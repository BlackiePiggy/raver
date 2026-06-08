import { Request, Response } from 'express';
import { Prisma, PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';
import {
  buildMediaObjectKey,
  isObjectStorageConfigured,
  uploadBufferToObjectStorage,
} from '../services/media-storage.service';
import { mediaAssetService } from '../services/media-asset.service';
import {
  DEFAULT_EVENT_TIME_ZONE,
  diffEventDays,
  isValidEventTimeZone,
  normalizeEventTimeZone,
  parseEventDateInput,
  startOfEventDay,
  zonedTimeToUtc,
} from '../utils/event-timezone';
import {
  buildEventStatusWhere,
  deriveEventStatus,
  resolveEventTruth,
} from '../utils/event-status';
import {
  loadCanonicalEventLineupSnapshot,
  normalizeCanonicalLineupArtists,
  syncCanonicalEventLineupAndTimetable,
} from '../services/event-lineup-canonical.service';
import {
  EventSubmissionValidationError,
  normalizeSubmittedEventScheduleContext,
  normalizeSubmittedTimetableSlots,
  syncStructuredEventSchedule,
} from '../services/content-submission-event.service';
import {
  EventAdminContractGuardrailError,
  validateEventAdminContractPayload,
} from '../services/event-admin-contract-guardrail.service';
import { recordEventContribution } from '../services/contribution.service';
import {
  EntityChangeInvalidRevisionError,
  EntityChangeRevisionConflictError,
  entityChangeService,
} from '../modules/entity-change';

const cityTimezones = require('city-timezones') as {
  lookupViaCity: (city: string) => unknown[];
  findFromCityStateProvince: (query: string) => unknown[];
};

const prisma = new PrismaClient();

class EventInputValidationError extends Error {}

type LineupSlotInput = {
  djId?: string;
  memberDjIds?: Array<string | null>;
  memberNames?: string[];
  festivalDayIndex?: number | null;
  djName?: string;
  stageName?: string;
  sortOrder?: number;
  startTime: string;
  endTime: string;
};

type TicketTierInput = {
  name?: string;
  price?: number | string;
  currency?: string;
  sortOrder?: number;
};

type RawLineupArtistInput = {
  djId?: string;
  memberDjIds?: Array<string | null>;
  memberNames?: string[];
  djName?: string;
  name?: string;
  musician?: string;
  artistName?: string;
  sortOrder?: number;
};

type LineupArtistInput = {
  djId: string | null;
  memberDjIds: Array<string | null>;
  memberNames?: string[];
  djName: string;
  sortOrder: number;
};

type CityTimezoneLookupRow = {
  city: string;
  city_ascii?: string;
  country?: string;
  iso2?: string;
  iso3?: string;
  province?: string;
  exactCity?: string;
  exactProvince?: string;
  state_ansi?: string;
  timezone?: string;
  lat?: number;
  lng?: number;
  pop?: number;
};

type EventTimezoneLookupItem = {
  city: string;
  cityAscii: string;
  province: string;
  exactProvince: string;
  stateAnsi: string;
  country: string;
  iso2: string;
  iso3: string;
  timezone: string;
  lat: number | null;
  lng: number | null;
  population: number | null;
  label: string;
  searchRank: number;
  matchSource: 'exact-city' | 'city-region-search';
};

type SubmittedEventTimezoneSelection = {
  city: string;
  province: string;
  country: string;
  stateAnsi: string;
  lat: number | null;
  lng: number | null;
};

const slugify = (value: string) =>
  value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '') || 'event';

const toNumberOrNull = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') {
    return null;
  }
  const num = Number(value);
  return Number.isFinite(num) ? num : null;
};

const normalizeCityTimezoneText = (value: unknown): string =>
  String(value ?? '')
    .trim()
    .replace(/\s+/g, ' ');

const buildEventTimezoneLookupLabel = (item: {
  city: string;
  province?: string;
  exactProvince?: string;
  stateAnsi?: string;
  country?: string;
  timezone: string;
}): string => {
  const parts = [
    normalizeCityTimezoneText(item.city),
    normalizeCityTimezoneText(item.exactProvince || item.stateAnsi || item.province || ''),
    normalizeCityTimezoneText(item.country || ''),
  ].filter(Boolean);
  return `${parts.join(', ')} · ${item.timezone}`;
};

const toEventTimezoneLookupItem = (
  row: unknown,
  query: string,
  matchSource: 'exact-city' | 'city-region-search'
): EventTimezoneLookupItem | null => {
  if (!row || typeof row !== 'object' || Array.isArray(row)) return null;
  const source = row as CityTimezoneLookupRow;
  const timezone = normalizeCityTimezoneText(source.timezone);
  const city = normalizeCityTimezoneText(source.city);
  if (!city || !timezone || !isValidEventTimeZone(timezone)) return null;

  const cityAscii = normalizeCityTimezoneText(source.city_ascii || city);
  const province = normalizeCityTimezoneText(source.province);
  const exactProvince = normalizeCityTimezoneText(source.exactProvince || province);
  const stateAnsi = normalizeCityTimezoneText(source.state_ansi);
  const country = normalizeCityTimezoneText(source.country);
  const iso2 = normalizeCityTimezoneText(source.iso2).toUpperCase();
  const iso3 = normalizeCityTimezoneText(source.iso3).toUpperCase();
  const normalizedQuery = normalizeCityTimezoneText(query).toLowerCase();
  const normalizedCity = city.toLowerCase();
  const normalizedAscii = cityAscii.toLowerCase();
  const exactCity = normalizeCityTimezoneText(source.exactCity || city).toLowerCase();

  let searchRank = matchSource === 'exact-city' ? 0 : 20;
  if (normalizedQuery && (
    normalizedCity === normalizedQuery
    || normalizedAscii === normalizedQuery
    || exactCity === normalizedQuery
  )) {
    searchRank -= 10;
  }
  if (stateAnsi) searchRank -= 1;
  const population = toNumberOrNull(source.pop);
  if (population) {
    searchRank -= Math.min(5, Math.floor(Math.log10(Math.max(1, population))));
  }

  return {
    city,
    cityAscii,
    province,
    exactProvince,
    stateAnsi,
    country,
    iso2,
    iso3,
    timezone,
    lat: toNumberOrNull(source.lat),
    lng: toNumberOrNull(source.lng),
    population,
    label: buildEventTimezoneLookupLabel({
      city,
      province,
      exactProvince,
      stateAnsi,
      country,
      timezone,
    }),
    searchRank,
    matchSource,
  };
};

export const searchEventTimezonesByCity = (query: string, limitRaw: unknown): EventTimezoneLookupItem[] => {
  const searchQuery = normalizeCityTimezoneText(query);
  if (!searchQuery) return [];
  const limitParsed = Number(limitRaw);
  const limit = Number.isFinite(limitParsed)
    ? Math.max(1, Math.min(20, Math.floor(limitParsed)))
    : 8;

  const exactMatches = cityTimezones.lookupViaCity(searchQuery) || [];
  const broadMatches = cityTimezones.findFromCityStateProvince(searchQuery) || [];
  const merged = new Map<string, EventTimezoneLookupItem>();
  const push = (rows: unknown[], matchSource: 'exact-city' | 'city-region-search') => {
    for (const row of rows) {
      const item = toEventTimezoneLookupItem(row, searchQuery, matchSource);
      if (!item) continue;
      const key = [
        item.city.toLowerCase(),
        item.exactProvince.toLowerCase(),
        item.country.toLowerCase(),
        item.timezone.toLowerCase(),
      ].join('|');
      const existing = merged.get(key);
      if (!existing || item.searchRank < existing.searchRank) {
        merged.set(key, item);
      }
    }
  };
  push(exactMatches, 'exact-city');
  push(broadMatches, 'city-region-search');

  return Array.from(merged.values())
    .sort((a, b) => {
      if (a.searchRank !== b.searchRank) return a.searchRank - b.searchRank;
      const popA = a.population ?? -1;
      const popB = b.population ?? -1;
      if (popA !== popB) return popB - popA;
      return a.label.localeCompare(b.label, 'en', { sensitivity: 'base' });
    })
    .slice(0, limit);
};

const readSubmittedEventTimezoneSelection = (
  body: Record<string, unknown>
): SubmittedEventTimezoneSelection | null => {
  const city = normalizeCityTimezoneText(body.timeZoneCity);
  const province = normalizeCityTimezoneText(body.timeZoneProvince);
  const country = normalizeCityTimezoneText(body.timeZoneCountry);
  const stateAnsi = normalizeCityTimezoneText(body.timeZoneStateAnsi).toUpperCase();
  const lat = toNumberOrNull(body.timeZoneLat);
  const lng = toNumberOrNull(body.timeZoneLng);
  if (!city && !province && !country && !stateAnsi && lat === null && lng === null) return null;
  return {
    city,
    province,
    country,
    stateAnsi,
    lat,
    lng,
  };
};

const validateSubmittedEventTimezoneSelection = (
  body: Record<string, unknown>,
  submittedTimeZone: string
): string | null => {
  const selection = readSubmittedEventTimezoneSelection(body);
  if (!selection) return null;
  if (!selection.city) return 'timeZoneCity is required when submitting city-based timezone metadata';

  const query = [
    selection.city,
    selection.stateAnsi || selection.province,
    selection.country,
  ].filter(Boolean).join(' ').trim() || selection.city;

  const candidates = searchEventTimezonesByCity(query, 20);
  const cityLower = selection.city.toLowerCase();
  const provinceLower = selection.province.toLowerCase();
  const countryLower = selection.country.toLowerCase();
  const targetTimeZone = normalizeEventTimeZone(submittedTimeZone);
  const matched = candidates.find((item) => {
    if (item.timezone !== targetTimeZone) return false;
    const cityMatches = item.city.toLowerCase() === cityLower || item.cityAscii.toLowerCase() === cityLower;
    if (!cityMatches) return false;
    if (selection.stateAnsi && item.stateAnsi.toUpperCase() !== selection.stateAnsi) return false;
    if (provinceLower) {
      const itemProvince = (item.exactProvince || item.province || '').toLowerCase();
      if (itemProvince && itemProvince !== provinceLower) return false;
    }
    if (countryLower && item.country.toLowerCase() !== countryLower) return false;
    if (selection.lat !== null && item.lat !== null && Math.abs(item.lat - selection.lat) > 0.5) return false;
    if (selection.lng !== null && item.lng !== null && Math.abs(item.lng - selection.lng) > 0.5) return false;
    return true;
  });

  return matched ? null : 'Submitted event timezone does not match the selected city timezone result';
};

const EVENT_DEFAULT_START_TIME = '00:00:00';
const EVENT_DEFAULT_END_TIME = '23:59:59';

const normalizeEventClockTime = (value: unknown, fallback: string): string => {
  if (typeof value !== 'string') return fallback;
  const trimmed = value.trim();
  if (!trimmed) return fallback;
  const match = trimmed.match(/^(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$/);
  if (!match) return fallback;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  const second = Number(match[3] ?? '0');
  if (!Number.isInteger(hour) || !Number.isInteger(minute) || !Number.isInteger(second)) return fallback;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59 || second < 0 || second > 59) return fallback;
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:${String(second).padStart(2, '0')}`;
};

const normalizeEventStartDate = (date: Date, timeZone = DEFAULT_EVENT_TIME_ZONE): Date => startOfEventDay(date, timeZone);

const normalizeEventEndDate = (date: Date, timeZone = DEFAULT_EVENT_TIME_ZONE): Date =>
  new Date(startOfEventDay(date, timeZone).getTime() + 86_400_000 - 1000);

const withDerivedStatus = <
  T extends {
    startDate: Date;
    endDate: Date;
    isCancelled?: boolean | null;
    visibility?: unknown;
  }
>(event: T) => {
  const resolvedTruth = resolveEventTruth({
    isCancelled: event.isCancelled ?? undefined,
    visibility: event.visibility ?? undefined,
  });

  return {
    ...event,
    status: deriveEventStatus(new Date(event.startDate), new Date(event.endDate), {
      isCancelled: resolvedTruth.isCancelled,
      visibility: resolvedTruth.visibility,
    }),
  };
};

const LINEUP_DJ_ID_PLACEHOLDER = '__UNBOUND__';
const isLineupDjIdPlaceholder = (value: string): boolean => value === LINEUP_DJ_ID_PLACEHOLDER;
const normalizeTrimmedText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  const text = value.trim();
  if (!text || /^\[object\s+object\]$/i.test(text)) return '';
  return text;
};

const normalizeOptionalTriTextJson = (value: unknown): Prisma.InputJsonValue | undefined => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return undefined;
  const row = value as Record<string, unknown>;
  const out: Record<string, string> = {};
  const zh = normalizeTrimmedText(row.zh ?? row.ZH ?? row.cn ?? row.chinese ?? row['zh-CN']);
  const en = normalizeTrimmedText(row.en ?? row.EN ?? row.english ?? row['en-US']);
  const ja = normalizeTrimmedText(row.ja ?? row.JA ?? row.jp ?? row.japanese ?? row['ja-JP']);
  const enFull = normalizeTrimmedText(row.enFull ?? row.en_full ?? row.englishFull ?? row.country_en_full);
  if (zh) out.zh = zh;
  if (en) out.en = en;
  if (ja) out.ja = ja;
  if (enFull) out.enFull = enFull;
  return Object.keys(out).length ? (out as Prisma.InputJsonValue) : undefined;
};

type EventLocalizedAddressText = {
  zh?: string;
  en?: string;
  ja?: string;
  enFull?: string;
};

const asPlainObject = (value: unknown): Record<string, unknown> | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
};

const normalizeLocalizedAddressText = (value: unknown): EventLocalizedAddressText | null => {
  const row = asPlainObject(value);
  if (!row) return null;
  const zh = normalizeTrimmedText(row.zh ?? row['zh-CN'] ?? row['zh-Hans']);
  const en = normalizeTrimmedText(row.en ?? row['en-US']);
  const ja = normalizeTrimmedText(row.ja ?? row['ja-JP']);
  const enFull = normalizeTrimmedText(row.enFull ?? row.en_full);
  if (!zh && !en && !ja && !enFull) return null;
  return {
    zh: zh || undefined,
    en: en || undefined,
    ja: ja || undefined,
    enFull: enFull || undefined,
  };
};

const joinAddressParts = (parts: Array<string | null | undefined>): string =>
  parts
    .map((item) => normalizeTrimmedText(item))
    .filter(Boolean)
    .join(' · ');

const buildFormattedAddressI18n = (input: {
  detailAddressI18n?: EventLocalizedAddressText | null;
  cityI18n?: EventLocalizedAddressText | null;
  countryI18n?: EventLocalizedAddressText | null;
}): EventLocalizedAddressText | null => {
  const detail = input.detailAddressI18n;
  if (!detail) return null;
  const city = input.cityI18n ?? null;
  const country = input.countryI18n ?? null;
  return {
    zh:
      joinAddressParts([
        country?.zh || country?.en,
        city?.zh || city?.en,
        detail.zh || detail.en,
      ]) || detail.zh || detail.en,
    en:
      joinAddressParts([
        country?.enFull || country?.en || country?.zh,
        city?.en || city?.zh,
        detail.en || detail.zh,
      ]) || detail.en || detail.zh,
    ja:
      joinAddressParts([
        country?.ja || country?.enFull || country?.en || country?.zh,
        city?.ja || city?.en || city?.zh,
        detail.ja || detail.en || detail.zh,
      ]) || detail.ja || detail.en || detail.zh,
    enFull: detail.enFull,
  };
};

const normalizeEventAddressPayloads = (input: {
  manualLocation: unknown;
  locationPoint: unknown;
  cityI18n?: Prisma.InputJsonValue;
  countryI18n?: Prisma.InputJsonValue;
}): {
  manualLocation: Prisma.InputJsonValue | typeof Prisma.JsonNull | undefined;
  locationPoint: Prisma.InputJsonValue | typeof Prisma.JsonNull | undefined;
} => {
  const manualLocation = asPlainObject(input.manualLocation);
  const locationPoint = asPlainObject(input.locationPoint);
  const normalizedCityI18n = normalizeLocalizedAddressText(input.cityI18n);
  const normalizedCountryI18n = normalizeLocalizedAddressText(input.countryI18n);
  const detailAddressI18n = normalizeLocalizedAddressText(manualLocation?.detailAddressI18n);
  const formattedAddressI18n = buildFormattedAddressI18n({
    detailAddressI18n,
    cityI18n: normalizedCityI18n,
    countryI18n: normalizedCountryI18n,
  });

  const nextManualLocation = manualLocation
    ? {
        ...manualLocation,
        ...(detailAddressI18n ? { detailAddressI18n } : {}),
        ...(formattedAddressI18n ? { formattedAddressI18n } : {}),
      }
    : undefined;

  const pointManualSetAddressI18n =
    normalizeLocalizedAddressText(locationPoint?.manualSetAddressI18n);

  const nextLocationPoint = locationPoint
    ? {
        ...locationPoint,
        ...(pointManualSetAddressI18n ? { manualSetAddressI18n: pointManualSetAddressI18n } : {}),
      }
    : undefined;

  return {
    manualLocation: nextManualLocation ? (nextManualLocation as Prisma.InputJsonValue) : undefined,
    locationPoint: nextLocationPoint ? (nextLocationPoint as Prisma.InputJsonValue) : undefined,
  };
};

const hasOwn = (body: Record<string, unknown>, key: string): boolean =>
  Object.prototype.hasOwnProperty.call(body, key);

const normalizeOptionalNullableTextField = (
  body: Record<string, unknown>,
  key: string
): string | null | undefined => {
  if (!hasOwn(body, key)) return undefined;
  const text = normalizeTrimmedText(body[key]);
  return text || null;
};

const normalizeOptionalStringArrayField = (
  body: Record<string, unknown>,
  key: string
): string[] | undefined => {
  if (!hasOwn(body, key)) return undefined;
  const value = body[key];
  const source = Array.isArray(value)
    ? value
    : typeof value === 'string'
      ? value.split(/[\n,]/)
      : [];
  return Array.from(new Set(source.map((item) => normalizeTrimmedText(item)).filter(Boolean)));
};

const normalizeOptionalJsonField = (
  body: Record<string, unknown>,
  key: string
): Prisma.InputJsonValue | typeof Prisma.JsonNull | undefined => {
  if (!hasOwn(body, key)) return undefined;
  const value = body[key];
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

const normalizeStageOrder = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  const result: string[] = [];
  for (const item of value) {
    const text = normalizeTrimmedText(item);
    if (!text) continue;
    const key = text.toLocaleLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(text);
  }
  return result;
};
const normalizeDayRolloverHour = (value: unknown, fallback = 6): number => {
  const numeric = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(numeric)) return fallback;
  const hour = Math.floor(numeric);
  if (hour < 0 || hour > 23) return fallback;
  return hour;
};

const datePartsInTimeZone = (date: Date, timeZone: string): { year: number; month: number; day: number } => {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
  };
};

const timePartsInTimeZone = (date: Date, timeZone: string): { hour: number; minute: number; second: number; millisecond: number } => {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hourCycle: 'h23',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return {
    hour: Number(values.hour),
    minute: Number(values.minute),
    second: Number(values.second),
    millisecond: date.getUTCMilliseconds(),
  };
};

const applyDayOffsetPreservingSourceWallTime = (
  timeSource: Date,
  eventStartDate: Date,
  dayOffset: number,
  sourceTimeZoneRaw: unknown,
  targetTimeZoneRaw: unknown
): Date => {
  const sourceTimeZone = normalizeEventTimeZone(sourceTimeZoneRaw);
  const targetTimeZone = normalizeEventTimeZone(targetTimeZoneRaw);
  const dateParts = datePartsInTimeZone(eventStartDate, targetTimeZone);
  const timeParts = timePartsInTimeZone(timeSource, sourceTimeZone);
  return zonedTimeToUtc({
    ...dateParts,
    day: dateParts.day + Math.max(0, dayOffset),
    ...timeParts,
  }, targetTimeZone);
};

type ExistingLineupSlotForRebase = {
  id: string;
  festivalDayIndex: number | null;
  startTime: Date;
  endTime: Date;
};

const rebaseExistingLineupSlotsToEventStart = (
  slots: ExistingLineupSlotForRebase[],
  previousEventStartDate: Date,
  nextEventStartDate: Date,
  _dayRolloverHour: number,
  previousTimeZone = DEFAULT_EVENT_TIME_ZONE,
  nextTimeZone = DEFAULT_EVENT_TIME_ZONE
): Array<{ id: string; festivalDayIndex: number | null; startTime: Date; endTime: Date }> =>
  slots.map((slot) => {
    const startDayOffset = Math.max(0, diffEventDays(previousEventStartDate, slot.startTime, previousTimeZone));
    const endDayOffset = Math.max(0, diffEventDays(previousEventStartDate, slot.endTime, previousTimeZone));
    const startTime = applyDayOffsetPreservingSourceWallTime(
      slot.startTime,
      nextEventStartDate,
      startDayOffset,
      previousTimeZone,
      nextTimeZone
    );
    let endTime = applyDayOffsetPreservingSourceWallTime(
      slot.endTime,
      nextEventStartDate,
      endDayOffset,
      previousTimeZone,
      nextTimeZone
    );
    while (endTime < startTime) {
      endTime = new Date(endTime.getTime() + 86_400_000);
    }

    return {
      id: slot.id,
      festivalDayIndex: slot.festivalDayIndex ?? null,
      startTime,
      endTime,
    };
  });

const buildLineupArtistsFromSlots = (slots: LineupSlotInput[]): LineupArtistInput[] => {
  const byKey = new Map<string, LineupArtistInput>();
  for (const [index, slot] of slots.entries()) {
    const djName = String(slot.djName || '').trim();
    if (!djName) continue;
    const memberDjIds = Array.isArray(slot.memberDjIds)
      ? slot.memberDjIds.map((id) => {
          const normalized = String(id || '').trim();
          return normalized && !isLineupDjIdPlaceholder(normalized) ? normalized : null;
        })
      : [];
    const primaryDjId = slot.djId && !isLineupDjIdPlaceholder(slot.djId) ? slot.djId : (memberDjIds.find((id) => !!id) || null);
    const key = primaryDjId ? `id:${primaryDjId}` : `name:${djName.toLowerCase()}`;
    const existing = byKey.get(key);
    if (existing) {
      if (!existing.memberDjIds.length) {
        existing.memberDjIds = memberDjIds.length ? memberDjIds : (primaryDjId ? [primaryDjId] : []);
      }
      if ((!existing.memberNames || !existing.memberNames.length) && Array.isArray(slot.memberNames) && slot.memberNames.length) {
        existing.memberNames = slot.memberNames;
      }
      if (!existing.djId && primaryDjId) existing.djId = primaryDjId;
      existing.sortOrder = Math.min(existing.sortOrder, slot.sortOrder || index + 1);
      continue;
    }
    byKey.set(key, {
      djId: primaryDjId,
      memberDjIds: memberDjIds.length ? memberDjIds : (primaryDjId ? [primaryDjId] : []),
      memberNames: Array.isArray(slot.memberNames) ? slot.memberNames : undefined,
      djName,
      sortOrder: slot.sortOrder || index + 1,
    });
  }
  return Array.from(byKey.values()).sort((a, b) => a.sortOrder - b.sortOrder);
};

const normalizeLineupArtists = (artists: unknown, fallbackSlots: LineupSlotInput[] = []): LineupArtistInput[] => {
  const source = Array.isArray(artists) ? artists : null;
  if (!source) return buildLineupArtistsFromSlots(fallbackSlots);
  return normalizeCanonicalLineupArtists(
    source
      .filter((raw): raw is RawLineupArtistInput => !!raw && typeof raw === 'object')
      .map((row, index) => {
        const djName = String(row.djName ?? row.name ?? row.musician ?? row.artistName ?? '').trim();
        const memberDjIds = (Array.isArray(row.memberDjIds) ? row.memberDjIds : [])
          .map((id) => {
            const normalized = String(id || '').trim();
            return normalized && !isLineupDjIdPlaceholder(normalized) ? normalized : null;
          });
        const primaryRaw = String(row.djId || '').trim();
        const djId = primaryRaw && !isLineupDjIdPlaceholder(primaryRaw) ? primaryRaw : (memberDjIds.find((id) => !!id) || null);
      return {
          djId,
          memberDjIds: memberDjIds.length ? memberDjIds : (djId ? [djId] : []),
          memberNames: Array.isArray(row.memberNames) ? row.memberNames.map((name) => String(name || '').trim()).filter(Boolean) : undefined,
          djName,
          sortOrder: typeof row.sortOrder === 'number' && Number.isFinite(row.sortOrder) ? row.sortOrder : index + 1,
        };
      }),
    fallbackSlots.map((slot) => ({
      djId: slot.djId ?? null,
      memberDjIds: slot.memberDjIds ?? [],
      memberNames: slot.memberNames ?? [],
      djName: slot.djName || 'Unknown DJ',
      stageName: slot.stageName ?? null,
      festivalDayIndex: slot.festivalDayIndex ?? null,
      startTime: new Date(slot.startTime),
      endTime: new Date(slot.endTime),
      sortOrder: slot.sortOrder || 0,
    }))
  ).map((artist) => ({
    djId: artist.djId,
    memberDjIds: artist.memberDjIds ?? (artist.djId ? [artist.djId] : []),
    memberNames: artist.memberNames,
    djName: artist.djName,
    sortOrder: artist.sortOrder,
  }));
};

const normalizeTicketTiers = (tiers: unknown): TicketTierInput[] => {
  if (!Array.isArray(tiers)) {
    return [];
  }
  return tiers
    .filter((tier) => tier && typeof tier === 'object')
    .map((tier) => tier as TicketTierInput)
    .filter((tier) => String(tier.name || '').trim() && toNumberOrNull(tier.price) !== null);
};

const attachCanonicalLineupToEvent = async <
  T extends {
    id: string;
  }
>(
  event: T
): Promise<T & {
  lineupArtists: Array<{
    id: string;
    eventId: string;
    djId: string | null;
    memberDjIds: Array<string | null>;
    memberNames?: string[];
    djName: string;
    sortOrder: number;
  }>;
  lineupSlots: Array<{
    id: string;
    eventId: string;
    lineupArtistId: string | null;
    djId: string | null;
    memberDjIds: Array<string | null>;
    memberNames?: string[];
    djName: string;
    festivalDayIndex: number | null;
    stageName: string | null;
    sortOrder: number;
    startTime: Date;
    endTime: Date;
  }>;
  timetableSlots: Array<{
    id: string;
    eventId: string;
    lineupArtistId: string | null;
    djId: string | null;
    memberDjIds: Array<string | null>;
    memberNames?: string[];
    djName: string;
    festivalDayIndex: number | null;
    stageName: string | null;
    sortOrder: number;
    startTime: Date;
    endTime: Date;
  }>;
}> => {
  const snapshot = await loadCanonicalEventLineupSnapshot(prisma, event.id);
  const mappedArtists = snapshot.artists.map((artist) => ({
    id: artist.id || '',
    eventId: event.id,
    djId: artist.djId,
    memberDjIds: artist.memberDjIds ?? [],
    memberNames: artist.memberNames ?? [],
    djName: artist.djName,
    sortOrder: artist.sortOrder,
  }));
  const mappedSlots = snapshot.slots.map((slot) => ({
    id: slot.id || '',
    eventId: event.id,
    lineupArtistId: slot.lineupArtistId ?? null,
    eventDayId: slot.eventDayId ?? null,
    weekIndex: slot.weekIndex ?? null,
    dayIndexInWeek: slot.dayIndexInWeek ?? null,
    overallDayIndex: slot.overallDayIndex ?? null,
    localDate: slot.localDate ?? null,
    djId: slot.djId,
    memberDjIds: slot.memberDjIds ?? [],
    memberNames: [],
    djName: slot.djName,
    festivalDayIndex: slot.festivalDayIndex,
    stageName: slot.stageName,
    sortOrder: slot.sortOrder,
    startTime: slot.startTime,
    endTime: slot.endTime,
  }));

  return {
    ...event,
    lineupArtists: mappedArtists,
    lineupSlots: mappedSlots,
    timetableSlots: mappedSlots,
  };
};

export const getEvents = async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      page = '1',
      limit = '20',
      search,
      city,
      country,
      eventType,
      year,
      status = 'upcoming'
    } = req.query;
    const normalizedStatus = String(status || 'upcoming').trim().toLowerCase();

    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    const where: any = {};
    const now = new Date();
    const statusWhere = buildEventStatusWhere(normalizedStatus, now);
    if (statusWhere) {
      Object.assign(where, statusWhere);
    }

    if (search) {
      where.OR = [
        { name: { contains: search as string, mode: 'insensitive' } },
        { description: { contains: search as string, mode: 'insensitive' } },
      ];
    }

    if (city) {
      where.city = city as string;
    }

    if (country) {
      where.country = country as string;
    }
    const yearNum = Number(year);
    if (Number.isInteger(yearNum) && yearNum > 1900 && yearNum < 3000) {
      where.startDate = {
        ...(where.startDate && typeof where.startDate === 'object' ? where.startDate : {}),
        gte: new Date(Date.UTC(yearNum, 0, 1)),
        lt: new Date(Date.UTC(yearNum + 1, 0, 1)),
      };
    }
    if (eventType) {
      where.eventType = eventType as string;
    }

    const [events, total] = await Promise.all([
      prisma.event.findMany({
        where,
        skip,
        take: limitNum,
        orderBy: { startDate: 'asc' },
        include: {
          ticketTiers: {
            orderBy: { sortOrder: 'asc' },
          },
          organizer: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
        },
      }),
      prisma.event.count({ where }),
    ]);

    const eventsWithCanonicalLineup = await Promise.all(events.map((event) => attachCanonicalLineupToEvent(event)));

    res.json({
      events: eventsWithCanonicalLineup.map((event) => withDerivedStatus(event)),
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        totalPages: Math.ceil(total / limitNum),
      },
    });
  } catch (error) {
    console.error('Get events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getEventYears = async (_req: Request, res: Response): Promise<void> => {
  try {
    const rows = await prisma.$queryRaw<Array<{ year: number; count: number }>>`
      SELECT EXTRACT(YEAR FROM "startDate")::int AS "year", COUNT(*)::int AS "count"
      FROM "events"
      GROUP BY 1
      ORDER BY 1 DESC
    `;
    res.json({ years: rows });
  } catch (error) {
    console.error('Get event years error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const searchEventTimezones = async (req: Request, res: Response): Promise<void> => {
  try {
    const query = String(req.query.q || req.query.query || '').trim();
    if (!query) {
      res.json({
        items: [],
        query: '',
      });
      return;
    }

    const items = searchEventTimezonesByCity(query, req.query.limit);
    res.json({
      items,
      query,
    });
  } catch (error) {
    console.error('Search event timezones error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getMyEvents = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const events = await prisma.event.findMany({
      where: { organizerId: userId },
      orderBy: { createdAt: 'desc' },
      include: {
        ticketTiers: {
          orderBy: { sortOrder: 'asc' },
        },
        organizer: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
    });

    const eventsWithCanonicalLineup = await Promise.all(events.map((event) => attachCanonicalLineupToEvent(event)));

    res.json({ events: eventsWithCanonicalLineup.map((event) => withDerivedStatus(event)) });
  } catch (error) {
    console.error('Get my events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getEvent = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const event = await prisma.event.findUnique({
      where: { id: id as string },
      include: {
        ticketTiers: {
          orderBy: { sortOrder: 'asc' },
        },
        organizer: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!event) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    res.json(withDerivedStatus(await attachCanonicalLineupToEvent(event)));
  } catch (error) {
    console.error('Get event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const createEvent = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    const role = req.user?.role;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    validateEventAdminContractPayload(req.body, 'create');

    const requestBody = req.body as Record<string, unknown>;
    const {
      name,
      slug,
      coverImageUrl,
      lineupImageUrl,
      cityI18n,
      countryI18n,
      manualLocation,
      locationPoint,
      latitude,
      longitude,
      startDate,
      endDate,
      timeZone,
      startTime,
      endTime,
      dayRolloverHour,
      ticketPriceMin,
      ticketPriceMax,
      ticketTiers,
      lineupSlots,
    } = req.body;
    const wikiFestivalId = normalizeOptionalNullableTextField(requestBody, 'wikiFestivalId');
    const description = normalizeOptionalNullableTextField(requestBody, 'description');
    const eventType = normalizeOptionalNullableTextField(requestBody, 'eventType');
    const organizerName = normalizeOptionalNullableTextField(requestBody, 'organizerName');
    const sourceEventUrl = normalizeOptionalNullableTextField(requestBody, 'sourceEventUrl');
    const sourceProvider = normalizeOptionalNullableTextField(requestBody, 'sourceProvider');
    const city = normalizeOptionalNullableTextField(requestBody, 'city');
    const country = normalizeOptionalNullableTextField(requestBody, 'country');
    const ticketUrl = normalizeOptionalNullableTextField(requestBody, 'ticketUrl');
    const ticketCurrency = normalizeOptionalNullableTextField(requestBody, 'ticketCurrency');
    const ticketNotes = normalizeOptionalNullableTextField(requestBody, 'ticketNotes');
    const normalizedOfficialWebsite = normalizeOptionalNullableTextField(requestBody, 'officialWebsite');
    const referenceLinks = normalizeOptionalStringArrayField(requestBody, 'referenceLinks');
    const socialLinks = normalizeOptionalJsonField(requestBody, 'socialLinks');
    const stageOrder = normalizeStageOrder(requestBody.stageOrder);

    if (!name || !startDate || !endDate) {
      res.status(400).json({ error: 'Name, startDate, and endDate are required' });
      return;
    }

    if (!isValidEventTimeZone(timeZone)) {
      res.status(400).json({ error: 'Valid event timeZone is required' });
      return;
    }

    if (role !== 'admin' && role !== 'operator') {
      const submission = await prisma.contentSubmission.create({
        data: {
          submitterId: userId,
          entityType: 'event',
          title: String(name).trim(),
          payload: req.body,
          status: 'pending',
        },
      });
      res.status(202).json({
        message: '活动信息已提交审核，管理员审核通过后才会入库',
        submission,
      });
      return;
    }

    const desiredSlug = slug || slugify(name);
    const existingEvent = await prisma.event.findUnique({
      where: { slug: desiredSlug },
    });

    if (existingEvent) {
      res.status(409).json({ error: 'Event with this slug already exists' });
      return;
    }

    const normalizedTicketTiers = normalizeTicketTiers(ticketTiers);
    const normalizedTimeZone = normalizeEventTimeZone(timeZone);
    const submittedTimeZoneSelectionError = validateSubmittedEventTimezoneSelection(requestBody, normalizedTimeZone);
    if (submittedTimeZoneSelectionError) {
      res.status(400).json({ error: submittedTimeZoneSelectionError });
      return;
    }
    const normalizedStartTime = normalizeEventClockTime(startTime, EVENT_DEFAULT_START_TIME);
    const normalizedEndTime = normalizeEventClockTime(endTime, EVENT_DEFAULT_END_TIME);
    const parsedStartDateInput = parseEventDateInput(startDate, normalizedTimeZone, 'start', normalizedStartTime);
    const parsedEndDateInput = parseEventDateInput(endDate, normalizedTimeZone, 'end', normalizedEndTime);
    if (!parsedStartDateInput || !parsedEndDateInput) {
      res.status(400).json({ error: 'Invalid event date range' });
      return;
    }
    const parsedStartDate = normalizeEventStartDate(parsedStartDateInput, normalizedTimeZone);
    const parsedEndDate = normalizeEventEndDate(parsedEndDateInput, normalizedTimeZone);
    const normalizedDayRolloverHour = normalizeDayRolloverHour(dayRolloverHour, 6);
    const scheduleContext = normalizeSubmittedEventScheduleContext(req.body as Record<string, unknown>);
    const normalizedSlots = normalizeSubmittedTimetableSlots(lineupSlots, scheduleContext);
    const normalizedLineupArtists = normalizeLineupArtists(
      req.body.lineupArtists,
      normalizedSlots.map((slot) => ({
        djId: slot.djId ?? undefined,
        memberDjIds: slot.memberDjIds ?? [],
        memberNames: [],
        festivalDayIndex: null,
        djName: slot.djName,
        stageName: slot.stageName ?? undefined,
        sortOrder: slot.sortOrder,
        startTime: slot.startTime.toISOString(),
        endTime: slot.endTime.toISOString(),
      }))
    );
    const normalizedNameI18n = normalizeOptionalTriTextJson(req.body.nameI18n);
    const normalizedDescriptionI18n = normalizeOptionalTriTextJson(req.body.descriptionI18n);
    const normalizedCityI18n = normalizeOptionalTriTextJson(cityI18n);
    const normalizedCountryI18n = normalizeOptionalTriTextJson(countryI18n);
    const normalizedAddressPayloads = normalizeEventAddressPayloads({
      manualLocation,
      locationPoint,
      cityI18n: normalizedCityI18n,
      countryI18n: normalizedCountryI18n,
    });
    const resolvedEventTruth = resolveEventTruth({
      isCancelled: requestBody.isCancelled,
      visibility: requestBody.visibility,
    });

    const event = await prisma.$transaction(async (tx) => {
      const created = await tx.event.create({
        data: {
          organizerId: userId,
          wikiFestivalId: wikiFestivalId ?? undefined,
          name,
          slug: desiredSlug,
          description: description ?? undefined,
          nameI18n: normalizedNameI18n,
          descriptionI18n: normalizedDescriptionI18n,
          coverImageUrl,
          lineupImageUrl,
          eventType: eventType ?? undefined,
          organizerName: organizerName ?? undefined,
          referenceLinks: referenceLinks ?? undefined,
          socialLinks: socialLinks ?? undefined,
          sourceProvider: sourceProvider ?? undefined,
          sourceEventUrl: sourceEventUrl ?? undefined,
          city: city ?? undefined,
          cityI18n: normalizedCityI18n,
          country: country ?? undefined,
          countryI18n: normalizedCountryI18n,
          manualLocation: normalizedAddressPayloads.manualLocation,
          locationPoint: normalizedAddressPayloads.locationPoint,
          latitude: toNumberOrNull(latitude),
          longitude: toNumberOrNull(longitude),
          startDate: parsedStartDate,
          endDate: parsedEndDate,
          timeZone: normalizedTimeZone,
          startTime: normalizedStartTime,
          endTime: normalizedEndTime,
          dayRolloverHour: normalizedDayRolloverHour,
          isCancelled: resolvedEventTruth.isCancelled,
          visibility: resolvedEventTruth.visibility,
          ticketUrl: ticketUrl ?? undefined,
          ticketPriceMin: toNumberOrNull(ticketPriceMin),
          ticketPriceMax: toNumberOrNull(ticketPriceMax),
          ticketCurrency: ticketCurrency ?? undefined,
          ticketNotes: ticketNotes ?? undefined,
          ticketTiers: normalizedTicketTiers.length
            ? {
                create: normalizedTicketTiers.map((tier, index) => ({
                  name: String(tier.name).trim(),
                  price: Number(tier.price),
                  currency: tier.currency || ticketCurrency || null,
                  sortOrder: tier.sortOrder ?? index + 1,
                })),
              }
            : undefined,
          officialWebsite: normalizedOfficialWebsite ?? undefined,
        },
      });
      await syncStructuredEventSchedule(tx, created.id, scheduleContext);
      await syncCanonicalEventLineupAndTimetable(
        tx,
        created.id,
        normalizedSlots,
        normalizedLineupArtists,
        stageOrder
      );
      const persisted = await tx.event.findUniqueOrThrow({
        where: { id: created.id },
        select: {
          id: true,
          name: true,
          coverImageUrl: true,
          revision: true,
        },
      });
      await recordEventContribution(tx, {
        entityId: persisted.id,
        userId,
        title: persisted.name,
        coverImageUrl: persisted.coverImageUrl ?? null,
        role: 'creator',
        actionType: 'create',
        source: 'direct_commit',
        approvedAt: new Date(),
        versionAfter: persisted.revision ?? null,
        changeSummary: null,
      });
      return tx.event.findUniqueOrThrow({
        where: { id: created.id },
        include: {
          ticketTiers: {
            orderBy: { sortOrder: 'asc' },
          },
          organizer: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
        },
      });
    }, { timeout: 20_000, maxWait: 10_000 });

    res.status(201).json(withDerivedStatus(await attachCanonicalLineupToEvent(event)));
  } catch (error) {
    if (
      error instanceof EventInputValidationError
      || error instanceof EventSubmissionValidationError
      || error instanceof EventAdminContractGuardrailError
    ) {
      res.status(400).json({ error: error.message });
      return;
    }
    console.error('Create event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const updateEvent = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const userId = req.user?.userId;
    const role = req.user?.role;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    validateEventAdminContractPayload(req.body, 'update');

    const {
      name,
      slug,
      coverImageUrl,
      lineupImageUrl,
      cityI18n,
      countryI18n,
      manualLocation,
      locationPoint,
      latitude,
      longitude,
      startDate,
      endDate,
      timeZone,
      startTime,
      endTime,
      dayRolloverHour,
      ticketPriceMin,
      ticketPriceMax,
      ticketTiers,
      lineupSlots,
    } = req.body;
    const requestBody = req.body as Record<string, unknown>;
    const expectedEventRevision = entityChangeService.parseExpectedRevision(
      requestBody.expectedRevision ?? requestBody.baseRevision ?? requestBody.revision
    );
    const hasCoverImageUrl = hasOwn(requestBody, 'coverImageUrl');
    const hasLineupImageUrl = hasOwn(requestBody, 'lineupImageUrl');
    const clearCityI18n = requestBody.clearCityI18n === true;
    const clearCountryI18n = requestBody.clearCountryI18n === true;
    const clearWikiFestivalId = requestBody.clearWikiFestivalId === true;
    const clearManualLocation = requestBody.clearManualLocation === true;
    const clearLocationPoint = requestBody.clearLocationPoint === true;
    const clearLatitude = requestBody.clearLatitude === true;
    const clearLongitude = requestBody.clearLongitude === true;
    const clearStageOrder = requestBody.clearStageOrder === true;
    const clearLineupSlots = requestBody.clearLineupSlots === true;
    const clearSocialLinks = requestBody.clearSocialLinks === true;
    const wikiFestivalId = normalizeOptionalNullableTextField(requestBody, 'wikiFestivalId');
    const description = normalizeOptionalNullableTextField(requestBody, 'description');
    const eventType = normalizeOptionalNullableTextField(requestBody, 'eventType');
    const organizerName = normalizeOptionalNullableTextField(requestBody, 'organizerName');
    const sourceEventUrl = normalizeOptionalNullableTextField(requestBody, 'sourceEventUrl');
    const sourceProvider = normalizeOptionalNullableTextField(requestBody, 'sourceProvider');
    const city = normalizeOptionalNullableTextField(requestBody, 'city');
    const country = normalizeOptionalNullableTextField(requestBody, 'country');
    const ticketUrl = normalizeOptionalNullableTextField(requestBody, 'ticketUrl');
    const ticketCurrency = normalizeOptionalNullableTextField(requestBody, 'ticketCurrency');
    const ticketNotes = normalizeOptionalNullableTextField(requestBody, 'ticketNotes');
    const normalizedOfficialWebsite = normalizeOptionalNullableTextField(requestBody, 'officialWebsite');
    const referenceLinks = normalizeOptionalStringArrayField(requestBody, 'referenceLinks');
    const socialLinks = normalizeOptionalJsonField(requestBody, 'socialLinks');
    const stageOrder = clearStageOrder ? [] : normalizeStageOrder(requestBody.stageOrder);

    const existing = await prisma.event.findUnique({
      where: { id: id as string },
      select: {
        id: true,
        organizerId: true,
        startDate: true,
        endDate: true,
        timeZone: true,
        startTime: true,
        endTime: true,
        dayRolloverHour: true,
        isCancelled: true,
        visibility: true,
        revision: true,
      },
    });
    if (!existing) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    if (role !== 'admin' && existing.organizerId !== userId) {
      res.status(403).json({ error: 'You can only edit your own event' });
      return;
    }
    const beforeChangeSnapshot = await entityChangeService.captureSnapshot({
      entityType: 'event',
      entityId: id as string,
    });
    const currentEventRevision = beforeChangeSnapshot?.revision ?? existing.revision;
    entityChangeService.assertRevisionMatch({
      entityType: 'event',
      entityId: id as string,
      expectedRevision: expectedEventRevision,
      currentRevision: currentEventRevision,
      message: '活动在你编辑期间已被更新，请刷新最新内容后重新提交',
    });

    if (timeZone !== undefined && !isValidEventTimeZone(timeZone)) {
      res.status(400).json({ error: 'Valid event timeZone is required' });
      return;
    }
    const nextTimeZone = timeZone !== undefined
      ? normalizeEventTimeZone(timeZone, existing.timeZone ?? DEFAULT_EVENT_TIME_ZONE)
      : normalizeEventTimeZone(existing.timeZone ?? DEFAULT_EVENT_TIME_ZONE);
    if (timeZone !== undefined) {
      const submittedTimeZoneSelectionError = validateSubmittedEventTimezoneSelection(requestBody, nextTimeZone);
      if (submittedTimeZoneSelectionError) {
        res.status(400).json({ error: submittedTimeZoneSelectionError });
        return;
      }
    }
    const nextStartTime = startTime !== undefined
      ? normalizeEventClockTime(startTime, EVENT_DEFAULT_START_TIME)
      : normalizeEventClockTime(existing.startTime, EVENT_DEFAULT_START_TIME);
    const nextEndTime = endTime !== undefined
      ? normalizeEventClockTime(endTime, EVENT_DEFAULT_END_TIME)
      : normalizeEventClockTime(existing.endTime, EVENT_DEFAULT_END_TIME);
    const nextStartDateInput = startDate ? parseEventDateInput(startDate, nextTimeZone, 'start', nextStartTime) : null;
    if (startDate && !nextStartDateInput) {
      res.status(400).json({ error: 'Invalid startDate' });
      return;
    }
    const nextEndDateInput = endDate ? parseEventDateInput(endDate, nextTimeZone, 'end', nextEndTime) : null;
    if (endDate && !nextEndDateInput) {
      res.status(400).json({ error: 'Invalid endDate' });
      return;
    }
    const nextStartDate = nextStartDateInput ? normalizeEventStartDate(nextStartDateInput, nextTimeZone) : null;
    const nextEndDate = nextEndDateInput ? normalizeEventEndDate(nextEndDateInput, nextTimeZone) : null;
    const effectiveStartDate = nextStartDate ?? existing.startDate;
    const effectiveEndDate = nextEndDate ?? existing.endDate;
    const nextDayRolloverHour = dayRolloverHour !== undefined
      ? normalizeDayRolloverHour(dayRolloverHour, existing.dayRolloverHour ?? 6)
      : (existing.dayRolloverHour ?? 6);
    const hasStructuredSchedulePayload =
      !!requestBody.schedule
      && typeof requestBody.schedule === 'object'
      && !Array.isArray(requestBody.schedule)
      && Array.isArray(requestBody.weeks)
      && Array.isArray(requestBody.eventDays);
    const structuredSchedulePayload: Record<string, unknown> = hasStructuredSchedulePayload
      ? requestBody
      : {
          ...requestBody,
          schedule: {
            mode: requestBody.scheduleMode ?? (requestBody.schedule as Record<string, unknown> | undefined)?.mode ?? 'single_day',
            timeZone: nextTimeZone,
            dayRolloverHour: nextDayRolloverHour,
          },
          weeks: [
            {
              weekIndex: 1,
              label: null,
              startDate: effectiveStartDate,
              endDate: effectiveEndDate,
              sortOrder: 1,
            },
          ],
          eventDays: Array.from({ length: Math.max(1, diffEventDays(effectiveStartDate, effectiveEndDate, nextTimeZone) + 1) }).map((_, index) => {
            const date = new Date(effectiveStartDate.getTime() + index * 86_400_000);
            return {
              eventDayId: `d${index + 1}`,
              weekIndex: 1,
              dayIndexInWeek: index + 1,
              overallDayIndex: index + 1,
              label: null,
              weekday: null,
              date,
              sortOrder: index + 1,
            };
          }),
        };
    const scheduleContext = normalizeSubmittedEventScheduleContext(structuredSchedulePayload);
    const normalizedSlots = Array.isArray(lineupSlots)
      ? normalizeSubmittedTimetableSlots(lineupSlots, scheduleContext)
      : [];
    const normalizedLineupArtists = normalizeLineupArtists(
      req.body.lineupArtists,
      normalizedSlots.map((slot) => ({
        djId: slot.djId ?? undefined,
        memberDjIds: slot.memberDjIds ?? [],
        memberNames: [],
        festivalDayIndex: null,
        djName: slot.djName,
        stageName: slot.stageName ?? undefined,
        sortOrder: slot.sortOrder,
        startTime: slot.startTime.toISOString(),
        endTime: slot.endTime.toISOString(),
      }))
    );
    const normalizedTicketTiers = normalizeTicketTiers(ticketTiers);
    const shouldRebaseExistingLineupSlots =
      !Array.isArray(lineupSlots)
      && (startDate !== undefined || dayRolloverHour !== undefined || timeZone !== undefined)
      && (await loadCanonicalEventLineupSnapshot(prisma, id as string)).slots.length > 0;
    const shouldSyncLineupArtists =
      Array.isArray(req.body.lineupArtists)
      || Array.isArray(lineupSlots)
      || Array.isArray(requestBody.stageOrder)
      || clearLineupSlots
      || clearStageOrder;
    const normalizedNameI18n = normalizeOptionalTriTextJson(req.body.nameI18n);
    const normalizedDescriptionI18n = normalizeOptionalTriTextJson(req.body.descriptionI18n);
    const normalizedCityI18n = normalizeOptionalTriTextJson(cityI18n);
    const normalizedCountryI18n = normalizeOptionalTriTextJson(countryI18n);
    const normalizedAddressPayloads = normalizeEventAddressPayloads({
      manualLocation,
      locationPoint,
      cityI18n: normalizedCityI18n,
      countryI18n: normalizedCountryI18n,
    });
    const resolvedEventTruth = resolveEventTruth({
      isCancelled: hasOwn(requestBody, 'isCancelled') ? requestBody.isCancelled : existing.isCancelled,
      visibility: hasOwn(requestBody, 'visibility') ? requestBody.visibility : existing.visibility,
    });

    await prisma.$transaction(async (tx) => {
      try {
        await tx.event.update({
          where: { id: id as string, revision: currentEventRevision },
          data: {
            name: name ?? undefined,
            slug: slug ?? undefined,
            wikiFestivalId: clearWikiFestivalId ? null : wikiFestivalId,
            description: description ?? undefined,
            nameI18n: req.body.nameI18n !== undefined ? (normalizedNameI18n ?? Prisma.DbNull) : undefined,
            descriptionI18n: req.body.descriptionI18n !== undefined ? (normalizedDescriptionI18n ?? Prisma.DbNull) : undefined,
            coverImageUrl: hasCoverImageUrl ? (typeof coverImageUrl === 'string' && coverImageUrl.trim() ? coverImageUrl.trim() : null) : undefined,
            lineupImageUrl: hasLineupImageUrl ? (typeof lineupImageUrl === 'string' && lineupImageUrl.trim() ? lineupImageUrl.trim() : null) : undefined,
            eventType: eventType ?? undefined,
            organizerName: organizerName ?? undefined,
            referenceLinks: referenceLinks !== undefined ? referenceLinks : undefined,
            socialLinks: clearSocialLinks ? Prisma.JsonNull : socialLinks,
            sourceProvider: sourceProvider,
            sourceEventUrl: sourceEventUrl,
            city: city ?? undefined,
            cityI18n: clearCityI18n ? Prisma.DbNull : cityI18n !== undefined ? (normalizedCityI18n ?? Prisma.DbNull) : undefined,
            country: country ?? undefined,
            countryI18n: clearCountryI18n ? Prisma.DbNull : countryI18n !== undefined ? (normalizedCountryI18n ?? Prisma.DbNull) : undefined,
            manualLocation: clearManualLocation
              ? Prisma.JsonNull
              : hasOwn(requestBody, 'manualLocation')
                ? (normalizedAddressPayloads.manualLocation ?? Prisma.JsonNull)
                : undefined,
            locationPoint: clearLocationPoint
              ? Prisma.JsonNull
              : hasOwn(requestBody, 'locationPoint')
                ? (normalizedAddressPayloads.locationPoint ?? Prisma.JsonNull)
                : undefined,
            latitude: clearLatitude ? null : hasOwn(requestBody, 'latitude') ? toNumberOrNull(latitude) : undefined,
            longitude: clearLongitude ? null : hasOwn(requestBody, 'longitude') ? toNumberOrNull(longitude) : undefined,
            startDate: startDate ? nextStartDate ?? undefined : undefined,
            endDate: endDate ? nextEndDate ?? undefined : undefined,
            timeZone: timeZone !== undefined ? nextTimeZone : undefined,
            startTime: startTime !== undefined ? nextStartTime : undefined,
            endTime: endTime !== undefined ? nextEndTime : undefined,
            dayRolloverHour: dayRolloverHour !== undefined ? nextDayRolloverHour : undefined,
            ticketUrl: ticketUrl ?? undefined,
            ticketPriceMin: ticketPriceMin !== undefined ? toNumberOrNull(ticketPriceMin) : undefined,
            ticketPriceMax: ticketPriceMax !== undefined ? toNumberOrNull(ticketPriceMax) : undefined,
            ticketCurrency: ticketCurrency ?? undefined,
            ticketNotes: ticketNotes ?? undefined,
            ticketTiers: Array.isArray(ticketTiers)
              ? {
                  deleteMany: {},
                  create: normalizedTicketTiers.map((tier, index) => ({
                    name: String(tier.name).trim(),
                    price: Number(tier.price),
                    currency: tier.currency || ticketCurrency || null,
                    sortOrder: tier.sortOrder ?? index + 1,
                  })),
                }
              : undefined,
            officialWebsite: normalizedOfficialWebsite ?? undefined,
            isCancelled: resolvedEventTruth.isCancelled,
            visibility: resolvedEventTruth.visibility,
            revision: { increment: 1 },
          },
        });
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2025') {
          const current = await tx.event.findUnique({
            where: { id: id as string },
            select: { revision: true },
          });
          throw new EntityChangeRevisionConflictError(
            '活动在你编辑期间已被更新，请刷新最新内容后重新提交',
            {
              entityType: 'event',
              entityId: id as string,
              expectedRevision: currentEventRevision,
              currentRevision: current?.revision ?? null,
            }
          );
        }
        throw error;
      }
      await syncStructuredEventSchedule(tx, id as string, scheduleContext);
      if (shouldSyncLineupArtists) {
        await syncCanonicalEventLineupAndTimetable(
          tx,
          id as string,
          normalizedSlots,
          normalizedLineupArtists,
          stageOrder
        );
      }
      const persisted = await tx.event.findUniqueOrThrow({
        where: { id: id as string },
        select: {
          id: true,
          name: true,
          coverImageUrl: true,
          revision: true,
        },
      });
      await recordEventContribution(tx, {
        entityId: persisted.id,
        userId,
        title: persisted.name,
        coverImageUrl: persisted.coverImageUrl ?? null,
        role: 'editor',
        actionType: 'edit',
        source: 'direct_commit',
        approvedAt: new Date(),
        versionAfter: persisted.revision ?? null,
        changeSummary: null,
      });
    }, { timeout: 20_000, maxWait: 10_000 });

    if (shouldRebaseExistingLineupSlots) {
      await prisma.$transaction(async (tx) => {
        const snapshot = await loadCanonicalEventLineupSnapshot(tx, id as string);
        const rebasedSlots = rebaseExistingLineupSlotsToEventStart(
          snapshot.slots.map((slot) => ({
            id: slot.id || '',
            festivalDayIndex: slot.festivalDayIndex,
            startTime: slot.startTime,
            endTime: slot.endTime,
          })),
          existing.startDate,
          effectiveStartDate,
          nextDayRolloverHour,
          existing.timeZone ?? DEFAULT_EVENT_TIME_ZONE,
          nextTimeZone
        );
        await syncCanonicalEventLineupAndTimetable(
          tx,
          id as string,
          snapshot.slots.map((slot) => {
            const rebased = rebasedSlots.find((item) => item.id === slot.id);
            return rebased
              ? { ...slot, festivalDayIndex: null, startTime: rebased.startTime, endTime: rebased.endTime }
              : slot;
          }),
          snapshot.artists
        );
      }, { timeout: 20_000, maxWait: 10_000 });
    }

    const event = await prisma.event.findUnique({
      where: { id: id as string },
      include: {
        ticketTiers: {
          orderBy: { sortOrder: 'asc' },
        },
        organizer: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!event) {
      res.status(404).json({ error: 'Event not found after update' });
      return;
    }

    const afterChangeSnapshot = await entityChangeService.captureSnapshot({
      entityType: 'event',
      entityId: id as string,
    });
    const change = await entityChangeService.diffSnapshots({
      entityType: 'event',
      entityId: id as string,
      operationType: 'update',
      before: beforeChangeSnapshot,
      after: afterChangeSnapshot,
    });
    const changeLog = await entityChangeService.persistChange({
      result: change,
      snapshots: {
        before: beforeChangeSnapshot,
        after: afterChangeSnapshot,
      },
      actorId: userId,
      actorRole: role ?? null,
      source: 'event_admin_api',
      sourceRoute: 'PUT /api/events/:id',
    });
    const eventWithLineup = withDerivedStatus(await attachCanonicalLineupToEvent(event));

    res.json({
      ...eventWithLineup,
      change: entityChangeService.toResponse({ change, changeLog }),
    });
  } catch (error) {
    if (
      error instanceof EventInputValidationError
      || error instanceof EventSubmissionValidationError
      || error instanceof EventAdminContractGuardrailError
    ) {
      res.status(400).json({ error: error.message });
      return;
    }
    if (error instanceof EntityChangeInvalidRevisionError) {
      res.status(400).json({
        error: error.message,
        code: error.code,
        details: error.details,
      });
      return;
    }
    if (error instanceof EntityChangeRevisionConflictError) {
      res.status(409).json({
        error: error.message,
        code: error.code,
        details: error.details,
      });
      return;
    }
    console.error('Update event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const deleteEvent = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const userId = req.user?.userId;
    const role = req.user?.role;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const existing = await prisma.event.findUnique({
      where: { id: id as string },
      select: { id: true, organizerId: true, coverImageUrl: true, lineupImageUrl: true, imageAssets: true },
    });
    if (!existing) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    if (role !== 'admin' && existing.organizerId !== userId) {
      res.status(403).json({ error: 'You can only delete your own event' });
      return;
    }

    await prisma.event.delete({
      where: { id: id as string },
    });
    await mediaAssetService.markDeletedByUrl(existing.coverImageUrl);
    await mediaAssetService.markDeletedByUrl(existing.lineupImageUrl);
    const imageAssets = Array.isArray(existing.imageAssets) ? existing.imageAssets : [];
    for (const asset of imageAssets) {
      if (asset && typeof asset === 'object' && 'url' in asset) {
        await mediaAssetService.markDeletedByUrl((asset as { url?: unknown }).url as string | null | undefined);
      }
    }

    res.status(204).send();
  } catch (error) {
    console.error('Delete event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const uploadEventImage = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    if (!file.buffer) {
      res.status(400).json({ error: 'Invalid upload payload' });
      return;
    }

    if (!isObjectStorageConfigured()) {
      res.status(503).json({ error: 'Object storage is not configured for uploads' });
      return;
    }

    const uploaded = await uploadBufferToObjectStorage({
      buffer: file.buffer,
      mimeType: file.mimetype || 'image/jpeg',
      objectKey: buildMediaObjectKey(
        process.env.OSS_EVENTS_PREFIX || 'wen-jasonlee/events',
        (req.body?.eventId as string | undefined) || 'legacy-api',
        (req.body?.usage as string | undefined) || 'image',
        file.originalname || 'image.jpg',
        file.mimetype || 'image/jpeg'
      ),
    });
    const asset = await mediaAssetService.register({
      ownerType: 'event',
      ownerId: typeof req.body?.eventId === 'string' ? req.body.eventId : null,
      purpose: typeof req.body?.usage === 'string' && req.body.usage.trim() ? req.body.usage.trim() : 'image',
      provider: 'oss',
      objectKey: uploaded.objectKey,
      url: uploaded.url,
      mimeType: file.mimetype || 'image/jpeg',
      sizeBytes: file.size,
      uploadedById: req.user?.userId || null,
      metadata: {
        originalName: file.originalname,
        source: 'api/events/upload-image',
      },
    });

    res.status(201).json({
      assetId: asset.id,
      url: uploaded.url,
      filename: uploaded.objectKey.split('/').pop(),
      originalName: file.originalname,
      size: file.size,
      mimeType: file.mimetype,
    });
  } catch (error) {
    console.error('Upload event image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
