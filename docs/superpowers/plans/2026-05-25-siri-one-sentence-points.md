# Siri One-Sentence Point Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let parents record points with a single spoken sentence — Siri triggers an intent, captures one free-form utterance, the server uses Gemini to parse it (including relative dates), and iOS confirms before executing.

**Architecture:** `RecordPointsIntent` captures speech → `POST /families/:id/point-system/parse-voice-command` → Gemini parses utterance + today's date → server fuzzy-matches child → iOS shows confirmation → existing events endpoint records the point with `event_date`. Existing `AddPointsIntent` and `DeductPointsIntent` are untouched.

**Tech Stack:** Node.js + TypeScript + Express + PostgreSQL (server); Swift + AppIntents (iOS); Google Gemini 2.5 Flash Lite REST API.

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| CREATE | `server/src/services/gemini.ts` | `callGemini()` + `parseJson()` helpers |
| MODIFY | `server/src/routes/pointSystem.ts` | Add parse-voice-command route; add `date` to events route |
| MODIFY | `server/src/index.ts` | No change needed — pointSystem already mounted |
| MODIFY | `server/.env` | Add `GEMINI_API_KEY` |
| MODIFY | `server/.env.example` | Add `GEMINI_API_KEY=` placeholder |
| CREATE | `server/migrations/003_point_events_event_date.js` | Add `event_date DATE` column |
| MODIFY | `ios/.../Services/PointSystemService.swift` | `parseVoiceCommand()`, new errors, date in `addPointEvent()` |
| MODIFY | `ios/.../Intents/PointsIntentSupport.swift` | `parseVoiceCommand()` bridge, `unparseable` error |
| CREATE | `ios/.../Intents/RecordPointsIntent.swift` | New intent |
| MODIFY | `ios/.../Intents/TheBetterWeShortcuts.swift` | Add `RecordPointsIntent` shortcut |

---

## Task 1: Database Migration — Add `event_date` to `point_events`

**Files:**
- Create: `server/migrations/003_point_events_event_date.js`

- [ ] **Step 1: Create the migration file**

```javascript
'use strict';

/** @param {import('node-pg-migrate').MigrationBuilder} pgm */
exports.up = (pgm) => {
  pgm.sql(`
    ALTER TABLE point_events
      ADD COLUMN event_date DATE NOT NULL DEFAULT CURRENT_DATE;
  `);
};

/** @param {import('node-pg-migrate').MigrationBuilder} pgm */
exports.down = (pgm) => {
  pgm.sql(`
    ALTER TABLE point_events DROP COLUMN IF EXISTS event_date;
  `);
};
```

- [ ] **Step 2: Run the migration locally**

```bash
cd server
npm run migrate
```

Expected output includes: `### MIGRATION 003_point_events_event_date (UP) ###`

- [ ] **Step 3: Verify the column was added**

```bash
psql betterwe -c "\d point_events"
```

Expected: `event_date | date | not null | default CURRENT_DATE` appears in the column list.

- [ ] **Step 4: Commit**

```bash
git add server/migrations/003_point_events_event_date.js
git commit -m "feat: add event_date column to point_events"
```

---

## Task 2: Server — Gemini Service

**Files:**
- Create: `server/src/services/gemini.ts`
- Modify: `server/.env`
- Modify: `server/.env.example`

- [ ] **Step 1: Add `GEMINI_API_KEY` to env files**

In `server/.env`, add:
```
GEMINI_API_KEY=your-key-here
```
(Fill in the real key from your Google AI Studio account — the same one used in OrderFromMe.)

In `server/.env.example`, add:
```
GEMINI_API_KEY=
```

- [ ] **Step 2: Create `server/src/services/gemini.ts`**

```typescript
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash-lite:generateContent?key=${GEMINI_API_KEY}`;

if (!GEMINI_API_KEY) {
  console.error('[AI] GEMINI_API_KEY is not set — AI features will fail');
} else {
  console.log('[AI] Gemini key loaded:', GEMINI_API_KEY.slice(0, 8) + '...');
}

interface GeminiResult {
  text?: string;
  error?: string;
  quotaExceeded?: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function callGemini(prompt: string): Promise<GeminiResult> {
  const res = await fetch(GEMINI_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
  });
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const data = await res.json() as any;
  if (!res.ok) {
    console.error('[Gemini] HTTP', res.status, JSON.stringify(data));
    return { quotaExceeded: res.status === 429, error: data.error?.message ?? `HTTP ${res.status}` };
  }
  if (data.error) {
    console.error('[Gemini] API error', JSON.stringify(data.error));
    return { quotaExceeded: false, error: data.error.message };
  }
  const text: string = data.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
  return { text };
}

export function parseJson<T>(text: string): T {
  const cleaned = text
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/```\s*$/i, '')
    .trim();
  return JSON.parse(cleaned) as T;
}
```

- [ ] **Step 3: Commit**

```bash
git add server/src/services/gemini.ts server/.env.example
git commit -m "feat: add Gemini service helper"
```

---

## Task 3: Server — `parse-voice-command` Endpoint

**Files:**
- Modify: `server/src/routes/pointSystem.ts`

Add the following route **after the existing imports** (add the gemini import at the top) and **before** `export default router`:

- [ ] **Step 1: Add import at the top of `pointSystem.ts`**

After the existing imports, add:
```typescript
import { callGemini, parseJson } from '../services/gemini';
```

- [ ] **Step 2: Add the helper function after the `isMember` function**

```typescript
function fuzzyMatchChild(
  query: string,
  children: Array<{ memberId: number; name: string; balance: number }>
) {
  const q = query.toLowerCase().trim();
  return children.filter((c) => {
    const lower = c.name.toLowerCase();
    return lower === q || lower.split(/\s+/).includes(q);
  });
}
```

- [ ] **Step 3: Add the route before `export default router`**

```typescript
// POST /families/:familyId/point-system/parse-voice-command
router.post('/:familyId/point-system/parse-voice-command', async (req: Request, res: Response) => {
  const familyId = parseInt(req.params.familyId, 10);
  const userId = req.auth!.sub;
  const { utterance } = req.body as { utterance?: string };

  if (!utterance?.trim()) {
    res.status(400).json({ error: 'utterance is required' });
    return;
  }

  if (!(await isMember(familyId, userId))) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  // Fetch children for this family
  const children = (await pool.query<{ memberId: number; name: string; balance: number }>(
    `SELECT
      fm.id           AS "memberId",
      fm.display_name AS name,
      COALESCE((SELECT SUM(delta) FROM point_events WHERE member_id = fm.id), 0)::INTEGER AS balance
    FROM family_members fm
    WHERE fm.family_id = $1
      AND EXISTS (
        SELECT 1 FROM member_role_keywords k
        WHERE k.member_id = fm.id AND k.keyword = 'child'
      )`,
    [familyId]
  )).rows;

  // Build prompt with today's date for relative date resolution
  const todayStr = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
  const prompt = `Today's date is ${todayStr}.

Parse the following family points management command into JSON with exactly these fields:
- points: positive integer (number of points, 1-9999)
- isAdd: boolean (true = adding points, false = deducting)
- childName: string (child's name as mentioned)
- note: string or null (reason/description, null if not mentioned)
- date: "YYYY-MM-DD" string or null (resolve relative references like "yesterday", "last Wednesday" using today's date; null if no date mentioned)

Command: "${utterance.trim()}"

Examples:
- "add 5 points to Noah for doing homework" → {"points":5,"isAdd":true,"childName":"Noah","note":"doing homework","date":null}
- "deduct 3 points from Emma for not cleaning" → {"points":3,"isAdd":false,"childName":"Emma","note":"not cleaning","date":null}
- "给Noah加5分因为做了作业" → {"points":5,"isAdd":true,"childName":"Noah","note":"做了作业","date":null}
- "give Noah 5 points for homework yesterday" (today=2026-05-25) → {"points":5,"isAdd":true,"childName":"Noah","note":"homework","date":"2026-05-24"}
- "扣Emma3分 last Wednesday" (today=2026-05-25) → {"points":3,"isAdd":false,"childName":"Emma","note":null,"date":"2026-05-21"}

Return ONLY valid JSON. No markdown, no explanation.`;

  const geminiResult = await callGemini(prompt);
  if (geminiResult.error) {
    console.error('[parse-voice-command] Gemini error:', geminiResult.error);
    res.status(500).json({ error: 'gemini_error' });
    return;
  }

  // Parse and validate Gemini's response
  let parsed: { points: unknown; isAdd: unknown; childName: unknown; note: unknown; date: unknown };
  try {
    parsed = parseJson(geminiResult.text!);
  } catch {
    res.status(400).json({ error: 'unparseable' });
    return;
  }

  const { points, isAdd, childName, note, date } = parsed;

  if (
    typeof points !== 'number' || !Number.isInteger(points) || points < 1 || points > 9999 ||
    typeof isAdd !== 'boolean' ||
    typeof childName !== 'string' || !childName.trim() ||
    (note !== null && typeof note !== 'string') ||
    (date !== null && typeof date !== 'string')
  ) {
    res.status(400).json({ error: 'unparseable' });
    return;
  }

  // Validate date format and reject future dates
  let safeDate: string | null = null;
  if (date !== null) {
    const dateStr = date as string;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
      res.status(400).json({ error: 'unparseable' });
      return;
    }
    if (dateStr > todayStr) {
      res.status(400).json({ error: 'future_date' });
      return;
    }
    safeDate = dateStr;
  }

  // Fuzzy-match child name
  const matches = fuzzyMatchChild(childName as string, children);
  if (matches.length === 0) {
    res.status(404).json({ error: 'child_not_found' });
    return;
  }
  if (matches.length > 1) {
    res.status(409).json({ error: 'child_ambiguous' });
    return;
  }

  const child = matches[0];
  const delta = isAdd ? (points as number) : -(points as number);
  const safeNote = (typeof note === 'string' && (note as string).trim()) ? (note as string).trim() : null;

  res.json({
    memberId: child.memberId,
    memberName: child.name,
    delta,
    note: safeNote,
    date: safeDate,
  });
});
```

- [ ] **Step 4: Start the dev server and test with curl**

```bash
cd server && npm run dev
```

In a new terminal — replace `TOKEN` with a valid JWT from logging in, and `FAMILY_ID` with your test family's id:

```bash
# Test: basic add without date
curl -s -X POST http://localhost:3000/families/FAMILY_ID/point-system/parse-voice-command \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"utterance":"add 5 points to Noah for doing homework"}' | jq .
```

Expected:
```json
{ "memberId": 123, "memberName": "Noah Yang", "delta": 5, "note": "doing homework", "date": null }
```

```bash
# Test: with relative date
curl -s -X POST http://localhost:3000/families/FAMILY_ID/point-system/parse-voice-command \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"utterance":"give Noah 5 points for homework yesterday"}' | jq .
```

Expected: `"date"` is yesterday's date in YYYY-MM-DD.

```bash
# Test: unknown child → 404
curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/families/FAMILY_ID/point-system/parse-voice-command \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"utterance":"add 5 points to zzunknown"}' 
```

Expected: `404`

- [ ] **Step 5: Commit**

```bash
git add server/src/routes/pointSystem.ts server/src/services/gemini.ts
git commit -m "feat: add parse-voice-command endpoint with Gemini parsing"
```

---

## Task 4: Server — Add `date` to Events Endpoint

**Files:**
- Modify: `server/src/routes/pointSystem.ts`

- [ ] **Step 1: Update the `POST /:familyId/point-system/events` route**

Find the existing events route handler. Replace the body destructuring and INSERT query:

Old body destructuring:
```typescript
const { memberId, delta, note } = req.body as {
  memberId?: number;
  delta?: number;
  note?: string;
};
```

New:
```typescript
const { memberId, delta, note, date } = req.body as {
  memberId?: number;
  delta?: number;
  note?: string;
  date?: string;
};
```

Old INSERT (after existing validation):
```typescript
const eventResult = await pool.query(
  'INSERT INTO point_events (member_id, delta, note) VALUES ($1, $2, $3) RETURNING id',
  [memberId, delta, safeNote]
);
```

New:
```typescript
// Validate date if provided
let safeDate: string | null = null;
if (typeof date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(date)) {
  safeDate = date;
}

const eventResult = await pool.query(
  'INSERT INTO point_events (member_id, delta, note, event_date) VALUES ($1, $2, $3, COALESCE($4::DATE, CURRENT_DATE)) RETURNING id',
  [memberId, delta, safeNote, safeDate]
);
```

- [ ] **Step 2: Test the updated events endpoint**

```bash
# Test: event without date (defaults to today)
curl -s -X POST http://localhost:3000/families/FAMILY_ID/point-system/events \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"memberId": MEMBER_ID, "delta": 3, "note": "test no date"}' | jq .
```

Expected: `{ "eventId": ..., "memberId": ..., "delta": 3, "note": "test no date", "newBalance": ... }`

```bash
# Test: event with explicit date
curl -s -X POST http://localhost:3000/families/FAMILY_ID/point-system/events \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"memberId": MEMBER_ID, "delta": 5, "note": "backdated", "date": "2026-05-20"}' | jq .
```

Then verify in DB:
```bash
psql betterwe -c "SELECT id, delta, note, event_date, created_at FROM point_events ORDER BY id DESC LIMIT 2;"
```

Expected: first row has `event_date = 2026-05-20`, second has `event_date = today`.

- [ ] **Step 3: Commit**

```bash
git add server/src/routes/pointSystem.ts
git commit -m "feat: accept optional date in point events endpoint, store as event_date"
```

---

## Task 5: iOS — Update `PointSystemService.swift`

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Services/PointSystemService.swift`

- [ ] **Step 1: Add new error cases and the `ParsedVoiceCommand` model**

After the existing `PointSystemError` enum, add:
```swift
// New error cases — add to existing PointSystemError enum
// case network       <- already exists
// case unauthorized  <- already exists
// Add:
case unparseable
case childNotFound
case childAmbiguous
```

The full updated enum:
```swift
enum PointSystemError: LocalizedError {
    case network
    case unauthorized
    case unparseable
    case childNotFound
    case childAmbiguous

    var errorDescription: String? {
        switch self {
        case .network:        return String(localized: "Network error. Please try again.")
        case .unauthorized:   return String(localized: "Session expired. Please log in again.")
        case .unparseable:    return String(localized: "Couldn't understand that command.")
        case .childNotFound:  return String(localized: "Couldn't find that child.")
        case .childAmbiguous: return String(localized: "Multiple children match that name.")
        }
    }
}
```

After the enum, add the new model:
```swift
struct ParsedVoiceCommand {
    let memberId: Int
    let memberName: String
    let delta: Int       // signed: positive = add, negative = deduct
    let note: String?
    let date: String?    // YYYY-MM-DD or nil
}
```

- [ ] **Step 2: Add `parseVoiceCommand()` to `PointSystemService`**

Add this method inside `enum PointSystemService`:

```swift
static func parseVoiceCommand(familyId: Int, utterance: String) async throws -> ParsedVoiceCommand {
    struct Body: Encodable {
        let utterance: String
    }
    struct Response: Decodable {
        let memberId: Int
        let memberName: String
        let delta: Int
        let note: String?
        let date: String?
    }

    guard let token = AuthService.accessToken else { throw PointSystemError.unauthorized }
    var request = URLRequest(url: baseURL.appending(path: "/families/\(familyId)/point-system/parse-voice-command"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpBody = try? JSONEncoder().encode(Body(utterance: utterance))

    let (data, response): (Data, URLResponse)
    do {
        (data, response) = try await URLSession.shared.data(for: request)
    } catch {
        throw PointSystemError.network
    }

    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    switch status {
    case 200:
        guard let parsed = try? JSONDecoder().decode(Response.self, from: data) else {
            throw PointSystemError.network
        }
        return ParsedVoiceCommand(
            memberId: parsed.memberId,
            memberName: parsed.memberName,
            delta: parsed.delta,
            note: parsed.note,
            date: parsed.date
        )
    case 400, 500:
        throw PointSystemError.unparseable
    case 401:
        throw PointSystemError.unauthorized
    case 404:
        throw PointSystemError.childNotFound
    case 409:
        throw PointSystemError.childAmbiguous
    default:
        throw PointSystemError.network
    }
}
```

- [ ] **Step 3: Add optional `date` parameter to `addPointEvent()`**

Replace the existing `addPointEvent()` signature and body:

```swift
static func addPointEvent(
    familyId: Int,
    memberId: Int,
    delta: Int,
    note: String?,
    date: String? = nil
) async throws -> PointEventResponse {
    struct Body: Encodable {
        let memberId: Int
        let delta: Int
        let note: String?
        let date: String?
    }
    let data = try await post(
        path: "/families/\(familyId)/point-system/events",
        body: Body(memberId: memberId, delta: delta, note: note, date: date),
        expectedStatus: 201
    )
    guard let response = try? JSONDecoder().decode(PointEventResponse.self, from: data) else {
        throw PointSystemError.network
    }
    return response
}
```

The `date: String? = nil` default means all existing call sites (in `AddPointsIntent`, `DeductPointsIntent`) compile unchanged.

- [ ] **Step 4: Build to verify no compile errors**

Open Xcode and build (⌘B). Expected: 0 errors. The existing intents' calls to `addPointEvent` should still compile since `date` has a default value.

- [ ] **Step 5: Commit** *(note: new Swift files must be added to Xcode target manually — this file already exists so no target add needed)*

```bash
git add ios/TheBetterWe/TheBetterWe/Services/PointSystemService.swift
git commit -m "feat: add parseVoiceCommand, date param to addPointEvent in PointSystemService"
```

---

## Task 6: iOS — Update `PointsIntentSupport.swift`

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Intents/PointsIntentSupport.swift`

- [ ] **Step 1: Add `.unparseable` to `PointsIntentError`**

In the existing `PointsIntentError` enum, add a new case and its `errorDescription`:

```swift
enum PointsIntentError: LocalizedError {
    case notLoggedIn
    case notParent
    case notInFamily
    case childNotFound
    case childAmbiguous
    case unparseable      // ← new
    case network

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:    return String(localized: "Please log in to TheBetterWe first.")
        case .notParent:      return String(localized: "Only parents can adjust points.")
        case .notInFamily:    return String(localized: "You haven't joined a family yet. Please open TheBetterWe.")
        case .childNotFound:  return String(localized: "Couldn't find that child. Please open TheBetterWe.")
        case .childAmbiguous: return String(localized: "Multiple children match that name. Please open TheBetterWe.")
        case .unparseable:    return String(localized: "Couldn't understand that command. Try: \"Add 5 points to Noah for doing homework\".")
        case .network:        return String(localized: "Network error. Please try again.")
        }
    }
}
```

- [ ] **Step 2: Add `parseVoiceCommand()` to `PointsIntentSupport`**

Add this static function inside `enum PointsIntentSupport`:

```swift
/// Sends the utterance to the server, which uses Gemini to parse it.
/// Returns a ParsedVoiceCommand with signed delta, optional note, and optional date.
static func parseVoiceCommand(utterance: String, familyId: Int) async throws -> ParsedVoiceCommand {
    do {
        return try await PointSystemService.parseVoiceCommand(familyId: familyId, utterance: utterance)
    } catch PointSystemError.unauthorized {
        throw PointsIntentError.notLoggedIn
    } catch PointSystemError.unparseable {
        throw PointsIntentError.unparseable
    } catch PointSystemError.childNotFound {
        throw PointsIntentError.childNotFound
    } catch PointSystemError.childAmbiguous {
        throw PointsIntentError.childAmbiguous
    } catch {
        throw PointsIntentError.network
    }
}
```

- [ ] **Step 3: Add `date` parameter to `adjustPoints()`**

Replace the existing `adjustPoints()` signature:

```swift
static func adjustPoints(
    familyId: Int,
    memberId: Int,
    delta: Int,
    note: String?,
    date: String? = nil
) async throws -> Int {
    do {
        let response = try await PointSystemService.addPointEvent(
            familyId: familyId,
            memberId: memberId,
            delta: delta,
            note: note,
            date: date
        )
        return response.newBalance
    } catch PointSystemError.unauthorized {
        throw PointsIntentError.notLoggedIn
    } catch {
        throw PointsIntentError.network
    }
}
```

The `date: String? = nil` default keeps existing call sites in `AddPointsIntent` and `DeductPointsIntent` unchanged.

- [ ] **Step 4: Build to verify (⌘B in Xcode)**

Expected: 0 errors. Existing intents compile unchanged because of `nil` defaults.

- [ ] **Step 5: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Intents/PointsIntentSupport.swift
git commit -m "feat: add parseVoiceCommand and date support to PointsIntentSupport"
```

---

## Task 7: iOS — Create `RecordPointsIntent.swift`

**Files:**
- Create: `ios/TheBetterWe/TheBetterWe/Intents/RecordPointsIntent.swift`

> ⚠️ **After creating this file, the user must manually add it to the Xcode target.** In Xcode: right-click the `Intents` group → "Add Files to TheBetterWe..." → select the new file → ensure the TheBetterWe target is checked.

- [ ] **Step 1: Create the file**

```swift
import AppIntents

struct RecordPointsIntent: AppIntent {
    static let title: LocalizedStringResource = "Record Points"
    static let description = IntentDescription(
        "Add or deduct points with a single spoken sentence"
    )

    @Parameter(
        title: "Points Command",
        requestValueDialog: IntentDialog(
            "What points would you like to record? For example: Add 5 points to Noah for doing homework."
        )
    )
    var command: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. Auth + parent check
        let membership = try await PointsIntentSupport.requireParentMembership()

        // 2. Parse utterance via server → Gemini
        let parsed = try await PointsIntentSupport.parseVoiceCommand(
            utterance: command,
            familyId: membership.familyId
        )

        // 3. Build confirmation dialog
        let absPoints = abs(parsed.delta)
        let pts = absPoints == 1 ? "point" : "points"
        let verb = parsed.delta > 0 ? "Add" : "Deduct"
        let prep = parsed.delta > 0 ? "to" : "from"

        var confirmMsg: String
        let dateStr = parsed.date.map { RecordPointsIntent.formatDate($0) }

        switch (parsed.note, dateStr) {
        case let (note?, date?):
            confirmMsg = "\(verb) \(absPoints) \(pts) \(prep) \(parsed.memberName) for \"\(note)\" on \(date)?"
        case let (note?, nil):
            confirmMsg = "\(verb) \(absPoints) \(pts) \(prep) \(parsed.memberName) for \"\(note)\"?"
        case let (nil, date?):
            confirmMsg = "\(verb) \(absPoints) \(pts) \(prep) \(parsed.memberName) on \(date)?"
        case (nil, nil):
            confirmMsg = "\(verb) \(absPoints) \(pts) \(prep) \(parsed.memberName)?"
        }

        try await requestConfirmation(result: .result(dialog: IntentDialog(stringLiteral: confirmMsg)))

        // 4. Execute
        let newBalance = try await PointsIntentSupport.adjustPoints(
            familyId: membership.familyId,
            memberId: parsed.memberId,
            delta: parsed.delta,
            note: parsed.note,
            date: parsed.date
        )

        // 5. Success dialog
        let pastVerb = parsed.delta > 0 ? "Added" : "Deducted"
        var successMsg: String
        switch (parsed.note, dateStr) {
        case let (note?, date?):
            successMsg = "\(pastVerb) \(absPoints) \(pts) \(prep) \(parsed.memberName) for \"\(note)\" on \(date). Balance: \(newBalance) pts."
        case let (note?, nil):
            successMsg = "\(pastVerb) \(absPoints) \(pts) \(prep) \(parsed.memberName) for \"\(note)\". Balance: \(newBalance) pts."
        case let (nil, date?):
            successMsg = "\(pastVerb) \(absPoints) \(pts) \(prep) \(parsed.memberName) on \(date). Balance: \(newBalance) pts."
        case (nil, nil):
            successMsg = "\(pastVerb) \(absPoints) \(pts) \(prep) \(parsed.memberName). Balance: \(newBalance) pts."
        }
        return .result(dialog: IntentDialog(stringLiteral: successMsg))
    }

    // Formats "2026-05-24" → "May 24"
    private static func formatDate(_ iso: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: iso) else { return iso }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return display.string(from: date)
    }
}
```

- [ ] **Step 2: Add the file to the Xcode target**

In Xcode: right-click the **Intents** group in the Project Navigator → **Add Files to "TheBetterWe"...** → select `RecordPointsIntent.swift` → make sure the **TheBetterWe** target checkbox is checked → **Add**.

- [ ] **Step 3: Build (⌘B)**

Expected: 0 errors. If `ParsedVoiceCommand` is not found, confirm Task 5 was committed and the file is in the target.

- [ ] **Step 4: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Intents/RecordPointsIntent.swift
git add ios/TheBetterWe/TheBetterWe.xcodeproj/project.pbxproj
git commit -m "feat: add RecordPointsIntent for one-sentence Siri point recording"
```

---

## Task 8: iOS — Add `RecordPointsIntent` to `TheBetterWeShortcuts.swift`

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Intents/TheBetterWeShortcuts.swift`

- [ ] **Step 1: Add the new AppShortcut**

Add a third `AppShortcut` entry inside `appShortcuts`. The existing two entries for `AddPointsIntent` and `DeductPointsIntent` stay unchanged:

```swift
import AppIntents

struct TheBetterWeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddPointsIntent(),
            phrases: [
                "Add points in \(.applicationName)",
                "Award points in \(.applicationName)",
                "在\(.applicationName)加分",
                "用\(.applicationName)加分",
                "给孩子加分在\(.applicationName)"
            ],
            shortTitle: "Add Points",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: DeductPointsIntent(),
            phrases: [
                "Deduct points in \(.applicationName)",
                "Remove points in \(.applicationName)",
                "在\(.applicationName)扣分",
                "用\(.applicationName)扣分",
                "给孩子扣分在\(.applicationName)"
            ],
            shortTitle: "Deduct Points",
            systemImageName: "minus.circle"
        )
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
    }
}
```

- [ ] **Step 2: Build (⌘B)**

Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Intents/TheBetterWeShortcuts.swift
git commit -m "feat: add RecordPointsIntent shortcut phrases"
```

---

## Task 9: End-to-End Test in Shortcuts App + Set fly.io Secret

**Files:** None — verification + deployment config only.

- [ ] **Step 1: Set the Gemini API key on fly.io**

```bash
cd server
fly secrets set GEMINI_API_KEY=your-key-here
```

(Use the same key as `server/.env`. fly.io restarts the app automatically after `secrets set`.)

- [ ] **Step 2: Build and run on Simulator (iOS 16+)**

In Xcode, select a Simulator and press ▶.

- [ ] **Step 3: Open Shortcuts app on Simulator**

Tap **+** → search **TheBetterWe** → confirm three actions appear: **Add Points**, **Deduct Points**, **Record Points**.

- [ ] **Step 4: Test Record Points — add with note and date**

Add a **Record Points** shortcut. In the `command` field, type:
```
add 5 points to Noah for doing homework yesterday
```

Run it. Expected:
1. Server calls Gemini → returns delta=5, note="doing homework", date=yesterday's date
2. Confirmation: *"Add 5 points to Noah for 'doing homework' on May 24?"* (date is yesterday)
3. Confirm → success: *"Added 5 points to Noah for 'doing homework' on May 24. Balance: X pts."*

Verify in DB:
```bash
psql betterwe -c "SELECT delta, note, event_date, created_at FROM point_events ORDER BY id DESC LIMIT 1;"
```
Expected: `event_date = yesterday`, `created_at = now (unix)`.

- [ ] **Step 5: Test — add without date**

Command: `give Noah 3 points for cleaning room`
Expected confirmation: *"Add 3 points to Noah for 'cleaning room'?"* (no date shown)
DB: `event_date = today`.

- [ ] **Step 6: Test — deduct**

Command: `扣Emma2分因为没写作业`
Expected confirmation: *"Deduct 2 points from Emma for '没写作业'?"*

- [ ] **Step 7: Test — unknown child error**

Command: `add 5 points to zzunknown`
Expected: Siri surfaces *"Couldn't find that child. Please open TheBetterWe."* — no crash.

- [ ] **Step 8: Test — unparseable command**

Command: `hello world`
Expected: Siri surfaces *"Couldn't understand that command. Try: 'Add 5 points to Noah for doing homework'."*
