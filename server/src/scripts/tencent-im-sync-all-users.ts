import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { tencentIMConfig } from '../services/tencent-im/tencent-im-config';
import { tencentIMUserService } from '../services/tencent-im/tencent-im-user.service';

const prisma = new PrismaClient();

const parsePositiveInt = (value: string | undefined, fallback: number): number => {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : fallback;
};

const BATCH_SIZE = parsePositiveInt(process.env.TENCENT_IM_SYNC_BATCH_SIZE, 20);

const chunk = <T>(items: T[], size: number): T[][] => {
  const result: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    result.push(items.slice(index, index + size));
  }
  return result;
};

const main = async (): Promise<void> => {
  if (!tencentIMConfig.enabled) {
    throw new Error('Tencent IM is disabled. Set TENCENT_IM_ENABLED=true before running sync.');
  }

  if (!tencentIMConfig.isConfigured) {
    throw new Error('Tencent IM is missing SDKAppID or SecretKey. Check server/.env before running sync.');
  }

  const users = await prisma.user.findMany({
    where: { isActive: true },
    select: {
      id: true,
      username: true,
      displayName: true,
    },
    orderBy: {
      createdAt: 'asc',
    },
  });

  if (users.length === 0) {
    console.log('[tencent-im:sync-all-users] no active users found');
    return;
  }

  const batches = chunk(users.map((user) => user.id), BATCH_SIZE);
  let synced = 0;

  console.log('[tencent-im:sync-all-users] start', {
    totalUsers: users.length,
    batchSize: BATCH_SIZE,
    batches: batches.length,
  });

  for (const [index, batch] of batches.entries()) {
    await tencentIMUserService.ensureUsersByIds(batch);
    synced += batch.length;
    console.log('[tencent-im:sync-all-users] batch complete', {
      batch: index + 1,
      batches: batches.length,
      synced,
      totalUsers: users.length,
    });
  }

  console.log('[tencent-im:sync-all-users] done', {
    totalUsers: users.length,
    synced,
  });
};

void main()
  .catch((error: unknown) => {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[tencent-im:sync-all-users] failed: ${message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
