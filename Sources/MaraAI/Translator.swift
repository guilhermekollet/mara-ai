import Foundation
import Security

/// Talks to the OpenAI chat API: refines the translation of each sentence and summarizes the meeting.
struct Translator {
    let apiKey: String
    let model: String
    var glossary: [GlossaryEntry] = []

    /// Glossary block for the prompts; empty when there are no terms.
    private var glossaryPrompt: String {
        let lines = glossary.compactMap { entry -> String? in
            let term = entry.term.trimmingCharacters(in: .whitespaces)
            let rendering = entry.rendering.trimmingCharacters(in: .whitespaces)
            guard !term.isEmpty else { return nil }
            return rendering.isEmpty ? "- \(term)" : "- \(term) → \(rendering)"
        }
        guard !lines.isEmpty else { return "" }
        return """


        Glossary of names and terms used by this team. "A → B" means A must be written as B. A term \
        without an arrow must be kept exactly as written, never translated. If the speech recognition \
        produced something that sounds like a glossary term, assume the term was meant.
        \(lines.joined(separator: "\n"))
        """
    }

    struct Result {
        let text: String
        let inputTokens: Int
        let cachedTokens: Int
        let outputTokens: Int
        let reasoningTokens: Int
    }

    func translate(_ text: String, from language: String, to target: String, context: [String]) async throws -> Result {
        let system = """
        You are a live interpreter producing subtitles for a meeting. Translate the line under \
        "Translate" from \(language) to \(target). The text comes from speech recognition \
        and may contain errors: use the context to fix obvious ones. The context lines are earlier \
        speech, for reference only; never translate them. Reply with the translation only.
        """ + glossaryPrompt
        var user = ""
        if !context.isEmpty {
            user += "Context:\n" + context.joined(separator: "\n") + "\n\n"
        }
        user += "Translate:\n" + text
        return try await complete(system: system, user: user, timeout: 20)
    }

    /// Summarizes a meeting from its transcript, in `language`. Long meetings are first taken down
    /// as notes, part by part, and the summary is written from the notes. Returns the JSON text of
    /// the summary and every call made, so each one is logged with its cost.
    /// `withSpeakers`: the transcript marks each line "Me:", "Person N:" or "Others:".
    func summarize(_ transcript: String, language: String, withSpeakers: Bool = false) async throws -> (text: String, calls: [Result]) {
        let speakers = withSpeakers ? Self.speakersPrompt : ""
        var calls: [Result] = []
        var source = transcript
        let parts = Self.split(transcript, limit: Self.partLength)
        if parts.count > 1 {
            var notes: [String] = []
            for (index, part) in parts.enumerated() {
                let result = try await complete(system: notesPrompt(language: language) + speakers, user: part, timeout: 180)
                calls.append(result)
                notes.append("Part \(index + 1) of \(parts.count):\n\(result.text)")
            }
            source = "Notes taken from consecutive parts of the same meeting, in order:\n\n" + notes.joined(separator: "\n\n")
        }
        let system = summaryPrompt(language: language, withSpeakers: withSpeakers) + speakers
        let result: Result
        do {
            result = try await complete(system: system, user: source, timeout: 180, format: .schema(MeetingSummary.schema))
        } catch AppError.message(let message) where message.localizedCaseInsensitiveContains("response_format")
            || message.localizedCaseInsensitiveContains("json_schema") {
            // Models without Structured Outputs: ask for the same JSON in the prompt instead.
            result = try await complete(system: system + Self.schemaInstructions, user: source, timeout: 180, format: .json)
        }
        calls.append(result)
        return (result.text, calls)
    }

    /// About 12,000 tokens of transcript per call; longer meetings are taken down in parts.
    private static let partLength = 48_000

    /// Splits the transcript on line breaks into parts of at most `limit` characters.
    static func split(_ text: String, limit: Int) -> [String] {
        guard text.count > limit else { return [text] }
        var parts: [String] = []
        var current = ""
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if !current.isEmpty, current.count + line.count + 1 > limit {
                parts.append(current)
                current = ""
            }
            current += current.isEmpty ? String(line) : "\n" + line
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    private func summaryPrompt(language: String, withSpeakers: Bool) -> String {
        """
        You summarize a meeting for someone who was in it, from the transcript of its audio. Write \
        in \(language). The transcript comes from speech recognition\(withSpeakers ? "" : " and does not say who is speaking"); \
        it may contain recognition errors, so fix obvious ones from context.

        First decide what kind of meeting it was. "conversation": several people talking with each \
        other, with turns, questions and answers, people addressing one another. "presentation": \
        mostly one person speaking to an audience, like a class, a talk, a demo or a video.

        Then tell what was talked about, using only what is in the transcript:
        - title: 3 to 7 words naming the subject.
        - overview: 2 to 4 sentences on what the meeting was about and where it ended up.
        - topics: the subjects in the order they came up; for each, a short title and 1 to 3 \
        sentences on what was said. In a conversation, show the different views when there were \
        any. Use people's names only when they were said.
        - decisions: what was agreed, for conversations; empty for presentations or when nothing \
        was decided.
        - key_points: the main ideas, for presentations; empty for conversations.
        - open_questions: questions left unanswered or things left to be defined; empty if none.
        Do not invent anything and do not turn the summary into a task list.
        """ + glossaryPrompt
    }

    /// Added when the lines say who spoke (the microphone was on, or the speakers were told apart
    /// by their voices), so the summary can too.
    private static let speakersPrompt = """


    Each line of this transcript says who spoke. "Me:" is the person this summary is for, from \
    their microphone. "Person 1:", "Person 2:" and so on are the other participants, told apart \
    automatically by their voices: the numbers are only labels and can occasionally mix two people \
    up, so when someone's name comes up in the conversation, use the name instead of the number. \
    "Others:" is someone from the meeting who wasn't told apart. Refer to "Me" as "you", in the \
    second person, and say who said what when it matters: who proposed, agreed to or took on \
    something, who asked what. Lines from "Me" can include stray words picked up by the \
    microphone; skip what is not part of the meeting.
    """

    private func notesPrompt(language: String) -> String {
        """
        You take notes on one part of a longer meeting, from the transcript of its audio, so the \
        whole meeting can be summarized later. Write in \(language), as short bullet points in \
        order: the subjects discussed and what was said about each, any decision, any open \
        question, and the times they happened. Only what is in the transcript; it comes from speech \
        recognition and may contain errors.
        """ + glossaryPrompt
    }

    /// The schema spelled out, for models that only support plain JSON mode.
    private static let schemaInstructions = """


    Reply with only a JSON object in this format: {"kind": "conversation" or "presentation", \
    "title": "...", "overview": "...", "topics": [{"title": "...", "summary": "..."}], \
    "decisions": ["..."], "key_points": ["..."], "open_questions": ["..."]}
    """

    private enum Format {
        case text, json
        case schema([String: Any])
    }

    private func complete(
        system: String, user: String, timeout: TimeInterval, format: Format = .text
    ) async throws -> Result {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
        switch format {
        case .text:
            break
        case .json:
            payload["response_format"] = ["type": "json_object"]
        case .schema(let schema):
            payload["response_format"] = [
                "type": "json_schema",
                "json_schema": ["name": "meeting_summary", "strict": true, "schema": schema] as [String: Any],
            ]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let detail = (json?["error"] as? [String: Any])?["message"] as? String
            throw AppError.message("OpenAI: " + (detail ?? localized("erro HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")))
        }
        guard
            let choices = json?["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw AppError.message(localized("OpenAI: resposta em formato inesperado."))
        }
        // Tokens come from the response's "usage" field: the same count OpenAI uses for billing.
        let usage = json?["usage"] as? [String: Any] ?? [:]
        let inputDetails = usage["prompt_tokens_details"] as? [String: Any] ?? [:]
        let outputDetails = usage["completion_tokens_details"] as? [String: Any] ?? [:]
        return Result(
            text: content.trimmingCharacters(in: .whitespacesAndNewlines),
            inputTokens: usage["prompt_tokens"] as? Int ?? 0,
            cachedTokens: inputDetails["cached_tokens"] as? Int ?? 0,
            outputTokens: usage["completion_tokens"] as? Int ?? 0,
            reasoningTokens: outputDetails["reasoning_tokens"] as? Int ?? 0
        )
    }
}

/// The OpenAI key lives in the user's Keychain, never in a file.
enum Keychain {
    private static let base: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.guilhermekollet.mara-ai",
        kSecAttrAccount as String: "openai-api-key",
    ]

    static func loadAPIKey() -> String {
        read(base) ?? ""
    }

    private static func read(_ item: [String: Any]) -> String? {
        var query = item
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Other app secrets, each in its own Keychain account.
    static func loadSecret(account: String) -> String {
        var item = base
        item[kSecAttrAccount as String] = account
        return read(item) ?? ""
    }

    static func saveSecret(_ value: String, account: String) {
        var item = base
        item[kSecAttrAccount as String] = account
        SecItemDelete(item as CFDictionary)
        guard !value.isEmpty else { return }
        item[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(item as CFDictionary, nil)
    }

    static func saveAPIKey(_ key: String) {
        SecItemDelete(base as CFDictionary)
        guard !key.isEmpty else { return }
        var item = base
        item[kSecValueData as String] = Data(key.utf8)
        SecItemAdd(item as CFDictionary, nil)
    }
}
