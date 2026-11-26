import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var store: AgentStore

    @State private var runningID: UUID?
    @State private var showSettings = false
    @State private var showLogs = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.tasks) { task in
                        NavigationLink {
                            TaskEditorView(task: task)
                        } label: {
                            row(task)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                run(task)
                            } label: {
                                Label("运行", systemImage: "play.fill")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if let index = store.tasks.firstIndex(where: { $0.id == task.id }) {
                                    store.remove(at: IndexSet(integer: index))
                                }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("任务")
                } footer: {
                    Text("左滑运行，右滑删除。点进去可以改步骤。")
                }

                if !store.logs.isEmpty {
                    Section("最近执行") {
                        ForEach(Array(store.logs.prefix(5))) { log in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(log.success ? .green : .red)
                                        .font(.caption)
                                    Text(log.taskName)
                                        .font(.footnote.weight(.semibold))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(log.date, format: .dateTime.hour().minute())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(log.output)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("TaskPilot")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showLogs = true
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    Button {
                        store.tasks.append(TaskItem(name: "新任务 \(store.tasks.count + 1)", steps: [Step(kind: .http)]))
                        store.save()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showLogs) {
                LogView().environmentObject(store)
            }
            .onAppear {
                NotificationManager.shared.requestAuthorization()
                BackgroundScheduler.shared.scheduleNext()
            }
        }
    }

    // MARK: - 子视图

    private func row(_ task: TaskItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: task.enabled ? "bolt.fill" : "bolt.slash")
                .foregroundStyle(task.enabled ? Color.orange : Color.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .lineLimit(1)
                Text(subtitle(task))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if runningID == task.id {
                ProgressView()
            } else if let last = task.lastRun {
                Text(last, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func subtitle(_ task: TaskItem) -> String {
        let stepCount = "\(task.steps.count) 步"
        switch task.trigger {
        case .manual:
            return "手动 · \(stepCount)"
        case .shortcut:
            return "快捷指令 · \(stepCount)"
        case .schedule:
            let time = String(format: "%02d:%02d", task.hour, task.minute)
            return "每天 \(time) · \(stepCount)"
        }
    }

    private func run(_ task: TaskItem) {
        guard runningID == nil else { return }
        runningID = task.id
        Task { @MainActor in
            let result = await Executor.run(task)
            AgentStore.shared.markFinished(task, result: result)
            runningID = nil
        }
    }
}

#Preview {
    TaskListView().environmentObject(AgentStore.shared)
}
