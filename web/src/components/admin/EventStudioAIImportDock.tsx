'use client';

import Image from 'next/image';
import { useMemo, useRef, useState } from 'react';
import { DJAggregatorAPI } from '@/lib/api';
import {
  eventStudioApi,
  syncEventStudioScheduleStructure,
  type EventStudioDraft,
  type EventStudioImportJobKind,
  type EventStudioImageState,
  type EventStudioImageUsage,
  type EventStudioScheduleMode,
  type EventStudioWeekDraft,
} from '@/features/admin-content/event-studio';

type ImportPanelKind = EventStudioImportJobKind;

type ImportPanelState = {
  kind: ImportPanelKind;
  selectedImageId: string;
  running: boolean;
  jobId: string | null;
  statusText: string;
  errorText: string | null;
  resultJson: unknown | null;
  lineupItems: EventStudioAIEditableLineupItem[];
  timetableSlots: EventStudioAIEditableTimetableSlot[];
  selectedTimetableSlotIds: string[];
  warnings: string[];
  unparsedTexts: string[];
};

type EventStudioAIActType = 'solo' | 'b2b' | 'b3b';

type EventStudioAIEditableLineupItem = {
  id: string;
  actType: EventStudioAIActType;
  performerNamesText: string;
  performerDJIDs: Array<string | null>;
  confidence?: number | null;
  notes: string[];
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
  sortOrder: number;
};

const PANEL_ITEMS: Array<{
  kind: ImportPanelKind;
  title: string;
  description: string;
  zones: EventStudioImageUsage[];
}> = [
  { kind: 'poster', title: 'Poster 导入', description: '识别活动基础信息、时间、地点与票务。', zones: ['poster', 'cover'] },
  { kind: 'timetable', title: 'Timetable 导入', description: '识别时间表、舞台与演出时段。', zones: ['timetable'] },
  { kind: 'lineup', title: 'Lineup 导入', description: '识别阵容图中的艺人列表。', zones: ['lineup'] },
];

const firstFilledText = (...values: Array<string | undefined | null>) => {
  for (const value of values) {
    const trimmed = String(value || '').trim();
    if (trimmed) return trimmed;
  }
  return '';
};

const safeString = (value: unknown): string => (typeof value === 'string' ? value.trim() : '');

const ACT_TYPE_ITEMS: Array<{ value: EventStudioAIActType; label: string; count: number }> = [
  { value: 'solo', label: 'Solo', count: 1 },
  { value: 'b2b', label: 'B2B', count: 2 },
  { value: 'b3b', label: 'B3B', count: 3 },
];

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

const normalizeDateOnly = (value: string): string => value.trim().slice(0, 10);

const normalizePerformerIds = (ids: unknown, count: number): Array<string | null> => {
  const source = Array.isArray(ids) ? ids : [];
  return Array.from({ length: count }, (_, index) => {
    const trimmed = safeString(source[index]);
    return trimmed || null;
  });
};

const normalizeWarnings = (raw: Record<string, any>): string[] =>
  (Array.isArray(raw.warnings) ? raw.warnings : [])
    .map((item) => safeString(item))
    .filter(Boolean);

const normalizeUnparsedTexts = (raw: Record<string, any>): string[] =>
  (Array.isArray(raw.unparsedTexts ?? raw.unparsed_texts) ? raw.unparsedTexts ?? raw.unparsed_texts : [])
    .map((item: unknown) => safeString(item))
    .filter(Boolean);

const findImportImage = (
  draft: EventStudioDraft,
  kind: ImportPanelKind
): EventStudioImageState | null => {
  const config = PANEL_ITEMS.find((item) => item.kind === kind);
  if (!config) return null;
  const candidates = config.zones.flatMap((zone) => draft.imageZones[zone] || []);
  return [...candidates].sort((left, right) => left.sortOrder - right.sortOrder)[0] || null;
};

const resolvedTimeZoneSelection = (draft: EventStudioDraft, raw: any) => {
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
    label: `${city || 'Unknown'} · ${timeZone}${displayName && displayName !== timeZone ? ` · ${displayName}` : ''}`,
    matchSource: 'web-ai-import',
  };
};

const normalizeWeekRanges = (raw: unknown): EventStudioWeekDraft[] => {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((item, index) => {
      if (!item || typeof item !== 'object') return null;
      const record = item as Record<string, unknown>;
      const startDate = safeString(record.startDate ?? record.start_date);
      const endDate = safeString(record.endDate ?? record.end_date);
      if (!startDate || !endDate) return null;
      return {
        id: crypto.randomUUID(),
        weekIndex: Number.isFinite(Number(record.weekIndex)) ? Math.max(1, Math.floor(Number(record.weekIndex))) : index + 1,
        label: safeString(record.label || record.weekLabel) || `Week ${index + 1}`,
        startDate,
        endDate,
        sortOrder: Number.isFinite(Number(record.sortOrder)) ? Math.max(1, Math.floor(Number(record.sortOrder))) : index + 1,
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

const importImageOptions = (
  draft: EventStudioDraft,
  kind: ImportPanelKind
): EventStudioImageState[] => {
  if (kind === 'poster') {
    return [...draft.imageZones.poster, ...draft.imageZones.cover].sort((left, right) => left.sortOrder - right.sortOrder);
  }
  return [...draft.imageZones[kind]].sort((left, right) => left.sortOrder - right.sortOrder);
};

const parseLineupEditableItems = (raw: Record<string, any>): EventStudioAIEditableLineupItem[] => {
  const items = Array.isArray(raw.items) ? raw.items : [];
  const parsed: Array<EventStudioAIEditableLineupItem | null> = items
    .slice()
    .sort((left: any, right: any) => Number(left?.order || 0) - Number(right?.order || 0))
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
                  ? stage.slots.map((slot: any, index: number) => {
                      const eventDayRef = day?.eventDayRef || day?.event_day_ref || {};
                      const resolvedEventDay =
                        draft.eventDays.find((item) => item.eventDayId === safeString(eventDayRef.eventDayId || eventDayRef.event_day_id)) ||
                        draft.eventDays.find((item) => item.overallDayIndex === Number(eventDayRef.overallDayIndex || eventDayRef.overall_day_index)) ||
                        draft.eventDays.find((item) => item.date === normalizeDateOnly(safeString(eventDayRef.date || day?.dateText || day?.date || '')));
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
                      const startSource = slot?.normalizedStartTime ?? slot?.normalized_start_time ?? slot?.startTimeText ?? slot?.start_time_text;
                      const endSource = slot?.normalizedEndTime ?? slot?.normalized_end_time ?? slot?.endTimeText ?? slot?.end_time_text;
                      return {
                        id: crypto.randomUUID(),
                        eventDayId: resolvedEventDay?.eventDayId || safeString(eventDayRef.eventDayId || eventDayRef.event_day_id),
                        weekIndex: resolvedEventDay?.weekIndex || Number(week?.weekIndex || week?.week_index || 1),
                        dayIndexInWeek: resolvedEventDay?.dayIndexInWeek || Number(day?.dayIndexInWeek || day?.day_index_in_week || 1),
                        overallDayIndex: resolvedEventDay?.overallDayIndex || Number(eventDayRef.overallDayIndex || eventDayRef.overall_day_index || 1),
                        localDate: resolvedEventDay?.date || normalizeDateOnly(safeString(eventDayRef.date || day?.dateText || day?.date || '')),
                        dayLabel: safeString(day?.dayLabel || day?.day_label) || resolvedEventDay?.label || '',
                        stageName: safeString(stage?.stageName || stage?.stage_name) || 'Main Stage',
                        actType,
                        performerNamesText: names.join(' / '),
                        performerDJIDs: normalizePerformerIds(slot?.performerDJIDs ?? slot?.performerDjIds ?? slot?.memberDjIds, count),
                        confidence: Number.isFinite(Number(slot?.confidence)) ? Number(slot.confidence) : null,
                        notes: Array.isArray(slot?.notes) ? slot.notes.map((note: unknown) => safeString(note)).filter(Boolean) : [],
                        startTimeText: editableClockText(startSource),
                        endTimeText: editableClockText(endSource),
                        startDayOffset: dayOffsetFromClockText(startSource),
                        endDayOffset: dayOffsetFromClockText(endSource),
                        sortOrder: Number.isFinite(Number(slot?.orderInStage || slot?.order))
                          ? Math.max(1, Math.floor(Number(slot?.orderInStage || slot?.order)))
                          : index + 1,
                      };
                    }).filter((item: EventStudioAIEditableTimetableSlot | null): item is EventStudioAIEditableTimetableSlot => item !== null)
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
  } as T;
};

export default function EventStudioAIImportDock({
  draft,
  setDraft,
  onOpenStep,
}: {
  draft: EventStudioDraft;
  setDraft: React.Dispatch<React.SetStateAction<EventStudioDraft>>;
  onOpenStep?: (step: 'media' | 'timetable' | 'lineup') => void;
}) {
  const [panel, setPanel] = useState<ImportPanelState | null>(null);
  const [globalError, setGlobalError] = useState<string | null>(null);
  const cancelRequestedRef = useRef(false);

  const posterPreviewCount = useMemo(
    () => draft.imageZones.poster.length + draft.imageZones.cover.length,
    [draft.imageZones.cover.length, draft.imageZones.poster.length]
  );
  const timetablePreviewCount = useMemo(
    () => draft.imageZones.timetable.length,
    [draft.imageZones.timetable.length]
  );
  const lineupPreviewCount = useMemo(
    () => draft.imageZones.lineup.length,
    [draft.imageZones.lineup.length]
  );

  const openPanel = (kind: ImportPanelKind) => {
    const initialImage = findImportImage(draft, kind);
    if (!initialImage) {
      setGlobalError('当前草稿里还没有可用于识别的图片，请先上传对应图片。');
      return;
    }
    setGlobalError(null);
    setPanel({
      kind,
      selectedImageId: initialImage.id,
      running: false,
      jobId: null,
      statusText: '请选择图片后开始识别。',
      errorText: null,
      resultJson: null,
      lineupItems: [],
      timetableSlots: [],
      selectedTimetableSlotIds: [],
      warnings: [],
      unparsedTexts: [],
    });
  };

  const selectedImageOptions = panel ? importImageOptions(draft, panel.kind) : [];
  const selectedImage = panel
    ? selectedImageOptions.find((item) => item.id === panel.selectedImageId) || selectedImageOptions[0] || null
    : null;

  const closePanel = () => {
    cancelRequestedRef.current = true;
    setPanel(null);
  };

  const updatePanel = (patch: Partial<ImportPanelState>) => {
    setPanel((current) => (current ? { ...current, ...patch } : current));
  };

  const setEditablePanelResult = (kind: ImportPanelKind, rawJson: unknown) => {
    const rawRecord = rawJson && typeof rawJson === 'object' && !Array.isArray(rawJson) ? rawJson as Record<string, any> : {};
    setPanel((current) => {
      if (!current) return current;
      return {
        ...current,
        resultJson: rawJson,
        lineupItems: kind === 'lineup' ? parseLineupEditableItems(rawRecord) : current.lineupItems,
        timetableSlots: kind === 'timetable' ? parseTimetableEditableSlots(rawRecord, draft) : current.timetableSlots,
        selectedTimetableSlotIds: [],
        warnings: normalizeWarnings(rawRecord),
        unparsedTexts: normalizeUnparsedTexts(rawRecord),
      };
    });
  };

  const pollJob = async (kind: ImportPanelKind, jobId: string) => {
    for (;;) {
      if (cancelRequestedRef.current) return null;
      const snapshot = await eventStudioApi.fetchImportImageJob(kind, jobId);
      updatePanel({
        jobId,
        statusText:
          snapshot.status === 'pending'
            ? '任务已提交，正在排队。'
            : snapshot.status === 'running'
              ? '识别中，请稍候。'
              : snapshot.status === 'succeeded'
                ? '识别完成。'
                : snapshot.status === 'cancelled'
                  ? '任务已取消。'
                  : snapshot.error || '识别失败。',
        errorText: snapshot.status === 'failed' ? snapshot.error || '识别失败，请稍后重试。' : null,
        resultJson: snapshot.result?.rawJson ?? null,
        running: snapshot.status === 'pending' || snapshot.status === 'running',
      });
      if (snapshot.status === 'succeeded') {
        setEditablePanelResult(kind, snapshot.result?.rawJson ?? null);
      }
      if (snapshot.status === 'succeeded' || snapshot.status === 'failed' || snapshot.status === 'cancelled') {
        return snapshot;
      }
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  };

  const startRecognition = async () => {
    if (!panel || !selectedImage) return;
    try {
      cancelRequestedRef.current = false;
      updatePanel({
        running: true,
        errorText: null,
        resultJson: null,
        statusText: '已提交识别任务，正在等待结果。',
      });
      const job = await eventStudioApi.createImportImageJob({
        kind: panel.kind,
        imageUrl: selectedImage.remoteUrl,
        fileType: 'image/jpeg',
        context:
          panel.kind === 'poster'
            ? {
                timeZone: draft.timeZoneSelection?.timezone || '',
                dayRolloverHour: Number(draft.dayRolloverHour) || 6,
                weeks: draft.weeks,
                eventDays: draft.eventDays,
              }
            : panel.kind === 'timetable'
              ? {
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
                }
              : {
                  preferredLanguage: 'zh',
                  knownDJNames: draft.lineupArtists
                    .map((artist) => artist.memberNamesText)
                    .map((item) => item.trim())
                    .filter(Boolean)
                    .slice(0, 100),
                },
      });
      updatePanel({
        jobId: job.jobId,
        statusText: '识别任务已创建，正在轮询结果。',
        running: true,
      });
      const snapshot = await pollJob(panel.kind, job.jobId);
      if (!snapshot) return;
      updatePanel({
        jobId: snapshot.jobId,
        statusText: snapshot.status === 'succeeded' ? '识别完成，确认无误后即可应用。' : snapshot.error || '识别未成功。',
        errorText: snapshot.status === 'failed' ? snapshot.error || '识别失败' : null,
        resultJson: snapshot.result?.rawJson ?? null,
        running: false,
      });
      if (snapshot.status === 'succeeded') {
        setEditablePanelResult(panel.kind, snapshot.result?.rawJson ?? null);
      }
    } catch (error) {
      updatePanel({
        running: false,
        errorText: error instanceof Error ? error.message : '识别失败',
        statusText: '识别失败，请稍后重试。',
      });
    }
  };

  const cancelRecognition = async () => {
    if (!panel?.jobId) {
      closePanel();
      return;
    }
    try {
      cancelRequestedRef.current = true;
      await eventStudioApi.cancelImportImageJob(panel.kind, panel.jobId);
      updatePanel({
        running: false,
        statusText: '任务已取消。',
      });
    } catch (error) {
      updatePanel({
        running: false,
        errorText: error instanceof Error ? error.message : '取消失败',
      });
    }
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

  const updateTimetableSlot = (slotId: string, updater: (slot: EventStudioAIEditableTimetableSlot) => EventStudioAIEditableTimetableSlot) => {
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

  const autoMatchAIItems = async () => {
    if (!panel) return;
    const items = panel.kind === 'lineup' ? panel.lineupItems : panel.timetableSlots;
    const nextItems = await Promise.all(
      items.map(async (item) => {
        const names = splitPerformerNames(item.performerNamesText);
        const nextDJIds = Array.from({ length: actTypePerformerCount(item.actType) }, (_, index) => item.performerDJIDs[index] || null);
        for (let index = 0; index < names.length; index += 1) {
          if (nextDJIds[index]) continue;
          const result = await safeSearchDJ(names[index]);
          if (result?.id) {
            nextDJIds[index] = result.id;
          }
        }
        return { ...item, performerDJIDs: nextDJIds };
      })
    );
    setPanel((current) => {
      if (!current) return current;
      return panel.kind === 'lineup'
        ? { ...current, lineupItems: nextItems as EventStudioAIEditableLineupItem[] }
        : { ...current, timetableSlots: nextItems as EventStudioAIEditableTimetableSlot[] };
    });
  };

  const safeSearchDJ = async (name: string) => {
    const query = name.trim();
    if (!query) return null;
    try {
      const response = await DJAggregatorAPI.searchDJ(query);
      if (Array.isArray(response?.items) && response.items.length > 0) {
        return response.items[0] as { id?: string } | null;
      }
      if (response?.id) return response as { id?: string };
      return null;
    } catch {
      return null;
    }
  };

  const applyResult = () => {
    if (!panel) return;
    if (panel.kind === 'poster') {
      const raw = panel.resultJson as Record<string, any>;
      const schedule = raw.schedule && typeof raw.schedule === 'object' ? raw.schedule as Record<string, any> : {};
      const ticketInfo = raw.ticketInfo && typeof raw.ticketInfo === 'object' ? raw.ticketInfo as Record<string, any> : {};
      const posterWeeks = normalizeWeekRanges(schedule.weekRanges ?? schedule.week_ranges);
      const nextDraft = {
        ...draft,
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
        timeZoneSelection: resolvedTimeZoneSelection(draft, raw),
        startDate: safeString(schedule.startDate || schedule.start_date || draft.startDate),
        endDate: safeString(schedule.endDate || schedule.end_date || draft.endDate),
        scheduleMode: normalizeScheduleMode(schedule.scheduleMode || schedule.schedule_mode),
        ticketUrl: safeString(ticketInfo.ticketUrl || ticketInfo.ticket_url || draft.ticketUrl),
        ticketCurrency: safeString(ticketInfo.currency || draft.ticketCurrency).toUpperCase() || draft.ticketCurrency,
        ticketNotes: safeString(ticketInfo.notes || ticketInfo.ticketNotes || draft.ticketNotes),
      };
      const hydratedWeeks = posterWeeks.length ? posterWeeks : nextDraft.scheduleMode === 'multi_week' ? draft.weeks : [];
      setDraft(syncEventStudioScheduleStructure({
        ...nextDraft,
        weeks: hydratedWeeks.length ? hydratedWeeks : nextDraft.weeks,
        eventDays: draft.eventDays,
      }));
      closePanel();
      return;
    }
    if (panel.kind === 'lineup') {
      const nextLineup = panel.lineupItems
        .map((item, index): EventStudioDraft['lineupArtists'][number] | null => {
          const normalized = normalizeEditableAct(item);
          const names = splitPerformerNames(normalized.performerNamesText).slice(0, actTypePerformerCount(normalized.actType));
          if (!names.length) return null;
          return {
            id: crypto.randomUUID(),
            canonicalArtistId: null,
            djId: normalized.performerDJIDs.find(Boolean) || '',
            memberDjIds: normalizePerformerIds(normalized.performerDJIDs, actTypePerformerCount(normalized.actType)),
            memberNamesText: names.join(' / '),
            actType: normalized.actType,
            sortOrder: index + 1,
          };
        })
        .filter((item): item is EventStudioDraft['lineupArtists'][number] => item !== null);
      setDraft((current) => ({
        ...current,
        lineupArtists: nextLineup,
      }));
      closePanel();
      return;
    }
    const nextSlots = panel.timetableSlots
      .map((slot, index): EventStudioDraft['timetableSlots'][number] | null => {
        const normalized = normalizeEditableAct(slot);
        const names = splitPerformerNames(normalized.performerNamesText).slice(0, actTypePerformerCount(normalized.actType));
        if (!names.length) return null;
        return {
          id: crypto.randomUUID(),
          canonicalSlotId: null,
          lineupArtistId: null,
          actType: normalized.actType,
          eventDayId: slot.eventDayId,
          weekIndex: slot.weekIndex,
          dayIndexInWeek: slot.dayIndexInWeek,
          overallDayIndex: slot.overallDayIndex,
          localDate: slot.localDate,
          djId: normalized.performerDJIDs.find(Boolean) || '',
          memberDjIds: normalizePerformerIds(normalized.performerDJIDs, actTypePerformerCount(normalized.actType)),
          memberNamesText: names.join(' / '),
          stageName: slot.stageName || 'Main Stage',
          sortOrder: index + 1,
          startTime: slot.startTimeText,
          endTime: slot.endTimeText,
          startDayOffset: slot.startDayOffset,
          endDayOffset: slot.endDayOffset,
        };
      })
      .filter((slot): slot is EventStudioDraft['timetableSlots'][number] => slot !== null);
    setDraft((current) => ({
      ...current,
      timetableSlots: nextSlots,
      stageOrder: Array.from(new Set([...current.stageOrder, ...nextSlots.map((slot) => slot.stageName).filter(Boolean)])),
    }));
    closePanel();
  };

  return (
    <div className="space-y-4">
      {globalError ? <div className="admin-studio-pastel-rose p-4 text-sm text-[#6a3530]">{globalError}</div> : null}
      <div className="grid gap-3 lg:grid-cols-3">
        {PANEL_ITEMS.map((item) => {
          const count =
            item.kind === 'poster'
              ? posterPreviewCount
              : item.kind === 'timetable'
                ? timetablePreviewCount
                : lineupPreviewCount;
          return (
            <button
              key={item.kind}
              type="button"
              onClick={() => {
                setGlobalError(null);
                openPanel(item.kind);
                onOpenStep?.(item.kind === 'poster' ? 'media' : item.kind);
              }}
              className="admin-reference-soft-card p-4 text-left"
            >
              <div className="admin-studio-label">{item.title}</div>
              <div className="mt-2 text-sm leading-6 text-black/48">{item.description}</div>
              <div className="mt-3 text-xs text-black/40">当前图片: {count} 张</div>
            </button>
          );
        })}
      </div>

      {panel ? (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/45 p-3 sm:items-center">
          <div className="w-full max-w-4xl overflow-hidden rounded-[28px] border border-[#e8eceb] bg-[#fbfcfa] shadow-2xl">
            <div className="flex items-start justify-between gap-4 border-b border-[#e8eceb] px-5 py-4">
              <div>
                <div className="admin-studio-label">
                  {PANEL_ITEMS.find((item) => item.kind === panel.kind)?.title}
                </div>
                <div className="mt-2 text-sm leading-6 text-black/52">{panel.statusText}</div>
              </div>
              <div className="flex items-center gap-2">
                <button type="button" onClick={cancelRecognition} className="admin-studio-button-secondary px-4 py-2 text-sm">
                  {panel.running ? '取消识别' : '关闭'}
                </button>
                <button
                  type="button"
                  onClick={() => void startRecognition()}
                  disabled={!selectedImage || panel.running}
                  className="admin-studio-button-primary px-4 py-2 text-sm disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {panel.running ? '识别中...' : '开始识别'}
                </button>
              </div>
            </div>

            <div className="grid gap-5 p-5 lg:grid-cols-[0.95fr_1.05fr]">
              <div className="space-y-3">
                <div className="text-sm font-semibold text-[#071110]">选择图片</div>
                <div className="grid gap-3 sm:grid-cols-2">
                  {selectedImageOptions.map((image) => (
                    <button
                      key={image.id}
                      type="button"
                      onClick={() =>
                        setPanel((current) => (current ? { ...current, selectedImageId: image.id } : current))
                      }
                      className={`overflow-hidden rounded-[22px] border text-left ${
                        panel.selectedImageId === image.id ? 'border-[#3aa66b]' : 'border-[#e8eceb]'
                      } bg-white`}
                    >
                      <div className="relative aspect-[4/3] bg-[#f2f3ef]">
                        <Image src={image.remoteUrl} alt={image.fileName} fill className="object-cover" sizes="420px" />
                      </div>
                      <div className="px-4 py-3">
                        <div className="truncate text-sm font-medium text-[#071110]">{image.fileName}</div>
                        <div className="mt-1 text-xs text-black/40">
                          {image.origin === 'persisted' ? '已存在' : '当前草稿上传'}
                        </div>
                      </div>
                    </button>
                  ))}
                </div>
              </div>

              <div className="space-y-3">
                <div className="admin-reference-card p-4">
                  <div className="text-sm font-semibold text-[#071110]">当前状态</div>
                  <div className="mt-2 text-sm leading-6 text-black/52">{panel.errorText || panel.statusText}</div>
                </div>

                {panel.resultJson ? (
                  <div className="space-y-3">
                    <div className="admin-reference-card p-4">
                      <div className="flex items-center justify-between gap-3">
                        <div>
                          <div className="text-sm font-semibold text-[#071110]">识别结果</div>
                          <div className="mt-1 text-xs text-black/40">确认无误后再应用到草稿</div>
                        </div>
                        <div className="flex flex-wrap gap-2">
                          <button
                            type="button"
                            onClick={() => void autoMatchAIItems()}
                            className="admin-studio-button-secondary px-4 py-2 text-sm"
                          >
                            自动匹配 DJ
                          </button>
                          <button
                            type="button"
                            onClick={applyResult}
                            className="admin-studio-button-primary px-4 py-2 text-sm"
                          >
                            应用结果
                          </button>
                        </div>
                      </div>
                      {panel.warnings.length || panel.unparsedTexts.length ? (
                        <div className="mt-3 space-y-2 text-xs text-black/48">
                          {panel.warnings.length ? <div>Warnings: {panel.warnings.join(' · ')}</div> : null}
                          {panel.unparsedTexts.length ? <div>Unparsed: {panel.unparsedTexts.join(' · ')}</div> : null}
                        </div>
                      ) : null}
                    </div>

                    {panel.kind === 'lineup' ? (
                      <div className="space-y-3">
                        {panel.lineupItems.map((item, index) => {
                          const count = actTypePerformerCount(item.actType);
                          const names = splitPerformerNames(item.performerNamesText);
                          return (
                            <div key={item.id} className="admin-reference-card p-4">
                              <div className="flex items-start justify-between gap-3">
                                <div className="text-sm font-semibold text-[#071110]">Lineup #{index + 1}</div>
                                <button type="button" onClick={() => removeLineupItem(item.id)} className="admin-studio-button-danger px-3 py-1.5 text-xs">
                                  删除
                                </button>
                              </div>
                              <div className="mt-3 grid gap-3 lg:grid-cols-4">
                                <select
                                  className="admin-studio-input"
                                  value={item.actType}
                                  onChange={(event) =>
                                    updateLineupItem(item.id, (current) => normalizeEditableAct({
                                      ...current,
                                      actType: normalizeActType(event.target.value, splitPerformerNames(current.performerNamesText).length),
                                    }))
                                  }
                                >
                                  {ACT_TYPE_ITEMS.map((act) => (
                                    <option key={act.value} value={act.value}>
                                      {act.label}
                                    </option>
                                  ))}
                                </select>
                                <input
                                  className="admin-studio-input"
                                  value={item.performerNamesText}
                                  onChange={(event) =>
                                    updateLineupItem(item.id, (current) => normalizeEditableAct({
                                      ...current,
                                      performerNamesText: event.target.value,
                                    }))
                                  }
                                />
                                <input
                                  className="admin-studio-input"
                                  value={item.performerDJIDs[0] || ''}
                                  onChange={(event) =>
                                    updateLineupItem(item.id, (current) => ({
                                      ...current,
                                      performerDJIDs: normalizePerformerIds([event.target.value], count),
                                    }))
                                  }
                                  placeholder="DJ ID"
                                />
                                <input
                                  className="admin-studio-input"
                                  value={item.performerDJIDs[1] || ''}
                                  onChange={(event) =>
                                    updateLineupItem(item.id, (current) => ({
                                      ...current,
                                      performerDJIDs: normalizePerformerIds([current.performerDJIDs[0], event.target.value], count),
                                    }))
                                  }
                                  placeholder="DJ ID 2"
                                />
                              </div>
                              <div className="mt-2 text-xs text-black/40">
                                {names.join(' / ')} · {item.notes.join(' · ') || 'No notes'}
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    ) : panel.kind === 'timetable' ? (
                      <div className="space-y-3">
                        <div className="flex flex-wrap gap-2">
                          <button
                            type="button"
                            onClick={() => {
                              const firstDay = draft.eventDays[0];
                              if (!firstDay || !panel.timetableSlots.length) return;
                              setPanel((current) => current ? {
                                ...current,
                                selectedTimetableSlotIds: panel.selectedTimetableSlotIds.length ? [] : panel.timetableSlots.map((slot) => slot.id),
                              } : current);
                            }}
                            className="admin-studio-button-secondary px-3 py-2 text-xs"
                          >
                            全选/取消
                          </button>
                          <button
                            type="button"
                            onClick={() => {
                              const currentDay = draft.eventDays.find((day) => day.eventDayId === draft.eventDays[0]?.eventDayId) || draft.eventDays[0];
                              if (!currentDay) return;
                              setPanel((current) => current ? {
                                ...current,
                                timetableSlots: current.timetableSlots.map((slot) =>
                                  current.selectedTimetableSlotIds.includes(slot.id)
                                    ? { ...slot, eventDayId: currentDay.eventDayId, weekIndex: currentDay.weekIndex, dayIndexInWeek: currentDay.dayIndexInWeek, overallDayIndex: currentDay.overallDayIndex, localDate: currentDay.date, dayLabel: currentDay.label }
                                    : slot
                                ),
                              } : current);
                            }}
                            className="admin-studio-button-secondary px-3 py-2 text-xs"
                          >
                            移动到当前日
                          </button>
                        </div>
                        {panel.timetableSlots.map((slot) => (
                          <div key={slot.id} className="admin-reference-card p-4">
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
                                <div className="text-sm font-semibold text-[#071110]">Timetable #{slot.sortOrder}</div>
                              </div>
                              <button type="button" onClick={() => removeTimetableSlot(slot.id)} className="admin-studio-button-danger px-3 py-1.5 text-xs">
                                删除
                              </button>
                            </div>
                            <div className="mt-3 grid gap-3 lg:grid-cols-4">
                              <select
                                className="admin-studio-input"
                                value={slot.actType}
                                onChange={(event) =>
                                  updateTimetableSlot(slot.id, (current) => normalizeEditableAct({
                                    ...current,
                                    actType: normalizeActType(event.target.value, splitPerformerNames(current.performerNamesText).length),
                                  }) as EventStudioAIEditableTimetableSlot)
                                }
                              >
                                {ACT_TYPE_ITEMS.map((act) => (
                                  <option key={act.value} value={act.value}>
                                    {act.label}
                                  </option>
                                ))}
                              </select>
                              <input
                                className="admin-studio-input"
                                value={slot.performerNamesText}
                                onChange={(event) =>
                                  updateTimetableSlot(slot.id, (current) => ({
                                    ...current,
                                    performerNamesText: event.target.value,
                                  }))
                                }
                              />
                              <input
                                className="admin-studio-input"
                                value={slot.startTimeText}
                                onChange={(event) =>
                                  updateTimetableSlot(slot.id, (current) => ({ ...current, startTimeText: event.target.value }))
                                }
                              />
                              <input
                                className="admin-studio-input"
                                value={slot.endTimeText}
                                onChange={(event) =>
                                  updateTimetableSlot(slot.id, (current) => ({ ...current, endTimeText: event.target.value }))
                                }
                              />
                              <select
                                className="admin-studio-input"
                                value={String(slot.startDayOffset)}
                                onChange={(event) =>
                                  updateTimetableSlot(slot.id, (current) => ({ ...current, startDayOffset: Number(event.target.value) || 0 }))
                                }
                              >
                                <option value="0">开始同日</option>
                                <option value="1">开始次日</option>
                              </select>
                              <select
                                className="admin-studio-input"
                                value={String(slot.endDayOffset)}
                                onChange={(event) =>
                                  updateTimetableSlot(slot.id, (current) => ({ ...current, endDayOffset: Number(event.target.value) || 0 }))
                                }
                              >
                                <option value="0">结束同日</option>
                                <option value="1">结束次日</option>
                              </select>
                            </div>
                            <div className="mt-3 grid gap-3 lg:grid-cols-3">
                              <input
                                className="admin-studio-input"
                                value={slot.performerDJIDs[0] || ''}
                                onChange={(event) =>
                                  updateTimetableSlot(slot.id, (current) => ({
                                    ...current,
                                    performerDJIDs: normalizePerformerIds([event.target.value], actTypePerformerCount(current.actType)),
                                  }))
                                }
                                placeholder="DJ ID 1"
                              />
                              <input
                                className="admin-studio-input"
                                value={slot.performerDJIDs[1] || ''}
                                onChange={(event) =>
                                  updateTimetableSlot(slot.id, (current) => ({
                                    ...current,
                                    performerDJIDs: normalizePerformerIds([current.performerDJIDs[0], event.target.value], actTypePerformerCount(current.actType)),
                                  }))
                                }
                                placeholder="DJ ID 2"
                              />
                              <input
                                className="admin-studio-input"
                                value={slot.performerDJIDs[2] || ''}
                                onChange={(event) =>
                                  updateTimetableSlot(slot.id, (current) => ({
                                    ...current,
                                    performerDJIDs: normalizePerformerIds([current.performerDJIDs[0], current.performerDJIDs[1], event.target.value], actTypePerformerCount(current.actType)),
                                  }))
                                }
                                placeholder="DJ ID 3"
                              />
                            </div>
                            <div className="mt-2 text-xs text-black/40">
                              {slot.dayLabel || slot.localDate} · {slot.stageName}
                            </div>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <pre className="mt-3 max-h-[320px] overflow-auto rounded-[18px] bg-[#0b1210] p-4 text-xs leading-6 text-[#d6f3df]">
                        {JSON.stringify(panel.resultJson, null, 2)}
                      </pre>
                    )}
                  </div>
                ) : (
                  <div className="admin-reference-soft-card p-4 text-sm text-black/48">
                    先选一张图片，然后点击「开始识别」。
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
