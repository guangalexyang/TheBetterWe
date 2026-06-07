# Volcengine ASR Integration — Design Spec

**Date:** 2026-06-06  
**Status:** Approved  
**Scope:** Replace `SFSpeechRecognizer` with a Volcengine streaming ASR proxy, keeping Apple ASR as automatic fallback.

---

## 1. Goals

- Stream real-time partial + final transcripts through our Node server to Volcengine's WebSocket ASR API.
- Keep `SFSpeechRecognizer` as an automatic fallback (used during development and when the server is unreachable).
- Surface the active engine in the voice sheet status label: `聆听中[火山]` or `聆听中[Apple]`.
- Credentials never touch the iOS client.

---

## 2. Architecture

```
iOS (ASRService)
  └── VolcengineBackend (try first)
        │  PCM audio frames (16kHz/16-bit/mono)
        │  WebSocket: wss://thebetterwe-api.fly.dev/asr/stream?token=<authToken>
        ▼
  Node Server (/asr/stream WebSocket route)
        │  relays audio →
        ▼
  Volcengine Streaming ASR WebSocket
        │  partial + final JSON results →
        ▼
  Node Server
        │  relays results →
        ▼
iOS (ASRService)
  └── AppleBackend (fallback if VolcengineBackend fails to connect within 2s)
```

The server is a **pure relay** — no audio processing, no storage. It opens two WebSocket connections per session (one to iOS, one to Volcengine) and forwards bytes between them.

---

## 3. iOS Changes

### 3.1 ASRBackend Protocol

New file: `Services/ASRBackend.swift`

```swift
protocol ASRBackend: AnyObject {
    var onPartialTranscript: ((String) -> Void)? { get set }
    var onFinalTranscript: ((String) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
    var engineLabel: String { get }      // "火山" or "Apple"

    func start(audioFormat: AVAudioFormat) throws
    func appendBuffer(_ buffer: AVAudioPCMBuffer)
    func stop()
}
```

### 3.2 VolcengineBackend

New file: `Services/VolcengineBackend.swift`

- On `start()`: read `AuthService.accessToken` (static keychain-backed property) and open `URLSessionWebSocketTask` to `wss://thebetterwe-api.fly.dev/asr/stream?token=<token>`.
- Connection timeout: **2 seconds**. If not connected, call `onError` → `ASRService` falls back to `AppleBackend`.
- **Audio buffering during connection:** `appendBuffer()` calls that arrive before the WebSocket is open are stored in a small in-memory ring buffer (max 512 frames). Once connected, the buffered frames are flushed before live frames. Frames beyond 512 are dropped.
- On `appendBuffer()` after connected: downsample PCM from the device's native rate (44.1kHz/32-bit) to **16kHz/16-bit mono** using `AVAudioConverter`, then send as binary WebSocket frame.
- Receive loop: parse JSON messages `{ "type": "partial"|"final", "text": "..." }` from server, call `onPartialTranscript` or `onFinalTranscript`.
- `engineLabel`: `"火山"`

**Credential placeholder:** `VolcengineBackend` reads no credentials itself — auth is handled entirely server-side via `VOLCENGINE_ASR_APP_ID` and `VOLCENGINE_ASR_TOKEN` env vars.

### 3.3 AppleBackend

New file: `Services/AppleBackend.swift`

Extracts the existing `SFSpeechRecognizer` block from `ASRService.startListening()` into `ASRBackend` conformance. No logic changes — pure mechanical extraction.

- `engineLabel`: `"Apple"`

### 3.4 ASRService Changes

`ASRService.startListening()` becomes:

1. Activate `AVAudioSession` (unchanged).
2. Create fresh `AVAudioEngine` (unchanged).
3. Install tap on `inputNode` (unchanged) — tap calls `activeBackend.appendBuffer(_:)`.
4. Try `VolcengineBackend` first: assign as `activeBackend`, call `start()`.
5. If `onError` fires within 2s: tear down, assign `AppleBackend`, call `start()`.
6. Silence detection, timers, callbacks — all unchanged.

New published property:

```swift
@Published private(set) var engineLabel: String = ""
```

Set when the active backend is decided. `VoiceInputView` reads this to build the status label.

### 3.5 VoiceInputView Change

Status label in `.talking` state changes from:

```swift
"聆听中"
```

to:

```swift
"聆听中[\(asr.engineLabel)]"
```

---

## 4. Server Changes

### 4.1 New Route: `/asr/stream` (WebSocket)

New file: `server/src/routes/asr.ts`

**Auth:** Validate Bearer token from the `token` query param using the existing `authenticateToken` middleware logic. Reject unauthenticated connections immediately.

**Per-session flow:**
1. Accept iOS WebSocket connection.
2. Open WebSocket connection to Volcengine streaming ASR (credentials from env vars `VOLCENGINE_ASR_APP_ID` and `VOLCENGINE_ASR_TOKEN`).
3. Relay binary frames (PCM audio) from iOS → Volcengine.
4. Relay JSON result messages from Volcengine → iOS.
5. On either connection closing: close both.

**Volcengine connection stub:** During development (no credentials), the server sends a single error frame `{ "type": "error", "message": "no_credentials" }` and closes — this triggers the iOS fallback to `AppleBackend`.

**Message format (server → iOS):**
```json
{ "type": "partial", "text": "给小明" }
{ "type": "final",   "text": "给小明加十分" }
{ "type": "error",   "message": "no_credentials" }
```

### 4.2 Rate Limiting

Applied to `/asr/stream` on the authenticated user ID (not IP — a family may share an IP):

- Max **2 concurrent WebSocket sessions per user**.
- Max **60 seconds per session** (server forcibly closes after this; prevents runaway billing if iOS fails to close cleanly).
- Once Volcengine credentials are wired in, also enforce a per-user **daily audio budget** (e.g. 300 seconds/day) configurable via an env var. Exceeding the budget returns `{ "type": "error", "message": "quota_exceeded" }`.

### 4.3 Wiring

In `server/src/index.ts`: mount the WebSocket upgrade handler for `/asr/stream` alongside existing HTTP routes. Use the `ws` npm package (already common in Express+WebSocket setups) or Node's built-in `http.Server` upgrade event.

---

## 5. Audio Format Pipeline

```
AVAudioEngine inputNode
  → 44.1kHz / 32-bit float / mono (device native)
  → [VolcengineBackend: downsample + convert]
  → 16kHz / 16-bit signed int / mono (Volcengine standard)
  → WebSocket binary frame (raw PCM, no container)
```

Downsampling is done on iOS using `AVAudioConverter` before sending. This reduces bandwidth from ~1.4 Mbps to ~256 Kbps.

---

## 6. Fallback Behavior

| Scenario | Result |
|----------|--------|
| Server WebSocket connects successfully | `聆听中[火山]` |
| Server unreachable / connection timeout (2s) | Fall back, `聆听中[Apple]` |
| Server returns `no_credentials` error | Fall back, `聆听中[Apple]` |
| Server returns `quota_exceeded` | Fall back, `聆听中[Apple]` |
| Apple SFSpeechRecognizer unavailable | `onError` fires, permission alert shown |

Fallback is invisible to the user except for the engine label change.

---

## 7. Credentials & Configuration

**Not needed to build.** The full plumbing is built and tested with the `no_credentials` stub path (always falls back to Apple). Volcengine credentials are dropped in as two env vars when ready:

```
VOLCENGINE_ASR_APP_ID=...
VOLCENGINE_ASR_TOKEN=...
```

No code changes needed to activate Volcengine once credentials exist — only `fly secrets set` and a redeploy.

---

## 8. Files Touched

| Action | Path |
|--------|------|
| Create | `ios/.../Services/ASRBackend.swift` |
| Create | `ios/.../Services/VolcengineBackend.swift` |
| Create | `ios/.../Services/AppleBackend.swift` |
| Modify | `ios/.../Services/ASRService.swift` — swap backend, add `engineLabel` |
| Modify | `ios/.../Views/Voice/VoiceInputView.swift` — update status label |
| Create | `server/src/routes/asr.ts` — WebSocket proxy route |
| Modify | `server/src/index.ts` — mount WebSocket upgrade handler |
| Modify | `server/package.json` — add `ws` + `@types/ws` if not present |

---

## 9. Out of Scope

- Volcengine language model selection (default to zh-Hans; configurable later via env var).
- Volcengine billing dashboard / quota monitoring (manual, via Volcengine console).
- Any NLP / intent parsing on the transcript (Phase 4).
- Apple Watch (Phase 5).
