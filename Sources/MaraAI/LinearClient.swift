import Foundation

/// Minimal client for the Linear GraphQL API, used only to send the tasks the user picks.
struct LinearClient {
    let apiKey: String

    struct Team: Identifiable, Hashable {
        let id: String
        let name: String
        let key: String
    }

    struct Member: Identifiable, Hashable {
        let id: String
        let name: String
        let displayName: String
    }

    struct Issue {
        let id: String
        let identifier: String
        let url: String
        let state: String
    }

    struct IssueState {
        let name: String
        /// State type in Linear: backlog, unstarted, started, completed or canceled.
        let type: String
        let priority: Int
    }

    /// Snapshot of the team's current cycle, for the menu bar panel.
    struct Overview: Codable, Equatable {
        var cycle: String?
        var open = 0
        var inProgress = 0
        var inReview = 0
        var done = 0
        var focus: Focus?
    }

    struct Focus: Codable, Equatable {
        let identifier: String
        let title: String
        let url: String
        let priority: Int
    }

    private static let issueFields = "identifier title url priority state { name type }"

    func overview(teamID: String, onlyMine: Bool) async throws -> Overview {
        let mine: [String: Any] = onlyMine ? ["assignee": ["isMe": ["eq": true]]] : [:]

        // Fast path: the active cycle and its issues in a single call.
        let combined = """
        query($id: String!, $filter: IssueFilter) {
          team(id: $id) { activeCycle { id number name issues(first: 250, filter: $filter) { nodes { \(Self.issueFields) } } } }
        }
        """
        if let data = try? await graphQL(combined, variables: ["id": teamID, "filter": mine]) {
            let cycle = (data["team"] as? [String: Any])?["activeCycle"] as? [String: Any]
            if let cycle, let nodes = (cycle["issues"] as? [String: Any])?["nodes"] as? [[String: Any]] {
                return summarize(nodes, cycle: cycle)
            }
        }

        // No active cycle (or the combined query failed): fetch the cycle and the issues separately.
        let cycleQuery = "query($id: String!) { team(id: $id) { activeCycle { id number name } } }"
        let team = try await graphQL(cycleQuery, variables: ["id": teamID])["team"] as? [String: Any]
        let cycle = team?["activeCycle"] as? [String: Any]

        var filter = mine
        filter["team"] = ["id": ["eq": teamID]]
        if let cycleID = cycle?["id"] as? String {
            filter["cycle"] = ["id": ["eq": cycleID]]
        } else {
            // Team without an active cycle: only count what is still open.
            filter["state"] = ["type": ["in": ["backlog", "unstarted", "started"]]]
        }
        let issuesQuery = "query($filter: IssueFilter) { issues(first: 250, filter: $filter) { nodes { \(Self.issueFields) } } }"
        let data = try await graphQL(issuesQuery, variables: ["filter": filter])
        return summarize((data["issues"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? [], cycle: cycle)
    }

    private func summarize(_ nodes: [[String: Any]], cycle: [String: Any]?) -> Overview {
        var overview = Overview()
        if let cycle {
            let name = cycle["name"] as? String ?? ""
            overview.cycle = name.isEmpty ? "Cycle \(cycle["number"] as? Int ?? 0)" : name
        }
        var started: [Focus] = []
        for node in nodes {
            let state = node["state"] as? [String: Any] ?? [:]
            switch DemandStatus.fromLinear(type: state["type"] as? String ?? "", name: state["name"] as? String ?? "") {
            case .backlog, .todo: overview.open += 1
            case .inReview: overview.inReview += 1
            case .done: overview.done += 1
            case .canceled: break
            case .inProgress:
                overview.inProgress += 1
                started.append(Focus(
                    identifier: node["identifier"] as? String ?? "", title: node["title"] as? String ?? "",
                    url: node["url"] as? String ?? "", priority: node["priority"] as? Int ?? 0
                ))
            }
        }
        overview.focus = started.min { DemandPriority.rank($0.priority) < DemandPriority.rank($1.priority) }
        return overview
    }

    /// Team issues completed since `since`, with who completed them. Reads up to 1,500 issues.
    func completions(teamID: String, since: Date) async throws -> [Delivery] {
        let query = """
        query($filter: IssueFilter, $after: String) {
          issues(first: 250, after: $after, filter: $filter) {
            nodes { completedAt assignee { id name } }
            pageInfo { hasNextPage endCursor }
          }
        }
        """
        let filter: [String: Any] = [
            "team": ["id": ["eq": teamID]],
            "completedAt": ["gte": ISO8601DateFormatter().string(from: since)],
        ]
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()

        var deliveries: [Delivery] = []
        var cursor: String?
        for _ in 0..<6 {
            var variables: [String: Any] = ["filter": filter]
            if let cursor { variables["after"] = cursor }
            let issues = try await graphQL(query, variables: variables)["issues"] as? [String: Any]
            for node in issues?["nodes"] as? [[String: Any]] ?? [] {
                guard let text = node["completedAt"] as? String,
                      let date = withFraction.date(from: text) ?? plain.date(from: text) else { continue }
                let assignee = node["assignee"] as? [String: Any]
                deliveries.append(Delivery(
                    date: date, memberID: assignee?["id"] as? String ?? "sem-responsavel",
                    memberName: assignee?["name"] as? String ?? "Sem responsável"
                ))
            }
            let page = issues?["pageInfo"] as? [String: Any]
            guard page?["hasNextPage"] as? Bool == true, let next = page?["endCursor"] as? String else { break }
            cursor = next
        }
        return deliveries
    }

    func members(teamID: String) async throws -> [Member] {
        let query = "query($id: String!) { team(id: $id) { members(first: 250) { nodes { id name displayName active } } } }"
        let data = try await graphQL(query, variables: ["id": teamID])
        let team = data["team"] as? [String: Any]
        let nodes = (team?["members"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
        return nodes.compactMap { node -> Member? in
            guard node["active"] as? Bool != false, let id = node["id"] as? String, let name = node["name"] as? String else { return nil }
            return Member(id: id, name: name, displayName: node["displayName"] as? String ?? name)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Current status of issues already sent, so Mara reflects what changed in Linear.
    func states(issueIDs: [String]) async throws -> [String: IssueState] {
        guard !issueIDs.isEmpty else { return [:] }
        let query = "query($ids: [ID!]) { issues(first: 250, filter: { id: { in: $ids } }) { nodes { id priority state { name type } } } }"
        let data = try await graphQL(query, variables: ["ids": issueIDs])
        let nodes = (data["issues"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
        var result: [String: IssueState] = [:]
        for node in nodes {
            guard let id = node["id"] as? String, let state = node["state"] as? [String: Any] else { continue }
            result[id] = IssueState(
                name: state["name"] as? String ?? "", type: state["type"] as? String ?? "", priority: node["priority"] as? Int ?? 0
            )
        }
        return result
    }

    func teams() async throws -> [Team] {
        let data = try await graphQL("query { teams(first: 100) { nodes { id name key } } }", variables: [:])
        let nodes = (data["teams"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
        return nodes.compactMap { node in
            guard let id = node["id"] as? String, let name = node["name"] as? String else { return nil }
            return Team(id: id, name: name, key: node["key"] as? String ?? "")
        }
    }

    func createIssue(
        teamID: String, title: String, description: String, assigneeID: String?, dueDate: String?, priority: Int
    ) async throws -> Issue {
        let mutation = """
        mutation($input: IssueCreateInput!) {
          issueCreate(input: $input) { success issue { id identifier url state { name } } }
        }
        """
        var input: [String: Any] = ["teamId": teamID, "title": title, "description": description]
        if let assigneeID { input["assigneeId"] = assigneeID }
        if let dueDate { input["dueDate"] = dueDate }
        if priority > 0 { input["priority"] = priority }
        let data = try await graphQL(mutation, variables: ["input": input])
        guard
            let result = data["issueCreate"] as? [String: Any],
            result["success"] as? Bool == true,
            let issue = result["issue"] as? [String: Any],
            let id = issue["id"] as? String,
            let identifier = issue["identifier"] as? String,
            let url = issue["url"] as? String
        else {
            throw AppError.message("O Linear não confirmou a criação da issue.")
        }
        let state = (issue["state"] as? [String: Any])?["name"] as? String ?? ""
        return Issue(id: id, identifier: identifier, url: url, state: state)
    }

    private func graphQL(_ query: String, variables: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "https://api.linear.app/graphql")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        // Linear personal API keys go raw in the header, without "Bearer".
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query, "variables": variables])

        let (body, response) = try await URLSession.shared.data(for: request)
        let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        if let errors = json?["errors"] as? [[String: Any]], let message = errors.first?["message"] as? String {
            throw AppError.message("Linear: \(message)")
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, let data = json?["data"] as? [String: Any] else {
            throw AppError.message("Linear: erro HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        return data
    }
}
