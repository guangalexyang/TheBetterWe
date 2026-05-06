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

## Async Button Actions

Buttons that will eventually call a backend use a loading state to block double-taps and show feedback during the wait.

```swift
@State private var isLoading = false

Button {
    isLoading = true
    Task {
        try? await Task.sleep(for: .seconds(2)) // replace with real call
        isLoading = false
    }
} label: {
    Group {
        if isLoading {
            ProgressView().tint(.white)
        } else {
            Text("Log In").font(.body.bold())
        }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, AuthStyle.buttonVPadding)
    .background(canLogIn ? Color.red : Color.red.opacity(0.3))
    .foregroundStyle(.white)
    .clipShape(RoundedRectangle(cornerRadius: AuthStyle.buttonCornerRadius))
}
.disabled(!canLogIn || isLoading)
```

When wiring up the real backend, replace `Task.sleep` with the async service call — everything else stays the same.

---

## Localization Previews

Always add both language previews so translations are visible without changing simulator language.

```swift
#Preview("English") { LoginView() }
#Preview("中文") { LoginView().environment(\.locale, .init(identifier: "zh-Hans")) }
```
