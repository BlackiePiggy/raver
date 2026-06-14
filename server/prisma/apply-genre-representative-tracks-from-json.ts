import dotenv from 'dotenv';
import { Prisma, PrismaClient } from '@prisma/client';
import fs from 'fs';
import path from 'path';

dotenv.config();

const prisma = new PrismaClient();

const APPLY = process.argv.includes('--apply');
const INPUT_PATH = (() => {
  const arg = process.argv.find((item) => item.startsWith('--input='));
  return arg?.slice('--input='.length) || '/Users/blackie/Downloads/electronic_music_genre_representative_tracks_web_sources.json';
})();

type RepresentativeTrack = {
  rank?: number;
  title: string;
  artist: string;
  source?: unknown;
};

type InputGenre = {
  id: string;
  name: string;
  representativeTracks: RepresentativeTrack[];
};

type InputPayload = {
  meta?: Record<string, unknown>;
  genres: InputGenre[];
};

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
  ar?: Array<{ name: string }>;
  album?: { name?: string };
  duration?: number;
};

type SearchResult = {
  title: string;
  artist: string;
  neteaseUrl: string;
};

type ResolvedTrack = SoundCueTrack & {
  expectedTitle: string;
  expectedArtist: string;
  matchQuality: 'strict' | 'title_only' | 'loose' | 'unresolved';
};

const CACHE_DIR = path.join(process.cwd(), 'prisma', '.cache');
const CACHE_PATH = path.join(CACHE_DIR, 'netease-song-search-json-source-cache.json');
const REPORT_PATH = path.join(
  CACHE_DIR,
  `genre-representative-tracks-json-apply-${new Date().toISOString().replace(/[:.]/g, '-')}.json`,
);
const MARKDOWN_REPORT_PATH = REPORT_PATH.replace(/\.json$/, '.md');
const MANUAL_NETEASE_MATCHES: Record<string, SearchResult> = {
  [normalizeKey('The Maxx Cocaine')]: {
    title: 'Cocaine',
    artist: 'The Maxx',
    neteaseUrl: 'https://music.163.com/#/song?id=550905833',
  },
};

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

function normalizeKey(value: string): string {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/\b(feat|ft|featuring)\b/g, ' ')
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function readJson(): InputPayload {
  const payload = JSON.parse(fs.readFileSync(INPUT_PATH, 'utf8')) as InputPayload;
  if (!payload || !Array.isArray(payload.genres)) {
    throw new Error(`Invalid input JSON: ${INPUT_PATH}`);
  }
  return payload;
}

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

function titleMatches(actual: string, expected: string): boolean {
  const actualKey = normalizeKey(actual);
  const expectedKey = normalizeKey(expected);
  if (!actualKey || !expectedKey) return false;
  return actualKey === expectedKey || actualKey.includes(expectedKey) || expectedKey.includes(actualKey);
}

function artistMatches(actual: string, expected: string): boolean {
  const expectedKey = normalizeKey(expected);
  if (!expectedKey) return false;
  const actualArtists = actual.split(',').map((item) => normalizeKey(item));
  return actualArtists.some((artist) => (
    artist === expectedKey || artist.includes(expectedKey) || expectedKey.includes(artist)
  ));
}

async function searchNeteaseSongs(query: string, cache: Record<string, SearchResult[]>): Promise<SearchResult[]> {
  const cacheKey = normalizeKey(query);
  if (Object.prototype.hasOwnProperty.call(cache, cacheKey)) return cache[cacheKey];

  const urls = [
    `https://music.163.com/api/cloudsearch/pc?csrf_token=&s=${encodeURIComponent(query)}&type=1&offset=0&limit=10`,
    `https://music.163.com/api/search/get/web?csrf_token=&s=${encodeURIComponent(query)}&type=1&offset=0&limit=10`,
  ];
  const headers = {
    'User-Agent': 'Mozilla/5.0',
    Referer: 'https://music.163.com/',
  };
  const allResults: SearchResult[] = [];

  for (const url of urls) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10_000);
  let response: Response;
  try {
    response = await fetch(url, {
      signal: controller.signal,
      headers,
    });
  } catch {
    clearTimeout(timeout);
    continue;
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    continue;
  }

  const json = await response.json() as { result?: { songs?: SearchSong[] } };
  const results = (json.result?.songs ?? []).map((song) => ({
    title: song.name,
    artist: (song.artists ?? song.ar ?? []).map((item) => item.name).join(', '),
    neteaseUrl: `https://music.163.com/#/song?id=${song.id}`,
  }));
    allResults.push(...results);
    if (allResults.length) break;
  }

  const deduped: SearchResult[] = [];
  const seen = new Set<string>();
  for (const result of allResults) {
    const key = `${result.neteaseUrl}:${normalizeKey(`${result.artist} ${result.title}`)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(result);
  }

  cache[cacheKey] = deduped;
  await sleep(120);
  return deduped;
}

async function resolveTrack(track: RepresentativeTrack, cache: Record<string, SearchResult[]>): Promise<ResolvedTrack> {
  const expectedTitle = track.title.trim();
  const expectedArtist = track.artist.trim();
  const manual = MANUAL_NETEASE_MATCHES[normalizeKey(`${expectedArtist} ${expectedTitle}`)];
  if (manual) {
    return {
      title: manual.title,
      artist: manual.artist,
      spotifyUrl: null,
      appleMusicUrl: null,
      neteaseUrl: manual.neteaseUrl,
      soundcloudUrl: null,
      beatportUrl: null,
      expectedTitle,
      expectedArtist,
      matchQuality: 'strict',
    };
  }

  const queries = Array.from(new Set([
    `${expectedArtist} ${expectedTitle}`.trim(),
    `${expectedTitle} ${expectedArtist}`.trim(),
    expectedTitle,
  ].filter(Boolean)));

  const allResults: SearchResult[] = [];
  for (const query of queries) {
    const results = await searchNeteaseSongs(query, cache);
    allResults.push(...results);
  }

  const strict = allResults.find((result) => titleMatches(result.title, expectedTitle) && artistMatches(result.artist, expectedArtist));
  const titleOnly = allResults.find((result) => titleMatches(result.title, expectedTitle));
  const loose = allResults[0];
  const picked = strict ?? titleOnly ?? loose;
  const matchQuality = strict ? 'strict' : titleOnly ? 'title_only' : loose ? 'loose' : 'unresolved';

  return {
    title: picked?.title ?? expectedTitle,
    artist: picked?.artist || expectedArtist,
    spotifyUrl: null,
    appleMusicUrl: null,
    neteaseUrl: picked?.neteaseUrl ?? null,
    soundcloudUrl: null,
    beatportUrl: null,
    expectedTitle,
    expectedArtist,
    matchQuality,
  };
}

function toDbTrack(track: ResolvedTrack): SoundCueTrack {
  return {
    title: track.expectedTitle,
    artist: track.expectedArtist,
    spotifyUrl: null,
    appleMusicUrl: null,
    neteaseUrl: track.neteaseUrl,
    soundcloudUrl: null,
    beatportUrl: null,
  };
}

function markdownReport(report: {
  apply: boolean;
  inputPath: string;
  totalInputGenres: number;
  updated: number;
  unchanged: number;
  missingInDatabase: string[];
  unresolved: Array<{ genreId: string; genreName: string; title: string; artist: string }>;
  looseMatches: Array<{ genreId: string; genreName: string; expected: string; actual: string; url: string | null; quality: string }>;
  items: Array<{ id: string; name: string; tracks: ResolvedTrack[] }>;
}) {
  return [
    '# Genre Representative Tracks JSON Apply Report',
    '',
    `- Apply: ${report.apply}`,
    `- Input: ${report.inputPath}`,
    `- Input genres: ${report.totalInputGenres}`,
    `- Updated: ${report.updated}`,
    `- Unchanged: ${report.unchanged}`,
    `- Missing in database: ${report.missingInDatabase.length}`,
    `- Unresolved tracks: ${report.unresolved.length}`,
    `- Loose/title-only matches: ${report.looseMatches.length}`,
    '',
    '## Unresolved Tracks',
    '',
    ...(report.unresolved.length
      ? report.unresolved.map((item) => `- ${item.genreName} (\`${item.genreId}\`): ${item.artist} - ${item.title}`)
      : ['- None']),
    '',
    '## Loose Or Title-Only Matches',
    '',
    ...(report.looseMatches.length
      ? report.looseMatches.map((item) => `- ${item.genreName} (\`${item.genreId}\`): ${item.expected} -> ${item.actual} [${item.quality}] ${item.url ?? ''}`)
      : ['- None']),
    '',
    '## Applied Tracks',
    '',
    ...report.items.flatMap((item) => [
      `### ${item.name}`,
      '',
      `- ID: \`${item.id}\``,
      ...item.tracks.map((track, index) => `- ${index + 1}. ${track.artist} - ${track.title}: ${track.neteaseUrl ?? 'UNRESOLVED'} (${track.matchQuality})`),
      '',
    ]),
  ].join('\n');
}

async function main() {
  const input = readJson();
  const cache = readCache();
  const inputById = new Map(input.genres.map((genre) => [genre.id, genre]));
  const dbGenres = await prisma.genre.findMany({
    select: {
      id: true,
      name: true,
      soundCueTracks: true,
    },
  });
  const dbById = new Map(dbGenres.map((genre) => [genre.id, genre]));
  const missingInDatabase = input.genres
    .filter((genre) => !dbById.has(genre.id))
    .map((genre) => genre.id);
  const missingInInput = dbGenres
    .filter((genre) => !inputById.has(genre.id))
    .map((genre) => genre.id);

  const report = {
    apply: APPLY,
    inputPath: INPUT_PATH,
    totalInputGenres: input.genres.length,
    totalDbGenres: dbGenres.length,
    updated: 0,
    unchanged: 0,
    missingInDatabase,
    missingInInput,
    unresolved: [] as Array<{ genreId: string; genreName: string; title: string; artist: string }>,
    looseMatches: [] as Array<{ genreId: string; genreName: string; expected: string; actual: string; url: string | null; quality: string }>,
    items: [] as Array<{ id: string; name: string; tracks: ResolvedTrack[] }>,
  };

  for (const [index, inputGenre] of input.genres.entries()) {
    if (index === 0 || (index + 1) % 25 === 0 || index + 1 === input.genres.length) {
      console.log('[genre-representative-tracks-json-apply] progress', {
        current: index + 1,
        total: input.genres.length,
        genre: inputGenre.id,
      });
    }
    const dbGenre = dbById.get(inputGenre.id);
    if (!dbGenre) continue;
    const sourceTracks = [...inputGenre.representativeTracks]
      .sort((lhs, rhs) => (lhs.rank ?? 999) - (rhs.rank ?? 999))
      .slice(0, 3);
    if (sourceTracks.length !== 3) {
      throw new Error(`Genre ${inputGenre.id} must have exactly 3 representativeTracks`);
    }

    const resolvedTracks = [] as ResolvedTrack[];
    for (const track of sourceTracks) {
      const resolved = await resolveTrack(track, cache);
      resolvedTracks.push(resolved);
      if (!resolved.neteaseUrl) {
        report.unresolved.push({
          genreId: inputGenre.id,
          genreName: inputGenre.name,
          title: resolved.expectedTitle,
          artist: resolved.expectedArtist,
        });
      }
      if (resolved.matchQuality !== 'strict') {
        report.looseMatches.push({
          genreId: inputGenre.id,
          genreName: inputGenre.name,
          expected: `${resolved.expectedArtist} - ${resolved.expectedTitle}`,
          actual: `${resolved.artist} - ${resolved.title}`,
          url: resolved.neteaseUrl,
          quality: resolved.matchQuality,
        });
      }
    }

    const nextTracks = resolvedTracks.map(toDbTrack);
    const before = JSON.stringify(dbGenre.soundCueTracks ?? null);
    const after = JSON.stringify(nextTracks);
    if (before !== after) {
      report.updated += 1;
      if (APPLY) {
        await prisma.genre.update({
          where: { id: inputGenre.id },
          data: {
            soundCueTracks: nextTracks as unknown as Prisma.InputJsonValue,
          },
        });
      }
    } else {
      report.unchanged += 1;
    }

    report.items.push({
      id: inputGenre.id,
      name: inputGenre.name,
      tracks: resolvedTracks,
    });
  }

  writeCache(cache);
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  fs.writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2));
  fs.writeFileSync(MARKDOWN_REPORT_PATH, markdownReport(report));

  console.log('[genre-representative-tracks-json-apply] done', {
    apply: APPLY,
    inputPath: INPUT_PATH,
    inputGenres: report.totalInputGenres,
    dbGenres: report.totalDbGenres,
    updated: report.updated,
    unchanged: report.unchanged,
    missingInDatabase: report.missingInDatabase.length,
    missingInInput: report.missingInInput.length,
    unresolved: report.unresolved.length,
    looseMatches: report.looseMatches.length,
    report: REPORT_PATH,
    markdownReport: MARKDOWN_REPORT_PATH,
  });
}

main()
  .catch((error) => {
    console.error('[genre-representative-tracks-json-apply] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
