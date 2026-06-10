import 'dotenv/config';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { Prisma, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type TriText = {
  en?: string | null;
  zh?: string | null;
  ja?: string | null;
};

type SourceRow = {
  英文名称?: unknown;
  中文译名?: unknown;
  发源地?: unknown;
  发源时期?: unknown;
  BPM区间?: unknown;
};

type NormalizedSourceRow = {
  englishName: string;
  chineseName: string;
  origin: string;
  era: string;
  bpm: string;
  normalizedKey: string;
};

type ReportRow = {
  genreId: string;
  genreName: string;
  path: string;
  sourceEnglishName: string;
  normalizedKey: string;
};

const safeText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const parseInputPath = (): string => {
  const index = process.argv.findIndex((arg) => arg === '--input' || arg === '-i');
  if (index >= 0 && process.argv[index + 1]) return path.resolve(process.argv[index + 1]);
  throw new Error('Missing required --input <json-file-path>');
};

const normalizeNameKey = (value: string): string => value
  .normalize('NFKD')
  .replace(/[\u0300-\u036f]/g, '')
  .toLowerCase()
  .replace(/&/g, ' and ')
  .replace(/'/g, '')
  .replace(/\//g, ' ')
  .replace(/[^a-z0-9]+/g, ' ')
  .replace(/\s+/g, ' ')
  .trim();

const normalizeJsonRows = (raw: unknown): NormalizedSourceRow[] => {
  if (!Array.isArray(raw)) throw new Error('Input JSON must be an array');

  return raw.flatMap((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) return [];
    const row = item as SourceRow;
    const englishName = safeText(row.英文名称);
    if (!englishName) return [];

    return [{
      englishName,
      chineseName: safeText(row.中文译名),
      origin: safeText(row.发源地),
      era: safeText(row.发源时期),
      bpm: safeText(row.BPM区间),
      normalizedKey: normalizeNameKey(englishName),
    }];
  });
};

async function main() {
  const inputPath = parseInputPath();
  const raw = JSON.parse(await readFile(inputPath, 'utf8')) as unknown;
  const sourceRows = normalizeJsonRows(raw);
  if (!sourceRows.length) {
    throw new Error(`No valid rows found in ${inputPath}`);
  }

  const duplicateSourceKeys = sourceRows.filter((row, index) =>
    sourceRows.findIndex((candidate) => candidate.normalizedKey === row.normalizedKey) !== index
  );
  if (duplicateSourceKeys.length) {
    throw new Error(`Input contains duplicate normalized names, e.g. ${duplicateSourceKeys.slice(0, 10).map((item) => item.englishName).join(', ')}`);
  }

  const sourceByKey = new Map(sourceRows.map((row) => [row.normalizedKey, row]));
  const genres = await prisma.genre.findMany({
    orderBy: [{ path: 'asc' }],
    select: {
      id: true,
      name: true,
      path: true,
      nameI18n: true,
      origin: true,
      era: true,
      bpm: true,
    },
  });

  const missingMatches = genres.filter((genre) => !sourceByKey.has(normalizeNameKey(genre.name)));
  if (missingMatches.length) {
    throw new Error(`Source JSON is missing ${missingMatches.length} genres, e.g. ${missingMatches.slice(0, 10).map((row) => row.name).join(', ')}`);
  }

  const matchedReport: ReportRow[] = [];
  const updates = genres.map((genre) => {
    const normalizedKey = normalizeNameKey(genre.name);
    const source = sourceByKey.get(normalizedKey);
    if (!source) {
      throw new Error(`Unexpected missing source row for genre ${genre.id} (${genre.name})`);
    }

    const currentNameI18n =
      genre.nameI18n && typeof genre.nameI18n === 'object' && !Array.isArray(genre.nameI18n)
        ? (genre.nameI18n as TriText)
        : {};
    const nextNameI18n: TriText = {
      en: safeText(currentNameI18n.en) || genre.name,
      zh: source.chineseName || null,
      ja: safeText(currentNameI18n.ja) || null,
    };

    matchedReport.push({
      genreId: genre.id,
      genreName: genre.name,
      path: genre.path,
      sourceEnglishName: source.englishName,
      normalizedKey,
    });

    return prisma.genre.update({
      where: { id: genre.id },
      data: {
        nameI18n: nextNameI18n as unknown as Prisma.InputJsonValue,
        origin: source.origin || null,
        era: source.era || null,
        bpm: source.bpm || null,
      },
    });
  });

  await prisma.$transaction(updates);

  const matchedGenreIds = new Set(matchedReport.map((row) => row.genreId));
  const unmatchedSourceRows = sourceRows.filter((row) => !matchedReport.some((entry) => entry.normalizedKey === row.normalizedKey));
  const outputDir = path.resolve(process.cwd(), 'prisma/genre-i18n-translated');
  const reportPath = path.join(outputDir, 'genre-metadata-import-report.json');
  await mkdir(outputDir, { recursive: true });
  await writeFile(reportPath, `${JSON.stringify({
    importedAt: new Date().toISOString(),
    inputPath,
    sourceRowCount: sourceRows.length,
    updatedGenreCount: updates.length,
    matchedGenreCount: matchedGenreIds.size,
    unmatchedSourceRows: unmatchedSourceRows.map((row) => row.englishName),
    matched: matchedReport,
  }, null, 2)}\n`, 'utf8');

  console.log(`Imported metadata for ${updates.length} genres from ${inputPath}`);
  console.log(`Report written to ${reportPath}`);
}

main()
  .catch((error) => {
    console.error('[import-genre-metadata-from-zh-json] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
