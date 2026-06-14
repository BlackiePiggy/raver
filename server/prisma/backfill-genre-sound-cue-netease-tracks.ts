import dotenv from 'dotenv';
import { Prisma, PrismaClient } from '@prisma/client';
import fs from 'fs';
import path from 'path';

dotenv.config();

const prisma = new PrismaClient();

const APPLY = process.argv.includes('--apply');
const FORCE = process.argv.includes('--force');
const LIMIT = (() => {
  const arg = process.argv.find((item) => item.startsWith('--limit='));
  if (!arg) return null;
  const value = Number(arg.slice('--limit='.length));
  return Number.isFinite(value) && value > 0 ? Math.floor(value) : null;
})();

type SoundCueTrack = {
  title: string;
  artist: string;
  spotifyUrl: string | null;
  appleMusicUrl: string | null;
  neteaseUrl: string | null;
  soundcloudUrl: string | null;
  beatportUrl: string | null;
};

type SearchSong = {
  id: number;
  name: string;
  artists: Array<{ name: string }>;
  album?: { name?: string };
  duration?: number;
};

type SearchResult = {
  title: string;
  artist: string;
  neteaseUrl: string;
};

const CACHE_DIR = path.join(process.cwd(), 'prisma', '.cache');
const CACHE_PATH = path.join(CACHE_DIR, 'netease-song-search-cache.json');
const REPORT_PATH = path.join(
  CACHE_DIR,
  `genre-sound-cue-netease-backfill-${new Date().toISOString().replace(/[:.]/g, '-')}.json`,
);

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

function readCache(): Record<string, SearchResult[]> {
  if (!fs.existsSync(CACHE_PATH)) return {};
  try {
    return JSON.parse(fs.readFileSync(CACHE_PATH, 'utf8'));
  } catch {
    return {};
  }
}

function writeCache(cache: Record<string, SearchResult[]>) {
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  fs.writeFileSync(CACHE_PATH, JSON.stringify(cache, null, 2));
}

function normalizeTrack(value: unknown): SoundCueTrack | null {
  if (!value || typeof value !== 'object') return null;
  const raw = value as Record<string, unknown>;
  const title = typeof raw.title === 'string' ? raw.title.trim() : '';
  const artist = typeof raw.artist === 'string' ? raw.artist.trim() : '';
  const neteaseUrl = typeof raw.neteaseUrl === 'string' && raw.neteaseUrl.trim()
    ? raw.neteaseUrl.trim()
    : null;
  if (!title && !artist) return null;
  return {
    title,
    artist,
    spotifyUrl: typeof raw.spotifyUrl === 'string' && raw.spotifyUrl.trim() ? raw.spotifyUrl.trim() : null,
    appleMusicUrl: typeof raw.appleMusicUrl === 'string' && raw.appleMusicUrl.trim() ? raw.appleMusicUrl.trim() : null,
    neteaseUrl,
    soundcloudUrl: typeof raw.soundcloudUrl === 'string' && raw.soundcloudUrl.trim() ? raw.soundcloudUrl.trim() : null,
    beatportUrl: typeof raw.beatportUrl === 'string' && raw.beatportUrl.trim() ? raw.beatportUrl.trim() : null,
  };
}

function normalizeTracks(value: Prisma.JsonValue | null): SoundCueTrack[] {
  if (!Array.isArray(value)) return [];
  const tracks: SoundCueTrack[] = [];
  const seen = new Set<string>();
  for (const item of value) {
    const track = normalizeTrack(item);
    if (!track) continue;
    const key = normalizeKey(`${track.title} ${track.artist}`);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    tracks.push(track);
  }
  return tracks;
}

function normalizeKey(value: string): string {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function extractExampleQuery(example: string | null): string | null {
  if (!example) return null;
  return example
    .replace(/^参考曲目[:：]\s*/i, '')
    .replace(/^reference track[:：]\s*/i, '')
    .trim() || null;
}

function buildQueries(genre: {
  name: string;
  example: string | null;
  exampleI18n: Prisma.JsonValue | null;
  keyArtists: string[];
  parentName: string | null;
  descendantExamples: string[];
}): string[] {
  const queries: string[] = [];
  const add = (value: string | null | undefined) => {
    const query = value?.trim();
    if (!query) return;
    const key = normalizeKey(query);
    if (!key || queries.some((item) => normalizeKey(item) === key)) return;
    queries.push(query);
  };

  add(extractExampleQuery(genre.example));
  if (genre.exampleI18n && typeof genre.exampleI18n === 'object' && !Array.isArray(genre.exampleI18n)) {
    for (const value of Object.values(genre.exampleI18n as Record<string, unknown>)) {
      if (typeof value === 'string') add(extractExampleQuery(value));
    }
  }

  for (const artist of genre.keyArtists.slice(0, 4)) {
    add(`${artist} ${genre.name}`);
    add(artist);
  }

  for (const example of genre.descendantExamples.slice(0, 8)) {
    add(extractExampleQuery(example));
  }

  add(`${genre.name} electronic`);
  add(`${genre.name} music`);
  add(`${genre.name} ${genre.parentName ?? ''}`.trim());
  add(genre.name);

  return queries;
}

function scoreSong(song: SearchSong, query: string, genreName: string): number {
  const title = normalizeKey(song.name);
  const artist = normalizeKey(song.artists?.map((item) => item.name).join(' ') ?? '');
  const album = normalizeKey(song.album?.name ?? '');
  const haystack = `${title} ${artist} ${album}`;
  const queryKey = normalizeKey(query);
  const genreKey = normalizeKey(genreName);

  let score = 0;
  if (queryKey && haystack.includes(queryKey)) score += 8;
  for (const token of queryKey.split(' ').filter((item) => item.length > 2)) {
    if (haystack.includes(token)) score += 1;
  }
  for (const token of genreKey.split(' ').filter((item) => item.length > 2)) {
    if (haystack.includes(token)) score += 2;
  }
  if (song.duration && song.duration >= 90_000 && song.duration <= 720_000) score += 1;
  return score;
}

async function searchNeteaseSongs(query: string, genreName: string, cache: Record<string, SearchResult[]>): Promise<SearchResult[]> {
  const cacheKey = normalizeKey(query);
  if (cache[cacheKey]?.length) return cache[cacheKey];

  const url = `https://music.163.com/api/search/get/web?csrf_token=&s=${encodeURIComponent(query)}&type=1&offset=0&limit=10`;
  const response = await fetch(url, {
    headers: {
      'User-Agent': 'Mozilla/5.0',
      Referer: 'https://music.163.com/',
    },
  });

  if (!response.ok) {
    cache[cacheKey] = [];
    return [];
  }

  const json = await response.json() as { result?: { songs?: SearchSong[] } };
  const songs = (json.result?.songs ?? [])
    .map((song) => ({ song, score: scoreSong(song, query, genreName) }))
    .sort((lhs, rhs) => rhs.score - lhs.score)
    .slice(0, 5)
    .map(({ song }) => ({
      title: song.name,
      artist: song.artists?.map((item) => item.name).join(', ') ?? '',
      neteaseUrl: `https://music.163.com/#/song?id=${song.id}`,
    }));

  cache[cacheKey] = songs;
  await sleep(120);
  return songs;
}

function toSoundCueTrack(result: SearchResult): SoundCueTrack {
  return {
    title: result.title,
    artist: result.artist,
    spotifyUrl: null,
    appleMusicUrl: null,
    neteaseUrl: result.neteaseUrl,
    soundcloudUrl: null,
    beatportUrl: null,
  };
}

async function main() {
  const cache = readCache();
  const genres = await prisma.genre.findMany({
    orderBy: [{ path: 'asc' }],
    ...(LIMIT ? { take: LIMIT } : {}),
    select: {
      id: true,
      name: true,
      path: true,
      parentId: true,
      example: true,
      exampleI18n: true,
      keyArtists: true,
      soundCueTracks: true,
    },
  });
  const parentRows = await prisma.genre.findMany({
    where: {
      id: {
        in: Array.from(new Set(genres.map((genre) => genre.parentId).filter((id): id is string => Boolean(id)))),
      },
    },
    select: { id: true, name: true },
  });
  const parentNameById = new Map(parentRows.map((row) => [row.id, row.name]));
  const examplesByAncestorId = new Map<string, string[]>();
  for (const ancestor of genres) {
    const ancestorPathPrefix = `${ancestor.path}/`;
    const examples = genres
      .filter((candidate) => candidate.id !== ancestor.id && candidate.path.startsWith(ancestorPathPrefix))
      .map((candidate) => candidate.example)
      .filter((example): example is string => Boolean(example))
      .slice(0, 12);
    examplesByAncestorId.set(ancestor.id, examples);
  }

  const report = {
    apply: APPLY,
    force: FORCE,
    totalGenres: genres.length,
    updated: 0,
    unchanged: 0,
    failed: [] as Array<{ id: string; name: string; reason: string; queries: string[] }>,
    items: [] as Array<{
      id: string;
      name: string;
      beforeCount: number;
      afterCount: number;
      queries: string[];
      tracks: SoundCueTrack[];
    }>,
  };

  for (const genre of genres) {
    const beforeTracks = normalizeTracks(genre.soundCueTracks);
    const tracks = FORCE ? [] : [...beforeTracks];
    const seen = new Set(tracks.map((track) => normalizeKey(`${track.title} ${track.artist}`)));
    const queries = buildQueries({
      name: genre.name,
      example: genre.example,
      exampleI18n: genre.exampleI18n,
      keyArtists: genre.keyArtists,
      parentName: genre.parentId ? (parentNameById.get(genre.parentId) ?? null) : null,
      descendantExamples: examplesByAncestorId.get(genre.id) ?? [],
    });

    for (let index = 0; index < tracks.length; index += 1) {
      const track = tracks[index];
      if (track.neteaseUrl) continue;
      const query = `${track.artist} ${track.title}`.trim() || track.title;
      const results = await searchNeteaseSongs(query, genre.name, cache);
      if (results[0]) {
        tracks[index] = {
          ...track,
          title: track.title || results[0].title,
          artist: track.artist || results[0].artist,
          neteaseUrl: results[0].neteaseUrl,
        };
      }
    }

    for (const query of queries) {
      if (tracks.length >= 3) break;
      const results = await searchNeteaseSongs(query, genre.name, cache);
      for (const result of results) {
        const key = normalizeKey(`${result.title} ${result.artist}`);
        if (!key || seen.has(key)) continue;
        seen.add(key);
        tracks.push(toSoundCueTrack(result));
        if (tracks.length >= 3) break;
      }
    }

    const nextTracks = tracks.slice(0, Math.max(3, beforeTracks.length));
    const changed = JSON.stringify(beforeTracks) !== JSON.stringify(nextTracks);

    if (nextTracks.length < 3) {
      report.failed.push({
        id: genre.id,
        name: genre.name,
        reason: `Only found ${nextTracks.length} tracks`,
        queries,
      });
    }

    if (changed && nextTracks.length >= 3) {
      report.updated += 1;
      if (APPLY) {
        await prisma.genre.update({
          where: { id: genre.id },
          data: {
            soundCueTracks: nextTracks as unknown as Prisma.InputJsonValue,
          },
        });
      }
    } else {
      report.unchanged += 1;
    }

    report.items.push({
      id: genre.id,
      name: genre.name,
      beforeCount: beforeTracks.length,
      afterCount: nextTracks.length,
      queries,
      tracks: nextTracks,
    });
  }

  writeCache(cache);
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  fs.writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2));

  console.log('[genre-sound-cue-netease-backfill] done', {
    apply: APPLY,
    force: FORCE,
    totalGenres: report.totalGenres,
    updated: report.updated,
    unchanged: report.unchanged,
    failed: report.failed.length,
    report: REPORT_PATH,
  });
}

main()
  .catch((error) => {
    console.error('[genre-sound-cue-netease-backfill] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
