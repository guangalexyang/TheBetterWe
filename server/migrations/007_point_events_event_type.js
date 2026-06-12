exports.up = (pgm) => {
  pgm.sql(`
    ALTER TABLE point_events ADD COLUMN event_type TEXT;
    UPDATE point_events SET event_type = CASE WHEN delta > 0 THEN 'add' ELSE 'redeem' END;
    ALTER TABLE point_events ALTER COLUMN event_type SET NOT NULL;
    ALTER TABLE point_events ALTER COLUMN event_type SET DEFAULT 'add';
    ALTER TABLE point_events ADD CONSTRAINT point_events_event_type_check
      CHECK (event_type IN ('add', 'deduct', 'redeem'));
  `);
};

exports.down = (pgm) => {
  pgm.sql(`ALTER TABLE point_events DROP COLUMN event_type;`);
};
