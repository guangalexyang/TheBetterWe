# fly.io Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the TheBetterWe Express/TypeScript backend from SQLite (better-sqlite3) to PostgreSQL on fly.io, with Postgres.app for local development.

**Architecture:** Replace `better-sqlite3` with `pg` (node-postgres) pool. All DB calls become async/await with `$1`-style placeholders. Schema is managed by numbered `node-pg-migrate` migration files in `server/migrations/`. fly.io managed Postgres provides `DATABASE_URL` in production; Postgres.app provides it locally.

**Tech Stack:** Node.js + Express + TypeScript, `pg`, `node-pg-migrate`, Postgres.app (local), fly.io + managed Postgres (production), `flyctl` CLI.

---

## File Map

| Action | Path | Purpose |
|---|---|---|
| Create | `server/migrations/001_init.js` | Full initial schema in PostgreSQL |
| Create | `server/migrations/002_child_profile_columns.js` | gender + birthday_date on family_members |
| Create | `server/Dockerfile` | Container image for fly.io |
| Modify | `server/package.json` | Swap deps, add migrate scripts and config |
| Modify | `server/.env.example` | Replace DB_PATH with DATABASE_URL |
| Modify | `server/src/db/index.ts` | Replace better-sqlite3 singleton with pg.Pool |
| Modify | `server/src/routes/auth.ts` | Async refactor, pg syntax, RETURNING id |
| Modify | `server/src/routes/families.ts` | Async refactor, pg transaction pattern |
| Modify | `server/src/routes/pointSystem.ts` | Async refactor, pg transaction pattern |

No changes needed: `src/middleware/auth.ts` (pure JWT, no DB), `src/routes/featureToggles.ts` (no DB).

---

## Task 1: Install Postgres.app and create local database

**Files:** none (manual setup)

- [ ] **Step 1: Download and install Postgres.app**

  Go to https://postgresapp.com and download the latest version. Drag to Applications and open it. Click **Initialize** to create a local Postgres server. Then click **Start**.

- [ ] **Step 2: Add psql to your PATH**

  Run in terminal:
  ```bash
  sudo mkdir -p /etc/paths.d && echo /Applications/Postgres.app/Contents/Versions/latest/bin | sudo tee /etc/paths.d/postgresapp
  ```
  Open a new terminal tab for the PATH to take effect.

- [ ] **Step 3: Create the betterwe database**

  ```bash
  createdb betterwe
  ```
  Expected: no output (success).

- [ ] **Step 4: Verify connection**

  ```bash
  psql betterwe -c "SELECT version();"
  ```
  Expected: a line showing `PostgreSQL 16.x` or `17.x`.

- [ ] **Step 5: Update .env with DATABASE_URL**

  Open `server/.env` and replace the `DB_PATH` line with:
  ```
  DATABASE_URL=postgresql://localhost:5432/betterwe
  ```
  Keep `PORT` and `JWT_SECRET` lines as-is.

---

## Task 2: Update server dependencies and config

**Files:**
- Modify: `server/package.json`
- Modify: `server/.env.example`

- [ ] **Step 1: Remove SQLite packages**

  ```bash
  cd server && npm uninstall better-sqlite3 @types/better-sqlite3
  ```
  Expected: success message, package-lock.json updated.

- [ ] **Step 2: Add Postgres packages**

  ```bash
  npm install pg && npm install --save-dev @types/pg && npm install node-pg-migrate
  ```
  Expected: all three install without errors.

- [ ] **Step 3: Add migrate scripts and node-pg-migrate config to package.json**

  In `server/package.json`, update the `scripts` section and add a top-level `node-pg-migrate` key so the file looks like this (keep all existing content, only add/change what's shown):

  ```json
  {
    "scripts": {
      "dev": "nodemon",
      "build": "tsc",
      "start": "node dist/index.js",
      "migrate": "node -r dotenv/config node_modules/.bin/node-pg-migrate up",
      "migrate:create": "node -r dotenv/config node_modules/.bin/node-pg-migrate create"
    },
    "node-pg-migrate": {
      "dir": "migrations",
      "databaseUrlEnv": "DATABASE_URL"
    }
  }
  ```

- [ ] **Step 4: Update .env.example**

  Replace the entire content of `server/.env.example` with:
  ```
  PORT=3000
  JWT_SECRET=replace-with-a-long-random-secret
  DATABASE_URL=postgresql://localhost:5432/betterwe
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add server/package.json server/package-lock.json server/.env.example
  git commit -m "chore: swap better-sqlite3 for pg, add node-pg-migrate"
  ```

---

## Task 3: Create migration 001 — full initial schema

**Files:**
- Create: `server/migrations/001_init.js`

- [ ] **Step 1: Create migrations directory and migration file**

  ```bash
  mkdir -p server/migrations
  ```

  Create `server/migrations/001_init.js` with this content:

  ```js
  'use strict';

  /** @param {import('node-pg-migrate').MigrationBuilder} pgm */
  exports.up = (pgm) => {
    pgm.sql(`
      CREATE EXTENSION IF NOT EXISTS citext;

      CREATE TABLE IF NOT EXISTS users (
        id            SERIAL PRIMARY KEY,
        username      CITEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        display_name  TEXT NOT NULL DEFAULT '',
        created_at    INTEGER NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::INTEGER
      );

      CREATE TABLE IF NOT EXISTS refresh_tokens (
        id          SERIAL PRIMARY KEY,
        user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        family_id   TEXT NOT NULL,
        token_hash  TEXT UNIQUE NOT NULL,
        used        INTEGER NOT NULL DEFAULT 0,
        expires_at  INTEGER NOT NULL,
        created_at  INTEGER NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::INTEGER
      );

      CREATE TABLE IF NOT EXISTS families (
        id          SERIAL PRIMARY KEY,
        name        TEXT NOT NULL,
        invite_code TEXT UNIQUE NOT NULL,
        created_at  INTEGER NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::INTEGER
      );

      CREATE TABLE IF NOT EXISTS family_members (
        id           SERIAL PRIMARY KEY,
        family_id    INTEGER NOT NULL REFERENCES families(id) ON DELETE CASCADE,
        user_id      INTEGER REFERENCES users(id) ON DELETE SET NULL,
        display_name TEXT NOT NULL,
        joined_at    INTEGER NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::INTEGER
      );

      CREATE TABLE IF NOT EXISTS member_role_keywords (
        id        SERIAL PRIMARY KEY,
        member_id INTEGER NOT NULL REFERENCES family_members(id) ON DELETE CASCADE,
        keyword   TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_family_members_user_id   ON family_members(user_id);
      CREATE INDEX IF NOT EXISTS idx_family_members_family_id ON family_members(family_id);
      CREATE INDEX IF NOT EXISTS idx_role_keywords_member_id  ON member_role_keywords(member_id);
      CREATE INDEX IF NOT EXISTS idx_families_invite_code     ON families(invite_code);

      CREATE TABLE IF NOT EXISTS rules (
        id                  SERIAL PRIMARY KEY,
        family_id           INTEGER NOT NULL REFERENCES families(id) ON DELETE CASCADE,
        name                TEXT NOT NULL,
        description         TEXT,
        point_cost_per_unit INTEGER,
        unit_label          TEXT,
        threshold_amount    INTEGER,
        threshold_period    TEXT,
        is_archived         INTEGER NOT NULL DEFAULT 0,
        created_at          INTEGER NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::INTEGER
      );

      CREATE TABLE IF NOT EXISTS point_events (
        id         SERIAL PRIMARY KEY,
        member_id  INTEGER NOT NULL REFERENCES family_members(id) ON DELETE CASCADE,
        rule_id    INTEGER REFERENCES rules(id) ON DELETE SET NULL,
        delta      INTEGER NOT NULL,
        note       TEXT,
        created_at INTEGER NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::INTEGER
      );

      CREATE TABLE IF NOT EXISTS redemptions (
        id              SERIAL PRIMARY KEY,
        member_id       INTEGER NOT NULL REFERENCES family_members(id) ON DELETE CASCADE,
        rule_id         INTEGER REFERENCES rules(id) ON DELETE SET NULL,
        units           INTEGER NOT NULL DEFAULT 1,
        points_deducted INTEGER NOT NULL DEFAULT 0,
        note            TEXT,
        created_at      INTEGER NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::INTEGER
      );

      CREATE INDEX IF NOT EXISTS idx_point_events_member ON point_events(member_id);
      CREATE INDEX IF NOT EXISTS idx_redemptions_member   ON redemptions(member_id);
      CREATE INDEX IF NOT EXISTS idx_rules_family         ON rules(family_id);
    `);
  };

  /** @param {import('node-pg-migrate').MigrationBuilder} pgm */
  exports.down = (pgm) => {
    pgm.sql(`
      DROP TABLE IF EXISTS redemptions;
      DROP TABLE IF EXISTS point_events;
      DROP TABLE IF EXISTS rules;
      DROP TABLE IF EXISTS member_role_keywords;
      DROP TABLE IF EXISTS family_members;
      DROP TABLE IF EXISTS families;
      DROP TABLE IF EXISTS refresh_tokens;
      DROP TABLE IF EXISTS users;
      DROP EXTENSION IF EXISTS citext;
    `);
  };
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add server/migrations/001_init.js
  git commit -m "chore: add migration 001 — full initial schema (PostgreSQL)"
  ```

---

## Task 4: Create migration 002 — child profile columns

**Files:**
- Create: `server/migrations/002_child_profile_columns.js`

- [ ] **Step 1: Create migration file**

  Create `server/migrations/002_child_profile_columns.js` with this content:

  ```js
  'use strict';

  /** @param {import('node-pg-migrate').MigrationBuilder} pgm */
  exports.up = (pgm) => {
    pgm.sql(`
      ALTER TABLE family_members ADD COLUMN IF NOT EXISTS gender TEXT;
      ALTER TABLE family_members ADD COLUMN IF NOT EXISTS birthday_date TEXT;
    `);
  };

  /** @param {import('node-pg-migrate').MigrationBuilder} pgm */
  exports.down = (pgm) => {
    pgm.sql(`
      ALTER TABLE family_members DROP COLUMN IF EXISTS gender;
      ALTER TABLE family_members DROP COLUMN IF EXISTS birthday_date;
    `);
  };
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add server/migrations/002_child_profile_columns.js
  git commit -m "chore: add migration 002 — gender and birthday_date on family_members"
  ```

---

## Task 5: Run migrations locally and verify

**Files:** none (verification only)

- [ ] **Step 1: Ensure Postgres.app is running**

  Open Postgres.app and confirm the elephant icon shows a green dot.

- [ ] **Step 2: Run migrations**

  ```bash
  cd server && npm run migrate
  ```
  Expected output:
  ```
  Migrating files:
  - 001_init
  - 002_child_profile_columns
  Running migration 001_init
  Running migration 002_child_profile_columns
  Migrations complete!
  ```

- [ ] **Step 3: Verify tables were created**

  ```bash
  psql betterwe -c "\dt"
  ```
  Expected: a table list including `users`, `families`, `family_members`, `member_role_keywords`, `refresh_tokens`, `rules`, `point_events`, `redemptions`, `pgmigrations`.

- [ ] **Step 4: Verify child profile columns exist**

  ```bash
  psql betterwe -c "\d family_members"
  ```
  Expected: columns include `gender text` and `birthday_date text`.

---

## Task 6: Replace src/db/index.ts with pg Pool

**Files:**
- Modify: `server/src/db/index.ts`

- [ ] **Step 1: Replace the entire file content**

  Replace `server/src/db/index.ts` with:

  ```typescript
  import { Pool } from 'pg';

  const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
  });

  export default pool;
  ```

- [ ] **Step 2: Verify TypeScript compiles**

  ```bash
  cd server && npx tsc --noEmit
  ```
  Expected: errors about `db.prepare` in route files (that's correct — those get fixed in the next tasks). No errors in `db/index.ts` itself.

- [ ] **Step 3: Commit**

  ```bash
  git add server/src/db/index.ts
  git commit -m "refactor: replace better-sqlite3 with pg.Pool in db/index.ts"
  ```

---

## Task 7: Refactor src/routes/auth.ts

**Files:**
- Modify: `server/src/routes/auth.ts`

Key changes:
- `db.prepare(...).get()` → `(await pool.query(..., [params])).rows[0]`
- `db.prepare(...).run()` → `await pool.query(..., [params])`
- `?` placeholders → `$1, $2, $3...`
- `lastInsertRowid` → `RETURNING id` + `result.rows[0].id`
- `insertRefreshToken` becomes `async`
- All route handlers that touch the DB become `async`

- [ ] **Step 1: Replace the entire file content**

  Replace `server/src/routes/auth.ts` with:

  ```typescript
  import { Router, Request, Response } from 'express';
  import bcrypt from 'bcrypt';
  import jwt from 'jsonwebtoken';
  import crypto from 'crypto';
  import pool from '../db';
  import { requireAuth } from '../middleware/auth';

  const router = Router();

  const BCRYPT_ROUNDS = 12;
  const ACCESS_TOKEN_TTL = '15m';
  const REFRESH_TOKEN_TTL_DAYS = 30;

  function jwtSecret(): string {
    const secret = process.env.JWT_SECRET;
    if (!secret) throw new Error('JWT_SECRET is not set');
    return secret;
  }

  function makeAccessToken(userId: number, username: string): string {
    return jwt.sign({ sub: userId, username }, jwtSecret(), { expiresIn: ACCESS_TOKEN_TTL });
  }

  function makeRefreshToken(): { raw: string; hash: string; expiresAt: number } {
    const raw = crypto.randomBytes(40).toString('hex');
    const hash = crypto.createHash('sha256').update(raw).digest('hex');
    const expiresAt = Math.floor(Date.now() / 1000) + REFRESH_TOKEN_TTL_DAYS * 86400;
    return { raw, hash, expiresAt };
  }

  async function insertRefreshToken(userId: number, familyId: string, hash: string, expiresAt: number): Promise<void> {
    await pool.query(
      'INSERT INTO refresh_tokens (user_id, family_id, token_hash, expires_at) VALUES ($1, $2, $3, $4)',
      [userId, familyId, hash, expiresAt]
    );
  }

  // POST /auth/signup
  router.post('/signup', async (req: Request, res: Response) => {
    const { username, password } = req.body as { username?: string; password?: string };

    if (!username || !password) {
      res.status(400).json({ error: 'username and password are required' });
      return;
    }

    const existing = (await pool.query('SELECT id FROM users WHERE username = $1', [username])).rows[0];
    if (existing) {
      res.status(409).json({ error: 'username already taken' });
      return;
    }

    const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
    const result = await pool.query(
      'INSERT INTO users (username, password_hash) VALUES ($1, $2) RETURNING id',
      [username, passwordHash]
    );
    const userId = result.rows[0].id as number;

    const accessToken = makeAccessToken(userId, username);
    const refresh = makeRefreshToken();
    const familyId = crypto.randomUUID();

    await insertRefreshToken(userId, familyId, refresh.hash, refresh.expiresAt);

    res.status(201).json({ accessToken, refreshToken: refresh.raw, displayName: '' });
  });

  // POST /auth/login
  router.post('/login', async (req: Request, res: Response) => {
    const { username, password } = req.body as { username?: string; password?: string };

    if (!username || !password) {
      res.status(400).json({ error: 'username and password are required' });
      return;
    }

    const user = (await pool.query(
      'SELECT id, username, password_hash, display_name FROM users WHERE username = $1',
      [username]
    )).rows[0] as { id: number; username: string; password_hash: string; display_name: string } | undefined;

    const match = user && (await bcrypt.compare(password, user.password_hash));
    if (!match) {
      res.status(401).json({ error: 'invalid credentials' });
      return;
    }

    const accessToken = makeAccessToken(user.id, user.username);
    const refresh = makeRefreshToken();
    const familyId = crypto.randomUUID();

    await insertRefreshToken(user.id, familyId, refresh.hash, refresh.expiresAt);

    res.json({ accessToken, refreshToken: refresh.raw, displayName: user.display_name });
  });

  // PUT /auth/display-name
  router.put('/display-name', requireAuth, async (req: Request, res: Response) => {
    const { displayName } = req.body as { displayName?: string };

    if (!displayName || !displayName.trim()) {
      res.status(400).json({ error: 'displayName is required' });
      return;
    }

    await pool.query('UPDATE users SET display_name = $1 WHERE id = $2', [displayName.trim(), req.auth!.sub]);
    res.json({ displayName: displayName.trim() });
  });

  // POST /auth/refresh
  router.post('/refresh', async (req: Request, res: Response) => {
    const { refreshToken } = req.body as { refreshToken?: string };

    if (!refreshToken) {
      res.status(400).json({ error: 'refreshToken is required' });
      return;
    }

    const hash = crypto.createHash('sha256').update(refreshToken).digest('hex');
    const now = Math.floor(Date.now() / 1000);

    const row = (await pool.query(
      `SELECT rt.id, rt.user_id, rt.family_id, rt.used, rt.expires_at, u.username, u.display_name
       FROM refresh_tokens rt
       JOIN users u ON u.id = rt.user_id
       WHERE rt.token_hash = $1`,
      [hash]
    )).rows[0] as {
      id: number; user_id: number; family_id: string;
      used: number; expires_at: number; username: string; display_name: string;
    } | undefined;

    if (!row) {
      res.status(401).json({ error: 'invalid refresh token' });
      return;
    }

    if (row.used) {
      await pool.query('DELETE FROM refresh_tokens WHERE family_id = $1', [row.family_id]);
      res.status(401).json({ error: 'refresh token reuse detected' });
      return;
    }

    if (row.expires_at <= now) {
      await pool.query('DELETE FROM refresh_tokens WHERE id = $1', [row.id]);
      res.status(401).json({ error: 'refresh token expired' });
      return;
    }

    await pool.query('UPDATE refresh_tokens SET used = 1 WHERE id = $1', [row.id]);

    const accessToken = makeAccessToken(row.user_id, row.username);
    const newRefresh = makeRefreshToken();

    await insertRefreshToken(row.user_id, row.family_id, newRefresh.hash, newRefresh.expiresAt);

    res.json({ accessToken, refreshToken: newRefresh.raw, displayName: row.display_name });
  });

  // POST /auth/logout
  router.post('/logout', async (req: Request, res: Response) => {
    const { refreshToken } = req.body as { refreshToken?: string };

    if (refreshToken) {
      const hash = crypto.createHash('sha256').update(refreshToken).digest('hex');
      const row = (await pool.query(
        'SELECT family_id FROM refresh_tokens WHERE token_hash = $1',
        [hash]
      )).rows[0] as { family_id: string } | undefined;

      if (row) {
        await pool.query('DELETE FROM refresh_tokens WHERE family_id = $1', [row.family_id]);
      }
    }

    res.status(204).send();
  });

  export default router;
  ```

- [ ] **Step 2: Verify TypeScript compiles (auth only)**

  ```bash
  cd server && npx tsc --noEmit 2>&1 | grep auth
  ```
  Expected: no errors mentioning `auth.ts`.

- [ ] **Step 3: Commit**

  ```bash
  git add server/src/routes/auth.ts
  git commit -m "refactor: migrate auth routes to async pg"
  ```

---

## Task 8: Refactor src/routes/families.ts

**Files:**
- Modify: `server/src/routes/families.ts`

Key changes: `db.transaction()` → pg `BEGIN`/`COMMIT`/`ROLLBACK` with `pool.connect()`.

- [ ] **Step 1: Replace the entire file content**

  Replace `server/src/routes/families.ts` with:

  ```typescript
  import { Router, Request, Response } from 'express';
  import crypto from 'crypto';
  import pool from '../db';
  import { requireAuth } from '../middleware/auth';

  const router = Router();
  router.use(requireAuth);

  // GET /families/mine
  router.get('/mine', async (req: Request, res: Response) => {
    const userId = req.auth!.sub;

    const members = (await pool.query(
      `SELECT fm.id AS "memberId", fm.family_id AS "familyId", fm.display_name AS "displayName", f.name AS "familyName"
       FROM family_members fm
       JOIN families f ON f.id = fm.family_id
       WHERE fm.user_id = $1`,
      [userId]
    )).rows as { memberId: number; familyId: number; displayName: string; familyName: string }[];

    if (members.length === 0) {
      res.json([]);
      return;
    }

    const result = await Promise.all(members.map(async (m) => {
      const keywords = (await pool.query(
        'SELECT keyword FROM member_role_keywords WHERE member_id = $1',
        [m.memberId]
      )).rows.map((r: { keyword: string }) => r.keyword);

      return { familyId: m.familyId, familyName: m.familyName, memberId: m.memberId, displayName: m.displayName, roleKeywords: keywords };
    }));

    res.json(result);
  });

  // POST /families
  router.post('/', async (req: Request, res: Response) => {
    const { familyName, displayName, roleKeywords } = req.body as {
      familyName?: string;
      displayName?: string;
      roleKeywords?: string[];
    };

    if (!familyName?.trim() || !displayName?.trim()) {
      res.status(400).json({ error: 'familyName and displayName are required' });
      return;
    }

    const userId = req.auth!.sub;
    const inviteCode = crypto.randomUUID();
    const keywords: string[] = Array.isArray(roleKeywords) ? roleKeywords : [];

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const familyResult = await client.query(
        'INSERT INTO families (name, invite_code) VALUES ($1, $2) RETURNING id',
        [familyName.trim(), inviteCode]
      );
      const familyId = familyResult.rows[0].id as number;

      const memberResult = await client.query(
        'INSERT INTO family_members (family_id, user_id, display_name) VALUES ($1, $2, $3) RETURNING id',
        [familyId, userId, displayName.trim()]
      );
      const memberId = memberResult.rows[0].id as number;

      for (const kw of keywords) {
        await client.query(
          'INSERT INTO member_role_keywords (member_id, keyword) VALUES ($1, $2)',
          [memberId, kw]
        );
      }

      await client.query('COMMIT');

      res.status(201).json({
        familyId,
        familyName: familyName.trim(),
        memberId,
        displayName: displayName.trim(),
        roleKeywords: keywords,
      });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  });

  // DELETE /families/:id
  router.delete('/:id', async (req: Request, res: Response) => {
    const familyId = parseInt(req.params.id, 10);
    const userId = req.auth!.sub;

    const member = (await pool.query(
      'SELECT id FROM family_members WHERE family_id = $1 AND user_id = $2',
      [familyId, userId]
    )).rows[0];

    if (!member) {
      res.status(403).json({ error: 'not a member of this family' });
      return;
    }

    await pool.query('DELETE FROM families WHERE id = $1', [familyId]);
    res.status(204).send();
  });

  export default router;
  ```

- [ ] **Step 2: Verify TypeScript compiles (families only)**

  ```bash
  cd server && npx tsc --noEmit 2>&1 | grep families
  ```
  Expected: no errors mentioning `families.ts`.

- [ ] **Step 3: Commit**

  ```bash
  git add server/src/routes/families.ts
  git commit -m "refactor: migrate families routes to async pg"
  ```

---

## Task 9: Refactor src/routes/pointSystem.ts

**Files:**
- Modify: `server/src/routes/pointSystem.ts`

- [ ] **Step 1: Replace the entire file content**

  Replace `server/src/routes/pointSystem.ts` with:

  ```typescript
  import { Router, Request, Response } from 'express';
  import pool from '../db';
  import { requireAuth } from '../middleware/auth';

  const router = Router();
  router.use(requireAuth);

  async function isMember(familyId: number, userId: number): Promise<boolean> {
    const result = await pool.query(
      'SELECT id FROM family_members WHERE family_id = $1 AND user_id = $2',
      [familyId, userId]
    );
    return result.rows.length > 0;
  }

  // GET /families/:familyId/point-system/children
  router.get('/:familyId/point-system/children', async (req: Request, res: Response) => {
    const familyId = parseInt(req.params.familyId, 10);
    const userId = req.auth!.sub;

    if (!(await isMember(familyId, userId))) {
      res.status(403).json({ error: 'not a member of this family' });
      return;
    }

    const children = (await pool.query(
      `SELECT
        fm.id           AS "memberId",
        fm.display_name AS name,
        fm.gender       AS gender,
        fm.birthday_date AS birthday,
        COALESCE((SELECT SUM(delta) FROM point_events WHERE member_id = fm.id), 0)::INTEGER AS balance
      FROM family_members fm
      WHERE fm.family_id = $1
        AND EXISTS (
          SELECT 1 FROM member_role_keywords k
          WHERE k.member_id = fm.id AND k.keyword = 'child'
        )
      ORDER BY fm.joined_at ASC`,
      [familyId]
    )).rows as { memberId: number; name: string; gender: string | null; birthday: string | null; balance: number }[];

    res.json(children);
  });

  // POST /families/:familyId/point-system/children
  router.post('/:familyId/point-system/children', async (req: Request, res: Response) => {
    const familyId = parseInt(req.params.familyId, 10);
    const userId = req.auth!.sub;
    const { name, gender, birthday } = req.body as {
      name?: string;
      gender?: 'boy' | 'girl';
      birthday?: string;
    };

    if (!(await isMember(familyId, userId))) {
      res.status(403).json({ error: 'not a member of this family' });
      return;
    }

    if (!name?.trim()) {
      res.status(400).json({ error: 'name is required' });
      return;
    }

    const validGenders = ['boy', 'girl'];
    const safeGender = gender && validGenders.includes(gender) ? gender : null;
    const safeBirthday = birthday ?? null;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const memberResult = await client.query(
        'INSERT INTO family_members (family_id, user_id, display_name, gender, birthday_date) VALUES ($1, NULL, $2, $3, $4) RETURNING id',
        [familyId, name.trim(), safeGender, safeBirthday]
      );
      const memberId = memberResult.rows[0].id as number;

      await client.query(
        'INSERT INTO member_role_keywords (member_id, keyword) VALUES ($1, $2)',
        [memberId, 'child']
      );

      await client.query('COMMIT');

      res.status(201).json({
        memberId,
        name: name.trim(),
        gender: safeGender,
        birthday: safeBirthday,
        balance: 0,
      });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  });

  // POST /families/:familyId/point-system/events
  router.post('/:familyId/point-system/events', async (req: Request, res: Response) => {
    const familyId = parseInt(req.params.familyId, 10);
    const userId = req.auth!.sub;
    const { memberId, delta, note } = req.body as {
      memberId?: number;
      delta?: number;
      note?: string;
    };

    if (!(await isMember(familyId, userId))) {
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

    const childMember = (await pool.query(
      `SELECT fm.id FROM family_members fm
       WHERE fm.id = $1 AND fm.family_id = $2
         AND EXISTS (
           SELECT 1 FROM member_role_keywords k
           WHERE k.member_id = fm.id AND k.keyword = 'child'
         )`,
      [memberId, familyId]
    )).rows[0] as { id: number } | undefined;

    if (!childMember) {
      res.status(404).json({ error: 'child member not found in this family' });
      return;
    }

    const safeNote = (typeof note === 'string' && note.trim()) ? note.trim() : null;

    const eventResult = await pool.query(
      'INSERT INTO point_events (member_id, delta, note) VALUES ($1, $2, $3) RETURNING id',
      [memberId, delta, safeNote]
    );
    const eventId = eventResult.rows[0].id as number;

    const balanceResult = await pool.query(
      'SELECT COALESCE(SUM(delta), 0)::INTEGER AS "newBalance" FROM point_events WHERE member_id = $1',
      [memberId]
    );
    const newBalance = balanceResult.rows[0].newBalance as number;

    res.status(201).json({ eventId, memberId, delta, note: safeNote, newBalance });
  });

  export default router;
  ```

- [ ] **Step 2: Verify TypeScript compiles — all files**

  ```bash
  cd server && npx tsc --noEmit
  ```
  Expected: no errors at all.

- [ ] **Step 3: Commit**

  ```bash
  git add server/src/routes/pointSystem.ts
  git commit -m "refactor: migrate point system routes to async pg"
  ```

---

## Task 10: Verify server works locally

**Files:** none (verification only)

- [ ] **Step 1: Start the dev server**

  In one terminal:
  ```bash
  cd server && npm run dev
  ```
  Expected: `Server running on port 3000`

- [ ] **Step 2: Test signup**

  In another terminal:
  ```bash
  curl -s -X POST http://localhost:3000/auth/signup \
    -H 'Content-Type: application/json' \
    -d '{"username":"testuser","password":"testpass123"}' | jq .
  ```
  Expected:
  ```json
  { "accessToken": "...", "refreshToken": "...", "displayName": "" }
  ```
  Save the `accessToken` value as `ACCESS_TOKEN` for the next steps.

- [ ] **Step 3: Test login**

  ```bash
  curl -s -X POST http://localhost:3000/auth/login \
    -H 'Content-Type: application/json' \
    -d '{"username":"testuser","password":"testpass123"}' | jq .
  ```
  Expected: same shape as signup response.

- [ ] **Step 4: Test create family**

  Replace `<ACCESS_TOKEN>` with the token from Step 2:
  ```bash
  curl -s -X POST http://localhost:3000/families \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer <ACCESS_TOKEN>' \
    -d '{"familyName":"Test Family","displayName":"Parent","roleKeywords":["parent"]}' | jq .
  ```
  Expected:
  ```json
  { "familyId": 1, "familyName": "Test Family", "memberId": 1, "displayName": "Parent", "roleKeywords": ["parent"] }
  ```
  Save `familyId` as `FAMILY_ID`.

- [ ] **Step 5: Test add child**

  ```bash
  curl -s -X POST http://localhost:3000/families/<FAMILY_ID>/point-system/children \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer <ACCESS_TOKEN>' \
    -d '{"name":"Alice","gender":"girl","birthday":"2018-03-15"}' | jq .
  ```
  Expected:
  ```json
  { "memberId": 2, "name": "Alice", "gender": "girl", "birthday": "2018-03-15", "balance": 0 }
  ```

- [ ] **Step 6: Test add points**

  Replace `<MEMBER_ID>` with the memberId from Step 5:
  ```bash
  curl -s -X POST http://localhost:3000/families/<FAMILY_ID>/point-system/events \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer <ACCESS_TOKEN>' \
    -d '{"memberId":<MEMBER_ID>,"delta":10,"note":"Good job!"}' | jq .
  ```
  Expected:
  ```json
  { "eventId": 1, "memberId": 2, "delta": 10, "note": "Good job!", "newBalance": 10 }
  ```

- [ ] **Step 7: Clean up test data**

  ```bash
  psql betterwe -c "DELETE FROM users WHERE username = 'testuser';"
  ```
  Expected: `DELETE 1`

---

## Task 11: Create Dockerfile

**Files:**
- Create: `server/Dockerfile`

- [ ] **Step 1: Create Dockerfile**

  Create `server/Dockerfile` with:

  ```dockerfile
  FROM node:22-alpine
  WORKDIR /app
  COPY package*.json ./
  RUN npm ci
  COPY . .
  RUN npm run build
  EXPOSE 8080
  CMD ["node", "dist/index.js"]
  ```

- [ ] **Step 2: Create .dockerignore**

  Create `server/.dockerignore` with:

  ```
  node_modules
  dist
  data
  .env
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add server/Dockerfile server/.dockerignore
  git commit -m "chore: add Dockerfile for fly.io deployment"
  ```

---

## Task 12: fly.io account, app, Postgres, and first deploy

**Files:**
- fly.toml (generated by fly launch, then modified)

- [ ] **Step 1: Install flyctl**

  ```bash
  brew install flyctl
  ```
  Verify:
  ```bash
  fly version
  ```
  Expected: `fly v0.x.x ...`

- [ ] **Step 2: Create account and log in**

  ```bash
  fly auth signup
  ```
  This opens a browser. Complete signup at fly.io, then return to the terminal. If you already have an account, use `fly auth login` instead.

- [ ] **Step 3: Initialize the fly app**

  From the `server/` directory:
  ```bash
  cd server && fly launch --no-deploy
  ```
  When prompted:
  - App name: `thebetterwe-api` (or accept the suggested name)
  - Region: choose the closest to you (e.g., `sjc` for San Jose, `lax` for LA, `nrt` for Tokyo)
  - Answer **No** to setting up a Postgres database here (we'll do it separately next)
  - Answer **No** to deploying now

  This creates `fly.toml` in the `server/` directory.

- [ ] **Step 4: Add release_command to fly.toml**

  Open `server/fly.toml`. Find the `[deploy]` section (or add it if absent). Make it read:

  ```toml
  [deploy]
    release_command = "npm run migrate"
  ```

  Also verify the `[[services]]` or `[http_service]` block has `internal_port = 8080`. If it says `3000`, change it to `8080` (fly.io injects `PORT=8080`).

- [ ] **Step 5: Create managed Postgres cluster**

  ```bash
  fly postgres create --name thebetterwe-db
  ```
  When prompted, choose:
  - Region: same as your app
  - Configuration: **Development** (single node, cheapest — fine for this scale)

  Wait for creation to complete. Expected: `Postgres cluster thebetterwe-db created`.

- [ ] **Step 6: Attach Postgres to the app**

  ```bash
  fly postgres attach thebetterwe-db --app thebetterwe-api
  ```
  Expected: `DATABASE_URL secret is set on thebetterwe-api`.
  
  This automatically sets the `DATABASE_URL` secret in your app.

- [ ] **Step 7: Set JWT_SECRET**

  Generate a random secret and set it:
  ```bash
  fly secrets set JWT_SECRET=$(openssl rand -hex 32) --app thebetterwe-api
  ```
  Expected: `Secrets are staged for the first deployment`.

- [ ] **Step 8: Deploy**

  ```bash
  fly deploy
  ```
  Expected sequence:
  1. Builds Docker image
  2. Pushes to fly.io registry
  3. Runs release command: `npm run migrate` (migrations applied)
  4. Starts new app instance
  5. `✓ Finished` with a URL like `https://thebetterwe-api.fly.dev`

- [ ] **Step 9: Verify production health**

  ```bash
  curl -s https://thebetterwe-api.fly.dev/health | jq .
  ```
  Expected:
  ```json
  { "status": "ok" }
  ```

- [ ] **Step 10: Smoke test signup in production**

  ```bash
  curl -s -X POST https://thebetterwe-api.fly.dev/auth/signup \
    -H 'Content-Type: application/json' \
    -d '{"username":"smoketest","password":"smoketest123"}' | jq .
  ```
  Expected: `{ "accessToken": "...", "refreshToken": "...", "displayName": "" }`

- [ ] **Step 11: Commit fly.toml**

  ```bash
  git add server/fly.toml
  git commit -m "chore: add fly.toml for fly.io deployment"
  ```

- [ ] **Step 12: Update iOS app base URL**

  In the iOS app's API client (the file that holds the server base URL), change the development URL from `http://localhost:3000` to `https://thebetterwe-api.fly.dev` (or keep localhost for dev and add an environment switch — that's a separate task).

---

## Post-Deploy: Ongoing workflow

**Local dev:**
```bash
# Start Postgres.app (click the elephant icon → Start)
cd server && npm run dev
```

**Add a schema change:**
```bash
cd server && npm run migrate:create -- add-something
# Edit the generated file in server/migrations/
npm run migrate   # apply locally
```

**Deploy a change:**
```bash
cd server && fly deploy
# fly.io automatically runs migrations before starting the new version
```
