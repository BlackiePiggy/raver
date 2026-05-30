'use client';

import Link from 'next/link';
import Image from 'next/image';
import { ChangeEvent, useMemo, useState } from 'react';
import {
  createEmptyTicketTierDraft,
  createEmptyEventStudioTimetableSlotDraft,
  eventStudioApi,
  EventStudioApiError,
  mapEventStudioDraftToCreateInput,
  syncEventStudioLineupState,
  syncEventStudioScheduleStructure,
  mapEventStudioDraftToUpdateInput,
  validateEventStudioDraft,
  type EventStudioAlignmentPreview,
  type EventStudioCreateResult,
  type EventStudioDraft,
  type EventStudioOrganizer,
  type EventStudioValidationErrors,
} from '@/features/admin-content/event-studio';

const EVENT_TYPES = ['电音节', '酒吧活动', '露天活动', '俱乐部派对', '仓库派对', '巡演专场', '其他'];
const SCHEDULE_MODE_ITEMS: Array<{ value: EventStudioDraft['scheduleMode']; label: string; description: string }> = [
  { value: 'single_day', label: '单日', description: '适合一天内完成的活动。' },
  { value: 'multi_day', label: '多日', description: '连续多天但仍视为同一周次的活动。' },
  { value: 'multi_week', label: '多周', description: '跨多个周次，按 week + eventDay 结构提交。' },
];

function Section({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
      <div>
        <h2 className="text-2xl font-semibold">{title}</h2>
        <p className="mt-2 text-sm leading-6 text-text-secondary">{description}</p>
      </div>
      <div className="mt-5">{children}</div>
    </section>
  );
}

function Field({
  label,
  error,
  children,
}: {
  label: string;
  error?: string;
  children: React.ReactNode;
}) {
  return (
    <label className="block">
      <div className="mb-2 text-sm text-text-secondary">{label}</div>
      {children}
      {error ? <div className="mt-2 text-xs text-red-300">{error}</div> : null}
    </label>
  );
}

const textInputClassName = 'w-full rounded-xl border border-border-secondary bg-bg-tertiary/70 px-4 py-3 text-sm text-text-primary outline-none transition-colors focus:border-primary-blue';
const textAreaClassName = `${textInputClassName} min-h-28 resize-y`;

const formatEventDayLabel = (day: EventStudioDraft['eventDays'][number]) =>
  `${day.label || day.eventDayId} · ${day.date}`;

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
  const [submitting, setSubmitting] = useState(false);
  const [alignmentPreviewLoading, setAlignmentPreviewLoading] = useState(false);
  const [alignmentPreview, setAlignmentPreview] = useState<EventStudioAlignmentPreview | null>(null);
  const [alignmentPreviewError, setAlignmentPreviewError] = useState<string | null>(null);
  const [conflictNotice, setConflictNotice] = useState<string | null>(null);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const canSubmit = useMemo(() => Object.keys(validateEventStudioDraft(draft)).length === 0, [draft]);

  const updateDraft = <K extends keyof EventStudioDraft>(key: K, value: EventStudioDraft[K]) => {
    setDraft((current) => {
      const next = { ...current, [key]: value };
      if (key === 'startDate' || key === 'endDate' || key === 'scheduleMode') {
        return syncEventStudioScheduleStructure(next);
      }
      return next;
    });
    setErrors((current) => {
      if (!current[key as keyof EventStudioValidationErrors]) return current;
      const next = { ...current };
      delete next[key as keyof EventStudioValidationErrors];
      return next;
    });
  };

  const updateDerivedDraft = (updater: (current: EventStudioDraft) => EventStudioDraft) => {
    setDraft((current) => {
      const next = updater(current);
      const syncedLineup = syncEventStudioLineupState(next, next.eventDays);
      return {
        ...next,
        ...syncedLineup,
      };
    });
    setErrors((current) => {
      if (!current.timetableSlots) return current;
      const next = { ...current };
      delete next.timetableSlots;
      return next;
    });
    setAlignmentPreview(null);
    setAlignmentPreviewError(null);
  };

  const updateLocalizedField = (
    key: 'name' | 'city' | 'country' | 'detailAddress',
    locale: 'zh' | 'en' | 'ja' | 'enFull',
    value: string
  ) => {
    setDraft((current) => ({
      ...current,
      [key]: {
        ...current[key],
        [locale]: value,
      },
    }));
    setErrors((current) => {
      if (!current[key]) return current;
      const next = { ...current };
      delete next[key];
      return next;
    });
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
      if (usage === 'cover') {
        setUploadingCover(true);
      } else {
        setUploadingLineup(true);
      }
      const uploaded = await eventStudioApi.uploadImage(file);
      if (usage === 'cover') {
        updateDraft('coverImage', { remoteUrl: uploaded.url, fileName: file.name });
      } else {
        updateDraft('lineupImage', { remoteUrl: uploaded.url, fileName: file.name });
      }
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

  const handleSubmit = async () => {
    const nextErrors = validateEventStudioDraft(draft);
    setErrors(nextErrors);
    setSubmitError(null);
    setConflictNotice(null);
    if (Object.keys(nextErrors).length > 0) return;

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
    updateDerivedDraft((current) => ({
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

  return (
    <div className="space-y-5">
      {conflictNotice ? (
        <section className="rounded-3xl border border-amber-500/30 bg-amber-500/10 p-4 text-sm text-amber-100">
          {conflictNotice}
        </section>
      ) : null}

      {submitError ? (
        <section className="rounded-3xl border border-red-500/30 bg-red-500/10 p-4 text-sm text-red-200">
          {submitError}
        </section>
      ) : null}

      <Section title="基础信息" description="先填写活动名称、类型、主办方文本名和活动来源链接。多语言目前以中英文为主，后续会继续补 organizer 绑定与多语言展开策略。">
        <div className="grid gap-4 lg:grid-cols-2">
          <Field label="活动名称（中文）" error={errors.name}>
            <input value={draft.name.zh} onChange={(event) => updateLocalizedField('name', 'zh', event.target.value)} className={textInputClassName} placeholder="例如：Tomorrowland" />
          </Field>
          <Field label="活动名称（英文）">
            <input value={draft.name.en} onChange={(event) => updateLocalizedField('name', 'en', event.target.value)} className={textInputClassName} placeholder="English name" />
          </Field>
          <Field label="活动类型">
            <select value={draft.eventType} onChange={(event) => updateDraft('eventType', event.target.value)} className={textInputClassName}>
              {EVENT_TYPES.map((item) => (
                <option key={item} value={item}>
                  {item}
                </option>
              ))}
            </select>
          </Field>
          <Field label="活动简称">
            <input value={draft.abbreviation} onChange={(event) => updateDraft('abbreviation', event.target.value)} className={textInputClassName} placeholder="例如：ASOT" />
          </Field>
          <Field label="主办方绑定">
            <div className="space-y-3">
              <div className="flex flex-col gap-3 lg:flex-row">
                <input
                  value={draft.organizerName}
                  onChange={(event) => {
                    updateDraft('organizerName', event.target.value);
                    if (draft.organizerFestivalId) {
                      updateDraft('organizerFestivalId', '');
                    }
                  }}
                  className={textInputClassName}
                  placeholder="输入主办方名称后可搜索绑定"
                />
                <button
                  type="button"
                  onClick={() => void searchOrganizers()}
                  className="rounded-xl border border-border-secondary px-4 py-3 text-sm hover:border-primary-blue hover:text-primary-blue"
                >
                  {organizerLoading ? '搜索中...' : '搜索主办方'}
                </button>
                <Link
                  href={
                    draft.organizerName.trim()
                      ? `/admin/content/organizers/new?name=${encodeURIComponent(
                          draft.organizerName.trim()
                        )}`
                      : '/admin/content/organizers/new'
                  }
                  className="rounded-xl border border-border-secondary px-4 py-3 text-sm hover:border-primary-blue hover:text-primary-blue"
                >
                  新建主办方
                </Link>
              </div>

              {draft.organizerFestivalId ? (
                <div className="rounded-xl border border-primary-blue/40 bg-primary-blue/10 px-4 py-3 text-sm text-primary-blue">
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
                      className="rounded-xl border border-border-secondary bg-bg-primary/20 px-4 py-3 text-left text-sm hover:border-primary-blue"
                    >
                      <div className="font-semibold text-text-primary">{item.name}</div>
                      <div className="mt-1 text-xs text-text-secondary">
                        {[item.country, item.city, item.tagline].filter(Boolean).join(' · ') || item.id}
                      </div>
                    </button>
                  ))}
                </div>
              ) : null}
            </div>
          </Field>
          <Field label="来源链接">
            <input value={draft.sourceEventUrl} onChange={(event) => updateDraft('sourceEventUrl', event.target.value)} className={textInputClassName} placeholder="https://..." />
          </Field>
          <div className="lg:col-span-2">
            <Field label="活动描述">
              <textarea value={draft.description} onChange={(event) => updateDraft('description', event.target.value)} className={textAreaClassName} placeholder="填写活动简介、风格或亮点说明" />
            </Field>
          </div>
        </div>
      </Section>

      <Section title="地点与时区" description="第一版先支持手动地址、时区确认和可选坐标。后续会继续接地图选点、结构化 locationPoint 和 organizer 绑定回填。">
        <div className="grid gap-4 lg:grid-cols-2">
          <Field label="城市（中文）" error={errors.city}>
            <input value={draft.city.zh} onChange={(event) => updateLocalizedField('city', 'zh', event.target.value)} className={textInputClassName} placeholder="Shanghai" />
          </Field>
          <Field label="城市（英文）">
            <input value={draft.city.en} onChange={(event) => updateLocalizedField('city', 'en', event.target.value)} className={textInputClassName} placeholder="Shanghai" />
          </Field>
          <Field label="国家（中文）" error={errors.country}>
            <input value={draft.country.zh} onChange={(event) => updateLocalizedField('country', 'zh', event.target.value)} className={textInputClassName} placeholder="中国" />
          </Field>
          <Field label="国家（英文）">
            <input value={draft.country.en} onChange={(event) => updateLocalizedField('country', 'en', event.target.value)} className={textInputClassName} placeholder="China" />
          </Field>
          <div className="lg:col-span-2">
            <Field label="详细地址（中文）" error={errors.detailAddress}>
              <textarea value={draft.detailAddress.zh} onChange={(event) => updateLocalizedField('detailAddress', 'zh', event.target.value)} className={textAreaClassName} placeholder="活动详细地址" />
            </Field>
          </div>
          <Field label="纬度（可选）">
            <input value={draft.latitude} onChange={(event) => updateDraft('latitude', event.target.value)} className={textInputClassName} placeholder="31.2304" />
          </Field>
          <Field label="经度（可选）">
            <input value={draft.longitude} onChange={(event) => updateDraft('longitude', event.target.value)} className={textInputClassName} placeholder="121.4737" />
          </Field>
          <Field label="地图地点名（可选）">
            <input value={draft.pickedPlaceName} onChange={(event) => updateDraft('pickedPlaceName', event.target.value)} className={textInputClassName} placeholder="例如：National Stadium" />
          </Field>
          <Field label="地图地址（可选）">
            <input value={draft.pickedMapAddress} onChange={(event) => updateDraft('pickedMapAddress', event.target.value)} className={textInputClassName} placeholder="用于 locationPoint 回填" />
          </Field>
          <div className="lg:col-span-2 rounded-2xl border border-border-secondary bg-bg-tertiary/60 p-4">
            <Field label="活动时区搜索" error={errors.timeZone || timezoneError}>
              <div className="flex flex-col gap-3 lg:flex-row">
                <input
                  value={draft.timeZoneQuery}
                  onChange={(event) => {
                    updateDraft('timeZoneQuery', event.target.value);
                    if (draft.timeZoneSelection && event.target.value.trim() !== (draft.timeZoneSelection.cityAscii || draft.timeZoneSelection.city)) {
                      updateDraft('timeZoneSelection', null);
                    }
                  }}
                  className={textInputClassName}
                  placeholder="输入城市或城市+州/国家，例如 Chicago / Amsterdam NL"
                />
                <button type="button" onClick={() => void searchTimezones()} className="rounded-xl border border-border-secondary px-4 py-3 text-sm hover:border-primary-blue hover:text-primary-blue">
                  {timezoneLoading ? '搜索中...' : '搜索时区'}
                </button>
              </div>
            </Field>
            <div className={`mt-3 rounded-xl border px-4 py-3 text-sm ${draft.timeZoneSelection ? 'border-primary-blue/40 bg-primary-blue/10 text-primary-blue' : 'border-border-secondary bg-bg-primary/20 text-text-secondary'}`}>
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
                      setErrors((current) => {
                        if (!current.timeZone) return current;
                        const next = { ...current };
                        delete next.timeZone;
                        return next;
                      });
                    }}
                    className="rounded-xl border border-border-secondary bg-bg-primary/20 px-4 py-3 text-left text-sm hover:border-primary-blue"
                  >
                    {item.label}
                  </button>
                ))}
              </div>
            ) : null}
          </div>
        </div>
      </Section>

      <Section title="时间与票务" description="当前版本已开始接结构化 schedule 语义。这里会同步生成 `weeks / eventDays`，为后续 timetable 和审核 diff 做准备。">
        <div className="grid gap-4 lg:grid-cols-2">
          <Field label="排期模式">
            <select value={draft.scheduleMode} onChange={(event) => updateDraft('scheduleMode', event.target.value as EventStudioDraft['scheduleMode'])} className={textInputClassName}>
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
          <Field label="开始日期" error={errors.startDate}>
            <input type="date" value={draft.startDate} onChange={(event) => updateDraft('startDate', event.target.value)} className={textInputClassName} />
          </Field>
          <Field label="结束日期" error={errors.endDate}>
            <input type="date" value={draft.endDate} onChange={(event) => updateDraft('endDate', event.target.value)} className={textInputClassName} />
          </Field>
          <Field label="Day Rollover Hour">
            <input value={draft.dayRolloverHour} onChange={(event) => updateDraft('dayRolloverHour', event.target.value)} className={textInputClassName} placeholder="默认 6" />
          </Field>
          <Field label="官网链接">
            <input value={draft.officialWebsite} onChange={(event) => updateDraft('officialWebsite', event.target.value)} className={textInputClassName} placeholder="https://..." />
          </Field>
          <Field label="购票链接">
            <input value={draft.ticketUrl} onChange={(event) => updateDraft('ticketUrl', event.target.value)} className={textInputClassName} placeholder="https://..." />
          </Field>
          <Field label="票务币种">
            <input value={draft.ticketCurrency} onChange={(event) => updateDraft('ticketCurrency', event.target.value)} className={textInputClassName} placeholder="CNY" />
          </Field>
          <div className="lg:col-span-2">
            <Field label="票务备注">
              <textarea value={draft.ticketNotes} onChange={(event) => updateDraft('ticketNotes', event.target.value)} className={textAreaClassName} placeholder="例如：早鸟票已售罄，预售票次日开售" />
            </Field>
          </div>
        </div>

        <div className="mt-6 rounded-2xl border border-border-secondary bg-bg-tertiary/60 p-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <div className="text-sm font-semibold">结构化日期预览</div>
              <div className="mt-1 text-xs text-text-secondary">
                提交时会把这些 `weeks / eventDays` 一并带给 `/v1/events`，和 iOS 的 schedule 语义保持一致。
              </div>
            </div>
            <div className="text-xs text-text-secondary">
              weeks: {draft.weeks.length} · eventDays: {draft.eventDays.length}
            </div>
          </div>

          <div className="mt-4 grid gap-4 xl:grid-cols-2">
            <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-4">
              <div className="text-sm font-semibold">Weeks</div>
              <div className="mt-3 space-y-2">
                {draft.weeks.length ? (
                  draft.weeks.map((week) => (
                    <div key={week.id} className="rounded-xl border border-border-secondary bg-bg-tertiary/50 px-3 py-2 text-sm">
                      <div className="font-medium text-text-primary">
                        {week.label || `Week ${week.weekIndex}`}
                      </div>
                      <div className="mt-1 text-xs text-text-secondary">
                        {week.startDate} → {week.endDate}
                      </div>
                    </div>
                  ))
                ) : (
                  <div className="text-sm text-text-secondary">请先完成开始/结束日期设置。</div>
                )}
              </div>
            </div>

            <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-4">
              <div className="text-sm font-semibold">Event Days</div>
              <div className="mt-3 space-y-2">
                {draft.eventDays.length ? (
                  draft.eventDays.map((day) => (
                    <div key={day.id} className="rounded-xl border border-border-secondary bg-bg-tertiary/50 px-3 py-2 text-sm">
                      <div className="font-medium text-text-primary">
                        {day.label || day.eventDayId}
                      </div>
                      <div className="mt-1 text-xs text-text-secondary">
                        {day.date} · week {day.weekIndex} / day {day.dayIndexInWeek} / overall {day.overallDayIndex}
                      </div>
                    </div>
                  ))
                ) : (
                  <div className="text-sm text-text-secondary">当前还没有生成 eventDays。</div>
                )}
              </div>
            </div>
          </div>
        </div>

        <div className="mt-6 rounded-2xl border border-border-secondary bg-bg-tertiary/60 p-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <div className="text-sm font-semibold">票档</div>
              <div className="mt-1 text-xs text-text-secondary">可选填写，当前版本支持简单名称 + 价格。</div>
            </div>
            <button
              type="button"
              onClick={() => updateDraft('ticketTiers', [...draft.ticketTiers, createEmptyTicketTierDraft()])}
              className="rounded-xl border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue"
            >
              新增票档
            </button>
          </div>

          <div className="mt-4 space-y-3">
            {draft.ticketTiers.map((tier) => (
              <div key={tier.id} className="grid gap-3 rounded-2xl border border-border-secondary bg-bg-secondary p-4 lg:grid-cols-[1.4fr_1fr_120px_auto]">
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
                      draft.ticketTiers.map((current) => (current.id === tier.id ? { ...current, currency: event.target.value } : current))
                    )
                  }
                  className={textInputClassName}
                  placeholder="币种"
                />
                <button
                  type="button"
                  onClick={() => updateDraft('ticketTiers', draft.ticketTiers.filter((current) => current.id !== tier.id))}
                  className="rounded-xl border border-red-500/30 px-4 py-3 text-sm text-red-300 hover:border-red-400"
                >
                  删除
                </button>
              </div>
            ))}
          </div>
          {errors.ticketTiers ? <div className="mt-3 text-xs text-red-300">{errors.ticketTiers}</div> : null}
        </div>

        <div className="mt-6 rounded-2xl border border-border-secondary bg-bg-tertiary/60 p-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <div className="text-sm font-semibold">阵容与时间表</div>
              <div className="mt-1 text-xs text-text-secondary">
                这版先按 structured eventDay + timetable slot 提交，自动推导 `stageOrder` 和基础 `lineupArtists`，与 `/v1/events` 及 iOS mapper 语义对齐。
              </div>
            </div>
            <button
              type="button"
              onClick={() =>
                updateDerivedDraft((current) => ({
                  ...current,
                  timetableSlots: [
                    ...current.timetableSlots,
                    createEmptyEventStudioTimetableSlotDraft(
                      current.eventDays[0],
                      current.stageOrder[0] || 'Main Stage'
                    ),
                  ].map((slot, index) => ({
                    ...slot,
                    sortOrder: index + 1,
                  })),
                }))
              }
              disabled={!draft.eventDays.length}
              className="rounded-xl border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue disabled:cursor-not-allowed disabled:opacity-60"
            >
              新增时间表条目
            </button>
          </div>

          <div className="mt-4 grid gap-4 xl:grid-cols-[1.2fr_1fr]">
            <div className="space-y-3">
              {draft.timetableSlots.length ? (
                draft.timetableSlots.map((slot) => (
                  <div key={slot.id} className="grid gap-3 rounded-2xl border border-border-secondary bg-bg-secondary p-4 lg:grid-cols-2">
                    <Field label="演出日">
                      <select
                        value={slot.eventDayId}
                        onChange={(event) => {
                          const selectedDay = draft.eventDays.find((day) => day.eventDayId === event.target.value);
                          if (!selectedDay) return;
                          updateDerivedDraft((current) => ({
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
                          updateDerivedDraft((current) => ({
                            ...current,
                            timetableSlots: current.timetableSlots.map((currentSlot) =>
                              currentSlot.id === slot.id
                                ? { ...currentSlot, stageName: event.target.value }
                                : currentSlot
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
                          updateDerivedDraft((current) => ({
                            ...current,
                            timetableSlots: current.timetableSlots.map((currentSlot) =>
                              currentSlot.id === slot.id
                                ? { ...currentSlot, memberNamesText: event.target.value }
                                : currentSlot
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
                          updateDerivedDraft((current) => ({
                            ...current,
                            timetableSlots: current.timetableSlots.map((currentSlot) =>
                              currentSlot.id === slot.id
                                ? { ...currentSlot, djId: event.target.value, memberDjIds: event.target.value.trim() ? [event.target.value.trim()] : [] }
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
                          updateDerivedDraft((current) => ({
                            ...current,
                            timetableSlots: current.timetableSlots.map((currentSlot) =>
                              currentSlot.id === slot.id
                                ? { ...currentSlot, startTime: event.target.value }
                                : currentSlot
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
                          updateDerivedDraft((current) => ({
                            ...current,
                            timetableSlots: current.timetableSlots.map((currentSlot) =>
                              currentSlot.id === slot.id
                                ? { ...currentSlot, endTime: event.target.value }
                                : currentSlot
                            ),
                          }))
                        }
                        className={textInputClassName}
                      />
                    </Field>
                    <div className="lg:col-span-2 flex justify-end">
                      <button
                        type="button"
                        onClick={() =>
                          updateDerivedDraft((current) => ({
                            ...current,
                            timetableSlots: current.timetableSlots
                              .filter((currentSlot) => currentSlot.id !== slot.id)
                              .map((currentSlot, index) => ({
                                ...currentSlot,
                                sortOrder: index + 1,
                              })),
                          }))
                        }
                        className="rounded-xl border border-red-500/30 px-4 py-3 text-sm text-red-300 hover:border-red-400"
                      >
                        删除条目
                      </button>
                    </div>
                  </div>
                ))
              ) : (
                <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-4 text-sm text-text-secondary">
                  还没有时间表条目。先完成活动日期结构后，就可以按 event day 逐条补充舞台和演出时段。
                </div>
              )}
              {errors.timetableSlots ? <div className="text-xs text-red-300">{errors.timetableSlots}</div> : null}
            </div>

            <div className="space-y-4">
              <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-4">
                <div className="text-sm font-semibold">Stage Order 预览</div>
                <div className="mt-3 flex flex-wrap gap-2">
                  {draft.stageOrder.length ? (
                    draft.stageOrder.map((stage) => (
                      <span key={stage} className="rounded-full border border-border-secondary bg-bg-tertiary/50 px-3 py-1 text-xs text-text-primary">
                        {stage}
                      </span>
                    ))
                  ) : (
                    <div className="text-sm text-text-secondary">添加 timetable 条目后会自动生成。</div>
                  )}
                </div>
              </div>

              <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-4">
                <div className="text-sm font-semibold">Lineup Sync Mode</div>
                <div className="mt-3 space-y-2">
                  <label className="flex cursor-pointer items-start gap-3 rounded-xl border border-border-secondary px-3 py-3 text-sm">
                    <input
                      type="radio"
                      name="lineupSyncMode"
                      checked={draft.lineupSyncMode === 'incremental_fill'}
                      onChange={() => updateDraft('lineupSyncMode', 'incremental_fill')}
                    />
                    <span>增量补齐：保留当前阵容基础上，用 timetable 补全缺失艺人。</span>
                  </label>
                  <label className="flex cursor-pointer items-start gap-3 rounded-xl border border-border-secondary px-3 py-3 text-sm">
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

              <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-4">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <div className="text-sm font-semibold">对齐预览</div>
                    <div className="mt-1 text-xs text-text-secondary">
                      先用后端规则预览阵容和时间表是否一致，再决定是否按严格对齐方式提交。
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => void handlePreviewAlignment()}
                    disabled={alignmentPreviewLoading || !draft.timetableSlots.length}
                    className="rounded-xl border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue disabled:cursor-not-allowed disabled:opacity-60"
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
                    <div className={`rounded-2xl border px-4 py-3 text-sm ${
                      alignmentPreview.aligned
                        ? 'border-emerald-500/30 bg-emerald-500/10 text-emerald-100'
                        : 'border-amber-500/30 bg-amber-500/10 text-amber-100'
                    }`}>
                      {alignmentPreview.message || (alignmentPreview.aligned ? '当前阵容与时间表已对齐。' : '当前阵容与时间表存在差异。')}
                    </div>

                    {!alignmentPreview.aligned && alignmentPreview.issue ? (
                      <div className="grid gap-3">
                        <div className="rounded-2xl border border-border-secondary bg-bg-tertiary/50 px-4 py-3 text-sm">
                          <div className="font-semibold text-text-primary">时间表中存在但阵容里缺少</div>
                          <div className="mt-2 text-text-secondary">
                            {alignmentPreview.issue.missingFromLineup.length
                              ? alignmentPreview.issue.missingFromLineup.join('、')
                              : '无'}
                          </div>
                        </div>
                        <div className="rounded-2xl border border-border-secondary bg-bg-tertiary/50 px-4 py-3 text-sm">
                          <div className="font-semibold text-text-primary">阵容中存在但时间表里缺少</div>
                          <div className="mt-2 text-text-secondary">
                            {alignmentPreview.issue.extraInLineup.length
                              ? alignmentPreview.issue.extraInLineup.join('、')
                              : '无'}
                          </div>
                        </div>
                      </div>
                    ) : null}

                    {alignmentPreview.lineupArtists.length ? (
                      <div className="rounded-2xl border border-border-secondary bg-bg-tertiary/50 p-4">
                        <div className="flex items-center justify-between gap-3">
                          <div className="text-sm font-semibold">建议对齐后的 Lineup</div>
                          <button
                            type="button"
                            onClick={applyAlignedLineupArtists}
                            className="rounded-xl bg-primary-blue px-4 py-2 text-sm font-semibold text-white"
                          >
                            应用建议阵容
                          </button>
                        </div>
                        <div className="mt-3 space-y-2">
                          {alignmentPreview.lineupArtists.map((artist, index) => (
                            <div key={`${artist.djName}-${index}`} className="rounded-xl border border-border-secondary bg-bg-secondary px-3 py-2 text-sm">
                              <div className="font-medium text-text-primary">{artist.djName}</div>
                              <div className="mt-1 text-xs text-text-secondary">
                                sort: {artist.sortOrder ?? index + 1}
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    ) : null}
                  </div>
                ) : null}
              </div>

              <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-4">
                <div className="text-sm font-semibold">衍生 Lineup Artists 预览</div>
                <div className="mt-3 space-y-2">
                  {draft.lineupArtists.length ? (
                    draft.lineupArtists.map((artist) => (
                      <div key={artist.id} className="rounded-xl border border-border-secondary bg-bg-tertiary/50 px-3 py-2 text-sm">
                        <div className="font-medium text-text-primary">
                          {artist.memberNamesText || artist.djId || '未命名艺人'}
                        </div>
                        <div className="mt-1 text-xs text-text-secondary">
                          sort: {artist.sortOrder}{artist.canonicalArtistId ? ` · canonical: ${artist.canonicalArtistId}` : ''}
                        </div>
                      </div>
                    ))
                  ) : (
                    <div className="text-sm text-text-secondary">当前还没有可提交的阵容艺人。</div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </Section>

      <Section title="媒体" description="当前先接入封面/海报与阵容图上传，图片会直接走 `/v1/events/upload-image`。后续会扩展到与 iOS 对齐的完整六分区资产模型。">
        <div className="grid gap-5 lg:grid-cols-2">
          <div className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 p-4">
            <Field label="封面 / 海报" error={errors.coverImage}>
              <label className="flex cursor-pointer flex-col gap-3 rounded-2xl border border-dashed border-border-secondary bg-bg-primary/20 p-4">
                {draft.coverImage?.remoteUrl ? (
                  <div className="relative aspect-video overflow-hidden rounded-xl border border-border-secondary">
                    <Image src={draft.coverImage.remoteUrl} alt="cover" fill className="object-cover" sizes="800px" />
                  </div>
                ) : (
                  <div className="flex aspect-video items-center justify-center rounded-xl border border-border-secondary bg-bg-secondary text-sm text-text-secondary">
                    还没有上传封面
                  </div>
                )}
                <div className="flex items-center justify-between">
                  <span className="text-sm text-text-secondary">{uploadingCover ? '上传中...' : '选择并上传图片'}</span>
                  <input type="file" accept="image/*" className="hidden" onChange={(event) => void handleImageUpload(event, 'cover')} />
                  <span className="rounded-lg border border-border-secondary px-3 py-2 text-xs">上传</span>
                </div>
              </label>
            </Field>
          </div>

          <div className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 p-4">
            <Field label="阵容图（可选）">
              <label className="flex cursor-pointer flex-col gap-3 rounded-2xl border border-dashed border-border-secondary bg-bg-primary/20 p-4">
                {draft.lineupImage?.remoteUrl ? (
                  <div className="relative aspect-video overflow-hidden rounded-xl border border-border-secondary">
                    <Image src={draft.lineupImage.remoteUrl} alt="lineup" fill className="object-cover" sizes="800px" />
                  </div>
                ) : (
                  <div className="flex aspect-video items-center justify-center rounded-xl border border-border-secondary bg-bg-secondary text-sm text-text-secondary">
                    还没有上传阵容图
                  </div>
                )}
                <div className="flex items-center justify-between">
                  <span className="text-sm text-text-secondary">{uploadingLineup ? '上传中...' : '选择并上传图片'}</span>
                  <input type="file" accept="image/*" className="hidden" onChange={(event) => void handleImageUpload(event, 'lineup')} />
                  <span className="rounded-lg border border-border-secondary px-3 py-2 text-xs">上传</span>
                </div>
              </label>
            </Field>
          </div>
        </div>
      </Section>

      <Section title="提交" description="当前版本会根据后端返回结果显示两种状态：直接创建成功/直接更新成功，或提交进入审核队列。编辑态现在已经切到真实 PATCH 提交链路。">
        <div className="flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={() => void handleSubmit()}
            disabled={submitting || uploadingCover || uploadingLineup || !canSubmit}
            className="rounded-xl bg-primary-blue px-5 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
          >
            {submitting ? '提交中...' : submitButtonText || (mode === 'create' ? '提交活动' : '提交编辑')}
          </button>
          <Link href="/admin/content/events" className="rounded-xl border border-border-secondary px-5 py-3 text-sm hover:border-primary-blue hover:text-primary-blue">
            先返回工作区
          </Link>
        </div>
      </Section>
    </div>
  );
}
