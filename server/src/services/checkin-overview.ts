import { PrismaClient, Prisma } from '@prisma/client';
import { normalizeBiText, resolveEventAddress } from './checkin-domain';

export type CheckinOverviewStats = {
  eventCount: number;
  artistCount: number;
  latestCheckinAt: Date | null;
};

export type CheckinOverviewTimelinePerformer = {
  djId: string | null;
  name: string;
  avatarUrl: string | null;
  country: string | null;
  performerIndex: number;
};

export type CheckinOverviewTimelineAct = {
  actGroupId: string;
  actType: 'solo' | 'b2b' | 'b3b';
  displayName: string;
  performers: CheckinOverviewTimelinePerformer[];
};

export type CheckinOverviewTimelineDay = {
  dayId: string;
  dayIndex: number;
  acts: CheckinOverviewTimelineAct[];
};

export type CheckinOverviewTimelineItem = {
  id: string;
  type: 'event';
  attendedAt: Date;
  createdAt: Date;
  event: {
    id: string;
    name: string | null;
    nameI18n: Record<string, unknown> | null;
    coverImageUrl: string | null;
    address: string | null;
    city: string | null;
    country: string | null;
    startDate: Date | null;
    endDate: Date | null;
  };
  summary: {
    dayCount: number;
    artistCount: number;
    performanceCount: number;
  };
  selections: CheckinOverviewTimelineDay[];
};

export type CheckinOverviewGalleryEventItem = {
  eventId: string;
  name: string | null;
  coverImageUrl: string | null;
  address: string | null;
  attendedAt: Date;
  artistCount: number;
  performanceCount: number;
};

export type CheckinOverviewGalleryArtistItem = {
  djId: string | null;
  name: string;
  avatarUrl: string | null;
  country: string | null;
  count: number;
  latestAttendedAt: Date;
};

export type CheckinOverviewResponse = {
  stats: CheckinOverviewStats;
  timeline: {
    items: CheckinOverviewTimelineItem[];
    pagination: {
      limit: number;
      hasMore: boolean;
      totalEventCount: number;
    };
  };
  gallerySummary: {
    topEvents: CheckinOverviewGalleryEventItem[];
    topArtists: CheckinOverviewGalleryArtistItem[];
  };
};

export type CheckinTimelineResponse = {
  items: CheckinOverviewTimelineItem[];
};

export type CheckinGalleryEventsResponse = {
  items: CheckinOverviewGalleryEventItem[];
};

export type CheckinGalleryArtistsResponse = {
  items: CheckinOverviewGalleryArtistItem[];
};

export type CheckinStatsResponse = CheckinOverviewStats;

type LegacySelectionDJ = {
  id: string;
  name: string;
  avatarUrl?: string | null;
  country?: string | null;
};

type LegacySelectionDay = {
  dayID: string;
  dayIndex: number;
  djSelections: LegacySelectionDJ[];
};

type EventTimelineRow = {
  id: string;
  eventId: string | null;
  type: string;
  note: string | null;
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
  snapshot: {
    eventName: string | null;
    eventNameI18n: Prisma.JsonValue | null;
    eventCoverUrl: string | null;
    eventCity: string | null;
    eventCountry: string | null;
    eventAddress: string | null;
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

type ArtistAggregateRow = {
  type: string;
  attendedAt: Date;
  djId: string | null;
  note: string | null;
  dj: {
    id: string;
    name: string;
    avatarUrl: string | null;
    country: string | null;
  } | null;
  selections: Array<{
    dayId: string;
    dayIndex: number;
    djs: Array<{
      djId: string | null;
      displayName: string;
      rawName: string;
      avatarUrl: string | null;
      country: string | null;
      actType: string | null;
      performerIndex: number;
      actGroupId: string | null;
    }>;
  }>;
};

const OVERVIEW_TIMELINE_LIMIT = 3;
const GALLERY_ARTIST_LIMIT = 6;
const EVENT_ATTENDANCE_NOTE_PREFIX = 'event_checkin_v1:';
const TIMELINE_PAGE_LIMIT_MAX = 50;
const GALLERY_PAGE_LIMIT_MAX = 100;

type CheckinPagination = {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

const normalizeText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const normalizeLegacyKey = (value: string): string =>
  value
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .normalize('NFKC');

const normalizeActType = (value: unknown): 'solo' | 'b2b' | 'b3b' => {
  const normalized = normalizeText(value).toLowerCase();
  if (normalized === 'b2b' || normalized === 'b3b') {
    return normalized;
  }
  return 'solo';
};

const composeActDisplayName = (
  actType: 'solo' | 'b2b' | 'b3b',
  performers: CheckinOverviewTimelinePerformer[],
  fallback: string
): string => {
  const names = performers
    .slice()
    .sort((left, right) => left.performerIndex - right.performerIndex)
    .map((performer) => normalizeText(performer.name))
    .filter(Boolean);

  if (actType === 'b3b' && names.length >= 3) return names.slice(0, 3).join(' B3B ');
  if (actType === 'b2b' && names.length >= 2) return names.slice(0, 2).join(' B2B ');
  return names[0] ?? normalizeText(fallback);
};

const parseLegacySelections = (note: string | null): LegacySelectionDay[] => {
  const trimmed = normalizeText(note);
  if (!trimmed.startsWith(EVENT_ATTENDANCE_NOTE_PREFIX)) {
    return [];
  }

  const rawPayload = trimmed.slice(EVENT_ATTENDANCE_NOTE_PREFIX.length);
  if (!rawPayload) return [];

  try {
    const parsed = JSON.parse(rawPayload) as unknown;
    if (Array.isArray(parsed)) {
      return parsed.map(normalizeLegacyDay).filter((item): item is LegacySelectionDay => item !== null);
    }
    const single = normalizeLegacyDay(parsed);
    return single ? [single] : [];
  } catch {
    return [];
  }
};

const normalizeLegacyDay = (value: unknown): LegacySelectionDay | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const row = value as Record<string, unknown>;
  const dayID = normalizeText(row.dayID ?? row.dayId);
  const dayIndex = Number(row.dayIndex);
  const sourceSelections = Array.isArray(row.djSelections) ? row.djSelections : [];
  if (!dayID || !Number.isFinite(dayIndex)) return null;

  const djSelections = sourceSelections
    .map(normalizeLegacySelectionDJ)
    .filter((item): item is LegacySelectionDJ => item !== null);

  return {
    dayID,
    dayIndex: Math.max(1, Math.floor(dayIndex)),
    djSelections,
  };
};

const normalizeLegacySelectionDJ = (value: unknown): LegacySelectionDJ | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const row = value as Record<string, unknown>;
  const id = normalizeText(row.id);
  const name = normalizeText(row.name);
  if (!id || !name) return null;
  return {
    id,
    name,
    avatarUrl: normalizeText(row.avatarUrl) || null,
    country: normalizeText(row.country) || null,
  };
};

const buildStructuredTimelineDays = (
  selections: EventTimelineRow['selections']
): CheckinOverviewTimelineDay[] =>
  selections
    .slice()
    .sort((left, right) => left.dayIndex - right.dayIndex)
    .map((selection) => {
      const groupedActs = new Map<string, CheckinOverviewTimelineAct>();

      for (const dj of [...selection.djs].sort((left, right) => {
        if (left.sortOrder !== right.sortOrder) return left.sortOrder - right.sortOrder;
        return left.performerIndex - right.performerIndex;
      })) {
        const actGroupId =
          normalizeText(dj.actGroupId) || `${selection.dayId}:act:${normalizeLegacyKey(dj.displayName)}`;
        const actType = normalizeActType(dj.actType);
        const existing = groupedActs.get(actGroupId);
        const performer: CheckinOverviewTimelinePerformer = {
          djId: dj.djId,
          name: dj.displayName,
          avatarUrl: dj.avatarUrl,
          country: dj.country,
          performerIndex: dj.performerIndex,
        };

        if (existing) {
          existing.performers.push(performer);
          continue;
        }

        groupedActs.set(actGroupId, {
          actGroupId,
          actType,
          displayName: dj.displayName,
          performers: [performer],
        });
      }

      const acts = Array.from(groupedActs.values()).map((act) => {
        const performers = act.performers.sort((left, right) => left.performerIndex - right.performerIndex);
        return {
          ...act,
          displayName: composeActDisplayName(act.actType, performers, act.displayName),
          performers,
        };
      });

      return {
        dayId: selection.dayId,
        dayIndex: selection.dayIndex,
        acts,
      };
    });

const buildLegacyTimelineDays = (note: string | null): CheckinOverviewTimelineDay[] =>
  parseLegacySelections(note).map((day) => ({
    dayId: day.dayID,
    dayIndex: day.dayIndex,
    acts: day.djSelections.map((selection, index) => {
      return {
        actGroupId: `${day.dayID}:legacy:${index + 1}`,
        actType: 'solo' as const,
        displayName: selection.name,
        performers: [
          {
            djId: selection.id,
            name: selection.name,
            avatarUrl: selection.avatarUrl ?? null,
            country: selection.country ?? null,
            performerIndex: 0,
          },
        ],
      };
    }),
  }));

const summarizeTimelineDays = (days: CheckinOverviewTimelineDay[]): {
  dayCount: number;
  artistCount: number;
  performanceCount: number;
} => {
  const artistKeys = new Set<string>();
  let performanceCount = 0;

  for (const day of days) {
    performanceCount += day.acts.length;
    for (const act of day.acts) {
      for (const performer of act.performers) {
        if (performer.djId) {
          artistKeys.add(`id:${performer.djId}`);
        }
      }
    }
  }

  return {
    dayCount: days.length,
    artistCount: artistKeys.size,
    performanceCount,
  };
};

export const mapCheckinTimelineItem = (row: EventTimelineRow): CheckinOverviewTimelineItem | null => {
  if (!row.eventId) return null;

  const days =
    row.selections.length > 0 ? buildStructuredTimelineDays(row.selections) : buildLegacyTimelineDays(row.note);
  const summary = summarizeTimelineDays(days);
  const eventName = normalizeText(row.snapshot?.eventName) || row.event?.name || null;

  return {
    id: row.id,
    type: 'event',
    attendedAt: row.attendedAt,
    createdAt: row.createdAt,
    event: {
      id: row.eventId,
      name: eventName,
      nameI18n:
        (normalizeBiText(row.snapshot?.eventNameI18n ?? row.event?.nameI18n, eventName ?? '') as Record<
          string,
          unknown
        > | null) ?? null,
      coverImageUrl: row.snapshot?.eventCoverUrl ?? row.event?.coverImageUrl ?? null,
      address: row.snapshot?.eventAddress ?? resolveEventAddress(row.event) ?? null,
      city: row.snapshot?.eventCity ?? row.event?.city ?? null,
      country: row.snapshot?.eventCountry ?? row.event?.country ?? null,
      startDate: row.event?.startDate ?? null,
      endDate: row.event?.endDate ?? null,
    },
    summary,
    selections: days,
  };
};

export const aggregateCheckinArtists = (rows: ArtistAggregateRow[]): CheckinOverviewGalleryArtistItem[] => {
  const aggregates = new Map<string, CheckinOverviewGalleryArtistItem>();

  const upsertArtist = (input: {
    djId: string | null;
    name: string;
    avatarUrl: string | null;
    country: string | null;
    attendedAt: Date;
  }): void => {
    if (!input.djId) return;
    const name = normalizeText(input.name);
    if (!name) return;
    const key = `id:${input.djId}`;
    const existing = aggregates.get(key);
    if (existing) {
      existing.count += 1;
      if (input.attendedAt > existing.latestAttendedAt) {
        existing.latestAttendedAt = input.attendedAt;
      }
      if (!existing.avatarUrl && input.avatarUrl) {
        existing.avatarUrl = input.avatarUrl;
      }
      if (!existing.country && input.country) {
        existing.country = input.country;
      }
      return;
    }

    aggregates.set(key, {
      djId: input.djId,
      name,
      avatarUrl: input.avatarUrl,
      country: input.country,
      count: 1,
      latestAttendedAt: input.attendedAt,
    });
  };

  for (const row of rows) {
    if (row.type === 'dj' && row.dj) {
      upsertArtist({
        djId: row.dj.id,
        name: row.dj.name,
        avatarUrl: row.dj.avatarUrl,
        country: row.dj.country,
        attendedAt: row.attendedAt,
      });
    }

    if (row.selections.length > 0) {
      for (const selection of row.selections) {
        for (const dj of selection.djs) {
          upsertArtist({
            djId: dj.djId,
            name: dj.displayName,
            avatarUrl: dj.avatarUrl,
            country: dj.country,
            attendedAt: row.attendedAt,
          });
        }
      }
      continue;
    }

    for (const day of parseLegacySelections(row.note)) {
      for (const selection of day.djSelections) {
        upsertArtist({
          djId: selection.id,
          name: selection.name,
          avatarUrl: selection.avatarUrl ?? null,
          country: selection.country ?? null,
          attendedAt: row.attendedAt,
        });
      }
    }
  }

  return Array.from(aggregates.values()).sort((left, right) => {
    if (left.count !== right.count) return right.count - left.count;
    if (left.latestAttendedAt.getTime() !== right.latestAttendedAt.getTime()) {
      return right.latestAttendedAt.getTime() - left.latestAttendedAt.getTime();
    }
    return left.name.localeCompare(right.name, 'en', { sensitivity: 'base' });
  });
};

export const buildCheckinAccessWhere = (
  targetUserId: string,
  viewerUserId?: string | null
): Prisma.CheckinWhereInput => {
  const includePrivate = viewerUserId === targetUserId;
  return {
    userId: targetUserId,
    status: 'active',
    OR: [{ note: null }, { note: { not: 'marked' } }],
    ...(includePrivate ? {} : { visibility: 'visible' }),
  };
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

export const buildCheckinPagination = (page: number, limit: number, total: number): CheckinPagination => ({
  page,
  limit,
  total,
  totalPages: Math.max(1, Math.ceil(total / limit)),
});

const userExists = async (prisma: PrismaClient, targetUserId: string): Promise<boolean> => {
  const user = await prisma.user.findUnique({
    where: { id: targetUserId },
    select: { id: true },
  });
  return Boolean(user);
};

export async function fetchCheckinOverview(
  prisma: PrismaClient,
  targetUserId: string,
  viewerUserId?: string | null
): Promise<CheckinOverviewResponse | null> {
  if (!(await userExists(prisma, targetUserId))) return null;

  const baseWhere = buildCheckinAccessWhere(targetUserId, viewerUserId);

  const [eventCount, latestCheckin, timelineRows, artistRows] = await Promise.all([
    prisma.checkin.count({
      where: {
        ...baseWhere,
        type: 'event',
      },
    }),
    prisma.checkin.findFirst({
      where: baseWhere,
      orderBy: [{ attendedAt: 'desc' }, { createdAt: 'desc' }],
      select: { attendedAt: true },
    }),
    prisma.checkin.findMany({
      where: {
        ...baseWhere,
        type: 'event',
      },
      orderBy: [{ attendedAt: 'desc' }, { createdAt: 'desc' }],
      take: OVERVIEW_TIMELINE_LIMIT,
      select: {
        id: true,
        eventId: true,
        type: true,
        note: true,
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
        snapshot: {
          select: {
            eventName: true,
            eventNameI18n: true,
            eventCoverUrl: true,
            eventCity: true,
            eventCountry: true,
            eventAddress: true,
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
    }),
    prisma.checkin.findMany({
      where: {
        ...baseWhere,
        OR: [{ type: 'dj' }, { type: 'event' }],
      },
      select: {
        type: true,
        attendedAt: true,
        djId: true,
        note: true,
        dj: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
            country: true,
          },
        },
        selections: {
          select: {
            dayId: true,
            dayIndex: true,
            djs: {
              select: {
                djId: true,
                displayName: true,
                rawName: true,
                avatarUrl: true,
                country: true,
                actType: true,
                performerIndex: true,
                actGroupId: true,
              },
            },
          },
        },
      },
    }),
  ]);

  const timelineItems = timelineRows
    .map(mapCheckinTimelineItem)
    .filter((item): item is CheckinOverviewTimelineItem => item !== null);
  const allArtists = aggregateCheckinArtists(artistRows);
  const topArtists = allArtists.slice(0, GALLERY_ARTIST_LIMIT);

  return {
    stats: {
      eventCount,
      artistCount: allArtists.length,
      latestCheckinAt: latestCheckin?.attendedAt ?? null,
    },
    timeline: {
      items: timelineItems,
      pagination: {
        limit: OVERVIEW_TIMELINE_LIMIT,
        hasMore: eventCount > timelineItems.length,
        totalEventCount: eventCount,
      },
    },
    gallerySummary: {
      topEvents: timelineItems.map((item) => ({
        eventId: item.event.id,
        name: item.event.name,
        coverImageUrl: item.event.coverImageUrl,
        address: item.event.address,
        attendedAt: item.attendedAt,
        artistCount: item.summary.artistCount,
        performanceCount: item.summary.performanceCount,
      })),
      topArtists,
    },
  };
}

export async function fetchCheckinTimelinePage(
  prisma: PrismaClient,
  targetUserId: string,
  viewerUserId: string | null | undefined,
  page: number,
  limit: number
): Promise<{ data: CheckinTimelineResponse; pagination: CheckinPagination } | null> {
  if (!(await userExists(prisma, targetUserId))) return null;

  const { page: normalizedPage, limit: normalizedLimit, skip } = normalizePageLimit(
    page,
    limit,
    20,
    TIMELINE_PAGE_LIMIT_MAX
  );
  const baseWhere = buildCheckinAccessWhere(targetUserId, viewerUserId);
  const eventWhere: Prisma.CheckinWhereInput = {
    ...baseWhere,
    type: 'event',
  };

  const [total, timelineRows] = await Promise.all([
    prisma.checkin.count({ where: eventWhere }),
    prisma.checkin.findMany({
      where: eventWhere,
      orderBy: [{ attendedAt: 'desc' }, { createdAt: 'desc' }],
      skip,
      take: normalizedLimit,
      select: {
        id: true,
        eventId: true,
        type: true,
        note: true,
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
        snapshot: {
          select: {
            eventName: true,
            eventNameI18n: true,
            eventCoverUrl: true,
            eventCity: true,
            eventCountry: true,
            eventAddress: true,
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
    }),
  ]);

  const items = timelineRows
    .map(mapCheckinTimelineItem)
    .filter((item): item is CheckinOverviewTimelineItem => item !== null);

  return {
    data: { items },
    pagination: buildCheckinPagination(normalizedPage, normalizedLimit, total),
  };
}

export async function fetchCheckinGalleryEventsPage(
  prisma: PrismaClient,
  targetUserId: string,
  viewerUserId: string | null | undefined,
  page: number,
  limit: number
): Promise<{ data: CheckinGalleryEventsResponse; pagination: CheckinPagination } | null> {
  if (!(await userExists(prisma, targetUserId))) return null;

  const { page: normalizedPage, limit: normalizedLimit, skip } = normalizePageLimit(
    page,
    limit,
    20,
    GALLERY_PAGE_LIMIT_MAX
  );
  const baseWhere = buildCheckinAccessWhere(targetUserId, viewerUserId);
  const eventWhere: Prisma.CheckinWhereInput = {
    ...baseWhere,
    type: 'event',
  };

  const [total, rows] = await Promise.all([
    prisma.checkin.count({ where: eventWhere }),
    prisma.checkin.findMany({
      where: eventWhere,
      orderBy: [{ attendedAt: 'desc' }, { createdAt: 'desc' }],
      skip,
      take: normalizedLimit,
      select: {
        id: true,
        eventId: true,
        type: true,
        note: true,
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
        snapshot: {
          select: {
            eventName: true,
            eventNameI18n: true,
            eventCoverUrl: true,
            eventCity: true,
            eventCountry: true,
            eventAddress: true,
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
    }),
  ]);

  const items = rows
    .map(mapCheckinTimelineItem)
    .filter((item): item is CheckinOverviewTimelineItem => item !== null)
    .map((item) => ({
      eventId: item.event.id,
      name: item.event.name,
      coverImageUrl: item.event.coverImageUrl,
      address: item.event.address,
      attendedAt: item.attendedAt,
      artistCount: item.summary.artistCount,
      performanceCount: item.summary.performanceCount,
    }));

  return {
    data: { items },
    pagination: buildCheckinPagination(normalizedPage, normalizedLimit, total),
  };
}

export async function fetchCheckinGalleryArtistsPage(
  prisma: PrismaClient,
  targetUserId: string,
  viewerUserId: string | null | undefined,
  page: number,
  limit: number
): Promise<{ data: CheckinGalleryArtistsResponse; pagination: CheckinPagination } | null> {
  if (!(await userExists(prisma, targetUserId))) return null;

  const { page: normalizedPage, limit: normalizedLimit, skip } = normalizePageLimit(
    page,
    limit,
    20,
    GALLERY_PAGE_LIMIT_MAX
  );
  const baseWhere = buildCheckinAccessWhere(targetUserId, viewerUserId);
  const rows = await prisma.checkin.findMany({
    where: {
      ...baseWhere,
      OR: [{ type: 'dj' }, { type: 'event' }],
    },
    select: {
      type: true,
      attendedAt: true,
      djId: true,
      note: true,
      dj: {
        select: {
          id: true,
          name: true,
          avatarUrl: true,
          country: true,
        },
      },
      selections: {
        select: {
          dayId: true,
          dayIndex: true,
          djs: {
            select: {
              djId: true,
              displayName: true,
              rawName: true,
              avatarUrl: true,
              country: true,
              actType: true,
              performerIndex: true,
              actGroupId: true,
            },
          },
        },
      },
    },
  });

  const allArtists = aggregateCheckinArtists(rows);
  const items = allArtists.slice(skip, skip + normalizedLimit);

  return {
    data: { items },
    pagination: buildCheckinPagination(normalizedPage, normalizedLimit, allArtists.length),
  };
}

export async function fetchCheckinStats(
  prisma: PrismaClient,
  targetUserId: string,
  viewerUserId?: string | null
): Promise<CheckinStatsResponse | null> {
  if (!(await userExists(prisma, targetUserId))) return null;

  const baseWhere = buildCheckinAccessWhere(targetUserId, viewerUserId);
  const [eventCount, latestCheckin, artistRows] = await Promise.all([
    prisma.checkin.count({
      where: {
        ...baseWhere,
        type: 'event',
      },
    }),
    prisma.checkin.findFirst({
      where: baseWhere,
      orderBy: [{ attendedAt: 'desc' }, { createdAt: 'desc' }],
      select: { attendedAt: true },
    }),
    prisma.checkin.findMany({
      where: {
        ...baseWhere,
        OR: [{ type: 'dj' }, { type: 'event' }],
      },
      select: {
        type: true,
        attendedAt: true,
        djId: true,
        note: true,
        dj: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
            country: true,
          },
        },
        selections: {
          select: {
            dayId: true,
            dayIndex: true,
            djs: {
              select: {
                djId: true,
                displayName: true,
                rawName: true,
                avatarUrl: true,
                country: true,
                actType: true,
                performerIndex: true,
                actGroupId: true,
              },
            },
          },
        },
      },
    }),
  ]);

  return {
    eventCount,
    artistCount: aggregateCheckinArtists(artistRows).length,
    latestCheckinAt: latestCheckin?.attendedAt ?? null,
  };
}
