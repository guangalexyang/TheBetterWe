import { Router, Request, Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import db from '../db';
import { requireAuth } from '../middleware/auth';

const router = Router();

const BCRYPT_ROUNDS = 12;
const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL_DAYS = 30;

function jwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error('JWT_SECRET is not set');
  return secret;
}

function makeAccessToken(userId: number, username: string): string {
  return jwt.sign({ sub: userId, username }, jwtSecret(), { expiresIn: ACCESS_TOKEN_TTL });
}

function makeRefreshToken(): { raw: string; hash: string; expiresAt: number } {
  const raw = crypto.randomBytes(40).toString('hex');
  const hash = crypto.createHash('sha256').update(raw).digest('hex');
  const expiresAt = Math.floor(Date.now() / 1000) + REFRESH_TOKEN_TTL_DAYS * 86400;
  return { raw, hash, expiresAt };
}

function insertRefreshToken(userId: number, familyId: string, hash: string, expiresAt: number): void {
  db.prepare(
    'INSERT INTO refresh_tokens (user_id, family_id, token_hash, expires_at) VALUES (?, ?, ?, ?)'
  ).run(userId, familyId, hash, expiresAt);
}

// POST /auth/signup
router.post('/signup', async (req: Request, res: Response) => {
  const { username, password } = req.body as { username?: string; password?: string };

  if (!username || !password) {
    res.status(400).json({ error: 'username and password are required' });
    return;
  }

  const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
  if (existing) {
    res.status(409).json({ error: 'username already taken' });
    return;
  }

  const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
  const { lastInsertRowid } = db
    .prepare('INSERT INTO users (username, password_hash) VALUES (?, ?)')
    .run(username, passwordHash);

  const userId = Number(lastInsertRowid);
  const accessToken = makeAccessToken(userId, username);
  const refresh = makeRefreshToken();
  const familyId = crypto.randomUUID();

  insertRefreshToken(userId, familyId, refresh.hash, refresh.expiresAt);

  res.status(201).json({ accessToken, refreshToken: refresh.raw, displayName: '' });
});

// POST /auth/login
router.post('/login', async (req: Request, res: Response) => {
  const { username, password } = req.body as { username?: string; password?: string };

  if (!username || !password) {
    res.status(400).json({ error: 'username and password are required' });
    return;
  }

  const user = db
    .prepare('SELECT id, username, password_hash, display_name FROM users WHERE username = ?')
    .get(username) as { id: number; username: string; password_hash: string; display_name: string } | undefined;

  const match = user && (await bcrypt.compare(password, user.password_hash));
  if (!match) {
    res.status(401).json({ error: 'invalid credentials' });
    return;
  }

  const accessToken = makeAccessToken(user.id, user.username);
  const refresh = makeRefreshToken();
  const familyId = crypto.randomUUID();

  insertRefreshToken(user.id, familyId, refresh.hash, refresh.expiresAt);

  res.json({ accessToken, refreshToken: refresh.raw, displayName: user.display_name });
});

// PUT /auth/display-name
router.put('/display-name', requireAuth, (req: Request, res: Response) => {
  const { displayName } = req.body as { displayName?: string };

  if (!displayName || !displayName.trim()) {
    res.status(400).json({ error: 'displayName is required' });
    return;
  }

  db.prepare('UPDATE users SET display_name = ? WHERE id = ?').run(displayName.trim(), req.auth!.sub);
  res.json({ displayName: displayName.trim() });
});

// POST /auth/refresh
router.post('/refresh', (req: Request, res: Response) => {
  const { refreshToken } = req.body as { refreshToken?: string };

  if (!refreshToken) {
    res.status(400).json({ error: 'refreshToken is required' });
    return;
  }

  const hash = crypto.createHash('sha256').update(refreshToken).digest('hex');
  const now = Math.floor(Date.now() / 1000);

  const row = db
    .prepare(
      `SELECT rt.id, rt.user_id, rt.family_id, rt.used, rt.expires_at, u.username, u.display_name
       FROM refresh_tokens rt
       JOIN users u ON u.id = rt.user_id
       WHERE rt.token_hash = ?`
    )
    .get(hash) as {
      id: number; user_id: number; family_id: string;
      used: number; expires_at: number; username: string; display_name: string;
    } | undefined;

  if (!row) {
    res.status(401).json({ error: 'invalid refresh token' });
    return;
  }

  if (row.used) {
    db.prepare('DELETE FROM refresh_tokens WHERE family_id = ?').run(row.family_id);
    res.status(401).json({ error: 'refresh token reuse detected' });
    return;
  }

  if (row.expires_at <= now) {
    db.prepare('DELETE FROM refresh_tokens WHERE id = ?').run(row.id);
    res.status(401).json({ error: 'refresh token expired' });
    return;
  }

  db.prepare('UPDATE refresh_tokens SET used = 1 WHERE id = ?').run(row.id);

  const accessToken = makeAccessToken(row.user_id, row.username);
  const newRefresh = makeRefreshToken();

  insertRefreshToken(row.user_id, row.family_id, newRefresh.hash, newRefresh.expiresAt);

  res.json({ accessToken, refreshToken: newRefresh.raw, displayName: row.display_name });
});

// POST /auth/logout
router.post('/logout', (req: Request, res: Response) => {
  const { refreshToken } = req.body as { refreshToken?: string };

  if (refreshToken) {
    const hash = crypto.createHash('sha256').update(refreshToken).digest('hex');
    const row = db
      .prepare('SELECT family_id FROM refresh_tokens WHERE token_hash = ?')
      .get(hash) as { family_id: string } | undefined;

    if (row) {
      db.prepare('DELETE FROM refresh_tokens WHERE family_id = ?').run(row.family_id);
    }
  }

  res.status(204).send();
});

export default router;
