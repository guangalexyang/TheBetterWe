# Voice Input (ASR) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a voice input bottom sheet triggered by the + tab bar button that records speech, transcribes via Apple SFSpeechRecognizer, and displays transcript + stub intent/error cards with a 5-state UI.

**Architecture:** `ASRService` (ObservableObject) owns AVAudioEngine + SFSpeechRecognizer and exposes transcript text plus audio level; `VoiceInputView` observes it and drives a local 5-state enum via Timer-based silence detection. The service is architected so Volcengine ASR can replace SFSpeechRecognizer in a single file swap later.

**Tech Stack:** SwiftUI, AVFoundation (AVAudioEngine), Speech (SFSpeechRecognizer), Swift Concurrency (async/await + MainActor), Combine (@Published). iOS 17+ minimum.

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `ios/TheBetterWe/TheBetterWe/Views/Voice/VoiceInputStyle.swift` | Color + size constants for the voice sheet |
| Create | `ios/TheBetterWe/TheBetterWe/Services/ASRService.swift` | Recording, SFSpeechRecognizer transcription, RMS audio level, silence detection callbacks |
| Create | `ios/TheBetterWe/TheBetterWe/Views/Voice/VoiceInputView.swift` | Bottom sheet: state machine, header, transcript area, wave bars, mic button with countdown ring, intent/error cards |
| Modify | `ios/TheBetterWe/TheBetterWe/Views/Main/MainTabView.swift` | Replace placeholder `Text("Create")` sheet with `VoiceInputView` |
| Modify | `ios/TheBetterWe/TheBetterWe/Resources/Localizable.xcstrings` | Add all Chinese + English strings for the voice sheet |

> **Important:** The iOS project uses an Xcode **synchronized folder** (`PBXFileSystemSynchronizedRootGroup`). Any new `.swift` file placed inside `TheBetterWe/` is automatically compiled — do **not** use "Add Files to target" or touch `project.pbxproj`.

---

## Design Reference

Full design spec: `/Users/alexyang/.claude/projects/-Users-alexyang-Claude-TheBetterWe/memory/project_asr_voice_input.md`
Final HTML mockup: `/Users/alexyang/Claude/TheBetterWe/.superpowers/brainstorm/11224-1780728993/content/voice-states-v13.html`

---

### Task 1: VoiceInputStyle.swift — constants

**Files:**
- Create: `ios/TheBetterWe/TheBetterWe/Views/Voice/VoiceInputStyle.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

enum VoiceInputStyle {
    // Sheet
    static let sheetHeightFraction: CGFloat = 0.72
    static let handleWidth: CGFloat = 36
    static let handleHeight: CGFloat = 4
    static let handleCornerRadius: CGFloat = 2

    // Colors
    static let appBlue = Color(red: 58/255, green: 123/255, blue: 213/255)
    static let appBlueLight = Color(red: 144/255, green: 186/255, blue: 240/255)  // wave bars idle
    static let timerOrange = Color(red: 1.0, green: 149/255, blue: 0)
    static let interimGray = Color(hex: "AEAEB2")
    static let confirmedColor = Color(hex: "1C1C1E")

    // Intent card
    static let intentCardBackground = Color(red: 240/255, green: 245/255, blue: 1.0)
    static let intentCardBorder = appBlue

    // Error card
    static let errorCardBackground = Color(red: 1.0, green: 245/255, blue: 245/255)
    static let errorCardBorder = Color(red: 1.0, green: 59/255, blue: 48/255)

    // Mic button
    static let micButtonSize: CGFloat = 60

    // Wave bars
    static let waveBarsCount: Int = 5
    static let waveBarWidth: CGFloat = 4
    static let waveBarMinHeight: CGFloat = 6
    static let waveBarMaxHeight: CGFloat = 32
    static let waveBarCornerRadius: CGFloat = 2
    static let waveBarSpacing: CGFloat = 5

    // Countdown ring
    static let countdownRingSize: CGFloat = 76    // mic + ring padding
    static let countdownRingLineWidth: CGFloat = 3

    // Typography
    static let transcriptFontSize: CGFloat = 12
    static let statusDotSize: CGFloat = 8
}

// Hex color helper (private, used only in this file's enum)
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

- [ ] **Step 2: Verify the file compiles (build in Xcode — Cmd+B)**

Expected: build succeeds, no errors.

- [ ] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Views/Voice/VoiceInputStyle.swift
git commit -m "feat: add VoiceInputStyle constants for ASR sheet"
```

---

### Task 2: ASRService.swift — recording + transcription engine

**Files:**
- Create: `ios/TheBetterWe/TheBetterWe/Services/ASRService.swift`

The service uses `SFSpeechRecognizer` for transcription. The public API is designed so that swapping to Volcengine ASR later only requires changing this one file.

**Info.plist keys required (user must add in Xcode):**
- `NSSpeechRecognitionUsageDescription` — "语音识别用于语音输入积分记录"
- `NSMicrophoneUsageDescription` — "麦克风用于语音输入"

- [ ] **Step 1: Create ASRService.swift**

```swift
import Foundation
import AVFoundation
import Speech
import Combine

/// Transcription + audio recording service.
/// Swap the SFSpeechRecognizer implementation for Volcengine ASR in this file only.
@MainActor
final class ASRService: NSObject, ObservableObject {

    // MARK: - Published state

    @Published private(set) var interimTranscript: String = ""
    @Published private(set) var confirmedTranscript: String = ""
    /// Normalized RMS level 0.0 … 1.0 for wave bar animation.
    @Published private(set) var audioLevel: Float = 0

    // MARK: - Silence-detection callbacks (set before calling startListening)

    /// Called once when the first audio above RMS threshold arrives (cancels the no-speech timer).
    var onFirstSpeechDetected: (() -> Void)?
    /// Called when silence persists for `silenceTimeout` after speech was detected.
    var onSilenceDetected: (() -> Void)?
    /// Called when no speech is detected within `noSpeechTimeout` of starting.
    var onNoSpeechTimeout: (() -> Void)?
    /// Called on a non-recoverable error (permission denied, engine start failure).
    var onError: ((Error) -> Void)?

    // MARK: - Private

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-Hans"))

    private var hasSpeechStarted = false
    private var noSpeechTimer: Timer?
    private var silenceTimer: Timer?
    private let rmsThreshold: Float = 0.015   // tune if too sensitive

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

    /// Start recording immediately. `noSpeechTimeout` and `silenceTimeout` fire their respective callbacks.
    func startListening(noSpeechTimeout: TimeInterval = 3, silenceTimeout: TimeInterval = 1.5) {
        reset()

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
                self.audioLevel = min(rms / 0.1, 1.0)   // normalize: 0.1 RMS ≈ full bar
                self.handleAudioLevel(rms: rms, silenceTimeout: silenceTimeout)
            }
        }

        do {
            try audioEngine.start()
        } catch {
            onError?(error)
            return
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
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
        }

        noSpeechTimer = Timer.scheduledTimer(withTimeInterval: noSpeechTimeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard !self.hasSpeechStarted else { return }
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

    // MARK: - Private helpers

    private func handleAudioLevel(rms: Float, silenceTimeout: TimeInterval) {
        guard rms > rmsThreshold else {
            // Silence — if we already had speech, reset silence timer
            if hasSpeechStarted {
                silenceTimer?.invalidate()
                silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
                    Task { @MainActor in self?.onSilenceDetected?() }
                }
            }
            return
        }
        // Audio above threshold
        silenceTimer?.invalidate()
        if !hasSpeechStarted {
            hasSpeechStarted = true
            noSpeechTimer?.invalidate()
            onFirstSpeechDetected?()
        }
    }

    /// Compute RMS amplitude of a PCM audio buffer.
    static func rms(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelDataValue[$0] }
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataValueArray.count))
        return rms.isNaN ? 0 : rms
    }
}
```

- [ ] **Step 2: Build in Xcode (Cmd+B)**

Expected: no errors. If `AVAudioApplication.requestRecordPermission` is unavailable (pre-iOS 17 target), replace with `AVAudioSession.sharedInstance().requestRecordPermission`.

- [ ] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Services/ASRService.swift
git commit -m "feat: add ASRService — SFSpeechRecognizer + AVAudioEngine + silence detection"
```

---

### Task 3: VoiceInputView.swift — the bottom sheet

**Files:**
- Create: `ios/TheBetterWe/TheBetterWe/Views/Voice/VoiceInputView.swift`

This file contains all sub-views (WaveBarsView, CountdownRingView, IntentCardView, ErrorCardView) as private structs so no new files are needed for components that have no reuse outside this sheet.

- [ ] **Step 1: Create VoiceInputView.swift**

```swift
import SwiftUI
import AVFoundation

// MARK: - State machine

enum VoiceInputState {
    case listening        // State 1: auto-listening, orange countdown ring, 3s no-speech timer
    case talking          // State 2: audio above threshold, wave bars jump
    case stoppedMatch     // State 3: silence elapsed, show stub intent card
    case stoppedNoMatch   // State 4: silence elapsed, show error card (for now always this)
}

// MARK: - VoiceInputView

struct VoiceInputView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var asr = ASRService()
    @State private var state: VoiceInputState = .listening
    @State private var permissionDenied = false

    // Countdown ring animation
    @State private var countdownProgress: CGFloat = 1.0   // 1.0 = full ring, 0 = ring gone
    @State private var countdownTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            headerRow
                .padding(.horizontal, 20)
                .padding(.top, 12)
            transcriptArea
                .padding(.horizontal, 20)
                .padding(.top, 16)
            Spacer()
            waveBarsRow
                .padding(.bottom, 12)
            micRow
                .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear { beginListening() }
        .onDisappear { asr.stopRecording() }
        .alert("麦克风权限被拒绝", isPresented: $permissionDenied) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text("请在设置中允许麦克风和语音识别权限。")
        }
    }

    // MARK: - Subviews

    private var dragHandle: some View {
        Capsule()
            .fill(Color(.systemGray4))
            .frame(width: VoiceInputStyle.handleWidth, height: VoiceInputStyle.handleHeight)
            .padding(.top, 8)
    }

    private var headerRow: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray5), in: Circle())
            }
            Spacer()
            statusIndicator
            Spacer()
            // Done button — visible but no-op this phase
            Button {} label: {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(doneButtonColor)
            }
            .disabled(true)
        }
    }

    private var doneButtonColor: Color {
        switch state {
        case .listening, .stoppedNoMatch: return .secondary
        case .talking, .stoppedMatch: return VoiceInputStyle.appBlue
        }
    }

    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusDotColor)
                .frame(width: VoiceInputStyle.statusDotSize, height: VoiceInputStyle.statusDotSize)
            Text(statusLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var statusDotColor: Color {
        switch state {
        case .listening:      return VoiceInputStyle.timerOrange
        case .talking:        return VoiceInputStyle.appBlue
        case .stoppedMatch, .stoppedNoMatch: return .secondary
        }
    }

    private var statusLabel: LocalizedStringKey {
        switch state {
        case .listening:      return "超时"
        case .talking:        return "聆听中"
        case .stoppedMatch, .stoppedNoMatch: return "已停止"
        }
    }

    private var transcriptArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            let confirmed = asr.confirmedTranscript
            let interim = asr.interimTranscript

            if confirmed.isEmpty && interim.isEmpty {
                Text("请开始说话…")
                    .font(.system(size: VoiceInputStyle.transcriptFontSize))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                (Text(confirmed)
                    .foregroundColor(VoiceInputStyle.confirmedColor) +
                 Text(interim.isEmpty ? "" : (confirmed.isEmpty ? "" : " ") + interim)
                    .foregroundColor(VoiceInputStyle.interimGray))
                    .font(.system(size: VoiceInputStyle.transcriptFontSize))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Intent / error card
            if state == .stoppedMatch {
                IntentCardView()
                    .padding(.top, 8)
            } else if state == .stoppedNoMatch {
                ErrorCardView()
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var waveBarsRow: some View {
        WaveBarsView(
            audioLevel: asr.audioLevel,
            isActive: state == .talking
        )
    }

    private var micRow: some View {
        ZStack {
            // Orange countdown ring (State 1 only)
            if state == .listening {
                CountdownRingView(progress: countdownProgress)
            }
            // Mic button
            Button { handleMicTap() } label: {
                Circle()
                    .fill(VoiceInputStyle.appBlue)
                    .frame(width: VoiceInputStyle.micButtonSize, height: VoiceInputStyle.micButtonSize)
                    .shadow(color: VoiceInputStyle.appBlue.opacity(0.4), radius: 8, x: 0, y: 4)
                    .overlay {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Logic

    private func beginListening() {
        Task {
            let granted = await asr.requestPermissions()
            guard granted else {
                permissionDenied = true
                return
            }
            startSession()
        }
    }

    private func startSession() {
        state = .listening
        countdownProgress = 1.0
        startCountdownAnimation(duration: 3)

        asr.onFirstSpeechDetected = {
            withAnimation { self.state = .talking }
            self.stopCountdown()
        }

        asr.onSilenceDetected = {
            // Phase 1: always show stoppedNoMatch (no NLP yet)
            let hasText = !self.asr.confirmedTranscript.isEmpty || !self.asr.interimTranscript.isEmpty
            withAnimation { self.state = hasText ? .stoppedNoMatch : .stoppedNoMatch }
        }

        asr.onNoSpeechTimeout = {
            self.dismiss()
        }

        asr.startListening(noSpeechTimeout: 3, silenceTimeout: 1.5)
    }

    private func handleMicTap() {
        guard state == .stoppedMatch || state == .stoppedNoMatch else { return }
        asr.reset()
        startSession()
    }

    // MARK: - Countdown ring helpers

    private func startCountdownAnimation(duration: TimeInterval) {
        countdownProgress = 1.0
        let steps = 60
        let interval = duration / Double(steps)
        var tick = 0
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            tick += 1
            let remaining = max(0, CGFloat(steps - tick) / CGFloat(steps))
            withAnimation(.linear(duration: interval)) {
                self.countdownProgress = remaining
            }
            if tick >= steps { timer.invalidate() }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}

// MARK: - WaveBarsView

private struct WaveBarsView: View {
    let audioLevel: Float
    let isActive: Bool

    @State private var phases: [Double] = [0, 0.2, 0.4, 0.2, 0]

    var body: some View {
        HStack(spacing: VoiceInputStyle.waveBarSpacing) {
            ForEach(0..<VoiceInputStyle.waveBarsCount, id: \.self) { i in
                Capsule()
                    .fill(barColor)
                    .frame(width: VoiceInputStyle.waveBarWidth,
                           height: barHeight(index: i))
                    .animation(.easeInOut(duration: isActive ? 0.15 : 2.0), value: audioLevel)
            }
        }
        .frame(height: VoiceInputStyle.waveBarMaxHeight)
    }

    private var barColor: Color {
        isActive ? VoiceInputStyle.appBlue : VoiceInputStyle.appBlueLight
    }

    private func barHeight(index: Int) -> CGFloat {
        let base = VoiceInputStyle.waveBarMinHeight
        let range = VoiceInputStyle.waveBarMaxHeight - base
        if !isActive {
            // Gentle breathe: staggered offsets, low amplitude
            let offset = [0.0, 0.3, 0.6, 0.3, 0.0][index]
            let breathe = (sin(phases[index] + offset) + 1) / 2 * 0.4
            return base + range * CGFloat(breathe)
        }
        // Active: level-driven with per-bar stagger
        let stagger: [Float] = [0.6, 0.8, 1.0, 0.8, 0.6]
        let h = base + range * CGFloat(audioLevel * stagger[index])
        return max(base, h)
    }
}

// MARK: - CountdownRingView

private struct CountdownRingView: View {
    let progress: CGFloat   // 1.0 = full, 0.0 = empty

    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(VoiceInputStyle.timerOrange, style: StrokeStyle(lineWidth: VoiceInputStyle.countdownRingLineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: VoiceInputStyle.countdownRingSize, height: VoiceInputStyle.countdownRingSize)
            .animation(.linear, value: progress)
    }
}

// MARK: - IntentCardView (stub)

private struct IntentCardView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(VoiceInputStyle.intentCardBorder)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text("✓ 积分记录")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VoiceInputStyle.appBlue)
                Text("— —")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(VoiceInputStyle.intentCardBackground, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - ErrorCardView (stub)

private struct ErrorCardView: View {
    private let examples: [(tag: String, example: LocalizedStringKey)] = [
        ("加分", "给小明加10分"),
        ("扣分", "小红扣了5分"),
        ("兑换", "小明兑换了20分")
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(VoiceInputStyle.errorCardBorder)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                Text("⚠ 未知命令")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VoiceInputStyle.errorCardBorder)
                Text("试试以下命令")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                ForEach(examples, id: \.tag) { item in
                    HStack(spacing: 6) {
                        Text(item.tag)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5), in: Capsule())
                        Text(item.example)
                            .font(.system(size: 12).italic())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(12)
        .background(VoiceInputStyle.errorCardBackground, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    VoiceInputView()
        .presentationDetents([.fraction(0.72)])
}
```

- [ ] **Step 2: Build in Xcode (Cmd+B)**

Expected: no errors. Warnings about `SFSpeechRecognizer` or `AVAudioEngine` not being Sendable are acceptable.

- [ ] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Views/Voice/VoiceInputView.swift
git commit -m "feat: add VoiceInputView — 5-state ASR bottom sheet"
```

---

### Task 4: Wire VoiceInputView into MainTabView

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Views/Main/MainTabView.swift:54-57`

The current sheet is:
```swift
.sheet(isPresented: $showCreate) {
    Text("Create")
        .presentationDetents([.medium])
}
```

- [ ] **Step 1: Replace the placeholder sheet**

Replace lines 54–57 with:

```swift
.sheet(isPresented: $showCreate) {
    VoiceInputView()
        .presentationDetents([.fraction(VoiceInputStyle.sheetHeightFraction)])
        .presentationDragIndicator(.hidden)   // we draw our own handle
}
```

Also add `import SwiftUI` is already there — no extra import needed since both files are in the same module.

- [ ] **Step 2: Build and run on Simulator (Cmd+R)**

Test checklist:
1. Tap the `+` button → voice sheet slides up
2. Sheet occupies ~72% of screen height
3. Status shows orange dot + "超时"
4. Wait 3 seconds without speaking → sheet auto-dismisses ✓
5. Tap + again, speak → status changes to blue + "聆听中", wave bars animate ✓
6. Stop speaking for 1.5 seconds → wave bars flatten, status shows gray + "已停止", error card appears ✓
7. Tap mic button → clears transcript, restarts from State 1 ✓
8. Tap ✕ → sheet dismisses with no action ✓
9. Done button is visible but tapping does nothing ✓

- [ ] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Views/Main/MainTabView.swift
git commit -m "feat: wire VoiceInputView to + tab bar button"
```

---

### Task 5: Localization strings

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Resources/Localizable.xcstrings`

All user-visible strings in VoiceInputView use `LocalizedStringKey`. Add the required keys to `Localizable.xcstrings`.

- [ ] **Step 1: Open Localizable.xcstrings in Xcode (or edit JSON)**

Add the following entries inside the `"strings"` object. Each entry follows the existing pattern (see `"Activities"` as reference):

```json
"超时": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Timeout" } },
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "超时" } }
  }
},
"聆听中": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Listening" } },
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "聆听中" } }
  }
},
"已停止": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Stopped" } },
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "已停止" } }
  }
},
"请开始说话…": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Start speaking…" } },
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "请开始说话…" } }
  }
},
"✓ 积分记录": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "✓ Points Recorded" } },
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "✓ 积分记录" } }
  }
},
"⚠ 未知命令": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "⚠ Unknown Command" } },
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "⚠ 未知命令" } }
  }
},
"试试以下命令": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Try these commands" } },
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "试试以下命令" } }
  }
},
"给小明加10分": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Add 10 points to Xiao Ming" } },
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "给小明加10分" } }
  }
},
"小红扣了5分": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Deduct 5 from Xiao Hong" } },
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "小红扣了5分" } }
  }
},
"小明兑换了20分": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Xiao Ming redeemed 20 points" } },
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "小明兑换了20分" } }
  }
},
"麦克风权限被拒绝": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Microphone Permission Denied" } },
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "麦克风权限被拒绝" } }
  }
},
"请在设置中允许麦克风和语音识别权限。": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Please allow microphone and speech recognition in Settings." } },
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "请在设置中允许麦克风和语音识别权限。" } }
  }
}
```

- [ ] **Step 2: Build in Xcode (Cmd+B)**

Expected: no errors or warnings about missing string keys.

- [ ] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Resources/Localizable.xcstrings
git commit -m "feat: add zh-Hans + en strings for voice input sheet"
```

---

### Task 6: Info.plist permission keys

> **User action required:** Xcode must be used to add these keys — editing `Info.plist` directly is possible but the project uses a generated plist. The safest path is Xcode's target editor.

- [ ] **Step 1: Add microphone permission key**

In Xcode → select `TheBetterWe` target → Info tab → add:
- Key: `Privacy - Microphone Usage Description`
- Value: `语音输入需要麦克风权限 / Microphone is used for voice input`

- [ ] **Step 2: Add speech recognition permission key**

- Key: `Privacy - Speech Recognition Usage Description`
- Value: `语音识别用于将语音转为积分记录 / Speech recognition is used to convert voice to points records`

- [ ] **Step 3: Verify on device or Simulator**

Run the app (Cmd+R), tap +. The system permission dialog should appear the first time asking for microphone + speech access.

- [ ] **Step 4: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/
git commit -m "feat: add microphone + speech recognition Info.plist keys"
```

---

## Self-Review

### Spec coverage check

| Spec requirement | Task |
|-----------------|------|
| + button opens voice sheet | Task 4 |
| Sheet height ~72% | Task 4 |
| Sheet handle (drag pill) | Task 3 — `dragHandle` |
| Header: ✕ · status · Done | Task 3 — `headerRow` |
| Transcript area, placeholder, confirmed dark, interim gray | Task 3 — `transcriptArea` |
| Wave bars, 5 bars, staggered | Task 3 — `WaveBarsView` |
| Mic button 60pt, #3A7BD5, shadow | Task 3 — `micRow` |
| State 1: orange dot, "超时", countdown ring, 3s auto-dismiss | Task 3 + ASRService `onNoSpeechTimeout` |
| State 2: blue dot, "聆听中", fast wave bars | Task 3 — `statusDotColor`, `waveBarsRow` |
| State 3: gray dot, "已停止", intent card stub | Task 3 — `IntentCardView` |
| State 4: gray dot, "已停止", error card stub | Task 3 — `ErrorCardView` |
| State 5: tap mic → restart | Task 3 — `handleMicTap()` |
| Done button visible, does nothing | Task 3 — `disabled(true)` + no action |
| 3s no-speech → dismiss | Task 2 `ASRService.onNoSpeechTimeout` + Task 3 |
| 1.5s silence after speech → stop | Task 2 `ASRService.onSilenceDetected` |
| SFSpeechRecognizer, Volcengine swap-ready | Task 2 — single-file swap |
| Permission denied alert | Task 3 — `.alert(permissionDenied:)` |
| zh-Hans + en strings | Task 5 |
| Info.plist keys | Task 6 |
| No feature toggle (ships enabled) | No toggle added ✓ |

### Placeholder check

No TBD / TODO / "similar to" / "handle appropriately" phrases present. All code is complete.

### Type consistency check

- `VoiceInputState` defined in Task 3, used in Task 3 only ✓
- `ASRService` defined in Task 2, instantiated as `@StateObject` in Task 3 ✓
- `VoiceInputStyle` defined in Task 1, referenced in Task 3 ✓
- `asr.confirmedTranscript`, `asr.interimTranscript`, `asr.audioLevel` — all `@Published` properties defined in Task 2 ✓
- `asr.onFirstSpeechDetected`, `asr.onSilenceDetected`, `asr.onNoSpeechTimeout` — callbacks defined in Task 2 ✓
- `asr.startListening(noSpeechTimeout:silenceTimeout:)` defined Task 2, called Task 3 ✓
- `asr.stopRecording()`, `asr.reset()` defined Task 2, called Task 3 ✓
- `countdownProgress: CGFloat` — consistent across `CountdownRingView` and `VoiceInputView` ✓
