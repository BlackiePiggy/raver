'use client';

import Image from 'next/image';
import { useEffect, useMemo, useRef, useState } from 'react';
import OverlayImageViewer, { type OverlayImageViewerAsset } from '@/components/admin/OverlayImageViewer';
import {
  eventStudioApi,
  normalizeEventStudioDateInput,
  syncEventStudioScheduleStructure,
  type EventStudioDraft,
  type EventStudioImageState,
  type EventStudioImageUsage,
  type EventStudioImportJobKind,
  type EventStudioImportJobSnapshot,
  type EventStudioScheduleMode,
  type EventStudioWeekDraft,
} from '@/features/admin-content/event-studio';
import useOverlayBodyLock from '@/hooks/useOverlayBodyLock';

type ImportPanelKind = EventStudioImportJobKind;
type EventStudioAIEntryMode = 'all' | 'single' | 'hidden';

type EventStudioAIActType = 'solo' | 'b2b' | 'b3b';

type EventStudioAIEditableLineupItem = {
  id: string;
  actType: EventStudioAIActType;
  performerNamesText: string;
  displayNameOverrideText: string;
  performerDJIDs: Array<string | null>;
  performerAvatarURLs: Array<string | null>;
  confidence?: number | null;
  notes: string[];
  sortOrder: number;
};

type EventStudioAIEditableTimetableSlot = EventStudioAIEditableLineupItem & {
  eventDayId: string;
  weekIndex: number;
  dayIndexInWeek: number;
  overallDayIndex: number;
  localDate: string;
  dayLabel: string;
  stageName: string;
  startTimeText: string;
  endTimeText: string;
  startDayOffset: number;
  endDayOffset: number;
  unresolvedEventDay: boolean;
  eventDayResolutionReason: string;
  eventDayResolutionConfidence: number | null;
};

type EventStudioAIResultTarget = {
  targetEventDayId: string;
  targetStageName: string;
};

type EventStudioAIDJSearchResult = {
  id: string;
  name?: string | null;
  country?: string | null;
  slug?: string | null;
  avatarUrl?: string | null;
  avatarOriginalUrl?: string | null;
  avatarMediumUrl?: string | null;
  avatarSmallUrl?: string | null;
};

type EventStudioAIPosterEditableResult = {
  name: EventStudioDraft['name'];
  city: EventStudioDraft['city'];
  country: EventStudioDraft['country'];
  detailAddress: EventStudioDraft['detailAddress'];
  venueName: string;
  venueAddress: string;
  sourceProvider: string;
  referenceLinksText: string;
  socialLinksText: string;
  timeZoneIdentifier: string;
  timeZoneDisplayName: string;
  selectedTimeZoneLookup: EventStudioDraft['timeZoneSelection'];
  timeZoneSearchQuery: string;
  startDate: string;
  endDate: string;
  scheduleMode: EventStudioScheduleMode;
  weekRanges: EventStudioWeekDraft[];
  ticketUrl: string;
  ticketCurrency: string;
  ticketNotes: string;
  ticketTiers: EventStudioDraft['ticketTiers'];
  warnings: string[];
  unparsedTexts: string[];
};

type EventStudioAIImportTaskEntry = {
  id: string;
  imageId: string;
  imageFileName: string;
  imageOrigin: EventStudioImageState['origin'];
  jobId: string | null;
  phase: 'preparing' | 'polling' | 'auto_matching' | 'succeeded' | 'failed' | 'cancelled';
  pollStatus: string | null;
  startedAt: number;
  updatedAt: number;
  resultCount: number;
  warningCount: number;
  matchSuccessCount: number;
  matchFailedCount: number;
  message: string;
};

type EventStudioAIMatchSummary = {
  attempted: number;
  matched: number;
  failed: number;
};

type ImportPanelState = {
  kind: ImportPanelKind;
  selectedImageIds: string[];
  running: boolean;
  statusText: string;
  errorText: string | null;
  resultJson: unknown | null;
  posterResult: EventStudioAIPosterEditableResult | null;
  lineupItems: EventStudioAIEditableLineupItem[];
  timetableSlots: EventStudioAIEditableTimetableSlot[];
  selectedTimetableSlotIds: string[];
  targetEventDayId: string;
  targetStageName: string;
  warnings: string[];
  unparsedTexts: string[];
  taskEntries: EventStudioAIImportTaskEntry[];
  autoMatching: boolean;
  autoMatchStartedAt: number | null;
  manualMatchSummary: EventStudioAIMatchSummary | null;
  expandedResultItemIds: string[];
  resultSearchQuery: string;
  warningsExpanded: boolean;
};

const PANEL_ITEMS: Array<{
  kind: ImportPanelKind;
  title: string;
  description: string;
  zones: EventStudioImageUsage[];
}> = [
  {
    kind: 'poster',
    title: 'Poster Import',
    description: 'Recognize core event information, dates, timezone, venue, and ticket details.',
    zones: ['poster', 'cover'],
  },
  {
    kind: 'timetable',
    title: 'Timetable Import',
    description: 'Recognize stages, performers, and set times from timetable images.',
    zones: ['timetable'],
  },
  {
    kind: 'lineup',
    title: 'Lineup Import',
    description: 'Recognize lineup artists from lineup posters and cards.',
    zones: ['lineup'],
  },
];

const aiCompactInputClass =
  'admin-studio-input h-9 min-h-9 rounded-[14px] px-3 py-1.5 text-[13px] leading-5';

const aiCompactSelectClass =
  'admin-studio-select h-9 min-h-9 rounded-[14px] pr-8 text-[13px]';

const aiCompactSelectorChipClass =
  'inline-flex min-w-0 shrink-0 items-center rounded-[14px] border px-3 py-2 text-[13px] font-semibold tracking-[0.01em] transition whitespace-nowrap';

const ALL_EVENT_DAYS_VALUE = '__all_event_days__';
const ALL_STAGES_VALUE = '__all_stages__';

const ACT_TYPE_ITEMS: Array<{ value: EventStudioAIActType; label: string; count: number }> = [
  { value: 'solo', label: 'Solo', count: 1 },
  { value: 'b2b', label: 'B2B', count: 2 },
  { value: 'b3b', label: 'B3B', count: 3 },
];

const firstFilledText = (...values: Array<string | undefined | null>) => {
  for (const value of values) {
    const trimmed = String(value || '').trim();
    if (trimmed) return trimmed;
  }
  return '';
};

const safeString = (value: unknown): string => (typeof value === 'string' ? value.trim() : '');

const safeNumber = (value: unknown, fallback = 0): number => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const mergeUniqueStrings = (base: string[], incoming: string[]): string[] => {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const value of [...base, ...incoming]) {
    const trimmed = safeString(value);
    if (!trimmed) continue;
    const key = trimmed.toLocaleLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(trimmed);
  }
  return result;
};

const inferActTypeFromPerformerCount = (performerCount = 0): EventStudioAIActType => {
  if (performerCount >= 3) return 'b3b';
  if (performerCount === 2) return 'b2b';
  return 'solo';
};

const normalizeActType = (value: unknown, performerCount = 0): EventStudioAIActType => {
  const normalized = safeString(value).toLowerCase();
  if (normalized === 'b3b') return 'b3b';
  if (normalized === 'b2b') return 'b2b';
  if (normalized === 'solo') return 'solo';
  return inferActTypeFromPerformerCount(performerCount);
};

const actTypePerformerCount = (value: unknown): number =>
  ACT_TYPE_ITEMS.find((item) => item.value === normalizeActType(value))?.count ?? 1;

const splitActNamesByKeyword = (value: string, keyword: 'B2B' | 'B3B'): string[] | null => {
  const trimmed = safeString(value);
  if (!trimmed) return null;
  const token = `__EVENT_STUDIO_${keyword}_TOKEN__`;
  const replaced = trimmed.replace(new RegExp(`\\s*${keyword}\\s*`, 'gi'), token);
  const parts = replaced
    .split(token)
    .map((item) => item.trim())
    .filter(Boolean);
  return parts.length > 1 ? parts : null;
};

const parseExplicitActNamesFromText = (
  value: string
): { actType: EventStudioAIActType; names: string[] } | null => {
  const b3bNames = splitActNamesByKeyword(value, 'B3B');
  if (b3bNames?.length) return { actType: 'b3b', names: b3bNames };
  const b2bNames = splitActNamesByKeyword(value, 'B2B');
  if (b2bNames?.length) return { actType: 'b2b', names: b2bNames };
  return null;
};

const splitPerformerNames = (value: string, preferredActType?: unknown): string[] => {
  const trimmed = safeString(value);
  if (!trimmed) return [];
  const explicit = parseExplicitActNamesFromText(trimmed);
  if (explicit) return explicit.names;

  const actType = normalizeActType(preferredActType);
  if (actType === 'solo') return [trimmed];

  return trimmed
    .split(/\s*(?:\/|,|，|、|\r?\n)\s*/g)
    .map((item) => item.trim())
    .filter(Boolean);
};

const formatPerformerNamesText = (names: string[], actType: EventStudioAIActType): string => {
  const compact = names.map((item) => safeString(item)).filter(Boolean).slice(0, actTypePerformerCount(actType));
  if (!compact.length) return '';
  return actType === 'solo' ? compact[0] : compact.join(' / ');
};

const normalizeDisplayNameOverrideText = (
  value: string,
  names: string[],
  actType: EventStudioAIActType
): string => {
  const trimmed = safeString(value);
  if (!trimmed) return '';
  return trimmed === formatPerformerNamesText(names, actType) ? '' : trimmed;
};

const resolveImportedAct = (input: {
  performerType: unknown;
  performerNames: string[];
  displayName?: unknown;
  rawText?: unknown;
}): { actType: EventStudioAIActType; performerNames: string[] } => {
  const displayName = firstFilledText(input.displayName as string | undefined | null, input.rawText as string | undefined | null);
  const explicitTextAct = parseExplicitActNamesFromText(displayName);
  const performerType = safeString(input.performerType).toLowerCase();

  if (performerType === 'b3b' || explicitTextAct?.actType === 'b3b') {
    const names = input.performerNames.length >= 3 ? input.performerNames : explicitTextAct?.names ?? input.performerNames;
    return {
      actType: 'b3b',
      performerNames: names.slice(0, actTypePerformerCount('b3b')),
    };
  }

  if (performerType === 'b2b' || explicitTextAct?.actType === 'b2b') {
    const names = input.performerNames.length >= 2 ? input.performerNames : explicitTextAct?.names ?? input.performerNames;
    return {
      actType: 'b2b',
      performerNames: names.slice(0, actTypePerformerCount('b2b')),
    };
  }

  const soloName = displayName || input.performerNames.join(' / ');
  return {
    actType: 'solo',
    performerNames: soloName ? [soloName] : [],
  };
};

const editableClockText = (value: unknown): string => {
  const text = safeString(value);
  const isoMatch = text.match(/T(\d{2}:\d{2})/);
  if (isoMatch?.[1]) return isoMatch[1];
  const normalized24Match = text.match(/^(\d{2}):(\d{2})$/);
  if (normalized24Match) return `${normalized24Match[1]}:${normalized24Match[2]}`;
  const looseMatch = text.match(/(\d{1,2}):(\d{2})/);
  if (!looseMatch) return '';
  return `${looseMatch[1].padStart(2, '0')}:${looseMatch[2]}`;
};

const dayOffsetFromClockText = (value: unknown): number => {
  const text = safeString(value);
  const hourMatch = text.match(/(?:T|^)(\d{1,2}):\d{2}/);
  if (!hourMatch) return 0;
  const hour = Number(hourMatch[1]);
  return Number.isFinite(hour) && hour >= 24 ? 1 : 0;
};

const normalizePerformerIds = (ids: unknown, count: number): Array<string | null> => {
  const source = Array.isArray(ids) ? ids : [];
  return Array.from({ length: count }, (_, index) => {
    const trimmed = safeString(source[index]);
    return trimmed || null;
  });
};

const normalizePerformerAvatarURLs = (urls: unknown, count: number): Array<string | null> => {
  const source = Array.isArray(urls) ? urls : [];
  return Array.from({ length: count }, (_, index) => {
    const trimmed = safeString(source[index]);
    return trimmed || null;
  });
};

const normalizeWarnings = (raw: Record<string, any>): string[] =>
  (Array.isArray(raw.warnings) ? raw.warnings : []).map((item) => safeString(item)).filter(Boolean);

const normalizeUnparsedTexts = (raw: Record<string, any>): string[] =>
  (Array.isArray(raw.unparsedTexts ?? raw.unparsed_texts) ? raw.unparsedTexts ?? raw.unparsed_texts : [])
    .map((item: unknown) => safeString(item))
    .filter(Boolean);

const normalizeDJLookupKey = (value: string): string =>
  value
    .trim()
    .toLocaleLowerCase()
    .replace(/\s+/g, ' ');

const normalizeWeekRanges = (raw: unknown, timeZone?: string): EventStudioWeekDraft[] => {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((item, index) => {
      if (!item || typeof item !== 'object') return null;
      const record = item as Record<string, unknown>;
      const startDate = normalizeEventStudioDateInput(safeString(record.startDate ?? record.start_date), timeZone);
      const endDate = normalizeEventStudioDateInput(safeString(record.endDate ?? record.end_date), timeZone);
      if (!startDate || !endDate) return null;
      return {
        id: crypto.randomUUID(),
        weekIndex: Math.max(1, Math.floor(safeNumber(record.weekIndex, index + 1))),
        label: safeString(record.label || record.weekLabel) || `Week ${index + 1}`,
        startDate,
        endDate,
        sortOrder: Math.max(1, Math.floor(safeNumber(record.sortOrder, index + 1))),
      };
    })
    .filter((item): item is EventStudioWeekDraft => item !== null);
};

const normalizeScheduleMode = (value: unknown): EventStudioScheduleMode => {
  const normalized = safeString(value);
  if (normalized === 'multi_week') return 'multi_week';
  if (normalized === 'multi_day') return 'multi_day';
  return 'single_day';
};

const resolvedTimeZoneSelection = (draft: EventStudioDraft, raw: Record<string, any>) => {
  const timeZone = safeString(raw?.timeZone?.ianaName || raw?.timeZone?.iana_name || draft.timeZoneSelection?.timezone);
  if (!timeZone) return draft.timeZoneSelection;
  const displayName = safeString(raw?.timeZone?.displayName || raw?.timeZone?.display_name || timeZone);
  const city = firstFilledText(raw?.cityI18n?.zh, raw?.cityI18n?.en, draft.city.zh, draft.city.en);
  const country = firstFilledText(raw?.countryI18n?.zh, raw?.countryI18n?.en, draft.country.zh, draft.country.en);
  return {
    city,
    cityAscii: city,
    province: '',
    exactProvince: '',
    stateAnsi: '',
    country,
    iso2: '',
    iso3: '',
    timezone: timeZone,
    lat: null,
    lng: null,
    population: null,
    label: `${city || 'Unknown'} / ${timeZone}${displayName && displayName !== timeZone ? ` / ${displayName}` : ''}`,
    matchSource: 'web-ai-import',
  };
};

const parsePosterEditableResult = (
  raw: Record<string, any>,
  draft: EventStudioDraft
): EventStudioAIPosterEditableResult => {
  const schedule = raw.schedule && typeof raw.schedule === 'object' ? (raw.schedule as Record<string, any>) : {};
  const ticketInfo = raw.ticketInfo && typeof raw.ticketInfo === 'object' ? (raw.ticketInfo as Record<string, any>) : {};
  const resolvedTimeZone = safeString(raw.timeZone?.ianaName || raw.timeZone?.iana_name || draft.timeZoneSelection?.timezone);
  const posterWeeks = normalizeWeekRanges(schedule.weekRanges ?? schedule.week_ranges, resolvedTimeZone);
  const ticketTiers = Array.isArray(ticketInfo.tiers)
    ? ticketInfo.tiers
        .map((item: any, index: number) => ({
          id: crypto.randomUUID(),
          name: safeString(item?.name || item?.tierName || item?.title || `Tier ${index + 1}`),
          price: safeString(item?.price),
          currency: safeString(item?.currency || ticketInfo.currency || draft.ticketCurrency).toUpperCase(),
        }))
        .filter((item) => item.name || item.price)
    : draft.ticketTiers;

  return {
    name: {
      ...draft.name,
      zh: safeString(raw.nameI18n?.zh || raw.name_i18n?.zh || draft.name.zh),
      en: safeString(raw.nameI18n?.en || raw.name_i18n?.en || draft.name.en),
      ja: safeString(raw.nameI18n?.ja || raw.name_i18n?.ja || draft.name.ja),
      enFull: safeString(raw.nameI18n?.enFull || raw.name_i18n?.enFull || draft.name.enFull),
    },
    city: {
      ...draft.city,
      zh: safeString(raw.cityI18n?.zh || raw.city_i18n?.zh || draft.city.zh),
      en: safeString(raw.cityI18n?.en || raw.city_i18n?.en || draft.city.en),
      ja: safeString(raw.cityI18n?.ja || raw.city_i18n?.ja || draft.city.ja),
      enFull: safeString(raw.cityI18n?.enFull || raw.city_i18n?.enFull || draft.city.enFull),
    },
    country: {
      ...draft.country,
      zh: safeString(raw.countryI18n?.zh || raw.country_i18n?.zh || draft.country.zh),
      en: safeString(raw.countryI18n?.en || raw.country_i18n?.en || draft.country.en),
      ja: safeString(raw.countryI18n?.ja || raw.country_i18n?.ja || draft.country.ja),
      enFull: safeString(raw.countryI18n?.enFull || raw.country_i18n?.enFull || draft.country.enFull),
    },
    detailAddress: {
      ...draft.detailAddress,
      zh: safeString(raw.detailAddressI18n?.zh || raw.detail_address_i18n?.zh || draft.detailAddress.zh),
      en: safeString(raw.detailAddressI18n?.en || raw.detail_address_i18n?.en || draft.detailAddress.en),
      ja: safeString(raw.detailAddressI18n?.ja || raw.detail_address_i18n?.ja || draft.detailAddress.ja),
      enFull: safeString(raw.detailAddressI18n?.enFull || raw.detail_address_i18n?.enFull || draft.detailAddress.enFull),
    },
    venueName: safeString(raw.venueName || raw.venue_name || draft.venueName),
    venueAddress: safeString(raw.venueAddress || raw.venue_address || draft.venueAddress),
    sourceProvider: safeString(raw.sourceProvider || raw.source_provider || draft.sourceProvider),
    referenceLinksText: Array.isArray(raw.referenceLinks || raw.reference_links)
      ? (raw.referenceLinks || raw.reference_links).map((item: unknown) => safeString(item)).filter(Boolean).join('\n')
      : draft.referenceLinksText,
    socialLinksText:
      raw.socialLinks || raw.social_links ? JSON.stringify(raw.socialLinks || raw.social_links, null, 2) : draft.socialLinksText,
    timeZoneIdentifier: resolvedTimeZone,
    timeZoneDisplayName: safeString(raw.timeZone?.displayName || raw.timeZone?.display_name),
    selectedTimeZoneLookup: null,
    timeZoneSearchQuery: firstFilledText(
      raw.cityI18n?.en,
      raw.city_i18n?.en,
      raw.cityI18n?.zh,
      raw.city_i18n?.zh,
      draft.city.en,
      draft.city.zh
    ),
    startDate: normalizeEventStudioDateInput(safeString(schedule.startDate || schedule.start_date || draft.startDate), resolvedTimeZone),
    endDate: normalizeEventStudioDateInput(safeString(schedule.endDate || schedule.end_date || draft.endDate), resolvedTimeZone),
    scheduleMode: normalizeScheduleMode(schedule.scheduleMode || schedule.schedule_mode || draft.scheduleMode),
    weekRanges: posterWeeks.length ? posterWeeks : draft.weeks,
    ticketUrl: safeString(ticketInfo.ticketUrl || ticketInfo.ticket_url || draft.ticketUrl),
    ticketCurrency: safeString(ticketInfo.currency || draft.ticketCurrency).toUpperCase() || draft.ticketCurrency,
    ticketNotes: safeString(ticketInfo.notes || ticketInfo.ticketNotes || draft.ticketNotes),
    ticketTiers,
    warnings: normalizeWarnings(raw),
    unparsedTexts: normalizeUnparsedTexts(raw),
  };
};

const hasUnresolvedTimetableDay = (slot: EventStudioAIEditableTimetableSlot): boolean =>
  slot.unresolvedEventDay || !slot.eventDayId || !slot.localDate;

const importImageOptions = (draft: EventStudioDraft, kind: ImportPanelKind): EventStudioImageState[] => {
  const readyOnly = (items: EventStudioImageState[]) =>
    items.filter((item) => item.remoteUrl.trim());
  if (kind === 'poster') {
    return readyOnly([...draft.imageZones.poster, ...draft.imageZones.cover]).sort(
      (left, right) => left.sortOrder - right.sortOrder
    );
  }
  return readyOnly([...draft.imageZones[kind]]).sort((left, right) => left.sortOrder - right.sortOrder);
};

const parseLineupEditableItems = (raw: Record<string, any>): EventStudioAIEditableLineupItem[] => {
  const items = Array.isArray(raw.items) ? raw.items : [];
  const parsed: Array<EventStudioAIEditableLineupItem | null> = items
    .slice()
    .sort((left: any, right: any) => safeNumber(left?.order) - safeNumber(right?.order))
    .map((item: any, index: number) => {
      const performerNames = Array.isArray(item?.performerNames)
        ? item.performerNames.map((name: unknown) => safeString(name)).filter(Boolean)
        : [];
      const resolved = resolveImportedAct({
        performerType: item?.performerType,
        performerNames,
        displayName: item?.displayName,
        rawText: item?.rawText,
      });
      const count = actTypePerformerCount(resolved.actType);
      const normalizedNames = resolved.performerNames.slice(0, count);
      if (!normalizedNames.length) return null;
      const defaultDisplayName = formatPerformerNamesText(normalizedNames, resolved.actType);
      const displayNameOverrideText = normalizeDisplayNameOverrideText(
        firstFilledText(item?.displayName, item?.rawText),
        normalizedNames,
        resolved.actType
      );
      return {
        id: crypto.randomUUID(),
        actType: resolved.actType,
        performerNamesText: formatPerformerNamesText(normalizedNames, resolved.actType),
        displayNameOverrideText: displayNameOverrideText || (defaultDisplayName !== firstFilledText(item?.displayName, item?.rawText) ? '' : ''),
        performerDJIDs: normalizePerformerIds(item?.performerDJIDs ?? item?.performerDjIds ?? item?.memberDjIds, count),
        performerAvatarURLs: normalizePerformerAvatarURLs(item?.performerAvatarURLs ?? item?.performerAvatarUrls, count),
        confidence: Number.isFinite(Number(item?.confidence)) ? Number(item.confidence) : null,
        notes: Array.isArray(item?.notes) ? item.notes.map((note: unknown) => safeString(note)).filter(Boolean) : [],
        sortOrder: index + 1,
      };
    });
  return parsed.filter((item): item is EventStudioAIEditableLineupItem => item !== null);
};

const parseTimetableEditableSlots = (
  raw: Record<string, any>,
  draft: EventStudioDraft
): EventStudioAIEditableTimetableSlot[] => {
  const weeks = Array.isArray(raw.weeks) ? raw.weeks : [];
  return weeks.flatMap((week: any) =>
    Array.isArray(week?.days)
      ? week.days.flatMap((day: any) =>
          Array.isArray(day?.stages)
            ? day.stages.flatMap((stage: any) =>
                Array.isArray(stage?.slots)
                  ? stage.slots
                      .map((slot: any, index: number) => {
                        const eventDayRef = day?.eventDayRef || day?.event_day_ref || {};
                        const requestedEventDayId = safeString(eventDayRef.eventDayId || eventDayRef.event_day_id);
                        const requestedDate = normalizeEventStudioDateInput(
                          safeString(eventDayRef.date || day?.dateText || day?.date || ''),
                          draft.timeZoneSelection?.timezone
                        );
                        const requestedOverallDayIndex = safeNumber(eventDayRef.overallDayIndex || eventDayRef.overall_day_index);
                        const resolvedEventDay =
                          draft.eventDays.find((item) => item.eventDayId === requestedEventDayId) ||
                          draft.eventDays.find((item) => item.overallDayIndex === requestedOverallDayIndex) ||
                          draft.eventDays.find((item) => item.date === requestedDate);
                        const rawNames = Array.isArray(slot?.performerNames)
                          ? slot.performerNames.map((name: unknown) => safeString(name)).filter(Boolean)
                          : [];
                        const resolvedAct = resolveImportedAct({
                          performerType: slot?.performerType,
                          performerNames: rawNames,
                          displayName: slot?.displayName,
                          rawText: slot?.rawText,
                        });
                        const count = actTypePerformerCount(resolvedAct.actType);
                        const names = resolvedAct.performerNames.slice(0, count);
                        if (!names.length) return null;
                        const defaultDisplayName = formatPerformerNamesText(names, resolvedAct.actType);
                        const displayNameOverrideText = normalizeDisplayNameOverrideText(
                          firstFilledText(slot?.displayName, slot?.rawText),
                          names,
                          resolvedAct.actType
                        );
                        const startSource =
                          slot?.normalizedStartTime ?? slot?.normalized_start_time ?? slot?.startTimeText ?? slot?.start_time_text;
                        const endSource =
                          slot?.normalizedEndTime ?? slot?.normalized_end_time ?? slot?.endTimeText ?? slot?.end_time_text;
                        return {
                          id: crypto.randomUUID(),
                          eventDayId: resolvedEventDay?.eventDayId || requestedEventDayId,
                          weekIndex: resolvedEventDay?.weekIndex || safeNumber(week?.weekIndex || week?.week_index, 1),
                          dayIndexInWeek: resolvedEventDay?.dayIndexInWeek || safeNumber(day?.dayIndexInWeek || day?.day_index_in_week, 1),
                          overallDayIndex: resolvedEventDay?.overallDayIndex || requestedOverallDayIndex || 1,
                          localDate: resolvedEventDay?.date || requestedDate,
                          dayLabel: safeString(day?.dayLabel || day?.day_label) || resolvedEventDay?.label || '',
                          stageName: safeString(stage?.stageName || stage?.stage_name) || 'Main Stage',
                          actType: resolvedAct.actType,
                          performerNamesText: formatPerformerNamesText(names, resolvedAct.actType),
                          displayNameOverrideText: displayNameOverrideText || (defaultDisplayName !== firstFilledText(slot?.displayName, slot?.rawText) ? '' : ''),
                          performerDJIDs: normalizePerformerIds(slot?.performerDJIDs ?? slot?.performerDjIds ?? slot?.memberDjIds, count),
                          performerAvatarURLs: normalizePerformerAvatarURLs(
                            slot?.performerAvatarURLs ?? slot?.performerAvatarUrls,
                            count
                          ),
                          confidence: Number.isFinite(Number(slot?.confidence)) ? Number(slot.confidence) : null,
                          notes: Array.isArray(slot?.notes) ? slot.notes.map((note: unknown) => safeString(note)).filter(Boolean) : [],
                          startTimeText: editableClockText(startSource),
                          endTimeText: editableClockText(endSource),
                          startDayOffset: dayOffsetFromClockText(startSource),
                          endDayOffset: dayOffsetFromClockText(endSource),
                          sortOrder: Number.isFinite(Number(slot?.orderInStage || slot?.order))
                            ? Math.max(1, Math.floor(Number(slot?.orderInStage || slot?.order)))
                            : index + 1,
                          unresolvedEventDay: !resolvedEventDay,
                          eventDayResolutionReason: safeString(
                            eventDayRef.resolutionReason || eventDayRef.resolution_reason || (!resolvedEventDay ? 'Manual resolution required.' : '')
                          ),
                          eventDayResolutionConfidence: Number.isFinite(Number(eventDayRef.confidence))
                            ? Number(eventDayRef.confidence)
                            : null,
                        };
                      })
                      .filter((item: EventStudioAIEditableTimetableSlot | null): item is EventStudioAIEditableTimetableSlot => item !== null)
                  : []
              )
            : []
        )
      : []
  );
};

const normalizeEditableAct = <T extends EventStudioAIEditableLineupItem | EventStudioAIEditableTimetableSlot>(item: T): T => {
  const actType = normalizeActType(item.actType, splitPerformerNames(item.performerNamesText, item.actType).length);
  const count = actTypePerformerCount(actType);
  const names = splitPerformerNames(item.performerNamesText, actType).slice(0, count);
  return {
    ...item,
    actType,
    performerNamesText: formatPerformerNamesText(names, actType),
    displayNameOverrideText: normalizeDisplayNameOverrideText(item.displayNameOverrideText, names, actType),
    performerDJIDs: normalizePerformerIds(item.performerDJIDs, count),
    performerAvatarURLs: normalizePerformerAvatarURLs(item.performerAvatarURLs, count),
  } as T;
};

const compactEditableAct = <T extends EventStudioAIEditableLineupItem | EventStudioAIEditableTimetableSlot>(item: T): T | null => {
  const normalized = normalizeEditableAct(item);
  const names = splitPerformerNames(normalized.performerNamesText, normalized.actType);
  const performerCount = actTypePerformerCount(normalized.actType);
  const compactNames: string[] = [];
  const compactDjIds: Array<string | null> = [];
  const compactAvatarURLs: Array<string | null> = [];

  for (let index = 0; index < performerCount; index += 1) {
    const name = names[index] || '';
    const djId = normalized.performerDJIDs[index] || null;
    const avatar = normalized.performerAvatarURLs[index] || null;
    if (!name.trim() && !djId) continue;
    compactNames.push(name);
    compactDjIds.push(djId);
    compactAvatarURLs.push(avatar);
  }

  if (!compactNames.length) return null;

  const nextActType = inferActTypeFromPerformerCount(compactNames.length);
  const nextCount = actTypePerformerCount(nextActType);
  return {
    ...normalized,
    actType: nextActType,
    performerNamesText: formatPerformerNamesText(compactNames, nextActType),
    displayNameOverrideText: normalizeDisplayNameOverrideText(normalized.displayNameOverrideText, compactNames, nextActType),
    performerDJIDs: normalizePerformerIds(compactDjIds, nextCount),
    performerAvatarURLs: normalizePerformerAvatarURLs(compactAvatarURLs, nextCount),
  } as T;
};

const compactEditableLineupItems = (items: EventStudioAIEditableLineupItem[]): EventStudioAIEditableLineupItem[] =>
  items
    .map((item) => compactEditableAct(item))
    .filter((item): item is EventStudioAIEditableLineupItem => item !== null)
    .map((item, index) => ({ ...item, sortOrder: index + 1 }));

const compactEditableTimetableSlots = (items: EventStudioAIEditableTimetableSlot[]): EventStudioAIEditableTimetableSlot[] =>
  items
    .map((item) => compactEditableAct(item))
    .filter((item): item is EventStudioAIEditableTimetableSlot => item !== null)
    .map((item, index) => ({ ...item, sortOrder: index + 1 }));

const eventDayTargets = (draft: EventStudioDraft) =>
  draft.eventDays.map((day) => ({
    eventDayId: day.eventDayId,
    label: day.label || `Day ${day.overallDayIndex}`,
    date: day.date,
    weekIndex: day.weekIndex,
    dayIndexInWeek: day.dayIndexInWeek,
    overallDayIndex: day.overallDayIndex,
  }));

const availableStageNames = (draft: EventStudioDraft, currentItems: EventStudioAIEditableTimetableSlot[]): string[] => {
  const seen = new Set<string>();
  const result: string[] = [];
  const push = (value?: string | null) => {
    const trimmed = safeString(value);
    if (!trimmed) return;
    const key = trimmed.toLocaleLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    result.push(trimmed);
  };

  draft.stageOrder.forEach(push);
  currentItems.forEach((slot) => push(slot.stageName));
  if (!result.length) result.push('Main Stage');
  return result;
};

const jobContextForPanel = (draft: EventStudioDraft, kind: ImportPanelKind) => {
  if (kind === 'poster') {
    return {
      timeZone: draft.timeZoneSelection?.timezone || '',
      dayRolloverHour: Number(draft.dayRolloverHour) || 6,
      weeks: draft.weeks,
      eventDays: draft.eventDays,
    };
  }
  if (kind === 'timetable') {
    return {
      eventTimeZone: draft.timeZoneSelection?.timezone || '',
      dayRolloverHour: Number(draft.dayRolloverHour) || 6,
      schedule: {
        mode: draft.scheduleMode,
        timeZone: draft.timeZoneSelection?.timezone || '',
        dayRolloverHour: Number(draft.dayRolloverHour) || 6,
      },
      weeks: draft.weeks,
      eventDays: draft.eventDays,
      knownStageNames: draft.stageOrder,
    };
  }
  return {
    preferredLanguage: 'zh',
    knownDJNames: draft.lineupArtists
      .map((artist) => artist.memberNamesText)
      .map((item) => item.trim())
      .filter(Boolean)
      .slice(0, 100),
  };
};

const taskPhaseLabel = (task: EventStudioAIImportTaskEntry): string => {
  switch (task.phase) {
    case 'preparing':
      return '准备中';
    case 'polling':
      return task.pollStatus === 'running' ? '识别中' : '排队中';
    case 'auto_matching':
      return '自动匹配 DJ';
    case 'succeeded':
      return '已完成';
    case 'failed':
      return '失败';
    case 'cancelled':
      return '已取消';
    default:
      return '等待中';
  }
};

const imageOriginLabel = (origin: EventStudioImageState['origin']): string => {
  if (origin === 'persisted-event') return '已入库图片';
  if (origin === 'event-upload') return '编辑流程上传';
  return '当前草稿上传';
};

const selectedCountLabel = (panel: ImportPanelState | null): string => {
  if (!panel) return '已选 0 张';
  return `已选 ${panel.selectedImageIds.length} 张`;
};

const formatDurationMs = (durationMs: number): string => {
  const totalSeconds = Math.max(0, Math.round(durationMs / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
};

const taskDurationText = (task: EventStudioAIImportTaskEntry, now: number): string =>
  formatDurationMs((task.phase === 'preparing' || task.phase === 'polling' || task.phase === 'auto_matching' ? now : task.updatedAt) - task.startedAt);

const taskPhaseClassName = (task: EventStudioAIImportTaskEntry): string => {
  switch (task.phase) {
    case 'succeeded':
      return 'bg-[#e8f6ee] text-[#23724a]';
    case 'failed':
      return 'bg-[#fff1f1] text-[#a43f3f]';
    case 'cancelled':
      return 'bg-[#f1f3f1] text-[#5c6762]';
    case 'auto_matching':
      return 'bg-[#edf6ff] text-[#2c699b]';
    default:
      return 'bg-[#f4f6f3] text-[#071110]';
  }
};

const emptyMatchSummary = (): EventStudioAIMatchSummary => ({
  attempted: 0,
  matched: 0,
  failed: 0,
});

const aggregateTaskMatchSummary = (tasks: EventStudioAIImportTaskEntry[]): EventStudioAIMatchSummary =>
  tasks.reduce(
    (summary, task) => ({
      attempted: summary.attempted + task.matchSuccessCount + task.matchFailedCount,
      matched: summary.matched + task.matchSuccessCount,
      failed: summary.failed + task.matchFailedCount,
    }),
    emptyMatchSummary()
  );

type EventStudioAIEditableAct = EventStudioAIEditableLineupItem | EventStudioAIEditableTimetableSlot;

const actTypeLabel = (value: EventStudioAIActType): string =>
  ACT_TYPE_ITEMS.find((item) => item.value === value)?.label || value.toUpperCase();

const performerNamesForDisplay = (item: EventStudioAIEditableAct): string[] =>
  splitPerformerNames(item.performerNamesText, item.actType).slice(0, actTypePerformerCount(item.actType));

const performerDisplayName = (item: EventStudioAIEditableAct): string =>
  safeString(item.displayNameOverrideText) || formatPerformerNamesText(performerNamesForDisplay(item), item.actType) || '未命名演出';

const matchedPerformerCount = (item: EventStudioAIEditableAct): number =>
  item.performerDJIDs.slice(0, actTypePerformerCount(item.actType)).filter(Boolean).length;

const isResultItemFullyMatched = (item: EventStudioAIEditableAct): boolean =>
  matchedPerformerCount(item) >= actTypePerformerCount(item.actType);

const resultItemStatusLabel = (item: EventStudioAIEditableAct): string => (isResultItemFullyMatched(item) ? '已匹配' : '待确认');

const resultItemStatusClassName = (item: EventStudioAIEditableAct): string =>
  isResultItemFullyMatched(item)
    ? 'bg-[#e8f7ee] text-[#1f8f57]'
    : 'bg-[#fff4e8] text-[#a6621a]';

const defaultExpandedResultItemIds = <T extends EventStudioAIEditableAct>(items: T[]): string[] =>
  items.filter((item) => !isResultItemFullyMatched(item)).map((item) => item.id);

const mergeExpandedResultItemIds = <T extends EventStudioAIEditableAct>(baseIds: string[], items: T[]): string[] => {
  const next = new Set(baseIds);
  for (const id of defaultExpandedResultItemIds(items)) next.add(id);
  return Array.from(next);
};

const resultConfidenceValue = (value: number | null | undefined): number | null => {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return null;
  return Math.max(0, Math.min(1, numeric));
};

const resultSearchMatches = (item: EventStudioAIEditableAct, query: string): boolean => {
  const keyword = query.trim().toLocaleLowerCase();
  if (!keyword) return true;
  const haystacks = [
    performerDisplayName(item),
    item.performerNamesText,
    item.notes.join(' '),
    item.actType,
    'stageName' in item ? item.stageName : '',
    'stageName' in item ? item.dayLabel : '',
    'stageName' in item ? item.localDate : '',
    'stageName' in item ? `${item.startTimeText} ${item.endTimeText}` : '',
  ];
  return haystacks.some((value) => value.toLocaleLowerCase().includes(keyword));
};

export default function EventStudioAIImportDock({
  draft,
  setDraft,
  onOpenStep,
  entryMode = 'all',
  entryKind,
}: {
  draft: EventStudioDraft;
  setDraft: React.Dispatch<React.SetStateAction<EventStudioDraft>>;
  onOpenStep?: (step: 'media' | 'timetable' | 'lineup') => void;
  entryMode?: EventStudioAIEntryMode;
  entryKind?: ImportPanelKind;
}) {
  const [panel, setPanel] = useState<ImportPanelState | null>(null);
  const [djSearchResults, setDJSearchResults] = useState<Record<string, EventStudioAIDJSearchResult[]>>({});
  const [djSearchLoadingKeys, setDJSearchLoadingKeys] = useState<Record<string, boolean>>({});
  const [timezoneResults, setTimezoneResults] = useState<NonNullable<EventStudioDraft['timeZoneSelection']>[]>([]);
  const [timezoneSearching, setTimezoneSearching] = useState(false);
  const [globalError, setGlobalError] = useState<string | null>(null);
  const [previewAssetIndex, setPreviewAssetIndex] = useState<number | null>(null);
  const [clockNow, setClockNow] = useState(() => Date.now());
  const runTokenRef = useRef(0);
  const cancelRequestedRef = useRef(false);

  const posterPreviewCount = useMemo(
    () => draft.imageZones.poster.length + draft.imageZones.cover.length,
    [draft.imageZones.cover.length, draft.imageZones.poster.length]
  );
  const timetablePreviewCount = useMemo(() => draft.imageZones.timetable.length, [draft.imageZones.timetable.length]);
  const lineupPreviewCount = useMemo(() => draft.imageZones.lineup.length, [draft.imageZones.lineup.length]);

  const selectedImageOptions = useMemo(() => (panel ? importImageOptions(draft, panel.kind) : []), [draft, panel]);

  const selectedImages = useMemo(() => {
    if (!panel) return [];
    const selectedIdSet = new Set(panel.selectedImageIds);
    return selectedImageOptions.filter((item) => selectedIdSet.has(item.id));
  }, [panel, selectedImageOptions]);
  const previewAssets = useMemo<OverlayImageViewerAsset[]>(
    () =>
      selectedImageOptions.map((image) => ({
        url: image.remoteUrl,
        alt: image.fileName,
        title: image.fileName || '识别图片',
        subtitle: imageOriginLabel(image.origin),
        fileName: image.fileName || undefined,
      })),
    [selectedImageOptions]
  );

  const selectedPosterImage = useMemo(() => {
    if (!panel || panel.kind !== 'poster') return null;
    return selectedImages[0] || selectedImageOptions[0] || null;
  }, [panel, selectedImageOptions, selectedImages]);

  const unresolvedTimetableSlots = panel?.kind === 'timetable' ? panel.timetableSlots.filter(hasUnresolvedTimetableDay) : [];
  const recognitionMatchSummary = useMemo(() => (panel ? aggregateTaskMatchSummary(panel.taskEntries) : emptyMatchSummary()), [panel]);
  const visibleMatchSummary = panel?.manualMatchSummary && panel.manualMatchSummary.attempted > 0 ? panel.manualMatchSummary : recognitionMatchSummary;
  const visibleLineupItems = useMemo(
    () => (panel?.kind === 'lineup' ? panel.lineupItems.filter((item) => resultSearchMatches(item, panel.resultSearchQuery)) : []),
    [panel]
  );
  const visibleTimetableSlots = useMemo(
    () =>
      panel?.kind === 'timetable'
        ? panel.timetableSlots.filter((item) => {
            if (!resultSearchMatches(item, panel.resultSearchQuery)) return false;
            const matchesDay =
              panel.targetEventDayId && panel.targetEventDayId !== ALL_EVENT_DAYS_VALUE
                ? item.eventDayId === panel.targetEventDayId
                : true;
            const normalizedTargetStage =
              panel.targetStageName && panel.targetStageName !== ALL_STAGES_VALUE
                ? panel.targetStageName.trim().toLocaleLowerCase()
                : '';
            const normalizedItemStage = item.stageName.trim().toLocaleLowerCase();
            const matchesStage = normalizedTargetStage ? normalizedItemStage === normalizedTargetStage : true;
            return matchesDay && matchesStage;
          })
        : [],
    [panel]
  );
  const visibleLineupItemIds = useMemo(() => visibleLineupItems.map((item) => item.id), [visibleLineupItems]);
  const visibleTimetableSlotIds = useMemo(() => visibleTimetableSlots.map((slot) => slot.id), [visibleTimetableSlots]);
  const allVisibleTimetableSelected = useMemo(
    () =>
      panel?.kind === 'timetable' &&
      visibleTimetableSlotIds.length > 0 &&
      visibleTimetableSlotIds.every((id) => panel.selectedTimetableSlotIds.includes(id)),
    [panel, visibleTimetableSlotIds]
  );

  useOverlayBodyLock(Boolean(panel));

  useEffect(() => {
    if (!panel) return undefined;
    const hasActiveTask = panel.running || panel.autoMatching || panel.taskEntries.some((task) => ['preparing', 'polling', 'auto_matching'].includes(task.phase));
    if (!hasActiveTask) return undefined;
    const timer = window.setInterval(() => setClockNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [panel]);

  useEffect(() => {
    if (previewAssetIndex === null) return;
    if (previewAssetIndex < previewAssets.length) return;
    setPreviewAssetIndex(null);
  }, [previewAssetIndex, previewAssets.length]);

  const updatePanel = (patch: Partial<ImportPanelState>) => {
    setPanel((current) => (current ? { ...current, ...patch } : current));
  };

  const toggleExpandedResultItem = (itemId: string) => {
    setPanel((current) => {
      if (!current) return current;
      const expanded = current.expandedResultItemIds.includes(itemId);
      return {
        ...current,
        expandedResultItemIds: expanded
          ? current.expandedResultItemIds.filter((id) => id !== itemId)
          : [...current.expandedResultItemIds, itemId],
      };
    });
  };

  const updateTaskEntry = (taskId: string, patch: Partial<EventStudioAIImportTaskEntry>) => {
    setPanel((current) => {
      if (!current) return current;
      return {
        ...current,
        taskEntries: current.taskEntries.map((task) =>
          task.id === taskId ? { ...task, ...patch, updatedAt: Date.now() } : task
        ),
      };
    });
  };

  const openPanel = (kind: ImportPanelKind) => {
    const options = importImageOptions(draft, kind);
    if (!options.length) {
      setGlobalError('No eligible images are available yet. Upload the corresponding image first.');
      return;
    }
    setGlobalError(null);
    setTimezoneResults([]);
    setPanel({
      kind,
      selectedImageIds: kind === 'poster' ? [options[0].id] : options.map((item) => item.id),
      running: false,
      statusText: 'Choose image(s) and start recognition.',
      errorText: null,
      resultJson: null,
      posterResult: null,
      lineupItems: [],
      timetableSlots: [],
      selectedTimetableSlotIds: [],
      targetEventDayId: ALL_EVENT_DAYS_VALUE,
      targetStageName: ALL_STAGES_VALUE,
      warnings: [],
      unparsedTexts: [],
      taskEntries: [],
      autoMatching: false,
      autoMatchStartedAt: null,
      manualMatchSummary: null,
      expandedResultItemIds: [],
      resultSearchQuery: '',
      warningsExpanded: false,
    });
  };

  const closePanel = () => {
    cancelRequestedRef.current = true;
    runTokenRef.current += 1;
    setPanel(null);
    setTimezoneResults([]);
  };

  const aiSearchKey = (scope: 'lineup' | 'timetable', itemId: string, performerIndex: number) =>
    `${scope}-${itemId}-${performerIndex}`;

  const searchPosterTimezones = async () => {
    const query = panel?.posterResult?.timeZoneSearchQuery.trim() || '';
    if (!query) {
      setTimezoneResults([]);
      return;
    }
    setTimezoneSearching(true);
    try {
      const items = await eventStudioApi.searchTimezones(query);
      setTimezoneResults(items);
    } catch {
      setTimezoneResults([]);
    } finally {
      setTimezoneSearching(false);
    }
  };

  const exactMatchLineupItems = async (
    items: EventStudioAIEditableLineupItem[]
  ): Promise<{ items: EventStudioAIEditableLineupItem[]; summary: EventStudioAIMatchSummary }> => {
    const unresolvedNames = items.flatMap((item) =>
      splitPerformerNames(item.performerNamesText, item.actType)
        .slice(0, actTypePerformerCount(item.actType))
        .flatMap((name, performerIndex) => {
          const bound = item.performerDJIDs[performerIndex];
          return bound ? [] : [name];
        })
    );
    if (!unresolvedNames.length) return { items, summary: emptyMatchSummary() };

    const matches = await eventStudioApi.matchExactDJs(unresolvedNames);
    if (!matches.length) {
      return {
        items,
        summary: {
          attempted: unresolvedNames.length,
          matched: 0,
          failed: unresolvedNames.length,
        },
      };
    }

    const lookup = new Map<string, (typeof matches)[number]>();
    for (const match of matches) {
      lookup.set(normalizeDJLookupKey(match.query), match);
      lookup.set(normalizeDJLookupKey(match.name), match);
      for (const alias of match.aliases || []) {
        lookup.set(normalizeDJLookupKey(alias), match);
      }
    }

    let matchedCount = 0;
    let failedCount = 0;
    const nextItems = items.map((item) => {
      const performerNames = splitPerformerNames(item.performerNamesText, item.actType).slice(0, actTypePerformerCount(item.actType));
      const performerDJIDs = [...item.performerDJIDs];
      const performerAvatarURLs = [...item.performerAvatarURLs];
      performerNames.forEach((name, performerIndex) => {
        if (performerDJIDs[performerIndex]) return;
        const match = lookup.get(normalizeDJLookupKey(name));
        if (!match) {
          failedCount += 1;
          return;
        }
        matchedCount += 1;
        performerDJIDs[performerIndex] = match.djId;
        performerAvatarURLs[performerIndex] =
          match.avatarSmallUrl || match.avatarMediumUrl || match.avatarUrl || match.avatarOriginalUrl || null;
      });
      return normalizeEditableAct({
        ...item,
        performerDJIDs,
        performerAvatarURLs,
      });
    });
    return {
      items: nextItems,
      summary: {
        attempted: matchedCount + failedCount,
        matched: matchedCount,
        failed: failedCount,
      },
    };
  };

  const exactMatchTimetableSlots = async (
    slots: EventStudioAIEditableTimetableSlot[]
  ): Promise<{ items: EventStudioAIEditableTimetableSlot[]; summary: EventStudioAIMatchSummary }> => {
    const unresolvedNames = slots.flatMap((slot) =>
      splitPerformerNames(slot.performerNamesText, slot.actType)
        .slice(0, actTypePerformerCount(slot.actType))
        .flatMap((name, performerIndex) => {
          const bound = slot.performerDJIDs[performerIndex];
          return bound ? [] : [name];
        })
    );
    if (!unresolvedNames.length) return { items: slots, summary: emptyMatchSummary() };

    const matches = await eventStudioApi.matchExactDJs(unresolvedNames);
    if (!matches.length) {
      return {
        items: slots,
        summary: {
          attempted: unresolvedNames.length,
          matched: 0,
          failed: unresolvedNames.length,
        },
      };
    }

    const lookup = new Map<string, (typeof matches)[number]>();
    for (const match of matches) {
      lookup.set(normalizeDJLookupKey(match.query), match);
      lookup.set(normalizeDJLookupKey(match.name), match);
      for (const alias of match.aliases || []) {
        lookup.set(normalizeDJLookupKey(alias), match);
      }
    }

    let matchedCount = 0;
    let failedCount = 0;
    const nextSlots = slots.map((slot) => {
      const performerNames = splitPerformerNames(slot.performerNamesText, slot.actType).slice(0, actTypePerformerCount(slot.actType));
      const performerDJIDs = [...slot.performerDJIDs];
      const performerAvatarURLs = [...slot.performerAvatarURLs];
      performerNames.forEach((name, performerIndex) => {
        if (performerDJIDs[performerIndex]) return;
        const match = lookup.get(normalizeDJLookupKey(name));
        if (!match) {
          failedCount += 1;
          return;
        }
        matchedCount += 1;
        performerDJIDs[performerIndex] = match.djId;
        performerAvatarURLs[performerIndex] =
          match.avatarSmallUrl || match.avatarMediumUrl || match.avatarUrl || match.avatarOriginalUrl || null;
      });
      return normalizeEditableAct({
        ...slot,
        performerDJIDs,
        performerAvatarURLs,
      });
    });
    return {
      items: nextSlots,
      summary: {
        attempted: matchedCount + failedCount,
        matched: matchedCount,
        failed: failedCount,
      },
    };
  };

  const appendPosterResult = (rawJson: unknown) => {
    const rawRecord = rawJson && typeof rawJson === 'object' && !Array.isArray(rawJson) ? (rawJson as Record<string, any>) : {};
    setPanel((current) => {
      if (!current || current.kind !== 'poster') return current;
      const parsed = parsePosterEditableResult(rawRecord, draft);
      return {
        ...current,
        resultJson: rawJson,
        posterResult: parsed,
        warnings: mergeUniqueStrings(current.warnings, parsed.warnings),
        unparsedTexts: mergeUniqueStrings(current.unparsedTexts, parsed.unparsedTexts),
      };
    });
  };

  const appendLineupItems = (items: EventStudioAIEditableLineupItem[], warnings: string[], unparsedTexts: string[], rawJson: unknown) => {
    setPanel((current) => {
      if (!current || current.kind !== 'lineup') return current;
      const nextItems = [
        ...current.lineupItems,
        ...items.map((item, index) => ({
          ...item,
          sortOrder: current.lineupItems.length + index + 1,
        })),
      ];
      return {
        ...current,
        resultJson: rawJson,
        lineupItems: nextItems,
        expandedResultItemIds: mergeExpandedResultItemIds(current.expandedResultItemIds, items),
        warnings: mergeUniqueStrings(current.warnings, warnings),
        unparsedTexts: mergeUniqueStrings(current.unparsedTexts, unparsedTexts),
      };
    });
  };

  const appendTimetableSlots = (
    slots: EventStudioAIEditableTimetableSlot[],
    warnings: string[],
    unparsedTexts: string[],
    rawJson: unknown
  ) => {
    setPanel((current) => {
      if (!current || current.kind !== 'timetable') return current;
      const nextSlots = [
        ...current.timetableSlots,
        ...slots.map((slot, index) => ({
          ...slot,
          sortOrder: current.timetableSlots.length + index + 1,
        })),
      ];
      return {
        ...current,
        resultJson: rawJson,
        timetableSlots: nextSlots,
        expandedResultItemIds: mergeExpandedResultItemIds(current.expandedResultItemIds, slots),
        warnings: mergeUniqueStrings(current.warnings, warnings),
        unparsedTexts: mergeUniqueStrings(current.unparsedTexts, unparsedTexts),
      };
    });
  };

  const pollJob = async (
    kind: ImportPanelKind,
    jobId: string,
    taskId: string,
    runToken: number
  ): Promise<EventStudioImportJobSnapshot | null> => {
    for (;;) {
      if (cancelRequestedRef.current || runToken !== runTokenRef.current) return null;
      const snapshot = await eventStudioApi.fetchImportImageJob(kind, jobId);
      updateTaskEntry(taskId, {
        jobId,
        phase:
          snapshot.status === 'cancelled'
            ? 'cancelled'
            : snapshot.status === 'failed'
              ? 'failed'
              : snapshot.status === 'succeeded'
                ? 'succeeded'
                : 'polling',
        pollStatus: snapshot.status,
        message:
          snapshot.status === 'pending'
            ? '已进入 Coze 队列。'
            : snapshot.status === 'running'
              ? '识别进行中。'
              : snapshot.status === 'succeeded'
                ? '识别已完成。'
                : snapshot.status === 'cancelled'
                  ? '识别已取消。'
                  : snapshot.error || '识别失败。',
      });
      if (snapshot.status === 'succeeded' || snapshot.status === 'failed' || snapshot.status === 'cancelled') {
        return snapshot;
      }
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  };

  const startRecognition = async () => {
    if (!panel) return;
    const images = panel.kind === 'poster' ? (selectedPosterImage ? [selectedPosterImage] : []) : selectedImages;
    if (!images.length) {
      updatePanel({
        errorText: 'Select at least one image before starting recognition.',
      });
      return;
    }

    const runToken = runTokenRef.current + 1;
    runTokenRef.current = runToken;
    cancelRequestedRef.current = false;
    setTimezoneResults([]);
    const nextTaskEntries: EventStudioAIImportTaskEntry[] = images.map((image) => ({
      id: crypto.randomUUID(),
      imageId: image.id,
      imageFileName: image.fileName,
      imageOrigin: image.origin,
      jobId: null,
      phase: 'preparing',
      pollStatus: null,
      startedAt: Date.now(),
      updatedAt: Date.now(),
      resultCount: 0,
      warningCount: 0,
      matchSuccessCount: 0,
      matchFailedCount: 0,
      message: '正在准备图片和识别请求。',
    }));
    const taskIdByImageId = new Map(nextTaskEntries.map((task) => [task.imageId, task.id]));
    setPanel((current) => {
      if (!current) return current;
      return {
        ...current,
        running: true,
        errorText: null,
        statusText:
          current.kind === 'poster'
            ? '已开始海报识别。'
            : `已开始 ${images.length} 个识别任务。`,
        taskEntries: nextTaskEntries,
        manualMatchSummary: null,
        ...(current.kind === 'poster'
          ? {
              resultJson: null,
              posterResult: null,
              warnings: [],
              unparsedTexts: [],
            }
          : {}),
      };
    });

    const results = await Promise.allSettled(
      images.map(async (image) => {
        const taskId = taskIdByImageId.get(image.id);
        if (!taskId) return;

        try {
          updateTaskEntry(taskId, {
            phase: 'preparing',
            message: '正在创建识别任务。',
          });
          const job = await eventStudioApi.createImportImageJob({
            kind: panel.kind,
            imageUrl: image.remoteUrl,
            fileType: 'image/jpeg',
            context: jobContextForPanel(draft, panel.kind),
          });
          if (cancelRequestedRef.current || runToken !== runTokenRef.current) return;

          updateTaskEntry(taskId, {
            jobId: job.jobId,
            phase: 'polling',
            pollStatus: job.status,
            message: '任务已创建，正在轮询结果。',
          });

          const snapshot = await pollJob(panel.kind, job.jobId, taskId, runToken);
          if (!snapshot || cancelRequestedRef.current || runToken !== runTokenRef.current) return;

          if (snapshot.status === 'failed') {
            updateTaskEntry(taskId, {
              phase: 'failed',
              message: snapshot.error || '识别失败。',
            });
            return;
          }

          if (snapshot.status === 'cancelled') {
            updateTaskEntry(taskId, {
              phase: 'cancelled',
              message: '识别已取消。',
            });
            return;
          }

          const rawRecord =
            snapshot.result?.rawJson && typeof snapshot.result.rawJson === 'object' && !Array.isArray(snapshot.result.rawJson)
              ? (snapshot.result.rawJson as Record<string, any>)
              : {};
          const warnings = normalizeWarnings(rawRecord);
          const unparsedTexts = normalizeUnparsedTexts(rawRecord);

          if (panel.kind === 'poster') {
            appendPosterResult(snapshot.result?.rawJson ?? null);
            updateTaskEntry(taskId, {
              phase: 'succeeded',
              resultCount: 1,
              warningCount: warnings.length,
              message: '海报识别结果已生成，可继续确认。',
            });
            return;
          }

          updateTaskEntry(taskId, {
            phase: 'auto_matching',
            message: '正在执行精确 DJ 匹配。',
          });

          if (panel.kind === 'lineup') {
            const parsed = parseLineupEditableItems(rawRecord);
            const matchedResult = await exactMatchLineupItems(parsed);
            if (cancelRequestedRef.current || runToken !== runTokenRef.current) return;
            appendLineupItems(matchedResult.items, warnings, unparsedTexts, snapshot.result?.rawJson ?? null);
            updateTaskEntry(taskId, {
              phase: 'succeeded',
              resultCount: matchedResult.items.length,
              warningCount: warnings.length,
              matchSuccessCount: matchedResult.summary.matched,
              matchFailedCount: matchedResult.summary.failed,
              message: `已导入 ${matchedResult.items.length} 条 lineup 结果${matchedResult.summary.attempted ? `，匹配成功 ${matchedResult.summary.matched}，失败 ${matchedResult.summary.failed}` : ''}。`,
            });
            return;
          }

          const parsed = parseTimetableEditableSlots(rawRecord, draft);
          const matchedResult = await exactMatchTimetableSlots(parsed);
          if (cancelRequestedRef.current || runToken !== runTokenRef.current) return;
          appendTimetableSlots(matchedResult.items, warnings, unparsedTexts, snapshot.result?.rawJson ?? null);
          updateTaskEntry(taskId, {
            phase: 'succeeded',
            resultCount: matchedResult.items.length,
            warningCount: warnings.length,
            matchSuccessCount: matchedResult.summary.matched,
            matchFailedCount: matchedResult.summary.failed,
            message: `已导入 ${matchedResult.items.length} 条 timetable 结果${matchedResult.summary.attempted ? `，匹配成功 ${matchedResult.summary.matched}，失败 ${matchedResult.summary.failed}` : ''}。`,
          });
        } catch (error) {
          updateTaskEntry(taskId, {
            phase: 'failed',
            message: error instanceof Error ? error.message : '识别失败。',
          });
        }
      })
    );

    if (runToken !== runTokenRef.current) return;

    const failedCount = results.filter((item) => item.status === 'rejected').length;
    setPanel((current) => {
      if (!current) return current;
      const succeededCount = current.taskEntries.filter((task) => task.phase === 'succeeded').length;
      const cancelledCount = current.taskEntries.filter((task) => task.phase === 'cancelled').length;
      return {
        ...current,
        running: false,
        statusText:
          cancelledCount === current.taskEntries.length
            ? '所有识别任务均已取消。'
            : `识别完成：成功 ${succeededCount}，失败 ${failedCount + current.taskEntries.filter((task) => task.phase === 'failed').length}${cancelledCount ? `，取消 ${cancelledCount}` : ''}。`,
      };
    });
  };

  const cancelRecognition = async () => {
    if (!panel) return;
    if (!panel.running) {
      closePanel();
      return;
    }

    cancelRequestedRef.current = true;
    runTokenRef.current += 1;
    const cancellableJobs = panel.taskEntries.map((task) => task.jobId).filter((jobId): jobId is string => Boolean(jobId));
    await Promise.allSettled(cancellableJobs.map((jobId) => eventStudioApi.cancelImportImageJob(panel.kind, jobId)));
    setPanel((current) => {
      if (!current) return current;
      return {
        ...current,
        running: false,
        statusText: '识别已取消。',
        taskEntries: current.taskEntries.map((task) =>
          task.phase === 'succeeded' || task.phase === 'failed'
            ? task
            : { ...task, phase: 'cancelled', message: '识别已取消。', updatedAt: Date.now() }
        ),
      };
    });
  };

  const updateLineupItem = (itemId: string, updater: (item: EventStudioAIEditableLineupItem) => EventStudioAIEditableLineupItem) => {
    setPanel((current) => {
      if (!current) return current;
      return {
        ...current,
        lineupItems: current.lineupItems.map((item) => (item.id === itemId ? updater(item) : item)),
      };
    });
  };

  const updateTimetableSlot = (
    slotId: string,
    updater: (slot: EventStudioAIEditableTimetableSlot) => EventStudioAIEditableTimetableSlot
  ) => {
    setPanel((current) => {
      if (!current) return current;
      return {
        ...current,
        timetableSlots: current.timetableSlots.map((slot) => (slot.id === slotId ? updater(slot) : slot)),
      };
    });
  };

  const removeLineupItem = (itemId: string) => {
    setPanel((current) => {
      if (!current) return current;
      return {
        ...current,
        lineupItems: current.lineupItems.filter((item) => item.id !== itemId).map((item, index) => ({ ...item, sortOrder: index + 1 })),
        expandedResultItemIds: current.expandedResultItemIds.filter((id) => id !== itemId),
      };
    });
  };

  const removeTimetableSlot = (slotId: string) => {
    setPanel((current) => {
      if (!current) return current;
      const nextSlots = current.timetableSlots.filter((slot) => slot.id !== slotId).map((slot, index) => ({ ...slot, sortOrder: index + 1 }));
      return {
        ...current,
        timetableSlots: nextSlots,
        selectedTimetableSlotIds: current.selectedTimetableSlotIds.filter((id) => id !== slotId),
        expandedResultItemIds: current.expandedResultItemIds.filter((id) => id !== slotId),
      };
    });
  };

  const updateAIImportPerformerName = (
    scope: 'lineup' | 'timetable',
    itemId: string,
    performerIndex: number,
    nextName: string
  ) => {
    const applyUpdate = <T extends EventStudioAIEditableAct>(current: T): T => {
      const count = actTypePerformerCount(current.actType);
      const names = Array.from({ length: count }, (_, index) => performerNamesForDisplay(current)[index] || '');
      names[performerIndex] = nextName;
      const performerDJIDs = [...normalizePerformerIds(current.performerDJIDs, count)];
      const performerAvatarURLs = [...normalizePerformerAvatarURLs(current.performerAvatarURLs, count)];
      performerDJIDs[performerIndex] = null;
      performerAvatarURLs[performerIndex] = null;
      return normalizeEditableAct({
        ...current,
        performerNamesText: formatPerformerNamesText(names, current.actType),
        performerDJIDs,
        performerAvatarURLs,
      }) as T;
    };

    if (scope === 'lineup') {
      updateLineupItem(itemId, (current) => applyUpdate(current));
      return;
    }
    updateTimetableSlot(itemId, (current) => applyUpdate(current));
  };

  const updateAIImportDisplayName = (
    scope: 'lineup' | 'timetable',
    itemId: string,
    value: string
  ) => {
    const applyUpdate = <T extends EventStudioAIEditableAct>(current: T): T => {
      const names = performerNamesForDisplay(current);
      return {
        ...current,
        displayNameOverrideText: normalizeDisplayNameOverrideText(value, names, current.actType),
      };
    };
    if (scope === 'lineup') {
      updateLineupItem(itemId, (current) => applyUpdate(current));
      return;
    }
    updateTimetableSlot(itemId, (current) => applyUpdate(current));
  };

  const moveSelectedTimetableSlots = (target: EventStudioAIResultTarget) => {
    setPanel((current) => {
      if (!current || !current.selectedTimetableSlotIds.length) return current;
      if (target.targetEventDayId === ALL_EVENT_DAYS_VALUE || target.targetStageName === ALL_STAGES_VALUE) {
        return {
          ...current,
          errorText: '批量移动前，请先选择具体的目标活动日和目标舞台。',
        };
      }
      const targetDay = draft.eventDays.find((day) => day.eventDayId === target.targetEventDayId) || draft.eventDays[0];
      if (!targetDay) return current;
      const targetStage = target.targetStageName.trim() || current.targetStageName.trim() || 'Main Stage';
      return {
        ...current,
        timetableSlots: current.timetableSlots.map((slot) =>
          current.selectedTimetableSlotIds.includes(slot.id)
            ? {
                ...slot,
                eventDayId: targetDay.eventDayId,
                weekIndex: targetDay.weekIndex,
                dayIndexInWeek: targetDay.dayIndexInWeek,
                overallDayIndex: targetDay.overallDayIndex,
                localDate: targetDay.date,
                dayLabel: targetDay.label,
                stageName: targetStage,
                unresolvedEventDay: false,
                eventDayResolutionReason: 'Resolved manually in web editor.',
                eventDayResolutionConfidence: 1,
              }
            : slot
        ),
        selectedTimetableSlotIds: [],
        targetEventDayId: targetDay.eventDayId,
        targetStageName: targetStage,
      };
    });
  };

  const confirmVisibleAIItems = () => {
    if (!panel) return;
    const idsToCollapse = panel.kind === 'lineup' ? visibleLineupItemIds : visibleTimetableSlotIds;
    if (!idsToCollapse.length) return;
    setPanel((current) => {
      if (!current) return current;
      return {
        ...current,
        expandedResultItemIds: current.expandedResultItemIds.filter((id) => !idsToCollapse.includes(id)),
      };
    });
  };

  const cleanVisibleAIItems = () => {
    if (!panel) return;
    if (panel.kind === 'lineup') {
      setPanel((current) => {
        if (!current) return current;
        const cleaned = compactEditableLineupItems(current.lineupItems);
        return {
          ...current,
          lineupItems: cleaned,
          expandedResultItemIds: current.expandedResultItemIds.filter((id) => cleaned.some((item) => item.id === id)),
        };
      });
      return;
    }
    if (panel.kind === 'timetable') {
      setPanel((current) => {
        if (!current) return current;
        const cleaned = compactEditableTimetableSlots(current.timetableSlots);
        return {
          ...current,
          timetableSlots: cleaned,
          selectedTimetableSlotIds: current.selectedTimetableSlotIds.filter((id) => cleaned.some((slot) => slot.id === id)),
          expandedResultItemIds: current.expandedResultItemIds.filter((id) => cleaned.some((slot) => slot.id === id)),
        };
      });
    }
  };

  const autoMatchAIItems = async () => {
    if (!panel || panel.kind === 'poster') return;
    updatePanel({
      autoMatching: true,
      autoMatchStartedAt: Date.now(),
      manualMatchSummary: null,
      errorText: null,
      statusText: '正在执行精确 DJ 匹配。',
    });
    try {
      if (panel.kind === 'lineup') {
        const matched = await exactMatchLineupItems(panel.lineupItems);
        setPanel((current) =>
          current && current.kind === 'lineup'
            ? {
                ...current,
                lineupItems: matched.items,
                manualMatchSummary: matched.summary,
                expandedResultItemIds: defaultExpandedResultItemIds(matched.items),
              }
            : current
        );
        updatePanel({
          autoMatching: false,
          autoMatchStartedAt: null,
          statusText: matched.summary.attempted
            ? `精确 DJ 匹配完成：成功 ${matched.summary.matched}，失败 ${matched.summary.failed}。`
            : '精确 DJ 匹配完成，没有需要继续匹配的未绑定对象。',
        });
      } else {
        const matched = await exactMatchTimetableSlots(panel.timetableSlots);
        setPanel((current) =>
          current && current.kind === 'timetable'
            ? {
                ...current,
                timetableSlots: matched.items,
                manualMatchSummary: matched.summary,
                expandedResultItemIds: defaultExpandedResultItemIds(matched.items),
              }
            : current
        );
        updatePanel({
          autoMatching: false,
          autoMatchStartedAt: null,
          statusText: matched.summary.attempted
            ? `精确 DJ 匹配完成：成功 ${matched.summary.matched}，失败 ${matched.summary.failed}。`
            : '精确 DJ 匹配完成，没有需要继续匹配的未绑定对象。',
        });
      }
    } catch (error) {
      updatePanel({
        autoMatching: false,
        autoMatchStartedAt: null,
        errorText: error instanceof Error ? error.message : '精确 DJ 匹配失败。',
      });
    }
  };

  const searchAIImportDJ = async (scope: 'lineup' | 'timetable', itemId: string, performerIndex: number, query: string) => {
    const key = aiSearchKey(scope, itemId, performerIndex);
    const trimmed = query.trim();
    if (!trimmed) {
      setDJSearchResults((current) => ({ ...current, [key]: [] }));
      return;
    }
    setDJSearchLoadingKeys((current) => ({ ...current, [key]: true }));
    try {
      const items = await eventStudioApi.searchDJs(trimmed);
      setDJSearchResults((current) => ({
        ...current,
        [key]: items.filter((item) => Boolean(item.id)),
      }));
    } catch {
      setDJSearchResults((current) => ({ ...current, [key]: [] }));
    } finally {
      setDJSearchLoadingKeys((current) => ({ ...current, [key]: false }));
    }
  };

  const bindAIImportDJ = (scope: 'lineup' | 'timetable', itemId: string, performerIndex: number, dj: EventStudioAIDJSearchResult) => {
    const key = aiSearchKey(scope, itemId, performerIndex);
    const avatar = dj.avatarSmallUrl || dj.avatarMediumUrl || dj.avatarUrl || dj.avatarOriginalUrl || null;
    setPanel((current) => {
      if (!current) return current;
      const items = scope === 'lineup' ? current.lineupItems : current.timetableSlots;
      const nextItems = items.map((item) =>
        item.id === itemId
          ? normalizeEditableAct({
              ...item,
              performerDJIDs: normalizePerformerIds(
                item.performerDJIDs.map((id, index) => (index === performerIndex ? dj.id : id)),
                actTypePerformerCount(item.actType)
              ),
              performerAvatarURLs: normalizePerformerAvatarURLs(
                item.performerAvatarURLs.map((currentAvatar, index) => (index === performerIndex ? avatar : currentAvatar)),
                actTypePerformerCount(item.actType)
              ),
            })
          : item
      );
      return scope === 'lineup'
        ? { ...current, lineupItems: nextItems as EventStudioAIEditableLineupItem[] }
        : { ...current, timetableSlots: nextItems as EventStudioAIEditableTimetableSlot[] };
    });
    setDJSearchResults((current) => ({ ...current, [key]: [] }));
  };

  const clearAIImportDJBinding = (scope: 'lineup' | 'timetable', itemId: string, performerIndex: number) => {
    setPanel((current) => {
      if (!current) return current;
      const items = scope === 'lineup' ? current.lineupItems : current.timetableSlots;
      const nextItems = items.map((item) =>
        item.id === itemId
          ? normalizeEditableAct({
              ...item,
              performerDJIDs: normalizePerformerIds(
                item.performerDJIDs.map((id, index) => (index === performerIndex ? null : id)),
                actTypePerformerCount(item.actType)
              ),
              performerAvatarURLs: normalizePerformerAvatarURLs(
                item.performerAvatarURLs.map((avatar, index) => (index === performerIndex ? null : avatar)),
                actTypePerformerCount(item.actType)
              ),
            })
          : item
      );
      return scope === 'lineup'
        ? { ...current, lineupItems: nextItems as EventStudioAIEditableLineupItem[] }
        : { ...current, timetableSlots: nextItems as EventStudioAIEditableTimetableSlot[] };
    });
  };

  const renderDJBindingControls = (
    scope: 'lineup' | 'timetable',
    item: EventStudioAIEditableLineupItem | EventStudioAIEditableTimetableSlot,
    performerIndex: number
  ) => {
    const key = aiSearchKey(scope, item.id, performerIndex);
    const names = splitPerformerNames(item.performerNamesText, item.actType);
    const query = names[performerIndex] || names[0] || '';
    const bound = Boolean(item.performerDJIDs[performerIndex]);
    const results = djSearchResults[key] || [];
    const isSearching = Boolean(djSearchLoadingKeys[key]);
    const avatar = item.performerAvatarURLs[performerIndex];
    const title = item.actType === 'solo' ? '艺人信息' : `成员 ${performerIndex + 1}`;

    return (
      <div key={`${item.id}-${performerIndex}`} className="rounded-[16px] border border-[#e8eceb] bg-white p-3 shadow-[0_8px_20px_rgba(15,23,42,0.04)]">
        <div className="mb-2.5 flex items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            {avatar ? (
              <span className="inline-flex h-9 w-9 overflow-hidden rounded-full border border-[#e8eceb] bg-[#f4f6f3]">
                <Image src={avatar} alt="" width={36} height={36} className="h-9 w-9 object-cover" />
              </span>
            ) : (
              <span className="inline-flex h-9 w-9 items-center justify-center rounded-full border border-[#d9e4ff] bg-[#eef4ff] text-sm font-semibold text-[#3567d6]">
                {(query.trim()[0] || `${performerIndex + 1}`).toUpperCase()}
              </span>
            )}
            <div>
              <div className="text-xs font-semibold text-[#071110]">{title}</div>
              <div className="mt-0.5 text-[11px] text-black/42">{bound ? '已绑定 DJ' : '未绑定 DJ'}</div>
            </div>
          </div>
          <span className={`inline-flex rounded-full px-2.5 py-1 text-[11px] font-semibold ${bound ? 'bg-[#e8f7ee] text-[#1f8f57]' : 'bg-[#fff4e8] text-[#a6621a]'}`}>
            {bound ? '已匹配' : '待匹配'}
          </span>
        </div>
        <div className="space-y-3">
          <label className="block space-y-1">
            <span className="text-[11px] text-black/42">{item.actType === 'solo' ? '艺人名称' : `成员名称 ${performerIndex + 1}`}</span>
            <input
              className={`${aiCompactInputClass} w-full`}
              value={names[performerIndex] || ''}
              onChange={(event) => updateAIImportPerformerName(scope, item.id, performerIndex, event.target.value)}
              placeholder={item.actType === 'solo' ? '输入艺人名称' : `输入成员 ${performerIndex + 1} 名称`}
            />
          </label>
        </div>
        <div className="mt-2.5 flex flex-wrap items-center gap-2">
          <input
            className={`${aiCompactInputClass} min-w-[160px] flex-1`}
            value={item.performerDJIDs[performerIndex] || ''}
            onChange={(event) =>
              scope === 'lineup'
                ? updateLineupItem(item.id, (current) =>
                    normalizeEditableAct({
                      ...current,
                      performerDJIDs: normalizePerformerIds(
                        current.performerDJIDs.map((id, index) => (index === performerIndex ? event.target.value : id)),
                        actTypePerformerCount(current.actType)
                      ),
                    })
                  )
                : updateTimetableSlot(item.id, (current) =>
                    normalizeEditableAct({
                      ...current,
                      performerDJIDs: normalizePerformerIds(
                        current.performerDJIDs.map((id, index) => (index === performerIndex ? event.target.value : id)),
                        actTypePerformerCount(current.actType)
                      ),
                    })
                  )
            }
            placeholder={`绑定 DJ ID ${performerIndex + 1}`}
          />
          <button
            type="button"
            onClick={() => void searchAIImportDJ(scope, item.id, performerIndex, query)}
            disabled={isSearching || !query}
            className="admin-studio-button-secondary px-3 py-2 text-xs disabled:cursor-not-allowed disabled:opacity-60"
          >
            {isSearching ? '搜索中' : '搜索'}
          </button>
          <button
            type="button"
            onClick={() => clearAIImportDJBinding(scope, item.id, performerIndex)}
            className="admin-studio-button-secondary px-3 py-2 text-xs"
          >
            清空
          </button>
        </div>
        {results.length ? (
          <div className="mt-2 space-y-1">
            {results.slice(0, 5).map((dj) => (
              <button
                key={dj.id}
                type="button"
                onClick={() => bindAIImportDJ(scope, item.id, performerIndex, dj)}
                className="flex w-full items-center justify-between gap-3 rounded-[12px] bg-[#f4f6f3] px-3 py-2 text-left text-xs text-[#071110]"
              >
                <span className="flex min-w-0 items-center gap-2">
                  {dj.avatarSmallUrl || dj.avatarMediumUrl || dj.avatarUrl || dj.avatarOriginalUrl ? (
                    <span className="inline-flex h-7 w-7 overflow-hidden rounded-full border border-[#e8eceb] bg-white">
                      <Image
                        src={dj.avatarSmallUrl || dj.avatarMediumUrl || dj.avatarUrl || dj.avatarOriginalUrl || ''}
                        alt=""
                        width={28}
                        height={28}
                        className="h-7 w-7 object-cover"
                      />
                    </span>
                  ) : null}
                  <span className="truncate">{dj.name || dj.slug || dj.id}</span>
                </span>
                <span className="shrink-0 text-black/38">{dj.country || dj.id}</span>
              </button>
            ))}
          </div>
        ) : null}
      </div>
    );
  };

  const renderResultAvatarGroup = (item: EventStudioAIEditableAct) => {
    const names = performerNamesForDisplay(item);
    return (
      <div className="flex shrink-0 -space-x-1.5">
        {names.slice(0, 3).map((name, index) => {
          const avatar = item.performerAvatarURLs[index];
          const initial = (name.trim()[0] || '?').toUpperCase();
          return avatar ? (
            <span
              key={`${item.id}-avatar-${index}`}
              className="inline-flex h-9 w-9 overflow-hidden rounded-full border-2 border-white bg-[#eef1ec] shadow-[0_8px_20px_rgba(15,23,42,0.08)]"
            >
              <Image src={avatar} alt="" width={36} height={36} className="h-9 w-9 object-cover" />
            </span>
          ) : (
            <span
              key={`${item.id}-avatar-${index}`}
              className="inline-flex h-9 w-9 items-center justify-center rounded-full border-2 border-white bg-[#eef4ff] text-xs font-semibold text-[#3567d6] shadow-[0_8px_20px_rgba(15,23,42,0.08)]"
            >
              {initial}
            </span>
          );
        })}
      </div>
    );
  };

  const renderResultToolbar = (
    totalCount: number,
    matchedCount: number,
    unresolvedCount: number,
    searchPlaceholder: string
  ) => (
    <div className="admin-reference-card p-4">
      <div className="flex flex-col gap-3 xl:flex-row xl:items-center xl:justify-between">
        <label className="flex min-w-0 flex-1 items-center gap-3 rounded-[18px] border border-[#e7ece7] bg-white px-4 py-2.5">
          <span className="text-black/35">⌕</span>
          <input
            className="min-w-0 flex-1 appearance-none border-0 bg-transparent p-0 text-sm text-[#071110] shadow-none outline-none ring-0 placeholder:text-black/35 focus:outline-none focus:ring-0"
            value={panel?.resultSearchQuery || ''}
            onChange={(event) => updatePanel({ resultSearchQuery: event.target.value })}
            placeholder={searchPlaceholder}
          />
        </label>
        <div className="flex flex-wrap gap-2">
          {[
            { label: '全部', count: totalCount, className: 'border-[#dce7ff] bg-[#f4f7ff] text-[#3567d6]' },
            { label: '成功', count: matchedCount, className: 'border-[#dcefdc] bg-[#effaf0] text-[#24945b]' },
            { label: '待确认', count: unresolvedCount, className: 'border-[#f3e1ca] bg-[#fff7ef] text-[#b56b1b]' },
          ].map((chip) => (
            <div
              key={chip.label}
              className={`inline-flex items-center gap-2 rounded-[16px] border px-4 py-2 text-sm font-medium ${chip.className}`}
            >
              <span>{chip.label}</span>
              <span>{chip.count}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );

  const renderActTypeToggle = (
    value: EventStudioAIActType,
    onChange: (next: EventStudioAIActType) => void
  ) => (
    <div className="grid grid-cols-3 gap-1 rounded-[14px] border border-[#e7ece7] bg-white p-1">
      {ACT_TYPE_ITEMS.map((act) => {
        const active = act.value === value;
        return (
          <button
            key={act.value}
            type="button"
            onClick={() => onChange(act.value)}
            className={`min-w-0 whitespace-nowrap rounded-[10px] px-2.5 py-2 text-[13px] font-semibold tracking-[0.01em] transition ${
              active ? 'bg-[#eef4ff] text-[#3567d6]' : 'text-black/45 hover:bg-[#f5f7f5]'
            }`}
          >
            {act.label}
          </button>
        );
      })}
    </div>
  );

  const renderLineupEditPanel = (item: EventStudioAIEditableLineupItem) => {
    const count = actTypePerformerCount(item.actType);
    const names = performerNamesForDisplay(item);
    return (
      <div className="border-t border-[#eef1ee] bg-[#fbfcfa] px-4 py-4">
        <div className="mb-3 flex flex-wrap items-start justify-between gap-2">
          <div>
            <div className="text-sm font-semibold text-[#071110]">编辑演出对象</div>
            <div className="mt-1 text-xs text-black/42">可以修改展示名、演出形式和每位成员的绑定结果。</div>
          </div>
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => toggleExpandedResultItem(item.id)}
              className="admin-studio-button-primary min-w-[82px] whitespace-nowrap px-3 py-2 text-xs"
            >
              确认此项
            </button>
            <button
              type="button"
              onClick={() => removeLineupItem(item.id)}
              className="admin-studio-button-danger min-w-[68px] whitespace-nowrap px-3 py-2 text-xs"
            >
              删除
            </button>
          </div>
        </div>
        <div className="grid gap-3 xl:grid-cols-[220px_140px_minmax(0,1fr)]">
          <div className="space-y-1 text-xs text-black/45">
            <span>演出形式</span>
            {renderActTypeToggle(item.actType, (nextActType) =>
              updateLineupItem(item.id, (current) =>
                normalizeEditableAct({
                  ...current,
                  actType: nextActType,
                })
              )
            )}
          </div>
          <label className="space-y-1 text-xs text-black/45">
            <span>置信度</span>
            <input
              className={aiCompactInputClass}
              value={String(item.confidence ?? '')}
              onChange={(event) =>
                updateLineupItem(item.id, (current) => ({
                  ...current,
                  confidence: event.target.value ? Number(event.target.value) : null,
                }))
              }
              placeholder="0.95"
            />
          </label>
          <div className="rounded-[16px] border border-[#edf1ee] bg-white px-4 py-3 text-sm text-black/56">
            <label className="block space-y-1">
              <span className="text-[11px] text-black/38">当前展示名</span>
              <input
                className={`${aiCompactInputClass} mt-1`}
                value={item.displayNameOverrideText || formatPerformerNamesText(names, item.actType)}
                onChange={(event) => updateAIImportDisplayName('lineup', item.id, event.target.value)}
                placeholder="输入展示名称"
              />
            </label>
          </div>
        </div>
        <div className={`mt-3 grid gap-3 ${count >= 3 ? 'xl:grid-cols-3' : 'xl:grid-cols-2'}`}>
          {Array.from({ length: count }).map((_, performerIndex) => renderDJBindingControls('lineup', item, performerIndex))}
        </div>
        {item.notes.length ? <div className="mt-2 text-xs text-black/40">备注：{item.notes.join(' / ')}</div> : null}
      </div>
    );
  };

  const renderTimetableEditPanel = (slot: EventStudioAIEditableTimetableSlot) => (
    <div className="border-t border-[#eef1ee] bg-[#fbfcfa] px-4 py-4">
      <div className="mb-3 flex flex-wrap items-start justify-between gap-2">
        <div>
          <div className="text-sm font-semibold text-[#071110]">编辑时刻表对象</div>
          <div className="mt-1 text-xs text-black/42">确认时间、舞台、展示名和每位成员绑定后，再切回确认态。</div>
        </div>
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => toggleExpandedResultItem(slot.id)}
            className="admin-studio-button-primary min-w-[82px] whitespace-nowrap px-3 py-2 text-xs"
          >
            确认此项
          </button>
          <button
            type="button"
            onClick={() => removeTimetableSlot(slot.id)}
            className="admin-studio-button-danger min-w-[68px] whitespace-nowrap px-3 py-2 text-xs"
          >
            删除
          </button>
        </div>
      </div>
      <div className="grid gap-3 xl:grid-cols-2">
        <div className="space-y-1 text-xs text-black/45">
          <span>演出形式</span>
          {renderActTypeToggle(slot.actType, (nextActType) =>
            updateTimetableSlot(slot.id, (current) =>
              normalizeEditableAct({
                ...current,
                actType: nextActType,
              })
            )
          )}
        </div>
        <label className="space-y-1 text-xs text-black/45">
          <span>活动日</span>
          <div className="admin-studio-select-shell">
            <select
              className={aiCompactSelectClass}
              value={slot.eventDayId}
              onChange={(event) =>
                updateTimetableSlot(slot.id, (current) => {
                  const matchedDay = draft.eventDays.find((day) => day.eventDayId === event.target.value) || draft.eventDays[0];
                  return matchedDay
                    ? {
                        ...current,
                        eventDayId: matchedDay.eventDayId,
                        weekIndex: matchedDay.weekIndex,
                        dayIndexInWeek: matchedDay.dayIndexInWeek,
                        overallDayIndex: matchedDay.overallDayIndex,
                        localDate: matchedDay.date,
                        dayLabel: matchedDay.label,
                        unresolvedEventDay: false,
                        eventDayResolutionReason: '已在网页编辑器中手动修正。',
                        eventDayResolutionConfidence: 1,
                      }
                    : current;
                })
              }
            >
              {eventDayTargets(draft).map((day) => (
                <option key={day.eventDayId} value={day.eventDayId}>
                  {day.label} / {day.date}
                </option>
              ))}
            </select>
          </div>
        </label>
        <div className="rounded-[16px] border border-[#edf1ee] bg-white px-4 py-3 text-sm text-black/56">
          <label className="block space-y-1">
            <span className="text-[11px] text-black/38">当前展示名</span>
            <input
              className={`${aiCompactInputClass} mt-1`}
              value={slot.displayNameOverrideText || formatPerformerNamesText(performerNamesForDisplay(slot), slot.actType)}
              onChange={(event) => updateAIImportDisplayName('timetable', slot.id, event.target.value)}
              placeholder="输入展示名称"
            />
          </label>
        </div>
        <label className="space-y-1 text-xs text-black/45">
          <span>舞台</span>
          <input
            className={aiCompactInputClass}
            value={slot.stageName}
            onChange={(event) => updateTimetableSlot(slot.id, (current) => ({ ...current, stageName: event.target.value }))}
            placeholder="舞台名称"
          />
        </label>
        <label className="space-y-1 text-xs text-black/45">
          <span>开始时间</span>
          <input
            className={aiCompactInputClass}
            value={slot.startTimeText}
            onChange={(event) => updateTimetableSlot(slot.id, (current) => ({ ...current, startTimeText: event.target.value }))}
            placeholder="18:00"
          />
        </label>
        <label className="space-y-1 text-xs text-black/45">
          <span>结束时间</span>
          <input
            className={aiCompactInputClass}
            value={slot.endTimeText}
            onChange={(event) => updateTimetableSlot(slot.id, (current) => ({ ...current, endTimeText: event.target.value }))}
            placeholder="19:00"
          />
        </label>
        <label className="space-y-1 text-xs text-black/45">
          <span>开始跨天</span>
          <div className="admin-studio-select-shell">
            <select
              className={aiCompactSelectClass}
              value={String(slot.startDayOffset)}
              onChange={(event) =>
                updateTimetableSlot(slot.id, (current) => ({ ...current, startDayOffset: Number(event.target.value) || 0 }))
              }
            >
              <option value="0">当天</option>
              <option value="1">次日</option>
            </select>
          </div>
        </label>
        <label className="space-y-1 text-xs text-black/45">
          <span>结束跨天</span>
          <div className="admin-studio-select-shell">
            <select
              className={aiCompactSelectClass}
              value={String(slot.endDayOffset)}
              onChange={(event) =>
                updateTimetableSlot(slot.id, (current) => ({ ...current, endDayOffset: Number(event.target.value) || 0 }))
              }
            >
              <option value="0">当天</option>
              <option value="1">次日</option>
            </select>
          </div>
        </label>
      </div>
      {slot.eventDayResolutionReason ? (
        <div className="mt-3 rounded-[14px] border border-[#f0e1cc] bg-[#fffaf4] px-3 py-2 text-xs text-[#9a6334]">
          修正说明：{slot.eventDayResolutionReason}
          {slot.eventDayResolutionConfidence != null ? ` / 置信度 ${slot.eventDayResolutionConfidence}` : ''}
        </div>
      ) : null}
      <div className={`mt-3 grid gap-3 ${actTypePerformerCount(slot.actType) >= 3 ? 'xl:grid-cols-3' : 'xl:grid-cols-2'}`}>
        {Array.from({ length: actTypePerformerCount(slot.actType) }).map((_, performerIndex) =>
          renderDJBindingControls('timetable', slot, performerIndex)
        )}
      </div>
    </div>
  );

  const applyResult = () => {
    if (!panel) return;

    if (panel.kind === 'poster') {
      if (!panel.posterResult) return;
      const result = panel.posterResult;
      setDraft((current) =>
        syncEventStudioScheduleStructure({
          ...current,
          name: result.name,
          city: result.city,
          country: result.country,
          detailAddress: result.detailAddress,
          venueName: result.venueName,
          venueAddress: result.venueAddress,
          sourceProvider: result.sourceProvider || current.sourceProvider,
          referenceLinksText: result.referenceLinksText,
          socialLinksText: result.socialLinksText,
          timeZoneQuery: result.timeZoneSearchQuery || current.timeZoneQuery,
          timeZoneSelection:
            result.selectedTimeZoneLookup ||
            resolvedTimeZoneSelection(current, {
              timeZone: {
                ianaName: result.timeZoneIdentifier,
                displayName: result.timeZoneDisplayName,
              },
              cityI18n: result.city,
              countryI18n: result.country,
            }),
          startDate: result.startDate || current.startDate,
          endDate: result.endDate || current.endDate,
          scheduleMode: result.scheduleMode,
          weeks: result.scheduleMode === 'multi_week' ? result.weekRanges : current.weeks,
          ticketUrl: result.ticketUrl,
          ticketCurrency: result.ticketCurrency || current.ticketCurrency,
          ticketNotes: result.ticketNotes,
          ticketTiers: result.ticketTiers,
        })
      );
      closePanel();
      return;
    }

    if (panel.kind === 'lineup') {
      const nextLineup = compactEditableLineupItems(panel.lineupItems)
        .map((item, index): EventStudioDraft['lineupArtists'][number] | null => {
          const names = splitPerformerNames(item.performerNamesText, item.actType).slice(0, actTypePerformerCount(item.actType));
          if (!names.length) return null;
          return {
            id: crypto.randomUUID(),
            canonicalArtistId: null,
            djId: item.performerDJIDs.find(Boolean) || '',
            memberDjIds: normalizePerformerIds(item.performerDJIDs, actTypePerformerCount(item.actType)),
            memberNamesText: names.join(' / '),
            displayNameOverride: normalizeDisplayNameOverrideText(item.displayNameOverrideText, names, item.actType) || undefined,
            actType: item.actType,
            sortOrder: draft.lineupArtists.length + index + 1,
          };
        })
        .filter((item): item is EventStudioDraft['lineupArtists'][number] => item !== null);

      setDraft((current) => ({
        ...current,
        lineupSyncMode: 'incremental_fill',
        lineupArtists: [...current.lineupArtists, ...nextLineup].map((artist, index) => ({
          ...artist,
          sortOrder: index + 1,
        })),
      }));
      closePanel();
      return;
    }

    if (unresolvedTimetableSlots.length) {
      updatePanel({
        errorText: 'Resolve every unresolved event day before applying timetable results.',
      });
      return;
    }

    const nextSlots = compactEditableTimetableSlots(panel.timetableSlots)
      .map((slot, index): EventStudioDraft['timetableSlots'][number] | null => {
        const names = splitPerformerNames(slot.performerNamesText, slot.actType).slice(0, actTypePerformerCount(slot.actType));
        if (!names.length) return null;
        const eventDay = draft.eventDays.find((day) => day.eventDayId === slot.eventDayId);
        if (!eventDay) return null;
        return {
          id: crypto.randomUUID(),
          canonicalSlotId: null,
          lineupArtistId: null,
          actType: slot.actType,
          eventDayId: eventDay.eventDayId,
          weekIndex: eventDay.weekIndex,
          dayIndexInWeek: eventDay.dayIndexInWeek,
          overallDayIndex: eventDay.overallDayIndex,
          localDate: eventDay.date,
          djId: slot.performerDJIDs.find(Boolean) || '',
          memberDjIds: normalizePerformerIds(slot.performerDJIDs, actTypePerformerCount(slot.actType)),
          memberNamesText: names.join(' / '),
          displayNameOverride: normalizeDisplayNameOverrideText(slot.displayNameOverrideText, names, slot.actType) || undefined,
          stageName: slot.stageName || 'Main Stage',
          sortOrder: draft.timetableSlots.length + index + 1,
          startTime: slot.startTimeText,
          endTime: slot.endTimeText,
          startDayOffset: Math.max(0, Number(slot.startDayOffset) || 0),
          endDayOffset: Math.max(Math.max(0, Number(slot.startDayOffset) || 0), Number(slot.endDayOffset) || 0),
        };
      })
      .filter((slot): slot is EventStudioDraft['timetableSlots'][number] => slot !== null);

    setDraft((current) => ({
      ...current,
      timetableSlots: [...current.timetableSlots, ...nextSlots].map((slot, index) => ({
        ...slot,
        sortOrder: index + 1,
      })),
      stageOrder: Array.from(new Set([...current.stageOrder, ...nextSlots.map((slot) => slot.stageName).filter(Boolean)])),
    }));
    closePanel();
  };

  const renderEntryButton = (item: (typeof PANEL_ITEMS)[number], compact = false) => (
    <div key={item.kind} className={compact ? 'space-y-2' : 'space-y-3'}>
      <button
        type="button"
        onClick={() => {
          setGlobalError(null);
          openPanel(item.kind);
          onOpenStep?.(item.kind === 'poster' ? 'media' : item.kind);
        }}
        className={`admin-ai-action-button ${compact ? 'admin-ai-action-button-compact' : 'w-full'}`}
      >
        <span className="admin-ai-action-button-title">AI</span>
        <span>{item.title}</span>
      </button>
      <div className="px-1 text-sm leading-6 text-black/48">{item.description}</div>
    </div>
  );

  return (
    <div className="space-y-4">
      {globalError ? <div className="admin-studio-pastel-rose p-4 text-sm text-[#6a3530]">{globalError}</div> : null}

      {entryMode === 'all' ? (
        <div className="admin-reference-card p-4">
          <div className="admin-studio-label">AI Import</div>
          <div className="mt-3 grid gap-4 lg:grid-cols-3">
            {PANEL_ITEMS.map((item) => {
              const count =
                item.kind === 'poster' ? posterPreviewCount : item.kind === 'timetable' ? timetablePreviewCount : lineupPreviewCount;
              return (
                <div key={item.kind} className="rounded-[22px] border border-[#e8eceb] bg-[#f8f9f8] p-4">
                  {renderEntryButton(item, true)}
                  <div className="mt-3 text-xs text-black/40">可用图片：{count}</div>
                </div>
              );
            })}
          </div>
        </div>
      ) : null}

      {entryMode === 'single' && entryKind ? (
        (() => {
          const item = PANEL_ITEMS.find((current) => current.kind === entryKind);
          if (!item) return null;
          return renderEntryButton(item);
        })()
      ) : null}

      {panel ? (
        <div className="fixed inset-0 z-50 overflow-hidden overscroll-contain bg-black/45 p-3">
          <div className="flex h-full items-center justify-center">
            <div className="flex h-[calc(100vh-1.5rem)] min-h-[calc(100vh-1.5rem)] w-full max-w-6xl flex-col overflow-hidden rounded-[28px] border border-[#e8eceb] bg-[#fbfcfa] shadow-2xl sm:h-[calc(100vh-3rem)] sm:min-h-[calc(100vh-3rem)]">
              <div className="flex flex-shrink-0 items-start justify-between gap-4 border-b border-[#e8eceb] px-5 py-4">
                <div className="min-w-0 flex-1">
                  <div className="admin-studio-label">{PANEL_ITEMS.find((item) => item.kind === panel.kind)?.title}</div>
                  <div className="mt-2 text-sm leading-6 text-black/52">{panel.errorText || panel.statusText}</div>
                </div>
                <div className="flex shrink-0 flex-nowrap items-center gap-2">
                  <button
                    type="button"
                    onClick={() => void cancelRecognition()}
                    className="admin-studio-button-secondary h-9 min-w-[76px] whitespace-nowrap px-3 text-[13px]"
                  >
                    {panel.running ? '取消' : '关闭'}
                  </button>
                  <button
                    type="button"
                    onClick={() => void startRecognition()}
                    disabled={(panel.kind === 'poster' ? !selectedPosterImage : !selectedImages.length) || panel.running}
                    className={`admin-ai-action-button h-9 min-w-[118px] whitespace-nowrap px-3 text-[13px] ${
                      panel.running ? 'admin-ai-action-button-running' : ''
                    } disabled:cursor-not-allowed disabled:opacity-60`}
                  >
                    {panel.running ? '识别中...' : '开始识别'}
                  </button>
                </div>
              </div>

              <div className="min-h-0 flex-1 overflow-hidden">
                <div className="grid h-full min-h-0 gap-5 p-5 lg:grid-cols-[248px_minmax(0,1fr)]">
                  <div className="min-h-0 space-y-4 overflow-y-auto overscroll-contain pr-1">
                    <div className="admin-reference-card p-4">
                      <div className="flex items-center justify-between gap-3">
                        <div className="text-sm font-semibold text-[#071110]">选择图片</div>
                        <div className="text-xs text-black/40">{selectedCountLabel(panel)}</div>
                      </div>
                      <div className="mt-3 grid grid-cols-2 gap-2.5">
                        {selectedImageOptions.map((image) => {
                          const checked = panel.selectedImageIds.includes(image.id);
                          const toggle = () => {
                            setPanel((current) => {
                              if (!current) return current;
                              if (current.kind === 'poster') {
                                return { ...current, selectedImageIds: [image.id] };
                              }
                              const nextSelected = checked
                                ? current.selectedImageIds.filter((id) => id !== image.id)
                                : [...current.selectedImageIds, image.id];
                              return { ...current, selectedImageIds: nextSelected };
                            });
                          };

                          return (
                            <div
                              key={image.id}
                              className={`relative overflow-hidden rounded-[16px] border bg-white ${
                                checked ? 'border-[#3aa66b]' : 'border-[#e8eceb]'
                              }`}
                            >
                              <button type="button" onClick={toggle} className="block w-full text-left">
                                <div className="relative aspect-square bg-[#f2f3ef]">
                                  <Image src={image.remoteUrl} alt={image.fileName} fill className="object-cover" sizes="140px" />
                                </div>
                                <div className="flex items-start justify-between gap-2 px-2.5 py-2">
                                  <div className="min-w-0">
                                    <div className="truncate text-[12px] font-medium text-[#071110]">{image.fileName}</div>
                                    <div className="mt-1 text-[10px] text-black/40">{imageOriginLabel(image.origin)}</div>
                                  </div>
                                  <input readOnly type={panel.kind === 'poster' ? 'radio' : 'checkbox'} checked={checked} />
                                </div>
                              </button>
                              <button
                                type="button"
                                onClick={() => {
                                  const previewIndex = selectedImageOptions.findIndex((candidate) => candidate.id === image.id);
                                  if (previewIndex >= 0) setPreviewAssetIndex(previewIndex);
                                }}
                                className="absolute right-2 top-2 rounded-full bg-black/55 px-2.5 py-1 text-[10px] font-semibold text-white"
                              >
                                预览
                              </button>
                            </div>
                          );
                        })}
                      </div>
                    </div>

                    <div className="admin-reference-card p-4">
                      <div className="text-sm font-semibold text-[#071110]">任务进度</div>
                      {panel.taskEntries.length ? (
                        <div className="mt-3 space-y-2">
                          {panel.taskEntries.map((task) => (
                            <div key={task.id} className="rounded-[18px] border border-[#e8eceb] bg-white/80 p-3">
                              <div className="flex flex-nowrap items-start justify-between gap-2">
                                <div className="min-w-0">
                                  <div className="truncate text-sm font-medium text-[#071110]">{task.imageFileName}</div>
                                  <div className="mt-1 text-xs text-black/40">{imageOriginLabel(task.imageOrigin)}</div>
                                </div>
                                <div className={`shrink-0 rounded-full px-3 py-1 text-center text-xs font-semibold ${taskPhaseClassName(task)}`}>
                                  {taskPhaseLabel(task)}
                                </div>
                              </div>
                              <div className="mt-2 flex flex-wrap items-center justify-between gap-2 text-[11px] text-black/38">
                                <span>{task.phase === 'preparing' || task.phase === 'polling' || task.phase === 'auto_matching' ? '已耗时' : '总耗时'}: {taskDurationText(task, clockNow)}</span>
                                {task.matchSuccessCount || task.matchFailedCount ? (
                                  <span>
                                    匹配 成功 {task.matchSuccessCount} / 失败 {task.matchFailedCount}
                                  </span>
                                ) : null}
                              </div>
                              <div className="mt-2 text-xs leading-5 text-black/52">{task.message}</div>
                              {task.resultCount || task.warningCount ? (
                                <div className="mt-2 text-xs text-black/38">
                                  结果数：{task.resultCount} / 警告：{task.warningCount}
                                </div>
                              ) : null}
                            </div>
                          ))}
                        </div>
                      ) : (
                        <div className="mt-3 text-sm text-black/48">尚未开始识别任务。</div>
                      )}
                    </div>
                  </div>

                  <div className="min-h-0 space-y-4 overflow-y-auto overscroll-contain pr-1">
                    <div className="admin-reference-card p-4">
                      <div className="flex flex-wrap items-center justify-between gap-3">
                        <div>
                          <div className="text-sm font-semibold text-[#071110]">识别结果</div>
                          <div className="mt-1 text-xs text-black/40">先确认识别结果，再将它们应用到当前草稿。</div>
                          {panel.kind !== 'poster' && visibleMatchSummary.attempted ? (
                            <div className="mt-2 text-xs text-black/45">
                              自动匹配：成功 {visibleMatchSummary.matched} / 失败 {visibleMatchSummary.failed}
                            </div>
                          ) : null}
                        </div>
                        <div className="flex flex-wrap gap-2">
                          {panel.kind !== 'poster' ? (
                            <button
                              type="button"
                              onClick={() => void autoMatchAIItems()}
                              disabled={panel.autoMatching || panel.running}
                              className="admin-studio-button-secondary px-4 py-2 text-sm disabled:cursor-not-allowed disabled:opacity-60"
                            >
                              {panel.autoMatching ? '匹配中...' : '自动匹配 DJ'}
                            </button>
                          ) : null}
                          <button
                            type="button"
                            onClick={applyResult}
                            disabled={
                              panel.running ||
                              (panel.kind === 'poster' && !panel.posterResult) ||
                              (panel.kind === 'lineup' && !panel.lineupItems.length) ||
                              (panel.kind === 'timetable' && (!panel.timetableSlots.length || unresolvedTimetableSlots.length > 0))
                            }
                            className="admin-studio-button-primary px-4 py-2 text-sm disabled:cursor-not-allowed disabled:opacity-60"
                          >
                            应用结果
                          </button>
                        </div>
                      </div>

                      {panel.warnings.length || panel.unparsedTexts.length ? (
                        <div className="mt-3 rounded-[18px] border border-[#f0dcc5] bg-[#fff7ef] p-3 text-xs text-[#7c4d20]">
                          <div className="flex items-center justify-between gap-3">
                            <div>
                              警告 {panel.warnings.length} 条 / 未解析 {panel.unparsedTexts.length} 条
                            </div>
                            <button
                              type="button"
                              onClick={() => updatePanel({ warningsExpanded: !panel.warningsExpanded })}
                              className="admin-studio-button-secondary px-3 py-1.5 text-xs"
                            >
                              {panel.warningsExpanded ? '收起详情' : '展开详情'}
                            </button>
                          </div>
                          {panel.warningsExpanded ? (
                            <div className="mt-2 space-y-2">
                              {panel.warnings.length ? <div>警告：{panel.warnings.join(' / ')}</div> : null}
                              {panel.unparsedTexts.length ? <div>未解析：{panel.unparsedTexts.join(' / ')}</div> : null}
                            </div>
                          ) : null}
                        </div>
                      ) : null}

                      {panel.kind === 'timetable' && unresolvedTimetableSlots.length ? (
                        <div className="mt-3 rounded-[18px] border border-[#f0d0d0] bg-[#fff3f3] p-3 text-xs text-[#8a3e3e]">
                          还有 {unresolvedTimetableSlots.length} 条 timetable 结果需要先手动确认活动日，才能应用到草稿。
                        </div>
                      ) : null}
                    </div>

                    {panel.kind === 'poster' ? (
                  panel.posterResult ? (
                    <div className="space-y-3">
                      <div className="admin-reference-card p-4">
                        <div className="grid gap-3 lg:grid-cols-2">
                          <label className="space-y-1 text-xs text-black/45">
                            <span>Name (ZH)</span>
                            <input
                              className="admin-studio-input"
                              value={panel.posterResult.name.zh}
                              onChange={(event) =>
                                setPanel((current) =>
                                  current && current.posterResult
                                    ? {
                                        ...current,
                                        posterResult: {
                                          ...current.posterResult,
                                          name: { ...current.posterResult.name, zh: event.target.value },
                                        },
                                      }
                                    : current
                                )
                              }
                            />
                          </label>
                          <label className="space-y-1 text-xs text-black/45">
                            <span>Name (EN)</span>
                            <input
                              className="admin-studio-input"
                              value={panel.posterResult.name.en}
                              onChange={(event) =>
                                setPanel((current) =>
                                  current && current.posterResult
                                    ? {
                                        ...current,
                                        posterResult: {
                                          ...current.posterResult,
                                          name: { ...current.posterResult.name, en: event.target.value },
                                        },
                                      }
                                    : current
                                )
                              }
                            />
                          </label>
                          <label className="space-y-1 text-xs text-black/45">
                            <span>City</span>
                            <input
                              className="admin-studio-input"
                              value={panel.posterResult.city.en || panel.posterResult.city.zh}
                              onChange={(event) =>
                                setPanel((current) =>
                                  current && current.posterResult
                                    ? {
                                        ...current,
                                        posterResult: {
                                          ...current.posterResult,
                                          city: {
                                            ...current.posterResult.city,
                                            en: event.target.value,
                                            zh: current.posterResult.city.zh || event.target.value,
                                          },
                                        },
                                      }
                                    : current
                                )
                              }
                            />
                          </label>
                          <label className="space-y-1 text-xs text-black/45">
                            <span>Country</span>
                            <input
                              className="admin-studio-input"
                              value={panel.posterResult.country.en || panel.posterResult.country.zh}
                              onChange={(event) =>
                                setPanel((current) =>
                                  current && current.posterResult
                                    ? {
                                        ...current,
                                        posterResult: {
                                          ...current.posterResult,
                                          country: {
                                            ...current.posterResult.country,
                                            en: event.target.value,
                                            zh: current.posterResult.country.zh || event.target.value,
                                          },
                                        },
                                      }
                                    : current
                                )
                              }
                            />
                          </label>
                          <label className="space-y-1 text-xs text-black/45 lg:col-span-2">
                            <span>Detail Address</span>
                            <input
                              className="admin-studio-input"
                              value={panel.posterResult.detailAddress.en || panel.posterResult.detailAddress.zh}
                              onChange={(event) =>
                                setPanel((current) =>
                                  current && current.posterResult
                                    ? {
                                        ...current,
                                        posterResult: {
                                          ...current.posterResult,
                                          detailAddress: {
                                            ...current.posterResult.detailAddress,
                                            en: event.target.value,
                                            zh: current.posterResult.detailAddress.zh || event.target.value,
                                          },
                                        },
                                      }
                                    : current
                                )
                              }
                            />
                          </label>
                        </div>
                      </div>

                      <div className="admin-reference-card p-4">
                        <div className="grid gap-3 lg:grid-cols-[1fr_auto]">
                          <label className="space-y-1 text-xs text-black/45">
                            <span>Timezone Search</span>
                            <input
                              className="admin-studio-input"
                              value={panel.posterResult.timeZoneSearchQuery}
                              onChange={(event) =>
                                setPanel((current) =>
                                  current && current.posterResult
                                    ? {
                                        ...current,
                                        posterResult: {
                                          ...current.posterResult,
                                          timeZoneSearchQuery: event.target.value,
                                        },
                                      }
                                    : current
                                )
                              }
                              placeholder="Search city or timezone"
                            />
                          </label>
                          <button
                            type="button"
                            onClick={() => void searchPosterTimezones()}
                            disabled={timezoneSearching}
                            className="admin-studio-button-secondary px-4 py-2 text-sm self-end"
                          >
                            {timezoneSearching ? 'Searching...' : 'Search Timezone'}
                          </button>
                        </div>
                        <div className="mt-3 rounded-[18px] border border-[#e8eceb] bg-white/70 p-3 text-xs text-black/52">
                          Current: {panel.posterResult.selectedTimeZoneLookup?.label || panel.posterResult.timeZoneIdentifier || 'Not selected'}
                        </div>
                        {timezoneResults.length ? (
                          <div className="mt-3 space-y-2">
                            {timezoneResults.map((item) => (
                              <button
                                key={`${item.timezone}-${item.city}-${item.country}`}
                                type="button"
                                onClick={() =>
                                  setPanel((current) =>
                                    current && current.posterResult
                                      ? {
                                          ...current,
                                          posterResult: {
                                            ...current.posterResult,
                                            selectedTimeZoneLookup: item,
                                            timeZoneIdentifier: item.timezone,
                                            timeZoneDisplayName: item.label,
                                            timeZoneSearchQuery: item.cityAscii || item.city || current.posterResult.timeZoneSearchQuery,
                                          },
                                        }
                                      : current
                                  )
                                }
                                className="flex w-full items-center justify-between gap-3 rounded-[14px] bg-[#f4f6f3] px-3 py-2 text-left text-xs text-[#071110]"
                              >
                                <span>{item.label}</span>
                                <span className="text-black/38">{item.timezone}</span>
                              </button>
                            ))}
                          </div>
                        ) : null}
                      </div>

                      <div className="admin-reference-card p-4">
                        <div className="grid gap-3 lg:grid-cols-3">
                          <label className="space-y-1 text-xs text-black/45">
                            <span>Schedule Mode</span>
                            <select
                              className="admin-studio-input"
                              value={panel.posterResult.scheduleMode}
                              onChange={(event) =>
                                setPanel((current) =>
                                  current && current.posterResult
                                    ? {
                                        ...current,
                                        posterResult: {
                                          ...current.posterResult,
                                          scheduleMode: normalizeScheduleMode(event.target.value),
                                        },
                                      }
                                    : current
                                )
                              }
                            >
                              <option value="single_day">Single Day</option>
                              <option value="multi_day">Multi Day</option>
                              <option value="multi_week">Multi Week</option>
                            </select>
                          </label>
                          <label className="space-y-1 text-xs text-black/45">
                            <span>Start Date</span>
                            <input
                              className="admin-studio-input"
                              value={panel.posterResult.startDate}
                              onChange={(event) =>
                                setPanel((current) =>
                                  current && current.posterResult
                                    ? { ...current, posterResult: { ...current.posterResult, startDate: event.target.value } }
                                    : current
                                )
                              }
                            />
                          </label>
                          <label className="space-y-1 text-xs text-black/45">
                            <span>End Date</span>
                            <input
                              className="admin-studio-input"
                              value={panel.posterResult.endDate}
                              onChange={(event) =>
                                setPanel((current) =>
                                  current && current.posterResult
                                    ? { ...current, posterResult: { ...current.posterResult, endDate: event.target.value } }
                                    : current
                                )
                              }
                            />
                          </label>
                        </div>
                        {panel.posterResult.scheduleMode === 'multi_week' ? (
                          <div className="mt-3 space-y-2">
                            {panel.posterResult.weekRanges.map((week) => (
                              <div key={week.id} className="grid gap-2 lg:grid-cols-3">
                                <input
                                  className="admin-studio-input"
                                  value={week.label}
                                  onChange={(event) =>
                                    setPanel((current) =>
                                      current && current.posterResult
                                        ? {
                                            ...current,
                                            posterResult: {
                                              ...current.posterResult,
                                              weekRanges: current.posterResult.weekRanges.map((currentWeek) =>
                                                currentWeek.id === week.id ? { ...currentWeek, label: event.target.value } : currentWeek
                                              ),
                                            },
                                          }
                                        : current
                                    )
                                  }
                                />
                                <input
                                  className="admin-studio-input"
                                  value={week.startDate}
                                  onChange={(event) =>
                                    setPanel((current) =>
                                      current && current.posterResult
                                        ? {
                                            ...current,
                                            posterResult: {
                                              ...current.posterResult,
                                              weekRanges: current.posterResult.weekRanges.map((currentWeek) =>
                                                currentWeek.id === week.id ? { ...currentWeek, startDate: event.target.value } : currentWeek
                                              ),
                                            },
                                          }
                                        : current
                                    )
                                  }
                                />
                                <input
                                  className="admin-studio-input"
                                  value={week.endDate}
                                  onChange={(event) =>
                                    setPanel((current) =>
                                      current && current.posterResult
                                        ? {
                                            ...current,
                                            posterResult: {
                                              ...current.posterResult,
                                              weekRanges: current.posterResult.weekRanges.map((currentWeek) =>
                                                currentWeek.id === week.id ? { ...currentWeek, endDate: event.target.value } : currentWeek
                                              ),
                                            },
                                          }
                                        : current
                                    )
                                  }
                                />
                              </div>
                            ))}
                          </div>
                        ) : null}
                      </div>

                      <div className="admin-reference-card p-4">
                        <div className="grid gap-3 lg:grid-cols-3">
                          <label className="space-y-1 text-xs text-black/45">
                            <span>Ticket URL</span>
                            <input
                              className="admin-studio-input"
                              value={panel.posterResult.ticketUrl}
                              onChange={(event) =>
                                setPanel((current) =>
                                  current && current.posterResult
                                    ? { ...current, posterResult: { ...current.posterResult, ticketUrl: event.target.value } }
                                    : current
                                )
                              }
                            />
                          </label>
                          <label className="space-y-1 text-xs text-black/45">
                            <span>Currency</span>
                            <input
                              className="admin-studio-input"
                              value={panel.posterResult.ticketCurrency}
                              onChange={(event) =>
                                setPanel((current) =>
                                  current && current.posterResult
                                    ? { ...current, posterResult: { ...current.posterResult, ticketCurrency: event.target.value.toUpperCase() } }
                                    : current
                                )
                              }
                            />
                          </label>
                          <label className="space-y-1 text-xs text-black/45">
                            <span>Ticket Notes</span>
                            <input
                              className="admin-studio-input"
                              value={panel.posterResult.ticketNotes}
                              onChange={(event) =>
                                setPanel((current) =>
                                  current && current.posterResult
                                    ? { ...current, posterResult: { ...current.posterResult, ticketNotes: event.target.value } }
                                    : current
                                )
                              }
                            />
                          </label>
                        </div>
                      </div>
                    </div>
                  ) : (
                    <div className="admin-reference-soft-card p-4 text-sm text-black/48">
                      开始识别海报后，这里会出现可编辑的识别结果。
                    </div>
                  )
                ) : panel.kind === 'lineup' ? (
                  panel.lineupItems.length ? (
                    <div className="space-y-3">
                      <div className="admin-reference-card p-3.5">
                        <div className="flex flex-wrap gap-2">
                          <button
                            type="button"
                            onClick={confirmVisibleAIItems}
                            disabled={!visibleLineupItems.length}
                            className="admin-studio-button-secondary px-3 py-2 text-xs disabled:cursor-not-allowed disabled:opacity-60"
                          >
                            一键确认当前结果
                          </button>
                        </div>
                      </div>
                      {renderResultToolbar(
                        panel.lineupItems.length,
                        panel.lineupItems.filter(isResultItemFullyMatched).length,
                        panel.lineupItems.filter((item) => !isResultItemFullyMatched(item)).length,
                        '搜索 DJ 名称'
                      )}
                      <div className="overflow-hidden rounded-[26px] border border-[#e8eceb] bg-white shadow-[0_18px_48px_rgba(15,23,42,0.06)]">
                        <div className="hidden items-center gap-3 border-b border-[#eef1ee] bg-[#fafcf9] px-3.5 py-2.5 text-[11px] font-semibold tracking-[0.02em] text-black/45 lg:grid lg:grid-cols-[40px_minmax(0,1.9fr)_92px_104px_96px_148px]">
                          <span>#</span>
                          <span>DJ / 艺人</span>
                          <span>演出形式</span>
                          <span>置信度</span>
                          <span>匹配状态</span>
                          <span>操作</span>
                        </div>
                        {visibleLineupItems.length ? (
                          visibleLineupItems.map((item, index) => {
                            const expanded = panel.expandedResultItemIds.includes(item.id);
                            const confidence = resultConfidenceValue(item.confidence);
                            return (
                              <div key={item.id} className="border-t border-[#f1f3f0] first:border-t-0">
                                <div className="grid gap-3 px-3.5 py-3 lg:grid-cols-[40px_minmax(0,1.9fr)_92px_104px_96px_148px] lg:items-center">
                                  <div className="text-sm font-semibold text-black/65">{index + 1}</div>
                                  <div className="flex min-w-0 items-center gap-2.5">
                                    {renderResultAvatarGroup(item)}
                                    <div className="min-w-0 flex-1">
                                      <div className="truncate text-[14px] font-semibold leading-5 text-[#071110]">{performerDisplayName(item)}</div>
                                      <div className="mt-0.5 truncate text-[11px] text-black/42">
                                        {matchedPerformerCount(item)} / {actTypePerformerCount(item.actType)} 已绑定
                                      </div>
                                    </div>
                                  </div>
                                  <div>
                                    <span className="inline-flex rounded-full border border-[#dbe6ff] bg-[#f4f7ff] px-2.5 py-1 text-[11px] font-semibold text-[#3567d6]">
                                      {actTypeLabel(item.actType)}
                                    </span>
                                  </div>
                                  <div>
                                    <div className="text-sm font-semibold leading-5 text-[#071110]">{confidence == null ? '--' : confidence.toFixed(2)}</div>
                                    <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-[#edf1ee]">
                                      <div
                                        className="h-full rounded-full bg-[#23a35d]"
                                        style={{ width: `${Math.round((confidence ?? 0) * 100)}%` }}
                                      />
                                    </div>
                                  </div>
                                  <div>
                                    <span className={`inline-flex rounded-full px-2.5 py-1 text-[11px] font-semibold ${resultItemStatusClassName(item)}`}>
                                      {resultItemStatusLabel(item)}
                                    </span>
                                  </div>
                                  <div className="flex flex-wrap justify-start gap-2 lg:justify-end">
                                    <button
                                      type="button"
                                      onClick={() => toggleExpandedResultItem(item.id)}
                                      className="admin-studio-button-secondary min-w-[68px] whitespace-nowrap px-3 py-2 text-xs"
                                    >
                                      {expanded ? '确认' : '编辑'}
                                    </button>
                                    <button type="button" onClick={() => removeLineupItem(item.id)} className="admin-studio-button-danger min-w-[68px] whitespace-nowrap px-3 py-2 text-xs">
                                      删除
                                    </button>
                                  </div>
                                </div>
                                {expanded ? renderLineupEditPanel(item) : null}
                              </div>
                            );
                          })
                        ) : (
                          <div className="px-5 py-10 text-center text-sm text-black/45">当前搜索条件下没有匹配的识别结果。</div>
                        )}
                      </div>
                    </div>
                  ) : (
                    <div className="admin-reference-soft-card p-4 text-sm text-black/48">
                      开始识别 lineup 后，这里会追加可确认、可编辑的结果列表。
                    </div>
                  )
                ) : panel.timetableSlots.length ? (
                  <div className="space-y-3">
                    <div className="admin-reference-card p-3.5">
                      <div className="flex flex-wrap gap-2">
                        <button
                          type="button"
                          onClick={() =>
                            setPanel((current) =>
                              current
                                ? {
                                    ...current,
                                    selectedTimetableSlotIds: allVisibleTimetableSelected ? [] : visibleTimetableSlotIds,
                                  }
                                : current
                            )
                          }
                          className="admin-studio-button-secondary px-3 py-2 text-xs"
                        >
                          {allVisibleTimetableSelected ? '清空选择' : '全选'}
                        </button>
                        <button
                          type="button"
                          onClick={confirmVisibleAIItems}
                          disabled={!visibleTimetableSlots.length}
                          className="admin-studio-button-secondary px-3 py-2 text-xs disabled:cursor-not-allowed disabled:opacity-60"
                        >
                          一键确认当前结果
                        </button>
                        <button
                          type="button"
                          onClick={() =>
                            moveSelectedTimetableSlots({
                              targetEventDayId: panel.targetEventDayId || ALL_EVENT_DAYS_VALUE,
                              targetStageName: panel.targetStageName || ALL_STAGES_VALUE,
                            })
                          }
                          disabled={!panel.selectedTimetableSlotIds.length}
                          className="admin-studio-button-secondary px-3 py-2 text-xs disabled:cursor-not-allowed disabled:opacity-60"
                        >
                          批量移动
                        </button>
                        <button type="button" onClick={cleanVisibleAIItems} className="admin-studio-button-secondary px-3 py-2 text-xs">
                          清理空白项
                        </button>
                      </div>
                      <div className="mt-2.5 grid gap-3">
                        <label className="space-y-1 text-xs text-black/45">
                          <span>目标活动日</span>
                          <div className="flex gap-2 overflow-x-auto pb-1">
                            <button
                              type="button"
                              onClick={() => updatePanel({ targetEventDayId: ALL_EVENT_DAYS_VALUE })}
                              className={`${aiCompactSelectorChipClass} ${
                                panel.targetEventDayId === ALL_EVENT_DAYS_VALUE
                                  ? 'border-[#cfe0ff] bg-[#eef4ff] text-[#3567d6]'
                                  : 'border-[#e7ece7] bg-white text-black/55 hover:bg-[#f5f7f5]'
                              }`}
                            >
                              全部日期
                            </button>
                            {eventDayTargets(draft).map((day) => {
                              const active = panel.targetEventDayId === day.eventDayId;
                              return (
                                <button
                                  key={day.eventDayId}
                                  type="button"
                                  onClick={() => updatePanel({ targetEventDayId: day.eventDayId })}
                                  className={`${aiCompactSelectorChipClass} ${
                                    active
                                      ? 'border-[#cfe0ff] bg-[#eef4ff] text-[#3567d6]'
                                      : 'border-[#e7ece7] bg-white text-black/55 hover:bg-[#f5f7f5]'
                                  }`}
                                >
                                  {day.label} / {day.date}
                                </button>
                              );
                            })}
                          </div>
                        </label>
                        <label className="space-y-1 text-xs text-black/45">
                          <span>目标舞台</span>
                          <div className="flex gap-2 overflow-x-auto pb-1">
                            <button
                              type="button"
                              onClick={() => updatePanel({ targetStageName: ALL_STAGES_VALUE })}
                              className={`${aiCompactSelectorChipClass} ${
                                panel.targetStageName === ALL_STAGES_VALUE
                                  ? 'border-[#cfe0ff] bg-[#eef4ff] text-[#3567d6]'
                                  : 'border-[#e7ece7] bg-white text-black/55 hover:bg-[#f5f7f5]'
                              }`}
                            >
                              全部舞台
                            </button>
                            {availableStageNames(draft, panel.timetableSlots).map((stage) => {
                              const active = panel.targetStageName === stage;
                              return (
                                <button
                                  key={stage}
                                  type="button"
                                  onClick={() => updatePanel({ targetStageName: stage })}
                                  className={`${aiCompactSelectorChipClass} ${
                                    active
                                      ? 'border-[#cfe0ff] bg-[#eef4ff] text-[#3567d6]'
                                      : 'border-[#e7ece7] bg-white text-black/55 hover:bg-[#f5f7f5]'
                                  }`}
                                >
                                  {stage}
                                </button>
                              );
                            })}
                          </div>
                        </label>
                      </div>
                    </div>
                    {renderResultToolbar(
                      panel.timetableSlots.length,
                      panel.timetableSlots.filter(isResultItemFullyMatched).length,
                      panel.timetableSlots.filter((item) => !isResultItemFullyMatched(item)).length,
                      '搜索 DJ 名称、舞台或时间'
                    )}
                    <div className="overflow-hidden rounded-[26px] border border-[#e8eceb] bg-white shadow-[0_18px_48px_rgba(15,23,42,0.06)]">
                      <div className="hidden items-center gap-3 border-b border-[#eef1ee] bg-[#fafcf9] px-3.5 py-2.5 text-[11px] font-semibold tracking-[0.02em] text-black/45 lg:grid lg:grid-cols-[40px_40px_minmax(0,2fr)_152px_104px_104px_148px]">
                        <span />
                        <span>#</span>
                        <span>DJ / 艺人</span>
                        <span>舞台 / 时间</span>
                        <span>置信度</span>
                        <span>匹配状态</span>
                        <span>操作</span>
                      </div>
                      {visibleTimetableSlots.length ? (
                        visibleTimetableSlots.map((slot, index) => {
                            const expanded = panel.expandedResultItemIds.includes(slot.id);
                            const confidence = resultConfidenceValue(slot.confidence);
                          return (
                            <div key={slot.id} className="border-t border-[#f1f3f0] first:border-t-0">
                              <div className="grid gap-3 px-3.5 py-3 lg:grid-cols-[40px_40px_minmax(0,2fr)_152px_104px_104px_148px] lg:items-center">
                                <div className="flex justify-center">
                                  <input
                                    type="checkbox"
                                    checked={panel.selectedTimetableSlotIds.includes(slot.id)}
                                    onChange={() =>
                                      setPanel((current) =>
                                        current
                                          ? {
                                              ...current,
                                              selectedTimetableSlotIds: current.selectedTimetableSlotIds.includes(slot.id)
                                                ? current.selectedTimetableSlotIds.filter((id) => id !== slot.id)
                                                : [...current.selectedTimetableSlotIds, slot.id],
                                            }
                                          : current
                                      )
                                    }
                                  />
                                </div>
                                <div className="text-sm font-semibold text-black/65">{index + 1}</div>
                                <div className="flex min-w-0 items-center gap-2.5">
                                  {renderResultAvatarGroup(slot)}
                                  <div className="min-w-0 flex-1">
                                    <div className="truncate text-[14px] font-semibold leading-5 text-[#071110]">{performerDisplayName(slot)}</div>
                                    <div className="mt-0.5 truncate text-[11px] text-black/42">
                                      {slot.dayLabel || slot.localDate}
                                      {slot.unresolvedEventDay ? ' · 活动日待确认' : ''}
                                    </div>
                                  </div>
                                </div>
                                <div className="space-y-1.5">
                                  <div className="inline-flex rounded-full border border-[#dbe6ff] bg-[#f4f7ff] px-2.5 py-1 text-[11px] font-semibold text-[#3567d6]">
                                    {slot.stageName || 'Main Stage'}
                                  </div>
                                  <div className="text-[11px] text-black/45">
                                    {slot.startTimeText || '--'} - {slot.endTimeText || '--'}
                                  </div>
                                </div>
                                <div>
                                  <div className="text-sm font-semibold leading-5 text-[#071110]">{confidence == null ? '--' : confidence.toFixed(2)}</div>
                                  <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-[#edf1ee]">
                                    <div
                                      className="h-full rounded-full bg-[#23a35d]"
                                      style={{ width: `${Math.round((confidence ?? 0) * 100)}%` }}
                                    />
                                  </div>
                                </div>
                                <div className="space-y-1.5">
                                  <span className={`inline-flex rounded-full px-2.5 py-1 text-[11px] font-semibold ${resultItemStatusClassName(slot)}`}>
                                    {resultItemStatusLabel(slot)}
                                  </span>
                                  <div className="text-[11px] text-black/45">{actTypeLabel(slot.actType)}</div>
                                  {slot.unresolvedEventDay ? <div className="text-[11px] text-[#a6621a]">日期待确认</div> : null}
                                </div>
                                <div className="flex flex-wrap justify-start gap-2 lg:justify-end">
                                  <button
                                    type="button"
                                    onClick={() => toggleExpandedResultItem(slot.id)}
                                    className="admin-studio-button-secondary min-w-[68px] whitespace-nowrap px-3 py-2 text-xs"
                                  >
                                    {expanded ? '确认' : '编辑'}
                                  </button>
                                  <button type="button" onClick={() => removeTimetableSlot(slot.id)} className="admin-studio-button-danger min-w-[68px] whitespace-nowrap px-3 py-2 text-xs">
                                    删除
                                  </button>
                                </div>
                              </div>
                              {expanded ? renderTimetableEditPanel(slot) : null}
                            </div>
                          );
                        })
                      ) : (
                        <div className="px-5 py-10 text-center text-sm text-black/45">当前搜索条件下没有匹配的识别结果。</div>
                      )}
                    </div>
                  </div>
                ) : (
                  <div className="admin-reference-soft-card p-4 text-sm text-black/48">
                    开始识别 timetable 后，这里会追加可确认、可编辑的结果列表。
                  </div>
                )}
                  </div>
                </div>
              </div>
            </div>
          </div>
          <OverlayImageViewer
            assets={previewAssets}
            activeIndex={previewAssetIndex}
            onClose={() => setPreviewAssetIndex(null)}
            onChange={setPreviewAssetIndex}
          />
        </div>
      ) : null}
    </div>
  );
}
