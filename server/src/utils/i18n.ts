import { Prisma } from '@prisma/client';

export type TriTextPayload = {
  en: string;
  zh: string;
  ja?: string;
  enFull?: string;
};

const normalizeText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  const text = value.trim();
  if (!text) return '';
  if (/^\[object\s+object\]$/i.test(text)) return '';
  return text;
};

export const normalizeTriTextPayload = (value: unknown, fallback = ''): TriTextPayload | null => {
  const fallbackText = normalizeText(fallback);
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    const row = value as Record<string, unknown>;
    const en = normalizeText(row.en ?? row.EN ?? row.english) || fallbackText;
    const zh = normalizeText(row.zh ?? row.ZH ?? row.cn ?? row.chinese) || en || fallbackText;
    const ja = normalizeText(row.ja ?? row.JA ?? row.jp ?? row.japanese);
    const enFull = normalizeText(
      row.enFull ?? row.en_full ?? row.englishFull ?? row.country_en_full
    );
    const normalizedEn = en || zh || fallbackText;
    const normalizedZh = zh || en || fallbackText;
    if (!normalizedEn && !normalizedZh) return null;
    const out: TriTextPayload = {
      en: normalizedEn,
      zh: normalizedZh,
      ja: ja || normalizedEn || normalizedZh || fallbackText,
    };
    if (enFull) out.enFull = enFull;
    return out;
  }

  const plain = normalizeText(value) || fallbackText;
  if (!plain) return null;
  return {
    en: plain,
    zh: plain,
    ja: plain,
  };
};

export const resolveTriTextWithFallback = (value: unknown, fallback = ''): TriTextPayload | null =>
  normalizeTriTextPayload(value, fallback);

export const triTextToJson = (value: TriTextPayload | null): Prisma.InputJsonValue | undefined =>
  value ? (value as unknown as Prisma.InputJsonValue) : undefined;

export type LocaleFallback = 'ja' | 'en' | 'zh';

export const resolveLocalizedText = (
  value: unknown,
  fallback = '',
  order: LocaleFallback[] = ['ja', 'en', 'zh']
): string => {
  const normalized = normalizeTriTextPayload(value, fallback);
  if (!normalized) return normalizeText(fallback);

  for (const locale of order) {
    const text = normalizeText(normalized[locale]);
    if (text) return text;
  }
  return normalizeText(fallback);
};

export type I18nCompletenessField = {
  field: string;
  missingLocales: LocaleFallback[];
};

export type I18nCompletenessReport = {
  requiredLocales: LocaleFallback[];
  missingLocales: LocaleFallback[];
  fields: I18nCompletenessField[];
  autoTranslated: boolean;
  manuallyConfirmed: boolean;
  status: 'ready' | 'missing_ja' | 'needs_manual_confirmation';
};

const readRecordValue = (value: unknown, key: string): unknown => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return undefined;
  return (value as Record<string, unknown>)[key];
};

const hasLocaleText = (value: unknown, locale: LocaleFallback): boolean => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const row = value as Record<string, unknown>;
  if (locale === 'zh') {
    return Boolean(normalizeText(row.zh ?? row['zh-CN'] ?? row.cn ?? row.chinese));
  }
  if (locale === 'ja') {
    return Boolean(normalizeText(row.ja ?? row['ja-JP'] ?? row.jp ?? row.japanese));
  }
  return Boolean(normalizeText(row.en ?? row['en-US'] ?? row.english));
};

export const analyzeI18nCompleteness = (
  payload: unknown,
  fieldKeys: string[],
  requiredLocales: LocaleFallback[] = ['zh', 'en', 'ja']
): I18nCompletenessReport => {
  const fields = fieldKeys
    .map((field) => {
      const value = readRecordValue(payload, field);
      const missingLocales = requiredLocales.filter((locale) => !hasLocaleText(value, locale));
      return { field, missingLocales };
    })
    .filter((item) => item.missingLocales.length > 0);

  const translationMeta = readRecordValue(payload, 'translationMeta');
  const autoTranslated =
    readRecordValue(payload, 'autoTranslated') === true ||
    readRecordValue(translationMeta, 'autoTranslated') === true ||
    readRecordValue(translationMeta, 'source') === 'machine';
  const manuallyConfirmed =
    readRecordValue(payload, 'translationManuallyConfirmed') === true ||
    readRecordValue(translationMeta, 'manuallyConfirmed') === true ||
    readRecordValue(translationMeta, 'status') === 'manually_confirmed';

  const missingLocales = Array.from(new Set(fields.flatMap((item) => item.missingLocales)));
  const status =
    missingLocales.includes('ja')
      ? 'missing_ja'
      : autoTranslated && !manuallyConfirmed
        ? 'needs_manual_confirmation'
        : 'ready';

  return {
    requiredLocales,
    missingLocales,
    fields,
    autoTranslated,
    manuallyConfirmed,
    status,
  };
};
