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
