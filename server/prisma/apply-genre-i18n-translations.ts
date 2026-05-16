import fs from 'fs';
import path from 'path';
import { Prisma, PrismaClient } from '@prisma/client';

type TriText = {
  en: string;
  zh: string;
  ja: string;
};

type TranslationRow = {
  id: string;
  descriptionI18n: TriText;
  exampleI18n: TriText | null;
};

const prisma = new PrismaClient();

const safeText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const readInputPath = (): string => {
  const argIndex = process.argv.findIndex((arg) => arg === '--input' || arg === '-i');
  if (argIndex >= 0 && process.argv[argIndex + 1]) return path.resolve(process.argv[argIndex + 1]);
  return path.resolve(__dirname, 'genre-i18n-translations.json');
};

const isTriText = (value: unknown): value is TriText => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const row = value as Record<string, unknown>;
  return Boolean(safeText(row.en) && safeText(row.zh) && safeText(row.ja));
};

const normalizeRows = (raw: unknown): TranslationRow[] => {
  const items: unknown[] = Array.isArray(raw)
    ? raw
    : raw && typeof raw === 'object' && Array.isArray((raw as Record<string, unknown>).items)
      ? ((raw as Record<string, unknown>).items as unknown[])
      : [];
  return items.flatMap((item: unknown) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) return [];
    const row = item as Record<string, unknown>;
    const id = safeText(row.id);
    if (!id || !isTriText(row.descriptionI18n)) return [];
    return [{
      id,
      descriptionI18n: row.descriptionI18n,
      exampleI18n: isTriText(row.exampleI18n) ? row.exampleI18n : null,
    }];
  });
};

const main = async (): Promise<void> => {
  const inputPath = readInputPath();
  const raw = JSON.parse(fs.readFileSync(inputPath, 'utf8')) as unknown;
  const rows = normalizeRows(raw);
  if (!rows.length) throw new Error(`No valid translation rows in ${inputPath}`);

  let updated = 0;
  for (const row of rows) {
    await prisma.genre.update({
      where: { id: row.id },
      data: {
        description: row.descriptionI18n.en,
        descriptionI18n: row.descriptionI18n as unknown as Prisma.InputJsonValue,
        example: row.exampleI18n?.en || null,
        exampleI18n: row.exampleI18n
          ? row.exampleI18n as unknown as Prisma.InputJsonValue
          : Prisma.DbNull,
      },
    });
    updated += 1;
  }

  console.log(`Applied ${updated} genre i18n translations from ${inputPath}`);
};

main()
  .catch((error) => {
    console.error('Apply genre i18n translations failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
