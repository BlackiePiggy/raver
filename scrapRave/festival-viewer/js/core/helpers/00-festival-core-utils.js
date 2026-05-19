// ── HELPERS ──
function parseFolderName(name) {
  const parts = name.split('-');
  if (parts.length < 3) return null;
  const parsedMonth = parseInt(parts[0], 10);
  if (parsedMonth < 1 || parsedMonth > 12) return null;
  const location = parts[parts.length - 1].trim();
  const festName = parts.slice(1, -1).join('-').trim();
  if (!festName || !location) return null;
  return { month: parsedMonth, festName, location };
}

function classifyImage(filename) {
  const base = filename.replace(/\.[^.]+$/, '');
  const up = base.toUpperCase();
  if (/^COVER$/i.test(base)) return { type:'cover', label:'COVER', order:0, sort:0 };
  const lu = up.match(/^LUALL(\d*)$/);
  if (lu) { const n = lu[1] ? parseInt(lu[1]) : 1; return { type:'luall', label: lu[1] ? `LINE-UP ALL ${n}` : 'LINE-UP ALL', order:1, sort:n }; }
  const luShort = up.match(/^LU(?:[\s_-]?([0-9]+))?$/);
  if (luShort) { const n = luShort[1] ? parseInt(luShort[1]) : 1; return { type:'luall', label: n > 1 ? `LINE-UP ${n}` : 'LINE-UP', order:1, sort:n }; }
  const lu2 = up.match(/^LINEUP(?:-([0-9]+))?$/);
  if (lu2) { const n = lu2[1] ? parseInt(lu2[1]) : 1; return { type:'luall', label: n > 1 ? `LINE-UP ${n}` : 'LINE-UP', order:1, sort:n }; }
  const tt = up.match(/^TT(\d+)$/);
  if (tt) { const n = parseInt(tt[1]); return { type:'tt', label:`TIMETABLE ${n}`, order:2, sort:n }; }
  const tt2 = up.match(/^TIMETABLE(?:-([0-9]+))?$/);
  if (tt2) { const n = tt2[1] ? parseInt(tt2[1]) : 1; return { type:'tt', label: n > 1 ? `TIMETABLE ${n}` : 'TIMETABLE', order:2, sort:n }; }
  if (up.includes('LUALL')) return { type:'luall', label:'LINE-UP ALL', order:1, sort:99 };
  if (up.includes('LINEUP')) return { type:'luall', label:'LINE-UP', order:1, sort:99 };
  if (/^COVER/i.test(up)) return { type:'cover', label:'COVER', order:0, sort:0 };
  if (/^TT\d/i.test(up)) return { type:'tt', label:'TIMETABLE', order:2, sort:99 };
  if (up.includes('TIMETABLE')) return { type:'tt', label:'TIMETABLE', order:2, sort:99 };
  return { type:'other', label:base, order:3, sort:99 };
}

function isImage(name) { return /\.(jpe?g|png|gif|webp|avif|bmp|svg|tiff?)$/i.test(name); }

function getUrlHost(url) {
  try { return new URL(String(url || '').trim()).hostname.toLowerCase(); }
  catch (_) { return ''; }
}

function inferSocialTypeFromUrl(url) {
  const host = getUrlHost(url);
  if (!host) return 'website';
  if (host.includes('instagram.com')) return 'instagram';
  if (host.includes('twitter.com') || host.includes('x.com')) return 'x';
  if (host.includes('facebook.com') || host.includes('fb.com')) return 'facebook';
  if (host.includes('threads.net')) return 'threads';
  if (host.includes('youtube.com') || host.includes('youtu.be')) return 'youtube';
  if (host.includes('tiktok.com')) return 'tiktok';
  if (host.includes('soundcloud.com')) return 'soundcloud';
  return 'website';
}

function socialIconForType(type) {
  const t = String(type || '').toLowerCase();
  if (t === 'instagram') return '📸';
  if (t === 'x' || t === 'twitter') return '✕';
  if (t === 'facebook') return 'f';
  if (t === 'threads') return '🧵';
  if (t === 'youtube') return '▶';
  if (t === 'tiktok') return '♫';
  if (t === 'soundcloud') return '☁';
  return '🌐';
}

function normalizeSocialLinks(raw) {
  let arr = [];
  if (Array.isArray(raw)) arr = raw;
  else if (typeof raw === 'string') arr = raw.split(/\r?\n/).map(v => v.trim()).filter(Boolean);

  const out = [];
  const seen = new Set();
  for (const item of arr) {
    if (!item) continue;
    const url = typeof item === 'string' ? item.trim() : String(item.url || '').trim();
    if (!url || seen.has(url)) continue;
    seen.add(url);
    const type = (typeof item === 'object' && item.type) ? String(item.type).toLowerCase() : inferSocialTypeFromUrl(url);
    const label = (typeof item === 'object' && item.label) ? String(item.label) : '';
    out.push({ type, url, label });
  }
  return out;
}

function splitReferenceLinks(links, existingSocial = []) {
  const refs = [];
  const social = normalizeSocialLinks(existingSocial);
  const socialSet = new Set(social.map(s => s.url));

  for (const raw of (Array.isArray(links) ? links : [])) {
    const url = String(raw || '').trim();
    if (!url) continue;
    const t = inferSocialTypeFromUrl(url);
    const isKnownSocial = t !== 'website';
    if (isKnownSocial && !socialSet.has(url)) {
      social.push({ type: t, url, label: '' });
      socialSet.add(url);
    } else if (!socialSet.has(url)) {
      refs.push(url);
    }
  }
  return { refs: dedupeStrings(refs), social: normalizeSocialLinks(social) };
}

function mergeSourceMeta(source, fallback = {}) {
  const base = (fallback && typeof fallback === 'object' && !Array.isArray(fallback)) ? fallback : {};
  const ext = (source && typeof source === 'object' && !Array.isArray(source)) ? source : {};
  const merged = { ...base, ...ext };
  if (merged.provider) merged.provider = String(merged.provider).trim().toLowerCase();
  if (merged.slug) merged.slug = String(merged.slug).trim();
  if (merged.eventUrl) merged.eventUrl = String(merged.eventUrl).trim();
  return merged;
}

function toPascalToken(text, fallback = '') {
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

function normalizeCountryLookupKey(text) {
  return String(text || '')
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9\u4E00-\u9FFF]+/g, '');
}

function resolveCountryAlpha3(countryInput) {
  const src = String(countryInput || '').trim();
  if (!src) return '';
  const data = window.ISO3166_COUNTRY_DATA || {};
  const lookup = (data && typeof data.lookup === 'object') ? data.lookup : {};
  const key = normalizeCountryLookupKey(src);
  if (key && lookup[key]) return String(lookup[key]).toUpperCase();

  // Try bilingual parsing if input is an i18n object stringified by caller fallback.
  const bi = normalizeBiTextValue(countryInput, src);
  const candidates = [bi.en, bi.zh, src];
  for (const c of candidates) {
    const k = normalizeCountryLookupKey(c);
    if (k && lookup[k]) return String(lookup[k]).toUpperCase();
  }

  // Fallback: if user already typed a 3-letter code, trust it.
  if (/^[A-Z]{3}$/.test(key)) return key;
  // Compatibility alias: UK is commonly used but ISO alpha-3 is GBR.
  if (key === 'UK') return 'GBR';
  return '';
}

let isoCountryAlpha3ToEnglishCache = null;
function getIsoCountryAlpha3ToEnglishMap() {
  if (isoCountryAlpha3ToEnglishCache) return isoCountryAlpha3ToEnglishCache;
  const out = {};
  const countries = Array.isArray(window?.ISO3166_COUNTRY_DATA?.countries)
    ? window.ISO3166_COUNTRY_DATA.countries
    : [];
  for (const item of countries) {
    if (!item || typeof item !== 'object') continue;
    const alpha3 = String(item.alpha3 || '').trim().toUpperCase();
    const en = String(item.en || '').trim();
    if (!alpha3 || !en) continue;
    out[alpha3] = en;
  }
  isoCountryAlpha3ToEnglishCache = out;
  return out;
}

function resolveCountryEnglishFull(countryInput) {
  const src = normalizeScalarText(countryInput);
  const explicit = (countryInput && typeof countryInput === 'object' && !Array.isArray(countryInput))
    ? normalizeScalarText(
      countryInput.enFull
      ?? countryInput.en_full
      ?? countryInput.englishFull
      ?? countryInput.country_en_full
      ?? ''
    )
    : '';
  if (explicit) return explicit;

  const alpha3 = resolveCountryAlpha3(countryInput);
  const alpha3Map = getIsoCountryAlpha3ToEnglishMap();
  if (alpha3 && alpha3Map[alpha3]) return alpha3Map[alpha3];

  const data = window.ISO3166_COUNTRY_DATA || {};
  const lookup = (data && typeof data.lookup === 'object') ? data.lookup : {};
  const bi = normalizeBiTextValue(countryInput, src);
  const candidates = [bi.en, bi.zh, src];
  for (const candidate of candidates) {
    const key = normalizeCountryLookupKey(candidate);
    if (!key) continue;
    const code = String(lookup[key] || '').toUpperCase();
    if (code && alpha3Map[code]) return alpha3Map[code];
  }

  const enFallback = normalizeScalarText(bi.en);
  if (enFallback && !/^[A-Z]{3}$/.test(enFallback.toUpperCase())) return enFallback;
  return '';
}

function normalizeCountryBiTextValue(value, fallback = '') {
  const bi = normalizeBiTextValue(value, fallback);
  let enFull = resolveCountryEnglishFull(value);
  if (!enFull) enFull = resolveCountryEnglishFull(bi.en || bi.zh || fallback);
  const out = { en: bi.en || '', zh: bi.zh || '' };
  if (bi.ja) out.ja = bi.ja;
  if (enFull) out.enFull = enFull;
  return out;
}

function dateTokenFromStartDate(startDate) {
  const src = String(startDate || '').trim();
  let m = src.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!m) m = src.match(/^(\d{4})[\/.](\d{2})[\/.](\d{2})/);
  if (m) return `${m[1]}${m[2]}${m[3]}`;
  const digits = src.replace(/\D/g, '');
  if (digits.length >= 8) return digits.slice(0, 8);
  return '';
}

function buildFestivalId(startDate, festivalName, country) {
  const datePart = dateTokenFromStartDate(startDate);
  const nameBi = normalizeBiTextValue(festivalName, String(festivalName || '').trim());
  const namePart = toPascalToken(nameBi.en || nameBi.zh || '');
  const countryPart = resolveCountryAlpha3(country);
  if (!datePart || !namePart || !countryPart) return '';
  return `${datePart}-${namePart}-${countryPart}`;
}

function buildLocalFestivalId(year, folder) {
  const y = String(year || '').trim() || '0000';
  const f = toPascalToken(folder);
  if (!f) return `${y}0101`;
  return `${y}0101-${f}`;
}

function resolveFestivalId(raw, fallback = {}, source = {}) {
  const startDate = String(raw.startDate ?? raw.start ?? raw.start_date ?? fallback.startDate ?? '').trim();
  const nameBi = normalizeBiTextValue(
    raw.nameI18n ?? raw.name_i18n ?? raw.name ?? raw.festivalName ?? fallback.nameI18n ?? fallback.name_i18n ?? fallback.name ?? '',
    String(raw.name ?? raw.festivalName ?? fallback.name ?? '').trim()
  );
  const countryBi = normalizeBiTextValue(
    raw.countryI18n ?? raw.country_i18n ?? raw.country ?? raw.countryCode ?? fallback.countryI18n ?? fallback.country_i18n ?? fallback.country ?? '',
    String(raw.country ?? raw.countryCode ?? fallback.country ?? '').trim()
  );
  const name = String(nameBi.en || nameBi.zh || '').trim();
  const country = String(countryBi.en || countryBi.zh || '').trim();
  const canonical = buildFestivalId(startDate, name, country);
  if (canonical) return canonical;

  const explicit = String(
    raw.festivalId ?? raw.eventId ?? raw.id ?? raw.uid ??
    fallback.festivalId ?? fallback.eventId ?? fallback.id ?? ''
  ).trim();
  if (explicit) return explicit;

  const maybeFolder = String(raw.folder || fallback.folder || '').trim();
  const maybeYear = String(raw.year || fallback.year || '').trim();
  return buildLocalFestivalId(maybeYear, maybeFolder);
}

function splitEventRange(text) {
  const src = String(text || '').trim();
  if (!src) return { startDate:'', endDate:'' };
  let parts = src.split(/\s*(?:~|—|–|to|TO|至|到)\s*/);
  if (parts.length < 2 && /\s-\s/.test(src)) {
    parts = src.split(/\s-\s/);
  }
  if (parts.length >= 2) return { startDate: parts[0].trim(), endDate: parts[1].trim() };
  return { startDate: src, endDate: src };
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

function normalizeBiTextValue(value, fallback = '') {
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
    const hasExplicitLocaleKeys =
      Object.prototype.hasOwnProperty.call(value, 'en')
      || Object.prototype.hasOwnProperty.call(value, 'EN')
      || Object.prototype.hasOwnProperty.call(value, 'english')
      || Object.prototype.hasOwnProperty.call(value, 'name_en')
      || Object.prototype.hasOwnProperty.call(value, 'en_US')
      || Object.prototype.hasOwnProperty.call(value, 'zh')
      || Object.prototype.hasOwnProperty.call(value, 'ZH')
      || Object.prototype.hasOwnProperty.call(value, 'cn')
      || Object.prototype.hasOwnProperty.call(value, 'zh_CN')
      || Object.prototype.hasOwnProperty.call(value, 'chinese')
      || Object.prototype.hasOwnProperty.call(value, 'name_zh')
      || Object.prototype.hasOwnProperty.call(value, 'ja')
      || Object.prototype.hasOwnProperty.call(value, 'JA')
      || Object.prototype.hasOwnProperty.call(value, 'jp')
      || Object.prototype.hasOwnProperty.call(value, 'japanese');
    let en = normalizeScalarText(value.en ?? value.EN ?? value.english ?? value.name_en ?? value.en_US ?? '');
    let zh = normalizeScalarText(value.zh ?? value.ZH ?? value.cn ?? value.zh_CN ?? value.chinese ?? value.name_zh ?? '');
    const ja = normalizeScalarText(value.ja ?? value.JA ?? value.jp ?? value.japanese ?? '');
    const enFull = normalizeScalarText(
      value.enFull
      ?? value.en_full
      ?? value.englishFull
      ?? value.country_en_full
      ?? ''
    );
    if (hasExplicitLocaleKeys) {
      if (!en && !zh && !ja && fb) en = fb;
      const out = { en, zh };
      if (ja) out.ja = ja;
      if (enFull) out.enFull = enFull;
      return out;
    }
    if (!en) en = zh || fb;
    if (!zh) zh = en || fb;
    const out = { en: en || fb, zh: zh || fb };
    if (ja) out.ja = ja;
    if (enFull) out.enFull = enFull;
    return out;
  }
  const text = normalizeScalarText(value) || fb;
  return { en: text, zh: text };
}

function renderBiTextHtml(value, options = {}) {
  const bi = normalizeBiTextValue(value, options.fallback || '');
  const en = String(bi.enFull || bi.en || '').trim() || String(bi.zh || '').trim() || '—';
  const zh = String(bi.zh || '').trim() || en || '—';
  const cls = `bi-text ${options.compact ? 'compact' : ''}`.trim();
  return `<span class="${cls}"><span class="bi-en">${escapeHtml(en)}</span><span class="bi-zh">${escapeHtml(zh)}</span></span>`;
}

function normalizeBoolFlag(value, fallback = false) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  const s = String(value ?? '').trim().toLowerCase();
  if (!s) return !!fallback;
  if (['1', 'true', 'yes', 'y', 'cancelled', 'canceled', '已取消', '是'].includes(s)) return true;
  if (['0', 'false', 'no', 'n', 'active', 'normal', '未取消', '否'].includes(s)) return false;
  return !!fallback;
}

function normalizeTicketPriceValue(value, fallback = null) {
  const source = value ?? fallback;
  if (source === null || source === undefined || source === '') return null;
  if (typeof source === 'number' && Number.isFinite(source)) return source;
  const text = String(source).trim();
  if (!text) return null;
  const cleaned = text.replace(/[, ]+/g, '').replace(/[^\d.-]/g, '');
  if (!cleaned) return null;
  const parsed = Number(cleaned);
  return Number.isFinite(parsed) ? parsed : null;
}

function formatTicketPriceNumber(value) {
  if (!Number.isFinite(value)) return '';
  return Number.isInteger(value) ? String(value) : String(Number(value.toFixed(2)));
}

function normalizeFestivalLocationPoint(value, fallback = null) {
  const src = (value && typeof value === 'object') ? value : ((fallback && typeof fallback === 'object') ? fallback : null);
  if (!src || typeof src !== 'object') return null;
  const lng = Number(src?.location?.lng ?? src?.lng ?? src?.longitude);
  const lat = Number(src?.location?.lat ?? src?.lat ?? src?.latitude);
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
  const provider = String(src?.provider || 'amap').trim().toLowerCase() || 'amap';
  const providerMetaRaw = (src?.providerMeta && typeof src.providerMeta === 'object') ? src.providerMeta : null;
  const providerMeta = {
    ...(providerMetaRaw && providerMetaRaw.amap && typeof providerMetaRaw.amap === 'object'
      ? {
          amap: {
            poiId: String(providerMetaRaw.amap?.poiId || '').trim(),
            adcode: String(providerMetaRaw.amap?.adcode || '').trim(),
          },
        }
      : {}),
    ...(providerMetaRaw && providerMetaRaw.google && typeof providerMetaRaw.google === 'object'
      ? {
          google: {
            placeId: String(providerMetaRaw.google?.placeId || '').trim(),
            types: Array.isArray(providerMetaRaw.google?.types)
              ? providerMetaRaw.google.types.map((item) => String(item || '').trim()).filter(Boolean).slice(0, 20)
              : [],
          },
        }
      : {}),
    ...(providerMetaRaw && providerMetaRaw.mapkit && typeof providerMetaRaw.mapkit === 'object'
      ? {
          mapkit: {
            mapItemIdentifier: String(providerMetaRaw.mapkit?.mapItemIdentifier || '').trim(),
          },
        }
      : {}),
    ...(providerMetaRaw && providerMetaRaw.mapbox && typeof providerMetaRaw.mapbox === 'object'
      ? {
          mapbox: {
            placeId: String(providerMetaRaw.mapbox?.placeId || '').trim(),
            featureType: String(providerMetaRaw.mapbox?.featureType || '').trim(),
          },
        }
      : {}),
    ...(providerMetaRaw && providerMetaRaw.geoapify && typeof providerMetaRaw.geoapify === 'object'
      ? {
          geoapify: {
            placeId: String(providerMetaRaw.geoapify?.placeId || '').trim(),
            featureType: String(providerMetaRaw.geoapify?.featureType || '').trim(),
          },
        }
      : {}),
  };
  const providerPlaceId = String(
    src?.providerPlaceId
    || src?.poiId
    || providerMeta.amap?.poiId
    || providerMeta.google?.placeId
    || providerMeta.mapkit?.mapItemIdentifier
    || providerMeta.mapbox?.placeId
    || providerMeta.geoapify?.placeId
    || ''
  ).trim();
  const poiId = String(src?.poiId || providerMeta.amap?.poiId || (provider === 'amap' ? providerPlaceId : '') || '').trim();
  const adcode = String(src?.adcode || providerMeta.amap?.adcode || '').trim();
  if (poiId || adcode) {
    providerMeta.amap = {
      poiId: poiId || '',
      adcode: adcode || '',
    };
  }
  const nameZh = String(src?.nameI18n?.zh || src?.name || '').trim();
  const nameEn = String(src?.nameI18n?.en || nameZh).trim();
  const addrZh = String(src?.addressI18n?.zh || src?.address || '').trim();
  const addrEn = String(src?.addressI18n?.en || addrZh).trim();
  const formattedZh = String(src?.formattedAddressI18n?.zh || src?.formattedAddress || addrZh).trim();
  const formattedEn = String(src?.formattedAddressI18n?.en || formattedZh || addrEn).trim();
  const countryCode = String(src?.countryCode || '').trim().toUpperCase();
  return {
    provider,
    sourceMode: String(src?.sourceMode || 'manual_search').trim() || 'manual_search',
    providerPlaceId,
    poiId,
    location: { lng, lat },
    nameI18n: { zh: nameZh, en: nameEn },
    addressI18n: { zh: addrZh, en: addrEn },
    formattedAddressI18n: { zh: formattedZh, en: formattedEn },
    adcode,
    city: String(src?.city || '').trim(),
    district: String(src?.district || '').trim(),
    province: String(src?.province || '').trim(),
    countryCode,
    providerMeta: Object.keys(providerMeta).length ? providerMeta : null,
    i18nPending: !!src?.i18nPending,
    selectedAt: String(src?.selectedAt || '').trim() || new Date().toISOString(),
  };
}

function normalizeFestivalManualLocation(value, fallback = null) {
  const src = (value && typeof value === 'object') ? value : ((fallback && typeof fallback === 'object') ? fallback : null);
  if (!src || typeof src !== 'object') return null;
  const detailAddressI18n = normalizeBiTextValue(
    src?.detailAddressI18n ?? src?.detail_address_i18n ?? '',
    ''
  );
  const formatted = normalizeBiTextValue(
    src?.formattedAddressI18n ?? src?.formattedAddress ?? detailAddressI18n,
    ''
  );
  const hasDetail = !!(String(detailAddressI18n.en || '').trim() || String(detailAddressI18n.zh || '').trim());
  const hasFormatted = !!(String(formatted.en || '').trim() || String(formatted.zh || '').trim());
  if (!hasDetail && !hasFormatted) return null;
  const selectedAtRaw = String(src?.selectedAt || '').trim();
  const selectedAtDate = selectedAtRaw ? new Date(selectedAtRaw) : new Date();
  const selectedAt = Number.isNaN(selectedAtDate.getTime()) ? new Date().toISOString() : selectedAtDate.toISOString();
  return {
    detailAddressI18n: hasDetail ? detailAddressI18n : { en: '', zh: '' },
    formattedAddressI18n: hasFormatted ? formatted : { en: '', zh: '' },
    selectedAt,
  };
}

function joinEventAddressParts(parts) {
  const out = [];
  const seen = new Set();
  for (const item of (Array.isArray(parts) ? parts : [])) {
    const text = normalizeScalarText(item);
    if (!text) continue;
    const key = text.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(text);
  }
  return out.join(' · ');
}

function formatFestivalUnifiedAddress(info) {
  const row = (info && typeof info === 'object') ? info : {};
  const explicitLang = normalizeScalarText(
    row.addressLang ?? row.address_lang ?? row.displayLang ?? row.display_lang ?? row.lang ?? row.language
  ).toLowerCase();
  const docLang = (typeof document !== 'undefined')
    ? normalizeScalarText(document?.documentElement?.lang).toLowerCase()
    : '';
  const navLang = (typeof navigator !== 'undefined')
    ? normalizeScalarText(navigator?.language).toLowerCase()
    : '';
  const preferZh = explicitLang.startsWith('zh')
    || (!explicitLang.startsWith('en') && (docLang.startsWith('zh') || navLang.startsWith('zh') || (!docLang && !navLang)));

  const manual = normalizeFestivalManualLocation(row.manualLocation ?? row.manual_location ?? null);
  const point = normalizeFestivalLocationPoint(row.locationPoint ?? row.location_point ?? null);
  const manualFormattedBi = normalizeBiTextValue(manual?.formattedAddressI18n ?? '', '');
  const manualFormatted = normalizeScalarText(
    preferZh
      ? (manualFormattedBi.zh || manualFormattedBi.en)
      : (manualFormattedBi.en || manualFormattedBi.zh)
  );
  if (manualFormatted) return manualFormatted;

  const pointFormattedBi = normalizeBiTextValue(point?.formattedAddressI18n ?? '', '');
  const pointFormatted = normalizeScalarText(
    preferZh
      ? (pointFormattedBi.zh || pointFormattedBi.en)
      : (pointFormattedBi.en || pointFormattedBi.zh)
  );
  if (pointFormatted) return pointFormatted;

  // Fallback for older records that have detailAddress but missing formattedAddress.
  const detailBi = normalizeBiTextValue(
    manual?.detailAddressI18n ?? row.detailAddressI18n ?? row.detail_address_i18n ?? '',
    ''
  );
  const detail = normalizeScalarText(preferZh ? (detailBi.zh || detailBi.en) : (detailBi.en || detailBi.zh));
  if (detail) return detail;

  return '';
}

function normalizeFestivalInfo(raw, fallback) {
  fallback = (fallback && typeof fallback === 'object') ? fallback : {};
  const linksRaw = raw.relatedLinks ?? raw.links ?? raw.urls ?? raw.related_links ?? [];
  let links = [];
  if (Array.isArray(linksRaw)) links = linksRaw.map(v => String(v||'').trim()).filter(Boolean);
  else if (typeof linksRaw === 'string') links = linksRaw.split(/\r?\n/).map(v=>v.trim()).filter(Boolean);

  const range = splitEventRange(raw.eventTime ?? raw.time ?? raw.dateRange ?? raw.date ?? '');

  // Parse lineup — supports both top-level array and { lineup_info: [...] } wrapper
  let lineup = [];
  const lineupRaw = raw.lineup ?? raw.lineup_info ?? null;
  if (Array.isArray(lineupRaw)) lineup = lineupRaw;
  else if (lineupRaw && typeof lineupRaw === 'object' && Array.isArray(lineupRaw.lineup_info)) lineup = lineupRaw.lineup_info;

  const socialRaw = raw.socialLinks ?? raw.social_links ?? raw.social ?? [];
  const socialLinks = normalizeSocialLinks(socialRaw);
  const { refs, social } = splitReferenceLinks(links, socialLinks);

  const nameBi = normalizeBiTextValue(
    raw.nameI18n ?? raw.name_i18n ?? raw.name ?? raw.festivalName ?? fallback.nameI18n ?? fallback.name_i18n ?? fallback.name ?? ''
  );
  const countryBi = normalizeCountryBiTextValue(
    raw.countryI18n ?? raw.country_i18n ?? raw.country ?? raw.countryCode ?? fallback.countryI18n ?? fallback.country_i18n ?? fallback.country ?? ''
  );
  const cityBi = normalizeBiTextValue(
    raw.cityI18n ?? raw.city_i18n ?? raw.city ?? fallback.cityI18n ?? fallback.city_i18n ?? fallback.city ?? ''
  );
  const manualLocation = normalizeFestivalManualLocation(
    raw.manualLocation ?? raw.manual_location ?? null,
    fallback.manualLocation ?? fallback.manual_location ?? null
  );
  const locationBi = normalizeBiTextValue(
    manualLocation?.detailAddressI18n
      ?? raw.locationI18n
      ?? raw.location_i18n
      ?? '',
    ''
  );
  const name = String(nameBi.en || nameBi.zh || '').trim();
  const location = String(locationBi.en || locationBi.zh || '').trim();
  const country = String(countryBi.en || countryBi.zh || '').trim();
  const startDate = String(raw.startDate ?? raw.start ?? raw.start_date ?? range.startDate ?? fallback.startDate ?? '').trim();
  const endDate = String(raw.endDate ?? raw.end ?? raw.end_date ?? range.endDate ?? fallback.endDate ?? '').trim();
  const canceled = normalizeBoolFlag(
    raw.canceled ?? raw.cancelled ?? raw.isCanceled ?? raw.isCancelled ?? raw.cancel_status ?? raw.is_cancelled,
    fallback.canceled
  );
  const source = mergeSourceMeta(raw.source, fallback.source);
  const festivalId = resolveFestivalId(
    { ...raw, name, location, country, startDate, endDate },
    fallback,
    source
  );
  const descriptionBi = normalizeBiTextValue(
    raw.descriptionI18n ?? raw.description_i18n ?? raw.description ?? fallback.descriptionI18n ?? fallback.description_i18n ?? fallback.description ?? ''
  );
  const description = String(raw.description ?? descriptionBi.en ?? descriptionBi.zh ?? fallback.description ?? '').trim();
  const archiveFestivalId = String(raw.archiveFestivalId ?? raw.archive_festival_id ?? fallback.archiveFestivalId ?? '').trim();
  const backendEventId = String(raw.backendEventId ?? raw.backend_event_id ?? fallback.backendEventId ?? '').trim();
  const wikiFestivalId = String(
    raw.wikiFestivalId ?? raw.wiki_festival_id ?? raw.brandId ?? raw.brand_id ?? fallback.wikiFestivalId ?? ''
  ).trim();
  const wikiFestivalRaw = raw.wikiFestival ?? raw.wiki_festival ?? fallback.wikiFestival ?? null;
  const wikiFestival = (() => {
    if (!wikiFestivalRaw || typeof wikiFestivalRaw !== 'object' || Array.isArray(wikiFestivalRaw)) return null;
    const item = wikiFestivalRaw;
    const id = String(item.id || wikiFestivalId || '').trim();
    if (!id) return null;
    const nameBi = normalizeBiTextValue(item.nameI18n ?? item.name_i18n ?? item.name, String(item.name || '').trim());
    const countryBi = normalizeCountryBiTextValue(item.countryI18n ?? item.country_i18n ?? item.country, String(item.country || '').trim());
    const cityBi = normalizeBiTextValue(item.cityI18n ?? item.city_i18n ?? item.city, String(item.city || '').trim());
    return {
      id,
      name: String(item.name || nameBi.en || nameBi.zh || '').trim(),
      nameI18n: nameBi,
      country: String(item.country || countryBi.en || countryBi.zh || '').trim(),
      countryI18n: countryBi,
      city: String(item.city || cityBi.en || cityBi.zh || '').trim(),
      cityI18n: cityBi,
      avatarUrl: String(item.avatarUrl || item.avatar_url || '').trim(),
      backgroundUrl: String(item.backgroundUrl || item.background_url || '').trim(),
    };
  })();
  const status = String(raw.status ?? fallback.status ?? '').trim();
  const dayRolloverHourRaw = Number(raw.dayRolloverHour ?? raw.day_rollover_hour ?? fallback.dayRolloverHour ?? 6);
  const dayRolloverHour = Number.isFinite(dayRolloverHourRaw)
    ? Math.max(0, Math.min(23, Math.floor(dayRolloverHourRaw)))
    : 6;
  const stageOrder = normalizeStageOrderList(raw.stageOrder ?? raw.stage_order, fallback.stageOrder ?? fallback.stage_order);
  const eventType = String(raw.eventType ?? raw.event_type ?? fallback.eventType ?? '').trim();
  const organizerName = String(raw.organizerName ?? raw.organizer_name ?? fallback.organizerName ?? '').trim();
  const city = normalizeScalarText(raw.city) || cityBi.en || cityBi.zh || normalizeScalarText(fallback.city);
  const officialWebsite = String(raw.officialWebsite ?? raw.official_website ?? fallback.officialWebsite ?? '').trim();
  const ticketPriceMin = normalizeTicketPriceValue(raw.ticketPriceMin ?? raw.ticket_price_min ?? fallback.ticketPriceMin);
  const ticketPriceMax = normalizeTicketPriceValue(raw.ticketPriceMax ?? raw.ticket_price_max ?? fallback.ticketPriceMax);
  const ticketCurrency = String(raw.ticketCurrency ?? raw.ticket_currency ?? fallback.ticketCurrency ?? '').trim().toUpperCase();
  const ticketUrl = String(raw.ticketUrl ?? raw.ticket_url ?? fallback.ticketUrl ?? '').trim();
  const ticketNotes = String(raw.ticketNotes ?? raw.ticket_notes ?? fallback.ticketNotes ?? '').trim();
  const ticketTiersRaw = raw.ticketTiers ?? raw.ticket_tiers ?? fallback.ticketTiers ?? [];
  const ticketTiers = Array.isArray(ticketTiersRaw)
    ? ticketTiersRaw
        .map((tier, index) => {
          if (!tier || typeof tier !== 'object' || Array.isArray(tier)) return null;
          const name = String(tier.name || '').trim();
          const price = normalizeTicketPriceValue(tier.price);
          const currency = String(tier.currency || ticketCurrency || '').trim().toUpperCase();
          const sortOrderNum = Number(tier.sortOrder);
          const sortOrder = Number.isFinite(sortOrderNum) ? sortOrderNum : index + 1;
          if (!name && price === null) return null;
          return {
            id: String(tier.id || '').trim() || undefined,
            name,
            price,
            currency,
            sortOrder,
          };
        })
        .filter(Boolean)
    : [];
  const slug = String(raw.slug ?? fallback.slug ?? '').trim();
  const createdAt = String(raw.createdAt ?? raw.created_at ?? fallback.createdAt ?? '').trim();
  const updatedAt = String(raw.updatedAt ?? raw.updated_at ?? fallback.updatedAt ?? '').trim();
  const locationPoint = normalizeFestivalLocationPoint(
    raw.locationPoint ?? raw.location_point ?? null,
    fallback.locationPoint ?? fallback.location_point ?? null
  );

  return {
    name,
    nameI18n: nameBi,
    location,
    country,
    countryI18n: countryBi,
    city,
    cityI18n: cityBi,
    canceled,
    startDate,
    endDate,
    relatedLinks: refs,
    socialLinks: social,
    lineup,
    festivalId,
    source,
    description,
    descriptionI18n: descriptionBi,
    archiveFestivalId,
    backendEventId,
    wikiFestivalId,
    wikiFestival,
    status,
    dayRolloverHour,
    stageOrder,
    eventType,
    organizerName,
    manualLocation,
    officialWebsite,
    ticketPriceMin,
    ticketPriceMax,
    ticketCurrency,
    ticketUrl,
    ticketNotes,
    ticketTiers,
    locationPoint,
    slug,
    createdAt,
    updatedAt,
  };
}

function formatDateRange(startDate, endDate) {
  const s = String(startDate||'').trim();
  const e = String(endDate||'').trim();
  if (s && e && s !== e) return `${s} → ${e}`;
  return s || e || '';
}

function normalizeStageOrderList(value, fallback = []) {
  const source = Array.isArray(value) ? value : (Array.isArray(fallback) ? fallback : []);
  const seen = new Set();
  const result = [];
  for (const item of source) {
    const text = String(item || '').trim();
    if (!text) continue;
    const key = text.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(text);
  }
  return result;
}

async function verifyPermission(fileHandle, withWrite = false) {
  const opts = withWrite ? { mode: 'readwrite' } : {};
  if ((await fileHandle.queryPermission(opts)) === 'granted') return true;
  if ((await fileHandle.requestPermission(opts)) === 'granted') return true;
  return false;
}
