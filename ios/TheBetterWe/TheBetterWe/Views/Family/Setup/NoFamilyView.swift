import SwiftUI

struct NoFamilyView: View {
    var displayName: String? = AuthService.displayName
    var onComplete: ([FamilyMembership]) -> Void = { _ in }

    @State private var navigateToCreate = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 8) {
                    // TODO: Replace with app logo asset when available
                    Image(systemName: "house.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)

                    if let name = displayName {
                        Text("\(name),")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                    }

                    Text("You're not in a family yet")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("Create a new family or join one with an invite code.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        navigateToCreate = true
                    } label: {
                        Text("Create a family")
                            .font(.body.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FamilyStyle.buttonVPadding)
                            .background(Color.primary)
                            .foregroundStyle(Color(UIColor.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: FamilyStyle.buttonCornerRadius))
                    }

                    Button {
                        // TODO: navigate to JoinFamilyView
                    } label: {
                        Text("Scan QR code to join")
                            .font(.body.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FamilyStyle.buttonVPadding)
                            .background(Color(.systemGray6))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: FamilyStyle.buttonCornerRadius))
                    }
                }
                .padding(.horizontal, FamilyStyle.screenHPadding)
                .padding(.bottom, 48)
            }
            .navigationDestination(isPresented: $navigateToCreate) {
                CreateFamilyView(displayName: displayName, onComplete: onComplete)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    NoFamilyView(displayName: "Alex")
}

#Preview("中文") {
    NoFamilyView(displayName: "Alex")
        .environment(\.locale, .init(identifier: "zh-Hans"))
}
