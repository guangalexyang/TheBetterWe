import AppIntents

struct TheBetterWeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddPointsIntent(),
            phrases: [
                // Parameterized — Siri fills all params from one utterance
                "Add \(.$amount) points to \(.$childName) in \(.applicationName)",
                "Add \(.$amount) points to \(.$childName) for \(.$note) in \(.applicationName)",
                "Give \(.$childName) \(.$amount) points in \(.applicationName)",
                "用\(.applicationName)给\(.$childName)加\(.$amount)分",
                "用\(.applicationName)给\(.$childName)加\(.$amount)分，原因是\(.$note)",
                // Generic fallback — Siri asks for each parameter interactively
                "Add points in \(.applicationName)",
                "Award points in \(.applicationName)",
                "用\(.applicationName)加分"
            ],
            shortTitle: "Add Points",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: DeductPointsIntent(),
            phrases: [
                // Parameterized — Siri fills all params from one utterance
                "Deduct \(.$amount) points from \(.$childName) in \(.applicationName)",
                "Deduct \(.$amount) points from \(.$childName) for \(.$note) in \(.applicationName)",
                "用\(.applicationName)给\(.$childName)扣\(.$amount)分",
                "用\(.applicationName)给\(.$childName)扣\(.$amount)分，原因是\(.$note)",
                // Generic fallback — Siri asks for each parameter interactively
                "Deduct points in \(.applicationName)",
                "Remove points in \(.applicationName)",
                "用\(.applicationName)扣分"
            ],
            shortTitle: "Deduct Points",
            systemImageName: "minus.circle"
        )
    }
}
