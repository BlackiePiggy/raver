import dotenv from 'dotenv';
import { PrismaClient, Prisma } from '@prisma/client';

dotenv.config();

const prisma = new PrismaClient();

type BindingSeed = {
  label: string;
  genreId: string;
};

const PLAN: Record<string, BindingSeed[]> = {
  DROPI: [
    { label: 'Big Room House', genreId: 'house/electro-house/big-room-house' },
    { label: 'Hardstyle', genreId: 'techno/hard-techno/hardcore/hardstyle' },
    { label: 'Hardcore', genreId: 'techno/hard-techno/hardcore' },
    { label: 'Hard Dance', genreId: 'techno/hard-techno/hard-dance' },
    { label: 'Hard Trance', genreId: 'trance/hard-trance' },
  ],
  BOUN: [
    { label: 'Melbourne Bounce', genreId: 'house/electro-house/melbourne-bounce' },
    { label: 'Big Room House', genreId: 'house/electro-house/big-room-house' },
    { label: 'Future House', genreId: 'house/electro-house/future-house' },
    { label: 'Electro House', genreId: 'house/electro-house' },
    { label: 'Eurodance', genreId: 'pop-and-rock-fusion/dance-pop/eurodance' },
  ],
  HUG: [
    { label: 'Melodic Bass', genreId: 'bass-music/future-bass/melodic-bass' },
    { label: 'Future bass', genreId: 'bass-music/future-bass' },
    { label: 'Melodic Dubstep', genreId: 'bass-music/dubstep/melodic-dubstep' },
    { label: 'Progressive House', genreId: 'house/progressive-house' },
    { label: 'Vocal Trance', genreId: 'trance/uplifting-trance/vocal-trance' },
  ],
  OLD: [
    { label: 'Disco', genreId: 'disco' },
    { label: 'Classic Chicago House', genreId: 'house/chicago-house/classic-chicago-house' },
    { label: 'Chicago House', genreId: 'house/chicago-house' },
    { label: 'Acid House', genreId: 'house/chicago-house/acid-house' },
    { label: 'Eurodance', genreId: 'pop-and-rock-fusion/dance-pop/eurodance' },
  ],
  PROD: [
    { label: 'Progressive House', genreId: 'house/progressive-house' },
    { label: 'Progressive Trance', genreId: 'trance/progressive-trance' },
    { label: 'Melodic Progressive Trance', genreId: 'trance/progressive-trance/melodic-progressive-trance' },
    { label: 'Trance', genreId: 'trance' },
    { label: 'Melodic Techno', genreId: 'techno/melodic-techno' },
  ],
  HEAD: [
    { label: 'Hardstyle', genreId: 'techno/hard-techno/hardcore/hardstyle' },
    { label: 'Hardcore', genreId: 'techno/hard-techno/hardcore' },
    { label: 'Aggressive Dubstep', genreId: 'bass-music/dubstep/brostep/aggressive-dubstep' },
    { label: 'Industrial Hardcore', genreId: 'techno/hard-techno/hardcore/industrial-hardcore' },
    { label: 'Big Room House', genreId: 'house/electro-house/big-room-house' },
  ],
  NIGHT: [
    { label: 'Chillwave', genreId: 'chill-out/chillwave' },
    { label: 'Downtempo', genreId: 'chill-out/downtempo' },
    { label: 'Chillstep', genreId: 'bass-music/dubstep/melodic-dubstep/chillstep' },
    { label: 'Future bass', genreId: 'bass-music/future-bass' },
    { label: 'Ambient', genreId: 'ambient' },
  ],
  DREAM: [
    { label: 'Uplifting Trance', genreId: 'trance/uplifting-trance' },
    { label: 'Melodic Techno', genreId: 'techno/melodic-techno' },
    { label: 'Progressive Trance', genreId: 'trance/progressive-trance' },
    { label: 'Psybient', genreId: 'ambient/psybient' },
    { label: 'Space Ambient', genreId: 'ambient/space-ambient' },
  ],
  DARK: [
    { label: 'Industrial Techno', genreId: 'techno/hard-techno/industrial-techno' },
    { label: 'Experimental', genreId: 'experimental' },
    { label: 'Dark Ambient', genreId: 'ambient/dark-ambient' },
    { label: 'Industrial Ambient', genreId: 'ambient/dark-ambient/industrial-ambient' },
    { label: 'EBM', genreId: 'industrial-and-post-industrial/ebm' },
  ],
  MASH: [
    { label: 'Experimental', genreId: 'experimental' },
    { label: 'IDM (Intelligent Dance Music)', genreId: 'experimental/idm-intelligent-dance-music' },
    { label: 'Glitch Hop', genreId: 'experimental/idm-intelligent-dance-music/glitch-hop' },
    { label: 'Complextro', genreId: 'house/electro-house/complextro' },
    { label: 'Breakbeat', genreId: 'breakbeat' },
  ],
  PARTY: [
    { label: 'Uplifting Trance', genreId: 'trance/uplifting-trance' },
    { label: 'Progressive House', genreId: 'house/progressive-house' },
    { label: 'Big Room House', genreId: 'house/electro-house/big-room-house' },
    { label: 'Vocal Trance', genreId: 'trance/uplifting-trance/vocal-trance' },
    { label: 'House', genreId: 'house' },
  ],
  SUNNY: [
    { label: 'Future House', genreId: 'house/electro-house/future-house' },
    { label: 'Progressive House', genreId: 'house/progressive-house' },
    { label: 'Melbourne Bounce', genreId: 'house/electro-house/melbourne-bounce' },
    { label: 'Melodic House', genreId: 'house/melodic-house' },
    { label: 'Dance-pop', genreId: 'pop-and-rock-fusion/dance-pop' },
  ],
  COLD: [
    { label: 'Minimal Techno', genreId: 'techno/minimal-techno' },
    { label: 'Dub Techno', genreId: 'techno/minimal-techno/dub-techno' },
    { label: 'Deep Techno', genreId: 'techno/minimal-techno/deep-techno' },
    { label: 'Ambient Techno', genreId: 'techno/ambient-techno' },
    { label: 'Industrial Techno', genreId: 'techno/hard-techno/industrial-techno' },
  ],
  GLIT: [
    { label: 'Complextro', genreId: 'house/electro-house/complextro' },
    { label: 'Glitch Hop', genreId: 'experimental/idm-intelligent-dance-music/glitch-hop' },
    { label: 'IDM (Intelligent Dance Music)', genreId: 'experimental/idm-intelligent-dance-music' },
    { label: 'Color Bass', genreId: 'bass-music/dubstep/color-bass' },
    { label: 'Melodic Brostep', genreId: 'bass-music/dubstep/brostep/melodic-brostep' },
  ],
  AMBI: [
    { label: 'Ambient', genreId: 'ambient' },
    { label: 'Space Ambient', genreId: 'ambient/space-ambient' },
    { label: 'Psybient', genreId: 'ambient/psybient' },
    { label: 'Progressive Trance', genreId: 'trance/progressive-trance' },
    { label: 'Ambient Techno', genreId: 'techno/ambient-techno' },
  ],
  PLUR: [
    { label: 'Chillwave', genreId: 'chill-out/chillwave' },
    { label: 'Downtempo', genreId: 'chill-out/downtempo' },
    { label: 'Chill-out', genreId: 'chill-out' },
    { label: 'Future bass', genreId: 'bass-music/future-bass' },
    { label: 'Melodic Bass', genreId: 'bass-music/future-bass/melodic-bass' },
  ],
  DRUNK: [
    { label: 'Big Room House', genreId: 'house/electro-house/big-room-house' },
    { label: 'Melbourne Bounce', genreId: 'house/electro-house/melbourne-bounce' },
    { label: 'Hardstyle', genreId: 'techno/hard-techno/hardcore/hardstyle' },
    { label: 'Eurodance', genreId: 'pop-and-rock-fusion/dance-pop/eurodance' },
    { label: 'Moombahton', genreId: 'bass-music/moombahton' },
  ],
  HHHH: [
    { label: 'Happy Hardcore', genreId: 'techno/hard-techno/hardcore/happy-hardcore' },
    { label: 'Kawaii future bass', genreId: 'bass-music/future-bass/kawaii-future-bass' },
    { label: 'Dance-pop', genreId: 'pop-and-rock-fusion/dance-pop' },
    { label: 'Eurodance', genreId: 'pop-and-rock-fusion/dance-pop/eurodance' },
    { label: 'Melbourne Bounce', genreId: 'house/electro-house/melbourne-bounce' },
  ],
  CPDD: [
    { label: 'Melbourne Bounce', genreId: 'house/electro-house/melbourne-bounce' },
    { label: 'Big Room House', genreId: 'house/electro-house/big-room-house' },
    { label: 'Future House', genreId: 'house/electro-house/future-house' },
    { label: 'Dance-pop', genreId: 'pop-and-rock-fusion/dance-pop' },
    { label: 'Progressive House', genreId: 'house/progressive-house' },
  ],
  PHOENIX: [
    { label: 'Melodic Bass', genreId: 'bass-music/future-bass/melodic-bass' },
    { label: 'Future bass', genreId: 'bass-music/future-bass' },
    { label: 'Melodic Dubstep', genreId: 'bass-music/dubstep/melodic-dubstep' },
    { label: 'Chillstep', genreId: 'bass-music/dubstep/melodic-dubstep/chillstep' },
    { label: 'Melodic Brostep', genreId: 'bass-music/dubstep/brostep/melodic-brostep' },
  ],
};

async function main() {
  const codes = Object.keys(PLAN);
  const genres = await prisma.genre.findMany({
    where: {
      id: {
        in: Array.from(
          new Set(
            Object.values(PLAN)
              .flat()
              .map((binding) => binding.genreId),
          ),
        ),
      },
    },
    select: { id: true, name: true, path: true },
  });

  const genreIds = new Set(genres.map((genre) => genre.id));
  const genresById = new Map(genres.map((genre) => [genre.id, genre]));
  const missingGenreIds = Object.values(PLAN)
    .flat()
    .map((binding) => binding.genreId)
    .filter((genreId, index, list) => list.indexOf(genreId) === index && !genreIds.has(genreId));

  if (missingGenreIds.length > 0) {
    throw new Error(`Missing genre ids: ${missingGenreIds.join(', ')}`);
  }

  const rows = await prisma.personalityResultType.findMany({
    where: { code: { in: codes } },
    select: { id: true, code: true, title: true },
    orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
  });

  const foundCodes = new Set(rows.map((row) => row.code));
  const missingCodes = codes.filter((code) => !foundCodes.has(code));
  if (missingCodes.length > 0) {
    throw new Error(`Missing personality result codes: ${missingCodes.join(', ')}`);
  }

  let updatedCount = 0;
  for (const row of rows) {
    const nextBindings = PLAN[row.code].map((binding) => ({
      label: binding.label,
      displayName: null,
      genreId: binding.genreId,
      path: genresById.get(binding.genreId)?.path ?? null,
    }));

    await prisma.personalityResultType.update({
      where: { id: row.id },
      data: {
        genreBindings: nextBindings as Prisma.InputJsonValue,
      },
    });

    updatedCount += 1;
  }

  console.log('[apply-edmti-result-genre-bindings] done', {
    updatedCount,
    withBindings: rows.filter((row) => PLAN[row.code].length > 0).length,
    withoutBindings: rows.filter((row) => PLAN[row.code].length === 0).length,
    totalBindings: rows.reduce((sum, row) => sum + PLAN[row.code].length, 0),
  });
}

main()
  .catch((error) => {
    console.error('[apply-edmti-result-genre-bindings] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
