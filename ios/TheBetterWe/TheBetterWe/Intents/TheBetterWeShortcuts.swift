import AppIntents

struct TheBetterWeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddPointsIntent(),
            phrases: [
                "Add \(\.$amount) points to \(\.$childName) in \(.applicationName)",
                "Add \(\.$amount) points to \(\.$childName) for \(\.$note) in \(.applicationName)"
            ],
            shortTitle: "Add Points",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: DeductPointsIntent(),
            phrases: [
                "Deduct \(\.$amount) points from \(\.$childName) in \(.applicationName)",
                "Deduct \(\.$amount) points from \(\.$childName) for \(\.$note) in \(.applicationName)"
            ],
            shortTitle: "Deduct Points",
            systemImageName: "minus.circle"
        )
    }
}
