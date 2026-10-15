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

    nonisolated static let feed = URL(string: "https://api.github.com/repos/guilhermekollet/mara-ai/releases/latest")!
    /// The public half of the key that signs every release (scripts/sign-update.swift signs with
    /// the private half, kept as a GitHub secret).
    nonisolated static let publicKey = "pGAcfm82aQmM6AsqtkHuefE7fySeanHSMfsO5VPn+ik="

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

    /// Checks shortly after launch and then once a day while automatic updates are on; after a
    /// failure, such as being offline, it tries again an hour later.
    func start() {
        guard isAvailable, schedule == nil else { return }
        try? FileManager.default.removeItem(at: Self.folder) // leftovers from earlier downloads
        schedule = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            while !Task.isCancelled {
                var failed = false
                if let self, self.automatic {
                    await self.check()
                    if case .failed = self.state { failed = true }
                }
                try? await Task.sleep(for: .seconds(failed ? 60 * 60 : 24 * 60 * 60))
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
            let release = try await Self.latestRelease()
            lastCheck = Date()
            guard Self.isNewer(release.version, than: currentVersion) else {
                state = .upToDate
                return
            }
            state = .downloading(version: release.version)
            staged = try await Self.download(release, into: Self.folder)
            state = .ready(version: release.version, notes: release.html_url)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Swaps the downloaded version in for this one, in a single atomic step, after checking it
    /// once more; with `relaunch`, the new version opens once this one has quit. Returns whether
    /// it was installed. Called on quit, and by "Reiniciar agora" before quitting.
    @discardableResult
    func installIfReady(relaunch: Bool) -> Bool {
        guard case .ready(let version, _) = state, !installing, let staged, let app = installedApp else { return false }
        installing = true
        do {
            // It may have waited days in Application Support: check it again before it goes in.
            try Self.checkApp(at: staged, version: version)
            // The running app keeps working from its open files until it quits.
            _ = try FileManager.default.replaceItemAt(app, withItemAt: staged)
        } catch {
            installing = false
            state = .failed(localized("A versão \(version) não foi instalada: \(error.localizedDescription)"))
            return false
        }
        if relaunch {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$2\"",
                                 "sh", String(ProcessInfo.processInfo.processIdentifier), app.path]
            try? process.run()
        }
        return true
    }

    // MARK: Release, download and checks (off the main actor)

    private struct Release: Decodable, Sendable {
        struct Asset: Decodable, Sendable {
            let name: String
            let browser_download_url: URL
        }

        let tag_name: String
        let html_url: URL
        let assets: [Asset]

        var version: String { tag_name.hasPrefix("v") ? String(tag_name.dropFirst()) : tag_name }
    }

    nonisolated private static func latestRelease() async throws -> Release {
        var request = URLRequest(url: feed, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AppError.message(localized("O GitHub não respondeu como esperado."))
        }
        let release = try JSONDecoder().decode(Release.self, from: data)
        // The version names a folder below, so it must be plain numbers and dots.
        guard isPlainVersion(release.version) else {
            throw AppError.message(localized("A última release tem uma versão inesperada (\(release.tag_name))."))
        }
        return release
    }

    /// Downloads the release's zip and signature, checks both and unpacks the app. Returns the
    /// unpacked app, ready to be moved into place.
    nonisolated private static func download(_ release: Release, into updates: URL) async throws -> URL {
        guard let zip = release.assets.first(where: { $0.name.hasSuffix("-macOS-arm64.zip") }),
              let signature = release.assets.first(where: { $0.name == zip.name + ".sig" })
        else { throw AppError.message(localized("A versão \(release.version) não tem o pacote assinado para este Mac.")) }

        let (zipFile, _) = try await URLSession.shared.download(from: zip.browser_download_url)
        let (signatureData, _) = try await URLSession.shared.data(from: signature.browser_download_url)
        let archive = try Data(contentsOf: zipFile)
        guard let signatureText = String(data: signatureData, encoding: .utf8),
              let signatureBytes = Data(base64Encoded: signatureText.trimmingCharacters(in: .whitespacesAndNewlines)),
              isSigned(archive, signature: signatureBytes, publicKey: publicKey)
        else { throw AppError.message(localized("A assinatura da versão \(release.version) não confere; ela não foi instalada.")) }

        let folder = updates.appendingPathComponent(release.version, isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let archiveURL = folder.appendingPathComponent("update.zip")
        try archive.write(to: archiveURL)
        try run("/usr/bin/ditto", ["-x", "-k", archiveURL.path, folder.path])
        let app = folder.appendingPathComponent("Mara AI.app", isDirectory: true)
        try checkApp(at: app, version: release.version)
        return app
    }

    /// The unpacked app must be Mara, at the version the release says, intact and signed with the
    /// same certificate as the running app.
    nonisolated private static func checkApp(at app: URL, version: String) throws {
        // Read straight from disk: Bundle caches what it read from a path before.
        let infoData = try Data(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        guard let info = try PropertyListSerialization.propertyList(from: infoData, format: nil) as? [String: Any],
              info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              info["CFBundleShortVersionString"] as? String == version
        else { throw AppError.message(localized("O pacote da versão \(version) não é o esperado.")) }

        var downloaded: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &downloaded) == errSecSuccess, let downloaded else {
            throw AppError.message(localized("Não foi possível conferir a assinatura do app baixado."))
        }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate)
        guard SecStaticCodeCheckValidity(downloaded, flags, try projectRequirement()) == errSecSuccess else {
            throw AppError.message(localized("O app da versão \(version) não tem a assinatura do projeto."))
        }
    }

    /// What the running app is signed with, for the update to match. An ad hoc signature names
    /// only its own build, so no other build could match it; then the zip's signature is the check
    /// that counts. Anything unreadable fails the update rather than skipping the check.
    nonisolated private static func projectRequirement() throws -> SecRequirement? {
        var current: SecCode?
        var running: SecStaticCode?
        var information: CFDictionary?
        guard SecCodeCopySelf([], &current) == errSecSuccess, let current,
              SecCodeCopyStaticCode(current, [], &running) == errSecSuccess, let running,
              SecCodeCopySigningInformation(running, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let flags = (information as NSDictionary?)?[kSecCodeInfoFlags] as? NSNumber
        else { throw AppError.message(localized("Não foi possível ler a assinatura desta versão da Mara.")) }
        if flags.uint32Value & SecCodeSignatureFlags.adhoc.rawValue != 0 { return nil }
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(running, [], &requirement) == errSecSuccess, let requirement else {
            throw AppError.message(localized("Não foi possível ler a assinatura desta versão da Mara."))
        }
        return requirement
    }

    nonisolated private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw AppError.message(localized("Não foi possível abrir o pacote da atualização.")) }
    }

    // MARK: Pure helpers

    /// Numbers separated by dots, such as "0.3.0".
    nonisolated static func isPlainVersion(_ version: String) -> Bool {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        return !parts.isEmpty && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }
    }

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
