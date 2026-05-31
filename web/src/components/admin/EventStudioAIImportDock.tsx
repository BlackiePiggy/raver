'use client';

import Image from 'next/image';
import { useMemo, useRef, useState } from 'react';
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

const normalizeDateOnly = (value: string): string => value.trim().slice(0, 10);

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

  const applyResult = () => {
    if (!panel?.resultJson) return;
    const raw = panel.resultJson as Record<string, any>;

    if (panel.kind === 'poster') {
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

      const hydratedWeeks = posterWeeks.length
        ? posterWeeks
        : nextDraft.scheduleMode === 'multi_week'
          ? draft.weeks
          : [];

      setDraft(syncEventStudioScheduleStructure({
        ...nextDraft,
        weeks: hydratedWeeks.length ? hydratedWeeks : nextDraft.weeks,
        eventDays: draft.eventDays,
      }));
    }

    if (panel.kind === 'timetable') {
      const weeks = Array.isArray(raw.weeks) ? raw.weeks : [];
      const stageNames = new Set<string>();
      const nextSlots = weeks.flatMap((week: any) =>
        Array.isArray(week?.days)
          ? week.days.flatMap((day: any) =>
              Array.isArray(day?.stages)
                ? day.stages.flatMap((stage: any) =>
                    Array.isArray(stage?.slots)
                      ? stage.slots.map((slot: any, index: number) => {
                          const eventDayRef = day?.eventDayRef || {};
                          const resolvedEventDay =
                            draft.eventDays.find((item) => item.eventDayId === safeString(eventDayRef.eventDayId || eventDayRef.event_day_id)) ||
                            draft.eventDays.find((item) => item.overallDayIndex === Number(eventDayRef.overallDayIndex || eventDayRef.overall_day_index)) ||
                            draft.eventDays.find((item) => item.date === normalizeDateOnly(safeString(eventDayRef.date || day?.dateText || day?.date || '')));
                          const stageName = safeString(stage?.stageName) || 'Main Stage';
                          stageNames.add(stageName);
                          return {
                            id: crypto.randomUUID(),
                            canonicalSlotId: null,
                            lineupArtistId: null,
                            eventDayId: resolvedEventDay?.eventDayId || safeString(eventDayRef.eventDayId || eventDayRef.event_day_id),
                            weekIndex: resolvedEventDay?.weekIndex || Number(week?.weekIndex || 1),
                            dayIndexInWeek: resolvedEventDay?.dayIndexInWeek || Number(day?.dayIndexInWeek || 1),
                            overallDayIndex: resolvedEventDay?.overallDayIndex || Number(eventDayRef.overallDayIndex || eventDayRef.overall_day_index || 1),
                            localDate: resolvedEventDay?.date || normalizeDateOnly(safeString(eventDayRef.date || day?.dateText || day?.date || '')),
                            djId: '',
                            memberDjIds: [],
                            memberNamesText: firstFilledText(
                              slot?.displayName,
                              Array.isArray(slot?.performerNames) ? slot.performerNames.join(' / ') : '',
                              safeString(slot?.rawText)
                            ),
                            stageName,
                            sortOrder: Number.isFinite(Number(slot?.orderInStage || slot?.order))
                              ? Math.max(1, Math.floor(Number(slot?.orderInStage || slot?.order)))
                              : index + 1,
                            startTime: safeString(slot?.normalizedStartTime || slot?.startTimeText),
                            endTime: safeString(slot?.normalizedEndTime || slot?.endTimeText),
                          };
                        })
                      : []
                  )
                : []
            )
          : []
      );

      setDraft((current) => ({
        ...current,
        timetableSlots: nextSlots,
        stageOrder: Array.from(stageNames),
      }));
    }

    if (panel.kind === 'lineup') {
      const items = Array.isArray(raw.items) ? raw.items : [];
      const nextLineup = items
        .slice()
        .sort((left: any, right: any) => Number(left?.order || 0) - Number(right?.order || 0))
        .map((item: any, index: number) => ({
          id: crypto.randomUUID(),
          canonicalArtistId: null,
          djId: '',
          memberDjIds: [],
          memberNamesText: firstFilledText(
            Array.isArray(item?.performerNames) ? item.performerNames.join(' / ') : '',
            item?.displayName,
            item?.rawText
          ),
          sortOrder: Number.isFinite(Number(item?.order)) ? Math.max(1, Math.floor(Number(item?.order))) : index + 1,
        }))
        .filter((item: EventStudioDraft['lineupArtists'][number]) => item.memberNamesText.trim().length > 0);

      setDraft((current) => ({
        ...current,
        lineupArtists: nextLineup,
      }));
    }

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
                  <div className="admin-reference-card p-4">
                    <div className="flex items-center justify-between gap-3">
                      <div>
                        <div className="text-sm font-semibold text-[#071110]">识别结果</div>
                        <div className="mt-1 text-xs text-black/40">确认无误后再应用到草稿</div>
                      </div>
                      <button
                        type="button"
                        onClick={applyResult}
                        className="admin-studio-button-primary px-4 py-2 text-sm"
                      >
                        应用结果
                      </button>
                    </div>
                    <pre className="mt-3 max-h-[320px] overflow-auto rounded-[18px] bg-[#0b1210] p-4 text-xs leading-6 text-[#d6f3df]">
{JSON.stringify(panel.resultJson, null, 2)}
                    </pre>
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
