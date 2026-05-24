# Point Adjust Form — Design Spec

**Date:** 2026-05-23  
**Feature:** 加分/扣分 inline form (PointAdjustFormView)  
**Status:** Approved

---

## Overview

Replace the "Coming Soon" placeholder panels inside the Add Points and Deduct Points expandable rows with a real, functional inline form. The form lets a parent award or deduct a numeric point value for a child, add an optional note, and submit to the server. On success the row auto-collapses and the child's displayed balance updates immediately.

---

## Component Architecture

### `PointAdjustFormView` (new file)

A single reusable SwiftUI view parameterized by `ActionStyle`. Never duplicated — both Add and Deduct use this same component.

```swift
struct ActionStyle {
    let tint: Color
    let confirmLabel: LocalizedStringKey
}

extension ActionStyle {
    static let add    = ActionStyle(tint: Color(red: 58/255, green: 123/255, blue: 213/255),
                                    confirmLabel: "Add Points")
    static let deduct = ActionStyle(tint: Color(red: 217/255, green: 64/255, blue: 64/255),
                                    confirmLabel: "Deduct Points")
}
```

**Constructor:**
```swift
PointAdjustFormView(
    style: ActionStyle,
    familyId: Int,
    memberId: Int,
    onSuccess: (Int) -> Void   // called with newBalance on submit success
)
```

### Placement in `PointSystemView.swift`

`ChildFullView.actionRow()` currently renders a "Coming Soon" panel when `isOpen`. Replace that panel with `PointAdjustFormView(style:familyId:memberId:onSuccess:)`.

`ChildFullView` gains an `onBalanceChange: (Int) -> Void` callback. `PointSystemView` passes a closure that writes the new balance into `children[safeIndex].balance`.

---

## Visual Design

### Stepper

```
  ╭──────╮              ╭──────╮
  │  −   │      2       │  +   │
  ╰──────╯    pts/分     ╰──────╯
           tap to edit
```

- **Circle buttons:** white background, 1.5pt border (`Color(.systemGray3)`), shadow (`radius:4, y:1, opacity:0.10`), `font(.system(size: 22, weight: .light))`
- **Number:** `font(.system(size: 52, weight: .heavy))`, black (`Color(.label)`) at rest
- **Unit label:** `"pts"` in English / `"分"` in Chinese — localized via xcstrings — `font(.subheadline.weight(.medium))`, `.secondary` color, sits directly below the number
- **"tap to edit" hint:** `font(.caption)`, `.tertiary` color, sits below the unit label; hidden while the TextField is focused

### Editing state (TextField focused)

- Number color → tint color; text cursor is tint color
- ± buttons → `.opacity(0.35)`
- "tap to edit" hint → `.opacity(0)` (hidden, not removed, to avoid layout shift)

### Default value

Starts at `2`. Stepper clamps at min `1` (cannot go below 1 via buttons). Max enforced only on submit: reject values < 1 or > 9999 with an inline error.

### Note field

Standard form field style (matching `AuthStyle` pattern): gray rounded rect, placeholder `"Note (optional)"` / `"备注（选填）"`. No client-side character limit.

### "More ▾" link

Tinted text button (`font(.subheadline.weight(.medium))`). Toggles a `@State var isMoreExpanded: Bool`. When expanded, shows a Coming Soon placeholder (🚧 emoji + `"Coming soon"` text, same style as other Coming Soon panels in the app). Label flips to `"Less ▴"` when open.

### Confirm button

Full-width, `LinearGradient` using tint color (lighter shade at trailing end). `font(.body.weight(.semibold))`. While submitting: replace label with `ProgressView().tint(.white)`. Disabled while submitting or while value < 1.

On **success:** `PointAdjustFormView` calls `onSuccess(newBalance)`. The parent `ChildFullView` supplies the `onSuccess` closure, which both calls `onBalanceChange(newBalance)` and sets `expandedRow = nil` — auto-collapsing the row. The form itself has no direct access to `expandedRow`.

On **failure:** show an inline error message in `.caption` red below the confirm button. Error clears on next submit attempt.

### Form panel background

`Color(.systemGray6)` — matches the existing "Coming Soon" panel style.

### Tint propagation

The tint color applies to: expanded chevron in row header, ± button border and symbol color, number color (editing only), text cursor (editing only), "More" link, confirm button gradient.

---

## Localization (xcstrings keys to add)

| Key | zh-Hans | Note |
|-----|---------|------|
| `"pts"` | `"分"` | already in xcstrings (child card) |
| `"tap to edit"` | `"点击输入"` | new |
| `"Note (optional)"` | `"备注（选填）"` | new |
| `"More"` | `"更多"` | new |
| `"Less"` | `"收起"` | new |
| `"Add Points"` | `"加分确认"` | new (distinct from existing `"Add points"` row label) |
| `"Deduct Points"` | `"扣分确认"` | new (distinct from existing `"Deduct points"` row label) |
| `"Invalid amount"` | `"积分数量无效"` | new |

---

## Server

### New endpoint

**`POST /families/:familyId/point-system/events`**

Auth required. Caller must be a member of `familyId`.

**Request body:**
```json
{ "memberId": 3, "delta": 5, "note": "Great job today" }
```

- For Add: `delta` is positive
- For Deduct: `delta` is negative (iOS sends `-abs(value)`)
- `note` is optional (`null` or omitted)

**Validation:**
- `delta` must be a non-zero integer in range `[-9999, 9999]`
- `memberId` must be a child (`keyword = 'child'`) within `familyId`

**Response `201`:**
```json
{ "eventId": 42, "memberId": 3, "delta": 5, "note": "Great job today", "newBalance": 1285 }
```

`newBalance` is computed as `SUM(delta) FROM point_events WHERE member_id = ?` (same query as children list).

**Errors:** `400` invalid input, `403` not a member / not a child, `404` member not found.

---

## iOS Service

Add to `PointSystemService.swift`:

```swift
struct PointEventResponse: Decodable {
    let eventId: Int
    let memberId: Int
    let delta: Int
    let note: String?
    let newBalance: Int
}

static func addPointEvent(
    familyId: Int,
    memberId: Int,
    delta: Int,       // positive for add, negative for deduct
    note: String?
) async throws -> PointEventResponse
```

Uses the existing `post(path:body:expectedStatus:)` helper with `expectedStatus: 201`.

---

## State in `PointAdjustFormView`

```swift
@State private var points: Int = 2
@State private var noteText: String = ""
@FocusState private var isEditing: Bool
@State private var isMoreExpanded: Bool = false
@State private var isSubmitting: Bool = false
@State private var errorMessage: String? = nil
```

---

## Error Handling

- Network / server error → show `errorMessage` inline below the confirm button; do not collapse the form
- `unauthorized` error → call `onLogOut()` (same pattern used throughout the app). `PointAdjustFormView` receives an `onLogOut: () -> Void` callback. This requires threading `onLogOut` into `PointSystemView` (it currently doesn't have it) → `ChildFullView` → `PointAdjustFormView`. `PointSystemView` is called from `FamilyView`; check whether `FamilyView` already has `onLogOut` in scope.

---

## Previews

```swift
#Preview("Add Points — EN") { ... }
#Preview("Deduct Points — EN") { ... }
#Preview("中文") { ... .environment(\.locale, .init(identifier: "zh-Hans")) }
#Preview("Editing state") { ... }  // start with isEditing = true via .focused()
```

---

## Out of Scope (this spec)

- Rules selection (the "More" section will handle this later)
- Redemptions
- Point history (PointRecordView — separate spec)
