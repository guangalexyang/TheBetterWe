import SwiftUI
import SwiftData

@main
struct TheBetterWeApp: App {
    @State private var themeManager = ThemeManager()

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
                .environment(themeManager)
                .environment(\.appTheme, themeManager.current)
                .preferredColorScheme(themeManager.current.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
