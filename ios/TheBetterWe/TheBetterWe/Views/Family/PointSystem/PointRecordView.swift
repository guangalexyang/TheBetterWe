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

#Preview("English") {
    NavigationStack {
        PointRecordView(child: PSChild(memberId: 1, name: "桅", gender: .boy,
                                      birthday: "2022-03-15", balance: 1280))
    }
}

#Preview("中文") {
    NavigationStack {
        PointRecordView(child: PSChild(memberId: 2, name: "朵", gender: .girl,
                                      birthday: "2020-07-04", balance: 840))
    }
    .environment(\.locale, .init(identifier: "zh-Hans"))
}
