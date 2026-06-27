import SwiftUI

struct FamilyTodoView: View {
    let familyId: Int
    @State private var store = FamilyTodoStore()
    @State private var filter: String = "all"
    @State private var swipeOffsets: [Int: CGFloat] = [:]
    @State private var showCreate: Bool = false
    @State private var createDetent: PresentationDetent = .height(560)
    @State private var editingTodo: FamilyTodo? = nil
    @State private var editDetent: PresentationDetent = .height(560)
    @State private var completedExpanded: Bool = false
    @Environment(\.appTheme) private var theme

    private func swipeBinding(for id: Int) -> Binding<CGFloat> {
        Binding(get: { swipeOffsets[id] ?? 0 }, set: { swipeOffsets[id] = $0 })
    }

    private var filteredActive: [FamilyTodo] {
        switch filter {
        case "family":   return store.active.filter { $0.todoType == "family" }
        case "personal": return store.active.filter { $0.todoType == "personal" }
        default:         return store.active
        }
    }

    var body: some View {
        ZStack {
            theme.pageBg.ignoresSafeArea()

            if store.isLoading && store.active.isEmpty {
                ProgressView()
            } else if let err = store.loadError {
                VStack(spacing: 12) {
                    Text(err).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button(NSLocalizedString("重试", comment: "")) {
                        Task { await store.load(familyId: familyId) }
                    }
                    .foregroundStyle(theme.primaryAccent)
                }
                .padding()
            } else {
                mainContent
            }
        }
        .task { await store.load(familyId: familyId) }
        .onReceive(NotificationCenter.default.publisher(for: .familyTodoDidChange)) { _ in
            Task { await store.load(familyId: familyId) }
        }
        .sheet(isPresented: $showCreate) {
            CreateFamilyTodoSheet(store: store, detent: $createDetent)
                .presentationDetents([.height(560), .height(680)], selection: $createDetent)
                .presentationDragIndicator(.visible)
                .onDisappear { createDetent = .height(560) }
        }
        .sheet(item: $editingTodo) { todo in
            CreateFamilyTodoSheet(store: store, detent: $editDetent, existingTodo: todo)
                .presentationDetents([.height(560), .height(680)], selection: $editDetent)
                .presentationDragIndicator(.visible)
                .onDisappear { editDetent = .height(560) }
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    filterPills
                    Spacer()
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(theme.primaryAccent)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if store.active.isEmpty && store.completed.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredActive) { todo in
                        SwipableCard(
                            todo: todo,
                            onComplete: { Task { await store.complete(todoId: todo.id) } },
                            onReactivate: { Task { await store.reactivate(todoId: todo.id) } },
                            onEdit: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    swipeOffsets[todo.id] = 0
                                }
                                editingTodo = todo
                            },
                            onDelete: { Task { await store.delete(todoId: todo.id) } },
                            onStartSwipe: {
                                let id = todo.id
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    for key in swipeOffsets.keys where key != id { swipeOffsets[key] = 0 }
                                }
                            },
                            swipeOffset: swipeBinding(for: todo.id)
                        )
                        .padding(.horizontal, 16)
                        .transition(.opacity)
                    }

                    if !store.completed.isEmpty {
                        completedSection
                    }
                }
            }
            .padding(.bottom, 24)
            .animation(.easeInOut(duration: 0.22), value: filteredActive.map(\.id))
            .animation(.easeInOut(duration: 0.22), value: store.completed.map(\.id))
        }
    }

    private var filterPills: some View {
        HStack(spacing: 6) {
            ForEach([("all", "family_todo_filter_all"), ("family", "family_todo_filter_family"), ("personal", "family_todo_filter_personal")], id: \.0) { value, key in
                Button(NSLocalizedString(key, comment: "")) { swipeOffsets = [:]; filter = value }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(filter == value ? theme.primaryAccent : Color(.systemBackground))
                    .foregroundStyle(filter == value ? Color.white : Color.secondary)
                    .clipShape(Capsule())
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(theme.primaryAccent.opacity(0.12))
                    .frame(width: 72, height: 72)
                Text("✅").font(.system(size: 32))
            }
            Text(NSLocalizedString("family_todo_empty_title", comment: ""))
                .font(.system(size: 17, weight: .semibold))
            Text(NSLocalizedString("family_todo_empty_subtitle", comment: ""))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var completedSection: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation { completedExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: completedExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(NSLocalizedString("family_todo_completed_section", comment: ""))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("[\(store.completed.count)]")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)

            if completedExpanded {
                ForEach(store.completed) { todo in
                    SwipableCard(
                        todo: todo,
                        onComplete: {},
                        onReactivate: { Task { await store.reactivate(todoId: todo.id) } },
                        onEdit: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                swipeOffsets[todo.id] = 0
                            }
                            editingTodo = todo
                        },
                        onDelete: { Task { await store.delete(todoId: todo.id) } },
                        onStartSwipe: {
                            let id = todo.id
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                for key in swipeOffsets.keys where key != id { swipeOffsets[key] = 0 }
                            }
                        },
                        swipeOffset: swipeBinding(for: todo.id)
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

// MARK: - Swipe-to-delete/edit wrapper (FamilyTodoView only)

private struct SwipableCard: View {
    let todo: FamilyTodo
    let onComplete: () -> Void
    let onReactivate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onStartSwipe: () -> Void
    @Binding var swipeOffset: CGFloat

    private let editRevealWidth: CGFloat = 72
    private let deleteRevealWidth: CGFloat = 76
    private var totalRevealWidth: CGFloat { editRevealWidth + deleteRevealWidth + 4 }

    private var buttonOpacity: Double {
        Double(min(1, max(0, -swipeOffset / (totalRevealWidth * 0.4))))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 4) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { swipeOffset = 0 }
                    onEdit()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .medium))
                        Text(NSLocalizedString("family_todo_edit_action", comment: ""))
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .frame(width: editRevealWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { swipeOffset = 0 }
                    onDelete()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                        Text(NSLocalizedString("Delete", comment: ""))
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .frame(width: deleteRevealWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .opacity(buttonOpacity)

            FamilyTodoCard(todo: todo, onComplete: onComplete, onReactivate: onReactivate)
                .offset(x: swipeOffset)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            let dx = value.translation.width
                            if dx < 0 {
                                onStartSwipe()
                                swipeOffset = max(dx, -totalRevealWidth)
                            } else if swipeOffset < 0 {
                                swipeOffset = min(0, swipeOffset + dx)
                            }
                        }
                        .onEnded { value in
                            let velocity = value.predictedEndTranslation.width
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if swipeOffset < -(totalRevealWidth / 2) || velocity < -100 {
                                    swipeOffset = -totalRevealWidth
                                } else {
                                    swipeOffset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
    }
}
