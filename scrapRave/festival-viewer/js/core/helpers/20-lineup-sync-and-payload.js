function hasExplicitYearInDateTextForSync(value) {
  const src = String(value || '')
    .replace(/[０-９]/g, (ch) => String.fromCharCode(ch.charCodeAt(0) - 0xFEE0))
    .trim();
  if (!src) return false;
  return /(?:^|[^\d])(19|20)\d{2}(?:\s*年)?(?!\d)/.test(src);
}

function normalizeArchiveDateTextForSync(value) {
  const src = String(value || '').trim();
  if (!src) return '';
  const isoLikePrefix = src.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (isoLikePrefix) return `${isoLikePrefix[1]}-${isoLikePrefix[2]}-${isoLikePrefix[3]}`;
  const m = src.match(/^(\d{4})[\/.\-](\d{1,2})[\/.\-](\d{1,2})$/);
  if (m) return `${m[1]}-${String(Number(m[2])).padStart(2, '0')}-${String(Number(m[3])).padStart(2, '0')}`;
  const cn = src.match(/^(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日?$/);
  if (cn) return `${cn[1]}-${String(Number(cn[2])).padStart(2, '0')}-${String(Number(cn[3])).padStart(2, '0')}`;
  const isoDateOnly = src.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (isoDateOnly) return `${isoDateOnly[1]}-${isoDateOnly[2]}-${isoDateOnly[3]}`;
  const parsed = new Date(src);
  if (!Number.isNaN(parsed.getTime())) {
    // Browsers may infer ambiguous month/day strings as year 2001 (e.g. "Oct.2").
    // Keep ambiguous text untouched so we can resolve year by event date range later.
    if (!hasExplicitYearInDateTextForSync(src) && parsed.getFullYear() === 2001) return src;
    const y = parsed.getFullYear();
    const mo = String(parsed.getMonth() + 1).padStart(2, '0');
    const d = String(parsed.getDate()).padStart(2, '0');
    return `${y}-${mo}-${d}`;
  }
  return src;
}

function parseArchiveDateOnlyForSync(dateText) {
  const normalized = normalizeArchiveDateTextForSync(dateText);
  const m = normalized.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!m) return null;
  const date = new Date(`${m[1]}-${m[2]}-${m[3]}T00:00:00`);
  return Number.isNaN(date.getTime()) ? null : date;
}

function normalizeDateOnlyForSync(value) {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) return null;
  const out = new Date(value);
  out.setHours(0, 0, 0, 0);
  return out;
}

function parseLineupDayIndexForSync(value) {
  const text = String(value || '').trim();
  if (!text) return null;
  const en = text.match(/\bday\s*([1-9]\d*)\b/i);
  if (en) return Number(en[1]);
  const cn = text.match(/第?\s*([1-9]\d*)\s*天/);
  if (cn) return Number(cn[1]);
  return null;
}

function parseLineupMonthDayCandidatesForSync(value) {
  const text = String(value || '').trim();
  if (!text) return [];
  const candidates = [];
  const seen = new Set();
  const push = (month, day) => {
    const m = Number(month);
    const d = Number(day);
    if (!Number.isInteger(m) || !Number.isInteger(d)) return;
    if (m < 1 || m > 12 || d < 1 || d > 31) return;
    const key = `${m}-${d}`;
    if (seen.has(key)) return;
    seen.add(key);
    candidates.push({ month: m, day: d });
  };

  const monthMap = {
    jan: 1, january: 1,
    feb: 2, february: 2,
    mar: 3, march: 3,
    apr: 4, april: 4,
    may: 5,
    jun: 6, june: 6,
    jul: 7, july: 7,
    aug: 8, august: 8,
    sep: 9, sept: 9, september: 9,
    oct: 10, october: 10,
    nov: 11, november: 11,
    dec: 12, december: 12
  };
  const monthToken = '(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t|tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';

  const enMonthFirst = text.match(new RegExp(`${monthToken}\\.?\\s*([0-9]{1,2})`, 'i'));
  if (enMonthFirst) push(monthMap[String(enMonthFirst[1] || '').toLowerCase()], enMonthFirst[2]);

  const enDayFirst = text.match(new RegExp(`([0-9]{1,2})\\s*${monthToken}\\.?`, 'i'));
  if (enDayFirst) push(monthMap[String(enDayFirst[2] || '').toLowerCase()], enDayFirst[1]);

  const cn = text.match(/([0-9]{1,2})\s*月\s*([0-9]{1,2})\s*日?/);
  if (cn) push(cn[1], cn[2]);

  const numeric = text.match(/(?:^|[^\d])([0-9]{1,2})\s*[\/.\-]\s*([0-9]{1,2})(?:[^\d]|$)/);
  if (numeric) {
    const a = Number(numeric[1]);
    const b = Number(numeric[2]);
    push(a, b);
    if (a <= 12 && b <= 12 && a !== b) push(b, a);
  }

  return candidates;
}

function resolveLineupDateForSync(dateText, eventStartDate, eventEndDate) {
  const start = normalizeDateOnlyForSync(eventStartDate) || normalizeDateOnlyForSync(new Date()) || new Date();
  const rawEnd = normalizeDateOnlyForSync(eventEndDate) || start;
  const rangeStart = start.getTime() <= rawEnd.getTime() ? start : rawEnd;
  const rangeEnd = start.getTime() <= rawEnd.getTime() ? rawEnd : start;
  const rawText = String(dateText || '').trim();
  if (!rawText) return rangeStart;

  const explicitYear = hasExplicitYearInDateTextForSync(rawText);
  const parsed = parseArchiveDateOnlyForSync(rawText);
  if (parsed && explicitYear) {
    return normalizeDateOnlyForSync(parsed) || rangeStart;
  }

  const dayIndex = parseLineupDayIndexForSync(rawText);
  if (Number.isInteger(dayIndex) && dayIndex > 0) {
    const candidate = new Date(rangeStart);
    candidate.setDate(candidate.getDate() + dayIndex - 1);
    if (candidate.getTime() <= rangeEnd.getTime()) return candidate;
  }

  const monthDayCandidates = parseLineupMonthDayCandidatesForSync(rawText);
  if (monthDayCandidates.length) {
    const daySpan = Math.max(1, Math.floor((rangeEnd.getTime() - rangeStart.getTime()) / (24 * 60 * 60 * 1000)) + 1);
    const scanDays = Math.min(daySpan, 400);
    for (let offset = 0; offset < scanDays; offset += 1) {
      const probe = new Date(rangeStart);
      probe.setDate(probe.getDate() + offset);
      const probeMonth = probe.getMonth() + 1;
      const probeDay = probe.getDate();
      if (monthDayCandidates.some((item) => item.month === probeMonth && item.day === probeDay)) {
        return probe;
      }
    }

    const years = Array.from(new Set([
      rangeStart.getFullYear(),
      rangeEnd.getFullYear(),
      rangeStart.getFullYear() - 1,
      rangeStart.getFullYear() + 1
    ]));
    let best = null;
    for (const year of years) {
      for (const item of monthDayCandidates) {
        const probe = new Date(`${year}-${String(item.month).padStart(2, '0')}-${String(item.day).padStart(2, '0')}T00:00:00`);
        if (Number.isNaN(probe.getTime())) continue;
        const distance = Math.abs(probe.getTime() - rangeStart.getTime());
        if (!best || distance < best.distance) {
          best = { date: probe, distance };
        }
      }
    }
    if (best?.date) return best.date;
  }

  if (parsed && !explicitYear && parsed.getFullYear() !== 2001) {
    return normalizeDateOnlyForSync(parsed) || rangeStart;
  }
  return rangeStart;
}

function parseLineupTimeRangeForSync(value) {
  const text = String(value || '').trim();
  if (!text) return { startHM: null, endHM: null };
  const pair = text.match(/(\d{1,2}:\d{2})\s*(?:—|–|~|-|to|TO|至|到)\s*(\d{1,2}:\d{2})/);
  if (pair) {
    return { startHM: pair[1], endHM: pair[2] };
  }
  const one = text.match(/(\d{1,2}:\d{2})/);
  if (one) {
    return { startHM: one[1], endHM: null };
  }
  return { startHM: null, endHM: null };
}

function buildLineupDateTimeForSync(date, hourMinute, fallbackMinutes = 0) {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
    return new Date(Date.now() + Math.max(0, Number(fallbackMinutes) || 0) * 60_000);
  }
  const fallback = new Date(date.getTime() + Math.max(0, Number(fallbackMinutes) || 0) * 60_000);
  if (!hourMinute) return fallback;
  const hm = String(hourMinute).match(/^(\d{1,2}):(\d{2})$/);
  if (!hm) return fallback;
  const hours = Math.max(0, Math.min(23, Number(hm[1])));
  const minutes = Math.max(0, Math.min(59, Number(hm[2])));
  const out = new Date(date);
  out.setHours(hours, minutes, 0, 0);
  return out;
}

function isValidTimeZoneForSync(timeZone) {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone });
    return true;
  } catch (_error) {
    return false;
  }
}

function normalizeTimeZoneForSync(value, fallback = 'UTC') {
  const candidate = String(value || '').trim() || fallback;
  return isValidTimeZoneForSync(candidate) ? candidate : fallback;
}

function timeZoneOffsetMsForSync(timeZone, instant) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(instant);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return Date.UTC(
    Number(values.year),
    Number(values.month) - 1,
    Number(values.day),
    Number(values.hour),
    Number(values.minute),
    Number(values.second)
  ) - instant.getTime();
}

function zonedDateTimeToUtcForSync(date, hourMinute, timeZoneRaw, fallbackMinutes = 0) {
  const local = buildLineupDateTimeForSync(date, hourMinute, fallbackMinutes);
  const timeZone = normalizeTimeZoneForSync(timeZoneRaw);
  const guess = Date.UTC(
    local.getFullYear(),
    local.getMonth(),
    local.getDate(),
    local.getHours(),
    local.getMinutes(),
    local.getSeconds(),
    local.getMilliseconds()
  );
  let instant = new Date(guess - timeZoneOffsetMsForSync(timeZone, new Date(guess)));
  instant = new Date(guess - timeZoneOffsetMsForSync(timeZone, instant));
  return instant;
}

function normalizeDayRolloverHourForSync(value, fallback = 6) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(0, Math.min(23, Math.floor(parsed)));
}

function normalizeStageOrderForSync(value, fallback = []) {
  if (typeof normalizeStageOrderList === 'function') {
    return normalizeStageOrderList(value, fallback);
  }
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

function deriveStageOrderFromLineupForSync(lineup) {
  return normalizeStageOrderForSync((Array.isArray(lineup) ? lineup : []).map((slot) => slot?.stage));
}

function extractLineupArtistNameForSync(row) {
  return String(row?.djName ?? row?.name ?? row?.musician ?? row?.artistName ?? '').trim();
}

function buildEventLineupArtistsFromArchive(lineupArtists, timetableRows = []) {
  const source = Array.isArray(lineupArtists) ? lineupArtists : [];
  const fallback = Array.isArray(timetableRows) ? timetableRows : [];
  const byKey = new Map();
  const push = (row, index) => {
    const djName = extractLineupArtistNameForSync(row);
    if (!djName) return;
    const rawDjIds = Array.isArray(row?.djIds) ? row.djIds : [];
    const djIds = rawDjIds
      .map((id) => String(id || '').trim())
      .filter((id) => id && !isLineupDjIdPlaceholder(id));
    const rawDjId = String(row?.djId || '').trim();
    const djId = rawDjId && !isLineupDjIdPlaceholder(rawDjId) ? rawDjId : (djIds[0] || null);
    const key = djId ? `id:${djId}` : `name:${djName.toLowerCase()}`;
    const sortOrder = Number.isFinite(Number(row?.sortOrder)) ? Number(row.sortOrder) : index + 1;
    const existing = byKey.get(key);
    if (existing) {
      existing.djIds = Array.from(new Set([...(existing.djIds || []), ...djIds, ...(djId ? [djId] : [])])).filter(Boolean);
      existing.sortOrder = Math.min(existing.sortOrder, sortOrder);
      const avatarUrl = String(row?.avatarUrl || row?.avatar_url || row?.dj?.avatarUrl || row?.dj?.avatar_url || '').trim();
      if (avatarUrl && !existing.avatarUrl) existing.avatarUrl = avatarUrl;
      return;
    }
    const avatarUrl = String(row?.avatarUrl || row?.avatar_url || row?.dj?.avatarUrl || row?.dj?.avatar_url || '').trim();
    byKey.set(key, {
      djId,
      djIds: Array.from(new Set([...djIds, ...(djId ? [djId] : [])])).filter(Boolean),
      djName,
      sortOrder,
      ...(avatarUrl ? { avatarUrl } : {}),
    });
  };
  source.forEach(push);
  if (!source.length) fallback.forEach(push);
  return Array.from(byKey.values()).sort((a, b) => a.sortOrder - b.sortOrder);
}

function buildEventLineupSlotsFromArchive(lineup, eventStartDateText, eventEndDateText, dayRolloverHourRaw = 6, timeZoneRaw = 'UTC') {
  if (!Array.isArray(lineup)) return [];
  const parsedStart = parseArchiveDateOnlyForSync(eventStartDateText);
  const parsedEnd = parseArchiveDateOnlyForSync(eventEndDateText) || parsedStart;
  const eventStartDate = normalizeDateOnlyForSync(parsedStart) || normalizeDateOnlyForSync(new Date()) || new Date();
  const eventEndDate = normalizeDateOnlyForSync(parsedEnd) || eventStartDate;
  const dayRolloverHour = normalizeDayRolloverHourForSync(dayRolloverHourRaw, 6);
  const timeZone = normalizeTimeZoneForSync(timeZoneRaw);
  const slots = [];
  for (let i = 0; i < lineup.length; i += 1) {
    const normalized = normalizeLineupEntry(lineup[i] || {});
    const djName = String(normalized.musician || '').trim();
    if (!djName) continue;
    const dateCandidate = resolveLineupDateForSync(normalized.date, eventStartDate, eventEndDate);
    const { startHM, endHM } = parseLineupTimeRangeForSync(normalized.time);
    const naturalDayOffset = Math.max(0, Math.floor((normalizeDateOnlyForSync(dateCandidate).getTime() - eventStartDate.getTime()) / (24 * 60 * 60 * 1000)));
    // Recompute festivalDayIndex from date/time on every save.
    // Do not reuse incoming lineup.festivalDayIndex to avoid persisting stale values.
    let festivalDayIndex = naturalDayOffset + 1;
    if (startHM) {
      const hour = Number(String(startHM).split(':')[0] || '0');
      if (Number.isFinite(hour) && hour < dayRolloverHour && festivalDayIndex > 1) {
        festivalDayIndex -= 1;
      }
    }
    const startTime = zonedDateTimeToUtcForSync(dateCandidate, startHM, timeZone, i);
    let endTime = zonedDateTimeToUtcForSync(dateCandidate, endHM, timeZone, i + 1);
    if (endTime.getTime() <= startTime.getTime()) {
      endTime = new Date(endTime.getTime() + 24 * 60 * 60 * 1000);
    }
    const row = {
      djName,
      stageName: String(normalized.stage || '').trim() || null,
      sortOrder: i + 1,
      startTime: startTime.toISOString(),
      endTime: endTime.toISOString(),
      festivalDayIndex: Math.max(1, festivalDayIndex),
    };
    const rawDjIds = Array.isArray(normalized.djIds) ? normalized.djIds : [];
    const djIds = rawDjIds
      .map((id) => String(id || '').trim())
      .filter(Boolean);
    const firstBoundId = djIds.find((id) => !isLineupDjIdPlaceholder(id)) || '';
    const normalizedPrimary = String(normalized.djId || '').trim();
    const djId = (!isLineupDjIdPlaceholder(normalizedPrimary) ? normalizedPrimary : '') || firstBoundId;
    if (djId) row.djId = djId;
    if (djIds.length) row.djIds = djIds;
    slots.push(row);
  }
  return slots;
}

function normalizeArchiveEventStatus(value, fallback = '') {
  const raw = String(value ?? '').trim().toLowerCase();
  if (!raw) return String(fallback || '').trim().toLowerCase();
  if (['cancelled', 'canceled', '已取消', 'cancel'].includes(raw)) return 'cancelled';
  if (['upcoming', 'upcoming_soon', '即将开始', '未开始'].includes(raw)) return 'upcoming';
  if (['ongoing', 'running', '进行中'].includes(raw)) return 'ongoing';
  if (['ended', 'finished', '已结束'].includes(raw)) return 'ended';
  return String(fallback || '').trim().toLowerCase();
}

function resolveArchiveEventStatusForSync(canceled, startDateText, endDateText) {
  if (normalizeBoolFlag(canceled, false)) return 'cancelled';
  const start = parseArchiveDateOnlyForSync(startDateText);
  const end = parseArchiveDateOnlyForSync(endDateText) || start;
  if (!start || !end) return 'upcoming';
  const startMs = start.getTime();
  const endObj = new Date(end);
  endObj.setHours(23, 59, 59, 999);
  const endMs = Math.max(startMs, endObj.getTime());
  const now = Date.now();
  if (now < startMs) return 'upcoming';
  if (now > endMs) return 'ended';
  return 'ongoing';
}

function parseBackendEventImageAssets(value) {
  if (!Array.isArray(value)) return [];
  const allowed = new Set(['cover', 'luall', 'tt', 'other', 'lineup', 'timetable', 'poster', 'map']);
  return value
    .map((item) => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
      const row = item;
      let type = String(row.type || '').trim().toLowerCase();
      if (!type) return null;
      if (!allowed.has(type)) type = 'other';
      if (type === 'lineup') type = 'luall';
      if (type === 'timetable') type = 'tt';
      if (type === 'poster' || type === 'map') type = 'other';
      const url = String(row.url || '').trim();
      if (!url) return null;
      const order = Number.isFinite(row.order) ? Number(row.order) : undefined;
      const sort = Number.isFinite(row.sort) ? Number(row.sort) : undefined;
      return {
        type,
        label: String(row.label || '').trim() || type.toUpperCase(),
        url,
        source: String(row.source || '').trim() || undefined,
        originalUrl: String(row.originalUrl || '').trim() || undefined,
        fileName: String(row.fileName || '').trim() || undefined,
        ...(order !== undefined ? { order } : {}),
        ...(sort !== undefined ? { sort } : {}),
      };
    })
    .filter(Boolean)
    .sort((a, b) => {
      const ao = Number.isFinite(a.order) ? Number(a.order) : 99;
      const bo = Number.isFinite(b.order) ? Number(b.order) : 99;
      if (ao !== bo) return ao - bo;
      const as = Number.isFinite(a.sort) ? Number(a.sort) : 99;
      const bs = Number.isFinite(b.sort) ? Number(b.sort) : 99;
      if (as !== bs) return as - bs;
      return String(a.fileName || '').localeCompare(String(b.fileName || ''));
    });
}

function pickPrimaryEventImageUrls(assets) {
  const list = Array.isArray(assets) ? assets : [];
  const firstByType = (type) => list.find((item) => String(item?.type || '').toLowerCase() === type);
  const cover = firstByType('cover');
  const lineup = firstByType('luall');
  const timetable = firstByType('tt');
  const any = list[0] || null;
  return {
    coverImageUrl: cover?.url || lineup?.url || timetable?.url || any?.url || null,
    lineupImageUrl: lineup?.url || timetable?.url || cover?.url || any?.url || null,
  };
}

function normalizeLocationPointForSync(point) {
  if (typeof normalizeEventLocationPoint === 'function') {
    return normalizeEventLocationPoint(point);
  }
  if (!point || typeof point !== 'object') return null;
  const lng = Number(point?.location?.lng ?? point?.lng ?? point?.longitude);
  const lat = Number(point?.location?.lat ?? point?.lat ?? point?.latitude);
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
  const provider = String(point?.provider || 'amap').trim().toLowerCase() || 'amap';
  const providerMetaRaw = (point?.providerMeta && typeof point.providerMeta === 'object') ? point.providerMeta : null;
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
    point?.providerPlaceId
    || point?.poiId
    || providerMeta.amap?.poiId
    || providerMeta.google?.placeId
    || providerMeta.mapkit?.mapItemIdentifier
    || providerMeta.mapbox?.placeId
    || providerMeta.geoapify?.placeId
    || ''
  ).trim();
  const poiId = String(point?.poiId || providerMeta.amap?.poiId || (provider === 'amap' ? providerPlaceId : '') || '').trim();
  const adcode = String(point?.adcode || providerMeta.amap?.adcode || '').trim();
  if (poiId || adcode) {
    providerMeta.amap = {
      poiId: poiId || '',
      adcode: adcode || '',
    };
  }
  return {
    provider,
    sourceMode: String(point?.sourceMode || 'manual_search').trim() || 'manual_search',
    providerPlaceId,
    poiId,
    location: { lng, lat },
    nameI18n: {
      zh: String(point?.nameI18n?.zh || point?.name || '').trim(),
      en: String(point?.nameI18n?.en || point?.nameI18n?.zh || point?.name || '').trim(),
    },
    addressI18n: {
      zh: String(point?.addressI18n?.zh || point?.address || '').trim(),
      en: String(point?.addressI18n?.en || point?.addressI18n?.zh || point?.address || '').trim(),
    },
    formattedAddressI18n: {
      zh: String(point?.formattedAddressI18n?.zh || point?.formattedAddress || '').trim(),
      en: String(point?.formattedAddressI18n?.en || point?.formattedAddressI18n?.zh || point?.formattedAddress || '').trim(),
    },
    adcode,
    city: String(point?.city || '').trim(),
    district: String(point?.district || '').trim(),
    province: String(point?.province || '').trim(),
    countryCode: String(point?.countryCode || '').trim().toUpperCase(),
    providerMeta: Object.keys(providerMeta).length ? providerMeta : null,
    i18nPending: !!point?.i18nPending,
    selectedAt: String(point?.selectedAt || new Date().toISOString()).trim(),
  };
}

function normalizeManualLocationForSync(value, fallback = null) {
  if (typeof normalizeFestivalManualLocation === 'function') {
    return normalizeFestivalManualLocation(value, fallback);
  }
  const src = (value && typeof value === 'object')
    ? value
    : ((fallback && typeof fallback === 'object') ? fallback : null);
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
  return {
    detailAddressI18n: hasDetail ? detailAddressI18n : { en: '', zh: '' },
    formattedAddressI18n: hasFormatted ? formatted : { en: '', zh: '' },
    selectedAt: String(src?.selectedAt || new Date().toISOString()).trim(),
  };
}

function buildBackendEventUpsertPayload(fest, payload) {
  const hasPayloadCityField = Object.prototype.hasOwnProperty.call(payload || {}, 'cityI18n')
    || Object.prototype.hasOwnProperty.call(payload || {}, 'city');
  const hasPayloadCountryField = Object.prototype.hasOwnProperty.call(payload || {}, 'countryI18n')
    || Object.prototype.hasOwnProperty.call(payload || {}, 'country');
  const hasPayloadManualLocationField = Object.prototype.hasOwnProperty.call(payload || {}, 'manualLocation');
  const source = mergeSourceMeta(payload?.source, fest?.info?.source);
  const nameBi = normalizeBiTextValue(payload?.nameI18n ?? payload?.name, fest?.info?.name || fest?.name || fest?.folder || '');
  const manualLocation = normalizeManualLocationForSync(
    hasPayloadManualLocationField
      ? payload?.manualLocation
      : (payload?.manualLocation ?? fest?.info?.manualLocation ?? null),
    null
  );
  const cityBi = normalizeBiTextValue(
    payload?.cityI18n ?? payload?.city,
    hasPayloadCityField ? '' : (fest?.info?.cityI18n ?? fest?.info?.city ?? '')
  );
  const countryBi = normalizeCountryBiTextValue(
    payload?.countryI18n ?? payload?.country,
    hasPayloadCountryField ? '' : (fest?.info?.countryI18n ?? fest?.info?.country ?? '')
  );
  const name = String(payload?.name || nameBi.en || nameBi.zh || '').trim();
  const city = String(payload?.city || cityBi.zh || cityBi.en || '').trim();
  const country = String(payload?.country || countryBi.en || countryBi.zh || '').trim();
  const startDate = normalizeArchiveDateTextForSync(payload?.startDate || fest?.info?.startDate || '');
  const endDate = normalizeArchiveDateTextForSync(payload?.endDate || fest?.info?.endDate || '') || startDate;
  const referenceLinks = dedupeStrings(payload?.relatedLinks || []);
  const socialLinks = normalizeSocialLinks(payload?.socialLinks || []);
  const dayRolloverHour = normalizeDayRolloverHourForSync(
    payload?.dayRolloverHour ?? fest?.info?.dayRolloverHour,
    6
  );
  const timeZone = normalizeTimeZoneForSync(payload?.timeZone ?? payload?.timezone ?? fest?.info?.timeZone ?? fest?.info?.timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone, 'UTC');
  const stageOrder = normalizeStageOrderForSync(
    payload?.stageOrder ?? payload?.stage_order,
    fest?.info?.stageOrder ?? deriveStageOrderFromLineupForSync(payload?.lineup || [])
  );
  const lineupSlots = buildEventLineupSlotsFromArchive(payload?.lineup || [], startDate, endDate, dayRolloverHour, timeZone);
  const lineupArtists = buildEventLineupArtistsFromArchive(payload?.lineupArtists || [], payload?.lineup || []);
  const computedStatus = resolveArchiveEventStatusForSync(payload?.canceled, startDate, endDate);
  const status = normalizeArchiveEventStatus(payload?.status, computedStatus) || computedStatus;
  const archiveFestivalId = String(payload?.festivalId || fest?.info?.festivalId || '').trim();
  const websiteFromSocial = socialLinks.find((item) => String(item?.type || '').toLowerCase() === 'website')?.url || '';
  const websiteFromRef = referenceLinks.find((link) => /^https?:\/\//i.test(String(link || '').trim())) || '';
  const officialWebsite = String(
    payload?.officialWebsite || fest?.info?.officialWebsite || websiteFromSocial || websiteFromRef || ''
  ).trim();
  const eventType = String(payload?.eventType || fest?.info?.eventType || 'festival').trim() || 'festival';
  const wikiFestivalIdRaw = String(
    payload?.wikiFestivalId ?? fest?.info?.wikiFestivalId ?? fest?.info?.wikiFestival?.id ?? ''
  ).trim();
  const wikiFestivalId = wikiFestivalIdRaw || null;
  const organizerName = String(payload?.organizerName || fest?.info?.organizerName || '').trim();
  const hasTicketPriceMin = Object.prototype.hasOwnProperty.call(payload || {}, 'ticketPriceMin');
  const hasTicketPriceMax = Object.prototype.hasOwnProperty.call(payload || {}, 'ticketPriceMax');
  const hasTicketCurrency = Object.prototype.hasOwnProperty.call(payload || {}, 'ticketCurrency');
  const hasTicketUrl = Object.prototype.hasOwnProperty.call(payload || {}, 'ticketUrl');
  const hasTicketNotes = Object.prototype.hasOwnProperty.call(payload || {}, 'ticketNotes');
  const ticketPriceMin = normalizeTicketPriceValue(
    hasTicketPriceMin ? payload?.ticketPriceMin : fest?.info?.ticketPriceMin
  );
  const ticketPriceMax = normalizeTicketPriceValue(
    hasTicketPriceMax ? payload?.ticketPriceMax : fest?.info?.ticketPriceMax
  );
  const ticketCurrency = String(
    (hasTicketCurrency ? payload?.ticketCurrency : fest?.info?.ticketCurrency) || ''
  ).trim().toUpperCase();
  const ticketUrl = String(
    (hasTicketUrl ? payload?.ticketUrl : fest?.info?.ticketUrl) || ''
  ).trim();
  const ticketNotes = String(
    (hasTicketNotes ? payload?.ticketNotes : fest?.info?.ticketNotes) || ''
  ).trim();
  const locationPoint = normalizeLocationPointForSync(payload?.locationPoint ?? fest?.info?.locationPoint ?? null);
  const result = {
    name,
    nameI18n: nameBi,
    cityI18n: cityBi,
    countryI18n: countryBi,
    archiveFestivalId,
    sourceProvider: String(source?.provider || '').trim() || null,
    sourceEventUrl: String(source?.eventUrl || '').trim() || null,
    wikiFestivalId,
    referenceLinks,
    socialLinks,
    lineupArtists,
    lineupSlots,
    dayRolloverHour,
    timeZone,
    stageOrder,
    startDate,
    endDate,
    status,
    eventType,
    organizerName: organizerName || null,
    manualLocation: manualLocation || null,
    city: city || null,
    country: country || null,
    officialWebsite: officialWebsite || null,
    ticketPriceMin,
    ticketPriceMax,
    ticketCurrency: ticketCurrency || null,
    ticketUrl: ticketUrl || null,
    ticketNotes: ticketNotes || null,
    locationPoint: locationPoint || null,
  };
  const description = String(payload?.description || fest?.info?.description || '').trim();
  if (description) {
    result.description = description;
    result.descriptionI18n = normalizeBiTextValue(
      payload?.descriptionI18n ?? fest?.info?.descriptionI18n ?? description,
      description
    );
  }
  return result;
}

async function findBackendEventByArchiveFestivalId(archiveFestivalId, authHeaders) {
  const target = String(archiveFestivalId || '').trim().toLowerCase();
  if (!target) return null;
  for (let page = 1; page <= EVENT_SYNC_LOOKUP_MAX_PAGES; page += 1) {
    const query = new URLSearchParams({
      page: String(page),
      limit: String(EVENT_SYNC_LOOKUP_LIMIT),
      status: 'all',
    });
    const resp = await apiGet(`/api/raver/events?${query.toString()}`, authHeaders);
    const items = Array.isArray(resp?.data?.items) ? resp.data.items : [];
    const found = items.find((item) =>
      String(item?.archiveFestivalId || '').trim().toLowerCase() === target
    );
    if (found) return found;
    const totalPages = Number(resp?.pagination?.totalPages || 0);
    if (totalPages > 0 && page >= totalPages) break;
    if (!items.length) break;
  }
  return null;
}
