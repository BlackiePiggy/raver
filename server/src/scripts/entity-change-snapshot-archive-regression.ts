import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import {
  entityChangeService,
  type EntitySnapshot,
} from '../modules/entity-change';

const prisma = new PrismaClient();

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

const runId = `snapshot-archive-regression-${Date.now()}`;

const snapshot = (entityId: string, name: string, revision: number): EntitySnapshot => ({
  entityType: 'dj',
  entityId,
  displayName: name,
  revision,
  schemaVersion: 1,
  capturedAt: new Date().toISOString(),
  data: {
    profile: {
      name,
      aliases: [name],
      genres: ['house'],
    },
  },
});

const archiveRowsFor = async (changeLogId: string) =>
  prisma.entityChangeSnapshotArchive.findMany({
    where: { changeLogId },
    orderBy: { snapshotRole: 'asc' },
  });

const persist = async (input: {
  entityId: string;
  before: EntitySnapshot | null;
  after: EntitySnapshot | null;
  operationType: 'create' | 'update' | 'delete';
}) => {
  const change = await entityChangeService.diffSnapshots({
    entityType: 'dj',
    entityId: input.entityId,
    operationType: input.operationType,
    before: input.before,
    after: input.after,
  });
  const changeLog = await entityChangeService.persistChange({
    result: change,
    snapshots: {
      before: input.before,
      after: input.after,
    },
    source: 'entity-change-snapshot-archive-regression',
    requestId: runId,
    snapshotArchiveRetentionDays: 1,
  });
  return { change, changeLog };
};

const run = async (): Promise<void> => {
  const createEntityId = `${runId}-create`;
  const createAfter = snapshot(createEntityId, 'Archive Create After', 1);
  const createResult = await persist({
    entityId: createEntityId,
    before: null,
    after: createAfter,
    operationType: 'create',
  });
  assert(createResult.changeLog !== null, 'create should persist a change log');
  const createArchives = await archiveRowsFor(createResult.changeLog.id);
  assert(createArchives.length === 1, 'create should archive only after snapshot');
  assert(createArchives[0]?.snapshotRole === 'after', 'create archive should use after role');
  assert(createArchives[0]?.snapshotHash === createResult.change.afterHash, 'create archive hash should match afterHash');
  assert(createArchives[0]?.expiresAt.getTime() > Date.now(), 'create archive should have a future expiresAt');

  const updateEntityId = `${runId}-update`;
  const updateBefore = snapshot(updateEntityId, 'Archive Update Before', 1);
  const updateAfter = snapshot(updateEntityId, 'Archive Update After', 2);
  const updateResult = await persist({
    entityId: updateEntityId,
    before: updateBefore,
    after: updateAfter,
    operationType: 'update',
  });
  assert(updateResult.changeLog !== null, 'update should persist a change log');
  const updateArchives = await archiveRowsFor(updateResult.changeLog.id);
  assert(updateArchives.length === 2, 'update should archive before and after snapshots');
  assert(updateArchives.some((row) => row.snapshotRole === 'before'), 'update should include before archive');
  assert(updateArchives.some((row) => row.snapshotRole === 'after'), 'update should include after archive');
  assert(
    updateArchives.find((row) => row.snapshotRole === 'before')?.snapshotHash === updateResult.change.beforeHash,
    'update before archive hash should match beforeHash'
  );
  assert(
    updateArchives.find((row) => row.snapshotRole === 'after')?.snapshotHash === updateResult.change.afterHash,
    'update after archive hash should match afterHash'
  );

  const deleteEntityId = `${runId}-delete`;
  const deleteBefore = snapshot(deleteEntityId, 'Archive Delete Before', 1);
  const deleteResult = await persist({
    entityId: deleteEntityId,
    before: deleteBefore,
    after: null,
    operationType: 'delete',
  });
  assert(deleteResult.changeLog !== null, 'delete should persist a change log');
  const deleteArchives = await archiveRowsFor(deleteResult.changeLog.id);
  assert(deleteArchives.length === 1, 'delete should archive only before snapshot');
  assert(deleteArchives[0]?.snapshotRole === 'before', 'delete archive should use before role');
  assert(deleteArchives[0]?.snapshotHash === deleteResult.change.beforeHash, 'delete archive hash should match beforeHash');

  const noChangeEntityId = `${runId}-no-change`;
  const noChangeSnapshot = snapshot(noChangeEntityId, 'Archive No Change', 1);
  const archivesBeforeNoChange = await prisma.entityChangeSnapshotArchive.count({
    where: { entityId: noChangeEntityId },
  });
  const noChangeResult = await persist({
    entityId: noChangeEntityId,
    before: noChangeSnapshot,
    after: noChangeSnapshot,
    operationType: 'update',
  });
  const archivesAfterNoChange = await prisma.entityChangeSnapshotArchive.count({
    where: { entityId: noChangeEntityId },
  });
  assert(noChangeResult.changeLog === null, 'no-change should not persist a change log');
  assert(archivesAfterNoChange === archivesBeforeNoChange, 'no-change should not persist snapshot archives');

  console.log('[entity-change-snapshot-archive-regression] ok');
};

run()
  .catch((error) => {
    console.error('[entity-change-snapshot-archive-regression] failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.entityChangeLog.deleteMany({
      where: { entityId: { startsWith: runId } },
    });
    await prisma.$disconnect();
  });
