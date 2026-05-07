import { PrismaClient } from '@prisma/client';
import {
  checkinProjectionStatusExitCode,
  getCheckinProjectionStatus,
} from '../services/checkin-projection-status';

const prisma = new PrismaClient();

async function main(): Promise<void> {
  const report = await getCheckinProjectionStatus(prisma);

  console.log('[checkin-projection-freshness] report', JSON.stringify(report, null, 2));
  process.exitCode = checkinProjectionStatusExitCode(report.status);
}

main()
  .catch((error) => {
    console.error('[checkin-projection-freshness] fatal', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
