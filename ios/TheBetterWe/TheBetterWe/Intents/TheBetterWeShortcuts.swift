import AppIntents

struct TheBetterWeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddPointsIntent(),
            phrases: [
                "Add points in \(.applicationName)",
                "Award points in \(.applicationName)",
                "在\(.applicationName)加分",
                "用\(.applicationName)加分",
                "给孩子加分在\(.applicationName)"
            ],
            shortTitle: "Add Points",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: DeductPointsIntent(),
            phrases: [
                "Deduct points in \(.applicationName)",
                "Remove points in \(.applicationName)",
                "在\(.applicationName)扣分",
                "用\(.applicationName)扣分",
                "给孩子扣分在\(.applicationName)"
            ],
            shortTitle: "Deduct Points",
            systemImageName: "minus.circle"
        )
        AppShortcut(
            intent: RecordPointsIntent(),
            phrases: [
                "用\(.applicationName)记分",
                "Record points in \(.applicationName)",
                "Log points in \(.applicationName)"
            ],
            shortTitle: "Record Points",
            systemImageName: "mic.circle"
        )
    }
}
