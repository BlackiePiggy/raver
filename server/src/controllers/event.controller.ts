import { Request, Response } from 'express';
import { Prisma, PrismaClient } from '@prisma/client';
import path from 'path';
import { AuthRequest } from '../middleware/auth';
import {
  buildMediaObjectKey,
  isObjectStorageConfigured,
  saveBufferToLocalUploads,
  shouldAllowLocalUploadFallback,
  uploadBufferToObjectStorage,
} from '../services/media-storage.service';
import { mediaAssetService } from '../services/media-asset.service';
import {
  DEFAULT_EVENT_TIME_ZONE,
  diffEventDays,
  getEventHour,
  isValidEventTimeZone,
  normalizeEventTimeZone,
  parseEventDateInput,
  setEventDayAndKeepTime,
  startOfEventDay,
  zonedTimeToUtc,
} from '../utils/event-timezone';
import {
  loadCanonicalEventLineupSnapshot,
  normalizeCanonicalLineupArtists,
  syncCanonicalEventLineupAndTimetable,
} from '../services/event-lineup-canonical.service';

const cityTimezones = require('city-timezones') as {
  lookupViaCity: (city: string) => unknown[];
  findFromCityStateProvince: (query: string) => unknown[];
};

const prisma = new PrismaClient();

class EventInputValidationError extends Error {}

type RawLineupSlotInput = {
  djId?: string;
  memberDjIds?: Array<string | null>;
  memberNames?: string[];
  festivalDayIndex?: number;
  djName?: string;
  stageName?: string;
  sortOrder?: number;
  startTime?: string;
  endTime?: string;
};

type LineupSlotInput = {
  djId?: string;
  memberDjIds?: Array<string | null>;
  memberNames?: string[];
  festivalDayIndex?: number;
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

const resolveEventStatus = (
  startDate: Date,
  endDate: Date,
  fallbackStatus?: string | null
): 'upcoming' | 'ongoing' | 'ended' | 'cancelled' => {
  const normalizedFallback = typeof fallbackStatus === 'string' ? fallbackStatus.trim().toLowerCase() : '';
  if (normalizedFallback === 'cancelled' || normalizedFallback === 'canceled') {
    return 'cancelled';
  }

  const now = Date.now();
  const start = startDate.getTime();
  const end = endDate.getTime();

  if (Number.isFinite(start) && Number.isFinite(end) && end >= start) {
    if (now < start) return 'upcoming';
    if (now > end) return 'ended';
    return 'ongoing';
  }

  if (normalizedFallback === 'ongoing' || normalizedFallback === 'ended' || normalizedFallback === 'upcoming') {
    return normalizedFallback as 'upcoming' | 'ongoing' | 'ended';
  }
  return 'upcoming';
};

const withDerivedStatus = <T extends { startDate: Date; endDate: Date; status?: string | null }>(event: T) => ({
  ...event,
  status: resolveEventStatus(new Date(event.startDate), new Date(event.endDate), event.status ?? null),
});

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
const normalizeDayRolloverHour = (value: unknown, fallback = 6): number => {
  const numeric = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(numeric)) return fallback;
  const hour = Math.floor(numeric);
  if (hour < 0 || hour > 23) return fallback;
  return hour;
};

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

const applyFestivalDayIndexPreservingSourceWallTime = (
  timeSource: Date,
  eventStartDate: Date,
  festivalDayIndex: number,
  sourceTimeZoneRaw: unknown,
  targetTimeZoneRaw: unknown
): Date => {
  const sourceTimeZone = normalizeEventTimeZone(sourceTimeZoneRaw);
  const targetTimeZone = normalizeEventTimeZone(targetTimeZoneRaw);
  const dateParts = datePartsInTimeZone(eventStartDate, targetTimeZone);
  const timeParts = timePartsInTimeZone(timeSource, sourceTimeZone);
  return zonedTimeToUtc({
    ...dateParts,
    day: dateParts.day + Math.max(0, festivalDayIndex - 1),
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
  dayRolloverHour: number,
  previousTimeZone = DEFAULT_EVENT_TIME_ZONE,
  nextTimeZone = DEFAULT_EVENT_TIME_ZONE
): Array<{ id: string; festivalDayIndex: number; startTime: Date; endTime: Date }> =>
  slots.map((slot) => {
    const festivalDayIndex =
      slot.festivalDayIndex
      ?? inferFestivalDayIndex(slot.startTime, previousEventStartDate, dayRolloverHour, previousTimeZone)
      ?? 1;
    const endDayOffset = Math.max(0, diffEventDays(slot.startTime, slot.endTime, previousTimeZone));
    const startTime = applyFestivalDayIndexPreservingSourceWallTime(
      slot.startTime,
      nextEventStartDate,
      festivalDayIndex,
      previousTimeZone,
      nextTimeZone
    );
    let endTime = applyFestivalDayIndexPreservingSourceWallTime(
      slot.endTime,
      nextEventStartDate,
      festivalDayIndex + endDayOffset,
      previousTimeZone,
      nextTimeZone
    );

    while (endTime < startTime) {
      endTime = new Date(endTime.getTime() + 86_400_000);
    }

    return {
      id: slot.id,
      festivalDayIndex,
      startTime,
      endTime,
    };
  });

const normalizeLineupSlots = (
  slots: unknown,
  eventStartDate: Date,
  dayRolloverHourRaw: unknown = 6,
  timeZoneRaw: unknown = DEFAULT_EVENT_TIME_ZONE
): LineupSlotInput[] => {
  if (!Array.isArray(slots)) {
    return [];
  }

  const dayRolloverHour = normalizeDayRolloverHour(dayRolloverHourRaw, 6);
  const timeZone = normalizeEventTimeZone(timeZoneRaw);
  const safeEventStart = Number.isNaN(eventStartDate.getTime()) ? new Date() : eventStartDate;
  return slots
    .filter((slot) => slot && typeof slot === 'object')
    .map((slot) => slot as RawLineupSlotInput)
    .map((slot, index) => {
      if (slot.startTime === undefined || slot.endTime === undefined) {
        throw new EventInputValidationError(`lineupSlots[${index}] requires startTime and endTime`);
      }
      const parsedStart = parseEventDateInput(slot.startTime, timeZone, 'start');
      const parsedEnd = parseEventDateInput(slot.endTime, timeZone, 'end');
      if (!parsedStart || !parsedEnd) {
        throw new EventInputValidationError(`lineupSlots[${index}] has invalid startTime or endTime`);
      }
      if (parsedStart.getTime() === parsedEnd.getTime()) {
        throw new EventInputValidationError(`lineupSlots[${index}] startTime and endTime cannot be the same`);
      }
      const explicitFestivalDayIndex =
        typeof slot.festivalDayIndex === 'number' && Number.isFinite(slot.festivalDayIndex)
          ? Math.max(1, Math.floor(slot.festivalDayIndex))
          : null;

      let startTime = parsedStart;
      let endTime = parsedEnd >= parsedStart ? parsedEnd : new Date(parsedEnd.getTime() + 86_400_000);

      if (explicitFestivalDayIndex) {
        startTime = applyFestivalDayIndexToDate(startTime, safeEventStart, explicitFestivalDayIndex, timeZone);
        endTime = applyFestivalDayIndexToDate(endTime, safeEventStart, explicitFestivalDayIndex, timeZone);
        if (endTime < startTime) {
          endTime = new Date(endTime.getTime() + 86_400_000);
        }
      }

      const rawDjId = typeof slot.djId === 'string' && slot.djId.trim() ? slot.djId.trim() : '';
      const memberDjIds = Array.isArray(slot.memberDjIds)
        ? slot.memberDjIds.map((id) => {
            const normalized = typeof id === 'string' ? id.trim() : '';
            return normalized && !isLineupDjIdPlaceholder(normalized) ? normalized : null;
          })
        : [];
      const memberNames = Array.isArray(slot.memberNames)
        ? slot.memberNames.map((name) => String(name || '').trim()).filter(Boolean)
        : [];
      const djId = rawDjId && !isLineupDjIdPlaceholder(rawDjId) ? rawDjId : undefined;
      const firstBoundDjId = memberDjIds.find((id) => !!id) || undefined;
      const mergedMemberDjIds = memberDjIds.length
        ? memberDjIds
        : (djId ? [djId] : []);
      const effectiveDjId = djId || firstBoundDjId;
      const festivalDayIndex =
        explicitFestivalDayIndex
        ?? inferFestivalDayIndex(startTime, safeEventStart, dayRolloverHour, timeZone);

      return {
        djId: effectiveDjId,
        memberDjIds: mergedMemberDjIds,
        memberNames,
        festivalDayIndex: festivalDayIndex ?? undefined,
        djName: slot.djName,
        stageName: slot.stageName,
        sortOrder: slot.sortOrder,
        startTime: startTime.toISOString(),
        endTime: endTime.toISOString(),
      };
    })
    .filter((slot) => String(slot.djName || '').trim() || String(slot.djId || '').trim() || (Array.isArray(slot.memberDjIds) && slot.memberDjIds.length > 0));
};

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
    const normalizedStatus = String(status || 'upcoming').trim().toLowerCase() === 'canceled'
      ? 'cancelled'
      : String(status || 'upcoming').trim().toLowerCase();

    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    const where: any = {};
    const now = new Date();
    if (normalizedStatus === 'upcoming') {
      where.startDate = { gt: now };
      where.status = { not: 'cancelled' };
    } else if (normalizedStatus === 'ongoing') {
      where.startDate = { lte: now };
      where.endDate = { gte: now };
      where.status = { not: 'cancelled' };
    } else if (normalizedStatus === 'ended') {
      where.endDate = { lt: now };
      where.status = { not: 'cancelled' };
    } else if (normalizedStatus === 'cancelled') {
      where.status = 'cancelled';
    } else if (normalizedStatus === 'all' || normalizedStatus === '') {
      // no status filter
    } else if (normalizedStatus) {
      where.status = normalizedStatus;
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

    const {
      name,
      slug,
      description,
      coverImageUrl,
      lineupImageUrl,
      eventType,
      organizerName,
      city,
      cityI18n,
      country,
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
      ticketUrl,
      ticketPriceMin,
      ticketPriceMax,
      ticketCurrency,
      ticketNotes,
      ticketTiers,
      officialWebsite,
      lineupSlots,
      status,
    } = req.body;

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
    const submittedTimeZoneSelectionError = validateSubmittedEventTimezoneSelection(req.body as Record<string, unknown>, normalizedTimeZone);
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
    const normalizedSlots = normalizeLineupSlots(lineupSlots, parsedStartDate, normalizedDayRolloverHour, normalizedTimeZone);
    const normalizedLineupArtists = normalizeLineupArtists(req.body.lineupArtists, normalizedSlots);
    const normalizedNameI18n = normalizeOptionalTriTextJson(req.body.nameI18n);
    const normalizedDescriptionI18n = normalizeOptionalTriTextJson(req.body.descriptionI18n);
    const normalizedCityI18n = normalizeOptionalTriTextJson(cityI18n);
    const normalizedCountryI18n = normalizeOptionalTriTextJson(countryI18n);

    const event = await prisma.$transaction(async (tx) => {
      const created = await tx.event.create({
        data: {
          organizerId: userId,
          name,
          slug: desiredSlug,
          description,
          nameI18n: normalizedNameI18n,
          descriptionI18n: normalizedDescriptionI18n,
          coverImageUrl,
          lineupImageUrl,
          eventType,
          organizerName,
          city,
          cityI18n: normalizedCityI18n,
          country,
          countryI18n: normalizedCountryI18n,
          manualLocation,
          locationPoint,
          latitude: toNumberOrNull(latitude),
          longitude: toNumberOrNull(longitude),
          startDate: parsedStartDate,
          endDate: parsedEndDate,
          timeZone: normalizedTimeZone,
          startTime: normalizedStartTime,
          endTime: normalizedEndTime,
          dayRolloverHour: normalizedDayRolloverHour,
          status: resolveEventStatus(parsedStartDate, parsedEndDate, typeof status === 'string' ? status : null),
          ticketUrl,
          ticketPriceMin: toNumberOrNull(ticketPriceMin),
          ticketPriceMax: toNumberOrNull(ticketPriceMax),
          ticketCurrency,
          ticketNotes,
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
          officialWebsite,
        },
      });
      await syncCanonicalEventLineupAndTimetable(
        tx,
        created.id,
        normalizedSlots.map((slot) => ({
          ...slot,
          djId: slot.djId ?? null,
          memberDjIds: slot.memberDjIds ?? [],
          memberNames: slot.memberNames ?? [],
          djName: slot.djName || 'Unknown DJ',
          sortOrder: slot.sortOrder || 0,
          stageName: slot.stageName ?? null,
          festivalDayIndex: slot.festivalDayIndex ?? null,
          startTime: new Date(slot.startTime),
          endTime: new Date(slot.endTime),
        })),
        normalizedLineupArtists
      );
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
    });

    res.status(201).json(withDerivedStatus(await attachCanonicalLineupToEvent(event)));
  } catch (error) {
    if (error instanceof EventInputValidationError) {
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

    const {
      name,
      slug,
      description,
      coverImageUrl,
      lineupImageUrl,
      eventType,
      organizerName,
      city,
      cityI18n,
      country,
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
      ticketUrl,
      ticketPriceMin,
      ticketPriceMax,
      ticketCurrency,
      ticketNotes,
      ticketTiers,
      officialWebsite,
      lineupSlots,
      status,
    } = req.body;

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
        status: true,
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

    if (timeZone !== undefined && !isValidEventTimeZone(timeZone)) {
      res.status(400).json({ error: 'Valid event timeZone is required' });
      return;
    }
    const nextTimeZone = timeZone !== undefined
      ? normalizeEventTimeZone(timeZone, existing.timeZone ?? DEFAULT_EVENT_TIME_ZONE)
      : normalizeEventTimeZone(existing.timeZone ?? DEFAULT_EVENT_TIME_ZONE);
    if (timeZone !== undefined) {
      const submittedTimeZoneSelectionError = validateSubmittedEventTimezoneSelection(req.body as Record<string, unknown>, nextTimeZone);
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
    const normalizedSlots = normalizeLineupSlots(lineupSlots, nextStartDate ?? existing.startDate, nextDayRolloverHour, nextTimeZone);
    const normalizedLineupArtists = normalizeLineupArtists(req.body.lineupArtists, normalizedSlots);
    const normalizedTicketTiers = normalizeTicketTiers(ticketTiers);
    const shouldRebaseExistingLineupSlots =
      !Array.isArray(lineupSlots)
      && (startDate !== undefined || dayRolloverHour !== undefined || timeZone !== undefined)
      && (await loadCanonicalEventLineupSnapshot(prisma, id as string)).slots.length > 0;
    const shouldSyncLineupArtists = Array.isArray(req.body.lineupArtists) || Array.isArray(lineupSlots);
    const normalizedNameI18n = normalizeOptionalTriTextJson(req.body.nameI18n);
    const normalizedDescriptionI18n = normalizeOptionalTriTextJson(req.body.descriptionI18n);
    const normalizedCityI18n = normalizeOptionalTriTextJson(cityI18n);
    const normalizedCountryI18n = normalizeOptionalTriTextJson(countryI18n);

    await prisma.$transaction(async (tx) => {
      await tx.event.update({
        where: { id: id as string },
        data: {
          name: name ?? undefined,
          slug: slug ?? undefined,
          description: description ?? undefined,
          nameI18n: req.body.nameI18n !== undefined ? (normalizedNameI18n ?? Prisma.DbNull) : undefined,
          descriptionI18n: req.body.descriptionI18n !== undefined ? (normalizedDescriptionI18n ?? Prisma.DbNull) : undefined,
          coverImageUrl: coverImageUrl ?? undefined,
          lineupImageUrl: lineupImageUrl ?? undefined,
          eventType: eventType ?? undefined,
          organizerName: organizerName ?? undefined,
          city: city ?? undefined,
          cityI18n: cityI18n !== undefined ? (normalizedCityI18n ?? Prisma.DbNull) : undefined,
          country: country ?? undefined,
          countryI18n: countryI18n !== undefined ? (normalizedCountryI18n ?? Prisma.DbNull) : undefined,
          manualLocation: manualLocation ?? undefined,
          locationPoint: locationPoint ?? undefined,
          latitude: latitude !== undefined ? toNumberOrNull(latitude) : undefined,
          longitude: longitude !== undefined ? toNumberOrNull(longitude) : undefined,
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
          officialWebsite: officialWebsite ?? undefined,
          status: resolveEventStatus(
            effectiveStartDate,
            effectiveEndDate,
            typeof status === 'string' ? status : existing.status
          ),
        },
      });
      if (shouldSyncLineupArtists) {
        await syncCanonicalEventLineupAndTimetable(
          tx,
          id as string,
          normalizedSlots.map((slot) => ({
            ...slot,
            djId: slot.djId ?? null,
            memberDjIds: slot.memberDjIds ?? [],
            memberNames: slot.memberNames ?? [],
            djName: slot.djName || 'Unknown DJ',
            sortOrder: slot.sortOrder || 0,
            stageName: slot.stageName ?? null,
            festivalDayIndex: slot.festivalDayIndex ?? null,
            startTime: new Date(slot.startTime),
            endTime: new Date(slot.endTime),
          })),
          normalizedLineupArtists
        );
      }
    });

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
              ? { ...slot, festivalDayIndex: rebased.festivalDayIndex, startTime: rebased.startTime, endTime: rebased.endTime }
              : slot;
          }),
          snapshot.artists
        );
      });
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

    res.json(withDerivedStatus(await attachCanonicalLineupToEvent(event)));
  } catch (error) {
    if (error instanceof EventInputValidationError) {
      res.status(400).json({ error: error.message });
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

    if (!isObjectStorageConfigured() && !shouldAllowLocalUploadFallback()) {
      res.status(503).json({ error: 'Object storage is not configured for uploads' });
      return;
    }

    const uploaded = isObjectStorageConfigured()
      ? await uploadBufferToObjectStorage({
          buffer: file.buffer,
          mimeType: file.mimetype || 'image/jpeg',
          objectKey: buildMediaObjectKey(
            process.env.OSS_EVENTS_PREFIX || 'wen-jasonlee/events',
            (req.body?.eventId as string | undefined) || 'legacy-api',
            (req.body?.usage as string | undefined) || 'image',
            file.originalname || 'image.jpg',
            file.mimetype || 'image/jpeg'
          ),
        })
      : await saveBufferToLocalUploads({
          buffer: file.buffer,
          localDir: path.join(process.cwd(), 'uploads', 'events'),
          publicSubdir: 'events',
          originalName: file.originalname || 'image.jpg',
          mimeType: file.mimetype || 'image/jpeg',
        });
    const asset = await mediaAssetService.register({
      ownerType: 'event',
      ownerId: typeof req.body?.eventId === 'string' ? req.body.eventId : null,
      purpose: typeof req.body?.usage === 'string' && req.body.usage.trim() ? req.body.usage.trim() : 'image',
      provider: 'objectKey' in uploaded ? 'oss' : 'local',
      objectKey: 'objectKey' in uploaded ? uploaded.objectKey : null,
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
      filename: 'fileName' in uploaded ? uploaded.fileName : uploaded.objectKey.split('/').pop(),
      originalName: file.originalname,
      size: file.size,
      mimeType: file.mimetype,
    });
  } catch (error) {
    console.error('Upload event image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
