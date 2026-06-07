#if DEBUG
import SwiftUI
import AVFoundation

// In-app integration test for Volcengine ASR connection.
// Access: long-press the "Done" button in VoiceInputView.
// Logs in as test/admin123, injects synthetic PCM audio (simulates 喂喂喂),
// and displays the full event timeline on screen + Xcode console.

struct ASRDiagnosticView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [LogEntry] = []
    @State private var isRunning = false
    @State private var backend: VolcengineBackend?

    struct LogEntry: Identifiable {
        let id = UUID()
        let elapsed: Double
        let icon: String
        let message: String
        var text: String { String(format: "%@  +%.2fs  %@", icon, elapsed, message) }
    }

    var body: some View {
        NavigationStack {
            List(entries) { entry in
                Text(entry.text)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(entry.icon == "❌" ? .red : entry.icon == "✅" ? .green : .primary)
            }
            .listStyle(.plain)
            .overlay {
                if entries.isEmpty && !isRunning {
                    ContentUnavailableView("Tap Run", systemImage: "waveform.badge.mic")
                }
                if isRunning {
                    VStack {
                        Spacer()
                        ProgressView("Running…")
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("ASR Diagnostic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Run") {
                        Task { await runTest() }
                    }
                    .disabled(isRunning)
                }
            }
        }
    }

    // MARK: - Test runner

    @MainActor
    private func runTest() async {
        entries.removeAll()
        isRunning = true
        let start = Date()

        func log(_ icon: String, _ message: String) {
            let elapsed = Date().timeIntervalSince(start)
            let entry = LogEntry(elapsed: elapsed, icon: icon, message: message)
            entries.append(entry)
            print(String(format: "[ASRDiag] %@ +%.2fs  %@", icon, elapsed, message))
        }

        // 1. Log in as test/admin123
        log("🔑", "Logging in as test/admin123…")
        do {
            try await AuthService.logIn(username: "test", password: "admin123")
            let prefix = String(AuthService.accessToken?.prefix(8) ?? "nil")
            log("✅", "Auth OK — token \(prefix)…")
        } catch {
            log("❌", "Auth failed: \(error.localizedDescription)")
            isRunning = false
            return
        }

        // 2. Create backend and wire callbacks
        let b = VolcengineBackend()
        backend = b

        b.onConnected = {
            let elapsed = Date().timeIntervalSince(start)
            let entry = LogEntry(elapsed: elapsed, icon: "✅", message: "onConnected fired — engineLabel should be 火山")
            entries.append(entry)
            print(String(format: "[ASRDiag] ✅ +%.2fs  onConnected", elapsed))
        }

        b.onPartialTranscript = { text in
            let elapsed = Date().timeIntervalSince(start)
            let entry = LogEntry(elapsed: elapsed, icon: "💬", message: "partial: \(text)")
            entries.append(entry)
        }

        b.onFinalTranscript = { text in
            let elapsed = Date().timeIntervalSince(start)
            let entry = LogEntry(elapsed: elapsed, icon: "📝", message: "final: \(text)")
            entries.append(entry)
        }

        b.onError = { error in
            let elapsed = Date().timeIntervalSince(start)
            let entry = LogEntry(elapsed: elapsed, icon: "❌", message: "onError: \(error.localizedDescription)")
            entries.append(entry)
            print(String(format: "[ASRDiag] ❌ +%.2fs  onError: %@", elapsed, error.localizedDescription))
        }

        // 3. Start backend with a plausible AVAudioFormat (matches what AVAudioEngine provides on device)
        let sampleRate = 48_000.0
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: sampleRate,
                                         channels: 1,
                                         interleaved: false) else {
            log("❌", "Could not create AVAudioFormat")
            isRunning = false
            return
        }

        do {
            log("📡", "Starting VolcengineBackend…")
            try b.start(audioFormat: format)
            log("▶️", "Backend start() returned (WS task resumed)")
        } catch {
            log("❌", "start() threw: \(error.localizedDescription)")
            isRunning = false
            return
        }

        // 4. Inject synthetic audio every 100ms for 4 seconds (simulates 喂喂喂)
        // Sine wave at 440 Hz, amplitude 0.3 — above rmsThreshold, realistic speech volume
        let chunkFrames = AVAudioFrameCount(sampleRate * 0.1)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames),
              let channelData = buffer.floatChannelData?.pointee else {
            log("❌", "Could not create PCM buffer")
            isRunning = false
            return
        }
        buffer.frameLength = chunkFrames
        for i in 0..<Int(chunkFrames) {
            channelData[i] = 0.3 * sin(2 * .pi * 440 * Float(i) / Float(sampleRate))
        }

        log("🎤", "Injecting 4s of synthetic audio (440Hz, amp=0.3)…")
        for chunk in 0..<40 {
            b.appendBuffer(buffer)
            try? await Task.sleep(nanoseconds: 100_000_000)
            if chunk == 9  { log("⏱", "1s of audio sent") }
            if chunk == 19 { log("⏱", "2s of audio sent") }
            if chunk == 29 { log("⏱", "3s of audio sent") }
        }

        // 5. Stop
        log("⏹", "Stopping backend")
        b.stop()
        backend = nil

        // 6. Wait a moment for any trailing callbacks
        try? await Task.sleep(nanoseconds: 500_000_000)
        log("🏁", "Done — check for ✅ connected and any ❌ errors above")
        isRunning = false
    }
}

#Preview {
    ASRDiagnosticView()
}
#endif
