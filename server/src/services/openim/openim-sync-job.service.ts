import { PrismaClient } from '@prisma/client';
import { openIMConfig } from './openim-config';
import { openIMUserService } from './openim-user.service';

const prisma = new PrismaClient();

const OPENIM_SYNC_JOB_TYPE_USER_PROFILE = 'user_profile_sync';
const OPENIM_SYNC_ENTITY_TYPE_USER = 'user';

const STATUS_PENDING = 'pending';
const STATUS_PROCESSING = 'processing';
const STATUS_RETRYING = 'retrying';
const STATUS_SUCCEEDED = 'succeeded';
const STATUS_FAILED = 'failed';

type OpenIMSyncQueueResult = {
  queued: boolean;
  jobId?: string;
  reason?: string;
};

const sanitizeError = (error: unknown): string => {
  const message = error instanceof Error ? error.message : String(error);
  const normalized = message.trim();
  if (!normalized) return 'unknown error';
  return normalized.length > 1800 ? `${normalized.slice(0, 1800)}...` : normalized;
};

const getWorkerId = (): string => {
  return `openim-sync-worker-${process.pid}`;
};

const getBackoffMs = (attempt: number): number => {
  const exponent = Math.max(1, Math.min(8, attempt));
  const base = Math.pow(2, exponent) * 1000;
  return Math.min(base, 5 * 60 * 1000);
};

export const openIMSyncJobService = {
  workerTimer: null as NodeJS.Timeout | null,
  isRunningOnce: false,

  async queueUserProfileSync(
    userId: string,
    options?: { reason?: string; runAfterMs?: number; maxAttempts?: number }
  ): Promise<OpenIMSyncQueueResult> {
    if (!openIMConfig.enabled) {
      return { queued: false, reason: 'openim-disabled' };
    }

    const trimmedUserId = userId.trim();
    if (!trimmedUserId) {
      return { queued: false, reason: 'empty-user-id' };
    }

    const dedupeKey = `openim:user-profile-sync:${trimmedUserId}`;
    const now = new Date();
    const runAfterMs = Math.max(0, options?.runAfterMs ?? 0);
    const maxAttempts = Math.max(1, options?.maxAttempts ?? openIMConfig.syncDefaultMaxAttempts);
    const nextRunAt = new Date(now.getTime() + runAfterMs);

    const payload = {
      reason: options?.reason || 'unknown',
      requestedAt: now.toISOString(),
    };

    const existing = await prisma.openIMSyncJob.findUnique({
      where: { dedupeKey },
      select: { id: true, status: true },
    });

    if (!existing) {
      const created = await prisma.openIMSyncJob.create({
        data: {
          dedupeKey,
          jobType: OPENIM_SYNC_JOB_TYPE_USER_PROFILE,
          entityType: OPENIM_SYNC_ENTITY_TYPE_USER,
          entityId: trimmedUserId,
          payload,
          status: STATUS_PENDING,
          attempts: 0,
          maxAttempts,
          nextRunAt,
          lockedAt: null,
          lockedBy: null,
          lastError: null,
        },
        select: { id: true },
      });
      return { queued: true, jobId: created.id };
    }

    if (existing.status === STATUS_PROCESSING) {
      return { queued: false, jobId: existing.id, reason: 'already-processing' };
    }

    const updated = await prisma.openIMSyncJob.update({
      where: { dedupeKey },
      data: {
        jobType: OPENIM_SYNC_JOB_TYPE_USER_PROFILE,
        entityType: OPENIM_SYNC_ENTITY_TYPE_USER,
        entityId: trimmedUserId,
        payload,
        status: STATUS_PENDING,
        attempts: 0,
        maxAttempts,
        nextRunAt,
        lockedAt: null,
        lockedBy: null,
        lastError: null,
      },
      select: { id: true },
    });

    return { queued: true, jobId: updated.id };
  },

  async runWorkerOnce(limit = openIMConfig.syncWorkerBatchSize): Promise<number> {
    if (!openIMConfig.enabled || !openIMConfig.syncWorkerEnabled) {
      return 0;
    }

    if (this.isRunningOnce) {
      return 0;
    }

    this.isRunningOnce = true;

    try {
      const now = new Date();
      const lockExpiresAt = new Date(now.getTime() - Math.max(1, openIMConfig.syncLockTimeoutMs));
      const workerId = getWorkerId();
      const batchSize = Math.max(1, limit);

      const candidates = await prisma.openIMSyncJob.findMany({
        where: {
          status: { in: [STATUS_PENDING, STATUS_RETRYING] },
          nextRunAt: { lte: now },
        },
        orderBy: [{ nextRunAt: 'asc' }, { createdAt: 'asc' }],
        take: batchSize,
      });

      if (candidates.length === 0) {
        return 0;
      }

      let processed = 0;
      for (const candidate of candidates) {
        const claimed = await prisma.openIMSyncJob.updateMany({
          where: {
            id: candidate.id,
            status: { in: [STATUS_PENDING, STATUS_RETRYING] },
            nextRunAt: { lte: now },
            OR: [{ lockedAt: null }, { lockedAt: { lt: lockExpiresAt } }],
          },
          data: {
            status: STATUS_PROCESSING,
            lockedAt: now,
            lockedBy: workerId,
          },
        });

        if (claimed.count !== 1) {
          continue;
        }

        try {
          await this.processJob(candidate.jobType, candidate.entityId);
          await prisma.openIMSyncJob.updateMany({
            where: {
              id: candidate.id,
              status: STATUS_PROCESSING,
              lockedBy: workerId,
            },
            data: {
              status: STATUS_SUCCEEDED,
              attempts: candidate.attempts + 1,
              lastError: null,
              lockedAt: null,
              lockedBy: null,
              nextRunAt: new Date(),
            },
          });
          processed += 1;
        } catch (error) {
          const nextAttempts = candidate.attempts + 1;
          const exhausted = nextAttempts >= candidate.maxAttempts;
          const retryDelay = getBackoffMs(nextAttempts);
          const nextRunAt = new Date(Date.now() + retryDelay);

          await prisma.openIMSyncJob.updateMany({
            where: {
              id: candidate.id,
              status: STATUS_PROCESSING,
              lockedBy: workerId,
            },
            data: {
              status: exhausted ? STATUS_FAILED : STATUS_RETRYING,
              attempts: nextAttempts,
              lastError: sanitizeError(error),
              lockedAt: null,
              lockedBy: null,
              nextRunAt: exhausted ? new Date() : nextRunAt,
            },
          });
          processed += 1;
        }
      }

      return processed;
    } finally {
      this.isRunningOnce = false;
    }
  },

  startWorker(): void {
    if (!openIMConfig.enabled || !openIMConfig.syncWorkerEnabled) {
      return;
    }

    if (this.workerTimer) {
      return;
    }

    const intervalMs = Math.max(500, openIMConfig.syncWorkerIntervalMs);
    this.workerTimer = setInterval(() => {
      void this.runWorkerOnce().catch((error) => {
        console.error('[openim-sync] worker run failed', error);
      });
    }, intervalMs);

    void this.runWorkerOnce().catch((error) => {
      console.error('[openim-sync] worker bootstrap run failed', error);
    });

    console.log(`[openim-sync] worker started interval=${intervalMs}ms batch=${openIMConfig.syncWorkerBatchSize}`);
  },

  stopWorker(): void {
    if (!this.workerTimer) {
      return;
    }
    clearInterval(this.workerTimer);
    this.workerTimer = null;
    console.log('[openim-sync] worker stopped');
  },

  async processJob(jobType: string, entityId: string): Promise<void> {
    if (jobType === OPENIM_SYNC_JOB_TYPE_USER_PROFILE) {
      await openIMUserService.syncUserById(entityId);
      return;
    }
    throw new Error(`Unsupported OpenIM sync job type: ${jobType}`);
  },
};
