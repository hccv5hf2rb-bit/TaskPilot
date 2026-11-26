import Foundation

/// 任务的触发方式
enum TriggerKind: String, Codable, CaseIterable, Identifiable {
    case manual      // 手动点一下
    case schedule    // 每天定时（受 iOS 后台调度限制，不保证精确）
    case shortcut    // 交给「快捷指令」触发（最可靠）

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: return "手动"
        case .schedule: return "每天定时"
        case .shortcut: return "快捷指令"
        }
    }
}

/// 一个步骤的类型
enum StepKind: String, Codable, CaseIterable, Identifiable {
    case http      // 发 HTTP 请求
    case llm       // 调模型
    case notify    // 发本地通知
    case delay     // 等待

    var id: String { rawValue }

    var title: String {
        switch self {
        case .http: return "HTTP 请求"
        case .llm: return "调用模型"
        case .notify: return "发通知"
        case .delay: return "等待"
        }
    }
}

struct Step: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: StepKind
    var name: String = ""

    // HTTP
    var url: String = ""
    var method: String = "GET"
    var headers: String = ""
    var body: String = ""

    // 模型
    var prompt: String = ""

    // 通知
    var message: String = ""

    // 等待
    var seconds: Double = 1
}

struct TaskItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String = "新任务"
    var enabled: Bool = true
    var trigger: TriggerKind = .manual

    var hour: Int = 9
    var minute: Int = 0

    var steps: [Step] = []

    var lastRun: Date? = nil
    var lastResult: String = ""
}

struct LogEntry: Identifiable, Codable {
    var id = UUID()
    var taskName: String
    var date: Date
    var output: String
    var success: Bool
}

struct RunResult {
    var success: Bool
    var output: String
}

enum AgentError: LocalizedError {
    case badURL(String)
    case http(Int, String)
    case missingConfig
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .badURL(let value):
            return "URL 无效：\(value)"
        case .http(let code, let body):
            return "HTTP \(code)：\(body)"
        case .missingConfig:
            return "还没有配置模型接口，请先到「设置」里填写 Base URL、模型名和 Key"
        case .emptyResponse:
            return "接口没有返回可用内容"
        }
    }
}
