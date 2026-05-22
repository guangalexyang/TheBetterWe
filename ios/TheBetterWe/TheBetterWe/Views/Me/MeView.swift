import SwiftUI

struct MeView: View {
    var onMenuTap: () -> Void = {}
    var onLogOut: () -> Void = {}

    var body: some View {
        VStack {
            ContentUnavailableView("Me", systemImage: "person", description: Text("Coming soon"))

            Button("Log Out") {
                Task {
                    await AuthService.logOut()
                    onLogOut()
                }
            }
            .foregroundStyle(.red)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    MeView()
}
