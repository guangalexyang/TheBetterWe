import SwiftUI

private let roleOptions: [(label: String, value: String, icon: String)] = [
    ("爸爸 Dad",  "dad",   "person.fill"),
    ("妈妈 Mom",  "mom",   "person.fill"),
    ("孩子 Kid",  "child", "star.fill"),
    ("其他 Other","other", "person.2.fill"),
]

struct JoinFamilyView: View {
    let inviteCode: String
    let familyName: String
    var onComplete: ([FamilyMembership]) -> Void = { _ in }

    @State private var displayName: String = AuthService.displayName ?? ""
    @State private var selectedRole: String = "dad"
    @State private var isJoining = false
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) private var dismiss
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
        ScrollView {
            VStack(spacing: 0) {
                // Family banner
                VStack(spacing: 6) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(verbatim: familyName)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("加入此家庭 / Joining this family")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(headerGradient)

                VStack(spacing: 20) {
                    // Display name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("你的名字 / Your name in family")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        TextField("e.g. 爸爸 / Dad", text: $displayName)
                            .font(.body)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(theme.cardSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(theme.cardBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Role picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("我的身份 / My role")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(roleOptions, id: \.value) { option in
                                RoleChip(
                                    label: option.label,
                                    icon: option.icon,
                                    isSelected: selectedRole == option.value
                                ) {
                                    selectedRole = option.value
                                }
                            }
                        }
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Join button
                    Button {
                        Task { await joinFamily() }
                    } label: {
                        Group {
                            if isJoining {
                                ProgressView().tint(.white)
                            } else {
                                Text("加入家庭 / Join Family")
                                    .font(.body.bold())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(displayName.trimmingCharacters(in: .whitespaces).isEmpty
                            ? theme.primaryAccent.opacity(0.4)
                            : theme.primaryAccent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isJoining)
                }
                .padding(20)
            }
        }
        .background(theme.pageBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.25), in: Circle())
            }
            .padding(.top, 56)
            .padding(.leading, 20)
        }
    }

    private func joinFamily() async {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isJoining = true
        errorMessage = nil
        do {
            let memberships = try await FamilyService.joinFamily(
                inviteCode: inviteCode,
                displayName: name,
                role: selectedRole
            )
            onComplete(memberships)
        } catch FamilyError.alreadyMember {
            errorMessage = "已经是该家庭的成员 / Already a member of this family"
            isJoining = false
        } catch FamilyError.notFound {
            errorMessage = "邀请码已失效 / Invite code is no longer valid"
            isJoining = false
        } catch {
            errorMessage = error.localizedDescription
            isJoining = false
        }
    }
}

private struct RoleChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? theme.primaryAccent : theme.cardSurface)
            .foregroundStyle(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : theme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
