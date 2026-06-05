'use client';

import Image from 'next/image';
import { useMemo, useRef, useState } from 'react';
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

type ImportPanelKind = EventStudioImportJobKind;
type EventStudioAIEntryMode = 'all' | 'single' | 'hidden';

type EventStudioAIActType = 'solo' | 'b2b' | 'b3b';

type EventStudioAIEditableLineupItem = {
  id: string;
  actType: EventStudioAIActType;
  performerNamesText: string;
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
  message: string;
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
  'admin-studio-input h-9 min-h-9 rounded-[14px] px-3 py-1.5 pr-8 text-[13px] leading-5';

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

const normalizeActType = (value: unknown, performerCount = 0): EventStudioAIActType => {
  const normalized = safeString(value).toLowerCase();
  if (normalized === 'b3b') return 'b3b';
  if (normalized === 'b2b') return 'b2b';
  if (performerCount >= 3) return 'b3b';
  if (performerCount === 2) return 'b2b';
  return 'solo';
};

const actTypePerformerCount = (value: unknown): number =>
  ACT_TYPE_ITEMS.find((item) => item.value === normalizeActType(value))?.count ?? 1;

const splitPerformerNames = (value: string): string[] =>
  value
    .split(/[\/,&]/)
    .map((item) => item.trim())
    .filter(Boolean);

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
      const names = Array.isArray(item?.performerNames)
        ? item.performerNames.map((name: unknown) => safeString(name)).filter(Boolean)
        : [];
      const fallbackNames = names.length
        ? names
        : splitPerformerNames(firstFilledText(item?.displayName, item?.rawText).replace(/\bB2B\b|\bB3B\b/gi, '/'));
      const actType = normalizeActType(item?.performerType, fallbackNames.length);
      const count = actTypePerformerCount(actType);
      const normalizedNames = fallbackNames.slice(0, count);
      if (!normalizedNames.length) return null;
      return {
        id: crypto.randomUUID(),
        actType,
        performerNamesText: normalizedNames.join(' / '),
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
                        const fallbackNames = rawNames.length
                          ? rawNames
                          : splitPerformerNames(firstFilledText(slot?.displayName, slot?.rawText).replace(/\bB2B\b|\bB3B\b/gi, '/'));
                        const actType = normalizeActType(slot?.performerType, fallbackNames.length);
                        const count = actTypePerformerCount(actType);
                        const names = fallbackNames.slice(0, count);
                        if (!names.length) return null;
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
                          actType,
                          performerNamesText: names.join(' / '),
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
  const actType = normalizeActType(item.actType, splitPerformerNames(item.performerNamesText).length);
  const count = actTypePerformerCount(actType);
  const names = splitPerformerNames(item.performerNamesText).slice(0, count);
  return {
    ...item,
    actType,
    performerNamesText: names.join(' / '),
    performerDJIDs: normalizePerformerIds(item.performerDJIDs, count),
    performerAvatarURLs: normalizePerformerAvatarURLs(item.performerAvatarURLs, count),
  } as T;
};

const compactEditableAct = <T extends EventStudioAIEditableLineupItem | EventStudioAIEditableTimetableSlot>(item: T): T | null => {
  const normalized = normalizeEditableAct(item);
  const names = splitPerformerNames(normalized.performerNamesText);
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

  const nextActType = normalizeActType(normalized.actType, compactNames.length);
  const nextCount = actTypePerformerCount(nextActType);
  return {
    ...normalized,
    actType: nextActType,
    performerNamesText: compactNames.join(' / '),
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
      return 'Preparing';
    case 'polling':
      return task.pollStatus === 'running' ? 'Recognizing' : 'Queued';
    case 'auto_matching':
      return 'Auto matching DJs';
    case 'succeeded':
      return 'Completed';
    case 'failed':
      return 'Failed';
    case 'cancelled':
      return 'Cancelled';
    default:
      return 'Pending';
  }
};

const imageOriginLabel = (origin: EventStudioImageState['origin']): string => {
  if (origin === 'persisted-event') return 'Persisted event image';
  if (origin === 'event-upload') return 'Uploaded in edit flow';
  return 'Uploaded in current draft';
};

const selectedCountLabel = (panel: ImportPanelState | null): string => {
  if (!panel) return '0 selected';
  return `${panel.selectedImageIds.length} selected`;
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

  const selectedPosterImage = useMemo(() => {
    if (!panel || panel.kind !== 'poster') return null;
    return selectedImages[0] || selectedImageOptions[0] || null;
  }, [panel, selectedImageOptions, selectedImages]);

  const unresolvedTimetableSlots = panel?.kind === 'timetable' ? panel.timetableSlots.filter(hasUnresolvedTimetableDay) : [];

  const updatePanel = (patch: Partial<ImportPanelState>) => {
    setPanel((current) => (current ? { ...current, ...patch } : current));
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
      targetEventDayId: draft.eventDays[0]?.eventDayId || '',
      targetStageName: draft.stageOrder[0] || 'Main Stage',
      warnings: [],
      unparsedTexts: [],
      taskEntries: [],
      autoMatching: false,
      autoMatchStartedAt: null,
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

  const exactMatchLineupItems = async (items: EventStudioAIEditableLineupItem[]): Promise<EventStudioAIEditableLineupItem[]> => {
    const unresolvedNames = items.flatMap((item) =>
      splitPerformerNames(item.performerNamesText)
        .slice(0, actTypePerformerCount(item.actType))
        .flatMap((name, performerIndex) => {
          const bound = item.performerDJIDs[performerIndex];
          return bound ? [] : [name];
        })
    );
    if (!unresolvedNames.length) return items;

    const matches = await eventStudioApi.matchExactDJs(unresolvedNames);
    if (!matches.length) return items;

    const lookup = new Map<string, (typeof matches)[number]>();
    for (const match of matches) {
      lookup.set(normalizeDJLookupKey(match.query), match);
      lookup.set(normalizeDJLookupKey(match.name), match);
      for (const alias of match.aliases || []) {
        lookup.set(normalizeDJLookupKey(alias), match);
      }
    }

    return items.map((item) => {
      const performerNames = splitPerformerNames(item.performerNamesText).slice(0, actTypePerformerCount(item.actType));
      const performerDJIDs = [...item.performerDJIDs];
      const performerAvatarURLs = [...item.performerAvatarURLs];
      performerNames.forEach((name, performerIndex) => {
        if (performerDJIDs[performerIndex]) return;
        const match = lookup.get(normalizeDJLookupKey(name));
        if (!match) return;
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
  };

  const exactMatchTimetableSlots = async (
    slots: EventStudioAIEditableTimetableSlot[]
  ): Promise<EventStudioAIEditableTimetableSlot[]> => {
    const unresolvedNames = slots.flatMap((slot) =>
      splitPerformerNames(slot.performerNamesText)
        .slice(0, actTypePerformerCount(slot.actType))
        .flatMap((name, performerIndex) => {
          const bound = slot.performerDJIDs[performerIndex];
          return bound ? [] : [name];
        })
    );
    if (!unresolvedNames.length) return slots;

    const matches = await eventStudioApi.matchExactDJs(unresolvedNames);
    if (!matches.length) return slots;

    const lookup = new Map<string, (typeof matches)[number]>();
    for (const match of matches) {
      lookup.set(normalizeDJLookupKey(match.query), match);
      lookup.set(normalizeDJLookupKey(match.name), match);
      for (const alias of match.aliases || []) {
        lookup.set(normalizeDJLookupKey(alias), match);
      }
    }

    return slots.map((slot) => {
      const performerNames = splitPerformerNames(slot.performerNamesText).slice(0, actTypePerformerCount(slot.actType));
      const performerDJIDs = [...slot.performerDJIDs];
      const performerAvatarURLs = [...slot.performerAvatarURLs];
      performerNames.forEach((name, performerIndex) => {
        if (performerDJIDs[performerIndex]) return;
        const match = lookup.get(normalizeDJLookupKey(name));
        if (!match) return;
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
            ? 'Queued in Coze.'
            : snapshot.status === 'running'
              ? 'Recognition is running.'
              : snapshot.status === 'succeeded'
                ? 'Recognition completed.'
                : snapshot.status === 'cancelled'
                  ? 'Recognition cancelled.'
                  : snapshot.error || 'Recognition failed.',
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
      message: 'Preparing image and request payload.',
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
            ? 'Poster recognition started.'
            : `Started ${images.length} recognition task${images.length > 1 ? 's' : ''}.`,
        taskEntries: nextTaskEntries,
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
            message: 'Creating import job.',
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
            message: 'Job created. Polling result.',
          });

          const snapshot = await pollJob(panel.kind, job.jobId, taskId, runToken);
          if (!snapshot || cancelRequestedRef.current || runToken !== runTokenRef.current) return;

          if (snapshot.status === 'failed') {
            updateTaskEntry(taskId, {
              phase: 'failed',
              message: snapshot.error || 'Recognition failed.',
            });
            return;
          }

          if (snapshot.status === 'cancelled') {
            updateTaskEntry(taskId, {
              phase: 'cancelled',
              message: 'Recognition cancelled.',
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
              message: 'Poster result is ready for review.',
            });
            return;
          }

          updateTaskEntry(taskId, {
            phase: 'auto_matching',
            message: 'Running exact DJ matching.',
          });

          if (panel.kind === 'lineup') {
            const parsed = parseLineupEditableItems(rawRecord);
            const matched = await exactMatchLineupItems(parsed);
            if (cancelRequestedRef.current || runToken !== runTokenRef.current) return;
            appendLineupItems(matched, warnings, unparsedTexts, snapshot.result?.rawJson ?? null);
            updateTaskEntry(taskId, {
              phase: 'succeeded',
              resultCount: matched.length,
              warningCount: warnings.length,
              message: `Imported ${matched.length} lineup item${matched.length === 1 ? '' : 's'}.`,
            });
            return;
          }

          const parsed = parseTimetableEditableSlots(rawRecord, draft);
          const matched = await exactMatchTimetableSlots(parsed);
          if (cancelRequestedRef.current || runToken !== runTokenRef.current) return;
          appendTimetableSlots(matched, warnings, unparsedTexts, snapshot.result?.rawJson ?? null);
          updateTaskEntry(taskId, {
            phase: 'succeeded',
            resultCount: matched.length,
            warningCount: warnings.length,
            message: `Imported ${matched.length} timetable slot${matched.length === 1 ? '' : 's'}.`,
          });
        } catch (error) {
          updateTaskEntry(taskId, {
            phase: 'failed',
            message: error instanceof Error ? error.message : 'Recognition failed.',
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
            ? 'All recognition tasks were cancelled.'
            : `Recognition finished: ${succeededCount} succeeded, ${failedCount + current.taskEntries.filter((task) => task.phase === 'failed').length} failed${cancelledCount ? `, ${cancelledCount} cancelled` : ''}.`,
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
        statusText: 'Recognition cancelled.',
        taskEntries: current.taskEntries.map((task) =>
          task.phase === 'succeeded' || task.phase === 'failed'
            ? task
            : { ...task, phase: 'cancelled', message: 'Recognition cancelled.', updatedAt: Date.now() }
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
      };
    });
  };

  const moveSelectedTimetableSlots = (target: EventStudioAIResultTarget) => {
    setPanel((current) => {
      if (!current || !current.selectedTimetableSlotIds.length) return current;
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

  const cleanVisibleAIItems = () => {
    if (!panel) return;
    if (panel.kind === 'lineup') {
      setPanel((current) => {
        if (!current) return current;
        return {
          ...current,
          lineupItems: compactEditableLineupItems(current.lineupItems),
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
        };
      });
    }
  };

  const autoMatchAIItems = async () => {
    if (!panel || panel.kind === 'poster') return;
    updatePanel({
      autoMatching: true,
      autoMatchStartedAt: Date.now(),
      errorText: null,
      statusText: 'Running exact DJ matching.',
    });
    try {
      if (panel.kind === 'lineup') {
        const matched = await exactMatchLineupItems(panel.lineupItems);
        setPanel((current) => (current && current.kind === 'lineup' ? { ...current, lineupItems: matched } : current));
      } else {
        const matched = await exactMatchTimetableSlots(panel.timetableSlots);
        setPanel((current) => (current && current.kind === 'timetable' ? { ...current, timetableSlots: matched } : current));
      }
      updatePanel({
        autoMatching: false,
        statusText: 'Exact DJ matching completed.',
      });
    } catch (error) {
      updatePanel({
        autoMatching: false,
        errorText: error instanceof Error ? error.message : 'Exact DJ matching failed.',
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
    const names = splitPerformerNames(item.performerNamesText);
    const query = names[performerIndex] || names[0] || '';
    const results = djSearchResults[key] || [];
    const isSearching = Boolean(djSearchLoadingKeys[key]);
    const avatar = item.performerAvatarURLs[performerIndex];

    return (
      <div key={`${item.id}-${performerIndex}`} className="rounded-[16px] border border-[#e8eceb] bg-white/70 p-2.5">
        <div className="mb-1.5 flex items-center gap-2 text-[11px] text-black/45">
          <span>Performer {performerIndex + 1}</span>
          {avatar ? (
            <span className="inline-flex h-7 w-7 overflow-hidden rounded-full border border-[#e8eceb] bg-[#f4f6f3]">
              <Image src={avatar} alt="" width={28} height={28} className="h-7 w-7 object-cover" />
            </span>
          ) : null}
        </div>
        <div className="flex flex-wrap items-center gap-2">
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
            placeholder={`DJ ID ${performerIndex + 1}`}
          />
          <button
            type="button"
            onClick={() => void searchAIImportDJ(scope, item.id, performerIndex, query)}
            disabled={isSearching || !query}
            className="admin-studio-button-secondary px-3 py-2 text-xs disabled:cursor-not-allowed disabled:opacity-60"
          >
            {isSearching ? 'Searching' : 'Search'}
          </button>
          <button
            type="button"
            onClick={() => clearAIImportDJBinding(scope, item.id, performerIndex)}
            className="admin-studio-button-secondary px-3 py-2 text-xs"
          >
            Clear
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
          const names = splitPerformerNames(item.performerNamesText).slice(0, actTypePerformerCount(item.actType));
          if (!names.length) return null;
          return {
            id: crypto.randomUUID(),
            canonicalArtistId: null,
            djId: item.performerDJIDs.find(Boolean) || '',
            memberDjIds: normalizePerformerIds(item.performerDJIDs, actTypePerformerCount(item.actType)),
            memberNamesText: names.join(' / '),
            actType: item.actType,
            sortOrder: draft.lineupArtists.length + index + 1,
          };
        })
        .filter((item): item is EventStudioDraft['lineupArtists'][number] => item !== null);

      setDraft((current) => ({
        ...current,
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
        const names = splitPerformerNames(slot.performerNamesText).slice(0, actTypePerformerCount(slot.actType));
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
                  <div className="mt-3 text-xs text-black/40">Available images: {count}</div>
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
        <div className="fixed inset-0 z-50 overflow-y-auto bg-black/45 p-3">
          <div className="flex min-h-full items-end justify-center sm:items-center">
            <div className="flex max-h-[calc(100vh-1.5rem)] w-full max-w-6xl flex-col overflow-hidden rounded-[28px] border border-[#e8eceb] bg-[#fbfcfa] shadow-2xl sm:max-h-[calc(100vh-3rem)]">
              <div className="flex flex-shrink-0 items-start justify-between gap-4 border-b border-[#e8eceb] px-5 py-4">
              <div>
                <div className="admin-studio-label">{PANEL_ITEMS.find((item) => item.kind === panel.kind)?.title}</div>
                <div className="mt-2 text-sm leading-6 text-black/52">{panel.errorText || panel.statusText}</div>
              </div>
              <div className="flex items-center gap-2">
                <button type="button" onClick={() => void cancelRecognition()} className="admin-studio-button-secondary px-4 py-2 text-sm">
                  {panel.running ? 'Cancel' : 'Close'}
                </button>
                <button
                  type="button"
                  onClick={() => void startRecognition()}
                  disabled={(panel.kind === 'poster' ? !selectedPosterImage : !selectedImages.length) || panel.running}
                  className={`admin-ai-action-button px-4 py-2 text-sm ${
                    panel.running ? 'admin-ai-action-button-running' : ''
                  } disabled:cursor-not-allowed disabled:opacity-60`}
                >
                  {panel.running ? 'Running...' : 'Start Recognition'}
                </button>
              </div>
              </div>

              <div className="min-h-0 flex-1 overflow-y-auto">
                <div className="grid gap-5 p-5 lg:grid-cols-[0.88fr_1.12fr]">
                  <div className="space-y-4">
                    <div className="admin-reference-card p-4">
                      <div className="flex items-center justify-between gap-3">
                        <div className="text-sm font-semibold text-[#071110]">Choose Images</div>
                        <div className="text-xs text-black/40">{selectedCountLabel(panel)}</div>
                      </div>
                      <div className="mt-3 grid gap-3 sm:grid-cols-2">
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
                            <button
                              key={image.id}
                              type="button"
                              onClick={toggle}
                              className={`overflow-hidden rounded-[22px] border text-left ${
                                checked ? 'border-[#3aa66b]' : 'border-[#e8eceb]'
                              } bg-white`}
                            >
                              <div className="relative aspect-[4/3] bg-[#f2f3ef]">
                                <Image src={image.remoteUrl} alt={image.fileName} fill className="object-cover" sizes="420px" />
                              </div>
                              <div className="flex items-start justify-between gap-3 px-4 py-3">
                                <div className="min-w-0">
                                  <div className="truncate text-sm font-medium text-[#071110]">{image.fileName}</div>
                                  <div className="mt-1 text-xs text-black/40">{imageOriginLabel(image.origin)}</div>
                                </div>
                                <input readOnly type={panel.kind === 'poster' ? 'radio' : 'checkbox'} checked={checked} />
                              </div>
                            </button>
                          );
                        })}
                      </div>
                    </div>

                    <div className="admin-reference-card p-4">
                      <div className="text-sm font-semibold text-[#071110]">Task Progress</div>
                      {panel.taskEntries.length ? (
                        <div className="mt-3 space-y-2">
                          {panel.taskEntries.map((task) => (
                            <div key={task.id} className="rounded-[18px] border border-[#e8eceb] bg-white/80 p-3">
                              <div className="flex items-center justify-between gap-3">
                                <div className="min-w-0">
                                  <div className="truncate text-sm font-medium text-[#071110]">{task.imageFileName}</div>
                                  <div className="mt-1 text-xs text-black/40">{imageOriginLabel(task.imageOrigin)}</div>
                                </div>
                                <div className="rounded-full bg-[#f4f6f3] px-3 py-1 text-xs text-[#071110]">{taskPhaseLabel(task)}</div>
                              </div>
                              <div className="mt-2 text-xs leading-5 text-black/52">{task.message}</div>
                              {task.resultCount || task.warningCount ? (
                                <div className="mt-2 text-xs text-black/38">
                                  Results: {task.resultCount} / Warnings: {task.warningCount}
                                </div>
                              ) : null}
                            </div>
                          ))}
                        </div>
                      ) : (
                        <div className="mt-3 text-sm text-black/48">No recognition task has started yet.</div>
                      )}
                    </div>
                  </div>

                  <div className="space-y-4">
                <div className="admin-reference-card p-4">
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <div className="text-sm font-semibold text-[#071110]">Recognition Result</div>
                      <div className="mt-1 text-xs text-black/40">Review the editable result first, then apply it into the draft.</div>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      {panel.kind !== 'poster' ? (
                        <button
                          type="button"
                          onClick={() => void autoMatchAIItems()}
                          disabled={panel.autoMatching || panel.running}
                          className="admin-studio-button-secondary px-4 py-2 text-sm disabled:cursor-not-allowed disabled:opacity-60"
                        >
                          {panel.autoMatching ? 'Matching...' : 'Auto Match DJs'}
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
                        Apply Result
                      </button>
                    </div>
                  </div>

                  {panel.warnings.length || panel.unparsedTexts.length ? (
                    <div className="mt-3 rounded-[18px] border border-[#f0dcc5] bg-[#fff7ef] p-3 text-xs text-[#7c4d20]">
                      <div className="flex items-center justify-between gap-3">
                        <div>
                          Warnings: {panel.warnings.length} / Unparsed: {panel.unparsedTexts.length}
                        </div>
                        <button
                          type="button"
                          onClick={() => updatePanel({ warningsExpanded: !panel.warningsExpanded })}
                          className="admin-studio-button-secondary px-3 py-1.5 text-xs"
                        >
                          {panel.warningsExpanded ? 'Hide Details' : 'Show Details'}
                        </button>
                      </div>
                      {panel.warningsExpanded ? (
                        <div className="mt-2 space-y-2">
                          {panel.warnings.length ? <div>Warnings: {panel.warnings.join(' / ')}</div> : null}
                          {panel.unparsedTexts.length ? <div>Unparsed: {panel.unparsedTexts.join(' / ')}</div> : null}
                        </div>
                      ) : null}
                    </div>
                  ) : null}

                  {panel.kind === 'timetable' && unresolvedTimetableSlots.length ? (
                    <div className="mt-3 rounded-[18px] border border-[#f0d0d0] bg-[#fff3f3] p-3 text-xs text-[#8a3e3e]">
                      {unresolvedTimetableSlots.length} timetable slot(s) still need manual event-day resolution before apply.
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
                      Start poster recognition to get an editable result here.
                    </div>
                  )
                ) : panel.kind === 'lineup' ? (
                  panel.lineupItems.length ? (
                    <div className="space-y-3">
                      {panel.lineupItems.map((item, index) => {
                        const count = actTypePerformerCount(item.actType);
                        const names = splitPerformerNames(item.performerNamesText);
                        return (
                          <div key={item.id} className="admin-reference-card p-3.5">
                            <div className="flex items-start justify-between gap-3">
                              <div className="text-sm font-semibold text-[#071110]">Lineup #{index + 1}</div>
                              <button type="button" onClick={() => removeLineupItem(item.id)} className="admin-studio-button-danger px-3 py-1.5 text-xs">
                                Remove
                              </button>
                            </div>
                            <div className="mt-2.5 grid gap-2 lg:grid-cols-5">
                              <select
                                className={aiCompactSelectClass}
                                value={item.actType}
                                onChange={(event) =>
                                  updateLineupItem(item.id, (current) =>
                                    normalizeEditableAct({
                                      ...current,
                                      actType: normalizeActType(event.target.value, splitPerformerNames(current.performerNamesText).length),
                                    })
                                  )
                                }
                              >
                                {ACT_TYPE_ITEMS.map((act) => (
                                  <option key={act.value} value={act.value}>
                                    {act.label}
                                  </option>
                                ))}
                              </select>
                              <input
                                className={`${aiCompactInputClass} lg:col-span-2`}
                                value={item.performerNamesText}
                                onChange={(event) =>
                                  updateLineupItem(item.id, (current) =>
                                    normalizeEditableAct({
                                      ...current,
                                      performerNamesText: event.target.value,
                                    })
                                  )
                                }
                              />
                              <input
                                className={aiCompactInputClass}
                                value={String(item.confidence ?? '')}
                                onChange={(event) =>
                                  updateLineupItem(item.id, (current) => ({
                                    ...current,
                                    confidence: event.target.value ? Number(event.target.value) : null,
                                  }))
                                }
                                placeholder="Confidence"
                              />
                              <div className="rounded-[14px] border border-[#e8eceb] bg-[#f8faf8] px-3 py-2 text-[11px] leading-5 text-black/45">
                                {names.join(' / ')}
                              </div>
                            </div>
                            <div className="mt-2.5 grid gap-1.5">
                              {Array.from({ length: count }).map((_, performerIndex) => renderDJBindingControls('lineup', item, performerIndex))}
                            </div>
                            <div className="mt-2 text-xs text-black/40">{item.notes.join(' / ') || 'No notes'}</div>
                          </div>
                        );
                      })}
                    </div>
                  ) : (
                    <div className="admin-reference-soft-card p-4 text-sm text-black/48">
                      Start lineup recognition to append editable lineup results here.
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
                                    selectedTimetableSlotIds: current.selectedTimetableSlotIds.length
                                      ? []
                                      : current.timetableSlots.map((slot) => slot.id),
                                  }
                                : current
                            )
                          }
                          className="admin-studio-button-secondary px-3 py-2 text-xs"
                        >
                          {panel.selectedTimetableSlotIds.length ? 'Clear Selection' : 'Select All'}
                        </button>
                        <button
                          type="button"
                          onClick={() =>
                            moveSelectedTimetableSlots({
                              targetEventDayId: panel.targetEventDayId || draft.eventDays[0]?.eventDayId || '',
                              targetStageName: panel.targetStageName || 'Main Stage',
                            })
                          }
                          disabled={!panel.selectedTimetableSlotIds.length}
                          className="admin-studio-button-secondary px-3 py-2 text-xs disabled:cursor-not-allowed disabled:opacity-60"
                        >
                          Move Selected
                        </button>
                        <button type="button" onClick={cleanVisibleAIItems} className="admin-studio-button-secondary px-3 py-2 text-xs">
                          Clean Empty Items
                        </button>
                      </div>
                      <div className="mt-2.5 grid gap-2 lg:grid-cols-2">
                        <label className="space-y-1 text-xs text-black/45">
                          <span>Target Event Day</span>
                          <select
                            className={aiCompactSelectClass}
                            value={panel.targetEventDayId}
                            onChange={(event) => updatePanel({ targetEventDayId: event.target.value })}
                          >
                            {eventDayTargets(draft).map((day) => (
                              <option key={day.eventDayId} value={day.eventDayId}>
                                {day.label} / {day.date}
                              </option>
                            ))}
                          </select>
                        </label>
                        <label className="space-y-1 text-xs text-black/45">
                          <span>Target Stage</span>
                          <select
                            className={aiCompactSelectClass}
                            value={panel.targetStageName}
                            onChange={(event) => updatePanel({ targetStageName: event.target.value })}
                          >
                            {availableStageNames(draft, panel.timetableSlots).map((stage) => (
                              <option key={stage} value={stage}>
                                {stage}
                              </option>
                            ))}
                          </select>
                        </label>
                      </div>
                    </div>

                    {panel.timetableSlots.map((slot) => (
                      <div key={slot.id} className="admin-reference-card p-3.5">
                        <div className="flex items-start justify-between gap-3">
                          <div className="flex items-center gap-3">
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
                            <div>
                              <div className="text-sm font-semibold text-[#071110]">Timetable #{slot.sortOrder}</div>
                              <div className="mt-1 text-xs text-black/40">
                                {slot.dayLabel || slot.localDate} / {slot.stageName}
                              </div>
                            </div>
                          </div>
                          <div className="flex items-center gap-2">
                            {slot.unresolvedEventDay ? (
                              <span className="rounded-full bg-[#fff3f3] px-3 py-1 text-xs text-[#8a3e3e]">Unresolved Day</span>
                            ) : null}
                            <button type="button" onClick={() => removeTimetableSlot(slot.id)} className="admin-studio-button-danger px-3 py-1.5 text-xs">
                              Remove
                            </button>
                          </div>
                        </div>
                        <div className="mt-2.5 grid gap-2 lg:grid-cols-5">
                          <select
                            className={aiCompactSelectClass}
                            value={slot.actType}
                            onChange={(event) =>
                              updateTimetableSlot(slot.id, (current) =>
                                normalizeEditableAct({
                                  ...current,
                                  actType: normalizeActType(event.target.value, splitPerformerNames(current.performerNamesText).length),
                                })
                              )
                            }
                          >
                            {ACT_TYPE_ITEMS.map((act) => (
                              <option key={act.value} value={act.value}>
                                {act.label}
                              </option>
                            ))}
                          </select>
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
                                      eventDayResolutionReason: 'Resolved manually in web editor.',
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
                          <input
                            className={aiCompactInputClass}
                            value={slot.stageName}
                            onChange={(event) => updateTimetableSlot(slot.id, (current) => ({ ...current, stageName: event.target.value }))}
                            placeholder="Stage"
                          />
                          <input
                            className={`${aiCompactInputClass} lg:col-span-2`}
                            value={slot.performerNamesText}
                            onChange={(event) => updateTimetableSlot(slot.id, (current) => ({ ...current, performerNamesText: event.target.value }))}
                          />
                          <input
                            className={aiCompactInputClass}
                            value={slot.startTimeText}
                            onChange={(event) => updateTimetableSlot(slot.id, (current) => ({ ...current, startTimeText: event.target.value }))}
                            placeholder="Start"
                          />
                          <input
                            className={aiCompactInputClass}
                            value={slot.endTimeText}
                            onChange={(event) => updateTimetableSlot(slot.id, (current) => ({ ...current, endTimeText: event.target.value }))}
                            placeholder="End"
                          />
                          <select
                            className={aiCompactSelectClass}
                            value={String(slot.startDayOffset)}
                            onChange={(event) =>
                              updateTimetableSlot(slot.id, (current) => ({ ...current, startDayOffset: Number(event.target.value) || 0 }))
                            }
                          >
                            <option value="0">Start same day</option>
                            <option value="1">Start next day</option>
                          </select>
                          <select
                            className={aiCompactSelectClass}
                            value={String(slot.endDayOffset)}
                            onChange={(event) =>
                              updateTimetableSlot(slot.id, (current) => ({ ...current, endDayOffset: Number(event.target.value) || 0 }))
                            }
                          >
                            <option value="0">End same day</option>
                            <option value="1">End next day</option>
                          </select>
                        </div>
                        {slot.eventDayResolutionReason ? (
                          <div className="mt-2 text-xs text-black/40">
                            Resolution: {slot.eventDayResolutionReason}
                            {slot.eventDayResolutionConfidence != null ? ` / Confidence ${slot.eventDayResolutionConfidence}` : ''}
                          </div>
                        ) : null}
                        <div className="mt-2.5 grid gap-1.5">
                          {Array.from({ length: actTypePerformerCount(slot.actType) }).map((_, performerIndex) =>
                            renderDJBindingControls('timetable', slot, performerIndex)
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="admin-reference-soft-card p-4 text-sm text-black/48">
                    Start timetable recognition to append editable timetable results here.
                  </div>
                )}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
