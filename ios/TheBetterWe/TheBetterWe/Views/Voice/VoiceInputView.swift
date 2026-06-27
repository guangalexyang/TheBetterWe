import SwiftUI
import AVFoundation

// MARK: - State machine

enum VoiceInputState {
    case bootstrapping
    case listening
    case talking
    case parsing
    case parsed
    case parseFailed
}

// MARK: - VoiceInputView

struct VoiceInputView: View {
    let familyId: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @StateObject private var asr = ASRService()
    @State private var voiceState: VoiceInputState = .bootstrapping
    @State private var parsedResult: VoiceTranscriptResult? = nil
    @State private var permissionDenied = false
    @State private var countdownProgress: CGFloat = 1.0
    @State private var countdownTimer: Timer?

    // MARK: - Dynamic sheet height

    private var detentHeight: CGFloat {
        switch voiceState {
        case .bootstrapping: return VoiceInputStyle.heightConnecting
        case .listening:     return VoiceInputStyle.heightIdle
        case .talking:       return VoiceInputStyle.heightRecording
        case .parsing:       return VoiceInputStyle.heightProcessing
        case .parsed:        return VoiceInputStyle.heightResult
        case .parseFailed:   return VoiceInputStyle.heightError
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            headerRow
            phaseBody
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.cardSurface)
        .presentationDetents([.height(detentHeight)])
        .onAppear { beginListening() }
        .onDisappear { asr.stopRecording() }
        .onChange(of: asr.engineLabel) { _, newLabel in
            guard !newLabel.isEmpty, voiceState == .bootstrapping else { return }
            withAnimation(.easeInOut(duration: 0.25)) { voiceState = .listening }
            countdownProgress = 1.0
            startCountdownAnimation(duration: VoiceInputStyle.noSpeechTimeout)
            asr.onNoSpeechTimeout = { self.dismiss() }
            asr.arm(noSpeechTimeout: VoiceInputStyle.noSpeechTimeout)
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

    // MARK: - Shared chrome

    private var dragHandle: some View {
        Capsule()
            .fill(Color(.systemGray4))
            .frame(width: VoiceInputStyle.handleWidth, height: VoiceInputStyle.handleHeight)
            .padding(.top, 8)
    }

    private var headerRow: some View {
        HStack {
            Text("语音指令")
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.systemGray5), in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Phase body

    @ViewBuilder
    private var phaseBody: some View {
        switch voiceState {
        case .bootstrapping: connectingPhase
        case .listening:     idlePhase
        case .talking:       recordingPhase
        case .parsing:       processingPhase
        case .parsed:        resultPhase
        case .parseFailed:   errorPhase
        }
    }

    // MARK: - Connecting phase

    private var connectingPhase: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
                .tint(VoiceInputStyle.appBlue)
            Text("连接中")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Idle phase

    private var idlePhase: some View {
        VStack(spacing: 14) {
            Spacer()
            VStack(spacing: 6) {
                Text("说出指令，例如：")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text(verbatim: "\u{201C}给小明加十分，因为他帮忙洗碗\u{201D}")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(verbatim: "\u{201C}提醒我明天去银行\u{201D}")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            ZStack {
                CountdownRingView(progress: countdownProgress)
                gradientMicButton
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    // MARK: - Recording phase

    private var recordingPhase: some View {
        VStack(spacing: 0) {
            transcriptArea
                .padding(.horizontal, 20)
                .padding(.top, 8)
            Spacer()
            VStack(spacing: 12) {
                statusRow
                WaveBarsView(audioLevel: asr.audioLevel, isActive: true, isStopped: false)
                ZStack {
                    PulseRingsView()
                    gradientMicButton
                }
            }
            .padding(.bottom, 28)
        }
    }

    // MARK: - Processing phase

    private var processingPhase: some View {
        VStack(spacing: 0) {
            transcriptArea
                .padding(.horizontal, 20)
                .padding(.top, 8)
            Spacer()
            VStack(spacing: 10) {
                WaveBarsView(audioLevel: 0, isActive: false, isStopped: true)
                ProgressView()
                    .tint(VoiceInputStyle.appBlue)
                Text("豆包正在分析")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 28)
        }
    }

    // MARK: - Result phase

    private var resultPhase: some View {
        VStack(spacing: 12) {
            transcriptCard
            llmDoneLabel
            if let result = parsedResult {
                if result.isTodoIntent {
                    TodoIntentCardView(result: result)
                } else {
                    IntentCardView(result: result)
                }
            }
            HStack(spacing: 12) {
                retryButton
                confirmButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    // MARK: - Error phase

    private var errorPhase: some View {
        VStack(spacing: 12) {
            transcriptCard
            llmDoneLabel
            ErrorCardView()
            retryButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    // MARK: - Shared components

    private var gradientMicButton: some View {
        Circle()
            .fill(LinearGradient(
                colors: [
                    Color(red: 240/255, green: 112/255, blue: 74/255),
                    Color(red: 232/255, green: 93/255,  blue: 122/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: VoiceInputStyle.micButtonSize, height: VoiceInputStyle.micButtonSize)
            .shadow(
                color: Color(red: 240/255, green: 112/255, blue: 74/255).opacity(0.45),
                radius: 10, y: 4
            )
            .overlay {
                Image(systemName: "mic.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
            }
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(VoiceInputStyle.appBlue)
                .frame(width: VoiceInputStyle.statusDotSize, height: VoiceInputStyle.statusDotSize)
            if asr.engineLabel.isEmpty {
                Text("聆听中")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                (Text("聆听中") + Text(verbatim: "[") +
                 Text(LocalizedStringKey(asr.engineLabel)) + Text(verbatim: "]"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var transcriptArea: some View {
        let confirmed = asr.confirmedTranscript
        let interim   = asr.interimTranscript
        let interimColor: Color = voiceState == .parsing
            ? VoiceInputStyle.confirmedColor
            : VoiceInputStyle.interimGray
        return Group {
            if confirmed.isEmpty && interim.isEmpty {
                Text("请开始说话…")
                    .font(.system(size: VoiceInputStyle.transcriptFontSize))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                (Text(confirmed).foregroundColor(VoiceInputStyle.confirmedColor) +
                 Text(interim.isEmpty ? "" : (confirmed.isEmpty ? "" : " ") + interim)
                    .foregroundColor(interimColor))
                    .font(.system(size: VoiceInputStyle.transcriptFontSize))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var transcriptCard: some View {
        let text = asr.confirmedTranscript.isEmpty
            ? asr.interimTranscript
            : asr.confirmedTranscript
        return VStack(alignment: .leading, spacing: 4) {
            Text("识别结果")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(VoiceInputStyle.transcriptCardBackground,
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.cardBorder, lineWidth: 1)
        )
    }

    private var llmDoneLabel: some View {
        (Text(verbatim: "[") +
         Text(LocalizedStringKey("豆包")) +
         Text(verbatim: "] ") +
         Text(LocalizedStringKey("分析完成")))
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var retryButton: some View {
        Button { handleRetry() } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .semibold))
                Text("重试")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(theme.cardSurface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(theme.cardBorder, lineWidth: 1)
            )
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var confirmButton: some View {
        Button { handleConfirm() } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                Text("确认执行")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 82/255,  green: 200/255, blue: 130/255),
                        Color(red: 42/255,  green: 171/255, blue: 94/255)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .shadow(
                color: Color(red: 42/255, green: 171/255, blue: 94/255).opacity(0.3),
                radius: 6, y: 3
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
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

        asr.startListening(silenceTimeout: 1.5)
    }

    private func handleRetry() {
        parsedResult = nil
        asr.reset()
        startSession()
    }

    private func parseTranscript() async {
        let transcript = asr.confirmedTranscript.isEmpty
            ? asr.interimTranscript
            : asr.confirmedTranscript
        guard !transcript.isEmpty else {
            await MainActor.run { withAnimation { voiceState = .parseFailed } }
            return
        }
        do {
            let result = try await PointSystemService.parseTranscript(
                familyId: familyId,
                transcript: transcript
            )
            await MainActor.run {
                parsedResult = result
                withAnimation { voiceState = result.isHighConfidence ? .parsed : .parseFailed }
            }
        } catch {
            await MainActor.run { withAnimation { voiceState = .parseFailed } }
        }
    }

    private func handleConfirm() {
        guard voiceState == .parsed, let result = parsedResult else { return }
        Task {
            if result.isTodoIntent {
                guard let title = result.todoTitle,
                      let todoType = result.todoType,
                      let priority = result.todoPriority else { return }
                do {
                    var dueAt: Int? = nil
                    if let dateStr = result.date {
                        let fmt = DateFormatter()
                        fmt.locale = Locale(identifier: "en_US_POSIX")
                        fmt.dateFormat = "yyyy-MM-dd"
                        fmt.timeZone = .current
                        if let d = fmt.date(from: dateStr) { dueAt = Int(d.timeIntervalSince1970) }
                    }
                    _ = try await FamilyTodoService.createTodo(
                        familyId: familyId,
                        body: CreateTodoBody(
                            todoType: todoType,
                            title: title,
                            description: result.note,
                            location: nil,
                            priority: priority,
                            dueAt: dueAt
                        )
                    )
                    NotificationCenter.default.post(name: .familyTodoDidChange, object: nil)
                } catch { }
            } else {
                guard let memberId = result.memberId, let delta = result.delta else { return }
                do {
                    _ = try await PointSystemService.addPointEvent(
                        familyId: familyId,
                        memberId: memberId,
                        delta: delta,
                        note: result.note,
                        date: result.date ?? localDateString(),
                        eventType: result.eventType ?? (delta > 0 ? "add" : "redeem")
                    )
                    NotificationCenter.default.post(name: .pointEventDidChange, object: nil)
                } catch { }
            }
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
}

// MARK: - PulseRingsView

private struct PulseRingsView: View {
    @State private var pulse1 = false
    @State private var pulse2 = false

    var body: some View {
        ZStack {
            ring(active: pulse1)
            ring(active: pulse2)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulse1 = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    pulse2 = true
                }
            }
        }
    }

    private func ring(active: Bool) -> some View {
        Circle()
            .fill(Color(red: 240/255, green: 112/255, blue: 74/255).opacity(0.18))
            .frame(width: VoiceInputStyle.micButtonSize, height: VoiceInputStyle.micButtonSize)
            .scaleEffect(active ? 1.47 : 1.0)
            .opacity(active ? 0 : 0.7)
    }
}

// MARK: - WaveBarsView

private struct WaveBarsView: View {
    let audioLevel: Float
    let isActive: Bool
    let isStopped: Bool

    private let phaseOffsets: [Double] = [0, 0.4, 0.8, 0.4, 0]

    var body: some View {
        if isStopped {
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
        let breathe = (sin(time * 1.2 + phaseOffsets[index]) + 1) / 2 * 0.35
        return base + range * CGFloat(breathe)
    }
}

// MARK: - CountdownRingView

private struct CountdownRingView: View {
    let progress: CGFloat

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

// MARK: - TodoIntentCardView

private struct TodoIntentCardView: View {
    let result: VoiceTranscriptResult

    private var priorityLabel: String {
        switch result.todoPriority {
        case "high": return "高"
        case "low":  return "低"
        default:     return "中"
        }
    }

    private var priorityColor: Color {
        switch result.todoPriority {
        case "high": return .red
        case "low":  return .secondary
        default:     return .blue
        }
    }

    private var typeLabel: String { result.todoType == "personal" ? "个人" : "家庭" }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(VoiceInputStyle.appBlue)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                Text("✓ 创建任务")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VoiceInputStyle.appBlue)
                Text(result.todoTitle ?? "")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                if let note = result.note {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Text(typeLabel)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(VoiceInputStyle.appBlue.opacity(0.12))
                        .foregroundStyle(VoiceInputStyle.appBlue)
                        .clipShape(Capsule())
                    Text(priorityLabel)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(priorityColor.opacity(0.12))
                        .foregroundStyle(priorityColor)
                        .clipShape(Capsule())
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
    private let examples: [(tag: String, example: String)] = [
        ("加分", "给小明加10分"),
        ("扣分", "小红扣了5分"),
        ("兑换", "小明兑换了20分"),
        ("任务", "提醒我去银行")
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
    VoiceInputView(familyId: 1)
        .environment(ThemeManager())
}
