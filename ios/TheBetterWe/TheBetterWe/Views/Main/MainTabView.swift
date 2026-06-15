import SwiftUI

enum AppTab {
    case family, me
}

struct MainTabView: View {
    var membership: FamilyMembership
    var onLogOut: () -> Void = {}
    var onFamilyDeleted: () -> Void = {}

    @State private var selectedTab: AppTab = .family
    @State private var showCreate = false
    @State private var showMenu = false
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
        ZStack(alignment: .trailing) {
            // Subtle warm gradient background
            LinearGradient(
                colors: theme.pageBgGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Group {
                switch selectedTab {
                case .family: FamilyView(membership: membership, onDeleted: onFamilyDeleted, onLogOut: onLogOut)
                case .me: MeView(
                    membership: membership,
                    onMenuTap: { withAnimation(.easeInOut(duration: 0.25)) { showMenu = true } },
                    onLogOut: onLogOut
                )
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(selectedTab: $selectedTab, onPlus: { showCreate = true })
            }

            if showMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) { showMenu = false }
                    }
                    .transition(.opacity)

                MenuDrawer(
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.25)) { showMenu = false }
                    },
                    onLogOut: {
                        withAnimation(.easeInOut(duration: 0.25)) { showMenu = false }
                        Task { await AuthService.logOut() }
                        onLogOut()
                    }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showMenu)
        .sheet(isPresented: $showCreate) {
            VoiceInputView(familyId: membership.familyId)
                .presentationDetents([.height(VoiceInputStyle.sheetHeight)])
                .presentationDragIndicator(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        } // NavigationStack
    }
}

private struct MenuDrawer: View {
    var onDismiss: () -> Void
    var onLogOut: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.bold())
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color(.systemGray5), in: Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .padding(.bottom, 16)

            Spacer()

            Button(action: onLogOut) {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .frame(width: 22)
                    Text("Log Out")
                    Spacer()
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(theme.cardSurface, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 48)
        }
        .frame(width: UIScreen.main.bounds.width * 0.82)
        .frame(maxHeight: .infinity)
        .background(theme.pageBg)
        .ignoresSafeArea()
    }
}

private struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    let onPlus: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(theme.cardBorder)
                .frame(height: 0.5)
            // bottom-aligned so the taller + button floats above the tab icons
            HStack(alignment: .bottom, spacing: 0) {
                tabButton(icon: "house", label: "Home", tab: .family)
                Spacer()
                plusButton
                Spacer()
                tabButton(icon: "person", label: "Me", tab: .me)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .background(theme.cardSurface)
        }
    }

    @ViewBuilder
    private func tabButton(icon: String, label: LocalizedStringKey, tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        Button { selectedTab = tab } label: {
            VStack(spacing: 2) {
                Image(systemName: isSelected ? "\(icon).fill" : icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? theme.tabActiveColor : theme.tabInactiveColor)
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? theme.tabActiveColor : theme.tabInactiveColor)
                Circle()
                    .fill(isSelected ? theme.tabActiveColor : Color.clear)
                    .frame(width: 4, height: 4)
            }
        }
    }

    private var plusButton: some View {
        Button { onPlus() } label: {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 240/255, green: 112/255, blue: 74/255),
                            Color(red: 232/255, green: 93/255, blue: 122/255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(
                    color: Color(red: 240/255, green: 112/255, blue: 74/255).opacity(0.45),
                    radius: 12, y: 4
                )
        }
    }
}

#Preview {
    MainTabView(membership: FamilyMembership(
        familyId: 1, familyName: "The Yangs", memberId: 1,
        displayName: "Dad", roleKeywords: ["familyTodo", "pointSystem", "familyNotes"]
    ))
    .environment(ThemeManager())
}
