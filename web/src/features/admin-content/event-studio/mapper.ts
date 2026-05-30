import {
  EventStudioCreateInput,
  EventStudioDraft,
  EventStudioLineupArtistDraft,
  EventStudioLocalizedText,
  EventStudioTimetableSlotDraft,
  EventStudioUpdateInput,
} from './types';

const trimOrNull = (value?: string | null): string | null => {
  const trimmed = String(value || '').trim();
  return trimmed || null;
};

const numericOrNull = (value?: string | null): number | null => {
  const trimmed = String(value || '').trim();
  if (!trimmed) return null;
  const numeric = Number(trimmed);
  return Number.isFinite(numeric) ? numeric : null;
};

const normalizedLocalizedText = (value: EventStudioLocalizedText): EventStudioLocalizedText | null => {
  const next: EventStudioLocalizedText = {
    zh: value.zh.trim(),
    en: value.en.trim(),
    ja: value.ja.trim(),
    enFull: value.enFull.trim(),
  };
  return next.zh || next.en || next.ja || next.enFull ? next : null;
};

const primaryText = (value: EventStudioLocalizedText): string =>
  value.zh.trim() || value.en.trim() || value.ja.trim() || value.enFull.trim();

const joinLocalizedAddress = (
  detail: EventStudioLocalizedText,
  city: EventStudioLocalizedText,
  country: EventStudioLocalizedText
): EventStudioLocalizedText => ({
  zh: [country.zh.trim(), city.zh.trim(), detail.zh.trim()].filter(Boolean).join(' '),
  en: [country.enFull.trim() || country.en.trim(), city.en.trim(), detail.en.trim()].filter(Boolean).join(', '),
  ja: [country.ja.trim(), city.ja.trim(), detail.ja.trim()].filter(Boolean).join(' '),
  enFull: [country.enFull.trim() || country.en.trim(), city.en.trim(), detail.enFull.trim() || detail.en.trim()].filter(Boolean).join(', '),
});

const resolveVisualStatus = (startDate: string, endDate: string): string => {
  const today = new Date().toISOString().slice(0, 10);
  if (endDate < today) return 'ended';
  if (startDate > today) return 'upcoming';
  return 'ongoing';
};

const splitMemberNamesText = (value: string): string[] =>
  value
    .split(/[\/,&]/)
    .map((item) => item.trim())
    .filter(Boolean);

const normalizeMemberDjIds = (memberDjIds: Array<string | null>): Array<string | null> => {
  const normalized = memberDjIds.map((item) => {
    const trimmed = String(item || '').trim();
    return trimmed || null;
  });
  return normalized.some((item) => item !== null) ? normalized : [];
};

const lineupArtistPayload = (artist: EventStudioLineupArtistDraft) => {
  const memberNames = splitMemberNamesText(artist.memberNamesText);
  const normalizedDjId = trimOrNull(artist.djId);
  if (!memberNames.length && !normalizedDjId) return null;

  const normalizedMemberDjIds = normalizeMemberDjIds(artist.memberDjIds);
  const displayName = memberNames.length ? memberNames.join(' / ') : normalizedDjId || '';
  if (!displayName) return null;

  return {
    id: trimOrNull(artist.canonicalArtistId),
    djId: normalizedDjId,
    memberDjIds: normalizedMemberDjIds.length ? normalizedMemberDjIds : (normalizedDjId ? [normalizedDjId] : null),
    memberNames: memberNames.length ? memberNames : null,
    djName: displayName,
    sortOrder: artist.sortOrder,
  };
};

const lineupSlotPayload = (slot: EventStudioTimetableSlotDraft) => {
  const memberNames = splitMemberNamesText(slot.memberNamesText);
  const normalizedDjId = trimOrNull(slot.djId);
  const normalizedStageName = trimOrNull(slot.stageName);
  if (!memberNames.length && !normalizedDjId) return null;
  if (!slot.eventDayId.trim() || !slot.localDate.trim() || !slot.startTime.trim() || !slot.endTime.trim()) return null;

  const normalizedMemberDjIds = normalizeMemberDjIds(slot.memberDjIds);
  const displayName = memberNames.length ? memberNames.join(' / ') : normalizedDjId || '';
  if (!displayName) return null;

  return {
    id: trimOrNull(slot.canonicalSlotId),
    lineupArtistId: trimOrNull(slot.lineupArtistId),
    eventDayId: slot.eventDayId,
    weekIndex: slot.weekIndex,
    dayIndexInWeek: slot.dayIndexInWeek,
    overallDayIndex: slot.overallDayIndex,
    localDate: slot.localDate,
    djId: normalizedDjId,
    memberDjIds: normalizedMemberDjIds.length ? normalizedMemberDjIds : (normalizedDjId ? [normalizedDjId] : null),
    memberNames: memberNames.length ? memberNames : null,
    festivalDayIndex: slot.overallDayIndex,
    djName: displayName,
    stageName: normalizedStageName,
    sortOrder: slot.sortOrder,
    startTime: `${slot.localDate}T${slot.startTime}:00`,
    endTime: `${slot.localDate}T${slot.endTime}:00`,
  };
};

export const mapEventStudioDraftToCreateInput = (draft: EventStudioDraft): EventStudioCreateInput => {
  const nameI18n = normalizedLocalizedText(draft.name);
  const cityI18n = normalizedLocalizedText(draft.city);
  const countryI18n = normalizedLocalizedText(draft.country);
  const detailAddressI18n = normalizedLocalizedText(draft.detailAddress);
  const coverUrl = trimOrNull(draft.coverImage?.remoteUrl);
  const lineupUrl = trimOrNull(draft.lineupImage?.remoteUrl);
  const latitude = numericOrNull(draft.latitude);
  const longitude = numericOrNull(draft.longitude);
  const locationName = trimOrNull(draft.pickedPlaceName);
  const locationAddress = trimOrNull(draft.pickedMapAddress);

  const imageAssets = [
    draft.coverImage
      ? {
          url: draft.coverImage.remoteUrl,
          type: 'poster',
          label: 'POSTER',
          sort: 0,
          order: 1,
          source: 'web-event-studio-v1',
          fileName: draft.coverImage.fileName,
        }
      : null,
    draft.lineupImage
      ? {
          url: draft.lineupImage.remoteUrl,
          type: 'luall',
          label: 'LINE-UP',
          sort: 1,
          order: 1,
          source: 'web-event-studio-v1',
          fileName: draft.lineupImage.fileName,
        }
      : null,
  ].filter((item): item is NonNullable<typeof item> => Boolean(item));

  const manualLocation = detailAddressI18n
    ? {
        detailAddressI18n,
        formattedAddressI18n: joinLocalizedAddress(detailAddressI18n, cityI18n || draft.city, countryI18n || draft.country),
        selectedAt: new Date().toISOString(),
      }
    : null;

  const locationPoint = latitude !== null && longitude !== null
    ? {
        provider: 'web-manual',
        sourceMode: 'web-event-studio-v1',
        location: { lng: longitude, lat: latitude },
        nameI18n: locationName
          ? {
              zh: locationName,
              en: '',
              ja: '',
              enFull: '',
            }
          : null,
        addressI18n: locationAddress
          ? {
              zh: locationAddress,
              en: '',
              ja: '',
              enFull: '',
            }
          : detailAddressI18n,
        formattedAddressI18n: detailAddressI18n
          ? joinLocalizedAddress(detailAddressI18n, cityI18n || draft.city, countryI18n || draft.country)
          : null,
        city: trimOrNull(primaryText(draft.city)),
      }
    : null;

  const ticketTiers = draft.ticketTiers
    .map((tier, index) => {
      const name = tier.name.trim();
      const price = Number(tier.price);
      if (!name || !Number.isFinite(price)) return null;
      return {
        name,
        price,
        currency: trimOrNull(tier.currency) || trimOrNull(draft.ticketCurrency),
        sortOrder: index,
      };
    })
    .filter((item): item is NonNullable<typeof item> => Boolean(item));

  const scheduleMode = draft.scheduleMode;
  const dayRolloverHour = numericOrNull(draft.dayRolloverHour) ?? 6;

  const schedule = draft.timeZoneSelection?.timezone
    ? {
        mode: scheduleMode,
        timeZone: draft.timeZoneSelection.timezone,
        dayRolloverHour,
      }
    : null;

  const weeks = draft.weeks.map((week) => ({
    weekIndex: week.weekIndex,
    label: trimOrNull(week.label),
    startDate: week.startDate,
    endDate: week.endDate,
    sortOrder: week.sortOrder,
  }));

  const eventDays = draft.eventDays.map((day) => ({
    eventDayId: day.eventDayId,
    weekIndex: day.weekIndex,
    dayIndexInWeek: day.dayIndexInWeek,
    overallDayIndex: day.overallDayIndex,
    label: trimOrNull(day.label),
    weekday: trimOrNull(day.weekday),
    date: day.date,
    sortOrder: day.sortOrder,
  }));
  const stageOrder = draft.stageOrder
    .map((stage) => stage.trim())
    .filter(Boolean);
  const lineupArtists = draft.lineupArtists
    .map(lineupArtistPayload)
    .filter((item): item is NonNullable<typeof item> => Boolean(item));
  const lineupSlots = draft.timetableSlots
    .map(lineupSlotPayload)
    .filter((item): item is NonNullable<typeof item> => Boolean(item));

  return {
    name: primaryText(draft.name),
    nameI18n,
    wikiFestivalId: trimOrNull(draft.organizerFestivalId),
    abbreviation: trimOrNull(draft.abbreviation),
    description: trimOrNull(draft.description),
    eventType: trimOrNull(draft.eventType),
    organizerName: trimOrNull(draft.organizerName),
    sourceEventUrl: trimOrNull(draft.sourceEventUrl),
    city: trimOrNull(primaryText(draft.city)),
    cityI18n,
    country: trimOrNull(primaryText(draft.country)),
    countryI18n,
    manualLocation,
    locationPoint,
    latitude,
    longitude,
    ticketUrl: trimOrNull(draft.ticketUrl),
    ticketCurrency: trimOrNull(draft.ticketCurrency)?.toUpperCase() || null,
    ticketNotes: trimOrNull(draft.ticketNotes),
    officialWebsite: trimOrNull(draft.officialWebsite),
    startDate: draft.startDate,
    endDate: draft.endDate,
    schedule,
    weeks: weeks.length ? weeks : null,
    eventDays: eventDays.length ? eventDays : null,
    timeZone: trimOrNull(draft.timeZoneSelection?.timezone),
    timeZoneCity: trimOrNull(draft.timeZoneSelection?.city),
    timeZoneProvince: trimOrNull(draft.timeZoneSelection?.exactProvince || draft.timeZoneSelection?.province),
    timeZoneCountry: trimOrNull(draft.timeZoneSelection?.country),
    timeZoneStateAnsi: trimOrNull(draft.timeZoneSelection?.stateAnsi),
    timeZoneLat: draft.timeZoneSelection?.lat ?? null,
    timeZoneLng: draft.timeZoneSelection?.lng ?? null,
    dayRolloverHour,
    coverImageUrl: coverUrl,
    lineupImageUrl: lineupUrl,
    imageAssets: imageAssets.length ? imageAssets : null,
    ticketTiers: ticketTiers.length ? ticketTiers : null,
    stageOrder: stageOrder.length ? stageOrder : null,
    lineupArtists: lineupArtists.length ? lineupArtists : null,
    lineupSlots: lineupSlots.length ? lineupSlots : null,
    lineupSyncMode: draft.lineupSyncMode,
    status: resolveVisualStatus(draft.startDate, draft.endDate),
  };
};

export const mapEventStudioDraftToUpdateInput = (draft: EventStudioDraft): EventStudioUpdateInput => {
  const createInput = mapEventStudioDraftToCreateInput(draft);
  const hasManualLocation = Boolean(createInput.manualLocation);
  const hasLocationPoint = Boolean(createInput.locationPoint);
  const hasLatitude = createInput.latitude !== null && createInput.latitude !== undefined;
  const hasLongitude = createInput.longitude !== null && createInput.longitude !== undefined;
  const hasWikiFestivalId = Boolean(createInput.wikiFestivalId);

  return {
    ...createInput,
    clearWikiFestivalId: !hasWikiFestivalId,
    clearManualLocation: !hasManualLocation,
    clearLocationPoint: !hasLocationPoint,
    clearLatitude: !hasLatitude,
    clearLongitude: !hasLongitude,
    clearStageOrder: !createInput.stageOrder?.length,
    clearLineupSlots: !createInput.lineupSlots?.length,
    coverImageUrl: draft.coverImage ? createInput.coverImageUrl : null,
    lineupImageUrl: draft.lineupImage ? createInput.lineupImageUrl : null,
  };
};
