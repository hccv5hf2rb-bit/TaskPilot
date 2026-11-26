import SwiftUI

struct LogView: View {
    @EnvironmentObject private var store: AgentStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.logs.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("还没有执行记录")
                            .font(.headline)
                        Text("跑一次任务，这里就会有记录")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(store.logs) { log in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(log.success ? .green : .red)
                                    Text(log.taskName)
                                        .font(.footnote.weight(.semibold))
                                    Spacer()
                                    Text(log.date, format: .dateTime.month().day().hour().minute())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(log.output)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("执行记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("清空") {
                        store.logs.removeAll()
                        store.save()
                    }
                    .disabled(store.logs.isEmpty)
                }
            }
        }
    }
}
