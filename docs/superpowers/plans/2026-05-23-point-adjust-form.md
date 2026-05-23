# Point Adjust Form (加分/扣分) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the "Coming Soon" placeholder inside the Add/Deduct rows with a working inline form that posts a point event to the server, updates the child's displayed balance, and auto-collapses the row on success.

**Architecture:** Single reusable `PointAdjustFormView` parameterized by `ActionStyle` (tint + label + sign). The form is a pure child component — it calls `onSuccess(newBalance)` and `onLogOut()` callbacks; the parent `ChildFullView` owns `expandedRow` state and handles collapsing. `onLogOut` is threaded from `MainTabView` → `FamilyView` → `PointSystemView` → `ChildFullView` → `PointAdjustFormView`.

**Tech Stack:** Swift/SwiftUI (iOS), Node.js + Express + TypeScript + better-sqlite3 (server), xcstrings (localization)

**Spec:** `docs/superpowers/specs/2026-05-23-point-adjust-form-design.md`

---

## File Map

| Action | File |
|--------|------|
| Modify | `server/src/routes/pointSystem.ts` |
| Modify | `ios/TheBetterWe/TheBetterWe/Models/PointSystemModels.swift` |
| Modify | `ios/TheBetterWe/TheBetterWe/Services/PointSystemService.swift` |
| Modify | `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemStyle.swift` |
| Modify | `ios/TheBetterWe/TheBetterWe/Resources/Localizable.xcstrings` |
| **Create** | `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointAdjustFormView.swift` |
| Modify | `ios/TheBetterWe/TheBetterWe/Views/Main/MainTabView.swift` |
| Modify | `ios/TheBetterWe/TheBetterWe/Views/Family/FamilyView.swift` |
| Modify | `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemView.swift` |

---

## Task 1: Server — POST point event endpoint

**Files:**
- Modify: `server/src/routes/pointSystem.ts`

- [ ] **Step 1.1 — Add the POST /events route**

Open `server/src/routes/pointSystem.ts`. Add this block **before** the `export default router` line:

```typescript
// POST /families/:familyId/point-system/events
router.post('/:familyId/point-system/events', (req: Request, res: Response) => {
  const familyId = parseInt(req.params.familyId, 10);
  const userId = req.auth!.sub;
  const { memberId, delta, note } = req.body as {
    memberId?: number;
    delta?: number;
    note?: string;
  };

  if (!isMember(familyId, userId)) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  if (
    typeof memberId !== 'number' ||
    typeof delta !== 'number' ||
    !Number.isInteger(delta) ||
    delta === 0 ||
    Math.abs(delta) > 9999
  ) {
    res.status(400).json({ error: 'invalid memberId or delta' });
    return;
  }

  const childMember = db.prepare(`
    SELECT fm.id FROM family_members fm
    WHERE fm.id = ? AND fm.family_id = ?
      AND EXISTS (
        SELECT 1 FROM member_role_keywords k
        WHERE k.member_id = fm.id AND k.keyword = 'child'
      )
  `).get(memberId, familyId) as { id: number } | undefined;

  if (!childMember) {
    res.status(404).json({ error: 'child member not found in this family' });
    return;
  }

  const safeNote = (typeof note === 'string' && note.trim()) ? note.trim() : null;

  const { lastInsertRowid } = db.prepare(
    'INSERT INTO point_events (member_id, delta, note) VALUES (?, ?, ?)'
  ).run(memberId, delta, safeNote);

  const eventId = Number(lastInsertRowid);

  const { newBalance } = db.prepare(
    'SELECT COALESCE(SUM(delta), 0) AS newBalance FROM point_events WHERE member_id = ?'
  ).get(memberId) as { newBalance: number };

  res.status(201).json({ eventId, memberId, delta, note: safeNote, newBalance });
});
```

- [ ] **Step 1.2 — Restart the server and verify**

```bash
cd /Users/alexyang/Claude/TheBetterWe/server && npm run dev
```

In a second terminal, test with curl (replace `TOKEN` and `FAMILY_ID`/`MEMBER_ID` with real values from a login response and your DB):

```bash
# Login first to get a token
curl -s -X POST http://localhost:3000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"YOUR_USER","password":"YOUR_PASS"}' | jq .

# Award 5 points to member 1 in family 1
curl -s -X POST http://localhost:3000/families/1/point-system/events \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer TOKEN' \
  -d '{"memberId":1,"delta":5,"note":"Great job!"}' | jq .
```

Expected response:
```json
{
  "eventId": 1,
  "memberId": 1,
  "delta": 5,
  "note": "Great job!",
  "newBalance": 5
}
```

Test deduct: `"delta": -3` → response has `newBalance: 2`. Test invalid: `"delta": 0` → HTTP 400.

- [ ] **Step 1.3 — Commit**

```bash
git add server/src/routes/pointSystem.ts
git commit -m "feat(server): POST /families/:id/point-system/events endpoint"
```

---

## Task 2: iOS Model — PointEventResponse

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Models/PointSystemModels.swift`

- [ ] **Step 2.1 — Add PointEventResponse**

Append to the bottom of `PointSystemModels.swift` (after the `PSChild` struct):

```swift
struct PointEventResponse: Decodable {
    let eventId: Int
    let memberId: Int
    let delta: Int
    let note: String?
    let newBalance: Int
}
```

- [ ] **Step 2.2 — Verify the file builds**

In Xcode: Product → Build (⌘B). Expect no errors.

- [ ] **Step 2.3 — Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Models/PointSystemModels.swift
git commit -m "feat(ios): add PointEventResponse model"
```

---

## Task 3: iOS Service — addPointEvent

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Services/PointSystemService.swift`

- [ ] **Step 3.1 — Add addPointEvent method**

In `PointSystemService.swift`, add this method after `addChild(...)`. Place it before the `// MARK: - Helpers` comment:

```swift
static func addPointEvent(
    familyId: Int,
    memberId: Int,
    delta: Int,
    note: String?
) async throws -> PointEventResponse {
    struct Body: Encodable {
        let memberId: Int
        let delta: Int
        let note: String?
    }
    let data = try await post(
        path: "/families/\(familyId)/point-system/events",
        body: Body(memberId: memberId, delta: delta, note: note),
        expectedStatus: 201
    )
    guard let response = try? JSONDecoder().decode(PointEventResponse.self, from: data) else {
        throw PointSystemError.network
    }
    return response
}
```

- [ ] **Step 3.2 — Build to verify**

⌘B. Expect no errors.

- [ ] **Step 3.3 — Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Services/PointSystemService.swift
git commit -m "feat(ios): add PointSystemService.addPointEvent"
```

---

## Task 4: Style — form constants, tint colors, ActionStyle

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemStyle.swift`

- [ ] **Step 4.1 — Add form constants and tint colors**

In `PointSystemStyle.swift`, extend the `enum PointSystemStyle` block. Add after the existing `recordIconBackground` constant:

```swift
    // Point adjust form
    static let formHPadding: CGFloat = 20
    static let formVPadding: CGFloat = 20
    static let stepperButtonSize: CGFloat = 44
    static let stepperButtonBorderWidth: CGFloat = 1.5
    static let stepperValueFontSize: CGFloat = 52
    static let stepperUnitFontSize: CGFloat = 14
    static let stepperButtonIconSize: CGFloat = 22
    static let formFieldCornerRadius: CGFloat = 10
    static let formFieldHPadding: CGFloat = 12
    static let formFieldVPadding: CGFloat = 10
    static let formConfirmVPadding: CGFloat = 13
    static let formConfirmCornerRadius: CGFloat = 12

    static let addTint    = Color(red: 58/255, green: 123/255, blue: 213/255)
    static let deductTint = Color(red: 217/255, green: 64/255, blue: 64/255)
```

- [ ] **Step 4.2 — Add ActionStyle after the enum (top level in the file)**

After the closing `}` of `enum PointSystemStyle`, add:

```swift
// MARK: - ActionStyle

struct ActionStyle {
    let tint: Color
    let confirmLabel: LocalizedStringKey
    let sign: Int  // +1 for add points, -1 for deduct

    static let add = ActionStyle(
        tint: PointSystemStyle.addTint,
        confirmLabel: "Add Points",
        sign: 1
    )
    static let deduct = ActionStyle(
        tint: PointSystemStyle.deductTint,
        confirmLabel: "Deduct Points",
        sign: -1
    )
}
```

- [ ] **Step 4.3 — Build to verify**

⌘B. Expect no errors.

- [ ] **Step 4.4 — Commit**

```bash
git add ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemStyle.swift
git commit -m "feat(ios): point adjust form style constants and ActionStyle"
```

---

## Task 5: Localization — new xcstrings keys

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Resources/Localizable.xcstrings`

- [ ] **Step 5.1 — Add 7 new keys**

Open `Localizable.xcstrings` in a text editor. Find the `"strings"` JSON object. Add these entries (in alphabetical position — xcstrings sorts alphabetically):

```json
"Add Points" : {
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "加分确认"
      }
    }
  }
},
```

```json
"Deduct Points" : {
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "扣分确认"
      }
    }
  }
},
```

```json
"Invalid amount" : {
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "积分数量无效"
      }
    }
  }
},
```

```json
"Less" : {
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "收起"
      }
    }
  }
},
```

```json
"More" : {
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "更多"
      }
    }
  }
},
```

```json
"Note (optional)" : {
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "备注（选填）"
      }
    }
  }
},
```

```json
"tap to edit" : {
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "点击输入"
      }
    }
  }
},
```

Note: `"pts"` (→ `"分"`) already exists from the child card — do not duplicate it.

- [ ] **Step 5.2 — Build to verify xcstrings parses**

⌘B. If there's a JSON parse error, check for missing commas between entries or trailing commas.

- [ ] **Step 5.3 — Commit**

```bash
git add "ios/TheBetterWe/TheBetterWe/Resources/Localizable.xcstrings"
git commit -m "feat(ios): localization keys for point adjust form"
```

---

## Task 6: Create PointAdjustFormView

**Files:**
- Create: `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointAdjustFormView.swift`

- [ ] **Step 6.1 — Create the file**

Create `PointAdjustFormView.swift` with this full content:

```swift
import SwiftUI

// MARK: - PointAdjustFormView

struct PointAdjustFormView: View {
    let style: ActionStyle
    let familyId: Int
    let memberId: Int
    let onSuccess: (Int) -> Void
    let onLogOut: () -> Void

    @State private var points: Int = 2
    @State private var pointsText: String = "2"
    @State private var noteText: String = ""
    @FocusState private var isEditing: Bool
    @State private var isMoreExpanded: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
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

    // MARK: Stepper

    private var stepperArea: some View {
        VStack(spacing: 4) {
            HStack(spacing: 24) {
                stepperButton(symbol: "minus") {
                    guard points > 1 else { return }
                    points -= 1
                    pointsText = "\(points)"
                }
                .opacity(isEditing ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.15), value: isEditing)

                numberField

                stepperButton(symbol: "plus") {
                    points += 1
                    pointsText = "\(points)"
                }
                .opacity(isEditing ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.15), value: isEditing)
            }

            Text("pts")
                .font(.system(size: PointSystemStyle.stepperUnitFontSize, weight: .medium))
                .foregroundStyle(.secondary)

            Text("tap to edit")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .opacity(isEditing ? 0 : 1)
                .animation(.easeInOut(duration: 0.15), value: isEditing)
        }
        .padding(.vertical, PointSystemStyle.formVPadding)
    }

    private var numberField: some View {
        TextField("", text: $pointsText)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: PointSystemStyle.stepperValueFontSize, weight: .heavy))
            .foregroundStyle(isEditing ? style.tint : Color(.label))
            .tint(style.tint)
            .focused($isEditing)
            .frame(minWidth: 60)
            .fixedSize()
            .onChange(of: pointsText) { _, newValue in
                let filtered = newValue.filter(\.isNumber)
                if filtered != newValue { pointsText = filtered }
                if let v = Int(filtered), v >= 1, v <= 9999 {
                    points = v
                }
            }
            .onChange(of: isEditing) { _, editing in
                if !editing {
                    // reset display if text is empty or out of range
                    if Int(pointsText) == nil || (Int(pointsText) ?? 0) < 1 {
                        points = max(1, points)
                        pointsText = "\(points)"
                    }
                }
            }
    }

    private func stepperButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: PointSystemStyle.stepperButtonIconSize, weight: .light))
                .foregroundStyle(style.tint)
                .frame(width: PointSystemStyle.stepperButtonSize,
                       height: PointSystemStyle.stepperButtonSize)
                .background(.white)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(style.tint,
                                    lineWidth: PointSystemStyle.stepperButtonBorderWidth)
                )
                .shadow(color: .black.opacity(0.10), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: Note field

    private var noteField: some View {
        TextField("Note (optional)", text: $noteText, axis: .vertical)
            .font(.body)
            .padding(.horizontal, PointSystemStyle.formFieldHPadding)
            .padding(.vertical, PointSystemStyle.formFieldVPadding)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: PointSystemStyle.formFieldCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PointSystemStyle.formFieldCornerRadius)
                    .stroke(Color(.systemGray4), lineWidth: 1.5)
            )
    }

    // MARK: More section

    private var moreSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isMoreExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(isMoreExpanded ? "Less" : "More")
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .rotationEffect(.degrees(isMoreExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isMoreExpanded)
                }
                .foregroundStyle(style.tint)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)

            if isMoreExpanded {
                HStack(spacing: 8) {
                    Text("🚧")
                    Text("Coming soon")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: Confirm section

    private var confirmSection: some View {
        VStack(spacing: 8) {
            Button {
                submitForm()
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(style.confirmLabel)
                            .font(.body.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, PointSystemStyle.formConfirmVPadding)
                .background(
                    LinearGradient(
                        colors: [style.tint, style.tint.opacity(0.75)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: PointSystemStyle.formConfirmCornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting || points < 1)

            if let msg = errorMessage {
                Text(verbatim: msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Submit

    private func submitForm() {
        guard points >= 1, !isSubmitting else { return }
        errorMessage = nil
        isSubmitting = true
        isEditing = false
        let delta = style.sign * points
        let note = noteText.isEmpty ? nil : noteText
        Task {
            do {
                let response = try await PointSystemService.addPointEvent(
                    familyId: familyId,
                    memberId: memberId,
                    delta: delta,
                    note: note
                )
                isSubmitting = false
                onSuccess(response.newBalance)
            } catch PointSystemError.unauthorized {
                isSubmitting = false
                onLogOut()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Previews

#Preview("Add Points — EN") {
    PointAdjustFormView(
        style: .add,
        familyId: 1,
        memberId: 1,
        onSuccess: { _ in },
        onLogOut: {}
    )
}

#Preview("Deduct Points — EN") {
    PointAdjustFormView(
        style: .deduct,
        familyId: 1,
        memberId: 1,
        onSuccess: { _ in },
        onLogOut: {}
    )
}

#Preview("中文") {
    PointAdjustFormView(
        style: .add,
        familyId: 1,
        memberId: 1,
        onSuccess: { _ in },
        onLogOut: {}
    )
    .environment(\.locale, .init(identifier: "zh-Hans"))
}
```

- [ ] **Step 6.2 — Add file to Xcode project**

In Xcode, right-click `Views/Family/PointSystem` group → Add Files → select `PointAdjustFormView.swift`. Confirm it appears in the group.

- [ ] **Step 6.3 — Build and open Previews**

⌘B. Then open the Canvas (Option+⌘+Return) and run all three previews. Verify:
- Add: blue tint on buttons, "More" link, confirm button
- Deduct: red tint throughout
- 中文: "pts" shows as "分", "Note (optional)" shows as "备注（选填）", "More" shows as "更多"

- [ ] **Step 6.4 — Commit**

```bash
git add "ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointAdjustFormView.swift"
git commit -m "feat(ios): PointAdjustFormView — inline add/deduct form"
```

---

## Task 7: Wire onLogOut chain and replace Coming Soon panels

**Files:**
- Modify: `ios/TheBetterWe/TheBetterWe/Views/Main/MainTabView.swift`
- Modify: `ios/TheBetterWe/TheBetterWe/Views/Family/FamilyView.swift`
- Modify: `ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemView.swift`

### 7a — MainTabView: pass onLogOut to FamilyView

- [ ] **Step 7a.1 — Update FamilyView call in MainTabView**

In `MainTabView.swift`, find this line:

```swift
case .family: FamilyView(membership: membership, onDeleted: onFamilyDeleted)
```

Replace with:

```swift
case .family: FamilyView(membership: membership, onDeleted: onFamilyDeleted, onLogOut: onLogOut)
```

### 7b — FamilyView: add onLogOut param and pass to PointSystemView

- [ ] **Step 7b.1 — Add onLogOut parameter to FamilyView**

In `FamilyView.swift`, find:

```swift
struct FamilyView: View {
    var membership: FamilyMembership
    var onDeleted: () -> Void = {}
```

Replace with:

```swift
struct FamilyView: View {
    var membership: FamilyMembership
    var onDeleted: () -> Void = {}
    var onLogOut: () -> Void = {}
```

- [ ] **Step 7b.2 — Pass onLogOut to PointSystemView**

In `FamilyView.swift`, find:

```swift
case .pointSystem:
    PointSystemView(membership: membership)
```

Replace with:

```swift
case .pointSystem:
    PointSystemView(membership: membership, onLogOut: onLogOut)
```

### 7c — PointSystemView: add onLogOut, update ChildFullView, wire form

- [ ] **Step 7c.1 — Add onLogOut to PointSystemView**

In `PointSystemView.swift`, find:

```swift
struct PointSystemView: View {
    let membership: FamilyMembership
```

Replace with:

```swift
struct PointSystemView: View {
    let membership: FamilyMembership
    var onLogOut: () -> Void = {}
```

- [ ] **Step 7c.2 — Update ChildFullView call in PointSystemView**

In `PointSystemView.swift`, find:

```swift
            let safeIndex = min(selectedIndex, children.count - 1)
            ChildFullView(child: children[safeIndex])
                .id(children[safeIndex].id)
                .frame(maxHeight: .infinity, alignment: .top)
```

Replace with:

```swift
            let safeIndex = min(selectedIndex, children.count - 1)
            let safeChild = children[safeIndex]
            ChildFullView(
                child: safeChild,
                familyId: membership.familyId,
                onBalanceChange: { newBalance in
                    if let idx = children.firstIndex(where: { $0.memberId == safeChild.memberId }) {
                        children[idx].balance = newBalance
                    }
                },
                onLogOut: onLogOut
            )
            .id(safeChild.id)
            .frame(maxHeight: .infinity, alignment: .top)
```

- [ ] **Step 7c.3 — Update ChildFullView struct to accept new parameters**

In `PointSystemView.swift`, find:

```swift
private struct ChildFullView: View {
    let child: PSChild

    private enum ExpandedRow: Equatable { case add, deduct }
```

Replace with:

```swift
private struct ChildFullView: View {
    let child: PSChild
    let familyId: Int
    let onBalanceChange: (Int) -> Void
    let onLogOut: () -> Void

    private enum ExpandedRow: Equatable { case add, deduct }
```

- [ ] **Step 7c.4 — Replace Coming Soon panels with PointAdjustFormView**

In `PointSystemView.swift`, inside `ChildFullView.actionRow(...)`, find the entire `if isOpen { ... }` block:

```swift
            if isOpen {
                HStack(spacing: 8) {
                    Text("🚧")
                    Text("Coming soon")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.systemGray6))
                .clipped()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
```

Replace with:

```swift
            if isOpen {
                PointAdjustFormView(
                    style: row == .add ? .add : .deduct,
                    familyId: familyId,
                    memberId: child.memberId,
                    onSuccess: { newBalance in
                        onBalanceChange(newBalance)
                        withAnimation(.easeInOut(duration: 0.22)) {
                            expandedRow = nil
                        }
                    },
                    onLogOut: onLogOut
                )
                .clipped()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
```

- [ ] **Step 7c.5 — Build**

⌘B. Expect no errors. If there are "missing argument" errors, check that all three new `ChildFullView` parameters are passed in the `contentSection` of `PointSystemView`.

- [ ] **Step 7c.6 — Update ChildFullView previews**

The existing previews for `ChildFullView` at the bottom of `PointSystemView.swift` will fail to compile because the struct now requires `familyId`, `onBalanceChange`, and `onLogOut`. Update them:

Find:
```swift
#Preview("ChildFullView — boy, 1280 pts") {
    NavigationStack {
        ChildFullView(child: PSChild(memberId: 1, name: "桅", gender: .boy,
                                    birthday: "2022-03-15", balance: 1280))
    }
}

#Preview("ChildFullView — girl, 340 pts") {
    NavigationStack {
        ChildFullView(child: PSChild(memberId: 2, name: "朵", gender: .girl,
                                    birthday: "2020-07-04", balance: 340))
    }
}
```

Replace with:
```swift
#Preview("ChildFullView — boy, 1280 pts") {
    NavigationStack {
        ChildFullView(
            child: PSChild(memberId: 1, name: "桅", gender: .boy,
                           birthday: "2022-03-15", balance: 1280),
            familyId: 1,
            onBalanceChange: { _ in },
            onLogOut: {}
        )
    }
}

#Preview("ChildFullView — girl, 340 pts") {
    NavigationStack {
        ChildFullView(
            child: PSChild(memberId: 2, name: "朵", gender: .girl,
                           birthday: "2020-07-04", balance: 340),
            familyId: 1,
            onBalanceChange: { _ in },
            onLogOut: {}
        )
    }
}
```

- [ ] **Step 7c.7 — Build again and run previews**

⌘B. Open Canvas on `PointSystemView.swift`. Run the ChildFullView previews. Tap "Add points" row — the form should expand showing the stepper with blue tint. Tap "Deduct points" — form shows with red tint. The "Coming soon" panel should be gone.

- [ ] **Step 7c.8 — Commit**

```bash
git add \
  "ios/TheBetterWe/TheBetterWe/Views/Main/MainTabView.swift" \
  "ios/TheBetterWe/TheBetterWe/Views/Family/FamilyView.swift" \
  "ios/TheBetterWe/TheBetterWe/Views/Family/PointSystem/PointSystemView.swift"
git commit -m "feat(ios): wire PointAdjustFormView into ChildFullView, thread onLogOut"
```

---

## Task 8: Manual end-to-end test

- [ ] **Step 8.1 — Run the app on simulator**

Ensure the local server is running (`npm run dev` in the server directory). Run the iOS app in the simulator.

- [ ] **Step 8.2 — Test Add Points**

1. Navigate to Point System tab for a family with at least one child
2. Tap "Add points" row — form expands with blue tint, default value 2, "pts" label, "tap to edit" hint
3. Tap the large number — it turns blue, cursor appears, buttons dim
4. Type a different value (e.g., 10) — number updates
5. Tap the + button while not editing — value increments
6. Tap − at value 1 — value stays at 1 (clamped)
7. Fill in a note
8. Tap "Add Points" — spinner appears, then row collapses and the balance on the child card increases by the entered amount

- [ ] **Step 8.3 — Test Deduct Points**

Tap "Deduct points" — form shows red tint. Submit — balance decreases.

- [ ] **Step 8.4 — Test "More" section**

Tap "More ▾" inside the form — Coming Soon placeholder appears. Tap "Less ▴" — collapses.

- [ ] **Step 8.5 — Test Chinese locale**

In Simulator: Settings → General → Language & Region → Preferred Languages → add Chinese (Simplified), move to top, restart simulator. Verify "pts" shows as "分", "Note (optional)" as "备注（选填）", "More" as "更多", confirm button in Chinese.

- [ ] **Step 8.6 — Commit any fixups**

If you find and fix UI issues during testing, commit them:

```bash
git add -p
git commit -m "fix(ios): point adjust form UI fixups"
```
