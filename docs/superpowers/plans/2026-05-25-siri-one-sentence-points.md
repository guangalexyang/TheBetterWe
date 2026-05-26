# Siri One-Sentence Point Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace generic AppShortcut trigger phrases with parameterized phrase templates so parents can add/deduct points in one spoken sentence with no Siri follow-up questions.

**Architecture:** Only `TheBetterWeShortcuts.swift` changes. Parameterized phrase templates (`\(.$parameterName)` slots) pre-fill all intent parameters from a single utterance. All intent logic, confirmation step, fuzzy child resolution, and API calls in `AddPointsIntent.swift` and `DeductPointsIntent.swift` are untouched.

**Tech Stack:** Swift, AppIntents framework (iOS 16+). No server changes. No new files.

---

## File Map

| Action | File | What changes |
|--------|------|-------------|
| Modify | `ios/TheBetterWe/TheBetterWe/Intents/TheBetterWeShortcuts.swift` | Replace generic phrases with parameterized phrase templates |

**Read-only reference (do not modify):**
- `ios/TheBetterWe/TheBetterWe/Intents/AddPointsIntent.swift` — parameter names: `childName: String`, `amount: Int`, `note: String?`
- `ios/TheBetterWe/TheBetterWe/Intents/DeductPointsIntent.swift` — parameter names: `childName: String`, `amount: Int`, `note: String?`

---

## Task 1: Update AppShortcut Phrases

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Intents/TheBetterWeShortcuts.swift`

> **Note on TDD:** AppShortcut phrase matching cannot be unit tested — Siri's NLU runs on-device. The verification step (Task 2) is the functional test. Make the code change first, then verify manually.

- [ ] **Step 1: Replace the contents of `TheBetterWeShortcuts.swift`**

Open `ios/TheBetterWe/TheBetterWe/Intents/TheBetterWeShortcuts.swift` and replace the entire file with:

```swift
import AppIntents

struct TheBetterWeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddPointsIntent(),
            phrases: [
                // Parameterized — Siri fills all params from one utterance
                "Add \(.$amount) points to \(.$childName) in \(.applicationName)",
                "Add \(.$amount) points to \(.$childName) for \(.$note) in \(.applicationName)",
                "Give \(.$childName) \(.$amount) points in \(.applicationName)",
                "用\(.applicationName)给\(.$childName)加\(.$amount)分",
                "用\(.applicationName)给\(.$childName)加\(.$amount)分，原因是\(.$note)",
                // Generic fallback — Siri asks for each parameter interactively
                "Add points in \(.applicationName)",
                "Award points in \(.applicationName)",
                "用\(.applicationName)加分"
            ],
            shortTitle: "Add Points",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: DeductPointsIntent(),
            phrases: [
                // Parameterized — Siri fills all params from one utterance
                "Deduct \(.$amount) points from \(.$childName) in \(.applicationName)",
                "Deduct \(.$amount) points from \(.$childName) for \(.$note) in \(.applicationName)",
                "用\(.applicationName)给\(.$childName)扣\(.$amount)分",
                "用\(.applicationName)给\(.$childName)扣\(.$amount)分，原因是\(.$note)",
                // Generic fallback — Siri asks for each parameter interactively
                "Deduct points in \(.applicationName)",
                "Remove points in \(.applicationName)",
                "用\(.applicationName)扣分"
            ],
            shortTitle: "Deduct Points",
            systemImageName: "minus.circle"
        )
    }
}
```

**Why this works:**
- `\(.$amount)` → Siri parses spoken number into `amount: Int`
- `\(.$childName)` → Siri captures the name token into `childName: String`, which `resolveChild()` fuzzy-matches
- `\(.$note)` → Siri captures everything between "for" / "原因是" and "in TheBetterWe" as `note: String?`
- With-note and without-note variants are disambiguated by presence of "for" / "原因是" in the utterance
- Generic fallback phrases are kept so the old conversational flow still works when details aren't known upfront

- [ ] **Step 2: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Intents/TheBetterWeShortcuts.swift
git commit -m "feat: add parameterized Siri phrases for one-sentence point entry"
```

---

## Task 2: Verify in Shortcuts App (Simulator)

> Voice input does not work in Simulator. Use the **Shortcuts app** to trigger `perform()` with pre-filled parameters instead.

**Files:** None — verification only.

- [ ] **Step 1: Build and run on Simulator**

In Xcode, select any iPhone simulator (iOS 16+) and press ▶ Run. The app must launch successfully before the Shortcuts app can find the intents.

- [ ] **Step 2: Open the Shortcuts app on the Simulator**

In the Simulator, find and open the **Shortcuts** app (comes pre-installed). Tap the **+** button to create a new shortcut, then search for **TheBetterWe**. You should see both **Add Points** and **Deduct Points** listed.

- [ ] **Step 3: Verify Add Points — with note, no back-and-forth**

Tap **Add Points**. In the shortcut editor, the action should show three inline fields: **Child Name**, **Points**, **Note**. Fill them in:
- Child Name: the name of an existing child in your test family (e.g. "Noah")
- Points: `5`
- Note: `doing homework`

Tap ▶ Run. Expected outcome:
1. A confirmation dialog appears: *"Add 5 points to Noah for doing homework?"*
2. Tap **Confirm**
3. Success dialog: *"Added 5 points to Noah for doing homework. Balance: [N] pts."*

No Siri question dialogs should appear between steps 1 and 3.

- [ ] **Step 4: Verify Add Points — without note**

Create another shortcut with **Add Points**, fill Child Name and Points only, leave Note blank. Run it. Expected:
1. Confirmation: *"Add 5 points to Noah?"*
2. Confirm
3. Success: *"Added 5 points to Noah. Balance: [N] pts."*

- [ ] **Step 5: Verify Deduct Points**

Create a shortcut with **Deduct Points**, fill Child Name: "Noah", Points: `3`, Note: `left toys out`. Run it. Expected:
1. Confirmation: *"Deduct 3 points from Noah for left toys out?"*
2. Confirm
3. Success: *"Deducted 3 points from Noah for left toys out. Balance: [N] pts."*

- [ ] **Step 6: Verify error handling — unknown child**

Create an **Add Points** shortcut with Child Name: `zzunknownchild`, Points: `1`. Run it. Expected: Siri/Shortcuts surfaces the error *"Couldn't find that child. Please open TheBetterWe."* — no crash, no partial execution.

- [ ] **Step 7: Verify generic fallback still works**

Add an **Add Points** action to a shortcut but leave **all three fields blank**. Run it. Expected: Siri asks for Child Name, then Points, then (optionally) Note — the old conversational flow. This confirms the fallback phrases still function.
