# fly.io Migration Design

**Date:** 2026-05-24
**Scope:** Migrate TheBetterWe backend from local SQLite (better-sqlite3) to PostgreSQL on fly.io, with Postgres.app for local development.

---

## Goals

- Single database dialect everywhere (no SQLite dev / Postgres prod split)
- Numbered migration files for a clear schema change history
- Automated migration on deploy — schema always up to date before app starts
- Minimal changes to Express routing layer; only DB layer and controllers change

---

## Architecture

### Local Development
- **Postgres.app** runs PostgreSQL on `localhost:5432`
- Database name: `betterwe`
- Start/stop with one click; no Docker, no VM overhead
- `DATABASE_URL=postgresql://localhost:5432/betterwe` in `.env`

### Production
- **fly.io app** runs the Node.js/Express server
- **fly.io managed Postgres cluster** (`thebetterwe-db`) provides PostgreSQL
- `fly postgres attach` injects `DATABASE_URL` automatically as an app secret
- App name: `thebetterwe-api` (→ `thebetterwe-api.fly.dev`)

Both environments connect via `DATABASE_URL`. No `DB_PATH`, no SQLite anywhere.

---

## Dependencies

**Remove:**
- `better-sqlite3`
- `@types/better-sqlite3`

**Add:**
- `pg` — Postgres client (node-postgres)
- `@types/pg`
- `node-pg-migrate` — migration runner

---

## Database Layer (`src/db/index.ts`)

Replace the `better-sqlite3` singleton with a `pg.Pool`:

```typescript
import { Pool } from 'pg';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

export default pool;
```

The `CREATE TABLE IF NOT EXISTS` and `ALTER TABLE try/catch` blocks are removed entirely — schema is now managed by migrations.

---

## Schema Migrations (`server/migrations/`)

`node-pg-migrate` tracks applied migrations in a `pgmigrations` table it manages automatically. Config in `package.json` points at the `migrations/` directory and reads `DATABASE_URL`.

### Migration files

**`migrations/001_init.sql`** — Full schema in PostgreSQL syntax.

Key SQLite → PostgreSQL translations:

| SQLite | PostgreSQL |
|---|---|
| `INTEGER PRIMARY KEY AUTOINCREMENT` | `SERIAL PRIMARY KEY` |
| `DEFAULT (unixepoch())` | `DEFAULT EXTRACT(EPOCH FROM NOW())::INTEGER` |
| `TEXT UNIQUE NOT NULL COLLATE NOCASE` (username) | `CITEXT UNIQUE NOT NULL` (requires `CREATE EXTENSION IF NOT EXISTS citext`) |
| `INTEGER REFERENCES ... ON DELETE CASCADE` | Same syntax, works identically |

Tables in this migration: `users`, `refresh_tokens`, `families`, `family_members`, `member_role_keywords`, `rules`, `point_events`, `redemptions`, plus all indexes.

**`migrations/002_child_profile_columns.sql`** — Adds `gender TEXT` and `birthday_date TEXT` to `family_members`. These were previously added via try/catch in code.

### npm scripts

```json
"migrate": "node-pg-migrate up",
"migrate:create": "node-pg-migrate create"
```

Run locally: `npm run migrate` before starting the server.

---

## Async Refactor

`pool.query()` returns a Promise, so every DB-touching function becomes `async`.

**Pattern:**
```typescript
// Before (better-sqlite3)
function getUser(id: number) {
  return db.prepare('SELECT * FROM users WHERE id = ?').get(id);
}

// After (pg)
async function getUser(id: number) {
  const result = await pool.query('SELECT * FROM users WHERE id = $1', [id]);
  return result.rows[0];
}
```

Two syntax changes throughout:
- Placeholders: `?` → `$1, $2, $3...`
- Results: direct return value → `result.rows[0]` (single) or `result.rows` (array)

**Files to update:**
- `src/db/index.ts` — replace better-sqlite3 with pg.Pool
- `src/routes/auth.ts` — login, register, token refresh queries
- `src/routes/families.ts` — family and member queries
- `src/routes/pointSystem.ts` — rules, point events, redemptions
- `src/middleware/auth.ts` — token validation (if it queries the DB)

Express route handlers already support async functions — no changes to the Express layer.

---

## fly.io Setup (One-Time)

```bash
# 1. Install CLI
brew install flyctl

# 2. Create account and login
fly auth signup

# 3. From server/ directory — detect Node.js, generate fly.toml
fly launch

# 4. Create managed Postgres cluster
fly postgres create --name thebetterwe-db

# 5. Attach — sets DATABASE_URL secret automatically
fly postgres attach thebetterwe-db

# 6. Set remaining secrets
fly secrets set JWT_SECRET=<long-random-string>

# 7. Deploy
fly deploy
```

### `fly.toml` additions

```toml
[deploy]
  release_command = "npm run migrate"
```

Migrations run automatically before each new version goes live.

### Subsequent deploys

```bash
fly deploy
```

That's it. Migrations run, then the new app version starts.

---

## Environment Variables

| Variable | Local (`.env`) | fly.io |
|---|---|---|
| `DATABASE_URL` | `postgresql://localhost:5432/betterwe` | Auto-set by `fly postgres attach` |
| `JWT_SECRET` | Dev secret | `fly secrets set JWT_SECRET=...` |
| `PORT` | `3000` | Auto-set by fly.io |

`DB_PATH` is removed. Update `.env.example` accordingly.

---

## Local Dev Workflow (After Setup)

1. Open Postgres.app → click **Start**
2. `npm run migrate` (only needed after pulling new migrations)
3. `npm run dev`

---

## Out of Scope

- Custom domain (fly.dev subdomain is sufficient)
- Docker (Postgres.app is used instead)
- ORM or query builder (raw SQL with `pg` is kept)
- Apple Watch / Phase 5+ features
