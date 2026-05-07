import { PrismaClient } from '@prisma/client';
import { CHECKIN_PROJECTION_VERSION, rebuildUserCheckinProjection } from '../services/checkin-projection';

const prisma = new PrismaClient();

const readArgValue = (flag: string): string | null => {
  const index = process.argv.indexOf(flag);
  if (index < 0) return null;
  const value = process.argv[index + 1];
  return value && !value.startsWith('--') ? value.trim() : null;
};

const parsePositiveInt = (value: string | null, fallback: number): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.floor(parsed));
};

async function main(): Promise<void> {
  const apply = process.argv.includes('--apply');
  const limit = parsePositiveInt(readArgValue('--limit'), 50);
  const dirtyUsers = await prisma.checkin.findMany({
    where: {
      status: 'active',
      projectionVersion: { lt: CHECKIN_PROJECTION_VERSION },
    },
    distinct: ['userId'],
    take: limit,
    select: {
      userId: true,
    },
    orderBy: [{ updatedAt: 'asc' }],
  });

  const reports = [];
  for (const row of dirtyUsers) {
    reports.push(
      await rebuildUserCheckinProjection(prisma, row.userId, {
        dryRun: !apply,
      })
    );
  }

  console.log(
    `[checkin-reproject-dirty-users] mode=${apply ? 'apply' : 'dry-run'} limit=${limit} users=${dirtyUsers.length}`
  );
  console.log(JSON.stringify(reports, null, 2));

  if (!apply) {
    console.log('[checkin-reproject-dirty-users] dry-run only; rerun with --apply to write projection tables');
  }
}

main()
  .catch((error) => {
    console.error('[checkin-reproject-dirty-users] fatal', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
