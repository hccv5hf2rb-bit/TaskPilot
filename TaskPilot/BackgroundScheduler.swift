import Foundation
import BackgroundTasks

/// 每天定时的兜底实现。iOS 不允许精确后台定时，
/// 系统会在它认为合适的时候唤醒 App（通常有 15 分钟以上的误差，电量低时可能跳过）。
/// 所以要「准时」，请用快捷指令自动化来触发（见 README）。
final class BackgroundScheduler {
    static let shared = BackgroundScheduler()
    private init() {}

    private var identifier: String {
        (Bundle.main.bundleIdentifier ?? "com.taskpilot.app") + ".refresh"
    }

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { [weak self] task in
            guard let self, let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handle(refresh)
        }
    }

    func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // 模拟器或没有 Background Modes 权限时会失败，不需要处理
        }
    }

    private func handle(_ task: BGAppRefreshTask) {
        scheduleNext()

        let work = Task { () -> Bool in
            await self.runDueTasks()
            return true
        }

        task.expirationHandler = { work.cancel() }

        Task {
            let succeeded = await work.value
            task.setTaskCompleted(success: succeeded)
        }
    }

    private func runDueTasks() async {
        let due: [TaskItem] = await MainActor.run {
            AgentStore.shared.dueScheduledTasks()
        }
        guard !due.isEmpty else { return }

        for item in due {
            if Task.isCancelled { return }
            let result = await Executor.run(item)
            await MainActor.run {
                AgentStore.shared.markFinished(item, result: result)
            }
            NotificationManager.shared.post(title: item.name, body: result.output)
        }
    }
}
