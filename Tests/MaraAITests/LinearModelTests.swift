import Testing
@testable import MaraAI

@Suite("Linear model")
struct LinearModelTests {
    @Test(arguments: [
        ("backlog", "Backlog", DemandStatus.backlog),
        ("triage", "Triage", .backlog),
        ("unstarted", "Todo", .todo),
        ("started", "In Progress", .inProgress),
        ("started", "In Review", .inReview),
        ("started", "Code review", .inReview),
        ("completed", "Done", .done),
        ("canceled", "Canceled", .canceled),
    ])
    func mapsLinearStates(type: String, name: String, expected: DemandStatus) {
        #expect(DemandStatus.fromLinear(type: type, name: name) == expected)
    }

    @Test func ranksUrgentFirstAndNoPriorityLast() {
        let sorted = [0, 4, 1, 3, 2].sorted { DemandPriority.rank($0) < DemandPriority.rank($1) }
        #expect(sorted == [1, 2, 3, 4, 0])
    }
}
