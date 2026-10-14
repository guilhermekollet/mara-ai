import Testing
@testable import MaraAI

@Suite("Meeting summary parsing")
struct MeetingSummaryTests {
    @Test func readsSectionsAndActions() {
        let raw = """
        ```json
        {"pontos": ["Contract review"], "decisoes": [], "pendencias": [
          {"titulo": "Send the revised proposal", "responsavel": "Sarah", "prazo": "Thursday", "prazo_data": "2026-10-15"},
          {"titulo": "Schedule a follow-up", "responsavel": "", "prazo": "", "prazo_data": "tomorrow"},
          {"titulo": "   "}
        ]}
        ```
        """
        let summary = MeetingSummary.parse(raw)

        #expect(summary.actions.count == 2)
        #expect(summary.actions[0].owner == "Sarah")
        #expect(summary.actions[0].dueDate == "2026-10-15")
        // Only ISO dates are accepted as due dates; free text stays out.
        #expect(summary.actions[1].dueDate == nil)
        #expect(summary.text.contains("Decisões\n- Nada registrado."))
        #expect(summary.text.contains("- Send the revised proposal (responsável: Sarah; prazo: Thursday)"))
    }

    @Test func fallsBackToRawTextWhenNotJSON() {
        let summary = MeetingSummary.parse("Sorry, I could not do it.")
        #expect(summary.text == "Sorry, I could not do it.")
        #expect(summary.actions.isEmpty)
    }
}
