import AVFoundation

protocol ASRBackend: AnyObject {
    /// Called on main actor when the backend is ready to process audio.
    /// Apple backend calls this synchronously in `start()`.
    /// Volcengine backend calls this when the server sends `{ type: "connected" }`.
    var onConnected: (() -> Void)? { get set }
    var onPartialTranscript: ((String) -> Void)? { get set }
    var onFinalTranscript: ((String) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }

    /// Short name shown in the voice sheet status label.
    var engineLabel: String { get }

    /// Begin accepting audio. Called after AVAudioSession is active and AVAudioEngine is running.
    /// Throws if startup fails immediately (e.g., no auth token). Async errors arrive via `onError`.
    func start(audioFormat: AVAudioFormat) throws

    /// Deliver a PCM buffer from the audio tap. Called from the audio thread — implementation must be thread-safe.
    func appendBuffer(_ buffer: AVAudioPCMBuffer)

    /// Tear down the backend. Safe to call multiple times.
    func stop()
}

enum ASRError: Error {
    case noAuthToken
    case invalidURL
    case connectionTimeout
    case serverError(String)
}
