'use client';

import Link from 'next/link';
import Image from 'next/image';
import { ChangeEvent, useMemo, useState } from 'react';
import {
  createEmptyOrganizerExtraLinkDraft,
  mapOrganizerStudioDraftToCreateInput,
  mapOrganizerStudioDraftToUpdateInput,
  organizerStudioApi,
  validateOrganizerStudioDraft,
  type OrganizerStudioCreateResult,
  type OrganizerStudioDraft,
  type OrganizerStudioValidationErrors,
} from '@/features/admin-content/organizer-studio';

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
  acceptMultiple = false,
}: {
  label: string;
  previewUrl?: string;
  uploading: boolean;
  onChange: (event: ChangeEvent<HTMLInputElement>) => void;
  onRemove?: () => void;
  acceptMultiple?: boolean;
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
            绉婚櫎
          </button>
        ) : null}
      </div>
      {previewUrl ? (
        <div className="relative mt-3 aspect-video overflow-hidden rounded-[20px] border border-[#e8eceb]">
          <Image src={previewUrl} alt={label} fill className="object-cover" sizes="640px" />
        </div>
      ) : (
        <div className="mt-3 flex aspect-video items-center justify-center rounded-[20px] bg-[linear-gradient(135deg,#edf7f2,#f7efda)] text-sm text-black/42">
          鏆傛棤鍥剧墖
        </div>
      )}
      <label className="admin-studio-button-secondary mt-4 cursor-pointer px-4 py-3 text-sm">
        {uploading ? '涓婁紶涓?..' : acceptMultiple ? '閫夋嫨鍥剧墖' : '涓婁紶鍥剧墖'}
        <input
          type="file"
          accept="image/*"
          multiple={acceptMultiple}
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

type OrganizerStudioFormProps = {
  mode: 'create' | 'edit';
  organizerId?: string;
  draft: OrganizerStudioDraft;
  setDraft: React.Dispatch<React.SetStateAction<OrganizerStudioDraft>>;
  onSubmit: (result: OrganizerStudioCreateResult) => void;
  submitButtonText?: string;
};

export default function OrganizerStudioForm({
  mode,
  organizerId,
  draft,
  setDraft,
  onSubmit,
  submitButtonText,
}: OrganizerStudioFormProps) {
  const [errors, setErrors] = useState<OrganizerStudioValidationErrors>({});
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [uploadingBackground, setUploadingBackground] = useState(false);
  const [uploadingProof, setUploadingProof] = useState(false);
  const [deletingAvatar, setDeletingAvatar] = useState(false);
  const [deletingBackground, setDeletingBackground] = useState(false);
  const [deletingProofIndexes, setDeletingProofIndexes] = useState<number[]>([]);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const canSubmit = useMemo(
    () => Object.keys(validateOrganizerStudioDraft(draft)).length === 0,
    [draft]
  );

  const updateDraft = <K extends keyof OrganizerStudioDraft>(
    key: K,
    value: OrganizerStudioDraft[K]
  ) => {
    setDraft((current) => ({ ...current, [key]: value }));
    setErrors((current) => {
      if (!current[key as keyof OrganizerStudioValidationErrors]) return current;
      const next = { ...current };
      delete next[key as keyof OrganizerStudioValidationErrors];
      return next;
    });
  };

  const updateLocalizedField = (
    key: 'name' | 'country' | 'city' | 'introduction',
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
      if (!current[key as keyof OrganizerStudioValidationErrors]) return current;
      const next = { ...current };
      delete next[key as keyof OrganizerStudioValidationErrors];
      return next;
    });
  };

  const updateExtraLink = (
    id: string,
    key: 'title' | 'icon' | 'url',
    value: string
  ) => {
    setDraft((current) => ({
      ...current,
      extraLinks: current.extraLinks.map((item) =>
        item.id === id ? { ...item, [key]: value } : item
      ),
    }));
    setErrors((current) => {
      if (!current.links) return current;
      const next = { ...current };
      delete next.links;
      return next;
    });
  };

  const handleSingleImageUpload = async (
    event: ChangeEvent<HTMLInputElement>,
    usage: 'avatar' | 'background'
  ) => {
    const file = event.target.files?.[0];
    if (!file) return;

    try {
      setSubmitError(null);
      if (usage === 'avatar') {
        setUploadingAvatar(true);
      } else {
        setUploadingBackground(true);
      }
      const uploaded = await organizerStudioApi.uploadImage(file, {
        usage,
        draftId: draft.id,
      });
      const nextValue = {
        remoteUrl: uploaded.url,
        fileName: uploaded.fileName || file.name,
        usage,
        origin: 'draft-upload' as const,
      };
      if (usage === 'avatar') {
        updateDraft('avatarImage', nextValue);
      } else {
        updateDraft('backgroundImage', nextValue);
      }
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '涓诲姙鏂瑰浘鐗囦笂浼犲け璐?);
    } finally {
      if (usage === 'avatar') {
        setUploadingAvatar(false);
      } else {
        setUploadingBackground(false);
      }
      event.target.value = '';
    }
  };

  const handleProofUpload = async (event: ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(event.target.files || []);
    if (!files.length) return;

    try {
      setUploadingProof(true);
      setSubmitError(null);
      const uploadedItems = await Promise.all(
        files.map(async (file, index) => {
          const uploaded = await organizerStudioApi.uploadImage(file, {
            usage: 'proof',
            draftId: draft.id,
            sort: draft.proofImages.length + index,
          });
          return {
            remoteUrl: uploaded.url,
            fileName: uploaded.fileName || file.name,
            usage: 'proof' as const,
            origin: 'draft-upload' as const,
          };
        })
      );
      setDraft((current) => ({
        ...current,
        proofImages: [...current.proofImages, ...uploadedItems],
      }));
      setErrors((current) => {
        if (!current.links) return current;
        const next = { ...current };
        delete next.links;
        return next;
      });
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '璇佹槑鍥剧墖涓婁紶澶辫触');
    } finally {
      setUploadingProof(false);
      event.target.value = '';
    }
  };

  const handleSubmit = async () => {
    const nextErrors = validateOrganizerStudioDraft(draft);
    setErrors(nextErrors);
    setSubmitError(null);
    if (Object.keys(nextErrors).length > 0) return;

    try {
      setSubmitting(true);
      const result =
        mode === 'edit' && organizerId
          ? await organizerStudioApi.updateOrganizer(
              organizerId,
              mapOrganizerStudioDraftToUpdateInput(draft)
            )
          : await organizerStudioApi.createOrganizer(
              mapOrganizerStudioDraftToCreateInput(draft)
            );
      onSubmit(result);
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '涓诲姙鏂规彁浜ゅけ璐?);
    } finally {
      setSubmitting(false);
    }
  };

  const handleSingleImageRemove = async (usage: 'avatar' | 'background') => {
    const image = usage === 'avatar' ? draft.avatarImage : draft.backgroundImage;
    if (!image) return;

    try {
      setSubmitError(null);
      if (usage === 'avatar') {
        setDeletingAvatar(true);
      } else {
        setDeletingBackground(true);
      }

      if (image.origin === 'draft-upload') {
        await organizerStudioApi.deleteImages({
          draftId: draft.id,
          urls: [image.remoteUrl],
        });
      }

      if (usage === 'avatar') {
        updateDraft('avatarImage', null);
      } else {
        updateDraft('backgroundImage', null);
      }
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '鍥剧墖绉婚櫎澶辫触');
    } finally {
      if (usage === 'avatar') {
        setDeletingAvatar(false);
      } else {
        setDeletingBackground(false);
      }
    }
  };

  const handleProofRemove = async (index: number) => {
    const image = draft.proofImages[index];
    if (!image) return;

    try {
      setSubmitError(null);
      setDeletingProofIndexes((current) => [...current, index]);

      if (image.origin === 'draft-upload') {
        await organizerStudioApi.deleteImages({
          draftId: draft.id,
          urls: [image.remoteUrl],
        });
      } else if (mode === 'edit' && organizerId) {
        await organizerStudioApi.deleteImages({
          brandId: organizerId,
          urls: [image.remoteUrl],
        });
      }

      updateDraft(
        'proofImages',
        draft.proofImages.filter((_, itemIndex) => itemIndex !== index)
      );
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '璇佹槑鍥剧墖绉婚櫎澶辫触');
    } finally {
      setDeletingProofIndexes((current) => current.filter((item) => item !== index));
    }
  };

  return (
    <div className="space-y-5">
      {submitError ? (
        <section className="admin-studio-pastel-rose p-4 text-sm text-[#6a3530]">
          {submitError}
        </section>
      ) : null}

      <Section
        title="濯掍綋涓庤瘉鏄?
        description="绗竴鐗堝厛瀵归綈澶村儚銆佽儗鏅拰璇佹槑鍥剧墖涓婁紶銆傚ご鍍忔槸蹇呭～涓昏瑙夛紝瀹樻柟閾炬帴涓庤瘉鏄庡浘婊¤冻鍏朵竴鍗冲彲鎻愪氦銆?
      >
        <div className="grid gap-4 xl:grid-cols-2">
          <Field label="涓诲姙鏂瑰ご鍍? error={errors.avatarImage}>
            <ImageDropZone
              label="鐢ㄤ簬鍒楄〃鍜岃鎯呴〉鐨勪富瑙嗚澶村儚"
              previewUrl={draft.avatarImage?.remoteUrl}
              uploading={uploadingAvatar || deletingAvatar}
              onChange={(event) => void handleSingleImageUpload(event, 'avatar')}
              onRemove={() => void handleSingleImageRemove('avatar')}
            />
            {draft.avatarImage?.origin === 'persisted' ? (
              <div className="mt-2 text-xs text-text-secondary">
                褰撳墠涓哄凡鎸佷箙鍖栧ご鍍忋€傜Щ闄や細瑙ｉ櫎鏈缂栬緫涓殑寮曠敤锛屼絾涓嶄細鐩存帴鍒犻櫎鏃㈡湁涓昏瑙夋枃浠躲€?
              </div>
            ) : null}
          </Field>

          <Field label="鑳屾櫙鍥?>
            <ImageDropZone
              label="鐢ㄤ簬璇︽儏澶村浘鎴栦富瑙嗚寤跺睍"
              previewUrl={draft.backgroundImage?.remoteUrl}
              uploading={uploadingBackground || deletingBackground}
              onChange={(event) => void handleSingleImageUpload(event, 'background')}
              onRemove={() => void handleSingleImageRemove('background')}
            />
            {draft.backgroundImage?.origin === 'persisted' ? (
              <div className="mt-2 text-xs text-text-secondary">
                褰撳墠涓哄凡鎸佷箙鍖栬儗鏅浘銆傜Щ闄や細瑙ｉ櫎鏈缂栬緫涓殑寮曠敤锛屼絾涓嶄細鐩存帴鍒犻櫎鏃㈡湁鑳屾櫙璧勬簮銆?
              </div>
            ) : null}
          </Field>
        </div>

        <div className="mt-5">
          <Field label="璇佹槑鍥剧墖" error={errors.links}>
            <ImageDropZone
              label="鍙笂浼犺惀涓氭墽鐓с€佸畼鏂规埅鍥俱€佹捣鎶ユ垨鍏朵粬璇佹槑鍥?
              uploading={uploadingProof}
              onChange={(event) => void handleProofUpload(event)}
              acceptMultiple
            />
            {draft.proofImages.length ? (
              <div className="mt-4 grid gap-3 md:grid-cols-3">
                {draft.proofImages.map((image, index) => (
                  <div
                    key={`${image.remoteUrl}-${index}`}
                    className="admin-reference-soft-card p-3"
                  >
                    <div className="relative aspect-video overflow-hidden rounded-xl border border-border-secondary">
                      <Image
                        src={image.remoteUrl}
                        alt={image.fileName}
                        fill
                        className="object-cover"
                        sizes="320px"
                      />
                    </div>
                    <div className="mt-3 flex items-center justify-between gap-3">
                      <div className="min-w-0 text-xs text-black/42">
                        <div className="truncate">{image.fileName}</div>
                      </div>
                      <button
                        type="button"
                        onClick={() => void handleProofRemove(index)}
                        disabled={deletingProofIndexes.includes(index)}
                        className="text-xs text-black/48 hover:text-[#071110]"
                      >
                        {deletingProofIndexes.includes(index) ? '绉婚櫎涓?..' : '绉婚櫎'}
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            ) : null}
          </Field>
        </div>
      </Section>

      <Section
        title="鍩虹淇℃伅"
        description="杩欓噷鍏堝榻愬悕绉般€佸埆鍚嶃€佸煄甯傘€佸浗瀹跺拰鍩虹妗ｆ瀛楁銆傚璇█鍏堜互涓枃銆佽嫳鏂囦负涓伙紝鍚庣画鍐嶇户缁墿灞曟洿缁嗙矑搴﹁瑷€缂栬緫銆?
      >
        <div className="grid gap-4 lg:grid-cols-2">
          <Field label="涓诲姙鏂瑰悕绉帮紙涓枃锛? error={errors.name}>
            <input
              value={draft.name.zh}
              onChange={(event) => updateLocalizedField('name', 'zh', event.target.value)}
              className={textInputClassName}
              placeholder="渚嬪锛歍omorrowland"
            />
          </Field>
          <Field label="涓诲姙鏂瑰悕绉帮紙鑻辨枃锛?>
            <input
              value={draft.name.en}
              onChange={(event) => updateLocalizedField('name', 'en', event.target.value)}
              className={textInputClassName}
              placeholder="English name"
            />
          </Field>
          <Field label="绠€绉?>
            <input
              value={draft.abbreviation}
              onChange={(event) => updateDraft('abbreviation', event.target.value)}
              className={textInputClassName}
              placeholder="渚嬪锛歍ML"
            />
          </Field>
          <Field label="鍒悕锛堥€楀彿鎴栨崲琛屽垎闅旓級">
            <textarea
              value={draft.aliasesText}
              onChange={(event) => updateDraft('aliasesText', event.target.value)}
              className={textAreaClassName}
              placeholder="Tomorrowland Belgium&#10;Tomorrowland Brasil"
            />
          </Field>
          <Field label="鍥藉锛堜腑鏂囷級">
            <input
              value={draft.country.zh}
              onChange={(event) => updateLocalizedField('country', 'zh', event.target.value)}
              className={textInputClassName}
              placeholder="渚嬪锛氭瘮鍒╂椂"
            />
          </Field>
          <Field label="鍥藉锛堣嫳鏂囷級">
            <input
              value={draft.country.en}
              onChange={(event) => updateLocalizedField('country', 'en', event.target.value)}
              className={textInputClassName}
              placeholder="Belgium"
            />
          </Field>
          <Field label="鍩庡競锛堜腑鏂囷級">
            <input
              value={draft.city.zh}
              onChange={(event) => updateLocalizedField('city', 'zh', event.target.value)}
              className={textInputClassName}
              placeholder="渚嬪锛欱oom"
            />
          </Field>
          <Field label="鍩庡競锛堣嫳鏂囷級">
            <input
              value={draft.city.en}
              onChange={(event) => updateLocalizedField('city', 'en', event.target.value)}
              className={textInputClassName}
              placeholder="Boom"
            />
          </Field>
          <Field label="鎴愮珛骞翠唤">
            <input
              value={draft.foundedYear}
              onChange={(event) => updateDraft('foundedYear', event.target.value)}
              className={textInputClassName}
              placeholder="渚嬪锛?005"
            />
          </Field>
          <Field label="涓惧姙棰戠巼">
            <input
              value={draft.frequency}
              onChange={(event) => updateDraft('frequency', event.target.value)}
              className={textInputClassName}
              placeholder="渚嬪锛欰nnual"
            />
          </Field>
        </div>
      </Section>

      <Section
        title="鍝佺墝璧勬枡"
        description="涓诲姙鏂硅鎯呮弿杩颁細浣滀负 Brand / WikiFestival 鐨勪富璧勬枡鏉ユ簮銆傚悗缁?Event 缁戝畾鍜屾洿瀹屾暣鐨?profile diff 涔熶細缁х画闈犳嫝杩欓噷銆?
      >
        <div className="grid gap-4 lg:grid-cols-2">
          <Field label="涓€鍙ヨ瘽鏍囩">
            <input
              value={draft.tagline}
              onChange={(event) => updateDraft('tagline', event.target.value)}
              className={textInputClassName}
              placeholder="渚嬪锛欸lobal electronic music festival"
            />
          </Field>
          <div className="admin-reference-soft-card px-4 py-3 text-sm leading-6 text-black/48">
            Event ?????????????
            <Link
              href="/admin/content/events/catalog"
              className="ml-1 font-semibold text-[#071110] hover:underline"
            >
              ??????
            </Link>
            ??????????????? organizer inline bind ?????
          </div>
        </div>
      </Section>

      <div className="flex justify-end">
        <button
          type="button"
          onClick={() => void handleSubmit()}
          disabled={submitting || !canSubmit}
          className="admin-studio-button-primary"
        >
          {submitting
            ? '鎻愪氦涓?..'
            : submitButtonText ||
              (mode === 'edit' ? '鎻愪氦涓诲姙鏂圭紪杈? : '鎻愪氦涓诲姙鏂瑰垱寤?)}
        </button>
      </div>
    </div>
  );
}

