import { PrismaClient } from '@prisma/client';
import { runCheckinProjectionWorkerOnce } from '../../modules/checkins';

const parseBatchSize = (): number | undefined => {
  const raw = process.env.CHECKIN_PROJECTION_WORKER_BATCH_SIZE;
  if (!raw) return undefined;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? Math.floor(parsed) : undefined;
};

export const runCheckinProjectionWorkerJob = async (prisma: PrismaClient): Promise<number> => {
  const report = await runCheckinProjectionWorkerOnce(prisma, {
    batchSize: parseBatchSize(),
  });

  console.log(
    `[checkin-projection-worker] scanned=${report.scannedEvents} usersRebuilt=${report.usersRebuilt} processed=${report.processedEvents} failed=${report.failedEvents}`
  );

  for (const error of report.errors) {
    console.error(`[checkin-projection-worker] ${error}`);
  }

  return report.failedEvents > 0 ? 1 : 0;
};
