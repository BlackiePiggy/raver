import 'dotenv/config';
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

import { Prisma, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type TriText = {
  en?: string | null;
  zh?: string | null;
  ja?: string | null;
};

const safeText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const readInputPath = (): string => {
  const argIndex = process.argv.findIndex((arg) => arg === '--input' || arg === '-i');
  if (argIndex >= 0 && process.argv[argIndex + 1]) return path.resolve(process.argv[argIndex + 1]);
  throw new Error('Missing required --input <python-file-path>');
};

const parseTranslations = (source: string): Map<string, string> => {
  const lines = source.split(/\r?\n/);
  const translations = new Map<string, string>();

  for (const line of lines) {
    const match = line.match(/^\s*"([^"]+)":\s*"(.*)",\s*$/);
    if (!match) continue;

    const [, id, rawValue] = match;
    const value = rawValue
      .replace(/\\"/g, '"')
      .replace(/\\\\/g, '\\')
      .trim();
    if (!value) continue;
    translations.set(id, value);
  }

  return translations;
};

async function main() {
  const inputPath = readInputPath();
  const source = await readFile(inputPath, 'utf8');
  const translations = parseTranslations(source);
  if (!translations.size) {
    throw new Error(`No translation rows parsed from ${inputPath}`);
  }

  const genres = await prisma.genre.findMany({
    orderBy: [{ path: 'asc' }],
    select: {
      id: true,
      path: true,
      descriptionI18n: true,
    },
  });

  const genreIdSet = new Set(genres.map((genre) => genre.id));
  const missing = genres
    .filter((genre) => !translations.has(genre.id))
    .map((genre) => genre.id);

  const updates = genres.flatMap((genre) => {
    const zh = translations.get(genre.id);
    if (!zh) return [];

    const current =
      genre.descriptionI18n && typeof genre.descriptionI18n === 'object' && !Array.isArray(genre.descriptionI18n)
        ? (genre.descriptionI18n as TriText)
        : {};

    const next: TriText = {
      en: safeText(current.en),
      zh,
      ja: safeText(current.ja),
    };

    return [{
      id: genre.id,
      query: prisma.genre.update({
        where: { id: genre.id },
        data: {
          descriptionI18n: next as unknown as Prisma.InputJsonValue,
        },
      }),
    }];
  });

  await prisma.$transaction(updates.map((item) => item.query));

  const updated = updates.length;
  const unmatched = Array.from(translations.keys()).filter((id) => !genreIdSet.has(id));
  const reportPath = path.resolve(process.cwd(), 'prisma/genre-i18n-translated/genre-zh-apply-report.json');
  await writeFile(
    reportPath,
    `${JSON.stringify(
      {
        appliedAt: new Date().toISOString(),
        inputPath,
        parsedTranslations: translations.size,
        updated,
        missingFromInput: missing,
        unmatchedInputIds: unmatched,
      },
      null,
      2
    )}\n`,
    'utf8'
  );

  console.log(`Parsed ${translations.size} translations from ${inputPath}`);
  console.log(`Updated zh descriptions for ${updated} genres`);
  console.log(`Report written to ${reportPath}`);
  if (missing.length) {
    console.log(`Missing translations for ${missing.length} genres`);
  }
  if (unmatched.length) {
    console.log(`Found ${unmatched.length} input ids not present in database`);
  }
}

main()
  .catch((error) => {
    console.error('[apply-genre-zh-descriptions-from-python] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
