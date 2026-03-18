import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';

const prisma = new PrismaClient();

type LineupSlotInput = {
  djId?: string;
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

const normalizeLineupSlots = (slots: unknown): LineupSlotInput[] => {
  if (!Array.isArray(slots)) {
    return [];
  }
  return slots
    .filter((slot) => slot && typeof slot === 'object')
    .map((slot) => slot as LineupSlotInput)
    .filter((slot) => slot.startTime && slot.endTime);
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

    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    const where: any = { status };

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
      events,
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

    res.json({ events });
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

    res.json(event);
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
      venueName,
      venueAddress,
      city,
      country,
      latitude,
      longitude,
      startDate,
      endDate,
      ticketUrl,
      ticketPriceMin,
      ticketPriceMax,
      ticketCurrency,
      ticketNotes,
      ticketTiers,
      officialWebsite,
      lineupSlots,
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

    const normalizedSlots = normalizeLineupSlots(lineupSlots);
    const normalizedTicketTiers = normalizeTicketTiers(ticketTiers);
    const parsedStartDate = new Date(startDate);
    const parsedEndDate = new Date(endDate);
    if (Number.isNaN(parsedStartDate.getTime()) || Number.isNaN(parsedEndDate.getTime())) {
      res.status(400).json({ error: 'Invalid event date range' });
      return;
    }

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
        venueName,
        venueAddress,
        city,
        country,
        latitude: toNumberOrNull(latitude),
        longitude: toNumberOrNull(longitude),
        startDate: parsedStartDate,
        endDate: parsedEndDate,
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

    res.status(201).json(event);
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
      venueName,
      venueAddress,
      city,
      country,
      latitude,
      longitude,
      startDate,
      endDate,
      ticketUrl,
      ticketPriceMin,
      ticketPriceMax,
      ticketCurrency,
      ticketNotes,
      ticketTiers,
      officialWebsite,
      status,
      lineupSlots,
    } = req.body;

    const existing = await prisma.event.findUnique({
      where: { id: id as string },
      select: { id: true, organizerId: true },
    });
    if (!existing) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    if (role !== 'admin' && existing.organizerId !== userId) {
      res.status(403).json({ error: 'You can only edit your own event' });
      return;
    }

    const normalizedSlots = normalizeLineupSlots(lineupSlots);
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
        venueName: venueName ?? undefined,
        venueAddress: venueAddress ?? undefined,
        city: city ?? undefined,
        country: country ?? undefined,
        latitude: latitude !== undefined ? toNumberOrNull(latitude) : undefined,
        longitude: longitude !== undefined ? toNumberOrNull(longitude) : undefined,
        startDate: startDate ? new Date(startDate) : undefined,
        endDate: endDate ? new Date(endDate) : undefined,
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
        status: status ?? undefined,
        lineupSlots: Array.isArray(lineupSlots)
          ? {
              deleteMany: {},
              create: normalizedSlots.map((slot, index) => ({
                djId: slot.djId || null,
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

    res.json(event);
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
