'use client';

import Image from 'next/image';
import Link from 'next/link';
import { ChangeEvent, CSSProperties, ReactNode, useEffect, useMemo, useState } from 'react';
import EventLocationPickerModal, {
  type EventLocationPoint,
  type EventLocationProvider,
} from '@/components/admin/EventLocationPickerModal';
import EventStudioAIImportDock from '@/components/admin/EventStudioAIImportDock';
import {
  createEmptyTicketTierDraft,
  createEmptyEventStudioTimetableSlotDraft,
  eventStudioApi,
  EventStudioApiError,
  mapEventStudioDraftToCreateInput,
  mapEventStudioDraftToUpdateInput,
  syncEventStudioLineupState,
  syncEventStudioScheduleStructure,
  validateEventStudioDraft,
  type EventStudioAlignmentPreview,
  type EventStudioCreateResult,
  type EventStudioDraft,
  type EventStudioEventDayDraft,
  type EventStudioImageState,
  type EventStudioImageUsage,
  type EventStudioOrganizer,
  type EventStudioTimetableSlotDraft,
  type EventStudioValidationErrors,
  type EventStudioWeekDraft,
} from '@/features/admin-content/event-studio';

const EVENT_TYPES = ['电音节', '酒吧活动', '露天活动', '俱乐部派对', '仓库派对', '巡演专场', '其他'];

const SCHEDULE_MODE_ITEMS: Array<{
  value: EventStudioDraft['scheduleMode'];
  label: string;
  description: string;
}> = [
  { value: 'single_day', label: '单日', description: '只有 1 个活动日，适合单天活动。' },
  { value: 'multi_day', label: '多日', description: '连续多天活动，自动生成一个连续日期范围。' },
  { value: 'multi_week', label: '多周', description: '按周拆分多个日期段，适合巡回、周末节庆或分周活动。' },
];

const EVENT_STUDIO_STEP_ITEMS = [
  { key: 'media', eyebrow: 'Step 1', title: '媒体', description: 'Poster、Cover、Lineup、Timetable 与相关图片' },
  { key: 'basic', eyebrow: 'Step 2', title: '信息', description: '基础资料、地点、主办方与时区' },
  { key: 'time', eyebrow: 'Step 3', title: '周期', description: '单日、多日、多周日期结构' },
  { key: 'timetable', eyebrow: 'Step 4', title: '时间表', description: '活动日、舞台与演出时段' },
  { key: 'lineup', eyebrow: 'Step 5', title: '阵容', description: 'DJ 列表与时间表对齐' },
  { key: 'tickets', eyebrow: 'Step 6', title: '票务', description: '购票链接、票档与说明' },
  { key: 'review', eyebrow: 'Step 7', title: '检查', description: '核对摘要并提交' },
] as const;

type EventStudioStepKey = (typeof EVENT_STUDIO_STEP_ITEMS)[number]['key'];

const STEP_ERROR_KEYS: Record<EventStudioStepKey, Array<keyof EventStudioValidationErrors>> = {
  media: ['coverImage'],
  basic: ['name', 'city', 'country', 'detailAddress', 'timeZone'],
  time: ['startDate', 'endDate'],
  timetable: ['timetableSlots'],
  lineup: [],
  tickets: ['ticketTiers'],
  review: ['name', 'city', 'country', 'detailAddress', 'timeZone', 'startDate', 'endDate', 'coverImage', 'ticketTiers', 'timetableSlots'],
};

const IMAGE_ZONE_CONFIG: Array<{
  usage: EventStudioImageUsage;
  title: string;
  description: string;
  hint: string;
  emphasis: 'primary' | 'secondary';
}> = [
  { usage: 'poster', title: 'Poster', description: '活动主视觉，目录和详情页最优先。', hint: '建议上传海报主图。', emphasis: 'primary' },
  { usage: 'cover', title: 'Cover', description: '封面横图，可作为活动详情头图。', hint: '适合横版头图。', emphasis: 'primary' },
  { usage: 'lineup', title: 'Lineup', description: '阵容图，用于 lineup 识别和详情补充。', hint: '适合艺人阵容排版图。', emphasis: 'primary' },
  { usage: 'timetable', title: 'Timetable', description: '时间表图，便于人工核对排期。', hint: '适合舞台排期长图。', emphasis: 'secondary' },
  { usage: 'map', title: 'Map', description: '场地地图或区域导航图。', hint: '可上传场内导览图。', emphasis: 'secondary' },
  { usage: 'other', title: 'Other', description: '其他视觉素材，如票务图或补充资料。', hint: '用于补充资料。', emphasis: 'secondary' },
];

const textInputClassName = 'admin-studio-input';
const textAreaClassName = 'admin-studio-textarea min-h-28';

const firstFilledText = (...values: Array<string | undefined | null>) => {
  for (const value of values) {
    const trimmed = String(value || '').trim();
    if (trimmed) return trimmed;
  }
  return '';
};

const formatEventDayLabel = (day: EventStudioDraft['eventDays'][number]) =>
  `${day.label || day.eventDayId} · ${day.date}`;

const normalizeMapProvider = (value?: string | null): EventLocationProvider | 'google' => {
  if (value === 'amap' || value === 'mapkit' || value === 'mapbox' || value === 'geoapify' || value === 'google') {
    return value;
  }
  return 'geoapify';
};

const normalizeProviderMetaForModal = (
  value: NonNullable<EventStudioDraft['locationPoint']>['providerMeta'] | undefined
) => {
  if (!value) return null;
  return {
    ...(value.amap
      ? {
          amap: {
            ...(value.amap.poiId ? { poiId: value.amap.poiId } : {}),
            ...(value.amap.adcode ? { adcode: value.amap.adcode } : {}),
          },
        }
      : {}),
    ...(value.mapkit
      ? {
          mapkit: {
            ...(value.mapkit.mapItemIdentifier ? { mapItemIdentifier: value.mapkit.mapItemIdentifier } : {}),
          },
        }
      : {}),
    ...(value.mapbox
      ? {
          mapbox: {
            ...(value.mapbox.placeId ? { placeId: value.mapbox.placeId } : {}),
            ...(value.mapbox.featureType ? { featureType: value.mapbox.featureType } : {}),
          },
        }
      : {}),
    ...(value.geoapify
      ? {
          geoapify: {
            ...(value.geoapify.placeId ? { placeId: value.geoapify.placeId } : {}),
            ...(value.geoapify.featureType ? { featureType: value.geoapify.featureType } : {}),
          },
        }
      : {}),
    ...(value.google
      ? {
          google: {
            ...(value.google.placeId ? { placeId: value.google.placeId } : {}),
            ...(value.google.types?.length ? { types: value.google.types.filter(Boolean) as string[] } : {}),
          },
        }
      : {}),
  };
};

const cloneImageZones = (zones: EventStudioDraft['imageZones']): EventStudioDraft['imageZones'] => ({
  poster: [...zones.poster],
  lineup: [...zones.lineup],
  timetable: [...zones.timetable],
  cover: [...zones.cover],
  map: [...zones.map],
  other: [...zones.other],
});

const normalizeZoneSortOrder = (items: EventStudioImageState[]) =>
  [...items].map((item, index) => ({
    ...item,
    sortOrder: index + 1,
  }));

function Section({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: ReactNode;
}) {
  return (
    <section className="admin-studio-section p-6">
      <div>
        <div className="admin-studio-label">{title}</div>
        <p className="mt-3 text-sm leading-6 text-black/52">{description}</p>
      </div>
      <div className="mt-5">{children}</div>
    </section>
  );
}

function Field({
  label,
  error,
  hint,
  children,
}: {
  label: string;
  error?: string;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <label className="block">
      <div className="mb-2 admin-studio-label">{label}</div>
      {children}
      {hint ? <div className="mt-2 text-xs text-black/40">{hint}</div> : null}
      {error ? <div className="mt-2 text-xs text-[#6a3530]">{error}</div> : null}
    </label>
  );
}

function SummaryStat({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone: 'mint' | 'sand' | 'rose' | 'soft';
}) {
  const className =
    tone === 'mint'
      ? 'admin-studio-pastel-mint'
      : tone === 'sand'
        ? 'admin-studio-pastel-sand'
        : tone === 'rose'
          ? 'admin-studio-pastel-rose'
          : 'admin-reference-soft-card';
  return (
    <div className={`${className} px-4 py-3 text-sm`}>
      <div className="text-black/42">{label}</div>
      <div className="mt-1 font-semibold text-[#071110]">{value}</div>
    </div>
  );
}

function StepNavigation({
  currentStep,
  onSelect,
}: {
  currentStep: number;
  onSelect: (index: number) => void;
}) {
  return (
    <div className="grid gap-3 xl:grid-cols-7">
      {EVENT_STUDIO_STEP_ITEMS.map((item, index) => {
        const active = currentStep === index;
        const done = index < currentStep;
        return (
          <button
            key={item.key}
            type="button"
            onClick={() => onSelect(index)}
            className={
              active
                ? 'admin-studio-section p-4 text-left'
                : done
                  ? 'admin-reference-soft-card border border-[#d9e7dd] bg-[#f6fbf7] p-4 text-left'
                  : 'admin-reference-soft-card p-4 text-left'
            }
          >
            <div className="admin-studio-label">{item.eyebrow}</div>
            <div className="mt-2 text-base font-semibold tracking-[-0.02em] text-[#071110]">{item.title}</div>
            <div className="mt-2 text-sm leading-6 text-black/48">{item.description}</div>
          </button>
        );
      })}
    </div>
  );
}

function StudioTopbar({
  mode,
  draftTitle,
  currentStepItem,
  canSubmit,
  submitting,
  uploading,
  onCancel,
  onSaveDraft,
  onSubmit,
  submitButtonText,
}: {
  mode: 'create' | 'edit';
  draftTitle: string;
  currentStepItem: (typeof EVENT_STUDIO_STEP_ITEMS)[number];
  canSubmit: boolean;
  submitting: boolean;
  uploading: boolean;
  onCancel: () => void;
  onSaveDraft: () => void;
  onSubmit: () => void;
  submitButtonText?: string;
}) {
  return (
    <section className="admin-event-workbench-topbar">
      <div className="min-w-0">
        <div className="admin-event-workbench-crumb">
          <span>活动工作区</span>
          <span>/</span>
          <span className="truncate">{draftTitle}</span>
          <span>/</span>
          <span>{currentStepItem.title}</span>
        </div>
        <div className="mt-3 flex flex-wrap items-end gap-3">
          <div>
            <div className="admin-studio-label">{mode === 'create' ? 'Create Event Flow' : 'Edit Event Flow'}</div>
            <h2 className="mt-1 text-[30px] font-extrabold tracking-[-0.045em] text-[#071110]">{currentStepItem.title}</h2>
          </div>
          <p className="max-w-2xl text-sm leading-6 text-black/48">{currentStepItem.description}</p>
        </div>
      </div>
      <div className="flex shrink-0 flex-wrap items-center gap-2">
        <button type="button" onClick={onCancel} className="admin-studio-button-secondary px-5 py-3 text-sm">
          取消
        </button>
        <button type="button" onClick={onSaveDraft} className="admin-studio-button-secondary px-5 py-3 text-sm">
          保存草稿
        </button>
        <button
          type="button"
          onClick={onSubmit}
          disabled={submitting || uploading}
          className="admin-studio-button-primary px-5 py-3 text-sm disabled:cursor-not-allowed disabled:opacity-60"
          title={canSubmit ? '当前表单已满足提交条件' : '还有必填项未完成，提交时会自动跳转到对应分页'}
        >
          {submitting ? '提交中...' : submitButtonText || (mode === 'create' ? '提交审核' : '提交审核')}
        </button>
      </div>
    </section>
  );
}

function WorkflowRail({
  currentStep,
  onSelect,
  draft,
  mediaCount,
  canSubmit,
}: {
  currentStep: number;
  onSelect: (index: number) => void;
  draft: EventStudioDraft;
  mediaCount: number;
  canSubmit: boolean;
}) {
  return (
    <aside className="admin-event-workbench-rail">
      <div className="rounded-[28px] bg-[#071110] p-5 text-white shadow-[0_24px_55px_rgba(7,17,16,.18)]">
        <div className="text-[11px] font-bold uppercase tracking-[0.2em] text-white/45">Event Session</div>
        <div className="mt-3 text-2xl font-black tracking-[-0.05em]">{currentStep + 1}/7</div>
        <div className="mt-2 text-sm leading-6 text-white/62">{canSubmit ? '资料已满足提交条件' : '按 iOS 上传分页继续补齐资料'}</div>
      </div>

      <nav className="mt-4 space-y-2">
        {EVENT_STUDIO_STEP_ITEMS.map((item, index) => {
          const active = currentStep === index;
          const done = index < currentStep;
          return (
            <button
              key={item.key}
              type="button"
              onClick={() => onSelect(index)}
              className={`admin-event-workbench-step ${active ? 'is-active' : ''} ${done ? 'is-done' : ''}`}
            >
              <span className="admin-event-workbench-step-index">{String(index + 1).padStart(2, '0')}</span>
              <span className="min-w-0 flex-1">
                <span className="block truncate font-bold">{item.title}</span>
                <span className="mt-1 block truncate text-xs text-black/42">{item.description}</span>
              </span>
            </button>
          );
        })}
      </nav>

      <div className="admin-event-workbench-rail-card mt-4">
        <div className="admin-studio-label">当前数据</div>
        <div className="mt-3 grid gap-2 text-sm">
          <div className="flex justify-between gap-3"><span>媒体</span><b>{mediaCount} 张</b></div>
          <div className="flex justify-between gap-3"><span>活动日</span><b>{draft.eventDays.length} 天</b></div>
          <div className="flex justify-between gap-3"><span>舞台</span><b>{draft.stageOrder.length || 0} 个</b></div>
          <div className="flex justify-between gap-3"><span>时间块</span><b>{draft.timetableSlots.length} 条</b></div>
          <div className="flex justify-between gap-3"><span>阵容</span><b>{draft.lineupArtists.length} 位</b></div>
        </div>
      </div>
    </aside>
  );
}

const EVENT_STUDIO_STEP_STORAGE_KEY = 'raver-event-studio-step';

const minutesFromTime = (value: string): number | null => {
  const match = value.match(/^(\d{2}):(\d{2})$/);
  if (!match) return null;
  return Number(match[1]) * 60 + Number(match[2]);
};

const getSlotLayout = (slot: EventStudioTimetableSlotDraft): CSSProperties => {
  const start = minutesFromTime(slot.startTime) ?? 18 * 60;
  const endRaw = minutesFromTime(slot.endTime) ?? start + 60;
  const end = endRaw <= start ? endRaw + 24 * 60 : endRaw;
  const boardStart = 12 * 60;
  const boardEnd = 30 * 60;
  const top = Math.max(0, ((start - boardStart) / (boardEnd - boardStart)) * 100);
  const height = Math.max(7, ((end - start) / (boardEnd - boardStart)) * 100);
  return {
    top: `${Math.min(top, 92)}%`,
    height: `${Math.min(height, 34)}%`,
  };
};

type EventStudioFormProps = {
  mode: 'create' | 'edit';
  eventId?: string;
  draft: EventStudioDraft;
  setDraft: React.Dispatch<React.SetStateAction<EventStudioDraft>>;
  onSubmit: (result: EventStudioCreateResult) => void;
  submitButtonText?: string;
};

export default function EventStudioForm({
  mode,
  eventId,
  draft,
  setDraft,
  onSubmit,
  submitButtonText,
}: EventStudioFormProps) {
  const [errors, setErrors] = useState<EventStudioValidationErrors>({});
  const [timezoneItems, setTimezoneItems] = useState<Array<NonNullable<EventStudioDraft['timeZoneSelection']>>>([]);
  const [timezoneLoading, setTimezoneLoading] = useState(false);
  const [timezoneError, setTimezoneError] = useState('');
  const [organizerItems, setOrganizerItems] = useState<EventStudioOrganizer[]>([]);
  const [organizerLoading, setOrganizerLoading] = useState(false);
  const [organizerError, setOrganizerError] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [currentStep, setCurrentStep] = useState(0);
  const [alignmentPreviewLoading, setAlignmentPreviewLoading] = useState(false);
  const [alignmentPreview, setAlignmentPreview] = useState<EventStudioAlignmentPreview | null>(null);
  const [alignmentPreviewError, setAlignmentPreviewError] = useState<string | null>(null);
  const [conflictNotice, setConflictNotice] = useState<string | null>(null);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [showLocationPicker, setShowLocationPicker] = useState(false);
  const [uploadingUsage, setUploadingUsage] = useState<EventStudioImageUsage | null>(null);
  const [deletingImageId, setDeletingImageId] = useState<string | null>(null);

  const totalSteps = EVENT_STUDIO_STEP_ITEMS.length;
  const canSubmit = useMemo(() => Object.keys(validateEventStudioDraft(draft)).length === 0, [draft]);
  const mediaCount = useMemo(
    () => Object.values(draft.imageZones).reduce((sum, items) => sum + items.length, 0),
    [draft.imageZones]
  );
  const entryVisualCount = useMemo(
    () => draft.imageZones.poster.length + draft.imageZones.cover.length + draft.imageZones.lineup.length,
    [draft.imageZones]
  );

  const draftTitle = firstFilledText(draft.name.zh, draft.name.en, draft.name.ja, draft.name.enFull) || '活动资料编辑';
  const draftCity = firstFilledText(draft.city.zh, draft.city.en, draft.city.ja, draft.city.enFull) || '未填写城市';
  const draftCountry = firstFilledText(draft.country.zh, draft.country.en, draft.country.ja, draft.country.enFull) || '未填写国家';
  const detailAddressDisplay =
    firstFilledText(
      draft.pickedMapAddress,
      draft.detailAddress.zh,
      draft.detailAddress.en,
      draft.detailAddress.ja,
      draft.detailAddress.enFull
    ) || '还没有地点地址';

  useEffect(() => {
    if (typeof window === 'undefined') return;
    const savedStep = Number(window.localStorage.getItem(EVENT_STUDIO_STEP_STORAGE_KEY));
    if (Number.isFinite(savedStep)) {
      setCurrentStep(Math.max(0, Math.min(savedStep, totalSteps - 1)));
    }
  }, [totalSteps]);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    window.localStorage.setItem(EVENT_STUDIO_STEP_STORAGE_KEY, String(currentStep));
  }, [currentStep]);

  const locationPointInitial = useMemo<EventLocationPoint | null>(() => {
    if (draft.locationPoint) {
        return {
        provider: normalizeMapProvider(draft.locationPoint.provider),
        sourceMode: draft.locationPoint.sourceMode || 'web-event-studio-v2',
        providerPlaceId: draft.locationPoint.providerPlaceId || undefined,
        poiId: draft.locationPoint.poiId || undefined,
        adcode: draft.locationPoint.adcode || undefined,
        location: {
          lng: Number(draft.locationPoint.location?.lng),
          lat: Number(draft.locationPoint.location?.lat),
        },
        nameI18n: {
          zh: draft.locationPoint.nameI18n?.zh || '',
          en: draft.locationPoint.nameI18n?.en || '',
        },
        addressI18n: {
          zh: draft.locationPoint.addressI18n?.zh || '',
          en: draft.locationPoint.addressI18n?.en || '',
        },
        formattedAddressI18n: {
          zh: draft.locationPoint.formattedAddressI18n?.zh || '',
          en: draft.locationPoint.formattedAddressI18n?.en || '',
        },
        city: draft.locationPoint.city || '',
        district: draft.locationPoint.district || '',
        province: draft.locationPoint.province || '',
        countryCode: draft.locationPoint.countryCode || '',
        providerMeta: normalizeProviderMetaForModal(draft.locationPoint.providerMeta),
      };
    }
    const latitude = Number(draft.latitude);
    const longitude = Number(draft.longitude);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
      return {
      provider: 'geoapify',
      sourceMode: 'web-event-studio-v2',
      location: { lng: longitude, lat: latitude },
      nameI18n: {
        zh: draft.pickedPlaceName,
        en: draft.pickedPlaceName,
      },
      addressI18n: {
        zh: draft.pickedMapAddress || draft.detailAddress.zh,
        en: draft.pickedMapAddress || draft.detailAddress.en,
      },
      formattedAddressI18n: {
        zh: draft.pickedMapAddress || draft.detailAddress.zh,
        en: draft.pickedMapAddress || draft.detailAddress.en,
      },
      city: firstFilledText(draft.city.en, draft.city.zh),
      district: '',
      province: '',
      countryCode: '',
      providerMeta: null,
    };
  }, [
    draft.locationPoint,
    draft.latitude,
    draft.longitude,
    draft.pickedPlaceName,
    draft.pickedMapAddress,
    draft.detailAddress.zh,
    draft.detailAddress.en,
    draft.city.en,
    draft.city.zh,
  ]);

  const clearErrors = (...keys: Array<keyof EventStudioValidationErrors>) => {
    setErrors((current) => {
      let changed = false;
      const next = { ...current };
      keys.forEach((key) => {
        if (next[key]) {
          delete next[key];
          changed = true;
        }
      });
      return changed ? next : current;
    });
  };

  const goToStep = (index: number) => {
    setCurrentStep(Math.max(0, Math.min(index, totalSteps - 1)));
  };

  const handleCancelFlow = () => {
    window.location.href = '/admin/content/events/catalog';
  };

  const handleSaveDraft = () => {
    setSubmitError(null);
    setConflictNotice('草稿已保存在当前页面状态中。你可以继续切换分页，系统会保留当前步骤。');
  };

  const updateDraftState = (
    updater: (current: EventStudioDraft) => EventStudioDraft,
    options?: {
      syncSchedule?: boolean;
      syncLineup?: boolean;
      clearErrorKeys?: Array<keyof EventStudioValidationErrors>;
    }
  ) => {
    setDraft((current) => {
      let next = updater(current);
      if (options?.syncSchedule) {
        next = syncEventStudioScheduleStructure(next);
      } else if (options?.syncLineup) {
        next = {
          ...next,
          ...syncEventStudioLineupState(next, next.eventDays),
        };
      }
      return next;
    });
    if (options?.clearErrorKeys?.length) {
      clearErrors(...options.clearErrorKeys);
    }
  };

  const updateDraft = <K extends keyof EventStudioDraft>(key: K, value: EventStudioDraft[K]) => {
    updateDraftState(
      (current) => ({
        ...current,
        [key]: key === 'ticketCurrency' ? String(value).toUpperCase() : value,
      }),
      {
        syncSchedule: key === 'startDate' || key === 'endDate' || key === 'scheduleMode',
        clearErrorKeys:
          key === 'startDate'
            ? ['startDate']
            : key === 'endDate'
              ? ['endDate']
              : key === 'imageZones'
                ? ['coverImage']
                : [],
      }
    );
  };

  const updateLocalizedField = (
    key: 'name' | 'city' | 'country' | 'detailAddress',
    locale: 'zh' | 'en' | 'ja' | 'enFull',
    value: string
  ) => {
    updateDraftState(
      (current) => ({
        ...current,
        [key]: {
          ...current[key],
          [locale]: value,
        },
      }),
      {
        clearErrorKeys:
          key === 'name'
            ? ['name']
            : key === 'city'
              ? ['city']
              : key === 'country'
                ? ['country']
                : ['detailAddress'],
      }
    );
  };

  const updateScheduleDerivedDraft = (updater: (current: EventStudioDraft) => EventStudioDraft) => {
    updateDraftState(updater, { syncLineup: true, clearErrorKeys: ['timetableSlots'] });
    setAlignmentPreview(null);
    setAlignmentPreviewError(null);
  };

  const updateLineupDraft = (updater: (current: EventStudioDraft) => EventStudioDraft) => {
    updateDraftState(updater);
  };

  const getStepForErrors = (nextErrors: EventStudioValidationErrors): number => {
    for (let index = 0; index < EVENT_STUDIO_STEP_ITEMS.length; index += 1) {
      const step = EVENT_STUDIO_STEP_ITEMS[index];
      if (STEP_ERROR_KEYS[step.key].some((key) => nextErrors[key])) {
        return index;
      }
    }
    return currentStep;
  };

  const currentStepHasBlockingErrors = (nextErrors: EventStudioValidationErrors) => {
    const step = EVENT_STUDIO_STEP_ITEMS[currentStep];
    return STEP_ERROR_KEYS[step.key].some((key) => nextErrors[key]);
  };

  const searchTimezones = async () => {
    const query = draft.timeZoneQuery.trim();
    if (!query) {
      setTimezoneError('请先输入城市或城市+州/国家');
      setTimezoneItems([]);
      return;
    }

    try {
      setTimezoneLoading(true);
      setTimezoneError('');
      const items = await eventStudioApi.searchTimezones(query);
      setTimezoneItems(items);
      if (!items.length) {
        setTimezoneError('没有匹配结果，请尝试城市英文名、州缩写或国家名');
      }
    } catch (error) {
      setTimezoneItems([]);
      setTimezoneError(error instanceof Error ? error.message : '搜索城市时区失败');
    } finally {
      setTimezoneLoading(false);
    }
  };

  const searchOrganizers = async () => {
    const query = draft.organizerName.trim();
    if (!query) {
      setOrganizerError('请先输入主办方名称');
      setOrganizerItems([]);
      return;
    }

    try {
      setOrganizerLoading(true);
      setOrganizerError('');
      const items = await eventStudioApi.searchOrganizers(query);
      setOrganizerItems(items);
      if (!items.length) {
        setOrganizerError('没有找到匹配主办方，当前将继续保留手动名称');
      }
    } catch (error) {
      setOrganizerItems([]);
      setOrganizerError(error instanceof Error ? error.message : '搜索主办方失败');
    } finally {
      setOrganizerLoading(false);
    }
  };

  const handleImageUpload = async (event: ChangeEvent<HTMLInputElement>, usage: EventStudioImageUsage) => {
    const files = Array.from(event.target.files || []);
    if (!files.length) return;

    try {
      setSubmitError(null);
      setUploadingUsage(usage);
      const uploadedItems = await Promise.all(
        files.map(async (file) => {
          const uploaded = await eventStudioApi.uploadImage(file, {
            usage,
            draftId: draft.id,
          });
          return {
            id: crypto.randomUUID(),
            remoteUrl: uploaded.url,
            fileName: uploaded.fileName || file.name,
            usage,
            origin: 'draft-upload' as const,
            sortOrder: 0,
          };
        })
      );

      updateDraftState(
        (current) => {
          const nextZones = cloneImageZones(current.imageZones);
          const currentItems = [...nextZones[usage]];
          const appended = uploadedItems.map((item, index) => ({
            ...item,
            sortOrder: currentItems.length + index + 1,
          }));
          nextZones[usage] = normalizeZoneSortOrder([...currentItems, ...appended]);
          return {
            ...current,
            imageZones: nextZones,
          };
        },
        { clearErrorKeys: ['coverImage'] }
      );
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '图片上传失败');
    } finally {
      setUploadingUsage(null);
      event.target.value = '';
    }
  };

  const handleImageRemove = async (usage: EventStudioImageUsage, image: EventStudioImageState) => {
    try {
      setSubmitError(null);
      setDeletingImageId(image.id);
      if (image.origin === 'draft-upload') {
        await eventStudioApi.deleteDraftImages({
          draftId: draft.id,
          urls: [image.remoteUrl],
        });
      }
      updateDraftState(
        (current) => {
          const nextZones = cloneImageZones(current.imageZones);
          nextZones[usage] = normalizeZoneSortOrder(nextZones[usage].filter((currentImage) => currentImage.id !== image.id));
          return {
            ...current,
            imageZones: nextZones,
          };
        },
        { clearErrorKeys: ['coverImage'] }
      );
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '图片移除失败');
    } finally {
      setDeletingImageId(null);
    }
  };

  const handleLocationConfirm = (point: EventLocationPoint) => {
    updateDraftState(
      (current) => {
        const currentDetail = firstFilledText(
          current.detailAddress.zh,
          current.detailAddress.en,
          current.detailAddress.ja,
          current.detailAddress.enFull
        );
        const hasCurrentCity = !!firstFilledText(current.city.zh, current.city.en, current.city.ja, current.city.enFull);
        const nextAddressZh =
          point.formattedAddressI18n?.zh?.trim() ||
          point.addressI18n?.zh?.trim() ||
          point.formattedAddressI18n?.en?.trim() ||
          point.addressI18n?.en?.trim() ||
          '';
        const nextAddressEn =
          point.formattedAddressI18n?.en?.trim() ||
          point.addressI18n?.en?.trim() ||
          point.formattedAddressI18n?.zh?.trim() ||
          point.addressI18n?.zh?.trim() ||
          '';
        const nextCity = point.city?.trim() || '';

        return {
          ...current,
          latitude: String(point.location.lat),
          longitude: String(point.location.lng),
          locationPoint: {
            provider: point.provider,
            sourceMode: point.sourceMode,
            providerPlaceId: point.providerPlaceId || null,
            poiId: point.poiId || null,
            adcode: point.adcode || null,
            providerMeta: point.providerMeta || null,
            location: {
              lng: point.location.lng,
              lat: point.location.lat,
            },
            nameI18n: {
              zh: point.nameI18n?.zh || '',
              en: point.nameI18n?.en || '',
              ja: '',
              enFull: '',
            },
            addressI18n: {
              zh: point.addressI18n?.zh || '',
              en: point.addressI18n?.en || '',
              ja: '',
              enFull: '',
            },
            formattedAddressI18n: {
              zh: point.formattedAddressI18n?.zh || '',
              en: point.formattedAddressI18n?.en || '',
              ja: '',
              enFull: '',
            },
            city: point.city || null,
            district: point.district || null,
            province: point.province || null,
            countryCode: point.countryCode || null,
            selectedAt: new Date().toISOString(),
          },
          pickedPlaceName: point.nameI18n?.zh?.trim() || point.nameI18n?.en?.trim() || current.pickedPlaceName,
          pickedMapAddress: nextAddressZh || nextAddressEn || current.pickedMapAddress,
          detailAddress: {
            ...current.detailAddress,
            zh: current.detailAddress.zh || (!currentDetail ? nextAddressZh : ''),
            en: current.detailAddress.en || (!currentDetail ? nextAddressEn : ''),
          },
          city: nextCity && !hasCurrentCity
            ? {
                ...current.city,
                zh: nextCity,
                en: current.city.en || nextCity,
              }
            : current.city,
          timeZoneQuery: current.timeZoneQuery.trim() || nextCity || current.timeZoneQuery,
        };
      },
      {
        clearErrorKeys: ['city', 'detailAddress'],
      }
    );
    setShowLocationPicker(false);
  };

  const setSingleDayDate = (value: string) => {
    updateDraftState(
      (current) => ({
        ...current,
        startDate: value,
        endDate: value,
      }),
      {
        syncSchedule: true,
        clearErrorKeys: ['startDate', 'endDate'],
      }
    );
  };

  const setScheduleMode = (value: EventStudioDraft['scheduleMode']) => {
    updateDraftState(
      (current) => {
        if (value === current.scheduleMode) return current;
        if (value === 'single_day') {
          const nextDate = current.startDate || current.endDate || '';
          return {
            ...current,
            scheduleMode: value,
            startDate: nextDate,
            endDate: nextDate,
            weeks: [],
          };
        }
        if (value === 'multi_day') {
          return {
            ...current,
            scheduleMode: value,
            weeks: [],
          };
        }
        const seedStart = current.startDate || current.endDate || '';
        const seedEnd = current.endDate || current.startDate || '';
        const initialWeek: EventStudioWeekDraft = {
          id: crypto.randomUUID(),
          weekIndex: 1,
          label: 'Week 1',
          startDate: seedStart,
          endDate: seedEnd,
          sortOrder: 1,
        };
        return {
          ...current,
          scheduleMode: value,
          weeks: current.weeks.length ? current.weeks : [initialWeek],
        };
      },
      {
        syncSchedule: true,
        clearErrorKeys: ['startDate', 'endDate'],
      }
    );
  };

  const addWeekRange = () => {
    updateDraftState(
      (current) => {
        const previous = current.weeks[current.weeks.length - 1];
        const nextWeek: EventStudioWeekDraft = {
          id: crypto.randomUUID(),
          weekIndex: current.weeks.length + 1,
          label: `Week ${current.weeks.length + 1}`,
          startDate: previous?.endDate || current.endDate || current.startDate || '',
          endDate: previous?.endDate || current.endDate || current.startDate || '',
          sortOrder: current.weeks.length + 1,
        };
        return {
          ...current,
          weeks: [...current.weeks, nextWeek],
        };
      },
      { syncSchedule: true, clearErrorKeys: ['startDate', 'endDate'] }
    );
  };

  const updateWeekRange = (weekId: string, patch: Partial<EventStudioWeekDraft>) => {
    updateDraftState(
      (current) => ({
        ...current,
        weeks: current.weeks.map((week) =>
          week.id === weekId
            ? {
                ...week,
                ...patch,
              }
            : week
        ),
      }),
      { syncSchedule: true, clearErrorKeys: ['startDate', 'endDate'] }
    );
  };

  const removeWeekRange = (weekId: string) => {
    updateDraftState(
      (current) => ({
        ...current,
        weeks: current.weeks.filter((week) => week.id !== weekId),
      }),
      { syncSchedule: true, clearErrorKeys: ['startDate', 'endDate'] }
    );
  };

  const handleAdvance = () => {
    const nextErrors = validateEventStudioDraft(draft);
    setErrors(nextErrors);
    setSubmitError(null);

    if (currentStepHasBlockingErrors(nextErrors)) {
      setSubmitError('当前分页还有必填项未完成，请先补齐后再继续。');
      return;
    }

    goToStep(currentStep + 1);
  };

  const handleSubmit = async () => {
    const nextErrors = validateEventStudioDraft(draft);
    setErrors(nextErrors);
    setSubmitError(null);
    setConflictNotice(null);

    if (Object.keys(nextErrors).length > 0) {
      goToStep(getStepForErrors(nextErrors));
      return;
    }

    try {
      setSubmitting(true);
      const result =
        mode === 'edit' && eventId
          ? await eventStudioApi.updateEvent(eventId, mapEventStudioDraftToUpdateInput(draft))
          : await eventStudioApi.createEvent(mapEventStudioDraftToCreateInput(draft));
      setAlignmentPreview(null);
      onSubmit(result);
    } catch (error) {
      if (error instanceof EventStudioApiError && error.code === 'ACTIVE_EVENT_EDIT_SUBMISSION_EXISTS') {
        const activeSubmissionId = error.details?.activeSubmissionId;
        const activeSubmissionStatus = error.details?.activeSubmissionStatus;
        setConflictNotice(
          `当前活动已经存在一个进行中的编辑任务${activeSubmissionId ? `（submission: ${activeSubmissionId}）` : ''}${activeSubmissionStatus ? `，状态为 ${activeSubmissionStatus}` : ''}。请等待它处理完成后再提交新的编辑。`
        );
      } else {
        setSubmitError(error instanceof Error ? error.message : '活动提交失败');
      }
    } finally {
      setSubmitting(false);
    }
  };

  const handlePreviewAlignment = async () => {
    const nextErrors = validateEventStudioDraft(draft);
    setErrors(nextErrors);
    setAlignmentPreviewError(null);
    setSubmitError(null);
    if (Object.keys(nextErrors).length > 0) {
      goToStep(getStepForErrors(nextErrors));
      setAlignmentPreviewError('请先补齐必填字段后再预览阵容和时间表对齐情况。');
      return;
    }

    try {
      setAlignmentPreviewLoading(true);
      const preview = await eventStudioApi.previewLineupTimetableAlignment(
        mapEventStudioDraftToCreateInput(draft)
      );
      setAlignmentPreview(preview);
    } catch (error) {
      setAlignmentPreview(null);
      setAlignmentPreviewError(error instanceof Error ? error.message : '阵容对齐预览失败');
    } finally {
      setAlignmentPreviewLoading(false);
    }
  };

  const applyAlignedLineupArtists = () => {
    if (!alignmentPreview?.lineupArtists?.length) return;
    updateLineupDraft((current) => ({
      ...current,
      lineupArtists: alignmentPreview.lineupArtists.map((artist, index) => ({
        id: crypto.randomUUID(),
        canonicalArtistId: artist.id || null,
        djId: artist.djId || '',
        memberDjIds: artist.memberDjIds ?? (artist.djId ? [artist.djId] : []),
        memberNamesText: (artist.memberNames ?? []).filter(Boolean).join(' / ') || artist.djName,
        sortOrder: artist.sortOrder ?? index + 1,
      })),
      lineupSyncMode: 'exact_align',
    }));
  };

  const currentStepItem = EVENT_STUDIO_STEP_ITEMS[currentStep];

  const renderMediaZone = (usage: EventStudioImageUsage) => {
    const config = IMAGE_ZONE_CONFIG.find((item) => item.usage === usage);
    if (!config) return null;
    const items = draft.imageZones[usage];
    const isPrimary = config.emphasis === 'primary';

    return (
      <div
        key={usage}
        className={isPrimary ? 'admin-reference-card p-4' : 'admin-reference-soft-card border border-[#e8eceb] bg-[#fafbf9] p-4'}
      >
        <div className="flex items-start justify-between gap-3">
          <div>
            <div className="text-sm font-semibold text-[#071110]">{config.title}</div>
            <div className="mt-1 text-sm leading-6 text-black/48">{config.description}</div>
          </div>
          <label className="admin-studio-button-secondary cursor-pointer px-3 py-2 text-xs">
            {uploadingUsage === usage ? '上传中...' : '上传图片'}
            <input
              type="file"
              multiple
              accept="image/*"
              className="hidden"
              onChange={(event) => void handleImageUpload(event, usage)}
            />
          </label>
        </div>

        <div className="mt-4">
          {items.length ? (
            <div className="grid gap-3 sm:grid-cols-2">
              {items.map((image, index) => (
                <div key={image.id} className="overflow-hidden rounded-[22px] border border-[#e8eceb] bg-white">
                  <div className="relative aspect-[4/3] overflow-hidden bg-[#f2f3ef]">
                    <Image src={image.remoteUrl} alt={`${config.title}-${index + 1}`} fill className="object-cover" sizes="800px" />
                  </div>
                  <div className="flex items-center justify-between gap-3 px-4 py-3">
                    <div className="min-w-0">
                      <div className="truncate text-sm font-medium text-[#071110]">{image.fileName || `${config.title} ${index + 1}`}</div>
                      <div className="mt-1 text-xs text-black/40">
                        #{image.sortOrder} · {image.origin === 'persisted' ? '已存在' : '当前草稿上传'}
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => void handleImageRemove(usage, image)}
                      className="admin-studio-button-danger px-3 py-2 text-xs"
                    >
                      {deletingImageId === image.id ? '移除中...' : '移除'}
                    </button>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="flex min-h-[180px] items-center justify-center rounded-[22px] border border-dashed border-[#d6ddd7] bg-white text-sm text-black/42">
              {config.hint}
            </div>
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="admin-event-workbench space-y-5">
      <StudioTopbar
        mode={mode}
        draftTitle={draftTitle}
        currentStepItem={currentStepItem}
        canSubmit={canSubmit}
        submitting={submitting}
        uploading={uploadingUsage !== null || deletingImageId !== null}
        onCancel={handleCancelFlow}
        onSaveDraft={handleSaveDraft}
        onSubmit={() => void handleSubmit()}
        submitButtonText={submitButtonText}
      />

      {conflictNotice ? (
        <section className="admin-studio-pastel-sand p-4 text-sm text-[#604a1b]">{conflictNotice}</section>
      ) : null}

      {submitError ? (
        <section className="admin-studio-pastel-rose p-4 text-sm text-[#6a3530]">{submitError}</section>
      ) : null}

      <div className="admin-event-workbench-shell">
        <WorkflowRail currentStep={currentStep} onSelect={goToStep} draft={draft} mediaCount={mediaCount} canSubmit={canSubmit} />
        <main className="min-w-0 space-y-5">

      {currentStep === 0 ? (
        <Section title="媒体" description="先把主视觉、封面、阵容图和排期图集中整理好。提交校验会要求 Poster / Lineup / Cover 至少有一张。">
          <div className="grid gap-5 xl:grid-cols-2">
            {IMAGE_ZONE_CONFIG.filter((item) => item.emphasis === 'primary').map((item) => renderMediaZone(item.usage))}
          </div>

          <div className="mt-5 grid gap-4 xl:grid-cols-3">
            {IMAGE_ZONE_CONFIG.filter((item) => item.emphasis === 'secondary').map((item) => renderMediaZone(item.usage))}
          </div>

          <div className="admin-reference-card mt-5 grid gap-3 p-4 md:grid-cols-3">
            <SummaryStat label="入口视觉" value={`${entryVisualCount} 张`} tone="mint" />
            <SummaryStat label="全部图片" value={`${mediaCount} 张`} tone="soft" />
            <SummaryStat label="提交要求" value="Poster / Cover / Lineup 至少一张" tone="sand" />
          </div>

          <div className="mt-6">
            <EventStudioAIImportDock
              draft={draft}
              setDraft={setDraft}
              onOpenStep={(step) => {
                if (step === 'media') setCurrentStep(0);
                if (step === 'timetable') setCurrentStep(3);
                if (step === 'lineup') setCurrentStep(4);
              }}
            />
          </div>

          {errors.coverImage ? <div className="text-xs text-[#6a3530]">{errors.coverImage}</div> : null}
        </Section>
      ) : null}

      {currentStep === 1 ? (
        <>
          <Section title="活动信息" description="这一步集中填写活动名称、主办方、描述以及地点基础信息。地点部分直接使用原生地图弹层。">
            <div className="grid gap-4 lg:grid-cols-2">
              <Field label="活动名称（中文）" error={errors.name}>
                <input
                  value={draft.name.zh}
                  onChange={(event) => updateLocalizedField('name', 'zh', event.target.value)}
                  className={textInputClassName}
                  placeholder="例如：Tomorrowland"
                />
              </Field>
              <Field label="活动名称（英文）">
                <input
                  value={draft.name.en}
                  onChange={(event) => updateLocalizedField('name', 'en', event.target.value)}
                  className={textInputClassName}
                  placeholder="English name"
                />
              </Field>
              <Field label="活动类型">
                <select
                  value={draft.eventType}
                  onChange={(event) => updateDraft('eventType', event.target.value)}
                  className={textInputClassName}
                >
                  {EVENT_TYPES.map((item) => (
                    <option key={item} value={item}>
                      {item}
                    </option>
                  ))}
                </select>
              </Field>
              <Field label="活动简称">
                <input
                  value={draft.abbreviation}
                  onChange={(event) => updateDraft('abbreviation', event.target.value)}
                  className={textInputClassName}
                  placeholder="例如：ASOT"
                />
              </Field>
              <Field label="场馆名（可选）">
                <input
                  value={draft.venueName}
                  onChange={(event) => updateDraft('venueName', event.target.value)}
                  className={textInputClassName}
                  placeholder="例如：National Stadium"
                />
              </Field>
              <Field label="来源链接">
                <input
                  value={draft.sourceEventUrl}
                  onChange={(event) => updateDraft('sourceEventUrl', event.target.value)}
                  className={textInputClassName}
                  placeholder="https://..."
                />
              </Field>

              <div className="lg:col-span-2">
                <Field label="主办方绑定">
                  <div className="space-y-3">
                    <div className="flex flex-col gap-3 lg:flex-row">
                      <input
                        value={draft.organizerName}
                        onChange={(event) =>
                          updateDraftState((current) => ({
                            ...current,
                            organizerName: event.target.value,
                            organizerFestivalId: current.organizerFestivalId ? '' : current.organizerFestivalId,
                          }))
                        }
                        className={textInputClassName}
                        placeholder="输入主办方名称后可搜索绑定"
                      />
                      <button type="button" onClick={() => void searchOrganizers()} className="admin-studio-button-secondary">
                        {organizerLoading ? '搜索中...' : '搜索主办方'}
                      </button>
                      <Link
                        href={
                          draft.organizerName.trim()
                            ? `/admin/content/organizers/new?name=${encodeURIComponent(draft.organizerName.trim())}`
                            : '/admin/content/organizers/new'
                        }
                        className="admin-studio-button-secondary"
                      >
                        新建主办方
                      </Link>
                    </div>

                    {draft.organizerFestivalId ? (
                      <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] px-4 py-3 text-sm text-[#2f4027]">
                        已绑定主办方 ID：{draft.organizerFestivalId}
                      </div>
                    ) : null}

                    {organizerError ? <div className="text-xs text-text-secondary">{organizerError}</div> : null}

                    {organizerItems.length ? (
                      <div className="grid gap-2">
                        {organizerItems.map((item) => (
                          <button
                            key={item.id}
                            type="button"
                            onClick={() => {
                              updateDraft('organizerFestivalId', item.id);
                              updateDraft('organizerName', item.name);
                              setOrganizerItems([]);
                              setOrganizerError('');
                            }}
                            className="admin-reference-soft-card px-4 py-3 text-left text-sm"
                          >
                            <div className="font-semibold text-[#071110]">{item.name}</div>
                            <div className="mt-1 text-xs text-black/42">
                              {[item.country, item.city, item.tagline].filter(Boolean).join(' · ') || item.id}
                            </div>
                          </button>
                        ))}
                      </div>
                    ) : null}
                  </div>
                </Field>
              </div>

              <div className="lg:col-span-2">
                <Field label="活动描述">
                  <textarea
                    value={draft.description}
                    onChange={(event) => updateDraft('description', event.target.value)}
                    className={textAreaClassName}
                    placeholder="填写活动简介、风格或亮点说明"
                  />
                </Field>
              </div>
            </div>
          </Section>

          <Section title="地点与时区" description="这里完成地图选点、城市国家回填和时区确认。搜索时区后必须从候选列表中点选确认。">
            <div className="grid gap-4 xl:grid-cols-[1.15fr_0.85fr]">
              <div className="space-y-4">
                <div className="admin-reference-card p-4">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <div className="text-sm font-semibold text-[#071110]">活动地点</div>
                      <div className="mt-2 text-sm leading-6 text-black/52">
                        {detailAddressDisplay}
                      </div>
                      <div className="mt-2 text-xs text-black/40">
                        {draft.latitude && draft.longitude
                          ? `${draft.latitude}, ${draft.longitude}`
                          : '还没有已绑定坐标'}
                      </div>
                      {draft.locationPoint?.provider ? (
                        <div className="mt-2 text-xs text-black/40">
                          Provider: {draft.locationPoint.provider} · sourceMode: {draft.locationPoint.sourceMode || 'manual_search'}
                        </div>
                      ) : null}
                    </div>
                    <div className="flex flex-wrap gap-2">
                      <button
                        type="button"
                        onClick={() => setShowLocationPicker(true)}
                        className="admin-studio-button-primary px-4 py-3 text-sm"
                      >
                        {draft.latitude && draft.longitude ? '重新地图选点' : '地图选点'}
                      </button>
                      {(draft.latitude || draft.longitude || draft.pickedMapAddress || draft.pickedPlaceName) ? (
                        <button
                          type="button"
                          onClick={() =>
                            updateDraftState(
                              (current) => ({
                                ...current,
                                latitude: '',
                                longitude: '',
                                locationPoint: null,
                                pickedPlaceName: '',
                                pickedMapAddress: '',
                              }),
                              { clearErrorKeys: ['detailAddress', 'city'] }
                            )
                          }
                          className="admin-studio-button-secondary px-4 py-3 text-sm"
                        >
                          清除地图绑定
                        </button>
                      ) : null}
                    </div>
                  </div>

                  <div className="mt-4 grid gap-3 md:grid-cols-2">
                    <Field label="地图地点名（可选）">
                      <input
                        value={draft.pickedPlaceName}
                        onChange={(event) => updateDraft('pickedPlaceName', event.target.value)}
                        className={textInputClassName}
                        placeholder="例如：National Stadium"
                      />
                    </Field>
                    <Field label="地图地址（可选）">
                      <input
                        value={draft.pickedMapAddress}
                        onChange={(event) => updateDraft('pickedMapAddress', event.target.value)}
                        className={textInputClassName}
                        placeholder="用于 locationPoint 回填"
                      />
                    </Field>
                  </div>
                </div>

                <div className="grid gap-4 lg:grid-cols-2">
                  <Field label="城市（中文）" error={errors.city}>
                    <input
                      value={draft.city.zh}
                      onChange={(event) => updateLocalizedField('city', 'zh', event.target.value)}
                      className={textInputClassName}
                      placeholder="Shanghai"
                    />
                  </Field>
                  <Field label="城市（英文）">
                    <input
                      value={draft.city.en}
                      onChange={(event) => updateLocalizedField('city', 'en', event.target.value)}
                      className={textInputClassName}
                      placeholder="Shanghai"
                    />
                  </Field>
                  <Field label="国家（中文）" error={errors.country}>
                    <input
                      value={draft.country.zh}
                      onChange={(event) => updateLocalizedField('country', 'zh', event.target.value)}
                      className={textInputClassName}
                      placeholder="中国"
                    />
                  </Field>
                  <Field label="国家（英文）">
                    <input
                      value={draft.country.en}
                      onChange={(event) => updateLocalizedField('country', 'en', event.target.value)}
                      className={textInputClassName}
                      placeholder="China"
                    />
                  </Field>
                  <div className="lg:col-span-2">
                    <Field label="详细地址（中文）" error={errors.detailAddress}>
                      <textarea
                        value={draft.detailAddress.zh}
                        onChange={(event) => updateLocalizedField('detailAddress', 'zh', event.target.value)}
                        className={textAreaClassName}
                        placeholder="活动详细地址"
                      />
                    </Field>
                  </div>
                  <Field label="纬度（可选）">
                    <input
                      value={draft.latitude}
                      onChange={(event) => updateDraft('latitude', event.target.value)}
                      className={textInputClassName}
                      placeholder="31.2304"
                    />
                  </Field>
                  <Field label="经度（可选）">
                    <input
                      value={draft.longitude}
                      onChange={(event) => updateDraft('longitude', event.target.value)}
                      className={textInputClassName}
                      placeholder="121.4737"
                    />
                  </Field>
                </div>
              </div>

              <div className="admin-reference-card p-4">
                <Field label="活动时区搜索" error={errors.timeZone || timezoneError}>
                  <div className="flex flex-col gap-3">
                    <input
                      value={draft.timeZoneQuery}
                      onChange={(event) => {
                        updateDraft('timeZoneQuery', event.target.value);
                        if (
                          draft.timeZoneSelection &&
                          event.target.value.trim() !== (draft.timeZoneSelection.cityAscii || draft.timeZoneSelection.city)
                        ) {
                          updateDraft('timeZoneSelection', null);
                        }
                      }}
                      className={textInputClassName}
                      placeholder="输入城市或城市+州/国家，例如 Chicago / Amsterdam NL"
                    />
                    <button type="button" onClick={() => void searchTimezones()} className="admin-studio-button-secondary">
                      {timezoneLoading ? '搜索中...' : '搜索时区'}
                    </button>
                  </div>
                </Field>

                <div
                  className={`mt-3 rounded-[20px] border px-4 py-3 text-sm ${
                    draft.timeZoneSelection ? 'border-[#dceabf] bg-[#edf7f2] text-[#2f4027]' : 'border-[#e8eceb] bg-[#f8f9f8] text-black/48'
                  }`}
                >
                  {draft.timeZoneSelection ? `${draft.timeZoneSelection.label}` : '还没有确认活动时区。保存前必须从候选列表中选定。'}
                </div>

                {timezoneItems.length ? (
                  <div className="mt-3 grid gap-2">
                    {timezoneItems.map((item) => (
                      <button
                        key={`${item.city}-${item.exactProvince}-${item.country}-${item.timezone}`}
                        type="button"
                        onClick={() => {
                          updateDraft('timeZoneSelection', item);
                          updateDraft('timeZoneQuery', item.cityAscii || item.city);
                          setTimezoneItems([]);
                          setTimezoneError('');
                          clearErrors('timeZone');
                        }}
                        className="admin-reference-soft-card px-4 py-3 text-left text-sm"
                      >
                        {item.label}
                      </button>
                    ))}
                  </div>
                ) : null}
              </div>
            </div>
          </Section>
        </>
      ) : null}

      {currentStep === 2 ? (
        <Section title="活动周期" description="这里决定活动的日期结构，提交时会同步生成 weeks / eventDays，供 timetable 和 lineup 共用。">
          <div className="grid gap-4 lg:grid-cols-2">
            <Field label="排期模式">
              <select
                value={draft.scheduleMode}
                onChange={(event) => setScheduleMode(event.target.value as EventStudioDraft['scheduleMode'])}
                className={textInputClassName}
              >
                {SCHEDULE_MODE_ITEMS.map((item) => (
                  <option key={item.value} value={item.value}>
                    {item.label}
                  </option>
                ))}
              </select>
              <div className="mt-2 text-xs text-text-secondary">
                {SCHEDULE_MODE_ITEMS.find((item) => item.value === draft.scheduleMode)?.description}
              </div>
            </Field>
            <Field label="Day Rollover Hour">
              <input
                value={draft.dayRolloverHour}
                onChange={(event) => updateDraft('dayRolloverHour', event.target.value)}
                className={textInputClassName}
                placeholder="默认 6"
              />
            </Field>

            {draft.scheduleMode === 'single_day' ? (
              <Field label="活动日期" error={errors.startDate || errors.endDate}>
                <input
                  type="date"
                  value={draft.startDate}
                  onChange={(event) => setSingleDayDate(event.target.value)}
                  className={textInputClassName}
                />
              </Field>
            ) : null}

            {draft.scheduleMode === 'multi_day' ? (
              <>
                <Field label="开始日期" error={errors.startDate}>
                  <input
                    type="date"
                    value={draft.startDate}
                    onChange={(event) => updateDraft('startDate', event.target.value)}
                    className={textInputClassName}
                  />
                </Field>
                <Field label="结束日期" error={errors.endDate}>
                  <input
                    type="date"
                    value={draft.endDate}
                    onChange={(event) => updateDraft('endDate', event.target.value)}
                    className={textInputClassName}
                  />
                </Field>
              </>
            ) : null}

            <Field label="官网链接">
              <input
                value={draft.officialWebsite}
                onChange={(event) => updateDraft('officialWebsite', event.target.value)}
                className={textInputClassName}
                placeholder="https://..."
              />
            </Field>
          </div>

          {draft.scheduleMode === 'multi_week' ? (
            <div className="admin-reference-card mt-6 p-4">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <div className="text-sm font-semibold text-[#071110]">Week Ranges</div>
                  <div className="mt-1 text-xs text-text-secondary">
                    为每个活动周分别指定起止日期，系统会自动生成对应 eventDays。
                  </div>
                </div>
                <button type="button" onClick={addWeekRange} className="admin-studio-button-primary px-4 py-3 text-sm">
                  新增一周
                </button>
              </div>

              <div className="mt-4 space-y-3">
                {draft.weeks.length ? (
                  draft.weeks.map((week, index) => (
                    <div key={week.id} className="grid gap-3 rounded-[24px] border border-[#e8eceb] bg-[#f8f9f8] p-4 lg:grid-cols-[0.9fr_1fr_1fr_auto]">
                      <input
                        value={week.label}
                        onChange={(event) => updateWeekRange(week.id, { label: event.target.value })}
                        className={textInputClassName}
                        placeholder={`Week ${index + 1}`}
                      />
                      <input
                        type="date"
                        value={week.startDate}
                        onChange={(event) => updateWeekRange(week.id, { startDate: event.target.value })}
                        className={textInputClassName}
                      />
                      <input
                        type="date"
                        value={week.endDate}
                        onChange={(event) => updateWeekRange(week.id, { endDate: event.target.value })}
                        className={textInputClassName}
                      />
                      <button
                        type="button"
                        onClick={() => removeWeekRange(week.id)}
                        className="admin-studio-button-danger px-4 py-3 text-sm"
                      >
                        删除
                      </button>
                    </div>
                  ))
                ) : (
                  <div className="admin-reference-soft-card p-4 text-sm text-black/48">
                    还没有周次。请至少添加 2 个 week range。
                  </div>
                )}
              </div>

              {errors.endDate ? <div className="mt-3 text-xs text-[#6a3530]">{errors.endDate}</div> : null}
            </div>
          ) : null}

          <div className="admin-reference-card mt-6 p-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <div className="text-sm font-semibold">结构化日期预览</div>
                <div className="mt-1 text-xs text-text-secondary">
                  这部分会在提交时直接带给 `/v1/events`，和 iOS 的 schedule 语义保持一致。
                </div>
              </div>
              <div className="text-xs text-text-secondary">weeks: {draft.weeks.length} · eventDays: {draft.eventDays.length}</div>
            </div>

            <div className="mt-4 grid gap-4 xl:grid-cols-2">
              <div className="admin-reference-soft-card p-4">
                <div className="text-sm font-semibold text-[#071110]">Weeks</div>
                <div className="mt-3 space-y-2">
                  {draft.weeks.length ? (
                    draft.weeks.map((week) => (
                      <div key={week.id} className="rounded-[18px] border border-[#e8eceb] bg-white px-3 py-2 text-sm">
                        <div className="font-medium text-[#071110]">{week.label || `Week ${week.weekIndex}`}</div>
                        <div className="mt-1 text-xs text-black/42">
                          {week.startDate} → {week.endDate}
                        </div>
                      </div>
                    ))
                  ) : (
                    <div className="text-sm text-black/48">请先完成日期设置。</div>
                  )}
                </div>
              </div>

              <div className="admin-reference-soft-card p-4">
                <div className="text-sm font-semibold text-[#071110]">Event Days</div>
                <div className="mt-3 space-y-2">
                  {draft.eventDays.length ? (
                    draft.eventDays.map((day) => (
                      <div key={day.id} className="rounded-[18px] border border-[#e8eceb] bg-white px-3 py-2 text-sm">
                        <div className="font-medium text-[#071110]">{day.label || day.eventDayId}</div>
                        <div className="mt-1 text-xs text-black/42">
                          {day.date} · week {day.weekIndex} / day {day.dayIndexInWeek} / overall {day.overallDayIndex}
                        </div>
                      </div>
                    ))
                  ) : (
                    <div className="text-sm text-black/48">当前还没有生成 eventDays。</div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </Section>
      ) : null}

      {currentStep === 3 ? (
        <Section title="时间表" description="按 iOS 的活动日、舞台和演出时段组织，主视图优先展示可视化排期板。">
          <div className="admin-event-timetable-board">
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div>
                <div className="admin-studio-label">Timetable Board</div>
                <h3 className="mt-2 text-2xl font-black tracking-[-0.045em] text-[#071110]">舞台排期</h3>
                <p className="mt-2 max-w-2xl text-sm leading-6 text-black/48">
                  先在这里看整体结构，再用下方条目做精确编辑。时间轴按 12:00 到次日 06:00 呈现。
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                <button type="button" className="admin-studio-button-secondary px-4 py-3 text-sm">
                  批量操作
                </button>
                <button
                  type="button"
                  onClick={() =>
                    updateScheduleDerivedDraft((current) => {
                      const stageName = `Stage ${current.stageOrder.length + 1}`;
                      return {
                        ...current,
                        stageOrder: [...current.stageOrder, stageName],
                      };
                    })
                  }
                  className="admin-studio-button-secondary px-4 py-3 text-sm"
                >
                  添加舞台
                </button>
                <button
                  type="button"
                  onClick={() =>
                    updateScheduleDerivedDraft((current) => ({
                      ...current,
                      timetableSlots: [
                        ...current.timetableSlots,
                        createEmptyEventStudioTimetableSlotDraft(current.eventDays[0], current.stageOrder[0] || 'Main Stage'),
                      ].map((slot, index) => ({
                        ...slot,
                        sortOrder: index + 1,
                      })),
                    }))
                  }
                  disabled={!draft.eventDays.length}
                  className="admin-studio-button-primary px-4 py-3 text-sm disabled:cursor-not-allowed disabled:opacity-60"
                >
                  新增时间块
                </button>
              </div>
            </div>

            <div className="mt-6 flex gap-3 overflow-x-auto pb-2">
              {(draft.weeks.length ? draft.weeks : [{ id: 'single-week', label: 'Week 1', weekIndex: 1 }]).map((week) => (
                <button key={week.id} type="button" className="admin-event-timetable-tab is-active">
                  {week.label || `Week ${week.weekIndex}`}
                </button>
              ))}
            </div>

            <div className="mt-3 flex gap-3 overflow-x-auto pb-2">
              {draft.eventDays.length ? (
                draft.eventDays.map((day, index) => (
                  <button key={day.id} type="button" className={`admin-event-day-tab ${index === 0 ? 'is-active' : ''}`}>
                    <span>{day.label || `Day ${day.overallDayIndex}`}</span>
                    <b>{day.date || '未设置日期'}</b>
                  </button>
                ))
              ) : (
                <div className="admin-reference-soft-card px-4 py-3 text-sm text-black/48">
                  请先在“周期”分页完成日期结构。
                </div>
              )}
            </div>

            <div className="admin-event-stage-grid mt-6">
              <div className="admin-event-time-axis">
                {['12:00', '15:00', '18:00', '21:00', '00:00', '03:00', '06:00'].map((time) => (
                  <span key={time}>{time}</span>
                ))}
              </div>
              {(draft.stageOrder.length ? draft.stageOrder : ['Main Stage']).map((stage, stageIndex) => {
                const stageSlots = draft.timetableSlots.filter((slot) => (slot.stageName || 'Main Stage') === stage);
                return (
                  <div key={stage} className="admin-event-stage-column">
                    <div className="admin-event-stage-heading">
                      <span>{stage}</span>
                      <b>{stageSlots.length} Sets</b>
                    </div>
                    <div className="admin-event-stage-lane">
                      {stageSlots.map((slot, index) => (
                        <button
                          key={slot.id}
                          type="button"
                          style={getSlotLayout(slot)}
                          className={`admin-event-slot-card tone-${(stageIndex + index) % 4}`}
                        >
                          <span className="text-[10px] font-black uppercase tracking-[0.14em] text-black/38">
                            {slot.startTime || '--:--'} - {slot.endTime || '--:--'}
                          </span>
                          <strong>{slot.memberNamesText || '未填写艺人'}</strong>
                          <small>{slot.localDate || '未选择活动日'}</small>
                        </button>
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>

            <div className="mt-5 flex flex-wrap items-center gap-3 text-xs font-bold uppercase tracking-[0.14em] text-black/40">
              <span className="inline-flex items-center gap-2"><i className="size-3 rounded-full bg-[#b9f1d0]" /> 正常时段</span>
              <span className="inline-flex items-center gap-2"><i className="size-3 rounded-full bg-[#f7d884]" /> 跨夜/待核对</span>
              <span className="inline-flex items-center gap-2"><i className="size-3 rounded-full bg-[#c9defa]" /> 已录入艺人</span>
            </div>

            {errors.timetableSlots ? <div className="mt-4 text-xs text-[#6a3530]">{errors.timetableSlots}</div> : null}
          </div>

          <div className="admin-reference-card mt-5 p-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <div className="text-sm font-semibold">时间表条目编辑</div>
                <div className="mt-1 text-xs text-text-secondary">
                  下方保留完整字段编辑，确保 web 和 iOS 上传流程提交的数据结构一致。
                </div>
              </div>
            </div>

            <div className="mt-4 space-y-3">
              {draft.timetableSlots.length ? (
                draft.timetableSlots.map((slot) => (
                  <div key={slot.id} className="grid gap-3 rounded-[24px] border border-[#e8eceb] bg-[#f8f9f8] p-4 lg:grid-cols-3">
                    <Field label="演出日">
                      <select
                        value={slot.eventDayId}
                        onChange={(event) => {
                          const selectedDay = draft.eventDays.find((day) => day.eventDayId === event.target.value);
                          if (!selectedDay) return;
                          updateScheduleDerivedDraft((current) => ({
                            ...current,
                            timetableSlots: current.timetableSlots.map((currentSlot) =>
                              currentSlot.id === slot.id
                                ? {
                                    ...currentSlot,
                                    eventDayId: selectedDay.eventDayId,
                                    weekIndex: selectedDay.weekIndex,
                                    dayIndexInWeek: selectedDay.dayIndexInWeek,
                                    overallDayIndex: selectedDay.overallDayIndex,
                                    localDate: selectedDay.date,
                                  }
                                : currentSlot
                            ),
                          }));
                        }}
                        className={textInputClassName}
                      >
                        {draft.eventDays.map((day) => (
                          <option key={day.id} value={day.eventDayId}>
                            {formatEventDayLabel(day)}
                          </option>
                        ))}
                      </select>
                    </Field>

                    <Field label="舞台名">
                      <input
                        value={slot.stageName}
                        onChange={(event) =>
                          updateScheduleDerivedDraft((current) => ({
                            ...current,
                            timetableSlots: current.timetableSlots.map((currentSlot) =>
                              currentSlot.id === slot.id ? { ...currentSlot, stageName: event.target.value } : currentSlot
                            ),
                          }))
                        }
                        className={textInputClassName}
                        placeholder="Main Stage"
                      />
                    </Field>

                    <Field label="演出人名称">
                      <input
                        value={slot.memberNamesText}
                        onChange={(event) =>
                          updateScheduleDerivedDraft((current) => ({
                            ...current,
                            timetableSlots: current.timetableSlots.map((currentSlot) =>
                              currentSlot.id === slot.id ? { ...currentSlot, memberNamesText: event.target.value } : currentSlot
                            ),
                          }))
                        }
                        className={textInputClassName}
                        placeholder="例如：Martin Garrix / Alesso"
                      />
                    </Field>

                    <Field label="已绑定 DJ ID（可选）">
                      <input
                        value={slot.djId}
                        onChange={(event) =>
                          updateScheduleDerivedDraft((current) => ({
                            ...current,
                            timetableSlots: current.timetableSlots.map((currentSlot) =>
                              currentSlot.id === slot.id
                                ? {
                                    ...currentSlot,
                                    djId: event.target.value,
                                    memberDjIds: event.target.value.trim() ? [event.target.value.trim()] : [],
                                  }
                                : currentSlot
                            ),
                          }))
                        }
                        className={textInputClassName}
                        placeholder="如已绑定实体，可填写 DJ ID"
                      />
                    </Field>

                    <Field label="开始时间">
                      <input
                        type="time"
                        value={slot.startTime}
                        onChange={(event) =>
                          updateScheduleDerivedDraft((current) => ({
                            ...current,
                            timetableSlots: current.timetableSlots.map((currentSlot) =>
                              currentSlot.id === slot.id ? { ...currentSlot, startTime: event.target.value } : currentSlot
                            ),
                          }))
                        }
                        className={textInputClassName}
                      />
                    </Field>

                    <Field label="结束时间">
                      <input
                        type="time"
                        value={slot.endTime}
                        onChange={(event) =>
                          updateScheduleDerivedDraft((current) => ({
                            ...current,
                            timetableSlots: current.timetableSlots.map((currentSlot) =>
                              currentSlot.id === slot.id ? { ...currentSlot, endTime: event.target.value } : currentSlot
                            ),
                          }))
                        }
                        className={textInputClassName}
                      />
                    </Field>

                    <div className="flex justify-end lg:col-span-3">
                      <button
                        type="button"
                        onClick={() =>
                          updateScheduleDerivedDraft((current) => ({
                            ...current,
                            timetableSlots: current.timetableSlots
                              .filter((currentSlot) => currentSlot.id !== slot.id)
                              .map((currentSlot, index) => ({
                                ...currentSlot,
                                sortOrder: index + 1,
                              })),
                          }))
                        }
                        className="admin-studio-button-danger px-4 py-3 text-sm"
                      >
                        删除条目
                      </button>
                    </div>
                  </div>
                ))
              ) : (
                <div className="admin-reference-soft-card p-4 text-sm text-black/48">
                  还没有时间表条目。先完成活动日期结构后，就可以开始录入演出时段。
                </div>
              )}
            </div>
          </div>
        </Section>
      ) : null}

      {currentStep === 4 ? (
        <Section title="阵容" description="阵容页单独处理 DJ 列表与对齐策略，让重点操作从 timetable 中解耦出来。">
          <div className="grid gap-4 xl:grid-cols-[0.95fr_1.05fr]">
            <div className="space-y-4">
              <div className="admin-reference-soft-card p-4">
                <div className="text-sm font-semibold text-[#071110]">Lineup Sync Mode</div>
                <div className="mt-3 space-y-2">
                  <label className="admin-reference-card flex cursor-pointer items-start gap-3 px-3 py-3 text-sm">
                    <input
                      type="radio"
                      name="lineupSyncMode"
                      checked={draft.lineupSyncMode === 'incremental_fill'}
                      onChange={() => updateDraft('lineupSyncMode', 'incremental_fill')}
                    />
                    <span>增量补齐：保留当前阵容基础上，用 timetable 补全缺失艺人。</span>
                  </label>
                  <label className="admin-reference-card flex cursor-pointer items-start gap-3 px-3 py-3 text-sm">
                    <input
                      type="radio"
                      name="lineupSyncMode"
                      checked={draft.lineupSyncMode === 'exact_align'}
                      onChange={() => updateDraft('lineupSyncMode', 'exact_align')}
                    />
                    <span>严格对齐：以 timetable 中出现的艺人为准重建 lineup。</span>
                  </label>
                </div>
              </div>

              <div className="admin-reference-soft-card p-4">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <div className="text-sm font-semibold">对齐预览</div>
                    <div className="mt-1 text-xs text-text-secondary">
                      先用后端规则预览阵容和时间表是否一致，再决定是否直接应用建议阵容。
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => void handlePreviewAlignment()}
                    disabled={alignmentPreviewLoading || !draft.timetableSlots.length}
                    className="admin-studio-button-secondary px-4 py-2 text-sm disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    {alignmentPreviewLoading ? '预览中...' : '预览对齐'}
                  </button>
                </div>

                {alignmentPreviewError ? (
                  <div className="mt-3 rounded-2xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-200">
                    {alignmentPreviewError}
                  </div>
                ) : null}

                {alignmentPreview ? (
                  <div className="mt-3 space-y-3">
                    <div
                      className={`rounded-2xl border px-4 py-3 text-sm ${
                        alignmentPreview.aligned
                          ? 'border-emerald-500/30 bg-emerald-500/10 text-emerald-100'
                          : 'border-amber-500/30 bg-amber-500/10 text-amber-100'
                      }`}
                    >
                      {alignmentPreview.message || (alignmentPreview.aligned ? '当前阵容与时间表已对齐。' : '当前阵容与时间表存在差异。')}
                    </div>

                    {!alignmentPreview.aligned && alignmentPreview.issue ? (
                      <div className="grid gap-3">
                        <div className="admin-reference-card px-4 py-3 text-sm">
                          <div className="font-semibold text-[#071110]">时间表中存在但阵容里缺少</div>
                          <div className="mt-2 text-black/48">
                            {alignmentPreview.issue.missingFromLineup.length
                              ? alignmentPreview.issue.missingFromLineup.join('、')
                              : '无'}
                          </div>
                        </div>
                        <div className="admin-reference-card px-4 py-3 text-sm">
                          <div className="font-semibold text-[#071110]">阵容中存在但时间表里缺少</div>
                          <div className="mt-2 text-black/48">
                            {alignmentPreview.issue.extraInLineup.length ? alignmentPreview.issue.extraInLineup.join('、') : '无'}
                          </div>
                        </div>
                      </div>
                    ) : null}
                  </div>
                ) : null}
              </div>
            </div>

            <div className="admin-reference-card p-4">
              <div className="flex items-center justify-between gap-3">
                <div>
                  <div className="text-sm font-semibold text-[#071110]">阵容艺人</div>
                  <div className="mt-1 text-xs text-text-secondary">你可以直接微调阵容名称、DJ ID 和排序。</div>
                </div>
                <div className="flex gap-2">
                  {alignmentPreview?.lineupArtists?.length ? (
                    <button type="button" onClick={applyAlignedLineupArtists} className="admin-studio-button-primary px-4 py-2 text-sm">
                      应用建议阵容
                    </button>
                  ) : null}
                  <button
                    type="button"
                    onClick={() =>
                      updateLineupDraft((current) => ({
                        ...current,
                        lineupArtists: [
                          ...current.lineupArtists,
                          {
                            id: crypto.randomUUID(),
                            canonicalArtistId: null,
                            djId: '',
                            memberDjIds: [],
                            memberNamesText: '',
                            sortOrder: current.lineupArtists.length + 1,
                          },
                        ],
                      }))
                    }
                    className="admin-studio-button-secondary px-4 py-2 text-sm"
                  >
                    新增阵容艺人
                  </button>
                </div>
              </div>

              <div className="mt-4 space-y-3">
                {draft.lineupArtists.length ? (
                  draft.lineupArtists.map((artist, index) => (
                    <div key={artist.id} className="grid gap-3 rounded-[22px] border border-[#e8eceb] bg-[#f8f9f8] p-4 lg:grid-cols-[0.7fr_1.4fr_1fr_auto]">
                      <input
                        value={String(artist.sortOrder)}
                        onChange={(event) =>
                          updateLineupDraft((current) => ({
                            ...current,
                            lineupArtists: current.lineupArtists.map((currentArtist) =>
                              currentArtist.id === artist.id
                                ? { ...currentArtist, sortOrder: Number(event.target.value) || index + 1 }
                                : currentArtist
                            ),
                          }))
                        }
                        className={textInputClassName}
                        placeholder="排序"
                      />
                      <input
                        value={artist.memberNamesText}
                        onChange={(event) =>
                          updateLineupDraft((current) => ({
                            ...current,
                            lineupArtists: current.lineupArtists.map((currentArtist) =>
                              currentArtist.id === artist.id ? { ...currentArtist, memberNamesText: event.target.value } : currentArtist
                            ),
                          }))
                        }
                        className={textInputClassName}
                        placeholder="艺人名称"
                      />
                      <input
                        value={artist.djId}
                        onChange={(event) =>
                          updateLineupDraft((current) => ({
                            ...current,
                            lineupArtists: current.lineupArtists.map((currentArtist) =>
                              currentArtist.id === artist.id
                                ? {
                                    ...currentArtist,
                                    djId: event.target.value,
                                    memberDjIds: event.target.value.trim() ? [event.target.value.trim()] : [],
                                  }
                                : currentArtist
                            ),
                          }))
                        }
                        className={textInputClassName}
                        placeholder="DJ ID（可选）"
                      />
                      <button
                        type="button"
                        onClick={() =>
                          updateLineupDraft((current) => ({
                            ...current,
                            lineupArtists: current.lineupArtists
                              .filter((currentArtist) => currentArtist.id !== artist.id)
                              .map((currentArtist, nextIndex) => ({
                                ...currentArtist,
                                sortOrder: nextIndex + 1,
                              })),
                          }))
                        }
                        className="admin-studio-button-danger px-4 py-3 text-sm"
                      >
                        删除
                      </button>
                    </div>
                  ))
                ) : (
                  <div className="admin-reference-soft-card p-4 text-sm text-black/48">
                    当前还没有可提交的阵容艺人。你可以直接新增，也可以先在左侧做对齐预览后应用建议阵容。
                  </div>
                )}
              </div>
            </div>
          </div>
        </Section>
      ) : null}

      {currentStep === 5 ? (
        <Section title="票务" description="票务相关信息单独收纳到一个分页里，让主要操作区域保持聚焦。">
          <div className="grid gap-4 lg:grid-cols-2">
            <Field label="购票链接">
              <input
                value={draft.ticketUrl}
                onChange={(event) => updateDraft('ticketUrl', event.target.value)}
                className={textInputClassName}
                placeholder="https://..."
              />
            </Field>
            <Field label="票务币种">
              <input
                value={draft.ticketCurrency}
                onChange={(event) => updateDraft('ticketCurrency', event.target.value)}
                className={textInputClassName}
                placeholder="CNY"
              />
            </Field>
            <div className="lg:col-span-2">
              <Field label="票务备注">
                <textarea
                  value={draft.ticketNotes}
                  onChange={(event) => updateDraft('ticketNotes', event.target.value)}
                  className={textAreaClassName}
                  placeholder="例如：早鸟票已售罄，预售票次日开售"
                />
              </Field>
            </div>
          </div>

          <div className="admin-reference-card mt-6 p-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <div className="text-sm font-semibold">票档</div>
                <div className="mt-1 text-xs text-text-secondary">当前版本支持简单名称 + 价格 + 币种。</div>
              </div>
              <button
                type="button"
                onClick={() => updateDraft('ticketTiers', [...draft.ticketTiers, createEmptyTicketTierDraft()])}
                className="admin-studio-button-primary px-4 py-3 text-sm"
              >
                新增票档
              </button>
            </div>

            <div className="mt-4 space-y-3">
              {draft.ticketTiers.map((tier) => (
                <div key={tier.id} className="grid gap-3 rounded-[22px] border border-[#e8eceb] bg-[#f8f9f8] p-4 lg:grid-cols-[1.4fr_1fr_120px_auto]">
                  <input
                    value={tier.name}
                    onChange={(event) =>
                      updateDraft(
                        'ticketTiers',
                        draft.ticketTiers.map((current) => (current.id === tier.id ? { ...current, name: event.target.value } : current))
                      )
                    }
                    className={textInputClassName}
                    placeholder="票档名称"
                  />
                  <input
                    value={tier.price}
                    onChange={(event) =>
                      updateDraft(
                        'ticketTiers',
                        draft.ticketTiers.map((current) => (current.id === tier.id ? { ...current, price: event.target.value } : current))
                      )
                    }
                    className={textInputClassName}
                    placeholder="价格"
                  />
                  <input
                    value={tier.currency}
                    onChange={(event) =>
                      updateDraft(
                        'ticketTiers',
                        draft.ticketTiers.map((current) =>
                          current.id === tier.id ? { ...current, currency: event.target.value.toUpperCase() } : current
                        )
                      )
                    }
                    className={textInputClassName}
                    placeholder="币种"
                  />
                  <button
                    type="button"
                    onClick={() => updateDraft('ticketTiers', draft.ticketTiers.filter((current) => current.id !== tier.id))}
                    className="admin-studio-button-danger"
                  >
                    删除
                  </button>
                </div>
              ))}
            </div>

            {errors.ticketTiers ? <div className="mt-3 text-xs text-[#6a3530]">{errors.ticketTiers}</div> : null}
          </div>
        </Section>
      ) : null}

      {currentStep === 6 ? (
        <Section title="检查与提交" description="最后一步统一核对媒体、地点、周期、时间表和票务摘要。确认无误后再正式提交。">
          <div className="grid gap-4 xl:grid-cols-[1fr_1fr]">
            <div className="space-y-4">
              <div className="admin-reference-card p-4">
                <div className="text-sm font-semibold text-[#071110]">活动摘要</div>
                <div className="mt-4 grid gap-3 md:grid-cols-2">
                  <SummaryStat label="活动名称" value={draftTitle} tone="soft" />
                  <SummaryStat label="活动地点" value={`${draftCountry} · ${draftCity}`} tone="soft" />
                  <SummaryStat label="活动日期" value={`${draft.startDate || '未开始'} → ${draft.endDate || '未结束'}`} tone="sand" />
                  <SummaryStat label="时区" value={draft.timeZoneSelection?.timezone || '未确认'} tone="mint" />
                  <SummaryStat label="时间表条目" value={`${draft.timetableSlots.length} 条`} tone="rose" />
                  <SummaryStat label="票档数量" value={`${draft.ticketTiers.length} 个`} tone="soft" />
                </div>
              </div>

              <div className="admin-reference-card p-4">
                <div className="text-sm font-semibold text-[#071110]">地点与描述</div>
                <div className="mt-3 space-y-2 text-sm leading-6 text-black/52">
                  <p>{detailAddressDisplay}</p>
                  <p>{draft.description.trim() || '还没有填写活动描述。'}</p>
                </div>
              </div>

              <div className="admin-reference-card p-4">
                <div className="text-sm font-semibold text-[#071110]">时间表与阵容状态</div>
                <div className="mt-3 space-y-2 text-sm leading-6 text-black/52">
                  <p>当前 stage 数量：{draft.stageOrder.length || 0}</p>
                  <p>当前 lineup 艺人数量：{draft.lineupArtists.length || 0}</p>
                  <p>lineup 同步策略：{draft.lineupSyncMode === 'exact_align' ? '严格对齐' : '增量补齐'}</p>
                </div>
              </div>
            </div>

            <div className="space-y-4">
              <div className="admin-reference-card p-4">
                <div className="text-sm font-semibold text-[#071110]">媒体预览</div>
                <div className="mt-4 grid gap-4 sm:grid-cols-2">
                  {IMAGE_ZONE_CONFIG.filter((item) => draft.imageZones[item.usage].length > 0).map((item) => {
                    const firstImage = draft.imageZones[item.usage][0];
                    return (
                      <div key={item.usage} className="rounded-[24px] border border-[#e8eceb] bg-[#f8f9f8] p-4">
                        <div className="text-xs font-semibold uppercase tracking-[0.18em] text-black/42">{item.title}</div>
                        <div className="mt-3 relative aspect-[16/9] overflow-hidden rounded-[18px] border border-[#e8eceb] bg-white">
                          {firstImage ? (
                            <Image src={firstImage.remoteUrl} alt={`${item.title} preview`} fill className="object-cover" sizes="900px" />
                          ) : (
                            <div className="flex h-full items-center justify-center text-sm text-black/42">还没有上传图片</div>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              <div className="admin-studio-pastel-mint p-5">
                <div className="admin-studio-label">Ready To Submit</div>
                <div className="mt-2 text-lg font-semibold text-[#071110]">
                  {canSubmit ? '当前表单已满足提交条件。' : '还有必填项未完成，提交时会自动跳转到对应分页。'}
                </div>
                <div className="mt-3 text-sm leading-6 text-black/52">
                  {mode === 'create' ? '提交后会直接创建活动，或者进入审核队列。' : '提交后会生成活动编辑任务并处理 revision 更新。'}
                </div>
              </div>
            </div>
          </div>
        </Section>
      ) : null}

      {currentStep < totalSteps - 1 ? (
        <section className="admin-reference-card flex flex-wrap items-center justify-between gap-3 px-5 py-4">
          <button
            type="button"
            onClick={() => goToStep(currentStep - 1)}
            disabled={currentStep === 0}
            className="admin-studio-button-secondary px-5 py-3 text-sm disabled:opacity-50"
          >
            上一步
          </button>
          <div className="text-sm text-black/45">
            {currentStepItem.eyebrow} / {currentStepItem.title}
          </div>
          <button type="button" onClick={handleAdvance} className="admin-studio-button-primary px-5 py-3 text-sm">
            下一步
          </button>
        </section>
      ) : (
        <section className="admin-reference-card flex flex-wrap items-center justify-between gap-3 px-5 py-4">
          <button type="button" onClick={() => goToStep(currentStep - 1)} className="admin-studio-button-secondary px-5 py-3 text-sm">
            返回上一步
          </button>
          <div className="text-sm text-black/45">
            {currentStepItem.eyebrow} / {currentStepItem.title}
          </div>
          <div className="flex flex-wrap gap-3">
            <Link href="/admin/content/events/catalog" className="admin-studio-button-secondary px-5 py-3 text-sm">
              返回活动目录
            </Link>
            <button
              type="button"
              onClick={() => void handleSubmit()}
              disabled={submitting || uploadingUsage !== null || deletingImageId !== null}
              className="admin-studio-button-primary px-5 py-3 text-sm disabled:cursor-not-allowed disabled:opacity-60"
            >
              {submitting ? '提交中...' : submitButtonText || (mode === 'create' ? '提交活动' : '提交编辑')}
            </button>
          </div>
        </section>
      )}

        </main>
      </div>

      <EventLocationPickerModal
        open={showLocationPicker}
        initialPoint={locationPointInitial}
        initialProvider={locationPointInitial?.provider === 'google' ? 'geoapify' : locationPointInitial?.provider}
        composedQuery={[draft.country.zh || draft.country.en, draft.city.zh || draft.city.en, draft.detailAddress.zh || draft.detailAddress.en]
          .filter(Boolean)
          .join(' ')
          .trim()}
        composedQueryZh={[draft.country.zh, draft.city.zh, draft.detailAddress.zh].filter(Boolean).join(' ').trim()}
        composedQueryEn={[draft.detailAddress.en, draft.city.en, draft.country.en].filter(Boolean).join(', ').trim()}
        onClose={() => setShowLocationPicker(false)}
        onConfirm={handleLocationConfirm}
      />
    </div>
  );
}
