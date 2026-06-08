import { Prisma } from '@prisma/client';

const normalizeText = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
};

const readJsonString = (value: unknown, keys: string[]): string | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  let current: unknown = value;
  for (const key of keys) {
    if (!current || typeof current !== 'object' || Array.isArray(current)) return null;
    current = (current as Record<string, unknown>)[key];
  }
  return normalizeText(current);
};

export const readLocalizedJsonString = (value: unknown, keys: string[]): string | null =>
  readJsonString(value, [...keys, 'zhHans'])
  ?? readJsonString(value, [...keys, 'zh-Hans'])
  ?? readJsonString(value, [...keys, 'zh'])
  ?? readJsonString(value, [...keys, 'en'])
  ?? readJsonString(value, keys);

export const compactUniqueTextParts = (parts: Array<string | null | undefined>): string[] => {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const part of parts) {
    const normalized = normalizeText(part);
    if (!normalized) continue;
    const key = normalized.toLocaleLowerCase('zh-Hans-CN');
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(normalized);
  }
  return result;
};

export const resolveEventActivityAddressText = (event: {
  manualLocation?: Prisma.JsonValue | null;
} | null | undefined): string | null => {
  if (!event) return null;
  return readLocalizedJsonString(event.manualLocation, ['formattedAddressI18n']);
};

export const resolveEventVenueDisplayAddressText = (event: {
  manualLocation?: Prisma.JsonValue | null;
  locationPoint?: Prisma.JsonValue | null;
} | null | undefined): string | null => {
  if (!event) return null;
  if (event.locationPoint) {
    return (
      readLocalizedJsonString(event.locationPoint, ['manualSetAddressI18n'])
      ?? readLocalizedJsonString(event.locationPoint, ['formattedAddressI18n'])
    );
  }

  return (
    readLocalizedJsonString(event.manualLocation, ['formattedAddressI18n'])
    ?? readLocalizedJsonString(event.manualLocation, ['detailAddressI18n'])
  );
};

export const resolveEventAddressText = (event: {
  manualLocation?: Prisma.JsonValue | null;
  locationPoint?: Prisma.JsonValue | null;
  city?: string | null;
  country?: string | null;
} | null | undefined): string | null => {
  if (!event) return null;
  return resolveEventVenueDisplayAddressText(event);
};
