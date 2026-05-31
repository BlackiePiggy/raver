'use client';

import Link from 'next/link';
import Image from 'next/image';
import { ChangeEvent, useMemo, useState } from 'react';
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
  { key: 'identity', eyebrow: 'Step 1', title: '身份', description: 'DJ 名称、主头像与 Banner' },
  { key: 'profile', eyebrow: 'Step 2', title: '资料', description: '别名、Genres、国家与简介' },
  { key: 'links', eyebrow: 'Step 3', title: '平台', description: '官方链接、平台 ID、统计与 Proof' },
  { key: 'review', eyebrow: 'Step 4', title: '检查', description: '最终核对后提交' },
] as const;

type DJStudioStepKey = (typeof DJ_STUDIO_STEPS)[number]['key'];

const STEP_ERROR_KEYS: Record<DJStudioStepKey, Array<keyof DJStudioValidationErrors>> = {
  identity: ['name', 'avatarImage'],
  profile: [],
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
  children,
}: {
  label: string;
  error?: string;
  children: React.ReactNode;
}) {
  return (
    <label className="block">
      <div className="mb-2 admin-studio-label">{label}</div>
      {children}
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
    <div className="grid gap-3 xl:grid-cols-4">
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
    <div className="admin-studio-soft p-4">
      <div className="flex items-center justify-between gap-3">
        <p className="text-sm text-black/48">{label}</p>
        {previewUrl && onRemove ? (
          <button type="button" onClick={onRemove} className="text-xs text-black/48">
            移除
          </button>
        ) : null}
      </div>
      {previewUrl ? (
        <div className="relative mt-3 aspect-video overflow-hidden rounded-[20px] border border-[#e8eceb]">
          <Image src={previewUrl} alt={label} fill className="object-cover" sizes="640px" />
        </div>
      ) : (
        <div className="mt-3 flex aspect-video items-center justify-center rounded-[20px] bg-[linear-gradient(135deg,#edf7f2,#f7efda)] text-sm text-black/42">
          暂无图片
        </div>
      )}
      <label className="admin-studio-button-secondary mt-4 cursor-pointer px-4 py-3 text-sm">
        {uploading ? '上传中...' : '上传图片'}
        <input type="file" accept="image/*" className="hidden" onChange={onChange} />
      </label>
    </div>
  );
}

const textInputClassName = 'admin-studio-input';
const textAreaClassName = 'admin-studio-textarea min-h-28';

const firstFilledText = (...values: Array<string | undefined | null>) => {
  for (const value of values) {
    const trimmed = String(value || '').trim();
    if (trimmed) return trimmed;
  }
  return '';
};

const splitLinesForDisplay = (value: string) =>
  value
    .split(/[\n,]/)
    .map((item) => item.trim())
    .filter(Boolean);

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

  const canSubmit = useMemo(
    () => Object.keys(validateDJStudioDraft(draft)).length === 0,
    [draft]
  );
  const currentStepItem = DJ_STUDIO_STEPS[currentStep];
  const totalSteps = DJ_STUDIO_STEPS.length;
  const displayName = firstFilledText(draft.name.zh, draft.name.en, draft.name.ja, draft.name.enFull) || 'DJ 资料草稿';
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

  const goToStep = (index: number) => {
    setCurrentStep(Math.max(0, Math.min(index, totalSteps - 1)));
  };

  const getStepForErrors = (nextErrors: DJStudioValidationErrors): number => {
    for (let index = 0; index < DJ_STUDIO_STEPS.length; index += 1) {
      const step = DJ_STUDIO_STEPS[index];
      if (STEP_ERROR_KEYS[step.key].some((key) => nextErrors[key])) {
        return index;
      }
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

  const updateLocalizedField = (
    key: 'name' | 'bio' | 'country',
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
      if (!current[key as keyof DJStudioValidationErrors]) return current;
      const next = { ...current };
      delete next[key as keyof DJStudioValidationErrors];
      return next;
    });
  };

  const handleImageUpload = async (
    event: ChangeEvent<HTMLInputElement>,
    usage: 'avatar' | 'banner' | 'proof'
  ) => {
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
      usage === 'avatar'
        ? draft.avatarImage
        : usage === 'banner'
          ? draft.bannerImage
          : draft.proofImage;
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
      setSubmitError(error instanceof Error ? error.message : 'DJ 提交失败');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-5">
      {submitError ? (
        <section className="admin-studio-pastel-rose p-4 text-sm text-[#6a3530]">
          {submitError}
        </section>
      ) : null}

      <section className="grid gap-4 xl:grid-cols-[1.35fr_0.9fr]">
        <div className="admin-studio-section p-6">
          <div className="admin-studio-label">{mode === 'create' ? 'DJ Studio' : 'Edit DJ Session'}</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">{displayName}</h2>
          <div className="mt-5 grid gap-3 md:grid-cols-4">
            <SummaryCard label="头像" value={draft.avatarImage ? '已上传' : '待上传'} tone="mint" />
            <SummaryCard label="平台链接" value={hasPlatformLink ? '已填写' : '待补齐'} tone="sand" />
            <SummaryCard label="Proof" value={draft.proofImage ? '已上传' : '可选'} tone="rose" />
            <SummaryCard label="当前分页" value={`${currentStep + 1}/${totalSteps} · ${currentStepItem.title}`} />
          </div>
        </div>

        <div className="admin-studio-pastel-mint p-6">
          <div className="admin-studio-label">iOS Flow</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">4 步上传节奏</h2>
          <p className="mt-4 text-sm leading-6 text-black/52">
            Web 端现在按 iOS DJUploadFlow 的顺序拆分为身份、资料、平台、检查。每一步只处理当前上下文，最后统一校验并提交。
          </p>
        </div>
      </section>

      <StepNavigation currentStep={currentStep} onSelect={goToStep} />

      {currentStep === 0 ? (
        <Section title="DJ 身份" description="先确认 DJ 名称和核心视觉。头像是必填，Banner 可选。">
          <div className="grid gap-4 lg:grid-cols-2">
            <Field label="DJ 名称（中文）" error={errors.name}>
              <input value={draft.name.zh} onChange={(event) => updateLocalizedField('name', 'zh', event.target.value)} className={textInputClassName} placeholder="例如：Martin Garrix" />
            </Field>
            <Field label="DJ 名称（英文）">
              <input value={draft.name.en} onChange={(event) => updateLocalizedField('name', 'en', event.target.value)} className={textInputClassName} placeholder="English name" />
            </Field>
            <Field label="DJ 名称（日文，可选）">
              <input value={draft.name.ja} onChange={(event) => updateLocalizedField('name', 'ja', event.target.value)} className={textInputClassName} placeholder="日本語名" />
            </Field>
            <Field label="DJ 英文全称（可选）">
              <input value={draft.name.enFull} onChange={(event) => updateLocalizedField('name', 'enFull', event.target.value)} className={textInputClassName} placeholder="Full English name" />
            </Field>
          </div>

          <div className="mt-6 grid gap-5 lg:grid-cols-2">
            <Field label="头像" error={errors.avatarImage}>
              <ImageDropZone
                label="Avatar"
                previewUrl={draft.avatarImage?.remoteUrl}
                uploading={uploadingAvatar}
                onChange={(event) => void handleImageUpload(event, 'avatar')}
                onRemove={() => void handleRemoveImage('avatar')}
              />
            </Field>
            <Field label="Banner（可选）">
              <ImageDropZone
                label="Banner"
                previewUrl={draft.bannerImage?.remoteUrl}
                uploading={uploadingBanner}
                onChange={(event) => void handleImageUpload(event, 'banner')}
                onRemove={() => void handleRemoveImage('banner')}
              />
            </Field>
          </div>
        </Section>
      ) : null}

      {currentStep === 1 ? (
        <Section title="资料信息" description="补充别名、风格、国家和简介，让 DJ 资料页更完整。">
          <div className="grid gap-4 lg:grid-cols-2">
            <Field label="别名（每行一个）">
              <textarea value={draft.aliasesText} onChange={(event) => updateDraft('aliasesText', event.target.value)} className={textAreaClassName} placeholder="MARTIN GARRIX&#10;Ytram" />
            </Field>
            <Field label="Genres（每行一个）">
              <textarea value={draft.genresText} onChange={(event) => updateDraft('genresText', event.target.value)} className={textAreaClassName} placeholder="Big Room&#10;Progressive House" />
            </Field>
            <Field label="国家/地区（中文）">
              <input value={draft.country.zh} onChange={(event) => updateLocalizedField('country', 'zh', event.target.value)} className={textInputClassName} placeholder="荷兰" />
            </Field>
            <Field label="国家/地区（英文）">
              <input value={draft.country.en} onChange={(event) => updateLocalizedField('country', 'en', event.target.value)} className={textInputClassName} placeholder="Netherlands" />
            </Field>
            <div className="lg:col-span-2">
              <Field label="简介">
                <textarea value={draft.bio.zh} onChange={(event) => updateLocalizedField('bio', 'zh', event.target.value)} className={textAreaClassName} placeholder="DJ 简介、风格、代表经历等" />
              </Field>
            </div>
          </div>
        </Section>
      ) : null}

      {currentStep === 2 ? (
        <Section title="平台链接" description="尽量补齐官方平台入口和关键数据。没有任何平台链接时，需要至少提供一张 proof 图片。">
          <div className="grid gap-4 lg:grid-cols-2">
            <Field label="Spotify ID">
              <input value={draft.spotifyId} onChange={(event) => updateDraft('spotifyId', event.target.value)} className={textInputClassName} placeholder="spotify artist id" />
            </Field>
            <Field label="Spotify URL" error={errors.links}>
              <input value={draft.spotifyUrl} onChange={(event) => updateDraft('spotifyUrl', event.target.value)} className={textInputClassName} placeholder="https://open.spotify.com/artist/..." />
            </Field>
            <Field label="Apple Music ID">
              <input value={draft.appleMusicId} onChange={(event) => updateDraft('appleMusicId', event.target.value)} className={textInputClassName} placeholder="apple music id" />
            </Field>
            <Field label="Instagram URL">
              <input value={draft.instagramUrl} onChange={(event) => updateDraft('instagramUrl', event.target.value)} className={textInputClassName} placeholder="https://instagram.com/..." />
            </Field>
            <Field label="Facebook URL">
              <input value={draft.facebookUrl} onChange={(event) => updateDraft('facebookUrl', event.target.value)} className={textInputClassName} placeholder="https://facebook.com/..." />
            </Field>
            <Field label="SoundCloud URL">
              <input value={draft.soundcloudUrl} onChange={(event) => updateDraft('soundcloudUrl', event.target.value)} className={textInputClassName} placeholder="https://soundcloud.com/..." />
            </Field>
            <Field label="SoundCloud ID">
              <input value={draft.soundcloudId} onChange={(event) => updateDraft('soundcloudId', event.target.value)} className={textInputClassName} placeholder="soundcloud user id" />
            </Field>
            <Field label="Twitter / X URL">
              <input value={draft.twitterUrl} onChange={(event) => updateDraft('twitterUrl', event.target.value)} className={textInputClassName} placeholder="https://x.com/..." />
            </Field>
            <Field label="YouTube URL">
              <input value={draft.youtubeUrl} onChange={(event) => updateDraft('youtubeUrl', event.target.value)} className={textInputClassName} placeholder="https://youtube.com/..." />
            </Field>
            <Field label="网易云 URL">
              <input value={draft.neteaseUrl} onChange={(event) => updateDraft('neteaseUrl', event.target.value)} className={textInputClassName} placeholder="https://music.163.com/..." />
            </Field>
            <Field label="QQ 音乐 URL">
              <input value={draft.qqMusicUrl} onChange={(event) => updateDraft('qqMusicUrl', event.target.value)} className={textInputClassName} placeholder="https://y.qq.com/..." />
            </Field>
            <Field label="官网 URL">
              <input value={draft.website} onChange={(event) => updateDraft('website', event.target.value)} className={textInputClassName} placeholder="https://..." />
            </Field>
            <Field label="其他平台 URL">
              <input value={draft.otherPlatformUrl} onChange={(event) => updateDraft('otherPlatformUrl', event.target.value)} className={textInputClassName} placeholder="其他平台链接" />
            </Field>
            <Field label="Spotify Followers" error={errors.stats}>
              <input value={draft.spotifyFollowers} onChange={(event) => updateDraft('spotifyFollowers', event.target.value)} className={textInputClassName} placeholder="123456" />
            </Field>
            <Field label="Track Count" error={errors.stats}>
              <input value={draft.trackCount} onChange={(event) => updateDraft('trackCount', event.target.value)} className={textInputClassName} placeholder="0" />
            </Field>
            <Field label="Playlist Count" error={errors.stats}>
              <input value={draft.playlistCount} onChange={(event) => updateDraft('playlistCount', event.target.value)} className={textInputClassName} placeholder="0" />
            </Field>
            <Field label="SoundCloud Followers" error={errors.stats}>
              <input value={draft.soundCloudFollowers} onChange={(event) => updateDraft('soundCloudFollowers', event.target.value)} className={textInputClassName} placeholder="0" />
            </Field>
            <Field label="SoundCloud Favorites" error={errors.stats}>
              <input value={draft.soundCloudFavorites} onChange={(event) => updateDraft('soundCloudFavorites', event.target.value)} className={textInputClassName} placeholder="0" />
            </Field>
          </div>

          <div className="mt-6">
            <Field label="Proof（无平台链接时建议上传）" error={errors.links}>
              <ImageDropZone
                label="Proof"
                previewUrl={draft.proofImage?.remoteUrl}
                uploading={uploadingProof}
                onChange={(event) => void handleImageUpload(event, 'proof')}
                onRemove={() => void handleRemoveImage('proof')}
              />
            </Field>
          </div>
        </Section>
      ) : null}

      {currentStep === 3 ? (
        <Section title="检查与提交" description="最后确认关键信息。提交前如果有缺项，会自动跳回对应分页。">
          <div className="grid gap-4 xl:grid-cols-2">
            <div className="admin-reference-card p-4">
              <div className="text-sm font-semibold text-[#071110]">资料摘要</div>
              <div className="mt-4 grid gap-3 md:grid-cols-2">
                <SummaryCard label="名称" value={displayName} />
                <SummaryCard label="头像" value={draft.avatarImage ? '已上传到 OSS' : '未上传'} tone={draft.avatarImage ? 'mint' : 'rose'} />
                <SummaryCard label="平台链接" value={hasPlatformLink ? '已填写' : '未填写'} tone={hasPlatformLink ? 'mint' : 'sand'} />
                <SummaryCard label="Proof" value={draft.proofImage ? '已上传' : '未上传'} tone={draft.proofImage ? 'mint' : 'soft'} />
                <SummaryCard label="别名" value={`${splitLinesForDisplay(draft.aliasesText).length} 个`} />
                <SummaryCard label="Genres" value={`${splitLinesForDisplay(draft.genresText).length} 个`} />
              </div>
            </div>

            <div className="space-y-4">
              <div className="admin-studio-pastel-mint p-5">
                <div className="admin-studio-label">Ready To Submit</div>
                <div className="mt-2 text-lg font-semibold text-[#071110]">
                  {canSubmit ? '当前 DJ 资料已满足提交条件。' : '还有必填项未完成，提交时会自动跳转。'}
                </div>
                <div className="mt-3 text-sm leading-6 text-black/52">
                  {mode === 'create' ? '提交后会创建 DJ，或进入内容审核队列。' : '提交后会保存 DJ 编辑，或进入编辑审核队列。'}
                </div>
              </div>
              {Object.values(errors).filter(Boolean).map((error) => (
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
            <Link href="/admin/content/djs" className="admin-studio-button-secondary px-5 py-3 text-sm">
              返回 DJ 工作区
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
    </div>
  );
}
