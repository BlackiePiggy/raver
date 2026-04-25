import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const IOS_PLATFORM_ALIASES = ['ios', 'apns', 'ios_apns'] as const;
const ANDROID_PLATFORM_ALIASES = ['android', 'fcm', 'android_fcm'] as const;

type DeviceTokenRow = {
  id: string;
  userId: string;
  deviceId: string;
  platform: string;
  pushToken: string;
  isActive: boolean;
  appVersion: string | null;
  locale: string | null;
  lastSeenAt: Date;
  createdAt: Date;
  updatedAt: Date;
};

const normalizeDevicePlatform = (raw: string): string => {
  const normalized = raw.trim().toLowerCase();
  if (!normalized) return normalized;
  if ((IOS_PLATFORM_ALIASES as readonly string[]).includes(normalized)) return 'ios';
  if ((ANDROID_PLATFORM_ALIASES as readonly string[]).includes(normalized)) return 'android';
  return normalized;
};

const byFreshnessDesc = (a: DeviceTokenRow, b: DeviceTokenRow): number => {
  const updatedDiff = b.updatedAt.getTime() - a.updatedAt.getTime();
  if (updatedDiff !== 0) return updatedDiff;
  const seenDiff = b.lastSeenAt.getTime() - a.lastSeenAt.getTime();
  if (seenDiff !== 0) return seenDiff;
  return b.createdAt.getTime() - a.createdAt.getTime();
};

const groupKey = (row: DeviceTokenRow): string => {
  return `${row.userId}::${row.deviceId}::${normalizeDevicePlatform(row.platform)}`;
};

const main = async (): Promise<void> => {
  const rows = await prisma.devicePushToken.findMany({
    where: {
      platform: {
        in: [...IOS_PLATFORM_ALIASES, ...ANDROID_PLATFORM_ALIASES],
      },
    },
    select: {
      id: true,
      userId: true,
      deviceId: true,
      platform: true,
      pushToken: true,
      isActive: true,
      appVersion: true,
      locale: true,
      lastSeenAt: true,
      createdAt: true,
      updatedAt: true,
    },
  });

  if (rows.length === 0) {
    console.log('[notification:normalize-device-platforms] no candidate rows found');
    return;
  }

  const grouped = new Map<string, DeviceTokenRow[]>();
  for (const row of rows) {
    const key = groupKey(row);
    const current = grouped.get(key) ?? [];
    current.push(row);
    grouped.set(key, current);
  }

  let touchedGroups = 0;
  let updatedRows = 0;
  let deletedRows = 0;

  for (const [, group] of grouped) {
    const canonicalPlatform = normalizeDevicePlatform(group[0].platform);
    if (!canonicalPlatform) {
      continue;
    }

    const sorted = [...group].sort(byFreshnessDesc);
    const freshest = sorted[0];
    const canonicalRows = sorted.filter((item) => item.platform === canonicalPlatform);
    const keeper = canonicalRows.length > 0 ? canonicalRows[0] : freshest;

    const shouldUpdateKeeper =
      keeper.platform !== canonicalPlatform ||
      keeper.pushToken !== freshest.pushToken ||
      keeper.isActive !== freshest.isActive ||
      keeper.appVersion !== freshest.appVersion ||
      keeper.locale !== freshest.locale ||
      keeper.lastSeenAt.getTime() !== freshest.lastSeenAt.getTime();

    const removeIds = sorted.filter((item) => item.id !== keeper.id).map((item) => item.id);

    if (!shouldUpdateKeeper && removeIds.length === 0) {
      continue;
    }

    touchedGroups += 1;

    await prisma.$transaction(async (tx) => {
      if (shouldUpdateKeeper) {
        await tx.devicePushToken.update({
          where: { id: keeper.id },
          data: {
            platform: canonicalPlatform,
            pushToken: freshest.pushToken,
            isActive: freshest.isActive,
            appVersion: freshest.appVersion,
            locale: freshest.locale,
            lastSeenAt: freshest.lastSeenAt,
          },
          select: { id: true },
        });
      }

      if (removeIds.length > 0) {
        await tx.devicePushToken.deleteMany({
          where: {
            id: {
              in: removeIds,
            },
          },
        });
      }
    });

    if (shouldUpdateKeeper) {
      updatedRows += 1;
    }
    deletedRows += removeIds.length;
  }

  console.log('[notification:normalize-device-platforms] done', {
    candidates: rows.length,
    groups: grouped.size,
    touchedGroups,
    updatedRows,
    deletedRows,
  });
};

void main()
  .catch((error: unknown) => {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[notification:normalize-device-platforms] failed: ${message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
