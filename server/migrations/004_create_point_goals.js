/* eslint-disable camelcase */
exports.shorthands = undefined;

exports.up = (pgm) => {
  pgm.createTable('point_goals', {
    id: { type: 'serial', primaryKey: true },
    member_id: {
      type: 'integer',
      notNull: true,
      references: 'family_members(id)',
      onDelete: 'CASCADE',
    },
    name: { type: 'text', notNull: true },
    target_points: { type: 'integer', notNull: true },
    created_at: { type: 'integer', notNull: true, default: pgm.func('EXTRACT(EPOCH FROM NOW())::INTEGER') },
  });
  pgm.addIndex('point_goals', 'member_id');
};

exports.down = (pgm) => {
  pgm.dropTable('point_goals');
};
