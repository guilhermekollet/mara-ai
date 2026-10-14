import Foundation

/// A glossary term. `rendering` is how it should appear in the caption; empty means
/// "keep it exactly as is".
struct GlossaryEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var term = ""
    var rendering = ""

    private static let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MaraAI/glossario.json")

    static func load() -> [GlossaryEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([GlossaryEntry].self, from: data)) ?? []
    }

    static func save(_ entries: [GlossaryEntry]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(entries) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
