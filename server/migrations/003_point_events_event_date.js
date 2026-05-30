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
