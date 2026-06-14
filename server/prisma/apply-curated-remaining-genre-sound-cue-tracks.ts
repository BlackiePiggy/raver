import dotenv from 'dotenv';
import { Prisma, PrismaClient } from '@prisma/client';
import fs from 'fs';
import path from 'path';

dotenv.config();

const prisma = new PrismaClient();
const APPLY = process.argv.includes('--apply');

type SoundCueTrack = {
  title: string;
  artist: string;
  spotifyUrl: string | null;
  appleMusicUrl: string | null;
  neteaseUrl: string | null;
  soundcloudUrl: string | null;
  beatportUrl: string | null;
};

const CACHE_DIR = path.join(process.cwd(), 'prisma', '.cache');
const REPORT_PATH = path.join(
  CACHE_DIR,
  `curated-remaining-genre-sound-cue-tracks-${new Date().toISOString().replace(/[:.]/g, '-')}.json`,
);
const MARKDOWN_REPORT_PATH = REPORT_PATH.replace(/\.json$/, '.md');

function track(artist: string, title: string, neteaseUrl: string): SoundCueTrack {
  return {
    artist,
    title,
    neteaseUrl,
    spotifyUrl: null,
    appleMusicUrl: null,
    soundcloudUrl: null,
    beatportUrl: null,
  };
}

const CURATED_MODERN_TRACKS: Record<string, SoundCueTrack[]> = {
  'ambient/new-age-ambient/celtic-ambient': [
    track('Anilah', 'Medicine Chant', 'https://music.163.com/#/song?id=28278533'),
    track('Adrian Von Ziegler', 'Prophecy', 'https://music.163.com/#/song?id=26466990'),
    track('BrunuhVille', 'The Wolf and the Moon', 'https://music.163.com/#/song?id=31356802'),
  ],
  'global-club/funk-carioca/funk-proibido': [
    track('MC Tikão, Raflow, Jhowzin, jess beats', 'Vida Bandida', 'https://music.163.com/#/song?id=2061280059'),
    track('MC TH', 'Vidro Fumê (Ao Vivo)', 'https://music.163.com/#/song?id=1345483014'),
    track('MC Menor da ZO, Mc Bó Do Catarina, DJ LéoSheik, Love Funk', 'Proibidão Vive', 'https://music.163.com/#/song?id=2125660034'),
  ],
  'global-club/latin-club/latin-bass': [
    track('Nicola Cruz, Huaira', 'Colibria', 'https://music.163.com/#/song?id=38494959'),
    track('Chancha Via Circuito', 'Ilaló', 'https://music.163.com/#/song?id=1435869638'),
    track('Lechuga Zafiro', 'Sapo De Manga', 'https://music.163.com/#/song?id=26325398'),
  ],
  'global-club/latin-club/latincore': [
    track('Safety Trance, Arca', 'El Alma Que Te Trajo', 'https://music.163.com/#/song?id=1952700741'),
    track('Kamixlo', 'Paleta', 'https://music.163.com/#/song?id=1966545553'),
    track('Cardopusher', 'Yr Fifteen Minutes Are Up', 'https://music.163.com/#/song?id=1880296459'),
  ],
  'global-club/singeli': [
    track('Dogo Niga', 'Kimbau Mbau', 'https://music.163.com/#/song?id=543965833'),
    track('Kadilida', 'Ambakati', 'https://music.163.com/#/song?id=1987752304'),
    track('McZo', 'Ushauri Wa Bure', 'https://music.163.com/#/song?id=1862697490'),
  ],
  'industrial-and-post-industrial': [
    track('3TEETH', 'EXXXIT', 'https://music.163.com/#/song?id=1363589897'),
    track('Author & Punisher', 'Nihil Strength', 'https://music.163.com/#/song?id=1314771929'),
    track('HEALTH, SIERRA', 'HATEFUL', 'https://music.163.com/#/song?id=2106319753'),
  ],
  'trance/hard-trance/hard-uplifting-trance': [
    track('Billy Gillies, Hannah Boleyn', 'DNA (Loving You) [feat. Hannah Boleyn]', 'https://music.163.com/#/song?id=2067164107'),
    track('David Rust', 'Vision (Renegade System Remix)', 'https://music.163.com/#/song?id=1335774136'),
    track('Sneijder', 'Vaporize', 'https://music.163.com/#/song?id=478736202'),
  ],
  'trance/uplifting-trance/orchestral-trance': [
    track('RAM, Susana', 'RAMelia (Tribute To Amelia) (Original Mix)', 'https://music.163.com/#/song?id=28096177'),
    track("Sergey Nevone, Simon O'Shine", 'Apprehension (Original Mix)', 'https://music.163.com/#/song?id=27977937'),
    track('Kelly Andrew', 'Xanadu (Orchestral Trance Mix)', 'https://music.163.com/#/song?id=36664998'),
  ],
};

function normalizeTrack(value: unknown): SoundCueTrack | null {
  if (!value || typeof value !== 'object') return null;
  const raw = value as Record<string, unknown>;
  const title = typeof raw.title === 'string' ? raw.title.trim() : '';
  const artist = typeof raw.artist === 'string' ? raw.artist.trim() : '';
  if (!title || !artist) return null;
  return {
    title,
    artist,
    neteaseUrl: typeof raw.neteaseUrl === 'string' && raw.neteaseUrl.trim() ? raw.neteaseUrl.trim() : null,
    spotifyUrl: typeof raw.spotifyUrl === 'string' && raw.spotifyUrl.trim() ? raw.spotifyUrl.trim() : null,
    appleMusicUrl: typeof raw.appleMusicUrl === 'string' && raw.appleMusicUrl.trim() ? raw.appleMusicUrl.trim() : null,
    soundcloudUrl: typeof raw.soundcloudUrl === 'string' && raw.soundcloudUrl.trim() ? raw.soundcloudUrl.trim() : null,
    beatportUrl: typeof raw.beatportUrl === 'string' && raw.beatportUrl.trim() ? raw.beatportUrl.trim() : null,
  };
}

function normalizeTracks(value: Prisma.JsonValue | null): SoundCueTrack[] {
  if (!Array.isArray(value)) return [];
  return value.map(normalizeTrack).filter((item): item is SoundCueTrack => Boolean(item));
}

async function main() {
  const report = {
    apply: APPLY,
    updated: 0,
    unchanged: 0,
    skipped: [] as Array<{ id: string; reason: string }>,
    items: [] as Array<{ id: string; name: string; beforeModernTracks: SoundCueTrack[]; afterModernTracks: SoundCueTrack[] }>,
  };

  for (const [id, afterModernTracks] of Object.entries(CURATED_MODERN_TRACKS)) {
    const genre = await prisma.genre.findUnique({
      where: { id },
      select: { id: true, name: true, soundCueTracks: true },
    });
    if (!genre) {
      report.skipped.push({ id, reason: 'genre not found' });
      continue;
    }
    const currentTracks = normalizeTracks(genre.soundCueTracks);
    if (currentTracks.length < 3) {
      report.skipped.push({ id, reason: 'fewer than 3 preserved tracks' });
      continue;
    }

    const nextTracks = [...currentTracks.slice(0, 3), ...afterModernTracks];
    const beforeModernTracks = currentTracks.slice(3, 6);
    const changed = JSON.stringify(currentTracks.slice(0, 6)) !== JSON.stringify(nextTracks);
    if (changed) {
      report.updated += 1;
      if (APPLY) {
        await prisma.genre.update({
          where: { id },
          data: { soundCueTracks: nextTracks as unknown as Prisma.InputJsonValue },
        });
      }
    } else {
      report.unchanged += 1;
    }
    report.items.push({ id, name: genre.name, beforeModernTracks, afterModernTracks });
  }

  fs.mkdirSync(CACHE_DIR, { recursive: true });
  fs.writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2));
  fs.writeFileSync(
    MARKDOWN_REPORT_PATH,
    [
      '# Curated Remaining Genre Sound Cue Tracks',
      '',
      `- Apply: ${APPLY}`,
      `- Updated: ${report.updated}`,
      `- Unchanged: ${report.unchanged}`,
      `- Skipped: ${report.skipped.length}`,
      '',
      '## Items',
      '',
      ...report.items.flatMap((item) => [
        `### ${item.name}`,
        '',
        `- ID: \`${item.id}\``,
        'Before:',
        ...item.beforeModernTracks.map((trackItem, index) => `- old #${index + 4}: ${trackItem.artist} - ${trackItem.title} ${trackItem.neteaseUrl ?? ''}`),
        'After:',
        ...item.afterModernTracks.map((trackItem, index) => `- new #${index + 4}: ${trackItem.artist} - ${trackItem.title} ${trackItem.neteaseUrl ?? ''}`),
        '',
      ]),
    ].join('\n'),
  );

  console.log('[curated-remaining-genre-sound-cue-tracks] done', {
    apply: APPLY,
    updated: report.updated,
    unchanged: report.unchanged,
    skipped: report.skipped.length,
    report: REPORT_PATH,
    markdownReport: MARKDOWN_REPORT_PATH,
  });
}

main()
  .catch((error) => {
    console.error('[curated-remaining-genre-sound-cue-tracks] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
