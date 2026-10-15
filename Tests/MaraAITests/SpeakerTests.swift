import Testing
@testable import MaraAI

@Suite("Telling speakers apart")
struct SpeakerTests {
    @Test func sentencesFromTheSamePeopleGoTogether() {
        let meeting = [0, 1, 0, 2, 1, 1, 0, 2, 2, 0]
        let assigned = clusteredSpeakers(of: meeting)
        // The same person always lands in the same group, and different people in different ones.
        for (a, b) in zip(meeting.indices, meeting.indices.dropFirst()) {
            #expect((meeting[a] == meeting[b]) == (assigned[a] == assigned[b]))
        }
        #expect(Set(assigned).count == 3)
    }

    @Test func noMoreThanTheMaximumOfPeopleAreKept() {
        let meeting = Array(0..<12)
        #expect(Set(clusteredSpeakers(of: meeting)).count == SpeakerClusters.maxSpeakers)
    }

    @Test func eachGenderGetsTwoVoicesInTurn() {
        var cast = VoiceCast()
        #expect(cast.slot(for: 0, gender: .female) == 0)
        #expect(cast.slot(for: 1, gender: .male) == 0)
        #expect(cast.slot(for: 2, gender: .female) == 1)
        // A third woman shares the first woman's voice; everyone keeps theirs.
        #expect(cast.slot(for: 3, gender: .female) == 0)
        #expect(cast.slot(for: 2, gender: .female) == 1)
        #expect(cast.slot(for: 0, gender: .female) == 0)
    }

    @Test func aSpeakerWhoseGenderChangesMovesToTheOtherVoices() {
        var cast = VoiceCast()
        _ = cast.slot(for: 0, gender: .male)
        #expect(cast.slot(for: 1, gender: .male) == 1)
        _ = cast.slot(for: 0, gender: .female)
        // With speaker 0 gone from the men, speaker 1 is now the first man.
        #expect(cast.slot(for: 1, gender: .male) == 0)
    }

    @Test func aSentencesTimeRangeFindsItsAudio() {
        #expect(clippedSeconds(feeding: 5, from: 2, to: 4) == [2, 3])
    }

    @Test func audioOlderThanHalfAMinuteIsGone() {
        #expect(clippedSeconds(feeding: 40, from: 5, to: 12) == [10, 11])
        #expect(clippedSeconds(feeding: 40, from: 1, to: 5).isEmpty)
    }

    @Test func aSecondSpeakerOfTheSameGenderReadsWithAnotherVoice() {
        for language in ["pt", "en"] {
            let voices = ReadoutCatalog.voices(for: language, gender: .female)
            #expect(voices.count >= 2, "\(language)")
        }
    }
}

@Suite("People in the summary")
@MainActor
struct PeopleTranscriptTests {
    @Test func toldApartEachLineSaysWhichPerson() {
        var first = CaptionModel.Segment(original: "Can you send the proposal?")
        first.person = 1
        var second = CaptionModel.Segment(original: "Sure, by Friday.")
        second.person = 2
        let unknown = CaptionModel.Segment(original: "Ok.")
        let lines = CaptionModel.summaryTranscript([first, second, unknown]).split(separator: "\n")
        #expect(lines[0].hasSuffix("] Person 1: Can you send the proposal?"))
        #expect(lines[1].hasSuffix("] Person 2: Sure, by Friday."))
        #expect(lines[2].hasSuffix("] Others: Ok."))
        #expect(CaptionModel.namesSpeakers([first]))
    }

    @Test func withoutPeopleOrMicrophoneTheSummaryDoesntNameSpeakers() {
        #expect(!CaptionModel.namesSpeakers([CaptionModel.Segment(original: "Hello.")]))
    }
}
