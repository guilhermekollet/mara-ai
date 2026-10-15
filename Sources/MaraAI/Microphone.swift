import AVFoundation
import AppKit

/// Who said an utterance. The source tells them apart: the Mac's audio is the other participants,
/// the microphone is the person using Mara. No voice recognition is involved.
enum Speaker: Sendable {
    case others, me
}

/// Permission to use the microphone, which macOS asks for the first time it is turned on.
enum MicrophonePermission {
    static var isGranted: Bool { AVCaptureDevice.authorizationStatus(for: .audio) == .authorized }
    static var wasDenied: Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status == .denied || status == .restricted
    }

    /// Shows the system prompt the first time; afterwards it only reports the current state.
    static func request() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Without headphones, the microphone also hears the other participants through the speakers, so
/// the same sentence would be transcribed twice, once as theirs and once as "yours". This compares
/// the words: an utterance from the microphone that repeats what came from the Mac around the
/// same time is that echo.
enum EchoFilter {
    /// How far apart the two transcriptions of the same sentence can finish. Measured: the
    /// microphone's ends 1 s before to 2 s after the Mac's. Kept tight, because someone repeating
    /// your words a little later ("ok, let's move it to Friday") is not an echo.
    static let window: Double = 6
    /// Short utterances ("ok", "sim, claro") share words with almost anything, so they only count as
    /// an echo when the same words, in the same order, came from the Mac within a few seconds.
    static let shortWindow: Double = 4
    static let shortLength = 3
    /// Share of the microphone's words that must also have come from the Mac.
    static let overlap = 0.6

    /// Whether `mine` repeats what the others said. `others` are their utterances, each with how
    /// many seconds before (or, negative, after) `mine` it finished.
    static func isEcho(_ mine: String, others: [(text: String, secondsApart: Double)]) -> Bool {
        let words = Self.words(mine)
        guard !words.isEmpty else { return false }
        if words.count <= shortLength {
            return others.contains { abs($0.secondsApart) <= shortWindow && contains(Self.words($0.text), words) }
        }
        let heard = Set(others.filter { abs($0.secondsApart) <= window }.flatMap { Self.words($0.text) })
        let repeated = words.filter(heard.contains).count
        return Double(repeated) / Double(words.count) >= overlap
    }

    /// Lowercased words without accents or punctuation, so "Está bem." and "esta bem" match.
    static func words(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func contains(_ text: [String], _ phrase: [String]) -> Bool {
        guard phrase.count <= text.count else { return false }
        return (0...(text.count - phrase.count)).contains { Array(text[$0..<($0 + phrase.count)]) == phrase }
    }
}
