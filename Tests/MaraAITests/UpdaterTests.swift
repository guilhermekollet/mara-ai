import Testing
@testable import MaraAI

@Suite("Updater")
struct UpdaterTests {
    @Test func comparesVersionsNumberByNumber() {
        #expect(Updater.isNewer("0.3.0", than: "0.2.0"))
        #expect(Updater.isNewer("0.10.0", than: "0.9.2"))
        #expect(Updater.isNewer("1.0", than: "0.9.9"))
        #expect(!Updater.isNewer("0.2.0", than: "0.2.0"))
        #expect(!Updater.isNewer("0.2", than: "0.2.0"))
        #expect(!Updater.isNewer("0.1.9", than: "0.2.0"))
    }

    @Test func acceptsOnlyPlainVersions() {
        #expect(Updater.isPlainVersion("0.3.0"))
        #expect(Updater.isPlainVersion("12"))
        #expect(!Updater.isPlainVersion("../../Documents"))
        #expect(!Updater.isPlainVersion("0.3.0-beta"))
        #expect(!Updater.isPlainVersion("0..3"))
        #expect(!Updater.isPlainVersion(""))
    }

    @Test func acceptsOnlyAnUntouchedSignedArchive() {
        #expect(updateSignatureHolds(afterTampering: false))
        #expect(!updateSignatureHolds(afterTampering: true))
    }

    @Test func rejectsAMalformedKey() {
        #expect(!Updater.isSigned(.init(), signature: .init(), publicKey: "not a key"))
    }
}
