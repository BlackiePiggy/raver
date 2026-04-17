import fs from 'fs';
import path from 'path';

type CountryRow = {
  alpha2?: string;
  alpha3?: string;
  en?: string;
  zh?: string;
};

export type CountryBiTextPayload = {
  en: string;
  zh: string;
  enFull?: string;
};

type CountryRefData = {
  alpha3ToEn: Record<string, string>;
  lookup: Record<string, string>;
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

const normalizeCountryLookupKey = (value: unknown): string =>
  normalizeText(value)
    .toUpperCase()
    .replace(/[^A-Z0-9\u4E00-\u9FFF]+/g, '');

const loadCountryRefData = (): CountryRefData => {
  const candidates = [
    path.resolve(process.cwd(), '../scrapRave/country-codes-iso3166.json'),
    path.resolve(process.cwd(), 'scrapRave/country-codes-iso3166.json'),
    path.resolve(__dirname, '../../../scrapRave/country-codes-iso3166.json'),
  ];

  let rows: CountryRow[] = [];
  for (const filePath of candidates) {
    try {
      if (!fs.existsSync(filePath)) continue;
      const parsed = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      if (Array.isArray(parsed)) {
        rows = parsed as CountryRow[];
        break;
      }
    } catch {
      // Try next candidate.
    }
  }

  const alpha3ToEn: Record<string, string> = {};
  const lookup: Record<string, string> = {};

  for (const row of rows) {
    const alpha2 = normalizeText(row?.alpha2).toUpperCase();
    const alpha3 = normalizeText(row?.alpha3).toUpperCase();
    const en = normalizeText(row?.en);
    const zh = normalizeText(row?.zh);
    if (!alpha3) continue;
    if (en) alpha3ToEn[alpha3] = en;

    const tokens = [alpha2, alpha3, en, zh];
    for (const token of tokens) {
      const key = normalizeCountryLookupKey(token);
      if (!key || lookup[key]) continue;
      lookup[key] = alpha3;
    }
  }

  if (!lookup.UK) lookup.UK = 'GBR';
  if (!lookup.PRC) lookup.PRC = 'CHN';
  if (!lookup.MACAU) lookup.MACAU = 'MAC';

  return { alpha3ToEn, lookup };
};

const COUNTRY_REF_DATA = loadCountryRefData();

const extractCountryEnFull = (value: unknown): string => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return '';
  const row = value as Record<string, unknown>;
  return normalizeText(row.enFull ?? row.en_full ?? row.englishFull ?? row.country_en_full ?? '');
};

export const resolveCountryAlpha3Code = (value: unknown): string => {
  const direct = normalizeCountryLookupKey(value);
  if (!direct) return '';
  const viaLookup = normalizeText(COUNTRY_REF_DATA.lookup[direct]).toUpperCase();
  if (viaLookup) return viaLookup;
  if (/^[A-Z]{3}$/.test(direct)) return direct;
  if (direct === 'UK') return 'GBR';
  return '';
};

export const resolveCountryEnglishFullName = (value: unknown): string => {
  const explicit = extractCountryEnFull(value);
  if (explicit) return explicit;

  let alpha3 = resolveCountryAlpha3Code(value);
  if (!alpha3 && value && typeof value === 'object' && !Array.isArray(value)) {
    const row = value as Record<string, unknown>;
    alpha3 = resolveCountryAlpha3Code(row.en ?? row.zh ?? '');
  }
  if (alpha3) {
    const en = normalizeText(COUNTRY_REF_DATA.alpha3ToEn[alpha3]);
    if (en) return en;
  }

  if (value && typeof value === 'object' && !Array.isArray(value)) {
    const row = value as Record<string, unknown>;
    const enFallback = normalizeText(row.en ?? row.english ?? '');
    if (enFallback && !/^[A-Z]{3}$/.test(enFallback.toUpperCase())) return enFallback;
  }

  const text = normalizeText(value);
  if (text && !/^[A-Z]{3}$/.test(text.toUpperCase())) return text;
  return '';
};

export const normalizeCountryBiTextPayload = (value: unknown, fallback = ''): CountryBiTextPayload | null => {
  const fallbackText = normalizeText(fallback);
  let en = '';
  let zh = '';
  let enFull = '';

  if (value && typeof value === 'object' && !Array.isArray(value)) {
    const row = value as Record<string, unknown>;
    en = normalizeText(row.en ?? row.EN ?? row.english ?? row.name_en ?? '');
    zh = normalizeText(row.zh ?? row.ZH ?? row.cn ?? row.chinese ?? row.name_zh ?? '');
    enFull = extractCountryEnFull(row);
  } else {
    const text = normalizeText(value);
    if (text) {
      en = text;
      zh = text;
    }
  }

  if (!en && !zh && fallbackText) {
    en = fallbackText;
    zh = fallbackText;
  }
  if (!en) en = zh || fallbackText;
  if (!zh) zh = en || fallbackText;

  const alpha3 = resolveCountryAlpha3Code(en) || resolveCountryAlpha3Code(zh);
  if (alpha3) en = alpha3;

  if (!enFull) {
    enFull = resolveCountryEnglishFullName({ en, zh });
  }

  const normalizedEn = normalizeText(en);
  const normalizedZh = normalizeText(zh);
  const normalizedEnFull = normalizeText(enFull);
  if (!normalizedEn && !normalizedZh && !normalizedEnFull) return null;

  return {
    en: normalizedEn || normalizedZh || '',
    zh: normalizedZh || normalizedEn || '',
    ...(normalizedEnFull ? { enFull: normalizedEnFull } : {}),
  };
};
