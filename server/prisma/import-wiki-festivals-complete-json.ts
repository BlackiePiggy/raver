import 'dotenv/config';

import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';

import { PrismaClient, Prisma } from '@prisma/client';

type BiText = {
  zh: string;
  en: string;
};

type FestivalCompleteRow = {
  id?: number | string | null;
  name_cn?: string | null;
  name_en?: string | null;
  abbreviation?: string | null;
  description_cn?: string | null;
  description_en?: string | null;
  city_cn?: string | null;
  city_en?: string | null;
  country_cn?: string | null;
  country_en?: string | null;
  year_founded?: string | number | null;
  frequency_cn?: string | null;
  frequency_en?: string | null;
  official_website?: string | null;
  facebook?: string | null;
  instagram?: string | null;
  twitter?: string | null;
  youtube?: string | null;
  tiktok?: string | null;
};

type LinkPayload = {
  title: string;
  icon: string;
  url: string;
};

const prisma = new PrismaClient();

const INPUT_JSON = path.resolve(
  process.env.WIKI_FESTIVALS_COMPLETE_JSON || path.join(process.cwd(), '..', 'docs', 'festivals_complete.json')
);

const DRY_RUN = ['1', 'true', 'yes'].includes(String(process.env.WIKI_FESTIVALS_COMPLETE_DRY_RUN || '').trim().toLowerCase());

function normalizeText(value: unknown): string {
  if (typeof value !== 'string') return '';
  return value.trim();
}

function normalizeInteger(value: unknown): number | null {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  return Math.trunc(parsed);
}

function normalizeNameKey(value: string): string {
  return normalizeText(value)
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]/g, '');
}

function normalizeBiText(zhValue: unknown, enValue: unknown): BiText | null {
  const zh = normalizeText(zhValue);
  const en = normalizeText(enValue);
  const normalizedZh = zh || en;
  const normalizedEn = en || zh;
  if (!normalizedZh && !normalizedEn) return null;
  return {
    zh: normalizedZh,
    en: normalizedEn,
  };
}

function pickPrimaryText(value: BiText | null, fallback = ''): string {
  const fallbackText = normalizeText(fallback);
  if (!value) return fallbackText;
  return normalizeText(value.zh) || normalizeText(value.en) || fallbackText;
}

function splitAbbreviation(value: string): string[] {
  return value
    .split(/[,\uFF0C\/\u3001|]/g)
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

function mergeAliases(name: string, ...values: Array<string | null | undefined>): string[] {
  const baseKey = normalizeNameKey(name);
  const seen = new Set<string>();
  const result: string[] = [];
  const push = (raw: string | null | undefined): void => {
    const text = normalizeText(raw);
    if (!text) return;
    const key = normalizeNameKey(text);
    if (!key || key === baseKey || seen.has(key)) return;
    seen.add(key);
    result.push(text);
  };

  for (const value of values) {
    if (!value) continue;
    if (value.includes(',') || value.includes('，') || value.includes('/')) {
      for (const part of splitAbbreviation(value)) push(part);
    } else {
      push(value);
    }
  }
  return result;
}

function slugifyFestivalId(value: string, fallback: string): string {
  const slug = normalizeText(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return slug || fallback;
}

function parseRowId(value: unknown): number | null {
  const parsed = normalizeInteger(value);
  if (parsed === null || parsed <= 0) return null;
  return parsed;
}

function parseExistingBiText(value: unknown): BiText | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const row = value as Record<string, unknown>;
  return normalizeBiText(row.zh ?? row.cn ?? row.chinese, row.en ?? row.english);
}

function toNullableJsonInput(value: BiText | null): Prisma.InputJsonValue | Prisma.NullableJsonNullValueInput {
  return value ? (value as unknown as Prisma.InputJsonValue) : Prisma.DbNull;
}

function repairUnescapedQuotesInJson(input: string): string {
  let output = '';
  let inString = false;
  let escaped = false;

  for (let i = 0; i < input.length; i += 1) {
    const ch = input[i];
    if (!inString) {
      output += ch;
      if (ch === '"') {
        inString = true;
        escaped = false;
      }
      continue;
    }

    if (escaped) {
      output += ch;
      escaped = false;
      continue;
    }

    if (ch === '\\') {
      output += ch;
      escaped = true;
      continue;
    }

    if (ch === '"') {
      let j = i + 1;
      while (j < input.length && /\s/.test(input[j])) {
        j += 1;
      }
      const next = input[j] ?? '';
      const isClosing = next === '' || next === ',' || next === '}' || next === ']' || next === ':';
      if (isClosing) {
        output += ch;
        inString = false;
      } else {
        output += '\\"';
      }
      continue;
    }

    output += ch;
  }
  return output;
}

function buildLinks(row: FestivalCompleteRow): LinkPayload[] {
  const links: LinkPayload[] = [];
  const seen = new Set<string>();
  const push = (title: string, icon: string, rawUrl: unknown): void => {
    const url = normalizeText(rawUrl);
    if (!url) return;
    const key = url.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    links.push({ title, icon, url });
  };

  push('Official', 'globe', row.official_website);
  push('Facebook', 'f.square', row.facebook);
  push('Instagram', 'camera', row.instagram);
  push('X / Twitter', 'bird', row.twitter);
  push('YouTube', 'play.rectangle', row.youtube);
  push('TikTok', 'music.note', row.tiktok);
  return links;
}

async function ensureContributor(festivalId: string, userId: string | null): Promise<void> {
  if (!userId) return;
  await prisma.wikiFestivalContributor.upsert({
    where: {
      festivalId_userId: {
        festivalId,
        userId,
      },
    },
    create: {
      id: randomUUID(),
      festivalId,
      userId,
    },
    update: {},
  });
}

async function main(): Promise<void> {
  if (!fs.existsSync(INPUT_JSON)) {
    throw new Error(`Input JSON not found: ${INPUT_JSON}`);
  }

  const rawText = fs.readFileSync(INPUT_JSON, 'utf8');
  let parsed: unknown;
  try {
    parsed = JSON.parse(rawText);
  } catch (_error) {
    const repaired = repairUnescapedQuotesInJson(rawText);
    parsed = JSON.parse(repaired);
    console.warn('[wiki-festivals-import] input JSON contained unescaped quotes, auto-repaired before parsing');
  }
  if (!Array.isArray(parsed)) {
    throw new Error('festivals_complete.json must be an array');
  }
  const rows = parsed as FestivalCompleteRow[];

  const existingRows = await prisma.wikiFestival.findMany({
    select: {
      id: true,
      sourceRowId: true,
      name: true,
      nameI18n: true,
      aliases: true,
      avatarUrl: true,
      backgroundUrl: true,
    },
  });

  const bySourceRowId = new Map<number, typeof existingRows[number]>();
  const byNameKey = new Map<string, typeof existingRows[number]>();
  const usedIds = new Set(existingRows.map((item) => item.id));

  for (const row of existingRows) {
    if (typeof row.sourceRowId === 'number') {
      bySourceRowId.set(row.sourceRowId, row);
    }
    const keys = new Set<string>();
    keys.add(normalizeNameKey(row.name));
    for (const alias of row.aliases || []) {
      keys.add(normalizeNameKey(alias));
    }
    const nameI18n = parseExistingBiText(row.nameI18n);
    if (nameI18n) {
      keys.add(normalizeNameKey(nameI18n.zh));
      keys.add(normalizeNameKey(nameI18n.en));
    }
    for (const key of keys) {
      if (!key) continue;
      if (!byNameKey.has(key)) {
        byNameKey.set(key, row);
      }
    }
  }

  const uploadtester = await prisma.user.findUnique({
    where: { username: 'uploadtester' },
    select: { id: true },
  });
  const contributorUserId = uploadtester?.id ?? null;

  let created = 0;
  let updated = 0;
  let skipped = 0;
  let errored = 0;

  console.log(`[wiki-festivals-import] start rows=${rows.length} input=${INPUT_JSON} dryRun=${DRY_RUN}`);

  for (let index = 0; index < rows.length; index += 1) {
    const row = rows[index];
    const sourceRowId = parseRowId(row.id);
    const nameI18n = normalizeBiText(row.name_cn, row.name_en);
    const name = pickPrimaryText(nameI18n);
    if (!name) {
      skipped += 1;
      console.warn(`[wiki-festivals-import] skip ${index + 1}/${rows.length}: empty name`);
      continue;
    }

    const candidateKeys = new Set<string>();
    candidateKeys.add(normalizeNameKey(name));
    if (nameI18n) {
      candidateKeys.add(normalizeNameKey(nameI18n.zh));
      candidateKeys.add(normalizeNameKey(nameI18n.en));
    }
    for (const alias of splitAbbreviation(normalizeText(row.abbreviation))) {
      candidateKeys.add(normalizeNameKey(alias));
    }

    let matched = sourceRowId !== null ? bySourceRowId.get(sourceRowId) ?? null : null;
    if (!matched) {
      for (const key of candidateKeys) {
        if (!key) continue;
        const target = byNameKey.get(key);
        if (target) {
          matched = target;
          break;
        }
      }
    }

    let targetId = matched?.id ?? '';
    if (!targetId) {
      const base = slugifyFestivalId(nameI18n?.en || name, `wiki-festival-${sourceRowId ?? index + 1}`);
      targetId = base;
      let seq = 2;
      while (usedIds.has(targetId)) {
        targetId = `${base}-${seq}`;
        seq += 1;
      }
      usedIds.add(targetId);
    }

    const countryI18n = normalizeBiText(row.country_cn, row.country_en);
    const cityI18n = normalizeBiText(row.city_cn, row.city_en);
    const frequencyI18n = normalizeBiText(row.frequency_cn, row.frequency_en);
    const descriptionI18n = normalizeBiText(row.description_cn, row.description_en);

    const country = pickPrimaryText(countryI18n);
    const city = pickPrimaryText(cityI18n);
    const frequency = pickPrimaryText(frequencyI18n);
    const introduction = pickPrimaryText(descriptionI18n);
    const foundedYear = normalizeText(row.year_founded === null || row.year_founded === undefined ? '' : String(row.year_founded));
    const abbreviation = normalizeText(row.abbreviation);
    const officialWebsite = normalizeText(row.official_website);
    const facebookUrl = normalizeText(row.facebook);
    const instagramUrl = normalizeText(row.instagram);
    const twitterUrl = normalizeText(row.twitter);
    const youtubeUrl = normalizeText(row.youtube);
    const tiktokUrl = normalizeText(row.tiktok);

    const aliases = mergeAliases(
      name,
      ...(matched?.aliases || []),
      nameI18n?.zh,
      nameI18n?.en,
      abbreviation
    );
    const links = buildLinks(row);

    const upsertData: Record<string, unknown> = {
      sourceRowId,
      name,
      nameI18n: toNullableJsonInput(nameI18n),
      abbreviation,
      aliases,
      country,
      countryI18n: toNullableJsonInput(countryI18n),
      city,
      cityI18n: toNullableJsonInput(cityI18n),
      foundedYear,
      frequency,
      frequencyI18n: toNullableJsonInput(frequencyI18n),
      tagline: '',
      introduction,
      descriptionI18n: toNullableJsonInput(descriptionI18n),
      officialWebsite: officialWebsite || null,
      facebookUrl: facebookUrl || null,
      instagramUrl: instagramUrl || null,
      twitterUrl: twitterUrl || null,
      youtubeUrl: youtubeUrl || null,
      tiktokUrl: tiktokUrl || null,
      links: links as unknown as Prisma.InputJsonValue,
      isActive: true,
    };

    try {
      if (!DRY_RUN) {
        await prisma.wikiFestival.upsert({
          where: { id: targetId },
          create: {
            ...upsertData,
            id: targetId,
            avatarUrl: matched?.avatarUrl ?? null,
            backgroundUrl: matched?.backgroundUrl ?? null,
          } as Prisma.WikiFestivalUncheckedCreateInput,
          update: {
            sourceRowId: upsertData.sourceRowId as number | null,
            name: upsertData.name as string,
            nameI18n: upsertData.nameI18n as Prisma.InputJsonValue | Prisma.NullableJsonNullValueInput,
            abbreviation: upsertData.abbreviation as string,
            aliases: upsertData.aliases as string[],
            country: upsertData.country as string,
            countryI18n: upsertData.countryI18n as Prisma.InputJsonValue | Prisma.NullableJsonNullValueInput,
            city: upsertData.city as string,
            cityI18n: upsertData.cityI18n as Prisma.InputJsonValue | Prisma.NullableJsonNullValueInput,
            foundedYear: upsertData.foundedYear as string,
            frequency: upsertData.frequency as string,
            frequencyI18n: upsertData.frequencyI18n as Prisma.InputJsonValue | Prisma.NullableJsonNullValueInput,
            introduction: upsertData.introduction as string,
            descriptionI18n: upsertData.descriptionI18n as Prisma.InputJsonValue | Prisma.NullableJsonNullValueInput,
            officialWebsite: upsertData.officialWebsite as string | null,
            facebookUrl: upsertData.facebookUrl as string | null,
            instagramUrl: upsertData.instagramUrl as string | null,
            twitterUrl: upsertData.twitterUrl as string | null,
            youtubeUrl: upsertData.youtubeUrl as string | null,
            tiktokUrl: upsertData.tiktokUrl as string | null,
            links: upsertData.links as Prisma.InputJsonValue,
            isActive: true,
          } as Prisma.WikiFestivalUncheckedUpdateInput,
        });
        await ensureContributor(targetId, contributorUserId);
      }

      if (matched) updated += 1;
      else created += 1;

      console.log(
        `[wiki-festivals-import] ${index + 1}/${rows.length} upsert id=${targetId} sourceRowId=${sourceRowId ?? 'null'} name=${name}`
      );
    } catch (error: any) {
      errored += 1;
      console.error(
        `[wiki-festivals-import] error ${index + 1}/${rows.length} id=${targetId} name=${name}: ${String(error?.message || error)}`
      );
    }
  }

  console.log(
    `[wiki-festivals-import] done created=${created} updated=${updated} skipped=${skipped} errored=${errored} dryRun=${DRY_RUN}`
  );
}

main()
  .catch((error) => {
    console.error('[wiki-festivals-import] fatal', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
