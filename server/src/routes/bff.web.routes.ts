import { Router, Request, Response, NextFunction } from 'express';
import { PrismaClient, Prisma } from '@prisma/client';
import OSS from 'ali-oss';
import multer from 'multer';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import djSetService from '../services/djset.service';
import commentService from '../services/comment.service';
import spotifyArtistService, { SpotifyUpstreamError } from '../services/spotify-artist.service';
import discogsArtistService, { DiscogsUpstreamError } from '../services/discogs-artist.service';
import soundcloudArtistService, { SoundCloudUpstreamError } from '../services/soundcloud-artist.service';
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

type EventBiTextPayload = {
  en: string;
  zh: string;
};

type EventSocialLinkPayload = {
  type: string;
  url: string;
  label?: string;
};

type EventImageAssetPayload = {
  type: 'cover' | 'luall' | 'tt' | 'other';
  label: string;
  url: string;
  source?: string;
  originalUrl?: string;
  fileName?: string;
  order?: number;
  sort?: number;
};

const normalizeEventText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const normalizeEventBiText = (value: unknown, fallback = ''): EventBiTextPayload | null => {
  const fallbackText = fallback.trim();
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    const row = value as Record<string, unknown>;
    const en = normalizeEventText(row.en ?? row.EN ?? row.english) || fallbackText;
    const zh = normalizeEventText(row.zh ?? row.ZH ?? row.cn ?? row.chinese) || en || fallbackText;
    const normalizedEn = en || zh || fallbackText;
    const normalizedZh = zh || en || fallbackText;
    if (!normalizedEn && !normalizedZh) return null;
    return {
      en: normalizedEn,
      zh: normalizedZh,
    };
  }

  const plain = normalizeEventText(value) || fallbackText;
  if (!plain) return null;
  return {
    en: plain,
    zh: plain,
  };
};

const normalizeDJBiText = (value: unknown, fallback = ''): EventBiTextPayload | null =>
  normalizeEventBiText(value, fallback);

const resolveBiTextWithFallback = (value: unknown, fallback = ''): EventBiTextPayload | null =>
  normalizeEventBiText(value, fallback);

const parseEventReferenceLinks = (value: unknown): string[] => {
  const list = Array.isArray(value)
    ? value
    : typeof value === 'string'
      ? value.split(/\r?\n/g)
      : [];

  const result: string[] = [];
  const seen = new Set<string>();
  for (const item of list) {
    const url = normalizeEventText(item);
    if (!url) continue;
    const key = url.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(url);
  }
  return result;
};

const parseEventSocialLinks = (value: unknown): EventSocialLinkPayload[] => {
  if (!Array.isArray(value)) return [];

  const normalized = value
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const row = item as Record<string, unknown>;
      const url = normalizeEventText(row.url);
      if (!url) return null;

      const type = normalizeEventText(row.type).toLowerCase() || 'website';
      const label = normalizeEventText(row.label);
      return {
        type,
        url,
        ...(label ? { label } : {}),
      } as EventSocialLinkPayload;
    })
    .filter((item): item is EventSocialLinkPayload => item !== null);

  const deduped: EventSocialLinkPayload[] = [];
  const seen = new Set<string>();
  for (const item of normalized) {
    const key = `${item.type}::${item.url}`.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(item);
  }

  return deduped;
};

const parseEventImageAssets = (value: unknown): EventImageAssetPayload[] => {
  if (!Array.isArray(value)) return [];
  const allowedTypes = new Set(['cover', 'luall', 'tt', 'other']);
  return value
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const row = item as Record<string, unknown>;
      const typeRaw = normalizeEventText(row.type).toLowerCase();
      if (!allowedTypes.has(typeRaw)) return null;
      const url = normalizeEventText(row.url);
      if (!url) return null;
      const label = normalizeEventText(row.label) || typeRaw.toUpperCase();

      const order = typeof row.order === 'number' && Number.isFinite(row.order) ? row.order : undefined;
      const sort = typeof row.sort === 'number' && Number.isFinite(row.sort) ? row.sort : undefined;
      const source = normalizeEventText(row.source) || undefined;
      const originalUrl = normalizeEventText(row.originalUrl) || undefined;
      const fileName = normalizeEventText(row.fileName) || undefined;

      return {
        type: typeRaw as EventImageAssetPayload['type'],
        label,
        url,
        ...(source ? { source } : {}),
        ...(originalUrl ? { originalUrl } : {}),
        ...(fileName ? { fileName } : {}),
        ...(order !== undefined ? { order } : {}),
        ...(sort !== undefined ? { sort } : {}),
      } as EventImageAssetPayload;
    })
    .filter((item): item is EventImageAssetPayload => item !== null);
};

type NormalizedLineupSlot = {
  djId: string | null;
  djIds: string[];
  festivalDayIndex: number | null;
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

const EVENT_TYPE_FILTER_ALIASES: Record<string, string[]> = {
  festival: ['festival', '电音节'],
  bar_event: ['bar_event', 'bar event', 'bar-event', '酒吧活动'],
  outdoor_event: ['outdoor_event', 'outdoor event', 'outdoor-event', '露天活动'],
  club_party: ['club_party', 'club party', 'club-party', '俱乐部派对'],
  warehouse_party: ['warehouse_party', 'warehouse party', 'warehouse-party', '仓库派对'],
  tour_special: ['tour_special', 'tour special', 'tour-special', '巡演专场'],
  other: ['other', '其他'],
};

const normalizeEventTypeFilterKey = (value: string): string =>
  value
    .trim()
    .toLowerCase()
    .replace(/-/g, '_')
    .replace(/\s+/g, '_');

const resolveEventTypeFilterValues = (rawValue: string): string[] => {
  const trimmed = rawValue.trim();
  if (!trimmed) return [];
  const key = normalizeEventTypeFilterKey(trimmed);
  const aliases = EVENT_TYPE_FILTER_ALIASES[key];
  if (!aliases || aliases.length === 0) {
    return [trimmed];
  }
  return aliases;
};

const LINEUP_DJ_ID_PLACEHOLDER = '__UNBOUND__';
const isLineupDjIdPlaceholder = (value: string): boolean => value === LINEUP_DJ_ID_PLACEHOLDER;

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
  dayRolloverHour: number
): number | null => {
  if (Number.isNaN(startTime.getTime()) || Number.isNaN(eventStartDate.getTime())) {
    return null;
  }
  const calendar = CalendarJS;
  const eventStartDay = calendar.startOfDay(eventStartDate);
  const slotStartDay = calendar.startOfDay(startTime);
  let dayOffset = calendar.diffDays(eventStartDay, slotStartDay);
  if (dayOffset > 0 && startTime.getHours() < dayRolloverHour) {
    dayOffset -= 1;
  }
  return Math.max(1, dayOffset + 1);
};

const CalendarJS = {
  startOfDay(date: Date): Date {
    const out = new Date(date);
    out.setHours(0, 0, 0, 0);
    return out;
  },
  diffDays(from: Date, to: Date): number {
    const millis = this.startOfDay(to).getTime() - this.startOfDay(from).getTime();
    return Math.floor(millis / 86_400_000);
  },
};

const normalizeLineupSlots = (
  slots: unknown,
  eventStartDate: Date,
  dayRolloverHourRaw: unknown = 6
): NormalizedLineupSlot[] => {
  if (!Array.isArray(slots)) {
    return [];
  }

  const dayRolloverHour = normalizeDayRolloverHour(dayRolloverHourRaw, 6);
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
      const rawDjId = typeof slot.djId === 'string' && slot.djId.trim() ? slot.djId.trim() : '';
      const rawDjIds = Array.isArray(slot.djIds) ? slot.djIds : [];
      const cleanedDjIds = rawDjIds
        .map((id) => (typeof id === 'string' ? id.trim() : ''))
        .filter((id) => !!id);
      const normalizedRawDjId = rawDjId && !isLineupDjIdPlaceholder(rawDjId) ? rawDjId : '';
      const firstBoundDjId = cleanedDjIds.find((id) => !isLineupDjIdPlaceholder(id)) || '';
      const effectiveDjId = normalizedRawDjId || firstBoundDjId || null;
      // Always recompute festivalDayIndex from the effective startTime.
      // This prevents stale historical indices (e.g. previously imported Day7/Day8)
      // from being preserved after users edit and save timetable rows.
      const festivalDayIndex =
        inferFestivalDayIndex(startTime, safeEventStart, dayRolloverHour);
      const djIds = cleanedDjIds.length
        ? cleanedDjIds
        : (effectiveDjId ? [effectiveDjId] : []);
      const hasIdentity = djName.length > 0 || !!effectiveDjId || djIds.length > 0;
      if (!hasIdentity) {
        return null;
      }

      return {
        djId: effectiveDjId,
        djIds,
        festivalDayIndex,
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
const feedUploadDir = path.join(process.cwd(), 'uploads', 'feed');
const djUploadDir = path.join(process.cwd(), 'uploads', 'djs');
const ratingUploadDir = path.join(process.cwd(), 'uploads', 'ratings');
const wikiBrandUploadDir = path.join(process.cwd(), 'uploads', 'wiki-brands');
for (const dir of [eventUploadDir, djSetUploadDir, feedUploadDir, djUploadDir, ratingUploadDir, wikiBrandUploadDir]) {
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
const lineupImportImageUpload = createImageUpload(eventUploadDir, 10 * 1024 * 1024);
const djSetThumbUpload = createImageUpload(djSetUploadDir, 10 * 1024 * 1024);
const djSetVideoUpload = createVideoUpload(djSetUploadDir, 300 * 1024 * 1024);
const feedImageUpload = createImageUpload(feedUploadDir, 10 * 1024 * 1024);
const feedVideoUpload = createVideoUpload(feedUploadDir, 300 * 1024 * 1024);
const djImageUpload = createImageUpload(djUploadDir, 10 * 1024 * 1024);
const ratingImageUpload = createImageUpload(ratingUploadDir, 10 * 1024 * 1024);
const wikiBrandImageUpload = createImageUpload(wikiBrandUploadDir, 10 * 1024 * 1024);

const cleanEnv = (value: string | undefined): string | null => {
  if (!value) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const ossRegion = cleanEnv(process.env.OSS_REGION);
const ossAccessKeyId = cleanEnv(process.env.OSS_ACCESS_KEY_ID);
const ossAccessKeySecret = cleanEnv(process.env.OSS_ACCESS_KEY_SECRET);
const ossBucket = cleanEnv(process.env.OSS_BUCKET);
const ossEndpoint = cleanEnv(process.env.OSS_ENDPOINT);
const ossPostsPrefix = (cleanEnv(process.env.OSS_POSTS_PREFIX) || 'posts').replace(/^\/+|\/+$/g, '');
const ossEventsPrefix = (cleanEnv(process.env.OSS_EVENTS_PREFIX) || 'wen-jasonlee/events').replace(/^\/+|\/+$/g, '');
const ossDjsPrefix = (cleanEnv(process.env.OSS_DJS_PREFIX) || 'wen-jasonlee/djs').replace(/^\/+|\/+$/g, '');
const ossRatingsPrefix = (cleanEnv(process.env.OSS_RATINGS_PREFIX) || 'wen-jasonlee/ratings').replace(/^\/+|\/+$/g, '');
const ossWikiBrandsPrefix = (cleanEnv(process.env.OSS_WIKI_BRANDS_PREFIX) || 'wiki/brands').replace(/^\/+|\/+$/g, '');
const cozeWorkflowRunUrl = cleanEnv(process.env.COZE_WORKFLOW_RUN_URL) || 'https://dxy8zryvs2.coze.site/run';
const cozeWorkflowToken = cleanEnv(process.env.COZE_WORKFLOW_TOKEN);
const cozeWorkflowImageField = cleanEnv(process.env.COZE_WORKFLOW_IMAGE_FIELD) || 'festival_image';
const cozeWorkflowTimeoutMs = (() => {
  const parsed = Number(process.env.COZE_WORKFLOW_TIMEOUT_MS);
  if (Number.isFinite(parsed) && parsed >= 10_000 && parsed <= 600_000) {
    return Math.floor(parsed);
  }
  return 120_000;
})();

const postMediaOssClient =
  ossRegion && ossAccessKeyId && ossAccessKeySecret && ossBucket
    ? new OSS({
        region: ossRegion,
        accessKeyId: ossAccessKeyId,
        accessKeySecret: ossAccessKeySecret,
        bucket: ossBucket,
        endpoint: ossEndpoint || undefined,
      })
    : null;

const looksLikePostMediaName = (name: string, kind: 'image' | 'video'): boolean => {
  const lower = name.trim().toLowerCase();
  if (!lower) return false;
  if (kind === 'image') {
    return lower.startsWith('post-image-');
  }
  return lower.startsWith('post-video-');
};

const normalizeUploadedOssUrl = (rawUrl: string | undefined, objectKey: string): string => {
  if (rawUrl && rawUrl.trim().length > 0) {
    if (rawUrl.startsWith('//')) return `https:${rawUrl}`;
    if (rawUrl.startsWith('http://')) return `https://${rawUrl.slice('http://'.length)}`;
    if (rawUrl.startsWith('https://')) return rawUrl;
  }

  if (!ossBucket || !ossRegion) {
    throw new Error('OSS bucket/region is not configured');
  }
  const endpointHost = ossEndpoint
    ? ossEndpoint.replace(/^https?:\/\//, '').replace(/^\/+|\/+$/g, '')
    : `${ossRegion}.aliyuncs.com`;
  const bucketHost = endpointHost.startsWith(`${ossBucket}.`) ? endpointHost : `${ossBucket}.${endpointHost}`;
  return `https://${bucketHost}/${objectKey}`;
};

const sanitizeOssPathSegment = (value: string): string =>
  value
    .trim()
    .replace(/[^a-zA-Z0-9-_]/g, '')
    .slice(0, 128);

const buildEventMediaObjectKey = (
  eventId: string,
  fileName: string,
  mimeType: string,
  usage: string | null
): string => {
  const rawExt = path.extname(fileName || '').toLowerCase();
  const mimeExt = mimeType.includes('png')
    ? '.png'
    : mimeType.includes('webp')
      ? '.webp'
      : mimeType.includes('gif')
        ? '.gif'
        : '.jpg';
  const ext = rawExt && rawExt.length <= 10 ? rawExt : mimeExt;
  const safeEventId = sanitizeOssPathSegment(eventId) || 'unknown-event';
  const safeUsage = sanitizeOssPathSegment(usage || '') || 'image';
  return `${ossEventsPrefix}/${safeEventId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const buildRatingMediaObjectKey = (
  owner: {
    userId: string;
    ratingEventId?: string | null;
    ratingUnitId?: string | null;
  },
  fileName: string,
  mimeType: string,
  usage: string | null
): string => {
  const rawExt = path.extname(fileName || '').toLowerCase();
  const mimeExt = mimeType.includes('png')
    ? '.png'
    : mimeType.includes('webp')
      ? '.webp'
      : mimeType.includes('gif')
        ? '.gif'
        : '.jpg';
  const ext = rawExt && rawExt.length <= 10 ? rawExt : mimeExt;
  const safeUsage = sanitizeOssPathSegment(usage || '') || 'image';

  const safeRatingEventId = sanitizeOssPathSegment(owner.ratingEventId || '');
  const safeRatingUnitId = sanitizeOssPathSegment(owner.ratingUnitId || '');
  const safeUserId = sanitizeOssPathSegment(owner.userId) || 'unknown-user';

  if (safeRatingEventId && safeRatingUnitId) {
    return `${ossRatingsPrefix}/events/${safeRatingEventId}/units/${safeRatingUnitId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
  }
  if (safeRatingEventId) {
    return `${ossRatingsPrefix}/events/${safeRatingEventId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
  }
  if (safeRatingUnitId) {
    return `${ossRatingsPrefix}/units/${safeRatingUnitId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
  }
  return `${ossRatingsPrefix}/drafts/${safeUserId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const parseOssObjectKeyFromUrl = (value: string | null | undefined): string | null => {
  if (!value) return null;
  const trimmed = value.trim();
  if (!trimmed) return null;

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    try {
      const parsed = new URL(trimmed);
      const key = parsed.pathname.replace(/^\/+/, '');
      return key || null;
    } catch (_error) {
      return null;
    }
  }

  return null;
};

const isEventOssObjectKey = (objectKey: string, eventId: string): boolean => {
  const safeEventId = sanitizeOssPathSegment(eventId);
  if (!safeEventId) return false;
  return objectKey.startsWith(`${ossEventsPrefix}/${safeEventId}/`);
};

const isDjAvatarOssObjectKey = (objectKey: string, djId: string): boolean => {
  const safeDJId = sanitizeOssPathSegment(djId);
  if (!safeDJId) return false;
  return objectKey.startsWith(`${ossDjsPrefix}/${safeDJId}/`);
};

const isWikiBrandOssObjectKey = (objectKey: string, brandId: string): boolean => {
  const safeBrandId = sanitizeOssPathSegment(brandId);
  if (!safeBrandId) return false;
  return objectKey.startsWith(`${ossWikiBrandsPrefix}/${safeBrandId}/`);
};

const isRatingOssObjectKey = (objectKey: string): boolean => objectKey.startsWith(`${ossRatingsPrefix}/`);

const normalizeDJNameKey = (value: string): string => value.trim().toLowerCase();

const mergeAliases = (baseName: string, values: Array<string | null | undefined>): string[] => {
  const baseKey = normalizeDJNameKey(baseName);
  const result: string[] = [];
  const seen = new Set<string>([baseKey]);

  for (const raw of values) {
    if (!raw) continue;
    const trimmed = raw.trim();
    if (!trimmed) continue;
    const key = normalizeDJNameKey(trimmed);
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(trimmed);
  }

  return result;
};

const normalizeGenres = (value: unknown): string[] => {
  const list = Array.isArray(value)
    ? value
    : typeof value === 'string'
      ? value.split(/[,\n/\uFF0C\u3001|;]+/g)
      : [];
  const result: string[] = [];
  const seen = new Set<string>();
  for (const item of list) {
    if (typeof item !== 'string') continue;
    const trimmed = item.trim();
    if (!trimmed) continue;
    const key = trimmed.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(trimmed);
  }
  return result;
};

const parseOptionalNonNegativeInt = (value: unknown, fieldName: string): number | null => {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      throw new Error(`${fieldName} must be a finite number or null`);
    }
    return Math.max(0, Math.floor(value));
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return null;
    if (!/^\d+$/.test(trimmed)) {
      throw new Error(`${fieldName} must be a non-negative integer or null`);
    }
    return Math.max(0, Math.floor(Number(trimmed)));
  }
  throw new Error(`${fieldName} must be a number, string, or null`);
};

const payloadHasAnyKey = (payload: Record<string, unknown>, keys: string[]): boolean =>
  keys.some((key) => Object.prototype.hasOwnProperty.call(payload, key));

const payloadValueByKeys = (payload: Record<string, unknown>, keys: string[]): unknown => {
  for (const key of keys) {
    if (Object.prototype.hasOwnProperty.call(payload, key)) {
      return payload[key];
    }
  }
  return undefined;
};

const parseOptionalStringFromPayload = (payload: Record<string, unknown>, keys: string[]): string => {
  const value = payloadValueByKeys(payload, keys);
  return typeof value === 'string' ? value.trim() : '';
};

const splitDataSources = (value: string | null | undefined): string[] => {
  if (!value) return [];
  return value
    .split(/[|,;]+/)
    .map((item) => item.trim())
    .filter(Boolean);
};

const mergeDJDataSources = (
  existing: string | null | undefined,
  additions: Array<string | null | undefined>
): string | null => {
  const result: string[] = [];
  const seen = new Set<string>();

  const push = (raw: string | null | undefined) => {
    if (!raw) return;
    const trimmed = raw.trim();
    if (!trimmed) return;
    const key = trimmed.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    result.push(trimmed);
  };

  for (const source of splitDataSources(existing)) {
    push(source);
  }
  for (const source of additions) {
    push(source);
  }

  return result.length > 0 ? result.join('|') : null;
};

type DJContributorInfo = {
  userIds: string[];
  usernames: string[];
  users: Array<{
    id: string;
    username: string;
    displayName: string | null;
    avatarUrl: string | null;
  }>;
  uploadedByUsername: string | null;
};

const emptyDJContributorInfo: DJContributorInfo = {
  userIds: [],
  usernames: [],
  users: [],
  uploadedByUsername: null,
};

const contributorInfoFromRow = (row: any): DJContributorInfo =>
  (row?.__contributorInfo as DJContributorInfo | undefined) ?? emptyDJContributorInfo;

type DJStatsInfo = {
  eventCount: number;
  setCount: number;
};

const emptyDJStatsInfo: DJStatsInfo = {
  eventCount: 0,
  setCount: 0,
};

const statsInfoFromRow = (row: any): DJStatsInfo =>
  (row?.__statsInfo as DJStatsInfo | undefined) ?? emptyDJStatsInfo;

const fetchDJContributorInfoMap = async (djIds: string[]): Promise<Map<string, DJContributorInfo>> => {
  const validIds = Array.from(new Set(djIds.map((id) => id.trim()).filter(Boolean)));
  if (validIds.length === 0) {
    return new Map();
  }

  const rows = await prisma.$queryRaw<
    Array<{
      djId: string;
      userId: string;
      username: string;
      displayName: string | null;
      avatarUrl: string | null;
      createdAt: Date;
    }>
  >(Prisma.sql`
    SELECT
      c."dj_id" AS "djId",
      c."user_id" AS "userId",
      u."username" AS "username",
      u."display_name" AS "displayName",
      u."avatar_url" AS "avatarUrl",
      c."created_at" AS "createdAt"
    FROM "dj_contributors" c
    INNER JOIN "users" u ON u."id" = c."user_id"
    WHERE c."dj_id" IN (${Prisma.join(validIds)})
    ORDER BY c."created_at" ASC
  `);

  const map = new Map<string, DJContributorInfo>();
  for (const row of rows) {
    const current = map.get(row.djId) ?? {
      userIds: [],
      usernames: [],
      users: [],
      uploadedByUsername: null,
    };
    if (!current.userIds.includes(row.userId)) {
      current.userIds.push(row.userId);
      current.users.push({
        id: row.userId,
        username: row.username,
        displayName: row.displayName,
        avatarUrl: row.avatarUrl,
      });
    }
    const username = row.username?.trim() ?? '';
    if (username && !current.usernames.some((item) => item.toLowerCase() === username.toLowerCase())) {
      current.usernames.push(username);
    }
    if (!current.uploadedByUsername && username) {
      current.uploadedByUsername = username;
    }
    map.set(row.djId, current);
  }

  return map;
};

const fetchDJStatsInfoMap = async (djIds: string[]): Promise<Map<string, DJStatsInfo>> => {
  const validIds = Array.from(new Set(djIds.map((id) => id.trim()).filter(Boolean)));
  if (validIds.length === 0) {
    return new Map();
  }

  const [eventRows, setRows] = await Promise.all([
    prisma.$queryRaw<Array<{ djId: string; eventCount: number }>>(Prisma.sql`
      SELECT
        "s"."dj_id" AS "djId",
        COUNT(DISTINCT "s"."event_id")::int AS "eventCount"
      FROM "event_lineup_slots" AS "s"
      WHERE "s"."dj_id" IN (${Prisma.join(validIds)})
      GROUP BY "s"."dj_id"
    `),
    prisma.$queryRaw<Array<{ djId: string; setCount: number }>>(Prisma.sql`
      SELECT
        "s"."dj_id" AS "djId",
        COUNT(*)::int AS "setCount"
      FROM "dj_sets" AS "s"
      WHERE "s"."dj_id" IN (${Prisma.join(validIds)})
      GROUP BY "s"."dj_id"
    `),
  ]);

  const map = new Map<string, DJStatsInfo>();
  for (const id of validIds) {
    map.set(id, { ...emptyDJStatsInfo });
  }

  for (const row of eventRows) {
    const current = map.get(row.djId) ?? { ...emptyDJStatsInfo };
    current.eventCount = Number(row.eventCount || 0);
    map.set(row.djId, current);
  }

  for (const row of setRows) {
    const current = map.get(row.djId) ?? { ...emptyDJStatsInfo };
    current.setCount = Number(row.setCount || 0);
    map.set(row.djId, current);
  }

  return map;
};

const attachDJContributorInfo = async (row: any): Promise<any> => {
  if (!row?.id) return row;
  const [contributorMap, statsMap] = await Promise.all([
    fetchDJContributorInfoMap([String(row.id)]),
    fetchDJStatsInfoMap([String(row.id)]),
  ]);
  return {
    ...row,
    __contributorInfo: contributorMap.get(String(row.id)) ?? emptyDJContributorInfo,
    __statsInfo: statsMap.get(String(row.id)) ?? emptyDJStatsInfo,
  };
};

const attachDJContributorInfoList = async (rows: any[]): Promise<any[]> => {
  if (rows.length === 0) return rows;
  const ids = rows.map((row) => String(row.id));
  const [contributorMap, statsMap] = await Promise.all([
    fetchDJContributorInfoMap(ids),
    fetchDJStatsInfoMap(ids),
  ]);
  return rows.map((row) => ({
    ...row,
    __contributorInfo: contributorMap.get(String(row.id)) ?? emptyDJContributorInfo,
    __statsInfo: statsMap.get(String(row.id)) ?? emptyDJStatsInfo,
  }));
};

const isDJContributorByRow = (row: any, userId: string | null | undefined): boolean => {
  if (!userId) return false;
  return contributorInfoFromRow(row).userIds.includes(userId);
};

const isDJContributor = async (djId: string, userId: string): Promise<boolean> => {
  const rows = await prisma.$queryRaw<Array<{ matched: number }>>(Prisma.sql`
    SELECT 1 AS "matched"
    FROM "dj_contributors"
    WHERE "dj_id" = ${djId} AND "user_id" = ${userId}
    LIMIT 1
  `);
  return rows.length > 0;
};

const canUserEditDJ = async (
  djId: string,
  userId: string,
  role: string | null | undefined
): Promise<boolean> => {
  if (role === 'admin') return true;
  return isDJContributor(djId, userId);
};

const parseCommaSeparatedSet = (value: string | undefined, fallback: string[]): Set<string> => {
  const raw = String(value || '').trim();
  const values = (raw ? raw.split(',') : fallback)
    .map((item) => String(item || '').trim().toLowerCase())
    .filter(Boolean);
  return new Set(values);
};

const WEB_SUPER_ADMIN_USERNAMES = parseCommaSeparatedSet(
  process.env.WEB_SUPER_ADMIN_USERNAMES,
  ['uploadtester']
);
const WEB_SUPER_ADMIN_EMAILS = parseCommaSeparatedSet(
  process.env.WEB_SUPER_ADMIN_EMAILS,
  []
);

const canUserManageEvent = async (
  userId: string,
  role: string | null | undefined,
  organizerId: string | null | undefined,
  tokenEmail: string | null | undefined
): Promise<boolean> => {
  if (role === 'admin') return true;
  const normalizedTokenEmail = String(tokenEmail || '').trim().toLowerCase();
  if (normalizedTokenEmail && WEB_SUPER_ADMIN_EMAILS.has(normalizedTokenEmail)) return true;

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { role: true, username: true, email: true },
  });
  if (!user) return false;

  if (user.role === 'admin') return true;
  const normalizedUsername = String(user.username || '').trim().toLowerCase();
  if (normalizedUsername && WEB_SUPER_ADMIN_USERNAMES.has(normalizedUsername)) return true;

  const normalizedEmail = String(user.email || '').trim().toLowerCase();
  if (normalizedEmail && WEB_SUPER_ADMIN_EMAILS.has(normalizedEmail)) return true;

  return organizerId === userId;
};

const ensureDJContributor = async (djId: string, userId: string): Promise<void> => {
  await prisma.$executeRaw(Prisma.sql`
    INSERT INTO "dj_contributors" ("id", "dj_id", "user_id", "created_at", "updated_at")
    VALUES (${crypto.randomUUID()}, ${djId}, ${userId}, NOW(), NOW())
    ON CONFLICT ("dj_id", "user_id") DO NOTHING
  `);
};

const fetchDJWithContributorsById = async (djId: string) =>
  attachDJContributorInfo(
    await prisma.dJ.findUnique({
    where: { id: djId },
    })
  );

const uniqueDJSlugForName = async (name: string): Promise<string> => {
  const base = slugify(name) || `dj-${Date.now()}`;
  let candidate = base;
  let seq = 1;
  while (true) {
    const exists = await prisma.dJ.findUnique({ where: { slug: candidate } });
    if (!exists || normalizeDJNameKey(exists.name) === normalizeDJNameKey(name)) {
      return candidate;
    }
    seq += 1;
    candidate = `${base}-${seq}`;
  }
};

const buildDJAvatarObjectKey = (djId: string, mimeType: string, sourceUrl?: string | null): string => {
  const sourceExt = sourceUrl ? path.extname(sourceUrl.split('?')[0] || '').toLowerCase() : '';
  const mimeExt = mimeType.includes('png')
    ? '.png'
    : mimeType.includes('webp')
      ? '.webp'
      : mimeType.includes('gif')
        ? '.gif'
        : '.jpg';
  const ext = sourceExt && sourceExt.length <= 10 ? sourceExt : mimeExt;
  const safeDJId = sanitizeOssPathSegment(djId) || 'unknown-dj';
  return `${ossDjsPrefix}/${safeDJId}/avatar-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const buildDJMediaObjectKey = (
  djId: string,
  fileName: string,
  mimeType: string,
  usage: 'avatar' | 'banner'
): string => {
  const rawExt = path.extname(fileName || '').toLowerCase();
  const mimeExt = mimeType.includes('png')
    ? '.png'
    : mimeType.includes('webp')
      ? '.webp'
      : mimeType.includes('gif')
        ? '.gif'
        : '.jpg';
  const ext = rawExt && rawExt.length <= 10 ? rawExt : mimeExt;
  const safeDJId = sanitizeOssPathSegment(djId) || 'unknown-dj';
  const safeUsage = sanitizeOssPathSegment(usage) || 'image';
  return `${ossDjsPrefix}/${safeDJId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const buildWikiBrandMediaObjectKey = (
  brandId: string | null,
  fileName: string,
  mimeType: string,
  usage: string | null
): string => {
  const rawExt = path.extname(fileName || '').toLowerCase();
  const mimeExt = mimeType.includes('png')
    ? '.png'
    : mimeType.includes('webp')
      ? '.webp'
      : mimeType.includes('gif')
        ? '.gif'
        : '.jpg';
  const ext = rawExt && rawExt.length <= 10 ? rawExt : mimeExt;
  const safeBrandId = sanitizeOssPathSegment(brandId || '') || 'unknown-brand';
  const safeUsage = sanitizeOssPathSegment(usage || '') || 'image';
  return `${ossWikiBrandsPrefix}/${safeBrandId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const uploadRemoteDJAvatarToOss = async (
  djId: string,
  sourceUrl: string
): Promise<{ url: string; objectKey: string } | null> => {
  if (!postMediaOssClient) return null;
  const trimmed = sourceUrl.trim();
  if (!trimmed) return null;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);

  try {
    const response = await fetch(trimmed, {
      method: 'GET',
      signal: controller.signal,
      headers: {
        Accept: 'image/*',
      },
    });
    if (!response.ok) return null;

    const mimeType = (response.headers.get('content-type') || 'image/jpeg').toLowerCase();
    if (!mimeType.startsWith('image/')) return null;

    const buffer = Buffer.from(await response.arrayBuffer());
    if (buffer.length === 0) return null;

    const objectKey = buildDJAvatarObjectKey(djId, mimeType, trimmed);
    const putResult = await postMediaOssClient.put(objectKey, buffer, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });

    return {
      url: normalizeUploadedOssUrl(putResult.url, objectKey),
      objectKey,
    };
  } catch (_error) {
    return null;
  } finally {
    clearTimeout(timeout);
  }
};

const deleteOssObjects = async (keys: string[]): Promise<void> => {
  if (!postMediaOssClient || keys.length === 0) return;

  const chunkSize = 1000;
  for (let start = 0; start < keys.length; start += chunkSize) {
    const chunk = keys.slice(start, start + chunkSize);
    try {
      await postMediaOssClient.deleteMulti(chunk, { quiet: true });
    } catch (error) {
      console.error('BFF web delete OSS objects error:', error);
    }
  }
};

const deleteSingleEventOssObjectIfOwned = async (url: string | null | undefined, eventId: string): Promise<void> => {
  if (!postMediaOssClient || !url) return;
  const objectKey = parseOssObjectKeyFromUrl(url);
  if (!objectKey || !isEventOssObjectKey(objectKey, eventId)) return;
  await deleteOssObjects([objectKey]);
};

const deleteSingleDJAvatarOssObjectIfOwned = async (url: string | null | undefined, djId: string): Promise<void> => {
  if (!postMediaOssClient || !url) return;
  const objectKey = parseOssObjectKeyFromUrl(url);
  if (!objectKey || !isDjAvatarOssObjectKey(objectKey, djId)) return;
  await deleteOssObjects([objectKey]);
};

const deleteSingleDJMediaOssObjectIfOwned = async (url: string | null | undefined, djId: string): Promise<void> => {
  if (!postMediaOssClient || !url) return;
  const objectKey = parseOssObjectKeyFromUrl(url);
  if (!objectKey || !isDjAvatarOssObjectKey(objectKey, djId)) return;
  await deleteOssObjects([objectKey]);
};

const deleteSingleWikiBrandOssObjectIfOwned = async (
  url: string | null | undefined,
  brandId: string
): Promise<void> => {
  if (!postMediaOssClient || !url) return;
  const objectKey = parseOssObjectKeyFromUrl(url);
  if (!objectKey || !isWikiBrandOssObjectKey(objectKey, brandId)) return;
  await deleteOssObjects([objectKey]);
};

const deleteSingleRatingOssObjectIfOwned = async (url: string | null | undefined): Promise<void> => {
  if (!postMediaOssClient || !url) return;
  const objectKey = parseOssObjectKeyFromUrl(url);
  if (!objectKey || !isRatingOssObjectKey(objectKey)) return;
  await deleteOssObjects([objectKey]);
};

const deleteEventOssFolder = async (eventId: string): Promise<void> => {
  if (!postMediaOssClient) return;
  const safeEventId = sanitizeOssPathSegment(eventId);
  if (!safeEventId) return;
  const prefix = `${ossEventsPrefix}/${safeEventId}/`;

  let marker: string | undefined;
  const keys: string[] = [];

  do {
    let listed:
      | {
          objects?: Array<{ name?: string }>;
          nextMarker?: string;
          isTruncated?: boolean;
        }
      | undefined;

    try {
      listed = await postMediaOssClient.list(
        {
          prefix,
          marker,
          'max-keys': 1000,
        },
        {}
      );
    } catch (error) {
      console.error('BFF web list OSS folder error:', error);
      return;
    }

    const objects = Array.isArray(listed?.objects) ? listed.objects : [];
    for (const item of objects) {
      if (item?.name) {
        keys.push(item.name);
      }
    }

    if (listed?.isTruncated && listed.nextMarker) {
      marker = listed.nextMarker;
    } else {
      marker = undefined;
    }
  } while (marker);

  await deleteOssObjects(keys);
};

const deleteDJOssFolder = async (djId: string): Promise<void> => {
  if (!postMediaOssClient) return;
  const safeDJId = sanitizeOssPathSegment(djId);
  if (!safeDJId) return;
  const prefix = `${ossDjsPrefix}/${safeDJId}/`;

  let marker: string | undefined;
  const keys: string[] = [];

  do {
    let listed:
      | {
          objects?: Array<{ name?: string }>;
          nextMarker?: string;
          isTruncated?: boolean;
        }
      | undefined;

    try {
      listed = await postMediaOssClient.list(
        {
          prefix,
          marker,
          'max-keys': 1000,
        },
        {}
      );
    } catch (error) {
      console.error('BFF web list DJ OSS folder error:', error);
      return;
    }

    const objects = Array.isArray(listed?.objects) ? listed.objects : [];
    for (const item of objects) {
      if (item?.name) {
        keys.push(item.name);
      }
    }

    if (listed?.isTruncated && listed.nextMarker) {
      marker = listed.nextMarker;
    } else {
      marker = undefined;
    }
  } while (marker);

  await deleteOssObjects(keys);
};

const deleteWikiBrandOssFolder = async (brandId: string): Promise<void> => {
  if (!postMediaOssClient) return;
  const safeBrandId = sanitizeOssPathSegment(brandId);
  if (!safeBrandId) return;
  const prefix = `${ossWikiBrandsPrefix}/${safeBrandId}/`;

  let marker: string | undefined;
  const keys: string[] = [];

  do {
    let listed:
      | {
          objects?: Array<{ name?: string }>;
          nextMarker?: string;
          isTruncated?: boolean;
        }
      | undefined;

    try {
      listed = await postMediaOssClient.list(
        {
          prefix,
          marker,
          'max-keys': 1000,
        },
        {}
      );
    } catch (error) {
      console.error('BFF web list wiki brand OSS folder error:', error);
      return;
    }

    const objects = Array.isArray(listed?.objects) ? listed.objects : [];
    for (const item of objects) {
      if (item?.name) {
        keys.push(item.name);
      }
    }

    if (listed?.isTruncated && listed.nextMarker) {
      marker = listed.nextMarker;
    } else {
      marker = undefined;
    }
  } while (marker);

  await deleteOssObjects(keys);
};

const uploadPostMediaToOss = async (
  file: Express.Multer.File,
  kind: 'image' | 'video',
  scopeKey?: string | null
): Promise<{ url: string; fileName: string; mimeType: string; size: number }> => {
  if (!postMediaOssClient) {
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  const originalExt = path.extname(file.originalname || '').toLowerCase();
  const fallbackExt = kind === 'image' ? '.jpg' : '.mp4';
  const safeExt = originalExt && originalExt.length <= 10 ? originalExt : fallbackExt;
  const safeScopeKey = scopeKey ? sanitizeOssPathSegment(scopeKey) : '';
  const postMediaDir = safeScopeKey ? `${ossPostsPrefix}/news/${safeScopeKey}` : ossPostsPrefix;
  const objectKey = `${postMediaDir}/${kind}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${safeExt}`;
  const mimeType = file.mimetype || (kind === 'image' ? 'image/jpeg' : 'video/mp4');

  let putResult: { url?: string };
  try {
    putResult = await postMediaOssClient.put(objectKey, file.path, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }

  return {
    url: normalizeUploadedOssUrl(putResult.url, objectKey),
    fileName: path.basename(objectKey),
    mimeType,
    size: file.size,
  };
};

const uploadEventMediaToOss = async (
  file: Express.Multer.File,
  eventId: string,
  usage: string | null
): Promise<{ url: string; fileName: string; mimeType: string; size: number }> => {
  if (!postMediaOssClient) {
    await fs.promises.unlink(file.path).catch(() => undefined);
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  const mimeType = file.mimetype || 'image/jpeg';
  const objectKey = buildEventMediaObjectKey(eventId, file.originalname || file.filename || 'image.jpg', mimeType, usage);

  let putResult: { url?: string };
  try {
    putResult = await postMediaOssClient.put(objectKey, file.path, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }

  return {
    url: normalizeUploadedOssUrl(putResult.url, objectKey),
    fileName: path.basename(objectKey),
    mimeType,
    size: file.size,
  };
};

const uploadRatingMediaToOss = async (
  file: Express.Multer.File,
  owner: {
    userId: string;
    ratingEventId?: string | null;
    ratingUnitId?: string | null;
  },
  usage: string | null
): Promise<{ url: string; fileName: string; mimeType: string; size: number }> => {
  if (!postMediaOssClient) {
    await fs.promises.unlink(file.path).catch(() => undefined);
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  const mimeType = file.mimetype || 'image/jpeg';
  const objectKey = buildRatingMediaObjectKey(owner, file.originalname || file.filename || 'image.jpg', mimeType, usage);

  let putResult: { url?: string };
  try {
    putResult = await postMediaOssClient.put(objectKey, file.path, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }

  return {
    url: normalizeUploadedOssUrl(putResult.url, objectKey),
    fileName: path.basename(objectKey),
    mimeType,
    size: file.size,
  };
};

const uploadRemoteImageToRatingOss = async (
  owner: {
    userId: string;
    ratingEventId?: string | null;
    ratingUnitId?: string | null;
  },
  sourceUrl: string,
  usage: string | null
): Promise<{ url: string; objectKey: string } | null> => {
  if (!postMediaOssClient) return null;
  const trimmed = sourceUrl.trim();
  if (!trimmed) return null;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);

  try {
    const response = await fetch(trimmed, {
      method: 'GET',
      signal: controller.signal,
      headers: {
        Accept: 'image/*',
      },
    });
    if (!response.ok) return null;

    const mimeType = (response.headers.get('content-type') || 'image/jpeg').toLowerCase();
    if (!mimeType.startsWith('image/')) return null;

    const buffer = Buffer.from(await response.arrayBuffer());
    if (buffer.length === 0) return null;

    const objectKey = buildRatingMediaObjectKey(owner, path.basename(trimmed.split('?')[0] || 'image.jpg'), mimeType, usage);
    const putResult = await postMediaOssClient.put(objectKey, buffer, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });

    return {
      url: normalizeUploadedOssUrl(putResult.url, objectKey),
      objectKey,
    };
  } catch (_error) {
    return null;
  } finally {
    clearTimeout(timeout);
  }
};

const uploadDJMediaToOss = async (
  file: Express.Multer.File,
  djId: string,
  usage: 'avatar' | 'banner'
): Promise<{ url: string; fileName: string; mimeType: string; size: number }> => {
  if (!postMediaOssClient) {
    await fs.promises.unlink(file.path).catch(() => undefined);
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  const mimeType = file.mimetype || 'image/jpeg';
  const objectKey = buildDJMediaObjectKey(djId, file.originalname || file.filename || 'image.jpg', mimeType, usage);

  let putResult: { url?: string };
  try {
    putResult = await postMediaOssClient.put(objectKey, file.path, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }

  return {
    url: normalizeUploadedOssUrl(putResult.url, objectKey),
    fileName: path.basename(objectKey),
    mimeType,
    size: file.size,
  };
};

const uploadWikiBrandMediaToOss = async (
  file: Express.Multer.File,
  brandId: string | null,
  usage: string | null
): Promise<{ url: string; fileName: string; mimeType: string; size: number }> => {
  if (!postMediaOssClient) {
    await fs.promises.unlink(file.path).catch(() => undefined);
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  const mimeType = file.mimetype || 'image/jpeg';
  const objectKey = buildWikiBrandMediaObjectKey(brandId, file.originalname || file.filename || 'image.jpg', mimeType, usage);

  let putResult: { url?: string };
  try {
    putResult = await postMediaOssClient.put(objectKey, file.path, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }

  return {
    url: normalizeUploadedOssUrl(putResult.url, objectKey),
    fileName: path.basename(objectKey),
    mimeType,
    size: file.size,
  };
};

const buildLineupImportObjectKey = (fileName: string, mimeType: string): string => {
  const rawExt = path.extname(fileName || '').toLowerCase();
  const mimeExt = mimeType.includes('png')
    ? '.png'
    : mimeType.includes('webp')
      ? '.webp'
      : mimeType.includes('gif')
        ? '.gif'
        : '.jpg';
  const ext = rawExt && rawExt.length <= 10 ? rawExt : mimeExt;
  return `${ossEventsPrefix}/lineup-imports/${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const uploadLineupImportImageToOss = async (
  file: Express.Multer.File
): Promise<{ url: string; objectKey: string; mimeType: string }> => {
  if (!postMediaOssClient) {
    await fs.promises.unlink(file.path).catch(() => undefined);
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  const mimeType = file.mimetype || 'image/jpeg';
  const objectKey = buildLineupImportObjectKey(file.originalname || file.filename || 'lineup.jpg', mimeType);

  let putResult: { url?: string };
  try {
    putResult = await postMediaOssClient.put(objectKey, file.path, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=3600',
      },
    });
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }

  return {
    url: normalizeUploadedOssUrl(putResult.url, objectKey),
    objectKey,
    mimeType,
  };
};

type ImportedLineupItem = {
  id: string;
  musician: string;
  time: string | null;
  stage: string | null;
  date: string | null;
};

type SpotifyDJSearchItem = {
  spotifyId: string;
  name: string;
  uri: string;
  url: string | null;
  popularity: number;
  followers: number;
  genres: string[];
  imageUrl: string | null;
  existingDJId: string | null;
  existingDJName: string | null;
  existingMatchType: 'spotify_id' | 'name_case_insensitive' | null;
};

type DiscogsDJSearchItem = {
  artistId: number;
  name: string;
  thumbUrl: string | null;
  coverImageUrl: string | null;
  resourceUrl: string | null;
  uri: string | null;
  existingDJId: string | null;
  existingDJName: string | null;
  existingMatchType: 'name_case_insensitive' | null;
};

type SoundCloudDJSearchItem = {
  soundcloudid: string;
  soundcloudId: string;
  soundCloudId: string;
  name: string;
  username: string;
  avatarUrl: string | null;
  permalink: string | null;
  permalinkUrl: string | null;
  city: string | null;
  country: string | null;
  description: string | null;
  website: string | null;
  spotifyUrl: string | null;
  instagramUrl: string | null;
  facebookUrl: string | null;
  twitterUrl: string | null;
  youtubeUrl: string | null;
  track_count: number;
  playlist_count: number;
  followers_count: number;
  public_favorites_count: number;
  trackCount: number;
  playlistCount: number;
  followersCount: number;
  publicFavoritesCount: number;
  soundCloudFollowers: number;
  soundCloudFavorites: number;
  existingDJId: string | null;
  existingDJName: string | null;
  existingMatchType: 'name_case_insensitive' | null;
};

type DiscogsDJArtistDetailItem = {
  artistId: number;
  name: string;
  realName: string | null;
  profile: string | null;
  urls: string[];
  nameVariations: string[];
  aliases: string[];
  groups: string[];
  primaryImageUrl: string | null;
  thumbnailImageUrl: string | null;
  resourceUrl: string | null;
  uri: string | null;
  existingDJId: string | null;
  existingDJName: string | null;
  existingMatchType: 'name_case_insensitive' | null;
};

const isUnknownText = (value: string): boolean => {
  const normalized = value.trim().toLowerCase();
  if (!normalized) return true;
  return (
    normalized === 'unknown' ||
    normalized === 'unk' ||
    normalized === 'n/a' ||
    normalized === 'na' ||
    normalized === 'none' ||
    normalized === 'null' ||
    normalized === '-' ||
    normalized === '--' ||
    normalized === '未知'
  );
};

const sanitizeOptionalText = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!trimmed || isUnknownText(trimmed)) return null;
  return trimmed;
};

const pickFirstUrlByHosts = (
  urls: string[] | null | undefined,
  hostKeywords: string[]
): string | null => {
  if (!Array.isArray(urls) || urls.length === 0) return null;
  for (const raw of urls) {
    const trimmed = raw?.trim();
    if (!trimmed) continue;
    try {
      const parsed = new URL(trimmed);
      const host = parsed.hostname.toLowerCase();
      if (hostKeywords.some((keyword) => host.includes(keyword.toLowerCase()))) {
        return trimmed;
      }
    } catch (_error) {
      continue;
    }
  }
  return null;
};

const safeParseJson = (text: string): unknown | null => {
  try {
    return JSON.parse(text);
  } catch (_error) {
    return null;
  }
};

const extractFirstJSONObjectText = (input: string): string | null => {
  let depth = 0;
  let start = -1;
  let inString = false;
  let escaped = false;

  for (let i = 0; i < input.length; i += 1) {
    const ch = input[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch === '\\') {
        escaped = true;
      } else if (ch === '"') {
        inString = false;
      }
      continue;
    }
    if (ch === '"') {
      inString = true;
      continue;
    }
    if (ch === '{') {
      if (depth === 0) start = i;
      depth += 1;
      continue;
    }
    if (ch === '}') {
      if (depth > 0) depth -= 1;
      if (depth === 0 && start >= 0) {
        return input.slice(start, i + 1);
      }
    }
  }
  return null;
};

const tryParseJsonFromText = (rawText: string): unknown | null => {
  const direct = safeParseJson(rawText);
  if (direct !== null) return direct;
  const extracted = extractFirstJSONObjectText(rawText);
  if (!extracted) return null;
  return safeParseJson(extracted);
};

const extractLineupInfo = (value: unknown): Array<Record<string, unknown>> => {
  const seen = new WeakSet<object>();

  const walk = (node: unknown): Array<Record<string, unknown>> | null => {
    if (Array.isArray(node)) {
      for (const item of node) {
        const nested = walk(item);
        if (nested && nested.length > 0) return nested;
      }
      return null;
    }

    if (typeof node === 'string') {
      const parsed = tryParseJsonFromText(node);
      if (parsed !== null) return walk(parsed);
      return null;
    }

    if (!node || typeof node !== 'object') return null;
    if (seen.has(node)) return null;
    seen.add(node);

    const record = node as Record<string, unknown>;
    if (Array.isArray(record.lineup_info)) {
      return record.lineup_info.filter((item): item is Record<string, unknown> => typeof item === 'object' && item !== null);
    }

    for (const value of Object.values(record)) {
      const nested = walk(value);
      if (nested && nested.length > 0) return nested;
    }
    return null;
  };

  return walk(value) ?? [];
};

const extractFormattedOutputText = (value: unknown): string | null => {
  const seen = new WeakSet<object>();

  const walk = (node: unknown): string | null => {
    if (typeof node === 'string') {
      const trimmed = node.trim();
      return trimmed ? trimmed : null;
    }
    if (Array.isArray(node)) {
      for (const item of node) {
        const found = walk(item);
        if (found) return found;
      }
      return null;
    }
    if (!node || typeof node !== 'object') return null;
    if (seen.has(node)) return null;
    seen.add(node);

    const record = node as Record<string, unknown>;
    const direct = record.formatted_output ?? record.formattedOutput ?? record.output ?? null;
    if (typeof direct === 'string' && direct.trim()) {
      return direct.trim();
    }

    for (const child of Object.values(record)) {
      const found = walk(child);
      if (found) return found;
    }
    return null;
  };

  return walk(value);
};

const normalizeTimeText = (value: string): string =>
  value
    .replace(/：/g, ':')
    .replace(/[—–]/g, '-')
    .trim();

const isLikelyTimeRange = (value: string): boolean =>
  /^\s*\d{1,2}:[0-5]\d\s*-\s*\d{1,2}:[0-5]\d\s*$/i.test(normalizeTimeText(value));

const isLikelySingleTime = (value: string): boolean =>
  /^\s*\d{1,2}:[0-5]\d\s*$/i.test(normalizeTimeText(value));

const isLikelyTimeValue = (value: string): boolean => {
  const normalized = normalizeTimeText(value).toLowerCase();
  return isLikelyTimeRange(normalized) || isLikelySingleTime(normalized) || normalized === 'open';
};

const isLikelyDateValue = (value: string): boolean => {
  const trimmed = value.trim();
  if (!trimmed) return false;
  if (/^\s*day\s*\d{1,2}\s*$/i.test(trimmed)) return true;
  if (/^\s*\d{4}[/-]\d{1,2}[/-]\d{1,2}\s*$/i.test(trimmed)) return true;
  if (/^\s*\d{1,2}\s*[A-Za-z]{3,}\.?\s*$/i.test(trimmed)) return true; // 31 DEC.
  if (/^\s*[A-Za-z]{3,}\.?\s*\d{1,2}\s*$/i.test(trimmed)) return true; // Nov.2
  return false;
};

const normalizeFormattedSegment = (value: string): string => {
  let cleaned = value.trim();
  cleaned = cleaned.replace(/^[\[{(]+/, '').replace(/[\]})]+$/, '').trim();
  cleaned = cleaned.replace(
    /^(?:"?(musician|artist|name|date|time|stage)"?)\s*[:：]\s*/i,
    ''
  );
  cleaned = cleaned.replace(/^"(.*)"$/, '$1').replace(/^'(.*)'$/, '$1');
  return cleaned.trim();
};

const parseFormattedOutputToItems = (text: string): ImportedLineupItem[] => {
  const lines = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  return lines
    .map((line, index) => {
      const segments = line
        .split(/[，,]/)
        .map((item) => normalizeFormattedSegment(item))
        .filter(Boolean);
      if (segments.length === 0) return null;

      const musician = sanitizeOptionalText(segments[0]);
      if (!musician) return null;

      let time: string | null = null;
      let stage: string | null = null;
      let date: string | null = null;
      const rest = segments.slice(1);
      const consumed = new Set<number>();

      for (let i = 0; i < rest.length; i += 1) {
        if (time === null && isLikelyTimeValue(rest[i])) {
          time = sanitizeOptionalText(rest[i]);
          consumed.add(i);
          continue;
        }
        if (date === null && isLikelyDateValue(rest[i])) {
          date = sanitizeOptionalText(rest[i]);
          consumed.add(i);
          continue;
        }
      }

      for (let i = 0; i < rest.length; i += 1) {
        if (consumed.has(i)) continue;
        const candidate = sanitizeOptionalText(rest[i]);
        if (!candidate) continue;
        if (time === null && isLikelyTimeValue(candidate)) {
          time = candidate;
          continue;
        }
        if (date === null && isLikelyDateValue(candidate)) {
          date = candidate;
          continue;
        }
        if (stage === null) {
          stage = candidate;
        }
      }

      return {
        id: `ocr-text-${index}-${Math.random().toString(36).slice(2, 8)}`,
        musician,
        time,
        stage,
        date,
      } satisfies ImportedLineupItem;
    })
    .filter((item): item is ImportedLineupItem => item !== null);
};

const normalizeImportedLineupItems = (items: Array<Record<string, unknown>>): ImportedLineupItem[] =>
  items
    .map((item, index) => {
      const musician = sanitizeOptionalText(item.musician ?? item.name ?? item.artist ?? item.djName);
      if (!musician) return null;
      return {
        id: `ocr-${index}-${Math.random().toString(36).slice(2, 8)}`,
        musician,
        time: sanitizeOptionalText(item.time ?? item.time_range ?? item.timeRange ?? item.slot),
        stage: sanitizeOptionalText(item.stage ?? item.stage_name ?? item.stageName),
        date: sanitizeOptionalText(item.date ?? item.day ?? item.performDate),
      } as ImportedLineupItem;
    })
    .filter((item): item is ImportedLineupItem => item !== null);

const resolveCozeFileType = (value: string): 'image' | 'video' | 'audio' | 'document' | 'default' => {
  const normalized = value.trim().toLowerCase();
  if (!normalized) return 'default';
  if (normalized === 'image' || normalized.startsWith('image/')) return 'image';
  if (normalized === 'video' || normalized.startsWith('video/')) return 'video';
  if (normalized === 'audio' || normalized.startsWith('audio/')) return 'audio';
  if (normalized === 'document' || normalized.startsWith('application/')) return 'document';
  return 'default';
};

const runCozeLineupWorker = async (
  imageUrl: string,
  fileType: string
): Promise<{ normalizedText: string; lineupInfo: ImportedLineupItem[] }> => {
  if (!cozeWorkflowToken) {
    throw new Error('COZE_WORKFLOW_TOKEN is not configured');
  }

  const payload = {
    [cozeWorkflowImageField]: {
      url: imageUrl,
      file_type: resolveCozeFileType(fileType),
    },
  };

  const startedAt = Date.now();
  console.info('[coze-lineup] run.start', {
    runUrl: cozeWorkflowRunUrl,
    imageUrl,
    fileType,
    timeoutMs: cozeWorkflowTimeoutMs,
  });
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), cozeWorkflowTimeoutMs);
  let rawText = '';
  try {
    const response = await fetch(cozeWorkflowRunUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cozeWorkflowToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    rawText = await response.text();
    console.info('[coze-lineup] run.response', {
      status: response.status,
      durationMs: Date.now() - startedAt,
      responseLength: rawText.length,
    });
    if (!response.ok) {
      throw new Error(`Coze workflow request failed (${response.status}): ${rawText.slice(0, 500)}`);
    }
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error(`COZE_WORKFLOW_TIMEOUT after ${cozeWorkflowTimeoutMs}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }

  const parsed = tryParseJsonFromText(rawText);
  if (parsed === null) {
    throw new Error('Coze workflow returned non-JSON content');
  }

  const lineupRaw = extractLineupInfo(parsed);
  let lineupInfo = normalizeImportedLineupItems(lineupRaw);
  if (lineupInfo.length === 0) {
    const formattedOutput = extractFormattedOutputText(parsed);
    if (formattedOutput) {
      lineupInfo = parseFormattedOutputToItems(formattedOutput);
    }
  }
  console.info('[coze-lineup] run.parsed', {
    durationMs: Date.now() - startedAt,
    lineupCount: lineupInfo.length,
  });

  return {
    normalizedText: JSON.stringify(
      {
        lineup_info: lineupInfo.map((item) => ({
          musician: item.musician,
          time: item.time ?? '未知',
          stage: item.stage ?? '未知',
          date: item.date ?? '未知',
        })),
      },
      null,
      2
    ),
    lineupInfo,
  };
};

const extraOssImageHostSuffixes = (process.env.RAVER_OSS_IMAGE_HOSTS || process.env.OSS_IMAGE_HOSTS || '')
  .split(',')
  .map((item) => item.trim().toLowerCase())
  .filter(Boolean);

const isLikelyAliyunOssHost = (host: string): boolean => {
  const normalized = host.trim().toLowerCase();
  if (!normalized) return false;
  if (normalized === 'aliyuncs.com' || normalized.endsWith('.aliyuncs.com')) {
    return true;
  }
  return extraOssImageHostSuffixes.some((suffix) => normalized === suffix || normalized.endsWith(`.${suffix}`));
};

const buildOssAvatarVariantUrl = (
  rawUrl: string | null | undefined,
  size: 'small' | 'medium' | 'original'
): string | null => {
  const normalized = typeof rawUrl === 'string' ? rawUrl.trim() : '';
  if (!normalized) return null;
  if (size === 'original') return normalized;

  let parsed: URL;
  try {
    parsed = new URL(normalized);
  } catch {
    return normalized;
  }

  const pathLooksLikeDJMedia = parsed.pathname.toLowerCase().includes('/djs/');
  if (!isLikelyAliyunOssHost(parsed.hostname) && !pathLooksLikeDJMedia) {
    return normalized;
  }

  const process = size === 'small'
    ? 'image/resize,m_fill,w_160,h_160/quality,q_82/format,webp'
    : 'image/resize,m_fill,w_480,h_480/quality,q_88/format,webp';
  parsed.searchParams.set('x-oss-process', process);
  return parsed.toString();
};

const mapDJ = (
  row: any,
  isFollowing = false,
  viewerId: string | null | undefined = null,
  viewerRole: string | null | undefined = null
) => {
  const resolvedAvatarUrl =
    typeof row.avatarUrl === 'string' && row.avatarUrl.trim().length > 0
      ? row.avatarUrl.trim()
      : null;
  const nameI18n = resolveBiTextWithFallback(row.nameI18n ?? null, row.name ?? '');
  const bioI18n = row.bio
    ? resolveBiTextWithFallback(row.bioI18n ?? null, row.bio ?? '')
    : (row.bioI18n ? resolveBiTextWithFallback(row.bioI18n, '') : null);
  const countryI18n = row.country
    ? resolveBiTextWithFallback(row.countryI18n ?? null, row.country ?? '')
    : (row.countryI18n ? resolveBiTextWithFallback(row.countryI18n, '') : null);
  const contributorInfo = contributorInfoFromRow(row);
  const statsInfo = statsInfoFromRow(row);
  const contributorUsernames = contributorInfo.usernames;
  const contributors = contributorInfo.users.map((user) => mapUserLite(user));
  const uploadedByUsername = contributorInfo.uploadedByUsername;
  const isContributor = isDJContributorByRow(row, viewerId);
  const canEdit = viewerRole === 'admin' || isContributor;
  const eventCount = Math.max(
    Number(row.eventCount ?? 0),
    Number(row.eventsCount ?? 0),
    Number(row.upcomingShows ?? 0),
    Number(row.sourceLineupEventCount ?? 0),
    Number(row.sourceUpcomingShows ?? 0),
    Number(statsInfo.eventCount ?? 0)
  );
  const setCount = Math.max(
    Number(row.setCount ?? 0),
    Number(row.setsCount ?? 0),
    Number(row.djSetCount ?? 0),
    Number(statsInfo.setCount ?? 0)
  );

  return {
    id: row.id,
    name: row.name,
    nameI18n: nameI18n ?? null,
    aliases: Array.isArray(row.aliases) ? row.aliases : [],
    genres: Array.isArray(row.genres) ? row.genres : [],
    slug: row.slug,
    bio: row.bio,
    bioI18n: bioI18n ?? null,
    avatarUrl: resolvedAvatarUrl,
    avatarOriginalUrl: resolvedAvatarUrl,
    avatarMediumUrl: buildOssAvatarVariantUrl(resolvedAvatarUrl, 'medium'),
    avatarSmallUrl: buildOssAvatarVariantUrl(resolvedAvatarUrl, 'small'),
    avatarSourceUrl: row.avatarSourceUrl ?? null,
    bannerUrl: row.bannerUrl,
    country: row.country,
    countryI18n: countryI18n ?? null,
    spotifyId: row.spotifyId,
    spotifyFollowers: row.spotifyFollowers ?? null,
    appleMusicId: row.appleMusicId,
    soundcloudUrl: row.soundcloudUrl,
    soundcloudId: row.soundcloudId ?? null,
    soundCloudId: row.soundcloudId ?? null,
    website: row.website ?? null,
    trackCount: row.trackCount ?? null,
    playlistCount: row.playlistCount ?? null,
    soundCloudFollowers: row.soundCloudFollowers ?? null,
    soundCloudFavorites: row.soundCloudFavorites ?? null,
    instagramUrl: row.instagramUrl,
    facebookUrl: row.facebookUrl,
    twitterUrl: row.twitterUrl,
    youtubeUrl: row.youtubeUrl ?? null,
    isVerified: row.isVerified,
    followerCount: row.followerCount,
    eventCount,
    eventsCount: eventCount,
    upcomingShows: eventCount,
    setCount,
    setsCount: setCount,
    djSetCount: setCount,
    sourceDataSource: row.sourceDataSource ?? null,
    contributors,
    contributorUsernames,
    uploadedByUsername,
    isContributor,
    canEdit,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    isFollowing,
  };
};

const mapUserLite = (row: any) => {
  if (!row) return null;
  return {
    id: row.id,
    username: row.username,
    displayName: row.displayName || row.username,
    avatarUrl: row.avatarUrl || null,
  };
};

type WikiFestivalLinkPayload = {
  title: string;
  icon: string;
  url: string;
};

const normalizeWikiFestivalText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const normalizeWikiFestivalInteger = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  return Math.trunc(parsed);
};

const normalizeWikiFestivalBiText = (value: unknown, fallback = ''): EventBiTextPayload | null =>
  normalizeEventBiText(value, fallback);

const pickWikiFestivalPrimaryText = (value: EventBiTextPayload | null, fallback = ''): string => {
  const zh = normalizeWikiFestivalText(value?.zh);
  const en = normalizeWikiFestivalText(value?.en);
  const fallbackText = normalizeWikiFestivalText(fallback);
  return zh || en || fallbackText;
};

const parseWikiFestivalLinks = (value: unknown): WikiFestivalLinkPayload[] => {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (typeof item !== 'object' || item === null) return null;
      const title = normalizeWikiFestivalText((item as Record<string, unknown>).title);
      const icon = normalizeWikiFestivalText((item as Record<string, unknown>).icon);
      const url = normalizeWikiFestivalText((item as Record<string, unknown>).url);
      if (!title || !url) return null;
      return {
        title,
        icon: icon || 'link',
        url,
      } as WikiFestivalLinkPayload;
    })
    .filter((item): item is WikiFestivalLinkPayload => item !== null);
};

const mergeWikiFestivalLinks = (
  baseLinks: WikiFestivalLinkPayload[],
  fields: {
    officialWebsite?: string | null;
    facebookUrl?: string | null;
    instagramUrl?: string | null;
    twitterUrl?: string | null;
    youtubeUrl?: string | null;
    tiktokUrl?: string | null;
  }
): WikiFestivalLinkPayload[] => {
  const merged: WikiFestivalLinkPayload[] = Array.isArray(baseLinks) ? [...baseLinks] : [];
  const seen = new Set(
    merged
      .map((item) => normalizeWikiFestivalText(item.url).toLowerCase())
      .filter((item) => item.length > 0)
  );

  const push = (title: string, icon: string, url: string | null | undefined): void => {
    const normalizedUrl = normalizeWikiFestivalText(url);
    if (!normalizedUrl) return;
    const key = normalizedUrl.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    merged.push({ title, icon, url: normalizedUrl });
  };

  push('Official', 'globe', fields.officialWebsite);
  push('Facebook', 'f.square', fields.facebookUrl);
  push('Instagram', 'camera', fields.instagramUrl);
  push('X / Twitter', 'bird', fields.twitterUrl);
  push('YouTube', 'play.rectangle', fields.youtubeUrl);
  push('TikTok', 'music.note', fields.tiktokUrl);
  return merged;
};

const parseWikiFestivalAliases = (value: unknown): string[] => {
  if (Array.isArray(value)) {
    return value
      .map((item) => normalizeWikiFestivalText(item))
      .filter((item) => item.length > 0);
  }
  if (typeof value === 'string') {
    return value
      .split(/[,\uFF0C\/\u3001]/g)
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
  }
  return [];
};

const uniqueWikiFestivalIdForName = async (name: string): Promise<string> => {
  const base = slugify(name) || `festival-${Date.now()}`;
  let candidate = base;
  let seq = 1;

  while (true) {
    const exists = await prisma.wikiFestival.findUnique({
      where: { id: candidate },
      select: { id: true },
    });
    if (!exists) {
      return candidate;
    }
    seq += 1;
    candidate = `${base}-${seq}`;
  }
};

const mapWikiFestival = (
  row: any,
  viewerId: string | null | undefined = null,
  viewerRole: string | null | undefined = null
) => {
  const contributors = Array.isArray(row?.contributors)
    ? row.contributors
        .map((item: any) => mapUserLite(item?.user ?? item))
        .filter((item: ReturnType<typeof mapUserLite>): item is NonNullable<ReturnType<typeof mapUserLite>> => Boolean(item))
    : [];
  const nameI18n = resolveBiTextWithFallback(row?.nameI18n ?? null, row?.name ?? '');
  const descriptionI18n = resolveBiTextWithFallback(row?.descriptionI18n ?? null, row?.introduction ?? '');
  const cityI18n = resolveBiTextWithFallback(row?.cityI18n ?? null, row?.city ?? '');
  const countryI18n = resolveBiTextWithFallback(row?.countryI18n ?? null, row?.country ?? '');
  const frequencyI18n = resolveBiTextWithFallback(row?.frequencyI18n ?? null, row?.frequency ?? '');
  const links = mergeWikiFestivalLinks(parseWikiFestivalLinks(row?.links), {
    officialWebsite: row?.officialWebsite ?? null,
    facebookUrl: row?.facebookUrl ?? null,
    instagramUrl: row?.instagramUrl ?? null,
    twitterUrl: row?.twitterUrl ?? null,
    youtubeUrl: row?.youtubeUrl ?? null,
    tiktokUrl: row?.tiktokUrl ?? null,
  });
  const isContributor = !!viewerId && contributors.some((user: any) => user.id === viewerId);
  const canEdit = viewerRole === 'admin' || isContributor;

  return {
    id: row.id,
    name: row.name,
    nameI18n: nameI18n ?? null,
    sourceRowId: row.sourceRowId ?? null,
    abbreviation: row.abbreviation ?? null,
    aliases: Array.isArray(row.aliases) ? row.aliases : [],
    country: row.country,
    countryI18n: countryI18n ?? null,
    city: row.city,
    cityI18n: cityI18n ?? null,
    foundedYear: row.foundedYear,
    frequency: row.frequency,
    frequencyI18n: frequencyI18n ?? null,
    tagline: row.tagline,
    introduction: row.introduction,
    descriptionI18n: descriptionI18n ?? null,
    officialWebsite: row.officialWebsite ?? null,
    facebookUrl: row.facebookUrl ?? null,
    instagramUrl: row.instagramUrl ?? null,
    twitterUrl: row.twitterUrl ?? null,
    youtubeUrl: row.youtubeUrl ?? null,
    tiktokUrl: row.tiktokUrl ?? null,
    avatarUrl: row.avatarUrl ?? null,
    backgroundUrl: row.backgroundUrl ?? null,
    links,
    contributors,
    canEdit,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
};

const mapEvent = (row: any) => ({
  id: row.id,
  name: row.name,
  nameI18n: row.nameI18n ?? null,
  wikiFestivalId: row.wikiFestivalId ?? null,
  slug: row.slug,
  archiveFestivalId: row.archiveFestivalId ?? null,
  description: row.description,
  descriptionI18n: row.descriptionI18n ?? null,
  locationI18n: row.locationI18n ?? null,
  countryI18n: row.countryI18n ?? null,
  coverImageUrl: row.coverImageUrl,
  lineupImageUrl: row.lineupImageUrl,
  imageAssets: row.imageAssets ?? null,
  referenceLinks: Array.isArray(row.referenceLinks) ? row.referenceLinks : [],
  socialLinks: row.socialLinks ?? null,
  sourceProvider: row.sourceProvider ?? null,
  sourceEventUrl: row.sourceEventUrl ?? null,
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
  dayRolloverHour: row.dayRolloverHour ?? 6,
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
  wikiFestival: row.wikiFestival
    ? {
        id: row.wikiFestival.id,
        name: row.wikiFestival.name,
        nameI18n: row.wikiFestival.nameI18n ?? null,
        country: row.wikiFestival.country,
        countryI18n: row.wikiFestival.countryI18n ?? null,
        city: row.wikiFestival.city,
        cityI18n: row.wikiFestival.cityI18n ?? null,
        avatarUrl: row.wikiFestival.avatarUrl ?? null,
        backgroundUrl: row.wikiFestival.backgroundUrl ?? null,
      }
    : null,
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
        djIds: Array.isArray(slot.djIds) ? slot.djIds : (slot.djId ? [slot.djId] : []),
        djName: slot.djName,
        festivalDayIndex: typeof slot.festivalDayIndex === 'number' ? slot.festivalDayIndex : null,
        stageName: slot.stageName,
        sortOrder: slot.sortOrder,
        startTime: slot.startTime,
        endTime: slot.endTime,
        dj: slot.dj
          ? {
              id: slot.dj.id,
              name: slot.dj.name,
              avatarUrl: slot.dj.avatarUrl,
              avatarOriginalUrl: buildOssAvatarVariantUrl(slot.dj.avatarUrl, 'original'),
              avatarMediumUrl: buildOssAvatarVariantUrl(slot.dj.avatarUrl, 'medium'),
              avatarSmallUrl: buildOssAvatarVariantUrl(slot.dj.avatarUrl, 'small'),
              bannerUrl: slot.dj.bannerUrl,
              country: slot.dj.country,
              soundCloudFollowers: slot.dj.soundCloudFollowers ?? null,
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
        avatarOriginalUrl: buildOssAvatarVariantUrl(row.dj.avatarUrl, 'original'),
        avatarMediumUrl: buildOssAvatarVariantUrl(row.dj.avatarUrl, 'medium'),
        avatarSmallUrl: buildOssAvatarVariantUrl(row.dj.avatarUrl, 'small'),
        bannerUrl: row.dj.bannerUrl,
        country: row.dj.country,
      }
    : null,
  lineupDjs: Array.isArray(row.lineupDjs)
    ? row.lineupDjs.map((dj: any) => ({
        id: dj.id,
        name: dj.name,
        avatarUrl: dj.avatarUrl,
        avatarOriginalUrl: buildOssAvatarVariantUrl(dj.avatarUrl, 'original'),
        avatarMediumUrl: buildOssAvatarVariantUrl(dj.avatarUrl, 'medium'),
        avatarSmallUrl: buildOssAvatarVariantUrl(dj.avatarUrl, 'small'),
      }))
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
    linkedDJs: Array.isArray(row.linkedDJs)
      ? row.linkedDJs.map((dj: any) => ({
          id: dj.id,
          name: dj.name,
          avatarUrl: dj.avatarUrl || null,
          bannerUrl: dj.bannerUrl || null,
          country: dj.country || null,
        }))
      : [],
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    rating: summary.rating,
    ratingCount: summary.ratingCount,
    comments: includeComments && Array.isArray(row.comments) ? row.comments.map(mapRatingComment) : [],
    event: row.event
      ? {
          id: row.event.id,
          name: row.event.name,
          description: row.event.description ?? null,
          imageUrl: row.event.imageUrl ?? null,
        }
      : undefined,
    createdBy: mapUserLite(row.createdBy),
  };
};

const mapRatingEvent = (row: any) => ({
  id: row.id,
  name: row.name,
  description: row.description,
  imageUrl: row.imageUrl,
  sourceEventId: row.sourceEventId ?? null,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  createdBy: mapUserLite(row.createdBy),
  units: Array.isArray(row.units) ? row.units.map((unit: any) => mapRatingUnit(unit)) : [],
});

const parseActPerformerNames = (rawName: string): string[] => {
  const trimmed = rawName.trim();
  if (!trimmed) return [];
  const separated = trimmed
    .replace(/\s*[bB]\s*[23]\s*[bB]\s*/g, '|')
    .split('|')
    .map((item) => item.trim())
    .filter(Boolean);
  return separated.length > 0 ? separated : [trimmed];
};

const resolveSourceEventIdForRatingEvent = async (row: any): Promise<string | null> => {
  const explicitSourceEventId = typeof row?.sourceEventId === 'string' ? row.sourceEventId.trim() : '';
  if (explicitSourceEventId) {
    return explicitSourceEventId;
  }

  const ratingEventName = typeof row?.name === 'string' ? row.name.trim() : '';
  if (!ratingEventName) {
    return null;
  }

  const ratingUnitNameKeys = new Set<string>(
    (Array.isArray(row?.units) ? row.units : [])
      .map((unit: any) => normalizeTextKey(typeof unit?.name === 'string' ? unit.name : ''))
      .filter((name: string) => name.length > 0)
  );

  const candidateEvents = await prisma.event.findMany({
    where: {
      name: {
        equals: ratingEventName,
        mode: 'insensitive',
      },
    },
    select: {
      id: true,
      lineupSlots: {
        select: { djName: true },
      },
    },
    take: 20,
  });

  if (candidateEvents.length === 0) {
    return null;
  }

  if (ratingUnitNameKeys.size === 0) {
    return candidateEvents[0]?.id ?? null;
  }

  let bestMatchedEventId: string | null = null;
  let bestMatchedScore = 0;

  for (const candidate of candidateEvents) {
    const lineupNameKeys = new Set<string>(
      candidate.lineupSlots
        .map((slot) => normalizeTextKey(slot.djName))
        .filter((name: string) => name.length > 0)
    );
    let overlap = 0;
    for (const unitNameKey of ratingUnitNameKeys) {
      if (lineupNameKeys.has(unitNameKey)) {
        overlap += 1;
      }
    }
    if (overlap > bestMatchedScore) {
      bestMatchedScore = overlap;
      bestMatchedEventId = candidate.id;
    }
  }

  if (bestMatchedEventId) {
    return bestMatchedEventId;
  }

  return candidateEvents.length === 1 ? candidateEvents[0].id : null;
};

const formatHourMinute = (value: Date): string => {
  const hours = String(value.getHours()).padStart(2, '0');
  const minutes = String(value.getMinutes()).padStart(2, '0');
  return `${hours}:${minutes}`;
};

const buildRatingUnitDescriptionFromLineupSlot = (slot: {
  stageName?: string | null;
  startTime: Date;
  endTime: Date;
}): string => {
  const stageName = typeof slot.stageName === 'string' ? slot.stageName.trim() : '';
  const timeRange = `${formatHourMinute(slot.startTime)}-${formatHourMinute(slot.endTime)}`;
  return stageName ? `${stageName} · ${timeRange}` : timeRange;
};

const normalizeTextKey = (value: string): string =>
  value.trim().toLowerCase();

const attachLinkedDJsToRatingUnits = async (units: any[]): Promise<any[]> => {
  if (!Array.isArray(units) || units.length === 0) return [];

  const namesByUnitId = new Map<string, string[]>();
  const allPerformerNameKeys = new Set<string>();

  for (const unit of units) {
    const actNames = parseActPerformerNames(typeof unit?.name === 'string' ? unit.name : '');
    const normalizedNames = actNames.map(normalizeTextKey).filter(Boolean);
    namesByUnitId.set(unit.id, normalizedNames);
    for (const key of normalizedNames) {
      allPerformerNameKeys.add(key);
    }
  }

  const performerNames = Array.from(allPerformerNameKeys);
  if (performerNames.length === 0) {
    return units.map((unit) => ({ ...unit, linkedDJs: [] }));
  }

  const matchedDJs = await prisma.dJ.findMany({
    where: {
      OR: performerNames.map((name) => ({
        name: {
          equals: name,
          mode: 'insensitive',
        },
      })),
    },
    select: {
      id: true,
      name: true,
      avatarUrl: true,
      bannerUrl: true,
      country: true,
    },
  });

  const djByNormalizedName = new Map<string, any>();
  for (const dj of matchedDJs) {
    djByNormalizedName.set(normalizeTextKey(dj.name), dj);
  }

  return units.map((unit) => {
    const names = namesByUnitId.get(unit.id) || [];
    const linkedDJs = names
      .map((name) => djByNormalizedName.get(name))
      .filter(Boolean);
    return {
      ...unit,
      linkedDJs,
    };
  });
};

type RankingEntityType = 'dj' | 'festival';

type RankingBoardRecord = {
  id: string;
  title: string;
  subtitle: string;
  description: string;
  coverImageUrl: string | null;
  entityType: RankingEntityType;
  years: number[];
  createdAt: string;
  updatedAt: string;
};

type RankingEntryRecord = {
  rank: number;
  name: string;
  entityId?: string | null;
};

type RankingYearFile = {
  boardId: string;
  year: number;
  source?: string;
  updatedAt: string;
  entries: RankingEntryRecord[];
};

const LEGACY_RANKING_BOARDS: Record<
  string,
  {
    title: string;
    subtitle: string;
    years: number[];
    coverImageUrl?: string;
    entityType: RankingEntityType;
  }
> = {
  djmag: {
    title: 'DJ MAG TOP 100',
    subtitle: '全球电子音乐最有影响力榜单之一',
    years: [2022, 2023, 2024, 2025],
    entityType: 'dj',
  },
  dongye: {
    title: '东野 DJ 榜',
    subtitle: '中文圈 DJ 热度与影响力榜单',
    years: [2024, 2025],
    entityType: 'dj',
  },
  djmag_festival: {
    title: 'DJ MAG TOP 100 Festivals',
    subtitle: '全球电音节品牌百大榜单',
    years: [2025],
    entityType: 'festival',
  },
};

const rankingRootCandidates = [
  path.join(process.cwd(), '..', 'web', 'public', 'rankings'),
  path.join(process.cwd(), 'web', 'public', 'rankings'),
];

const rankingBoardManifestFile = '_boards.json';

const sanitizeRankingBoardId = (value: string): string => {
  const normalized = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/^_+|_+$/g, '');
  return normalized || `ranking-${Date.now()}`;
};

const resolveRankingRootDir = (): string => {
  for (const dir of rankingRootCandidates) {
    if (fs.existsSync(dir)) return dir;
  }
  const fallback = rankingRootCandidates[0];
  fs.mkdirSync(fallback, { recursive: true });
  return fallback;
};

const rankingBoardManifestPath = (): string =>
  path.join(resolveRankingRootDir(), rankingBoardManifestFile);

const rankingBoardDirPath = (boardId: string): string =>
  path.join(resolveRankingRootDir(), sanitizeRankingBoardId(boardId));

const rankingYearJsonPath = (boardId: string, year: number): string =>
  path.join(rankingBoardDirPath(boardId), `${year}.json`);

const rankingYearTxtPath = (boardId: string, year: number): string =>
  path.join(rankingBoardDirPath(boardId), `${year}.txt`);

const rankingYearPathLegacy = (boardId: string, year: number): string | null => {
  const candidates = [
    rankingYearTxtPath(boardId, year),
    ...rankingRootCandidates.map((root) => path.join(root, sanitizeRankingBoardId(boardId), `${year}.txt`)),
  ];
  for (const filePath of candidates) {
    if (fs.existsSync(filePath)) return filePath;
  }
  return null;
};

const normalizeRankingYears = (value: unknown): number[] => {
  if (!Array.isArray(value)) return [];
  return Array.from(
    new Set(
      value
        .map((item) => Number(item))
        .filter((item) => Number.isFinite(item))
        .map((item) => Math.max(1900, Math.min(2200, Math.floor(item))))
    )
  ).sort((a, b) => a - b);
};

const normalizeRankingBoard = (input: unknown, fallbackId = ''): RankingBoardRecord | null => {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return null;
  const row = input as Record<string, unknown>;
  const id = sanitizeRankingBoardId(String(row.id || fallbackId || ''));
  const title = String(row.title || '').trim() || id;
  const subtitle = String(row.subtitle || '').trim();
  const description = String(row.description || '').trim();
  const entityType: RankingEntityType = String(row.entityType || '').trim() === 'festival' ? 'festival' : 'dj';
  const coverImageUrlRaw = String(row.coverImageUrl || '').trim();
  const coverImageUrl = coverImageUrlRaw || null;
  const years = normalizeRankingYears(row.years);
  const nowIso = new Date().toISOString();
  const createdAt = String(row.createdAt || '').trim() || nowIso;
  const updatedAt = String(row.updatedAt || '').trim() || nowIso;
  return {
    id,
    title,
    subtitle,
    description,
    coverImageUrl,
    entityType,
    years,
    createdAt,
    updatedAt,
  };
};

const collectRankingBoardYearsFromFiles = (boardId: string): number[] => {
  const dirPath = rankingBoardDirPath(boardId);
  if (!fs.existsSync(dirPath)) return [];
  const yearSet = new Set<number>();
  for (const file of fs.readdirSync(dirPath)) {
    const match = file.match(/^(\d{4})\.(json|txt)$/i);
    if (!match) continue;
    const year = Number(match[1]);
    if (Number.isFinite(year)) yearSet.add(year);
  }
  return Array.from(yearSet).sort((a, b) => a - b);
};

const rankingEntriesToText = (entries: RankingEntryRecord[]): string =>
  entries
    .slice()
    .sort((a, b) => a.rank - b.rank)
    .map((item) => `${item.rank}. ${item.name}`)
    .join('\n');

const parseRankingEntries = (value: unknown): RankingEntryRecord[] => {
  if (!Array.isArray(value)) return [];
  const rows = value
    .map((item) => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
      const row = item as Record<string, unknown>;
      const rank = Number(row.rank);
      const name = String(row.name || '').trim();
      if (!Number.isFinite(rank) || rank <= 0 || !name) return null;
      const entityIdRaw = String(row.entityId || '').trim();
      const entityId = entityIdRaw.length > 0 ? entityIdRaw : null;
      return {
        rank: Math.floor(rank),
        name,
        ...(entityId ? { entityId } : {}),
      } as RankingEntryRecord;
    })
    .filter((item): item is RankingEntryRecord => item !== null);

  const deduped = new Map<number, RankingEntryRecord>();
  for (const item of rows) {
    deduped.set(item.rank, item);
  }
  return Array.from(deduped.values()).sort((a, b) => a.rank - b.rank);
};

const loadRankingBoards = (): RankingBoardRecord[] => {
  const manifestPath = rankingBoardManifestPath();
  let boards = Array.from(Object.entries(LEGACY_RANKING_BOARDS)).map(([id, board]) => ({
    id,
    title: board.title,
    subtitle: board.subtitle,
    description: '',
    coverImageUrl: board.coverImageUrl || null,
    entityType: board.entityType,
    years: board.years.slice().sort((a, b) => a - b),
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  })) as RankingBoardRecord[];

  if (fs.existsSync(manifestPath)) {
    try {
      const payload = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
      const rows = Array.isArray(payload?.boards) ? payload.boards : [];
      const normalizedRows = rows
        .map((item: unknown) => normalizeRankingBoard(item))
        .filter((item: RankingBoardRecord | null): item is RankingBoardRecord => item !== null);
      if (normalizedRows.length > 0) {
        boards = normalizedRows;
      }
    } catch (_error) {
      // Keep legacy fallback when manifest is corrupted.
    }
  }

  const dedupedById = new Map<string, RankingBoardRecord>();
  for (const board of boards) {
    const fileYears = collectRankingBoardYearsFromFiles(board.id);
    const years = Array.from(new Set([...board.years, ...fileYears])).sort((a, b) => a - b);
    dedupedById.set(board.id, { ...board, years });
  }
  return Array.from(dedupedById.values()).sort((a, b) => a.title.localeCompare(b.title));
};

const saveRankingBoards = (boards: RankingBoardRecord[]): void => {
  const payload = {
    updatedAt: new Date().toISOString(),
    boards: boards
      .map((item) => ({
        id: sanitizeRankingBoardId(item.id),
        title: String(item.title || '').trim(),
        subtitle: String(item.subtitle || '').trim(),
        description: String(item.description || '').trim(),
        coverImageUrl: String(item.coverImageUrl || '').trim() || null,
        entityType: item.entityType === 'festival' ? 'festival' : 'dj',
        years: normalizeRankingYears(item.years),
        createdAt: item.createdAt || new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }))
      .filter((item) => item.id && item.title),
  };
  fs.writeFileSync(rankingBoardManifestPath(), JSON.stringify(payload, null, 2), 'utf8');
};

const loadRankingYearData = (boardId: string, year: number): RankingYearFile | null => {
  const yearJsonPath = rankingYearJsonPath(boardId, year);
  if (fs.existsSync(yearJsonPath)) {
    try {
      const parsed = JSON.parse(fs.readFileSync(yearJsonPath, 'utf8'));
      if (parsed && typeof parsed === 'object') {
        const entries = parseRankingEntries((parsed as Record<string, unknown>).entries);
        return {
          boardId: sanitizeRankingBoardId(boardId),
          year: Math.floor(year),
          source: String((parsed as Record<string, unknown>).source || '').trim() || undefined,
          updatedAt: String((parsed as Record<string, unknown>).updatedAt || '').trim() || new Date().toISOString(),
          entries,
        };
      }
    } catch (_error) {
      // Fall through to legacy parser.
    }
  }

  const legacyTxtPath = rankingYearPathLegacy(boardId, year);
  if (!legacyTxtPath) return null;
  const parsed = parseRankingText(fs.readFileSync(legacyTxtPath, 'utf8')).map((item) => ({
    rank: item.rank,
    name: item.name,
  }));
  return {
    boardId: sanitizeRankingBoardId(boardId),
    year: Math.floor(year),
    source: 'legacy_txt',
    updatedAt: new Date().toISOString(),
    entries: parsed,
  };
};

const saveRankingYearData = (boardId: string, year: number, entries: RankingEntryRecord[], source = 'manual'): RankingYearFile => {
  const boardDir = rankingBoardDirPath(boardId);
  fs.mkdirSync(boardDir, { recursive: true });
  const normalizedEntries = parseRankingEntries(entries);
  const payload: RankingYearFile = {
    boardId: sanitizeRankingBoardId(boardId),
    year: Math.floor(year),
    source,
    updatedAt: new Date().toISOString(),
    entries: normalizedEntries,
  };
  fs.writeFileSync(rankingYearJsonPath(boardId, year), JSON.stringify(payload, null, 2), 'utf8');
  fs.writeFileSync(rankingYearTxtPath(boardId, year), rankingEntriesToText(normalizedEntries), 'utf8');
  return payload;
};

const normalizeEventWikiFestivalId = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
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
    const statusRaw = typeof req.query.status === 'string' ? req.query.status.trim() : 'upcoming';
    const status = statusRaw.toLowerCase() === 'canceled' ? 'cancelled' : statusRaw.toLowerCase();

    const where: any = {};
    const now = new Date();
    if (status === 'upcoming') {
      where.startDate = { gt: now };
      where.status = { not: 'cancelled' };
    } else if (status === 'ongoing') {
      where.startDate = { lte: now };
      where.endDate = { gte: now };
      where.status = { not: 'cancelled' };
    } else if (status === 'ended') {
      where.endDate = { lt: now };
      where.status = { not: 'cancelled' };
    } else if (status === 'cancelled') {
      where.status = 'cancelled';
    } else if (status === 'all' || status === '') {
      // no status filter
    } else if (status) {
      where.status = status;
    }
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
        { slug: { contains: search, mode: 'insensitive' } },
        { city: { contains: search, mode: 'insensitive' } },
        { country: { contains: search, mode: 'insensitive' } },
        { venueName: { contains: search, mode: 'insensitive' } },
        { organizerName: { contains: search, mode: 'insensitive' } },
        { wikiFestivalId: { contains: search, mode: 'insensitive' } },
        { nameI18n: { path: ['zh'], string_contains: search } },
        { nameI18n: { path: ['en'], string_contains: search } },
        { descriptionI18n: { path: ['zh'], string_contains: search } },
        { descriptionI18n: { path: ['en'], string_contains: search } },
        { locationI18n: { path: ['zh'], string_contains: search } },
        { locationI18n: { path: ['en'], string_contains: search } },
        { countryI18n: { path: ['zh'], string_contains: search } },
        { countryI18n: { path: ['en'], string_contains: search } },
      ];
    }
    if (city) where.city = city;
    if (country) where.country = country;
    if (eventType) {
      const eventTypeValues = resolveEventTypeFilterValues(eventType);
      if (eventTypeValues.length <= 1) {
        where.eventType = eventTypeValues[0] ?? eventType;
      } else {
        where.eventType = { in: eventTypeValues };
      }
    }

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
                select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
              },
            },
          },
          organizer: {
            select: { id: true, username: true, displayName: true, avatarUrl: true },
          },
          wikiFestival: {
            select: {
              id: true,
              name: true,
              nameI18n: true,
              country: true,
              countryI18n: true,
              city: true,
              cityI18n: true,
              avatarUrl: true,
              backgroundUrl: true,
            },
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
              select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
            },
          },
        },
        organizer: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        wikiFestival: {
          select: {
            id: true,
            name: true,
            nameI18n: true,
            country: true,
            countryI18n: true,
            city: true,
            cityI18n: true,
            avatarUrl: true,
            backgroundUrl: true,
          },
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
              select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
            },
          },
        },
        organizer: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        wikiFestival: {
          select: {
            id: true,
            name: true,
            nameI18n: true,
            country: true,
            countryI18n: true,
            city: true,
            cityI18n: true,
            avatarUrl: true,
            backgroundUrl: true,
          },
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

router.get('/events/:id/rating-events', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const eventId = req.params.id as string;
    const sourceEvent = await prisma.event.findUnique({
      where: { id: eventId },
      select: {
        id: true,
        name: true,
        lineupSlots: {
          select: {
            djName: true,
          },
        },
      },
    });

    if (!sourceEvent) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    const sourceEventName = normalizeTextKey(sourceEvent.name);
    const sourceActNames = new Set(
      sourceEvent.lineupSlots
        .map((slot) => normalizeTextKey(slot.djName))
        .filter(Boolean)
    );

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

    const matchedRows: any[] = [];
    for (const row of rows) {
      const sameName = normalizeTextKey(row.name) === sourceEventName;
      if (!sameName) continue;

      const hasMatchingUnit =
        sourceActNames.size === 0
          ? true
          : row.units.some((unit) => sourceActNames.has(normalizeTextKey(unit.name)));
      if (!hasMatchingUnit) continue;

      const linkedUnits = await attachLinkedDJsToRatingUnits(row.units as any[]);
      matchedRows.push({
        ...row,
        sourceEventId: sourceEvent.id,
        units: linkedUnits,
      });
    }

    ok(res, { items: matchedRows.map(mapRatingEvent) });
  } catch (error) {
    console.error('BFF web event rating events error:', error);
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

    const dayRolloverHour = normalizeDayRolloverHour(body.dayRolloverHour, 6);
    const rawSlots = Array.isArray(body.lineupSlots) ? body.lineupSlots : [];
    const lineupSlots = normalizeLineupSlots(rawSlots, parsedStartDate, dayRolloverHour);
    const coverImageUrlInput =
      typeof body.coverImageUrl === 'string' && body.coverImageUrl.trim()
        ? body.coverImageUrl.trim()
        : null;
    const lineupImageUrlInput =
      typeof body.lineupImageUrl === 'string' && body.lineupImageUrl.trim()
        ? body.lineupImageUrl.trim()
        : null;
    const archiveFestivalIdInput =
      typeof body.archiveFestivalId === 'string' && body.archiveFestivalId.trim()
        ? body.archiveFestivalId.trim()
        : null;
    const wikiFestivalIdInput = normalizeEventWikiFestivalId(body.wikiFestivalId ?? body.brandId);
    const sourceProviderInput =
      typeof body.sourceProvider === 'string' && body.sourceProvider.trim()
        ? body.sourceProvider.trim()
        : null;
    const sourceEventUrlInput =
      typeof body.sourceEventUrl === 'string' && body.sourceEventUrl.trim()
        ? body.sourceEventUrl.trim()
        : null;

    const locationSeed =
      (typeof body.location === 'string' && body.location.trim()) ||
      (typeof body.venueName === 'string' && body.venueName.trim()) ||
      (typeof body.city === 'string' && body.city.trim()) ||
      '';
    const countrySeed = typeof body.country === 'string' ? body.country : '';
    const descriptionSeed = typeof body.description === 'string' ? body.description : '';

    const nameI18n = normalizeEventBiText(body.nameI18n, name);
    const locationI18n = normalizeEventBiText(body.locationI18n, locationSeed);
    const countryI18n = normalizeEventBiText(body.countryI18n, countrySeed);
    const descriptionI18n = normalizeEventBiText(body.descriptionI18n, descriptionSeed);
    const referenceLinks = parseEventReferenceLinks(body.referenceLinks ?? body.relatedLinks);
    const socialLinks = parseEventSocialLinks(body.socialLinks);
    const imageAssets = parseEventImageAssets(body.imageAssets);

    if (wikiFestivalIdInput) {
      const brand = await prisma.wikiFestival.findUnique({
        where: { id: wikiFestivalIdInput },
        select: { id: true, isActive: true },
      });
      if (!brand || !brand.isActive) {
        res.status(400).json({ error: 'Invalid wikiFestivalId' });
        return;
      }
    }

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

    const createEventData: any = {
        organizerId: userId,
        name,
        nameI18n: nameI18n ? (nameI18n as unknown as Prisma.InputJsonValue) : undefined,
        slug: desiredSlug,
        wikiFestivalId: wikiFestivalIdInput,
        archiveFestivalId: archiveFestivalIdInput,
        description: typeof body.description === 'string' ? body.description : null,
        descriptionI18n: descriptionI18n ? (descriptionI18n as unknown as Prisma.InputJsonValue) : undefined,
        locationI18n: locationI18n ? (locationI18n as unknown as Prisma.InputJsonValue) : undefined,
        countryI18n: countryI18n ? (countryI18n as unknown as Prisma.InputJsonValue) : undefined,
        coverImageUrl: coverImageUrlInput,
        lineupImageUrl: lineupImageUrlInput,
        imageAssets: imageAssets.length > 0 ? (imageAssets as unknown as Prisma.InputJsonValue) : undefined,
        referenceLinks,
        socialLinks: socialLinks.length > 0 ? (socialLinks as unknown as Prisma.InputJsonValue) : undefined,
        sourceProvider: sourceProviderInput,
        sourceEventUrl: sourceEventUrlInput,
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
        dayRolloverHour,
        status: resolveEventStatus(parsedStartDate, parsedEndDate, typeof body.status === 'string' ? body.status : null),
        ticketUrl: typeof body.ticketUrl === 'string' ? body.ticketUrl : null,
        ticketPriceMin: toNumber(body.ticketPriceMin),
        ticketPriceMax: toNumber(body.ticketPriceMax),
        ticketCurrency,
        ticketNotes: typeof body.ticketNotes === 'string' ? body.ticketNotes : null,
        officialWebsite: typeof body.officialWebsite === 'string' ? body.officialWebsite : null,
        lineupSlots: lineupSlots.length ? { create: lineupSlots } : undefined,
        ticketTiers: ticketTiers.length ? { create: ticketTiers } : undefined,
      };

    const created = await prisma.event.create({
      data: createEventData,
      include: {
        ticketTiers: {
          orderBy: { sortOrder: 'asc' },
        },
        lineupSlots: {
          orderBy: { startTime: 'asc' },
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
            },
          },
        },
        organizer: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        wikiFestival: {
          select: {
            id: true,
            name: true,
            nameI18n: true,
            country: true,
            countryI18n: true,
            city: true,
            cityI18n: true,
            avatarUrl: true,
            backgroundUrl: true,
          },
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
      select: {
        id: true,
        organizerId: true,
        wikiFestivalId: true,
        startDate: true,
        endDate: true,
        dayRolloverHour: true,
        status: true,
        coverImageUrl: true,
        lineupImageUrl: true,
        imageAssets: true,
      },
    });

    if (!existing) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    const canManage = await canUserManageEvent(
      userId,
      authReq.user?.role ?? null,
      existing.organizerId,
      authReq.user?.email ?? null
    );
    if (!canManage) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const rawSlots = Array.isArray(body.lineupSlots) ? body.lineupSlots : null;
    const rawTicketTiers = Array.isArray(body.ticketTiers) ? body.ticketTiers : null;
    const hasCoverImageField = Object.prototype.hasOwnProperty.call(body, 'coverImageUrl');
    const hasLineupImageField = Object.prototype.hasOwnProperty.call(body, 'lineupImageUrl');
    const hasArchiveFestivalIdField = Object.prototype.hasOwnProperty.call(body, 'archiveFestivalId');
    const hasWikiFestivalIdField = Object.prototype.hasOwnProperty.call(body, 'wikiFestivalId')
      || Object.prototype.hasOwnProperty.call(body, 'brandId');
    const hasNameI18nField = Object.prototype.hasOwnProperty.call(body, 'nameI18n');
    const hasDescriptionI18nField = Object.prototype.hasOwnProperty.call(body, 'descriptionI18n');
    const hasLocationI18nField = Object.prototype.hasOwnProperty.call(body, 'locationI18n');
    const hasCountryI18nField = Object.prototype.hasOwnProperty.call(body, 'countryI18n');
    const hasReferenceLinksField = Object.prototype.hasOwnProperty.call(body, 'referenceLinks')
      || Object.prototype.hasOwnProperty.call(body, 'relatedLinks');
    const hasSocialLinksField = Object.prototype.hasOwnProperty.call(body, 'socialLinks');
    const hasImageAssetsField = Object.prototype.hasOwnProperty.call(body, 'imageAssets');
    const hasSourceProviderField = Object.prototype.hasOwnProperty.call(body, 'sourceProvider');
    const hasSourceEventUrlField = Object.prototype.hasOwnProperty.call(body, 'sourceEventUrl');

    const nextCoverImageUrl =
      hasCoverImageField
        ? (typeof body.coverImageUrl === 'string' && body.coverImageUrl.trim() ? body.coverImageUrl.trim() : null)
        : undefined;
    const nextLineupImageUrl =
      hasLineupImageField
        ? (typeof body.lineupImageUrl === 'string' && body.lineupImageUrl.trim() ? body.lineupImageUrl.trim() : null)
        : undefined;
    const nextArchiveFestivalId =
      hasArchiveFestivalIdField
        ? (typeof body.archiveFestivalId === 'string' && body.archiveFestivalId.trim() ? body.archiveFestivalId.trim() : null)
        : undefined;
    const nextWikiFestivalId =
      hasWikiFestivalIdField
        ? normalizeEventWikiFestivalId(body.wikiFestivalId ?? body.brandId)
        : undefined;

    if (hasWikiFestivalIdField && nextWikiFestivalId) {
      const brand = await prisma.wikiFestival.findUnique({
        where: { id: nextWikiFestivalId },
        select: { id: true, isActive: true },
      });
      if (!brand || !brand.isActive) {
        res.status(400).json({ error: 'Invalid wikiFestivalId' });
        return;
      }
    }

    const updateName = typeof body.name === 'string' ? body.name : '';
    const updateDescription = typeof body.description === 'string' ? body.description : '';
    const updateLocationSeed =
      (typeof body.location === 'string' && body.location.trim())
      || (typeof body.venueName === 'string' && body.venueName.trim())
      || (typeof body.city === 'string' && body.city.trim())
      || '';
    const updateCountrySeed = typeof body.country === 'string' ? body.country : '';

    const nextNameI18n = hasNameI18nField ? normalizeEventBiText(body.nameI18n, updateName) : null;
    const nextDescriptionI18n = hasDescriptionI18nField ? normalizeEventBiText(body.descriptionI18n, updateDescription) : null;
    const nextLocationI18n = hasLocationI18nField ? normalizeEventBiText(body.locationI18n, updateLocationSeed) : null;
    const nextCountryI18n = hasCountryI18nField ? normalizeEventBiText(body.countryI18n, updateCountrySeed) : null;
    const nextReferenceLinks = hasReferenceLinksField ? parseEventReferenceLinks(body.referenceLinks ?? body.relatedLinks) : null;
    const nextSocialLinks = hasSocialLinksField ? parseEventSocialLinks(body.socialLinks) : null;
    const nextImageAssets = hasImageAssetsField ? parseEventImageAssets(body.imageAssets) : null;
    const nextSourceProvider =
      hasSourceProviderField
        ? (typeof body.sourceProvider === 'string' && body.sourceProvider.trim() ? body.sourceProvider.trim() : null)
        : undefined;
    const nextSourceEventUrl =
      hasSourceEventUrlField
        ? (typeof body.sourceEventUrl === 'string' && body.sourceEventUrl.trim() ? body.sourceEventUrl.trim() : null)
        : undefined;

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

    const nextDayRolloverHour = body.dayRolloverHour !== undefined
      ? normalizeDayRolloverHour(body.dayRolloverHour, existing.dayRolloverHour ?? 6)
      : (existing.dayRolloverHour ?? 6);
    const lineupBaseDate = parsedStartDate ?? existing.startDate;
    const effectiveStartDate = parsedStartDate ?? existing.startDate;
    const effectiveEndDate = parsedEndDate ?? existing.endDate;
    const lineupSlots = normalizeLineupSlots(rawSlots || [], lineupBaseDate, nextDayRolloverHour);

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

    const updateEventData: any = {
        name: typeof body.name === 'string' ? body.name : undefined,
        nameI18n: hasNameI18nField
          ? (nextNameI18n ? (nextNameI18n as unknown as Prisma.InputJsonValue) : undefined)
          : undefined,
        slug: typeof body.slug === 'string' ? body.slug : undefined,
        wikiFestivalId: hasWikiFestivalIdField ? nextWikiFestivalId : undefined,
        archiveFestivalId: nextArchiveFestivalId,
        description: typeof body.description === 'string' ? body.description : undefined,
        descriptionI18n: hasDescriptionI18nField
          ? (nextDescriptionI18n ? (nextDescriptionI18n as unknown as Prisma.InputJsonValue) : undefined)
          : undefined,
        locationI18n: hasLocationI18nField
          ? (nextLocationI18n ? (nextLocationI18n as unknown as Prisma.InputJsonValue) : undefined)
          : undefined,
        countryI18n: hasCountryI18nField
          ? (nextCountryI18n ? (nextCountryI18n as unknown as Prisma.InputJsonValue) : undefined)
          : undefined,
        coverImageUrl: nextCoverImageUrl,
        lineupImageUrl: nextLineupImageUrl,
        imageAssets: hasImageAssetsField
          ? (nextImageAssets && nextImageAssets.length > 0
              ? (nextImageAssets as unknown as Prisma.InputJsonValue)
              : Prisma.DbNull)
          : undefined,
        referenceLinks: hasReferenceLinksField ? (nextReferenceLinks ?? []) : undefined,
        socialLinks: hasSocialLinksField
          ? (nextSocialLinks && nextSocialLinks.length > 0 ? (nextSocialLinks as unknown as Prisma.InputJsonValue) : undefined)
          : undefined,
        sourceProvider: nextSourceProvider,
        sourceEventUrl: nextSourceEventUrl,
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
        dayRolloverHour: body.dayRolloverHour !== undefined ? nextDayRolloverHour : undefined,
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
      };

    const updated = await prisma.event.update({
      where: { id: eventId },
      data: updateEventData,
      include: {
        ticketTiers: {
          orderBy: { sortOrder: 'asc' },
        },
        lineupSlots: {
          orderBy: { startTime: 'asc' },
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
            },
          },
        },
        organizer: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        wikiFestival: {
          select: {
            id: true,
            name: true,
            nameI18n: true,
            country: true,
            countryI18n: true,
            city: true,
            cityI18n: true,
            avatarUrl: true,
            backgroundUrl: true,
          },
        },
      },
    });

    if (hasCoverImageField && existing.coverImageUrl && existing.coverImageUrl !== updated.coverImageUrl) {
      await deleteSingleEventOssObjectIfOwned(existing.coverImageUrl, eventId);
    }
    if (hasLineupImageField && existing.lineupImageUrl && existing.lineupImageUrl !== updated.lineupImageUrl) {
      await deleteSingleEventOssObjectIfOwned(existing.lineupImageUrl, eventId);
    }
    if (hasImageAssetsField) {
      const previousAssets = parseEventImageAssets(existing.imageAssets ?? []);
      const nextAssets = parseEventImageAssets(updated.imageAssets ?? []);
      const nextUrlSet = new Set(
        nextAssets
          .map((asset) => String(asset.url || '').trim().toLowerCase())
          .filter(Boolean)
      );
      const removedAssets = previousAssets.filter((asset) => {
        const key = String(asset.url || '').trim().toLowerCase();
        if (!key) return false;
        return !nextUrlSet.has(key);
      });
      for (const asset of removedAssets) {
        await deleteSingleEventOssObjectIfOwned(asset.url, eventId);
      }
    }

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

    const canManage = await canUserManageEvent(
      userId,
      authReq.user?.role ?? null,
      existing.organizerId,
      authReq.user?.email ?? null
    );
    if (!canManage) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    await prisma.event.delete({ where: { id: eventId } });
    await deleteEventOssFolder(eventId);
    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events/upload-image', optionalAuth, eventImageUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }
    if (!postMediaOssClient) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(503).json({ error: 'OSS is not configured for rating image upload' });
      return;
    }

    const formBody = req.body as Record<string, unknown>;
    const eventId = typeof formBody.eventId === 'string' ? formBody.eventId.trim() : '';
    const usage = typeof formBody.usage === 'string' ? formBody.usage.trim() : '';

    if (eventId) {
      const event = await prisma.event.findUnique({
        where: { id: eventId },
        select: { id: true, organizerId: true },
      });

      if (!event) {
        await fs.promises.unlink(file.path).catch(() => undefined);
        res.status(404).json({ error: 'Event not found' });
        return;
      }

      const canManage = await canUserManageEvent(
        userId,
        authReq.user?.role ?? null,
        event.organizerId,
        authReq.user?.email ?? null
      );
      if (!canManage) {
        await fs.promises.unlink(file.path).catch(() => undefined);
        res.status(403).json({ error: 'Forbidden' });
        return;
      }

      const uploaded = await uploadEventMediaToOss(file, eventId, usage || null);
      ok(res, uploaded);
      return;
    }

    if (looksLikePostMediaName(file.originalname || '', 'image')) {
      const uploaded = await uploadPostMediaToOss(file, 'image');
      ok(res, uploaded);
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

router.post('/wiki/brands/upload-image', optionalAuth, wikiBrandImageUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    if (!postMediaOssClient) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(503).json({ error: 'OSS is not configured for wiki brand image upload' });
      return;
    }

    const formBody = req.body as Record<string, unknown>;
    const brandIdRaw = typeof formBody.brandId === 'string' ? formBody.brandId.trim() : '';
    const usageRaw = typeof formBody.usage === 'string' ? formBody.usage.trim() : '';
    const brandId = brandIdRaw.length > 0 ? brandIdRaw : null;
    const usage = usageRaw.length > 0 ? usageRaw : null;

    const uploaded = await uploadWikiBrandMediaToOss(file, brandId, usage);
    ok(res, uploaded);
  } catch (error) {
    console.error('BFF web upload wiki brand image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events/lineup/import-image', optionalAuth, lineupImportImageUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  const requestStartedAt = Date.now();
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    if (!postMediaOssClient) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(503).json({ error: 'OSS is not configured for lineup image import' });
      return;
    }
    if (!cozeWorkflowToken) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(503).json({ error: 'COZE_WORKFLOW_TOKEN is not configured' });
      return;
    }

    const uploaded = await uploadLineupImportImageToOss(file);
    try {
      const imported = await runCozeLineupWorker(uploaded.url, uploaded.mimeType);
      console.info('[lineup-import] request.success', {
        userId,
        durationMs: Date.now() - requestStartedAt,
        lineupCount: imported.lineupInfo.length,
      });
      ok(res, imported);
    } finally {
      await deleteOssObjects([uploaded.objectKey]);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    console.error('BFF web lineup import image error:', {
      durationMs: Date.now() - requestStartedAt,
      message,
      error,
    });
    if (message.includes('COZE_WORKFLOW_TIMEOUT')) {
      res.status(504).json({ error: '阵容识别超时，请稍后重试或换一张更清晰的图' });
      return;
    }
    if (message.startsWith('Coze workflow request failed')) {
      res.status(502).json({ error: '阵容识别服务暂时不可用，请稍后重试' });
      return;
    }
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/upload-image', optionalAuth, feedImageUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;
    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    const formBody = req.body as Record<string, unknown>;
    const postIdRaw = typeof formBody.postId === 'string' ? formBody.postId.trim() : '';
    const newsKeyRaw = typeof formBody.newsKey === 'string' ? formBody.newsKey.trim() : '';
    const scopeKey = postIdRaw
      ? `post-${postIdRaw}`
      : (newsKeyRaw ? `draft-${newsKeyRaw}` : null);

    const uploaded = await uploadPostMediaToOss(file, 'image', scopeKey);
    ok(res, uploaded);
  } catch (error) {
    console.error('BFF web upload feed image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/upload-video', optionalAuth, feedVideoUpload.single('video'), async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;
    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    const formBody = req.body as Record<string, unknown>;
    const postIdRaw = typeof formBody.postId === 'string' ? formBody.postId.trim() : '';
    const newsKeyRaw = typeof formBody.newsKey === 'string' ? formBody.newsKey.trim() : '';
    const scopeKey = postIdRaw
      ? `post-${postIdRaw}`
      : (newsKeyRaw ? `draft-${newsKeyRaw}` : null);

    const uploaded = await uploadPostMediaToOss(file, 'video', scopeKey);
    ok(res, uploaded);
  } catch (error) {
    console.error('BFF web upload feed video error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId;
    const viewerRole = authReq.user?.role ?? null;
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const skip = (page - 1) * limit;

    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const country = typeof req.query.country === 'string' ? req.query.country.trim() : '';
    const sortBy = typeof req.query.sortBy === 'string' ? req.query.sortBy : 'followerCount';

    const where: Prisma.DJWhereInput = {};
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

    let rows: any[] = [];
    let total = 0;

    // When keyword search is present, prioritize textual relevance:
    // name match relevance > aliases match relevance > bio match relevance.
    // `sortBy=random` remains an explicit override.
    if (search && sortBy !== 'random') {
      const searchPattern = `%${search}%`;
      const whereSqlParts: Prisma.Sql[] = [
        Prisma.sql`(
          "d"."name" ILIKE ${searchPattern}
          OR COALESCE("d"."bio", '') ILIKE ${searchPattern}
          OR EXISTS (
            SELECT 1
            FROM unnest("d"."aliases") AS "alias"
            WHERE "alias" ILIKE ${searchPattern}
          )
          OR "d"."name" % ${search}
          OR COALESCE("d"."bio", '') % ${search}
          OR EXISTS (
            SELECT 1
            FROM unnest("d"."aliases") AS "alias"
            WHERE "alias" % ${search}
          )
        )`,
      ];

      if (country) {
        whereSqlParts.push(Prisma.sql`"d"."country" = ${country}`);
      }

      const whereSql = Prisma.sql`WHERE ${Prisma.join(whereSqlParts, ' AND ')}`;

      const [idRows, totalCountRows] = await Promise.all([
        prisma.$queryRaw<Array<{ id: string }>>(Prisma.sql`
          WITH scored AS (
            SELECT
              "d"."id",
              "d"."name",
              "d"."follower_count",
              CASE
                WHEN "d"."name" ILIKE ${searchPattern} OR "d"."name" % ${search} THEN 0
                WHEN EXISTS (
                  SELECT 1
                  FROM unnest("d"."aliases") AS "alias"
                  WHERE "alias" ILIKE ${searchPattern} OR "alias" % ${search}
                ) THEN 1
                WHEN COALESCE("d"."bio", '') ILIKE ${searchPattern} OR COALESCE("d"."bio", '') % ${search} THEN 2
                ELSE 3
              END AS "match_bucket",
              GREATEST(
                similarity(COALESCE("d"."name", ''), ${search}),
                word_similarity(COALESCE("d"."name", ''), ${search})
              ) AS "name_score",
              COALESCE((
                SELECT MAX(
                  GREATEST(
                    similarity("alias", ${search}),
                    word_similarity("alias", ${search})
                  )
                )
                FROM unnest("d"."aliases") AS "alias"
              ), 0) AS "alias_score",
              GREATEST(
                similarity(COALESCE("d"."bio", ''), ${search}),
                word_similarity(COALESCE("d"."bio", ''), ${search})
              ) AS "bio_score"
            FROM "djs" AS "d"
            ${whereSql}
          )
          SELECT "id"
          FROM scored
          ORDER BY
            "match_bucket" ASC,
            CASE
              WHEN "match_bucket" = 0 THEN "name_score"
              WHEN "match_bucket" = 1 THEN "alias_score"
              WHEN "match_bucket" = 2 THEN "bio_score"
              ELSE 0
            END DESC,
            GREATEST("name_score", "alias_score", "bio_score") DESC,
            "follower_count" DESC,
            "name" ASC
          LIMIT ${limit}
          OFFSET ${skip}
        `),
        prisma.$queryRaw<Array<{ total: number }>>(Prisma.sql`
          SELECT COUNT(*)::int AS "total"
          FROM "djs" AS "d"
          ${whereSql}
        `),
      ]);

      total = Number(totalCountRows[0]?.total ?? 0);
      const orderedIds = idRows.map((row) => row.id);
      if (orderedIds.length > 0) {
        const idOrder = new Map(orderedIds.map((id, index) => [id, index]));
        rows = await prisma.dJ.findMany({
          where: {
            id: { in: orderedIds },
          },
        });
        rows.sort((a, b) => (idOrder.get(a.id) ?? 0) - (idOrder.get(b.id) ?? 0));
      }
    } else if (sortBy === 'random') {
      const whereSqlParts: Prisma.Sql[] = [];

      if (search) {
        const searchPattern = `%${search}%`;
        whereSqlParts.push(Prisma.sql`(
          "djs"."name" ILIKE ${searchPattern}
          OR COALESCE("djs"."bio", '') ILIKE ${searchPattern}
          OR EXISTS (
            SELECT 1
            FROM unnest("djs"."aliases") AS "alias"
            WHERE "alias" ILIKE ${searchPattern}
          )
        )`);
      }

      if (country) {
        whereSqlParts.push(Prisma.sql`"djs"."country" = ${country}`);
      }

      const whereSql =
        whereSqlParts.length > 0
          ? Prisma.sql`WHERE ${Prisma.join(whereSqlParts, ' AND ')}`
          : Prisma.empty;

      const [idRows, totalCount] = await Promise.all([
        prisma.$queryRaw<Array<{ id: string }>>(Prisma.sql`
          SELECT "djs"."id"
          FROM "djs"
          ${whereSql}
          ORDER BY RANDOM()
          LIMIT ${limit}
          OFFSET ${skip}
        `),
        prisma.dJ.count({ where }),
      ]);

      total = totalCount;
      const orderedIds = idRows.map((row) => row.id);
      if (orderedIds.length > 0) {
        const idOrder = new Map(orderedIds.map((id, index) => [id, index]));
        rows = await prisma.dJ.findMany({
          where: {
            id: { in: orderedIds },
          },
        });
        rows.sort((a, b) => (idOrder.get(a.id) ?? 0) - (idOrder.get(b.id) ?? 0));
      }
    } else {
      const orderBy: Prisma.DJOrderByWithRelationInput =
        sortBy === 'name'
          ? { name: 'asc' }
          : sortBy === 'createdAt'
            ? { createdAt: 'desc' }
            : { followerCount: 'desc' };

      const [sortedRows, totalCount] = await Promise.all([
        prisma.dJ.findMany({
          where,
          skip,
          take: limit,
          orderBy,
        }),
        prisma.dJ.count({ where }),
      ]);

      rows = sortedRows;
      total = totalCount;
    }

    rows = await attachDJContributorInfoList(rows);

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
      { items: rows.map((row) => mapDJ(row, followSet.has(row.id), viewerId, viewerRole)) },
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

router.get('/djs/spotify/search', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    if (!spotifyArtistService.isConfigured()) {
      res.status(503).json({ error: 'Spotify credentials are not configured' });
      return;
    }

    const query = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    if (!query) {
      res.status(400).json({ error: 'q is required' });
      return;
    }

    const limit = normalizeLimit(req.query.limit, 10, 10);
    console.info('[spotify-debug] bff.search.start', {
      userId,
      query,
      limit,
    });
    const candidates = await spotifyArtistService.searchArtistsByName(query, limit);
    if (candidates.length === 0) {
      console.info('[spotify-debug] bff.search.empty', {
        userId,
        query,
      });
      ok(res, { items: [] as SpotifyDJSearchItem[] });
      return;
    }

    const spotifyIds = candidates.map((item) => item.id).filter(Boolean);
    const nameConditions = candidates.map((item) => ({
      name: { equals: item.name, mode: 'insensitive' as const },
    }));
    const existingRows = await prisma.dJ.findMany({
      where: {
        OR: [
          ...(spotifyIds.length > 0 ? [{ spotifyId: { in: spotifyIds } }] : []),
          ...nameConditions,
        ],
      },
      select: {
        id: true,
        name: true,
        spotifyId: true,
      },
      orderBy: {
        createdAt: 'asc',
      },
    });

    const bySpotifyId = new Map<string, (typeof existingRows)[number]>();
    const byName = new Map<string, (typeof existingRows)[number]>();
    for (const row of existingRows) {
      if (row.spotifyId && !bySpotifyId.has(row.spotifyId)) {
        bySpotifyId.set(row.spotifyId, row);
      }
      const key = normalizeDJNameKey(row.name);
      if (!byName.has(key)) {
        byName.set(key, row);
      }
    }

    const items: SpotifyDJSearchItem[] = candidates.map((item) => {
      const spotifyMatched = bySpotifyId.get(item.id) ?? null;
      const nameMatched = byName.get(normalizeDJNameKey(item.name)) ?? null;
      const matched = spotifyMatched ?? nameMatched;
      const matchType: SpotifyDJSearchItem['existingMatchType'] = spotifyMatched
        ? 'spotify_id'
        : nameMatched
          ? 'name_case_insensitive'
          : null;

      return {
        spotifyId: item.id,
        name: item.name,
        uri: item.uri,
        url: item.url,
        popularity: item.popularity,
        followers: item.followers,
        genres: item.genres,
        imageUrl: item.imageUrl,
        existingDJId: matched?.id ?? null,
        existingDJName: matched?.name ?? null,
        existingMatchType: matchType,
      };
    });

    console.info('[spotify-debug] bff.search.success', {
      userId,
      query,
      spotifyCandidateCount: candidates.length,
      responseItemCount: items.length,
      matchedExistingCount: items.filter((item) => Boolean(item.existingDJId)).length,
    });
    ok(res, { items });
  } catch (error) {
    if (error instanceof SpotifyUpstreamError) {
      console.error('BFF web spotify dj search upstream error:', {
        code: error.code,
        status: error.status,
        message: error.message,
      });
      res.status(503).json({
        error: 'Spotify 服务暂时不可用，请稍后重试',
        errorCode: error.code,
      });
      return;
    }
    console.error('BFF web spotify dj search error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/discogs/search', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    if (!discogsArtistService.isConfigured()) {
      res.status(503).json({ error: 'Discogs token is not configured' });
      return;
    }

    const query = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    if (!query) {
      res.status(400).json({ error: 'q is required' });
      return;
    }

    const limit = normalizeLimit(req.query.limit, 10, 20);
    const candidates = await discogsArtistService.searchArtistsByName(query, limit);
    if (candidates.length === 0) {
      ok(res, { items: [] as DiscogsDJSearchItem[] });
      return;
    }

    const nameConditions = candidates.map((item) => ({
      name: { equals: item.name, mode: 'insensitive' as const },
    }));
    const existingRows = await prisma.dJ.findMany({
      where: {
        OR: nameConditions,
      },
      select: {
        id: true,
        name: true,
      },
      orderBy: {
        createdAt: 'asc',
      },
    });

    const byName = new Map<string, (typeof existingRows)[number]>();
    for (const row of existingRows) {
      const key = normalizeDJNameKey(row.name);
      if (!byName.has(key)) {
        byName.set(key, row);
      }
    }

    const items: DiscogsDJSearchItem[] = candidates.map((item) => {
      const matched = byName.get(normalizeDJNameKey(item.name)) ?? null;
      return {
        artistId: item.artistId,
        name: item.name,
        thumbUrl: item.thumbUrl,
        coverImageUrl: item.coverImageUrl,
        resourceUrl: item.resourceUrl,
        uri: item.uri,
        existingDJId: matched?.id ?? null,
        existingDJName: matched?.name ?? null,
        existingMatchType: matched ? 'name_case_insensitive' : null,
      };
    });

    ok(res, { items });
  } catch (error) {
    if (error instanceof DiscogsUpstreamError) {
      console.error('BFF web discogs dj search upstream error:', {
        code: error.code,
        status: error.status,
        message: error.message,
      });
      res.status(503).json({
        error: 'Discogs 服务暂时不可用，请稍后重试',
        errorCode: error.code,
      });
      return;
    }
    console.error('BFF web discogs dj search error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/discogs/artists/:artistId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    if (!discogsArtistService.isConfigured()) {
      res.status(503).json({ error: 'Discogs token is not configured' });
      return;
    }

    const parsedArtistId = Number(req.params.artistId);
    if (!Number.isFinite(parsedArtistId) || parsedArtistId <= 0) {
      res.status(400).json({ error: 'artistId must be a positive number' });
      return;
    }

    const detail = await discogsArtistService.getArtistById(Math.floor(parsedArtistId));
    if (!detail) {
      res.status(404).json({ error: 'Discogs artist not found' });
      return;
    }

    const existing = await prisma.dJ.findFirst({
      where: { name: { equals: detail.name, mode: 'insensitive' } },
      select: { id: true, name: true },
      orderBy: { createdAt: 'asc' },
    });

    const payload: DiscogsDJArtistDetailItem = {
      artistId: detail.artistId,
      name: detail.name,
      realName: detail.realName,
      profile: detail.profile,
      urls: detail.urls,
      nameVariations: detail.nameVariations,
      aliases: detail.aliases,
      groups: detail.groups,
      primaryImageUrl: detail.primaryImageUrl,
      thumbnailImageUrl: detail.thumbnailImageUrl,
      resourceUrl: detail.resourceUrl,
      uri: detail.uri,
      existingDJId: existing?.id ?? null,
      existingDJName: existing?.name ?? null,
      existingMatchType: existing ? 'name_case_insensitive' : null,
    };

    ok(res, payload);
  } catch (error) {
    if (error instanceof DiscogsUpstreamError) {
      console.error('BFF web discogs artist detail upstream error:', {
        code: error.code,
        status: error.status,
        message: error.message,
      });
      res.status(503).json({
        error: 'Discogs 服务暂时不可用，请稍后重试',
        errorCode: error.code,
      });
      return;
    }
    console.error('BFF web discogs artist detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/soundcloud/search', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    if (!soundcloudArtistService.isConfigured()) {
      res.status(503).json({ error: 'SoundCloud credentials are not configured' });
      return;
    }

    const query = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    if (!query) {
      res.status(400).json({ error: 'q is required' });
      return;
    }

    const limit = normalizeLimit(req.query.limit, 10, 30);
    const candidates = await soundcloudArtistService.searchUsersByName(query, limit);
    if (candidates.length === 0) {
      ok(res, { items: [] as SoundCloudDJSearchItem[] });
      return;
    }

    const nameConditions = candidates.map((item) => ({
      name: { equals: item.name, mode: 'insensitive' as const },
    }));
    const existingRows = await prisma.dJ.findMany({
      where: {
        OR: nameConditions,
      },
      select: {
        id: true,
        name: true,
      },
      orderBy: {
        createdAt: 'asc',
      },
    });

    const byName = new Map<string, (typeof existingRows)[number]>();
    for (const row of existingRows) {
      const key = normalizeDJNameKey(row.name);
      if (!byName.has(key)) {
        byName.set(key, row);
      }
    }

    const items: SoundCloudDJSearchItem[] = candidates.map((item) => {
      const matched = byName.get(normalizeDJNameKey(item.name)) ?? null;
      return {
        soundcloudid: item.soundcloudId,
        soundcloudId: item.soundcloudId,
        soundCloudId: item.soundcloudId,
        name: item.name,
        username: item.username,
        avatarUrl: item.avatarUrl,
        permalink: item.permalink,
        permalinkUrl: item.permalinkUrl,
        city: item.city,
        country: item.country,
        description: item.description,
        website: item.website,
        spotifyUrl: item.spotifyUrl,
        instagramUrl: item.instagramUrl,
        facebookUrl: item.facebookUrl,
        twitterUrl: item.twitterUrl,
        youtubeUrl: item.youtubeUrl,
        track_count: item.trackCount,
        playlist_count: item.playlistCount,
        followers_count: item.followersCount,
        public_favorites_count: item.publicFavoritesCount,
        trackCount: item.trackCount,
        playlistCount: item.playlistCount,
        followersCount: item.followersCount,
        publicFavoritesCount: item.publicFavoritesCount,
        soundCloudFollowers: item.followersCount,
        soundCloudFavorites: item.publicFavoritesCount,
        existingDJId: matched?.id ?? null,
        existingDJName: matched?.name ?? null,
        existingMatchType: matched ? 'name_case_insensitive' : null,
      };
    });

    ok(res, { items });
  } catch (error) {
    if (error instanceof SoundCloudUpstreamError) {
      console.error('BFF web soundcloud dj search upstream error:', {
        code: error.code,
        status: error.status,
        message: error.message,
      });
      res.status(503).json({
        error: 'SoundCloud 服务暂时不可用，请稍后重试',
        errorCode: error.code,
      });
      return;
    }
    console.error('BFF web soundcloud dj search error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/djs/spotify/import', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    if (!spotifyArtistService.isConfigured()) {
      res.status(503).json({ error: 'Spotify credentials are not configured' });
      return;
    }

    const payload = (req.body ?? {}) as Record<string, unknown>;
    const spotifyId = typeof payload.spotifyId === 'string' ? payload.spotifyId.trim() : '';
    if (!spotifyId) {
      res.status(400).json({ error: 'spotifyId is required' });
      return;
    }

    const spotifyArtist = await spotifyArtistService.getArtistById(spotifyId);
    if (!spotifyArtist) {
      res.status(404).json({ error: 'Spotify artist not found' });
      return;
    }

    const requestedName = typeof payload.name === 'string' ? payload.name.trim() : '';
    const finalName = requestedName || spotifyArtist.name.trim();
    if (!finalName) {
      res.status(400).json({ error: 'DJ name is empty' });
      return;
    }

    const hasAliasesInput = Object.prototype.hasOwnProperty.call(payload, 'aliases');
    let requestedAliases: string[] = [];
    if (hasAliasesInput) {
      const aliasValue = payload.aliases;
      if (aliasValue !== null && !Array.isArray(aliasValue)) {
        res.status(400).json({ error: 'aliases must be an array or null' });
        return;
      }
      requestedAliases = Array.isArray(aliasValue)
        ? aliasValue.map((item) => (typeof item === 'string' ? item.trim() : '')).filter(Boolean)
        : [];
    }
    const requestedBio = typeof payload.bio === 'string' ? payload.bio.trim() : '';
    const requestedCountry = typeof payload.country === 'string' ? payload.country.trim() : '';
    const hasGenresInput = Object.prototype.hasOwnProperty.call(payload, 'genres');
    if (hasGenresInput && payload.genres !== null && !Array.isArray(payload.genres) && typeof payload.genres !== 'string') {
      res.status(400).json({ error: 'genres must be an array, string, or null' });
      return;
    }
    const requestedGenres = hasGenresInput ? normalizeGenres(payload.genres) : [];
    const requestedInstagram = typeof payload.instagramUrl === 'string' ? payload.instagramUrl.trim() : '';
    const requestedFacebook = typeof payload.facebookUrl === 'string' ? payload.facebookUrl.trim() : '';
    const requestedSoundcloud = typeof payload.soundcloudUrl === 'string' ? payload.soundcloudUrl.trim() : '';
    const requestedTwitter = typeof payload.twitterUrl === 'string' ? payload.twitterUrl.trim() : '';
    const requestedYoutube = typeof payload.youtubeUrl === 'string' ? payload.youtubeUrl.trim() : '';
    const requestedSoundcloudId = parseOptionalStringFromPayload(payload, ['soundcloudId', 'soundcloudid']);
    const requestedWebsite = parseOptionalStringFromPayload(payload, ['website', 'websiteUrl', 'officialWebsite']);
    const hasTrackCountInput = payloadHasAnyKey(payload, ['trackCount', 'track_count']);
    const hasPlaylistCountInput = payloadHasAnyKey(payload, ['playlistCount', 'playlist_count']);
    const hasSoundCloudFollowersInput = payloadHasAnyKey(payload, [
      'soundCloudFollowers',
      'soundcloudFollowers',
      'followers_count',
    ]);
    const hasSoundCloudFavoritesInput = payloadHasAnyKey(payload, [
      'soundCloudFavorites',
      'soundcloudFavorites',
      'public_favorites_count',
    ]);
    let requestedTrackCount: number | null = null;
    let requestedPlaylistCount: number | null = null;
    let requestedSoundCloudFollowers: number | null = null;
    let requestedSoundCloudFavorites: number | null = null;
    try {
      if (hasTrackCountInput) {
        requestedTrackCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['trackCount', 'track_count']),
          'trackCount'
        );
      }
      if (hasPlaylistCountInput) {
        requestedPlaylistCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['playlistCount', 'playlist_count']),
          'playlistCount'
        );
      }
      if (hasSoundCloudFollowersInput) {
        requestedSoundCloudFollowers = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFollowers', 'soundcloudFollowers', 'followers_count']),
          'soundCloudFollowers'
        );
      }
      if (hasSoundCloudFavoritesInput) {
        requestedSoundCloudFavorites = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFavorites', 'soundcloudFavorites', 'public_favorites_count']),
          'soundCloudFavorites'
        );
      }
    } catch (error) {
      res.status(400).json({ error: (error as Error).message });
      return;
    }
    const hasSpotifyFollowersInput = Object.prototype.hasOwnProperty.call(payload, 'spotifyFollowers');
    let requestedSpotifyFollowers: number | null = null;
    if (hasSpotifyFollowersInput) {
      try {
        requestedSpotifyFollowers = parseOptionalNonNegativeInt(payload.spotifyFollowers, 'spotifyFollowers');
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }
    const requestedVerified =
      typeof payload.isVerified === 'boolean' ? payload.isVerified : true;

    const spotifyName = spotifyArtist.name.trim();
    const derivedBio = spotifyArtist.genres.length
      ? `Spotify genres: ${spotifyArtist.genres.slice(0, 4).join(', ')}`
      : '';
    const derivedGenres = normalizeGenres(spotifyArtist.genres);
    const derivedSpotifyFollowers = Number.isFinite(spotifyArtist.followers)
      ? Math.max(0, Math.floor(spotifyArtist.followers))
      : 0;

    const existingBySpotifyId = await prisma.dJ.findFirst({
      where: { spotifyId: spotifyArtist.id },
    });
    const existingByName = existingBySpotifyId
      ? null
      : await prisma.dJ.findFirst({
          where: { name: { equals: finalName, mode: 'insensitive' } },
          orderBy: { createdAt: 'asc' },
        });

    const target = existingBySpotifyId ?? existingByName;
    if (target) {
      const allowed = await canUserEditDJ(target.id, userId, viewerRole);
      if (!allowed) {
        res.status(403).json({ error: '仅该 DJ 的贡献者或管理员可修改信息' });
        return;
      }
    }
    const mergedAliases = mergeAliases(finalName, [
      ...(target?.aliases ?? []),
      ...requestedAliases,
      spotifyName,
    ]);

    let action: 'created' | 'updated' = 'created';
    let previousAvatarUrl: string | null = null;
    let persisted: any;

    if (target) {
      action = 'updated';
      previousAvatarUrl = target.avatarUrl ?? null;
      persisted = await prisma.dJ.update({
        where: { id: target.id },
        data: {
          name: target.name || finalName,
          nameI18n: (normalizeDJBiText(target.nameI18n ?? null, target.name || finalName) as unknown as Prisma.InputJsonValue | null) ?? undefined,
          aliases: mergedAliases,
          genres: hasGenresInput ? requestedGenres : normalizeGenres([...(target.genres ?? []), ...derivedGenres]),
          bio: requestedBio || target.bio || derivedBio || null,
          bioI18n: (normalizeDJBiText(target.bioI18n ?? null, requestedBio || target.bio || derivedBio || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          country: requestedCountry || target.country || null,
          countryI18n: (normalizeDJBiText(target.countryI18n ?? null, requestedCountry || target.country || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          spotifyId: spotifyArtist.id,
          spotifyFollowers: hasSpotifyFollowersInput ? requestedSpotifyFollowers : derivedSpotifyFollowers,
          followerCount: spotifyArtist.followers || target.followerCount || 0,
          instagramUrl: requestedInstagram || target.instagramUrl || null,
          facebookUrl: requestedFacebook || target.facebookUrl || null,
          soundcloudUrl: requestedSoundcloud || target.soundcloudUrl || null,
          soundcloudId: requestedSoundcloudId || target.soundcloudId || null,
          website: requestedWebsite || target.website || null,
          trackCount: hasTrackCountInput ? requestedTrackCount : (target.trackCount ?? null),
          playlistCount: hasPlaylistCountInput ? requestedPlaylistCount : (target.playlistCount ?? null),
          soundCloudFollowers: hasSoundCloudFollowersInput
            ? requestedSoundCloudFollowers
            : (target.soundCloudFollowers ?? null),
          soundCloudFavorites: hasSoundCloudFavoritesInput
            ? requestedSoundCloudFavorites
            : (target.soundCloudFavorites ?? null),
          twitterUrl: requestedTwitter || target.twitterUrl || null,
          youtubeUrl: requestedYoutube || target.youtubeUrl || null,
          isVerified: target.isVerified || requestedVerified,
          avatarSourceUrl: spotifyArtist.imageUrl || target.avatarSourceUrl || null,
          sourceDataSource: mergeDJDataSources(target.sourceDataSource, ['spotify']),
        },
      });
    } else {
      const slug = await uniqueDJSlugForName(finalName);
      persisted = await prisma.dJ.create({
        data: {
          name: finalName,
          nameI18n: (normalizeDJBiText(payload.nameI18n ?? null, finalName) as unknown as Prisma.InputJsonValue | null) ?? undefined,
          aliases: mergedAliases,
          genres: hasGenresInput ? requestedGenres : derivedGenres,
          slug,
          bio: requestedBio || derivedBio || null,
          bioI18n: (normalizeDJBiText(payload.bioI18n ?? null, requestedBio || derivedBio || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          country: requestedCountry || null,
          countryI18n: (normalizeDJBiText(payload.countryI18n ?? null, requestedCountry || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          spotifyId: spotifyArtist.id,
          spotifyFollowers: hasSpotifyFollowersInput ? requestedSpotifyFollowers : derivedSpotifyFollowers,
          followerCount: spotifyArtist.followers || 0,
          instagramUrl: requestedInstagram || null,
          facebookUrl: requestedFacebook || null,
          soundcloudUrl: requestedSoundcloud || null,
          soundcloudId: requestedSoundcloudId || null,
          website: requestedWebsite || null,
          trackCount: hasTrackCountInput ? requestedTrackCount : null,
          playlistCount: hasPlaylistCountInput ? requestedPlaylistCount : null,
          soundCloudFollowers: hasSoundCloudFollowersInput ? requestedSoundCloudFollowers : null,
          soundCloudFavorites: hasSoundCloudFavoritesInput ? requestedSoundCloudFavorites : null,
          twitterUrl: requestedTwitter || null,
          youtubeUrl: requestedYoutube || null,
          isVerified: requestedVerified,
          avatarSourceUrl: spotifyArtist.imageUrl || null,
          avatarUrl: null,
          sourceDataSource: mergeDJDataSources(null, ['spotify']),
        },
      });
    }

    let avatarUploadedToOss = false;
    let replacedExistingAvatar = false;
    if (spotifyArtist.imageUrl) {
      const uploadedAvatar = await uploadRemoteDJAvatarToOss(persisted.id, spotifyArtist.imageUrl);
      if (uploadedAvatar) {
        avatarUploadedToOss = true;
        replacedExistingAvatar = Boolean(previousAvatarUrl && previousAvatarUrl !== uploadedAvatar.url);
        const updated = await prisma.dJ.update({
          where: { id: persisted.id },
          data: {
            avatarUrl: uploadedAvatar.url,
            avatarSourceUrl: spotifyArtist.imageUrl,
          },
        });
        if (previousAvatarUrl && previousAvatarUrl !== uploadedAvatar.url) {
          await deleteSingleDJAvatarOssObjectIfOwned(previousAvatarUrl, persisted.id);
        }
        persisted = updated;
      } else if (!persisted.avatarUrl) {
        persisted = await prisma.dJ.update({
          where: { id: persisted.id },
          data: {
            avatarUrl: spotifyArtist.imageUrl,
            avatarSourceUrl: spotifyArtist.imageUrl,
          },
        });
      }
    }

    await ensureDJContributor(persisted.id, userId);
    const hydrated = await fetchDJWithContributorsById(persisted.id);
    const mapped = mapDJ(hydrated ?? persisted, false, userId, viewerRole);

    ok(res, {
      action,
      avatarUploadedToOss,
      replacedExistingAvatar,
      dj: mapped,
    });
  } catch (error) {
    if (error instanceof SpotifyUpstreamError) {
      console.error('BFF web spotify dj import upstream error:', {
        code: error.code,
        status: error.status,
        message: error.message,
      });
      res.status(503).json({
        error: 'Spotify 服务暂时不可用，请稍后重试',
        errorCode: error.code,
      });
      return;
    }
    console.error('BFF web spotify dj import error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/djs/discogs/import', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    if (!discogsArtistService.isConfigured()) {
      res.status(503).json({ error: 'Discogs token is not configured' });
      return;
    }

    const payload = (req.body ?? {}) as Record<string, unknown>;
    const rawArtistId = payload.discogsArtistId ?? payload.artistId;
    const discogsArtistId = Number(rawArtistId);
    if (!Number.isFinite(discogsArtistId) || discogsArtistId <= 0) {
      res.status(400).json({ error: 'discogsArtistId is required and must be a positive number' });
      return;
    }

    const discogsArtist = await discogsArtistService.getArtistById(Math.floor(discogsArtistId));
    if (!discogsArtist) {
      res.status(404).json({ error: 'Discogs artist not found' });
      return;
    }

    const requestedName = typeof payload.name === 'string' ? payload.name.trim() : '';
    const finalName = requestedName || discogsArtist.name.trim();
    if (!finalName) {
      res.status(400).json({ error: 'DJ name is empty' });
      return;
    }

    const hasAliasesInput = Object.prototype.hasOwnProperty.call(payload, 'aliases');
    let requestedAliases: string[] = [];
    if (hasAliasesInput) {
      const aliasValue = payload.aliases;
      if (aliasValue !== null && !Array.isArray(aliasValue)) {
        res.status(400).json({ error: 'aliases must be an array or null' });
        return;
      }
      requestedAliases = Array.isArray(aliasValue)
        ? aliasValue.map((item) => (typeof item === 'string' ? item.trim() : '')).filter(Boolean)
        : [];
    }
    const requestedBio = typeof payload.bio === 'string' ? payload.bio.trim() : '';
    const requestedCountry = typeof payload.country === 'string' ? payload.country.trim() : '';
    const hasGenresInput = Object.prototype.hasOwnProperty.call(payload, 'genres');
    if (hasGenresInput && payload.genres !== null && !Array.isArray(payload.genres) && typeof payload.genres !== 'string') {
      res.status(400).json({ error: 'genres must be an array, string, or null' });
      return;
    }
    const requestedGenres = hasGenresInput ? normalizeGenres(payload.genres) : [];
    const requestedInstagram = typeof payload.instagramUrl === 'string' ? payload.instagramUrl.trim() : '';
    const requestedFacebook = typeof payload.facebookUrl === 'string' ? payload.facebookUrl.trim() : '';
    const requestedSoundcloud = typeof payload.soundcloudUrl === 'string' ? payload.soundcloudUrl.trim() : '';
    const requestedTwitter = typeof payload.twitterUrl === 'string' ? payload.twitterUrl.trim() : '';
    const requestedYoutube = typeof payload.youtubeUrl === 'string' ? payload.youtubeUrl.trim() : '';
    const requestedSpotifyId = typeof payload.spotifyId === 'string' ? payload.spotifyId.trim() : '';
    const requestedSoundcloudId = parseOptionalStringFromPayload(payload, ['soundcloudId', 'soundcloudid']);
    const requestedWebsite = parseOptionalStringFromPayload(payload, ['website', 'websiteUrl', 'officialWebsite']);
    const hasTrackCountInput = payloadHasAnyKey(payload, ['trackCount', 'track_count']);
    const hasPlaylistCountInput = payloadHasAnyKey(payload, ['playlistCount', 'playlist_count']);
    const hasSoundCloudFollowersInput = payloadHasAnyKey(payload, [
      'soundCloudFollowers',
      'soundcloudFollowers',
      'followers_count',
    ]);
    const hasSoundCloudFavoritesInput = payloadHasAnyKey(payload, [
      'soundCloudFavorites',
      'soundcloudFavorites',
      'public_favorites_count',
    ]);
    let requestedTrackCount: number | null = null;
    let requestedPlaylistCount: number | null = null;
    let requestedSoundCloudFollowers: number | null = null;
    let requestedSoundCloudFavorites: number | null = null;
    try {
      if (hasTrackCountInput) {
        requestedTrackCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['trackCount', 'track_count']),
          'trackCount'
        );
      }
      if (hasPlaylistCountInput) {
        requestedPlaylistCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['playlistCount', 'playlist_count']),
          'playlistCount'
        );
      }
      if (hasSoundCloudFollowersInput) {
        requestedSoundCloudFollowers = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFollowers', 'soundcloudFollowers', 'followers_count']),
          'soundCloudFollowers'
        );
      }
      if (hasSoundCloudFavoritesInput) {
        requestedSoundCloudFavorites = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFavorites', 'soundcloudFavorites', 'public_favorites_count']),
          'soundCloudFavorites'
        );
      }
    } catch (error) {
      res.status(400).json({ error: (error as Error).message });
      return;
    }
    const hasSpotifyFollowersInput = Object.prototype.hasOwnProperty.call(payload, 'spotifyFollowers');
    let requestedSpotifyFollowers: number | null = null;
    if (hasSpotifyFollowersInput) {
      try {
        requestedSpotifyFollowers = parseOptionalNonNegativeInt(payload.spotifyFollowers, 'spotifyFollowers');
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }
    const requestedVerified =
      typeof payload.isVerified === 'boolean' ? payload.isVerified : true;

    const existingBySpotifyId = requestedSpotifyId
      ? await prisma.dJ.findFirst({
          where: { spotifyId: requestedSpotifyId },
        })
      : null;
    const existingByName = existingBySpotifyId
      ? null
      : await prisma.dJ.findFirst({
          where: { name: { equals: finalName, mode: 'insensitive' } },
          orderBy: { createdAt: 'asc' },
        });
    const target = existingBySpotifyId ?? existingByName;
    if (target) {
      const allowed = await canUserEditDJ(target.id, userId, viewerRole);
      if (!allowed) {
        res.status(403).json({ error: '仅该 DJ 的贡献者或管理员可修改信息' });
        return;
      }
    }

    const derivedBio = discogsArtist.profile?.trim() || '';
    const derivedInstagram = pickFirstUrlByHosts(discogsArtist.urls, ['instagram.com']);
    const derivedFacebook = pickFirstUrlByHosts(discogsArtist.urls, ['facebook.com', 'fb.com']);
    const derivedSoundcloud = pickFirstUrlByHosts(discogsArtist.urls, ['soundcloud.com']);
    const derivedTwitter = pickFirstUrlByHosts(discogsArtist.urls, ['twitter.com', 'x.com']);
    const derivedYoutube = pickFirstUrlByHosts(discogsArtist.urls, ['youtube.com', 'youtu.be']);
    const mergedAliases = hasAliasesInput
      ? mergeAliases(finalName, requestedAliases)
      : mergeAliases(finalName, [
          ...(target?.aliases ?? []),
          discogsArtist.name,
          discogsArtist.realName,
          ...discogsArtist.nameVariations,
          ...discogsArtist.aliases,
          ...discogsArtist.groups,
        ]);

    let action: 'created' | 'updated' = 'created';
    let previousAvatarUrl: string | null = null;
    let persisted: any;

    if (target) {
      action = 'updated';
      previousAvatarUrl = target.avatarUrl ?? null;
      persisted = await prisma.dJ.update({
        where: { id: target.id },
        data: {
          name: target.name || finalName,
          nameI18n: (normalizeDJBiText(target.nameI18n ?? null, target.name || finalName) as unknown as Prisma.InputJsonValue | null) ?? undefined,
          aliases: mergedAliases,
          genres: hasGenresInput ? requestedGenres : (target.genres ?? []),
          bio: requestedBio || target.bio || derivedBio || null,
          bioI18n: (normalizeDJBiText(target.bioI18n ?? null, requestedBio || target.bio || derivedBio || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          country: requestedCountry || target.country || null,
          countryI18n: (normalizeDJBiText(target.countryI18n ?? null, requestedCountry || target.country || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          spotifyId: requestedSpotifyId || target.spotifyId || null,
          spotifyFollowers: hasSpotifyFollowersInput ? requestedSpotifyFollowers : (target.spotifyFollowers ?? null),
          instagramUrl: requestedInstagram || target.instagramUrl || derivedInstagram || null,
          facebookUrl: requestedFacebook || target.facebookUrl || derivedFacebook || null,
          soundcloudUrl: requestedSoundcloud || target.soundcloudUrl || derivedSoundcloud || null,
          soundcloudId: requestedSoundcloudId || target.soundcloudId || null,
          website: requestedWebsite || target.website || null,
          trackCount: hasTrackCountInput ? requestedTrackCount : (target.trackCount ?? null),
          playlistCount: hasPlaylistCountInput ? requestedPlaylistCount : (target.playlistCount ?? null),
          soundCloudFollowers: hasSoundCloudFollowersInput
            ? requestedSoundCloudFollowers
            : (target.soundCloudFollowers ?? null),
          soundCloudFavorites: hasSoundCloudFavoritesInput
            ? requestedSoundCloudFavorites
            : (target.soundCloudFavorites ?? null),
          twitterUrl: requestedTwitter || target.twitterUrl || derivedTwitter || null,
          youtubeUrl: requestedYoutube || target.youtubeUrl || derivedYoutube || null,
          isVerified: target.isVerified || requestedVerified,
          avatarSourceUrl: discogsArtist.primaryImageUrl || target.avatarSourceUrl || null,
          sourceDataSource: mergeDJDataSources(target.sourceDataSource, [
            'discogs',
            requestedSpotifyId ? 'spotify' : null,
          ]),
        },
      });
    } else {
      const slug = await uniqueDJSlugForName(finalName);
      persisted = await prisma.dJ.create({
        data: {
          name: finalName,
          nameI18n: (normalizeDJBiText(payload.nameI18n ?? null, finalName) as unknown as Prisma.InputJsonValue | null) ?? undefined,
          aliases: mergedAliases,
          genres: hasGenresInput ? requestedGenres : [],
          slug,
          bio: requestedBio || derivedBio || null,
          bioI18n: (normalizeDJBiText(payload.bioI18n ?? null, requestedBio || derivedBio || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          country: requestedCountry || null,
          countryI18n: (normalizeDJBiText(payload.countryI18n ?? null, requestedCountry || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          spotifyId: requestedSpotifyId || null,
          spotifyFollowers: hasSpotifyFollowersInput ? requestedSpotifyFollowers : null,
          instagramUrl: requestedInstagram || derivedInstagram || null,
          facebookUrl: requestedFacebook || derivedFacebook || null,
          soundcloudUrl: requestedSoundcloud || derivedSoundcloud || null,
          soundcloudId: requestedSoundcloudId || null,
          website: requestedWebsite || null,
          trackCount: hasTrackCountInput ? requestedTrackCount : null,
          playlistCount: hasPlaylistCountInput ? requestedPlaylistCount : null,
          soundCloudFollowers: hasSoundCloudFollowersInput ? requestedSoundCloudFollowers : null,
          soundCloudFavorites: hasSoundCloudFavoritesInput ? requestedSoundCloudFavorites : null,
          twitterUrl: requestedTwitter || derivedTwitter || null,
          youtubeUrl: requestedYoutube || derivedYoutube || null,
          isVerified: requestedVerified,
          avatarSourceUrl: discogsArtist.primaryImageUrl || null,
          avatarUrl: null,
          sourceDataSource: mergeDJDataSources(null, [
            'discogs',
            requestedSpotifyId ? 'spotify' : null,
          ]),
        },
      });
    }

    let avatarUploadedToOss = false;
    let replacedExistingAvatar = false;
    if (discogsArtist.primaryImageUrl) {
      const uploadedAvatar = await uploadRemoteDJAvatarToOss(persisted.id, discogsArtist.primaryImageUrl);
      if (uploadedAvatar) {
        avatarUploadedToOss = true;
        replacedExistingAvatar = Boolean(previousAvatarUrl && previousAvatarUrl !== uploadedAvatar.url);
        const updated = await prisma.dJ.update({
          where: { id: persisted.id },
          data: {
            avatarUrl: uploadedAvatar.url,
            avatarSourceUrl: discogsArtist.primaryImageUrl,
          },
        });
        if (previousAvatarUrl && previousAvatarUrl !== uploadedAvatar.url) {
          await deleteSingleDJAvatarOssObjectIfOwned(previousAvatarUrl, persisted.id);
        }
        persisted = updated;
      } else if (!persisted.avatarUrl) {
        persisted = await prisma.dJ.update({
          where: { id: persisted.id },
          data: {
            avatarUrl: discogsArtist.primaryImageUrl,
            avatarSourceUrl: discogsArtist.primaryImageUrl,
          },
        });
      }
    }

    await ensureDJContributor(persisted.id, userId);
    const hydrated = await fetchDJWithContributorsById(persisted.id);
    const mapped = mapDJ(hydrated ?? persisted, false, userId, viewerRole);

    ok(res, {
      action,
      avatarUploadedToOss,
      replacedExistingAvatar,
      dj: mapped,
    });
  } catch (error) {
    if (error instanceof DiscogsUpstreamError) {
      console.error('BFF web discogs dj import upstream error:', {
        code: error.code,
        status: error.status,
        message: error.message,
      });
      res.status(503).json({
        error: 'Discogs 服务暂时不可用，请稍后重试',
        errorCode: error.code,
      });
      return;
    }
    console.error('BFF web discogs dj import error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/djs/manual/import', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const payload = (req.body ?? {}) as Record<string, unknown>;
    const name = typeof payload.name === 'string' ? payload.name.trim() : '';
    if (!name) {
      res.status(400).json({ error: 'name is required' });
      return;
    }

    const spotifyId = typeof payload.spotifyId === 'string' ? payload.spotifyId.trim() : '';
    const aliases = Array.isArray(payload.aliases)
      ? payload.aliases.map((item) => (typeof item === 'string' ? item.trim() : '')).filter(Boolean)
      : [];
    const bio = typeof payload.bio === 'string' ? payload.bio.trim() : '';
    const country = typeof payload.country === 'string' ? payload.country.trim() : '';
    const hasGenresInput = Object.prototype.hasOwnProperty.call(payload, 'genres');
    if (hasGenresInput && payload.genres !== null && !Array.isArray(payload.genres) && typeof payload.genres !== 'string') {
      res.status(400).json({ error: 'genres must be an array, string, or null' });
      return;
    }
    const genres = hasGenresInput ? normalizeGenres(payload.genres) : [];
    const hasSpotifyFollowersInput = Object.prototype.hasOwnProperty.call(payload, 'spotifyFollowers');
    let spotifyFollowers: number | null = null;
    if (hasSpotifyFollowersInput) {
      try {
        spotifyFollowers = parseOptionalNonNegativeInt(payload.spotifyFollowers, 'spotifyFollowers');
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }
    const instagramUrl = typeof payload.instagramUrl === 'string' ? payload.instagramUrl.trim() : '';
    const facebookUrl = typeof payload.facebookUrl === 'string' ? payload.facebookUrl.trim() : '';
    const soundcloudUrl = typeof payload.soundcloudUrl === 'string' ? payload.soundcloudUrl.trim() : '';
    const twitterUrl = typeof payload.twitterUrl === 'string' ? payload.twitterUrl.trim() : '';
    const youtubeUrl = typeof payload.youtubeUrl === 'string' ? payload.youtubeUrl.trim() : '';
    const soundcloudId = parseOptionalStringFromPayload(payload, ['soundcloudId', 'soundcloudid']);
    const website = parseOptionalStringFromPayload(payload, ['website', 'websiteUrl', 'officialWebsite']);
    const hasTrackCountInput = payloadHasAnyKey(payload, ['trackCount', 'track_count']);
    const hasPlaylistCountInput = payloadHasAnyKey(payload, ['playlistCount', 'playlist_count']);
    const hasSoundCloudFollowersInput = payloadHasAnyKey(payload, [
      'soundCloudFollowers',
      'soundcloudFollowers',
      'followers_count',
    ]);
    const hasSoundCloudFavoritesInput = payloadHasAnyKey(payload, [
      'soundCloudFavorites',
      'soundcloudFavorites',
      'public_favorites_count',
    ]);
    let trackCount: number | null = null;
    let playlistCount: number | null = null;
    let soundCloudFollowers: number | null = null;
    let soundCloudFavorites: number | null = null;
    try {
      if (hasTrackCountInput) {
        trackCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['trackCount', 'track_count']),
          'trackCount'
        );
      }
      if (hasPlaylistCountInput) {
        playlistCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['playlistCount', 'playlist_count']),
          'playlistCount'
        );
      }
      if (hasSoundCloudFollowersInput) {
        soundCloudFollowers = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFollowers', 'soundcloudFollowers', 'followers_count']),
          'soundCloudFollowers'
        );
      }
      if (hasSoundCloudFavoritesInput) {
        soundCloudFavorites = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFavorites', 'soundcloudFavorites', 'public_favorites_count']),
          'soundCloudFavorites'
        );
      }
    } catch (error) {
      res.status(400).json({ error: (error as Error).message });
      return;
    }
    const isVerified = typeof payload.isVerified === 'boolean' ? payload.isVerified : true;

    const existingBySpotifyId = spotifyId
      ? await prisma.dJ.findFirst({
          where: { spotifyId },
        })
      : null;
    const existingByName = existingBySpotifyId
      ? null
      : await prisma.dJ.findFirst({
          where: { name: { equals: name, mode: 'insensitive' } },
          orderBy: { createdAt: 'asc' },
        });
    const target = existingBySpotifyId ?? existingByName;
    if (target) {
      const allowed = await canUserEditDJ(target.id, userId, viewerRole);
      if (!allowed) {
        res.status(403).json({ error: '仅该 DJ 的贡献者或管理员可修改信息' });
        return;
      }
    }

    const mergedAliases = mergeAliases(name, [...(target?.aliases ?? []), ...aliases]);

    let action: 'created' | 'updated' = 'created';
    let persisted: any;
    if (target) {
      action = 'updated';
      persisted = await prisma.dJ.update({
        where: { id: target.id },
        data: {
          name: target.name || name,
          nameI18n: (normalizeDJBiText(target.nameI18n ?? null, target.name || name) as unknown as Prisma.InputJsonValue | null) ?? undefined,
          aliases: mergedAliases,
          genres: hasGenresInput ? genres : (target.genres ?? []),
          bio: bio || target.bio || null,
          bioI18n: (normalizeDJBiText(target.bioI18n ?? null, bio || target.bio || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          country: country || target.country || null,
          countryI18n: (normalizeDJBiText(target.countryI18n ?? null, country || target.country || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          spotifyId: spotifyId || target.spotifyId || null,
          spotifyFollowers: hasSpotifyFollowersInput ? spotifyFollowers : (target.spotifyFollowers ?? null),
          instagramUrl: instagramUrl || target.instagramUrl || null,
          facebookUrl: facebookUrl || target.facebookUrl || null,
          soundcloudUrl: soundcloudUrl || target.soundcloudUrl || null,
          soundcloudId: soundcloudId || target.soundcloudId || null,
          website: website || target.website || null,
          trackCount: hasTrackCountInput ? trackCount : (target.trackCount ?? null),
          playlistCount: hasPlaylistCountInput ? playlistCount : (target.playlistCount ?? null),
          soundCloudFollowers: hasSoundCloudFollowersInput
            ? soundCloudFollowers
            : (target.soundCloudFollowers ?? null),
          soundCloudFavorites: hasSoundCloudFavoritesInput
            ? soundCloudFavorites
            : (target.soundCloudFavorites ?? null),
          twitterUrl: twitterUrl || target.twitterUrl || null,
          youtubeUrl: youtubeUrl || target.youtubeUrl || null,
          isVerified: target.isVerified || isVerified,
          sourceDataSource: mergeDJDataSources(target.sourceDataSource, ['manual']),
        },
      });
    } else {
      const slug = await uniqueDJSlugForName(name);
      persisted = await prisma.dJ.create({
        data: {
          name,
          nameI18n: (normalizeDJBiText(payload.nameI18n ?? null, name) as unknown as Prisma.InputJsonValue | null) ?? undefined,
          aliases: mergedAliases,
          genres,
          slug,
          bio: bio || null,
          bioI18n: (normalizeDJBiText(payload.bioI18n ?? null, bio || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          country: country || null,
          countryI18n: (normalizeDJBiText(payload.countryI18n ?? null, country || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          spotifyId: spotifyId || null,
          spotifyFollowers,
          instagramUrl: instagramUrl || null,
          facebookUrl: facebookUrl || null,
          soundcloudUrl: soundcloudUrl || null,
          soundcloudId: soundcloudId || null,
          website: website || null,
          trackCount: hasTrackCountInput ? trackCount : null,
          playlistCount: hasPlaylistCountInput ? playlistCount : null,
          soundCloudFollowers: hasSoundCloudFollowersInput ? soundCloudFollowers : null,
          soundCloudFavorites: hasSoundCloudFavoritesInput ? soundCloudFavorites : null,
          twitterUrl: twitterUrl || null,
          youtubeUrl: youtubeUrl || null,
          isVerified,
          sourceDataSource: mergeDJDataSources(null, ['manual']),
        },
      });
    }

    await ensureDJContributor(persisted.id, userId);
    const hydrated = await fetchDJWithContributorsById(persisted.id);
    const mapped = mapDJ(hydrated ?? persisted, false, userId, viewerRole);

    ok(res, {
      action,
      dj: mapped,
    });
  } catch (error) {
    console.error('BFF web manual dj import error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/djs/upload-image', optionalAuth, djImageUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    const formBody = req.body as Record<string, unknown>;
    const djId = typeof formBody.djId === 'string' ? formBody.djId.trim() : '';
    const usageRaw = typeof formBody.usage === 'string' ? formBody.usage.trim().toLowerCase() : '';
    const usage: 'avatar' | 'banner' | null =
      usageRaw === 'avatar' || usageRaw === 'banner' ? usageRaw : null;

    if (!djId) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(400).json({ error: 'djId is required' });
      return;
    }
    if (!usage) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(400).json({ error: 'usage must be avatar or banner' });
      return;
    }

    const existing = await prisma.dJ.findUnique({
      where: { id: djId },
      select: { id: true, avatarUrl: true, bannerUrl: true },
    });
    if (!existing) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    const allowed = await canUserEditDJ(existing.id, userId, viewerRole);
    if (!allowed) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(403).json({ error: '仅该 DJ 的贡献者或管理员可修改信息' });
      return;
    }

    const uploaded = await uploadDJMediaToOss(file, djId, usage);
    const previousUrl = usage === 'avatar' ? existing.avatarUrl : existing.bannerUrl;

    await prisma.dJ.update({
      where: { id: djId },
      data:
        usage === 'avatar'
          ? {
              avatarUrl: uploaded.url,
              avatarSourceUrl: uploaded.url,
            }
          : {
              bannerUrl: uploaded.url,
            },
    });

    if (previousUrl && previousUrl !== uploaded.url) {
      await deleteSingleDJMediaOssObjectIfOwned(previousUrl, djId);
    }

    await ensureDJContributor(djId, userId);

    ok(res, uploaded);
  } catch (error) {
    console.error('BFF web upload dj image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/djs/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const djId = typeof req.params.id === 'string' ? req.params.id.trim() : '';
    if (!djId) {
      res.status(400).json({ error: 'DJ id is required' });
      return;
    }

    const existing = await fetchDJWithContributorsById(djId);
    if (!existing) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    const allowed = await canUserEditDJ(existing.id, userId, viewerRole);
    if (!allowed) {
      res.status(403).json({ error: '仅该 DJ 的贡献者或管理员可修改信息' });
      return;
    }

    const payload = (req.body ?? {}) as Record<string, unknown>;
    const updateData: Prisma.DJUpdateInput = {};
    const hasNameI18nField = Object.prototype.hasOwnProperty.call(payload, 'nameI18n');
    const hasBioI18nField = Object.prototype.hasOwnProperty.call(payload, 'bioI18n');
    const hasCountryI18nField = Object.prototype.hasOwnProperty.call(payload, 'countryI18n');

    let nextName = existing.name;
    let hasNameInput = false;
    if (Object.prototype.hasOwnProperty.call(payload, 'name')) {
      if (typeof payload.name !== 'string') {
        res.status(400).json({ error: 'name must be a string' });
        return;
      }
      const trimmed = payload.name.trim();
      if (!trimmed) {
        res.status(400).json({ error: 'name cannot be empty' });
        return;
      }
      hasNameInput = true;
      nextName = trimmed;
      updateData.name = trimmed;
    }

    const hasAliasesInput = Object.prototype.hasOwnProperty.call(payload, 'aliases');
    if (hasAliasesInput || hasNameInput) {
      let aliasCandidates: string[] = [];

      if (hasAliasesInput) {
        const aliasValue = payload.aliases;
        if (aliasValue !== null && !Array.isArray(aliasValue)) {
          res.status(400).json({ error: 'aliases must be an array or null' });
          return;
        }
        aliasCandidates = Array.isArray(aliasValue)
          ? aliasValue
              .map((item) => (typeof item === 'string' ? item.trim() : ''))
              .filter(Boolean)
          : [];
      } else {
        aliasCandidates = [...(existing.aliases ?? [])];
      }

      if (hasNameInput && normalizeDJNameKey(existing.name) !== normalizeDJNameKey(nextName)) {
        aliasCandidates.push(existing.name);
      }
      updateData.aliases = mergeAliases(nextName, aliasCandidates);
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'genres')) {
      const genreValue = payload.genres;
      if (genreValue === null) {
        updateData.genres = [];
      } else if (Array.isArray(genreValue) || typeof genreValue === 'string') {
        updateData.genres = normalizeGenres(genreValue);
      } else {
        res.status(400).json({ error: 'genres must be an array, string, or null' });
        return;
      }
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'spotifyFollowers')) {
      try {
        updateData.spotifyFollowers = parseOptionalNonNegativeInt(payload.spotifyFollowers, 'spotifyFollowers');
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }

    if (payloadHasAnyKey(payload, ['trackCount', 'track_count'])) {
      try {
        updateData.trackCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['trackCount', 'track_count']),
          'trackCount'
        );
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }

    if (payloadHasAnyKey(payload, ['playlistCount', 'playlist_count'])) {
      try {
        updateData.playlistCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['playlistCount', 'playlist_count']),
          'playlistCount'
        );
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }

    if (payloadHasAnyKey(payload, ['soundCloudFollowers', 'soundcloudFollowers', 'followers_count'])) {
      try {
        updateData.soundCloudFollowers = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFollowers', 'soundcloudFollowers', 'followers_count']),
          'soundCloudFollowers'
        );
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }

    if (payloadHasAnyKey(payload, ['soundCloudFavorites', 'soundcloudFavorites', 'public_favorites_count'])) {
      try {
        updateData.soundCloudFavorites = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFavorites', 'soundcloudFavorites', 'public_favorites_count']),
          'soundCloudFavorites'
        );
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }

    if (payloadHasAnyKey(payload, ['soundcloudId', 'soundcloudid'])) {
      const value = payloadValueByKeys(payload, ['soundcloudId', 'soundcloudid']);
      if (value === null) {
        updateData.soundcloudId = null;
      } else if (typeof value === 'string') {
        updateData.soundcloudId = value.trim() || null;
      } else {
        res.status(400).json({ error: 'soundcloudId must be a string or null' });
        return;
      }
    }

    if (payloadHasAnyKey(payload, ['website', 'websiteUrl', 'officialWebsite'])) {
      const value = payloadValueByKeys(payload, ['website', 'websiteUrl', 'officialWebsite']);
      if (value === null) {
        updateData.website = null;
      } else if (typeof value === 'string') {
        updateData.website = value.trim() || null;
      } else {
        res.status(400).json({ error: 'website must be a string or null' });
        return;
      }
    }

    const assignOptionalString = (
      payloadKey: string,
      targetKey:
        | 'bio'
        | 'country'
        | 'spotifyId'
        | 'appleMusicId'
        | 'instagramUrl'
        | 'facebookUrl'
        | 'soundcloudUrl'
        | 'soundcloudId'
        | 'website'
        | 'twitterUrl'
        | 'youtubeUrl'
    ) => {
      if (!Object.prototype.hasOwnProperty.call(payload, payloadKey)) return;
      const value = payload[payloadKey];
      if (value === null) {
        updateData[targetKey] = null;
        return;
      }
      if (typeof value !== 'string') {
        throw new Error(`${payloadKey} must be a string or null`);
      }
      const trimmed = value.trim();
      updateData[targetKey] = trimmed || null;
    };

    try {
      assignOptionalString('bio', 'bio');
      assignOptionalString('country', 'country');
      assignOptionalString('spotifyId', 'spotifyId');
      assignOptionalString('appleMusicId', 'appleMusicId');
      assignOptionalString('instagramUrl', 'instagramUrl');
      assignOptionalString('facebookUrl', 'facebookUrl');
      assignOptionalString('soundcloudUrl', 'soundcloudUrl');
      assignOptionalString('soundcloudId', 'soundcloudId');
      assignOptionalString('website', 'website');
      assignOptionalString('twitterUrl', 'twitterUrl');
      assignOptionalString('youtubeUrl', 'youtubeUrl');
    } catch (error) {
      res.status(400).json({ error: (error as Error).message });
      return;
    }

    if (hasNameI18nField) {
      const normalized = normalizeDJBiText(payload.nameI18n, nextName);
      if (normalized) {
        updateData.nameI18n = normalized as unknown as Prisma.InputJsonValue;
      }
    } else if (hasNameInput) {
      const normalized = normalizeDJBiText(existing.nameI18n ?? null, nextName);
      if (normalized) {
        updateData.nameI18n = normalized as unknown as Prisma.InputJsonValue;
      }
    }

    const hasBioField = Object.prototype.hasOwnProperty.call(payload, 'bio');
    if (hasBioI18nField) {
      const bioSeed = hasBioField
        ? (typeof payload.bio === 'string' ? payload.bio.trim() : '')
        : (existing.bio ?? '');
      const normalized = normalizeDJBiText(payload.bioI18n, bioSeed);
      if (normalized) {
        updateData.bioI18n = normalized as unknown as Prisma.InputJsonValue;
      }
    } else if (hasBioField) {
      const bioSeed = typeof payload.bio === 'string' ? payload.bio.trim() : '';
      const normalized = normalizeDJBiText(existing.bioI18n ?? null, bioSeed);
      if (normalized) {
        updateData.bioI18n = normalized as unknown as Prisma.InputJsonValue;
      }
    }

    const hasCountryField = Object.prototype.hasOwnProperty.call(payload, 'country');
    if (hasCountryI18nField) {
      const countrySeed = hasCountryField
        ? (typeof payload.country === 'string' ? payload.country.trim() : '')
        : (existing.country ?? '');
      const normalized = normalizeDJBiText(payload.countryI18n, countrySeed);
      if (normalized) {
        updateData.countryI18n = normalized as unknown as Prisma.InputJsonValue;
      }
    } else if (hasCountryField) {
      const countrySeed = typeof payload.country === 'string' ? payload.country.trim() : '';
      const normalized = normalizeDJBiText(existing.countryI18n ?? null, countrySeed);
      if (normalized) {
        updateData.countryI18n = normalized as unknown as Prisma.InputJsonValue;
      }
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'isVerified')) {
      if (typeof payload.isVerified !== 'boolean') {
        res.status(400).json({ error: 'isVerified must be a boolean' });
        return;
      }
      updateData.isVerified = payload.isVerified;
    }

    if (Object.keys(updateData).length === 0) {
      ok(res, mapDJ(existing, false, userId, viewerRole));
      return;
    }

    await prisma.dJ.update({
      where: { id: djId },
      data: updateData,
    });
    await ensureDJContributor(djId, userId);

    const updated = await fetchDJWithContributorsById(djId);
    if (!updated) {
      res.status(404).json({ error: 'DJ not found after update' });
      return;
    }

    ok(res, mapDJ(updated, false, userId, viewerRole));
  } catch (error) {
    console.error('BFF web update dj error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/djs/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const djId = typeof req.params.id === 'string' ? req.params.id.trim() : '';
    if (!djId) {
      res.status(400).json({ error: 'DJ id is required' });
      return;
    }

    const existing = await prisma.dJ.findUnique({
      where: { id: djId },
      select: {
        id: true,
        avatarUrl: true,
        avatarSourceUrl: true,
        bannerUrl: true,
      },
    });
    if (!existing) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    const allowed = await canUserEditDJ(existing.id, userId, viewerRole);
    if (!allowed) {
      res.status(403).json({ error: '仅该 DJ 的贡献者或管理员可删除' });
      return;
    }

    const urlsToDelete = [
      existing.avatarUrl,
      existing.avatarSourceUrl,
      existing.bannerUrl,
    ].filter((value): value is string => typeof value === 'string' && value.trim().length > 0);

    await prisma.dJ.delete({ where: { id: djId } });
    for (const url of urlsToDelete) {
      await deleteSingleDJMediaOssObjectIfOwned(url, djId);
    }
    await deleteDJOssFolder(djId);

    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete dj error:', error);
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
              select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
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

router.get('/djs/:id/rating-units', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const djId = req.params.id as string;
    const sourceDJ = await prisma.dJ.findUnique({
      where: { id: djId },
      select: { id: true, name: true },
    });
    if (!sourceDJ) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    const normalizedDJName = normalizeTextKey(sourceDJ.name);
    const rows = await prisma.ratingUnit.findMany({
      orderBy: [{ createdAt: 'desc' }],
      include: {
        event: {
          select: { id: true, name: true, description: true, imageUrl: true },
        },
        comments: {
          select: { score: true },
        },
        createdBy: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    const matchedRows = rows.filter((row) => {
      const names = parseActPerformerNames(row.name).map(normalizeTextKey);
      return names.includes(normalizedDJName);
    });

    const linkedRows = await attachLinkedDJsToRatingUnits(matchedRows as any[]);
    ok(res, { items: linkedRows.map((row) => mapRatingUnit(row)) });
  } catch (error) {
    console.error('BFF web dj rating units error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId;
    const viewerRole = authReq.user?.role ?? null;
    const djId = req.params.id as string;
    const row = await attachDJContributorInfo(
      await prisma.dJ.findUnique({
        where: { id: djId },
      })
    );
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

    ok(res, mapDJ(row, isFollowing, viewerId, viewerRole));
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
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

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

    const updated = await attachDJContributorInfo(
      await prisma.dJ.findUnique({
        where: { id: djId },
      })
    );
    ok(res, mapDJ(updated || dj, true, userId, viewerRole));
  } catch (error) {
    console.error('BFF web follow dj error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/djs/:id/follow', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

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

    const updated = await attachDJContributorInfo(
      await prisma.dJ.findUnique({
        where: { id: djId },
      })
    );
    ok(res, mapDJ(updated || dj, false, userId, viewerRole));
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
    const eventNameFilter = typeof req.query.eventName === 'string' ? req.query.eventName.trim() : '';

    let sets = await djSetService.getAllDJSets();
    if (djIdFilter) {
      sets = sets.filter((set) => set.djId === djIdFilter);
    }
    if (eventNameFilter) {
      const normalizedEventName = eventNameFilter.toLowerCase();
      sets = sets.filter((set) => {
        const currentEventName = typeof set.eventName === 'string' ? set.eventName.trim().toLowerCase() : '';
        return currentEventName.length > 0 && currentEventName === normalizedEventName;
      });
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

    if (looksLikePostMediaName(file.originalname || '', 'video')) {
      const uploaded = await uploadPostMediaToOss(file, 'video');
      ok(res, uploaded);
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
              nameI18n: true,
              locationI18n: true,
              countryI18n: true,
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
              nameI18n: true,
              avatarUrl: true,
              country: true,
              countryI18n: true,
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

    if (type === 'event' && eventId) {
      const existingAttendance = await prisma.checkin.findFirst({
        where: {
          userId,
          type: 'event',
          eventId,
          NOT: [
            { note: 'marked' },
          ],
        },
        orderBy: [{ attendedAt: 'desc' }, { createdAt: 'desc' }],
      });

      if (existingAttendance) {
        res.status(409).json({ error: '该活动已打卡，请直接编辑原有记录' });
        return;
      }
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
            nameI18n: true,
            locationI18n: true,
            countryI18n: true,
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
            nameI18n: true,
            avatarUrl: true,
            country: true,
            countryI18n: true,
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

router.patch('/checkins/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const checkinId = req.params.id as string;
    const existing = await prisma.checkin.findUnique({
      where: { id: checkinId },
      include: {
        event: {
          select: {
            id: true,
            name: true,
            nameI18n: true,
            locationI18n: true,
            countryI18n: true,
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
            nameI18n: true,
            avatarUrl: true,
            country: true,
            countryI18n: true,
          },
        },
      },
    });

    if (!existing) {
      res.status(404).json({ error: 'Checkin not found' });
      return;
    }

    if (authReq.user?.role !== 'admin' && existing.userId !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const nextEventId = typeof body.eventId === 'string' ? body.eventId : existing.eventId;
    const nextDjId = typeof body.djId === 'string' ? body.djId : existing.djId;
    const nextNote = typeof body.note === 'string' ? body.note : existing.note;
    const nextRating = typeof body.rating === 'number' ? body.rating : existing.rating;
    const attendedAt =
      typeof body.attendedAt === 'string' && body.attendedAt.trim().length > 0
        ? new Date(body.attendedAt)
        : existing.attendedAt;

    if (Number.isNaN(attendedAt.getTime())) {
      res.status(400).json({ error: 'attendedAt must be a valid ISO datetime' });
      return;
    }

    if (existing.type === 'event' && !nextEventId) {
      res.status(400).json({ error: 'eventId is required for event checkin' });
      return;
    }

    if (existing.type === 'dj' && !nextDjId) {
      res.status(400).json({ error: 'djId is required for dj checkin' });
      return;
    }

    if (existing.type === 'event' && nextEventId) {
      const conflicting = await prisma.checkin.findFirst({
        where: {
          id: { not: checkinId },
          userId,
          type: 'event',
          eventId: nextEventId,
          NOT: [
            { note: 'marked' },
          ],
        },
        orderBy: [{ attendedAt: 'desc' }, { createdAt: 'desc' }],
      });

      if (conflicting) {
        res.status(409).json({ error: '该活动已存在另一条打卡记录' });
        return;
      }
    }

    const updated = await prisma.checkin.update({
      where: { id: checkinId },
      data: {
        eventId: nextEventId ?? null,
        djId: existing.type === 'dj' ? nextDjId : null,
        note: nextNote ?? null,
        rating: nextRating ?? null,
        attendedAt,
      },
      include: {
        event: {
          select: {
            id: true,
            name: true,
            nameI18n: true,
            locationI18n: true,
            countryI18n: true,
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
            nameI18n: true,
            avatarUrl: true,
            country: true,
            countryI18n: true,
          },
        },
      },
    });

    ok(res, updated);
  } catch (error) {
    console.error('BFF web update checkin error:', error);
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

router.post('/rating/upload-image', optionalAuth, ratingImageUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    const formBody = req.body as Record<string, unknown>;
    const ratingEventId = typeof formBody.ratingEventId === 'string' ? formBody.ratingEventId.trim() : '';
    const ratingUnitId = typeof formBody.ratingUnitId === 'string' ? formBody.ratingUnitId.trim() : '';
    const usage = typeof formBody.usage === 'string' ? formBody.usage.trim() : '';

    if (ratingEventId) {
      const event = await prisma.ratingEvent.findUnique({
        where: { id: ratingEventId },
        select: { id: true, createdById: true },
      });
      if (!event) {
        await fs.promises.unlink(file.path).catch(() => undefined);
        res.status(404).json({ error: 'Rating event not found' });
        return;
      }
      if (authReq.user?.role !== 'admin' && event.createdById !== userId) {
        await fs.promises.unlink(file.path).catch(() => undefined);
        res.status(403).json({ error: 'Forbidden' });
        return;
      }
    }

    if (ratingUnitId) {
      const unit = await prisma.ratingUnit.findUnique({
        where: { id: ratingUnitId },
        select: { id: true, createdById: true, eventId: true },
      });
      if (!unit) {
        await fs.promises.unlink(file.path).catch(() => undefined);
        res.status(404).json({ error: 'Rating unit not found' });
        return;
      }
      if (authReq.user?.role !== 'admin' && unit.createdById !== userId) {
        await fs.promises.unlink(file.path).catch(() => undefined);
        res.status(403).json({ error: 'Forbidden' });
        return;
      }
    }

    const uploaded = await uploadRatingMediaToOss(
      file,
      {
        userId,
        ratingEventId: ratingEventId || null,
        ratingUnitId: ratingUnitId || null,
      },
      usage || null
    );
    ok(res, uploaded);
  } catch (error) {
    console.error('BFF web upload rating image error:', error);
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

    const rowsWithLinkedDJs = await Promise.all(
      rows.map(async (row) => ({
        ...row,
        sourceEventId: await resolveSourceEventIdForRatingEvent(row),
        units: await attachLinkedDJsToRatingUnits(row.units as any[]),
      }))
    );

    ok(res, { items: rowsWithLinkedDJs.map(mapRatingEvent) });
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

    const linkedUnits = await attachLinkedDJsToRatingUnits(row.units as any[]);
    const sourceEventId = await resolveSourceEventIdForRatingEvent({ ...row, units: linkedUnits });
    ok(res, mapRatingEvent({ ...row, sourceEventId, units: linkedUnits }));
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

router.post('/rating-events/from-event', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = req.body as Record<string, unknown>;
    const sourceEventId = typeof body.eventId === 'string' ? body.eventId.trim() : '';
    if (!sourceEventId) {
      res.status(400).json({ error: 'eventId is required' });
      return;
    }

    const sourceEvent = await prisma.event.findUnique({
      where: { id: sourceEventId },
      include: {
        lineupSlots: {
          orderBy: [{ startTime: 'asc' }, { sortOrder: 'asc' }],
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true },
            },
          },
        },
      },
    });
    if (!sourceEvent) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    const createdEvent = await prisma.ratingEvent.create({
      data: {
        createdById: userId,
        name: sourceEvent.name,
        description: sourceEvent.description ?? null,
        imageUrl: null,
      },
      select: { id: true },
    });

    let nextEventImageUrl: string | null = null;
    if (sourceEvent.coverImageUrl) {
      const uploadedCover = await uploadRemoteImageToRatingOss(
        {
          userId,
          ratingEventId: createdEvent.id,
        },
        sourceEvent.coverImageUrl,
        'event-cover'
      );
      if (uploadedCover?.url) {
        nextEventImageUrl = uploadedCover.url;
      }
    }

    const performerNamesToResolve = new Set<string>();
    const lineupActNamesBySlot = new Map<string, string[]>();
    for (const slot of sourceEvent.lineupSlots) {
      const names = parseActPerformerNames(slot.djName);
      lineupActNamesBySlot.set(slot.id, names);
      const firstName = names[0];
      if (firstName) {
        performerNamesToResolve.add(firstName.toLowerCase());
      }
    }

    const nameCandidates = Array.from(performerNamesToResolve);
    const allDJs = nameCandidates.length
      ? await prisma.dJ.findMany({
          where: {
            OR: nameCandidates.map((name) => ({
              name: {
                equals: name,
                mode: 'insensitive',
              },
            })),
          },
          select: { id: true, name: true, avatarUrl: true },
        })
      : [];
    const djByNormalizedName = new Map<string, { id: string; name: string; avatarUrl: string | null }>();
    for (const dj of allDJs) {
      djByNormalizedName.set(dj.name.trim().toLowerCase(), dj);
    }

    for (const slot of sourceEvent.lineupSlots) {
      const performerNames = lineupActNamesBySlot.get(slot.id) || [];
      const firstPerformerName = performerNames[0]?.trim() || slot.djName;
      const fallbackLineupDJ = slot.dj;
      const matchedFirstDJ =
        (firstPerformerName
          ? djByNormalizedName.get(firstPerformerName.toLowerCase()) || null
          : null) || fallbackLineupDJ;

      let unitImageUrl: string | null = null;
      const sourceAvatarUrl = matchedFirstDJ?.avatarUrl || null;

      const createdUnit = await prisma.ratingUnit.create({
        data: {
          eventId: createdEvent.id,
          createdById: userId,
          name: slot.djName,
          description: buildRatingUnitDescriptionFromLineupSlot(slot),
          imageUrl: null,
        },
        select: { id: true },
      });

      if (sourceAvatarUrl) {
        const uploadedAvatar = await uploadRemoteImageToRatingOss(
          {
            userId,
            ratingEventId: createdEvent.id,
            ratingUnitId: createdUnit.id,
          },
          sourceAvatarUrl,
          'unit-cover'
        );
        if (uploadedAvatar?.url) {
          unitImageUrl = uploadedAvatar.url;
        }
      }

      if (unitImageUrl) {
        await prisma.ratingUnit.update({
          where: { id: createdUnit.id },
          data: { imageUrl: unitImageUrl },
        });
      }
    }

    await prisma.ratingEvent.update({
      where: { id: createdEvent.id },
      data: {
        imageUrl: nextEventImageUrl,
      },
    });

    const created = await prisma.ratingEvent.findUnique({
      where: { id: createdEvent.id },
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

    if (!created) {
      res.status(500).json({ error: 'Failed to create rating event' });
      return;
    }

    const linkedUnits = await attachLinkedDJsToRatingUnits(created.units as any[]);
    ok(res, mapRatingEvent({ ...created, sourceEventId, units: linkedUnits }));
  } catch (error) {
    console.error('BFF web create rating event from event error:', error);
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

    const linkedRows = await attachLinkedDJsToRatingUnits([created as any]);
    ok(res, mapRatingUnit(linkedRows[0]));
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
      select: { id: true, createdById: true, imageUrl: true },
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
    const nextImageUrl = typeof body.imageUrl === 'string' ? body.imageUrl.trim() || null : undefined;
    const updated = await prisma.ratingEvent.update({
      where: { id: eventId },
      data: {
        name: typeof body.name === 'string' ? body.name.trim() : undefined,
        description: typeof body.description === 'string' ? body.description.trim() || null : undefined,
        imageUrl: nextImageUrl,
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

    if (nextImageUrl !== undefined && nextImageUrl !== existing.imageUrl) {
      await deleteSingleRatingOssObjectIfOwned(existing.imageUrl);
    }

    const linkedUnits = await attachLinkedDJsToRatingUnits(updated.units as any[]);
    ok(res, mapRatingEvent({ ...updated, units: linkedUnits }));
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
      select: {
        id: true,
        createdById: true,
        imageUrl: true,
        units: {
          select: { id: true, imageUrl: true },
        },
      },
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
    await deleteSingleRatingOssObjectIfOwned(existing.imageUrl);
    for (const unit of existing.units) {
      await deleteSingleRatingOssObjectIfOwned(unit.imageUrl);
    }
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

    const linkedRows = await attachLinkedDJsToRatingUnits([row as any]);
    ok(res, {
      ...mapRatingUnit(linkedRows[0], true),
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
      select: { id: true, createdById: true, imageUrl: true },
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
    const nextImageUrl = typeof body.imageUrl === 'string' ? body.imageUrl.trim() || null : undefined;
    const updated = await prisma.ratingUnit.update({
      where: { id: unitId },
      data: {
        name: typeof body.name === 'string' ? body.name.trim() : undefined,
        description: typeof body.description === 'string' ? body.description.trim() || null : undefined,
        imageUrl: nextImageUrl,
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

    if (nextImageUrl !== undefined && nextImageUrl !== existing.imageUrl) {
      await deleteSingleRatingOssObjectIfOwned(existing.imageUrl);
    }

    const linkedRows = await attachLinkedDJsToRatingUnits([updated as any]);
    ok(res, mapRatingUnit(linkedRows[0]));
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
      select: { id: true, createdById: true, imageUrl: true },
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
    await deleteSingleRatingOssObjectIfOwned(existing.imageUrl);
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

router.get('/learn/festivals', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId ?? null;
    const viewerRole = authReq.user?.role ?? null;
    const search = typeof req.query.search === 'string' ? req.query.search.trim().toLowerCase() : '';

    const rows = await prisma.wikiFestival.findMany({
      where: { isActive: true },
      orderBy: [{ name: 'asc' }],
      include: {
        contributors: {
          include: {
            user: {
              select: { id: true, username: true, displayName: true, avatarUrl: true },
            },
          },
        },
      },
    });

    const filteredRows = !search
      ? rows
      : rows.filter((row) => {
          const nameI18n = resolveBiTextWithFallback(row.nameI18n ?? null, row.name ?? '');
          const descriptionI18n = resolveBiTextWithFallback(row.descriptionI18n ?? null, row.introduction ?? '');
          const countryI18n = resolveBiTextWithFallback(row.countryI18n ?? null, row.country ?? '');
          const cityI18n = resolveBiTextWithFallback(row.cityI18n ?? null, row.city ?? '');
          const frequencyI18n = resolveBiTextWithFallback(row.frequencyI18n ?? null, row.frequency ?? '');
          const pool = [
            row.name,
            nameI18n?.zh,
            nameI18n?.en,
            row.abbreviation,
            ...(Array.isArray(row.aliases) ? row.aliases : []),
            row.country,
            countryI18n?.zh,
            countryI18n?.en,
            row.city,
            cityI18n?.zh,
            cityI18n?.en,
            row.frequency,
            frequencyI18n?.zh,
            frequencyI18n?.en,
            row.tagline,
            row.introduction,
            descriptionI18n?.zh,
            descriptionI18n?.en,
            row.officialWebsite,
            row.facebookUrl,
            row.instagramUrl,
            row.twitterUrl,
            row.youtubeUrl,
            row.tiktokUrl,
          ]
            .join(' ')
            .toLowerCase();
          return pool.includes(search);
        });

    ok(res, { items: filteredRows.map((row) => mapWikiFestival(row, viewerId, viewerRole)) });
  } catch (error) {
    console.error('BFF web learn festivals error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/learn/festivals', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const body = (req.body ?? {}) as Record<string, unknown>;
    const sourceRowIdRaw = normalizeWikiFestivalInteger(body.sourceRowId);
    if (Object.prototype.hasOwnProperty.call(body, 'sourceRowId') && body.sourceRowId !== null && body.sourceRowId !== '' && sourceRowIdRaw === null) {
      res.status(400).json({ error: 'sourceRowId must be an integer' });
      return;
    }

    const rawName = normalizeWikiFestivalText(body.name);
    const nameI18n = normalizeWikiFestivalBiText(body.nameI18n, rawName);
    const name = rawName || pickWikiFestivalPrimaryText(nameI18n);
    if (!name) {
      res.status(400).json({ error: 'name is required' });
      return;
    }

    const abbreviation = normalizeWikiFestivalText(body.abbreviation);
    const aliases = parseWikiFestivalAliases(body.aliases);
    const rawCountry = normalizeWikiFestivalText(body.country);
    const countryI18n = normalizeWikiFestivalBiText(body.countryI18n, rawCountry);
    const country = rawCountry || pickWikiFestivalPrimaryText(countryI18n);
    const rawCity = normalizeWikiFestivalText(body.city);
    const cityI18n = normalizeWikiFestivalBiText(body.cityI18n, rawCity);
    const city = rawCity || pickWikiFestivalPrimaryText(cityI18n);
    const foundedYear = normalizeWikiFestivalText(body.foundedYear);
    const rawFrequency = normalizeWikiFestivalText(body.frequency);
    const frequencyI18n = normalizeWikiFestivalBiText(body.frequencyI18n, rawFrequency);
    const frequency = rawFrequency || pickWikiFestivalPrimaryText(frequencyI18n);
    const tagline = normalizeWikiFestivalText(body.tagline);
    const rawIntroduction = normalizeWikiFestivalText(body.introduction);
    const descriptionI18n = normalizeWikiFestivalBiText(body.descriptionI18n, rawIntroduction);
    const introduction = rawIntroduction || pickWikiFestivalPrimaryText(descriptionI18n);
    const officialWebsite = normalizeWikiFestivalText(body.officialWebsite);
    const facebookUrl = normalizeWikiFestivalText(body.facebookUrl);
    const instagramUrl = normalizeWikiFestivalText(body.instagramUrl);
    const twitterUrl = normalizeWikiFestivalText(body.twitterUrl);
    const youtubeUrl = normalizeWikiFestivalText(body.youtubeUrl);
    const tiktokUrl = normalizeWikiFestivalText(body.tiktokUrl);
    const avatarUrl = normalizeWikiFestivalText(body.avatarUrl);
    const backgroundUrl = normalizeWikiFestivalText(body.backgroundUrl);
    const links = mergeWikiFestivalLinks(parseWikiFestivalLinks(body.links), {
      officialWebsite,
      facebookUrl,
      instagramUrl,
      twitterUrl,
      youtubeUrl,
      tiktokUrl,
    });
    const festivalId = await uniqueWikiFestivalIdForName(name);

    const created = await prisma.wikiFestival.create({
      data: {
        id: festivalId,
        sourceRowId: sourceRowIdRaw,
        name,
        nameI18n: nameI18n ? (nameI18n as unknown as Prisma.InputJsonValue) : undefined,
        abbreviation: abbreviation.length > 0 ? abbreviation : '',
        aliases,
        country: country || '',
        countryI18n: countryI18n ? (countryI18n as unknown as Prisma.InputJsonValue) : undefined,
        city: city || '',
        cityI18n: cityI18n ? (cityI18n as unknown as Prisma.InputJsonValue) : undefined,
        foundedYear,
        frequency: frequency || '',
        frequencyI18n: frequencyI18n ? (frequencyI18n as unknown as Prisma.InputJsonValue) : undefined,
        tagline,
        introduction: introduction || '',
        descriptionI18n: descriptionI18n ? (descriptionI18n as unknown as Prisma.InputJsonValue) : undefined,
        officialWebsite: officialWebsite.length > 0 ? officialWebsite : null,
        facebookUrl: facebookUrl.length > 0 ? facebookUrl : null,
        instagramUrl: instagramUrl.length > 0 ? instagramUrl : null,
        twitterUrl: twitterUrl.length > 0 ? twitterUrl : null,
        youtubeUrl: youtubeUrl.length > 0 ? youtubeUrl : null,
        tiktokUrl: tiktokUrl.length > 0 ? tiktokUrl : null,
        avatarUrl: avatarUrl.length > 0 ? avatarUrl : null,
        backgroundUrl: backgroundUrl.length > 0 ? backgroundUrl : null,
        links: links as unknown as Prisma.InputJsonValue,
        contributors: {
          create: {
            userId,
          },
        },
      },
      include: {
        contributors: {
          include: {
            user: {
              select: { id: true, username: true, displayName: true, avatarUrl: true },
            },
          },
        },
      },
    });

    ok(res, mapWikiFestival(created, userId, viewerRole));
  } catch (error) {
    console.error('BFF web create learn festival error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/learn/festivals/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const festivalId = req.params.id as string;
    const existing = await prisma.wikiFestival.findUnique({
      where: { id: festivalId },
      include: {
        contributors: {
          select: { userId: true },
        },
      },
    });

    if (!existing) {
      res.status(404).json({ error: 'Festival not found' });
      return;
    }

    const isContributor = existing.contributors.some((item) => item.userId === userId);
    const canEdit = viewerRole === 'admin' || isContributor;
    if (!canEdit) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const body = (req.body ?? {}) as Record<string, unknown>;
    const updateData: Prisma.WikiFestivalUpdateInput = {};
    const hasNameField = Object.prototype.hasOwnProperty.call(body, 'name');
    const hasNameI18nField = Object.prototype.hasOwnProperty.call(body, 'nameI18n');
    const hasSourceRowIdField = Object.prototype.hasOwnProperty.call(body, 'sourceRowId');
    const hasAbbreviationField = Object.prototype.hasOwnProperty.call(body, 'abbreviation');
    const hasCountryField = Object.prototype.hasOwnProperty.call(body, 'country');
    const hasCountryI18nField = Object.prototype.hasOwnProperty.call(body, 'countryI18n');
    const hasCityField = Object.prototype.hasOwnProperty.call(body, 'city');
    const hasCityI18nField = Object.prototype.hasOwnProperty.call(body, 'cityI18n');
    const hasFrequencyField = Object.prototype.hasOwnProperty.call(body, 'frequency');
    const hasFrequencyI18nField = Object.prototype.hasOwnProperty.call(body, 'frequencyI18n');
    const hasIntroductionField = Object.prototype.hasOwnProperty.call(body, 'introduction');
    const hasDescriptionI18nField = Object.prototype.hasOwnProperty.call(body, 'descriptionI18n');
    const hasOfficialWebsiteField = Object.prototype.hasOwnProperty.call(body, 'officialWebsite');
    const hasFacebookUrlField = Object.prototype.hasOwnProperty.call(body, 'facebookUrl');
    const hasInstagramUrlField = Object.prototype.hasOwnProperty.call(body, 'instagramUrl');
    const hasTwitterUrlField = Object.prototype.hasOwnProperty.call(body, 'twitterUrl');
    const hasYoutubeUrlField = Object.prototype.hasOwnProperty.call(body, 'youtubeUrl');
    const hasTiktokUrlField = Object.prototype.hasOwnProperty.call(body, 'tiktokUrl');
    const hasLinksField = Object.prototype.hasOwnProperty.call(body, 'links');

    if (hasSourceRowIdField) {
      if (body.sourceRowId === null || body.sourceRowId === '') {
        updateData.sourceRowId = null;
      } else {
        const sourceRowId = normalizeWikiFestivalInteger(body.sourceRowId);
        if (sourceRowId === null) {
          res.status(400).json({ error: 'sourceRowId must be an integer' });
          return;
        }
        updateData.sourceRowId = sourceRowId;
      }
    }

    let nextName = hasNameField ? normalizeWikiFestivalText(body.name) : existing.name;
    if (hasNameI18nField) {
      const normalized = normalizeWikiFestivalBiText(body.nameI18n, nextName);
      updateData.nameI18n = normalized ? (normalized as unknown as Prisma.InputJsonValue) : Prisma.DbNull;
      if (!hasNameField && normalized) {
        nextName = pickWikiFestivalPrimaryText(normalized, existing.name);
      }
    }
    if (hasNameField || hasNameI18nField) {
      const finalName = nextName || existing.name;
      if (!finalName) {
        res.status(400).json({ error: 'name is required' });
        return;
      }
      updateData.name = finalName;
    }

    if (hasAbbreviationField) {
      updateData.abbreviation = normalizeWikiFestivalText(body.abbreviation);
    }

    if (Object.prototype.hasOwnProperty.call(body, 'aliases')) {
      updateData.aliases = parseWikiFestivalAliases(body.aliases);
    }

    if (hasCountryField || hasCountryI18nField) {
      let nextCountry = hasCountryField ? normalizeWikiFestivalText(body.country) : existing.country;
      if (hasCountryI18nField) {
        const normalized = normalizeWikiFestivalBiText(body.countryI18n, nextCountry);
        updateData.countryI18n = normalized ? (normalized as unknown as Prisma.InputJsonValue) : Prisma.DbNull;
        if (!hasCountryField && normalized) {
          nextCountry = pickWikiFestivalPrimaryText(normalized, existing.country);
        }
      }
      updateData.country = nextCountry || '';
    }

    if (hasCityField || hasCityI18nField) {
      let nextCity = hasCityField ? normalizeWikiFestivalText(body.city) : existing.city;
      if (hasCityI18nField) {
        const normalized = normalizeWikiFestivalBiText(body.cityI18n, nextCity);
        updateData.cityI18n = normalized ? (normalized as unknown as Prisma.InputJsonValue) : Prisma.DbNull;
        if (!hasCityField && normalized) {
          nextCity = pickWikiFestivalPrimaryText(normalized, existing.city);
        }
      }
      updateData.city = nextCity || '';
    }

    if (Object.prototype.hasOwnProperty.call(body, 'foundedYear')) {
      updateData.foundedYear = normalizeWikiFestivalText(body.foundedYear);
    }

    if (hasFrequencyField || hasFrequencyI18nField) {
      let nextFrequency = hasFrequencyField ? normalizeWikiFestivalText(body.frequency) : existing.frequency;
      if (hasFrequencyI18nField) {
        const normalized = normalizeWikiFestivalBiText(body.frequencyI18n, nextFrequency);
        updateData.frequencyI18n = normalized ? (normalized as unknown as Prisma.InputJsonValue) : Prisma.DbNull;
        if (!hasFrequencyField && normalized) {
          nextFrequency = pickWikiFestivalPrimaryText(normalized, existing.frequency);
        }
      }
      updateData.frequency = nextFrequency || '';
    }

    if (Object.prototype.hasOwnProperty.call(body, 'tagline')) {
      updateData.tagline = normalizeWikiFestivalText(body.tagline);
    }

    if (hasIntroductionField || hasDescriptionI18nField) {
      let nextIntroduction = hasIntroductionField ? normalizeWikiFestivalText(body.introduction) : existing.introduction;
      if (hasDescriptionI18nField) {
        const normalized = normalizeWikiFestivalBiText(body.descriptionI18n, nextIntroduction);
        updateData.descriptionI18n = normalized ? (normalized as unknown as Prisma.InputJsonValue) : Prisma.DbNull;
        if (!hasIntroductionField && normalized) {
          nextIntroduction = pickWikiFestivalPrimaryText(normalized, existing.introduction);
        }
      }
      updateData.introduction = nextIntroduction || '';
    }

    if (Object.prototype.hasOwnProperty.call(body, 'avatarUrl')) {
      if (body.avatarUrl === null) {
        updateData.avatarUrl = null;
      } else {
        const avatarUrl = normalizeWikiFestivalText(body.avatarUrl);
        updateData.avatarUrl = avatarUrl.length > 0 ? avatarUrl : null;
      }
    }

    if (Object.prototype.hasOwnProperty.call(body, 'backgroundUrl')) {
      if (body.backgroundUrl === null) {
        updateData.backgroundUrl = null;
      } else {
        const backgroundUrl = normalizeWikiFestivalText(body.backgroundUrl);
        updateData.backgroundUrl = backgroundUrl.length > 0 ? backgroundUrl : null;
      }
    }

    const nextOfficialWebsite = hasOfficialWebsiteField
      ? normalizeWikiFestivalText(body.officialWebsite)
      : (existing.officialWebsite ?? '');
    const nextFacebookUrl = hasFacebookUrlField
      ? normalizeWikiFestivalText(body.facebookUrl)
      : (existing.facebookUrl ?? '');
    const nextInstagramUrl = hasInstagramUrlField
      ? normalizeWikiFestivalText(body.instagramUrl)
      : (existing.instagramUrl ?? '');
    const nextTwitterUrl = hasTwitterUrlField
      ? normalizeWikiFestivalText(body.twitterUrl)
      : (existing.twitterUrl ?? '');
    const nextYoutubeUrl = hasYoutubeUrlField
      ? normalizeWikiFestivalText(body.youtubeUrl)
      : (existing.youtubeUrl ?? '');
    const nextTiktokUrl = hasTiktokUrlField
      ? normalizeWikiFestivalText(body.tiktokUrl)
      : (existing.tiktokUrl ?? '');

    if (hasOfficialWebsiteField) {
      updateData.officialWebsite = nextOfficialWebsite.length > 0 ? nextOfficialWebsite : null;
    }
    if (hasFacebookUrlField) {
      updateData.facebookUrl = nextFacebookUrl.length > 0 ? nextFacebookUrl : null;
    }
    if (hasInstagramUrlField) {
      updateData.instagramUrl = nextInstagramUrl.length > 0 ? nextInstagramUrl : null;
    }
    if (hasTwitterUrlField) {
      updateData.twitterUrl = nextTwitterUrl.length > 0 ? nextTwitterUrl : null;
    }
    if (hasYoutubeUrlField) {
      updateData.youtubeUrl = nextYoutubeUrl.length > 0 ? nextYoutubeUrl : null;
    }
    if (hasTiktokUrlField) {
      updateData.tiktokUrl = nextTiktokUrl.length > 0 ? nextTiktokUrl : null;
    }

    if (
      hasLinksField ||
      hasOfficialWebsiteField ||
      hasFacebookUrlField ||
      hasInstagramUrlField ||
      hasTwitterUrlField ||
      hasYoutubeUrlField ||
      hasTiktokUrlField
    ) {
      const baseLinks = hasLinksField ? parseWikiFestivalLinks(body.links) : parseWikiFestivalLinks(existing.links);
      const mergedLinks = mergeWikiFestivalLinks(baseLinks, {
        officialWebsite: nextOfficialWebsite,
        facebookUrl: nextFacebookUrl,
        instagramUrl: nextInstagramUrl,
        twitterUrl: nextTwitterUrl,
        youtubeUrl: nextYoutubeUrl,
        tiktokUrl: nextTiktokUrl,
      });
      updateData.links = mergedLinks as unknown as Prisma.InputJsonValue;
    }

    const hasUpdateFields = Object.keys(updateData).length > 0;

    const updated = await prisma.$transaction(async (tx) => {
      if (hasUpdateFields) {
        await tx.wikiFestival.update({
          where: { id: festivalId },
          data: updateData,
        });
      }

      await tx.wikiFestivalContributor.upsert({
        where: {
          festivalId_userId: {
            festivalId,
            userId,
          },
        },
        create: {
          festivalId,
          userId,
        },
        update: {},
      });

      return tx.wikiFestival.findUnique({
        where: { id: festivalId },
        include: {
          contributors: {
            include: {
              user: {
                select: { id: true, username: true, displayName: true, avatarUrl: true },
              },
            },
          },
        },
      });
    });

    if (!updated) {
      res.status(404).json({ error: 'Festival not found' });
      return;
    }

    ok(res, mapWikiFestival(updated, userId, viewerRole));
  } catch (error) {
    console.error('BFF web update learn festival error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/learn/festivals/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const festivalId = req.params.id as string;
    const existing = await prisma.wikiFestival.findUnique({
      where: { id: festivalId },
      include: {
        contributors: {
          select: { userId: true },
        },
      },
    });

    if (!existing) {
      res.status(404).json({ error: 'Festival not found' });
      return;
    }

    const isContributor = existing.contributors.some((item) => item.userId === userId);
    const canDelete = viewerRole === 'admin' || isContributor;
    if (!canDelete) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const urlsToDelete = [
      existing.avatarUrl,
      existing.backgroundUrl,
    ].filter((value): value is string => typeof value === 'string' && value.trim().length > 0);

    await prisma.wikiFestival.delete({ where: { id: festivalId } });
    for (const url of urlsToDelete) {
      await deleteSingleWikiBrandOssObjectIfOwned(url, festivalId);
    }
    await deleteWikiBrandOssFolder(festivalId);

    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete learn festival error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
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
  const boards = loadRankingBoards();
  ok(
    res,
    boards.map((board) => ({
      id: board.id,
      title: board.title,
      subtitle: board.subtitle,
      description: board.description,
      coverImageUrl: board.coverImageUrl || null,
      years: board.years,
      entityType: board.entityType,
      createdAt: board.createdAt,
      updatedAt: board.updatedAt,
    }))
  );
});

router.get('/learn/rankings/:boardId', async (req: Request, res: Response): Promise<void> => {
  try {
    const boardId = sanitizeRankingBoardId(req.params.boardId as string);
    const boards = loadRankingBoards();
    const board = boards.find((item) => item.id === boardId);
    if (!board) {
      res.status(404).json({ error: 'Board not found' });
      return;
    }

    if (board.years.length === 0) {
      ok(res, {
        boardId: board.id,
        title: board.title,
        subtitle: board.subtitle,
        description: board.description,
        coverImageUrl: board.coverImageUrl || null,
        entityType: board.entityType,
        years: [],
        year: null,
        entries: [],
      });
      return;
    }

    const requestedYear = Number(req.query.year);
    const year = Number.isFinite(requestedYear) ? requestedYear : board.years[board.years.length - 1];
    if (!board.years.includes(year)) {
      res.status(400).json({ error: 'year is invalid' });
      return;
    }

    const currentYearData = loadRankingYearData(boardId, year);
    const current = currentYearData?.entries ?? [];
    const strictEntityBinding = Boolean(currentYearData && currentYearData.source !== 'legacy_txt');

    const prevYear = board.years[board.years.indexOf(year) - 1];
    const prev = prevYear
      ? loadRankingYearData(boardId, prevYear)?.entries ?? []
      : [];

    const previousRankMap: Record<string, number> = {};
    for (const item of prev) {
      previousRankMap[normalizeName(item.name)] = item.rank;
    }

    let entries: Array<Record<string, unknown>> = [];

    if (board.entityType === 'festival') {
      const festivals = await prisma.wikiFestival.findMany({
        where: { isActive: true },
        select: {
          id: true,
          name: true,
          nameI18n: true,
          aliases: true,
          avatarUrl: true,
          backgroundUrl: true,
          country: true,
          city: true,
          tagline: true,
        },
      });

      const festivalMap: Record<string, any> = {};
      const festivalMapById: Record<string, any> = {};
      for (const fest of festivals) {
        festivalMapById[fest.id] = fest;
        festivalMap[normalizeName(fest.name)] = fest;
        const nameI18n = resolveBiTextWithFallback(fest.nameI18n ?? null, fest.name ?? '');
        if (nameI18n?.zh) {
          festivalMap[normalizeName(nameI18n.zh)] = fest;
        }
        if (nameI18n?.en) {
          festivalMap[normalizeName(nameI18n.en)] = fest;
        }
        for (const alias of Array.isArray(fest.aliases) ? fest.aliases : []) {
          festivalMap[normalizeName(alias)] = fest;
        }
      }

      entries = current.map((item) => {
        const key = normalizeName(item.name);
        const prevRank = previousRankMap[key];
        const fest = (item.entityId ? festivalMapById[item.entityId] : null)
          || (strictEntityBinding ? null : festivalMap[key]);
        return {
          rank: item.rank,
          name: item.name,
          entityId: fest?.id || item.entityId || null,
          delta: prevYear && prevRank !== undefined ? prevRank - item.rank : null,
          festival: fest
            ? {
                id: fest.id,
                name: fest.name,
                avatarUrl: fest.avatarUrl,
                backgroundUrl: fest.backgroundUrl,
                country: fest.country,
                city: fest.city,
                tagline: fest.tagline,
              }
            : null,
          dj: null,
        };
      });
    } else {
      const djs = await prisma.dJ.findMany({
        select: {
          id: true,
          name: true,
          slug: true,
          avatarUrl: true,
          bannerUrl: true,
          followerCount: true,
          country: true,
          aliases: true,
        },
      });
      const djMap: Record<string, any> = {};
      const djMapById: Record<string, any> = {};
      for (const dj of djs) {
        djMapById[dj.id] = dj;
        djMap[normalizeName(dj.name)] = dj;
        for (const alias of Array.isArray(dj.aliases) ? dj.aliases : []) {
          djMap[normalizeName(alias)] = dj;
        }
      }

      entries = current.map((item) => {
        const key = normalizeName(item.name);
        const prevRank = previousRankMap[key];
        const matchedDJ = (item.entityId ? djMapById[item.entityId] : null)
          || (strictEntityBinding ? null : djMap[key]);
        return {
          rank: item.rank,
          name: item.name,
          entityId: matchedDJ?.id || item.entityId || null,
          delta: prevYear && prevRank !== undefined ? prevRank - item.rank : null,
          dj: matchedDJ
            ? {
                id: matchedDJ.id,
                name: matchedDJ.name,
                slug: matchedDJ.slug,
                avatarUrl: matchedDJ.avatarUrl,
                bannerUrl: matchedDJ.bannerUrl,
                followerCount: matchedDJ.followerCount,
                country: matchedDJ.country,
              }
            : null,
          festival: null,
        };
      });
    }

    ok(res, {
      boardId: board.id,
      title: board.title,
      subtitle: board.subtitle,
      description: board.description,
      coverImageUrl: board.coverImageUrl || null,
      entityType: board.entityType,
      years: board.years,
      year,
      strictEntityBinding,
      entries,
    });
  } catch (error) {
    console.error('BFF web rankings detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/learn/rankings/upload-image', optionalAuth, wikiBrandImageUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    if (!req.file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    if (!postMediaOssClient) {
      res.status(503).json({ error: 'OSS is not configured for ranking image upload' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const boardId = sanitizeRankingBoardId(String(body?.boardId || 'ranking-temp'));
    const usage = 'cover';
    const uploaded = await uploadWikiBrandMediaToOss(req.file, boardId, usage);
    ok(res, uploaded);
  } catch (error) {
    console.error('BFF web upload ranking image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/learn/rankings', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const body = (req.body ?? {}) as Record<string, unknown>;
    const title = String(body.title || '').trim();
    if (!title) {
      res.status(400).json({ error: 'title is required' });
      return;
    }

    const entityType: RankingEntityType = String(body.entityType || '').trim() === 'festival' ? 'festival' : 'dj';
    const requestedId = String(body.id || '').trim();
    const boardId = sanitizeRankingBoardId(requestedId || title);
    const boards = loadRankingBoards();
    if (boards.some((item) => item.id === boardId)) {
      res.status(409).json({ error: 'board id already exists' });
      return;
    }

    const nowIso = new Date().toISOString();
    const board: RankingBoardRecord = {
      id: boardId,
      title,
      subtitle: String(body.subtitle || '').trim(),
      description: String(body.description || '').trim(),
      coverImageUrl: String(body.coverImageUrl || '').trim() || null,
      entityType,
      years: normalizeRankingYears(body.years),
      createdAt: nowIso,
      updatedAt: nowIso,
    };

    const year = Number(body.year);
    const importText = String(body.importText || '').trim();
    const explicitEntries = parseRankingEntries(body.entries);
    const importedEntries = importText
      ? parseRankingText(importText).map((item) => ({ rank: item.rank, name: item.name }))
      : [];
    const finalEntries = explicitEntries.length > 0 ? explicitEntries : importedEntries;

    if (Number.isFinite(year) && year > 1900 && year < 2201 && finalEntries.length > 0) {
      saveRankingYearData(boardId, Math.floor(year), finalEntries, importText ? 'import_text' : 'manual_create');
      board.years = Array.from(new Set([...board.years, Math.floor(year)])).sort((a, b) => a - b);
    }

    saveRankingBoards([...boards, board]);

    ok(res, board);
  } catch (error) {
    console.error('BFF web create ranking board error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/learn/rankings/:boardId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const boardId = sanitizeRankingBoardId(String(req.params.boardId ?? ''));
    const body = (req.body ?? {}) as Record<string, unknown>;
    const boards = loadRankingBoards();
    const index = boards.findIndex((item) => item.id === boardId);
    if (index < 0) {
      res.status(404).json({ error: 'Board not found' });
      return;
    }

    const current = boards[index];
    const next: RankingBoardRecord = {
      ...current,
      title: Object.prototype.hasOwnProperty.call(body, 'title')
        ? String(body.title || '').trim() || current.title
        : current.title,
      subtitle: Object.prototype.hasOwnProperty.call(body, 'subtitle')
        ? String(body.subtitle || '').trim()
        : current.subtitle,
      description: Object.prototype.hasOwnProperty.call(body, 'description')
        ? String(body.description || '').trim()
        : current.description,
      coverImageUrl: Object.prototype.hasOwnProperty.call(body, 'coverImageUrl')
        ? (String(body.coverImageUrl || '').trim() || null)
        : current.coverImageUrl,
      entityType: Object.prototype.hasOwnProperty.call(body, 'entityType')
        ? (String(body.entityType || '').trim() === 'festival' ? 'festival' : 'dj')
        : current.entityType,
      years: Object.prototype.hasOwnProperty.call(body, 'years')
        ? normalizeRankingYears(body.years)
        : current.years,
      updatedAt: new Date().toISOString(),
    };

    boards[index] = next;
    saveRankingBoards(boards);
    ok(res, next);
  } catch (error) {
    console.error('BFF web update ranking board error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/learn/rankings/:boardId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const boardId = sanitizeRankingBoardId(String(req.params.boardId ?? ''));
    const boards = loadRankingBoards();
    const target = boards.find((item) => item.id === boardId);
    if (!target) {
      res.status(404).json({ error: 'Board not found' });
      return;
    }

    if (target.coverImageUrl) {
      await deleteSingleWikiBrandOssObjectIfOwned(target.coverImageUrl, boardId);
    }
    await deleteWikiBrandOssFolder(boardId);
    fs.rmSync(rankingBoardDirPath(boardId), { recursive: true, force: true });
    saveRankingBoards(boards.filter((item) => item.id !== boardId));
    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete ranking board error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/learn/rankings/:boardId/years/:year/upsert', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const boardId = sanitizeRankingBoardId(String(req.params.boardId ?? ''));
    const year = Number(String(req.params.year ?? ''));
    if (!Number.isFinite(year) || year < 1900 || year > 2200) {
      res.status(400).json({ error: 'year is invalid' });
      return;
    }

    const boards = loadRankingBoards();
    const boardIndex = boards.findIndex((item) => item.id === boardId);
    if (boardIndex < 0) {
      res.status(404).json({ error: 'Board not found' });
      return;
    }

    const body = (req.body ?? {}) as Record<string, unknown>;
    const explicitEntries = parseRankingEntries(body.entries);
    const importText = String(body.importText || '').trim();
    const importedEntries = importText
      ? parseRankingText(importText).map((item) => ({ rank: item.rank, name: item.name }))
      : [];
    const entries = explicitEntries.length > 0 ? explicitEntries : importedEntries;

    saveRankingYearData(boardId, Math.floor(year), entries, importText ? 'import_text' : 'manual_update');

    const board = boards[boardIndex];
    board.years = Array.from(new Set([...board.years, Math.floor(year)])).sort((a, b) => a - b);
    board.updatedAt = new Date().toISOString();
    boards[boardIndex] = board;
    saveRankingBoards(boards);

    ok(res, {
      boardId,
      year: Math.floor(year),
      count: entries.length,
      years: board.years,
    });
  } catch (error) {
    console.error('BFF web upsert ranking year error:', error);
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
