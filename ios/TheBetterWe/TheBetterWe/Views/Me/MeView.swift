import SwiftUI

struct MeView: View {
    var membership: FamilyMembership
    var onMenuTap: () -> Void = {}
    var onLogOut: () -> Void = {}

    @Environment(\.appTheme) private var theme
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profileCard
                settingsSection
                aboutSection
                footerSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 240/255, green: 112/255, blue: 74/255).opacity(0.13),
                                Color(red: 232/255, green: 93/255, blue: 122/255).opacity(0.13)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                Text("😊")
                    .font(.system(size: 32))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: membership.displayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("家长 · \(membership.familyName)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("管理员")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(theme.primaryAccent.opacity(0.12))
                    .foregroundStyle(theme.primaryAccent)
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(20)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Sections

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("账户设置")
            card {
                settingsRow(icon: "gearshape", label: "个人信息",
                            color: Color(red: 74/255, green: 144/255, blue: 217/255))
                divider
                settingsRow(icon: "bell", label: "通知与提醒",
                            color: Color(red: 240/255, green: 112/255, blue: 74/255))
                divider
                darkModeRow
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("关于")
            card {
                settingsRow(icon: "lock.shield", label: "隐私政策",
                            color: Color(red: 82/255, green: 184/255, blue: 138/255))
                divider
                settingsRow(icon: "questionmark.circle", label: "帮助与反馈",
                            color: Color(red: 247/255, green: 201/255, blue: 72/255))
            }
        }
    }

    private var footerSection: some View {
        VStack(spacing: 12) {
            Text("佳家 v1.0.0 · TheBetterWe")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            Button("退出登录") {
                Task {
                    await AuthService.logOut()
                    onLogOut()
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(.red)
        }
        .padding(.top, 4)
    }

    // MARK: - Reusable Components

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    private func settingsRow(icon: String, label: LocalizedStringKey, color: Color) -> some View {
        Button { } label: {
            HStack(spacing: 12) {
                iconBadge(icon: icon, color: color)
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(.systemGray3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var darkModeRow: some View {
        HStack(spacing: 12) {
            iconBadge(icon: "moon.fill",
                      color: Color(red: 124/255, green: 58/255, blue: 237/255))
            Text("深色模式")
                .font(.system(size: 15))
                .foregroundStyle(.primary)
            Spacer()
            darkModeToggle
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var darkModeToggle: some View {
        Button { themeManager.toggle() } label: {
            ZStack(alignment: themeManager.isDark ? .trailing : .leading) {
                Capsule()
                    .fill(themeManager.isDark ? theme.primaryAccent : Color(.systemGray4))
                    .frame(width: 44, height: 26)
                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .padding(2)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: themeManager.isDark)
        }
        .buttonStyle(.plain)
    }

    private func iconBadge(icon: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(color.opacity(0.15))
                .frame(width: 28, height: 28)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.cardBorder)
            .frame(height: 0.5)
            .padding(.leading, 56)
    }
}

#Preview("Dark") {
    MeView(membership: FamilyMembership(
        familyId: 1, familyName: "The Yangs", memberId: 1,
        displayName: "Alex", roleKeywords: ["pointSystem"]
    ))
    .environment(ThemeManager())
    .environment(\.appTheme, AppTheme.dark)
    .preferredColorScheme(.dark)
}

#Preview("Light") {
    MeView(membership: FamilyMembership(
        familyId: 1, familyName: "The Yangs", memberId: 1,
        displayName: "Alex", roleKeywords: ["pointSystem"]
    ))
    .environment(ThemeManager())
    .environment(\.appTheme, AppTheme.light)
    .preferredColorScheme(.light)
}
