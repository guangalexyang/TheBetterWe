import SwiftUI
import SwiftData
import AppIntents

@main
struct TheBetterWeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    TheBetterWeShortcuts.updateAppShortcutParameters()
                    // Replace with real server base URL when backend is live.
                    // guard let url = URL(string: "https://api.thebetterwe.com") else { return }
                    // await FeatureToggle.shared.fetch(from: url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
