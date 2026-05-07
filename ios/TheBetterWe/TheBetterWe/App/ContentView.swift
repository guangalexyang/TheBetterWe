import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = false

    var body: some View {
        if isAuthenticated {
            MainTabView()
        } else {
            LoginView(onSuccess: { isAuthenticated = true })
        }
    }
}
