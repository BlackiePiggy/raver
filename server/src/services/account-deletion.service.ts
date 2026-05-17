import { Prisma, PrismaClient } from '@prisma/client';
import OSS from 'ali-oss';
import crypto from 'crypto';
import { tencentIMClient, tencentIMConfig, toTencentIMUserID } from '../modules/im';

const prisma = new PrismaClient();

type PrismaLike = PrismaClient | Prisma.TransactionClient;

type DeletionUserSnapshot = {
  id: string;
  email: string | null;
  phoneNumber: string | null;
  avatarUrl: string | null;
  profileShareQrCodeUrl: string | null;
  posts?: Array<{ images: string[] }>;
  eventLiveComments?: Array<{ imageUrls: string[] }>;
  squadMessages?: Array<{ imageUrl: string | null }>;
  uploadedPhotos?: Array<{ url: string }>;
};

type AccountDeletionRequestSource = 'ios' | 'web' | 'admin';

const cleanEnv = (value: string | undefined): string | null => {
  const trimmed = String(value || '').trim();
  return trimmed || null;
};

const ossRegion = cleanEnv(process.env.OSS_REGION);
const ossAccessKeyId = cleanEnv(process.env.OSS_ACCESS_KEY_ID);
const ossAccessKeySecret = cleanEnv(process.env.OSS_ACCESS_KEY_SECRET);
const ossBucket = cleanEnv(process.env.OSS_BUCKET);
const ossEndpoint = cleanEnv(process.env.OSS_ENDPOINT);

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

const stableHash = (value: string | null | undefined): string | null => {
  const normalized = String(value || '').trim().toLowerCase();
  if (!normalized) return null;
  return crypto.createHash('sha256').update(normalized).digest('hex');
};

const nextRetryAt = (attempts: number): Date => {
  const minutes = Math.min(24 * 60, Math.max(5, 5 * 2 ** Math.min(attempts, 8)));
  return new Date(Date.now() + minutes * 60 * 1000);
};

const normalizeError = (error: unknown): string => {
  const message = error instanceof Error ? error.message : String(error);
  return message.slice(0, 4000);
};

const ossHostMatches = (host: string): boolean => {
  if (!ossBucket) return false;
  const normalizedHost = host.toLowerCase();
  const bucket = ossBucket.toLowerCase();
  return normalizedHost === bucket || normalizedHost.startsWith(`${bucket}.`);
};

const extractOssObjectKey = (raw: string): string | null => {
  const value = raw.trim();
  if (!value) return null;

  if (value.startsWith('/')) {
    const relative = value.replace(/^\/+/, '');
    return relative ? relative : null;
  }

  if (value.startsWith('http://') || value.startsWith('https://')) {
    try {
      const url = new URL(value);
      if (!ossHostMatches(url.hostname)) return null;
      const objectKey = decodeURIComponent(url.pathname || '').replace(/^\/+/, '');
      return objectKey || null;
    } catch {
      return null;
    }
  }

  return value.includes('/') ? value : null;
};

const unique = (values: Array<string | null | undefined>): string[] =>
  Array.from(new Set(values.map((item) => String(item || '').trim()).filter(Boolean)));

const collectMediaUrls = (user: DeletionUserSnapshot): string[] => {
  const urls = [
    user.avatarUrl,
    user.profileShareQrCodeUrl,
    ...(user.posts || []).flatMap((post) => post.images || []),
    ...(user.eventLiveComments || []).flatMap((comment) => comment.imageUrls || []),
    ...(user.squadMessages || []).map((message) => message.imageUrl),
    ...(user.uploadedPhotos || []).map((photo) => photo.url),
  ];
  return unique(urls);
};

const resolveRequestStatus = (imStatus: string, mediaStatus: string): string => {
  const statuses = [imStatus, mediaStatus];
  if (statuses.some((status) => status === 'failed')) return 'partial_failed';
  if (statuses.every((status) => status === 'completed' || status === 'skipped')) return 'completed';
  return 'queued';
};

export const accountDeletionService = {
  async createOrGetRequest(
    tx: PrismaLike,
    input: {
      user: DeletionUserSnapshot;
      requestedBy?: string;
      requestSource?: AccountDeletionRequestSource;
    }
  ) {
    const existing = await tx.accountDeletionRequest.findFirst({
      where: { userId: input.user.id },
      orderBy: { createdAt: 'desc' },
    });
    if (existing) return existing;

    const mediaUrls = collectMediaUrls(input.user);
    const mediaObjectKeys = unique(mediaUrls.map(extractOssObjectKey));
    const imStatus = tencentIMConfig.enabled ? 'pending' : 'skipped';
    const mediaStatus = mediaObjectKeys.length > 0 ? 'pending' : 'skipped';
    const now = new Date();
    const request = await tx.accountDeletionRequest.create({
      data: {
        userId: input.user.id,
        status: resolveRequestStatus(imStatus, mediaStatus),
        requestedBy: input.requestedBy || 'user',
        requestSource: input.requestSource || 'ios',
        originalEmailHash: stableHash(input.user.email),
        originalPhoneHash: stableHash(input.user.phoneNumber),
        previousAvatarUrl: input.user.avatarUrl,
        previousProfileQrUrl: input.user.profileShareQrCodeUrl,
        imUserId: toTencentIMUserID(input.user.id),
        imStatus,
        imNextRunAt: now,
        mediaStatus,
        mediaNextRunAt: now,
        mediaTargets: {
          objectKeys: mediaObjectKeys,
          sourceUrls: mediaUrls,
        },
        completedAt: resolveRequestStatus(imStatus, mediaStatus) === 'completed' ? now : null,
      },
    });

    if (imStatus === 'pending') {
      await tx.openIMSyncJob.upsert({
        where: { dedupeKey: `account-deletion:im:${input.user.id}` },
        update: {
          status: 'pending',
          nextRunAt: now,
          lastError: null,
          payload: { accountDeletionRequestId: request.id, imUserId: request.imUserId },
        },
        create: {
          dedupeKey: `account-deletion:im:${input.user.id}`,
          jobType: 'account_delete',
          entityType: 'user',
          entityId: input.user.id,
          payload: { accountDeletionRequestId: request.id, imUserId: request.imUserId },
          status: 'pending',
          nextRunAt: now,
        },
      });
    }

    return request;
  },

  async processRequest(requestId: string, options: { force?: boolean } = {}) {
    const request = await prisma.accountDeletionRequest.findUnique({ where: { id: requestId } });
    if (!request) {
      throw new Error('account_deletion_request_not_found');
    }

    const now = new Date();
    let imStatus = request.imStatus;
    let mediaStatus = request.mediaStatus;
    let completedAt = request.completedAt;

    if (
      request.imUserId &&
      ['pending', 'failed'].includes(request.imStatus) &&
      (options.force || request.imNextRunAt <= now)
    ) {
      if (!tencentIMConfig.enabled) {
        imStatus = 'skipped';
        await prisma.accountDeletionRequest.update({
          where: { id: request.id },
          data: { imStatus, imLastError: null },
        });
      } else {
        const attempts = request.imAttempts + 1;
        try {
          await tencentIMClient.post('v4/im_open_login_svc/account_delete', {
            DeleteItem: [{ UserID: request.imUserId }],
          });
          imStatus = 'completed';
          await prisma.$transaction([
            prisma.accountDeletionRequest.update({
              where: { id: request.id },
              data: { imStatus, imAttempts: attempts, imLastError: null },
            }),
            prisma.openIMSyncJob.updateMany({
              where: { dedupeKey: `account-deletion:im:${request.userId}` },
              data: { status: 'completed', attempts, lastError: null, lockedAt: null, lockedBy: null },
            }),
          ]);
        } catch (error) {
          imStatus = 'failed';
          const message = normalizeError(error);
          await prisma.$transaction([
            prisma.accountDeletionRequest.update({
              where: { id: request.id },
              data: { imStatus, imAttempts: attempts, imLastError: message, imNextRunAt: nextRetryAt(attempts) },
            }),
            prisma.openIMSyncJob.updateMany({
              where: { dedupeKey: `account-deletion:im:${request.userId}` },
              data: { status: 'failed', attempts, lastError: message, nextRunAt: nextRetryAt(attempts) },
            }),
          ]);
        }
      }
    }

    const mediaTargets = request.mediaTargets as { objectKeys?: string[] } | null;
    const objectKeys = unique(mediaTargets?.objectKeys || []);
    if (['pending', 'failed'].includes(request.mediaStatus) && (options.force || request.mediaNextRunAt <= now)) {
      if (objectKeys.length === 0) {
        mediaStatus = 'skipped';
        await prisma.accountDeletionRequest.update({
          where: { id: request.id },
          data: { mediaStatus, mediaLastError: null },
        });
      } else if (!ossClient) {
        mediaStatus = 'failed';
        const attempts = request.mediaAttempts + 1;
        await prisma.accountDeletionRequest.update({
          where: { id: request.id },
          data: {
            mediaStatus,
            mediaAttempts: attempts,
            mediaLastError: 'OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET',
            mediaNextRunAt: nextRetryAt(attempts),
          },
        });
      } else {
        const attempts = request.mediaAttempts + 1;
        const results = await Promise.allSettled(objectKeys.map((key) => ossClient.delete(key)));
        const failedKeys = results
          .map((result, index) => (result.status === 'rejected' ? objectKeys[index] : null))
          .filter((item): item is string => Boolean(item));
        if (failedKeys.length === 0) {
          mediaStatus = 'completed';
          await prisma.accountDeletionRequest.update({
            where: { id: request.id },
            data: { mediaStatus, mediaAttempts: attempts, mediaLastError: null },
          });
        } else {
          mediaStatus = 'failed';
          await prisma.accountDeletionRequest.update({
            where: { id: request.id },
            data: {
              mediaStatus,
              mediaAttempts: attempts,
              mediaLastError: `Failed OSS keys: ${failedKeys.join(', ')}`.slice(0, 4000),
              mediaNextRunAt: nextRetryAt(attempts),
            },
          });
        }
      }
    }

    const status = resolveRequestStatus(imStatus, mediaStatus);
    if (status === 'completed') {
      completedAt = completedAt || new Date();
    } else {
      completedAt = null;
    }

    return prisma.accountDeletionRequest.update({
      where: { id: request.id },
      data: { status, completedAt },
    });
  },

  async processDueRequests(limit = 20) {
    const now = new Date();
    const items = await prisma.accountDeletionRequest.findMany({
      where: {
        OR: [
          { imStatus: { in: ['pending', 'failed'] }, imNextRunAt: { lte: now } },
          { mediaStatus: { in: ['pending', 'failed'] }, mediaNextRunAt: { lte: now } },
        ],
      },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      take: Math.max(1, Math.min(limit, 100)),
    });

    const results = [];
    for (const item of items) {
      try {
        results.push({ id: item.id, ok: true, request: await this.processRequest(item.id) });
      } catch (error) {
        results.push({ id: item.id, ok: false, error: normalizeError(error) });
      }
    }
    return results;
  },

  async listRequests(input: { userId?: string; status?: string; limit?: number } = {}) {
    const where: Prisma.AccountDeletionRequestWhereInput = {};
    const userId = input.userId?.trim();
    const status = input.status?.trim();
    if (userId) where.userId = userId;
    if (status) where.status = status;

    return prisma.accountDeletionRequest.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: Math.max(1, Math.min(input.limit || 50, 200)),
      include: {
        user: {
          select: { id: true, username: true, displayName: true, email: true, isActive: true },
        },
      },
    });
  },
};
