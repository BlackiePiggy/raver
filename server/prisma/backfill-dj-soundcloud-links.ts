import 'dotenv/config';
import path from 'node:path';
import fs from 'node:fs/promises';
import { PrismaClient, Prisma } from '@prisma/client';
import soundcloudArtistService from '../src/services/soundcloud-artist.service';

const prisma = new PrismaClient();

const DEFAULT_BEFORE = '2026-03-28T00:00:00+08:00';
const DEFAULT_CONCURRENCY = 4;
const DEFAULT_LIMIT = 0;
const DEFAULT_SC_SEARCH_LIMIT = 25;
const DEFAULT_REPORT_PREFIX = 'dj-soundcloud-link-backfill';

type DJRow = {
  id: string;
  name: string;
  createdAt: Date;
  instagramUrl: string | null;
  facebookUrl: string | null;
  twitterUrl: string | null;
  youtubeUrl: string | null;
  soundcloudUrl: string | null;
  trackCount: number | null;
  playlistCount: number | null;
  soundCloudFollowers: number | null;
  soundCloudFavorites: number | null;
};

type RowResultStatus = 'updated' | 'skipped_no_match' | 'skipped_no_fields' | 'skipped_empty_name' | 'error';

type RowResult = {
  djId: string;
  djName: string;
  createdAt: string;
  status: RowResultStatus;
  reason?: string;
  matchedCandidate?: {
    soundcloudId: string;
    name: string;
    username: string;
    followersCount: number;
  };
  appliedFields?: string[];
};

type ReportPayload = {
  startedAt: string;
  finishedAt: string;
  durationMs: number;
  config: {
    before: string;
    beforeEpochMs: number;
    concurrency: number;
    limit: number;
    startIndex: number;
    soundcloudSearchLimit: number;
    dryRun: boolean;
  };
  totals: {
    totalRowsBeforeStart: number;
    targetRows: number;
    updated: number;
    skippedNoMatch: number;
    skippedNoFields: number;
    skippedEmptyName: number;
    errored: number;
  };
  errors: Array<{
    djId: string;
    djName: string;
    error: string;
  }>;
  rows: RowResult[];
};

type SoundCloudCandidate = Awaited<ReturnType<typeof soundcloudArtistService.searchUsersByName>>[number];
type SoundCloudWebLinks = Awaited<ReturnType<typeof soundcloudArtistService.getWebProfileLinksByUserId>>;

function envInt(name: string, fallback: number, min = 0): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(min, Math.floor(parsed));
}

function exactNameKey(value: string): string {
  return value.trim().toLowerCase();
}

function toNonEmptyString(value: string | null | undefined): string | null {
  const text = typeof value === 'string' ? value.trim() : '';
  return text ? text : null;
}

function buildUpdateData(dj: DJRow, candidate: SoundCloudCandidate, webLinks: SoundCloudWebLinks | null) {
  const updateData: Prisma.DJUpdateInput = {};
  const appliedFields: string[] = [];

  const setIfPresent = (
    field:
      | 'instagramUrl'
      | 'facebookUrl'
      | 'twitterUrl'
      | 'youtubeUrl'
      | 'soundcloudUrl',
    value: string | null | undefined
  ) => {
    const nextValue = toNonEmptyString(value);
    if (!nextValue) return;
    const prevValue = toNonEmptyString(dj[field]);
    if (prevValue === nextValue) return;
    updateData[field] = nextValue;
    appliedFields.push(field);
  };

  const setNumberIfPresent = (
    field: 'trackCount' | 'playlistCount' | 'soundCloudFollowers' | 'soundCloudFavorites',
    value: number | null | undefined
  ) => {
    if (!Number.isFinite(value)) return;
    const nextValue = Math.max(0, Math.floor(Number(value)));
    if (dj[field] === nextValue) return;
    updateData[field] = nextValue;
    appliedFields.push(field);
  };

  setIfPresent('instagramUrl', webLinks?.instagramUrl || candidate.instagramUrl);
  setIfPresent('facebookUrl', webLinks?.facebookUrl || candidate.facebookUrl);
  setIfPresent('twitterUrl', webLinks?.twitterUrl || candidate.twitterUrl);
  setIfPresent('youtubeUrl', webLinks?.youtubeUrl || candidate.youtubeUrl);
  setIfPresent('soundcloudUrl', candidate.permalinkUrl || candidate.permalink || null);

  setNumberIfPresent('trackCount', candidate.trackCount);
  setNumberIfPresent('playlistCount', candidate.playlistCount);
  setNumberIfPresent('soundCloudFollowers', candidate.followersCount);
  setNumberIfPresent('soundCloudFavorites', candidate.publicFavoritesCount);

  return { updateData, appliedFields };
}

async function processOne(
  dj: DJRow,
  soundcloudSearchLimit: number,
  dryRun: boolean
): Promise<RowResult> {
  const name = dj.name.trim();
  if (!name) {
    return {
      djId: dj.id,
      djName: dj.name,
      createdAt: dj.createdAt.toISOString(),
      status: 'skipped_empty_name',
      reason: 'DJ name is empty',
    };
  }

  const targetKey = exactNameKey(name);
  const candidates = await soundcloudArtistService.searchUsersByName(name, soundcloudSearchLimit, {
    enrichWebProfiles: false,
  });
  const exactMatches = candidates.filter((item) => {
    const itemName = exactNameKey(item.name);
    const itemUsername = exactNameKey(item.username);
    return itemName === targetKey || itemUsername === targetKey;
  });

  if (!exactMatches.length) {
    return {
      djId: dj.id,
      djName: dj.name,
      createdAt: dj.createdAt.toISOString(),
      status: 'skipped_no_match',
      reason: 'No exact case-insensitive SoundCloud name match',
    };
  }

  const matched = exactMatches.sort((lhs, rhs) => {
    if (rhs.followersCount !== lhs.followersCount) return rhs.followersCount - lhs.followersCount;
    if (rhs.trackCount !== lhs.trackCount) return rhs.trackCount - lhs.trackCount;
    return lhs.soundcloudId.localeCompare(rhs.soundcloudId);
  })[0];

  let webLinks: SoundCloudWebLinks | null = null;
  try {
    webLinks = await soundcloudArtistService.getWebProfileLinksByUserId(matched.soundcloudId);
  } catch (_error) {
    webLinks = null;
  }

  const { updateData, appliedFields } = buildUpdateData(dj, matched, webLinks);
  if (!appliedFields.length) {
    return {
      djId: dj.id,
      djName: dj.name,
      createdAt: dj.createdAt.toISOString(),
      status: 'skipped_no_fields',
      reason: 'Matched candidate has no new writable fields',
      matchedCandidate: {
        soundcloudId: matched.soundcloudId,
        name: matched.name,
        username: matched.username,
        followersCount: matched.followersCount,
      },
    };
  }

  if (!dryRun) {
    await prisma.dJ.update({
      where: { id: dj.id },
      data: updateData,
    });
  }

  return {
    djId: dj.id,
    djName: dj.name,
    createdAt: dj.createdAt.toISOString(),
    status: 'updated',
    appliedFields,
    matchedCandidate: {
      soundcloudId: matched.soundcloudId,
      name: matched.name,
      username: matched.username,
      followersCount: matched.followersCount,
    },
  };
}

async function main() {
  const startedAt = new Date();
  const beforeRaw = process.env.DJ_SC_BACKFILL_BEFORE?.trim() || DEFAULT_BEFORE;
  const beforeDate = new Date(beforeRaw);
  if (!Number.isFinite(beforeDate.getTime())) {
    throw new Error(`Invalid DJ_SC_BACKFILL_BEFORE value: ${beforeRaw}`);
  }

  const concurrency = envInt('DJ_SC_BACKFILL_CONCURRENCY', DEFAULT_CONCURRENCY, 1);
  const limit = envInt('DJ_SC_BACKFILL_LIMIT', DEFAULT_LIMIT, 0);
  const startIndexRaw = envInt('DJ_SC_BACKFILL_START_INDEX', 0, 0);
  const soundcloudSearchLimit = envInt('DJ_SC_BACKFILL_SC_LIMIT', DEFAULT_SC_SEARCH_LIMIT, 1);
  const dryRun = process.env.DJ_SC_BACKFILL_DRY_RUN === '1';

  if (!soundcloudArtistService.isConfigured()) {
    throw new Error('SoundCloud credentials are not configured. Please set SOUNDCLOUD_CLIENT_ID / SOUNDCLOUD_CLIENT_SECRET.');
  }

  const rows = await prisma.dJ.findMany({
    where: {
      createdAt: { lt: beforeDate },
    },
    select: {
      id: true,
      name: true,
      createdAt: true,
      instagramUrl: true,
      facebookUrl: true,
      twitterUrl: true,
      youtubeUrl: true,
      soundcloudUrl: true,
      trackCount: true,
      playlistCount: true,
      soundCloudFollowers: true,
      soundCloudFavorites: true,
    },
    orderBy: { createdAt: 'asc' },
  });

  const limitedRows = limit > 0 ? rows.slice(0, limit) : rows;
  const startIndex = Math.min(startIndexRaw, limitedRows.length);
  const targets = limitedRows.slice(startIndex);
  console.log(
    `[dj-sc-backfill] start total=${limitedRows.length} fromIndex=${startIndex} targets=${targets.length} before=${beforeDate.toISOString()} concurrency=${concurrency} dryRun=${dryRun}`
  );

  const results: RowResult[] = [];
  const errors: ReportPayload['errors'] = [];
  let cursor = 0;

  async function worker(workerIndex: number): Promise<void> {
    while (true) {
      const idx = cursor;
      cursor += 1;
      if (idx >= targets.length) return;
      const dj = targets[idx];
      if (!dj) return;
      const absoluteIndex = startIndex + idx;

      try {
        console.log(`[worker-${workerIndex}] processing ${absoluteIndex + 1}/${limitedRows.length} ${dj.id} ${dj.name}`);
        const result = await processOne(dj, soundcloudSearchLimit, dryRun);
        results.push(result);
        if (result.status === 'updated') {
          console.log(
            `[worker-${workerIndex}] updated ${dj.id} ${dj.name} fields=${(result.appliedFields || []).join(',')}`
          );
        } else {
          console.log(`[worker-${workerIndex}] ${result.status} ${dj.id} ${dj.name} ${result.reason || ''}`.trim());
        }
      } catch (error) {
        const message = error instanceof Error ? `${error.name}: ${error.message}` : String(error);
        results.push({
          djId: dj.id,
          djName: dj.name,
          createdAt: dj.createdAt.toISOString(),
          status: 'error',
          reason: message,
        });
        errors.push({
          djId: dj.id,
          djName: dj.name,
          error: message,
        });
        console.error(`[worker-${workerIndex}] error ${dj.id} ${dj.name}: ${message}`);
      }
    }
  }

  const workers = Array.from({ length: concurrency }, (_, i) => worker(i + 1));
  await Promise.all(workers);

  const totals: ReportPayload['totals'] = {
    totalRowsBeforeStart: limitedRows.length,
    targetRows: targets.length,
    updated: results.filter((r) => r.status === 'updated').length,
    skippedNoMatch: results.filter((r) => r.status === 'skipped_no_match').length,
    skippedNoFields: results.filter((r) => r.status === 'skipped_no_fields').length,
    skippedEmptyName: results.filter((r) => r.status === 'skipped_empty_name').length,
    errored: results.filter((r) => r.status === 'error').length,
  };

  const finishedAt = new Date();
  const report: ReportPayload = {
    startedAt: startedAt.toISOString(),
    finishedAt: finishedAt.toISOString(),
    durationMs: finishedAt.getTime() - startedAt.getTime(),
    config: {
      before: beforeRaw,
      beforeEpochMs: beforeDate.getTime(),
      concurrency,
      limit,
      startIndex,
      soundcloudSearchLimit,
      dryRun,
    },
    totals,
    errors,
    rows: results,
  };

  const cacheDir = path.join(__dirname, '.cache');
  await fs.mkdir(cacheDir, { recursive: true });
  const stamp = `${finishedAt.getFullYear()}${String(finishedAt.getMonth() + 1).padStart(2, '0')}${String(
    finishedAt.getDate()
  ).padStart(2, '0')}-${String(finishedAt.getHours()).padStart(2, '0')}${String(finishedAt.getMinutes()).padStart(
    2,
    '0'
  )}${String(finishedAt.getSeconds()).padStart(2, '0')}`;
  const reportFile = path.join(cacheDir, `${DEFAULT_REPORT_PREFIX}-${stamp}.json`);
  await fs.writeFile(reportFile, JSON.stringify(report, null, 2), 'utf-8');

  console.log(
    `[dj-sc-backfill] done updated=${totals.updated} skippedNoMatch=${totals.skippedNoMatch} skippedNoFields=${totals.skippedNoFields} skippedEmptyName=${totals.skippedEmptyName} errored=${totals.errored} report=${reportFile}`
  );
}

main()
  .catch((error) => {
    console.error('[dj-sc-backfill] fatal:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
