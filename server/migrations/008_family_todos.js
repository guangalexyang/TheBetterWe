exports.up = (pgm) => {
  pgm.sql(`
    CREATE TABLE family_todos (
      id                      SERIAL PRIMARY KEY,
      family_id               INTEGER NOT NULL REFERENCES families(id) ON DELETE CASCADE,
      created_by_member_id    INTEGER NOT NULL REFERENCES family_members(id) ON DELETE CASCADE,
      todo_type               TEXT NOT NULL CHECK (todo_type IN ('family', 'personal')),
      title                   TEXT NOT NULL,
      description             TEXT,
      location                TEXT,
      priority                TEXT NOT NULL DEFAULT 'medium'
                                CHECK (priority IN ('low', 'medium', 'high')),
      due_at                  INTEGER,
      completed_at            INTEGER,
      completed_by_member_id  INTEGER REFERENCES family_members(id) ON DELETE SET NULL,
      created_at              INTEGER NOT NULL
                                DEFAULT EXTRACT(EPOCH FROM NOW())::INTEGER,
      updated_at              INTEGER NOT NULL
                                DEFAULT EXTRACT(EPOCH FROM NOW())::INTEGER
    );

    CREATE INDEX idx_family_todos_family     ON family_todos(family_id);
    CREATE INDEX idx_family_todos_created_by ON family_todos(created_by_member_id);
  `);
};

exports.down = (pgm) => {
  pgm.sql(`DROP TABLE IF EXISTS family_todos;`);
};
