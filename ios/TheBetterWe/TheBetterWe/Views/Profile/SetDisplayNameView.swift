import SwiftUI

struct SetDisplayNameView: View {
    var onComplete: () -> Void = {}
    var onLogOut: () -> Void = {}

    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.appTheme) private var theme

    private var canContinue: Bool { !displayName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Text("How should I call you?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("You can go by a different name in each family.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer().frame(height: 40)

            HStack(spacing: 12) {
                Image(systemName: "person")
                    .foregroundStyle(.secondary)
                    .frame(width: AuthStyle.fieldIconWidth)
                Divider().frame(height: AuthStyle.fieldDividerHeight)
                TextField("Your name", text: $displayName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
            }
            .padding(.horizontal, AuthStyle.fieldHPadding)
            .padding(.vertical, AuthStyle.fieldVPadding)
            .background(theme.cardSurface, in: RoundedRectangle(cornerRadius: AuthStyle.fieldCornerRadius))
            .overlay(RoundedRectangle(cornerRadius: AuthStyle.fieldCornerRadius).strokeBorder(theme.cardBorder, lineWidth: 1))
            .padding(.horizontal, AuthStyle.screenHPadding)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
                    .padding(.horizontal, AuthStyle.screenHPadding)
            }

            Spacer()

            Button {
                isLoading = true
                errorMessage = nil
                Task {
                    do {
                        try await AuthService.updateDisplayName(displayName.trimmingCharacters(in: .whitespaces))
                        onComplete()
                    } catch {
                        errorMessage = String(localized: "Network error. Please try again.")
                    }
                    isLoading = false
                }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continue")
                            .font(.body.bold())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AuthStyle.buttonVPadding)
                .background(canContinue ? theme.primaryAccent : theme.primaryAccent.opacity(0.3))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AuthStyle.buttonCornerRadius))
            }
            .disabled(!canContinue || isLoading)
            .padding(.horizontal, AuthStyle.screenHPadding)
            .padding(.bottom, 16)

            Button {
                Task { await AuthService.logOut() }
                onLogOut()
            } label: {
                Text("Log Out")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 48)
        }
        .background(
            LinearGradient(
                colors: theme.pageBgGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

#Preview("Dark") {
    SetDisplayNameView()
        .environment(ThemeManager())
        .environment(\.appTheme, AppTheme.dark)
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    SetDisplayNameView()
        .environment(ThemeManager())
        .environment(\.appTheme, AppTheme.light)
        .preferredColorScheme(.light)
}
