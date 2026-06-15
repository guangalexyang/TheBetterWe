import SwiftUI

@Observable
final class ThemeManager {
    var isDark: Bool {
        didSet { UserDefaults.standard.set(isDark, forKey: "appIsDarkTheme") }
    }

    var current: AppTheme { isDark ? .dark : .light }

    init() {
        // Default to dark if no saved preference (matches current app default)
        isDark = UserDefaults.standard.object(forKey: "appIsDarkTheme") as? Bool ?? true
    }

    func toggle() { isDark.toggle() }
}
