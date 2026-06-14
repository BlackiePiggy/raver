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

type Candidate = {
  title: string;
  artist: string;
  source: 'genre_example' | 'current_exact_track' | 'representative_artist_catalog' | 'descendant_example' | 'sibling_example';
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
  score: number;
};

const CACHE_DIR = path.join(process.cwd(), 'prisma', '.cache');
const CACHE_PATH = path.join(CACHE_DIR, 'netease-song-search-cache.json');
const REPORT_PATH = path.join(
  CACHE_DIR,
  `genre-representative-netease-curation-${new Date().toISOString().replace(/[:.]/g, '-')}.json`,
);
const MARKDOWN_REPORT_PATH = REPORT_PATH.replace(/\.json$/, '.md');

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

function parseRepresentativeWork(value: string | null | undefined): Pick<Candidate, 'artist' | 'title'> | null {
  const raw = value
    ?.replace(/^参考曲目[:：]\s*/i, '')
    .replace(/^reference track[:：]\s*/i, '')
    .trim();
  if (!raw) return null;

  const separator = raw.includes(' - ') ? ' - ' : raw.includes(' – ') ? ' – ' : raw.includes(' — ') ? ' — ' : null;
  if (!separator) return { artist: '', title: raw };

  const [artist, ...titleParts] = raw.split(separator);
  const title = titleParts.join(separator).trim();
  if (!title) return { artist: '', title: raw };
  return {
    artist: artist.trim(),
    title,
  };
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

function addCandidate(candidates: Candidate[], candidate: Candidate | null) {
  if (!candidate?.title.trim()) return;
  const key = normalizeKey(`${candidate.artist} ${candidate.title}`);
  if (!key || candidates.some((item) => normalizeKey(`${item.artist} ${item.title}`) === key)) return;
  candidates.push({
    ...candidate,
    title: candidate.title.trim(),
    artist: candidate.artist.trim(),
  });
}

function scoreSong(song: SearchSong, query: string, candidate?: Candidate): number {
  const title = normalizeKey(song.name);
  const artist = normalizeKey(song.artists?.map((item) => item.name).join(' ') ?? '');
  const album = normalizeKey(song.album?.name ?? '');
  const haystack = `${title} ${artist} ${album}`;
  const queryKey = normalizeKey(query);
  const candidateTitle = normalizeKey(candidate?.title ?? '');
  const candidateArtist = normalizeKey(candidate?.artist ?? '');

  let score = 0;
  if (candidateTitle && title === candidateTitle) score += 30;
  if (candidateTitle && title.includes(candidateTitle)) score += 15;
  if (candidateArtist && artist.includes(candidateArtist)) score += 20;
  if (queryKey && haystack.includes(queryKey)) score += 8;
  for (const token of queryKey.split(' ').filter((item) => item.length > 2)) {
    if (haystack.includes(token)) score += 1;
  }
  if (song.duration && song.duration >= 60_000 && song.duration <= 900_000) score += 1;
  return score;
}

function artistMatches(resultArtist: string, expectedArtist: string): boolean {
  const expected = normalizeKey(expectedArtist);
  if (!expected) return true;
  return resultArtist
    .split(',')
    .map((item) => normalizeKey(item))
    .some((artist) => artist === expected);
}

function resultMatchesCandidate(result: SearchResult, candidate: Candidate): boolean {
  const candidateTitle = normalizeKey(candidate.title);
  const resultTitle = normalizeKey(result.title);
  const titleMatches = candidateTitle && (resultTitle === candidateTitle || resultTitle.includes(candidateTitle));
  if (!candidate.artist) return true;
  const sameArtist = artistMatches(result.artist, candidate.artist);
  if (titleMatches) return sameArtist;
  return sameArtist && ['genre_example', 'descendant_example', 'sibling_example'].includes(candidate.source);
}

async function searchNeteaseSongs(
  query: string,
  cache: Record<string, SearchResult[]>,
  candidate?: Candidate,
): Promise<SearchResult[]> {
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
    .map((song) => ({ song, score: scoreSong(song, query, candidate) }))
    .sort((lhs, rhs) => rhs.score - lhs.score)
    .slice(0, 5)
    .map(({ song, score }) => ({
      title: song.name,
      artist: song.artists?.map((item) => item.name).join(', ') ?? '',
      neteaseUrl: `https://music.163.com/#/song?id=${song.id}`,
      score,
    }));

  cache[cacheKey] = songs;
  await sleep(120);
  return songs;
}

async function resolveCandidate(candidate: Candidate, cache: Record<string, SearchResult[]>): Promise<SoundCueTrack | null> {
  const queries = [
    `${candidate.artist} ${candidate.title}`.trim(),
    candidate.title,
  ].filter(Boolean);

  for (const query of queries) {
    const results = await searchNeteaseSongs(query, cache, candidate);
    const best = results.find((result) => resultMatchesCandidate(result, candidate));
    if (!best) continue;
    return {
      title: best.title,
      artist: best.artist,
      spotifyUrl: null,
      appleMusicUrl: null,
      neteaseUrl: best.neteaseUrl,
      soundcloudUrl: null,
      beatportUrl: null,
    };
  }

  return null;
}

async function pickRepresentativeArtistTrack(
  artist: string,
  cache: Record<string, SearchResult[]>,
): Promise<Candidate | null> {
  const results = await searchNeteaseSongs(artist, cache);
  const matched = results.find((result) => artistMatches(result.artist, artist));
  if (!matched) return null;
  return {
    title: matched.title,
    artist: matched.artist,
    source: 'representative_artist_catalog',
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
      keyArtists: true,
      soundCueTracks: true,
    },
  });
  const allGenres = await prisma.genre.findMany({
    select: {
      id: true,
      name: true,
      path: true,
      parentId: true,
      example: true,
      keyArtists: true,
    },
  });

  const report = {
    apply: APPLY,
    force: FORCE,
    totalGenres: genres.length,
    updated: 0,
    unchanged: 0,
    failed: [] as Array<{ id: string; name: string; reason: string; candidates: Candidate[] }>,
    items: [] as Array<{
      id: string;
      name: string;
      candidates: Candidate[];
      tracks: SoundCueTrack[];
    }>,
  };

  for (const genre of genres) {
    const candidates: Candidate[] = [];
    const example = parseRepresentativeWork(genre.example);
    addCandidate(candidates, example ? { ...example, source: 'genre_example' } : null);

    for (const artist of genre.keyArtists) {
      const artistTrack = await pickRepresentativeArtistTrack(artist, cache);
      addCandidate(candidates, artistTrack);
    }

    const descendantExamples = allGenres
      .filter((candidate) => candidate.id !== genre.id && candidate.path.startsWith(`${genre.path}/`))
      .map((candidate) => parseRepresentativeWork(candidate.example))
      .filter((candidate): candidate is Pick<Candidate, 'artist' | 'title'> => Boolean(candidate));
    for (const candidate of descendantExamples) {
      addCandidate(candidates, { ...candidate, source: 'descendant_example' });
      if (candidates.length >= 8) break;
    }

    const siblingExamples = allGenres
      .filter((candidate) => candidate.id !== genre.id && candidate.parentId === genre.parentId)
      .map((candidate) => parseRepresentativeWork(candidate.example))
      .filter((candidate): candidate is Pick<Candidate, 'artist' | 'title'> => Boolean(candidate));
    for (const candidate of siblingExamples) {
      addCandidate(candidates, { ...candidate, source: 'sibling_example' });
      if (candidates.length >= 12) break;
    }

    if (!FORCE) {
      for (const track of normalizeTracks(genre.soundCueTracks)) {
        addCandidate(candidates, {
          title: track.title,
          artist: track.artist,
          source: 'current_exact_track',
        });
        if (candidates.length >= 18) break;
      }
    }

    const tracks: SoundCueTrack[] = [];
    const seen = new Set<string>();
    for (const candidate of candidates) {
      if (tracks.length >= 3) break;
      const track = await resolveCandidate(candidate, cache);
      if (!track?.neteaseUrl) continue;
      const key = normalizeKey(`${track.artist} ${track.title}`);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      tracks.push(track);
    }

    if (tracks.length < 3) {
      report.failed.push({
        id: genre.id,
        name: genre.name,
        reason: `Only resolved ${tracks.length} tracks`,
        candidates,
      });
    }

    const beforeTracks = normalizeTracks(genre.soundCueTracks);
    const changed = JSON.stringify(beforeTracks.slice(0, 3)) !== JSON.stringify(tracks);
    if (tracks.length >= 3 && changed) {
      report.updated += 1;
      if (APPLY) {
        await prisma.genre.update({
          where: { id: genre.id },
          data: {
            soundCueTracks: tracks as unknown as Prisma.InputJsonValue,
          },
        });
      }
    } else {
      report.unchanged += 1;
    }

    report.items.push({
      id: genre.id,
      name: genre.name,
      candidates: candidates.slice(0, 6),
      tracks,
    });
  }

  writeCache(cache);
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  fs.writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2));
  fs.writeFileSync(
    MARKDOWN_REPORT_PATH,
    [
      '# Genre Representative NetEase Track Curation',
      '',
      `- Apply: ${APPLY}`,
      `- Total genres: ${report.totalGenres}`,
      `- Updated: ${report.updated}`,
      `- Unchanged: ${report.unchanged}`,
      `- Failed: ${report.failed.length}`,
      '',
      '## Items',
      '',
      ...report.items.flatMap((item) => [
        `### ${item.name}`,
        '',
        `- ID: \`${item.id}\``,
        `- Candidates: ${item.candidates.slice(0, 3).map((candidate) => `${candidate.artist ? `${candidate.artist} - ` : ''}${candidate.title} (${candidate.source})`).join('; ')}`,
        ...item.tracks.map((track, index) => `- ${index + 1}. ${track.artist} - ${track.title}: ${track.neteaseUrl}`),
        '',
      ]),
    ].join('\n'),
  );

  console.log('[genre-representative-netease-curation] done', {
    apply: APPLY,
    force: FORCE,
    totalGenres: report.totalGenres,
    updated: report.updated,
    unchanged: report.unchanged,
    failed: report.failed.length,
    report: REPORT_PATH,
    markdownReport: MARKDOWN_REPORT_PATH,
  });
}

main()
  .catch((error) => {
    console.error('[genre-representative-netease-curation] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
