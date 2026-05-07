import SwiftUI

struct FamilyView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                // Replace with Image("AppLogo") when logo asset is added
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 80, height: 80)
                    Image(systemName: "house.heart.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.red)
                }

                Text("Home")
                    .font(.title2.bold())
                Text("Coming soon")
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    FamilyView()
}
