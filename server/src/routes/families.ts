import { Router, Request, Response } from 'express';
import crypto from 'crypto';
import pool from '../db';
import { requireAuth } from '../middleware/auth';

const router = Router();
router.use(requireAuth);

// GET /families/mine
router.get('/mine', async (req: Request, res: Response) => {
  const userId = req.auth!.sub;

  const members = (await pool.query(
    `SELECT fm.id AS "memberId", fm.family_id AS "familyId", fm.display_name AS "displayName", f.name AS "familyName"
     FROM family_members fm
     JOIN families f ON f.id = fm.family_id
     WHERE fm.user_id = $1`,
    [userId]
  )).rows as { memberId: number; familyId: number; displayName: string; familyName: string }[];

  if (members.length === 0) {
    res.json([]);
    return;
  }

  const result = await Promise.all(members.map(async (m) => {
    const keywords = (await pool.query(
      'SELECT keyword FROM member_role_keywords WHERE member_id = $1',
      [m.memberId]
    )).rows.map((r: { keyword: string }) => r.keyword);

    return { familyId: m.familyId, familyName: m.familyName, memberId: m.memberId, displayName: m.displayName, roleKeywords: keywords };
  }));

  res.json(result);
});

// POST /families
router.post('/', async (req: Request, res: Response) => {
  const { familyName, displayName, roleKeywords } = req.body as {
    familyName?: string;
    displayName?: string;
    roleKeywords?: string[];
  };

  if (!familyName?.trim() || !displayName?.trim()) {
    res.status(400).json({ error: 'familyName and displayName are required' });
    return;
  }

  const userId = req.auth!.sub;
  const inviteCode = crypto.randomUUID();
  const keywords: string[] = Array.isArray(roleKeywords) ? roleKeywords : [];

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const familyResult = await client.query(
      'INSERT INTO families (name, invite_code) VALUES ($1, $2) RETURNING id',
      [familyName.trim(), inviteCode]
    );
    const familyId = familyResult.rows[0].id as number;

    const memberResult = await client.query(
      'INSERT INTO family_members (family_id, user_id, display_name) VALUES ($1, $2, $3) RETURNING id',
      [familyId, userId, displayName.trim()]
    );
    const memberId = memberResult.rows[0].id as number;

    for (const kw of keywords) {
      await client.query(
        'INSERT INTO member_role_keywords (member_id, keyword) VALUES ($1, $2)',
        [memberId, kw]
      );
    }

    await client.query('COMMIT');

    res.status(201).json({
      familyId,
      familyName: familyName.trim(),
      memberId,
      displayName: displayName.trim(),
      roleKeywords: keywords,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

// DELETE /families/:id
router.delete('/:id', async (req: Request, res: Response) => {
  const familyId = parseInt(req.params.id, 10);
  const userId = req.auth!.sub;

  const member = (await pool.query(
    'SELECT id FROM family_members WHERE family_id = $1 AND user_id = $2',
    [familyId, userId]
  )).rows[0];

  if (!member) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  await pool.query('DELETE FROM families WHERE id = $1', [familyId]);
  res.status(204).send();
});

export default router;
