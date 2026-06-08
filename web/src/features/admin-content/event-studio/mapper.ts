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
import { INPUT_LIMITS, normalizeMultiline, normalizeSingleLine, trimArrayItems } from '@/lib/input-rules';

type EventLocationProvider = EventContractComponents['schemas']['EventLocationProvider'];
type EventLocationSourceMode = EventContractComponents['schemas']['EventLocationSourceMode'];
type EventLocationProviderMeta = EventContractComponents['schemas']['EventLocationProviderMeta'];
type EventStudioLocationProviderMetaInput = NonNullable<NonNullable<EventStudioDraft['locationPoint']>['providerMeta']>;

const trimSingleLineOrNull = (value: string | null | undefined, max: number): string | null => {
  const trimmed = normalizeSingleLine(value).slice(0, max);
  return trimmed || null;
};

const trimMultilineOrNull = (value: string | null | undefined, max: number): string | null => {
  const trimmed = normalizeMultiline(value).slice(0, max);
  return trimmed || null;
};

const trimUrlOrNull = (value?: string | null): string | null =>
  trimSingleLineOrNull(value, INPUT_LIMITS.common.url);

const trimExternalIdOrNull = (value?: string | null): string | null =>
  trimSingleLineOrNull(value, INPUT_LIMITS.common.externalId);

const splitLines = (value: string): string[] =>
  trimArrayItems(value.split(/[\n,]/), INPUT_LIMITS.common.url);

const parseJsonTextOrNull = (value: string): unknown | null => {
  const trimmed = normalizeMultiline(value).slice(0, INPUT_LIMITS.event.socialLinksText);
  if (!trimmed) return null;
  try {
    return JSON.parse(trimmed);
  } catch {
    return null;
  }
};

const numericOrNull = (value?: string | null): number | null => {
  const trimmed = normalizeSingleLine(value);
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

  const amapPoiId = trimExternalIdOrNull(value.amap?.poiId);
  const amapAdcode = trimExternalIdOrNull(value.amap?.adcode);
  if (amapPoiId || amapAdcode) {
    next.amap = {
      poiId: amapPoiId,
      adcode: amapAdcode,
    };
  }

  const googlePlaceId = trimExternalIdOrNull(value.google?.placeId);
  const googleTypes = value.google?.types
    ?.map((item: string | null | undefined) => trimExternalIdOrNull(item))
    .filter((item): item is string => Boolean(item)) || null;
  if (googlePlaceId || (googleTypes && googleTypes.length)) {
    next.google = {
      placeId: googlePlaceId,
      types: googleTypes && googleTypes.length ? googleTypes : null,
    };
  }

  const mapkitIdentifier = trimExternalIdOrNull(value.mapkit?.mapItemIdentifier);
  if (mapkitIdentifier) {
    next.mapkit = {
      mapItemIdentifier: mapkitIdentifier,
    };
  }

  const mapboxPlaceId = trimExternalIdOrNull(value.mapbox?.placeId);
  const mapboxFeatureType = trimExternalIdOrNull(value.mapbox?.featureType);
  if (mapboxPlaceId || mapboxFeatureType) {
    next.mapbox = {
      placeId: mapboxPlaceId,
      featureType: mapboxFeatureType,
    };
  }

  const geoapifyPlaceId = trimExternalIdOrNull(value.geoapify?.placeId);
  const geoapifyFeatureType = trimExternalIdOrNull(value.geoapify?.featureType);
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
  const trimmed = normalizeSingleLine(value);
  if (!trimmed) return trimmed;
  const parsed = new Date(`${trimmed}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime())) return trimmed;
  parsed.setUTCDate(parsed.getUTCDate() + 1);
  return parsed.toISOString().slice(0, 10);
};

const composeSlotDateTime = (date: string, time: string): string => {
  const normalizedDate = normalizeSingleLine(date);
  const normalizedTime = normalizeSingleLine(time);
  if (!normalizedDate || !normalizedTime) return '';
  return `${normalizedDate}T${normalizedTime}:00`;
};

const dateWithDayOffset = (date: string, offset?: number): string => {
  const normalizedDate = normalizeSingleLine(date);
  const normalizedOffset = Math.max(0, Math.floor(Number(offset) || 0));
  if (!normalizedDate || normalizedOffset <= 0) return normalizedDate;
  let result = normalizedDate;
  for (let index = 0; index < normalizedOffset; index += 1) {
    result = nextDateText(result);
  }
  return result;
};

const normalizedLocalizedText = (
  value: EventStudioLocalizedText,
  max: number,
  multiline = false
): EventStudioLocalizedText | null => {
  const next: EventStudioLocalizedText = {
    zh: (multiline ? normalizeMultiline(value.zh) : normalizeSingleLine(value.zh)).slice(0, max),
    en: (multiline ? normalizeMultiline(value.en) : normalizeSingleLine(value.en)).slice(0, max),
    ja: (multiline ? normalizeMultiline(value.ja) : normalizeSingleLine(value.ja)).slice(0, max),
    enFull: (multiline ? normalizeMultiline(value.enFull) : normalizeSingleLine(value.enFull)).slice(0, max),
  };
  return next.zh || next.en || next.ja || next.enFull ? next : null;
};

const primaryText = (value: EventStudioLocalizedText): string =>
  normalizeSingleLine(value.zh)
  || normalizeSingleLine(value.en)
  || normalizeSingleLine(value.ja)
  || normalizeSingleLine(value.enFull);

const canonicalLocationText = (
  value: EventStudioLocalizedText,
  max: number,
  options?: { preferEnglishFull?: boolean }
): string => {
  const en = normalizeSingleLine(value.en).slice(0, max);
  const zh = normalizeSingleLine(value.zh).slice(0, max);
  const ja = normalizeSingleLine(value.ja).slice(0, max);
  const enFull = normalizeSingleLine(value.enFull).slice(0, max);
  if (options?.preferEnglishFull) {
    return en || enFull || zh || ja;
  }
  return en || zh || ja || enFull;
};

const normalizedAddressText = (value: EventStudioLocalizedText, max: number): EventStudioLocalizedText => ({
  zh: normalizeSingleLine(value.zh).slice(0, max),
  en: normalizeSingleLine(value.en).slice(0, max),
  ja: normalizeSingleLine(value.ja).slice(0, max),
  enFull: normalizeSingleLine(value.enFull).slice(0, max),
});

const joinAddressParts = (parts: Array<string | null | undefined>): string =>
  parts
    .map((item) => normalizeSingleLine(item))
    .filter(Boolean)
    .join(' · ');

const joinLocalizedAddress = (
  detail: EventStudioLocalizedText,
  city: EventStudioLocalizedText,
  country: EventStudioLocalizedText
): EventStudioLocalizedText => {
  const normalizedDetail = normalizedAddressText(detail, INPUT_LIMITS.event.detailAddress);
  const normalizedCity = normalizedAddressText(city, INPUT_LIMITS.event.city);
  const normalizedCountry = normalizedAddressText(country, INPUT_LIMITS.event.country);

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

const splitMemberNamesText = (value: string): string[] =>
  trimArrayItems(value.split(/[\/,&]/), INPUT_LIMITS.dj.name);

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

const composeActDisplayName = (
  actType: string | undefined,
  memberNames: string[],
  fallback: string,
  override?: string | null
): string => {
  const normalizedOverride = trimSingleLineOrNull(override, INPUT_LIMITS.dj.name);
  if (normalizedOverride) return normalizedOverride;
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
    return trimExternalIdOrNull(item);
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
  }, INPUT_LIMITS.event.detailAddress, true);
  return normalized ?? undefined;
};

const hasLocationProviderMeta = (value: unknown): boolean => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  return Object.values(value as Record<string, unknown>).some((providerMeta) => {
    if (!providerMeta || typeof providerMeta !== 'object' || Array.isArray(providerMeta)) return false;
    return Object.values(providerMeta as Record<string, unknown>).some((fieldValue) => {
      if (Array.isArray(fieldValue)) {
        return fieldValue.some((item) => typeof item === 'string' && normalizeSingleLine(item).length > 0);
      }
      return typeof fieldValue === 'string' && normalizeSingleLine(fieldValue).length > 0;
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
    const trimmed = trimSingleLineOrNull(value, INPUT_LIMITS.common.stageName);
    if (!trimmed) return;
    const key = trimmed.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    result.push(trimmed);
  };

  explicitStageOrder.forEach(pushStage);
  timetableSlots.forEach((slot) => {
    const normalizedStageName = trimSingleLineOrNull(slot.stageName, INPUT_LIMITS.common.stageName);
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
  const normalizedDjId = trimExternalIdOrNull(artist.djId);
  if (!memberNames.length && !normalizedDjId) return null;

  const normalizedMemberDjIds = normalizeMemberDjIds(artist.memberDjIds).slice(0, performerCount);
  const displayName = composeActDisplayName(artist.actType, memberNames, normalizedDjId || '', artist.displayNameOverride);
  if (!displayName) return null;

  return {
    id: trimExternalIdOrNull(artist.canonicalArtistId),
    djId: normalizedDjId,
    memberDjIds: normalizedMemberDjIds.length ? normalizedMemberDjIds : (normalizedDjId ? [normalizedDjId] : null),
    memberNames: memberNames.length ? memberNames : null,
    djName: displayName.slice(0, INPUT_LIMITS.dj.name),
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
  const normalizedDjId = trimExternalIdOrNull(slot.djId);
  const normalizedStageName = trimSingleLineOrNull(slot.stageName, INPUT_LIMITS.common.stageName) || fallbackStageName(stageOrder);
  if (!memberNames.length && !normalizedDjId) return null;
  if (!normalizeSingleLine(slot.eventDayId) || !normalizeSingleLine(slot.localDate) || !normalizeSingleLine(slot.startTime) || !normalizeSingleLine(slot.endTime)) return null;

  if (memberNames.length < performerCount) return null;

  const normalizedMemberDjIds = normalizeMemberDjIds(slot.memberDjIds).slice(0, performerCount);
  const displayName = composeActDisplayName(slot.actType, memberNames, normalizedDjId || '', slot.displayNameOverride);
  if (!displayName) return null;
  const startDayOffset = Math.max(0, Math.floor(Number(slot.startDayOffset) || 0));
  const inferredEndOffset = slot.endTime.trim() > slot.startTime.trim() ? startDayOffset : startDayOffset + 1;
  const endDayOffset = Math.max(startDayOffset, Math.floor(Number(slot.endDayOffset) || inferredEndOffset));
  const normalizedStartTime = composeSlotDateTime(dateWithDayOffset(slot.localDate, startDayOffset), slot.startTime);
  const normalizedEndDate = dateWithDayOffset(slot.localDate, endDayOffset);
  const identityKey = eventStudioTimetableSlotIdentityKey(slot);

  return {
    id: trimExternalIdOrNull(slot.canonicalSlotId),
    lineupArtistId: trimExternalIdOrNull(slot.lineupArtistId) || (identityKey ? lineupArtistIdByKey.get(identityKey) : null) || null,
    eventDayId: slot.eventDayId,
    weekIndex: slot.weekIndex,
    dayIndexInWeek: slot.dayIndexInWeek,
    overallDayIndex: slot.overallDayIndex,
    localDate: slot.localDate,
    djId: normalizedDjId,
    memberDjIds: normalizedMemberDjIds.length ? normalizedMemberDjIds : (normalizedDjId ? [normalizedDjId] : null),
    memberNames: memberNames.length ? memberNames : null,
    festivalDayIndex: null,
    djName: displayName.slice(0, INPUT_LIMITS.dj.name),
    stageName: normalizedStageName,
    sortOrder: slot.sortOrder,
    startTime: normalizedStartTime,
    endTime: composeSlotDateTime(normalizedEndDate, slot.endTime),
  };
};

export const mapEventStudioDraftToCreateInput = (draft: EventStudioDraft): EventStudioCreateInput => {
  const nameI18n = normalizedLocalizedText(draft.name, INPUT_LIMITS.event.name);
  const cityI18n = draft.clearCityI18nIntent ? null : normalizedLocalizedText(draft.city, INPUT_LIMITS.event.city);
  const countryI18n = draft.clearCountryI18nIntent ? null : normalizedLocalizedText(draft.country, INPUT_LIMITS.event.country);
  const detailAddressI18n = normalizedLocalizedText(draft.detailAddress, INPUT_LIMITS.event.detailAddress, true);
  const posterImage = firstImageInZone(draft, 'poster');
  const coverImage = firstImageInZone(draft, 'cover');
  const lineupImage = firstImageInZone(draft, 'lineup');
  const coverUrl = trimUrlOrNull(posterImage?.remoteUrl || coverImage?.remoteUrl);
  const lineupUrl = trimUrlOrNull(lineupImage?.remoteUrl);
  const latitude = numericOrNull(draft.latitude);
  const longitude = numericOrNull(draft.longitude);
  const locationName = trimSingleLineOrNull(draft.pickedPlaceName, INPUT_LIMITS.event.name);
  const locationAddress = trimSingleLineOrNull(draft.pickedMapAddress, INPUT_LIMITS.event.detailAddress);
  const locationProviderMeta = normalizeLocationProviderMeta(draft.locationPoint?.providerMeta ?? null);
  const locationProvider =
    normalizeLocationProvider(draft.locationPoint?.provider)
    || inferLocationProviderFromMeta(locationProviderMeta, trimExternalIdOrNull(draft.locationPoint?.adcode), trimExternalIdOrNull(draft.locationPoint?.poiId));
  const locationSourceMode =
    normalizeLocationSourceMode(draft.locationPoint?.sourceMode)
    || (locationProviderMeta || trimExternalIdOrNull(draft.locationPoint?.providerPlaceId) || trimExternalIdOrNull(draft.locationPoint?.poiId)
      ? 'manual_search'
      : locationProvider
        ? 'legacy_coords'
        : null);
  const locationProviderPlaceId = trimExternalIdOrNull(draft.locationPoint?.providerPlaceId);
  const locationPoiId = trimExternalIdOrNull(draft.locationPoint?.poiId);
  const locationAdcode = trimExternalIdOrNull(draft.locationPoint?.adcode);
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
          url: normalizeSingleLine(image.remoteUrl).slice(0, INPUT_LIMITS.common.url),
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
        manualSetAddressI18n:
          detailAddressI18n
            ? joinLocalizedAddress(detailAddressI18n, cityI18n || draft.city, countryI18n || draft.country)
            : cloneLocalizedTextOrUndefined(draft.locationPoint?.manualSetAddressI18n) ||
              cloneLocalizedTextOrUndefined(draft.locationPoint?.formattedAddressI18n) ||
              (locationAddress
                ? {
                    zh: locationAddress,
                    en: locationAddress,
                    ja: '',
                    enFull: '',
                  }
                : undefined),
        city: trimSingleLineOrNull(draft.locationPoint?.city, INPUT_LIMITS.event.city) || trimSingleLineOrNull(primaryText(draft.city), INPUT_LIMITS.event.city),
        district: trimSingleLineOrNull(draft.locationPoint?.district, INPUT_LIMITS.event.city),
        province: trimSingleLineOrNull(draft.locationPoint?.province, INPUT_LIMITS.event.country),
        countryCode: trimSingleLineOrNull(draft.locationPoint?.countryCode, 16),
      }
    : null;

  const ticketTiers = draft.ticketTiers
    .map((tier, index) => {
      const name = normalizeSingleLine(tier.name).slice(0, INPUT_LIMITS.common.ticketTierName) || defaultTicketTierName(index);
      const price = Number(tier.price);
      if (!Number.isFinite(price)) return null;
      return {
        name,
        price,
        currency: (trimSingleLineOrNull(tier.currency, INPUT_LIMITS.common.currency) || trimSingleLineOrNull(draft.ticketCurrency, INPUT_LIMITS.common.currency))?.toUpperCase() || null,
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
    label: trimSingleLineOrNull(week.label, INPUT_LIMITS.event.name),
    startDate: week.startDate,
    endDate: week.endDate,
    sortOrder: week.sortOrder,
  }));

  const eventDays = draft.eventDays.map((day) => ({
    eventDayId: day.eventDayId,
    weekIndex: day.weekIndex,
    dayIndexInWeek: day.dayIndexInWeek,
    overallDayIndex: day.overallDayIndex,
    label: trimSingleLineOrNull(day.label, INPUT_LIMITS.event.name),
    weekday: trimSingleLineOrNull(day.weekday, INPUT_LIMITS.event.abbreviation),
    date: day.date,
    sortOrder: day.sortOrder,
  }));
  const explicitStageOrder = trimArrayItems(draft.stageOrder, INPUT_LIMITS.common.stageName);
  const stageOrder = normalizeStageOrderForPayload(explicitStageOrder, draft.timetableSlots);
  const lineupArtistIdByKey = new Map<string, string>();
  draft.lineupArtists.forEach((artist) => {
    const key = eventStudioLineupArtistIdentityKey(artist);
    const artistId = trimExternalIdOrNull(artist.canonicalArtistId);
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
    name: primaryText(nameI18n ?? draft.name).slice(0, INPUT_LIMITS.event.name),
    nameI18n: nameI18n ?? undefined,
    wikiFestivalId: trimExternalIdOrNull(draft.organizerFestivalId),
    abbreviation: trimSingleLineOrNull(draft.abbreviation, INPUT_LIMITS.event.abbreviation),
    description: trimMultilineOrNull(draft.description, INPUT_LIMITS.event.description),
    eventType: trimExternalIdOrNull(draft.eventType),
    organizerName: trimSingleLineOrNull(draft.organizerName, INPUT_LIMITS.event.organizerName),
    sourceEventUrl: trimUrlOrNull(draft.sourceEventUrl),
    sourceProvider: trimSingleLineOrNull(draft.sourceProvider, INPUT_LIMITS.event.sourceProvider),
    referenceLinks: splitLines(draft.referenceLinksText),
    socialLinks: parseJsonTextOrNull(draft.socialLinksText),
    city: trimSingleLineOrNull(canonicalLocationText(draft.city, INPUT_LIMITS.event.city), INPUT_LIMITS.event.city),
    cityI18n: cityI18n ?? undefined,
    country: trimSingleLineOrNull(canonicalLocationText(draft.country, INPUT_LIMITS.event.country, { preferEnglishFull: true }), INPUT_LIMITS.event.country),
    countryI18n: countryI18n ?? undefined,
    manualLocation: manualLocation ?? undefined,
    locationPoint: locationPoint ?? undefined,
    latitude,
    longitude,
    ticketUrl: trimUrlOrNull(draft.ticketUrl),
    ticketCurrency: trimSingleLineOrNull(draft.ticketCurrency, INPUT_LIMITS.common.currency)?.toUpperCase() || null,
    ticketNotes: trimMultilineOrNull(draft.ticketNotes, INPUT_LIMITS.event.ticketNotes),
    officialWebsite: trimUrlOrNull(draft.officialWebsite),
    startDate: draft.startDate,
    endDate: draft.endDate,
    schedule: schedule ?? undefined,
    weeks: weeks.length ? weeks : null,
    eventDays: eventDays.length ? eventDays : null,
    timeZone: trimSingleLineOrNull(draft.timeZoneSelection?.timezone, INPUT_LIMITS.common.externalId),
    timeZoneCity: trimSingleLineOrNull(draft.timeZoneSelection?.city, INPUT_LIMITS.event.city),
    timeZoneProvince: trimSingleLineOrNull(draft.timeZoneSelection?.exactProvince || draft.timeZoneSelection?.province, INPUT_LIMITS.event.country),
    timeZoneCountry: trimSingleLineOrNull(draft.timeZoneSelection?.country, INPUT_LIMITS.event.country),
    timeZoneStateAnsi: trimSingleLineOrNull(draft.timeZoneSelection?.stateAnsi, 16),
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
    isCancelled: draft.isCancelled,
    visibility: draft.visibility,
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
