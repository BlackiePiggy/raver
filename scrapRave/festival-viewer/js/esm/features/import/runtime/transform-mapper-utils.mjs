// ESM pilot module for import/runtime transform mapping pure helpers.
// Runtime-isolated: dependencies are injected by caller where needed.

export function scrapeDateFromDatetime(dt) {
  const m = String(dt || '').match(/^(\d{4}-\d{2}-\d{2})/);
  return m ? m[1] : '';
}

export function dedupeStrings(arr) {
  const seen = new Set();
  const out = [];
  for (const s of arr || []) {
    const v = String(s || '').trim();
    if (!v || seen.has(v)) continue;
    seen.add(v);
    out.push(v);
  }
  return out;
}

export function extractCountryFromScraped(event) {
  const list = Array.isArray(event?.jsonld) ? event.jsonld : [];
  for (const item of list) {
    if (!item || typeof item !== 'object') continue;
    if (item['@type'] !== 'Event') continue;
    const addr = item.location?.address || {};
    const fromCountry = String(addr.addressCountry || '').trim();
    if (fromCountry) return fromCountry;
    const name = String(addr.name || '').trim();
    if (name) {
      const parts = name.split(',').map((v) => v.trim()).filter(Boolean);
      if (parts.length) return parts[parts.length - 1];
    }
  }
  return '';
}

export function sanitizeFolderToken(text, fallback) {
  const v = String(text || '')
    .replace(/[\\/:*?"<>|]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return (v || fallback || 'unknown').slice(0, 70);
}

export function sanitizePhotoLabel(label, fallback = 'photo') {
  const raw = String(label || '').trim().toLowerCase();
  const cleaned = raw
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 60);
  return cleaned || fallback;
}

export function guessPhotoExt(url) {
  try {
    const u = new URL(String(url || ''));
    const m = u.pathname.match(/\.([a-zA-Z0-9]{2,5})$/);
    if (!m) return 'jpg';
    const ext = m[1].toLowerCase();
    return ext === 'jpeg' ? 'jpg' : ext;
  } catch (_) {
    return 'jpg';
  }
}

function defaultNormalizeSocialLinks(list) {
  return (Array.isArray(list) ? list : [])
    .map((x) => ({
      type: String(x?.type || '').toLowerCase().trim(),
      url: String(x?.url || '').trim(),
      label: String(x?.label || '').trim(),
    }))
    .filter((x) => x.type && x.url);
}

function defaultBuildFestivalId(startDate, eventName, country) {
  const date = String(startDate || '').replace(/\D/g, '').slice(0, 8);
  const name = String(eventName || '').replace(/[^\p{L}\p{N}]+/gu, ' ').trim().split(/\s+/).filter(Boolean).map((w) => w[0].toUpperCase() + w.slice(1)).join('');
  const countryToken = String(country || '').trim().toUpperCase().slice(0, 3);
  if (!date || !name || !countryToken) return '';
  return `${date}-${name}-${countryToken}`;
}

export function mapScrapedEventToInfo(event, options = {}) {
  const normalizeSocialLinks = typeof options.normalizeSocialLinks === 'function'
    ? options.normalizeSocialLinks
    : defaultNormalizeSocialLinks;
  const buildFestivalId = typeof options.buildFestivalId === 'function'
    ? options.buildFestivalId
    : defaultBuildFestivalId;
  const dedupeStringsFn = typeof options.dedupeStrings === 'function'
    ? options.dedupeStrings
    : dedupeStrings;

  const startDate = scrapeDateFromDatetime(event?.start_datetime);
  const endDate = scrapeDateFromDatetime(event?.end_datetime) || startDate;
  const eventName = String(event?.title || event?.slug || '').trim();
  const location = String(event?.venue || '').trim();
  const country = extractCountryFromScraped(event || {});
  const slug = String(event?.slug || '').trim();
  const provider = 'festtimetable';

  const scrapedSocial = Array.isArray(event?.social_links)
    ? event.social_links.map((x) => ({
      type: String(x?.type || '').toLowerCase(),
      url: x?.url,
      label: x?.text || x?.type || '',
    }))
    : [];
  const socialLinks = normalizeSocialLinks(scrapedSocial);
  const socialSet = new Set(socialLinks.map((s) => s.url));
  const links = dedupeStringsFn([
    event?.event_url,
    ...(Array.isArray(event?.stream_platforms) ? event.stream_platforms.map((x) => x?.url) : []),
    ...(Array.isArray(event?.quick_links) ? event.quick_links.map((x) => x?.url) : []),
  ]).filter((u) => !socialSet.has(u));

  const lineup = [];
  const details = Array.isArray(event?.timetable_details) ? event.timetable_details : [];
  for (const day of details) {
    const dayDate = String(day?.date_text || '').trim();
    for (const stage of (day?.stages || [])) {
      const stageName = String(stage?.stage_name || '').trim();
      for (const set of (stage?.sets || [])) {
        const musician = String(set?.artist || '').trim();
        if (!musician) continue;
        const d = scrapeDateFromDatetime(set?.start_datetime) || dayDate;
        const st = String(set?.start_time || '').trim();
        const et = String(set?.end_time || '').trim();
        const tm = st && et ? `${st}—${et}` : (st || et || '');
        lineup.push({
          musician,
          date: d,
          time: tm,
          stage: stageName,
          avatar: String(set?.artist_image_url || '').trim(),
        });
      }
    }
  }

  const source = {
    provider,
    slug,
    eventUrl: String(event?.event_url || '').trim(),
    photos: Array.isArray(event?.photos) ? event.photos.map((p) => ({ label: p.label, image_url: p.image_url })) : [],
  };
  const festivalId = buildFestivalId(startDate, eventName, country);

  return {
    name: eventName,
    nameI18n: { en: eventName, zh: eventName },
    location,
    locationI18n: { en: location, zh: location },
    country,
    countryI18n: { en: country, zh: country },
    canceled: false,
    startDate,
    endDate,
    relatedLinks: links,
    socialLinks,
    lineup,
    festivalId,
    source,
  };
}
