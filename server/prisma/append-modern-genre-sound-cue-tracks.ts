import dotenv from 'dotenv';
import { Prisma, PrismaClient } from '@prisma/client';
import fs from 'fs';
import path from 'path';

dotenv.config();

const prisma = new PrismaClient();

const APPLY = process.argv.includes('--apply');
const MODERN_YEAR = (() => {
  const arg = process.argv.find((item) => item.startsWith('--modern-year='));
  const value = arg ? Number(arg.slice('--modern-year='.length)) : 2010;
  return Number.isFinite(value) ? Math.floor(value) : 2010;
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
  artists?: Array<{ name: string }>;
  ar?: Array<{ name: string }>;
  publishTime?: number;
};

type SearchResult = {
  title: string;
  artist: string;
  neteaseUrl: string;
  publishYear: number | null;
  query: string;
  matchSource: 'own_key_artist' | 'descendant_key_artist' | 'genre_keyword';
};

const CACHE_DIR = path.join(process.cwd(), 'prisma', '.cache');
const CACHE_PATH = path.join(CACHE_DIR, 'netease-modern-song-search-cache.json');
const REPORT_PATH = path.join(
  CACHE_DIR,
  `genre-modern-sound-cue-tracks-${new Date().toISOString().replace(/[:.]/g, '-')}.json`,
);
const MARKDOWN_REPORT_PATH = REPORT_PATH.replace(/\.json$/, '.md');
const MODERN_OVERRIDES: Record<string, SearchResult[]> = {
  'ambient/drone-ambient': [
    {
      title: 'Keyed out',
      artist: 'Tim Hecker',
      neteaseUrl: 'https://music.163.com/#/song?id=1312811285',
      publishYear: 2018,
      query: 'manual modern override',
      matchSource: 'own_key_artist',
    },
    {
      title: 'Cascade',
      artist: 'William Basinski',
      neteaseUrl: 'https://music.163.com/#/song?id=1305798520',
      publishYear: 2015,
      query: 'manual modern override',
      matchSource: 'own_key_artist',
    },
  ],
  'electro/industrial-electro': [
    {
      title: 'Cellular Automata',
      artist: 'Dopplereffekt',
      neteaseUrl: 'https://music.163.com/#/song?id=497755318',
      publishYear: 2017,
      query: 'manual modern override',
      matchSource: 'own_key_artist',
    },
    {
      title: 'Shockwave',
      artist: 'The Hacker',
      neteaseUrl: 'https://music.163.com/#/song?id=26159038',
      publishYear: 2012,
      query: 'manual modern override',
      matchSource: 'own_key_artist',
    },
  ],
  'experimental/8-bit-chiptune/nintendocore': [
    {
      title: 'Prom Night',
      artist: 'Anamanaguchi',
      neteaseUrl: 'https://music.163.com/#/song?id=26327791',
      publishYear: 2013,
      query: 'manual modern override',
      matchSource: 'own_key_artist',
    },
    {
      title: 'Miku',
      artist: 'Anamanaguchi, 初音ミク',
      neteaseUrl: 'https://music.163.com/#/song?id=2137300345',
      publishYear: 2017,
      query: 'manual modern override',
      matchSource: 'own_key_artist',
    },
  ],
  'industrial-and-post-industrial/ebm': [
    {
      title: 'Pain',
      artist: 'Boy Harsher',
      neteaseUrl: 'https://music.163.com/#/song?id=1300292987',
      publishYear: 2018,
      query: 'manual modern override',
      matchSource: 'own_key_artist',
    },
    {
      title: 'Consuming Guilt',
      artist: 'Youth Code',
      neteaseUrl: 'https://music.163.com/#/song?id=1379273182',
      publishYear: 2014,
      query: 'manual modern override',
      matchSource: 'own_key_artist',
    },
  ],
};

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

function normalizeKey(value: string): string {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/\b(feat|ft|featuring|remaster|remastered|radio edit|original mix)\b/g, ' ')
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
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

function normalizeTrack(value: unknown): SoundCueTrack | null {
  if (!value || typeof value !== 'object') return null;
  const raw = value as Record<string, unknown>;
  const title = typeof raw.title === 'string' ? raw.title.trim() : '';
  const artist = typeof raw.artist === 'string' ? raw.artist.trim() : '';
  const neteaseUrl = typeof raw.neteaseUrl === 'string' && raw.neteaseUrl.trim()
    ? raw.neteaseUrl.trim()
    : null;
  if (!title || !artist) return null;
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
    const key = normalizeKey(`${track.artist} ${track.title}`);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    tracks.push(track);
  }
  return tracks;
}

function publishYear(publishTime: number | undefined): number | null {
  if (!publishTime) return null;
  const year = new Date(publishTime).getUTCFullYear();
  return year > 1900 ? year : null;
}

function artistMatches(actual: string, expected: string): boolean {
  const expectedKey = normalizeKey(expected);
  if (!expectedKey) return false;
  return actual
    .split(',')
    .map((item) => normalizeKey(item))
    .some((artist) => artist === expectedKey || artist.includes(expectedKey) || expectedKey.includes(artist));
}

async function searchNeteaseSongs(
  query: string,
  cache: Record<string, SearchResult[]>,
  matchSource: SearchResult['matchSource'],
): Promise<SearchResult[]> {
  const cacheKey = `${matchSource}:${normalizeKey(query)}`;
  if (Object.prototype.hasOwnProperty.call(cache, cacheKey)) return cache[cacheKey];

  const url = `https://music.163.com/api/cloudsearch/pc?csrf_token=&s=${encodeURIComponent(query)}&type=1&offset=0&limit=30`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10_000);
  try {
    const response = await fetch(url, {
      signal: controller.signal,
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
    const results = (json.result?.songs ?? []).map((song) => ({
      title: song.name,
      artist: (song.artists ?? song.ar ?? []).map((item) => item.name).join(', '),
      neteaseUrl: `https://music.163.com/#/song?id=${song.id}`,
      publishYear: publishYear(song.publishTime),
      query,
      matchSource,
    }));
    cache[cacheKey] = results;
    await sleep(120);
    return results;
  } catch {
    cache[cacheKey] = [];
    return [];
  } finally {
    clearTimeout(timeout);
  }
}

function addUniqueArtist(artists: Array<{ name: string; source: SearchResult['matchSource'] }>, name: string, source: SearchResult['matchSource']) {
  const trimmed = name.trim();
  if (!trimmed) return;
  const key = normalizeKey(trimmed);
  if (!key || artists.some((artist) => normalizeKey(artist.name) === key)) return;
  artists.push({ name: trimmed, source });
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

function trackKey(track: Pick<SoundCueTrack, 'artist' | 'title'>): string {
  return normalizeKey(`${track.artist} ${track.title}`);
}

async function main() {
  const cache = readCache();
  const genres = await prisma.genre.findMany({
    orderBy: [{ path: 'asc' }],
    select: {
      id: true,
      name: true,
      path: true,
      keyArtists: true,
      soundCueTracks: true,
    },
  });

  const report = {
    apply: APPLY,
    modernYear: MODERN_YEAR,
    totalGenres: genres.length,
    updated: 0,
    unchanged: 0,
    fewerThanTwoModernAdditions: [] as Array<{ id: string; name: string; count: number }>,
    unknownYearAdditions: [] as Array<{ id: string; name: string; track: SearchResult }>,
    looseKeywordAdditions: [] as Array<{ id: string; name: string; track: SearchResult }>,
    items: [] as Array<{ id: string; name: string; added: SearchResult[]; finalCount: number }>,
  };

  for (const [index, genre] of genres.entries()) {
    if (index === 0 || (index + 1) % 25 === 0 || index + 1 === genres.length) {
      console.log('[genre-modern-sound-cue-tracks] progress', {
        current: index + 1,
        total: genres.length,
        genre: genre.id,
      });
    }

    const existingTracks = normalizeTracks(genre.soundCueTracks);
    const baseTracks = existingTracks.slice(0, 3);
    const seen = new Set(baseTracks.map(trackKey));
    const artists: Array<{ name: string; source: SearchResult['matchSource'] }> = [];
    for (const artist of genre.keyArtists) addUniqueArtist(artists, artist, 'own_key_artist');

    const descendantArtists = genres
      .filter((candidate) => candidate.id !== genre.id && candidate.path.startsWith(`${genre.path}/`))
      .flatMap((candidate) => candidate.keyArtists);
    for (const artist of descendantArtists) {
      if (artists.length >= 18) break;
      addUniqueArtist(artists, artist, 'descendant_key_artist');
    }

    const candidates: SearchResult[] = [];
    for (const artist of artists) {
      if (candidates.length >= 24) break;
      const artistResults = await searchNeteaseSongs(artist.name, cache, artist.source);
      for (const result of artistResults) {
        if (!artistMatches(result.artist, artist.name)) continue;
        const key = normalizeKey(`${result.artist} ${result.title}`);
        if (!key || seen.has(key) || candidates.some((item) => normalizeKey(`${item.artist} ${item.title}`) === key)) continue;
        candidates.push(result);
      }
    }

    for (const result of MODERN_OVERRIDES[genre.id] ?? []) {
      const key = normalizeKey(`${result.artist} ${result.title}`);
      if (!key || seen.has(key) || candidates.some((item) => normalizeKey(`${item.artist} ${item.title}`) === key)) continue;
      candidates.unshift(result);
    }

    const modernCandidates = candidates
      .filter((candidate) => candidate.publishYear !== null && candidate.publishYear >= MODERN_YEAR)
      .sort((lhs, rhs) => (rhs.publishYear ?? 0) - (lhs.publishYear ?? 0));
    const unknownYearCandidates = candidates
      .filter((candidate) => candidate.publishYear === null)
      .sort((lhs, rhs) => {
        const sourceWeight = (item: SearchResult) => item.matchSource === 'genre_keyword' ? 0 : 1;
        return sourceWeight(rhs) - sourceWeight(lhs);
      });

    const added: SearchResult[] = [];
    for (const pool of [modernCandidates, unknownYearCandidates]) {
      for (const candidate of pool) {
        if (added.length >= 2) break;
        const key = normalizeKey(`${candidate.artist} ${candidate.title}`);
        if (!key || seen.has(key) || added.some((item) => normalizeKey(`${item.artist} ${item.title}`) === key)) continue;
        seen.add(key);
        added.push(candidate);
      }
      if (added.length >= 2) break;
    }

    if (added.length < 2) {
      report.fewerThanTwoModernAdditions.push({ id: genre.id, name: genre.name, count: added.length });
    }

    for (const track of added) {
      if (track.publishYear === null) report.unknownYearAdditions.push({ id: genre.id, name: genre.name, track });
      if (track.matchSource === 'genre_keyword') report.looseKeywordAdditions.push({ id: genre.id, name: genre.name, track });
    }

    const nextTracks = [...baseTracks, ...added.map(toSoundCueTrack)].slice(0, 5);
    const changed = JSON.stringify(existingTracks.slice(0, 5)) !== JSON.stringify(nextTracks);
    if (changed) {
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
      added,
      finalCount: nextTracks.length,
    });
  }

  writeCache(cache);
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  fs.writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2));
  fs.writeFileSync(
    MARKDOWN_REPORT_PATH,
    [
      '# Genre Modern Sound Cue Tracks Report',
      '',
      `- Apply: ${APPLY}`,
      `- Modern year threshold: ${MODERN_YEAR}`,
      `- Total genres: ${report.totalGenres}`,
      `- Updated: ${report.updated}`,
      `- Unchanged: ${report.unchanged}`,
      `- Fewer than two additions: ${report.fewerThanTwoModernAdditions.length}`,
      `- Unknown-year additions: ${report.unknownYearAdditions.length}`,
      `- Loose keyword additions: ${report.looseKeywordAdditions.length}`,
      '',
      '## Fewer Than Two Additions',
      '',
      ...(report.fewerThanTwoModernAdditions.length
        ? report.fewerThanTwoModernAdditions.map((item) => `- ${item.name} (\`${item.id}\`): ${item.count}`)
        : ['- None']),
      '',
      '## Added Tracks',
      '',
      ...report.items.flatMap((item) => [
        `### ${item.name}`,
        '',
        `- ID: \`${item.id}\``,
        ...item.added.map((track, trackIndex) => `- ${trackIndex + 1}. ${track.artist} - ${track.title}: ${track.neteaseUrl} (${track.publishYear ?? 'year unknown'}, ${track.matchSource})`),
        '',
      ]),
    ].join('\n'),
  );

  console.log('[genre-modern-sound-cue-tracks] done', {
    apply: APPLY,
    modernYear: MODERN_YEAR,
    totalGenres: report.totalGenres,
    updated: report.updated,
    unchanged: report.unchanged,
    fewerThanTwoModernAdditions: report.fewerThanTwoModernAdditions.length,
    unknownYearAdditions: report.unknownYearAdditions.length,
    looseKeywordAdditions: report.looseKeywordAdditions.length,
    report: REPORT_PATH,
    markdownReport: MARKDOWN_REPORT_PATH,
  });
}

main()
  .catch((error) => {
    console.error('[genre-modern-sound-cue-tracks] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
