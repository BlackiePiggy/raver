import { PrismaClient } from '@prisma/client';
import { getContentSubmissionProcessingQueueStatus } from '../services/content-submission-processing.service';

const prisma = new PrismaClient({
  datasources: process.env.WORKER_DATABASE_URL
    ? {
        db: {
          url: process.env.WORKER_DATABASE_URL,
        },
      }
    : undefined,
});

const formatDateTime = (value: Date | null | undefined): string =>
  value ? value.toISOString() : '-';

const formatDurationMs = (value: unknown): string => {
  if (typeof value !== 'number' || !Number.isFinite(value)) return '-';
  if (value < 1000) return `${Math.round(value)}ms`;
  return `${(value / 1000).toFixed(value >= 10_000 ? 0 : 1)}s`;
};

const formatPhaseTimings = (value: unknown): string => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return '-';
  const row = value as Record<string, unknown>;
  const parts = [
    `review=${formatDurationMs(row.reviewingTransitionMs)}`,
    `apply=${formatDurationMs(row.applyMs)}`,
    `queue=${formatDurationMs(row.timetableQueuedMs)}`,
    `finalize=${formatDurationMs(row.approvalFinalizeMs)}`,
    `total=${formatDurationMs(row.totalMs)}`,
  ];
  return parts.join(' ');
};

const formatJobTypeTotals = (value: Record<string, Record<string, number>>): string[] =>
  Object.entries(value)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([jobType, totals]) => {
      const states = Object.entries(totals)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([status, count]) => `${status}=${count}`)
        .join(' ');
      return `- ${jobType}: ${states}`;
    });

const printHumanReadableStatus = async (): Promise<void> => {
  const status = await getContentSubmissionProcessingQueueStatus(prisma);
  console.log(`content submission worker status: ${status.status}`);
  console.log(`checkedAt: ${status.checkedAt.toISOString()}`);
  console.log(`alerts: ${status.alertReasons.length > 0 ? status.alertReasons.join(', ') : 'none'}`);
  console.log(
    `queue: queued=${status.queuedCount} retrying=${status.retryingCount} running=${status.runningCount} failed=${status.failedCount}`
  );
  console.log(
    `oldestQueued: ${formatDateTime(status.oldestQueuedAt)} ageSeconds=${status.oldestQueuedAgeSeconds ?? '-'} staleRunning=${status.staleRunningCount}`
  );
  console.log('jobTypeTotals:');
  for (const line of formatJobTypeTotals(status.jobTypeTotals)) {
    console.log(line);
  }
  console.log('latestJobs:');
  for (const job of status.latestJobs) {
    console.log(
      [
        `- ${job.jobType}/${job.status}`,
        `submission=${job.submissionId}`,
        `title=${job.submissionTitle || '-'}`,
        `entity=${job.entityType || '-'}`,
        `submissionStatus=${job.submissionStatus || '-'}`,
        `attempts=${job.attempts}/${job.maxAttempts}`,
        `lastResult=${job.lastResult || '-'}`,
        `lastDuration=${formatDurationMs(job.lastDurationMs)}`,
      ].join(' ')
    );
    console.log(
      `  updatedAt=${job.updatedAt.toISOString()} availableAt=${job.availableAt.toISOString()} retryScheduledAt=${job.retryScheduledAt || '-'}`
    );
    console.log(`  phaseTimings=${formatPhaseTimings(job.phaseTimings)}`);
    console.log(`  createdEntityId=${job.createdEntityId || '-'} lockedBy=${job.lockedBy || '-'} lastError=${job.lastError || '-'}`);
    console.log(`  phaseBFailure=${job.phaseBFailure ? JSON.stringify(job.phaseBFailure) : '-'}`);
  }
  process.exitCode = status.status === 'critical' ? 1 : 0;
};

async function main(): Promise<void> {
  const args = new Set(process.argv.slice(2));
  if (args.has('--json')) {
    const status = await getContentSubmissionProcessingQueueStatus(prisma);
    console.log(JSON.stringify(status, null, 2));
    process.exitCode = status.status === 'critical' ? 1 : 0;
    return;
  }
  await printHumanReadableStatus();
}

main()
  .catch((error) => {
    console.error('[content-submission-worker-status] failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
