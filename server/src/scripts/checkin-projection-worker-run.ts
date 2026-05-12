import { PrismaClient } from '@prisma/client';
import { runCheckinProjectionWorkerJob } from '../jobs/checkin-projection/projection-worker.job';

const prisma = new PrismaClient();

async function main(): Promise<void> {
  process.exitCode = await runCheckinProjectionWorkerJob(prisma);
}

main()
  .catch((error) => {
    console.error('[checkin-projection-worker] run failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
