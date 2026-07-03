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

// GET /families/by-invite/:code — look up a family by invite code (no membership required)
router.get('/by-invite/:code', async (req: Request, res: Response) => {
  const { code } = req.params;
  if (!code?.trim()) {
    res.status(400).json({ error: 'code required' });
    return;
  }
  const row = (await pool.query(
    'SELECT id AS "familyId", name AS "familyName" FROM families WHERE invite_code = $1',
    [code.trim()]
  )).rows[0];
  if (!row) {
    res.status(404).json({ error: 'invalid invite code' });
    return;
  }
  res.json(row);
});

// POST /families/join — join a family using an invite code
router.post('/join', async (req: Request, res: Response) => {
  const { inviteCode, displayName, role } = req.body as {
    inviteCode?: string;
    displayName?: string;
    role?: string;
  };

  if (!inviteCode?.trim() || !displayName?.trim() || !role?.trim()) {
    res.status(400).json({ error: 'inviteCode, displayName, and role are required' });
    return;
  }

  const userId = req.auth!.sub;

  const family = (await pool.query(
    'SELECT id FROM families WHERE invite_code = $1',
    [inviteCode.trim()]
  )).rows[0];
  if (!family) {
    res.status(404).json({ error: 'invalid invite code' });
    return;
  }
  const familyId = family.id as number;

  const existing = (await pool.query(
    'SELECT id FROM family_members WHERE family_id = $1 AND user_id = $2',
    [familyId, userId]
  )).rows[0];
  if (existing) {
    res.status(409).json({ error: 'already a member of this family' });
    return;
  }

  // Copy module keywords from existing parent members so the joiner sees the same tabs
  const moduleKeywords = (await pool.query<{ keyword: string }>(
    `SELECT DISTINCT mrk.keyword
     FROM member_role_keywords mrk
     JOIN family_members fm ON fm.id = mrk.member_id
     WHERE fm.family_id = $1 AND fm.user_id IS NOT NULL`,
    [familyId]
  )).rows.map(r => r.keyword);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const memberResult = await client.query(
      'INSERT INTO family_members (family_id, user_id, display_name) VALUES ($1, $2, $3) RETURNING id',
      [familyId, userId, displayName.trim()]
    );
    const memberId = memberResult.rows[0].id as number;

    // Insert role keyword
    await client.query(
      'INSERT INTO member_role_keywords (member_id, keyword) VALUES ($1, $2)',
      [memberId, role.trim().toLowerCase()]
    );

    // Insert module keywords copied from existing members
    for (const kw of moduleKeywords) {
      await client.query(
        'INSERT INTO member_role_keywords (member_id, keyword) VALUES ($1, $2)',
        [memberId, kw]
      );
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  // Return the caller's full membership list
  const members = (await pool.query(
    `SELECT fm.id AS "memberId", fm.family_id AS "familyId", fm.display_name AS "displayName", f.name AS "familyName"
     FROM family_members fm
     JOIN families f ON f.id = fm.family_id
     WHERE fm.user_id = $1`,
    [userId]
  )).rows as { memberId: number; familyId: number; displayName: string; familyName: string }[];

  const result = await Promise.all(members.map(async (m) => {
    const keywords = (await pool.query(
      'SELECT keyword FROM member_role_keywords WHERE member_id = $1',
      [m.memberId]
    )).rows.map((r: { keyword: string }) => r.keyword);
    return { familyId: m.familyId, familyName: m.familyName, memberId: m.memberId, displayName: m.displayName, roleKeywords: keywords };
  }));

  res.json(result);
});

// GET /families/:id/invite-code — fetch the current invite code (members only)
router.get('/:id/invite-code', async (req: Request, res: Response) => {
  const familyId = parseInt(req.params.id, 10);
  if (isNaN(familyId)) { res.status(400).json({ error: 'invalid familyId' }); return; }
  const userId = req.auth!.sub;

  const member = (await pool.query(
    'SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2',
    [familyId, userId]
  )).rows[0];
  if (!member) { res.status(403).json({ error: 'not a member of this family' }); return; }

  const family = (await pool.query(
    'SELECT invite_code AS "inviteCode" FROM families WHERE id = $1',
    [familyId]
  )).rows[0];
  res.json({ inviteCode: family.inviteCode });
});

// POST /families/:id/invite-code/refresh — generate a new invite code, invalidating the old one
router.post('/:id/invite-code/refresh', async (req: Request, res: Response) => {
  const familyId = parseInt(req.params.id, 10);
  if (isNaN(familyId)) { res.status(400).json({ error: 'invalid familyId' }); return; }
  const userId = req.auth!.sub;

  const member = (await pool.query(
    'SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2',
    [familyId, userId]
  )).rows[0];
  if (!member) { res.status(403).json({ error: 'not a member of this family' }); return; }

  const newCode = crypto.randomUUID();
  await pool.query('UPDATE families SET invite_code = $1 WHERE id = $2', [newCode, familyId]);
  res.json({ inviteCode: newCode });
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
