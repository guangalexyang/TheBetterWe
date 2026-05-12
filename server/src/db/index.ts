import Database from 'better-sqlite3';
import path from 'path';

const DB_PATH = process.env.DB_PATH ?? path.join(__dirname, '../../data/betterwe.db');

const db = new Database(DB_PATH);

db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL COLLATE NOCASE,
    password_hash TEXT NOT NULL,
    display_name TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL DEFAULT (unixepoch())
  );

  CREATE TABLE IF NOT EXISTS refresh_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    family_id TEXT NOT NULL,
    token_hash TEXT UNIQUE NOT NULL,
    used INTEGER NOT NULL DEFAULT 0,
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch())
  );

  CREATE TABLE IF NOT EXISTS families (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL,
    invite_code TEXT    UNIQUE NOT NULL,
    created_at  INTEGER NOT NULL DEFAULT (unixepoch())
  );

  CREATE TABLE IF NOT EXISTS family_members (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    family_id    INTEGER NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    user_id      INTEGER REFERENCES users(id) ON DELETE SET NULL,
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
  CREATE INDEX IF NOT EXISTS idx_families_invite_code     ON families(invite_code);
`);

export default db;
