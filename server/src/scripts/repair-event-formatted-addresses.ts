import 'dotenv/config';
import { Prisma, PrismaClient } from '@prisma/client';

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

type JsonRecord = Record<string, unknown>;

type EventAddressAuditRow = {
  id: string;
  name: string;
  city: string | null;
  country: string | null;
  cityI18n: Prisma.JsonValue | null;
  countryI18n: Prisma.JsonValue | null;
  manualLocation: Prisma.JsonValue | null;
  locationPoint: Prisma.JsonValue | null;
};

type RepairCandidate = {
  event: EventAddressAuditRow;
  currentManualLocation: JsonRecord | null;
  currentLocationPoint: JsonRecord | null;
  nextManualFormatted: EventBiText | null;
  nextLocationPointManualSet: EventBiText | null;
  reasons: string[];
};

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

const asRecord = (value: unknown): JsonRecord | null =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? value as JsonRecord
    : null;

const normalizeBiText = (value: unknown): EventBiText | null => {
  const record = asRecord(value);
  if (!record) return null;
  const normalized: EventBiText = {
    en: cleanText(record.en),
    zh: cleanText(record.zh),
    ja: cleanText(record.ja),
    enFull: cleanText(record.enFull),
  };
  return normalized.en || normalized.zh || normalized.ja || normalized.enFull ? normalized : null;
};

const joinParts = (parts: Array<string | null | undefined>): string | null => {
  const values = parts.map((part) => cleanText(part)).filter((value): value is string => Boolean(value));
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

const equalBiText = (lhs: EventBiText | null, rhs: EventBiText | null): boolean => {
  const left = {
    zh: cleanText(lhs?.zh),
    en: cleanText(lhs?.en),
    ja: cleanText(lhs?.ja),
    enFull: cleanText(lhs?.enFull),
  };
  const right = {
    zh: cleanText(rhs?.zh),
    en: cleanText(rhs?.en),
    ja: cleanText(rhs?.ja),
    enFull: cleanText(rhs?.enFull),
  };
  return left.zh === right.zh
    && left.en === right.en
    && left.ja === right.ja
    && left.enFull === right.enFull;
};

const main = async (): Promise<void> => {
  const where: Prisma.EventWhereInput = {
    OR: [
      { manualLocation: { not: Prisma.JsonNull } },
      { locationPoint: { not: Prisma.JsonNull } },
    ],
    ...(targetIds.length > 0 ? { id: { in: targetIds } } : {}),
  };

  const events = await prisma.event.findMany({
    where,
    select: {
      id: true,
      name: true,
      city: true,
      country: true,
      cityI18n: true,
      countryI18n: true,
      manualLocation: true,
      locationPoint: true,
    },
    orderBy: [{ startDate: 'desc' }, { id: 'desc' }],
  });

  const candidates: RepairCandidate[] = events.flatMap((event) => {
    const currentManualLocation = asRecord(event.manualLocation);
    const currentLocationPoint = asRecord(event.locationPoint);

    const city = normalizeBiText(event.cityI18n)
      ?? (cleanText(event.city) ? { en: cleanText(event.city), zh: cleanText(event.city) } : null);
    const country = normalizeBiText(event.countryI18n)
      ?? (cleanText(event.country) ? { en: cleanText(event.country), zh: cleanText(event.country) } : null);

    const manualDetail = normalizeBiText(currentManualLocation?.detailAddressI18n);
    const manualFormatted = normalizeBiText(currentManualLocation?.formattedAddressI18n);
    const nextManualFormatted = manualDetail
      ? buildFormattedAddress(manualDetail, city, country)
      : null;

    const pointManualSet = normalizeBiText(currentLocationPoint?.manualSetAddressI18n);
    const pointFormatted = normalizeBiText(currentLocationPoint?.formattedAddressI18n);
    const nextLocationPointManualSet = currentLocationPoint
      ? (nextManualFormatted ?? pointFormatted ?? manualDetail)
      : null;

    const reasons: string[] = [];
    if (manualDetail && nextManualFormatted && !equalBiText(manualFormatted, nextManualFormatted)) {
      reasons.push('repair-manual-formatted-address');
    }
    if (currentLocationPoint && nextLocationPointManualSet && !equalBiText(pointManualSet, nextLocationPointManualSet)) {
      reasons.push('repair-location-point-manual-set-address');
    }

    if (reasons.length === 0) return [];

    return [{
      event,
      currentManualLocation,
      currentLocationPoint,
      nextManualFormatted,
      nextLocationPointManualSet,
      reasons,
    }];
  });

  console.log(JSON.stringify({
    apply,
    targetIds,
    scanned: events.length,
    repairable: candidates.length,
    items: candidates.map((candidate) => ({
      id: candidate.event.id,
      name: candidate.event.name,
      city: candidate.event.city,
      country: candidate.event.country,
      reasons: candidate.reasons,
      currentManualDetail: normalizeBiText(candidate.currentManualLocation?.detailAddressI18n),
      currentManualFormatted: normalizeBiText(candidate.currentManualLocation?.formattedAddressI18n),
      nextManualFormatted: candidate.nextManualFormatted,
      currentPointManualSet: normalizeBiText(candidate.currentLocationPoint?.manualSetAddressI18n),
      nextPointManualSet: candidate.nextLocationPointManualSet,
    })),
  }, null, 2));

  if (!apply || candidates.length === 0) return;

  for (const candidate of candidates) {
    const data: Prisma.EventUpdateInput = {};

    if (candidate.nextManualFormatted) {
      data.manualLocation = {
        ...((candidate.currentManualLocation ?? {}) as Prisma.JsonObject),
        formattedAddressI18n: candidate.nextManualFormatted as Prisma.JsonObject,
      };
    }

    if (candidate.currentLocationPoint && candidate.nextLocationPointManualSet) {
      data.locationPoint = {
        ...(candidate.currentLocationPoint as Prisma.JsonObject),
        manualSetAddressI18n: candidate.nextLocationPointManualSet as Prisma.JsonObject,
      };
    }

    await prisma.event.update({
      where: { id: candidate.event.id },
      data,
    });
  }

  console.log(JSON.stringify({
    updated: candidates.length,
    ids: candidates.map((candidate) => candidate.event.id),
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
