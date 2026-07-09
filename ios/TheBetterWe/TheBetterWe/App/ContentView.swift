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
    @State private var selectedFamilyId: Int? = nil

    var body: some View {
        Group {
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
                    let current = memberships.first(where: { $0.familyId == selectedFamilyId }) ?? memberships[0]
                    MainTabView(
                        memberships: memberships,
                        currentMembership: current,
                        onLogOut: {
                            isAuthenticated = false
                            appState = .needsDisplayName
                        },
                        onFamilyDeleted: { appState = .noFamily },
                        onSwitchFamily: { m in selectedFamilyId = m.familyId },
                        onFamiliesUpdated: { newList in
                            selectedFamilyId = newList.last?.familyId
                            appState = .hasFamily(newList)
                        }
                    )
                case .offline:
                    MainTabView(
                        memberships: [FamilyMembership(familyId: 0, familyName: "", memberId: 0, displayName: "", roleKeywords: [])],
                        currentMembership: FamilyMembership(familyId: 0, familyName: "", memberId: 0, displayName: "", roleKeywords: []),
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
        .onReceive(NotificationCenter.default.publisher(for: AuthService.sessionExpiredNotification)) { _ in
            isAuthenticated = false
            appState = .needsDisplayName
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
