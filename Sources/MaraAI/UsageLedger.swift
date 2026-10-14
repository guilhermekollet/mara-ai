import Foundation

/// One GPT call, with the tokens OpenAI itself reported in the response.
struct UsageEntry: Codable {
    let date: Date
    let model: String
    let inputTokens: Int
    let cachedTokens: Int
    let outputTokens: Int
    let reasoningTokens: Int
    let milliseconds: Int
    /// Estimated cost using the prices configured at the time of the call.
    let costUSD: Double
}

struct UsageTotals {
    var calls = 0
    var inputTokens = 0
    var outputTokens = 0
    var costUSD = 0.0
}

/// Permanent usage log: one JSON per line, append-only, so that a failure
/// in the middle of a write never corrupts the history.
@MainActor
final class UsageLedger: ObservableObject {
    @Published private(set) var entries: [UsageEntry] = []

    static let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MaraAI/consumo.jsonl")

    private let encoder = JSONEncoder()
    private var needsLeadingNewline = false
    /// Set when a write fails, so the screen can warn that the history is incomplete.
    @Published private(set) var writeError: String?

    init() {
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let text = try? String(contentsOf: Self.url, encoding: .utf8) else { return }
        // A truncated line at the end (power loss) must not swallow the next write.
        needsLeadingNewline = !text.isEmpty && !text.hasSuffix("\n")
        entries = text.split(separator: "\n").compactMap { try? decoder.decode(UsageEntry.self, from: Data($0.utf8)) }
    }

    func record(_ entry: UsageEntry) {
        entries.append(entry)
        do {
            var line = try encoder.encode(entry)
            line.append(0x0A)
            if needsLeadingNewline { line.insert(0x0A, at: 0) }
            try FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: Self.url.path) {
                FileManager.default.createFile(atPath: Self.url.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: Self.url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
            try handle.synchronize()
            needsLeadingNewline = false
            writeError = nil
        } catch {
            writeError = error.localizedDescription
        }
    }

    func totals(since start: Date?) -> UsageTotals {
        entries.reduce(into: UsageTotals()) { totals, entry in
            if let start, entry.date < start { return }
            totals.calls += 1
            totals.inputTokens += entry.inputTokens
            totals.outputTokens += entry.outputTokens
            totals.costUSD += entry.costUSD
        }
    }
}
