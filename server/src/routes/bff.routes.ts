import { Router, Request, Response, NextFunction, type CookieOptions } from 'express';
import { Prisma, PrismaClient } from '@prisma/client';
import OSS from 'ali-oss';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import crypto from 'crypto';
import {
  ACCESS_TOKEN_TTL_SECONDS,
  REFRESH_TOKEN_TTL_MS,
  comparePassword,
  generateRefreshToken,
  generateToken,
  hashPassword,
  hashToken,
  isTokenHashMatch,
  verifyToken,
  type JWTPayload,
} from '../utils/auth';
import { tencentIMGroupService } from '../services/tencent-im/tencent-im-group.service';
import { tencentIMUserService } from '../services/tencent-im/tencent-im-user.service';
import { smsService } from '../services/sms/sms-provider';
import { notificationCenterService } from '../services/notification-center';

const router: Router = Router();
const prisma = new PrismaClient();
const avatarUploadDir = path.join(process.cwd(), 'uploads', 'avatars');
if (!fs.existsSync(avatarUploadDir)) {
  fs.mkdirSync(avatarUploadDir, { recursive: true });
}

const avatarStorage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, avatarUploadDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const safeExt = ext && ext.length <= 8 ? ext : '.jpg';
    cb(null, `${Date.now()}-${Math.random().toString(36).slice(2, 10)}${safeExt}`);
  },
});

const avatarUpload = multer({
  storage: avatarStorage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith('image/')) {
      cb(new Error('Only image files are allowed'));
      return;
    }
    cb(null, true);
  },
});

const cleanEnv = (value: string | undefined): string | null => {
  if (!value) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const ossRegion = cleanEnv(process.env.OSS_REGION);
const ossAccessKeyId = cleanEnv(process.env.OSS_ACCESS_KEY_ID);
const ossAccessKeySecret = cleanEnv(process.env.OSS_ACCESS_KEY_SECRET);
const ossBucket = cleanEnv(process.env.OSS_BUCKET);
const ossEndpoint = cleanEnv(process.env.OSS_ENDPOINT);
const ossPostsPrefix = (cleanEnv(process.env.OSS_POSTS_PREFIX) || 'posts').replace(/^\/+|\/+$/g, '');

const postMediaOssClient =
  ossRegion && ossAccessKeyId && ossAccessKeySecret && ossBucket
    ? new OSS({
        region: ossRegion,
        accessKeyId: ossAccessKeyId,
        accessKeySecret: ossAccessKeySecret,
        bucket: ossBucket,
        endpoint: ossEndpoint || undefined,
      })
    : null;

const extractPostMediaOssKey = (raw: string): string | null => {
  const value = raw.trim();
  if (!value) return null;

  const normalizedPrefix = `${ossPostsPrefix}/`;
  if (value.startsWith('/')) {
    const relative = value.replace(/^\/+/, '');
    return relative.startsWith(normalizedPrefix) ? relative : null;
  }

  if (value.startsWith('http://') || value.startsWith('https://')) {
    try {
      const url = new URL(value);
      const pathname = decodeURIComponent(url.pathname || '').replace(/^\/+/, '');
      if (!pathname.startsWith(normalizedPrefix)) {
        return null;
      }
      if (!ossBucket) {
        return null;
      }
      const host = url.hostname.toLowerCase();
      const expectedBucket = ossBucket.toLowerCase();
      if (host === expectedBucket || host.startsWith(`${expectedBucket}.`)) {
        return pathname;
      }
      return null;
    } catch {
      return null;
    }
  }

  return value.startsWith(normalizedPrefix) ? value : null;
};

const deletePostMediaFromOss = async (imageUrls: string[]): Promise<{ deletedKeys: string[]; failedKeys: string[] }> => {
  if (!postMediaOssClient || imageUrls.length === 0) {
    return { deletedKeys: [], failedKeys: [] };
  }

  const uniqueKeys = Array.from(
    new Set(
      imageUrls
        .map((item) => extractPostMediaOssKey(item))
        .filter((item): item is string => Boolean(item))
    )
  );

  if (uniqueKeys.length === 0) {
    return { deletedKeys: [], failedKeys: [] };
  }

  const results = await Promise.allSettled(uniqueKeys.map((key) => postMediaOssClient.delete(key)));
  const deletedKeys: string[] = [];
  const failedKeys: string[] = [];
  results.forEach((result, index) => {
    const key = uniqueKeys[index];
    if (result.status === 'fulfilled') {
      deletedKeys.push(key);
    } else {
      failedKeys.push(key);
    }
  });
  return { deletedKeys, failedKeys };
};

interface BFFAuthRequest extends Request {
  user?: JWTPayload;
}

const optionalAuth = (req: Request, _res: Response, next: NextFunction): void => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    next();
    return;
  }

  const token = authHeader.substring(7);
  try {
    const decoded = verifyToken(token);
    (req as BFFAuthRequest).user = decoded;
  } catch (_error) {
    // Ignore invalid token for public endpoints.
  }

  next();
};

const requireAuth = (req: BFFAuthRequest, res: Response): string | null => {
  const userId = req.user?.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
  return userId;
};

const syncTencentIMUserBestEffort = async (userId: string, reason: string): Promise<void> => {
  try {
    await tencentIMUserService.ensureUsersByIds([userId]);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`[tencent-im] user sync skipped during ${reason}: ${message}`, { userId });
  }
};

const authRefreshCookieName = cleanEnv(process.env.AUTH_REFRESH_COOKIE_NAME) || 'raver_refresh_token';
const authRefreshCookieDomain = cleanEnv(process.env.AUTH_COOKIE_DOMAIN);
const authRefreshCookiePath = cleanEnv(process.env.AUTH_REFRESH_COOKIE_PATH) || '/v1/auth';
const authCookieSecureOverride = cleanEnv(process.env.AUTH_COOKIE_SECURE);

const normalizePositiveInt = (
  value: string | undefined,
  fallback: number,
  min: number,
  max: number
): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  const rounded = Math.floor(parsed);
  if (!Number.isFinite(rounded)) return fallback;
  return Math.max(min, Math.min(max, rounded));
};

const authSmsCodeLength = normalizePositiveInt(process.env.AUTH_SMS_CODE_LENGTH, 6, 4, 8);
const authSmsCodeTtlMs = normalizePositiveInt(process.env.AUTH_SMS_CODE_TTL_MS, 5 * 60 * 1000, 10_000, 30 * 60 * 1000);
const authSmsSendCooldownMs = normalizePositiveInt(process.env.AUTH_SMS_SEND_COOLDOWN_MS, 60 * 1000, 5_000, 10 * 60 * 1000);
const authSmsPhoneHourlyLimit = normalizePositiveInt(process.env.AUTH_SMS_PHONE_HOURLY_LIMIT, 5, 1, 100);
const authSmsIpHourlyLimit = normalizePositiveInt(process.env.AUTH_SMS_IP_HOURLY_LIMIT, 30, 1, 1_000);
const authSmsVerifyFailureLimit = normalizePositiveInt(process.env.AUTH_SMS_VERIFY_FAILURE_LIMIT, 10, 3, 100);
const authSmsVerifyBlockMs = normalizePositiveInt(process.env.AUTH_SMS_VERIFY_BLOCK_MS, 15 * 60 * 1000, 30_000, 24 * 60 * 60 * 1000);
const authSmsProviderMode = (cleanEnv(process.env.AUTH_SMS_PROVIDER) || 'mock').toLowerCase();
const authSmsDebugReturnCodeRaw = cleanEnv(process.env.AUTH_SMS_DEBUG_RETURN_CODE);
const authSmsDebugPhoneAllowlistRaw = cleanEnv(process.env.AUTH_SMS_DEBUG_PHONE_ALLOWLIST);
const authLoginRateLimitWindowMs = normalizePositiveInt(
  process.env.AUTH_LOGIN_RATE_LIMIT_WINDOW_MS,
  15 * 60 * 1000,
  10_000,
  24 * 60 * 60 * 1000
);
const authLoginRateLimitMaxAttempts = normalizePositiveInt(
  process.env.AUTH_LOGIN_RATE_LIMIT_MAX_ATTEMPTS,
  10,
  1,
  500
);
const authRegisterRateLimitWindowMs = normalizePositiveInt(
  process.env.AUTH_REGISTER_RATE_LIMIT_WINDOW_MS,
  60 * 60 * 1000,
  10_000,
  24 * 60 * 60 * 1000
);
const authRegisterRateLimitMaxAttempts = normalizePositiveInt(
  process.env.AUTH_REGISTER_RATE_LIMIT_MAX_ATTEMPTS,
  10,
  1,
  500
);

type RateLimitBucket = {
  count: number;
  windowStartMs: number;
};

const authLoginRateBuckets = new Map<string, RateLimitBucket>();
const authRegisterRateBuckets = new Map<string, RateLimitBucket>();
const authRateBucketMaxSize = 20_000;

const buildRateKey = (ip: string, identifier: string): string => {
  const normalizedIdentifier = identifier.trim().toLowerCase().slice(0, 128) || 'unknown';
  return `${ip}::${normalizedIdentifier}`;
};

const pruneRateBuckets = (store: Map<string, RateLimitBucket>, windowMs: number, nowMs: number): void => {
  if (store.size <= authRateBucketMaxSize) return;
  for (const [key, bucket] of store.entries()) {
    if (nowMs - bucket.windowStartMs >= windowMs) {
      store.delete(key);
    }
  }
};

const checkRateLimit = (
  store: Map<string, RateLimitBucket>,
  key: string,
  maxAttempts: number,
  windowMs: number,
  nowMs: number
): { limited: boolean; retryAfterSeconds: number } => {
  const bucket = store.get(key);
  if (!bucket) {
    return { limited: false, retryAfterSeconds: 0 };
  }
  if (nowMs - bucket.windowStartMs >= windowMs) {
    store.delete(key);
    return { limited: false, retryAfterSeconds: 0 };
  }
  if (bucket.count >= maxAttempts) {
    const retryAfterMs = Math.max(0, windowMs - (nowMs - bucket.windowStartMs));
    return { limited: true, retryAfterSeconds: Math.max(1, Math.ceil(retryAfterMs / 1000)) };
  }
  return { limited: false, retryAfterSeconds: 0 };
};

const registerRateAttempt = (
  store: Map<string, RateLimitBucket>,
  key: string,
  windowMs: number,
  nowMs: number
): void => {
  pruneRateBuckets(store, windowMs, nowMs);
  const bucket = store.get(key);
  if (!bucket || nowMs - bucket.windowStartMs >= windowMs) {
    store.set(key, { count: 1, windowStartMs: nowMs });
    return;
  }
  bucket.count += 1;
  store.set(key, bucket);
};

const clearRateBucket = (store: Map<string, RateLimitBucket>, key: string): void => {
  store.delete(key);
};

type AuthAuditOutcome = 'success' | 'failed' | 'blocked';

const maskIdentifier = (value: string): string => {
  const trimmed = value.trim();
  if (!trimmed) return 'unknown';
  if (trimmed.length <= 3) return '***';
  return `${trimmed.slice(0, 2)}***${trimmed.slice(-2)}`;
};

const writeAuthAuditLog = (
  req: Request,
  payload: {
    action: string;
    outcome: AuthAuditOutcome;
    userId?: string | null;
    identifier?: string | null;
    errorCode?: string | null;
    detail?: Record<string, unknown>;
  }
): void => {
  const traceId =
    (typeof req.headers['x-request-id'] === 'string' && req.headers['x-request-id']) ||
    (typeof req.headers['x-correlation-id'] === 'string' && req.headers['x-correlation-id']) ||
    null;
  console.info('[auth-audit]', {
    traceId,
    action: payload.action,
    outcome: payload.outcome,
    userId: payload.userId || null,
    identifier: payload.identifier ? maskIdentifier(payload.identifier) : null,
    errorCode: payload.errorCode || null,
    ip: getClientIp(req),
    userAgent: req.headers['user-agent'] || null,
    ...(payload.detail || {}),
  });
};

const parseBool = (value: string | null | undefined, fallback: boolean): boolean => {
  if (!value) return fallback;
  const normalized = value.trim().toLowerCase();
  if (normalized === 'true' || normalized === '1' || normalized === 'yes') return true;
  if (normalized === 'false' || normalized === '0' || normalized === 'no') return false;
  return fallback;
};

const getClientIp = (req: Request): string => {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.trim()) {
    const first = forwarded.split(',')[0].trim();
    if (first) return first;
  }
  if (Array.isArray(forwarded) && forwarded.length > 0 && forwarded[0].trim()) {
    return forwarded[0].trim();
  }
  return req.socket.remoteAddress || 'unknown';
};

const normalizePhoneNumber = (value: unknown): string | null => {
  const raw = String(value || '').trim();
  if (!raw) return null;
  const normalized = raw.replace(/[\s()-]/g, '');
  if (!/^\+?\d{8,20}$/.test(normalized)) return null;
  return normalized.startsWith('+') ? normalized : `+${normalized}`;
};

const isSmsDebugCodeEnabledForPhone = (phoneNumber: string): boolean => {
  if (process.env.NODE_ENV === 'production') return false;
  if (authSmsProviderMode !== 'mock') return false;
  if (!parseBool(authSmsDebugReturnCodeRaw, false)) return false;

  const allowlist = (authSmsDebugPhoneAllowlistRaw || '')
    .split(',')
    .map((item) => normalizePhoneNumber(item))
    .filter((item): item is string => Boolean(item));

  if (allowlist.length === 0) return true;
  return allowlist.includes(phoneNumber);
};

const normalizeSmsCode = (value: unknown): string | null => {
  const code = String(value || '').trim();
  if (!/^\d{4,8}$/.test(code)) return null;
  return code;
};

const generateSmsCode = (): string => {
  const max = 10 ** Math.max(4, Math.min(8, authSmsCodeLength));
  return crypto.randomInt(0, max).toString().padStart(Math.max(4, Math.min(8, authSmsCodeLength)), '0');
};

const getCookieValue = (req: Request, key: string): string | null => {
  const cookieHeader = req.headers.cookie;
  if (!cookieHeader) return null;

  const cookies = cookieHeader.split(';');
  for (const cookie of cookies) {
    const [rawKey, ...rawValue] = cookie.split('=');
    if (!rawKey || rawValue.length === 0) continue;
    if (rawKey.trim() !== key) continue;
    return decodeURIComponent(rawValue.join('=').trim());
  }
  return null;
};

const extractRefreshToken = (req: Request): string | null => {
  const bodyToken = (req.body as { refreshToken?: unknown } | undefined)?.refreshToken;
  if (typeof bodyToken === 'string' && bodyToken.trim()) {
    return bodyToken.trim();
  }
  return getCookieValue(req, authRefreshCookieName);
};

const refreshCookieOptions = (): CookieOptions => {
  const secureFallback = process.env.NODE_ENV === 'production';
  const secure = parseBool(authCookieSecureOverride, secureFallback);
  const options: CookieOptions = {
    httpOnly: true,
    sameSite: 'lax',
    secure,
    path: authRefreshCookiePath,
    maxAge: REFRESH_TOKEN_TTL_MS,
  };
  if (authRefreshCookieDomain) {
    options.domain = authRefreshCookieDomain;
  }
  return options;
};

const setRefreshCookie = (res: Response, refreshToken: string): void => {
  res.cookie(authRefreshCookieName, refreshToken, refreshCookieOptions());
};

const clearRefreshCookie = (res: Response): void => {
  const options = refreshCookieOptions();
  res.clearCookie(authRefreshCookieName, {
    ...options,
    maxAge: 0,
  });
};

type AuthUserRecord = {
  id: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
  email: string;
  role: string;
};

const createAccessTokenForUser = (user: Pick<AuthUserRecord, 'id' | 'email' | 'role'>): string => {
  return generateToken({
    userId: user.id,
    email: user.email,
    role: user.role,
  });
};

const createRefreshSessionForUser = async (
  userId: string,
  req: Request
): Promise<{ refreshToken: string; refreshTokenId: string }> => {
  const refreshToken = generateRefreshToken();
  const tokenHashValue = hashToken(refreshToken);
  const expiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_MS);
  const created = await prisma.authRefreshToken.create({
    data: {
      userId,
      tokenHash: tokenHashValue,
      userAgent: req.headers['user-agent'] || null,
      ipAddress: getClientIp(req),
      expiresAt,
    },
    select: { id: true },
  });

  return {
    refreshToken,
    refreshTokenId: created.id,
  };
};

const issueAuthSuccessResponse = async (
  req: Request,
  res: Response,
  user: AuthUserRecord
): Promise<void> => {
  const accessToken = createAccessTokenForUser(user);
  const refreshSession = await createRefreshSessionForUser(user.id, req);
  setRefreshCookie(res, refreshSession.refreshToken);

  res.json({
    token: accessToken,
    accessToken,
    accessTokenExpiresIn: ACCESS_TOKEN_TTL_SECONDS,
    refreshToken: refreshSession.refreshToken,
    refreshTokenId: refreshSession.refreshTokenId,
    user: toUserSummary(
      {
        id: user.id,
        username: user.username,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
      },
      false
    ),
  });
};

const revokeRefreshTokenByRawToken = async (rawToken: string, revokedAt: Date): Promise<number> => {
  const tokenHashValue = hashToken(rawToken);
  const result = await prisma.authRefreshToken.updateMany({
    where: {
      tokenHash: tokenHashValue,
      revokedAt: null,
    },
    data: {
      revokedAt,
      lastUsedAt: revokedAt,
    },
  });
  return result.count;
};

const registerSmsVerifyFailure = async (phoneNumber: string, now: Date): Promise<{ blockedUntil: Date | null }> => {
  const existing = await prisma.authPhoneAuthState.findUnique({
    where: { phoneNumber },
    select: { failedAttempts: true, blockedUntil: true },
  });

  const previousFailures = existing?.failedAttempts || 0;
  const nextFailures = previousFailures + 1;
  const blockedUntil = nextFailures >= authSmsVerifyFailureLimit
    ? new Date(now.getTime() + authSmsVerifyBlockMs)
    : existing?.blockedUntil || null;

  await prisma.authPhoneAuthState.upsert({
    where: { phoneNumber },
    create: {
      phoneNumber,
      failedAttempts: nextFailures,
      blockedUntil,
      lastFailedAt: now,
    },
    update: {
      failedAttempts: nextFailures,
      blockedUntil,
      lastFailedAt: now,
    },
  });

  return { blockedUntil };
};

const clearSmsVerifyFailures = async (phoneNumber: string): Promise<void> => {
  await prisma.authPhoneAuthState.upsert({
    where: { phoneNumber },
    create: {
      phoneNumber,
      failedAttempts: 0,
      blockedUntil: null,
      lastFailedAt: null,
    },
    update: {
      failedAttempts: 0,
      blockedUntil: null,
      lastFailedAt: null,
    },
  });
};

const generatePhoneBootstrapIdentity = async (phoneNumber: string): Promise<{
  username: string;
  email: string;
  displayName: string;
}> => {
  const digits = phoneNumber.replace(/\D/g, '');
  const suffix = digits.slice(-6) || String(Date.now()).slice(-6);

  for (let attempt = 0; attempt < 8; attempt += 1) {
    const randomSuffix = crypto.randomInt(1000, 9999).toString();
    const username = `phone_${suffix}_${randomSuffix}`;
    const exists = await prisma.user.findUnique({
      where: { username },
      select: { id: true },
    });
    if (exists) {
      continue;
    }
    return {
      username,
      email: `${username}@phone.raver.local`,
      displayName: `Raver ${suffix}`,
    };
  }

  const fallback = `phone_${suffix}_${Date.now()}`;
  return {
    username: fallback,
    email: `${fallback}@phone.raver.local`,
    displayName: `Raver ${suffix}`,
  };
};

const normalizeLimit = (value: unknown, fallback = 20, max = 50): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.min(max, Math.floor(parsed)));
};

const parseCursorDate = (cursor: unknown): Date | null => {
  if (typeof cursor !== 'string' || !cursor.trim()) return null;
  const date = new Date(cursor);
  return Number.isNaN(date.getTime()) ? null : date;
};

type FeedMode = 'recommended' | 'following' | 'latest';
type FeedEventType =
  | 'feed_impression'
  | 'feed_open_post'
  | 'feed_like'
  | 'feed_save'
  | 'feed_share'
  | 'feed_hide';
type FeedRecallSource = 'trending' | 'followed_author' | 'followed_dj' | 'behavior_similar';
type FeedExperimentBucket = 'control' | 'engagement_heavy' | 'freshness_heavy';
type FeedRankingWeights = {
  freshnessBase: number;
  freshnessHalfLifeHours: number;
  likeWeight: number;
  commentWeight: number;
  repostWeight: number;
  saveWeight: number;
  shareWeight: number;
  recallFollowedAuthorWeight: number;
  recallFollowedDjWeight: number;
  recallBehaviorSimilarWeight: number;
  recallTrendingWeight: number;
  followedDjBonus: number;
  followingAuthorBonus: number;
  mutedAuthorPenalty: number;
  globalHidePenalty: number;
  seenTooOftenPenaltyFactor: number;
  seenTooOftenPenaltyMax: number;
  exposureLimit: number;
  exploreMinFreshness: number;
};

const feedExperimentBucketSet = new Set<FeedExperimentBucket>([
  'control',
  'engagement_heavy',
  'freshness_heavy',
]);

const FEED_RANKING_WEIGHTS_VERSION = 'feed-rank-v2-ab';
const FEED_AB_ENABLED = parseBool(process.env.FEED_AB_ENABLED, true);
const FEED_AB_CONTROL_PERCENT = normalizePositiveInt(process.env.FEED_AB_CONTROL_PERCENT, 40, 1, 100);
const FEED_AB_ENGAGEMENT_PERCENT = normalizePositiveInt(process.env.FEED_AB_ENGAGEMENT_PERCENT, 30, 0, 100);
const FEED_AB_FRESHNESS_PERCENT = Math.max(
  0,
  Math.min(100, 100 - FEED_AB_CONTROL_PERCENT - FEED_AB_ENGAGEMENT_PERCENT)
);

const FEED_RANKING_BASE_WEIGHTS: FeedRankingWeights = {
  freshnessBase: 80,
  freshnessHalfLifeHours: 20,
  likeWeight: 1,
  commentWeight: 1.8,
  repostWeight: 2.2,
  saveWeight: 2.4,
  shareWeight: 2,
  recallFollowedAuthorWeight: 24,
  recallFollowedDjWeight: 30,
  recallBehaviorSimilarWeight: 28,
  recallTrendingWeight: 6,
  followedDjBonus: 40,
  followingAuthorBonus: 35,
  mutedAuthorPenalty: 120,
  globalHidePenalty: 0.8,
  seenTooOftenPenaltyFactor: 0.5,
  seenTooOftenPenaltyMax: 8,
  exposureLimit: 2,
  exploreMinFreshness: 40,
};

const buildFeedRankingWeights = (bucket: FeedExperimentBucket): FeedRankingWeights => {
  const base = FEED_RANKING_BASE_WEIGHTS;
  if (bucket === 'engagement_heavy') {
    return {
      ...base,
      freshnessBase: base.freshnessBase * 0.78,
      likeWeight: base.likeWeight * 1.35,
      commentWeight: base.commentWeight * 1.35,
      repostWeight: base.repostWeight * 1.3,
      saveWeight: base.saveWeight * 1.3,
      shareWeight: base.shareWeight * 1.3,
      recallBehaviorSimilarWeight: base.recallBehaviorSimilarWeight * 1.12,
    };
  }
  if (bucket === 'freshness_heavy') {
    return {
      ...base,
      freshnessBase: base.freshnessBase * 1.28,
      freshnessHalfLifeHours: base.freshnessHalfLifeHours * 0.8,
      likeWeight: base.likeWeight * 0.85,
      commentWeight: base.commentWeight * 0.88,
      repostWeight: base.repostWeight * 0.85,
      saveWeight: base.saveWeight * 0.88,
      shareWeight: base.shareWeight * 0.88,
      recallTrendingWeight: base.recallTrendingWeight * 1.4,
      exploreMinFreshness: 48,
    };
  }
  return base;
};

const normalizeFeedExperimentBucket = (value: unknown): FeedExperimentBucket | null | 'invalid' => {
  if (value === null || value === undefined) return null;
  const normalized = String(value || '')
    .trim()
    .toLowerCase();
  if (!normalized) return null;
  return feedExperimentBucketSet.has(normalized as FeedExperimentBucket)
    ? (normalized as FeedExperimentBucket)
    : 'invalid';
};

const stableBucketPercentFromSeed = (seed: string): number => {
  const hash = crypto.createHash('sha256').update(seed).digest();
  const value = hash.readUInt32BE(0);
  return value % 100;
};

const resolveFeedExperimentBucket = (req: Request, viewerId: string | undefined): FeedExperimentBucket => {
  const override = normalizeFeedExperimentBucket((req.query.expBucket ?? req.query.experimentBucket) as unknown);
  if (override && override !== 'invalid') {
    return override;
  }

  if (!FEED_AB_ENABLED || !viewerId) {
    return 'control';
  }

  const bucketValue = stableBucketPercentFromSeed(`feed-ab:${viewerId}`);
  if (bucketValue < FEED_AB_CONTROL_PERCENT) return 'control';
  if (bucketValue < FEED_AB_CONTROL_PERCENT + FEED_AB_ENGAGEMENT_PERCENT) return 'engagement_heavy';
  if (bucketValue < FEED_AB_CONTROL_PERCENT + FEED_AB_ENGAGEMENT_PERCENT + FEED_AB_FRESHNESS_PERCENT) {
    return 'freshness_heavy';
  }
  return 'freshness_heavy';
};

const feedEventTypeSet = new Set<FeedEventType>([
  'feed_impression',
  'feed_open_post',
  'feed_like',
  'feed_save',
  'feed_share',
  'feed_hide',
]);

const normalizeFeedMode = (value: unknown): FeedMode => {
  const normalized = String(value || '')
    .trim()
    .toLowerCase();
  if (normalized === 'following') return 'following';
  if (normalized === 'latest') return 'latest';
  return 'recommended';
};

const normalizeOptionalFeedMode = (value: unknown): FeedMode | null | 'invalid' => {
  if (value === null || value === undefined) return null;
  const normalized = String(value || '')
    .trim()
    .toLowerCase();
  if (!normalized) return null;
  if (normalized === 'recommended') return 'recommended';
  if (normalized === 'following') return 'following';
  if (normalized === 'latest') return 'latest';
  return 'invalid';
};

const normalizeFeedEventSessionID = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  if (!normalized) return null;
  return normalized.slice(0, 128);
};

const normalizeFeedEventType = (value: unknown): FeedEventType | null => {
  const normalized = typeof value === 'string' ? value.trim().toLowerCase() : '';
  return feedEventTypeSet.has(normalized as FeedEventType) ? (normalized as FeedEventType) : null;
};

const normalizeFeedEventPosition = (value: unknown): number | null | 'invalid' => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return 'invalid';
  const rounded = Math.floor(parsed);
  if (rounded < 0 || rounded > 10_000) return 'invalid';
  return rounded;
};

const normalizeFeedEventMetadata = (value: unknown): Prisma.InputJsonValue | null | 'invalid' => {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'object') return 'invalid';
  try {
    const serialized = JSON.stringify(value);
    if (!serialized) return null;
    if (serialized.length > 8_000) return 'invalid';
    return JSON.parse(serialized) as Prisma.InputJsonValue;
  } catch {
    return 'invalid';
  }
};

const parseFeedPostDateInput = (value: unknown): Date | null | 'invalid' => {
  if (value === null || value === undefined) return null;
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? 'invalid' : value;
  }
  const text = String(value || '').trim();
  if (!text) return null;
  const parsed = new Date(text);
  if (Number.isNaN(parsed.getTime())) return 'invalid';
  return parsed;
};

type BasicUser = {
  id: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
};

const toUserSummary = (user: BasicUser, isFollowing: boolean) => {
  return {
    id: user.id,
    username: user.username,
    displayName: user.displayName || user.username,
    avatarURL: user.avatarUrl,
    isFollowing,
  };
};

const toUserSummaryWithNickname = (
  user: BasicUser,
  isFollowing: boolean,
  nickname?: string | null
) => {
  const summary = toUserSummary(user, isFollowing);
  const normalizedNickname = typeof nickname === 'string' ? nickname.trim() : '';
  if (normalizedNickname) {
    summary.displayName = normalizedNickname;
  }
  return summary;
};

const canManageSquad = (role: string | null | undefined): boolean => {
  return role === 'leader' || role === 'admin';
};

const canRemoveSquadMember = (operatorRole: string | null | undefined, targetRole: string | null | undefined): boolean => {
  if (operatorRole === 'leader') {
    return targetRole === 'admin' || targetRole === 'member';
  }
  if (operatorRole === 'admin') {
    return targetRole === 'member';
  }
  return false;
};

const syncSquadGroupInfo = async (squadId: string): Promise<void> => {
  const squad = await prisma.squad.findUnique({
    where: { id: squadId },
    select: {
      id: true,
      name: true,
      description: true,
      avatarUrl: true,
      bannerUrl: true,
      notice: true,
      qrCodeUrl: true,
      isPublic: true,
    },
  });

  if (!squad) {
    throw new Error('Squad not found during Tencent IM profile sync');
  }

  await tencentIMGroupService.ensureSquadGroupById(squad.id);
};

const MIN_SQUAD_INITIAL_MEMBERS = 3;
const MIN_SQUAD_INVITED_MEMBERS = MIN_SQUAD_INITIAL_MEMBERS - 1;

const buildFollowingMap = async (viewerId: string | undefined, targetUserIds: string[]) => {
  if (!viewerId || targetUserIds.length === 0) {
    return new Set<string>();
  }

  const follows = await prisma.follow.findMany({
    where: {
      followerId: viewerId,
      type: 'user',
      followingId: { in: targetUserIds },
    },
    select: { followingId: true },
  });

  return new Set(follows.map((f) => f.followingId).filter((id): id is string => Boolean(id)));
};

const buildFriendUserIds = async (userId: string, candidateUserIds?: string[]) => {
  const outgoing = await prisma.follow.findMany({
    where: {
      followerId: userId,
      type: 'user',
      ...(candidateUserIds
        ? {
            followingId: {
              in: candidateUserIds,
            },
          }
        : {
            followingId: {
              not: null,
            },
          }),
    },
    select: { followingId: true },
  });

  const outgoingIds = outgoing
    .map((row) => row.followingId)
    .filter((id): id is string => Boolean(id));
  if (outgoingIds.length === 0) {
    return new Set<string>();
  }

  const incoming = await prisma.follow.findMany({
    where: {
      followerId: {
        in: outgoingIds,
      },
      followingId: userId,
      type: 'user',
    },
    select: { followerId: true },
  });

  return new Set(incoming.map((row) => row.followerId));
};

const mapPost = (
  post: {
    id: string;
    user: BasicUser;
    squad: { id: string; name: string; avatarUrl: string | null } | null;
    content: string;
    images: string[];
    location?: string | null;
    eventId?: string | null;
    boundDjIds?: string[] | null;
    boundBrandIds?: string[] | null;
    boundEventIds?: string[] | null;
    displayPublishedAt?: Date | null;
    createdAt: Date;
    updatedAt: Date;
    likeCount: number;
    repostCount: number;
    saveCount: number;
    shareCount: number;
    hideCount: number;
    commentCount: number;
  },
  followingSet: Set<string>,
  likedPostIds: Set<string>,
  repostedPostIds: Set<string>,
  savedPostIds: Set<string> = new Set<string>(),
  hiddenPostIds: Set<string> = new Set<string>(),
  recommendation?: { reasonCode: string | null; reasonText: string | null }
) => {
  const displayPublishedAt = post.displayPublishedAt ?? post.createdAt;
  return {
    id: post.id,
    author: toUserSummary(post.user, followingSet.has(post.user.id)),
    content: post.content,
    images: post.images,
    location: post.location ?? null,
    eventID: post.eventId ?? null,
    boundDjIDs: Array.isArray(post.boundDjIds) ? post.boundDjIds : [],
    boundBrandIDs: Array.isArray(post.boundBrandIds) ? post.boundBrandIds : [],
    boundEventIDs: Array.isArray(post.boundEventIds) ? post.boundEventIds : [],
    displayPublishedAt,
    publishedAt: displayPublishedAt,
    firstPublishedAt: post.createdAt,
    createdAt: post.createdAt,
    updatedAt: post.updatedAt,
    likeCount: post.likeCount,
    repostCount: post.repostCount,
    saveCount: post.saveCount,
    shareCount: post.shareCount,
    commentCount: post.commentCount,
    isLiked: likedPostIds.has(post.id),
    isReposted: repostedPostIds.has(post.id),
    isSaved: savedPostIds.has(post.id),
    isHidden: hiddenPostIds.has(post.id),
    recommendationReasonCode: recommendation?.reasonCode ?? null,
    recommendationReason: recommendation?.reasonText ?? null,
    squad: post.squad
      ? {
          id: post.squad.id,
          name: post.squad.name,
          avatarURL: post.squad.avatarUrl,
        }
      : null,
  };
};

const buildLikedPostMap = async (viewerId: string | undefined, postIds: string[]) => {
  if (!viewerId || postIds.length === 0) {
    return new Set<string>();
  }

  const rows = await prisma.postLike.findMany({
    where: {
      userId: viewerId,
      postId: { in: postIds },
    },
    select: { postId: true },
  });

  return new Set(rows.map((row) => row.postId));
};

const buildRepostedPostMap = async (viewerId: string | undefined, postIds: string[]) => {
  if (!viewerId || postIds.length === 0) {
    return new Set<string>();
  }

  const rows = await prisma.postRepost.findMany({
    where: {
      userId: viewerId,
      postId: { in: postIds },
    },
    select: { postId: true },
  });

  return new Set(rows.map((row) => row.postId));
};

const buildSavedPostMap = async (viewerId: string | undefined, postIds: string[]) => {
  if (!viewerId || postIds.length === 0) {
    return new Set<string>();
  }

  const rows = await prisma.postSave.findMany({
    where: {
      userId: viewerId,
      postId: { in: postIds },
    },
    select: { postId: true },
  });

  return new Set(rows.map((row) => row.postId));
};

const buildHiddenPostMap = async (viewerId: string | undefined, postIds: string[]) => {
  if (!viewerId || postIds.length === 0) {
    return new Set<string>();
  }

  const rows = await prisma.postHide.findMany({
    where: {
      userId: viewerId,
      postId: { in: postIds },
    },
    select: { postId: true },
  });

  return new Set(rows.map((row) => row.postId));
};

const hydratePostForViewer = async (postId: string, viewerId: string | undefined) => {
  const hydrated = await prisma.post.findUnique({
    where: { id: postId },
    include: {
      user: {
        select: {
          id: true,
          username: true,
          displayName: true,
          avatarUrl: true,
        },
      },
      squad: {
        select: {
          id: true,
          name: true,
          avatarUrl: true,
        },
      },
    },
  });

  if (!hydrated) return null;

  const [followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds] = await Promise.all([
    buildFollowingMap(viewerId, [hydrated.user.id]),
    buildLikedPostMap(viewerId, [postId]),
    buildRepostedPostMap(viewerId, [postId]),
    buildSavedPostMap(viewerId, [postId]),
    buildHiddenPostMap(viewerId, [postId]),
  ]);

  return mapPost(hydrated, followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds);
};

const normalizeTags = (input: unknown): string[] => {
  if (Array.isArray(input)) {
    return Array.from(
      new Set(
        input
          .filter((item): item is string => typeof item === 'string')
          .map((item) => item.trim())
          .filter(Boolean)
          .slice(0, 20)
      )
    );
  }

  if (typeof input === 'string') {
    return Array.from(
      new Set(
        input
          .split(',')
          .map((item) => item.trim())
          .filter(Boolean)
          .slice(0, 20)
      )
    );
  }

  return [];
};

const normalizePostBindingIDs = (input: unknown, maxCount = 50): string[] => {
  if (!Array.isArray(input)) {
    return [];
  }

  const deduped = Array.from(
    new Set(
      input
        .filter((item): item is string => typeof item === 'string')
        .map((item) => item.trim())
        .filter((item) => item.length > 0)
    )
  );

  return deduped.slice(0, maxCount);
};

const normalizeShareChannel = (input: unknown): string => {
  const value = typeof input === 'string' ? input.trim().toLowerCase() : '';
  const allowed = new Set(['system', 'copy_link', 'wechat', 'moments', 'other']);
  return allowed.has(value) ? value : 'system';
};

const normalizeShareStatus = (input: unknown): string => {
  const value = typeof input === 'string' ? input.trim().toLowerCase() : '';
  return value === 'intent' ? 'intent' : 'completed';
};

const normalizeHideReason = (input: unknown): string => {
  const value = typeof input === 'string' ? input.trim().toLowerCase() : '';
  const allowed = new Set(['not_relevant', 'seen_too_often', 'low_quality', 'author', 'other']);
  return allowed.has(value) ? value : 'not_relevant';
};

const normalizeHideNote = (input: unknown): string | null => {
  if (typeof input !== 'string') return null;
  const value = input.trim().slice(0, 500);
  return value || null;
};

const normalizeDirectPair = (userOneId: string, userTwoId: string): [string, string] => {
  return userOneId <= userTwoId ? [userOneId, userTwoId] : [userTwoId, userOneId];
};

const mapDirectConversation = async (
  conversation: {
    id: string;
    userAId: string;
    userBId: string;
    userA: BasicUser;
    userB: BasicUser;
    updatedAt: Date;
    messages: Array<{ content: string; createdAt: Date; senderId: string; sender?: { username: string } }>;
  },
  viewerId: string,
  unreadCount = 0
) => {
  const targetUser = conversation.userAId === viewerId ? conversation.userB : conversation.userA;
  const followingSet = await buildFollowingMap(viewerId, [targetUser.id]);
  const last = conversation.messages[0];

  return {
    id: conversation.id,
    type: 'direct',
    title: targetUser.displayName || targetUser.username,
    avatarURL: targetUser.avatarUrl,
    lastMessage: last?.content || '开始聊天吧',
    lastMessageSenderID: last?.sender?.username || last?.senderId || null,
    unreadCount,
    updatedAt: last?.createdAt || conversation.updatedAt,
    peer: toUserSummary(targetUser, followingSet.has(targetUser.id)),
  };
};

const mapGroupConversation = (
  squad: {
    id: string;
    name: string;
    avatarUrl: string | null;
    updatedAt: Date;
    messages: Array<{ content: string; createdAt: Date; userId: string; user?: { username: string } }>;
  },
  unreadCount = 0
) => {
  const last = squad.messages[0];
  return {
    id: squad.id,
    type: 'group',
    title: squad.name,
    avatarURL: squad.avatarUrl,
    lastMessage: last?.content || '暂无消息',
    lastMessageSenderID: last?.user?.username || last?.userId || null,
    unreadCount,
    updatedAt: last?.createdAt || squad.updatedAt,
    peer: null,
  };
};

const truncateText = (value: string, maxLength = 28): string => {
  const normalized = value.replace(/\s+/g, ' ').trim();
  if (!normalized) return '';
  if (normalized.length <= maxLength) return normalized;
  return `${normalized.slice(0, maxLength - 1)}…`;
};

const NEWS_MARKER = '#RAVER_NEWS';

const newsSingleLine = (value: string): string => value.replace(/\s+/g, ' ').trim();

const newsDecodeUtf8Base64 = (encoded: string): string => {
  const source = encoded.trim();
  if (!source) return '';
  try {
    return Buffer.from(source, 'base64').toString('utf8').trim();
  } catch {
    return '';
  }
};

const readNewsValueAfterPrefix = (line: string, key: string): string => {
  const prefixes = [`${key}：`, `${key}:`, `${key.toUpperCase()}：`, `${key.toUpperCase()}:`];
  for (const prefix of prefixes) {
    if (!line.startsWith(prefix)) continue;
    const value = line.slice(prefix.length).trim();
    if (value) return value;
  }
  return '';
};

const decodeRaverNewsDraft = (
  content: string
): { title: string; summary: string; body: string } | null => {
  const lines = String(content || '')
    .split(/\r?\n/g)
    .map((line) => line.trim())
    .filter(Boolean);
  if (!lines.includes(NEWS_MARKER)) {
    return null;
  }

  const read = (keys: string[]): string => {
    for (const line of lines) {
      for (const key of keys) {
        const value = readNewsValueAfterPrefix(line, key);
        if (value) return value;
      }
    }
    return '';
  };

  const title = read(['标题', 'title']) || '未命名资讯';
  const summary = read(['摘要', 'summary']) || '';
  const bodyEncoded = read(['正文MD64', 'content_md64', 'body_md64']);
  const body = newsDecodeUtf8Base64(bodyEncoded) || read(['正文', 'content', 'body']) || '';
  return {
    title: newsSingleLine(title) || '未命名资讯',
    summary: newsSingleLine(summary),
    body,
  };
};

const normalizeNotificationTargets = (targetUserIds: string[]): string[] => {
  return Array.from(new Set(targetUserIds.map((item) => item.trim()).filter((item) => item.length > 0)));
};

const publishCommunityInteractionSafely = (params: {
  targetUserIds: string[];
  title: string;
  body: string;
  deeplink?: string | null;
  metadata?: Record<string, unknown>;
  dedupeKey?: string;
}): void => {
  const targets = normalizeNotificationTargets(params.targetUserIds);
  if (targets.length === 0) {
    return;
  }

  void notificationCenterService
    .publish({
      category: 'community_interaction',
      targets: targets.map((userId) => ({ userId })),
      channels: ['in_app', 'apns'],
      payload: {
        title: params.title,
        body: params.body,
        deeplink: params.deeplink ?? null,
        metadata: params.metadata ?? {},
      },
      dedupeKey: params.dedupeKey,
    })
    .catch((error) => {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`[notification-center] community publish failed: ${message}`);
    });
};

const publishChatMessageSafely = (params: {
  targetUserIds: string[];
  title: string;
  body: string;
  deeplink?: string | null;
  metadata?: Record<string, unknown>;
  dedupeKey?: string;
}): void => {
  const targets = normalizeNotificationTargets(params.targetUserIds);
  if (targets.length === 0) {
    return;
  }

  void notificationCenterService
    .publish({
      category: 'chat_message',
      targets: targets.map((userId) => ({ userId })),
      channels: ['in_app', 'apns'],
      payload: {
        title: params.title,
        body: params.body,
        deeplink: params.deeplink ?? null,
        metadata: params.metadata ?? {},
      },
      dedupeKey: params.dedupeKey,
    })
    .catch((error) => {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`[notification-center] chat publish failed: ${message}`);
    });
};

const publishFavoritedEventNewsSafely = async (params: {
  actorUserId: string;
  postId: string;
  content: string;
  imageURLs: string[];
  boundEventIDs: string[];
  occurredAt: Date;
}): Promise<void> => {
  const normalizedEventIDs = Array.from(
    new Set(params.boundEventIDs.map((item) => item.trim()).filter((item) => item.length > 0))
  );
  if (normalizedEventIDs.length === 0) {
    return;
  }

  const decodedNews = decodeRaverNewsDraft(params.content);
  if (!decodedNews) {
    return;
  }

  const events = await prisma.event.findMany({
    where: {
      id: {
        in: normalizedEventIDs,
      },
    },
    select: {
      id: true,
      name: true,
    },
  });
  if (events.length === 0) {
    return;
  }

  const eventNameByID = new Map(events.map((item) => [item.id, item.name.trim() || item.id]));
  const coverImageURL = params.imageURLs.find((item) => item.trim().length > 0)?.trim() || null;
  const fallbackSummary = newsSingleLine(decodedNews.body).slice(0, 140);
  const newsSummary = decodedNews.summary || fallbackSummary || '你收藏的活动发布了新的资讯。';

  for (const eventID of normalizedEventIDs) {
    const eventName = eventNameByID.get(eventID);
    if (!eventName) continue;

    const rows = await prisma.checkin.findMany({
      where: {
        eventId: eventID,
        type: 'event',
        note: 'marked',
      },
      select: {
        userId: true,
      },
    });

    const targetUserIds = normalizeNotificationTargets(rows.map((item) => item.userId));
    if (targetUserIds.length === 0) {
      continue;
    }

    void notificationCenterService
      .publish({
        category: 'major_news',
        targets: targetUserIds.map((userId) => ({ userId })),
        channels: ['in_app', 'apns'],
        payload: {
          title: `${eventName} 发布了新资讯`,
          body: decodedNews.title,
          deeplink: `raver://news/${encodeURIComponent(params.postId)}`,
          metadata: {
            route: 'event_update',
            primaryUpdateKind: 'news',
            updateKind: 'news',
            eventID,
            eventName,
            newsID: params.postId,
            newsTitle: decodedNews.title,
            newsSummary,
            newsCoverImageURL: coverImageURL,
            occurredAt: params.occurredAt.toISOString(),
            source: 'event_news_publish',
            sourceAudience: 'marked_event_users',
          },
        },
        dedupeKey: `event-news:${eventID}:post:${params.postId}`,
      })
      .catch((error) => {
        const message = error instanceof Error ? error.message : String(error);
        console.error(`[notification-center] event news publish failed event=${eventID} post=${params.postId}: ${message}`);
      });
  }
};

type NotificationType = 'follow' | 'like' | 'comment' | 'squad_invite';

type CommunityNotificationSource =
  | 'user_follow'
  | 'post_like'
  | 'post_comment'
  | 'post_comment_reply'
  | 'squad_invite';

type CommunityNotificationContext = {
  inboxId: string;
  type: NotificationType;
  source: CommunityNotificationSource;
  createdAt: Date;
  isRead: boolean;
  text: string;
  actorUserId: string | null;
  target: {
    type: 'user' | 'post' | 'squad';
    id: string;
    title: string | null;
  } | null;
};

type CommunityNotificationCount = {
  total: number;
  follows: number;
  likes: number;
  comments: number;
  squadInvites: number;
};

const COMMUNITY_NOTIFICATION_SOURCES: ReadonlySet<CommunityNotificationSource> = new Set([
  'user_follow',
  'post_like',
  'post_comment',
  'post_comment_reply',
  'squad_invite',
]);

const COMMUNITY_NOTIFICATION_TYPE_SOURCES: Record<NotificationType, CommunityNotificationSource[]> = {
  follow: ['user_follow'],
  like: ['post_like'],
  comment: ['post_comment', 'post_comment_reply'],
  squad_invite: ['squad_invite'],
};

const toPositiveSafeInteger = (value: unknown): number => {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.max(0, Math.floor(value));
  }
  if (typeof value === 'bigint') {
    return Number(value > 0n ? value : 0n);
  }
  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.max(0, Math.floor(parsed)) : 0;
  }
  return 0;
};

const asRecord = (value: unknown): Record<string, unknown> | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
};

const readMetadataString = (metadata: Record<string, unknown> | null, keys: string[]): string | null => {
  if (!metadata) return null;
  for (const key of keys) {
    const raw = metadata[key];
    if (typeof raw !== 'string') continue;
    const trimmed = raw.trim();
    if (trimmed) {
      return trimmed;
    }
  }
  return null;
};

const parseNotificationType = (rawType: unknown): NotificationType | null => {
  if (typeof rawType !== 'string') return null;
  const normalized = rawType.trim().toLowerCase();
  if (!normalized) return null;
  if (normalized === 'follow') return 'follow';
  if (normalized === 'like') return 'like';
  if (normalized === 'comment') return 'comment';
  if (normalized === 'squad_invite' || normalized === 'squadinvite') return 'squad_invite';
  return null;
};

const mapSourceToNotificationType = (source: CommunityNotificationSource): NotificationType => {
  if (source === 'user_follow') return 'follow';
  if (source === 'post_like') return 'like';
  if (source === 'squad_invite') return 'squad_invite';
  return 'comment';
};

const toCommunityNotificationContext = (
  row: {
    id: string;
    type: string;
    body: string;
    metadata: Prisma.JsonValue | null;
    isRead: boolean;
    createdAt: Date;
  }
): CommunityNotificationContext | null => {
  if (row.type !== 'community_interaction') {
    return null;
  }

  const metadata = asRecord(row.metadata);
  const sourceRaw = readMetadataString(metadata, ['source']);
  if (!sourceRaw || !COMMUNITY_NOTIFICATION_SOURCES.has(sourceRaw as CommunityNotificationSource)) {
    return null;
  }

  const source = sourceRaw as CommunityNotificationSource;
  const type = mapSourceToNotificationType(source);
  const actorUserId = readMetadataString(metadata, ['actorUserID', 'actorUserId', 'inviterUserID', 'inviterUserId']);
  const postId = readMetadataString(metadata, ['postID', 'postId']);
  const squadId = readMetadataString(metadata, ['squadID', 'squadId']);
  const squadName = readMetadataString(metadata, ['squadName', 'squadTitle']);

  let target: CommunityNotificationContext['target'] = null;
  if (type === 'follow' && actorUserId) {
    target = { type: 'user', id: actorUserId, title: null };
  } else if ((type === 'like' || type === 'comment') && postId) {
    target = { type: 'post', id: postId, title: null };
  } else if (type === 'squad_invite' && squadId) {
    target = { type: 'squad', id: squadId, title: squadName };
  }

  return {
    inboxId: row.id,
    type,
    source,
    createdAt: row.createdAt,
    isRead: row.isRead,
    text: row.body,
    actorUserId,
    target,
  };
};

const getCommunityNotificationCounts = async (userId: string): Promise<CommunityNotificationCount> => {
  const rows = await prisma.$queryRaw<Array<{ source: string | null; count: bigint | number }>>`
    SELECT
      metadata ->> 'source' AS source,
      COUNT(*)::bigint AS count
    FROM notification_inbox
    WHERE user_id = ${userId}
      AND is_read = false
      AND type = 'community_interaction'
    GROUP BY metadata ->> 'source'
  `;

  const bySource = new Map<string, number>();
  for (const row of rows) {
    const source = typeof row.source === 'string' ? row.source.trim() : '';
    if (!source) continue;
    bySource.set(source, toPositiveSafeInteger(row.count));
  }

  const follows = COMMUNITY_NOTIFICATION_TYPE_SOURCES.follow.reduce((sum, source) => sum + (bySource.get(source) ?? 0), 0);
  const likes = COMMUNITY_NOTIFICATION_TYPE_SOURCES.like.reduce((sum, source) => sum + (bySource.get(source) ?? 0), 0);
  const comments = COMMUNITY_NOTIFICATION_TYPE_SOURCES.comment.reduce((sum, source) => sum + (bySource.get(source) ?? 0), 0);
  const squadInvites = COMMUNITY_NOTIFICATION_TYPE_SOURCES.squad_invite.reduce(
    (sum, source) => sum + (bySource.get(source) ?? 0),
    0
  );

  return {
    follows,
    likes,
    comments,
    squadInvites,
    total: follows + likes + comments + squadInvites,
  };
};

router.get('/', (_req: Request, res: Response) => {
  res.json({
    name: 'Raver BFF',
    version: 'v1',
    endpoints: {
      authLogin: 'POST /v1/auth/login',
      authRegister: 'POST /v1/auth/register',
      authSmsSend: 'POST /v1/auth/sms/send',
      authSmsLogin: 'POST /v1/auth/sms/login',
      authRefresh: 'POST /v1/auth/refresh',
      authLogout: 'POST /v1/auth/logout',
      authLogoutAll: 'POST /v1/auth/logout-all',
      feed: 'GET /v1/feed',
      feedSearch: 'GET /v1/feed/search',
      feedPostDetail: 'GET /v1/feed/posts/:id',
      createPost: 'POST /v1/feed/posts',
      updatePost: 'PATCH /v1/feed/posts/:id',
      deletePost: 'DELETE /v1/feed/posts/:id',
      userSearch: 'GET /v1/users/search',
      userProfile: 'GET /v1/users/:id/profile',
      userPosts: 'GET /v1/users/:id/posts',
      userFollowers: 'GET /v1/users/:id/followers',
      userFollowing: 'GET /v1/users/:id/following',
      userFriends: 'GET /v1/users/:id/friends',
      notifications: 'GET /v1/notifications',
      notificationsUnreadCount: 'GET /v1/notifications/unread-count',
      notificationsRead: 'POST /v1/notifications/read',
      squadsRecommended: 'GET /v1/squads/recommended',
      squadsMine: 'GET /v1/squads/mine',
      squadProfile: 'GET /v1/squads/:id/profile',
      squadJoin: 'POST /v1/squads/:id/join',
      squadLeave: 'POST /v1/squads/:id/leave',
      squadDisband: 'POST /v1/squads/:id/disband',
      squadCreate: 'POST /v1/squads',
      squadAvatar: 'POST /v1/squads/:id/avatar',
      squadMySettings: 'PATCH /v1/squads/:id/my-settings',
      squadManage: 'PATCH /v1/squads/:id/manage',
      profileUpdate: 'PATCH /v1/profile/me',
      profileAvatar: 'POST /v1/profile/me/avatar',
      profileLikes: 'GET /v1/profile/me/likes',
      profileReposts: 'GET /v1/profile/me/reposts',
      profileSaves: 'GET /v1/profile/me/saves',
      conversations: 'GET /v1/chat/conversations',
      conversationRead: 'POST /v1/chat/conversations/:id/read',
      startDirect: 'POST /v1/chat/direct/start',
      repostPost: 'POST /v1/feed/posts/:id/repost',
      unrepostPost: 'DELETE /v1/feed/posts/:id/repost',
      savePost: 'POST /v1/feed/posts/:id/save',
      unsavePost: 'DELETE /v1/feed/posts/:id/save',
      sharePost: 'POST /v1/feed/posts/:id/share',
      hidePost: 'POST /v1/feed/posts/:id/hide',
      feedEvent: 'POST /v1/feed/events',
      feedExperimentSummary: 'GET /v1/feed/experiments/summary',
    },
  });
});

router.post('/auth/login', async (req: Request, res: Response): Promise<void> => {
  try {
    const { username, identifier, email, password } = req.body as {
      username?: string;
      identifier?: string;
      email?: string;
      password?: string;
    };

    const loginIdentifier = String(username || identifier || email || '').trim();
    const nowMs = Date.now();
    const clientIp = getClientIp(req);
    const loginRateKey = buildRateKey(clientIp, loginIdentifier || 'unknown');
    const loginRateState = checkRateLimit(
      authLoginRateBuckets,
      loginRateKey,
      authLoginRateLimitMaxAttempts,
      authLoginRateLimitWindowMs,
      nowMs
    );

    if (loginRateState.limited) {
      writeAuthAuditLog(req, {
        action: 'auth.login',
        outcome: 'blocked',
        identifier: loginIdentifier || null,
        errorCode: 'AUTH_LOGIN_RATE_LIMITED',
        detail: { retryAfterSeconds: loginRateState.retryAfterSeconds },
      });
      res.status(429).json({
        error: 'Too many login attempts, please try again later',
        retryAfterSeconds: loginRateState.retryAfterSeconds,
      });
      return;
    }

    if (!loginIdentifier || !password) {
      writeAuthAuditLog(req, {
        action: 'auth.login',
        outcome: 'failed',
        identifier: loginIdentifier || null,
        errorCode: 'AUTH_INVALID_REQUEST',
      });
      res.status(400).json({ error: 'username and password are required' });
      return;
    }

    const user = await prisma.user.findFirst({
      where: {
        isActive: true,
        OR: [
          { username: { equals: loginIdentifier, mode: 'insensitive' } },
          { email: { equals: loginIdentifier, mode: 'insensitive' } },
          { displayName: { equals: loginIdentifier, mode: 'insensitive' } },
        ],
      },
      orderBy: { createdAt: 'asc' },
    });

    if (!user) {
      registerRateAttempt(authLoginRateBuckets, loginRateKey, authLoginRateLimitWindowMs, nowMs);
      writeAuthAuditLog(req, {
        action: 'auth.login',
        outcome: 'failed',
        identifier: loginIdentifier,
        errorCode: 'AUTH_INVALID_CREDENTIALS',
      });
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }

    const valid = await comparePassword(password, user.passwordHash);
    if (!valid) {
      registerRateAttempt(authLoginRateBuckets, loginRateKey, authLoginRateLimitWindowMs, nowMs);
      writeAuthAuditLog(req, {
        action: 'auth.login',
        outcome: 'failed',
        identifier: loginIdentifier,
        userId: user.id,
        errorCode: 'AUTH_INVALID_CREDENTIALS',
      });
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }

    clearRateBucket(authLoginRateBuckets, loginRateKey);

    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    await syncTencentIMUserBestEffort(user.id, 'bff-auth-login');
    writeAuthAuditLog(req, {
      action: 'auth.login',
      outcome: 'success',
      userId: user.id,
      identifier: loginIdentifier,
    });
    await issueAuthSuccessResponse(req, res, {
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      email: user.email,
      role: user.role,
    });
  } catch (error) {
    console.error('BFF login error:', error);
    writeAuthAuditLog(req, {
      action: 'auth.login',
      outcome: 'failed',
      errorCode: 'AUTH_INTERNAL_ERROR',
    });
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/auth/register', async (req: Request, res: Response): Promise<void> => {
  try {
    const { username, email, password, displayName } = req.body as {
      username?: string;
      email?: string;
      password?: string;
      displayName?: string;
    };

    const normalizedUsername = String(username || '').trim().toLowerCase();
    const normalizedEmail = String(email || '').trim().toLowerCase();
    const normalizedDisplayName = String(displayName || normalizedUsername).trim();
    const nowMs = Date.now();
    const registerIdentifier = normalizedEmail || normalizedUsername || 'unknown';
    const registerRateKey = buildRateKey(getClientIp(req), registerIdentifier);
    const registerRateState = checkRateLimit(
      authRegisterRateBuckets,
      registerRateKey,
      authRegisterRateLimitMaxAttempts,
      authRegisterRateLimitWindowMs,
      nowMs
    );

    if (registerRateState.limited) {
      writeAuthAuditLog(req, {
        action: 'auth.register',
        outcome: 'blocked',
        identifier: registerIdentifier,
        errorCode: 'AUTH_REGISTER_RATE_LIMITED',
        detail: { retryAfterSeconds: registerRateState.retryAfterSeconds },
      });
      res.status(429).json({
        error: 'Too many register attempts, please try again later',
        retryAfterSeconds: registerRateState.retryAfterSeconds,
      });
      return;
    }

    registerRateAttempt(authRegisterRateBuckets, registerRateKey, authRegisterRateLimitWindowMs, nowMs);

    if (!normalizedUsername || !normalizedEmail || !password) {
      writeAuthAuditLog(req, {
        action: 'auth.register',
        outcome: 'failed',
        identifier: registerIdentifier,
        errorCode: 'AUTH_INVALID_REQUEST',
      });
      res.status(400).json({ error: 'username, email, and password are required' });
      return;
    }

    if (password.length < 6) {
      writeAuthAuditLog(req, {
        action: 'auth.register',
        outcome: 'failed',
        identifier: registerIdentifier,
        errorCode: 'AUTH_PASSWORD_TOO_SHORT',
      });
      res.status(400).json({ error: 'Password must be at least 6 characters' });
      return;
    }

    const exists = await prisma.user.findFirst({
      where: {
        OR: [{ username: normalizedUsername }, { email: normalizedEmail }],
      },
      select: { id: true },
    });

    if (exists) {
      writeAuthAuditLog(req, {
        action: 'auth.register',
        outcome: 'failed',
        identifier: registerIdentifier,
        errorCode: 'AUTH_USER_EXISTS',
      });
      res.status(409).json({ error: 'User already exists' });
      return;
    }

    const user = await prisma.user.create({
      data: {
        username: normalizedUsername,
        email: normalizedEmail,
        passwordHash: await hashPassword(password),
        displayName: normalizedDisplayName || normalizedUsername,
      },
      select: {
        id: true,
        username: true,
        email: true,
        displayName: true,
        avatarUrl: true,
        role: true,
      },
    });

    await syncTencentIMUserBestEffort(user.id, 'bff-auth-register');
    writeAuthAuditLog(req, {
      action: 'auth.register',
      outcome: 'success',
      userId: user.id,
      identifier: registerIdentifier,
    });
    res.status(201);
    await issueAuthSuccessResponse(req, res, {
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      email: user.email,
      role: user.role,
    });
  } catch (error) {
    console.error('BFF register error:', error);
    writeAuthAuditLog(req, {
      action: 'auth.register',
      outcome: 'failed',
      errorCode: 'AUTH_INTERNAL_ERROR',
    });
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/auth/sms/send', async (req: Request, res: Response): Promise<void> => {
  try {
    const { phone, scene } = req.body as { phone?: string; scene?: string };
    const phoneNumber = normalizePhoneNumber(phone);
    const sceneKey = String(scene || 'login').trim().toLowerCase() || 'login';
    const now = new Date();
    const clientIp = getClientIp(req);

    if (!phoneNumber) {
      res.status(400).json({ error: 'Invalid phone number' });
      return;
    }

    if (sceneKey !== 'login') {
      res.status(400).json({ error: 'Unsupported sms scene' });
      return;
    }

    const [lastSent, sentByPhoneInLastHour, sentByIpInLastHour] = await Promise.all([
      prisma.authSmsCode.findFirst({
        where: { phoneNumber, scene: sceneKey },
        orderBy: { createdAt: 'desc' },
        select: { createdAt: true },
      }),
      prisma.authSmsCode.count({
        where: {
          phoneNumber,
          scene: sceneKey,
          createdAt: { gte: new Date(now.getTime() - 60 * 60 * 1000) },
        },
      }),
      prisma.authSmsCode.count({
        where: {
          sendIp: clientIp,
          createdAt: { gte: new Date(now.getTime() - 60 * 60 * 1000) },
        },
      }),
    ]);

    if (lastSent && now.getTime() - lastSent.createdAt.getTime() < authSmsSendCooldownMs) {
      const retryAfterMs = authSmsSendCooldownMs - (now.getTime() - lastSent.createdAt.getTime());
      res.status(429).json({
        error: 'SMS request too frequent',
        retryAfterSeconds: Math.ceil(retryAfterMs / 1000),
      });
      return;
    }

    if (sentByPhoneInLastHour >= authSmsPhoneHourlyLimit) {
      res.status(429).json({
        error: 'SMS phone hourly limit exceeded',
        retryAfterSeconds: 60 * 60,
      });
      return;
    }

    if (sentByIpInLastHour >= authSmsIpHourlyLimit) {
      res.status(429).json({
        error: 'SMS ip hourly limit exceeded',
        retryAfterSeconds: 60 * 60,
      });
      return;
    }

    const code = generateSmsCode();
    await smsService.sendLoginCode(phoneNumber, code);

    await prisma.authSmsCode.create({
      data: {
        phoneNumber,
        scene: sceneKey,
        codeHash: hashToken(code),
        sendIp: clientIp,
        expiresAt: new Date(now.getTime() + authSmsCodeTtlMs),
      },
      select: { id: true },
    });

    const responsePayload: {
      success: true;
      expiresInSeconds: number;
      debugCode?: string;
      debugProvider?: string;
    } = {
      success: true,
      expiresInSeconds: Math.max(1, Math.floor(authSmsCodeTtlMs / 1000)),
    };

    if (isSmsDebugCodeEnabledForPhone(phoneNumber)) {
      responsePayload.debugCode = code;
      responsePayload.debugProvider = 'mock';
    }

    res.status(201).json(responsePayload);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('BFF sms send error:', message);
    res.status(502).json({ error: 'Failed to send sms code' });
  }
});

router.post('/auth/sms/login', async (req: Request, res: Response): Promise<void> => {
  try {
    const { phone, code } = req.body as { phone?: string; code?: string };
    const phoneNumber = normalizePhoneNumber(phone);
    const smsCode = normalizeSmsCode(code);
    const now = new Date();

    if (!phoneNumber || !smsCode) {
      res.status(400).json({ error: 'phone and code are required' });
      return;
    }

    const phoneState = await prisma.authPhoneAuthState.findUnique({
      where: { phoneNumber },
      select: { blockedUntil: true },
    });

    if (phoneState?.blockedUntil && phoneState.blockedUntil.getTime() > now.getTime()) {
      res.status(429).json({
        error: 'Phone temporarily blocked due to too many failed attempts',
        retryAfterSeconds: Math.ceil((phoneState.blockedUntil.getTime() - now.getTime()) / 1000),
      });
      return;
    }

    const latestCode = await prisma.authSmsCode.findFirst({
      where: {
        phoneNumber,
        scene: 'login',
        consumedAt: null,
      },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        codeHash: true,
        expiresAt: true,
      },
    });

    if (!latestCode || latestCode.expiresAt.getTime() <= now.getTime()) {
      const state = await registerSmsVerifyFailure(phoneNumber, now);
      const blockedUntil = state.blockedUntil;
      res.status(401).json({
        error: 'Invalid or expired sms code',
        blockedUntil: blockedUntil ? blockedUntil.toISOString() : null,
      });
      return;
    }

    if (!isTokenHashMatch(smsCode, latestCode.codeHash)) {
      const state = await registerSmsVerifyFailure(phoneNumber, now);
      const blockedUntil = state.blockedUntil;
      res.status(401).json({
        error: 'Invalid or expired sms code',
        blockedUntil: blockedUntil ? blockedUntil.toISOString() : null,
      });
      return;
    }

    await prisma.authSmsCode.update({
      where: { id: latestCode.id },
      data: { consumedAt: now },
      select: { id: true },
    });
    await clearSmsVerifyFailures(phoneNumber);

    let user = await prisma.user.findFirst({
      where: { phoneNumber, isActive: true },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
        email: true,
        role: true,
      },
    });

    if (!user) {
      const bootstrapIdentity = await generatePhoneBootstrapIdentity(phoneNumber);
      user = await prisma.user.create({
        data: {
          username: bootstrapIdentity.username,
          email: bootstrapIdentity.email,
          phoneNumber,
          passwordHash: await hashPassword(generateRefreshToken()),
          displayName: bootstrapIdentity.displayName,
          isActive: true,
        },
        select: {
          id: true,
          username: true,
          displayName: true,
          avatarUrl: true,
          email: true,
          role: true,
        },
      });
    }

    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: now },
      select: { id: true },
    });

    await syncTencentIMUserBestEffort(user.id, 'bff-auth-sms-login');
    await issueAuthSuccessResponse(req, res, user);
  } catch (error) {
    console.error('BFF sms login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/auth/refresh', async (req: Request, res: Response): Promise<void> => {
  try {
    const rawRefreshToken = extractRefreshToken(req);
    if (!rawRefreshToken) {
      clearRefreshCookie(res);
      writeAuthAuditLog(req, {
        action: 'auth.refresh',
        outcome: 'failed',
        errorCode: 'AUTH_REFRESH_TOKEN_MISSING',
      });
      res.status(401).json({ error: 'Refresh token is required' });
      return;
    }

    const now = new Date();
    const current = await prisma.authRefreshToken.findUnique({
      where: { tokenHash: hashToken(rawRefreshToken) },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
            email: true,
            role: true,
            isActive: true,
          },
        },
      },
    });

    if (!current || current.revokedAt || current.expiresAt.getTime() <= now.getTime() || !current.user.isActive) {
      clearRefreshCookie(res);
      if (current && !current.revokedAt) {
        await prisma.authRefreshToken.update({
          where: { id: current.id },
          data: {
            revokedAt: now,
            lastUsedAt: now,
          },
          select: { id: true },
        });
      }
      writeAuthAuditLog(req, {
        action: 'auth.refresh',
        outcome: 'failed',
        userId: current?.userId || null,
        errorCode: 'AUTH_REFRESH_TOKEN_INVALID_OR_EXPIRED',
      });
      res.status(401).json({ error: 'Refresh token invalid or expired' });
      return;
    }

    const nextRefreshToken = generateRefreshToken();
    const nextRefreshHash = hashToken(nextRefreshToken);
    const nextExpiresAt = new Date(now.getTime() + REFRESH_TOKEN_TTL_MS);
    const clientIp = getClientIp(req);
    const userAgent = req.headers['user-agent'] || null;

    const createdNextToken = await prisma.$transaction(async (tx) => {
      const next = await tx.authRefreshToken.create({
        data: {
          userId: current.userId,
          tokenHash: nextRefreshHash,
          userAgent,
          ipAddress: clientIp,
          expiresAt: nextExpiresAt,
        },
        select: { id: true },
      });

      await tx.authRefreshToken.update({
        where: { id: current.id },
        data: {
          revokedAt: now,
          lastUsedAt: now,
          replacedByTokenId: next.id,
        },
        select: { id: true },
      });

      return next;
    });

    setRefreshCookie(res, nextRefreshToken);
    const accessToken = createAccessTokenForUser(current.user);
    writeAuthAuditLog(req, {
      action: 'auth.refresh',
      outcome: 'success',
      userId: current.userId,
    });
    res.json({
      token: accessToken,
      accessToken,
      accessTokenExpiresIn: ACCESS_TOKEN_TTL_SECONDS,
      refreshToken: nextRefreshToken,
      refreshTokenId: createdNextToken.id,
      user: toUserSummary(
        {
          id: current.user.id,
          username: current.user.username,
          displayName: current.user.displayName,
          avatarUrl: current.user.avatarUrl,
        },
        false
      ),
    });
  } catch (error) {
    console.error('BFF refresh error:', error);
    clearRefreshCookie(res);
    writeAuthAuditLog(req, {
      action: 'auth.refresh',
      outcome: 'failed',
      errorCode: 'AUTH_INTERNAL_ERROR',
    });
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/auth/logout', async (req: Request, res: Response): Promise<void> => {
  try {
    const rawRefreshToken = extractRefreshToken(req);
    const now = new Date();
    let revokedCount = 0;
    if (rawRefreshToken) {
      revokedCount = await revokeRefreshTokenByRawToken(rawRefreshToken, now);
    }
    clearRefreshCookie(res);
    writeAuthAuditLog(req, {
      action: 'auth.logout',
      outcome: 'success',
      detail: { revokedCount },
    });
    res.json({ success: true });
  } catch (error) {
    console.error('BFF logout error:', error);
    clearRefreshCookie(res);
    writeAuthAuditLog(req, {
      action: 'auth.logout',
      outcome: 'failed',
      errorCode: 'AUTH_INTERNAL_ERROR',
    });
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/auth/logout-all', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) {
      writeAuthAuditLog(req, {
        action: 'auth.logout-all',
        outcome: 'failed',
        errorCode: 'AUTH_UNAUTHORIZED',
      });
      return;
    }

    const result = await prisma.authRefreshToken.updateMany({
      where: {
        userId,
        revokedAt: null,
      },
      data: {
        revokedAt: new Date(),
      },
    });

    clearRefreshCookie(res);
    writeAuthAuditLog(req, {
      action: 'auth.logout-all',
      outcome: 'success',
      userId,
      detail: { revokedCount: result.count },
    });
    res.json({ success: true });
  } catch (error) {
    console.error('BFF logout all error:', error);
    clearRefreshCookie(res);
    writeAuthAuditLog(req, {
      action: 'auth.logout-all',
      outcome: 'failed',
      errorCode: 'AUTH_INTERNAL_ERROR',
    });
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/feed', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId;
    const requestedMode = normalizeFeedMode(req.query.mode);
    const effectiveMode: FeedMode = requestedMode === 'following' && !viewerId ? 'latest' : requestedMode;
    const experimentBucket: FeedExperimentBucket = resolveFeedExperimentBucket(req, viewerId);
    const rankingWeights = buildFeedRankingWeights(experimentBucket);

    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);
    const baseWhere = {
      visibility: 'public' as const,
      squadId: null,
      ...(viewerId
        ? {
            hides: {
              none: { userId: viewerId },
            },
          }
        : {}),
      ...(cursorDate
        ? {
            createdAt: {
              lt: cursorDate,
            },
          }
        : {}),
    };

    const postInclude = {
      user: {
        select: {
          id: true,
          username: true,
          displayName: true,
          avatarUrl: true,
        },
      },
      squad: {
        select: {
          id: true,
          name: true,
          avatarUrl: true,
        },
      },
    } as const;

    let sourcePosts: Array<Parameters<typeof mapPost>[0]> = [];
    let recallSourcesByPostId = new Map<string, Set<FeedRecallSource>>();
    let preloadedFollowedDjIds: Set<string> | null = null;

    const addRecallSource = (postId: string, source: FeedRecallSource) => {
      const bucket = recallSourcesByPostId.get(postId) || new Set<FeedRecallSource>();
      bucket.add(source);
      recallSourcesByPostId.set(postId, bucket);
    };

    const mergeRecallPosts = (
      target: Map<string, Parameters<typeof mapPost>[0]>,
      posts: Array<Parameters<typeof mapPost>[0]>,
      source: FeedRecallSource
    ) => {
      for (const post of posts) {
        if (!target.has(post.id)) {
          target.set(post.id, post);
        }
        addRecallSource(post.id, source);
      }
    };

    if (effectiveMode === 'recommended') {
      const mergedById = new Map<string, Parameters<typeof mapPost>[0]>();
      const trendingTake = Math.min(Math.max(limit * 5, 100), 300);

      if (!viewerId) {
        const trendingCandidates = await prisma.post.findMany({
          where: baseWhere,
          include: postInclude,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          take: trendingTake,
        });
        mergeRecallPosts(mergedById, trendingCandidates, 'trending');
      } else {
        const [followingRows, followedDjRows, recentSaveRows, recentLikeRows] = await Promise.all([
          prisma.follow.findMany({
            where: {
              followerId: viewerId,
              type: 'user',
              followingId: { not: null },
            },
            select: { followingId: true },
          }),
          prisma.follow.findMany({
            where: {
              followerId: viewerId,
              type: 'dj',
              djId: { not: null },
            },
            select: { djId: true },
          }),
          prisma.postSave.findMany({
            where: { userId: viewerId },
            orderBy: { createdAt: 'desc' },
            take: 18,
            select: { postId: true },
          }),
          prisma.postLike.findMany({
            where: { userId: viewerId },
            orderBy: { createdAt: 'desc' },
            take: 18,
            select: { postId: true },
          }),
        ]);

        const followingIds = followingRows
          .map((row) => row.followingId)
          .filter((id): id is string => Boolean(id));
        const followedDjIds = new Set(
          followedDjRows.map((row) => row.djId).filter((id): id is string => Boolean(id))
        );
        preloadedFollowedDjIds = followedDjIds;

        const interactionPostIds = Array.from(
          new Set(
            [...recentSaveRows.map((row) => row.postId), ...recentLikeRows.map((row) => row.postId)].filter(
              (id): id is string => Boolean(id)
            )
          )
        ).slice(0, 24);

        const interactionSeeds =
          interactionPostIds.length > 0
            ? await prisma.post.findMany({
                where: {
                  id: { in: interactionPostIds },
                },
                select: {
                  userId: true,
                  boundDjIds: true,
                  boundBrandIds: true,
                  boundEventIds: true,
                },
              })
            : [];

        const relatedAuthorIds = Array.from(
          new Set(
            interactionSeeds
              .map((row) => row.userId)
              .filter((id): id is string => Boolean(id && id !== viewerId))
          )
        );
        const relatedDjIds = Array.from(new Set(interactionSeeds.flatMap((row) => row.boundDjIds || [])));
        const relatedBrandIds = Array.from(new Set(interactionSeeds.flatMap((row) => row.boundBrandIds || [])));
        const relatedEventIds = Array.from(new Set(interactionSeeds.flatMap((row) => row.boundEventIds || [])));

        const behaviorWhereOr: Prisma.PostWhereInput[] = [];
        if (relatedAuthorIds.length > 0) {
          behaviorWhereOr.push({ userId: { in: relatedAuthorIds } });
        }
        if (relatedDjIds.length > 0) {
          behaviorWhereOr.push({ boundDjIds: { hasSome: relatedDjIds } });
        }
        if (relatedBrandIds.length > 0) {
          behaviorWhereOr.push({ boundBrandIds: { hasSome: relatedBrandIds } });
        }
        if (relatedEventIds.length > 0) {
          behaviorWhereOr.push({ boundEventIds: { hasSome: relatedEventIds } });
        }

        const emptyPosts: Array<Parameters<typeof mapPost>[0]> = [];
        const [trendingCandidates, followedAuthorCandidates, followedDjCandidates, behaviorSimilarCandidates] =
          await Promise.all([
            prisma.post.findMany({
              where: baseWhere,
              include: postInclude,
              orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
              take: trendingTake,
            }),
            followingIds.length > 0
              ? prisma.post.findMany({
                  where: {
                    ...baseWhere,
                    userId: { in: followingIds },
                  },
                  include: postInclude,
                  orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
                  take: Math.min(Math.max(limit * 4, 60), 220),
                })
              : Promise.resolve(emptyPosts),
            followedDjIds.size > 0
              ? prisma.post.findMany({
                  where: {
                    ...baseWhere,
                    boundDjIds: { hasSome: Array.from(followedDjIds) },
                  },
                  include: postInclude,
                  orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
                  take: Math.min(Math.max(limit * 4, 60), 220),
                })
              : Promise.resolve(emptyPosts),
            behaviorWhereOr.length > 0
              ? prisma.post.findMany({
                  where: {
                    ...baseWhere,
                    OR: behaviorWhereOr,
                  },
                  include: postInclude,
                  orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
                  take: Math.min(Math.max(limit * 5, 80), 260),
                })
              : Promise.resolve(emptyPosts),
          ]);

        mergeRecallPosts(mergedById, followedAuthorCandidates, 'followed_author');
        mergeRecallPosts(mergedById, followedDjCandidates, 'followed_dj');
        mergeRecallPosts(mergedById, behaviorSimilarCandidates, 'behavior_similar');
        mergeRecallPosts(mergedById, trendingCandidates, 'trending');
      }

      const maxCandidatePool = Math.min(Math.max(limit * 12, 180), 420);
      sourcePosts = Array.from(mergedById.values()).slice(0, maxCandidatePool);
    } else if (effectiveMode === 'following' && viewerId) {
      const followingRows = await prisma.follow.findMany({
        where: {
          followerId: viewerId,
          type: 'user',
          followingId: { not: null },
        },
        select: { followingId: true },
      });
      const followingIds = followingRows
        .map((row) => row.followingId)
        .filter((id): id is string => Boolean(id));

      if (followingIds.length === 0) {
        res.json({
          mode: requestedMode,
          effectiveMode,
          posts: [],
          nextCursor: null,
        });
        return;
      }

      sourcePosts = await prisma.post.findMany({
        where: {
          ...baseWhere,
          userId: { in: followingIds },
        },
        include: postInclude,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
      });
    } else {
      sourcePosts = await prisma.post.findMany({
        where: baseWhere,
        include: postInclude,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
      });
    }

    const authorIds = Array.from(new Set(sourcePosts.map((post) => post.user.id)));
    const postIds = sourcePosts.map((post) => post.id);
    const boundDjIds = Array.from(
      new Set(sourcePosts.flatMap((post) => (Array.isArray(post.boundDjIds) ? post.boundDjIds : [])))
    );

    const [
      followingSet,
      likedPostIds,
      repostedPostIds,
      savedPostIds,
      hiddenPostIds,
      followedDjIds,
    ] = await Promise.all([
      buildFollowingMap(viewerId, authorIds),
      buildLikedPostMap(viewerId, postIds),
      buildRepostedPostMap(viewerId, postIds),
      buildSavedPostMap(viewerId, postIds),
      buildHiddenPostMap(viewerId, postIds),
      preloadedFollowedDjIds
        ? Promise.resolve(preloadedFollowedDjIds)
        : viewerId && boundDjIds.length > 0
          ? prisma.follow
              .findMany({
                where: {
                  followerId: viewerId,
                  type: 'dj',
                  djId: { in: boundDjIds },
                },
                select: { djId: true },
              })
              .then((rows) => new Set(rows.map((row) => row.djId).filter((id): id is string => Boolean(id))))
          : Promise.resolve(new Set<string>()),
    ]);

    let pagePosts = sourcePosts;
    let recommendationByPostId = new Map<string, { reasonCode: string | null; reasonText: string | null }>();

    if (effectiveMode === 'recommended') {
      const now = Date.now();
      const [mutedAuthorRows, hideReasonRows] = viewerId
        ? await Promise.all([
            prisma.postHide.findMany({
              where: {
                userId: viewerId,
                reason: 'author',
              },
              select: {
                post: {
                  select: {
                    userId: true,
                  },
                },
              },
              take: 200,
            }),
            prisma.postHide.groupBy({
              by: ['reason'],
              where: { userId: viewerId },
              _count: { _all: true },
            }),
          ])
        : [[], []];
      const mutedAuthorIds = new Set(
        mutedAuthorRows
          .map((row) => row.post?.userId)
          .filter((id): id is string => Boolean(id))
      );
      const hideReasonCountByKey = new Map<string, number>();
      for (const row of hideReasonRows) {
        hideReasonCountByKey.set(row.reason || 'unknown', row._count?._all ?? 0);
      }
      const seenTooOftenPenalty = Math.min(
        rankingWeights.seenTooOftenPenaltyMax,
        (hideReasonCountByKey.get('seen_too_often') || 0) * rankingWeights.seenTooOftenPenaltyFactor
      );

      const scored = sourcePosts.map((post) => {
        const createdAtMs = (post.displayPublishedAt ?? post.createdAt).getTime();
        const ageHours = Math.max(0, (now - createdAtMs) / (1000 * 60 * 60));
        const freshnessScore =
          Math.exp(-ageHours / Math.max(1, rankingWeights.freshnessHalfLifeHours)) * rankingWeights.freshnessBase;
        const engagementScore =
          post.likeCount * rankingWeights.likeWeight +
          post.commentCount * rankingWeights.commentWeight +
          post.repostCount * rankingWeights.repostWeight +
          post.saveCount * rankingWeights.saveWeight +
          post.shareCount * rankingWeights.shareWeight;
        let score = freshnessScore + engagementScore;
        const recallSources = recallSourcesByPostId.get(post.id) || new Set<FeedRecallSource>();

        let reasonCode: string | null = null;
        let reasonText: string | null = null;

        if (recallSources.has('followed_author')) {
          score += rankingWeights.recallFollowedAuthorWeight;
        }
        if (recallSources.has('followed_dj')) {
          score += rankingWeights.recallFollowedDjWeight;
        }
        if (recallSources.has('behavior_similar')) {
          score += rankingWeights.recallBehaviorSimilarWeight;
        }
        if (recallSources.has('trending')) {
          score += rankingWeights.recallTrendingWeight;
        }

        const hasFollowedDj = Array.isArray(post.boundDjIds) && post.boundDjIds.some((id) => followedDjIds.has(id));
        if (hasFollowedDj) {
          score += rankingWeights.followedDjBonus;
          reasonCode = 'followed_dj';
          reasonText = '因为你关注了相关 DJ';
        }

        if (mutedAuthorIds.has(post.user.id)) {
          score -= rankingWeights.mutedAuthorPenalty;
        }

        score -= post.hideCount * rankingWeights.globalHidePenalty;

        if (!reasonCode && recallSources.has('behavior_similar')) {
          reasonCode = 'behavior_similar';
          reasonText = '因为你最近互动过相似内容';
        }

        if (!reasonCode && followingSet.has(post.user.id)) {
          score += rankingWeights.followingAuthorBonus;
          reasonCode = 'followed_author';
          reasonText = `因为你关注了 ${post.user.displayName || post.user.username}`;
        }

        if (reasonCode === 'followed_author' && seenTooOftenPenalty > 0) {
          score -= seenTooOftenPenalty;
        }

        if (!reasonCode) {
          reasonCode = 'trending';
          reasonText = '热门推荐';
        }

        return { post, score, freshnessScore, recommendation: { reasonCode, reasonText } };
      });

      scored.sort((lhs, rhs) => {
        if (rhs.score !== lhs.score) return rhs.score - lhs.score;
        return rhs.post.createdAt.getTime() - lhs.post.createdAt.getTime();
      });

      const diversified: typeof scored = [];
      const deferred: typeof scored = [];
      const authorExposure = new Map<string, number>();
      const entityExposure = new Map<string, number>();
      const exposureLimit = Math.max(1, rankingWeights.exposureLimit);

      const resolvePrimaryEntityKey = (post: Parameters<typeof mapPost>[0]): string | null => {
        if (Array.isArray(post.boundDjIds) && post.boundDjIds.length > 0) return `dj:${post.boundDjIds[0]}`;
        if (Array.isArray(post.boundBrandIds) && post.boundBrandIds.length > 0) return `brand:${post.boundBrandIds[0]}`;
        if (Array.isArray(post.boundEventIds) && post.boundEventIds.length > 0) return `event:${post.boundEventIds[0]}`;
        return null;
      };

      for (const item of scored) {
        const authorCount = authorExposure.get(item.post.user.id) || 0;
        const entityKey = resolvePrimaryEntityKey(item.post);
        const entityCount = entityKey ? entityExposure.get(entityKey) || 0 : 0;
        const shouldDefer = authorCount >= exposureLimit || (entityKey ? entityCount >= exposureLimit : false);

        if (shouldDefer) {
          deferred.push(item);
          continue;
        }

        diversified.push(item);
        authorExposure.set(item.post.user.id, authorCount + 1);
        if (entityKey) {
          entityExposure.set(entityKey, entityCount + 1);
        }
      }

      for (const item of deferred) {
        diversified.push(item);
      }

      const hasMore = diversified.length > limit;
      const ranked = hasMore ? diversified.slice(0, limit) : diversified.slice();

      if (viewerId && ranked.length >= 4) {
        const selectedPostIds = new Set(ranked.map((item) => item.post.id));
        const exploreCandidate = diversified.find(
          (item) => !selectedPostIds.has(item.post.id) && item.freshnessScore >= rankingWeights.exploreMinFreshness
        );
        if (exploreCandidate) {
          ranked[ranked.length - 1] = {
            ...exploreCandidate,
            recommendation: {
              reasonCode: 'explore',
              reasonText: '为你探索更多新内容',
            },
          };
        }
      }

      pagePosts = ranked.map((item) => item.post);
      recommendationByPostId = new Map(ranked.map((item) => [item.post.id, item.recommendation]));

      res.json({
        mode: requestedMode,
        effectiveMode,
        rankingExperiment: {
          bucket: experimentBucket,
          weightsVersion: FEED_RANKING_WEIGHTS_VERSION,
        },
        posts: pagePosts.map((post) =>
          mapPost(
            post,
            followingSet,
            likedPostIds,
            repostedPostIds,
            savedPostIds,
            hiddenPostIds,
            recommendationByPostId.get(post.id)
          )
        ),
        nextCursor: hasMore ? pagePosts[pagePosts.length - 1]?.createdAt.toISOString() ?? null : null,
      });
      return;
    }

    const hasMore = sourcePosts.length > limit;
    pagePosts = hasMore ? sourcePosts.slice(0, limit) : sourcePosts;

    const mappedPosts = pagePosts.map((post) =>
      mapPost(post, followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds)
    );

    res.json({
      mode: requestedMode,
      effectiveMode,
      rankingExperiment: null,
      posts: mappedPosts,
      nextCursor: hasMore ? pagePosts[pagePosts.length - 1]?.createdAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF feed error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/events', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const viewerId = (req as BFFAuthRequest).user?.userId;
    const body = (req.body ?? {}) as {
      sessionId?: unknown;
      sessionID?: unknown;
      eventType?: unknown;
      postID?: unknown;
      postId?: unknown;
      feedMode?: unknown;
      position?: unknown;
      metadata?: unknown;
    };

    const sessionId = normalizeFeedEventSessionID(body.sessionId ?? body.sessionID);
    if (!sessionId) {
      res.status(400).json({ error: 'sessionId is required' });
      return;
    }

    const eventType = normalizeFeedEventType(body.eventType);
    if (!eventType) {
      res.status(400).json({ error: 'eventType is invalid' });
      return;
    }

    const feedMode = normalizeOptionalFeedMode(body.feedMode);
    if (feedMode === 'invalid') {
      res.status(400).json({ error: 'feedMode is invalid' });
      return;
    }

    const position = normalizeFeedEventPosition(body.position);
    if (position === 'invalid') {
      res.status(400).json({ error: 'position is invalid' });
      return;
    }

    const metadata = normalizeFeedEventMetadata(body.metadata);
    if (metadata === 'invalid') {
      res.status(400).json({ error: 'metadata is invalid' });
      return;
    }

    let persistedMetadata: Prisma.InputJsonValue | undefined = metadata ?? undefined;
    if (feedMode === 'recommended') {
      const eventBucket = resolveFeedExperimentBucket(req, viewerId);
      const metadataObject: Prisma.JsonObject =
        metadata && typeof metadata === 'object' && !Array.isArray(metadata)
          ? { ...(metadata as Prisma.JsonObject) }
          : {};
      metadataObject.experimentBucket = eventBucket;
      metadataObject.weightsVersion = FEED_RANKING_WEIGHTS_VERSION;
      persistedMetadata = metadataObject;
    }

    const rawPostId =
      typeof body.postID === 'string'
        ? body.postID.trim()
        : typeof body.postId === 'string'
          ? body.postId.trim()
          : '';
    const postId = rawPostId || null;
    if (postId) {
      const exists = await prisma.post.findUnique({
        where: { id: postId },
        select: { id: true },
      });
      if (!exists) {
        res.status(404).json({ error: 'Post not found' });
        return;
      }
    }

    await prisma.feedEvent.create({
      data: {
        userId: viewerId ?? null,
        sessionId,
        eventType,
        postId,
        feedMode,
        position,
        metadata: persistedMetadata,
      },
    });

    res.status(201).json({ success: true });
  } catch (error) {
    console.error('BFF feed event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/feed/experiments/summary', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    if (authReq.user?.role !== 'admin') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const windowHours = normalizeLimit(req.query.windowHours, 24, 168);
    const since = new Date(Date.now() - windowHours * 60 * 60 * 1000);

    const rows = await prisma.$queryRaw<
      Array<{ bucket: string | null; event_type: string; count: bigint }>
    >`
      SELECT
        COALESCE(metadata->>'experimentBucket', 'unknown') AS bucket,
        event_type,
        COUNT(*)::bigint AS count
      FROM feed_events
      WHERE created_at >= ${since}
      GROUP BY 1, 2
      ORDER BY 1, 2
    `;

    const summary = new Map<
      string,
      {
        counts: Record<string, number>;
      }
    >();

    for (const row of rows) {
      const bucket = (row.bucket || 'unknown').trim() || 'unknown';
      const existing = summary.get(bucket) || { counts: {} };
      existing.counts[row.event_type] = Number(row.count || 0n);
      summary.set(bucket, existing);
    }

    const buckets = Array.from(summary.entries()).map(([bucket, data]) => {
      const impressions = data.counts.feed_impression || 0;
      const opens = data.counts.feed_open_post || 0;
      const likes = data.counts.feed_like || 0;
      const saves = data.counts.feed_save || 0;
      const shares = data.counts.feed_share || 0;
      const hides = data.counts.feed_hide || 0;

      const safeRate = (num: number, den: number): number => {
        if (den <= 0) return 0;
        return Number((num / den).toFixed(4));
      };

      return {
        bucket,
        counts: data.counts,
        metrics: {
          ctr: safeRate(opens, impressions),
          likeRate: safeRate(likes, impressions),
          saveRate: safeRate(saves, impressions),
          shareRate: safeRate(shares, impressions),
          hideRate: safeRate(hides, impressions),
        },
      };
    });

    res.json({
      windowHours,
      since: since.toISOString(),
      generatedAt: new Date().toISOString(),
      weightsVersion: FEED_RANKING_WEIGHTS_VERSION,
      buckets,
    });
  } catch (error) {
    console.error('BFF feed experiments summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/feed/search', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId;
    const query = String(req.query.q || '').trim();
    const limit = normalizeLimit(req.query.limit, 20, 50);

    if (!query) {
      res.json({ posts: [], nextCursor: null });
      return;
    }

    const posts = await prisma.post.findMany({
      where: {
        visibility: 'public',
        squadId: null,
        ...(viewerId
          ? {
              hides: {
                none: { userId: viewerId },
              },
            }
          : {}),
        OR: [
          { content: { contains: query, mode: 'insensitive' } },
          {
            user: {
              OR: [
                { username: { contains: query, mode: 'insensitive' } },
                { displayName: { contains: query, mode: 'insensitive' } },
              ],
            },
          },
        ],
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit,
    });

    const authorIds = Array.from(new Set(posts.map((post) => post.user.id)));
    const postIds = posts.map((post) => post.id);
    const [followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds] = await Promise.all([
      buildFollowingMap(viewerId, authorIds),
      buildLikedPostMap(viewerId, postIds),
      buildRepostedPostMap(viewerId, postIds),
      buildSavedPostMap(viewerId, postIds),
      buildHiddenPostMap(viewerId, postIds),
    ]);

    res.json({
      posts: posts.map((post) =>
        mapPost(post, followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds)
      ),
      nextCursor: null,
    });
  } catch (error) {
    console.error('BFF feed search error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/feed/posts/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId;
    const postID = String(req.params.id || '').trim();

    if (!postID) {
      res.status(400).json({ error: 'Post id is required' });
      return;
    }

    const post = await prisma.post.findFirst({
      where: {
        id: postID,
        visibility: 'public',
        squadId: null,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!post) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    const [followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds] = await Promise.all([
      buildFollowingMap(viewerId, [post.user.id]),
      buildLikedPostMap(viewerId, [post.id]),
      buildRepostedPostMap(viewerId, [post.id]),
      buildSavedPostMap(viewerId, [post.id]),
      buildHiddenPostMap(viewerId, [post.id]),
    ]);

    res.json(mapPost(post, followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds));
  } catch (error) {
    console.error('BFF post detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/search', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const query = String(req.query.q || '').trim();
    const limit = normalizeLimit(req.query.limit, 20, 50);
    if (!query) {
      res.json([]);
      return;
    }

    const users = await prisma.user.findMany({
      where: {
        isActive: true,
        id: { not: userId },
        OR: [
          { username: { contains: query, mode: 'insensitive' } },
          { displayName: { contains: query, mode: 'insensitive' } },
        ],
      },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
      },
      orderBy: [{ username: 'asc' }],
      take: limit,
    });

    const followingSet = await buildFollowingMap(
      userId,
      users.map((user) => user.id)
    );

    res.json(users.map((user) => toUserSummary(user, followingSet.has(user.id))));
  } catch (error) {
    console.error('BFF user search error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/:id/profile', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const viewerId = requireAuth(req as BFFAuthRequest, res);
    if (!viewerId) return;

    const targetUserId = req.params.id as string;
    const user = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: {
        id: true,
        username: true,
        displayName: true,
        bio: true,
        avatarUrl: true,
        favoriteGenres: true,
        isFollowersListPublic: true,
        isFollowingListPublic: true,
        isActive: true,
      },
    });

    if (!user || !user.isActive) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const [followersCount, followingCount, postsCount, followRow, friendIds] = await Promise.all([
      prisma.follow.count({
        where: {
          followingId: targetUserId,
          type: 'user',
        },
      }),
      prisma.follow.count({
        where: {
          followerId: targetUserId,
          type: 'user',
          followingId: { not: null },
        },
      }),
      prisma.post.count({
        where: {
          userId: targetUserId,
          visibility: 'public',
        },
      }),
      viewerId === targetUserId
        ? Promise.resolve(null)
        : prisma.follow.findUnique({
            where: {
              followerId_followingId: {
                followerId: viewerId,
                followingId: targetUserId,
              },
            },
            select: { id: true },
          }),
      buildFriendUserIds(targetUserId),
    ]);

    const canViewFollowersList = viewerId === targetUserId || user.isFollowersListPublic;
    const canViewFollowingList = viewerId === targetUserId || user.isFollowingListPublic;

    res.json({
      id: user.id,
      username: user.username,
      displayName: user.displayName || user.username,
      bio: user.bio || '',
      avatarURL: user.avatarUrl,
      tags: user.favoriteGenres,
      isFollowersListPublic: user.isFollowersListPublic,
      isFollowingListPublic: user.isFollowingListPublic,
      canViewFollowersList,
      canViewFollowingList,
      followersCount,
      followingCount,
      friendsCount: friendIds.size,
      postsCount,
      isFollowing: Boolean(followRow),
    });
  } catch (error) {
    console.error('BFF user profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/:id/followers', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const viewerId = requireAuth(req as BFFAuthRequest, res);
    if (!viewerId) return;

    const targetUserId = req.params.id as string;
    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);

    const user = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true, isActive: true, isFollowersListPublic: true },
    });
    if (!user || !user.isActive) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const canView = viewerId === targetUserId || user.isFollowersListPublic;
    if (!canView) {
      res.status(403).json({ error: 'Followers list is private' });
      return;
    }

    const rows = await prisma.follow.findMany({
      where: {
        followingId: targetUserId,
        type: 'user',
        ...(cursorDate
          ? {
              createdAt: {
                lt: cursorDate,
              },
            }
          : {}),
      },
      include: {
        follower: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = rows.length > limit;
    const pageRows = hasMore ? rows.slice(0, limit) : rows;
    const followingSet = await buildFollowingMap(
      viewerId,
      pageRows.map((row) => row.follower.id)
    );

    res.json({
      users: pageRows.map((row) => toUserSummary(row.follower, followingSet.has(row.follower.id))),
      nextCursor: hasMore ? pageRows[pageRows.length - 1]?.createdAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF followers list error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/:id/following', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const viewerId = requireAuth(req as BFFAuthRequest, res);
    if (!viewerId) return;

    const targetUserId = req.params.id as string;
    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);

    const user = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true, isActive: true, isFollowingListPublic: true },
    });
    if (!user || !user.isActive) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const canView = viewerId === targetUserId || user.isFollowingListPublic;
    if (!canView) {
      res.status(403).json({ error: 'Following list is private' });
      return;
    }

    const rows = await prisma.follow.findMany({
      where: {
        followerId: targetUserId,
        type: 'user',
        followingId: { not: null },
        ...(cursorDate
          ? {
              createdAt: {
                lt: cursorDate,
              },
            }
          : {}),
      },
      include: {
        following: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
            isActive: true,
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = rows.length > limit;
    const pageRows = hasMore ? rows.slice(0, limit) : rows;
    const users = pageRows.map((row) => row.following).filter((target): target is BasicUser & { isActive: boolean } => Boolean(target && target.isActive));
    const followingSet = await buildFollowingMap(
      viewerId,
      users.map((target) => target.id)
    );

    res.json({
      users: users.map((target) => toUserSummary(target, followingSet.has(target.id))),
      nextCursor: hasMore ? pageRows[pageRows.length - 1]?.createdAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF following list error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/:id/friends', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const viewerId = requireAuth(req as BFFAuthRequest, res);
    if (!viewerId) return;

    const targetUserId = req.params.id as string;
    const user = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true, isActive: true },
    });
    if (!user || !user.isActive) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const friendIds = Array.from(await buildFriendUserIds(targetUserId));
    if (friendIds.length === 0) {
      res.json({ users: [], nextCursor: null });
      return;
    }

    const users = await prisma.user.findMany({
      where: {
        id: { in: friendIds },
        isActive: true,
      },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
      },
      orderBy: [{ username: 'asc' }],
    });

    const followingSet = await buildFollowingMap(viewerId, users.map((item) => item.id));
    res.json({
      users: users.map((item) => toUserSummary(item, followingSet.has(item.id))),
      nextCursor: null,
    });
  } catch (error) {
    console.error('BFF friends list error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/:id/posts', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = requireAuth(authReq, res);
    if (!viewerId) return;

    const targetUserId = req.params.id as string;
    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);

    const targetUser = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true, isActive: true },
    });

    if (!targetUser || !targetUser.isActive) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const posts = await prisma.post.findMany({
      where: {
        userId: targetUserId,
        visibility: 'public',
        squadId: null,
        ...(cursorDate
          ? {
              createdAt: {
                lt: cursorDate,
              },
            }
          : {}),
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = posts.length > limit;
    const pagePosts = hasMore ? posts.slice(0, limit) : posts;
    const postIds = pagePosts.map((post) => post.id);

    const [followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds] = await Promise.all([
      buildFollowingMap(viewerId, [targetUserId]),
      buildLikedPostMap(viewerId, postIds),
      buildRepostedPostMap(viewerId, postIds),
      buildSavedPostMap(viewerId, postIds),
      buildHiddenPostMap(viewerId, postIds),
    ]);

    res.json({
      posts: pagePosts.map((post) =>
        mapPost(post, followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds)
      ),
      nextCursor: hasMore ? pagePosts[pagePosts.length - 1]?.createdAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF user posts error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/notifications/unread-count', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const counts = await getCommunityNotificationCounts(userId);

    res.json({
      total: counts.total,
      follows: counts.follows,
      likes: counts.likes,
      comments: counts.comments,
      squadInvites: counts.squadInvites,
    });
  } catch (error) {
    console.error('BFF unread notifications error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/notifications/read', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = req.body as { notificationId?: unknown; notificationIds?: unknown; notificationType?: unknown };
    const inputIds: unknown[] = [];
    if (typeof body.notificationId === 'string') {
      inputIds.push(body.notificationId);
    }
    if (Array.isArray(body.notificationIds)) {
      inputIds.push(...body.notificationIds);
    }
    const inboxIds = Array.from(
      new Set(
        inputIds
          .filter((value): value is string => typeof value === 'string')
          .map((value) => value.trim())
          .filter(Boolean)
      )
    );
    const notificationType = parseNotificationType(body.notificationType);

    if (inboxIds.length === 0 && !notificationType) {
      res.status(400).json({ error: 'notificationId or notificationType is required' });
      return;
    }

    const now = new Date();
    let updatedByInboxIds = 0;
    if (inboxIds.length > 0) {
      updatedByInboxIds = await notificationCenterService.markInboxRead(userId, inboxIds);
    }

    let updatedByType = 0;
    if (notificationType) {
      const sources = COMMUNITY_NOTIFICATION_TYPE_SOURCES[notificationType];
      if (sources.length > 0) {
        updatedByType = await prisma.$executeRaw`
          UPDATE notification_inbox
          SET is_read = TRUE,
              read_at = ${now},
              updated_at = ${now}
          WHERE user_id = ${userId}
            AND is_read = FALSE
            AND type = 'community_interaction'
            AND (metadata ->> 'source') IN (${Prisma.join(sources)})
        `;
      }
    }

    res.json({
      success: true,
      readCount: updatedByInboxIds + toPositiveSafeInteger(updatedByType),
      readAt: now,
    });
  } catch (error) {
    console.error('BFF mark notification read error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/notifications', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const limit = normalizeLimit(req.query.limit, 20, 50);
    const fetchTake = Math.min(Math.max(limit * 6, limit), 300);
    const [counts, inboxRows] = await Promise.all([
      getCommunityNotificationCounts(userId),
      prisma.notificationInboxItem.findMany({
        where: {
          userId,
          type: 'community_interaction',
        },
        orderBy: { createdAt: 'desc' },
        take: fetchTake,
        select: {
          id: true,
          type: true,
          body: true,
          metadata: true,
          isRead: true,
          createdAt: true,
        },
      }),
    ]);

    const contexts = inboxRows
      .map((row) => toCommunityNotificationContext(row))
      .filter((item): item is CommunityNotificationContext => item !== null)
      .slice(0, limit);

    const actorIds = Array.from(
      new Set(
        contexts
          .map((item) => item.actorUserId)
          .filter((id): id is string => Boolean(id && id !== userId))
      )
    );
    const [followingSet, actors] = actorIds.length > 0
      ? await Promise.all([
          buildFollowingMap(userId, actorIds),
          prisma.user.findMany({
            where: {
              id: { in: actorIds },
            },
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          }),
        ])
      : [new Set<string>(), []];

    const actorMap = new Map(
      actors.map((user) => [user.id, toUserSummary(user, followingSet.has(user.id))] as const)
    );

    const items = contexts.map((item) => {
      const actor = item.actorUserId ? actorMap.get(item.actorUserId) ?? null : null;
      const target = item.target
        ? {
            type: item.target.type,
            id: item.target.id,
            title: item.target.title ?? (item.target.type === 'user' ? actor?.displayName ?? null : null),
          }
        : null;
      return {
        id: item.inboxId,
        type: item.type,
        createdAt: item.createdAt,
        isRead: item.isRead,
        actor,
        text: item.text,
        target,
      };
    });

    res.json({
      unreadCount: counts.total,
      items,
    });
  } catch (error) {
    console.error('BFF notifications error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/squads/recommended', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const limit = normalizeLimit(req.query.limit, 20, 50);
    const squads = await prisma.squad.findMany({
      where: {
        OR: [
          { isPublic: true },
          { members: { some: { userId } } },
        ],
      },
      include: {
        _count: {
          select: {
            members: true,
          },
        },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: {
            content: true,
            createdAt: true,
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }],
      take: limit,
    });

    const squadIds = squads.map((squad) => squad.id);
    const memberships = await prisma.squadMember.findMany({
      where: {
        userId,
        squadId: { in: squadIds },
      },
      select: { squadId: true },
    });
    const memberSet = new Set(memberships.map((item) => item.squadId));

    res.json(
      squads.map((squad) => ({
        id: squad.id,
        name: squad.name,
        description: squad.description,
        avatarURL: squad.avatarUrl,
        bannerURL: squad.bannerUrl,
        isPublic: squad.isPublic,
        memberCount: squad._count.members,
        isMember: memberSet.has(squad.id),
        lastMessage: squad.messages[0]?.content ?? null,
        updatedAt: squad.messages[0]?.createdAt ?? squad.updatedAt,
      }))
    );
  } catch (error) {
    console.error('BFF recommended squads error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/squads/mine', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squads = await prisma.squad.findMany({
      where: {
        members: {
          some: { userId },
        },
      },
      include: {
        _count: {
          select: {
            members: true,
          },
        },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: {
            content: true,
            createdAt: true,
          },
        },
      },
      orderBy: [{ updatedAt: 'desc' }, { createdAt: 'desc' }],
    });

    res.json(
      squads.map((squad) => ({
        id: squad.id,
        name: squad.name,
        description: squad.description,
        avatarURL: squad.avatarUrl,
        bannerURL: squad.bannerUrl,
        isPublic: squad.isPublic,
        memberCount: squad._count.members,
        isMember: true,
        lastMessage: squad.messages[0]?.content ?? null,
        updatedAt: squad.messages[0]?.createdAt ?? squad.updatedAt,
      }))
    );
  } catch (error) {
    console.error('BFF my squads error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/squads/:id/profile', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const [squad, memberRow] = await Promise.all([
      prisma.squad.findUnique({
        where: { id: squadId },
        include: {
          leader: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
          members: {
            orderBy: { joinedAt: 'asc' },
            include: {
              user: {
                select: {
                  id: true,
                  username: true,
                  displayName: true,
                  avatarUrl: true,
                },
              },
            },
            take: 80,
          },
          messages: {
            orderBy: { createdAt: 'desc' },
            take: 20,
            include: {
              user: {
                select: {
                  id: true,
                  username: true,
                  displayName: true,
                  avatarUrl: true,
                },
              },
            },
          },
          activities: {
            orderBy: [{ date: 'desc' }, { createdAt: 'desc' }],
            take: 12,
            include: {
              createdBy: {
                select: {
                  id: true,
                  username: true,
                  displayName: true,
                  avatarUrl: true,
                },
              },
            },
          },
          _count: {
            select: {
              members: true,
            },
          },
        },
      }),
      prisma.squadMember.findUnique({
        where: {
          squadId_userId: {
            squadId,
            userId,
          },
        },
        select: { id: true, role: true, nickname: true, notificationsEnabled: true },
      }),
    ]);

    if (!squad) {
      res.status(404).json({ error: 'Squad not found' });
      return;
    }

    if (!squad.isPublic && !memberRow) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const memberNicknameMap = new Map(squad.members.map((member) => [member.userId, member.nickname]));
    const memberIds = squad.members.map((member) => member.user.id);
    const followingSet = await buildFollowingMap(userId, [
      squad.leader.id,
      ...memberIds,
      ...squad.messages.map((message) => message.user.id),
      ...squad.activities.map((activity) => activity.createdBy.id),
    ]);

    const leaderNickname = memberNicknameMap.get(squad.leader.id);

    res.json({
      id: squad.id,
      name: squad.name,
      description: squad.description,
      avatarURL: squad.avatarUrl,
      bannerURL: squad.bannerUrl,
      notice: squad.notice || '',
      qrCodeURL: squad.qrCodeUrl,
      isPublic: squad.isPublic,
      maxMembers: squad.maxMembers,
      memberCount: squad._count.members,
      isMember: Boolean(memberRow),
      canEditGroup: Boolean(memberRow) && (canManageSquad(memberRow?.role) || squad.leaderId === userId),
      myRole: memberRow?.role ?? null,
      myNickname: memberRow?.nickname ?? null,
      myNotificationsEnabled: memberRow?.notificationsEnabled ?? null,
      leader: toUserSummaryWithNickname(
        squad.leader,
        followingSet.has(squad.leader.id),
        leaderNickname
      ),
      members: squad.members.map((member) => ({
        ...toUserSummaryWithNickname(member.user, followingSet.has(member.user.id), member.nickname),
        role: member.role,
        nickname: member.nickname,
        isCaptain: member.userId === squad.leaderId,
        isAdmin: canManageSquad(member.role),
      })),
      lastMessage: squad.messages[0]?.content ?? null,
      updatedAt: squad.messages[0]?.createdAt ?? squad.updatedAt,
      recentMessages: squad.messages.map((message) => ({
        id: message.id,
        content: message.content,
        createdAt: message.createdAt,
        sender: toUserSummaryWithNickname(
          message.user,
          followingSet.has(message.user.id),
          memberNicknameMap.get(message.user.id)
        ),
      })),
      activities: squad.activities.map((activity) => ({
        id: activity.id,
        title: activity.title,
        description: activity.description,
        location: activity.location,
        date: activity.date,
        createdBy: toUserSummary(activity.createdBy, followingSet.has(activity.createdBy.id)),
      })),
    });
  } catch (error) {
    console.error('BFF squad profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/squads/:id/join', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const squad = await prisma.squad.findUnique({
      where: { id: squadId },
      select: {
        id: true,
        isPublic: true,
        maxMembers: true,
      },
    });

    if (!squad) {
      res.status(404).json({ error: 'Squad not found' });
      return;
    }

    if (!squad.isPublic) {
      res.status(403).json({ error: 'This squad requires invitation' });
      return;
    }

    const existing = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId,
          userId,
        },
      },
      select: { id: true },
    });

    if (existing) {
      res.json({ success: true, isMember: true });
      return;
    }

    const count = await prisma.squadMember.count({
      where: { squadId },
    });
    if (count >= squad.maxMembers) {
      res.status(400).json({ error: 'Squad is full' });
      return;
    }

    const membership = await prisma.squadMember.create({
      data: {
        squadId,
        userId,
        role: 'member',
        lastReadAt: new Date(),
      },
      select: {
        id: true,
      },
    });

    try {
      await tencentIMGroupService.addGroupMembers(squadId, [userId], 'public squad join');
    } catch (error) {
      await prisma.squadMember.delete({
        where: { id: membership.id },
      });
      throw error;
    }

    res.status(201).json({ success: true, isMember: true });
  } catch (error) {
    console.error('BFF join squad error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/squads/:id/leave', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const squad = await prisma.squad.findUnique({
      where: { id: squadId },
      select: { id: true, leaderId: true },
    });

    if (!squad) {
      res.status(404).json({ error: 'Squad not found' });
      return;
    }

    if (squad.leaderId === userId) {
      res.status(400).json({ error: 'Leader cannot leave squad before transfer ownership' });
      return;
    }

    const existingMembership = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId,
          userId,
        },
      },
      select: {
        userId: true,
        role: true,
        nickname: true,
        notificationsEnabled: true,
        lastReadAt: true,
      },
    });

    if (!existingMembership) {
      res.status(400).json({ error: 'You are not a squad member' });
      return;
    }

    const leaveResult = await prisma.$transaction(async (tx) => {
      await tx.squadMember.delete({
        where: {
          squadId_userId: {
            squadId,
            userId,
          },
        },
      });

      const message = await tx.squadMessage.create({
        data: {
          squadId,
          userId,
          content: '离开了小队',
          type: 'system',
        },
      });

      return { messageId: message.id };
    });

    try {
      await tencentIMGroupService.removeGroupMembers(squadId, [userId], 'member left squad');
    } catch (error) {
      await prisma.$transaction(async (tx) => {
        await tx.squadMessage.delete({
          where: { id: leaveResult.messageId },
        });
        await tx.squadMember.create({
          data: {
            squadId,
            userId: existingMembership.userId,
            role: existingMembership.role,
            nickname: existingMembership.nickname,
            notificationsEnabled: existingMembership.notificationsEnabled,
            lastReadAt: existingMembership.lastReadAt,
          },
        });
      });
      throw error;
    }

    res.json({ success: true });
  } catch (error) {
    console.error('BFF leave squad error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/squads/:id/disband', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const [squad, membership] = await Promise.all([
      prisma.squad.findUnique({
        where: { id: squadId },
        select: { id: true, leaderId: true },
      }),
      prisma.squadMember.findUnique({
        where: {
          squadId_userId: {
            squadId,
            userId,
          },
        },
        select: { role: true },
      }),
    ]);

    if (!squad) {
      res.status(404).json({ error: 'Squad not found' });
      return;
    }

    if (!membership || squad.leaderId !== userId || membership.role !== 'leader') {
      res.status(403).json({ error: 'Only squad leader can disband squad' });
      return;
    }

    await tencentIMGroupService.dismissSquadGroup(squadId);

    await prisma.squad.delete({
      where: { id: squadId },
      select: { id: true },
    });

    res.json({ success: true });
  } catch (error) {
    console.error('BFF disband squad error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/squads', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = req.body as {
      name?: unknown;
      description?: unknown;
      isPublic?: unknown;
      bannerURL?: unknown;
      memberIds?: unknown;
    };

    const normalizedMemberIds = Array.isArray(body.memberIds)
      ? Array.from(
          new Set(
            body.memberIds
              .filter((item): item is string => typeof item === 'string')
              .map((item) => item.trim())
              .filter((item) => item.length > 0 && item !== userId)
          )
        )
      : [];

    if (normalizedMemberIds.length < MIN_SQUAD_INVITED_MEMBERS) {
      res.status(400).json({ error: '创建小队至少需要 3 人，请至少选择 2 位好友' });
      return;
    }

    if (normalizedMemberIds.length > 0) {
      const friendIds = await buildFriendUserIds(userId, normalizedMemberIds);
      if (friendIds.size !== normalizedMemberIds.length) {
        res.status(403).json({ error: '只能从好友列表中选择小队成员' });
        return;
      }
    }

    const requestedName = typeof body.name === 'string' ? body.name.trim() : '';
    const requestedDescription = typeof body.description === 'string' ? body.description.trim() : '';
    const requestedIsPublic = typeof body.isPublic === 'boolean' ? body.isPublic : false;
    const requestedBannerURL = typeof body.bannerURL === 'string' ? body.bannerURL.trim() : '';
    const fallbackName = `${userId}+${Date.now()}创建的小队`;
    const finalName = requestedName || fallbackName;

    const created = await prisma.$transaction(async (tx) => {
      const squad = await tx.squad.create({
        data: {
          name: finalName,
          description: requestedDescription || null,
          bannerUrl: requestedBannerURL || null,
          leaderId: userId,
          isPublic: requestedIsPublic,
          maxMembers: 50,
        },
        select: {
          id: true,
          name: true,
          avatarUrl: true,
          updatedAt: true,
        },
      });

      await tx.squadMember.create({
        data: {
          squadId: squad.id,
          userId,
          role: 'leader',
          lastReadAt: new Date(),
        },
        select: { id: true },
      });

      if (normalizedMemberIds.length > 0) {
        await tx.squadMember.createMany({
          data: normalizedMemberIds.map((memberId) => ({
            squadId: squad.id,
            userId: memberId,
            role: 'member',
            lastReadAt: new Date(),
          })),
        });
      }

      return squad;
    });

    try {
      await tencentIMGroupService.ensureSquadGroupById(created.id);
    } catch (error) {
      await prisma.$transaction(async (tx) => {
        await tx.squadMember.deleteMany({
          where: { squadId: created.id },
        });
        await tx.squad.delete({
          where: { id: created.id },
        });
      });
      throw error;
    }

    res.status(201).json({
      id: created.id,
      type: 'group',
      title: created.name,
      avatarURL: created.avatarUrl,
      lastMessage: '暂无消息',
      lastMessageSenderID: null,
      unreadCount: 0,
      updatedAt: created.updatedAt,
      peer: null,
    });
  } catch (error) {
    console.error('BFF create squad error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post(
  '/squads/:id/avatar',
  optionalAuth,
  avatarUpload.single('avatar'),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const userId = requireAuth(req as BFFAuthRequest, res);
      if (!userId) return;

      const squadId = req.params.id as string;
      const file = (req as Request & { file?: Express.Multer.File }).file;
      if (!file) {
        res.status(400).json({ error: 'No file uploaded' });
        return;
      }

      const membership = await prisma.squadMember.findUnique({
        where: {
          squadId_userId: {
            squadId,
            userId,
          },
        },
        select: {
          role: true,
        },
      });

      if (!membership || !canManageSquad(membership.role)) {
        res.status(403).json({ error: 'Only admin/captain can edit squad avatar' });
        return;
      }

      const previousSquad = await prisma.squad.findUnique({
        where: { id: squadId },
        select: {
          avatarUrl: true,
        },
      });

      const avatarUrl = `/uploads/avatars/${file.filename}`;
      await prisma.squad.update({
        where: { id: squadId },
        data: { avatarUrl },
        select: { id: true },
      });

      try {
        await syncSquadGroupInfo(squadId);
      } catch (error) {
        await prisma.squad.update({
          where: { id: squadId },
          data: { avatarUrl: previousSquad?.avatarUrl || null },
          select: { id: true },
        });
        throw error;
      }

      res.status(201).json({ avatarURL: avatarUrl });
    } catch (error) {
      console.error('BFF upload squad avatar error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

router.patch('/squads/:id/my-settings', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const membership = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId,
          userId,
        },
      },
      select: {
        id: true,
        nickname: true,
        notificationsEnabled: true,
      },
    });

    if (!membership) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const body = req.body as { nickname?: unknown; notificationsEnabled?: unknown };
    const data: { nickname?: string | null; notificationsEnabled?: boolean } = {};

    if (typeof body.nickname === 'string') {
      const trimmed = body.nickname.trim();
      data.nickname = trimmed || null;
    }

    if (typeof body.notificationsEnabled === 'boolean') {
      data.notificationsEnabled = body.notificationsEnabled;
    }

    const updated =
      Object.keys(data).length === 0
        ? membership
        : await prisma.squadMember.update({
            where: {
              squadId_userId: {
                squadId,
                userId,
              },
            },
            data,
            select: {
              id: true,
              nickname: true,
              notificationsEnabled: true,
            },
          });

    res.json({
      success: true,
      nickname: updated.nickname,
      notificationsEnabled: updated.notificationsEnabled,
    });
  } catch (error) {
    console.error('BFF update squad my settings error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/squads/:id/manage', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const [squad, membership] = await Promise.all([
      prisma.squad.findUnique({
        where: { id: squadId },
        select: {
          id: true,
          leaderId: true,
          name: true,
          description: true,
          avatarUrl: true,
          bannerUrl: true,
          notice: true,
          qrCodeUrl: true,
          isPublic: true,
        },
      }),
      prisma.squadMember.findUnique({
        where: {
          squadId_userId: {
            squadId,
            userId,
          },
        },
        select: {
          role: true,
        },
      }),
    ]);

    if (!squad) {
      res.status(404).json({ error: 'Squad not found' });
      return;
    }

    if (!membership || (!canManageSquad(membership.role) && squad.leaderId !== userId)) {
      res.status(403).json({ error: 'Only admin/captain can edit group settings' });
      return;
    }

    const body = req.body as {
      name?: unknown;
      description?: unknown;
      isPublic?: unknown;
      avatarURL?: unknown;
      bannerURL?: unknown;
      notice?: unknown;
      qrCodeURL?: unknown;
    };

    const data: {
      name?: string;
      description?: string | null;
      isPublic?: boolean;
      avatarUrl?: string | null;
      bannerUrl?: string | null;
      notice?: string | null;
      qrCodeUrl?: string | null;
    } = {};

    if (typeof body.name === 'string') {
      const trimmedName = body.name.trim();
      if (!trimmedName) {
        res.status(400).json({ error: 'name cannot be empty' });
        return;
      }
      data.name = trimmedName;
    }

    if (typeof body.description === 'string') {
      const trimmedDescription = body.description.trim();
      data.description = trimmedDescription || null;
    }

    if (typeof body.isPublic === 'boolean') {
      data.isPublic = body.isPublic;
    }

    if (typeof body.avatarURL === 'string') {
      const trimmedAvatar = body.avatarURL.trim();
      data.avatarUrl = trimmedAvatar || null;
    }

    if (typeof body.bannerURL === 'string') {
      const trimmedBanner = body.bannerURL.trim();
      data.bannerUrl = trimmedBanner || null;
    }

    if (typeof body.notice === 'string') {
      const trimmedNotice = body.notice.trim();
      data.notice = trimmedNotice || null;
    }

    if (typeof body.qrCodeURL === 'string') {
      const trimmedQrCode = body.qrCodeURL.trim();
      data.qrCodeUrl = trimmedQrCode || null;
    }

    if (Object.keys(data).length > 0) {
      await prisma.squad.update({
        where: { id: squadId },
        data,
        select: { id: true },
      });

      try {
        await syncSquadGroupInfo(squadId);
      } catch (error) {
        await prisma.squad.update({
          where: { id: squadId },
          data: {
            name: squad.name,
            description: squad.description,
            avatarUrl: squad.avatarUrl,
            bannerUrl: squad.bannerUrl,
            notice: squad.notice,
            qrCodeUrl: squad.qrCodeUrl,
            isPublic: squad.isPublic,
          },
          select: { id: true },
        });
        throw error;
      }
    }

    res.json({ success: true });
  } catch (error) {
    console.error('BFF update squad manage error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/squads/:id/members/:memberUserId/role', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const memberUserId = req.params.memberUserId as string;
    const body = req.body as { role?: unknown };
    const nextRole = typeof body.role === 'string' ? body.role.trim() : '';

    if (!['leader', 'admin', 'member'].includes(nextRole)) {
      res.status(400).json({ error: 'role must be one of leader/admin/member' });
      return;
    }

    const [squad, operatorMembership, targetMembership] = await Promise.all([
      prisma.squad.findUnique({
        where: { id: squadId },
        select: { id: true, leaderId: true },
      }),
      prisma.squadMember.findUnique({
        where: {
          squadId_userId: {
            squadId,
            userId,
          },
        },
        select: { role: true },
      }),
      prisma.squadMember.findUnique({
        where: {
          squadId_userId: {
            squadId,
            userId: memberUserId,
          },
        },
        select: {
          id: true,
          role: true,
          lastReadAt: true,
        },
      }),
    ]);

    if (!squad) {
      res.status(404).json({ error: 'Squad not found' });
      return;
    }

    if (!operatorMembership || squad.leaderId !== userId) {
      res.status(403).json({ error: 'Only squad leader can update member role' });
      return;
    }

    if (!targetMembership) {
      res.status(404).json({ error: 'Squad member not found' });
      return;
    }

    if (memberUserId === userId && nextRole !== 'leader') {
      res.status(400).json({ error: 'Leader cannot change their own role directly' });
      return;
    }

    if (nextRole === 'leader') {
      if (memberUserId === squad.leaderId) {
        res.json({ success: true, role: 'leader' });
        return;
      }

      const previousTargetRole = targetMembership.role;
      await prisma.$transaction(async (tx) => {
        await tx.squad.update({
          where: { id: squadId },
          data: {
            leaderId: memberUserId,
          },
          select: { id: true },
        });
        await tx.squadMember.update({
          where: {
            squadId_userId: {
              squadId,
              userId,
            },
          },
          data: { role: 'member' },
          select: { id: true },
        });
        await tx.squadMember.update({
          where: {
            squadId_userId: {
              squadId,
              userId: memberUserId,
            },
          },
          data: { role: 'leader' },
          select: { id: true },
        });
      });

      try {
        await tencentIMGroupService.transferSquadGroupOwner(squadId, memberUserId);
      } catch (error) {
        await prisma.$transaction(async (tx) => {
          await tx.squad.update({
            where: { id: squadId },
            data: {
              leaderId: userId,
            },
            select: { id: true },
          });
          await tx.squadMember.update({
            where: {
              squadId_userId: {
                squadId,
                userId,
              },
            },
            data: { role: 'leader' },
            select: { id: true },
          });
          await tx.squadMember.update({
            where: {
              squadId_userId: {
                squadId,
                userId: memberUserId,
              },
            },
            data: { role: previousTargetRole },
            select: { id: true },
          });
        });
        throw error;
      }

      res.json({ success: true, role: 'leader' });
      return;
    }

    if (targetMembership.role === 'leader') {
      res.status(400).json({ error: 'Use leader transfer to update current leader role' });
      return;
    }

    if (targetMembership.role === nextRole) {
      res.json({ success: true, role: nextRole });
      return;
    }

    await prisma.squadMember.update({
      where: {
        squadId_userId: {
          squadId,
          userId: memberUserId,
        },
      },
      data: { role: nextRole },
      select: { id: true },
    });

    try {
      await tencentIMGroupService.updateGroupMemberRole(squadId, memberUserId, nextRole as 'admin' | 'member');
    } catch (error) {
      await prisma.squadMember.update({
        where: {
          squadId_userId: {
            squadId,
            userId: memberUserId,
          },
        },
        data: { role: targetMembership.role },
        select: { id: true },
      });
      throw error;
    }

    res.json({ success: true, role: nextRole });
  } catch (error) {
    console.error('BFF update squad member role error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/squads/:id/members/:memberUserId/remove', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const memberUserId = req.params.memberUserId as string;

    if (memberUserId === userId) {
      res.status(400).json({ error: 'Use leave action to quit squad yourself' });
      return;
    }

    const [squad, operatorMembership, targetMembership] = await Promise.all([
      prisma.squad.findUnique({
        where: { id: squadId },
        select: { id: true, leaderId: true },
      }),
      prisma.squadMember.findUnique({
        where: {
          squadId_userId: {
            squadId,
            userId,
          },
        },
        select: { role: true },
      }),
      prisma.squadMember.findUnique({
        where: {
          squadId_userId: {
            squadId,
            userId: memberUserId,
          },
        },
        select: {
          userId: true,
          role: true,
          nickname: true,
          notificationsEnabled: true,
          lastReadAt: true,
        },
      }),
    ]);

    if (!squad) {
      res.status(404).json({ error: 'Squad not found' });
      return;
    }

    if (!targetMembership) {
      res.status(404).json({ error: 'Squad member not found' });
      return;
    }

    if (!operatorMembership || !canRemoveSquadMember(operatorMembership.role, targetMembership.role)) {
      res.status(403).json({ error: 'You do not have permission to remove this member' });
      return;
    }

    const removedMember = targetMembership;
    const removeResult = await prisma.$transaction(async (tx) => {
      await tx.squadMember.delete({
        where: {
          squadId_userId: {
            squadId,
            userId: memberUserId,
          },
        },
      });

      const message = await tx.squadMessage.create({
        data: {
          squadId,
          userId,
          content: '移除了小队成员',
          type: 'system',
        },
      });

      return { messageId: message.id };
    });

    try {
      await tencentIMGroupService.removeGroupMembers(squadId, [memberUserId], 'removed by squad manager');
    } catch (error) {
      await prisma.$transaction(async (tx) => {
        await tx.squadMessage.delete({
          where: { id: removeResult.messageId },
        });
        await tx.squadMember.create({
          data: {
            squadId,
            userId: removedMember.userId,
            role: removedMember.role,
            nickname: removedMember.nickname,
            notificationsEnabled: removedMember.notificationsEnabled,
            lastReadAt: removedMember.lastReadAt,
          },
        });
      });
      throw error;
    }

    res.json({ success: true });
  } catch (error) {
    console.error('BFF remove squad member error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/posts', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = (req.body ?? {}) as Record<string, unknown>;
    const { content, images, squadId, location } = body as {
      content?: string;
      images?: string[];
      squadId?: string;
      location?: string;
    };

    const normalizedImages = Array.isArray(images)
      ? images.filter((url): url is string => typeof url === 'string' && !!url.trim())
      : [];
    const normalizedLocation = typeof location === 'string' ? location.trim().slice(0, 160) : '';
    const normalizedBoundDjIDs = normalizePostBindingIDs(
      body.boundDjIDs ?? body.boundDjIds ?? body.boundDJIDs ?? body.bound_dj_ids
    );
    const normalizedBoundBrandIDs = normalizePostBindingIDs(
      body.boundBrandIDs ?? body.boundBrandIds ?? body.bound_brand_ids
    );
    const normalizedBoundEventIDs = normalizePostBindingIDs(
      body.boundEventIDs ?? body.boundEventIds ?? body.bound_event_ids
    );
    const displayPublishedAtInput =
      body.displayPublishedAt ??
      body.display_published_at ??
      body.publishedAt ??
      body.published_at ??
      body.publishAt ??
      body.publish_at;
    const parsedDisplayPublishedAt = parseFeedPostDateInput(displayPublishedAtInput);
    if (parsedDisplayPublishedAt === 'invalid') {
      res.status(400).json({ error: 'displayPublishedAt is invalid' });
      return;
    }
    const trimmed = String(content || '').trim();
    if (!trimmed && normalizedImages.length === 0) {
      res.status(400).json({ error: 'content or images is required' });
      return;
    }

    let linkedSquadId: string | null = null;
    if (typeof squadId === 'string' && squadId.trim()) {
      const squad = await prisma.squad.findUnique({
        where: { id: squadId.trim() },
        select: { id: true },
      });
      if (!squad) {
        res.status(404).json({ error: 'Squad not found' });
        return;
      }

      const membership = await prisma.squadMember.findUnique({
        where: {
          squadId_userId: {
            squadId: squad.id,
            userId,
          },
        },
        select: { id: true },
      });

      if (!membership) {
        res.status(403).json({ error: 'Join squad before posting to it' });
        return;
      }
      linkedSquadId = squad.id;
    }

    const created = await prisma.post.create({
      data: {
        userId,
        squadId: linkedSquadId,
        content: trimmed,
        images: normalizedImages,
        location: normalizedLocation || null,
        type: linkedSquadId ? 'squad' : 'general',
        visibility: 'public',
        boundDjIds: normalizedBoundDjIDs,
        boundBrandIds: normalizedBoundBrandIDs,
        boundEventIds: normalizedBoundEventIDs,
        displayPublishedAt: parsedDisplayPublishedAt || new Date(),
      } as any,
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
    });

    const followingSet = await buildFollowingMap(userId, [created.user.id]);
    const mapped = mapPost(created, followingSet, new Set<string>(), new Set<string>());

    void publishFavoritedEventNewsSafely({
      actorUserId: userId,
      postId: created.id,
      content: created.content,
      imageURLs: Array.isArray(created.images) ? created.images : [],
      boundEventIDs: Array.isArray((created as any).boundEventIds) ? ((created as any).boundEventIds as string[]) : [],
      occurredAt: created.displayPublishedAt ?? created.createdAt,
    });

    res.status(201).json(mapped);
  } catch (error) {
    console.error('BFF create post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/feed/posts/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const postId = req.params.id as string;
    const body = (req.body ?? {}) as Record<string, unknown>;
    const { content, images, location } = body as {
      content?: string;
      images?: string[];
      location?: string;
    };
    const boundDjIDs = body.boundDjIDs ?? body.boundDjIds ?? body.boundDJIDs ?? body.bound_dj_ids;
    const boundBrandIDs = body.boundBrandIDs ?? body.boundBrandIds ?? body.bound_brand_ids;
    const boundEventIDs = body.boundEventIDs ?? body.boundEventIds ?? body.bound_event_ids;
    const hasDisplayPublishedAt =
      Object.prototype.hasOwnProperty.call(body, 'displayPublishedAt') ||
      Object.prototype.hasOwnProperty.call(body, 'display_published_at') ||
      Object.prototype.hasOwnProperty.call(body, 'publishedAt') ||
      Object.prototype.hasOwnProperty.call(body, 'published_at') ||
      Object.prototype.hasOwnProperty.call(body, 'publishAt') ||
      Object.prototype.hasOwnProperty.call(body, 'publish_at');
    const displayPublishedAtInput =
      body.displayPublishedAt ??
      body.display_published_at ??
      body.publishedAt ??
      body.published_at ??
      body.publishAt ??
      body.publish_at;
    const parsedDisplayPublishedAt = parseFeedPostDateInput(displayPublishedAtInput);
    if (hasDisplayPublishedAt && parsedDisplayPublishedAt === 'invalid') {
      res.status(400).json({ error: 'displayPublishedAt is invalid' });
      return;
    }

    const hasContent = typeof content === 'string';
    const hasImages = Array.isArray(images);
    const hasLocation = typeof location === 'string';
    const hasBoundDjIDs = Array.isArray(boundDjIDs);
    const hasBoundBrandIDs = Array.isArray(boundBrandIDs);
    const hasBoundEventIDs = Array.isArray(boundEventIDs);
    if (
      !hasContent &&
      !hasImages &&
      !hasLocation &&
      !hasBoundDjIDs &&
      !hasBoundBrandIDs &&
      !hasBoundEventIDs &&
      !hasDisplayPublishedAt
    ) {
      res.status(400).json({ error: 'content, images, location, displayPublishedAt or binding fields is required' });
      return;
    }

    const existing = await prisma.post.findUnique({
      where: { id: postId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!existing) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    if (authReq.user?.role !== 'admin' && existing.userId !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const nextContent = hasContent ? String(content || '').trim() : existing.content;
    const nextImages = hasImages
      ? (images as unknown[])
          .filter((url): url is string => typeof url === 'string')
          .map((url) => url.trim())
          .filter(Boolean)
      : existing.images;

    if (!nextContent && nextImages.length === 0) {
      res.status(400).json({ error: 'content or images is required' });
      return;
    }

    const updateData: {
      content?: string;
      images?: string[];
      location?: string | null;
      boundDjIds?: string[];
      boundBrandIds?: string[];
      boundEventIds?: string[];
      displayPublishedAt?: Date;
    } = {};
    if (hasContent) {
      updateData.content = nextContent;
    }
    if (hasImages) {
      updateData.images = nextImages;
    }
    if (hasLocation) {
      const normalizedLocation = String(location || '').trim().slice(0, 160);
      updateData.location = normalizedLocation || null;
    }
    if (hasBoundDjIDs) {
      updateData.boundDjIds = normalizePostBindingIDs(boundDjIDs);
    }
    if (hasBoundBrandIDs) {
      updateData.boundBrandIds = normalizePostBindingIDs(boundBrandIDs);
    }
    if (hasBoundEventIDs) {
      updateData.boundEventIds = normalizePostBindingIDs(boundEventIDs);
    }
    if (hasDisplayPublishedAt) {
      const normalizedDisplayPublishedAt =
        parsedDisplayPublishedAt && parsedDisplayPublishedAt !== 'invalid'
          ? parsedDisplayPublishedAt
          : null;
      updateData.displayPublishedAt = normalizedDisplayPublishedAt || existing.createdAt;
    }

    const updated =
      Object.keys(updateData).length > 0
        ? await prisma.post.update({
            where: { id: postId },
            data: updateData as any,
            include: {
              user: {
                select: {
                  id: true,
                  username: true,
                  displayName: true,
                  avatarUrl: true,
                },
              },
              squad: {
                select: {
                  id: true,
                  name: true,
                  avatarUrl: true,
                },
              },
            },
          })
        : existing;

    if (hasImages) {
      const newImageSet = new Set(nextImages);
      const removedImages = existing.images.filter((url) => !newImageSet.has(url));
      if (removedImages.length > 0) {
        const { failedKeys } = await deletePostMediaFromOss(removedImages);
        if (failedKeys.length > 0) {
          console.warn('BFF update post OSS cleanup failed keys:', failedKeys);
        }
      }
    }

    const [followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds] = await Promise.all([
      buildFollowingMap(userId, [updated.user.id]),
      buildLikedPostMap(userId, [updated.id]),
      buildRepostedPostMap(userId, [updated.id]),
      buildSavedPostMap(userId, [updated.id]),
      buildHiddenPostMap(userId, [updated.id]),
    ]);
    const mapped = mapPost(updated, followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds);
    res.json(mapped);
  } catch (error) {
    console.error('BFF update post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/feed/posts/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const postId = req.params.id as string;
    const post = await prisma.post.findUnique({
      where: { id: postId },
      select: { id: true, userId: true, images: true },
    });

    if (!post) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    if (authReq.user?.role !== 'admin' && post.userId !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    await prisma.post.delete({ where: { id: postId } });

    const { deletedKeys, failedKeys } = await deletePostMediaFromOss(post.images);

    res.json({
      success: true,
      deletedPostId: postId,
      deletedMediaCount: deletedKeys.length,
      cleanupFailedCount: failedKeys.length,
      cleanupFailedKeys: failedKeys,
    });
  } catch (error) {
    console.error('BFF delete post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/posts/:id/like', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;
    const post = await prisma.post.findUnique({
      where: { id: postId },
      select: { id: true, userId: true, content: true },
    });
    if (!post) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    let createdLikeId: string | null = null;
    await prisma.$transaction(async (tx) => {
      const existing = await tx.postLike.findUnique({
        where: {
          postId_userId: {
            postId,
            userId,
          },
        },
      });

      if (!existing) {
        const createdLike = await tx.postLike.create({
          data: {
            postId,
            userId,
          },
          select: { id: true },
        });
        createdLikeId = createdLike.id;

        await tx.post.update({
          where: { id: postId },
          data: { likeCount: { increment: 1 } },
        });
      }
    });

    const hydrated = await prisma.post.findUnique({
      where: { id: postId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!hydrated) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    const [followingSet, repostedPostIds, savedPostIds, hiddenPostIds] = await Promise.all([
      buildFollowingMap(userId, [hydrated.user.id]),
      buildRepostedPostMap(userId, [postId]),
      buildSavedPostMap(userId, [postId]),
      buildHiddenPostMap(userId, [postId]),
    ]);
    const mapped = mapPost(hydrated, followingSet, new Set([postId]), repostedPostIds, savedPostIds, hiddenPostIds);

    if (createdLikeId && post.userId !== userId) {
      publishCommunityInteractionSafely({
        targetUserIds: [post.userId],
        title: '社区互动',
        body: '有人赞了你的动态',
        deeplink: `raver://community/post/${postId}`,
        metadata: {
          source: 'post_like',
          actorUserID: userId,
          postID: postId,
          postPreview: truncateText(post.content, 80) || null,
        },
        dedupeKey: `community:like:${createdLikeId}`,
      });
    }

    res.json(mapped);
  } catch (error) {
    console.error('BFF like post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/feed/posts/:id/like', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;

    await prisma.$transaction(async (tx) => {
      const existing = await tx.postLike.findUnique({
        where: {
          postId_userId: {
            postId,
            userId,
          },
        },
      });

      if (existing) {
        await tx.postLike.delete({ where: { id: existing.id } });
        await tx.post.update({
          where: { id: postId },
          data: {
            likeCount: {
              decrement: 1,
            },
          },
        });
      }
    });

    const hydrated = await prisma.post.findUnique({
      where: { id: postId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!hydrated) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    const [followingSet, repostedPostIds, savedPostIds, hiddenPostIds] = await Promise.all([
      buildFollowingMap(userId, [hydrated.user.id]),
      buildRepostedPostMap(userId, [postId]),
      buildSavedPostMap(userId, [postId]),
      buildHiddenPostMap(userId, [postId]),
    ]);
    const mapped = mapPost(hydrated, followingSet, new Set<string>(), repostedPostIds, savedPostIds, hiddenPostIds);
    res.json(mapped);
  } catch (error) {
    console.error('BFF unlike post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/posts/:id/repost', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;
    const post = await prisma.post.findUnique({ where: { id: postId }, select: { id: true } });
    if (!post) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    await prisma.$transaction(async (tx) => {
      const existing = await tx.postRepost.findUnique({
        where: {
          postId_userId: {
            postId,
            userId,
          },
        },
      });

      if (!existing) {
        await tx.postRepost.create({
          data: {
            postId,
            userId,
          },
        });
        await tx.post.update({
          where: { id: postId },
          data: {
            repostCount: {
              increment: 1,
            },
          },
        });
      }
    });

    const hydrated = await prisma.post.findUnique({
      where: { id: postId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!hydrated) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    const [followingSet, likedPostIds, savedPostIds, hiddenPostIds] = await Promise.all([
      buildFollowingMap(userId, [hydrated.user.id]),
      buildLikedPostMap(userId, [postId]),
      buildSavedPostMap(userId, [postId]),
      buildHiddenPostMap(userId, [postId]),
    ]);
    const mapped = mapPost(hydrated, followingSet, likedPostIds, new Set([postId]), savedPostIds, hiddenPostIds);
    res.json(mapped);
  } catch (error) {
    console.error('BFF repost post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/feed/posts/:id/repost', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;

    await prisma.$transaction(async (tx) => {
      const existing = await tx.postRepost.findUnique({
        where: {
          postId_userId: {
            postId,
            userId,
          },
        },
      });

      if (existing) {
        await tx.postRepost.delete({
          where: {
            id: existing.id,
          },
        });
        await tx.post.updateMany({
          where: {
            id: postId,
            repostCount: { gt: 0 },
          },
          data: {
            repostCount: {
              decrement: 1,
            },
          },
        });
      }
    });

    const hydrated = await prisma.post.findUnique({
      where: { id: postId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!hydrated) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    const [followingSet, likedPostIds, savedPostIds, hiddenPostIds] = await Promise.all([
      buildFollowingMap(userId, [hydrated.user.id]),
      buildLikedPostMap(userId, [postId]),
      buildSavedPostMap(userId, [postId]),
      buildHiddenPostMap(userId, [postId]),
    ]);
    const mapped = mapPost(hydrated, followingSet, likedPostIds, new Set<string>(), savedPostIds, hiddenPostIds);
    res.json(mapped);
  } catch (error) {
    console.error('BFF unrepost post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/posts/:id/save', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;
    const post = await prisma.post.findUnique({ where: { id: postId }, select: { id: true } });
    if (!post) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    await prisma.$transaction(async (tx) => {
      const existing = await tx.postSave.findUnique({
        where: {
          postId_userId: {
            postId,
            userId,
          },
        },
      });

      if (!existing) {
        await tx.postSave.create({
          data: {
            postId,
            userId,
          },
        });
        await tx.post.update({
          where: { id: postId },
          data: { saveCount: { increment: 1 } },
        });
      }
    });

    const mapped = await hydratePostForViewer(postId, userId);
    if (!mapped) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }
    res.json(mapped);
  } catch (error) {
    console.error('BFF save post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/feed/posts/:id/save', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;

    await prisma.$transaction(async (tx) => {
      const existing = await tx.postSave.findUnique({
        where: {
          postId_userId: {
            postId,
            userId,
          },
        },
      });

      if (existing) {
        await tx.postSave.delete({ where: { id: existing.id } });
        await tx.post.updateMany({
          where: {
            id: postId,
            saveCount: { gt: 0 },
          },
          data: { saveCount: { decrement: 1 } },
        });
      }
    });

    const mapped = await hydratePostForViewer(postId, userId);
    if (!mapped) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }
    res.json(mapped);
  } catch (error) {
    console.error('BFF unsave post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/posts/:id/share', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;
    const post = await prisma.post.findUnique({ where: { id: postId }, select: { id: true } });
    if (!post) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    const body = (req.body ?? {}) as Record<string, unknown>;
    const channel = normalizeShareChannel(body.channel);
    const status = normalizeShareStatus(body.status);

    await prisma.$transaction(async (tx) => {
      await tx.postShare.create({
        data: {
          postId,
          userId,
          channel,
          status,
        },
      });

      if (status === 'completed') {
        await tx.post.update({
          where: { id: postId },
          data: { shareCount: { increment: 1 } },
        });
      }
    });

    const mapped = await hydratePostForViewer(postId, userId);
    if (!mapped) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }
    res.json(mapped);
  } catch (error) {
    console.error('BFF share post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/posts/:id/hide', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;
    const post = await prisma.post.findUnique({ where: { id: postId }, select: { id: true } });
    if (!post) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    const body = (req.body ?? {}) as Record<string, unknown>;
    const reason = normalizeHideReason(body.reason);
    const note = normalizeHideNote(body.note);

    await prisma.$transaction(async (tx) => {
      const existing = await tx.postHide.findUnique({
        where: {
          postId_userId: {
            postId,
            userId,
          },
        },
      });

      if (existing) {
        await tx.postHide.update({
          where: { id: existing.id },
          data: { reason, note },
        });
      } else {
        await tx.postHide.create({
          data: {
            postId,
            userId,
            reason,
            note,
          },
        });
        await tx.post.update({
          where: { id: postId },
          data: { hideCount: { increment: 1 } },
        });
      }
    });

    res.json({ success: true, hiddenPostId: postId });
  } catch (error) {
    console.error('BFF hide post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/feed/posts/:id/hide', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;

    await prisma.$transaction(async (tx) => {
      const existing = await tx.postHide.findUnique({
        where: {
          postId_userId: {
            postId,
            userId,
          },
        },
      });

      if (existing) {
        await tx.postHide.delete({ where: { id: existing.id } });
        await tx.post.updateMany({
          where: {
            id: postId,
            hideCount: { gt: 0 },
          },
          data: { hideCount: { decrement: 1 } },
        });
      }
    });

    res.json({ success: true, hiddenPostId: postId });
  } catch (error) {
    console.error('BFF unhide post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/feed/posts/:id/comments', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const viewerId = (req as BFFAuthRequest).user?.userId;
    const postId = req.params.id as string;

    const comments = await prisma.postComment.findMany({
      where: { postId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        replyToUser: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    const authorIds = Array.from(
      new Set(
        comments
          .flatMap((comment) => [comment.user.id, comment.replyToUser?.id ?? null])
          .filter((id): id is string => Boolean(id))
      )
    );
    const followingSet = await buildFollowingMap(viewerId, authorIds);

    res.json(
      comments.map((comment) => ({
        id: comment.id,
        postID: comment.postId,
        parentCommentID: comment.parentCommentId ?? null,
        rootCommentID: comment.rootCommentId ?? null,
        depth: comment.depth ?? 0,
        author: toUserSummary(comment.user, followingSet.has(comment.user.id)),
        replyToAuthor: comment.replyToUser
          ? toUserSummary(comment.replyToUser, followingSet.has(comment.replyToUser.id))
          : null,
        content: comment.content,
        createdAt: comment.createdAt,
      }))
    );
  } catch (error) {
    console.error('BFF comments error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/posts/:id/comments', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;
    const body = (req.body ?? {}) as {
      content?: unknown;
      parentCommentID?: unknown;
      parentCommentId?: unknown;
      replyToCommentID?: unknown;
      replyToCommentId?: unknown;
    };
    const content = String(body.content || '').trim();
    const rawParentID =
      body.parentCommentID ??
      body.parentCommentId ??
      body.replyToCommentID ??
      body.replyToCommentId;
    const parentCommentID = typeof rawParentID === 'string' ? rawParentID.trim() : '';
    const normalizedParentCommentID = parentCommentID.length > 0 ? parentCommentID : null;

    if (!content) {
      res.status(400).json({ error: 'content is required' });
      return;
    }

    const post = await prisma.post.findUnique({
      where: { id: postId },
      select: { id: true, userId: true, content: true },
    });
    if (!post) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    const comment = await prisma.$transaction(async (tx) => {
      let parentComment:
        | {
            id: string;
            postId: string;
            userId: string;
            rootCommentId: string | null;
            depth: number;
          }
        | null = null;

      if (normalizedParentCommentID) {
        parentComment = await tx.postComment.findUnique({
          where: { id: normalizedParentCommentID },
          select: {
            id: true,
            postId: true,
            userId: true,
            rootCommentId: true,
            depth: true,
          },
        });

        if (!parentComment || parentComment.postId !== postId) {
          throw new Error('PARENT_COMMENT_INVALID');
        }
      }

      const rootCommentId = parentComment ? parentComment.rootCommentId ?? parentComment.id : null;
      const depth = parentComment ? Math.min((parentComment.depth ?? 0) + 1, 2) : 0;
      const replyToUserId = parentComment?.userId ?? null;

      const created = await tx.postComment.create({
        data: {
          postId,
          userId,
          content,
          parentCommentId: parentComment?.id ?? null,
          rootCommentId,
          depth,
          replyToUserId,
        },
        include: {
          user: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
          replyToUser: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
        },
      });

      await tx.post.update({
        where: { id: postId },
        data: { commentCount: { increment: 1 } },
      });

      return created;
    });

    if (post.userId !== userId) {
      publishCommunityInteractionSafely({
        targetUserIds: [post.userId],
        title: '社区互动',
        body: '有人评论了你的动态',
        deeplink: `raver://community/post/${postId}`,
        metadata: {
          source: 'post_comment',
          actorUserID: userId,
          commentID: comment.id,
          postID: postId,
          postPreview: truncateText(post.content, 80) || null,
          commentPreview: truncateText(comment.content, 80) || null,
        },
        dedupeKey: `community:comment:${comment.id}:post_owner:${post.userId}`,
      });
    }

    if (comment.replyToUser && comment.replyToUser.id !== userId && comment.replyToUser.id !== post.userId) {
      publishCommunityInteractionSafely({
        targetUserIds: [comment.replyToUser.id],
        title: '社区互动',
        body: '有人回复了你的评论',
        deeplink: `raver://community/post/${postId}`,
        metadata: {
          source: 'post_comment_reply',
          actorUserID: userId,
          commentID: comment.id,
          postID: postId,
          commentPreview: truncateText(comment.content, 80) || null,
        },
        dedupeKey: `community:comment:${comment.id}:reply_to:${comment.replyToUser.id}`,
      });
    }

    res.status(201).json({
      id: comment.id,
      postID: comment.postId,
      parentCommentID: comment.parentCommentId ?? null,
      rootCommentID: comment.rootCommentId ?? null,
      depth: comment.depth ?? 0,
      author: toUserSummary(comment.user, false),
      replyToAuthor: comment.replyToUser ? toUserSummary(comment.replyToUser, false) : null,
      content: comment.content,
      createdAt: comment.createdAt,
    });
  } catch (error) {
    if (error instanceof Error && error.message === 'PARENT_COMMENT_INVALID') {
      res.status(400).json({ error: 'parentCommentID is invalid' });
      return;
    }
    console.error('BFF add comment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/chat/conversations', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const type = String(req.query.type || 'group');
    const limit = normalizeLimit(req.query.limit, 50, 200);

    if (type === 'direct') {
      const directConversations = await prisma.directConversation.findMany({
        where: {
          OR: [{ userAId: userId }, { userBId: userId }],
        },
        include: {
          userA: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
          userB: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
          messages: {
            orderBy: { createdAt: 'desc' },
            take: 1,
            select: {
              content: true,
              createdAt: true,
              senderId: true,
              sender: {
                select: { username: true },
              },
            },
          },
        },
        orderBy: { updatedAt: 'desc' },
        take: limit,
      });

      const conversationIds = directConversations.map((conversation) => conversation.id);
      const readRows =
        conversationIds.length === 0
          ? []
          : await prisma.directConversationRead.findMany({
              where: {
                userId,
                conversationId: { in: conversationIds },
              },
              select: {
                conversationId: true,
                lastReadAt: true,
              },
            });

      const readMap = new Map(readRows.map((row) => [row.conversationId, row.lastReadAt]));
      const unreadPairs = await Promise.all(
        directConversations.map(async (conversation) => {
          const lastReadAt = readMap.get(conversation.id);
          const unreadCount = await prisma.directMessage.count({
            where: {
              conversationId: conversation.id,
              senderId: { not: userId },
              ...(lastReadAt ? { createdAt: { gt: lastReadAt } } : {}),
            },
          });
          return [conversation.id, unreadCount] as const;
        })
      );
      const unreadMap = new Map(unreadPairs);

      const mapped = await Promise.all(
        directConversations.map((conversation) =>
          mapDirectConversation(conversation, userId, unreadMap.get(conversation.id) ?? 0)
        )
      );

      res.json(mapped);
      return;
    }

    const memberships = await prisma.squadMember.findMany({
      where: { userId },
      select: {
        lastReadAt: true,
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
            updatedAt: true,
            messages: {
              orderBy: { createdAt: 'desc' },
              take: 1,
              select: {
                content: true,
                createdAt: true,
                userId: true,
                user: {
                  select: { username: true },
                },
              },
            },
          },
        },
      },
    });

    const unreadPairs = await Promise.all(
      memberships.map(async (membership) => {
        const unreadCount = await prisma.squadMessage.count({
          where: {
            squadId: membership.squad.id,
            userId: { not: userId },
            ...(membership.lastReadAt ? { createdAt: { gt: membership.lastReadAt } } : {}),
          },
        });
        return [membership.squad.id, unreadCount] as const;
      })
    );
    const unreadMap = new Map(unreadPairs);

    const conversations = memberships
      .map((membership) => mapGroupConversation(membership.squad, unreadMap.get(membership.squad.id) ?? 0))
      .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());

    res.json(conversations);
  } catch (error) {
    console.error('BFF conversations error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/chat/conversations/:id/read', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const conversationId = req.params.id as string;
    const readAt = new Date();

    const directConversation = await prisma.directConversation.findFirst({
      where: {
        id: conversationId,
        OR: [{ userAId: userId }, { userBId: userId }],
      },
      select: { id: true, userAId: true, userBId: true },
    });

    if (directConversation) {
      await prisma.directConversationRead.upsert({
        where: {
          conversationId_userId: {
            conversationId,
            userId,
          },
        },
        update: { lastReadAt: readAt },
        create: {
          conversationId,
          userId,
          lastReadAt: readAt,
        },
      });
      res.json({ success: true, readAt });
      return;
    }

    const membership = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId: conversationId,
          userId,
        },
      },
      select: { id: true },
    });

    if (!membership) {
      res.status(404).json({ error: 'Conversation not found' });
      return;
    }

    await prisma.squadMember.update({
      where: {
        squadId_userId: {
          squadId: conversationId,
          userId,
        },
      },
      data: { lastReadAt: readAt },
    });

    res.json({ success: true, readAt });
  } catch (error) {
    console.error('BFF mark conversation read error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/chat/direct/start', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const { identifier, userId: targetUserId, username } = req.body as {
      identifier?: string;
      userId?: string;
      username?: string;
    };

    const lookupIdentifier = String(targetUserId || identifier || username || '').trim();
    if (!lookupIdentifier) {
      res.status(400).json({ error: 'identifier is required' });
      return;
    }

    const target = await prisma.user.findFirst({
      where: {
        isActive: true,
        OR: [
          { id: lookupIdentifier },
          { username: { equals: lookupIdentifier, mode: 'insensitive' } },
          { email: { equals: lookupIdentifier, mode: 'insensitive' } },
        ],
      },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
      },
    });

    if (!target) {
      res.status(404).json({ error: 'Target user not found' });
      return;
    }

    if (target.id === userId) {
      res.status(400).json({ error: 'Cannot start direct chat with yourself' });
      return;
    }

    const [userAId, userBId] = normalizeDirectPair(userId, target.id);

    const conversation = await prisma.directConversation.upsert({
      where: {
        userAId_userBId: { userAId, userBId },
      },
      update: {
        updatedAt: new Date(),
      },
      create: {
        userAId,
        userBId,
      },
      include: {
        userA: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        userB: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: {
            content: true,
            createdAt: true,
            senderId: true,
            sender: {
              select: { username: true },
            },
          },
        },
      },
    });

    await prisma.directConversationRead.upsert({
      where: {
        conversationId_userId: {
          conversationId: conversation.id,
          userId,
        },
      },
      update: { lastReadAt: new Date() },
      create: {
        conversationId: conversation.id,
        userId,
      },
    });

    const mapped = await mapDirectConversation(conversation, userId);
    res.status(201).json(mapped);
  } catch (error) {
    console.error('BFF start direct conversation error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/chat/conversations/:id/messages', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const conversationId = req.params.id as string;
    const limit = normalizeLimit(req.query.limit, 50, 200);

    const directConversation = await prisma.directConversation.findFirst({
      where: {
        id: conversationId,
        OR: [{ userAId: userId }, { userBId: userId }],
      },
      select: { id: true, userAId: true, userBId: true },
    });

    if (directConversation) {
      const messages = await prisma.directMessage.findMany({
        where: { conversationId },
        include: {
          sender: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
        },
        orderBy: { createdAt: 'asc' },
        take: limit,
      });

      const senderIds = Array.from(new Set(messages.map((msg) => msg.sender.id)));
      const followingSet = await buildFollowingMap(userId, senderIds);

      await prisma.directConversationRead.upsert({
        where: {
          conversationId_userId: {
            conversationId,
            userId,
          },
        },
        update: { lastReadAt: new Date() },
        create: {
          conversationId,
          userId,
        },
      });

      res.json(
        messages.map((message) => ({
          id: message.id,
          conversationID: conversationId,
          sender: toUserSummary(message.sender, followingSet.has(message.sender.id)),
          content: message.content,
          createdAt: message.createdAt,
          isMine: message.senderId === userId,
        }))
      );
      return;
    }

    const membership = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId: conversationId,
          userId,
        },
      },
      select: { id: true, nickname: true },
    });

    if (!membership) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const messages = await prisma.squadMessage.findMany({
      where: { squadId: conversationId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: { createdAt: 'asc' },
      take: limit,
    });

    const senderIds = Array.from(new Set(messages.map((msg) => msg.user.id)));
    const [followingSet, squadMembers] = await Promise.all([
      buildFollowingMap(userId, senderIds),
      prisma.squadMember.findMany({
        where: {
          squadId: conversationId,
          userId: {
            in: senderIds,
          },
        },
        select: {
          userId: true,
          nickname: true,
        },
      }),
    ]);
    const nicknameMap = new Map(squadMembers.map((item) => [item.userId, item.nickname]));

    await prisma.squadMember.update({
      where: {
        squadId_userId: {
          squadId: conversationId,
          userId,
        },
      },
      data: { lastReadAt: new Date() },
    });

    res.json(
      messages.map((message) => ({
        id: message.id,
        conversationID: conversationId,
        sender: toUserSummaryWithNickname(
          message.user,
          followingSet.has(message.user.id),
          nicknameMap.get(message.user.id)
        ),
        content: message.content,
        createdAt: message.createdAt,
        isMine: message.userId === userId,
      }))
    );
  } catch (error) {
    console.error('BFF messages error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/chat/conversations/:id/messages', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const conversationId = req.params.id as string;
    const content = String((req.body as { content?: string }).content || '').trim();

    if (!content) {
      res.status(400).json({ error: 'content is required' });
      return;
    }

    const directConversation = await prisma.directConversation.findFirst({
      where: {
        id: conversationId,
        OR: [{ userAId: userId }, { userBId: userId }],
      },
      select: { id: true, userAId: true, userBId: true },
    });

    if (directConversation) {
      const created = await prisma.$transaction(async (tx) => {
        const message = await tx.directMessage.create({
          data: {
            conversationId,
            senderId: userId,
            content,
            type: 'text',
          },
          include: {
            sender: {
              select: {
                id: true,
                username: true,
                displayName: true,
                avatarUrl: true,
              },
            },
          },
        });

        await tx.directConversation.update({
          where: { id: conversationId },
          data: { updatedAt: new Date() },
        });

        await tx.directConversationRead.upsert({
          where: {
            conversationId_userId: {
              conversationId,
              userId,
            },
          },
          update: { lastReadAt: new Date() },
          create: {
            conversationId,
            userId,
          },
        });

        return message;
      });

      const directTargetUserId = directConversation.userAId === userId
        ? directConversation.userBId
        : directConversation.userAId;
      const senderDisplayName = created.sender.displayName || created.sender.username || '新消息';
      publishChatMessageSafely({
        targetUserIds: [directTargetUserId],
        title: senderDisplayName,
        body: truncateText(created.content, 120) || '发来一条新消息',
        deeplink: `raver://messages/conversation/${conversationId}`,
        metadata: {
          scope: 'direct',
          conversationID: conversationId,
          messageID: created.id,
          senderUserID: userId,
          receiverUserID: directTargetUserId,
        },
        dedupeKey: `chat:direct:${created.id}`,
      });

      res.status(201).json({
        id: created.id,
        conversationID: conversationId,
        sender: toUserSummary(created.sender, false),
        content: created.content,
        createdAt: created.createdAt,
        isMine: true,
      });
      return;
    }

    const membership = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId: conversationId,
          userId,
        },
      },
      select: { id: true, nickname: true },
    });

    if (!membership) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const created = await prisma.squadMessage.create({
      data: {
        squadId: conversationId,
        userId,
        content,
        type: 'text',
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
    });

    await prisma.squadMember.update({
      where: {
        squadId_userId: {
          squadId: conversationId,
          userId,
        },
      },
      data: { lastReadAt: new Date() },
    });

    const [squad, targetMembers] = await Promise.all([
      prisma.squad.findUnique({
        where: { id: conversationId },
        select: { name: true },
      }),
      prisma.squadMember.findMany({
        where: {
          squadId: conversationId,
          userId: { not: userId },
          notificationsEnabled: true,
        },
        select: { userId: true },
      }),
    ]);

    const senderDisplayName = created.user.displayName || created.user.username || '新消息';
    publishChatMessageSafely({
      targetUserIds: targetMembers.map((item) => item.userId),
      title: squad?.name || '小队消息',
      body: `${senderDisplayName}: ${truncateText(created.content, 100) || '发来一条新消息'}`,
      deeplink: `raver://messages/conversation/${conversationId}`,
      metadata: {
        scope: 'group',
        conversationID: conversationId,
        messageID: created.id,
        squadName: squad?.name || null,
        senderUserID: userId,
      },
      dedupeKey: `chat:group:${created.id}`,
    });

    res.status(201).json({
      id: created.id,
      conversationID: conversationId,
      sender: toUserSummaryWithNickname(created.user, false, membership.nickname),
      content: created.content,
      createdAt: created.createdAt,
      isMine: true,
    });
  } catch (error) {
    console.error('BFF send message error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/profile/me', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const [user, followersCount, followingCount, postsCount, friendIds] = await Promise.all([
      prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          username: true,
          displayName: true,
          bio: true,
          avatarUrl: true,
          favoriteGenres: true,
          isFollowersListPublic: true,
          isFollowingListPublic: true,
        },
      }),
      prisma.follow.count({
        where: {
          followingId: userId,
          type: 'user',
        },
      }),
      prisma.follow.count({
        where: {
          followerId: userId,
          type: 'user',
          followingId: { not: null },
        },
      }),
      prisma.post.count({
        where: { userId },
      }),
      buildFriendUserIds(userId),
    ]);

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json({
      id: user.id,
      username: user.username,
      displayName: user.displayName || user.username,
      bio: user.bio || '',
      avatarURL: user.avatarUrl,
      tags: user.favoriteGenres,
      isFollowersListPublic: user.isFollowersListPublic,
      isFollowingListPublic: user.isFollowingListPublic,
      canViewFollowersList: true,
      canViewFollowingList: true,
      followersCount,
      followingCount,
      friendsCount: friendIds.size,
      postsCount,
      isFollowing: false,
    });
  } catch (error) {
    console.error('BFF profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/profile/me', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = req.body as {
      displayName?: string;
      bio?: string;
      tags?: unknown;
      isFollowersListPublic?: boolean;
      isFollowingListPublic?: boolean;
    };

    const data: {
      displayName?: string;
      bio?: string;
      favoriteGenres?: string[];
      isFollowersListPublic?: boolean;
      isFollowingListPublic?: boolean;
    } = {};

    if (typeof body.displayName === 'string') {
      const trimmed = body.displayName.trim();
      if (!trimmed) {
        res.status(400).json({ error: 'displayName cannot be empty' });
        return;
      }
      data.displayName = trimmed;
    }

    if (typeof body.bio === 'string') {
      data.bio = body.bio.trim();
    }

    if (body.tags !== undefined) {
      data.favoriteGenres = normalizeTags(body.tags);
    }

    if (typeof body.isFollowersListPublic === 'boolean') {
      data.isFollowersListPublic = body.isFollowersListPublic;
    }

    if (typeof body.isFollowingListPublic === 'boolean') {
      data.isFollowingListPublic = body.isFollowingListPublic;
    }

    if (Object.keys(data).length > 0) {
      await prisma.user.update({
        where: { id: userId },
        data,
        select: { id: true },
      });

      await syncTencentIMUserBestEffort(userId, 'bff-profile-update');
    }

    const [user, followersCount, followingCount, postsCount, friendIds] = await Promise.all([
      prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          username: true,
          displayName: true,
          bio: true,
          avatarUrl: true,
          favoriteGenres: true,
          isFollowersListPublic: true,
          isFollowingListPublic: true,
        },
      }),
      prisma.follow.count({
        where: {
          followingId: userId,
          type: 'user',
        },
      }),
      prisma.follow.count({
        where: {
          followerId: userId,
          type: 'user',
          followingId: { not: null },
        },
      }),
      prisma.post.count({
        where: { userId },
      }),
      buildFriendUserIds(userId),
    ]);

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json({
      id: user.id,
      username: user.username,
      displayName: user.displayName || user.username,
      bio: user.bio || '',
      avatarURL: user.avatarUrl,
      tags: user.favoriteGenres,
      isFollowersListPublic: user.isFollowersListPublic,
      isFollowingListPublic: user.isFollowingListPublic,
      canViewFollowersList: true,
      canViewFollowingList: true,
      followersCount,
      followingCount,
      friendsCount: friendIds.size,
      postsCount,
      isFollowing: false,
    });
  } catch (error) {
    console.error('BFF update profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post(
  '/profile/me/avatar',
  optionalAuth,
  avatarUpload.single('avatar'),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const userId = requireAuth(req as BFFAuthRequest, res);
      if (!userId) return;

      const file = (req as Request & { file?: Express.Multer.File }).file;
      if (!file) {
        res.status(400).json({ error: 'No file uploaded' });
        return;
      }

      const avatarUrl = `/uploads/avatars/${file.filename}`;
      await prisma.user.update({
        where: { id: userId },
        data: { avatarUrl },
        select: { id: true },
      });

      await syncTencentIMUserBestEffort(userId, 'bff-profile-avatar');

      res.status(201).json({ avatarURL: avatarUrl });
    } catch (error) {
      console.error('BFF upload avatar error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

router.get('/profile/me/likes', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);

    const likes = await prisma.postLike.findMany({
      where: {
        userId,
        ...(cursorDate
          ? {
              createdAt: {
                lt: cursorDate,
              },
            }
          : {}),
      },
      include: {
        post: {
          include: {
            user: {
              select: {
                id: true,
                username: true,
                displayName: true,
                avatarUrl: true,
              },
            },
            squad: {
              select: {
                id: true,
                name: true,
                avatarUrl: true,
              },
            },
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = likes.length > limit;
    const pageLikes = hasMore ? likes.slice(0, limit) : likes;
    const postIds = pageLikes.map((item) => item.postId);
    const authorIds = Array.from(new Set(pageLikes.map((item) => item.post.user.id)));
    const [followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds] = await Promise.all([
      buildFollowingMap(userId, authorIds),
      buildLikedPostMap(userId, postIds),
      buildRepostedPostMap(userId, postIds),
      buildSavedPostMap(userId, postIds),
      buildHiddenPostMap(userId, postIds),
    ]);

    res.json({
      items: pageLikes.map((item) => ({
        actionAt: item.createdAt,
        post: mapPost(item.post, followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds),
      })),
      nextCursor: hasMore ? pageLikes[pageLikes.length - 1]?.createdAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF like history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/profile/me/reposts', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);

    const reposts = await prisma.postRepost.findMany({
      where: {
        userId,
        ...(cursorDate
          ? {
              createdAt: {
                lt: cursorDate,
              },
            }
          : {}),
      },
      include: {
        post: {
          include: {
            user: {
              select: {
                id: true,
                username: true,
                displayName: true,
                avatarUrl: true,
              },
            },
            squad: {
              select: {
                id: true,
                name: true,
                avatarUrl: true,
              },
            },
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = reposts.length > limit;
    const pageReposts = hasMore ? reposts.slice(0, limit) : reposts;
    const postIds = pageReposts.map((item) => item.postId);
    const authorIds = Array.from(new Set(pageReposts.map((item) => item.post.user.id)));
    const [followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds] = await Promise.all([
      buildFollowingMap(userId, authorIds),
      buildLikedPostMap(userId, postIds),
      buildRepostedPostMap(userId, postIds),
      buildSavedPostMap(userId, postIds),
      buildHiddenPostMap(userId, postIds),
    ]);

    res.json({
      items: pageReposts.map((item) => ({
        actionAt: item.createdAt,
        post: mapPost(item.post, followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds),
      })),
      nextCursor: hasMore ? pageReposts[pageReposts.length - 1]?.createdAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF repost history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/profile/me/saves', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);

    const saves = await prisma.postSave.findMany({
      where: {
        userId,
        ...(cursorDate
          ? {
              createdAt: {
                lt: cursorDate,
              },
            }
          : {}),
      },
      include: {
        post: {
          include: {
            user: {
              select: {
                id: true,
                username: true,
                displayName: true,
                avatarUrl: true,
              },
            },
            squad: {
              select: {
                id: true,
                name: true,
                avatarUrl: true,
              },
            },
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = saves.length > limit;
    const pageSaves = hasMore ? saves.slice(0, limit) : saves;
    const postIds = pageSaves.map((item) => item.postId);
    const authorIds = Array.from(new Set(pageSaves.map((item) => item.post.user.id)));
    const [followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds] = await Promise.all([
      buildFollowingMap(userId, authorIds),
      buildLikedPostMap(userId, postIds),
      buildRepostedPostMap(userId, postIds),
      buildSavedPostMap(userId, postIds),
      buildHiddenPostMap(userId, postIds),
    ]);

    res.json({
      items: pageSaves.map((item) => ({
        actionAt: item.createdAt,
        post: mapPost(item.post, followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds),
      })),
      nextCursor: hasMore ? pageSaves[pageSaves.length - 1]?.createdAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF save history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/social/users/:id/follow', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const targetUserId = req.params.id as string;
    if (targetUserId === userId) {
      res.status(400).json({ error: 'Cannot follow yourself' });
      return;
    }

    const target = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
        isActive: true,
      },
    });

    if (!target || !target.isActive) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const existing = await prisma.follow.findUnique({
      where: {
        followerId_followingId: {
          followerId: userId,
          followingId: targetUserId,
        },
      },
    });

    let createdFollowId: string | null = null;
    if (!existing) {
      const createdFollow = await prisma.follow.create({
        data: {
          followerId: userId,
          followingId: targetUserId,
          type: 'user',
        },
        select: { id: true },
      });
      createdFollowId = createdFollow.id;
    }

    if (createdFollowId) {
      publishCommunityInteractionSafely({
        targetUserIds: [targetUserId],
        title: '社区互动',
        body: '有人关注了你',
        deeplink: `raver://profile/${userId}`,
        metadata: {
          source: 'user_follow',
          actorUserID: userId,
          followID: createdFollowId,
        },
        dedupeKey: `community:follow:${createdFollowId}`,
      });
    }

    res.json(toUserSummary(target, true));
  } catch (error) {
    console.error('BFF follow user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/social/users/:id/follow', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const targetUserId = req.params.id as string;

    const target = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
      },
    });

    if (!target) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    await prisma.follow.deleteMany({
      where: {
        followerId: userId,
        followingId: targetUserId,
        type: 'user',
      },
    });

    res.json(toUserSummary(target, false));
  } catch (error) {
    console.error('BFF unfollow user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
