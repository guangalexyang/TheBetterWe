# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**TheBetterWe** is a family daily-routine iOS app. It is the hub that integrates smaller family tools (OrderFromMe, RewardMe, and future tools) into one place, alongside its own core features.

The app serves parents managing family life. Children may have their own accounts (with a `"child"` role keyword in the family), or parents can create profile-only child roles (`user_id = NULL`) for young kids who don't log in.

## Core Features

- **Family & Personal TODOs / Done** — task tracking at both family and individual level
- **Highlight of the Day** — event with text + optional photo; creator can choose to notify other family members
- **OrderFromMe integration** — recipes, meal invitations, shopping lists (shopping lists sync with TODOs)
- **RewardMe integration** — points and rewards for children

## Integration Philosophy

OrderFromMe and RewardMe may exist as separate web apps with their own hosting/URLs, or as iOS apps. TheBetterWe integrates them — do not assume they share a codebase or can be directly imported. Integration is API-based or via deep links depending on how each tool is deployed at the time of integration.

## Tech Stack

### iOS Client
- SwiftUI, SwiftData (local persistence for personal TODOs/Done only)
- When offline, app only shows what is in local database (personal TODOs/Done). No cached family data — family features show an offline indicator.
- Light theme first; dark/custom theme designed later with reference screenshots
- Chinese + English localization (`.xcstrings` from the start)
- Build UI **view by view, step by step** — never scaffold multiple views at once without user approval

### Server
- Node.js + Express.js + **TypeScript**
- For dev: runs locally on this machine
- SQLite (better-sqlite3) for dev; schema managed inline in `src/db/index.ts` via `CREATE TABLE IF NOT EXISTS` + idempotent `ALTER TABLE` — no migrations directory
- RESTful API — iOS client communicates via HTTP
- Migration target: fly.io (or similar) with PostgreSQL in a later phase

### Apple Watch
- Later phase — syncs with iOS under same account

## Data Architecture

**Local (SwiftData on device):**
- Personal TODOs and Done items only
- No family data cached locally

**Server (SQLite for dev, PostgreSQL planned for production):**
- User accounts and authentication
- Family groups and membership — a user can belong to multiple families; `family_members` is a junction table
- Child roles have no user account (`user_id` is null); managed by parents
- Family TODOs, Done, Highlights
- Integration records linking to OrderFromMe, RewardMe

**Personal TODO sync (local ↔ server):**
- Both local (SwiftData) and server store personal TODOs
- Each record carries `updated_at` on both sides
- Sync strategy: last-write-wins with field-level merging — each field carries its own `updated_at`; conflicting fields are resolved independently rather than one side overwriting the whole record
- Sync runs on app launch and when coming back online
- Full conflict resolution UI not needed — personal TODOs are owned by one user, simultaneous edits across devices are rare and low-stakes
- Required for Apple Watch support in a later phase

## Feature Toggle System

Every new feature must be behind a toggle. Toggles are served by the backend via `GET /config/feature-flags` and fetched by the iOS app on every launch.

- Server holds a `feature_flags.json` (or in-memory config) — edit server-side to enable/disable without a new app release
- iOS caches the last successful response locally; uses the cache if the server is unreachable
- If never fetched before and offline, all toggles default to **off**
- This allows shipping client code with a toggle off, then enabling it from the server when ready

**Git workflow — dev-to-master merges only happen for one of these three reasons:**
1. Add the toggle (off by default on server)
2. All feature code complete, still behind toggle, merge to master
3. Remove the toggle (feature fully shipped)

## AI Integration (Phased)

- Every database operation (local or server) should have a corresponding API endpoint suitable for AI invocation
- Document AI-callable APIs: natural language trigger + endpoint + parameters
- Phase 1: Siri via App Intents
- Phase 2: Doubao

## Notifications

- When creating a Highlight or completing a family event, creator can optionally notify other family members
- Push notifications sent only when the creator opts in

## Project Structure

```
TheBetterWe/
├── CLAUDE.md
│
├── ios/                        # iOS client
│   ├── TheBetterWe.xcodeproj
│   └── TheBetterWe/
│       ├── App/                # Entry point, config, feature flag loader
│       ├── Models/             # SwiftData models (local DB)
│       ├── Views/              # SwiftUI views, grouped by feature
│       ├── ViewModels/         # @Observable view models
│       ├── Services/           # API client, sync engine
│       ├── Intents/            # App Intents (Siri)
│       └── Resources/          # Assets, .xcstrings (en/zh)
│
└── server/                     # Node.js + Express + TypeScript
    ├── src/
    │   ├── routes/             # Express route definitions
    │   ├── controllers/        # Request handlers / business logic
    │   ├── models/             # DB query functions (per table)
    │   ├── middleware/         # Auth, error handling, logging
    │   └── services/           # External integrations (OrderFromMe, RewardMe etc.)
    ├── data/                   # SQLite database file (betterwe.db, git-ignored)
    ├── feature_flags.json      # Server-side toggle config, edit to enable/disable features
    ├── package.json
    └── .env.example
```

## UI

Build UI **view by view** — never scaffold multiple views at once without user approval. Follow the patterns in [`docs/ui-design-practices.md`](docs/ui-design-practices.md) for style constants, navigation transitions, form fields, password fields, and validation.

## Development Phases

1. **Phase 1 (current)** — iOS app + local Node/Express server + SQLite; user auth, family setup, Point System (kids + rules + points + redemptions), personal + family TODOs/Done, Highlight of the Day
2. **Phase 2** — OrderFromMe integration (recipes, shopping list ↔ TODOs)
3. **Phase 3** — RewardMe standalone integration (if needed beyond Phase 1 Point System)
4. **Phase 4** — Siri / App Intents; Doubao API
5. **Phase 5** — Apple Watch companion
6. **Phase 6** — Migrate backend to fly.io (or chosen host)
