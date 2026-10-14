import Testing
@testable import MaraAI

@Suite("Standby gate")
struct ActivityGateTests {
    @Test func passesAudioThroughWhileListening() {
        let harness = GateHarness()
        #expect(harness.feed(loud: true) == 0.1)
    }

    @Test func holdsTheLastSecondAndAHalfWhilePausedAndReleasesItOnResume() {
        let harness = GateHarness()
        harness.gate.setPaused(true)
        var delivered = 0.0
        for _ in 0..<40 { delivered += harness.feed(loud: false) } // 4 s of silence
        #expect(delivered == 0)

        harness.gate.setPaused(false)
        let released = harness.feed(loud: true)
        #expect(released >= 1.5 && released <= 1.7)
    }

    @Test func soundResetsTheSilenceTimerEvenWhilePaused() {
        let harness = GateHarness()
        harness.gate.setPaused(true)
        _ = harness.feed(loud: true)
        #expect(harness.gate.secondsSinceSound < 0.1)
    }
}
