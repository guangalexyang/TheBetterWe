# Volcengine ASR Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `SFSpeechRecognizer` with a Volcengine streaming ASR proxy through our Node server, keeping Apple ASR as automatic fallback, and show the active engine in the voice sheet status label.

**Architecture:** `ASRService` delegates transcription to a swappable `ASRBackend` protocol. `VolcengineBackend` streams 16kHz/16-bit PCM over WebSocket to `/asr/stream` on the server, which relays to Volcengine (or returns `no_credentials` until credentials are wired in, triggering iOS to fall back to `AppleBackend`). Silence detection, audio engine setup, and all voice sheet UI are unchanged.

**Tech Stack:** Swift / SwiftUI / AVFoundation / URLSessionWebSocketTask (iOS); Node.js + Express + `ws` npm package (server); TypeScript; JWT auth; fly.io deploy.

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `server/package.json` | Add `ws` + `@types/ws` |
| Modify | `server/src/index.ts` | Wrap Express in `http.Server`, handle WebSocket upgrade for `/asr/stream` |
| Create | `server/src/routes/asr.ts` | WebSocket proxy: auth, rate limit, `no_credentials` stub, future Volcengine relay |
| Create | `ios/.../Services/ASRBackend.swift` | Protocol defining the backend interface |
| Create | `ios/.../Services/AppleBackend.swift` | `SFSpeechRecognizer` extracted from `ASRService` |
| Create | `ios/.../Services/VolcengineBackend.swift` | WebSocket client, ring buffer, `AVAudioConverter` downsampler |
| Modify | `ios/.../Services/ASRService.swift` | Remove recognizer internals, add `engineLabel`, try Volcengine first then fall back |
| Modify | `ios/.../Views/Voice/VoiceInputView.swift` | Status label shows `聆听中[火山]` or `聆听中[Apple]` |

> **iOS synchronized folder:** All new `.swift` files placed inside `TheBetterWe/` are auto-compiled — do NOT touch `project.pbxproj`.

---

## Task 1: Install `ws` on server and switch to `http.Server`

**Files:**
- Modify: `server/package.json`
- Modify: `server/src/index.ts`

- [ ] **Step 1: Install ws**

```bash
cd server && npm install ws && npm install --save-dev @types/ws
```

Expected: `ws` appears in `dependencies`, `@types/ws` in `devDependencies` in `package.json`.

- [ ] **Step 2: Update `server/src/index.ts`**

Replace the entire file with:

```typescript
import 'dotenv/config';
import express from 'express';
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import { handleASRUpgrade } from './routes/asr';
import featureToggles from './routes/featureToggles';
import auth from './routes/auth';
import families from './routes/families';
import pointSystem from './routes/pointSystem';

const app = express();
const port = process.env.PORT ?? 3000;

app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.use('/auth', auth);
app.use('/families', families);
app.use('/families', pointSystem);
app.use('/config/feature-toggles', featureToggles);

const server = createServer(app);
const wss = new WebSocketServer({ noServer: true });

server.on('upgrade', (req, socket, head) => {
  const url = new URL(req.url ?? '', 'http://localhost');
  if (url.pathname === '/asr/stream') {
    wss.handleUpgrade(req, socket, head, (ws) => {
      handleASRUpgrade(ws, req);
    });
  } else {
    socket.destroy();
  }
});

server.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
```

- [ ] **Step 3: Verify it builds**

```bash
cd server && npm run build
```

Expected: `dist/` emits without TypeScript errors. (The `handleASRUpgrade` import will fail until Task 2 creates the file — that's expected. You can stub `server/src/routes/asr.ts` as an empty export to unblock the build now:)

```bash
echo "export function handleASRUpgrade(_ws: any, _req: any): void {}" > server/src/routes/asr.ts
npm run build
```

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
cd server
git add package.json package-lock.json src/index.ts src/routes/asr.ts
git commit -m "feat: add ws package and http.Server wrapper for WebSocket support"
```

---

## Task 2: Create `server/src/routes/asr.ts`

**Files:**
- Modify: `server/src/routes/asr.ts` (replace the stub from Task 1)

- [ ] **Step 1: Write the full route**

```typescript
import { WebSocket } from 'ws';
import { IncomingMessage } from 'http';
import jwt from 'jsonwebtoken';

interface AuthPayload {
  sub: number;
  username: string;
}

// Tracks active session counts per user for rate limiting.
// Keys are user IDs; values are counts of open sessions.
const activeSessions = new Map<number, number>();
const MAX_SESSIONS_PER_USER = 2;
const MAX_SESSION_MS = 60_000;

export function handleASRUpgrade(ws: WebSocket, req: IncomingMessage): void {
  // --- Auth ---
  const url = new URL(req.url ?? '', 'http://localhost');
  const token = url.searchParams.get('token');
  const secret = process.env.JWT_SECRET;

  if (!token || !secret) {
    ws.close(4001, 'unauthorized');
    return;
  }

  let auth: AuthPayload;
  try {
    auth = jwt.verify(token, secret) as unknown as AuthPayload;
  } catch {
    ws.close(4001, 'unauthorized');
    return;
  }

  // --- Rate limit ---
  const userId = auth.sub;
  const currentSessions = activeSessions.get(userId) ?? 0;
  if (currentSessions >= MAX_SESSIONS_PER_USER) {
    ws.send(JSON.stringify({ type: 'error', message: 'rate_limited' }));
    ws.close(4029, 'too many sessions');
    return;
  }

  activeSessions.set(userId, currentSessions + 1);

  const cleanup = () => {
    const n = activeSessions.get(userId) ?? 1;
    activeSessions.set(userId, Math.max(0, n - 1));
    clearTimeout(sessionTimeout);
  };

  // --- Session timeout (60s hard cap to prevent runaway billing) ---
  const sessionTimeout = setTimeout(() => {
    ws.send(JSON.stringify({ type: 'error', message: 'session_timeout' }));
    ws.close(1000, 'session timeout');
  }, MAX_SESSION_MS);

  ws.on('close', cleanup);
  ws.on('error', cleanup);

  // --- Volcengine credential check ---
  const hasCredentials = !!(
    process.env.VOLCENGINE_ASR_APP_ID && process.env.VOLCENGINE_ASR_TOKEN
  );

  if (!hasCredentials) {
    // No credentials yet — tell iOS to fall back to Apple ASR immediately.
    ws.send(JSON.stringify({ type: 'error', message: 'no_credentials' }));
    ws.close(1000, 'no credentials');
    return;
  }

  // --- Volcengine relay (active once credentials are set via fly secrets) ---
  // TODO: replace this section with Volcengine WebSocket relay when credentials are available.
  // Shape:
  //   1. Open WebSocket to Volcengine streaming ASR endpoint using VOLCENGINE_ASR_APP_ID + VOLCENGINE_ASR_TOKEN
  //   2. Send connected acknowledgment to iOS: ws.send(JSON.stringify({ type: 'connected' }))
  //   3. On binary message from iOS: forward to Volcengine socket
  //   4. On JSON result from Volcengine: forward { type: 'partial'|'final', text } to iOS
  //   5. On either socket closing: close the other
  ws.send(JSON.stringify({ type: 'error', message: 'not_implemented' }));
  ws.close(1000, 'not implemented');
}
```

- [ ] **Step 2: Build**

```bash
cd server && npm run build
```

Expected: no TypeScript errors.

- [ ] **Step 3: Smoke test with wscat**

Start the server locally: `npm run dev`

In a second terminal, install wscat if needed (`npm install -g wscat`), then test unauthenticated rejection:

```bash
wscat -c "ws://localhost:3000/asr/stream"
```

Expected: connection closes immediately (no token → 4001).

Test with an invalid token:

```bash
wscat -c "ws://localhost:3000/asr/stream?token=badtoken"
```

Expected: connection closes immediately.

To test with a valid token, log in via the app and copy the JWT from Xcode console, then:

```bash
wscat -c "ws://localhost:3000/asr/stream?token=<paste_jwt>"
```

Expected: receives `{"type":"error","message":"no_credentials"}` then connection closes. This is correct — iOS will fall back to Apple.

- [ ] **Step 4: Commit**

```bash
cd server
git add src/routes/asr.ts
git commit -m "feat: add /asr/stream WebSocket route with auth, rate limit, and no_credentials stub"
```

---

## Task 3: Create `ASRBackend.swift` protocol (iOS)

**Files:**
- Create: `ios/TheBetterWe/TheBetterWe/Services/ASRBackend.swift`

- [ ] **Step 1: Create the file**

```swift
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
```

- [ ] **Step 2: Build (Cmd+B in Xcode)**

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Services/ASRBackend.swift
git commit -m "feat: add ASRBackend protocol and ASRError"
```

---

## Task 4: Create `AppleBackend.swift` (iOS)

**Files:**
- Create: `ios/TheBetterWe/TheBetterWe/Services/AppleBackend.swift`

This is a mechanical extraction of the `SFSpeechRecognizer` block currently in `ASRService.startListening()` (lines 85–122).

- [ ] **Step 1: Create the file**

```swift
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
```

- [ ] **Step 2: Build (Cmd+B)**

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Services/AppleBackend.swift
git commit -m "feat: add AppleBackend — SFSpeechRecognizer wrapped in ASRBackend protocol"
```

---

## Task 5: Create `VolcengineBackend.swift` (iOS)

**Files:**
- Create: `ios/TheBetterWe/TheBetterWe/Services/VolcengineBackend.swift`

- [ ] **Step 1: Create the file**

```swift
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
            // Flush ring buffer on main queue to avoid audio-thread / main-thread race.
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
```

- [ ] **Step 2: Build (Cmd+B)**

Expected: no errors. Ignore any Sendable warnings on `AVAudioConverter`.

- [ ] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Services/VolcengineBackend.swift
git commit -m "feat: add VolcengineBackend — WebSocket relay with ring buffer and AVAudioConverter downsampler"
```

---

## Task 6: Refactor `ASRService.swift`

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Services/ASRService.swift`

Remove the `SFSpeechRecognizer` internals, add `engineLabel`, and delegate to backends.

- [ ] **Step 1: Replace the entire file**

```swift
import Foundation
import AVFoundation
import Speech
import Combine

/// Owns the audio engine and silence detection. Delegates transcription to ASRBackend.
/// Try VolcengineBackend first; fall back to AppleBackend automatically on any error.
@MainActor
final class ASRService: NSObject, ObservableObject {

    // MARK: - Published state

    @Published private(set) var interimTranscript: String = ""
    @Published private(set) var confirmedTranscript: String = ""
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
                self.handleAudioLevel(rms: rms, silenceTimeout: silenceTimeout)
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
            // Immediate failure (e.g., no auth token) — skip to Apple now.
            fallbackToApple()
        }

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
        backend.onConnected = { [weak self] in
            self?.engineLabel = backend.engineLabel
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
        activeBackend?.stop()
        guard let format = capturedAudioFormat else { return }
        let apple = AppleBackend()
        wire(backend: apple)
        activeBackend = apple
        try? apple.start(audioFormat: format)
    }

    private func handleAudioLevel(rms: Float, silenceTimeout: TimeInterval) {
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
```

- [ ] **Step 2: Build (Cmd+B)**

Expected: no errors. `ASRService` no longer imports `Speech` directly (that moved to `AppleBackend`) — remove the `import Speech` line if the compiler warns.

- [ ] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Services/ASRService.swift
git commit -m "feat: refactor ASRService to use ASRBackend protocol, add engineLabel, try Volcengine first"
```

---

## Task 7: Update `VoiceInputView.swift` status label

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Views/Voice/VoiceInputView.swift`

- [ ] **Step 1: Replace `statusLabel` with `statusText` in `VoiceInputView`**

Find and remove the `statusLabel` computed property (lines ~118–124):

```swift
// REMOVE this entire property:
private var statusLabel: LocalizedStringKey {
    switch voiceState {
    case .listening:                  return "超时"
    case .talking:                    return "聆听中"
    case .stoppedMatch, .stoppedNoMatch: return "已停止"
    }
}
```

Add this property in its place:

```swift
private var statusText: Text {
    switch voiceState {
    case .listening:
        return Text("超时")
    case .talking:
        return asr.engineLabel.isEmpty
            ? Text("聆听中")
            : Text("聆听中") + Text(verbatim: "[\(asr.engineLabel)]")
    case .stoppedMatch, .stoppedNoMatch:
        return Text("已停止")
    }
}
```

- [ ] **Step 2: Update `statusIndicator` to use `statusText`**

Find `statusIndicator` (around line 99) and change `Text(statusLabel)` to `statusText`:

```swift
private var statusIndicator: some View {
    HStack(spacing: 6) {
        Circle()
            .fill(statusDotColor)
            .frame(width: VoiceInputStyle.statusDotSize, height: VoiceInputStyle.statusDotSize)
        statusText
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
    }
}
```

- [ ] **Step 3: Build (Cmd+B)**

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Views/Voice/VoiceInputView.swift
git commit -m "feat: show active ASR engine in voice sheet status label"
```

---

## Task 8: End-to-end manual test on device

- [ ] **Step 1: Deploy server**

```bash
cd server && fly deploy
```

Expected: deploy succeeds, `https://thebetterwe-api.fly.dev/health` returns `{"status":"ok"}`.

- [ ] **Step 2: Run app on real device (not Simulator — ASR is broken on iOS 26 beta Simulator)**

Build and run via Xcode (Cmd+R) on a physical iPhone.

- [ ] **Step 3: Verify Apple fallback (current behaviour — no Volcengine credentials)**

Test checklist:
1. Log in and tap the `+` tab bar button → voice sheet opens
2. Status shows orange dot + "超时" (no engine label yet — correct, still in `.listening` state)
3. Within ~1 second: VolcengineBackend connects → server returns `no_credentials` → fallback to AppleBackend fires
4. Start speaking → status changes to blue dot + **"聆听中[Apple]"** ✓
5. Transcript updates in real time (gray interim → dark confirmed) ✓
6. Stop speaking for 1.5 seconds → wave bars flatten, "已停止", error card appears ✓
7. Tap mic → clears transcript, restarts from "超时" state ✓
8. Tap ✕ → sheet dismisses ✓

- [ ] **Step 4: Verify rate limit**

Open two voice sheets simultaneously (hard to do with one phone — skip for now; the server-side counter protects it).

- [ ] **Step 5: Commit any fixes found during testing**

---

## Self-Review

### Spec coverage

| Spec requirement | Task |
|-----------------|------|
| Server proxy — iOS never holds Volcengine credentials | Task 2 (credentials in env vars, never sent to client) ✓ |
| Real-time partial transcripts via WebSocket | Tasks 2, 5, 6 — `onPartialTranscript` callback chain ✓ |
| Apple fallback on server error | Task 6 — `wire(backend:).onError → fallbackToApple()` ✓ |
| Fallback on 2s connection timeout | Task 5 — `VolcengineBackend.connectionTimeoutTimer` ✓ |
| Fallback on `no_credentials` server error | Task 2 (server sends it), Task 5 (client handles it) ✓ |
| `聆听中[火山]` / `聆听中[Apple]` status label | Task 7 — `statusText` computed property ✓ |
| No engine label shown during `.listening` state | Task 7 — `statusText` for `.listening` returns `Text("超时")`, not the engine label ✓ |
| No flash of "[]" if engineLabel not yet set | Task 7 — `asr.engineLabel.isEmpty` guard ✓ |
| Audio buffered during connection window | Task 5 — `VolcengineBackend.ringBuffer` with `NSLock` ✓ |
| Ring buffer max 512 frames then drop | Task 5 — `ringBufferMax = 512` ✓ |
| `AuthService.accessToken` for WebSocket URL | Task 5 — `VolcengineBackend.start()` ✓ |
| Rate limit: 2 concurrent sessions per user | Task 2 — `activeSessions` map, `MAX_SESSIONS_PER_USER = 2` ✓ |
| 60s per-session hard cap | Task 2 — `sessionTimeout` timer ✓ |
| Volcengine relay stubbed with TODO comment | Task 2 — clearly marked TODO section ✓ |
| `VOLCENGINE_ASR_APP_ID` + `VOLCENGINE_ASR_TOKEN` env vars | Task 2 — `hasCredentials` check ✓ |
| No code changes needed to activate Volcengine, only `fly secrets set` | Task 2 — env var check is dynamic ✓ |
| `AVAudioConverter` for 44.1kHz→16kHz downsampling | Task 5 — `VolcengineBackend.downsample()` ✓ |
| Thread-safe ring buffer | Task 5 — `NSLock` wrapping all `ringBuffer` access ✓ |

### Placeholder scan

No TBD / TODO / "implement later" phrases in the iOS tasks. The server `asr.ts` contains one clearly-marked `// TODO:` inside a comment block explaining exactly what to implement — this is intentional, not a placeholder gap.

### Type consistency

- `ASRBackend` protocol defined in Task 3, implemented by `AppleBackend` (Task 4) and `VolcengineBackend` (Task 5), held as `any ASRBackend` in `ASRService` (Task 6) ✓
- `ASRError` defined in Task 3, thrown in Task 5 ✓
- `engineLabel: String` on protocol (Task 3) matches `asr.engineLabel` read in Task 7 ✓
- `onConnected`, `onPartialTranscript`, `onFinalTranscript`, `onError` — all defined in Task 3, wired in `ASRService.wire(backend:)` (Task 6), implemented in Tasks 4 and 5 ✓
- `ServerMessage` struct in `VolcengineBackend` (Task 5) matches JSON shape sent by server in Task 2 ✓
