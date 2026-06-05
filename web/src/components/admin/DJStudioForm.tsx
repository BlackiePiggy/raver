'use client';

import Link from 'next/link';
import Image from 'next/image';
import { ChangeEvent, useEffect, useMemo, useState } from 'react';
import { Plus, Trash2 } from 'lucide-react';
import { LocalizedTextField, MultilingualEditorOverlay, type LocalizedFieldKind, type LocalizedLocaleKey } from '@/components/admin/LocalizedTextEditor';
import { notificationCenterAdminApi } from '@/lib/api/notification-center-admin';
import { INPUT_LIMITS, countText } from '@/lib/input-rules';
import {
  djStudioApi,
  mapDJStudioDraftToCreateInput,
  mapDJStudioDraftToUpdateInput,
  validateDJStudioDraft,
  type DJStudioCreateResult,
  type DJStudioDraft,
  type DJStudioValidationErrors,
} from '@/features/admin-content/dj-studio';

const DJ_STUDIO_STEPS = [
  { key: 'profile', eyebrow: '第 1 步', title: '资料', description: '身份、多语言、图片、别名和风格' },
  { key: 'links', eyebrow: '第 2 步', title: '平台', description: '官方链接、平台 ID 和统计' },
  { key: 'review', eyebrow: '第 3 步', title: '检查', description: '最终核对并提交' },
] as const;

type DJStudioStepKey = (typeof DJ_STUDIO_STEPS)[number]['key'];
type DJLocalizedFieldKey = 'name' | 'bio' | 'country';

type DJLocalizedFieldOverlayState = {
  key: DJLocalizedFieldKey;
  label: string;
  kind: LocalizedFieldKind;
};

const STEP_ERROR_KEYS: Record<DJStudioStepKey, Array<keyof DJStudioValidationErrors>> = {
  profile: ['name', 'avatarImage'],
  links: ['links', 'stats'],
  review: ['name', 'avatarImage', 'links', 'stats'],
};

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
  children: React.ReactNode;
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

function SummaryCard({
  label,
  value,
  tone = 'soft',
}: {
  label: string;
  value: string;
  tone?: 'mint' | 'sand' | 'rose' | 'soft';
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
    <div className="grid gap-3 xl:grid-cols-3">
      {DJ_STUDIO_STEPS.map((item, index) => {
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

function ImageDropZone({
  label,
  previewUrl,
  uploading,
  onChange,
  onRemove,
}: {
  label: string;
  previewUrl?: string | null;
  uploading: boolean;
  onChange: (event: ChangeEvent<HTMLInputElement>) => void;
  onRemove?: () => void;
}) {
  return (
    <div className="admin-studio-soft w-full max-w-[220px] p-4">
      <div className="flex items-center justify-between gap-3">
        <p className="text-sm font-medium text-[#071110]">{label}</p>
        {previewUrl && onRemove ? (
          <button type="button" onClick={onRemove} className="text-xs text-black/48">
            移除
          </button>
        ) : null}
      </div>
      <div className="relative mt-3 aspect-square overflow-hidden rounded-[20px] border border-[#e8eceb] bg-[linear-gradient(135deg,#edf7f2,#f7efda)]">
        {previewUrl ? (
          <Image src={previewUrl} alt={label} fill className="object-cover" sizes="220px" />
        ) : (
          <div className="flex h-full items-center justify-center px-4 text-center text-sm text-black/42">暂无图片</div>
        )}
      </div>
      <label className="admin-studio-button-secondary mt-4 flex cursor-pointer items-center justify-center px-4 py-3 text-sm">
        {uploading ? '上传中...' : '上传图片'}
        <input type="file" accept="image/*" className="hidden" onChange={onChange} />
      </label>
    </div>
  );
}

function DynamicStringListField({
  label,
  items,
  placeholder,
  onChange,
  onAdd,
  onRemove,
  hint,
  itemMax,
  maxItems,
}: {
  label: string;
  items: string[];
  placeholder: string;
  onChange: (index: number, value: string) => void;
  onAdd: () => void;
  onRemove: (index: number) => void;
  hint?: string;
  itemMax: number;
  maxItems: number;
}) {
  const combinedHint = [hint, `已填写 ${countFilledItems(items)}/${maxItems} 项，每项最多 ${itemMax} 个字符`]
    .filter(Boolean)
    .join(' ');

  return (
    <Field label={label} hint={combinedHint}>
      <div className="space-y-3">
        {items.map((item, index) => (
          <div key={`${label}-${index}`} className="flex items-start gap-2">
            <div className="min-w-0 flex-1">
              <input
                value={item}
                onChange={(event) => onChange(index, event.target.value)}
                className="admin-studio-input"
                placeholder={placeholder}
                maxLength={itemMax}
              />
              <div className="mt-2 text-xs text-black/40">{countText(item)}/{itemMax}</div>
            </div>
            <button
              type="button"
              onClick={() => onRemove(index)}
              className="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-black/48 hover:text-[#071110]"
              aria-label={`删除${label}${index + 1}`}
            >
              <Trash2 className="h-4 w-4" />
            </button>
          </div>
        ))}
        <button
          type="button"
          onClick={onAdd}
          disabled={items.length >= maxItems}
          className="inline-flex items-center gap-2 rounded-full border border-[#d9e7dd] bg-[#f6fbf7] px-4 py-2 text-sm font-semibold text-[#071110]"
        >
          <Plus className="h-4 w-4" />
          添加一行
        </button>
      </div>
    </Field>
  );
}

const textInputClassName = 'admin-studio-input';

const firstFilledText = (...values: Array<string | undefined | null>) => {
  for (const value of values) {
    const trimmed = String(value || '').trim();
    if (trimmed) return trimmed;
  }
  return '';
};

const countFilledItems = (items: string[]) => items.map((item) => item.trim()).filter(Boolean).length;
const commonUrlHint = (value: string) => `${countText(value)}/${INPUT_LIMITS.common.url}`;
const commonIdHint = (value: string) => `${countText(value)}/${INPUT_LIMITS.common.externalId}`;

type DJStudioFormProps = {
  mode: 'create' | 'edit';
  djId?: string;
  draft: DJStudioDraft;
  setDraft: React.Dispatch<React.SetStateAction<DJStudioDraft>>;
  onSubmit: (result: DJStudioCreateResult) => void;
  submitButtonText?: string;
};

export default function DJStudioForm({
  mode,
  djId,
  draft,
  setDraft,
  onSubmit,
  submitButtonText,
}: DJStudioFormProps) {
  const [errors, setErrors] = useState<DJStudioValidationErrors>({});
  const [currentStep, setCurrentStep] = useState(0);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [uploadingBanner, setUploadingBanner] = useState(false);
  const [uploadingProof, setUploadingProof] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [activeLocalizedField, setActiveLocalizedField] = useState<DJLocalizedFieldOverlayState | null>(null);

  useEffect(() => {
    if (!activeLocalizedField) return;
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setActiveLocalizedField(null);
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [activeLocalizedField]);

  const canSubmit = useMemo(() => Object.keys(validateDJStudioDraft(draft)).length === 0, [draft]);
  const currentStepItem = DJ_STUDIO_STEPS[currentStep];
  const totalSteps = DJ_STUDIO_STEPS.length;
  const displayName = firstFilledText(draft.name.zh, draft.name.en, draft.name.ja, draft.name.enFull) || 'DJ 草稿';
  const hasPlatformLink = [
    draft.spotifyUrl,
    draft.instagramUrl,
    draft.facebookUrl,
    draft.soundcloudUrl,
    draft.twitterUrl,
    draft.youtubeUrl,
    draft.neteaseUrl,
    draft.qqMusicUrl,
    draft.website,
    draft.otherPlatformUrl,
  ].some((item) => item.trim());
  const activeLocalizedValue = activeLocalizedField ? draft[activeLocalizedField.key] : null;

  const goToStep = (index: number) => {
    setCurrentStep(Math.max(0, Math.min(index, totalSteps - 1)));
  };

  const getStepForErrors = (nextErrors: DJStudioValidationErrors): number => {
    for (let index = 0; index < DJ_STUDIO_STEPS.length; index += 1) {
      const step = DJ_STUDIO_STEPS[index];
      if (STEP_ERROR_KEYS[step.key].some((key) => nextErrors[key])) return index;
    }
    return currentStep;
  };

  const currentStepHasBlockingErrors = (nextErrors: DJStudioValidationErrors) => {
    const step = DJ_STUDIO_STEPS[currentStep];
    return STEP_ERROR_KEYS[step.key].some((key) => nextErrors[key]);
  };

  const updateDraft = <K extends keyof DJStudioDraft>(key: K, value: DJStudioDraft[K]) => {
    setDraft((current) => ({ ...current, [key]: value }));
    setErrors((current) => {
      if (!current[key as keyof DJStudioValidationErrors]) return current;
      const next = { ...current };
      delete next[key as keyof DJStudioValidationErrors];
      return next;
    });
  };

  const updateLocalizedField = (key: DJLocalizedFieldKey, locale: LocalizedLocaleKey, value: string) => {
    setDraft((current) => ({
      ...current,
      [key]: {
        ...current[key],
        [locale]: value,
      },
    }));
    setErrors((current) => {
      if (!current[key as keyof DJStudioValidationErrors]) return current;
      const next = { ...current };
      delete next[key as keyof DJStudioValidationErrors];
      return next;
    });
  };

  const updateStringList = (key: 'aliases' | 'genres', updater: (current: string[]) => string[]) => {
    setDraft((current) => ({
      ...current,
      [key]: updater(current[key]),
    }));
  };

  const handleListChange = (key: 'aliases' | 'genres', index: number, value: string) => {
    updateStringList(key, (current) => current.map((item, itemIndex) => (itemIndex === index ? value : item)));
  };

  const handleListAdd = (key: 'aliases' | 'genres') => {
    updateStringList(key, (current) => {
      const maxItems = key === 'aliases' ? INPUT_LIMITS.dj.aliasesMaxItems : INPUT_LIMITS.dj.genresMaxItems;
      return current.length >= maxItems ? current : [...current, ''];
    });
  };

  const handleListRemove = (key: 'aliases' | 'genres', index: number) => {
    updateStringList(key, (current) => {
      const next = current.filter((_, itemIndex) => itemIndex !== index);
      return next.length ? next : [''];
    });
  };

  const handleImageUpload = async (event: ChangeEvent<HTMLInputElement>, usage: 'avatar' | 'banner' | 'proof') => {
    const file = event.target.files?.[0];
    if (!file) return;

    try {
      setSubmitError(null);
      if (usage === 'avatar') setUploadingAvatar(true);
      if (usage === 'banner') setUploadingBanner(true);
      if (usage === 'proof') setUploadingProof(true);

      const uploaded = await djStudioApi.uploadImage(file, {
        usage,
        draftId: draft.id,
      });
      const nextImage = {
        remoteUrl: uploaded.originalUrl || uploaded.url,
        fileName: uploaded.fileName || file.name,
        usage,
        origin: 'draft-upload' as const,
      };

      if (usage === 'avatar') updateDraft('avatarImage', nextImage);
      if (usage === 'banner') updateDraft('bannerImage', nextImage);
      if (usage === 'proof') updateDraft('proofImage', nextImage);
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : 'DJ 图片上传失败');
    } finally {
      if (usage === 'avatar') setUploadingAvatar(false);
      if (usage === 'banner') setUploadingBanner(false);
      if (usage === 'proof') setUploadingProof(false);
      event.target.value = '';
    }
  };

  const handleRemoveImage = async (usage: 'avatar' | 'banner' | 'proof') => {
    const currentImage =
      usage === 'avatar' ? draft.avatarImage : usage === 'banner' ? draft.bannerImage : draft.proofImage;
    if (!currentImage) return;

    try {
      setSubmitError(null);
      if (currentImage.origin === 'draft-upload') {
        await djStudioApi.deleteDraftImages({
          draftId: draft.id,
          urls: [currentImage.remoteUrl],
        });
      }
      if (usage === 'avatar') updateDraft('avatarImage', null);
      if (usage === 'banner') updateDraft('bannerImage', null);
      if (usage === 'proof') updateDraft('proofImage', null);
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '删除 DJ 图片失败');
    }
  };

  const handleAdvance = () => {
    const nextErrors = validateDJStudioDraft(draft);
    setErrors(nextErrors);
    setSubmitError(null);
    if (currentStepHasBlockingErrors(nextErrors)) {
      setSubmitError('当前分页还有必填项未完成，请先补齐后再继续。');
      return;
    }
    goToStep(currentStep + 1);
  };

  const handleSubmit = async () => {
    const nextErrors = validateDJStudioDraft(draft);
    setErrors(nextErrors);
    setSubmitError(null);
    if (Object.keys(nextErrors).length > 0) {
      goToStep(getStepForErrors(nextErrors));
      return;
    }

    try {
      setSubmitting(true);
      const result =
        mode === 'edit' && djId
          ? await djStudioApi.updateDJ(djId, mapDJStudioDraftToUpdateInput(draft))
          : await djStudioApi.createDJ(mapDJStudioDraftToCreateInput(draft));
      onSubmit(result);
    } catch (error) {
      await notificationCenterAdminApi
        .logContentHistoryFailure({
          entityType: 'dj',
          entityId: djId ?? null,
          taskType: 'dj_release',
          operationType: mode === 'edit' ? 'edit' : 'create',
          title: displayName || (mode === 'edit' ? 'DJ 编辑失败' : 'DJ 创建失败'),
          summary: draft.bio.zh || draft.bio.en || draft.bio.ja || draft.bio.enFull || null,
          sourceRoute: mode === 'edit' && djId ? `/admin/content/djs/${djId}/edit` : '/admin/content/djs/new',
          errorMessage: error instanceof Error ? error.message : 'DJ 提交失败',
          payload: {
            name: draft.name,
            country: draft.country,
          },
        })
        .catch(() => undefined);
      setSubmitError(error instanceof Error ? error.message : 'DJ 提交失败');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-5">
      {submitError ? <section className="admin-studio-pastel-rose p-4 text-sm text-[#6a3530]">{submitError}</section> : null}

      <section className="grid gap-4 xl:grid-cols-[1.35fr_0.9fr]">
        <div className="admin-studio-section p-6">
          <div className="admin-studio-label">{mode === 'create' ? 'DJ 工作台' : '编辑 DJ'}</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">{displayName}</h2>
          <div className="mt-5 grid gap-3 md:grid-cols-4">
            <SummaryCard label="头像" value={draft.avatarImage ? '已上传' : '待上传'} tone="mint" />
            <SummaryCard label="平台链接" value={hasPlatformLink ? '已填写' : '待补齐'} tone="sand" />
            <SummaryCard label="证明图" value={draft.proofImage ? '已上传' : '可选'} tone="rose" />
            <SummaryCard label="当前步骤" value={`${currentStep + 1}/${totalSteps} / ${currentStepItem.title}`} />
          </div>
        </div>

        <div className="admin-studio-pastel-mint p-6">
          <div className="admin-studio-label">流程对齐</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">资料优先</h2>
          <p className="mt-4 text-sm leading-6 text-black/52">
            Web 端 DJ 编辑现在先集中处理资料和身份，再进入平台链接和最终检查。多语言字段统一采用和 event 一样的按钮打开 overlay 编辑。
          </p>
        </div>
      </section>

      <StepNavigation currentStep={currentStep} onSelect={goToStep} />

      {currentStep === 0 ? (
        <Section title="DJ 资料" description="集中编辑 DJ 名称、多语言文案、图片、别名和 Genres。">
          <div className="grid gap-4 lg:grid-cols-2">
            <div className="lg:col-span-2">
              <LocalizedTextField
                label="DJ 名称"
                value={draft.name}
                kind="input"
                error={errors.name}
                placeholder="例如：Martin Garrix"
                hint="主输入默认编辑中文。"
                maxLength={INPUT_LIMITS.dj.name}
                onPrimaryChange={(value) => updateLocalizedField('name', 'zh', value)}
                onOpenOverlay={() => setActiveLocalizedField({ key: 'name', label: 'DJ 名称', kind: 'input' })}
              />
            </div>

            <div className="lg:col-span-2">
              <Field label="图片素材" error={errors.avatarImage} hint="头像、横幅和证明图都使用更紧凑的正方形素材卡片管理。">
                <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                  <ImageDropZone
                    label="头像"
                    previewUrl={draft.avatarImage?.remoteUrl}
                    uploading={uploadingAvatar}
                    onChange={(event) => void handleImageUpload(event, 'avatar')}
                    onRemove={() => void handleRemoveImage('avatar')}
                  />
                  <ImageDropZone
                    label="横幅"
                    previewUrl={draft.bannerImage?.remoteUrl}
                    uploading={uploadingBanner}
                    onChange={(event) => void handleImageUpload(event, 'banner')}
                    onRemove={() => void handleRemoveImage('banner')}
                  />
                  <ImageDropZone
                    label="证明图"
                    previewUrl={draft.proofImage?.remoteUrl}
                    uploading={uploadingProof}
                    onChange={(event) => void handleImageUpload(event, 'proof')}
                    onRemove={() => void handleRemoveImage('proof')}
                  />
                </div>
              </Field>
            </div>

            <DynamicStringListField
              label="别名"
              items={draft.aliases}
              placeholder="例如：Ytram"
              hint="每点击一次加号按钮新增一行。"
              itemMax={INPUT_LIMITS.dj.alias}
              maxItems={INPUT_LIMITS.dj.aliasesMaxItems}
              onChange={(index, value) => handleListChange('aliases', index, value)}
              onAdd={() => handleListAdd('aliases')}
              onRemove={(index) => handleListRemove('aliases', index)}
            />

            <DynamicStringListField
              label="风格（Genres）"
              items={draft.genres}
              placeholder="例如：Progressive House"
              hint="风格也按显式加号新增，不再依赖换行。"
              itemMax={INPUT_LIMITS.dj.genre}
              maxItems={INPUT_LIMITS.dj.genresMaxItems}
              onChange={(index, value) => handleListChange('genres', index, value)}
              onAdd={() => handleListAdd('genres')}
              onRemove={(index) => handleListRemove('genres', index)}
            />

            <LocalizedTextField
              label="国家 / 地区"
              value={draft.country}
              kind="input"
              placeholder="例如：荷兰"
              maxLength={INPUT_LIMITS.dj.country}
              onPrimaryChange={(value) => updateLocalizedField('country', 'zh', value)}
              onOpenOverlay={() => setActiveLocalizedField({ key: 'country', label: '国家 / 地区', kind: 'input' })}
            />

            <div className="lg:col-span-2">
              <LocalizedTextField
                label="简介"
                value={draft.bio}
                kind="textarea"
                placeholder="DJ 简介、风格、代表经历等"
                maxLength={INPUT_LIMITS.dj.bio}
                onPrimaryChange={(value) => updateLocalizedField('bio', 'zh', value)}
                onOpenOverlay={() => setActiveLocalizedField({ key: 'bio', label: '简介', kind: 'textarea' })}
              />
            </div>
          </div>
        </Section>
      ) : null}

      {currentStep === 1 ? (
        <Section title="平台链接" description="尽量补齐官方平台入口和关键统计。证明图作为素材已经统一放在资料页管理。">
          <div className="grid gap-4 lg:grid-cols-2">
            <Field label="Spotify 编号" hint={commonIdHint(draft.spotifyId)}>
              <input value={draft.spotifyId} onChange={(event) => updateDraft('spotifyId', event.target.value)} className={textInputClassName} placeholder="spotify artist id" maxLength={INPUT_LIMITS.common.externalId} />
            </Field>
            <Field label="Spotify 链接" error={errors.links} hint={commonUrlHint(draft.spotifyUrl)}>
              <input value={draft.spotifyUrl} onChange={(event) => updateDraft('spotifyUrl', event.target.value)} className={textInputClassName} placeholder="https://open.spotify.com/artist/..." maxLength={INPUT_LIMITS.common.url} />
            </Field>
            <Field label="Apple Music 编号" hint={commonIdHint(draft.appleMusicId)}>
              <input value={draft.appleMusicId} onChange={(event) => updateDraft('appleMusicId', event.target.value)} className={textInputClassName} placeholder="apple music id" maxLength={INPUT_LIMITS.common.externalId} />
            </Field>
            <Field label="Instagram 链接" hint={commonUrlHint(draft.instagramUrl)}>
              <input value={draft.instagramUrl} onChange={(event) => updateDraft('instagramUrl', event.target.value)} className={textInputClassName} placeholder="https://instagram.com/..." maxLength={INPUT_LIMITS.common.url} />
            </Field>
            <Field label="Facebook 链接" hint={commonUrlHint(draft.facebookUrl)}>
              <input value={draft.facebookUrl} onChange={(event) => updateDraft('facebookUrl', event.target.value)} className={textInputClassName} placeholder="https://facebook.com/..." maxLength={INPUT_LIMITS.common.url} />
            </Field>
            <Field label="SoundCloud 链接" hint={commonUrlHint(draft.soundcloudUrl)}>
              <input value={draft.soundcloudUrl} onChange={(event) => updateDraft('soundcloudUrl', event.target.value)} className={textInputClassName} placeholder="https://soundcloud.com/..." maxLength={INPUT_LIMITS.common.url} />
            </Field>
            <Field label="SoundCloud 编号" hint={commonIdHint(draft.soundcloudId)}>
              <input value={draft.soundcloudId} onChange={(event) => updateDraft('soundcloudId', event.target.value)} className={textInputClassName} placeholder="soundcloud user id" maxLength={INPUT_LIMITS.common.externalId} />
            </Field>
            <Field label="X / Twitter 链接" hint={commonUrlHint(draft.twitterUrl)}>
              <input value={draft.twitterUrl} onChange={(event) => updateDraft('twitterUrl', event.target.value)} className={textInputClassName} placeholder="https://x.com/..." maxLength={INPUT_LIMITS.common.url} />
            </Field>
            <Field label="YouTube 链接" hint={commonUrlHint(draft.youtubeUrl)}>
              <input value={draft.youtubeUrl} onChange={(event) => updateDraft('youtubeUrl', event.target.value)} className={textInputClassName} placeholder="https://youtube.com/..." maxLength={INPUT_LIMITS.common.url} />
            </Field>
            <Field label="网易云 URL" hint={commonUrlHint(draft.neteaseUrl)}>
              <input value={draft.neteaseUrl} onChange={(event) => updateDraft('neteaseUrl', event.target.value)} className={textInputClassName} placeholder="https://music.163.com/..." maxLength={INPUT_LIMITS.common.url} />
            </Field>
            <Field label="QQ 音乐 URL" hint={commonUrlHint(draft.qqMusicUrl)}>
              <input value={draft.qqMusicUrl} onChange={(event) => updateDraft('qqMusicUrl', event.target.value)} className={textInputClassName} placeholder="https://y.qq.com/..." maxLength={INPUT_LIMITS.common.url} />
            </Field>
            <Field label="官网 URL" hint={commonUrlHint(draft.website)}>
              <input value={draft.website} onChange={(event) => updateDraft('website', event.target.value)} className={textInputClassName} placeholder="https://..." maxLength={INPUT_LIMITS.common.url} />
            </Field>
            <Field label="其他平台 URL" hint={commonUrlHint(draft.otherPlatformUrl)}>
              <input value={draft.otherPlatformUrl} onChange={(event) => updateDraft('otherPlatformUrl', event.target.value)} className={textInputClassName} placeholder="其他平台链接" maxLength={INPUT_LIMITS.common.url} />
            </Field>
            <Field label="Spotify Followers" error={errors.stats}>
              <input value={draft.spotifyFollowers} onChange={(event) => updateDraft('spotifyFollowers', event.target.value)} className={textInputClassName} placeholder="123456" />
            </Field>
            <Field label="曲目数" error={errors.stats}>
              <input value={draft.trackCount} onChange={(event) => updateDraft('trackCount', event.target.value)} className={textInputClassName} placeholder="0" />
            </Field>
            <Field label="歌单数" error={errors.stats}>
              <input value={draft.playlistCount} onChange={(event) => updateDraft('playlistCount', event.target.value)} className={textInputClassName} placeholder="0" />
            </Field>
            <Field label="SoundCloud 粉丝数" error={errors.stats}>
              <input value={draft.soundCloudFollowers} onChange={(event) => updateDraft('soundCloudFollowers', event.target.value)} className={textInputClassName} placeholder="0" />
            </Field>
            <Field label="SoundCloud 收藏数" error={errors.stats}>
              <input value={draft.soundCloudFavorites} onChange={(event) => updateDraft('soundCloudFavorites', event.target.value)} className={textInputClassName} placeholder="0" />
            </Field>
          </div>
        </Section>
      ) : null}
      {currentStep === 2 ? (
        <Section title="最终检查" description="提交前确认核心资料、素材和平台链接是否完整。">
          <div className="grid gap-4 xl:grid-cols-2">
            <div className="admin-reference-card p-4">
              <div className="text-sm font-semibold text-[#071110]">资料摘要</div>
                <div className="mt-4 grid gap-3 md:grid-cols-2">
                <SummaryCard label="名称" value={displayName} />
                <SummaryCard label="头像" value={draft.avatarImage ? '已上传到 OSS' : '待补充'} tone={draft.avatarImage ? 'mint' : 'rose'} />
                <SummaryCard label="平台链接" value={hasPlatformLink ? '已填写' : '待补充'} tone={hasPlatformLink ? 'mint' : 'sand'} />
                <SummaryCard label="证明图" value={draft.proofImage ? '已上传' : '未上传'} tone={draft.proofImage ? 'mint' : 'soft'} />
                <SummaryCard label="别名" value={`${countFilledItems(draft.aliases)} 项`} />
                <SummaryCard label="风格" value={`${countFilledItems(draft.genres)} 项`} />
              </div>
            </div>

            <div className="space-y-4">
              <div className="admin-studio-pastel-mint p-5">
                <div className="admin-studio-label">准备提交</div>
                <div className="mt-2 text-lg font-semibold text-[#071110]">
                  {canSubmit ? '当前 DJ 信息已经可以提交' : '还有字段未完成，请先补齐'}
                </div>
                <div className="mt-3 text-sm leading-6 text-black/52">
                  {mode === 'create' ? '提交后会创建新的 DJ 内容记录。' : '提交后会进入 DJ 编辑审核或更新流程。'}
                </div>
              </div>
              {Object.values(errors)
                .filter(Boolean)
                .map((error) => (
                  <div key={error} className="admin-studio-pastel-rose px-4 py-3 text-sm text-[#6a3530]">
                    {error}
                  </div>
                ))}
            </div>
          </div>
        </Section>
      ) : null}

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
        {currentStep < totalSteps - 1 ? (
          <button type="button" onClick={handleAdvance} className="admin-studio-button-primary px-5 py-3 text-sm">
            下一步
          </button>
        ) : (
          <div className="flex flex-wrap gap-3">
            <Link href="/admin/content/djs/catalog" className="admin-studio-button-secondary px-5 py-3 text-sm">
              返回 DJ 目录
            </Link>
            <button
              type="button"
              onClick={() => void handleSubmit()}
              disabled={submitting || uploadingAvatar || uploadingBanner || uploadingProof}
              className="admin-studio-button-primary px-5 py-3 text-sm disabled:cursor-not-allowed disabled:opacity-60"
            >
              {submitting ? '提交中...' : submitButtonText || (mode === 'create' ? '提交 DJ' : '提交编辑')}
            </button>
          </div>
        )}
      </section>

      <MultilingualEditorOverlay
        open={Boolean(activeLocalizedField && activeLocalizedValue)}
        title={activeLocalizedField?.label ?? ''}
        kind={activeLocalizedField?.kind ?? 'input'}
        value={activeLocalizedValue ?? { zh: '', en: '', ja: '', enFull: '' }}
        maxLength={
          activeLocalizedField?.key === 'name'
            ? INPUT_LIMITS.dj.name
            : activeLocalizedField?.key === 'country'
              ? INPUT_LIMITS.dj.country
              : INPUT_LIMITS.dj.bio
        }
        onChange={(locale, value) => {
          if (!activeLocalizedField) return;
          updateLocalizedField(activeLocalizedField.key, locale, value);
        }}
        onClose={() => setActiveLocalizedField(null)}
      />
    </div>
  );
}
