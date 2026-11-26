import AppIntents
import Foundation

/// 暴露给「快捷指令」的动作：跑一个任务，把结果作为文本返回。
/// 这是 iOS 上最靠得住的自动化入口——可以让快捷指令按时间、地点、充电、连上某个 Wi-Fi 等条件触发。
struct RunTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "运行 TaskPilot 任务"
    static var description: IntentDescription = IntentDescription("执行 App 内已有的一个任务，返回执行结果文本")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "任务名称", description: "要和 App 里的任务名称完全一致")
    var taskName: String

    static var parameterSummary: some ParameterSummary {
        Summary("运行 \(\.$taskName)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let task: TaskItem? = await MainActor.run {
            AgentStore.shared.tasksMatching(name: taskName)
        }
        guard let task else {
            return .result(value: "没有找到已启用的任务「\(taskName)」")
        }

        let result = await Executor.run(task)
        await MainActor.run {
            AgentStore.shared.markFinished(task, result: result)
        }
        if !result.success {
            NotificationManager.shared.post(title: "\(task.name) 失败", body: result.output)
        }
        return .result(value: result.output)
    }
}

struct TaskPilotShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RunTaskIntent(),
            phrases: [
                "用 \(.applicationName) 跑任务",
                "\(.applicationName) 开始自动化"
            ],
            shortTitle: "跑任务",
            systemImageName: "bolt.fill"
        )
    }
}
