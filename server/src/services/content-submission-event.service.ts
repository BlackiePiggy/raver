import { Prisma, PrismaClient } from '@prisma/client';
import {
  DEFAULT_EVENT_TIME_ZONE,
  diffEventDays,
  eventDateKey,
  eventDateOnlyToStorageDate,
  getLocalDateTimePartsForInstant,
  normalizeEventTimeZone,
  parseEventDateInput,
  startOfEventDay,
  storageDateToEventDate,
  zonedTimeToUtc,
} from '../utils/event-timezone';
import { normalizeTriTextPayload, triTextToJson } from '../utils/i18n';
import {
  type CanonicalLineupSyncProfiling,
  type CanonicalLineupArtistInput,
  type CanonicalLineupSlotInput,
  normalizeCanonicalLineupArtists,
  syncCanonicalEventLineupAndTimetable,
} from './event-lineup-canonical.service';

const EVENT_SUBMISSION_TRANSACTION_TIMEOUT_MS = 120_000;
const EVENT_SUBMISSION_TRANSACTION_MAX_WAIT_MS = 30_000;
const EVENT_SUBMISSION_TRANSACTION_URL = typeof process.env.EVENT_SUBMISSION_TRANSACTION_URL === 'string'
  && process.env.EVENT_SUBMISSION_TRANSACTION_URL.trim()
  ? process.env.EVENT_SUBMISSION_TRANSACTION_URL.trim()
  : typeof process.env.DIRECT_URL === 'string' && process.env.DIRECT_URL.trim()
    ? process.env.DIRECT_URL.trim()
    : null;
const EVENT_SUBMISSION_TRANSACTION_URL_SOURCE = typeof process.env.EVENT_SUBMISSION_TRANSACTION_URL === 'string'
  && process.env.EVENT_SUBMISSION_TRANSACTION_URL.trim()
  ? 'event_submission_transaction_url'
  : typeof process.env.DIRECT_URL === 'string' && process.env.DIRECT_URL.trim()
    ? 'direct_url'
    : 'database_url';
const EVENT_SUBMISSION_TRANSACTION_CLIENT = EVENT_SUBMISSION_TRANSACTION_URL
  && EVENT_SUBMISSION_TRANSACTION_URL !== process.env.DATABASE_URL
  ? new PrismaClient({
      datasources: {
        db: {
          url: EVENT_SUBMISSION_TRANSACTION_URL,
        },
      },
    })
  : null;

const LINEUP_DJ_ID_PLACEHOLDER = '__UNBOUND__';
const EVENT_LINEUP_SYNC_MODES = ['incremental_fill', 'exact_align'] as const;
type EventLineupSyncMode = typeof EVENT_LINEUP_SYNC_MODES[number];

const classifyTransactionConnectionMode = (url: string | null): 'supabase_pooler_session' | 'supabase_pooler_transaction' | 'direct_postgres' | 'unknown' => {
  if (!url) return 'unknown';
  try {
    const parsed = new URL(url);
    const host = parsed.hostname.toLowerCase();
    const port = parsed.port || '5432';
    if (host.includes('.pooler.supabase.com')) {
      if (port === '6543') return 'supabase_pooler_transaction';
      if (port === '5432') return 'supabase_pooler_session';
    }
    return 'direct_postgres';
  } catch {
    return 'unknown';
  }
};

export const getEventSubmissionTransactionConnectionInfo = (): {
  source: 'event_submission_transaction_url' | 'direct_url' | 'database_url';
  mode: 'supabase_pooler_session' | 'supabase_pooler_transaction' | 'direct_postgres' | 'unknown';
} => ({
  source: EVENT_SUBMISSION_TRANSACTION_URL_SOURCE,
  mode: classifyTransactionConnectionMode(EVENT_SUBMISSION_TRANSACTION_URL ?? process.env.DATABASE_URL ?? null),
});

export type SubmittedEventWeek = {
  weekIndex: number;
  label: string | null;
  startDate: Date;
  endDate: Date;
  sortOrder: number;
};

export type SubmittedEventDay = {
  eventDayId: string;
  weekIndex: number;
  dayIndexInWeek: number;
  overallDayIndex: number;
  label: string | null;
  weekday: string | null;
  date: Date;
  sortOrder: number;
};

export type SubmittedEventScheduleContext = {
  scheduleMode: 'single_day' | 'multi_day' | 'multi_week';
  timeZone: string;
  dayRolloverHour: number;
  weeks: SubmittedEventWeek[];
  eventDays: SubmittedEventDay[];
  startDate: Date;
  endDate: Date;
};

const cleanText = (value: unknown): string | undefined => {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed || undefined;
};

const hasOwn = (value: Record<string, unknown>, key: string): boolean =>
  Object.prototype.hasOwnProperty.call(value, key);

const resolveOptionalNullableTextField = (
  payload: Prisma.JsonObject,
  key: string
): string | null | undefined => {
  if (!hasOwn(payload, key)) return undefined;
  return cleanText(payload[key]) || null;
};

const resolveOptionalStringArrayField = (
  payload: Prisma.JsonObject,
  key: string
): string[] | undefined => {
  if (!hasOwn(payload, key)) return undefined;
  const value = payload[key];
  const source = Array.isArray(value)
    ? value
    : typeof value === 'string'
      ? value.split(/[\n,]/)
      : [];
  return Array.from(new Set(source.map((item) => cleanText(item)).filter((item): item is string => Boolean(item))));
};

const resolveOptionalJsonField = (
  payload: Prisma.JsonObject,
  key: string
): Prisma.InputJsonValue | typeof Prisma.JsonNull | undefined => {
  if (!hasOwn(payload, key)) return undefined;
  const value = payload[key];
  if (value == null) return Prisma.JsonNull;
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return Prisma.JsonNull;
    try {
      return JSON.parse(trimmed) as Prisma.InputJsonValue;
    } catch {
      return Prisma.JsonNull;
    }
  }
  return value as Prisma.InputJsonValue;
};

const resolveOptionalTriTextField = (
  payload: Prisma.JsonObject,
  key: string,
  fallback: string,
  options: {
    includeWhen?: boolean;
  } = {}
): Prisma.InputJsonValue | typeof Prisma.DbNull | undefined => {
  if (options.includeWhen === false) return undefined;
  if (!hasOwn(payload, key) && options.includeWhen === undefined) return undefined;
  const normalized = normalizeTriTextPayload(payload[key], fallback);
  return normalized ? triTextToJson(normalized) : Prisma.DbNull;
};

const resolveEventLineupSyncMode = (
  payload: Prisma.JsonObject | Prisma.InputJsonObject | Record<string, unknown>
): EventLineupSyncMode => {
  const raw = cleanText((payload as Record<string, unknown>).lineupSyncMode)?.toLowerCase();
  return raw && EVENT_LINEUP_SYNC_MODES.includes(raw as EventLineupSyncMode)
    ? raw as EventLineupSyncMode
    : 'incremental_fill';
};

export class ActiveEventEditSubmissionError extends Error {
  readonly code = 'ACTIVE_EVENT_EDIT_SUBMISSION_EXISTS';
  readonly details: {
    targetEventId: string;
    activeSubmissionId: string;
    activeSubmissionStatus: string;
  };

  constructor(details: {
    targetEventId: string;
    activeSubmissionId: string;
    activeSubmissionStatus: string;
  }) {
    super('该活动已有一个编辑任务正在处理中，请等待入库完成后再继续编辑');
    this.name = 'ActiveEventEditSubmissionError';
    this.details = details;
  }
}

const ACTIVE_EVENT_EDIT_SUBMISSION_STATUSES = ['pending', 'processing', 'reviewing'] as const;

const isPlainObject = (value: unknown): value is Record<string, unknown> =>
  !!value && typeof value === 'object' && !Array.isArray(value);

export class EventSubmissionValidationError extends Error {
  readonly code = 'EVENT_SUBMISSION_INVALID_PAYLOAD';

  constructor(message: string) {
    super(message);
    this.name = 'EventSubmissionValidationError';
  }
}

const normalizeScheduleMode = (value: unknown): 'single_day' | 'multi_day' | 'multi_week' => {
  const normalized = cleanText(value)?.toLowerCase().replace(/-/g, '_');
  switch (normalized) {
    case 'single_day':
    case 'multi_day':
    case 'multi_week':
      return normalized;
    default:
      throw new EventSubmissionValidationError('schedule.mode 必须是 single_day、multi_day 或 multi_week');
  }
};

const parseEventDateOnlyOrThrow = (
  value: unknown,
  label: string,
  timeZone: string
): Date => {
  let parsed: Date | null = null;
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    parsed = parseEventDateInput(eventDateKey(value, timeZone), timeZone, 'start');
  } else {
    const text = cleanText(value);
    parsed = text ? parseEventDateInput(text, timeZone, 'start') : null;
  }
  if (!parsed) {
    throw new EventSubmissionValidationError(`${label} 缺少有效日期`);
  }
  const normalized = startOfEventDay(parsed, timeZone);
  if (Number.isNaN(normalized.getTime())) {
    throw new EventSubmissionValidationError(`${label} 日期无效`);
  }
  return normalized;
};

const parsePositiveIntOrThrow = (value: unknown, label: string): number => {
  const parsed = integerOrNull(value);
  if (parsed === null || parsed < 1) {
    throw new EventSubmissionValidationError(`${label} 必须是大于 0 的整数`);
  }
  return parsed;
};

const normalizeNullableText = (value: unknown): string | null => cleanText(value) || null;

const parseSubmittedEventWeeks = (
  value: unknown,
  timeZone: string
): SubmittedEventWeek[] => {
  if (!Array.isArray(value)) {
    throw new EventSubmissionValidationError('weeks 必须是数组');
  }
  const weeks = value.map((item, index) => {
    if (!isPlainObject(item)) {
      throw new EventSubmissionValidationError(`weeks[${index}] 必须是对象`);
    }
    const weekIndex = parsePositiveIntOrThrow(item.weekIndex, `weeks[${index}].weekIndex`);
    const startDate = parseEventDateOnlyOrThrow(item.startDate, `weeks[${index}].startDate`, timeZone);
    const endDate = parseEventDateOnlyOrThrow(item.endDate, `weeks[${index}].endDate`, timeZone);
    if (endDate.getTime() < startDate.getTime()) {
      throw new EventSubmissionValidationError(`weeks[${index}] 的 endDate 不能早于 startDate`);
    }
    return {
      weekIndex,
      label: normalizeNullableText(item.label),
      startDate,
      endDate,
      sortOrder: parsePositiveIntOrThrow(item.sortOrder ?? weekIndex, `weeks[${index}].sortOrder`),
    } satisfies SubmittedEventWeek;
  });

  if (weeks.length === 0) {
    throw new EventSubmissionValidationError('weeks 不能为空');
  }

  const seenWeekIndexes = new Set<number>();
  for (const week of weeks) {
    if (seenWeekIndexes.has(week.weekIndex)) {
      throw new EventSubmissionValidationError(`weeks 中存在重复的 weekIndex=${week.weekIndex}`);
    }
    seenWeekIndexes.add(week.weekIndex);
  }

  return weeks.slice().sort((a, b) => a.weekIndex - b.weekIndex || a.sortOrder - b.sortOrder);
};

const parseSubmittedEventDays = (
  value: unknown,
  timeZone: string
): SubmittedEventDay[] => {
  if (!Array.isArray(value)) {
    throw new EventSubmissionValidationError('eventDays 必须是数组');
  }
  const days = value.map((item, index) => {
    if (!isPlainObject(item)) {
      throw new EventSubmissionValidationError(`eventDays[${index}] 必须是对象`);
    }
    const eventDayId = cleanText(item.eventDayId);
    if (!eventDayId) {
      throw new EventSubmissionValidationError(`eventDays[${index}].eventDayId 不能为空`);
    }
    return {
      eventDayId,
      weekIndex: parsePositiveIntOrThrow(item.weekIndex, `eventDays[${index}].weekIndex`),
      dayIndexInWeek: parsePositiveIntOrThrow(item.dayIndexInWeek, `eventDays[${index}].dayIndexInWeek`),
      overallDayIndex: parsePositiveIntOrThrow(item.overallDayIndex, `eventDays[${index}].overallDayIndex`),
      label: normalizeNullableText(item.label),
      weekday: normalizeNullableText(item.weekday)?.toLowerCase() ?? null,
      date: parseEventDateOnlyOrThrow(item.date, `eventDays[${index}].date`, timeZone),
      sortOrder: parsePositiveIntOrThrow(item.sortOrder ?? item.overallDayIndex, `eventDays[${index}].sortOrder`),
    } satisfies SubmittedEventDay;
  });

  if (days.length === 0) {
    throw new EventSubmissionValidationError('eventDays 不能为空');
  }

  const seenEventDayIds = new Set<string>();
  const seenOverallIndexes = new Set<number>();
  const seenWeekDayKeys = new Set<string>();
  for (const day of days) {
    if (seenEventDayIds.has(day.eventDayId)) {
      throw new EventSubmissionValidationError(`eventDays 中存在重复的 eventDayId=${day.eventDayId}`);
    }
    if (seenOverallIndexes.has(day.overallDayIndex)) {
      throw new EventSubmissionValidationError(`eventDays 中存在重复的 overallDayIndex=${day.overallDayIndex}`);
    }
    const weekDayKey = `${day.weekIndex}:${day.dayIndexInWeek}`;
    if (seenWeekDayKeys.has(weekDayKey)) {
      throw new EventSubmissionValidationError(`eventDays 中存在重复的 week/day=${weekDayKey}`);
    }
    seenEventDayIds.add(day.eventDayId);
    seenOverallIndexes.add(day.overallDayIndex);
    seenWeekDayKeys.add(weekDayKey);
  }

  return days.slice().sort((a, b) => a.overallDayIndex - b.overallDayIndex || a.sortOrder - b.sortOrder);
};

const assertWeeksAndDaysConsistency = (
  scheduleMode: 'single_day' | 'multi_day' | 'multi_week',
  weeks: SubmittedEventWeek[],
  eventDays: SubmittedEventDay[],
  timeZone: string
): void => {
  if (scheduleMode === 'multi_week' && weeks.length < 2) {
    throw new EventSubmissionValidationError('multi_week 活动至少需要 2 个 weeks');
  }
  if (scheduleMode !== 'multi_week' && weeks.length !== 1) {
    throw new EventSubmissionValidationError(`${scheduleMode} 活动必须且只能有 1 个 week`);
  }
  if (scheduleMode === 'single_day' && eventDays.length !== 1) {
    throw new EventSubmissionValidationError('single_day 活动必须且只能有 1 个 eventDay');
  }
  if (scheduleMode === 'multi_day' && eventDays.length < 2) {
    throw new EventSubmissionValidationError('multi_day 活动至少需要 2 个 eventDays');
  }

  const weekByIndex = new Map(weeks.map((week) => [week.weekIndex, week]));
  for (const day of eventDays) {
    const week = weekByIndex.get(day.weekIndex);
    if (!week) {
      throw new EventSubmissionValidationError(`eventDay ${day.eventDayId} 引用了不存在的 weekIndex=${day.weekIndex}`);
    }
    const dayDate = day.date.getTime();
    if (dayDate < week.startDate.getTime() || dayDate > week.endDate.getTime()) {
      throw new EventSubmissionValidationError(`eventDay ${day.eventDayId} 的日期不在所属 week 范围内`);
    }
  }

  const orderedDays = eventDays.slice().sort((a, b) => a.overallDayIndex - b.overallDayIndex);
  for (const [index, day] of orderedDays.entries()) {
    if (day.overallDayIndex !== index + 1) {
      throw new EventSubmissionValidationError('eventDays.overallDayIndex 必须从 1 开始连续递增');
    }
  }

  const startDateKey = eventDateKey(orderedDays[0].date, timeZone);
  const endDateKey = eventDateKey(orderedDays[orderedDays.length - 1].date, timeZone);
  const firstWeekKey = eventDateKey(weeks[0].startDate, timeZone);
  const lastWeekKey = eventDateKey(weeks[weeks.length - 1].endDate, timeZone);
  if (startDateKey !== firstWeekKey || endDateKey !== lastWeekKey) {
    throw new EventSubmissionValidationError('weeks 与 eventDays 的整体起止日期不一致');
  }
};

export const normalizeSubmittedEventScheduleContext = (
  payload: Prisma.JsonObject | Prisma.InputJsonObject | Record<string, unknown>
): SubmittedEventScheduleContext => {
  const input = payload as Record<string, unknown>;
  const scheduleInput = isPlainObject(input.schedule) ? input.schedule : {};
  const timeZone = normalizeEventTimeZone(
    scheduleInput.timeZone ?? input.timeZone ?? input.timezone ?? input.eventTimeZone ?? DEFAULT_EVENT_TIME_ZONE
  );
  const dayRolloverHour = normalizeDayRolloverHour(
    scheduleInput.dayRolloverHour ?? input.dayRolloverHour,
    6
  );
  const scheduleMode = normalizeScheduleMode(scheduleInput.mode ?? input.scheduleMode ?? input.schedule_mode);
  const weeks = parseSubmittedEventWeeks(input.weeks, timeZone);
  const eventDays = parseSubmittedEventDays(input.eventDays, timeZone);
  assertWeeksAndDaysConsistency(scheduleMode, weeks, eventDays, timeZone);

  return {
    scheduleMode,
    timeZone,
    dayRolloverHour,
    weeks,
    eventDays,
    startDate: eventDays[0].date,
    endDate: new Date(eventDays[eventDays.length - 1].date.getTime() + 86_400_000 - 1000),
  };
};

export const getEventEditTargetIdFromPayload = (payload: Prisma.JsonObject | Prisma.InputJsonObject): string | null =>
  cleanText(payload.targetEventId) || cleanText(payload.editTargetEventId) || null;

const buildActiveEventEditSubmissionWhere = (
  targetEventId: string,
  excludeSubmissionId?: string
): Prisma.ContentSubmissionWhereInput => ({
  entityType: 'event',
  status: { in: [...ACTIVE_EVENT_EDIT_SUBMISSION_STATUSES] },
  ...(excludeSubmissionId ? { id: { not: excludeSubmissionId } } : {}),
  OR: [
    { payload: { path: ['targetEventId'], equals: targetEventId } },
    { payload: { path: ['editTargetEventId'], equals: targetEventId } },
  ],
});

const lockEventRowForEdit = async (
  db: PrismaClient | Prisma.TransactionClient,
  targetEventId: string
): Promise<void> => {
  await db.$queryRaw(Prisma.sql`SELECT id FROM "events" WHERE id = ${targetEventId} FOR UPDATE`);
};

export const findActiveEventEditSubmission = async (
  db: PrismaClient | Prisma.TransactionClient,
  targetEventId: string,
  excludeSubmissionId?: string
) => db.contentSubmission.findFirst({
  where: buildActiveEventEditSubmissionWhere(targetEventId, excludeSubmissionId),
  orderBy: [{ createdAt: 'asc' }],
  select: {
    id: true,
    status: true,
    title: true,
    createdAt: true,
  },
});

export const assertNoActiveEventEditSubmission = async (
  db: PrismaClient | Prisma.TransactionClient,
  payload: Prisma.JsonObject | Prisma.InputJsonObject,
  options: {
    excludeSubmissionId?: string;
    lockTargetEvent?: boolean;
  } = {}
): Promise<void> => {
  const targetEventId = getEventEditTargetIdFromPayload(payload);
  if (!targetEventId) return;
  if (options.lockTargetEvent) {
    await lockEventRowForEdit(db, targetEventId);
  }
  const active = await findActiveEventEditSubmission(db, targetEventId, options.excludeSubmissionId);
  if (!active) return;
  throw new ActiveEventEditSubmissionError({
    targetEventId,
    activeSubmissionId: active.id,
    activeSubmissionStatus: active.status,
  });
};

const cancelSupersededActiveEventEditSubmissions = async (
  db: Prisma.TransactionClient,
  targetEventId: string,
  keepSubmissionId: string
): Promise<void> => {
  const superseded = await db.contentSubmission.findMany({
    where: buildActiveEventEditSubmissionWhere(targetEventId, keepSubmissionId),
    select: { id: true },
  });
  const ids = superseded.map((submission) => submission.id);
  if (ids.length === 0) return;

  await db.contentSubmission.updateMany({
    where: { id: { in: ids } },
    data: {
      status: 'cancelled',
      reviewReason: '活动已有更新版本入库，旧编辑任务已自动取消',
    },
  });
  await db.contentSubmissionProcessingJob.updateMany({
    where: {
      submissionId: { in: ids },
      status: { in: ['queued', 'retrying'] },
    },
    data: {
      status: 'cancelled',
      lockedBy: null,
      lockedAt: null,
      completedAt: new Date(),
      lastError: 'Superseded by a newer event edit submission',
    },
  });
};

const decimalOrNull = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const integerOrNull = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.trunc(parsed) : null;
};

const dateTimeValue = (value: Date | string | null | undefined): number | null => {
  if (!value) return null;
  const parsed = value instanceof Date ? value : new Date(value);
  const time = parsed.getTime();
  return Number.isFinite(time) ? time : null;
};

const eventImageAssetsFromPayload = (value: unknown): Prisma.InputJsonValue[] => {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
      const row = item as Record<string, unknown>;
      const url = cleanText(row.url);
      const type = cleanText(row.type)?.toLowerCase();
      if (!url || !type || !['cover', 'luall', 'tt', 'poster', 'other'].includes(type)) return null;
      const label = cleanText(row.label) || type.toUpperCase();
      const fileName = cleanText(row.fileName);
      const source = cleanText(row.source);
      const originalUrl = cleanText(row.originalUrl);
      const order = typeof row.order === 'number' && Number.isFinite(row.order) ? row.order : undefined;
      const sort = typeof row.sort === 'number' && Number.isFinite(row.sort) ? row.sort : undefined;
      return {
        type,
        label,
        url,
        ...(fileName ? { fileName } : {}),
        ...(source ? { source } : {}),
        ...(originalUrl ? { originalUrl } : {}),
        ...(order !== undefined ? { order } : {}),
        ...(sort !== undefined ? { sort } : {}),
      } as Prisma.InputJsonObject;
    })
    .filter((item): item is Prisma.InputJsonObject => item !== null);
};

const hasRequiredEventPrimaryImageAsset = (assets: Prisma.InputJsonValue[]): boolean =>
  assets.some((asset) => {
    if (!asset || typeof asset !== 'object' || Array.isArray(asset)) return false;
    const row = asset as Record<string, unknown>;
    const type = cleanText(row.type)?.toLowerCase();
    if (type === 'cover' || type === 'luall' || type === 'poster') return true;
    const label = cleanText(row.label)?.toUpperCase() || '';
    const fileName = cleanText(row.fileName)?.toLowerCase() || '';
    return type === 'other' && (label.includes('POSTER') || fileName.startsWith('poster'));
  });

const eventTicketTiersFromPayload = (value: unknown, fallbackCurrency?: string): Prisma.EventTicketTierCreateWithoutEventInput[] => {
  if (!Array.isArray(value)) return [];
  const tiers: Prisma.EventTicketTierCreateWithoutEventInput[] = [];
  value.forEach((item, index) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) return;
    const row = item as Record<string, unknown>;
    const name = cleanText(row.name);
    const price = decimalOrNull(row.price);
    if (!name || price === null) return;
    const currency = cleanText(row.currency) || fallbackCurrency || null;
    const sortOrder = integerOrNull(row.sortOrder) ?? index + 1;
    tiers.push({
      name,
      price,
      currency,
      sortOrder,
    });
  });
  return tiers;
};

const normalizeDayRolloverHour = (value: unknown, fallback = 6): number => {
  const numeric = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(numeric)) return fallback;
  const hour = Math.floor(numeric);
  if (hour < 0 || hour > 23) return fallback;
  return hour;
};

const normalizeEventStageOrder = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  const result: string[] = [];
  for (const item of value) {
    const text = typeof item === 'string' ? item.trim() : '';
    if (!text) continue;
    const key = text.toLocaleLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(text);
  }
  return result;
};

const isLineupDjIdPlaceholder = (value: string): boolean => value === LINEUP_DJ_ID_PLACEHOLDER;

const cloneEventDayByOffset = (eventDayDate: Date, offsetDays: number): Date =>
  new Date(eventDayDate.getTime() + Math.max(0, offsetDays) * 86_400_000);

const buildSlotInstantFromEventDay = (
  sourceInstant: Date,
  eventDayDate: Date,
  timeZone: string
): Date => {
  const carryOffset = Math.max(0, diffEventDays(eventDayDate, sourceInstant, timeZone));
  const targetBaseDate = cloneEventDayByOffset(eventDayDate, carryOffset);
  const dateParts = getLocalDateTimePartsForInstant(targetBaseDate, timeZone);
  const timeParts = getLocalDateTimePartsForInstant(sourceInstant, timeZone);
  if (!dateParts || !timeParts) return new Date(NaN);
  return zonedTimeToUtc({
    year: dateParts.year,
    month: dateParts.month,
    day: dateParts.day,
    hour: timeParts.hour,
    minute: timeParts.minute,
    second: timeParts.second,
    millisecond: timeParts.millisecond,
  }, timeZone);
};

const normalizeLocalDateInput = (value: unknown, timeZone: string): Date | null => {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return startOfEventDay(value, timeZone);
  }
  const parsed = cleanText(value) ? parseEventDateInput(value, timeZone, 'start') : null;
  return parsed ? startOfEventDay(parsed, timeZone) : null;
};

const assertSlotMatchesEventDay = (
  slot: Record<string, unknown>,
  eventDay: SubmittedEventDay,
  timeZone: string,
  eventDayDateKey?: string
): void => {
  const inputWeekIndex = integerOrNull(slot.weekIndex);
  if (inputWeekIndex !== null && inputWeekIndex !== eventDay.weekIndex) {
    throw new EventSubmissionValidationError(`slot.eventDayId=${eventDay.eventDayId} 的 weekIndex 与 eventDays 定义不一致`);
  }
  const inputDayIndexInWeek = integerOrNull(slot.dayIndexInWeek);
  if (inputDayIndexInWeek !== null && inputDayIndexInWeek !== eventDay.dayIndexInWeek) {
    throw new EventSubmissionValidationError(`slot.eventDayId=${eventDay.eventDayId} 的 dayIndexInWeek 与 eventDays 定义不一致`);
  }
  const inputOverallDayIndex = integerOrNull(slot.overallDayIndex);
  if (inputOverallDayIndex !== null && inputOverallDayIndex !== eventDay.overallDayIndex) {
    throw new EventSubmissionValidationError(`slot.eventDayId=${eventDay.eventDayId} 的 overallDayIndex 与 eventDays 定义不一致`);
  }
  const inputFestivalDayIndex = integerOrNull(slot.festivalDayIndex);
  if (inputFestivalDayIndex !== null && inputFestivalDayIndex !== eventDay.overallDayIndex) {
    throw new EventSubmissionValidationError(`slot.eventDayId=${eventDay.eventDayId} 的 festivalDayIndex 与 eventDays 定义不一致`);
  }
  const localDate = normalizeLocalDateInput(slot.localDate, timeZone);
  const targetDateKey = eventDayDateKey ?? eventDateKey(eventDay.date, timeZone);
  if (localDate && eventDateKey(localDate, timeZone) !== targetDateKey) {
    throw new EventSubmissionValidationError(`slot.eventDayId=${eventDay.eventDayId} 的 localDate 与 eventDays 定义不一致`);
  }
};

const splitCollaborativeLineupName = (value: string): string[] => {
  const name = String(value || '').trim();
  if (!name) return [];
  const parts = name
    .replace(/\s+b3b\s+/ig, '[[B3B]]')
    .replace(/\s+b2b\s+/ig, '[[B2B]]')
    .split(/\[\[(?:B2B|B3B)\]\]/)
    .map((item) => item.trim())
    .filter(Boolean);
  return parts.length > 1 ? parts : [name];
};

const normalizeLineupMemberNamesInput = (row: Record<string, unknown>, djName: string): string[] => {
  const explicit = Array.isArray(row.memberNames)
    ? row.memberNames.map((item) => String(item || '').trim()).filter(Boolean)
    : [];
  return explicit.length ? explicit : splitCollaborativeLineupName(djName);
};

const normalizeLineupMemberDjIdsInput = (row: Record<string, unknown>, djId: string | null): Array<string | null> => {
  if (Array.isArray(row.memberDjIds)) {
    return row.memberDjIds.map((item) => {
      const id = String(item || '').trim();
      return id && !isLineupDjIdPlaceholder(id) ? id : null;
    });
  }
  return djId ? [djId] : [];
};

const normalizeSubmissionLineupSlots = (
  slots: unknown,
  scheduleContext: SubmittedEventScheduleContext
): CanonicalLineupSlotInput[] => {
  if (!Array.isArray(slots)) return [];

  const { eventDays, timeZone } = scheduleContext;
  const eventDayMeta = eventDays.map((day) => ({
    day,
    dateKey: eventDateKey(day.date, timeZone),
    storageLocalDate: eventDateOnlyToStorageDate(day.date, timeZone),
  }));
  const eventDayById = new Map(eventDays.map((day) => [day.eventDayId, day]));
  const eventDayMetaById = new Map(eventDayMeta.map((meta) => [meta.day.eventDayId, meta]));
  const eventDayByOverallDayIndex = new Map(eventDays.map((day) => [day.overallDayIndex, day]));
  const eventDayByDateKey = new Map(eventDayMeta.map((meta) => [meta.dateKey, meta.day]));
  const resolveEventDayForLegacySlot = (slot: Record<string, unknown>): SubmittedEventDay | null => {
    const overallDayIndex = integerOrNull(slot.overallDayIndex);
    if (overallDayIndex !== null) {
      const matched = eventDayByOverallDayIndex.get(overallDayIndex);
      if (matched) return matched;
    }

    const localDate = normalizeLocalDateInput(slot.localDate, timeZone);
    if (localDate) {
      const localDateKey = eventDateKey(localDate, timeZone);
      const matched = eventDayByDateKey.get(localDateKey);
      if (matched) return matched;
    }

    const parsedStart = parseEventDateInput(slot.startTime, timeZone, 'start');
    if (parsedStart) {
      const startDay = startOfEventDay(parsedStart, timeZone);
      const startDayKey = eventDateKey(startDay, timeZone);
      const matched = eventDayByDateKey.get(startDayKey);
      if (matched) return matched;
    }

    return null;
  };

  return slots
    .filter((slot): slot is Record<string, unknown> => typeof slot === 'object' && slot !== null)
    .map((slot, index) => {
      const explicitEventDayId = cleanText(slot.eventDayId);
      const inferredEventDay = explicitEventDayId ? null : resolveEventDayForLegacySlot(slot);
      const eventDayId = explicitEventDayId || inferredEventDay?.eventDayId;
      if (!eventDayId) {
        throw new EventSubmissionValidationError('所有 timetable slot 都必须携带 eventDayId');
      }
      const eventDay = eventDayById.get(eventDayId) || inferredEventDay;
      if (!eventDay) {
        throw new EventSubmissionValidationError(`slot.eventDayId=${eventDayId} 不存在于 eventDays 中`);
      }
      const eventDayResolvedMeta = eventDayMetaById.get(eventDay.eventDayId);
      const eventDayDateKey = eventDayResolvedMeta?.dateKey ?? eventDateKey(eventDay.date, timeZone);
      assertSlotMatchesEventDay(slot, eventDay, timeZone, eventDayDateKey);

      const parsedStart = parseEventDateInput(slot.startTime, timeZone, 'start');
      const parsedEnd = parseEventDateInput(slot.endTime, timeZone, 'end');
      if (!parsedStart || !parsedEnd) {
        throw new EventSubmissionValidationError(`slot.eventDayId=${eventDayId} 缺少有效的 startTime / endTime`);
      }
      const startCarryOffset = diffEventDays(eventDay.date, parsedStart, timeZone);
      const endCarryOffset = diffEventDays(eventDay.date, parsedEnd, timeZone);
      let startTime = startCarryOffset === 0
        ? parsedStart
        : buildSlotInstantFromEventDay(parsedStart, eventDay.date, timeZone);
      let endTime = startCarryOffset === 0 && endCarryOffset >= 0
        ? parsedEnd
        : buildSlotInstantFromEventDay(parsedEnd, eventDay.date, timeZone);
      while (endTime < startTime) {
        endTime = new Date(endTime.getTime() + 86_400_000);
      }

      const djName = typeof slot.djName === 'string' ? slot.djName.trim() : '';
      const rawDjId = typeof slot.djId === 'string' && slot.djId.trim() ? slot.djId.trim() : '';
      const cleanedMemberDjIds = Array.isArray(slot.memberDjIds)
        ? slot.memberDjIds.map((id) => {
            const normalized = typeof id === 'string' ? id.trim() : '';
            return normalized && !isLineupDjIdPlaceholder(normalized) ? normalized : null;
          })
        : [];
      const normalizedRawDjId = rawDjId && !isLineupDjIdPlaceholder(rawDjId) ? rawDjId : '';
      const firstBoundDjId = cleanedMemberDjIds.find((id) => !!id) || '';
      const effectiveDjId = normalizedRawDjId || firstBoundDjId || null;
      const memberDjIds = cleanedMemberDjIds.length ? cleanedMemberDjIds : (effectiveDjId ? [effectiveDjId] : []);
      const hasIdentity = djName.length > 0 || !!effectiveDjId || memberDjIds.some(Boolean);
      if (!hasIdentity) return null;
      const slotId = cleanText(slot.id);

      const lineupArtistId = cleanText(slot.lineupArtistId);
      const normalizedSlot: CanonicalLineupSlotInput = {
        ...(slotId ? { id: slotId } : {}),
        ...(lineupArtistId ? { lineupArtistId } : {}),
        eventDayId: eventDay.eventDayId,
        weekIndex: eventDay.weekIndex,
        dayIndexInWeek: eventDay.dayIndexInWeek,
        overallDayIndex: eventDay.overallDayIndex,
        localDate: eventDayResolvedMeta?.storageLocalDate ?? eventDateOnlyToStorageDate(eventDay.date, scheduleContext.timeZone),
        djId: effectiveDjId,
        memberDjIds,
        djName: djName || 'Unknown DJ',
        stageName: typeof slot.stageName === 'string' && slot.stageName.trim() ? slot.stageName.trim() : null,
        festivalDayIndex: null,
        startTime,
        endTime,
        sortOrder: typeof slot.sortOrder === 'number' && Number.isFinite(slot.sortOrder) ? slot.sortOrder : index + 1,
      };
      return normalizedSlot;
    })
    .filter((slot): slot is CanonicalLineupSlotInput => slot !== null);
};

export const normalizeSubmittedTimetableSlots = (
  slots: unknown,
  scheduleContext: SubmittedEventScheduleContext
): CanonicalLineupSlotInput[] => normalizeSubmissionLineupSlots(slots, scheduleContext);

export const buildSubmittedEventScheduleContextFromEvent = (event: {
  scheduleMode?: string | null;
  timeZone?: string | null;
  dayRolloverHour?: number | null;
  weeks?: Array<{
    weekIndex: number;
    label?: string | null;
    startDate: Date;
    endDate: Date;
    sortOrder?: number | null;
  }> | null;
  eventDays?: Array<{
    eventDayId: string;
    weekIndex: number;
    dayIndexInWeek: number;
    overallDayIndex: number;
    label?: string | null;
    weekday?: string | null;
    date: Date;
    sortOrder?: number | null;
  }> | null;
}): SubmittedEventScheduleContext => {
  const payload: Record<string, unknown> = {
    schedule: {
      mode: event.scheduleMode ?? 'single_day',
      timeZone: event.timeZone ?? DEFAULT_EVENT_TIME_ZONE,
      dayRolloverHour: event.dayRolloverHour ?? 6,
    },
    weeks: Array.isArray(event.weeks)
      ? event.weeks.map((week) => ({
          weekIndex: week.weekIndex,
          label: week.label ?? null,
          startDate: storageDateToEventDate(week.startDate, event.timeZone ?? DEFAULT_EVENT_TIME_ZONE),
          endDate: storageDateToEventDate(week.endDate, event.timeZone ?? DEFAULT_EVENT_TIME_ZONE),
          sortOrder: week.sortOrder ?? week.weekIndex,
        }))
      : [],
    eventDays: Array.isArray(event.eventDays)
      ? event.eventDays.map((day) => ({
          eventDayId: day.eventDayId,
          weekIndex: day.weekIndex,
          dayIndexInWeek: day.dayIndexInWeek,
          overallDayIndex: day.overallDayIndex,
          label: day.label ?? null,
          weekday: day.weekday ?? null,
          date: storageDateToEventDate(day.date, event.timeZone ?? DEFAULT_EVENT_TIME_ZONE),
          sortOrder: day.sortOrder ?? day.overallDayIndex,
        }))
      : [],
  };
  return normalizeSubmittedEventScheduleContext(payload);
};

const normalizeSubmissionLineupArtists = (
  artists: unknown,
  fallbackSlots: CanonicalLineupSlotInput[] = []
): CanonicalLineupArtistInput[] => {
  const source = Array.isArray(artists) ? artists : null;
  if (!source) return normalizeCanonicalLineupArtists([], fallbackSlots);

  return normalizeCanonicalLineupArtists(
    source
      .filter((raw): raw is Record<string, unknown> => !!raw && typeof raw === 'object')
      .map((row, index) => {
        const djName = String(row.djName ?? row.name ?? row.musician ?? row.artistName ?? '').trim();
        const primaryRaw = String(row.djId || '').trim();
        const djId = primaryRaw && !isLineupDjIdPlaceholder(primaryRaw) ? primaryRaw : null;
        const artistId = cleanText(row.id);
        return {
          ...(artistId ? { id: artistId } : {}),
          djId,
          memberDjIds: normalizeLineupMemberDjIdsInput(row, djId),
          memberNames: normalizeLineupMemberNamesInput(row, djName),
          djName,
          sortOrder: typeof row.sortOrder === 'number' && Number.isFinite(row.sortOrder) ? row.sortOrder : index + 1,
        } satisfies CanonicalLineupArtistInput;
      }),
    fallbackSlots
  );
};

const lineupIdentityKey = (input: {
  djId?: string | null;
  memberDjIds?: Array<string | null>;
  memberNames?: string[];
  djName: string;
}): string => {
  const djId = cleanText(input.djId);
  if (djId && !isLineupDjIdPlaceholder(djId)) return `dj:${djId}`;

  const memberDjIds = Array.isArray(input.memberDjIds)
    ? input.memberDjIds.map((id) => cleanText(id)).filter((id): id is string => Boolean(id && !isLineupDjIdPlaceholder(id)))
    : [];
  const uniqueMemberDjIds = Array.from(new Set(memberDjIds)).sort();
  if (uniqueMemberDjIds.length > 0) return `members:${uniqueMemberDjIds.join('|')}`;

  const memberNames = Array.isArray(input.memberNames)
    ? input.memberNames.map((name) => cleanText(name)?.toLowerCase().replace(/\s+/g, ' ')).filter((name): name is string => Boolean(name))
    : [];
  const uniqueMemberNames = Array.from(new Set(memberNames)).sort();
  if (uniqueMemberNames.length > 1) return `member-names:${uniqueMemberNames.join('|')}`;

  return `name:${input.djName.trim().toLowerCase().replace(/\s+/g, ' ')}`;
};

const lineupIdentityLabel = (input: {
  memberNames?: string[];
  djName: string;
}): string => {
  const names = Array.isArray(input.memberNames)
    ? input.memberNames.map((name) => cleanText(name)).filter(Boolean)
    : [];
  return names.length > 1 ? names.join(' b2b ') : input.djName;
};

export type EventLineupTimetableAlignmentIssue = {
  missingFromLineup: string[];
  extraInLineup: string[];
};

const mergeAlignedLineupArtists = (
  currentArtists: CanonicalLineupArtistInput[],
  timetableArtists: CanonicalLineupArtistInput[]
): CanonicalLineupArtistInput[] => {
  const currentByKey = new Map<string, CanonicalLineupArtistInput>();
  for (const artist of currentArtists) {
    currentByKey.set(lineupIdentityKey(artist), artist);
  }

  return timetableArtists
    .map((artist, index) => {
      const existing = currentByKey.get(lineupIdentityKey(artist));
      return {
        ...artist,
        id: existing?.id,
        sortOrder: existing?.sortOrder ?? index + 1,
      };
    })
    .sort((a, b) => a.sortOrder - b.sortOrder);
};

const mergeIncrementalLineupArtists = (
  currentArtists: CanonicalLineupArtistInput[],
  timetableArtists: CanonicalLineupArtistInput[]
): CanonicalLineupArtistInput[] => {
  const currentByKey = new Map<string, CanonicalLineupArtistInput>();
  for (const artist of currentArtists) {
    currentByKey.set(lineupIdentityKey(artist), artist);
  }

  const result = currentArtists.map(cloneArtistInput);
  let nextSortOrder = result.reduce((max, artist) => Math.max(max, artist.sortOrder), 0);

  for (const artist of timetableArtists) {
    const key = lineupIdentityKey(artist);
    if (currentByKey.has(key)) continue;
    result.push({
      ...artist,
      sortOrder: ++nextSortOrder,
    });
    currentByKey.set(key, artist);
  }

  return result
    .slice()
    .sort((a, b) => a.sortOrder - b.sortOrder)
    .map((artist, index) => ({ ...artist, sortOrder: artist.sortOrder || index + 1 }));
};

const relinkSlotsToAlignedArtists = (
  slots: CanonicalLineupSlotInput[],
  artists: CanonicalLineupArtistInput[]
): CanonicalLineupSlotInput[] => {
  const artistIdByKey = new Map<string, string>();
  for (const artist of artists) {
    if (!artist.id) continue;
    artistIdByKey.set(lineupIdentityKey(artist), artist.id);
  }

  return slots.map((slot) => ({
    ...slot,
    lineupArtistId: artistIdByKey.get(lineupIdentityKey({
      djId: slot.djId,
      memberDjIds: slot.memberDjIds,
      djName: slot.djName,
    })) ?? null,
  }));
};

const cloneArtistInput = (artist: CanonicalLineupArtistInput): CanonicalLineupArtistInput => ({
  id: artist.id,
  djId: artist.djId,
  memberDjIds: [...(artist.memberDjIds ?? [])],
  memberNames: [...(artist.memberNames ?? [])],
  djName: artist.djName,
  sortOrder: artist.sortOrder,
});

export const buildAlignedLineupArtistsFromTimetablePayload = (
  payload: Prisma.JsonObject,
  scheduleContext: SubmittedEventScheduleContext
): CanonicalLineupArtistInput[] => {
  const slots = normalizeSubmissionLineupSlots(payload.lineupSlots, scheduleContext);
  const currentArtists = normalizeSubmissionLineupArtists(payload.lineupArtists, []);
  const timetableArtists = normalizeCanonicalLineupArtists([], slots);
  return mergeAlignedLineupArtists(currentArtists, timetableArtists);
};

export const autoAlignEventLineupToTimetablePayload = (
  payload: Prisma.JsonObject,
  scheduleContext: SubmittedEventScheduleContext
): Prisma.JsonObject => {
  const slots = normalizeSubmissionLineupSlots(payload.lineupSlots, scheduleContext);
  if (slots.length === 0) return payload;
  const alignedArtists = buildAlignedLineupArtistsFromTimetablePayload(
    payload,
    scheduleContext
  );
  return {
    ...payload,
    lineupArtists: alignedArtists as unknown as Prisma.JsonValue,
    lineupSlots: relinkSlotsToAlignedArtists(slots, alignedArtists) as unknown as Prisma.JsonValue,
  } as Prisma.JsonObject;
};

export const incrementallyFillEventLineupFromTimetablePayload = (
  payload: Prisma.JsonObject,
  scheduleContext: SubmittedEventScheduleContext
): Prisma.JsonObject => {
  const slots = normalizeSubmissionLineupSlots(payload.lineupSlots, scheduleContext);
  if (slots.length === 0) return payload;
  const currentArtists = normalizeSubmissionLineupArtists(payload.lineupArtists, []);
  const timetableArtists = normalizeCanonicalLineupArtists([], slots);
  const mergedArtists = mergeIncrementalLineupArtists(currentArtists, timetableArtists);
  return {
    ...payload,
    lineupArtists: mergedArtists as unknown as Prisma.JsonValue,
    lineupSlots: relinkSlotsToAlignedArtists(slots, mergedArtists) as unknown as Prisma.JsonValue,
  } as Prisma.JsonObject;
};

export const validateEventLineupTimetableAlignment = (
  payload: Prisma.JsonObject,
  scheduleContext: SubmittedEventScheduleContext
): EventLineupTimetableAlignmentIssue | null => {
  const slots = normalizeSubmissionLineupSlots(payload.lineupSlots, scheduleContext);
  if (slots.length === 0) return null;

  const artists = normalizeSubmissionLineupArtists(payload.lineupArtists, []);
  const lineupByKey = new Map<string, string>();
  for (const artist of artists) {
    lineupByKey.set(lineupIdentityKey(artist), lineupIdentityLabel(artist));
  }

  const timetableArtists = normalizeCanonicalLineupArtists([], slots);
  const timetableByKey = new Map<string, string>();
  for (const artist of timetableArtists) {
    timetableByKey.set(lineupIdentityKey(artist), lineupIdentityLabel(artist));
  }

  const missingFromLineup = Array.from(timetableByKey.entries())
    .filter(([key]) => !lineupByKey.has(key))
    .map(([, label]) => label);
  const extraInLineup = Array.from(lineupByKey.entries())
    .filter(([key]) => !timetableByKey.has(key))
    .map(([, label]) => label);

  if (missingFromLineup.length === 0 && extraInLineup.length === 0) return null;
  return {
    missingFromLineup,
    extraInLineup,
  };
};

export const formatEventLineupTimetableAlignmentError = (
  issue: EventLineupTimetableAlignmentIssue
): string => {
  const parts = ['阵容和时间表未对齐。'];
  if (issue.missingFromLineup.length > 0) {
    parts.push(`时间表中有但阵容中缺少：${issue.missingFromLineup.join('、')}`);
  }
  if (issue.extraInLineup.length > 0) {
    parts.push(`阵容中有但时间表中缺少：${issue.extraInLineup.join('、')}`);
  }
  parts.push('请一键将阵容与时间表对齐，或手动修改后再提交。');
  return parts.join(' ');
};

const syncSubmissionEventLineupAndTimetable = async (
  tx: Prisma.TransactionClient,
  eventId: string,
  payload: Prisma.JsonObject,
  scheduleContext: SubmittedEventScheduleContext
): Promise<CanonicalLineupSyncProfiling> => {
  const slotsStartedAt = process.hrtime.bigint();
  const slots = normalizeSubmissionLineupSlots(payload.lineupSlots, scheduleContext);
  const submissionSlotsNormalizeMs = Number(process.hrtime.bigint() - slotsStartedAt) / 1_000_000;
  const artistsStartedAt = process.hrtime.bigint();
  const submittedArtists = normalizeSubmissionLineupArtists(payload.lineupArtists, []);
  const normalizedArtists = normalizeCanonicalLineupArtists(submittedArtists, []);
  const timetableArtists = normalizeCanonicalLineupArtists([], slots);
  const submissionArtistsNormalizeMs = Number(process.hrtime.bigint() - artistsStartedAt) / 1_000_000;
  const mergeStartedAt = process.hrtime.bigint();
  const lineupSyncMode = resolveEventLineupSyncMode(payload);
  const artists = lineupSyncMode === 'exact_align'
    ? mergeAlignedLineupArtists(normalizedArtists, timetableArtists)
    : mergeIncrementalLineupArtists(normalizedArtists, timetableArtists);
  const submissionArtistMergeMs = Number(process.hrtime.bigint() - mergeStartedAt) / 1_000_000;
  const relinkStartedAt = process.hrtime.bigint();
  const relinkedSlots = relinkSlotsToAlignedArtists(slots, artists);
  const submissionSlotRelinkMs = Number(process.hrtime.bigint() - relinkStartedAt) / 1_000_000;
  const stageOrderStartedAt = process.hrtime.bigint();
  const stageOrder = normalizeEventStageOrder(payload.stageOrder);
  const submissionStageOrderMs = Number(process.hrtime.bigint() - stageOrderStartedAt) / 1_000_000;
  const canonicalSync = await syncCanonicalEventLineupAndTimetable(tx, eventId, relinkedSlots, artists, stageOrder);
  return {
    ...canonicalSync,
    submissionSlotsNormalizeMs,
    submissionArtistsNormalizeMs,
    submissionArtistMergeMs,
    submissionSlotRelinkMs,
    submissionStageOrderMs,
  };
};

const runEventSubmissionTransaction = async <T>(
  db: PrismaClient,
  callback: (tx: Prisma.TransactionClient) => Promise<T>
): Promise<T> => (EVENT_SUBMISSION_TRANSACTION_CLIENT ?? db).$transaction(callback, {
  timeout: EVENT_SUBMISSION_TRANSACTION_TIMEOUT_MS,
  maxWait: EVENT_SUBMISSION_TRANSACTION_MAX_WAIT_MS,
});

type NormalizedEventSubmissionWriteInput = {
  targetEventId: string | null;
  name: string;
  scheduleContext: SubmittedEventScheduleContext;
  eventData: Prisma.EventUncheckedUpdateInput;
  ticketTiers: Prisma.EventTicketTierCreateWithoutEventInput[];
};

const uniqueEventSlug = async (db: PrismaClient, name: string, requestedSlug?: string): Promise<string> => {
  const base = String(requestedSlug || name)
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '') || `event-${Date.now()}`;
  let candidate = base;
  let seq = 1;
  while (await db.event.findUnique({ where: { slug: candidate }, select: { id: true } })) {
    seq += 1;
    candidate = `${base}-${seq}`;
  }
  return candidate;
};

const buildEventWeeksCreateInput = (
  weeks: SubmittedEventWeek[],
  timeZone: string
): Prisma.EventWeekCreateManyEventInput[] =>
  weeks.map((week) => ({
    weekIndex: week.weekIndex,
    label: week.label,
    startDate: eventDateOnlyToStorageDate(week.startDate, timeZone),
    endDate: eventDateOnlyToStorageDate(week.endDate, timeZone),
    sortOrder: week.sortOrder,
  }));

const buildEventDaysCreateInput = (
  weeks: SubmittedEventWeek[],
  eventDays: SubmittedEventDay[],
  timeZone: string
): Prisma.EventDayCreateManyEventInput[] => {
  const weekByIndex = new Map(weeks.map((week) => [week.weekIndex, week]));
  return eventDays.map((day) => {
    const week = weekByIndex.get(day.weekIndex);
    if (!week) {
      throw new EventSubmissionValidationError(`eventDay ${day.eventDayId} 引用了不存在的 weekIndex=${day.weekIndex}`);
    }
    return {
      eventWeekId: null,
      eventDayId: day.eventDayId,
      weekIndex: day.weekIndex,
      dayIndexInWeek: day.dayIndexInWeek,
      overallDayIndex: day.overallDayIndex,
      label: day.label,
      weekday: day.weekday,
      date: eventDateOnlyToStorageDate(day.date, timeZone),
      sortOrder: day.sortOrder,
    };
  });
};

export const syncStructuredEventSchedule = async (
  tx: Prisma.TransactionClient,
  eventId: string,
  scheduleContext: SubmittedEventScheduleContext
): Promise<void> => {
  const [existingWeeks, existingDays] = await Promise.all([
    tx.eventWeek.findMany({
      where: { eventId },
      select: {
        id: true,
        weekIndex: true,
        label: true,
        startDate: true,
        endDate: true,
        sortOrder: true,
      },
    }),
    tx.eventDay.findMany({
      where: { eventId },
      select: {
        id: true,
        eventWeekId: true,
        eventDayId: true,
        weekIndex: true,
        dayIndexInWeek: true,
        overallDayIndex: true,
        label: true,
        weekday: true,
        date: true,
        sortOrder: true,
      },
    }),
  ]);

  const desiredWeekRows = buildEventWeeksCreateInput(scheduleContext.weeks, scheduleContext.timeZone);
  const desiredDayRows = buildEventDaysCreateInput(scheduleContext.weeks, scheduleContext.eventDays, scheduleContext.timeZone);
  const desiredWeekIndexes = new Set(scheduleContext.weeks.map((week) => week.weekIndex));
  const desiredEventDayIds = new Set(scheduleContext.eventDays.map((day) => day.eventDayId));
  const existingWeekByIndex = new Map(existingWeeks.map((week) => [week.weekIndex, week]));
  const existingDayByEventDayId = new Map(existingDays.map((day) => [day.eventDayId, day]));

  const eventDayIdsToDelete = existingDays
    .filter((day) => !desiredEventDayIds.has(day.eventDayId))
    .map((day) => day.eventDayId);
  if (eventDayIdsToDelete.length > 0) {
    await tx.eventPerformance.updateMany({
      where: {
        eventId,
        eventDayId: { in: eventDayIdsToDelete },
      },
      data: {
        eventDayId: null,
        weekIndex: null,
        dayIndexInWeek: null,
        overallDayIndex: null,
        localDate: null,
      },
    });
    await tx.eventDay.deleteMany({
      where: {
        eventId,
        eventDayId: { in: eventDayIdsToDelete },
      },
    });
  }

  for (const week of desiredWeekRows) {
    const existing = existingWeekByIndex.get(week.weekIndex);
    if (!existing) {
      await tx.eventWeek.create({
        data: {
          eventId,
          ...week,
        },
      });
      continue;
    }
    if (
      existing.label !== week.label
      || dateTimeValue(existing.startDate) !== dateTimeValue(week.startDate)
      || dateTimeValue(existing.endDate) !== dateTimeValue(week.endDate)
      || existing.sortOrder !== week.sortOrder
    ) {
      await tx.eventWeek.update({
        where: { id: existing.id },
        data: week,
      });
    }
  }

  const createdWeeks = await tx.eventWeek.findMany({
    where: { eventId },
    select: { id: true, weekIndex: true },
  });
  const weekIdByIndex = new Map(createdWeeks.map((week) => [week.weekIndex, week.id]));

  const daysNeedingTemporaryOverallIndex = desiredDayRows
    .map((day) => existingDayByEventDayId.get(day.eventDayId))
    .filter((day): day is NonNullable<typeof day> => Boolean(day))
    .filter((day) => {
      const desired = desiredDayRows.find((row) => row.eventDayId === day.eventDayId);
      return Boolean(desired && desired.overallDayIndex !== day.overallDayIndex);
    });
  for (const [index, day] of daysNeedingTemporaryOverallIndex.entries()) {
    await tx.eventDay.update({
      where: { id: day.id },
      data: { overallDayIndex: -(index + 1) },
    });
  }

  for (const day of desiredDayRows) {
    const eventWeekId = weekIdByIndex.get(day.weekIndex) ?? null;
    const existing = existingDayByEventDayId.get(day.eventDayId);
    const data = {
      eventWeekId,
      weekIndex: day.weekIndex,
      dayIndexInWeek: day.dayIndexInWeek,
      overallDayIndex: day.overallDayIndex,
      label: day.label,
      weekday: day.weekday,
      date: day.date,
      sortOrder: day.sortOrder,
    };
    if (!existing) {
      await tx.eventDay.create({
        data: {
          eventId,
          eventDayId: day.eventDayId,
          ...data,
        },
      });
      continue;
    }
    if (
      existing.eventWeekId !== eventWeekId
      || existing.weekIndex !== data.weekIndex
      || existing.dayIndexInWeek !== data.dayIndexInWeek
      || existing.overallDayIndex !== data.overallDayIndex
      || existing.label !== data.label
      || existing.weekday !== data.weekday
      || dateTimeValue(existing.date) !== dateTimeValue(data.date)
      || existing.sortOrder !== data.sortOrder
    ) {
      await tx.eventDay.update({
        where: { id: existing.id },
        data,
      });
    }
  }

  const weekIndexesToDelete = existingWeeks
    .filter((week) => !desiredWeekIndexes.has(week.weekIndex))
    .map((week) => week.weekIndex);
  if (weekIndexesToDelete.length > 0) {
    await tx.eventWeek.deleteMany({
      where: {
        eventId,
        weekIndex: { in: weekIndexesToDelete },
      },
    });
  }
};

const normalizeEventSubmissionWriteInput = async (
  db: PrismaClient,
  payload: Prisma.JsonObject,
  options: {
    submissionId?: string;
  } = {}
): Promise<NormalizedEventSubmissionWriteInput> => {
  const name = cleanText(payload.name);
  let targetEventId = getEventEditTargetIdFromPayload(payload);
  if (!targetEventId && options.submissionId) {
    const existingSubmission = await db.contentSubmission.findUnique({
      where: { id: options.submissionId },
      select: { createdEntityId: true },
    });
    targetEventId = cleanText(existingSubmission?.createdEntityId) || null;
  }
  const scheduleContext = normalizeSubmittedEventScheduleContext(payload);
  if (!name) {
    throw new Error('活动名称不能为空');
  }

  const imageAssets = eventImageAssetsFromPayload(payload.imageAssets);
  if (!hasRequiredEventPrimaryImageAsset(imageAssets)) {
    throw new Error('至少需要上传一张海报、阵容图或封面图');
  }

  const description = resolveOptionalNullableTextField(payload, 'description');
  const sourceEventUrl = resolveOptionalNullableTextField(payload, 'sourceEventUrl');
  const coverImageUrl = resolveOptionalNullableTextField(payload, 'coverImageUrl');
  const lineupImageUrl = resolveOptionalNullableTextField(payload, 'lineupImageUrl');
  const eventType = resolveOptionalNullableTextField(payload, 'eventType');
  const organizerName = resolveOptionalNullableTextField(payload, 'organizerName');
  const venueName = resolveOptionalNullableTextField(payload, 'venueName');
  const venueAddress = resolveOptionalNullableTextField(payload, 'venueAddress');
  const referenceLinks = resolveOptionalStringArrayField(payload, 'referenceLinks');
  const socialLinks = resolveOptionalJsonField(payload, 'socialLinks');
  const sourceProvider = resolveOptionalNullableTextField(payload, 'sourceProvider');
  const city = resolveOptionalNullableTextField(payload, 'city');
  const country = resolveOptionalNullableTextField(payload, 'country');
  const manualLocation = hasOwn(payload, 'manualLocation')
    ? ((payload.manualLocation as Prisma.InputJsonValue | undefined) ?? Prisma.JsonNull)
    : undefined;
  const locationPoint = hasOwn(payload, 'locationPoint')
    ? ((payload.locationPoint as Prisma.InputJsonValue | undefined) ?? Prisma.JsonNull)
    : undefined;
  const latitude = hasOwn(payload, 'latitude') ? decimalOrNull(payload.latitude) : undefined;
  const longitude = hasOwn(payload, 'longitude') ? decimalOrNull(payload.longitude) : undefined;
  const ticketUrl = resolveOptionalNullableTextField(payload, 'ticketUrl');
  const ticketCurrency = resolveOptionalNullableTextField(payload, 'ticketCurrency');
  const ticketNotes = resolveOptionalNullableTextField(payload, 'ticketNotes');
  const officialWebsite = resolveOptionalNullableTextField(payload, 'officialWebsite');
  const ticketTiers = eventTicketTiersFromPayload(payload.ticketTiers, ticketCurrency || undefined);
  const wikiFestivalId = resolveOptionalNullableTextField(payload, 'wikiFestivalId');
  const descriptionI18n = resolveOptionalTriTextField(payload, 'descriptionI18n', description || '', {
    includeWhen: hasOwn(payload, 'description') || hasOwn(payload, 'descriptionI18n'),
  });
  const cityI18n = resolveOptionalTriTextField(payload, 'cityI18n', city || '', {
    includeWhen: hasOwn(payload, 'city') || hasOwn(payload, 'cityI18n'),
  });
  const countryI18n = resolveOptionalTriTextField(payload, 'countryI18n', country || '', {
    includeWhen: hasOwn(payload, 'country') || hasOwn(payload, 'countryI18n'),
  });

  return {
    targetEventId,
    name,
    scheduleContext,
    ticketTiers,
    eventData: {
      name,
      nameI18n: triTextToJson(normalizeTriTextPayload(payload.nameI18n, name)),
      wikiFestivalId,
      description,
      descriptionI18n,
      coverImageUrl,
      lineupImageUrl,
      imageAssets: imageAssets.length ? imageAssets : Prisma.JsonNull,
      eventType,
      organizerName,
      venueName,
      venueAddress,
      referenceLinks,
      socialLinks,
      sourceProvider,
      sourceEventUrl,
      city,
      country,
      cityI18n,
      countryI18n,
      manualLocation,
      locationPoint,
      latitude,
      longitude,
      startDate: scheduleContext.startDate,
      endDate: scheduleContext.endDate,
      scheduleMode: scheduleContext.scheduleMode,
      timeZone: scheduleContext.timeZone,
      startTime: cleanText(payload.startTime) || undefined,
      endTime: cleanText(payload.endTime) || undefined,
      dayRolloverHour: scheduleContext.dayRolloverHour,
      ticketUrl,
      ticketPriceMin: decimalOrNull(payload.ticketPriceMin),
      ticketPriceMax: decimalOrNull(payload.ticketPriceMax),
      ticketCurrency,
      ticketNotes,
      officialWebsite,
      status: cleanText(payload.status) || 'upcoming',
      isVerified: true,
    } satisfies Prisma.EventUncheckedUpdateInput,
  };
};

const applyEventCoreUpdate = async (
  tx: Prisma.TransactionClient,
  targetEventId: string,
  input: NormalizedEventSubmissionWriteInput
): Promise<void> => {
  await tx.event.update({
    where: { id: targetEventId },
    data: {
      ...input.eventData,
      revision: { increment: 1 },
      ticketTiers: {
        deleteMany: {},
        create: input.ticketTiers,
      },
    },
  });
  await syncStructuredEventSchedule(tx, targetEventId, input.scheduleContext);
};

const applyEventCoreCreate = async (
  tx: Prisma.TransactionClient,
  submitterId: string,
  slug: string,
  input: NormalizedEventSubmissionWriteInput
): Promise<{ id: string }> => {
  const created = await tx.event.create({
    data: {
      organizerId: submitterId,
      slug,
      ...input.eventData,
      ticketTiers: input.ticketTiers.length
        ? {
            create: input.ticketTiers,
          }
        : undefined,
    } as any,
  });
  await syncStructuredEventSchedule(tx, created.id, input.scheduleContext);
  return created;
};

export const applyEventCanonicalSubmissionState = async (
  tx: Prisma.TransactionClient,
  eventId: string,
  payload: Prisma.JsonObject,
  scheduleContext: SubmittedEventScheduleContext
): Promise<CanonicalLineupSyncProfiling> => syncSubmissionEventLineupAndTimetable(
  tx,
  eventId,
  payload,
  scheduleContext
);

export const applyEventTimetableFromSubmission = async (
  db: PrismaClient,
  eventId: string,
  payload: Prisma.JsonObject
): Promise<CanonicalLineupSyncProfiling> => {
  const startedAt = process.hrtime.bigint();
  const scheduleContextStartedAt = process.hrtime.bigint();
  const scheduleContext = normalizeSubmittedEventScheduleContext(payload);
  const scheduleContextMs = Number(process.hrtime.bigint() - scheduleContextStartedAt) / 1_000_000;
  const transactionStartedAt = process.hrtime.bigint();
  const canonicalSync = await runEventSubmissionTransaction(db, async (tx) => applyEventCanonicalSubmissionState(
    tx,
    eventId,
    payload,
    scheduleContext
  ));
  const transactionWallMs = Number(process.hrtime.bigint() - transactionStartedAt) / 1_000_000;
  const totalWallMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
  return {
    ...canonicalSync,
    scheduleContextMs,
    transactionWallMs,
    transactionOverheadMs: Math.max(0, totalWallMs - scheduleContextMs - canonicalSync.totalMs),
    outerTotalMs: totalWallMs,
  };
};

export async function createOrUpdateEventFromSubmission(
  db: PrismaClient,
  payload: Prisma.JsonObject,
  submitterId: string,
  options: {
    submissionId?: string;
    skipCanonicalApply?: boolean;
  } = {}
) {
  const input = await normalizeEventSubmissionWriteInput(db, payload, options);

  if (input.targetEventId) {
    const existing = await db.event.findUnique({
      where: { id: input.targetEventId },
      select: {
        id: true,
      },
    });
    if (!existing) {
      throw new Error('待更新的活动不存在');
    }

    await runEventSubmissionTransaction(db, async (tx) => {
      await applyEventCoreUpdate(tx, input.targetEventId as string, input);
      if (!options.skipCanonicalApply) {
        await applyEventCanonicalSubmissionState(tx, input.targetEventId as string, payload, input.scheduleContext);
      }
      if (options.submissionId) {
        await cancelSupersededActiveEventEditSubmissions(tx, input.targetEventId as string, options.submissionId);
      }
    });

    return db.event.findUniqueOrThrow({
      where: { id: input.targetEventId },
    });
  }

  const slug = await uniqueEventSlug(db, input.name, cleanText(payload.slug));
  const created = await runEventSubmissionTransaction(db, async (tx) => {
    const created = await applyEventCoreCreate(tx, submitterId, slug, input);
    if (options.submissionId) {
      await tx.contentSubmission.update({
        where: { id: options.submissionId },
        data: {
          createdEntityId: created.id,
        },
      });
    }
    if (!options.skipCanonicalApply) {
      await applyEventCanonicalSubmissionState(tx, created.id, payload, input.scheduleContext);
    }
    return created;
  });

  return db.event.findUniqueOrThrow({
    where: { id: created.id },
  });
}
