import CoreML
import CryptoKit
import Foundation

/// The neural voices that read the captions aloud. Kokoro speaks English and Spanish, Supertonic
/// speaks Portuguese: in Portuguese, Kokoro's pronunciation rules got the Brazilian accent wrong.
/// Both run on the Mac (Core ML), are free and are downloaded only when you turn reading on.
enum VoiceEngine: String, CaseIterable, Identifiable, Sendable {
    case kokoro, supertonic

    var id: String { rawValue }

    /// The engine that reads captions in `language`, by its code ("pt", "en", "es").
    static func reading(_ language: String) -> VoiceEngine {
        language == "pt" ? .supertonic : .kokoro
    }

    var manifest: VoiceModelManifest {
        switch self {
        case .kokoro: return .kokoro
        case .supertonic: return .supertonic
        }
    }
}

/// The files of one model, pinned to a revision of its Hugging Face repository and checked once
/// downloaded: every file by its size, the large ones also by their SHA-256.
struct VoiceModelManifest: Sendable {
    struct File: Sendable {
        let path: String
        let size: Int
        let sha256: String?

        init(_ path: String, size: Int, sha256: String? = nil) {
            self.path = path
            self.size = size
            self.sha256 = sha256
        }
    }

    let repository: String
    let revision: String
    let files: [File]

    var totalBytes: Int { files.reduce(0) { $0 + $1.size } }

    func url(for file: File) -> URL {
        URL(string: "https://huggingface.co/\(repository)/resolve/\(revision)/\(file.path)")!
    }

    /// Kokoro-82M (Apache-2.0): the model, its English pronunciation dictionaries and the voices Mara offers.
    static let kokoro = VoiceModelManifest(
        repository: "aufklarer/Kokoro-82M-CoreML",
        revision: "f8ff771e4cab0bb3368e8af3a090a7e847485401",
        files: [
            .init("G2PDecoder.mlmodelc/analytics/coremldata.bin", size: 243, sha256: "dbf1767747fdc188222d467a45b04608b396c76c71db3abb18a5fb3680ef9827"),
            .init("G2PDecoder.mlmodelc/coremldata.bin", size: 545, sha256: "607e960f19b4d9a30317a5a11869fcce84b300a909fcab2cc756c0d98e2dacd9"),
            .init("G2PDecoder.mlmodelc/metadata.json", size: 3064),
            .init("G2PDecoder.mlmodelc/model.mil", size: 19737),
            .init("G2PDecoder.mlmodelc/weights/weight.bin", size: 828030, sha256: "cbaeb4e743359f607ab161af0c6d8a817462fdaec622ee788ef8ef952c5f8214"),
            .init("G2PEncoder.mlmodelc/analytics/coremldata.bin", size: 243, sha256: "cf7fbd7e7a65529b2d2bf3941e458a0ab6dff7a298bf48e205a1727c81c26a99"),
            .init("G2PEncoder.mlmodelc/coremldata.bin", size: 398, sha256: "0f14d46ca9fd06c68b4717294575b2b99449e67d40b7a2c56f926bf05cd90b11"),
            .init("G2PEncoder.mlmodelc/metadata.json", size: 2034),
            .init("G2PEncoder.mlmodelc/model.mil", size: 20392),
            .init("G2PEncoder.mlmodelc/weights/weight.bin", size: 694592, sha256: "6926bcd2827d21fec82839487b987e06f85fd8a6a5bb896bc4f6062461d014ec"),
            .init("g2p_vocab.json", size: 1665),
            .init("kokoro_5s.mlmodelc/analytics/coremldata.bin", size: 243, sha256: "4ab1ce05ed4689825180da77f37ff86d7bcee01877732c6426c5fc8834fbc798"),
            .init("kokoro_5s.mlmodelc/coremldata.bin", size: 478, sha256: "c177e635173de37545490ea0b431274816491e77bb187ac197ab63ad6a9b902d"),
            .init("kokoro_5s.mlmodelc/metadata.json", size: 4586),
            .init("kokoro_5s.mlmodelc/model.mil", size: 804060),
            .init("kokoro_5s.mlmodelc/weights/weight.bin", size: 324488320, sha256: "48b6d7301be895e25d80a6024b71ba023d1baa9ec71e26a66cc9e32f78f83a86"),
            .init("us_gold.json", size: 3001196),
            .init("us_silver.json", size: 3105352),
            .init("vocab_index.json", size: 2034),
            .init("voices/af_bella.json", size: 5505),
            .init("voices/af_heart.json", size: 5517),
            .init("voices/am_adam.json", size: 5501),
            .init("voices/am_michael.json", size: 5477),
            .init("voices/ef_dora.json", size: 5523),
            .init("voices/em_alex.json", size: 5513),
            .init("voices/em_santa.json", size: 5515),
        ]
    )

    /// Supertonic 3 by Supertone (OpenRAIL-M): reads the text as written, without pronunciation rules.
    static let supertonic = VoiceModelManifest(
        repository: "aufklarer/Supertonic-3-CoreML",
        revision: "d159f984aa1c4ccaafd0541076463e422cf75408",
        files: [
            .init("DurationPredictor.mlpackage/Data/com.apple.CoreML/model.mlmodel", size: 83267, sha256: "23f4128d68de2cc0aacd5568d134d33f0340deeac64443bd5dc2073a4fada293"),
            .init("DurationPredictor.mlpackage/Data/com.apple.CoreML/weights/weight.bin", size: 3590080, sha256: "714d7d6bcf0cbae95a8e0a27c88b643961d0785fe381d33243fc679fd1b76625"),
            .init("DurationPredictor.mlpackage/Manifest.json", size: 617),
            .init("TextEncoder.mlpackage/Data/com.apple.CoreML/model.mlmodel", size: 128982, sha256: "3671067b6123ea2fdefc2b36fde98ea25d09a0c9ebc0051e7b2b195387d088a7"),
            .init("TextEncoder.mlpackage/Data/com.apple.CoreML/weights/weight.bin", size: 36035200, sha256: "9618a75954419ab1e19d1f0946df20ab391d993632f0d2478085c32ddc17e8d7"),
            .init("TextEncoder.mlpackage/Manifest.json", size: 617),
            .init("VectorEstimator.mlpackage/Data/com.apple.CoreML/model.mlmodel", size: 289258, sha256: "b14fb761f8d755f4859d53116478be091cae378a32bbd75cad7be245ea475b2a"),
            .init("VectorEstimator.mlpackage/Data/com.apple.CoreML/weights/weight.bin", size: 255276032, sha256: "593cb7df14efd8d98e6e0543e0c18fb5778f3602e36164ec0dcf35f5c713e1fd"),
            .init("VectorEstimator.mlpackage/Manifest.json", size: 617),
            .init("Vocoder.mlpackage/Data/com.apple.CoreML/model.mlmodel", size: 64393, sha256: "a1f37fe142b88dc57487092be463de4e0a1ec8bf850128f03c34005a28c1be33"),
            .init("Vocoder.mlpackage/Data/com.apple.CoreML/weights/weight.bin", size: 101339136, sha256: "f0f325c9e90fe325cf1450e7f5f204ded3a8771b32d5e151435a9fb0fc07ac6d"),
            .init("Vocoder.mlpackage/Manifest.json", size: 617),
            .init("tts.json", size: 8253),
            .init("unicode_indexer.json", size: 277676),
            .init("voice_styles/F1.json", size: 292046),
            .init("voice_styles/F2.json", size: 292423),
            .init("voice_styles/F3.json", size: 290794),
            .init("voice_styles/F4.json", size: 291808),
            .init("voice_styles/F5.json", size: 291479),
            .init("voice_styles/M1.json", size: 291748),
            .init("voice_styles/M2.json", size: 292055),
            .init("voice_styles/M3.json", size: 290198),
            .init("voice_styles/M4.json", size: 291522),
            .init("voice_styles/M5.json", size: 291469),
        ]
    )
}

/// Where each voice model stands on this Mac, and its download.
@MainActor
final class VoiceModelStore: ObservableObject {
    enum State: Equatable {
        case missing
        /// From 0 to 1.
        case downloading(Double)
        case ready
        case failed(String)
    }

    static let shared = VoiceModelStore()

    @Published private(set) var states: [VoiceEngine: State] = [:]
    private var downloads: [VoiceEngine: Task<Void, Never>] = [:]

    nonisolated static let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MaraAI/Voices", isDirectory: true)

    private init() {
        for engine in VoiceEngine.allCases {
            states[engine] = Self.isComplete(engine) ? .ready : .missing
        }
    }

    func state(_ engine: VoiceEngine) -> State { states[engine] ?? .missing }

    /// The model's folder, named after its revision, so a new one never mixes with an old one.
    nonisolated static func directory(_ engine: VoiceEngine) -> URL {
        root.appendingPathComponent("\(engine.rawValue)-\(engine.manifest.revision.prefix(12))", isDirectory: true)
    }

    /// Written last, once every file has been checked.
    private nonisolated static func marker(_ engine: VoiceEngine) -> URL {
        directory(engine).appendingPathComponent(".complete")
    }

    nonisolated static func isComplete(_ engine: VoiceEngine) -> Bool {
        FileManager.default.fileExists(atPath: marker(engine).path)
    }

    func download(_ engine: VoiceEngine) {
        if case .downloading = state(engine) { return }
        guard state(engine) != .ready else { return }
        states[engine] = .downloading(0)
        downloads[engine] = Task { [weak self] in
            do {
                try await Self.fetch(engine) { fraction in
                    Task { @MainActor in
                        guard let self, case .downloading = self.state(engine) else { return }
                        self.states[engine] = .downloading(fraction)
                    }
                }
                self?.states[engine] = .ready
            } catch let error where error is CancellationError || (error as? URLError)?.code == .cancelled {
                // Cancelled mid-file, URLSession reports it as its own error.
                self?.states[engine] = .missing
            } catch {
                self?.states[engine] = .failed(error.localizedDescription)
            }
            self?.downloads[engine] = nil
        }
    }

    func cancel(_ engine: VoiceEngine) {
        downloads[engine]?.cancel()
    }

    /// Frees the disk space. The voices come back with another download.
    func remove(_ engine: VoiceEngine) {
        cancel(engine)
        try? FileManager.default.removeItem(at: Self.directory(engine))
        states[engine] = .missing
    }

    /// Downloads into a temporary folder and moves it into place only when everything checks out,
    /// so a download cut halfway never looks complete.
    private nonisolated static func fetch(_ engine: VoiceEngine, progress: @escaping @Sendable (Double) -> Void) async throws {
        let manifest = engine.manifest
        let fileManager = FileManager.default
        let staging = root.appendingPathComponent(".\(engine.rawValue)-download", isDirectory: true)
        try? fileManager.removeItem(at: staging)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        let total = Double(manifest.totalBytes)
        var done = 0
        for file in manifest.files {
            try Task.checkCancellation()
            let destination = staging.appendingPathComponent(file.path)
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            let base = done
            let (downloaded, response) = try await URLSession.shared.download(
                from: manifest.url(for: file),
                delegate: ProgressDelegate { written in progress(Double(base + Int(written)) / total) }
            )
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw AppError.message(localized("O download das vozes falhou (\(file.path)). Tente de novo."))
            }
            try fileManager.moveItem(at: downloaded, to: destination)
            try verify(destination, against: file)
            done += file.size
            progress(Double(done) / total)
        }

        // Supertonic ships its graphs uncompiled. Compiling them here, once, spares the first
        // meeting that wait and the disk the second copy.
        let packages = try fileManager.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "mlpackage" }
        for package in packages {
            try Task.checkCancellation()
            let compiled = try await MLModel.compileModel(at: package)
            try fileManager.moveItem(at: compiled, to: package.deletingPathExtension().appendingPathExtension("mlmodelc"))
            try fileManager.removeItem(at: package)
        }

        // Cancelled or deleted while compiling: nothing is moved into place.
        try Task.checkCancellation()
        let directory = Self.directory(engine)
        try? fileManager.removeItem(at: directory)
        try fileManager.moveItem(at: staging, to: directory)
        fileManager.createFile(atPath: marker(engine).path, contents: Data())
    }

    nonisolated static func verify(_ url: URL, against file: VoiceModelManifest.File) throws {
        let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue
        guard size == file.size else {
            throw AppError.message(localized("Um arquivo das vozes chegou incompleto (\(file.path)). Tente de novo."))
        }
        guard let expected = file.sha256 else { return }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == expected else {
            throw AppError.message(localized("Um arquivo das vozes não confere com o original (\(file.path)). Tente de novo."))
        }
    }
}

/// Reports how much of the file in flight has arrived.
private final class ProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let onWrite: (Int64) -> Void

    init(onWrite: @escaping (Int64) -> Void) {
        self.onWrite = onWrite
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        onWrite(totalBytesWritten)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}
