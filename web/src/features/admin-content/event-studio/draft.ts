import {
  EventStudioDraft,
  EventStudioEventDayDraft,
  EventStudioImageOrigin,
  EventStudioImageState,
  EventStudioImageUsage,
  EventStudioLineupArtistDraft,
  EventStudioLoadedEvent,
  EventStudioLocalizedText,
  EventStudioTicketTierDraft,
  EventStudioTimetableSlotDraft,
  EventStudioWeekDraft,
} from './types';
import { formatClockTimeInTimeZone, formatDateInputInTimeZone, normalizeDisplayTimeZone } from '@/lib/timezone';

const EVENT_STUDIO_ACT_TYPES = ['solo', 'b2b', 'b3b'] as const;
type EventStudioActType = (typeof EVENT_STUDIO_ACT_TYPES)[number];

const normalizeActType = (value?: string | null): EventStudioActType => {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'b2b' || normalized === 'b3b') return normalized;
  return 'solo';
};

const inferActType = (value?: string | null, performerCount = 0): EventStudioActType => {
  const normalized = normalizeActType(value);
  if (normalized !== 'solo') return normalized;
  if (performerCount >= 3) return 'b3b';
  if (performerCount === 2) return 'b2b';
  return 'solo';
};

const emptyLocalizedText = (): EventStudioLocalizedText => ({
  zh: '',
  en: '',
  ja: '',
  enFull: '',
});

type EventStudioLooseLocalizedText = {
  zh?: string | null;
  en?: string | null;
  ja?: string | null;
  enFull?: string | null;
};

const createTicketTier = (): EventStudioTicketTierDraft => ({
  id: crypto.randomUUID(),
  name: '',
  price: '',
  currency: 'CNY',
});

const EVENT_STUDIO_IMAGE_USAGES: EventStudioImageUsage[] = ['poster', 'lineup', 'timetable', 'cover', 'map', 'other'];

const createEmptyImageZones = (): Record<EventStudioImageUsage, EventStudioImageState[]> => ({
  poster: [],
  lineup: [],
  timetable: [],
  cover: [],
  map: [],
  other: [],
});

const normalizeImageZones = (
  zones?: Partial<Record<EventStudioImageUsage, EventStudioImageState[] | null>> | null
): Record<EventStudioImageUsage, EventStudioImageState[]> => {
  const next = createEmptyImageZones();
  EVENT_STUDIO_IMAGE_USAGES.forEach((usage) => {
    const items = Array.isArray(zones?.[usage]) ? zones?.[usage] : [];
    next[usage] = (items || []).map((item, index) => ({
      ...item,
      id: item.id || crypto.randomUUID(),
      usage,
      sortOrder: item.sortOrder || index + 1,
      mimeType: item.mimeType || null,
      localPreviewUrl: item.localPreviewUrl || null,
      localFile: item.localFile || null,
      uploadState: item.uploadState || (item.remoteUrl?.trim() ? 'uploaded' : 'pending'),
    }));
  });
  return next;
};

const createImageState = (input: {
  usage: EventStudioImageUsage;
  remoteUrl: string;
  fileName: string;
  origin: EventStudioImageOrigin;
  sortOrder?: number;
}): EventStudioImageState => ({
  id: crypto.randomUUID(),
  usage: input.usage,
  remoteUrl: input.remoteUrl,
  fileName: input.fileName,
  origin: input.origin,
  sortOrder: input.sortOrder || 1,
  mimeType: null,
  localPreviewUrl: null,
  localFile: null,
  uploadState: input.remoteUrl.trim() ? 'uploaded' : 'pending',
});

const classifyEventImageUsage = (type?: string | null, label?: string | null): EventStudioImageUsage => {
  const normalizedType = String(type || '').trim().toLowerCase();
  const normalizedLabel = String(label || '').trim().toUpperCase();
  if (normalizedType === 'cover' || normalizedLabel.includes('COVER')) return 'cover';
  if (normalizedType === 'luall' || normalizedType === 'lineup' || normalizedLabel.includes('LINE-UP')) return 'lineup';
  if (normalizedType === 'tt' || normalizedType === 'timetable' || normalizedLabel.includes('TIMETABLE')) return 'timetable';
  if (normalizedType === 'poster' || normalizedLabel.includes('POSTER')) return 'poster';
  if (normalizedLabel.includes('MAP')) return 'map';
  return 'other';
};

const splitMemberNamesText = (value: string): string[] =>
  value
    .replace(/\bB2B\b/gi, '/')
    .replace(/\bB3B\b/gi, '/')
    .split(/[\/,&]/)
    .map((item) => item.trim())
    .filter(Boolean);

const composeActDisplayName = (actType?: string | null, memberNamesText?: string | null): string => {
  const normalizedActType = normalizeActType(actType);
  const names = splitMemberNamesText(String(memberNamesText || ''));
  if (!names.length) return '';
  if (normalizedActType === 'b3b') return names.slice(0, 3).join(' B3B ');
  if (normalizedActType === 'b2b') return names.slice(0, 2).join(' B2B ');
  return names[0] || '';
};

const resolveDisplayNameOverride = (
  actType: string | null | undefined,
  memberNamesText: string,
  displayName?: string | null
): string | undefined => {
  const normalizedDisplayName = String(displayName || '').trim();
  if (!normalizedDisplayName) return undefined;
  return normalizedDisplayName === composeActDisplayName(actType, memberNamesText) ? undefined : normalizedDisplayName;
};

const defaultMemberNamesText = (members?: string[] | null, fallback?: string | null): string => {
  const normalizedMembers = Array.isArray(members)
    ? members.flatMap((item) => splitMemberNamesText(String(item || '')))
    : [];
  if (normalizedMembers.length > 0) {
    return normalizedMembers.join(' / ');
  }
  return splitMemberNamesText(String(fallback || '')).join(' / ');
};

const normalizedMemberDjIds = (memberDjIds?: Array<string | null> | null): string[] =>
  (memberDjIds ?? [])
    .map((item) => String(item || '').trim())
    .filter(Boolean);

const firstNonEmptyArray = <T,>(...candidates: Array<T[] | null | undefined>): T[] =>
  candidates.find((items) => Array.isArray(items) && items.length > 0) ?? [];

export const eventStudioLineupArtistIdentityKey = (artist: Pick<
  EventStudioLineupArtistDraft,
  'djId' | 'memberDjIds' | 'memberNamesText'
>): string | null => {
  const djId = artist.djId.trim();
  if (djId) return `dj:${djId}`;

  const memberDjIds = normalizedMemberDjIds(artist.memberDjIds).sort();
  if (memberDjIds.length) return `members:${memberDjIds.join('|')}`;

  const memberNames = splitMemberNamesText(artist.memberNamesText)
    .map((item) => item.toLowerCase())
    .sort();
  if (memberNames.length) return `names:${memberNames.join('|')}`;

  return null;
};

export const eventStudioTimetableSlotIdentityKey = (slot: Pick<
  EventStudioTimetableSlotDraft,
  'djId' | 'memberDjIds' | 'memberNamesText'
>): string | null =>
  eventStudioLineupArtistIdentityKey({
    djId: slot.djId,
    memberDjIds: slot.memberDjIds,
    memberNamesText: slot.memberNamesText,
  });

const defaultStageName = (): string => 'Main Stage';

const normalizeStageOrder = (stageOrder?: string[] | null, slots?: Array<{ stageName?: string | null }> | null): string[] => {
  const seen = new Set<string>();
  const result: string[] = [];
  let hasBlankSlot = false;
  const pushValue = (value?: string | null) => {
    const trimmed = String(value || '').trim();
    if (!trimmed) {
      hasBlankSlot = true;
      return;
    }
    const key = trimmed.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    result.push(trimmed);
  };

  (stageOrder ?? []).forEach(pushValue);
  (slots ?? []).forEach((slot) => pushValue(slot.stageName));
  if (!result.length && hasBlankSlot) {
    pushValue(defaultStageName());
  }
  return result;
};

export const buildLineupArtistsFromTimetableSlots = (
  timetableSlots: EventStudioTimetableSlotDraft[]
): EventStudioLineupArtistDraft[] => {
  const artistsByKey = new Map<string, EventStudioLineupArtistDraft>();

  timetableSlots.forEach((slot, index) => {
    const memberNamesText = slot.memberNamesText.trim();
    const normalizedDjId = slot.djId.trim();
    const normalizedMemberDjIds = slot.memberDjIds.map((item) => {
      const trimmed = String(item || '').trim();
      return trimmed || null;
    });
    const identityKey = eventStudioTimetableSlotIdentityKey(slot);
    if (!identityKey) return;
    if (artistsByKey.has(identityKey)) return;

    artistsByKey.set(identityKey, {
      id: crypto.randomUUID(),
      canonicalArtistId: slot.lineupArtistId || null,
      djId: normalizedDjId,
      memberDjIds: normalizedMemberDjIds,
      memberNamesText,
      displayNameOverride: slot.displayNameOverride,
      actType: inferActType(slot.actType, Math.max(memberNamesText ? memberNamesText.split(/[\/,&]/).map((item) => item.trim()).filter(Boolean).length : 0, normalizedMemberDjIds.filter(Boolean).length)),
      sortOrder: artistsByKey.size + 1 || index + 1,
    });
  });

  return Array.from(artistsByKey.values());
};

export const fillLineupArtistsFromTimetableSlots = (
  lineupArtists: EventStudioLineupArtistDraft[],
  timetableSlots: EventStudioTimetableSlotDraft[]
): EventStudioLineupArtistDraft[] => {
  const seenKeys = new Set(
    lineupArtists
      .map(eventStudioLineupArtistIdentityKey)
      .filter((key): key is string => Boolean(key))
  );
  const additions: EventStudioLineupArtistDraft[] = [];

  buildLineupArtistsFromTimetableSlots(timetableSlots).forEach((artist) => {
    const key = eventStudioLineupArtistIdentityKey(artist);
    if (!key || seenKeys.has(key)) return;
    seenKeys.add(key);
    additions.push({
      ...artist,
      id: crypto.randomUUID(),
      canonicalArtistId: null,
      actType: normalizeActType(artist.actType),
      sortOrder: lineupArtists.length + additions.length + 1,
    });
  });

  return [...lineupArtists, ...additions];
};

const buildLineupArtistsFromInput = (
  lineupArtists?: EventStudioLoadedEvent['lineupArtists'] | null
): EventStudioLineupArtistDraft[] => {
  if (!Array.isArray(lineupArtists)) return [];
  const result: EventStudioLineupArtistDraft[] = [];
  lineupArtists.forEach((artist, index) => {
    const memberNamesText = defaultMemberNamesText(artist.memberNames, artist.djName);
    const djId = String(artist.djId || '').trim();
    const memberDjIds = Array.isArray(artist.memberDjIds)
      ? artist.memberDjIds.map((item) => {
          const trimmed = String(item || '').trim();
          return trimmed || null;
        })
      : (djId ? [djId] : []);
    if (!memberNamesText && !djId) return;
    result.push({
      id: crypto.randomUUID(),
      canonicalArtistId: artist.id || null,
      djId,
      memberDjIds,
      memberNamesText,
      displayNameOverride: resolveDisplayNameOverride((artist as { performerType?: string | null }).performerType, memberNamesText, artist.djName),
      actType: inferActType((artist as { performerType?: string | null }).performerType, Math.max(memberNamesText ? memberNamesText.split(/[\/,&]/).map((item) => item.trim()).filter(Boolean).length : 0, memberDjIds.filter(Boolean).length, djId ? 1 : 0)),
      sortOrder: artist.sortOrder ?? index + 1,
    });
  });
  return result.sort((left, right) => left.sortOrder - right.sortOrder);
};

const datePartFromIsoLike = (value?: string | null): string => String(value || '').slice(0, 10);

const timePartFromIsoLike = (value?: string | null): string => {
  const text = String(value || '').trim();
  const match = text.match(/T(\d{2}:\d{2})/);
  if (match?.[1]) return match[1];
  if (/^\d{2}:\d{2}$/.test(text)) return text;
  return '';
};

const dayOffsetFromIsoLike = (value?: string | null): number => {
  const text = String(value || '').trim();
  const match = text.match(/^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})/);
  if (!match) return 0;
  const hour = Number(match[2].slice(0, 2));
  return Number.isFinite(hour) && hour >= 24 ? 1 : 0;
};

const composeSlotDateTime = (date: string, time: string): string => {
  const normalizedDate = date.trim();
  const normalizedTime = time.trim();
  if (!normalizedDate || !normalizedTime) return '';
  return `${normalizedDate}T${normalizedTime}:00`;
};

const isIsoInstantWithZone = (value?: string | null): boolean =>
  Boolean(String(value || '').trim().match(/Z$|[+-]\d{2}:\d{2}$/));

const timePartFromValueInTimeZone = (value?: string | null, timeZone?: string | null): string => {
  const text = String(value || '').trim();
  if (!text) return '';
  if (/^\d{2}:\d{2}$/.test(text)) return text;
  if (/^\d{4}-\d{2}-\d{2}T\d{1,2}:\d{2}/.test(text) && !isIsoInstantWithZone(text)) {
    return text.slice(11, 16);
  }
  return formatClockTimeInTimeZone(text, normalizeDisplayTimeZone(timeZone));
};

const datePartFromValueInTimeZone = (value?: string | null, timeZone?: string | null): string => {
  const text = String(value || '').trim();
  if (!text) return '';
  if (/^\d{4}-\d{2}-\d{2}$/.test(text)) return text;
  if (/^\d{4}-\d{2}-\d{2}T\d{1,2}:\d{2}/.test(text) && !isIsoInstantWithZone(text)) {
    return text.slice(0, 10);
  }
  return formatDateInputInTimeZone(text, normalizeDisplayTimeZone(timeZone));
};

export const normalizeEventStudioDateInput = (value?: string | null, timeZone?: string | null): string =>
  datePartFromValueInTimeZone(value, timeZone);

const dateOffsetFromBaseDate = (baseDate: string, valueDate: string): number => {
  const base = parseDateOnly(baseDate);
  const value = parseDateOnly(valueDate);
  if (!base || !value) return 0;
  return Math.max(0, Math.round((value.getTime() - base.getTime()) / 86400000));
};

const dayOffsetFromValueInTimeZone = (baseDate: string, value?: string | null, timeZone?: string | null): number => {
  const valueDate = datePartFromValueInTimeZone(value, timeZone);
  if (!baseDate || !valueDate) return 0;
  return dateOffsetFromBaseDate(baseDate, valueDate);
};

const normalizeSlotDayOffset = (value?: number | null): number => {
  const normalized = Math.max(0, Math.floor(Number(value) || 0));
  return normalized;
};

const mapTimetableSlotsToCurrentSchedule = (
  timetableSlots: EventStudioTimetableSlotDraft[],
  eventDays: EventStudioEventDayDraft[]
): EventStudioTimetableSlotDraft[] => {
  if (!timetableSlots.length || !eventDays.length) return [];

  const eventDayById = new Map(eventDays.map((day) => [day.eventDayId, day]));
  const eventDayByOverallDayIndex = new Map(eventDays.map((day) => [day.overallDayIndex, day]));
  const eventDayByDate = new Map(eventDays.map((day) => [day.date, day]));

  return timetableSlots.flatMap((slot, index) => {
    const matchedDay =
      eventDayById.get(slot.eventDayId) ||
      eventDayByOverallDayIndex.get(slot.overallDayIndex) ||
      eventDayByDate.get(slot.localDate);
    if (!matchedDay) return [];

    return [{
      ...slot,
      eventDayId: matchedDay.eventDayId,
      weekIndex: matchedDay.weekIndex,
      dayIndexInWeek: matchedDay.dayIndexInWeek,
      overallDayIndex: matchedDay.overallDayIndex,
      localDate: matchedDay.date,
      sortOrder: index + 1,
      startDayOffset: normalizeSlotDayOffset(slot.startDayOffset),
      endDayOffset: normalizeSlotDayOffset(slot.endDayOffset),
    }];
  });
};

export const syncEventStudioLineupState = (
  draft: EventStudioDraft,
  eventDays: EventStudioEventDayDraft[]
): Pick<EventStudioDraft, 'stageOrder' | 'lineupArtists' | 'timetableSlots'> => {
  const timetableSlots = mapTimetableSlotsToCurrentSchedule(draft.timetableSlots, eventDays);
  const lineupArtists = draft.lineupSyncMode === 'exact_align'
    ? buildLineupArtistsFromTimetableSlots(timetableSlots)
    : draft.lineupArtists;
  const stageOrder = normalizeStageOrder(draft.stageOrder, timetableSlots);
  const normalizedLineupArtists = lineupArtists.map((artist, index) => ({
    ...artist,
    actType: inferActType(artist.actType, Math.max(
      splitMemberNamesText(artist.memberNamesText).length,
      normalizedMemberDjIds(artist.memberDjIds).length,
      artist.djId.trim() ? 1 : 0
    )),
    sortOrder: artist.sortOrder || index + 1,
  }));
  const normalizedTimetableSlots = timetableSlots.map((slot, index) => ({
    ...slot,
    actType: inferActType(slot.actType, Math.max(
      splitMemberNamesText(slot.memberNamesText).length,
      normalizedMemberDjIds(slot.memberDjIds).length,
      slot.djId.trim() ? 1 : 0
    )),
    sortOrder: slot.sortOrder || index + 1,
  }));

  return {
    stageOrder,
    lineupArtists: normalizedLineupArtists,
    timetableSlots: normalizedTimetableSlots,
  };
};

export const createEmptyEventStudioTimetableSlotDraft = (
  eventDay?: EventStudioEventDayDraft,
  stageName = 'Main Stage'
): EventStudioTimetableSlotDraft => ({
  id: crypto.randomUUID(),
  canonicalSlotId: null,
  lineupArtistId: null,
  actType: 'solo',
  eventDayId: eventDay?.eventDayId || '',
  weekIndex: eventDay?.weekIndex || 1,
  dayIndexInWeek: eventDay?.dayIndexInWeek || 1,
  overallDayIndex: eventDay?.overallDayIndex || 1,
  localDate: eventDay?.date || '',
  djId: '',
  memberDjIds: [],
  memberNamesText: '',
  stageName,
  sortOrder: 1,
  startTime: '',
  endTime: '',
  startDayOffset: 0,
  endDayOffset: 0,
});

const parseDateOnly = (value: string): Date | null => {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const [year, month, day] = trimmed.slice(0, 10).split('-').map(Number);
  if (!year || !month || !day) return null;
  const parsed = new Date(year, month - 1, day);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const formatDateOnly = (date: Date): string => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

const weekdayKey = (date: Date): string =>
  ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'][date.getDay()] || 'unknown';

const weekdayDisplayName = (date: Date): string =>
  ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][date.getDay()] || 'Unknown';

const eventDayIdentifier = (
  scheduleMode: EventStudioDraft['scheduleMode'],
  weekIndex: number,
  dayIndexInWeek: number,
  overallDayIndex: number
): string => (scheduleMode === 'multi_week' ? `w${weekIndex}d${dayIndexInWeek}` : `d${overallDayIndex}`);

const defaultScheduleMode = (startDate: string, endDate: string) => {
  if (!startDate || !endDate) return 'single_day' as const;
  if (startDate === endDate) return 'single_day' as const;
  return 'multi_day' as const;
};

const normalizeWeekLabel = (weekIndex: number, scheduleMode: EventStudioDraft['scheduleMode']) =>
  scheduleMode === 'multi_week' ? `Week ${weekIndex}` : '';

export const buildEventStudioScheduleStructure = (
  scheduleMode: EventStudioDraft['scheduleMode'],
  startDateValue: string,
  endDateValue: string
): {
  weeks: EventStudioWeekDraft[];
  eventDays: EventStudioEventDayDraft[];
} => {
  const startDate = parseDateOnly(startDateValue);
  const endDate = parseDateOnly(endDateValue);
  if (!startDate || !endDate || endDate.getTime() < startDate.getTime()) {
    return { weeks: [], eventDays: [] };
  }

  const weeks: EventStudioWeekDraft[] = [];
  const eventDays: EventStudioEventDayDraft[] = [];
  let overallDayIndex = 1;

  if (scheduleMode === 'multi_week') {
    let currentWeekIndex = 1;
    let weekCursor = new Date(startDate);

    while (weekCursor.getTime() <= endDate.getTime()) {
      const weekStart = new Date(weekCursor);
      const weekEnd = new Date(weekStart);
      weekEnd.setDate(weekEnd.getDate() + 6);
      if (weekEnd.getTime() > endDate.getTime()) {
        weekEnd.setTime(endDate.getTime());
      }

      weeks.push({
        id: crypto.randomUUID(),
        weekIndex: currentWeekIndex,
        label: normalizeWeekLabel(currentWeekIndex, scheduleMode),
        startDate: formatDateOnly(weekStart),
        endDate: formatDateOnly(weekEnd),
        sortOrder: currentWeekIndex,
      });

      let dayIndexInWeek = 1;
      const dayCursor = new Date(weekStart);
      while (dayCursor.getTime() <= weekEnd.getTime()) {
        eventDays.push({
          id: crypto.randomUUID(),
          eventDayId: eventDayIdentifier(scheduleMode, currentWeekIndex, dayIndexInWeek, overallDayIndex),
          weekIndex: currentWeekIndex,
          dayIndexInWeek,
          overallDayIndex,
          label: `Week ${currentWeekIndex} Day ${dayIndexInWeek}`,
          weekday: weekdayKey(dayCursor),
          date: formatDateOnly(dayCursor),
          sortOrder: overallDayIndex,
        });
        overallDayIndex += 1;
        dayIndexInWeek += 1;
        dayCursor.setDate(dayCursor.getDate() + 1);
      }

      currentWeekIndex += 1;
      weekCursor = new Date(weekEnd);
      weekCursor.setDate(weekCursor.getDate() + 1);
    }

    return { weeks, eventDays };
  }

  weeks.push({
    id: crypto.randomUUID(),
    weekIndex: 1,
    label: '',
    startDate: formatDateOnly(startDate),
    endDate: formatDateOnly(endDate),
    sortOrder: 1,
  });

  const dayCursor = new Date(startDate);
  while (dayCursor.getTime() <= endDate.getTime()) {
    const dayIndexInWeek = overallDayIndex;
    eventDays.push({
      id: crypto.randomUUID(),
      eventDayId: eventDayIdentifier(scheduleMode, 1, dayIndexInWeek, overallDayIndex),
      weekIndex: 1,
      dayIndexInWeek,
      overallDayIndex,
      label: weekdayDisplayName(dayCursor),
      weekday: weekdayKey(dayCursor),
      date: formatDateOnly(dayCursor),
      sortOrder: overallDayIndex,
    });
    overallDayIndex += 1;
    dayCursor.setDate(dayCursor.getDate() + 1);
  }

  return { weeks, eventDays };
};

export const createEventStudioDraft = (): EventStudioDraft => ({
  id: crypto.randomUUID(),
  isCancelled: false,
  visibility: 'visible',
  derivedStatus: 'upcoming',
  name: emptyLocalizedText(),
  description: '',
  abbreviation: '',
  eventType: '电音节',
  organizerFestivalId: '',
  organizerName: '',
  sourceEventUrl: '',
  sourceProvider: '',
  referenceLinksText: '',
  socialLinksText: '',
  city: emptyLocalizedText(),
  clearCityI18nIntent: false,
  country: emptyLocalizedText(),
  clearCountryI18nIntent: false,
  detailAddress: emptyLocalizedText(),
  latitude: '',
  longitude: '',
  locationPoint: null,
  pickedPlaceName: '',
  pickedMapAddress: '',
  timeZoneQuery: '',
  timeZoneSelection: null,
  startDate: '',
  endDate: '',
  dayRolloverHour: '6',
  officialWebsite: '',
  ticketUrl: '',
  ticketCurrency: 'CNY',
  ticketNotes: '',
  imageZones: createEmptyImageZones(),
  ticketTiers: [],
  scheduleMode: 'single_day',
  weeks: [],
  eventDays: [],
  stageOrder: [],
  lineupSyncMode: 'incremental_fill',
  lineupArtists: [],
  timetableSlots: [],
});

export const createEmptyTicketTierDraft = createTicketTier;

const fromNullableLocalizedText = (
  value?: EventStudioLooseLocalizedText | null,
  fallback = ''
): EventStudioLocalizedText => ({
  zh: value?.zh ?? fallback,
  en: value?.en ?? '',
  ja: value?.ja ?? '',
  enFull: value?.enFull ?? '',
});

export const hydrateEventStudioDraftFromEvent = (event: EventStudioLoadedEvent): EventStudioDraft => {
  const eventWithStatusTruth = event as EventStudioLoadedEvent & {
    isCancelled?: boolean | null;
    visibility?: 'visible' | 'hidden' | null;
  };
  const manualDetail = event.manualLocation?.detailAddressI18n;
  const locationAddress = event.locationPoint?.addressI18n;
  const formattedLocationAddress = event.locationPoint?.formattedAddressI18n;
  const manualSetLocationAddress = event.locationPoint?.manualSetAddressI18n;
  const legacyTicketPriceSource = event as EventStudioLoadedEvent & {
    ticketPriceMin?: number | null;
    ticketPriceMax?: number | null;
  };
  const legacyTicketPriceBounds = [legacyTicketPriceSource.ticketPriceMin, legacyTicketPriceSource.ticketPriceMax]
    .map((value) => (typeof value === 'number' && Number.isFinite(value) ? value : null))
    .filter((value): value is number => value !== null);
  const socialLinksText = event.socialLinks == null
    ? ''
    : JSON.stringify(event.socialLinks, null, 2);
  const hydratedImageZones = createEmptyImageZones();
  (event.imageAssets ?? []).forEach((asset, index) => {
    const url = String(asset.url || '').trim();
    if (!url) return;
    const usage = classifyEventImageUsage(asset.type, asset.label);
    hydratedImageZones[usage].push(
      createImageState({
        usage,
        remoteUrl: url,
        fileName: asset.fileName || url.split('/').pop() || `${usage}-${index + 1}`,
        origin: 'persisted-event',
        sortOrder: asset.sort ?? asset.order ?? hydratedImageZones[usage].length + 1,
      })
    );
  });

  if (event.coverImageUrl && !hydratedImageZones.cover.some((item) => item.remoteUrl === event.coverImageUrl)) {
    hydratedImageZones.cover.unshift(
      createImageState({
        usage: 'cover',
        remoteUrl: event.coverImageUrl,
        fileName: event.coverImageUrl.split('/').pop() || 'cover',
        origin: 'persisted-event',
        sortOrder: 1,
      })
    );
  }

  if (event.lineupImageUrl && !hydratedImageZones.lineup.some((item) => item.remoteUrl === event.lineupImageUrl)) {
    hydratedImageZones.lineup.unshift(
      createImageState({
        usage: 'lineup',
        remoteUrl: event.lineupImageUrl,
        fileName: event.lineupImageUrl.split('/').pop() || 'lineup',
        origin: 'persisted-event',
        sortOrder: 1,
      })
    );
  }

  const eventTimeZone = normalizeDisplayTimeZone(event.schedule?.timeZone || event.timeZone);
  const startDate = normalizeEventStudioDateInput(event.startDate, eventTimeZone);
  const endDate = normalizeEventStudioDateInput(event.endDate, eventTimeZone);
  const normalizedDerivedStatus = String(event.status || '').trim().toLowerCase();
  const isCancelled = eventWithStatusTruth.isCancelled === true;
  const visibility: EventStudioDraft['visibility'] =
    String(eventWithStatusTruth.visibility || '').trim().toLowerCase() === 'hidden'
      ? 'hidden'
      : 'visible';
  const derivedStatus: EventStudioDraft['derivedStatus'] =
    normalizedDerivedStatus === 'ongoing'
      ? 'ongoing'
      : normalizedDerivedStatus === 'ended'
        ? 'ended'
        : normalizedDerivedStatus === 'cancelled'
          ? 'cancelled'
          : 'upcoming';
  const scheduleMode =
    (event.schedule?.mode as EventStudioDraft['scheduleMode'] | undefined) ??
    (event.weeks && event.weeks.length > 1
      ? 'multi_week'
      : startDate && endDate && startDate !== endDate
        ? 'multi_day'
        : 'single_day');
  const fallbackStructure = buildEventStudioScheduleStructure(
    scheduleMode,
    startDate,
    endDate
  );
  const hydratedEventDaysFromInput: EventStudioEventDayDraft[] = Array.isArray(event.eventDays) && event.eventDays.length
    ? event.eventDays.map((day) => ({
        id: day.id || crypto.randomUUID(),
        eventDayId: day.eventDayId,
        weekIndex: day.weekIndex,
        dayIndexInWeek: day.dayIndexInWeek,
        overallDayIndex: day.overallDayIndex,
        label: day.label ?? '',
        weekday: day.weekday ?? '',
        date: normalizeEventStudioDateInput(day.date, eventTimeZone),
        sortOrder: day.sortOrder ?? day.overallDayIndex,
      }))
    : fallbackStructure.eventDays;
  const timetableSlotSource = firstNonEmptyArray(event.timetableSlots, event.lineupSlots);
  const hydratedTimetableSlots: EventStudioTimetableSlotDraft[] = [];
  timetableSlotSource.forEach((slot, index) => {
    const slotWithOffsets = slot as { startDayOffset?: number | null; endDayOffset?: number | null };
    const localDate =
      datePartFromValueInTimeZone(slot.localDate, eventTimeZone) ||
      datePartFromValueInTimeZone(slot.startTime, eventTimeZone) ||
      '';
    const eventDayId = slot.eventDayId || '';
    const eventDay =
      hydratedEventDaysFromInput.find((day) => day.eventDayId === eventDayId) ||
      (slot.overallDayIndex != null
        ? hydratedEventDaysFromInput.find((day) => day.overallDayIndex === slot.overallDayIndex)
        : null) ||
      (localDate
        ? hydratedEventDaysFromInput.find((day) => day.date === localDate)
        : null);
    if (!eventDay) return;

    hydratedTimetableSlots.push({
      id: crypto.randomUUID(),
      canonicalSlotId: slot.id || null,
      lineupArtistId: slot.lineupArtistId || null,
      eventDayId: eventDay.eventDayId,
      weekIndex: eventDay.weekIndex,
      dayIndexInWeek: eventDay.dayIndexInWeek,
      overallDayIndex: eventDay.overallDayIndex,
      localDate: eventDay.date,
      djId: slot.djId || '',
      memberDjIds: Array.isArray(slot.memberDjIds) ? slot.memberDjIds : (slot.djId ? [slot.djId] : []),
      memberNamesText: defaultMemberNamesText(slot.memberNames, slot.djName),
      displayNameOverride: resolveDisplayNameOverride(
        (slot as { performerType?: string | null }).performerType,
        defaultMemberNamesText(slot.memberNames, slot.djName),
        slot.djName
      ),
      stageName: String(slot.stageName || '').trim(),
      sortOrder: slot.sortOrder ?? index + 1,
      startTime: timePartFromValueInTimeZone(slot.startTime, eventTimeZone),
      endTime: timePartFromValueInTimeZone(slot.endTime, eventTimeZone),
      startDayOffset: Number.isFinite(Number(slotWithOffsets.startDayOffset))
        ? normalizeSlotDayOffset(slotWithOffsets.startDayOffset)
        : dayOffsetFromValueInTimeZone(eventDay.date, slot.startTime, eventTimeZone),
      endDayOffset: Number.isFinite(Number(slotWithOffsets.endDayOffset))
        ? normalizeSlotDayOffset(slotWithOffsets.endDayOffset)
        : dayOffsetFromValueInTimeZone(eventDay.date, slot.endTime, eventTimeZone),
      actType: inferActType(
        (slot as { performerType?: string | null }).performerType,
        Math.max(
          defaultMemberNamesText(slot.memberNames, slot.djName).split(/[\/,&]/).map((item) => item.trim()).filter(Boolean).length,
          Array.isArray(slot.memberDjIds) ? slot.memberDjIds.filter(Boolean).length : 0,
          slot.djId ? 1 : 0
        )
      ),
    });
  });
  const hydratedStageOrder = normalizeStageOrder(event.stageOrder, hydratedTimetableSlots);
  const hydratedStageFallback = hydratedStageOrder[0] || defaultStageName();
  const normalizedHydratedTimetableSlots = hydratedTimetableSlots.map((slot) => ({
    ...slot,
    stageName: slot.stageName || hydratedStageFallback,
  }));
  const hydratedLineupArtistsFromInput = buildLineupArtistsFromInput(event.lineupArtists ?? null);
  const hydratedLineupArtists = hydratedLineupArtistsFromInput.length
    ? hydratedLineupArtistsFromInput
    : buildLineupArtistsFromTimetableSlots(normalizedHydratedTimetableSlots);

  return {
    id: crypto.randomUUID(),
    isCancelled,
    visibility,
    derivedStatus,
    name: fromNullableLocalizedText(event.nameI18n, event.name),
    description: event.description ?? '',
    abbreviation: event.abbreviation ?? '',
    eventType: event.eventType ?? '电音节',
    organizerFestivalId: event.wikiFestivalId ?? '',
    organizerName: event.organizerName ?? '',
    sourceEventUrl: event.sourceEventUrl ?? '',
    sourceProvider: event.sourceProvider ?? '',
    referenceLinksText: (event.referenceLinks ?? []).join('\n'),
    socialLinksText,
    city: fromNullableLocalizedText(event.cityI18n, event.city ?? ''),
    clearCityI18nIntent: false,
    country: fromNullableLocalizedText(event.countryI18n, event.country ?? ''),
    clearCountryI18nIntent: false,
    detailAddress: fromNullableLocalizedText(manualDetail || locationAddress, ''),
    latitude: event.latitude != null ? String(event.latitude) : '',
    longitude: event.longitude != null ? String(event.longitude) : '',
    locationPoint: event.locationPoint
      ? {
          ...event.locationPoint,
          adcode:
            typeof event.locationPoint === 'object' &&
            event.locationPoint &&
            'adcode' in event.locationPoint
              ? String((event.locationPoint as { adcode?: string | null }).adcode || '')
              : null,
          providerMeta:
            typeof event.locationPoint === 'object' &&
            event.locationPoint &&
            'providerMeta' in event.locationPoint
              ? ((event.locationPoint as { providerMeta?: NonNullable<EventStudioDraft['locationPoint']>['providerMeta'] }).providerMeta ?? null)
              : null,
        }
      : null,
    pickedPlaceName: event.locationPoint?.nameI18n?.zh ?? event.locationPoint?.nameI18n?.en ?? '',
    pickedMapAddress:
      manualSetLocationAddress?.zh ??
      manualSetLocationAddress?.en ??
      formattedLocationAddress?.zh ??
      formattedLocationAddress?.en ??
      event.locationPoint?.addressI18n?.zh ??
      event.locationPoint?.addressI18n?.en ??
      '',
    timeZoneQuery: event.city ?? event.cityI18n?.en ?? event.cityI18n?.zh ?? '',
    timeZoneSelection: event.timeZone
      ? {
          city: event.city ?? event.cityI18n?.en ?? event.cityI18n?.zh ?? '',
          cityAscii: event.city ?? event.cityI18n?.en ?? event.cityI18n?.zh ?? '',
          province: '',
          exactProvince: '',
          stateAnsi: '',
          country: event.country ?? event.countryI18n?.en ?? event.countryI18n?.zh ?? '',
          iso2: '',
          iso3: '',
          timezone: event.schedule?.timeZone ?? event.timeZone ?? '',
          lat: null,
          lng: null,
          population: null,
          label: `${event.city ?? event.cityI18n?.en ?? event.cityI18n?.zh ?? ''}${event.country ? `, ${event.country}` : ''} · ${event.schedule?.timeZone ?? event.timeZone ?? ''}`,
          matchSource: 'event-edit-hydrate',
        }
      : null,
    startDate,
    endDate,
    dayRolloverHour: String(event.schedule?.dayRolloverHour ?? event.dayRolloverHour ?? 6),
    officialWebsite: event.officialWebsite ?? '',
    ticketUrl: event.ticketUrl ?? '',
    ticketCurrency: event.ticketCurrency ?? 'CNY',
    ticketNotes: event.ticketNotes ?? '',
    imageZones: normalizeImageZones(hydratedImageZones),
    ticketTiers: (event.ticketTiers?.length
      ? [...event.ticketTiers]
        .sort((left, right) => (left.sortOrder ?? 0) - (right.sortOrder ?? 0))
        .map((tier) => ({
          id: tier.id || createTicketTier().id,
          name: tier.name,
          price: tier.price != null ? String(tier.price) : '',
          currency: tier.currency || event.ticketCurrency || 'CNY',
        }))
      : legacyTicketPriceBounds.map((price) => ({
          id: createTicketTier().id,
          name: '',
          price: String(price),
          currency: event.ticketCurrency || 'CNY',
        }))),
    scheduleMode,
    weeks: (event.weeks ?? []).length
      ? (event.weeks ?? []).map((week) => ({
          id: week.id || crypto.randomUUID(),
          weekIndex: week.weekIndex,
          label: week.label ?? normalizeWeekLabel(week.weekIndex, scheduleMode),
          startDate: normalizeEventStudioDateInput(week.startDate, eventTimeZone),
          endDate: normalizeEventStudioDateInput(week.endDate, eventTimeZone),
          sortOrder: week.sortOrder ?? week.weekIndex,
        }))
      : fallbackStructure.weeks,
    eventDays: hydratedEventDaysFromInput,
    stageOrder: hydratedStageOrder,
    lineupSyncMode: (event.lineupArtists?.length ? 'incremental_fill' : 'exact_align'),
    lineupArtists: hydratedLineupArtists,
    timetableSlots: normalizedHydratedTimetableSlots,
  };
};

export const syncEventStudioScheduleStructure = (
  draft: EventStudioDraft
): EventStudioDraft => {
  const scheduleMode =
    draft.scheduleMode ||
    defaultScheduleMode(draft.startDate, draft.endDate);
  const structure =
    scheduleMode === 'multi_week' && draft.weeks.length
      ? buildEventStudioScheduleStructureFromWeeks(draft.weeks)
      : buildEventStudioScheduleStructure(scheduleMode, draft.startDate, draft.endDate);
  const lineupState = syncEventStudioLineupState(draft, structure.eventDays);

  return {
    ...draft,
    scheduleMode,
    weeks: structure.weeks,
    eventDays: structure.eventDays,
    ...lineupState,
  };
};

export const rebaseEventStudioDatesPreservingWallDate = (
  draft: EventStudioDraft
): EventStudioDraft => {
  const next = {
    ...draft,
    startDate: normalizeEventStudioDateInput(draft.startDate),
    endDate: normalizeEventStudioDateInput(draft.endDate),
    weeks: draft.weeks.map((week) => ({
      ...week,
      startDate: normalizeEventStudioDateInput(week.startDate),
      endDate: normalizeEventStudioDateInput(week.endDate),
    })),
  };

  return syncEventStudioScheduleStructure(next);
};

export const buildEventStudioScheduleStructureFromWeeks = (
  weeksInput: EventStudioWeekDraft[]
): {
  weeks: EventStudioWeekDraft[];
  eventDays: EventStudioEventDayDraft[];
} => {
  const normalizedWeeks = [...weeksInput]
    .map((week, index) => ({
      ...week,
      weekIndex: index + 1,
      sortOrder: index + 1,
      label: week.label || `Week ${index + 1}`,
    }))
    .filter((week) => parseDateOnly(week.startDate) && parseDateOnly(week.endDate) && week.endDate >= week.startDate);

  const eventDays: EventStudioEventDayDraft[] = [];
  let overallDayIndex = 1;

  normalizedWeeks.forEach((week, index) => {
    const weekStart = parseDateOnly(week.startDate);
    const weekEnd = parseDateOnly(week.endDate);
    if (!weekStart || !weekEnd) return;

    let dayIndexInWeek = 1;
    const dayCursor = new Date(weekStart);
    while (dayCursor.getTime() <= weekEnd.getTime()) {
      eventDays.push({
        id: crypto.randomUUID(),
        eventDayId: eventDayIdentifier('multi_week', index + 1, dayIndexInWeek, overallDayIndex),
        weekIndex: index + 1,
        dayIndexInWeek,
        overallDayIndex,
        label: `Week ${index + 1} Day ${dayIndexInWeek}`,
        weekday: weekdayKey(dayCursor),
        date: formatDateOnly(dayCursor),
        sortOrder: overallDayIndex,
      });
      overallDayIndex += 1;
      dayIndexInWeek += 1;
      dayCursor.setDate(dayCursor.getDate() + 1);
    }
  });

  return {
    weeks: normalizedWeeks,
    eventDays,
  };
};
