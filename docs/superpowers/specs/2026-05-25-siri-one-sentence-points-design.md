# Siri One-Sentence Point Entry — Design Spec

**Date:** 2026-05-25  
**Status:** Approved  
**Scope:** iOS App Intents — `TheBetterWeShortcuts.swift` only

---

## Problem

The current Siri points workflow is conversational: Siri asks for child name, then points, then note — one question at a time. This makes it slower than just opening the app.

## Goal

One spoken sentence → confirmation prompt → done.  
Example: *"Add 5 points to Noah for doing homework in TheBetterWe"*

---

## Solution: Parameterized AppShortcut Phrases

Replace generic trigger phrases with parameterized phrase templates that embed `\(.$parameterName)` slots. Siri extracts slot values from the utterance and pre-fills all intent parameters before `perform()` runs — no back-and-forth asking.

**Only `TheBetterWeShortcuts.swift` changes.** All intent logic, confirmation step, fuzzy child resolution, and API calls are unchanged.

---

## Phrase Templates

### AddPointsIntent

| Phrase | Note captured? | Language |
|--------|---------------|----------|
| `"Add \(.$amount) points to \(.$childName) in \(.applicationName)"` | No | EN |
| `"Add \(.$amount) points to \(.$childName) for \(.$note) in \(.applicationName)"` | Yes | EN |
| `"Give \(.$childName) \(.$amount) points in \(.applicationName)"` | No | EN |
| `"用\(.applicationName)给\(.$childName)加\(.$amount)分"` | No | ZH |
| `"用\(.applicationName)给\(.$childName)加\(.$amount)分，原因是\(.$note)"` | Yes | ZH |

### DeductPointsIntent

| Phrase | Note captured? | Language |
|--------|---------------|----------|
| `"Deduct \(.$amount) points from \(.$childName) in \(.applicationName)"` | No | EN |
| `"Deduct \(.$amount) points from \(.$childName) for \(.$note) in \(.applicationName)"` | Yes | EN |
| `"用\(.applicationName)给\(.$childName)扣\(.$amount)分"` | No | ZH |
| `"用\(.applicationName)给\(.$childName)扣\(.$amount)分，原因是\(.$note)"` | Yes | ZH |

Siri disambiguates with-note vs without-note based on presence of "for" / "原因是" in the utterance.

---

## Parameter Handling

| Parameter | Type | How Siri fills it |
|-----------|------|-------------------|
| `amount` | `Int` | Siri's native number recognition — reliable |
| `childName` | `String` | Captured from name slot → fed into existing `resolveChild()` fuzzy matcher |
| `note` | `String?` | Captures everything between "for" and "in TheBetterWe" as free text |

---

## Full Flow (Happy Path)

> *"Add 5 points to Noah for doing homework in TheBetterWe"*

1. Siri matches phrase → pre-fills `amount=5`, `childName="Noah"`, `note="doing homework"`
2. `perform()` runs:
   - Auth check (`requireParentMembership()`)
   - `resolveChild("Noah")` fuzzy match
   - **Confirmation dialog:** *"Add 5 points to Noah for doing homework?"*
3. User says "Yes"
4. API call → success dialog: *"Added 5 points to Noah for doing homework. Balance: 23 pts."*

**Two voice interactions total** (utterance + confirm). Zero Siri follow-up questions.

---

## Kept Behaviors

- **Confirmation step is preserved** — catches Siri mishears before points are applied.
- **Generic fallback phrases** (`"Add points in \(.applicationName)"`, `"记分"`) can remain as additional phrases for when the user wants the old conversational flow (useful when details aren't known upfront).
- **Error handling unchanged** — `childNotFound`, `childAmbiguous`, `network` errors surface via existing `PointsIntentError`.

---

## Known Limitations

- **App name required in utterance** — Apple's AppShortcut constraint; user must say "in TheBetterWe" or "用TheBetterWe…". Purely free-form speech without the app name is not possible with AppShortcuts.
- **Chinese free-form note delimiter** — `"原因是"` is required as a delimiter for Siri to capture the note in Chinese. Pure free-form like "给Noah加5分做了作业" won't capture "做了作业" as note. The without-note phrase still works; note can be added in-app.
- **Phrase count limit** — Apple allows up to 10 phrases per AppShortcut. Both intents stay well within this limit.

---

## Out of Scope

- LLM-based parsing (Option B) — not needed for this structured use case
- Regex/string parsing (Option C) — not needed; native slot filling handles it
- New intent, new service call, new API endpoint — none required
- Chinese localization changes — intent dialogs already use `String(localized:)`
