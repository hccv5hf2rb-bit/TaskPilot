import Foundation

struct LLMConfig {
    var baseURL: String
    var model: String
    var apiKey: String

    static var current: LLMConfig {
        let defaults = UserDefaults.standard
        return LLMConfig(
            baseURL: defaults.string(forKey: "llm.baseURL") ?? "https://api.openai.com/v1",
            model: defaults.string(forKey: "llm.model") ?? "gpt-4o-mini",
            apiKey: defaults.string(forKey: "llm.apiKey") ?? ""
        )
    }

    var chatEndpoint: URL? {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return nil }
        if base.hasSuffix("/chat/completions") { return URL(string: base) }
        if base.hasSuffix("/") { base.removeLast() }
        return URL(string: base + "/chat/completions")
    }
}

enum LLMClient {
    static let systemPrompt = "你是一个跑在手机上的自动化助手。回答简短、直接给可用结论，不要寒暄，不要解释过程。"

    static func complete(prompt: String, system: String = systemPrompt) async throws -> String {
        let config = LLMConfig.current
        guard !config.apiKey.isEmpty else { throw AgentError.missingConfig }
        guard let url = config.chatEndpoint else { throw AgentError.missingConfig }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "model": config.model,
            "temperature": 0.3,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AgentError.http(httpResponse.statusCode, String(text.prefix(500)))
        }

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = root["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String,
            !content.isEmpty
        else {
            throw AgentError.emptyResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
