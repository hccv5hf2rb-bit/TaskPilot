import AVFoundation
import Foundation
import Speech
import SwiftUI

/// 语音转文字。用系统 Speech 框架，识别结果是流式返回的，
/// 每拿到一段就把「原始文字 + 新识别内容」写回输入框，用户可以边说话边看。
final class SpeechService: ObservableObject {
    static let shared = SpeechService()

    @Published var isRecording = false
    @Published var errorText: String?

    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false

    private init() {}

    // MARK: - 授权

    func requestAuthorizations() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    // MARK: - 开始 / 停止

    func start(onText: @escaping (String) -> Void) {
        guard !isRecording else { return }
        errorText = nil

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self else { return }
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self.errorText = "语音识别没授权。去 设置 → TaskPilot → 语音识别 打开后再试。"
                }
                return
            }
            self.askMicrophone { granted in
                guard granted else {
                    DispatchQueue.main.async {
                        self.errorText = "麦克风没授权。去 设置 → TaskPilot → 麦克风 打开后再试。"
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.begin(onText: onText)
                }
            }
        }
    }

    private func askMicrophone(_ completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            completion(granted)
        }
    }

    private func begin(onText: @escaping (String) -> Void) {
        guard let recognizer, recognizer.isAvailable else {
            errorText = "当前设备暂时用不了语音识别，稍后再试。"
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            request = req

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            if tapInstalled {
                input.removeTap(onBus: 0)
                tapInstalled = false
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }
            tapInstalled = true

            engine.prepare()
            try engine.start()

            isRecording = true

            task = recognizer.recognitionTask(with: req) { [weak self] result, error in
                guard let self else { return }

                if let result {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        onText(text)
                    }
                    if result.isFinal {
                        DispatchQueue.main.async { self.stop() }
                    }
                }

                if let error {
                    // 用户主动停止时也会走到这里，这时不算错误
                    if self.isRecording {
                        DispatchQueue.main.async {
                            self.errorText = error.localizedDescription
                            self.stop()
                        }
                    }
                }
            }
        } catch {
            errorText = "启动麦克风失败：\(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        if engine.isRunning { engine.stop() }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func toggle(onText: @escaping (String) -> Void) {
        if isRecording { stop() } else { start(onText: onText) }
    }
}

// MARK: - 带麦克风的输入框

struct VoiceField: View {
    let title: String
    @Binding var text: String
    var multiline: Bool = false
    var lineLimitRange: ClosedRange<Int> = 2...8
    var monospaced: Bool = false

    @ObservedObject private var speech = SpeechService.shared
    @State private var baseText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                field

                Button {
                    if speech.isRecording {
                        speech.stop()
                    } else {
                        baseText = text.isEmpty ? "" : text + (text.hasSuffix(" ") ? "" : " ")
                        speech.start { recognized in
                            text = baseText + recognized
                        }
                    }
                } label: {
                    Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(speech.isRecording ? Color.white : Color.accentColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle().fill(speech.isRecording ? Color.red : Color.accentColor.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }

            if speech.isRecording {
                Text("正在听… 说完点红色按钮停止")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let message = speech.errorText {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var field: some View {
        if multiline {
            TextField(LocalizedStringKey(title), text: $text, axis: .vertical)
                .lineLimit(lineLimitRange)
                .font(monospaced ? .body.monospaced() : .body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } else {
            TextField(LocalizedStringKey(title), text: $text)
                .font(monospaced ? .body.monospaced() : .body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }
}
