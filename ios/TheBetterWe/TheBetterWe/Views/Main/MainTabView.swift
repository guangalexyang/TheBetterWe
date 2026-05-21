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

    var body: some View {
        NavigationStack {
        ZStack(alignment: .trailing) {
            Group {
                switch selectedTab {
                case .family: FamilyView(membership: membership, onDeleted: onFamilyDeleted)
                case .me: MeView(onMenuTap: {
                    withAnimation(.easeInOut(duration: 0.25)) { showMenu = true }
                })
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
            Text("Create")
                .presentationDetents([.medium])
        }
        .toolbar(.hidden, for: .navigationBar)
        } // NavigationStack
    }
}

private struct MenuDrawer: View {
    var onDismiss: () -> Void
    var onLogOut: () -> Void

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
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 48)
        }
        .frame(width: UIScreen.main.bounds.width * 0.82)
        .frame(maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea()
    }
}

private struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    let onPlus: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                tabButton(icon: "house", label: "Home", tab: .family)
                Spacer()
                plusButton
                Spacer()
                tabButton(icon: "person", label: "Me", tab: .me)
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .background(.white)
        }
    }

    @ViewBuilder
    private func tabButton(icon: String, label: LocalizedStringKey, tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        Button { selectedTab = tab } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? "\(icon).fill" : icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
        }
    }

    private var plusButton: some View {
        Button { onPlus() } label: {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary, lineWidth: 1.5)
                .frame(width: 52, height: 34)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.primary)
                }
        }
    }
}

#Preview {
    MainTabView(membership: FamilyMembership(
        familyId: 1, familyName: "The Yangs", memberId: 1,
        displayName: "Dad", roleKeywords: ["familyTodo", "pointSystem", "familyNotes"]
    ))
}
