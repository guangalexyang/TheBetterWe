# Siri One-Sentence Point Entry — Design Spec

**Date:** 2026-05-25
**Status:** Approved (v2 — revised from parameterized phrases to two-step Gemini parsing)
**Scope:** iOS App Intents + Node/Express server + PostgreSQL migration

---

## Problem

The current Siri points workflow is conversational: Siri asks for child name, then points, then note — one question at a time. This makes it slower than just opening the app.

`AppShortcut` phrase interpolation (`\(.$param)`) only works with `AppEntity` / `AppEnum` types — primitive `String` and `Int` parameters fail to compile. One-sentence native parameterized phrases are not possible with the current intent design.

## Goal

Two voice interactions total: trigger phrase → one free-form sentence → confirmation → done.

> *"Hey Siri, 用TheBetterWe记分"*
> Siri: *"What points would you like to record? For example: Add 5 points to Noah for doing homework."*
> You: *"Give Noah 5 points for finishing homework yesterday"*
> Siri: *"Add 5 points to Noah for finishing homework on May 24?"*
> *"Yes"* → done.

---

## Solution: Two-Step with Server-Side Gemini Parsing

1. Generic trigger phrase opens `RecordPointsIntent`
2. Siri asks for one free-form `command: String` parameter
3. iOS sends utterance to `POST /families/:familyId/point-system/parse-voice-command`
4. Server injects today's date → calls Gemini → parses utterance → fuzzy-matches child → returns structured result
5. iOS shows confirmation dialog (including date if extracted)
6. User confirms → iOS calls existing events endpoint → success dialog

**Existing `AddPointsIntent` and `DeductPointsIntent` are untouched** — they remain available via Shortcuts app with their existing phrases.

---

## New Server Endpoint

### `POST /families/:familyId/point-system/parse-voice-command`

**Auth:** Bearer token (existing `requireAuth` middleware)

**Request body:**
```json
{ "utterance": "Give Noah 5 points for finishing homework yesterday" }
```

**Gemini prompt (server-constructed):**
```
Today's date is YYYY-MM-DD.

Parse the following family points management command into JSON with exactly these fields:
- points: positive integer (number of points)
- isAdd: boolean (true = adding, false = deducting)
- childName: string (child's name as mentioned)
- note: string or null (reason/description, null if not mentioned)
- date: "YYYY-MM-DD" string or null (resolved from relative references like "yesterday",
        "last Wednesday"; null if no date mentioned)

Command: "<utterance>"

Examples:
- "add 5 points to Noah for doing homework" → {"points":5,"isAdd":true,"childName":"Noah","note":"doing homework","date":null}
- "deduct 3 points from Emma for not cleaning" → {"points":3,"isAdd":false,"childName":"Emma","note":"not cleaning","date":null}
- "给Noah加5分因为做了作业" → {"points":5,"isAdd":true,"childName":"Noah","note":"做了作业","date":null}
- "give Noah 5 points for homework yesterday" (today=2026-05-25) → {"points":5,"isAdd":true,"childName":"Noah","note":"homework","date":"2026-05-24"}
- "扣Emma3分 last Wednesday" (today=2026-05-25) → {"points":3,"isAdd":false,"childName":"Emma","note":null,"date":"2026-05-21"}

Return ONLY valid JSON. No markdown, no explanation.
```

**Server validation after parsing:**
- `points`: positive integer, 1–9999
- `isAdd`: boolean
- `childName`: non-empty string
- `note`: string or null
- `date`: valid YYYY-MM-DD string or null; if date is in the future, reject with 400

**Child fuzzy-match** (same token logic as iOS `resolveChild()`):
- Lowercase both sides; match if full name equals query OR any space-separated token equals query
- 0 matches → 404; 2+ matches → 409; exactly 1 → proceed

**Success response:**
```json
{
  "memberId": 123,
  "memberName": "Noah Yang",
  "delta": 5,
  "note": "finishing homework",
  "date": "2026-05-24"
}
```
`delta` is signed: positive = add, negative = deduct.

**Error responses:**
| Status | `error` value | Meaning |
|--------|--------------|---------|
| 400 | `"unparseable"` | Gemini couldn't parse or validation failed |
| 400 | `"future_date"` | Resolved date is in the future |
| 404 | `"child_not_found"` | No child matches the name |
| 409 | `"child_ambiguous"` | Multiple children match |
| 500 | `"gemini_error"` | Gemini API failed |

---

## Database Change

### New migration: add `event_date` to `point_events`

```sql
ALTER TABLE point_events
  ADD COLUMN event_date DATE NOT NULL DEFAULT CURRENT_DATE;
```

- `created_at` — system timestamp: when the event was recorded (unchanged)
- `event_date` — user-intended date: when the event actually happened
- Existing rows default to `CURRENT_DATE` on migration (acceptable — historical events were recorded same-day)
- Display and reporting use `event_date`

### Updated `POST /families/:familyId/point-system/events`

Accepts optional `date` field (YYYY-MM-DD string). When absent, defaults to current date. Fully backward-compatible with existing `AddPointsIntent` / `DeductPointsIntent` flows.

---

## iOS Changes

### New: `RecordPointsIntent.swift`

```
@Parameter var command: String
requestValueDialog: "What points would you like to record? For example: Add 5 points to Noah for doing homework."
```

`perform()`:
1. `requireParentMembership()` — auth + parent check
2. Call `PointSystemService.parseVoiceCommand(familyId:utterance:)` → `ParsedVoiceCommand`
3. Build confirmation string:
   - With date: *"Add 5 points to Noah for finishing homework on May 24?"*
   - Without date: *"Add 5 points to Noah for finishing homework?"*
   - Deduct variant: *"Deduct 3 points from Emma for not cleaning?"*
4. `requestConfirmation()`
5. `adjustPoints(familyId:memberId:delta:note:date:)` — passes `date` through
6. Success dialog with balance

### Modified: `PointSystemService.swift`

New method `parseVoiceCommand(familyId:utterance:)` → `ParsedVoiceCommand`.

New error cases on `PointSystemError`:
- `.unparseable` — HTTP 400 `unparseable` or `future_date`
- `.childNotFound` — HTTP 404
- `.childAmbiguous` — HTTP 409

`addPointEvent()` gains optional `date: String?` parameter — passed in the request body when non-nil.

New model:
```swift
struct ParsedVoiceCommand {
    let memberId: Int
    let memberName: String
    let delta: Int       // signed: positive = add, negative = deduct
    let note: String?
    let date: String?    // YYYY-MM-DD or nil
}
```

### Modified: `PointsIntentSupport.swift`

- New `PointsIntentError` case: `.unparseable`
- New `parseVoiceCommand(utterance:familyId:)` function: calls service, maps `PointSystemError` → `PointsIntentError`
- `adjustPoints()` gains optional `date: String?` parameter, passes through to service

### Modified: `TheBetterWeShortcuts.swift`

New `AppShortcut` for `RecordPointsIntent`:
```swift
AppShortcut(
    intent: RecordPointsIntent(),
    phrases: [
        "用\(.applicationName)记分",
        "Record points in \(.applicationName)",
        "Log points in \(.applicationName)"
    ],
    shortTitle: "Record Points",
    systemImageName: "mic.circle"
)
```

---

## Date Display in Dialogs

Format: `"MMM d"` (e.g. "May 24") — locale-formatted using `DateFormatter` with `en_US_POSIX` locale for parsing, user's locale for display.

---

## Confirmation Step

Kept — catches Gemini misparses before points are applied.

---

## Error Messages (iOS)

| Error | Siri dialog |
|-------|------------|
| `.unparseable` | "Couldn't understand that command. Try: 'Add 5 points to Noah for doing homework'." |
| `.childNotFound` | "Couldn't find that child. Please open TheBetterWe." |
| `.childAmbiguous` | "Multiple children match that name. Please open TheBetterWe." |
| `.network` | "Network error. Please try again." |
| `.notLoggedIn` | "Please log in to TheBetterWe first." |
| `.notParent` | "Only parents can adjust points." |

---

## Out of Scope

- AppEntity-based parameterized phrases — requires full entity/query infrastructure, deferred
- LLM on-device parsing — all LLM calls server-side only
- Timezone handling — date is day-precision only, stored as DATE not TIMESTAMP
- Modifying `AddPointsIntent` / `DeductPointsIntent` — untouched
