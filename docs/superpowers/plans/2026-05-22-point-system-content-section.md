# Point System Content Section Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the "Coming Soon" placeholder in `PointSystemView.contentSection` with a points balance banner and three action rows (加分, 扣分, 积分记录).

**Architecture:** The existing `@ViewBuilder func childContent` becomes `private struct ChildContentView: View` to hold local `@State`. `ChildContentView` receives the selected `PSChild` as a parameter — no new data fetching. The content section does not swipe; it reads `children[selectedIndex]` and re-renders when `selectedIndex` changes.

**Tech Stack:** SwiftUI, Swift 5.9+, iOS 17+ (already established in project).

---

## File Map

| File | Action | What changes |
|---|---|---|
| `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemStyle.swift` | Modify | Add 9 size constants + 3 icon background colors |
| `ios/TheBetterWe/TheBetterWe/Resources/Localizable.xcstrings` | Modify | Add 6 new localized string keys |
| `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointRecordView.swift` | Create | "Coming Soon" stub for 积分记录 push screen |
| `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemView.swift` | Modify | Replace `childContent` func with `ChildContentView` struct; update `contentSection` |

---

## Task 1: Add style constants to PointSystemStyle

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemStyle.swift`

- [ ] **Step 1: Add numeric constants and icon background colors**

Open `PointSystemStyle.swift`. Replace the entire `PointSystemStyle` enum with this updated version (adds 9 constants and 3 color properties after `cardBottomPadding`; everything else is unchanged):

```swift
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

    // Content section
    static let pointsBannerHPadding: CGFloat = 20
    static let pointsBannerVPadding: CGFloat = 16
    static let pointsValueFontSize: CGFloat = 40
    static let pointsUnitFontSize: CGFloat = 18
    static let actionListGap: CGFloat = 8
    static let rowIconSize: CGFloat = 32
    static let rowIconCornerRadius: CGFloat = 8
    static let rowHPadding: CGFloat = 20
    static let rowVPadding: CGFloat = 14

    static let addIconBackground    = Color(red: 0.91, green: 0.97, blue: 0.91)
    static let deductIconBackground = Color(red: 0.99, green: 0.91, blue: 0.91)
    static let recordIconBackground = Color(red: 0.91, green: 0.93, blue: 0.97)
}
```

- [ ] **Step 2: Build to verify no errors**

```bash
xcodebuild -project ios/TheBetterWe/TheBetterWe.xcodeproj \
  -scheme TheBetterWe \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build 2>&1 | grep -E "error:|Build succeeded|Build failed"
```

Expected: `** BUILD SUCCEEDED **`

---

## Task 2: Add localization strings

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Resources/Localizable.xcstrings`

- [ ] **Step 1: Insert 6 new key blocks into the `"strings"` dictionary**

The file is alphabetically sorted JSON. Insert each block in alphabetical position. Add these six entries anywhere inside the `"strings": { ... }` object (Xcode will re-sort on next build):

```json
"Add points" : {
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "加分"
      }
    }
  }
},
"Coming soon" : {
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "即将推出"
      }
    }
  }
},
"Deduct points" : {
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "扣分"
      }
    }
  }
},
"Point records" : {
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "积分记录"
      }
    }
  }
},
"Points" : {
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "积分"
      }
    }
  }
},
"pts" : {
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "分"
      }
    }
  }
},
```

- [ ] **Step 2: Build to verify xcstrings parses correctly**

```bash
xcodebuild -project ios/TheBetterWe/TheBetterWe.xcodeproj \
  -scheme TheBetterWe \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build 2>&1 | grep -E "error:|Build succeeded|Build failed"
```

Expected: `** BUILD SUCCEEDED **`

---

## Task 3: Create PointRecordView stub

**Files:**
- Create: `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointRecordView.swift`

- [ ] **Step 1: Create the stub view**

```swift
import SwiftUI

struct PointRecordView: View {
    let child: PSChild

    var body: some View {
        VStack(spacing: 16) {
            Text("🚧").font(.largeTitle)
            Text("Coming soon").font(.headline.bold())
            Text("Point history will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(child.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("English") {
    NavigationStack {
        PointRecordView(child: PSChild(memberId: 1, name: "桅", gender: .boy,
                                      birthday: "2022-03-15", balance: 1280))
    }
}

#Preview("中文") {
    NavigationStack {
        PointRecordView(child: PSChild(memberId: 2, name: "朵", gender: .girl,
                                      birthday: "2020-07-04", balance: 840))
    }
    .environment(\.locale, .init(identifier: "zh-Hans"))
}
```

- [ ] **Step 2: Build to verify the new file compiles**

```bash
xcodebuild -project ios/TheBetterWe/TheBetterWe.xcodeproj \
  -scheme TheBetterWe \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build 2>&1 | grep -E "error:|Build succeeded|Build failed"
```

Expected: `** BUILD SUCCEEDED **`

---

## Task 4: Build ChildContentView (replaces childContent)

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemView.swift`

- [ ] **Step 1: Update `contentSection` in `PointSystemView`**

Replace the current `contentSection` computed property and `childContent` function. The new `contentSection` delegates to `ChildContentView` only when a child exists; the nil/empty case renders nothing (the top section already shows the empty-add card).

Find this block in `PointSystemView.swift` (lines ~97–131):

```swift
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
private func childContent(child _: PSChild?) -> some View {
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
```

Replace with:

```swift
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
    } else if !children.isEmpty {
        ChildContentView(child: children[selectedIndex])
    }
}
```

- [ ] **Step 2: Add `ChildContentView` at the bottom of `PointSystemView.swift`, before the `#Preview` blocks**

Insert this struct after the closing `}` of `PointSystemView` and before `// MARK: - ChildCard`:

```swift
// MARK: - ChildContentView

private struct ChildContentView: View {
    let child: PSChild

    private enum ExpandedRow: Equatable { case add, deduct }

    @State private var expandedRow: ExpandedRow? = nil
    @State private var navigateToRecord = false

    var body: some View {
        VStack(spacing: 0) {
            pointsBanner
            Color(.systemGray6).frame(height: PointSystemStyle.actionListGap)
            actionList
        }
        .navigationDestination(isPresented: $navigateToRecord) {
            PointRecordView(child: child)
        }
    }

    // MARK: Points banner

    private var pointsBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PointSystemStyle.pointsBannerHPadding)
        .padding(.vertical, PointSystemStyle.pointsBannerVPadding)
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
        .background(Color(.systemBackground))
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
                .padding(.horizontal, PointSystemStyle.rowHPadding)
                .padding(.vertical, PointSystemStyle.rowVPadding)
            }
            .buttonStyle(.plain)

            if isOpen {
                HStack(spacing: 8) {
                    Text("🚧")
                    Text("Coming soon")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.systemGray6))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipped()
    }

    private var recordRow: some View {
        Button {
            navigateToRecord = true
        } label: {
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
            .padding(.horizontal, PointSystemStyle.rowHPadding)
            .padding(.vertical, PointSystemStyle.rowVPadding)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Add previews for ChildContentView before the existing `#Preview` blocks**

Append these previews at the bottom of `PointSystemView.swift`, before the existing `#Preview("ChildCard — boy")`:

```swift
#Preview("ChildContentView — boy, 1280 pts") {
    NavigationStack {
        ChildContentView(child: PSChild(memberId: 1, name: "桅", gender: .boy,
                                       birthday: "2022-03-15", balance: 1280))
    }
}

#Preview("ChildContentView — girl, 0 pts") {
    NavigationStack {
        ChildContentView(child: PSChild(memberId: 2, name: "朵", gender: .girl,
                                       birthday: "2020-07-04", balance: 0))
    }
}

#Preview("ChildContentView — 中文") {
    NavigationStack {
        ChildContentView(child: PSChild(memberId: 1, name: "桅", gender: .boy,
                                       birthday: "2022-03-15", balance: 1280))
    }
    .environment(\.locale, .init(identifier: "zh-Hans"))
}
```

- [ ] **Step 4: Build to verify the full change compiles**

```bash
xcodebuild -project ios/TheBetterWe/TheBetterWe.xcodeproj \
  -scheme TheBetterWe \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build 2>&1 | grep -E "error:|Build succeeded|Build failed"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Verify previews visually in Xcode**

Open `PointSystemView.swift` in Xcode. In the canvas, check:
- `ChildContentView — boy, 1280 pts`: blue gradient banner with "1,280 pts", three rows visible
- `ChildContentView — girl, 0 pts`: pink gradient banner with "0 pts"
- `ChildContentView — 中文`: banner shows "积分" + "1,280 分", rows show "加分" / "扣分" / "积分记录"

Also check the full `PointSystemView` previews ("Empty state", "中文 — empty state") still render without error.
