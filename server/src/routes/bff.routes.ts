import { Router, Request, Response, NextFunction, type CookieOptions } from 'express';
import { Prisma, PrismaClient } from '@prisma/client';
import OSS from 'ali-oss';
import multer from 'multer';
import crypto from 'crypto';
import path from 'path';
import {
  ACCESS_TOKEN_TTL_SECONDS,
  REFRESH_TOKEN_TTL_MS,
  comparePassword,
  generateReauthProof,
  generateRefreshToken,
  generateToken,
  hashPassword,
  hashToken,
  isTokenHashMatch,
  verifyToken,
  type JWTPayload,
} from '../utils/auth';
import { tencentIMFriendService, tencentIMGroupService, tencentIMUserService } from '../modules/im';
import { smsService } from '../services/sms/sms-provider';
import { emailService } from '../services/email/email-provider';
import { recordSmsMetric } from '../services/sms/sms-metrics';
import { verifyFirebasePhoneIdToken } from '../services/firebase-phone-auth.service';
import { notificationCenterService } from '../services/notification-center';
import {
  FEED_RANKING_WEIGHTS_VERSION,
  FeedEventValidationError,
  type FeedExperimentBucket,
  buildFeedRankingWeights,
  createPostComment,
  fetchPostComments,
  hidePost,
  likePost,
  PostCommentNotFoundError,
  PostCommentValidationError,
  recordFeedEvent,
  repostPost,
  resolveFeedExperimentBucket as resolveFeedExperimentBucketFromModule,
  savePost,
  sharePost,
  PostInteractionNotFoundError,
  unhidePost,
  unlikePost,
  unrepostPost,
  unsavePost,
} from '../modules/feed';
import {
  getShareLinkByCode,
  recordShareLinkEvent,
  redeemShareLinkInvite,
  resolveOrCreateShareLink,
  resetShareLinkInvite,
  ShareLinkError,
} from '../services/share-link.service';
import {
  accountEnforcementService,
  type EnforcementScope,
} from '../services/account-enforcement.service';
import { accountDeletionService } from '../services/account-deletion.service';
import { analyzeI18nCompleteness } from '../utils/i18n';
import { contentCompliance } from '../utils/content-compliance';
import { regionalCompliance } from '../config/regional-compliance';
import {
  publicObjectStorageUrlForKey,
  saveBufferToLocalUploads,
  securePublicAssetUrl as resolveSecurePublicAssetUrl,
  shouldAllowLocalUploadFallback,
} from '../services/media-storage.service';
import { mediaAssetService } from '../services/media-asset.service';

const router: Router = Router();
const prisma = new PrismaClient();

const timeAsync = async <T>(
  scope: string,
  step: string,
  task: () => Promise<T>,
  detail: Record<string, unknown> = {}
): Promise<T> => {
  const startedAt = Date.now();
  try {
    const result = await task();
    console.info('[perf]', {
      scope,
      step,
      outcome: 'success',
      durationMs: Date.now() - startedAt,
      ...detail,
    });
    return result;
  } catch (error) {
    console.warn('[perf]', {
      scope,
      step,
      outcome: 'failed',
      durationMs: Date.now() - startedAt,
      error: error instanceof Error ? error.message : String(error),
      ...detail,
    });
    throw error;
  }
};

const avatarUpload = multer({
  storage: multer.memoryStorage(),
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
const ossUserAvatarsPrefix = (cleanEnv(process.env.OSS_USER_AVATARS_PREFIX) || 'users/avatars').replace(/^\/+|\/+$/g, '');
const ossSquadAvatarsPrefix = (cleanEnv(process.env.OSS_SQUAD_AVATARS_PREFIX) || 'squads/avatars').replace(/^\/+|\/+$/g, '');

const ossClient =
  ossRegion && ossAccessKeyId && ossAccessKeySecret && ossBucket
    ? new OSS({
        region: ossRegion,
        accessKeyId: ossAccessKeyId,
        accessKeySecret: ossAccessKeySecret,
        bucket: ossBucket,
        endpoint: ossEndpoint || undefined,
      })
    : null;

const postMediaOssClient = ossClient;

const normalizeDisplayName = (value: string | null | undefined): string => {
  return String(value || '').trim().replace(/\s+/g, ' ');
};

const normalizeDisplayNameForUniqueness = (value: string | null | undefined): string => {
  return normalizeDisplayName(value).toLocaleLowerCase('zh-Hans-CN');
};

const createInternalUsername = async (seed: string): Promise<string> => {
  const normalizedSeed = seed
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 24) || 'user';

  for (let attempt = 0; attempt < 8; attempt += 1) {
    const suffix = crypto.randomBytes(4).toString('hex');
    const candidate = `${normalizedSeed}_${suffix}`.slice(0, 40);
    const exists = await prisma.user.findUnique({
      where: { username: candidate },
      select: { id: true },
    });
    if (!exists) {
      return candidate;
    }
  }

  return `user_${crypto.randomUUID().replace(/-/g, '').slice(0, 20)}`;
};

const publicOssUrlForObjectKey = (objectKey: string): string => publicObjectStorageUrlForKey(objectKey);

const securePublicAssetUrl = (rawUrl: string | undefined | null, objectKey: string): string => {
  return resolveSecurePublicAssetUrl(rawUrl, objectKey);
};

const extensionForMimeType = (mimeType: string): string => {
  const normalized = mimeType.toLowerCase();
  if (normalized.includes('png')) return '.png';
  if (normalized.includes('webp')) return '.webp';
  if (normalized.includes('gif')) return '.gif';
  return '.jpg';
};

const uploadUserAvatarToOss = async (
  userId: string,
  file: Express.Multer.File
): Promise<{ assetId: string; url: string; objectKey: string }> => {
  if (!ossClient) {
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  const ext = extensionForMimeType(file.mimetype);
  const objectKey = `${ossUserAvatarsPrefix}/${userId}/avatar-${Date.now()}-${crypto.randomBytes(4).toString('hex')}${ext}`;
  const result = await ossClient.put(objectKey, file.buffer, {
    headers: {
      'Content-Type': file.mimetype,
      'Cache-Control': 'public, max-age=31536000, immutable',
    },
  });
  const url = securePublicAssetUrl(result.url, objectKey);
  const asset = await mediaAssetService.register({
    ownerType: 'user',
    ownerId: userId,
    purpose: 'avatar',
    provider: 'oss',
    objectKey,
    url,
    mimeType: file.mimetype,
    sizeBytes: file.size,
    uploadedById: userId,
    metadata: {
      originalName: file.originalname,
      source: 'v1/profile/me/avatar',
    },
  });
  return {
    assetId: asset.id,
    url,
    objectKey,
  };
};

const uploadSquadAvatarAsset = async (
  squadId: string,
  file: Express.Multer.File
): Promise<{ assetId: string; url: string; objectKey: string | null }> => {
  const ext = extensionForMimeType(file.mimetype);

  if (ossClient) {
    const objectKey = `${ossSquadAvatarsPrefix}/${squadId}/avatar-${Date.now()}-${crypto.randomBytes(4).toString('hex')}${ext}`;
    const result = await ossClient.put(objectKey, file.buffer, {
      headers: {
        'Content-Type': file.mimetype,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
    const url = result.url || publicOssUrlForObjectKey(objectKey);
    const asset = await mediaAssetService.register({
      ownerType: 'squad',
      ownerId: squadId,
      purpose: 'avatar',
      provider: 'oss',
      objectKey,
      url,
      mimeType: file.mimetype,
      sizeBytes: file.size,
      metadata: {
        originalName: file.originalname,
        source: 'v1/squads/:id/avatar',
      },
    });
    return {
      assetId: asset.id,
      url,
      objectKey,
    };
  }

  if (!shouldAllowLocalUploadFallback()) {
    throw new Error('Squad avatar upload requires OSS configuration');
  }

  const localUpload = await saveBufferToLocalUploads({
    buffer: file.buffer,
    localDir: path.join(process.cwd(), 'uploads', 'avatars'),
    publicSubdir: 'avatars',
    originalName: `squad-${squadId}${ext}`,
    mimeType: file.mimetype,
  });
  const asset = await mediaAssetService.register({
    ownerType: 'squad',
    ownerId: squadId,
    purpose: 'avatar',
    provider: 'local',
    objectKey: null,
    url: localUpload.url,
    mimeType: file.mimetype,
    sizeBytes: file.size,
    metadata: {
      originalName: file.originalname,
      source: 'v1/squads/:id/avatar',
    },
  });
  return {
    assetId: asset.id,
    url: localUpload.url,
    objectKey: null,
  };
};

const createProfileModerationJob = async (
  userId: string,
  targetType: 'display_name' | 'avatar',
  targetValue: string,
  normalizedValue?: string | null
): Promise<void> => {
  await prisma.userProfileModerationJob.create({
    data: {
      userId,
      targetType,
      targetValue,
      normalizedValue: normalizedValue || null,
      status: 'pending',
      provider: 'manual_review',
    },
  });
};

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
  authUserId?: string;
  authAccountStatus?: 'active' | 'inactive' | 'missing';
}

const optionalAuth = async (req: Request, _res: Response, next: NextFunction): Promise<void> => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    next();
    return;
  }

  const token = authHeader.substring(7);
  try {
    const decoded = verifyToken(token);
    const authReq = req as BFFAuthRequest;
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      select: { id: true, email: true, role: true, isActive: true },
    });
    authReq.authUserId = decoded.userId;
    authReq.authAccountStatus = !user ? 'missing' : user.isActive ? 'active' : 'inactive';
    if (user?.isActive) {
      authReq.user = {
          ...decoded,
          email: user.email,
          role: user.role,
        };
    }
  } catch (_error) {
    // Ignore invalid token for public endpoints.
  }

  next();
};

const requireAuth = (
  req: BFFAuthRequest,
  res: Response,
  options: { allowInactiveAccount?: boolean } = {}
): string | null => {
  const userId = req.user?.userId ?? (options.allowInactiveAccount ? req.authUserId : undefined);
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
  if (!options.allowInactiveAccount && req.authAccountStatus && req.authAccountStatus !== 'active') {
    res.status(401).json({
      error: 'Account is no longer active',
      code: 'ACCOUNT_INACTIVE',
      accountStatus: req.authAccountStatus === 'inactive' ? 'deleted' : 'missing',
    });
    return null;
  }
  return userId;
};

const denyForEnforcement = async (
  userId: string,
  scope: EnforcementScope,
  res: Response
): Promise<boolean> => {
  const result = await accountEnforcementService.assertAllowed(userId, scope);
  if (result.allowed) return false;

  res.status(403).json({
    error: 'account_enforcement_restricted',
    scope,
    accountStatus: result.status,
    blockingEnforcements: result.blockingEnforcements.map((item) => ({
      id: item.id,
      type: item.type,
      scopes: item.scopes,
      reasonCode: item.reasonCode,
      userMessageI18n: item.userMessageI18n,
      startsAt: item.startsAt.toISOString(),
      endsAt: item.endsAt ? item.endsAt.toISOString() : null,
    })),
  });
  return true;
};

type MinorRestrictionKey = keyof ReturnType<typeof regionalCompliance.policyFor>['minorRestrictions'];

const denyForMinorRegionalRestriction = async (
  userId: string,
  restriction: MinorRestrictionKey,
  res: Response
): Promise<boolean> => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { regionCode: true, ageBand: true },
  });
  const policy = regionalCompliance.policyFor(user?.regionCode);
  if (regionalCompliance.isRestrictedMinor(user, restriction)) {
    res.status(403).json({
      error: 'This action is restricted by regional minor safety policy',
      code: 'REGIONAL_MINOR_SAFETY_RESTRICTED',
      region: policy.region,
    });
    return true;
  }
  return false;
};

const normalizeComplianceText = (value: unknown, maxLength: number): string | null => {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().replace(/\s+/g, ' ');
  if (!normalized) return null;
  return normalized.slice(0, maxLength);
};

const normalizeReportAttachments = (value: unknown): Prisma.InputJsonValue | undefined => {
  if (!Array.isArray(value)) return undefined;
  const attachments = value
    .slice(0, 8)
    .map((item) => {
      if (typeof item === 'string') {
        const url = item.trim();
        return url ? { type: 'link', url } : null;
      }
      if (!item || typeof item !== 'object') return null;
      const record = item as Record<string, unknown>;
      const url = typeof record.url === 'string' ? record.url.trim() : '';
      if (!url) return null;
      const type = typeof record.type === 'string' ? record.type.trim().slice(0, 32) : 'link';
      const label = typeof record.label === 'string' ? record.label.trim().slice(0, 120) : null;
      return { type, url, label };
    })
    .filter((item): item is { type: string; url: string; label: string | null } => Boolean(item));
  return attachments.length > 0 ? (attachments as Prisma.InputJsonValue) : undefined;
};

const resolveReportTargetUserId = async (
  targetType: string,
  targetId: string
): Promise<string | null> => {
  const [normalizedType, ownerHint] = targetType.includes(':')
    ? targetType.split(':', 2)
    : [targetType, null];
  const ownerIdFromHint = ownerHint?.startsWith('owner=') ? ownerHint.slice('owner='.length) : null;
  if (ownerIdFromHint) return ownerIdFromHint;

  if (['image', 'video', 'audio', 'media_image', 'media_video', 'media_audio'].includes(normalizedType)) {
    return null;
  }

  switch (normalizedType) {
    case 'user': {
      const user = await prisma.user.findUnique({
        where: { id: targetId },
        select: { id: true },
      });
      return user?.id ?? null;
    }
    case 'post': {
      const post = await prisma.post.findUnique({
        where: { id: targetId },
        select: { userId: true },
      });
      return post?.userId ?? null;
    }
    case 'post_comment': {
      const comment = await prisma.postComment.findUnique({
        where: { id: targetId },
        select: { userId: true },
      });
      return comment?.userId ?? null;
    }
    case 'event_live_comment': {
      const comment = await prisma.eventLiveComment.findUnique({
        where: { id: targetId },
        select: { userId: true },
      });
      return comment?.userId ?? null;
    }
    case 'dj_set': {
      const set = await prisma.dJSet.findUnique({
        where: { id: targetId },
        select: { uploadedById: true },
      });
      return set?.uploadedById ?? null;
    }
    case 'event': {
      const event = await prisma.event.findUnique({
        where: { id: targetId },
        select: { organizerId: true },
      });
      return event?.organizerId ?? null;
    }
    case 'label':
    case 'festival':
    case 'circle_id':
      return null;
    case 'rating_event': {
      const ratingEvent = await prisma.ratingEvent.findUnique({
        where: { id: targetId },
        select: { createdById: true },
      });
      return ratingEvent?.createdById ?? null;
    }
    case 'rating_unit': {
      const ratingUnit = await prisma.ratingUnit.findUnique({
        where: { id: targetId },
        select: { createdById: true },
      });
      return ratingUnit?.createdById ?? null;
    }
    case 'direct_message': {
      const message = await prisma.directMessage.findUnique({
        where: { id: targetId },
        select: { senderId: true },
      });
      return message?.senderId ?? null;
    }
    case 'group_message':
    case 'squad_message': {
      const message = await prisma.squadMessage.findUnique({
        where: { id: targetId },
        select: { userId: true },
      });
      return message?.userId ?? null;
    }
    default:
      return null;
  }
};

const toPublicUserSummary = (user: {
  id: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
} | null | undefined) => {
  if (!user) return null;
  return {
    id: user.id,
    username: user.username,
    displayName: user.displayName || user.username,
    avatarURL: user.avatarUrl,
    avatarUrl: user.avatarUrl,
    isFollowing: false,
  };
};

const canBypassContentReview = (role?: string | null): boolean =>
  role === 'admin' || role === 'operator';

const CONTENT_I18N_FIELDS_BY_ENTITY: Record<string, string[]> = {
  news: ['titleI18n', 'summaryI18n', 'bodyI18n'],
  id: ['titleI18n', 'descriptionI18n'],
};

const buildI18nReviewNotes = (entityType: string, payload: Record<string, unknown>): Prisma.InputJsonObject => ({
  i18n: analyzeI18nCompleteness(payload, CONTENT_I18N_FIELDS_BY_ENTITY[entityType] || ['titleI18n']) as unknown as Prisma.InputJsonValue,
  compliance: contentCompliance.reviewNotes(entityType, payload),
});

const createPendingContentSubmission = async (input: {
  submitterId: string;
  entityType: 'news' | 'id';
  title: string;
  payload: Record<string, unknown>;
}) => {
  return prisma.$transaction(async (tx) => {
    const submission = await tx.contentSubmission.create({
      data: {
        submitterId: input.submitterId,
        entityType: input.entityType,
        title: input.title,
        payload: input.payload as Prisma.InputJsonObject,
        reviewNotes: buildI18nReviewNotes(input.entityType, input.payload),
        status: 'pending',
      },
    });

    await (tx as any).contentSubmissionVersion.create({
      data: {
        submissionId: submission.id,
        version: 1,
        title: input.title,
        payload: input.payload as Prisma.InputJsonObject,
        submittedBy: input.submitterId,
        changeNote: 'Initial submission',
      },
    });

    return submission;
  });
};

const acceptedSubmission = (
  res: Response,
  submission: Awaited<ReturnType<typeof createPendingContentSubmission>>,
  message: string
): void => {
  res.status(202).json({
    status: 'submitted_for_review',
    message,
    submission,
  });
};

const newsTitleFromContent = (content: string): string => {
  const line = content
    .split(/\r?\n/)
    .map((item) => item.trim())
    .find((item) => item.startsWith('标题：') || item.toLowerCase().startsWith('title:'));
  return line?.replace(/^标题：/u, '').replace(/^title:/i, '').trim() || '未命名资讯';
};

const idTitleFromContent = (content: string): string => {
  const line = content
    .split(/\r?\n/)
    .map((item) => item.trim())
    .find((item) => item.startsWith('标题：') || item.toLowerCase().startsWith('title:'));
  return line?.replace(/^标题：/u, '').replace(/^title:/i, '').trim() || '未命名 ID';
};

const idPayloadFromContent = (content: string): Record<string, unknown> => {
  const fields: Record<string, string> = {};
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    const separatorIndex = line.indexOf('：') >= 0 ? line.indexOf('：') : line.indexOf(':');
    if (separatorIndex < 0) continue;
    const key = line.slice(0, separatorIndex).trim().toLowerCase();
    const value = line.slice(separatorIndex + 1).trim();
    if (!key || !value) continue;
    fields[key] = value;
  }

  const songName = fields['标题'] || fields.title;
  const artistNames = fields['艺人'] || fields.artist;
  const eventName = fields['活动'] || fields.event;
  const audioUrl = fields['音频'] || fields.audio;
  const videoUrl = fields['视频'] || fields.video;

  return {
    ...(songName ? { songName } : {}),
    ...(artistNames ? { djNames: artistNames.split(/[,\uFF0C\/\u3001]/g).map((item) => item.trim()).filter(Boolean) } : {}),
    ...(eventName ? { eventName } : {}),
    ...(audioUrl ? { audioUrl } : {}),
    ...(videoUrl ? { videoUrl } : {}),
  };
};

const syncTencentIMUserBestEffort = async (userId: string, reason: string): Promise<void> => {
  try {
    await tencentIMUserService.ensureUsersByIds([userId]);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`[tencent-im] user sync skipped during ${reason}: ${message}`, { userId });
  }
};

const scheduleTencentIMUserSyncBestEffort = (userId: string, reason: string): void => {
  setImmediate(() => {
    void syncTencentIMUserBestEffort(userId, reason);
  });
};

const syncTencentIMFriendshipBestEffort = async (
  userOneId: string,
  userTwoId: string,
  reason: string
): Promise<void> => {
  try {
    await tencentIMFriendService.ensureMutualFriends(userOneId, userTwoId);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`[tencent-im] friend sync skipped during ${reason}: ${message}`, { userOneId, userTwoId });
  }
};

const sendTencentIMFriendCreatedTipBestEffort = async (
  userOneId: string,
  userTwoId: string,
  text: string,
  reason: string
): Promise<void> => {
  try {
    await tencentIMFriendService.sendFriendCreatedTip(userOneId, userTwoId, text);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`[tencent-im] friend tip skipped during ${reason}: ${message}`, { userOneId, userTwoId });
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
const authEmailCodeLength = normalizePositiveInt(process.env.AUTH_EMAIL_CODE_LENGTH, 6, 4, 8);
const authEmailCodeTtlMs = normalizePositiveInt(process.env.AUTH_EMAIL_CODE_TTL_MS, 5 * 60 * 1000, 10_000, 30 * 60 * 1000);
const authEmailSendCooldownMs = normalizePositiveInt(process.env.AUTH_EMAIL_SEND_COOLDOWN_MS, 60 * 1000, 5_000, 10 * 60 * 1000);
const authEmailAddressHourlyLimit = normalizePositiveInt(process.env.AUTH_EMAIL_ADDRESS_HOURLY_LIMIT, 5, 1, 100);
const authEmailIpHourlyLimit = normalizePositiveInt(process.env.AUTH_EMAIL_IP_HOURLY_LIMIT, 30, 1, 1_000);
const authEmailVerifyFailureLimit = normalizePositiveInt(process.env.AUTH_EMAIL_VERIFY_FAILURE_LIMIT, 10, 3, 100);
const authEmailVerifyBlockMs = normalizePositiveInt(process.env.AUTH_EMAIL_VERIFY_BLOCK_MS, 15 * 60 * 1000, 30_000, 24 * 60 * 60 * 1000);
const authEmailProviderMode = (cleanEnv(process.env.AUTH_EMAIL_PROVIDER) || 'mock').toLowerCase();
const authEmailDebugReturnCodeRaw = cleanEnv(process.env.AUTH_EMAIL_DEBUG_RETURN_CODE);
const authEmailDebugAllowlistRaw = cleanEnv(process.env.AUTH_EMAIL_DEBUG_ALLOWLIST);
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
const authWebAdminRefreshTtlMs = normalizePositiveInt(
  process.env.AUTH_WEB_ADMIN_REFRESH_TTL_MS,
  12 * 60 * 60 * 1000,
  5 * 60 * 1000,
  7 * 24 * 60 * 60 * 1000
);
const authWebAdminIdleTtlMs = normalizePositiveInt(
  process.env.AUTH_WEB_ADMIN_IDLE_TTL_MS,
  30 * 60 * 1000,
  60 * 1000,
  24 * 60 * 60 * 1000
);

type AuthClientType = 'ios' | 'android' | 'web_admin' | 'web_public' | 'unknown';

type AuthSessionMetadata = {
  clientType: AuthClientType;
  deviceId: string | null;
  deviceName: string | null;
  platform: string | null;
  appVersion: string | null;
};

const AUTH_CLIENT_TYPES = new Set<AuthClientType>(['ios', 'android', 'web_admin', 'web_public', 'unknown']);

const normalizeAuthClientType = (value: unknown): AuthClientType => {
  const normalized = String(value || '').trim().toLowerCase().replace(/-/g, '_');
  if (AUTH_CLIENT_TYPES.has(normalized as AuthClientType)) {
    return normalized as AuthClientType;
  }
  return 'ios';
};

const firstHeaderValue = (value: string | string[] | undefined): string | undefined => {
  if (Array.isArray(value)) return value[0];
  return value;
};

const normalizeMetadataText = (value: unknown, maxLength = 128): string | null => {
  const trimmed = String(value || '').trim();
  if (!trimmed) return null;
  return trimmed.slice(0, maxLength);
};

const resolveAuthSessionMetadata = (req: Request): AuthSessionMetadata => {
  const body = req.body as Record<string, unknown> | undefined;
  const clientType = normalizeAuthClientType(
    firstHeaderValue(req.headers['x-raver-client-type']) ?? body?.clientType
  );
  return {
    clientType,
    deviceId: normalizeMetadataText(firstHeaderValue(req.headers['x-raver-device-id']) ?? body?.deviceId, 128),
    deviceName: normalizeMetadataText(firstHeaderValue(req.headers['x-raver-device-name']) ?? body?.deviceName, 128),
    platform: normalizeMetadataText(firstHeaderValue(req.headers['x-raver-platform']) ?? body?.platform, 64),
    appVersion: normalizeMetadataText(firstHeaderValue(req.headers['x-raver-app-version']) ?? body?.appVersion, 64),
  };
};

const isWebAdminSession = (clientType: string | null | undefined): boolean => clientType === 'web_admin';

const buildRefreshSessionExpiry = (
  clientType: string | null | undefined,
  now = new Date(),
  existingAbsoluteExpiresAt?: Date | null
): {
  expiresAt: Date;
  idleExpiresAt: Date | null;
  absoluteExpiresAt: Date | null;
  cookieMaxAgeMs: number;
} => {
  if (isWebAdminSession(clientType)) {
    const absoluteExpiresAt = existingAbsoluteExpiresAt && existingAbsoluteExpiresAt.getTime() > now.getTime()
      ? existingAbsoluteExpiresAt
      : new Date(now.getTime() + authWebAdminRefreshTtlMs);
    const idleExpiresAt = new Date(
      Math.min(now.getTime() + authWebAdminIdleTtlMs, absoluteExpiresAt.getTime())
    );
    return {
      expiresAt: absoluteExpiresAt,
      idleExpiresAt,
      absoluteExpiresAt,
      cookieMaxAgeMs: Math.max(1, absoluteExpiresAt.getTime() - now.getTime()),
    };
  }

  const expiresAt = new Date(now.getTime() + REFRESH_TOKEN_TTL_MS);
  return {
    expiresAt,
    idleExpiresAt: null,
    absoluteExpiresAt: null,
    cookieMaxAgeMs: REFRESH_TOKEN_TTL_MS,
  };
};

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

const maskPhoneNumber = (phoneNumber: string): string => {
  const normalized = normalizePhoneNumber(phoneNumber) || phoneNumber.trim();
  if (normalized.length <= 4) return '****';
  const prefix = normalized.slice(0, Math.min(4, Math.max(1, normalized.length - 4)));
  const suffix = normalized.slice(-4);
  return `${prefix}****${suffix}`;
};

const normalizeEmailAddress = (value: unknown): string | null => {
  const email = String(value || '').trim().toLowerCase();
  if (!email || email.length > 254) return null;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return null;
  return email;
};

const maskEmailAddress = (email: string): string => {
  const normalized = normalizeEmailAddress(email) || email.trim().toLowerCase();
  const [localPart, domain] = normalized.split('@');
  if (!localPart || !domain) return '***';
  return `${localPart.slice(0, Math.min(2, localPart.length))}***@${domain}`;
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

const isEmailDebugCodeEnabledForEmail = (email: string): boolean => {
  if (process.env.NODE_ENV === 'production') return false;
  if (authEmailProviderMode !== 'mock') return false;
  if (!parseBool(authEmailDebugReturnCodeRaw, false)) return false;

  const allowlist = (authEmailDebugAllowlistRaw || '')
    .split(',')
    .map((item) => normalizeEmailAddress(item))
    .filter((item): item is string => Boolean(item));

  if (allowlist.length === 0) return true;
  return allowlist.includes(email);
};

const normalizeSmsCode = (value: unknown): string | null => {
  const code = String(value || '').trim();
  if (!/^\d{4,8}$/.test(code)) return null;
  return code;
};

const normalizeEmailCode = (value: unknown): string | null => {
  const code = String(value || '').trim();
  if (!/^\d{4,8}$/.test(code)) return null;
  return code;
};

const generateSmsCode = (): string => {
  const max = 10 ** Math.max(4, Math.min(8, authSmsCodeLength));
  return crypto.randomInt(0, max).toString().padStart(Math.max(4, Math.min(8, authSmsCodeLength)), '0');
};

const generateEmailCode = (): string => {
  const length = Math.max(4, Math.min(8, authEmailCodeLength));
  const max = 10 ** length;
  return crypto.randomInt(0, max).toString().padStart(length, '0');
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

const refreshCookieOptions = (maxAgeMs = REFRESH_TOKEN_TTL_MS): CookieOptions => {
  const secureFallback = process.env.NODE_ENV === 'production';
  const secure = parseBool(authCookieSecureOverride, secureFallback);
  const options: CookieOptions = {
    httpOnly: true,
    sameSite: 'lax',
    secure,
    path: authRefreshCookiePath,
    maxAge: maxAgeMs,
  };
  if (authRefreshCookieDomain) {
    options.domain = authRefreshCookieDomain;
  }
  return options;
};

const setRefreshCookie = (res: Response, refreshToken: string, maxAgeMs = REFRESH_TOKEN_TTL_MS): void => {
  res.cookie(authRefreshCookieName, refreshToken, refreshCookieOptions(maxAgeMs));
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
  regionCode?: string | null;
  birthYear?: number | null;
  ageBand?: string | null;
  guardianContactEmail?: string | null;
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
  req: Request,
  options: { metadata?: AuthSessionMetadata; absoluteExpiresAt?: Date | null } = {}
): Promise<{ refreshToken: string; refreshTokenId: string; cookieMaxAgeMs: number }> => {
  const metadata = options.metadata ?? resolveAuthSessionMetadata(req);
  const now = new Date();
  const refreshToken = generateRefreshToken();
  const tokenHashValue = hashToken(refreshToken);
  const expiry = buildRefreshSessionExpiry(metadata.clientType, now, options.absoluteExpiresAt);
  const created = await prisma.authRefreshToken.create({
    data: {
      userId,
      tokenHash: tokenHashValue,
      userAgent: req.headers['user-agent'] || null,
      ipAddress: getClientIp(req),
      clientType: metadata.clientType,
      deviceId: metadata.deviceId,
      deviceName: metadata.deviceName,
      platform: metadata.platform,
      appVersion: metadata.appVersion,
      expiresAt: expiry.expiresAt,
      idleExpiresAt: expiry.idleExpiresAt,
      absoluteExpiresAt: expiry.absoluteExpiresAt,
    },
    select: { id: true },
  });

  return {
    refreshToken,
    refreshTokenId: created.id,
    cookieMaxAgeMs: expiry.cookieMaxAgeMs,
  };
};

const issueAuthSuccessResponse = async (
  req: Request,
  res: Response,
  user: AuthUserRecord
): Promise<void> => {
  const accountStatus = await accountEnforcementService.getAccountStatus(user.id);
  const accessToken = createAccessTokenForUser(user);
  const refreshSession = await createRefreshSessionForUser(user.id, req);
  setRefreshCookie(res, refreshSession.refreshToken, refreshSession.cookieMaxAgeMs);

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
        regionCode: user.regionCode,
        birthYear: user.birthYear,
        ageBand: user.ageBand,
        guardianContactEmail: user.guardianContactEmail,
      },
      false
    ),
    accountStatus,
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

const revokeRefreshTokensForUser = async (
  tx: PrismaClient | Prisma.TransactionClient,
  userId: string,
  revokedAt: Date,
  options: { exceptTokenHash?: string | null } = {}
): Promise<number> => {
  const result = await tx.authRefreshToken.updateMany({
    where: {
      userId,
      revokedAt: null,
      ...(options.exceptTokenHash ? { tokenHash: { not: options.exceptTokenHash } } : {}),
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

const registerEmailVerifyFailure = async (email: string, now: Date): Promise<{ blockedUntil: Date | null }> => {
  const existing = await prisma.authEmailAuthState.findUnique({
    where: { email },
    select: { failedAttempts: true, blockedUntil: true },
  });

  const previousFailures = existing?.failedAttempts || 0;
  const nextFailures = previousFailures + 1;
  const blockedUntil = nextFailures >= authEmailVerifyFailureLimit
    ? new Date(now.getTime() + authEmailVerifyBlockMs)
    : existing?.blockedUntil || null;

  await prisma.authEmailAuthState.upsert({
    where: { email },
    create: {
      email,
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

const clearEmailVerifyFailures = async (email: string): Promise<void> => {
  await prisma.authEmailAuthState.upsert({
    where: { email },
    create: {
      email,
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

const resolveOrCreatePhoneAuthUser = async (input: {
  phoneNumber: string;
  birthYear?: number | string;
  regionCode?: string;
  guardianContactEmail?: string;
  displayName?: string;
}): Promise<AuthUserRecord | { errorStatus: number; errorBody: Record<string, unknown> }> => {
  const { phoneNumber, birthYear, regionCode, guardianContactEmail, displayName } = input;
  const existing = await prisma.user.findFirst({
    where: { phoneNumber, isActive: true },
    select: {
      id: true,
      username: true,
      displayName: true,
      avatarUrl: true,
      email: true,
      role: true,
      regionCode: true,
      birthYear: true,
      ageBand: true,
      guardianContactEmail: true,
    },
  });
  if (existing) return existing;

  const complianceRegion = regionalCompliance.resolveRegion(regionCode);
  const compliancePolicy = regionalCompliance.policyFor(complianceRegion);
  const normalizedBirthYear =
    typeof birthYear === 'number'
      ? birthYear
      : Number.parseInt(String(birthYear || ''), 10);
  const hasBirthYear = Number.isInteger(normalizedBirthYear);

  if (compliancePolicy.ageDeclarationRequired && !hasBirthYear) {
    return {
      errorStatus: 400,
      errorBody: {
        error: 'Birth year is required before creating a new account in this region',
        code: 'AUTH_BIRTH_YEAR_REQUIRED',
      },
    };
  }

  if (hasBirthYear) {
    const currentYear = new Date().getUTCFullYear();
    if (normalizedBirthYear < 1900 || normalizedBirthYear > currentYear) {
      return { errorStatus: 400, errorBody: { error: 'Birth year is invalid', code: 'AUTH_BIRTH_YEAR_INVALID' } };
    }
    if (regionalCompliance.ageBandForBirthYear(normalizedBirthYear) === 'under_13') {
      return {
        errorStatus: 403,
        errorBody: {
          error: 'You must meet the minimum age requirement to create an account',
          code: 'AUTH_MINIMUM_AGE_NOT_MET',
        },
      };
    }
  }

  const bootstrapIdentity = await generatePhoneBootstrapIdentity(phoneNumber);
  const requestedDisplayName = normalizeDisplayName(displayName);
  const requestedDisplayNameKey = normalizeDisplayNameForUniqueness(requestedDisplayName);
  if (requestedDisplayName) {
    const existingDisplayName = await prisma.user.findUnique({
      where: { displayNameNormalized: requestedDisplayNameKey },
      select: { id: true },
    });
    if (existingDisplayName) {
      return {
        errorStatus: 409,
        errorBody: { error: '昵称已被使用', code: 'AUTH_DISPLAY_NAME_TAKEN' },
      };
    }
  }
  return prisma.user.create({
    data: {
      username: bootstrapIdentity.username,
      email: bootstrapIdentity.email,
      phoneNumber,
      passwordHash: await hashPassword(generateRefreshToken()),
      displayName: requestedDisplayName || bootstrapIdentity.displayName,
      displayNameNormalized: requestedDisplayName ? requestedDisplayNameKey : normalizeDisplayNameForUniqueness(bootstrapIdentity.displayName),
      isActive: true,
      regionCode: complianceRegion,
      birthYear: hasBirthYear ? normalizedBirthYear : null,
      ageBand: hasBirthYear ? regionalCompliance.ageBandForBirthYear(normalizedBirthYear) : 'unknown',
      guardianContactEmail: String(guardianContactEmail || '').trim() || null,
      ageDeclaredAt: hasBirthYear ? new Date() : null,
    },
    select: {
      id: true,
      username: true,
      displayName: true,
      avatarUrl: true,
      email: true,
      role: true,
      regionCode: true,
      birthYear: true,
      ageBand: true,
      guardianContactEmail: true,
    },
  });
};

const isPhoneAuthUserError = (
  value: AuthUserRecord | { errorStatus: number; errorBody: Record<string, unknown> }
): value is { errorStatus: number; errorBody: Record<string, unknown> } => {
  return 'errorStatus' in value;
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
type FeedRecallSource = 'trending' | 'followed_author' | 'followed_dj' | 'behavior_similar';

const resolveFeedExperimentBucket = (req: Request, viewerId: string | undefined): FeedExperimentBucket => {
  return resolveFeedExperimentBucketFromModule(req.query.expBucket ?? req.query.experimentBucket, viewerId);
};

const normalizeFeedMode = (value: unknown): FeedMode => {
  const normalized = String(value || '')
    .trim()
    .toLowerCase();
  if (normalized === 'following') return 'following';
  if (normalized === 'latest') return 'latest';
  return 'recommended';
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
  regionCode?: string | null;
  birthYear?: number | null;
  ageBand?: string | null;
  guardianContactEmail?: string | null;
};

const toUserSummary = (user: BasicUser, isFollowing: boolean) => {
  return {
    id: user.id,
    username: user.username,
    displayName: user.displayName || user.username,
    avatarURL: user.avatarUrl,
    isFollowing,
    regionCode: user.regionCode ?? undefined,
    birthYear: user.birthYear ?? undefined,
    ageBand: user.ageBand ?? undefined,
    guardianContactEmail: user.guardianContactEmail ?? undefined,
  };
};

const toUserSummaryWithFriendship = (
  user: BasicUser,
  isFollowing: boolean,
  isFriend: boolean
) => {
  return {
    ...toUserSummary(user, isFollowing),
    isFriend,
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

const canManageSquadAsMember = (
  membership: { role: string | null } | null | undefined,
  squad: { leaderId: string | null },
  userId: string
): boolean => {
  return Boolean(membership) && (canManageSquad(membership?.role) || squad.leaderId === userId);
};

const ACTIVE_SQUAD_OFFLINE_ACTIVITY_STATUS = 'active';
const SQUAD_OFFLINE_ACTIVITY_CARD_TYPE = 'squad_offline_activity';
const CUSTOM_CARD_BUSINESS_ID = 'raver_custom_card';

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

const normalizeFiniteNumber = (value: unknown): number | null => {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value !== 'string') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const normalizeCoordinate = (
  value: unknown,
  min: number,
  max: number
): number | null => {
  const parsed = normalizeFiniteNumber(value);
  if (parsed === null || parsed < min || parsed > max) return null;
  return parsed;
};

const normalizeOptionalBoolean = (value: unknown): boolean | null => {
  if (typeof value === 'boolean') return value;
  if (typeof value !== 'string') return null;
  const normalized = value.trim().toLowerCase();
  if (['true', '1', 'yes', 'y', 'on'].includes(normalized)) return true;
  if (['false', '0', 'no', 'n', 'off'].includes(normalized)) return false;
  return null;
};

const readJsonNumber = (value: unknown, keys: string[]): number | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  let current: unknown = value;
  for (const key of keys) {
    if (!current || typeof current !== 'object' || Array.isArray(current)) return null;
    current = (current as Record<string, unknown>)[key];
  }
  return normalizeFiniteNumber(current);
};

const readJsonString = (value: unknown, keys: string[]): string | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  let current: unknown = value;
  for (const key of keys) {
    if (!current || typeof current !== 'object' || Array.isArray(current)) return null;
    current = (current as Record<string, unknown>)[key];
  }
  if (typeof current !== 'string') return null;
  const normalized = current.trim();
  return normalized.length > 0 ? normalized : null;
};

const readLocalizedJsonString = (value: unknown, keys: string[]): string | null => {
  return readJsonString(value, [...keys, 'zhHans'])
    ?? readJsonString(value, [...keys, 'zh-Hans'])
    ?? readJsonString(value, [...keys, 'zh'])
    ?? readJsonString(value, [...keys, 'en'])
    ?? readJsonString(value, keys);
};

const resolveEventCoordinate = (event: {
  latitude?: Prisma.Decimal | null;
  longitude?: Prisma.Decimal | null;
  locationPoint?: Prisma.JsonValue | null;
  manualLocation?: Prisma.JsonValue | null;
} | null | undefined): { latitude: number; longitude: number } | null => {
  if (!event) return null;
  const lat = event.latitude === null || event.latitude === undefined ? null : Number(event.latitude);
  const lng = event.longitude === null || event.longitude === undefined ? null : Number(event.longitude);
  if (lat !== null && lng !== null && Number.isFinite(lat) && Number.isFinite(lng)) {
    return { latitude: lat, longitude: lng };
  }

  const pointLat = readJsonNumber(event.locationPoint, ['location', 'lat']);
  const pointLng = readJsonNumber(event.locationPoint, ['location', 'lng']);
  if (pointLat !== null && pointLng !== null) {
    return { latitude: pointLat, longitude: pointLng };
  }

  const manualLat = readJsonNumber(event.manualLocation, ['coordinate', 'lat'])
    ?? readJsonNumber(event.manualLocation, ['location', 'lat']);
  const manualLng = readJsonNumber(event.manualLocation, ['coordinate', 'lng'])
    ?? readJsonNumber(event.manualLocation, ['location', 'lng']);
  if (manualLat !== null && manualLng !== null) {
    return { latitude: manualLat, longitude: manualLng };
  }

  return null;
};

const compactUniqueTextParts = (parts: Array<string | null | undefined>): string[] => {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const part of parts) {
    const normalized = String(part || '').trim();
    if (!normalized) continue;
    const key = normalized.toLocaleLowerCase('zh-Hans-CN');
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(normalized);
  }
  return result;
};

const resolveEventAddressText = (event: {
  venueName?: string | null;
  venueAddress?: string | null;
  city?: string | null;
  country?: string | null;
  manualLocation?: Prisma.JsonValue | null;
  locationPoint?: Prisma.JsonValue | null;
} | null | undefined): string | null => {
  if (!event) return null;
  const formatted = readLocalizedJsonString(event.manualLocation, ['formattedAddressI18n'])
    ?? readLocalizedJsonString(event.locationPoint, ['formattedAddressI18n'])
    ?? readLocalizedJsonString(event.manualLocation, ['detailAddressI18n']);
  const parts = compactUniqueTextParts([
    event.venueName,
    event.venueAddress,
    formatted,
    event.city,
    event.country,
  ]);
  return parts.length > 0 ? parts.join(' · ') : null;
};

type SquadOfflineActivityWithDetails = Prisma.SquadOfflineActivityGetPayload<{
  include: {
    createdBy: {
      select: {
        id: true;
        username: true;
        displayName: true;
        avatarUrl: true;
      };
    };
    event: {
      select: {
        id: true;
        name: true;
        coverImageUrl: true;
        venueName: true;
        venueAddress: true;
        city: true;
        country: true;
        latitude: true;
        longitude: true;
        locationPoint: true;
        manualLocation: true;
      };
    };
    participants: {
      include: {
        user: {
          select: {
            id: true;
            username: true;
            displayName: true;
            avatarUrl: true;
          };
        };
      };
      orderBy: { joinedAt: 'asc' };
    };
  };
}>;

const fetchActiveSquadOfflineActivity = async (squadId: string): Promise<SquadOfflineActivityWithDetails | null> => {
  return prisma.squadOfflineActivity.findFirst({
    where: {
      squadId,
      status: ACTIVE_SQUAD_OFFLINE_ACTIVITY_STATUS,
      endedAt: null,
    },
    include: {
      createdBy: {
        select: {
          id: true,
          username: true,
          displayName: true,
          avatarUrl: true,
        },
      },
      event: {
        select: {
          id: true,
          name: true,
          coverImageUrl: true,
          venueName: true,
          venueAddress: true,
          city: true,
          country: true,
          latitude: true,
          longitude: true,
          locationPoint: true,
          manualLocation: true,
        },
      },
      participants: {
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
        orderBy: { joinedAt: 'asc' },
      },
    },
    orderBy: { startedAt: 'desc' },
  });
};

const fetchSquadOfflineActivityById = async (activityId: string): Promise<SquadOfflineActivityWithDetails | null> => {
  return prisma.squadOfflineActivity.findUnique({
    where: { id: activityId },
    include: {
      createdBy: {
        select: {
          id: true,
          username: true,
          displayName: true,
          avatarUrl: true,
        },
      },
      event: {
        select: {
          id: true,
          name: true,
          coverImageUrl: true,
          venueName: true,
          venueAddress: true,
          city: true,
          country: true,
          latitude: true,
          longitude: true,
          locationPoint: true,
          manualLocation: true,
        },
      },
      participants: {
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
        orderBy: { joinedAt: 'asc' },
      },
    },
  });
};

const toSquadOfflineActivityResponse = async (
  activity: SquadOfflineActivityWithDetails | null,
  viewerUserId: string,
  viewerCanManage = false
) => {
  if (!activity) return null;

  const latestLocations = await prisma.squadOfflineActivityLocation.findMany({
    where: {
      activityId: activity.id,
      userId: { in: activity.participants.map((participant) => participant.userId) },
    },
    distinct: ['userId'],
    orderBy: [
      { userId: 'asc' },
      { capturedAt: 'desc' },
    ],
    select: {
      userId: true,
      latitude: true,
      longitude: true,
      accuracy: true,
      capturedAt: true,
    },
  });
  const latestLocationMap = new Map(latestLocations.map((item) => [item.userId, item]));
  const viewerRoute = await prisma.squadOfflineActivityLocation.findMany({
    where: {
      activityId: activity.id,
      userId: viewerUserId,
    },
    orderBy: { capturedAt: 'asc' },
    select: {
      latitude: true,
      longitude: true,
      accuracy: true,
      capturedAt: true,
    },
  });
  const statusCounts = await prisma.squadOfflineActivityStatusEvent.groupBy({
    by: ['statusType'],
    where: {
      activityId: activity.id,
      userId: viewerUserId,
      isActive: true,
    },
    _count: { _all: true },
  });
  const viewerSummary = {
    restroomCount: statusCounts.find((item) => item.statusType === 'restroom')?._count._all ?? 0,
    buyingDrinkCount: statusCounts.find((item) => item.statusType === 'buying_drink')?._count._all ?? 0,
  };
  const eventCoordinate = resolveEventCoordinate(activity.event);
  const hasEnded = activity.status !== ACTIVE_SQUAD_OFFLINE_ACTIVITY_STATUS || Boolean(activity.endedAt);

  return {
    id: activity.id,
    squadID: activity.squadId,
    eventID: activity.eventId,
    eventName: activity.event?.name ?? activity.title,
    eventCoverImageURL: activity.event?.coverImageUrl ?? null,
    eventVenueName: activity.event?.venueName ?? null,
    eventVenueAddress: activity.event?.venueAddress ?? null,
    eventAddressText: resolveEventAddressText(activity.event),
    eventCity: activity.event?.city ?? null,
    eventCoordinate,
    title: activity.title,
    status: activity.status,
    startedAt: activity.startedAt,
    endedAt: activity.endedAt,
    createdBy: toUserSummary(activity.createdBy, false),
    isCreatedByMe: activity.createdById === viewerUserId,
    canManage: viewerCanManage || activity.createdById === viewerUserId,
    participantCount: hasEnded
      ? activity.participants.length
      : activity.participants.filter((participant) => !participant.leftAt).length,
    isJoined: activity.participants.some((participant) => participant.userId === viewerUserId && !participant.leftAt),
    uploadIntervalSeconds: 300,
    viewerSummary,
    viewerRoute: viewerRoute.map((location) => ({
      latitude: Number(location.latitude),
      longitude: Number(location.longitude),
      accuracy: location.accuracy,
      capturedAt: location.capturedAt,
    })),
    participants: activity.participants.map((participant) => {
      const location = latestLocationMap.get(participant.userId);
      return {
        id: participant.userId,
        username: participant.user.username,
        displayName: participant.user.displayName || participant.user.username,
        avatarURL: participant.user.avatarUrl,
        isFollowing: false,
        joinedAt: participant.joinedAt,
        leftAt: participant.leftAt,
        isInRestroom: participant.isInRestroom,
        isBuyingDrink: participant.isBuyingDrink,
        latestLocation: location
          ? {
              latitude: Number(location.latitude),
              longitude: Number(location.longitude),
              accuracy: location.accuracy,
              capturedAt: location.capturedAt,
            }
          : null,
      };
    }),
  };
};

const offlineActivityDurationSeconds = (startedAt: Date, endedAt: Date): number => {
  return Math.max(0, Math.floor((endedAt.getTime() - startedAt.getTime()) / 1000));
};

const formatDurationZh = (durationSeconds: number): string => {
  const hours = Math.floor(durationSeconds / 3600);
  const minutes = Math.floor((durationSeconds % 3600) / 60);
  if (hours > 0) return `${hours} 小时 ${minutes} 分钟`;
  if (minutes > 0) return `${minutes} 分钟`;
  return '<1 分钟';
};

const buildSquadOfflineActivityCardPayload = (activity: {
  id: string;
  squadId: string;
  title: string | null;
  eventId: string | null;
  event?: {
    name: string;
    venueName: string | null;
    city: string | null;
    coverImageUrl: string | null;
  } | null;
  startedAt: Date;
  endedAt: Date | null;
  participants: Array<{ userId: string }>;
}) => {
  const endedAt = activity.endedAt ?? new Date();
  const durationSeconds = offlineActivityDurationSeconds(activity.startedAt, endedAt);
  const participantCount = new Set(activity.participants.map((participant) => participant.userId)).size;
  const title = activity.event?.name || activity.title || '小队线下活动';
  return {
    activityID: activity.id,
    squadID: activity.squadId,
    eventID: activity.eventId,
    title,
    eventName: activity.event?.name ?? null,
    venueName: activity.event?.venueName ?? null,
    city: activity.event?.city ?? null,
    coverImageURL: activity.event?.coverImageUrl ?? null,
    startedAt: activity.startedAt,
    endedAt,
    durationSeconds,
    durationText: formatDurationZh(durationSeconds),
    participantCount,
  };
};

const encodeSquadOfflineActivityCardContent = (payload: ReturnType<typeof buildSquadOfflineActivityCardPayload>): string => {
  return JSON.stringify({
    businessID: CUSTOM_CARD_BUSINESS_ID,
    version: 1,
    cardType: SQUAD_OFFLINE_ACTIVITY_CARD_TYPE,
    payload,
  });
};

const sendSquadOfflineActivityCardToTencentIM = async (
  squadId: string,
  senderUserId: string,
  payload: ReturnType<typeof buildSquadOfflineActivityCardPayload>
): Promise<void> => {
  await tencentIMGroupService.sendSquadCustomCardMessage(
    squadId,
    senderUserId,
    {
      businessID: CUSTOM_CARD_BUSINESS_ID,
      version: 1,
      cardType: SQUAD_OFFLINE_ACTIVITY_CARD_TYPE,
      payload,
    },
    `线下活动结束：${payload.title}`
  );
};

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

const buildBlockedRelationUserIds = async (viewerId: string | undefined | null): Promise<Set<string>> => {
  if (!viewerId) {
    return new Set<string>();
  }

  const rows = await prisma.userBlock.findMany({
    where: {
      OR: [
        { blockerUserId: viewerId },
        { blockedUserId: viewerId },
      ],
    },
    select: {
      blockerUserId: true,
      blockedUserId: true,
    },
  });

  return new Set(
    rows
      .map((row) => (row.blockerUserId === viewerId ? row.blockedUserId : row.blockerUserId))
      .filter((id): id is string => Boolean(id && id !== viewerId))
  );
};

const hasBlockingRelationship = async (userAId: string, userBId: string): Promise<boolean> => {
  if (!userAId || !userBId || userAId === userBId) {
    return false;
  }

  const block = await prisma.userBlock.findFirst({
    where: {
      OR: [
        { blockerUserId: userAId, blockedUserId: userBId },
        { blockerUserId: userBId, blockedUserId: userAId },
      ],
    },
    select: { id: true },
  });

  return Boolean(block);
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

const mapEventLiveComment = (
  comment: {
    id: string;
    eventId: string;
    parentCommentId?: string | null;
    rootCommentId?: string | null;
    depth?: number | null;
    user: BasicUser;
    replyToUser?: BasicUser | null;
    content: string;
    imageUrls?: string[] | null;
    likeCount?: number | null;
    createdAt: Date;
  },
  followingSet: Set<string>,
  likedCommentIds: Set<string> = new Set()
) => ({
  id: comment.id,
  eventID: comment.eventId,
  parentCommentID: comment.parentCommentId ?? null,
  rootCommentID: comment.rootCommentId ?? null,
  depth: comment.depth ?? 0,
  author: toUserSummary(comment.user, followingSet.has(comment.user.id)),
  replyToAuthor: comment.replyToUser ? toUserSummary(comment.replyToUser, followingSet.has(comment.replyToUser.id)) : null,
  content: comment.content,
  imageURLs: comment.imageUrls ?? [],
  likeCount: comment.likeCount ?? 0,
  isLiked: likedCommentIds.has(comment.id),
  createdAt: comment.createdAt,
});

const buildLikedEventLiveCommentMap = async (viewerId: string | undefined, commentIds: string[]) => {
  if (!viewerId || commentIds.length === 0) {
    return new Set<string>();
  }
  const rows = await prisma.eventLiveCommentLike.findMany({
    where: {
      userId: viewerId,
      commentId: { in: commentIds },
    },
    select: { commentId: true },
  });
  return new Set(rows.map((row) => row.commentId));
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

const normalizeDirectPair = (userOneId: string, userTwoId: string): [string, string] => {
  return userOneId <= userTwoId ? [userOneId, userTwoId] : [userTwoId, userOneId];
};

const FRIEND_CHAT_GREETING = '你们已成功添加好友，现在可以开始聊天了';

const isMutualFriend = async (userOneId: string, userTwoId: string): Promise<boolean> => {
  const [outgoing, incoming] = await Promise.all([
    prisma.follow.findUnique({
      where: {
        followerId_followingId: {
          followerId: userOneId,
          followingId: userTwoId,
        },
      },
      select: { id: true },
    }),
    prisma.follow.findUnique({
      where: {
        followerId_followingId: {
          followerId: userTwoId,
          followingId: userOneId,
        },
      },
      select: { id: true },
    }),
  ]);
  return Boolean(outgoing && incoming);
};

const ensureFriendConversationWithGreeting = async (
  userOneId: string,
  userTwoId: string
): Promise<{ conversationId: string; createdGreeting: boolean }> => {
  const [userAId, userBId] = normalizeDirectPair(userOneId, userTwoId);

  return prisma.$transaction(async (tx) => {
    const conversation = await tx.directConversation.upsert({
      where: {
        userAId_userBId: { userAId, userBId },
      },
      update: {},
      create: {
        userAId,
        userBId,
      },
      select: { id: true },
    });

    const existingGreeting = await tx.directMessage.findFirst({
      where: {
        conversationId: conversation.id,
        senderId: userAId,
        type: 'system_friend_created',
      },
      select: { id: true },
    });

    if (existingGreeting) {
      return { conversationId: conversation.id, createdGreeting: false };
    }

    await tx.directMessage.create({
      data: {
        conversationId: conversation.id,
        senderId: userAId,
        content: FRIEND_CHAT_GREETING,
        type: 'system_friend_created',
      },
    });

    await tx.directConversation.update({
      where: { id: conversation.id },
      data: { updatedAt: new Date() },
    });

    return { conversationId: conversation.id, createdGreeting: true };
  });
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
  const [followingSet, friendSet] = await Promise.all([
    buildFollowingMap(viewerId, [targetUser.id]),
    buildFriendUserIds(viewerId, [targetUser.id]),
  ]);
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
    peer: toUserSummaryWithFriendship(
      targetUser,
      followingSet.has(targetUser.id),
      friendSet.has(targetUser.id)
    ),
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

    const rows = await prisma.eventFavorite.findMany({
      where: {
        eventId: eventID,
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

const publishFollowedDJNewsSafely = async (params: {
  actorUserId: string;
  postId: string;
  content: string;
  imageURLs: string[];
  boundDjIDs: string[];
  occurredAt: Date;
}): Promise<void> => {
  const normalizedDJIDs = Array.from(
    new Set(params.boundDjIDs.map((item) => item.trim()).filter((item) => item.length > 0))
  );
  if (normalizedDJIDs.length === 0) {
    return;
  }

  const decodedNews = decodeRaverNewsDraft(params.content);
  if (!decodedNews) {
    return;
  }

  const djs = await prisma.dJ.findMany({
    where: {
      id: {
        in: normalizedDJIDs,
      },
    },
    select: {
      id: true,
      name: true,
    },
  });
  if (djs.length === 0) {
    return;
  }

  const djNameByID = new Map(djs.map((item) => [item.id, item.name.trim() || item.id]));
  const coverImageURL = params.imageURLs.find((item) => item.trim().length > 0)?.trim() || null;
  const fallbackSummary = newsSingleLine(decodedNews.body).slice(0, 140);
  const newsSummary = decodedNews.summary || fallbackSummary || '你关注的DJ发布了新的资讯。';

  for (const djID of normalizedDJIDs) {
    const djName = djNameByID.get(djID);
    if (!djName) continue;

    const rows = await prisma.follow.findMany({
      where: {
        djId: djID,
        type: 'dj',
      },
      select: {
        followerId: true,
      },
    });

    const targetUserIds = normalizeNotificationTargets(rows.map((item) => item.followerId));
    if (targetUserIds.length === 0) {
      continue;
    }

    void notificationCenterService
      .publish({
        category: 'followed_dj_update',
        targets: targetUserIds.map((userId) => ({ userId })),
        channels: ['in_app', 'apns'],
        payload: {
          title: `${djName} 发布了新资讯`,
          body: decodedNews.title,
          deeplink: `raver://news/${encodeURIComponent(params.postId)}`,
          metadata: {
            route: 'dj_update',
            primaryUpdateKind: 'news',
            updateKind: 'news',
            djID,
            djName,
            newsID: params.postId,
            newsTitle: decodedNews.title,
            newsSummary,
            newsCoverImageURL: coverImageURL,
            occurredAt: params.occurredAt.toISOString(),
            source: 'followed_dj_news_publish',
            sourceAudience: 'followed_dj_users',
          },
        },
        dedupeKey: `dj-news:${djID}:post:${params.postId}`,
      })
      .catch((error) => {
        const message = error instanceof Error ? error.message : String(error);
        console.error(`[notification-center] followed dj news publish failed dj=${djID} error=${message}`);
      });
  }
};

const publishFollowedBrandNewsSafely = async (params: {
  actorUserId: string;
  postId: string;
  content: string;
  imageURLs: string[];
  boundBrandIDs: string[];
  occurredAt: Date;
}): Promise<void> => {
  const normalizedBrandIDs = Array.from(
    new Set(params.boundBrandIDs.map((item) => item.trim()).filter((item) => item.length > 0))
  );
  if (normalizedBrandIDs.length === 0) {
    return;
  }

  const decodedNews = decodeRaverNewsDraft(params.content);
  if (!decodedNews) {
    return;
  }

  const [wikiBrands, labels] = await Promise.all([
    prisma.wikiFestival.findMany({
      where: {
        id: {
          in: normalizedBrandIDs,
        },
      },
      select: {
        id: true,
        name: true,
      },
    }),
    prisma.label.findMany({
      where: {
        id: {
          in: normalizedBrandIDs,
        },
      },
      select: {
        id: true,
        name: true,
      },
    }),
  ]);

  const brandNameByID = new Map<string, string>();
  for (const brand of wikiBrands) {
    brandNameByID.set(brand.id, brand.name.trim() || brand.id);
  }
  for (const brand of labels) {
    if (!brandNameByID.has(brand.id)) {
      brandNameByID.set(brand.id, brand.name.trim() || brand.id);
    }
  }
  if (brandNameByID.size == 0) {
    return;
  }

  const subscriptions = await notificationCenterService.fetchFollowedBrandUpdateSubscriptions();
  if (subscriptions.length === 0) {
    return;
  }

  const coverImageURL = params.imageURLs.find((item) => item.trim().length > 0)?.trim() || null;
  const fallbackSummary = newsSingleLine(decodedNews.body).slice(0, 140);
  const newsSummary = decodedNews.summary || fallbackSummary || '你关注的音乐节发布了新的资讯。';

  for (const brandID of normalizedBrandIDs) {
    const brandName = brandNameByID.get(brandID);
    if (!brandName) continue;

    const targetUserIds = normalizeNotificationTargets(
      subscriptions
        .filter((item) => item.preference.enabled && item.preference.watchedBrandIds.includes(brandID))
        .map((item) => item.userId)
    );
    if (targetUserIds.length === 0) {
      continue;
    }

    void notificationCenterService
      .publish({
        category: 'followed_brand_update',
        targets: targetUserIds.map((userId) => ({ userId })),
        channels: ['in_app', 'apns'],
        payload: {
          title: `${brandName} 发布了新资讯`,
          body: decodedNews.title,
          deeplink: `raver://news/${encodeURIComponent(params.postId)}`,
          metadata: {
            route: 'brand_update',
            primaryUpdateKind: 'news',
            updateKind: 'news',
            brandID,
            brandName,
            newsID: params.postId,
            newsTitle: decodedNews.title,
            newsSummary,
            newsCoverImageURL: coverImageURL,
            occurredAt: params.occurredAt.toISOString(),
            source: 'followed_brand_news_publish',
            sourceAudience: 'followed_brand_users',
          },
        },
        dedupeKey: `brand-news:${brandID}:post:${params.postId}`,
      })
      .catch((error) => {
        const message = error instanceof Error ? error.message : String(error);
        console.error(`[notification-center] followed brand news publish failed brand=${brandID} error=${message}`);
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
      authEmailSend: 'POST /v1/auth/email/send',
      authEmailLogin: 'POST /v1/auth/email/login',
      authEmailRegister: 'POST /v1/auth/email/register',
      authSmsSend: 'POST /v1/auth/sms/send',
      authSmsLogin: 'POST /v1/auth/sms/login',
      authRefresh: 'POST /v1/auth/refresh',
      authLogout: 'POST /v1/auth/logout',
      authLogoutAll: 'POST /v1/auth/logout-all',
      authAccountDelete: 'DELETE /v1/auth/account',
      accountStatus: 'GET /v1/account/status',
      accountEnforcements: 'GET /v1/account/enforcements',
      accountEnforcementAppeal: 'POST /v1/account/enforcements/:id/appeal',
      accountAppeals: 'GET /v1/account/appeals',
      reportContent: 'POST /v1/reports',
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
      blockUser: 'POST /v1/social/users/:id/block',
      unblockUser: 'DELETE /v1/social/users/:id/block',
    },
  });
});

router.post('/share-links/resolve', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const body = (req.body ?? {}) as Record<string, unknown>;
    const targetType = String(body.targetType ?? '').trim();
    const targetId = String(body.targetId ?? '').trim();
    const channel = typeof body.channel === 'string' ? body.channel.trim() : null;
    const campaign = typeof body.campaign === 'string' ? body.campaign.trim() : null;
    const preferPermanent = body.preferPermanent !== false;
    const expiresInHours = typeof body.expiresInHours === 'number' ? body.expiresInHours : null;
    const maxUses = typeof body.maxUses === 'number' ? body.maxUses : null;
    const targetSeed = typeof body.targetSeed === 'object' && body.targetSeed !== null
      ? body.targetSeed as Record<string, unknown>
      : null;

    const payload = await resolveOrCreateShareLink({
      prisma,
      targetType,
      targetId,
      channel,
      campaign,
      preferPermanent,
      userId: authReq.user?.userId ?? null,
      expiresInHours,
      maxUses,
      targetSeed: targetSeed ? {
        canonicalUrl: typeof targetSeed.canonicalUrl === 'string' ? targetSeed.canonicalUrl.trim() : null,
        deepLink: typeof targetSeed.deepLink === 'string' ? targetSeed.deepLink.trim() : null,
        fallbackUrl: typeof targetSeed.fallbackUrl === 'string' ? targetSeed.fallbackUrl.trim() : null,
        title: typeof targetSeed.title === 'string' ? targetSeed.title.trim() : null,
        subtitle: typeof targetSeed.subtitle === 'string' ? targetSeed.subtitle.trim() : null,
        imageUrl: typeof targetSeed.imageUrl === 'string' ? targetSeed.imageUrl.trim() : null,
        previewType: typeof targetSeed.previewType === 'string' ? targetSeed.previewType.trim() : null,
        visibility: typeof targetSeed.visibility === 'string' ? targetSeed.visibility.trim() : null,
      } : null,
    });

    res.json(payload);
  } catch (error) {
    if (error instanceof ShareLinkError) {
      res.status(error.status).json({ error: error.code, message: error.message });
      return;
    }
    console.error('BFF resolve share link error:', error);
    res.status(500).json({ error: 'internal_server_error' });
  }
});

router.get('/share-links/:code', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const payload = await getShareLinkByCode(prisma, req.params.code as string);
    res.json(payload);
  } catch (error) {
    if (error instanceof ShareLinkError) {
      res.status(error.status).json({ error: error.code, message: error.message });
      return;
    }
    console.error('BFF get share link error:', error);
    res.status(500).json({ error: 'internal_server_error' });
  }
});

router.post('/share-links/:code/events', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const body = (req.body ?? {}) as Record<string, unknown>;
    const payload = await recordShareLinkEvent({
      prisma,
      code: req.params.code as string,
      eventType: String(body.eventType ?? '').trim(),
      channel: typeof body.channel === 'string' ? body.channel.trim() : null,
      userId: authReq.user?.userId ?? null,
      anonymousId: typeof body.anonymousId === 'string' ? body.anonymousId.trim() : null,
      platform: typeof body.platform === 'string' ? body.platform.trim() : 'iOS',
      userAgent: typeof req.headers['user-agent'] === 'string' ? req.headers['user-agent'] : null,
      referrer: typeof req.headers.referer === 'string' ? req.headers.referer : null,
      metadata: typeof body.metadata === 'object' && body.metadata !== null
        ? body.metadata as Prisma.InputJsonValue
        : undefined,
    });
    res.json(payload);
  } catch (error) {
    if (error instanceof ShareLinkError) {
      res.status(error.status).json({ error: error.code, message: error.message });
      return;
    }
    console.error('BFF record share link event error:', error);
    res.status(500).json({ error: 'internal_server_error' });
  }
});

router.post('/share-links/:code/redeem', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = (req.body ?? {}) as Record<string, unknown>;
    const payload = await redeemShareLinkInvite({
      prisma,
      code: req.params.code as string,
      userId,
      channel: typeof body.channel === 'string' ? body.channel.trim() : 'invite_redeem',
      platform: typeof body.platform === 'string' ? body.platform.trim() : 'iOS',
      userAgent: typeof req.headers['user-agent'] === 'string' ? req.headers['user-agent'] : null,
      referrer: typeof req.headers.referer === 'string' ? req.headers.referer : null,
    });
    res.json(payload);
  } catch (error) {
    if (error instanceof ShareLinkError) {
      res.status(error.status).json({ error: error.code, message: error.message });
      return;
    }
    console.error('BFF redeem share invite error:', error);
    res.status(500).json({ error: 'internal_server_error' });
  }
});

router.post('/share-links/:code/reset', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const payload = await resetShareLinkInvite(prisma, req.params.code as string, userId);
    res.json(payload);
  } catch (error) {
    if (error instanceof ShareLinkError) {
      res.status(error.status).json({ error: error.code, message: error.message });
      return;
    }
    console.error('BFF reset share invite error:', error);
    res.status(500).json({ error: 'internal_server_error' });
  }
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
    const loginDisplayNameKey = normalizeDisplayNameForUniqueness(loginIdentifier);
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
          { displayNameNormalized: loginDisplayNameKey },
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

    if (await denyForEnforcement(user.id, 'login', res)) {
      writeAuthAuditLog(req, {
        action: 'auth.login',
        outcome: 'blocked',
        userId: user.id,
        identifier: loginIdentifier,
        errorCode: 'AUTH_ACCOUNT_ENFORCEMENT_BLOCKED',
      });
      return;
    }

    clearRateBucket(authLoginRateBuckets, loginRateKey);

    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    scheduleTencentIMUserSyncBestEffort(user.id, 'bff-auth-login');
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
      regionCode: user.regionCode,
      birthYear: user.birthYear,
      ageBand: user.ageBand,
      guardianContactEmail: user.guardianContactEmail,
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

router.get('/auth/display-name/check', async (req: Request, res: Response): Promise<void> => {
  try {
    const displayName = normalizeDisplayName(String(req.query.displayName || ''));
    const displayNameKey = normalizeDisplayNameForUniqueness(displayName);
    if (!displayName || displayName.length < 2 || displayName.length > 24) {
      res.status(400).json({
        available: false,
        code: 'AUTH_DISPLAY_NAME_INVALID',
        error: '昵称需要 2-24 个字符',
      });
      return;
    }

    const exists = await prisma.user.findUnique({
      where: { displayNameNormalized: displayNameKey },
      select: { id: true },
    });
    res.json({
      available: !exists,
      code: exists ? 'AUTH_DISPLAY_NAME_TAKEN' : 'AUTH_DISPLAY_NAME_AVAILABLE',
    });
  } catch (error) {
    console.error('BFF display name check error:', error);
    res.status(500).json({ available: false, error: 'Internal server error', code: 'AUTH_INTERNAL_ERROR' });
  }
});

router.post('/auth/register', async (req: Request, res: Response): Promise<void> => {
  try {
    const { username, email, password, displayName, birthYear, regionCode, guardianContactEmail } = req.body as {
      username?: string;
      email?: string;
      password?: string;
      displayName?: string;
      birthYear?: number | string;
      regionCode?: string;
      guardianContactEmail?: string;
    };

    const requestedUsername = String(username || '').trim().toLowerCase();
    const normalizedEmail = String(email || '').trim().toLowerCase();
    const normalizedDisplayName = normalizeDisplayName(displayName);
    const normalizedDisplayNameKey = normalizeDisplayNameForUniqueness(normalizedDisplayName);
    const complianceRegion = regionalCompliance.resolveRegion(regionCode);
    const compliancePolicy = regionalCompliance.policyFor(complianceRegion);
    const normalizedBirthYear =
      typeof birthYear === 'number'
        ? birthYear
        : Number.parseInt(String(birthYear || ''), 10);
    const hasBirthYear = Number.isInteger(normalizedBirthYear);
    const nowMs = Date.now();
    const registerIdentifier = normalizedEmail || normalizedDisplayNameKey || requestedUsername || 'unknown';
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

    if (!normalizedDisplayName || !normalizedEmail || !password) {
      writeAuthAuditLog(req, {
        action: 'auth.register',
        outcome: 'failed',
        identifier: registerIdentifier,
        errorCode: 'AUTH_INVALID_REQUEST',
      });
      res.status(400).json({ error: 'displayName, email, and password are required' });
      return;
    }

    if (normalizedDisplayName.length < 2 || normalizedDisplayName.length > 24) {
      writeAuthAuditLog(req, {
        action: 'auth.register',
        outcome: 'failed',
        identifier: registerIdentifier,
        errorCode: 'AUTH_DISPLAY_NAME_INVALID',
      });
      res.status(400).json({ error: '昵称需要 2-24 个字符' });
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

    if (compliancePolicy.ageDeclarationRequired && !hasBirthYear) {
      writeAuthAuditLog(req, {
        action: 'auth.register',
        outcome: 'failed',
        identifier: registerIdentifier,
        errorCode: 'AUTH_BIRTH_YEAR_REQUIRED',
        detail: { region: complianceRegion },
      });
      res.status(400).json({ error: 'Birth year is required for this region' });
      return;
    }

    if (hasBirthYear) {
      const currentYear = new Date().getUTCFullYear();
      if (normalizedBirthYear < 1900 || normalizedBirthYear > currentYear) {
        writeAuthAuditLog(req, {
          action: 'auth.register',
          outcome: 'failed',
          identifier: registerIdentifier,
          errorCode: 'AUTH_BIRTH_YEAR_INVALID',
          detail: { region: complianceRegion },
        });
        res.status(400).json({ error: 'Birth year is invalid' });
        return;
      }
      const ageBand = regionalCompliance.ageBandForBirthYear(normalizedBirthYear);
      if (ageBand === 'under_13') {
        writeAuthAuditLog(req, {
          action: 'auth.register',
          outcome: 'blocked',
          identifier: registerIdentifier,
          errorCode: 'AUTH_MINIMUM_AGE_NOT_MET',
          detail: { region: complianceRegion },
        });
        res.status(403).json({ error: 'You must meet the minimum age requirement to create an account' });
        return;
      }
    }

    const exists = await prisma.user.findFirst({
      where: {
        OR: [
          { email: normalizedEmail },
          { displayNameNormalized: normalizedDisplayNameKey },
          ...(requestedUsername ? [{ username: requestedUsername }] : []),
        ],
      },
      select: { id: true, email: true, displayNameNormalized: true, username: true },
    });

    if (exists) {
      writeAuthAuditLog(req, {
        action: 'auth.register',
        outcome: 'failed',
        identifier: registerIdentifier,
        errorCode: 'AUTH_USER_EXISTS',
      });
      res.status(409).json({
        error: exists.displayNameNormalized === normalizedDisplayNameKey ? '昵称已被使用' : 'User already exists',
      });
      return;
    }

    const internalUsername = requestedUsername || await createInternalUsername(normalizedEmail.split('@')[0] || normalizedDisplayNameKey);
    const user = await prisma.user.create({
      data: {
        username: internalUsername,
        email: normalizedEmail,
        passwordHash: await hashPassword(password),
        displayName: normalizedDisplayName,
        displayNameNormalized: normalizedDisplayNameKey,
        displayNameStatus: 'pending',
        regionCode: complianceRegion,
        birthYear: hasBirthYear ? normalizedBirthYear : null,
        ageBand: hasBirthYear ? regionalCompliance.ageBandForBirthYear(normalizedBirthYear) : 'unknown',
        guardianContactEmail: String(guardianContactEmail || '').trim() || null,
        ageDeclaredAt: hasBirthYear ? new Date() : null,
      },
      select: {
        id: true,
        username: true,
        email: true,
        displayName: true,
        avatarUrl: true,
        role: true,
        regionCode: true,
        birthYear: true,
        ageBand: true,
        guardianContactEmail: true,
      },
    });

    await createProfileModerationJob(
      user.id,
      'display_name',
      normalizedDisplayName,
      normalizedDisplayNameKey
    );

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
      regionCode: user.regionCode,
      birthYear: user.birthYear,
      ageBand: user.ageBand,
      guardianContactEmail: user.guardianContactEmail,
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

router.post('/auth/email/send', async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, scene } = req.body as { email?: string; scene?: string };
    const normalizedEmail = normalizeEmailAddress(email);
    const sceneKey = String(scene || 'login').trim().toLowerCase() || 'login';
    const now = new Date();
    const clientIp = getClientIp(req);

    if (!normalizedEmail) {
      res.status(400).json({ error: 'Invalid email address', code: 'AUTH_EMAIL_INVALID' });
      return;
    }

    if (sceneKey !== 'login' && sceneKey !== 'register') {
      res.status(400).json({ error: 'Unsupported email scene', code: 'AUTH_EMAIL_SCENE_UNSUPPORTED' });
      return;
    }

    const existingUser = await prisma.user.findUnique({
      where: { email: normalizedEmail },
      select: { id: true, isActive: true },
    });

    if (sceneKey === 'login' && (!existingUser || !existingUser.isActive)) {
      res.status(404).json({ error: 'Email is not registered', code: 'AUTH_EMAIL_NOT_REGISTERED' });
      return;
    }

    if (sceneKey === 'register' && existingUser) {
      res.status(409).json({ error: 'Email is already registered', code: 'AUTH_EMAIL_ALREADY_REGISTERED' });
      return;
    }

    const [lastSent, sentByEmailInLastHour, sentByIpInLastHour] = await Promise.all([
      prisma.authEmailCode.findFirst({
        where: { email: normalizedEmail, scene: sceneKey },
        orderBy: { createdAt: 'desc' },
        select: { createdAt: true },
      }),
      prisma.authEmailCode.count({
        where: {
          email: normalizedEmail,
          scene: sceneKey,
          createdAt: { gte: new Date(now.getTime() - 60 * 60 * 1000) },
        },
      }),
      prisma.authEmailCode.count({
        where: {
          sendIp: clientIp,
          createdAt: { gte: new Date(now.getTime() - 60 * 60 * 1000) },
        },
      }),
    ]);

    if (lastSent && now.getTime() - lastSent.createdAt.getTime() < authEmailSendCooldownMs) {
      const retryAfterMs = authEmailSendCooldownMs - (now.getTime() - lastSent.createdAt.getTime());
      res.status(429).json({
        error: 'Email code request too frequent',
        code: 'AUTH_EMAIL_SEND_COOLDOWN',
        retryAfterSeconds: Math.ceil(retryAfterMs / 1000),
      });
      return;
    }

    if (sentByEmailInLastHour >= authEmailAddressHourlyLimit) {
      res.status(429).json({
        error: 'Email hourly limit exceeded',
        code: 'AUTH_EMAIL_ADDRESS_HOURLY_LIMIT',
        retryAfterSeconds: 60 * 60,
      });
      return;
    }

    if (sentByIpInLastHour >= authEmailIpHourlyLimit) {
      res.status(429).json({
        error: 'Email ip hourly limit exceeded',
        code: 'AUTH_EMAIL_IP_HOURLY_LIMIT',
        retryAfterSeconds: 60 * 60,
      });
      return;
    }

    const code = generateEmailCode();
    await emailService.sendAuthCode(normalizedEmail, code, sceneKey);

    await prisma.authEmailCode.create({
      data: {
        email: normalizedEmail,
        scene: sceneKey,
        codeHash: hashToken(code),
        sendIp: clientIp,
        expiresAt: new Date(now.getTime() + authEmailCodeTtlMs),
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
      expiresInSeconds: Math.max(1, Math.floor(authEmailCodeTtlMs / 1000)),
    };

    if (isEmailDebugCodeEnabledForEmail(normalizedEmail)) {
      responsePayload.debugCode = code;
      responsePayload.debugProvider = 'mock';
    }

    res.status(201).json(responsePayload);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('BFF email send error:', message);
    res.status(502).json({ error: 'Failed to send email code', code: 'AUTH_EMAIL_PROVIDER_FAILED' });
  }
});

router.post('/auth/email/login', async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, code } = req.body as { email?: string; code?: string };
    const normalizedEmail = normalizeEmailAddress(email);
    const emailCode = normalizeEmailCode(code);
    const now = new Date();

    if (!normalizedEmail || !emailCode) {
      res.status(400).json({ error: 'email and code are required', code: 'AUTH_EMAIL_LOGIN_REQUIRED' });
      return;
    }

    const emailState = await timeAsync(
      'auth.email_login',
      'prisma.authEmailAuthState.findUnique',
      () => prisma.authEmailAuthState.findUnique({
        where: { email: normalizedEmail },
        select: { blockedUntil: true },
      }),
      { email: maskEmailAddress(normalizedEmail) }
    );

    if (emailState?.blockedUntil && emailState.blockedUntil.getTime() > now.getTime()) {
      res.status(429).json({
        error: 'Email temporarily blocked due to too many failed attempts',
        code: 'AUTH_EMAIL_VERIFY_BLOCKED',
        retryAfterSeconds: Math.ceil((emailState.blockedUntil.getTime() - now.getTime()) / 1000),
      });
      return;
    }

    const latestCode = await timeAsync(
      'auth.email_login',
      'prisma.authEmailCode.findFirst',
      () => prisma.authEmailCode.findFirst({
        where: {
          email: normalizedEmail,
          scene: 'login',
          consumedAt: null,
        },
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          codeHash: true,
          expiresAt: true,
        },
      }),
      { email: maskEmailAddress(normalizedEmail) }
    );

    if (!latestCode || latestCode.expiresAt.getTime() <= now.getTime() || !isTokenHashMatch(emailCode, latestCode.codeHash)) {
      const state = await registerEmailVerifyFailure(normalizedEmail, now);
      console.warn('[auth:email] login verify failed', {
        email: maskEmailAddress(normalizedEmail),
        blockedUntil: state.blockedUntil ? state.blockedUntil.toISOString() : null,
      });
      res.status(401).json({
        error: 'Invalid or expired email code',
        code: 'AUTH_EMAIL_CODE_INVALID_OR_EXPIRED',
        blockedUntil: state.blockedUntil ? state.blockedUntil.toISOString() : null,
      });
      return;
    }

    const user = await timeAsync(
      'auth.email_login',
      'prisma.user.findFirst',
      () => prisma.user.findFirst({
        where: { email: normalizedEmail, isActive: true },
        select: {
          id: true,
          username: true,
          displayName: true,
          avatarUrl: true,
          email: true,
          role: true,
          regionCode: true,
          birthYear: true,
          ageBand: true,
          guardianContactEmail: true,
        },
      }),
      { email: maskEmailAddress(normalizedEmail) }
    );

    if (!user) {
      await registerEmailVerifyFailure(normalizedEmail, now);
      res.status(404).json({ error: 'Email is not registered', code: 'AUTH_EMAIL_NOT_REGISTERED' });
      return;
    }

    await timeAsync(
      'auth.email_login',
      'prisma.authEmailCode.update',
      () => prisma.authEmailCode.update({
        where: { id: latestCode.id },
        data: { consumedAt: now },
        select: { id: true },
      }),
      { email: maskEmailAddress(normalizedEmail) }
    );
    await timeAsync(
      'auth.email_login',
      'clearEmailVerifyFailures',
      () => clearEmailVerifyFailures(normalizedEmail),
      { email: maskEmailAddress(normalizedEmail) }
    );

    if (await timeAsync(
      'auth.email_login',
      'accountEnforcement.assertAllowed',
      () => denyForEnforcement(user.id, 'login', res),
      { userId: user.id }
    )) {
      writeAuthAuditLog(req, {
        action: 'auth.email_login',
        outcome: 'blocked',
        userId: user.id,
        identifier: normalizedEmail,
        errorCode: 'AUTH_ACCOUNT_ENFORCEMENT_BLOCKED',
      });
      return;
    }

    await timeAsync(
      'auth.email_login',
      'prisma.user.updateLastLoginAt',
      () => prisma.user.update({
        where: { id: user.id },
        data: { lastLoginAt: now },
        select: { id: true },
      }),
      { userId: user.id }
    );

    scheduleTencentIMUserSyncBestEffort(user.id, 'bff-auth-email-login');
    writeAuthAuditLog(req, {
      action: 'auth.email_login',
      outcome: 'success',
      userId: user.id,
      identifier: normalizedEmail,
    });
    await timeAsync(
      'auth.email_login',
      'issueAuthSuccessResponse',
      () => issueAuthSuccessResponse(req, res, user),
      { userId: user.id }
    );
  } catch (error) {
    console.error('BFF email login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/auth/email/register', async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, code, displayName, birthYear, regionCode, guardianContactEmail } = req.body as {
      email?: string;
      code?: string;
      displayName?: string;
      birthYear?: number | string;
      regionCode?: string;
      guardianContactEmail?: string;
    };

    const normalizedEmail = normalizeEmailAddress(email);
    const emailCode = normalizeEmailCode(code);
    const normalizedDisplayName = normalizeDisplayName(displayName);
    const normalizedDisplayNameKey = normalizeDisplayNameForUniqueness(normalizedDisplayName);
    const complianceRegion = regionalCompliance.resolveRegion(regionCode);
    const compliancePolicy = regionalCompliance.policyFor(complianceRegion);
    const normalizedBirthYear =
      typeof birthYear === 'number'
        ? birthYear
        : Number.parseInt(String(birthYear || ''), 10);
    const hasBirthYear = Number.isInteger(normalizedBirthYear);
    const now = new Date();

    if (!normalizedEmail || !emailCode || !normalizedDisplayName) {
      res.status(400).json({ error: 'email, code, and displayName are required', code: 'AUTH_EMAIL_REGISTER_REQUIRED' });
      return;
    }

    if (normalizedDisplayName.length < 2 || normalizedDisplayName.length > 24) {
      res.status(400).json({ error: '昵称需要 2-24 个字符', code: 'AUTH_DISPLAY_NAME_INVALID' });
      return;
    }

    if (compliancePolicy.ageDeclarationRequired && !hasBirthYear) {
      res.status(400).json({ error: 'Birth year is required for this region', code: 'AUTH_BIRTH_YEAR_REQUIRED' });
      return;
    }

    if (hasBirthYear) {
      const currentYear = new Date().getUTCFullYear();
      if (normalizedBirthYear < 1900 || normalizedBirthYear > currentYear) {
        res.status(400).json({ error: 'Birth year is invalid', code: 'AUTH_BIRTH_YEAR_INVALID' });
        return;
      }
      if (regionalCompliance.ageBandForBirthYear(normalizedBirthYear) === 'under_13') {
        res.status(403).json({
          error: 'You must meet the minimum age requirement to create an account',
          code: 'AUTH_MINIMUM_AGE_NOT_MET',
        });
        return;
      }
    }

    const emailState = await prisma.authEmailAuthState.findUnique({
      where: { email: normalizedEmail },
      select: { blockedUntil: true },
    });

    if (emailState?.blockedUntil && emailState.blockedUntil.getTime() > now.getTime()) {
      res.status(429).json({
        error: 'Email temporarily blocked due to too many failed attempts',
        code: 'AUTH_EMAIL_VERIFY_BLOCKED',
        retryAfterSeconds: Math.ceil((emailState.blockedUntil.getTime() - now.getTime()) / 1000),
      });
      return;
    }

    const [existingUser, latestCode] = await Promise.all([
      prisma.user.findFirst({
        where: {
          OR: [
            { email: normalizedEmail },
            { displayNameNormalized: normalizedDisplayNameKey },
          ],
        },
        select: { id: true, email: true, displayNameNormalized: true },
      }),
      prisma.authEmailCode.findFirst({
        where: {
          email: normalizedEmail,
          scene: 'register',
          consumedAt: null,
        },
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          codeHash: true,
          expiresAt: true,
        },
      }),
    ]);

    if (existingUser) {
      res.status(409).json({
        error: existingUser.displayNameNormalized === normalizedDisplayNameKey ? '昵称已被使用' : 'Email is already registered',
        code: existingUser.displayNameNormalized === normalizedDisplayNameKey ? 'AUTH_DISPLAY_NAME_TAKEN' : 'AUTH_EMAIL_ALREADY_REGISTERED',
      });
      return;
    }

    if (!latestCode || latestCode.expiresAt.getTime() <= now.getTime() || !isTokenHashMatch(emailCode, latestCode.codeHash)) {
      const state = await registerEmailVerifyFailure(normalizedEmail, now);
      console.warn('[auth:email] register verify failed', {
        email: maskEmailAddress(normalizedEmail),
        blockedUntil: state.blockedUntil ? state.blockedUntil.toISOString() : null,
      });
      res.status(401).json({
        error: 'Invalid or expired email code',
        code: 'AUTH_EMAIL_CODE_INVALID_OR_EXPIRED',
        blockedUntil: state.blockedUntil ? state.blockedUntil.toISOString() : null,
      });
      return;
    }

    const internalUsername = await createInternalUsername(normalizedEmail.split('@')[0] || normalizedDisplayNameKey);
    const user = await prisma.$transaction(async (tx) => {
      await tx.authEmailCode.update({
        where: { id: latestCode.id },
        data: { consumedAt: now },
        select: { id: true },
      });

      return tx.user.create({
        data: {
          username: internalUsername,
          email: normalizedEmail,
          passwordHash: await hashPassword(generateRefreshToken()),
          displayName: normalizedDisplayName,
          displayNameNormalized: normalizedDisplayNameKey,
          displayNameStatus: 'pending',
          isActive: true,
          regionCode: complianceRegion,
          birthYear: hasBirthYear ? normalizedBirthYear : null,
          ageBand: hasBirthYear ? regionalCompliance.ageBandForBirthYear(normalizedBirthYear) : 'unknown',
          guardianContactEmail: String(guardianContactEmail || '').trim() || null,
          ageDeclaredAt: hasBirthYear ? now : null,
        },
        select: {
          id: true,
          username: true,
          email: true,
          displayName: true,
          avatarUrl: true,
          role: true,
          regionCode: true,
          birthYear: true,
          ageBand: true,
          guardianContactEmail: true,
        },
      });
    });

    await clearEmailVerifyFailures(normalizedEmail);
    await createProfileModerationJob(
      user.id,
      'display_name',
      normalizedDisplayName,
      normalizedDisplayNameKey
    );
    await syncTencentIMUserBestEffort(user.id, 'bff-auth-email-register');
    writeAuthAuditLog(req, {
      action: 'auth.email_register',
      outcome: 'success',
      userId: user.id,
      identifier: normalizedEmail,
    });
    res.status(201);
    await issueAuthSuccessResponse(req, res, user);
  } catch (error) {
    console.error('BFF email register error:', error);
    writeAuthAuditLog(req, {
      action: 'auth.email_register',
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
      res.status(400).json({ error: 'Invalid phone number', code: 'AUTH_SMS_PHONE_INVALID' });
      return;
    }

    if (sceneKey !== 'login') {
      res.status(400).json({ error: 'Unsupported sms scene', code: 'AUTH_SMS_SCENE_UNSUPPORTED' });
      return;
    }

    recordSmsMetric('attempted');

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
      recordSmsMetric('rate_limited', 'cooldown');
      res.status(429).json({
        error: 'SMS request too frequent',
        code: 'AUTH_SMS_SEND_COOLDOWN',
        retryAfterSeconds: Math.ceil(retryAfterMs / 1000),
      });
      return;
    }

    if (sentByPhoneInLastHour >= authSmsPhoneHourlyLimit) {
      recordSmsMetric('rate_limited', 'phone_hourly_limit');
      res.status(429).json({
        error: 'SMS phone hourly limit exceeded',
        code: 'AUTH_SMS_PHONE_HOURLY_LIMIT',
        retryAfterSeconds: 60 * 60,
      });
      return;
    }

    if (sentByIpInLastHour >= authSmsIpHourlyLimit) {
      recordSmsMetric('rate_limited', 'ip_hourly_limit');
      res.status(429).json({
        error: 'SMS ip hourly limit exceeded',
        code: 'AUTH_SMS_IP_HOURLY_LIMIT',
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
    recordSmsMetric('sent');

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
    recordSmsMetric('failed', 'provider_error');
    console.error('BFF sms send error:', message);
    res.status(502).json({ error: 'Failed to send sms code', code: 'AUTH_SMS_PROVIDER_FAILED' });
  }
});

router.post('/auth/sms/login', async (req: Request, res: Response): Promise<void> => {
  try {
    const { phone, code, birthYear, regionCode, guardianContactEmail } = req.body as {
      phone?: string;
      code?: string;
      birthYear?: number | string;
      regionCode?: string;
      guardianContactEmail?: string;
    };
    const phoneNumber = normalizePhoneNumber(phone);
    const smsCode = normalizeSmsCode(code);
    const now = new Date();

    if (!phoneNumber || !smsCode) {
      res.status(400).json({ error: 'phone and code are required', code: 'AUTH_SMS_LOGIN_REQUIRED' });
      return;
    }

    const phoneState = await prisma.authPhoneAuthState.findUnique({
      where: { phoneNumber },
      select: { blockedUntil: true },
    });

    if (phoneState?.blockedUntil && phoneState.blockedUntil.getTime() > now.getTime()) {
      recordSmsMetric('verify_blocked', 'too_many_verify_failures');
      res.status(429).json({
        error: 'Phone temporarily blocked due to too many failed attempts',
        code: 'AUTH_SMS_VERIFY_BLOCKED',
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
      recordSmsMetric('verify_failed', blockedUntil ? 'too_many_verify_failures' : 'invalid_or_expired_code');
      console.warn('[auth:sms] verify failed', {
        phone: maskPhoneNumber(phoneNumber),
        reason: 'invalid_or_expired_code',
        blockedUntil: blockedUntil ? blockedUntil.toISOString() : null,
      });
      res.status(401).json({
        error: 'Invalid or expired sms code',
        code: 'AUTH_SMS_CODE_INVALID_OR_EXPIRED',
        blockedUntil: blockedUntil ? blockedUntil.toISOString() : null,
      });
      return;
    }

    if (!isTokenHashMatch(smsCode, latestCode.codeHash)) {
      const state = await registerSmsVerifyFailure(phoneNumber, now);
      const blockedUntil = state.blockedUntil;
      recordSmsMetric('verify_failed', blockedUntil ? 'too_many_verify_failures' : 'invalid_or_expired_code');
      console.warn('[auth:sms] verify failed', {
        phone: maskPhoneNumber(phoneNumber),
        reason: 'code_mismatch',
        blockedUntil: blockedUntil ? blockedUntil.toISOString() : null,
      });
      res.status(401).json({
        error: 'Invalid or expired sms code',
        code: 'AUTH_SMS_CODE_INVALID_OR_EXPIRED',
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

    const userResult = await resolveOrCreatePhoneAuthUser({
      phoneNumber,
      birthYear,
      regionCode,
      guardianContactEmail,
    });
    if (isPhoneAuthUserError(userResult)) {
      res.status(userResult.errorStatus).json(userResult.errorBody);
      return;
    }
    const user = userResult;

    if (await denyForEnforcement(user.id, 'login', res)) {
      writeAuthAuditLog(req, {
        action: 'auth.sms_login',
        outcome: 'blocked',
        userId: user.id,
        identifier: phoneNumber,
        errorCode: 'AUTH_ACCOUNT_ENFORCEMENT_BLOCKED',
      });
      return;
    }

    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: now },
      select: { id: true },
    });

    scheduleTencentIMUserSyncBestEffort(user.id, 'bff-auth-sms-login');
    await issueAuthSuccessResponse(req, res, user);
  } catch (error) {
    console.error('BFF sms login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/auth/firebase-phone/login', async (req: Request, res: Response): Promise<void> => {
  try {
    const { idToken, birthYear, regionCode, guardianContactEmail, displayName } = req.body as {
      idToken?: string;
      birthYear?: number | string;
      regionCode?: string;
      guardianContactEmail?: string;
      displayName?: string;
    };
    const token = String(idToken || '').trim();
    if (!token) {
      res.status(400).json({ error: 'Firebase id token is required', code: 'AUTH_FIREBASE_ID_TOKEN_REQUIRED' });
      return;
    }

    let verified: { uid: string; phoneNumber: string };
    try {
      verified = await verifyFirebasePhoneIdToken(token);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.warn('[auth:firebase-phone] verify failed', { reason: message });
      res.status(401).json({ error: 'Firebase phone token is invalid', code: 'AUTH_FIREBASE_PHONE_TOKEN_INVALID' });
      return;
    }

    const phoneNumber = normalizePhoneNumber(verified.phoneNumber);
    if (!phoneNumber) {
      res.status(401).json({ error: 'Firebase phone number is invalid', code: 'AUTH_FIREBASE_PHONE_INVALID' });
      return;
    }

    const userResult = await resolveOrCreatePhoneAuthUser({
      phoneNumber,
      birthYear,
      regionCode,
      guardianContactEmail,
      displayName,
    });
    if (isPhoneAuthUserError(userResult)) {
      res.status(userResult.errorStatus).json(userResult.errorBody);
      return;
    }
    const user = userResult;

    if (await denyForEnforcement(user.id, 'login', res)) {
      writeAuthAuditLog(req, {
        action: 'auth.firebase-phone-login',
        outcome: 'blocked',
        userId: user.id,
        identifier: maskPhoneNumber(phoneNumber),
        errorCode: 'AUTH_ACCOUNT_ENFORCEMENT_BLOCKED',
      });
      return;
    }

    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
      select: { id: true },
    });

    await clearSmsVerifyFailures(phoneNumber);
    scheduleTencentIMUserSyncBestEffort(user.id, 'bff-auth-firebase-phone-login');
    writeAuthAuditLog(req, {
      action: 'auth.firebase-phone-login',
      outcome: 'success',
      userId: user.id,
      identifier: maskPhoneNumber(phoneNumber),
      detail: { firebaseUid: verified.uid },
    });
    await issueAuthSuccessResponse(req, res, user);
  } catch (error) {
    console.error('BFF firebase phone login error:', error);
    writeAuthAuditLog(req, {
      action: 'auth.firebase-phone-login',
      outcome: 'failed',
      errorCode: 'AUTH_INTERNAL_ERROR',
    });
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

    const sessionExpiryFailure =
      !current
        ? 'AUTH_REFRESH_TOKEN_INVALID_OR_EXPIRED'
        : current.revokedAt
          ? 'AUTH_SESSION_REVOKED'
          : current.expiresAt.getTime() <= now.getTime()
            ? 'AUTH_REFRESH_TOKEN_INVALID_OR_EXPIRED'
            : current.absoluteExpiresAt && current.absoluteExpiresAt.getTime() <= now.getTime()
              ? 'AUTH_SESSION_ABSOLUTE_EXPIRED'
              : current.idleExpiresAt && current.idleExpiresAt.getTime() <= now.getTime()
                ? 'AUTH_SESSION_IDLE_EXPIRED'
                : !current.user.isActive
                  ? 'AUTH_ACCOUNT_INACTIVE'
                  : null;

    if (sessionExpiryFailure) {
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
        errorCode: sessionExpiryFailure,
      });
      res.status(401).json({
        error: sessionExpiryFailure === 'AUTH_ACCOUNT_INACTIVE'
          ? 'Account is no longer active'
          : 'Refresh token invalid or expired',
        code: sessionExpiryFailure,
      });
      return;
    }

    if (!current) {
      clearRefreshCookie(res);
      res.status(401).json({ error: 'Refresh token invalid or expired', code: 'AUTH_REFRESH_TOKEN_INVALID_OR_EXPIRED' });
      return;
    }

    const activeRefreshSession = current;

    if (await denyForEnforcement(activeRefreshSession.userId, 'login', res)) {
      clearRefreshCookie(res);
      await prisma.authRefreshToken.update({
        where: { id: activeRefreshSession.id },
        data: {
          revokedAt: now,
          lastUsedAt: now,
        },
        select: { id: true },
      });
      writeAuthAuditLog(req, {
        action: 'auth.refresh',
        outcome: 'blocked',
        userId: activeRefreshSession.userId,
        errorCode: 'AUTH_ACCOUNT_ENFORCEMENT_BLOCKED',
      });
      return;
    }

    const nextRefreshToken = generateRefreshToken();
    const nextRefreshHash = hashToken(nextRefreshToken);
    const nextExpiry = buildRefreshSessionExpiry(
      activeRefreshSession.clientType,
      now,
      activeRefreshSession.absoluteExpiresAt
    );
    const clientIp = getClientIp(req);
    const userAgent = req.headers['user-agent'] || null;

    const createdNextToken = await prisma.$transaction(async (tx) => {
      const next = await tx.authRefreshToken.create({
        data: {
          userId: activeRefreshSession.userId,
          tokenHash: nextRefreshHash,
          userAgent,
          ipAddress: clientIp,
          clientType: activeRefreshSession.clientType,
          deviceId: activeRefreshSession.deviceId,
          deviceName: activeRefreshSession.deviceName,
          platform: activeRefreshSession.platform,
          appVersion: activeRefreshSession.appVersion,
          expiresAt: nextExpiry.expiresAt,
          idleExpiresAt: nextExpiry.idleExpiresAt,
          absoluteExpiresAt: nextExpiry.absoluteExpiresAt,
          riskLevel: activeRefreshSession.riskLevel,
        },
        select: { id: true },
      });

      await tx.authRefreshToken.update({
        where: { id: activeRefreshSession.id },
        data: {
          revokedAt: now,
          lastUsedAt: now,
          replacedByTokenId: next.id,
        },
        select: { id: true },
      });

      return next;
    });

    setRefreshCookie(res, nextRefreshToken, nextExpiry.cookieMaxAgeMs);
    const accessToken = createAccessTokenForUser(activeRefreshSession.user);
    const accountStatus = await accountEnforcementService.getAccountStatus(activeRefreshSession.userId);
    writeAuthAuditLog(req, {
      action: 'auth.refresh',
      outcome: 'success',
      userId: activeRefreshSession.userId,
    });
    res.json({
      token: accessToken,
      accessToken,
      accessTokenExpiresIn: ACCESS_TOKEN_TTL_SECONDS,
      refreshToken: nextRefreshToken,
      refreshTokenId: createdNextToken.id,
      accountStatus,
      user: toUserSummary(
        {
          id: activeRefreshSession.user.id,
          username: activeRefreshSession.user.username,
          displayName: activeRefreshSession.user.displayName,
          avatarUrl: activeRefreshSession.user.avatarUrl,
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

router.post('/auth/reauth', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const { password, scope } = req.body as { password?: string; scope?: string };
    const normalizedScope = String(scope || 'admin.high_risk').trim().slice(0, 80) || 'admin.high_risk';
    if (!password) {
      res.status(400).json({ error: 'Password is required', code: 'AUTH_REAUTH_PASSWORD_REQUIRED' });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true, passwordHash: true },
    });
    if (!user) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const valid = await comparePassword(password, user.passwordHash);
    if (!valid) {
      writeAuthAuditLog(req, {
        action: 'auth.reauth',
        outcome: 'failed',
        userId,
        errorCode: 'AUTH_REAUTH_INVALID_CREDENTIALS',
        detail: { scope: normalizedScope },
      });
      res.status(401).json({ error: 'Invalid credentials', code: 'AUTH_REAUTH_INVALID_CREDENTIALS' });
      return;
    }

    const reauthProof = generateReauthProof({
      userId,
      role: user.role,
      scope: normalizedScope,
    });
    writeAuthAuditLog(req, {
      action: 'auth.reauth',
      outcome: 'success',
      userId,
      detail: { scope: normalizedScope },
    });
    res.json({ success: true, reauthProof, expiresInSeconds: 10 * 60, scope: normalizedScope });
  } catch (error) {
    console.error('BFF reauth error:', error);
    writeAuthAuditLog(req, {
      action: 'auth.reauth',
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

    const revokedCount = await revokeRefreshTokensForUser(prisma, userId, new Date());

    clearRefreshCookie(res);
    writeAuthAuditLog(req, {
      action: 'auth.logout-all',
      outcome: 'success',
      userId,
      detail: { revokedCount },
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

router.post('/auth/password', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) {
      writeAuthAuditLog(req, {
        action: 'auth.password-change',
        outcome: 'failed',
        errorCode: 'AUTH_UNAUTHORIZED',
      });
      return;
    }

    const { currentPassword, newPassword } = req.body as { currentPassword?: string; newPassword?: string };
    if (!currentPassword || !newPassword) {
      res.status(400).json({ error: 'Current password and new password are required', code: 'AUTH_PASSWORD_CHANGE_REQUIRED' });
      return;
    }
    if (newPassword.length < 6) {
      res.status(400).json({ error: 'Password must be at least 6 characters', code: 'AUTH_PASSWORD_TOO_SHORT' });
      return;
    }

    const rawRefreshToken = extractRefreshToken(req);
    if (!rawRefreshToken) {
      res.status(401).json({ error: 'Current session is required', code: 'AUTH_REFRESH_TOKEN_MISSING' });
      return;
    }
    const currentTokenHash = hashToken(rawRefreshToken);

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, passwordHash: true, isActive: true },
    });
    if (!user || !user.isActive) {
      res.status(401).json({ error: 'Account is no longer active', code: 'AUTH_ACCOUNT_INACTIVE' });
      return;
    }

    const currentSession = await prisma.authRefreshToken.findFirst({
      where: {
        userId,
        tokenHash: currentTokenHash,
        revokedAt: null,
      },
      select: { id: true },
    });
    if (!currentSession) {
      res.status(401).json({ error: 'Current session is invalid or expired', code: 'AUTH_SESSION_REVOKED' });
      return;
    }

    const valid = await comparePassword(currentPassword, user.passwordHash);
    if (!valid) {
      writeAuthAuditLog(req, {
        action: 'auth.password-change',
        outcome: 'failed',
        userId,
        errorCode: 'AUTH_PASSWORD_INVALID_CURRENT',
      });
      res.status(401).json({ error: 'Current password is invalid', code: 'AUTH_PASSWORD_INVALID_CURRENT' });
      return;
    }

    const now = new Date();
    const nextPasswordHash = await hashPassword(newPassword);
    const revokedCount = await prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: { passwordHash: nextPasswordHash },
        select: { id: true },
      });
      return revokeRefreshTokensForUser(tx, userId, now, { exceptTokenHash: currentTokenHash });
    });

    writeAuthAuditLog(req, {
      action: 'auth.password-change',
      outcome: 'success',
      userId,
      detail: { revokedOtherSessions: revokedCount },
    });
    res.json({ success: true, revokedOtherSessions: revokedCount });
  } catch (error) {
    console.error('BFF password change error:', error);
    writeAuthAuditLog(req, {
      action: 'auth.password-change',
      outcome: 'failed',
      errorCode: 'AUTH_INTERNAL_ERROR',
    });
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/auth/sessions', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const rawRefreshToken = extractRefreshToken(req);
    const currentTokenHash = rawRefreshToken ? hashToken(rawRefreshToken) : null;
    const sessions = await prisma.authRefreshToken.findMany({
      where: { userId },
      orderBy: [{ revokedAt: 'asc' }, { lastUsedAt: 'desc' }, { createdAt: 'desc' }],
      take: 100,
      select: {
        id: true,
        tokenHash: true,
        clientType: true,
        deviceId: true,
        deviceName: true,
        platform: true,
        appVersion: true,
        userAgent: true,
        ipAddress: true,
        expiresAt: true,
        idleExpiresAt: true,
        absoluteExpiresAt: true,
        lastUsedAt: true,
        revokedAt: true,
        createdAt: true,
      },
    });

    res.json({
      items: sessions.map((session) => ({
        id: session.id,
        clientType: session.clientType || 'unknown',
        deviceId: session.deviceId,
        deviceName: session.deviceName,
        platform: session.platform,
        appVersion: session.appVersion,
        userAgent: session.userAgent,
        ipAddressMasked: session.ipAddress ? maskIdentifier(session.ipAddress) : null,
        createdAt: session.createdAt.toISOString(),
        lastUsedAt: session.lastUsedAt ? session.lastUsedAt.toISOString() : null,
        expiresAt: session.expiresAt.toISOString(),
        idleExpiresAt: session.idleExpiresAt ? session.idleExpiresAt.toISOString() : null,
        absoluteExpiresAt: session.absoluteExpiresAt ? session.absoluteExpiresAt.toISOString() : null,
        revokedAt: session.revokedAt ? session.revokedAt.toISOString() : null,
        isCurrent: Boolean(currentTokenHash && session.tokenHash === currentTokenHash),
      })),
    });
  } catch (error) {
    console.error('BFF auth sessions list error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/auth/sessions/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const sessionId = String(req.params.id || '').trim();
    if (!sessionId) {
      res.status(400).json({ error: 'Session id is required', code: 'AUTH_SESSION_ID_REQUIRED' });
      return;
    }

    const now = new Date();
    const rawRefreshToken = extractRefreshToken(req);
    const currentTokenHash = rawRefreshToken ? hashToken(rawRefreshToken) : null;
    const session = await prisma.authRefreshToken.findFirst({
      where: {
        id: sessionId,
        userId,
      },
      select: {
        id: true,
        tokenHash: true,
        revokedAt: true,
      },
    });

    if (!session) {
      res.status(404).json({ error: 'Session not found', code: 'AUTH_SESSION_NOT_FOUND' });
      return;
    }

    if (!session.revokedAt) {
      await prisma.authRefreshToken.update({
        where: { id: session.id },
        data: {
          revokedAt: now,
          lastUsedAt: now,
        },
        select: { id: true },
      });
    }

    const revokedCurrent = Boolean(currentTokenHash && session.tokenHash === currentTokenHash);
    if (revokedCurrent) {
      clearRefreshCookie(res);
    }

    writeAuthAuditLog(req, {
      action: 'auth.session.revoke',
      outcome: 'success',
      userId,
      detail: {
        sessionId: session.id,
        revokedCurrent,
      },
    });
    res.json({ success: true, revokedCurrent });
  } catch (error) {
    console.error('BFF auth session revoke error:', error);
    writeAuthAuditLog(req, {
      action: 'auth.session.revoke',
      outcome: 'failed',
      errorCode: 'AUTH_INTERNAL_ERROR',
    });
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/account/status', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const status = await accountEnforcementService.getAccountStatus(userId);
    res.json({ success: true, status });
  } catch (error) {
    console.error('BFF account status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/account/enforcements', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const items = await accountEnforcementService.listEnforcements({
      userId,
      limit: 100,
    });
    res.json({ success: true, items });
  } catch (error) {
    console.error('BFF account enforcements error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/account/enforcements/:id/appeal', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = req.body as {
      appealReason?: string;
      reason?: string;
      attachments?: unknown;
      contactEmail?: string;
    };

    const appeal = await accountEnforcementService.createAppeal({
      enforcementId: String(req.params.id || ''),
      userId,
      appealReason: String(body.appealReason || body.reason || ''),
      attachments: body.attachments as never,
      contactEmail: body.contactEmail || null,
    });

    res.status(201).json({ success: true, appeal });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = message === 'enforcement_not_found' ? 404 : 400;
    res.status(status).json({ error: message || 'Failed to create appeal' });
  }
});

router.get('/account/appeals', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const items = await accountEnforcementService.listAppeals({
      userId,
      limit: 100,
    });
    res.json({ success: true, items });
  } catch (error) {
    console.error('BFF account appeals error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/auth/account', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  const authReq = req as BFFAuthRequest;
  try {
    const userId = requireAuth(authReq, res, { allowInactiveAccount: true });
    if (!userId) {
      writeAuthAuditLog(req, {
        action: 'auth.account-delete',
        outcome: 'failed',
        errorCode: 'AUTH_UNAUTHORIZED',
      });
      return;
    }

    const now = new Date();
    const anonymizedSuffix = userId.replace(/-/g, '').slice(0, 12);
    let deletionRequestId: string | null = null;
    await prisma.$transaction(async (tx) => {
      const userSnapshot = await tx.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          email: true,
          phoneNumber: true,
          avatarUrl: true,
          profileShareQrCodeUrl: true,
          posts: { select: { images: true } },
          eventLiveComments: { select: { imageUrls: true } },
          squadMessages: { select: { imageUrl: true } },
          uploadedPhotos: { select: { url: true } },
        },
      });

      if (!userSnapshot) {
        throw new Error('account_delete_user_not_found');
      }

      const deletionRequest = await accountDeletionService.createOrGetRequest(tx, {
        user: userSnapshot,
        requestedBy: 'user',
        requestSource: 'ios',
      });
      deletionRequestId = deletionRequest.id;

      await revokeRefreshTokensForUser(tx, userId, now);

      await tx.devicePushToken.updateMany({
        where: { userId, isActive: true },
        data: { isActive: false, lastSeenAt: now },
      });

      await tx.user.update({
        where: { id: userId },
        data: {
          username: `deleted-${anonymizedSuffix}`,
          isActive: false,
          email: `deleted-${anonymizedSuffix}@deleted.raver.local`,
          phoneNumber: null,
          passwordHash: `deleted:${crypto.randomBytes(32).toString('hex')}`,
          displayName: 'Deleted User',
          displayNameNormalized: `deleted-${anonymizedSuffix}`,
          displayNameStatus: 'approved',
          displayNameReviewNote: null,
          avatarUrl: null,
          avatarStatus: 'none',
          avatarReviewNote: null,
          bio: null,
          location: null,
          favoriteDjIds: [],
          favoriteGenres: [],
          isVerified: false,
          profileShareCode: null,
          profileShareQrCodeUrl: null,
        },
        select: { id: true },
      });
    });

    clearRefreshCookie(res);
    writeAuthAuditLog(req, {
      action: 'auth.account-delete',
      outcome: 'success',
      userId,
      detail: { strategy: 'soft_delete_and_anonymize', deletionRequestId },
    });
    res.json({ success: true, status: 'deleted', deletionRequestId });
  } catch (error) {
    console.error('BFF account delete error:', error);
    clearRefreshCookie(res);
    writeAuthAuditLog(req, {
      action: 'auth.account-delete',
      outcome: 'failed',
      userId: authReq.user?.userId ?? null,
      errorCode: 'AUTH_INTERNAL_ERROR',
    });
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/reports', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = (req.body ?? {}) as Record<string, unknown>;
    const targetType = normalizeComplianceText(body.targetType, 64);
    const targetId = normalizeComplianceText(body.targetId, 128);
    const reason = normalizeComplianceText(body.reason, 64);
    const detail = normalizeComplianceText(body.detail, 2000);
    const source = normalizeComplianceText(body.source, 64) || 'in_app';
    const attachments = normalizeReportAttachments(body.attachments);

    if (!targetType || !targetId || !reason) {
      res.status(400).json({ error: 'targetType, targetId and reason are required' });
      return;
    }

    const targetUserId = await resolveReportTargetUserId(targetType, targetId);
    if (targetType === 'user' && targetId === userId) {
      res.status(400).json({ error: 'Cannot report yourself' });
      return;
    }

    const report = await prisma.contentReport.upsert({
      where: {
        reporterUserId_targetType_targetId: {
          reporterUserId: userId,
          targetType,
          targetId,
        },
      },
      create: {
        reporterUserId: userId,
        targetType,
        targetId,
        targetUserId,
        reason,
        detail,
        attachments,
        source,
        metadata: {
          ip: getClientIp(req),
          userAgent: req.headers['user-agent'] || null,
        } as Prisma.InputJsonValue,
      },
      update: {
        reason,
        detail,
        attachments,
        source,
        targetUserId,
        status: 'pending',
        metadata: {
          ip: getClientIp(req),
          userAgent: req.headers['user-agent'] || null,
          resubmittedAt: new Date().toISOString(),
        } as Prisma.InputJsonValue,
      },
      select: {
        id: true,
        targetType: true,
        targetId: true,
        reason: true,
        status: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    res.status(201).json(report);
  } catch (error) {
    console.error('BFF create report error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/reports', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const limit = Math.max(1, Math.min(Number(req.query.limit) || 50, 100));
    const reports = await prisma.contentReport.findMany({
      where: { reporterUserId: userId },
      orderBy: { updatedAt: 'desc' },
      take: limit,
      select: {
        id: true,
        targetType: true,
        targetId: true,
        targetUserId: true,
        reason: true,
        detail: true,
        source: true,
        status: true,
        resolutionNote: true,
        resolvedAt: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    const targetUserIds = Array.from(new Set(reports.map((item) => item.targetUserId).filter(Boolean))) as string[];
    const targetUsers = targetUserIds.length > 0
      ? await prisma.user.findMany({
          where: { id: { in: targetUserIds } },
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        })
      : [];
    const targetUserById = new Map(targetUsers.map((user) => [user.id, user]));

    res.json({
      items: reports.map((report) => ({
        ...report,
        targetUser: report.targetUserId ? toPublicUserSummary(targetUserById.get(report.targetUserId)) : null,
      })),
    });
  } catch (error) {
    console.error('BFF list reports error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/social/blocks', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const limit = Math.max(1, Math.min(Number(req.query.limit) || 100, 100));
    const blocks = await prisma.userBlock.findMany({
      where: { blockerUserId: userId },
      orderBy: { updatedAt: 'desc' },
      take: limit,
      select: {
        id: true,
        blockedUserId: true,
        reason: true,
        note: true,
        source: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    const blockedUserIds = blocks.map((item) => item.blockedUserId);
    const blockedUsers = blockedUserIds.length > 0
      ? await prisma.user.findMany({
          where: { id: { in: blockedUserIds } },
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        })
      : [];
    const userById = new Map(blockedUsers.map((user) => [user.id, user]));

    res.json({
      items: blocks.map((block) => ({
        id: block.id,
        reason: block.reason,
        note: block.note,
        source: block.source,
        createdAt: block.createdAt,
        updatedAt: block.updatedAt,
        user: toPublicUserSummary(userById.get(block.blockedUserId)) || {
          id: block.blockedUserId,
          username: 'unknown',
          displayName: 'Unknown User',
          avatarURL: null,
          avatarUrl: null,
          isFollowing: false,
        },
      })),
    });
  } catch (error) {
    console.error('BFF list blocked users error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/social/users/:id/block', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;
    const targetUserId = String(req.params.id || '').trim();
    if (!targetUserId || targetUserId === userId) {
      res.status(400).json({ error: 'Invalid target user' });
      return;
    }

    const block = await prisma.userBlock.findUnique({
      where: {
        blockerUserId_blockedUserId: {
          blockerUserId: userId,
          blockedUserId: targetUserId,
        },
      },
      select: { id: true, createdAt: true },
    });

    res.json({ isBlocked: Boolean(block), blockedAt: block?.createdAt ?? null });
  } catch (error) {
    console.error('BFF get user block error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/social/users/:id/block', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;
    const targetUserId = String(req.params.id || '').trim();
    if (!targetUserId || targetUserId === userId) {
      res.status(400).json({ error: 'Invalid target user' });
      return;
    }

    const target = await prisma.user.findFirst({
      where: { id: targetUserId, isActive: true },
      select: { id: true },
    });
    if (!target) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const body = (req.body ?? {}) as Record<string, unknown>;
    const reason = normalizeComplianceText(body.reason, 64);
    const note = normalizeComplianceText(body.note, 1000);
    const source = normalizeComplianceText(body.source, 64) || 'in_app';
    const block = await prisma.userBlock.upsert({
      where: {
        blockerUserId_blockedUserId: {
          blockerUserId: userId,
          blockedUserId: targetUserId,
        },
      },
      create: {
        blockerUserId: userId,
        blockedUserId: targetUserId,
        reason,
        note,
        source,
      },
      update: {
        reason,
        note,
        source,
      },
      select: { id: true, createdAt: true, updatedAt: true },
    });

    res.status(201).json({ isBlocked: true, block });
  } catch (error) {
    console.error('BFF block user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/social/users/:id/block', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;
    const targetUserId = String(req.params.id || '').trim();
    if (!targetUserId || targetUserId === userId) {
      res.status(400).json({ error: 'Invalid target user' });
      return;
    }

    await prisma.userBlock.deleteMany({
      where: {
        blockerUserId: userId,
        blockedUserId: targetUserId,
      },
    });

    res.json({ success: true, isBlocked: false });
  } catch (error) {
    console.error('BFF unblock user error:', error);
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
    const eventID =
      typeof req.query.eventID === 'string'
        ? req.query.eventID.trim()
        : typeof req.query.eventId === 'string'
          ? req.query.eventId.trim()
          : '';

    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);
    const blockedRelationUserIds = await buildBlockedRelationUserIds(viewerId);
    const baseWhere = {
      visibility: 'public' as const,
      squadId: null,
      ...(blockedRelationUserIds.size > 0
        ? {
            userId: { notIn: Array.from(blockedRelationUserIds) },
          }
        : {}),
      ...(eventID
        ? {
            content: { not: { contains: NEWS_MARKER } },
            OR: [
              { eventId: eventID },
              { boundEventIds: { has: eventID } },
            ],
          }
        : {}),
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

    if (eventID) {
      sourcePosts = await prisma.post.findMany({
        where: baseWhere,
        include: postInclude,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
      });

      const hasMore = sourcePosts.length > limit;
      const pagePosts = hasMore ? sourcePosts.slice(0, limit) : sourcePosts;
      const authorIds = Array.from(new Set(pagePosts.map((post) => post.user.id)));
      const postIds = pagePosts.map((post) => post.id);
      const [followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds] = await Promise.all([
        buildFollowingMap(viewerId, authorIds),
        buildLikedPostMap(viewerId, postIds),
        buildRepostedPostMap(viewerId, postIds),
        buildSavedPostMap(viewerId, postIds),
        buildHiddenPostMap(viewerId, postIds),
      ]);

      res.json({
        mode: requestedMode,
        effectiveMode,
        eventID,
        rankingExperiment: null,
        posts: pagePosts.map((post) =>
          mapPost(post, followingSet, likedPostIds, repostedPostIds, savedPostIds, hiddenPostIds)
        ),
        nextCursor: hasMore ? pagePosts[pagePosts.length - 1]?.createdAt.toISOString() ?? null : null,
      });
      return;
    }

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
          .filter((id): id is string => Boolean(id && !blockedRelationUserIds.has(id)));
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
              .filter((id): id is string => Boolean(id && id !== viewerId && !blockedRelationUserIds.has(id)))
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
        .filter((id): id is string => Boolean(id && !blockedRelationUserIds.has(id)));

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
    const body = (req.body ?? {}) as Record<string, unknown>;
    await recordFeedEvent({
      ...body,
      viewerId,
      experimentBucketOverride: req.query.expBucket ?? req.query.experimentBucket,
    });

    res.status(201).json({ success: true });
  } catch (error) {
    if (error instanceof FeedEventValidationError) {
      res.status(error.status).json({ error: error.message });
      return;
    }
    console.error('BFF feed event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/:id/live-comments', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const viewerId = (req as BFFAuthRequest).user?.userId;
    const eventID = String(req.params.id || '').trim();
    const limit = normalizeLimit(req.query.limit, 50, 100);
    const cursorDate = parseCursorDate(req.query.cursor);
    const sort = String(req.query.sort || 'oldest').trim().toLowerCase();
    const blockedRelationUserIds = await buildBlockedRelationUserIds(viewerId);

    if (!eventID) {
      res.status(400).json({ error: 'Event id is required' });
      return;
    }

    const orderBy =
      sort === 'hot'
        ? [{ likeCount: 'desc' as const }, { createdAt: 'desc' as const }, { id: 'desc' as const }]
        : sort === 'newest'
          ? [{ createdAt: 'desc' as const }, { id: 'desc' as const }]
          : [{ createdAt: 'asc' as const }, { id: 'asc' as const }];
    const cursorDirection = sort === 'oldest' ? 'gt' : 'lt';

    const comments = await prisma.eventLiveComment.findMany({
      where: {
        eventId: eventID,
        ...(cursorDate
          ? {
              createdAt: {
                [cursorDirection]: cursorDate,
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
        replyToUser: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
      orderBy,
      take: limit + 1,
    });

    const visibleComments = comments.filter(
      (comment) =>
        !blockedRelationUserIds.has(comment.user.id) &&
        (!comment.replyToUser || !blockedRelationUserIds.has(comment.replyToUser.id))
    );
    const hasMore = visibleComments.length > limit;
    const pageComments = hasMore ? visibleComments.slice(0, limit) : visibleComments;
    const authorIds = Array.from(
      new Set(
        pageComments
          .flatMap((comment) => [comment.user.id, comment.replyToUser?.id ?? null])
          .filter((id): id is string => Boolean(id))
      )
    );
    const commentIds = pageComments.map((comment) => comment.id);
    const [followingSet, likedCommentIds] = await Promise.all([
      buildFollowingMap(viewerId, authorIds),
      buildLikedEventLiveCommentMap(viewerId, commentIds),
    ]);

    res.json({
      comments: pageComments.map((comment) => mapEventLiveComment(comment, followingSet, likedCommentIds)),
      nextCursor: hasMore ? pageComments[pageComments.length - 1]?.createdAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF event live comments error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events/:id/live-comments', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;
    if (await denyForEnforcement(userId, 'comment_create', res)) return;

    const eventID = String(req.params.id || '').trim();
    const body = (req.body ?? {}) as {
      content?: unknown;
      imageURLs?: unknown;
      imageUrls?: unknown;
      parentCommentID?: unknown;
      parentCommentId?: unknown;
      replyToCommentID?: unknown;
      replyToCommentId?: unknown;
    };
    const content = String(body.content || '').trim();
    const rawImageURLs = Array.isArray(body.imageURLs) ? body.imageURLs : Array.isArray(body.imageUrls) ? body.imageUrls : [];
    const imageUrls = rawImageURLs
      .map((value) => String(value || '').trim())
      .filter(Boolean)
      .slice(0, 3);
    const rawParentID =
      body.parentCommentID ??
      body.parentCommentId ??
      body.replyToCommentID ??
      body.replyToCommentId;
    const parentCommentID = typeof rawParentID === 'string' ? rawParentID.trim() : '';
    const normalizedParentCommentID = parentCommentID.length > 0 ? parentCommentID : null;
    const blockedRelationUserIds = await buildBlockedRelationUserIds(userId);

    if (!eventID) {
      res.status(400).json({ error: 'Event id is required' });
      return;
    }
    if (!content && imageUrls.length === 0) {
      res.status(400).json({ error: 'content or image is required' });
      return;
    }

    const eventExists = await prisma.event.findUnique({
      where: { id: eventID },
      select: { id: true },
    });
    if (!eventExists) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    const created = await prisma.$transaction(async (tx) => {
      let parentComment:
        | {
            id: string;
            eventId: string;
            userId: string;
            rootCommentId: string | null;
            depth: number;
          }
        | null = null;

      if (normalizedParentCommentID) {
        parentComment = await tx.eventLiveComment.findUnique({
          where: { id: normalizedParentCommentID },
          select: {
            id: true,
            eventId: true,
            userId: true,
            rootCommentId: true,
            depth: true,
          },
        });

        if (!parentComment || parentComment.eventId !== eventID) {
          throw new Error('Parent comment not found');
        }
        if (blockedRelationUserIds.has(parentComment.userId)) {
          throw new Error('Blocked relation');
        }
      }

      const depth = parentComment ? Math.min((parentComment.depth ?? 0) + 1, 1) : 0;
      const rootCommentId = parentComment ? parentComment.rootCommentId ?? parentComment.id : null;

      return tx.eventLiveComment.create({
        data: {
          eventId: eventID,
          userId,
          parentCommentId: parentComment?.id ?? null,
          rootCommentId,
          replyToUserId: parentComment?.userId ?? null,
          depth,
          content: content.slice(0, 500),
          imageUrls,
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
    });

    const followingSet = await buildFollowingMap(userId, [created.user.id, created.replyToUser?.id].filter((id): id is string => Boolean(id)));
    res.status(201).json(mapEventLiveComment(created, followingSet));
  } catch (error) {
    if (error instanceof Error && error.message === 'Blocked relation') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    if (error instanceof Error && error.message === 'Parent comment not found') {
      res.status(404).json({ error: 'Parent comment not found' });
      return;
    }
    console.error('BFF create event live comment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events/live-comments/:commentId/like', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const commentId = String(req.params.commentId || '').trim();
    const comment = await prisma.eventLiveComment.findUnique({
      where: { id: commentId },
      select: { id: true },
    });
    if (!comment) {
      res.status(404).json({ error: 'Comment not found' });
      return;
    }

    await prisma.$transaction(async (tx) => {
      const existing = await tx.eventLiveCommentLike.findUnique({
        where: {
          commentId_userId: {
            commentId,
            userId,
          },
        },
      });
      if (!existing) {
        await tx.eventLiveCommentLike.create({
          data: {
            commentId,
            userId,
          },
        });
        await tx.eventLiveComment.update({
          where: { id: commentId },
          data: { likeCount: { increment: 1 } },
        });
      }
    });

    const hydrated = await prisma.eventLiveComment.findUnique({
      where: { id: commentId },
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
    if (!hydrated) {
      res.status(404).json({ error: 'Comment not found' });
      return;
    }
    const followingSet = await buildFollowingMap(userId, [hydrated.user.id, hydrated.replyToUser?.id].filter((id): id is string => Boolean(id)));
    res.json(mapEventLiveComment(hydrated, followingSet, new Set([commentId])));
  } catch (error) {
    console.error('BFF like event live comment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/events/live-comments/:commentId/like', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const commentId = String(req.params.commentId || '').trim();
    await prisma.$transaction(async (tx) => {
      const existing = await tx.eventLiveCommentLike.findUnique({
        where: {
          commentId_userId: {
            commentId,
            userId,
          },
        },
      });
      if (existing) {
        await tx.eventLiveCommentLike.delete({ where: { id: existing.id } });
        await tx.eventLiveComment.updateMany({
          where: {
            id: commentId,
            likeCount: { gt: 0 },
          },
          data: {
            likeCount: {
              decrement: 1,
            },
          },
        });
      }
    });

    const hydrated = await prisma.eventLiveComment.findUnique({
      where: { id: commentId },
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
    if (!hydrated) {
      res.status(404).json({ error: 'Comment not found' });
      return;
    }
    const followingSet = await buildFollowingMap(userId, [hydrated.user.id, hydrated.replyToUser?.id].filter((id): id is string => Boolean(id)));
    res.json(mapEventLiveComment(hydrated, followingSet));
  } catch (error) {
    console.error('BFF unlike event live comment error:', error);
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

type NewsArticleRow = {
  id: string;
  authorId: string | null;
  author?: BasicUser | null;
  category: string;
  source: string;
  title: string;
  summary: string;
  body: string;
  link: string | null;
  coverImageUrl: string | null;
  boundDjIds: string[];
  boundBrandIds: string[];
  boundEventIds: string[];
  commentCount?: number | null;
  publishedAt: Date;
};

const mapNewsArticle = (article: NewsArticleRow) => ({
  id: article.id,
  category: article.category,
  source: article.source,
  title: article.title,
  summary: article.summary,
  body: article.body,
  link: article.link,
  coverImageURL: article.coverImageUrl,
  publishedAt: article.publishedAt.toISOString(),
  replyCount: article.commentCount ?? 0,
  authorID: article.authorId || '',
  authorUsername: article.author?.username || 'raver',
  authorName: article.author?.displayName || article.author?.username || 'Raver',
  authorAvatarURL: article.author?.avatarUrl || null,
  legacyEventID: null,
  boundDjIDs: article.boundDjIds,
  boundBrandIDs: article.boundBrandIds,
  boundEventIDs: article.boundEventIds,
});

const selectNewsArticleAuthor = {
  id: true,
  username: true,
  displayName: true,
  avatarUrl: true,
} as const;

type NewsCommentRow = {
  id: string;
  articleId: string;
  parentCommentId: string | null;
  rootCommentId: string | null;
  depth: number;
  user: BasicUser;
  replyToUser: BasicUser | null;
  content: string;
  createdAt: Date;
};

const mapNewsComment = (comment: NewsCommentRow, followingSet: Set<string>) => ({
  id: comment.id,
  postID: comment.articleId,
  parentCommentID: comment.parentCommentId ?? null,
  rootCommentID: comment.rootCommentId ?? null,
  depth: comment.depth ?? 0,
  author: toUserSummary(comment.user, followingSet.has(comment.user.id)),
  replyToAuthor: comment.replyToUser
    ? toUserSummary(comment.replyToUser, followingSet.has(comment.replyToUser.id))
    : null,
  content: comment.content,
  createdAt: comment.createdAt,
});

const normalizeNewsParentCommentId = (body: {
  parentCommentID?: unknown;
  parentCommentId?: unknown;
  replyToCommentID?: unknown;
  replyToCommentId?: unknown;
}): string | null => {
  const rawParentID =
    body.parentCommentID ??
    body.parentCommentId ??
    body.replyToCommentID ??
    body.replyToCommentId;
  const parentCommentID = typeof rawParentID === 'string' ? rawParentID.trim() : '';
  return parentCommentID.length > 0 ? parentCommentID : null;
};

const normalizeNewsCategory = (value: unknown): string => {
  const normalized = String(value || 'community').trim().toLowerCase();
  return ['festival', 'scene', 'gear', 'industry', 'community'].includes(normalized) ? normalized : 'community';
};

const normalizeNewsDraft = (body: Record<string, unknown>) => {
  const title = String(body.title || '').trim().slice(0, 180);
  const summary = String(body.summary || '').trim().slice(0, 500);
  const articleBody = String(body.body ?? body.content ?? '').trim();
  const source = String(body.source || 'Raver').trim().slice(0, 80) || 'Raver';
  const link = typeof body.link === 'string' && body.link.trim() ? body.link.trim().slice(0, 2000) : null;
  const coverImageUrl =
    typeof body.coverImageURL === 'string' && body.coverImageURL.trim()
      ? body.coverImageURL.trim()
      : typeof body.coverImageUrl === 'string' && body.coverImageUrl.trim()
        ? body.coverImageUrl.trim()
        : null;
  const publishedAtInput = body.publishedAt ?? body.published_at ?? body.displayPublishedAt ?? body.display_published_at;
  const parsedPublishedAt = parseFeedPostDateInput(publishedAtInput);

  return {
    title,
    summary,
    body: articleBody,
    source,
    link,
    coverImageUrl,
    category: normalizeNewsCategory(body.category),
    boundDjIds: normalizePostBindingIDs(body.boundDjIDs ?? body.boundDjIds ?? body.boundDJIDs ?? body.bound_dj_ids),
    boundBrandIds: normalizePostBindingIDs(body.boundBrandIDs ?? body.boundBrandIds ?? body.bound_brand_ids),
    boundEventIds: normalizePostBindingIDs(body.boundEventIDs ?? body.boundEventIds ?? body.bound_event_ids),
    publishedAt: parsedPublishedAt,
  };
};

router.get('/news/search', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId;
    const query = String(req.query.q || '').trim();
    const limit = normalizeLimit(req.query.limit, 20, 50);

    if (!query) {
      res.json({ items: [], nextCursor: null });
      return;
    }

    const blockedRelationUserIds = await buildBlockedRelationUserIds(viewerId);
    const rows = await prisma.newsArticle.findMany({
      where: {
        visibility: 'public',
        authorId: blockedRelationUserIds.size > 0 ? { notIn: Array.from(blockedRelationUserIds) } : undefined,
        OR: [
          { title: { contains: query, mode: 'insensitive' } },
          { summary: { contains: query, mode: 'insensitive' } },
          { body: { contains: query, mode: 'insensitive' } },
          { source: { contains: query, mode: 'insensitive' } },
        ],
      },
      include: { author: { select: selectNewsArticleAuthor } },
      orderBy: [{ publishedAt: 'desc' }, { id: 'desc' }],
      take: limit,
    });

    res.json({ items: rows.map(mapNewsArticle), nextCursor: null });
  } catch (error) {
    console.error('BFF news search error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/news/bound', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId;
    const eventID =
      typeof req.query.eventID === 'string'
        ? req.query.eventID.trim()
        : typeof req.query.eventId === 'string'
          ? req.query.eventId.trim()
          : '';
    const djID =
      typeof req.query.djID === 'string'
        ? req.query.djID.trim()
        : typeof req.query.djId === 'string'
          ? req.query.djId.trim()
          : '';
    const festivalID =
      typeof req.query.festivalID === 'string'
        ? req.query.festivalID.trim()
        : typeof req.query.festivalId === 'string'
          ? req.query.festivalId.trim()
          : typeof req.query.brandID === 'string'
            ? req.query.brandID.trim()
            : typeof req.query.brandId === 'string'
              ? req.query.brandId.trim()
              : '';

    if (!eventID && !djID && !festivalID) {
      res.status(400).json({ error: 'At least one binding identifier is required' });
      return;
    }

    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);
    const blockedRelationUserIds = await buildBlockedRelationUserIds(viewerId);

    const where = {
      visibility: 'public' as const,
      ...(eventID ? { boundEventIds: { has: eventID } } : {}),
      ...(djID ? { boundDjIds: { has: djID } } : {}),
      ...(festivalID ? { boundBrandIds: { has: festivalID } } : {}),
      ...(blockedRelationUserIds.size > 0
        ? {
            authorId: { notIn: Array.from(blockedRelationUserIds) },
          }
        : {}),
      ...(cursorDate
        ? {
            publishedAt: {
              lt: cursorDate,
            },
          }
        : {}),
    };

    const sourceArticles = await prisma.newsArticle.findMany({
      where,
      include: { author: { select: selectNewsArticleAuthor } },
      orderBy: [{ publishedAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = sourceArticles.length > limit;
    const pageArticles = hasMore ? sourceArticles.slice(0, limit) : sourceArticles;

    res.json({
      items: pageArticles.map(mapNewsArticle),
      nextCursor: hasMore ? pageArticles[pageArticles.length - 1]?.publishedAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF bound news feed error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/news/:id/comments', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const viewerId = (req as BFFAuthRequest).user?.userId;
    const articleId = String(req.params.id || '').trim();
    const article = await prisma.newsArticle.findFirst({
      where: { id: articleId, visibility: 'public' },
      select: { id: true },
    });
    if (!article) {
      res.status(404).json({ error: 'News article not found' });
      return;
    }

    const blockedRelationUserIds = await buildBlockedRelationUserIds(viewerId);
    const comments = await prisma.newsComment.findMany({
      where: { articleId },
      include: {
        user: { select: selectNewsArticleAuthor },
        replyToUser: { select: selectNewsArticleAuthor },
      },
      orderBy: { createdAt: 'asc' },
    });
    const visibleComments = comments.filter(
      (comment) =>
        !blockedRelationUserIds.has(comment.user.id) &&
        (!comment.replyToUser || !blockedRelationUserIds.has(comment.replyToUser.id))
    );
    const authorIds = Array.from(
      new Set(
        visibleComments
          .flatMap((comment) => [comment.user.id, comment.replyToUser?.id ?? null])
          .filter((id): id is string => Boolean(id))
      )
    );
    const followingSet = await buildFollowingMap(viewerId, authorIds);

    res.json(visibleComments.map((comment) => mapNewsComment(comment, followingSet)));
  } catch (error) {
    console.error('BFF news comments error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/news/:id/comments', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;
    if (await denyForEnforcement(userId, 'comment_create', res)) return;

    const articleId = String(req.params.id || '').trim();
    const body = (req.body ?? {}) as {
      content?: unknown;
      parentCommentID?: unknown;
      parentCommentId?: unknown;
      replyToCommentID?: unknown;
      replyToCommentId?: unknown;
    };
    const content = String(body.content || '').trim();
    if (!content) {
      res.status(400).json({ error: 'content is required' });
      return;
    }

    const normalizedParentCommentID = normalizeNewsParentCommentId(body);
    const result = await prisma.$transaction(async (tx) => {
      const article = await tx.newsArticle.findFirst({
        where: { id: articleId, visibility: 'public' },
        select: { id: true, authorId: true, title: true },
      });
      if (!article) {
        return { status: 404 as const, error: 'News article not found' };
      }

      let parentComment:
        | {
            id: string;
            articleId: string;
            userId: string;
            rootCommentId: string | null;
            depth: number;
          }
        | null = null;
      if (normalizedParentCommentID) {
        parentComment = await tx.newsComment.findUnique({
          where: { id: normalizedParentCommentID },
          select: {
            id: true,
            articleId: true,
            userId: true,
            rootCommentId: true,
            depth: true,
          },
        });
        if (!parentComment || parentComment.articleId !== articleId) {
          return { status: 400 as const, error: 'parentCommentID is invalid' };
        }
      }

      const rootCommentId = parentComment ? parentComment.rootCommentId ?? parentComment.id : null;
      const depth = parentComment ? Math.min((parentComment.depth ?? 0) + 1, 2) : 0;
      const replyToUserId = parentComment?.userId ?? null;
      const comment = await tx.newsComment.create({
        data: {
          articleId,
          userId,
          content,
          parentCommentId: parentComment?.id ?? null,
          rootCommentId,
          depth,
          replyToUserId,
        },
        include: {
          user: { select: selectNewsArticleAuthor },
          replyToUser: { select: selectNewsArticleAuthor },
        },
      });
      await tx.newsArticle.update({
        where: { id: articleId },
        data: { commentCount: { increment: 1 } },
        select: { id: true },
      });

      return { status: 201 as const, article, comment };
    });

    if ('error' in result) {
      res.status(result.status).json({ error: result.error });
      return;
    }

    if (result.article.authorId && result.article.authorId !== userId) {
      publishCommunityInteractionSafely({
        targetUserIds: [result.article.authorId],
        title: '资讯互动',
        body: '有人评论了你的资讯',
        deeplink: `raver://news/${articleId}`,
        metadata: {
          source: 'news_comment',
          actorUserID: userId,
          commentID: result.comment.id,
          articleID: articleId,
          articleTitle: result.article.title,
          commentPreview: truncateText(result.comment.content, 80) || null,
        },
        dedupeKey: `news:comment:${result.comment.id}:article_owner:${result.article.authorId}`,
      });
    }

    if (
      result.comment.replyToUser &&
      result.comment.replyToUser.id !== userId &&
      result.comment.replyToUser.id !== result.article.authorId
    ) {
      publishCommunityInteractionSafely({
        targetUserIds: [result.comment.replyToUser.id],
        title: '资讯互动',
        body: '有人回复了你的评论',
        deeplink: `raver://news/${articleId}`,
        metadata: {
          source: 'news_comment_reply',
          actorUserID: userId,
          commentID: result.comment.id,
          articleID: articleId,
          commentPreview: truncateText(result.comment.content, 80) || null,
        },
        dedupeKey: `news:comment:${result.comment.id}:reply_to:${result.comment.replyToUser.id}`,
      });
    }

    res.status(201).json(mapNewsComment(result.comment, new Set<string>()));
  } catch (error) {
    console.error('BFF add news comment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/news/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const articleId = String(req.params.id || '').trim();
    const article = await prisma.newsArticle.findFirst({
      where: { id: articleId, visibility: 'public' },
      include: { author: { select: selectNewsArticleAuthor } },
    });
    if (!article) {
      res.status(404).json({ error: 'News article not found' });
      return;
    }
    res.json(mapNewsArticle(article));
  } catch (error) {
    console.error('BFF fetch news article error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/news', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId;
    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);
    const blockedRelationUserIds = await buildBlockedRelationUserIds(viewerId);
    const rows = await prisma.newsArticle.findMany({
      where: {
        visibility: 'public',
        authorId: blockedRelationUserIds.size > 0 ? { notIn: Array.from(blockedRelationUserIds) } : undefined,
        ...(cursorDate ? { publishedAt: { lt: cursorDate } } : {}),
      },
      include: { author: { select: selectNewsArticleAuthor } },
      orderBy: [{ publishedAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = rows.length > limit;
    const pageRows = hasMore ? rows.slice(0, limit) : rows;
    res.json({
      items: pageRows.map(mapNewsArticle),
      nextCursor: hasMore ? pageRows[pageRows.length - 1]?.publishedAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF news feed error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/news', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    if (await denyForEnforcement(userId, 'post_create', res)) return;

    const body = (req.body ?? {}) as Record<string, unknown>;
    const draft = normalizeNewsDraft(body);
    if (draft.publishedAt === 'invalid') {
      res.status(400).json({ error: 'publishedAt is invalid' });
      return;
    }
    if (!draft.title && !draft.body) {
      res.status(400).json({ error: 'title or body is required' });
      return;
    }

    const viewerRole = authReq.user?.role ?? null;
    const submissionPayload = {
      ...body,
      title: draft.title,
      summary: draft.summary,
      body: draft.body,
      source: draft.source,
      category: draft.category,
      link: draft.link,
      coverImageURL: draft.coverImageUrl,
      boundDjIDs: draft.boundDjIds,
      boundBrandIDs: draft.boundBrandIds,
      boundEventIDs: draft.boundEventIds,
      publishedAt: (draft.publishedAt || new Date()).toISOString(),
    };
    const complianceError = contentCompliance.validationError('news', submissionPayload);
    if (complianceError) {
      res.status(400).json({ error: complianceError });
      return;
    }

    if (!canBypassContentReview(viewerRole)) {
      const submission = await createPendingContentSubmission({
        submitterId: userId,
        entityType: 'news',
        title: draft.title || newsTitleFromContent(draft.body),
        payload: submissionPayload,
      });
      acceptedSubmission(res, submission, '资讯已提交审核，管理员审核通过后才会发布');
      return;
    }

    const created = await prisma.newsArticle.create({
      data: {
        authorId: userId,
        category: draft.category,
        source: draft.source,
        title: draft.title || newsTitleFromContent(draft.body),
        summary: draft.summary,
        body: draft.body,
        link: draft.link,
        coverImageUrl: draft.coverImageUrl,
        visibility: 'public',
        boundDjIds: draft.boundDjIds,
        boundBrandIds: draft.boundBrandIds,
        boundEventIds: draft.boundEventIds,
        publishedAt: draft.publishedAt || new Date(),
      },
      include: { author: { select: selectNewsArticleAuthor } },
    });
    res.status(201).json(mapNewsArticle(created));
  } catch (error) {
    console.error('BFF create news article error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/feed/search', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId;
    const query = String(req.query.q || '').trim();
    const limit = normalizeLimit(req.query.limit, 20, 50);
    const blockedRelationUserIds = await buildBlockedRelationUserIds(viewerId);

    if (!query) {
      res.json({ posts: [], nextCursor: null });
      return;
    }

    const posts = await prisma.post.findMany({
      where: {
        visibility: 'public',
        squadId: null,
        ...(blockedRelationUserIds.size > 0
          ? {
              userId: { notIn: Array.from(blockedRelationUserIds) },
            }
          : {}),
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
    const blockedRelationUserIds = await buildBlockedRelationUserIds(viewerId);

    if (!postID) {
      res.status(400).json({ error: 'Post id is required' });
      return;
    }

    const post = await prisma.post.findFirst({
      where: {
        id: postID,
        visibility: 'public',
        squadId: null,
        ...(blockedRelationUserIds.size > 0
          ? {
              userId: { notIn: Array.from(blockedRelationUserIds) },
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
    const blockedRelationUserIds = await buildBlockedRelationUserIds(userId);
    if (!query) {
      res.json([]);
      return;
    }

    const users = await prisma.user.findMany({
      where: {
        isActive: true,
        id: blockedRelationUserIds.size > 0
          ? { not: userId, notIn: Array.from(blockedRelationUserIds) }
          : { not: userId },
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

    const [followersCount, followingCount, postsCount, followRow, viewerFriendIds, targetFriendIds] = await Promise.all([
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
      viewerId === targetUserId ? Promise.resolve(new Set<string>()) : buildFriendUserIds(viewerId, [targetUserId]),
      buildFriendUserIds(targetUserId),
    ]);

    const profileShareLink = await resolveOrCreateShareLink({
      prisma,
      targetType: 'user_card',
      targetId: targetUserId,
      userId: viewerId,
      channel: 'profile_qr_bootstrap',
      preferPermanent: true,
    });

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
      friendsCount: targetFriendIds.size,
      postsCount,
      isFollowing: Boolean(followRow),
      isFriend: viewerId === targetUserId ? false : viewerFriendIds.has(targetUserId),
      qrCodeURL: profileShareLink.qrCodeUrl,
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
    const blockedRelationUserIds = await buildBlockedRelationUserIds(viewerId);

    const targetUser = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true, isActive: true },
    });

    if (!targetUser || !targetUser.isActive) {
      res.status(404).json({ error: 'User not found' });
      return;
    }
    if (blockedRelationUserIds.has(targetUserId)) {
      res.json({ posts: [], nextCursor: null });
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

    let qrCodeURL = squad.qrCodeUrl;
    if (!qrCodeURL) {
      const qrPayload = await resolveOrCreateShareLink({
        prisma,
        targetType: squad.isPublic ? 'squad_card' : 'squad_invite',
        targetId: squad.id,
        userId,
        channel: 'squad_qr_bootstrap',
        preferPermanent: squad.isPublic,
        expiresInHours: squad.isPublic ? null : 72,
        maxUses: squad.isPublic ? null : 10,
      });
      qrCodeURL = qrPayload.qrCodeUrl;
    }

    res.json({
      id: squad.id,
      name: squad.name,
      description: squad.description,
      avatarURL: squad.avatarUrl,
      bannerURL: squad.bannerUrl,
      notice: squad.notice || '',
      qrCodeURL,
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

router.get('/squads/:id/offline-activity/current', optionalAuth, async (req: Request, res: Response): Promise<void> => {
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
        select: { id: true, role: true },
      }),
    ]);

    if (!squad) {
      res.status(404).json({ error: 'Squad not found' });
      return;
    }

    if (!membership) {
      res.status(403).json({ error: 'Join squad before viewing offline activity' });
      return;
    }

    const activity = await fetchActiveSquadOfflineActivity(squadId);
    res.json(await toSquadOfflineActivityResponse(activity, userId, canManageSquadAsMember(membership, squad, userId)));
  } catch (error) {
    console.error('BFF current squad offline activity error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/squads/:id/offline-activities/history', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const limitParam = Number(req.query.limit);
    const limit = Number.isFinite(limitParam) ? Math.max(1, Math.min(50, Math.floor(limitParam))) : 30;

    const membership = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId,
          userId,
        },
      },
      select: { id: true },
    });

    if (!membership) {
      res.status(403).json({ error: 'Join squad before viewing offline activity history' });
      return;
    }

    const activities = await prisma.squadOfflineActivity.findMany({
      where: {
        squadId,
        status: { not: ACTIVE_SQUAD_OFFLINE_ACTIVITY_STATUS },
        endedAt: { not: null },
      },
      include: {
        createdBy: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        event: {
          select: {
            id: true,
            name: true,
            coverImageUrl: true,
            venueName: true,
            venueAddress: true,
            city: true,
            country: true,
            latitude: true,
            longitude: true,
            locationPoint: true,
            manualLocation: true,
          },
        },
        participants: {
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
          orderBy: { joinedAt: 'asc' },
        },
      },
      orderBy: { endedAt: 'desc' },
      take: limit,
    });

    res.json(await Promise.all(activities.map((activity) => toSquadOfflineActivityResponse(activity, userId, false))));
  } catch (error) {
    console.error('BFF squad offline activity history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/squads/:id/offline-activities', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const body = req.body as { eventID?: unknown; eventId?: unknown; title?: unknown };
    const eventId = typeof body.eventID === 'string'
      ? body.eventID.trim()
      : typeof body.eventId === 'string'
        ? body.eventId.trim()
        : '';
    const title = typeof body.title === 'string' ? body.title.trim() : '';

    const [squad, membership, existingActive] = await Promise.all([
      prisma.squad.findUnique({
        where: { id: squadId },
        select: { id: true, name: true, leaderId: true },
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
      fetchActiveSquadOfflineActivity(squadId),
    ]);

    if (!squad) {
      res.status(404).json({ error: 'Squad not found' });
      return;
    }

    if (!canManageSquadAsMember(membership, squad, userId)) {
      console.warn('BFF create squad offline activity forbidden', {
        squadId,
        userId,
        memberRole: membership?.role ?? null,
        leaderId: squad.leaderId,
      });
      res.status(403).json({ error: 'Only squad leader/admin can start offline activity' });
      return;
    }

    if (existingActive) {
      res.status(409).json({ error: 'Squad already has an active offline activity' });
      return;
    }

    let eventSnapshot: { id: string; name: string } | null = null;
    if (eventId) {
      eventSnapshot = await prisma.event.findUnique({
        where: { id: eventId },
        select: { id: true, name: true },
      });
      if (!eventSnapshot) {
        res.status(404).json({ error: 'Event not found' });
        return;
      }
    }

    await prisma.squadOfflineActivity.create({
      data: {
        squadId,
        eventId: eventSnapshot?.id ?? null,
        title: title || eventSnapshot?.name || null,
        createdById: userId,
        participants: {
          create: {
            userId,
          },
        },
      },
      select: { id: true },
    });

    await prisma.squadMessage.create({
      data: {
        squadId,
        userId,
        content: eventSnapshot ? `开启了线下活动：${eventSnapshot.name}` : '开启了线下活动',
        type: 'system',
      },
    });

    const activity = await fetchActiveSquadOfflineActivity(squadId);
    res.status(201).json(await toSquadOfflineActivityResponse(activity, userId, canManageSquadAsMember(membership, squad, userId)));
  } catch (error) {
    console.error('BFF create squad offline activity error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/squads/:id/offline-activities/:activityId/end', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const activityId = req.params.activityId as string;
    const [activity, squad, membership] = await Promise.all([
      prisma.squadOfflineActivity.findUnique({
        where: { id: activityId },
        include: {
          event: {
            select: {
              name: true,
              coverImageUrl: true,
              venueName: true,
              venueAddress: true,
              city: true,
              country: true,
            },
          },
          participants: {
            select: { userId: true },
          },
        },
      }),
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

    if (!activity || activity.squadId !== squadId || !squad) {
      res.status(404).json({ error: 'Offline activity not found' });
      return;
    }

    const canEndActivity = activity.createdById === userId || canManageSquadAsMember(membership, squad, userId);
    if (!canEndActivity) {
      console.warn('BFF end squad offline activity forbidden', {
        squadId,
        activityId,
        userId,
        createdById: activity.createdById,
        memberRole: membership?.role ?? null,
        leaderId: squad.leaderId,
      });
      res.status(403).json({ error: 'Only activity creator or squad leader/admin can end offline activity' });
      return;
    }

    const endedAt = new Date();
    const endedActivity = {
      ...activity,
      endedAt,
    };
    const cardPayload = buildSquadOfflineActivityCardPayload(endedActivity);
    const cardContent = encodeSquadOfflineActivityCardContent(cardPayload);
    await prisma.$transaction(async (tx) => {
      await tx.squadOfflineActivity.update({
        where: { id: activityId },
        data: {
          status: 'ended',
          endedAt,
          summary: {
            status: 'pending_ai_summary',
            generatedAt: null,
          },
        },
      });
      await tx.squadOfflineActivityParticipant.updateMany({
        where: {
          activityId,
          leftAt: null,
        },
        data: { leftAt: endedAt, isInRestroom: false, isBuyingDrink: false },
      });
      await tx.squadMessage.create({
        data: {
          squadId,
          userId: activity.createdById,
          content: cardContent,
          type: 'card',
        },
      });
    });

    try {
      await sendSquadOfflineActivityCardToTencentIM(squadId, activity.createdById, cardPayload);
    } catch (error) {
      console.warn('BFF send squad offline activity card to Tencent IM failed:', error);
    }

    const current = await fetchSquadOfflineActivityById(activityId);
    res.json(await toSquadOfflineActivityResponse(current, userId, canManageSquadAsMember(membership, squad, userId)));
  } catch (error) {
    console.error('BFF end squad offline activity error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/squads/:id/offline-activities/:activityId/join', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const activityId = req.params.activityId as string;
    const [activity, membership] = await Promise.all([
      prisma.squadOfflineActivity.findUnique({
        where: { id: activityId },
        select: { id: true, squadId: true, status: true, endedAt: true },
      }),
      prisma.squadMember.findUnique({
        where: {
          squadId_userId: {
            squadId,
            userId,
          },
        },
        select: { id: true },
      }),
    ]);

    if (!membership) {
      res.status(403).json({ error: 'Join squad before joining offline activity' });
      return;
    }

    if (!activity || activity.squadId !== squadId || activity.status !== ACTIVE_SQUAD_OFFLINE_ACTIVITY_STATUS || activity.endedAt) {
      res.status(404).json({ error: 'Active offline activity not found' });
      return;
    }

    await prisma.squadOfflineActivityParticipant.upsert({
      where: {
        activityId_userId: {
          activityId,
          userId,
        },
      },
      create: {
        activityId,
        userId,
      },
      update: {
        leftAt: null,
        isInRestroom: false,
        isBuyingDrink: false,
      },
    });

    const current = await fetchActiveSquadOfflineActivity(squadId);
    res.json(await toSquadOfflineActivityResponse(current, userId));
  } catch (error) {
    console.error('BFF join squad offline activity error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/squads/:id/offline-activities/:activityId/leave', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const activityId = req.params.activityId as string;
    const activity = await prisma.squadOfflineActivity.findUnique({
      where: { id: activityId },
      select: { id: true, squadId: true },
    });

    if (!activity || activity.squadId !== squadId) {
      res.status(404).json({ error: 'Offline activity not found' });
      return;
    }

    await prisma.squadOfflineActivityParticipant.updateMany({
      where: {
        activityId,
        userId,
        leftAt: null,
      },
      data: {
        leftAt: new Date(),
        isInRestroom: false,
        isBuyingDrink: false,
      },
    });

    const current = await fetchActiveSquadOfflineActivity(squadId);
    res.json(await toSquadOfflineActivityResponse(current, userId));
  } catch (error) {
    console.error('BFF leave squad offline activity error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/squads/:id/offline-activities/:activityId/status', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const activityId = req.params.activityId as string;
    const body = req.body as Record<string, unknown>;
    const isInRestroom = normalizeOptionalBoolean(body.isInRestroom);
    const isBuyingDrink = normalizeOptionalBoolean(body.isBuyingDrink);

    if (isInRestroom === null && isBuyingDrink === null) {
      res.status(400).json({ error: 'Invalid offline activity status payload' });
      return;
    }

    const [activity, squad, membership, participant] = await Promise.all([
      prisma.squadOfflineActivity.findUnique({
        where: { id: activityId },
        select: { id: true, squadId: true, status: true, endedAt: true },
      }),
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
      prisma.squadOfflineActivityParticipant.findUnique({
        where: {
          activityId_userId: {
            activityId,
            userId,
          },
        },
        select: { id: true, leftAt: true, isInRestroom: true, isBuyingDrink: true },
      }),
    ]);

    if (!activity || activity.squadId !== squadId || !squad || activity.status !== ACTIVE_SQUAD_OFFLINE_ACTIVITY_STATUS || activity.endedAt) {
      res.status(404).json({ error: 'Active offline activity not found' });
      return;
    }

    if (!membership) {
      res.status(403).json({ error: 'Join squad before updating offline activity status' });
      return;
    }

    if (!participant || participant.leftAt) {
      res.status(403).json({ error: 'Join offline activity before updating status' });
      return;
    }

    const capturedAt = new Date();
    const statusEvents: Array<{ statusType: string; isActive: boolean }> = [];
    if (isInRestroom !== null && isInRestroom !== participant.isInRestroom) {
      statusEvents.push({ statusType: 'restroom', isActive: isInRestroom });
    }
    if (isBuyingDrink !== null && isBuyingDrink !== participant.isBuyingDrink) {
      statusEvents.push({ statusType: 'buying_drink', isActive: isBuyingDrink });
    }

    await prisma.$transaction(async (tx) => {
      await tx.squadOfflineActivityParticipant.update({
        where: { id: participant.id },
        data: {
          ...(isInRestroom !== null ? { isInRestroom } : {}),
          ...(isBuyingDrink !== null ? { isBuyingDrink } : {}),
        },
        select: { id: true },
      });

      if (statusEvents.length > 0) {
        await tx.squadOfflineActivityStatusEvent.createMany({
          data: statusEvents.map((event) => ({
            activityId,
            userId,
            statusType: event.statusType,
            isActive: event.isActive,
            capturedAt,
          })),
        });
      }
    });

    const current = await fetchActiveSquadOfflineActivity(squadId);
    res.json(await toSquadOfflineActivityResponse(current, userId, canManageSquadAsMember(membership, squad, userId)));
  } catch (error) {
    console.error('BFF update squad offline activity status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/squads/:id/offline-activities/:activityId/participants/:participantUserId/remove', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const activityId = req.params.activityId as string;
    const participantUserId = req.params.participantUserId as string;

    const [activity, squad, membership, participant] = await Promise.all([
      prisma.squadOfflineActivity.findUnique({
        where: { id: activityId },
        select: { id: true, squadId: true, status: true, endedAt: true },
      }),
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
      prisma.squadOfflineActivityParticipant.findUnique({
        where: {
          activityId_userId: {
            activityId,
            userId: participantUserId,
          },
        },
        select: { id: true, leftAt: true },
      }),
    ]);

    if (!activity || activity.squadId !== squadId || !squad || activity.status !== ACTIVE_SQUAD_OFFLINE_ACTIVITY_STATUS || activity.endedAt) {
      res.status(404).json({ error: 'Active offline activity not found' });
      return;
    }

    if (!canManageSquadAsMember(membership, squad, userId)) {
      res.status(403).json({ error: 'Only squad leader/admin can remove offline activity participant' });
      return;
    }

    if (!participant || participant.leftAt) {
      res.status(404).json({ error: 'Offline activity participant not found' });
      return;
    }

    await prisma.squadOfflineActivityParticipant.update({
      where: { id: participant.id },
      data: { leftAt: new Date(), isInRestroom: false, isBuyingDrink: false },
      select: { id: true },
    });

    const current = await fetchActiveSquadOfflineActivity(squadId);
    res.json(await toSquadOfflineActivityResponse(current, userId, true));
  } catch (error) {
    console.error('BFF remove squad offline activity participant error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/squads/:id/offline-activities/:activityId/location', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;
    if (await denyForEnforcement(userId, 'location_share', res)) return;
    if (await denyForMinorRegionalRestriction(userId, 'locationSharing', res)) return;

    const squadId = req.params.id as string;
    const activityId = req.params.activityId as string;
    const body = req.body as Record<string, unknown>;
    const latitude = normalizeCoordinate(body.latitude, -90, 90);
    const longitude = normalizeCoordinate(body.longitude, -180, 180);
    const capturedAtText = typeof body.capturedAt === 'string' ? body.capturedAt : '';
    const capturedAt = capturedAtText ? new Date(capturedAtText) : new Date();

    if (latitude === null || longitude === null || Number.isNaN(capturedAt.getTime())) {
      res.status(400).json({ error: 'Invalid location payload' });
      return;
    }

    const [activity, participant] = await Promise.all([
      prisma.squadOfflineActivity.findUnique({
        where: { id: activityId },
        select: { id: true, squadId: true, status: true, endedAt: true },
      }),
      prisma.squadOfflineActivityParticipant.findUnique({
        where: {
          activityId_userId: {
            activityId,
            userId,
          },
        },
        select: { id: true, leftAt: true },
      }),
    ]);

    if (!activity || activity.squadId !== squadId || activity.status !== ACTIVE_SQUAD_OFFLINE_ACTIVITY_STATUS || activity.endedAt) {
      res.status(404).json({ error: 'Active offline activity not found' });
      return;
    }

    if (!participant || participant.leftAt) {
      res.status(403).json({ error: 'Join offline activity before uploading location' });
      return;
    }

    await prisma.$transaction(async (tx) => {
      await tx.squadOfflineActivityLocation.create({
        data: {
          activityId,
          userId,
          latitude,
          longitude,
          accuracy: normalizeFiniteNumber(body.accuracy),
          altitude: normalizeFiniteNumber(body.altitude),
          speed: normalizeFiniteNumber(body.speed),
          heading: normalizeFiniteNumber(body.heading),
          capturedAt,
        },
      });
      await tx.squadOfflineActivityParticipant.update({
        where: { id: participant.id },
        data: { lastLocationAt: capturedAt },
      });
    });

    res.status(201).json({ success: true });
  } catch (error) {
    console.error('BFF upload squad offline activity location error:', error);
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
      const [friendIds, blockedRelationUserIds] = await Promise.all([
        buildFriendUserIds(userId, normalizedMemberIds),
        buildBlockedRelationUserIds(userId),
      ]);
      if (friendIds.size !== normalizedMemberIds.length) {
        res.status(403).json({ error: '只能从好友列表中选择小队成员' });
        return;
      }
      if (normalizedMemberIds.some((memberId) => blockedRelationUserIds.has(memberId))) {
        res.status(403).json({ error: '不能邀请已拉黑用户创建小队' });
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

      const upload = await uploadSquadAvatarAsset(squadId, file);
      const avatarUrl = upload.url;
      await prisma.squad.update({
        where: { id: squadId },
        data: { avatarUrl },
        select: { id: true },
      });
      if (previousSquad?.avatarUrl && previousSquad.avatarUrl !== avatarUrl) {
        await mediaAssetService.markReplacedByUrl(previousSquad.avatarUrl);
      }

      try {
        await syncSquadGroupInfo(squadId);
      } catch (error) {
        await prisma.squad.update({
          where: { id: squadId },
          data: { avatarUrl: previousSquad?.avatarUrl || null },
          select: { id: true },
        });
        await mediaAssetService.markReplacedByUrl(avatarUrl);
        throw error;
      }

      res.status(201).json({ avatarURL: avatarUrl, assetId: upload.assetId });
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
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    if (await denyForEnforcement(userId, 'post_create', res)) return;
    const viewerRole = authReq.user?.role ?? null;

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

    const isNewsSubmission = trimmed
      .split(/\r?\n/)
      .map((line) => line.trim())
      .includes('#RAVER_NEWS');
    const isIDSubmission = trimmed
      .split(/\r?\n/)
      .map((line) => line.trim())
      .includes('#RAVER_ID');

    if (isNewsSubmission) {
      res.status(400).json({ error: 'News must be submitted through /v1/news' });
      return;
    }

    if (!canBypassContentReview(viewerRole) && isIDSubmission) {
      const entityType = 'id';
      const title = idTitleFromContent(trimmed);
      const idPayload = isIDSubmission ? idPayloadFromContent(trimmed) : {};
      const submissionPayload = {
        ...body,
        ...idPayload,
        title,
        content: trimmed,
        images: normalizedImages,
        location: normalizedLocation || null,
        boundDjIDs: normalizedBoundDjIDs,
        boundBrandIDs: normalizedBoundBrandIDs,
        boundEventIDs: normalizedBoundEventIDs,
        displayPublishedAt: parsedDisplayPublishedAt || new Date().toISOString(),
      };
      const complianceError = contentCompliance.validationError(entityType, submissionPayload);
      if (complianceError) {
        res.status(400).json({ error: complianceError });
        return;
      }
      const submission = await createPendingContentSubmission({
        submitterId: userId,
        entityType,
        title,
        payload: submissionPayload,
      });
      acceptedSubmission(
        res,
        submission,
        'ID 已提交审核，管理员审核通过后才会发布'
      );
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

    void publishFollowedDJNewsSafely({
      actorUserId: userId,
      postId: created.id,
      content: created.content,
      imageURLs: Array.isArray(created.images) ? created.images : [],
      boundDjIDs: Array.isArray((created as any).boundDjIds) ? ((created as any).boundDjIds as string[]) : [],
      occurredAt: created.displayPublishedAt ?? created.createdAt,
    });

    void publishFollowedBrandNewsSafely({
      actorUserId: userId,
      postId: created.id,
      content: created.content,
      imageURLs: Array.isArray(created.images) ? created.images : [],
      boundBrandIDs: Array.isArray((created as any).boundBrandIds) ? ((created as any).boundBrandIds as string[]) : [],
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
    const { post, createdLikeId } = await likePost(postId, userId);

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
    if (error instanceof PostInteractionNotFoundError) {
      res.status(404).json({ error: error.message });
      return;
    }
    console.error('BFF like post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/feed/posts/:id/like', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;
    await unlikePost(postId, userId);

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
    await repostPost(postId, userId);

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
    if (error instanceof PostInteractionNotFoundError) {
      res.status(404).json({ error: error.message });
      return;
    }
    console.error('BFF repost post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/feed/posts/:id/repost', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;
    await unrepostPost(postId, userId);

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
    await savePost(postId, userId);

    const mapped = await hydratePostForViewer(postId, userId);
    if (!mapped) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }
    res.json(mapped);
  } catch (error) {
    if (error instanceof PostInteractionNotFoundError) {
      res.status(404).json({ error: error.message });
      return;
    }
    console.error('BFF save post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/feed/posts/:id/save', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;
    await unsavePost(postId, userId);

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
    const body = (req.body ?? {}) as Record<string, unknown>;
    await sharePost(postId, userId, body);

    const mapped = await hydratePostForViewer(postId, userId);
    if (!mapped) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }
    res.json(mapped);
  } catch (error) {
    if (error instanceof PostInteractionNotFoundError) {
      res.status(404).json({ error: error.message });
      return;
    }
    console.error('BFF share post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/posts/:id/hide', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;
    const body = (req.body ?? {}) as Record<string, unknown>;
    await hidePost(postId, userId, body);

    res.json({ success: true, hiddenPostId: postId });
  } catch (error) {
    if (error instanceof PostInteractionNotFoundError) {
      res.status(404).json({ error: error.message });
      return;
    }
    console.error('BFF hide post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/feed/posts/:id/hide', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;
    await unhidePost(postId, userId);

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
    const blockedRelationUserIds = await buildBlockedRelationUserIds(viewerId);

    const comments = await fetchPostComments(postId);
    const visibleComments = comments.filter(
      (comment) =>
        !blockedRelationUserIds.has(comment.user.id) &&
        (!comment.replyToUser || !blockedRelationUserIds.has(comment.replyToUser.id))
    );

    const authorIds = Array.from(
      new Set(
        visibleComments
          .flatMap((comment) => [comment.user.id, comment.replyToUser?.id ?? null])
          .filter((id): id is string => Boolean(id))
      )
    );
    const followingSet = await buildFollowingMap(viewerId, authorIds);

    res.json(
      visibleComments.map((comment) => ({
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
    if (await denyForEnforcement(userId, 'comment_create', res)) return;

    const postId = req.params.id as string;
    const body = (req.body ?? {}) as {
      content?: unknown;
      parentCommentID?: unknown;
      parentCommentId?: unknown;
      replyToCommentID?: unknown;
      replyToCommentId?: unknown;
    };
    const { post, comment } = await createPostComment(postId, userId, body);

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
    if (error instanceof PostCommentValidationError) {
      res.status(error.status).json({ error: error.message });
      return;
    }
    if (error instanceof PostCommentNotFoundError) {
      res.status(404).json({ error: error.message });
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
    const blockedRelationUserIds = await buildBlockedRelationUserIds(userId);

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

      const visibleDirectConversations = directConversations.filter((conversation) => {
        const peerId = conversation.userAId === userId ? conversation.userBId : conversation.userAId;
        return !blockedRelationUserIds.has(peerId);
      });
      const conversationIds = visibleDirectConversations.map((conversation) => conversation.id);
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
        visibleDirectConversations.map(async (conversation) => {
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
        visibleDirectConversations.map((conversation) =>
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

    if (await hasBlockingRelationship(userId, target.id)) {
      res.status(403).json({ error: '无法与该用户发起私信' });
      return;
    }

    const isFriend = await isMutualFriend(userId, target.id);
    if (!isFriend && await denyForMinorRegionalRestriction(userId, 'strangerDirectMessages', res)) {
      return;
    }

    if (!isFriend) {
      res.status(403).json({ error: '需要双方互相关注成为好友后才能聊天' });
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
      const directTargetUserId = directConversation.userAId === userId
        ? directConversation.userBId
        : directConversation.userAId;
      if (await hasBlockingRelationship(userId, directTargetUserId)) {
        res.status(403).json({ error: 'Forbidden' });
        return;
      }

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
          kind: message.type === 'system_friend_created' ? 'system' : 'text',
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

    const blockedRelationUserIds = await buildBlockedRelationUserIds(userId);
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
    const visibleMessages = messages.filter((message) => {
      if (message.type === 'system') return true;
      if (message.userId === userId) return true;
      return !blockedRelationUserIds.has(message.userId);
    });

    const senderIds = Array.from(new Set(visibleMessages.map((msg) => msg.user.id)));
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
      visibleMessages.map((message) => ({
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
    if (await denyForEnforcement(userId, 'message_send', res)) return;

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
      const directTargetUserId = directConversation.userAId === userId
        ? directConversation.userBId
        : directConversation.userAId;

      if (await hasBlockingRelationship(userId, directTargetUserId)) {
        res.status(403).json({ error: '无法向该用户发送私信' });
        return;
      }

      if (!(await isMutualFriend(userId, directTargetUserId))) {
        res.status(403).json({ error: '需要双方互相关注成为好友后才能聊天' });
        return;
      }

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
    const blockedRelationUserIds = await buildBlockedRelationUserIds(userId);

    const senderDisplayName = created.user.displayName || created.user.username || '新消息';
    publishChatMessageSafely({
      targetUserIds: targetMembers.map((item) => item.userId).filter((targetUserId) => !blockedRelationUserIds.has(targetUserId)),
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
          email: true,
          role: true,
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

    const profileShareLink = await resolveOrCreateShareLink({
      prisma,
      targetType: 'user_card',
      targetId: userId,
      userId,
      channel: 'profile_qr_bootstrap',
      preferPermanent: true,
    });

    res.json({
      id: user.id,
      username: user.username,
      email: user.email,
      role: user.role,
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
      qrCodeURL: profileShareLink.qrCodeUrl,
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
    if (await denyForEnforcement(userId, 'profile_update', res)) return;

    const body = req.body as {
      displayName?: string;
      bio?: string;
      tags?: unknown;
      isFollowersListPublic?: boolean;
      isFollowingListPublic?: boolean;
    };

    const data: {
      displayName?: string;
      displayNameNormalized?: string;
      displayNameStatus?: string;
      displayNameReviewNote?: string | null;
      bio?: string;
      favoriteGenres?: string[];
      isFollowersListPublic?: boolean;
      isFollowingListPublic?: boolean;
    } = {};

    if (typeof body.displayName === 'string') {
      const trimmed = normalizeDisplayName(body.displayName);
      if (!trimmed) {
        res.status(400).json({ error: 'displayName cannot be empty' });
        return;
      }
      if (trimmed.length < 2 || trimmed.length > 24) {
        res.status(400).json({ error: '昵称需要 2-24 个字符' });
        return;
      }
      const displayNameKey = normalizeDisplayNameForUniqueness(trimmed);
      const existingDisplayNameUser = await prisma.user.findFirst({
        where: {
          displayNameNormalized: displayNameKey,
          id: { not: userId },
        },
        select: { id: true },
      });
      if (existingDisplayNameUser) {
        res.status(409).json({ error: '昵称已被使用' });
        return;
      }
      data.displayName = trimmed;
      data.displayNameNormalized = displayNameKey;
      data.displayNameStatus = 'pending';
      data.displayNameReviewNote = null;
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

      if (data.displayName && data.displayNameNormalized) {
        await createProfileModerationJob(
          userId,
          'display_name',
          data.displayName,
          data.displayNameNormalized
        );
      }

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
      if (await denyForEnforcement(userId, 'media_upload', res)) return;

      const file = (req as Request & { file?: Express.Multer.File }).file;
      if (!file) {
        res.status(400).json({ error: 'No file uploaded' });
        return;
      }

      const previousUser = await prisma.user.findUnique({
        where: { id: userId },
        select: { avatarUrl: true },
      });

      const upload = await uploadUserAvatarToOss(userId, file);
      const avatarUrl = upload.url;
      await prisma.user.update({
        where: { id: userId },
        data: {
          avatarUrl,
          avatarStatus: 'pending',
          avatarReviewNote: null,
        },
        select: { id: true },
      });

      if (previousUser?.avatarUrl && previousUser.avatarUrl !== avatarUrl) {
        await mediaAssetService.markReplacedByUrl(previousUser.avatarUrl);
      }

      await createProfileModerationJob(
        userId,
        'avatar',
        avatarUrl,
        upload.objectKey
      );

      await syncTencentIMUserBestEffort(userId, 'bff-profile-avatar');

      res.status(201).json({ avatarURL: avatarUrl, assetId: upload.assetId });
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
    let friendConversationResult: { conversationId: string; createdGreeting: boolean } | null = null;
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

    const becameFriends = await isMutualFriend(userId, targetUserId);
    if (becameFriends) {
      friendConversationResult = await ensureFriendConversationWithGreeting(userId, targetUserId);
      await syncTencentIMFriendshipBestEffort(userId, targetUserId, 'bff-mutual-follow');
      if (friendConversationResult.createdGreeting) {
        await sendTencentIMFriendCreatedTipBestEffort(
          userId,
          targetUserId,
          FRIEND_CHAT_GREETING,
          'bff-mutual-follow'
        );
      }
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

    res.json({
      ...toUserSummary(target, true),
      isFriend: becameFriends,
      conversationID: friendConversationResult?.conversationId ?? null,
      friendMessage: becameFriends ? FRIEND_CHAT_GREETING : null,
    });
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
