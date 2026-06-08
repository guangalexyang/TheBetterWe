const API_KEY  = process.env.DOUBAO_API_KEY;
const MODEL_ID = process.env.DOUBAO_MODEL_ID ?? 'doubao-lite-4k';
const ENDPOINT = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';

if (!API_KEY) {
  console.error('[AI] DOUBAO_API_KEY not set — voice parsing will fail');
} else {
  console.log('[AI] Doubao key loaded:', API_KEY.slice(0, 8) + '...');
}

interface DoubaoResult {
  text?: string;
  error?: string;
}

export async function callDoubao(prompt: string): Promise<DoubaoResult> {
  if (!API_KEY) return { error: 'DOUBAO_API_KEY not configured' };

  let res: Response;
  try {
    res = await fetch(ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_KEY}`,
      },
      body: JSON.stringify({
        model: MODEL_ID,
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 150,
        temperature: 0,
      }),
      signal: AbortSignal.timeout(10_000),
    });
  } catch (e: any) {
    console.error('[Doubao] fetch error:', e.message);
    return { error: e.message };
  }

  const data = await res.json() as any;
  console.log('[Doubao] HTTP', res.status, 'raw body:', JSON.stringify(data));
  if (!res.ok) {
    return { error: data.error?.message ?? `HTTP ${res.status}` };
  }

  const text: string = data.choices?.[0]?.message?.content ?? '';
  return { text };
}

export function parseJson<T>(text: string): T {
  const cleaned = text
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/```\s*$/i, '')
    .trim();
  return JSON.parse(cleaned) as T;
}
