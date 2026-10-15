import Foundation
import Voices

/// Groups the meeting's sentences by who said them, from each sentence's voice fingerprint: a
/// sentence close enough to someone already heard is theirs, otherwise it's someone new. Measured
/// on recorded speech (pt and en, 2 to 6 people, 2 to 5 s sentences), 0.55 kept the right person
/// for 95–100% of the sentences; real meetings, with call audio and crosstalk, will do worse.
struct SpeakerClusters {
    /// Cosine similarity from which a sentence belongs to someone already heard.
    static let threshold: Float = 0.55
    /// Past this, new voices go to whoever is closest instead of growing the list.
    static let maxSpeakers = 8

    private(set) var centroids: [[Float]] = []
    private var counts: [Int] = []

    /// The index of the speaker `embedding` belongs to, adding one when nobody is close enough.
    mutating func assign(_ embedding: [Float]) -> Int {
        let similarities = centroids.map { Self.cosine($0, embedding) }
        if let best = similarities.max(), best >= Self.threshold || centroids.count >= Self.maxSpeakers {
            let index = similarities.firstIndex(of: best)!
            // The running mean follows the voice as more of it is heard.
            var merged = zip(centroids[index], embedding).map { $0 * Float(counts[index]) + $1 }
            let norm = sqrt(merged.reduce(0) { $0 + $1 * $1 })
            if norm > 0 { merged = merged.map { $0 / norm } }
            centroids[index] = merged
            counts[index] += 1
            return index
        }
        centroids.append(embedding)
        counts.append(1)
        return centroids.count - 1
    }

    static func cosine(_ left: [Float], _ right: [Float]) -> Float {
        var dot: Float = 0, leftNorm: Float = 0, rightNorm: Float = 0
        for index in left.indices {
            dot += left[index] * right[index]
            leftNorm += left[index] * left[index]
            rightNorm += right[index] * right[index]
        }
        let denominator = sqrt(leftNorm) * sqrt(rightNorm)
        return denominator > 0 ? dot / denominator : 0
    }
}

/// Which of the language's voices each speaker gets: theirs for the whole meeting, from the
/// voices of their gender, at most two per gender so every voice stays a good one. The third
/// woman shares the first woman's voice, and so on.
struct VoiceCast {
    static let voicesPerGender = 2

    /// The speakers of each gender, in the order they were first heard.
    private var order: [VoiceGender: [Int]] = [:]

    /// The voice slot (0 or 1) for `speaker`, now known to be of `gender`.
    mutating func slot(for speaker: Int, gender: VoiceGender) -> Int {
        // A speaker whose gender estimate changed moves to the other list.
        for other in VoiceGender.allCases where other != gender {
            order[other]?.removeAll { $0 == speaker }
        }
        var list = order[gender, default: []]
        if !list.contains(speaker) { list.append(speaker) }
        order[gender] = list
        return list.firstIndex(of: speaker)! % Self.voicesPerGender
    }
}

/// Who said a sentence: their number in the meeting (1, 2, 3…), their voice's gender and the
/// voice slot they read with.
struct SpeakerInfo: Equatable, Sendable {
    let person: Int
    let gender: VoiceGender?
    let slot: Int
}

/// Tells the meeting's speakers apart, one finished sentence at a time, on its own queue (a
/// fingerprint takes about a quarter of a second).
final class SpeakerTracker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "mara-ai.speakers", qos: .userInitiated)
    private let embedder: SpeakerEmbedder
    private var clusters = SpeakerClusters()
    private var cast = VoiceCast()
    /// Each speaker's sentence pitches, to judge their gender over all they said rather than one sentence.
    private var pitches: [Int: [Double]] = [:]

    private init(embedder: SpeakerEmbedder) {
        self.embedder = embedder
    }

    static func load() async throws -> SpeakerTracker {
        let directory = VoiceModelStore.directory(.speakers)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let embedder = try SpeakerEmbedder.load(from: directory)
                    // The first fingerprint after loading is the slow one.
                    _ = try? embedder.embed((0..<16_000).map { Float(sin(Double($0) * 0.07)) * 0.05 })
                    continuation.resume(returning: SpeakerTracker(embedder: embedder))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Who said the sentence in `samples`. Nil when the sentence is too short to tell.
    func identify(_ samples: [Float], sampleRate: Double) async -> SpeakerInfo? {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.identifyNow(samples, sampleRate: sampleRate))
            }
        }
    }

    private func identifyNow(_ samples: [Float], sampleRate: Double) -> SpeakerInfo? {
        let audio = Self.resampled(samples, from: sampleRate)
        guard let embedding = try? embedder.embed(audio) else { return nil }
        let speaker = clusters.assign(embedding)
        if let pitch = SpeakerPitch.median(of: audio, sampleRate: Double(SpeakerEmbedder.sampleRate)) {
            pitches[speaker, default: []].append(pitch)
        }
        let sorted = (pitches[speaker] ?? []).sorted()
        let gender = sorted.isEmpty ? nil : SpeakerPitch.gender(forPersonPitch: sorted[sorted.count / 2])
        let slot = gender.map { cast.slot(for: speaker, gender: $0) } ?? 0
        return SpeakerInfo(person: speaker + 1, gender: gender, slot: slot)
    }

    /// The model wants 16 kHz; the recognizer usually asks for that already.
    static func resampled(_ samples: [Float], from rate: Double) -> [Float] {
        let target = Double(SpeakerEmbedder.sampleRate)
        guard rate != target, rate > 0, !samples.isEmpty else { return samples }
        let count = Int(Double(samples.count) * target / rate)
        return (0..<count).map { index in
            let position = Double(index) * rate / target
            let lower = Int(position)
            let upper = min(lower + 1, samples.count - 1)
            let fraction = Float(position - Double(lower))
            return samples[lower] * (1 - fraction) + samples[upper] * fraction
        }
    }
}
