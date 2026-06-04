import 'dotenv/config';
import { Prisma, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type EntityType = 'event' | 'dj';
type ContributionRole = 'creator' | 'editor';

type RegistryEntry = {
  entityId: string;
  userId: string;
  role: ContributionRole;
  firstContributedAt: Date;
  lastContributedAt: Date;
  contributionCount: number;
};

type HistoryEntry = {
  id: string;
  entityId: string;
  userId: string;
  role: ContributionRole;
  occurredAt: Date;
  createdAt: Date;
};

type HistoryAggregate = {
  userId: string;
  count: number;
  firstOccurredAt: Date;
  lastOccurredAt: Date;
  hasCreatorRole: boolean;
};

type ValidationIssue = {
  severity: 'warning' | 'error';
  entityType: EntityType;
  entityId: string;
  code: string;
  detail: string;
};

type TypeSummary = {
  entityType: EntityType;
  historyRowCount: number;
  historyDistinctEntityCount: number;
  historyCreatorEntityCount: number;
  registryRowCount: number;
  registryDistinctEntityCount: number;
  registryCreatorEntityCount: number;
  missingRegistryEntityIds: string[];
  missingCreatorEntityIds: string[];
  sampledEntityIds: string[];
};

const parsePositiveInt = (value: string | undefined, fallback: number): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.floor(parsed);
};

const sampleSize = parsePositiveInt(process.env.CONTRIBUTION_MODULE_VERIFY_SAMPLE_SIZE, 20);
const selectedEntityTypes = (() => {
  const raw = String(process.env.CONTRIBUTION_MODULE_VERIFY_ENTITY_TYPES || 'event,dj')
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
  const values = Array.from(new Set(raw.filter((item) => item === 'event' || item === 'dj')));
  if (values.length === 0) {
    throw new Error('CONTRIBUTION_MODULE_VERIFY_ENTITY_TYPES must include event and/or dj');
  }
  return values as EntityType[];
})();
const selectedEventId = typeof process.env.CONTRIBUTION_MODULE_VERIFY_EVENT_ID === 'string'
  && process.env.CONTRIBUTION_MODULE_VERIFY_EVENT_ID.trim()
  ? process.env.CONTRIBUTION_MODULE_VERIFY_EVENT_ID.trim()
  : null;
const selectedDJId = typeof process.env.CONTRIBUTION_MODULE_VERIFY_DJ_ID === 'string'
  && process.env.CONTRIBUTION_MODULE_VERIFY_DJ_ID.trim()
  ? process.env.CONTRIBUTION_MODULE_VERIFY_DJ_ID.trim()
  : null;

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[verify-contribution-module-backfill]', step, detail || {});
};

const bigintToNumber = (value: bigint | number | null | undefined): number => {
  if (typeof value === 'bigint') return Number(value);
  return Number(value || 0);
};

const countResult = async (query: Prisma.PrismaPromise<Array<{ count: bigint }>>): Promise<number> => {
  const [row] = await query;
  return bigintToNumber(row?.count);
};

const scopeEntityIdForType = (entityType: EntityType): string | null =>
  entityType === 'event' ? selectedEventId : selectedDJId;

const loadTypeSummary = async (entityType: EntityType): Promise<TypeSummary> => {
  const scopedEntityId = scopeEntityIdForType(entityType);
  const historyWhere = scopedEntityId
    ? Prisma.sql`AND "entity_id" = ${scopedEntityId}`
    : Prisma.empty;
  const registryWhere = entityType === 'event'
    ? scopedEntityId
      ? Prisma.sql`WHERE "event_id" = ${scopedEntityId}`
      : Prisma.empty
    : scopedEntityId
      ? Prisma.sql`WHERE "dj_id" = ${scopedEntityId}`
      : Prisma.empty;

  if (entityType === 'event') {
    const [
      historyRowCount,
      historyDistinctEntityCount,
      historyCreatorEntityCount,
      registryRowCount,
      registryDistinctEntityCount,
      registryCreatorEntityCount,
      missingRegistryRows,
      missingCreatorRows,
      sampleRows,
    ] = await Promise.all([
      prisma.contributionHistoryEntry.count({
        where: {
          entityType: 'event',
          ...(scopedEntityId ? { entityId: scopedEntityId } : {}),
        },
      }),
      countResult(prisma.$queryRaw<Array<{ count: bigint }>>(Prisma.sql`
        SELECT COUNT(DISTINCT "entity_id")::bigint AS count
        FROM "contribution_history_entries"
        WHERE "entity_type" = 'event'
        ${historyWhere}
      `)),
      countResult(prisma.$queryRaw<Array<{ count: bigint }>>(Prisma.sql`
        SELECT COUNT(DISTINCT "entity_id")::bigint AS count
        FROM "contribution_history_entries"
        WHERE "entity_type" = 'event'
          AND "role_snapshot" = 'creator'
          ${historyWhere}
      `)),
      prisma.eventContributor.count({
        where: scopedEntityId ? { eventId: scopedEntityId } : undefined,
      }),
      countResult(prisma.$queryRaw<Array<{ count: bigint }>>(Prisma.sql`
        SELECT COUNT(DISTINCT "event_id")::bigint AS count
        FROM "event_contributors"
        ${registryWhere}
      `)),
      countResult(prisma.$queryRaw<Array<{ count: bigint }>>(Prisma.sql`
        SELECT COUNT(DISTINCT "event_id")::bigint AS count
        FROM "event_contributors"
        WHERE "role" = 'creator'
        ${scopedEntityId ? Prisma.sql`AND "event_id" = ${scopedEntityId}` : Prisma.empty}
      `)),
      prisma.$queryRaw<Array<{ entityId: string }>>(Prisma.sql`
        SELECT h."entity_id" AS "entityId"
        FROM "contribution_history_entries" h
        LEFT JOIN "event_contributors" c ON c."event_id" = h."entity_id"
        WHERE h."entity_type" = 'event'
          ${historyWhere}
        GROUP BY h."entity_id"
        HAVING COUNT(c."id") = 0
        ORDER BY h."entity_id" ASC
        LIMIT 10
      `),
      prisma.$queryRaw<Array<{ entityId: string }>>(Prisma.sql`
        SELECT c."event_id" AS "entityId"
        FROM "event_contributors" c
        ${registryWhere}
        GROUP BY c."event_id"
        HAVING SUM(CASE WHEN c."role" = 'creator' THEN 1 ELSE 0 END) = 0
        ORDER BY MAX(c."last_contributed_at") DESC
        LIMIT 10
      `),
      prisma.$queryRaw<Array<{ entityId: string }>>(Prisma.sql`
        SELECT c."event_id" AS "entityId"
        FROM "event_contributors" c
        ${registryWhere}
        GROUP BY c."event_id"
        ORDER BY MAX(c."last_contributed_at") DESC
        LIMIT ${sampleSize}
      `),
    ]);

    return {
      entityType,
      historyRowCount,
      historyDistinctEntityCount,
      historyCreatorEntityCount,
      registryRowCount,
      registryDistinctEntityCount,
      registryCreatorEntityCount,
      missingRegistryEntityIds: missingRegistryRows.map((row) => row.entityId),
      missingCreatorEntityIds: missingCreatorRows.map((row) => row.entityId),
      sampledEntityIds: sampleRows.map((row) => row.entityId),
    };
  }

  const [
    historyRowCount,
    historyDistinctEntityCount,
    historyCreatorEntityCount,
    registryRowCount,
    registryDistinctEntityCount,
    registryCreatorEntityCount,
    missingRegistryRows,
    missingCreatorRows,
    sampleRows,
  ] = await Promise.all([
    prisma.contributionHistoryEntry.count({
      where: {
        entityType: 'dj',
        ...(scopedEntityId ? { entityId: scopedEntityId } : {}),
      },
    }),
    countResult(prisma.$queryRaw<Array<{ count: bigint }>>(Prisma.sql`
      SELECT COUNT(DISTINCT "entity_id")::bigint AS count
      FROM "contribution_history_entries"
      WHERE "entity_type" = 'dj'
      ${historyWhere}
    `)),
    countResult(prisma.$queryRaw<Array<{ count: bigint }>>(Prisma.sql`
      SELECT COUNT(DISTINCT "entity_id")::bigint AS count
      FROM "contribution_history_entries"
      WHERE "entity_type" = 'dj'
        AND "role_snapshot" = 'creator'
        ${historyWhere}
    `)),
    prisma.dJContributor.count({
      where: scopedEntityId ? { djId: scopedEntityId } : undefined,
    }),
    countResult(prisma.$queryRaw<Array<{ count: bigint }>>(Prisma.sql`
      SELECT COUNT(DISTINCT "dj_id")::bigint AS count
      FROM "dj_contributors"
      ${registryWhere}
    `)),
    countResult(prisma.$queryRaw<Array<{ count: bigint }>>(Prisma.sql`
      SELECT COUNT(DISTINCT "dj_id")::bigint AS count
      FROM "dj_contributors"
      WHERE "role" = 'creator'
      ${scopedEntityId ? Prisma.sql`AND "dj_id" = ${scopedEntityId}` : Prisma.empty}
    `)),
    prisma.$queryRaw<Array<{ entityId: string }>>(Prisma.sql`
      SELECT h."entity_id" AS "entityId"
      FROM "contribution_history_entries" h
      LEFT JOIN "dj_contributors" c ON c."dj_id" = h."entity_id"
      WHERE h."entity_type" = 'dj'
        ${historyWhere}
      GROUP BY h."entity_id"
      HAVING COUNT(c."id") = 0
      ORDER BY h."entity_id" ASC
      LIMIT 10
    `),
    prisma.$queryRaw<Array<{ entityId: string }>>(Prisma.sql`
      SELECT c."dj_id" AS "entityId"
      FROM "dj_contributors" c
      ${registryWhere}
      GROUP BY c."dj_id"
      HAVING SUM(CASE WHEN c."role" = 'creator' THEN 1 ELSE 0 END) = 0
      ORDER BY MAX(c."last_contributed_at") DESC
      LIMIT 10
    `),
    prisma.$queryRaw<Array<{ entityId: string }>>(Prisma.sql`
      SELECT c."dj_id" AS "entityId"
      FROM "dj_contributors" c
      ${registryWhere}
      GROUP BY c."dj_id"
      ORDER BY MAX(c."last_contributed_at") DESC
      LIMIT ${sampleSize}
    `),
  ]);

  return {
    entityType,
    historyRowCount,
    historyDistinctEntityCount,
    historyCreatorEntityCount,
    registryRowCount,
    registryDistinctEntityCount,
    registryCreatorEntityCount,
    missingRegistryEntityIds: missingRegistryRows.map((row) => row.entityId),
    missingCreatorEntityIds: missingCreatorRows.map((row) => row.entityId),
    sampledEntityIds: sampleRows.map((row) => row.entityId),
  };
};

const loadRegistryEntries = async (
  entityType: EntityType,
  entityId: string
): Promise<RegistryEntry[]> => {
  if (entityType === 'event') {
    const rows = await prisma.eventContributor.findMany({
      where: { eventId: entityId },
      orderBy: [
        { role: 'asc' },
        { lastContributedAt: 'desc' },
        { createdAt: 'desc' },
      ],
      select: {
        eventId: true,
        userId: true,
        role: true,
        firstContributedAt: true,
        lastContributedAt: true,
        contributionCount: true,
      },
    });
    return rows.map((row) => ({
      entityId: row.eventId,
      userId: row.userId,
      role: row.role === 'creator' ? 'creator' : 'editor',
      firstContributedAt: row.firstContributedAt,
      lastContributedAt: row.lastContributedAt,
      contributionCount: row.contributionCount,
    }));
  }

  const rows = await prisma.dJContributor.findMany({
    where: { djId: entityId },
    orderBy: [
      { role: 'asc' },
      { lastContributedAt: 'desc' },
      { createdAt: 'desc' },
    ],
    select: {
      djId: true,
      userId: true,
      role: true,
      firstContributedAt: true,
      lastContributedAt: true,
      contributionCount: true,
    },
  });
  return rows.map((row) => ({
    entityId: row.djId,
    userId: row.userId,
    role: row.role === 'creator' ? 'creator' : 'editor',
    firstContributedAt: row.firstContributedAt,
    lastContributedAt: row.lastContributedAt,
    contributionCount: row.contributionCount,
  }));
};

const loadHistoryEntries = async (
  entityType: EntityType,
  entityId: string
): Promise<HistoryEntry[]> => {
  const rows = await prisma.contributionHistoryEntry.findMany({
    where: {
      entityType,
      entityId,
    },
    orderBy: [
      { occurredAt: 'asc' },
      { createdAt: 'asc' },
      { id: 'asc' },
    ],
    select: {
      id: true,
      entityId: true,
      userId: true,
      roleSnapshot: true,
      occurredAt: true,
      createdAt: true,
    },
  });

  return rows.map((row) => ({
    id: row.id,
    entityId: row.entityId,
    userId: row.userId,
    role: row.roleSnapshot === 'creator' ? 'creator' : 'editor',
    occurredAt: row.occurredAt,
    createdAt: row.createdAt,
  }));
};

const aggregateHistoryEntries = (rows: HistoryEntry[]): Map<string, HistoryAggregate> => {
  const map = new Map<string, HistoryAggregate>();
  for (const row of rows) {
    const existing = map.get(row.userId);
    if (!existing) {
      map.set(row.userId, {
        userId: row.userId,
        count: 1,
        firstOccurredAt: row.occurredAt,
        lastOccurredAt: row.occurredAt,
        hasCreatorRole: row.role === 'creator',
      });
      continue;
    }

    existing.count += 1;
    if (row.occurredAt.getTime() < existing.firstOccurredAt.getTime()) {
      existing.firstOccurredAt = row.occurredAt;
    }
    if (row.occurredAt.getTime() > existing.lastOccurredAt.getTime()) {
      existing.lastOccurredAt = row.occurredAt;
    }
    existing.hasCreatorRole = existing.hasCreatorRole || row.role === 'creator';
  }
  return map;
};

const validateSample = async (
  entityType: EntityType,
  entityId: string
): Promise<ValidationIssue[]> => {
  const [registryEntries, historyEntries] = await Promise.all([
    loadRegistryEntries(entityType, entityId),
    loadHistoryEntries(entityType, entityId),
  ]);

  const issues: ValidationIssue[] = [];

  if (historyEntries.length > 0 && registryEntries.length === 0) {
    issues.push({
      severity: 'error',
      entityType,
      entityId,
      code: 'missing_registry_for_history',
      detail: 'History exists but contributor registry has no rows.',
    });
    return issues;
  }

  const creatorCount = registryEntries.filter((entry) => entry.role === 'creator').length;
  if (creatorCount === 0 && registryEntries.length > 0) {
    issues.push({
      severity: 'warning',
      entityType,
      entityId,
      code: 'missing_creator_registry',
      detail: 'Contributor registry has rows but no creator role.',
    });
  }
  if (creatorCount > 1) {
    issues.push({
      severity: 'error',
      entityType,
      entityId,
      code: 'multiple_creators_registry',
      detail: `Contributor registry has ${creatorCount} creator rows.`,
    });
  }

  for (const entry of registryEntries) {
    if (entry.contributionCount < 1) {
      issues.push({
        severity: 'error',
        entityType,
        entityId,
        code: 'invalid_registry_contribution_count',
        detail: `User ${entry.userId} has contributionCount=${entry.contributionCount}.`,
      });
    }
    if (entry.firstContributedAt.getTime() > entry.lastContributedAt.getTime()) {
      issues.push({
        severity: 'error',
        entityType,
        entityId,
        code: 'invalid_registry_timestamp_range',
        detail: `User ${entry.userId} has firstContributedAt later than lastContributedAt.`,
      });
    }
  }

  const registryByUser = new Map(registryEntries.map((entry) => [entry.userId, entry]));
  const historyByUser = aggregateHistoryEntries(historyEntries);

  for (const aggregate of historyByUser.values()) {
    const registryEntry = registryByUser.get(aggregate.userId);
    if (!registryEntry) {
      issues.push({
        severity: 'error',
        entityType,
        entityId,
        code: 'missing_registry_user',
        detail: `User ${aggregate.userId} exists in history but not in registry.`,
      });
      continue;
    }
    if (registryEntry.firstContributedAt.getTime() > aggregate.firstOccurredAt.getTime()) {
      issues.push({
        severity: 'error',
        entityType,
        entityId,
        code: 'registry_first_after_history',
        detail: `User ${aggregate.userId} registry firstContributedAt is later than history first occurrence.`,
      });
    }
    if (registryEntry.lastContributedAt.getTime() < aggregate.lastOccurredAt.getTime()) {
      issues.push({
        severity: 'error',
        entityType,
        entityId,
        code: 'registry_last_before_history',
        detail: `User ${aggregate.userId} registry lastContributedAt is earlier than history last occurrence.`,
      });
    }
    if (registryEntry.contributionCount < aggregate.count) {
      issues.push({
        severity: 'error',
        entityType,
        entityId,
        code: 'registry_count_less_than_history',
        detail: `User ${aggregate.userId} registry contributionCount=${registryEntry.contributionCount} but history count=${aggregate.count}.`,
      });
    }
    if (aggregate.hasCreatorRole && registryEntry.role !== 'creator') {
      issues.push({
        severity: 'error',
        entityType,
        entityId,
        code: 'registry_role_missing_creator',
        detail: `User ${aggregate.userId} has creator history but registry role=${registryEntry.role}.`,
      });
    }
  }

  logStep('sample_checked', {
    entityType,
    entityId,
    registryRows: registryEntries.length,
    historyRows: historyEntries.length,
    issueCount: issues.length,
  });

  return issues;
};

async function main(): Promise<void> {
  logStep('start', {
    selectedEntityTypes,
    sampleSize,
    selectedEventId,
    selectedDJId,
  });

  const summaries: TypeSummary[] = [];
  const issues: ValidationIssue[] = [];

  for (const entityType of selectedEntityTypes) {
    const summary = await loadTypeSummary(entityType);
    summaries.push(summary);
    logStep('type_summary', {
      entityType,
      historyRowCount: summary.historyRowCount,
      historyDistinctEntityCount: summary.historyDistinctEntityCount,
      historyCreatorEntityCount: summary.historyCreatorEntityCount,
      registryRowCount: summary.registryRowCount,
      registryDistinctEntityCount: summary.registryDistinctEntityCount,
      registryCreatorEntityCount: summary.registryCreatorEntityCount,
      missingRegistrySample: summary.missingRegistryEntityIds.slice(0, 5),
      missingCreatorSample: summary.missingCreatorEntityIds.slice(0, 5),
      sampledEntityCount: summary.sampledEntityIds.length,
    });

    for (const entityId of summary.sampledEntityIds) {
      const sampleIssues = await validateSample(entityType, entityId);
      issues.push(...sampleIssues);
    }
  }

  const warnings = issues.filter((issue) => issue.severity === 'warning');
  const errors = issues.filter((issue) => issue.severity === 'error');

  logStep('complete', {
    warningCount: warnings.length,
    errorCount: errors.length,
    warningSample: warnings.slice(0, 10),
    errorSample: errors.slice(0, 10),
  });

  if (errors.length > 0) {
    process.exitCode = 1;
  }
}

void main()
  .catch((error: unknown) => {
    console.error('[verify-contribution-module-backfill] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
