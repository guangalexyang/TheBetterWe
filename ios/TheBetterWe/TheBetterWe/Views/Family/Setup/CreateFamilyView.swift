import SwiftUI

enum FamilyRole: Hashable {
    case dad, mom, child, other

    var label: LocalizedStringKey {
        switch self {
        case .dad:   return "Dad"
        case .mom:   return "Mom"
        case .child: return "Child"
        case .other: return "Other"
        }
    }
}

struct CreateFamilyView: View {
    var displayName: String? = AuthService.displayName
    var onComplete: ([FamilyMembership]) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var familyName = ""
    @State private var selectedRole: FamilyRole? = nil
    @State private var customRole = ""
    @State private var navigateToModules = false

    private var effectiveName: String { familyName.trimmingCharacters(in: .whitespaces) }
    private var canContinue: Bool {
        guard selectedRole != nil else { return false }
        if selectedRole == .other { return !customRole.trimmingCharacters(in: .whitespaces).isEmpty }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: back button left, title centered
            ZStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.bold())
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                }
                Text("Family Info")
                    .font(.title.bold())
            }
            .padding(.horizontal, AuthStyle.screenHPadding)
            .frame(height: AuthStyle.topRowHeight)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Family name
                    Text("Family name")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 32)
                        .padding(.bottom, 8)

                    HStack(spacing: 12) {
                        Image(systemName: "house")
                            .foregroundStyle(.secondary)
                            .frame(width: AuthStyle.fieldIconWidth)
                        Divider().frame(height: AuthStyle.fieldDividerHeight)
                        TextField("Family name", text: $familyName)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, AuthStyle.fieldHPadding)
                    .padding(.vertical, AuthStyle.fieldVPadding)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: AuthStyle.fieldCornerRadius))

                    // Role section
                    Text("You are the family's:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, AuthStyle.sectionSpacing)
                        .padding(.bottom, 8)

                    HStack(spacing: 10) {
                        ForEach([FamilyRole.dad, .mom, .child, .other], id: \.self) { role in
                            roleChip(role)
                        }
                    }

                    if selectedRole == .other {
                        TextField("e.g. 姑妈", text: $customRole)
                            .autocorrectionDisabled()
                            .padding(.horizontal, AuthStyle.fieldHPadding)
                            .padding(.vertical, AuthStyle.fieldVPadding)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: AuthStyle.fieldCornerRadius))
                            .padding(.top, 12)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedRole)
                .padding(.horizontal, AuthStyle.screenHPadding)
            }

            // Pinned continue button
            Button {
                navigateToModules = true
            } label: {
                Text("Continue")
                    .font(.body.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AuthStyle.buttonVPadding)
                    .background(canContinue ? Color.primary : Color.primary.opacity(0.3))
                    .foregroundStyle(Color(UIColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: AuthStyle.buttonCornerRadius))
            }
            .disabled(!canContinue)
            .padding(.horizontal, AuthStyle.screenHPadding)
            .padding(.top, 16)
            .padding(.bottom, 48)
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToModules) {
            ModuleSelectionView(
                familyName: effectiveName,
                role: selectedRole ?? .other,
                customRole: customRole,
                onComplete: onComplete
            )
        }
        .onAppear {
            if let name = displayName, familyName.isEmpty {
                familyName = String(format: String(localized: "%@'s Family"), name)
            }
        }
    }

    @ViewBuilder
    private func roleChip(_ role: FamilyRole) -> some View {
        let isSelected = selectedRole == role
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedRole = role
                if role != .other { customRole = "" }
            }
        } label: {
            Text(role.label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, FamilyStyle.chipHPadding)
                .padding(.vertical, FamilyStyle.chipVPadding)
                .background(isSelected ? Color.primary : Color(.systemGray6))
                .foregroundStyle(isSelected ? Color(UIColor.systemBackground) : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: FamilyStyle.chipCornerRadius))
        }
    }
}

#Preview {
    NavigationStack { CreateFamilyView(displayName: "Alex") }
}

#Preview("中文") {
    NavigationStack { CreateFamilyView(displayName: "Alex") }
        .environment(\.locale, .init(identifier: "zh-Hans"))
}
