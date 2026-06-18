import SwiftUI

enum VoiceInputStyle {
    // Sheet — per-state heights (replaces static sheetHeight)
    static let heightConnecting:  CGFloat = 260
    static let heightIdle:        CGFloat = 340
    static let heightRecording:   CGFloat = 340
    static let heightProcessing:  CGFloat = 300
    static let heightResult:      CGFloat = 400
    static let heightError:       CGFloat = 380

    // Handle
    static let handleWidth:  CGFloat = 36
    static let handleHeight: CGFloat = 4

    // No-speech countdown (was 3)
    static let noSpeechTimeout: TimeInterval = 5

    // Colors
    static let appBlue      = Color(red: 58/255,  green: 123/255, blue: 213/255)
    static let appBlueLight = Color(red: 144/255, green: 186/255, blue: 240/255)
    static let timerOrange  = Color(red: 1.0, green: 149/255, blue: 0)
    static let interimGray  = Color(hex: "AEAEB2")
    static let confirmedColor = Color.primary

    // Intent card
    static let intentCardBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 30/255,  green: 50/255, blue: 80/255,  alpha: 1)
            : UIColor(red: 240/255, green: 245/255, blue: 1.0,    alpha: 1)
    })
    static let intentCardBorder = appBlue

    // Error card
    static let errorCardBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 70/255, green: 20/255, blue: 20/255, alpha: 1)
            : UIColor(red: 1.0,   green: 245/255, blue: 245/255, alpha: 1)
    })
    static let errorCardBorder = Color(red: 1.0, green: 59/255, blue: 48/255)

    // Transcript card (neutral elevated surface)
    static let transcriptCardBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 50/255, green: 40/255, blue: 38/255, alpha: 1)
            : UIColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1)
    })

    // Mic button (gradient, 68pt — was 60pt solid blue)
    static let micButtonSize: CGFloat = 68

    // Wave bars
    static let waveBarsCount:    Int     = 5
    static let waveBarWidth:     CGFloat = 4
    static let waveBarMinHeight: CGFloat = 6
    static let waveBarMaxHeight: CGFloat = 32
    static let waveBarSpacing:   CGFloat = 5

    // Countdown ring (sized for 68pt mic — was 76pt)
    static let countdownRingSize:      CGFloat = 86
    static let countdownRingLineWidth: CGFloat = 3

    // Typography
    static let transcriptFontSize: CGFloat = 15
    static let statusDotSize:      CGFloat = 8
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
