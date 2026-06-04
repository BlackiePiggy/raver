import { Prisma, PrismaClient } from '@prisma/client';
import crypto from 'crypto';

type DBClient = PrismaClient | Prisma.TransactionClient;

export type ContributionEntityType = 'event' | 'dj';
export type ContributionHistoryFilter = ContributionEntityType | 'all';
export type ContributionRole = 'creator' | 'editor';
export type ContributionActionType = 'create' | 'edit';

export type ContributorUser = {
  id: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
};

export type ContributorRegistryEntry = ContributorUser & {
  entityId: string;
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

export type ContributorSummary = {
  totalCount: number;
  creator: ContributorUser | null;
  previewUsers: ContributorUser[];
  displayName: string | null;
};

export type ContributorInfo = {
  userIds: string[];
  usernames: string[];
  users: ContributorUser[];
  uploadedByUsername: string | null;
  entries: ContributorRegistryEntry[];
  summary: ContributorSummary;
};

export type ContributionHistoryItem = {
  id: string;
  entityType: ContributionEntityType;
  entityId: string;
  entityTitle: string | null;
  entityCoverImageUrl: string | null;
  role: ContributionRole;
  actionType: ContributionActionType;
  source: string;
  submissionId: string | null;
  occurredAt: Date;
  approvedAt: Date | null;
  versionAfter: number | null;
  changeSummary: string | null;
  metadata: Prisma.JsonValue | null;
  createdAt: Date;
};

export type ContributionHistoryPage = {
  entityType: ContributionHistoryFilter;
  limit: number;
  items: ContributionHistoryItem[];
  nextCursor: string | null;
  hasMore: boolean;
};

export type ContributionCenterSummary = {
  totalContributionCount: number;
  contributedEventCount: number;
  contributedDJCount: number;
  lastContributionAt: Date | null;
  recentItems: ContributionHistoryItem[];
};

type ContributorRow = {
  entityId: string;
  userId: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
  role: string;
  firstContributedAt: Date;
  lastContributedAt: Date;
  contributionCount: number;
  firstSubmissionId: string | null;
  lastSubmissionId: string | null;
  lastContributionSource: string | null;
  createdAt: Date;
  updatedAt: Date;
};

type ContributionHistoryCursorPayload = {
  occurredAt: string;
  createdAt: string;
  id: string;
};

type ContributionHistoryRow = {
  id: string;
  entityType: string;
  entityId: string;
  entityTitleSnapshot: string | null;
  entityCoverSnapshot: string | null;
  roleSnapshot: string;
  actionType: string;
  source: string;
  submissionId: string | null;
  occurredAt: Date;
  approvedAt: Date | null;
  versionAfter: number | null;
  changeSummary: string | null;
  metadata: Prisma.JsonValue | null;
  createdAt: Date;
};

type ContributionCenterSummaryRow = {
  totalContributionCount: number;
  contributedEventCount: number;
  contributedDJCount: number;
  lastContributionAt: Date | null;
};

export type RecordContributionInput = {
  entityId: string;
  userId: string;
  title: string | null | undefined;
  coverImageUrl?: string | null | undefined;
  role: ContributionRole;
  actionType: ContributionActionType;
  source: string;
  submissionId?: string | null | undefined;
  occurredAt?: Date;
  approvedAt?: Date | null | undefined;
  versionAfter?: number | null | undefined;
  changeSummary?: string | null | undefined;
  metadata?: Prisma.JsonObject | Prisma.JsonArray | null | undefined;
};

export class InvalidContributionHistoryCursorError extends Error {
  constructor() {
    super('Invalid contribution history cursor');
    this.name = 'InvalidContributionHistoryCursorError';
  }
}

const emptyContributorSummary: ContributorSummary = {
  totalCount: 0,
  creator: null,
  previewUsers: [],
  displayName: null,
};

export const emptyContributorInfo: ContributorInfo = {
  userIds: [],
  usernames: [],
  users: [],
  uploadedByUsername: null,
  entries: [],
  summary: emptyContributorSummary,
};

const contributorUserFromRow = (row: ContributorRow): ContributorUser => ({
  id: row.userId,
  username: row.username,
  displayName: row.displayName,
  avatarUrl: row.avatarUrl,
});

const contributorUserFromEntry = (entry: ContributorRegistryEntry): ContributorUser => ({
  id: entry.id,
  username: entry.username,
  displayName: entry.displayName,
  avatarUrl: entry.avatarUrl,
});

const encodeContributionHistoryCursor = (row: Pick<ContributionHistoryRow, 'occurredAt' | 'createdAt' | 'id'>): string =>
  Buffer.from(
    JSON.stringify({
      occurredAt: row.occurredAt.toISOString(),
      createdAt: row.createdAt.toISOString(),
      id: row.id,
    } satisfies ContributionHistoryCursorPayload)
  ).toString('base64url');

const decodeContributionHistoryCursor = (cursor: string): ContributionHistoryCursorPayload => {
  try {
    const parsed = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8')) as Partial<ContributionHistoryCursorPayload>;
    const occurredAt = typeof parsed?.occurredAt === 'string' ? parsed.occurredAt : '';
    const createdAt = typeof parsed?.createdAt === 'string' ? parsed.createdAt : '';
    const id = typeof parsed?.id === 'string' ? parsed.id.trim() : '';
    if (!occurredAt || !createdAt || !id) {
      throw new InvalidContributionHistoryCursorError();
    }
    if (!Number.isFinite(new Date(occurredAt).getTime()) || !Number.isFinite(new Date(createdAt).getTime())) {
      throw new InvalidContributionHistoryCursorError();
    }
    return { occurredAt, createdAt, id };
  } catch (error) {
    if (error instanceof InvalidContributionHistoryCursorError) throw error;
    throw new InvalidContributionHistoryCursorError();
  }
};

export const buildContributorSummary = (entries: ContributorRegistryEntry[]): ContributorSummary => {
  if (entries.length === 0) return emptyContributorSummary;

  const creatorEntry = entries.find((item) => item.role === 'creator') ?? entries[0];
  const previewUsers = entries.slice(0, 3).map((item) => contributorUserFromEntry(item));

  return {
    totalCount: entries.length,
    creator: creatorEntry ? contributorUserFromEntry(creatorEntry) : null,
    previewUsers,
    displayName: creatorEntry?.displayName || creatorEntry?.username || null,
  };
};

const mapContributorRows = (rows: ContributorRow[]): ContributorInfo => {
  const entries = rows.map((row) => ({
    entityId: row.entityId,
    role: row.role === 'creator' ? 'creator' : 'editor',
    firstContributedAt: row.firstContributedAt,
    lastContributedAt: row.lastContributedAt,
    contributionCount: Number(row.contributionCount || 0),
    firstSubmissionId: row.firstSubmissionId,
    lastSubmissionId: row.lastSubmissionId,
    lastContributionSource: row.lastContributionSource,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    ...contributorUserFromRow(row),
  })) satisfies ContributorRegistryEntry[];

  const userIds = entries.map((item) => item.id);
  const usernames = entries
    .map((item) => item.username.trim())
    .filter(Boolean)
    .filter((value, index, list) => list.findIndex((item) => item.toLowerCase() === value.toLowerCase()) === index);
  const users = entries.map((item) => contributorUserFromEntry(item));

  return {
    userIds,
    usernames,
    users,
    uploadedByUsername: entries[0]?.username ?? null,
    entries,
    summary: buildContributorSummary(entries),
  };
};

const orderSqlForView = (view: 'summary' | 'list') =>
  view === 'summary'
    ? Prisma.sql`
        CASE WHEN c."role" = 'creator' THEN 0 ELSE 1 END ASC,
        c."first_contributed_at" ASC,
        c."created_at" ASC
      `
    : Prisma.sql`
        c."last_contributed_at" DESC,
        CASE WHEN c."role" = 'creator' THEN 0 ELSE 1 END ASC,
        c."created_at" DESC
      `;

const queryDJContributorRows = async (
  db: DBClient,
  entityIds: string[],
  view: 'summary' | 'list'
): Promise<ContributorRow[]> =>
  db.$queryRaw<ContributorRow[]>(Prisma.sql`
    SELECT
      c."dj_id" AS "entityId",
      c."user_id" AS "userId",
      u."username" AS "username",
      u."display_name" AS "displayName",
      u."avatar_url" AS "avatarUrl",
      c."role" AS "role",
      c."first_contributed_at" AS "firstContributedAt",
      c."last_contributed_at" AS "lastContributedAt",
      c."contribution_count" AS "contributionCount",
      c."first_submission_id" AS "firstSubmissionId",
      c."last_submission_id" AS "lastSubmissionId",
      c."last_contribution_source" AS "lastContributionSource",
      c."created_at" AS "createdAt",
      c."updated_at" AS "updatedAt"
    FROM "dj_contributors" c
    INNER JOIN "users" u ON u."id" = c."user_id"
    WHERE c."dj_id" IN (${Prisma.join(entityIds)})
    ORDER BY c."dj_id" ASC, ${orderSqlForView(view)}
  `);

const queryEventContributorRows = async (
  db: DBClient,
  entityIds: string[],
  view: 'summary' | 'list'
): Promise<ContributorRow[]> =>
  db.$queryRaw<ContributorRow[]>(Prisma.sql`
    SELECT
      c."event_id" AS "entityId",
      c."user_id" AS "userId",
      u."username" AS "username",
      u."display_name" AS "displayName",
      u."avatar_url" AS "avatarUrl",
      c."role" AS "role",
      c."first_contributed_at" AS "firstContributedAt",
      c."last_contributed_at" AS "lastContributedAt",
      c."contribution_count" AS "contributionCount",
      c."first_submission_id" AS "firstSubmissionId",
      c."last_submission_id" AS "lastSubmissionId",
      c."last_contribution_source" AS "lastContributionSource",
      c."created_at" AS "createdAt",
      c."updated_at" AS "updatedAt"
    FROM "event_contributors" c
    INNER JOIN "users" u ON u."id" = c."user_id"
    WHERE c."event_id" IN (${Prisma.join(entityIds)})
    ORDER BY c."event_id" ASC, ${orderSqlForView(view)}
  `);

const queryContributorRows = async (
  db: DBClient,
  entityType: ContributionEntityType,
  entityIds: string[],
  view: 'summary' | 'list'
): Promise<ContributorRow[]> => {
  const validIds = Array.from(new Set(entityIds.map((item) => item.trim()).filter(Boolean)));
  if (validIds.length === 0) return [];
  return entityType === 'dj'
    ? queryDJContributorRows(db, validIds, view)
    : queryEventContributorRows(db, validIds, view);
};

const buildContributorInfoMap = (
  entityIds: string[],
  rows: ContributorRow[]
): Map<string, ContributorInfo> => {
  const map = new Map<string, ContributorInfo>();
  for (const id of entityIds) {
    map.set(id, emptyContributorInfo);
  }

  const grouped = new Map<string, ContributorRow[]>();
  for (const row of rows) {
    const list = grouped.get(row.entityId) ?? [];
    list.push(row);
    grouped.set(row.entityId, list);
  }

  for (const [entityId, entryRows] of grouped.entries()) {
    map.set(entityId, mapContributorRows(entryRows));
  }

  return map;
};

export const fetchContributorInfoMap = async (
  db: DBClient,
  entityType: ContributionEntityType,
  entityIds: string[]
): Promise<Map<string, ContributorInfo>> => {
  const validIds = Array.from(new Set(entityIds.map((item) => item.trim()).filter(Boolean)));
  if (validIds.length === 0) return new Map();
  const rows = await queryContributorRows(db, entityType, validIds, 'summary');
  return buildContributorInfoMap(validIds, rows);
};

export const fetchContributorEntriesForEntity = async (
  db: DBClient,
  entityType: ContributionEntityType,
  entityId: string
): Promise<ContributorRegistryEntry[]> => {
  const rows = await queryContributorRows(db, entityType, [entityId], 'list');
  return mapContributorRows(rows).entries;
};

export const attachContributionInfo = async (
  db: DBClient,
  entityType: ContributionEntityType,
  row: any
): Promise<any> => {
  if (!row?.id) return row;
  const map = await fetchContributorInfoMap(db, entityType, [String(row.id)]);
  return {
    ...row,
    __contributorInfo: map.get(String(row.id)) ?? emptyContributorInfo,
  };
};

export const attachContributionInfoList = async (
  db: DBClient,
  entityType: ContributionEntityType,
  rows: any[]
): Promise<any[]> => {
  if (rows.length === 0) return rows;
  const ids = rows.map((row) => String(row.id));
  const map = await fetchContributorInfoMap(db, entityType, ids);
  return rows.map((row) => ({
    ...row,
    __contributorInfo: map.get(String(row.id)) ?? emptyContributorInfo,
  }));
};

const jsonValueSql = (value: Prisma.JsonObject | Prisma.JsonArray | null | undefined) =>
  value == null ? Prisma.sql`NULL` : Prisma.sql`${JSON.stringify(value)}::jsonb`;

const upsertContributorRegistry = async (
  db: DBClient,
  entityType: ContributionEntityType,
  input: RecordContributionInput
): Promise<void> => {
  const occurredAt = input.occurredAt ?? new Date();
  const role = input.role;
  const submissionId = input.submissionId ?? null;
  const source = input.source || null;

  if (entityType === 'dj') {
    await db.$executeRaw(Prisma.sql`
      INSERT INTO "dj_contributors" (
        "id",
        "dj_id",
        "user_id",
        "role",
        "first_contributed_at",
        "last_contributed_at",
        "contribution_count",
        "first_submission_id",
        "last_submission_id",
        "last_contribution_source",
        "created_at",
        "updated_at"
      )
      VALUES (
        ${crypto.randomUUID()},
        ${input.entityId},
        ${input.userId},
        ${role},
        ${occurredAt},
        ${occurredAt},
        1,
        ${submissionId},
        ${submissionId},
        ${source},
        NOW(),
        NOW()
      )
      ON CONFLICT ("dj_id", "user_id") DO UPDATE
      SET
        "role" = CASE
          WHEN "dj_contributors"."role" = 'creator' THEN "dj_contributors"."role"
          WHEN EXCLUDED."role" = 'creator' THEN EXCLUDED."role"
          ELSE 'editor'
        END,
        "first_contributed_at" = LEAST("dj_contributors"."first_contributed_at", EXCLUDED."first_contributed_at"),
        "last_contributed_at" = GREATEST("dj_contributors"."last_contributed_at", EXCLUDED."last_contributed_at"),
        "contribution_count" = "dj_contributors"."contribution_count" + 1,
        "first_submission_id" = COALESCE("dj_contributors"."first_submission_id", EXCLUDED."first_submission_id"),
        "last_submission_id" = COALESCE(EXCLUDED."last_submission_id", "dj_contributors"."last_submission_id"),
        "last_contribution_source" = COALESCE(EXCLUDED."last_contribution_source", "dj_contributors"."last_contribution_source"),
        "updated_at" = NOW()
    `);
    return;
  }

  await db.$executeRaw(Prisma.sql`
    INSERT INTO "event_contributors" (
      "id",
      "event_id",
      "user_id",
      "role",
      "first_contributed_at",
      "last_contributed_at",
      "contribution_count",
      "first_submission_id",
      "last_submission_id",
      "last_contribution_source",
      "created_at",
      "updated_at"
    )
    VALUES (
      ${crypto.randomUUID()},
      ${input.entityId},
      ${input.userId},
      ${role},
      ${occurredAt},
      ${occurredAt},
      1,
      ${submissionId},
      ${submissionId},
      ${source},
      NOW(),
      NOW()
    )
    ON CONFLICT ("event_id", "user_id") DO UPDATE
    SET
      "role" = CASE
        WHEN "event_contributors"."role" = 'creator' THEN "event_contributors"."role"
        WHEN EXCLUDED."role" = 'creator' THEN EXCLUDED."role"
        ELSE 'editor'
      END,
      "first_contributed_at" = LEAST("event_contributors"."first_contributed_at", EXCLUDED."first_contributed_at"),
      "last_contributed_at" = GREATEST("event_contributors"."last_contributed_at", EXCLUDED."last_contributed_at"),
      "contribution_count" = "event_contributors"."contribution_count" + 1,
      "first_submission_id" = COALESCE("event_contributors"."first_submission_id", EXCLUDED."first_submission_id"),
      "last_submission_id" = COALESCE(EXCLUDED."last_submission_id", "event_contributors"."last_submission_id"),
      "last_contribution_source" = COALESCE(EXCLUDED."last_contribution_source", "event_contributors"."last_contribution_source"),
      "updated_at" = NOW()
  `);
};

const insertContributionHistory = async (
  db: DBClient,
  entityType: ContributionEntityType,
  input: RecordContributionInput
): Promise<void> => {
  await db.$executeRaw(Prisma.sql`
    INSERT INTO "contribution_history_entries" (
      "id",
      "user_id",
      "entity_type",
      "entity_id",
      "entity_title_snapshot",
      "entity_cover_snapshot",
      "role_snapshot",
      "action_type",
      "source",
      "submission_id",
      "occurred_at",
      "approved_at",
      "version_after",
      "change_summary",
      "metadata",
      "created_at"
    )
    VALUES (
      ${crypto.randomUUID()},
      ${input.userId},
      ${entityType},
      ${input.entityId},
      ${input.title ?? null},
      ${input.coverImageUrl ?? null},
      ${input.role},
      ${input.actionType},
      ${input.source},
      ${input.submissionId ?? null},
      ${input.occurredAt ?? new Date()},
      ${input.approvedAt ?? null},
      ${input.versionAfter ?? null},
      ${input.changeSummary ?? null},
      ${jsonValueSql(input.metadata)},
      NOW()
    )
  `);
};

const recordContribution = async (
  db: DBClient,
  entityType: ContributionEntityType,
  input: RecordContributionInput
): Promise<void> => {
  await upsertContributorRegistry(db, entityType, input);
  await insertContributionHistory(db, entityType, input);
};

export const recordDJContribution = async (
  db: DBClient,
  input: RecordContributionInput
): Promise<void> => recordContribution(db, 'dj', input);

export const recordEventContribution = async (
  db: DBClient,
  input: RecordContributionInput
): Promise<void> => recordContribution(db, 'event', input);

export const isContributorForEntity = async (
  db: DBClient,
  entityType: ContributionEntityType,
  entityId: string,
  userId: string
): Promise<boolean> => {
  const rows = entityType === 'dj'
    ? await db.$queryRaw<Array<{ matched: number }>>(Prisma.sql`
        SELECT 1 AS "matched"
        FROM "dj_contributors"
        WHERE "dj_id" = ${entityId} AND "user_id" = ${userId}
        LIMIT 1
      `)
    : await db.$queryRaw<Array<{ matched: number }>>(Prisma.sql`
        SELECT 1 AS "matched"
        FROM "event_contributors"
        WHERE "event_id" = ${entityId} AND "user_id" = ${userId}
        LIMIT 1
      `);
  return rows.length > 0;
};

const loadContributionEntitySnapshots = async (
  db: DBClient,
  rows: ContributionHistoryRow[]
): Promise<{
  events: Map<string, { title: string | null; coverImageUrl: string | null }>;
  djs: Map<string, { title: string | null; coverImageUrl: string | null }>;
}> => {
  const missingEventIds = Array.from(new Set(
    rows
      .filter((row) => row.entityType === 'event' && (!row.entityTitleSnapshot || !row.entityCoverSnapshot))
      .map((row) => row.entityId)
  ));
  const missingDJIds = Array.from(new Set(
    rows
      .filter((row) => row.entityType === 'dj' && (!row.entityTitleSnapshot || !row.entityCoverSnapshot))
      .map((row) => row.entityId)
  ));

  const [events, djs] = await Promise.all([
    missingEventIds.length
      ? db.event.findMany({
          where: { id: { in: missingEventIds } },
          select: {
            id: true,
            name: true,
            coverImageUrl: true,
          },
        })
      : Promise.resolve([] as Array<{ id: string; name: string; coverImageUrl: string | null }>),
    missingDJIds.length
      ? db.dJ.findMany({
          where: { id: { in: missingDJIds } },
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        })
      : Promise.resolve([] as Array<{ id: string; name: string; avatarUrl: string | null }>),
  ]);

  return {
    events: new Map(events.map((item) => [item.id, { title: item.name, coverImageUrl: item.coverImageUrl ?? null }])),
    djs: new Map(djs.map((item) => [item.id, { title: item.name, coverImageUrl: item.avatarUrl ?? null }])),
  };
};

const mapContributionHistoryRows = async (
  db: DBClient,
  rows: ContributionHistoryRow[]
): Promise<ContributionHistoryItem[]> => {
  if (rows.length === 0) return [];
  const snapshots = await loadContributionEntitySnapshots(db, rows);

  return rows.map((row) => {
    const entityType: ContributionEntityType = row.entityType === 'dj' ? 'dj' : 'event';
    const liveSnapshot = entityType === 'dj'
      ? snapshots.djs.get(row.entityId)
      : snapshots.events.get(row.entityId);

    return {
      id: row.id,
      entityType,
      entityId: row.entityId,
      entityTitle: row.entityTitleSnapshot ?? liveSnapshot?.title ?? null,
      entityCoverImageUrl: row.entityCoverSnapshot ?? liveSnapshot?.coverImageUrl ?? null,
      role: row.roleSnapshot === 'creator' ? 'creator' : 'editor',
      actionType: row.actionType === 'create' ? 'create' : 'edit',
      source: row.source,
      submissionId: row.submissionId,
      occurredAt: row.occurredAt,
      approvedAt: row.approvedAt,
      versionAfter: row.versionAfter == null ? null : Number(row.versionAfter),
      changeSummary: row.changeSummary,
      metadata: row.metadata,
      createdAt: row.createdAt,
    };
  });
};

export const fetchContributionCenterSummary = async (
  db: DBClient,
  userId: string
): Promise<ContributionCenterSummary> => {
  const [summaryRow] = await db.$queryRaw<ContributionCenterSummaryRow[]>(Prisma.sql`
    SELECT
      COUNT(*)::int AS "totalContributionCount",
      COUNT(DISTINCT CASE WHEN "entity_type" = 'event' THEN "entity_id" END)::int AS "contributedEventCount",
      COUNT(DISTINCT CASE WHEN "entity_type" = 'dj' THEN "entity_id" END)::int AS "contributedDJCount",
      MAX("occurred_at") AS "lastContributionAt"
    FROM "contribution_history_entries"
    WHERE "user_id" = ${userId}
  `);

  const previewPage = await fetchContributionHistoryPage(db, userId, {
    entityType: 'all',
    limit: 3,
    cursor: null,
  });

  return {
    totalContributionCount: Number(summaryRow?.totalContributionCount ?? 0),
    contributedEventCount: Number(summaryRow?.contributedEventCount ?? 0),
    contributedDJCount: Number(summaryRow?.contributedDJCount ?? 0),
    lastContributionAt: summaryRow?.lastContributionAt ?? null,
    recentItems: previewPage.items,
  };
};

export const fetchContributionHistoryPage = async (
  db: DBClient,
  userId: string,
  input: {
    entityType: ContributionHistoryFilter;
    limit: number;
    cursor?: string | null;
  }
): Promise<ContributionHistoryPage> => {
  const entityType = input.entityType;
  const limit = Math.max(1, input.limit);
  const cursorPayload = input.cursor ? decodeContributionHistoryCursor(input.cursor) : null;
  const cursorCondition = cursorPayload
    ? Prisma.sql`
        AND (
          "occurred_at" < ${new Date(cursorPayload.occurredAt)}
          OR (
            "occurred_at" = ${new Date(cursorPayload.occurredAt)}
            AND "created_at" < ${new Date(cursorPayload.createdAt)}
          )
          OR (
            "occurred_at" = ${new Date(cursorPayload.occurredAt)}
            AND "created_at" = ${new Date(cursorPayload.createdAt)}
            AND "id" < ${cursorPayload.id}
          )
        )
      `
    : Prisma.empty;
  const entityTypeCondition = entityType === 'all'
    ? Prisma.empty
    : Prisma.sql`AND "entity_type" = ${entityType}`;

  const rows = await db.$queryRaw<ContributionHistoryRow[]>(Prisma.sql`
    SELECT
      "id" AS "id",
      "entity_type" AS "entityType",
      "entity_id" AS "entityId",
      "entity_title_snapshot" AS "entityTitleSnapshot",
      "entity_cover_snapshot" AS "entityCoverSnapshot",
      "role_snapshot" AS "roleSnapshot",
      "action_type" AS "actionType",
      "source" AS "source",
      "submission_id" AS "submissionId",
      "occurred_at" AS "occurredAt",
      "approved_at" AS "approvedAt",
      "version_after" AS "versionAfter",
      "change_summary" AS "changeSummary",
      "metadata" AS "metadata",
      "created_at" AS "createdAt"
    FROM "contribution_history_entries"
    WHERE "user_id" = ${userId}
    ${entityTypeCondition}
    ${cursorCondition}
    ORDER BY "occurred_at" DESC, "created_at" DESC, "id" DESC
    LIMIT ${limit + 1}
  `);

  const hasMore = rows.length > limit;
  const pageRows = hasMore ? rows.slice(0, limit) : rows;
  const items = await mapContributionHistoryRows(db, pageRows);
  const lastRow = pageRows[pageRows.length - 1];

  return {
    entityType,
    limit,
    items,
    nextCursor: hasMore && lastRow ? encodeContributionHistoryCursor(lastRow) : null,
    hasMore,
  };
};
