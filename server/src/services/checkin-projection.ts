import { Prisma, PrismaClient } from '@prisma/client';
import {
  aggregateCheckinArtists,
  CheckinOverviewGalleryArtistItem,
  CheckinOverviewTimelineItem,
  mapCheckinTimelineItem,
} from './checkin-overview';

const PROJECTION_VERSION = 3;

export const CHECKIN_PROJECTION_VERSION = PROJECTION_VERSION;

type ProjectionScope = 'all' | 'visible';

type ProjectionCheckinRow = {
  id: string;
  userId: string;
  eventId: string | null;
  djId: string | null;
  type: string;
  note: string | null;
  visibility: string;
  attendedAt: Date;
  createdAt: Date;
  event: {
    id: string;
    name: string;
    nameI18n: Prisma.JsonValue | null;
    coverImageUrl: string | null;
    city: string | null;
    country: string | null;
    venueAddress: string | null;
    manualLocation: Prisma.JsonValue | null;
    startDate: Date;
    endDate: Date;
  } | null;
  dj: {
    id: string;
    name: string;
    avatarUrl: string | null;
    country: string | null;
  } | null;
  snapshot: {
    eventName: string | null;
    eventNameI18n: Prisma.JsonValue | null;
    eventCoverUrl: string | null;
    eventCity: string | null;
    eventCountry: string | null;
    eventAddress: string | null;
    visibilityResolved: string;
  } | null;
  selections: Array<{
    dayId: string;
    dayIndex: number;
    djs: Array<{
      djId: string | null;
      actGroupId: string | null;
      rawName: string;
      displayName: string;
      avatarUrl: string | null;
      country: string | null;
      actType: string | null;
      performerIndex: number;
      sortOrder: number;
    }>;
  }>;
};

type DJProfileLite = {
  id: string;
  name: string;
  avatarUrl: string | null;
  country: string | null;
};

type GalleryEventAggregate = {
  eventId: string | null;
  eventName: string;
  eventCoverUrl: string | null;
  eventAddress: string | null;
  count: number;
  latestAttendedAt: Date;
  artistCount: number;
  performanceCount: number;
  visibilityResolved: string;
};

type ProjectionBuild = {
  scope: ProjectionScope;
  rows: ProjectionCheckinRow[];
  timelineItems: Array<{
    item: CheckinOverviewTimelineItem;
    row: ProjectionCheckinRow;
  }>;
  artists: CheckinOverviewGalleryArtistItem[];
  eventAggregates: GalleryEventAggregate[];
};

export type CheckinProjectionReport = {
  userId: string;
  mode: 'dry-run' | 'apply';
  projectionVersion: number;
  scopedRows: Record<ProjectionScope, number>;
  timelineEntries: number;
  galleryEventAggregates: number;
  galleryDJAggregates: number;
};

const normalizeText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const normalizeKey = (value: string): string =>
  value
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .normalize('NFKC');

const firstNonEmptyText = (...values: Array<string | null | undefined>): string | null => {
  for (const value of values) {
    const normalized = normalizeText(value);
    if (normalized) return normalized;
  }
  return null;
};

const buildDJProfileMaps = (profiles: DJProfileLite[]): {
  byId: Map<string, DJProfileLite>;
} => {
  const byId = new Map<string, DJProfileLite>();

  for (const profile of profiles) {
    byId.set(profile.id, profile);
  }

  return { byId };
};

const enrichProjectionRowsWithDJProfiles = async (
  prisma: PrismaClient,
  rows: ProjectionCheckinRow[]
): Promise<ProjectionCheckinRow[]> => {
  const djIds = new Set<string>();

  for (const row of rows) {
    if (row.dj?.id) djIds.add(row.dj.id);
    if (row.djId) djIds.add(row.djId);

    for (const selection of row.selections) {
      for (const dj of selection.djs) {
        if (dj.djId) djIds.add(dj.djId);
      }
    }
  }

  const profiles =
    djIds.size > 0
      ? await prisma.dJ.findMany({
          where: {
            id: { in: Array.from(djIds) },
          },
          select: {
            id: true,
            name: true,
            avatarUrl: true,
            country: true,
          },
        })
      : [];
  const maps = buildDJProfileMaps(profiles);

  return rows.map((row) => ({
    ...row,
    dj:
      row.dj ??
      (row.djId
        ? (() => {
            const profile = maps.byId.get(row.djId);
            return profile
              ? {
                  id: profile.id,
                  name: profile.name,
                  avatarUrl: profile.avatarUrl,
                  country: profile.country,
                }
              : null;
          })()
        : null),
    selections: row.selections.map((selection) => ({
      ...selection,
      djs: selection.djs.map((dj) => {
        const profile = dj.djId ? maps.byId.get(dj.djId) : undefined;
        if (!profile) return dj;

        return {
          ...dj,
          djId: profile.id,
          displayName: firstNonEmptyText(dj.displayName, profile.name) ?? profile.name,
          avatarUrl: firstNonEmptyText(dj.avatarUrl, profile.avatarUrl),
          country: firstNonEmptyText(dj.country, profile.country),
        };
      }),
    })),
  }));
};

const resolveVisibility = (row: ProjectionCheckinRow): string => {
  const snapshotVisibility = normalizeText(row.snapshot?.visibilityResolved).toLowerCase();
  if (snapshotVisibility === 'visible' || snapshotVisibility === 'private') {
    return snapshotVisibility;
  }

  const checkinVisibility = normalizeText(row.visibility).toLowerCase();
  return checkinVisibility === 'visible' ? 'visible' : 'private';
};

const toDateOnly = (date: Date): Date =>
  new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));

const buildTimelinePayload = (item: CheckinOverviewTimelineItem): Prisma.InputJsonValue =>
  ({
    id: item.id,
    type: item.type,
    attendedAt: item.attendedAt.toISOString(),
    createdAt: item.createdAt.toISOString(),
    event: {
      id: item.event.id,
      name: item.event.name,
      nameI18n: item.event.nameI18n as Prisma.InputJsonValue,
      coverImageUrl: item.event.coverImageUrl,
      address: item.event.address,
      city: item.event.city,
      country: item.event.country,
      startDate: item.event.startDate?.toISOString() ?? null,
      endDate: item.event.endDate?.toISOString() ?? null,
    },
    summary: item.summary,
    selections: item.selections,
  }) as Prisma.InputJsonValue;

const buildGalleryEventAggregates = (
  timelineItems: ProjectionBuild['timelineItems']
): GalleryEventAggregate[] => {
  const aggregates = new Map<string, GalleryEventAggregate>();

  for (const { item, row } of timelineItems) {
    const eventName = normalizeText(item.event.name) || 'Unknown event';
    const key = item.event.id ? `id:${item.event.id}` : `name:${normalizeKey(eventName)}`;
    const existing = aggregates.get(key);
    const visibilityResolved = resolveVisibility(row);

    if (existing) {
      existing.count += 1;
      if (item.attendedAt > existing.latestAttendedAt) {
        existing.latestAttendedAt = item.attendedAt;
      }
      existing.artistCount = Math.max(existing.artistCount, item.summary.artistCount);
      existing.performanceCount = Math.max(existing.performanceCount, item.summary.performanceCount);
      if (existing.visibilityResolved !== 'visible' || visibilityResolved !== 'visible') {
        existing.visibilityResolved = 'private';
      }
      continue;
    }

    aggregates.set(key, {
      eventId: item.event.id,
      eventName,
      eventCoverUrl: item.event.coverImageUrl,
      eventAddress: item.event.address,
      count: 1,
      latestAttendedAt: item.attendedAt,
      artistCount: item.summary.artistCount,
      performanceCount: item.summary.performanceCount,
      visibilityResolved,
    });
  }

  return Array.from(aggregates.values()).sort((left, right) => {
    if (left.count !== right.count) return right.count - left.count;
    return right.latestAttendedAt.getTime() - left.latestAttendedAt.getTime();
  });
};

const buildScope = (scope: ProjectionScope, allRows: ProjectionCheckinRow[]): ProjectionBuild => {
  const rows = scope === 'visible' ? allRows.filter((row) => resolveVisibility(row) === 'visible') : allRows;
  const timelineItems = rows
    .filter((row) => row.type === 'event')
    .map((row) => ({ row, item: mapCheckinTimelineItem(row) }))
    .filter(
      (entry): entry is { row: ProjectionCheckinRow; item: CheckinOverviewTimelineItem } =>
        entry.item !== null
    );

  return {
    scope,
    rows,
    timelineItems,
    artists: aggregateCheckinArtists(rows),
    eventAggregates: buildGalleryEventAggregates(timelineItems),
  };
};

const selectProjectionRows = async (
  prisma: PrismaClient,
  userId: string
): Promise<ProjectionCheckinRow[]> =>
  prisma.checkin.findMany({
    where: {
      userId,
      status: 'active',
      OR: [{ note: null }, { note: { not: 'marked' } }],
    },
    orderBy: [{ attendedAt: 'desc' }, { createdAt: 'desc' }],
    select: {
      id: true,
      userId: true,
      eventId: true,
      djId: true,
      type: true,
      note: true,
      visibility: true,
      attendedAt: true,
      createdAt: true,
      event: {
        select: {
          id: true,
          name: true,
          nameI18n: true,
          coverImageUrl: true,
          city: true,
          country: true,
          venueAddress: true,
          manualLocation: true,
          startDate: true,
          endDate: true,
        },
      },
      dj: {
        select: {
          id: true,
          name: true,
          avatarUrl: true,
          country: true,
        },
      },
      snapshot: {
        select: {
          eventName: true,
          eventNameI18n: true,
          eventCoverUrl: true,
          eventCity: true,
          eventCountry: true,
          eventAddress: true,
          visibilityResolved: true,
        },
      },
      selections: {
        orderBy: [{ dayIndex: 'asc' }, { sortOrder: 'asc' }],
        select: {
          dayId: true,
          dayIndex: true,
          djs: {
            orderBy: [{ sortOrder: 'asc' }, { performerIndex: 'asc' }],
            select: {
              djId: true,
              actGroupId: true,
              rawName: true,
              displayName: true,
              avatarUrl: true,
              country: true,
              actType: true,
              performerIndex: true,
              sortOrder: true,
            },
          },
        },
      },
    },
  });

export async function rebuildUserCheckinProjection(
  prisma: PrismaClient,
  userId: string,
  options: { dryRun?: boolean } = {}
): Promise<CheckinProjectionReport> {
  const rows = await enrichProjectionRowsWithDJProfiles(prisma, await selectProjectionRows(prisma, userId));
  const allScope = buildScope('all', rows);
  const visibleScope = buildScope('visible', rows);
  const scopes = [allScope, visibleScope];
  const baseReport: CheckinProjectionReport = {
    userId,
    mode: options.dryRun ? 'dry-run' : 'apply',
    projectionVersion: PROJECTION_VERSION,
    scopedRows: {
      all: allScope.rows.length,
      visible: visibleScope.rows.length,
    },
    timelineEntries: allScope.timelineItems.length,
    galleryEventAggregates: allScope.eventAggregates.length + visibleScope.eventAggregates.length,
    galleryDJAggregates: allScope.artists.length + visibleScope.artists.length,
  };

  if (options.dryRun) {
    return baseReport;
  }

  await prisma.$transaction(async (tx) => {
    await tx.userCheckinTimelineEntry.deleteMany({ where: { userId } });
    await tx.userCheckinStat.deleteMany({ where: { userId } });
    await tx.userCheckinGalleryEventAggregate.deleteMany({ where: { userId } });
    await tx.userCheckinGalleryDJAggregate.deleteMany({ where: { userId } });

    if (allScope.timelineItems.length > 0) {
      await tx.userCheckinTimelineEntry.createMany({
        data: allScope.timelineItems.map(({ item, row }) => ({
          userId,
          timelineDate: toDateOnly(item.attendedAt),
          anchorAt: item.attendedAt,
          nodeType: item.type,
          primaryCheckinId: item.id,
          eventId: item.event.id,
          eventName: item.event.name,
          eventCoverUrl: item.event.coverImageUrl,
          eventAddress: item.event.address,
          payload: buildTimelinePayload(item),
          statsDjCount: item.summary.artistCount,
          statsPerformanceCount: item.summary.performanceCount,
          statsSelectionCount: item.summary.dayCount,
          visibilityResolved: resolveVisibility(row),
          projectionVersion: PROJECTION_VERSION,
        })),
      });
    }

    await tx.userCheckinStat.createMany({
      data: scopes.map((scope) => ({
        userId,
        scope: scope.scope,
        eventCount: scope.timelineItems.length,
        artistCount: scope.artists.length,
        eventCheckinCount: scope.rows.filter((row) => row.type === 'event').length,
        djCheckinCount: scope.rows.filter((row) => row.type === 'dj').length,
        performanceCount: scope.timelineItems.reduce(
          (total, entry) => total + entry.item.summary.performanceCount,
          0
        ),
        latestCheckinAt: scope.rows[0]?.attendedAt ?? null,
        visibilityResolved: scope.scope === 'visible' ? 'visible' : 'private',
        projectionVersion: PROJECTION_VERSION,
      })),
    });

    for (const scope of scopes) {
      if (scope.eventAggregates.length > 0) {
        await tx.userCheckinGalleryEventAggregate.createMany({
          data: scope.eventAggregates.map((item) => ({
            userId,
            scope: scope.scope,
            eventId: item.eventId,
            eventName: item.eventName,
            eventCoverUrl: item.eventCoverUrl,
            eventAddress: item.eventAddress,
            artistCount: item.artistCount,
            performanceCount: item.performanceCount,
            count: item.count,
            latestAttendedAt: item.latestAttendedAt,
            visibilityResolved: item.visibilityResolved,
            projectionVersion: PROJECTION_VERSION,
          })),
        });
      }

      if (scope.artists.length > 0) {
        await tx.userCheckinGalleryDJAggregate.createMany({
          data: scope.artists.map((item) => ({
            userId,
            scope: scope.scope,
            djId: item.djId,
            displayName: item.name,
            avatarUrl: item.avatarUrl,
            country: item.country,
            count: item.count,
            latestAttendedAt: item.latestAttendedAt,
            visibilityResolved: scope.scope === 'visible' ? 'visible' : 'private',
            projectionVersion: PROJECTION_VERSION,
          })),
        });
      }
    }

    await tx.$executeRaw`
      UPDATE "checkins"
      SET "projection_version" = ${PROJECTION_VERSION}
      WHERE "user_id" = ${userId}
    `;
  });

  return baseReport;
}
