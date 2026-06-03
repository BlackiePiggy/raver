'use client';

import Link from 'next/link';
import Image from 'next/image';
import { ChangeEvent, useEffect, useMemo, useState } from 'react';
import { Plus, Trash2 } from 'lucide-react';
import { LocalizedTextField, MultilingualEditorOverlay, type LocalizedFieldKind, type LocalizedLocaleKey } from '@/components/admin/LocalizedTextEditor';
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
  { key: 'profile', eyebrow: 'Step 1', title: '资料', description: '身份、多语言、图片、别名和 Genres' },
  { key: 'links', eyebrow: 'Step 2', title: '平台', description: '官方链接、平台 ID 和统计' },
  { key: 'review', eyebrow: 'Step 3', title: '检查', description: '最终核对并提交' },
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
            绉婚櫎
          </button>
        ) : null}
      </div>
      <div className="relative mt-3 aspect-square overflow-hidden rounded-[20px] border border-[#e8eceb] bg-[linear-gradient(135deg,#edf7f2,#f7efda)]">
        {previewUrl ? (
          <Image src={previewUrl} alt={label} fill className="object-cover" sizes="220px" />
        ) : (
          <div className="flex h-full items-center justify-center px-4 text-center text-sm text-black/42">鏆傛棤鍥剧墖</div>
        )}
      </div>
      <label className="admin-studio-button-secondary mt-4 flex cursor-pointer items-center justify-center px-4 py-3 text-sm">
        {uploading ? '涓婁紶涓?..' : '涓婁紶鍥剧墖'}
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
}: {
  label: string;
  items: string[];
  placeholder: string;
  onChange: (index: number, value: string) => void;
  onAdd: () => void;
  onRemove: (index: number) => void;
  hint?: string;
}) {
  return (
    <Field label={label} hint={hint}>
      <div className="space-y-3">
        {items.map((item, index) => (
          <div key={`${label}-${index}`} className="flex items-center gap-2">
            <input
              value={item}
              onChange={(event) => onChange(index, event.target.value)}
              className="admin-studio-input"
              placeholder={placeholder}
            />
            <button
              type="button"
              onClick={() => onRemove(index)}
              className="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-black/48 hover:text-[#071110]"
              aria-label={`鍒犻櫎${label}${index + 1}`}
            >
              <Trash2 className="h-4 w-4" />
            </button>
          </div>
        ))}
        <button
          type="button"
          onClick={onAdd}
          className="inline-flex items-center gap-2 rounded-full border border-[#d9e7dd] bg-[#f6fbf7] px-4 py-2 text-sm font-semibold text-[#071110]"
        >
          <Plus className="h-4 w-4" />
          娣诲姞涓€琛?        </button>
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
  const displayName = firstFilledText(draft.name.zh, draft.name.en, draft.name.ja, draft.name.enFull) || 'DJ 鑽夌';
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
    updateStringList(key, (current) => [...current, '']);
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
      setSubmitError(error instanceof Error ? error.message : 'DJ 鍥剧墖涓婁紶澶辫触');
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
      setSubmitError(error instanceof Error ? error.message : '鍒犻櫎 DJ 鍥剧墖澶辫触');
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
      setSubmitError(error instanceof Error ? error.message : 'DJ 鎻愪氦澶辫触');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-5">
      {submitError ? <section className="admin-studio-pastel-rose p-4 text-sm text-[#6a3530]">{submitError}</section> : null}

      <section className="grid gap-4 xl:grid-cols-[1.35fr_0.9fr]">
        <div className="admin-studio-section p-6">
          <div className="admin-studio-label">{mode === 'create' ? 'DJ Studio' : 'Edit DJ Session'}</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">{displayName}</h2>
          <div className="mt-5 grid gap-3 md:grid-cols-4">
            <SummaryCard label="头像" value={draft.avatarImage ? '已上传' : '待上传'} tone="mint" />
            <SummaryCard label="平台链接" value={hasPlatformLink ? '已填写' : '待补齐'} tone="sand" />
            <SummaryCard label="Proof" value={draft.proofImage ? '已上传' : '可选'} tone="rose" />
            <SummaryCard label="当前步骤" value={`${currentStep + 1}/${totalSteps} / ${currentStepItem.title}`} />
          </div>
        </div>

        <div className="admin-studio-pastel-mint p-6">
          <div className="admin-studio-label">Aligned Flow</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">璧勬枡浼樺厛</h2>
          <p className="mt-4 text-sm leading-6 text-black/52">
            Web 绔?DJ 涓婁紶鐜板湪鍏堥泦涓鐞嗚祫鏂欎笌韬唤锛屽啀杩涘叆骞冲彴閾炬帴鍜屾渶缁堟鏌ャ€傚璇█瀛楁缁熶竴閲囩敤鍜?event 涓€鏍风殑鎸夐挳寮?overlay 缂栬緫銆?          </p>
        </div>
      </section>

      <StepNavigation currentStep={currentStep} onSelect={goToStep} />

      {currentStep === 0 ? (
        <Section title="DJ ?????" description="?????????????????????Genres???????">
          <div className="grid gap-4 lg:grid-cols-2">
            <div className="lg:col-span-2">
              <LocalizedTextField
                label="DJ 鍚嶇О"
                value={draft.name}
                kind="input"
                error={errors.name}
                placeholder="渚嬪锛歁artin Garrix"
                hint="主输入默认编辑中文。"
                onPrimaryChange={(value) => updateLocalizedField('name', 'zh', value)}
                onOpenOverlay={() => setActiveLocalizedField({ key: 'name', label: 'DJ 鍚嶇О', kind: 'input' })}
              />
            </div>

            <div className="lg:col-span-2">
              <Field label="图片素材" error={errors.avatarImage} hint="头像、Banner 和 proof 都使用更紧凑的正方形素材卡片管理。">
                <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                  <ImageDropZone
                    label="Avatar"
                    previewUrl={draft.avatarImage?.remoteUrl}
                    uploading={uploadingAvatar}
                    onChange={(event) => void handleImageUpload(event, 'avatar')}
                    onRemove={() => void handleRemoveImage('avatar')}
                  />
                  <ImageDropZone
                    label="Banner"
                    previewUrl={draft.bannerImage?.remoteUrl}
                    uploading={uploadingBanner}
                    onChange={(event) => void handleImageUpload(event, 'banner')}
                    onRemove={() => void handleRemoveImage('banner')}
                  />
                  <ImageDropZone
                    label="Proof"
                    previewUrl={draft.proofImage?.remoteUrl}
                    uploading={uploadingProof}
                    onChange={(event) => void handleImageUpload(event, 'proof')}
                    onRemove={() => void handleRemoveImage('proof')}
                  />
                </div>
              </Field>
            </div>

            <DynamicStringListField
              label="鍒悕"
              items={draft.aliases}
              placeholder="渚嬪锛歒tram"
              hint="每点击一次加号按钮新增一行。"
              onChange={(index, value) => handleListChange('aliases', index, value)}
              onAdd={() => handleListAdd('aliases')}
              onRemove={(index) => handleListRemove('aliases', index)}
            />

            <DynamicStringListField
              label="Genres"
              items={draft.genres}
              placeholder="渚嬪锛歅rogressive House"
              hint="Genres 也按显式加号新增，不再依赖换行。"
              onChange={(index, value) => handleListChange('genres', index, value)}
              onAdd={() => handleListAdd('genres')}
              onRemove={(index) => handleListRemove('genres', index)}
            />

            <LocalizedTextField
              label="鍥藉 / 鍦板尯"
              value={draft.country}
              kind="input"
              placeholder="例如：荷兰"
              onPrimaryChange={(value) => updateLocalizedField('country', 'zh', value)}
              onOpenOverlay={() => setActiveLocalizedField({ key: 'country', label: '鍥藉 / 鍦板尯', kind: 'input' })}
            />

            <div className="lg:col-span-2">
              <LocalizedTextField
                label="简介"
                value={draft.bio}
                kind="textarea"
                placeholder="DJ 简介、风格、代表经历等"
                onPrimaryChange={(value) => updateLocalizedField('bio', 'zh', value)}
                onOpenOverlay={() => setActiveLocalizedField({ key: 'bio', label: '简介', kind: 'textarea' })}
              />
            </div>
          </div>
        </Section>
      ) : null}

      {currentStep === 1 ? (
        <Section title="平台链接" description="尽量补齐官方平台入口和关键统计。proof 作为素材已经统一放在资料页管理。">
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
            <Field label="缃戞槗浜?URL">
              <input value={draft.neteaseUrl} onChange={(event) => updateDraft('neteaseUrl', event.target.value)} className={textInputClassName} placeholder="https://music.163.com/..." />
            </Field>
            <Field label="QQ 闊充箰 URL">
              <input value={draft.qqMusicUrl} onChange={(event) => updateDraft('qqMusicUrl', event.target.value)} className={textInputClassName} placeholder="https://y.qq.com/..." />
            </Field>
            <Field label="瀹樼綉 URL">
              <input value={draft.website} onChange={(event) => updateDraft('website', event.target.value)} className={textInputClassName} placeholder="https://..." />
            </Field>
            <Field label="鍏朵粬骞冲彴 URL">
              <input value={draft.otherPlatformUrl} onChange={(event) => updateDraft('otherPlatformUrl', event.target.value)} className={textInputClassName} placeholder="鍏朵粬骞冲彴閾炬帴" />
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
        </Section>
      ) : null}
      {currentStep === 2 ? (
        <Section title="?????" description="???????????????????????????">
          <div className="grid gap-4 xl:grid-cols-2">
            <div className="admin-reference-card p-4">
              <div className="text-sm font-semibold text-[#071110]">????</div>
              <div className="mt-4 grid gap-3 md:grid-cols-2">
                <SummaryCard label="??" value={displayName} />
                <SummaryCard label="??" value={draft.avatarImage ? "???? OSS" : "???"} tone={draft.avatarImage ? "mint" : "rose"} />
                <SummaryCard label="????" value={hasPlatformLink ? "???" : "???"} tone={hasPlatformLink ? "mint" : "sand"} />
                <SummaryCard label="Proof" value={draft.proofImage ? "???" : "???"} tone={draft.proofImage ? "mint" : "soft"} />
                <SummaryCard label="??" value={`${countFilledItems(draft.aliases)} ?`} />
                <SummaryCard label="Genres" value={`${countFilledItems(draft.genres)} ?`} />
              </div>
            </div>

            <div className="space-y-4">
              <div className="admin-studio-pastel-mint p-5">
                <div className="admin-studio-label">Ready To Submit</div>
                <div className="mt-2 text-lg font-semibold text-[#071110]">
                  {canSubmit ? "?? DJ ??????????" : "??????????????????"}
                </div>
                <div className="mt-3 text-sm leading-6 text-black/52">
                  {mode === "create" ? "?????? DJ???????????" : "?????? DJ ?????????????"}
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
          涓婁竴姝?        </button>
        <div className="text-sm text-black/45">
          {currentStepItem.eyebrow} / {currentStepItem.title}
        </div>
        {currentStep < totalSteps - 1 ? (
          <button type="button" onClick={handleAdvance} className="admin-studio-button-primary px-5 py-3 text-sm">
            涓嬩竴姝?          </button>
        ) : (
          <div className="flex flex-wrap gap-3">
            <Link href="/admin/content/djs/catalog" className="admin-studio-button-secondary px-5 py-3 text-sm">
              ?? DJ ??
            </Link>
            <button
              type="button"
              onClick={() => void handleSubmit()}
              disabled={submitting || uploadingAvatar || uploadingBanner || uploadingProof}
              className="admin-studio-button-primary px-5 py-3 text-sm disabled:cursor-not-allowed disabled:opacity-60"
            >
              {submitting ? '鎻愪氦涓?..' : submitButtonText || (mode === 'create' ? '鎻愪氦 DJ' : '鎻愪氦缂栬緫')}
            </button>
          </div>
        )}
      </section>

      <MultilingualEditorOverlay
        open={Boolean(activeLocalizedField && activeLocalizedValue)}
        title={activeLocalizedField?.label ?? ''}
        kind={activeLocalizedField?.kind ?? 'input'}
        value={activeLocalizedValue ?? { zh: '', en: '', ja: '', enFull: '' }}
        onChange={(locale, value) => {
          if (!activeLocalizedField) return;
          updateLocalizedField(activeLocalizedField.key, locale, value);
        }}
        onClose={() => setActiveLocalizedField(null)}
      />
    </div>
  );
}
