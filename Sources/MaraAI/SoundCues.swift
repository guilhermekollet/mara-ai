import AVFoundation

/// Short, soft, low-pitched cues for session events. They are synthesized on the fly (no audio
/// files to ship): a few sine notes with a touch of overtone for warmth, a gentle attack and a
/// natural decay, kept quiet. Mara's own sound is excluded from the capture
/// (`excludesCurrentProcessAudio`), so the cues never end up in a transcript.
@MainActor
final class SoundCues {
    enum Cue: CaseIterable {
        case start, stop, standby, resume, summaryReady, failure
    }

    /// Turned off in Settings › Appearance.
    var enabled = true

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    /// Stops the audio engine shortly after the last cue, so the Mac's audio isn't kept awake.
    private var idleStop: Task<Void, Never>?

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play(_ cue: Cue, evenIfDisabled: Bool = false) {
        guard enabled || evenIfDisabled, let buffer = buffer(for: cue) else { return }
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
        idleStop?.cancel()
        idleStop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            self.player.stop()
            self.engine.stop()
        }
    }

    /// A note: pitch in hertz, when it starts and how long it rings, in seconds.
    private typealias Note = (frequency: Double, start: Double, length: Double)

    /// The cues: rising for start, falling for stop, a single low note to go on hold, a short one to
    /// come back, a gentle fourth when the summary is ready and a low double tap for failures.
    private static func notes(for cue: Cue) -> (notes: [Note], volume: Double) {
        switch cue {
        case .start: return ([(220.00, 0, 0.38), (329.63, 0.09, 0.45)], 0.16) // A3 → E4
        case .stop: return ([(329.63, 0, 0.38), (220.00, 0.09, 0.5)], 0.16) // E4 → A3
        case .standby: return ([(196.00, 0, 0.55)], 0.12) // G3
        case .resume: return ([(246.94, 0, 0.32)], 0.13) // B3
        case .summaryReady: return ([(293.66, 0, 0.38), (392.00, 0.11, 0.55)], 0.15) // D4 → G4
        case .failure: return ([(164.81, 0, 0.18), (164.81, 0.15, 0.3)], 0.15) // E3, twice
        }
    }

    private func buffer(for cue: Cue) -> AVAudioPCMBuffer? {
        if let cached = buffers[cue] { return cached }
        let (notes, volume) = Self.notes(for: cue)
        let rate = format.sampleRate
        let total = (notes.map { $0.start + $0.length }.max() ?? 0) + 0.05
        let frames = AVAudioFrameCount(total * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let samples = buffer.floatChannelData?[0] else {
            return nil
        }
        buffer.frameLength = frames
        for index in 0..<Int(frames) { samples[index] = 0 }
        for note in notes {
            let first = Int(note.start * rate)
            let count = Int(note.length * rate)
            for offset in 0..<count where first + offset < Int(frames) {
                let t = Double(offset) / rate
                // 12 ms attack, then an exponential decay that fades out by the end of the note.
                let attack = min(1, t / 0.012)
                let decay = exp(-t / (note.length * 0.32))
                let tail = min(1, (note.length - t) / 0.03)
                let phase = 2 * Double.pi * note.frequency * t
                // Mostly the fundamental, with soft second and third harmonics for a warmer tone.
                let wave = sin(phase) + 0.22 * sin(2 * phase) + 0.06 * sin(3 * phase)
                samples[first + offset] += Float(wave * attack * decay * tail * volume)
            }
        }
        buffers[cue] = buffer
        return buffer
    }
}
