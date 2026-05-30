import SwiftUI

struct PointRecordView: View {
    let child: PSChild

    var body: some View {
        VStack(spacing: 16) {
            Text("🚧").font(.largeTitle)
            Text("Coming soon").font(.headline.bold())
            Text("Point history will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(child.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
