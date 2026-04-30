import 'dotenv/config';
import fs from 'fs/promises';
import path from 'path';
import { PrismaClient } from '@prisma/client';
import { tencentIMConfig } from '../services/tencent-im/tencent-im-config';
import { tencentIMClient } from '../services/tencent-im/tencent-im-client';
import { toTencentIMUserID } from '../services/tencent-im/tencent-im-id';

const prisma = new PrismaClient();

type CandidateRow = {
  id: string;
  username: string;
  displayName: string | null;
  email: string;
};

const rootDir = path.resolve(__dirname, '../../..');
const outputDir = path.join(rootDir, 'docs', 'generated');
const snapshotPath = path.join(outputDir, 'tencent-im-openim-users-deleted.json');

const chunk = <T>(items: T[], size: number): T[][] => {
  const result: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    result.push(items.slice(index, index + size));
  }
  return result;
};

const isOpenIMRelated = (user: CandidateRow): boolean => {
  const values = [user.username, user.displayName ?? '', user.email];
  return values.some((value) => value.toLowerCase().includes('openim'));
};

const deleteTencentAccounts = async (userIDs: string[]): Promise<void> => {
  if (!tencentIMConfig.enabled) {
    console.log('[tencent-im:delete-openim-users] Tencent IM disabled, skip account_delete');
    return;
  }

  if (!tencentIMConfig.isConfigured) {
    throw new Error('Tencent IM is missing SDKAppID or SecretKey. Refusing to delete partial state.');
  }

  const batches = chunk(userIDs, 100);
  for (const [index, batch] of batches.entries()) {
    await tencentIMClient.post('v4/im_open_login_svc/account_delete', {
      DeleteItem: batch.map((userID) => ({ UserID: userID })),
    });
    console.log('[tencent-im:delete-openim-users] Tencent batch deleted', {
      batch: index + 1,
      batches: batches.length,
      count: batch.length,
    });
  }
};

const main = async (): Promise<void> => {
  const candidates = await prisma.user.findMany({
    where: {
      OR: [
        { username: { contains: 'openim', mode: 'insensitive' } },
        { displayName: { contains: 'openim', mode: 'insensitive' } },
        { email: { contains: 'openim', mode: 'insensitive' } },
      ],
    },
    select: {
      id: true,
      username: true,
      displayName: true,
      email: true,
    },
    orderBy: {
      createdAt: 'asc',
    },
  });

  const filtered = candidates.filter(isOpenIMRelated);
  if (filtered.length === 0) {
    console.log('[tencent-im:delete-openim-users] no OPENIM-related users found');
    return;
  }

  const snapshot = filtered.map((user) => ({
    platformUserID: user.id,
    username: user.username,
    displayName: user.displayName ?? '',
    email: user.email,
    tencentIMUserID: toTencentIMUserID(user.id),
  }));

  await fs.mkdir(outputDir, { recursive: true });
  await fs.writeFile(snapshotPath, JSON.stringify(snapshot, null, 2), 'utf8');

  console.log('[tencent-im:delete-openim-users] snapshot saved', {
    snapshotPath,
    totalUsers: snapshot.length,
  });

  await deleteTencentAccounts(snapshot.map((item) => item.tencentIMUserID));

  await prisma.user.deleteMany({
    where: {
      id: {
        in: filtered.map((user) => user.id),
      },
    },
  });

  console.log('[tencent-im:delete-openim-users] platform users deleted', {
    totalUsers: filtered.length,
  });
};

void main()
  .catch((error: unknown) => {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[tencent-im:delete-openim-users] failed: ${message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
