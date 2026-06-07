import SwiftUI

// MARK: - PointSystemView

struct PointSystemView: View {
    let membership: FamilyMembership
    var onLogOut: () -> Void = {}
    var initialChildId: Int? = nil

    @State private var children: [PSChild] = []
    @State private var selectedIndex: Int = 0
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var navigateToAddChild = false
    @State private var childToEdit: PSChild? = nil
    @State private var childToDelete: PSChild? = nil
    @State private var showDeleteConfirm = false

    private var safeIndex: Int { min(selectedIndex, max(0, children.count - 1)) }
    private var selectedChild: PSChild? { children.isEmpty ? nil : children[safeIndex] }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if let msg = errorMessage {
                    errorView(msg)
                } else {
                    memberGridSection
                    if let child = selectedChild {
                        ChildCardView(
                            child: child,
                            familyId: membership.familyId,
                            onBalanceChange: { newBalance in
                                if let idx = children.firstIndex(where: { $0.memberId == child.memberId }) {
                                    children[idx].balance = newBalance
                                }
                            },
                            onLogOut: onLogOut,
                            onEdit: { childToEdit = child },
                            onDelete: { childToDelete = child; showDeleteConfirm = true }
                        )
                        .id(child.id)

                        GoalProgressSection(
                            child: child,
                            familyId: membership.familyId,
                            onLogOut: onLogOut
                        )
                        .id("goals-\(child.id)")

                        ActivitySection(
                            child: child,
                            familyId: membership.familyId,
                            onBalanceChange: { newBalance in
                                if let idx = children.firstIndex(where: { $0.memberId == child.memberId }) {
                                    children[idx].balance = newBalance
                                }
                            }
                        )
                        .id("activity-\(child.id)-\(child.balance)")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationDestination(isPresented: $navigateToAddChild) {
            AddChildView(familyId: membership.familyId) { newChild in
                children.append(newChild)
                selectedIndex = children.count - 1
            }
        }
        .navigationDestination(item: $childToEdit) { child in
            AddChildView(familyId: membership.familyId, existingChild: child) { updated in
                if let idx = children.firstIndex(where: { $0.memberId == updated.memberId }) {
                    children[idx] = updated
                }
            }
        }
        .overlay {
            if showDeleteConfirm, let child = childToDelete {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    deleteConfirmCard(child)
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .center)))
                }
            }
        }
        .animation(.easeOut(duration: 0.22), value: showDeleteConfirm)
        .task { await loadChildren() }
        .onChange(of: children) { _, newValue in
            if selectedIndex >= newValue.count {
                selectedIndex = max(0, newValue.count - 1)
            }
        }
    }

    @ViewBuilder
    private func deleteConfirmCard(_ child: PSChild) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: String(localized: "Delete %@?"), child.name))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                Text("This will permanently remove all points, goals, and history for this child.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Button {
                    showDeleteConfirm = false
                    Task { await performDeleteChild(child) }
                } label: {
                    Text("Delete")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button { showDeleteConfirm = false } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
        .frame(maxWidth: 320)
        .padding(.horizontal, 24)
    }

    private var memberGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Family Members")
                .font(.system(size: PointSystemStyle.sectionHeaderFontSize, weight: .bold))
                .foregroundStyle(.primary)

            if children.isEmpty {
                Text("Add your first child to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: PointSystemStyle.memberGridColumns)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    MemberAvatarCell(
                        child: child,
                        isSelected: index == safeIndex
                    ) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedIndex = index
                        }
                    }
                }
                Button { navigateToAddChild = true } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .foregroundStyle(Color(.systemGray3))
                                .frame(width: PointSystemStyle.memberAvatarSize,
                                       height: PointSystemStyle.memberAvatarSize)
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color(.systemGray3))
                        }
                        Text("New")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(.systemGray3))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add new child")
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Text(verbatim: msg)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") {
                Task { await loadChildren() }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func performDeleteChild(_ child: PSChild) async {
        do {
            try await PointSystemService.deleteChild(familyId: membership.familyId, memberId: child.memberId)
            children.removeAll { $0.memberId == child.memberId }
        } catch {
            // Network error — child stays in list, user can retry
        }
    }

    private func loadChildren() async {
        isLoading = true
        errorMessage = nil
        do {
            children = try await PointSystemService.fetchChildren(familyId: membership.familyId)
            if let childId = initialChildId,
               let idx = children.firstIndex(where: { $0.memberId == childId }) {
                selectedIndex = idx
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - MemberAvatarCell

private struct MemberAvatarCell: View {
    let child: PSChild
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 2.5)
                        .frame(width: PointSystemStyle.memberAvatarSize + 6,
                               height: PointSystemStyle.memberAvatarSize + 6)
                        .opacity(isSelected ? 1 : 0)
                    Circle().fill(
                        LinearGradient(
                            colors: child.gender.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: PointSystemStyle.memberAvatarSize,
                           height: PointSystemStyle.memberAvatarSize)
                    Text(child.gender.avatarEmoji)
                        .font(.system(size: 28))
                }
                Text(verbatim: child.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

// MARK: - ChildCardView

private struct ChildCardView: View {
    let child: PSChild
    let familyId: Int
    let onBalanceChange: (Int) -> Void
    let onLogOut: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private enum Sheet: Int, Identifiable {
        case deduct = 0
        case reward = 1
        var id: Int { rawValue }
    }

    @State private var activeSheet: Sheet? = nil
    @State private var showChildMenu = false
    @State private var menuVisible = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(
                            LinearGradient(
                                colors: child.gender.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: PointSystemStyle.childCardAvatarSize,
                               height: PointSystemStyle.childCardAvatarSize)
                        Text(child.gender.avatarEmoji)
                            .font(.system(size: 24))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(verbatim: child.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Button {
                                var t = Transaction()
                                t.disablesAnimations = true
                                withTransaction(t) { showChildMenu = true }
                            } label: {
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 5)
                                    .background(Color(.systemGray5), in: Circle())
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        if let age = ageString() {
                            Text(verbatim: age)
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(child.balance, format: .number)
                        .font(.system(size: PointSystemStyle.pointsDisplayFontSize, weight: .heavy))
                        .foregroundStyle(Color.accentColor)
                        .contentTransition(.numericText())
                    Text("points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    activeSheet = .deduct
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Redeem")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: PointSystemStyle.actionButtonHeight)
                    .background(Color(.systemGray6))
                    .foregroundStyle(child.balance <= 0 ? Color(.systemGray3) : .primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(child.balance <= 0)

                Button {
                    activeSheet = .reward
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Reward")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: PointSystemStyle.actionButtonHeight)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(PointSystemStyle.childCardPadding)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: PointSystemStyle.childCardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PointSystemStyle.childCardCornerRadius)
                .strokeBorder(Color(.systemGray4), lineWidth: PointSystemStyle.childCardBorderWidth)
        )
        .sheet(item: $activeSheet) { sheet in
            PointAdjustFormView(
                style: sheet == .reward ? .add : .deduct,
                familyId: familyId,
                memberId: child.memberId,
                balance: sheet == .deduct ? child.balance : nil,
                onSuccess: { newBalance in
                    onBalanceChange(newBalance)
                    activeSheet = nil
                },
                onLogOut: onLogOut,
                onDismiss: { activeSheet = nil }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(isPresented: $showChildMenu) {
            childActionSheet
                .presentationBackground(.clear)
        }
    }

    private static let birthdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func ageString() -> String? {
        guard let birthday = child.birthday,
              let date = Self.birthdayFormatter.date(from: birthday) else { return nil }
        let years = Calendar.current.dateComponents([.year], from: date, to: .now).year ?? 0
        return String(format: String(localized: "%d years old"), years)
    }

    private func dismissMenu(then action: (() -> Void)? = nil) {
        withAnimation(.easeIn(duration: 0.2)) { menuVisible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { showChildMenu = false }
            action?()
        }
    }

    @ViewBuilder
    private var childActionSheet: some View {
        ZStack(alignment: .bottom) {
            Color.black
                .opacity(menuVisible ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismissMenu() }

            VStack(spacing: 8) {
                VStack(spacing: 0) {
                    Button {
                        dismissMenu {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { onEdit() }
                        }
                    } label: {
                        Text("Edit")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.accentColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 57)
                    }
                    .buttonStyle(.plain)
                    Divider()
                    Button {
                        dismissMenu {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { onDelete() }
                        }
                    } label: {
                        Text("Delete")
                            .font(.system(size: 17))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 57)
                    }
                    .buttonStyle(.plain)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button { dismissMenu() } label: {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 57)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .offset(y: menuVisible ? 0 : 300)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.28)) { menuVisible = true }
        }
    }


}

// MARK: - GoalProgressSection

private struct GoalProgressSection: View {
    let child: PSChild
    let familyId: Int
    let onLogOut: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    @State private var goals: [PSGoal] = []
    @State private var isLoading = false
    @State private var lastLoadedDate: String = ""
    @State private var showCreateGoal = false
    @State private var goalSheetDetent: PresentationDetent = .height(510)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress to Goal")
                    .font(.system(size: PointSystemStyle.sectionHeaderFontSize, weight: .bold))
                Spacer()
                Button {
                    showCreateGoal = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add goal")
            }

            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if goals.isEmpty {
                Text("Create your first goal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(goals) { goal in
                        GoalRow(goal: goal) {
                            Task { await deleteGoal(goal) }
                        }
                    }
                }
            }
        }
        .task { await loadGoals() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            Task { await loadGoals() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && localDateString() != lastLoadedDate {
                Task { await loadGoals() }
            }
        }
        .onChange(of: child.balance) { _, _ in Task { await loadGoals() } }
        .sheet(isPresented: $showCreateGoal, onDismiss: { goalSheetDetent = .height(510) }) {
            CreateGoalSheet(
                familyId: familyId,
                memberId: child.memberId,
                detent: $goalSheetDetent,
                onSuccess: { goal in
                    goals.append(goal)
                    showCreateGoal = false
                },
                onCancel: { showCreateGoal = false },
                onLogOut: onLogOut
            )
            .presentationDetents([.height(510), .height(730)], selection: $goalSheetDetent)
            .presentationDragIndicator(.visible)
        }
    }

    private func loadGoals() async {
        isLoading = true
        if let fetched = try? await PointSystemService.fetchGoals(familyId: familyId, memberId: child.memberId) {
            goals = fetched
        }
        lastLoadedDate = localDateString()
        isLoading = false
    }

    private func deleteGoal(_ goal: PSGoal) async {
        do {
            try await PointSystemService.deleteGoal(familyId: familyId, goalId: goal.goalId)
            goals.removeAll { $0.goalId == goal.goalId }
        } catch {
            // Server delete failed — keep item in list, user can retry
        }
    }
}

// MARK: - GoalRow

private struct GoalRow: View {
    let goal: PSGoal
    let onDelete: () -> Void

    @State private var cardScale: CGFloat = 1.0

    private var isFulfilled: Bool { goal.periodProgress >= goal.targetPoints && goal.targetPoints > 0 }

    private var progress: Double {
        guard goal.targetPoints > 0 else { return 0 }
        return max(0.0, min(1.0, Double(goal.periodProgress) / Double(goal.targetPoints)))
    }

    private var periodLabel: String {
        switch goal.goalLifespan {
        case .daily:   return String(localized: "Today")
        case .weekly:  return String(localized: "This week")
        case .monthly: return String(localized: "This month")
        case .oneTime:
            guard let start = goal.startDate, let end = goal.endDate else { return "" }
            let parser = DateFormatter()
            parser.locale = Locale(identifier: "en_US_POSIX")
            parser.dateFormat = "yyyy-MM-dd"
            let display = DateFormatter()
            display.locale = Locale.current
            display.setLocalizedDateFormatFromTemplate("MMMd")
            guard let sd = parser.date(from: start), let ed = parser.date(from: end) else { return "\(start) – \(end)" }
            return "\(display.string(from: sd)) – \(display.string(from: ed))"
        case nil: return ""
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(verbatim: goal.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(goal.periodProgress)/\(goal.targetPoints)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isFulfilled ? Color(red: 22/255, green: 163/255, blue: 74/255) : Color.accentColor)
            }
            if let lifespan = goal.goalLifespan, !periodLabel.isEmpty || isFulfilled {
                HStack(spacing: 4) {
                    if let lifespan = goal.goalLifespan, !periodLabel.isEmpty {
                        Image(systemName: lifespan.icon)
                            .font(.system(size: 10))
                        Text(verbatim: periodLabel)
                            .font(.system(size: 11))
                    }
                    Spacer()
                    if isFulfilled {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                            Text("Goal reached!")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color(red: 34/255, green: 197/255, blue: 94/255))
                        .clipShape(Capsule())
                    }
                }
                .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                        .frame(height: PointSystemStyle.goalProgressHeight)
                    Capsule()
                        .fill(isFulfilled ? Color(red: 34/255, green: 197/255, blue: 94/255) : Color.accentColor)
                        .frame(width: geo.size.width * progress,
                               height: PointSystemStyle.goalProgressHeight)
                        .animation(.easeOut(duration: 0.6), value: progress)
                }
            }
            .frame(height: PointSystemStyle.goalProgressHeight)
        }
        .padding(16)
        .background(isFulfilled ? Color(red: 240/255, green: 253/255, blue: 244/255) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isFulfilled ? Color(red: 187/255, green: 247/255, blue: 208/255) : Color(.systemGray4), lineWidth: isFulfilled ? 1.5 : 1)
        )
        .scaleEffect(cardScale)
        .onAppear {
            guard isFulfilled else { return }
            cardScale = 1.0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                cardScale = 1.04
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    cardScale = 1.0
                }
            }
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - CreateGoalSheet

private struct CreateGoalSheet: View {
    let familyId: Int
    let memberId: Int
    @Binding var detent: PresentationDetent
    let onSuccess: (PSGoal) -> Void
    let onCancel: () -> Void
    let onLogOut: () -> Void

    @State private var name = ""
    @State private var targetText = ""
    @State private var selectedLifespan: GoalLifespan? = nil
    @State private var startDate = Date()
    @State private var startTime = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var endTime = Date()
    @State private var isCreating = false
    @State private var errorMessage: String? = nil

    private var targetPoints: Int? { Int(targetText).flatMap { $0 > 0 ? $0 : nil } }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && targetPoints != nil
        && selectedLifespan != nil
        && (selectedLifespan != .oneTime || endDate > startDate)
    }

    private static let cr: CGFloat        = PointSystemStyle.formConfirmCornerRadius
    private static let fieldBg            = Color(red: 245/255, green: 242/255, blue: 254/255)
    private static let borderColor        = Color(red: 199/255, green: 196/255, blue: 215/255)
    private static let labelColor         = Color(red: 118/255, green: 117/255, blue: 134/255)

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    descriptionField
                    targetField
                    lifespanSection
                    if selectedLifespan == .oneTime {
                        oneTimeSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
                .animation(.easeInOut(duration: 0.3), value: selectedLifespan)
            }
            .scrollBounceBehavior(.basedOnSize)
            sheetFooter
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .onChange(of: selectedLifespan) { _, lifespan in
            withAnimation(.easeInOut(duration: 0.3)) {
                detent = lifespan == .oneTime ? .height(730) : .height(510)
            }
        }
    }

    // MARK: Header

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)
            HStack {
                Text("Create New Goal")
                    .font(.headline.weight(.bold))
                Spacer()
                Button { onCancel() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(.systemGray))
                        .frame(width: 28, height: 28)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            Divider()
        }
    }

    // MARK: Input fields

    private var descriptionField: some View {
        fieldSection(label: "Goal Description") {
            HStack {
                TextField("e.g., Hike on weekends, Watch TV at night", text: $name)
                    .font(.body)
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Self.borderColor)
            }
        }
    }

    private var targetField: some View {
        fieldSection(label: "Goal Target") {
            HStack {
                TextField("e.g., 500 points", text: $targetText)
                    .font(.body)
                    .keyboardType(.numberPad)
                    .onChange(of: targetText) { _, new in
                        let filtered = new.filter(\.isNumber)
                        if filtered != new { targetText = filtered }
                    }
                Image(systemName: "star")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Self.borderColor)
            }
        }
    }

    @ViewBuilder
    private func fieldSection<Content: View>(
        label: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(label)
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Self.fieldBg)
                .clipShape(RoundedRectangle(cornerRadius: Self.cr))
                .overlay(RoundedRectangle(cornerRadius: Self.cr).stroke(Self.borderColor, lineWidth: 1))
        }
    }

    private func fieldLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Self.labelColor)
            .kerning(0.5)
            .textCase(.uppercase)
    }

    // MARK: Lifespan

    private var lifespanSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Goal Lifespan")
            HStack(spacing: 8) {
                ForEach(GoalLifespan.allCases, id: \.self) { lifespan in
                    lifespanButton(lifespan)
                }
            }
        }
    }

    private func lifespanButton(_ lifespan: GoalLifespan) -> some View {
        let isSelected = selectedLifespan == lifespan
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedLifespan = isSelected ? nil : lifespan
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: lifespan.icon)
                    .font(.system(size: 20))
                Text(lifespan.label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isSelected ? .white : Self.labelColor)
            .background(isSelected ? Color.accentColor : Self.fieldBg)
            .clipShape(RoundedRectangle(cornerRadius: Self.cr))
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: Self.cr).stroke(Self.borderColor, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: One-time section

    private var oneTimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            dateGroup(label: "Starts", date: $startDate, time: $startTime)
            dateGroup(label: "Ends",   date: $endDate,   time: $endTime)
        }
        .padding(16)
        .background(Self.fieldBg)
        .clipShape(RoundedRectangle(cornerRadius: Self.cr))
        .overlay(RoundedRectangle(cornerRadius: Self.cr).stroke(Self.borderColor, lineWidth: 1))
    }

    private func dateGroup(label: LocalizedStringKey, date: Binding<Date>, time: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(label)
            HStack(spacing: 10) {
                datePickerField(date, components: .date,          icon: "calendar")
                datePickerField(time, components: .hourAndMinute, icon: "clock")
            }
        }
    }

    private func datePickerField(_ binding: Binding<Date>, components: DatePickerComponents, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Self.labelColor)
            DatePicker("", selection: binding, displayedComponents: components)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color.accentColor)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Self.cr))
        .overlay(RoundedRectangle(cornerRadius: Self.cr).stroke(Self.borderColor, lineWidth: 1))
    }

    // MARK: Footer

    private var sheetFooter: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 8) {
                Button { save() } label: {
                    Group {
                        if isCreating {
                            ProgressView().tint(.white)
                        } else {
                            Text("Create Goal")
                                .font(.body.weight(.bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canSave ? Color.accentColor : Color(.systemGray4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Self.cr))
                }
                .buttonStyle(.plain)
                .disabled(!canSave || isCreating)

                if let msg = errorMessage {
                    Text(verbatim: msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
    }

    // MARK: Save

    private func save() {
        guard let pts = targetPoints, let lifespan = selectedLifespan, !isCreating else { return }
        isCreating = true
        errorMessage = nil
        var startStr: String? = nil
        var endStr: String?   = nil
        if lifespan == .oneTime {
            startStr = localDateString(from: startDate)
            endStr   = localDateString(from: endDate)
        }
        Task {
            do {
                let goal = try await PointSystemService.createGoal(
                    familyId: familyId,
                    memberId: memberId,
                    name: name.trimmingCharacters(in: .whitespaces),
                    targetPoints: pts,
                    lifespan: lifespan,
                    startDate: startStr,
                    endDate: endStr
                )
                isCreating = false
                onSuccess(goal)
            } catch PointSystemError.unauthorized {
                isCreating = false
                onLogOut()
            } catch {
                isCreating = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - ActivitySection

private struct ActivitySection: View {
    let child: PSChild
    let familyId: Int
    let onBalanceChange: (Int) -> Void

    @State private var activities: [PSActivity] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = false
    @State private var loadError: String? = nil
    private let pageSize = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activities")
                .font(.system(size: PointSystemStyle.sectionHeaderFontSize, weight: .bold))

            if isLoading && activities.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            } else if let err = loadError {
                Text(verbatim: err)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else if activities.isEmpty {
                Text("No activity yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                        ActivityRow(activity: activity) {
                            Task { await deleteActivity(activity) }
                        }
                        if index < activities.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(.systemGray4), lineWidth: 1))

                if hasMore {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        Group {
                            if isLoadingMore {
                                ProgressView()
                            } else {
                                Text("More")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingMore)
                }
            }
        }
        .task { await loadActivities() }
    }

    private func loadActivities() async {
        isLoading = true
        loadError = nil
        do {
            let fetched = try await PointSystemService.fetchActivities(
                familyId: familyId, memberId: child.memberId, limit: pageSize, offset: 0
            )
            activities = fetched
            hasMore = fetched.count == pageSize
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let fetched = try await PointSystemService.fetchActivities(
                familyId: familyId, memberId: child.memberId, limit: pageSize, offset: activities.count
            )
            activities.append(contentsOf: fetched)
            hasMore = fetched.count == pageSize
        } catch {
            // Keep existing entries on load-more failure
        }
        isLoadingMore = false
    }

    private func deleteActivity(_ activity: PSActivity) async {
        do {
            try await PointSystemService.deleteActivity(familyId: familyId, eventId: activity.eventId)
            activities.removeAll { $0.eventId == activity.eventId }
            let newBalance = child.balance - activity.delta
            onBalanceChange(newBalance)
        } catch {
            // Server delete failed — keep item in list
        }
    }
}

// MARK: - ActivityRow

private struct ActivityRow: View {
    let activity: PSActivity
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(activity.isPositive ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                .frame(width: PointSystemStyle.activityIconSize, height: PointSystemStyle.activityIconSize)
                .overlay(
                    Image(systemName: activity.isPositive ? "star.fill" : "minus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(activity.isPositive ? .green : .red)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: activity.note ?? (activity.isPositive
                    ? String(localized: "Points added")
                    : String(localized: "Points redeemed")))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(verbatim: activity.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(verbatim: activity.deltaText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(activity.isPositive ? .green : .red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Legacy (preserved for reuse)

// MARK: - ChildTabBar

private struct ChildTabBar: View {
    let children: [PSChild]
    @Binding var selectedIndex: Int

    var body: some View {
        // ViewThatFits: centered HStack when tabs fit, scrollable when they don't
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { tabButtons }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { tabButtons }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var tabButtons: some View {
        ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedIndex = index
                }
            } label: {
                HStack(spacing: 4) {
                    Text(child.gender.avatarEmoji)
                        .font(.subheadline)
                    Text(verbatim: child.name)
                        .font(.subheadline)
                        .fontWeight(index == selectedIndex ? .semibold : .regular)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    if index == selectedIndex {
                        Capsule().fill(
                            LinearGradient(
                                colors: child.gender.gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    } else {
                        Capsule().fill(Color(.systemGray6))
                    }
                }
                .foregroundStyle(index == selectedIndex ? .white : Color(.label))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - ChildFullView

private struct ChildFullView: View {
    let child: PSChild
    let familyId: Int
    let onBalanceChange: (Int) -> Void
    let onLogOut: () -> Void

    private enum ExpandedRow: Equatable { case add, deduct }

    @State private var expandedRow: ExpandedRow? = nil
    @State private var navigateToRecord = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                childCard
                Color(.systemGray6).frame(height: PointSystemStyle.actionListGap)
                actionList
            }
        }
        .background(Color(.systemBackground))
        .navigationDestination(isPresented: $navigateToRecord) {
            PointRecordView(child: child)
        }
    }

    // MARK: Combined child info + points card

    private var childCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: PointSystemStyle.avatarSize, height: PointSystemStyle.avatarSize)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.85),
                                        lineWidth: PointSystemStyle.avatarBorderWidth)
                    )
                Text(child.gender.avatarEmoji)
                    .font(.system(size: 42))
            }
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: child.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    if let age = ageString() {
                        Text(verbatim: age)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.80))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Points")
                        .font(.caption.uppercaseSmallCaps())
                        .foregroundStyle(.white.opacity(0.75))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(child.balance, format: .number)
                            .font(.system(size: PointSystemStyle.pointsValueFontSize, weight: .heavy))
                            .foregroundStyle(.white)
                        Text("pts")
                            .font(.system(size: PointSystemStyle.pointsUnitFontSize, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            Spacer()
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: child.gender.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // MARK: Action list

    private var actionList: some View {
        VStack(spacing: 0) {
            actionRow(
                icon: "plus",
                iconBackground: PointSystemStyle.addIconBackground,
                label: "Add points",
                row: .add
            )
            Divider()
                .padding(.leading, PointSystemStyle.rowHPadding + PointSystemStyle.rowIconSize + 12)
            actionRow(
                icon: "minus",
                iconBackground: PointSystemStyle.deductIconBackground,
                label: "Redeem",
                row: .deduct
            )
            Divider()
                .padding(.leading, PointSystemStyle.rowHPadding + PointSystemStyle.rowIconSize + 12)
            recordRow
        }
    }

    @ViewBuilder
    private func actionRow(
        icon: String,
        iconBackground: Color,
        label: LocalizedStringKey,
        row: ExpandedRow
    ) -> some View {
        let isOpen = expandedRow == row
        let isDisabled = row == .deduct && child.balance <= 0
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandedRow = isOpen ? nil : row
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: PointSystemStyle.rowIconCornerRadius)
                            .fill(iconBackground)
                            .frame(width: PointSystemStyle.rowIconSize,
                                   height: PointSystemStyle.rowIconSize)
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(label)
                        .font(.body)
                        .foregroundStyle(isDisabled ? Color(.systemGray3) : .primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(Color(.systemGray3))
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .animation(.easeInOut(duration: 0.22), value: isOpen)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, PointSystemStyle.rowHPadding)
                .padding(.vertical, PointSystemStyle.rowVPadding)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            if isOpen {
                PointAdjustFormView(
                    style: row == .add ? .add : .deduct,
                    familyId: familyId,
                    memberId: child.memberId,
                    balance: row == .deduct ? child.balance : nil,
                    onSuccess: { newBalance in
                        onBalanceChange(newBalance)
                        withAnimation(.easeInOut(duration: 0.22)) {
                            expandedRow = nil
                        }
                    },
                    onLogOut: onLogOut
                )
            }
        }
    }

    private var recordRow: some View {
        Button { navigateToRecord = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: PointSystemStyle.rowIconCornerRadius)
                        .fill(PointSystemStyle.recordIconBackground)
                        .frame(width: PointSystemStyle.rowIconSize,
                               height: PointSystemStyle.rowIconSize)
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text("Point records")
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Color(.systemGray3))
            }
            .contentShape(Rectangle())
            .padding(.horizontal, PointSystemStyle.rowHPadding)
            .padding(.vertical, PointSystemStyle.rowVPadding)
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private static let birthdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func ageString() -> String? {
        guard let birthday = child.birthday else { return nil }
        guard let date = Self.birthdayFormatter.date(from: birthday) else { return nil }
        let years = Calendar.current.dateComponents([.year], from: date, to: .now).year ?? 0
        return String(format: String(localized: "%d years old"), years)
    }
}
