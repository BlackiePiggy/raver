import { Prisma, PrismaClient } from '@prisma/client';
import { normalizeCountryBiTextPayload } from '../src/utils/country-i18n';

const prisma = new PrismaClient();

type CountryLike = {
  en?: unknown;
  zh?: unknown;
  enFull?: unknown;
  en_full?: unknown;
  englishFull?: unknown;
  country_en_full?: unknown;
};

type RowPatch = {
  id: string;
  country: string;
  before: CountryLike | null;
  after: CountryLike;
};

const normalizeText = (value: unknown): string => {
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
    const text = String(value).trim();
    if (!text) return '';
    if (/^\[object\s+object\]$/i.test(text)) return '';
    return text;
  }
  return '';
};

const parseCountryLike = (value: unknown): CountryLike | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const row = value as Record<string, unknown>;
  return {
    en: normalizeText(row.en ?? row.EN ?? row.english ?? row.name_en ?? ''),
    zh: normalizeText(row.zh ?? row.ZH ?? row.chinese ?? row.cn ?? row.name_zh ?? ''),
    enFull: normalizeText(row.enFull ?? row.en_full ?? row.englishFull ?? row.country_en_full ?? ''),
  };
};

const pickText = (...values: unknown[]): string => {
  for (const value of values) {
    const text = normalizeText(value);
    if (text) return text;
  }
  return '';
};

const buildTargetCountryI18n = (value: unknown, fallbackCountry: string): CountryLike | null => {
  const existing = parseCountryLike(value);
  const normalized = normalizeCountryBiTextPayload(value ?? null, fallbackCountry);
  if (!existing && !normalized) return null;

  const en = pickText(existing?.en, normalized?.en);
  const zh = pickText(existing?.zh, normalized?.zh);
  const enFull = pickText(
    existing?.enFull,
    existing?.en_full,
    existing?.englishFull,
    existing?.country_en_full,
    normalized?.enFull
  );

  const finalEn = en || zh;
  const finalZh = zh || en;
  if (!finalEn && !finalZh && !enFull) return null;

  return {
    ...(finalEn ? { en: finalEn } : {}),
    ...(finalZh ? { zh: finalZh } : {}),
    ...(enFull ? { enFull } : {}),
  };
};

const sameCountryLike = (left: CountryLike | null, right: CountryLike): boolean => {
  if (!left) return false;
  const leftEn = normalizeText(left.en);
  const leftZh = normalizeText(left.zh);
  const leftEnFull = normalizeText(left.enFull ?? left.en_full ?? left.englishFull ?? left.country_en_full ?? '');
  const rightEn = normalizeText(right.en);
  const rightZh = normalizeText(right.zh);
  const rightEnFull = normalizeText(right.enFull ?? right.en_full ?? right.englishFull ?? right.country_en_full ?? '');
  return leftEn === rightEn && leftZh === rightZh && leftEnFull === rightEnFull;
};

const toInputJson = (value: CountryLike): Prisma.InputJsonValue =>
  value as unknown as Prisma.InputJsonValue;

async function scanEvents(): Promise<RowPatch[]> {
  const rows = await prisma.event.findMany({
    select: { id: true, country: true, countryI18n: true },
  });
  const patches: RowPatch[] = [];
  for (const row of rows) {
    const before = parseCountryLike(row.countryI18n);
    const after = buildTargetCountryI18n(row.countryI18n ?? null, row.country ?? '');
    if (!after) continue;
    if (sameCountryLike(before, after)) continue;
    patches.push({ id: row.id, country: row.country ?? '', before, after });
  }
  return patches;
}

async function scanDJs(): Promise<RowPatch[]> {
  const rows = await prisma.dJ.findMany({
    select: { id: true, country: true, countryI18n: true },
  });
  const patches: RowPatch[] = [];
  for (const row of rows) {
    const before = parseCountryLike(row.countryI18n);
    const after = buildTargetCountryI18n(row.countryI18n ?? null, row.country ?? '');
    if (!after) continue;
    if (sameCountryLike(before, after)) continue;
    patches.push({ id: row.id, country: row.country ?? '', before, after });
  }
  return patches;
}

async function scanWikiFestivals(): Promise<RowPatch[]> {
  const rows = await prisma.wikiFestival.findMany({
    select: { id: true, country: true, countryI18n: true },
  });
  const patches: RowPatch[] = [];
  for (const row of rows) {
    const before = parseCountryLike(row.countryI18n);
    const after = buildTargetCountryI18n(row.countryI18n ?? null, row.country ?? '');
    if (!after) continue;
    if (sameCountryLike(before, after)) continue;
    patches.push({ id: row.id, country: row.country ?? '', before, after });
  }
  return patches;
}

async function applyEvents(patches: RowPatch[]) {
  for (const patch of patches) {
    await prisma.event.update({
      where: { id: patch.id },
      data: { countryI18n: toInputJson(patch.after) },
    });
  }
}

async function applyDJs(patches: RowPatch[]) {
  for (const patch of patches) {
    await prisma.dJ.update({
      where: { id: patch.id },
      data: { countryI18n: toInputJson(patch.after) },
    });
  }
}

async function applyWikiFestivals(patches: RowPatch[]) {
  for (const patch of patches) {
    await prisma.wikiFestival.update({
      where: { id: patch.id },
      data: { countryI18n: toInputJson(patch.after) },
    });
  }
}

function printPreview(title: string, patches: RowPatch[]) {
  console.log(`${title}: ${patches.length}`);
  for (const patch of patches.slice(0, 8)) {
    console.log(
      `[${patch.id}] country="${patch.country}" before=${JSON.stringify(patch.before)} after=${JSON.stringify(patch.after)}`
    );
  }
}

async function main() {
  const apply = process.argv.includes('--apply');

  const [eventPatches, djPatches, wikiPatches] = await Promise.all([
    scanEvents(),
    scanDJs(),
    scanWikiFestivals(),
  ]);

  console.log('Country enFull backfill scan completed.');
  printPreview('Event patches', eventPatches);
  printPreview('DJ patches', djPatches);
  printPreview('WikiFestival patches', wikiPatches);

  const total = eventPatches.length + djPatches.length + wikiPatches.length;
  console.log(`Total patches: ${total}`);

  if (!apply) {
    console.log('Dry-run only. Add --apply to persist updates.');
    return;
  }

  await applyEvents(eventPatches);
  await applyDJs(djPatches);
  await applyWikiFestivals(wikiPatches);
  console.log('Backfill applied successfully.');
}

main()
  .catch((error) => {
    console.error('Backfill failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
