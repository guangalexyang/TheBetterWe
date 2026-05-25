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
