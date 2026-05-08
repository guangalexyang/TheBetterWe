import SwiftUI

struct MeView: View {
    var onMenuTap: () -> Void = {}

    var body: some View {
        NavigationStack {
            ContentUnavailableView("Me", systemImage: "person", description: Text("Coming soon"))
                .navigationTitle("Me")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: onMenuTap) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.primary)
                        }
                    }
                }
        }
    }
}

#Preview {
    MeView()
}
