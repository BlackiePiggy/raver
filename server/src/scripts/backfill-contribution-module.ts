import 'dotenv/config';
import { Prisma, PrismaClient } from '@prisma/client';
import crypto from 'node:crypto';
import { changeSummaryTextFromPayload } from '../services/content-submission-change-summary.service';

const prisma = new PrismaClient();

const BACKFILL_MODULE_KEY = 'contribution_module_phase8';
const dryRun = process.env.CONTRIBUTION_MODULE_BACKFILL_APPLY !== '1';
const batchSize = Math.max(50, Number(process.env.CONTRIBUTION_MODULE_BACKFILL_BATCH_SIZE || 500));
const readBatchSize = Math.max(5, Number(process.env.CONTRIBUTION_MODULE_BACKFILL_READ_BATCH_SIZE || 10));
const legacyDJReadBatchSize = Math.max(50, Number(process.env.CONTRIBUTION_MODULE_BACKFILL_DJ_LEGACY_READ_BATCH_SIZE || 500));
const maxReadRetries = Math.max(1, Number(process.env.CONTRIBUTION_MODULE_BACKFILL_READ_RETRIES || 3));
const parsePositiveInt = (value: string | undefined): number | null => {
  if (!value) return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return null;
  return Math.floor(parsed);
};
const cleanText = (value: unknown): string | undefined => {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed || undefined;
};
const selectedEntityTypes = (() => {
  const raw = String(process.env.CONTRIBUTION_MODULE_BACKFILL_ENTITY_TYPES || 'event,dj')
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
  const values = Array.from(new Set(raw.filter((item) => item === 'event' || item === 'dj')));
  if (values.length === 0) {
    throw new Error('CONTRIBUTION_MODULE_BACKFILL_ENTITY_TYPES must include event and/or dj');
  }
  return values as Array<'event' | 'dj'>;
})();
const scopedEntityLimit = parsePositiveInt(process.env.CONTRIBUTION_MODULE_BACKFILL_LIMIT);
const selectedEventId = cleanText(process.env.CONTRIBUTION_MODULE_BACKFILL_EVENT_ID) ?? null;
const selectedDJId = cleanText(process.env.CONTRIBUTION_MODULE_BACKFILL_DJ_ID) ?? null;

type BackfillEntityType = 'event' | 'dj';
type ContributionRole = 'creator' | 'editor';
type ContributionActionType = 'create' | 'edit';
type BackfillScope = {
  eventIds: string[] | null;
  djIds: string[] | null;
};

type ApprovedSubmissionRecord = {
  id: string;
  entityType: BackfillEntityType;
  submitterId: string;
  title: string;
  payload: Prisma.JsonValue;
  reviewedAt: Date | null;
  createdAt: Date;
  createdEntityId: string;
};

type EntitySnapshot = {
  title: string | null;
  coverImageUrl: string | null;
  createdAt: Date;
};

type BackfillHistoryRecord = {
  userId: string;
  entityType: BackfillEntityType;
  entityId: string;
  title: string | null;
  coverImageUrl: string | null;
  role: ContributionRole;
  actionType: ContributionActionType;
  submissionId: string | null;
  occurredAt: Date;
  approvedAt: Date | null;
  changeSummary: string | null;
  metadata: Prisma.InputJsonObject;
};

type LegacyDJContributorSeed = {
  djId: string;
  userId: string;
  role: ContributionRole;
  firstContributedAt: Date;
  lastContributedAt: Date;
  contributionCount: number;
  firstSubmissionId: string | null;
  lastSubmissionId: string | null;
  lastContributionSource: string | null;
  createdAt: Date;
  updatedAt: Date;
};

type RegistryAggregate = {
  entityType: BackfillEntityType;
  entityId: string;
  userId: string;
  role: ContributionRole;
  firstContributedAt: Date;
  lastContributedAt: Date;
  contributionCount: number;
  firstSubmissionId: string | null;
  lastSubmissionId: string | null;
  lastContributionSource: string | null;
  createdAt: Date;
  updatedAt: Date;
};

type BuildBackfillResult = {
  historyRecords: BackfillHistoryRecord[];
  legacyDJSeeds: LegacyDJContributorSeed[];
  unresolvedEventCreatorIds: string[];
  unresolvedDJCreatorIds: string[];
  counts: {
    approvedSubmissionRecords: number;
    eventOrganizerFallbackRecords: number;
    djSingleLegacyFallbackRecords: number;
    legacyDJSeedRows: number;
  };
};

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[backfill-contribution-module]', step, detail || {});
};

const chunk = <T>(items: T[], size: number): T[][] => {
  if (items.length === 0) return [];
  const result: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    result.push(items.slice(index, index + size));
  }
  return result;
};

const minDate = (left: Date, right: Date): Date => (left.getTime() <= right.getTime() ? left : right);
const maxDate = (left: Date, right: Date): Date => (left.getTime() >= right.getTime() ? left : right);
const uniqueValues = <T>(items: T[]): T[] => Array.from(new Set(items));
const sleep = (ms: number): Promise<void> => new Promise((resolve) => setTimeout(resolve, ms));
const isRetryableReadError = (error: unknown): boolean => {
  if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P1017') {
    return true;
  }
  if (error instanceof Error) {
    const message = error.message.toLowerCase();
    return message.includes('server has closed the connection')
      || message.includes('connection')
      || message.includes('socket');
  }
  return false;
};

const withReadRetry = async <T>(
  label: string,
  run: (attempt: number) => Promise<T>
): Promise<T> => {
  let lastError: unknown;
  for (let attempt = 1; attempt <= maxReadRetries; attempt += 1) {
    try {
      return await run(attempt);
    } catch (error) {
      lastError = error;
      if (!isRetryableReadError(error) || attempt >= maxReadRetries) {
        throw error;
      }
      logStep('read_retry', {
        label,
        attempt,
        maxReadRetries,
        reason: error instanceof Error ? error.message : String(error),
      });
      await sleep(attempt * 500);
    }
  }
  throw lastError;
};

const buildEntityIdFilter = (
  scopeIds: string[] | null
): Prisma.StringFilter<'ContentSubmission'> | string | undefined => {
  if (scopeIds === null) return undefined;
  if (scopeIds.length === 0) return { in: [] };
  return { in: scopeIds };
};

const loadScopedEntityIds = async (
  entityType: BackfillEntityType
): Promise<string[] | null> => {
  if (entityType === 'event' && selectedEventId) {
    return [selectedEventId];
  }
  if (entityType === 'dj' && selectedDJId) {
    return [selectedDJId];
  }
  if (!scopedEntityLimit) {
    return null;
  }

  logStep('scope_ids_loading', {
    entityType,
    scopedEntityLimit,
  });

  if (entityType === 'event') {
    const rows = await prisma.event.findMany({
      select: { id: true },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      take: scopedEntityLimit,
    });
    const ids = rows.map((row) => row.id);
    logStep('scope_ids_ready', {
      entityType,
      scopedEntityLimit,
      matchedEntityCount: ids.length,
    });
    return ids;
  }

  const rows = await prisma.dJ.findMany({
    select: { id: true },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    take: scopedEntityLimit,
  });
  const ids = rows.map((row) => row.id);
  logStep('scope_ids_ready', {
    entityType,
    scopedEntityLimit,
    matchedEntityCount: ids.length,
  });
  return ids;
};

const loadBackfillScope = async (): Promise<BackfillScope> => {
  const eventIds = selectedEntityTypes.includes('event')
    ? await loadScopedEntityIds('event')
    : null;
  const djIds = selectedEntityTypes.includes('dj')
    ? await loadScopedEntityIds('dj')
    : null;

  logStep('scope_ready', {
    eventScopeCount: eventIds?.length ?? 'all',
    djScopeCount: djIds?.length ?? 'all',
    selectedEventId,
    selectedDJId,
    scopedEntityLimit,
  });

  return { eventIds, djIds };
};

const inferSubmissionActionType = (
  entityType: BackfillEntityType,
  payload: Prisma.JsonObject
): ContributionActionType => {
  const targetId = entityType === 'event'
    ? cleanText(payload.targetEventId) || cleanText(payload.editTargetEventId)
    : cleanText(payload.targetDJId) || cleanText(payload.editTargetDJId);
  return targetId ? 'edit' : 'create';
};

const inferOccurredAt = (record: { reviewedAt: Date | null; createdAt: Date }): Date =>
  record.reviewedAt ?? record.createdAt;

const buildBackfillKey = (
  entityType: BackfillEntityType,
  entityId: string,
  userId: string,
  actionType: ContributionActionType,
  submissionId: string | null,
  discriminator: string
): string => [
  BACKFILL_MODULE_KEY,
  entityType,
  entityId,
  userId,
  actionType,
  submissionId || 'none',
  discriminator,
].join(':');

const loadApprovedSubmissionRecords = async (scope: BackfillScope): Promise<ApprovedSubmissionRecord[]> => {
  type ApprovedSubmissionMetaRow = {
    id: string;
    entityType: string;
    submitterId: string;
    title: string;
    reviewedAt: Date | null;
    createdAt: Date;
    createdEntityId: string | null;
  };

  const scopedClauses: Prisma.ContentSubmissionWhereInput[] = [];
  const scopedEventIds = selectedEntityTypes.includes('event')
    ? buildEntityIdFilter(scope.eventIds)
    : undefined;
  const scopedDJIds = selectedEntityTypes.includes('dj')
    ? buildEntityIdFilter(scope.djIds)
    : undefined;

  if (selectedEntityTypes.includes('event')) {
    scopedClauses.push({
      entityType: 'event',
      ...(scopedEventIds ? { createdEntityId: scopedEventIds } : {}),
    });
  }
  if (selectedEntityTypes.includes('dj')) {
    scopedClauses.push({
      entityType: 'dj',
      ...(scopedDJIds ? { createdEntityId: scopedDJIds } : {}),
    });
  }

  logStep('approved_submissions_loading', {
    selectedEntityTypes,
    scopedClauseCount: scopedClauses.length,
    readBatchSize,
    maxReadRetries,
  });

  const where: Prisma.ContentSubmissionWhereInput = {
    status: 'approved',
    createdEntityId: { not: null },
    ...(scopedClauses.length > 0 ? { OR: scopedClauses } : { entityType: { in: selectedEntityTypes } }),
  };

  const records: ApprovedSubmissionRecord[] = [];
  let cursorId: string | null = null;
  let page = 0;

  while (true) {
    const metaStartedAt = Date.now();
    const metaRows = await withReadRetry('approved_submissions_meta_page', async () =>
      prisma.contentSubmission.findMany({
        where,
        orderBy: [{ id: 'asc' }],
        ...(cursorId ? { cursor: { id: cursorId }, skip: 1 } : {}),
        take: readBatchSize,
        select: {
          id: true,
          entityType: true,
          submitterId: true,
          title: true,
          reviewedAt: true,
          createdAt: true,
          createdEntityId: true,
        },
      })
    );

    if (metaRows.length === 0) {
      break;
    }

    logStep('approved_submissions_meta_page_loaded', {
      page: page + 1,
      pageRowCount: metaRows.length,
      elapsedMs: Date.now() - metaStartedAt,
      lastCursorId: metaRows[metaRows.length - 1]?.id ?? null,
    });

    const payloadStartedAt = Date.now();
    const payloadRows = await withReadRetry('approved_submissions_payload_page', async () =>
      prisma.contentSubmission.findMany({
        where: {
          id: {
            in: metaRows.map((row) => row.id),
          },
        },
        select: {
          id: true,
          payload: true,
        },
      })
    );
    const payloadById = new Map(payloadRows.map((row) => [row.id, row.payload]));

    logStep('approved_submissions_payload_page_loaded', {
      page: page + 1,
      pageRowCount: payloadRows.length,
      elapsedMs: Date.now() - payloadStartedAt,
    });

    page += 1;
    const mappedRows: ApprovedSubmissionRecord[] = (metaRows as ApprovedSubmissionMetaRow[])
      .filter((row): row is ApprovedSubmissionMetaRow & { createdEntityId: string } => Boolean(row.createdEntityId))
      .map((row) => ({
        id: row.id,
        entityType: row.entityType === 'event' ? 'event' as const : 'dj' as const,
        submitterId: row.submitterId,
        title: row.title,
        payload: payloadById.get(row.id) ?? {},
        reviewedAt: row.reviewedAt,
        createdAt: row.createdAt,
        createdEntityId: row.createdEntityId,
      }));

    records.push(...mappedRows);
    cursorId = metaRows[metaRows.length - 1]?.id ?? null;

    logStep('approved_submissions_page_loaded', {
      page,
      pageRowCount: metaRows.length,
      accumulatedRowCount: records.length,
      lastCursorId: cursorId,
    });

    if (metaRows.length < readBatchSize) {
      break;
    }
  }

  logStep('approved_submissions_loaded', {
    count: records.length,
    eventCount: records.filter((row) => row.entityType === 'event').length,
    djCount: records.filter((row) => row.entityType === 'dj').length,
  });

  return records;
};

const loadEntitySnapshots = async (
  entityType: BackfillEntityType,
  ids: string[]
): Promise<Map<string, EntitySnapshot>> => {
  const uniqueIds = uniqueValues(ids.map((item) => item.trim()).filter(Boolean));
  if (uniqueIds.length === 0) return new Map();

  logStep('entity_snapshots_loading', {
    entityType,
    entityCount: uniqueIds.length,
  });

  if (entityType === 'event') {
    const rows = await prisma.event.findMany({
      where: { id: { in: uniqueIds } },
      select: {
        id: true,
        name: true,
        coverImageUrl: true,
        createdAt: true,
      },
    });
    return new Map(rows.map((row) => [
      row.id,
      {
        title: row.name,
        coverImageUrl: row.coverImageUrl ?? null,
        createdAt: row.createdAt,
      },
    ]));
  }

  const rows = await prisma.dJ.findMany({
    where: { id: { in: uniqueIds } },
    select: {
      id: true,
      name: true,
      avatarUrl: true,
      createdAt: true,
    },
  });
  return new Map(rows.map((row) => [
    row.id,
    {
      title: row.name,
      coverImageUrl: row.avatarUrl ?? null,
      createdAt: row.createdAt,
    },
  ]));
};

const buildApprovedSubmissionBackfillRecords = async (
  submissions: ApprovedSubmissionRecord[]
): Promise<BackfillHistoryRecord[]> => {
  logStep('approved_submission_records_building', {
    submissionCount: submissions.length,
    eventEntityCount: uniqueValues(
      submissions.filter((item) => item.entityType === 'event').map((item) => item.createdEntityId)
    ).length,
    djEntityCount: uniqueValues(
      submissions.filter((item) => item.entityType === 'dj').map((item) => item.createdEntityId)
    ).length,
  });

  const eventSnapshots = await loadEntitySnapshots(
    'event',
    submissions.filter((item) => item.entityType === 'event').map((item) => item.createdEntityId)
  );
  const djSnapshots = await loadEntitySnapshots(
    'dj',
    submissions.filter((item) => item.entityType === 'dj').map((item) => item.createdEntityId)
  );

  const rows = submissions.map((submission) => {
    const payload = submission.payload && typeof submission.payload === 'object' && !Array.isArray(submission.payload)
      ? submission.payload as Prisma.JsonObject
      : {};
    const actionType = inferSubmissionActionType(submission.entityType, payload);
    const role: ContributionRole = actionType === 'create' ? 'creator' : 'editor';
    const snapshot = submission.entityType === 'event'
      ? eventSnapshots.get(submission.createdEntityId)
      : djSnapshots.get(submission.createdEntityId);
    const occurredAt = inferOccurredAt(submission);
    const backfillKey = buildBackfillKey(
      submission.entityType,
      submission.createdEntityId,
      submission.submitterId,
      actionType,
      submission.id,
      'approved_submission'
    );

    return {
      userId: submission.submitterId,
      entityType: submission.entityType,
      entityId: submission.createdEntityId,
      title: submission.title || snapshot?.title || null,
      coverImageUrl: snapshot?.coverImageUrl ?? null,
      role,
      actionType,
      submissionId: submission.id,
      occurredAt,
      approvedAt: submission.reviewedAt ?? occurredAt,
      changeSummary: changeSummaryTextFromPayload(payload),
      metadata: {
        backfillModule: BACKFILL_MODULE_KEY,
        backfillKey,
        backfillKind: 'approved_submission',
        confidence: 'high',
      },
    };
  });

  logStep('approved_submission_records_built', {
    count: rows.length,
  });

  return rows;
};

const buildEventOrganizerFallbackRecords = async (
  existingCreateEventIds: Set<string>,
  scope: BackfillScope
): Promise<{
  records: BackfillHistoryRecord[];
  unresolvedEventCreatorIds: string[];
}> => {
  logStep('event_fallback_loading', {
    existingCreateEventIds: existingCreateEventIds.size,
    scopedEventCount: scope.eventIds?.length ?? 'all',
  });

  const events = await prisma.event.findMany({
    where: scope.eventIds === null
      ? {}
      : { id: { in: scope.eventIds } },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    select: {
      id: true,
      name: true,
      coverImageUrl: true,
      organizerId: true,
      createdAt: true,
    },
  });

  const records: BackfillHistoryRecord[] = [];
  const unresolvedEventCreatorIds: string[] = [];

  for (const event of events) {
    if (existingCreateEventIds.has(event.id)) continue;
    if (!event.organizerId) {
      unresolvedEventCreatorIds.push(event.id);
      continue;
    }

    const backfillKey = buildBackfillKey(
      'event',
      event.id,
      event.organizerId,
      'create',
      null,
      'event_organizer_fallback'
    );

    records.push({
      userId: event.organizerId,
      entityType: 'event',
      entityId: event.id,
      title: event.name,
      coverImageUrl: event.coverImageUrl ?? null,
      role: 'creator',
      actionType: 'create',
      submissionId: null,
      occurredAt: event.createdAt,
      approvedAt: null,
      changeSummary: null,
      metadata: {
        backfillModule: BACKFILL_MODULE_KEY,
        backfillKey,
        backfillKind: 'event_organizer_fallback',
        confidence: 'high',
      },
    });
  }

  logStep('event_fallback_built', {
    scannedEvents: events.length,
    fallbackRecordCount: records.length,
    unresolvedEventCreatorCount: unresolvedEventCreatorIds.length,
  });

  return { records, unresolvedEventCreatorIds };
};

const buildDJLegacySeedsAndFallbackRecords = async (
  existingCreateDJIds: Set<string>,
  scope: BackfillScope
): Promise<{
  legacySeeds: LegacyDJContributorSeed[];
  fallbackRecords: BackfillHistoryRecord[];
  unresolvedDJCreatorIds: string[];
}> => {
  type LegacyDJContributorRow = {
    id: string;
    djId: string;
    userId: string;
    role: string;
    firstContributedAt: Date;
    lastContributedAt: Date;
    contributionCount: number;
    firstSubmissionId: string | null;
    lastSubmissionId: string | null;
    lastContributionSource: string | null;
    createdAt: Date;
    updatedAt: Date;
    dj: {
      name: string;
      avatarUrl: string | null;
      createdAt: Date;
    };
  };

  logStep('dj_legacy_loading', {
    existingCreateDJIds: existingCreateDJIds.size,
    scopedDJCount: scope.djIds?.length ?? 'all',
    legacyDJReadBatchSize,
  });

  const grouped = new Map<string, LegacyDJContributorRow[]>();
  const where = scope.djIds === null
    ? undefined
    : { djId: { in: scope.djIds } };
  let cursorId: string | null = null;
  let page = 0;
  let scannedContributorRows = 0;

  while (true) {
    const startedAt = Date.now();
    const rows = await withReadRetry('dj_legacy_page', async () =>
      prisma.dJContributor.findMany({
        where,
        orderBy: [{ id: 'asc' }],
        ...(cursorId ? { cursor: { id: cursorId }, skip: 1 } : {}),
        take: legacyDJReadBatchSize,
        select: {
          id: true,
          djId: true,
          userId: true,
          role: true,
          firstContributedAt: true,
          lastContributedAt: true,
          contributionCount: true,
          firstSubmissionId: true,
          lastSubmissionId: true,
          lastContributionSource: true,
          createdAt: true,
          updatedAt: true,
          dj: {
            select: {
              name: true,
              avatarUrl: true,
              createdAt: true,
            },
          },
        },
      })
    );

    if (rows.length === 0) {
      break;
    }

    page += 1;
    scannedContributorRows += rows.length;
    cursorId = rows[rows.length - 1]?.id ?? null;

    logStep('dj_legacy_page_loaded', {
      page,
      pageRowCount: rows.length,
      accumulatedRowCount: scannedContributorRows,
      elapsedMs: Date.now() - startedAt,
      lastCursorId: cursorId,
    });

    for (const row of rows) {
      const list = grouped.get(row.djId) || [];
      list.push(row);
      grouped.set(row.djId, list);
    }

    if (rows.length < legacyDJReadBatchSize) {
      break;
    }
  }

  for (const contributors of grouped.values()) {
    contributors.sort((left, right) =>
      left.createdAt.getTime() - right.createdAt.getTime()
      || left.updatedAt.getTime() - right.updatedAt.getTime()
      || left.id.localeCompare(right.id)
    );
  }

  const legacySeeds: LegacyDJContributorSeed[] = [];
  const fallbackRecords: BackfillHistoryRecord[] = [];
  const unresolvedDJCreatorIds: string[] = [];

  for (const [djId, contributors] of grouped.entries()) {
    const contributorCount = contributors.length;
    const hasCreateSubmission = existingCreateDJIds.has(djId);

    for (const contributor of contributors) {
      const inferredRole: ContributionRole = hasCreateSubmission
        ? (contributor.role === 'creator' ? 'creator' : 'editor')
        : contributorCount === 1
          ? 'creator'
          : 'editor';

      legacySeeds.push({
        djId,
        userId: contributor.userId,
        role: inferredRole,
        firstContributedAt: contributor.firstContributedAt ?? contributor.createdAt,
        lastContributedAt: contributor.lastContributedAt ?? contributor.updatedAt,
        contributionCount: Math.max(1, contributor.contributionCount ?? 1),
        firstSubmissionId: contributor.firstSubmissionId ?? null,
        lastSubmissionId: contributor.lastSubmissionId ?? null,
        lastContributionSource: contributor.lastContributionSource ?? 'backfill_legacy_registry',
        createdAt: contributor.createdAt,
        updatedAt: contributor.updatedAt,
      });
    }

    if (hasCreateSubmission) continue;

    if (contributorCount === 1) {
      const contributor = contributors[0];
      const occurredAt = minDate(contributor.dj.createdAt, contributor.createdAt);
      const backfillKey = buildBackfillKey(
        'dj',
        djId,
        contributor.userId,
        'create',
        null,
        'dj_single_legacy_contributor_fallback'
      );

      fallbackRecords.push({
        userId: contributor.userId,
        entityType: 'dj',
        entityId: djId,
        title: contributor.dj.name,
        coverImageUrl: contributor.dj.avatarUrl ?? null,
        role: 'creator',
        actionType: 'create',
        submissionId: null,
        occurredAt,
        approvedAt: null,
        changeSummary: null,
        metadata: {
          backfillModule: BACKFILL_MODULE_KEY,
          backfillKey,
          backfillKind: 'dj_single_legacy_contributor_fallback',
          confidence: 'medium',
        },
      });
      continue;
    }

    unresolvedDJCreatorIds.push(djId);
  }

  logStep('dj_legacy_built', {
    scannedContributorRows,
    legacySeedCount: legacySeeds.length,
    fallbackRecordCount: fallbackRecords.length,
    unresolvedDJCreatorCount: unresolvedDJCreatorIds.length,
  });

  return {
    legacySeeds,
    fallbackRecords,
    unresolvedDJCreatorIds,
  };
};

const dedupeHistoryRecords = (records: BackfillHistoryRecord[]): BackfillHistoryRecord[] => {
  const map = new Map<string, BackfillHistoryRecord>();
  for (const record of records) {
    const key = String(record.metadata.backfillKey || '');
    if (!key) continue;
    map.set(key, record);
  }
  return Array.from(map.values()).sort((left, right) =>
    left.occurredAt.getTime() - right.occurredAt.getTime()
    || left.entityType.localeCompare(right.entityType)
    || left.entityId.localeCompare(right.entityId)
    || left.userId.localeCompare(right.userId)
  );
};

const buildBackfillData = async (scope: BackfillScope): Promise<BuildBackfillResult> => {
  const submissions = (await loadApprovedSubmissionRecords(scope))
    .filter((item) => selectedEntityTypes.includes(item.entityType));
  const approvedSubmissionRecords = await buildApprovedSubmissionBackfillRecords(submissions);

  const existingCreateEventIds = new Set(
    approvedSubmissionRecords
      .filter((item) => item.entityType === 'event' && item.actionType === 'create')
      .map((item) => item.entityId)
  );
  const existingCreateDJIds = new Set(
    approvedSubmissionRecords
      .filter((item) => item.entityType === 'dj' && item.actionType === 'create')
      .map((item) => item.entityId)
  );

  const eventFallback = selectedEntityTypes.includes('event')
    ? await buildEventOrganizerFallbackRecords(existingCreateEventIds, scope)
    : { records: [] as BackfillHistoryRecord[], unresolvedEventCreatorIds: [] as string[] };

  const djFallback = selectedEntityTypes.includes('dj')
    ? await buildDJLegacySeedsAndFallbackRecords(existingCreateDJIds, scope)
    : {
        legacySeeds: [] as LegacyDJContributorSeed[],
        fallbackRecords: [] as BackfillHistoryRecord[],
        unresolvedDJCreatorIds: [] as string[],
      };

  logStep('history_records_deduping', {
    rawHistoryRecordCount:
      approvedSubmissionRecords.length + eventFallback.records.length + djFallback.fallbackRecords.length,
  });

  const historyRecords = dedupeHistoryRecords([
    ...approvedSubmissionRecords,
    ...eventFallback.records,
    ...djFallback.fallbackRecords,
  ]);

  logStep('history_records_deduped', {
    dedupedHistoryRecordCount: historyRecords.length,
  });

  return {
    historyRecords,
    legacyDJSeeds: djFallback.legacySeeds,
    unresolvedEventCreatorIds: eventFallback.unresolvedEventCreatorIds,
    unresolvedDJCreatorIds: djFallback.unresolvedDJCreatorIds,
    counts: {
      approvedSubmissionRecords: approvedSubmissionRecords.length,
      eventOrganizerFallbackRecords: eventFallback.records.length,
      djSingleLegacyFallbackRecords: djFallback.fallbackRecords.length,
      legacyDJSeedRows: djFallback.legacySeeds.length,
    },
  };
};

const insertBackfillHistoryRecords = async (
  tx: Prisma.TransactionClient,
  records: BackfillHistoryRecord[]
): Promise<void> => {
  for (const batch of chunk(records, batchSize)) {
    await tx.contributionHistoryEntry.createMany({
      data: batch.map((record) => ({
        id: crypto.randomUUID(),
        userId: record.userId,
        entityType: record.entityType,
        entityId: record.entityId,
        entityTitleSnapshot: record.title,
        entityCoverSnapshot: record.coverImageUrl,
        roleSnapshot: record.role,
        actionType: record.actionType,
        source: 'backfill',
        submissionId: record.submissionId,
        occurredAt: record.occurredAt,
        approvedAt: record.approvedAt,
        versionAfter: null,
        changeSummary: record.changeSummary,
        metadata: record.metadata,
        createdAt: new Date(),
      })),
    });
  }
};

const aggregateRegistryFromHistory = async (
  tx: Prisma.TransactionClient
): Promise<Map<string, RegistryAggregate>> => {
  const rows = await tx.contributionHistoryEntry.findMany({
    where: {
      entityType: { in: selectedEntityTypes },
    },
    orderBy: [{ occurredAt: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
    select: {
      entityType: true,
      entityId: true,
      userId: true,
      roleSnapshot: true,
      submissionId: true,
      source: true,
      occurredAt: true,
      createdAt: true,
    },
  });

  const map = new Map<string, RegistryAggregate>();
  for (const row of rows) {
    const entityType = row.entityType === 'event' ? 'event' : 'dj';
    const key = `${entityType}:${row.entityId}:${row.userId}`;
    const existing = map.get(key);
    if (!existing) {
      map.set(key, {
        entityType,
        entityId: row.entityId,
        userId: row.userId,
        role: row.roleSnapshot === 'creator' ? 'creator' : 'editor',
        firstContributedAt: row.occurredAt,
        lastContributedAt: row.occurredAt,
        contributionCount: 1,
        firstSubmissionId: row.submissionId ?? null,
        lastSubmissionId: row.submissionId ?? null,
        lastContributionSource: row.source,
        createdAt: row.createdAt,
        updatedAt: row.createdAt,
      });
      continue;
    }

    existing.role = existing.role === 'creator' || row.roleSnapshot === 'creator' ? 'creator' : 'editor';
    existing.firstContributedAt = minDate(existing.firstContributedAt, row.occurredAt);
    existing.lastContributedAt = maxDate(existing.lastContributedAt, row.occurredAt);
    existing.contributionCount += 1;
    if (!existing.firstSubmissionId && row.submissionId) {
      existing.firstSubmissionId = row.submissionId;
    }
    if (
      row.occurredAt.getTime() >= existing.lastContributedAt.getTime()
      || (row.occurredAt.getTime() === existing.lastContributedAt.getTime() && row.createdAt.getTime() >= existing.updatedAt.getTime())
    ) {
      existing.lastSubmissionId = row.submissionId ?? existing.lastSubmissionId;
      existing.lastContributionSource = row.source || existing.lastContributionSource;
      existing.updatedAt = row.createdAt;
    }
  }

  return map;
};

const mergeLegacyDJSeeds = (
  aggregates: Map<string, RegistryAggregate>,
  seeds: LegacyDJContributorSeed[]
): void => {
  for (const seed of seeds) {
    const key = `dj:${seed.djId}:${seed.userId}`;
    if (aggregates.has(key)) continue;
    aggregates.set(key, {
      entityType: 'dj',
      entityId: seed.djId,
      userId: seed.userId,
      role: seed.role,
      firstContributedAt: seed.firstContributedAt,
      lastContributedAt: seed.lastContributedAt,
      contributionCount: seed.contributionCount,
      firstSubmissionId: seed.firstSubmissionId,
      lastSubmissionId: seed.lastSubmissionId,
      lastContributionSource: seed.lastContributionSource,
      createdAt: seed.createdAt,
      updatedAt: seed.updatedAt,
    });
  }
};

const rebuildContributorRegistries = async (
  tx: Prisma.TransactionClient,
  aggregates: Map<string, RegistryAggregate>
): Promise<void> => {
  if (selectedEntityTypes.includes('event')) {
    await tx.eventContributor.deleteMany({});
    const eventRows = Array.from(aggregates.values()).filter((item) => item.entityType === 'event');
    for (const batch of chunk(eventRows, batchSize)) {
      await tx.eventContributor.createMany({
        data: batch.map((row) => ({
          id: crypto.randomUUID(),
          eventId: row.entityId,
          userId: row.userId,
          role: row.role,
          firstContributedAt: row.firstContributedAt,
          lastContributedAt: row.lastContributedAt,
          contributionCount: row.contributionCount,
          firstSubmissionId: row.firstSubmissionId,
          lastSubmissionId: row.lastSubmissionId,
          lastContributionSource: row.lastContributionSource,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        })),
      });
    }
  }

  if (selectedEntityTypes.includes('dj')) {
    await tx.dJContributor.deleteMany({});
    const djRows = Array.from(aggregates.values()).filter((item) => item.entityType === 'dj');
    for (const batch of chunk(djRows, batchSize)) {
      await tx.dJContributor.createMany({
        data: batch.map((row) => ({
          id: crypto.randomUUID(),
          djId: row.entityId,
          userId: row.userId,
          role: row.role,
          firstContributedAt: row.firstContributedAt,
          lastContributedAt: row.lastContributedAt,
          contributionCount: row.contributionCount,
          firstSubmissionId: row.firstSubmissionId,
          lastSubmissionId: row.lastSubmissionId,
          lastContributionSource: row.lastContributionSource,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        })),
      });
    }
  }
};

const deletePreviousBackfillHistory = async (tx: Prisma.TransactionClient): Promise<void> => {
  const entityTypesSql = Prisma.join(selectedEntityTypes.map((item) => Prisma.sql`${item}`));
  await tx.$executeRaw(Prisma.sql`
    DELETE FROM "contribution_history_entries"
    WHERE "entity_type" IN (${entityTypesSql})
      AND COALESCE("metadata"->>'backfillModule', '') = ${BACKFILL_MODULE_KEY}
  `);
};

async function main(): Promise<void> {
  logStep('start', {
    dryRun,
    selectedEntityTypes,
    batchSize,
    readBatchSize,
    maxReadRetries,
    scopedEntityLimit,
    selectedEventId,
    selectedDJId,
  });

  const scope = await loadBackfillScope();
  const backfill = await buildBackfillData(scope);
  logStep('plan_ready', {
    historyRecords: backfill.historyRecords.length,
    legacyDJSeeds: backfill.legacyDJSeeds.length,
    unresolvedEventCreators: backfill.unresolvedEventCreatorIds.length,
    unresolvedDJCreators: backfill.unresolvedDJCreatorIds.length,
    ...backfill.counts,
  });

  if (backfill.unresolvedEventCreatorIds.length > 0) {
    logStep('unresolved_event_creators_sample', {
      sampleEventIds: backfill.unresolvedEventCreatorIds.slice(0, 10),
    });
  }
  if (backfill.unresolvedDJCreatorIds.length > 0) {
    logStep('unresolved_dj_creators_sample', {
      sampleDJIds: backfill.unresolvedDJCreatorIds.slice(0, 10),
    });
  }

  if (dryRun) {
    logStep('dry_run_complete', {
      historyRecords: backfill.historyRecords.length,
      legacyDJSeeds: backfill.legacyDJSeeds.length,
    });
    return;
  }

  await prisma.$transaction(async (tx) => {
    logStep('apply_delete_previous_history_start');
    await deletePreviousBackfillHistory(tx);
    logStep('apply_delete_previous_history_done');
    logStep('apply_insert_history_start', {
      historyRecords: backfill.historyRecords.length,
    });
    await insertBackfillHistoryRecords(tx, backfill.historyRecords);
    logStep('apply_insert_history_done');
    logStep('apply_aggregate_registry_start');
    const aggregates = await aggregateRegistryFromHistory(tx);
    logStep('apply_aggregate_registry_done', {
      aggregateCount: aggregates.size,
    });
    logStep('apply_merge_legacy_dj_seeds_start', {
      legacyDJSeeds: backfill.legacyDJSeeds.length,
    });
    mergeLegacyDJSeeds(aggregates, backfill.legacyDJSeeds);
    logStep('apply_merge_legacy_dj_seeds_done', {
      aggregateCountAfterMerge: aggregates.size,
    });
    logStep('apply_rebuild_registry_start');
    await rebuildContributorRegistries(tx, aggregates);
    logStep('apply_rebuild_registry_done');
  }, {
    timeout: 120_000,
    maxWait: 30_000,
  });

  logStep('applied', {
    historyRecords: backfill.historyRecords.length,
    legacyDJSeeds: backfill.legacyDJSeeds.length,
  });
}

void main()
  .catch((error: unknown) => {
    console.error('[backfill-contribution-module] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
