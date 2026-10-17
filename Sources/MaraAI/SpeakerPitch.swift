import AVFoundation

/// Follows the pitch of the voices in the meeting, so each sentence can be read with a voice like
/// the speaker's: deep voices with a male voice, high ones with a female voice. A first step
/// before telling the participants apart; pitch alone gets some people wrong, which is why the
/// borderline range keeps the previous speaker's voice.
///
/// Capture pushes audio on its queue; the main actor takes the sentence's pitch when it finishes.
final class SpeakerPitch: @unchecked Sendable {
    private let lock = NSLock()
    private var frame: [Float] = []
    private var sampleRate = 16_000.0
    /// The pitch of each voiced stretch heard since the last sentence, with when it was heard.
    private var heard: [(date: Date, hertz: Double)] = []

    /// Below this pitch a voice reads as male, above `femaleAbove` as female (typical adult
    /// speaking pitch: about 85–155 Hz for men and 165–255 Hz for women).
    static let maleBelow = 155.0
    static let femaleAbove = 170.0

    /// Called on the capture queue with the audio sent to transcription.
    func push(_ buffer: AVAudioPCMBuffer) {
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }
        var samples = [Float](repeating: 0, count: count)
        if let channel = buffer.floatChannelData?[0] {
            for index in 0..<count { samples[index] = channel[index] }
        } else if let channel = buffer.int16ChannelData?[0] {
            for index in 0..<count { samples[index] = Float(channel[index]) / 32_768 }
        } else {
            return
        }
        let rate = buffer.format.sampleRate
        // About 64 ms per analysis: a few periods of even the deepest voice.
        let length = Int(rate * 0.064)
        var found: [Double] = []
        lock.lock()
        sampleRate = rate
        frame += samples
        while frame.count >= length {
            let window = Array(frame.prefix(length))
            frame.removeFirst(length / 2)
            lock.unlock()
            if let hertz = Self.pitch(of: window, sampleRate: rate) { found.append(hertz) }
            lock.lock()
        }
        let now = Date()
        heard += found.map { (now, $0) }
        // Only the last 15 seconds matter: a sentence never lasts longer than that.
        heard.removeAll { now.timeIntervalSince($0.date) > 15 }
        lock.unlock()
    }

    /// The median pitch since the previous call, which marks where the next sentence starts. Nil
    /// when too little voiced audio was heard to tell.
    func take() -> Double? {
        lock.lock()
        let values = heard.map(\.hertz).sorted()
        heard = []
        lock.unlock()
        guard values.count >= 4 else { return nil }
        return values[values.count / 2]
    }

    /// Male, female, or nil in the range where pitch doesn't say.
    static func gender(forPitch hertz: Double?) -> VoiceGender? {
        guard let hertz else { return nil }
        if hertz < maleBelow { return .male }
        if hertz > femaleAbove { return .female }
        return nil
    }

    /// The fundamental frequency of `samples` by autocorrelation, or nil when the stretch is too
    /// quiet or not voiced (silence, noise, consonants).
    static func pitch(of samples: [Float], sampleRate: Double) -> Double? {
        let count = samples.count
        var energy: Float = 0
        for sample in samples { energy += sample * sample }
        guard energy / Float(count) > 0.0001 else { return nil }  // about -40 dB

        // Human speaking pitch: 70 to 400 Hz.
        let shortest = Int(sampleRate / 400)
        let longest = min(Int(sampleRate / 70), count / 2)
        guard shortest < longest else { return nil }
        var correlation = [Float](repeating: 0, count: longest + 1)
        for lag in shortest...longest {
            var sum: Float = 0
            for index in 0..<(count - lag) { sum += samples[index] * samples[index + lag] }
            correlation[lag] = sum / energy
        }
        guard let best = (shortest...longest).max(by: { correlation[$0] < correlation[$1] }),
              correlation[best] > 0.45 else { return nil }
        // A voice also correlates at twice its period, sometimes as strongly: the shortest lag
        // that is nearly as good is the real period, so a high voice isn't taken for one an
        // octave lower.
        let period = (shortest...best).first { lag in
            correlation[lag] >= correlation[best] * 0.9
                && correlation[lag] >= correlation[max(shortest, lag - 1)]
                && correlation[lag] >= correlation[min(longest, lag + 1)]
        } ?? best
        return sampleRate / Double(period)
    }
}
