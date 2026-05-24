# UI Design Practices

## Style Constants

Every feature area gets a dedicated `<Feature>Style.swift` enum in its Views subfolder. No magic numbers in view files — always reference named constants.

```swift
// Views/Auth/AuthStyle.swift
enum AuthStyle {
    static let screenHPadding: CGFloat = 24
    static let topRowHeight: CGFloat = 44
    static let sectionSpacing: CGFloat = 32
    static let fieldSpacing: CGFloat = 14
    static let fieldHPadding: CGFloat = 16
    static let fieldVPadding: CGFloat = 14
    static let fieldCornerRadius: CGFloat = 12
    static let fieldIconWidth: CGFloat = 20
    static let fieldDividerHeight: CGFloat = 22
    static let buttonVPadding: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 14
}

extension Color {
    static let authPink = Color(red: 1.0, green: 0.71, blue: 0.76)
}
```

Color extensions belong in the same `<Feature>Style.swift` file — not in view files.

---

## Navigation Transitions

When two screens share a push/pop transition, both must have the same navigation bar visibility or content will jump when the bar animates in/out.

**Rule:** Hide the nav bar on both screens. Manage the back button manually inside the view's `VStack` so both screens share identical layout structure.

```swift
// Parent screen (e.g. LoginView)
.toolbar(.hidden, for: .navigationBar)
// Add a clear spacer matching the child's back-button row height
Color.clear.frame(height: AuthStyle.topRowHeight)

// Child screen (e.g. SignUpView)
.navigationBarBackButtonHidden()
.toolbar(.hidden, for: .navigationBar)
// Back button sits inside the VStack at the same height
HStack {
    Button { dismiss() } label: {
        Image(systemName: "chevron.left").font(.body.bold())
    }
    Spacer()
}
.frame(height: AuthStyle.topRowHeight)
```

---

## Form Fields

Standard field layout: icon + vertical divider + text field inside a gray rounded rect.

```swift
HStack(spacing: 12) {
    Image(systemName: "person")
        .foregroundStyle(.secondary)
        .frame(width: AuthStyle.fieldIconWidth)
    Divider().frame(height: AuthStyle.fieldDividerHeight)
    TextField("Placeholder", text: $value)
}
.padding(.horizontal, AuthStyle.fieldHPadding)
.padding(.vertical, AuthStyle.fieldVPadding)
.background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: AuthStyle.fieldCornerRadius))
```

Password fields use an eye button (left side) to toggle visibility between `SecureField` and `TextField`.

---

## Password Fields (Sign-Up)

Apply `.textContentType(.oneTimeCode)` to **both** the password and confirm-password fields. This prevents iOS from showing the "Use Strong Password" sheet and auto-filling both fields at once.

```swift
SecureField("Create a password", text: $password)
    .textContentType(.oneTimeCode)

SecureField("Confirm your password", text: $confirmPassword)
    .textContentType(.oneTimeCode)
```

---

## Form Validation

Express validation as private computed properties on the view — not inline in the body. The submit button reads a single `canSubmit` bool.

```swift
private var hasLength: Bool { password.count >= 6 }
private var hasLetter: Bool { password.rangeOfCharacter(from: .letters) != nil }
private var hasNumber: Bool { password.rangeOfCharacter(from: .decimalDigits) != nil }
private var isPasswordValid: Bool { hasLength && hasLetter && hasNumber }
private var canSignUp: Bool { !username.isEmpty && isPasswordValid && passwordsMatch }
```

Show inline validation hints with a `@ViewBuilder` helper:

```swift
@ViewBuilder
private func validationRow(text: String, passed: Bool) -> some View {
    HStack(spacing: 6) {
        Image(systemName: passed ? "checkmark" : "xmark")
            .font(.caption.bold())
            .foregroundStyle(passed ? .green : Color(.systemGray3))
        Text(text)
            .font(.caption)
            .foregroundStyle(passed ? .primary : Color(.systemGray3))
    }
}
```

Disabled buttons use a lighter background — never hide them.

```swift
.background(canSignUp ? Color.red : Color.red.opacity(0.3))
.disabled(!canSignUp)
```

Validation helper functions that are shared between views belong in a dedicated `<Feature>Validator.swift` enum — not duplicated on each view.

```swift
// Views/Auth/PasswordValidator.swift
enum PasswordValidator {
    static func hasLength(_ password: String) -> Bool { password.count >= 6 }
    static func hasLetter(_ password: String) -> Bool { password.rangeOfCharacter(from: .letters) != nil }
    static func hasNumber(_ password: String) -> Bool { password.rangeOfCharacter(from: .decimalDigits) != nil }
    static func isValid(_ password: String) -> Bool { hasLength(password) && hasLetter(password) && hasNumber(password) }
}
```

Pass `LocalizedStringKey` (not `String`) to `@ViewBuilder` helpers that render `Text`, otherwise localization is bypassed.

```swift
private func validationRow(text: LocalizedStringKey, passed: Bool) -> some View { ... }
```

---

## Localization

### Rule: English keys only in Swift

The project's `sourceLanguage` is `"en"`. All string literals passed to `Text()`, `TextField()`, `LocalizedStringKey`, etc. **must be in English**. Chinese (and any other language) goes only in `Localizable.xcstrings` as a translation.

```swift
// ✅ correct — English key, Chinese translation in xcstrings
Text("Home")         // shows "Home" in EN, "我家" in ZH

// ❌ wrong — Chinese key, no English fallback
Text("我家")         // shows "我家" in EN too, translation never applies
```

### xcstrings entry pattern

```json
"Home" : {
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : { "state" : "translated", "value" : "我家" }
    }
  }
}
```

### LocalizedStringKey in helpers

Pass `LocalizedStringKey` (not `String`) to any `@ViewBuilder` helper that renders `Text`, otherwise SwiftUI treats the value as verbatim and skips localization lookup.

```swift
// ✅
private func validationRow(text: LocalizedStringKey, passed: Bool) -> some View

// ❌ — localization bypassed
private func validationRow(text: String, passed: Bool) -> some View
```

### Testing translations

- **In Xcode preview**: add a second `#Preview` with `.environment(\.locale, .init(identifier: "zh-Hans"))`
- **In simulator**: Settings → General → Language & Region → Preferred Languages → add Chinese (Simplified), drag to top, restart

---

## Async Button Actions

Buttons that call a backend use a loading state to block double-taps and show feedback during the wait.

```swift
@State private var isLoading = false
@State private var errorMessage: String? = nil

Button {
    isLoading = true
    errorMessage = nil
    Task {
        do {
            try await SomeService.doAction(...)
            isLoading = false
            // handle success (navigate, update state, etc.)
        } catch SomeError.unauthorized {
            isLoading = false
            onLogOut()
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
} label: {
    Group {
        if isLoading {
            ProgressView().tint(.white)
        } else {
            Text("Submit").font(.body.bold())
        }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, AuthStyle.buttonVPadding)
    .background(canSubmit ? Color.accentColor : Color.accentColor.opacity(0.3))
    .foregroundStyle(.white)
    .clipShape(RoundedRectangle(cornerRadius: AuthStyle.buttonCornerRadius))
}
.disabled(!canSubmit || isLoading)

if let msg = errorMessage {
    Text(verbatim: msg).font(.caption).foregroundStyle(.red)
}
```

---

## Localization Previews

Always add both language previews so translations are visible without changing simulator language.

```swift
#Preview("English") { LoginView() }
#Preview("中文") { LoginView().environment(\.locale, .init(identifier: "zh-Hans")) }
```

---

## Expandable List Rows

For inline expand/collapse rows (one open at a time), use a single optional enum state. Only one row can be open because assigning a new value automatically closes the previous one.

```swift
private enum ExpandedRow: Equatable { case add, deduct }
@State private var expandedRow: ExpandedRow? = nil

// In the row button action:
withAnimation(.easeInOut(duration: 0.22)) {
    expandedRow = isOpen ? nil : row   // toggle; opening one closes the other
}
```

Do **not** add `.transition` or `.clipped()` to the panel. Any `.transition` modifier causes visual artifacts (fly-in, fade) that fight the layout animation. `withAnimation` alone handles the height change — the content just appears and disappears with the expanding container.

```swift
VStack(spacing: 0) {
    Button { ... } label: { ... }
        .buttonStyle(.plain)

    if isOpen {
        expandedPanel
        // no .transition, no .clipped()
    }
}
```

Chevron rotation signals open state:

```swift
Image(systemName: "chevron.right")
    .rotationEffect(.degrees(isOpen ? 90 : 0))
    .animation(.easeInOut(duration: 0.22), value: isOpen)
```

---

## State Reset on Identity Change

When a view has local `@State` that should reset whenever the driving data changes (e.g. swiping to a different child), add `.id(dataItem.id)`. SwiftUI destroys and recreates the view, clearing all `@State`.

```swift
// Without .id — expandedRow stays open when child switches (bug)
ChildContentView(child: children[selectedIndex])

// With .id — state resets on every child change
ChildContentView(child: children[selectedIndex])
    .id(children[selectedIndex].id)
```

---

## @ViewBuilder func vs. struct View

`@ViewBuilder func` helpers cannot hold `@State`. If a helper needs local state (expand/collapse, navigation flag), make it a `private struct` instead.

```swift
// ❌ wrong — @State not allowed in a @ViewBuilder func
@ViewBuilder
private func childContent(child: PSChild?) -> some View {
    @State var expandedRow: ExpandedRow? = nil  // compiler error
    ...
}

// ✅ correct — private struct owns its @State
private struct ChildContentView: View {
    let child: PSChild
    @State private var expandedRow: ExpandedRow? = nil
    ...
}
```

---

## Number Formatting

Use SwiftUI's built-in format style for locale-aware grouping separators instead of string interpolation.

```swift
// ❌ — no grouping separator, not locale-aware
Text("\(child.balance)")

// ✅ — shows "1,280" in EN, respects locale
Text(child.balance, format: .number)
```

---

## ViewThatFits — Centered or Scrollable

To build a row that centers its content when it fits and scrolls when it overflows, put `.frame(maxWidth: .infinity)` on the `ViewThatFits` **container**, never on a candidate inside it. A candidate with `maxWidth: .infinity` always claims the proposed width, so `ViewThatFits` always picks it and the scroll fallback is never reached.

```swift
// ❌ wrong — HStack always wins, ScrollView is unreachable
ViewThatFits(in: .horizontal) {
    HStack(spacing: 8) { tabs }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .center)  // always fits
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) { tabs }.padding(.horizontal, 16)
    }
}

// ✅ correct — HStack reports natural width; ScrollView activates when tabs overflow
ViewThatFits(in: .horizontal) {
    HStack(spacing: 8) { tabs }
        .padding(.horizontal, 16).padding(.vertical, 10)
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) { tabs }
            .padding(.horizontal, 16).padding(.vertical, 10)
    }
}
.frame(maxWidth: .infinity)  // ← on the container, not inside
.background(Color(.systemBackground))
```

---

## Safe Array Subscript with Dynamic Data

When a view subscripts an array with a `@State` index, guard against the array shrinking. SwiftUI re-renders `body` immediately on state change, but `onChange(of:)` fires *after* the render. A stale index crashes before the clamp runs.

```swift
// ❌ crashes when loadChildren() returns fewer children than selectedIndex
ChildFullView(child: children[selectedIndex])

// ✅ safe at every render
let safeIndex = min(selectedIndex, children.count - 1)
ChildFullView(child: children[safeIndex])
    .id(children[safeIndex].id)
```

Keep the `onChange` clamp too — it updates the stored index for subsequent renders:

```swift
.onChange(of: children) { _, newValue in
    if selectedIndex >= newValue.count {
        selectedIndex = max(0, newValue.count - 1)
    }
}

---

## Tinted Reusable Action Forms

When two actions (e.g. Add / Deduct) share the same form layout but differ only in color and label, build one component and pass an `ActionStyle` (color + label) in — never duplicate the layout.

```swift
struct ActionStyle {
    let tint: Color
    let confirmLabel: LocalizedStringKey
}

// Usage
PointAdjustFormView(style: .add)    // blue tint, "Add Points"
PointAdjustFormView(style: .deduct) // red tint,  "Deduct Points"
```

The tint propagates to: stepper ± buttons, editable number cursor, "More" text link, and confirm button gradient.

---

## Round Floating Stepper

For numeric input where keyboard is secondary to ± tapping, use floating circular buttons flanking a large central number — not a UIKit-style segmented control bar (which reads dated).

```
  ╭──────╮          ╭──────╮
  │  −   │    2     │  +   │
  │      │  POINTS  │      │
  ╰──────╯          ╰──────╯
       tap to edit
```

- Buttons: circle, white background, 1.5pt border, shadow, `font(.system(size:22, weight:.light))`
- Number: large bold, tinted color when editing (blue cursor appears, buttons dim to 0.35 opacity)
- "tap to edit" hint sits **below** the stepper row (not inside the value), hidden while editing
- Default value starts at a sensible low number (e.g. 2) so the user almost always adjusts up

---

## Scrollable Content Sections

When a content section contains expandable rows (or any dynamically growing content), wrap it in `ScrollView` so the bottom tab bar stays fixed and the content scrolls rather than pushing the bar off-screen.

```swift
var body: some View {
    ScrollView {
        VStack(spacing: 0) {
            headerCard
            actionList   // may expand with inline forms
        }
    }
    .background(Color(.systemBackground))
}
```

Do not add `Spacer(minLength: 0)` inside a `ScrollView` — it has no effect and the scroll view handles sizing automatically.

---

## Widget Card Theme Pattern

Dashboard widget cards use a two-property theme per module: a `LinearGradient` header and a soft tinted body background. Define both in a `private extension AppModule` inside the view file — never in the model.

```swift
private extension AppModule {
    var widgetHeaderGradient: LinearGradient {
        switch self {
        case .pointSystem:
            return LinearGradient(
                colors: [Color(red: 58/255, green: 123/255, blue: 213/255),
                         Color(red: 91/255, green: 168/255, blue: 245/255)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        // ... other cases
        }
    }

    var widgetBodyBackground: Color {
        // Leading gradient color at 9% opacity
        Color(red: 58/255, green: 123/255, blue: 213/255).opacity(0.09)
    }
}
```

Apply them in the card shell — body background at the card level, not inside sub-views:

```swift
VStack(spacing: 0) {
    headerBar.background(module.widgetHeaderGradient)
    cardBody.background(module.widgetBodyBackground)  // ← here, not inside sub-views
}
.clipShape(RoundedRectangle(cornerRadius: 16))
```

Sub-views must **not** set their own `.background(Color(.systemBackground))` — that overrides the card-level tint.

---

## Gender-Tinted List Rows

When showing children in a list, use `child.gender.tintColor` (from `Optional<ChildGender>` extension) for balance/pts text, and gender gradient circles with emoji avatars — not letter initials. This keeps the visual language consistent with `PointSystemView`.

```swift
// Avatar
ZStack {
    Circle().fill(LinearGradient(colors: child.gender.gradientColors,
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
    Text(child.gender.avatarEmoji).font(.system(size: 16))
}
.frame(width: 36, height: 36)

// Balance
Text("\(child.balance, format: .number) pts")
    .foregroundStyle(child.gender.tintColor)
```

---

## Multiline TextField Minimum Height

`TextField(axis: .vertical)` returns near-zero intrinsic height when empty on iOS 26+. Always add `.frame(minHeight: 24)` on the text field itself (before padding) to ensure it is visible and tappable.

```swift
TextField("Note (optional)", text: $text, axis: .vertical)
    .frame(minHeight: 24)          // ← before padding
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(.white)
    .clipShape(RoundedRectangle(cornerRadius: 10))
```
