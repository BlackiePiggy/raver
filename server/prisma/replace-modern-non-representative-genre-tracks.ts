import dotenv from 'dotenv';
import { Prisma, PrismaClient } from '@prisma/client';
import fs from 'fs';
import path from 'path';

dotenv.config();

const prisma = new PrismaClient();

const APPLY = process.argv.includes('--apply');
const MODERN_ADDITION_COUNT = 3;
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

type CandidateTrack = SoundCueTrack & {
  publishYear: number | null;
  query: string;
  sourceArtist: string | null;
  sourceRelation: 'descendant' | 'sibling' | 'parent' | 'ancestor' | 'related';
};

const CACHE_DIR = path.join(process.cwd(), 'prisma', '.cache');
const CACHE_PATH = path.join(CACHE_DIR, 'netease-modern-non-representative-search-cache.json');
const REPORT_PATH = path.join(
  CACHE_DIR,
  `genre-modern-non-representative-tracks-${new Date().toISOString().replace(/[:.]/g, '-')}.json`,
);
const MARKDOWN_REPORT_PATH = REPORT_PATH.replace(/\.json$/, '.md');
const AMBIGUOUS_SOURCE_ARTISTS = new Set(['earth']);

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

function normalizeKey(value: string): string {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/\b(feat|ft|featuring|remaster|remastered|radio edit|original mix|extended mix)\b/g, ' ')
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function splitArtists(value: string): string[] {
  return value
    .split(/,|\+|、|，/i)
    .map((item) => item.trim())
    .filter(Boolean);
}

function readCache(): Record<string, CandidateTrack[]> {
  if (!fs.existsSync(CACHE_PATH)) return {};
  try {
    return JSON.parse(fs.readFileSync(CACHE_PATH, 'utf8'));
  } catch {
    return {};
  }
}

function writeCache(cache: Record<string, CandidateTrack[]>) {
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

function artistIsExcluded(artistValue: string, excludedArtistKeys: Set<string>): boolean {
  return splitArtists(artistValue).some((artist) => {
    const artistKey = normalizeKey(artist);
    if (!artistKey) return false;
    return excludedArtistKeys.has(artistKey);
  });
}

function trackKey(track: Pick<SoundCueTrack, 'artist' | 'title'>): string {
  return normalizeKey(`${track.artist} ${track.title}`);
}

function primaryArtistKey(artistValue: string): string {
  return normalizeKey(splitArtists(artistValue)[0] ?? artistValue);
}

function artistKeys(artistValue: string): string[] {
  return splitArtists(artistValue).map(normalizeKey).filter(Boolean);
}

function addRelatedArtist(
  artists: Array<{ name: string; relation: CandidateTrack['sourceRelation'] }>,
  name: string,
  relation: CandidateTrack['sourceRelation'],
) {
  const trimmed = name.trim();
  if (!trimmed) return;
  const key = normalizeKey(trimmed);
  if (!key || artists.some((artist) => normalizeKey(artist.name) === key)) return;
  artists.push({ name: trimmed, relation });
}

async function searchNeteaseSongs(
  query: string,
  cache: Record<string, CandidateTrack[]>,
  sourceArtist: string | null,
  sourceRelation: CandidateTrack['sourceRelation'],
): Promise<CandidateTrack[]> {
  const cacheKey = `${normalizeKey(sourceArtist ?? 'keyword')}:${sourceRelation}:${normalizeKey(query)}`;
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
    const tracks = (json.result?.songs ?? []).map((song) => ({
      title: song.name,
      artist: (song.artists ?? song.ar ?? []).map((item) => item.name).join(', '),
      spotifyUrl: null,
      appleMusicUrl: null,
      neteaseUrl: `https://music.163.com/#/song?id=${song.id}`,
      soundcloudUrl: null,
      beatportUrl: null,
      publishYear: publishYear(song.publishTime),
      query,
      sourceArtist,
      sourceRelation,
    }));
    cache[cacheKey] = tracks;
    await sleep(120);
    return tracks;
  } catch {
    cache[cacheKey] = [];
    return [];
  } finally {
    clearTimeout(timeout);
  }
}

function toSoundCueTrack(track: CandidateTrack): SoundCueTrack {
  return {
    title: track.title,
    artist: track.artist,
    spotifyUrl: null,
    appleMusicUrl: null,
    neteaseUrl: track.neteaseUrl,
    soundcloudUrl: null,
    beatportUrl: null,
  };
}

async function main() {
  const cache = readCache();
  const genres = await prisma.genre.findMany({
    orderBy: [{ path: 'asc' }],
    select: {
      id: true,
      name: true,
      path: true,
      parentId: true,
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
    fewerThanTarget: [] as Array<{ id: string; name: string; count: number }>,
    items: [] as Array<{ id: string; name: string; excludedArtists: string[]; relatedArtists: Array<{ name: string; relation: CandidateTrack['sourceRelation'] }>; added: CandidateTrack[]; finalCount: number }>,
  };

  for (const [index, genre] of genres.entries()) {
    if (index === 0 || (index + 1) % 25 === 0 || index + 1 === genres.length) {
      console.log('[genre-modern-non-representative-tracks] progress', {
        current: index + 1,
        total: genres.length,
        genre: genre.id,
      });
    }

    const existingTracks = normalizeTracks(genre.soundCueTracks);
    const baseTracks = existingTracks.slice(0, 3);
    const excludedArtists = [
      ...genre.keyArtists,
      ...baseTracks.flatMap((track) => splitArtists(track.artist)),
    ];
    const excludedArtistKeys = new Set(excludedArtists.map(normalizeKey).filter(Boolean));
    const seenTrackKeys = new Set(baseTracks.map(trackKey));
    const seenAddedArtistKeys = new Set<string>();
    const added: CandidateTrack[] = [];
    const relatedArtists: Array<{ name: string; relation: CandidateTrack['sourceRelation'] }> = [];

    const descendants = genres.filter((candidate) => candidate.id !== genre.id && candidate.path.startsWith(`${genre.path}/`));
    for (const descendant of descendants) {
      for (const artist of descendant.keyArtists) addRelatedArtist(relatedArtists, artist, 'descendant');
      if (relatedArtists.length >= 24) break;
    }

    const siblings = genres.filter((candidate) => candidate.id !== genre.id && candidate.parentId === genre.parentId);
    for (const sibling of siblings) {
      for (const artist of sibling.keyArtists) addRelatedArtist(relatedArtists, artist, 'sibling');
      if (relatedArtists.length >= 36) break;
    }

    const parent = genres.find((candidate) => candidate.id === genre.parentId);
    if (parent) {
      for (const artist of parent.keyArtists) addRelatedArtist(relatedArtists, artist, 'parent');
      const ancestor = genres.find((candidate) => candidate.id === parent.parentId);
      if (ancestor) {
        for (const artist of ancestor.keyArtists) addRelatedArtist(relatedArtists, artist, 'ancestor');
      }
    }

    for (const artist of relatedArtists) {
      if (added.length >= MODERN_ADDITION_COUNT) break;
      if (artistIsExcluded(artist.name, excludedArtistKeys)) continue;
      if (AMBIGUOUS_SOURCE_ARTISTS.has(normalizeKey(artist.name))) continue;
      const queries = [
        artist.name,
        `${artist.name} 2025`,
        `${artist.name} 2024`,
        `${artist.name} 2023`,
        `${artist.name} 2020`,
      ];
      const results = (await Promise.all(queries.map((query) => searchNeteaseSongs(query, cache, artist.name, artist.relation)))).flat();
      const modernResults = results
        .filter((track) => track.publishYear !== null && track.publishYear >= MODERN_YEAR)
        .filter((track) => !artistIsExcluded(track.artist, excludedArtistKeys))
        .filter((track) => artistIsExcluded(track.artist, new Set([normalizeKey(artist.name)])))
        .sort((lhs, rhs) => (rhs.publishYear ?? 0) - (lhs.publishYear ?? 0));
      for (const track of modernResults) {
        if (added.length >= MODERN_ADDITION_COUNT) break;
        const key = trackKey(track);
        if (!key || seenTrackKeys.has(key)) continue;
        const keys = artistKeys(track.artist);
        const artistKey = primaryArtistKey(track.artist);
        if (!artistKey || keys.some((item) => seenAddedArtistKeys.has(item))) continue;
        if (artistIsExcluded(track.artist, excludedArtistKeys)) continue;
        if (added.some((item) => trackKey(item) === key)) continue;
        seenTrackKeys.add(key);
        for (const item of keys) seenAddedArtistKeys.add(item);
        added.push(track);
      }
    }

    if (added.length < MODERN_ADDITION_COUNT) {
      report.fewerThanTarget.push({ id: genre.id, name: genre.name, count: added.length });
    }

    const nextTracks = [...baseTracks, ...added.map(toSoundCueTrack)].slice(0, 3 + MODERN_ADDITION_COUNT);
    const changed = JSON.stringify(existingTracks.slice(0, 3 + MODERN_ADDITION_COUNT)) !== JSON.stringify(nextTracks);
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
      excludedArtists,
      relatedArtists,
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
      '# Genre Modern Non-Representative Tracks Report',
      '',
      `- Apply: ${APPLY}`,
      `- Modern year threshold: ${MODERN_YEAR}`,
      `- Modern additions per genre: ${MODERN_ADDITION_COUNT}`,
      `- Total genres: ${report.totalGenres}`,
      `- Updated: ${report.updated}`,
      `- Unchanged: ${report.unchanged}`,
      `- Fewer than target additions: ${report.fewerThanTarget.length}`,
      '',
      '## Fewer Than Target',
      '',
      ...(report.fewerThanTarget.length
        ? report.fewerThanTarget.map((item) => `- ${item.name} (\`${item.id}\`): ${item.count}`)
        : ['- None']),
      '',
      '## Added Tracks',
      '',
      ...report.items.flatMap((item) => [
        `### ${item.name}`,
        '',
        `- ID: \`${item.id}\``,
        `- Excluded artists: ${item.excludedArtists.join(', ')}`,
        `- Related artist pool: ${item.relatedArtists.slice(0, 12).map((artist) => `${artist.name} (${artist.relation})`).join(', ')}`,
        ...item.added.map((track, trackIndex) => `- ${trackIndex + 1}. ${track.artist} - ${track.title}: ${track.neteaseUrl} (${track.publishYear}, ${track.sourceRelation}, source: ${track.sourceArtist}, query: ${track.query})`),
        '',
      ]),
    ].join('\n'),
  );

  console.log('[genre-modern-non-representative-tracks] done', {
    apply: APPLY,
    modernYear: MODERN_YEAR,
    totalGenres: report.totalGenres,
    updated: report.updated,
    unchanged: report.unchanged,
    fewerThanTarget: report.fewerThanTarget.length,
    report: REPORT_PATH,
    markdownReport: MARKDOWN_REPORT_PATH,
  });
}

main()
  .catch((error) => {
    console.error('[genre-modern-non-representative-tracks] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
