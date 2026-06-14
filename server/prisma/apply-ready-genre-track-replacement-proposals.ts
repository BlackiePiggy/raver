import dotenv from 'dotenv';
import { Prisma, PrismaClient } from '@prisma/client';
import fs from 'fs';
import path from 'path';

dotenv.config();

const prisma = new PrismaClient();

const APPLY = process.argv.includes('--apply');
const PROPOSAL_PATH = (() => {
  const arg = process.argv.find((item) => item.startsWith('--proposal='));
  return arg?.slice('--proposal='.length) || null;
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

type ProposedTrack = {
  title: string;
  artist: string;
  neteaseUrl: string;
};

type ProposalItem = {
  id: string;
  name: string;
  status: string;
  proposedModernTracks: ProposedTrack[];
};

type ProposalReport = {
  items: ProposalItem[];
};

const CACHE_DIR = path.join(process.cwd(), 'prisma', '.cache');
const REPORT_PATH = path.join(
  CACHE_DIR,
  `genre-track-replacement-ready-apply-${new Date().toISOString().replace(/[:.]/g, '-')}.json`,
);
const MARKDOWN_REPORT_PATH = REPORT_PATH.replace(/\.json$/, '.md');

function latestProposalPath(): string {
  if (PROPOSAL_PATH) return PROPOSAL_PATH;
  const files = fs.readdirSync(CACHE_DIR)
    .filter((file) => file.startsWith('genre-track-replacement-proposals-musicbrainz-') && file.endsWith('.json'))
    .map((file) => path.join(CACHE_DIR, file))
    .sort((lhs, rhs) => fs.statSync(rhs).mtimeMs - fs.statSync(lhs).mtimeMs);
  if (!files[0]) throw new Error('No MusicBrainz replacement proposal report found');
  return files[0];
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

function toSoundCueTrack(track: ProposedTrack): SoundCueTrack {
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

function isReadyStatus(status: string): boolean {
  return status === 'ready' || status === 'ready_fallback';
}

async function main() {
  const proposalPath = latestProposalPath();
  const proposal = JSON.parse(fs.readFileSync(proposalPath, 'utf8')) as ProposalReport;
  const readyItems = proposal.items.filter((item) => isReadyStatus(item.status) && item.proposedModernTracks.length >= 3);

  const report = {
    apply: APPLY,
    proposalPath,
    readyCount: readyItems.length,
    updated: 0,
    unchanged: 0,
    skipped: [] as Array<{ id: string; name: string; reason: string }>,
    items: [] as Array<{ id: string; name: string; beforeModernTracks: SoundCueTrack[]; afterModernTracks: SoundCueTrack[] }>,
  };

  for (const item of readyItems) {
    const genre = await prisma.genre.findUnique({
      where: { id: item.id },
      select: { id: true, name: true, soundCueTracks: true },
    });
    if (!genre) {
      report.skipped.push({ id: item.id, name: item.name, reason: 'genre not found' });
      continue;
    }

    const currentTracks = normalizeTracks(genre.soundCueTracks);
    if (currentTracks.length < 3) {
      report.skipped.push({ id: item.id, name: item.name, reason: 'fewer than 3 preserved tracks' });
      continue;
    }

    const beforeModernTracks = currentTracks.slice(3, 6);
    const afterModernTracks = item.proposedModernTracks.slice(0, 3).map(toSoundCueTrack);
    const nextTracks = [...currentTracks.slice(0, 3), ...afterModernTracks];
    const changed = JSON.stringify(currentTracks.slice(0, 6)) !== JSON.stringify(nextTracks);

    if (changed) {
      report.updated += 1;
      if (APPLY) {
        await prisma.genre.update({
          where: { id: item.id },
          data: {
            soundCueTracks: nextTracks as unknown as Prisma.InputJsonValue,
          },
        });
      }
    } else {
      report.unchanged += 1;
    }

    report.items.push({
      id: item.id,
      name: item.name,
      beforeModernTracks,
      afterModernTracks,
    });
  }

  fs.mkdirSync(CACHE_DIR, { recursive: true });
  fs.writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2));
  fs.writeFileSync(
    MARKDOWN_REPORT_PATH,
    [
      '# Ready Genre Track Replacement Apply Report',
      '',
      `- Apply: ${APPLY}`,
      `- Proposal: ${proposalPath}`,
      `- Ready items: ${report.readyCount}`,
      `- Updated: ${report.updated}`,
      `- Unchanged: ${report.unchanged}`,
      `- Skipped: ${report.skipped.length}`,
      '',
      '## Skipped',
      '',
      ...(report.skipped.length
        ? report.skipped.map((item) => `- ${item.name} (\`${item.id}\`): ${item.reason}`)
        : ['- None']),
      '',
      '## Applied Items',
      '',
      ...report.items.flatMap((item) => [
        `### ${item.name}`,
        '',
        `- ID: \`${item.id}\``,
        'Before:',
        ...item.beforeModernTracks.map((track, index) => `- old #${index + 4}: ${track.artist} - ${track.title} ${track.neteaseUrl ?? ''}`),
        'After:',
        ...item.afterModernTracks.map((track, index) => `- new #${index + 4}: ${track.artist} - ${track.title} ${track.neteaseUrl ?? ''}`),
        '',
      ]),
    ].join('\n'),
  );

  console.log('[genre-track-replacement-ready-apply] done', {
    apply: APPLY,
    proposalPath,
    readyCount: report.readyCount,
    updated: report.updated,
    unchanged: report.unchanged,
    skipped: report.skipped.length,
    report: REPORT_PATH,
    markdownReport: MARKDOWN_REPORT_PATH,
  });
}

main()
  .catch((error) => {
    console.error('[genre-track-replacement-ready-apply] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
