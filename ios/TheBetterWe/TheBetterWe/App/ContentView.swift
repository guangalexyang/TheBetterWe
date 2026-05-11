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
    @State private var appState: AppState = AuthService.displayName == nil ? .needsDisplayName : .noFamily // HARDCODE

    var body: some View {
        if isAuthenticated {
            switch appState {
            case .loading:
                ProgressView()
            case .needsDisplayName:
                SetDisplayNameView(
                    onComplete: { appState = .noFamily },
                    onLogOut: { isAuthenticated = false; appState = .needsDisplayName }
                )
            case .noFamily:
                NoFamilyView(
                    displayName: AuthService.displayName,
                    onComplete: { memberships in appState = .hasFamily(memberships) }
                )
            case .hasFamily:
                MainTabView(onLogOut: {
                    isAuthenticated = false
                    appState = .noFamily // HARDCODE
                })
            case .offline:
                MainTabView(onLogOut: {
                    isAuthenticated = false
                    appState = .noFamily // HARDCODE
                })
            }
        } else {
            LoginView(onSuccess: {
                isAuthenticated = true
                appState = AuthService.displayName == nil ? .needsDisplayName : .noFamily // HARDCODE
            })
        }
    }
}
