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

const readPayloadObject = (value: unknown): Record<string, unknown> =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};

const readJsonObject = (value: unknown): Record<string, unknown> | null =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;

const main = async (): Promise<void> => {
  const eventId = cleanText(process.argv[2]);
  if (!eventId) {
    throw new Error('Usage: pnpm content-submissions:event-edit:diagnose <eventId>');
  }

  const event = await prisma.event.findUnique({
    where: { id: eventId },
    select: {
      id: true,
      name: true,
      revision: true,
      updatedAt: true,
      organizerId: true,
      isCancelled: true,
      visibility: true,
    },
  });

  if (!event) {
    throw new Error(`Event not found: ${eventId}`);
  }

  const submissions = await prisma.contentSubmission.findMany({
    where: {
      entityType: 'event',
      OR: [
        { createdEntityId: eventId },
        { payload: { path: ['targetEventId'], equals: eventId } },
        { payload: { path: ['editTargetEventId'], equals: eventId } },
      ],
    },
    orderBy: [{ createdAt: 'asc' }],
    include: {
      submitter: {
        select: {
          id: true,
          username: true,
          displayName: true,
          role: true,
        },
      },
      processingJobs: {
        orderBy: [{ createdAt: 'asc' }],
      },
      versions: {
        orderBy: [{ version: 'asc' }],
      },
    },
  });

  const rows = submissions.map((submission) => {
    const payload = readPayloadObject(submission.payload);
    const jobs = submission.processingJobs.map((job) => {
      const metadata = readJsonObject(job.metadata);
      return {
        id: job.id,
        status: job.status,
        attempts: job.attempts,
        maxAttempts: job.maxAttempts,
        createdAt: job.createdAt.toISOString(),
        startedAt: job.startedAt?.toISOString() ?? null,
        completedAt: job.completedAt?.toISOString() ?? null,
        failedAt: job.failedAt?.toISOString() ?? null,
        lastError: job.lastError,
        phase: metadata?.phase ?? metadata?.currentPhase ?? null,
        lastResult: metadata?.lastResult ?? null,
        lastDurationMs: metadata?.lastDurationMs ?? null,
        conflictDetails: metadata?.conflictDetails ?? null,
      };
    });
    return {
      id: submission.id,
      status: submission.status,
      title: submission.title,
      submitter: submission.submitter,
      createdAt: submission.createdAt.toISOString(),
      updatedAt: submission.updatedAt.toISOString(),
      reviewedAt: submission.reviewedAt?.toISOString() ?? null,
      createdEntityId: submission.createdEntityId,
      reviewReason: submission.reviewReason,
      targetEventId: cleanText(payload.targetEventId) ?? cleanText(payload.editTargetEventId),
      changeSummary: readJsonObject(payload.changeSummary),
      versionCount: submission.versions.length,
      versionSubmittedAt: submission.versions.map((version) => ({
        version: version.version,
        submittedAt: version.submittedAt.toISOString(),
        submittedBy: version.submittedBy,
        changeNote: version.changeNote,
      })),
      jobs,
    };
  });

  const activeRows = rows.filter((row) => ['pending', 'processing', 'reviewing'].includes(row.status));
  console.log(JSON.stringify({
    event: {
      ...event,
      updatedAt: event.updatedAt.toISOString(),
    },
    summary: {
      submissionCount: rows.length,
      activeSubmissionCount: activeRows.length,
      firstSubmissionAt: rows[0]?.createdAt ?? null,
      lastSubmissionAt: rows[rows.length - 1]?.createdAt ?? null,
    },
    submissions: rows,
  }, null, 2));
};

main()
  .catch((error) => {
    console.error('[content-submission-event-edit-diagnose] failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
