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

    var body: some View {
        VStack(spacing: 0) {
            if children.count > 1 {
                ChildTabBar(children: children, selectedIndex: $selectedIndex)
                Divider()
            }
            contentSection
        }
        .frame(maxHeight: .infinity, alignment: .top)
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

    // MARK: Content section

    @ViewBuilder
    private var contentSection: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let msg = errorMessage {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if children.isEmpty {
            VStack {
                emptyCard
                    .padding(.horizontal, PointSystemStyle.cardHPadding)
                    .padding(.top, PointSystemStyle.cardTopPadding)
                Spacer()
            }
            .frame(maxHeight: .infinity)
        } else {
            let safeIndex = min(selectedIndex, children.count - 1)
            let safeChild = children[safeIndex]
            ChildFullView(
                child: safeChild,
                familyId: membership.familyId,
                onBalanceChange: { newBalance in
                    if let idx = children.firstIndex(where: { $0.memberId == safeChild.memberId }) {
                        children[idx].balance = newBalance
                    }
                },
                onLogOut: onLogOut
            )
            .id(safeChild.id)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: Empty card

    private var emptyCard: some View {
        Button { navigateToAddChild = true } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Add your first child")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: PointSystemStyle.cardHeight)
            .background(
                RoundedRectangle(cornerRadius: PointSystemStyle.cardCornerRadius)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundStyle(Color(.systemGray3))
            )
            .contentShape(RoundedRectangle(cornerRadius: PointSystemStyle.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }

    // MARK: Data

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

// MARK: - Previews

#Preview("Single child — boy") {
    NavigationStack {
        PointSystemView(membership: FamilyMembership(
            familyId: 1, familyName: "杨家", memberId: 1,
            displayName: "爸爸", roleKeywords: ["pointSystem"]
        ))
    }
}

#Preview("ChildFullView — boy, 1280 pts") {
    NavigationStack {
        ChildFullView(
            child: PSChild(memberId: 1, name: "桅", gender: .boy,
                           birthday: "2022-03-15", balance: 1280),
            familyId: 1,
            onBalanceChange: { _ in },
            onLogOut: {}
        )
    }
}

#Preview("ChildFullView — girl, 340 pts") {
    NavigationStack {
        ChildFullView(
            child: PSChild(memberId: 2, name: "朵", gender: .girl,
                           birthday: "2020-07-04", balance: 340),
            familyId: 1,
            onBalanceChange: { _ in },
            onLogOut: {}
        )
    }
}

#Preview("ChildTabBar — 3 children") {
    ChildTabBar(
        children: [
            PSChild(memberId: 1, name: "桅", gender: .boy, birthday: nil, balance: 0),
            PSChild(memberId: 2, name: "朵", gender: .girl, birthday: nil, balance: 0),
            PSChild(memberId: 3, name: "小明", gender: nil, birthday: nil, balance: 0),
        ],
        selectedIndex: .constant(0)
    )
}

#Preview("中文") {
    NavigationStack {
        ChildFullView(
            child: PSChild(memberId: 1, name: "桅", gender: .boy,
                           birthday: "2022-03-15", balance: 1280),
            familyId: 1,
            onBalanceChange: { _ in },
            onLogOut: {}
        )
    }
    .environment(\.locale, .init(identifier: "zh-Hans"))
}

#Preview("Empty state") {
    NavigationStack {
        PointSystemView(membership: FamilyMembership(
            familyId: 99, familyName: "Empty Family", memberId: 1,
            displayName: "Dad", roleKeywords: ["pointSystem"]
        ))
    }
}
