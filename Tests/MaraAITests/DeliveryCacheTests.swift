import Testing
@testable import MaraAI

@Suite("Deliveries cache")
struct DeliveryCacheTests {
    private func cache(_ completions: [LinearClient.Completion]) -> DeliveryCache {
        DeliveryCache(teamID: "team", fullRead: completions, at: Fixtures.now)
    }

    @Test func keepsWhatTheFullReadFound() {
        let cache = cache([Fixtures.completion("A", daysAgo: 1), Fixtures.completion("B", daysAgo: 3, member: "Bia")])
        #expect(cache.deliveries.map(\.memberName) == ["Bia", "Ana"])
    }

    @Test func changesUpdateAndAddIssues() {
        var cache = cache([Fixtures.completion("A", daysAgo: 1)])
        cache.apply(
            [Fixtures.completion("A", daysAgo: 1, member: "Bia"), Fixtures.completion("C", daysAgo: 0)],
            at: Fixtures.hoursLater(1)
        )
        #expect(cache.deliveries.count == 2)
        #expect(cache.deliveries.map(\.memberName).sorted() == ["Ana", "Bia"])
    }

    @Test func reopenedIssuesLeaveTheChart() {
        var cache = cache([Fixtures.completion("A", daysAgo: 1), Fixtures.completion("B", daysAgo: 2)])
        cache.apply([Fixtures.completion("A", daysAgo: nil)], at: Fixtures.hoursLater(1))
        #expect(cache.deliveries.count == 1)
    }

    @Test func dropsIssuesOlderThanNineWeeks() {
        let cache = cache([Fixtures.completion("A", daysAgo: 62), Fixtures.completion("B", daysAgo: 64)])
        #expect(cache.deliveries.count == 1)
    }

    @Test func readsEverythingAgainOnceADay() {
        var cache = cache([])
        #expect(!cache.needsFullSync(at: Fixtures.hoursLater(23)))
        cache.apply([], at: Fixtures.hoursLater(23))
        #expect(cache.needsFullSync(at: Fixtures.hoursLater(24)))
    }

    @Test func nextReadOverlapsTheLastOne() {
        #expect(Fixtures.overlapSeconds(cache([])) == 300)
    }
}
