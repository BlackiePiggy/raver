import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import OSS from 'ali-oss';
import { Prisma, PrismaClient } from '@prisma/client';

type RawContact = {
  label: string | null;
  url: string | null;
};

type RawLink = {
  label: string | null;
  url: string | null;
  metric_text: string | null;
  metric_value: number | null;
};

type RawLabel = {
  name?: string | null;
  profile_url?: string | null;
  profile_slug?: string | null;
  source_page?: number | null;
  source_listing_url?: string | null;
  card_id?: string | null;
  logo_url?: string | null;
  avatar_url?: string | null;
  background_url?: string | null;
  soundcloud_followers?: number | null;
  likes?: number | null;
  nation?: string | null;
  genres_preview?: string | null;
  latest_release_listing?: string | null;
  introduction_preview?: string | null;
  location_period?: string | null;
  introduction?: string | null;
  genres?: string[] | null;
  contacts?: RawContact[] | null;
  general_contact_email?: string | null;
  demo_submission_url?: string | null;
  demo_submission_display?: string | null;
  links_in_web?: RawLink[] | null;
  founder_name?: string | null;
  founded_at?: string | null;
  founded_year?: string | number | null;
  founder_dj_id?: string | null;
};

type CliOptions = {
  inputPath: string;
  limit: number | null;
  offset: number;
  skipOssUpload: boolean;
};

const prisma = new PrismaClient();

const DEFAULT_INPUT_PATH = '/Users/blackie/Projects/label-crawler/output/labelsbase_top30_pages_combined.json';

const slugify = (value: string): string =>
  value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'label';

const parseArgs = (argv: string[]): CliOptions => {
  const options: CliOptions = {
    inputPath: process.env.LABELS_INPUT_JSON || DEFAULT_INPUT_PATH,
    limit: null,
    offset: 0,
    skipOssUpload: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];

    if ((arg === '--input' || arg === '-i') && argv[i + 1]) {
      options.inputPath = path.resolve(argv[i + 1]);
      i += 1;
      continue;
    }

    if (arg === '--limit' && argv[i + 1]) {
      const value = Number(argv[i + 1]);
      if (Number.isFinite(value) && value > 0) {
        options.limit = Math.floor(value);
      }
      i += 1;
      continue;
    }

    if (arg === '--offset' && argv[i + 1]) {
      const value = Number(argv[i + 1]);
      if (Number.isFinite(value) && value >= 0) {
        options.offset = Math.floor(value);
      }
      i += 1;
      continue;
    }

    if (arg === '--skip-oss-upload') {
      options.skipOssUpload = true;
    }
  }

  return options;
};

const safeString = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const safeNumber = (value: unknown): number | null => {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.floor(value);
  }
  if (typeof value === 'string') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return Math.floor(parsed);
    }
  }
  return null;
};

const safeStringArray = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => safeString(item))
    .filter((item): item is string => !!item);
};

const normalizeLookupKey = (value: string): string =>
  value
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');

const normalizeLinks = (value: unknown): RawLink[] => {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const row = item as Record<string, unknown>;
      return {
        label: safeString(row.label),
        url: safeString(row.url),
        metric_text: safeString(row.metric_text),
        metric_value: safeNumber(row.metric_value),
      };
    })
    .filter((item): item is RawLink => item !== null);
};

const normalizeContacts = (value: unknown): RawContact[] => {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const row = item as Record<string, unknown>;
      return {
        label: safeString(row.label),
        url: safeString(row.url),
      };
    })
    .filter((item): item is RawContact => item !== null);
};

const parseJsonFile = (inputPath: string): RawLabel[] => {
  const raw = fs.readFileSync(inputPath, 'utf8');
  const parsed: unknown = JSON.parse(raw);
  if (!Array.isArray(parsed)) {
    throw new Error('Input JSON must be an array');
  }
  return parsed as RawLabel[];
};

const detectExt = (url: string, contentType?: string | null): string => {
  const byType = (contentType || '').toLowerCase();
  if (byType.includes('png')) return '.png';
  if (byType.includes('webp')) return '.webp';
  if (byType.includes('gif')) return '.gif';
  if (byType.includes('jpeg') || byType.includes('jpg')) return '.jpg';

  const pathname = url.split('?')[0] || '';
  const ext = path.extname(pathname).toLowerCase();
  if (ext === '.png' || ext === '.jpg' || ext === '.jpeg' || ext === '.webp' || ext === '.gif') {
    return ext === '.jpeg' ? '.jpg' : ext;
  }
  return '.jpg';
};

const normalizeOssUrl = (url: string): string => {
  if (url.startsWith('http://')) {
    return `https://${url.slice('http://'.length)}`;
  }
  return url;
};

const buildOssClient = (): OSS | null => {
  const region = safeString(process.env.OSS_REGION);
  const accessKeyId = safeString(process.env.OSS_ACCESS_KEY_ID);
  const accessKeySecret = safeString(process.env.OSS_ACCESS_KEY_SECRET);
  const bucket = safeString(process.env.OSS_BUCKET);
  const endpoint = safeString(process.env.OSS_ENDPOINT);

  if (!region || !accessKeyId || !accessKeySecret || !bucket) {
    return null;
  }

  return new OSS({
    region,
    accessKeyId,
    accessKeySecret,
    bucket,
    endpoint: endpoint || undefined,
    secure: true,
  });
};

const uploadToOss = async (client: OSS, sourceUrl: string, objectKey: string): Promise<string | null> => {
  const response = await fetch(sourceUrl, { redirect: 'follow' });
  if (!response.ok) {
    throw new Error(`download failed with status ${response.status}`);
  }

  const buffer = Buffer.from(await response.arrayBuffer());
  const contentType = response.headers.get('content-type') || undefined;

  const result = await client.put(objectKey, buffer, {
    headers: contentType
      ? {
          'Content-Type': contentType,
          'Cache-Control': 'public, max-age=31536000',
        }
      : {
          'Cache-Control': 'public, max-age=31536000',
        },
  });

  if (!result.url) return null;
  return normalizeOssUrl(result.url);
};

const mapLinksByOrder = (links: RawLink[]) => {
  const isFacebook = (url: string): boolean => url.includes('facebook.com');
  const isSoundCloud = (url: string): boolean => url.includes('soundcloud.com');
  const isStore = (url: string): boolean =>
    url.includes('beatport.com') || url.includes('bandcamp.com') || url.includes('junodownload.com');
  const isKnownSocialOrStore = (url: string): boolean => isFacebook(url) || isSoundCloud(url) || isStore(url);

  const byIndex = (index: number): string | null => safeString(links[index]?.url);
  const first = byIndex(0);
  const second = byIndex(1);
  const third = byIndex(2);
  const fourth = byIndex(3);

  let facebookUrl = first && isFacebook(first.toLowerCase()) ? first : null;
  let soundcloudUrl = second && isSoundCloud(second.toLowerCase()) ? second : null;
  let musicPurchaseUrl = third && isStore(third.toLowerCase()) ? third : null;
  let officialWebsiteUrl =
    fourth && !isKnownSocialOrStore(fourth.toLowerCase()) ? fourth : null;

  // 用户确认 links_in_web 的顺序为：Facebook -> SoundCloud -> 购买链接 -> 官网。
  // 为防止部分条目缺项，这里再做域名兜底。
  for (const link of links) {
    const url = safeString(link.url);
    if (!url) continue;
    const lower = url.toLowerCase();

    if (!facebookUrl && isFacebook(lower)) facebookUrl = url;
    if (!soundcloudUrl && isSoundCloud(lower)) soundcloudUrl = url;
    if (!musicPurchaseUrl && isStore(lower)) {
      musicPurchaseUrl = url;
    }

    if (!officialWebsiteUrl) {
      if (!isKnownSocialOrStore(lower)) {
        officialWebsiteUrl = url;
      }
    }
  }

  return {
    facebookUrl,
    soundcloudUrl,
    musicPurchaseUrl,
    officialWebsiteUrl,
  };
};

const run = async (): Promise<void> => {
  const options = parseArgs(process.argv.slice(2));
  const records = parseJsonFile(options.inputPath);
  const sliced = records.slice(options.offset, options.limit ? options.offset + options.limit : undefined);

  const ossPrefix = safeString(process.env.OSS_LABEL_PREFIX) || 'wiki/labels';
  const useOss = !options.skipOssUpload;
  const ossClient = useOss ? buildOssClient() : null;

  if (useOss && !ossClient) {
    console.warn('[labels-import] OSS env not complete, fallback to original image URLs.');
  }

  let createdOrUpdated = 0;
  let avatarUploaded = 0;
  let backgroundUploaded = 0;
  let failed = 0;
  const founderDjByName = new Map<string, string>();

  const allDjs = await prisma.dJ.findMany({
    select: {
      id: true,
      name: true,
      aliases: true,
    },
  });
  for (const dj of allDjs) {
    founderDjByName.set(normalizeLookupKey(dj.name), dj.id);
    for (const alias of dj.aliases ?? []) {
      const normalized = normalizeLookupKey(alias);
      if (!founderDjByName.has(normalized)) {
        founderDjByName.set(normalized, dj.id);
      }
    }
  }

  for (let i = 0; i < sliced.length; i += 1) {
    const row = sliced[i];
    const raw = row as RawLabel & Record<string, unknown>;
    const name = safeString(row.name);
    const profileUrl = safeString(row.profile_url);

    if (!name || !profileUrl) {
      failed += 1;
      console.warn(`[labels-import] skip index ${i}: missing name/profile_url`);
      continue;
    }

    const baseSlug = safeString(row.profile_slug) || slugify(name);
    const uniqueHint = crypto.createHash('md5').update(profileUrl).digest('hex').slice(0, 8);
    const slug = `${baseSlug}-${uniqueHint}`;

    const links = normalizeLinks(row.links_in_web);
    const contacts = normalizeContacts(row.contacts);
    const contactsJson: Prisma.InputJsonValue | Prisma.NullableJsonNullValueInput =
      contacts.length > 0 ? (contacts as Prisma.InputJsonValue) : Prisma.JsonNull;
    const linksJson: Prisma.InputJsonValue | Prisma.NullableJsonNullValueInput =
      links.length > 0 ? (links as Prisma.InputJsonValue) : Prisma.JsonNull;
    const mappedLinks = mapLinksByOrder(links);

    const avatarSourceUrl = safeString(row.avatar_url) || safeString(row.logo_url);
    const backgroundSourceUrl = safeString(row.background_url);
    const founderName =
      safeString(row.founder_name)
      || safeString(raw.founder)
      || safeString(raw.founder_name_cn);
    const foundedAt =
      safeString(row.founded_at)
      || safeString(row.founded_year)
      || safeString(raw.founded)
      || safeString(raw.founding_time)
      || safeString(raw.founding_year);
    const explicitFounderDjId = safeString(row.founder_dj_id);
    const inferredFounderDjId =
      founderName
        ? founderDjByName.get(normalizeLookupKey(founderName)) ?? null
        : null;
    const founderDjId = explicitFounderDjId ?? inferredFounderDjId;

    let avatarUrl = avatarSourceUrl;
    let backgroundUrl = backgroundSourceUrl;

    if (ossClient && avatarSourceUrl) {
      try {
        const ext = detectExt(avatarSourceUrl, null);
        const objectKey = `${ossPrefix}/${slug}/avatar${ext}`;
        const uploaded = await uploadToOss(ossClient, avatarSourceUrl, objectKey);
        if (uploaded) {
          avatarUrl = uploaded;
          avatarUploaded += 1;
        }
      } catch (error) {
        console.warn(`[labels-import] avatar upload failed: ${name}`, (error as Error).message);
      }
    }

    if (ossClient && backgroundSourceUrl) {
      try {
        const ext = detectExt(backgroundSourceUrl, null);
        const objectKey = `${ossPrefix}/${slug}/background${ext}`;
        const uploaded = await uploadToOss(ossClient, backgroundSourceUrl, objectKey);
        if (uploaded) {
          backgroundUrl = uploaded;
          backgroundUploaded += 1;
        }
      } catch (error) {
        console.warn(`[labels-import] background upload failed: ${name}`, (error as Error).message);
      }
    }

    try {
      const payload: Prisma.LabelUncheckedCreateInput = {
        name,
        slug,
        profileUrl,
        profileSlug: safeString(row.profile_slug),
        sourcePage: safeNumber(row.source_page),
        sourceListingUrl: safeString(row.source_listing_url),
        cardId: safeString(row.card_id),
        logoUrl: safeString(row.logo_url),
        avatarSourceUrl,
        backgroundSourceUrl,
        avatarUrl,
        backgroundUrl,
        soundcloudFollowers: safeNumber(row.soundcloud_followers),
        likes: safeNumber(row.likes),
        nation: safeString(row.nation),
        genresPreview: safeString(row.genres_preview),
        latestReleaseListing: safeString(row.latest_release_listing),
        introductionPreview: safeString(row.introduction_preview),
        locationPeriod: safeString(row.location_period),
        introduction: safeString(row.introduction),
        genres: safeStringArray(row.genres),
        contacts: contactsJson,
        linksInWeb: linksJson,
        generalContactEmail: safeString(row.general_contact_email),
        demoSubmissionUrl: safeString(row.demo_submission_url),
        demoSubmissionDisplay: safeString(row.demo_submission_display),
        facebookUrl: mappedLinks.facebookUrl,
        soundcloudUrl: mappedLinks.soundcloudUrl,
        musicPurchaseUrl: mappedLinks.musicPurchaseUrl,
        officialWebsiteUrl: mappedLinks.officialWebsiteUrl,
        founderName,
        foundedAt,
        founderDjId,
      };

      await prisma.label.upsert({
        where: { profileUrl },
        update: payload,
        create: payload,
      });

      createdOrUpdated += 1;
      if ((i + 1) % 20 === 0 || i === sliced.length - 1) {
        console.log(`[labels-import] processed ${i + 1}/${sliced.length}`);
      }
    } catch (error) {
      failed += 1;
      console.error(`[labels-import] upsert failed: ${name}`, error);
    }
  }

  console.log('');
  console.log('[labels-import] finished');
  console.log(`input: ${options.inputPath}`);
  console.log(`processed: ${sliced.length}`);
  console.log(`success: ${createdOrUpdated}`);
  console.log(`failed: ${failed}`);
  console.log(`avatar uploaded: ${avatarUploaded}`);
  console.log(`background uploaded: ${backgroundUploaded}`);
};

run()
  .catch((error) => {
    console.error('[labels-import] fatal error:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
