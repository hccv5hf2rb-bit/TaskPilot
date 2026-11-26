import SwiftUI

struct TaskEditorView: View {
    @EnvironmentObject private var store: AgentStore
    @Environment(\.dismiss) private var dismiss

    @State var task: TaskItem
    @State private var isRunning = false
    @State private var runOutput = ""

    var body: some View {
        Form {
            Section("基本信息") {
                VoiceField(title: "名称", text: $task.name)
                Toggle("启用", isOn: $task.enabled)
                Picker("触发方式", selection: $task.trigger) {
                    ForEach(TriggerKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                if task.trigger == .schedule {
                    DatePicker("执行时间", selection: timeBinding, displayedComponents: .hourAndMinute)
                }
            }

            if task.trigger == .schedule {
                Section {
                    Text("iOS 不会精确地在整点唤醒 App。要准点执行，请改用「快捷指令」→ 个人自动化 → 特定时间 → 运行 TaskPilot 任务。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("步骤") {
                ForEach(task.steps.indices, id: \.self) { index in
                    NavigationLink {
                        StepEditorView(step: $task.steps[index])
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: icon(for: task.steps[index].kind))
                                .foregroundStyle(.orange)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.steps[index].name.isEmpty ? task.steps[index].kind.title : task.steps[index].name)
                                    .lineLimit(1)
                                Text(summary(of: task.steps[index]))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    task.steps.remove(atOffsets: offsets)
                }

                Button {
                    task.steps.append(Step(kind: .http))
                } label: {
                    Label("添加步骤", systemImage: "plus.circle.fill")
                }
            }

            Section {
                Button {
                    store.upsert(task)
                    dismiss()
                } label: {
                    Text("保存")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                .disabled(task.name.trimmingCharacters(in: .whitespaces).isEmpty)

                Button {
                    saveSilently()
                    runNow()
                } label: {
                    HStack(spacing: 8) {
                        if isRunning { ProgressView() }
                        Text(isRunning ? "运行中…" : "保存并运行一次")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isRunning || task.steps.isEmpty)
            }

            if !runOutput.isEmpty {
                Section("运行结果") {
                    Text(runOutput)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }

            if let last = task.lastRun, !task.lastResult.isEmpty {
                Section("上次运行（\(last.formatted(date: .abbreviated, time: .shortened))）") {
                    Text(task.lastResult)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("编辑任务")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 时间选择

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: task.hour,
                    minute: task.minute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                task.hour = parts.hour ?? 9
                task.minute = parts.minute ?? 0
            }
        )
    }

    // MARK: - 动作

    private func saveSilently() {
        store.upsert(task)
    }

    private func runNow() {
        isRunning = true
        runOutput = ""
        let snapshot = task
        Task { @MainActor in
            let result = await Executor.run(snapshot)
            AgentStore.shared.markFinished(snapshot, result: result)
            runOutput = result.output
            if let index = store.tasks.firstIndex(where: { $0.id == task.id }) {
                task.lastRun = store.tasks[index].lastRun
                task.lastResult = store.tasks[index].lastResult
            }
            isRunning = false
        }
    }

    private func icon(for kind: StepKind) -> String {
        switch kind {
        case .http: return "network"
        case .llm: return "sparkles"
        case .notify: return "bell.fill"
        case .delay: return "clock"
        }
    }

    private func summary(of step: Step) -> String {
        switch step.kind {
        case .http:
            let method = step.method.uppercased()
            return step.url.isEmpty ? "还没填 URL" : "\(method) \(step.url)"
        case .llm:
            return step.prompt.isEmpty ? "还没填提示词" : step.prompt
        case .notify:
            return step.message.isEmpty ? "还没填内容" : step.message
        case .delay:
            return "等待 \(Int(step.seconds)) 秒"
        }
    }
}
