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

    func translate(_ text: String, from language: String, context: [String]) async throws -> Result {
        let system = """
        You are a live interpreter producing subtitles for a meeting. Translate the line under \
        "Translate" from \(language) to Brazilian Portuguese. The text comes from speech recognition \
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

    func summarize(_ transcript: String, today: String) async throws -> Result {
        let system = """
        Você resume reuniões de trabalho a partir da transcrição. Responda em português do Brasil, \
        somente com um objeto JSON neste formato:
        {"pontos": ["..."], "decisoes": ["..."], "pendencias": [{"titulo": "...", "responsavel": "...", "prazo": "...", "prazo_data": "AAAA-MM-DD"}]}
        "pontos" são os assuntos principais e "decisoes" o que foi decidido, em frases curtas. Cada \
        item de "pendencias" é uma ação a fazer: "titulo" começa com um verbo e é entendido sozinho; \
        "responsavel" e "prazo" ficam como texto vazio quando não foram mencionados. "prazo" repete \
        o que foi dito ("quinta-feira"); "prazo_data" é essa data no formato AAAA-MM-DD, calculada a \
        partir de hoje (\(today)), ou texto vazio se não der para determinar. Baseie-se apenas \
        no que está na transcrição, sem inventar; use listas vazias quando não houver conteúdo. A \
        transcrição vem de reconhecimento de fala e pode conter erros de palavras.
        """ + glossaryPrompt
        return try await complete(system: system, user: transcript, timeout: 180, json: true)
    }

    private func complete(
        system: String, user: String, timeout: TimeInterval, json wantsJSON: Bool = false
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
        if wantsJSON { payload["response_format"] = ["type": "json_object"] }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let detail = (json?["error"] as? [String: Any])?["message"] as? String
            throw AppError.message("OpenAI: " + (detail ?? "erro HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"))
        }
        guard
            let choices = json?["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw AppError.message("OpenAI: resposta em formato inesperado.")
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

    /// Other app secrets (such as the Linear key), each in its own Keychain account.
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
