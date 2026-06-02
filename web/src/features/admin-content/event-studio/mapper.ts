import {
  EventStudioCreateInput,
  EventStudioDraft,
  EventStudioImageState,
  EventStudioLineupArtistDraft,
  EventStudioLocalizedText,
  EventStudioTimetableSlotDraft,
  EventStudioUpdateInput,
} from './types';
import type { components as EventContractComponents } from '../../../../../contracts/generated/web/event-admin';
import {
  eventStudioLineupArtistIdentityKey,
  eventStudioTimetableSlotIdentityKey,
} from './draft';
import { formatDateInputInTimeZone } from '@/lib/timezone';

type EventLocationProvider = EventContractComponents['schemas']['EventLocationProvider'];
type EventLocationSourceMode = EventContractComponents['schemas']['EventLocationSourceMode'];
type EventLocationProviderMeta = EventContractComponents['schemas']['EventLocationProviderMeta'];
type EventStudioLocationProviderMetaInput = NonNullable<NonNullable<EventStudioDraft['locationPoint']>['providerMeta']>;

const trimOrNull = (value?: string | null): string | null => {
  const trimmed = String(value || '').trim();
  return trimmed || null;
};

const splitLines = (value: string): string[] =>
  Array.from(
    new Set(
      value
        .split(/[\n,]/)
        .map((item) => item.trim())
        .filter(Boolean)
    )
  );

const parseJsonTextOrNull = (value: string): unknown | null => {
  const trimmed = value.trim();
  if (!trimmed) return null;
  try {
    return JSON.parse(trimmed);
  } catch {
    return null;
  }
};

const numericOrNull = (value?: string | null): number | null => {
  const trimmed = String(value || '').trim();
  if (!trimmed) return null;
  const numeric = Number(trimmed);
  return Number.isFinite(numeric) ? numeric : null;
};

const normalizeLocationProvider = (value?: string | null): EventLocationProvider | null => {
  const normalized = String(value || '').trim().toLowerCase();
  if (!normalized) return null;
  if (normalized === 'apple-mapkit' || normalized === 'apple_mapkit') return 'mapkit';
  if (normalized === 'amap' || normalized === 'google' || normalized === 'mapkit' || normalized === 'mapbox' || normalized === 'geoapify') {
    return normalized;
  }
  return null;
};

const normalizeLocationSourceMode = (value?: string | null): EventLocationSourceMode | null => {
  const normalized = String(value || '').trim().toLowerCase();
  if (!normalized) return null;
  if (normalized === 'composed_search' || normalized === 'picker_search') return 'manual_search';
  if (
    normalized === 'manual_pick'
    || normalized === 'manual_pin'
    || normalized === 'ios-event-upload-v2'
    || normalized === 'web-event-studio-v2'
  ) {
    return 'pin_drag';
  }
  if (
    normalized === 'manual_search'
    || normalized === 'pin_drag'
    || normalized === 'map_poi_click'
    || normalized === 'my_location'
    || normalized === 'legacy_coords'
  ) {
    return normalized;
  }
  return null;
};

const normalizeLocationProviderMeta = (
  value: EventStudioLocationProviderMetaInput | null
): EventLocationProviderMeta | null => {
  if (!value) return null;
  const next: EventLocationProviderMeta = {};

  const amapPoiId = trimOrNull(value.amap?.poiId);
  const amapAdcode = trimOrNull(value.amap?.adcode);
  if (amapPoiId || amapAdcode) {
    next.amap = {
      poiId: amapPoiId,
      adcode: amapAdcode,
    };
  }

  const googlePlaceId = trimOrNull(value.google?.placeId);
  const googleTypes = value.google?.types?.map((item: string | null | undefined) => String(item || '').trim()).filter(Boolean) || null;
  if (googlePlaceId || (googleTypes && googleTypes.length)) {
    next.google = {
      placeId: googlePlaceId,
      types: googleTypes && googleTypes.length ? googleTypes : null,
    };
  }

  const mapkitIdentifier = trimOrNull(value.mapkit?.mapItemIdentifier);
  if (mapkitIdentifier) {
    next.mapkit = {
      mapItemIdentifier: mapkitIdentifier,
    };
  }

  const mapboxPlaceId = trimOrNull(value.mapbox?.placeId);
  const mapboxFeatureType = trimOrNull(value.mapbox?.featureType);
  if (mapboxPlaceId || mapboxFeatureType) {
    next.mapbox = {
      placeId: mapboxPlaceId,
      featureType: mapboxFeatureType,
    };
  }

  const geoapifyPlaceId = trimOrNull(value.geoapify?.placeId);
  const geoapifyFeatureType = trimOrNull(value.geoapify?.featureType);
  if (geoapifyPlaceId || geoapifyFeatureType) {
    next.geoapify = {
      placeId: geoapifyPlaceId,
      featureType: geoapifyFeatureType,
    };
  }

  return Object.keys(next).length ? next : null;
};

const inferLocationProviderFromMeta = (
  meta: EventLocationProviderMeta | null,
  adcode: string | null,
  poiId: string | null
): EventLocationProvider | null => {
  if (meta?.amap || adcode || poiId) return 'amap';
  if (meta?.google) return 'google';
  if (meta?.mapkit) return 'mapkit';
  if (meta?.mapbox) return 'mapbox';
  if (meta?.geoapify) return 'geoapify';
  return null;
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

const dateWithDayOffset = (date: string, offset?: number): string => {
  const normalizedDate = date.trim();
  const normalizedOffset = Math.max(0, Math.floor(Number(offset) || 0));
  if (!normalizedDate || normalizedOffset <= 0) return normalizedDate;
  let result = normalizedDate;
  for (let index = 0; index < normalizedOffset; index += 1) {
    result = nextDateText(result);
  }
  return result;
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

const canonicalLocationText = (
  value: EventStudioLocalizedText,
  options?: { preferEnglishFull?: boolean }
): string => {
  const en = value.en.trim();
  const zh = value.zh.trim();
  const ja = value.ja.trim();
  const enFull = value.enFull.trim();
  if (options?.preferEnglishFull) {
    return en || enFull || zh || ja;
  }
  return en || zh || ja || enFull;
};

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
  endDate: string,
  timeZone?: string | null
): 'upcoming' | 'ongoing' | 'ended' => {
  const today = formatDateInputInTimeZone(new Date(), timeZone);
  if (endDate < today) return 'ended';
  if (startDate > today) return 'upcoming';
  return 'ongoing';
};

const splitMemberNamesText = (value: string): string[] =>
  value
    .split(/[\/,&]/)
    .map((item) => item.trim())
    .filter(Boolean);

const normalizeActType = (value?: string | null): 'solo' | 'b2b' | 'b3b' => {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'b2b' || normalized === 'b3b') return normalized;
  return 'solo';
};

const actTypePerformerCount = (value?: string | null): number => {
  const normalized = normalizeActType(value);
  if (normalized === 'b3b') return 3;
  if (normalized === 'b2b') return 2;
  return 1;
};

const composeActDisplayName = (actType: string | undefined, memberNames: string[], fallback: string): string => {
  const normalizedActType = normalizeActType(actType);
  const count = actTypePerformerCount(normalizedActType);
  const names = memberNames.slice(0, count).filter(Boolean);
  if (!names.length) return fallback;
  if (normalizedActType === 'b3b') return names.join(' B3B ');
  if (normalizedActType === 'b2b') return names.join(' B2B ');
  return names[0] || fallback;
};

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

const hasLocationProviderMeta = (value: unknown): boolean => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  return Object.values(value as Record<string, unknown>).some((providerMeta) => {
    if (!providerMeta || typeof providerMeta !== 'object' || Array.isArray(providerMeta)) return false;
    return Object.values(providerMeta as Record<string, unknown>).some((fieldValue) => {
      if (Array.isArray(fieldValue)) return fieldValue.some((item) => String(item || '').trim());
      return String(fieldValue || '').trim().length > 0;
    });
  });
};

const hasLocationPointProvenance = (input: {
  providerPlaceId: string | null;
  poiId: string | null;
  adcode: string | null;
  providerMeta: EventLocationProviderMeta | null;
}): boolean =>
  Boolean(
    input.providerPlaceId
    || input.poiId
    || input.adcode
    || hasLocationProviderMeta(input.providerMeta)
  );

const fallbackStageName = (stageOrder: string[]): string => stageOrder[0] || 'Main Stage';
const defaultTicketTierName = (index: number): string => `Tier ${index + 1}`;

const hasStageSlotContent = (slot: EventStudioTimetableSlotDraft): boolean =>
  [
    slot.memberNamesText,
    slot.djId,
    slot.stageName,
    slot.startTime,
    slot.endTime,
  ].some((value) => String(value || '').trim().length > 0);

const normalizeStageOrderForPayload = (
  explicitStageOrder: string[],
  timetableSlots: EventStudioTimetableSlotDraft[]
): string[] => {
  const seen = new Set<string>();
  const result: string[] = [];
  let hasBlankStageSlot = false;
  const pushStage = (value?: string | null) => {
    const trimmed = String(value || '').trim();
    if (!trimmed) return;
    const key = trimmed.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    result.push(trimmed);
  };

  explicitStageOrder.forEach(pushStage);
  timetableSlots.forEach((slot) => {
    const normalizedStageName = trimOrNull(slot.stageName);
    if (normalizedStageName) {
      pushStage(normalizedStageName);
      return;
    }
    if (hasStageSlotContent(slot)) {
      hasBlankStageSlot = true;
    }
  });

  if (!result.length && hasBlankStageSlot) {
    result.push('Main Stage');
  }

  return result;
};

const lineupArtistPayload = (artist: EventStudioLineupArtistDraft) => {
  const performerCount = actTypePerformerCount(artist.actType);
  const memberNames = splitMemberNamesText(artist.memberNamesText).slice(0, performerCount);
  const normalizedDjId = trimOrNull(artist.djId);
  if (!memberNames.length && !normalizedDjId) return null;

  const normalizedMemberDjIds = normalizeMemberDjIds(artist.memberDjIds).slice(0, performerCount);
  const displayName = composeActDisplayName(artist.actType, memberNames, normalizedDjId || '');
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

const lineupSlotPayload = (
  slot: EventStudioTimetableSlotDraft,
  index: number,
  lineupArtistIdByKey: Map<string, string>,
  stageOrder: string[]
) => {
  const performerCount = actTypePerformerCount(slot.actType);
  const memberNames = splitMemberNamesText(slot.memberNamesText).slice(0, performerCount);
  const normalizedDjId = trimOrNull(slot.djId);
  const normalizedStageName = trimOrNull(slot.stageName) || fallbackStageName(stageOrder);
  if (!memberNames.length && !normalizedDjId) return null;
  if (!slot.eventDayId.trim() || !slot.localDate.trim() || !slot.startTime.trim() || !slot.endTime.trim()) return null;

  if (memberNames.length < performerCount) return null;

  const normalizedMemberDjIds = normalizeMemberDjIds(slot.memberDjIds).slice(0, performerCount);
  const displayName = composeActDisplayName(slot.actType, memberNames, normalizedDjId || '');
  if (!displayName) return null;
  const startDayOffset = Math.max(0, Math.floor(Number(slot.startDayOffset) || 0));
  const inferredEndOffset = slot.endTime.trim() > slot.startTime.trim() ? startDayOffset : startDayOffset + 1;
  const endDayOffset = Math.max(startDayOffset, Math.floor(Number(slot.endDayOffset) || inferredEndOffset));
  const normalizedStartTime = composeSlotDateTime(dateWithDayOffset(slot.localDate, startDayOffset), slot.startTime);
  const normalizedEndDate = dateWithDayOffset(slot.localDate, endDayOffset);
  const identityKey = eventStudioTimetableSlotIdentityKey(slot);

  return {
    id: trimOrNull(slot.canonicalSlotId),
    lineupArtistId: trimOrNull(slot.lineupArtistId) || (identityKey ? lineupArtistIdByKey.get(identityKey) : null) || null,
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
  const cityI18n = draft.clearCityI18nIntent ? null : normalizedLocalizedText(draft.city);
  const countryI18n = draft.clearCountryI18nIntent ? null : normalizedLocalizedText(draft.country);
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
  const locationProviderMeta = normalizeLocationProviderMeta(draft.locationPoint?.providerMeta ?? null);
  const locationProvider =
    normalizeLocationProvider(draft.locationPoint?.provider)
    || inferLocationProviderFromMeta(locationProviderMeta, trimOrNull(draft.locationPoint?.adcode), trimOrNull(draft.locationPoint?.poiId));
  const locationSourceMode =
    normalizeLocationSourceMode(draft.locationPoint?.sourceMode)
    || (locationProviderMeta || trimOrNull(draft.locationPoint?.providerPlaceId) || trimOrNull(draft.locationPoint?.poiId)
      ? 'manual_search'
      : locationProvider
        ? 'legacy_coords'
        : null);
  const locationProviderPlaceId = trimOrNull(draft.locationPoint?.providerPlaceId);
  const locationPoiId = trimOrNull(draft.locationPoint?.poiId);
  const locationAdcode = trimOrNull(draft.locationPoint?.adcode);
  const hasRealLocationPointProvenance = hasLocationPointProvenance({
    providerPlaceId: locationProviderPlaceId,
    poiId: locationPoiId,
    adcode: locationAdcode,
    providerMeta: locationProviderMeta,
  });

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

  const locationPoint: EventStudioCreateInput['locationPoint'] | null = latitude !== null
    && longitude !== null
    && hasRealLocationPointProvenance
    && locationProvider
    && locationSourceMode
    ? {
        provider: locationProvider,
        sourceMode: locationSourceMode,
        providerPlaceId: locationProviderPlaceId,
        poiId: locationPoiId,
        adcode: locationAdcode,
        providerMeta: locationProviderMeta,
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
      const name = tier.name.trim() || defaultTicketTierName(index);
      const price = Number(tier.price);
      if (!Number.isFinite(price)) return null;
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
  const explicitStageOrder = draft.stageOrder
    .map((stage) => stage.trim())
    .filter(Boolean);
  const stageOrder = normalizeStageOrderForPayload(explicitStageOrder, draft.timetableSlots);
  const lineupArtistIdByKey = new Map<string, string>();
  draft.lineupArtists.forEach((artist) => {
    const key = eventStudioLineupArtistIdentityKey(artist);
    const artistId = trimOrNull(artist.canonicalArtistId);
    if (key && artistId && !lineupArtistIdByKey.has(key)) {
      lineupArtistIdByKey.set(key, artistId);
    }
  });
  const lineupArtists = draft.lineupArtists
    .map(lineupArtistPayload)
    .filter((item): item is NonNullable<typeof item> => Boolean(item));
  const lineupSlots = draft.timetableSlots
    .map((slot, index) => lineupSlotPayload(slot, index, lineupArtistIdByKey, stageOrder))
    .filter((item): item is NonNullable<typeof item> => Boolean(item));

  return {
    name: primaryText(draft.name),
    nameI18n: nameI18n ?? undefined,
    wikiFestivalId: trimOrNull(draft.organizerFestivalId),
    abbreviation: trimOrNull(draft.abbreviation),
    description: trimOrNull(draft.description),
    eventType: trimOrNull(draft.eventType),
    organizerName: trimOrNull(draft.organizerName),
    venueName: trimOrNull(draft.venueName),
    venueAddress: trimOrNull(draft.venueAddress),
    sourceEventUrl: trimOrNull(draft.sourceEventUrl),
    sourceProvider: trimOrNull(draft.sourceProvider),
    referenceLinks: splitLines(draft.referenceLinksText),
    socialLinks: parseJsonTextOrNull(draft.socialLinksText),
    city: trimOrNull(canonicalLocationText(draft.city)),
    cityI18n: cityI18n ?? undefined,
    country: trimOrNull(canonicalLocationText(draft.country, { preferEnglishFull: true })),
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
    status: resolveVisualStatus(draft.startDate, draft.endDate, draft.timeZoneSelection?.timezone),
  };
};

export const mapEventStudioDraftToUpdateInput = (draft: EventStudioDraft): EventStudioUpdateInput => {
  const createInput = mapEventStudioDraftToCreateInput(draft);
  const hasManualLocation = Boolean(createInput.manualLocation);
  const hasLocationPoint = Boolean(createInput.locationPoint);
  const hasLatitude = createInput.latitude !== null && createInput.latitude !== undefined;
  const hasLongitude = createInput.longitude !== null && createInput.longitude !== undefined;
  const hasWikiFestivalId = Boolean(createInput.wikiFestivalId);
  const hasSocialLinksText = draft.socialLinksText.trim().length > 0;
  const includeTimeZoneSelectionMetadata = draft.timeZoneSelection?.matchSource !== 'event-edit-hydrate';

  return {
    ...createInput,
    clearCityI18n: draft.clearCityI18nIntent,
    clearCountryI18n: draft.clearCountryI18nIntent,
    clearWikiFestivalId: !hasWikiFestivalId,
    clearManualLocation: !hasManualLocation,
    clearLocationPoint: !hasLocationPoint,
    clearLatitude: !hasLatitude,
    clearLongitude: !hasLongitude,
    clearSocialLinks: !hasSocialLinksText,
    clearStageOrder: !createInput.stageOrder?.length,
    clearLineupSlots: !createInput.lineupSlots?.length,
    coverImageUrl: firstImageInZone(draft, 'poster') || firstImageInZone(draft, 'cover') ? createInput.coverImageUrl : null,
    lineupImageUrl: firstImageInZone(draft, 'lineup') ? createInput.lineupImageUrl : null,
    timeZoneCity: includeTimeZoneSelectionMetadata ? createInput.timeZoneCity : null,
    timeZoneProvince: includeTimeZoneSelectionMetadata ? createInput.timeZoneProvince : null,
    timeZoneCountry: includeTimeZoneSelectionMetadata ? createInput.timeZoneCountry : null,
    timeZoneStateAnsi: includeTimeZoneSelectionMetadata ? createInput.timeZoneStateAnsi : null,
    timeZoneLat: includeTimeZoneSelectionMetadata ? createInput.timeZoneLat : null,
    timeZoneLng: includeTimeZoneSelectionMetadata ? createInput.timeZoneLng : null,
  };
};
