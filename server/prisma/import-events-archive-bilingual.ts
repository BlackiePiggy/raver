import 'dotenv/config';
import fs from 'node:fs';
import path from 'node:path';
import OSS from 'ali-oss';
import { Prisma, PrismaClient } from '@prisma/client';

type ImageType = 'cover' | 'luall' | 'tt' | 'other';

type ImageClassified = {
  type: ImageType;
  label: string;
  order: number;
  sort: number;
};

type EventBiText = {
  en: string;
  zh: string;
};

type EventSocialLink = {
  type: string;
  url: string;
  label?: string;
};

type EventImageAsset = {
  type: ImageType;
  label: string;
  url: string;
  source: 'archive-local' | 'archive-photo';
  originalUrl?: string;
  fileName?: string;
  order?: number;
  sort?: number;
};

type ArchiveLineupRow = {
  musician?: unknown;
  date?: unknown;
  time?: unknown;
  stage?: unknown;
  djId?: unknown;
};

type ArchiveSourcePhoto = {
  label?: unknown;
  image_url?: unknown;
};

type ArchiveFestivalInfo = {
  name?: unknown;
  nameI18n?: unknown;
  location?: unknown;
  locationI18n?: unknown;
  country?: unknown;
  countryI18n?: unknown;
  description?: unknown;
  descriptionI18n?: unknown;
  canceled?: unknown;
  cancelled?: unknown;
  isCanceled?: unknown;
  isCancelled?: unknown;
  startDate?: unknown;
  endDate?: unknown;
  relatedLinks?: unknown;
  socialLinks?: unknown;
  festivalId?: unknown;
  lineup?: unknown;
  source?: {
    provider?: unknown;
    eventUrl?: unknown;
    photos?: unknown;
  } | unknown;
};

type LocalImageCandidate = {
  kind: 'local';
  absPath: string;
  fileName: string;
  classified: ImageClassified;
};

type RemoteImageCandidate = {
  kind: 'remote';
  imageUrl: string;
  fileName: string;
  classified: ImageClassified;
  label: string;
};

type ImageCandidate = LocalImageCandidate | RemoteImageCandidate;

type CliOptions = {
  brandsRoot: string;
  offset: number;
  limit: number | null;
  dryRun: boolean;
  skipImages: boolean;
  skipExistingImages: boolean;
  ownerUsername: string;
  onlyFestivalId: string | null;
};

type ExistingEventLite = {
  id: string;
  slug: string;
  organizerId: string | null;
  description: string | null;
  venueName: string | null;
  city: string | null;
  country: string | null;
  coverImageUrl: string | null;
  lineupImageUrl: string | null;
  imageAssets: Prisma.JsonValue | null;
  nameI18n: Prisma.JsonValue | null;
  locationI18n: Prisma.JsonValue | null;
  countryI18n: Prisma.JsonValue | null;
  descriptionI18n: Prisma.JsonValue | null;
  referenceLinks: string[];
  socialLinks: Prisma.JsonValue | null;
  sourceProvider: string | null;
  sourceEventUrl: string | null;
  archiveFestivalId: string | null;
  eventType: string | null;
  organizerName: string | null;
  venueAddress: string | null;
  latitude: Prisma.Decimal | null;
  longitude: Prisma.Decimal | null;
  ticketUrl: string | null;
  ticketPriceMin: Prisma.Decimal | null;
  ticketPriceMax: Prisma.Decimal | null;
  ticketCurrency: string | null;
  ticketNotes: string | null;
  officialWebsite: string | null;
  isVerified: boolean;
};

const prisma = new PrismaClient();

const IMAGE_EXT_RE = /\.(jpe?g|png|gif|webp|avif|bmp|svg|tiff?)$/i;

const defaultBrandsRoot = path.resolve(__dirname, '../../scrapRave/brands');

const parseArgs = (argv: string[]): CliOptions => {
  const opts: CliOptions = {
    brandsRoot: process.env.EVENT_ARCHIVE_BRANDS_ROOT?.trim() || defaultBrandsRoot,
    offset: 0,
    limit: null,
    dryRun: false,
    skipImages: false,
    skipExistingImages: true,
    ownerUsername: process.env.EVENT_ARCHIVE_OWNER_USERNAME?.trim() || 'uploadtester',
    onlyFestivalId: null,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if ((arg === '--brands-root' || arg === '-r') && argv[i + 1]) {
      opts.brandsRoot = path.resolve(argv[i + 1]);
      i += 1;
      continue;
    }
    if (arg === '--offset' && argv[i + 1]) {
      const value = Number(argv[i + 1]);
      if (Number.isFinite(value) && value >= 0) {
        opts.offset = Math.floor(value);
      }
      i += 1;
      continue;
    }
    if (arg === '--limit' && argv[i + 1]) {
      const value = Number(argv[i + 1]);
      if (Number.isFinite(value) && value > 0) {
        opts.limit = Math.floor(value);
      }
      i += 1;
      continue;
    }
    if (arg === '--dry-run') {
      opts.dryRun = true;
      continue;
    }
    if (arg === '--skip-images') {
      opts.skipImages = true;
      continue;
    }
    if (arg === '--skip-existing-images=false') {
      opts.skipExistingImages = false;
      continue;
    }
    if (arg === '--owner-username' && argv[i + 1]) {
      opts.ownerUsername = String(argv[i + 1] || '').trim() || opts.ownerUsername;
      i += 1;
      continue;
    }
    if (arg === '--festival-id' && argv[i + 1]) {
      const value = String(argv[i + 1] || '').trim();
      opts.onlyFestivalId = value || null;
      i += 1;
      continue;
    }
  }

  return opts;
};

const safeText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const normalizeNameKey = (value: string): string =>
  value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]/g, '');

const normalizeBiText = (value: unknown, fallback = ''): EventBiText => {
  const fallbackText = fallback.trim();
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    const row = value as Record<string, unknown>;
    const en = safeText(row.en ?? row.EN ?? row.english) || fallbackText;
    const zh = safeText(row.zh ?? row.ZH ?? row.cn ?? row.chinese) || en || fallbackText;
    return {
      en: en || zh || fallbackText,
      zh: zh || en || fallbackText,
    };
  }
  const plain = safeText(value) || fallbackText;
  return { en: plain, zh: plain };
};

const parseFolderName = (folderName: string): { month: number; festName: string; location: string } | null => {
  const parts = folderName.split('-');
  if (parts.length < 3) return null;
  const month = Number(parts[0]);
  if (!Number.isFinite(month) || month < 1 || month > 12) return null;
  const location = parts[parts.length - 1].trim();
  const festName = parts.slice(1, -1).join('-').trim();
  if (!location || !festName) return null;
  return { month, festName, location };
};

const normalizeDateText = (value: unknown): string => {
  const src = safeText(value);
  if (!src) return '';
  const m = src.match(/^(\d{4})[\/.\-](\d{1,2})[\/.\-](\d{1,2})$/);
  if (!m) return src;
  return `${m[1]}-${String(Number(m[2])).padStart(2, '0')}-${String(Number(m[3])).padStart(2, '0')}`;
};

const parseDateOnly = (dateText: string): Date | null => {
  const normalized = normalizeDateText(dateText);
  const m = normalized.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!m) return null;
  const date = new Date(`${m[1]}-${m[2]}-${m[3]}T00:00:00`);
  return Number.isNaN(date.getTime()) ? null : date;
};

const dateTokenFromStartDate = (dateText: string): string => {
  const src = normalizeDateText(dateText);
  const m = src.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (m) return `${m[1]}${m[2]}${m[3]}`;
  const digits = src.replace(/\D/g, '');
  return digits.length >= 8 ? digits.slice(0, 8) : '';
};

const toPascalToken = (value: string, fallback = ''): string => {
  const words = value
    .trim()
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .split(/\s+/g)
    .filter(Boolean);
  if (!words.length) return fallback;
  return words
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join('');
};

const buildArchiveFestivalId = (
  startDateText: string,
  festivalName: string,
  country: string,
  fallbackYear: string,
  fallbackFolder: string
): string => {
  const datePart = dateTokenFromStartDate(startDateText) || `${fallbackYear || '0000'}0101`;
  const namePart = toPascalToken(festivalName, toPascalToken(fallbackFolder, 'Festival'));
  const countryPart = country.trim().toUpperCase().replace(/[^A-Z0-9\u4E00-\u9FFF]/g, '') || 'UNK';
  return `${datePart}-${namePart}-${countryPart}`;
};

const normalizeBoolFlag = (value: unknown, fallback = false): boolean => {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  const s = safeText(value).toLowerCase();
  if (!s) return fallback;
  if (['1', 'true', 'yes', 'y', 'cancelled', 'canceled', '已取消', '是'].includes(s)) return true;
  if (['0', 'false', 'no', 'n', 'active', 'normal', '未取消', '否'].includes(s)) return false;
  return fallback;
};

const resolveStatus = (canceled: boolean, startDate: Date, endDate: Date): string => {
  if (canceled) return 'cancelled';
  const now = Date.now();
  const start = startDate.getTime();
  const end = endDate.getTime();
  if (now < start) return 'upcoming';
  if (now > end) return 'ended';
  return 'ongoing';
};

const normalizeReferenceLinks = (value: unknown): string[] => {
  const list = Array.isArray(value)
    ? value
    : typeof value === 'string'
      ? value.split(/\r?\n/g)
      : [];

  const out: string[] = [];
  const seen = new Set<string>();
  for (const item of list) {
    const link = safeText(item);
    if (!link) continue;
    const key = link.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(link);
  }
  return out;
};

const normalizeSocialLinks = (value: unknown): EventSocialLink[] => {
  if (!Array.isArray(value)) return [];

  const links = value
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const row = item as Record<string, unknown>;
      const url = safeText(row.url);
      if (!url) return null;
      const type = safeText(row.type).toLowerCase() || 'website';
      const label = safeText(row.label);
      return {
        type,
        url,
        ...(label ? { label } : {}),
      } as EventSocialLink;
    })
    .filter((item): item is EventSocialLink => item !== null);

  const deduped: EventSocialLink[] = [];
  const seen = new Set<string>();
  for (const item of links) {
    const key = `${item.type}::${item.url}`.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(item);
  }

  return deduped;
};

const extractOfficialWebsite = (socialLinks: EventSocialLink[], referenceLinks: string[]): string | null => {
  const socialWebsite = socialLinks.find((link) => link.type === 'website')?.url;
  if (socialWebsite) return socialWebsite;

  const firstHttpRef = referenceLinks.find((link) => /^https?:\/\//i.test(link));
  return firstHttpRef || null;
};

const classifyImageByFilename = (filename: string): ImageClassified => {
  const base = filename.replace(/\.[^.]+$/, '');
  const up = base.toUpperCase();
  if (/^COVER$/i.test(base)) return { type: 'cover', label: 'COVER', order: 0, sort: 0 };

  const lu = up.match(/^LUALL(\d*)$/);
  if (lu) {
    const n = lu[1] ? Number(lu[1]) : 1;
    return { type: 'luall', label: lu[1] ? `LINE-UP ALL ${n}` : 'LINE-UP ALL', order: 1, sort: n };
  }

  const luShort = up.match(/^LU(?:[\s_-]?(\d+))?$/);
  if (luShort) {
    const n = luShort[1] ? Number(luShort[1]) : 1;
    return { type: 'luall', label: n > 1 ? `LINE-UP ${n}` : 'LINE-UP', order: 1, sort: n };
  }

  const lu2 = up.match(/^LINEUP(?:-(\d+))?$/);
  if (lu2) {
    const n = lu2[1] ? Number(lu2[1]) : 1;
    return { type: 'luall', label: n > 1 ? `LINE-UP ${n}` : 'LINE-UP', order: 1, sort: n };
  }

  const tt = up.match(/^TT(\d+)$/);
  if (tt) {
    const n = Number(tt[1]);
    return { type: 'tt', label: `TIMETABLE ${n}`, order: 2, sort: n };
  }

  const tt2 = up.match(/^TIMETABLE(?:-(\d+))?$/);
  if (tt2) {
    const n = tt2[1] ? Number(tt2[1]) : 1;
    return { type: 'tt', label: n > 1 ? `TIMETABLE ${n}` : 'TIMETABLE', order: 2, sort: n };
  }

  if (up.includes('LUALL')) return { type: 'luall', label: 'LINE-UP ALL', order: 1, sort: 99 };
  if (up.includes('LINEUP')) return { type: 'luall', label: 'LINE-UP', order: 1, sort: 99 };
  if (/^COVER/i.test(up)) return { type: 'cover', label: 'COVER', order: 0, sort: 0 };
  if (/^TT\d/i.test(up)) return { type: 'tt', label: 'TIMETABLE', order: 2, sort: 99 };
  if (up.includes('TIMETABLE')) return { type: 'tt', label: 'TIMETABLE', order: 2, sort: 99 };
  return { type: 'other', label: base, order: 3, sort: 99 };
};

const classifyImageByPhotoLabel = (label: string): ImageClassified => {
  const source = label.trim();
  const up = source.toUpperCase();
  if (up.includes('POSTER') || up.includes('COVER')) {
    return { type: 'cover', label: source || 'POSTER', order: 0, sort: 0 };
  }
  if (up.includes('LINEUP') || up.includes('LINE-UP') || up.includes('LUALL') || up === 'LU') {
    return { type: 'luall', label: source || 'LINE-UP', order: 1, sort: 1 };
  }
  if (up.includes('TIMETABLE') || /^TT\d*$/.test(up)) {
    return { type: 'tt', label: source || 'TIMETABLE', order: 2, sort: 1 };
  }
  return { type: 'other', label: source || 'OTHER', order: 3, sort: 99 };
};

const parseLineupTimeRange = (value: unknown): { startHM: string | null; endHM: string | null } => {
  const text = safeText(value);
  if (!text) return { startHM: null, endHM: null };

  const match = text.match(/(\d{1,2}:\d{2})\s*(?:—|–|~|-|to|TO|至|到)\s*(\d{1,2}:\d{2})/);
  if (match) {
    return {
      startHM: match[1],
      endHM: match[2],
    };
  }

  const one = text.match(/(\d{1,2}:\d{2})/);
  if (one) {
    return { startHM: one[1], endHM: null };
  }

  return { startHM: null, endHM: null };
};

const buildDateTime = (date: Date, hourMinute: string | null, fallbackMinutes = 0): Date => {
  if (!hourMinute) {
    return new Date(date.getTime() + fallbackMinutes * 60_000);
  }

  const hm = hourMinute.match(/^(\d{1,2}):(\d{2})$/);
  if (!hm) {
    return new Date(date.getTime() + fallbackMinutes * 60_000);
  }

  const hours = Math.max(0, Math.min(23, Number(hm[1])));
  const minutes = Math.max(0, Math.min(59, Number(hm[2])));

  const out = new Date(date);
  out.setHours(hours, minutes, 0, 0);
  return out;
};

const mergeBiTexts = (nextValue: EventBiText, existingValue: Prisma.JsonValue | null): EventBiText => {
  if (!existingValue || typeof existingValue !== 'object' || Array.isArray(existingValue)) {
    return nextValue;
  }

  const row = existingValue as Record<string, unknown>;
  const currentEn = safeText(row.en);
  const currentZh = safeText(row.zh);

  return {
    en: nextValue.en || currentEn,
    zh: nextValue.zh || currentZh || nextValue.en || currentEn,
  };
};

const mergeStringArray = (nextValues: string[], existingValues: string[]): string[] => {
  if (nextValues.length === 0) return existingValues;
  const out: string[] = [];
  const seen = new Set<string>();
  for (const value of [...nextValues, ...existingValues]) {
    const text = value.trim();
    if (!text) continue;
    const key = text.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(text);
  }
  return out;
};

const walkFestivalInfoFiles = (rootDir: string): string[] => {
  const files: string[] = [];
  const queue = [rootDir];

  while (queue.length > 0) {
    const current = queue.shift() as string;
    const entries = fs.readdirSync(current, { withFileTypes: true });
    for (const entry of entries) {
      const absPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === 'downloads') continue;
        queue.push(absPath);
        continue;
      }
      if (entry.isFile() && entry.name === 'festival-info.json') {
        files.push(absPath);
      }
    }
  }

  files.sort((a, b) => a.localeCompare(b));
  return files;
};

const resolveExtByMime = (mimeType: string, fallbackName = 'image.jpg'): string => {
  const mime = mimeType.toLowerCase();
  if (mime.includes('png')) return '.png';
  if (mime.includes('webp')) return '.webp';
  if (mime.includes('gif')) return '.gif';
  if (mime.includes('svg')) return '.svg';
  if (mime.includes('bmp')) return '.bmp';
  if (mime.includes('avif')) return '.avif';
  if (mime.includes('tiff')) return '.tiff';
  if (mime.includes('jpg') || mime.includes('jpeg')) return '.jpg';

  const ext = path.extname(fallbackName).toLowerCase();
  if (IMAGE_EXT_RE.test(ext)) {
    return ext === '.jpeg' ? '.jpg' : ext;
  }

  return '.jpg';
};

const sanitizeOssPathSegment = (value: string): string =>
  value
    .trim()
    .replace(/[^a-zA-Z0-9-_]/g, '')
    .slice(0, 128);

const normalizeUploadedOssUrl = (
  rawUrl: string | undefined,
  objectKey: string,
  bucket: string,
  region: string,
  endpoint: string | null
): string => {
  if (rawUrl && rawUrl.trim()) {
    if (rawUrl.startsWith('//')) return `https:${rawUrl}`;
    if (rawUrl.startsWith('http://')) return `https://${rawUrl.slice('http://'.length)}`;
    if (rawUrl.startsWith('https://')) return rawUrl;
  }

  const endpointHost = endpoint
    ? endpoint.replace(/^https?:\/\//, '').replace(/^\/+|\/+$/g, '')
    : `${region}.aliyuncs.com`;
  const bucketHost = endpointHost.startsWith(`${bucket}.`) ? endpointHost : `${bucket}.${endpointHost}`;
  return `https://${bucketHost}/${objectKey}`;
};

const buildOssClient = (): {
  client: OSS;
  bucket: string;
  region: string;
  endpoint: string | null;
  prefix: string;
} | null => {
  const region = safeText(process.env.OSS_REGION);
  const accessKeyId = safeText(process.env.OSS_ACCESS_KEY_ID);
  const accessKeySecret = safeText(process.env.OSS_ACCESS_KEY_SECRET);
  const bucket = safeText(process.env.OSS_BUCKET);
  const endpoint = safeText(process.env.OSS_ENDPOINT) || null;
  const prefix = (safeText(process.env.OSS_EVENTS_PREFIX) || 'wen-jasonlee/events').replace(/^\/+|\/+$/g, '');

  if (!region || !accessKeyId || !accessKeySecret || !bucket) {
    return null;
  }

  return {
    client: new OSS({
      region,
      accessKeyId,
      accessKeySecret,
      bucket,
      endpoint: endpoint || undefined,
      secure: true,
    }),
    bucket,
    region,
    endpoint,
    prefix,
  };
};

const buildEventMediaObjectKey = (
  prefix: string,
  eventId: string,
  usage: ImageType,
  fileName: string,
  mimeType: string
): string => {
  const rawExt = path.extname(fileName || '').toLowerCase();
  const ext = rawExt && rawExt.length <= 10 ? rawExt : resolveExtByMime(mimeType, fileName);
  const safeEventId = sanitizeOssPathSegment(eventId) || 'unknown-event';
  const safeUsage = sanitizeOssPathSegment(usage) || 'image';
  return `${prefix}/${safeEventId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const fetchRemoteImage = async (url: string): Promise<{ buffer: Buffer; mimeType: string; fileName: string }> => {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 20_000);

  try {
    const resp = await fetch(url, {
      method: 'GET',
      signal: controller.signal,
      headers: {
        Accept: 'image/*',
      },
    });
    if (!resp.ok) {
      throw new Error(`remote image download failed with status ${resp.status}`);
    }

    const mimeType = (resp.headers.get('content-type') || 'image/jpeg').toLowerCase();
    if (!mimeType.startsWith('image/')) {
      throw new Error(`invalid remote mime type: ${mimeType}`);
    }

    const buffer = Buffer.from(await resp.arrayBuffer());
    if (buffer.length === 0) {
      throw new Error('remote image buffer is empty');
    }

    let fileName = path.basename(url.split('?')[0] || '').trim();
    if (!fileName) {
      fileName = `remote-${Date.now()}${resolveExtByMime(mimeType)}`;
    }

    return { buffer, mimeType, fileName };
  } finally {
    clearTimeout(timer);
  }
};

const parseExistingImageAssets = (value: Prisma.JsonValue | null): EventImageAsset[] => {
  if (!Array.isArray(value)) return [];
  const allowedTypes = new Set<ImageType>(['cover', 'luall', 'tt', 'other']);

  return value
    .map((item) => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
      const row = item as Record<string, unknown>;
      const typeText = safeText(row.type).toLowerCase() as ImageType;
      if (!allowedTypes.has(typeText)) return null;
      const url = safeText(row.url);
      if (!url) return null;

      const order = typeof row.order === 'number' && Number.isFinite(row.order) ? row.order : undefined;
      const sort = typeof row.sort === 'number' && Number.isFinite(row.sort) ? row.sort : undefined;

      return {
        type: typeText,
        label: safeText(row.label) || typeText.toUpperCase(),
        url,
        source: safeText(row.source) === 'archive-photo' ? 'archive-photo' : 'archive-local',
        originalUrl: safeText(row.originalUrl) || undefined,
        fileName: safeText(row.fileName) || undefined,
        ...(order !== undefined ? { order } : {}),
        ...(sort !== undefined ? { sort } : {}),
      } as EventImageAsset;
    })
    .filter((item): item is EventImageAsset => item !== null);
};

const uploadImageCandidates = async (
  args: {
    candidates: ImageCandidate[];
    eventId: string;
    oss: {
      client: OSS;
      bucket: string;
      region: string;
      endpoint: string | null;
      prefix: string;
    };
  }
): Promise<{ assets: EventImageAsset[]; uploaded: number; failed: number }> => {
  const assets: EventImageAsset[] = [];
  let uploaded = 0;
  let failed = 0;

  for (const candidate of args.candidates) {
    try {
      let fileName = candidate.fileName;
      let mimeType = 'image/jpeg';
      let buffer: Buffer;

      if (candidate.kind === 'local') {
        buffer = fs.readFileSync(candidate.absPath);
        if (buffer.length === 0) throw new Error('local image is empty');
        const ext = path.extname(candidate.fileName).toLowerCase();
        if (ext === '.png') mimeType = 'image/png';
        else if (ext === '.webp') mimeType = 'image/webp';
        else if (ext === '.gif') mimeType = 'image/gif';
        else if (ext === '.svg') mimeType = 'image/svg+xml';
        else mimeType = 'image/jpeg';
      } else {
        const remote = await fetchRemoteImage(candidate.imageUrl);
        buffer = remote.buffer;
        mimeType = remote.mimeType;
        fileName = remote.fileName;
      }

      const objectKey = buildEventMediaObjectKey(
        args.oss.prefix,
        args.eventId,
        candidate.classified.type,
        fileName,
        mimeType
      );

      const put = await args.oss.client.put(objectKey, buffer, {
        headers: {
          'Content-Type': mimeType,
          'Cache-Control': 'public, max-age=31536000, immutable',
        },
      });

      const uploadedUrl = normalizeUploadedOssUrl(
        put.url,
        objectKey,
        args.oss.bucket,
        args.oss.region,
        args.oss.endpoint
      );

      assets.push({
        type: candidate.classified.type,
        label: candidate.classified.label,
        url: uploadedUrl,
        source: candidate.kind === 'local' ? 'archive-local' : 'archive-photo',
        ...(candidate.kind === 'remote' ? { originalUrl: candidate.imageUrl } : {}),
        fileName: path.basename(fileName),
        order: candidate.classified.order,
        sort: candidate.classified.sort,
      });
      uploaded += 1;
    } catch (error) {
      failed += 1;
      const target = candidate.kind === 'local' ? candidate.absPath : candidate.imageUrl;
      console.warn(`[archive-events] image upload failed: ${target} -> ${(error as Error).message}`);
    }
  }

  assets.sort((a, b) => {
    const ao = typeof a.order === 'number' ? a.order : 99;
    const bo = typeof b.order === 'number' ? b.order : 99;
    if (ao !== bo) return ao - bo;
    const as = typeof a.sort === 'number' ? a.sort : 99;
    const bs = typeof b.sort === 'number' ? b.sort : 99;
    if (as !== bs) return as - bs;
    return String(a.fileName || '').localeCompare(String(b.fileName || ''));
  });

  return { assets, uploaded, failed };
};

const parseLineupRows = (
  rawLineup: unknown,
  eventStartDate: Date,
  validDJIds: Set<string>,
  djIdByName: Map<string, string>
): Prisma.EventLineupSlotCreateManyInput[] => {
  if (!Array.isArray(rawLineup)) return [];

  const out: Prisma.EventLineupSlotCreateManyInput[] = [];

  rawLineup.forEach((item, index) => {
    if (!item || typeof item !== 'object') return;
    const row = item as ArchiveLineupRow;
    const djName = safeText(row.musician);
    if (!djName) return;

    const dateCandidate = parseDateOnly(safeText(row.date)) || eventStartDate;
    const { startHM, endHM } = parseLineupTimeRange(row.time);

    const startTime = buildDateTime(dateCandidate, startHM, index);
    let endTime = buildDateTime(dateCandidate, endHM, index + 1);
    if (endTime.getTime() <= startTime.getTime()) {
      endTime = new Date(endTime.getTime() + 24 * 60 * 60 * 1000);
    }

    let djId = safeText(row.djId);
    if (!djId || !validDJIds.has(djId)) {
      djId = '';
    }
    if (!djId) {
      djId = djIdByName.get(normalizeNameKey(djName)) || '';
    }

    const stageName = safeText(row.stage);

    out.push({
      eventId: '',
      djId: djId || null,
      djName,
      stageName: stageName || null,
      sortOrder: index + 1,
      startTime,
      endTime,
    });
  });

  return out;
};

const collectImageCandidates = (festivalDir: string, info: ArchiveFestivalInfo): ImageCandidate[] => {
  const candidates: ImageCandidate[] = [];

  const entries = fs.readdirSync(festivalDir, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isFile()) continue;
    if (!IMAGE_EXT_RE.test(entry.name)) continue;

    candidates.push({
      kind: 'local',
      absPath: path.join(festivalDir, entry.name),
      fileName: entry.name,
      classified: classifyImageByFilename(entry.name),
    });
  }

  const source = info.source && typeof info.source === 'object' ? (info.source as Record<string, unknown>) : null;
  const photosRaw = source?.photos;
  if (Array.isArray(photosRaw)) {
    for (const item of photosRaw) {
      if (!item || typeof item !== 'object') continue;
      const photo = item as ArchiveSourcePhoto;
      const imageUrl = safeText(photo.image_url);
      if (!imageUrl) continue;

      const label = safeText(photo.label) || 'PHOTO';
      const fileName = path.basename(imageUrl.split('?')[0] || '') || `${Date.now()}.jpg`;

      candidates.push({
        kind: 'remote',
        imageUrl,
        fileName,
        classified: classifyImageByPhotoLabel(label),
        label,
      });
    }
  }

  candidates.sort((a, b) => {
    if (a.classified.order !== b.classified.order) return a.classified.order - b.classified.order;
    if (a.classified.sort !== b.classified.sort) return a.classified.sort - b.classified.sort;
    return a.fileName.localeCompare(b.fileName);
  });

  return candidates;
};

const ensureUniqueSlug = async (baseSlug: string, excludeEventId: string | null): Promise<string> => {
  let next = baseSlug;
  let idx = 1;

  while (true) {
    const found = await prisma.event.findUnique({
      where: { slug: next },
      select: { id: true },
    });

    if (!found || (excludeEventId && found.id === excludeEventId)) {
      return next;
    }

    idx += 1;
    next = `${baseSlug}-${idx}`;
  }
};

const loadFestivalInfo = (infoPath: string): ArchiveFestivalInfo => {
  const raw = fs.readFileSync(infoPath, 'utf8');
  const parsed: unknown = JSON.parse(raw);
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('festival-info.json root must be an object');
  }
  return parsed as ArchiveFestivalInfo;
};

const selectExistingEvent = {
  id: true,
  slug: true,
  organizerId: true,
  description: true,
  venueName: true,
  city: true,
  country: true,
  coverImageUrl: true,
  lineupImageUrl: true,
  imageAssets: true,
  nameI18n: true,
  locationI18n: true,
  countryI18n: true,
  descriptionI18n: true,
  referenceLinks: true,
  socialLinks: true,
  sourceProvider: true,
  sourceEventUrl: true,
  archiveFestivalId: true,
  eventType: true,
  organizerName: true,
  venueAddress: true,
  latitude: true,
  longitude: true,
  ticketUrl: true,
  ticketPriceMin: true,
  ticketPriceMax: true,
  ticketCurrency: true,
  ticketNotes: true,
  officialWebsite: true,
  isVerified: true,
} as const;

const main = async (): Promise<void> => {
  const options = parseArgs(process.argv.slice(2));
  const brandsRoot = path.resolve(options.brandsRoot);

  if (!fs.existsSync(brandsRoot) || !fs.statSync(brandsRoot).isDirectory()) {
    throw new Error(`brands root not found: ${brandsRoot}`);
  }

  const files = walkFestivalInfoFiles(brandsRoot);
  const sliced = files.slice(options.offset, options.limit ? options.offset + options.limit : undefined);

  console.log(
    `[archive-events] start total=${files.length} selected=${sliced.length} dryRun=${options.dryRun} skipImages=${options.skipImages} skipExistingImages=${options.skipExistingImages}`
  );

  const owner = await prisma.user.findUnique({
    where: { username: options.ownerUsername },
    select: { id: true, username: true },
  });
  if (!owner) {
    console.warn(`[archive-events] owner username not found: ${options.ownerUsername}. create rows will use organizerId=null`);
  }

  const djs = await prisma.dJ.findMany({
    select: {
      id: true,
      name: true,
      aliases: true,
    },
  });

  const validDJIds = new Set<string>(djs.map((dj) => dj.id));
  const djIdByName = new Map<string, string>();
  for (const dj of djs) {
    const primaryKey = normalizeNameKey(dj.name);
    if (primaryKey && !djIdByName.has(primaryKey)) {
      djIdByName.set(primaryKey, dj.id);
    }
    for (const alias of dj.aliases || []) {
      const aliasKey = normalizeNameKey(alias);
      if (aliasKey && !djIdByName.has(aliasKey)) {
        djIdByName.set(aliasKey, dj.id);
      }
    }
  }

  const oss = options.skipImages ? null : buildOssClient();
  if (!options.skipImages && !oss) {
    throw new Error('OSS env missing: require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  let created = 0;
  let updated = 0;
  let failed = 0;
  let imagesUploaded = 0;
  let imagesFailed = 0;

  for (let i = 0; i < sliced.length; i += 1) {
    const infoPath = sliced[i];
    const relativePath = path.relative(brandsRoot, infoPath);

    try {
      const festivalDir = path.dirname(infoPath);
      const folderName = path.basename(festivalDir);
      const yearName = path.basename(path.dirname(festivalDir));
      const parsedFolder = parseFolderName(folderName);
      const info = loadFestivalInfo(infoPath);

      const nameBi = normalizeBiText(info.nameI18n ?? info.name, parsedFolder?.festName || '');
      const locationBi = normalizeBiText(info.locationI18n ?? info.location, parsedFolder?.location || '');
      const countryBi = normalizeBiText(info.countryI18n ?? info.country, '');
      const descriptionBi = normalizeBiText(info.descriptionI18n ?? info.description, '');

      const normalizedName = safeText(nameBi.en || nameBi.zh) || parsedFolder?.festName || folderName;
      const normalizedLocation = safeText(locationBi.en || locationBi.zh) || parsedFolder?.location || '';
      const normalizedCountry = safeText(countryBi.en || countryBi.zh);

      const fallbackStart = `${yearName}-${String(parsedFolder?.month || 1).padStart(2, '0')}-01`;
      const startDateText = normalizeDateText(info.startDate) || fallbackStart;
      const endDateText = normalizeDateText(info.endDate) || startDateText;
      const startDate = parseDateOnly(startDateText) || new Date(`${fallbackStart}T00:00:00`);
      const endDate = parseDateOnly(endDateText) || startDate;

      const archiveFestivalId = safeText(info.festivalId)
        || buildArchiveFestivalId(startDateText, normalizedName, normalizedCountry, yearName, folderName);

      if (options.onlyFestivalId && archiveFestivalId !== options.onlyFestivalId) {
        continue;
      }

      const referenceLinks = normalizeReferenceLinks(info.relatedLinks);
      const socialLinks = normalizeSocialLinks(info.socialLinks);
      const officialWebsite = extractOfficialWebsite(socialLinks, referenceLinks);

      const sourceObj = info.source && typeof info.source === 'object'
        ? (info.source as Record<string, unknown>)
        : null;
      const sourceProvider = safeText(sourceObj?.provider);
      const sourceEventUrl = safeText(sourceObj?.eventUrl);

      const canceled = normalizeBoolFlag(
        info.canceled ?? info.cancelled ?? info.isCanceled ?? info.isCancelled,
        false
      );
      const nextStatus = resolveStatus(canceled, startDate, endDate);

      const slugBase = (sourceEventUrl.split('/').filter(Boolean).pop() || '').trim();
      const canonicalSlug = slugify(slugBase || `${normalizedName}-${startDateText}`);

      let existing: ExistingEventLite | null = null;
      if (archiveFestivalId) {
        existing = await prisma.event.findUnique({
          where: { archiveFestivalId },
          select: selectExistingEvent,
        }) as ExistingEventLite | null;
      }

      if (!existing) {
        existing = await prisma.event.findUnique({
          where: { slug: canonicalSlug },
          select: selectExistingEvent,
        }) as ExistingEventLite | null;
      }

      if (!existing) {
        existing = await prisma.event.findFirst({
          where: {
            name: normalizedName,
            startDate,
          },
          select: selectExistingEvent,
        }) as ExistingEventLite | null;
      }

      const effectiveSlug = await ensureUniqueSlug(canonicalSlug, existing?.id || null);

      const lineupSlots = parseLineupRows(
        info.lineup,
        startDate,
        validDJIds,
        djIdByName
      );

      const existingAssets = existing ? parseExistingImageAssets(existing.imageAssets) : [];
      let nextAssets = existingAssets;
      let nextCoverImageUrl = existing?.coverImageUrl || null;
      let nextLineupImageUrl = existing?.lineupImageUrl || null;

      const shouldUploadImages = !options.skipImages
        && Boolean(oss)
        && (!options.skipExistingImages || existingAssets.length === 0);
      const imageCandidates = shouldUploadImages ? collectImageCandidates(festivalDir, info) : [];

      if (options.dryRun) {
        console.log(
          `[archive-events] [dry-run] ${i + 1}/${sliced.length} ${archiveFestivalId} ${normalizedName} ${existing ? 'update' : 'create'} lineup=${lineupSlots.length} assets(existing)=${nextAssets.length} assets(candidates)=${imageCandidates.length}`
        );
        continue;
      }

      const nextNameI18n = existing
        ? mergeBiTexts(nameBi, existing.nameI18n)
        : nameBi;
      const nextLocationI18n = existing
        ? mergeBiTexts(locationBi, existing.locationI18n)
        : locationBi;
      const nextCountryI18n = existing
        ? mergeBiTexts(countryBi, existing.countryI18n)
        : countryBi;
      const nextDescriptionI18n = existing
        ? mergeBiTexts(descriptionBi, existing.descriptionI18n)
        : descriptionBi;

      const mergedReferenceLinks = existing
        ? mergeStringArray(referenceLinks, existing.referenceLinks || [])
        : referenceLinks;

      const mergedSocialLinks = socialLinks.length > 0
        ? socialLinks
        : (existing?.socialLinks && Array.isArray(existing.socialLinks)
            ? (existing.socialLinks as unknown as EventSocialLink[])
            : []);

      const payload = {
        organizerId: existing?.organizerId || owner?.id || null,
        archiveFestivalId,
        name: normalizedName,
        nameI18n: nextNameI18n as unknown as Prisma.InputJsonValue,
        slug: existing?.slug || effectiveSlug,
        description: safeText(info.description) || existing?.description || null,
        descriptionI18n: nextDescriptionI18n as unknown as Prisma.InputJsonValue,
        locationI18n: nextLocationI18n as unknown as Prisma.InputJsonValue,
        countryI18n: nextCountryI18n as unknown as Prisma.InputJsonValue,
        coverImageUrl: nextCoverImageUrl,
        lineupImageUrl: nextLineupImageUrl,
        imageAssets: nextAssets.length > 0 ? (nextAssets as unknown as Prisma.InputJsonValue) : undefined,
        referenceLinks: mergedReferenceLinks,
        socialLinks: mergedSocialLinks.length > 0 ? (mergedSocialLinks as unknown as Prisma.InputJsonValue) : undefined,
        sourceProvider: sourceProvider || existing?.sourceProvider || null,
        sourceEventUrl: sourceEventUrl || existing?.sourceEventUrl || null,
        eventType: existing?.eventType || 'festival',
        organizerName: existing?.organizerName || null,
        venueName: normalizedLocation || existing?.venueName || null,
        venueAddress: existing?.venueAddress || null,
        city: normalizedLocation || existing?.city || null,
        country: normalizedCountry || existing?.country || null,
        latitude: existing?.latitude ?? null,
        longitude: existing?.longitude ?? null,
        startDate,
        endDate,
        ticketUrl: existing?.ticketUrl || null,
        ticketPriceMin: existing?.ticketPriceMin ?? null,
        ticketPriceMax: existing?.ticketPriceMax ?? null,
        ticketCurrency: existing?.ticketCurrency || null,
        ticketNotes: existing?.ticketNotes || null,
        officialWebsite: officialWebsite || existing?.officialWebsite || null,
        status: nextStatus,
        isVerified: existing?.isVerified ?? false,
      };

      const saved = await prisma.$transaction(async (tx) => {
        const event = existing
          ? await tx.event.update({
              where: { id: existing.id },
              data: payload,
              select: { id: true },
            })
          : await tx.event.create({
              data: payload,
              select: { id: true },
            });

        await tx.eventLineupSlot.deleteMany({ where: { eventId: event.id } });
        if (lineupSlots.length > 0) {
          await tx.eventLineupSlot.createMany({
            data: lineupSlots.map((slot) => ({
              ...slot,
              eventId: event.id,
            })),
          });
        }

        return event;
      });

      if (shouldUploadImages && oss && imageCandidates.length > 0) {
        const uploaded = await uploadImageCandidates({
          candidates: imageCandidates,
          eventId: saved.id,
          oss,
        });

        nextAssets = uploaded.assets;
        imagesUploaded += uploaded.uploaded;
        imagesFailed += uploaded.failed;

        const coverFromAssets = nextAssets.find((asset) => asset.type === 'cover')?.url || null;
        const lineupFromAssets =
          nextAssets.find((asset) => asset.type === 'luall')?.url
          || nextAssets.find((asset) => asset.type === 'tt')?.url
          || null;

        nextCoverImageUrl = coverFromAssets || nextCoverImageUrl;
        nextLineupImageUrl = lineupFromAssets || nextLineupImageUrl;

        await prisma.event.update({
          where: { id: saved.id },
          data: {
            imageAssets: nextAssets.length > 0 ? (nextAssets as unknown as Prisma.InputJsonValue) : undefined,
            coverImageUrl: nextCoverImageUrl,
            lineupImageUrl: nextLineupImageUrl,
          },
        });
      }

      if (existing) {
        updated += 1;
      } else {
        created += 1;
      }

      console.log(
        `[archive-events] ${i + 1}/${sliced.length} ${existing ? 'updated' : 'created'} event=${saved.id} festivalId=${archiveFestivalId} lineup=${lineupSlots.length} assets=${nextAssets.length} path=${relativePath}`
      );
    } catch (error) {
      failed += 1;
      console.error(
        `[archive-events] ${i + 1}/${sliced.length} failed path=${relativePath}: ${(error as Error).message}`
      );
    }
  }

  console.log('');
  console.log('[archive-events] finished');
  console.log(`processed=${sliced.length}`);
  console.log(`created=${created}`);
  console.log(`updated=${updated}`);
  console.log(`failed=${failed}`);
  console.log(`imagesUploaded=${imagesUploaded}`);
  console.log(`imagesFailed=${imagesFailed}`);
};

const slugify = (value: string): string =>
  value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'festival';

main()
  .catch((error) => {
    console.error('[archive-events] fatal:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
