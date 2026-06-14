import dotenv from 'dotenv';
import { Prisma, PrismaClient } from '@prisma/client';
import fs from 'fs';
import path from 'path';

dotenv.config();

const prisma = new PrismaClient();

type SoundCueTrack = {
  title: string;
  artist: string;
  spotifyUrl: string | null;
  appleMusicUrl: string | null;
  neteaseUrl: string | null;
  soundcloudUrl: string | null;
  beatportUrl: string | null;
};

type GenreRow = {
  id: string;
  name: string;
  path: string;
  parentId: string | null;
  keyArtists: string[];
  soundCueTracks: Prisma.JsonValue | null;
};

type TrackIssue = {
  severity: 'high' | 'medium' | 'low';
  code: string;
  message: string;
  trackIndex: number;
  track: SoundCueTrack;
};

const CACHE_DIR = path.join(process.cwd(), 'prisma', '.cache');
const REPORT_PATH = path.join(
  CACHE_DIR,
  `genre-sound-cue-quality-audit-${new Date().toISOString().replace(/[:.]/g, '-')}.json`,
);
const MARKDOWN_REPORT_PATH = REPORT_PATH.replace(/\.json$/, '.md');

const SUSPICIOUS_TITLE_PATTERNS = [
  /\bvol\.?\s*\d+\b/i,
  /\bfree\s+my\s+mind\b/i,
  /\belectronic\s+music\b/i,
  /\btechno\s+20\d\d\b/i,
  /\btrance\s+20\d\d\b/i,
  /\bdeep\s+house\s+20\d\d\b/i,
  /\bdubstep\s+20\d\d\b/i,
  /\bambient\s+20\d\d\b/i,
];

const LEGIT_SHORT_ARTIST_KEYS = new Set([
  '2at',
  'a ki',
  'bk',
  'dyr',
  'edx',
  'lyn',
  'm83',
  'ram',
  'rei',
  'vyd',
  'ziq',
  '!!!',
]);

const SUSPICIOUS_ARTIST_PATTERNS = [
  /\bbeats?\b/i,
  /\bstudio\b/i,
  /\bmusic\b/i,
  /\bsounds?\b/i,
  /\bgroup\b/i,
  /\bplaylist\b/i,
  /\bchillout\b/i,
];

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
  return value
    .split(/,|\+|、|，/i)
    .map((item) => item.trim())
    .filter(Boolean);
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

function trackKey(track: Pick<SoundCueTrack, 'artist' | 'title'>): string {
  return normalizeKey(`${track.artist} ${track.title}`);
}

function artistKeys(track: Pick<SoundCueTrack, 'artist'>): string[] {
  return splitArtists(track.artist).map(normalizeKey).filter(Boolean);
}

function isSuspiciousKeywordTrack(track: SoundCueTrack, genreName: string): string[] {
  const reasons: string[] = [];
  const title = track.title;
  const artist = track.artist;
  const genreKey = normalizeKey(genreName);
  const titleKey = normalizeKey(title);

  if (SUSPICIOUS_TITLE_PATTERNS.some((pattern) => pattern.test(title))) {
    reasons.push('title looks like SEO/year/playlist placeholder');
  }
  if (SUSPICIOUS_ARTIST_PATTERNS.some((pattern) => pattern.test(artist)) && titleKey.includes(genreKey)) {
    reasons.push('generic artist plus genre-keyword title');
  }
  if (titleKey === genreKey || titleKey === `${genreKey} music`) {
    reasons.push('title is only the genre name');
  }
  if (artistKeys(track).some((artist) => artist.length <= 3 && !LEGIT_SHORT_ARTIST_KEYS.has(artist))) {
    reasons.push('artist name is too short/ambiguous for automated matching');
  }

  return reasons;
}

function issueLine(issue: TrackIssue): string {
  return `- [${issue.severity}] #${issue.trackIndex + 1} ${issue.track.artist} - ${issue.track.title}: ${issue.message}`;
}

async function main() {
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

  const byId = new Map(genres.map((genre) => [genre.id, genre]));
  const tracksByGenreId = new Map(genres.map((genre) => [genre.id, normalizeTracks(genre.soundCueTracks)]));
  const childrenByParentId = new Map<string, GenreRow[]>();
  for (const genre of genres) {
    if (!genre.parentId) continue;
    const children = childrenByParentId.get(genre.parentId) ?? [];
    children.push(genre);
    childrenByParentId.set(genre.parentId, children);
  }

  const items = genres.map((genre) => {
    const tracks = tracksByGenreId.get(genre.id) ?? [];
    const parent = genre.parentId ? byId.get(genre.parentId) : null;
    const parentTracks = parent ? (tracksByGenreId.get(parent.id) ?? []) : [];
    const childTracks = (childrenByParentId.get(genre.id) ?? []).flatMap((child) => tracksByGenreId.get(child.id) ?? []);
    const siblingTracks = genres
      .filter((candidate) => candidate.id !== genre.id && candidate.parentId === genre.parentId)
      .flatMap((candidate) => tracksByGenreId.get(candidate.id) ?? []);

    const issues: TrackIssue[] = [];

    tracks.forEach((track, index) => {
      if (!track.neteaseUrl) {
        issues.push({
          severity: 'high',
          code: 'missing_netease_url',
          message: 'missing NetEase URL',
          trackIndex: index,
          track,
        });
      }

      const suspiciousReasons = isSuspiciousKeywordTrack(track, genre.name);
      for (const reason of suspiciousReasons) {
        issues.push({
          severity: index >= 3 ? 'high' : 'medium',
          code: 'suspicious_keyword_track',
          message: reason,
          trackIndex: index,
          track,
        });
      }

      const key = trackKey(track);
      if (index >= 3 && parentTracks.some((parentTrack) => trackKey(parentTrack) === key)) {
        issues.push({
          severity: 'high',
          code: 'duplicates_parent_track',
          message: parent ? `duplicates parent genre "${parent.name}"` : 'duplicates parent genre',
          trackIndex: index,
          track,
        });
      }
      if (index >= 3 && childTracks.some((childTrack) => trackKey(childTrack) === key)) {
        issues.push({
          severity: 'medium',
          code: 'duplicates_child_track',
          message: 'also appears in a child genre',
          trackIndex: index,
          track,
        });
      }
      if (index >= 3 && siblingTracks.some((siblingTrack) => trackKey(siblingTrack) === key)) {
        issues.push({
          severity: 'medium',
          code: 'duplicates_sibling_track',
          message: 'also appears in a sibling genre',
          trackIndex: index,
          track,
        });
      }
    });

    const modernTracks = tracks.slice(3);
    const seenModernArtists = new Set<string>();
    modernTracks.forEach((track, offset) => {
      for (const artist of artistKeys(track)) {
        if (seenModernArtists.has(artist)) {
          issues.push({
            severity: 'high',
            code: 'duplicate_modern_artist',
            message: 'modern additions repeat an artist',
            trackIndex: offset + 3,
            track,
          });
        }
        seenModernArtists.add(artist);
      }
    });

    return {
      id: genre.id,
      name: genre.name,
      path: genre.path,
      parentId: genre.parentId,
      trackCount: tracks.length,
      tracks,
      issues,
      needsReplacement: issues.some((issue) => issue.severity === 'high'),
    };
  });

  const report = {
    generatedAt: new Date().toISOString(),
    totalGenres: genres.length,
    totalTracks: Array.from(tracksByGenreId.values()).reduce((sum, tracks) => sum + tracks.length, 0),
    genresWithIssues: items.filter((item) => item.issues.length > 0).length,
    genresNeedingReplacement: items.filter((item) => item.needsReplacement).length,
    highIssues: items.flatMap((item) => item.issues).filter((issue) => issue.severity === 'high').length,
    mediumIssues: items.flatMap((item) => item.issues).filter((issue) => issue.severity === 'medium').length,
    lowIssues: items.flatMap((item) => item.issues).filter((issue) => issue.severity === 'low').length,
    items,
  };

  fs.mkdirSync(CACHE_DIR, { recursive: true });
  fs.writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2));

  const sortedItems = [...items].sort((lhs, rhs) => {
    const high = (item: typeof lhs) => item.issues.filter((issue) => issue.severity === 'high').length;
    return high(rhs) - high(lhs) || rhs.issues.length - lhs.issues.length || lhs.path.localeCompare(rhs.path);
  });

  fs.writeFileSync(
    MARKDOWN_REPORT_PATH,
    [
      '# Genre Sound Cue Track Quality Audit',
      '',
      `- Generated at: ${report.generatedAt}`,
      `- Total genres: ${report.totalGenres}`,
      `- Total tracks: ${report.totalTracks}`,
      `- Genres with issues: ${report.genresWithIssues}`,
      `- Genres needing replacement: ${report.genresNeedingReplacement}`,
      `- High issues: ${report.highIssues}`,
      `- Medium issues: ${report.mediumIssues}`,
      '',
      '## How To Read',
      '',
      '- Tracks #1-#3 are the JSON-standard representative tracks and should generally be preserved.',
      '- Tracks #4-#6 are the modern non-representative additions and are the main replacement target.',
      '- High issues should be replaced before applying another automated write.',
      '- Medium issues usually mean parent/child/sibling overlap that needs human judgement.',
      '',
      '## Priority Issues',
      '',
      ...sortedItems
        .filter((item) => item.issues.length > 0)
        .flatMap((item) => [
          `### ${item.name}`,
          '',
          `- ID: \`${item.id}\``,
          `- Path: ${item.path}`,
          `- Track count: ${item.trackCount}`,
          `- Needs replacement: ${item.needsReplacement ? 'yes' : 'no'}`,
          ...item.issues.map(issueLine),
          '',
          'Current tracks:',
          ...item.tracks.map((track, index) => `- #${index + 1}: ${track.artist} - ${track.title} ${track.neteaseUrl ?? ''}`),
          '',
        ]),
    ].join('\n'),
  );

  console.log('[genre-sound-cue-quality-audit] done', {
    totalGenres: report.totalGenres,
    totalTracks: report.totalTracks,
    genresWithIssues: report.genresWithIssues,
    genresNeedingReplacement: report.genresNeedingReplacement,
    highIssues: report.highIssues,
    mediumIssues: report.mediumIssues,
    report: REPORT_PATH,
    markdownReport: MARKDOWN_REPORT_PATH,
  });
}

main()
  .catch((error) => {
    console.error('[genre-sound-cue-quality-audit] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
