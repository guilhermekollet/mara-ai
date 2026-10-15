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
