# Point System — Content Section Design

**Date:** 2026-05-22
**Scope:** Replaces the "Coming Soon" placeholder in `PointSystemView.contentSection`. Does not touch the top section (child card / page dots).

---

## Overview

The content section displays the selected child's point balance and three action rows. It is fixed — it does not swipe with the child cards in the top section — but its gradient color and balance number animate/update whenever the selected child changes.

---

## Layout

```
┌─────────────────────────────────────┐
│  [TOP SECTION — swipeable cards]    │  ← already built
├─────────────────────────────────────┤
│  ▌ 积分          (gradient banner)  │
│  ▌ 1,280 分                         │
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤  8px gray gap
│  ➕  加分                      ›    │  ← tappable, expands inline
│       ─────────────────────────     │
│        [expanded area, if open]     │
├─────────────────────────────────────┤
│  ➖  扣分                      ›    │  ← tappable, expands inline
│       ─────────────────────────     │
├─────────────────────────────────────┤
│  📋  积分记录                  ›    │  ← navigation push
└─────────────────────────────────────┘
```

---

## Components

### 1. Points Banner (`pointsBanner`)

- Full-width section, no card rounding — bleeds edge to edge.
- Background: `LinearGradient` using `child.gender.gradientColors` (same as `ChildCard`). Animates with `.animation(.easeInOut, value: selectedIndex)` when child changes.
- Label: `"Points"` (localized key → "积分" in zh-Hans). Small, uppercase, low-opacity white.
- Value: `child.balance` formatted with `%d` and grouping separator. Large bold white number. Unit `"pts"` (localized → "分") inline after the number, slightly smaller weight.
- No button, no redeem concept — points balance only.

### 2. Action List

A plain white `VStack` with `Divider()` between rows. 8px gray gap separates it from the points banner.

Each row: icon (rounded-rect background) + label + chevron. Follows existing list-row style in the app.

#### 加分 / 扣分 rows (expandable)

- Tap toggles an inline expanded area below the row.
- Only one row is open at a time; opening one auto-closes the other.
- Chevron rotates 90° when open (`.rotationEffect(.degrees(isOpen ? 90 : 0))`), animated.
- The expanded area uses a `@ViewBuilder` called `expandedContent(for:)` that currently returns a "Coming Soon" placeholder. The placeholder matches the style of the existing `childContent` coming-soon view (🚧 emoji + text).
- Expansion animation: `.animation(.easeInOut(duration: 0.22), value: expandedRow)`.
- State lives in a private `struct ChildContentView: View` (the current `@ViewBuilder func childContent` must become a proper struct to hold `@State`).
- Single `@State var expandedRow: ExpandedRow?` enum (`enum ExpandedRow { case add, deduct }`).

#### 积分记录 row (navigation)

- Standard chevron navigation row. Tapping pushes a `PointRecordView` (new screen).
- `PointRecordView` takes `child: PSChild` and shows a "Coming Soon" placeholder for now.
- `navigationDestination(isPresented:)` lives inside `ChildContentView` — valid because it is already inside the caller's `NavigationStack`.

---

## Data Flow

- `PointSystemView` already owns `selectedIndex` and `children: [PSChild]`.
- `contentSection` and all sub-views receive the currently selected `PSChild` (or `nil` if empty) via parameter — no new state needed at this level.
- Balance shown is `child.balance` from the last `fetchChildren` call. No separate fetch for balance.
- After 加分/扣分 actions are implemented (future), the action will update `children[selectedIndex].balance` in place so the banner reflects the new total without a full reload.

---

## State

| State | Owner | Notes |
|---|---|---|
| `expandedRow: ExpandedRow?` | `ChildContentView` (`@State`) | Nil when nothing is expanded |
| `navigateToRecord: Bool` | `ChildContentView` (`@State`) | Drives `navigationDestination` for 积分记录 |

---

## Style Constants (additions to `PointSystemStyle`)

```swift
static let pointsBannerHPadding: CGFloat = 20
static let pointsBannerVPadding: CGFloat = 16
static let pointsValueFontSize: CGFloat = 40    // .system(size: 40, weight: .heavy)
static let pointsUnitFontSize: CGFloat = 18
static let actionListGap: CGFloat = 8           // gray spacer between banner and list
static let rowIconSize: CGFloat = 32
static let rowIconCornerRadius: CGFloat = 8
static let rowHPadding: CGFloat = 20
static let rowVPadding: CGFloat = 14
```

Icon background colors (added to `PointSystemStyle`):
- 加分: `Color(red: 0.91, green: 0.97, blue: 0.91)` (soft green)
- 扣分: `Color(red: 0.99, green: 0.91, blue: 0.91)` (soft red)
- 积分记录: `Color(red: 0.91, green: 0.93, blue: 0.97)` (soft blue)

---

## Empty State

If `child == nil` (no children added), the content section shows nothing (caller already shows the empty card in the top section). If `child.balance == 0`, the banner shows "0 分" — no special empty message.

---

## Localization

| Key (English) | zh-Hans |
|---|---|
| `"Points"` | 积分 |
| `"pts"` | 分 |
| `"Add points"` | 加分 |
| `"Deduct points"` | 扣分 |
| `"Point records"` | 积分记录 |
| `"Coming soon"` | 即将推出 |
| `"Award points, track rules, and redeem rewards — all here."` | *(existing, no change)* |

---

## Files Changed

| File | Change |
|---|---|
| `PointSystemView.swift` | Replace `childContent` body; add `PointRecordView` stub |
| `PointSystemStyle.swift` | Add new constants above |
| `Localizable.xcstrings` | Add new keys from localization table |

New file: `PointRecordView.swift` (stub, "Coming Soon"). The `childContent` `@ViewBuilder func` is refactored into a private `struct ChildContentView: View` (necessary to hold `@State`).

---

## Out of Scope

- 加分 / 扣分 form UI (separate design session)
- 积分记录 list UI (separate design session)
- Server endpoints for adding/deducting points
