export const DEFAULT_BUSINESS_TIME_ZONE = 'Asia/Shanghai';

const ZONE_LABELS_ZH: Record<string, string> = {
  'Asia/Shanghai': '北京时间',
  'Asia/Tokyo': '东京时间',
  'Asia/Seoul': '首尔时间',
  'America/Los_Angeles': '洛杉矶时间',
  'America/New_York': '纽约时间',
  'America/Chicago': '芝加哥时间',
  'America/Denver': '丹佛时间',
  'Europe/London': '伦敦时间',
  'Europe/Paris': '巴黎时间',
  'Europe/Berlin': '柏林时间',
  UTC: 'UTC',
};

export const getSystemTimeZone = (): string => {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || DEFAULT_BUSINESS_TIME_ZONE;
  } catch (_error) {
    return DEFAULT_BUSINESS_TIME_ZONE;
  }
};

export const getTimeZoneLabel = (timeZone = getSystemTimeZone()): string =>
  ZONE_LABELS_ZH[timeZone] || timeZone;

export const getSystemTimeZoneLabel = (): string => getTimeZoneLabel(getSystemTimeZone());

export const normalizeDisplayTimeZone = (timeZone: string | null | undefined): string => {
  if (!timeZone || !timeZone.trim()) return DEFAULT_BUSINESS_TIME_ZONE;
  try {
    new Intl.DateTimeFormat('zh-CN', { timeZone: timeZone.trim() });
    return timeZone.trim();
  } catch (_error) {
    return DEFAULT_BUSINESS_TIME_ZONE;
  }
};

const toDate = (value: string | Date | null | undefined): Date | null => {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};

const getZonedDateTimeParts = (value: string | Date | number, timeZone: string) => {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: normalizeDisplayTimeZone(timeZone),
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  const hour = Number(values.hour === '24' ? '0' : values.hour);
  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
    hour,
    minute: Number(values.minute),
    second: Number(values.second),
  };
};

const formatDateKeyFromUtcDate = (date: Date): string =>
  new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'UTC',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);

const addDaysToDateKey = (dateKey: string, days: number): string => {
  const [year, month, day] = dateKey.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  date.setUTCDate(date.getUTCDate() + days);
  return formatDateKeyFromUtcDate(date);
};

export const zonedWallTimeToUtcMs = (
  dateTimeValue: string,
  timeZone: string | null | undefined
): number => {
  const match = dateTimeValue
    .trim()
    .match(/^(\d{4})-(\d{2})-(\d{2})[T ](\d{1,2}):(\d{2})(?::(\d{2}))?$/);
  if (!match) return NaN;

  const target = {
    year: Number(match[1]),
    month: Number(match[2]),
    day: Number(match[3]),
    hour: Number(match[4]),
    minute: Number(match[5]),
    second: Number(match[6] ?? '0'),
  };
  if (
    target.month < 1 ||
    target.month > 12 ||
    target.day < 1 ||
    target.day > 31 ||
    target.hour < 0 ||
    target.hour > 23 ||
    target.minute < 0 ||
    target.minute > 59 ||
    target.second < 0 ||
    target.second > 59
  ) {
    return NaN;
  }

  const displayTimeZone = normalizeDisplayTimeZone(timeZone);
  let utcMs = Date.UTC(
    target.year,
    target.month - 1,
    target.day,
    target.hour,
    target.minute,
    target.second
  );

  for (let i = 0; i < 4; i += 1) {
    const actual = getZonedDateTimeParts(utcMs, displayTimeZone);
    if (!actual) return NaN;
    const actualAsUtc = Date.UTC(
      actual.year,
      actual.month - 1,
      actual.day,
      actual.hour,
      actual.minute,
      actual.second
    );
    const targetAsUtc = Date.UTC(
      target.year,
      target.month - 1,
      target.day,
      target.hour,
      target.minute,
      target.second
    );
    const diff = targetAsUtc - actualAsUtc;
    if (diff === 0) break;
    utcMs += diff;
  }

  const verified = getZonedDateTimeParts(utcMs, displayTimeZone);
  if (
    !verified ||
    verified.year !== target.year ||
    verified.month !== target.month ||
    verified.day !== target.day ||
    verified.hour !== target.hour ||
    verified.minute !== target.minute ||
    verified.second !== target.second
  ) {
    return NaN;
  }

  return utcMs;
};

export const getFestivalDayKeyForInstant = (
  value: string | Date | number,
  timeZone: string | null | undefined,
  dayRolloverHour = 6
): string => {
  const displayTimeZone = normalizeDisplayTimeZone(timeZone);
  const parts = getZonedDateTimeParts(value, displayTimeZone);
  if (!parts) return '';
  const dateKey = `${String(parts.year).padStart(4, '0')}-${String(parts.month).padStart(2, '0')}-${String(parts.day).padStart(2, '0')}`;
  return parts.hour >= dayRolloverHour ? dateKey : addDaysToDateKey(dateKey, -1);
};

export const floorInstantToZonedHourMs = (
  value: string | Date | number,
  timeZone: string | null | undefined
): number => {
  const displayTimeZone = normalizeDisplayTimeZone(timeZone);
  const parts = getZonedDateTimeParts(value, displayTimeZone);
  if (!parts) return NaN;
  return zonedWallTimeToUtcMs(
    `${String(parts.year).padStart(4, '0')}-${String(parts.month).padStart(2, '0')}-${String(parts.day).padStart(2, '0')}T${String(parts.hour).padStart(2, '0')}:00:00`,
    displayTimeZone
  );
};

export const ceilInstantToZonedHourMs = (
  value: string | Date | number,
  timeZone: string | null | undefined
): number => {
  const displayTimeZone = normalizeDisplayTimeZone(timeZone);
  const parts = getZonedDateTimeParts(value, displayTimeZone);
  if (!parts) return NaN;
  if (parts.minute === 0 && parts.second === 0) {
    return floorInstantToZonedHourMs(value, displayTimeZone);
  }
  for (let hourOffset = 1; hourOffset <= 4; hourOffset += 1) {
    const wallHour = new Date(Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour + hourOffset));
    const nextDateKey = formatDateKeyFromUtcDate(wallHour);
    const nextHour = wallHour.getUTCHours();
    const utcMs = zonedWallTimeToUtcMs(
      `${nextDateKey}T${String(nextHour).padStart(2, '0')}:00:00`,
      displayTimeZone
    );
    if (!Number.isNaN(utcMs)) return utcMs;
  }
  return NaN;
};

export const formatDateInSystemTimeZone = (
  value: string | Date | null | undefined,
  options: Intl.DateTimeFormatOptions = {}
): string => {
  const date = toDate(value);
  if (!date) return '未知时间';
  return date.toLocaleDateString('zh-CN', {
    timeZone: getSystemTimeZone(),
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    ...options,
  });
};

export const formatDateTimeInSystemTimeZone = (
  value: string | Date | null | undefined,
  options: Intl.DateTimeFormatOptions = {}
): string => {
  const date = toDate(value);
  if (!date) return '未知时间';
  return date.toLocaleString('zh-CN', {
    timeZone: getSystemTimeZone(),
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    ...options,
  });
};

export const formatDateWithSystemTimeZoneLabel = (
  value: string | Date | null | undefined,
  options?: Intl.DateTimeFormatOptions
): string => `${formatDateInSystemTimeZone(value, options)} (${getSystemTimeZoneLabel()})`;

export const formatDateInTimeZone = (
  value: string | Date | null | undefined,
  timeZone: string | null | undefined,
  options: Intl.DateTimeFormatOptions = {}
): string => {
  const date = toDate(value);
  if (!date) return '未知时间';
  const displayTimeZone = normalizeDisplayTimeZone(timeZone);
  return date.toLocaleDateString('zh-CN', {
    timeZone: displayTimeZone,
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    ...options,
  });
};

export const formatDateWithTimeZoneLabel = (
  value: string | Date | null | undefined,
  timeZone: string | null | undefined,
  options?: Intl.DateTimeFormatOptions
): string => {
  const displayTimeZone = normalizeDisplayTimeZone(timeZone);
  return `${formatDateInTimeZone(value, displayTimeZone, options)} (${getTimeZoneLabel(displayTimeZone)})`;
};

export const formatDateTimeWithSystemTimeZoneLabel = (
  value: string | Date | null | undefined,
  options?: Intl.DateTimeFormatOptions
): string => `${formatDateTimeInSystemTimeZone(value, options)} (${getSystemTimeZoneLabel()})`;

export const parseDateInputAsBusinessDateTime = (
  dateValue: string,
  timeValue = '00:00',
  timeZone = DEFAULT_BUSINESS_TIME_ZONE
): string | null => {
  const dateMatch = dateValue.trim().match(/^(\d{4})-(\d{2})-(\d{2})$/);
  const timeMatch = timeValue.trim().match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?$/);
  if (!dateMatch || !timeMatch) return null;
  const hour = Number(timeMatch[1]);
  const minute = Number(timeMatch[2]);
  const second = Number(timeMatch[3] ?? '0');
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59 || second < 0 || second > 59) return null;
  return `${dateMatch[1]}-${dateMatch[2]}-${dateMatch[3]}T${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:${String(second).padStart(2, '0')}`;
};

export const formatDateInputInTimeZone = (
  value: string | Date | null | undefined,
  timeZone: string | null | undefined
): string => {
  const date = toDate(value);
  if (!date) return '';
  const displayTimeZone = normalizeDisplayTimeZone(timeZone);
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: displayTimeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
};

export const formatClockTimeInTimeZone = (
  value: string | Date | null | undefined,
  timeZone: string | null | undefined
): string => {
  const date = toDate(value);
  if (!date) return '';
  const displayTimeZone = normalizeDisplayTimeZone(timeZone);
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: displayTimeZone,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.hour}:${values.minute}`;
};
