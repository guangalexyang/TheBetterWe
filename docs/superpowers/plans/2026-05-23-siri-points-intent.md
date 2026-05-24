# Siri Points Intent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `AddPointsIntent` and `DeductPointsIntent` App Intents so parents can award or deduct points for children via Siri, with a shared `PointsIntentSupport` helper ready for future intents.

**Architecture:** Four new Swift files in the `Intents/` directory, all added to the main app target (no extension target needed — App Intents framework handles background launch automatically). Error cases throw `LocalizedError` values; Siri displays `errorDescription` and the user opens the app manually. Confirmation dialogs use `requestConfirmation(result:)`. No new server endpoints — reuses the existing `POST /families/:familyId/point-system/events`.

**Tech Stack:** Swift, App Intents framework (iOS 16+), existing `AuthService` / `FamilyService` / `PointSystemService`

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `Intents/PointsIntentSupport.swift` | Create | `PointsIntentError` enum + `requireParentMembership` + `resolveChild` + `adjustPoints` |
| `Intents/AddPointsIntent.swift` | Create | Add points intent — parameters, confirmation, `perform()` |
| `Intents/DeductPointsIntent.swift` | Create | Deduct points intent — parameters, confirmation, `perform()` |
| `Intents/TheBetterWeShortcuts.swift` | Create | `AppShortcutsProvider` — registers Siri phrases |
| `App/TheBetterWeApp.swift` | Modify | Call `updateAppShortcutParameters()` on launch |
| `Xcode project` | Modify | Add all four new files to the main target |
| `Resources/Localizable.xcstrings` | Modify | zh-Hans strings for intent error messages |

---

### Task 1: `PointsIntentSupport.swift`

**Files:**
- Create: `ios/TheBetterWe/TheBetterWe/Intents/PointsIntentSupport.swift`

- [ ] **Step 1: Create the file with the full implementation**

```swift
import AppIntents
import Foundation

// MARK: - Error

enum PointsIntentError: LocalizedError {
    case notLoggedIn
    case notParent
    case childNotFound
    case childAmbiguous
    case network

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:    return String(localized: "Please log in to TheBetterWe first.")
        case .notParent:      return String(localized: "Only parents can adjust points.")
        case .childNotFound:  return String(localized: "Couldn't find that child. Please open TheBetterWe.")
        case .childAmbiguous: return String(localized: "Multiple children match that name. Please open TheBetterWe.")
        case .network:        return String(localized: "Network error. Please try again.")
        }
    }
}

// MARK: - Support

enum PointsIntentSupport {

    /// Verifies the user is logged in and is a parent (not a child role).
    /// Uses memberships[0] — same family selection as the main app.
    static func requireParentMembership() async throws -> FamilyMembership {
        guard AuthService.isAuthenticated else { throw PointsIntentError.notLoggedIn }
        let memberships: [FamilyMembership]
        do {
            memberships = try await FamilyService.fetchMine()
        } catch {
            throw PointsIntentError.network
        }
        guard let membership = memberships.first else { throw PointsIntentError.network }
        guard !membership.roleKeywords.contains("child") else { throw PointsIntentError.notParent }
        return membership
    }

    /// Finds a unique child by matching `name` case-insensitively against any
    /// whitespace-separated token in each child's stored name.
    /// "Noah" matches "Noah Yang"; "Yang" also matches "Noah Yang".
    static func resolveChild(named name: String, familyId: Int) async throws -> PSChild {
        let children: [PSChild]
        do {
            children = try await PointSystemService.fetchChildren(familyId: familyId)
        } catch {
            throw PointsIntentError.network
        }
        let query = name.lowercased().trimmingCharacters(in: .whitespaces)
        let matches = children.filter { child in
            child.name
                .lowercased()
                .components(separatedBy: .whitespaces)
                .contains(query)
        }
        switch matches.count {
        case 0:  throw PointsIntentError.childNotFound
        case 1:  return matches[0]
        default: throw PointsIntentError.childAmbiguous
        }
    }

    /// Posts a point event and returns the child's new balance.
    /// Pass a positive delta to add, negative to deduct.
    static func adjustPoints(
        familyId: Int,
        memberId: Int,
        delta: Int,
        note: String?
    ) async throws -> Int {
        do {
            let response = try await PointSystemService.addPointEvent(
                familyId: familyId,
                memberId: memberId,
                delta: delta,
                note: note
            )
            return response.newBalance
        } catch PointSystemError.unauthorized {
            throw PointsIntentError.notLoggedIn
        } catch {
            throw PointsIntentError.network
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Intents/PointsIntentSupport.swift
git commit -m "feat: add PointsIntentSupport shared helper for Siri intents"
```

---

### Task 2: `AddPointsIntent.swift`

**Files:**
- Create: `ios/TheBetterWe/TheBetterWe/Intents/AddPointsIntent.swift`

- [ ] **Step 1: Create the file**

```swift
import AppIntents

struct AddPointsIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Points"
    static let description = IntentDescription("Add points to a child in TheBetterWe")

    @Parameter(title: "Child Name")
    var childName: String

    @Parameter(title: "Points")
    var amount: Int

    @Parameter(title: "Note")
    var note: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. Auth + role check — throws if not logged in or user is a child
        let membership = try await PointsIntentSupport.requireParentMembership()

        // 2. Resolve child — throws if not found or ambiguous
        let child = try await PointsIntentSupport.resolveChild(
            named: childName,
            familyId: membership.familyId
        )

        // 3. Confirmation dialog
        let pts = amount == 1 ? "point" : "points"
        let confirmMsg: String
        if let n = note, !n.isEmpty {
            confirmMsg = "Add \(amount) \(pts) to \(child.name) for \"\(n)\"?"
        } else {
            confirmMsg = "Add \(amount) \(pts) to \(child.name)?"
        }
        try await requestConfirmation(result: .result(dialog: IntentDialog(stringLiteral: confirmMsg)))

        // 4. Execute — throws PointsIntentError.network on failure
        let newBalance = try await PointsIntentSupport.adjustPoints(
            familyId: membership.familyId,
            memberId: child.memberId,
            delta: amount,
            note: note
        )

        // 5. Success dialog
        let successMsg: String
        if let n = note, !n.isEmpty {
            successMsg = "Added \(amount) \(pts) to \(child.name) for \"\(n)\". Balance: \(newBalance) pts."
        } else {
            successMsg = "Added \(amount) \(pts) to \(child.name). Balance: \(newBalance) pts."
        }
        return .result(dialog: IntentDialog(stringLiteral: successMsg))
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Intents/AddPointsIntent.swift
git commit -m "feat: add AddPointsIntent Siri App Intent"
```

---

### Task 3: `DeductPointsIntent.swift`

**Files:**
- Create: `ios/TheBetterWe/TheBetterWe/Intents/DeductPointsIntent.swift`

- [ ] **Step 1: Create the file**

```swift
import AppIntents

struct DeductPointsIntent: AppIntent {
    static let title: LocalizedStringResource = "Deduct Points"
    static let description = IntentDescription("Deduct points from a child in TheBetterWe")

    @Parameter(title: "Child Name")
    var childName: String

    @Parameter(title: "Points")
    var amount: Int

    @Parameter(title: "Note")
    var note: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. Auth + role check — throws if not logged in or user is a child
        let membership = try await PointsIntentSupport.requireParentMembership()

        // 2. Resolve child — throws if not found or ambiguous
        let child = try await PointsIntentSupport.resolveChild(
            named: childName,
            familyId: membership.familyId
        )

        // 3. Confirmation dialog
        let pts = amount == 1 ? "point" : "points"
        let confirmMsg: String
        if let n = note, !n.isEmpty {
            confirmMsg = "Deduct \(amount) \(pts) from \(child.name) for \"\(n)\"?"
        } else {
            confirmMsg = "Deduct \(amount) \(pts) from \(child.name)?"
        }
        try await requestConfirmation(result: .result(dialog: IntentDialog(stringLiteral: confirmMsg)))

        // 4. Execute with negative delta — throws PointsIntentError.network on failure
        let newBalance = try await PointsIntentSupport.adjustPoints(
            familyId: membership.familyId,
            memberId: child.memberId,
            delta: -amount,
            note: note
        )

        // 5. Success dialog
        let successMsg: String
        if let n = note, !n.isEmpty {
            successMsg = "Deducted \(amount) \(pts) from \(child.name) for \"\(n)\". Balance: \(newBalance) pts."
        } else {
            successMsg = "Deducted \(amount) \(pts) from \(child.name). Balance: \(newBalance) pts."
        }
        return .result(dialog: IntentDialog(stringLiteral: successMsg))
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Intents/DeductPointsIntent.swift
git commit -m "feat: add DeductPointsIntent Siri App Intent"
```

---

### Task 4: `TheBetterWeShortcuts.swift` — register Siri phrases

**Files:**
- Create: `ios/TheBetterWe/TheBetterWe/Intents/TheBetterWeShortcuts.swift`

The `AppShortcutsProvider` is what makes "Hey Siri, add 2 points…" work without the user manually building a Shortcut. The phrases use `\(\.$param)` syntax to reference intent parameters. `.applicationName` expands to the app's display name.

- [ ] **Step 1: Create the file**

```swift
import AppIntents

struct TheBetterWeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddPointsIntent(),
            phrases: [
                "Add \(\.$amount) points to \(\.$childName) in \(.applicationName)",
                "Add \(\.$amount) points to \(\.$childName) for \(\.$note) in \(.applicationName)"
            ],
            shortTitle: "Add Points",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: DeductPointsIntent(),
            phrases: [
                "Deduct \(\.$amount) points from \(\.$childName) in \(.applicationName)",
                "Deduct \(\.$amount) points from \(\.$childName) for \(\.$note) in \(.applicationName)"
            ],
            shortTitle: "Deduct Points",
            systemImageName: "minus.circle"
        )
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Intents/TheBetterWeShortcuts.swift
git commit -m "feat: register Siri App Shortcuts phrases for points intents"
```

---

### Task 5: Update `TheBetterWeApp.swift` — donate shortcuts on launch

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/App/TheBetterWeApp.swift`

Calling `updateAppShortcutParameters()` on every launch tells Siri to re-index the phrases promptly. Without it, Siri may take hours to discover newly installed intents.

- [ ] **Step 1: Add `import AppIntents` and the donation call**

Replace the entire file with:

```swift
import SwiftUI
import SwiftData
import AppIntents

@main
struct TheBetterWeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    TheBetterWeShortcuts.updateAppShortcutParameters()
                    // Replace with real server base URL when backend is live.
                    // guard let url = URL(string: "https://api.thebetterwe.com") else { return }
                    // await FeatureToggle.shared.fetch(from: url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/App/TheBetterWeApp.swift
git commit -m "feat: donate Siri App Shortcuts on app launch"
```

---

### Task 6: Add new files to Xcode target and verify build

Swift files created outside Xcode are not automatically included in the build. They must be added to the target manually.

- [ ] **Step 1: Open the project in Xcode**

```bash
open ios/TheBetterWe/TheBetterWe.xcodeproj
```

- [ ] **Step 2: Add the four new files to the TheBetterWe target**

In the Project Navigator, right-click the `Intents` group → **Add Files to "TheBetterWe"…** → select all four files:
- `PointsIntentSupport.swift`
- `AddPointsIntent.swift`
- `DeductPointsIntent.swift`
- `TheBetterWeShortcuts.swift`

Ensure **"Add to targets: TheBetterWe"** is checked. Click Add.

- [ ] **Step 3: Build (⌘B)**

Expected: Build succeeds with no errors.

If you see `No such module 'AppIntents'`: open Project settings → target → General → Minimum Deployments → set iOS to **16.0** or higher.

If you see `Type 'TheBetterWeShortcuts' does not conform to protocol 'AppShortcutsProvider'`: ensure all four files are in the target (check File Inspector for each file — "Target Membership" must include TheBetterWe).

- [ ] **Step 4: Commit the updated project file**

```bash
git add ios/TheBetterWe/TheBetterWe.xcodeproj/project.pbxproj
git commit -m "chore: add Siri intent files to Xcode target"
```

---

### Task 7: zh-Hans localizations for intent error strings

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Resources/Localizable.xcstrings`

The five `String(localized:)` keys in `PointsIntentError.errorDescription` need Chinese translations. Confirmation and success dialog strings use runtime string interpolation and are English-only for now.

- [ ] **Step 1: Build once (⌘B) so Xcode extracts the new string keys**

After the build, open `Localizable.xcstrings` in Xcode. The five new keys should appear with state "New" or "Needs Review".

- [ ] **Step 2: Add zh-Hans translations**

In the xcstrings editor, set the Chinese (Simplified) value for each key:

| Key | zh-Hans value |
|-----|--------------|
| `"Please log in to TheBetterWe first."` | `"请先登录 TheBetterWe。"` |
| `"Only parents can adjust points."` | `"只有家长可以调整积分。"` |
| `"Couldn't find that child. Please open TheBetterWe."` | `"找不到该孩子，请打开 TheBetterWe。"` |
| `"Multiple children match that name. Please open TheBetterWe."` | `"多个孩子匹配该名字，请打开 TheBetterWe。"` |
| `"Network error. Please try again."` | `"网络错误，请重试。"` |

- [ ] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Resources/Localizable.xcstrings
git commit -m "feat: add zh-Hans localizations for Siri intent error strings"
```

---

### Task 8: Manual Siri verification

App Intents have no automated tests. Verify each scenario on device or simulator.

**Prerequisites:** App built and installed on device/simulator. Local server running (`cd server && npm run dev`). Logged in as a parent with at least one child in the point system.

- [ ] **Happy path — add points without note**

Say: *"Hey Siri, add 2 points to [child first name] in TheBetterWe"*

Expected flow:
1. Siri shows: *"Add 2 points to [child name]?"*
2. Say "Yes"
3. Siri shows: *"Added 2 points to [child name]. Balance: X pts."*
4. Open the app → verify the child's balance increased by 2

- [ ] **Happy path — add points with note**

Say: *"Hey Siri, add 3 points to [child first name] for piano practice in TheBetterWe"*

Expected:
1. Confirmation: *"Add 3 points to [child name] for "piano practice"?"*
2. Say "Yes"
3. Result: *"Added 3 points to [child name] for "piano practice". Balance: X pts."*
4. Open app → verify balance and check the note appears in point records

- [ ] **Happy path — deduct points**

Say: *"Hey Siri, deduct 1 point from [child first name] in TheBetterWe"*

Expected:
1. Confirmation: *"Deduct 1 point from [child name]?"* (singular "point")
2. Say "Yes"
3. Result: *"Deducted 1 point from [child name]. Balance: X pts."*
4. Open app → verify balance decreased by 1

- [ ] **Cancellation**

Say the add command → when Siri shows confirmation → say "No"

Expected: Siri dismisses silently. Open app → verify balance is unchanged.

- [ ] **Error — not logged in**

Log out of the app. Say: *"Hey Siri, add 2 points to [child name] in TheBetterWe"*

Expected: Siri shows *"Please log in to TheBetterWe first."*

- [ ] **Error — child not found**

Say: *"Hey Siri, add 2 points to Zzzzz in TheBetterWe"*

Expected: Siri shows *"Couldn't find that child. Please open TheBetterWe."*

- [ ] **Final commit**

```bash
git commit --allow-empty -m "chore: Siri points intent verified manually"
```
