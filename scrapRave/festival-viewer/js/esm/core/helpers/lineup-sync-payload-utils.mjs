// ESM pilot module for lineup/date/payload pure helper chain.
// Runtime-isolated: used by tests/tooling first.

export function hasExplicitYearInDateTextForSync(value) {
  const src = String(value || '')
    .replace(/[０-９]/g, (ch) => String.fromCharCode(ch.charCodeAt(0) - 0xFEE0))
    .trim();
  if (!src) return false;
  return /(?:^|[^\d])(19|20)\d{2}(?:\s*年)?(?!\d)/.test(src);
}

export function normalizeArchiveDateTextForSync(value) {
  const src = String(value || '').trim();
  if (!src) return '';
  const isoLikePrefix = src.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (isoLikePrefix) return `${isoLikePrefix[1]}-${isoLikePrefix[2]}-${isoLikePrefix[3]}`;
  const m = src.match(/^(\d{4})[\/.\-](\d{1,2})[\/.\-](\d{1,2})$/);
  if (m) return `${m[1]}-${String(Number(m[2])).padStart(2, '0')}-${String(Number(m[3])).padStart(2, '0')}`;
  const cn = src.match(/^(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日?$/);
  if (cn) return `${cn[1]}-${String(Number(cn[2])).padStart(2, '0')}-${String(Number(cn[3])).padStart(2, '0')}`;
  const parsed = new Date(src);
  if (!Number.isNaN(parsed.getTime())) {
    if (!hasExplicitYearInDateTextForSync(src) && parsed.getFullYear() === 2001) return src;
    const y = parsed.getFullYear();
    const mo = String(parsed.getMonth() + 1).padStart(2, '0');
    const d = String(parsed.getDate()).padStart(2, '0');
    return `${y}-${mo}-${d}`;
  }
  return src;
}

export function parseArchiveDateOnlyForSync(dateText) {
  const normalized = normalizeArchiveDateTextForSync(dateText);
  const m = normalized.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!m) return null;
  const date = new Date(`${m[1]}-${m[2]}-${m[3]}T00:00:00`);
  return Number.isNaN(date.getTime()) ? null : date;
}

export function normalizeDateOnlyForSync(value) {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) return null;
  const out = new Date(value);
  out.setHours(0, 0, 0, 0);
  return out;
}

export function parseLineupDayIndexForSync(value) {
  const text = String(value || '').trim();
  if (!text) return null;
  const en = text.match(/\bday\s*([1-9]\d*)\b/i);
  if (en) return Number(en[1]);
  const cn = text.match(/第?\s*([1-9]\d*)\s*天/);
  if (cn) return Number(cn[1]);
  return null;
}

export function parseLineupMonthDayCandidatesForSync(value) {
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
    dec: 12, december: 12,
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

export function resolveLineupDateForSync(dateText, eventStartDate, eventEndDate) {
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
      rangeStart.getFullYear() + 1,
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

export function parseLineupTimeRangeForSync(value) {
  const text = String(value || '').trim();
  if (!text) return { startHM: null, endHM: null };
  const pair = text.match(/(\d{1,2}:\d{2})\s*(?:—|–|~|-|to|TO|至|到)\s*(\d{1,2}:\d{2})/);
  if (pair) return { startHM: pair[1], endHM: pair[2] };
  const one = text.match(/(\d{1,2}:\d{2})/);
  if (one) return { startHM: one[1], endHM: null };
  return { startHM: null, endHM: null };
}

export function buildLineupDateTimeForSync(date, hourMinute, fallbackMinutes = 0) {
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

export function isValidTimeZoneForSync(timeZone) {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone });
    return true;
  } catch (_error) {
    return false;
  }
}

export function normalizeTimeZoneForSync(value, fallback = 'UTC') {
  const candidate = String(value || '').trim() || fallback;
  return isValidTimeZoneForSync(candidate) ? candidate : fallback;
}

export function timeZoneOffsetMsForSync(timeZone, instant) {
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

export function zonedDateTimeToUtcForSync(date, hourMinute, timeZoneRaw, fallbackMinutes = 0) {
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

export function normalizeDayRolloverHourForSync(value, fallback = 6) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(0, Math.min(23, Math.floor(parsed)));
}

export function normalizeStageOrderForSync(value, fallback = []) {
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

function defaultNormalizeLineupEntry(entry) {
  return {
    musician: String(entry?.musician || '').trim(),
    stage: String(entry?.stage || '').trim(),
    date: String(entry?.date || '').trim(),
    time: String(entry?.time || '').trim(),
    djId: String(entry?.djId || '').trim(),
    djIds: Array.isArray(entry?.djIds) ? entry.djIds : [],
  };
}

function defaultIsLineupDjIdPlaceholder(id) {
  return /^pending:/i.test(String(id || '').trim());
}

export function buildEventLineupSlotsFromArchive(
  lineup,
  eventStartDateText,
  eventEndDateText,
  dayRolloverHourRaw = 6,
  options = {}
) {
  if (!Array.isArray(lineup)) return [];
  const normalizeLineupEntry = typeof options.normalizeLineupEntry === 'function'
    ? options.normalizeLineupEntry
    : defaultNormalizeLineupEntry;
  const isLineupDjIdPlaceholder = typeof options.isLineupDjIdPlaceholder === 'function'
    ? options.isLineupDjIdPlaceholder
    : defaultIsLineupDjIdPlaceholder;

  const parsedStart = parseArchiveDateOnlyForSync(eventStartDateText);
  const parsedEnd = parseArchiveDateOnlyForSync(eventEndDateText) || parsedStart;
  const eventStartDate = normalizeDateOnlyForSync(parsedStart) || normalizeDateOnlyForSync(new Date()) || new Date();
  const eventEndDate = normalizeDateOnlyForSync(parsedEnd) || eventStartDate;
  const dayRolloverHour = normalizeDayRolloverHourForSync(dayRolloverHourRaw, 6);
  const timeZone = normalizeTimeZoneForSync(options.timeZone || options.timezone || 'UTC');
  const slots = [];

  for (let i = 0; i < lineup.length; i += 1) {
    const normalized = normalizeLineupEntry(lineup[i] || {});
    const djName = String(normalized.musician || '').trim();
    if (!djName) continue;
    const dateCandidate = resolveLineupDateForSync(normalized.date, eventStartDate, eventEndDate);
    const { startHM, endHM } = parseLineupTimeRangeForSync(normalized.time);
    const normalizedDate = normalizeDateOnlyForSync(dateCandidate);
    const naturalDayOffset = Math.max(0, Math.floor((normalizedDate.getTime() - eventStartDate.getTime()) / (24 * 60 * 60 * 1000)));
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
    const djIds = rawDjIds.map((id) => String(id || '').trim()).filter(Boolean);
    const firstBoundId = djIds.find((id) => !isLineupDjIdPlaceholder(id)) || '';
    const normalizedPrimary = String(normalized.djId || '').trim();
    const djId = (!isLineupDjIdPlaceholder(normalizedPrimary) ? normalizedPrimary : '') || firstBoundId;
    if (djId) row.djId = djId;
    if (djIds.length) row.djIds = djIds;
    slots.push(row);
  }

  return slots;
}

export function parseBackendEventImageAssets(value) {
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

export function pickPrimaryEventImageUrls(assets) {
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
