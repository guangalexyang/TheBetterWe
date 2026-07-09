import SwiftUI

enum FamilyTab: Hashable {
    case dashboard
    case module(AppModule)
}

struct FamilyView: View {
    var membership: FamilyMembership
    var onDeleted: () -> Void = {}
    var onLogOut: () -> Void = {}

    @State private var selectedTab: FamilyTab = .dashboard
    @State private var pointSystemInitialChildId: Int? = nil
    @State private var showDrawer = false
    @State private var showInviteSheet = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var errorMessage: String? = nil
    @Environment(\.appTheme) private var theme

    private var tabs: [FamilyTab] {
        let active = AppModule.allCases.filter {
            $0.isToggleActive && membership.roleKeywords.contains($0.rawValue)
        }
        return [.dashboard] + active.map { .module($0) }
    }

    var body: some View {
        let drawerW = UIScreen.main.bounds.width * 0.75

        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                FamilyTopBar(selectedTab: $selectedTab, tabs: tabs) {
                    showDrawer = true
                }
                Rectangle()
                    .fill(theme.cardBorder)
                    .frame(height: 0.5)
                tabContent
            }
            .offset(x: showDrawer ? drawerW : 0)
            .overlay {
                if showDrawer {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture { showDrawer = false }
                }
            }

            FamilyLeftDrawer(
                membership: membership,
                onDismiss: { showDrawer = false },
                onInvite: {
                    showDrawer = false
                    showInviteSheet = true
                },
                onEdit: {
                    showDrawer = false
                    showEditSheet = true
                }
            )
            .offset(x: showDrawer ? 0 : -drawerW)
        }
        .animation(.easeInOut(duration: 0.25), value: showDrawer)
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .dashboard { pointSystemInitialChildId = nil }
        }
        .confirmationDialog("Delete \"\(membership.familyName)\"?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Family", role: .destructive) {
                isDeleting = true
                Task {
                    do {
                        try await FamilyService.deleteFamily(id: membership.familyId)
                        onDeleted()
                    } catch {
                        errorMessage = error.localizedDescription
                        isDeleting = false
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteSheet(membership: membership)
                .presentationDetents([.height(580)])
        }
        .sheet(isPresented: $showEditSheet) {
            Text("TODO: Edit")
                .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView(
                membership: membership,
                onChildTapped: { child in
                    pointSystemInitialChildId = child.memberId
                    selectedTab = .module(.pointSystem)
                },
                onViewTodosTapped: {
                    selectedTab = .module(.familyTodo)
                }
            )
        case .module(let m):
            switch m {
            case .pointSystem:
                PointSystemView(membership: membership, onLogOut: onLogOut, initialChildId: pointSystemInitialChildId)
            case .familyTodo:
                FamilyTodoView(familyId: membership.familyId)
            default:
                Text("TODO: \(m.rawValue)")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Top Bar

private struct FamilyTopBar: View {
    @Binding var selectedTab: FamilyTab
    let tabs: [FamilyTab]
    let onMenu: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 20))
                .foregroundStyle(theme.navIconColor)
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .contentShape(Rectangle())
                .onTapGesture(perform: onMenu)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        TabLabel(tab: tab, isSelected: selectedTab == tab) {
                            selectedTab = tab
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(height: 44)
        .background(theme.pageBg)
    }
}

private struct TabLabel: View {
    let tab: FamilyTab
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    private var label: LocalizedStringKey {
        switch tab {
        case .dashboard:      return "Dashboard"
        case .module(let m):  return m.title
        }
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? theme.tabStripActiveColor : theme.tabStripInactiveColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? theme.primaryAccent : Color.clear)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Left Drawer

private struct FamilyLeftDrawer: View {
    let membership: FamilyMembership
    let onDismiss: () -> Void
    let onInvite: () -> Void
    let onEdit: () -> Void
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
        VStack(alignment: .leading, spacing: 0) {
            // Gradient header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("家庭")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(verbatim: membership.familyName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(6)
                        .background(.white.opacity(0.15), in: Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 20)
            .background(headerGradient)

            // Content
            VStack(spacing: 0) {
                verbatimRow(icon: "house", label: membership.familyName, action: { /* future: multi-family picker */ })
                drawerRow(icon: "person.badge.plus", label: "Invite", action: onInvite)
                drawerRow(icon: "pencil", label: "Edit", action: onEdit)
            }
            .background(theme.cardSurface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder, lineWidth: 1))
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()
        }
        .frame(width: UIScreen.main.bounds.width * 0.75)
        .frame(maxHeight: .infinity)
        .background(theme.pageBg)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func drawerRow(icon: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                    .frame(width: 24)
                Text(label)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(.systemGray3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func verbatimRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                    .frame(width: 24)
                Text(verbatim: label)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(.systemGray3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    FamilyView(membership: FamilyMembership(
        familyId: 1, familyName: "The Yangs", memberId: 1,
        displayName: "Dad", roleKeywords: ["familyTodo", "pointSystem", "familyNotes", "orderFromMe"]
    ))
}
