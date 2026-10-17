import CoreML
import Foundation

/// A voice's fingerprint: ReDimNet2-B6 (MIT) turns a stretch of speech into a 192-number
/// embedding; two stretches from the same person point the same way (cosine similarity close to 1).
///
/// Vendored from soniqo/speech-swift's `ReDimNet2SpeakerModel` (Apache-2.0); see NOTICE.
public final class SpeakerEmbedder: @unchecked Sendable {
    public static let sampleRate = 16_000
    /// The model always sees 6 seconds: shorter clips are repeated to fill it, longer ones are
    /// center-cropped.
    static let windowSamples = 96_000
    /// Below this, a clip says too little about the voice to be worth comparing.
    public static let minimumSamples = 9_600
    public static let dimension = 192

    private let model: MLModel

    private init(model: MLModel) {
        self.model = model
    }

    /// Loads the compiled model from `directory`, where Mara downloaded it.
    public static func load(from directory: URL, computeUnits: MLComputeUnits = .all) throws -> SpeakerEmbedder {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = computeUnits
        let model = try MLModel(contentsOf: directory.appendingPathComponent("ReDimNet2B6.mlmodelc", isDirectory: true), configuration: configuration)
        return SpeakerEmbedder(model: model)
    }

    /// The embedding of `samples` (mono, 16 kHz), L2-normalized; nil for a clip too short or silent.
    public func embed(_ samples: [Float]) throws -> [Float]? {
        guard samples.count >= Self.minimumSamples, samples.allSatisfy(\.isFinite) else { return nil }
        let input = try MLMultiArray(shape: [1, Self.windowSamples as NSNumber], dataType: .float32)
        let pointer = input.dataPointer.assumingMemoryBound(to: Float.self)
        if samples.count >= Self.windowSamples {
            let start = (samples.count - Self.windowSamples) / 2
            for index in 0..<Self.windowSamples { pointer[index] = samples[start + index] }
        } else {
            for index in 0..<Self.windowSamples { pointer[index] = samples[index % samples.count] }
        }
        let output = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["audio": MLFeatureValue(multiArray: input)]))
        guard let values = output.featureValue(for: "embedding")?.multiArrayValue, values.count == Self.dimension else {
            throw AudioModelError.inferenceFailed(operation: "speaker embedding", reason: "missing 192-dimensional output")
        }
        var embedding = (0..<Self.dimension).map { values[$0].floatValue }
        let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        guard norm > 1e-8, norm.isFinite else { return nil }
        for index in embedding.indices { embedding[index] /= norm }
        return embedding
    }
}
