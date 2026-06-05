import { Prisma, PrismaClient } from '@prisma/client';
import type {
  EntityChangeLogRecord,
  EntityChangeSnapshotRole,
  EntitySnapshot,
  PersistEntityChangeInput,
} from './entity-change.types';

const prisma = new PrismaClient();

const toJson = (value: unknown): Prisma.InputJsonValue => value as Prisma.InputJsonValue;

const DEFAULT_SNAPSHOT_ARCHIVE_RETENTION_DAYS = 30;

const snapshotArchiveRetentionDays = (override?: number): number => {
  if (Number.isFinite(override) && override && override > 0) return Math.floor(override);
  const raw = process.env.ENTITY_CHANGE_SNAPSHOT_ARCHIVE_TTL_DAYS;
  const fromEnv = raw ? Number(raw) : NaN;
  return Number.isFinite(fromEnv) && fromEnv > 0
    ? Math.floor(fromEnv)
    : DEFAULT_SNAPSHOT_ARCHIVE_RETENTION_DAYS;
};

const archiveExpiresAt = (retentionDays: number): Date => {
  const expiresAt = new Date();
  expiresAt.setUTCDate(expiresAt.getUTCDate() + retentionDays);
  return expiresAt;
};

const archiveRow = (input: {
  changeLogId: string;
  role: EntityChangeSnapshotRole;
  snapshot: EntitySnapshot | null | undefined;
  snapshotHash: string | null;
  expiresAt: Date;
}) => {
  if (!input.snapshot || !input.snapshotHash) return null;
  return {
    changeLogId: input.changeLogId,
    entityType: input.snapshot.entityType,
    entityId: input.snapshot.entityId,
    snapshotRole: input.role,
    snapshotSchemaVersion: input.snapshot.schemaVersion,
    snapshotHash: input.snapshotHash,
    snapshot: toJson(input.snapshot),
    expiresAt: input.expiresAt,
  };
};

export const entityChangeRepository = {
  async create(input: PersistEntityChangeInput): Promise<EntityChangeLogRecord> {
    const row = await prisma.$transaction(async (tx) => {
      const created = await tx.entityChangeLog.create({
        data: {
          entityType: input.result.entityType,
          entityId: input.result.entityId,
          operationType: input.result.operationType,
          actorId: input.actorId ?? null,
          actorRole: input.actorRole ?? null,
          source: input.source ?? null,
          sourceRoute: input.sourceRoute ?? null,
          requestId: input.requestId ?? null,
          snapshotSchemaVersion: input.result.snapshotSchemaVersion,
          diffSchemaVersion: input.result.diffSchemaVersion,
          revisionBefore: input.result.revisionBefore,
          revisionAfter: input.result.revisionAfter,
          beforeHash: input.result.beforeHash,
          afterHash: input.result.afterHash,
          changed: input.result.changed,
          changeCount: input.result.changeCount,
          privateSummaryZh: input.result.summary.privateSummaryZh,
          operatorSummaryZh: input.result.summary.operatorSummaryZh,
          publicSummaryZh: input.result.summary.publicSummaryZh,
          privateSummaryEn: input.result.summary.privateSummaryEn,
          operatorSummaryEn: input.result.summary.operatorSummaryEn,
          publicSummaryEn: input.result.summary.publicSummaryEn,
          privateSummaryJa: input.result.summary.privateSummaryJa,
          operatorSummaryJa: input.result.summary.operatorSummaryJa,
          publicSummaryJa: input.result.summary.publicSummaryJa,
          changes: toJson(input.result.changes),
          publicChanges: toJson(input.result.publicChanges),
          metadata: input.metadata ? toJson(input.metadata) : undefined,
        },
        select: {
          id: true,
          entityType: true,
          entityId: true,
          operationType: true,
          changeCount: true,
          publicSummaryZh: true,
          createdAt: true,
        },
      });

      const expiresAt = archiveExpiresAt(snapshotArchiveRetentionDays(input.snapshotArchiveRetentionDays));
      const archiveRows = [
        archiveRow({
          changeLogId: created.id,
          role: 'before',
          snapshot: input.snapshots?.before,
          snapshotHash: input.result.beforeHash,
          expiresAt,
        }),
        archiveRow({
          changeLogId: created.id,
          role: 'after',
          snapshot: input.snapshots?.after,
          snapshotHash: input.result.afterHash,
          expiresAt,
        }),
      ].filter((row): row is NonNullable<typeof row> => row !== null);

      if (archiveRows.length > 0) {
        await tx.entityChangeSnapshotArchive.createMany({
          data: archiveRows,
        });
      }

      return created;
    });
    return row;
  },
};
