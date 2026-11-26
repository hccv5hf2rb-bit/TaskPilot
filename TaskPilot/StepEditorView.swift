import SwiftUI

struct StepEditorView: View {
    @Binding var step: Step

    var body: some View {
        Form {
            Section("类型") {
                Picker("步骤类型", selection: $step.kind) {
                    ForEach(StepKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                VoiceField(title: "步骤名称（可留空）", text: $step.name)
            }

            switch step.kind {
            case .http:
                Section {
                    Picker("方法", selection: $step.method) {
                        ForEach(["GET", "POST", "PUT", "PATCH", "DELETE"], id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                    TextField("URL", text: $step.url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("请求")
                }

                Section("请求头（每行 Key: Value）") {
                    TextField("Authorization: Bearer xxx", text: $step.headers, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(2...5)
                        .font(.body.monospaced())
                }

                Section("Body（非 GET 时发送）") {
                    VoiceField(
                        title: "{\"key\": \"value\"}",
                        text: $step.body,
                        multiline: true,
                        lineLimitRange: 3...8,
                        monospaced: true
                    )
                }

            case .llm:
                Section("提示词") {
                    VoiceField(
                        title: "用一句话总结：{{prev}}",
                        text: $step.prompt,
                        multiline: true,
                        lineLimitRange: 4...10
                    )
                }

            case .notify:
                Section("通知内容") {
                    VoiceField(
                        title: "{{prev}}",
                        text: $step.message,
                        multiline: true,
                        lineLimitRange: 2...6
                    )
                }

            case .delay:
                Section("等待") {
                    HStack {
                        Text("秒数")
                        Spacer()
                        TextField("1", value: $step.seconds, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("可用占位符")
                        .font(.footnote.weight(.semibold))
                    Text("{{prev}} → 上一步的输出（HTTP 响应正文、模型回答等）")
                        .font(.footnote)
                    Text("{{task}} → 当前任务名称")
                        .font(.footnote)
                    Text("输入框右边的麦克风可以直接说，识别结果会实时写进去。")
                        .font(.footnote)
                }
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(step.kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
