import CoreML
import Foundation
import Voices

/// Whose voice to read with. Told apart by the pitch of who is speaking (see `SpeakerPitch`).
enum VoiceGender: String, CaseIterable, Sendable {
    case female, male
}

/// A voice Mara can read with: the engine's preset name and how it shows in Settings.
struct ReadoutVoice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let gender: VoiceGender
}

/// The voices offered for each caption language, the first of each gender being the default.
enum ReadoutCatalog {
    static func voices(for language: String) -> [ReadoutVoice] {
        switch language {
        case "pt":
            return (1...5).map { ReadoutVoice(id: "F\($0)", name: localized("Feminina \($0)"), gender: .female) }
                + (1...5).map { ReadoutVoice(id: "M\($0)", name: localized("Masculina \($0)"), gender: .male) }
        case "es":
            return [
                ReadoutVoice(id: "ef_dora", name: "Dora", gender: .female),
                ReadoutVoice(id: "em_alex", name: "Alex", gender: .male),
                ReadoutVoice(id: "em_santa", name: "Santa", gender: .male),
            ]
        default:
            return [
                ReadoutVoice(id: "af_heart", name: "Heart", gender: .female),
                ReadoutVoice(id: "af_bella", name: "Bella", gender: .female),
                ReadoutVoice(id: "am_michael", name: "Michael", gender: .male),
                ReadoutVoice(id: "am_adam", name: "Adam", gender: .male),
            ]
        }
    }

    static func voices(for language: String, gender: VoiceGender) -> [ReadoutVoice] {
        voices(for: language).filter { $0.gender == gender }
    }

    /// `preferred` when the language offers it, otherwise the language's first voice of that gender.
    static func voice(for language: String, gender: VoiceGender, preferred: String?) -> ReadoutVoice {
        let options = voices(for: language, gender: gender)
        return options.first { $0.id == preferred } ?? options[0]
    }

    /// A sentence to try a voice with, in its language.
    static func sample(for language: String) -> String {
        switch language {
        case "pt": return "Oi! É assim que eu vou ler as legendas da reunião para você."
        case "es": return "¡Hola! Así voy a leer los subtítulos de la reunión para ti."
        default: return "Hi! This is how I'll read the meeting's captions to you."
        }
    }
}

/// One loaded voice model. Synthesis takes a quarter to two thirds of a second per sentence, so it
/// runs on its own queue, never on the main thread; one sentence at a time.
final class Synthesizer: @unchecked Sendable {
    let engine: VoiceEngine
    let sampleRate: Double
    private let queue = DispatchQueue(label: "mara-ai.voice-synthesis", qos: .userInitiated)
    private let kokoro: KokoroTTSModel?
    private let supertonic: SupertonicTTSModel?

    private init(engine: VoiceEngine, kokoro: KokoroTTSModel?, supertonic: SupertonicTTSModel?) {
        self.engine = engine
        self.kokoro = kokoro
        self.supertonic = supertonic
        sampleRate = engine == .kokoro ? Double(KokoroTTSModel.outputSampleRate) : 44_100
    }

    /// Loads the downloaded model (a few seconds) off the main thread, and warms it up: the first
    /// synthesis after loading is the slow one, when Core ML prepares the model for this Mac.
    static func load(_ engine: VoiceEngine) async throws -> Synthesizer {
        let directory = VoiceModelStore.directory(engine.model)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let synthesizer: Synthesizer
                    switch engine {
                    case .kokoro:
                        synthesizer = Synthesizer(engine: engine, kokoro: try KokoroTTSModel.load(from: directory), supertonic: nil)
                    case .supertonic:
                        synthesizer = Synthesizer(engine: engine, kokoro: nil, supertonic: try SupertonicTTSModel.load(from: directory))
                    }
                    _ = try? synthesizer.render("Ok.", voice: engine == .kokoro ? "af_heart" : "F1", language: engine == .kokoro ? "en" : "pt", speed: 1)
                    continuation.resume(returning: synthesizer)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Mono samples at `sampleRate`. `speed` 1 is the voice's natural pace.
    func synthesize(_ text: String, voice: String, language: String, speed: Double) async throws -> [Float] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try self.render(text, voice: voice, language: language, speed: speed) })
            }
        }
    }

    private func render(_ text: String, voice: String, language: String, speed: Double) throws -> [Float] {
        if let supertonic {
            // Supertonic splits long text itself. Its natural pace is a bit slow for a meeting.
            return try supertonic.synthesize(
                text: text, voice: voice, language: language,
                options: SupertonicOptions(totalStep: 8, speed: Float(1.15 * speed), seed: 7)
            )
        }
        guard let kokoro else { return [] }
        // Kokoro makes at most about 5 seconds per call and drops the rest, so long sentences are
        // read clause by clause, with a short pause in between.
        let pause = [Float](repeating: 0, count: Int(sampleRate * 0.12))
        var samples: [Float] = []
        for (index, clause) in Self.clauses(of: text).enumerated() {
            if index > 0 { samples += pause }
            samples += try kokoro.synthesize(text: clause, voice: voice, language: language, speed: Float(speed))
        }
        return samples
    }

    /// Splits `text` into pieces of at most `limit` characters, at punctuation when possible and
    /// otherwise between words.
    static func clauses(of text: String, limit: Int = 90) -> [String] {
        var pieces: [String] = []
        var current = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: true) {
            let candidate = current.isEmpty ? String(word) : current + " " + word
            if candidate.count > limit, !current.isEmpty {
                pieces.append(current)
                current = String(word)
            } else {
                current = candidate
            }
            // Ends a piece at a comma or a period once it is long enough to sound natural.
            if let last = current.last, ",;:.!?…".contains(last), current.count >= limit / 3 {
                pieces.append(current)
                current = ""
            }
        }
        if !current.isEmpty { pieces.append(current) }
        return pieces
    }
}
