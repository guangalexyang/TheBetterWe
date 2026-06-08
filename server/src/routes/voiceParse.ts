import { Router, Request, Response } from 'express';
import pool from '../db';
import { requireAuth } from '../middleware/auth';
import { callDoubao, parseJson } from '../services/doubao';

const router = Router();
router.use(requireAuth);

function lowConfidence(debug: string) {
  return {
    confidence: 'low' as const,
    memberId: null,
    memberName: null,
    delta: null,
    note: null,
    date: null,
    _debug: debug,
  };
}

function buildPrompt(
  transcript: string,
  children: Array<{ memberId: number; name: string }>,
  todayStr: string
): string {
  const childList = children.map(c => `{"id":${c.memberId},"name":"${c.name}"}`).join(', ');
  const exampleId1 = children[0]?.memberId ?? 1;
  const exampleId2 = children[1]?.memberId ?? 2;
  return `Today's date is ${todayStr}.
Family children: [${childList}]

Parse the following family points command into JSON with exactly these fields:
- points: positive integer (1-9999)
- isAdd: boolean (true = adding points, false = deducting/redeeming)
- memberId: integer — the "id" of the matching child. Correct ASR/phonetic errors (e.g. "Nova" → match Noah, "Amy" → match Emma).
- note: string or null (reason/description, null if not mentioned)
- date: "YYYY-MM-DD" or null (resolve relative references using today; null if not mentioned)

Command: "${transcript}"

Examples (children: [{"id":${exampleId1},"name":"Noah"}, {"id":${exampleId2},"name":"Emma"}]):
- "给 Nova 加10分" → {"points":10,"isAdd":true,"memberId":${exampleId1},"note":null,"date":null}
- "给Emma扣5分因为没做作业" → {"points":5,"isAdd":false,"memberId":${exampleId2},"note":"没做作业","date":null}
- "add 5 points to Noah for homework" → {"points":5,"isAdd":true,"memberId":${exampleId1},"note":"homework","date":null}

Return ONLY valid JSON. No markdown, no explanation.`;
}

router.post('/parse', async (req: Request, res: Response) => {
  const { transcript, familyId: familyIdRaw } = req.body as {
    transcript?: string;
    familyId?: unknown;
  };

  console.log('[voice/parse] received transcript:', transcript, '| familyId:', familyIdRaw);

  if (!transcript?.trim()) {
    res.status(400).json({ error: 'transcript required' });
    return;
  }

  const familyId = parseInt(String(familyIdRaw ?? ''), 10);
  if (isNaN(familyId)) {
    res.status(400).json({ error: 'familyId required' });
    return;
  }

  const userId = req.auth!.sub;

  const memberCheck = await pool.query(
    'SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2',
    [familyId, userId]
  );
  if (memberCheck.rows.length === 0) {
    res.status(403).json({ error: 'not a member of this family' });
    return;
  }

  const children = (await pool.query<{ memberId: number; name: string }>(
    `SELECT fm.id AS "memberId", fm.display_name AS name
     FROM family_members fm
     WHERE fm.family_id = $1
       AND EXISTS (
         SELECT 1 FROM member_role_keywords k
         WHERE k.member_id = fm.id AND k.keyword = 'child'
       )`,
    [familyId]
  )).rows;

  console.log('[voice/parse] children found:', children.map(c => c.name));

  if (children.length === 0) {
    res.json(lowConfidence('no_children'));
    return;
  }

  const todayStr = new Date().toISOString().split('T')[0];
  const prompt = buildPrompt(transcript.trim(), children, todayStr);

  const llmResult = await callDoubao(prompt);
  console.log('[voice/parse] Doubao raw text:', llmResult.text, '| error:', llmResult.error);
  if (llmResult.error || !llmResult.text) {
    res.json(lowConfidence(`doubao_error:${llmResult.error ?? 'empty_text'}`));
    return;
  }

  let parsed: {
    points: unknown; isAdd: unknown; memberId: unknown; note: unknown; date: unknown;
  };
  try {
    parsed = parseJson(llmResult.text);
    console.log('[voice/parse] parsed JSON:', JSON.stringify(parsed));
  } catch {
    res.json(lowConfidence(`json_parse_failed:${llmResult.text.slice(0, 120)}`));
    return;
  }

  const { points, isAdd, memberId: memberIdRaw, note, date } = parsed;

  if (
    typeof points !== 'number' || !Number.isInteger(points) || points < 1 || points > 9999 ||
    typeof isAdd !== 'boolean' ||
    typeof memberIdRaw !== 'number' || !Number.isInteger(memberIdRaw)
  ) {
    res.json(lowConfidence(`field_invalid:points=${JSON.stringify(points)},isAdd=${JSON.stringify(isAdd)},memberId=${JSON.stringify(memberIdRaw)}`));
    return;
  }

  const child = children.find(c => c.memberId === memberIdRaw);
  if (!child) {
    res.json(lowConfidence(`unknown_memberId:${memberIdRaw},known:${children.map(c => c.memberId).join(',')}`));
    return;
  }

  let safeDate: string | null = null;
  if (typeof date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(date) && date <= todayStr) {
    safeDate = date;
  }

  const safeNote = typeof note === 'string' && note.trim() ? note.trim() : null;
  const delta = (isAdd as boolean) ? (points as number) : -(points as number);

  res.json({
    confidence: 'high',
    memberId: child.memberId,
    memberName: child.name,
    delta,
    note: safeNote,
    date: safeDate,
  });
});

export default router;
