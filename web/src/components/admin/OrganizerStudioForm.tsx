'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';
import { Languages, Plus, Trash2 } from 'lucide-react';
import AdminCountedControl from '@/components/admin/AdminCountedControl';
import AdminImageUploadPanel from '@/components/admin/AdminImageUploadPanel';
import DynamicStringListField from '@/components/admin/DynamicStringListField';
import EventLocationPickerModal, {
  type EventLocationPoint,
} from '@/components/admin/EventLocationPickerModal';
import {
  LocalizedTextField,
  MultilingualEditorOverlay,
  type LocalizedFieldKind,
  type LocalizedLocaleKey,
} from '@/components/admin/LocalizedTextEditor';
import { INPUT_LIMITS, countText } from '@/lib/input-rules';
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

const textInputClassName = 'admin-studio-input';
const compactInputClassName =
  'h-11 w-full rounded-[16px] border border-[#d7ded9] bg-white px-4 text-[14px] text-[#071110] outline-none transition focus:border-[#071110] focus:ring-0';
type OrganizerStudioFormProps = {
  mode: 'create' | 'edit';
  organizerId?: string;
  draft: OrganizerStudioDraft;
  setDraft: React.Dispatch<React.SetStateAction<OrganizerStudioDraft>>;
  onSubmit: (result: OrganizerStudioCreateResult) => void;
  submitButtonText?: string;
};

type OrganizerLocalizedFieldKey =
  | 'name'
  | 'country'
  | 'city'
  | 'introduction'
  | 'detailAddress'
  | 'manualSetAddress';

type OrganizerLocalizedFieldOverlayState = {
  key: OrganizerLocalizedFieldKey;
  label: string;
  kind: LocalizedFieldKind;
};

const firstFilledText = (...values: Array<string | null | undefined>): string => {
  for (const value of values) {
    const trimmed = String(value || '').trim();
    if (trimmed) return trimmed;
  }
  return '';
};

const buildReadonlyFormattedAddress = (
  detail: OrganizerStudioDraft['detailAddress'],
  city: OrganizerStudioDraft['city'],
  country: OrganizerStudioDraft['country']
) => {
  const join = (parts: Array<string | null | undefined>) =>
    parts
      .map((item) => String(item || '').trim())
      .filter(Boolean)
      .join(' · ');

  return {
    zh: join([
      country.zh || country.en,
      city.zh || city.en,
      detail.zh || detail.en,
    ]),
    en: join([
      country.enFull || country.en || country.zh,
      city.en || city.zh,
      detail.en || detail.zh,
    ]),
    ja: join([
      country.ja || country.enFull || country.en || country.zh,
      city.ja || city.en || city.zh,
      detail.ja || detail.en || detail.zh,
    ]),
  };
};

const normalizeMapProvider = (value?: string | null): EventLocationPoint['provider'] => {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'apple-mapkit' || normalized === 'apple_mapkit') {
    return 'mapkit';
  }
  if (
    normalized === 'amap' ||
    normalized === 'mapkit' ||
    normalized === 'mapbox' ||
    normalized === 'geoapify' ||
    normalized === 'google'
  ) {
    return normalized;
  }
  return 'geoapify';
};

const normalizeProviderMetaForModal = (
  value: NonNullable<OrganizerStudioDraft['locationPoint']>['providerMeta'] | undefined
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
            ...(value.mapkit.mapItemIdentifier
              ? { mapItemIdentifier: value.mapkit.mapItemIdentifier }
              : {}),
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
            ...(value.google.types?.length ? { types: value.google.types } : {}),
          },
        }
      : {}),
  };
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
  const [activeLocalizedField, setActiveLocalizedField] = useState<OrganizerLocalizedFieldOverlayState | null>(null);
  const [showLocationPicker, setShowLocationPicker] = useState(false);

  const canSubmit = useMemo(() => Object.keys(validateOrganizerStudioDraft(draft)).length === 0, [draft]);
  const detailAddressDisplay = useMemo(
    () =>
      firstFilledText(
        draft.detailAddress.zh,
        draft.detailAddress.en,
        draft.detailAddress.ja,
        draft.detailAddress.enFull
      ),
    [draft.detailAddress]
  );
  const manualLocationFormattedAddress = useMemo(
    () => buildReadonlyFormattedAddress(draft.detailAddress, draft.city, draft.country),
    [draft.detailAddress, draft.city, draft.country]
  );
  const locationPointFormattedAddress = useMemo(() => {
    return {
      zh:
        draft.locationPoint?.formattedAddressI18n?.zh ||
        draft.locationPoint?.formattedAddressI18n?.en ||
        manualLocationFormattedAddress.zh,
      en:
        draft.locationPoint?.formattedAddressI18n?.en ||
        draft.locationPoint?.formattedAddressI18n?.zh ||
        manualLocationFormattedAddress.en,
      ja:
        draft.locationPoint?.formattedAddressI18n?.ja ||
        manualLocationFormattedAddress.ja,
    };
  }, [draft.locationPoint, manualLocationFormattedAddress]);

  const activeLocalizedValue = activeLocalizedField ? draft[activeLocalizedField.key] : null;
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

  const updateDraft = <K extends keyof OrganizerStudioDraft>(key: K, value: OrganizerStudioDraft[K]) => {
    setDraft((current) => ({ ...current, [key]: value }));
    setErrors((current) => {
      if (!current[key as keyof OrganizerStudioValidationErrors]) return current;
      const next = { ...current };
      delete next[key as keyof OrganizerStudioValidationErrors];
      return next;
    });
  };

  const updateLocalizedField = (
    key: OrganizerLocalizedFieldKey,
    locale: LocalizedLocaleKey,
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
      const errorKey = key === 'detailAddress' || key === 'manualSetAddress'
        ? 'detailAddress'
        : key;
      if (!current[errorKey as keyof OrganizerStudioValidationErrors]) return current;
      const next = { ...current };
      delete next[errorKey as keyof OrganizerStudioValidationErrors];
      return next;
    });
  };

  const handleLocationConfirm = (point: EventLocationPoint) => {
    setDraft((current) => {
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
          manualSetAddressI18n: {
            zh: current.manualSetAddress.zh || '',
            en: current.manualSetAddress.en || '',
            ja: current.manualSetAddress.ja || '',
            enFull: current.manualSetAddress.enFull || '',
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
      };
    });
    setErrors((current) => {
      const next = { ...current };
      delete next.detailAddress;
      return next;
    });
    setShowLocationPicker(false);
  };

  const updateExtraLink = (id: string, key: 'title' | 'icon' | 'url', value: string) => {
    setDraft((current) => ({
      ...current,
      extraLinks: current.extraLinks.map((item) => (item.id === id ? { ...item, [key]: value } : item)),
    }));
    setErrors((current) => {
      if (!current.links) return current;
      const next = { ...current };
      delete next.links;
      return next;
    });
  };

  const addExtraLink = () => {
    setDraft((current) => ({
      ...current,
      extraLinks: [...current.extraLinks, createEmptyOrganizerExtraLinkDraft()],
    }));
  };

  const removeExtraLink = (id: string) => {
    setDraft((current) => ({
      ...current,
      extraLinks: current.extraLinks.filter((item) => item.id !== id),
    }));
  };

  const updateAliases = (updater: (current: string[]) => string[]) => {
    setDraft((current) => ({
      ...current,
      aliases: updater(current.aliases),
    }));
  };

  const handleAliasChange = (index: number, value: string) => {
    updateAliases((current) => current.map((item, itemIndex) => (itemIndex === index ? value : item)));
  };

  const handleAliasAdd = () => {
    updateAliases((current) =>
      current.length >= INPUT_LIMITS.organizer.aliasesMaxItems ? current : [...current, '']
    );
  };

  const handleAliasRemove = (index: number) => {
    updateAliases((current) => {
      const next = current.filter((_, itemIndex) => itemIndex !== index);
      return next.length ? next : [''];
    });
  };

  const handleSingleImageUpload = async (file: File | null, usage: 'avatar' | 'background') => {
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
      setSubmitError(error instanceof Error ? error.message : '主办方图片上传失败');
    } finally {
      if (usage === 'avatar') {
        setUploadingAvatar(false);
      } else {
        setUploadingBackground(false);
      }
    }
  };

  const handleProofUpload = async (files: File[]) => {
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
      setSubmitError(error instanceof Error ? error.message : '证明图片上传失败');
    } finally {
      setUploadingProof(false);
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
      setSubmitError(error instanceof Error ? error.message : '图片移除失败');
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

      setDraft((current) => ({
        ...current,
        proofImages: current.proofImages.filter((_, itemIndex) => itemIndex !== index),
      }));
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '证明图片移除失败');
    } finally {
      setDeletingProofIndexes((current) => current.filter((item) => item !== index));
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
          ? await organizerStudioApi.updateOrganizer(organizerId, mapOrganizerStudioDraftToUpdateInput(draft))
          : await organizerStudioApi.createOrganizer(mapOrganizerStudioDraftToCreateInput(draft));
      onSubmit(result);
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '主办方提交失败');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-5">
      {submitError ? (
        <section className="admin-studio-pastel-rose p-4 text-sm text-[#6a3530]">{submitError}</section>
      ) : null}

      <Section
        title="媒体素材"
        description="先对齐头像和背景图。头像是必填主视觉，用于目录列表和详情页的基础展示。"
      >
        <div className="grid gap-4 xl:grid-cols-2">
          <Field label="主办方头像" error={errors.avatarImage}>
            <AdminImageUploadPanel
              title="头像"
              description="用于目录列表和详情页展示的主视觉头像。"
              hint="建议上传清晰主体图，便于目录和绑定结果识别。"
              items={draft.avatarImage ? [{
                id: 'avatar',
                previewUrl: draft.avatarImage.remoteUrl,
                remoteUrl: draft.avatarImage.remoteUrl,
                fileName: draft.avatarImage.fileName || '主办方头像',
                statusText: draft.avatarImage.origin === 'persisted' ? '当前已入库资源' : '当前草稿上传',
                removeLabel: deletingAvatar ? '移除中...' : '移除',
                onRemove: () => void handleSingleImageRemove('avatar'),
              }] : []}
              uploading={uploadingAvatar || deletingAvatar}
              previewMode="square"
              tone="secondary"
              onUpload={(files) => void handleSingleImageUpload(files[0] || null, 'avatar')}
            />
            {draft.avatarImage?.origin === 'persisted' ? (
              <div className="mt-2 text-xs text-black/40">
                当前为已持久化头像。移除会解除本次编辑中的引用，但不会直接删除历史资源文件。
              </div>
            ) : null}
          </Field>

          <Field label="背景图">
            <AdminImageUploadPanel
              title="背景图"
              description="用于详情页头图或品牌背景视觉，适合更宽的横版构图。"
              hint="建议上传横版背景图，便于详情页头部展示。"
              items={draft.backgroundImage ? [{
                id: 'background',
                previewUrl: draft.backgroundImage.remoteUrl,
                remoteUrl: draft.backgroundImage.remoteUrl,
                fileName: draft.backgroundImage.fileName || '背景图',
                statusText: draft.backgroundImage.origin === 'persisted' ? '当前已入库资源' : '当前草稿上传',
                removeLabel: deletingBackground ? '移除中...' : '移除',
                onRemove: () => void handleSingleImageRemove('background'),
              }] : []}
              uploading={uploadingBackground || deletingBackground}
              previewMode="landscape"
              tone="secondary"
              onUpload={(files) => void handleSingleImageUpload(files[0] || null, 'background')}
            />
            {draft.backgroundImage?.origin === 'persisted' ? (
              <div className="mt-2 text-xs text-black/40">
                当前为已持久化背景图。移除会解除本次编辑中的引用，但不会直接删除历史资源文件。
              </div>
            ) : null}
          </Field>
        </div>
      </Section>

      <Section
        title="基础信息"
        description="名称、国家、城市和简介都统一走共享多语言编辑能力。默认主输入使用中文，点击右侧按钮展开编辑其他语言。"
      >
        <div className="grid gap-4 lg:grid-cols-2">
          <LocalizedTextField
            label="主办方名称"
            value={draft.name}
            kind="input"
            placeholder="例如：Tomorrowland"
            error={errors.name}
            hint="目录卡片、详情页标题和搜索结果都会优先使用这里的主名称。"
            maxLength={INPUT_LIMITS.organizer.name}
            onPrimaryChange={(value) => updateLocalizedField('name', 'zh', value)}
            onOpenOverlay={() => setActiveLocalizedField({ key: 'name', label: '主办方名称', kind: 'input' })}
          />

          <Field label="简称">
            <AdminCountedControl count={countText(draft.abbreviation)} maxLength={INPUT_LIMITS.organizer.abbreviation}>
              <input
                value={draft.abbreviation}
                onChange={(event) => updateDraft('abbreviation', event.target.value)}
                className={textInputClassName}
                placeholder="例如：TML"
                maxLength={INPUT_LIMITS.organizer.abbreviation}
              />
            </AdminCountedControl>
          </Field>

          <DynamicStringListField
            label="别名"
            items={draft.aliases}
            placeholder="例如：Tomorrowland Belgium"
            hint="点击加号新增一行，支持按条目单独删除。"
            itemMax={INPUT_LIMITS.organizer.alias}
            maxItems={INPUT_LIMITS.organizer.aliasesMaxItems}
            onChange={handleAliasChange}
            onAdd={handleAliasAdd}
            onRemove={handleAliasRemove}
          />

          <LocalizedTextField
            label="国家"
            value={draft.country}
            kind="input"
            placeholder="例如：比利时"
            maxLength={INPUT_LIMITS.organizer.country}
            onPrimaryChange={(value) => updateLocalizedField('country', 'zh', value)}
            onOpenOverlay={() => setActiveLocalizedField({ key: 'country', label: '国家', kind: 'input' })}
          />

          <LocalizedTextField
            label="城市"
            value={draft.city}
            kind="input"
            placeholder="例如：Boom"
            maxLength={INPUT_LIMITS.organizer.city}
            onPrimaryChange={(value) => updateLocalizedField('city', 'zh', value)}
            onOpenOverlay={() => setActiveLocalizedField({ key: 'city', label: '城市', kind: 'input' })}
          />

          <Field label="成立年份">
            <AdminCountedControl count={countText(draft.foundedYear)} maxLength={INPUT_LIMITS.organizer.foundedYear}>
              <input
                value={draft.foundedYear}
                onChange={(event) => updateDraft('foundedYear', event.target.value)}
                className={textInputClassName}
                placeholder="例如：2005"
                maxLength={INPUT_LIMITS.organizer.foundedYear}
              />
            </AdminCountedControl>
          </Field>

          <Field label="举办频率">
            <AdminCountedControl count={countText(draft.frequency)} maxLength={INPUT_LIMITS.organizer.frequency}>
              <input
                value={draft.frequency}
                onChange={(event) => updateDraft('frequency', event.target.value)}
                className={textInputClassName}
                placeholder="例如：Annual"
                maxLength={INPUT_LIMITS.organizer.frequency}
              />
            </AdminCountedControl>
          </Field>
        </div>
      </Section>

      <Section
        title="地点与地图"
        description="这里复用 event 的地图选点能力，但对主办方地址保持完全可选。你可以只填手动地址、只选地图，或者两者都不填。"
      >
        <div className="space-y-5">
          <div className="grid gap-5 xl:grid-cols-[0.92fr_1.08fr]">
            <div className="space-y-4">
              <div className="rounded-xl border border-gray-100 bg-gray-50/70 p-4 space-y-4">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="text-xs font-semibold text-gray-700">主办方地点</div>
                    <div className="mt-2 text-sm leading-relaxed text-gray-600">
                      {detailAddressDisplay || '当前还没有配置主办方地点地址'}
                    </div>
                    <div className="mt-2 text-xs text-gray-400">
                      地图选点支持原生版与 legacy 版切换，确认后会自动回填当前表单。
                    </div>
                    {draft.locationPoint?.provider ? (
                      <div className="mt-2 text-[10px] text-gray-400">
                        Provider: {draft.locationPoint.provider} · sourceMode: {draft.locationPoint.sourceMode || 'pin_drag'}
                      </div>
                    ) : null}
                    {draft.latitude || draft.longitude ? (
                      <div className="mt-2 text-xs text-gray-400 font-mono">
                        {draft.latitude || '—'}, {draft.longitude || '—'}
                      </div>
                    ) : null}
                  </div>
                  <div className="flex shrink-0 flex-col gap-2">
                    <button
                      type="button"
                      onClick={() => setShowLocationPicker(true)}
                      className="rounded-lg bg-gray-900 px-3 py-2 text-xs font-semibold text-white hover:bg-gray-800 transition-colors"
                    >
                      {draft.latitude && draft.longitude ? '重新地图选点' : '地图选点'}
                    </button>
                    {(draft.latitude || draft.longitude || draft.pickedMapAddress || draft.pickedPlaceName) ? (
                      <button
                        type="button"
                        onClick={() =>
                          setDraft((current) => ({
                            ...current,
                            latitude: '',
                            longitude: '',
                            locationPoint: null,
                            pickedPlaceName: '',
                            pickedMapAddress: '',
                          }))
                        }
                        className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-xs font-medium text-gray-600 hover:bg-gray-50 transition-colors"
                      >
                        清除地图绑定
                      </button>
                    ) : null}
                  </div>
                </div>

                <div>
                  <div className="mb-1.5 text-xs text-gray-500">场地展示地址（可选）</div>
                  <div className="admin-localized-field-shell">
                    <AdminCountedControl count={countText(draft.manualSetAddress.zh)} maxLength={INPUT_LIMITS.event.detailAddress}>
                      <input
                        value={draft.manualSetAddress.zh}
                        onChange={(event) => updateLocalizedField('manualSetAddress', 'zh', event.target.value)}
                        className={compactInputClassName}
                        placeholder="未填写时回退到地图地址"
                        maxLength={INPUT_LIMITS.event.detailAddress}
                      />
                    </AdminCountedControl>
                    <button
                      type="button"
                      onClick={() => setActiveLocalizedField({ key: 'manualSetAddress', label: '场地展示地址', kind: 'textarea' })}
                      className="admin-localized-field-trigger"
                      title="多语言编辑"
                    >
                      <Languages className="h-4 w-4" strokeWidth={2.2} />
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <div className="space-y-4">
              <div className="grid gap-3 md:grid-cols-2">
                <div>
                  <div className="mb-1.5 text-xs text-gray-500">国家</div>
                  <div className="admin-localized-field-shell">
                    <AdminCountedControl count={countText(draft.country.zh)} maxLength={INPUT_LIMITS.organizer.country}>
                      <input
                        value={draft.country.zh}
                        onChange={(event) => updateLocalizedField('country', 'zh', event.target.value)}
                        className={compactInputClassName}
                        placeholder="例如：中国"
                        maxLength={INPUT_LIMITS.organizer.country}
                      />
                    </AdminCountedControl>
                    <button
                      type="button"
                      onClick={() => setActiveLocalizedField({ key: 'country', label: '国家', kind: 'input' })}
                      className="admin-localized-field-trigger"
                      title="多语言编辑"
                    >
                      <Languages className="h-4 w-4" strokeWidth={2.2} />
                    </button>
                  </div>
                </div>

                <div>
                  <div className="mb-1.5 text-xs text-gray-500">城市</div>
                  <div className="admin-localized-field-shell">
                    <AdminCountedControl count={countText(draft.city.zh)} maxLength={INPUT_LIMITS.organizer.city}>
                      <input
                        value={draft.city.zh}
                        onChange={(event) => updateLocalizedField('city', 'zh', event.target.value)}
                        className={compactInputClassName}
                        placeholder="例如：Shanghai"
                        maxLength={INPUT_LIMITS.organizer.city}
                      />
                    </AdminCountedControl>
                    <button
                      type="button"
                      onClick={() => setActiveLocalizedField({ key: 'city', label: '城市', kind: 'input' })}
                      className="admin-localized-field-trigger"
                      title="多语言编辑"
                    >
                      <Languages className="h-4 w-4" strokeWidth={2.2} />
                    </button>
                  </div>
                </div>

                <div className="md:col-span-2">
                  <div className="mb-1.5 text-xs text-gray-500">详细地址</div>
                  <div className="admin-localized-field-shell">
                    <AdminCountedControl count={countText(draft.detailAddress.zh)} maxLength={INPUT_LIMITS.event.detailAddress}>
                      <input
                        value={draft.detailAddress.zh}
                        onChange={(event) => updateLocalizedField('detailAddress', 'zh', event.target.value)}
                        className={compactInputClassName}
                        placeholder="主办方详细地址"
                        maxLength={INPUT_LIMITS.event.detailAddress}
                      />
                    </AdminCountedControl>
                    <button
                      type="button"
                      onClick={() => setActiveLocalizedField({ key: 'detailAddress', label: '详细地址', kind: 'textarea' })}
                      className="admin-localized-field-trigger"
                      title="多语言编辑"
                    >
                      <Languages className="h-4 w-4" strokeWidth={2.2} />
                    </button>
                  </div>
                  {errors.detailAddress ? <div className="mt-1 text-xs text-[#6a3530]">{errors.detailAddress}</div> : null}
                </div>
              </div>
            </div>
          </div>

          <div className="grid gap-3 xl:grid-cols-[1.3fr_1.3fr_1fr]">
            <div className="rounded-lg border border-gray-100 bg-gray-50 px-3 py-2.5 text-xs leading-relaxed text-gray-600">
              <div className="mb-1 text-[10px] font-semibold uppercase tracking-wider text-gray-400">最终 hand-made 地址</div>
              {firstFilledText(manualLocationFormattedAddress.zh, manualLocationFormattedAddress.en) || '—'}
              {manualLocationFormattedAddress.en && manualLocationFormattedAddress.en !== manualLocationFormattedAddress.zh ? (
                <div className="mt-1 text-gray-400">EN: {manualLocationFormattedAddress.en}</div>
              ) : null}
              {manualLocationFormattedAddress.ja ? <div className="mt-0.5 text-gray-400">JA: {manualLocationFormattedAddress.ja}</div> : null}
            </div>

            <div className="rounded-lg border border-gray-100 bg-gray-50 px-3 py-2.5 text-xs leading-relaxed text-gray-600">
              <div className="mb-1 text-[10px] font-semibold uppercase tracking-wider text-gray-400">最终地图格式化地址</div>
              {firstFilledText(locationPointFormattedAddress.zh, locationPointFormattedAddress.en) || '—'}
              {locationPointFormattedAddress.en && locationPointFormattedAddress.en !== locationPointFormattedAddress.zh ? (
                <div className="mt-1 text-gray-400">EN: {locationPointFormattedAddress.en}</div>
              ) : null}
            </div>

            <div className="rounded-lg border border-gray-100 bg-gray-50 px-3 py-2.5 text-xs leading-relaxed text-gray-600">
              <div className="mb-1 text-[10px] font-semibold uppercase tracking-wider text-gray-400">最终场地展示地址</div>
              {firstFilledText(draft.manualSetAddress.zh, draft.manualSetAddress.en, draft.manualSetAddress.ja, draft.manualSetAddress.enFull) || '未填写时回退到地图地址'}
            </div>
          </div>
        </div>
      </Section>

      <Section
        title="品牌资料"
        description="主办方详情描述会作为品牌档案和详情页的核心资料来源。多语言介绍使用和 event / DJ 相同的共享编辑方式。"
      >
        <div className="grid gap-4 lg:grid-cols-2">
          <Field label="一句话标签">
            <AdminCountedControl count={countText(draft.tagline)} maxLength={INPUT_LIMITS.organizer.tagline}>
              <input
                value={draft.tagline}
                onChange={(event) => updateDraft('tagline', event.target.value)}
                className={textInputClassName}
                placeholder="例如：Global electronic music festival"
                maxLength={INPUT_LIMITS.organizer.tagline}
              />
            </AdminCountedControl>
          </Field>

          <div className="admin-reference-soft-card px-4 py-3 text-sm leading-6 text-black/48">
            活动和主办方的最终关联关系仍然以活动目录和活动编辑流为主。
            <Link
              href="/admin/content/events/catalog"
              className="ml-1 font-semibold text-[#071110] hover:underline"
            >
              打开活动目录
            </Link>
            ，后续可以继续在活动侧完成 organizer 绑定与校对。
          </div>
        </div>

        <div className="mt-4">
          <LocalizedTextField
            label="主办方介绍"
            value={draft.introduction}
            kind="textarea"
            placeholder="填写中文介绍，其他语言通过右侧按钮补充。"
            maxLength={INPUT_LIMITS.organizer.introduction}
            onPrimaryChange={(value) => updateLocalizedField('introduction', 'zh', value)}
            onOpenOverlay={() =>
              setActiveLocalizedField({ key: 'introduction', label: '主办方介绍', kind: 'textarea' })
            }
          />
        </div>
      </Section>

      <Section
        title="官方链接"
        description="至少提供一个官方链接，或上传一张以上证明图片。额外链接会一起进入最终 links payload。"
      >
        <div className="grid gap-4 lg:grid-cols-2">
          <Field label="官方网站" error={errors.links}>
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
          <Field label="Instagram">
            <AdminCountedControl count={countText(draft.instagram)} maxLength={INPUT_LIMITS.common.url}>
              <input
                value={draft.instagram}
                onChange={(event) => updateDraft('instagram', event.target.value)}
                className={textInputClassName}
                placeholder="https://instagram.com/..."
                maxLength={INPUT_LIMITS.common.url}
              />
            </AdminCountedControl>
          </Field>
          <Field label="Facebook">
            <AdminCountedControl count={countText(draft.facebook)} maxLength={INPUT_LIMITS.common.url}>
              <input
                value={draft.facebook}
                onChange={(event) => updateDraft('facebook', event.target.value)}
                className={textInputClassName}
                placeholder="https://facebook.com/..."
                maxLength={INPUT_LIMITS.common.url}
              />
            </AdminCountedControl>
          </Field>
          <Field label="X / Twitter">
            <AdminCountedControl count={countText(draft.twitter)} maxLength={INPUT_LIMITS.common.url}>
              <input
                value={draft.twitter}
                onChange={(event) => updateDraft('twitter', event.target.value)}
                className={textInputClassName}
                placeholder="https://x.com/..."
                maxLength={INPUT_LIMITS.common.url}
              />
            </AdminCountedControl>
          </Field>
          <Field label="YouTube">
            <AdminCountedControl count={countText(draft.youtube)} maxLength={INPUT_LIMITS.common.url}>
              <input
                value={draft.youtube}
                onChange={(event) => updateDraft('youtube', event.target.value)}
                className={textInputClassName}
                placeholder="https://youtube.com/..."
                maxLength={INPUT_LIMITS.common.url}
              />
            </AdminCountedControl>
          </Field>
          <Field label="TikTok">
            <AdminCountedControl count={countText(draft.tiktok)} maxLength={INPUT_LIMITS.common.url}>
              <input
                value={draft.tiktok}
                onChange={(event) => updateDraft('tiktok', event.target.value)}
                className={textInputClassName}
                placeholder="https://tiktok.com/@..."
                maxLength={INPUT_LIMITS.common.url}
              />
            </AdminCountedControl>
          </Field>
        </div>

        <div className="mt-5 space-y-3">
          <div className="flex items-center justify-between gap-3">
            <div>
              <div className="admin-studio-label">额外链接</div>
              <div className="mt-2 text-sm leading-6 text-black/48">
                用于补充不属于标准平台字段的链接，比如 Linktree、官方票务、Discord 或媒体页面。
              </div>
            </div>
            <button
              type="button"
              onClick={addExtraLink}
              className="inline-flex items-center gap-2 rounded-full border border-[#d9e7dd] bg-[#f6fbf7] px-4 py-2 text-sm font-semibold text-[#071110]"
            >
              <Plus className="h-4 w-4" />
              添加链接
            </button>
          </div>

          {draft.extraLinks.length ? (
            <div className="space-y-3">
              {draft.extraLinks.map((item, index) => (
                <div key={item.id} className="rounded-[22px] border border-[#e8eceb] bg-white p-4">
                  <div className="mb-3 flex items-center justify-between gap-3">
                    <div className="text-sm font-semibold text-[#071110]">额外链接 {index + 1}</div>
                    <button
                      type="button"
                      onClick={() => removeExtraLink(item.id)}
                      className="inline-flex h-9 w-9 items-center justify-center rounded-full border border-[#ead6d6] bg-white text-[#8b3a3a]"
                      aria-label={`删除额外链接 ${index + 1}`}
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                  <div className="grid gap-3 lg:grid-cols-3">
                    <AdminCountedControl count={countText(item.title)} maxLength={INPUT_LIMITS.organizer.extraLinkTitle}>
                      <input
                        value={item.title}
                        onChange={(event) => updateExtraLink(item.id, 'title', event.target.value)}
                        className={textInputClassName}
                        placeholder="标题，例如 Ticket"
                        maxLength={INPUT_LIMITS.organizer.extraLinkTitle}
                      />
                    </AdminCountedControl>
                    <AdminCountedControl count={countText(item.icon)} maxLength={INPUT_LIMITS.common.linkIcon}>
                      <input
                        value={item.icon}
                        onChange={(event) => updateExtraLink(item.id, 'icon', event.target.value)}
                        className={textInputClassName}
                        placeholder="icon，例如 link / ticket"
                        maxLength={INPUT_LIMITS.common.linkIcon}
                      />
                    </AdminCountedControl>
                    <AdminCountedControl count={countText(item.url)} maxLength={INPUT_LIMITS.common.url}>
                      <input
                        value={item.url}
                        onChange={(event) => updateExtraLink(item.id, 'url', event.target.value)}
                        className={textInputClassName}
                        placeholder="https://..."
                        maxLength={INPUT_LIMITS.common.url}
                      />
                    </AdminCountedControl>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="rounded-[18px] border border-dashed border-[#d7ded9] px-4 py-5 text-sm text-black/48">
              暂无额外链接。标准平台字段不够用时，再补充这里的自定义链接。
            </div>
          )}
        </div>
      </Section>

      <Section
        title="证明材料"
        description="证明图片放在提交确认前集中检查。可上传营业执照、官方截图、海报或其他可验证主办方身份的素材。"
      >
        <Field label="证明图片" error={errors.links}>
          <AdminImageUploadPanel
            title="证明图"
            description="集中管理用于审核的证明素材，可上传营业执照、官方截图、海报或其他可核验材料。"
            hint="支持一次选择多张证明图，提交前在这里统一核对。"
            items={draft.proofImages.map((image, index) => ({
              id: `${image.remoteUrl}-${index}`,
              previewUrl: image.remoteUrl,
              remoteUrl: image.remoteUrl,
              fileName: image.fileName || `证明图 ${index + 1}`,
              statusText: image.origin === 'persisted' ? `#${index + 1} · 当前已入库资源` : `#${index + 1} · 当前草稿上传`,
              removeLabel: deletingProofIndexes.includes(index) ? '移除中...' : '移除',
              onRemove: () => void handleProofRemove(index),
              onMoveLeft: index > 0 ? () => updateDraft('proofImages', [
                ...draft.proofImages.slice(0, index - 1),
                draft.proofImages[index],
                draft.proofImages[index - 1],
                ...draft.proofImages.slice(index + 1),
              ]) : undefined,
              onMoveRight: index < draft.proofImages.length - 1 ? () => updateDraft('proofImages', [
                ...draft.proofImages.slice(0, index),
                draft.proofImages[index + 1],
                draft.proofImages[index],
                ...draft.proofImages.slice(index + 2),
              ]) : undefined,
              moveLeftDisabled: index === 0,
              moveRightDisabled: index === draft.proofImages.length - 1,
            }))}
            uploading={uploadingProof}
            multiple
            previewMode="landscape"
            tone="secondary"
            onUpload={(files) => void handleProofUpload(files)}
          />
        </Field>
      </Section>

      <Section
        title="提交确认"
        description="提交前请确认资料来源可信、你有权使用当前素材，并确保这次上传代表真实有效的主办方实体。"
      >
        <div className="space-y-4">
          <label className="flex items-start gap-3 rounded-[20px] border border-[#e8eceb] bg-white px-4 py-4">
            <input
              type="checkbox"
              checked={draft.rightsConfirmed}
              onChange={(event) => updateDraft('rightsConfirmed', event.target.checked)}
              className="mt-1 h-4 w-4 rounded border-[#cdd5d0]"
            />
            <div>
              <div className="text-sm font-semibold text-[#071110]">我确认当前图片、链接和文案具备可用权利</div>
              <div className="mt-1 text-sm leading-6 text-black/48">
                包括头像、背景图、证明图和介绍文案，不会因为本次提交产生明显的版权或授权风险。
              </div>
            </div>
          </label>

          <label className="flex items-start gap-3 rounded-[20px] border border-[#e8eceb] bg-white px-4 py-4">
            <input
              type="checkbox"
              checked={draft.identityConfirmed}
              onChange={(event) => updateDraft('identityConfirmed', event.target.checked)}
              className="mt-1 h-4 w-4 rounded border-[#cdd5d0]"
            />
            <div>
              <div className="text-sm font-semibold text-[#071110]">我确认这确实是要创建或编辑的目标主办方实体</div>
              <div className="mt-1 text-sm leading-6 text-black/48">
                名称、链接、城市国家和证明资料彼此对应，不是误绑到其他主办方、品牌或活动页面。
              </div>
            </div>
          </label>

          {errors.review ? <div className="text-xs text-[#6a3530]">{errors.review}</div> : null}
        </div>
      </Section>

      <div className="flex justify-end">
        <button
          type="button"
          onClick={() => void handleSubmit()}
          disabled={submitting || !canSubmit}
          className="admin-studio-button-primary"
        >
          {submitting ? '提交中...' : submitButtonText || (mode === 'edit' ? '保存主办方' : '创建主办方')}
        </button>
      </div>

      <MultilingualEditorOverlay
        open={Boolean(activeLocalizedField && activeLocalizedValue)}
        title={activeLocalizedField?.label ?? ''}
        kind={activeLocalizedField?.kind ?? 'input'}
        value={activeLocalizedValue ?? { zh: '', en: '', ja: '', enFull: '' }}
        maxLength={
          activeLocalizedField?.key === 'name'
            ? INPUT_LIMITS.organizer.name
            : activeLocalizedField?.key === 'country'
              ? INPUT_LIMITS.organizer.country
              : activeLocalizedField?.key === 'city'
                ? INPUT_LIMITS.organizer.city
                : activeLocalizedField?.key === 'detailAddress' || activeLocalizedField?.key === 'manualSetAddress'
                  ? INPUT_LIMITS.event.detailAddress
                  : INPUT_LIMITS.organizer.introduction
        }
        onChange={(locale, value) => {
          if (!activeLocalizedField) return;
          updateLocalizedField(activeLocalizedField.key, locale, value);
        }}
        onClose={() => setActiveLocalizedField(null)}
      />

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
