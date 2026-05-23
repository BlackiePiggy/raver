import { Prisma, PrismaClient } from '@prisma/client';
import { notificationCenterService } from '../modules/notifications';
import { changeSummaryTextFromPayload } from './content-submission-change-summary.service';
import { createOrUpdateEventFromSubmission } from './content-submission-event.service';

const prisma = new PrismaClient();

const CONTENT_SUBMISSION_PROCESSING_JOB_TYPE = 'process_submission';
const DEFAULT_WORKER_BATCH_SIZE = 1;
const DEFAULT_WORKER_STALE_LOCK_MS = 15 * 60 * 1000;

export type ContentSubmissionTaskStatus =
  | 'processing'
  | 'reviewing'
  | 'approved'
  | 'rejected'
  | 'failed';

export type ContentSubmissionProcessingJobStatus =
  | 'queued'
  | 'running'
  | 'retrying'
  | 'succeeded'
  | 'failed'
  | 'cancelled';

type ProcessSubmissionResult = {
  status: 'succeeded' | 'skipped' | 'failed';
  reason?: string;
};

type RunWorkerOnceOptions = {
  batchSize?: number;
  workerId?: string;
  staleLockMs?: number;
};

type RunWorkerOnceReport = {
  scannedJobs: number;
  processedJobs: number;
  succeededJobs: number;
  failedJobs: number;
  retryingJobs: number;
  skippedJobs: number;
  errors: string[];
};

export type ContentSubmissionProcessingQueueStatus = {
  checkedAt: Date;
  status: 'healthy' | 'degraded' | 'critical';
  alertReasons: string[];
  totals: Record<string, number>;
  queuedCount: number;
  retryingCount: number;
  runningCount: number;
  failedCount: number;
  oldestQueuedAt: Date | null;
  oldestQueuedAgeSeconds: number | null;
  staleRunningCount: number;
  staleLockThresholdSeconds: number;
};

const typeLabelMap: Record<string, string> = {
  event: '活动',
  dj: 'DJ',
  news: '资讯',
  set: 'Set',
  brand: '品牌',
  label: '厂牌',
  id: 'ID',
  rating: '打分',
};

const statusLabelMap = {
  processing: { zh: '处理中', en: 'processing', ja: '処理中' },
  reviewing: { zh: '审核中', en: 'in review', ja: '審査中' },
  approved: { zh: '已入库', en: 'approved', ja: '入庫済み' },
  rejected: { zh: '未通过', en: 'rejected', ja: '未承認' },
  failed: { zh: '处理失败', en: 'failed', ja: '処理失敗' },
} as const;

const parsePositiveIntegerEnv = (name: string, fallback: number): number => {
  const parsed = Number(process.env[name]);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : fallback;
};

const buildWorkerId = (): string =>
  `${process.env.HOSTNAME || 'local'}:${process.pid}:${Date.now()}`;

const retryDelayMs = (attempts: number): number => {
  if (attempts <= 1) return 60_000;
  if (attempts <= 2) return 5 * 60_000;
  return 15 * 60_000;
};

const sleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

export async function publishContentSubmissionTaskNotification(input: {
  userId: string;
  entityType: string;
  status: ContentSubmissionTaskStatus;
  title: string;
  submissionId: string;
  reason?: string | null;
  createdEntityId?: string | null;
  titleOverride?: string;
  bodyOverride?: string;
  statusLabelOverride?: string;
  payload?: Prisma.InputJsonObject | Prisma.JsonObject;
}) {
  const typeLabel = typeLabelMap[input.entityType] || '内容';
  const statusLabels = statusLabelMap[input.status];
  const changeSummary = changeSummaryTextFromPayload(input.payload);
  const titleI18n = {
    zh: `${typeLabel}提交${statusLabels.zh}`,
    en: `${typeLabel} submission ${statusLabels.en}`,
    ja: `${typeLabel}の投稿${statusLabels.ja}`,
  };
  const bodyI18n = {
    zh:
      input.status === 'processing'
        ? `你提交的「${input.title}」已进入处理队列。`
        : input.status === 'reviewing'
          ? `你提交的「${input.title}」已完成处理，正在审核中。`
          : input.status === 'approved'
            ? `你提交的「${input.title}」已审核通过，内容已入库。`
            : input.status === 'failed'
              ? `你提交的「${input.title}」处理失败：${input.reason || '请稍后重试或联系支持。'}`
              : `你提交的「${input.title}」未通过审核：${input.reason || '请补充更准确的信息后重新提交。'}`,
    en:
      input.status === 'processing'
        ? `Your submission "${input.title}" has entered the processing queue.`
        : input.status === 'reviewing'
          ? `Your submission "${input.title}" finished processing and is now under review.`
          : input.status === 'approved'
            ? `Your submission "${input.title}" was approved and added to Raver.`
            : input.status === 'failed'
              ? `Your submission "${input.title}" failed during processing: ${input.reason || 'Please retry later or contact support.'}`
              : `Your submission "${input.title}" was rejected: ${input.reason || 'Please add more accurate details and submit again.'}`,
    ja:
      input.status === 'processing'
        ? `投稿「${input.title}」は処理キューに入りました。`
        : input.status === 'reviewing'
          ? `投稿「${input.title}」の処理が完了し、現在審査中です。`
          : input.status === 'approved'
            ? `投稿「${input.title}」が承認され、Raver に追加されました。`
            : input.status === 'failed'
              ? `投稿「${input.title}」の処理に失敗しました：${input.reason || '後でもう一度お試しいただくか、サポートへお問い合わせください。'}`
              : `投稿「${input.title}」は承認されませんでした：${input.reason || 'より正確な情報を追加して再送信してください。'}`,
  };
  if (changeSummary) {
    bodyI18n.zh = `${bodyI18n.zh}\n变更摘要：${changeSummary}`;
    bodyI18n.en = `${bodyI18n.en}\nChange summary: ${changeSummary}`;
    bodyI18n.ja = `${bodyI18n.ja}\n変更概要：${changeSummary}`;
  }

  const localizedBody = input.bodyOverride || bodyI18n.zh;
  await notificationCenterService.publish({
    category: 'content_review',
    targets: [{ userId: input.userId }],
    channels: ['in_app', 'apns'],
    dedupeKey: `content_submission:${input.submissionId}:${input.status}`,
    payload: {
      title: input.titleOverride || titleI18n.zh,
      body: localizedBody,
      deeplink: input.status === 'approved' && input.createdEntityId
        ? `/${input.entityType}s/${input.createdEntityId}`
        : `/profile/submissions/${input.submissionId}`,
      metadata: {
        source: 'content_submission_review',
        titleI18n,
        bodyI18n,
        message: localizedBody,
        submissionId: input.submissionId,
        entityType: input.entityType,
        status: input.status,
        reason: input.reason || null,
        reasonCode: input.reason || null,
        createdEntityId: input.createdEntityId || null,
        typeLabel,
        statusLabel: input.statusLabelOverride || statusLabels.zh,
      },
    },
  });
}

export async function enqueueContentSubmissionProcessingJob(
  submissionId: string,
  input: {
    db?: PrismaClient;
    priority?: number;
    metadata?: Prisma.InputJsonValue;
  } = {}
) {
  const db = input.db || prisma;
  const now = new Date();
  return db.contentSubmissionProcessingJob.upsert({
    where: {
      submissionId_jobType: {
        submissionId,
        jobType: CONTENT_SUBMISSION_PROCESSING_JOB_TYPE,
      },
    },
    create: {
      submissionId,
      jobType: CONTENT_SUBMISSION_PROCESSING_JOB_TYPE,
      status: 'queued',
      priority: input.priority ?? 0,
      availableAt: now,
      metadata: input.metadata,
    },
    update: {
      status: 'queued',
      priority: input.priority ?? 0,
      lockedBy: null,
      lockedAt: null,
      availableAt: now,
      completedAt: null,
      failedAt: null,
      lastError: null,
      metadata: input.metadata,
    },
  });
}

const markContentSubmissionFailed = async (
  db: PrismaClient,
  submissionId: string,
  message: string
): Promise<void> => {
  const failed = await db.contentSubmission.update({
    where: { id: submissionId },
    data: {
      status: 'failed',
      reviewReason: message,
    },
    select: {
      id: true,
      entityType: true,
      title: true,
      submitterId: true,
      payload: true,
    },
  });

  await publishContentSubmissionTaskNotification({
    userId: failed.submitterId,
    entityType: failed.entityType,
    status: 'failed',
    title: failed.title,
    submissionId: failed.id,
    reason: message,
    payload: failed.payload as Prisma.JsonObject,
  });
};

export async function processContentSubmission(
  submissionId: string,
  input: {
    db?: PrismaClient;
    markFailedOnError?: boolean;
  } = {}
): Promise<ProcessSubmissionResult> {
  const db = input.db || prisma;
  const markFailedOnError = input.markFailedOnError ?? true;
  const submission = await db.contentSubmission.findUnique({
    where: { id: submissionId },
    select: {
      id: true,
      status: true,
      entityType: true,
      title: true,
      submitterId: true,
      payload: true,
      submitter: {
        select: {
          role: true,
        },
      },
    },
  });

  if (!submission) return { status: 'skipped', reason: 'Submission not found' };
  if (submission.status !== 'processing' && submission.status !== 'pending') {
    return { status: 'skipped', reason: `Submission already ${submission.status}` };
  }

  try {
    const payload = submission.payload;
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      throw new Error('Invalid submission payload');
    }

    const updated = await db.contentSubmission.update({
      where: { id: submission.id },
      data: {
        status: 'reviewing',
        reviewReason: null,
      },
      select: {
        id: true,
        entityType: true,
        title: true,
        submitterId: true,
      },
    });

    const shouldAutoApprove =
      submission.entityType === 'event'
      && (submission.submitter?.role === 'admin' || submission.submitter?.role === 'operator');

    await publishContentSubmissionTaskNotification({
      userId: updated.submitterId,
      entityType: updated.entityType,
      status: 'reviewing',
      title: updated.title,
      submissionId: updated.id,
      payload: payload as Prisma.JsonObject,
      ...(shouldAutoApprove
        ? {
            titleOverride: `${typeLabelMap[updated.entityType] || '内容'}处理完成`,
            bodyOverride: `你提交的「${updated.title}」已完成处理，系统正在自动入库。`,
            statusLabelOverride: '处理完成',
          }
        : {}),
    });

    if (shouldAutoApprove) {
      const created = await createOrUpdateEventFromSubmission(
        db,
        payload as any,
        submission.submitterId
      );

      const approved = await db.contentSubmission.update({
        where: { id: submission.id },
        data: {
          status: 'approved',
          reviewReason: null,
          reviewedAt: new Date(),
          reviewedBy: submission.submitterId,
          createdEntityId: created.id,
        },
        select: {
          id: true,
          entityType: true,
          title: true,
          submitterId: true,
          createdEntityId: true,
        },
      });

      await publishContentSubmissionTaskNotification({
        userId: approved.submitterId,
        entityType: approved.entityType,
        status: 'approved',
        title: approved.title,
        submissionId: approved.id,
        createdEntityId: approved.createdEntityId,
        payload: payload as Prisma.JsonObject,
      });
    }

    return { status: 'succeeded' };
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Submission processing failed';
    if (!markFailedOnError) {
      throw error;
    }
    await markContentSubmissionFailed(db, submission.id, message);
    return { status: 'failed', reason: message };
  }
}

const resetStaleRunningJobs = async (
  db: PrismaClient,
  staleLockMs: number
): Promise<number> => {
  const staleBefore = new Date(Date.now() - staleLockMs);
  const result = await db.contentSubmissionProcessingJob.updateMany({
    where: {
      status: 'running',
      lockedAt: {
        lt: staleBefore,
      },
    },
    data: {
      status: 'retrying',
      lockedBy: null,
      lockedAt: null,
      availableAt: new Date(),
      lastError: 'Worker lock expired and was reset',
    },
  });
  return result.count;
};

const claimContentSubmissionProcessingJobs = async (
  db: PrismaClient,
  options: Required<Pick<RunWorkerOnceOptions, 'batchSize' | 'workerId'>>
) => {
  const now = new Date();
  const candidates = await db.contentSubmissionProcessingJob.findMany({
    where: {
      status: {
        in: ['queued', 'retrying'],
      },
      availableAt: {
        lte: now,
      },
    },
    orderBy: [
      { priority: 'desc' },
      { availableAt: 'asc' },
      { createdAt: 'asc' },
    ],
    take: options.batchSize,
  });

  const claimed = [];
  for (const candidate of candidates) {
    const updated = await db.contentSubmissionProcessingJob.updateMany({
      where: {
        id: candidate.id,
        status: {
          in: ['queued', 'retrying'],
        },
      },
      data: {
        status: 'running',
        lockedBy: options.workerId,
        lockedAt: now,
        startedAt: candidate.startedAt || now,
        attempts: {
          increment: 1,
        },
      },
    });

    if (updated.count !== 1) continue;
    const row = await db.contentSubmissionProcessingJob.findUnique({
      where: { id: candidate.id },
    });
    if (row) claimed.push(row);
  }

  return claimed;
};

const completeJob = async (
  db: PrismaClient,
  jobId: string,
  status: ContentSubmissionProcessingJobStatus,
  input: {
    error?: string | null;
    availableAt?: Date;
  } = {}
): Promise<void> => {
  const now = new Date();
  await db.contentSubmissionProcessingJob.update({
    where: { id: jobId },
    data: {
      status,
      lockedBy: null,
      lockedAt: null,
      availableAt: input.availableAt,
      completedAt: status === 'succeeded' || status === 'cancelled' ? now : undefined,
      failedAt: status === 'failed' ? now : undefined,
      lastError: input.error || null,
    },
  });
};

export async function runContentSubmissionProcessingWorkerOnce(
  db: PrismaClient = prisma,
  options: RunWorkerOnceOptions = {}
): Promise<RunWorkerOnceReport> {
  const batchSize = options.batchSize || parsePositiveIntegerEnv(
    'CONTENT_SUBMISSION_WORKER_BATCH_SIZE',
    DEFAULT_WORKER_BATCH_SIZE
  );
  const workerId = options.workerId || buildWorkerId();
  const staleLockMs = options.staleLockMs || parsePositiveIntegerEnv(
    'CONTENT_SUBMISSION_WORKER_STALE_LOCK_MS',
    DEFAULT_WORKER_STALE_LOCK_MS
  );

  const errors: string[] = [];
  await resetStaleRunningJobs(db, staleLockMs);
  const jobs = await claimContentSubmissionProcessingJobs(db, { batchSize, workerId });
  const report: RunWorkerOnceReport = {
    scannedJobs: jobs.length,
    processedJobs: 0,
    succeededJobs: 0,
    failedJobs: 0,
    retryingJobs: 0,
    skippedJobs: 0,
    errors,
  };

  for (const job of jobs) {
    report.processedJobs += 1;
    const startedAt = Date.now();
    try {
      const result = await processContentSubmission(job.submissionId, {
        db,
        markFailedOnError: false,
      });
      if (result.status === 'skipped') {
        report.skippedJobs += 1;
        await completeJob(db, job.id, 'cancelled', {
          error: result.reason || null,
        });
      } else {
        report.succeededJobs += 1;
        await completeJob(db, job.id, 'succeeded');
      }
      console.log('[content-submission-worker] processed', {
        workerId,
        jobId: job.id,
        submissionId: job.submissionId,
        result: result.status,
        durationMs: Date.now() - startedAt,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Submission processing failed';
      const shouldRetry = job.attempts < job.maxAttempts;
      if (shouldRetry) {
        report.retryingJobs += 1;
        await completeJob(db, job.id, 'retrying', {
          error: message,
          availableAt: new Date(Date.now() + retryDelayMs(job.attempts)),
        });
      } else {
        report.failedJobs += 1;
        await markContentSubmissionFailed(db, job.submissionId, message);
        await completeJob(db, job.id, 'failed', {
          error: message,
        });
      }
      errors.push(`job=${job.id} submission=${job.submissionId} error=${message}`);
      console.error('[content-submission-worker] failed', {
        workerId,
        jobId: job.id,
        submissionId: job.submissionId,
        attempts: job.attempts,
        maxAttempts: job.maxAttempts,
        retrying: shouldRetry,
        durationMs: Date.now() - startedAt,
        error: message,
      });
    }
  }

  return report;
}

export async function getContentSubmissionProcessingQueueStatus(
  db: PrismaClient = prisma,
  input: {
    staleLockMs?: number;
    queuedAgeWarnSeconds?: number;
    queuedAgeCriticalSeconds?: number;
  } = {}
): Promise<ContentSubmissionProcessingQueueStatus> {
  const checkedAt = new Date();
  const staleLockMs = input.staleLockMs || parsePositiveIntegerEnv(
    'CONTENT_SUBMISSION_WORKER_STALE_LOCK_MS',
    DEFAULT_WORKER_STALE_LOCK_MS
  );
  const queuedAgeWarnSeconds = input.queuedAgeWarnSeconds || parsePositiveIntegerEnv(
    'CONTENT_SUBMISSION_WORKER_QUEUE_WARN_SECONDS',
    10 * 60
  );
  const queuedAgeCriticalSeconds = input.queuedAgeCriticalSeconds || parsePositiveIntegerEnv(
    'CONTENT_SUBMISSION_WORKER_QUEUE_CRITICAL_SECONDS',
    30 * 60
  );

  const [grouped, oldestQueued, staleRunningCount] = await Promise.all([
    db.contentSubmissionProcessingJob.groupBy({
      by: ['status'],
      _count: {
        _all: true,
      },
    }),
    db.contentSubmissionProcessingJob.findFirst({
      where: {
        status: {
          in: ['queued', 'retrying'],
        },
      },
      orderBy: {
        availableAt: 'asc',
      },
      select: {
        availableAt: true,
      },
    }),
    db.contentSubmissionProcessingJob.count({
      where: {
        status: 'running',
        lockedAt: {
          lt: new Date(checkedAt.getTime() - staleLockMs),
        },
      },
    }),
  ]);

  const totals = grouped.reduce<Record<string, number>>((acc, row) => {
    acc[row.status] = row._count._all;
    return acc;
  }, {});
  const oldestQueuedAt = oldestQueued?.availableAt ?? null;
  const oldestQueuedAgeSeconds = oldestQueuedAt
    ? Math.max(0, Math.floor((checkedAt.getTime() - oldestQueuedAt.getTime()) / 1000))
    : null;
  const alertReasons: string[] = [];
  if (staleRunningCount > 0) {
    alertReasons.push('content_submission_worker.stale_running_jobs');
  }
  if (oldestQueuedAgeSeconds !== null && oldestQueuedAgeSeconds >= queuedAgeWarnSeconds) {
    alertReasons.push('content_submission_worker.queue_age_high');
  }
  if ((totals.failed || 0) > 0) {
    alertReasons.push('content_submission_worker.failed_jobs_present');
  }

  const status: ContentSubmissionProcessingQueueStatus['status'] =
    staleRunningCount > 0
    || (oldestQueuedAgeSeconds !== null && oldestQueuedAgeSeconds >= queuedAgeCriticalSeconds)
      ? 'critical'
      : alertReasons.length > 0
        ? 'degraded'
        : 'healthy';

  return {
    checkedAt,
    status,
    alertReasons,
    totals,
    queuedCount: totals.queued || 0,
    retryingCount: totals.retrying || 0,
    runningCount: totals.running || 0,
    failedCount: totals.failed || 0,
    oldestQueuedAt,
    oldestQueuedAgeSeconds,
    staleRunningCount,
    staleLockThresholdSeconds: Math.floor(staleLockMs / 1000),
  };
}

export async function startContentSubmissionProcessingWorkerLoop(
  db: PrismaClient = prisma,
  options: RunWorkerOnceOptions & { intervalMs?: number } = {}
): Promise<void> {
  const intervalMs = options.intervalMs || parsePositiveIntegerEnv(
    'CONTENT_SUBMISSION_WORKER_INTERVAL_MS',
    2000
  );

  console.log('[content-submission-worker] started', {
    intervalMs,
    batchSize: options.batchSize,
  });

  for (;;) {
    await runContentSubmissionProcessingWorkerOnce(db, options);
    await sleep(intervalMs);
  }
}

export async function scheduleContentSubmissionProcessingBestEffort(submissionId: string) {
  return enqueueContentSubmissionProcessingJob(submissionId);
}
