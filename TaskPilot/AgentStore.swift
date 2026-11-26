import Foundation
import SwiftUI

/// 任务与执行记录的唯一数据源，落在 App 沙盒的 Application Support 里。
final class AgentStore: ObservableObject {
    static let shared = AgentStore()

    @Published var tasks: [TaskItem] = []
    @Published var logs: [LogEntry] = []

    private struct Payload: Codable {
        var tasks: [TaskItem]
        var logs: [LogEntry]
    }

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("taskpilot.json")
    }

    private init() {
        load()
        if tasks.isEmpty {
            tasks = [TaskItem.demo]
            save()
        }
    }

    // MARK: - 持久化

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return
        }
        tasks = payload.tasks
        logs = payload.logs
    }

    func save() {
        let payload = Payload(tasks: tasks, logs: logs)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - 增删改

    func upsert(_ task: TaskItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
        save()
    }

    func remove(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        tasks.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - 执行结果

    @discardableResult
    func markFinished(_ task: TaskItem, result: RunResult) -> RunResult {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].lastRun = Date()
            tasks[index].lastResult = result.output
        }
        logs.insert(
            LogEntry(taskName: task.name, date: Date(), output: result.output, success: result.success),
            at: 0
        )
        if logs.count > 200 { logs = Array(logs.prefix(200)) }
        save()
        return result
    }

    // MARK: - 定时

    /// 找出「今天的执行时间已经过了、但还没跑过」的定时任务。
    func dueScheduledTasks(now: Date = Date()) -> [TaskItem] {
        let calendar = Calendar.current
        return tasks.filter { task in
            guard task.enabled, task.trigger == .schedule, !task.steps.isEmpty else { return false }
            guard let slot = calendar.date(
                bySettingHour: task.hour,
                minute: task.minute,
                second: 0,
                of: now
            ) else { return false }
            guard now >= slot else { return false }
            if let last = task.lastRun, last >= slot { return false }
            return true
        }
    }

    func tasksMatching(name: String) -> TaskItem? {
        tasks.first { $0.name == name && $0.enabled }
    }
}

extension TaskItem {
    static let demo = TaskItem(
        name: "每日天气播报",
        enabled: true,
        trigger: .manual,
        steps: [
            Step(kind: .http, name: "取天气", url: "https://api.open-meteo.com/v1/forecast?latitude=30.66&longitude=104.06&current=temperature_2m,weather_code", method: "GET"),
            Step(kind: .llm, prompt: "根据这段天气数据，用一句中文告诉我今天该怎么穿：{{prev}}"),
            Step(kind: .notify, message: "{{prev}}")
        ]
    )
}
