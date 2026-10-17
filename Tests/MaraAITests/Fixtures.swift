// Test helpers that need Foundation and AVFoundation live here, in a file that does not import
// Testing: with only the Command Line Tools installed (no Xcode), importing Testing next to
// Foundation fails because the `_Testing_Foundation` overlay is missing. Test files import just
// Testing and MaraAI and talk to these helpers through plain values.
import AVFoundation
import CryptoKit
import Foundation
@testable import MaraAI

/// Drives an `ActivityGate` with synthetic 100 ms buffers at 16 kHz.
final class GateHarness {
    let gate = ActivityGate()
    private let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: false)!

    private func buffer(amplitude: Int16) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1_600)!
        buffer.frameLength = 1_600
        for index in 0..<1_600 { buffer.int16ChannelData![0][index] = index.isMultiple(of: 2) ? amplitude : -amplitude }
        return buffer
    }

    /// Feeds one buffer and returns how many seconds of audio the gate let through.
    func feed(loud: Bool) -> Double {
        let released = gate.pass(buffer(amplitude: loud ? 4_000 : 0))
        return Double(released.reduce(0) { $0 + Int($1.frameLength) }) / 16_000
    }
}

/// The caption language a new install picks on a Mac set to `localeID`.
func preferredCaptionLanguage(onMacIn localeID: String) -> String {
    CaptionLanguage.preferred(for: Locale(identifier: localeID)).id
}

/// The caption language that matches a meeting locale, if Mara captions in it.
func captionLanguageCode(matching localeID: String) -> String? {
    CaptionLanguage.matching(Locale(identifier: localeID))?.code
}

/// Signs a sample with a fresh Ed25519 key, as scripts/sign-update.swift does, and checks it the
/// way the updater does, optionally after changing one byte of the sample.
func updateSignatureHolds(afterTampering tamper: Bool) -> Bool {
    let key = Curve25519.Signing.PrivateKey()
    var archive = Data("Mara AI.app".utf8)
    let signature = try! key.signature(for: archive)
    if tamper { archive[0] ^= 1 }
    return Updater.isSigned(archive, signature: signature, publicKey: key.publicKey.rawRepresentation.base64EncodedString())
}

// MARK: Translations

private let sources = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Sources/MaraAI")

/// The interface's translation table for `language` ("en", "es"), read from the sources.
func translationTable(_ language: String) -> [String: String] {
    let url = sources.appendingPathComponent("Resources/\(language).lproj/Localizable.strings")
    return NSDictionary(contentsOf: url) as? [String: String] ?? [:]
}

/// The format specifiers in `text`, in order (`%@`, `%lld`, `%%`): a translation must keep its key's.
func formatSpecifiers(_ text: String) -> [String] {
    let pattern = try! NSRegularExpression(pattern: "%(%|@|l{0,2}[dfu])")
    return pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
        .map { String(text[Range($0.range, in: text)!]) }
}

/// The key of every `localized("…")` in Sources/MaraAI, the way `String.LocalizationValue` builds
/// it, except that interpolations become `%@` whatever their type (the source doesn't say).
func localizedKeysInSources() -> [String] {
    let files = (try? FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)) ?? []
    var keys: [String] = []
    for file in files where file.pathExtension == "swift" {
        let text = Array((try? String(contentsOf: file, encoding: .utf8)) ?? "")
        let opening = Array("localized(\"")
        var index = 0
        while index + opening.count <= text.count {
            guard Array(text[index..<index + opening.count]) == opening else {
                index += 1
                continue
            }
            index += opening.count
            var key = ""
            while text[index] != "\"" {
                if text[index] == "\\", text[index + 1] == "(" {
                    // Skips the interpolated expression, which may have parentheses of its own.
                    var depth = 1
                    index += 2
                    while depth > 0 {
                        if text[index] == "(" { depth += 1 }
                        if text[index] == ")" { depth -= 1 }
                        index += 1
                    }
                    key += "%@"
                } else if text[index] == "\\" {
                    key += String(text[index...index + 1])
                    index += 2
                } else {
                    key += text[index] == "%" ? "%%" : String(text[index])
                    index += 1
                }
            }
            keys.append(key)
        }
    }
    return keys
}

/// `key` with every specifier but `%%` written as `%@`, to compare with `localizedKeysInSources`.
func normalizedKey(_ key: String) -> String {
    key.replacingOccurrences(of: "%l{0,2}[dfu]", with: "%@", options: .regularExpression)
}

// MARK: Reading aloud

/// Pushes sentences finalized `ages` seconds ago into a reading queue and returns the order, by
/// index, in which they come out.
func readoutOrder(pushedSecondsAgo ages: [Double]) -> [Int] {
    let now = Date()
    let items = ages.map { ReadoutQueue.Item(id: UUID(), createdAt: now.addingTimeInterval(-$0), text: "") }
    var queue = ReadoutQueue()
    items.forEach { queue.push($0) }
    var order: [Int] = []
    while let next = queue.next(now: now) { order.append(items.firstIndex(of: next)!) }
    return order
}

/// A voice-like tone: a fundamental and two overtones, which is what trips up octave detection.
func voiceTone(_ hertz: Double, seconds: Double = 0.064, sampleRate: Double = 16_000) -> [Float] {
    (0..<Int(seconds * sampleRate)).map { index in
        let t = Double(index) / sampleRate
        return Float(0.3 * sin(2 * .pi * hertz * t) + 0.2 * sin(4 * .pi * hertz * t) + 0.1 * sin(6 * .pi * hertz * t))
    }
}

/// Random noise, which has no pitch.
func noise(count: Int) -> [Float] {
    (0..<count).map { _ in Float.random(in: -0.3...0.3) }
}

/// The median pitch of one second of a tone at `hertz`, measured as a piece's clip would be.
func pitchOfOneSecond(_ hertz: Double) -> Double? {
    SpeakerPitch.median(of: voiceTone(hertz, seconds: 1), sampleRate: 16_000)
}

/// SHA-256 of "mara".
let maraSHA256 = "c8b6c061e8591dfeaabefdbad7cdacc0ece53900f0bb02160860a0e3ef7d2acc"

/// Writes `contents` to a temporary file and checks it against a manifest entry.
func verifiesDownload(_ contents: String, size: Int, sha256: String? = nil) -> Bool {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    guard (try? Data(contents.utf8).write(to: url)) != nil else { return false }
    return (try? VoiceModelStore.verify(url, against: .init("x", size: size, sha256: sha256))) != nil
}

// MARK: Telling speakers apart

/// Feeds a meeting to the clustering: each sentence is its speaker's voice (a fixed random
/// direction) plus some noise, in the order given. Returns the speaker each sentence was put with.
func clusteredSpeakers(of sentences: [Int], noise: Float = 0.6, seed: UInt64 = 7) -> [Int?] {
    var generator = SeededGenerator(seed: seed)
    func direction() -> [Float] { (0..<192).map { _ in Float.random(in: -1...1, using: &generator) } }
    func normalized(_ vector: [Float]) -> [Float] {
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        return vector.map { $0 / norm }
    }
    let voices = (0..<((sentences.max() ?? 0) + 1)).map { _ in normalized(direction()) }
    var clusters = SpeakerClusters()
    return sentences.map { speaker in
        let jitter = normalized(direction())
        return clusters.assign(normalized(zip(voices[speaker], jitter).map { $0 + noise * $1 }))
    }
}

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Appends `seconds` of audio where each second's samples equal that second's index, in buffers
/// of 0.1 s, then clips `from`…`to` and returns the distinct values found (which seconds came back).
func clippedSeconds(feeding seconds: Int, from start: Double, to end: Double) -> [Float] {
    let audio = SentenceAudio()
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
    for second in 0..<seconds {
        for _ in 0..<10 {
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1_600)!
            buffer.frameLength = 1_600
            for index in 0..<1_600 { buffer.floatChannelData![0][index] = Float(second) }
            audio.append(buffer)
        }
    }
    return Array(Set(audio.clip(from: start, to: end).samples)).sorted()
}
