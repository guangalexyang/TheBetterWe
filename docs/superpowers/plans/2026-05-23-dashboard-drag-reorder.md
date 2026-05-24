# Dashboard Drag-to-Reorder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the jumpy, offset-based drag-reorder with a ghost + floating overlay approach that feels like iOS home screen icon dragging.

**Architecture:** When a drag starts, the card in the VStack becomes a semi-transparent ghost (holds the space, previews the drop slot). A full-opacity duplicate is placed in a ZStack overlay and follows the finger freely via `.position(x:y:)`. Reordering fires only when the floating card's center crosses another card's midpoint, guarded by a `lastHoverIndex` check to prevent animation stacking.

**Tech Stack:** SwiftUI, iOS 17+. Single file change: `DashboardView.swift`. No new files.

---

## File Map

| File | Change |
|------|--------|
| `ios/TheBetterWe/TheBetterWe/Views/Family/DashboardView.swift` | Rewrite drag state, view body, gesture, and reorder logic |

**Build command (run from repo root after each task):**
```bash
xcodebuild -project ios/TheBetterWe/TheBetterWe.xcodeproj \
  -scheme TheBetterWe \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)' | tail -5
```
Expected: `BUILD SUCCEEDED`

---

## Task 1: View hierarchy — ZStack + VStack + cardWidth

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Views/Family/DashboardView.swift`

**Context:** The current body has a bare `ScrollView` with a `LazyVStack`. Wrap it in a `ZStack` (to host the floating card overlay in Task 3), switch to `VStack` (so all card frames are always tracked — `LazyVStack` skips off-screen items), and capture the scroll area width into `cardWidth` state so the floating card can match the exact card width. No drag behavior changes in this task.

- [ ] **Step 1: Add `cardWidth` state**

In the `DashboardView` state block, after `@State private var scrollDisabled = false`, add:

```swift
@State private var cardWidth: CGFloat = 0
```

- [ ] **Step 2: Replace view body**

Replace the entire `var body: some View { ... }` with:

```swift
var body: some View {
    ZStack {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(widgetOrder, id: \.self) { module in
                    WidgetCard(
                        module: module,
                        children: children,
                        onAddChild: module == .pointSystem ? { showAddChild = true } : nil
                    )
                    .scaleEffect(draggingItem == module ? 1.03 : 1.0)
                    .opacity(draggingItem == module ? 0.85 : 1.0)
                    .zIndex(draggingItem == module ? 1 : 0)
                    .offset(draggingItem == module ? dragOffset : .zero)
                    .gesture(longPressThenDrag(for: module))
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: DashboardFramePreference.self,
                                value: [module: geo.frame(in: .named("dashboard"))]
                            )
                        }
                    )
                }
            }
            .padding(16)
        }
        .coordinateSpace(name: "dashboard")
        .scrollDisabled(scrollDisabled)
        .onPreferenceChange(DashboardFramePreference.self) { cardFrames = $0 }
        .task { await loadChildren() }
        .onAppear { loadWidgetOrder() }
        .onChange(of: widgetOrder) { _, _ in saveWidgetOrder() }
        .navigationDestination(isPresented: $showAddChild) {
            AddChildView(familyId: membership.familyId) { children.append($0) }
        }
    }
    .background(
        GeometryReader { geo in
            Color.clear.onAppear { cardWidth = geo.size.width - 32 }
        }
    )
}
```

Drag modifiers on `WidgetCard` are unchanged in this step — we replace them in Task 2.

- [ ] **Step 3: Build**

```bash
xcodebuild -project ios/TheBetterWe/TheBetterWe.xcodeproj \
  -scheme TheBetterWe \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)' | tail -5
```

Expected: `BUILD SUCCEEDED`. App looks and behaves identically to before.

- [ ] **Step 4: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Views/Family/DashboardView.swift
git commit -m "refactor: wrap dashboard in ZStack, switch LazyVStack→VStack, capture cardWidth"
```

---

## Task 2: Drag state + gesture + ghost rendering + reorder algorithm

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Views/Family/DashboardView.swift`

**Context:** All drag logic changes together in one task because the state variables, gesture, per-card modifiers, and reorder function are tightly coupled — changing state alone would break compilation. This task: replaces `draggingItem` with `draggingModule`; adds `liftOrigin` (card frame at lift moment) and `lastHoverIndex` (prevents redundant reorder animations); rewrites the gesture to capture `liftOrigin` and use `draggingModule`; replaces `reorder(dragging:at:)` with `updateDropPosition(for:)` (threshold-based, fires only when target slot changes); and sets ghost opacity on the card in the list.

- [ ] **Step 1: Update state declarations**

Replace:

```swift
@State private var draggingItem: AppModule? = nil
@State private var dragOffset: CGSize = .zero
```

with:

```swift
@State private var draggingModule: AppModule? = nil
@State private var dragOffset: CGSize = .zero
@State private var liftOrigin: CGRect = .zero
@State private var lastHoverIndex: Int? = nil
```

- [ ] **Step 2: Replace per-card drag modifiers in the ForEach**

In the `ForEach` inside the `VStack`, replace the four drag-specific modifiers on `WidgetCard`:

```swift
// Remove these four lines:
.scaleEffect(draggingItem == module ? 1.03 : 1.0)
.opacity(draggingItem == module ? 0.85 : 1.0)
.zIndex(draggingItem == module ? 1 : 0)
.offset(draggingItem == module ? dragOffset : .zero)
```

with a single ghost opacity line:

```swift
.opacity(draggingModule == module ? 0.3 : 1.0)
```

The complete `WidgetCard` block inside `ForEach` should now be:

```swift
WidgetCard(
    module: module,
    children: children,
    onAddChild: module == .pointSystem ? { showAddChild = true } : nil
)
.opacity(draggingModule == module ? 0.3 : 1.0)
.gesture(longPressThenDrag(for: module))
.background(
    GeometryReader { geo in
        Color.clear.preference(
            key: DashboardFramePreference.self,
            value: [module: geo.frame(in: .named("dashboard"))]
        )
    }
)
```

- [ ] **Step 3: Rewrite `longPressThenDrag`**

Replace the entire `longPressThenDrag(for:)` method with:

```swift
private func longPressThenDrag(for module: AppModule) -> some Gesture {
    LongPressGesture(minimumDuration: 0.4)
        .sequenced(before: DragGesture(coordinateSpace: .named("dashboard")))
        .onChanged { value in
            switch value {
            case .first(true):
                scrollDisabled = true
            case .second(_, let drag?):
                if draggingModule == nil {
                    liftOrigin = cardFrames[module] ?? .zero
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        draggingModule = module
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                dragOffset = drag.translation
                updateDropPosition(for: module)
            default:
                break
            }
        }
        .onEnded { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                draggingModule = nil
                dragOffset = .zero
                liftOrigin = .zero
            }
            lastHoverIndex = nil
            scrollDisabled = false
        }
}
```

- [ ] **Step 4: Replace `reorder` with `updateDropPosition`**

Delete the entire `reorder(dragging:at:)` method and replace it with:

```swift
private func updateDropPosition(for module: AppModule) {
    guard let fromIndex = widgetOrder.firstIndex(of: module) else { return }
    let floatingMidY = liftOrigin.midY + dragOffset.height

    // Count non-dragging cards whose center is above the floating card's center.
    // That count is the target slot index in the final order.
    var newIndex = 0
    for m in widgetOrder where m != module {
        guard let frame = cardFrames[m] else { continue }
        if floatingMidY > frame.midY { newIndex += 1 }
    }

    guard newIndex != lastHoverIndex else { return }
    lastHoverIndex = newIndex

    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
        widgetOrder.move(
            fromOffsets: IndexSet(integer: fromIndex),
            toOffset: newIndex > fromIndex ? newIndex + 1 : newIndex
        )
    }
}
```

**Why `newIndex + 1` when `newIndex > fromIndex`:** `Array.move(fromOffsets:toOffset:)` removes the element first, then inserts at `toOffset` in the smaller array. When the source is earlier than the destination, the indices shift by 1 after removal, so we add 1 to land in the correct slot. Example: `[A, B, C, D]`, move A (index 0) after C (newIndex=2) → `toOffset = 3` → removes A → `[B, C, D]` → inserts at 3 → `[B, C, D, A]`... wait that's wrong. Let me re-trace: `toOffset: 2 + 1 = 3` on original array `[A, B, C, D]` removes A to get `[B, C, D]` then inserts before index 3 (end) = `[B, C, D, A]`. Hmm — actually `move(fromOffsets:[0], toOffset:3)` on `[A,B,C,D]` gives `[B,C,A,D]`. The `toOffset` in `move` is "insert before this position in the original array", not the shrunken array. So `toOffset:3` means "insert before D (index 3 in original)" → `[B,C,A,D]`. That is correct for newIndex=2 (after 2 non-dragging cards B and C).

- [ ] **Step 5: Build**

```bash
xcodebuild -project ios/TheBetterWe/TheBetterWe.xcodeproj \
  -scheme TheBetterWe \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)' | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Manual smoke test in simulator**

Run the app. Long-press a card for 0.4 s, drag up and down. Verify:
- Cards reorder without jumping (ghost slides into new slot with spring animation)
- Each midpoint crossing triggers exactly one reorder — no stacked animations
- Releasing snaps to final position cleanly
- (Floating card not yet visible — that's Task 3)

- [ ] **Step 7: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Views/Family/DashboardView.swift
git commit -m "feat: ghost drag — threshold reorder, liftOrigin capture, remove offset-based jitter"
```

---

## Task 3: Floating card overlay

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Views/Family/DashboardView.swift`

**Context:** Add the floating `WidgetCard` as the second ZStack layer. It is positioned using `.position(x:y:)` at the card's lift origin plus drag translation, scaled 1.05×, and given a heavier shadow. `.allowsHitTesting(false)` prevents it from intercepting taps on the ghost beneath. This completes the iOS-home-screen drag experience.

- [ ] **Step 1: Add floating card inside the ZStack**

In `var body`, inside the `ZStack { }` block, after the closing brace + modifier chain of the `ScrollView` (before the closing `}` of the `ZStack`), add:

```swift
// Floating card — follows the finger during drag
if let module = draggingModule {
    WidgetCard(
        module: module,
        children: children,
        onAddChild: nil
    )
    .frame(width: cardWidth)
    .scaleEffect(1.05)
    .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
    .position(x: liftOrigin.midX, y: liftOrigin.midY + dragOffset.height)
    .allowsHitTesting(false)
}
```

The complete `ZStack` block should now look like:

```swift
ZStack {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(widgetOrder, id: \.self) { module in
                WidgetCard(
                    module: module,
                    children: children,
                    onAddChild: module == .pointSystem ? { showAddChild = true } : nil
                )
                .opacity(draggingModule == module ? 0.3 : 1.0)
                .gesture(longPressThenDrag(for: module))
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: DashboardFramePreference.self,
                            value: [module: geo.frame(in: .named("dashboard"))]
                        )
                    }
                )
            }
        }
        .padding(16)
    }
    .coordinateSpace(name: "dashboard")
    .scrollDisabled(scrollDisabled)
    .onPreferenceChange(DashboardFramePreference.self) { cardFrames = $0 }
    .task { await loadChildren() }
    .onAppear { loadWidgetOrder() }
    .onChange(of: widgetOrder) { _, _ in saveWidgetOrder() }
    .navigationDestination(isPresented: $showAddChild) {
        AddChildView(familyId: membership.familyId) { children.append($0) }
    }

    // Floating card — follows the finger during drag
    if let module = draggingModule {
        WidgetCard(
            module: module,
            children: children,
            onAddChild: nil
        )
        .frame(width: cardWidth)
        .scaleEffect(1.05)
        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
        .position(x: liftOrigin.midX, y: liftOrigin.midY + dragOffset.height)
        .allowsHitTesting(false)
    }
}
.background(
    GeometryReader { geo in
        Color.clear.onAppear { cardWidth = geo.size.width - 32 }
    }
)
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project ios/TheBetterWe/TheBetterWe.xcodeproj \
  -scheme TheBetterWe \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)' | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Full manual test in simulator**

Run the app. Long-press any card for 0.4 s, then drag:

| Check | Expected |
|-------|----------|
| Lift | Full-opacity floating card appears at card's exact position, scaled up with heavier shadow |
| Ghost | Original slot shows the card at ~30% opacity, holding the space |
| Drag up/down | Other cards slide smoothly to make room with spring animation |
| Midpoint crossing | Ghost moves to new slot — single clean slide, no jitter or stacking |
| Release | Floating card disappears, ghost at new slot snaps to full opacity |
| Reorder persists | Kill and relaunch app; cards appear in the new order |
| Tap still works | Tap "Add Child" in the point system card — sheet opens |

- [ ] **Step 4: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Views/Family/DashboardView.swift
git commit -m "feat: floating card overlay for iOS-style smooth drag-to-reorder"
```
