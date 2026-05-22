# Family Setup Feature — Implementation Plan

## Progress Snapshot (last updated: 2026-05-20)

### Completed
- ✅ Server: `users.display_name` column added; DB wiped and recreated cleanly
- ✅ Server: `auth.ts` — signup/login/refresh return `{ accessToken, refreshToken, displayName }`; `PUT /auth/display-name` route added
- ✅ iOS: `Models/FamilyModels.swift` — `FamilyMembership` (with `familyName`), `FamilyPreview`, `FamilyInvite`
- ✅ iOS: `Services/AuthService.swift` — `displayName` Keychain key, `updateDisplayName()`, `displayName` returned from all auth responses, cleared on `logOut()`
- ✅ iOS: `Views/Family/FamilyStyle.swift` — all style constants
- ✅ iOS: `App/ContentView.swift` — `AppState` enum with `.needsDisplayName`, `.noFamily`, `.hasFamily`, `.offline`, `.loading`; hardcoded initial state
- ✅ iOS: `Views/Profile/SetDisplayNameView.swift` — account-level display name prompt on first login; "Log Out" escape hatch
- ✅ iOS: `Views/Family/Setup/NoFamilyView.swift` — shows `"{displayName},"` greeting, "Create a family" wired to CreateFamilyView, "Scan QR" TODO
- ✅ iOS: `Views/Family/Setup/CreateFamilyView.swift` — family name field (default `"{name}'s Family"` / `"{name} 的家"`), role pill section (Dad/Mom/Child/Other + custom), `canContinue` logic; Continue wired to `ModuleSelectionView`
- ✅ iOS: `Views/Family/Setup/ModuleSelectionView.swift` — "Customize Your Space" / "定制你的空间"; mandatory modules (Family TODO, Point System, Family Notes) as plain cards; optional module (OrderFromMe) with expandable feature list (3 bullets) + independent chevron/checkmark icons; `AppModule` enum with `isMandatory`, `title`, `description`, `icon`, `features`; Done button wired to `FamilyService.createFamily`, shows `ProgressView` while loading, shows alert on error
- ✅ iOS: `Resources/Localizable.xcstrings` — all strings translated to zh-Hans including all module titles, descriptions, and OrderFromMe feature bullets
- ✅ Server: `db/index.ts` — `families`, `family_members`, `member_role_keywords` tables + indexes
- ✅ Server: `routes/families.ts` — `GET /families/mine` (returns membership array with `familyName`), `POST /families` (transactional insert of family + member + keywords), `DELETE /families/:id` (member-verified delete, cascades)
- ✅ Server: `index.ts` — registered `/families`
- ✅ iOS: `Services/AuthService.swift` — added `static var accessToken: String?`
- ✅ iOS: `Services/FamilyService.swift` — `fetchMine()`, `createFamily(name:displayName:modules:)`, `deleteFamily(id:)` with full error handling
- ✅ iOS: `Models/FamilyModels.swift` — `familyName` added to `FamilyMembership`
- ✅ iOS: `Views/Main/MainTabView.swift` — accepts `membership: FamilyMembership` + `onFamilyDeleted`; passes to `FamilyView`
- ✅ iOS: `App/ContentView.swift` — removed all hardcodes; starts in `.loading`, calls `loadFamilies()` via `.task`; routes to `.noFamily` / `.hasFamily` / `.offline`; passes `memberships[0]` and `onFamilyDeleted` → `.noFamily` to `MainTabView`
- ✅ iOS: `Models/AppModule.swift` — `AppModule` enum + `ModuleFeature` extracted from `ModuleSelectionView` into shared Models file
- ✅ iOS: `Views/Family/FamilyView.swift` — full redesign: Douyin-style top bar (≡ + scrollable module tabs with capsule underline), tab content area, left drawer sliding from leading edge with iOS settings-style list (Family section: family name row + Invite row + Edit row), delete moved to future edit view; `FamilyTab` enum (`.dashboard` / `.module(AppModule)`); tabs computed from `membership.roleKeywords`; localization fixed via `LocalizedStringKey` overload + `verbatimRow` for dynamic strings; "Invite"/"Edit"/"Family" zh-Hans added with `extractionState: manual`
- ✅ iOS: `Views/Family/DashboardView.swift` — widget-based dashboard (主页): full-width cards per active module (Family TODO / Family Notes / Point System / OrderFromMe if enabled), colored headers (indigo / amber / orange / teal), long-press to drag reorder with haptic feedback, widget order persisted per-family in `UserDefaults`; Point System card shows live empty state (star + text + baby-head icon button) and children list once kids are added; all other cards show "Coming soon"
- ✅ iOS: `Models/PointSystemModels.swift` — `PSChild` struct (id, name, balance); mocked locally, server not yet wired
- ✅ iOS: `Views/Family/PointSystem/AddChildSheet.swift` — `.medium` sheet, name TextField, "Add" disabled until non-empty; creates mock `PSChild` on confirm

### In Progress
- 🔄 **Point System Phase C (remaining mocked UI)** — AwardPointsSheet, RulesView + AddRuleSheet, RedeemSheet still to build; Point System tab in `FamilyView.tabContent` still shows `Text("TODO: pointSystem")`

### Design changes from original plan
- **Account-level display name**: Added a first-login `SetDisplayNameView` step before `NoFamilyView`. This display name is stored in `users.display_name` (server) and Keychain (iOS). It is used as a default in per-family flows but can be customized per family.
- **`FamilyMembership` has `familyName`**: Server JOIN returns `familyName` in `GET /families/mine` and `POST /families`. Stored in model.
- **Role pills in CreateFamilyView**: The Dad/Mom/Child/Other role pills are on the same screen as the family name field. The selected role passes through to `ModuleSelectionView`.
- **No feature toggle**: Family setup has no `FeatureToggle` gate — build directly into production state machine.
- **`ModuleSelectionView` replaces `RoleSelectionView`**: The keyword/service chip approach is dropped. Instead, users pick 板块 (modules/boards). Mandatory: Family TODO, Point System, Family Notes. Optional (toggleable): OrderFromMe. `ServiceKeywordRegistry`, `FlowLayout`, and `FamilySetupMode` are no longer needed for this step.
- **`AppModule` moved to `Models/AppModule.swift`**: Shared between `ModuleSelectionView` and `FamilyView`.
- **Delete moved to edit view**: Delete family action removed from left drawer; will live in the future family edit view.
- **Point System — kid role deferred**: `ModuleSelectionView` Done button has a `// TODO` comment for kid-role branching (kid = read-only). Not implemented yet.
- **Dashboard is widget-based, not tab content**: Originally planned as a simple placeholder; now a full `DashboardView` with draggable module widget cards and per-family order persistence.

### Next immediate step
**Point System Phase C (remaining mocked UI)** — `AwardPointsSheet`, `RulesView` + `AddRuleSheet`, `RedeemSheet`; then wire Point System tab in `FamilyView`.

**Add Child is fully wired to backend** (Phase A + B complete for children):
- Server: `rules`, `point_events`, `redemptions` tables; `gender` + `birthday_date` on `family_members`
- Server: `GET/POST /:familyId/point-system/children` in `routes/pointSystem.ts`
- iOS: `PSChild` Codable, `PointSystemService.fetchChildren/addChild`, `AddChildView` wired with loading/error

Step 5 (Join flow) — `QRScannerView`, `JoinFamilyView`, server `GET /families/by-invite/:code` + `POST /families/:id/join` — deferred until Point System Phase C is complete.

---

## Context

After login, users land in an empty MainTabView with placeholder Family and Me views. Before any family features can work, a user must belong to a family. This plan adds the full family setup flow (create / join via QR code), a role/service keyword selection screen, and a redesigned FamilyView using a Xiaohongshu-style scrollable tab layout.

---

## Build Strategy

**UI-first with hardcoded state.** For each view:
1. Build the view and hardcode the data/state so the view is immediately visible when logging into the simulator — no server, no service calls yet.
2. Verify the view looks and behaves correctly.
3. Build the corresponding server route + FamilyService method.
4. Wire the view to the real service → remove hardcode.

This lets us see and validate every screen quickly without waiting for the full backend to be ready.

**Hardcoding pattern:** Set temporary state directly in `ContentView` (e.g., `@State private var familyStatus: FamilyStatus = .noFamily`) or pass a hardcoded `FamilyMembership` constant. Mark every hardcode with `// HARDCODE` so they're easy to find and remove.

---

## Part 1 — Server: DB Schema

**File:** `server/src/db/index.ts` — add after existing `refresh_tokens` block:

```sql
CREATE TABLE IF NOT EXISTS families (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT    NOT NULL,
  invite_code TEXT    UNIQUE NOT NULL,
  created_at  INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS family_members (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  family_id    INTEGER NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  user_id      INTEGER REFERENCES users(id) ON DELETE CASCADE,
  display_name TEXT    NOT NULL,
  joined_at    INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS member_role_keywords (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  member_id INTEGER NOT NULL REFERENCES family_members(id) ON DELETE CASCADE,
  keyword   TEXT    NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_family_members_user_id   ON family_members(user_id);
CREATE INDEX IF NOT EXISTS idx_family_members_family_id ON family_members(family_id);
CREATE INDEX IF NOT EXISTS idx_role_keywords_member_id  ON member_role_keywords(member_id);
```

- `user_id` nullable → allows future child roles with no account.
- `display_name` on `family_members` → one user can have different names in different families.
- Keywords normalised to their own table for future querying.

---

## Part 2 — Server: API Routes

**New file:** `server/src/routes/families.ts` (all routes require `requireAuth` middleware).
Register in `server/src/index.ts` as `app.use('/families', families)`.

| Method | Path | Request body | Response |
|--------|------|-------------|----------|
| GET | `/families/mine` | — | `[FamilyMembership]` or `[]` |
| POST | `/families` | `{familyName, displayName, roleKeywords[]}` | 201 `FamilyMembership` |
| GET | `/families/by-invite/:code` | — | `{familyId, familyName}` or 404 |
| POST | `/families/:id/join` | `{inviteCode, displayName, roleKeywords[]}` | 201 `FamilyMembership` |
| GET | `/families/:id/invite` | — | `{familyId, familyName, inviteCode}` |
| PUT | `/families/:id/members/me` | `{displayName?, roleKeywords?[]}` | 200 updated member |

**`GET /families/mine`** — JOIN across families + family_members + member_role_keywords for `req.auth.sub`. Empty array = no family → triggers the no-family interstitial in iOS.

**`POST /families`** — `crypto.randomUUID()` as invite_code, insert families row, insert family_members row, batch insert keywords. Return the created membership.

**`POST /families/:id/join`** — verify invite_code matches families.invite_code for that id, verify caller not already a member (409), then insert member + keywords.

**`PUT /families/:id/members/me`** — if roleKeywords provided, delete old keywords and re-insert in a SQLite transaction.

`FamilyMembership` response shape:
```json
{ "familyId": 1, "familyName": "The Yangs", "memberId": 7, "displayName": "Dad", "roleKeywords": ["parent", "chef"] }
```
(`familyName` is included via JOIN in `GET /families/mine` and `POST /families`. iOS model has `familyName`.)

---

## Part 3 — iOS: State Flow

### ContentView

New state enum:
```swift
enum FamilyStatus {
    case loading
    case noFamily
    case hasFamily([FamilyMembership])
    case offline
}
```

Routing logic:
```
isAuthenticated == false  →  LoginView
isAuthenticated == true
  └─ .loading   →  ProgressView (calls loadFamilies() in .task)
  └─ .noFamily  →  NoFamilyView(onSetupComplete:)
  └─ .hasFamily →  MainTabView(membership: memberships[0])
  └─ .offline   →  MainTabView(membership: nil)  ← FamilyView shows offline indicator
```

`NoFamilyView` receives `onSetupComplete: ([FamilyMembership]) -> Void`. On complete, ContentView sets `.hasFamily(memberships)`.

---

## Part 4 — iOS: New and Modified Files

### Shared Data Types (define first, no networking)

```swift
// familyName intentionally omitted — fetch dynamically, not cached in membership
struct FamilyMembership: Codable {
    let familyId: Int
    let memberId: Int
    let displayName: String
    let roleKeywords: [String]
}
struct FamilyPreview: Decodable { let familyId: Int; let familyName: String }
struct FamilyInvite:  Decodable { let familyId: Int; let familyName: String; let inviteCode: String }
```

Place in `Models/FamilyModels.swift` (no SwiftData — server-only data, not cached locally per CLAUDE.md).

### New Services

**`Services/FamilyService.swift`**
- Enum pattern same as `AuthService`.
- `FamilyError: LocalizedError` — `.notFound`, `.alreadyMember`, `.network`, `.unauthorized`.
- Methods: `fetchMine()`, `createFamily(name:displayName:keywords:)`, `lookupByInviteCode(_:)`, `joinFamily(id:inviteCode:displayName:keywords:)`, `fetchInvite(familyId:)`.

**`Services/ServiceKeywordRegistry.swift`**
```swift
enum AppService: String, CaseIterable {
    case orderFromMe = "OrderFromMe"
    case rewardMe    = "RewardMe"
}

enum ServiceKeywordRegistry {
    static let predefinedKeywords: [AppService: [String]] = [
        .orderFromMe: ["chef", "cook", "shopper"],
        .rewardMe:    ["parent", "reward admin", "point admin"],
    ]
    static var allPredefinedKeywords: [String] { predefinedKeywords.values.flatMap { $0 }.sorted() }
    static func activeServices(for keywords: [String]) -> [AppService]
}
```

### New Views (build one at a time in this order)

**`Views/Family/FamilyStyle.swift`** — style constants (screenHPadding, topBarHeight, chipCornerRadius, etc.)

**`Views/Family/Setup/NoFamilyView.swift`**
- NavigationStack, two big buttons: "Create a family" and "Scan QR code to join".
- `.navigationDestination` → `CreateFamilyView` or `JoinFamilyView`.
- Both receive `onComplete: ([FamilyMembership]) -> Void`.

**`Views/Family/Setup/CreateFamilyView.swift`**
- Single TextField for family name.
- On "Continue": pushes to `RoleSelectionView(mode: .create(familyName:), onComplete:)`.
- Does NOT call server yet — server call happens at end of RoleSelectionView.

**`Views/Family/Setup/QRScannerView.swift`** — `UIViewRepresentable`
- `AVCaptureSession` + `AVCaptureMetadataOutput` for `.qr`.
- On scan: stops session, calls `onCodeScanned(String)` on main thread.
- If camera permission denied: show `ContentUnavailableView` + "Open Settings" button.

**`Views/Family/Setup/JoinFamilyView.swift`**
- Two-mode segmented Picker: "Scan QR" | "Enter code".
- Scan mode: `QRScannerView` + code extraction from `thebetterwe://join?code=<invite_code>`.
- Manual mode: TextField for code string.
- On valid code: calls `FamilyService.lookupByInviteCode()` → preview card "You're joining **The Smiths**" + "Confirm".
- Confirm → pushes to `RoleSelectionView(mode: .join(familyId:inviteCode:), onComplete:)`.

**`Views/Shared/FlowLayout.swift`** — wrapping HStack using `Layout` protocol (~30 lines). Used by RoleSelectionView for keyword chips.

**`Views/Family/Setup/RoleSelectionView.swift`**
```swift
enum FamilySetupMode {
    case create(familyName: String)
    case join(familyId: Int, inviteCode: String)
}
```
- Display name TextField.
- Predefined keyword chips from `ServiceKeywordRegistry.allPredefinedKeywords` in `FlowLayout` — toggle-selectable.
- "Add a custom role…" TextField → appends to selected keywords on return/submit.
- Selected custom keywords as chips with × to remove.
- "Done" button: calls `FamilyService.createFamily` or `joinFamily` depending on mode → `onComplete([membership])`.

### Redesigned Views

**`Views/Family/FamilyView.swift`** — full rewrite

Layout:
```
VStack(spacing: 0)
  FamilyTopBar   ← ≡ (hamburger) | scrollable tab chips | ⊕ (invite)
  Divider
  TabContentArea ← switch on selectedFamilyTab

ZStack overlay: FamilyLeftDrawer (slides from left, .move(edge: .leading))
.sheet: FamilyInviteSheet
```

Tab enum:
```swift
enum FamilyTab: Hashable {
    case dashboard
    case service(AppService)
}
```
Tabs computed from `ServiceKeywordRegistry.activeServices(for: membership.roleKeywords)`.

**FamilyLeftDrawer:** width = `UIScreen.main.bounds.width * 0.75`, slides from left. Shows family name, display name, role keyword chips (read-only), "Edit Dashboard" button (placeholder sheet). Minimal — will be redesigned later.

**FamilyInviteSheet:** Fetches invite code from server on appear → generates QR image via `CIQRCodeGenerator` from `thebetterwe://join?code=<code>` → displays QR image + `ShareLink` for the URL string.

QR generation:
```swift
func makeQRImage(from string: String, size: CGFloat = 200) -> UIImage?
// CIFilter("CIQRCodeGenerator") → scale transform → UIImage(ciImage:)
```

**`Views/Me/MeView.swift`** — minimal update
- Receives `membership: FamilyMembership?`.
- Adds profile header: display name (title), family name (subtitle), role keyword chips (read-only).
- Existing right drawer + Log Out unchanged.

### Modified App Files

- **`App/ContentView.swift`** — new FamilyStatus state machine (see Part 3).
- **`Views/Main/MainTabView.swift`** — add `membership: FamilyMembership?`, pass to FamilyView and MeView.

---

## Part 5 — Build Order (UI-first)

Each step follows the pattern: **hardcode → see in simulator → wire to server → remove hardcode**.

### Step 1 — Define data types + server DB ✅
- `Models/FamilyModels.swift` with the three structs. ✅
- DB tables to be added to `server/src/db/index.ts`. ← still pending

### Step 2 — NoFamilyView (hardcoded) ✅
- `NoFamilyView.swift` built. ✅
- `ContentView` hardcoded to `.noFamily` initial state. ✅

### Step 3 — Create flow UI (hardcoded) ✅
- `FamilyStyle.swift`, `CreateFamilyView.swift`, `ModuleSelectionView.swift` built. ✅
- `FlowLayout.swift` and `RoleSelectionView.swift` dropped (module picker approach instead). ✅
- Done button in `ModuleSelectionView` is still hardcoded (no server call yet).

### Step 4 — Wire create flow to server ✅
- Add DB tables to `server/src/db/index.ts` (families, family_members).
- Build `FamilyService.createFamily(name:role:modules:)`.
- Build server `POST /families` + `GET /families/mine` routes.
- Register `/families` in `server/src/index.ts`.
- Wire `ModuleSelectionView` Done button to `FamilyService.createFamily` → `onComplete`.
- Wire `ContentView.loadFamilies()` to `FamilyService.fetchMine()` → remove hardcode.
- curl test both routes.

### Step 5 — Join flow UI (hardcoded)
- Build `QRScannerView.swift`, `JoinFamilyView.swift`.
- Add `NSCameraUsageDescription` to Info.plist + `thebetterwe` URL scheme to `CFBundleURLTypes`.
- Hardcode: simulate a scanned code string, hardcode family preview response.
- See the full join UI flow in simulator.

### Step 6 — Wire join flow to server
- Build `FamilyService.lookupByInviteCode()` + `joinFamily()`.
- Build server `GET /families/by-invite/:code` + `POST /families/:id/join`.
- Wire `JoinFamilyView` to real service → remove hardcode.

### Step 7 — FamilyView redesign (hardcoded)
- Full rewrite of `FamilyView.swift` (top bar + tabs + left drawer + invite sheet).
- In `ContentView`: hardcode `familyStatus = .hasFamily([mockMembership])` with keywords `["parent", "chef"]` // HARDCODE
- See the redesigned FamilyView with all tabs (Dashboard, OrderFromMe, RewardMe) immediately.

### Step 8 — Wire FamilyView invite sheet to server
- Build `FamilyService.fetchInvite()`.
- Build server `GET /families/:id/invite`.
- Wire `FamilyInviteSheet` to real service → remove hardcode.
- `PUT /families/:id/members/me` also built here (for future role editing).

### Step 9 — MeView update
- Update `MeView.swift` with profile header + role chips.
- Flows naturally from real membership (no separate hardcode step needed if Step 4 is done).

### Step 10 — Localization
- Add all new strings to `Localizable.xcstrings` with zh-Hans.
- Run in zh-Hans locale and verify.

---

## Part 6 — Localization (zh-Hans required)

| Key | zh-Hans |
|-----|---------|
| "You don't belong to a family yet" | "你还没有加入家庭" |
| "Create a family" | "创建家庭" |
| "Scan QR code to join" | "扫码加入" |
| "Enter code manually" | "手动输入邀请码" |
| "Name your family" | "给家庭起个名字" |
| "Family name" | "家庭名称" |
| "How do you want to be known?" | "你想怎么称呼自己？" |
| "Display name" | "显示名称" |
| "Your roles" | "你的角色" |
| "Select all that apply" | "选择所有适用的" |
| "Add a custom role..." | "添加自定义角色…" |
| "Dashboard" | "主页" |
| "Edit Dashboard" | "编辑主页" |
| "Invite to family" | "邀请加入家庭" |
| "Share invite link" | "分享邀请链接" |
| "Confirm" | "确认" |
| "Family not found" | "未找到家庭" |
| "Already a member of this family" | "已是该家庭成员" |
| "Camera access is required to scan QR codes" | "需要相机权限以扫描二维码" |
| "Open Settings" | "打开设置" |
| "Connect to see your family" | "连接网络查看家庭" |
| "Family setup error. Please try again." | "家庭设置失败，请重试。" |

---

## Part 7 — Deferred (explicitly out of scope)

- Dashboard widget edit mode — "Edit Dashboard" shows placeholder only
- Left drawer full redesign — minimal version now, rework later
- Me view full design — only minimal profile header + role chips now
- Multi-family switching — use `memberships[0]`; picker is future work
- Child roles — schema supports it; no UI built
- Invite code rotation — permanent for now
- Real-time membership updates — no WebSocket; fetch on demand

---

## Verification

1. **Server:** `curl` each route with a valid JWT. Verify `GET /mine` returns `[]` for new user, `POST /families` returns 201, `POST /:id/join` returns 409 on re-join.
2. **No-family flow:** Log in with a fresh user → see NoFamilyView → create family → role screen → complete → see redesigned FamilyView.
3. **Join flow:** Second simulator — scan QR or paste code → preview → join → see FamilyView with correct tabs per selected keywords.
4. **Role tabs:** Select "chef" → OrderFromMe tab appears. Select "parent" → RewardMe tab appears.
5. **Offline:** Kill server → launch app → see offline indicator in FamilyView, Me still accessible.
6. **Localization:** Run in zh-Hans locale, verify all new strings show Chinese.
