import SwiftUI
import AVFoundation

// MARK: - State machine

enum VoiceInputState {
    case listening        // State 1: auto-listening, orange countdown ring, 3s no-speech timer
    case talking          // State 2: audio above threshold, wave bars jump fast
    case stoppedMatch     // State 3: silence elapsed, stub intent card (future NLP)
    case stoppedNoMatch   // State 4: silence elapsed, error card
}

// MARK: - VoiceInputView

struct VoiceInputView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var asr = ASRService()
    @State private var voiceState: VoiceInputState = .listening
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
            WaveBarsView(audioLevel: asr.audioLevel, isActive: voiceState == .talking,
                         isStopped: voiceState == .stoppedMatch || voiceState == .stoppedNoMatch)
                .padding(.bottom, 12)
            micRow
                .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear { beginListening() }
        .onDisappear { asr.stopRecording(); stopNudge() }
        .onChange(of: voiceState) { _, newState in
            let isStopped = newState == .stoppedMatch || newState == .stoppedNoMatch
            isStopped ? startNudge() : stopNudge()
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
            // Done button — visible but no-op in Phase 1 (NLP not yet implemented)
            Button {} label: {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(doneButtonColor)
            }
            .disabled(true)
        }
    }

    private var doneButtonColor: Color {
        switch voiceState {
        case .listening, .stoppedNoMatch: return .secondary
        case .talking, .stoppedMatch:     return VoiceInputStyle.appBlue
        }
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
        case .listening:                  return VoiceInputStyle.timerOrange
        case .talking:                    return VoiceInputStyle.appBlue
        case .stoppedMatch, .stoppedNoMatch: return .secondary
        }
    }

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
                (Text(confirmed).foregroundColor(VoiceInputStyle.confirmedColor) +
                 Text(interim.isEmpty ? "" : (confirmed.isEmpty ? "" : " ") + interim)
                    .foregroundColor(VoiceInputStyle.interimGray))
                    .font(.system(size: VoiceInputStyle.transcriptFontSize))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if voiceState == .stoppedMatch {
                IntentCardView().padding(.top, 8)
            } else if voiceState == .stoppedNoMatch {
                ErrorCardView().padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        voiceState = .listening
        countdownProgress = 1.0
        startCountdownAnimation(duration: 3)

        asr.onFirstSpeechDetected = {
            withAnimation { self.voiceState = .talking }
            self.stopCountdown()
        }

        asr.onSilenceDetected = {
            self.asr.stopRecording()
            // Phase 1: NLP not implemented — always show error card
            withAnimation { self.voiceState = .stoppedNoMatch }
        }

        asr.onNoSpeechTimeout = {
            self.dismiss()
        }

        asr.startListening(noSpeechTimeout: 3, silenceTimeout: 1.5)
    }

    private func handleMicTap() {
        guard voiceState == .stoppedMatch || voiceState == .stoppedNoMatch else { return }
        asr.reset()
        startSession()
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

// MARK: - IntentCardView (stub — wired up when NLP is implemented in Phase 4)

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
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .background(VoiceInputStyle.intentCardBackground, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - ErrorCardView

private struct ErrorCardView: View {
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
            }
            Spacer()
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .background(VoiceInputStyle.errorCardBackground, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    VoiceInputView()
        .presentationDetents([.fraction(VoiceInputStyle.sheetHeightFraction)])
}
