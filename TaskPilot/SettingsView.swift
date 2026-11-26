import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var baseURL = UserDefaults.standard.string(forKey: "llm.baseURL") ?? "https://api.openai.com/v1"
    @State private var model = UserDefaults.standard.string(forKey: "llm.model") ?? "gpt-4o-mini"
    @State private var apiKey = UserDefaults.standard.string(forKey: "llm.apiKey") ?? ""
    @State private var testResult = ""
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Base URL", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("模型名", text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("API Key", text: $apiKey)
                } header: {
                    Text("模型接口（OpenAI 兼容）")
                } footer: {
                    Text("填到 /v1 这一层就行，App 会自动拼 /chat/completions。支持 OpenAI、DeepSeek、Moonshot、通义、以及自建 one-api 等。")
                }

                Section {
                    Button {
                        test()
                    } label: {
                        HStack(spacing: 8) {
                            if isTesting { ProgressView() }
                            Text(isTesting ? "测试中…" : "保存并测试连接")
                        }
                    }
                    .disabled(isTesting)

                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.footnote)
                            .textSelection(.enabled)
                    }
                } footer: {
                    Text("Key 只保存在这台设备的 UserDefaults 里。如果在意安全，可以改成 Keychain 存储，位置在 LLMClient.swift。")
                }

                Section("关于") {
                    LabeledContent("版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "-")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        persist()
                        dismiss()
                    }
                }
            }
        }
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(baseURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "llm.baseURL")
        defaults.set(model.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "llm.model")
        defaults.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "llm.apiKey")
    }

    private func test() {
        persist()
        isTesting = true
        testResult = ""
        Task { @MainActor in
            do {
                let answer = try await LLMClient.complete(prompt: "只回复两个字：连通")
                testResult = "✅ 连接正常，模型返回：\(answer)"
            } catch {
                testResult = "❌ \(error.localizedDescription)"
            }
            isTesting = false
        }
    }
}
