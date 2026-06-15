import SwiftUI

// MARK: - Dashboard View

struct DashboardView: View {
    let membership: FamilyMembership
    var onChildTapped: ((PSChild) -> Void)? = nil

    @State private var widgetOrder: [AppModule] = []
    @State private var draggingModule: AppModule? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var liftOrigin: CGRect = .zero
    @State private var lastHoverIndex: Int? = nil
    @State private var isReordering = false
    @State private var cardFrames: [AppModule: CGRect] = [:]
    @State private var children: [PSChild] = []
    @State private var isLoadingChildren = false
    @State private var showAddChild = false
    @State private var scrollDisabled = false
    @State private var cardWidth: CGFloat = 0

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(widgetOrder, id: \.self) { module in
                        WidgetCard(
                            module: module,
                            children: children,
                            onAddChild: module == .pointSystem ? { showAddChild = true } : nil,
                            onChildTapped: module == .pointSystem ? onChildTapped : nil,
                            onGripDragChanged: { drag in handleGripDragChanged(drag, for: module) },
                            onGripDragEnded: { handleGripDragEnded(for: module) }
                        )
                        .opacity(draggingModule == module ? 0.0 : 1.0)
                        .onGeometryChange(for: CGRect.self, of: { geo in
                            geo.frame(in: .named("dashboard"))
                        }) { frame in
                            cardFrames[module] = frame
                        }
                    }
                }
                .padding(16)
            }
            .scrollDisabled(scrollDisabled)
            .task { await loadChildren() }
            .onReceive(NotificationCenter.default.publisher(for: .pointEventDidChange)) { _ in
                Task { await loadChildren() }
            }
            .onAppear { loadWidgetOrder() }
            .onChange(of: widgetOrder) { _, _ in
                guard draggingModule == nil else { return }
                saveWidgetOrder()
            }
            .navigationDestination(isPresented: $showAddChild) {
                AddChildView(familyId: membership.familyId) { children.append($0) }
            }

            // Floating card — follows the finger during drag
            if let module = draggingModule {
                WidgetCard(
                    module: module,
                    children: children,
                    onAddChild: nil,
                    onChildTapped: nil
                )
                .frame(width: cardWidth)
                .scaleEffect(1.04)
                .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
                .position(x: liftOrigin.midX + dragOffset.width, y: liftOrigin.midY + dragOffset.height)
                .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: "dashboard")
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { cardWidth = geo.size.width - 32 }
                    .onChange(of: geo.size.width) { cardWidth = geo.size.width - 32 }
            }
        )
    }

    // MARK: - Children

    private func loadChildren() async {
        isLoadingChildren = true
        children = (try? await PointSystemService.fetchChildren(familyId: membership.familyId)) ?? []
        isLoadingChildren = false
    }

    // MARK: - Gesture

    private func handleGripDragChanged(_ drag: DragGesture.Value, for module: AppModule) {
        if draggingModule == nil {
            liftOrigin = cardFrames[module] ?? .zero
            scrollDisabled = true
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                draggingModule = module
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        dragOffset = drag.translation
        updateDropPosition(for: module)
    }

    private func handleGripDragEnded(for module: AppModule) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            draggingModule = nil
            dragOffset = .zero
        }
        liftOrigin = .zero
        lastHoverIndex = nil
        isReordering = false
        scrollDisabled = false
        saveWidgetOrder()
    }

    private func updateDropPosition(for module: AppModule) {
        guard !isReordering else { return }
        guard let fromIndex = widgetOrder.firstIndex(of: module) else { return }
        let floatingMidY = liftOrigin.midY + dragOffset.height

        // Count non-dragging cards whose center is above the floating card's center.
        // That count is the target slot index in the final order.
        var newIndex = 0
        for m in widgetOrder where m != module {
            guard let frame = cardFrames[m] else { continue }
            if floatingMidY > frame.midY { newIndex += 1 }
        }

        guard newIndex != lastHoverIndex else { return }
        lastHoverIndex = newIndex

        isReordering = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            widgetOrder.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: newIndex > fromIndex ? newIndex + 1 : newIndex
            )
        }
        let capturedModule = module
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if draggingModule == capturedModule { isReordering = false }
        }
    }

    // MARK: - Persistence

    private var orderKey: String { "dashboardWidgetOrder_\(membership.familyId)" }

    private func loadWidgetOrder() {
        let active = AppModule.allCases.filter {
            $0.isToggleActive && ($0.isMandatory || membership.roleKeywords.contains($0.rawValue))
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
    var children: [PSChild] = []
    var onAddChild: (() -> Void)? = nil
    var onChildTapped: ((PSChild) -> Void)? = nil
    var onGripDragChanged: ((DragGesture.Value) -> Void)? = nil
    var onGripDragEnded: (() -> Void)? = nil
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(module.iconBadgeColor)
                        .frame(width: 28, height: 28)
                    Image(systemName: module.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(module.iconTintColor)
                }
                Text(module.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if onGripDragChanged != nil {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(coordinateSpace: .named("dashboard"))
                                .onChanged { onGripDragChanged?($0) }
                                .onEnded { _ in onGripDragEnded?() }
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            cardBody
        }
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var cardBody: some View {
        if module == .pointSystem {
            if children.isEmpty {
                PointSystemEmptyState(onAddChild: onAddChild ?? {})
            } else {
                PointSystemChildrenList(children: children, onAddChild: onAddChild ?? {}, onChildTapped: onChildTapped)
            }
        } else {
            Text("Coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        }
    }
}

// MARK: - Point System Widget Content

private struct PointSystemEmptyState: View {
    let onAddChild: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "star.fill")
                .font(.system(size: 30))
                .foregroundStyle(.orange)

            Text("Track points for your kids")
                .font(.subheadline)
                .foregroundStyle(.primary)

            Text("Add a child to get started")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: onAddChild) {
                Label("Add Child", systemImage: "person.badge.plus")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(PointSystemStyle.addTint)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

private struct PointSystemChildrenList: View {
    let children: [PSChild]
    let onAddChild: () -> Void
    var onChildTapped: ((PSChild) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            ForEach(children) { child in
                Button {
                    onChildTapped?(child)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(
                                LinearGradient(
                                    colors: child.gender.gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            Text(child.gender.avatarEmoji)
                                .font(.system(size: 16))
                        }
                        .frame(width: 36, height: 36)

                        Text(verbatim: child.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("\(child.balance, format: .number) pts")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(child.gender.tintColor)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(.systemGray3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 64)
            }

            Button(action: onAddChild) {
                HStack(spacing: 12) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16))
                        .foregroundStyle(PointSystemStyle.addTint)
                        .frame(width: 36, height: 36)
                    Text("Add Child")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - AppModule widget theme (view-layer only)

private extension AppModule {
    var iconBadgeColor: Color {
        switch self {
        case .familyTodo:  return Color(red: 74/255,  green: 85/255,  blue: 204/255).opacity(0.20)
        case .pointSystem: return Color(red: 58/255,  green: 123/255, blue: 213/255).opacity(0.20)
        case .familyNotes: return Color(red: 192/255, green: 122/255, blue: 8/255).opacity(0.20)
        case .orderFromMe: return Color(red: 26/255,  green: 144/255, blue: 144/255).opacity(0.20)
        }
    }

    var iconTintColor: Color {
        switch self {
        case .familyTodo:  return Color(red: 123/255, green: 134/255, blue: 232/255)
        case .pointSystem: return Color(red: 91/255,  green: 168/255, blue: 245/255)
        case .familyNotes: return Color(red: 232/255, green: 168/255, blue: 40/255)
        case .orderFromMe: return Color(red: 56/255,  green: 196/255, blue: 184/255)
        }
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
