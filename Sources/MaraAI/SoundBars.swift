import AVFoundation
import SwiftUI

/// Measures the meeting audio's volume. Capture delivers the volume on another queue; a timer on
/// the main queue reads the latest value about 20 times per second, enough to animate.
final class AudioMeter: ObservableObject {
    /// Smoothed volume, from 0 (silence) to 1 (loud speech).
    @Published private(set) var level = 0.0
    /// Advances on every read, so the bars keep varying even at a constant volume.
    @Published private(set) var tick = 0

    private let lock = NSLock()
    private var latest = 0.0
    private var timer: Timer?

    /// Called on the capture queue with each audio buffer.
    func push(_ buffer: AVAudioPCMBuffer) {
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }
        var sum = 0.0
        if let channel = buffer.int16ChannelData?[0] {
            for index in 0..<frames {
                let sample = Double(channel[index]) / 32_768
                sum += sample * sample
            }
        } else if let channel = buffer.floatChannelData?[0] {
            for index in 0..<frames { sum += Double(channel[index]) * Double(channel[index]) }
        }
        let rms = (sum / Double(frames)).squareRoot()
        lock.lock()
        latest = max(latest, rms)
        lock.unlock()
    }

    @MainActor
    func setActive(_ active: Bool) {
        timer?.invalidate()
        timer = nil
        level = 0
        guard active else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.read() }
        }
    }

    @MainActor
    private func read() {
        lock.lock()
        let rms = latest
        latest = 0
        lock.unlock()
        // Speech sits between 0.02 and 0.2 RMS; the curve spreads that band across the 0 to 1 range.
        let target = min(1, pow(rms * 8, 0.6))
        level = level * 0.55 + target * 0.45
        tick += 1
    }
}

/// Sound bars that rise and fall with the meeting's actual volume. In silence they ripple gently
/// to show that Mara is listening.
struct SoundBars: View {
    @ObservedObject var meter: AudioMeter
    var height: CGFloat = 14
    var color = Theme.accent

    private static let weights = [0.55, 0.85, 1.0, 0.75, 0.5]
    private static let speeds = [0.9, 1.3, 0.7, 1.1, 0.8]

    var body: some View {
        HStack(alignment: .center, spacing: height * 0.16) {
            ForEach(0..<Self.weights.count, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(width: max(2, height * 0.18), height: height * amount(index))
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.16, dampingFraction: 0.62), value: meter.tick)
        .accessibilityLabel("Ouvindo")
    }

    private func amount(_ index: Int) -> Double {
        let time = Double(meter.tick)
        let idle = 0.16 + 0.07 * sin(time * 0.12 + Double(index) * 0.9)
        let wobble = 0.65 + 0.35 * sin(time * Self.speeds[index] + Double(index) * 1.7)
        return min(1, max(0.14, idle + meter.level * Self.weights[index] * wobble))
    }
}
