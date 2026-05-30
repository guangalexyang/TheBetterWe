const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash-lite:generateContent?key=${GEMINI_API_KEY}`;

if (!GEMINI_API_KEY) {
  console.error('[AI] GEMINI_API_KEY is not set — AI features will fail');
} else {
  console.log('[AI] Gemini key loaded:', GEMINI_API_KEY.slice(0, 8) + '...');
}

interface GeminiResult {
  text?: string;
  error?: string;
  quotaExceeded?: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function callGemini(prompt: string): Promise<GeminiResult> {
  const res = await fetch(GEMINI_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
  });
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const data = await res.json() as any;
  if (!res.ok) {
    console.error('[Gemini] HTTP', res.status, JSON.stringify(data));
    return { quotaExceeded: res.status === 429, error: data.error?.message ?? `HTTP ${res.status}` };
  }
  if (data.error) {
    console.error('[Gemini] API error', JSON.stringify(data.error));
    return { quotaExceeded: false, error: data.error.message };
  }
  const text: string = data.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
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
