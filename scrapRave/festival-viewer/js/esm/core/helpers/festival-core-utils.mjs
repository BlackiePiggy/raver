// ESM pilot module extracted from core helper pure functions.
// This file is intentionally runtime-isolated (used by tests/tooling first).

export function parseFolderName(name) {
  const parts = String(name || '').split('-');
  if (parts.length < 3) return null;
  const parsedMonth = parseInt(parts[0], 10);
  if (parsedMonth < 1 || parsedMonth > 12) return null;
  const location = parts[parts.length - 1].trim();
  const festName = parts.slice(1, -1).join('-').trim();
  if (!festName || !location) return null;
  return { month: parsedMonth, festName, location };
}

export function classifyImage(filename) {
  const base = String(filename || '').replace(/\.[^.]+$/, '');
  const up = base.toUpperCase();
  if (/^COVER$/i.test(base)) return { type: 'cover', label: 'COVER', order: 0, sort: 0 };
  const lu = up.match(/^LUALL(\d*)$/);
  if (lu) {
    const n = lu[1] ? parseInt(lu[1], 10) : 1;
    return { type: 'luall', label: lu[1] ? `LINE-UP ALL ${n}` : 'LINE-UP ALL', order: 1, sort: n };
  }
  const luShort = up.match(/^LU(?:[\s_-]?([0-9]+))?$/);
  if (luShort) {
    const n = luShort[1] ? parseInt(luShort[1], 10) : 1;
    return { type: 'luall', label: n > 1 ? `LINE-UP ${n}` : 'LINE-UP', order: 1, sort: n };
  }
  const lu2 = up.match(/^LINEUP(?:-([0-9]+))?$/);
  if (lu2) {
    const n = lu2[1] ? parseInt(lu2[1], 10) : 1;
    return { type: 'luall', label: n > 1 ? `LINE-UP ${n}` : 'LINE-UP', order: 1, sort: n };
  }
  const tt = up.match(/^TT(\d+)$/);
  if (tt) {
    const n = parseInt(tt[1], 10);
    return { type: 'tt', label: `TIMETABLE ${n}`, order: 2, sort: n };
  }
  const tt2 = up.match(/^TIMETABLE(?:-([0-9]+))?$/);
  if (tt2) {
    const n = tt2[1] ? parseInt(tt2[1], 10) : 1;
    return { type: 'tt', label: n > 1 ? `TIMETABLE ${n}` : 'TIMETABLE', order: 2, sort: n };
  }
  if (up.includes('LUALL')) return { type: 'luall', label: 'LINE-UP ALL', order: 1, sort: 99 };
  if (up.includes('LINEUP')) return { type: 'luall', label: 'LINE-UP', order: 1, sort: 99 };
  if (/^COVER/i.test(up)) return { type: 'cover', label: 'COVER', order: 0, sort: 0 };
  if (/^TT\d/i.test(up)) return { type: 'tt', label: 'TIMETABLE', order: 2, sort: 99 };
  if (up.includes('TIMETABLE')) return { type: 'tt', label: 'TIMETABLE', order: 2, sort: 99 };
  return { type: 'other', label: base, order: 3, sort: 99 };
}

export function mergeSourceMeta(source, fallback = {}) {
  const base = (fallback && typeof fallback === 'object' && !Array.isArray(fallback)) ? fallback : {};
  const ext = (source && typeof source === 'object' && !Array.isArray(source)) ? source : {};
  const merged = { ...base, ...ext };
  if (merged.provider) merged.provider = String(merged.provider).trim().toLowerCase();
  if (merged.slug) merged.slug = String(merged.slug).trim();
  if (merged.eventUrl) merged.eventUrl = String(merged.eventUrl).trim();
  return merged;
}

export function toPascalToken(text, fallback = '') {
  const words = String(text || '')
    .trim()
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .split(/\s+/)
    .filter(Boolean);
  if (!words.length) return fallback;
  return words.map((w) => {
    const first = w.charAt(0).toUpperCase();
    const rest = w.slice(1);
    return first + rest;
  }).join('');
}

export function normalizeCountryLookupKey(text) {
  return String(text || '')
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9\u4E00-\u9FFF]+/g, '');
}

function isObjectObjectMarkerText(text) {
  return /^\[object\s+object\]$/i.test(String(text || '').trim());
}

function normalizeScalarText(value) {
  if (value === null || value === undefined) return '';
  const t = typeof value;
  if (t === 'string' || t === 'number' || t === 'boolean') {
    const text = String(value).trim();
    if (!text) return '';
    if (isObjectObjectMarkerText(text)) return '';
    return text;
  }
  return '';
}

export function normalizeBiTextValue(value, fallback = '') {
  const fb = normalizeScalarText(fallback);
  if (typeof value === 'string') {
    const text = normalizeScalarText(value);
    if (text.startsWith('{') && text.endsWith('}')) {
      try {
        const parsed = JSON.parse(text);
        if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
          return normalizeBiTextValue(parsed, fb);
        }
      } catch (_error) {
        // keep plain text mode
      }
    }
  }
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    let en = normalizeScalarText(value.en ?? value.EN ?? value.english ?? value.name_en ?? value.en_US ?? '');
    let zh = normalizeScalarText(value.zh ?? value.ZH ?? value.cn ?? value.zh_CN ?? value.chinese ?? value.name_zh ?? '');
    const enFull = normalizeScalarText(
      value.enFull
      ?? value.en_full
      ?? value.englishFull
      ?? value.country_en_full
      ?? ''
    );
    if (!en) en = zh || fb;
    if (!zh) zh = en || fb;
    const out = { en: en || fb, zh: zh || fb };
    if (enFull) out.enFull = enFull;
    return out;
  }
  const text = normalizeScalarText(value) || fb;
  return { en: text, zh: text };
}

export function resolveCountryAlpha3(countryInput, lookup = {}) {
  const src = String(countryInput || '').trim();
  if (!src) return '';
  const map = (lookup && typeof lookup === 'object') ? lookup : {};
  const key = normalizeCountryLookupKey(src);
  if (key && map[key]) return String(map[key]).toUpperCase();

  const bi = normalizeBiTextValue(countryInput, src);
  const candidates = [bi.en, bi.zh, src];
  for (const c of candidates) {
    const k = normalizeCountryLookupKey(c);
    if (k && map[k]) return String(map[k]).toUpperCase();
  }

  if (/^[A-Z]{3}$/.test(key)) return key;
  if (key === 'UK') return 'GBR';
  return '';
}

export function dateTokenFromStartDate(startDate) {
  const src = String(startDate || '').trim();
  let m = src.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!m) m = src.match(/^(\d{4})[\/.](\d{2})[\/.](\d{2})/);
  if (m) return `${m[1]}${m[2]}${m[3]}`;
  const digits = src.replace(/\D/g, '');
  if (digits.length >= 8) return digits.slice(0, 8);
  return '';
}

export function buildFestivalId(startDate, festivalName, country, lookup = {}) {
  const datePart = dateTokenFromStartDate(startDate);
  const nameBi = normalizeBiTextValue(festivalName, String(festivalName || '').trim());
  const namePart = toPascalToken(nameBi.en || nameBi.zh || '');
  const countryPart = resolveCountryAlpha3(country, lookup);
  if (!datePart || !namePart || !countryPart) return '';
  return `${datePart}-${namePart}-${countryPart}`;
}

export function buildLocalFestivalId(year, folder) {
  const y = String(year || '').trim() || '0000';
  const f = toPascalToken(folder);
  if (!f) return `${y}0101`;
  return `${y}0101-${f}`;
}

export function resolveFestivalId(raw, fallback = {}, source = {}, options = {}) {
  const info = (raw && typeof raw === 'object') ? raw : {};
  const fb = (fallback && typeof fallback === 'object') ? fallback : {};
  const lookup = (options.lookup && typeof options.lookup === 'object') ? options.lookup : {};

  const startDate = String(info.startDate ?? info.start ?? info.start_date ?? fb.startDate ?? '').trim();
  const nameBi = normalizeBiTextValue(
    info.nameI18n ?? info.name_i18n ?? info.name ?? info.festivalName ?? fb.nameI18n ?? fb.name_i18n ?? fb.name ?? '',
    String(info.name ?? info.festivalName ?? fb.name ?? '').trim()
  );
  const countryBi = normalizeBiTextValue(
    info.countryI18n ?? info.country_i18n ?? info.country ?? info.countryCode ?? fb.countryI18n ?? fb.country_i18n ?? fb.country ?? '',
    String(info.country ?? info.countryCode ?? fb.country ?? '').trim()
  );
  const name = String(nameBi.en || nameBi.zh || '').trim();
  const country = String(countryBi.en || countryBi.zh || '').trim();
  const canonical = buildFestivalId(startDate, name, country, lookup);
  if (canonical) return canonical;

  const explicit = String(
    info.festivalId ?? info.eventId ?? info.id ?? info.uid ??
    fb.festivalId ?? fb.eventId ?? fb.id ?? ''
  ).trim();
  if (explicit) return explicit;

  const maybeFolder = String(info.folder || fb.folder || '').trim();
  const maybeYear = String(info.year || fb.year || '').trim();
  return buildLocalFestivalId(maybeYear, maybeFolder);
}

export function splitEventRange(text) {
  const src = String(text || '').trim();
  if (!src) return { startDate: '', endDate: '' };
  let parts = src.split(/\s*(?:~|—|–|to|TO|至|到)\s*/);
  if (parts.length < 2 && /\s-\s/.test(src)) {
    parts = src.split(/\s-\s/);
  }
  if (parts.length >= 2) return { startDate: parts[0].trim(), endDate: parts[1].trim() };
  return { startDate: src, endDate: src };
}
