import { PrismaClient } from '@prisma/client';
import { runContentSubmissionProcessingWorkerOnce } from '../../services/content-submission-processing.service';

const parseBatchSize = (): number | undefined => {
  const raw = process.env.CONTENT_SUBMISSION_WORKER_BATCH_SIZE;
  if (!raw) return undefined;
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : undefined;
};

export const runContentSubmissionProcessingWorkerJob = async (
  prisma: PrismaClient
): Promise<number> => {
  const report = await runContentSubmissionProcessingWorkerOnce(prisma, {
    batchSize: parseBatchSize(),
  });

  console.log(
    `[content-submission-worker] scanned=${report.scannedJobs} processed=${report.processedJobs} succeeded=${report.succeededJobs} retrying=${report.retryingJobs} failed=${report.failedJobs} skipped=${report.skippedJobs}`
  );

  for (const error of report.errors) {
    console.error(`[content-submission-worker] ${error}`);
  }

  return report.failedJobs > 0 ? 1 : 0;
};
