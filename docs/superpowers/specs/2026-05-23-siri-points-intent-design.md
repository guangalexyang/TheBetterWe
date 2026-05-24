# Siri Points Intent — Design Spec

**Date:** 2026-05-23
**Feature:** App Intents for adding and deducting points for children via Siri
**Phase:** Phase 4 (Siri / App Intents)

---

## Overview

Two App Intents (`AddPointsIntent`, `DeductPointsIntent`) let parents award or deduct points for a child using natural speech. A shared `PointsIntentSupport` helper handles all common logic so future intents (e.g., `CheckBalanceIntent`) can reuse it.

Doubao integration (Phase 4) is separate: it calls the existing server REST API directly and manages its own confirmation dialog in its chat UI. The App Intents confirmation is Siri-specific and has no bearing on Doubao.

---

## Files

All three files live in the main app target. No App Extension target is needed — the App Intents framework handles background launch automatically.

```
ios/TheBetterWe/TheBetterWe/Intents/
  AddPointsIntent.swift         — parameters, confirmation, delegates to helper
  DeductPointsIntent.swift      — parameters, confirmation, delegates to helper
  PointsIntentSupport.swift     — auth check, family fetch, child lookup, API call
```

`TheBetterWeApp.swift` gains an `AppShortcutsProvider` conformance to register suggested Siri phrases.

No new server endpoints. The existing `POST /families/:familyId/point-system/events` handles both add and deduct via the `delta` sign.

---

## PointsIntentSupport

### Error enum

```swift
enum PointsIntentError: Error {
    case notLoggedIn      // → open app
    case notParent        // logged-in user has "child" role → open app
    case childNotFound    // no name match → open app
    case childAmbiguous   // multiple children match → open app
    case network          // API failure → Siri error message, no app open
}
```

### `requireParentMembership() async throws -> FamilyMembership`

1. Check `AuthService.isAuthenticated` — throw `.notLoggedIn` if false
2. Call `FamilyService.fetchMine()` — throw `.network` on failure or empty result
3. Use `memberships[0]`
4. Check `membership.roleKeywords.contains("child")` — throw `.notParent` if true
5. Return the membership

### `resolveChild(named:familyId:) async throws -> PSChild`

1. Call `PointSystemService.fetchChildren(familyId:)`
2. Split each child's stored name into tokens (by space); case-insensitive check whether any token equals the given `childName` string (e.g. "Noah" matches "Noah Yang" via first token; "Yang" matches via second token)
3. Zero matches → throw `.childNotFound`
4. 2+ matches → throw `.childAmbiguous`
5. Exactly one match → return it

### `adjustPoints(familyId:memberId:delta:note:) async throws -> Int`

- Calls `PointSystemService.addPointEvent(...)`, returns `newBalance`
- Maps `PointSystemError.unauthorized` → `.notLoggedIn`
- Maps `PointSystemError.network` → `.network`

---

## Intent Parameters

Both intents share the same three parameters:

| Parameter   | Type      | Required | Notes             |
|-------------|-----------|----------|-------------------|
| `childName` | `String`  | Yes      | Matched by Siri NLU |
| `amount`    | `Int`     | Yes      | Valid range: 1–9999 |
| `note`      | `String?` | No       | Reason / activity |

---

## Siri Phrases (AppShortcutsProvider)

```
AddPointsIntent:
  "Add \(.amount) points to \(.childName) in TheBetterWe"
  "Add \(.amount) points to \(.childName) for \(.note) in TheBetterWe"

DeductPointsIntent:
  "Deduct \(.amount) points from \(.childName) in TheBetterWe"
  "Deduct \(.amount) points from \(.childName) for \(.note) in TheBetterWe"
```

The "in TheBetterWe" suffix is required by Apple for App Shortcuts registration.

---

## Confirmation Dialogs

Both intents call `requestConfirmation()` before executing. Siri reads the summary aloud and waits for "Yes" / "Confirm" or "No" / "Cancel" (voice or tap).

| Case | Dialog shown |
|------|-------------|
| Add with note | "Add 2 points to Noah for piano practice?" |
| Add without note | "Add 2 points to Noah?" |
| Deduct with note | "Deduct 2 points from Noah for piano practice?" |
| Deduct without note | "Deduct 2 points from Noah?" |

---

## Success Result

Siri reads the result aloud after the API call succeeds.

| Intent | Result dialog |
|--------|--------------|
| Add | "Added 2 points to Noah for piano practice. Balance: 42 pts." |
| Add (no note) | "Added 2 points to Noah. Balance: 42 pts." |
| Deduct | "Deducted 2 points from Noah for piano practice. Balance: 40 pts." |
| Deduct (no note) | "Deducted 2 points from Noah. Balance: 40 pts." |

---

## Execution Flow

```
Siri hears phrase
  → check AuthService.isAuthenticated
      ❌ → open app (login view)
  → fetch memberships[0]
  → check roleKeywords ≠ "child"
      ❌ → open app
  → fetch children for familyId
  → match childName (case-insensitive, first or last name)
      0 matches → open app
      2+ matches → open app
  → requestConfirmation()
      cancelled → dismissed, no action
  → POST /families/:familyId/point-system/events (delta = ±amount)
      network error → Siri error message (no app open)
  → return success dialog with new balance
```

---

## Error Handling Summary

| Error | Response |
|-------|----------|
| Not logged in | Open app (user lands on login view) |
| Logged-in user is a child role | Open app |
| Child name not found | Open app (user does it manually) |
| Child name ambiguous (2+ matches) | Open app (user does it manually) |
| Confirmation cancelled | Silent dismiss, no change |
| Network / server error | Siri error message, no app open |

---

## Role Check Rationale

Children may have their own accounts (with `"child"` in `roleKeywords`). The intent checks that the logged-in user does not have this keyword before proceeding. This prevents a child from triggering point changes via Siri on their own device.

---

## Future Intents (reuse PointsIntentSupport)

- `CheckBalanceIntent` — "What's Noah's balance in TheBetterWe?"
  - Calls `requireParentMembership()` + `resolveChild()`, no API write, returns balance dialog
- Others TBD

---

## Out of Scope

- Feature flags (app not yet shipped)
- Doubao integration (Phase 4, uses server REST API directly)
- Apple Watch (Phase 5)
- Multi-family disambiguation (app currently uses `memberships[0]` everywhere)
