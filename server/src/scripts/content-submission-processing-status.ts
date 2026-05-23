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

async function main(): Promise<void> {
  const status = await getContentSubmissionProcessingQueueStatus(prisma);
  console.log(JSON.stringify(status, null, 2));
  process.exitCode = status.status === 'critical' ? 1 : 0;
}

main()
  .catch((error) => {
    console.error('[content-submission-worker-status] failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
