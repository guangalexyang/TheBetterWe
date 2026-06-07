import { WebSocket } from 'ws';
import { IncomingMessage } from 'http';
import jwt from 'jsonwebtoken';
import { gzipSync, gunzipSync } from 'zlib';
import { randomUUID } from 'crypto';

interface AuthPayload {
  sub: number;
  username: string;
}

const activeSessions = new Map<number, number>();
const MAX_SESSIONS_PER_USER = 2;
const MAX_SESSION_MS = 60_000;

// ---------------------------------------------------------------------------
// Volcengine binary protocol helpers
// Docs: wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async
//
// Each frame: [4-byte header][4-byte payload-size][payload]
// Full server response also has a 4-byte sequence before payload-size.
// Header byte layout:
//   [0]: version(4) | header_size(4)   — always 0x11 (v1, 4-byte header)
//   [1]: msg_type(4) | flags(4)
//   [2]: serialization(4) | compression(4)
//   [3]: reserved — always 0x00
//
// msg_type:  0x1=full_client  0x2=audio_only  0x9=full_server  0xF=error
// flags:     0x0=none  0x2=last_packet(client)  0x1=normal(server)  0x3=last(server)
// serial:    0x0=none  0x1=JSON
// compress:  0x0=none  0x1=gzip
// ---------------------------------------------------------------------------

function header(msgType: number, flags: number, serial: number, compress: number): Buffer {
  const h = Buffer.alloc(4);
  h[0] = 0x11; // version=1, header_size=1 (1×4=4 bytes)
  h[1] = (msgType << 4) | flags;
  h[2] = (serial << 4) | compress;
  h[3] = 0x00;
  return h;
}

function sizeOf(payload: Buffer): Buffer {
  const b = Buffer.alloc(4);
  b.writeUInt32BE(payload.length, 0);
  return b;
}

function fullClientRequest(): Buffer {
  const json = Buffer.from(
    JSON.stringify({
      user: { uid: 'thebetterwe-server' },
      audio: { format: 'pcm', rate: 16000, bits: 16, channel: 1 },
      request: { model_name: 'bigmodel', enable_itn: true, enable_punc: true },
    }),
    'utf8'
  );
  const payload = gzipSync(json);
  // msg_type=full_client(1), flags=none(0), serial=JSON(1), compress=gzip(1)
  return Buffer.concat([header(0x1, 0x0, 0x1, 0x1), sizeOf(payload), payload]);
}

function audioFrame(pcm: Buffer, isLast: boolean): Buffer {
  const payload = gzipSync(pcm);
  // msg_type=audio_only(2), flags=none(0) or last(2), serial=none(0), compress=gzip(1)
  return Buffer.concat([header(0x2, isLast ? 0x2 : 0x0, 0x0, 0x1), sizeOf(payload), payload]);
}

function parseResponse(data: Buffer): { text: string; isFinal: boolean } | null {
  if (data.length < 12) return null;
  const msgType = (data[1] >> 4) & 0xF;
  if (msgType !== 0x9) return null; // only handle full server response

  const serverFlags = data[1] & 0xF;
  const compress    = data[2] & 0xF;

  // Layout: [0-3] header | [4-7] sequence | [8-11] payload-size | [12+] payload
  const payloadSize = data.readUInt32BE(8);
  if (data.length < 12 + payloadSize) return null;

  let payload = data.slice(12, 12 + payloadSize);
  if (compress === 0x1) {
    try { payload = gunzipSync(payload); } catch { return null; }
  }

  let json: any;
  try { json = JSON.parse(payload.toString('utf8')); } catch { return null; }

  const text: string | undefined = json?.result?.text;
  if (!text) return null;

  // Server flags 0x3 = last packet (final result)
  return { text, isFinal: serverFlags === 0x3 };
}

// ---------------------------------------------------------------------------
// WebSocket upgrade handler
// ---------------------------------------------------------------------------

export function handleASRUpgrade(ws: WebSocket, req: IncomingMessage): void {
  // --- Auth ---
  const url    = new URL(req.url ?? '', 'http://localhost');
  const token  = url.searchParams.get('token');
  const secret = process.env.JWT_SECRET;

  if (!token || !secret) { ws.close(4001, 'unauthorized'); return; }

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
    activeSessions.set(userId, Math.max(0, (activeSessions.get(userId) ?? 1) - 1));
    clearTimeout(sessionTimeout);
  };

  // Hard cap: 60s per session to prevent runaway billing.
  const sessionTimeout = setTimeout(() => {
    ws.send(JSON.stringify({ type: 'error', message: 'session_timeout' }));
    ws.close(1000, 'session timeout');
  }, MAX_SESSION_MS);

  ws.on('close', cleanup);
  ws.on('error', cleanup);

  // --- Credential check ---
  const appId      = process.env.VOLCENGINE_ASR_APP_ID;
  const accessKey  = process.env.VOLCENGINE_ASR_TOKEN;
  const resourceId = process.env.VOLCENGINE_ASR_RESOURCE_ID ?? 'volc.bigasr.sauc.duration';

  if (!appId || !accessKey) {
    ws.send(JSON.stringify({ type: 'error', message: 'no_credentials' }));
    ws.close(1000, 'no credentials');
    return;
  }

  // --- Connect to Volcengine streaming ASR ---
  const connectId = randomUUID();
  const volcWs = new WebSocket(
    'wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async',
    {
      headers: {
        'X-Api-App-Key':    appId,
        'X-Api-Access-Key': accessKey,
        'X-Api-Resource-Id': resourceId,
        'X-Api-Request-Id': connectId,
        'X-Api-Connect-Id': connectId,
        'X-Api-Sequence':   '-1',
      },
    }
  );

  // If Volcengine doesn't respond in 5s, fall back to Apple on iOS.
  const volcConnectTimeout = setTimeout(() => {
    if (volcWs.readyState !== WebSocket.OPEN) {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'error', message: 'volcengine_timeout' }));
        ws.close(1000, 'volcengine timeout');
      }
      volcWs.terminate();
    }
  }, 5000);

  volcWs.on('open', () => {
    clearTimeout(volcConnectTimeout);
    // Tell iOS the relay is ready.
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'connected' }));
    }
    // Send audio config to Volcengine.
    volcWs.send(fullClientRequest());
  });

  volcWs.on('message', (data) => {
    if (!Buffer.isBuffer(data)) return;
    const result = parseResponse(data);
    if (!result || !result.text) return;

    if (ws.readyState === WebSocket.OPEN) {
      const type = result.isFinal ? 'final' : 'partial';
      ws.send(JSON.stringify({ type, text: result.text }));
    }
  });

  volcWs.on('error', (err) => {
    console.error('[ASR] Volcengine error:', err.message);
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'error', message: 'volcengine_error' }));
      ws.close(1000, 'volcengine error');
    }
  });

  volcWs.on('close', () => {
    if (ws.readyState === WebSocket.OPEN) ws.close(1000, 'volcengine closed');
  });

  // --- Forward PCM audio from iOS → Volcengine ---
  ws.on('message', (data) => {
    if (volcWs.readyState === WebSocket.OPEN) {
      volcWs.send(audioFrame(Buffer.isBuffer(data) ? data : Buffer.from(data as any), false));
    }
  });

  // When iOS disconnects (silence detected), send final packet so Volcengine returns last result.
  ws.on('close', () => {
    if (volcWs.readyState === WebSocket.OPEN) {
      volcWs.send(audioFrame(Buffer.alloc(0), true));
      setTimeout(() => volcWs.terminate(), 3000);
    }
  });
}
