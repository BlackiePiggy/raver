// ESM pilot module for import/translate text planning pure helpers.
// Runtime-isolated: used by tests/tooling first.

import { normalizeBiTextValue } from '../../../core/helpers/festival-core-utils.mjs';

export function hasCjkChar(text) {
  return /[\u3400-\u9fff]/.test(String(text || ''));
}

export function hasLatinChar(text) {
  return /[A-Za-z]/.test(String(text || ''));
}

export function isEnglishFieldReady(text) {
  const src = String(text || '').trim();
  if (!src) return false;
  if (hasCjkChar(src)) return false;
  return hasLatinChar(src) || /^[A-Z]{2,3}$/.test(src.toUpperCase());
}

export function isChineseFieldReady(text) {
  const src = String(text || '').trim();
  if (!src) return false;
  return hasCjkChar(src);
}

export function toPlainBiText(value, fallback = '') {
  const bi = normalizeBiTextValue(value, fallback);
  return {
    en: String(bi.en || '').trim(),
    zh: String(bi.zh || '').trim(),
  };
}

export function parsePartialBiText(value) {
  const safe = (input) => {
    if (input === null || input === undefined) return '';
    const type = typeof input;
    if (type !== 'string' && type !== 'number' && type !== 'boolean') return '';
    const text = String(input).trim();
    if (!text) return '';
    return /^\[object\s+object\]$/i.test(text) ? '' : text;
  };
  if (!value || typeof value !== 'object' || Array.isArray(value)) return { en: '', zh: '' };
  return {
    en: safe(value.en ?? value.EN ?? value.english ?? value.name_en ?? ''),
    zh: safe(value.zh ?? value.ZH ?? value.chinese ?? value.name_zh ?? value.cn ?? ''),
  };
}

export function mergeTranslatedBiText(original, translated, needs) {
  const out = {
    en: String(original?.en || '').trim(),
    zh: String(original?.zh || '').trim(),
  };
  if (needs?.en && translated?.en) out.en = String(translated.en).trim();
  if (needs?.zh && translated?.zh) out.zh = String(translated.zh).trim();
  if (!out.en) out.en = out.zh;
  if (!out.zh) out.zh = out.en;
  return normalizeBiTextValue(out, original?.en || original?.zh || '');
}

export function getFestivalTranslateKey(fest) {
  const id = String(fest?.info?.festivalId || '').trim();
  if (id) return id;
  return `${String(fest?.year || '')}/${String(fest?.folder || '')}`;
}

function buildDerivedFormattedAddressBi(detailBi, cityBi, countryBi) {
  const zh = [countryBi?.zh || countryBi?.en, cityBi?.zh || cityBi?.en, detailBi?.zh || detailBi?.en]
    .map((part) => String(part || '').trim())
    .filter(Boolean)
    .join(' · ');
  const en = [countryBi?.en || countryBi?.zh, cityBi?.en || cityBi?.zh, detailBi?.en || detailBi?.zh]
    .map((part) => String(part || '').trim())
    .filter(Boolean)
    .join(' · ');
  return toPlainBiText({ en, zh }, zh || en);
}

export function buildFestivalTranslatePlan(fest) {
  const info = fest?.info || {};
  const nameBi = toPlainBiText(info.nameI18n ?? info.name, info.name || fest?.name || fest?.folder || '');
  const cityBi = toPlainBiText(info.cityI18n ?? info.city, info.city || '');
  const detailAddressBi = toPlainBiText(
    info.manualLocation?.detailAddressI18n ?? info.detailAddressI18n,
    ''
  );
  const countryBi = toPlainBiText(info.countryI18n ?? info.country, info.country || '');
  const formattedAddressBi = toPlainBiText(
    info.manualLocation?.formattedAddressI18n ?? buildDerivedFormattedAddressBi(detailAddressBi, cityBi, countryBi),
    ''
  );

  const requestFestival = {
    name_i18n: nameBi,
    city_i18n: cityBi,
    detail_address_i18n: detailAddressBi,
    formatted_address_i18n: formattedAddressBi,
    manual_location: {
      detail_address_i18n: detailAddressBi,
      formatted_address_i18n: formattedAddressBi,
    },
    country_i18n: countryBi,
  };

  return {
    nameBi,
    cityBi,
    detailAddressBi,
    formattedAddressBi,
    countryBi,
    requestFestival,
  };
}
