import { WebSocket } from 'ws';
import { IncomingMessage } from 'http';
import jwt from 'jsonwebtoken';

interface AuthPayload {
  sub: number;
  username: string;
}

// Tracks active session counts per user for rate limiting.
// Keys are user IDs; values are counts of open sessions.
const activeSessions = new Map<number, number>();
const MAX_SESSIONS_PER_USER = 2;
const MAX_SESSION_MS = 60_000;

export function handleASRUpgrade(ws: WebSocket, req: IncomingMessage): void {
  // --- Auth ---
  const url = new URL(req.url ?? '', 'http://localhost');
  const token = url.searchParams.get('token');
  const secret = process.env.JWT_SECRET;

  if (!token || !secret) {
    ws.close(4001, 'unauthorized');
    return;
  }

  let auth: AuthPayload;
  try {
    auth = jwt.verify(token, secret) as unknown as AuthPayload;
  } catch {
    ws.close(4001, 'unauthorized');
    return;
  }

  // --- Rate limit ---
  const userId = auth.sub;
  const currentSessions = activeSessions.get(userId) ?? 0;
  if (currentSessions >= MAX_SESSIONS_PER_USER) {
    ws.send(JSON.stringify({ type: 'error', message: 'rate_limited' }));
    ws.close(4029, 'too many sessions');
    return;
  }

  activeSessions.set(userId, currentSessions + 1);

  const cleanup = () => {
    const n = activeSessions.get(userId) ?? 1;
    activeSessions.set(userId, Math.max(0, n - 1));
    clearTimeout(sessionTimeout);
  };

  // --- Session timeout (60s hard cap to prevent runaway billing) ---
  const sessionTimeout = setTimeout(() => {
    ws.send(JSON.stringify({ type: 'error', message: 'session_timeout' }));
    ws.close(1000, 'session timeout');
  }, MAX_SESSION_MS);

  ws.on('close', cleanup);
  ws.on('error', cleanup);

  // --- Volcengine credential check ---
  const hasCredentials = !!(
    process.env.VOLCENGINE_ASR_APP_ID && process.env.VOLCENGINE_ASR_TOKEN
  );

  if (!hasCredentials) {
    // No credentials yet — tell iOS to fall back to Apple ASR immediately.
    ws.send(JSON.stringify({ type: 'error', message: 'no_credentials' }));
    ws.close(1000, 'no credentials');
    return;
  }

  // --- Volcengine relay (active once credentials are set via fly secrets) ---
  // TODO: replace this section with Volcengine WebSocket relay when credentials are available.
  // Shape:
  //   1. Open WebSocket to Volcengine streaming ASR endpoint using VOLCENGINE_ASR_APP_ID + VOLCENGINE_ASR_TOKEN
  //   2. Send connected acknowledgment to iOS: ws.send(JSON.stringify({ type: 'connected' }))
  //   3. On binary message from iOS: forward to Volcengine socket
  //   4. On JSON result from Volcengine: forward { type: 'partial'|'final', text } to iOS
  //   5. On either socket closing: close the other
  ws.send(JSON.stringify({ type: 'error', message: 'not_implemented' }));
  ws.close(1000, 'not implemented');
}
