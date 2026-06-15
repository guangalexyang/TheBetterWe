import SwiftUI

enum VoiceInputStyle {
    // Sheet
    static let sheetHeight: CGFloat = 400
    static let handleWidth: CGFloat = 36
    static let handleHeight: CGFloat = 4

    // Colors
    static let appBlue = Color(red: 58/255, green: 123/255, blue: 213/255)
    static let appBlueLight = Color(red: 144/255, green: 186/255, blue: 240/255)
    static let timerOrange = Color(red: 1.0, green: 149/255, blue: 0)
    static let interimGray = Color(hex: "AEAEB2")
    // Adapts to dark mode — was hardcoded near-black, invisible in dark
    static let confirmedColor = Color.primary

    // Intent card — light blue in light mode, dark blue in dark mode
    static let intentCardBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 30/255, green: 50/255, blue: 80/255, alpha: 1)
            : UIColor(red: 240/255, green: 245/255, blue: 1.0, alpha: 1)
    })
    static let intentCardBorder = appBlue

    // Error card — light pink in light mode, dark red in dark mode
    static let errorCardBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 70/255, green: 20/255, blue: 20/255, alpha: 1)
            : UIColor(red: 1.0, green: 245/255, blue: 245/255, alpha: 1)
    })
    static let errorCardBorder = Color(red: 1.0, green: 59/255, blue: 48/255)

    // Mic button
    static let micButtonSize: CGFloat = 60

    // Wave bars
    static let waveBarsCount: Int = 5
    static let waveBarWidth: CGFloat = 4
    static let waveBarMinHeight: CGFloat = 6
    static let waveBarMaxHeight: CGFloat = 32
    static let waveBarSpacing: CGFloat = 5

    // Countdown ring
    static let countdownRingSize: CGFloat = 76
    static let countdownRingLineWidth: CGFloat = 3

    // Typography
    static let transcriptFontSize: CGFloat = 15
    static let statusDotSize: CGFloat = 8
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
