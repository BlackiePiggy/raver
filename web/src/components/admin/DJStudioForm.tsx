'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import AdminCountedControl from '@/components/admin/AdminCountedControl';
import AdminImageUploadPanel from '@/components/admin/AdminImageUploadPanel';
import DynamicStringListField from '@/components/admin/DynamicStringListField';
import { Loader2, RefreshCw, X } from 'lucide-react';
import { LocalizedTextField, MultilingualEditorOverlay, type LocalizedFieldKind, type LocalizedLocaleKey } from '@/components/admin/LocalizedTextEditor';
import useOverlayBodyLock from '@/hooks/useOverlayBodyLock';
import { notificationCenterAdminApi } from '@/lib/api/notification-center-admin';
import { INPUT_LIMITS, countText } from '@/lib/input-rules';
import {
  djStudioApi,
  mapDJStudioDraftToCreateInput,
  mapDJStudioDraftToUpdateInput,
  validateDJStudioDraft,
  type DJStudioCreateResult,
  type DJStudioDraft,
  type DJStudioSourceCandidate,
  type DJStudioSourceFieldKey,
  type DJStudioSourceKey,
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

const DJ_SOURCE_LABELS: Record<Exclude<DJStudioSourceKey, 'keep'>, string> = {
  spotify: 'Spotify',
  discogs: 'Discogs',
  soundcloud: 'SoundCloud',
};

const DJ_SOURCE_REPLACE_FIELDS: Array<{ key: DJStudioSourceFieldKey; label: string }> = [
  { key: 'name', label: '名称' },
  { key: 'aliases', label: '别名' },
  { key: 'genres', label: 'GENRES' },
  { key: 'bio', label: '简介(EN)' },
  { key: 'country', label: '国家(EN)' },
  { key: 'countryEnFull', label: '国家(EN FULL)' },
  { key: 'website', label: '官网链接' },
  { key: 'spotifyUrl', label: 'Spotify URL' },
  { key: 'spotifyId', label: 'Spotify ID' },
  { key: 'spotifyFollowers', label: 'Spotify Followers' },
  { key: 'appleMusicId', label: 'Apple Music ID' },
  { key: 'instagramUrl', label: 'Instagram URL' },
  { key: 'facebookUrl', label: 'Facebook URL' },
  { key: 'twitterUrl', label: 'X / Twitter URL' },
  { key: 'youtubeUrl', label: 'YouTube URL' },
  { key: 'soundcloudUrl', label: 'SoundCloud URL' },
  { key: 'soundcloudId', label: 'SoundCloud ID' },
  { key: 'neteaseUrl', label: '网易云 URL' },
  { key: 'qqMusicUrl', label: 'QQ 音乐 URL' },
  { key: 'sourceWikipedia', label: 'Wikipedia 来源' },
  { key: 'sourceWebsite', label: '官网来源' },
  { key: 'sourceSameAs', label: 'SameAs' },
  { key: 'trackCount', label: '发歌数量' },
  { key: 'playlistCount', label: '专辑数量' },
  { key: 'soundCloudFollowers', label: 'SoundCloud 粉丝数量' },
  { key: 'soundCloudFavorites', label: 'SoundCloud 点赞数量' },
];

type DJStudioSourceGroupState = {
  status: 'idle' | 'loading' | 'ok' | 'err';
  message: string;
  items: DJStudioSourceCandidate[];
  selectedIndex: number;
};

type DJStudioSourceReplaceState = {
  query: string;
  sourceEnabled: Record<Exclude<DJStudioSourceKey, 'keep'>, boolean>;
  loading: boolean;
  statusText: string;
  statusTone: '' | 'ok' | 'err';
  sources: Record<Exclude<DJStudioSourceKey, 'keep'>, DJStudioSourceGroupState>;
  fieldSource: Record<DJStudioSourceFieldKey, DJStudioSourceKey>;
  avatarSource: DJStudioSourceKey;
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

const textInputClassName = 'admin-studio-input';

const firstFilledText = (...values: Array<string | undefined | null>) => {
  for (const value of values) {
    const trimmed = String(value || '').trim();
    if (trimmed) return trimmed;
  }
  return '';
};

const countFilledItems = (items: string[]) => items.map((item) => String(item || '').trim()).filter(Boolean).length;
const sourceValueToText = (value: unknown): string => {
  if (Array.isArray(value)) return value.map((item) => String(item || '').trim()).filter(Boolean).join(', ');
  return String(value || '').trim();
};
const sourceValueToList = (value: unknown): string[] => {
  if (Array.isArray(value)) return value.map((item) => String(item || '').trim()).filter(Boolean);
  return String(value || '')
    .split(/[\n,]/)
    .map((item) => item.trim())
    .filter(Boolean);
};

const createInitialSourceReplaceState = (query: string): DJStudioSourceReplaceState => ({
  query,
  sourceEnabled: { spotify: true, discogs: true, soundcloud: true },
  loading: false,
  statusText: '',
  statusTone: '',
  sources: {
    spotify: { status: 'idle', message: '未抓取', items: [], selectedIndex: -1 },
    discogs: { status: 'idle', message: '未抓取', items: [], selectedIndex: -1 },
    soundcloud: { status: 'idle', message: '未抓取', items: [], selectedIndex: -1 },
  },
  fieldSource: Object.fromEntries(DJ_SOURCE_REPLACE_FIELDS.map((field) => [field.key, 'keep'])) as Record<DJStudioSourceFieldKey, DJStudioSourceKey>,
  avatarSource: 'keep',
});

const buildCurrentDraftFieldValueMap = (draft: DJStudioDraft): Record<DJStudioSourceFieldKey, string> => ({
  name: firstFilledText(draft.name.en, draft.name.enFull, draft.name.zh, draft.name.ja),
  aliases: sourceValueToText(draft.aliases),
  genres: sourceValueToText(draft.genres),
  bio: firstFilledText(draft.bio.en, draft.bio.enFull, draft.bio.zh, draft.bio.ja),
  country: firstFilledText(draft.country.en, draft.country.enFull, draft.country.zh, draft.country.ja),
  countryEnFull: firstFilledText(draft.country.enFull, draft.country.en, draft.country.zh, draft.country.ja),
  website: draft.website,
  spotifyUrl: draft.spotifyUrl,
  spotifyId: draft.spotifyId,
  spotifyFollowers: draft.spotifyFollowers,
  appleMusicId: draft.appleMusicId,
  instagramUrl: draft.instagramUrl,
  facebookUrl: draft.facebookUrl,
  twitterUrl: draft.twitterUrl,
  youtubeUrl: draft.youtubeUrl,
  soundcloudUrl: draft.soundcloudUrl,
  soundcloudId: draft.soundcloudId,
  neteaseUrl: draft.neteaseUrl,
  qqMusicUrl: draft.qqMusicUrl,
  sourceWikipedia: draft.sourceWikipedia,
  sourceWebsite: draft.sourceWebsite,
  sourceSameAs: sourceValueToText(draft.sourceSameAs),
  trackCount: draft.trackCount,
  playlistCount: draft.playlistCount,
  soundCloudFollowers: draft.soundCloudFollowers,
  soundCloudFavorites: draft.soundCloudFavorites,
});
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
  const [showSourceOverlay, setShowSourceOverlay] = useState(false);
  const [sourceReplace, setSourceReplace] = useState<DJStudioSourceReplaceState>(() =>
    createInitialSourceReplaceState(firstFilledText(draft.name.zh, draft.name.en, draft.name.ja, draft.name.enFull))
  );

  useOverlayBodyLock(showSourceOverlay);

  useEffect(() => {
    if (!activeLocalizedField && !showSourceOverlay) return;
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return;
      if (activeLocalizedField) {
        setActiveLocalizedField(null);
        return;
      }
      if (showSourceOverlay) setShowSourceOverlay(false);
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [activeLocalizedField, showSourceOverlay]);

  useEffect(() => {
    if (mode !== 'create' || currentStep !== 0) {
      setShowSourceOverlay(false);
    }
  }, [currentStep, mode]);

  const canSubmit = useMemo(() => Object.keys(validateDJStudioDraft(draft)).length === 0, [draft]);
  const currentStepItem = DJ_STUDIO_STEPS[currentStep];
  const totalSteps = DJ_STUDIO_STEPS.length;
  const displayName = firstFilledText(draft.name.zh, draft.name.en, draft.name.ja, draft.name.enFull) || 'DJ 草稿';
  const currentDraftFieldMap = useMemo(() => buildCurrentDraftFieldValueMap(draft), [draft]);
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
  ].some((item) => String(item || '').trim());
  const activeLocalizedValue = activeLocalizedField ? draft[activeLocalizedField.key] : null;
  const sourceKeys: DJStudioSourceKey[] = ['keep', 'spotify', 'discogs', 'soundcloud'];

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

  const getSelectedSourceCandidate = (
    sourceKey: Exclude<DJStudioSourceKey, 'keep'>
  ): DJStudioSourceCandidate | null => {
    const group = sourceReplace.sources[sourceKey];
    if (!group || group.selectedIndex < 0) return null;
    return group.items[group.selectedIndex] || null;
  };

  const canSelectSourceField = (fieldKey: DJStudioSourceFieldKey | 'avatar', sourceKey: DJStudioSourceKey): boolean => {
    if (sourceKey === 'keep') return true;
    if (!sourceReplace.sourceEnabled[sourceKey]) return false;
    const selected = getSelectedSourceCandidate(sourceKey);
    if (!selected) return false;
    if (fieldKey === 'avatar') return Boolean(String(selected.avatarUrl || '').trim());
    return true;
  };

  const getSourceFieldValue = (fieldKey: DJStudioSourceFieldKey, sourceKey: DJStudioSourceKey): string => {
    if (sourceKey === 'keep') return currentDraftFieldMap[fieldKey] || '';
    const selected = getSelectedSourceCandidate(sourceKey);
    return selected ? sourceValueToText(selected[fieldKey]) : '';
  };

  const getSourceAvatarUrl = (sourceKey: DJStudioSourceKey): string => {
    if (sourceKey === 'keep') return String(draft.avatarImage?.remoteUrl || '').trim();
    return String(getSelectedSourceCandidate(sourceKey)?.avatarUrl || '').trim();
  };

  const canSelectSourceFieldFromState = (
    state: DJStudioSourceReplaceState,
    fieldKey: DJStudioSourceFieldKey | 'avatar',
    sourceKey: DJStudioSourceKey
  ): boolean => {
    if (sourceKey === 'keep') return true;
    if (!state.sourceEnabled[sourceKey]) return false;
    const group = state.sources[sourceKey];
    if (!group || group.selectedIndex < 0) return false;
    const selected = group.items[group.selectedIndex] || null;
    if (!selected) return false;
    if (fieldKey === 'avatar') return Boolean(String(selected.avatarUrl || '').trim());
    return true;
  };

  const normalizeSourceSelections = (state: DJStudioSourceReplaceState): DJStudioSourceReplaceState => {
    const nextFieldSource = { ...state.fieldSource };
    for (const field of DJ_SOURCE_REPLACE_FIELDS) {
      const source = nextFieldSource[field.key];
      if (!canSelectSourceFieldFromState(state, field.key, source)) {
        nextFieldSource[field.key] = 'keep';
      }
    }
    const nextAvatarSource = canSelectSourceFieldFromState(state, 'avatar', state.avatarSource) ? state.avatarSource : 'keep';
    return {
      ...state,
      fieldSource: nextFieldSource,
      avatarSource: nextAvatarSource,
    };
  };

  const setSourceStatus = (text: string, tone: DJStudioSourceReplaceState['statusTone'] = '') => {
    setSourceReplace((current) => ({
      ...current,
      statusText: text,
      statusTone: tone,
    }));
  };

  const handleSourceToggleChange = (sourceKey: Exclude<DJStudioSourceKey, 'keep'>, checked: boolean) => {
    setSourceReplace((current) =>
      normalizeSourceSelections({
        ...current,
        sourceEnabled: {
          ...current.sourceEnabled,
          [sourceKey]: checked,
        },
      })
    );
  };

  const handleSourceItemSelect = (sourceKey: Exclude<DJStudioSourceKey, 'keep'>, index: number) => {
    setSourceReplace((current) =>
      normalizeSourceSelections({
        ...current,
        sources: {
          ...current.sources,
          [sourceKey]: {
            ...current.sources[sourceKey],
            selectedIndex: index,
          },
        },
      })
    );
  };

  const handleFieldSourceSelect = (fieldKey: DJStudioSourceFieldKey, sourceKey: DJStudioSourceKey) => {
    if (!canSelectSourceField(fieldKey, sourceKey)) return;
    setSourceReplace((current) => ({
      ...current,
      fieldSource: {
        ...current.fieldSource,
        [fieldKey]: sourceKey,
      },
    }));
  };

  const handleAvatarSourceSelect = (sourceKey: DJStudioSourceKey) => {
    if (!canSelectSourceField('avatar', sourceKey)) return;
    setSourceReplace((current) => ({
      ...current,
      avatarSource: sourceKey,
    }));
  };

  const handleApplyAllFieldsFromSource = (sourceKey: Exclude<DJStudioSourceKey, 'keep'>) => {
    setSourceReplace((current) => {
      const nextFieldSource = { ...current.fieldSource };
      let appliedCount = 0;
      for (const field of DJ_SOURCE_REPLACE_FIELDS) {
        if (canSelectSourceField(field.key, sourceKey)) {
          nextFieldSource[field.key] = sourceKey;
          appliedCount += 1;
        } else {
          nextFieldSource[field.key] = 'keep';
        }
      }
      const nextState = {
        ...current,
        fieldSource: nextFieldSource,
        avatarSource: canSelectSourceField('avatar', sourceKey) ? sourceKey : 'keep',
        statusText: appliedCount > 0 ? `已应用 ${sourceKey.toUpperCase()} 源的 ${appliedCount} 个字段。` : `${sourceKey.toUpperCase()} 当前没有可应用字段。`,
        statusTone: (appliedCount > 0 ? 'ok' : '') as DJStudioSourceReplaceState['statusTone'],
      } satisfies DJStudioSourceReplaceState;
      return normalizeSourceSelections(nextState);
    });
  };

  const handleResetSourceSelection = () => {
    setSourceReplace((current) => ({
      ...current,
      fieldSource: Object.fromEntries(DJ_SOURCE_REPLACE_FIELDS.map((field) => [field.key, 'keep'])) as Record<DJStudioSourceFieldKey, DJStudioSourceKey>,
      avatarSource: 'keep',
      statusText: '已重置为保持当前值。',
      statusTone: 'ok',
    }));
  };

  const applySourceSelectionToDraft = () => {
    const nextAvatarUrl = getSourceAvatarUrl(sourceReplace.avatarSource);
    setDraft((current) => {
      const nextDraft = { ...current };
      for (const field of DJ_SOURCE_REPLACE_FIELDS) {
        const selectedSource = sourceReplace.fieldSource[field.key];
        if (selectedSource === 'keep') continue;
        const value = getSourceFieldValue(field.key, selectedSource);
        const selectedCandidate = getSelectedSourceCandidate(selectedSource);
        switch (field.key) {
          case 'name':
            nextDraft.name = {
              ...nextDraft.name,
              en: value,
              zh: nextDraft.name.zh.trim() ? nextDraft.name.zh : value,
            };
            break;
          case 'aliases':
            nextDraft.aliases = sourceValueToList(selectedCandidate?.aliases).length
              ? sourceValueToList(selectedCandidate?.aliases)
              : [''];
            break;
          case 'genres':
            nextDraft.genres = sourceValueToList(selectedCandidate?.genres).length
              ? sourceValueToList(selectedCandidate?.genres)
              : [''];
            break;
          case 'bio':
            nextDraft.bio = {
              ...nextDraft.bio,
              en: value,
              zh: nextDraft.bio.zh.trim() ? nextDraft.bio.zh : value,
            };
            break;
          case 'country':
            nextDraft.country = {
              ...nextDraft.country,
              en: value,
              zh: nextDraft.country.zh.trim() ? nextDraft.country.zh : value,
            };
            break;
          case 'countryEnFull':
            nextDraft.country = { ...nextDraft.country, enFull: value };
            break;
          case 'sourceWikipedia':
            nextDraft.sourceWikipedia = value;
            break;
          case 'sourceWebsite':
            nextDraft.sourceWebsite = value;
            break;
          case 'sourceSameAs':
            nextDraft.sourceSameAs = sourceValueToList(selectedCandidate?.sourceSameAs).length
              ? sourceValueToList(selectedCandidate?.sourceSameAs)
              : [''];
            break;
          case 'website':
          case 'spotifyUrl':
          case 'spotifyId':
          case 'spotifyFollowers':
          case 'appleMusicId':
          case 'instagramUrl':
          case 'facebookUrl':
          case 'twitterUrl':
          case 'youtubeUrl':
          case 'soundcloudUrl':
          case 'soundcloudId':
          case 'neteaseUrl':
          case 'qqMusicUrl':
          case 'trackCount':
          case 'playlistCount':
          case 'soundCloudFollowers':
          case 'soundCloudFavorites':
            (nextDraft as Record<string, unknown>)[field.key] = value;
            break;
          default:
            break;
        }
      }

      if (sourceReplace.avatarSource !== 'keep' && nextAvatarUrl) {
        const selectedCandidate = getSelectedSourceCandidate(sourceReplace.avatarSource);
        nextDraft.avatarImage = {
          remoteUrl: nextAvatarUrl,
          fileName: selectedCandidate?.name || 'source-avatar',
          usage: 'avatar',
          origin: 'persisted',
        };
      }

      return nextDraft;
    });
    setErrors((current) => {
      const next = { ...current };
      delete next.name;
      delete next.avatarImage;
      delete next.links;
      delete next.stats;
      return next;
    });
    setSourceStatus('字段已应用到当前编辑表单。', 'ok');
  };

  const handleFetchSourceCandidates = async () => {
    const query = String(sourceReplace.query || '').trim() || firstFilledText(draft.name.zh, draft.name.en, draft.name.ja, draft.name.enFull);
    if (!query) {
      setSourceStatus('请先输入 DJ 名称再抓取。', 'err');
      return;
    }

    const enabled = sourceReplace.sourceEnabled;
    if (!enabled.spotify && !enabled.discogs && !enabled.soundcloud) {
      setSourceStatus('请至少选择一个抓取渠道。', 'err');
      return;
    }

    setSourceReplace((current) => ({
      ...current,
      query,
      loading: true,
      statusText: '正在抓取多源信息...',
      statusTone: '',
      sources: {
        spotify: enabled.spotify ? { status: 'loading', message: '抓取中...', items: [], selectedIndex: -1 } : { status: 'idle', message: '未启用', items: [], selectedIndex: -1 },
        discogs: enabled.discogs ? { status: 'loading', message: '抓取中...', items: [], selectedIndex: -1 } : { status: 'idle', message: '未启用', items: [], selectedIndex: -1 },
        soundcloud: enabled.soundcloud ? { status: 'loading', message: '抓取中...', items: [], selectedIndex: -1 } : { status: 'idle', message: '未启用', items: [], selectedIndex: -1 },
      },
    }));

    const nextSources: Record<Exclude<DJStudioSourceKey, 'keep'>, DJStudioSourceGroupState> = {
      spotify: enabled.spotify ? { status: 'loading', message: '抓取中...', items: [], selectedIndex: -1 } : { status: 'idle', message: '未启用', items: [], selectedIndex: -1 },
      discogs: enabled.discogs ? { status: 'loading', message: '抓取中...', items: [], selectedIndex: -1 } : { status: 'idle', message: '未启用', items: [], selectedIndex: -1 },
      soundcloud: enabled.soundcloud ? { status: 'loading', message: '抓取中...', items: [], selectedIndex: -1 } : { status: 'idle', message: '未启用', items: [], selectedIndex: -1 },
    };

    await Promise.all([
      enabled.spotify
        ? djStudioApi.searchSpotifyCandidates(query).then((items) => {
            nextSources.spotify = { status: 'ok', message: items.length ? `抓取 ${items.length} 条` : '无结果', items, selectedIndex: items.length ? 0 : -1 };
          }).catch((error) => {
            nextSources.spotify = { status: 'err', message: error instanceof Error ? error.message : '抓取失败', items: [], selectedIndex: -1 };
          })
        : Promise.resolve(),
      enabled.discogs
        ? djStudioApi.searchDiscogsCandidates(query).then((items) => {
            nextSources.discogs = { status: 'ok', message: items.length ? `抓取 ${items.length} 条` : '无结果', items, selectedIndex: items.length ? 0 : -1 };
          }).catch((error) => {
            nextSources.discogs = { status: 'err', message: error instanceof Error ? error.message : '抓取失败', items: [], selectedIndex: -1 };
          })
        : Promise.resolve(),
      enabled.soundcloud
        ? djStudioApi.searchSoundCloudCandidates(query).then((items) => {
            nextSources.soundcloud = { status: 'ok', message: items.length ? `抓取 ${items.length} 条` : '无结果', items, selectedIndex: items.length ? 0 : -1 };
          }).catch((error) => {
            nextSources.soundcloud = { status: 'err', message: error instanceof Error ? error.message : '抓取失败', items: [], selectedIndex: -1 };
          })
        : Promise.resolve(),
    ]);

    setSourceReplace((current) =>
      normalizeSourceSelections({
        ...current,
        loading: false,
        query,
        statusText: '抓取完成，可逐字段选择来源并应用。',
        statusTone: 'ok',
        sources: nextSources,
      })
    );
  };

  const handleImageUpload = async (file: File | null, usage: 'avatar' | 'banner' | 'proof') => {
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

  const sourceSummaryCount = (sourceKey: Exclude<DJStudioSourceKey, 'keep'>) => {
    const group = sourceReplace.sources[sourceKey];
    return group.items.length;
  };

  const renderSourceReplacePanel = () => (
    <section className="rounded-[22px] border border-[#d7ded9] bg-[#f7f9f7] p-3 md:p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="text-[10px] font-semibold uppercase tracking-[0.16em] text-black/42">多源字段替换</div>
          <div className="mt-1.5 text-[20px] font-semibold tracking-[-0.03em] text-[#071110]">Spotify / Discogs / SoundCloud</div>
          <div className="mt-1.5 text-[13px] leading-5 text-black/48">
            按字段对比当前草稿与多平台候选，逐项决定保留当前值，还是引入某一个来源的数据与头像。
          </div>
        </div>
        <div className="flex flex-wrap gap-1.5">
          {(['spotify', 'discogs', 'soundcloud'] as const).map((sourceKey) => (
            <div
              key={`summary-${sourceKey}`}
              className="rounded-full border border-[#d7ded9] bg-white px-2.5 py-1.5 text-[10px] font-semibold uppercase tracking-[0.08em] text-[#18211f]"
            >
              {DJ_SOURCE_LABELS[sourceKey]} {sourceSummaryCount(sourceKey) ? `${sourceSummaryCount(sourceKey)} 条` : '未抓取'}
            </div>
          ))}
        </div>
      </div>

      <div className="mt-3 rounded-[18px] border border-[#dfe5e1] bg-white p-3">
        <div className="flex flex-wrap items-center gap-2">
          <input
            value={sourceReplace.query}
            onChange={(event) => setSourceReplace((current) => ({ ...current, query: event.target.value }))}
            placeholder="输入 DJ 名称后抓取多源信息"
            className="admin-studio-input h-10 min-w-[240px] flex-1 text-sm"
            onKeyDown={(event) => {
              if (event.key === 'Enter') {
                event.preventDefault();
                void handleFetchSourceCandidates();
              }
            }}
          />
          {(['spotify', 'discogs', 'soundcloud'] as const).map((sourceKey) => (
            <label
              key={sourceKey}
              className="inline-flex h-9 items-center gap-2 rounded-full border border-[#d7ded9] bg-[#fbfcfb] px-3 text-[10px] font-semibold uppercase tracking-[0.08em] text-[#18211f]"
            >
              <input
                type="checkbox"
                checked={sourceReplace.sourceEnabled[sourceKey]}
                onChange={(event) => handleSourceToggleChange(sourceKey, event.target.checked)}
              />
              {DJ_SOURCE_LABELS[sourceKey]}
            </label>
          ))}
          <button
            type="button"
            onClick={() => void handleFetchSourceCandidates()}
            disabled={sourceReplace.loading}
            className="admin-studio-button-primary inline-flex h-9 items-center gap-2 px-3 text-[12px] disabled:opacity-60"
          >
            {sourceReplace.loading ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <RefreshCw className="h-3.5 w-3.5" />}
            抓取
          </button>
          <button
            type="button"
            onClick={handleResetSourceSelection}
            className="admin-studio-button-secondary h-9 px-3 text-[11px]"
          >
            全设为保持当前
          </button>
          <button
            type="button"
            onClick={applySourceSelectionToDraft}
            className="admin-studio-button-primary h-9 px-3 text-[11px]"
          >
            应用到编辑表单
          </button>
        </div>
      </div>

      <div className="mt-3 grid gap-2.5 xl:grid-cols-3">
        {(['spotify', 'discogs', 'soundcloud'] as const)
          .filter((key) => sourceReplace.sourceEnabled[key])
          .map((sourceKey) => {
            const group = sourceReplace.sources[sourceKey];
            return (
              <div key={sourceKey} className="rounded-[16px] border border-[#d7ded9] bg-white p-2.5">
                <div className="flex items-center justify-between gap-2">
                  <div className="text-[10px] font-semibold uppercase tracking-[0.12em] text-black/45">
                    {DJ_SOURCE_LABELS[sourceKey]}
                  </div>
                  <div className="flex items-center gap-1.5">
                    <div className="text-[10px] uppercase tracking-[0.06em] text-black/45">{group.message}</div>
                    <button
                      type="button"
                      onClick={() => handleApplyAllFieldsFromSource(sourceKey)}
                      className="rounded-full border border-[#d7ded9] px-2 py-1 text-[9px] font-semibold uppercase tracking-[0.08em] text-[#18211f]"
                    >
                      应用全部
                    </button>
                  </div>
                </div>
                <div className="admin-shell-scrollbar mt-2.5 grid max-h-[220px] gap-1.5 overflow-auto">
                  {group.items.length ? (
                    group.items.map((item, index) => {
                      const selected = index === group.selectedIndex;
                      const metaLine = [
                        item.followersCount ? `粉丝:${item.followersCount.toLocaleString()}` : '',
                        item.trackCount ? `曲目:${item.trackCount}` : '',
                        item.playlistCount ? `歌单:${item.playlistCount}` : '',
                        item.soundCloudFavorites ? `点赞:${item.soundCloudFavorites}` : '',
                        item.spotifyId ? `spotify:${item.spotifyId}` : '',
                        item.soundcloudId ? `sc:${item.soundcloudId}` : '',
                        [item.city, item.country].filter(Boolean).join(', '),
                      ]
                        .filter(Boolean)
                        .join(' · ');
                      return (
                        <button
                          key={`${sourceKey}-${index}-${item.name}`}
                          type="button"
                          onClick={() => handleSourceItemSelect(sourceKey, index)}
                          className={
                            selected
                              ? 'grid grid-cols-[28px_minmax(0,1fr)] gap-2.5 rounded-[12px] border border-[#1d4ed8] bg-[#eff6ff] px-2.5 py-2 text-left'
                              : 'grid grid-cols-[28px_minmax(0,1fr)] gap-2.5 rounded-[12px] border border-[#e5e7eb] bg-white px-2.5 py-2 text-left'
                          }
                        >
                          <div className="flex h-[28px] w-[28px] items-center justify-center overflow-hidden rounded-full border border-[#d7ded9] bg-[#f3f4f6]">
                            {item.avatarUrl ? (
                              // eslint-disable-next-line @next/next/no-img-element
                              <img src={item.avatarUrl} alt={item.name} className="h-full w-full object-cover" />
                            ) : (
                              <span className="text-[10px] font-semibold text-black/45">
                                {(item.name[0] || '?').toUpperCase()}
                              </span>
                            )}
                          </div>
                          <div className="min-w-0">
                            <div className="truncate text-[13px] font-semibold uppercase tracking-[0.03em] text-[#071110]">
                              {item.name || 'Unknown'}
                            </div>
                            <div className="mt-0.5 text-[10px] leading-4 text-black/48">
                              {metaLine || '点击选择该源候选'}
                            </div>
                          </div>
                        </button>
                      );
                    })
                  ) : (
                    <div className="rounded-[12px] border border-dashed border-[#d7ded9] px-3 py-3 text-[11px] uppercase tracking-[0.04em] text-black/45">
                      {group.message || '暂无结果'}
                    </div>
                  )}
                </div>
              </div>
            );
          })}
      </div>

      <div className="admin-shell-scrollbar mt-3 overflow-auto">
        <table className="min-w-[1040px] w-full table-fixed border border-[#d7ded9] bg-white text-[11px]">
          <thead className="bg-[#f3f5f4]">
            <tr>
              <th className="w-[128px] border-b border-[#d7ded9] px-2.5 py-2 text-left text-[10px] font-semibold uppercase tracking-[0.08em] text-black/45">
                字段
              </th>
              <th className="w-[17%] border-b border-[#d7ded9] px-2.5 py-2 text-left text-[10px] font-semibold uppercase tracking-[0.08em] text-black/45">
                保持当前
              </th>
              <th className="w-[17%] border-b border-[#d7ded9] px-2.5 py-2 text-left text-[10px] font-semibold uppercase tracking-[0.08em] text-black/45">
                Spotify
              </th>
              <th className="w-[17%] border-b border-[#d7ded9] px-2.5 py-2 text-left text-[10px] font-semibold uppercase tracking-[0.08em] text-black/45">
                Discogs
              </th>
              <th className="w-[17%] border-b border-[#d7ded9] px-2.5 py-2 text-left text-[10px] font-semibold uppercase tracking-[0.08em] text-black/45">
                SoundCloud
              </th>
              <th className="w-[17%] border-b border-[#d7ded9] px-2.5 py-2 text-left text-[10px] font-semibold uppercase tracking-[0.08em] text-black/45">
                应用预览
              </th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td className="border-b border-[#eef1ef] px-2.5 py-2.5 text-[10px] font-semibold uppercase tracking-[0.08em] text-black/45">
                头像
              </td>
              {sourceKeys.map((sourceKey) => {
                const canSelect = canSelectSourceField('avatar', sourceKey);
                const selected = sourceReplace.avatarSource === sourceKey;
                const avatarUrl = getSourceAvatarUrl(sourceKey);
                return (
                  <td key={`avatar-${sourceKey}`} className="border-b border-[#eef1ef] px-2.5 py-2.5 align-top">
                    <button
                      type="button"
                      disabled={!canSelect}
                      onClick={() => handleAvatarSourceSelect(sourceKey)}
                      className={
                        selected
                          ? 'min-h-[48px] w-full rounded-[12px] border border-[#1d4ed8] bg-[#eff6ff] p-2 text-left'
                          : canSelect
                            ? 'min-h-[48px] w-full rounded-[12px] border border-[#d7ded9] bg-[#fbfcfb] p-2 text-left hover:border-[#1d4ed8]'
                            : 'min-h-[48px] w-full rounded-[12px] border border-[#e5e7eb] bg-[#f3f4f6] p-2 text-left opacity-50'
                      }
                    >
                      {avatarUrl ? (
                        <div className="flex items-center gap-2">
                          <div className="h-8 w-8 overflow-hidden rounded-full border border-[#d7ded9]">
                            {/* eslint-disable-next-line @next/next/no-img-element */}
                            <img src={avatarUrl} alt="avatar" className="h-full w-full object-cover" />
                          </div>
                          <div className="text-[10px] uppercase tracking-[0.04em] text-black/55">
                            {sourceKey === 'keep'
                              ? '保持当前头像'
                              : `使用 ${DJ_SOURCE_LABELS[sourceKey as Exclude<DJStudioSourceKey, 'keep'>]}`}
                          </div>
                        </div>
                      ) : (
                        <div className="text-[10px] uppercase tracking-[0.04em] text-black/45">{canSelect ? '无头像' : '不可选'}</div>
                      )}
                    </button>
                  </td>
                );
              })}
              <td className="border-b border-[#eef1ef] px-2.5 py-2.5 align-top">
                <div className="min-h-[48px] rounded-[12px] border border-[#d7ded9] bg-[#fbfcfb] p-2">
                  {getSourceAvatarUrl(sourceReplace.avatarSource) ? (
                    <div className="flex items-center gap-2">
                      <div className="h-8 w-8 overflow-hidden rounded-full border border-[#d7ded9]">
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img
                          src={getSourceAvatarUrl(sourceReplace.avatarSource)}
                          alt="selected avatar"
                          className="h-full w-full object-cover"
                        />
                      </div>
                      <div className="text-[10px] uppercase tracking-[0.04em] text-black/55">
                        {sourceReplace.avatarSource === 'keep'
                          ? '当前头像'
                          : DJ_SOURCE_LABELS[sourceReplace.avatarSource as Exclude<DJStudioSourceKey, 'keep'>]}
                      </div>
                    </div>
                  ) : (
                    <div className="text-[10px] uppercase tracking-[0.04em] text-black/45">
                      {sourceReplace.avatarSource === 'keep' ? '当前无头像' : '该来源无头像'}
                    </div>
                  )}
                </div>
              </td>
            </tr>
            {DJ_SOURCE_REPLACE_FIELDS.map((field) => (
              <tr key={field.key}>
                <td className="border-b border-[#eef1ef] px-2.5 py-2.5 text-[10px] font-semibold uppercase tracking-[0.08em] text-black/45">
                  {field.label}
                </td>
                {sourceKeys.map((sourceKey) => {
                  const canSelect = canSelectSourceField(field.key, sourceKey);
                  const selected = sourceReplace.fieldSource[field.key] === sourceKey;
                  const value = getSourceFieldValue(field.key, sourceKey);
                  return (
                    <td key={`${field.key}-${sourceKey}`} className="border-b border-[#eef1ef] px-2.5 py-2.5 align-top">
                      <button
                        type="button"
                        disabled={!canSelect}
                        onClick={() => handleFieldSourceSelect(field.key, sourceKey)}
                        className={
                          selected
                            ? 'min-h-[48px] w-full rounded-[12px] border border-[#1d4ed8] bg-[#eff6ff] p-2 text-left'
                            : canSelect
                              ? 'min-h-[48px] w-full rounded-[12px] border border-[#d7ded9] bg-[#fbfcfb] p-2 text-left hover:border-[#1d4ed8]'
                              : 'min-h-[48px] w-full rounded-[12px] border border-[#e5e7eb] bg-[#f3f4f6] p-2 text-left opacity-50'
                        }
                      >
                        <div className="max-h-[3.9em] overflow-hidden break-words text-[10px] leading-4 text-[#071110]">
                          {value || (canSelect ? '空值' : '不可选')}
                        </div>
                      </button>
                    </td>
                  );
                })}
                <td className="border-b border-[#eef1ef] px-2.5 py-2.5 align-top">
                  <div className="min-h-[48px] rounded-[12px] border border-[#d7ded9] bg-[#fbfcfb] p-2 text-[10px] leading-4 text-[#071110]">
                    {getSourceFieldValue(field.key, sourceReplace.fieldSource[field.key]) || '—'}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {sourceReplace.statusText ? (
        <div
          className={
            sourceReplace.statusTone === 'err'
              ? 'mt-3 rounded-[12px] border border-[#f3c9c9] bg-[#fff5f5] px-3 py-2.5 text-[12px] text-[#8b3a3a]'
              : sourceReplace.statusTone === 'ok'
                ? 'mt-3 rounded-[12px] border border-[#cde7d6] bg-[#f4fbf7] px-3 py-2.5 text-[12px] text-[#1f5c39]'
                : 'mt-3 rounded-[12px] border border-[#e5e7eb] bg-white px-3 py-2.5 text-[12px] text-black/55'
          }
        >
          {sourceReplace.statusText}
        </div>
      ) : null}
    </section>
  );

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
              {mode === 'create' ? (
                <section className="admin-reference-soft-card border border-[#e8eceb] bg-[#fafbf9] p-4">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <div className="admin-studio-label">多源补充信息</div>
                      <div className="mt-2 text-sm leading-6 text-black/48">
                        从 Spotify、Discogs、SoundCloud 拉取候选信息，按字段决定保留哪一个来源，再一键应用到当前新建表单。
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => setShowSourceOverlay(true)}
                      className="admin-studio-button-primary px-4 py-2 text-sm"
                    >
                      打开多源补充面板
                    </button>
                  </div>
                </section>
              ) : null}
            </div>

            <div className="lg:col-span-2">
              <Field label="图片素材" error={errors.avatarImage} hint="头像、横幅和证明图都使用更紧凑的正方形素材卡片管理。">
                <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                  <AdminImageUploadPanel
                    title="头像"
                    description="DJ 目录、详情和绑定候选里最常用的主头像图。"
                    hint="建议上传清晰头像，便于目录和绑定流程识别。"
                    items={draft.avatarImage ? [{
                      id: 'avatar',
                      previewUrl: draft.avatarImage.remoteUrl,
                      remoteUrl: draft.avatarImage.remoteUrl,
                      fileName: draft.avatarImage.fileName || '头像',
                      statusText: draft.avatarImage.origin === 'persisted' ? '当前已入库资源' : '当前草稿上传',
                      onRemove: () => void handleRemoveImage('avatar'),
                    }] : []}
                    uploading={uploadingAvatar}
                    previewMode="square"
                    tone="secondary"
                    onUpload={(files) => void handleImageUpload(files[0] || null, 'avatar')}
                  />
                  <AdminImageUploadPanel
                    title="横幅"
                    description="DJ 主页头部横图，建议保持画面完整、信息简洁。"
                    hint="适合横版视觉图，用于 DJ 页面顶部展示。"
                    items={draft.bannerImage ? [{
                      id: 'banner',
                      previewUrl: draft.bannerImage.remoteUrl,
                      remoteUrl: draft.bannerImage.remoteUrl,
                      fileName: draft.bannerImage.fileName || '横幅',
                      statusText: draft.bannerImage.origin === 'persisted' ? '当前已入库资源' : '当前草稿上传',
                      onRemove: () => void handleRemoveImage('banner'),
                    }] : []}
                    uploading={uploadingBanner}
                    previewMode="landscape"
                    tone="secondary"
                    onUpload={(files) => void handleImageUpload(files[0] || null, 'banner')}
                  />
                  <AdminImageUploadPanel
                    title="证明图"
                    description="辅助审核身份与资料真实性的截图或官方证明素材。"
                    hint="可上传平台后台截图、官方页面截图或其他可核验资料。"
                    items={draft.proofImage ? [{
                      id: 'proof',
                      previewUrl: draft.proofImage.remoteUrl,
                      remoteUrl: draft.proofImage.remoteUrl,
                      fileName: draft.proofImage.fileName || '证明图',
                      statusText: draft.proofImage.origin === 'persisted' ? '当前已入库资源' : '当前草稿上传',
                      onRemove: () => void handleRemoveImage('proof'),
                    }] : []}
                    uploading={uploadingProof}
                    previewMode="square"
                    tone="secondary"
                    onUpload={(files) => void handleImageUpload(files[0] || null, 'proof')}
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
            <Field label="Spotify 编号">
              <AdminCountedControl count={countText(draft.spotifyId)} maxLength={INPUT_LIMITS.common.externalId}>
                <input value={draft.spotifyId} onChange={(event) => updateDraft('spotifyId', event.target.value)} className={textInputClassName} placeholder="spotify artist id" maxLength={INPUT_LIMITS.common.externalId} />
              </AdminCountedControl>
            </Field>
            <Field label="Spotify 链接" error={errors.links}>
              <AdminCountedControl count={countText(draft.spotifyUrl)} maxLength={INPUT_LIMITS.common.url}>
                <input value={draft.spotifyUrl} onChange={(event) => updateDraft('spotifyUrl', event.target.value)} className={textInputClassName} placeholder="https://open.spotify.com/artist/..." maxLength={INPUT_LIMITS.common.url} />
              </AdminCountedControl>
            </Field>
            <Field label="Apple Music 编号">
              <AdminCountedControl count={countText(draft.appleMusicId)} maxLength={INPUT_LIMITS.common.externalId}>
                <input value={draft.appleMusicId} onChange={(event) => updateDraft('appleMusicId', event.target.value)} className={textInputClassName} placeholder="apple music id" maxLength={INPUT_LIMITS.common.externalId} />
              </AdminCountedControl>
            </Field>
            <Field label="Instagram 链接">
              <AdminCountedControl count={countText(draft.instagramUrl)} maxLength={INPUT_LIMITS.common.url}>
                <input value={draft.instagramUrl} onChange={(event) => updateDraft('instagramUrl', event.target.value)} className={textInputClassName} placeholder="https://instagram.com/..." maxLength={INPUT_LIMITS.common.url} />
              </AdminCountedControl>
            </Field>
            <Field label="Facebook 链接">
              <AdminCountedControl count={countText(draft.facebookUrl)} maxLength={INPUT_LIMITS.common.url}>
                <input value={draft.facebookUrl} onChange={(event) => updateDraft('facebookUrl', event.target.value)} className={textInputClassName} placeholder="https://facebook.com/..." maxLength={INPUT_LIMITS.common.url} />
              </AdminCountedControl>
            </Field>
            <Field label="SoundCloud 链接">
              <AdminCountedControl count={countText(draft.soundcloudUrl)} maxLength={INPUT_LIMITS.common.url}>
                <input value={draft.soundcloudUrl} onChange={(event) => updateDraft('soundcloudUrl', event.target.value)} className={textInputClassName} placeholder="https://soundcloud.com/..." maxLength={INPUT_LIMITS.common.url} />
              </AdminCountedControl>
            </Field>
            <Field label="SoundCloud 编号">
              <AdminCountedControl count={countText(draft.soundcloudId)} maxLength={INPUT_LIMITS.common.externalId}>
                <input value={draft.soundcloudId} onChange={(event) => updateDraft('soundcloudId', event.target.value)} className={textInputClassName} placeholder="soundcloud user id" maxLength={INPUT_LIMITS.common.externalId} />
              </AdminCountedControl>
            </Field>
            <Field label="X / Twitter 链接">
              <AdminCountedControl count={countText(draft.twitterUrl)} maxLength={INPUT_LIMITS.common.url}>
                <input value={draft.twitterUrl} onChange={(event) => updateDraft('twitterUrl', event.target.value)} className={textInputClassName} placeholder="https://x.com/..." maxLength={INPUT_LIMITS.common.url} />
              </AdminCountedControl>
            </Field>
            <Field label="YouTube 链接">
              <AdminCountedControl count={countText(draft.youtubeUrl)} maxLength={INPUT_LIMITS.common.url}>
                <input value={draft.youtubeUrl} onChange={(event) => updateDraft('youtubeUrl', event.target.value)} className={textInputClassName} placeholder="https://youtube.com/..." maxLength={INPUT_LIMITS.common.url} />
              </AdminCountedControl>
            </Field>
            <Field label="网易云 URL">
              <AdminCountedControl count={countText(draft.neteaseUrl)} maxLength={INPUT_LIMITS.common.url}>
                <input value={draft.neteaseUrl} onChange={(event) => updateDraft('neteaseUrl', event.target.value)} className={textInputClassName} placeholder="https://music.163.com/..." maxLength={INPUT_LIMITS.common.url} />
              </AdminCountedControl>
            </Field>
            <Field label="QQ 音乐 URL">
              <AdminCountedControl count={countText(draft.qqMusicUrl)} maxLength={INPUT_LIMITS.common.url}>
                <input value={draft.qqMusicUrl} onChange={(event) => updateDraft('qqMusicUrl', event.target.value)} className={textInputClassName} placeholder="https://y.qq.com/..." maxLength={INPUT_LIMITS.common.url} />
              </AdminCountedControl>
            </Field>
            <Field label="官网 URL">
              <AdminCountedControl count={countText(draft.website)} maxLength={INPUT_LIMITS.common.url}>
                <input value={draft.website} onChange={(event) => updateDraft('website', event.target.value)} className={textInputClassName} placeholder="https://..." maxLength={INPUT_LIMITS.common.url} />
              </AdminCountedControl>
            </Field>
            <Field label="其他平台 URL">
              <AdminCountedControl count={countText(draft.otherPlatformUrl)} maxLength={INPUT_LIMITS.common.url}>
                <input value={draft.otherPlatformUrl} onChange={(event) => updateDraft('otherPlatformUrl', event.target.value)} className={textInputClassName} placeholder="其他平台链接" maxLength={INPUT_LIMITS.common.url} />
              </AdminCountedControl>
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

      {mode === 'create' && showSourceOverlay ? (
        <div className="fixed inset-0 z-[120] bg-black/45 p-3 md:p-6" onClick={() => setShowSourceOverlay(false)}>
          <div
            className="mx-auto flex h-[calc(100vh-24px)] max-h-[900px] w-full max-w-[1440px] flex-col overflow-hidden rounded-[28px] border border-[#d7ded9] bg-[#fbfcf9] shadow-[0_28px_100px_rgba(7,17,16,0.22)] md:h-[calc(100vh-48px)]"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="flex flex-wrap items-start justify-between gap-3 border-b border-[#e2e8e4] px-4 py-4 md:px-5">
              <div>
                <div className="text-[10px] font-semibold uppercase tracking-[0.16em] text-black/42">第 1 步 / 新建 DJ</div>
                <div className="mt-1.5 text-[24px] font-semibold tracking-[-0.04em] text-[#071110]">多源补充信息</div>
                <div className="mt-1.5 text-[13px] leading-5 text-black/48">
                  保留旧版 `festival-viewer` 的多源字段对比逻辑，用 overlay 方式补充到当前工作台。
                </div>
              </div>
              <button
                type="button"
                onClick={() => setShowSourceOverlay(false)}
                className="inline-flex h-10 w-10 items-center justify-center rounded-full border border-[#d7ded9] bg-white text-[#18211f] transition hover:border-[#071110]"
                aria-label="关闭多源补充面板"
              >
                <X className="h-4 w-4" strokeWidth={2.2} />
              </button>
            </div>
            <div className="admin-shell-scrollbar min-h-0 flex-1 overflow-auto px-3 py-3 md:px-5 md:py-4">
              {renderSourceReplacePanel()}
            </div>
          </div>
        </div>
      ) : null}

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
