import 'dotenv/config';
import { PrismaClient, Prisma } from '@prisma/client';

const prisma = new PrismaClient({
  datasources: process.env.WORKER_DATABASE_URL
    ? {
        db: {
          url: process.env.WORKER_DATABASE_URL,
        },
      }
    : undefined,
});

type EventBiText = {
  en?: string | null;
  zh?: string | null;
  ja?: string | null;
  enFull?: string | null;
};

type EventLocationRecord = Record<string, unknown>;

const apply = process.argv.includes('--apply');
const targetIds = process.argv
  .filter((value) => !value.startsWith('--'))
  .slice(2)
  .map((value) => value.trim())
  .filter(Boolean);

const cleanText = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed || null;
};

const asRecord = (value: unknown): EventLocationRecord | null =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? value as EventLocationRecord
    : null;

const normalizeBiText = (value: unknown): EventBiText | null => {
  const record = asRecord(value);
  if (!record) return null;
  const text: EventBiText = {
    en: cleanText(record.en),
    zh: cleanText(record.zh),
    ja: cleanText(record.ja),
    enFull: cleanText(record.enFull),
  };
  return text.en || text.zh || text.ja || text.enFull ? text : null;
};

const joinParts = (parts: Array<string | null | undefined>): string | null => {
  const values = parts.map((value) => cleanText(value)).filter((value): value is string => Boolean(value));
  return values.length > 0 ? values.join(' · ') : null;
};

const buildFormattedAddress = (
  detail: EventBiText,
  city: EventBiText | null,
  country: EventBiText | null
): EventBiText => {
  const zh = joinParts([
    country?.zh ?? country?.en,
    city?.zh ?? city?.en,
    detail.zh ?? detail.en,
  ]);
  const en = joinParts([
    country?.enFull ?? country?.en ?? country?.zh,
    city?.en ?? city?.zh,
    detail.en ?? detail.zh,
  ]);
  const ja = joinParts([
    country?.ja ?? country?.enFull ?? country?.en ?? country?.zh,
    city?.ja ?? city?.en ?? city?.zh,
    detail.ja ?? detail.en ?? detail.zh,
  ]);
  return {
    zh: zh ?? detail.zh ?? detail.en ?? '',
    en: en ?? detail.en ?? detail.zh ?? '',
    ja: ja ?? detail.ja ?? undefined,
  };
};

const sameIgnoringCase = (lhs: string | null | undefined, rhs: string | null | undefined): boolean => {
  const left = cleanText(lhs)?.toLowerCase();
  const right = cleanText(rhs)?.toLowerCase();
  return Boolean(left && right && left === right);
};

const isDetailOnlyFormatted = (
  formatted: EventBiText | null,
  detail: EventBiText,
  city: EventBiText | null,
  country: EventBiText | null
): boolean => {
  const rawZh = cleanText(formatted?.zh);
  const rawEn = cleanText(formatted?.en);
  const detailZh = cleanText(detail.zh ?? detail.en);
  const detailEn = cleanText(detail.en ?? detail.zh);
  const hasCity = Boolean(cleanText(city?.zh ?? city?.en));
  const hasCountry = Boolean(cleanText(country?.zh ?? country?.en ?? country?.enFull));
  if (!hasCity || !hasCountry) return false;
  const zhMatchesDetail = rawZh && detailZh ? sameIgnoringCase(rawZh, detailZh) : false;
  const enMatchesDetail = rawEn && detailEn ? sameIgnoringCase(rawEn, detailEn) : false;
  const onlyZh = zhMatchesDetail && !rawEn;
  const onlyEn = enMatchesDetail && !rawZh;
  const bothMatchDetail = zhMatchesDetail && enMatchesDetail;
  return Boolean(onlyZh || onlyEn || bothMatchDetail);
};

const main = async (): Promise<void> => {
  const idFilterSql = targetIds.length > 0
    ? Prisma.sql`AND id = ANY(${targetIds})`
    : Prisma.empty;

  const events = await prisma.$queryRaw<Array<{
    id: string;
    name: string;
    city: string | null;
    country: string | null;
    cityI18n: Prisma.JsonValue | null;
    countryI18n: Prisma.JsonValue | null;
    manualLocation: Prisma.JsonValue | null;
    locationPoint: Prisma.JsonValue | null;
  }>>(Prisma.sql`
    SELECT
      id,
      name,
      city,
      country,
      city_i18n AS "cityI18n",
      country_i18n AS "countryI18n",
      manual_location AS "manualLocation",
      location_point AS "locationPoint"
    FROM events
    WHERE manual_location IS NOT NULL
      AND (
        NULLIF(TRIM(COALESCE(manual_location->'formattedAddressI18n'->>'zh', '')), '') IS NOT NULL
        OR NULLIF(TRIM(COALESCE(manual_location->'formattedAddressI18n'->>'en', '')), '') IS NOT NULL
      )
      AND (
        LOWER(TRIM(COALESCE(manual_location->'formattedAddressI18n'->>'zh', ''))) = LOWER(TRIM(COALESCE(manual_location->'detailAddressI18n'->>'zh', manual_location->'detailAddressI18n'->>'en', '')))
        OR LOWER(TRIM(COALESCE(manual_location->'formattedAddressI18n'->>'en', ''))) = LOWER(TRIM(COALESCE(manual_location->'detailAddressI18n'->>'en', manual_location->'detailAddressI18n'->>'zh', '')))
      )
      ${idFilterSql}
    ORDER BY start_date DESC, id DESC
  `);

  const candidates = events.flatMap((event) => {
    const manualLocation = asRecord(event.manualLocation);
    if (!manualLocation) return [];

    const detail = normalizeBiText(manualLocation.detailAddressI18n);
    if (!detail) return [];

    const formatted = normalizeBiText(manualLocation.formattedAddressI18n);
    const city = normalizeBiText(event.cityI18n) ?? (cleanText(event.city) ? { en: cleanText(event.city), zh: cleanText(event.city) } : null);
    const country = normalizeBiText(event.countryI18n) ?? (cleanText(event.country) ? { en: cleanText(event.country), zh: cleanText(event.country) } : null);
    if (!isDetailOnlyFormatted(formatted, detail, city, country)) return [];

    const nextFormatted = buildFormattedAddress(detail, city, country);
    return [{
      event,
      manualLocation,
      formatted,
      nextFormatted,
    }];
  });

  console.log(JSON.stringify({
    apply,
    targetIds,
    scanned: events.length,
    repairable: candidates.length,
    items: candidates.map(({ event, formatted, nextFormatted }) => ({
      id: event.id,
      name: event.name,
      city: event.city,
      country: event.country,
      currentFormatted: formatted,
      nextFormatted,
    })),
  }, null, 2));

  if (!apply || candidates.length === 0) return;

  for (const { event, manualLocation, nextFormatted } of candidates) {
    await prisma.event.update({
      where: { id: event.id },
      data: {
        manualLocation: {
          ...(manualLocation as Prisma.JsonObject),
          formattedAddressI18n: nextFormatted as Prisma.JsonObject,
        },
      },
    });
  }

  console.log(JSON.stringify({
    updated: candidates.length,
    ids: candidates.map(({ event }) => event.id),
  }, null, 2));
};

main()
  .catch((error) => {
    console.error('[repair-event-formatted-addresses] failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
