import {
  EventStudioCreateInput,
  EventStudioDraft,
  EventStudioImageState,
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

const nextDateText = (value: string): string => {
  const trimmed = value.trim();
  if (!trimmed) return trimmed;
  const parsed = new Date(`${trimmed}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime())) return trimmed;
  parsed.setUTCDate(parsed.getUTCDate() + 1);
  return parsed.toISOString().slice(0, 10);
};

const composeSlotDateTime = (date: string, time: string): string => {
  const normalizedDate = date.trim();
  const normalizedTime = time.trim();
  if (!normalizedDate || !normalizedTime) return '';
  return `${normalizedDate}T${normalizedTime}:00`;
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

const normalizedAddressText = (value: EventStudioLocalizedText): EventStudioLocalizedText => ({
  zh: value.zh.trim(),
  en: value.en.trim(),
  ja: value.ja.trim(),
  enFull: value.enFull.trim(),
});

const joinAddressParts = (parts: Array<string | null | undefined>): string =>
  parts
    .map((item) => String(item || '').trim())
    .filter(Boolean)
    .join(' · ');

const joinLocalizedAddress = (
  detail: EventStudioLocalizedText,
  city: EventStudioLocalizedText,
  country: EventStudioLocalizedText
): EventStudioLocalizedText => {
  const normalizedDetail = normalizedAddressText(detail);
  const normalizedCity = normalizedAddressText(city);
  const normalizedCountry = normalizedAddressText(country);

  return {
    zh: joinAddressParts([
      normalizedCountry.zh || normalizedCountry.en,
      normalizedCity.zh || normalizedCity.en,
      normalizedDetail.zh || normalizedDetail.en,
    ]) || normalizedDetail.zh || normalizedDetail.en,
    en: joinAddressParts([
      normalizedCountry.enFull || normalizedCountry.en || normalizedCountry.zh,
      normalizedCity.en || normalizedCity.zh,
      normalizedDetail.en || normalizedDetail.zh,
    ]) || normalizedDetail.en || normalizedDetail.zh,
    ja: joinAddressParts([
      normalizedCountry.ja || normalizedCountry.enFull || normalizedCountry.en || normalizedCountry.zh,
      normalizedCity.ja || normalizedCity.en || normalizedCity.zh,
      normalizedDetail.ja || normalizedDetail.en || normalizedDetail.zh,
    ]) || normalizedDetail.ja || normalizedDetail.en || normalizedDetail.zh,
    enFull: normalizedDetail.enFull,
  };
};

const resolveVisualStatus = (
  startDate: string,
  endDate: string
): 'upcoming' | 'ongoing' | 'ended' => {
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

const firstImageInZone = (draft: EventStudioDraft, usage: EventStudioImageState['usage']): EventStudioImageState | null =>
  [...(draft.imageZones[usage] || [])]
    .sort((left, right) => left.sortOrder - right.sortOrder)
    .find((item) => item.remoteUrl.trim()) || null;

const cloneLocalizedTextOrUndefined = (value?: {
  zh?: string | null;
  en?: string | null;
  ja?: string | null;
  enFull?: string | null;
} | null) => {
  if (!value) return undefined;
  const normalized = normalizedLocalizedText({
    zh: value.zh ?? '',
    en: value.en ?? '',
    ja: value.ja ?? '',
    enFull: value.enFull ?? '',
  });
  return normalized ?? undefined;
};

const defaultStageName = (index: number): string => (index === 0 ? 'Main Stage' : `Stage ${index + 1}`);

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

const lineupSlotPayload = (slot: EventStudioTimetableSlotDraft, index: number) => {
  const memberNames = splitMemberNamesText(slot.memberNamesText);
  const normalizedDjId = trimOrNull(slot.djId);
  const normalizedStageName = trimOrNull(slot.stageName) || defaultStageName(index);
  if (!memberNames.length && !normalizedDjId) return null;
  if (!slot.eventDayId.trim() || !slot.localDate.trim() || !slot.startTime.trim() || !slot.endTime.trim()) return null;

  const normalizedMemberDjIds = normalizeMemberDjIds(slot.memberDjIds);
  const displayName = memberNames.length ? memberNames.join(' / ') : normalizedDjId || '';
  if (!displayName) return null;
  const normalizedStartTime = composeSlotDateTime(slot.localDate, slot.startTime);
  const normalizedEndDate = slot.endTime.trim() > slot.startTime.trim()
    ? slot.localDate
    : nextDateText(slot.localDate);

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
    festivalDayIndex: null,
    djName: displayName,
    stageName: normalizedStageName,
    sortOrder: slot.sortOrder,
    startTime: normalizedStartTime,
    endTime: composeSlotDateTime(normalizedEndDate, slot.endTime),
  };
};

export const mapEventStudioDraftToCreateInput = (draft: EventStudioDraft): EventStudioCreateInput => {
  const nameI18n = normalizedLocalizedText(draft.name);
  const cityI18n = normalizedLocalizedText(draft.city);
  const countryI18n = normalizedLocalizedText(draft.country);
  const detailAddressI18n = normalizedLocalizedText(draft.detailAddress);
  const posterImage = firstImageInZone(draft, 'poster');
  const coverImage = firstImageInZone(draft, 'cover');
  const lineupImage = firstImageInZone(draft, 'lineup');
  const coverUrl = trimOrNull(posterImage?.remoteUrl || coverImage?.remoteUrl);
  const lineupUrl = trimOrNull(lineupImage?.remoteUrl);
  const latitude = numericOrNull(draft.latitude);
  const longitude = numericOrNull(draft.longitude);
  const locationName = trimOrNull(draft.pickedPlaceName);
  const locationAddress = trimOrNull(draft.pickedMapAddress);

  const imageAssets = Object.entries(draft.imageZones).flatMap(([usage, items]) =>
    [...items]
      .sort((left, right) => left.sortOrder - right.sortOrder)
      .map((image, index) => {
        const normalizedUsage = usage as EventStudioImageState['usage'];
        const type =
          normalizedUsage === 'lineup'
            ? 'luall'
            : normalizedUsage === 'timetable'
              ? 'tt'
              : normalizedUsage === 'cover'
                ? 'cover'
                : normalizedUsage === 'poster'
                  ? 'poster'
                  : 'other';
        const label =
          normalizedUsage === 'lineup'
            ? 'LINE-UP'
            : normalizedUsage === 'timetable'
              ? 'TIMETABLE'
              : normalizedUsage === 'cover'
                ? 'COVER'
                : normalizedUsage === 'poster'
                  ? 'POSTER'
                  : normalizedUsage.toUpperCase();
        return {
          url: image.remoteUrl,
          type,
          label,
          sort: image.sortOrder || index + 1,
          order: index + 1,
          source: 'web-event-studio-v2',
          fileName: image.fileName,
        };
      })
      .filter((item) => item.url.trim())
  );

  const manualLocation = detailAddressI18n
    ? {
        detailAddressI18n,
        formattedAddressI18n: joinLocalizedAddress(detailAddressI18n, cityI18n || draft.city, countryI18n || draft.country),
        selectedAt: new Date().toISOString(),
      }
    : null;

  const locationPoint = latitude !== null && longitude !== null
    ? {
        provider: trimOrNull(draft.locationPoint?.provider) || 'mapkit',
        sourceMode: trimOrNull(draft.locationPoint?.sourceMode) || 'web-event-studio-v2',
        providerPlaceId: trimOrNull(draft.locationPoint?.providerPlaceId),
        poiId: trimOrNull(draft.locationPoint?.poiId),
        adcode: trimOrNull(draft.locationPoint?.adcode),
        providerMeta: draft.locationPoint?.providerMeta ?? null,
        location: { lng: longitude, lat: latitude },
        nameI18n:
          cloneLocalizedTextOrUndefined(draft.locationPoint?.nameI18n) ||
          (locationName
            ? {
                zh: locationName,
                en: '',
                ja: '',
                enFull: '',
              }
            : undefined),
        addressI18n:
          cloneLocalizedTextOrUndefined(draft.locationPoint?.addressI18n) ||
          (locationAddress
            ? {
                zh: locationAddress,
                en: '',
                ja: '',
                enFull: '',
              }
            : detailAddressI18n ?? undefined),
        formattedAddressI18n:
          cloneLocalizedTextOrUndefined(draft.locationPoint?.formattedAddressI18n) ||
          (detailAddressI18n
            ? joinLocalizedAddress(detailAddressI18n, cityI18n || draft.city, countryI18n || draft.country)
            : undefined),
        city: trimOrNull(draft.locationPoint?.city) || trimOrNull(primaryText(draft.city)),
        district: trimOrNull(draft.locationPoint?.district),
        province: trimOrNull(draft.locationPoint?.province),
        countryCode: trimOrNull(draft.locationPoint?.countryCode),
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
        currency: (trimOrNull(tier.currency) || trimOrNull(draft.ticketCurrency))?.toUpperCase() || null,
        sortOrder: index + 1,
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
    nameI18n: nameI18n ?? undefined,
    wikiFestivalId: trimOrNull(draft.organizerFestivalId),
    abbreviation: trimOrNull(draft.abbreviation),
    description: trimOrNull(draft.description),
    eventType: trimOrNull(draft.eventType),
    organizerName: trimOrNull(draft.organizerName),
    sourceEventUrl: trimOrNull(draft.sourceEventUrl),
    city: trimOrNull(primaryText(draft.city)),
    cityI18n: cityI18n ?? undefined,
    country: trimOrNull(primaryText(draft.country)),
    countryI18n: countryI18n ?? undefined,
    manualLocation: manualLocation ?? undefined,
    locationPoint: locationPoint ?? undefined,
    latitude,
    longitude,
    ticketUrl: trimOrNull(draft.ticketUrl),
    ticketCurrency: trimOrNull(draft.ticketCurrency)?.toUpperCase() || null,
    ticketNotes: trimOrNull(draft.ticketNotes),
    officialWebsite: trimOrNull(draft.officialWebsite),
    startDate: draft.startDate,
    endDate: draft.endDate,
    schedule: schedule ?? undefined,
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
  const hasCityI18n = Boolean(createInput.cityI18n);
  const hasCountryI18n = Boolean(createInput.countryI18n);
  const hasManualLocation = Boolean(createInput.manualLocation);
  const hasLocationPoint = Boolean(createInput.locationPoint);
  const hasLatitude = createInput.latitude !== null && createInput.latitude !== undefined;
  const hasLongitude = createInput.longitude !== null && createInput.longitude !== undefined;
  const hasWikiFestivalId = Boolean(createInput.wikiFestivalId);

  return {
    ...createInput,
    clearCityI18n: !hasCityI18n,
    clearCountryI18n: !hasCountryI18n,
    clearWikiFestivalId: !hasWikiFestivalId,
    clearManualLocation: !hasManualLocation,
    clearLocationPoint: !hasLocationPoint,
    clearLatitude: !hasLatitude,
    clearLongitude: !hasLongitude,
    clearStageOrder: !createInput.stageOrder?.length,
    clearLineupSlots: !createInput.lineupSlots?.length,
    coverImageUrl: firstImageInZone(draft, 'poster') || firstImageInZone(draft, 'cover') ? createInput.coverImageUrl : null,
    lineupImageUrl: firstImageInZone(draft, 'lineup') ? createInput.lineupImageUrl : null,
  };
};
