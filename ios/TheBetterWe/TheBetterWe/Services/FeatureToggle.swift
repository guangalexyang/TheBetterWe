import Foundation

final class FeatureToggle {
    static let shared = FeatureToggle()

    // Add keys here as features are gated.
    enum Key: CaseIterable {}

    private static let cacheKey = "feature_toggle_flags"
    private var flags: [String: Bool] = [:]

    private init() {
        loadCache()
    }

    // MARK: - Public API

    static func isActive(_ key: Key) -> Bool {
        shared.flags[String(describing: key)] ?? false
    }

    static func enable(_ key: Key) {
        shared.flags[String(describing: key)] = true
        shared.saveCache()
    }

    static func disable(_ key: Key) {
        shared.flags[String(describing: key)] = false
        shared.saveCache()
    }

    // MARK: - Server fetch

    func fetch(from baseURL: URL) async {
        let url = baseURL.appending(path: "/config/feature-toggles")
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONDecoder().decode([String: Bool].self, from: data)
        else { return }

        flags = json
        saveCache()
    }

    // MARK: - Cache

    private func loadCache() {
        guard let stored = UserDefaults.standard.dictionary(forKey: Self.cacheKey) as? [String: Bool] else { return }
        flags = stored
    }

    private func saveCache() {
        UserDefaults.standard.set(flags, forKey: Self.cacheKey)
    }
}
