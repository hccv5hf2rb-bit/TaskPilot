import Foundation

/// 顺序执行一个任务的步骤链，任何一步抛错就整条链停下并记录原因。
enum Executor {

    static func run(_ task: TaskItem) async -> RunResult {
        var output = ""
        let steps = task.steps
        guard !steps.isEmpty else {
            return RunResult(success: false, output: "任务里还没有步骤")
        }

        for (index, step) in steps.enumerated() {
            let label = step.name.isEmpty ? step.kind.title : step.name
            do {
                let piece = try await perform(step, context: output, taskName: task.name)
                output += "[\(index + 1). \(label)] \(piece)\n"
            } catch {
                output += "[\(index + 1). \(label)] ✗ \(error.localizedDescription)\n"
                return RunResult(success: false, output: output)
            }
        }
        return RunResult(success: true, output: output)
    }

    // MARK: - 单步

    private static func perform(_ step: Step, context: String, taskName: String) async throws -> String {
        switch step.kind {
        case .http:
            return try await http(step, context: context, taskName: taskName)

        case .llm:
            let prompt = render(step.prompt, context: context, taskName: taskName)
            guard !prompt.isEmpty else { throw AgentError.emptyResponse }
            return try await LLMClient.complete(prompt: prompt)

        case .notify:
            let message = render(step.message, context: context, taskName: taskName)
            NotificationManager.shared.post(title: taskName, body: message)
            return "已发送通知"

        case .delay:
            let seconds = max(0, min(step.seconds, 300))
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return "等待 \(Int(seconds)) 秒"
        }
    }

    private static func http(_ step: Step, context: String, taskName: String) async throws -> String {
        let rawURL = render(step.url, context: context, taskName: taskName)
        guard let url = URL(string: rawURL), url.scheme != nil else {
            throw AgentError.badURL(rawURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = step.method.uppercased()
        request.timeoutInterval = 30

        for line in step.headers.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            if !key.isEmpty { request.setValue(value, forHTTPHeaderField: key) }
        }

        if request.httpMethod != "GET" {
            let body = render(step.body, context: context, taskName: taskName)
            if !body.isEmpty {
                request.httpBody = body.data(using: .utf8)
            }
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentError.emptyResponse
        }

        let text = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = text.count > 1500 ? String(text.prefix(1500)) + " …（已截断）" : text

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AgentError.http(httpResponse.statusCode, clipped)
        }
        return "HTTP \(httpResponse.statusCode) \(clipped)"
    }

    /// 把 {{prev}} / {{task}} 替换掉，让后面的步骤能引用前面的输出。
    private static func render(_ template: String, context: String, taskName: String) -> String {
        template
            .replacingOccurrences(of: "{{prev}}", with: context.trimmingCharacters(in: .whitespacesAndNewlines))
            .replacingOccurrences(of: "{{task}}", with: taskName)
    }
}
