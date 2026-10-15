import Testing
@testable import MaraAI

@Suite("Microphone echo")
struct EchoFilterTests {
    @Test func theOthersHeardThroughTheSpeakersAreAnEcho() {
        let others = [(text: "We can review the contract on Thursday, before the demo.", secondsApart: 1.2)]
        #expect(EchoFilter.isEcho("we can review the contract on thursday", others: others))
    }

    @Test func aRecognitionSlightlyDifferentIsStillAnEcho() {
        let others = [(text: "Vamos manter o prazo atual e enviar a proposta antes da demo.", secondsApart: 0.5)]
        #expect(EchoFilter.isEcho("vamos manter prazo atual e mandar a proposta antes da demo", others: others))
    }

    @Test func accentsAndPunctuationDontMatter() {
        let others = [(text: "Está bem, então fica para quinta.", secondsApart: 0.0)]
        #expect(EchoFilter.isEcho("esta bem entao fica pra quinta", others: others))
    }

    @Test func yourOwnAnswerIsNotAnEcho() {
        let others = [(text: "Can you send the revised proposal before the demo?", secondsApart: 2.0)]
        #expect(!EchoFilter.isEcho("Sure, I'll send it tomorrow morning with the new numbers.", others: others))
    }

    @Test func anOldSentenceDoesntCount() {
        let others = [(text: "We can review the contract on Thursday.", secondsApart: 40.0)]
        #expect(!EchoFilter.isEcho("we can review the contract on thursday", others: others))
    }

    @Test func aShortReplyOnlyCountsWhenTheSamePhraseWasJustSaid() {
        #expect(EchoFilter.isEcho("Sounds good.", others: [(text: "Sounds good, let's move on.", secondsApart: 1.0)]))
        // The same words, but not together, or long enough ago to be your own reply.
        #expect(!EchoFilter.isEcho("Sounds good.", others: [(text: "It sounds like the demo is good.", secondsApart: 1.0)]))
        #expect(!EchoFilter.isEcho("Sounds good.", others: [(text: "Sounds good, let's move on.", secondsApart: 8.0)]))
    }

    @Test func aTheirSentenceThatFinishesLaterStillMatches() {
        let others = [(text: "We can review the contract on Thursday.", secondsApart: -2.0)]
        #expect(EchoFilter.isEcho("we can review the contract on thursday", others: others))
    }

    @Test func nothingFromTheOthersMeansNoEcho() {
        #expect(!EchoFilter.isEcho("I think we should keep the date.", others: []))
        #expect(!EchoFilter.isEcho("", others: [(text: "anything", secondsApart: 0.0)]))
    }
}

@Suite("Speakers in the summary")
@MainActor
struct SpeakerTranscriptTests {
    @Test func withTheMicrophoneEachLineSaysWhoSpoke() {
        var mine = CaptionModel.Segment(original: "I'll send the proposal tomorrow.")
        mine.speaker = .me
        let transcript = CaptionModel.summaryTranscript([CaptionModel.Segment(original: "Can you send the proposal?"), mine])
        let lines = transcript.split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].hasSuffix("] Others: Can you send the proposal?"))
        #expect(lines[1].hasSuffix("] Me: I'll send the proposal tomorrow."))
    }

    @Test func withoutTheMicrophoneTheTranscriptIsUnchanged() {
        let transcript = CaptionModel.summaryTranscript([CaptionModel.Segment(original: "Can you send the proposal?")])
        #expect(transcript.hasSuffix("] Can you send the proposal?"))
        #expect(!transcript.contains("Others:"))
    }
}
