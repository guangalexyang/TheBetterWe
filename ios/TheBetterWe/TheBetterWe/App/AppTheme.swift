import SwiftUI

struct AppTheme {
    let colorScheme: ColorScheme
    /// Full-screen page background (base color)
    let pageBg: Color
    /// Gradient stops for page background — single element = flat color
    let pageBgGradientColors: [Color]
    /// Card and tab bar surface
    let cardSurface: Color
    /// Hairline border on cards and tab bar separator
    let cardBorder: Color
    /// Bottom tab bar active icon/label
    let tabActiveColor: Color
    /// Bottom tab bar inactive icon/label
    let tabInactiveColor: Color
    /// Top tab strip active text (on filled pill)
    let tabStripActiveColor: Color
    /// Top tab strip inactive label
    let tabStripInactiveColor: Color
    /// Hamburger icon and primary nav icons
    let navIconColor: Color
    /// Brand accent (orange) — badge, toggle on-state, pill fill
    let primaryAccent: Color
    /// Outlined + button border color (light mode only; dark uses gradient)
    let plusBorderColor: Color
}

extension AppTheme {
    static let dark = AppTheme(
        colorScheme: .dark,
        pageBg:                Color(red: 26/255,  green: 18/255,  blue: 16/255),   // #1a1210 warm
        pageBgGradientColors:  [
            Color(red: 26/255,  green: 18/255,  blue: 16/255),   // #1a1210
            Color(red: 35/255,  green: 21/255,  blue: 16/255),   // #231510
            Color(red: 30/255,  green: 18/255,  blue: 24/255),   // #1e1218
        ],
        cardSurface:           Color(red: 35/255,  green: 24/255,  blue: 21/255),   // #231815 warm
        cardBorder:            Color.white.opacity(0.08),
        tabActiveColor:        Color(red: 240/255, green: 112/255, blue: 74/255),   // #f0704a orange
        tabInactiveColor:      Color(red: 155/255, green: 123/255, blue: 111/255),  // #9b7b6f warm muted
        tabStripActiveColor:   .white,
        tabStripInactiveColor: Color(red: 160/255, green: 128/255, blue: 112/255),  // #a08070 warm muted
        navIconColor:          Color(red: 240/255, green: 232/255, blue: 228/255),  // #f0e8e4 warm white
        primaryAccent:         Color(red: 240/255, green: 112/255, blue: 74/255),   // #f0704a
        plusBorderColor:       Color.white.opacity(0.3)
    )

    static let light = AppTheme(
        colorScheme: .light,
        pageBg:                Color(red: 253/255, green: 248/255, blue: 245/255),  // #fdf8f5
        pageBgGradientColors:  [
            Color(red: 253/255, green: 248/255, blue: 245/255),  // flat (single stop)
        ],
        cardSurface:           .white,
        cardBorder:            Color(red: 240/255, green: 112/255, blue: 74/255).opacity(0.12),
        tabActiveColor:        Color(red: 240/255, green: 112/255, blue: 74/255),   // #f0704a
        tabInactiveColor:      Color(red: 155/255, green: 123/255, blue: 111/255),  // #9b7b6f
        tabStripActiveColor:   .white,
        tabStripInactiveColor: Color(red: 155/255, green: 123/255, blue: 111/255),  // #9b7b6f
        navIconColor:          Color(red: 45/255,  green: 31/255,  blue: 26/255),   // #2d1f1a
        primaryAccent:         Color(red: 240/255, green: 112/255, blue: 74/255),   // #f0704a
        plusBorderColor:       Color(red: 240/255, green: 112/255, blue: 74/255).opacity(0.7)
    )
}

extension EnvironmentValues {
    @Entry var appTheme: AppTheme = .dark
}
