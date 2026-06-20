import SwiftUI

struct FamilyTodoWidget: View {
    let familyId: Int
    let onViewAll: () -> Void

    @State private var store = FamilyTodoStore()
    @Environment(\.appTheme) private var theme

    private var familyTasks:    [FamilyTodo] { Array(store.active.filter { $0.todoType == "family" }.prefix(2)) }
    private var personalTasks:  [FamilyTodo] { Array(store.active.filter { $0.todoType == "personal" }.prefix(2)) }
    private var familyOverflow:  Int { max(0, store.active.filter { $0.todoType == "family" }.count - 2) }
    private var personalOverflow: Int { max(0, store.active.filter { $0.todoType == "personal" }.count - 2) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !familyTasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FAMILY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .kerning(0.8)
                    ForEach(familyTasks) { todo in
                        WidgetTaskRow(
                            todo: todo,
                            onComplete: { Task { await store.complete(todoId: todo.id) } }
                        )
                    }
                    if familyOverflow > 0 {
                        Button("+\(familyOverflow) more") { onViewAll() }
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .buttonStyle(.plain)
                    }
                }
            }

            if !personalTasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("个人")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .kerning(0.8)
                    ForEach(personalTasks) { todo in
                        WidgetTaskRow(
                            todo: todo,
                            onComplete: { Task { await store.complete(todoId: todo.id) } }
                        )
                    }
                    if personalOverflow > 0 {
                        Button("+\(personalOverflow) more") { onViewAll() }
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .buttonStyle(.plain)
                    }
                }
            }

            if familyTasks.isEmpty && personalTasks.isEmpty {
                Text(NSLocalizedString("family_todo_empty_title", comment: ""))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }

            Divider()

            Button {
                onViewAll()
            } label: {
                HStack {
                    Spacer()
                    Text(String(format: NSLocalizedString("family_todo_widget_view_all", comment: ""), store.active.count))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.primaryAccent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.primaryAccent)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .task { await store.load(familyId: familyId) }
    }
}

// MARK: - Widget task row

private struct WidgetTaskRow: View {
    let todo: FamilyTodo
    let onComplete: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button { onComplete() } label: {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(theme.cardBorder, lineWidth: 1.5)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            HStack {
                Text(todo.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer()
                priorityBadge
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var priorityBadge: some View {
        let label = todo.priority == "high" ? "高" : (todo.priority == "medium" ? "中" : "低")
        let fg: Color = todo.priority == "high" ? .red : (todo.priority == "medium" ? .blue : .secondary)
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(fg.opacity(0.12))
            .foregroundStyle(fg)
            .clipShape(Capsule())
    }

}
