import { Request, Response } from 'express';
import { Prisma, PrismaClient } from '@prisma/client';
import path from 'path';
import { AuthRequest } from '../middleware/auth';
import {
  buildMediaObjectKey,
  isObjectStorageConfigured,
  saveBufferToLocalUploads,
  shouldAllowLocalUploadFallback,
  uploadBufferToObjectStorage,
} from '../services/media-storage.service';
import { mediaAssetService } from '../services/media-asset.service';
import {
  DEFAULT_EVENT_TIME_ZONE,
  diffEventDays,
  getEventHour,
  isValidEventTimeZone,
  normalizeEventTimeZone,
  parseEventDateInput,
  setEventDayAndKeepTime,
  startOfEventDay,
} from '../utils/event-timezone';

const prisma = new PrismaClient();

type RawLineupSlotInput = {
  djId?: string;
  djIds?: string[];
  festivalDayIndex?: number;
  djName?: string;
  stageName?: string;
  sortOrder?: number;
  startTime?: string;
  endTime?: string;
};

type LineupSlotInput = {
  djId?: string;
  djIds?: string[];
  festivalDayIndex?: number;
  djName?: string;
  stageName?: string;
  sortOrder?: number;
  startTime: string;
  endTime: string;
};

type TicketTierInput = {
  name?: string;
  price?: number | string;
  currency?: string;
  sortOrder?: number;
};

type RawLineupArtistInput = {
  djId?: string;
  djIds?: string[];
  djName?: string;
  name?: string;
  musician?: string;
  artistName?: string;
  sortOrder?: number;
};

type LineupArtistInput = {
  djId: string | null;
  djIds: string[];
  djName: string;
  sortOrder: number;
};

const slugify = (value: string) =>
  value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '') || 'event';

const toNumberOrNull = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') {
    return null;
  }
  const num = Number(value);
  return Number.isFinite(num) ? num : null;
};

const EVENT_DEFAULT_START_TIME = '00:00:00';
const EVENT_DEFAULT_END_TIME = '23:59:59';

const normalizeEventClockTime = (value: unknown, fallback: string): string => {
  if (typeof value !== 'string') return fallback;
  const trimmed = value.trim();
  if (!trimmed) return fallback;
  const match = trimmed.match(/^(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$/);
  if (!match) return fallback;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  const second = Number(match[3] ?? '0');
  if (!Number.isInteger(hour) || !Number.isInteger(minute) || !Number.isInteger(second)) return fallback;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59 || second < 0 || second > 59) return fallback;
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:${String(second).padStart(2, '0')}`;
};

const normalizeEventStartDate = (date: Date, timeZone = DEFAULT_EVENT_TIME_ZONE): Date => startOfEventDay(date, timeZone);

const normalizeEventEndDate = (date: Date, timeZone = DEFAULT_EVENT_TIME_ZONE): Date =>
  new Date(startOfEventDay(date, timeZone).getTime() + 86_400_000 - 1000);

const resolveEventStatus = (
  startDate: Date,
  endDate: Date,
  fallbackStatus?: string | null
): 'upcoming' | 'ongoing' | 'ended' | 'cancelled' => {
  const normalizedFallback = typeof fallbackStatus === 'string' ? fallbackStatus.trim().toLowerCase() : '';
  if (normalizedFallback === 'cancelled' || normalizedFallback === 'canceled') {
    return 'cancelled';
  }

  const now = Date.now();
  const start = startDate.getTime();
  const end = endDate.getTime();

  if (Number.isFinite(start) && Number.isFinite(end) && end >= start) {
    if (now < start) return 'upcoming';
    if (now > end) return 'ended';
    return 'ongoing';
  }

  if (normalizedFallback === 'ongoing' || normalizedFallback === 'ended' || normalizedFallback === 'upcoming') {
    return normalizedFallback as 'upcoming' | 'ongoing' | 'ended';
  }
  return 'upcoming';
};

const withDerivedStatus = <T extends { startDate: Date; endDate: Date; status?: string | null }>(event: T) => ({
  ...event,
  status: resolveEventStatus(new Date(event.startDate), new Date(event.endDate), event.status ?? null),
});

const LINEUP_DJ_ID_PLACEHOLDER = '__UNBOUND__';
const isLineupDjIdPlaceholder = (value: string): boolean => value === LINEUP_DJ_ID_PLACEHOLDER;
const normalizeTrimmedText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  const text = value.trim();
  if (!text || /^\[object\s+object\]$/i.test(text)) return '';
  return text;
};

const normalizeOptionalTriTextJson = (value: unknown): Prisma.InputJsonValue | undefined => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return undefined;
  const row = value as Record<string, unknown>;
  const out: Record<string, string> = {};
  const zh = normalizeTrimmedText(row.zh ?? row.ZH ?? row.cn ?? row.chinese ?? row['zh-CN']);
  const en = normalizeTrimmedText(row.en ?? row.EN ?? row.english ?? row['en-US']);
  const ja = normalizeTrimmedText(row.ja ?? row.JA ?? row.jp ?? row.japanese ?? row['ja-JP']);
  const enFull = normalizeTrimmedText(row.enFull ?? row.en_full ?? row.englishFull ?? row.country_en_full);
  if (zh) out.zh = zh;
  if (en) out.en = en;
  if (ja) out.ja = ja;
  if (enFull) out.enFull = enFull;
  return Object.keys(out).length ? (out as Prisma.InputJsonValue) : undefined;
};
const normalizeDayRolloverHour = (value: unknown, fallback = 6): number => {
  const numeric = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(numeric)) return fallback;
  const hour = Math.floor(numeric);
  if (hour < 0 || hour > 23) return fallback;
  return hour;
};

const inferFestivalDayIndex = (
  startTime: Date,
  eventStartDate: Date,
  dayRolloverHour: number,
  timeZone = DEFAULT_EVENT_TIME_ZONE
): number | null => {
  if (Number.isNaN(startTime.getTime()) || Number.isNaN(eventStartDate.getTime())) {
    return null;
  }
  let dayOffset = diffEventDays(eventStartDate, startTime, timeZone);
  if (dayOffset > 0 && getEventHour(startTime, timeZone) < dayRolloverHour) {
    dayOffset -= 1;
  }
  return Math.max(1, dayOffset + 1);
};

const applyFestivalDayIndexToDate = (
  timeSource: Date,
  eventStartDate: Date,
  festivalDayIndex: number,
  timeZone = DEFAULT_EVENT_TIME_ZONE
): Date => setEventDayAndKeepTime(timeSource, eventStartDate, festivalDayIndex, timeZone);

type ExistingLineupSlotForRebase = {
  id: string;
  festivalDayIndex: number | null;
  startTime: Date;
  endTime: Date;
};

const rebaseExistingLineupSlotsToEventStart = (
  slots: ExistingLineupSlotForRebase[],
  previousEventStartDate: Date,
  nextEventStartDate: Date,
  dayRolloverHour: number,
  timeZone = DEFAULT_EVENT_TIME_ZONE
): Array<{ id: string; festivalDayIndex: number; startTime: Date; endTime: Date }> =>
  slots.map((slot) => {
    const festivalDayIndex =
      slot.festivalDayIndex
      ?? inferFestivalDayIndex(slot.startTime, previousEventStartDate, dayRolloverHour, timeZone)
      ?? 1;
    const endDayOffset = Math.max(0, diffEventDays(slot.startTime, slot.endTime, timeZone));
    const startTime = applyFestivalDayIndexToDate(slot.startTime, nextEventStartDate, festivalDayIndex, timeZone);
    let endTime = applyFestivalDayIndexToDate(slot.endTime, nextEventStartDate, festivalDayIndex + endDayOffset, timeZone);

    while (endTime < startTime) {
      endTime = new Date(endTime.getTime() + 86_400_000);
    }

    return {
      id: slot.id,
      festivalDayIndex,
      startTime,
      endTime,
    };
  });

const normalizeLineupSlots = (
  slots: unknown,
  eventStartDate: Date,
  dayRolloverHourRaw: unknown = 6,
  timeZoneRaw: unknown = DEFAULT_EVENT_TIME_ZONE
): LineupSlotInput[] => {
  if (!Array.isArray(slots)) {
    return [];
  }

  const dayRolloverHour = normalizeDayRolloverHour(dayRolloverHourRaw, 6);
  const timeZone = normalizeEventTimeZone(timeZoneRaw);
  const safeEventStart = Number.isNaN(eventStartDate.getTime()) ? new Date() : eventStartDate;
  return slots
    .filter((slot) => slot && typeof slot === 'object')
    .map((slot) => slot as RawLineupSlotInput)
    .map((slot, index) => {
      const parsedStart = parseEventDateInput(slot.startTime, timeZone, 'start');
      const parsedEnd = parseEventDateInput(slot.endTime, timeZone, 'end');
      const fallbackBase = new Date(safeEventStart.getTime() + index * 60_000);
      const explicitFestivalDayIndex =
        typeof slot.festivalDayIndex === 'number' && Number.isFinite(slot.festivalDayIndex)
          ? Math.max(1, Math.floor(slot.festivalDayIndex))
          : null;

      let startTime = fallbackBase;
      let endTime = fallbackBase;
      if (parsedStart && parsedEnd) {
        startTime = parsedStart;
        endTime = parsedEnd >= parsedStart ? parsedEnd : new Date(parsedStart.getTime() + 3_600_000);
      } else if (parsedStart) {
        startTime = parsedStart;
        endTime = new Date(parsedStart.getTime() + 3_600_000);
      } else if (parsedEnd) {
        endTime = parsedEnd;
        startTime = new Date(parsedEnd.getTime() - 3_600_000);
      }

      if (explicitFestivalDayIndex) {
        startTime = applyFestivalDayIndexToDate(startTime, safeEventStart, explicitFestivalDayIndex, timeZone);
        endTime = applyFestivalDayIndexToDate(endTime, safeEventStart, explicitFestivalDayIndex, timeZone);
        if (endTime < startTime) {
          endTime = new Date(endTime.getTime() + 86_400_000);
        }
      }

      const rawDjId = typeof slot.djId === 'string' && slot.djId.trim() ? slot.djId.trim() : '';
      const djIds = Array.isArray(slot.djIds)
        ? slot.djIds
            .map((id) => (typeof id === 'string' ? id.trim() : ''))
            .filter((id) => !!id)
        : [];
      const djId = rawDjId && !isLineupDjIdPlaceholder(rawDjId) ? rawDjId : undefined;
      const firstBoundDjId = djIds.find((id) => !isLineupDjIdPlaceholder(id)) || undefined;
      const mergedDjIds = djIds.length
        ? djIds
        : (djId ? [djId] : []);
      const effectiveDjId = djId || firstBoundDjId;
      const festivalDayIndex =
        explicitFestivalDayIndex
        ?? inferFestivalDayIndex(startTime, safeEventStart, dayRolloverHour, timeZone);

      return {
        djId: effectiveDjId,
        djIds: mergedDjIds,
        festivalDayIndex: festivalDayIndex ?? undefined,
        djName: slot.djName,
        stageName: slot.stageName,
        sortOrder: slot.sortOrder,
        startTime: startTime.toISOString(),
        endTime: endTime.toISOString(),
      };
    })
    .filter((slot) => String(slot.djName || '').trim() || String(slot.djId || '').trim() || (Array.isArray(slot.djIds) && slot.djIds.length > 0));
};

const buildLineupArtistsFromSlots = (slots: LineupSlotInput[]): LineupArtistInput[] => {
  const byKey = new Map<string, LineupArtistInput>();
  for (const [index, slot] of slots.entries()) {
    const djName = String(slot.djName || '').trim();
    if (!djName) continue;
    const djIds = Array.isArray(slot.djIds) ? slot.djIds.filter((id) => id && !isLineupDjIdPlaceholder(id)) : [];
    const primaryDjId = slot.djId && !isLineupDjIdPlaceholder(slot.djId) ? slot.djId : (djIds[0] || null);
    const key = primaryDjId ? `id:${primaryDjId}` : `name:${djName.toLowerCase()}`;
    const existing = byKey.get(key);
    if (existing) {
      existing.djIds = Array.from(new Set([...(existing.djIds || []), ...djIds, ...(primaryDjId ? [primaryDjId] : [])])).filter(Boolean);
      if (!existing.djId && primaryDjId) existing.djId = primaryDjId;
      existing.sortOrder = Math.min(existing.sortOrder, slot.sortOrder || index + 1);
      continue;
    }
    byKey.set(key, {
      djId: primaryDjId,
      djIds: Array.from(new Set([...djIds, ...(primaryDjId ? [primaryDjId] : [])])).filter(Boolean),
      djName,
      sortOrder: slot.sortOrder || index + 1,
    });
  }
  return Array.from(byKey.values()).sort((a, b) => a.sortOrder - b.sortOrder);
};

const normalizeLineupArtists = (artists: unknown, fallbackSlots: LineupSlotInput[] = []): LineupArtistInput[] => {
  const source = Array.isArray(artists) ? artists : null;
  if (!source) return buildLineupArtistsFromSlots(fallbackSlots);
  const byKey = new Map<string, LineupArtistInput>();
  for (const [index, raw] of source.entries()) {
    if (!raw || typeof raw !== 'object') continue;
    const row = raw as RawLineupArtistInput;
    const djName = String(row.djName ?? row.name ?? row.musician ?? row.artistName ?? '').trim();
    if (!djName) continue;
    const djIds = (Array.isArray(row.djIds) ? row.djIds : [])
      .map((id) => String(id || '').trim())
      .filter((id) => id && !isLineupDjIdPlaceholder(id));
    const primaryRaw = String(row.djId || '').trim();
    const djId = primaryRaw && !isLineupDjIdPlaceholder(primaryRaw) ? primaryRaw : (djIds[0] || null);
    const mergedIds = Array.from(new Set([...djIds, ...(djId ? [djId] : [])])).filter(Boolean);
    const sortOrder = typeof row.sortOrder === 'number' && Number.isFinite(row.sortOrder) ? row.sortOrder : index + 1;
    const key = djId ? `id:${djId}` : `name:${djName.toLowerCase()}`;
    const existing = byKey.get(key);
    if (existing) {
      existing.djIds = Array.from(new Set([...(existing.djIds || []), ...mergedIds])).filter(Boolean);
      existing.sortOrder = Math.min(existing.sortOrder, sortOrder);
      continue;
    }
    byKey.set(key, { djId, djIds: mergedIds, djName, sortOrder });
  }
  return Array.from(byKey.values()).sort((a, b) => a.sortOrder - b.sortOrder);
};

const normalizeTicketTiers = (tiers: unknown): TicketTierInput[] => {
  if (!Array.isArray(tiers)) {
    return [];
  }
  return tiers
    .filter((tier) => tier && typeof tier === 'object')
    .map((tier) => tier as TicketTierInput)
    .filter((tier) => String(tier.name || '').trim() && toNumberOrNull(tier.price) !== null);
};

export const getEvents = async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      page = '1',
      limit = '20',
      search,
      city,
      country,
      eventType,
      year,
      status = 'upcoming'
    } = req.query;
    const normalizedStatus = String(status || 'upcoming').trim().toLowerCase() === 'canceled'
      ? 'cancelled'
      : String(status || 'upcoming').trim().toLowerCase();

    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    const where: any = {};
    const now = new Date();
    if (normalizedStatus === 'upcoming') {
      where.startDate = { gt: now };
      where.status = { not: 'cancelled' };
    } else if (normalizedStatus === 'ongoing') {
      where.startDate = { lte: now };
      where.endDate = { gte: now };
      where.status = { not: 'cancelled' };
    } else if (normalizedStatus === 'ended') {
      where.endDate = { lt: now };
      where.status = { not: 'cancelled' };
    } else if (normalizedStatus === 'cancelled') {
      where.status = 'cancelled';
    } else if (normalizedStatus === 'all' || normalizedStatus === '') {
      // no status filter
    } else if (normalizedStatus) {
      where.status = normalizedStatus;
    }

    if (search) {
      where.OR = [
        { name: { contains: search as string, mode: 'insensitive' } },
        { description: { contains: search as string, mode: 'insensitive' } },
      ];
    }

    if (city) {
      where.city = city as string;
    }

    if (country) {
      where.country = country as string;
    }
    const yearNum = Number(year);
    if (Number.isInteger(yearNum) && yearNum > 1900 && yearNum < 3000) {
      where.startDate = {
        ...(where.startDate && typeof where.startDate === 'object' ? where.startDate : {}),
        gte: new Date(Date.UTC(yearNum, 0, 1)),
        lt: new Date(Date.UTC(yearNum + 1, 0, 1)),
      };
    }
    if (eventType) {
      where.eventType = eventType as string;
    }

    const [events, total] = await Promise.all([
      prisma.event.findMany({
        where,
        skip,
        take: limitNum,
        orderBy: { startDate: 'asc' },
        include: {
          ticketTiers: {
            orderBy: { sortOrder: 'asc' },
          },
          lineupSlots: {
            orderBy: { startTime: 'asc' },
            include: {
              dj: {
                select: { id: true, name: true, avatarUrl: true, bannerUrl: true },
              },
            },
          },
          lineupArtists: {
            orderBy: { sortOrder: 'asc' },
            include: {
              dj: {
                select: { id: true, name: true, avatarUrl: true, bannerUrl: true },
              },
            },
          },
          organizer: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
        },
      }),
      prisma.event.count({ where }),
    ]);

    res.json({
      events: events.map((event) => withDerivedStatus(event)),
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        totalPages: Math.ceil(total / limitNum),
      },
    });
  } catch (error) {
    console.error('Get events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getEventYears = async (_req: Request, res: Response): Promise<void> => {
  try {
    const rows = await prisma.$queryRaw<Array<{ year: number; count: number }>>`
      SELECT EXTRACT(YEAR FROM "startDate")::int AS "year", COUNT(*)::int AS "count"
      FROM "events"
      GROUP BY 1
      ORDER BY 1 DESC
    `;
    res.json({ years: rows });
  } catch (error) {
    console.error('Get event years error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getMyEvents = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const events = await prisma.event.findMany({
      where: { organizerId: userId },
      orderBy: { createdAt: 'desc' },
      include: {
        ticketTiers: {
          orderBy: { sortOrder: 'asc' },
        },
        lineupSlots: {
          orderBy: { startTime: 'asc' },
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true, bannerUrl: true },
            },
          },
        },
        lineupArtists: {
          orderBy: { sortOrder: 'asc' },
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true, bannerUrl: true },
            },
          },
        },
        organizer: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
    });

    res.json({ events: events.map((event) => withDerivedStatus(event)) });
  } catch (error) {
    console.error('Get my events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getEvent = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const event = await prisma.event.findUnique({
      where: { id: id as string },
      include: {
        ticketTiers: {
          orderBy: { sortOrder: 'asc' },
        },
        lineupSlots: {
          orderBy: { startTime: 'asc' },
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true },
            },
          },
        },
        lineupArtists: {
          orderBy: { sortOrder: 'asc' },
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true },
            },
          },
        },
        organizer: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!event) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    res.json(withDerivedStatus(event));
  } catch (error) {
    console.error('Get event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const createEvent = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    const role = req.user?.role;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const {
      name,
      slug,
      description,
      coverImageUrl,
      lineupImageUrl,
      eventType,
      organizerName,
      city,
      cityI18n,
      country,
      countryI18n,
      manualLocation,
      locationPoint,
      latitude,
      longitude,
      startDate,
      endDate,
      timeZone,
      startTime,
      endTime,
      dayRolloverHour,
      ticketUrl,
      ticketPriceMin,
      ticketPriceMax,
      ticketCurrency,
      ticketNotes,
      ticketTiers,
      officialWebsite,
      lineupSlots,
      status,
    } = req.body;

    if (!name || !startDate || !endDate) {
      res.status(400).json({ error: 'Name, startDate, and endDate are required' });
      return;
    }

    if (!isValidEventTimeZone(timeZone)) {
      res.status(400).json({ error: 'Valid event timeZone is required' });
      return;
    }

    if (role !== 'admin' && role !== 'operator') {
      const submission = await prisma.contentSubmission.create({
        data: {
          submitterId: userId,
          entityType: 'event',
          title: String(name).trim(),
          payload: req.body,
          status: 'pending',
        },
      });
      res.status(202).json({
        message: '活动信息已提交审核，管理员审核通过后才会入库',
        submission,
      });
      return;
    }

    const desiredSlug = slug || slugify(name);
    const existingEvent = await prisma.event.findUnique({
      where: { slug: desiredSlug },
    });

    if (existingEvent) {
      res.status(409).json({ error: 'Event with this slug already exists' });
      return;
    }

    const normalizedTicketTiers = normalizeTicketTiers(ticketTiers);
    const normalizedTimeZone = normalizeEventTimeZone(timeZone);
    const normalizedStartTime = normalizeEventClockTime(startTime, EVENT_DEFAULT_START_TIME);
    const normalizedEndTime = normalizeEventClockTime(endTime, EVENT_DEFAULT_END_TIME);
    const parsedStartDateInput = parseEventDateInput(startDate, normalizedTimeZone, 'start', normalizedStartTime);
    const parsedEndDateInput = parseEventDateInput(endDate, normalizedTimeZone, 'end', normalizedEndTime);
    if (!parsedStartDateInput || !parsedEndDateInput) {
      res.status(400).json({ error: 'Invalid event date range' });
      return;
    }
    const parsedStartDate = normalizeEventStartDate(parsedStartDateInput, normalizedTimeZone);
    const parsedEndDate = normalizeEventEndDate(parsedEndDateInput, normalizedTimeZone);
    const normalizedDayRolloverHour = normalizeDayRolloverHour(dayRolloverHour, 6);
    const normalizedSlots = normalizeLineupSlots(lineupSlots, parsedStartDate, normalizedDayRolloverHour, normalizedTimeZone);
    const normalizedLineupArtists = normalizeLineupArtists(req.body.lineupArtists, normalizedSlots);
    const normalizedNameI18n = normalizeOptionalTriTextJson(req.body.nameI18n);
    const normalizedDescriptionI18n = normalizeOptionalTriTextJson(req.body.descriptionI18n);
    const normalizedCityI18n = normalizeOptionalTriTextJson(cityI18n);
    const normalizedCountryI18n = normalizeOptionalTriTextJson(countryI18n);

    const event = await prisma.event.create({
      data: {
        organizerId: userId,
        name,
        slug: desiredSlug,
        description,
        nameI18n: normalizedNameI18n,
        descriptionI18n: normalizedDescriptionI18n,
        coverImageUrl,
        lineupImageUrl,
        eventType,
        organizerName,
        city,
        cityI18n: normalizedCityI18n,
        country,
        countryI18n: normalizedCountryI18n,
        manualLocation,
        locationPoint,
        latitude: toNumberOrNull(latitude),
        longitude: toNumberOrNull(longitude),
        startDate: parsedStartDate,
        endDate: parsedEndDate,
        timeZone: normalizedTimeZone,
        startTime: normalizedStartTime,
        endTime: normalizedEndTime,
        dayRolloverHour: normalizedDayRolloverHour,
        status: resolveEventStatus(parsedStartDate, parsedEndDate, typeof status === 'string' ? status : null),
        ticketUrl,
        ticketPriceMin: toNumberOrNull(ticketPriceMin),
        ticketPriceMax: toNumberOrNull(ticketPriceMax),
        ticketCurrency,
        ticketNotes,
        ticketTiers: normalizedTicketTiers.length
          ? {
              create: normalizedTicketTiers.map((tier, index) => ({
                name: String(tier.name).trim(),
                price: Number(tier.price),
                currency: tier.currency || ticketCurrency || null,
                sortOrder: tier.sortOrder ?? index + 1,
              })),
            }
          : undefined,
        officialWebsite,
        lineupArtists: normalizedLineupArtists.length
          ? {
              create: normalizedLineupArtists.map((artist) => ({
                djId: artist.djId,
                djIds: artist.djIds,
                djName: artist.djName,
                sortOrder: artist.sortOrder,
              })),
            }
          : undefined,
        lineupSlots: normalizedSlots.length
          ? {
              create: normalizedSlots.map((slot, index) => ({
                djId: slot.djId || null,
                djIds: Array.isArray(slot.djIds) ? slot.djIds : [],
                festivalDayIndex: slot.festivalDayIndex ?? null,
                djName: slot.djName || 'Unknown DJ',
                stageName: slot.stageName || null,
                sortOrder: slot.sortOrder ?? index + 1,
                startTime: new Date(slot.startTime),
                endTime: new Date(slot.endTime),
              })),
            }
          : undefined,
      },
      include: {
        ticketTiers: {
          orderBy: { sortOrder: 'asc' },
        },
        lineupSlots: {
          orderBy: { startTime: 'asc' },
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true, bannerUrl: true },
            },
          },
        },
        lineupArtists: {
          orderBy: { sortOrder: 'asc' },
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true, bannerUrl: true },
            },
          },
        },
        organizer: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
    });

    res.status(201).json(withDerivedStatus(event));
  } catch (error) {
    console.error('Create event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const updateEvent = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const userId = req.user?.userId;
    const role = req.user?.role;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const {
      name,
      slug,
      description,
      coverImageUrl,
      lineupImageUrl,
      eventType,
      organizerName,
      city,
      cityI18n,
      country,
      countryI18n,
      manualLocation,
      locationPoint,
      latitude,
      longitude,
      startDate,
      endDate,
      timeZone,
      startTime,
      endTime,
      dayRolloverHour,
      ticketUrl,
      ticketPriceMin,
      ticketPriceMax,
      ticketCurrency,
      ticketNotes,
      ticketTiers,
      officialWebsite,
      lineupSlots,
      status,
    } = req.body;

    const existing = await prisma.event.findUnique({
      where: { id: id as string },
      select: {
        id: true,
        organizerId: true,
        startDate: true,
        endDate: true,
        timeZone: true,
        startTime: true,
        endTime: true,
        dayRolloverHour: true,
        status: true,
        lineupSlots: {
          select: {
            id: true,
            festivalDayIndex: true,
            startTime: true,
            endTime: true,
          },
        },
      },
    });
    if (!existing) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    if (role !== 'admin' && existing.organizerId !== userId) {
      res.status(403).json({ error: 'You can only edit your own event' });
      return;
    }

    if (timeZone !== undefined && !isValidEventTimeZone(timeZone)) {
      res.status(400).json({ error: 'Valid event timeZone is required' });
      return;
    }
    const nextTimeZone = timeZone !== undefined
      ? normalizeEventTimeZone(timeZone, existing.timeZone ?? DEFAULT_EVENT_TIME_ZONE)
      : normalizeEventTimeZone(existing.timeZone ?? DEFAULT_EVENT_TIME_ZONE);
    const nextStartTime = startTime !== undefined
      ? normalizeEventClockTime(startTime, EVENT_DEFAULT_START_TIME)
      : normalizeEventClockTime(existing.startTime, EVENT_DEFAULT_START_TIME);
    const nextEndTime = endTime !== undefined
      ? normalizeEventClockTime(endTime, EVENT_DEFAULT_END_TIME)
      : normalizeEventClockTime(existing.endTime, EVENT_DEFAULT_END_TIME);
    const nextStartDateInput = startDate ? parseEventDateInput(startDate, nextTimeZone, 'start', nextStartTime) : null;
    if (startDate && !nextStartDateInput) {
      res.status(400).json({ error: 'Invalid startDate' });
      return;
    }
    const nextEndDateInput = endDate ? parseEventDateInput(endDate, nextTimeZone, 'end', nextEndTime) : null;
    if (endDate && !nextEndDateInput) {
      res.status(400).json({ error: 'Invalid endDate' });
      return;
    }
    const nextStartDate = nextStartDateInput ? normalizeEventStartDate(nextStartDateInput, nextTimeZone) : null;
    const nextEndDate = nextEndDateInput ? normalizeEventEndDate(nextEndDateInput, nextTimeZone) : null;
    const effectiveStartDate = nextStartDate ?? existing.startDate;
    const effectiveEndDate = nextEndDate ?? existing.endDate;
    const nextDayRolloverHour = dayRolloverHour !== undefined
      ? normalizeDayRolloverHour(dayRolloverHour, existing.dayRolloverHour ?? 6)
      : (existing.dayRolloverHour ?? 6);
    const normalizedSlots = normalizeLineupSlots(lineupSlots, nextStartDate ?? existing.startDate, nextDayRolloverHour, nextTimeZone);
    const normalizedLineupArtists = normalizeLineupArtists(req.body.lineupArtists, normalizedSlots);
    const normalizedTicketTiers = normalizeTicketTiers(ticketTiers);
    const shouldRebaseExistingLineupSlots =
      !Array.isArray(lineupSlots)
      && (startDate !== undefined || dayRolloverHour !== undefined || timeZone !== undefined)
      && existing.lineupSlots.length > 0;
    const shouldSyncLineupArtists = Array.isArray(req.body.lineupArtists) || Array.isArray(lineupSlots);
    const normalizedNameI18n = normalizeOptionalTriTextJson(req.body.nameI18n);
    const normalizedDescriptionI18n = normalizeOptionalTriTextJson(req.body.descriptionI18n);
    const normalizedCityI18n = normalizeOptionalTriTextJson(cityI18n);
    const normalizedCountryI18n = normalizeOptionalTriTextJson(countryI18n);

    await prisma.event.update({
      where: { id: id as string },
      data: {
        name: name ?? undefined,
        slug: slug ?? undefined,
        description: description ?? undefined,
        nameI18n: req.body.nameI18n !== undefined ? (normalizedNameI18n ?? Prisma.DbNull) : undefined,
        descriptionI18n: req.body.descriptionI18n !== undefined ? (normalizedDescriptionI18n ?? Prisma.DbNull) : undefined,
        coverImageUrl: coverImageUrl ?? undefined,
        lineupImageUrl: lineupImageUrl ?? undefined,
        eventType: eventType ?? undefined,
        organizerName: organizerName ?? undefined,
        city: city ?? undefined,
        cityI18n: cityI18n !== undefined ? (normalizedCityI18n ?? Prisma.DbNull) : undefined,
        country: country ?? undefined,
        countryI18n: countryI18n !== undefined ? (normalizedCountryI18n ?? Prisma.DbNull) : undefined,
        manualLocation: manualLocation ?? undefined,
        locationPoint: locationPoint ?? undefined,
        latitude: latitude !== undefined ? toNumberOrNull(latitude) : undefined,
        longitude: longitude !== undefined ? toNumberOrNull(longitude) : undefined,
        startDate: startDate ? nextStartDate ?? undefined : undefined,
        endDate: endDate ? nextEndDate ?? undefined : undefined,
        timeZone: timeZone !== undefined ? nextTimeZone : undefined,
        startTime: startTime !== undefined ? nextStartTime : undefined,
        endTime: endTime !== undefined ? nextEndTime : undefined,
        dayRolloverHour: dayRolloverHour !== undefined ? nextDayRolloverHour : undefined,
        ticketUrl: ticketUrl ?? undefined,
        ticketPriceMin: ticketPriceMin !== undefined ? toNumberOrNull(ticketPriceMin) : undefined,
        ticketPriceMax: ticketPriceMax !== undefined ? toNumberOrNull(ticketPriceMax) : undefined,
        ticketCurrency: ticketCurrency ?? undefined,
        ticketNotes: ticketNotes ?? undefined,
        ticketTiers: Array.isArray(ticketTiers)
          ? {
              deleteMany: {},
              create: normalizedTicketTiers.map((tier, index) => ({
                name: String(tier.name).trim(),
                price: Number(tier.price),
                currency: tier.currency || ticketCurrency || null,
                sortOrder: tier.sortOrder ?? index + 1,
              })),
            }
          : undefined,
        officialWebsite: officialWebsite ?? undefined,
        status: resolveEventStatus(
          effectiveStartDate,
          effectiveEndDate,
          typeof status === 'string' ? status : existing.status
        ),
        lineupArtists: shouldSyncLineupArtists
          ? {
              deleteMany: {},
              create: normalizedLineupArtists.map((artist) => ({
                djId: artist.djId,
                djIds: artist.djIds,
                djName: artist.djName,
                sortOrder: artist.sortOrder,
              })),
            }
          : undefined,
        lineupSlots: Array.isArray(lineupSlots)
          ? {
              deleteMany: {},
              create: normalizedSlots.map((slot, index) => ({
                djId: slot.djId || null,
                djIds: Array.isArray(slot.djIds) ? slot.djIds : [],
                festivalDayIndex: slot.festivalDayIndex ?? null,
                djName: slot.djName || 'Unknown DJ',
                stageName: slot.stageName || null,
                sortOrder: slot.sortOrder ?? index + 1,
                startTime: new Date(slot.startTime),
                endTime: new Date(slot.endTime),
              })),
            }
          : undefined,
      },
    });

    if (shouldRebaseExistingLineupSlots) {
      const rebasedSlots = rebaseExistingLineupSlotsToEventStart(
        existing.lineupSlots,
        existing.startDate,
        effectiveStartDate,
        nextDayRolloverHour,
        nextTimeZone
      );

      await prisma.$transaction(
        rebasedSlots.map((slot) =>
          prisma.eventLineupSlot.update({
            where: { id: slot.id },
            data: {
              festivalDayIndex: slot.festivalDayIndex,
              startTime: slot.startTime,
              endTime: slot.endTime,
            },
          })
        )
      );
    }

    const event = await prisma.event.findUnique({
      where: { id: id as string },
      include: {
        ticketTiers: {
          orderBy: { sortOrder: 'asc' },
        },
        lineupSlots: {
          orderBy: { startTime: 'asc' },
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true, bannerUrl: true },
            },
          },
        },
        lineupArtists: {
          orderBy: { sortOrder: 'asc' },
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true, bannerUrl: true },
            },
          },
        },
        organizer: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!event) {
      res.status(404).json({ error: 'Event not found after update' });
      return;
    }

    res.json(withDerivedStatus(event));
  } catch (error) {
    console.error('Update event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const deleteEvent = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const userId = req.user?.userId;
    const role = req.user?.role;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const existing = await prisma.event.findUnique({
      where: { id: id as string },
      select: { id: true, organizerId: true, coverImageUrl: true, lineupImageUrl: true, imageAssets: true },
    });
    if (!existing) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    if (role !== 'admin' && existing.organizerId !== userId) {
      res.status(403).json({ error: 'You can only delete your own event' });
      return;
    }

    await prisma.event.delete({
      where: { id: id as string },
    });
    await mediaAssetService.markDeletedByUrl(existing.coverImageUrl);
    await mediaAssetService.markDeletedByUrl(existing.lineupImageUrl);
    const imageAssets = Array.isArray(existing.imageAssets) ? existing.imageAssets : [];
    for (const asset of imageAssets) {
      if (asset && typeof asset === 'object' && 'url' in asset) {
        await mediaAssetService.markDeletedByUrl((asset as { url?: unknown }).url as string | null | undefined);
      }
    }

    res.status(204).send();
  } catch (error) {
    console.error('Delete event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const uploadEventImage = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    if (!file.buffer) {
      res.status(400).json({ error: 'Invalid upload payload' });
      return;
    }

    if (!isObjectStorageConfigured() && !shouldAllowLocalUploadFallback()) {
      res.status(503).json({ error: 'Object storage is not configured for uploads' });
      return;
    }

    const uploaded = isObjectStorageConfigured()
      ? await uploadBufferToObjectStorage({
          buffer: file.buffer,
          mimeType: file.mimetype || 'image/jpeg',
          objectKey: buildMediaObjectKey(
            process.env.OSS_EVENTS_PREFIX || 'wen-jasonlee/events',
            (req.body?.eventId as string | undefined) || 'legacy-api',
            (req.body?.usage as string | undefined) || 'image',
            file.originalname || 'image.jpg',
            file.mimetype || 'image/jpeg'
          ),
        })
      : await saveBufferToLocalUploads({
          buffer: file.buffer,
          localDir: path.join(process.cwd(), 'uploads', 'events'),
          publicSubdir: 'events',
          originalName: file.originalname || 'image.jpg',
          mimeType: file.mimetype || 'image/jpeg',
        });
    const asset = await mediaAssetService.register({
      ownerType: 'event',
      ownerId: typeof req.body?.eventId === 'string' ? req.body.eventId : null,
      purpose: typeof req.body?.usage === 'string' && req.body.usage.trim() ? req.body.usage.trim() : 'image',
      provider: 'objectKey' in uploaded ? 'oss' : 'local',
      objectKey: 'objectKey' in uploaded ? uploaded.objectKey : null,
      url: uploaded.url,
      mimeType: file.mimetype || 'image/jpeg',
      sizeBytes: file.size,
      uploadedById: req.user?.userId || null,
      metadata: {
        originalName: file.originalname,
        source: 'api/events/upload-image',
      },
    });

    res.status(201).json({
      assetId: asset.id,
      url: uploaded.url,
      filename: 'fileName' in uploaded ? uploaded.fileName : uploaded.objectKey.split('/').pop(),
      originalName: file.originalname,
      size: file.size,
      mimeType: file.mimetype,
    });
  } catch (error) {
    console.error('Upload event image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
