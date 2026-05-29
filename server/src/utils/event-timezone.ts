export const DEFAULT_EVENT_TIME_ZONE = 'Asia/Shanghai';

type DateBoundary = 'start' | 'end';

type LocalDateTimeParts = {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
  millisecond: number;
};

const DATE_ONLY_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;
const LOCAL_DATE_TIME_PATTERN = /^(\d{4})-(\d{2})-(\d{2})(?:[T\s](\d{1,2})(?::(\d{1,2})(?::(\d{1,2})(?:\.(\d{1,3}))?)?)?)?$/;
const EXPLICIT_ZONE_PATTERN = /(?:[zZ]|[+-]\d{2}:?\d{2})$/;

const intlFormatterCache = new Map<string, Intl.DateTimeFormat>();

const getCachedDateTimeFormatter = (
  locale: string,
  timeZone: string,
  options: Intl.DateTimeFormatOptions
): Intl.DateTimeFormat => {
  const key = `${locale}__${timeZone}__${JSON.stringify(options)}`;
  const cached = intlFormatterCache.get(key);
  if (cached) return cached;
  const formatter = new Intl.DateTimeFormat(locale, { ...options, timeZone });
  intlFormatterCache.set(key, formatter);
  return formatter;
};

export const isValidEventTimeZone = (value: unknown): value is string => {
  if (typeof value !== 'string' || !value.trim()) return false;
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: value.trim() });
    return true;
  } catch (_error) {
    return false;
  }
};

export const normalizeEventTimeZone = (value: unknown, fallback = DEFAULT_EVENT_TIME_ZONE): string => {
  const candidate = typeof value === 'string' && value.trim() ? value.trim() : fallback;
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: candidate });
    return candidate;
  } catch (_error) {
    return fallback;
  }
};

const parseClockParts = (
  clock: unknown,
  boundary: DateBoundary
): Pick<LocalDateTimeParts, 'hour' | 'minute' | 'second' | 'millisecond'> => {
  const fallback = boundary === 'start'
    ? { hour: 0, minute: 0, second: 0, millisecond: 0 }
    : { hour: 23, minute: 59, second: 59, millisecond: 0 };
  if (typeof clock !== 'string') return fallback;
  const match = clock.trim().match(/^(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$/);
  if (!match) return fallback;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  const second = Number(match[3] ?? '0');
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59 || second < 0 || second > 59) {
    return fallback;
  }
  return { hour, minute, second, millisecond: 0 };
};

const parseLocalDateTimeParts = (
  value: string,
  boundary: DateBoundary,
  clock?: unknown
): LocalDateTimeParts | null => {
  const dateOnly = value.match(DATE_ONLY_PATTERN);
  if (dateOnly) {
    const clockParts = parseClockParts(clock, boundary);
    return {
      year: Number(dateOnly[1]),
      month: Number(dateOnly[2]),
      day: Number(dateOnly[3]),
      ...clockParts,
    };
  }

  const local = value.match(LOCAL_DATE_TIME_PATTERN);
  if (!local) return null;
  return {
    year: Number(local[1]),
    month: Number(local[2]),
    day: Number(local[3]),
    hour: Number(local[4] ?? (boundary === 'start' ? 0 : 23)),
    minute: Number(local[5] ?? (boundary === 'start' ? 0 : 59)),
    second: Number(local[6] ?? (boundary === 'start' ? 0 : 59)),
    millisecond: Number(String(local[7] ?? '0').padEnd(3, '0')),
  };
};

const getTimeZoneOffsetMs = (timeZone: string, instant: Date): number => {
  const parts = getCachedDateTimeFormatter('en-US', timeZone, {
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(instant);

  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  const asUtc = Date.UTC(
    Number(values.year),
    Number(values.month) - 1,
    Number(values.day),
    Number(values.hour),
    Number(values.minute),
    Number(values.second)
  );
  return asUtc - instant.getTime();
};

export const getLocalDateTimePartsForInstant = (instant: Date, timeZone: string): LocalDateTimeParts | null => {
  if (!(instant instanceof Date) || Number.isNaN(instant.getTime())) return null;
  const parts = getCachedDateTimeFormatter('en-US', timeZone, {
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(instant);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
    hour: Number(values.hour),
    minute: Number(values.minute),
    second: Number(values.second),
    millisecond: instant.getUTCMilliseconds(),
  };
};

const localDateTimePartsMatch = (instant: Date, parts: LocalDateTimeParts, timeZone: string): boolean => {
  const actual = getLocalDateTimePartsForInstant(instant, timeZone);
  return Boolean(
    actual
    && actual.year === parts.year
    && actual.month === parts.month
    && actual.day === parts.day
    && actual.hour === parts.hour
    && actual.minute === parts.minute
    && actual.second === parts.second
    && actual.millisecond === parts.millisecond
  );
};

export const zonedTimeToUtc = (parts: LocalDateTimeParts, timeZoneRaw: unknown): Date => {
  const timeZone = normalizeEventTimeZone(timeZoneRaw);
  const utcGuess = Date.UTC(
    parts.year,
    parts.month - 1,
    parts.day,
    parts.hour,
    parts.minute,
    parts.second,
    parts.millisecond
  );
  let instant = new Date(utcGuess - getTimeZoneOffsetMs(timeZone, new Date(utcGuess)));
  instant = new Date(utcGuess - getTimeZoneOffsetMs(timeZone, instant));
  if (!localDateTimePartsMatch(instant, parts, timeZone)) {
    return new Date(NaN);
  }
  // Fall-back DST can produce the same wall time twice. Prefer the earlier real instant.
  for (let minutes = 1; minutes <= 180; minutes += 1) {
    const earlier = new Date(instant.getTime() - minutes * 60_000);
    if (localDateTimePartsMatch(earlier, parts, timeZone)) {
      instant = earlier;
    }
  }
  return instant;
};

export const parseEventDateInput = (
  value: unknown,
  timeZoneRaw: unknown,
  boundary: DateBoundary,
  clock?: unknown
): Date | null => {
  if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!trimmed) return null;

  if (!DATE_ONLY_PATTERN.test(trimmed) && EXPLICIT_ZONE_PATTERN.test(trimmed)) {
    const parsed = new Date(trimmed);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  const parts = parseLocalDateTimeParts(trimmed, boundary, clock);
  if (parts) {
    const parsed = zonedTimeToUtc(parts, timeZoneRaw);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  const parsed = new Date(trimmed);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

export const eventDateKey = (date: Date, timeZoneRaw: unknown): string => {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) return '';
  const timeZone = normalizeEventTimeZone(timeZoneRaw);
  const parts = getCachedDateTimeFormatter('en-CA', timeZone, {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
};

export const eventDateOnlyToStorageDate = (date: Date, timeZoneRaw: unknown): Date => {
  const key = eventDateKey(date, timeZoneRaw);
  const parsed = parseEventDateInput(key, 'UTC', 'start');
  if (!parsed) {
    return new Date(NaN);
  }
  return parsed;
};

export const storageDateToEventDate = (date: Date, timeZoneRaw: unknown): Date => {
  const key = eventDateKey(date, 'UTC');
  const parsed = parseEventDateInput(key, timeZoneRaw, 'start', '12:00:00');
  if (!parsed) {
    return new Date(NaN);
  }
  return parsed;
};

export const startOfEventDay = (date: Date, timeZoneRaw: unknown): Date => {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
    return new Date(NaN);
  }
  const timeZone = normalizeEventTimeZone(timeZoneRaw);
  const parts = getCachedDateTimeFormatter('en-CA', timeZone, {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return zonedTimeToUtc({
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
    hour: 0,
    minute: 0,
    second: 0,
    millisecond: 0,
  }, timeZone);
};

export const setEventDayAndKeepTime = (
  timeSource: Date,
  eventStartDate: Date,
  festivalDayIndex: number,
  timeZoneRaw: unknown
): Date => {
  if (
    !(timeSource instanceof Date)
    || Number.isNaN(timeSource.getTime())
    || !(eventStartDate instanceof Date)
    || Number.isNaN(eventStartDate.getTime())
  ) {
    return new Date(NaN);
  }
  const timeZone = normalizeEventTimeZone(timeZoneRaw);
  const eventStartDay = startOfEventDay(eventStartDate, timeZone);
  if (Number.isNaN(eventStartDay.getTime())) {
    return new Date(NaN);
  }
  const timeParts = getCachedDateTimeFormatter('en-US', timeZone, {
    hourCycle: 'h23',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(timeSource);
  const timeValues = Object.fromEntries(timeParts.map((part) => [part.type, part.value]));
  const targetDay = new Date(eventStartDay.getTime() + Math.max(0, festivalDayIndex - 1) * 86_400_000);
  if (Number.isNaN(targetDay.getTime())) {
    return new Date(NaN);
  }
  const dateParts = getCachedDateTimeFormatter('en-CA', timeZone, {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(targetDay);
  const dateValues = Object.fromEntries(dateParts.map((part) => [part.type, part.value]));
  const base = zonedTimeToUtc({
    year: Number(dateValues.year),
    month: Number(dateValues.month),
    day: Number(dateValues.day),
    hour: Number(timeValues.hour),
    minute: Number(timeValues.minute),
    second: Number(timeValues.second),
    millisecond: timeSource.getUTCMilliseconds(),
  }, timeZone);
  return base;
};

export const diffEventDays = (from: Date, to: Date, timeZoneRaw: unknown): number => {
  if (
    !(from instanceof Date)
    || Number.isNaN(from.getTime())
    || !(to instanceof Date)
    || Number.isNaN(to.getTime())
  ) {
    return 0;
  }
  const fromStart = startOfEventDay(from, timeZoneRaw).getTime();
  const toStart = startOfEventDay(to, timeZoneRaw).getTime();
  if (Number.isNaN(fromStart) || Number.isNaN(toStart)) {
    return 0;
  }
  return Math.floor((toStart - fromStart) / 86_400_000);
};

export const getEventHour = (date: Date, timeZoneRaw: unknown): number => {
  const timeZone = normalizeEventTimeZone(timeZoneRaw);
  const hour = getCachedDateTimeFormatter('en-US', timeZone, {
    hourCycle: 'h23',
    hour: '2-digit',
  }).format(date);
  return Number(hour);
};
