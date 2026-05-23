import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient({
  datasources: process.env.WORKER_DATABASE_URL
    ? {
        db: {
          url: process.env.WORKER_DATABASE_URL,
        },
      }
    : undefined,
});

const cleanText = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed || null;
};

const main = async (): Promise<void> => {
  const eventId = cleanText(process.argv[2]);
  const apply = process.argv.includes('--apply');
  if (!eventId) {
    throw new Error('Usage: pnpm content-submissions:event-edit:cleanup <eventId> [--apply]');
  }

  const candidates = await prisma.contentSubmission.findMany({
    where: {
      entityType: 'event',
      status: { in: ['pending', 'processing', 'reviewing'] },
      OR: [
        { payload: { path: ['targetEventId'], equals: eventId } },
        { payload: { path: ['editTargetEventId'], equals: eventId } },
      ],
    },
    orderBy: [{ createdAt: 'asc' }],
    include: {
      processingJobs: {
        orderBy: [{ createdAt: 'asc' }],
      },
    },
  });

  const safeToCancel = candidates.filter((submission) => {
    if (submission.processingJobs.length === 0) return true;
    return submission.processingJobs.every((job) =>
      ['cancelled', 'failed', 'succeeded'].includes(job.status)
    );
  });

  const unsafe = candidates.filter((submission) =>
    !safeToCancel.some((candidate) => candidate.id === submission.id)
  );

  if (apply && safeToCancel.length > 0) {
    const ids = safeToCancel.map((submission) => submission.id);
    await prisma.$transaction([
      prisma.contentSubmission.updateMany({
        where: { id: { in: ids } },
        data: {
          status: 'cancelled',
          reviewReason: '历史编辑任务已无可执行 job，清理为 cancelled',
        },
      }),
      prisma.contentSubmissionProcessingJob.updateMany({
        where: {
          submissionId: { in: ids },
          status: { in: ['queued', 'retrying', 'running'] },
        },
        data: {
          status: 'cancelled',
          lockedBy: null,
          lockedAt: null,
          completedAt: new Date(),
          lastError: 'Cancelled by event edit cleanup',
        },
      }),
    ]);
  }

  console.log(JSON.stringify({
    eventId,
    mode: apply ? 'apply' : 'dry-run',
    candidateCount: candidates.length,
    safeToCancelCount: safeToCancel.length,
    unsafeActiveCount: unsafe.length,
    safeToCancel: safeToCancel.map((submission) => ({
      id: submission.id,
      status: submission.status,
      title: submission.title,
      createdAt: submission.createdAt.toISOString(),
      updatedAt: submission.updatedAt.toISOString(),
      jobs: submission.processingJobs.map((job) => ({
        id: job.id,
        status: job.status,
        attempts: job.attempts,
        lastError: job.lastError,
      })),
    })),
    unsafeActive: unsafe.map((submission) => ({
      id: submission.id,
      status: submission.status,
      title: submission.title,
      createdAt: submission.createdAt.toISOString(),
      jobs: submission.processingJobs.map((job) => ({
        id: job.id,
        status: job.status,
        attempts: job.attempts,
        lastError: job.lastError,
      })),
    })),
  }, null, 2));
};

main()
  .catch((error) => {
    console.error('[content-submission-event-edit-cleanup] failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
