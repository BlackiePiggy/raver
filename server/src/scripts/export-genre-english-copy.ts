import 'dotenv/config';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type LocalizedText = {
  en?: string | null;
  zh?: string | null;
  ja?: string | null;
};

const cleanText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const pickEnglishText = (i18n: unknown, fallback: unknown): string => {
  if (i18n && typeof i18n === 'object' && !Array.isArray(i18n)) {
    const candidate = cleanText((i18n as LocalizedText).en);
    if (candidate) return candidate;
  }
  return cleanText(fallback);
};

async function main() {
  const rows = await prisma.genre.findMany({
    orderBy: [{ path: 'asc' }],
    select: {
      id: true,
      slug: true,
      name: true,
      path: true,
      description: true,
      descriptionI18n: true,
      example: true,
      exampleI18n: true,
      parentId: true,
      sortOrder: true,
    },
  });

  const exportedAt = new Date().toISOString();
  const items = rows.map((row) => ({
    id: row.id,
    slug: row.slug,
    name: row.name,
    path: row.path,
    parentId: row.parentId,
    sortOrder: row.sortOrder,
    descriptionEn: pickEnglishText(row.descriptionI18n, row.description),
    exampleEn: pickEnglishText(row.exampleI18n, row.example),
  }));

  const payload = {
    exportedAt,
    total: items.length,
    items,
  };

  const outputDir = path.resolve(process.cwd(), 'prisma/genre-i18n-translated');
  const outputPath = path.join(outputDir, 'genre-english-copy.json');
  await mkdir(outputDir, { recursive: true });
  await writeFile(outputPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');

  console.log(`Exported ${items.length} genres to ${outputPath}`);
}

main()
  .catch((error) => {
    console.error('[export-genre-english-copy] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
