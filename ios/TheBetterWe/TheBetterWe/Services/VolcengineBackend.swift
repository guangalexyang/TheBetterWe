import AVFoundation
import Foundation

final class VolcengineBackend: NSObject, ASRBackend {
    var onConnected: (() -> Void)?
    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    var engineLabel: String { "火山" }

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

    func start(audioFormat: AVAudioFormat) throws {
        guard let token = AuthService.accessToken else {
            throw ASRError.noAuthToken
        }

        audioConverter = AVAudioConverter(from: audioFormat, to: targetFormat)

        // Convert https → wss (or http → ws for local dev)
        let base = APIConfig.baseURL.absoluteString
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        guard let url = URL(string: "\(base)/asr/stream?token=\(token)") else {
            throw ASRError.invalidURL
        }

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        // If the server doesn't respond within 2 seconds, fall back to Apple.
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            guard let self, !self.isConnected else { return }
            self.onError?(ASRError.connectionTimeout)
        }

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
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
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
                guard !self.isConnected else { return }
                Task { @MainActor in self.onError?(error) }
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let msg = try? JSONDecoder().decode(ServerMessage.self, from: data)
        else { return }

        switch msg.type {
        case "connected":
            connectionTimeoutTimer?.invalidate()
            ringLock.lock()
            let buffered = ringBuffer
            ringBuffer.removeAll()
            isConnected = true
            ringLock.unlock()
            for d in buffered { send(data: d) }
            Task { @MainActor in self.onConnected?() }

        case "partial":
            Task { @MainActor in self.onPartialTranscript?(msg.text ?? "") }

        case "final":
            Task { @MainActor in self.onFinalTranscript?(msg.text ?? "") }

        case "error":
            Task { @MainActor in
                self.onError?(ASRError.serverError(msg.message ?? "unknown"))
            }

        default:
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
