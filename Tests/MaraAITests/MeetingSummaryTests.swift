import Testing
@testable import MaraAI

@Suite("Meeting summary")
struct MeetingSummaryTests {
    @Test func readsAConversation() {
        let raw = """
        ```json
        {"kind": "conversation", "title": "Delivery timeline review",
         "overview": "The team reviewed the timeline and agreed it is realistic.",
         "topics": [{"title": "Timeline", "summary": "Seen as realistic."}, {"title": " ", "summary": ""}],
         "decisions": ["Keep the current deadline.", "  "], "key_points": [], "open_questions": ["Who presents the demo?"]}
        ```
        """
        let summary = MeetingSummary.parse(raw)

        #expect(summary.kind == .conversation)
        #expect(summary.title == "Delivery timeline review")
        // Empty topics and blank list items are dropped.
        #expect(summary.topics == [MeetingSummary.Topic(title: "Timeline", summary: "Seen as realistic.")])
        #expect(summary.decisions == ["Keep the current deadline."])
        #expect(summary.openQuestions == ["Who presents the demo?"])
    }

    @Test func readsAPresentation() {
        let raw = """
        {"kind": "presentation", "title": "Intro to Swift Testing", "overview": "A talk on the new test library.",
         "topics": [], "decisions": [], "key_points": ["Tests are plain functions."], "open_questions": []}
        """
        let summary = MeetingSummary.parse(raw)

        #expect(summary.kind == .presentation)
        #expect(summary.kindLabel == "Apresentação")
        #expect(summary.keyPoints == ["Tests are plain functions."])
    }

    @Test func keepsTheTextWhenTheAnswerIsNotJSON() {
        let summary = MeetingSummary.parse("Sorry, I could not do it.")

        #expect(summary.overview == "Sorry, I could not do it.")
        #expect(summary.title == "Resumo da reunião")
        #expect(summary.topics.isEmpty)
    }

    @Test func writesMarkdownWithoutEmptySections() {
        let summary = MeetingSummary(
            kind: .conversation, title: "Weekly sync", overview: "Short sync.",
            topics: [.init(title: "Release", summary: "Ships Friday.")],
            decisions: ["Ship on Friday."], keyPoints: [], openQuestions: []
        )
        let markdown = summary.markdown(details: "14 Oct 2026 · 30 min")

        #expect(markdown.hasPrefix("# Weekly sync\n\n_Conversa entre várias pessoas · 14 Oct 2026 · 30 min_"))
        #expect(markdown.contains("## Assuntos\n\n**Release**\nShips Friday."))
        #expect(markdown.contains("## Decisões\n\n- Ship on Friday."))
        #expect(!markdown.contains("Ideias principais"))
        #expect(!markdown.contains("Perguntas em aberto"))
    }

    @Test func splitsLongTranscriptsOnLineBreaks() {
        let lines = (1...10).map { "[10:\($0)] " + String(repeating: "word ", count: 20) }
        let transcript = lines.joined(separator: "\n")
        let parts = Translator.split(transcript, limit: 300)

        #expect(parts.count > 1)
        #expect(parts.allSatisfy { $0.count <= 300 })
        // Nothing is lost or reordered.
        #expect(parts.joined(separator: "\n") == transcript)
        #expect(Translator.split("short", limit: 300) == ["short"])
    }
}
