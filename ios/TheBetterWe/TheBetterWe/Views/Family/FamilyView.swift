import SwiftUI

enum FamilyTab: Hashable {
    case dashboard
    case module(AppModule)
}

struct FamilyView: View {
    var membership: FamilyMembership
    var onDeleted: () -> Void = {}

    @State private var selectedTab: FamilyTab = .dashboard
    @State private var showDrawer = false
    @State private var showInviteSheet = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var errorMessage: String? = nil

    private var tabs: [FamilyTab] {
        let active = AppModule.allCases.filter { membership.roleKeywords.contains($0.rawValue) }
        return [.dashboard] + active.map { .module($0) }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                FamilyTopBar(selectedTab: $selectedTab, tabs: tabs) {
                    withAnimation(.easeInOut(duration: 0.25)) { showDrawer = true }
                }
                Divider()
                tabContent
            }

            if showDrawer {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) { showDrawer = false }
                    }
                    .transition(.opacity)

                FamilyLeftDrawer(
                    membership: membership,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.25)) { showDrawer = false }
                    },
                    onInvite: {
                        withAnimation(.easeInOut(duration: 0.25)) { showDrawer = false }
                        showInviteSheet = true
                    },
                    onEdit: {
                        withAnimation(.easeInOut(duration: 0.25)) { showDrawer = false }
                        showEditSheet = true
                    }
                )
                .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showDrawer)
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
            Text("TODO: Invite")
                .presentationDetents([.medium])
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
            DashboardView(membership: membership)
        case .module(let m):
            switch m {
            case .pointSystem:
                PointSystemView(membership: membership)
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

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onMenu) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
                    .padding(.leading, 16)
                    .padding(.trailing, 8)
            }

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
        .background(Color(.systemBackground))
    }
}

private struct TabLabel: View {
    let tab: FamilyTab
    let isSelected: Bool
    let action: () -> Void

    private var label: LocalizedStringKey {
        switch tab {
        case .dashboard:      return "Dashboard"
        case .module(let m):  return m.title
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                Capsule()
                    .fill(isSelected ? Color.primary : Color.clear)
                    .frame(height: 2.5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Left Drawer

private struct FamilyLeftDrawer: View {
    let membership: FamilyMembership
    let onDismiss: () -> Void
    let onInvite: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Family")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                verbatimRow(icon: "house", label: membership.familyName, action: { /* future: multi-family picker */ })
                drawerRow(icon: "person.badge.plus", label: "Invite", action: onInvite)
                drawerRow(icon: "pencil", label: "Edit", action: onEdit)
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            Spacer()
        }
        .frame(width: UIScreen.main.bounds.width * 0.75)
        .frame(maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
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
