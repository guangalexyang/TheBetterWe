import { Router, Request, Response } from 'express';
import pool from '../db';
import { requireAuth } from '../middleware/auth';

const router = Router();
router.use(requireAuth);

async function isMember(familyId: number, userId: number): Promise<boolean> {
  const result = await pool.query(
    'SELECT id FROM family_members WHERE family_id = $1 AND user_id = $2',
    [familyId, userId]
  );
  return result.rows.length > 0;
}

// GET /families/:familyId/point-system/children
router.get('/:familyId/point-system/children', async (req: Request, res: Response) => {
  const familyId = parseInt(req.params.familyId, 10);
  const userId = req.auth!.sub;

  if (!(await isMember(familyId, userId))) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  const children = (await pool.query(
    `SELECT
      fm.id           AS "memberId",
      fm.display_name AS name,
      fm.gender       AS gender,
      fm.birthday_date AS birthday,
      COALESCE((SELECT SUM(delta) FROM point_events WHERE member_id = fm.id), 0)::INTEGER AS balance
    FROM family_members fm
    WHERE fm.family_id = $1
      AND EXISTS (
        SELECT 1 FROM member_role_keywords k
        WHERE k.member_id = fm.id AND k.keyword = 'child'
      )
    ORDER BY fm.joined_at ASC`,
    [familyId]
  )).rows as { memberId: number; name: string; gender: string | null; birthday: string | null; balance: number }[];

  res.json(children);
});

// POST /families/:familyId/point-system/children
router.post('/:familyId/point-system/children', async (req: Request, res: Response) => {
  const familyId = parseInt(req.params.familyId, 10);
  const userId = req.auth!.sub;
  const { name, gender, birthday } = req.body as {
    name?: string;
    gender?: 'boy' | 'girl';
    birthday?: string;
  };

  if (!(await isMember(familyId, userId))) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  if (!name?.trim()) {
    res.status(400).json({ error: 'name is required' });
    return;
  }

  const validGenders = ['boy', 'girl'];
  const safeGender = gender && validGenders.includes(gender) ? gender : null;
  const safeBirthday = birthday ?? null;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const memberResult = await client.query(
      'INSERT INTO family_members (family_id, user_id, display_name, gender, birthday_date) VALUES ($1, NULL, $2, $3, $4) RETURNING id',
      [familyId, name.trim(), safeGender, safeBirthday]
    );
    const memberId = memberResult.rows[0].id as number;

    await client.query(
      'INSERT INTO member_role_keywords (member_id, keyword) VALUES ($1, $2)',
      [memberId, 'child']
    );

    await client.query('COMMIT');

    res.status(201).json({
      memberId,
      name: name.trim(),
      gender: safeGender,
      birthday: safeBirthday,
      balance: 0,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

// POST /families/:familyId/point-system/events
router.post('/:familyId/point-system/events', async (req: Request, res: Response) => {
  const familyId = parseInt(req.params.familyId, 10);
  const userId = req.auth!.sub;
  const { memberId, delta, note } = req.body as {
    memberId?: number;
    delta?: number;
    note?: string;
  };

  if (!(await isMember(familyId, userId))) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  if (
    typeof memberId !== 'number' ||
    typeof delta !== 'number' ||
    !Number.isInteger(delta) ||
    delta === 0 ||
    Math.abs(delta) > 9999
  ) {
    res.status(400).json({ error: 'invalid memberId or delta' });
    return;
  }

  const childMember = (await pool.query(
    `SELECT fm.id FROM family_members fm
     WHERE fm.id = $1 AND fm.family_id = $2
       AND EXISTS (
         SELECT 1 FROM member_role_keywords k
         WHERE k.member_id = fm.id AND k.keyword = 'child'
       )`,
    [memberId, familyId]
  )).rows[0] as { id: number } | undefined;

  if (!childMember) {
    res.status(404).json({ error: 'child member not found in this family' });
    return;
  }

  const safeNote = (typeof note === 'string' && note.trim()) ? note.trim() : null;

  const eventResult = await pool.query(
    'INSERT INTO point_events (member_id, delta, note) VALUES ($1, $2, $3) RETURNING id',
    [memberId, delta, safeNote]
  );
  const eventId = eventResult.rows[0].id as number;

  const balanceResult = await pool.query(
    'SELECT COALESCE(SUM(delta), 0)::INTEGER AS "newBalance" FROM point_events WHERE member_id = $1',
    [memberId]
  );
  const newBalance = balanceResult.rows[0].newBalance as number;

  res.status(201).json({ eventId, memberId, delta, note: safeNote, newBalance });
});

export default router;
