import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = AuthService.isAuthenticated

    var body: some View {
        if isAuthenticated {
            MainTabView(onLogOut: { isAuthenticated = false })
        } else {
            LoginView(onSuccess: { isAuthenticated = true })
        }
    }
}
