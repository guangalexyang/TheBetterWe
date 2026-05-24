# Point System View Redesign

**Date:** 2026-05-22
**Status:** Approved

## Summary

Redesign `PointSystemView` to remove the swipe carousel and replace it with a tab-based layout. The child card and points display merge into one full-width gradient card. Navigation between children (when 2+) uses centered pill tabs at the top.

## Layout

### Single child (no tabs)
```
┌─────────────────────────────────┐
│  ← 我家        积分系统          │  nav bar
├─────────────────────────────────┤
│  [avatar]  Name                 │  ← gradient card (full width, no padding)
│            Age                  │    row 1
│  ─────────────────────────────  │
│  Points                         │    row 2
│  1,280  pts                     │
├─────────────────────────────────┤
│  [+]  加分               ›      │  action rows
│  ─────────────────────────────  │
│  [-]  扣分               ›      │
│  ─────────────────────────────  │
│  [≡]  积分记录           ›      │
│                                 │
│           (spacer)              │
├─────────────────────────────────┤
│         ── home bar ──          │
└─────────────────────────────────┘
```

### Multiple children (with tab bar)
```
┌─────────────────────────────────┐
│  ← 我家        积分系统          │  nav bar
├─────────────────────────────────┤
│    [👦 桅]  👧 朵  🧒 小明       │  centered pill tabs
├─────────────────────────────────┤
│  (same card + actions below)    │
└─────────────────────────────────┘
```

## Components

### `ChildTabBar` (new private struct)
- `ScrollView(.horizontal, showsIndicators: false)` with centered `HStack`
- Each tab: `[emoji] [name]` in a `Capsule`
- Selected: child's `gradientColors` as `LinearGradient` fill, white semibold text
- Unselected: `systemGray6` fill, primary label color
- Tap animates `selectedIndex` with `.easeInOut(duration: 0.2)`
- Shown only when `children.count > 1`

### `ChildFullView` (replaces `ChildContentView`)
Combines what was the carousel card and the points banner into one view:

**Combined gradient card** (full width, no corner radius, no horizontal padding):
- Row 1: `avatar-circle` (88pt, white-bordered) + `VStack(name, age)`
- Row 2: "Points" small-caps label + `Text(balance, format: .number)` + "pts"
- Background: `child.gender.gradientColors` linear gradient

**Action list** (unchanged):
- 加分 expandable row
- 扣分 expandable row
- 积分记录 push row
- `Spacer(minLength: 0)` fills remaining height
- `.background(Color(.systemBackground))` on outer VStack

**State:** `expandedRow: ExpandedRow?`, `navigateToRecord: Bool` — same as before

### `PointSystemView` (updated)
- Removes: `topSection`, `PageDots`, `TabView(.page)` carousel
- Body: `VStack(spacing: 0)` → optional `ChildTabBar` + `Divider` + `contentSection`
- `contentSection`: loading / error / empty / `ChildFullView` (unchanged logic)
- Empty state: `emptyCard` centered in a VStack with top padding (unchanged)
- `.frame(maxHeight: .infinity, alignment: .top)` on outer VStack

## Style Constants (PointSystemStyle)

Existing constants reused as-is. No new constants needed — the card no longer needs `cardTopPadding`/`cardBottomPadding` (padding removed), but the constants can stay for the empty card.

## Removed

- `PageDots` struct — deleted
- `topSection` computed var — deleted
- `TabView(.page)` carousel — deleted
- Separate `pointsBanner` in `ChildContentView` — merged into card

## Localization

No new strings. All existing keys reused.

## Files Changed

- `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemView.swift` — full rewrite
- `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemStyle.swift` — no changes needed
