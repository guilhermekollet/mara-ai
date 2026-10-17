import AVFoundation

/// The pitch of a voice, so each piece can be read with a voice like the speaker's: deep voices
/// with a male voice, high ones with a female voice. Measured on the exact audio of what is read.
enum SpeakerPitch {
    /// Below this pitch a voice reads as male, above `femaleAbove` as female (typical adult
    /// speaking pitch: about 85–155 Hz for men and 165–255 Hz for women). In between, one piece
    /// alone doesn't say.
    static let maleBelow = 155.0
    static let femaleAbove = 170.0
    /// Over everything a person said, the median is reliable enough to split right in the middle.
    static let middle = 162.0

    /// The median pitch of the voiced stretches in `samples`, or nil when too little of it is voiced.
    static func median(of samples: [Float], sampleRate: Double) -> Double? {
        // About 64 ms per analysis, half overlapping: a few periods of even the deepest voice.
        let length = Int(sampleRate * 0.064)
        guard length > 0, samples.count >= length else { return nil }
        var found: [Double] = []
        var start = 0
        while start + length <= samples.count {
            if let hertz = pitch(of: Array(samples[start..<(start + length)]), sampleRate: sampleRate) { found.append(hertz) }
            start += length / 2
        }
        guard found.count >= 4 else { return nil }
        return found.sorted()[found.count / 2]
    }

    /// Male, female, or nil in the range where one piece's pitch doesn't say.
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

    /// A person's gender from the median of everything they said, split at `middle`.
    static func gender(forPersonPitch hertz: Double?) -> VoiceGender? {
        hertz.map { $0 < middle ? .male : .female }
    }
}
