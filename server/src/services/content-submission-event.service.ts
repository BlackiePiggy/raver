import { Prisma, PrismaClient } from '@prisma/client';
import {
  DEFAULT_EVENT_TIME_ZONE,
  diffEventDays,
  getEventHour,
  isValidEventTimeZone,
  normalizeEventTimeZone,
  parseEventDateInput,
  setEventDayAndKeepTime,
  startOfEventDay,
} from '../utils/event-timezone';
import { normalizeTriTextPayload, triTextToJson } from '../utils/i18n';
import {
  type CanonicalLineupSnapshot,
  type CanonicalLineupArtistInput,
  type CanonicalLineupSlotInput,
  loadCanonicalEventLineupSnapshot,
  normalizeCanonicalLineupArtists,
  syncCanonicalEventLineupAndTimetable,
} from './event-lineup-canonical.service';

const EVENT_SUBMISSION_TRANSACTION_TIMEOUT_MS = 120_000;
const EVENT_SUBMISSION_TRANSACTION_MAX_WAIT_MS = 30_000;

const LINEUP_DJ_ID_PLACEHOLDER = '__UNBOUND__';

const cleanText = (value: unknown): string | undefined => {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed || undefined;
};

export class EventSubmissionConflictError extends Error {
  readonly code = 'EVENT_SUBMISSION_STALE_EDIT';
  readonly details?: {
    targetEventId?: string;
    baseEventRevision?: number | null;
    currentEventRevision?: number | null;
  };

  constructor(message: string, details?: {
    targetEventId?: string;
    baseEventRevision?: number | null;
    currentEventRevision?: number | null;
  }) {
    super(message);
    this.name = 'EventSubmissionConflictError';
    this.details = details;
  }
}

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

const jsonObjectOrNull = (value: unknown): Prisma.JsonObject | null =>
  isPlainObject(value) ? value as Prisma.JsonObject : null;

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

const validateBaseEventRevision = (
  payload: Prisma.JsonObject,
  currentRevision: number
): void => {
  const targetEventId = getEventEditTargetIdFromPayload(payload);
  if (!targetEventId) return;
  const baseEventRevision = integerOrNull(payload.baseEventRevision);
  if (baseEventRevision === null) {
    throw new EventSubmissionConflictError('编辑基线已失效，请重新打开活动后再提交', {
      targetEventId,
      baseEventRevision: null,
      currentEventRevision: currentRevision,
    });
  }
  if (baseEventRevision !== currentRevision) {
    throw new EventSubmissionConflictError('活动在你编辑期间已被更新，请刷新最新内容后重新编辑提交', {
      targetEventId,
      baseEventRevision,
      currentEventRevision: currentRevision,
    });
  }
};

export const assertEventSubmissionBaseRevision = async (
  db: PrismaClient,
  payload: Prisma.JsonObject
): Promise<void> => {
  const targetEventId = getEventEditTargetIdFromPayload(payload);
  if (!targetEventId) return;
  const existing = await db.event.findUnique({
    where: { id: targetEventId },
    select: {
      id: true,
      revision: true,
    },
  });
  if (!existing) {
    throw new Error('待更新的活动不存在');
  }
  validateBaseEventRevision(payload, existing.revision);
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

const inferFestivalDayIndex = (
  startTime: Date,
  eventStartDate: Date,
  dayRolloverHour: number,
  timeZone = DEFAULT_EVENT_TIME_ZONE
): number | null => {
  if (Number.isNaN(startTime.getTime()) || Number.isNaN(eventStartDate.getTime())) {
    return null;
  }
  let dayOffset = diffEventDays(eventStartDate, startTime, timeZone);
  if (dayOffset > 0 && getEventHour(startTime, timeZone) < dayRolloverHour) {
    dayOffset -= 1;
  }
  return Math.max(1, dayOffset + 1);
};

const applyFestivalDayIndexToDate = (
  timeSource: Date,
  eventStartDate: Date,
  festivalDayIndex: number,
  timeZone = DEFAULT_EVENT_TIME_ZONE
): Date => setEventDayAndKeepTime(timeSource, eventStartDate, festivalDayIndex, timeZone);

const explicitFestivalDayCarryOffset = (
  timeSource: Date,
  eventStartDate: Date,
  festivalDayIndex: number,
  timeZone = DEFAULT_EVENT_TIME_ZONE
): number => {
  const logicalDay = applyFestivalDayIndexToDate(timeSource, eventStartDate, festivalDayIndex, timeZone);
  return Math.max(0, diffEventDays(logicalDay, timeSource, timeZone));
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
  eventStartDate: Date,
  dayRolloverHourRaw: unknown = 6,
  timeZoneRaw: unknown = DEFAULT_EVENT_TIME_ZONE
): CanonicalLineupSlotInput[] => {
  if (!Array.isArray(slots)) return [];

  const dayRolloverHour = normalizeDayRolloverHour(dayRolloverHourRaw, 6);
  const timeZone = normalizeEventTimeZone(timeZoneRaw);
  const safeEventStart = Number.isNaN(eventStartDate.getTime()) ? new Date() : eventStartDate;

  return slots
    .filter((slot): slot is Record<string, unknown> => typeof slot === 'object' && slot !== null)
    .map((slot, index) => {
      const parsedStart = parseEventDateInput(slot.startTime, timeZone, 'start');
      const parsedEnd = parseEventDateInput(slot.endTime, timeZone, 'end');
      const fallbackBase = new Date(safeEventStart.getTime() + index * 60_000);
      const explicitFestivalDayIndex =
        typeof slot.festivalDayIndex === 'number' && Number.isFinite(slot.festivalDayIndex)
          ? Math.max(1, Math.floor(slot.festivalDayIndex))
          : null;

      let startTime = parsedStart ?? fallbackBase;
      let endTime = parsedEnd ?? new Date(startTime.getTime() + 3_600_000);
      if (endTime < startTime) {
        endTime = new Date(startTime.getTime() + 3_600_000);
      }

      if (explicitFestivalDayIndex) {
        const startCarryOffset = explicitFestivalDayCarryOffset(startTime, safeEventStart, explicitFestivalDayIndex, timeZone);
        const endCarryOffset = explicitFestivalDayCarryOffset(endTime, safeEventStart, explicitFestivalDayIndex, timeZone);
        startTime = applyFestivalDayIndexToDate(startTime, safeEventStart, explicitFestivalDayIndex + startCarryOffset, timeZone);
        endTime = applyFestivalDayIndexToDate(endTime, safeEventStart, explicitFestivalDayIndex + endCarryOffset, timeZone);
        if (endTime < startTime) {
          endTime = new Date(endTime.getTime() + 86_400_000);
        }
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
      const festivalDayIndex =
        explicitFestivalDayIndex
        ?? inferFestivalDayIndex(startTime, safeEventStart, dayRolloverHour, timeZone);
      const memberDjIds = cleanedMemberDjIds.length ? cleanedMemberDjIds : (effectiveDjId ? [effectiveDjId] : []);
      const hasIdentity = djName.length > 0 || !!effectiveDjId || memberDjIds.some(Boolean);
      if (!hasIdentity) return null;
      const slotId = cleanText(slot.id);

      const lineupArtistId = cleanText(slot.lineupArtistId);
      const normalizedSlot: CanonicalLineupSlotInput = {
        ...(slotId ? { id: slotId } : {}),
        ...(lineupArtistId ? { lineupArtistId } : {}),
        djId: effectiveDjId,
        memberDjIds,
        djName: djName || 'Unknown DJ',
        stageName: typeof slot.stageName === 'string' && slot.stageName.trim() ? slot.stageName.trim() : null,
        festivalDayIndex,
        startTime,
        endTime,
        sortOrder: typeof slot.sortOrder === 'number' && Number.isFinite(slot.sortOrder) ? slot.sortOrder : index + 1,
      };
      return normalizedSlot;
    })
    .filter((slot): slot is CanonicalLineupSlotInput => slot !== null);
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

const syncLineupArtistsForAffectedTimetableKeys = (
  currentArtists: CanonicalLineupArtistInput[],
  currentSlots: CanonicalLineupSlotInput[],
  affectedKeys: Set<string>
): CanonicalLineupArtistInput[] => {
  if (affectedKeys.size === 0) return currentArtists;

  const slotArtists = normalizeCanonicalLineupArtists([], currentSlots);
  const slotArtistByKey = new Map<string, CanonicalLineupArtistInput>();
  for (const artist of slotArtists) {
    slotArtistByKey.set(lineupIdentityKey(artist), artist);
  }

  const currentByKey = new Map<string, CanonicalLineupArtistInput>();
  for (const artist of currentArtists) {
    currentByKey.set(lineupIdentityKey(artist), artist);
  }

  const result = currentArtists
    .filter((artist) => !affectedKeys.has(lineupIdentityKey(artist)))
    .map(cloneArtistInput);

  const removedAffectedArtists = currentArtists
    .filter((artist) => affectedKeys.has(lineupIdentityKey(artist)) && !slotArtistByKey.has(lineupIdentityKey(artist)))
    .slice()
    .sort((a, b) => a.sortOrder - b.sortOrder);
  const reusableSortOrders = removedAffectedArtists.map((artist) => artist.sortOrder).filter((value) => Number.isFinite(value));
  let nextSortOrder = result.reduce((max, artist) => Math.max(max, artist.sortOrder), 0);

  for (const slotArtist of slotArtists) {
    const key = lineupIdentityKey(slotArtist);
    if (!affectedKeys.has(key)) continue;
    const existing = currentByKey.get(key);
    const reusedSortOrder = reusableSortOrders.shift();
    const sortOrder = existing?.sortOrder
      ?? reusedSortOrder
      ?? ++nextSortOrder;
    result.push({
      ...slotArtist,
      id: existing?.id,
      sortOrder,
    });
    nextSortOrder = Math.max(nextSortOrder, sortOrder);
  }

  return result
    .slice()
    .sort((a, b) => a.sortOrder - b.sortOrder)
    .map((artist, index) => ({ ...artist, sortOrder: artist.sortOrder || index + 1 }));
};

const collectAffectedTimetableIdentityKeys = (
  previousSlots: CanonicalLineupSlotInput[],
  nextSlots: CanonicalLineupSlotInput[]
): Set<string> => {
  const affected = new Set<string>();
  const previousById = new Map(previousSlots.map((slot) => [slot.id, slot]).filter((entry): entry is [string, CanonicalLineupSlotInput] => Boolean(entry[0])));
  const nextById = new Map(nextSlots.map((slot) => [slot.id, slot]).filter((entry): entry is [string, CanonicalLineupSlotInput] => Boolean(entry[0])));

  for (const [id, previous] of previousById) {
    const next = nextById.get(id);
    if (!next) {
      affected.add(lineupIdentityKey({
        djId: previous.djId,
        memberDjIds: previous.memberDjIds,
        djName: previous.djName,
      }));
      continue;
    }
    const previousKey = lineupIdentityKey({
      djId: previous.djId,
      memberDjIds: previous.memberDjIds,
      djName: previous.djName,
    });
    const nextKey = lineupIdentityKey({
      djId: next.djId,
      memberDjIds: next.memberDjIds,
      djName: next.djName,
    });
    if (previousKey !== nextKey) {
      affected.add(previousKey);
      affected.add(nextKey);
    }
  }

  for (const next of nextSlots) {
    if (!next.id || previousById.has(next.id)) continue;
    affected.add(lineupIdentityKey({
      djId: next.djId,
      memberDjIds: next.memberDjIds,
      djName: next.djName,
    }));
  }

  return affected;
};

export const buildAlignedLineupArtistsFromTimetablePayload = (
  payload: Prisma.JsonObject,
  eventStartDate: Date,
  dayRolloverHour: number,
  timeZone: string
): CanonicalLineupArtistInput[] => {
  const slots = normalizeSubmissionLineupSlots(payload.lineupSlots, eventStartDate, dayRolloverHour, timeZone);
  const currentArtists = normalizeSubmissionLineupArtists(payload.lineupArtists, []);
  const timetableArtists = normalizeCanonicalLineupArtists([], slots);
  return mergeAlignedLineupArtists(currentArtists, timetableArtists);
};

export const autoAlignEventLineupToTimetablePayload = (
  payload: Prisma.JsonObject,
  eventStartDate: Date,
  dayRolloverHour: number,
  timeZone: string
): Prisma.JsonObject => {
  const slots = normalizeSubmissionLineupSlots(payload.lineupSlots, eventStartDate, dayRolloverHour, timeZone);
  if (slots.length === 0) return payload;
  const alignedArtists = buildAlignedLineupArtistsFromTimetablePayload(
    payload,
    eventStartDate,
    dayRolloverHour,
    timeZone
  );
  return {
    ...payload,
    lineupArtists: alignedArtists as unknown as Prisma.JsonValue,
    lineupSlots: relinkSlotsToAlignedArtists(slots, alignedArtists) as unknown as Prisma.JsonValue,
  } as Prisma.JsonObject;
};

export const validateEventLineupTimetableAlignment = (
  payload: Prisma.JsonObject,
  eventStartDate: Date,
  dayRolloverHour: number,
  timeZone: string
): EventLineupTimetableAlignmentIssue | null => {
  const slots = normalizeSubmissionLineupSlots(payload.lineupSlots, eventStartDate, dayRolloverHour, timeZone);
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

const requirePatchId = (row: Record<string, unknown>, field: string, label: string): string => {
  const id = cleanText(row[field]);
  if (!id) {
    throw new Error(`${label} 缺少稳定 ID，无法执行增量编辑`);
  }
  return id;
};

const normalizedStageText = (value: string | null | undefined): string =>
  cleanText(value)?.toLocaleLowerCase() || '';

const applySubmissionLineupPatch = async (
  tx: Prisma.TransactionClient,
  eventId: string,
  payload: Prisma.JsonObject,
  eventStartDate: Date,
  dayRolloverHour: number,
  timeZone: string
): Promise<{
  artists: CanonicalLineupArtistInput[];
  slots: CanonicalLineupSlotInput[];
  stageOrder: string[];
}> => {
  const snapshot: CanonicalLineupSnapshot = await loadCanonicalEventLineupSnapshot(tx, eventId);
  let artists = snapshot.artists.slice();
  let slots = snapshot.slots.slice();
  const affectedTimetableIdentityKeys = new Set<string>();
  let stageOrder = normalizeEventStageOrder(payload.stageOrder);
  if (stageOrder.length === 0) stageOrder = snapshot.stageOrder.slice();

  const artistById = () => new Map(artists.map((artist) => [artist.id, artist]).filter((entry): entry is [string, CanonicalLineupArtistInput] => Boolean(entry[0])));
  const slotById = () => new Map(slots.map((slot) => [slot.id, slot]).filter((entry): entry is [string, CanonicalLineupSlotInput] => Boolean(entry[0])));

  const lineupChanges = Array.isArray(payload.lineupChanges) ? payload.lineupChanges : [];
  for (const rawChange of lineupChanges) {
    if (!isPlainObject(rawChange)) continue;
    const op = cleanText(rawChange.op);
    if (op === 'add') {
      const artistPayload = jsonObjectOrNull(rawChange.artist);
      const normalized = normalizeSubmissionLineupArtists(artistPayload ? [artistPayload] : [], []);
      if (normalized.length === 0) throw new Error('新增艺人缺少名称或 DJ 信息');
      artists.push({
        ...normalized[0],
        sortOrder: normalized[0].sortOrder || artists.length + 1,
      });
      continue;
    }

    const artistId = requirePatchId(rawChange, 'artistId', '艺人变更');
    const existing = artistById().get(artistId);
    if (!existing) throw new Error(`艺人不存在或已变化，无法执行增量编辑：${artistId}`);

    if (op === 'delete') {
      const linkedSlots = slots.filter((slot) => slot.lineupArtistId === artistId || (slot.id && slot.djName === existing.djName));
      if (linkedSlots.length > 0) {
        throw new Error(`艺人「${existing.djName}」仍被时间表引用，请先删除对应 time slot 后再删除艺人`);
      }
      artists = artists.filter((artist) => artist.id !== artistId);
      continue;
    }

    if (op === 'update') {
      const patch = jsonObjectOrNull(rawChange.patch);
      if (!patch) throw new Error('艺人更新缺少 patch 内容');
      const normalized = normalizeSubmissionLineupArtists([{ ...existing, ...patch, id: artistId }], []);
      if (normalized.length === 0) throw new Error(`艺人更新内容无效：${artistId}`);
      artists = artists.map((artist) => artist.id === artistId ? { ...normalized[0], id: artistId } : artist);
      continue;
    }

    if (op === 'reorder') {
      const sortOrder = integerOrNull(rawChange.sortOrder);
      if (sortOrder === null) throw new Error('艺人排序变更缺少 sortOrder');
      artists = artists.map((artist) => artist.id === artistId ? { ...artist, sortOrder } : artist);
      continue;
    }

    throw new Error(`不支持的艺人增量操作：${op || 'unknown'}`);
  }

  const timetableChanges = Array.isArray(payload.timetableChanges) ? payload.timetableChanges : [];
  for (const rawChange of timetableChanges) {
    if (!isPlainObject(rawChange)) continue;
    const op = cleanText(rawChange.op);
    if (op === 'add') {
      const slotPayload = jsonObjectOrNull(rawChange.slot);
      const normalized = normalizeSubmissionLineupSlots(slotPayload ? [slotPayload] : [], eventStartDate, dayRolloverHour, timeZone);
      if (normalized.length === 0) throw new Error('新增 time slot 缺少艺人或时间信息');
      affectedTimetableIdentityKeys.add(lineupIdentityKey({
        djId: normalized[0].djId,
        memberDjIds: normalized[0].memberDjIds,
        djName: normalized[0].djName,
      }));
      slots.push({
        ...normalized[0],
        sortOrder: normalized[0].sortOrder || slots.length + 1,
      });
      continue;
    }

    const slotId = requirePatchId(rawChange, 'slotId', '时间表变更');
    const existing = slotById().get(slotId);
    if (!existing) throw new Error(`time slot 不存在或已变化，无法执行增量编辑：${slotId}`);
    affectedTimetableIdentityKeys.add(lineupIdentityKey({
      djId: existing.djId,
      memberDjIds: existing.memberDjIds,
      djName: existing.djName,
    }));

    if (op === 'delete') {
      slots = slots.filter((slot) => slot.id !== slotId);
      continue;
    }

    if (op === 'update') {
      const patch = jsonObjectOrNull(rawChange.patch);
      if (!patch) throw new Error('time slot 更新缺少 patch 内容');
      const normalized = normalizeSubmissionLineupSlots([{ ...existing, ...patch, id: slotId }], eventStartDate, dayRolloverHour, timeZone);
      if (normalized.length === 0) throw new Error(`time slot 更新内容无效：${slotId}`);
      affectedTimetableIdentityKeys.add(lineupIdentityKey({
        djId: normalized[0].djId,
        memberDjIds: normalized[0].memberDjIds,
        djName: normalized[0].djName,
      }));
      slots = slots.map((slot) => slot.id === slotId ? { ...normalized[0], id: slotId } : slot);
      continue;
    }

    if (op === 'reorder') {
      const sortOrder = integerOrNull(rawChange.sortOrder);
      if (sortOrder === null) throw new Error('time slot 排序变更缺少 sortOrder');
      slots = slots.map((slot) => slot.id === slotId ? { ...slot, sortOrder } : slot);
      continue;
    }

    throw new Error(`不支持的时间表增量操作：${op || 'unknown'}`);
  }

  const stageChanges = Array.isArray(payload.stageChanges) ? payload.stageChanges : [];
  for (const rawChange of stageChanges) {
    if (!isPlainObject(rawChange)) continue;
    const op = cleanText(rawChange.op);
    const stageName = cleanText(rawChange.name);
    if (!stageName) throw new Error('舞台变更缺少 stage name');
    const normalizedStageName = normalizedStageText(stageName);

    if (op === 'delete') {
      if (rawChange.confirmDeleteLinkedPerformances !== true) {
        throw new Error(`删除舞台「${stageName}」会删除该舞台下的全部演出，请确认后再提交`);
      }
      stageOrder = stageOrder.filter((name) => normalizedStageText(name) !== normalizedStageName);
      slots = slots.filter((slot) => normalizedStageText(slot.stageName) !== normalizedStageName);
      continue;
    }

    if (op === 'rename') {
      const nextName = cleanText(rawChange.nextName);
      if (!nextName) throw new Error('舞台重命名缺少新名称');
      const hasExactStageMatch = stageOrder.some((name) => normalizedStageText(name) === normalizedStageName);
      const canFallbackSingleStageRename = !hasExactStageMatch && stageOrder.length === 1;
      if (!hasExactStageMatch && !canFallbackSingleStageRename) {
        throw new Error(`舞台不存在或已变化，无法重命名：${stageName}`);
      }
      if (canFallbackSingleStageRename) {
        const currentOnlyStageName = stageOrder[0] || '';
        const normalizedCurrentOnlyStage = normalizedStageText(currentOnlyStageName);
        stageOrder = [nextName];
        slots = slots.map((slot) => normalizedStageText(slot.stageName) === normalizedCurrentOnlyStage
          ? { ...slot, stageName: nextName }
          : slot
        );
        continue;
      }
      stageOrder = stageOrder.map((name) => normalizedStageText(name) === normalizedStageName ? nextName : name);
      slots = slots.map((slot) => normalizedStageText(slot.stageName) === normalizedStageName ? { ...slot, stageName: nextName } : slot);
      continue;
    }

    throw new Error(`不支持的舞台增量操作：${op || 'unknown'}`);
  }

  const normalizedSlots = slots
    .slice()
    .sort((a, b) => a.sortOrder - b.sortOrder)
    .map((slot, index) => ({ ...slot, sortOrder: slot.sortOrder || index + 1 }));
  const normalizedArtists = normalizeCanonicalLineupArtists(
    artists.slice().sort((a, b) => a.sortOrder - b.sortOrder),
    normalizedSlots
  );
  const finalArtists = affectedTimetableIdentityKeys.size > 0
    ? syncLineupArtistsForAffectedTimetableKeys(normalizedArtists, normalizedSlots, affectedTimetableIdentityKeys)
    : normalizedArtists;
  const finalSlots = relinkSlotsToAlignedArtists(normalizedSlots, finalArtists);

  return {
    artists: finalArtists,
    slots: finalSlots,
    stageOrder,
  };
};

const syncSubmissionEventLineupAndTimetable = async (
  tx: Prisma.TransactionClient,
  eventId: string,
  payload: Prisma.JsonObject,
  eventStartDate: Date,
  dayRolloverHour: number,
  timeZone: string
): Promise<void> => {
  if (cleanText(payload.editMode) === 'patch') {
    const patched = await applySubmissionLineupPatch(tx, eventId, payload, eventStartDate, dayRolloverHour, timeZone);
    if (patched.slots.length === 0 && patched.artists.length === 0 && patched.stageOrder.length === 0) {
      return;
    }
    await syncCanonicalEventLineupAndTimetable(tx, eventId, patched.slots, patched.artists, patched.stageOrder);
    return;
  }

  const snapshot: CanonicalLineupSnapshot = await loadCanonicalEventLineupSnapshot(tx, eventId);
  const slots = normalizeSubmissionLineupSlots(payload.lineupSlots, eventStartDate, dayRolloverHour, timeZone);
  const submittedArtists = normalizeSubmissionLineupArtists(payload.lineupArtists, []);
  const normalizedArtists = normalizeCanonicalLineupArtists(submittedArtists, slots);
  const affectedIdentityKeys = collectAffectedTimetableIdentityKeys(snapshot.slots, slots);
  const artists = slots.length > 0
    ? (affectedIdentityKeys.size > 0
      ? syncLineupArtistsForAffectedTimetableKeys(normalizedArtists, slots, affectedIdentityKeys)
      : normalizedArtists)
    : normalizeCanonicalLineupArtists(submittedArtists, slots);
  const relinkedSlots = relinkSlotsToAlignedArtists(slots, artists);
  const stageOrder = normalizeEventStageOrder(payload.stageOrder);

  if (slots.length === 0 && artists.length === 0 && stageOrder.length === 0) {
    return;
  }

  await syncCanonicalEventLineupAndTimetable(tx, eventId, relinkedSlots, artists, stageOrder);
};

const runEventSubmissionTransaction = async <T>(
  db: PrismaClient,
  callback: (tx: Prisma.TransactionClient) => Promise<T>
): Promise<T> => db.$transaction(callback, {
  timeout: EVENT_SUBMISSION_TRANSACTION_TIMEOUT_MS,
  maxWait: EVENT_SUBMISSION_TRANSACTION_MAX_WAIT_MS,
});

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

export async function createOrUpdateEventFromSubmission(
  db: PrismaClient,
  payload: Prisma.JsonObject,
  submitterId: string,
  options: {
    submissionId?: string;
  } = {}
) {
  const name = cleanText(payload.name);
  let targetEventId = getEventEditTargetIdFromPayload(payload);
  if (!targetEventId && options.submissionId) {
    const existingSubmission = await db.contentSubmission.findUnique({
      where: { id: options.submissionId },
      select: { createdEntityId: true },
    });
    targetEventId = cleanText(existingSubmission?.createdEntityId) || null;
  }
  const rawTimeZone = payload.timeZone ?? payload.timezone ?? payload.eventTimeZone;
  if (!isValidEventTimeZone(rawTimeZone)) {
    throw new Error('活动时区不能为空或格式不正确');
  }
  const timeZone = normalizeEventTimeZone(rawTimeZone);
  const startDateRaw = parseEventDateInput(payload.startDate, timeZone, 'start', payload.startTime);
  const endDateRaw = parseEventDateInput(payload.endDate, timeZone, 'end', payload.endTime);
  const startDate = startDateRaw ? startOfEventDay(startDateRaw, timeZone) : null;
  const endDate = endDateRaw ? new Date(startOfEventDay(endDateRaw, timeZone).getTime() + 86_400_000 - 1000) : null;
  if (!name || !startDate || !endDate) {
    throw new Error('活动名称、开始日期和结束日期不能为空');
  }

  const imageAssets = eventImageAssetsFromPayload(payload.imageAssets);
  if (!hasRequiredEventPrimaryImageAsset(imageAssets)) {
    throw new Error('至少需要上传一张海报、阵容图或封面图');
  }

  const ticketCurrency = cleanText(payload.ticketCurrency) || null;
  const ticketTiers = eventTicketTiersFromPayload(payload.ticketTiers, ticketCurrency || undefined);
  const eventData = {
    name,
    nameI18n: triTextToJson(normalizeTriTextPayload(payload.nameI18n, name)),
    description: cleanText(payload.description) || null,
    descriptionI18n: triTextToJson(normalizeTriTextPayload(payload.descriptionI18n, cleanText(payload.description) || '')),
    coverImageUrl: cleanText(payload.coverImageUrl) || null,
    lineupImageUrl: cleanText(payload.lineupImageUrl) || null,
    imageAssets: imageAssets.length ? imageAssets : Prisma.JsonNull,
    eventType: cleanText(payload.eventType) || null,
    organizerName: cleanText(payload.organizerName) || null,
    city: cleanText(payload.city) || null,
    country: cleanText(payload.country) || null,
    cityI18n: triTextToJson(normalizeTriTextPayload(payload.cityI18n, cleanText(payload.city) || '')),
    countryI18n: triTextToJson(normalizeTriTextPayload(payload.countryI18n, cleanText(payload.country) || '')),
    manualLocation: (payload.manualLocation as Prisma.InputJsonValue | undefined) ?? Prisma.JsonNull,
    locationPoint: (payload.locationPoint as Prisma.InputJsonValue | undefined) ?? Prisma.JsonNull,
    latitude: decimalOrNull(payload.latitude),
    longitude: decimalOrNull(payload.longitude),
    startDate,
    endDate,
    timeZone,
    startTime: cleanText(payload.startTime) || undefined,
    endTime: cleanText(payload.endTime) || undefined,
    dayRolloverHour: integerOrNull(payload.dayRolloverHour) ?? undefined,
    ticketUrl: cleanText(payload.ticketUrl) || null,
    ticketPriceMin: decimalOrNull(payload.ticketPriceMin),
    ticketPriceMax: decimalOrNull(payload.ticketPriceMax),
    ticketCurrency,
    ticketNotes: cleanText(payload.ticketNotes) || null,
    officialWebsite: cleanText(payload.officialWebsite) || null,
    status: cleanText(payload.status) || 'upcoming',
    isVerified: true,
  } as any;

  if (targetEventId) {
    const existing = await db.event.findUnique({
      where: { id: targetEventId },
      select: {
        id: true,
        revision: true,
      },
    });
    if (!existing) {
      throw new Error('待更新的活动不存在');
    }
    validateBaseEventRevision(payload, existing.revision);

    await runEventSubmissionTransaction(db, async (tx) => {
      await tx.event.update({
        where: { id: targetEventId },
        data: {
          ...eventData,
          revision: { increment: 1 },
          ticketTiers: {
            deleteMany: {},
            create: ticketTiers,
          },
        },
      });
      await syncSubmissionEventLineupAndTimetable(
        tx,
        targetEventId,
        payload,
        startDate,
        integerOrNull(payload.dayRolloverHour) ?? 6,
        timeZone
      );
      if (options.submissionId) {
        await cancelSupersededActiveEventEditSubmissions(tx, targetEventId, options.submissionId);
      }
    });

    return db.event.findUniqueOrThrow({
      where: { id: targetEventId },
    });
  }

  const slug = await uniqueEventSlug(db, name, cleanText(payload.slug));
  const created = await runEventSubmissionTransaction(db, async (tx) => {
    const created = await tx.event.create({
      data: {
        organizerId: submitterId,
        slug,
        ...eventData,
        ticketTiers: ticketTiers.length
          ? {
              create: ticketTiers,
            }
          : undefined,
      } as any,
    });
    if (options.submissionId) {
      await tx.contentSubmission.update({
        where: { id: options.submissionId },
        data: {
          createdEntityId: created.id,
        },
      });
    }
    await syncSubmissionEventLineupAndTimetable(
      tx,
      created.id,
      payload,
      startDate,
      integerOrNull(payload.dayRolloverHour) ?? 6,
      timeZone
    );
    return created;
  });

  return db.event.findUniqueOrThrow({
    where: { id: created.id },
  });
}
