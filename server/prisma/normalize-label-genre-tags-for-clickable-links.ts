import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';

dotenv.config();

const prisma = new PrismaClient();

const APPLY = process.argv.includes('--apply');

const TAG_MAP = new Map<string, string>([
  ['big room', 'Big Room House'],
  ['drum and bass', 'Drum and Bass'],
  ['psy trance', 'Psytrance'],
  ['breaks', 'Breakbeat'],
  ['trap', 'Trap (EDM)'],
]);

const normalizeText = (value: unknown): string =>
  String(value || '')
    .trim()
    .replace(/\s+/g, ' ');

const normalizeLooseKey = (value: string): string =>
  value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/[_/]+/g, ' ')
    .replace(/[-\u2010-\u2015\u2212]+/g, ' ')
    .replace(/[()[\]{}\u2018\u2019\u201c\u201d'".:;!?+*#@`~|\\]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

async function main() {
  const labels = await prisma.label.findMany({
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    select: {
      id: true,
      name: true,
      genres: true,
    },
  });

  const changes: Array<{
    id: string;
    name: string;
    beforeGenres: string[];
    afterGenres: string[];
    replacements: Array<{ from: string; to: string }>;
  }> = [];

  for (const label of labels) {
    const seen = new Set<string>();
    const replacements: Array<{ from: string; to: string }> = [];
    const afterGenres: string[] = [];

    for (const rawGenre of label.genres) {
      const genre = normalizeText(rawGenre);
      const mapped = TAG_MAP.get(normalizeLooseKey(genre)) || genre;
      const dedupeKey = normalizeLooseKey(mapped);
      if (dedupeKey && seen.has(dedupeKey)) continue;
      seen.add(dedupeKey);
      afterGenres.push(mapped);
      if (mapped !== genre) {
        replacements.push({ from: genre, to: mapped });
      }
    }

    const changed =
      replacements.length > 0 ||
      afterGenres.length !== label.genres.length ||
      afterGenres.some((genre, index) => genre !== label.genres[index]);

    if (!changed) continue;

    changes.push({
      id: label.id,
      name: label.name,
      beforeGenres: label.genres,
      afterGenres,
      replacements,
    });

    if (APPLY) {
      await prisma.label.update({
        where: { id: label.id },
        data: {
          genres: afterGenres,
        },
      });
    }
  }

  console.log(
    JSON.stringify(
      {
        mode: APPLY ? 'apply' : 'dry-run',
        affectedLabels: changes.length,
        changedGenreInstances: changes.reduce((sum, item) => sum + item.replacements.length, 0),
        changes,
      },
      null,
      2
    )
  );
}

main()
  .catch((error) => {
    console.error('[normalize-label-genre-tags-for-clickable-links] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
