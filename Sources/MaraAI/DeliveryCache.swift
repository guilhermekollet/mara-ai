import Foundation

/// The team's completed issues, kept on disk: the deliveries chart opens with them right away, and
/// each refresh only asks Linear for the issues that changed since the last read instead of
/// reading nine weeks of issues again.
struct DeliveryCache: Codable, Equatable {
    struct Entry: Codable, Equatable {
        var completedAt: Date
        var memberID: String
        var memberName: String
    }

    let teamID: String
    /// When the last successful read started; the next one asks for what changed since then.
    private(set) var syncedAt: Date
    /// When everything was last read from scratch.
    private(set) var fullSyncAt: Date
    /// Completed issues by Linear issue ID.
    private(set) var issues: [String: Entry] = [:]

    /// How far back the chart goes: 9 weeks.
    static let window: TimeInterval = 63 * 86_400
    /// A full read once a day catches what changed-since reads can't see, such as deleted issues.
    static let fullSyncInterval: TimeInterval = 86_400
    /// Changes are read from a little before the last read, in case the Mac's clock and Linear's disagree.
    static let overlap: TimeInterval = 300

    /// A cache built from a full read of what was completed in the window.
    init(teamID: String, fullRead: [LinearClient.Completion], at now: Date) {
        self.teamID = teamID
        syncedAt = now
        fullSyncAt = now
        apply(fullRead, at: now)
    }

    /// Where the next changed-since read starts.
    var changesSince: Date { syncedAt.addingTimeInterval(-Self.overlap) }

    func needsFullSync(at now: Date) -> Bool {
        now.timeIntervalSince(fullSyncAt) >= Self.fullSyncInterval || now < fullSyncAt
    }

    /// Merges a read: completed issues are added or updated, reopened ones removed, and anything
    /// older than the window dropped.
    mutating func apply(_ completions: [LinearClient.Completion], at now: Date) {
        for completion in completions {
            if let completedAt = completion.completedAt {
                issues[completion.id] = Entry(completedAt: completedAt, memberID: completion.memberID, memberName: completion.memberName)
            } else {
                issues[completion.id] = nil
            }
        }
        let start = now.addingTimeInterval(-Self.window)
        issues = issues.filter { $0.value.completedAt >= start }
        syncedAt = now
    }

    var deliveries: [Delivery] {
        issues.values
            .map { Delivery(date: $0.completedAt, memberID: $0.memberID, memberName: $0.memberName) }
            .sorted { $0.date < $1.date }
    }

    // MARK: Disk

    private static let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MaraAI/entregas-linear.json")

    /// The cache saved for `teamID`, if there is one.
    static func load(teamID: String) -> DeliveryCache? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let cache = try? decoder.decode(DeliveryCache.self, from: data), cache.teamID == teamID else { return nil }
        return cache
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return }
        try? FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: Self.url, options: .atomic)
    }

    /// Removes the saved cache, for when the Linear key is removed.
    static func delete() {
        try? FileManager.default.removeItem(at: url)
    }
}
