import Testing
@testable import MaraAI

@Suite("Delivery chart data")
struct DeliveryBreakdownTests {
    @Test func colorFollowsThePersonNotTheRanking() {
        // "Zoe" delivers the most, but colors are assigned alphabetically, so she stays in her slot.
        let data = (0..<5).map { _ in Fixtures.delivery("Zoe") } + [Fixtures.delivery("Ana")]
        let members = DeliveryBreakdown(deliveries: data, byWeek: false, periods: 14).members
        #expect(members.map(\.name) == ["Ana", "Zoe"])
        #expect(members.first { $0.name == "Zoe" }?.total == 5)
    }

    @Test func foldsTheNinthPersonIntoOthers() {
        let names = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
        let members = DeliveryBreakdown(deliveries: names.map { Fixtures.delivery($0) }, byWeek: false, periods: 14).members
        #expect(members.count == SeriesPalette.colors.count + 1)
        #expect(members.last?.id == SeriesPalette.otherID)
        #expect(members.last?.total == 2)
    }

    @Test func ignoresDeliveriesOutsideThePeriod() {
        let data = [Fixtures.delivery("Ana", daysAgo: 1), Fixtures.delivery("Ana", daysAgo: 40)]
        let breakdown = DeliveryBreakdown(deliveries: data, byWeek: false, periods: 14)
        #expect(breakdown.buckets.count == 14)
        #expect(breakdown.cells.reduce(0) { $0 + $1.count } == 1)
    }
}
