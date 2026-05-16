import SwiftUI

// MARK: - Dashboard View

struct DashboardView: View {
    let membership: FamilyMembership

    @State private var widgetOrder: [AppModule] = []
    @State private var draggingItem: AppModule? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var cardFrames: [AppModule: CGRect] = [:]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(widgetOrder, id: \.self) { module in
                    WidgetCard(module: module)
                        .scaleEffect(draggingItem == module ? 1.03 : 1.0)
                        .opacity(draggingItem == module ? 0.85 : 1.0)
                        .zIndex(draggingItem == module ? 1 : 0)
                        .offset(draggingItem == module ? dragOffset : .zero)
                        .gesture(longPressThenDrag(for: module))
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: DashboardFramePreference.self,
                                    value: [module: geo.frame(in: .named("dashboard"))]
                                )
                            }
                        )
                }
            }
            .padding(16)
        }
        .coordinateSpace(name: "dashboard")
        .onPreferenceChange(DashboardFramePreference.self) { cardFrames = $0 }
        .onAppear { loadWidgetOrder() }
        .onChange(of: widgetOrder) { _, _ in saveWidgetOrder() }
    }

    // MARK: - Gesture

    private func longPressThenDrag(for module: AppModule) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(coordinateSpace: .named("dashboard")))
            .onChanged { value in
                switch value {
                case .second(_, let drag?):
                    if draggingItem == nil {
                        withAnimation(.easeOut(duration: 0.12)) { draggingItem = module }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    dragOffset = drag.translation
                    reorder(dragging: module, at: drag.location)
                default:
                    break
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    draggingItem = nil
                    dragOffset = .zero
                }
            }
    }

    private func reorder(dragging: AppModule, at location: CGPoint) {
        guard
            let target = cardFrames.first(where: { $0.value.contains(location) && $0.key != dragging })?.key,
            let fromIndex = widgetOrder.firstIndex(of: dragging),
            let toIndex = widgetOrder.firstIndex(of: target)
        else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            widgetOrder.move(fromOffsets: IndexSet(integer: fromIndex),
                             toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    // MARK: - Persistence

    private var orderKey: String { "dashboardWidgetOrder_\(membership.familyId)" }

    private func loadWidgetOrder() {
        let active = AppModule.allCases.filter {
            $0.isMandatory || membership.roleKeywords.contains($0.rawValue)
        }
        let saved = (UserDefaults.standard.array(forKey: orderKey) as? [String] ?? [])
            .compactMap { AppModule(rawValue: $0) }
            .filter { active.contains($0) }
        let missing = active.filter { !saved.contains($0) }
        widgetOrder = saved + missing
    }

    private func saveWidgetOrder() {
        UserDefaults.standard.set(widgetOrder.map(\.rawValue), forKey: orderKey)
    }
}

// MARK: - Widget Card

private struct WidgetCard: View {
    let module: AppModule

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: module.icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(module.title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(module.widgetHeaderColor)

            Text("Coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

// MARK: - AppModule header color (view-layer only)

private extension AppModule {
    var widgetHeaderColor: Color {
        switch self {
        case .familyTodo:  return .indigo
        case .familyNotes: return Color(red: 0.98, green: 0.75, blue: 0.17)
        case .pointSystem: return .orange
        case .orderFromMe: return .teal
        }
    }
}

// MARK: - Frame Preference Key

private struct DashboardFramePreference: PreferenceKey {
    static var defaultValue: [AppModule: CGRect] = [:]
    static func reduce(value: inout [AppModule: CGRect], nextValue: () -> [AppModule: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Preview

#Preview {
    DashboardView(membership: FamilyMembership(
        familyId: 1, familyName: "The Yangs", memberId: 1,
        displayName: "Dad", roleKeywords: ["familyTodo", "pointSystem", "familyNotes", "orderFromMe"]
    ))
}

#Preview("中文") {
    DashboardView(membership: FamilyMembership(
        familyId: 1, familyName: "杨家", memberId: 1,
        displayName: "妈妈", roleKeywords: ["familyTodo", "pointSystem", "familyNotes"]
    ))
    .environment(\.locale, .init(identifier: "zh-Hans"))
}
