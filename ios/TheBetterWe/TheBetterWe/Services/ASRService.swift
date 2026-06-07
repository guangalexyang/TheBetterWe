import Foundation
import AVFoundation
import Speech
import Combine

/// Owns the audio engine and silence detection. Delegates transcription to ASRBackend.
/// Tries VolcengineBackend first; falls back to AppleBackend automatically on any error.
@MainActor
final class ASRService: NSObject, ObservableObject {

    // MARK: - Published state

    @Published private(set) var interimTranscript: String = ""
    @Published private(set) var confirmedTranscript: String = ""
    /// Normalized RMS 0.0…1.0 for wave bar animation.
    @Published private(set) var audioLevel: Float = 0
    /// Short label for the active engine — "火山" or "Apple". Empty until the backend connects.
    @Published private(set) var engineLabel: String = ""

    // MARK: - Callbacks (set by VoiceInputView before calling startListening)

    var onFirstSpeechDetected: (() -> Void)?
    var onSilenceDetected: (() -> Void)?
    var onNoSpeechTimeout: (() -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Private

    private var audioEngine: AVAudioEngine?
    private var activeBackend: (any ASRBackend)?
    private var capturedAudioFormat: AVAudioFormat?

    private var hasSpeechStarted = false
    private var isCurrentlySilent = true
    private var noSpeechTimer: Timer?
    private var silenceTimer: Timer?
    private let rmsThreshold: Float = 0.015
    private var silenceTimeout: TimeInterval = 1.5

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

    /// Start audio engine + WebSocket connection. Does NOT start the no-speech timer —
    /// call arm(noSpeechTimeout:) once the backend signals it is ready (engineLabel becomes non-empty).
    func startListening(silenceTimeout: TimeInterval = 1.5) {
        reset()
        self.silenceTimeout = silenceTimeout

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            onError?(error)
            return
        }

        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        capturedAudioFormat = format

        // Wire Volcengine first. If it fails (sync throw or async onError), fall back to Apple.
        let volcengine = VolcengineBackend()
        wire(backend: volcengine)
        activeBackend = volcengine

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.activeBackend?.appendBuffer(buffer)
            let rms = Self.rms(buffer: buffer)
            Task { @MainActor in
                self.audioLevel = min(rms / 0.1, 1.0)
                self.handleAudioLevel(rms: rms)
            }
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            onError?(error)
            return
        }

        do {
            try volcengine.start(audioFormat: format)
        } catch {
            fallbackToApple()
        }
    }

    /// Start the no-speech timeout. Call this after bootstrap completes (engineLabel is set).
    func arm(noSpeechTimeout: TimeInterval) {
        noSpeechTimer?.invalidate()
        noSpeechTimer = Timer.scheduledTimer(withTimeInterval: noSpeechTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.hasSpeechStarted else { return }
                self.onNoSpeechTimeout?()
            }
        }
    }

    func stopRecording() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        activeBackend?.stop()
        noSpeechTimer?.invalidate()
        silenceTimer?.invalidate()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        stopRecording()
        interimTranscript = ""
        confirmedTranscript = ""
        audioLevel = 0
        engineLabel = ""
        hasSpeechStarted = false
        isCurrentlySilent = true
        activeBackend = nil
        capturedAudioFormat = nil
    }

    // MARK: - Private

    private func wire(backend: any ASRBackend) {
        // Capture label as a value to avoid a retain cycle (backend → closure → backend).
        let label = backend.engineLabel
        backend.onConnected = { [weak self] in
            self?.engineLabel = label
        }
        backend.onPartialTranscript = { [weak self] text in
            self?.interimTranscript = text
        }
        backend.onFinalTranscript = { [weak self] text in
            self?.confirmedTranscript = text
            self?.interimTranscript = ""
        }
        backend.onError = { [weak self] _ in
            self?.fallbackToApple()
        }
    }

    private func fallbackToApple() {
        guard let format = capturedAudioFormat else { return }
        activeBackend?.stop()
        let apple = AppleBackend()
        wire(backend: apple)
        activeBackend = apple
        try? apple.start(audioFormat: format)
    }

    private func handleAudioLevel(rms: Float) {
        if rms > rmsThreshold {
            if isCurrentlySilent {
                isCurrentlySilent = false
                silenceTimer?.invalidate()
            }
            if !hasSpeechStarted {
                hasSpeechStarted = true
                noSpeechTimer?.invalidate()
                onFirstSpeechDetected?()
            }
        } else {
            if hasSpeechStarted && !isCurrentlySilent {
                isCurrentlySilent = true
                silenceTimer?.invalidate()
                silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
                    Task { @MainActor in self?.onSilenceDetected?() }
                }
            }
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
