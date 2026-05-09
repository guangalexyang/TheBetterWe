import SwiftUI

enum FamilyRole: Equatable {
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

    private var effectiveName: String { familyName.trimmingCharacters(in: .whitespaces) }
    private var canContinue: Bool {
        guard selectedRole != nil else { return false }
        if selectedRole == .other { return !customRole.trimmingCharacters(in: .whitespaces).isEmpty }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.bold())
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                }
                .frame(height: AuthStyle.topRowHeight)

                Text("Name your family")
                    .font(.title.bold())
                    .padding(.bottom, AuthStyle.sectionSpacing)

                // Family name
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
                VStack(alignment: .leading, spacing: 12) {
                    Text("You are the family's:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, AuthStyle.sectionSpacing)

                    HStack(spacing: 10) {
                        ForEach([FamilyRole.dad, .mom, .child, .other], id: \.label) { role in
                            roleChip(role)
                        }
                    }

                    if selectedRole == .other {
                        TextField("e.g. 姑妈", text: $customRole)
                            .autocorrectionDisabled()
                            .padding(.horizontal, AuthStyle.fieldHPadding)
                            .padding(.vertical, AuthStyle.fieldVPadding)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: AuthStyle.fieldCornerRadius))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedRole)

                Spacer().frame(height: 48)

                Button {
                    // TODO: navigate to next step with effectiveName + role
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
                .padding(.bottom, 48)
            }
            .padding(.horizontal, AuthStyle.screenHPadding)
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
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
