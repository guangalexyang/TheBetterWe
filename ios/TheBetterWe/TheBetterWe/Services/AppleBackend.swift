import AVFoundation
import Speech

final class AppleBackend: NSObject, ASRBackend {
    var onConnected: (() -> Void)?
    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    var engineLabel: String { "Apple" }

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // iOS 26 beta Simulator ships a corrupted zh-Hans mini.json — use en-US there.
    // On a real device this is always zh-Hans.
    #if targetEnvironment(simulator)
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    #else
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-Hans"))
    #endif

    func start(audioFormat: AVAudioFormat) throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            if let error { print("[ASR] Apple error: \(error)") }
            guard let self, let result else { return }
            let text = result.bestTranscription.formattedString
            Task { @MainActor in
                if result.isFinal {
                    self.onFinalTranscript?(text)
                } else {
                    self.onPartialTranscript?(text)
                }
            }
        }

        // No network connection — backend is ready immediately.
        onConnected?()
    }

    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    func stop() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
}
