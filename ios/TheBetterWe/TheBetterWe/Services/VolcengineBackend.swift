import AVFoundation
import Foundation

final class VolcengineBackend: NSObject, ASRBackend {
    var onConnected: (() -> Void)?
    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    var engineLabel: String { "火山引擎" }

    private var webSocketTask: URLSessionWebSocketTask?
    private var connectionTimeoutTimer: Timer?
    private var isConnected = false

    // Ring buffer for audio arriving before the WebSocket is open.
    // Protected by ringLock — appendBuffer is called from the audio thread.
    private var ringBuffer: [Data] = []
    private let ringBufferMax = 512
    private let ringLock = NSLock()

    private var audioConverter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: true
    )!

    // MARK: - ASRBackend

    private var sessionStart: Date = Date()

    func start(audioFormat: AVAudioFormat) throws {
        guard let token = AuthService.accessToken else {
            print("[Volc] ❌ start — no auth token")
            throw ASRError.noAuthToken
        }

        sessionStart = Date()
        audioConverter = AVAudioConverter(from: audioFormat, to: targetFormat)

        // Convert https → wss (or http → ws for local dev)
        let base = APIConfig.baseURL.absoluteString
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        guard let url = URL(string: "\(base)/asr/stream?token=\(token)") else {
            print("[Volc] ❌ start — invalid URL")
            throw ASRError.invalidURL
        }

        print("[Volc] start — connecting to \(base)/asr/stream")
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        // If the server doesn't respond within 5 seconds, fall back to Apple.
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            guard let self, !self.isConnected else { return }
            let elapsed = Date().timeIntervalSince(self.sessionStart)
            print(String(format: "[Volc] ⏰ timeout fired at %.2fs — isConnected=false, firing onError", elapsed))
            self.onError?(ASRError.connectionTimeout)
        }
        print("[Volc] 5s timeout timer armed")

        receiveLoop()
    }

    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let data = downsample(buffer) else { return }
        ringLock.lock()
        if !isConnected {
            if ringBuffer.count < ringBufferMax { ringBuffer.append(data) }
            ringLock.unlock()
            return
        }
        ringLock.unlock()
        send(data: data)
    }

    func stop() {
        let elapsed = Date().timeIntervalSince(sessionStart)
        print(String(format: "[Volc] stop() called at %.2fs", elapsed))
        // Timer must be invalidated on main thread (where it was created).
        if Thread.isMainThread {
            connectionTimeoutTimer?.invalidate()
            connectionTimeoutTimer = nil
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.connectionTimeoutTimer?.invalidate()
                self?.connectionTimeoutTimer = nil
            }
        }
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        ringLock.lock()
        ringBuffer.removeAll()
        isConnected = false
        ringLock.unlock()
    }

    // MARK: - Private

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handle(message: message)
                self.receiveLoop()
            case .failure(let error):
                let elapsed = Date().timeIntervalSince(self.sessionStart)
                let connected = self.isConnected
                print(String(format: "[Volc] receive failure at %.2fs isConnected=%@ error=%@",
                              elapsed, connected ? "true" : "false", error.localizedDescription))
                guard !connected else { return }
                Task { @MainActor in self.onError?(error) }
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let msg = try? JSONDecoder().decode(ServerMessage.self, from: data)
        else { return }

        let elapsed = Date().timeIntervalSince(sessionStart)
        print(String(format: "[Volc] message at %.2fs type=%@", elapsed, msg.type))

        switch msg.type {
        case "connected":
            ringLock.lock()
            let buffered = ringBuffer
            ringBuffer.removeAll()
            isConnected = true
            ringLock.unlock()
            print(String(format: "[Volc] ✅ connected at %.2fs — flushing %d buffered frames", elapsed, buffered.count))
            for d in buffered { send(data: d) }
            Task { @MainActor in
                // Invalidate on main thread — timer was created there and invalidate() is not thread-safe.
                self.connectionTimeoutTimer?.invalidate()
                self.connectionTimeoutTimer = nil
                self.onConnected?()
            }

        case "partial":
            Task { @MainActor in self.onPartialTranscript?(msg.text ?? "") }

        case "final":
            Task { @MainActor in self.onFinalTranscript?(msg.text ?? "") }

        case "error":
            print(String(format: "[Volc] ❌ server error at %.2fs message=%@", elapsed, msg.message ?? "nil"))
            Task { @MainActor in
                self.onError?(ASRError.serverError(msg.message ?? "unknown"))
            }

        default:
            print(String(format: "[Volc] unknown message type=%@ at %.2fs", msg.type, elapsed))
            break
        }
    }

    private func send(data: Data) {
        webSocketTask?.send(.data(data)) { _ in }
    }

    private func downsample(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let converter = audioConverter else { return nil }
        let ratio = 16_000.0 / buffer.format.sampleRate
        let outFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard outFrames > 0,
              let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outFrames)
        else { return nil }

        var inputConsumed = false
        var convError: NSError?
        converter.convert(to: output, error: &convError) { _, status in
            if inputConsumed { status.pointee = .noDataNow; return nil }
            status.pointee = .haveData
            inputConsumed = true
            return buffer
        }
        guard convError == nil,
              let int16Ptr = output.int16ChannelData?.pointee
        else { return nil }

        return Data(bytes: int16Ptr, count: Int(output.frameLength) * 2)
    }

    // MARK: - Private types

    private struct ServerMessage: Decodable {
        let type: String
        let text: String?
        let message: String?
    }
}
