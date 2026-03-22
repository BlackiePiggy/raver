import { Router, Request, Response, NextFunction } from 'express';
import { PrismaClient, Prisma } from '@prisma/client';
import multer from 'multer';
import fs from 'fs';
import path from 'path';
import djSetService from '../services/djset.service';
import commentService from '../services/comment.service';
import { verifyToken, type JWTPayload } from '../utils/auth';

const router: Router = Router();
const prisma = new PrismaClient();

interface BFFAuthRequest extends Request {
  user?: JWTPayload;
}

const optionalAuth = (req: Request, _res: Response, next: NextFunction): void => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    next();
    return;
  }

  const token = authHeader.substring(7);
  try {
    const decoded = verifyToken(token);
    (req as BFFAuthRequest).user = decoded;
  } catch (_error) {
    // Ignore invalid token for public endpoints.
  }

  next();
};

const requireAuth = (req: BFFAuthRequest, res: Response): string | null => {
  const userId = req.user?.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
  return userId;
};

type BFFPagination = {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

const ok = <T>(res: Response, data: T, pagination?: BFFPagination): void => {
  if (pagination) {
    res.json({ data, pagination });
    return;
  }
  res.json({ data });
};

const normalizePage = (value: unknown, fallback = 1): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.floor(parsed));
};

const normalizeLimit = (value: unknown, fallback = 20, max = 50): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.min(max, Math.floor(parsed)));
};

const parseSortOrder = (value: unknown, fallback: Prisma.SortOrder): Prisma.SortOrder => {
  if (value === 'asc' || value === 'desc') {
    return value;
  }
  return fallback;
};

const slugify = (value: string): string =>
  value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '') || 'item';

const toNumber = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

type NormalizedLineupSlot = {
  djId: string | null;
  djName: string;
  stageName: string | null;
  sortOrder: number;
  startTime: Date;
  endTime: Date;
};

const parseDateInput = (value: unknown): Date | null => {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    const fromTimestamp = new Date(value);
    return Number.isNaN(fromTimestamp.getTime()) ? null : fromTimestamp;
  }
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  const parsed = new Date(trimmed);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const resolveEventStatus = (startDate: Date, endDate: Date, fallbackStatus?: string | null): 'upcoming' | 'ongoing' | 'ended' => {
  const now = Date.now();
  const start = startDate.getTime();
  const end = endDate.getTime();

  if (Number.isFinite(start) && Number.isFinite(end) && end >= start) {
    if (now < start) return 'upcoming';
    if (now > end) return 'ended';
    return 'ongoing';
  }

  if (fallbackStatus === 'ongoing' || fallbackStatus === 'ended') {
    return fallbackStatus;
  }
  return 'upcoming';
};

const normalizeLineupSlots = (slots: unknown, eventStartDate: Date): NormalizedLineupSlot[] => {
  if (!Array.isArray(slots)) {
    return [];
  }

  const safeEventStart = Number.isNaN(eventStartDate.getTime()) ? new Date() : eventStartDate;
  return slots
    .filter((slot): slot is Record<string, unknown> => typeof slot === 'object' && slot !== null)
    .map((slot, index) => {
      const parsedStart = parseDateInput(slot.startTime);
      const parsedEnd = parseDateInput(slot.endTime);
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

      const djName = typeof slot.djName === 'string' ? slot.djName.trim() : '';
      const djId = typeof slot.djId === 'string' && slot.djId.trim() ? slot.djId.trim() : null;
      const hasIdentity = djName.length > 0 || !!djId;
      if (!hasIdentity) {
        return null;
      }

      return {
        djId,
        djName: djName || 'Unknown DJ',
        stageName: typeof slot.stageName === 'string' && slot.stageName.trim() ? slot.stageName.trim() : null,
        sortOrder: typeof slot.sortOrder === 'number' && Number.isFinite(slot.sortOrder) ? slot.sortOrder : index + 1,
        startTime,
        endTime,
      };
    })
    .filter((slot): slot is NormalizedLineupSlot => slot !== null);
};

const normalizeName = (value: string): string => value.toLowerCase().replace(/[^a-z0-9\u4e00-\u9fa5]/g, '');

const parseRankingText = (text: string): Array<{ rank: number; name: string }> =>
  text
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const match = line.match(/^(\d+)\.\s+(.+)$/);
      if (!match) return null;
      return { rank: Number(match[1]), name: String(match[2]).trim() };
    })
    .filter((item): item is { rank: number; name: string } => item !== null)
    .sort((a, b) => a.rank - b.rank);

const eventUploadDir = path.join(process.cwd(), 'uploads', 'events');
const djSetUploadDir = path.join(process.cwd(), 'uploads', 'dj-sets');
for (const dir of [eventUploadDir, djSetUploadDir]) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

const createImageUpload = (destinationDir: string, maxSize: number) =>
  multer({
    storage: multer.diskStorage({
      destination: (_req, _file, cb) => cb(null, destinationDir),
      filename: (_req, file, cb) => {
        const ext = path.extname(file.originalname || '').toLowerCase();
        const safeExt = ext && ext.length <= 8 ? ext : '.jpg';
        cb(null, `${Date.now()}-${Math.random().toString(36).slice(2, 10)}${safeExt}`);
      },
    }),
    limits: { fileSize: maxSize },
    fileFilter: (_req, file, cb) => {
      if (!file.mimetype.startsWith('image/')) {
        cb(new Error('Only image files are allowed'));
        return;
      }
      cb(null, true);
    },
  });

const createVideoUpload = (destinationDir: string, maxSize: number) =>
  multer({
    storage: multer.diskStorage({
      destination: (_req, _file, cb) => cb(null, destinationDir),
      filename: (_req, file, cb) => {
        const ext = path.extname(file.originalname || '').toLowerCase();
        const safeExt = ext && ext.length <= 8 ? ext : '.mp4';
        cb(null, `${Date.now()}-${Math.random().toString(36).slice(2, 10)}${safeExt}`);
      },
    }),
    limits: { fileSize: maxSize },
    fileFilter: (_req, file, cb) => {
      if (!file.mimetype.startsWith('video/')) {
        cb(new Error('Only video files are allowed'));
        return;
      }
      cb(null, true);
    },
  });

const eventImageUpload = createImageUpload(eventUploadDir, 10 * 1024 * 1024);
const djSetThumbUpload = createImageUpload(djSetUploadDir, 10 * 1024 * 1024);
const djSetVideoUpload = createVideoUpload(djSetUploadDir, 300 * 1024 * 1024);

const mapDJ = (row: any, isFollowing = false) => ({
  id: row.id,
  name: row.name,
  aliases: Array.isArray(row.aliases) ? row.aliases : [],
  slug: row.slug,
  bio: row.bio,
  avatarUrl: row.avatarUrl,
  bannerUrl: row.bannerUrl,
  country: row.country,
  spotifyId: row.spotifyId,
  appleMusicId: row.appleMusicId,
  soundcloudUrl: row.soundcloudUrl,
  instagramUrl: row.instagramUrl,
  twitterUrl: row.twitterUrl,
  isVerified: row.isVerified,
  followerCount: row.followerCount,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  isFollowing,
});

const mapUserLite = (row: any) => {
  if (!row) return null;
  return {
    id: row.id,
    username: row.username,
    displayName: row.displayName || row.username,
    avatarUrl: row.avatarUrl || null,
  };
};

const mapEvent = (row: any) => ({
  id: row.id,
  name: row.name,
  slug: row.slug,
  description: row.description,
  coverImageUrl: row.coverImageUrl,
  lineupImageUrl: row.lineupImageUrl,
  eventType: row.eventType,
  organizerName: row.organizerName,
  venueName: row.venueName,
  venueAddress: row.venueAddress,
  city: row.city,
  country: row.country,
  latitude: toNumber(row.latitude),
  longitude: toNumber(row.longitude),
  startDate: row.startDate,
  endDate: row.endDate,
  ticketUrl: row.ticketUrl,
  ticketPriceMin: toNumber(row.ticketPriceMin),
  ticketPriceMax: toNumber(row.ticketPriceMax),
  ticketCurrency: row.ticketCurrency,
  ticketNotes: row.ticketNotes,
  officialWebsite: row.officialWebsite,
  status: resolveEventStatus(new Date(row.startDate), new Date(row.endDate), row.status),
  isVerified: row.isVerified,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  organizer: mapUserLite(row.organizer),
  ticketTiers: Array.isArray(row.ticketTiers)
    ? row.ticketTiers.map((tier: any) => ({
        id: tier.id,
        name: tier.name,
        price: toNumber(tier.price),
        currency: tier.currency,
        sortOrder: tier.sortOrder,
      }))
    : [],
  lineupSlots: Array.isArray(row.lineupSlots)
    ? row.lineupSlots.map((slot: any) => ({
        id: slot.id,
        eventId: slot.eventId,
        djId: slot.djId,
        djName: slot.djName,
        stageName: slot.stageName,
        sortOrder: slot.sortOrder,
        startTime: slot.startTime,
        endTime: slot.endTime,
        dj: slot.dj
          ? {
              id: slot.dj.id,
              name: slot.dj.name,
              avatarUrl: slot.dj.avatarUrl,
              bannerUrl: slot.dj.bannerUrl,
              country: slot.dj.country,
            }
          : null,
      }))
    : [],
});

const mapTrack = (track: any) => ({
  id: track.id,
  position: track.position,
  startTime: track.startTime,
  endTime: track.endTime,
  title: track.title,
  artist: track.artist,
  status: track.status,
  spotifyUrl: track.spotifyUrl,
  spotifyId: track.spotifyId,
  spotifyUri: track.spotifyUri,
  neteaseUrl: track.neteaseUrl,
  neteaseId: track.neteaseId,
  createdAt: track.createdAt,
  updatedAt: track.updatedAt,
});

const mapTracklistSummary = (row: any) => ({
  id: row.id,
  setId: row.setId,
  title: row.title,
  isDefault: row.isDefault,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  contributor: row.contributor || null,
  trackCount: row.trackCount || 0,
});

const mapTracklistDetail = (row: any) => ({
  id: row.id,
  setId: row.setId,
  title: row.title,
  isDefault: row.isDefault,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  contributor: row.contributor || null,
  tracks: Array.isArray(row.tracks) ? row.tracks.map(mapTrack) : [],
});

const mapDJSet = (row: any) => ({
  id: row.id,
  djId: row.djId,
  title: row.title,
  slug: row.slug,
  description: row.description,
  thumbnailUrl: row.thumbnailUrl,
  videoUrl: row.videoUrl,
  platform: row.platform,
  videoId: row.videoId,
  duration: row.duration,
  recordedAt: row.recordedAt,
  venue: row.venue,
  eventName: row.eventName,
  viewCount: row.viewCount,
  likeCount: row.likeCount,
  isVerified: row.isVerified,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  uploadedById: row.uploadedById,
  coDjIds: row.coDjIds || [],
  customDjNames: row.customDjNames || [],
  dj: row.dj
    ? {
        id: row.dj.id,
        name: row.dj.name,
        slug: row.dj.slug,
        avatarUrl: row.dj.avatarUrl,
        bannerUrl: row.dj.bannerUrl,
        country: row.dj.country,
      }
    : null,
  lineupDjs: Array.isArray(row.lineupDjs)
    ? row.lineupDjs.map((dj: any) => ({ id: dj.id, name: dj.name, avatarUrl: dj.avatarUrl }))
    : [],
  tracks: Array.isArray(row.tracks) ? row.tracks.map(mapTrack) : [],
  trackCount: Array.isArray(row.tracks) ? row.tracks.length : 0,
  uploader: mapUserLite(row.uploader),
  videoContributor: row.videoContributor || null,
  tracklistContributor: row.tracklistContributor || null,
});

const mapRatingComment = (row: any) => ({
  id: row.id,
  unitId: row.unitId,
  userId: row.userId,
  score: row.score,
  content: row.content,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  user: mapUserLite(row.user),
});

const resolveRatingSummary = (comments: Array<{ score: number }>): { rating: number; ratingCount: number } => {
  const scores = comments.map((item) => item.score).filter((value) => typeof value === 'number' && Number.isFinite(value));
  if (!scores.length) {
    return { rating: 0, ratingCount: 0 };
  }
  const total = scores.reduce((sum, value) => sum + value, 0);
  return {
    rating: total / scores.length,
    ratingCount: scores.length,
  };
};

const mapRatingUnit = (row: any, includeComments = false) => {
  const scoreRows: Array<{ score: number }> = Array.isArray(row.comments)
    ? row.comments
        .filter((item: any) => typeof item === 'object' && item !== null && typeof item.score === 'number')
        .map((item: any) => ({ score: item.score }))
    : [];
  const summary = resolveRatingSummary(scoreRows);

  return {
    id: row.id,
    eventId: row.eventId,
    name: row.name,
    description: row.description,
    imageUrl: row.imageUrl,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    rating: summary.rating,
    ratingCount: summary.ratingCount,
    comments: includeComments && Array.isArray(row.comments) ? row.comments.map(mapRatingComment) : [],
    createdBy: mapUserLite(row.createdBy),
  };
};

const mapRatingEvent = (row: any) => ({
  id: row.id,
  name: row.name,
  description: row.description,
  imageUrl: row.imageUrl,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  createdBy: mapUserLite(row.createdBy),
  units: Array.isArray(row.units) ? row.units.map((unit: any) => mapRatingUnit(unit)) : [],
});

const RANKING_BOARDS: Record<string, { title: string; subtitle: string; years: number[]; coverImageUrl?: string }> = {
  djmag: {
    title: 'DJ MAG TOP 100',
    subtitle: '全球电子音乐最有影响力榜单之一',
    years: [2022, 2023, 2024, 2025],
  },
  dongye: {
    title: '东野 DJ 榜',
    subtitle: '中文圈 DJ 热度与影响力榜单',
    years: [2024, 2025],
  },
};

const rankingFilePath = (boardId: string, year: number): string | null => {
  const candidates = [
    path.join(process.cwd(), '..', 'web', 'public', 'rankings', boardId, `${year}.txt`),
    path.join(process.cwd(), 'web', 'public', 'rankings', boardId, `${year}.txt`),
  ];

  for (const filePath of candidates) {
    if (fs.existsSync(filePath)) {
      return filePath;
    }
  }

  return null;
};

router.get('/events', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const skip = (page - 1) * limit;

    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const city = typeof req.query.city === 'string' ? req.query.city.trim() : '';
    const country = typeof req.query.country === 'string' ? req.query.country.trim() : '';
    const eventType = typeof req.query.eventType === 'string' ? req.query.eventType.trim() : '';
    const status = typeof req.query.status === 'string' ? req.query.status.trim() : 'upcoming';

    const where: any = {};
    const now = new Date();
    if (status === 'upcoming') {
      where.startDate = { gt: now };
    } else if (status === 'ongoing') {
      where.startDate = { lte: now };
      where.endDate = { gte: now };
    } else if (status === 'ended') {
      where.endDate = { lt: now };
    } else if (status === 'all' || status === '') {
      // no status filter
    } else if (status) {
      where.status = status;
    }
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
      ];
    }
    if (city) where.city = city;
    if (country) where.country = country;
    if (eventType) where.eventType = eventType;

    const [rows, total] = await Promise.all([
      prisma.event.findMany({
        where,
        skip,
        take: limit,
        orderBy: { startDate: 'asc' },
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
            select: { id: true, username: true, displayName: true, avatarUrl: true },
          },
        },
      }),
      prisma.event.count({ where }),
    ]);

    ok(
      res,
      { items: rows.map(mapEvent) },
      {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      }
    );
  } catch (error) {
    console.error('BFF web events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/my', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const rows = await prisma.event.findMany({
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
              select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true },
            },
          },
        },
        organizer: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    ok(res, { items: rows.map(mapEvent) });
  } catch (error) {
    console.error('BFF web my events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const eventId = req.params.id as string;
    const row = await prisma.event.findUnique({
      where: { id: eventId },
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
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    if (!row) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    ok(res, mapEvent(row));
  } catch (error) {
    console.error('BFF web event detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const body = req.body as Record<string, unknown>;
    const name = String(body.name || '').trim();
    const startDate = String(body.startDate || '').trim();
    const endDate = String(body.endDate || '').trim();

    if (!name || !startDate || !endDate) {
      res.status(400).json({ error: 'name, startDate and endDate are required' });
      return;
    }

    const parsedStartDate = new Date(startDate);
    const parsedEndDate = new Date(endDate);
    if (Number.isNaN(parsedStartDate.getTime()) || Number.isNaN(parsedEndDate.getTime())) {
      res.status(400).json({ error: 'Invalid event date range' });
      return;
    }

    const desiredSlug = String(body.slug || '').trim() || `${slugify(name)}-${Date.now().toString().slice(-6)}`;
    const slugUsed = await prisma.event.findUnique({ where: { slug: desiredSlug }, select: { id: true } });
    if (slugUsed) {
      res.status(409).json({ error: 'slug already exists' });
      return;
    }

    const rawSlots = Array.isArray(body.lineupSlots) ? body.lineupSlots : [];
    const lineupSlots = normalizeLineupSlots(rawSlots, parsedStartDate);

    const rawTicketTiers = Array.isArray(body.ticketTiers) ? body.ticketTiers : [];
    const ticketCurrency = typeof body.ticketCurrency === 'string' ? body.ticketCurrency : null;
    const ticketTiers = rawTicketTiers
      .filter((tier): tier is Record<string, unknown> => typeof tier === 'object' && tier !== null)
      .map((tier, index) => ({
        name: String(tier.name || '').trim(),
        price: toNumber(tier.price),
        currency: typeof tier.currency === 'string' && tier.currency.trim() ? tier.currency.trim() : ticketCurrency,
        sortOrder: typeof tier.sortOrder === 'number' ? tier.sortOrder : index + 1,
      }))
      .filter((tier) => tier.name && tier.price !== null)
      .map((tier) => ({
        name: tier.name,
        price: Number(tier.price),
        currency: tier.currency || null,
        sortOrder: tier.sortOrder,
      }));

    const created = await prisma.event.create({
      data: {
        organizerId: userId,
        name,
        slug: desiredSlug,
        description: typeof body.description === 'string' ? body.description : null,
        coverImageUrl: typeof body.coverImageUrl === 'string' ? body.coverImageUrl : null,
        lineupImageUrl: typeof body.lineupImageUrl === 'string' ? body.lineupImageUrl : null,
        eventType: typeof body.eventType === 'string' ? body.eventType : null,
        organizerName: typeof body.organizerName === 'string' ? body.organizerName : null,
        venueName: typeof body.venueName === 'string' ? body.venueName : null,
        venueAddress: typeof body.venueAddress === 'string' ? body.venueAddress : null,
        city: typeof body.city === 'string' ? body.city : null,
        country: typeof body.country === 'string' ? body.country : null,
        latitude: toNumber(body.latitude),
        longitude: toNumber(body.longitude),
        startDate: parsedStartDate,
        endDate: parsedEndDate,
        status: resolveEventStatus(parsedStartDate, parsedEndDate, typeof body.status === 'string' ? body.status : null),
        ticketUrl: typeof body.ticketUrl === 'string' ? body.ticketUrl : null,
        ticketPriceMin: toNumber(body.ticketPriceMin),
        ticketPriceMax: toNumber(body.ticketPriceMax),
        ticketCurrency,
        ticketNotes: typeof body.ticketNotes === 'string' ? body.ticketNotes : null,
        officialWebsite: typeof body.officialWebsite === 'string' ? body.officialWebsite : null,
        lineupSlots: lineupSlots.length ? { create: lineupSlots } : undefined,
        ticketTiers: ticketTiers.length ? { create: ticketTiers } : undefined,
      },
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
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    ok(res, mapEvent(created));
  } catch (error) {
    console.error('BFF web create event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/events/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const eventId = req.params.id as string;
    const existing = await prisma.event.findUnique({
      where: { id: eventId },
      select: { id: true, organizerId: true, startDate: true, endDate: true, status: true },
    });

    if (!existing) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    if (authReq.user?.role !== 'admin' && existing.organizerId !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const rawSlots = Array.isArray(body.lineupSlots) ? body.lineupSlots : null;
    const rawTicketTiers = Array.isArray(body.ticketTiers) ? body.ticketTiers : null;

    const parsedStartDate = body.startDate !== undefined ? parseDateInput(body.startDate) : null;
    const parsedEndDate = body.endDate !== undefined ? parseDateInput(body.endDate) : null;
    if (body.startDate !== undefined && parsedStartDate === null) {
      res.status(400).json({ error: 'Invalid startDate' });
      return;
    }
    if (body.endDate !== undefined && parsedEndDate === null) {
      res.status(400).json({ error: 'Invalid endDate' });
      return;
    }

    const lineupBaseDate = parsedStartDate ?? existing.startDate;
    const effectiveStartDate = parsedStartDate ?? existing.startDate;
    const effectiveEndDate = parsedEndDate ?? existing.endDate;
    const lineupSlots = normalizeLineupSlots(rawSlots || [], lineupBaseDate);

    const ticketCurrency = typeof body.ticketCurrency === 'string' ? body.ticketCurrency : null;
    const ticketTiers = (rawTicketTiers || [])
      .filter((tier): tier is Record<string, unknown> => typeof tier === 'object' && tier !== null)
      .map((tier, index) => ({
        name: String(tier.name || '').trim(),
        price: toNumber(tier.price),
        currency: typeof tier.currency === 'string' && tier.currency.trim() ? tier.currency.trim() : ticketCurrency,
        sortOrder: typeof tier.sortOrder === 'number' ? tier.sortOrder : index + 1,
      }))
      .filter((tier) => tier.name && tier.price !== null)
      .map((tier) => ({
        name: tier.name,
        price: Number(tier.price),
        currency: tier.currency || null,
        sortOrder: tier.sortOrder,
      }));

    const updated = await prisma.event.update({
      where: { id: eventId },
      data: {
        name: typeof body.name === 'string' ? body.name : undefined,
        slug: typeof body.slug === 'string' ? body.slug : undefined,
        description: typeof body.description === 'string' ? body.description : undefined,
        coverImageUrl: typeof body.coverImageUrl === 'string' ? body.coverImageUrl : undefined,
        lineupImageUrl: typeof body.lineupImageUrl === 'string' ? body.lineupImageUrl : undefined,
        eventType: typeof body.eventType === 'string' ? body.eventType : undefined,
        organizerName: typeof body.organizerName === 'string' ? body.organizerName : undefined,
        venueName: typeof body.venueName === 'string' ? body.venueName : undefined,
        venueAddress: typeof body.venueAddress === 'string' ? body.venueAddress : undefined,
        city: typeof body.city === 'string' ? body.city : undefined,
        country: typeof body.country === 'string' ? body.country : undefined,
        latitude: body.latitude !== undefined ? toNumber(body.latitude) : undefined,
        longitude: body.longitude !== undefined ? toNumber(body.longitude) : undefined,
        startDate: body.startDate !== undefined ? parsedStartDate ?? undefined : undefined,
        endDate: body.endDate !== undefined ? parsedEndDate ?? undefined : undefined,
        ticketUrl: typeof body.ticketUrl === 'string' ? body.ticketUrl : undefined,
        ticketPriceMin: body.ticketPriceMin !== undefined ? toNumber(body.ticketPriceMin) : undefined,
        ticketPriceMax: body.ticketPriceMax !== undefined ? toNumber(body.ticketPriceMax) : undefined,
        ticketCurrency: body.ticketCurrency !== undefined ? ticketCurrency : undefined,
        ticketNotes: typeof body.ticketNotes === 'string' ? body.ticketNotes : undefined,
        officialWebsite: typeof body.officialWebsite === 'string' ? body.officialWebsite : undefined,
        status: resolveEventStatus(effectiveStartDate, effectiveEndDate, typeof body.status === 'string' ? body.status : existing.status),
        lineupSlots:
          rawSlots !== null
            ? {
                deleteMany: {},
                create: lineupSlots,
              }
            : undefined,
        ticketTiers:
          rawTicketTiers !== null
            ? {
                deleteMany: {},
                create: ticketTiers,
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
              select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true },
            },
          },
        },
        organizer: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    ok(res, mapEvent(updated));
  } catch (error) {
    console.error('BFF web update event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/events/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const eventId = req.params.id as string;
    const existing = await prisma.event.findUnique({
      where: { id: eventId },
      select: { id: true, organizerId: true },
    });

    if (!existing) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    if (authReq.user?.role !== 'admin' && existing.organizerId !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    await prisma.event.delete({ where: { id: eventId } });
    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events/upload-image', optionalAuth, eventImageUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;
    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    ok(res, {
      url: `/uploads/events/${file.filename}`,
      fileName: file.filename,
      mimeType: file.mimetype,
      size: file.size,
    });
  } catch (error) {
    console.error('BFF web upload event image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const viewerId = (req as BFFAuthRequest).user?.userId;
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const skip = (page - 1) * limit;

    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const country = typeof req.query.country === 'string' ? req.query.country.trim() : '';
    const sortBy = typeof req.query.sortBy === 'string' ? req.query.sortBy : 'followerCount';

    const where: any = {};
    if (search) {
      const normalizedSearchVariants = Array.from(
        new Set([search, search.toLowerCase(), search.toUpperCase()])
      );
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { aliases: { hasSome: normalizedSearchVariants } },
        { bio: { contains: search, mode: 'insensitive' } },
      ];
    }
    if (country) where.country = country;

    const orderBy: any =
      sortBy === 'name'
        ? { name: 'asc' }
        : sortBy === 'createdAt'
          ? { createdAt: 'desc' }
          : { followerCount: 'desc' };

    const [rows, total] = await Promise.all([
      prisma.dJ.findMany({
        where,
        skip,
        take: limit,
        orderBy,
      }),
      prisma.dJ.count({ where }),
    ]);

    const ids = rows.map((row) => row.id);
    const followRows = viewerId
      ? await prisma.follow.findMany({
          where: {
            followerId: viewerId,
            type: 'dj',
            djId: { in: ids },
          },
          select: { djId: true },
        })
      : [];
    const followSet = new Set(followRows.map((row) => row.djId).filter((id): id is string => Boolean(id)));

    ok(
      res,
      { items: rows.map((row) => mapDJ(row, followSet.has(row.id))) },
      {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      }
    );
  } catch (error) {
    console.error('BFF web djs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/:id/sets', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const djId = req.params.id as string;
    const sets = await djSetService.getDJSetsByDJ(djId);
    ok(res, { items: sets.map(mapDJSet) });
  } catch (error) {
    console.error('BFF web dj sets error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/:id/events', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const djId = req.params.id as string;
    const rows = await prisma.event.findMany({
      where: {
        lineupSlots: {
          some: {
            djId,
          },
        },
      },
      orderBy: [{ startDate: 'desc' }, { name: 'asc' }],
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
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    ok(res, { items: rows.map(mapEvent) });
  } catch (error) {
    console.error('BFF web dj events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const viewerId = (req as BFFAuthRequest).user?.userId;
    const djId = req.params.id as string;
    const row = await prisma.dJ.findUnique({ where: { id: djId } });
    if (!row) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    let isFollowing = false;
    if (viewerId) {
      const follow = await prisma.follow.findUnique({
        where: {
          followerId_djId: {
            followerId: viewerId,
            djId,
          },
        },
      });
      isFollowing = Boolean(follow);
    }

    ok(res, mapDJ(row, isFollowing));
  } catch (error) {
    console.error('BFF web dj detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/:id/follow-status', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const djId = req.params.id as string;
    const follow = await prisma.follow.findUnique({
      where: {
        followerId_djId: {
          followerId: userId,
          djId,
        },
      },
    });

    ok(res, { isFollowing: Boolean(follow) });
  } catch (error) {
    console.error('BFF web dj follow status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/djs/:id/follow', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const djId = req.params.id as string;
    const dj = await prisma.dJ.findUnique({ where: { id: djId } });
    if (!dj) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    const existing = await prisma.follow.findUnique({
      where: {
        followerId_djId: {
          followerId: userId,
          djId,
        },
      },
    });

    if (!existing) {
      await prisma.$transaction([
        prisma.follow.create({
          data: {
            followerId: userId,
            djId,
            type: 'dj',
          },
        }),
        prisma.dJ.update({
          where: { id: djId },
          data: {
            followerCount: {
              increment: 1,
            },
          },
        }),
      ]);
    }

    const updated = await prisma.dJ.findUnique({ where: { id: djId } });
    ok(res, mapDJ(updated || dj, true));
  } catch (error) {
    console.error('BFF web follow dj error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/djs/:id/follow', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const djId = req.params.id as string;
    const dj = await prisma.dJ.findUnique({ where: { id: djId } });
    if (!dj) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    const existing = await prisma.follow.findUnique({
      where: {
        followerId_djId: {
          followerId: userId,
          djId,
        },
      },
    });

    if (existing) {
      await prisma.$transaction([
        prisma.follow.delete({
          where: {
            followerId_djId: {
              followerId: userId,
              djId,
            },
          },
        }),
        prisma.dJ.update({
          where: { id: djId },
          data: {
            followerCount: {
              decrement: 1,
            },
          },
        }),
      ]);
    }

    const updated = await prisma.dJ.findUnique({ where: { id: djId } });
    ok(res, mapDJ(updated || dj, false));
  } catch (error) {
    console.error('BFF web unfollow dj error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/dj-sets', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const sortBy = typeof req.query.sortBy === 'string' ? req.query.sortBy : 'latest';
    const djIdFilter = typeof req.query.djId === 'string' ? req.query.djId.trim() : '';

    let sets = await djSetService.getAllDJSets();
    if (djIdFilter) {
      sets = sets.filter((set) => set.djId === djIdFilter);
    }

    if (sortBy === 'popular') {
      sets.sort((a, b) => (b.viewCount || 0) - (a.viewCount || 0));
    } else if (sortBy === 'tracks') {
      sets.sort((a, b) => (b.tracks?.length || 0) - (a.tracks?.length || 0));
    } else {
      sets.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    }

    const total = sets.length;
    const start = (page - 1) * limit;
    const paged = sets.slice(start, start + limit);

    ok(
      res,
      { items: paged.map(mapDJSet) },
      {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      }
    );
  } catch (error) {
    console.error('BFF web dj sets list error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/dj-sets/mine', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;
    const sets = await djSetService.getDJSetsByUploader(userId);
    ok(res, { items: sets.map(mapDJSet) });
  } catch (error) {
    console.error('BFF web my dj sets error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/dj-sets/preview', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const videoUrl = typeof req.query.videoUrl === 'string' ? req.query.videoUrl.trim() : '';
    if (!videoUrl) {
      res.status(400).json({ error: 'videoUrl is required' });
      return;
    }
    const data = await djSetService.getVideoPreview(videoUrl);
    ok(res, data);
  } catch (error) {
    res.status(500).json({ error: (error as Error).message || 'Internal server error' });
  }
});

router.get('/dj-sets/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const setId = req.params.id as string;
    const set = await djSetService.getDJSet(setId);
    if (!set) {
      res.status(404).json({ error: 'DJ set not found' });
      return;
    }
    ok(res, mapDJSet(set));
  } catch (error) {
    console.error('BFF web dj set detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/dj-sets/:id/tracklists', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const setId = req.params.id as string;
    const set = await djSetService.getDJSet(setId);
    if (!set) {
      res.status(404).json({ error: 'DJ set not found' });
      return;
    }

    const tracklists = await djSetService.getTracklists(setId);
    ok(res, { items: tracklists.map(mapTracklistSummary) });
  } catch (error) {
    console.error('BFF web dj set tracklists error:', error);
    res.status(500).json({ error: (error as Error).message || 'Internal server error' });
  }
});

router.get('/dj-sets/:setId/tracklists/:tracklistId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const setId = req.params.setId as string;
    const tracklistId = req.params.tracklistId as string;
    const tracklist = await djSetService.getTracklistById(tracklistId);

    if (!tracklist || tracklist.setId !== setId) {
      res.status(404).json({ error: 'Tracklist not found' });
      return;
    }

    ok(res, mapTracklistDetail(tracklist));
  } catch (error) {
    console.error('BFF web dj set tracklist detail error:', error);
    res.status(500).json({ error: (error as Error).message || 'Internal server error' });
  }
});

router.post('/dj-sets/:id/tracklists', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const setId = req.params.id as string;
    const body = req.body as Record<string, unknown>;
    const title = typeof body.title === 'string' ? body.title.trim() : '';
    const tracksInput = Array.isArray(body.tracks) ? body.tracks : [];

    const tracks = tracksInput
      .filter((item): item is Record<string, unknown> => typeof item === 'object' && item !== null)
      .map((track, index) => ({
        position: typeof track.position === 'number' ? track.position : index + 1,
        startTime: Number(track.startTime || 0),
        endTime: track.endTime === null || track.endTime === undefined || track.endTime === '' ? undefined : Number(track.endTime),
        title: String(track.title || '').trim(),
        artist: String(track.artist || '').trim(),
        status:
          typeof track.status === 'string' && ['released', 'id', 'remix', 'edit'].includes(track.status)
            ? (track.status as 'released' | 'id' | 'remix' | 'edit')
            : 'released',
        spotifyUrl: typeof track.spotifyUrl === 'string' ? track.spotifyUrl : undefined,
        spotifyId: typeof track.spotifyId === 'string' ? track.spotifyId : undefined,
        spotifyUri: typeof track.spotifyUri === 'string' ? track.spotifyUri : undefined,
        neteaseUrl: typeof track.neteaseUrl === 'string' ? track.neteaseUrl : undefined,
        neteaseId: typeof track.neteaseId === 'string' ? track.neteaseId : undefined,
      }))
      .filter((track) => track.title && track.artist);

    if (tracks.length === 0) {
      res.status(400).json({ error: 'tracks is required and must contain valid title/artist rows' });
      return;
    }

    const created = await djSetService.createTracklist(setId, userId, title || undefined, tracks);
    if (!created) {
      res.status(500).json({ error: 'Failed to create tracklist' });
      return;
    }

    res.status(201);
    ok(res, mapTracklistDetail(created));
  } catch (error) {
    const message = (error as Error).message || 'Internal server error';
    if (message === 'DJ set not found') {
      res.status(404).json({ error: message });
      return;
    }
    console.error('BFF web create tracklist error:', error);
    res.status(500).json({ error: message });
  }
});

router.post('/dj-sets', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = req.body as Record<string, unknown>;
    const djId = String(body.djId || '').trim();
    const title = String(body.title || '').trim();
    const videoUrl = String(body.videoUrl || '').trim();

    if (!djId || !title || !videoUrl) {
      res.status(400).json({ error: 'djId, title and videoUrl are required' });
      return;
    }

    const created = await djSetService.createDJSet({
      djId,
      djIds: Array.isArray(body.djIds)
        ? body.djIds.filter((item): item is string => typeof item === 'string')
        : undefined,
      customDjNames: Array.isArray(body.customDjNames)
        ? body.customDjNames.filter((item): item is string => typeof item === 'string')
        : undefined,
      uploadedById: userId,
      title,
      videoUrl,
      thumbnailUrl: typeof body.thumbnailUrl === 'string' ? body.thumbnailUrl : undefined,
      description: typeof body.description === 'string' ? body.description : undefined,
      recordedAt: typeof body.recordedAt === 'string' ? new Date(body.recordedAt) : undefined,
      venue: typeof body.venue === 'string' ? body.venue : undefined,
      eventName: typeof body.eventName === 'string' ? body.eventName : undefined,
    });

    ok(res, mapDJSet(created));
  } catch (error) {
    console.error('BFF web create dj set error:', error);
    res.status(500).json({ error: (error as Error).message || 'Internal server error' });
  }
});

router.patch('/dj-sets/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const setId = req.params.id as string;
    const body = req.body as Record<string, unknown>;

    const updated = await djSetService.updateDJSetByUploader(setId, userId, {
      djId: typeof body.djId === 'string' ? body.djId : undefined,
      djIds: Array.isArray(body.djIds)
        ? body.djIds.filter((item): item is string => typeof item === 'string')
        : undefined,
      customDjNames: Array.isArray(body.customDjNames)
        ? body.customDjNames.filter((item): item is string => typeof item === 'string')
        : undefined,
      title: typeof body.title === 'string' ? body.title : undefined,
      description: typeof body.description === 'string' ? body.description : undefined,
      videoUrl: typeof body.videoUrl === 'string' ? body.videoUrl : undefined,
      thumbnailUrl: typeof body.thumbnailUrl === 'string' ? body.thumbnailUrl : undefined,
      venue: typeof body.venue === 'string' ? body.venue : undefined,
      eventName: typeof body.eventName === 'string' ? body.eventName : undefined,
      recordedAt: typeof body.recordedAt === 'string' ? new Date(body.recordedAt) : undefined,
    });

    ok(res, mapDJSet(updated));
  } catch (error) {
    const message = (error as Error).message || 'Internal server error';
    if (message === 'Forbidden') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    if (message === 'DJ set not found') {
      res.status(404).json({ error: message });
      return;
    }
    res.status(500).json({ error: message });
  }
});

router.delete('/dj-sets/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const setId = req.params.id as string;
    await djSetService.deleteDJSetByUploader(setId, userId, authReq.user?.role);
    ok(res, { success: true });
  } catch (error) {
    const message = (error as Error).message || 'Internal server error';
    if (message === 'Forbidden') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    if (message === 'DJ set not found') {
      res.status(404).json({ error: message });
      return;
    }
    res.status(500).json({ error: message });
  }
});

router.put('/dj-sets/:id/tracks', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const setId = req.params.id as string;
    const body = req.body as { tracks?: unknown };
    const tracksInput = Array.isArray(body.tracks) ? body.tracks : [];

    const tracks = tracksInput
      .filter((item): item is Record<string, unknown> => typeof item === 'object' && item !== null)
      .map((track, index) => ({
        position: typeof track.position === 'number' ? track.position : index + 1,
        startTime: Number(track.startTime || 0),
        endTime: track.endTime === null || track.endTime === undefined || track.endTime === '' ? undefined : Number(track.endTime),
        title: String(track.title || '').trim(),
        artist: String(track.artist || '').trim(),
        status:
          typeof track.status === 'string' && ['released', 'id', 'remix', 'edit'].includes(track.status)
            ? (track.status as 'released' | 'id' | 'remix' | 'edit')
            : 'released',
        spotifyUrl: typeof track.spotifyUrl === 'string' ? track.spotifyUrl : undefined,
        spotifyId: typeof track.spotifyId === 'string' ? track.spotifyId : undefined,
        spotifyUri: typeof track.spotifyUri === 'string' ? track.spotifyUri : undefined,
        neteaseUrl: typeof track.neteaseUrl === 'string' ? track.neteaseUrl : undefined,
        neteaseId: typeof track.neteaseId === 'string' ? track.neteaseId : undefined,
      }))
      .filter((track) => track.title && track.artist);

    const updated = await djSetService.replaceTracksByUploader(setId, userId, tracks);
    ok(res, mapDJSet(updated));
  } catch (error) {
    const message = (error as Error).message || 'Internal server error';
    if (message === 'Forbidden') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    if (message === 'DJ set not found') {
      res.status(404).json({ error: message });
      return;
    }
    res.status(500).json({ error: message });
  }
});

router.post('/dj-sets/:id/auto-link', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const setId = req.params.id as string;
    const set = await prisma.dJSet.findUnique({ where: { id: setId }, select: { uploadedById: true } });
    if (!set) {
      res.status(404).json({ error: 'DJ set not found' });
      return;
    }
    if (authReq.user?.role !== 'admin' && set.uploadedById !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    await djSetService.autoLinkTracks(setId);
    ok(res, { success: true });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message || 'Internal server error' });
  }
});

router.post('/dj-sets/upload-thumbnail', optionalAuth, djSetThumbUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    ok(res, {
      url: `/uploads/dj-sets/${file.filename}`,
      fileName: file.filename,
      mimeType: file.mimetype,
      size: file.size,
    });
  } catch (error) {
    console.error('BFF web upload dj set thumbnail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/dj-sets/upload-video', optionalAuth, djSetVideoUpload.single('video'), async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    ok(res, {
      url: `/uploads/dj-sets/${file.filename}`,
      fileName: file.filename,
      mimeType: file.mimetype,
      size: file.size,
    });
  } catch (error) {
    console.error('BFF web upload dj set video error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/dj-sets/:id/comments', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const setId = req.params.id as string;
    const comments = await commentService.getComments(setId);
    ok(res, { items: comments });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message || 'Internal server error' });
  }
});

router.post('/dj-sets/:id/comments', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const setId = req.params.id as string;
    const body = req.body as { content?: unknown; parentId?: unknown };
    const content = typeof body.content === 'string' ? body.content : '';
    if (!content.trim()) {
      res.status(400).json({ error: 'content is required' });
      return;
    }

    const comment = await commentService.createComment({
      setId,
      userId,
      content,
      parentId: typeof body.parentId === 'string' ? body.parentId : undefined,
    });

    ok(res, comment);
  } catch (error) {
    const message = (error as Error).message || 'Internal server error';
    if (message === 'DJ Set not found') {
      res.status(404).json({ error: message });
      return;
    }
    if (message.includes('Parent comment')) {
      res.status(400).json({ error: message });
      return;
    }
    res.status(500).json({ error: message });
  }
});

router.patch('/comments/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const commentId = req.params.id as string;
    const body = req.body as { content?: unknown };
    const content = typeof body.content === 'string' ? body.content : '';
    if (!content.trim()) {
      res.status(400).json({ error: 'content is required' });
      return;
    }

    const comment = await commentService.updateComment(commentId, userId, { content });
    ok(res, comment);
  } catch (error) {
    const message = (error as Error).message || 'Internal server error';
    if (message === 'Comment not found') {
      res.status(404).json({ error: message });
      return;
    }
    if (message === 'Forbidden') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    if (message.includes('5分钟')) {
      res.status(400).json({ error: message });
      return;
    }
    res.status(500).json({ error: message });
  }
});

router.delete('/comments/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const commentId = req.params.id as string;
    await commentService.deleteComment(commentId, userId, authReq.user?.role);
    ok(res, { success: true });
  } catch (error) {
    const message = (error as Error).message || 'Internal server error';
    if (message === 'Comment not found') {
      res.status(404).json({ error: message });
      return;
    }
    if (message === 'Forbidden') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    res.status(500).json({ error: message });
  }
});

router.get('/checkins', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const skip = (page - 1) * limit;
    const type = typeof req.query.type === 'string' ? req.query.type : undefined;
    const requestedUserId = typeof req.query.userId === 'string' ? req.query.userId.trim() : '';
    const targetUserId = requestedUserId || userId;
    const djId = typeof req.query.djId === 'string' ? req.query.djId.trim() : '';
    const eventId = typeof req.query.eventId === 'string' ? req.query.eventId.trim() : '';

    const where: any = { userId: targetUserId };
    if (type === 'event' || type === 'dj') {
      where.type = type;
    }
    if (djId) where.djId = djId;
    if (eventId) where.eventId = eventId;

    const [rows, total] = await Promise.all([
      prisma.checkin.findMany({
        where,
        skip,
        take: limit,
        orderBy: [{ attendedAt: 'desc' }, { createdAt: 'desc' }],
        include: {
          event: {
            select: {
              id: true,
              name: true,
              coverImageUrl: true,
              city: true,
              country: true,
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
        },
      }),
      prisma.checkin.count({ where }),
    ]);

    ok(
      res,
      {
        items: rows.map((row) => ({
          id: row.id,
          userId: row.userId,
          eventId: row.eventId,
          djId: row.djId,
          type: row.type,
          note: row.note,
          photoUrl: row.photoUrl,
          rating: row.rating,
          attendedAt: row.attendedAt,
          createdAt: row.createdAt,
          event: row.event,
          dj: row.dj,
        })),
      },
      {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      }
    );
  } catch (error) {
    console.error('BFF web checkins error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/checkins', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = req.body as Record<string, unknown>;
    const type = typeof body.type === 'string' ? body.type.trim() : '';
    if (type !== 'event' && type !== 'dj') {
      res.status(400).json({ error: 'type must be event or dj' });
      return;
    }

    const eventId = typeof body.eventId === 'string' ? body.eventId : null;
    const djId = typeof body.djId === 'string' ? body.djId : null;
    const attendedAt =
      typeof body.attendedAt === 'string' && body.attendedAt.trim().length > 0
        ? new Date(body.attendedAt)
        : null;

    if (type === 'event' && !eventId) {
      res.status(400).json({ error: 'eventId is required for event checkin' });
      return;
    }
    if (type === 'dj' && !djId) {
      res.status(400).json({ error: 'djId is required for dj checkin' });
      return;
    }
    if (attendedAt && Number.isNaN(attendedAt.getTime())) {
      res.status(400).json({ error: 'attendedAt must be a valid ISO datetime' });
      return;
    }

    const created = await prisma.checkin.create({
      data: {
        userId,
        type,
        // Allow DJ checkins to optionally bind to an event for timeline grouping.
        eventId,
        djId: type === 'dj' ? djId : null,
        note: typeof body.note === 'string' ? body.note : null,
        photoUrl: typeof body.photoUrl === 'string' ? body.photoUrl : null,
        rating: typeof body.rating === 'number' ? body.rating : null,
        attendedAt: attendedAt ?? new Date(),
      },
      include: {
        event: {
          select: {
            id: true,
            name: true,
            coverImageUrl: true,
            city: true,
            country: true,
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
      },
    });

    ok(res, created);
  } catch (error) {
    console.error('BFF web create checkin error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/checkins/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const checkinId = req.params.id as string;
    const existing = await prisma.checkin.findUnique({
      where: { id: checkinId },
      select: { id: true, userId: true },
    });

    if (!existing) {
      res.status(404).json({ error: 'Checkin not found' });
      return;
    }

    if (authReq.user?.role !== 'admin' && existing.userId !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    await prisma.checkin.delete({ where: { id: checkinId } });
    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete checkin error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/rating-events', optionalAuth, async (_req: Request, res: Response): Promise<void> => {
  try {
    const rows = await prisma.ratingEvent.findMany({
      orderBy: [{ createdAt: 'desc' }],
      include: {
        createdBy: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        units: {
          orderBy: [{ createdAt: 'asc' }],
          include: {
            comments: {
              select: { score: true },
            },
            createdBy: {
              select: { id: true, username: true, displayName: true, avatarUrl: true },
            },
          },
        },
      },
    });

    ok(res, { items: rows.map(mapRatingEvent) });
  } catch (error) {
    console.error('BFF web rating events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/rating-events/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const eventId = req.params.id as string;
    const row = await prisma.ratingEvent.findUnique({
      where: { id: eventId },
      include: {
        createdBy: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        units: {
          orderBy: [{ createdAt: 'asc' }],
          include: {
            comments: {
              select: { score: true },
            },
            createdBy: {
              select: { id: true, username: true, displayName: true, avatarUrl: true },
            },
          },
        },
      },
    });

    if (!row) {
      res.status(404).json({ error: 'Rating event not found' });
      return;
    }

    ok(res, mapRatingEvent(row));
  } catch (error) {
    console.error('BFF web rating event detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/rating-events', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = req.body as Record<string, unknown>;
    const name = typeof body.name === 'string' ? body.name.trim() : '';
    if (!name) {
      res.status(400).json({ error: 'name is required' });
      return;
    }

    const created = await prisma.ratingEvent.create({
      data: {
        createdById: userId,
        name,
        description: typeof body.description === 'string' ? body.description.trim() || null : null,
        imageUrl: typeof body.imageUrl === 'string' ? body.imageUrl.trim() || null : null,
      },
      include: {
        createdBy: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        units: {
          orderBy: [{ createdAt: 'asc' }],
          include: {
            comments: {
              select: { score: true },
            },
            createdBy: {
              select: { id: true, username: true, displayName: true, avatarUrl: true },
            },
          },
        },
      },
    });

    ok(res, mapRatingEvent(created));
  } catch (error) {
    console.error('BFF web create rating event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/rating-events/:id/units', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const eventId = req.params.id as string;
    const event = await prisma.ratingEvent.findUnique({
      where: { id: eventId },
      select: { id: true },
    });
    if (!event) {
      res.status(404).json({ error: 'Rating event not found' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const name = typeof body.name === 'string' ? body.name.trim() : '';
    if (!name) {
      res.status(400).json({ error: 'name is required' });
      return;
    }

    const created = await prisma.ratingUnit.create({
      data: {
        eventId,
        createdById: userId,
        name,
        description: typeof body.description === 'string' ? body.description.trim() || null : null,
        imageUrl: typeof body.imageUrl === 'string' ? body.imageUrl.trim() || null : null,
      },
      include: {
        comments: {
          select: { score: true },
        },
        createdBy: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    ok(res, mapRatingUnit(created));
  } catch (error) {
    console.error('BFF web create rating unit error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/rating-events/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const eventId = req.params.id as string;
    const existing = await prisma.ratingEvent.findUnique({
      where: { id: eventId },
      select: { id: true, createdById: true },
    });
    if (!existing) {
      res.status(404).json({ error: 'Rating event not found' });
      return;
    }
    if (authReq.user?.role !== 'admin' && existing.createdById !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const updated = await prisma.ratingEvent.update({
      where: { id: eventId },
      data: {
        name: typeof body.name === 'string' ? body.name.trim() : undefined,
        description: typeof body.description === 'string' ? body.description.trim() || null : undefined,
        imageUrl: typeof body.imageUrl === 'string' ? body.imageUrl.trim() || null : undefined,
      },
      include: {
        createdBy: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        units: {
          orderBy: [{ createdAt: 'asc' }],
          include: {
            comments: {
              select: { score: true },
            },
            createdBy: {
              select: { id: true, username: true, displayName: true, avatarUrl: true },
            },
          },
        },
      },
    });

    ok(res, mapRatingEvent(updated));
  } catch (error) {
    console.error('BFF web update rating event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/rating-events/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const eventId = req.params.id as string;
    const existing = await prisma.ratingEvent.findUnique({
      where: { id: eventId },
      select: { id: true, createdById: true },
    });
    if (!existing) {
      res.status(404).json({ error: 'Rating event not found' });
      return;
    }
    if (authReq.user?.role !== 'admin' && existing.createdById !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    await prisma.ratingEvent.delete({ where: { id: eventId } });
    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete rating event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/rating-units/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const unitId = req.params.id as string;
    const row = await prisma.ratingUnit.findUnique({
      where: { id: unitId },
      include: {
        event: {
          select: { id: true, name: true, description: true, imageUrl: true },
        },
        comments: {
          orderBy: [{ createdAt: 'desc' }],
          include: {
            user: {
              select: { id: true, username: true, displayName: true, avatarUrl: true },
            },
          },
        },
        createdBy: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    if (!row) {
      res.status(404).json({ error: 'Rating unit not found' });
      return;
    }

    ok(res, {
      ...mapRatingUnit(row, true),
      event: row.event,
    });
  } catch (error) {
    console.error('BFF web rating unit detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/rating-units/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const unitId = req.params.id as string;
    const existing = await prisma.ratingUnit.findUnique({
      where: { id: unitId },
      select: { id: true, createdById: true },
    });
    if (!existing) {
      res.status(404).json({ error: 'Rating unit not found' });
      return;
    }
    if (authReq.user?.role !== 'admin' && existing.createdById !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const updated = await prisma.ratingUnit.update({
      where: { id: unitId },
      data: {
        name: typeof body.name === 'string' ? body.name.trim() : undefined,
        description: typeof body.description === 'string' ? body.description.trim() || null : undefined,
        imageUrl: typeof body.imageUrl === 'string' ? body.imageUrl.trim() || null : undefined,
      },
      include: {
        comments: {
          select: { score: true },
        },
        createdBy: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    ok(res, mapRatingUnit(updated));
  } catch (error) {
    console.error('BFF web update rating unit error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/rating-units/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const unitId = req.params.id as string;
    const existing = await prisma.ratingUnit.findUnique({
      where: { id: unitId },
      select: { id: true, createdById: true },
    });
    if (!existing) {
      res.status(404).json({ error: 'Rating unit not found' });
      return;
    }
    if (authReq.user?.role !== 'admin' && existing.createdById !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    await prisma.ratingUnit.delete({ where: { id: unitId } });
    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete rating unit error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/rating-units/:id/comments', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const unitId = req.params.id as string;
    const body = req.body as Record<string, unknown>;
    const content = typeof body.content === 'string' ? body.content.trim() : '';
    const score = typeof body.score === 'number' ? Math.round(body.score) : NaN;

    if (!Number.isFinite(score) || score < 1 || score > 10) {
      res.status(400).json({ error: '请先评分' });
      return;
    }
    if (!content) {
      res.status(400).json({ error: 'content is required' });
      return;
    }

    const unit = await prisma.ratingUnit.findUnique({
      where: { id: unitId },
      select: { id: true },
    });
    if (!unit) {
      res.status(404).json({ error: 'Rating unit not found' });
      return;
    }

    const comment = await prisma.ratingComment.create({
      data: {
        unitId,
        userId,
        score,
        content,
      },
      include: {
        user: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    ok(res, mapRatingComment(comment));
  } catch (error) {
    console.error('BFF web create rating comment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/learn/genres', (_req: Request, res: Response): void => {
  const genreTree = [
    {
      id: 'house',
      name: 'House',
      description: '以四拍地板鼓点为核心，强调律动和舞池氛围。',
      children: [
        { id: 'deep-house', name: 'Deep House', description: '更柔和、更氛围化，低频和和声更细腻。' },
        { id: 'tech-house', name: 'Tech House', description: '融合 Techno 的极简与 House 的律动感。' },
        { id: 'progressive-house', name: 'Progressive House', description: '注重层层推进和情绪堆叠，适合大舞台。' },
      ],
    },
    {
      id: 'techno',
      name: 'Techno',
      description: '强调工业感、重复性和催眠式推进。',
      children: [
        { id: 'melodic-techno', name: 'Melodic Techno', description: '在 Techno 框架中加入旋律与情绪线。' },
        { id: 'hard-techno', name: 'Hard Techno', description: '速度更快、冲击更强、能量密度更高。' },
      ],
    },
    {
      id: 'bass-music',
      name: 'Bass Music',
      description: '强调低频冲击和节奏变化，现场表现力强。',
      children: [
        { id: 'dubstep', name: 'Dubstep', description: '以重低音和 Drop 变化为标志。' },
        { id: 'future-bass', name: 'Future Bass', description: '旋律化和弦与爆发式低频结合。' },
        { id: 'drum-and-bass', name: 'Drum & Bass', description: '高速 breakbeat 与深厚低频的经典组合。' },
      ],
    },
    {
      id: 'trance',
      name: 'Trance',
      description: '强调旋律推进、铺垫和情绪释放。',
      children: [
        { id: 'uplifting-trance', name: 'Uplifting Trance', description: '旋律明亮、情感强烈，高潮感突出。' },
        { id: 'psytrance', name: 'Psytrance', description: '高能重复节奏与迷幻音色。' },
      ],
    },
  ];

  ok(res, genreTree);
});

type LearnLabelSortBy = 'soundcloudFollowers' | 'likes' | 'name' | 'nation' | 'latestRelease' | 'createdAt';

const parseLearnLabelSortBy = (value: unknown): LearnLabelSortBy => {
  if (value === 'likes') return 'likes';
  if (value === 'name') return 'name';
  if (value === 'nation') return 'nation';
  if (value === 'latestRelease') return 'latestRelease';
  if (value === 'createdAt') return 'createdAt';
  return 'soundcloudFollowers';
};

const parseMultiFilterValues = (value: unknown): string[] => {
  const normalized = Array.isArray(value) ? value : [value];
  return normalized
    .flatMap((item) => (typeof item === 'string' ? item.split(',') : []))
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
};

router.get('/learn/labels', async (req: Request, res: Response): Promise<void> => {
  try {
    const page = normalizePage(req.query.page);
    const limit = normalizeLimit(req.query.limit, 20, 500);
    const sortBy = parseLearnLabelSortBy(req.query.sortBy);

    const defaultOrder: Prisma.SortOrder = sortBy === 'name' || sortBy === 'nation' ? 'asc' : 'desc';
    const order = parseSortOrder(req.query.order, defaultOrder);

    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const nationFilters = Array.from(
      new Set([
        ...parseMultiFilterValues(req.query.nation),
        ...parseMultiFilterValues(req.query.nations),
      ])
    );
    const genreFilters = Array.from(
      new Set([
        ...parseMultiFilterValues(req.query.genre),
        ...parseMultiFilterValues(req.query.genres),
      ])
    );

    const andConditions: Prisma.LabelWhereInput[] = [];

    if (search) {
      andConditions.push({
        OR: [
          { name: { contains: search, mode: 'insensitive' } },
          { introduction: { contains: search, mode: 'insensitive' } },
          { genresPreview: { contains: search, mode: 'insensitive' } },
        ],
      });
    }

    if (nationFilters.length > 0) {
      andConditions.push({
        OR: nationFilters.map((nation) => ({
          nation: { equals: nation, mode: 'insensitive' },
        })),
      });
    }

    if (genreFilters.length > 0) {
      for (const genre of genreFilters) {
        andConditions.push({ genres: { has: genre } });
      }
    }

    const where: Prisma.LabelWhereInput =
      andConditions.length > 0
        ? { AND: andConditions }
        : {};

    const orderBy: Prisma.LabelOrderByWithRelationInput =
      sortBy === 'soundcloudFollowers'
        ? { soundcloudFollowers: order }
        : sortBy === 'likes'
          ? { likes: order }
          : sortBy === 'nation'
            ? { nation: order }
            : sortBy === 'latestRelease'
              ? { latestReleaseListing: order }
              : sortBy === 'createdAt'
                ? { createdAt: order }
                : { name: order };

    const [labels, total] = await Promise.all([
      prisma.label.findMany({
        where,
        orderBy,
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.label.count({ where }),
    ]);

    const founderDjIds = Array.from(
      new Set(
        labels
          .map((item) => item.founderDjId)
          .filter((id): id is string => Boolean(id))
      )
    );
    const founderDjs = founderDjIds.length > 0
      ? await prisma.dJ.findMany({
          where: { id: { in: founderDjIds } },
        })
      : [];
    const founderDjById = new Map(founderDjs.map((item: { id: string }) => [item.id, item]));
    const hydratedLabels = labels.map((item) => ({
      ...item,
      founderDj: item.founderDjId ? founderDjById.get(item.founderDjId) ?? null : null,
    }));

    ok(
      res,
      {
        items: hydratedLabels,
      },
      {
        page,
        limit,
        total,
        totalPages: Math.max(1, Math.ceil(total / limit)),
      }
    );
  } catch (error) {
    console.error('BFF web learn labels error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/learn/rankings', (_req: Request, res: Response): void => {
  ok(
    res,
    Object.entries(RANKING_BOARDS).map(([id, board]) => ({
      id,
      title: board.title,
      subtitle: board.subtitle,
      coverImageUrl: board.coverImageUrl || null,
      years: board.years,
    }))
  );
});

router.get('/learn/rankings/:boardId', async (req: Request, res: Response): Promise<void> => {
  try {
    const boardId = req.params.boardId as string;
    const board = RANKING_BOARDS[boardId];
    if (!board) {
      res.status(404).json({ error: 'Board not found' });
      return;
    }

    const requestedYear = Number(req.query.year);
    const year = Number.isFinite(requestedYear) ? requestedYear : board.years[board.years.length - 1];
    if (!board.years.includes(year)) {
      res.status(400).json({ error: 'year is invalid' });
      return;
    }

    const currentFile = rankingFilePath(boardId, year);
    if (!currentFile) {
      res.status(404).json({ error: 'Ranking data not found' });
      return;
    }

    const currentText = fs.readFileSync(currentFile, 'utf8');
    const current = parseRankingText(currentText);

    const prevYear = board.years[board.years.indexOf(year) - 1];
    const prev = prevYear
      ? (() => {
          const prevFile = rankingFilePath(boardId, prevYear);
          if (!prevFile) return [] as Array<{ rank: number; name: string }>;
          return parseRankingText(fs.readFileSync(prevFile, 'utf8'));
        })()
      : [];

    const previousRankMap: Record<string, number> = {};
    for (const item of prev) {
      previousRankMap[normalizeName(item.name)] = item.rank;
    }

    const djs = await prisma.dJ.findMany({
      select: {
        id: true,
        name: true,
        slug: true,
        avatarUrl: true,
        bannerUrl: true,
        followerCount: true,
        country: true,
      },
    });
    const djMap: Record<string, any> = {};
    for (const dj of djs) {
      djMap[normalizeName(dj.name)] = dj;
    }

    const entries = current.map((item) => {
      const key = normalizeName(item.name);
      const prevRank = previousRankMap[key];
      return {
        rank: item.rank,
        name: item.name,
        delta: prevYear && prevRank !== undefined ? prevRank - item.rank : null,
        dj: djMap[key]
          ? {
              id: djMap[key].id,
              name: djMap[key].name,
              slug: djMap[key].slug,
              avatarUrl: djMap[key].avatarUrl,
              bannerUrl: djMap[key].bannerUrl,
              followerCount: djMap[key].followerCount,
              country: djMap[key].country,
            }
          : null,
      };
    });

    ok(res, {
      boardId,
      title: board.title,
      years: board.years,
      year,
      entries,
    });
  } catch (error) {
    console.error('BFF web rankings detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/publishes/me', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const [djSets, events, ratingEvents, ratingUnits] = await Promise.all([
      prisma.dJSet.findMany({
        where: { uploadedById: userId },
        include: {
          dj: {
            select: {
              id: true,
              name: true,
              slug: true,
              avatarUrl: true,
              bannerUrl: true,
              country: true,
            },
          },
          tracks: {
            select: { id: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.event.findMany({
        where: { organizerId: userId },
        include: {
          lineupSlots: {
            select: { id: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.ratingEvent.findMany({
        where: { createdById: userId },
        include: {
          units: {
            select: { id: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.ratingUnit.findMany({
        where: { createdById: userId },
        include: {
          event: {
            select: { id: true, name: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    ok(res, {
      djSets: djSets.map((set) => ({
        id: set.id,
        title: set.title,
        thumbnailUrl: set.thumbnailUrl,
        createdAt: set.createdAt,
        trackCount: set.tracks.length,
        dj: set.dj,
      })),
      events: events.map((event) => ({
        id: event.id,
        name: event.name,
        coverImageUrl: event.coverImageUrl,
        city: event.city,
        country: event.country,
        startDate: event.startDate,
        createdAt: event.createdAt,
        lineupSlotCount: event.lineupSlots.length,
      })),
      ratingEvents: ratingEvents.map((event) => ({
        id: event.id,
        name: event.name,
        imageUrl: event.imageUrl,
        description: event.description,
        unitCount: event.units.length,
        createdAt: event.createdAt,
      })),
      ratingUnits: ratingUnits.map((unit) => ({
        id: unit.id,
        eventId: unit.eventId,
        eventName: unit.event?.name || '未知事件',
        name: unit.name,
        imageUrl: unit.imageUrl,
        description: unit.description,
        createdAt: unit.createdAt,
      })),
    });
  } catch (error) {
    console.error('BFF web my publishes error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
