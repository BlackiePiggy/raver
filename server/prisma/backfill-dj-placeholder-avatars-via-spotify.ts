import 'dotenv/config';
import path from 'node:path';
import fs from 'node:fs/promises';
import OSS from 'ali-oss';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const CACHE_DIR = path.join(__dirname, '.cache');
const PROGRESS_FILE = path.join(CACHE_DIR, 'dj-placeholder-avatar-spotify-progress.json');
const REPORT_FILE = path.join(CACHE_DIR, 'dj-placeholder-avatar-spotify-report.json');

const DEFAULT_CONCURRENCY = 4;
const DEFAULT_RETRIES = 3;
const DEFAULT_TIMEOUT_MS = 25000;
const DEFAULT_OSS_PREFIX = 'djs/avatar';
const DEFAULT_PLACEHOLDER_URL = 'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/djs/avatar/_placeholder.png';

type SpotifyArtist = {
  id: string;
  name: string;
  followers?: { total?: number };
  images?: Array<{ url: string; width?: number; height?: number }>;
  genres?: string[];
  popularity?: number;
};

type ProgressPayload = {
  completedIds: string[];
  failed: Array<{ id: string; slug: string; error: string }>;
};

function cleanString(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function envNumber(name: string, fallback: number): number {
  const value = process.env[name];
  if (!value) return fallback;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.floor(parsed);
}

function normalizeText(value: string): string {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function normalizeLoose(value: string): string {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}

function detectExt(url: string, contentType?: string | null): string {
  const type = (contentType || '').toLowerCase();
  if (type.includes('png')) return '.png';
  if (type.includes('webp')) return '.webp';
  if (type.includes('gif')) return '.gif';
  if (type.includes('jpeg') || type.includes('jpg')) return '.jpg';
  const pathname = (url.split('?')[0] || '').toLowerCase();
  if (pathname.endsWith('.png')) return '.png';
  if (pathname.endsWith('.webp')) return '.webp';
  if (pathname.endsWith('.gif')) return '.gif';
  if (pathname.endsWith('.jpg') || pathname.endsWith('.jpeg')) return '.jpg';
  return '.jpg';
}

function normalizeOssUrl(url: string): string {
  if (url.startsWith('http://')) return `https://${url.slice('http://'.length)}`;
  return url;
}

function normalizePrefix(prefix: string): string {
  return prefix.replace(/^\/+/, '').replace(/\/+$/, '');
}

function parseSpotifyArtistId(url: string | null): string | null {
  if (!url) return null;
  const match = url.match(/spotify\.com\/artist\/([A-Za-z0-9]+)/i);
  return match?.[1] ?? null;
}

async function sleep(ms: number): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function loadProgress(filePath: string): Promise<ProgressPayload> {
  try {
    const raw = await fs.readFile(filePath, 'utf-8');
    const parsed = JSON.parse(raw) as ProgressPayload;
    return {
      completedIds: Array.isArray(parsed.completedIds) ? parsed.completedIds : [],
      failed: Array.isArray(parsed.failed) ? parsed.failed : [],
    };
  } catch {
    return { completedIds: [], failed: [] };
  }
}

async function saveProgress(filePath: string, payload: ProgressPayload): Promise<void> {
  await fs.writeFile(
    filePath,
    JSON.stringify(
      {
        completedIds: Array.from(new Set(payload.completedIds)),
        failed: payload.failed,
      },
      null,
      2
    ),
    'utf-8'
  );
}

class SpotifyClient {
  private accessToken: string | null = null;
  private expiresAtMs = 0;
  private readonly timeoutMs: number;
  private readonly retries: number;

  constructor(timeoutMs: number, retries: number) {
    this.timeoutMs = timeoutMs;
    this.retries = retries;
  }

  private async fetchWithTimeout(url: string, options?: RequestInit): Promise<Response> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      return await fetch(url, { ...options, signal: controller.signal });
    } finally {
      clearTimeout(timer);
    }
  }

  private async ensureToken(): Promise<string> {
    if (this.accessToken && Date.now() < this.expiresAtMs - 10_000) {
      return this.accessToken;
    }

    const clientId = cleanString(process.env.SPOTIFY_CLIENT_ID);
    const clientSecret = cleanString(process.env.SPOTIFY_CLIENT_SECRET);
    if (!clientId || !clientSecret) {
      throw new Error('Missing SPOTIFY_CLIENT_ID or SPOTIFY_CLIENT_SECRET');
    }

    const auth = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
    let attempt = 0;
    while (attempt <= this.retries) {
      try {
        const response = await this.fetchWithTimeout('https://accounts.spotify.com/api/token', {
          method: 'POST',
          headers: {
            Authorization: `Basic ${auth}`,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: new URLSearchParams({ grant_type: 'client_credentials' }).toString(),
        });
        if (!response.ok) {
          if (attempt === this.retries) {
            throw new Error(`Spotify token failed: HTTP ${response.status}`);
          }
          await sleep(400 * (attempt + 1));
          attempt += 1;
          continue;
        }
        const payload = (await response.json()) as { access_token: string; expires_in: number };
        this.accessToken = payload.access_token;
        this.expiresAtMs = Date.now() + payload.expires_in * 1000;
        return this.accessToken;
      } catch (error) {
        if (attempt === this.retries) {
          throw error;
        }
        await sleep(400 * (attempt + 1));
        attempt += 1;
      }
    }
    throw new Error('Spotify token acquisition failed');
  }

  private async spotifyGet<T>(url: string): Promise<T | null> {
    let attempt = 0;
    while (attempt <= this.retries) {
      try {
        const token = await this.ensureToken();
        const response = await this.fetchWithTimeout(url, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (response.status === 404) return null;
        if (response.status === 429) {
          const retryAfterSec = Number(response.headers.get('retry-after') || '1');
          const boundedSec = Math.min(8, Math.max(1, retryAfterSec));
          await sleep(boundedSec * 1000);
          attempt += 1;
          continue;
        }
        if (response.status === 401) {
          this.accessToken = null;
          this.expiresAtMs = 0;
          attempt += 1;
          continue;
        }
        if (!response.ok) {
          if (attempt === this.retries) {
            throw new Error(`Spotify API failed: HTTP ${response.status}`);
          }
          await sleep(300 * (attempt + 1));
          attempt += 1;
          continue;
        }
        return (await response.json()) as T;
      } catch (error) {
        if (attempt === this.retries) {
          throw error;
        }
        await sleep(300 * (attempt + 1));
        attempt += 1;
      }
    }
    return null;
  }

  async getArtistById(artistId: string): Promise<SpotifyArtist | null> {
    const trimmed = artistId.trim();
    if (!trimmed) return null;
    return this.spotifyGet<SpotifyArtist>(`https://api.spotify.com/v1/artists/${encodeURIComponent(trimmed)}`);
  }

  async searchArtists(name: string): Promise<SpotifyArtist[]> {
    const query = name.trim();
    if (!query) return [];
    const params = new URLSearchParams({
      q: query,
      type: 'artist',
      limit: '10',
    });
    const payload = await this.spotifyGet<{ artists?: { items?: SpotifyArtist[] } }>(
      `https://api.spotify.com/v1/search?${params.toString()}`
    );
    return payload?.artists?.items ?? [];
  }
}

function selectBestArtist(name: string, aliases: string[], candidates: SpotifyArtist[]): SpotifyArtist | null {
  if (candidates.length === 0) return null;
  const targetList = [name, ...aliases].map(normalizeText).filter(Boolean);
  const targetLoose = [name, ...aliases].map(normalizeLoose).filter(Boolean);

  let best: { artist: SpotifyArtist; score: number } | null = null;

  for (const artist of candidates) {
    const artistName = artist.name || '';
    const artistNormalized = normalizeText(artistName);
    const artistLoose = normalizeLoose(artistName);
    let score = 0;

    if (targetList.includes(artistNormalized)) score += 120;
    if (targetLoose.includes(artistLoose)) score += 110;

    if (targetList.some((target) => target && artistNormalized.includes(target))) score += 40;
    if (targetList.some((target) => target && target.includes(artistNormalized))) score += 30;

    score += Math.min(30, Math.log10((artist.followers?.total ?? 0) + 1) * 5);
    score += Math.min(20, (artist.popularity ?? 0) / 5);

    if (!best || score > best.score) {
      best = { artist, score };
    }
  }

  if (!best) return null;
  if (best.score < 80) return null;
  return best.artist;
}

function pickBestImage(artist: SpotifyArtist): string | null {
  const images = artist.images ?? [];
  if (images.length === 0) return null;
  const sorted = [...images].sort((a, b) => (b.width ?? 0) - (a.width ?? 0));
  return cleanString(sorted[0]?.url) || null;
}

function buildOssClient(): OSS {
  const region = cleanString(process.env.OSS_REGION);
  const accessKeyId = cleanString(process.env.OSS_ACCESS_KEY_ID);
  const accessKeySecret = cleanString(process.env.OSS_ACCESS_KEY_SECRET);
  const bucket = cleanString(process.env.OSS_BUCKET);
  const endpoint = cleanString(process.env.OSS_ENDPOINT);

  if (!region || !accessKeyId || !accessKeySecret || !bucket) {
    throw new Error('Missing OSS env. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  return new OSS({
    region,
    accessKeyId,
    accessKeySecret,
    bucket,
    endpoint: endpoint || undefined,
    secure: true,
  });
}

async function downloadBuffer(
  url: string,
  timeoutMs: number,
  retries: number
): Promise<{ buffer: Buffer; contentType?: string }> {
  let attempt = 0;
  while (attempt <= retries) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(url, { signal: controller.signal, redirect: 'follow' });
      if (!response.ok) {
        if (attempt === retries) {
          throw new Error(`image download failed: HTTP ${response.status}`);
        }
        await sleep(250 * (attempt + 1));
        attempt += 1;
        continue;
      }
      return {
        buffer: Buffer.from(await response.arrayBuffer()),
        contentType: response.headers.get('content-type') || undefined,
      };
    } catch (error) {
      if (attempt === retries) {
        throw error;
      }
      await sleep(250 * (attempt + 1));
      attempt += 1;
    } finally {
      clearTimeout(timer);
    }
  }
  throw new Error('image download failed');
}

async function main(): Promise<void> {
  const startedAt = new Date();
  const timeoutMs = envNumber('DJ_SPOTIFY_AVATAR_TIMEOUT_MS', DEFAULT_TIMEOUT_MS);
  const retries = envNumber('DJ_SPOTIFY_AVATAR_RETRIES', DEFAULT_RETRIES);
  const concurrency = envNumber('DJ_SPOTIFY_AVATAR_CONCURRENCY', DEFAULT_CONCURRENCY);
  const limit = process.env.DJ_SPOTIFY_AVATAR_LIMIT ? envNumber('DJ_SPOTIFY_AVATAR_LIMIT', 0) : 0;
  const resetProgress = process.env.DJ_SPOTIFY_AVATAR_RESET_PROGRESS === '1';
  const ignoreProgress = process.env.DJ_SPOTIFY_AVATAR_IGNORE_PROGRESS === '1';
  const placeholderUrl = cleanString(process.env.DJ_SPOTIFY_AVATAR_PLACEHOLDER_URL) || DEFAULT_PLACEHOLDER_URL;
  const prefix = normalizePrefix(cleanString(process.env.OSS_DJ_AVATAR_PREFIX) || DEFAULT_OSS_PREFIX);
  const region = cleanString(process.env.OSS_REGION)!;
  const bucket = cleanString(process.env.OSS_BUCKET)!;
  const canonicalPrefix = `https://${bucket}.${region}.aliyuncs.com/${prefix}/`;

  await fs.mkdir(CACHE_DIR, { recursive: true });
  if (resetProgress) {
    await saveProgress(PROGRESS_FILE, { completedIds: [], failed: [] });
  }

  const progress = await loadProgress(PROGRESS_FILE);
  const completedSet = new Set(ignoreProgress ? [] : progress.completedIds);
  const failedRows = ignoreProgress ? [] : [...progress.failed];

  const spotify = new SpotifyClient(timeoutMs, retries);
  const ossClient = buildOssClient();

  const baseTargets = await prisma.dJ.findMany({
    where: {
      OR: [{ avatarUrl: placeholderUrl }, { avatarUrl: '/images/placeholder-dj.png' }, { avatarUrl: null }],
    },
    select: {
      id: true,
      slug: true,
      name: true,
      aliases: true,
      spotifyId: true,
      avatarUrl: true,
      sourceSameAs: true,
      followerCount: true,
    },
    orderBy: { name: 'asc' },
  });

  let targets = baseTargets.filter((row) => !completedSet.has(row.id));
  if (limit > 0) targets = targets.slice(0, limit);

  const stats = {
    totalPlaceholderRows: baseTargets.length,
    targets: targets.length,
    updated: 0,
    failNoArtist: 0,
    failNoImage: 0,
    failed: 0,
    processed: 0,
    bySpotifyIdPath: 0,
    bySearchPath: 0,
  };

  console.log(
    `占位头像修复开始: placeholder=${stats.totalPlaceholderRows}, targets=${stats.targets}, concurrency=${concurrency}`
  );

  let cursor = 0;
  const checkpointEvery = 50;

  async function checkpoint(): Promise<void> {
    if (!ignoreProgress && stats.processed % checkpointEvery === 0) {
      await saveProgress(PROGRESS_FILE, {
        completedIds: Array.from(completedSet),
        failed: failedRows,
      });
      console.log(
        `修复进度: ${stats.processed}/${targets.length}, updated=${stats.updated}, failed=${stats.failed}, noArtist=${stats.failNoArtist}, noImage=${stats.failNoImage}`
      );
    }
  }

  async function worker(workerId: number): Promise<void> {
    while (true) {
      const index = cursor;
      cursor += 1;
      if (index >= targets.length) return;
      const target = targets[index];
      if (!target) return;

      try {
        const sourceSameAs = (target.sourceSameAs || []).map((item) => cleanString(item)).filter(Boolean) as string[];
        const spotifyUrlFromSameAs = sourceSameAs.find((url) => /spotify\.com\/artist\//i.test(url)) || null;
        const spotifyIdFromSameAs = parseSpotifyArtistId(spotifyUrlFromSameAs);
        const seedSpotifyId = cleanString(target.spotifyId) || spotifyIdFromSameAs;

        let artist: SpotifyArtist | null = null;
        if (seedSpotifyId) {
          artist = await spotify.getArtistById(seedSpotifyId);
          if (artist) stats.bySpotifyIdPath += 1;
        }

        if (!artist) {
          const candidates = await spotify.searchArtists(target.name);
          const aliases = (target.aliases || []).map((item) => cleanString(item)).filter(Boolean) as string[];
          artist = selectBestArtist(target.name, aliases, candidates);
          if (artist) stats.bySearchPath += 1;
        }

        if (!artist) {
          stats.failNoArtist += 1;
          stats.failed += 1;
          stats.processed += 1;
          failedRows.push({ id: target.id, slug: target.slug, error: 'spotify_artist_not_found' });
          await checkpoint();
          continue;
        }

        const imageUrl = pickBestImage(artist);
        if (!imageUrl) {
          stats.failNoImage += 1;
          stats.failed += 1;
          stats.processed += 1;
          failedRows.push({ id: target.id, slug: target.slug, error: 'spotify_image_not_found' });
          await checkpoint();
          continue;
        }

        const { buffer, contentType } = await downloadBuffer(imageUrl, timeoutMs, retries);
        const ext = detectExt(imageUrl, contentType);
        const objectKey = `${prefix}/${target.slug}${ext}`;
        const put = await ossClient.put(objectKey, buffer, {
          headers: contentType
            ? {
                'Content-Type': contentType,
                'Cache-Control': 'public, max-age=31536000',
              }
            : {
                'Cache-Control': 'public, max-age=31536000',
              },
        });
        const ossUrl = normalizeOssUrl(put.url || `${canonicalPrefix}${target.slug}${ext}`);

        await prisma.dJ.update({
          where: { id: target.id },
          data: {
            avatarUrl: ossUrl,
            avatarSourceUrl: imageUrl,
            spotifyId: cleanString(target.spotifyId) || artist.id,
            followerCount: artist.followers?.total ?? target.followerCount,
            lastSyncedAt: new Date(),
          },
        });

        stats.updated += 1;
        stats.processed += 1;
        completedSet.add(target.id);
        await checkpoint();
      } catch (error) {
        stats.failed += 1;
        stats.processed += 1;
        const message = error instanceof Error ? error.message : String(error);
        failedRows.push({ id: target.id, slug: target.slug, error: message });
        console.error(`[spotify-avatar-worker-${workerId}] 失败 ${target.slug}: ${message}`);
        await checkpoint();
      }
    }
  }

  await Promise.all(Array.from({ length: concurrency }, (_, i) => worker(i + 1)));

  if (!ignoreProgress) {
    await saveProgress(PROGRESS_FILE, {
      completedIds: Array.from(completedSet),
      failed: failedRows,
    });
  }

  const finishedAt = new Date();
  const report = {
    startedAt: startedAt.toISOString(),
    finishedAt: finishedAt.toISOString(),
    durationSeconds: Math.round((finishedAt.getTime() - startedAt.getTime()) / 1000),
    placeholderUrl,
    canonicalPrefix,
    stats,
    files: {
      progress: PROGRESS_FILE,
      report: REPORT_FILE,
    },
  };
  await fs.writeFile(REPORT_FILE, JSON.stringify(report, null, 2), 'utf-8');

  console.log('占位头像修复完成');
  console.log(JSON.stringify(report, null, 2));
}

main()
  .catch((error) => {
    console.error('占位头像修复失败:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
