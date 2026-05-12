import { Router, Request, Response } from 'express';
import crypto from 'crypto';
import db from '../db';
import { requireAuth } from '../middleware/auth';

const router = Router();
router.use(requireAuth);

// GET /families/mine
router.get('/mine', (req: Request, res: Response) => {
  const userId = req.auth!.sub;

  const members = db.prepare(`
    SELECT fm.id AS memberId, fm.family_id AS familyId, fm.display_name AS displayName, f.name AS familyName
    FROM family_members fm
    JOIN families f ON f.id = fm.family_id
    WHERE fm.user_id = ?
  `).all(userId) as { memberId: number; familyId: number; displayName: string; familyName: string }[];

  if (members.length === 0) {
    res.json([]);
    return;
  }

  const result = members.map(m => {
    const keywords = (db.prepare(
      'SELECT keyword FROM member_role_keywords WHERE member_id = ?'
    ).all(m.memberId) as { keyword: string }[]).map(r => r.keyword);

    return { familyId: m.familyId, familyName: m.familyName, memberId: m.memberId, displayName: m.displayName, roleKeywords: keywords };
  });

  res.json(result);
});

// POST /families
router.post('/', (req: Request, res: Response) => {
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

  const create = db.transaction(() => {
    const { lastInsertRowid: rawFamilyId } = db.prepare(
      'INSERT INTO families (name, invite_code) VALUES (?, ?)'
    ).run(familyName.trim(), inviteCode);

    const familyId = Number(rawFamilyId);

    const { lastInsertRowid: rawMemberId } = db.prepare(
      'INSERT INTO family_members (family_id, user_id, display_name) VALUES (?, ?, ?)'
    ).run(familyId, userId, displayName.trim());

    const memberId = Number(rawMemberId);

    const insertKeyword = db.prepare(
      'INSERT INTO member_role_keywords (member_id, keyword) VALUES (?, ?)'
    );
    for (const kw of keywords) insertKeyword.run(memberId, kw);

    return { familyId, memberId };
  });

  const { familyId, memberId } = create();

  res.status(201).json({
    familyId,
    familyName: familyName.trim(),
    memberId,
    displayName: displayName.trim(),
    roleKeywords: keywords,
  });
});

// DELETE /families/:id
router.delete('/:id', (req: Request, res: Response) => {
  const familyId = parseInt(req.params.id, 10);
  const userId = req.auth!.sub;

  const member = db.prepare(
    'SELECT id FROM family_members WHERE family_id = ? AND user_id = ?'
  ).get(familyId, userId);

  if (!member) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  db.prepare('DELETE FROM families WHERE id = ?').run(familyId);
  res.status(204).send();
});

export default router;
