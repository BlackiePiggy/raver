import { PrismaClient } from '@prisma/client';
import { runContentSubmissionProcessingWorkerJob } from '../jobs/content-submission/processing-worker.job';
import { startContentSubmissionProcessingWorkerLoop } from '../services/content-submission-processing.service';

const prisma = new PrismaClient({
  datasources: process.env.WORKER_DATABASE_URL
    ? {
        db: {
          url: process.env.WORKER_DATABASE_URL,
        },
      }
    : undefined,
});

async function main(): Promise<void> {
  if (process.env.CONTENT_SUBMISSION_WORKER_LOOP === '1') {
    await startContentSubmissionProcessingWorkerLoop(prisma);
    return;
  }

  process.exitCode = await runContentSubmissionProcessingWorkerJob(prisma);
}

main()
  .catch((error) => {
    console.error('[content-submission-worker] run failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    if (process.env.CONTENT_SUBMISSION_WORKER_LOOP !== '1') {
      await prisma.$disconnect();
    }
  });
