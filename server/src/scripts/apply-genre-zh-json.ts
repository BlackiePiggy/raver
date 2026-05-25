import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import path from 'node:path';

import { Prisma, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type TriText = {
  en?: string | null;
  zh?: string | null;
  ja?: string | null;
};

type InputItem = {
  id: string;
  descriptionZh: string;
};

const safeText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const readInputPath = (): string => {
  const argIndex = process.argv.findIndex((arg) => arg === '--input' || arg === '-i');
  if (argIndex >= 0 && process.argv[argIndex + 1]) return path.resolve(process.argv[argIndex + 1]);
  throw new Error('Missing required --input <json-file-path>');
};

const normalizeItems = (raw: unknown): InputItem[] => {
  const items: unknown[] =
    raw && typeof raw === 'object' && Array.isArray((raw as Record<string, unknown>).items)
      ? ((raw as Record<string, unknown>).items as unknown[])
      : [];

  return items.flatMap((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) return [];
    const row = item as Record<string, unknown>;
    const id = safeText(row.id);
    const descriptionZh = safeText(row.descriptionZh);
    if (!id || !descriptionZh) return [];
    return [{ id, descriptionZh }];
  });
};

async function main() {
  const inputPath = readInputPath();
  const raw = JSON.parse(await readFile(inputPath, 'utf8')) as unknown;
  const items = normalizeItems(raw);
  if (!items.length) {
    throw new Error(`No valid rows found in ${inputPath}`);
  }

  const genres = await prisma.genre.findMany({
    orderBy: [{ path: 'asc' }],
    select: {
      id: true,
      descriptionI18n: true,
    },
  });

  const itemMap = new Map(items.map((item) => [item.id, item.descriptionZh]));
  const missing = genres.filter((genre) => !itemMap.has(genre.id)).map((genre) => genre.id);
  if (missing.length) {
    throw new Error(`Input is missing ${missing.length} genre ids, e.g. ${missing.slice(0, 10).join(', ')}`);
  }

  const updates = genres.map((genre) => {
    const current =
      genre.descriptionI18n && typeof genre.descriptionI18n === 'object' && !Array.isArray(genre.descriptionI18n)
        ? (genre.descriptionI18n as TriText)
        : {};

    const next: TriText = {
      en: safeText(current.en),
      zh: itemMap.get(genre.id) ?? '',
      ja: safeText(current.ja),
    };

    return prisma.genre.update({
      where: { id: genre.id },
      data: {
        descriptionI18n: next as unknown as Prisma.InputJsonValue,
      },
    });
  });

  await prisma.$transaction(updates);

  console.log(`Updated zh descriptions for ${updates.length} genres from ${inputPath}`);
}

main()
  .catch((error) => {
    console.error('[apply-genre-zh-json] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
