import { Prisma, PrismaClient } from '@prisma/client';
import {
  buildCheckinPagination,
  CheckinGalleryArtistsResponse,
  CheckinGalleryEventsResponse,
  CheckinOverviewResponse,
  CheckinOverviewTimelineItem,
  CheckinStatsResponse,
  CheckinTimelineResponse,
} from './checkin-overview';
import { CHECKIN_PROJECTION_VERSION } from './checkin-projection';

const OVERVIEW_TIMELINE_LIMIT = 3;
const GALLERY_ARTIST_LIMIT = 6;
const TIMELINE_PAGE_LIMIT_MAX = 50;
const GALLERY_PAGE_LIMIT_MAX = 100;

type CheckinPagination = {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

type ReadModelResult<T> = {
  data: T;
  pagination?: CheckinPagination;
  stale: boolean;
};

export type ReadModelUnavailableReason = 'user_not_found' | 'projection_not_ready';

export type ReadModelMaybe<T> =
  | ReadModelResult<T>
  | {
      data: null;
      stale: true;
      reason: ReadModelUnavailableReason;
    };

const normalizePageLimit = (
  page: number,
  limit: number,
  fallbackLimit: number,
  maxLimit: number
): { page: number; limit: number; skip: number } => {
  const normalizedPage = Number.isFinite(page) ? Math.max(1, Math.floor(page)) : 1;
  const normalizedLimit = Number.isFinite(limit)
    ? Math.max(1, Math.min(maxLimit, Math.floor(limit)))
    : fallbackLimit;
  return {
    page: normalizedPage,
    limit: normalizedLimit,
    skip: (normalizedPage - 1) * normalizedLimit,
  };
};

const projectionScope = (targetUserId: string, viewerUserId?: string | null): 'all' | 'visible' =>
  viewerUserId === targetUserId ? 'all' : 'visible';

const userExists = async (prisma: PrismaClient, targetUserId: string): Promise<boolean> => {
  const user = await prisma.user.findUnique({
    where: { id: targetUserId },
    select: { id: true },
  });
  return Boolean(user);
};

const parseDate = (value: unknown): Date | null => {
  if (value instanceof Date) return value;
  if (typeof value !== 'string') return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};

const parseTimelinePayload = (payload: Prisma.JsonValue): CheckinOverviewTimelineItem | null => {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) return null;
  const row = payload as Record<string, unknown>;
  const event = row.event;
  const summary = row.summary;
  const attendedAt = parseDate(row.attendedAt);
  const createdAt = parseDate(row.createdAt);

  if (!event || typeof event !== 'object' || Array.isArray(event) || !attendedAt || !createdAt) {
    return null;
  }

  const eventRow = event as Record<string, unknown>;
  const summaryRow =
    summary && typeof summary === 'object' && !Array.isArray(summary)
      ? (summary as Record<string, unknown>)
      : {};

  return {
    id: String(row.id ?? ''),
    type: 'event',
    attendedAt,
    createdAt,
    event: {
      id: String(eventRow.id ?? ''),
      name: typeof eventRow.name === 'string' ? eventRow.name : null,
      nameI18n:
        eventRow.nameI18n && typeof eventRow.nameI18n === 'object' && !Array.isArray(eventRow.nameI18n)
          ? (eventRow.nameI18n as Record<string, unknown>)
          : null,
      coverImageUrl: typeof eventRow.coverImageUrl === 'string' ? eventRow.coverImageUrl : null,
      address: typeof eventRow.address === 'string' ? eventRow.address : null,
      city: typeof eventRow.city === 'string' ? eventRow.city : null,
      country: typeof eventRow.country === 'string' ? eventRow.country : null,
      startDate: parseDate(eventRow.startDate),
      endDate: parseDate(eventRow.endDate),
    },
    summary: {
      dayCount: Number(summaryRow.dayCount ?? 0),
      artistCount: Number(summaryRow.artistCount ?? 0),
      performanceCount: Number(summaryRow.performanceCount ?? 0),
    },
    selections: Array.isArray(row.selections)
      ? (row.selections as CheckinOverviewTimelineItem['selections'])
      : [],
  };
};

const isProjectionFresh = async (
  prisma: PrismaClient,
  userId: string,
  scope: 'all' | 'visible'
): Promise<boolean> => {
  const [dirtyCount, stats] = await Promise.all([
    prisma.checkin.count({
      where: {
        userId,
        status: 'active',
        projectionVersion: { lt: CHECKIN_PROJECTION_VERSION },
        ...(scope === 'visible' ? { visibility: 'visible' } : {}),
      },
    }),
    prisma.userCheckinStat.findUnique({
      where: {
        userId_scope: {
          userId,
          scope,
        },
      },
      select: {
        projectionVersion: true,
      },
    }),
  ]);

  return dirtyCount === 0 && stats?.projectionVersion === CHECKIN_PROJECTION_VERSION;
};

export async function fetchCheckinOverviewFromReadModel(
  prisma: PrismaClient,
  targetUserId: string,
  viewerUserId?: string | null
): Promise<ReadModelResult<CheckinOverviewResponse> | null> {
  if (!(await userExists(prisma, targetUserId))) return null;

  const scope = projectionScope(targetUserId, viewerUserId);
  const [stats, totalTimelineCount, timelineRows, topEvents, topArtists, fresh] = await Promise.all([
    prisma.userCheckinStat.findUnique({
      where: {
        userId_scope: {
          userId: targetUserId,
          scope,
        },
      },
    }),
    prisma.userCheckinTimelineEntry.count({
      where: {
        userId: targetUserId,
        ...(scope === 'visible' ? { visibilityResolved: 'visible' } : {}),
      },
    }),
    prisma.userCheckinTimelineEntry.findMany({
      where: {
        userId: targetUserId,
        ...(scope === 'visible' ? { visibilityResolved: 'visible' } : {}),
      },
      orderBy: [{ anchorAt: 'desc' }, { createdAt: 'desc' }],
      take: OVERVIEW_TIMELINE_LIMIT,
    }),
    prisma.userCheckinGalleryEventAggregate.findMany({
      where: {
        userId: targetUserId,
        scope,
      },
      orderBy: [{ count: 'desc' }, { latestAttendedAt: 'desc' }],
      take: OVERVIEW_TIMELINE_LIMIT,
    }),
    prisma.userCheckinGalleryDJAggregate.findMany({
      where: {
        userId: targetUserId,
        scope,
      },
      orderBy: [{ count: 'desc' }, { latestAttendedAt: 'desc' }],
      take: GALLERY_ARTIST_LIMIT,
    }),
    isProjectionFresh(prisma, targetUserId, scope),
  ]);

  if (!stats || !fresh) return null;

  const items = timelineRows
    .map((row) => parseTimelinePayload(row.payload))
    .filter((item): item is CheckinOverviewTimelineItem => item !== null);

  return {
    stale: false,
    data: {
      stats: {
        eventCount: stats.eventCount,
        artistCount: stats.artistCount,
        latestCheckinAt: stats.latestCheckinAt,
      },
      timeline: {
        items,
        pagination: {
          limit: OVERVIEW_TIMELINE_LIMIT,
          hasMore: totalTimelineCount > items.length,
          totalEventCount: totalTimelineCount,
        },
      },
      gallerySummary: {
        topEvents: topEvents.map((row) => ({
          eventId: row.eventId ?? '',
          name: row.eventName,
          coverImageUrl: row.eventCoverUrl,
          address: row.eventAddress,
          attendedAt: row.latestAttendedAt ?? new Date(0),
          artistCount: row.artistCount,
          performanceCount: row.performanceCount,
        })),
        topArtists: topArtists.map((row) => ({
          djId: row.djId,
          name: row.displayName,
          avatarUrl: row.avatarUrl,
          country: row.country,
          count: row.count,
          latestAttendedAt: row.latestAttendedAt ?? new Date(0),
        })),
      },
    },
  };
}

export async function fetchCheckinOverviewReadModelStrict(
  prisma: PrismaClient,
  targetUserId: string,
  viewerUserId?: string | null
): Promise<ReadModelMaybe<CheckinOverviewResponse>> {
  if (!(await userExists(prisma, targetUserId))) {
    return { data: null, stale: true, reason: 'user_not_found' };
  }
  return (
    (await fetchCheckinOverviewFromReadModel(prisma, targetUserId, viewerUserId)) ?? {
      data: null,
      stale: true,
      reason: 'projection_not_ready',
    }
  );
}

export async function fetchCheckinTimelinePageFromReadModel(
  prisma: PrismaClient,
  targetUserId: string,
  viewerUserId: string | null | undefined,
  page: number,
  limit: number
): Promise<ReadModelResult<CheckinTimelineResponse> | null> {
  if (!(await userExists(prisma, targetUserId))) return null;

  const scope = projectionScope(targetUserId, viewerUserId);
  const { page: normalizedPage, limit: normalizedLimit, skip } = normalizePageLimit(
    page,
    limit,
    20,
    TIMELINE_PAGE_LIMIT_MAX
  );
  const where = {
    userId: targetUserId,
    ...(scope === 'visible' ? { visibilityResolved: 'visible' } : {}),
  };
  const [total, rows, fresh] = await Promise.all([
    prisma.userCheckinTimelineEntry.count({ where }),
    prisma.userCheckinTimelineEntry.findMany({
      where,
      orderBy: [{ anchorAt: 'desc' }, { createdAt: 'desc' }],
      skip,
      take: normalizedLimit,
    }),
    isProjectionFresh(prisma, targetUserId, scope),
  ]);

  if (!fresh) return null;

  return {
    stale: false,
    data: {
      items: rows
        .map((row) => parseTimelinePayload(row.payload))
        .filter((item): item is CheckinOverviewTimelineItem => item !== null),
    },
    pagination: buildCheckinPagination(normalizedPage, normalizedLimit, total),
  };
}

export async function fetchCheckinTimelinePageReadModelStrict(
  prisma: PrismaClient,
  targetUserId: string,
  viewerUserId: string | null | undefined,
  page: number,
  limit: number
): Promise<ReadModelMaybe<CheckinTimelineResponse>> {
  if (!(await userExists(prisma, targetUserId))) {
    return { data: null, stale: true, reason: 'user_not_found' };
  }
  return (
    (await fetchCheckinTimelinePageFromReadModel(prisma, targetUserId, viewerUserId, page, limit)) ?? {
      data: null,
      stale: true,
      reason: 'projection_not_ready',
    }
  );
}

export async function fetchCheckinGalleryEventsPageFromReadModel(
  prisma: PrismaClient,
  targetUserId: string,
  viewerUserId: string | null | undefined,
  page: number,
  limit: number
): Promise<ReadModelResult<CheckinGalleryEventsResponse> | null> {
  if (!(await userExists(prisma, targetUserId))) return null;

  const scope = projectionScope(targetUserId, viewerUserId);
  const { page: normalizedPage, limit: normalizedLimit, skip } = normalizePageLimit(
    page,
    limit,
    20,
    GALLERY_PAGE_LIMIT_MAX
  );
  const where = { userId: targetUserId, scope };
  const [total, rows, fresh] = await Promise.all([
    prisma.userCheckinGalleryEventAggregate.count({ where }),
    prisma.userCheckinGalleryEventAggregate.findMany({
      where,
      orderBy: [{ count: 'desc' }, { latestAttendedAt: 'desc' }],
      skip,
      take: normalizedLimit,
    }),
    isProjectionFresh(prisma, targetUserId, scope),
  ]);

  if (!fresh) return null;

  return {
    stale: false,
    data: {
      items: rows.map((row) => ({
        eventId: row.eventId ?? '',
        name: row.eventName,
        coverImageUrl: row.eventCoverUrl,
        address: row.eventAddress,
        attendedAt: row.latestAttendedAt ?? new Date(0),
        artistCount: row.artistCount,
        performanceCount: row.performanceCount,
      })),
    },
    pagination: buildCheckinPagination(normalizedPage, normalizedLimit, total),
  };
}

export async function fetchCheckinGalleryEventsPageReadModelStrict(
  prisma: PrismaClient,
  targetUserId: string,
  viewerUserId: string | null | undefined,
  page: number,
  limit: number
): Promise<ReadModelMaybe<CheckinGalleryEventsResponse>> {
  if (!(await userExists(prisma, targetUserId))) {
    return { data: null, stale: true, reason: 'user_not_found' };
  }
  return (
    (await fetchCheckinGalleryEventsPageFromReadModel(prisma, targetUserId, viewerUserId, page, limit)) ?? {
      data: null,
      stale: true,
      reason: 'projection_not_ready',
    }
  );
}

export async function fetchCheckinGalleryArtistsPageFromReadModel(
  prisma: PrismaClient,
  targetUserId: string,
  viewerUserId: string | null | undefined,
  page: number,
  limit: number
): Promise<ReadModelResult<CheckinGalleryArtistsResponse> | null> {
  if (!(await userExists(prisma, targetUserId))) return null;

  const scope = projectionScope(targetUserId, viewerUserId);
  const { page: normalizedPage, limit: normalizedLimit, skip } = normalizePageLimit(
    page,
    limit,
    20,
    GALLERY_PAGE_LIMIT_MAX
  );
  const where = { userId: targetUserId, scope };
  const [total, rows, fresh] = await Promise.all([
    prisma.userCheckinGalleryDJAggregate.count({ where }),
    prisma.userCheckinGalleryDJAggregate.findMany({
      where,
      orderBy: [{ count: 'desc' }, { latestAttendedAt: 'desc' }],
      skip,
      take: normalizedLimit,
    }),
    isProjectionFresh(prisma, targetUserId, scope),
  ]);

  if (!fresh) return null;

  return {
    stale: false,
    data: {
      items: rows.map((row) => ({
        djId: row.djId,
        name: row.displayName,
        avatarUrl: row.avatarUrl,
        country: row.country,
        count: row.count,
        latestAttendedAt: row.latestAttendedAt ?? new Date(0),
      })),
    },
    pagination: buildCheckinPagination(normalizedPage, normalizedLimit, total),
  };
}

export async function fetchCheckinGalleryArtistsPageReadModelStrict(
  prisma: PrismaClient,
  targetUserId: string,
  viewerUserId: string | null | undefined,
  page: number,
  limit: number
): Promise<ReadModelMaybe<CheckinGalleryArtistsResponse>> {
  if (!(await userExists(prisma, targetUserId))) {
    return { data: null, stale: true, reason: 'user_not_found' };
  }
  return (
    (await fetchCheckinGalleryArtistsPageFromReadModel(prisma, targetUserId, viewerUserId, page, limit)) ?? {
      data: null,
      stale: true,
      reason: 'projection_not_ready',
    }
  );
}

export async function fetchCheckinStatsFromReadModel(
  prisma: PrismaClient,
  targetUserId: string,
  viewerUserId?: string | null
): Promise<ReadModelResult<CheckinStatsResponse> | null> {
  if (!(await userExists(prisma, targetUserId))) return null;

  const scope = projectionScope(targetUserId, viewerUserId);
  const [stats, fresh] = await Promise.all([
    prisma.userCheckinStat.findUnique({
      where: {
        userId_scope: {
          userId: targetUserId,
          scope,
        },
      },
    }),
    isProjectionFresh(prisma, targetUserId, scope),
  ]);

  if (!stats || !fresh) return null;

  return {
    stale: false,
    data: {
      eventCount: stats.eventCount,
      artistCount: stats.artistCount,
      latestCheckinAt: stats.latestCheckinAt,
    },
  };
}

export async function fetchCheckinStatsReadModelStrict(
  prisma: PrismaClient,
  targetUserId: string,
  viewerUserId?: string | null
): Promise<ReadModelMaybe<CheckinStatsResponse>> {
  if (!(await userExists(prisma, targetUserId))) {
    return { data: null, stale: true, reason: 'user_not_found' };
  }
  return (
    (await fetchCheckinStatsFromReadModel(prisma, targetUserId, viewerUserId)) ?? {
      data: null,
      stale: true,
      reason: 'projection_not_ready',
    }
  );
}
