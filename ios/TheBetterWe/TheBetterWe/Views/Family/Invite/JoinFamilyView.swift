import SwiftUI

struct JoinFamilyView: View {
    let inviteCode: String
    let familyName: String
    var onComplete: ([FamilyMembership]) -> Void = { _ in }

    @State private var displayName: String = AuthService.displayName ?? ""
    @State private var selectedRole: String = "dad"
    @State private var customRole: String = ""
    @State private var isJoining = false
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    private var roleOptions: [(label: String, value: String, icon: String)] {
        [
            (String(localized: "爸爸"), "dad",   "person.fill"),
            (String(localized: "妈妈"), "mom",   "person.fill"),
            (String(localized: "孩子"), "child", "star.fill"),
            (String(localized: "其他"), "other", "person.2.fill"),
        ]
    }

    private var effectiveRole: String {
        selectedRole == "other" && !customRole.trimmingCharacters(in: .whitespaces).isEmpty
            ? customRole.trimmingCharacters(in: .whitespaces).lowercased()
            : selectedRole
    }

    private var canJoin: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !(selectedRole == "other" && customRole.trimmingCharacters(in: .whitespaces).isEmpty)
    }

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
                VStack(spacing: 6) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(verbatim: familyName)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("加入此家庭")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(headerGradient)

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("你的名字")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        TextField("你的名字", text: $displayName)
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

                    VStack(alignment: .leading, spacing: 10) {
                        Text("我的身份")
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

                        if selectedRole == "other" {
                            TextField("自定义身份", text: $customRole)
                                .font(.body)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(theme.cardSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(theme.primaryAccent.opacity(0.5), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: selectedRole)

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await joinFamily() }
                    } label: {
                        Group {
                            if isJoining {
                                ProgressView().tint(.white)
                            } else {
                                Text("加入家庭")
                                    .font(.body.bold())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canJoin ? theme.primaryAccent : theme.primaryAccent.opacity(0.4))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .disabled(!canJoin || isJoining)
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
        guard canJoin else { return }
        isJoining = true
        errorMessage = nil
        do {
            let memberships = try await FamilyService.joinFamily(
                inviteCode: inviteCode,
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                role: effectiveRole
            )
            onComplete(memberships)
        } catch FamilyError.alreadyMember {
            errorMessage = String(localized: "已经是该家庭的成员")
            isJoining = false
        } catch FamilyError.notFound {
            errorMessage = String(localized: "邀请码已失效")
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
