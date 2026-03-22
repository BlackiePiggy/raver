import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import fs from 'node:fs/promises';
import path from 'node:path';

const prisma = new PrismaClient();

const SOURCE_BASE_URL = 'https://edmdancedirectory.com';
const ALL_INDEX_API = `${SOURCE_BASE_URL}/api/djs/all-index`;
const DEFAULT_CONCURRENCY = 8;
const DEFAULT_RETRIES = 4;
const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

const CACHE_DIR = path.join(__dirname, '.cache');
const PROGRESS_FILE = path.join(CACHE_DIR, 'edmdd-dj-import-progress.json');
const REPORT_FILE = path.join(CACHE_DIR, 'edmdd-dj-import-report.json');
const EXTRA_FIELDS_FILE = path.join(CACHE_DIR, 'edmdd-dj-extra-fields.json');
const SEED_EXPORT_FILE = path.join(CACHE_DIR, 'edmdd-dj-seed-list.json');

type DjIndexItem = {
  slug: string;
  name: string;
};

type DjIndexPayload = {
  allDJs?: DjIndexItem[];
  totalCount?: number;
};

type ProgressPayload = {
  completedSlugs: string[];
  failed: Array<{ slug: string; error: string }>;
};

type FieldObservation = {
  nonNullCount: number;
  samples: unknown[];
};

type ImportStats = {
  totalFromSource: number;
  totalValidSlug: number;
  skippedEmptySlug: number;
  skippedCompletedFromProgress: number;
  created: number;
  updated: number;
  failed: number;
  processed: number;
};

function envNumber(name: string, fallback: number): number {
  const value = process.env[name];
  if (!value) return fallback;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.floor(parsed);
}

function cleanString(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function safeInt(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string') {
    const normalized = value.trim();
    if (!normalized) return null;
    const parsed = Number(normalized);
    if (Number.isFinite(parsed)) return Math.trunc(parsed);
  }
  return null;
}

function safeDate(value: unknown): Date | null {
  const raw = cleanString(value);
  if (!raw) return null;
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) return null;
  return date;
}

function normalizeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return Array.from(new Set(value.map((entry) => cleanString(entry)).filter((entry): entry is string => Boolean(entry))));
}

function normalizeAliases(value: unknown): string[] {
  if (Array.isArray(value)) {
    return Array.from(
      new Set(value.map((entry) => cleanString(entry)).filter((entry): entry is string => Boolean(entry)))
    );
  }
  const single = cleanString(value);
  if (!single) return [];
  return Array.from(
    new Set(
      single
        .split(/[;,/]/)
        .map((entry) => entry.trim())
        .filter(Boolean)
    )
  );
}

function parseCountryFromLocation(location: unknown): string | null {
  const raw = cleanString(location);
  if (!raw) return null;
  const segments = raw
    .split(',')
    .map((segment) => segment.trim())
    .filter(Boolean);
  if (segments.length === 0) return null;
  return segments[segments.length - 1] ?? null;
}

function parseSpotifyArtistId(value: unknown): string | null {
  const raw = cleanString(value);
  if (!raw) return null;
  const match = raw.match(/spotify\.com\/artist\/([A-Za-z0-9]+)/i);
  return match?.[1] ?? null;
}

function pickFirstString(...candidates: unknown[]): string | null {
  for (const candidate of candidates) {
    const normalized = cleanString(candidate);
    if (normalized) return normalized;
  }
  return null;
}

function isPresent(value: unknown): boolean {
  if (value === null || value === undefined) return false;
  if (typeof value === 'string') return value.trim().length > 0;
  if (Array.isArray(value)) return value.length > 0;
  return true;
}

function sampleValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.slice(0, 3);
  if (typeof value === 'string' && value.length > 180) return `${value.slice(0, 180)}...`;
  return value;
}

function observeSourceFields(
  source: Record<string, unknown>,
  observed: Map<string, FieldObservation>
): void {
  for (const [key, value] of Object.entries(source)) {
    if (!isPresent(value)) continue;
    const current = observed.get(key) ?? { nonNullCount: 0, samples: [] };
    current.nonNullCount += 1;
    if (current.samples.length < 5) {
      current.samples.push(sampleValue(value));
    }
    observed.set(key, current);
  }
}

async function sleep(ms: number): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchJsonWithRetry<T>(url: string, retries: number): Promise<T | null> {
  let attempt = 0;
  while (attempt <= retries) {
    try {
      const response = await fetch(url, {
        headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' },
      });
      if (response.status === 404) return null;
      if (response.status === 429 || response.status >= 500) {
        if (attempt === retries) {
          throw new Error(`HTTP ${response.status}`);
        }
        const delayMs = 400 * (attempt + 1);
        await sleep(delayMs);
        attempt += 1;
        continue;
      }
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      return (await response.json()) as T;
    } catch (error) {
      if (attempt === retries) {
        throw error;
      }
      const delayMs = 400 * (attempt + 1);
      await sleep(delayMs);
      attempt += 1;
    }
  }
  return null;
}

async function loadProgress(progressFile: string): Promise<ProgressPayload> {
  try {
    const content = await fs.readFile(progressFile, 'utf-8');
    const parsed = JSON.parse(content) as ProgressPayload;
    return {
      completedSlugs: Array.isArray(parsed.completedSlugs) ? parsed.completedSlugs : [],
      failed: Array.isArray(parsed.failed) ? parsed.failed : [],
    };
  } catch {
    return { completedSlugs: [], failed: [] };
  }
}

async function saveProgress(progressFile: string, progress: ProgressPayload): Promise<void> {
  const payload: ProgressPayload = {
    completedSlugs: Array.from(new Set(progress.completedSlugs)),
    failed: progress.failed,
  };
  await fs.writeFile(progressFile, JSON.stringify(payload, null, 2), 'utf-8');
}

function mapSourceToDjUpdate(source: Record<string, unknown>): Record<string, unknown> {
  const aliases = normalizeAliases(source.aliases);
  const country = parseCountryFromLocation(source.location);
  const spotifyId = pickFirstString(source.spotifyArtistId, parseSpotifyArtistId(source.spotify));
  const instagramUrl = cleanString(source.instagram);
  const soundcloudUrl = cleanString(source.soundcloud);
  const twitterUrl = cleanString(source.twitter);
  const avatarUrl = cleanString(source.image);
  const bio = cleanString(source.bio);
  const discogsId = cleanString(source.discogsId);
  const verificationConfidence = Number(source.verificationConfidence ?? 0);
  const isVerified = Boolean(cleanString(source.verifiedAt)) || verificationConfidence >= 0.7;
  const sourceId = cleanString(source.id);

  const sourceAddedAt = safeDate(source.addedAt);
  const sourceUpdatedAt = safeDate(source.updatedAt);
  const sourceArtistType = cleanString(source.artistType);
  const sourceDataSource = cleanString(source.dataSource);
  const sourceSameAs = normalizeStringArray(source.sameAs);
  const sourceGenres = normalizeStringArray(source.genres);
  const sourceLabels = normalizeStringArray(source.labels);
  const sourceWebsite = cleanString(source.website);
  const sourceWikipedia = cleanString(source.wikipedia);
  const sourceTiktok = cleanString(source.tiktok);
  const sourceBookingAgency = cleanString(source.bookingAgency);
  const sourceBookingAgent = cleanString(source.bookingAgent);
  const sourceBookingUrl = cleanString(source.bookingUrl);
  const sourceRealName = cleanString(source.realName);
  const sourceBirthDate = cleanString(source.birthDate);
  const sourceNationality = cleanString(source.nationality);
  const sourceYearsActive = cleanString(source.yearsActive);
  const sourceDiscographyCount = safeInt(source.discographyCount);
  const sourceUpcomingShows = safeInt(source.upcomingShows);
  const sourceLineupEventCount = safeInt(source.lineupEventCount);
  const sourceLineupCityCount = safeInt(source.lineupCityCount);
  const sourcePromotionScore = safeInt(source.promotionScore);
  const sourceTotalVotes = safeInt(source.totalVotes);
  const sourceTrendingScore = safeInt(source.trendingScore);
  const sourceVerificationScore = safeInt(source.verificationScore);
  const sourceLastEnrichedAt = safeDate(source.lastEnrichedAt);
  const sourceLastImageAttemptAt = safeDate(source.lastImageAttemptAt);
  const sourceNextImageAttemptAt = safeDate(source.nextImageAttemptAt);
  const sourceSetlistFmMbid = cleanString(source.setlistFmMbid);
  const sourceSetlistFmUrl = cleanString(source.setlistFmUrl);
  const sourceSetlistFmFetchedAt = safeDate(source.setlistFmFetchedAt);

  const patch: Record<string, unknown> = {
    lastSyncedAt: new Date(),
  };
  if (aliases.length > 0) patch.aliases = aliases;
  if (country) patch.country = country;
  if (spotifyId) patch.spotifyId = spotifyId;
  if (instagramUrl) patch.instagramUrl = instagramUrl;
  if (soundcloudUrl) patch.soundcloudUrl = soundcloudUrl;
  if (twitterUrl) patch.twitterUrl = twitterUrl;
  if (avatarUrl) patch.avatarUrl = avatarUrl;
  if (avatarUrl) patch.avatarSourceUrl = avatarUrl;
  if (bio) patch.bio = bio;
  if (discogsId) patch.discogsId = discogsId;
  if (isVerified) patch.isVerified = true;
  if (sourceId) patch.sourceId = sourceId;
  if (sourceAddedAt) patch.sourceAddedAt = sourceAddedAt;
  if (sourceUpdatedAt) patch.sourceUpdatedAt = sourceUpdatedAt;
  if (sourceArtistType) patch.sourceArtistType = sourceArtistType;
  if (sourceDataSource) patch.sourceDataSource = sourceDataSource;
  patch.sourceSameAs = sourceSameAs;
  patch.sourceGenres = sourceGenres;
  patch.sourceLabels = sourceLabels;
  if (sourceWebsite) patch.sourceWebsite = sourceWebsite;
  if (sourceWikipedia) patch.sourceWikipedia = sourceWikipedia;
  if (sourceTiktok) patch.sourceTiktok = sourceTiktok;
  if (sourceBookingAgency) patch.sourceBookingAgency = sourceBookingAgency;
  if (sourceBookingAgent) patch.sourceBookingAgent = sourceBookingAgent;
  if (sourceBookingUrl) patch.sourceBookingUrl = sourceBookingUrl;
  if (sourceRealName) patch.sourceRealName = sourceRealName;
  if (sourceBirthDate) patch.sourceBirthDate = sourceBirthDate;
  if (sourceNationality) patch.sourceNationality = sourceNationality;
  if (sourceYearsActive) patch.sourceYearsActive = sourceYearsActive;
  if (sourceDiscographyCount !== null) patch.sourceDiscographyCount = sourceDiscographyCount;
  if (sourceUpcomingShows !== null) patch.sourceUpcomingShows = sourceUpcomingShows;
  if (sourceLineupEventCount !== null) patch.sourceLineupEventCount = sourceLineupEventCount;
  if (sourceLineupCityCount !== null) patch.sourceLineupCityCount = sourceLineupCityCount;
  if (sourcePromotionScore !== null) patch.sourcePromotionScore = sourcePromotionScore;
  if (sourceTotalVotes !== null) patch.sourceTotalVotes = sourceTotalVotes;
  if (sourceTrendingScore !== null) patch.sourceTrendingScore = sourceTrendingScore;
  if (sourceVerificationScore !== null) patch.sourceVerificationScore = sourceVerificationScore;
  if (sourceLastEnrichedAt) patch.sourceLastEnrichedAt = sourceLastEnrichedAt;
  if (sourceLastImageAttemptAt) patch.sourceLastImageAttemptAt = sourceLastImageAttemptAt;
  if (sourceNextImageAttemptAt) patch.sourceNextImageAttemptAt = sourceNextImageAttemptAt;
  if (sourceSetlistFmMbid) patch.sourceSetlistFmMbid = sourceSetlistFmMbid;
  if (sourceSetlistFmUrl) patch.sourceSetlistFmUrl = sourceSetlistFmUrl;
  if (sourceSetlistFmFetchedAt) patch.sourceSetlistFmFetchedAt = sourceSetlistFmFetchedAt;

  return patch;
}

async function main(): Promise<void> {
  const startedAt = new Date();
  const concurrency = envNumber('EDMDD_CONCURRENCY', DEFAULT_CONCURRENCY);
  const retries = envNumber('EDMDD_FETCH_RETRIES', DEFAULT_RETRIES);
  const limit = process.env.EDMDD_LIMIT ? envNumber('EDMDD_LIMIT', 0) : 0;
  const ignoreProgress = process.env.EDMDD_IGNORE_PROGRESS === '1';
  const resetProgress = process.env.EDMDD_RESET_PROGRESS === '1';
  const onlySlugs = (process.env.EDMDD_ONLY_SLUGS || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  const onlySlugSet = new Set(onlySlugs);

  await fs.mkdir(CACHE_DIR, { recursive: true });

  console.log(`开始抓取 DJ 列表: ${ALL_INDEX_API}`);
  const indexPayload = await fetchJsonWithRetry<DjIndexPayload>(ALL_INDEX_API, retries);
  if (!indexPayload?.allDJs || !Array.isArray(indexPayload.allDJs)) {
    throw new Error('无法解析 /api/djs/all-index');
  }

  const totalFromSource = indexPayload.totalCount ?? indexPayload.allDJs.length;
  const skippedEmptySlug = indexPayload.allDJs.filter((item) => !cleanString(item.slug)).length;
  const validSeed = indexPayload.allDJs
    .map((item) => ({ name: cleanString(item.name), slug: cleanString(item.slug) }))
    .filter((item): item is { name: string; slug: string } => Boolean(item.name && item.slug));

  await fs.writeFile(
    SEED_EXPORT_FILE,
    JSON.stringify(
      validSeed.map((item) => ({
        name: item.name,
        slug: item.slug,
        url: `${SOURCE_BASE_URL}/djs/${item.slug}`,
      })),
      null,
      2
    ),
    'utf-8'
  );

  if (resetProgress) {
    await saveProgress(PROGRESS_FILE, { completedSlugs: [], failed: [] });
  }

  const progress = await loadProgress(PROGRESS_FILE);
  const completedSet = new Set(ignoreProgress ? [] : progress.completedSlugs);
  const failedRows: Array<{ slug: string; error: string }> = ignoreProgress ? [] : [...progress.failed];

  let targets = validSeed.filter((item) => !completedSet.has(item.slug));
  if (onlySlugSet.size > 0) {
    targets = targets.filter((item) => onlySlugSet.has(item.slug));
  }
  if (limit > 0) {
    targets = targets.slice(0, limit);
  }

  const existingSlugs = new Set(
    (await prisma.dJ.findMany({ select: { slug: true } }))
      .map((item) => cleanString(item.slug))
      .filter((item): item is string => Boolean(item))
  );

  const observedSourceFields = new Map<string, FieldObservation>();
  const stats: ImportStats = {
    totalFromSource,
    totalValidSlug: validSeed.length,
    skippedEmptySlug,
    skippedCompletedFromProgress: validSeed.length - targets.length,
    created: 0,
    updated: 0,
    failed: 0,
    processed: 0,
  };

  console.log(
    `开始导入: valid=${stats.totalValidSlug}, 已完成跳过=${stats.skippedCompletedFromProgress}, 本次处理=${targets.length}, 并发=${concurrency}`
  );

  let cursor = 0;
  const checkpointEvery = 100;

  async function worker(workerId: number): Promise<void> {
    while (true) {
      const index = cursor;
      cursor += 1;
      if (index >= targets.length) return;
      const target = targets[index];
      if (!target) return;
      const detailUrl = `${SOURCE_BASE_URL}/api/djs/${encodeURIComponent(target.slug)}`;
      try {
        const detail = await fetchJsonWithRetry<Record<string, unknown>>(detailUrl, retries);
        if (!detail) {
          throw new Error('detail_not_found');
        }

        observeSourceFields(detail, observedSourceFields);
        const patch = mapSourceToDjUpdate(detail);
        const name = pickFirstString(detail.name, target.name) ?? target.name;

        const createData: Record<string, unknown> = {
          name,
          slug: target.slug,
          isVerified: false,
          followerCount: 0,
          ...patch,
        };

        const updateData: Record<string, unknown> = {
          name,
          ...patch,
        };

        await prisma.dJ.upsert({
          where: { slug: target.slug },
          create: createData as never,
          update: updateData as never,
        });

        if (existingSlugs.has(target.slug)) {
          stats.updated += 1;
        } else {
          stats.created += 1;
          existingSlugs.add(target.slug);
        }

        completedSet.add(target.slug);
        stats.processed += 1;

        if (!ignoreProgress && stats.processed % checkpointEvery === 0) {
          await saveProgress(PROGRESS_FILE, {
            completedSlugs: Array.from(completedSet),
            failed: failedRows,
          });
          console.log(
            `进度: ${stats.processed}/${targets.length} (created=${stats.created}, updated=${stats.updated}, failed=${stats.failed})`
          );
        }
      } catch (error) {
        stats.failed += 1;
        stats.processed += 1;
        const message = error instanceof Error ? error.message : String(error);
        failedRows.push({ slug: target.slug, error: message });
        console.error(`[worker-${workerId}] 失败 ${target.slug}: ${message}`);
      }
    }
  }

  await Promise.all(Array.from({ length: concurrency }, (_, i) => worker(i + 1)));

  if (!ignoreProgress) {
    await saveProgress(PROGRESS_FILE, {
      completedSlugs: Array.from(completedSet),
      failed: failedRows,
    });
  }

  const djSchemaFields = new Set([
    'id',
    'name',
    'aliases',
    'slug',
    'bio',
    'avatarUrl',
    'avatarSourceUrl',
    'bannerUrl',
    'country',
    'spotifyId',
    'appleMusicId',
    'soundcloudUrl',
    'instagramUrl',
    'twitterUrl',
    'isVerified',
    'followerCount',
    'raId',
    'discogsId',
    'beatportId',
    'createdAt',
    'updatedAt',
    'lastSyncedAt',
    'sourceId',
    'sourceAddedAt',
    'sourceUpdatedAt',
    'sourceArtistType',
    'sourceDataSource',
    'sourceSameAs',
    'sourceGenres',
    'sourceLabels',
    'sourceWebsite',
    'sourceWikipedia',
    'sourceTiktok',
    'sourceBookingAgency',
    'sourceBookingAgent',
    'sourceBookingUrl',
    'sourceRealName',
    'sourceBirthDate',
    'sourceNationality',
    'sourceYearsActive',
    'sourceDiscographyCount',
    'sourceUpcomingShows',
    'sourceLineupEventCount',
    'sourceLineupCityCount',
    'sourcePromotionScore',
    'sourceTotalVotes',
    'sourceTrendingScore',
    'sourceVerificationScore',
    'sourceLastEnrichedAt',
    'sourceLastImageAttemptAt',
    'sourceNextImageAttemptAt',
    'sourceSetlistFmMbid',
    'sourceSetlistFmUrl',
    'sourceSetlistFmFetchedAt',
  ]);

  const mappedSourceFields = new Set([
    'name',
    'slug',
    'aliases',
    'bio',
    'image',
    'location',
    'spotifyArtistId',
    'spotify',
    'soundcloud',
    'instagram',
    'twitter',
    'discogsId',
    'verificationConfidence',
    'verifiedAt',
    'id',
    'addedAt',
    'updatedAt',
    'artistType',
    'dataSource',
    'sameAs',
    'genres',
    'labels',
    'website',
    'wikipedia',
    'tiktok',
    'bookingAgency',
    'bookingAgent',
    'bookingUrl',
    'realName',
    'birthDate',
    'nationality',
    'yearsActive',
    'discographyCount',
    'upcomingShows',
    'lineupEventCount',
    'lineupCityCount',
    'promotionScore',
    'totalVotes',
    'trendingScore',
    'verificationScore',
    'lastEnrichedAt',
    'lastImageAttemptAt',
    'nextImageAttemptAt',
    'setlistFmMbid',
    'setlistFmUrl',
    'setlistFmFetchedAt',
  ]);

  const extraFields = Array.from(observedSourceFields.entries())
    .filter(([field]) => !mappedSourceFields.has(field))
    .map(([field, observation]) => ({
      sourceField: field,
      nonNullCount: observation.nonNullCount,
      sampleValues: observation.samples,
      alreadyInDjTable: djSchemaFields.has(field),
    }))
    .sort((a, b) => b.nonNullCount - a.nonNullCount || a.sourceField.localeCompare(b.sourceField));

  const finishedAt = new Date();
  const report = {
    startedAt: startedAt.toISOString(),
    finishedAt: finishedAt.toISOString(),
    durationSeconds: Math.round((finishedAt.getTime() - startedAt.getTime()) / 1000),
    stats,
    files: {
      progress: PROGRESS_FILE,
      report: REPORT_FILE,
      extraFields: EXTRA_FIELDS_FILE,
      seedList: SEED_EXPORT_FILE,
    },
  };

  await fs.writeFile(REPORT_FILE, JSON.stringify(report, null, 2), 'utf-8');
  if (observedSourceFields.size > 0) {
    await fs.writeFile(EXTRA_FIELDS_FILE, JSON.stringify(extraFields, null, 2), 'utf-8');
  }

  console.log('导入完成');
  console.log(JSON.stringify(report, null, 2));
  console.log(`超出当前映射字段清单: ${EXTRA_FIELDS_FILE}`);
}

main()
  .catch((error) => {
    console.error('导入失败:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
