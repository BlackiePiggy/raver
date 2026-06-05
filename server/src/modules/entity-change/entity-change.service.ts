import { Prisma, PrismaClient } from '@prisma/client';
import { diffEntitySnapshots } from './entity-change-diff-engine';
import { getEntityChangeDefinition } from './entity-change.registry';
import { entityChangeRepository } from './entity-change.repository';
import { buildEntityChangeSummary } from './entity-change-summarizer';
import {
  assertEntityRevisionMatches,
  parseExpectedEntityRevision,
} from './entity-change-revision-guard';
import { adminAuditService } from '../admin/admin-audit.service';
import type {
  EntityChangeDb,
  EntityChangeEntityType,
  EntityChangeLogRecord,
  EntityChangeOperationType,
  EntityChangeResult,
  EntitySnapshot,
  PersistEntityChangeInput,
} from './entity-change.types';

const prisma = new PrismaClient();

const displayNameFromSnapshots = (
  before: EntitySnapshot | null,
  after: EntitySnapshot | null,
  fallback: string
): string => after?.displayName || before?.displayName || fallback;

export const entityChangeService = {
  parseExpectedRevision: parseExpectedEntityRevision,
  assertRevisionMatch: assertEntityRevisionMatches,

  toResponse(input: {
    change: EntityChangeResult;
    changeLog: EntityChangeLogRecord | null;
  }): {
    changeLogId: string | null;
    changed: boolean;
    changeCount: number;
    summary: string | null;
    summaries: {
      zh: string | null;
      en: string | null;
      ja: string | null;
    };
    publicChanges: EntityChangeResult['publicChanges'];
  } {
    return {
      changeLogId: input.changeLog?.id ?? null,
      changed: input.change.changed,
      changeCount: input.change.changeCount,
      summary: input.change.summary.publicSummaryZh,
      summaries: {
        zh: input.change.summary.publicSummaryZh,
        en: input.change.summary.publicSummaryEn,
        ja: input.change.summary.publicSummaryJa,
      },
      publicChanges: input.change.publicChanges,
    };
  },

  async captureSnapshot(input: {
    entityType: EntityChangeEntityType;
    entityId: string;
    db?: EntityChangeDb;
  }): Promise<EntitySnapshot | null> {
    const definition = getEntityChangeDefinition(input.entityType);
    return definition.buildSnapshot({
      entityId: input.entityId,
      db: input.db ?? prisma,
    });
  },

  async diffSnapshots(input: {
    entityType: EntityChangeEntityType;
    entityId: string;
    operationType: EntityChangeOperationType;
    before: EntitySnapshot | null;
    after: EntitySnapshot | null;
  }): Promise<EntityChangeResult> {
    const definition = getEntityChangeDefinition(input.entityType);
    const diff = diffEntitySnapshots({
      definition,
      before: input.before,
      after: input.after,
    });
    const displayName = displayNameFromSnapshots(input.before, input.after, input.entityId);
    const summary = buildEntityChangeSummary({
      entityType: input.entityType,
      displayName,
      changes: diff.changes,
      publicChanges: diff.publicChanges,
    });

    return {
      entityType: input.entityType,
      entityId: input.entityId,
      operationType: input.operationType,
      displayName,
      snapshotSchemaVersion: definition.snapshotSchemaVersion,
      diffSchemaVersion: diff.diffSchemaVersion,
      revisionBefore: input.before?.revision ?? null,
      revisionAfter: input.after?.revision ?? null,
      beforeHash: diff.beforeHash,
      afterHash: diff.afterHash,
      changed: diff.changes.length > 0,
      changeCount: diff.changes.length,
      changes: diff.changes,
      publicChanges: diff.publicChanges,
      summary,
    };
  },

  async persistChange(input: PersistEntityChangeInput): Promise<EntityChangeLogRecord | null> {
    if (!input.result.changed) return null;
    const changeLog = await entityChangeRepository.create(input);
    if (input.actorId) {
      try {
        await adminAuditService.createAction({
          actorId: input.actorId,
          action: `entity_change.${input.result.operationType}`,
          targetType: input.result.entityType,
          targetId: input.result.entityId,
          detail: {
            changeLogId: changeLog.id,
            beforeHash: input.result.beforeHash,
            afterHash: input.result.afterHash,
            changeCount: input.result.changeCount,
            privateSummaryZh: input.result.summary.privateSummaryZh,
            operatorSummaryZh: input.result.summary.operatorSummaryZh,
            publicSummaryZh: input.result.summary.publicSummaryZh,
            publicSummaryEn: input.result.summary.publicSummaryEn,
            publicSummaryJa: input.result.summary.publicSummaryJa,
            changes: input.result.changes,
          } as Prisma.InputJsonValue,
        });
      } catch (error) {
        console.warn('[entity-change] admin audit bridge failed:', error instanceof Error ? error.message : String(error));
      }
    }
    return changeLog;
  },

  async trackUpdate<T>(input: {
    entityType: EntityChangeEntityType;
    entityId: string;
    operationType?: EntityChangeOperationType;
    actorId?: string | null;
    actorRole?: string | null;
    source?: string | null;
    sourceRoute?: string | null;
    requestId?: string | null;
    expectedRevision?: number | null;
    update: (tx: import('@prisma/client').Prisma.TransactionClient, context: {
      currentRevision: number | null;
      expectedRevision: number | null;
    }) => Promise<T>;
    metadata?: Record<string, unknown>;
  }): Promise<{ value: T; change: EntityChangeResult; changeLog: EntityChangeLogRecord | null }> {
    let before: EntitySnapshot | null = null;
    let after: EntitySnapshot | null = null;
    const value = await prisma.$transaction(async (tx) => {
      before = await this.captureSnapshot({
        entityType: input.entityType,
        entityId: input.entityId,
        db: tx,
      });
      const currentRevision = before?.revision ?? null;
      assertEntityRevisionMatches({
        entityType: input.entityType,
        entityId: input.entityId,
        expectedRevision: input.expectedRevision,
        currentRevision,
      });
      const updated = await input.update(tx, {
        currentRevision,
        expectedRevision: input.expectedRevision ?? null,
      });
      after = await this.captureSnapshot({
        entityType: input.entityType,
        entityId: input.entityId,
        db: tx,
      });
      return updated;
    });
    const change = await this.diffSnapshots({
      entityType: input.entityType,
      entityId: input.entityId,
      operationType: input.operationType ?? 'update',
      before,
      after,
    });
    const changeLog = await this.persistChange({
      result: change,
      snapshots: { before, after },
      actorId: input.actorId,
      actorRole: input.actorRole,
      source: input.source,
      sourceRoute: input.sourceRoute,
      requestId: input.requestId,
      metadata: input.metadata,
    });
    return { value, change, changeLog };
  },
};
