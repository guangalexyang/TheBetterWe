# PointSystemView Design Spec

**Date:** 2026-05-21  
**Feature:** 积分系统 tab view (Point System tab)  
**Phase:** Mocked UI — content section is "Coming Soon"; carousel + child cards fully functional

---

## Overview

`PointSystemView` is the SwiftUI view rendered when the user selects the Point System tab in `FamilyView`. Its primary structure is a **two-section layout**: a top carousel showing one child per page, and a content section below that updates in sync with the selected child.

---

## Layout

```
┌─────────────────────────────────┐
│  Top Section                    │
│  ┌─────────────────────────┐    │
│  │  ChildCard (gradient)   │    │  ← swipeable carousel
│  └─────────────────────────┘    │
│         ●  ○  ○                 │  ← page dots (hidden if 1 child)
├─────────────────────────────────┤
│  Content Section                │
│                                 │  ← driven by selectedIndex
│       🚧 Coming Soon            │
│                                 │
└─────────────────────────────────┘
```

---

## Component: PointSystemView

**File:** `Views/Family/PointSystem/PointSystemView.swift`

**Props:**
- `membership: FamilyMembership`

**State:**
- `children: [PSChild]` — fetched on `.task`
- `selectedIndex: Int = 0` — single source of truth; drives both carousel and content section
- `isLoading: Bool` — true during initial fetch
- `errorMessage: String?` — shown inline with a retry button

**Data flow:** `selectedIndex` is bound to the `TabView` page. The content section receives `children[selectedIndex]` as a parameter. When `children` updates, `selectedIndex` is clamped to `0...(max(0, children.count - 1))` to prevent out-of-bounds access.

**Fetch:** Calls `PointSystemService.fetchChildren(familyId: membership.familyId)` on `.task`. On failure, shows an inline error with a "Retry" button.

---

## Component: ChildCard

**Inline private struct** inside `PointSystemView.swift`.

**Props:** `child: PSChild`

**Layout:**
- Full-width card, height 130 pt, corner radius 18
- Background: linear gradient tinted by gender
  - Boy (`ChildGender.boy`): `#3A7BD5 → #5BA8F5`
  - Girl (`ChildGender.girl`): `#C94B9E → #E87CC0`
  - Unknown / nil gender: `#5A7BAA → #7FA0C8` (neutral blue-gray)
- **Left:** 88 pt circle avatar
  - Fill: `rgba(white, 0.18)`
  - Border: 3 pt white at 85% opacity
  - Content: gender emoji — `👦` (boy), `👧` (girl), `🧒` (unknown)
- **Right:** name in `.title2.bold()` white; age on next line in `.subheadline` white at 80% opacity
  - Age computed from `child.birthday` ("YYYY-MM-DD") to years. If `birthday` is nil, the age line is omitted entirely.

---

## Component: Page Dots

**Inline private view** or `@ViewBuilder` inside `PointSystemView.swift`.

- Centered `HStack`, gap 6 pt, padding `10 pt` top and `12 pt` bottom
- Active dot: pill shape, 18×6 pt, color matches the active card's gradient start color
- Inactive dot: circle, 6×6 pt, `Color(.systemGray3)`
- Hidden entirely when `children.count <= 1`

---

## Empty State

When `children` is empty (and not loading), the carousel area shows a single dashed-border card (same height as `ChildCard`) with:
- Centered `+` icon (`.largeTitle`, secondary color)
- "Add your first child" text (`.subheadline`, secondary)
- Tapping the card pushes `AddChildView` via `navigationDestination`

Page dots are hidden in the empty state.

---

## Content Section

Separated from the top section by a `Divider()`.

The content section is a `@ViewBuilder` helper `childContent(child: PSChild)` that takes the currently selected child. This makes future wiring trivial — swapping the Coming Soon body for real content requires no structural change.

**Coming Soon body:**
- Vertically and horizontally centered
- 🚧 emoji (`.largeTitle`)
- "Coming Soon" (`.headline.bold()`)
- "Award points, track rules, and redeem rewards — all here." (`.subheadline`, `.secondary`)

---

## Style Constants

**File:** `Views/Family/PointSystem/PointSystemStyle.swift`

```swift
enum PointSystemStyle {
    static let cardHeight: CGFloat = 130
    static let cardCornerRadius: CGFloat = 18
    static let avatarSize: CGFloat = 88
    static let avatarBorderWidth: CGFloat = 3
    static let dotSize: CGFloat = 6
    static let activeDotWidth: CGFloat = 18
    static let dotCornerRadius: CGFloat = 3
    static let cardHPadding: CGFloat = 16   // outer padding around carousel
}

extension ChildGender {
    var gradientColors: [Color] { ... }   // returns [start, end] for LinearGradient
    var avatarEmoji: String { ... }
}
```

A free function or extension on `ChildGender?` handles the unknown/nil case.

---

## Localization Strings (new in Localizable.xcstrings)

| English key | zh-Hans |
|---|---|
| "Coming Soon" | 即将推出 |
| "Award points, track rules, and redeem rewards — all here." | 奖励积分、设置规则、兑换奖品，都在这里。 |
| "Add your first child" | 添加第一个孩子 |
| "Retry" | 重试 |

---

## Files Changed

| File | Change |
|---|---|
| `Views/Family/PointSystem/PointSystemView.swift` | **New** — full view + ChildCard + dots + empty state + content section |
| `Views/Family/PointSystem/PointSystemStyle.swift` | **New** — style constants + ChildGender extensions |
| `Views/Family/FamilyView.swift` | In `tabContent`, add a `switch m` inside the existing `.module(let m)` case: route `.pointSystem` to `PointSystemView(membership:)`, all others remain `Text("TODO: …")` |
| `Resources/Localizable.xcstrings` | Add 4 new string keys with zh-Hans translations |

---

## Out of Scope (this phase)

- Award points, redeem, rules — all deferred; content section is "Coming Soon"
- Child photo upload — avatar is emoji only for now
- Add Child from within PointSystemView beyond the empty-state entry point
