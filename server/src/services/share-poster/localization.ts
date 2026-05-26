import { SharePosterLocale } from './types';

export const normalizeText = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  return normalized ? normalized : null;
};

export const singleLine = (value: string | null | undefined): string =>
  String(value || '')
    .replace(/\s+/g, ' ')
    .trim();

export const posterText = (value: string | null | undefined, fallback: string): string => {
  const normalized = singleLine(value);
  return normalized || fallback;
};

export const excerpt = (value: string | null | undefined, maxLength = 120): string => {
  const normalized = singleLine(value);
  if (!normalized) return '';
  if (normalized.length <= maxLength) return normalized;
  return `${normalized.slice(0, maxLength - 1)}…`;
};

export const normalizePosterVariant = (value: unknown): string | null => {
  const normalized = singleLine(typeof value === 'string' ? value : '').toLowerCase();
  return normalized || null;
};

export const normalizePosterLocale = (
  localeInput: unknown,
  acceptLanguage: string | string[] | undefined
): SharePosterLocale => {
  const localeRaw = String(localeInput || '').trim().toLowerCase();
  if (localeRaw.startsWith('zh')) return 'zh';
  if (localeRaw.startsWith('en')) return 'en';
  const raw = Array.isArray(acceptLanguage) ? acceptLanguage.join(',') : String(acceptLanguage || '');
  return raw.trim().toLowerCase().startsWith('zh') ? 'zh' : 'en';
};

export const localizedValueFromRecord = (
  record: Record<string, unknown>,
  locale: SharePosterLocale
): string | null => {
  const keysByLocale: Record<SharePosterLocale, string[]> = {
    zh: ['zh', 'zh-CN', 'zh-Hans', 'zh_CN', 'zh_Hans'],
    en: ['enFull', 'en', 'en-US', 'en_US'],
  };
  const fallbackKeys = ['zh', 'enFull', 'en', 'ja'];
  for (const key of [...keysByLocale[locale], ...fallbackKeys]) {
    const text = normalizeText(record[key]);
    if (text) return text;
  }
  return null;
};

export const pickLocalizedText = (
  value: unknown,
  locale: SharePosterLocale,
  fallback?: string | null
): string | null => {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return localizedValueFromRecord(value as Record<string, unknown>, locale) ?? normalizeText(fallback);
  }
  return normalizeText(fallback);
};

export const formatPosterVenueText = (value: string): string =>
  String(value || '')
    .replace(/\s*,\s*/g, ', ')
    .replace(/\s+/g, ' ')
    .trim();

const readLocalizedAddressText = (
  value: unknown,
  field: 'formattedAddressI18n' | 'detailAddressI18n',
  locale: SharePosterLocale
): string | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const source = (value as Record<string, unknown>)[field];
  if (!source || typeof source !== 'object' || Array.isArray(source)) return null;
  return localizedValueFromRecord(source as Record<string, unknown>, locale);
};

export const resolvePosterVenueText = (
  event: {
    city?: string | null;
    country?: string | null;
    cityI18n?: unknown;
    countryI18n?: unknown;
    manualLocation?: unknown;
    locationPoint?: unknown;
  },
  locale: SharePosterLocale
): string | null => {
  const cityText = pickLocalizedText(event.cityI18n, locale, event.city);
  const countryText = pickLocalizedText(event.countryI18n, locale, event.country);
  const unified = readLocalizedAddressText(event.manualLocation, 'formattedAddressI18n', locale)
    ?? readLocalizedAddressText(event.locationPoint, 'formattedAddressI18n', locale)
    ?? readLocalizedAddressText(event.manualLocation, 'detailAddressI18n', locale)
    ?? cityText
    ?? countryText;
  return unified ? formatPosterVenueText(unified) : null;
};

export const readShareLinkPosterVariant = (metadata: unknown): string | null => {
  if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) return null;
  const record = metadata as Record<string, unknown>;
  return normalizePosterVariant(record.posterVariant ?? record.posterKind ?? record.variant);
};
