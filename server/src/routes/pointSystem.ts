import { Router, Request, Response } from 'express';
import pool from '../db';
import { callGemini, parseJson } from '../services/gemini';
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

function fuzzyMatchChild(
  query: string,
  children: Array<{ memberId: number; name: string; balance: number }>
) {
  const q = query.toLowerCase().trim();
  return children.filter((c) => {
    const lower = c.name.toLowerCase();
    return lower === q || lower.split(/\s+/).includes(q);
  });
}

function parseIntParam(value: string | undefined): number | null {
  const n = parseInt(value ?? '', 10);
  return isNaN(n) ? null : n;
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
  const { memberId, delta, note, date } = req.body as {
    memberId?: number;
    delta?: number;
    note?: string;
    date?: string;
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

  // Validate and sanitise optional event date (YYYY-MM-DD); null falls back to CURRENT_DATE in DB
  const safeDate: string | null =
    typeof date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(date) ? date : null;

  const eventResult = await pool.query(
    'INSERT INTO point_events (member_id, delta, note, event_date) VALUES ($1, $2, $3, COALESCE($4::DATE, CURRENT_DATE)) RETURNING id',
    [memberId, delta, safeNote, safeDate]
  );
  const eventId = eventResult.rows[0].id as number;

  const balanceResult = await pool.query(
    'SELECT COALESCE(SUM(delta), 0)::INTEGER AS "newBalance" FROM point_events WHERE member_id = $1',
    [memberId]
  );
  const newBalance = balanceResult.rows[0].newBalance as number;

  res.status(201).json({ eventId, memberId, delta, note: safeNote, newBalance });
});

// POST /families/:familyId/point-system/parse-voice-command
router.post('/:familyId/point-system/parse-voice-command', async (req: Request, res: Response) => {
  const familyId = parseInt(req.params.familyId, 10);
  const userId = req.auth!.sub;
  const { utterance } = req.body as { utterance?: string };

  if (!utterance?.trim()) {
    res.status(400).json({ error: 'utterance is required' });
    return;
  }

  if (!(await isMember(familyId, userId))) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  // Fetch children for this family
  const children = (await pool.query<{ memberId: number; name: string; balance: number }>(
    `SELECT
      fm.id           AS "memberId",
      fm.display_name AS name,
      COALESCE((SELECT SUM(delta) FROM point_events WHERE member_id = fm.id), 0)::INTEGER AS balance
    FROM family_members fm
    WHERE fm.family_id = $1
      AND EXISTS (
        SELECT 1 FROM member_role_keywords k
        WHERE k.member_id = fm.id AND k.keyword = 'child'
      )`,
    [familyId]
  )).rows;

  // Build prompt with today's date for relative date resolution
  const todayStr = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
  const childrenList = children.map(c => c.name).join(', ');
  const prompt = `Today's date is ${todayStr}.
Available children in this family: ${childrenList}

Parse the following family points management command into JSON with exactly these fields:
- points: positive integer (number of points, 1-9999)
- isAdd: boolean (true = adding points, false = deducting)
- childName: string (the child's name from the command; the command may come from voice recognition with ASR errors, so if the heard name is phonetically similar to one of the available children names, use that exact name — otherwise use the name as heard)
- note: string or null (reason/description, null if not mentioned)
- date: "YYYY-MM-DD" string or null (resolve relative references like "yesterday", "last Wednesday" using today's date; null if no date mentioned)

Command: "${utterance.trim()}"

Examples (available children: Noah, Emma):
- "add 5 points to Noah for doing homework" → {"points":5,"isAdd":true,"childName":"Noah","note":"doing homework","date":null}
- "deduct 3 points from Emma for not cleaning" → {"points":3,"isAdd":false,"childName":"Emma","note":"not cleaning","date":null}
- "给Noah加5分因为做了作业" → {"points":5,"isAdd":true,"childName":"Noah","note":"做了作业","date":null}
- "give Noah 5 points for homework yesterday" (today=2026-05-25) → {"points":5,"isAdd":true,"childName":"Noah","note":"homework","date":"2026-05-24"}

Return ONLY valid JSON. No markdown, no explanation.`;

  console.log(`[parse-voice-command] utterance: "${utterance.trim()}" | children: [${childrenList}]`);
  const geminiResult = await callGemini(prompt);
  if (geminiResult.error) {
    console.error('[parse-voice-command] Gemini error:', geminiResult.error);
    res.status(500).json({ error: 'gemini_error' });
    return;
  }
  console.log(`[parse-voice-command] Gemini raw response: ${geminiResult.text}`);

  // Parse and validate Gemini's response
  let parsed: { points: unknown; isAdd: unknown; childName: unknown; note: unknown; date: unknown };
  try {
    parsed = parseJson(geminiResult.text!);
  } catch {
    res.status(400).json({ error: 'unparseable' });
    return;
  }

  const { points, isAdd, childName, note, date } = parsed;

  if (
    typeof points !== 'number' || !Number.isInteger(points) || points < 1 || points > 9999 ||
    typeof isAdd !== 'boolean' ||
    typeof childName !== 'string' || !(childName as string).trim() ||
    (note !== null && typeof note !== 'string') ||
    (date !== null && typeof date !== 'string')
  ) {
    res.status(400).json({ error: 'unparseable' });
    return;
  }

  // Validate date format and reject future dates
  let safeDate: string | null = null;
  if (date !== null) {
    const dateStr = date as string;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
      res.status(400).json({ error: 'unparseable' });
      return;
    }
    if (dateStr > todayStr) {
      res.status(400).json({ error: 'future_date' });
      return;
    }
    safeDate = dateStr;
  }

  // Fuzzy-match child name
  const matches = fuzzyMatchChild(childName as string, children);
  if (matches.length === 0) {
    res.status(404).json({ error: 'child_not_found', childName });
    return;
  }
  if (matches.length > 1) {
    res.status(409).json({ error: 'child_ambiguous' });
    return;
  }

  const child = matches[0];
  const delta = (isAdd as boolean) ? (points as number) : -(points as number);
  const safeNote = (typeof note === 'string' && (note as string).trim()) ? (note as string).trim() : null;

  res.json({
    memberId: child.memberId,
    memberName: child.name,
    delta,
    note: safeNote,
    date: safeDate,
  });
});

// GET /families/:familyId/point-system/members/:memberId/events?limit=20&offset=0
router.get('/:familyId/point-system/members/:memberId/events', async (req: Request, res: Response) => {
  const familyId = parseIntParam(req.params.familyId);
  const memberId = parseIntParam(req.params.memberId);
  const userId = req.auth!.sub;

  if (familyId === null || memberId === null) {
    res.status(400).json({ error: 'invalid id' });
    return;
  }

  const limitRaw = parseIntParam(req.query.limit as string);
  const offsetRaw = parseIntParam(req.query.offset as string);
  const limit = Math.min(limitRaw ?? 20, 50);
  const offset = offsetRaw ?? 0;

  if (!(await isMember(familyId, userId))) {
    res.status(403).json({ error: 'not a member of this family' });
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

  const rows = (await pool.query(
    `SELECT
      pe.id          AS "eventId",
      pe.member_id   AS "memberId",
      pe.delta,
      pe.note,
      pe.event_date  AS "eventDate",
      pe.created_at  AS "createdAt"
    FROM point_events pe
    JOIN family_members fm ON fm.id = pe.member_id
    WHERE pe.member_id = $1 AND fm.family_id = $2
    ORDER BY pe.created_at DESC
    LIMIT $3 OFFSET $4`,
    [memberId, familyId, limit, offset]
  )).rows;

  res.json(rows);
});

// DELETE /families/:familyId/point-system/events/:eventId
router.delete('/:familyId/point-system/events/:eventId', async (req: Request, res: Response) => {
  const familyId = parseIntParam(req.params.familyId);
  const eventId = parseIntParam(req.params.eventId);
  const userId = req.auth!.sub;

  if (familyId === null || eventId === null) {
    res.status(400).json({ error: 'invalid id' });
    return;
  }

  if (!(await isMember(familyId, userId))) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  const result = await pool.query(
    `DELETE FROM point_events pe
     USING family_members fm
     WHERE pe.id = $1 AND pe.member_id = fm.id AND fm.family_id = $2
     RETURNING pe.id`,
    [eventId, familyId]
  );

  if (result.rows.length === 0) {
    res.status(404).json({ error: 'event not found' });
    return;
  }

  res.status(204).send();
});

// GET /families/:familyId/point-system/members/:memberId/goals
router.get('/:familyId/point-system/members/:memberId/goals', async (req: Request, res: Response) => {
  const familyId = parseIntParam(req.params.familyId);
  const memberId = parseIntParam(req.params.memberId);
  const userId = req.auth!.sub;

  if (familyId === null || memberId === null) {
    res.status(400).json({ error: 'invalid id' });
    return;
  }

  if (!(await isMember(familyId, userId))) {
    res.status(403).json({ error: 'not a member of this family' });
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

  const rows = (await pool.query(
    `SELECT
      pg.id             AS "goalId",
      pg.member_id      AS "memberId",
      pg.name,
      pg.target_points  AS "targetPoints"
    FROM point_goals pg
    JOIN family_members fm ON fm.id = pg.member_id
    WHERE pg.member_id = $1 AND fm.family_id = $2
    ORDER BY pg.created_at ASC`,
    [memberId, familyId]
  )).rows;

  res.json(rows);
});

// POST /families/:familyId/point-system/goals
router.post('/:familyId/point-system/goals', async (req: Request, res: Response) => {
  const familyId = parseIntParam(req.params.familyId);
  const userId = req.auth!.sub;
  const { memberId, name, targetPoints } = req.body as {
    memberId?: number;
    name?: string;
    targetPoints?: number;
  };

  if (familyId === null) {
    res.status(400).json({ error: 'invalid id' });
    return;
  }

  if (!(await isMember(familyId, userId))) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  if (
    typeof memberId !== 'number' ||
    !name?.trim() ||
    typeof targetPoints !== 'number' ||
    !Number.isInteger(targetPoints) ||
    targetPoints < 1 ||
    targetPoints > 999999
  ) {
    res.status(400).json({ error: 'invalid request' });
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

  const result = await pool.query(
    `INSERT INTO point_goals (member_id, name, target_points)
     VALUES ($1, $2, $3)
     RETURNING id AS "goalId", member_id AS "memberId", name, target_points AS "targetPoints"`,
    [memberId, name.trim(), targetPoints]
  );

  res.status(201).json(result.rows[0]);
});

// DELETE /families/:familyId/point-system/goals/:goalId
router.delete('/:familyId/point-system/goals/:goalId', async (req: Request, res: Response) => {
  const familyId = parseIntParam(req.params.familyId);
  const goalId = parseIntParam(req.params.goalId);
  const userId = req.auth!.sub;

  if (familyId === null || goalId === null) {
    res.status(400).json({ error: 'invalid id' });
    return;
  }

  if (!(await isMember(familyId, userId))) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  const result = await pool.query(
    `DELETE FROM point_goals pg
     USING family_members fm
     WHERE pg.id = $1 AND pg.member_id = fm.id AND fm.family_id = $2
     RETURNING pg.id`,
    [goalId, familyId]
  );

  if (result.rows.length === 0) {
    res.status(404).json({ error: 'goal not found' });
    return;
  }

  res.status(204).send();
});

export default router;
