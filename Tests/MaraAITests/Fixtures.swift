// Test helpers that need Foundation and AVFoundation live here, in a file that does not import
// Testing: with only the Command Line Tools installed (no Xcode), importing Testing next to
// Foundation fails because the `_Testing_Foundation` overlay is missing. Test files import just
// Testing and MaraAI and talk to these helpers through plain values.
import AVFoundation
import Foundation
@testable import MaraAI

enum Fixtures {
    static func delivery(_ name: String, daysAgo: Int = 0) -> Delivery {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return Delivery(date: date, memberID: name, memberName: name)
    }

    /// A fixed "now" for the delivery cache tests, and moments relative to it.
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static func hoursLater(_ hours: Double) -> Date { now.addingTimeInterval(hours * 3_600) }

    /// A Linear issue completed `daysAgo` days before `now` by `member`, or reopened when `daysAgo` is nil.
    static func completion(_ id: String, daysAgo: Double?, member: String = "Ana") -> LinearClient.Completion {
        LinearClient.Completion(
            id: id, completedAt: daysAgo.map { now.addingTimeInterval(-$0 * 86_400) }, memberID: member, memberName: member
        )
    }

    /// Seconds between the last read and where the next changed-since read starts.
    static func overlapSeconds(_ cache: DeliveryCache) -> Double { cache.syncedAt.timeIntervalSince(cache.changesSince) }
}

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
