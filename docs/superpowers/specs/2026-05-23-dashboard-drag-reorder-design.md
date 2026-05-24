# Dashboard Drag-to-Reorder — Design Spec

**Date:** 2026-05-23  
**Status:** Approved  
**File:** `ios/TheBetterWe/TheBetterWe/Views/Family/DashboardView.swift`

## Problem

The current drag-to-reorder implementation has laggy, jumpy behavior. The dragged card stays inside the `VStack` and is shifted by `.offset(dragOffset)`. When `reorder()` moves it in `widgetOrder`, the card's base position in the stack shifts while the old offset still applies — the two forces fight each other and the card jumps. Compounding this, `reorder()` fires on every drag event with a `.easeInOut` animation, stacking animations every few milliseconds.

## Goal

iOS home-screen-quality drag behavior: long-press lifts only the pressed card, which follows the finger smoothly; other cards silently slide to make room; drop snaps the card cleanly into its new slot.

## Architecture — ZStack with ghost + floating overlay

Replace the current single-layer `ScrollView` with a `ZStack`:

- **Layer 1** — `ScrollView` containing a `VStack` of widget cards (changed from `LazyVStack`)
- **Layer 2** — Floating card overlay, rendered only while a drag is active

During drag, the card in the `VStack` becomes a **ghost** (opacity 0.3, no shadow) that holds the space and previews where the card will land. The actual `WidgetCard` is placed in the ZStack overlay, scaled up, given a heavier shadow, and follows the finger via `.position(x:y:)`.

`LazyVStack → VStack`: lazy views may not compute frames for off-screen items. With 4–5 max cards, `VStack` is appropriate.

The `"dashboard"` coordinate space remains on the `ScrollView`. Since the `ScrollView` fills the `ZStack` from the same origin, `.position()` in the ZStack maps to the same coordinate system as `cardFrames`.

## State

```swift
@State private var draggingModule: AppModule? = nil
@State private var dragOffset: CGSize = .zero      // finger translation since lift
@State private var liftOrigin: CGRect = .zero      // card frame at moment of lift
@State private var lastHoverIndex: Int? = nil      // prevents redundant reorders
@State private var cardWidth: CGFloat = 0          // captured once from GeometryReader on ZStack
```

`cardWidth` is captured from a `GeometryReader` background on the ZStack so the floating card matches scroll content width (`scrollView.width - 32`).

Remove: `draggingItem` (replaced by `draggingModule`), per-card `.offset()` / `.scaleEffect()` / `.zIndex()` modifiers.  
Keep: `dragOffset` (same name, repurposed to drive the floating card position instead of card `.offset()`).

## Gesture

`LongPressGesture(minimumDuration: 0.4)` sequenced with `DragGesture(coordinateSpace: .named("dashboard"))` — same structure as today.

Changes:
- **Long press fires** → `scrollDisabled = true`
- **First drag event** → capture `liftOrigin = cardFrames[module]`, set `draggingModule = module` with spring animation, haptic feedback
- **Drag update** → `dragOffset = drag.translation`, call `updateDropPosition(for:)` 
- **Gesture end** → spring-animate `draggingModule = nil` and `dragOffset = .zero`, clear `lastHoverIndex`, `scrollDisabled = false`

## Reorder Algorithm

`updateDropPosition(for:)` runs on every drag event but only mutates `widgetOrder` when the target index changes:

1. Compute floating card center Y: `liftOrigin.midY + dragOffset.height`
2. Scan `widgetOrder` (excluding the dragging card), look up each card's `midY` from `cardFrames`
3. Count how many other cards have `midY < floatingCenterY` — this is `newIndex`
4. If `newIndex == lastHoverIndex`, return early (no animation queued)
5. Otherwise update `lastHoverIndex = newIndex` and call `widgetOrder.move(fromOffsets:toOffset:)` with a `.spring(response: 0.3, dampingFraction: 0.85)` animation

Edge case: single card — no other cards to scan, `lastHoverIndex` never changes, no spurious reorders.

## Visual Rendering

**Ghost (inside VStack):**
- Same `WidgetCard` as today
- `.opacity(draggingModule == module ? 0.3 : 1.0)`
- Shadow suppressed when ghost: `.shadow(color: draggingModule == module ? .clear : .black.opacity(0.06), radius: 6, y: 2)`
- No `.offset()` or `.scaleEffect()` — ghost stays in natural layout position

**Floating card (ZStack overlay):**
```swift
if let module = draggingModule {
    WidgetCard(module: module, children: children, onAddChild: nil)
        .frame(width: cardWidth)
        .scaleEffect(1.05)
        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
        .position(x: liftOrigin.midX,
                  y: liftOrigin.midY + dragOffset.height)
        .allowsHitTesting(false)
}
```

`.allowsHitTesting(false)` prevents the floating card from consuming taps on the ghost beneath it.

## Drop

On gesture end, `draggingModule` springs to `nil` and the floating card disappears. The ghost at the correct position in the VStack fades back to full opacity. No explicit snap animation needed — the card is already in the right slot.

## Scroll Lock

`scrollDisabled = true` on long-press, `false` on gesture end — same as today. Since scrolling is locked for the entire drag, `liftOrigin` remains valid.

## Persistence

`widgetOrder` is mutated live during drag (ghost moves with it). The existing `onChange(of: widgetOrder) { saveWidgetOrder() }` is unchanged.
