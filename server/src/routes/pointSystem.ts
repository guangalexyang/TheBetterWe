import { Router, Request, Response } from 'express';
import db from '../db';
import { requireAuth } from '../middleware/auth';

const router = Router();
router.use(requireAuth);

function isMember(familyId: number, userId: number): boolean {
  return !!db.prepare(
    'SELECT id FROM family_members WHERE family_id = ? AND user_id = ?'
  ).get(familyId, userId);
}

// GET /families/:familyId/point-system/children
router.get('/:familyId/point-system/children', (req: Request, res: Response) => {
  const familyId = parseInt(req.params.familyId, 10);
  const userId = req.auth!.sub;

  if (!isMember(familyId, userId)) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  const children = db.prepare(`
    SELECT
      fm.id           AS memberId,
      fm.display_name AS name,
      fm.gender       AS gender,
      fm.birthday_date AS birthday,
      COALESCE((SELECT SUM(delta) FROM point_events WHERE member_id = fm.id), 0) AS balance
    FROM family_members fm
    WHERE fm.family_id = ?
      AND EXISTS (
        SELECT 1 FROM member_role_keywords k
        WHERE k.member_id = fm.id AND k.keyword = 'child'
      )
    ORDER BY fm.joined_at ASC
  `).all(familyId) as { memberId: number; name: string; gender: string | null; birthday: string | null; balance: number }[];

  res.json(children);
});

// POST /families/:familyId/point-system/children
router.post('/:familyId/point-system/children', (req: Request, res: Response) => {
  const familyId = parseInt(req.params.familyId, 10);
  const userId = req.auth!.sub;
  const { name, gender, birthday } = req.body as {
    name?: string;
    gender?: 'boy' | 'girl';
    birthday?: string;
  };

  if (!isMember(familyId, userId)) {
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

  const create = db.transaction(() => {
    const { lastInsertRowid } = db.prepare(
      'INSERT INTO family_members (family_id, user_id, display_name, gender, birthday_date) VALUES (?, NULL, ?, ?, ?)'
    ).run(familyId, name.trim(), safeGender, safeBirthday);

    const memberId = Number(lastInsertRowid);

    db.prepare(
      'INSERT INTO member_role_keywords (member_id, keyword) VALUES (?, ?)'
    ).run(memberId, 'child');

    return memberId;
  });

  const memberId = create();

  res.status(201).json({
    memberId,
    name: name.trim(),
    gender: safeGender,
    birthday: safeBirthday,
    balance: 0,
  });
});

export default router;
