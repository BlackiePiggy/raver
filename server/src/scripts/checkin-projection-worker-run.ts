import { PrismaClient } from '@prisma/client';
import { runCheckinProjectionWorkerOnce } from '../services/checkin-projection-worker';

const prisma = new PrismaClient();

const parseBatchSize = (): number | undefined => {
  const raw = process.env.CHECKIN_PROJECTION_WORKER_BATCH_SIZE;
  if (!raw) return undefined;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? Math.floor(parsed) : undefined;
};

async function main(): Promise<void> {
  const report = await runCheckinProjectionWorkerOnce(prisma, {
    batchSize: parseBatchSize(),
  });

  console.log(
    `[checkin-projection-worker] scanned=${report.scannedEvents} usersRebuilt=${report.usersRebuilt} processed=${report.processedEvents} failed=${report.failedEvents}`
  );

  for (const error of report.errors) {
    console.error(`[checkin-projection-worker] ${error}`);
  }

  if (report.failedEvents > 0) {
    process.exitCode = 1;
  }
}

main()
  .catch((error) => {
    console.error('[checkin-projection-worker] run failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
