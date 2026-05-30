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
          <button
            type="button"
            onClick={onRemove}
            className="text-xs text-black/48"
          >
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
        <input
          type="file"
          accept="image/*"
          className="hidden"
          onChange={onChange}
        />
      </label>
    </div>
  );
}

const textInputClassName =
  'admin-studio-input';
const textAreaClassName = 'admin-studio-textarea min-h-28';

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
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [uploadingBanner, setUploadingBanner] = useState(false);
  const [uploadingProof, setUploadingProof] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const canSubmit = useMemo(
    () => Object.keys(validateDJStudioDraft(draft)).length === 0,
    [draft]
  );

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

  const handleSubmit = async () => {
    const nextErrors = validateDJStudioDraft(draft);
    setErrors(nextErrors);
    setSubmitError(null);
    if (Object.keys(nextErrors).length > 0) return;

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

      <Section title="身份与主视觉" description="先完成 DJ 主名称、别名、国家和头像。这里延续 iOS 语义，头像必填，后续平台链接或 proof 至少满足一项。">
        <div className="grid gap-4 lg:grid-cols-2">
          <Field label="DJ 名称（中文）" error={errors.name}>
            <input value={draft.name.zh} onChange={(event) => updateLocalizedField('name', 'zh', event.target.value)} className={textInputClassName} placeholder="例如：Martin Garrix" />
          </Field>
          <Field label="DJ 名称（英文）">
            <input value={draft.name.en} onChange={(event) => updateLocalizedField('name', 'en', event.target.value)} className={textInputClassName} placeholder="English name" />
          </Field>
          <Field label="别名（每行一个）">
            <textarea value={draft.aliasesText} onChange={(event) => updateDraft('aliasesText', event.target.value)} className={textAreaClassName} placeholder="MARTIN GARRIX&#10;Ytram" />
          </Field>
          <Field label="风格 / Genres（每行一个）">
            <textarea value={draft.genresText} onChange={(event) => updateDraft('genresText', event.target.value)} className={textAreaClassName} placeholder="Big Room&#10;Progressive House" />
          </Field>
          <Field label="国家（中文）">
            <input value={draft.country.zh} onChange={(event) => updateLocalizedField('country', 'zh', event.target.value)} className={textInputClassName} placeholder="荷兰" />
          </Field>
          <Field label="国家（英文）">
            <input value={draft.country.en} onChange={(event) => updateLocalizedField('country', 'en', event.target.value)} className={textInputClassName} placeholder="Netherlands" />
          </Field>
        </div>

        <div className="mt-6 grid gap-5 lg:grid-cols-3">
          <div>
            <Field label="头像" error={errors.avatarImage}>
              <ImageDropZone
                label="Avatar"
                previewUrl={draft.avatarImage?.remoteUrl}
                uploading={uploadingAvatar}
                onChange={(event) => void handleImageUpload(event, 'avatar')}
                onRemove={() => void handleRemoveImage('avatar')}
              />
            </Field>
          </div>
          <div>
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
          <div>
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
        </div>
      </Section>

      <Section title="资料与平台链接" description="这里对齐 iOS DJUploadFlow 的 links 语义。可以补齐平台链接、平台 ID 和平台统计；没有任何平台链接时，需要至少提供一张 proof 图片。">
        <div className="grid gap-4 lg:grid-cols-2">
          <div className="lg:col-span-2">
            <Field label="简介">
              <textarea value={draft.bio.zh} onChange={(event) => updateLocalizedField('bio', 'zh', event.target.value)} className={textAreaClassName} placeholder="DJ 简介、风格、代表经历等" />
            </Field>
          </div>
          <Field label="Spotify ID">
            <input value={draft.spotifyId} onChange={(event) => updateDraft('spotifyId', event.target.value)} className={textInputClassName} placeholder="spotify artist id" />
          </Field>
          <Field label="Spotify URL" error={errors.links}>
            <input value={draft.spotifyUrl} onChange={(event) => updateDraft('spotifyUrl', event.target.value)} className={textInputClassName} placeholder="https://open.spotify.com/artist/..." />
          </Field>
          <Field label="Spotify Followers" error={errors.stats}>
            <input value={draft.spotifyFollowers} onChange={(event) => updateDraft('spotifyFollowers', event.target.value)} className={textInputClassName} placeholder="123456" />
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
        {errors.links ? <div className="mt-3 text-xs text-red-300">{errors.links}</div> : null}
      </Section>

      <Section title="提交" description="当前版本先对齐 DJ manual import 主线。普通用户创建会进入审核，管理员可直接创建；编辑态后续会继续补回填和 proof 生命周期细节。">
        <div className="flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={() => void handleSubmit()}
            disabled={submitting || uploadingAvatar || uploadingBanner || uploadingProof || !canSubmit}
            className="admin-studio-button-primary"
          >
            {submitting ? '提交中...' : submitButtonText || (mode === 'create' ? '提交 DJ' : '提交编辑')}
          </button>
          <Link href="/admin/content/djs" className="admin-studio-button-secondary">
            返回 DJ 工作区
          </Link>
        </div>
      </Section>
    </div>
  );
}
