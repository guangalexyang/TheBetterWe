import SwiftUI

struct AddFamilyView: View {
    var onComplete: ([FamilyMembership]) -> Void = { _ in }

    @State private var navigateToScanner = false
    @State private var navigateToCreate = false
    @Environment(\.appTheme) private var theme

    private let headerGradient = LinearGradient(
        colors: [
            Color(red: 240/255, green: 112/255, blue: 74/255),
            Color(red: 232/255, green: 93/255, blue: 122/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(spacing: 16) {
            actionCard(
                icon: "qrcode.viewfinder",
                title: "扫码加入家庭",
                subtitle: "扫描家庭邀请码加入已有家庭",
                isPrimary: true
            ) {
                navigateToScanner = true
            }

            actionCard(
                icon: "plus.circle",
                title: "创建新家庭",
                subtitle: "从零开始创建一个新家庭",
                isPrimary: false
            ) {
                navigateToCreate = true
            }
        }
        .padding(.horizontal, FamilyStyle.screenHPadding)
        .navigationDestination(isPresented: $navigateToScanner) {
            QRScannerView(onComplete: onComplete)
        }
        .navigationDestination(isPresented: $navigateToCreate) {
            CreateFamilyView(onComplete: onComplete)
        }
    }

    @ViewBuilder
    private func actionCard(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isPrimary ? AnyShapeStyle(headerGradient) : AnyShapeStyle(theme.cardBorder))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isPrimary ? Color.white : theme.primaryAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.systemGray3))
            }
            .padding(16)
            .background(theme.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
