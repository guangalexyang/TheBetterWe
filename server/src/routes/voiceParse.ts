import { Router, Request, Response } from 'express';
import pool from '../db';
import { requireAuth } from '../middleware/auth';
import { callDoubao, parseJson } from '../services/doubao';

const router = Router();
router.use(requireAuth);

function lowConfidence(debug: string) {
  return {
    confidence: 'low' as const,
    intentType: null,
    memberId: null,
    memberName: null,
    delta: null,
    note: null,
    date: null,
    eventType: null,
    todoTitle: null,
    todoType: null,
    todoPriority: null,
    _debug: debug,
  };
}

function buildPrompt(
  transcript: string,
  children: Array<{ memberId: number; name: string }>,
  todayStr: string,
  tomorrowStr: string
): string {
  const childList = children.length > 0
    ? children.map(c => `{"id":${c.memberId},"name":"${c.name}"}`).join(', ')
    : '[]';
  const exampleId1 = children[0]?.memberId ?? 1;
  const exampleId2 = children[1]?.memberId ?? 2;
  return `Today's date is ${todayStr}.
Family children: [${childList}]

Classify and parse the following family voice command. Return JSON with an "intentType" field.

CLASSIFICATION RULE (check in order):
- "points"      if command contains points keywords: 分/积分/加分/扣分/兑换 / points/deduct/redeem/reward
- "create_todo" if command contains task keywords: 任务/待办/提醒/记一下/帮我加 / task/todo/remind/remember
- Neither matches → return {"intentType":"unknown"}

For "points" return: { intentType, points, action, memberId, note, date }
- points: integer 1-9999
- action: "add" | "deduct" | "redeem"
- memberId: integer matching a child id (correct ASR phonetic errors e.g. "Nova" → Noah)
- note: string or null
- date: "YYYY-MM-DD" or null (resolve relative dates using today)

For "create_todo" return: { intentType, todoTitle, todoType, todoPriority, note, date }
- todoTitle: concise task title (the main action, e.g. "去TNT买菜" not just "买菜")
- todoType: "personal" if command contains 提醒我/我的待办/个人/remind me/my todo; "family" otherwise (default)
- todoPriority: "high" if urgency words present (急/紧急/重要/urgent/important/asap); "low" if explicitly low; "medium" otherwise
- note: any extra details or items mentioned beyond the title (e.g. "要买鸡蛋、牛奶"); null if none
- date: "YYYY-MM-DD" or null (due date; resolve relative references using today)

Command: "${transcript}"

Points examples (children: [{"id":${exampleId1},"name":"Noah"}, {"id":${exampleId2},"name":"Emma"}]):
- "给Nova加10分" → {"intentType":"points","points":10,"action":"add","memberId":${exampleId1},"note":null,"date":null}
- "给Emma扣5分因为没做作业" → {"intentType":"points","points":5,"action":"deduct","memberId":${exampleId2},"note":"没做作业","date":null}
- "小明兑换了20分" → {"intentType":"points","points":20,"action":"redeem","memberId":${exampleId1},"note":null,"date":null}
- "add 5 points to Noah for homework" → {"intentType":"points","points":5,"action":"add","memberId":${exampleId1},"note":"homework","date":null}

Todo examples:
- "帮我加个任务：买牛奶" → {"intentType":"create_todo","todoTitle":"买牛奶","todoType":"family","todoPriority":"medium","note":null,"date":null}
- "提醒我明天去TNT买菜，要买鸡蛋牛奶" → {"intentType":"create_todo","todoTitle":"去TNT买菜","todoType":"personal","todoPriority":"medium","note":"要买鸡蛋、牛奶","date":"${tomorrowStr}"}
- "提醒大家交电费，很重要" → {"intentType":"create_todo","todoTitle":"交电费","todoType":"family","todoPriority":"high","note":null,"date":null}
- "add a task: pick up dry cleaning" → {"intentType":"create_todo","todoTitle":"pick up dry cleaning","todoType":"family","todoPriority":"medium","note":null,"date":null}
- "remind me to call the dentist" → {"intentType":"create_todo","todoTitle":"call the dentist","todoType":"personal","todoPriority":"medium","note":null,"date":null}
- "remind everyone to pay the water bill urgently" → {"intentType":"create_todo","todoTitle":"pay the water bill","todoType":"family","todoPriority":"high","note":null,"date":null}

Unknown examples:
- "买菜" → {"intentType":"unknown"}
- "hello" → {"intentType":"unknown"}

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

  const today = new Date();
  const todayStr = today.toISOString().split('T')[0];
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const tomorrowStr = tomorrow.toISOString().split('T')[0];

  const prompt = buildPrompt(transcript.trim(), children, todayStr, tomorrowStr);

  const llmResult = await callDoubao(prompt);
  console.log('[voice/parse] Doubao raw text:', llmResult.text, '| error:', llmResult.error);
  if (llmResult.error || !llmResult.text) {
    res.json(lowConfidence(`doubao_error:${llmResult.error ?? 'empty_text'}`));
    return;
  }

  let parsed: Record<string, unknown>;
  try {
    parsed = parseJson(llmResult.text);
    console.log('[voice/parse] parsed JSON:', JSON.stringify(parsed));
  } catch {
    res.json(lowConfidence(`json_parse_failed:${llmResult.text.slice(0, 120)}`));
    return;
  }

  const { intentType, note, date } = parsed;
  const safeNote = typeof note === 'string' && note.trim() ? note.trim() : null;

  // Unknown intent
  if (intentType === 'unknown' || !intentType) {
    res.json(lowConfidence('unknown_intent'));
    return;
  }

  // create_todo intent
  if (intentType === 'create_todo') {
    const { todoTitle, todoType, todoPriority } = parsed;
    const validTodoTypes = ['family', 'personal'];
    const validPriorities = ['high', 'medium', 'low'];
    if (
      typeof todoTitle !== 'string' || !todoTitle.trim() ||
      typeof todoType !== 'string' || !validTodoTypes.includes(todoType) ||
      typeof todoPriority !== 'string' || !validPriorities.includes(todoPriority)
    ) {
      res.json(lowConfidence(`todo_field_invalid:title=${JSON.stringify(todoTitle)},type=${JSON.stringify(todoType)},priority=${JSON.stringify(todoPriority)}`));
      return;
    }
    const safeDueDate = typeof date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(date) ? date : null;
    res.json({
      confidence: 'high',
      intentType: 'create_todo',
      memberId: null,
      memberName: null,
      delta: null,
      eventType: null,
      note: safeNote,
      date: safeDueDate,
      todoTitle: todoTitle.trim(),
      todoType,
      todoPriority,
    });
    return;
  }

  // points intent
  if (intentType === 'points') {
    if (children.length === 0) {
      res.json(lowConfidence('no_children'));
      return;
    }
    const { points, action, memberId: memberIdRaw } = parsed;
    const validActions = ['add', 'deduct', 'redeem'];
    if (
      typeof points !== 'number' || !Number.isInteger(points) || points < 1 || points > 9999 ||
      typeof action !== 'string' || !validActions.includes(action) ||
      typeof memberIdRaw !== 'number' || !Number.isInteger(memberIdRaw)
    ) {
      res.json(lowConfidence(`field_invalid:points=${JSON.stringify(points)},action=${JSON.stringify(action)},memberId=${JSON.stringify(memberIdRaw)}`));
      return;
    }
    const child = children.find(c => c.memberId === memberIdRaw);
    if (!child) {
      res.json(lowConfidence(`unknown_memberId:${memberIdRaw},known:${children.map(c => c.memberId).join(',')}`));
      return;
    }
    const safePointsDate = typeof date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(date) && date <= todayStr
      ? date : null;
    const delta = (action === 'add') ? (points as number) : -(points as number);
    res.json({
      confidence: 'high',
      intentType: 'points',
      memberId: child.memberId,
      memberName: child.name,
      delta,
      note: safeNote,
      date: safePointsDate,
      eventType: action,
      todoTitle: null,
      todoType: null,
      todoPriority: null,
    });
    return;
  }

  res.json(lowConfidence(`unrecognized_intent:${String(intentType)}`));
});

export default router;
