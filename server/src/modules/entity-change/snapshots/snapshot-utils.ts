import { Prisma } from '@prisma/client';
import crypto from 'crypto';

export const dateToIso = (value: Date | string | null | undefined): string | null => {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
};

export const dateToDateKey = (value: Date | string | null | undefined): string | null => {
  const iso = dateToIso(value);
  return iso ? iso.slice(0, 10) : null;
};

export const decimalToString = (value: Prisma.Decimal | number | string | null | undefined): string | null => {
  if (value === null || value === undefined) return null;
  if (value instanceof Prisma.Decimal) return value.toString();
  return String(value);
};

export const normalizeJson = (value: unknown): unknown => {
  if (value === Prisma.JsonNull || value === Prisma.DbNull || value === Prisma.AnyNull) return null;
  if (value instanceof Date) return value.toISOString();
  if (value instanceof Prisma.Decimal) return value.toString();
  if (Array.isArray(value)) return value.map(normalizeJson);
  if (value && typeof value === 'object') {
    const row = value as Record<string, unknown>;
    const result: Record<string, unknown> = {};
    for (const key of Object.keys(row).sort()) {
      result[key] = normalizeJson(row[key]);
    }
    return result;
  }
  return value ?? null;
};

export const sortedStrings = (values: string[] | null | undefined): string[] =>
  Array.from(new Set((values ?? []).map((item) => item.trim()).filter(Boolean))).sort((a, b) =>
    a.localeCompare(b, 'en', { sensitivity: 'base' })
  );

export const textPreview = (value: string | null | undefined, limit = 180): string | null => {
  const normalized = (value || '').trim().replace(/\s+/g, ' ');
  if (!normalized) return null;
  return normalized.length > limit ? `${normalized.slice(0, Math.max(0, limit - 3))}...` : normalized;
};

export const textHash = (value: string | null | undefined): string | null => {
  const normalized = (value || '').trim().replace(/\s+/g, ' ');
  if (!normalized) return null;
  return crypto.createHash('sha256').update(normalized).digest('hex');
};
