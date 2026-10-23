//
//  SpeechCommandListener.swift
//  Golf101
//

import Foundation
import AVFoundation
import Observation
@preconcurrency import Speech

enum SpeechCommand: Equatable, Sendable {
    case next
    case repeatTip
    case restartStep
    case help

    static func parse(_ transcript: String) -> SpeechCommand? {
        let text = transcript
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .replacingOccurrences(of: "　", with: "")
            .lowercased()

        guard !text.isEmpty else { return nil }

        if ["再說一次", "重複提示", "重講", "再講一次", "教練再說"].contains(where: text.contains) {
            return .repeatTip
        }
        if ["下一步", "繼續", "完成這一步", "往下"].contains(where: text.contains) {
            return .next
        }
        if ["重來", "重新開始", "重新練習", "重做這步"].contains(where: text.contains) {
            return .restartStep
        }
        if ["語音指令", "可以說什麼", "指令有哪些", "幫助"].contains(where: text.contains) {
            return .help
        }
        return nil
    }
}

#if os(iOS)
@MainActor
@Observable
final class SpeechCommandListener {
    private(set) var isListening = false
    private(set) var statusMessage = "點麥克風後說「下一步」或「再說一次」"

    @ObservationIgnored private var isStarting = false
    @ObservationIgnored private var hasInstalledTap = false
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW"))

    func start(onCommand: @escaping @MainActor (SpeechCommand) -> Void) async {
        guard !isListening, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        statusMessage = "正在取得語音權限…"

        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechAuthorized else {
            statusMessage = "請在設定中允許語音辨識"
            return
        }

        let microphoneAuthorized = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard microphoneAuthorized else {
            statusMessage = "請在設定中允許麥克風"
            return
        }

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            statusMessage = "目前無法使用語音辨識"
            return
        }

        do {
            try configureAndStartRecognition(using: speechRecognizer, onCommand: onCommand)
        } catch {
            stop(status: "語音辨識啟動失敗，請再試一次")
        }
    }

    func stop(status: String = "已停止聆聽") {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
        if !status.isEmpty {
            statusMessage = status
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureAndStartRecognition(
        using speechRecognizer: SFSpeechRecognizer,
        onCommand: @escaping @MainActor (SpeechCommand) -> Void
    ) throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            stop(status: "目前裝置無可用麥克風輸入聲道")
            return
        }

        if hasInstalledTap {
            inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        hasInstalledTap = true

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
        statusMessage = "聆聽中：請說出練習指令"

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            let transcript = result?.bestTranscription.formattedString
            Task { @MainActor [weak self] in
                guard let self, self.isListening else { return }

                if let transcript, let command = SpeechCommand.parse(transcript) {
                    self.stop(status: "已辨識：「\(transcript)」")
                    onCommand(command)
                } else if let error {
                    self.stop(status: "語音辨識中斷，請再試一次")
                    _ = error
                } else if let transcript {
                    self.statusMessage = "聽到：「\(transcript)」"
                }
            }
        }
    }
}
#endif
