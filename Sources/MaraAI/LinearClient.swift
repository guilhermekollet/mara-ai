import Foundation

/// Minimal client for the Linear GraphQL API: the cycle overview, the deliveries chart and the
/// issues the user sends. Lists are read page by page, so big teams and cycles are counted in full,
/// and requests are retried when Linear is rate limiting or the network drops for a moment.
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

    /// A team issue for the deliveries chart: when it was completed (nil if it was reopened) and by whom.
    struct Completion {
        let id: String
        let completedAt: Date?
        let memberID: String
        let memberName: String
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

    /// Issues per page: the most Linear returns at once.
    private static let pageSize = 250
    /// Safety stop for paginated reads (10,000 issues), so a runaway cursor can't loop forever.
    private static let maxPages = 40

    private static func issuesQuery(_ fields: String) -> String {
        """
        query($filter: IssueFilter, $after: String) {
          issues(first: \(pageSize), after: $after, filter: $filter) {
            nodes { \(fields) }
            pageInfo { hasNextPage endCursor }
          }
        }
        """
    }

    func overview(teamID: String, onlyMine: Bool) async throws -> Overview {
        let cycleQuery = "query($id: String!) { team(id: $id) { activeCycle { id number name } } }"
        let team = try await graphQL(cycleQuery, variables: ["id": teamID])["team"] as? [String: Any]
        let cycle = team?["activeCycle"] as? [String: Any]

        var filter: [String: Any] = ["team": ["id": ["eq": teamID]]]
        if onlyMine { filter["assignee"] = ["isMe": ["eq": true]] }
        if let cycleID = cycle?["id"] as? String {
            filter["cycle"] = ["id": ["eq": cycleID]]
        } else {
            // Team without an active cycle: only count what is still open.
            filter["state"] = ["type": ["in": ["backlog", "unstarted", "started"]]]
        }
        let nodes = try await allNodes(Self.issuesQuery(Self.issueFields), variables: ["filter": filter], path: ["issues"])
        return summarize(nodes, cycle: cycle)
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

    /// Team issues for the deliveries chart. With `changedOnly` off: every issue completed since
    /// `since`. With it on: every issue changed since `since`, completed or not, so the cache can
    /// also drop issues that were reopened.
    func completions(teamID: String, since: Date, changedOnly: Bool) async throws -> [Completion] {
        let filter: [String: Any] = [
            "team": ["id": ["eq": teamID]],
            changedOnly ? "updatedAt" : "completedAt": ["gte": ISO8601DateFormatter().string(from: since)],
        ]
        let nodes = try await allNodes(
            Self.issuesQuery("id completedAt assignee { id name }"), variables: ["filter": filter], path: ["issues"]
        )
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        return nodes.compactMap { node in
            guard let id = node["id"] as? String else { return nil }
            let completedAt = (node["completedAt"] as? String).flatMap { withFraction.date(from: $0) ?? plain.date(from: $0) }
            let assignee = node["assignee"] as? [String: Any]
            return Completion(
                id: id, completedAt: completedAt,
                memberID: assignee?["id"] as? String ?? "sem-responsavel",
                memberName: assignee?["name"] as? String ?? "Sem responsável"
            )
        }
    }

    func members(teamID: String) async throws -> [Member] {
        let query = """
        query($id: String!, $after: String) {
          team(id: $id) { members(first: \(Self.pageSize), after: $after) { nodes { id name displayName active } pageInfo { hasNextPage endCursor } } }
        }
        """
        return try await allNodes(query, variables: ["id": teamID], path: ["team", "members"]).compactMap { node -> Member? in
            guard node["active"] as? Bool != false, let id = node["id"] as? String, let name = node["name"] as? String else { return nil }
            return Member(id: id, name: name, displayName: node["displayName"] as? String ?? name)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func teams() async throws -> [Team] {
        let query = "query($after: String) { teams(first: 100, after: $after) { nodes { id name key } pageInfo { hasNextPage endCursor } } }"
        return try await allNodes(query, variables: [:], path: ["teams"]).compactMap { node in
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

    /// Reads every page of a connection. `query` takes `$after` and selects `pageInfo` next to
    /// `nodes`; `path` leads from the response's `data` to the connection.
    private func allNodes(_ query: String, variables: [String: Any], path: [String]) async throws -> [[String: Any]] {
        var nodes: [[String: Any]] = []
        var cursor: String?
        for _ in 0..<Self.maxPages {
            var page = variables
            if let cursor { page["after"] = cursor }
            var connection: Any? = try await graphQL(query, variables: page)
            for key in path { connection = (connection as? [String: Any])?[key] }
            let object = connection as? [String: Any]
            nodes += object?["nodes"] as? [[String: Any]] ?? []
            let info = object?["pageInfo"] as? [String: Any]
            guard info?["hasNextPage"] as? Bool == true, let next = info?["endCursor"] as? String else { return nodes }
            cursor = next
        }
        throw AppError.message("Linear: a lista passou de \(Self.maxPages * Self.pageSize) itens e a leitura foi interrompida.")
    }

    /// A failure worth trying again: Linear rate limiting or briefly down, or the network dropping.
    private struct Transient: Error {
        let retryAfter: Double?
        let underlying: Error
    }

    /// Sends a query, trying up to three times on transient failures: after 1 s, then 2 s, or after
    /// as long as Linear asks, if that is 30 s or less.
    private func graphQL(_ query: String, variables: [String: Any]) async throws -> [String: Any] {
        for attempt in 1... {
            do {
                return try await send(query, variables: variables)
            } catch let failure as Transient {
                let wait = failure.retryAfter ?? Double(1 << (attempt - 1))
                guard attempt < 3, wait <= 30 else { throw failure.underlying }
                try await Task.sleep(for: .seconds(wait))
            }
        }
        fatalError("unreachable")
    }

    private func send(_ query: String, variables: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "https://api.linear.app/graphql")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        // Linear personal API keys go raw in the header, without "Bearer".
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query, "variables": variables])

        let body: Data
        let response: URLResponse
        do {
            (body, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where Self.transientNetworkErrors.contains(error.code) {
            throw Transient(retryAfter: nil, underlying: error)
        }
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        let errors = json?["errors"] as? [[String: Any]] ?? []

        let rateLimited = status == 429 || errors.contains { ($0["extensions"] as? [String: Any])?["code"] as? String == "RATELIMITED" }
        if rateLimited {
            throw Transient(
                retryAfter: http?.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init),
                underlying: AppError.message("Linear: limite de requisições atingido. Tente de novo em alguns minutos.")
            )
        }
        if status >= 500 {
            throw Transient(retryAfter: nil, underlying: AppError.message("Linear: erro HTTP \(status)"))
        }
        if let message = errors.first?["message"] as? String {
            throw AppError.message("Linear: \(message)")
        }
        guard status == 200, let data = json?["data"] as? [String: Any] else {
            throw AppError.message("Linear: erro HTTP \(status)")
        }
        return data
    }

    private static let transientNetworkErrors: Set<URLError.Code> = [
        .timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet, .dnsLookupFailed,
    ]
}
