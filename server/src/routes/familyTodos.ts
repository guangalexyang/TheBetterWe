import { Router, Request, Response } from 'express';
import pool from '../db';
import { requireAuth } from '../middleware/auth';

const router = Router();
router.use(requireAuth);

async function getMemberIdForFamily(familyId: number, userId: number): Promise<number | null> {
  const result = await pool.query(
    'SELECT id FROM family_members WHERE family_id = $1 AND user_id = $2',
    [familyId, userId]
  );
  return result.rows.length > 0 ? (result.rows[0].id as number) : null;
}

function parseIntParam(value: string | undefined): number | null {
  const n = parseInt(value ?? '', 10);
  return isNaN(n) ? null : n;
}

const TODO_SELECT = `
  SELECT
    ft.id,
    ft.family_id               AS "familyId",
    ft.created_by_member_id    AS "createdByMemberId",
    ft.todo_type               AS "todoType",
    ft.title,
    ft.description,
    ft.location,
    ft.priority,
    ft.due_at                  AS "dueAt",
    ft.completed_at            AS "completedAt",
    ft.completed_by_member_id  AS "completedByMemberId",
    completer.display_name     AS "completedByDisplayName",
    ft.created_at              AS "createdAt",
    ft.updated_at              AS "updatedAt"
  FROM family_todos ft
  LEFT JOIN family_members completer ON completer.id = ft.completed_by_member_id
`;

// GET /families/:familyId/todos?filter=all|family|personal
router.get('/:familyId/todos', async (req: Request, res: Response) => {
  const familyId = parseIntParam(req.params.familyId);
  if (familyId === null) { res.status(400).json({ error: 'invalid familyId' }); return; }

  const userId = req.auth!.sub;
  const memberId = await getMemberIdForFamily(familyId, userId);
  if (memberId === null) { res.status(403).json({ error: 'not a member of this family' }); return; }

  const filter = (req.query.filter as string) ?? 'all';
  let typeFilter = '';
  if (filter === 'family')   typeFilter = `AND ft.todo_type = 'family'`;
  if (filter === 'personal') typeFilter = `AND ft.todo_type = 'personal' AND ft.created_by_member_id = $2`;

  const visibilityClause = `
    ft.family_id = $1
    AND (ft.todo_type = 'family' OR ft.created_by_member_id = $2)
    ${typeFilter}
  `;

  const priorityOrder = `CASE ft.priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END`;

  const [activeRes, completedRes] = await Promise.all([
    pool.query(
      `${TODO_SELECT}
       WHERE ${visibilityClause} AND ft.completed_at IS NULL
       ORDER BY ${priorityOrder}, ft.due_at ASC NULLS LAST, ft.created_at ASC`,
      [familyId, memberId]
    ),
    pool.query(
      `${TODO_SELECT}
       WHERE ${visibilityClause} AND ft.completed_at IS NOT NULL
       ORDER BY ft.completed_at DESC
       LIMIT 20`,
      [familyId, memberId]
    ),
  ]);

  res.json({ active: activeRes.rows, completed: completedRes.rows });
});

// POST /families/:familyId/todos
router.post('/:familyId/todos', async (req: Request, res: Response) => {
  const familyId = parseIntParam(req.params.familyId);
  if (familyId === null) { res.status(400).json({ error: 'invalid familyId' }); return; }

  const userId = req.auth!.sub;
  const memberId = await getMemberIdForFamily(familyId, userId);
  if (memberId === null) { res.status(403).json({ error: 'not a member of this family' }); return; }

  const { todoType, title, description, location, priority, dueAt } = req.body as {
    todoType?: string;
    title?: string;
    description?: string;
    location?: string;
    priority?: string;
    dueAt?: number;
  };

  if (!title?.trim()) {
    res.status(400).json({ error: 'title is required' });
    return;
  }
  if (!todoType || !['family', 'personal'].includes(todoType)) {
    res.status(400).json({ error: 'todoType must be "family" or "personal"' });
    return;
  }
  const resolvedPriority = priority ?? 'medium';
  if (!['low', 'medium', 'high'].includes(resolvedPriority)) {
    res.status(400).json({ error: 'priority must be low, medium, or high' });
    return;
  }
  if (dueAt !== undefined && (!Number.isInteger(dueAt) || dueAt < 0)) {
    res.status(400).json({ error: 'dueAt must be a positive integer epoch' });
    return;
  }

  const now = Math.floor(Date.now() / 1000);
  const result = await pool.query(
    `INSERT INTO family_todos
       (family_id, created_by_member_id, todo_type, title, description, location, priority, due_at, created_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $9)
     RETURNING id`,
    [familyId, memberId, todoType, title.trim(), description ?? null, location ?? null, resolvedPriority, dueAt ?? null, now]
  );

  const newId = result.rows[0].id as number;
  const todo = await pool.query(`${TODO_SELECT} WHERE ft.id = $1`, [newId]);

  res.status(201).json(todo.rows[0]);
});

// PATCH /families/:familyId/todos/:todoId
router.patch('/:familyId/todos/:todoId', async (req: Request, res: Response) => {
  const familyId = parseIntParam(req.params.familyId);
  const todoId   = parseIntParam(req.params.todoId);
  if (familyId === null || todoId === null) {
    res.status(400).json({ error: 'invalid familyId or todoId' });
    return;
  }

  const userId = req.auth!.sub;
  const memberId = await getMemberIdForFamily(familyId, userId);
  if (memberId === null) { res.status(403).json({ error: 'not a member of this family' }); return; }

  const existing = await pool.query(
    `SELECT id, todo_type, created_by_member_id FROM family_todos
     WHERE id = $1 AND family_id = $2
       AND (todo_type = 'family' OR created_by_member_id = $3)`,
    [todoId, familyId, memberId]
  );
  if (existing.rows.length === 0) { res.status(404).json({ error: 'todo not found' }); return; }

  const todo = existing.rows[0] as { id: number; todo_type: string; created_by_member_id: number };

  if (todo.todo_type === 'personal' && todo.created_by_member_id !== memberId) {
    res.status(403).json({ error: "cannot edit another member's personal todo" });
    return;
  }

  const { title, description, location, priority, dueAt, completed } = req.body as {
    title?: string;
    description?: string;
    location?: string;
    priority?: string;
    dueAt?: number | null;
    completed?: boolean;
  };

  const now = Math.floor(Date.now() / 1000);
  const setClauses: string[] = ['updated_at = $1'];
  const params: unknown[] = [now];

  if (title !== undefined) {
    if (!title.trim()) { res.status(400).json({ error: 'title cannot be empty' }); return; }
    params.push(title.trim()); setClauses.push(`title = $${params.length}`);
  }
  if (description !== undefined) { params.push(description || null); setClauses.push(`description = $${params.length}`); }
  if (location !== undefined)    { params.push(location || null);    setClauses.push(`location = $${params.length}`); }
  if (priority !== undefined) {
    if (!['low', 'medium', 'high'].includes(priority)) {
      res.status(400).json({ error: 'priority must be low, medium, or high' }); return;
    }
    params.push(priority); setClauses.push(`priority = $${params.length}`);
  }
  if (dueAt !== undefined) { params.push(dueAt ?? null); setClauses.push(`due_at = $${params.length}`); }
  if (completed === true) {
    params.push(now);      setClauses.push(`completed_at = $${params.length}`);
    params.push(memberId); setClauses.push(`completed_by_member_id = $${params.length}`);
  }
  if (completed === false) {
    setClauses.push('completed_at = NULL');
    setClauses.push('completed_by_member_id = NULL');
  }

  params.push(todoId);
  await pool.query(
    `UPDATE family_todos SET ${setClauses.join(', ')} WHERE id = $${params.length}`,
    params
  );

  const updated = await pool.query(`${TODO_SELECT} WHERE ft.id = $1`, [todoId]);
  res.json(updated.rows[0]);
});

// DELETE /families/:familyId/todos/:todoId
router.delete('/:familyId/todos/:todoId', async (req: Request, res: Response) => {
  const familyId = parseIntParam(req.params.familyId);
  const todoId   = parseIntParam(req.params.todoId);
  if (familyId === null || todoId === null) {
    res.status(400).json({ error: 'invalid familyId or todoId' });
    return;
  }

  const userId = req.auth!.sub;
  const memberId = await getMemberIdForFamily(familyId, userId);
  if (memberId === null) { res.status(403).json({ error: 'not a member of this family' }); return; }

  const existing = await pool.query(
    `SELECT id, todo_type, created_by_member_id FROM family_todos
     WHERE id = $1 AND family_id = $2
       AND (todo_type = 'family' OR created_by_member_id = $3)`,
    [todoId, familyId, memberId]
  );
  if (existing.rows.length === 0) { res.status(404).json({ error: 'todo not found' }); return; }

  const row = existing.rows[0] as { todo_type: string; created_by_member_id: number };
  if (row.todo_type === 'personal' && row.created_by_member_id !== memberId) {
    res.status(403).json({ error: "cannot delete another member's personal todo" });
    return;
  }

  await pool.query('DELETE FROM family_todos WHERE id = $1', [todoId]);
  res.status(204).send();
});

export default router;
