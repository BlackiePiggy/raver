import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const apply = process.env.ENTITY_CHANGE_SNAPSHOT_ARCHIVE_CLEANUP_APPLY === '1';

const run = async (): Promise<void> => {
  const now = new Date();
  const where = {
    expiresAt: {
      lte: now,
    },
  };
  const expiredCount = await prisma.entityChangeSnapshotArchive.count({ where });
  if (!apply) {
    console.log(`[entity-change-snapshot-archive-cleanup] dry-run expired=${expiredCount}`);
    return;
  }
  const deleted = await prisma.entityChangeSnapshotArchive.deleteMany({ where });
  console.log(`[entity-change-snapshot-archive-cleanup] deleted=${deleted.count}`);
};

run()
  .catch((error) => {
    console.error('[entity-change-snapshot-archive-cleanup] failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
