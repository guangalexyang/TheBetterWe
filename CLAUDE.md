# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**TheBetterWe** is a family daily-routine iOS app. It is the hub that integrates smaller family tools (OrderFromMe, RewardMe, and future tools) into one place, alongside its own core features.

The app serves parents managing family life. Children may have their own accounts (with a `"child"` role keyword in the family), or parents can create profile-only child roles (`user_id = NULL`) for young kids who don't log in.

## Core Features

- **Family & Personal TODOs / Done** — task tracking at both family and individual level
- **Highlight of the Day** — event with text + optional photo; creator can choose to notify other family members
- **OrderFromMe integration** — recipes, meal invitations, shopping lists (shopping lists sync with TODOs)
- **RewardMe integration** — points and rewards for children

## Integration Philosophy

OrderFromMe and RewardMe may exist as separate web apps with their own hosting/URLs, or as iOS apps. TheBetterWe integrates them — do not assume they share a codebase or can be directly imported. Integration is API-based or via deep links depending on how each tool is deployed at the time of integration.

## Tech Stack

### iOS Client
- SwiftUI, SwiftData (local persistence for personal TODOs/Done only)
- When offline, app only shows what is in local database (personal TODOs/Done). No cached family data — family features show an offline indicator.
- Light theme first; dark/custom theme designed later with reference screenshots
- Chinese + English localization (`.xcstrings` from the start)
- Build UI **view by view, step by step** — never scaffold multiple views at once without user approval

### Server
- Node.js + Express.js + **TypeScript**
- **PostgreSQL everywhere** — Postgres.app for local dev, fly.io managed Postgres in production
- Schema managed via numbered migration files in `server/migrations/` using `node-pg-migrate`
- Local dev: `npm run migrate` then `npm run dev`; deploy: `fly deploy` (migrations run automatically via `release_command`)
- RESTful API — iOS client communicates via HTTP
- **Deployed:** `https://thebetterwe-api.fly.dev`

### Apple Watch
- Later phase — syncs with iOS under same account

## Data Architecture

**Local (SwiftData on device):**
- Personal TODOs and Done items only
- No family data cached locally

**Server (PostgreSQL — Postgres.app local, fly.io managed Postgres in production):**
- User accounts and authentication
- Family groups and membership — a user can belong to multiple families; `family_members` is a junction table
- Child roles have no user account (`user_id` is null); managed by parents
- Family TODOs, Done, Highlights
- Integration records linking to OrderFromMe, RewardMe

**Personal TODO sync (local ↔ server):**
- Both local (SwiftData) and server store personal TODOs
- Each record carries `updated_at` on both sides
- Sync strategy: last-write-wins with field-level merging — each field carries its own `updated_at`; conflicting fields are resolved independently rather than one side overwriting the whole record
- Sync runs on app launch and when coming back online
- Full conflict resolution UI not needed — personal TODOs are owned by one user, simultaneous edits across devices are rare and low-stakes
- Required for Apple Watch support in a later phase

## Feature Toggle System

Every new feature must be behind a toggle. Toggles are served by the backend via `GET /config/feature-toggles` and fetched by the iOS app on every launch.

- Server config is in-memory in `server/src/routes/featureToggles.ts` — edit and redeploy to enable/disable without a new app release
- iOS caches the last successful response locally; uses the cache if the server is unreachable
- If never fetched before and offline, all toggles default to **off**
- This allows shipping client code with a toggle off, then enabling it from the server when ready

**Git workflow — dev-to-master merges only happen for one of these three reasons:**
1. Add the toggle (off by default on server)
2. All feature code complete, still behind toggle, merge to master
3. Remove the toggle (feature fully shipped)

## AI Integration (Phased)

- Every database operation (local or server) should have a corresponding API endpoint suitable for AI invocation
- Document AI-callable APIs: natural language trigger + endpoint + parameters
- Phase 1: Siri via App Intents
- Phase 2: Doubao

## Notifications

- When creating a Highlight or completing a family event, creator can optionally notify other family members
- Push notifications sent only when the creator opts in

## Project Structure

```
TheBetterWe/
├── CLAUDE.md
│
├── ios/                        # iOS client
│   ├── TheBetterWe.xcodeproj
│   └── TheBetterWe/
│       ├── App/                # Entry point, config, feature flag loader
│       ├── Models/             # SwiftData + API response models
│       ├── Views/              # SwiftUI views, grouped by feature
│       ├── ViewModels/         # @Observable view models
│       ├── Services/           # API client, sync engine
│       ├── Intents/            # App Intents (Siri — AddPointsIntent, DeductPointsIntent)
│       └── Resources/          # Assets, .xcstrings (en/zh)
│
└── server/                     # Node.js + Express + TypeScript
    ├── src/
    │   ├── routes/             # Express route definitions + request handlers
    │   ├── db/                 # pg.Pool singleton
    │   ├── middleware/         # Auth, error handling, logging
    │   └── services/           # External integrations (OrderFromMe, RewardMe etc.)
    ├── migrations/             # node-pg-migrate numbered migration files
    ├── Dockerfile              # fly.io container build
    ├── fly.toml                # fly.io deployment config
    ├── package.json
    └── .env.example
```

## Technical Patterns & Gotchas

### iOS — Audio (AVAudioEngine + ASRBackend)

- **ASRBackend protocol:** `ASRService` holds `activeBackend: (any ASRBackend)?`. Conformers: `AppleBackend` (SFSpeechRecognizer) and `VolcengineBackend` (WebSocket relay). `wire(backend:)` attaches callbacks. `onError` triggers `fallbackToApple()` automatically.
- **Retain cycle in wire():** Capture `let label = backend.engineLabel` as a `String` value before the closure — never capture `backend` inside its own `onConnected` closure or you get a retain cycle.
- **appendBuffer thread safety:** The AVAudioEngine tap calls `appendBuffer` from the audio thread. Backends that buffer data (e.g. `VolcengineBackend` ring buffer) must protect mutable state with `NSLock`.
- **engineLabel:** `@Published private(set) var engineLabel: String` on `ASRService`; empty until backend connects. `VoiceInputView` shows `聆听中[火山]` or `聆听中[Apple]` using `Text("聆听中") + Text(verbatim: "[…]")` — never string interpolation inside a single `Text()`.
- **ASR bootstrap — decouple startListening from noSpeechTimer:** `startListening(silenceTimeout:)` starts audio engine + WebSocket but does NOT start noSpeechTimer. Call `arm(noSpeechTimeout:)` only after `engineLabel` becomes non-empty (i.e. `onConnected` fired). In `VoiceInputView`, use `.onChange(of: asr.engineLabel)` guarded by `voiceState == .bootstrapping` to trigger `arm()` + transition to `.listening`. Starting the timer before bootstrap would dismiss the sheet during fly.io cold start.
- **fly.io cold start — minimum 5s timeout:** fly.io machines auto-stop when idle; cold start takes 1–3s. Any connection timeout to `thebetterwe-api.fly.dev` (WebSocket or HTTP) must be **≥ 5 seconds**. `VolcengineBackend` uses 5s. The WebSocket upgrade itself wakes fly.io — no separate ping endpoint needed. `onConnected` IS the signal that fly.io is up AND Volcengine is ready.
- **ASRDiagnosticView:** DEBUG-only in-app integration test at `Views/Voice/ASRDiagnosticView.swift`. Long-press the status label in `VoiceInputView` to open it. Logs in as `test/admin123`, injects synthetic PCM audio, shows the full event timeline on screen. Use this to debug connection issues without Xcode.

### iOS — Audio (AVAudioEngine + SFSpeechRecognizer)
- **Fresh engine per session:** Never reuse a stopped `AVAudioEngine`. After `stop()`, `inputNode.outputFormat(forBus:)` returns 0 sample rate/channels, crashing `installTap`. Create `let engine = AVAudioEngine()` fresh each call to `startListening`.
- **Session before engine:** Activate `AVAudioSession` before creating the engine — `inputNode.outputFormat` is 0/0 if the session isn't active when queried.
- **Session category:** Use `.playAndRecord` + `.default` mode + `.duckOthers`. `.record` causes I/O reconfig cycles on Simulator. `.measurement` mode disables AGC/noise reduction, causing `SFSpeechRecognizer` to never fire partial results.
- **Silence detection:** Track `isCurrentlySilent: Bool`. Only arm the silence timer on the **sound → silence transition** — not on every audio buffer below threshold. Buffers arrive every ~23ms; resetting the timer per buffer means it never fires.
- **rmsThreshold:** Use `0.015` for real device. `0.003` is too low — real device ambient noise (room tone, HVAC) sits above it, so silence is never detected and the app stays in listening state forever. Tune on device, not Simulator.
- **stopRecording on silence:** Always call `asr.stopRecording()` when `onSilenceDetected` fires — not just change UI state. Without it the audio engine keeps running in the background.
- **Privacy keys:** This project uses `GENERATE_INFOPLIST_FILE = YES` — there is no standalone `Info.plist`. Add privacy keys as `INFOPLIST_KEY_NSMicrophoneUsageDescription` and `INFOPLIST_KEY_NSSpeechRecognitionUsageDescription` directly in `project.pbxproj` under **both** Debug and Release `buildSettings`.
- **Simulator ASR broken (iOS 26 beta):** All locales (zh-Hans and en-US) fail with `kLSRErrorDomain Code=300` — the on-device `mini.json` model files are corrupted. `recognizer?.isAvailable` returns `true` but `recognitionTask` fails immediately. There is no code workaround. **Test all ASR features on a real device.**

### iOS — Networking
- **URL construction with query params:** Never use `URL.appending(path:)` when the path contains `?` — it percent-encodes `?` as `%3F`, breaking Express routing. Always use `URL(string: baseURL.absoluteString + path)`.
- **Error handling in service calls:** Never use `try?` on async API calls in views. Use `do-catch` and store the error in a `@State var loadError: String?` to surface it in the UI. Silent failures show empty state with no diagnostic.
- **ActivitySection reload:** Use `.id("key-\(child.balance)")` to force a view identity change (and `.task` re-fire) after a balance update.

### iOS — Time & Calendar
- **Calendar day change detection:** Use `.onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged))` to reload data at local midnight while the app is in foreground. Pair with a `scenePhase → .active` + date-string comparison (`localDateString() != lastLoadedDate`) to handle the case where midnight passed while the app was backgrounded. Never use `Task.sleep(nanoseconds:)` for this — it uses `SuspendingClock` and pauses during device sleep, so it won't fire at midnight if the device was asleep.

### iOS — Layout
- **Shape without height in HStack expands infinitely:** A `RoundedRectangle` (or any Shape) with only `width` constrained inside a `HStack` proposes infinite height, pulling the entire card to fill available vertical space. Fix: add `.fixedSize(horizontal: false, vertical: true)` on the `HStack` so it hugs content height.
- **TimelineView keeps running in all states:** `TimelineView(.animation)` animates continuously regardless of external state. Gate it behind a conditional — render a plain static view when animation should stop (e.g. stopped/idle state).

### iOS — Sheets & Presentation
- **Sheet height:** Use `.presentationDetents([.height(X)])` with a calculated pixel value. `.medium` (~50% screen) is almost always too short; `.large` wastes space. Estimate: header ~70pt + fields ~70pt each + footer ~96pt + spacing.
- **Dynamic sheet height:** Two detents + `@Binding var detent: PresentationDetent` passed into the sheet. Reset to small detent `onDismiss`. Example: `.height(510)` ↔ `.height(730)` driven by `onChange(of:)` inside the sheet.
- **Per-state sheet height (multi-state machines):** For sheets that pass through many states (e.g. `VoiceInputView`), use a `detentHeight: CGFloat` computed property that switches on the state enum, and pass `[.height(detentHeight)]` to `.presentationDetents`. SwiftUI animates the resize automatically. The caller must NOT also set `.presentationDetents`. Store height constants in the style enum, not inline.
- **Conditional gradient vs Color background:** Use the `@ViewBuilder` form of `.background { }` — `if selected { Shape().fill(LinearGradient(...)) } else { Shape().fill(Color) }`. Avoids `AnyShapeStyle` boilerplate; compiles cleanly because the closure accepts any `View`.
- **DatePicker compact in sheets:** Always add `.fixedSize()` to `DatePicker(.compact)` — without it the picker's intrinsic width inflates the parent layout and can widen the sheet.
- **GeometryReader in .background():** Never use `GeometryReader` inside `.background()` on any view that contains a `TextField`. It creates UIKit Auto Layout views that conflict with the keyboard's internal constraints, producing `UIViewAlertForUnsatisfiableConstraints` on every tap.
- **lineLimit ternary:** `.lineLimit(isX ? 1...5 : 1)` is a type error. Use `.lineLimit(isX ? 1...5 : 1...1)` — both branches must be `ClosedRange<Int>`.
- **iOS 26 — confirmationDialog and alert are liquid glass:** On iOS 26, `confirmationDialog` and `alert` render as the new liquid glass context menu, not a classic action sheet or centered alert. For bottom action sheet style, use `fullScreenCover` with a custom `ZStack` (dark backdrop + white grouped cards + Cancel). For centered confirmation dialogs, use a `.overlay { ZStack { Color.black.opacity(0.4).ignoresSafeArea(); card } }` with `.animation(.easeOut, value: showConfirm)` and `.transition(.opacity.combined(with: .scale(scale: 0.92)))` on the card.
- **Custom action sheet split animation:** `fullScreenCover` slides all content as one unit. To animate the backdrop (fade) and cards (slide up) independently: (1) trigger with `Transaction.disablesAnimations = true` to suppress the cover's built-in slide, (2) use a separate `@State var menuVisible` inside the cover content, (3) `.onAppear { withAnimation(.easeOut(duration: 0.28)) { menuVisible = true } }` drives `Color.black.opacity(menuVisible ? 0.4 : 0)` and `.offset(y: menuVisible ? 0 : 300)` on the cards, (4) dismiss by animating `menuVisible = false` first, then closing the cover after a short delay with another `disablesAnimations` transaction.

### iOS — Models
- All PostgreSQL timestamp columns are `INTEGER` (Unix epoch via `EXTRACT(EPOCH FROM NOW())::INTEGER`). Decode as `Int`, never `String`.
- `PSActivity.createdAt: Int`, not `String`.
- **Activity date display — use `createdAt`, not `eventDate`:** For showing when an activity happened, use `Date(timeIntervalSince1970: TimeInterval(createdAt))`. Never parse the `eventDate` YYYY-MM-DD string as UTC midnight for display — for UTC-N users, midnight UTC on date D is still D-1 locally, causing today's events to show as "Yesterday".
- **Date-only display:** Use `setLocalizedDateFormatFromTemplate("MMMd")` (or `"MMMdyyyy"` for cross-year dates) for all user-facing date strings — it automatically adds locale-specific suffixes like "日" in Chinese. Never hardcode `dateFormat = "MMM d"`.
- **Timezone-correct period queries:** iOS must send the device's local date as `?localDate=YYYY-MM-DD` on any request whose result depends on "today / this week / this month". Use `localDateString()` (defined in `PointSystemService.swift`) for this. Also pass `date: localDateString()` in POST bodies for event records so `event_date` stores device local date.

### Server — WebSocket (ASR proxy)
- **WebSocket upgrade:** Use `http.createServer(app)` + `WebSocketServer({ noServer: true })`. Handle upgrades via `server.on('upgrade', ...)` and route by pathname. `app.listen()` does not support WebSocket upgrades.
- **Volcengine binary protocol:** Frames are `[4-byte header][4-byte size][gzip payload]`. Full server response adds a 4-byte sequence before size. Use `gzipSync`/`gunzipSync` from Node built-in `zlib`. No extra npm package needed.
- **Auth for WebSocket:** Token passed as `?token=<jwt>` query param (HTTP headers not available after upgrade in most clients). Validate with `jwt.verify` before doing anything else.
- **Rate limit by user ID, not IP:** Families may share an IP. Track `Map<userId, sessionCount>`. Also enforce a per-session hard timeout (60s) via `setTimeout` to prevent runaway billing.
- **Cleanup pattern:** Always attach both `ws.on('close', cleanup)` and `ws.on('error', cleanup)` and define `cleanup` before registering them to avoid double-counting.

### Server
- All new tables must use `INTEGER` epoch timestamps, not `timestamptz`.
- **Exception — date-only columns:** Store date-only values (goal start/end dates, event dates) as `TEXT` YYYY-MM-DD, not `INTEGER` epoch. `TO_TIMESTAMP(epoch)::DATE` uses UTC timezone, causing an off-by-one day for UTC+ users. TEXT strings cast directly: `column::DATE`.
- **PostgreSQL `SUM()` returns `BIGINT`:** node-postgres serializes BIGINT as a JavaScript string. Always cast `SUM(col)::INTEGER` and `COALESCE(SUM(col), 0)::INTEGER` for any aggregate destined for an iOS `Int` field. Silent decode failure looks identical to an empty result.
- **Timezone-correct period windows:** Accept `req.query.localDate` (YYYY-MM-DD), validate with a `validDate()` helper, and use `COALESCE($n::DATE, CURRENT_DATE)` in SQL. `DATE_TRUNC('week', ...)` in PostgreSQL uses ISO 8601 (Monday start).
- Always guard `parseInt` params with a NaN check (`parseIntParam` helper) and return 400 before running SQL.
- `pg.Pool` requires `.on('error', ...)` handler — idle client errors without it crash the process.
- Feature toggles live in `src/routes/featureToggles.ts` (in-memory object). No JSON file.
- **Cascading deletes — order matters:** Delete child tables before the parent row inside a BEGIN/COMMIT transaction. For a child member: `point_events` → `point_goals` → `member_role_keywords` → `family_members`. Foreign key constraints prevent deleting the parent first.

## UI

Build UI **view by view** — never scaffold multiple views at once without user approval. Follow the patterns in [`docs/ui-design-practices.md`](docs/ui-design-practices.md) for style constants, navigation transitions, form fields, password fields, and validation.

## Development Phases

1. **Phase 1 (current)** — iOS app + Node/Express server + PostgreSQL; user auth, family setup, Point System (kids + rules + points + redemptions + goals), personal + family TODOs/Done, Highlight of the Day
   - ✅ Backend deployed to fly.io — `https://thebetterwe-api.fly.dev`
   - ✅ Siri App Intents — `AddPointsIntent` + `RedeemRewardIntent`; `RecordPointsIntent` and `TheBetterWeShortcuts` removed (superseded by in-app voice flow); re-implement when Siri AI releases
   - ✅ App display name: **佳家** (`INFOPLIST_KEY_CFBundleDisplayName` in pbxproj)
   - ✅ Point System goals — create, lifespan (daily/weekly/monthly/one-time), period progress, fulfilled UI
   - ✅ Voice Input ASR sheet — `+` tab bar button opens 5-state bottom sheet; `AVAudioEngine` + `SFSpeechRecognizer` (zh-Hans on device); silence detection, error card, mic nudge animation
   - ✅ Volcengine ASR — full server proxy at `/asr/stream` WebSocket; `ASRBackend` protocol with `AppleBackend` + `VolcengineBackend`; status label shows `聆听中[火山]` or `聆听中[Apple]`; falls back to Apple automatically; credentials set (`APP_ID=3598972451`, resource `volc.bigasr.sauc.duration`), deployed and active
   - ✅ ASR bootstrap flow — `VoiceInputState.bootstrapping` shows spinner + "连接中" while fly.io wakes and Volcengine connects; `startListening()` does not start noSpeechTimer; `arm(noSpeechTimeout:)` called in `onChange(of: engineLabel)` once non-empty; `ASRDiagnosticView` (DEBUG, long-press status label) for in-app connection testing
   - ✅ Child edit/delete — ▼ badge trigger in ChildCardView; AddChildView reused for edit mode (title always "宝宝信息"); server PUT + cascading DELETE routes; deployed
   - ✅ Child card action menu — custom bottom action sheet (`fullScreenCover`, split fade/slide animation); delete confirmation is custom centered card overlay (not system alert)
   - ✅ `event_type` on `point_events` — `add`/`deduct`/`redeem`; migration 007 backfills existing rows from delta sign; voice parse LLM uses `action: "add"|"deduct"|"redeem"` field (not `isAdd: boolean`); `ActivityRow` icon/color/label driven by `eventType`
   - ✅ Feature toggles for `familyTodo`, `familyNotes`, `orderFromMe` — tabs and dashboard cards gated by `AppModule.isToggleActive`; all three currently **off** on server (pending implementation)
   - ✅ VoiceInputView UI redesign — 6-state per-state sheet heights, gradient mic (68pt), pulse rings in recording, "语音指令 + ×" header on all phases, 5s no-speech timeout (was 3s), mic nudge animation removed; `VoiceInputStyle.sheetHeight` removed, replaced by per-state constants
   - ✅ AddChildView UI redesign — top bar Cancel + centered title; live avatar (gradient + emoji reflecting selected gender, camera badge is decorative only — no photo upload, PSChild has no photo field); form card with compact DatePicker birthday (hasBirthday toggle + × clear), Boy/Girl gradient cards; Reward Profile tip; gradient capsule submit button; light/dark via UIColor dynamic providers
2. **Phase 2** — OrderFromMe integration (recipes, shopping list ↔ TODOs)
3. **Phase 3** — RewardMe standalone integration (if needed beyond Phase 1 Point System)
4. **Phase 4** — Doubao API (in-app natural language point recording) ✅ done — voice parse endpoint at `/voice/parse`
5. **Phase 5** — Apple Watch companion
