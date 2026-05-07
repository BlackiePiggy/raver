import { PrismaClient } from '@prisma/client';
import { rebuildUserCheckinProjection } from '../services/checkin-projection';

const prisma = new PrismaClient();

const readArgValue = (flag: string): string | null => {
  const index = process.argv.indexOf(flag);
  if (index < 0) return null;
  const value = process.argv[index + 1];
  return value && !value.startsWith('--') ? value.trim() : null;
};

const printUsage = (): void => {
  console.log(
    [
      'Usage:',
      '  pnpm checkins:reproject:user -- --user-id <userId> [--apply]',
      '',
      'Defaults to dry-run. Add --apply to rebuild projection tables.',
    ].join('\n')
  );
};

async function main(): Promise<void> {
  const userId = readArgValue('--user-id');
  const apply = process.argv.includes('--apply');

  if (!userId) {
    printUsage();
    process.exitCode = 1;
    return;
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true },
  });

  if (!user) {
    console.error(`[checkin-reproject-user] user not found: ${userId}`);
    process.exitCode = 1;
    return;
  }

  const report = await rebuildUserCheckinProjection(prisma, userId, {
    dryRun: !apply,
  });

  console.log('[checkin-reproject-user] report', JSON.stringify(report, null, 2));
  if (!apply) {
    console.log('[checkin-reproject-user] dry-run only; rerun with --apply to write projection tables');
  }
}

main()
  .catch((error) => {
    console.error('[checkin-reproject-user] fatal', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
