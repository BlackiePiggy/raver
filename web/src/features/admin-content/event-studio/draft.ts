import {
  EventStudioDraft,
  EventStudioEventDayDraft,
  EventStudioImageState,
  EventStudioImageUsage,
  EventStudioLineupArtistDraft,
  EventStudioLoadedEvent,
  EventStudioLocalizedText,
  EventStudioTicketTierDraft,
  EventStudioTimetableSlotDraft,
  EventStudioWeekDraft,
} from './types';

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
    }));
  });
  return next;
};

const createImageState = (input: {
  usage: EventStudioImageUsage;
  remoteUrl: string;
  fileName: string;
  origin: 'draft-upload' | 'persisted';
  sortOrder?: number;
}): EventStudioImageState => ({
  id: crypto.randomUUID(),
  usage: input.usage,
  remoteUrl: input.remoteUrl,
  fileName: input.fileName,
  origin: input.origin,
  sortOrder: input.sortOrder || 1,
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

const defaultMemberNamesText = (members?: string[] | null, fallback?: string | null): string => {
  const normalizedMembers = Array.isArray(members)
    ? members.map((item) => String(item || '').trim()).filter(Boolean)
    : [];
  if (normalizedMembers.length > 0) {
    return normalizedMembers.join(' / ');
  }
  return String(fallback || '').trim();
};

const defaultStageName = (index: number): string => (index === 0 ? 'Main Stage' : `Stage ${index + 1}`);

const normalizeStageOrder = (stageOrder?: string[] | null, slots?: Array<{ stageName?: string | null }> | null): string[] => {
  const seen = new Set<string>();
  const result: string[] = [];
  const pushValue = (value?: string | null) => {
    const trimmed = String(value || '').trim();
    if (!trimmed) return;
    const key = trimmed.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    result.push(trimmed);
  };

  (stageOrder ?? []).forEach(pushValue);
  (slots ?? []).forEach((slot, index) => pushValue(slot.stageName || defaultStageName(index)));
  return result;
};

const buildLineupArtistsFromTimetableSlots = (
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
    const identityKey = normalizedDjId
      ? `dj:${normalizedDjId}`
      : memberNamesText
        ? `name:${memberNamesText.toLowerCase()}`
        : '';
    if (!identityKey) return;
    if (artistsByKey.has(identityKey)) return;

    artistsByKey.set(identityKey, {
      id: crypto.randomUUID(),
      canonicalArtistId: slot.lineupArtistId || null,
      djId: normalizedDjId,
      memberDjIds: normalizedMemberDjIds,
      memberNamesText,
      sortOrder: artistsByKey.size + 1 || index + 1,
    });
  });

  return Array.from(artistsByKey.values());
};

const datePartFromIsoLike = (value?: string | null): string => String(value || '').slice(0, 10);

const timePartFromIsoLike = (value?: string | null): string => {
  const text = String(value || '').trim();
  const match = text.match(/T(\d{2}:\d{2})/);
  if (match?.[1]) return match[1];
  if (/^\d{2}:\d{2}$/.test(text)) return text;
  return '';
};

const composeSlotDateTime = (date: string, time: string): string => {
  const normalizedDate = date.trim();
  const normalizedTime = time.trim();
  if (!normalizedDate || !normalizedTime) return '';
  return `${normalizedDate}T${normalizedTime}:00`;
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
    }];
  });
};

export const syncEventStudioLineupState = (
  draft: EventStudioDraft,
  eventDays: EventStudioEventDayDraft[]
): Pick<EventStudioDraft, 'stageOrder' | 'lineupArtists' | 'timetableSlots'> => {
  const timetableSlots = mapTimetableSlotsToCurrentSchedule(draft.timetableSlots, eventDays);
  const lineupArtists = buildLineupArtistsFromTimetableSlots(timetableSlots);
  const stageOrder = normalizeStageOrder(draft.stageOrder, timetableSlots);

  return {
    stageOrder,
    lineupArtists,
    timetableSlots,
  };
};

export const createEmptyEventStudioTimetableSlotDraft = (
  eventDay?: EventStudioEventDayDraft,
  stageName = 'Main Stage'
): EventStudioTimetableSlotDraft => ({
  id: crypto.randomUUID(),
  canonicalSlotId: null,
  lineupArtistId: null,
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
  name: emptyLocalizedText(),
  description: '',
  abbreviation: '',
  eventType: '电音节',
  organizerFestivalId: '',
  organizerName: '',
  sourceEventUrl: '',
  city: emptyLocalizedText(),
  country: emptyLocalizedText(),
  detailAddress: emptyLocalizedText(),
  venueName: '',
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
  const manualDetail = event.manualLocation?.detailAddressI18n;
  const locationAddress = event.locationPoint?.addressI18n;
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
        origin: 'persisted',
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
        origin: 'persisted',
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
        origin: 'persisted',
        sortOrder: 1,
      })
    );
  }

  const startDate = event.startDate?.slice(0, 10) ?? '';
  const endDate = event.endDate?.slice(0, 10) ?? '';
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
  const hydratedTimetableSlots: EventStudioTimetableSlotDraft[] = [];
  (event.timetableSlots ?? event.lineupSlots ?? []).forEach((slot, index) => {
      const localDate = datePartFromIsoLike(slot.localDate) || '';
      const eventDayId = slot.eventDayId || '';
      const eventDay =
        fallbackStructure.eventDays.find((day) => day.eventDayId === eventDayId) ||
        (slot.overallDayIndex != null
          ? fallbackStructure.eventDays.find((day) => day.overallDayIndex === slot.overallDayIndex)
          : null) ||
        (localDate
          ? fallbackStructure.eventDays.find((day) => day.date === localDate)
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
        stageName: String(slot.stageName || '').trim() || defaultStageName(index),
        sortOrder: slot.sortOrder ?? index + 1,
        startTime: timePartFromIsoLike(slot.startTime),
        endTime: timePartFromIsoLike(slot.endTime),
      });
    });
  const hydratedLineupArtists = buildLineupArtistsFromTimetableSlots(hydratedTimetableSlots);
  const hydratedStageOrder = normalizeStageOrder(event.stageOrder, hydratedTimetableSlots);

  return {
    id: crypto.randomUUID(),
    name: fromNullableLocalizedText(event.nameI18n, event.name),
    description: event.description ?? '',
    abbreviation: event.abbreviation ?? '',
    eventType: event.eventType ?? '电音节',
    organizerFestivalId: event.wikiFestivalId ?? '',
    organizerName: event.organizerName ?? '',
    sourceEventUrl: event.sourceEventUrl ?? '',
    city: fromNullableLocalizedText(event.cityI18n, event.city ?? ''),
    country: fromNullableLocalizedText(event.countryI18n, event.country ?? ''),
    detailAddress: fromNullableLocalizedText(manualDetail || locationAddress, ''),
    venueName: '',
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
    pickedMapAddress: event.locationPoint?.addressI18n?.zh ?? event.locationPoint?.addressI18n?.en ?? '',
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
    ticketTiers: (event.ticketTiers ?? []).map((tier) => ({
      id: tier.id || createTicketTier().id,
      name: tier.name,
      price: tier.price != null ? String(tier.price) : '',
      currency: tier.currency || event.ticketCurrency || 'CNY',
    })),
    scheduleMode,
    weeks: (event.weeks ?? []).length
      ? (event.weeks ?? []).map((week) => ({
          id: week.id || crypto.randomUUID(),
          weekIndex: week.weekIndex,
          label: week.label ?? normalizeWeekLabel(week.weekIndex, scheduleMode),
          startDate: week.startDate.slice(0, 10),
          endDate: week.endDate.slice(0, 10),
          sortOrder: week.sortOrder ?? week.weekIndex,
        }))
      : fallbackStructure.weeks,
    eventDays: (event.eventDays ?? []).length
      ? (event.eventDays ?? []).map((day) => ({
          id: day.id || crypto.randomUUID(),
          eventDayId: day.eventDayId,
          weekIndex: day.weekIndex,
          dayIndexInWeek: day.dayIndexInWeek,
          overallDayIndex: day.overallDayIndex,
          label: day.label ?? '',
          weekday: day.weekday ?? '',
          date: day.date.slice(0, 10),
          sortOrder: day.sortOrder ?? day.overallDayIndex,
        }))
      : fallbackStructure.eventDays,
    stageOrder: hydratedStageOrder,
    lineupSyncMode: 'incremental_fill',
    lineupArtists: hydratedLineupArtists,
    timetableSlots: hydratedTimetableSlots,
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
