import dotenv from 'dotenv';
import { Prisma, PrismaClient } from '@prisma/client';
import fs from 'fs';
import path from 'path';

dotenv.config();

const prisma = new PrismaClient();

const MODERN_YEAR = (() => {
  const arg = process.argv.find((item) => item.startsWith('--modern-year='));
  const value = arg ? Number(arg.slice('--modern-year='.length)) : 2010;
  return Number.isFinite(value) ? Math.floor(value) : 2010;
})();
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

type AuditItem = {
  id: string;
  name: string;
  needsReplacement: boolean;
};

type MusicBrainzRecording = {
  id: string;
  score?: number;
  title: string;
  'first-release-date'?: string;
  'artist-credit'?: Array<{ name: string }>;
  tags?: Array<{ name: string; count?: number }>;
};

type MbCandidate = {
  title: string;
  artist: string;
  year: number;
  mbid: string;
  musicBrainzUrl: string;
  matchedTag: string;
  queryTag: string;
  evidenceLevel: 'alias' | 'parent' | 'ancestor';
  mbScore: number;
  tags: string[];
};

type ResolvedCandidate = MbCandidate & {
  neteaseUrl: string;
  neteaseTitle: string;
  neteaseArtist: string;
};

type NeteaseSong = {
  id: number;
  name: string;
  artists?: Array<{ name: string }>;
  ar?: Array<{ name: string }>;
};

type NeteaseResult = {
  title: string;
  artist: string;
  neteaseUrl: string;
};

const CACHE_DIR = path.join(process.cwd(), 'prisma', '.cache');
const MB_CACHE_PATH = path.join(CACHE_DIR, 'musicbrainz-tag-recording-search-cache.json');
const NETEASE_CACHE_PATH = path.join(CACHE_DIR, 'netease-musicbrainz-candidate-search-cache.json');
const REPORT_PATH = path.join(
  CACHE_DIR,
  `genre-track-replacement-proposals-fallback-${new Date().toISOString().replace(/[:.]/g, '-')}.json`,
);
const MARKDOWN_REPORT_PATH = REPORT_PATH.replace(/\.json$/, '.md');

const FALLBACK_TAGS: Record<string, string[]> = {
  'industrial ambient': ['dark ambient', 'industrial'],
  isolationism: ['dark ambient', 'ambient'],
  'lovecraftian ambient': ['dark ambient', 'ambient'],
  'microtonal drone': ['drone', 'ambient'],
  'new age ambient': ['new age', 'ambient'],
  'celtic ambient': ['new age', 'celtic'],
  'meditation ambient': ['new age', 'ambient'],
  'forest psybient': ['psybient', 'ambient'],
  psydub: ['psybient', 'dub'],
  'space ambient': ['ambient', 'space music'],
  'cloud rap': ['cloud rap', 'hip hop'],
  'party drum and bass': ['jump up', 'drum and bass'],
  'melodic brostep': ['brostep', 'melodic dubstep'],
  'color bass': ['dubstep', 'future bass'],
  'halftime dubstep': ['halftime', 'dubstep'],
  'melodic riddim': ['riddim', 'dubstep'],
  'uk dubstep': ['dubstep', 'uk garage'],
  'wonky dubstep': ['wonky', 'dubstep'],
  'chicago footwork': ['footwork', 'juke'],
  'rare phonk': ['phonk'],
  'chemical breaks': ['big beat', 'breakbeat'],
  'funky breaks': ['breakbeat', 'breaks'],
  'neo rave': ['rave', 'breakbeat'],
  'florida breaks': ['breaks', 'breakbeat'],
  'psychedelic breakbeat': ['breakbeat', 'psychedelic'],
  'detroit electro': ['electro', 'detroit techno'],
  'industrial electro': ['electro', 'industrial'],
  'space electro': ['electro'],
  nintendocore: ['chiptune', 'bitpop'],
  'textural club': ['deconstructed club', 'experimental club'],
  'ambient idm': ['idm', 'ambient'],
  'drill n bass': ['drill and bass', 'idm'],
  'ambient classical': ['modern classical', 'ambient'],
  japanoise: ['noise', 'harsh noise'],
  'generative music': ['ambient', 'experimental'],
  'post digital': ['glitch', 'experimental'],
  'nu funk': ['funk', 'funktronica'],
  nortec: ['nortec', 'latin electronic'],
  singeli: ['singeli', 'african electronic'],
  'dub house': ['deep house', 'dub techno'],
  'dubstep garage': ['future garage', 'uk garage'],
  'uk house': ['house', 'uk garage'],
  suomisaundi: ['psytrance', 'goa trance'],
  'psychedelic goa': ['goa trance', 'psytrance'],
  'twilight psytrance': ['psytrance'],
};

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

function normalizeKey(value: string): string {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/\b(feat|ft|featuring|remaster|remastered|radio edit|original mix|extended mix|mixed)\b/g, ' ')
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function splitArtists(value: string): string[] {
  return value.split(/,|\+|、|，/i).map((item) => item.trim()).filter(Boolean);
}

function normalizeTrack(value: unknown): SoundCueTrack | null {
  if (!value || typeof value !== 'object') return null;
  const raw = value as Record<string, unknown>;
  const title = typeof raw.title === 'string' ? raw.title.trim() : '';
  const artist = typeof raw.artist === 'string' ? raw.artist.trim() : '';
  if (!title || !artist) return null;
  return {
    title,
    artist,
    spotifyUrl: typeof raw.spotifyUrl === 'string' && raw.spotifyUrl.trim() ? raw.spotifyUrl.trim() : null,
    appleMusicUrl: typeof raw.appleMusicUrl === 'string' && raw.appleMusicUrl.trim() ? raw.appleMusicUrl.trim() : null,
    neteaseUrl: typeof raw.neteaseUrl === 'string' && raw.neteaseUrl.trim() ? raw.neteaseUrl.trim() : null,
    soundcloudUrl: typeof raw.soundcloudUrl === 'string' && raw.soundcloudUrl.trim() ? raw.soundcloudUrl.trim() : null,
    beatportUrl: typeof raw.beatportUrl === 'string' && raw.beatportUrl.trim() ? raw.beatportUrl.trim() : null,
  };
}

function normalizeTracks(value: Prisma.JsonValue | null): SoundCueTrack[] {
  if (!Array.isArray(value)) return [];
  return value.map(normalizeTrack).filter((track): track is SoundCueTrack => Boolean(track));
}

function readJson<T>(filePath: string, fallback: T): T {
  if (!fs.existsSync(filePath)) return fallback;
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8')) as T;
  } catch {
    return fallback;
  }
}

function writeJson(filePath: string, value: unknown) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(value, null, 2));
}

function latestAuditPath(): string {
  const files = fs.readdirSync(CACHE_DIR)
    .filter((file) => file.startsWith('genre-sound-cue-quality-audit-') && file.endsWith('.json'))
    .map((file) => path.join(CACHE_DIR, file))
    .sort((lhs, rhs) => fs.statSync(rhs).mtimeMs - fs.statSync(lhs).mtimeMs);
  if (!files[0]) throw new Error('No genre sound cue quality audit report found');
  return files[0];
}

function tagEntries(genre: { name: string; parentId: string | null }, byId: Map<string, { name: string; parentId: string | null }>) {
  const entries: Array<{ tag: string; evidenceLevel: MbCandidate['evidenceLevel'] }> = [];
  const add = (tag: string, evidenceLevel: MbCandidate['evidenceLevel']) => {
    const normalized = normalizeKey(tag);
    if (!normalized || normalized.length < 3 || entries.some((entry) => entry.tag === normalized)) return;
    entries.push({ tag: normalized, evidenceLevel });
  };
  for (const tag of FALLBACK_TAGS[normalizeKey(genre.name)] ?? []) add(tag, 'alias');
  let parentId = genre.parentId;
  let depth = 0;
  while (parentId) {
    const parent = byId.get(parentId);
    if (!parent) break;
    add(parent.name, depth === 0 ? 'parent' : 'ancestor');
    parentId = parent.parentId;
    depth += 1;
  }
  return entries.filter((entry) => !['electronic music', 'electronic'].includes(entry.tag)).slice(0, 8);
}

function releaseYear(recording: MusicBrainzRecording): number | null {
  const raw = recording['first-release-date'];
  if (!raw) return null;
  const year = Number(raw.slice(0, 4));
  return Number.isFinite(year) && year >= 1900 ? year : null;
}

function artistIsExcluded(artistValue: string, excludedArtistKeys: Set<string>): boolean {
  return splitArtists(artistValue).some((artist) => excludedArtistKeys.has(normalizeKey(artist)));
}

function titleMatches(actual: string, expected: string): boolean {
  const actualKey = normalizeKey(actual);
  const expectedKey = normalizeKey(expected);
  if (!actualKey || !expectedKey) return false;
  return actualKey === expectedKey || actualKey.includes(expectedKey) || expectedKey.includes(actualKey);
}

function artistMatches(actual: string, expected: string): boolean {
  const expectedKeys = splitArtists(expected).map(normalizeKey).filter(Boolean);
  const actualKeys = splitArtists(actual).map(normalizeKey).filter(Boolean);
  if (!expectedKeys.length || !actualKeys.length) return false;
  return expectedKeys.some((expectedKey) => actualKeys.includes(expectedKey));
}

async function searchMusicBrainzTag(
  entry: { tag: string; evidenceLevel: MbCandidate['evidenceLevel'] },
  cache: Record<string, MbCandidate[]>,
): Promise<MbCandidate[]> {
  const cacheKey = `${entry.tag}:${MODERN_YEAR}:${entry.evidenceLevel}`;
  if (Object.prototype.hasOwnProperty.call(cache, cacheKey)) return cache[cacheKey];

  const query = `tag:"${entry.tag}" AND date:[${MODERN_YEAR} TO *]`;
  const url = `https://musicbrainz.org/ws/2/recording/?query=${encodeURIComponent(query)}&fmt=json&limit=50`;
  let json: { recordings?: MusicBrainzRecording[] } | null = null;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15_000);
    try {
      const response = await fetch(url, {
        signal: controller.signal,
        headers: {
          'User-Agent': 'RaverAppGenreCuration/1.0 (https://github.com/raver-app)',
        },
      });
      if (response.ok) {
        json = await response.json() as { recordings?: MusicBrainzRecording[] };
        break;
      }
    } catch {
      // Retry transient failures.
    } finally {
      clearTimeout(timeout);
    }
    await sleep(1500 * attempt);
  }
  if (!json) {
    cache[cacheKey] = [];
    await sleep(1100);
    return [];
  }

  const candidates = (json.recordings ?? [])
    .map((recording) => {
      const year = releaseYear(recording);
      const artist = recording['artist-credit']?.map((item) => item.name).join(', ') ?? '';
      const tags = recording.tags?.map((tag) => tag.name) ?? [];
      const matchedTag = tags.find((tag) => normalizeKey(tag) === entry.tag) ?? '';
      if (!year || year < MODERN_YEAR || !recording.title || !artist || !matchedTag) return null;
      return {
        title: recording.title,
        artist,
        year,
        mbid: recording.id,
        musicBrainzUrl: `https://musicbrainz.org/recording/${recording.id}`,
        matchedTag,
        queryTag: entry.tag,
        evidenceLevel: entry.evidenceLevel,
        mbScore: recording.score ?? 0,
        tags,
      } satisfies MbCandidate;
    })
    .filter((candidate): candidate is MbCandidate => Boolean(candidate))
    .sort((lhs, rhs) => {
      const weight = (candidate: MbCandidate) => candidate.evidenceLevel === 'alias' ? 3 : candidate.evidenceLevel === 'parent' ? 2 : 1;
      return weight(rhs) - weight(lhs) || rhs.mbScore - lhs.mbScore || rhs.year - lhs.year;
    });

  cache[cacheKey] = candidates;
  await sleep(1100);
  return candidates;
}

async function searchNetease(candidate: MbCandidate, cache: Record<string, NeteaseResult[]>): Promise<ResolvedCandidate | null> {
  const queries = [`${candidate.artist} ${candidate.title}`, `${candidate.title} ${candidate.artist}`, candidate.title];
  const allResults: NeteaseResult[] = [];
  for (const query of queries) {
    const cacheKey = normalizeKey(query);
    let results = cache[cacheKey];
    if (!results) {
      const url = `https://music.163.com/api/cloudsearch/pc?csrf_token=&s=${encodeURIComponent(query)}&type=1&offset=0&limit=10`;
      const response = await fetch(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0',
          Referer: 'https://music.163.com/',
        },
      });
      if (!response.ok) {
        results = [];
      } else {
        const json = await response.json() as { result?: { songs?: NeteaseSong[] } };
        results = (json.result?.songs ?? []).map((song) => ({
          title: song.name,
          artist: (song.artists ?? song.ar ?? []).map((item) => item.name).join(', '),
          neteaseUrl: `https://music.163.com/#/song?id=${song.id}`,
        }));
      }
      cache[cacheKey] = results;
      await sleep(120);
    }
    allResults.push(...results);
  }

  const picked = allResults.find((result) => titleMatches(result.title, candidate.title) && artistMatches(result.artist, candidate.artist));
  if (!picked) return null;
  return { ...candidate, neteaseUrl: picked.neteaseUrl, neteaseTitle: picked.title, neteaseArtist: picked.artist };
}

function artistKeys(artistValue: string): string[] {
  return splitArtists(artistValue).map(normalizeKey).filter(Boolean);
}

async function main() {
  const auditPath = latestAuditPath();
  const audit = readJson<{ items: AuditItem[] }>(auditPath, { items: [] });
  const targetIds = audit.items.filter((item) => item.needsReplacement).map((item) => item.id);
  const limitedTargetIds = LIMIT ? targetIds.slice(0, LIMIT) : targetIds;

  const [allGenres, targetGenres, mbCache, neteaseCache] = await Promise.all([
    prisma.genre.findMany({ select: { id: true, name: true, parentId: true } }),
    prisma.genre.findMany({
      where: { id: { in: limitedTargetIds } },
      select: {
        id: true,
        name: true,
        path: true,
        parentId: true,
        keyArtists: true,
        soundCueTracks: true,
      },
      orderBy: [{ path: 'asc' }],
    }),
    Promise.resolve(readJson<Record<string, MbCandidate[]>>(MB_CACHE_PATH, {})),
    Promise.resolve(readJson<Record<string, NeteaseResult[]>>(NETEASE_CACHE_PATH, {})),
  ]);
  const byId = new Map(allGenres.map((genre) => [genre.id, genre]));

  const items = [];
  const globalSuggestedKeys = new Set<string>();

  for (const [index, genre] of targetGenres.entries()) {
    console.log('[genre-track-replacement-fallback] progress', {
      current: index + 1,
      total: targetGenres.length,
      genre: genre.id,
    });

    const currentTracks = normalizeTracks(genre.soundCueTracks);
    const preservedTracks = currentTracks.slice(0, 3);
    const excludedArtistKeys = new Set([
      ...genre.keyArtists,
      ...preservedTracks.flatMap((track) => splitArtists(track.artist)),
    ].map(normalizeKey).filter(Boolean));
    const currentTrackKeys = new Set(currentTracks.map((track) => normalizeKey(`${track.artist} ${track.title}`)));
    const selectedArtistKeys = new Set<string>();
    const selected: ResolvedCandidate[] = [];
    const entries = tagEntries(genre, byId);

    for (const entry of entries) {
      if (selected.length >= 3) break;
      const candidates = await searchMusicBrainzTag(entry, mbCache);
      for (const candidate of candidates) {
        if (selected.length >= 3) break;
        const key = normalizeKey(`${candidate.artist} ${candidate.title}`);
        if (!key || currentTrackKeys.has(key) || globalSuggestedKeys.has(key)) continue;
        if (artistIsExcluded(candidate.artist, excludedArtistKeys)) continue;
        const candidateArtistKeys = artistKeys(candidate.artist);
        if (!candidateArtistKeys.length || candidateArtistKeys.some((artistKey) => selectedArtistKeys.has(artistKey))) continue;
        const resolved = await searchNetease(candidate, neteaseCache);
        if (!resolved) continue;
        selected.push(resolved);
        globalSuggestedKeys.add(key);
        for (const artistKey of candidateArtistKeys) selectedArtistKeys.add(artistKey);
      }
    }

    items.push({
      id: genre.id,
      name: genre.name,
      path: genre.path,
      attemptedTags: entries,
      preservedTracks,
      currentModernTracks: currentTracks.slice(3),
      proposedModernTracks: selected,
      status: selected.length >= 3 ? 'ready_fallback' : 'needs_manual_curation',
      exclusionSummary: {
        keyArtists: genre.keyArtists,
        preservedArtists: preservedTracks.flatMap((track) => splitArtists(track.artist)),
      },
    });
  }

  writeJson(MB_CACHE_PATH, mbCache);
  writeJson(NETEASE_CACHE_PATH, neteaseCache);

  const report = {
    generatedAt: new Date().toISOString(),
    auditPath,
    modernYear: MODERN_YEAR,
    targetGenreCount: targetIds.length,
    processedGenreCount: targetGenres.length,
    readyCount: items.filter((item) => item.status === 'ready_fallback').length,
    needsManualCurationCount: items.filter((item) => item.status !== 'ready_fallback').length,
    items,
  };
  writeJson(REPORT_PATH, report);

  fs.writeFileSync(
    MARKDOWN_REPORT_PATH,
    [
      '# Remaining Genre Track Replacement Proposals With Fallback Evidence',
      '',
      `- Generated at: ${report.generatedAt}`,
      `- Source audit: ${auditPath}`,
      `- Modern year threshold: ${MODERN_YEAR}`,
      `- Target genres: ${report.targetGenreCount}`,
      `- Processed genres: ${report.processedGenreCount}`,
      `- Ready fallback: ${report.readyCount}`,
      `- Needs manual curation: ${report.needsManualCurationCount}`,
      '',
      '## Method',
      '',
      '- Preserve tracks #1-#3 from the JSON-standard representative set.',
      '- Replace tracks #4-#6 only.',
      '- Candidate evidence comes from MusicBrainz recordings using alias / parent / ancestor tags when exact tags were insufficient.',
      '- NetEase is used only to resolve a clickable song URL after the MusicBrainz candidate is selected.',
      '- Fallback evidence is weaker than exact tag evidence and should be reviewed.',
      '',
      '## Proposals',
      '',
      ...items.flatMap((item) => [
        `### ${item.name}`,
        '',
        `- ID: \`${item.id}\``,
        `- Status: ${item.status}`,
        `- Attempted fallback tags: ${item.attemptedTags.map((entry) => `${entry.tag} (${entry.evidenceLevel})`).join(', ') || 'none'}`,
        '',
        'Preserve:',
        ...item.preservedTracks.map((track, trackIndex) => `- #${trackIndex + 1}: ${track.artist} - ${track.title} ${track.neteaseUrl ?? ''}`),
        '',
        'Replace current modern tracks:',
        ...item.currentModernTracks.map((track, trackIndex) => `- old #${trackIndex + 4}: ${track.artist} - ${track.title} ${track.neteaseUrl ?? ''}`),
        '',
        'Proposed fallback replacements:',
        ...(item.proposedModernTracks.length
          ? item.proposedModernTracks.map((track, trackIndex) => `- new #${trackIndex + 4}: ${track.artist} - ${track.title} (${track.year}) ${track.neteaseUrl}; evidence: MusicBrainz tag "${track.matchedTag}" via ${track.evidenceLevel}, score ${track.mbScore}, ${track.musicBrainzUrl}`)
          : ['- None found automatically']),
        '',
      ]),
    ].join('\n'),
  );

  console.log('[genre-track-replacement-fallback] done', {
    auditPath,
    targetGenreCount: report.targetGenreCount,
    processedGenreCount: report.processedGenreCount,
    readyCount: report.readyCount,
    needsManualCurationCount: report.needsManualCurationCount,
    report: REPORT_PATH,
    markdownReport: MARKDOWN_REPORT_PATH,
  });
}

main()
  .catch((error) => {
    console.error('[genre-track-replacement-fallback] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
