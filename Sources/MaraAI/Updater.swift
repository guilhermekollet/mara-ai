import AppKit
import CryptoKit
import Foundation
import Security

/// Keeps Mara up to date from GitHub Releases. Once a day it looks for a newer release, downloads
/// it in the background and checks it: the zip must carry a valid signature from the project's
/// update key, and the app inside must be Mara, at that version, signed with the same certificate.
/// The new version replaces this one when Mara quits, or right away with "Reiniciar agora".
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case downloading(version: String)
        /// Downloaded and checked: it installs when Mara quits.
        case ready(version: String, notes: URL)
        case failed(String)
    }

    @Published private(set) var state = State.idle
    @Published private(set) var lastCheck: Date?
    @Published var automatic: Bool {
        didSet { UserDefaults.standard.set(automatic, forKey: "autoUpdate") }
    }

    static let feed = URL(string: "https://api.github.com/repos/guilhermekollet/mara-ai/releases/latest")!
    /// The public half of the key that signs every release (scripts/sign-update.swift signs with
    /// the private half, kept as a GitHub secret).
    static let publicKey = "pGAcfm82aQmM6AsqtkHuefE7fySeanHSMfsO5VPn+ik="

    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    private var staged: URL?
    private var schedule: Task<Void, Never>?
    private var installing = false

    private static let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Mara AI/Updates", isDirectory: true)

    private init() {
        automatic = UserDefaults.standard.object(forKey: "autoUpdate") as? Bool ?? true
    }

    /// Only release builds update themselves (scripts/package-release.sh marks them), and only
    /// when the app sits somewhere it can be replaced, such as Applications.
    var isAvailable: Bool { installedApp != nil }

    private var installedApp: URL? {
        let app = Bundle.main.bundleURL
        guard Bundle.main.object(forInfoDictionaryKey: "MaraUpdates") as? Bool == true,
              app.pathExtension == "app",
              FileManager.default.isWritableFile(atPath: app.deletingLastPathComponent().path)
        else { return nil }
        return app
    }

    /// Checks shortly after launch and then once a day, while automatic updates are on.
    func start() {
        guard isAvailable, schedule == nil else { return }
        try? FileManager.default.removeItem(at: Self.folder) // leftovers from earlier downloads
        schedule = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            while !Task.isCancelled {
                if let self, self.automatic { await self.check() }
                try? await Task.sleep(for: .seconds(24 * 60 * 60))
            }
        }
    }

    func check() async {
        switch state {
        case .checking, .downloading, .ready: return
        default: break
        }
        guard isAvailable else { return }
        state = .checking
        do {
            let release = try await latestRelease()
            lastCheck = Date()
            let version = release.version
            guard Self.isNewer(version, than: currentVersion) else {
                state = .upToDate
                return
            }
            state = .downloading(version: version)
            staged = try await download(release)
            state = .ready(version: version, notes: release.page)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Puts the downloaded version in place of this one once Mara has quit, and opens it again
    /// when `relaunch` is set. Called on quit, and by "Reiniciar agora" before quitting.
    func installIfReady(relaunch: Bool) {
        guard case .ready = state, !installing, let staged, let app = installedApp else { return }
        installing = true
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        backup="$2.previous"
        rm -rf "$backup"
        if mv "$2" "$backup" && mv "$3" "$2"; then
          rm -rf "$backup"
        elif [ -d "$backup" ] && [ ! -d "$2" ]; then
          mv "$backup" "$2"
        fi
        [ "$4" = 1 ] && /usr/bin/open "$2"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "sh", String(ProcessInfo.processInfo.processIdentifier), app.path, staged.path, relaunch ? "1" : "0"]
        try? process.run()
    }

    // MARK: Release, download and checks

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }

        let tag_name: String
        let html_url: URL
        let assets: [Asset]

        var version: String { tag_name.hasPrefix("v") ? String(tag_name.dropFirst()) : tag_name }
        var page: URL { html_url }
    }

    private func latestRelease() async throws -> Release {
        var request = URLRequest(url: Self.feed, timeoutInterval: 30)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AppError.message("O GitHub não respondeu como esperado.")
        }
        return try JSONDecoder().decode(Release.self, from: data)
    }

    /// Downloads the release's zip and signature, checks both and unpacks the app. Returns the
    /// unpacked app, ready to be moved into place.
    private func download(_ release: Release) async throws -> URL {
        guard let zip = release.assets.first(where: { $0.name.hasSuffix("-macOS-arm64.zip") }),
              let signature = release.assets.first(where: { $0.name == zip.name + ".sig" })
        else { throw AppError.message("A versão \(release.version) não tem o pacote assinado para este Mac.") }

        let folder = Self.folder.appendingPathComponent(release.version, isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let (zipFile, _) = try await URLSession.shared.download(from: zip.browser_download_url)
        let (signatureData, _) = try await URLSession.shared.data(from: signature.browser_download_url)
        let archive = try Data(contentsOf: zipFile)
        guard let signatureText = String(data: signatureData, encoding: .utf8),
              let signatureBytes = Data(base64Encoded: signatureText.trimmingCharacters(in: .whitespacesAndNewlines)),
              Self.isSigned(archive, signature: signatureBytes, publicKey: Self.publicKey)
        else { throw AppError.message("A assinatura da versão \(release.version) não confere; ela não foi instalada.") }

        let archiveURL = folder.appendingPathComponent(zip.name)
        try archive.write(to: archiveURL)
        try run("/usr/bin/ditto", ["-x", "-k", archiveURL.path, folder.path])
        let app = folder.appendingPathComponent("Mara AI.app", isDirectory: true)
        try checkApp(at: app, version: release.version)
        return app
    }

    /// The unpacked app must be Mara, at the version the release says, and signed with the same
    /// certificate as the running one (unless this one is signed ad hoc, which has none).
    private func checkApp(at app: URL, version: String) throws {
        guard let bundle = Bundle(url: app),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == version
        else { throw AppError.message("O pacote da versão \(version) não é o esperado.") }

        var current: SecCode?
        var currentStatic: SecStaticCode?
        var downloaded: SecStaticCode?
        guard SecCodeCopySelf([], &current) == errSecSuccess, let current,
              SecCodeCopyStaticCode(current, [], &currentStatic) == errSecSuccess, let currentStatic,
              SecStaticCodeCreateWithPath(app as CFURL, [], &downloaded) == errSecSuccess, let downloaded
        else { throw AppError.message("Não foi possível conferir a assinatura do app baixado.") }
        // An ad hoc signature's requirement names the exact build (its cdhash), so no other build
        // can match it; the update's own signature is the check that counts then.
        var requirement: SecRequirement?
        var requirementText: CFString?
        if SecCodeCopyDesignatedRequirement(currentStatic, [], &requirement) == errSecSuccess, let requirement {
            SecRequirementCopyString(requirement, [], &requirementText)
        }
        let signedAdHoc = (requirementText as String?)?.contains("cdhash") ?? true
        let status = SecStaticCodeCheckValidity(downloaded, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), signedAdHoc ? nil : requirement)
        guard status == errSecSuccess else {
            throw AppError.message("O app da versão \(version) não tem a assinatura do projeto.")
        }
    }

    private func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw AppError.message("Não foi possível abrir o pacote da atualização.") }
    }

    // MARK: Pure helpers

    /// Compares versions such as "0.10.0" and "0.9.2" number by number.
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        let numbers = { (version: String) in version.split(separator: ".").map { Int($0) ?? 0 } }
        let (a, b) = (numbers(candidate), numbers(current))
        for index in 0..<max(a.count, b.count) {
            let (x, y) = (index < a.count ? a[index] : 0, index < b.count ? b[index] : 0)
            if x != y { return x > y }
        }
        return false
    }

    /// Whether `signature` is the project's Ed25519 signature of `data`.
    nonisolated static func isSigned(_ data: Data, signature: Data, publicKey: String) -> Bool {
        guard let keyData = Data(base64Encoded: publicKey),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData)
        else { return false }
        return key.isValidSignature(signature, for: data)
    }
}
