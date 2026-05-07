import { PrismaClient } from '@prisma/client';
import {
  createSnapshotData,
  hydrateStoredSelections,
  normalizeNullableText,
} from '../services/checkin-domain';

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
  const userId = readArgValue('--user-id');
  const limit = parsePositiveInt(readArgValue('--limit'), 100);

  const rows = await prisma.checkin.findMany({
    where: {
      status: 'active',
      ...(userId ? { userId } : {}),
    },
    orderBy: [{ updatedAt: 'desc' }],
    take: limit,
    include: {
      user: {
        select: { displayName: true, username: true },
      },
      event: {
        select: {
          name: true,
          nameI18n: true,
          coverImageUrl: true,
          city: true,
          country: true,
          venueAddress: true,
          manualLocation: true,
          startDate: true,
          endDate: true,
        },
      },
      dj: {
        select: {
          name: true,
          nameI18n: true,
          avatarUrl: true,
          country: true,
        },
      },
      selections: {
        orderBy: [{ dayIndex: 'asc' }, { sortOrder: 'asc' }],
        select: {
          dayId: true,
          dayIndex: true,
          djs: {
            orderBy: [{ sortOrder: 'asc' }, { performerIndex: 'asc' }],
            select: {
              djId: true,
              displayName: true,
              rawName: true,
              actType: true,
              performerIndex: true,
              actGroupId: true,
            },
          },
        },
      },
    },
  });

  let rebuilt = 0;
  for (const row of rows) {
    const displayName = normalizeNullableText(row.user.displayName) ?? row.user.username;
    const visibility = row.visibility === 'visible' ? 'visible' : 'private';
    const snapshotData = createSnapshotData(
      displayName,
      visibility,
      hydrateStoredSelections(row.selections),
      row.event,
      row.dj
    );

    if (apply) {
      await prisma.checkinSnapshot.upsert({
        where: { checkinId: row.id },
        create: {
          checkinId: row.id,
          ...snapshotData,
        },
        update: {
          ...snapshotData,
          generatedAt: new Date(),
        },
      });
    }

    rebuilt += 1;
  }

  console.log(
    `[checkin-rebuild-snapshots] mode=${apply ? 'apply' : 'dry-run'} userId=${userId ?? 'ALL'} limit=${limit} scanned=${rows.length} rebuilt=${rebuilt}`
  );
  if (!apply) {
    console.log('[checkin-rebuild-snapshots] dry-run only; rerun with --apply to write snapshots');
  }
}

main()
  .catch((error) => {
    console.error('[checkin-rebuild-snapshots] fatal', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
