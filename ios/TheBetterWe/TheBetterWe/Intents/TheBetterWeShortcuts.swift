import AppIntents

struct TheBetterWeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddPointsIntent(),
            phrases: [
                "Add points in \(.applicationName)",
                "Award points in \(.applicationName)"
            ],
            shortTitle: "Add Points",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: DeductPointsIntent(),
            phrases: [
                "Deduct points in \(.applicationName)",
                "Remove points in \(.applicationName)"
            ],
            shortTitle: "Deduct Points",
            systemImageName: "minus.circle"
        )
    }
}
