'use client';

import Image from 'next/image';
import Link from 'next/link';
import { ChangeEvent, ReactNode, useMemo, useState } from 'react';
import EventLocationPickerBridgeModal, {
  type EventLocationBridgePoint,
} from '@/components/admin/EventLocationPickerBridgeModal';
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
  type EventStudioOrganizer,
  type EventStudioValidationErrors,
} from '@/features/admin-content/event-studio';

const EVENT_TYPES = ['电音节', '酒吧活动', '露天活动', '俱乐部派对', '仓库派对', '巡演专场', '其他'];

const SCHEDULE_MODE_ITEMS: Array<{
  value: EventStudioDraft['scheduleMode'];
  label: string;
  description: string;
}> = [
  { value: 'single_day', label: '单日', description: '适合一天内完成的活动。' },
  { value: 'multi_day', label: '多日', description: '连续多天但仍视为同一活动周期。' },
  { value: 'multi_week', label: '多周', description: '跨多个 week，会按 week + eventDay 结构提交。' },
];

const EVENT_STUDIO_STEP_ITEMS = [
  { key: 'media', eyebrow: 'Step 1', title: '媒体', description: '海报、封面与阵容图' },
  { key: 'basic', eyebrow: 'Step 2', title: '信息', description: '活动基础资料、地点与时区' },
  { key: 'time', eyebrow: 'Step 3', title: '周期', description: '日期范围、排期模式与日切' },
  { key: 'timetable', eyebrow: 'Step 4', title: '时间表', description: '舞台、场次与演出时段' },
  { key: 'lineup', eyebrow: 'Step 5', title: '阵容', description: '阵容艺人与对齐预览' },
  { key: 'tickets', eyebrow: 'Step 6', title: '票务', description: '购票链接、票档与备注' },
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
  const [uploadingCover, setUploadingCover] = useState(false);
  const [uploadingLineup, setUploadingLineup] = useState(false);
  const [deletingCover, setDeletingCover] = useState(false);
  const [deletingLineup, setDeletingLineup] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [currentStep, setCurrentStep] = useState(0);
  const [alignmentPreviewLoading, setAlignmentPreviewLoading] = useState(false);
  const [alignmentPreview, setAlignmentPreview] = useState<EventStudioAlignmentPreview | null>(null);
  const [alignmentPreviewError, setAlignmentPreviewError] = useState<string | null>(null);
  const [conflictNotice, setConflictNotice] = useState<string | null>(null);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [showLocationPicker, setShowLocationPicker] = useState(false);

  const totalSteps = EVENT_STUDIO_STEP_ITEMS.length;
  const canSubmit = useMemo(() => Object.keys(validateEventStudioDraft(draft)).length === 0, [draft]);

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

  const locationBridgeInitialPoint = useMemo<EventLocationBridgePoint | null>(() => {
    const latitude = Number(draft.latitude);
    const longitude = Number(draft.longitude);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
    return {
      provider: 'geoapify',
      sourceMode: 'web-event-studio-bridge',
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
    };
  }, [
    draft.latitude,
    draft.longitude,
    draft.pickedPlaceName,
    draft.pickedMapAddress,
    draft.detailAddress.en,
    draft.detailAddress.zh,
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
              : key === 'coverImage'
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

  const handleImageUpload = async (event: ChangeEvent<HTMLInputElement>, usage: 'cover' | 'lineup') => {
    const file = event.target.files?.[0];
    if (!file) return;

    try {
      setSubmitError(null);
      if (usage === 'cover') {
        setUploadingCover(true);
      } else {
        setUploadingLineup(true);
      }
      const uploaded = await eventStudioApi.uploadImage(file, {
        usage,
        draftId: draft.id,
      });
      updateDraft(
        usage === 'cover' ? 'coverImage' : 'lineupImage',
        {
          remoteUrl: uploaded.url,
          fileName: uploaded.fileName || file.name,
          usage,
          origin: 'draft-upload',
        }
      );
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '图片上传失败');
    } finally {
      if (usage === 'cover') {
        setUploadingCover(false);
      } else {
        setUploadingLineup(false);
      }
      event.target.value = '';
    }
  };

  const handleImageRemove = async (usage: 'cover' | 'lineup') => {
    const image = usage === 'cover' ? draft.coverImage : draft.lineupImage;
    if (!image) return;

    try {
      setSubmitError(null);
      if (usage === 'cover') {
        setDeletingCover(true);
      } else {
        setDeletingLineup(true);
      }

      if (image.origin === 'draft-upload') {
        await eventStudioApi.deleteDraftImages({
          draftId: draft.id,
          urls: [image.remoteUrl],
        });
      }

      updateDraft(usage === 'cover' ? 'coverImage' : 'lineupImage', null);
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '图片移除失败');
    } finally {
      if (usage === 'cover') {
        setDeletingCover(false);
      } else {
        setDeletingLineup(false);
      }
    }
  };

  const handleLocationConfirm = (point: EventLocationBridgePoint) => {
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

  return (
    <div className="space-y-5">
      {conflictNotice ? (
        <section className="admin-studio-pastel-sand p-4 text-sm text-[#604a1b]">{conflictNotice}</section>
      ) : null}

      {submitError ? (
        <section className="admin-studio-pastel-rose p-4 text-sm text-[#6a3530]">{submitError}</section>
      ) : null}

      <section className="grid gap-4 xl:grid-cols-[1.5fr_0.9fr]">
        <div className="admin-studio-section p-6">
          <div className="admin-studio-label">{mode === 'create' ? 'Event Studio' : 'Edit Session'}</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">{draftTitle}</h2>
          <div className="mt-5 grid gap-3 md:grid-cols-4">
            <SummaryStat
              label="地点绑定"
              value={draft.latitude && draft.longitude ? '已绑定地图点位' : '待选择'}
              tone="mint"
            />
            <SummaryStat label="排期结构" value={`${draft.weeks.length} 周 / ${draft.eventDays.length} 天`} tone="sand" />
            <SummaryStat label="时间表条目" value={`${draft.timetableSlots.length} 条`} tone="rose" />
            <SummaryStat
              label="当前分页"
              value={`${currentStep + 1}/${totalSteps} · ${currentStepItem.title}`}
              tone="soft"
            />
          </div>
        </div>

        <div className="admin-studio-pastel-mint p-6">
          <div className="admin-studio-label">Submission</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">分页式创建流程</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-black/52">
            <p>当前 web 端创建与编辑流程已经按 iOS 的分页顺序组织：媒体、信息、周期、时间表、阵容、票务、检查。</p>
            <p>地点选择改为直接桥接 `festival-viewer` 的地图选点能力，不再只靠手工填写经纬度。</p>
            <p>活动创建和编辑都继续走当前正式接口，不改后端提交契约。</p>
          </div>
        </div>
      </section>

      <StepNavigation currentStep={currentStep} onSelect={goToStep} />

      {currentStep === 0 ? (
        <Section title="媒体" description="第一步先处理封面、海报和阵容图，这样后续在检查页能直接看到完整的视觉预览。">
          <div className="grid gap-5 lg:grid-cols-2">
            <div className="admin-reference-card p-4">
              <Field label="封面 / 海报" error={errors.coverImage}>
                <div className="admin-reference-soft-card flex flex-col gap-3 border border-dashed p-4">
                  {draft.coverImage?.remoteUrl ? (
                    <div className="relative aspect-video overflow-hidden rounded-xl border border-border-secondary">
                      <Image src={draft.coverImage.remoteUrl} alt="cover" fill className="object-cover" sizes="800px" />
                    </div>
                  ) : (
                    <div className="flex aspect-video items-center justify-center rounded-xl border border-[#e8eceb] bg-white text-sm text-black/42">
                      还没有上传封面
                    </div>
                  )}

                  <div className="flex items-center justify-between gap-3">
                    <span className="text-sm text-black/48">{uploadingCover || deletingCover ? '处理中...' : '建议优先上传海报主图'}</span>
                    <div className="flex items-center gap-2">
                      {draft.coverImage ? (
                        <button
                          type="button"
                          onClick={() => void handleImageRemove('cover')}
                          className="admin-studio-button-secondary px-3 py-2 text-xs"
                        >
                          移除
                        </button>
                      ) : null}
                      <label className="admin-studio-button-secondary px-3 py-2 text-xs">
                        上传
                        <input
                          type="file"
                          accept="image/*"
                          className="hidden"
                          onChange={(event) => void handleImageUpload(event, 'cover')}
                        />
                      </label>
                    </div>
                  </div>
                </div>
              </Field>
            </div>

            <div className="admin-reference-card p-4">
              <Field label="阵容图（可选）">
                <div className="admin-reference-soft-card flex flex-col gap-3 border border-dashed p-4">
                  {draft.lineupImage?.remoteUrl ? (
                    <div className="relative aspect-video overflow-hidden rounded-xl border border-border-secondary">
                      <Image src={draft.lineupImage.remoteUrl} alt="lineup" fill className="object-cover" sizes="800px" />
                    </div>
                  ) : (
                    <div className="flex aspect-video items-center justify-center rounded-xl border border-[#e8eceb] bg-white text-sm text-black/42">
                      还没有上传阵容图
                    </div>
                  )}

                  <div className="flex items-center justify-between gap-3">
                    <span className="text-sm text-black/48">{uploadingLineup || deletingLineup ? '处理中...' : '可选，用于目录与详情页补充展示'}</span>
                    <div className="flex items-center gap-2">
                      {draft.lineupImage ? (
                        <button
                          type="button"
                          onClick={() => void handleImageRemove('lineup')}
                          className="admin-studio-button-secondary px-3 py-2 text-xs"
                        >
                          移除
                        </button>
                      ) : null}
                      <label className="admin-studio-button-secondary px-3 py-2 text-xs">
                        上传
                        <input
                          type="file"
                          accept="image/*"
                          className="hidden"
                          onChange={(event) => void handleImageUpload(event, 'lineup')}
                        />
                      </label>
                    </div>
                  </div>
                </div>
              </Field>
            </div>
          </div>
        </Section>
      ) : null}

      {currentStep === 1 ? (
        <>
          <Section title="活动信息" description="这一步集中填写活动名称、主办方、描述以及地点基础信息。地点部分已经接入 legacy 地图工具。">
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
        <Section title="活动周期" description="这里决定活动的日期结构，提交时会同步生成 `weeks / eventDays`，供 timetable 和 lineup 共用。">
          <div className="grid gap-4 lg:grid-cols-2">
            <Field label="排期模式">
              <select
                value={draft.scheduleMode}
                onChange={(event) => updateDraft('scheduleMode', event.target.value as EventStudioDraft['scheduleMode'])}
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
            <Field label="官网链接">
              <input
                value={draft.officialWebsite}
                onChange={(event) => updateDraft('officialWebsite', event.target.value)}
                className={textInputClassName}
                placeholder="https://..."
              />
            </Field>
          </div>

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
                    <div className="text-sm text-black/48">请先完成开始/结束日期设置。</div>
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
        <Section title="时间表" description="先按 event day 建立演出时段，再决定舞台名与 DJ 绑定。这里是活动编辑里最核心的操作区。">
          <div className="admin-reference-card p-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <div className="text-sm font-semibold">时间表条目</div>
                <div className="mt-1 text-xs text-text-secondary">
                  先完成活动日期结构后，就可以按 event day 逐条补充舞台、演出人和开始结束时间。
                </div>
              </div>
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
                新增时间表条目
              </button>
            </div>

            <div className="mt-4 grid gap-4 xl:grid-cols-[1.25fr_0.75fr]">
              <div className="space-y-3">
                {draft.timetableSlots.length ? (
                  draft.timetableSlots.map((slot) => (
                    <div key={slot.id} className="grid gap-3 rounded-[24px] border border-[#e8eceb] bg-[#f8f9f8] p-4 lg:grid-cols-2">
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

                      <div className="flex justify-end lg:col-span-2">
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

                {errors.timetableSlots ? <div className="text-xs text-red-300">{errors.timetableSlots}</div> : null}
              </div>

              <div className="space-y-4">
                <div className="admin-reference-soft-card p-4">
                  <div className="text-sm font-semibold text-[#071110]">Stage Order 预览</div>
                  <div className="mt-3 flex flex-wrap gap-2">
                    {draft.stageOrder.length ? (
                      draft.stageOrder.map((stage) => (
                        <span key={stage} className="admin-reference-chip">
                          {stage}
                        </span>
                      ))
                    ) : (
                      <div className="text-sm text-black/48">添加 timetable 条目后会自动生成。</div>
                    )}
                  </div>
                </div>

                <div className="admin-reference-soft-card p-4">
                  <div className="text-sm font-semibold text-[#071110]">录入密度提醒</div>
                  <div className="mt-3 space-y-2 text-sm leading-6 text-black/52">
                    <p>这一页优先突出“新增时段、改演出日、改舞台、改时间”这些核心动作。</p>
                    <p>阵容的最终整理放到下一步处理，避免在一页里混太多次级信息。</p>
                  </div>
                </div>
              </div>
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

            {errors.ticketTiers ? <div className="mt-3 text-xs text-red-300">{errors.ticketTiers}</div> : null}
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
                <div className="mt-4 grid gap-4">
                  <div className="rounded-[24px] border border-[#e8eceb] bg-[#f8f9f8] p-4">
                    <div className="text-xs font-semibold uppercase tracking-[0.18em] text-black/42">Cover</div>
                    <div className="mt-3 relative aspect-[16/9] overflow-hidden rounded-[18px] border border-[#e8eceb] bg-white">
                      {draft.coverImage?.remoteUrl ? (
                        <Image src={draft.coverImage.remoteUrl} alt="cover preview" fill className="object-cover" sizes="900px" />
                      ) : (
                        <div className="flex h-full items-center justify-center text-sm text-black/42">还没有上传封面</div>
                      )}
                    </div>
                  </div>

                  <div className="rounded-[24px] border border-[#e8eceb] bg-[#f8f9f8] p-4">
                    <div className="text-xs font-semibold uppercase tracking-[0.18em] text-black/42">Lineup</div>
                    <div className="mt-3 relative aspect-[16/9] overflow-hidden rounded-[18px] border border-[#e8eceb] bg-white">
                      {draft.lineupImage?.remoteUrl ? (
                        <Image src={draft.lineupImage.remoteUrl} alt="lineup preview" fill className="object-cover" sizes="900px" />
                      ) : (
                        <div className="flex h-full items-center justify-center text-sm text-black/42">还没有上传阵容图</div>
                      )}
                    </div>
                  </div>
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
              disabled={submitting || uploadingCover || uploadingLineup || deletingCover || deletingLineup}
              className="admin-studio-button-primary px-5 py-3 text-sm disabled:cursor-not-allowed disabled:opacity-60"
            >
              {submitting ? '提交中...' : submitButtonText || (mode === 'create' ? '提交活动' : '提交编辑')}
            </button>
          </div>
        </section>
      )}

      <EventLocationPickerBridgeModal
        open={showLocationPicker}
        initialPoint={locationBridgeInitialPoint}
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
