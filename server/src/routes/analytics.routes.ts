import { Router, Request, Response } from 'express';
import { createHash, randomUUID } from 'crypto';
import { mkdir, appendFile } from 'fs/promises';
import path from 'path';

const router: Router = Router();

const analyticsDir = path.resolve(
  process.env.ANALYTICS_LOG_DIR || path.join(process.cwd(), 'storage', 'analytics')
);
const visitLogPath = path.join(analyticsDir, 'website-visits.jsonl');
const visitorDedupe = new Map<string, number>();
const dedupeWindowMs = 30 * 60 * 1000;

type VisitPayload = {
  visitorId?: unknown;
  path?: unknown;
  referrer?: unknown;
  language?: unknown;
  timezone?: unknown;
  screen?: unknown;
};

const asShortString = (value: unknown, maxLength: number): string | null => {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }

  return trimmed.slice(0, maxLength);
};

const getClientIp = (req: Request): string => {
  const forwardedFor = req.headers['x-forwarded-for'];
  if (typeof forwardedFor === 'string' && forwardedFor.trim()) {
    return forwardedFor.split(',')[0]?.trim() || 'unknown';
  }

  return req.ip || req.socket.remoteAddress || 'unknown';
};

const hashValue = (value: string): string => {
  const salt = process.env.ANALYTICS_HASH_SALT || 'ravehub-analytics';
  return createHash('sha256').update(`${salt}:${value}`).digest('hex');
};

const cleanupDedupe = (now: number): void => {
  if (visitorDedupe.size < 1000) {
    return;
  }

  for (const [key, expiresAt] of visitorDedupe) {
    if (expiresAt <= now) {
      visitorDedupe.delete(key);
    }
  }
};

router.post('/visit', async (req: Request, res: Response) => {
  try {
    const payload = (req.body || {}) as VisitPayload;
    const visitorId = asShortString(payload.visitorId, 80) || randomUUID();
    const visitPath = asShortString(payload.path, 300) || '/';
    const now = Date.now();
    const dedupeKey = `${visitorId}:${visitPath}`;
    const existingExpiry = visitorDedupe.get(dedupeKey);

    cleanupDedupe(now);

    if (existingExpiry && existingExpiry > now) {
      res.status(202).json({ ok: true, deduped: true });
      return;
    }

    visitorDedupe.set(dedupeKey, now + dedupeWindowMs);

    const record = {
      id: randomUUID(),
      createdAt: new Date(now).toISOString(),
      visitorIdHash: hashValue(visitorId),
      path: visitPath,
      referrer: asShortString(payload.referrer, 500),
      language: asShortString(payload.language, 80),
      timezone: asShortString(payload.timezone, 80),
      screen: typeof payload.screen === 'object' && payload.screen !== null ? payload.screen : null,
      ipHash: hashValue(getClientIp(req)),
      userAgent: asShortString(req.get('user-agent'), 500),
    };

    await mkdir(analyticsDir, { recursive: true });
    await appendFile(visitLogPath, `${JSON.stringify(record)}\n`, 'utf8');

    res.status(202).json({ ok: true });
  } catch (error) {
    console.error('Failed to record website visit', error);
    res.status(202).json({ ok: false });
  }
});

export default router;
