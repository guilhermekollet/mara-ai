import Testing
@testable import MaraAI

@Suite("Reading aloud: the queue")
struct ReadoutQueueTests {
    @Test func readsInOrder() {
        #expect(readoutOrder(pushedSecondsAgo: [2, 1]) == [0, 1])
    }

    @Test func keepsOnlyTheNewestTwoWaiting() {
        #expect(readoutOrder(pushedSecondsAgo: [4, 3, 2, 1]) == [2, 3])
    }

    @Test func skipsWhatWaitedTooLong() {
        #expect(readoutOrder(pushedSecondsAgo: [12, 3]) == [1])
    }

    @Test func speedsUpOnlyWhileFallingBehind() {
        #expect(ReadoutQueue.boost(waiting: 0) == 1)
        #expect(ReadoutQueue.boost(waiting: 1) > 1)
        #expect(ReadoutQueue.boost(waiting: 5) == ReadoutQueue.boost(waiting: ReadoutQueue.maxWaiting))
    }
}

@Suite("Reading aloud: the speaker's pitch")
struct SpeakerPitchTests {
    @Test(arguments: [95.0, 120.0, 150.0, 190.0, 220.0, 260.0])
    func findsTheFundamental(hertz: Double) throws {
        let found = try #require(SpeakerPitch.pitch(of: voiceTone(hertz), sampleRate: 16_000))
        #expect(abs(found - hertz) / hertz < 0.05, "found \(found) Hz for \(hertz) Hz")
    }

    @Test func silenceAndNoiseHaveNoPitch() {
        #expect(SpeakerPitch.pitch(of: [Float](repeating: 0, count: 1_024), sampleRate: 16_000) == nil)
        #expect(SpeakerPitch.pitch(of: noise(count: 1_024), sampleRate: 16_000) == nil)
    }

    @Test func deepVoicesAreReadAsMaleAndHighOnesAsFemale() {
        #expect(SpeakerPitch.gender(forPitch: 110) == .male)
        #expect(SpeakerPitch.gender(forPitch: 210) == .female)
        #expect(SpeakerPitch.gender(forPitch: 162) == nil)
        #expect(SpeakerPitch.gender(forPitch: nil) == nil)
    }

    @Test func takesEachSentencesPitchFromTheCapturedAudio() {
        let (first, second) = pitchesTaken(afterHearing: 210)
        #expect(SpeakerPitch.gender(forPitch: first) == .female)
        #expect(second == nil)
        #expect(SpeakerPitch.gender(forPitch: pitchesTaken(afterHearing: 115).first) == .male)
    }
}

@Suite("Reading aloud: voices")
struct ReadoutVoiceTests {
    @Test func longSentencesAreSplitForKokoro() {
        let sentence = "Antes de fechar, queria lembrar que o relatório de vendas do terceiro trimestre precisa estar pronto até quarta-feira, porque a diretoria vai apresentar os números para os investidores na quinta de manhã."
        let pieces = Synthesizer.clauses(of: sentence)
        #expect(pieces.count > 1)
        #expect(pieces.allSatisfy { $0.count <= 90 })
        #expect(pieces.joined(separator: " ") == sentence)
    }

    @Test func shortSentencesStayWhole() {
        #expect(Synthesizer.clauses(of: "So let's move it to Friday.") == ["So let's move it to Friday."])
    }

    @Test(arguments: ["pt", "en", "es"])
    func everyLanguageHasAFemaleAndAMaleVoice(language: String) {
        #expect(!ReadoutCatalog.voices(for: language, gender: .female).isEmpty)
        #expect(!ReadoutCatalog.voices(for: language, gender: .male).isEmpty)
    }

    @Test func aVoiceFromAnotherLanguageFallsBackToTheDefault() {
        #expect(ReadoutCatalog.voice(for: "pt", gender: .male, preferred: "am_adam").id == "M1")
        #expect(ReadoutCatalog.voice(for: "en", gender: .male, preferred: "am_adam").id == "am_adam")
    }

    @Test func portugueseIsReadBySupertonicAndTheRestByKokoro() {
        #expect(VoiceEngine.reading("pt") == .supertonic)
        #expect(VoiceEngine.reading("en") == .kokoro)
        #expect(VoiceEngine.reading("es") == .kokoro)
    }

    /// Kokoro's offered voices must be in its download, or the voice would silently not load.
    @Test func kokoroDownloadsEveryVoiceItOffers() {
        let downloaded = Set(VoiceModelManifest.kokoro.files.map(\.path))
        for language in ["en", "es"] {
            for voice in ReadoutCatalog.voices(for: language) {
                #expect(downloaded.contains("voices/\(voice.id).json"), "\(voice.id)")
            }
        }
    }

    @Test func supertonicDownloadsEveryVoiceItOffers() {
        let downloaded = Set(VoiceModelManifest.supertonic.files.map(\.path))
        for voice in ReadoutCatalog.voices(for: "pt") {
            #expect(downloaded.contains("voice_styles/\(voice.id).json"), "\(voice.id)")
        }
    }

    @Test(arguments: VoiceEngine.allCases)
    func manifestsArePinnedAndChecked(engine: VoiceEngine) {
        let manifest = engine.manifest
        #expect(manifest.revision.count == 40)
        #expect(Set(manifest.files.map(\.path)).count == manifest.files.count)
        // Every model file over 1 MB is checked by its hash.
        #expect(manifest.files.filter { $0.size > 1_000_000 && !$0.path.hasSuffix(".json") }.allSatisfy { $0.sha256?.count == 64 })
    }
}

@Suite("Reading aloud: downloads")
struct VoiceDownloadTests {
    @Test func acceptsAFileThatMatches() {
        #expect(verifiesDownload("mara", size: 4))
        #expect(verifiesDownload("mara", size: 4, sha256: maraSHA256))
    }

    @Test func rejectsAFileCutShortOrChanged() {
        #expect(!verifiesDownload("mar", size: 4))
        #expect(!verifiesDownload("maré", size: 4, sha256: maraSHA256))
        #expect(!verifiesDownload("mara", size: 4, sha256: String(repeating: "0", count: 64)))
    }
}
