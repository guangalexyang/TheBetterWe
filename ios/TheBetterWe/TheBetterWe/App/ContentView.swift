import SwiftUI

enum AppState {
    case loading
    case needsDisplayName
    case noFamily
    case hasFamily([FamilyMembership])
    case offline
}

struct ContentView: View {
    @State private var isAuthenticated = AuthService.isAuthenticated
    @State private var appState: AppState = AuthService.displayName == nil ? .needsDisplayName : .loading

    var body: some View {
        if isAuthenticated {
            switch appState {
            case .loading:
                ProgressView()
                    .task { await loadFamilies() }
            case .needsDisplayName:
                SetDisplayNameView(
                    onComplete: { appState = .loading },
                    onLogOut: { isAuthenticated = false; appState = .needsDisplayName }
                )
            case .noFamily:
                NoFamilyView(
                    displayName: AuthService.displayName,
                    onComplete: { memberships in appState = .hasFamily(memberships) }
                )
            case .hasFamily(let memberships):
                MainTabView(
                    membership: memberships[0],
                    onLogOut: {
                        isAuthenticated = false
                        appState = .needsDisplayName
                    },
                    onFamilyDeleted: { appState = .noFamily }
                )
            case .offline:
                MainTabView(
                    membership: FamilyMembership(familyId: 0, familyName: "", memberId: 0, displayName: "", roleKeywords: []),
                    onLogOut: {
                        isAuthenticated = false
                        appState = .needsDisplayName
                    }
                )
            }
        } else {
            AuthView(onSuccess: {
                isAuthenticated = true
                appState = AuthService.displayName == nil ? .needsDisplayName : .loading
            })
        }
    }

    private func loadFamilies() async {
        await FeatureToggle.shared.fetch(from: APIConfig.baseURL)
        do {
            let memberships = try await FamilyService.fetchMine()
            appState = memberships.isEmpty ? .noFamily : .hasFamily(memberships)
        } catch FamilyError.unauthorized {
            isAuthenticated = false
            appState = .needsDisplayName
        } catch {
            appState = .offline
        }
    }
}
