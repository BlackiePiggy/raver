import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';

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

const parseOptionalDate = (value: unknown): Date | null => {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value;
  }
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }
  const parsed = new Date(trimmed);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

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
const normalizeDayRolloverHour = (value: unknown, fallback = 6): number => {
  const numeric = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(numeric)) return fallback;
  const hour = Math.floor(numeric);
  if (hour < 0 || hour > 23) return fallback;
  return hour;
};

const startOfDay = (date: Date): Date => {
  const out = new Date(date);
  out.setHours(0, 0, 0, 0);
  return out;
};

const diffDays = (from: Date, to: Date): number => {
  const millis = startOfDay(to).getTime() - startOfDay(from).getTime();
  return Math.floor(millis / 86_400_000);
};

const inferFestivalDayIndex = (
  startTime: Date,
  eventStartDate: Date,
  dayRolloverHour: number
): number | null => {
  if (Number.isNaN(startTime.getTime()) || Number.isNaN(eventStartDate.getTime())) {
    return null;
  }
  let dayOffset = diffDays(eventStartDate, startTime);
  if (dayOffset > 0 && startTime.getHours() < dayRolloverHour) {
    dayOffset -= 1;
  }
  return Math.max(1, dayOffset + 1);
};

const normalizeLineupSlots = (
  slots: unknown,
  eventStartDate: Date,
  dayRolloverHourRaw: unknown = 6
): LineupSlotInput[] => {
  if (!Array.isArray(slots)) {
    return [];
  }

  const dayRolloverHour = normalizeDayRolloverHour(dayRolloverHourRaw, 6);
  const safeEventStart = Number.isNaN(eventStartDate.getTime()) ? new Date() : eventStartDate;
  return slots
    .filter((slot) => slot && typeof slot === 'object')
    .map((slot) => slot as RawLineupSlotInput)
    .map((slot, index) => {
      const parsedStart = parseOptionalDate(slot.startTime);
      const parsedEnd = parseOptionalDate(slot.endTime);
      const fallbackBase = new Date(safeEventStart.getTime() + index * 60_000);

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
      const explicitFestivalDayIndex =
        typeof slot.festivalDayIndex === 'number' && Number.isFinite(slot.festivalDayIndex)
          ? Math.max(1, Math.floor(slot.festivalDayIndex))
          : null;
      const festivalDayIndex =
        explicitFestivalDayIndex
        ?? inferFestivalDayIndex(startTime, safeEventStart, dayRolloverHour);

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

    const desiredSlug = slug || slugify(name);
    const existingEvent = await prisma.event.findUnique({
      where: { slug: desiredSlug },
    });

    if (existingEvent) {
      res.status(409).json({ error: 'Event with this slug already exists' });
      return;
    }

    const normalizedTicketTiers = normalizeTicketTiers(ticketTiers);
    const parsedStartDate = new Date(startDate);
    const parsedEndDate = new Date(endDate);
    if (Number.isNaN(parsedStartDate.getTime()) || Number.isNaN(parsedEndDate.getTime())) {
      res.status(400).json({ error: 'Invalid event date range' });
      return;
    }
    const normalizedDayRolloverHour = normalizeDayRolloverHour(dayRolloverHour, 6);
    const normalizedSlots = normalizeLineupSlots(lineupSlots, parsedStartDate, normalizedDayRolloverHour);

    const event = await prisma.event.create({
      data: {
        organizerId: userId,
        name,
        slug: desiredSlug,
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
        latitude: toNumberOrNull(latitude),
        longitude: toNumberOrNull(longitude),
        startDate: parsedStartDate,
        endDate: parsedEndDate,
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
      select: { id: true, organizerId: true, startDate: true, endDate: true, dayRolloverHour: true, status: true },
    });
    if (!existing) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    if (role !== 'admin' && existing.organizerId !== userId) {
      res.status(403).json({ error: 'You can only edit your own event' });
      return;
    }

    const nextStartDate = startDate ? new Date(startDate) : null;
    if (nextStartDate && Number.isNaN(nextStartDate.getTime())) {
      res.status(400).json({ error: 'Invalid startDate' });
      return;
    }
    const nextEndDate = endDate ? new Date(endDate) : null;
    if (nextEndDate && Number.isNaN(nextEndDate.getTime())) {
      res.status(400).json({ error: 'Invalid endDate' });
      return;
    }
    const effectiveStartDate = nextStartDate ?? existing.startDate;
    const effectiveEndDate = nextEndDate ?? existing.endDate;
    const nextDayRolloverHour = dayRolloverHour !== undefined
      ? normalizeDayRolloverHour(dayRolloverHour, existing.dayRolloverHour ?? 6)
      : (existing.dayRolloverHour ?? 6);
    const normalizedSlots = normalizeLineupSlots(lineupSlots, nextStartDate ?? existing.startDate, nextDayRolloverHour);
    const normalizedTicketTiers = normalizeTicketTiers(ticketTiers);

    const event = await prisma.event.update({
      where: { id: id as string },
      data: {
        name: name ?? undefined,
        slug: slug ?? undefined,
        description: description ?? undefined,
        coverImageUrl: coverImageUrl ?? undefined,
        lineupImageUrl: lineupImageUrl ?? undefined,
        eventType: eventType ?? undefined,
        organizerName: organizerName ?? undefined,
        city: city ?? undefined,
        cityI18n: cityI18n ?? undefined,
        country: country ?? undefined,
        countryI18n: countryI18n ?? undefined,
        manualLocation: manualLocation ?? undefined,
        locationPoint: locationPoint ?? undefined,
        latitude: latitude !== undefined ? toNumberOrNull(latitude) : undefined,
        longitude: longitude !== undefined ? toNumberOrNull(longitude) : undefined,
        startDate: startDate ? nextStartDate ?? undefined : undefined,
        endDate: endDate ? nextEndDate ?? undefined : undefined,
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
      select: { id: true, organizerId: true },
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

    const publicUrl = `/uploads/events/${file.filename}`;

    res.status(201).json({
      url: publicUrl,
      filename: file.filename,
      originalName: file.originalname,
      size: file.size,
      mimeType: file.mimetype,
    });
  } catch (error) {
    console.error('Upload event image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
