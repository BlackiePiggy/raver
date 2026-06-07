'use client';

import Image from 'next/image';
import Link from 'next/link';
import { ChangeEvent, ReactNode, useEffect, useMemo, useRef, useState } from 'react';
import { Check, Languages, Pencil, Plus, Trash2, X } from 'lucide-react';
import AdminCountedControl from '@/components/admin/AdminCountedControl';
import AdminImageUploadPanel from '@/components/admin/AdminImageUploadPanel';
import EntityBindingField from '@/components/admin/EntityBindingField';
import type { EntityBindingValue } from '@/components/admin/EntityBindingSearch';
import EventLocationPickerModal, {
  type EventLocationPoint,
  type EventLocationProvider,
} from '@/components/admin/EventLocationPickerModal';
import EventStudioAIImportDock from '@/components/admin/EventStudioAIImportDock';
import useOverlayBodyLock from '@/hooks/useOverlayBodyLock';
import { notificationCenterAdminApi } from '@/lib/api/notification-center-admin';
import { INPUT_LIMITS, countText } from '@/lib/input-rules';
import { formatClockTimeInTimeZone, normalizeDisplayTimeZone } from '@/lib/timezone';
import {
  createEmptyTicketTierDraft,
  createEmptyEventStudioTimetableSlotDraft,
  eventStudioApi,
  EventStudioApiError,
  buildLineupArtistsFromTimetableSlots,
  eventStudioLineupArtistIdentityKey,
  eventStudioTimetableSlotIdentityKey,
  fillLineupArtistsFromTimetableSlots,
  mapEventStudioDraftToCreateInput,
  mapEventStudioDraftToUpdateInput,
  rebaseEventStudioDatesPreservingWallDate,
  syncEventStudioLineupState,
  syncEventStudioScheduleStructure,
  validateEventStudioDraft,
  type EventStudioAlignmentPreview,
  type EventStudioCreateResult,
  type EventStudioDraft,
  type EventStudioEventDayDraft,
  type EventStudioImageOrigin,
  type EventStudioImageState,
  type EventStudioImageUsage,
  type EventStudioLineupArtistDraft,
  type EventStudioLocalizedText,
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
type LocalizedFieldKey = 'name' | 'city' | 'country' | 'detailAddress';
type LocalizedLocaleKey = 'zh' | 'en' | 'ja' | 'enFull';
type LocalizedFieldKind = 'input' | 'textarea';

type LocalizedFieldOverlayState = {
  key: LocalizedFieldKey;
  label: string;
  kind: LocalizedFieldKind;
  clearable?: boolean;
};

type EventStudioFormDJSearchResult = Awaited<ReturnType<typeof eventStudioApi.searchDJs>>[number];
type PendingDeleteTimetableStage = {
  stageName: string;
  relatedSlotCount: number;
};

const LOCALIZED_LOCALE_ITEMS: Array<{ key: LocalizedLocaleKey; label: string; hint: string }> = [
  { key: 'zh', label: '中文', hint: '用于中文展示和搜索回填。' },
  { key: 'en', label: 'English', hint: '用于英文展示和国际化回退。' },
  { key: 'ja', label: '日本語', hint: '用于日文展示。' },
  { key: 'enFull', label: 'English Full', hint: '可选，用于更完整的英文地址或全称。' },
];

const STEP_ERROR_KEYS: Record<EventStudioStepKey, Array<keyof EventStudioValidationErrors>> = {
  media: ['coverImage'],
  basic: ['name', 'city', 'country', 'detailAddress', 'timeZone', 'socialLinks'],
  time: ['startDate', 'endDate'],
  timetable: ['timetableSlots'],
  lineup: [],
  tickets: ['ticketUrl', 'ticketTiers'],
  review: ['name', 'city', 'country', 'detailAddress', 'timeZone', 'startDate', 'endDate', 'ticketUrl', 'socialLinks', 'coverImage', 'ticketTiers', 'timetableSlots'],
};

const IMAGE_ZONE_CONFIG: Array<{
  usage: EventStudioImageUsage;
  title: string;
  description: string;
  hint: string;
  emphasis: 'primary' | 'secondary';
}> = [
  { usage: 'poster', title: '海报', description: '活动主视觉，目录和详情页最优先。', hint: '建议上传海报主图。', emphasis: 'primary' },
  { usage: 'cover', title: '封面', description: '封面横图，可作为活动详情头图。', hint: '适合横版头图。', emphasis: 'primary' },
  { usage: 'lineup', title: '阵容', description: '阵容图，用于 lineup 识别和详情补充。', hint: '适合艺人阵容排版图。', emphasis: 'primary' },
  { usage: 'timetable', title: '时间表', description: '时间表图，便于人工核对排期。', hint: '适合舞台排期长图。', emphasis: 'secondary' },
  { usage: 'map', title: '地图', description: '场地地图或区域导航图。', hint: '可上传场内导览图。', emphasis: 'secondary' },
  { usage: 'other', title: '其他', description: '其他视觉素材，如票务图或补充资料。', hint: '用于补充资料。', emphasis: 'secondary' },
];

const textInputClassName = 'admin-studio-input';
const selectInputClassName = 'admin-studio-select';
const textAreaClassName = 'admin-studio-textarea min-h-28';

const EVENT_DERIVED_STATUS_META: Record<
  EventStudioDraft['derivedStatus'],
  { label: string; toneClassName: string; description: string }
> = {
  upcoming: {
    label: '即将开始',
    toneClassName: 'bg-[#fff4e8] text-[#9a5a12]',
    description: '这是根据开始和结束日期动态推导出的时间状态。',
  },
  ongoing: {
    label: '进行中',
    toneClassName: 'bg-[#e9f8ef] text-[#1d7d4d]',
    description: '这是根据开始和结束日期动态推导出的时间状态。',
  },
  ended: {
    label: '已结束',
    toneClassName: 'bg-[#eef1f3] text-[#44525f]',
    description: '这是根据开始和结束日期动态推导出的时间状态。',
  },
  cancelled: {
    label: '已取消',
    toneClassName: 'bg-[#fdecec] text-[#b13a3a]',
    description: '取消态优先于时间推导，活动会按已取消展示。',
  },
};

const firstFilledText = (...values: Array<string | undefined | null>) => {
  for (const value of values) {
    const trimmed = String(value || '').trim();
    if (trimmed) return trimmed;
  }
  return '';
};

const collapseLocalizedTextForPlainValue = (
  value: EventStudioDraft['city'] | EventStudioDraft['country']
): EventStudioDraft['city'] => {
  const zh = value.zh.trim();
  const en = value.en.trim();
  const ja = value.ja.trim();
  const enFull = value.enFull.trim();
  if (zh) return { zh, en: '', ja: '', enFull: '' };
  if (en) return { zh: '', en, ja: '', enFull: '' };
  if (ja) return { zh: '', en: '', ja, enFull: '' };
  if (enFull) return { zh: '', en: enFull, ja: '', enFull: '' };
  return { zh: '', en: '', ja: '', enFull: '' };
};

const formatEventDayLabel = (day: EventStudioDraft['eventDays'][number]) =>
  `${day.label || day.eventDayId} · ${day.date}`;

const normalizeMapProvider = (value?: string | null): EventLocationProvider | 'google' => {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'apple-mapkit' || normalized === 'apple_mapkit') {
    return 'mapkit';
  }
  if (normalized === 'amap' || normalized === 'mapkit' || normalized === 'mapbox' || normalized === 'geoapify' || normalized === 'google') {
    return normalized;
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

const MAX_MEDIA_SELECTION_COUNT = 12;

const imageHasVisibleAsset = (image: EventStudioImageState): boolean =>
  String(image.remoteUrl || '').trim().length > 0 || Boolean(image.localPreviewUrl?.trim());

const imagePreviewUrl = (image: EventStudioImageState): string =>
  String(image.remoteUrl || '').trim() || image.localPreviewUrl?.trim() || '';

const imageOriginLabel = (origin: EventStudioImageOrigin): string => {
  if (origin === 'persisted-event') return '活动已存在资源';
  if (origin === 'event-upload') return '当前编辑上传';
  if (origin === 'draft-upload') return '当前草稿上传';
  return '本地待上传';
};

const imageStatusLabel = (image: EventStudioImageState): string => {
  if (image.uploadState === 'uploading') return '上传中';
  if (image.uploadState === 'failed') return '上传失败，提交前会重试';
  if (image.uploadState === 'pending') return '等待上传';
  return imageOriginLabel(image.origin);
};

const deriveDraftEventStatus = (
  startDate: string,
  endDate: string,
  isCancelled: boolean,
  timeZoneSelection?: EventStudioDraft['timeZoneSelection'] | null
): EventStudioDraft['derivedStatus'] => {
  if (isCancelled) return 'cancelled';
  const timeZone = normalizeDisplayTimeZone(timeZoneSelection?.timezone || null);
  const normalizedStartDate = String(startDate || '').trim();
  const normalizedEndDate = String(endDate || '').trim();
  if (!normalizedStartDate || !normalizedEndDate) return 'upcoming';
  const start = new Date(`${normalizedStartDate}T00:00:00`);
  const end = new Date(`${normalizedEndDate}T23:59:59`);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return 'upcoming';
  const now = new Date();
  const zonedNow = new Date(now.toLocaleString('en-US', { timeZone }));
  if (zonedNow.getTime() < start.getTime()) return 'upcoming';
  if (zonedNow.getTime() > end.getTime()) return 'ended';
  return 'ongoing';
};

const isAbortLikeError = (error: unknown): boolean =>
  error instanceof DOMException
    ? error.name === 'AbortError'
    : error instanceof Error
      ? error.name === 'AbortError'
      : false;

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

const localizedTextFilledLocaleLabels = (value: EventStudioLocalizedText): string[] =>
  LOCALIZED_LOCALE_ITEMS.filter((item) => value[item.key].trim()).map((item) => item.label);

function LocalizedTextField({
  label,
  value,
  kind,
  placeholder,
  error,
  hint,
  maxLength,
  onPrimaryChange,
  onOpenOverlay,
}: {
  label: string;
  value: EventStudioLocalizedText;
  kind: LocalizedFieldKind;
  placeholder: string;
  error?: string;
  hint?: string;
  maxLength?: number;
  onPrimaryChange: (value: string) => void;
  onOpenOverlay: () => void;
}) {
  const filledLocales = localizedTextFilledLocaleLabels(value);
  const extraLocales = filledLocales.filter((item) => item !== '中文');
  const combinedHint = [
    hint,
    extraLocales.length ? `已填写：${extraLocales.join(' / ')}` : '右侧图标可展开编辑英文、日文等多语言内容。',
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <Field label={label} error={error} hint={combinedHint}>
      <div className={`admin-localized-field-shell ${kind === 'textarea' ? 'is-textarea' : ''}`}>
        {kind === 'textarea' ? (
          <AdminCountedControl count={countText(value.zh, true)} maxLength={maxLength} multiline>
            <textarea
              value={value.zh}
              onChange={(event) => onPrimaryChange(event.target.value)}
              className={textAreaClassName}
              placeholder={placeholder}
              maxLength={maxLength}
            />
          </AdminCountedControl>
        ) : (
          <AdminCountedControl count={countText(value.zh)} maxLength={maxLength}>
            <input
              value={value.zh}
              onChange={(event) => onPrimaryChange(event.target.value)}
              className={textInputClassName}
              placeholder={placeholder}
              maxLength={maxLength}
            />
          </AdminCountedControl>
        )}
        <button
          type="button"
          onClick={onOpenOverlay}
          className={`admin-localized-field-trigger ${kind === 'textarea' ? 'is-textarea' : ''}`}
          aria-label={`${label}多语言编辑`}
          title={`${label}多语言编辑`}
        >
          <Languages className="h-4 w-4" strokeWidth={2.2} />
          {extraLocales.length ? <span className="admin-localized-field-trigger-dot" /> : null}
        </button>
      </div>
    </Field>
  );
}

const localizedFieldMaxLength = (key: LocalizedFieldKey): number => {
  if (key === 'name') return INPUT_LIMITS.event.name;
  if (key === 'city') return INPUT_LIMITS.event.city;
  if (key === 'country') return INPUT_LIMITS.event.country;
  return INPUT_LIMITS.event.detailAddress;
};

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
  /* const renderMediaZone = (usage: EventStudioImageUsage) => {
    const config = IMAGE_ZONE_CONFIG.find((item) => item.usage === usage);
    if (!config) return null;
    const items = draft.imageZones[usage];
    const isPrimary = config.emphasis === 'primary';
    const zoneUploadingCount = items.filter((item) => item.uploadState === 'uploading').length;

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
            {items.length ? 'Add More' : 'Choose Images'}
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
          <div className="mb-3 flex items-center justify-between gap-3 text-xs text-black/45">
            <span>{items.length} images</span>
            <span>{zoneUploadingCount ? `${zoneUploadingCount} uploading` : 'Up to 12 per pick'}</span>
          </div>
          {items.length ? (
            <div className="grid gap-3 sm:grid-cols-2">
              {items.map((image, index) => (
                <div key={image.id} className="overflow-hidden rounded-[22px] border border-[#e8eceb] bg-white">
                  <div className="relative aspect-[4/3] overflow-hidden bg-[#f2f3ef]">
                    {imagePreviewUrl(image) ? (
                      image.remoteUrl.trim() ? (
                        <Image src={image.remoteUrl} alt={`${config.title}-${index + 1}`} fill className="object-cover" sizes="800px" />
                      ) : (
                        <img src={imagePreviewUrl(image)} alt={`${config.title}-${index + 1}`} className="h-full w-full object-cover" />
                      )
                    ) : (
                      <div className="flex h-full items-center justify-center text-xs text-black/35">No preview</div>
                    )}
                    {image.uploadState === 'uploading' ? (
                      <div className="absolute inset-0 flex items-center justify-center bg-black/35 text-xs font-medium text-white">Uploading...</div>
                    ) : null}
                    {image.uploadState === 'failed' ? (
                      <div className="absolute right-3 top-3 rounded-full bg-[#fff4e6] px-2 py-1 text-[11px] font-semibold text-[#b25b00]">
                        Failed
                      </div>
                    ) : null}
                  </div>
                  <div className="flex items-center justify-between gap-3 px-4 py-3">
                    <div className="min-w-0">
                      <div className="truncate text-sm font-medium text-[#071110]">{image.fileName || `${config.title} ${index + 1}`}</div>
                      <div className="mt-1 text-xs text-black/40">
                        #{image.sortOrder} · {imageStatusLabel(image)}
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() => handleImageMove(usage, image.id, -1)}
                        disabled={index === 0}
                        className="rounded-full border border-[#d6ddd7] px-3 py-2 text-xs text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
                      >
                        Up
                      </button>
                      <button
                        type="button"
                        onClick={() => handleImageMove(usage, image.id, 1)}
                        disabled={index === items.length - 1}
                        className="rounded-full border border-[#d6ddd7] px-3 py-2 text-xs text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
                      >
                        Down
                      </button>
                      <button
                        type="button"
                        onClick={() => void handleImageRemove(usage, image)}
                        className="admin-studio-button-danger px-3 py-2 text-xs"
                      >
                        {deletingImageId === image.id ? 'Removing...' : 'Remove'}
                      </button>
                    </div>
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
  }; */

  return (
    <section className="admin-event-workbench-topbar">
      <div className="min-w-0">
        <div className="admin-event-workbench-crumb">
          <span>活动目录</span>
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

const normalizeStageName = (value?: string | null): string => String(value || 'Main Stage').trim() || 'Main Stage';

const stageKey = (value?: string | null): string => normalizeStageName(value).toLowerCase();

const EVENT_STUDIO_ACT_TYPES = [
  { value: 'solo' as const, label: 'Solo', performerCount: 1 },
  { value: 'b2b' as const, label: 'B2B', performerCount: 2 },
  { value: 'b3b' as const, label: 'B3B', performerCount: 3 },
];

const normalizeActType = (value?: string | null): 'solo' | 'b2b' | 'b3b' => {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'b2b' || normalized === 'b3b') return normalized;
  return 'solo';
};

const actTypePerformerCount = (value?: string | null): number => {
  const normalized = normalizeActType(value);
  return EVENT_STUDIO_ACT_TYPES.find((item) => item.value === normalized)?.performerCount ?? 1;
};

const collaborativeActBadgeLabel = (value?: string | null): string => {
  const normalized = normalizeActType(value);
  if (normalized === 'b2b') return 'B2B';
  if (normalized === 'b3b') return 'B3B';
  return '';
};

const splitActNamesByKeyword = (value: string, keyword: 'B2B' | 'B3B'): string[] | null => {
  const trimmed = String(value || '').trim();
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
): { actType: 'solo' | 'b2b' | 'b3b'; names: string[] } | null => {
  const b3bNames = splitActNamesByKeyword(value, 'B3B');
  if (b3bNames?.length) return { actType: 'b3b', names: b3bNames };
  const b2bNames = splitActNamesByKeyword(value, 'B2B');
  if (b2bNames?.length) return { actType: 'b2b', names: b2bNames };
  return null;
};

const splitPerformerNames = (value: string, preferredActType?: string | null): string[] => {
  const trimmed = String(value || '').trim();
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

const formatPerformerNamesText = (names: string[], actType?: string | null): string => {
  const normalizedActType = normalizeActType(actType);
  const count = actTypePerformerCount(normalizedActType);
  const compact = names.map((item) => String(item || '').trim()).filter(Boolean).slice(0, count);
  if (!compact.length) return '';
  return normalizedActType === 'solo' ? compact[0] : compact.join(' / ');
};

const normalizeDisplayNameOverrideText = (
  value: string | undefined | null,
  names: string[],
  actType?: string | null
): string => {
  const trimmed = String(value || '').trim();
  if (!trimmed) return '';
  return trimmed === formatPerformerNamesText(names, actType) ? '' : trimmed;
};

const getTimetableSlotPerformerNames = (slot: EventStudioTimetableSlotDraft): string[] => {
  const performerCount = actTypePerformerCount(slot.actType);
  const names = splitPerformerNames(slot.memberNamesText, slot.actType);
  return Array.from({ length: performerCount }, (_, index) => names[index] || '');
};

const getTimetableSlotBoundDjId = (
  slot: EventStudioTimetableSlotDraft,
  performerIndex: number
): string => {
  const memberDjId = String(slot.memberDjIds[performerIndex] || '').trim();
  if (memberDjId) return memberDjId;
  return performerIndex === 0 ? String(slot.djId || '').trim() : '';
};

const getLineupArtistPerformerNames = (artist: EventStudioLineupArtistDraft): string[] => {
  const performerCount = actTypePerformerCount(artist.actType);
  const names = splitPerformerNames(artist.memberNamesText, artist.actType);
  return Array.from({ length: performerCount }, (_, index) => names[index] || '');
};

const getLineupArtistDisplayName = (artist: EventStudioLineupArtistDraft): string => {
  const performerNames = getLineupArtistPerformerNames(artist);
  return (
    normalizeDisplayNameOverrideText(artist.displayNameOverride, performerNames, artist.actType) ||
    formatPerformerNamesText(performerNames, artist.actType) ||
    '未命名演出'
  );
};

const getLineupArtistMatchedPerformerCount = (artist: EventStudioLineupArtistDraft): number =>
  Array.from({ length: actTypePerformerCount(artist.actType) }, (_, performerIndex) => getLineupArtistBoundDjId(artist, performerIndex))
    .filter(Boolean)
    .length;

const isLineupArtistFullyMatched = (artist: EventStudioLineupArtistDraft): boolean =>
  getLineupArtistMatchedPerformerCount(artist) >= actTypePerformerCount(artist.actType);

const lineupArtistStatusLabel = (artist: EventStudioLineupArtistDraft): string =>
  isLineupArtistFullyMatched(artist) ? '已匹配' : '待确认';

const lineupArtistStatusClassName = (artist: EventStudioLineupArtistDraft): string =>
  isLineupArtistFullyMatched(artist) ? 'bg-[#e8f7ee] text-[#1f8f57]' : 'bg-[#fff4e8] text-[#a6621a]';

const renderLineupArtistAvatarGroup = (artist: EventStudioLineupArtistDraft) => {
  const names = getLineupArtistPerformerNames(artist);
  return (
    <div className="flex shrink-0 -space-x-1.5">
      {names.slice(0, 3).map((name, index) => (
        <span
          key={`${artist.id}-avatar-${index}`}
          className="inline-flex h-9 w-9 items-center justify-center rounded-full border-2 border-white bg-[#eef4ff] text-xs font-semibold text-[#3567d6] shadow-[0_8px_20px_rgba(15,23,42,0.08)]"
        >
          {(name.trim()[0] || `${index + 1}`).toUpperCase()}
        </span>
      ))}
    </div>
  );
};

const getLineupArtistBoundDjId = (
  artist: EventStudioLineupArtistDraft,
  performerIndex: number
): string => {
  const memberDjId = String(artist.memberDjIds[performerIndex] || '').trim();
  if (memberDjId) return memberDjId;
  return performerIndex === 0 ? String(artist.djId || '').trim() : '';
};

const getTimetableSlotPerformerRows = (
  slot: EventStudioTimetableSlotDraft
): Array<{ key: string; label: string; isBound: boolean }> => {
  const performerCount = actTypePerformerCount(slot.actType);
  const names = splitPerformerNames(slot.memberNamesText);
  const rows = Array.from({ length: performerCount }, (_, index) => {
    const boundDjId = getTimetableSlotBoundDjId(slot, index);
    const fallbackLabel =
      performerCount === 1
        ? String(slot.djId || '').trim() || '未填写艺人'
        : `成员 ${index + 1}`;
    return {
      key: `${slot.id}-performer-${index}`,
      label: names[index] || fallbackLabel,
      isBound: Boolean(boundDjId),
    };
  }).filter((row, index) => row.label || index === 0);

  if (rows.length) {
    return rows;
  }

  return [
    {
      key: `${slot.id}-performer-empty`,
      label: '未填写艺人',
      isBound: false,
    },
  ];
};

const timetableSlotHasAnyValue = (slot: EventStudioTimetableSlotDraft): boolean =>
  [
    slot.memberNamesText,
    slot.djId,
    slot.actType,
    slot.stageName,
    slot.startTime,
    slot.endTime,
    slot.eventDayId,
    slot.localDate,
  ].some((value) => String(value || '').trim().length > 0);

const compactTimetableSlot = (slot: EventStudioTimetableSlotDraft): EventStudioTimetableSlotDraft | null => {
  const names = splitPerformerNames(slot.memberNamesText, slot.actType);
  if (!names.length) return null;
  const djIds = slot.memberDjIds
    .map((item) => String(item || '').trim())
    .filter(Boolean);
  const performerCount = Math.max(names.length, djIds.length, 1);
  const actType = performerCount >= 3 ? 'b3b' : performerCount === 2 ? 'b2b' : 'solo';
  const count = actTypePerformerCount(actType);
  return {
    ...slot,
    actType,
    memberNamesText: formatPerformerNamesText(names, actType),
    memberDjIds: slot.memberDjIds.slice(0, count).map((item) => {
      const trimmed = String(item || '').trim();
      return trimmed || null;
    }),
  };
};

const normalizeTimetableSlotActType = (
  slot: EventStudioTimetableSlotDraft,
  actType: 'solo' | 'b2b' | 'b3b'
): EventStudioTimetableSlotDraft => {
  const count = actTypePerformerCount(actType);
  return {
    ...slot,
    actType,
    memberNamesText: formatPerformerNamesText(splitPerformerNames(slot.memberNamesText, slot.actType), actType),
    memberDjIds: slot.memberDjIds.slice(0, count).map((item) => {
      const trimmed = String(item || '').trim();
      return trimmed || null;
    }),
  };
};

const normalizeLineupArtistActType = (
  artist: EventStudioLineupArtistDraft,
  actType: 'solo' | 'b2b' | 'b3b'
): EventStudioLineupArtistDraft => {
  const performerCount = actTypePerformerCount(actType);
  const memberDjIds = artist.memberDjIds.slice(0, performerCount).map((item) => {
    const trimmed = String(item || '').trim();
    return trimmed || null;
  });
  const primaryDjId = memberDjIds.find((item) => Boolean(item)) || '';
  return {
    ...artist,
    actType,
    djId: primaryDjId,
    memberDjIds,
    memberNamesText: formatPerformerNamesText(getLineupArtistPerformerNames(artist), actType),
    displayNameOverride: normalizeDisplayNameOverrideText(artist.displayNameOverride, getLineupArtistPerformerNames(artist), actType) || undefined,
  };
};

const extractTimeValue = (value: string): string => {
  const text = String(value || '').trim();
  const isoMatch = text.match(/T(\d{2}:\d{2})/);
  if (isoMatch?.[1]) return isoMatch[1];
  const looseMatch = text.match(/^(\d{1,2}):(\d{2})/);
  if (!looseMatch) return '';
  return `${looseMatch[1].padStart(2, '0')}:${looseMatch[2]}`;
};

const minutesFromTime = (value: string): number | null => {
  const match = extractTimeValue(value).match(/^(\d{2}):(\d{2})$/);
  if (!match) return null;
  return Number(match[1]) * 60 + Number(match[2]);
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
  const [submitting, setSubmitting] = useState(false);
  const [currentStep, setCurrentStep] = useState(0);
  const [activeLocalizedField, setActiveLocalizedField] = useState<LocalizedFieldOverlayState | null>(null);
  const [showTimetableDebugDrawer, setShowTimetableDebugDrawer] = useState(false);
  const [timetableDebugTab, setTimetableDebugTab] = useState<'draft' | 'focused' | 'payload'>('draft');
  const [hasLoadedTimetableStep, setHasLoadedTimetableStep] = useState(false);
  const [hasLoadedLineupStep, setHasLoadedLineupStep] = useState(false);
  const [alignmentPreviewLoading, setAlignmentPreviewLoading] = useState(false);
  const [alignmentPreview, setAlignmentPreview] = useState<EventStudioAlignmentPreview | null>(null);
  const [alignmentPreviewError, setAlignmentPreviewError] = useState<string | null>(null);
  const [conflictNotice, setConflictNotice] = useState<string | null>(null);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [showLocationPicker, setShowLocationPicker] = useState(false);
  const [uploadingUsage, setUploadingUsage] = useState<EventStudioImageUsage | null>(null);
  const [deletingImageId, setDeletingImageId] = useState<string | null>(null);
  const [selectedTimetableWeekIndex, setSelectedTimetableWeekIndex] = useState(1);
  const [selectedTimetableDayId, setSelectedTimetableDayId] = useState('');
  const [timetableSelectionMode, setTimetableSelectionMode] = useState(false);
  const [selectedTimetableSlotIds, setSelectedTimetableSlotIds] = useState<string[]>([]);
  const [focusedTimetableSlotId, setFocusedTimetableSlotId] = useState<string | null>(null);
  const [confirmedTimetableSlotIds, setConfirmedTimetableSlotIds] = useState<string[]>(
    mode === 'edit' ? draft.timetableSlots.map((slot) => slot.id) : []
  );
  const [selectedTimetableStageFilter, setSelectedTimetableStageFilter] = useState('all');
  const [editingTimetableStageKey, setEditingTimetableStageKey] = useState<string | null>(null);
  const [editingTimetableStageName, setEditingTimetableStageName] = useState('');
  const [timetableStageError, setTimetableStageError] = useState<string | null>(null);
  const [pendingDeleteTimetableStage, setPendingDeleteTimetableStage] = useState<PendingDeleteTimetableStage | null>(null);
  const [activeLineupArtistEditorId, setActiveLineupArtistEditorId] = useState<string | null>(null);
  const [draggedTimetableStage, setDraggedTimetableStage] = useState<string | null>(null);
  const [lineupDJSearchResults, setLineupDJSearchResults] = useState<Record<string, EventStudioFormDJSearchResult[]>>({});
  const [lineupDJSearchLoadingKeys, setLineupDJSearchLoadingKeys] = useState<Record<string, boolean>>({});
  const draftRef = useRef(draft);
  const uploadTasksRef = useRef<Map<string, { promise: Promise<void>; controller: AbortController }>>(new Map());
  const objectUrlsRef = useRef<Set<string>>(new Set());
  useOverlayBodyLock(Boolean(activeLocalizedField) || Boolean(pendingDeleteTimetableStage));
  const organizerBindingItems = useMemo<EntityBindingValue[]>(() => {
    if (!draft.organizerFestivalId.trim()) return [];
    return [
      {
        id: draft.organizerFestivalId.trim(),
        name: draft.organizerName.trim() || draft.organizerFestivalId.trim(),
        subtitle: null,
        imageUrl: null,
      },
    ];
  }, [draft.organizerFestivalId, draft.organizerName]);

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
  const uploadingImageCount = useMemo(
    () =>
      Object.values(draft.imageZones).reduce(
        (sum, items) => sum + items.filter((item) => item.uploadState === 'uploading').length,
        0
      ),
    [draft.imageZones]
  );
  const failedImageCount = useMemo(
    () =>
      Object.values(draft.imageZones).reduce(
        (sum, items) => sum + items.filter((item) => item.uploadState === 'failed').length,
        0
      ),
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
  const derivedStatusMeta = EVENT_DERIVED_STATUS_META[draft.derivedStatus];
  const isCancelledDraft = draft.isCancelled;
  const visibilityDraft = draft.visibility;

  useEffect(() => {
    draftRef.current = draft;
  }, [draft]);

  useEffect(() => {
    const nextDerivedStatus = deriveDraftEventStatus(
      draft.startDate,
      draft.endDate,
      draft.isCancelled,
      draft.timeZoneSelection
    );
    if (draft.derivedStatus === nextDerivedStatus) {
      return;
    }
    setDraft((current) => {
      if (current.derivedStatus === nextDerivedStatus) return current;
      return {
        ...current,
        derivedStatus: nextDerivedStatus,
      };
    });
  }, [
    draft.startDate,
    draft.endDate,
    draft.isCancelled,
    draft.timeZoneSelection,
    draft.derivedStatus,
    setDraft,
  ]);

  useEffect(() => {
    const uploadTasks = uploadTasksRef.current;
    const objectUrls = objectUrlsRef.current;
    return () => {
      uploadTasks.forEach(({ controller }) => controller.abort());
      uploadTasks.clear();
      objectUrls.forEach((url) => {
        URL.revokeObjectURL(url);
      });
      objectUrls.clear();
    };
  }, []);

  useEffect(() => {
    if (!draft.eventDays.length) {
      setSelectedTimetableDayId('');
      return;
    }
    const currentDay = draft.eventDays.find((day) => day.eventDayId === selectedTimetableDayId);
    if (currentDay) {
      setSelectedTimetableWeekIndex(currentDay.weekIndex);
      return;
    }
    const fallbackDay =
      draft.eventDays.find((day) => day.weekIndex === selectedTimetableWeekIndex) ||
      draft.eventDays[0];
    setSelectedTimetableDayId(fallbackDay.eventDayId);
    setSelectedTimetableWeekIndex(fallbackDay.weekIndex);
  }, [draft.eventDays, selectedTimetableDayId, selectedTimetableWeekIndex]);

  useEffect(() => {
    const validIds = new Set(draft.timetableSlots.map((slot) => slot.id));
    setConfirmedTimetableSlotIds((current) => current.filter((id) => validIds.has(id)));
    setSelectedTimetableSlotIds((current) => current.filter((id) => validIds.has(id)));
    setFocusedTimetableSlotId((current) => (current && validIds.has(current) ? current : null));
  }, [draft.timetableSlots]);

  useEffect(() => {
    if (!editingTimetableStageKey) return;
    const matchedStage = draft.stageOrder.find((stage) => stageKey(stage) === editingTimetableStageKey);
    if (!matchedStage) {
      setEditingTimetableStageKey(null);
      setEditingTimetableStageName('');
      return;
    }
    setEditingTimetableStageName(matchedStage);
  }, [draft.stageOrder, editingTimetableStageKey]);

  useEffect(() => {
    if (currentStep === 3) {
      setHasLoadedTimetableStep(true);
    }
    if (currentStep === 4) {
      setHasLoadedLineupStep(true);
    }
  }, [currentStep]);

  useEffect(() => {
    if (!activeLocalizedField) return;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setActiveLocalizedField(null);
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [activeLocalizedField]);

  const locationPointInitial = useMemo<EventLocationPoint | null>(() => {
    if (draft.locationPoint) {
        return {
        provider: normalizeMapProvider(draft.locationPoint.provider),
        sourceMode: draft.locationPoint.sourceMode || 'pin_drag',
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
      sourceMode: 'pin_drag',
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
              : key === 'ticketUrl'
                ? ['ticketUrl']
                : key === 'socialLinksText'
                  ? ['socialLinks']
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
        ...(key === 'city'
          ? { clearCityI18nIntent: false }
          : key === 'country'
            ? { clearCountryI18nIntent: false }
            : {}),
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

  const mutateLineupArtist = (
    artistId: string,
    updater: (artist: EventStudioLineupArtistDraft) => EventStudioLineupArtistDraft
  ) => {
    updateLineupDraft((current) => ({
      ...current,
      lineupArtists: current.lineupArtists.map((artist) => (artist.id === artistId ? updater(artist) : artist)),
    }));
  };

  const updateLineupArtistPerformerName = (artistId: string, performerIndex: number, value: string) => {
    mutateLineupArtist(artistId, (artist) => {
      const names = getLineupArtistPerformerNames(artist);
      names[performerIndex] = value;
      return {
        ...artist,
        memberNamesText: names.map((item) => item.trim()).filter(Boolean).join(' / '),
      };
    });
  };

  const updateLineupArtistPerformerBinding = (artistId: string, performerIndex: number, value: string) => {
    mutateLineupArtist(artistId, (artist) => {
      const performerCount = actTypePerformerCount(artist.actType);
      const memberDjIds = Array.from({ length: performerCount }, (_, index) => {
        const currentValue = String(artist.memberDjIds[index] || '').trim();
        if (index !== performerIndex) return currentValue || null;
        const trimmed = value.trim();
        return trimmed || null;
      });
      const primaryDjId = memberDjIds.find((item) => Boolean(item)) || '';
      return {
        ...artist,
        djId: primaryDjId,
        memberDjIds,
      };
    });
  };

  const updateLineupArtistDisplayName = (artistId: string, value: string) => {
    mutateLineupArtist(artistId, (artist) => {
      const performerNames = getLineupArtistPerformerNames(artist);
      return {
        ...artist,
        displayNameOverride: normalizeDisplayNameOverrideText(value, performerNames, artist.actType) || undefined,
      };
    });
  };

  const lineupSearchKey = (artistId: string, performerIndex: number) => `${artistId}-${performerIndex}`;

  const searchLineupArtistDJ = async (artistId: string, performerIndex: number, query: string) => {
    const key = lineupSearchKey(artistId, performerIndex);
    const trimmed = query.trim();
    if (!trimmed) {
      setLineupDJSearchResults((current) => ({ ...current, [key]: [] }));
      return;
    }
    setLineupDJSearchLoadingKeys((current) => ({ ...current, [key]: true }));
    try {
      const items = await eventStudioApi.searchDJs(trimmed);
      setLineupDJSearchResults((current) => ({
        ...current,
        [key]: items.filter((item) => Boolean(item.id)),
      }));
    } catch {
      setLineupDJSearchResults((current) => ({ ...current, [key]: [] }));
    } finally {
      setLineupDJSearchLoadingKeys((current) => ({ ...current, [key]: false }));
    }
  };

  const bindLineupArtistDJ = (
    artistId: string,
    performerIndex: number,
    dj: EventStudioFormDJSearchResult
  ) => {
    updateLineupArtistPerformerBinding(artistId, performerIndex, dj.id);
    const key = lineupSearchKey(artistId, performerIndex);
    setLineupDJSearchResults((current) => ({ ...current, [key]: [] }));
  };

  const materializeEditableLineupArtists = (current: EventStudioDraft): EventStudioLineupArtistDraft[] => {
    if (current.lineupArtists.length) return current.lineupArtists;
    return buildLineupArtistsFromTimetableSlots(current.timetableSlots).map((artist, index) => ({
      ...artist,
      id: artist.id || crypto.randomUUID(),
      sortOrder: artist.sortOrder || index + 1,
    }));
  };

  const openLineupArtistEditor = (artistId: string) => {
    updateLineupDraft((current) => (
      current.lineupArtists.length
        ? current
        : {
            ...current,
            lineupArtists: materializeEditableLineupArtists(current),
          }
    ));
    setActiveLineupArtistEditorId(artistId);
  };

  const addLineupArtist = () => {
    const nextArtistId = crypto.randomUUID();
    updateLineupDraft((current) => {
      const lineupArtists = materializeEditableLineupArtists(current);
      return {
        ...current,
        lineupArtists: [
          ...lineupArtists,
          {
            id: nextArtistId,
            canonicalArtistId: null,
            djId: '',
            memberDjIds: [],
            memberNamesText: '',
            sortOrder: lineupArtists.length + 1,
            actType: 'solo',
          },
        ],
      };
    });
    setActiveLineupArtistEditorId(nextArtistId);
  };

  const removeLineupArtist = (artistId: string) => {
    updateLineupDraft((current) => ({
      ...current,
      lineupArtists: materializeEditableLineupArtists(current)
        .filter((artist) => artist.id !== artistId)
        .map((artist, index) => ({
          ...artist,
          sortOrder: index + 1,
        })),
    }));
    setActiveLineupArtistEditorId((current) => (current === artistId ? null : current));
  };

  const eventDisplayTimeZone = normalizeDisplayTimeZone(draft.timeZoneSelection?.timezone || draft.timeZoneQuery);
  const activeLocalizedValue = activeLocalizedField ? draft[activeLocalizedField.key] : null;
  const timetableStepActive = hasLoadedTimetableStep || currentStep === 3;
  const lineupStepActive = hasLoadedLineupStep || currentStep === 4;

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

  const _legacyHandleImageUpload = async (event: ChangeEvent<HTMLInputElement>, usage: EventStudioImageUsage) => {
    const files = Array.from(event.target.files || []);
    if (!files.length) return;

    try {
      setSubmitError(null);
      setUploadingUsage(usage);
      const uploadedItems: EventStudioImageState[] = await Promise.all(
        files.map(async (file) => {
          const uploaded = await eventStudioApi.uploadImage(file, {
            usage,
            ...(mode === 'edit' && eventId
              ? { eventId }
              : { draftId: draft.id }),
          });
          return {
            id: crypto.randomUUID(),
            remoteUrl: uploaded.url,
            fileName: uploaded.fileName || file.name,
            usage,
            origin: mode === 'edit' && eventId ? 'event-upload' : 'draft-upload',
            sortOrder: 0,
          };
        })
      );

      updateDraftState(
        (current) => {
          const nextZones = cloneImageZones(current.imageZones);
          const currentItems = [...nextZones[usage]];
          const appended: EventStudioImageState[] = uploadedItems.map((item, index) => ({
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

  const _legacyHandleImageRemove = async (usage: EventStudioImageUsage, image: EventStudioImageState) => {
    try {
      setSubmitError(null);
      setDeletingImageId(image.id);
      if (image.origin === 'draft-upload') {
        await eventStudioApi.deleteImages({
          draftId: draft.id,
          urls: [image.remoteUrl],
        });
      } else if (image.origin === 'event-upload' && mode === 'edit' && eventId) {
        await eventStudioApi.deleteImages({
          eventId,
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

  const revokeObjectUrl = (url?: string | null) => {
    const normalized = String(url || '').trim();
    if (!normalized || !objectUrlsRef.current.has(normalized)) return;
    URL.revokeObjectURL(normalized);
    objectUrlsRef.current.delete(normalized);
  };

  const uploadedImageOrigin: EventStudioImageOrigin = mode === 'edit' && eventId ? 'event-upload' : 'draft-upload';

  const deleteUploadedImageByUrlIfNeeded = async (image: Pick<EventStudioImageState, 'origin' | 'remoteUrl'>) => {
    const remoteUrl = image.remoteUrl.trim();
    if (!remoteUrl) return;
    if (image.origin === 'draft-upload') {
      await eventStudioApi.deleteImages({
        draftId: draftRef.current.id,
        urls: [remoteUrl],
      });
      return;
    }
    if (image.origin === 'event-upload' && mode === 'edit' && eventId) {
      await eventStudioApi.deleteImages({
        eventId,
        urls: [remoteUrl],
      });
    }
  };

  const markImageUploadState = (usage: EventStudioImageUsage, imageId: string, uploadState: EventStudioImageState['uploadState']) => {
    updateDraftState((current) => {
      const nextZones = cloneImageZones(current.imageZones);
      nextZones[usage] = nextZones[usage].map((image) =>
        image.id === imageId
          ? {
              ...image,
              uploadState,
            }
          : image
      );
      return {
        ...current,
        imageZones: nextZones,
      };
    });
  };

  const startImmediateImageUpload = (usage: EventStudioImageUsage, image: EventStudioImageState) => {
    const localFile = image.localFile;
    if (!localFile) return Promise.resolve();

    uploadTasksRef.current.get(image.id)?.controller.abort();
    markImageUploadState(usage, image.id, 'uploading');
    const controller = new AbortController();

    const uploadPromise = (async () => {
      try {
        const uploaded = await eventStudioApi.uploadImage(localFile, {
          usage,
          ...(mode === 'edit' && eventId ? { eventId } : { draftId: draftRef.current.id }),
          signal: controller.signal,
        });

        let removedBeforePersist = false;
        let previousPreviewUrl: string | null = null;
        updateDraftState((current) => {
          const nextZones = cloneImageZones(current.imageZones);
          const currentItems = [...nextZones[usage]];
          const imageIndex = currentItems.findIndex((item) => item.id === image.id);
          if (imageIndex < 0) {
            removedBeforePersist = true;
            return current;
          }
          previousPreviewUrl = currentItems[imageIndex].localPreviewUrl || null;
          currentItems[imageIndex] = {
            ...currentItems[imageIndex],
            remoteUrl: uploaded.url,
            fileName: uploaded.fileName || currentItems[imageIndex].fileName,
            origin: uploadedImageOrigin,
            uploadState: 'uploaded',
            localFile: null,
            localPreviewUrl: null,
          };
          nextZones[usage] = currentItems;
          return {
            ...current,
            imageZones: nextZones,
          };
        });

        if (removedBeforePersist) {
          await deleteUploadedImageByUrlIfNeeded({
            origin: uploadedImageOrigin,
            remoteUrl: uploaded.url,
          });
          return;
        }

        revokeObjectUrl(previousPreviewUrl);
      } catch (error) {
        if (isAbortLikeError(error)) return;
        markImageUploadState(usage, image.id, 'failed');
        setSubmitError(error instanceof Error ? error.message : '鍥剧墖涓婁紶澶辫触');
      } finally {
        uploadTasksRef.current.delete(image.id);
      }
    })();

    uploadTasksRef.current.set(image.id, {
      promise: uploadPromise,
      controller,
    });
    return uploadPromise;
  };

  const waitForOutstandingImageUploads = async () => {
    const tasks = Array.from(uploadTasksRef.current.values()).map((entry) => entry.promise);
    if (!tasks.length) return;
    await Promise.allSettled(tasks);
  };

  const uploadPendingImagesIfNeeded = async () => {
    await waitForOutstandingImageUploads();

    for (const [usage, items] of Object.entries(draftRef.current.imageZones) as Array<[EventStudioImageUsage, EventStudioImageState[]]>) {
      for (const image of items) {
        if (image.remoteUrl.trim()) continue;
        if (!image.localFile) {
          throw new Error('Some images are still pending upload, but the local file is no longer available. Remove and upload them again.');
        }
        await startImmediateImageUpload(usage, image);
      }
    }

    await waitForOutstandingImageUploads();

    const failedImage = Object.values(draftRef.current.imageZones)
      .flat()
      .find((image) => image.uploadState === 'failed' || !image.remoteUrl.trim());
    if (failedImage) {
      throw new Error('Some images still failed to upload. Retry or remove them before submitting.');
    }
  };

  const handleImageUploadFiles = async (selectedFiles: File[], usage: EventStudioImageUsage) => {
    if (!selectedFiles.length) return;

    const files = selectedFiles.slice(0, MAX_MEDIA_SELECTION_COUNT);
    if (selectedFiles.length > MAX_MEDIA_SELECTION_COUNT) {
      setConflictNotice(`单次最多选择 ${MAX_MEDIA_SELECTION_COUNT} 张图片，已按前 ${MAX_MEDIA_SELECTION_COUNT} 张处理。`);
    }

    setSubmitError(null);
    const pendingItems: EventStudioImageState[] = files.map((file, index) => {
      const previewUrl = URL.createObjectURL(file);
      objectUrlsRef.current.add(previewUrl);
      return {
        id: crypto.randomUUID(),
        remoteUrl: '',
        fileName: file.name,
        usage,
        origin: 'pending-local',
        sortOrder: index + 1,
        mimeType: file.type || null,
        localPreviewUrl: previewUrl,
        localFile: file,
        uploadState: 'pending',
      };
    });

    updateDraftState(
      (current) => {
        const nextZones = cloneImageZones(current.imageZones);
        const currentItems = [...nextZones[usage]];
        nextZones[usage] = normalizeZoneSortOrder([...currentItems, ...pendingItems]);
        return {
          ...current,
          imageZones: nextZones,
        };
      },
      { clearErrorKeys: ['coverImage'] }
    );

    pendingItems.forEach((item) => {
      void startImmediateImageUpload(usage, item);
    });
  };

  const handleImageUpload = async (event: ChangeEvent<HTMLInputElement>, usage: EventStudioImageUsage) => {
    const selectedFiles = Array.from(event.target.files || []);
    event.target.value = '';
    await handleImageUploadFiles(selectedFiles, usage);
  };

  const handleImageMove = (usage: EventStudioImageUsage, imageId: string, direction: number) => {
    updateDraftState((current) => {
      const nextZones = cloneImageZones(current.imageZones);
      const currentItems = [...nextZones[usage]];
      const currentIndex = currentItems.findIndex((item) => item.id === imageId);
      const nextIndex = currentIndex + direction;
      if (currentIndex < 0 || nextIndex < 0 || nextIndex >= currentItems.length) {
        return current;
      }
      [currentItems[currentIndex], currentItems[nextIndex]] = [currentItems[nextIndex], currentItems[currentIndex]];
      nextZones[usage] = normalizeZoneSortOrder(currentItems);
      return {
        ...current,
        imageZones: nextZones,
      };
    });
  };

  const handleImageRemove = async (usage: EventStudioImageUsage, image: EventStudioImageState) => {
    const uploadTask = uploadTasksRef.current.get(image.id);
    if (uploadTask) {
      uploadTask.controller.abort();
      uploadTasksRef.current.delete(image.id);
    }

    try {
      setSubmitError(null);
      setDeletingImageId(image.id);
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
      revokeObjectUrl(image.localPreviewUrl);

      if (image.origin !== 'persisted-event') {
        await deleteUploadedImageByUrlIfNeeded(image);
      }
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '鍥剧墖绉婚櫎澶辫触');
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
      await uploadPendingImagesIfNeeded();
      const result =
        mode === 'edit' && eventId
          ? await eventStudioApi.updateEvent(eventId, mapEventStudioDraftToUpdateInput(draftRef.current))
          : await eventStudioApi.createEvent(mapEventStudioDraftToCreateInput(draftRef.current));
      setAlignmentPreview(null);
      onSubmit(result);
    } catch (error) {
      const failureTitle =
        firstFilledText(
          draftRef.current.name.zh,
          draftRef.current.name.en,
          draftRef.current.name.ja,
          draftRef.current.name.enFull
        ) || (mode === 'edit' ? '活动编辑失败' : '活动创建失败');
      await notificationCenterAdminApi
        .logContentHistoryFailure({
          entityType: 'event',
          entityId: eventId ?? null,
          taskType: 'event_release',
          operationType: mode === 'edit' ? 'edit' : 'create',
          title: failureTitle,
          summary: firstFilledText(draftRef.current.detailAddress.zh, draftRef.current.detailAddress.en) || null,
          sourceRoute: mode === 'edit' && eventId ? `/admin/content/events/${eventId}/edit` : '/admin/content/events/new',
          errorMessage: error instanceof Error ? error.message : '活动提交失败',
          payload: {
            startDate: draftRef.current.startDate,
            endDate: draftRef.current.endDate,
          },
        })
        .catch(() => undefined);
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
        actType: artist.memberNames && artist.memberNames.length >= 3 ? 'b3b' : artist.memberNames && artist.memberNames.length === 2 ? 'b2b' : 'solo',
        sortOrder: artist.sortOrder ?? index + 1,
      })),
      lineupSyncMode: 'exact_align',
    }));
  };

  const clearLocalizedI18n = (key: 'city' | 'country') => {
    updateDraftState(
      (current) => ({
        ...current,
        [key]: collapseLocalizedTextForPlainValue(current[key]),
        ...(key === 'city'
          ? { clearCityI18nIntent: true }
          : { clearCountryI18nIntent: true }),
      }),
      {
        clearErrorKeys: key === 'city' ? ['city'] : ['country'],
      }
    );
  };

  const markTimetableSlotDirty = (slotId: string) => {
    setConfirmedTimetableSlotIds((current) => current.filter((id) => id !== slotId));
  };

  const mutateTimetableSlot = (
    slotId: string,
    updater: (slot: EventStudioTimetableSlotDraft) => EventStudioTimetableSlotDraft,
    options?: { preserveConfirmed?: boolean }
  ) => {
    if (!options?.preserveConfirmed) {
      markTimetableSlotDirty(slotId);
    }
    updateScheduleDerivedDraft((current) => ({
      ...current,
      timetableSlots: current.timetableSlots.map((slot) => (slot.id === slotId ? updater(slot) : slot)),
    }));
  };

  const updateTimetableSlotPerformerBinding = (
    slotId: string,
    performerIndex: number,
    payload: { djId: string | null; preserveConfirmed?: boolean }
  ) => {
    mutateTimetableSlot(
      slotId,
      (slot) => {
        const performerCount = actTypePerformerCount(slot.actType);
        const nextMemberDjIds = Array.from({ length: performerCount }, (_, index) => {
          const currentValue = String(slot.memberDjIds[index] || '').trim();
          if (index !== performerIndex) return currentValue || null;
          return payload.djId?.trim() ? payload.djId.trim() : null;
        });
        const primaryDjId = nextMemberDjIds.find((item) => Boolean(item)) || '';
        return {
          ...slot,
          djId: primaryDjId,
          memberDjIds: nextMemberDjIds,
        };
      },
      { preserveConfirmed: payload.preserveConfirmed }
    );
  };

  const canConfirmTimetableSlot = (slot: EventStudioTimetableSlotDraft): boolean => {
    if (!slot.eventDayId || !slot.stageName.trim() || !slot.startTime || !slot.endTime) return false;
    const performerNames = getTimetableSlotPerformerNames(slot);
    return performerNames.some((name) => Boolean(name.trim())) || slot.memberDjIds.some((id) => Boolean(String(id || '').trim()));
  };

  const confirmTimetableSlot = (slot: EventStudioTimetableSlotDraft) => {
    if (!canConfirmTimetableSlot(slot)) return;
    setConfirmedTimetableSlotIds((current) => (current.includes(slot.id) ? current : [...current, slot.id]));
    if (focusedTimetableSlotId === slot.id) {
      setFocusedTimetableSlotId(null);
    }
  };

  const toggleTimetableSelectionMode = () => {
    setTimetableSelectionMode((current) => {
      if (current) setSelectedTimetableSlotIds([]);
      return !current;
    });
  };

  const toggleTimetableSlotSelection = (slotId: string) => {
    setSelectedTimetableSlotIds((current) =>
      current.includes(slotId) ? current.filter((id) => id !== slotId) : [...current, slotId]
    );
  };

  const focusTimetableSlot = (slotId: string) => {
    const slot = draft.timetableSlots.find((item) => item.id === slotId);
    if (slot?.stageName) {
      setSelectedTimetableStageFilter(stageKey(slot.stageName));
    }
    setFocusedTimetableSlotId(slotId);
    if (typeof window === 'undefined') return;
    window.setTimeout(() => {
      document.getElementById(`timetable-slot-editor-${slotId}`)?.scrollIntoView({
        behavior: 'smooth',
        block: 'center',
      });
    }, 60);
  };

  const handleTimetableSlotCardClick = (slotId: string) => {
    if (timetableSelectionMode) {
      toggleTimetableSlotSelection(slotId);
      return;
    }
    focusTimetableSlot(slotId);
  };

  const moveStageOrder = (stage: string, direction: -1 | 1) => {
    const normalizedStage = normalizeStageName(stage);
    updateScheduleDerivedDraft((current) => {
      const mergedStages = [...current.stageOrder];
      if (!mergedStages.some((item) => stageKey(item) === stageKey(normalizedStage))) {
        mergedStages.push(normalizedStage);
      }
      current.timetableSlots.forEach((slot) => {
        const normalizedSlotStage = normalizeStageName(slot.stageName);
        if (!mergedStages.some((item) => stageKey(item) === stageKey(normalizedSlotStage))) {
          mergedStages.push(normalizedSlotStage);
        }
      });
      const fromIndex = mergedStages.findIndex((item) => stageKey(item) === stageKey(normalizedStage));
      const toIndex = fromIndex + direction;
      if (fromIndex < 0 || toIndex < 0 || toIndex >= mergedStages.length) {
        return current;
      }
      const nextStageOrder = [...mergedStages];
      const [moved] = nextStageOrder.splice(fromIndex, 1);
      nextStageOrder.splice(toIndex, 0, moved);
      return {
        ...current,
        stageOrder: nextStageOrder,
      };
    });
  };

  const moveStageOrderBefore = (stage: string, targetStage: string) => {
    const normalizedStage = normalizeStageName(stage);
    const normalizedTargetStage = normalizeStageName(targetStage);
    if (stageKey(normalizedStage) === stageKey(normalizedTargetStage)) return;
    updateScheduleDerivedDraft((current) => {
      const mergedStages = [...current.stageOrder];
      const pushStage = (value: string) => {
        const normalized = normalizeStageName(value);
        if (!mergedStages.some((item) => stageKey(item) === stageKey(normalized))) {
          mergedStages.push(normalized);
        }
      };
      pushStage(normalizedStage);
      pushStage(normalizedTargetStage);
      current.timetableSlots.forEach((slot) => pushStage(slot.stageName));
      const fromIndex = mergedStages.findIndex((item) => stageKey(item) === stageKey(normalizedStage));
      const targetIndex = mergedStages.findIndex((item) => stageKey(item) === stageKey(normalizedTargetStage));
      if (fromIndex < 0 || targetIndex < 0) return current;
      const nextStageOrder = [...mergedStages];
      const [moved] = nextStageOrder.splice(fromIndex, 1);
      const adjustedTargetIndex = nextStageOrder.findIndex((item) => stageKey(item) === stageKey(normalizedTargetStage));
      nextStageOrder.splice(adjustedTargetIndex < 0 ? nextStageOrder.length : adjustedTargetIndex, 0, moved);
      return {
        ...current,
        stageOrder: nextStageOrder,
      };
    });
  };

  const addTimetableStage = () => {
    setTimetableStageError(null);
    updateScheduleDerivedDraft((current) => {
      const nextIndex = current.stageOrder.length + 1;
      let stageName = `Stage ${nextIndex}`;
      let suffix = nextIndex;
      while (current.stageOrder.some((stage) => stageKey(stage) === stageKey(stageName))) {
        suffix += 1;
        stageName = `Stage ${suffix}`;
      }
      return {
        ...current,
        stageOrder: [...current.stageOrder, stageName],
      };
    });
  };

  const startEditingTimetableStage = (stage: string) => {
    setEditingTimetableStageKey(stageKey(stage));
    setEditingTimetableStageName(stage);
    setTimetableStageError(null);
  };

  const cancelEditingTimetableStage = () => {
    setEditingTimetableStageKey(null);
    setEditingTimetableStageName('');
    setTimetableStageError(null);
  };

  const renameTimetableStage = (stage: string) => {
    const originalKey = stageKey(stage);
    const trimmedName = editingTimetableStageName.trim();
    if (!trimmedName) {
      setTimetableStageError('舞台名称不能为空。');
      return;
    }
    const targetKey = stageKey(trimmedName);
    if (draft.stageOrder.some((item) => stageKey(item) === targetKey && stageKey(item) !== originalKey)) {
      setTimetableStageError(`舞台「${trimmedName}」已存在，请使用其他名称。`);
      return;
    }
    setTimetableStageError(null);
    updateScheduleDerivedDraft((current) => ({
      ...current,
      stageOrder: current.stageOrder.map((item) => (stageKey(item) === originalKey ? trimmedName : item)),
      timetableSlots: current.timetableSlots.map((slot) =>
        stageKey(slot.stageName) === originalKey
          ? {
              ...slot,
              stageName: trimmedName,
            }
          : slot
      ),
    }));
    if (selectedTimetableStageFilter === originalKey) {
      setSelectedTimetableStageFilter(targetKey);
    }
    setEditingTimetableStageKey(null);
    setEditingTimetableStageName('');
  };

  const removeTimetableStage = (stage: string) => {
    const normalizedStage = normalizeStageName(stage);
    const targetKey = stageKey(normalizedStage);
    const relatedSlotCount = draft.timetableSlots.filter((slot) => stageKey(slot.stageName) === targetKey).length;
    setPendingDeleteTimetableStage({
      stageName: normalizedStage,
      relatedSlotCount,
    });
  };

  const confirmRemoveTimetableStage = () => {
    if (!pendingDeleteTimetableStage) return;
    const normalizedStage = normalizeStageName(pendingDeleteTimetableStage.stageName);
    const targetKey = stageKey(normalizedStage);
    setTimetableStageError(null);
    updateScheduleDerivedDraft((current) => ({
      ...current,
      stageOrder: current.stageOrder.filter((item) => stageKey(item) !== targetKey),
      timetableSlots: current.timetableSlots
        .filter((slot) => stageKey(slot.stageName) !== targetKey)
        .map((slot, index) => ({
          ...slot,
          sortOrder: index + 1,
        })),
    }));
    setSelectedTimetableSlotIds((current) =>
      current.filter((slotId) => {
        const slot = draft.timetableSlots.find((item) => item.id === slotId);
        return slot ? stageKey(slot.stageName) !== targetKey : false;
      })
    );
    setConfirmedTimetableSlotIds((current) =>
      current.filter((slotId) => {
        const slot = draft.timetableSlots.find((item) => item.id === slotId);
        return slot ? stageKey(slot.stageName) !== targetKey : false;
      })
    );
    setFocusedTimetableSlotId((current) => {
      if (!current) return null;
      const slot = draft.timetableSlots.find((item) => item.id === current);
      return slot && stageKey(slot.stageName) === targetKey ? null : current;
    });
    if (selectedTimetableStageFilter === targetKey) {
      setSelectedTimetableStageFilter('all');
    }
    if (editingTimetableStageKey === targetKey) {
      cancelEditingTimetableStage();
    }
    setPendingDeleteTimetableStage(null);
  };

  const addTimetableSlot = (stageName?: string) => {
    updateScheduleDerivedDraft((current) => {
      const filteredStage =
        selectedTimetableStageFilter === 'all'
          ? ''
          : visibleStageOrder.find((stage) => stageKey(stage) === selectedTimetableStageFilter) || '';
      const targetStage = normalizeStageName(stageName || filteredStage || visibleStageOrder[0] || current.stageOrder[0] || 'Main Stage');
      return {
        ...current,
        stageOrder: current.stageOrder.some((stage) => stageKey(stage) === stageKey(targetStage))
          ? current.stageOrder
          : [...current.stageOrder, targetStage],
        timetableSlots: [
          ...current.timetableSlots,
          createEmptyEventStudioTimetableSlotDraft(
            current.eventDays.find((day) => day.eventDayId === selectedTimetableDay?.eventDayId) || current.eventDays[0],
            targetStage
          ),
        ].map((slot, index) => ({
          ...slot,
          sortOrder: index + 1,
        })),
      };
    });
  };

  const moveSelectedTimetableSlotsToDay = (day: EventStudioEventDayDraft) => {
    if (!selectedTimetableSlotIds.length) return;
    updateScheduleDerivedDraft((current) => ({
      ...current,
      timetableSlots: current.timetableSlots.map((slot) =>
        selectedTimetableSlotIds.includes(slot.id)
          ? {
              ...slot,
              eventDayId: day.eventDayId,
              weekIndex: day.weekIndex,
              dayIndexInWeek: day.dayIndexInWeek,
              overallDayIndex: day.overallDayIndex,
              localDate: day.date,
            }
          : slot
      ),
    }));
    setSelectedTimetableWeekIndex(day.weekIndex);
    setSelectedTimetableDayId(day.eventDayId);
    setSelectedTimetableSlotIds([]);
    setTimetableSelectionMode(false);
  };

  const moveSelectedTimetableSlotsToStage = (stage: string) => {
    const normalizedStage = normalizeStageName(stage);
    if (!selectedTimetableSlotIds.length || !normalizedStage) return;
    updateScheduleDerivedDraft((current) => ({
      ...current,
      timetableSlots: current.timetableSlots.map((slot) =>
        selectedTimetableSlotIds.includes(slot.id) ? { ...slot, stageName: normalizedStage } : slot
      ),
      stageOrder: current.stageOrder.some((item) => stageKey(item) === stageKey(normalizedStage))
        ? current.stageOrder
        : [...current.stageOrder, normalizedStage],
    }));
    setSelectedTimetableSlotIds([]);
    setTimetableSelectionMode(false);
  };

  const cleanupVisibleTimetableSlots = () => {
    const visibleIds = new Set(visibleTimetableSlots.map((slot) => slot.id));
    updateScheduleDerivedDraft((current) => ({
      ...current,
      timetableSlots: current.timetableSlots
        .flatMap((slot) => {
          if (!visibleIds.has(slot.id)) return [slot];
          const cleaned = compactTimetableSlot(slot);
          return cleaned ? [cleaned] : [];
        })
        .map((slot, index) => ({ ...slot, sortOrder: index + 1 })),
    }));
    setSelectedTimetableSlotIds((current) => current.filter((id) => !visibleIds.has(id)));
  };

  const deleteAllTimetableSlots = () => {
    updateScheduleDerivedDraft((current) => ({
      ...current,
      stageOrder: [],
      timetableSlots: [],
    }));
    setSelectedTimetableSlotIds([]);
    setTimetableSelectionMode(false);
    setFocusedTimetableSlotId(null);
    setConfirmedTimetableSlotIds([]);
    setSelectedTimetableStageFilter('all');
    cancelEditingTimetableStage();
    setDraggedTimetableStage(null);
  };

  const removeTimetableSlot = (slotId: string) => {
    updateScheduleDerivedDraft((current) => ({
      ...current,
      timetableSlots: current.timetableSlots
        .filter((currentSlot) => currentSlot.id !== slotId)
        .map((currentSlot, index) => ({
          ...currentSlot,
          sortOrder: index + 1,
        })),
    }));
  };

  const renderTimetableSlotEditorCard = (
    slot: EventStudioTimetableSlotDraft,
    options?: {
      dayLabel?: string;
      showOutOfRangeBadge?: boolean;
    }
  ) => {
    const performerCount = actTypePerformerCount(slot.actType);
    const performerNames = getTimetableSlotPerformerNames(slot);
    const actBadge = collaborativeActBadgeLabel(slot.actType);
    const isConfirmed = confirmedTimetableSlotIds.includes(slot.id);
    const isExpanded = focusedTimetableSlotId === slot.id || !isConfirmed;
    const boundCount = Array.from({ length: performerCount }, (_, index) => getTimetableSlotBoundDjId(slot, index)).filter(Boolean).length;
    const dayLabel = options?.dayLabel || slot.localDate || selectedTimetableDay?.date || '未设置日期';

    return (
      <div
        id={`timetable-slot-editor-${slot.id}`}
        key={slot.id}
        className={`admin-event-slot-editor-card rounded-[24px] border border-[#e8eceb] bg-[#f8f9f8] p-4 ${focusedTimetableSlotId === slot.id ? 'is-focused' : ''} ${isConfirmed ? 'is-confirmed' : 'is-draft'} ${isExpanded ? 'is-expanded' : 'is-collapsed'} ${options?.showOutOfRangeBadge ? 'is-out-of-range' : ''}`}
      >
        <div className="admin-event-slot-editor-summary">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <strong>{performerNames.filter(Boolean).join(' / ') || '未填写艺人'}</strong>
              {actBadge ? <span className="admin-event-collab-badge">{actBadge}</span> : null}
              {options?.showOutOfRangeBadge ? <span className="admin-event-slot-editor-warning-badge">超出活动日期</span> : null}
            </div>
            <div className="admin-event-slot-editor-summary-meta">
              <span>{formatTimetableSlotRange(slot)}</span>
              <span>{slot.stageName || '未命名舞台'}</span>
              <span>{dayLabel}</span>
              <span>{normalizeActType(slot.actType).toUpperCase()}</span>
            </div>
          </div>
          <div className="admin-event-slot-editor-summary-actions">
            <span
              className={`admin-event-slot-editor-status-badge ${
                isConfirmed ? 'is-confirmed' : boundCount === performerCount && performerCount > 0 ? 'is-bound' : 'is-pending'
              }`}
            >
              {isConfirmed ? '已确认' : `${boundCount}/${performerCount} 已绑定`}
            </span>
            {isExpanded ? null : (
              <div className="flex flex-wrap justify-end gap-2">
                <button
                  type="button"
                  onClick={() => focusTimetableSlot(slot.id)}
                  className="admin-studio-button-secondary px-4 py-2 text-sm"
                >
                  编辑
                </button>
                <button
                  type="button"
                  onClick={() => removeTimetableSlot(slot.id)}
                  className="admin-studio-button-danger px-4 py-2 text-sm"
                >
                  删除
                </button>
              </div>
            )}
          </div>
        </div>

        <div className="admin-event-slot-editor-summary-performers">
          {performerNames.map((performerName, performerIndex) => {
            const boundDjId = getTimetableSlotBoundDjId(slot, performerIndex);
            const collapsedIdLabel =
              normalizeActType(slot.actType) === 'solo'
                ? boundDjId || '未绑定 DJ'
                : `成员 ${performerIndex + 1} · ${boundDjId || '未绑定'}`;
            return (
              <div
                key={`${slot.id}-summary-${performerIndex}`}
                className={`admin-event-slot-editor-summary-performer ${isExpanded ? '' : 'is-id-only'}`}
              >
                {isExpanded ? (
                  <span className="admin-event-slot-editor-summary-name">
                    {performerName || `成员 ${performerIndex + 1}`}
                  </span>
                ) : null}
                <span className={`admin-event-slot-editor-summary-inline-id ${boundDjId ? 'is-bound' : 'is-empty'}`}>
                  {isExpanded ? boundDjId || '未绑定' : collapsedIdLabel}
                </span>
              </div>
            );
          })}
        </div>

        {isExpanded ? (
          <div className="mt-4 grid gap-3 lg:grid-cols-3">
            <Field label="演出形式">
              <div className="admin-studio-select-shell">
                <select
                  value={normalizeActType(slot.actType)}
                  onChange={(event) =>
                    mutateTimetableSlot(slot.id, (currentSlot) =>
                      normalizeTimetableSlotActType(currentSlot, normalizeActType(event.target.value))
                    )
                  }
                  className={selectInputClassName}
                >
                  {EVENT_STUDIO_ACT_TYPES.map((item) => (
                    <option key={item.value} value={item.value}>
                      {item.label}
                    </option>
                  ))}
                </select>
              </div>
            </Field>

            <Field label="演出日">
              <div className="admin-studio-select-shell">
                <select
                  value={slot.eventDayId}
                  onChange={(event) => {
                    const selectedDay = draft.eventDays.find((day) => day.eventDayId === event.target.value);
                    if (!selectedDay) return;
                    mutateTimetableSlot(slot.id, (currentSlot) => ({
                      ...currentSlot,
                      eventDayId: selectedDay.eventDayId,
                      weekIndex: selectedDay.weekIndex,
                      dayIndexInWeek: selectedDay.dayIndexInWeek,
                      overallDayIndex: selectedDay.overallDayIndex,
                      localDate: selectedDay.date,
                    }));
                  }}
                  className={selectInputClassName}
                >
                  {draft.eventDays.map((day) => (
                    <option key={day.id} value={day.eventDayId}>
                      {formatEventDayLabel(day)}
                    </option>
                  ))}
                </select>
              </div>
            </Field>

            <Field label="舞台名">
              <input
                value={slot.stageName}
                onChange={(event) =>
                  mutateTimetableSlot(slot.id, (currentSlot) => ({ ...currentSlot, stageName: event.target.value }))
                }
                className={textInputClassName}
                placeholder="Main Stage"
              />
            </Field>

            <div className="lg:col-span-3 grid gap-3">
              {Array.from({ length: performerCount }).map((_, performerIndex) => {
                const boundDjId = getTimetableSlotBoundDjId(slot, performerIndex);
                return (
                  <div key={`${slot.id}-member-${performerIndex}`} className="admin-event-slot-binding-panel">
                    <div className="admin-event-slot-binding-panel-head">
                      <div>
                        <span>{normalizeActType(slot.actType) === 'solo' ? 'DJ / 艺人名称' : `成员 ${performerIndex + 1}`}</span>
                        <b>{boundDjId ? `已绑定 ${boundDjId}` : '尚未绑定库内 DJ'}</b>
                      </div>
                    </div>
                    <div className="admin-event-slot-binding-row">
                      <input
                        value={performerNames[performerIndex] || ''}
                        onChange={(event) =>
                          mutateTimetableSlot(slot.id, (currentSlot) => {
                            const names = getTimetableSlotPerformerNames(currentSlot);
                            names[performerIndex] = event.target.value;
                            return {
                              ...currentSlot,
                              memberNamesText: names.filter(Boolean).join(' / '),
                            };
                          })
                        }
                        className={textInputClassName}
                        placeholder={normalizeActType(slot.actType) === 'solo' ? '输入艺人名称' : `成员 ${performerIndex + 1}`}
                      />
                    </div>
                    <EntityBindingField
                      kind="dj"
                      mode="single"
                      seedQuery={performerNames[performerIndex] || ''}
                      items={
                        boundDjId
                          ? [
                              {
                                id: boundDjId,
                                name: performerNames[performerIndex] || boundDjId,
                                subtitle: boundDjId,
                                imageUrl: null,
                              },
                            ]
                          : []
                      }
                      title="Bound DJ"
                      emptyLabel="Search and bind one DJ from the library."
                      onAdd={(value) =>
                        updateTimetableSlotPerformerBinding(slot.id, performerIndex, {
                          djId: value.id,
                        })
                      }
                      onRemove={() => updateTimetableSlotPerformerBinding(slot.id, performerIndex, { djId: null })}
                    />
                  </div>
                );
              })}
            </div>

            <Field label="开始时间">
              <input
                type="time"
                value={slot.startTime}
                onChange={(event) =>
                  mutateTimetableSlot(slot.id, (currentSlot) => ({ ...currentSlot, startTime: event.target.value }))
                }
                className={textInputClassName}
              />
            </Field>

            <Field label="结束时间">
              <input
                type="time"
                value={slot.endTime}
                onChange={(event) =>
                  mutateTimetableSlot(slot.id, (currentSlot) => ({ ...currentSlot, endTime: event.target.value }))
                }
                className={textInputClassName}
              />
            </Field>

            <Field label="主 DJ ID（只读）">
              <input value={slot.djId} readOnly className={textInputClassName} placeholder="会根据成员绑定自动生成" />
            </Field>

            <Field label="开始跨天">
              <div className="admin-studio-select-shell">
                <select
                  value={String(Math.max(0, Math.floor(Number(slot.startDayOffset) || 0)))}
                  onChange={(event) =>
                    mutateTimetableSlot(slot.id, (currentSlot) => ({
                      ...currentSlot,
                      startDayOffset: Number(event.target.value) || 0,
                    }))
                  }
                  className={selectInputClassName}
                >
                  <option value="0">同日</option>
                  <option value="1">次日</option>
                </select>
              </div>
            </Field>

            <Field label="结束跨天">
              <div className="admin-studio-select-shell">
                <select
                  value={String(Math.max(0, Math.floor(Number(slot.endDayOffset) || 0)))}
                  onChange={(event) =>
                    mutateTimetableSlot(slot.id, (currentSlot) => ({
                      ...currentSlot,
                      endDayOffset: Number(event.target.value) || 0,
                    }))
                  }
                  className={selectInputClassName}
                >
                  <option value="0">同日</option>
                  <option value="1">次日</option>
                </select>
              </div>
            </Field>

            <div className="admin-event-slot-editor-actions lg:col-span-3">
              <div className="admin-event-slot-editor-actions-meta">
                <span className={`admin-event-slot-editor-status-badge ${isConfirmed ? 'is-bound' : 'is-pending'}`}>
                  {isConfirmed ? '已确认' : '待确认'}
                </span>
                <small>
                  {options?.showOutOfRangeBadge
                    ? '这条时间表当前不在活动日期范围内。请改到有效活动日，或直接删除后再提交。'
                    : '确认后会折叠成摘要卡片，便于连续编辑多条 timetable。'}
                </small>
              </div>
              <div className="flex flex-wrap justify-end gap-2">
                <button
                  type="button"
                  onClick={() => confirmTimetableSlot(slot)}
                  disabled={!canConfirmTimetableSlot(slot)}
                  className="admin-studio-button-primary px-4 py-3 text-sm disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {isConfirmed ? '重新确认' : '确认此条'}
                </button>
                <button
                  type="button"
                  onClick={() => removeTimetableSlot(slot.id)}
                  className="admin-studio-button-danger px-4 py-3 text-sm"
                >
                  删除条目
                </button>
              </div>
            </div>
          </div>
        ) : null}
      </div>
    );
  };

  const currentStepItem = EVENT_STUDIO_STEP_ITEMS[currentStep];
  const timetableWeeks = useMemo(() => {
    if (draft.weeks.length) return draft.weeks;
    const firstDay = draft.eventDays[0];
    return [{
      id: 'single-week',
      weekIndex: firstDay?.weekIndex || 1,
      label: 'Week 1',
      startDate: firstDay?.date || draft.startDate,
      endDate: draft.endDate || firstDay?.date || draft.startDate,
      sortOrder: 1,
    }];
  }, [draft.endDate, draft.eventDays, draft.startDate, draft.weeks]);
  const selectedTimetableDay =
    draft.eventDays.find((day) => day.eventDayId === selectedTimetableDayId) ||
    draft.eventDays.find((day) => day.weekIndex === selectedTimetableWeekIndex) ||
    draft.eventDays[0] ||
    null;
  const timetableDaysInSelectedWeek = useMemo(
    () => draft.eventDays.filter((day) => day.weekIndex === selectedTimetableWeekIndex),
    [draft.eventDays, selectedTimetableWeekIndex]
  );
  const visibleTimetableDays = timetableDaysInSelectedWeek.length ? timetableDaysInSelectedWeek : draft.eventDays;
  const validEventDayIdSet = useMemo(
    () => new Set(draft.eventDays.map((day) => String(day.eventDayId || '').trim()).filter(Boolean)),
    [draft.eventDays]
  );
  const validEventDayDateSet = useMemo(
    () => new Set(draft.eventDays.map((day) => String(day.date || '').trim()).filter(Boolean)),
    [draft.eventDays]
  );
  const outOfRangeTimetableSlots = useMemo(
    () =>
      draft.timetableSlots
        .filter((slot) => {
          if (!timetableSlotHasAnyValue(slot)) return false;
          const eventDayId = String(slot.eventDayId || '').trim();
          const localDate = String(slot.localDate || '').trim();
          if (eventDayId && validEventDayIdSet.has(eventDayId)) return false;
          if (localDate && validEventDayDateSet.has(localDate)) return false;
          return Boolean(eventDayId || localDate);
        })
        .sort((a, b) => a.sortOrder - b.sortOrder),
    [draft.timetableSlots, validEventDayDateSet, validEventDayIdSet]
  );
  const outOfRangeTimetableSlotIdSet = useMemo(
    () => new Set(outOfRangeTimetableSlots.map((slot) => slot.id)),
    [outOfRangeTimetableSlots]
  );
  const visibleTimetableSlots = useMemo(() => {
    const timetableSortValue = (slot: EventStudioTimetableSlotDraft) => {
      const startMinutes = minutesFromTime(slot.startTime);
      if (startMinutes === null) return Number.MAX_SAFE_INTEGER;
      const startOffset = Math.max(0, Math.floor(Number(slot.startDayOffset) || 0));
      if (startOffset > 0) return startMinutes + startOffset * 24 * 60;
      const rolloverMinutes = Math.max(0, Math.min(23, Number(draft.dayRolloverHour) || 6)) * 60;
      return startMinutes < rolloverMinutes ? startMinutes + 24 * 60 : startMinutes;
    };
    if (!selectedTimetableDay) return draft.timetableSlots;
    return draft.timetableSlots
      .filter((slot) => !outOfRangeTimetableSlotIdSet.has(slot.id))
      .filter((slot) =>
        slot.eventDayId === selectedTimetableDay.eventDayId ||
        slot.localDate === selectedTimetableDay.date ||
        slot.overallDayIndex === selectedTimetableDay.overallDayIndex
      )
      .sort((a, b) => timetableSortValue(a) - timetableSortValue(b) || a.sortOrder - b.sortOrder);
  }, [draft.dayRolloverHour, draft.timetableSlots, outOfRangeTimetableSlotIdSet, selectedTimetableDay]);
  const visibleStageOrder = useMemo(() => {
    const seen = new Set<string>();
    const result: string[] = [];
    const pushStage = (stage?: string | null) => {
      const normalized = normalizeStageName(stage);
      const key = stageKey(normalized);
      if (seen.has(key)) return;
      seen.add(key);
      result.push(normalized);
    };
    draft.stageOrder.forEach(pushStage);
    visibleTimetableSlots.forEach((slot) => pushStage(slot.stageName));
    if (!result.length) result.push('Main Stage');
    return result;
  }, [draft.stageOrder, visibleTimetableSlots]);
  const visibleTimetableSlotsByStage = useMemo(
    () =>
      !timetableStepActive
        ? []
        : visibleStageOrder.map((stage) => ({
            stage,
            slots: visibleTimetableSlots.filter((slot) => stageKey(slot.stageName) === stageKey(stage)),
          })),
    [timetableStepActive, visibleStageOrder, visibleTimetableSlots]
  );
  const filteredVisibleTimetableSlotsByStage = useMemo(() => {
    if (selectedTimetableStageFilter === 'all') return visibleTimetableSlotsByStage;
    return visibleTimetableSlotsByStage.filter(({ stage }) => stageKey(stage) === selectedTimetableStageFilter);
  }, [selectedTimetableStageFilter, visibleTimetableSlotsByStage]);
  const timetableEditorGroups = useMemo(() => {
    const visibleIds = new Set(visibleTimetableSlots.map((slot) => slot.id));
    return filteredVisibleTimetableSlotsByStage
      .map(({ stage, slots }) => ({
        stage,
        slots: slots.filter((slot) => visibleIds.has(slot.id)),
      }))
      .filter((group) => group.slots.length > 0);
  }, [filteredVisibleTimetableSlotsByStage, visibleTimetableSlots]);
  const shouldUseLegacyStageColumns = filteredVisibleTimetableSlotsByStage.length > 1;
  const shouldUseLegacyScrollableColumns = filteredVisibleTimetableSlotsByStage.length >= 4;
  const activeTimetableStageLabel =
    selectedTimetableStageFilter === 'all'
      ? '全部舞台'
      : visibleStageOrder.find((stage) => stageKey(stage) === selectedTimetableStageFilter) || '当前舞台';
  const focusedTimetableSlot = useMemo(
    () => draft.timetableSlots.find((slot) => slot.id === focusedTimetableSlotId) || null,
    [draft.timetableSlots, focusedTimetableSlotId]
  );
  const timetableDraftJsonPreview = useMemo(
    () =>
      JSON.stringify(
        draft.timetableSlots.map((slot) => ({
          id: slot.id,
          canonicalSlotId: slot.canonicalSlotId || null,
          lineupArtistId: slot.lineupArtistId || null,
          actType: normalizeActType(slot.actType),
          eventDayId: slot.eventDayId,
          weekIndex: slot.weekIndex,
          dayIndexInWeek: slot.dayIndexInWeek,
          overallDayIndex: slot.overallDayIndex,
          localDate: slot.localDate,
          djId: slot.djId,
          memberDjIds: slot.memberDjIds,
          memberNamesText: slot.memberNamesText,
          displayNameOverride: slot.displayNameOverride || '',
          stageName: slot.stageName,
          sortOrder: slot.sortOrder,
          startTime: slot.startTime,
          endTime: slot.endTime,
          startDayOffset: Number(slot.startDayOffset) || 0,
          endDayOffset: Number(slot.endDayOffset) || 0,
        })),
        null,
        2
      ),
    [draft.timetableSlots]
  );
  const focusedTimetableSlotJsonPreview = useMemo(
    () =>
      JSON.stringify(
        focusedTimetableSlot
          ? {
              id: focusedTimetableSlot.id,
              canonicalSlotId: focusedTimetableSlot.canonicalSlotId || null,
              lineupArtistId: focusedTimetableSlot.lineupArtistId || null,
              actType: normalizeActType(focusedTimetableSlot.actType),
              eventDayId: focusedTimetableSlot.eventDayId,
              weekIndex: focusedTimetableSlot.weekIndex,
              dayIndexInWeek: focusedTimetableSlot.dayIndexInWeek,
              overallDayIndex: focusedTimetableSlot.overallDayIndex,
              localDate: focusedTimetableSlot.localDate,
              djId: focusedTimetableSlot.djId,
              memberDjIds: focusedTimetableSlot.memberDjIds,
              memberNamesText: focusedTimetableSlot.memberNamesText,
              displayNameOverride: focusedTimetableSlot.displayNameOverride || '',
              stageName: focusedTimetableSlot.stageName,
              sortOrder: focusedTimetableSlot.sortOrder,
              startTime: focusedTimetableSlot.startTime,
              endTime: focusedTimetableSlot.endTime,
              startDayOffset: Number(focusedTimetableSlot.startDayOffset) || 0,
              endDayOffset: Number(focusedTimetableSlot.endDayOffset) || 0,
            }
          : { message: '当前还没有聚焦的时间表条目。点击下方任意一条时间表卡片后，这里会实时显示该条数据。' },
        null,
        2
      ),
    [focusedTimetableSlot]
  );
  const timetablePayloadJsonPreview = useMemo(() => {
    const payload = mode === 'create' ? mapEventStudioDraftToCreateInput(draft) : mapEventStudioDraftToUpdateInput(draft);
    return JSON.stringify(
      {
        stageOrder: payload.stageOrder ?? [],
        lineupSlots: payload.lineupSlots ?? [],
      },
      null,
      2
    );
  }, [draft, mode]);
  const formatTimetableSlotClock = (slot: EventStudioTimetableSlotDraft, field: 'startTime' | 'endTime') => {
    const value = slot[field];
    const extracted = extractTimeValue(value);
    if (extracted) return extracted;
    const formatted = formatClockTimeInTimeZone(value, eventDisplayTimeZone);
    return formatted || '--:--';
  };
  const formatTimetableSlotRange = (slot: EventStudioTimetableSlotDraft) => {
    const start = formatTimetableSlotClock(slot, 'startTime');
    const end = formatTimetableSlotClock(slot, 'endTime');
    const startOffset = Math.max(0, Math.floor(Number(slot.startDayOffset) || 0));
    const endOffset = Math.max(0, Math.floor(Number(slot.endDayOffset) || 0));
    const startLabel = startOffset > 0 ? `+${startOffset} ${start}` : start;
    const endLabel = endOffset > 0 ? `+${endOffset} ${end}` : end;
    if (start === '--:--' && end === '--:--') return 'No time';
    return `${startLabel} - ${endLabel}`;
  };
  const lineupPreviewArtists = useMemo(() => {
    if (!lineupStepActive) return [];
    const source = draft.lineupArtists.length ? draft.lineupArtists : buildLineupArtistsFromTimetableSlots(draft.timetableSlots);
    return [...source].sort((left, right) => left.sortOrder - right.sortOrder);
  }, [draft.lineupArtists, draft.timetableSlots, lineupStepActive]);
  const lineupStageCount = useMemo(
    () => (lineupStepActive ? draft.lineupArtists.filter((artist) => artist.memberNamesText.trim() || artist.djId.trim()).length : 0),
    [draft.lineupArtists, lineupStepActive]
  );
  const lineupIdentityKeys = useMemo(
    () => new Set(draft.lineupArtists.map(eventStudioLineupArtistIdentityKey).filter((key): key is string => Boolean(key))),
    [draft.lineupArtists]
  );
  const timetableIdentityKeys = useMemo(
    () => new Set(draft.timetableSlots.map(eventStudioTimetableSlotIdentityKey).filter((key): key is string => Boolean(key))),
    [draft.timetableSlots]
  );
  const missingLineupArtistsFromTimetable = useMemo(() => {
    if (!lineupStepActive) return [];
    const seen = new Set<string>();
    return buildLineupArtistsFromTimetableSlots(draft.timetableSlots).filter((artist) => {
      const key = eventStudioLineupArtistIdentityKey(artist);
      if (!key || lineupIdentityKeys.has(key) || seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }, [draft.timetableSlots, lineupIdentityKeys, lineupStepActive]);
  const lineupArtistsOnlyInLineup = useMemo(
    () => (lineupStepActive
      ? draft.lineupArtists.filter((artist) => {
          const key = eventStudioLineupArtistIdentityKey(artist);
          return Boolean(key && !timetableIdentityKeys.has(key));
        })
      : []),
    [draft.lineupArtists, lineupStepActive, timetableIdentityKeys]
  );

  const applyTimetableIncrementalFillToLineup = () => {
    updateLineupDraft((current) => ({
      ...current,
      lineupSyncMode: 'incremental_fill',
      lineupArtists: fillLineupArtistsFromTimetableSlots(current.lineupArtists, current.timetableSlots),
    }));
  };

  const _legacyRenderMediaZone = (usage: EventStudioImageUsage) => {
    const config = IMAGE_ZONE_CONFIG.find((item) => item.usage === usage);
    if (!config) return null;
    const items = draft.imageZones[usage];
    const isPrimary = config.emphasis === 'primary';
    const zoneUploadingCount = items.filter((item) => item.uploadState === 'uploading').length;

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
                        #{image.sortOrder} · {image.origin === 'persisted-event' ? '活动已存在资源' : image.origin === 'event-upload' ? '当前编辑上传' : '当前草稿上传'}
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

  const renderMediaZone = (usage: EventStudioImageUsage) => {
    const config = IMAGE_ZONE_CONFIG.find((item) => item.usage === usage);
    if (!config) return null;
    const items = draft.imageZones[usage];
    const isPrimary = config.emphasis === 'primary';
    return (
      <AdminImageUploadPanel
        key={usage}
        title={config.title}
        description={config.description}
        hint={config.hint}
        items={items.map((image, index) => ({
          id: image.id,
          previewUrl: imagePreviewUrl(image),
          remoteUrl: String(image.remoteUrl || '').trim() || null,
          fileName: image.fileName || `${config.title} ${index + 1}`,
          statusText: `#${image.sortOrder} · ${imageStatusLabel(image)}`,
          state:
            image.uploadState === 'uploading'
              ? 'uploading'
              : image.uploadState === 'failed'
                ? 'failed'
                : 'idle',
          removeLabel: deletingImageId === image.id ? '移除中...' : '移除',
          onRemove: () => void handleImageRemove(usage, image),
          onMoveLeft: () => handleImageMove(usage, image.id, -1),
          onMoveRight: () => handleImageMove(usage, image.id, 1),
          moveLeftDisabled: index === 0,
          moveRightDisabled: index === items.length - 1,
        }))}
        multiple
        tone={isPrimary ? 'primary' : 'secondary'}
        previewMode="landscape"
        populatedActionLabel="继续添加"
        emptyActionLabel="选择图片"
        onUpload={(files) => void handleImageUploadFiles(files, usage)}
      />
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
        uploading={uploadingImageCount > 0 || deletingImageId !== null}
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

      {failedImageCount > 0 ? (
        <section className="admin-studio-pastel-sand p-4 text-sm text-[#604a1b]">
          有 {failedImageCount} 张图片上传失败。你可以继续提交，系统会在提交前按 iOS 语义再重试一次。
        </section>
      ) : null}

      <div className="admin-event-workbench-shell">
        <WorkflowRail currentStep={currentStep} onSelect={goToStep} draft={draft} mediaCount={mediaCount} canSubmit={canSubmit} />
        <main className="min-w-0 space-y-5">

      {currentStep === 0 ? (
        <Section title="媒体" description="先把主视觉、封面、阵容图和排期图集中整理好。提交校验会要求 Poster / Lineup / Cover 至少有一张。">
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {IMAGE_ZONE_CONFIG.map((item) => renderMediaZone(item.usage))}
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
            <div className="mb-5">
              <EventStudioAIImportDock draft={draft} setDraft={setDraft} entryMode="single" entryKind="poster" onOpenStep={() => setCurrentStep(1)} />
            </div>
            <div className="mb-5 grid gap-4 lg:grid-cols-3">
              <div className="admin-reference-card p-4">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <div className="text-sm font-semibold text-[#071110]">当前状态</div>
                    <div className="mt-2 text-sm leading-6 text-black/52">
                      时间状态由活动开始时间、结束时间和时区自动推导，这里只展示，不作为可编辑真值。
                    </div>
                  </div>
                  <span className={`rounded-full px-3 py-1 text-xs font-semibold ${derivedStatusMeta.toneClassName}`}>
                    {derivedStatusMeta.label}
                  </span>
                </div>
                <div className="mt-3 text-xs leading-6 text-black/42">{derivedStatusMeta.description}</div>
              </div>
              <div className="admin-reference-card p-4">
                <div className="text-sm font-semibold text-[#071110]">取消状态</div>
                <div className="mt-2 text-sm leading-6 text-black/52">
                  这里只控制活动是否取消，不再手动编辑“即将开始 / 进行中 / 已结束”。
                </div>
                <div className="mt-4 flex flex-wrap gap-2">
                  <button
                    type="button"
                    onClick={() => updateDraft('isCancelled', false)}
                    className={isCancelledDraft ? 'admin-studio-button-secondary px-4 py-3 text-sm' : 'admin-studio-button-primary px-4 py-3 text-sm'}
                  >
                    正常活动
                  </button>
                  <button
                    type="button"
                    onClick={() => updateDraft('isCancelled', true)}
                    className={isCancelledDraft ? 'admin-studio-button-danger px-4 py-3 text-sm' : 'admin-studio-button-secondary px-4 py-3 text-sm'}
                  >
                    标记为已取消
                  </button>
                </div>
                <div className={`mt-3 text-xs ${isCancelledDraft ? 'text-[#b13a3a]' : 'text-black/42'}`}>
                  {isCancelledDraft ? '保存后活动将按“已取消”展示。' : '保存后活动保持正常状态，时间态会自动推导。'}
                </div>
              </div>
              <div className="admin-reference-card p-4">
                <div className="text-sm font-semibold text-[#071110]">可见性</div>
                <div className="mt-2 text-sm leading-6 text-black/52">
                  控制活动是否在前台展示。隐藏不会改变时间状态，只影响内容可见性。
                </div>
                <div className="mt-4 flex flex-wrap gap-2">
                  <button
                    type="button"
                    onClick={() => updateDraft('visibility', 'visible')}
                    className={visibilityDraft === 'visible' ? 'admin-studio-button-primary px-4 py-3 text-sm' : 'admin-studio-button-secondary px-4 py-3 text-sm'}
                  >
                    前台可见
                  </button>
                  <button
                    type="button"
                    onClick={() => updateDraft('visibility', 'hidden')}
                    className={visibilityDraft === 'hidden' ? 'admin-studio-button-primary px-4 py-3 text-sm' : 'admin-studio-button-secondary px-4 py-3 text-sm'}
                  >
                    隐藏活动
                  </button>
                </div>
                <div className={`mt-3 text-xs ${visibilityDraft === 'hidden' ? 'text-[#8a5a16]' : 'text-black/42'}`}>
                  {visibilityDraft === 'hidden'
                    ? '保存后活动会从前台列表中隐藏，但后台仍保留完整编辑信息。'
                    : '保存后活动按正常可见内容参与前台展示与检索。'}
                </div>
              </div>
            </div>
            <div className="grid gap-4 lg:grid-cols-2">
              <div className="lg:col-span-2">
                <LocalizedTextField
                  label="活动名称"
                  value={draft.name}
                  kind="input"
                  error={errors.name}
                  placeholder="例如：Tomorrowland"
                  hint="主输入默认编辑中文。"
                  maxLength={INPUT_LIMITS.event.name}
                  onPrimaryChange={(value) => updateLocalizedField('name', 'zh', value)}
                  onOpenOverlay={() =>
                    setActiveLocalizedField({
                      key: 'name',
                      label: '活动名称',
                      kind: 'input',
                    })
                  }
                />
              </div>
              <Field label="活动类型">
                <div className="admin-studio-select-shell">
                  <select
                    value={draft.eventType}
                    onChange={(event) => updateDraft('eventType', event.target.value)}
                    className={selectInputClassName}
                  >
                    {EVENT_TYPES.map((item) => (
                      <option key={item} value={item}>
                        {item}
                      </option>
                    ))}
                  </select>
                </div>
              </Field>
              <Field label="活动简称">
                <AdminCountedControl count={countText(draft.abbreviation)} maxLength={INPUT_LIMITS.event.abbreviation}>
                  <input
                    value={draft.abbreviation}
                    onChange={(event) => updateDraft('abbreviation', event.target.value)}
                    className={textInputClassName}
                    placeholder="例如：ASOT"
                    maxLength={INPUT_LIMITS.event.abbreviation}
                  />
                </AdminCountedControl>
              </Field>
              <Field label="场馆名（可选）">
                <AdminCountedControl count={countText(draft.venueName)} maxLength={INPUT_LIMITS.event.venueName}>
                  <input
                    value={draft.venueName}
                    onChange={(event) => updateDraft('venueName', event.target.value)}
                    className={textInputClassName}
                    placeholder="例如：National Stadium"
                    maxLength={INPUT_LIMITS.event.venueName}
                  />
                </AdminCountedControl>
              </Field>
              <Field label="场馆地址（可选）">
                <AdminCountedControl count={countText(draft.venueAddress)} maxLength={INPUT_LIMITS.event.venueAddress}>
                  <input
                    value={draft.venueAddress}
                    onChange={(event) => updateDraft('venueAddress', event.target.value)}
                    className={textInputClassName}
                    placeholder="例如：88 Xuhui Riverside"
                    maxLength={INPUT_LIMITS.event.venueAddress}
                  />
                </AdminCountedControl>
              </Field>
              <Field label="来源链接">
                <AdminCountedControl count={countText(draft.sourceEventUrl)} maxLength={INPUT_LIMITS.common.url}>
                  <input
                    value={draft.sourceEventUrl}
                    onChange={(event) => updateDraft('sourceEventUrl', event.target.value)}
                    className={textInputClassName}
                    placeholder="https://..."
                    maxLength={INPUT_LIMITS.common.url}
                  />
                </AdminCountedControl>
              </Field>

              <Field label="来源平台（可选）">
                <AdminCountedControl count={countText(draft.sourceProvider)} maxLength={INPUT_LIMITS.event.sourceProvider}>
                  <input
                    value={draft.sourceProvider}
                    onChange={(event) => updateDraft('sourceProvider', event.target.value)}
                    className={textInputClassName}
                    placeholder="例如：official_website / instagram / manual"
                    maxLength={INPUT_LIMITS.event.sourceProvider}
                  />
                </AdminCountedControl>
              </Field>

              <div className="lg:col-span-2">
                <Field label="参考链接（每行一个，可选）">
                  <AdminCountedControl count={countText(draft.referenceLinksText, true)} maxLength={INPUT_LIMITS.event.referenceLinksText} multiline>
                    <textarea
                      value={draft.referenceLinksText}
                      onChange={(event) => updateDraft('referenceLinksText', event.target.value)}
                      className={textAreaClassName}
                      placeholder="https://example.com/page-1&#10;https://example.com/page-2"
                      maxLength={INPUT_LIMITS.event.referenceLinksText}
                    />
                  </AdminCountedControl>
                </Field>
              </div>

              <div className="lg:col-span-2">
                <Field label="社交链接 JSON（可选）">
                  <AdminCountedControl count={countText(draft.socialLinksText, true)} maxLength={INPUT_LIMITS.event.socialLinksText} multiline>
                    <textarea
                      value={draft.socialLinksText}
                      onChange={(event) => updateDraft('socialLinksText', event.target.value)}
                      className={textAreaClassName}
                      placeholder='[{"type":"instagram","url":"https://instagram.com/example"}]'
                      maxLength={INPUT_LIMITS.event.socialLinksText}
                    />
                  </AdminCountedControl>
                  {errors.socialLinks ? <div className="mt-2 text-xs text-[#6a3530]">{errors.socialLinks}</div> : null}
                </Field>
              </div>

              <div className="lg:col-span-2">
                <Field label="主办方绑定">
                  <div className="space-y-3">
                    <div className="flex flex-col gap-3 lg:flex-row">
                      <AdminCountedControl count={countText(draft.organizerName)} maxLength={INPUT_LIMITS.event.organizerName}>
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
                          placeholder="输入主办方名称，或作为手动主办方文本保留"
                          maxLength={INPUT_LIMITS.event.organizerName}
                        />
                      </AdminCountedControl>
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

                    <EntityBindingField
                      kind="festival"
                      mode="single"
                      seedQuery={draft.organizerName}
                      items={organizerBindingItems}
                      title="Bound organizer"
                      emptyLabel="Search and bind one organizer from the library."
                      onAdd={(value) => {
                        updateDraft('organizerFestivalId', value.id);
                        updateDraft('organizerName', value.name);
                      }}
                      onRemove={() => {
                        updateDraft('organizerFestivalId', '');
                      }}
                    />

                    {draft.organizerFestivalId ? (
                      <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] px-4 py-3 text-sm text-[#2f4027]">
                        已绑定主办方 ID：{draft.organizerFestivalId}
                      </div>
                    ) : null}

                  </div>
                </Field>
              </div>

              <div className="lg:col-span-2">
                <Field label="活动描述">
                  <AdminCountedControl count={countText(draft.description, true)} maxLength={INPUT_LIMITS.event.description} multiline>
                    <textarea
                      value={draft.description}
                      onChange={(event) => updateDraft('description', event.target.value)}
                      className={textAreaClassName}
                      placeholder="填写活动简介、风格或亮点说明"
                      maxLength={INPUT_LIMITS.event.description}
                    />
                  </AdminCountedControl>
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
                      <div className="mt-2 text-xs text-black/38">
                        地图选点将通过当前页内的 legacy 浮窗完成，确认后自动回填当前表单。
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
                      <AdminCountedControl count={countText(draft.pickedPlaceName)} maxLength={INPUT_LIMITS.event.venueName}>
                        <input
                          value={draft.pickedPlaceName}
                          onChange={(event) => updateDraft('pickedPlaceName', event.target.value)}
                          className={textInputClassName}
                          placeholder="例如：National Stadium"
                          maxLength={INPUT_LIMITS.event.venueName}
                        />
                      </AdminCountedControl>
                    </Field>
                    <Field label="地图地址（可选）">
                      <AdminCountedControl count={countText(draft.pickedMapAddress)} maxLength={INPUT_LIMITS.event.detailAddress}>
                        <input
                          value={draft.pickedMapAddress}
                          onChange={(event) => updateDraft('pickedMapAddress', event.target.value)}
                          className={textInputClassName}
                          placeholder="用于 locationPoint 回填"
                          maxLength={INPUT_LIMITS.event.detailAddress}
                        />
                      </AdminCountedControl>
                    </Field>
                  </div>
                </div>

                <div className="grid gap-4 lg:grid-cols-2">
                  <LocalizedTextField
                    label="城市"
                    value={draft.city}
                    kind="input"
                    error={errors.city}
                    placeholder="Shanghai"
                    hint="主输入默认编辑中文。"
                    maxLength={INPUT_LIMITS.event.city}
                    onPrimaryChange={(value) => updateLocalizedField('city', 'zh', value)}
                    onOpenOverlay={() =>
                      setActiveLocalizedField({
                        key: 'city',
                        label: '城市',
                        kind: 'input',
                        clearable: true,
                      })
                    }
                  />
                  <LocalizedTextField
                    label="国家"
                    value={draft.country}
                    kind="input"
                    error={errors.country}
                    placeholder="中国"
                    hint="主输入默认编辑中文。"
                    maxLength={INPUT_LIMITS.event.country}
                    onPrimaryChange={(value) => updateLocalizedField('country', 'zh', value)}
                    onOpenOverlay={() =>
                      setActiveLocalizedField({
                        key: 'country',
                        label: '国家',
                        kind: 'input',
                        clearable: true,
                      })
                    }
                  />
                  <div className="lg:col-span-2">
                    <LocalizedTextField
                      label="详细地址"
                      value={draft.detailAddress}
                      kind="textarea"
                      error={errors.detailAddress}
                      placeholder="活动详细地址"
                      hint="主输入默认编辑中文。"
                      maxLength={INPUT_LIMITS.event.detailAddress}
                      onPrimaryChange={(value) => updateLocalizedField('detailAddress', 'zh', value)}
                      onOpenOverlay={() =>
                        setActiveLocalizedField({
                          key: 'detailAddress',
                          label: '详细地址',
                          kind: 'textarea',
                        })
                      }
                    />
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
                          updateDraftState(
                            (current) => {
                              const rebased = rebaseEventStudioDatesPreservingWallDate(current);
                              return {
                                ...rebased,
                                timeZoneSelection: item,
                                timeZoneQuery: item.cityAscii || item.city,
                              };
                            },
                            {
                              clearErrorKeys: ['timeZone'],
                            }
                          );
                          setTimezoneItems([]);
                          setTimezoneError('');
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
              <div className="admin-studio-select-shell">
                <select
                  value={draft.scheduleMode}
                  onChange={(event) => setScheduleMode(event.target.value as EventStudioDraft['scheduleMode'])}
                  className={selectInputClassName}
                >
                  {SCHEDULE_MODE_ITEMS.map((item) => (
                    <option key={item.value} value={item.value}>
                      {item.label}
                    </option>
                  ))}
                </select>
              </div>
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
              <AdminCountedControl count={countText(draft.officialWebsite)} maxLength={INPUT_LIMITS.common.url}>
                <input
                  value={draft.officialWebsite}
                  onChange={(event) => updateDraft('officialWebsite', event.target.value)}
                  className={textInputClassName}
                  placeholder="https://..."
                  maxLength={INPUT_LIMITS.common.url}
                />
              </AdminCountedControl>
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
          <div className={`grid gap-5 ${showTimetableDebugDrawer ? 'xl:grid-cols-[minmax(0,1fr)_420px]' : ''}`}>
            <div className="min-w-0">
              <div className="mb-5">
                <EventStudioAIImportDock draft={draft} setDraft={setDraft} entryMode="single" entryKind="timetable" onOpenStep={() => setCurrentStep(3)} />
              </div>
              <div className="admin-event-timetable-board">
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div>
                <div className="admin-studio-label">Timetable Board</div>
                <h3 className="mt-2 text-2xl font-black tracking-[-0.045em] text-[#071110]">舞台排期</h3>
                <p className="mt-2 max-w-2xl text-sm leading-6 text-black/48">
                  先在这里看整体结构，再用下方条目做精确编辑。这里改为按照 legacy timetable 的舞台分栏方式展示，不再强制贴合时间轴。
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => setTimetableSelectionMode((current) => !current)}
                  className="admin-studio-button-secondary px-4 py-3 text-sm"
                >
                  {timetableSelectionMode ? '完成多选' : '批量操作'}
                </button>
                <button
                  type="button"
                  onClick={() => void cleanupVisibleTimetableSlots()}
                  className="admin-studio-button-secondary px-4 py-3 text-sm"
                >
                  一键清理当前页
                </button>
                {timetableSelectionMode ? (
                  <>
                    <button
                      type="button"
                      onClick={() => {
                        const day = draft.eventDays.find((item) => item.eventDayId === selectedTimetableDay?.eventDayId) || draft.eventDays[0];
                        if (day) moveSelectedTimetableSlotsToDay(day);
                      }}
                      disabled={!selectedTimetableSlotIds.length}
                      className="admin-studio-button-secondary px-4 py-3 text-sm disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      移动到当前日
                    </button>
                    <button
                      type="button"
                      onClick={() => moveSelectedTimetableSlotsToStage(visibleStageOrder[0] || draft.stageOrder[0] || 'Main Stage')}
                      disabled={!selectedTimetableSlotIds.length}
                      className="admin-studio-button-secondary px-4 py-3 text-sm disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      移动到当前舞台
                    </button>
                  </>
                ) : null}
                <button
                  type="button"
                  onClick={() => addTimetableSlot()}
                  disabled={!draft.eventDays.length}
                  className="admin-studio-button-primary px-4 py-3 text-sm disabled:cursor-not-allowed disabled:opacity-60"
                >
                  新增时间块
                </button>
                <button
                  type="button"
                  onClick={() => setShowTimetableDebugDrawer((current) => !current)}
                  className="admin-studio-button-secondary px-4 py-3 text-sm"
                >
                  {showTimetableDebugDrawer ? '隐藏调试面板' : '查看 JSON'}
                </button>
                <button
                  type="button"
                  onClick={deleteAllTimetableSlots}
                  disabled={!draft.timetableSlots.length}
                  className="admin-studio-button-danger px-4 py-3 text-sm disabled:cursor-not-allowed disabled:opacity-60"
                >
                  删除所有时间表
                </button>
              </div>
            </div>

            <div className="mt-6 flex gap-3 overflow-x-auto pb-2">
              {timetableWeeks.map((week) => (
                <button
                  key={week.id}
                  type="button"
                  onClick={() => {
                    setSelectedTimetableWeekIndex(week.weekIndex);
                    const firstDayInWeek = draft.eventDays.find((day) => day.weekIndex === week.weekIndex);
                    if (firstDayInWeek) setSelectedTimetableDayId(firstDayInWeek.eventDayId);
                  }}
                  className={`admin-event-timetable-tab ${week.weekIndex === selectedTimetableWeekIndex ? 'is-active' : ''}`}
                >
                  {week.label || `Week ${week.weekIndex}`}
                </button>
              ))}
            </div>

            <div className="mt-3 flex gap-3 overflow-x-auto pb-2">
              {draft.eventDays.length ? (
                visibleTimetableDays.map((day) => (
                  <button
                    key={day.id}
                    type="button"
                    onClick={() => {
                      setSelectedTimetableWeekIndex(day.weekIndex);
                      setSelectedTimetableDayId(day.eventDayId);
                    }}
                    className={`admin-event-day-tab ${day.eventDayId === selectedTimetableDay?.eventDayId ? 'is-active' : ''}`}
                  >
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

            <div className="admin-event-stage-order-panel mt-6">
              <div>
                <div className="admin-studio-label">Stage Order</div>
                <div className="mt-1 text-sm font-semibold text-[#071110]">舞台顺序</div>
              </div>
              <div className="admin-event-stage-order-list">
                {visibleStageOrder.map((stage, index) => (
                  <div
                    key={stage}
                    className="admin-event-stage-order-chip"
                    draggable
                    onDragStart={() => setDraggedTimetableStage(stage)}
                    onDragEnd={() => setDraggedTimetableStage(null)}
                    onDragOver={(event) => event.preventDefault()}
                    onDrop={() => {
                      if (!draggedTimetableStage) return;
                      moveStageOrderBefore(draggedTimetableStage, stage);
                      setDraggedTimetableStage(null);
                    }}
                  >
                    {editingTimetableStageKey === stageKey(stage) ? (
                      <input
                        value={editingTimetableStageName}
                        onChange={(event) => setEditingTimetableStageName(event.target.value)}
                        onKeyDown={(event) => {
                          if (event.key === 'Enter') {
                            event.preventDefault();
                            renameTimetableStage(stage);
                          }
                          if (event.key === 'Escape') {
                            event.preventDefault();
                            cancelEditingTimetableStage();
                          }
                        }}
                        className="admin-event-stage-order-input"
                        autoFocus
                        placeholder="舞台名称"
                      />
                    ) : (
                      <span>{stage}</span>
                    )}
                    <b>{visibleTimetableSlots.filter((slot) => stageKey(slot.stageName) === stageKey(stage)).length}</b>
                    <button type="button" onClick={() => moveStageOrder(stage, -1)} disabled={index === 0}>
                      ↑
                    </button>
                    <button type="button" onClick={() => moveStageOrder(stage, 1)} disabled={index === visibleStageOrder.length - 1}>
                      ↓
                    </button>
                    {editingTimetableStageKey === stageKey(stage) ? (
                      <>
                        <button type="button" onClick={() => renameTimetableStage(stage)} aria-label={`确认舞台 ${stage} 的新名称`}>
                          <Check size={14} />
                        </button>
                        <button type="button" onClick={cancelEditingTimetableStage} aria-label={`取消编辑舞台 ${stage}`}>
                          <X size={14} />
                        </button>
                      </>
                    ) : (
                      <>
                        <button type="button" onClick={() => startEditingTimetableStage(stage)} aria-label={`编辑舞台 ${stage}`}>
                          <Pencil size={13} />
                        </button>
                        <button type="button" onClick={() => removeTimetableStage(stage)} aria-label={`删除舞台 ${stage}`}>
                          <Trash2 size={13} />
                        </button>
                      </>
                    )}
                  </div>
                ))}
                <button type="button" onClick={addTimetableStage} className="admin-event-stage-order-add" aria-label="添加舞台">
                  <span>+</span>
                </button>
              </div>
            </div>
            {timetableStageError ? <div className="mt-3 text-xs text-[#6a3530]">{timetableStageError}</div> : null}

            <div className="admin-event-stage-filter-bar mt-4">
              <button
                type="button"
                onClick={() => setSelectedTimetableStageFilter('all')}
                className={selectedTimetableStageFilter === 'all' ? 'is-active' : ''}
              >
                全部舞台
              </button>
              {visibleStageOrder.map((stage) => (
                <button
                  key={stage}
                  type="button"
                  onClick={() => setSelectedTimetableStageFilter(stageKey(stage))}
                  className={selectedTimetableStageFilter === stageKey(stage) ? 'is-active' : ''}
                >
                  {stage}
                </button>
              ))}
              <span>当前：{activeTimetableStageLabel}</span>
            </div>

            <div className="admin-event-stage-scroll mt-6">
              {shouldUseLegacyStageColumns ? (
                <div
                  className={`admin-event-legacy-stages-wrap ${shouldUseLegacyScrollableColumns ? 'is-scrollable' : ''}`}
                  style={
                    shouldUseLegacyScrollableColumns
                      ? undefined
                      : { gridTemplateColumns: `repeat(${Math.max(1, filteredVisibleTimetableSlotsByStage.length)}, minmax(0, 1fr))` }
                  }
                >
                  {filteredVisibleTimetableSlotsByStage.map(({ stage, slots: stageSlots }) => (
                    <div key={stage} className="admin-event-legacy-stage-col">
                      <div className="admin-event-legacy-stage-head">
                        <span>{stage}</span>
                        <b>{stageSlots.length} Sets</b>
                      </div>
                      <div className="admin-event-legacy-slot-list">
                        {stageSlots.length ? (
                          stageSlots.map((slot) => (
                            <button
                              key={slot.id}
                              type="button"
                              onClick={() => handleTimetableSlotCardClick(slot.id)}
                              className={`admin-event-legacy-slot ${timetableSelectionMode && selectedTimetableSlotIds.includes(slot.id) ? 'is-selected' : ''} ${focusedTimetableSlotId === slot.id ? 'is-focused' : ''} ${confirmedTimetableSlotIds.includes(slot.id) ? 'is-confirmed' : ''}`}
                            >
                              <span className="admin-event-legacy-slot-time">{formatTimetableSlotRange(slot)}</span>
                              <strong className="admin-event-legacy-slot-title">
                                <span className="admin-event-legacy-slot-performers">
                                  {getTimetableSlotPerformerRows(slot).map((performer) => (
                                    <span key={performer.key} className="admin-event-legacy-slot-performer">
                                      <span className="admin-event-legacy-slot-performer-name">{performer.label}</span>
                                      {performer.isBound ? (
                                        <span className="admin-event-legacy-slot-bound-badge">已绑定 DJ</span>
                                      ) : null}
                                    </span>
                                  ))}
                                </span>
                              </strong>
                              <span className="admin-event-legacy-slot-meta">
                                <span>{normalizeActType(slot.actType)}</span>
                                <span>{slot.localDate || selectedTimetableDay?.date || '未设置日期'}</span>
                              </span>
                            </button>
                          ))
                        ) : (
                          <div className="admin-event-legacy-empty">
                            <span>当前日期暂无演出</span>
                            <button
                              type="button"
                              onClick={() => addTimetableSlot(stage)}
                              disabled={!draft.eventDays.length}
                            >
                              添加到此舞台
                            </button>
                          </div>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="admin-event-legacy-flat-list">
                  {filteredVisibleTimetableSlotsByStage.flatMap(({ stage, slots: stageSlots }) =>
                    stageSlots.map((slot) => (
                      <button
                        key={slot.id}
                        type="button"
                        onClick={() => handleTimetableSlotCardClick(slot.id)}
                        className={`admin-event-legacy-slot admin-event-legacy-flat-slot ${timetableSelectionMode && selectedTimetableSlotIds.includes(slot.id) ? 'is-selected' : ''} ${focusedTimetableSlotId === slot.id ? 'is-focused' : ''} ${confirmedTimetableSlotIds.includes(slot.id) ? 'is-confirmed' : ''}`}
                      >
                        <span className="admin-event-legacy-slot-time">{formatTimetableSlotRange(slot)}</span>
                        <strong className="admin-event-legacy-slot-title">
                          <span className="admin-event-legacy-slot-performers">
                            {getTimetableSlotPerformerRows(slot).map((performer) => (
                              <span key={performer.key} className="admin-event-legacy-slot-performer">
                                <span className="admin-event-legacy-slot-performer-name">{performer.label}</span>
                                {performer.isBound ? (
                                  <span className="admin-event-legacy-slot-bound-badge">已绑定 DJ</span>
                                ) : null}
                              </span>
                            ))}
                          </span>
                        </strong>
                        <span className="admin-event-legacy-slot-meta">
                          <span>{stage}</span>
                          <span>{normalizeActType(slot.actType)}</span>
                          <span>{slot.localDate || selectedTimetableDay?.date || '未设置日期'}</span>
                        </span>
                      </button>
                    ))
                  )}
                  {!filteredVisibleTimetableSlotsByStage.some(({ slots }) => slots.length) ? (
                    <div className="admin-event-legacy-empty">
                      <span>当前筛选下暂无演出</span>
                      <button
                        type="button"
                        onClick={() => addTimetableSlot(filteredVisibleTimetableSlotsByStage[0]?.stage)}
                        disabled={!draft.eventDays.length}
                      >
                        新增时间段
                      </button>
                    </div>
                  ) : null}
                </div>
              )}
            </div>
            
            <div className="mt-5 flex flex-wrap items-center gap-3 text-xs font-bold uppercase tracking-[0.14em] text-black/40">
              <span>当前视图：{activeTimetableStageLabel}</span>
              <span>显示时区：{eventDisplayTimeZone}</span>
              <span>展示方式：Legacy timetable columns</span>
              {outOfRangeTimetableSlots.length ? <span className="text-[#b54737]">异常时间表：{outOfRangeTimetableSlots.length} 条</span> : null}
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
              {timetableEditorGroups.length ? (
                timetableEditorGroups.map(({ stage, slots }) => (
                  <div key={stage} className="admin-event-slot-editor-group">
                    <div className="admin-event-slot-editor-group-head">
                      <div>
                        <span>{stage}</span>
                        <b>{selectedTimetableDay?.label || selectedTimetableDay?.date || 'Current day'}</b>
                      </div>
                      <button type="button" onClick={() => addTimetableSlot(stage)} disabled={!draft.eventDays.length}>
                        添加到此舞台
                      </button>
                    </div>
                    <div className="space-y-3">
                      {slots.map((slot) => renderTimetableSlotEditorCard(slot))}
                    </div>
                  </div>
                ))
              ) : (
                <div className="admin-reference-soft-card p-4 text-sm text-black/48">
                  当前日期还没有时间表条目。先完成活动日期结构后，就可以开始录入演出时段。
                </div>
              )}

              {outOfRangeTimetableSlots.length ? (
                <div className="admin-event-slot-editor-group is-warning">
                  <div className="admin-event-slot-editor-group-head">
                    <div>
                      <span>异常时间表</span>
                      <b>这些条目仍然存在于草稿里，但不在当前活动日期范围内。请改到有效活动日，或删除后再提交。</b>
                    </div>
                  </div>
                  <div className="space-y-3">
                    {outOfRangeTimetableSlots.map((slot) =>
                      renderTimetableSlotEditorCard(slot, {
                        dayLabel: `${slot.localDate || '未设置日期'}${slot.eventDayId ? ` · ${slot.eventDayId}` : ''}`,
                        showOutOfRangeBadge: true,
                      })
                    )}
                  </div>
                </div>
              ) : null}
            </div>
          </div>
            </div>

            {showTimetableDebugDrawer ? (
              <aside className="admin-event-debug-drawer">
                <div className="admin-event-debug-drawer-card">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <div className="admin-studio-label">Timetable Debug</div>
                      <div className="mt-2 text-lg font-semibold text-[#071110]">实时编辑态数据</div>
                      <div className="mt-2 text-sm leading-6 text-black/48">
                        这里会实时显示当前时间表编辑态、当前聚焦条目，以及提交前映射出来的 payload。
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => setShowTimetableDebugDrawer(false)}
                      className="admin-studio-button-secondary px-3 py-2 text-xs"
                    >
                      收起
                    </button>
                  </div>

                  <div className="mt-4 flex flex-wrap gap-2">
                    {[
                      { key: 'draft', label: '全部 draft' },
                      { key: 'focused', label: '当前条目' },
                      { key: 'payload', label: '提交态' },
                    ].map((item) => (
                      <button
                        key={item.key}
                        type="button"
                        onClick={() => setTimetableDebugTab(item.key as 'draft' | 'focused' | 'payload')}
                        className={`rounded-full px-3 py-2 text-xs font-semibold ${
                          timetableDebugTab === item.key
                            ? 'bg-[#eaf2ff] text-[#3567d6]'
                            : 'bg-[#f3f5f2] text-black/52'
                        }`}
                      >
                        {item.label}
                      </button>
                    ))}
                  </div>

                  <div className="mt-4 flex flex-wrap items-center gap-3 text-xs text-black/40">
                    <span>时间表条目：{draft.timetableSlots.length}</span>
                    <span>当前聚焦：{focusedTimetableSlot ? focusedTimetableSlot.id : '无'}</span>
                    <span>
                      当前标签：
                      {timetableDebugTab === 'draft' ? ' 全部 draft' : timetableDebugTab === 'focused' ? ' 当前条目' : ' 提交态 payload'}
                    </span>
                  </div>

                  <div className="mt-4 overflow-hidden rounded-[24px] border border-[#dfe5df] bg-[#0f1720]">
                    <pre className="admin-event-debug-drawer-pre">
                      <code>
                        {timetableDebugTab === 'draft'
                          ? timetableDraftJsonPreview
                          : timetableDebugTab === 'focused'
                            ? focusedTimetableSlotJsonPreview
                            : timetablePayloadJsonPreview}
                      </code>
                    </pre>
                  </div>
                </div>
              </aside>
            ) : null}
          </div>
        </Section>
      ) : null}

      {currentStep === 4 ? (
        <Section title="阵容" description="先读取已有阵容，再允许直接修改；如果需要，也能从时间表一键同步补齐。">
          <div className="mb-5">
            <EventStudioAIImportDock draft={draft} setDraft={setDraft} entryMode="single" entryKind="lineup" onOpenStep={() => setCurrentStep(4)} />
          </div>
          <div className="grid gap-4">
            <div className="space-y-4">
              <div className="admin-studio-section p-3">
                <div className="admin-studio-label">Lineup Snapshot</div>
              </div>

              <div className="admin-reference-soft-card p-4">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <div className="text-sm font-semibold text-[#071110]">同步策略</div>
                    <div className="mt-1 text-xs text-text-secondary">保留已有阵容后，可选择是否按时间表补齐缺失信息。</div>
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
                <div className="mt-4 grid gap-2">
                  <label className="admin-reference-card flex cursor-pointer items-start gap-3 px-3 py-3 text-sm">
                    <input
                      type="radio"
                      name="lineupSyncMode"
                      checked={draft.lineupSyncMode === 'incremental_fill'}
                      onChange={() => updateDraft('lineupSyncMode', 'incremental_fill')}
                    />
                    <span>增量补齐：保留当前阵容，使用 timetable 补全缺失艺人。</span>
                  </label>
                  <label className="admin-reference-card flex cursor-pointer items-start gap-3 px-3 py-3 text-sm">
                    <input
                      type="radio"
                      name="lineupSyncMode"
                      checked={draft.lineupSyncMode === 'exact_align'}
                      onChange={() => updateDraft('lineupSyncMode', 'exact_align')}
                    />
                    <span>严格对齐：以 timetable 为准重建阵容。</span>
                  </label>
                </div>
                {(missingLineupArtistsFromTimetable.length || lineupArtistsOnlyInLineup.length) ? (
                  <div className="mt-4 grid gap-3">
                    {missingLineupArtistsFromTimetable.length ? (
                      <div className="admin-reference-card px-4 py-3 text-sm">
                        <div className="font-semibold text-[#071110]">
                          时间表中有 {missingLineupArtistsFromTimetable.length} 位艺人尚未加入阵容
                        </div>
                        <div className="mt-2 text-black/48">
                          {missingLineupArtistsFromTimetable
                            .map((artist) => artist.memberNamesText || artist.djId)
                            .join('、')}
                        </div>
                        <button
                          type="button"
                          onClick={applyTimetableIncrementalFillToLineup}
                          className="admin-studio-button-primary mt-3 px-4 py-2 text-sm"
                        >
                          从时间表一键补齐阵容
                        </button>
                      </div>
                    ) : null}
                    {lineupArtistsOnlyInLineup.length ? (
                      <div className="admin-reference-card px-4 py-3 text-sm">
                        <div className="font-semibold text-[#071110]">
                          阵容中有 {lineupArtistsOnlyInLineup.length} 位艺人目前不在时间表里
                        </div>
                        <div className="mt-2 text-black/48">
                          {lineupArtistsOnlyInLineup
                            .map((artist) => artist.memberNamesText || artist.djId)
                            .join('、')}
                        </div>
                        <div className="mt-2 text-xs text-black/40">
                          默认提交会保留这些阵容艺人，和 iOS 上传/编辑流程一致。
                        </div>
                      </div>
                    ) : null}
                  </div>
                ) : null}
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
                          <div className="font-semibold text-[#071110]">时间表有但阵容缺少</div>
                          <div className="mt-2 text-black/48">
                            {alignmentPreview.issue.missingFromLineup.length
                              ? alignmentPreview.issue.missingFromLineup.join('、')
                              : '无'}
                          </div>
                        </div>
                        <div className="admin-reference-card px-4 py-3 text-sm">
                          <div className="font-semibold text-[#071110]">阵容有但时间表缺少</div>
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
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <div className="text-sm font-semibold text-[#071110]">已有阵容</div>
                  <div className="mt-1 text-xs text-text-secondary">
                    已读取 {lineupPreviewArtists.length} 位艺人，你可以直接改名字、DJ ID、排序，或新增/删除。
                  </div>
                </div>
                <div className="flex flex-wrap gap-2">
                  {alignmentPreview?.lineupArtists?.length ? (
                    <button type="button" onClick={applyAlignedLineupArtists} className="admin-studio-button-primary px-4 py-2 text-sm">
                      应用建议阵容
                    </button>
                  ) : null}
                  <button
                    type="button"
                    onClick={addLineupArtist}
                    className="admin-studio-button-secondary inline-flex items-center gap-2 px-4 py-2 text-sm"
                  >
                    <Plus className="h-4 w-4" />
                    新增阵容艺人
                  </button>
                </div>
              </div>

              <div className="mt-4 grid gap-3">
                {lineupPreviewArtists.length ? (
                  <>
                    <div className="hidden items-center gap-3 border border-[#eef1ee] bg-[#fafcf9] px-3.5 py-2.5 text-[11px] font-semibold tracking-[0.02em] text-black/45 lg:grid lg:grid-cols-[40px_minmax(0,1.9fr)_92px_116px_148px]">
                      <span>#</span>
                      <span>DJ / 艺人</span>
                      <span>演出形式</span>
                      <span>匹配状态</span>
                      <span>操作</span>
                    </div>
                    {lineupPreviewArtists.map((artist, index) => {
                    const artistKey = eventStudioLineupArtistIdentityKey(artist);
                    const hasTimetableMatch = Boolean(artistKey && timetableIdentityKeys.has(artistKey)) ||
                      draft.timetableSlots.some((slot) => Boolean(artist.canonicalArtistId && slot.lineupArtistId === artist.canonicalArtistId));
                    const performerCount = actTypePerformerCount(artist.actType);
                    const performerNames = getLineupArtistPerformerNames(artist);
                    const performerDisplayName = getLineupArtistDisplayName(artist);
                    const matchedCount = getLineupArtistMatchedPerformerCount(artist);
                    const isEditing = activeLineupArtistEditorId === artist.id;
                    return (
                      <div key={artist.id} className="overflow-hidden rounded-[26px] border border-[#e8eceb] bg-white shadow-[0_18px_48px_rgba(15,23,42,0.06)]">
                        <div className="grid gap-3 px-3.5 py-3 lg:grid-cols-[40px_minmax(0,1.9fr)_92px_116px_148px] lg:items-center">
                          <div className="text-sm font-semibold text-black/65">{index + 1}</div>
                          <div className="flex min-w-0 items-center gap-2.5">
                            {renderLineupArtistAvatarGroup(artist)}
                            <div className="min-w-0 flex-1">
                              <div className="truncate text-[14px] font-semibold leading-5 text-[#071110]">
                                {performerDisplayName}
                              </div>
                              <div className="mt-0.5 truncate text-[11px] text-black/42">
                                {matchedCount} / {performerCount} 已绑定
                              </div>
                            </div>
                          </div>
                          <div>
                            <span className="inline-flex rounded-full border border-[#dbe6ff] bg-[#f4f7ff] px-2.5 py-1 text-[11px] font-semibold text-[#3567d6]">
                              {normalizeActType(artist.actType).toUpperCase()}
                            </span>
                          </div>
                          <div className="space-y-1.5">
                            <span className={`inline-flex rounded-full px-2.5 py-1 text-[11px] font-semibold ${lineupArtistStatusClassName(artist)}`}>
                              {lineupArtistStatusLabel(artist)}
                            </span>
                          </div>
                          <div className="flex flex-wrap justify-start gap-2 lg:justify-end">
                            <button
                              type="button"
                              onClick={() => {
                                if (isEditing) {
                                  setActiveLineupArtistEditorId(null);
                                  return;
                                }
                                openLineupArtistEditor(artist.id);
                              }}
                              className="admin-studio-button-secondary min-w-[68px] whitespace-nowrap px-3 py-2 text-xs"
                            >
                              {isEditing ? '确认' : '编辑'}
                            </button>
                            <button
                              type="button"
                              onClick={() => removeLineupArtist(artist.id)}
                              className="admin-studio-button-danger min-w-[68px] whitespace-nowrap px-3 py-2 text-xs"
                            >
                              删除
                            </button>
                          </div>
                        </div>

                        {isEditing ? (
                          <div className="border-t border-[#eef1ee] bg-[#fbfcfa] px-4 py-4">
                            <div className="mb-3 flex flex-wrap items-start justify-between gap-2">
                              <div>
                                <div className="text-sm font-semibold text-[#071110]">编辑阵容对象</div>
                                <div className="mt-1 text-xs text-black/42">这里和 Coze 识别结果保持同样的编辑逻辑，可以修改展示名、演出形式和成员绑定。</div>
                              </div>
                              <div className="flex flex-wrap gap-2">
                                <button
                                  type="button"
                                  onClick={() => setActiveLineupArtistEditorId(null)}
                                  className="admin-studio-button-primary min-w-[82px] whitespace-nowrap px-3 py-2 text-xs"
                                >
                                  确认此项
                                </button>
                                <button
                                  type="button"
                                  onClick={() => removeLineupArtist(artist.id)}
                                  className="admin-studio-button-danger min-w-[68px] whitespace-nowrap px-3 py-2 text-xs"
                                >
                                  删除
                                </button>
                              </div>
                            </div>

                            <div className="grid gap-3 xl:grid-cols-[220px_140px_minmax(0,1fr)]">
                              <div className="space-y-1 text-xs text-black/45">
                                <span>演出形式</span>
                                <div className="grid grid-cols-3 gap-1 rounded-[14px] border border-[#e7ece7] bg-white p-1">
                                  {EVENT_STUDIO_ACT_TYPES.map((item) => {
                                    const active = normalizeActType(artist.actType) === item.value;
                                    return (
                                      <button
                                        key={item.value}
                                        type="button"
                                        onClick={() =>
                                          updateLineupDraft((current) => ({
                                            ...current,
                                            lineupArtists: materializeEditableLineupArtists(current).map((currentArtist) =>
                                              currentArtist.id === artist.id
                                                ? normalizeLineupArtistActType(currentArtist, item.value)
                                                : currentArtist
                                            ),
                                          }))
                                        }
                                        className={`min-w-0 whitespace-nowrap rounded-[10px] px-2.5 py-2 text-[13px] font-semibold tracking-[0.01em] transition ${
                                          active ? 'bg-[#eef4ff] text-[#3567d6]' : 'text-black/45 hover:bg-[#f5f7f5]'
                                        }`}
                                      >
                                        {item.label}
                                      </button>
                                    );
                                  })}
                                </div>
                              </div>
                              <label className="space-y-1 text-xs text-black/45">
                                <span>排序</span>
                                <input
                                  value={String(artist.sortOrder)}
                                  onChange={(event) =>
                                    updateLineupDraft((current) => ({
                                      ...current,
                                      lineupArtists: materializeEditableLineupArtists(current).map((currentArtist) =>
                                        currentArtist.id === artist.id
                                          ? { ...currentArtist, sortOrder: Number(event.target.value) || index + 1 }
                                          : currentArtist
                                      ),
                                    }))
                                  }
                                  className={textInputClassName}
                                  placeholder="排序"
                                />
                              </label>
                              <div className="rounded-[16px] border border-[#edf1ee] bg-white px-4 py-3 text-sm text-black/56">
                                <label className="block space-y-1">
                                  <span className="text-[11px] text-black/38">当前展示名</span>
                                  <input
                                    className={textInputClassName}
                                    value={artist.displayNameOverride || formatPerformerNamesText(performerNames, artist.actType)}
                                    onChange={(event) => updateLineupArtistDisplayName(artist.id, event.target.value)}
                                    placeholder="输入展示名称"
                                  />
                                </label>
                              </div>
                            </div>

                            <div className={`mt-3 grid gap-3 ${performerCount >= 3 ? 'xl:grid-cols-3' : 'xl:grid-cols-2'}`}>
                              {Array.from({ length: performerCount }).map((_, performerIndex) => {
                                const searchKey = lineupSearchKey(artist.id, performerIndex);
                                const boundDjId = getLineupArtistBoundDjId(artist, performerIndex);
                                const isSearching = Boolean(lineupDJSearchLoadingKeys[searchKey]);
                                const results = lineupDJSearchResults[searchKey] || [];
                                const query = performerNames[performerIndex] || performerNames[0] || '';
                                const isSolo = normalizeActType(artist.actType) === 'solo';
                                return (
                                  <div
                                    key={`${artist.id}-binding-${performerIndex}`}
                                    className="rounded-[16px] border border-[#e8eceb] bg-white p-3 shadow-[0_8px_20px_rgba(15,23,42,0.04)]"
                                  >
                                    <div className="mb-2.5 flex items-center justify-between gap-3">
                                      <div className="flex items-center gap-2">
                                        <span className="inline-flex h-9 w-9 items-center justify-center rounded-full border border-[#d9e4ff] bg-[#eef4ff] text-xs font-semibold text-[#3567d6]">
                                          {(query.trim()[0] || `${performerIndex + 1}`).toUpperCase()}
                                        </span>
                                        <div>
                                          <div className="text-xs font-semibold text-[#071110]">{isSolo ? '艺人信息' : `成员 ${performerIndex + 1}`}</div>
                                          <div className="mt-0.5 text-[11px] text-black/42">{boundDjId ? '已绑定 DJ' : '未绑定 DJ'}</div>
                                        </div>
                                      </div>
                                      <span className={`inline-flex rounded-full px-2.5 py-1 text-[11px] font-semibold ${boundDjId ? 'bg-[#e8f7ee] text-[#1f8f57]' : 'bg-[#fff4e8] text-[#a6621a]'}`}>
                                        {boundDjId ? '已匹配' : '待匹配'}
                                      </span>
                                    </div>
                                    <label className="block space-y-1">
                                      <span className="text-[11px] text-black/42">
                                        {isSolo ? '艺人名称' : `成员名称 ${performerIndex + 1}`}
                                      </span>
                                      <input
                                        value={performerNames[performerIndex] || ''}
                                        onChange={(event) => updateLineupArtistPerformerName(artist.id, performerIndex, event.target.value)}
                                        className={textInputClassName}
                                        placeholder={isSolo ? '输入艺人名称' : `输入成员 ${performerIndex + 1} 名称`}
                                      />
                                    </label>
                                    <div className="mt-2.5 flex flex-wrap items-center gap-2">
                                      <input
                                        className={`${textInputClassName} min-w-[160px] flex-1`}
                                        value={boundDjId}
                                        onChange={(event) => updateLineupArtistPerformerBinding(artist.id, performerIndex, event.target.value)}
                                        placeholder={`绑定 DJ ID ${performerIndex + 1}`}
                                      />
                                      <button
                                        type="button"
                                        onClick={() => void searchLineupArtistDJ(artist.id, performerIndex, query)}
                                        disabled={isSearching || !query}
                                        className="admin-studio-button-secondary px-3 py-2 text-xs disabled:cursor-not-allowed disabled:opacity-60"
                                      >
                                        {isSearching ? '搜索中' : '搜索'}
                                      </button>
                                      <button
                                        type="button"
                                        onClick={() => updateLineupArtistPerformerBinding(artist.id, performerIndex, '')}
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
                                            onClick={() => bindLineupArtistDJ(artist.id, performerIndex, dj)}
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
                              })}
                            </div>

                            {hasTimetableMatch ? (
                              <div className="mt-3 rounded-[14px] border border-[#dcefdc] bg-[#effaf0] px-3 py-2 text-xs text-[#23724a]">
                                该阵容对象已在时间表中出现。
                              </div>
                            ) : null}
                          </div>
                        ) : null}
                      </div>
                    );
                  })}
                  </>
                ) : (
                  <div className="admin-reference-soft-card p-4 text-sm text-black/48">
                    当前还没有读取到阵容艺人。若后端有 lineupArtists，这里会直接显示；否则会尝试从 timetable 自动推导。
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
              <AdminCountedControl count={countText(draft.ticketUrl)} maxLength={INPUT_LIMITS.common.url}>
                <input
                  value={draft.ticketUrl}
                  onChange={(event) => updateDraft('ticketUrl', event.target.value)}
                  className={textInputClassName}
                  placeholder="https://..."
                  maxLength={INPUT_LIMITS.common.url}
                />
              </AdminCountedControl>
              {errors.ticketUrl ? <div className="mt-2 text-xs text-[#6a3530]">{errors.ticketUrl}</div> : null}
            </Field>
            <Field label="票务币种">
              <AdminCountedControl count={countText(draft.ticketCurrency)} maxLength={INPUT_LIMITS.common.currency}>
                <input
                  value={draft.ticketCurrency}
                  onChange={(event) => updateDraft('ticketCurrency', event.target.value)}
                  className={textInputClassName}
                  placeholder="CNY"
                  maxLength={INPUT_LIMITS.common.currency}
                />
              </AdminCountedControl>
            </Field>
            <div className="lg:col-span-2">
              <Field label="票务备注">
                <AdminCountedControl count={countText(draft.ticketNotes, true)} maxLength={INPUT_LIMITS.event.ticketNotes} multiline>
                  <textarea
                    value={draft.ticketNotes}
                    onChange={(event) => updateDraft('ticketNotes', event.target.value)}
                    className={textAreaClassName}
                    placeholder="例如：早鸟票已售罄，预售票次日开售"
                    maxLength={INPUT_LIMITS.event.ticketNotes}
                  />
                </AdminCountedControl>
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
                          {firstImage && imagePreviewUrl(firstImage) ? (
                            firstImage.remoteUrl.trim() ? (
                              <Image src={firstImage.remoteUrl} alt={`${item.title} preview`} fill className="object-cover" sizes="900px" />
                            ) : (
                              <img src={imagePreviewUrl(firstImage)} alt={`${item.title} preview`} className="h-full w-full object-cover" />
                            )
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
              disabled={submitting || deletingImageId !== null}
              className="admin-studio-button-primary px-5 py-3 text-sm disabled:cursor-not-allowed disabled:opacity-60"
            >
              {submitting ? '提交中...' : submitButtonText || (mode === 'create' ? '提交活动' : '提交编辑')}
            </button>
          </div>
        </section>
      )}

        </main>
      </div>

      {activeLocalizedField && activeLocalizedValue ? (
        <div
          className="admin-localized-overlay"
          onClick={() => setActiveLocalizedField(null)}
        >
          <div
            className="admin-localized-overlay-card"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="flex items-start justify-between gap-4">
              <div>
                <div className="admin-studio-label">Multilingual Editor</div>
                <div className="mt-2 text-[24px] font-semibold tracking-[-0.04em] text-[#071110]">
                  {activeLocalizedField.label}
                </div>
                <div className="mt-2 text-sm leading-6 text-black/48">
                  主输入默认使用中文，这里统一补充英文、日文和其他语言版本。
                </div>
              </div>
              <button
                type="button"
                onClick={() => setActiveLocalizedField(null)}
                className="admin-localized-overlay-close"
                aria-label="关闭多语言编辑器"
              >
                <X className="h-4 w-4" strokeWidth={2.2} />
              </button>
            </div>

            <div className="mt-5 grid gap-4">
              {LOCALIZED_LOCALE_ITEMS.map((item) => (
                <Field
                  key={`${activeLocalizedField.key}-${item.key}`}
                  label={item.label}
                  hint={item.hint}
                >
                  {activeLocalizedField.kind === 'textarea' ? (
                    <AdminCountedControl
                      count={countText(activeLocalizedValue[item.key], true)}
                      maxLength={localizedFieldMaxLength(activeLocalizedField.key)}
                      multiline
                    >
                      <textarea
                        value={activeLocalizedValue[item.key]}
                        onChange={(event) => updateLocalizedField(activeLocalizedField.key, item.key, event.target.value)}
                        className={textAreaClassName}
                        placeholder={`${activeLocalizedField.label}${item.label}`}
                        maxLength={localizedFieldMaxLength(activeLocalizedField.key)}
                      />
                    </AdminCountedControl>
                  ) : (
                    <AdminCountedControl
                      count={countText(activeLocalizedValue[item.key])}
                      maxLength={localizedFieldMaxLength(activeLocalizedField.key)}
                    >
                      <input
                        value={activeLocalizedValue[item.key]}
                        onChange={(event) => updateLocalizedField(activeLocalizedField.key, item.key, event.target.value)}
                        className={textInputClassName}
                        placeholder={`${activeLocalizedField.label}${item.label}`}
                        maxLength={localizedFieldMaxLength(activeLocalizedField.key)}
                      />
                    </AdminCountedControl>
                  )}
                </Field>
              ))}
            </div>

            <div className="mt-6 flex flex-wrap items-center justify-between gap-3">
              <div className="text-xs text-black/40">
                已填写语言：{localizedTextFilledLocaleLabels(activeLocalizedValue).join(' / ') || '暂无'}
              </div>
              <div className="flex flex-wrap gap-3">
                {activeLocalizedField.clearable ? (
                  <button
                    type="button"
                    onClick={() => {
                      clearLocalizedI18n(activeLocalizedField.key as 'city' | 'country');
                      setActiveLocalizedField(null);
                    }}
                    className="admin-studio-button-secondary px-4 py-2 text-sm"
                  >
                    清除该字段多语言
                  </button>
                ) : null}
                <button
                  type="button"
                  onClick={() => setActiveLocalizedField(null)}
                  className="admin-studio-button-primary px-5 py-3 text-sm"
                >
                  完成
                </button>
              </div>
            </div>
          </div>
        </div>
      ) : null}

      {pendingDeleteTimetableStage ? (
        <div
          className="fixed inset-0 z-[90] flex items-center justify-center overflow-hidden overscroll-contain bg-black/45 p-4"
          onClick={() => setPendingDeleteTimetableStage(null)}
        >
          <div
            className="w-full max-w-md rounded-[28px] border border-[#e8eceb] bg-white p-6 shadow-[0_24px_72px_rgba(17,24,39,0.18)]"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[#b42318]">删除舞台</div>
            <div className="mt-3 text-[24px] font-semibold tracking-[-0.04em] text-[#111827]">确认删除这个舞台吗？</div>
            <p className="mt-3 text-sm leading-6 text-[#6b7280]">
              {pendingDeleteTimetableStage.stageName}
              <br />
              {pendingDeleteTimetableStage.relatedSlotCount > 0
                ? `删除后会同时移除该舞台下的 ${pendingDeleteTimetableStage.relatedSlotCount} 条时间表信息，请再次确认。`
                : '删除后该舞台将从当前活动时间表中移除。'}
            </p>
            <div className="mt-6 flex justify-end gap-3">
              <button
                type="button"
                onClick={() => setPendingDeleteTimetableStage(null)}
                className="inline-flex h-[44px] items-center justify-center rounded-full border border-[#e7ebef] bg-white px-5 text-sm font-semibold text-[#111827]"
              >
                取消
              </button>
              <button
                type="button"
                onClick={confirmRemoveTimetableStage}
                className="inline-flex h-[44px] items-center justify-center rounded-full bg-[#b42318] px-5 text-sm font-semibold text-white"
              >
                确认删除
              </button>
            </div>
          </div>
        </div>
      ) : null}

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
