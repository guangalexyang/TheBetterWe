import SwiftUI

enum AppTab {
    case family, me
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .family
    @State private var showCreate = false

    var body: some View {
        Group {
            switch selectedTab {
            case .family: FamilyView()
            case .me: MeView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selectedTab: $selectedTab, onPlus: { showCreate = true })
        }
        .sheet(isPresented: $showCreate) {
            Text("Create") // TODO: create action sheet
                .presentationDetents([.medium])
        }
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
    MainTabView()
}
