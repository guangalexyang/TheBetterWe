import SwiftUI

// MARK: - PointSystemView

struct PointSystemView: View {
    let membership: FamilyMembership

    @State private var children: [PSChild] = []
    @State private var selectedIndex: Int = 0
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var navigateToAddChild = false

    var body: some View {
        VStack(spacing: 0) {
            topSection
                .padding(.top, PointSystemStyle.cardTopPadding)
                .padding(.bottom, PointSystemStyle.cardBottomPadding)
            Divider()
            contentSection
        }
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

    // MARK: Top section

    @ViewBuilder
    private var topSection: some View {
        VStack(spacing: 0) {
            if isLoading {
                RoundedRectangle(cornerRadius: PointSystemStyle.cardCornerRadius)
                    .fill(Color(.systemGray5))
                    .frame(height: PointSystemStyle.cardHeight)
                    .padding(.horizontal, PointSystemStyle.cardHPadding)
            } else if children.isEmpty {
                emptyCard
                    .padding(.horizontal, PointSystemStyle.cardHPadding)
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                        ChildCard(child: child)
                            .padding(.horizontal, PointSystemStyle.cardHPadding)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: PointSystemStyle.cardHeight)

                if children.count > 1 {
                    PageDots(
                        count: children.count,
                        selected: selectedIndex,
                        activeColor: children[selectedIndex].gender.gradientColors.first ?? .accentColor
                    )
                    .padding(.top, 10)
                }
            }
        }
    }

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
        } else {
            let selected: PSChild? = children.isEmpty ? nil : children[selectedIndex]
            childContent(child: selected)
        }
    }

    @ViewBuilder
    private func childContent(child: PSChild?) -> some View {
        VStack(spacing: 12) {
            Text("🚧").font(.largeTitle)
            Text("Coming Soon").font(.headline.bold())
            Text("Award points, track rules, and redeem rewards — all here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - ChildCard

private struct ChildCard: View {
    let child: PSChild

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

    var body: some View {
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
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: PointSystemStyle.cardHeight)
        .background(
            LinearGradient(
                colors: child.gender.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: PointSystemStyle.cardCornerRadius))
    }
}

// MARK: - PageDots

private struct PageDots: View {
    let count: Int
    let selected: Int
    let activeColor: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == selected ? activeColor : Color(.systemGray3))
                    .frame(width: i == selected ? PointSystemStyle.activeDotWidth : PointSystemStyle.dotSize,
                           height: PointSystemStyle.dotSize)
                    .animation(.easeInOut(duration: 0.2), value: selected)
            }
        }
    }
}

// MARK: - Previews

#Preview("ChildCard — boy") {
    ChildCard(child: PSChild(memberId: 1, name: "桅", gender: .boy,
                             birthday: "2022-03-15", balance: 0))
        .padding()
}

#Preview("ChildCard — girl") {
    ChildCard(child: PSChild(memberId: 2, name: "朵", gender: .girl,
                             birthday: "2020-07-04", balance: 0))
        .padding()
}

#Preview("ChildCard — unknown, no birthday") {
    ChildCard(child: PSChild(memberId: 3, name: "小明", gender: nil,
                             birthday: nil, balance: 0))
        .padding()
}

#Preview("PageDots — 3 kids, page 1 active") {
    PageDots(count: 3, selected: 1,
             activeColor: Color(red: 58/255, green: 123/255, blue: 213/255))
        .padding()
}

#Preview("Empty state") {
    NavigationStack {
        PointSystemView(membership: FamilyMembership(
            familyId: 99, familyName: "Empty Family", memberId: 1,
            displayName: "Dad", roleKeywords: ["pointSystem"]
        ))
    }
}

#Preview("中文 — empty state") {
    NavigationStack {
        PointSystemView(membership: FamilyMembership(
            familyId: 99, familyName: "杨家", memberId: 1,
            displayName: "爸爸", roleKeywords: ["pointSystem"]
        ))
    }
    .environment(\.locale, .init(identifier: "zh-Hans"))
}
