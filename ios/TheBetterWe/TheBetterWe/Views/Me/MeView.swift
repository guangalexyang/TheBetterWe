import SwiftUI

struct MeView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Me", systemImage: "person", description: Text("Coming soon"))
                .navigationTitle("Me")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MeView()
}
