import Foundation
import AVFoundation
import Speech
import Combine

/// Transcription + audio recording service.
/// To swap in Volcengine ASR: replace only the SFSpeechRecognizer block in startListening().
@MainActor
final class ASRService: NSObject, ObservableObject {

    // MARK: - Published state

    @Published private(set) var interimTranscript: String = ""
    @Published private(set) var confirmedTranscript: String = ""
    /// Normalized RMS 0.0…1.0 for wave bar animation.
    @Published private(set) var audioLevel: Float = 0

    // MARK: - Silence-detection callbacks

    /// Fires once when audio first exceeds the RMS threshold (cancels the no-speech timer).
    var onFirstSpeechDetected: (() -> Void)?
    /// Fires when silence persists for `silenceTimeout` after speech began.
    var onSilenceDetected: (() -> Void)?
    /// Fires when no audio exceeds threshold within `noSpeechTimeout` of start.
    var onNoSpeechTimeout: (() -> Void)?
    /// Fires on non-recoverable errors (engine start failure).
    var onError: ((Error) -> Void)?

    // MARK: - Private

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-Hans"))

    private var hasSpeechStarted = false
    private var noSpeechTimer: Timer?
    private var silenceTimer: Timer?
    private let rmsThreshold: Float = 0.015

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        let micGranted = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
        guard micGranted else { return false }

        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        return speechStatus == .authorized
    }

    // MARK: - Lifecycle

    func startListening(noSpeechTimeout: TimeInterval = 3, silenceTimeout: TimeInterval = 1.5) {
        reset()

        // Activate audio session first — inputNode.outputFormat returns 0 sample rate otherwise.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            onError?(error)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            request.append(buffer)
            let rms = Self.rms(buffer: buffer)
            Task { @MainActor in
                self.audioLevel = min(rms / 0.1, 1.0)
                self.handleAudioLevel(rms: rms, silenceTimeout: silenceTimeout)
            }
        }

        do {
            try audioEngine.start()
        } catch {
            onError?(error)
            return
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, _ in
            guard let self, let result else { return }
            let text = result.bestTranscription.formattedString
            Task { @MainActor in
                if result.isFinal {
                    self.confirmedTranscript = text
                    self.interimTranscript = ""
                } else {
                    self.interimTranscript = text
                }
            }
        }

        noSpeechTimer = Timer.scheduledTimer(withTimeInterval: noSpeechTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.hasSpeechStarted else { return }
                self.onNoSpeechTimeout?()
            }
        }
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        noSpeechTimer?.invalidate()
        silenceTimer?.invalidate()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        stopRecording()
        interimTranscript = ""
        confirmedTranscript = ""
        audioLevel = 0
        hasSpeechStarted = false
        recognitionRequest = nil
        recognitionTask = nil
    }

    // MARK: - Private

    private func handleAudioLevel(rms: Float, silenceTimeout: TimeInterval) {
        guard rms > rmsThreshold else {
            if hasSpeechStarted {
                silenceTimer?.invalidate()
                silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
                    Task { @MainActor in self?.onSilenceDetected?() }
                }
            }
            return
        }
        silenceTimer?.invalidate()
        if !hasSpeechStarted {
            hasSpeechStarted = true
            noSpeechTimer?.invalidate()
            onFirstSpeechDetected?()
        }
    }

    /// Compute RMS amplitude of a mono PCM buffer.
    static func rms(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }
        let ptr = channelData.pointee
        var sum: Float = 0
        for i in stride(from: 0, to: frameCount, by: buffer.stride) {
            sum += ptr[i] * ptr[i]
        }
        let result = sqrt(sum / Float(frameCount / buffer.stride))
        return result.isNaN ? 0 : result
    }
}
