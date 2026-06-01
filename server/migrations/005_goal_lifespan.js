'use strict';

/** @param {import('node-pg-migrate').MigrationBuilder} pgm */
exports.up = (pgm) => {
  pgm.addColumns('point_goals', {
    lifespan: { type: 'text', notNull: true, default: 'one_time' },
    start_date: { type: 'integer' },
    end_date: { type: 'integer' },
  });
  pgm.addConstraint(
    'point_goals',
    'point_goals_lifespan_check',
    `CHECK (lifespan IN ('daily', 'weekly', 'monthly', 'one_time'))`
  );
};

/** @param {import('node-pg-migrate').MigrationBuilder} pgm */
exports.down = (pgm) => {
  pgm.dropConstraint('point_goals', 'point_goals_lifespan_check');
  pgm.dropColumns('point_goals', ['lifespan', 'start_date', 'end_date']);
};
