import Foundation

/// Status of a Linear issue, with the Portuguese names used in Mara.
enum DemandStatus: String, Codable, CaseIterable, Identifiable {
    case backlog, todo, inProgress, inReview, done, canceled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .backlog: return "Backlog"
        case .todo: return "A fazer"
        case .inProgress: return "Em progresso"
        case .inReview: return "Em review"
        case .done: return "Concluída"
        case .canceled: return "Cancelada"
        }
    }

    var symbol: String {
        switch self {
        case .backlog: return "circle.dotted"
        case .todo: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .inReview: return "circle.inset.filled"
        case .done: return "checkmark.circle.fill"
        case .canceled: return "xmark.circle.fill"
        }
    }

    var isOpen: Bool { self != .done && self != .canceled }

    /// Maps a Linear issue state. "In Review" is a "started"-type state,
    /// so it can only be told apart by its name.
    static func fromLinear(type: String, name: String) -> DemandStatus {
        switch type {
        case "backlog", "triage": return .backlog
        case "unstarted": return .todo
        case "started": return name.lowercased().contains("review") ? .inReview : .inProgress
        case "completed": return .done
        case "canceled": return .canceled
        default: return .todo
        }
    }
}

/// Priority following Linear's convention: 0 no priority, 1 urgent, 2 high, 3 medium, 4 low.
enum DemandPriority {
    static let all = [1, 2, 3, 4, 0]

    static func title(_ value: Int) -> String {
        switch value {
        case 1: return "Urgente"
        case 2: return "Alta"
        case 3: return "Média"
        case 4: return "Baixa"
        default: return "Sem prioridade"
        }
    }

    /// Order of importance: urgent first, no priority last.
    static func rank(_ value: Int) -> Int { value == 0 ? 5 : value }
}

/// An action item taken from the meeting summary. Mara does not store it: it lives for the session
/// until you decide to send it to Linear, which is where tasks live from then on.
struct MeetingAction: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var owner: String
    var due: String
    /// Due date as a date (YYYY-MM-DD), when the model was able to determine it.
    var dueDate: String?
    var priority = 0
    var linearIdentifier: String?
    var linearURL: String?
}

/// Structured summary the GPT returns as JSON: it becomes text to read and tasks to track.
struct MeetingSummary {
    struct Action {
        let title: String
        let owner: String
        let due: String
        let dueDate: String?
    }

    let text: String
    let actions: [Action]

    /// If the model doesn't return the expected JSON, the raw text is shown and no tasks are created.
    static func parse(_ raw: String) -> MeetingSummary {
        var body = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("```") {
            body = body.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
            if let fence = body.range(of: "```", options: .backwards) { body = String(body[..<fence.lowerBound]) }
        }
        guard
            let data = body.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return MeetingSummary(text: raw, actions: [])
        }

        let strings = { (key: String) in (json[key] as? [Any] ?? []).compactMap { $0 as? String }.filter { !$0.isEmpty } }
        let actions = (json["pendencias"] as? [[String: Any]] ?? []).compactMap { item -> Action? in
            guard let title = (item["titulo"] as? String)?.trimmingCharacters(in: .whitespaces), !title.isEmpty else { return nil }
            let date = (item["prazo_data"] as? String).flatMap { $0.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) == nil ? nil : $0 }
            return Action(
                title: title, owner: item["responsavel"] as? String ?? "", due: item["prazo"] as? String ?? "", dueDate: date
            )
        }

        let section = { (title: String, lines: [String]) in
            title + "\n" + (lines.isEmpty ? "- Nada registrado." : lines.map { "- \($0)" }.joined(separator: "\n"))
        }
        let actionLines = actions.map { action in
            let details = [action.owner.isEmpty ? nil : "responsável: \(action.owner)", action.due.isEmpty ? nil : "prazo: \(action.due)"]
                .compactMap { $0 }
            return details.isEmpty ? action.title : "\(action.title) (\(details.joined(separator: "; ")))"
        }
        let text = [
            section("Pontos principais", strings("pontos")),
            section("Decisões", strings("decisoes")),
            section("Pendências", actionLines),
        ].joined(separator: "\n\n")
        return MeetingSummary(text: text, actions: actions)
    }
}
