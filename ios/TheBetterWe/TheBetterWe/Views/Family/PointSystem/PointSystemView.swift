import SwiftUI

// MARK: - PointSystemView

struct PointSystemView: View {
    let membership: FamilyMembership
    var onLogOut: () -> Void = {}

    @State private var children: [PSChild] = []
    @State private var selectedIndex: Int = 0
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var navigateToAddChild = false

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
                            onLogOut: onLogOut
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
        .task { await loadChildren() }
        .onChange(of: children) { _, newValue in
            if selectedIndex >= newValue.count {
                selectedIndex = max(0, newValue.count - 1)
            }
        }
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

    private func loadChildren() async {
        isLoading = true
        errorMessage = nil
        do {
            children = try await PointSystemService.fetchChildren(familyId: membership.familyId)
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
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color(.systemGray4),
                            lineWidth: isSelected ? PointSystemStyle.memberAvatarBorderWidth + 1 : PointSystemStyle.memberAvatarBorderWidth
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

    private enum Sheet: Int, Identifiable {
        case deduct = 0
        case reward = 1
        var id: Int { rawValue }
    }

    @State private var activeSheet: Sheet? = nil

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.accentColor, lineWidth: PointSystemStyle.memberAvatarBorderWidth)
                            .frame(width: PointSystemStyle.childCardAvatarSize,
                                   height: PointSystemStyle.childCardAvatarSize)
                        Text(child.gender.avatarEmoji)
                            .font(.system(size: 24))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: child.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
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
                        Text("Deduct")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: PointSystemStyle.actionButtonHeight)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

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
}

// MARK: - GoalProgressSection

private struct GoalProgressSection: View {
    let child: PSChild
    let familyId: Int
    let onLogOut: () -> Void

    @State private var goals: [PSGoal] = []
    @State private var isLoading = false
    @State private var showComingSoon = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress to Goal")
                    .font(.system(size: PointSystemStyle.sectionHeaderFontSize, weight: .bold))
                Spacer()
                Button {
                    showComingSoon = true
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
                        GoalRow(goal: goal, currentBalance: child.balance) {
                            Task { await deleteGoal(goal) }
                        }
                    }
                }
            }
        }
        .task { await loadGoals() }
        .sheet(isPresented: $showComingSoon) {
            ComingSoonView { showComingSoon = false }
        }
    }

    private func loadGoals() async {
        isLoading = true
        if let fetched = try? await PointSystemService.fetchGoals(familyId: familyId, memberId: child.memberId) {
            goals = fetched
        }
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
    let currentBalance: Int
    let onDelete: () -> Void

    private var progress: Double {
        guard goal.targetPoints > 0 else { return 0 }
        return min(1.0, Double(currentBalance) / Double(goal.targetPoints))
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(verbatim: goal.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(currentBalance)/\(goal.targetPoints)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                        .frame(height: PointSystemStyle.goalProgressHeight)
                    Capsule().fill(Color.accentColor)
                        .frame(width: geo.size.width * progress,
                               height: PointSystemStyle.goalProgressHeight)
                        .animation(.easeOut(duration: 0.6), value: progress)
                }
            }
            .frame(height: PointSystemStyle.goalProgressHeight)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(.systemGray4), lineWidth: 1))
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - ComingSoonView

private struct ComingSoonView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            Text("Coming Soon")
                .font(.title2.weight(.bold))
            Button("Got It") { onDismiss() }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - AddGoalSheet

private struct AddGoalSheet: View {
    let childName: String
    let onSave: (String, Int) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var targetText = ""

    private var targetPoints: Int? { Int(targetText).flatMap { $0 > 0 ? $0 : nil } }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && targetPoints != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Goal").font(.headline)
                Spacer()
                Button { onCancel() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color(.systemGray3))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            VStack(spacing: 12) {
                TextField("Goal name (e.g. Screen Time)", text: $name)
                    .textFieldStyle(.roundedBorder)
                TextField("Target points", text: $targetText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
            }
            .padding(.horizontal, 20)

            Spacer()

            Button {
                guard let pts = targetPoints else { return }
                onSave(name.trimmingCharacters(in: .whitespaces), pts)
            } label: {
                Text("Save Goal")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: PointSystemStyle.actionButtonHeight)
                    .background(canSave ? Color.accentColor : Color(.systemGray4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
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
                    : String(localized: "Points deducted")))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(verbatim: activity.eventDate)
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
                label: "Deduct points",
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
                        .foregroundStyle(.primary)
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

            if isOpen {
                PointAdjustFormView(
                    style: row == .add ? .add : .deduct,
                    familyId: familyId,
                    memberId: child.memberId,
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
