import { Prisma, PrismaClient } from '@prisma/client';
import { notificationCenterService } from '../modules/notifications';
import { changeSummaryTextFromPayload } from './content-submission-change-summary.service';
import {
  applyEventTimetableFromSubmission,
  createOrUpdateEventFromSubmission,
} from './content-submission-event.service';
import { createOrUpdateDJFromSubmission } from './content-submission-dj.service';
import { createOrUpdateBrandFromSubmission } from './content-submission-brand.service';
import type { CanonicalLineupSyncProfiling } from './event-lineup-canonical.service';

const prisma = new PrismaClient();

const CONTENT_SUBMISSION_PROCESSING_JOB_TYPE = 'process_submission';
const CONTENT_SUBMISSION_EVENT_TIMETABLE_JOB_TYPE = 'apply_event_timetable';
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
  submissionStatus?: ContentSubmissionTaskStatus;
  createdEntityId?: string | null;
  autoApproved?: boolean;
  resumedFromStatus?: string;
  phase?: string;
  timings?: {
    reviewingTransitionMs: number;
    applyMs: number;
    timetableQueuedMs?: number;
    approvalFinalizeMs: number;
    totalMs: number;
    canonicalSync?: CanonicalLineupSyncProfiling | null;
  };
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
  jobTypeTotals: Record<string, Record<string, number>>;
  queuedCount: number;
  retryingCount: number;
  runningCount: number;
  failedCount: number;
  oldestQueuedAt: Date | null;
  oldestQueuedAgeSeconds: number | null;
  staleRunningCount: number;
  staleLockThresholdSeconds: number;
  latestJobs: Array<{
    id: string;
    submissionId: string;
    jobType: string;
    status: string;
    attempts: number;
    maxAttempts: number;
    lockedBy: string | null;
    availableAt: Date;
    startedAt: Date | null;
    completedAt: Date | null;
    failedAt: Date | null;
    updatedAt: Date;
    lastError: string | null;
    metadata: Prisma.JsonValue | null;
    entityType: string | null;
    submissionTitle: string | null;
    submissionStatus: string | null;
    createdEntityId: string | null;
    phaseBFailure: Prisma.JsonValue | null;
    phaseTimings: Prisma.JsonValue | null;
    retryScheduledAt: string | null;
    lastDurationMs: number | null;
    lastResult: string | null;
  }>;
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

const asJsonObject = (value: Prisma.JsonValue | null | undefined): Prisma.JsonObject => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  return value as Prisma.JsonObject;
};

const withDefinedJsonFields = (
  value: Record<string, Prisma.InputJsonValue | Prisma.JsonValue | undefined>
): Prisma.InputJsonObject => {
  const entries = Object.entries(value).filter(([, fieldValue]) => fieldValue !== undefined);
  return Object.fromEntries(entries) as Prisma.InputJsonObject;
};

const mergeJobMetadata = (
  current: Prisma.JsonValue | null | undefined,
  patch: Record<string, Prisma.InputJsonValue | Prisma.JsonValue | undefined>
): Prisma.InputJsonObject => ({
  ...asJsonObject(current),
  ...withDefinedJsonFields(patch),
});

const mergeSubmissionReviewNotes = (
  current: Prisma.JsonValue | null | undefined,
  patch: Record<string, Prisma.InputJsonValue | Prisma.JsonValue | undefined>
): Prisma.InputJsonObject => ({
  ...asJsonObject(current),
  ...withDefinedJsonFields(patch),
});

const asNullableJsonObject = (
  value: Prisma.JsonValue | null | undefined
): Prisma.JsonObject | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as Prisma.JsonObject;
};

export async function publishContentSubmissionTaskNotification(input: {
  userId: string;
  entityType: string;
  status: ContentSubmissionTaskStatus;
  title: string;
  submissionId: string;
  reason?: string | null;
  reasonCode?: string | null;
  createdEntityId?: string | null;
  titleOverride?: string;
  bodyOverride?: string;
  statusLabelOverride?: string;
  payload?: Prisma.InputJsonObject | Prisma.JsonObject;
  locale?: string;
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
      locale: input.locale || 'zh-CN',
      deeplink: input.status === 'approved' && input.createdEntityId
        ? `/${input.entityType}s/${input.createdEntityId}`
        : `/profile/submissions/${input.submissionId}`,
      metadata: {
        source: 'content_submission_review',
        locale: input.locale || 'zh-CN',
        titleI18n,
        bodyI18n,
        message: localizedBody,
        submissionId: input.submissionId,
        entityType: input.entityType,
        status: input.status,
        reason: input.reason || null,
        reasonCode: input.reasonCode || null,
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
    jobType?: string;
  } = {}
) {
  const db = input.db || prisma;
  const now = new Date();
  const jobType = input.jobType || CONTENT_SUBMISSION_PROCESSING_JOB_TYPE;
  return db.contentSubmissionProcessingJob.upsert({
    where: {
      submissionId_jobType: {
        submissionId,
        jobType,
      },
    },
    create: {
      submissionId,
      jobType,
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

const recordApprovedSubmissionPhaseBFailure = async (
  db: PrismaClient,
  submissionId: string,
  message: string
): Promise<void> => {
  const updated = await db.contentSubmission.update({
    where: { id: submissionId },
    data: {
      reviewNotes: mergeSubmissionReviewNotes(
        (await db.contentSubmission.findUnique({
          where: { id: submissionId },
          select: { reviewNotes: true },
        }))?.reviewNotes,
        {
          phaseBFailure: {
            failedAt: new Date().toISOString(),
            message,
            phase: CONTENT_SUBMISSION_EVENT_TIMETABLE_JOB_TYPE,
          },
        }
      ),
    },
    select: {
      id: true,
      entityType: true,
      title: true,
      submitterId: true,
      payload: true,
      createdEntityId: true,
    },
  });

  await publishContentSubmissionTaskNotification({
    userId: updated.submitterId,
    entityType: updated.entityType,
    status: 'approved',
    title: updated.title,
    submissionId: updated.id,
    createdEntityId: updated.createdEntityId,
    reason: message,
    statusLabelOverride: '主结构已入库，时间表同步失败',
    bodyOverride: `你提交的「${updated.title}」主结构已成功入库，但时间表同步失败，系统会稍后重试。`,
    payload: updated.payload as Prisma.JsonObject,
  });
};

const clearApprovedSubmissionPhaseBFailure = async (
  db: PrismaClient,
  submissionId: string
): Promise<void> => {
  const current = await db.contentSubmission.findUnique({
    where: { id: submissionId },
    select: {
      reviewNotes: true,
    },
  });
  const notes = asJsonObject(current?.reviewNotes);
  if (!Object.prototype.hasOwnProperty.call(notes, 'phaseBFailure')) {
    return;
  }
  const { phaseBFailure: _removed, ...rest } = notes;
  await db.contentSubmission.update({
    where: { id: submissionId },
    data: {
      reviewNotes: Object.keys(rest).length > 0 ? rest : Prisma.JsonNull,
    },
  });
};

const applyEventTimetableForSubmission = async (
  db: PrismaClient,
  submissionId: string
): Promise<ProcessSubmissionResult> => {
  const submission = await db.contentSubmission.findUnique({
    where: { id: submissionId },
    select: {
      id: true,
      entityType: true,
      payload: true,
      submitterId: true,
      createdEntityId: true,
      status: true,
    },
  });

  if (!submission) return { status: 'skipped', reason: 'Submission not found' };
  if (submission.entityType !== 'event') return { status: 'skipped', reason: 'Not an event submission' };
  if (!submission.createdEntityId) return { status: 'skipped', reason: 'Event core entity not created yet' };

  const canonicalSync = await applyEventTimetableFromSubmission(
    db,
    submission.createdEntityId,
    submission.payload as Prisma.JsonObject
  );
  await clearApprovedSubmissionPhaseBFailure(db, submission.id);

  return {
    status: 'succeeded',
    submissionStatus: submission.status as ContentSubmissionTaskStatus,
    createdEntityId: submission.createdEntityId,
    phase: 'event_timetable_applied',
    timings: {
      reviewingTransitionMs: 0,
      applyMs: canonicalSync.totalMs,
      timetableQueuedMs: 0,
      approvalFinalizeMs: 0,
      totalMs: canonicalSync.totalMs,
      canonicalSync,
    },
  };
};

export async function processContentSubmission(
  submissionId: string,
  input: {
    db?: PrismaClient;
    markFailedOnError?: boolean;
    jobId?: string;
    jobType?: string;
  } = {}
): Promise<ProcessSubmissionResult> {
  const processStartedAt = Date.now();
  const db = input.db || prisma;
  const markFailedOnError = input.markFailedOnError ?? true;
  const jobId = input.jobId;
  const jobType = input.jobType || CONTENT_SUBMISSION_PROCESSING_JOB_TYPE;

  if (jobType === CONTENT_SUBMISSION_EVENT_TIMETABLE_JOB_TYPE) {
    try {
      const result = await applyEventTimetableForSubmission(db, submissionId);
      return {
        ...result,
        timings: {
          reviewingTransitionMs: result.timings?.reviewingTransitionMs ?? 0,
          applyMs: result.timings?.applyMs ?? 0,
          timetableQueuedMs: result.timings?.timetableQueuedMs ?? 0,
          approvalFinalizeMs: result.timings?.approvalFinalizeMs ?? 0,
          totalMs: Date.now() - processStartedAt,
          canonicalSync: result.timings?.canonicalSync ?? null,
        },
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Event timetable processing failed';
      await recordApprovedSubmissionPhaseBFailure(db, submissionId, message);
      return {
        status: 'failed',
        reason: message,
        submissionStatus: 'approved',
        autoApproved: false,
        phase: 'event_timetable_failed',
        timings: {
          reviewingTransitionMs: 0,
          applyMs: 0,
          timetableQueuedMs: 0,
          approvalFinalizeMs: 0,
          totalMs: Date.now() - processStartedAt,
        },
      };
    }
  }
  const submission = await db.contentSubmission.findUnique({
    where: { id: submissionId },
    select: {
      id: true,
      status: true,
      entityType: true,
      title: true,
      submitterId: true,
      payload: true,
      reviewedAt: true,
      reviewedBy: true,
      createdEntityId: true,
      submitter: {
        select: {
          role: true,
        },
      },
    },
  });

  if (!submission) return { status: 'skipped', reason: 'Submission not found' };
  const shouldAutoApprove =
    (submission.entityType === 'event' || submission.entityType === 'dj' || submission.entityType === 'brand')
    && (submission.submitter?.role === 'admin' || submission.submitter?.role === 'operator');

  if (submission.status === 'approved') {
    return {
      status: 'succeeded',
      submissionStatus: 'approved',
      createdEntityId: submission.createdEntityId,
      autoApproved: shouldAutoApprove,
      resumedFromStatus: 'approved',
      phase: 'approved',
      timings: {
        reviewingTransitionMs: 0,
        applyMs: 0,
        timetableQueuedMs: 0,
        approvalFinalizeMs: 0,
        totalMs: Date.now() - processStartedAt,
      },
    };
  }

  if (submission.status === 'reviewing' && !shouldAutoApprove) {
    return {
      status: 'succeeded',
      submissionStatus: 'reviewing',
      autoApproved: false,
      resumedFromStatus: 'reviewing',
      phase: 'reviewing',
      timings: {
        reviewingTransitionMs: 0,
        applyMs: 0,
        timetableQueuedMs: 0,
        approvalFinalizeMs: 0,
        totalMs: Date.now() - processStartedAt,
      },
    };
  }

  if (submission.status !== 'processing' && submission.status !== 'pending' && submission.status !== 'reviewing') {
    return { status: 'skipped', reason: `Submission already ${submission.status}` };
  }

  try {
    const payload = submission.payload;
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      throw new Error('Invalid submission payload');
    }

    let reviewingTransitionMs = 0;
    let resumedFromStatus: string | undefined;
    let updated = {
      id: submission.id,
      entityType: submission.entityType,
      title: submission.title,
      submitterId: submission.submitterId,
    };

    const checkpointPhase = async (
      phase: string,
      patch: Record<string, Prisma.InputJsonValue | Prisma.JsonValue | undefined> = {}
    ): Promise<void> => {
      if (!jobId) return;
      await db.contentSubmissionProcessingJob.update({
        where: { id: jobId },
        data: {
          metadata: mergeJobMetadata(
            (await db.contentSubmissionProcessingJob.findUnique({
              where: { id: jobId },
              select: { metadata: true },
            }))?.metadata,
            {
              currentPhase: phase,
              phaseUpdatedAt: new Date().toISOString(),
              ...patch,
            }
          ),
        },
      });
    };

    if (submission.status === 'processing' || submission.status === 'pending') {
      await checkpointPhase('transition_to_reviewing', {
        resumedFromStatus: submission.status,
      });
      const reviewingTransitionStartedAt = Date.now();
      updated = await db.contentSubmission.update({
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
      reviewingTransitionMs = Date.now() - reviewingTransitionStartedAt;
      await checkpointPhase('reviewing_notified', {
        reviewingTransitionMs,
      });

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
    } else {
      resumedFromStatus = submission.status;
      await checkpointPhase('resume_from_reviewing', {
        resumedFromStatus,
      });
    }

    if (shouldAutoApprove) {
      await checkpointPhase('apply_canonical');
      const applyStartedAt = Date.now();
      const created = submission.entityType === 'event'
        ? await createOrUpdateEventFromSubmission(
            db,
            payload as any,
            submission.submitterId,
            { submissionId: submission.id, skipCanonicalApply: true }
          )
        : submission.entityType === 'dj'
          ? await createOrUpdateDJFromSubmission(
              db,
              payload as any,
              submission.submitterId
            )
          : await createOrUpdateBrandFromSubmission(
              db,
              payload as any,
              submission.submitterId,
              { submissionId: submission.id }
            );
      const applyMs = Date.now() - applyStartedAt;
      let timetableQueuedMs = 0;
      if (submission.entityType === 'event') {
        const queuedStartedAt = Date.now();
        await enqueueContentSubmissionProcessingJob(submission.id, {
          db,
          jobType: CONTENT_SUBMISSION_EVENT_TIMETABLE_JOB_TYPE,
          metadata: {
            source: 'event_auto_approval_phase_b',
            createdEntityId: created.id,
          },
        });
        timetableQueuedMs = Date.now() - queuedStartedAt;
      }
      await checkpointPhase('canonical_applied', {
        applyMs,
        timetableQueuedMs,
        createdEntityId: created.id,
      });

      await checkpointPhase('finalize_approved');
      const approvalFinalizeStartedAt = Date.now();
      const approved = await db.contentSubmission.update({
        where: { id: submission.id },
        data: {
          status: 'approved',
          reviewReason: null,
          reviewedAt: submission.reviewedAt || new Date(),
          reviewedBy: submission.reviewedBy || submission.submitterId,
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
      const approvalFinalizeMs = Date.now() - approvalFinalizeStartedAt;
      await checkpointPhase('approved', {
        approvalFinalizeMs,
        createdEntityId: approved.createdEntityId,
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

      return {
        status: 'succeeded',
        submissionStatus: 'approved',
        createdEntityId: approved.createdEntityId,
        autoApproved: true,
        resumedFromStatus,
        phase: 'approved',
        timings: {
          reviewingTransitionMs,
          applyMs,
          timetableQueuedMs,
          approvalFinalizeMs,
          totalMs: Date.now() - processStartedAt,
        },
      };
    }

    return {
      status: 'succeeded',
      submissionStatus: 'reviewing',
      autoApproved: false,
      resumedFromStatus,
      phase: 'reviewing',
      timings: {
        reviewingTransitionMs,
        applyMs: 0,
        timetableQueuedMs: 0,
        approvalFinalizeMs: 0,
        totalMs: Date.now() - processStartedAt,
      },
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Submission processing failed';
    if (!markFailedOnError) {
      throw error;
    }
    await markContentSubmissionFailed(db, submission.id, message);
    return {
      status: 'failed',
      reason: message,
      submissionStatus: 'failed',
      autoApproved: false,
      phase: 'failed',
      timings: {
        reviewingTransitionMs: 0,
        applyMs: 0,
        timetableQueuedMs: 0,
        approvalFinalizeMs: 0,
        totalMs: Date.now() - processStartedAt,
      },
    };
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
        metadata: mergeJobMetadata(candidate.metadata, {
          workerId: options.workerId,
          lastAttemptStartedAt: now.toISOString(),
          lastAttemptFinishedAt: null,
          lastResult: 'running',
          phase: 'processing',
          lastDurationMs: null,
          lastError: null,
          retryScheduledAt: null,
          attemptNumber: candidate.attempts + 1,
        }),
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
    metadata?: Prisma.InputJsonObject;
  } = {}
): Promise<void> => {
  const now = new Date();
  const existing = await db.contentSubmissionProcessingJob.findUnique({
    where: { id: jobId },
    select: {
      metadata: true,
    },
  });
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
      metadata: input.metadata
        ? mergeJobMetadata(existing?.metadata, input.metadata)
        : undefined,
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
    const attemptStartedAt = new Date();
    try {
      const result = await processContentSubmission(job.submissionId, {
        db,
        markFailedOnError: false,
        jobId: job.id,
        jobType: job.jobType,
      });
      const durationMs = Date.now() - startedAt;
      const metadata = withDefinedJsonFields({
        workerId,
        lastAttemptStartedAt: attemptStartedAt.toISOString(),
        lastAttemptFinishedAt: new Date().toISOString(),
        lastResult: result.status,
        phase: result.phase
          ?? (result.submissionStatus === 'approved'
            ? 'approved'
            : result.submissionStatus === 'reviewing'
              ? 'reviewing'
              : result.status),
        lastSubmissionStatus: result.submissionStatus ?? null,
        lastDurationMs: durationMs,
        lastError: result.reason ?? null,
        createdEntityId: result.createdEntityId ?? null,
        autoApproved: result.autoApproved ?? null,
        resumedFromStatus: result.resumedFromStatus ?? null,
        phaseTimings: result.timings
          ? withDefinedJsonFields({
              reviewingTransitionMs: result.timings.reviewingTransitionMs,
              applyMs: result.timings.applyMs,
              timetableQueuedMs: result.timings.timetableQueuedMs ?? null,
              approvalFinalizeMs: result.timings.approvalFinalizeMs,
              totalMs: result.timings.totalMs,
            })
          : null,
        retryScheduledAt: null,
      });
      if (result.status === 'skipped') {
        report.skippedJobs += 1;
        await completeJob(db, job.id, 'cancelled', {
          error: result.reason || null,
          metadata,
        });
      } else {
        report.succeededJobs += 1;
        await completeJob(db, job.id, 'succeeded', {
          metadata,
        });
      }
      console.log('[content-submission-worker] processed', {
        workerId,
        jobId: job.id,
        submissionId: job.submissionId,
        result: result.status,
        submissionStatus: result.submissionStatus,
        durationMs,
        phaseTimings: result.timings,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Submission processing failed';
      const retryable = true;
      const shouldRetry = retryable && job.attempts < job.maxAttempts;
      const durationMs = Date.now() - startedAt;
      const retryAt = shouldRetry ? new Date(Date.now() + retryDelayMs(job.attempts)) : undefined;
      const metadata = withDefinedJsonFields({
        workerId,
        lastAttemptStartedAt: attemptStartedAt.toISOString(),
        lastAttemptFinishedAt: new Date().toISOString(),
        lastResult: shouldRetry ? 'retrying' : 'failed',
        phase: shouldRetry ? 'retrying' : 'failed',
        lastSubmissionStatus: shouldRetry ? 'processing' : 'failed',
        lastDurationMs: durationMs,
        lastError: message,
        retryable,
        conflictDetails: null,
        retryScheduledAt: retryAt?.toISOString() ?? null,
      });
      if (shouldRetry) {
        report.retryingJobs += 1;
        await completeJob(db, job.id, 'retrying', {
          error: message,
          availableAt: retryAt,
          metadata,
        });
      } else {
        report.failedJobs += 1;
        await markContentSubmissionFailed(db, job.submissionId, message);
        await completeJob(db, job.id, 'failed', {
          error: message,
          metadata,
        });
      }
      errors.push(`job=${job.id} submission=${job.submissionId} error=${message}`);
      console.error('[content-submission-worker] failed', {
        workerId,
        jobId: job.id,
        submissionId: job.submissionId,
        attempts: job.attempts,
        maxAttempts: job.maxAttempts,
        retryable,
        retrying: shouldRetry,
        durationMs,
        error: message,
        retryAt: retryAt?.toISOString() ?? null,
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

  const [grouped, oldestQueued, staleRunningCount, latestJobs] = await Promise.all([
    db.contentSubmissionProcessingJob.groupBy({
      by: ['jobType', 'status'],
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
    db.contentSubmissionProcessingJob.findMany({
      orderBy: [
        { updatedAt: 'desc' },
        { createdAt: 'desc' },
      ],
      take: 5,
      select: {
        id: true,
        submissionId: true,
        jobType: true,
        status: true,
        attempts: true,
        maxAttempts: true,
        lockedBy: true,
        availableAt: true,
        startedAt: true,
        completedAt: true,
        failedAt: true,
        updatedAt: true,
        lastError: true,
        metadata: true,
        submission: {
          select: {
            entityType: true,
            title: true,
            status: true,
            createdEntityId: true,
            reviewNotes: true,
          },
        },
      },
    }),
  ]);

  const totals = grouped.reduce<Record<string, number>>((acc, row) => {
    acc[row.status] = row._count._all;
    return acc;
  }, {});
  const jobTypeTotals = grouped.reduce<Record<string, Record<string, number>>>((acc, row) => {
    const jobType = row.jobType;
    const bucket = acc[jobType] || {};
    bucket[row.status] = row._count._all;
    acc[jobType] = bucket;
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
    jobTypeTotals,
    latestJobs: latestJobs.map((job) => {
      const metadata = asNullableJsonObject(job.metadata);
      const phaseTimings = asNullableJsonObject(metadata?.phaseTimings as Prisma.JsonValue | null | undefined);
      const phaseBFailure = asNullableJsonObject(job.submission.reviewNotes)?.phaseBFailure ?? null;
      return {
        id: job.id,
        submissionId: job.submissionId,
        jobType: job.jobType,
        status: job.status,
        attempts: job.attempts,
        maxAttempts: job.maxAttempts,
        lockedBy: job.lockedBy,
        availableAt: job.availableAt,
        startedAt: job.startedAt,
        completedAt: job.completedAt,
        failedAt: job.failedAt,
        updatedAt: job.updatedAt,
        lastError: job.lastError,
        metadata: job.metadata,
        entityType: job.submission.entityType,
        submissionTitle: job.submission.title,
        submissionStatus: job.submission.status,
        createdEntityId: job.submission.createdEntityId,
        phaseBFailure,
        phaseTimings,
        retryScheduledAt: typeof metadata?.retryScheduledAt === 'string' ? metadata.retryScheduledAt : null,
        lastDurationMs: typeof metadata?.lastDurationMs === 'number' ? metadata.lastDurationMs : null,
        lastResult: typeof metadata?.lastResult === 'string' ? metadata.lastResult : null,
      };
    }),
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
