import SwiftUI

struct FamilyTodoCard: View {
    let todo: FamilyTodo
    let onComplete: () -> Void
    let onReactivate: () -> Void
    let onDelete: () -> Void

    @Binding var swipeOffset: CGFloat
    @State private var descriptionExpanded = false
    @Environment(\.appTheme) private var theme

    private let deleteRevealWidth: CGFloat = 76
    private var isCompleted: Bool { todo.completedAt != nil }

    var body: some View {
        ZStack(alignment: .trailing) {
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

            cardBody
                .offset(x: swipeOffset)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            let dx = value.translation.width
                            if dx < 0 {
                                swipeOffset = max(dx, -deleteRevealWidth)
                            } else if swipeOffset < 0 {
                                swipeOffset = min(0, swipeOffset + dx)
                            }
                        }
                        .onEnded { value in
                            let velocity = value.predictedEndTranslation.width
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if swipeOffset < -(deleteRevealWidth / 2) || velocity < -100 {
                                    swipeOffset = -deleteRevealWidth
                                } else {
                                    swipeOffset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
    }

    private var cardBody: some View {
        HStack(alignment: .top, spacing: 12) {
            checkboxButton
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { descriptionExpanded.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(todo.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(isCompleted ? .secondary : .primary)
                            .strikethrough(isCompleted)
                        Spacer()
                        priorityBadge
                    }
                    if let desc = todo.description {
                        Text(desc)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(descriptionExpanded ? nil : 2)
                    }
                    if let loc = todo.location {
                        Label(loc, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    dueDateRow
                    if isCompleted, let name = todo.completedByDisplayName {
                        Text(String(format: NSLocalizedString("family_todo_completed_by", comment: ""), name))
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(theme.cardBorder, lineWidth: 1)
                }
        }
    }

    private var checkboxButton: some View {
        Button {
            if isCompleted { onReactivate() } else { onComplete() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCompleted ? theme.primaryAccent : Color.clear)
                    .overlay {
                        if !isCompleted {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(theme.cardBorder, lineWidth: 1.5)
                        }
                    }
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var priorityBadge: some View {
        switch todo.priority {
        case "high":
            Text("高")
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Color.red.opacity(0.12))
                .foregroundStyle(Color.red)
                .clipShape(Capsule())
        case "medium":
            Text("中")
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Color.blue.opacity(0.12))
                .foregroundStyle(Color.blue)
                .clipShape(Capsule())
        default:
            Text("低")
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .foregroundStyle(Color.secondary)
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var dueDateRow: some View {
        if let dueAt = todo.dueAt {
            let dueDate = Date(timeIntervalSince1970: TimeInterval(dueAt))
            let now = Date()
            if !isCompleted && dueDate < now {
                Label(NSLocalizedString("family_todo_overdue", comment: ""), systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.red)
            } else {
                let cal = Calendar.current
                let isToday = cal.isDateInToday(dueDate)
                if isToday {
                    let formatter: DateFormatter = {
                        let f = DateFormatter()
                        f.locale = Locale(identifier: "en_US_POSIX")
                        f.dateFormat = "HH:mm"
                        return f
                    }()
                    Label("\(NSLocalizedString("family_todo_due_today", comment: "")) · \(formatter.string(from: dueDate))", systemImage: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.primaryAccent)
                } else {
                    let displayFormatter: DateFormatter = {
                        let f = DateFormatter()
                        f.locale = .current
                        f.setLocalizedDateFormatFromTemplate("MMMd")
                        return f
                    }()
                    Label(displayFormatter.string(from: dueDate), systemImage: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
