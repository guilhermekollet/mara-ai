import Foundation

/// What the meeting was about, as the GPT summarizes it: whether it was a conversation between
/// several people or someone presenting, an overview, the topics in the order they came up, and,
/// depending on the kind, the decisions or the key points, plus anything left open.
struct MeetingSummary: Equatable {
    enum Kind: String {
        case conversation, presentation
    }

    struct Topic: Equatable {
        var title: String
        var summary: String
    }

    var kind: Kind
    var title: String
    var overview: String
    var topics: [Topic]
    var decisions: [String]
    var keyPoints: [String]
    var openQuestions: [String]

    var kindLabel: String {
        switch kind {
        case .conversation: return "Conversa entre várias pessoas"
        case .presentation: return "Apresentação"
        }
    }

    // MARK: Reading the model's answer

    /// The JSON the model returns. Every field is optional here so a slightly off answer still
    /// produces a summary instead of an error.
    private struct Wire: Decodable {
        struct WireTopic: Decodable {
            var title: String?
            var summary: String?
        }

        var kind: String?
        var title: String?
        var overview: String?
        var topics: [WireTopic]?
        var decisions: [String]?
        var key_points: [String]?
        var open_questions: [String]?
    }

    /// Reads the model's JSON answer. If it isn't the expected JSON, its text becomes the overview,
    /// so nothing the model wrote is lost.
    static func parse(_ raw: String) -> MeetingSummary {
        var body = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("```") {
            body = body.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
            if let fence = body.range(of: "```", options: .backwards) { body = String(body[..<fence.lowerBound]) }
        }
        let clean = { (lines: [String]?) in
            (lines ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        guard let data = body.data(using: .utf8), let wire = try? JSONDecoder().decode(Wire.self, from: data),
              let overview = wire.overview?.trimmingCharacters(in: .whitespacesAndNewlines), !overview.isEmpty
        else {
            return MeetingSummary(
                kind: .conversation, title: "Resumo da reunião", overview: raw.trimmingCharacters(in: .whitespacesAndNewlines),
                topics: [], decisions: [], keyPoints: [], openQuestions: []
            )
        }
        let topics = (wire.topics ?? []).compactMap { topic -> Topic? in
            let title = (topic.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = (topic.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty && summary.isEmpty ? nil : Topic(title: title, summary: summary)
        }
        let title = (wire.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return MeetingSummary(
            kind: Kind(rawValue: wire.kind ?? "") ?? .conversation,
            title: title.isEmpty ? "Resumo da reunião" : title,
            overview: overview,
            topics: topics,
            decisions: clean(wire.decisions),
            keyPoints: clean(wire.key_points),
            openQuestions: clean(wire.open_questions)
        )
    }

    /// The answer's shape, for OpenAI's Structured Outputs: with it the model can only reply with
    /// this JSON. Every field is required; lists that don't apply come back empty.
    static let schema: [String: Any] = {
        let text: [String: Any] = ["type": "string"]
        let list: [String: Any] = ["type": "array", "items": text]
        return [
            "type": "object",
            "additionalProperties": false,
            "required": ["kind", "title", "overview", "topics", "decisions", "key_points", "open_questions"],
            "properties": [
                "kind": ["type": "string", "enum": ["conversation", "presentation"]],
                "title": text,
                "overview": text,
                "topics": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["title", "summary"],
                        "properties": ["title": text, "summary": text],
                    ] as [String: Any],
                ] as [String: Any],
                "decisions": list,
                "key_points": list,
                "open_questions": list,
            ] as [String: Any],
        ]
    }()

    // MARK: Markdown

    /// The summary as Markdown, for copying, sharing and the file saved next to the transcript.
    /// `details` is a line such as the date and duration of the meeting.
    func markdown(details: String? = nil) -> String {
        var lines = ["# \(title)", ""]
        lines.append("_\(kindLabel)\(details.map { " · \($0)" } ?? "")_")
        lines += ["", overview]
        if !topics.isEmpty {
            lines += ["", "## Assuntos"]
            for topic in topics {
                lines += ["", "**\(topic.title)**", topic.summary]
            }
        }
        let list = { (heading: String, items: [String]) in
            if !items.isEmpty { lines += ["", "## \(heading)", ""] + items.map { "- \($0)" } }
        }
        list("Decisões", decisions)
        list("Ideias principais", keyPoints)
        list("Perguntas em aberto", openQuestions)
        return lines.joined(separator: "\n") + "\n"
    }
}
