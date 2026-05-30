# Point System View Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign PointSystemView to match the v1.0.1 final design — avatar grid selector, white child card with side-by-side Deduct/Reward buttons, inline Activities section, and a feature-flagged Progress to Goal section.

**Architecture:** Replace the gradient-banner + expandable-row layout with a clean scrollable page: `FamilyMemberGrid` (avatar circle grid) → `ChildCard` (white card, horizontal layout) → `GoalProgressSection` (feature-flagged) → `ActivitySection` (inline history). Point adjustment moves from inline form to a `.sheet()`. Backend gains a GET events endpoint and Goals CRUD.

**Tech Stack:** SwiftUI, node-pg-migrate, Express/TypeScript, PostgreSQL

---

## Design Reference

From `v1.0.1/* Final design point system view/screen.png`:

- **Member grid**: 4-column grid, avatar circles (emoji), name label below, primary-color border on selected child, dashed "Add" button
- **Child card**: white card with `border border-outline-variant/30`, left side = avatar + name + age (label in primary), right side = large points number + "points" label, bottom = "Deduct" (outlined pill) + "Reward" (filled primary pill)
- **Progress to Goal**: section header + "+" add button, goal rows with `name | X/Y | progress bar`, swipe-to-delete
- **Activities**: section header, grouped card with rows (circle icon, name, time-ago, ±delta), swipe-to-delete, "View More" button

**Color palette** (SwiftUI equivalents):
- Primary: `.accentColor` (system blue) – design uses `#4343d5` but we keep system accent for iOS conventions
- Card background: `Color(.systemBackground)` with `stroke(Color(.systemGray4))`
- Surface container high: `Color(.systemGray6)`
- Positive delta: `.green`
- Negative delta: `.red`

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `ios/.../PointSystem/PointSystemStyle.swift` | Modify | Add new style constants; keep existing ones used by PointAdjustFormView |
| `ios/.../Models/PointSystemModels.swift` | Modify | Add `PSActivity`, `PSGoal` structs |
| `ios/.../Services/PointSystemService.swift` | Modify | Add `fetchActivities`, `deleteActivity`, `fetchGoals`, `createGoal`, `deleteGoal`; add `delete` helper |
| `ios/.../Services/FeatureToggle.swift` | Modify | Add `pointGoals` key |
| `ios/.../PointSystem/PointSystemView.swift` | Modify | Complete redesign — all view sections rebuilt as private structs |
| `ios/.../PointSystem/PointAdjustFormView.swift` | Modify | Add sheet header (title + X close button) for sheet presentation |
| `ios/.../Resources/Localizable.xcstrings` | Modify | Add zh-Hans for all new strings |
| `server/src/routes/pointSystem.ts` | Modify | Add GET events, DELETE event, Goals CRUD endpoints |
| `server/src/routes/featureToggles.ts` | Modify | Add `pointGoals: false` |
| `server/migrations/004_create_point_goals.js` | Create | `point_goals` table migration |

---

## Task 1: Add new style constants to PointSystemStyle.swift

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemStyle.swift`

- [x] **Step 1: Add new constants block**

Open `PointSystemStyle.swift` and add after the existing constants (before the closing `}`):

```swift
    // Redesign v1.0.1
    static let memberGridColumns: Int = 4
    static let memberAvatarSize: CGFloat = 64
    static let memberAvatarBorderWidth: CGFloat = 2
    static let childCardCornerRadius: CGFloat = 16
    static let childCardBorderWidth: CGFloat = 1
    static let childCardPadding: CGFloat = 20
    static let childCardAvatarSize: CGFloat = 56
    static let pointsDisplayFontSize: CGFloat = 32
    static let actionButtonHeight: CGFloat = 48
    static let sectionHeaderFontSize: CGFloat = 20
    static let activityIconSize: CGFloat = 40
    static let goalProgressHeight: CGFloat = 16
    static let goalProgressCornerRadius: CGFloat = 8
```

- [x] **Step 2: Verify build**

Build the iOS target in Xcode (`⌘B`). Expected: Build Succeeded (no errors from new constants).

- [x] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemStyle.swift
git commit -m "style: add v1.0.1 redesign constants to PointSystemStyle"
```

---

## Task 2: Add PSActivity and PSGoal models

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/TheBetterWe/Models/PointSystemModels.swift`

- [x] **Step 1: Add models**

Append to the bottom of `PointSystemModels.swift`:

```swift
struct PSActivity: Identifiable, Decodable {
    let eventId: Int
    let memberId: Int
    let delta: Int
    let note: String?
    let eventDate: String   // "YYYY-MM-DD"
    let createdAt: String   // ISO 8601

    var id: Int { eventId }

    // Returns "+25" or "-200"
    var deltaText: String {
        delta >= 0 ? "+\(delta)" : "\(delta)"
    }

    var isPositive: Bool { delta > 0 }
}

struct PSGoal: Identifiable, Decodable {
    let goalId: Int
    let memberId: Int
    let name: String
    let targetPoints: Int

    var id: Int { goalId }
}
```

- [x] **Step 2: Verify build**

Build (`⌘B`). Expected: Build Succeeded.

- [x] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/TheBetterWe/Models/PointSystemModels.swift
git commit -m "feat: add PSActivity and PSGoal models"
```

---

## Task 3: Add pointGoals feature flag key

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/TheBetterWe/Services/FeatureToggle.swift`

- [x] **Step 1: Add key**

Change:
```swift
    enum Key: CaseIterable {}
```
To:
```swift
    enum Key: CaseIterable {
        case pointGoals
    }
```

- [x] **Step 2: Verify build**

Build (`⌘B`). Expected: Build Succeeded.

- [x] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/TheBetterWe/Services/FeatureToggle.swift
git commit -m "feat: add pointGoals feature flag key"
```

---

## Task 4: DB migration — point_goals table

**Files:**
- Create: `server/migrations/004_create_point_goals.js`

- [x] **Step 1: Create migration file**

```js
/* eslint-disable camelcase */
exports.shorthands = undefined;

exports.up = (pgm) => {
  pgm.createTable('point_goals', {
    id: { type: 'serial', primaryKey: true },
    member_id: {
      type: 'integer',
      notNull: true,
      references: 'family_members(id)',
      onDelete: 'CASCADE',
    },
    name: { type: 'text', notNull: true },
    target_points: { type: 'integer', notNull: true },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('NOW()') },
  });
  pgm.addIndex('point_goals', 'member_id');
};

exports.down = (pgm) => {
  pgm.dropTable('point_goals');
};
```

- [x] **Step 2: Run migration locally**

```bash
cd server && npm run migrate
```

Expected output includes: `Running migration: 004_create_point_goals`

- [x] **Step 3: Commit**

```bash
git add server/migrations/004_create_point_goals.js
git commit -m "feat: migration 004 — point_goals table"
```

---

## Task 5: Add server endpoints — GET events, DELETE event, Goals CRUD

**Files:**
- Modify: `server/src/routes/pointSystem.ts`
- Modify: `server/src/routes/featureToggles.ts`

- [x] **Step 1: Add GET events endpoint**

In `pointSystem.ts`, add before `export default router`:

```typescript
// GET /families/:familyId/point-system/members/:memberId/events?limit=20&offset=0
router.get('/:familyId/point-system/members/:memberId/events', async (req: Request, res: Response) => {
  const familyId = parseInt(req.params.familyId, 10);
  const memberId = parseInt(req.params.memberId, 10);
  const userId = req.auth!.sub;
  const limit = Math.min(parseInt((req.query.limit as string) ?? '20', 10), 50);
  const offset = parseInt((req.query.offset as string) ?? '0', 10);

  if (!(await isMember(familyId, userId))) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  const rows = (await pool.query(
    `SELECT
      pe.id          AS "eventId",
      pe.member_id   AS "memberId",
      pe.delta,
      pe.note,
      pe.event_date  AS "eventDate",
      pe.created_at  AS "createdAt"
    FROM point_events pe
    JOIN family_members fm ON fm.id = pe.member_id
    WHERE pe.member_id = $1 AND fm.family_id = $2
    ORDER BY pe.created_at DESC
    LIMIT $3 OFFSET $4`,
    [memberId, familyId, limit, offset]
  )).rows;

  res.json(rows);
});
```

- [x] **Step 2: Add DELETE event endpoint**

```typescript
// DELETE /families/:familyId/point-system/events/:eventId
router.delete('/:familyId/point-system/events/:eventId', async (req: Request, res: Response) => {
  const familyId = parseInt(req.params.familyId, 10);
  const eventId = parseInt(req.params.eventId, 10);
  const userId = req.auth!.sub;

  if (!(await isMember(familyId, userId))) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  const result = await pool.query(
    `DELETE FROM point_events pe
     USING family_members fm
     WHERE pe.id = $1 AND pe.member_id = fm.id AND fm.family_id = $2
     RETURNING pe.id`,
    [eventId, familyId]
  );

  if (result.rows.length === 0) {
    res.status(404).json({ error: 'event not found' });
    return;
  }

  res.status(204).send();
});
```

- [x] **Step 3: Add GET goals endpoint**

```typescript
// GET /families/:familyId/point-system/members/:memberId/goals
router.get('/:familyId/point-system/members/:memberId/goals', async (req: Request, res: Response) => {
  const familyId = parseInt(req.params.familyId, 10);
  const memberId = parseInt(req.params.memberId, 10);
  const userId = req.auth!.sub;

  if (!(await isMember(familyId, userId))) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  const rows = (await pool.query(
    `SELECT
      pg.id             AS "goalId",
      pg.member_id      AS "memberId",
      pg.name,
      pg.target_points  AS "targetPoints"
    FROM point_goals pg
    JOIN family_members fm ON fm.id = pg.member_id
    WHERE pg.member_id = $1 AND fm.family_id = $2
    ORDER BY pg.created_at ASC`,
    [memberId, familyId]
  )).rows;

  res.json(rows);
});
```

- [x] **Step 4: Add POST goal endpoint**

```typescript
// POST /families/:familyId/point-system/goals
router.post('/:familyId/point-system/goals', async (req: Request, res: Response) => {
  const familyId = parseInt(req.params.familyId, 10);
  const userId = req.auth!.sub;
  const { memberId, name, targetPoints } = req.body as {
    memberId?: number;
    name?: string;
    targetPoints?: number;
  };

  if (!(await isMember(familyId, userId))) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  if (
    typeof memberId !== 'number' ||
    !name?.trim() ||
    typeof targetPoints !== 'number' ||
    !Number.isInteger(targetPoints) ||
    targetPoints < 1 ||
    targetPoints > 999999
  ) {
    res.status(400).json({ error: 'invalid request' });
    return;
  }

  const result = await pool.query(
    `INSERT INTO point_goals (member_id, name, target_points)
     SELECT $1, $2, $3
     WHERE EXISTS (
       SELECT 1 FROM family_members fm
       WHERE fm.id = $1 AND fm.family_id = $4
     )
     RETURNING id AS "goalId", member_id AS "memberId", name, target_points AS "targetPoints"`,
    [memberId, name.trim(), targetPoints, familyId]
  );

  if (result.rows.length === 0) {
    res.status(404).json({ error: 'member not found in this family' });
    return;
  }

  res.status(201).json(result.rows[0]);
});
```

- [x] **Step 5: Add DELETE goal endpoint**

```typescript
// DELETE /families/:familyId/point-system/goals/:goalId
router.delete('/:familyId/point-system/goals/:goalId', async (req: Request, res: Response) => {
  const familyId = parseInt(req.params.familyId, 10);
  const goalId = parseInt(req.params.goalId, 10);
  const userId = req.auth!.sub;

  if (!(await isMember(familyId, userId))) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  const result = await pool.query(
    `DELETE FROM point_goals pg
     USING family_members fm
     WHERE pg.id = $1 AND pg.member_id = fm.id AND fm.family_id = $2
     RETURNING pg.id`,
    [goalId, familyId]
  );

  if (result.rows.length === 0) {
    res.status(404).json({ error: 'goal not found' });
    return;
  }

  res.status(204).send();
});
```

- [x] **Step 6: Update featureToggles.ts**

Replace:
```typescript
router.get('/', (_req, res) => {
  res.json({});
});
```
With:
```typescript
router.get('/', (_req, res) => {
  res.json({
    pointGoals: false,
  });
});
```

- [x] **Step 7: Verify TypeScript compiles**

```bash
cd server && npm run build 2>&1 | tail -5
```
Expected: no errors (exit 0).

- [x] **Step 8: Commit**

```bash
git add server/src/routes/pointSystem.ts server/src/routes/featureToggles.ts
git commit -m "feat: add GET events, DELETE event, Goals CRUD endpoints"
```

---

## Task 6: Update PointSystemService with new methods

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/TheBetterWe/Services/PointSystemService.swift`

- [x] **Step 1: Add `delete` helper after the `post` helper**

In `PointSystemService`, add before the closing `}` of the `// MARK: - Helpers` section:

```swift
    private static func delete(path: String) async throws {
        guard let token = AuthService.accessToken else { throw PointSystemError.unauthorized }
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try await send(request, expectedStatus: 204)
    }
```

- [x] **Step 2: Add fetchActivities and deleteActivity**

After `addPointEvent`, add:

```swift
    static func fetchActivities(familyId: Int, memberId: Int, limit: Int = 20, offset: Int = 0) async throws -> [PSActivity] {
        let data = try await get(path: "/families/\(familyId)/point-system/members/\(memberId)/events?limit=\(limit)&offset=\(offset)")
        guard let activities = try? JSONDecoder().decode([PSActivity].self, from: data) else {
            throw PointSystemError.network
        }
        return activities
    }

    static func deleteActivity(familyId: Int, eventId: Int) async throws {
        try await delete(path: "/families/\(familyId)/point-system/events/\(eventId)")
    }
```

- [x] **Step 3: Add fetchGoals, createGoal, deleteGoal**

```swift
    static func fetchGoals(familyId: Int, memberId: Int) async throws -> [PSGoal] {
        let data = try await get(path: "/families/\(familyId)/point-system/members/\(memberId)/goals")
        guard let goals = try? JSONDecoder().decode([PSGoal].self, from: data) else {
            throw PointSystemError.network
        }
        return goals
    }

    static func createGoal(familyId: Int, memberId: Int, name: String, targetPoints: Int) async throws -> PSGoal {
        struct Body: Encodable {
            let memberId: Int
            let name: String
            let targetPoints: Int
        }
        let data = try await post(
            path: "/families/\(familyId)/point-system/goals",
            body: Body(memberId: memberId, name: name, targetPoints: targetPoints),
            expectedStatus: 201
        )
        guard let goal = try? JSONDecoder().decode(PSGoal.self, from: data) else {
            throw PointSystemError.network
        }
        return goal
    }

    static func deleteGoal(familyId: Int, goalId: Int) async throws {
        try await delete(path: "/families/\(familyId)/point-system/goals/\(goalId)")
    }
```

- [x] **Step 4: Verify build**

Build (`⌘B`). Expected: Build Succeeded.

- [x] **Step 5: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/TheBetterWe/Services/PointSystemService.swift
git commit -m "feat: add activities and goals service methods to PointSystemService"
```

---

## Task 7: Update PointAdjustFormView for sheet presentation

The form currently has no title or dismiss button. When shown as a `.sheet()`, it needs a header.

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointAdjustFormView.swift`

- [x] **Step 1: Add `onDismiss` parameter and sheet header**

Add `onDismiss` closure parameter and a sheet header above `stepperArea`. Change the struct signature:

```swift
struct PointAdjustFormView: View {
    let style: ActionStyle
    let familyId: Int
    let memberId: Int
    let onSuccess: (Int) -> Void
    let onLogOut: () -> Void
    var onDismiss: (() -> Void)? = nil   // nil = not in sheet mode
```

Replace the `body` with:

```swift
    var body: some View {
        VStack(spacing: 0) {
            if let dismiss = onDismiss {
                sheetHeader(dismiss: dismiss)
            }
            stepperArea
            noteField
                .padding(.horizontal, PointSystemStyle.formHPadding)
                .padding(.top, 14)
            moreSection
                .padding(.horizontal, PointSystemStyle.formHPadding)
            confirmSection
                .padding(.horizontal, PointSystemStyle.formHPadding)
                .padding(.top, 16)
                .padding(.bottom, PointSystemStyle.formVPadding)
        }
        .background(Color(.systemGray6))
    }
```

Add the `sheetHeader` view builder after the `body`:

```swift
    @ViewBuilder
    private func sheetHeader(dismiss: @escaping () -> Void) -> some View {
        HStack {
            Text(style.confirmLabel)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color(.systemGray3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PointSystemStyle.formHPadding)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
```

- [x] **Step 2: Verify build**

Build (`⌘B`). Expected: Build Succeeded.

- [x] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointAdjustFormView.swift
git commit -m "feat: add sheet header to PointAdjustFormView"
```

---

## Task 8: Redesign PointSystemView.swift

This is the main UI task. Replace everything in `PointSystemView.swift` with the new design.

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemView.swift`

- [x] **Step 1: Replace entire file content**

```swift
import SwiftUI

// MARK: - PointSystemView

struct PointSystemView: View {
    let membership: FamilyMembership
    var onLogOut: () -> Void = {}

    @State private var children: [PSChild] = []
    @State private var selectedIndex: Int = 0
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var navigateToAddChild = false

    private var safeIndex: Int { min(selectedIndex, max(0, children.count - 1)) }
    private var selectedChild: PSChild? { children.isEmpty ? nil : children[safeIndex] }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if let msg = errorMessage {
                    errorView(msg)
                } else {
                    memberGridSection
                    if let child = selectedChild {
                        ChildCardView(
                            child: child,
                            familyId: membership.familyId,
                            onBalanceChange: { newBalance in
                                if let idx = children.firstIndex(where: { $0.memberId == child.memberId }) {
                                    children[idx].balance = newBalance
                                }
                            },
                            onLogOut: onLogOut
                        )
                        .id(child.id)

                        if FeatureToggle.isActive(.pointGoals) {
                            GoalProgressSection(
                                child: child,
                                familyId: membership.familyId,
                                onLogOut: onLogOut
                            )
                            .id("goals-\(child.id)")
                        }

                        ActivitySection(
                            child: child,
                            familyId: membership.familyId,
                            onLogOut: onLogOut
                        )
                        .id("activity-\(child.id)")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationDestination(isPresented: $navigateToAddChild) {
            AddChildView(familyId: membership.familyId) { newChild in
                children.append(newChild)
                selectedIndex = children.count - 1
            }
        }
        .task { await loadChildren() }
        .onChange(of: children) { _, newValue in
            if selectedIndex >= newValue.count {
                selectedIndex = max(0, newValue.count - 1)
            }
        }
    }

    // MARK: Member grid

    private var memberGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Family Members")
                .font(.system(size: PointSystemStyle.sectionHeaderFontSize, weight: .bold))
                .foregroundStyle(.primary)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: PointSystemStyle.memberGridColumns)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    MemberAvatarCell(
                        child: child,
                        isSelected: index == safeIndex
                    ) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedIndex = index
                        }
                    }
                }
                // Add child button
                Button { navigateToAddChild = true } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .foregroundStyle(Color(.systemGray3))
                                .frame(width: PointSystemStyle.memberAvatarSize,
                                       height: PointSystemStyle.memberAvatarSize)
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color(.systemGray3))
                        }
                        Text("New")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(.systemGray3))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    // MARK: Error

    @ViewBuilder
    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Text(verbatim: msg)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") {
                Task { await loadChildren() }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: Data

    private func loadChildren() async {
        isLoading = true
        errorMessage = nil
        do {
            children = try await PointSystemService.fetchChildren(familyId: membership.familyId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - MemberAvatarCell

private struct MemberAvatarCell: View {
    let child: PSChild
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color(.systemGray4),
                            lineWidth: isSelected ? PointSystemStyle.memberAvatarBorderWidth + 1 : PointSystemStyle.memberAvatarBorderWidth
                        )
                        .frame(width: PointSystemStyle.memberAvatarSize,
                               height: PointSystemStyle.memberAvatarSize)
                    Text(child.gender.avatarEmoji)
                        .font(.system(size: 28))
                }
                Text(verbatim: child.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

// MARK: - ChildCardView

private struct ChildCardView: View {
    let child: PSChild
    let familyId: Int
    let onBalanceChange: (Int) -> Void
    let onLogOut: () -> Void

    private enum Sheet { case deduct, reward }
    @State private var activeSheet: Sheet? = nil

    var body: some View {
        VStack(spacing: 16) {
            // Top row: avatar+info | points
            HStack(alignment: .center, spacing: 16) {
                // Avatar + name + age
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.accentColor, lineWidth: PointSystemStyle.memberAvatarBorderWidth)
                            .frame(width: PointSystemStyle.childCardAvatarSize,
                                   height: PointSystemStyle.childCardAvatarSize)
                        Text(child.gender.avatarEmoji)
                            .font(.system(size: 24))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: child.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let age = ageString() {
                            Text(verbatim: age)
                                .font(.caption)
                                .foregroundStyle(.accentColor)
                        }
                    }
                }
                Spacer()
                // Points
                VStack(alignment: .trailing, spacing: 0) {
                    Text(child.balance, format: .number)
                        .font(.system(size: PointSystemStyle.pointsDisplayFontSize, weight: .heavy))
                        .foregroundStyle(.accentColor)
                        .contentTransition(.numericText())
                    Text("points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    activeSheet = .deduct
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Deduct")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: PointSystemStyle.actionButtonHeight)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    activeSheet = .reward
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Reward")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: PointSystemStyle.actionButtonHeight)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(PointSystemStyle.childCardPadding)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: PointSystemStyle.childCardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PointSystemStyle.childCardCornerRadius)
                .strokeBorder(Color(.systemGray4), lineWidth: PointSystemStyle.childCardBorderWidth)
        )
        .sheet(item: $activeSheet) { sheet in
            PointAdjustFormView(
                style: sheet == .reward ? .add : .deduct,
                familyId: familyId,
                memberId: child.memberId,
                onSuccess: { newBalance in
                    onBalanceChange(newBalance)
                    activeSheet = nil
                },
                onLogOut: onLogOut,
                onDismiss: { activeSheet = nil }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
    }

    private static let birthdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func ageString() -> String? {
        guard let birthday = child.birthday,
              let date = Self.birthdayFormatter.date(from: birthday) else { return nil }
        let years = Calendar.current.dateComponents([.year], from: date, to: .now).year ?? 0
        return String(format: String(localized: "%d years old"), years)
    }
}

// Make Sheet conform to Identifiable for .sheet(item:)
extension ChildCardView.Sheet: Identifiable {
    var id: Int { self == .reward ? 1 : 0 }
}

// MARK: - GoalProgressSection

private struct GoalProgressSection: View {
    let child: PSChild
    let familyId: Int
    let onLogOut: () -> Void

    @State private var goals: [PSGoal] = []
    @State private var isLoading = false
    @State private var showAddGoal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress to Goal")
                    .font(.system(size: PointSystemStyle.sectionHeaderFontSize, weight: .bold))
                Spacer()
                Button {
                    showAddGoal = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if goals.isEmpty {
                Text("No goals yet — tap + to add one")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(goals) { goal in
                        GoalRow(
                            goal: goal,
                            currentBalance: child.balance,
                            onDelete: {
                                Task { await deleteGoal(goal) }
                            }
                        )
                    }
                }
            }
        }
        .task { await loadGoals() }
        .sheet(isPresented: $showAddGoal) {
            AddGoalSheet(
                childName: child.name,
                onSave: { name, targetPoints in
                    Task { await addGoal(name: name, targetPoints: targetPoints) }
                    showAddGoal = false
                },
                onCancel: { showAddGoal = false }
            )
            .presentationDetents([.medium])
        }
    }

    private func loadGoals() async {
        isLoading = true
        if let fetched = try? await PointSystemService.fetchGoals(familyId: familyId, memberId: child.memberId) {
            goals = fetched
        }
        isLoading = false
    }

    private func addGoal(name: String, targetPoints: Int) async {
        if let goal = try? await PointSystemService.createGoal(
            familyId: familyId,
            memberId: child.memberId,
            name: name,
            targetPoints: targetPoints
        ) {
            goals.append(goal)
        }
    }

    private func deleteGoal(_ goal: PSGoal) async {
        try? await PointSystemService.deleteGoal(familyId: familyId, goalId: goal.goalId)
        goals.removeAll { $0.goalId == goal.goalId }
    }
}

// MARK: - GoalRow

private struct GoalRow: View {
    let goal: PSGoal
    let currentBalance: Int
    let onDelete: () -> Void

    private var progress: Double {
        guard goal.targetPoints > 0 else { return 0 }
        return min(1.0, Double(currentBalance) / Double(goal.targetPoints))
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(verbatim: goal.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(currentBalance)/\(goal.targetPoints)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.accentColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: PointSystemStyle.goalProgressHeight)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(
                            width: geo.size.width * progress,
                            height: PointSystemStyle.goalProgressHeight
                        )
                        .animation(.easeOut(duration: 0.6), value: progress)
                }
            }
            .frame(height: PointSystemStyle.goalProgressHeight)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.systemGray4), lineWidth: 1)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - AddGoalSheet

private struct AddGoalSheet: View {
    let childName: String
    let onSave: (String, Int) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var targetText = ""

    private var targetPoints: Int? { Int(targetText).flatMap { $0 > 0 ? $0 : nil } }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && targetPoints != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Goal")
                    .font(.headline)
                Spacer()
                Button { onCancel() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color(.systemGray3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            VStack(spacing: 12) {
                TextField("Goal name (e.g. Screen Time)", text: $name)
                    .textFieldStyle(.roundedBorder)
                TextField("Target points", text: $targetText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
            }
            .padding(.horizontal, 20)

            Spacer()

            Button {
                guard let pts = targetPoints else { return }
                onSave(name.trimmingCharacters(in: .whitespaces), pts)
            } label: {
                Text("Save Goal")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: PointSystemStyle.actionButtonHeight)
                    .background(canSave ? Color.accentColor : Color(.systemGray4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - ActivitySection

private struct ActivitySection: View {
    let child: PSChild
    let familyId: Int
    let onLogOut: () -> Void

    @State private var activities: [PSActivity] = []
    @State private var isLoading = false
    @State private var navigateToRecord = false

    private let pageSize = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activities")
                    .font(.system(size: PointSystemStyle.sectionHeaderFontSize, weight: .bold))
                Spacer()
            }

            if isLoading && activities.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            } else if activities.isEmpty {
                Text("No activity yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                        ActivityRow(activity: activity, onDelete: {
                            Task { await deleteActivity(activity) }
                        })
                        if index < activities.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(.systemGray4), lineWidth: 1)
                )

                NavigationLink(destination: PointRecordView(child: child)) {
                    Text("View More")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.accentColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .task { await loadActivities() }
    }

    private func loadActivities() async {
        isLoading = true
        if let fetched = try? await PointSystemService.fetchActivities(
            familyId: familyId,
            memberId: child.memberId,
            limit: pageSize
        ) {
            activities = fetched
        }
        isLoading = false
    }

    private func deleteActivity(_ activity: PSActivity) async {
        try? await PointSystemService.deleteActivity(familyId: familyId, eventId: activity.eventId)
        activities.removeAll { $0.eventId == activity.eventId }
    }
}

// MARK: - ActivityRow

private struct ActivityRow: View {
    let activity: PSActivity
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(activity.isPositive ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                .frame(width: PointSystemStyle.activityIconSize,
                       height: PointSystemStyle.activityIconSize)
                .overlay(
                    Image(systemName: activity.isPositive ? "star.fill" : "minus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(activity.isPositive ? .green : .red)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: activity.note ?? (activity.isPositive ? "Points added" : "Points deducted"))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(verbatim: activity.eventDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(verbatim: activity.deltaText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(activity.isPositive ? .green : .red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Previews

#Preview("Single child — boy") {
    NavigationStack {
        PointSystemView(membership: FamilyMembership(
            familyId: 1, familyName: "杨家", memberId: 1,
            displayName: "爸爸", roleKeywords: ["pointSystem"]
        ))
    }
}

#Preview("ChildCardView — boy") {
    NavigationStack {
        ChildCardView(
            child: PSChild(memberId: 1, name: "桅", gender: .boy,
                           birthday: "2022-03-15", balance: 1280),
            familyId: 1,
            onBalanceChange: { _ in },
            onLogOut: {}
        )
        .padding()
    }
}

#Preview("ActivityRow — positive") {
    ActivityRow(
        activity: PSActivity(
            eventId: 1, memberId: 1, delta: 25,
            note: "Morning Routine", eventDate: "2026-05-29", createdAt: "2026-05-29T08:00:00Z"
        ),
        onDelete: {}
    )
}

#Preview("Empty state") {
    NavigationStack {
        PointSystemView(membership: FamilyMembership(
            familyId: 99, familyName: "Empty Family", memberId: 1,
            displayName: "Dad", roleKeywords: ["pointSystem"]
        ))
    }
}
```

- [x] **Step 2: Verify build**

Build (`⌘B`). Expected: Build Succeeded.

- [x] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemView.swift
git commit -m "feat: redesign PointSystemView to match v1.0.1 design"
```

---

## Task 9: Add zh-Hans translations

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/TheBetterWe/Resources/Localizable.xcstrings`

- [x] **Step 1: Open Localizable.xcstrings in Xcode**

Open Xcode → `Localizable.xcstrings`. Add zh-Hans translations for each new string:

| English key | zh-Hans |
|-------------|---------|
| `"Family Members"` | `"家庭成员"` |
| `"New"` | `"添加"` |
| `"Retry"` | `"重试"` |
| `"Deduct"` | `"扣分"` |
| `"Reward"` | `"加分"` |
| `"Progress to Goal"` | `"目标进度"` |
| `"No goals yet — tap + to add one"` | `"暂无目标，点击 + 添加"` |
| `"Delete"` | `"删除"` |
| `"Add Goal"` | `"添加目标"` |
| `"Goal name (e.g. Screen Time)"` | `"目标名称（如：屏幕时间）"` |
| `"Target points"` | `"目标积分"` |
| `"Save Goal"` | `"保存目标"` |
| `"Activities"` | `"最近记录"` |
| `"No activity yet"` | `"暂无记录"` |
| `"View More"` | `"查看更多"` |
| `"Points added"` | `"加分"` |
| `"Points deducted"` | `"扣分"` |

- [x] **Step 2: Build and verify no localization warnings**

Build (`⌘B`). Expected: Build Succeeded without localization errors.

- [x] **Step 3: Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/TheBetterWe/Resources/Localizable.xcstrings
git commit -m "i18n: add zh-Hans translations for point system redesign"
```

---

## Task 10: Manual verification

- [x] **Step 1: Start server locally**

```bash
cd server && npm run dev
```
Expected: Server starts on port 3000.

- [x] **Step 2: Verify GET events endpoint**

```bash
# Replace TOKEN and IDs with real values
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/families/1/point-system/members/1/events?limit=5" | jq .
```
Expected: JSON array of event objects with `eventId`, `delta`, `note`, `eventDate`.

- [x] **Step 3: Verify goals endpoints**

```bash
# Create goal
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"memberId":1,"name":"Screen Time","targetPoints":600}' \
  "http://localhost:3000/families/1/point-system/goals" | jq .
# Expected: {"goalId":1,"memberId":1,"name":"Screen Time","targetPoints":600}

# List goals
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/families/1/point-system/members/1/goals" | jq .
# Expected: array with the goal above
```

- [x] **Step 4: Run app in Simulator**

Build and run (`⌘R`) on iPhone 16 Pro simulator.
- Navigate to Point System tab
- Verify: avatar grid shows children + Add button
- Tap a child: verify white card appears with points on right, Deduct/Reward buttons below
- Tap "Reward": verify sheet slides up with form + title + X button
- Enter 10 points + tap "Add Points": verify sheet dismisses, balance updates with animation
- Verify Activities section shows recent events (or "No activity yet")
- Enable `pointGoals` in `featureToggles.ts` (`pointGoals: true`), restart server, force-refresh app; verify Goals section appears

- [x] **Step 5: Chinese locale test**

In Simulator: Settings → General → Language & Region → Chinese (Simplified).
Relaunch app → verify all strings appear in zh-Hans.

- [x] **Step 6: Final commit if any tweaks were needed**

```bash
git add -A
git commit -m "fix: post-verification tweaks to point system redesign"
```

---

## Self-Review

**Spec coverage:**
- ✅ Family member avatar grid (4 columns, emoji, name, add button)
- ✅ White child card (avatar | name | age | points | Deduct/Reward buttons)
- ✅ Point adjustment via sheet modal (PointAdjustFormView with header)
- ✅ Activities section inline with swipe-to-delete and View More
- ✅ Progress to Goal section (feature-flagged `pointGoals`)
- ✅ Server endpoints: GET events, DELETE event, Goals CRUD
- ✅ DB migration for `point_goals` table
- ✅ zh-Hans translations for all new strings
- ✅ Feature flag added server-side (off by default) and iOS FeatureToggle.Key

**Placeholder check:** None found.

**Type consistency:**
- `PSActivity.eventId` → used as `PointSystemService.deleteActivity(eventId:)` ✅
- `PSGoal.goalId` → used as `PointSystemService.deleteGoal(goalId:)` ✅
- `PointSystemStyle.childCardAvatarSize` → referenced in `ChildCardView` ✅
- `PointSystemStyle.sectionHeaderFontSize` → used in all section headers ✅
- `ChildCardView.Sheet` `Identifiable` extension → `activeSheet` binding in `.sheet(item:)` ✅

---

## Implementation Notes (deviations from plan — committed 2026-05-29)

**Status: ALL TASKS COMPLETE** — Final commit: `fe01f6d` on branch `ay_dev`

### Changes from original plan

| Plan | Actual | Reason |
|------|--------|--------|
| Migration 004: `type: 'timestamptz'` | Changed to `type: 'integer'` with `pgm.func('EXTRACT(EPOCH FROM NOW())::INTEGER')` | Every existing table uses INTEGER epoch; timestamptz would break sort consistency |
| `GoalRow` + `ActivityRow`: `.swipeActions(...)` | Changed to `.contextMenu { ... }` | `.swipeActions` is silently ignored outside `List`; both rows live in `VStack` |
| `GoalProgressSection.addGoal`: `try?` | `do/catch` with `@State private var createGoalErrorMessage` + `.alert` | Silent failures invisible to user |
| `ActivitySection.deleteActivity`: `try?` | `do/catch`; remove from local state only on success | Non-optimistic pattern: never hide server errors |
| Server routes: `parseInt(req.params.X)` directly | Added `parseIntParam` helper; 400-guard before all SQL | `parseInt` returns `NaN` for strings; `NaN` in pg bind crashes query |
| Server routes: no child-role check | Added `SELECT 1 FROM member_role_keywords WHERE keyword = 'child'` on GET events, GET goals, POST goals | Any familyId could be passed without check |
| `ActivitySection` had no balance propagation | Added `onBalanceChange: (Int) -> Void` parameter; `ChildCardView` passes closure computing `child.balance - activity.delta` | Balance on card went stale after delete |
| Plan replaced entire `PointSystemView.swift` | Legacy `ChildTabBar` + `ChildFullView` preserved under `// MARK: - Legacy (preserved for reuse)` | User requested explicit preservation for future reuse |
| `PointSystemStyle.goalProgressCornerRadius` | Removed (dead — `Capsule()` has no cornerRadius param) | Compiler dead-code warning; Capsule is self-rounding |
| `NavigationLink(destination:)` in ActivitySection | Changed to `@State private var navigateToRecord` + `.navigationDestination(isPresented:)` | `NavigationLink(destination:)` deprecated in iOS 16+ |
| xcstrings: both `"Add Goal"` and `"Add goal"` had `extractionState: "manual"` | Removed `extractionState` from both | Same Swift symbol `addGoal` generated from both → compile error |
