'use strict';

/** @param {import('node-pg-migrate').MigrationBuilder} pgm */
exports.up = (pgm) => {
  pgm.addColumns('point_goals', {
    start_date_new: { type: 'text' },
    end_date_new: { type: 'text' },
  });
  // Migrate any existing epoch values to YYYY-MM-DD (UTC-based, acceptable for legacy data)
  pgm.sql(`
    UPDATE point_goals
      SET start_date_new = TO_CHAR(TO_TIMESTAMP(start_date), 'YYYY-MM-DD')
      WHERE start_date IS NOT NULL;
    UPDATE point_goals
      SET end_date_new = TO_CHAR(TO_TIMESTAMP(end_date), 'YYYY-MM-DD')
      WHERE end_date IS NOT NULL;
  `);
  pgm.dropColumns('point_goals', ['start_date', 'end_date']);
  pgm.renameColumn('point_goals', 'start_date_new', 'start_date');
  pgm.renameColumn('point_goals', 'end_date_new', 'end_date');
};

/** @param {import('node-pg-migrate').MigrationBuilder} pgm */
exports.down = (pgm) => {
  pgm.addColumns('point_goals', {
    start_date_old: { type: 'integer' },
    end_date_old: { type: 'integer' },
  });
  pgm.sql(`
    UPDATE point_goals
      SET start_date_old = EXTRACT(EPOCH FROM start_date::DATE)::INTEGER
      WHERE start_date IS NOT NULL;
    UPDATE point_goals
      SET end_date_old = EXTRACT(EPOCH FROM end_date::DATE)::INTEGER
      WHERE end_date IS NOT NULL;
  `);
  pgm.dropColumns('point_goals', ['start_date', 'end_date']);
  pgm.renameColumn('point_goals', 'start_date_old', 'start_date');
  pgm.renameColumn('point_goals', 'end_date_old', 'end_date');
};
