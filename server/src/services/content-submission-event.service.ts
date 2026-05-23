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
  type CanonicalLineupArtistInput,
  type CanonicalLineupSlotInput,
  normalizeCanonicalLineupArtists,
  syncCanonicalEventLineupAndTimetable,
} from './event-lineup-canonical.service';

const LINEUP_DJ_ID_PLACEHOLDER = '__UNBOUND__';

const cleanText = (value: unknown): string | undefined => {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed || undefined;
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

      return {
        djId: effectiveDjId,
        memberDjIds,
        djName: djName || 'Unknown DJ',
        stageName: typeof slot.stageName === 'string' && slot.stageName.trim() ? slot.stageName.trim() : null,
        festivalDayIndex,
        startTime,
        endTime,
        sortOrder: typeof slot.sortOrder === 'number' && Number.isFinite(slot.sortOrder) ? slot.sortOrder : index + 1,
      } satisfies CanonicalLineupSlotInput;
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
        return {
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

const syncSubmissionEventLineupAndTimetable = async (
  tx: Prisma.TransactionClient,
  eventId: string,
  payload: Prisma.JsonObject,
  eventStartDate: Date,
  dayRolloverHour: number,
  timeZone: string
): Promise<void> => {
  const slots = normalizeSubmissionLineupSlots(payload.lineupSlots, eventStartDate, dayRolloverHour, timeZone);
  const artists = normalizeSubmissionLineupArtists(payload.lineupArtists, slots);
  const stageOrder = normalizeEventStageOrder(payload.stageOrder);

  if (slots.length === 0 && artists.length === 0 && stageOrder.length === 0) {
    return;
  }

  await syncCanonicalEventLineupAndTimetable(tx, eventId, slots, artists, stageOrder);
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

export async function createOrUpdateEventFromSubmission(
  db: PrismaClient,
  payload: Prisma.JsonObject,
  submitterId: string
) {
  const name = cleanText(payload.name);
  const targetEventId = cleanText(payload.targetEventId) || cleanText(payload.editTargetEventId);
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
      select: { id: true },
    });
    if (!existing) {
      throw new Error('待更新的活动不存在');
    }

    return db.$transaction(async (tx) => {
      await tx.event.update({
        where: { id: targetEventId },
        data: {
          ...eventData,
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
      return tx.event.findUniqueOrThrow({
        where: { id: targetEventId },
      });
    });
  }

  const slug = await uniqueEventSlug(db, name, cleanText(payload.slug));
  return db.$transaction(async (tx) => {
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
}
