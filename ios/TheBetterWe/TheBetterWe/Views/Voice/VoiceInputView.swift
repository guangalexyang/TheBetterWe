import SwiftUI
import AVFoundation

// MARK: - State machine

enum VoiceInputState {
    case bootstrapping    // connecting to ASR backend
    case listening        // waiting for speech, 3s countdown ring
    case talking          // audio above threshold
    case parsing          // silence detected, LLM call in flight
    case parsed           // LLM returned high confidence — show IntentCard
    case parseFailed      // LLM returned low confidence or failed — show ErrorCard
}

// MARK: - VoiceInputView

struct VoiceInputView: View {
    let familyId: Int

    @Environment(\.dismiss) private var dismiss
    @StateObject private var asr = ASRService()
    @State private var voiceState: VoiceInputState = .bootstrapping
    @State private var parsedResult: VoiceTranscriptResult? = nil
    @State private var parseDebugInfo: String = ""
    @State private var permissionDenied = false
    @State private var countdownProgress: CGFloat = 1.0
    @State private var countdownTimer: Timer?
    @State private var micRotation: Double = 0
    @State private var nudgeTimer: Timer?
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
            if voiceState == .bootstrapping {
                bootstrapSpinner
                    .padding(.bottom, 48)
                    .transition(.opacity)
            } else {
                WaveBarsView(audioLevel: asr.audioLevel, isActive: voiceState == .talking,
                             isStopped: voiceState == .parsing || voiceState == .parsed || voiceState == .parseFailed)
                    .padding(.bottom, 12)
                    .transition(.opacity)
                micRow
                    .padding(.bottom, 36)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear { beginListening() }
        .onDisappear { asr.stopRecording(); stopNudge() }
        .onChange(of: voiceState) { _, newState in
            let isStopped = newState == .parsed || newState == .parseFailed
            isStopped ? startNudge() : stopNudge()
        }
        .onChange(of: asr.engineLabel) { _, newLabel in
            guard !newLabel.isEmpty, voiceState == .bootstrapping else { return }
            withAnimation(.easeInOut(duration: 0.25)) { voiceState = .listening }
            countdownProgress = 1.0
            startCountdownAnimation(duration: 3)
            asr.onNoSpeechTimeout = { self.dismiss() }
            asr.arm(noSpeechTimeout: 3)
        }
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
            Button { handleConfirm() } label: {
                Text("Confirm")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(confirmButtonColor)
            }
            .disabled(voiceState != .parsed)
        }
    }

    private var confirmButtonColor: Color {
        voiceState == .parsed ? VoiceInputStyle.appBlue : .secondary
    }

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

    private var statusDotColor: Color {
        switch voiceState {
        case .bootstrapping:                          return .secondary
        case .listening:                              return VoiceInputStyle.timerOrange
        case .talking:                                return VoiceInputStyle.appBlue
        case .parsing, .parsed, .parseFailed:         return .secondary
        }
    }

    private var statusText: Text {
        switch voiceState {
        case .bootstrapping:
            return Text("连接中")
        case .listening:
            return Text("等待中")
        case .talking:
            return asr.engineLabel.isEmpty
                ? Text("聆听中")
                : Text("聆听中") + Text(verbatim: "[") + Text(LocalizedStringKey(asr.engineLabel)) + Text(verbatim: "]")
        case .parsing, .parsed, .parseFailed:
            return Text("已停止")
        }
    }

    private var transcriptArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            let confirmed = asr.confirmedTranscript
            let interim = asr.interimTranscript

            let isStopped = voiceState == .parsing || voiceState == .parsed || voiceState == .parseFailed
            if confirmed.isEmpty && interim.isEmpty && voiceState != .bootstrapping {
                Text("请开始说话…")
                    .font(.system(size: VoiceInputStyle.transcriptFontSize))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                (Text(confirmed).foregroundColor(VoiceInputStyle.confirmedColor) +
                 Text(interim.isEmpty ? "" : (confirmed.isEmpty ? "" : " ") + interim)
                    .foregroundColor(isStopped ? VoiceInputStyle.confirmedColor : VoiceInputStyle.interimGray))
                    .font(.system(size: VoiceInputStyle.transcriptFontSize))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if voiceState == .parsing || voiceState == .parsed || voiceState == .parseFailed {
                llmStatusLabel
                    .padding(.top, 4)
            }

            if voiceState == .parsed, let result = parsedResult {
                IntentCardView(result: result).padding(.top, 8)
            } else if voiceState == .parseFailed {
                ErrorCardView(debugInfo: parseDebugInfo).padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var llmStatusLabel: some View {
        (Text(verbatim: "[") + Text(LocalizedStringKey("豆包")) + Text(verbatim: "] ") +
         Text(voiceState == .parsing ? LocalizedStringKey("分析中…") : LocalizedStringKey("分析完成")))
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
    }

    private var bootstrapSpinner: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(VoiceInputStyle.appBlue)
            Text("连接中")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var micRow: some View {
        ZStack {
            if voiceState == .listening {
                CountdownRingView(progress: countdownProgress)
            }
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
            .rotationEffect(.degrees(micRotation))
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
        voiceState = .bootstrapping

        asr.onFirstSpeechDetected = {
            guard self.voiceState != .bootstrapping else { return }
            withAnimation { self.voiceState = .talking }
            self.stopCountdown()
        }

        asr.onSilenceDetected = {
            self.asr.stopRecording()
            withAnimation { self.voiceState = .parsing }
            Task { await self.parseTranscript() }
        }

        // onNoSpeechTimeout wired in onChange(of: asr.engineLabel) after bootstrap completes.

        asr.startListening(silenceTimeout: 1.5)
    }

    private func handleMicTap() {
        guard voiceState == .parsed || voiceState == .parseFailed else { return }
        parsedResult = nil
        asr.reset()
        startSession()
    }

    private func parseTranscript() async {
        let transcript = asr.confirmedTranscript.isEmpty
            ? asr.interimTranscript
            : asr.confirmedTranscript
        guard !transcript.isEmpty else {
            await MainActor.run {
                parseDebugInfo = "sent: (empty)"
                withAnimation { voiceState = .parseFailed }
            }
            return
        }
        do {
            let result = try await PointSystemService.parseTranscript(
                familyId: familyId,
                transcript: transcript
            )
            print("[voice] parse result: confidence=\(result.confidence) member=\(result.memberName ?? "nil") delta=\(result.delta.map(String.init) ?? "nil") debug=\(result._debug ?? "-")")
            await MainActor.run {
                parsedResult = result
                var info = "sent: \(transcript)\nconfidence: \(result.confidence)"
                if let d = result._debug { info += "\n\(d)" }
                parseDebugInfo = info
                withAnimation { voiceState = result.isHighConfidence ? .parsed : .parseFailed }
            }
        } catch {
            print("[voice] parseTranscript error: \(error)")
            await MainActor.run {
                parseDebugInfo = "sent: \(transcript)\nerror: \(error)"
                withAnimation { voiceState = .parseFailed }
            }
        }
    }

    private func handleConfirm() {
        guard voiceState == .parsed,
              let result = parsedResult,
              let memberId = result.memberId,
              let delta = result.delta else { return }
        Task {
            do {
                _ = try await PointSystemService.addPointEvent(
                    familyId: familyId,
                    memberId: memberId,
                    delta: delta,
                    note: result.note,
                    date: result.date ?? localDateString()
                )
            } catch { /* errors dismissed silently — user can retry */ }
            await MainActor.run { dismiss() }
        }
    }

    private func startCountdownAnimation(duration: TimeInterval) {
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

    private func startNudge() {
        nudgeTimer?.invalidate()
        triggerNudge()
        nudgeTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            self.triggerNudge()
        }
    }

    private func stopNudge() {
        nudgeTimer?.invalidate()
        nudgeTimer = nil
        withAnimation(.easeOut(duration: 0.15)) { micRotation = 0 }
    }

    private func triggerNudge() {
        withAnimation(.easeOut(duration: 0.06)) { micRotation = 15 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.25)) { self.micRotation = 0 }
        }
    }
}

// MARK: - WaveBarsView
// Uses TimelineView so idle breathe animates continuously without external timers.

private struct WaveBarsView: View {
    let audioLevel: Float
    let isActive: Bool
    let isStopped: Bool

    // Phase offsets for staggered idle breathe (fractions of 2π)
    private let phaseOffsets: [Double] = [0, 0.4, 0.8, 0.4, 0]

    var body: some View {
        if isStopped {
            // Flat static bars — no animation, no TimelineView
            HStack(spacing: VoiceInputStyle.waveBarSpacing) {
                ForEach(0..<VoiceInputStyle.waveBarsCount, id: \.self) { _ in
                    Capsule()
                        .fill(Color(.systemGray4))
                        .frame(width: VoiceInputStyle.waveBarWidth,
                               height: VoiceInputStyle.waveBarMinHeight)
                }
            }
            .frame(height: VoiceInputStyle.waveBarMaxHeight)
        } else {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                HStack(spacing: VoiceInputStyle.waveBarSpacing) {
                    ForEach(0..<VoiceInputStyle.waveBarsCount, id: \.self) { i in
                        Capsule()
                            .fill(barColor)
                            .frame(width: VoiceInputStyle.waveBarWidth,
                                   height: barHeight(index: i, time: t))
                    }
                }
            }
            .frame(height: VoiceInputStyle.waveBarMaxHeight)
            .animation(.easeInOut(duration: 0.12), value: audioLevel)
        }
    }

    private var barColor: Color {
        isActive ? VoiceInputStyle.appBlue : VoiceInputStyle.appBlueLight
    }

    private func barHeight(index: Int, time: Double) -> CGFloat {
        let base  = VoiceInputStyle.waveBarMinHeight
        let range = VoiceInputStyle.waveBarMaxHeight - base
        if isActive {
            let stagger: [Float] = [0.55, 0.75, 1.0, 0.75, 0.55]
            return max(base, base + range * CGFloat(audioLevel * stagger[index]))
        }
        // Idle: slow sine breathe, low amplitude, staggered
        let breathe = (sin(time * 1.2 + phaseOffsets[index]) + 1) / 2 * 0.35
        return base + range * CGFloat(breathe)
    }
}

// MARK: - CountdownRingView

private struct CountdownRingView: View {
    let progress: CGFloat   // 1.0 = full ring, 0.0 = empty

    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                VoiceInputStyle.timerOrange,
                style: StrokeStyle(lineWidth: VoiceInputStyle.countdownRingLineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .frame(width: VoiceInputStyle.countdownRingSize, height: VoiceInputStyle.countdownRingSize)
            .animation(.linear, value: progress)
    }
}

// MARK: - IntentCardView

private struct IntentCardView: View {
    let result: VoiceTranscriptResult

    private var deltaText: String {
        guard let d = result.delta else { return "" }
        return d > 0 ? "+\(d) 分" : "\(d) 分"
    }

    private var deltaColor: Color {
        guard let d = result.delta else { return .primary }
        return d > 0 ? VoiceInputStyle.appBlue : VoiceInputStyle.timerOrange
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(VoiceInputStyle.intentCardBorder)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                Text("✓ 积分记录")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VoiceInputStyle.appBlue)
                HStack(spacing: 8) {
                    if let name = result.memberName {
                        Text(name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    Text(deltaText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(deltaColor)
                }
                if let note = result.note {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .background(VoiceInputStyle.intentCardBackground, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - ErrorCardView

private struct ErrorCardView: View {
    var debugInfo: String = ""

    private let examples: [(tag: String, example: String)] = [
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
                // DEBUG: remove before ship
                if !debugInfo.isEmpty {
                    Text(debugInfo)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(.systemGray2))
                        .padding(.top, 4)
                }
            }
            Spacer()
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .background(VoiceInputStyle.errorCardBackground, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    VoiceInputView(familyId: 1)
        .presentationDetents([.fraction(VoiceInputStyle.sheetHeightFraction)])
}
