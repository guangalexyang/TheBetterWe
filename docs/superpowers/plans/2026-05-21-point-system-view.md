# PointSystemView Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the 积分系统 (Point System) tab view with a swipeable child profile carousel and a "Coming Soon" content section driven by the selected child, wired into FamilyView's tab router.

**Architecture:** `PointSystemView` owns a `[PSChild]` array fetched on `.task` and a `selectedIndex: Int` that binds to the `TabView` page and also parameterizes the `childContent` helper below the divider — so swapping out "Coming Soon" for real content later is a one-line change. Style constants and `ChildGender` gradient/emoji extensions live in a separate `PointSystemStyle.swift` so view files stay free of magic numbers.

**Tech Stack:** SwiftUI, `TabView` with `.page` style, `PointSystemService.fetchChildren`, `Localizable.xcstrings`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemStyle.swift` | Create | Style constants + `ChildGender` gradient/emoji extensions |
| `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemView.swift` | Create | Full view: carousel, dots, empty state, content section, fetch |
| `ios/TheBetterWe/TheBetterWe/Views/Family/FamilyView.swift` | Modify | Route `.pointSystem` AppModule case to `PointSystemView` |
| `ios/TheBetterWe/TheBetterWe/Resources/Localizable.xcstrings` | Modify | Add 5 new localized string keys |

---

### Task 1: PointSystemStyle.swift

**Files:**
- Create: `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemStyle.swift`

- [ ] **Step 1: Create the style file**

```swift
import SwiftUI

enum PointSystemStyle {
    static let cardHeight: CGFloat = 130
    static let cardCornerRadius: CGFloat = 18
    static let avatarSize: CGFloat = 88
    static let avatarBorderWidth: CGFloat = 3
    static let cardHPadding: CGFloat = 16
    static let dotSize: CGFloat = 6
    static let activeDotWidth: CGFloat = 18
    static let cardTopPadding: CGFloat = 12
    static let cardBottomPadding: CGFloat = 8
}

extension ChildGender {
    var gradientColors: [Color] {
        switch self {
        case .boy:
            return [Color(red: 58/255, green: 123/255, blue: 213/255),
                    Color(red: 91/255, green: 168/255, blue: 245/255)]
        case .girl:
            return [Color(red: 201/255, green: 75/255, blue: 158/255),
                    Color(red: 232/255, green: 124/255, blue: 192/255)]
        }
    }

    var avatarEmoji: String {
        switch self {
        case .boy:  return "👦"
        case .girl: return "👧"
        }
    }
}

extension Optional where Wrapped == ChildGender {
    var gradientColors: [Color] {
        self?.gradientColors ?? [Color(red: 90/255, green: 123/255, blue: 170/255),
                                 Color(red: 127/255, green: 160/255, blue: 200/255)]
    }

    var avatarEmoji: String {
        self?.avatarEmoji ?? "🧒"
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

In Xcode, build (`⌘B`). Expected: build succeeds with no errors.

---

### Task 2: ChildCard and PageDots

**Files:**
- Create: `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemView.swift`

- [ ] **Step 1: Create the file with ChildCard and PageDots private structs**

```swift
import SwiftUI

// MARK: - ChildCard

private struct ChildCard: View {
    let child: PSChild

    private func ageString() -> String? {
        guard let birthday = child.birthday else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: birthday) else { return nil }
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
                if i == selected {
                    Capsule()
                        .fill(activeColor)
                        .frame(width: PointSystemStyle.activeDotWidth,
                               height: PointSystemStyle.dotSize)
                } else {
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: PointSystemStyle.dotSize,
                               height: PointSystemStyle.dotSize)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selected)
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
```

- [ ] **Step 2: Build and verify previews**

Build (`⌘B`). Open the preview canvas. Verify:
- Boy card: blue gradient, 👦 emoji, name "桅", age computed from birthday
- Girl card: pink gradient, 👧 emoji
- Unknown/nil card: gray-blue gradient, 🧒 emoji, no age line
- Dots: pill at index 1, circles at 0 and 2

---

### Task 3: PointSystemView — full assembly

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemView.swift`

- [ ] **Step 1: Insert PointSystemView above the `// MARK: - ChildCard` line**

```swift
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
                        activeColor: children[selectedIndex].gender.gradientColors[0]
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
```

- [ ] **Step 2: Add full-view previews at the bottom of the file**

Append after the last existing `#Preview` block:

```swift
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
```

- [ ] **Step 3: Build and check previews**

Build (`⌘B`). In the preview canvas:
- "Empty state": dashed card with "Add your first child" in top section; "Coming Soon" below divider
- "中文": same but all text in Chinese ("添加第一个孩子", "即将推出", "奖励积分…")
- Note: previews with real `familyId` values will show loading then error (expected when server is off)

---

### Task 4: Wire FamilyView

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Views/Family/FamilyView.swift` (line ~94)

- [ ] **Step 1: Replace the `tabContent` computed property**

Find the existing:

```swift
@ViewBuilder
private var tabContent: some View {
    switch selectedTab {
    case .dashboard:
        DashboardView(membership: membership)
    case .module(let m):
        Text("TODO: \(m.rawValue)")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

Replace with:

```swift
@ViewBuilder
private var tabContent: some View {
    switch selectedTab {
    case .dashboard:
        DashboardView(membership: membership)
    case .module(let m):
        switch m {
        case .pointSystem:
            PointSystemView(membership: membership)
        default:
            Text("TODO: \(m.rawValue)")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
```

- [ ] **Step 2: Build and run in simulator**

Build and run (`⌘R`). With the local server running (`npm run dev` in `server/`):
1. Log in and navigate to the family view
2. Tap the "Point System" tab
3. Verify the carousel shows real children (or empty state if none added yet)
4. If multiple children: swipe left/right and confirm the content section re-renders (currently Coming Soon, but verify no crash and correct child is passed)
5. Tap empty card (if no children) → verify navigation pushes AddChildView → add a child → verify the carousel appears with the new child on return

---

### Task 5: Localization

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add 5 new keys inside the `"strings"` object**

Open `Localizable.xcstrings`. Find the top-level `"strings": {` object and add the following entries (order within `"strings"` doesn't matter):

```json
"Coming Soon" : {
  "extractionState" : "manual",
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : { "state" : "translated", "value" : "即将推出" }
    }
  }
},
"Award points, track rules, and redeem rewards — all here." : {
  "extractionState" : "manual",
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : { "state" : "translated", "value" : "奖励积分、设置规则、兑换奖品，都在这里。" }
    }
  }
},
"Add your first child" : {
  "extractionState" : "manual",
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : { "state" : "translated", "value" : "添加第一个孩子" }
    }
  }
},
"Retry" : {
  "extractionState" : "manual",
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : { "state" : "translated", "value" : "重试" }
    }
  }
},
"%d years old" : {
  "extractionState" : "manual",
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : { "state" : "translated", "value" : "%d 岁" }
    }
  }
}
```

- [ ] **Step 2: Verify Chinese locale previews**

Build (`⌘B`). Open the "中文 — empty state" preview in the canvas. Verify:
- "Add your first child" → "添加第一个孩子"
- "Coming Soon" → "即将推出"
- "Award points, track rules…" → "奖励积分、设置规则、兑换奖品，都在这里。"

- [ ] **Step 3: Verify age string in Chinese**

Add a temporary preview to `PointSystemView.swift` for the ChildCard in Chinese locale:

```swift
#Preview("ChildCard age — 中文") {
    ChildCard(child: PSChild(memberId: 1, name: "桅", gender: .boy,
                             birthday: "2022-03-15", balance: 0))
        .padding()
        .environment(\.locale, .init(identifier: "zh-Hans"))
}
```

Build and open the preview. Verify age shows as "N 岁" (e.g. "3 岁") instead of "N years old". Delete the temporary preview when confirmed.
