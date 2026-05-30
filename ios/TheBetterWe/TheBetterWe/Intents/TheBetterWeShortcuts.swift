import AppIntents

struct TheBetterWeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordPointsIntent(),
            phrases: [
                "用\(.applicationName)记分",
                "用\(.applicationName)记录积分",
                "在\(.applicationName)记分",
                "在\(.applicationName)记录积分",
                "Record points in \(.applicationName)",
                "Log points in \(.applicationName)"
            ],
            shortTitle: "记录积分",
            systemImageName: "mic.circle"
        )
    }
}
