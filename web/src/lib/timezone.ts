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
