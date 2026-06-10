'use client';

import Link from 'next/link';
import { Plus, Trash2 } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import AdminCountedControl from '@/components/admin/AdminCountedControl';
import EntityBindingField from '@/components/admin/EntityBindingField';
import {
  LocalizedTextField,
  MultilingualEditorOverlay,
  type LocalizedLocaleKey,
  type LocalizedTextValue,
} from '@/components/admin/LocalizedTextEditor';
import {
  genreAdminApi,
  type GenreAdminNode,
  type GenreKeyArtistBinding,
  type GenreSoundCueTrack,
} from '@/features/admin-content/genre-admin';
import { INPUT_LIMITS, countText } from '@/lib/input-rules';

type ParentMode = 'root' | 'existing' | 'new';
type ParentPlacementMode = 'root' | 'existing';
type LocalizedFieldKey = 'description' | 'example';

type KeyArtistDraft = {
  id: string;
  name: string;
  djId: string | null;
  dj: GenreKeyArtistBinding['dj'];
};

type SoundCueTrackDraft = {
  id: string;
  title: string;
  artist: string;
  spotifyUrl: string;
  appleMusicUrl: string;
  neteaseUrl: string;
  soundcloudUrl: string;
  beatportUrl: string;
};

type CreateGenreDraft = {
  name: string;
  slug: string;
  sortOrder: string;
  parentMode: ParentMode;
  parentId: string;
  nameI18nValue: LocalizedTextValue;
  origin: string;
  era: string;
  bpm: string;
  backgroundImageURL: string;
  spotifyTrackURL: string;
  wikipediaURL: string;
  descriptionValue: LocalizedTextValue;
  exampleValue: LocalizedTextValue;
};

type NewParentDraft = {
  name: string;
  slug: string;
  sortOrder: string;
  placementMode: ParentPlacementMode;
  ancestorParentId: string;
};

type CreatedResult = {
  genre: {
    id: string;
    name: string;
    path: string;
  };
  parent: {
    id: string;
    name: string;
    path: string;
  } | null;
};

type FlatGenreNode = GenreAdminNode & {
  depth: number;
};

const emptyLocalizedValue = (): LocalizedTextValue => ({
  zh: '',
  en: '',
  ja: '',
  enFull: '',
});

const initialDraft = (): CreateGenreDraft => ({
  name: '',
  slug: '',
  sortOrder: '',
  parentMode: 'root',
  parentId: '',
  nameI18nValue: emptyLocalizedValue(),
  origin: '',
  era: '',
  bpm: '',
  backgroundImageURL: '',
  spotifyTrackURL: '',
  wikipediaURL: '',
  descriptionValue: emptyLocalizedValue(),
  exampleValue: emptyLocalizedValue(),
});

const initialNewParentDraft = (): NewParentDraft => ({
  name: '',
  slug: '',
  sortOrder: '',
  placementMode: 'root',
  ancestorParentId: '',
});

const flattenTree = (items: GenreAdminNode[], depth = 0): FlatGenreNode[] =>
  items.flatMap((item) => [{ ...item, depth }, ...flattenTree(item.children ?? [], depth + 1)]);

const makeDraftArtist = (): KeyArtistDraft => ({
  id: `draft-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
  name: '',
  djId: null,
  dj: null,
});

const makeSoundCueTrackDraft = (item?: GenreSoundCueTrack, index = 0): SoundCueTrackDraft => ({
  id: `sound-cue-${Date.now()}-${index}-${Math.random().toString(36).slice(2, 7)}`,
  title: item?.title || '',
  artist: item?.artist || '',
  spotifyUrl: item?.spotifyUrl || '',
  appleMusicUrl: item?.appleMusicUrl || '',
  neteaseUrl: item?.neteaseUrl || '',
  soundcloudUrl: item?.soundcloudUrl || '',
  beatportUrl: item?.beatportUrl || '',
});

export default function AdminGenreCreatePage() {
  const [draft, setDraft] = useState<CreateGenreDraft>(initialDraft);
  const [newParentDraft, setNewParentDraft] = useState<NewParentDraft>(initialNewParentDraft);
  const [keyArtistDrafts, setKeyArtistDrafts] = useState<KeyArtistDraft[]>([]);
  const [soundCueTrackDrafts, setSoundCueTrackDrafts] = useState<SoundCueTrackDraft[]>([]);
  const [tree, setTree] = useState<GenreAdminNode[]>([]);
  const [loadingTree, setLoadingTree] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [created, setCreated] = useState<CreatedResult | null>(null);
  const [activeLocalizedField, setActiveLocalizedField] = useState<LocalizedFieldKey | null>(null);

  const flatNodes = useMemo(() => flattenTree(tree), [tree]);
  const selectedParent = flatNodes.find((item) => item.id === draft.parentId) ?? null;
  const selectedAncestorParent = flatNodes.find((item) => item.id === newParentDraft.ancestorParentId) ?? null;
  const canSubmit = draft.name.trim().length > 0 && !saving;

  const loadTree = async () => {
    setLoadingTree(true);
    try {
      const payload = await genreAdminApi.fetchTree();
      setTree(payload.items);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '加载风格树失败。');
    } finally {
      setLoadingTree(false);
    }
  };

  useEffect(() => {
    void loadTree();
  }, []);

  const updateLocalizedValue = (field: LocalizedFieldKey, locale: LocalizedLocaleKey, value: string) => {
    setDraft((current) => ({
      ...current,
      [field === 'description' ? 'descriptionValue' : 'exampleValue']: {
        ...(field === 'description' ? current.descriptionValue : current.exampleValue),
        [locale]: value,
      },
    }));
  };

  const addKeyArtistDraft = () => {
    setKeyArtistDrafts((current) => [...current, makeDraftArtist()]);
  };

  const addSoundCueTrackDraft = () => {
    setSoundCueTrackDrafts((current) => [...current, makeSoundCueTrackDraft(undefined, current.length)]);
  };

  const updateKeyArtistDraft = (id: string, patch: Partial<KeyArtistDraft>) => {
    setKeyArtistDrafts((current) => current.map((item) => (item.id === id ? { ...item, ...patch } : item)));
  };

  const removeKeyArtistDraft = (id: string) => {
    setKeyArtistDrafts((current) => current.filter((item) => item.id !== id));
  };

  const updateSoundCueTrackDraft = (id: string, patch: Partial<SoundCueTrackDraft>) => {
    setSoundCueTrackDrafts((current) => current.map((item) => (item.id === id ? { ...item, ...patch } : item)));
  };

  const removeSoundCueTrackDraft = (id: string) => {
    setSoundCueTrackDrafts((current) => current.filter((item) => item.id !== id));
  };

  const resetForm = () => {
    setDraft(initialDraft());
    setNewParentDraft(initialNewParentDraft());
    setKeyArtistDrafts([]);
    setSoundCueTrackDrafts([]);
    setError('');
    setCreated(null);
    setActiveLocalizedField(null);
  };

  const validateBeforeSubmit = (): string | null => {
    if (!draft.name.trim()) return '请先填写风格名称。';
    if (draft.parentMode === 'existing' && !draft.parentId) return '请选择一个现有父风格。';
    if (draft.parentMode === 'new' && !newParentDraft.name.trim()) return '请先填写新父风格名称。';
    if (draft.parentMode === 'new' && newParentDraft.placementMode === 'existing' && !newParentDraft.ancestorParentId) {
      return '请先选择新父风格要挂载到哪个现有节点下。';
    }
    return null;
  };

  const handleSubmit = async () => {
    const validationError = validateBeforeSubmit();
    if (validationError) {
      setError(validationError);
      return;
    }

    setSaving(true);
    setError('');

    try {
      let resolvedParentId: string | null = null;
      let createdParent: CreatedResult['parent'] = null;

      if (draft.parentMode === 'existing') {
        resolvedParentId = draft.parentId;
      } else if (draft.parentMode === 'new') {
        const parentNode = await genreAdminApi.createNode({
          name: newParentDraft.name.trim(),
          parentId:
            newParentDraft.placementMode === 'existing' && newParentDraft.ancestorParentId
              ? newParentDraft.ancestorParentId
              : null,
          slug: newParentDraft.slug.trim() || null,
          sortOrder: newParentDraft.sortOrder.trim() ? Number(newParentDraft.sortOrder) : null,
        });
        resolvedParentId = parentNode.id;
        createdParent = {
          id: parentNode.id,
          name: parentNode.name,
          path: parentNode.path,
        };
      }

      const node = await genreAdminApi.createNode({
        name: draft.name.trim(),
        parentId: resolvedParentId,
        slug: draft.slug.trim() || null,
        sortOrder: draft.sortOrder.trim() ? Number(draft.sortOrder) : null,
      });

      await genreAdminApi.updateContent(node.id, {
        nameI18n: draft.nameI18nValue,
        description: draft.descriptionValue.zh.trim() || null,
        descriptionI18n: draft.descriptionValue,
        example: draft.exampleValue.zh.trim() || null,
        exampleI18n: draft.exampleValue,
        soundCueTracks: soundCueTrackDrafts
          .map((item) => ({
            title: item.title.trim(),
            artist: item.artist.trim(),
            spotifyUrl: item.spotifyUrl.trim() || null,
            appleMusicUrl: item.appleMusicUrl.trim() || null,
            neteaseUrl: item.neteaseUrl.trim() || null,
            soundcloudUrl: item.soundcloudUrl.trim() || null,
            beatportUrl: item.beatportUrl.trim() || null,
          }))
          .filter((item) => item.title),
        origin: draft.origin.trim() || null,
        era: draft.era.trim() || null,
        bpm: draft.bpm.trim() || null,
        backgroundImageURL: draft.backgroundImageURL.trim() || null,
        spotifyTrackURL: draft.spotifyTrackURL.trim() || null,
        wikipediaURL: draft.wikipediaURL.trim() || null,
      });

      await genreAdminApi.updateKeyArtists(node.id, {
        keyArtists: keyArtistDrafts.map((item) => item.name.trim()).filter(Boolean),
        bindings: keyArtistDrafts
          .map((item) => ({
            name: item.name.trim(),
            djId: item.djId,
          }))
          .filter((item) => item.name),
      });

      setCreated({
        genre: {
          id: node.id,
          name: node.name,
          path: node.path,
        },
        parent: createdParent,
      });

      await loadTree();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '创建风格失败。');
    } finally {
      setSaving(false);
    }
  };

  return (
    <AdminContentLayout
      title="新建风格"
      description="支持直接创建根节点、挂到现有父节点下，或先新建一个父节点，再继续完成多语言内容和 DJ 绑定。"
      actions={
        <>
          <Link
            href="/admin/content/genres"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            返回风格目录
          </Link>
        </>
      }
    >
      {created ? (
        <section className="space-y-5">
          <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-6 text-[#2f4027]">
            <div className="text-xs uppercase tracking-[0.14em] text-[#52705c]">已创建</div>
            <div className="mt-3 text-[30px] font-semibold tracking-[-0.04em] text-[#111827]">
              风格创建成功
            </div>
            <div className="mt-4 space-y-2 text-sm leading-7 text-[#4a5b52]">
              <div>名称：{created.genre.name}</div>
              <div>路径：{created.genre.path}</div>
              <div>ID: {created.genre.id}</div>
              {created.parent ? <div>同步创建父节点：{created.parent.path}</div> : null}
            </div>
          </div>

          <div className="flex flex-wrap gap-3">
            <Link
              href="/admin/content/genres"
              className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
            >
              返回风格目录
            </Link>
            <button
              type="button"
              onClick={resetForm}
              className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
            >
              继续创建下一条
            </button>
          </div>
        </section>
      ) : (
        <section className="space-y-5">
          {error ? (
            <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] p-4 text-sm text-[#6a3530]">
              {error}
            </div>
          ) : null}

          <section className="admin-reference-card p-6">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <div className="text-xs uppercase tracking-[0.14em] text-black/38">结构</div>
                <h2 className="mt-2 text-[22px] font-semibold text-[#111827]">挂载位置与层级</h2>
                <div className="mt-1 text-sm text-black/48">
                  选择把当前风格创建为根节点、挂到现有节点下，或在同一流程里先创建一个新的父节点。
                </div>
              </div>
              <button
                type="button"
                onClick={() => void handleSubmit()}
                disabled={!canSubmit}
                className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
              >
                {saving ? '创建中...' : '创建风格'}
              </button>
            </div>

            <div className="mt-5 grid gap-3 lg:grid-cols-3">
              {[
                {
                  key: 'root',
                  title: '根节点',
                  description: '把这条风格直接创建在树的顶层。',
                },
                {
                  key: 'existing',
                  title: '现有父节点',
                  description: '把新风格挂到当前树中的某个已有节点下。',
                },
                {
                  key: 'new',
                  title: '先创建父节点',
                  description: '先在本流程里新建一个父节点，再在其下创建当前风格。',
                },
              ].map((item) => (
                <button
                  key={item.key}
                  type="button"
                  onClick={() =>
                    setDraft((current) => ({
                      ...current,
                      parentMode: item.key as ParentMode,
                      parentId: item.key === 'existing' ? current.parentId : '',
                    }))
                  }
                  className={`rounded-[20px] border px-4 py-4 text-left transition ${
                    draft.parentMode === item.key
                      ? 'border-[#c8ded0] bg-[#f6fbf7]'
                      : 'border-[#e8eceb] bg-white hover:border-[#d6ddda]'
                  }`}
                >
                  <div className="text-sm font-semibold text-[#111827]">{item.title}</div>
                  <div className="mt-2 text-sm leading-6 text-black/50">{item.description}</div>
                </button>
              ))}
            </div>

            {draft.parentMode === 'existing' ? (
              <div className="mt-5 grid gap-4 xl:grid-cols-[minmax(0,1fr)_320px]">
                <label className="block">
                  <div className="mb-2 admin-studio-label">父风格</div>
                  <select
                    value={draft.parentId}
                    onChange={(event) => setDraft((current) => ({ ...current, parentId: event.target.value }))}
                    className="admin-studio-input"
                  >
                    <option value="">{loadingTree ? '正在加载风格树...' : '选择一个父风格'}</option>
                    {flatNodes.map((item) => (
                      <option key={item.id} value={item.id}>
                        {`${'— '.repeat(item.depth)}${item.name}`}
                      </option>
                    ))}
                  </select>
                </label>
                <div className="admin-reference-soft-card p-4 text-sm text-black/55">
                  <div className="text-xs uppercase tracking-[0.14em] text-black/38">当前父节点</div>
                  <div className="mt-2 font-medium text-[#111827]">{selectedParent?.name || '尚未选择父节点'}</div>
                  <div className="mt-1 break-words leading-6">{selectedParent?.path || '从左侧风格树里选择要挂载到的节点。'}</div>
                </div>
              </div>
            ) : null}

            {draft.parentMode === 'new' ? (
              <div className="mt-5 rounded-[24px] border border-[#e8eceb] bg-[#fbfcfb] p-5">
                <div className="text-sm font-semibold text-[#111827]">新父风格</div>
                <div className="mt-1 text-sm text-black/48">
                  会先创建这个父节点，然后再继续创建当前新风格。
                </div>

                <div className="mt-4 grid gap-4 lg:grid-cols-3">
                  <AdminCountedControl count={countText(newParentDraft.name)} maxLength={INPUT_LIMITS.genre.name}>
                    <input
                      className="admin-studio-input"
                      placeholder="父风格名称"
                      value={newParentDraft.name}
                      maxLength={INPUT_LIMITS.genre.name}
                      onChange={(event) =>
                        setNewParentDraft((current) => ({
                          ...current,
                          name: event.target.value,
                        }))
                      }
                    />
                  </AdminCountedControl>
                  <AdminCountedControl count={countText(newParentDraft.slug)} maxLength={INPUT_LIMITS.genre.slug}>
                    <input
                      className="admin-studio-input"
                      placeholder="父风格 slug（可选）"
                      value={newParentDraft.slug}
                      maxLength={INPUT_LIMITS.genre.slug}
                      onChange={(event) =>
                        setNewParentDraft((current) => ({
                          ...current,
                          slug: event.target.value,
                        }))
                      }
                    />
                  </AdminCountedControl>
                  <AdminCountedControl count={countText(newParentDraft.sortOrder)} maxLength={INPUT_LIMITS.genre.sortOrder}>
                    <input
                      className="admin-studio-input"
                      placeholder="父风格排序值（可选）"
                      value={newParentDraft.sortOrder}
                      maxLength={INPUT_LIMITS.genre.sortOrder}
                      onChange={(event) =>
                        setNewParentDraft((current) => ({
                          ...current,
                          sortOrder: event.target.value,
                        }))
                      }
                    />
                  </AdminCountedControl>
                </div>

                <div className="mt-4 grid gap-3 md:grid-cols-2">
                  {[
                    {
                      key: 'root',
                      title: '创建为根父节点',
                      description: '把这个新父节点直接创建到顶层。',
                    },
                    {
                      key: 'existing',
                      title: '挂到现有节点下',
                      description: '先把父节点挂到现有节点下，再在其下创建当前风格。',
                    },
                  ].map((item) => (
                    <button
                      key={item.key}
                      type="button"
                      onClick={() =>
                        setNewParentDraft((current) => ({
                          ...current,
                          placementMode: item.key as ParentPlacementMode,
                          ancestorParentId: item.key === 'existing' ? current.ancestorParentId : '',
                        }))
                      }
                      className={`rounded-[18px] border px-4 py-4 text-left transition ${
                        newParentDraft.placementMode === item.key
                          ? 'border-[#c8ded0] bg-white'
                          : 'border-[#e8eceb] bg-white/70 hover:border-[#d6ddda]'
                      }`}
                    >
                      <div className="text-sm font-semibold text-[#111827]">{item.title}</div>
                      <div className="mt-2 text-sm leading-6 text-black/50">{item.description}</div>
                    </button>
                  ))}
                </div>

                {newParentDraft.placementMode === 'existing' ? (
                  <div className="mt-4 grid gap-4 xl:grid-cols-[minmax(0,1fr)_320px]">
                    <label className="block">
                      <div className="mb-2 admin-studio-label">新父节点的上级节点</div>
                      <select
                        value={newParentDraft.ancestorParentId}
                        onChange={(event) =>
                          setNewParentDraft((current) => ({
                            ...current,
                            ancestorParentId: event.target.value,
                          }))
                        }
                        className="admin-studio-input"
                      >
                        <option value="">{loadingTree ? '正在加载风格树...' : '选择一个现有节点'}</option>
                        {flatNodes.map((item) => (
                          <option key={item.id} value={item.id}>
                            {`${'— '.repeat(item.depth)}${item.name}`}
                          </option>
                        ))}
                      </select>
                    </label>
                    <div className="admin-reference-soft-card p-4 text-sm text-black/55">
                      <div className="text-xs uppercase tracking-[0.14em] text-black/38">新父节点将挂载到</div>
                      <div className="mt-2 font-medium text-[#111827]">
                        {selectedAncestorParent?.name || '尚未选择节点'}
                      </div>
                      <div className="mt-1 break-words leading-6">
                        {selectedAncestorParent?.path || '如果新父节点不在顶层，请先选择它要挂载到的现有节点。'}
                      </div>
                    </div>
                  </div>
                ) : null}
              </div>
            ) : null}
          </section>

          <section className="admin-reference-card p-6">
            <div className="text-xs uppercase tracking-[0.14em] text-black/38">详情</div>
            <h2 className="mt-2 text-[22px] font-semibold text-[#111827]">风格资料</h2>
            <div className="mt-1 text-sm text-black/48">
              在创建时补齐基础结构字段、多语言文案和参考链接。
            </div>

            <div className="mt-5 grid gap-4 lg:grid-cols-3">
              <AdminCountedControl count={countText(draft.name)} maxLength={INPUT_LIMITS.genre.name}>
                <input
                  className="admin-studio-input"
                  placeholder="风格名称"
                  value={draft.name}
                  maxLength={INPUT_LIMITS.genre.name}
                  onChange={(event) => setDraft((current) => ({ ...current, name: event.target.value }))}
                />
              </AdminCountedControl>
              <AdminCountedControl count={countText(draft.slug)} maxLength={INPUT_LIMITS.genre.slug}>
                <input
                  className="admin-studio-input"
                  placeholder="Slug（可选）"
                  value={draft.slug}
                  maxLength={INPUT_LIMITS.genre.slug}
                  onChange={(event) => setDraft((current) => ({ ...current, slug: event.target.value }))}
                />
              </AdminCountedControl>
              <AdminCountedControl count={countText(draft.sortOrder)} maxLength={INPUT_LIMITS.genre.sortOrder}>
                <input
                  className="admin-studio-input"
                  placeholder="排序值（可选）"
                  value={draft.sortOrder}
                  maxLength={INPUT_LIMITS.genre.sortOrder}
                  onChange={(event) => setDraft((current) => ({ ...current, sortOrder: event.target.value }))}
                />
              </AdminCountedControl>
            </div>

            <div className="mt-4 grid gap-4 lg:grid-cols-2">
              <AdminCountedControl count={countText(draft.nameI18nValue.zh)} maxLength={INPUT_LIMITS.genre.name}>
                <input
                  className="admin-studio-input"
                  placeholder="中文名（可选）"
                  value={draft.nameI18nValue.zh}
                  maxLength={INPUT_LIMITS.genre.name}
                  onChange={(event) =>
                    setDraft((current) => ({
                      ...current,
                      nameI18nValue: { ...current.nameI18nValue, zh: event.target.value },
                    }))
                  }
                />
              </AdminCountedControl>
              <AdminCountedControl count={countText(draft.origin)} maxLength={INPUT_LIMITS.genre.shortText}>
                <input
                  className="admin-studio-input"
                  placeholder="起源地（如 Chicago, United States）"
                  value={draft.origin}
                  maxLength={INPUT_LIMITS.genre.shortText}
                  onChange={(event) => setDraft((current) => ({ ...current, origin: event.target.value }))}
                />
              </AdminCountedControl>
            </div>

            <div className="mt-4 grid gap-4 lg:grid-cols-3">
              <AdminCountedControl count={countText(draft.era)} maxLength={INPUT_LIMITS.genre.shortText}>
                <input
                  className="admin-studio-input"
                  placeholder="年代（如 Early 1980s）"
                  value={draft.era}
                  maxLength={INPUT_LIMITS.genre.shortText}
                  onChange={(event) => setDraft((current) => ({ ...current, era: event.target.value }))}
                />
              </AdminCountedControl>
              <AdminCountedControl count={countText(draft.bpm)} maxLength={INPUT_LIMITS.genre.shortText}>
                <input
                  className="admin-studio-input"
                  placeholder="BPM（如 118-130）"
                  value={draft.bpm}
                  maxLength={INPUT_LIMITS.genre.shortText}
                  onChange={(event) => setDraft((current) => ({ ...current, bpm: event.target.value }))}
                />
              </AdminCountedControl>
              <AdminCountedControl count={countText(draft.backgroundImageURL)} maxLength={INPUT_LIMITS.common.url}>
                <input
                  className="admin-studio-input"
                  placeholder="背景图链接（可选）"
                  value={draft.backgroundImageURL}
                  maxLength={INPUT_LIMITS.common.url}
                  onChange={(event) => setDraft((current) => ({ ...current, backgroundImageURL: event.target.value }))}
                />
              </AdminCountedControl>
            </div>

            <div className="mt-4 grid gap-4 lg:grid-cols-2">
              <AdminCountedControl count={countText(draft.spotifyTrackURL)} maxLength={INPUT_LIMITS.common.url}>
                <input
                  className="admin-studio-input"
                  placeholder="Spotify 曲目链接（可选）"
                  value={draft.spotifyTrackURL}
                  maxLength={INPUT_LIMITS.common.url}
                  onChange={(event) => setDraft((current) => ({ ...current, spotifyTrackURL: event.target.value }))}
                />
              </AdminCountedControl>
              <AdminCountedControl count={countText(draft.wikipediaURL)} maxLength={INPUT_LIMITS.common.url}>
                <input
                  className="admin-studio-input"
                  placeholder="Wikipedia 链接（可选）"
                  value={draft.wikipediaURL}
                  maxLength={INPUT_LIMITS.common.url}
                  onChange={(event) => setDraft((current) => ({ ...current, wikipediaURL: event.target.value }))}
                />
              </AdminCountedControl>
            </div>

            <div className="mt-4 grid gap-4 xl:grid-cols-2">
              <LocalizedTextField
                label="风格描述"
                kind="textarea"
                value={draft.descriptionValue}
                placeholder="先填写中文描述"
                hint="右侧按钮可继续补充英文、日文和英文全称版本。"
                maxLength={INPUT_LIMITS.genre.description}
                onPrimaryChange={(value) =>
                  setDraft((current) => ({
                    ...current,
                    descriptionValue: { ...current.descriptionValue, zh: value },
                  }))
                }
                onOpenOverlay={() => setActiveLocalizedField('description')}
              />
              <LocalizedTextField
                label="示例"
                kind="textarea"
                value={draft.exampleValue}
                placeholder="填写中文示例或代表性语境"
                hint="用于补充典型表达、代表作品或场景。"
                maxLength={INPUT_LIMITS.genre.example}
                onPrimaryChange={(value) =>
                  setDraft((current) => ({
                    ...current,
                    exampleValue: { ...current.exampleValue, zh: value },
                  }))
                }
                onOpenOverlay={() => setActiveLocalizedField('example')}
              />
            </div>
          </section>

          <section className="admin-reference-card p-6">
            <div className="flex items-center justify-between gap-3">
              <div>
                <div className="text-xs uppercase tracking-[0.14em] text-black/38">声音线索</div>
                <h2 className="mt-2 text-[22px] font-semibold text-[#111827]">声音线索歌曲</h2>
                <div className="mt-1 text-sm text-black/48">
                  可添加多首代表曲目，并补充 Spotify、Apple Music、网易云、SoundCloud、Beatport 链接。
                </div>
              </div>
              <button
                type="button"
                onClick={addSoundCueTrackDraft}
                className="rounded-full border border-[#d7ded9] bg-white px-4 py-2 text-sm text-[#18211f]"
              >
                <span className="inline-flex items-center gap-2">
                  <Plus className="h-4 w-4" />
                  添加歌曲
                </span>
              </button>
            </div>

            <div className="mt-4 space-y-4">
              {soundCueTrackDrafts.map((item, index) => (
                <div key={item.id} className="rounded-[18px] border border-[#e8eceb] bg-white p-4">
                  <div className="flex items-center justify-between gap-3">
                    <div className="text-sm font-semibold text-[#111827]">声音线索歌曲 #{index + 1}</div>
                    <button
                      type="button"
                      className="rounded-full border border-[#ead6d6] bg-white p-2 text-[#8b3a3a]"
                      onClick={() => removeSoundCueTrackDraft(item.id)}
                      aria-label="删除声音线索歌曲"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>

                  <div className="mt-3 grid gap-4 lg:grid-cols-2">
                    <AdminCountedControl count={countText(item.title)} maxLength={INPUT_LIMITS.genre.soundCueTrackTitle}>
                      <input
                        className="admin-reference-soft-card w-full px-4 py-3 text-sm"
                        placeholder="歌名"
                        value={item.title}
                        maxLength={INPUT_LIMITS.genre.soundCueTrackTitle}
                        onChange={(event) => updateSoundCueTrackDraft(item.id, { title: event.target.value })}
                      />
                    </AdminCountedControl>
                    <AdminCountedControl count={countText(item.artist)} maxLength={INPUT_LIMITS.genre.soundCueTrackArtist}>
                      <input
                        className="admin-reference-soft-card w-full px-4 py-3 text-sm"
                        placeholder="艺人"
                        value={item.artist}
                        maxLength={INPUT_LIMITS.genre.soundCueTrackArtist}
                        onChange={(event) => updateSoundCueTrackDraft(item.id, { artist: event.target.value })}
                      />
                    </AdminCountedControl>
                  </div>

                  <div className="mt-3 grid gap-4 lg:grid-cols-2">
                    {[
                      ['Spotify', 'spotifyUrl', 'https://open.spotify.com/track/...'],
                      ['Apple Music', 'appleMusicUrl', 'https://music.apple.com/...'],
                      ['网易云音乐', 'neteaseUrl', 'https://music.163.com/...'],
                      ['SoundCloud', 'soundcloudUrl', 'https://soundcloud.com/...'],
                      ['Beatport', 'beatportUrl', 'https://www.beatport.com/track/...'],
                    ].map(([label, key, placeholder]) => (
                      <AdminCountedControl key={key} count={countText(item[key as keyof SoundCueTrackDraft] as string)} maxLength={INPUT_LIMITS.common.url}>
                        <input
                          className="admin-reference-soft-card w-full px-4 py-3 text-sm"
                          placeholder={`${label} 链接`}
                          value={item[key as keyof SoundCueTrackDraft] as string}
                          maxLength={INPUT_LIMITS.common.url}
                          onChange={(event) => updateSoundCueTrackDraft(item.id, { [key]: event.target.value } as Partial<SoundCueTrackDraft>)}
                        />
                      </AdminCountedControl>
                    ))}
                  </div>
                </div>
              ))}

              {!soundCueTrackDrafts.length ? (
                <div className="rounded-[16px] border border-dashed border-[#d7ded9] px-4 py-6 text-sm text-black/48">
                  暂无声音线索歌曲。可先创建流派，也可以现在一次性把代表歌曲和各平台链接补齐。
                </div>
              ) : null}
            </div>
          </section>

          <section className="admin-reference-card p-6">
            <div className="flex items-center justify-between gap-3">
              <div>
                <div className="text-xs uppercase tracking-[0.14em] text-black/38">绑定</div>
                <h2 className="mt-2 text-[22px] font-semibold text-[#111827]">代表艺人</h2>
                <div className="mt-1 text-sm text-black/48">
                  每行保留一个艺人名称，并可选绑定到库内 DJ。
                </div>
              </div>
              <button
                type="button"
                onClick={addKeyArtistDraft}
                className="rounded-full border border-[#d7ded9] bg-white px-4 py-2 text-sm text-[#18211f]"
              >
                <span className="inline-flex items-center gap-2">
                  <Plus className="h-4 w-4" />
                  添加艺人
                </span>
              </button>
            </div>

            <div className="mt-4 space-y-4">
              {keyArtistDrafts.map((item, index) => {
                const currentBinding = item.dj
                  ? {
                      id: item.dj.id,
                      name: item.dj.name,
                      subtitle: null,
                      imageUrl: item.dj.avatarMediumUrl || item.dj.avatarUrl || null,
                    }
                  : null;

                return (
                  <div key={item.id} className="rounded-[18px] border border-[#e8eceb] bg-white p-4">
                    <div className="flex items-center justify-between gap-3">
                      <div className="text-sm font-semibold text-[#111827]">代表艺人 #{index + 1}</div>
                      <button
                        type="button"
                        className="rounded-full border border-[#ead6d6] bg-white p-2 text-[#8b3a3a]"
                        onClick={() => removeKeyArtistDraft(item.id)}
                        aria-label="删除代表艺人"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>

                    <div className="mt-3">
                      <AdminCountedControl count={countText(item.name)} maxLength={INPUT_LIMITS.genre.keyArtistName}>
                        <input
                          className="admin-reference-soft-card w-full px-4 py-3 text-sm"
                          placeholder="艺人名称"
                          value={item.name}
                          maxLength={INPUT_LIMITS.genre.keyArtistName}
                          onChange={(event) => updateKeyArtistDraft(item.id, { name: event.target.value })}
                        />
                      </AdminCountedControl>
                    </div>

                    <div className="mt-3">
                      <EntityBindingField
                        kind="dj"
                        mode="single"
                        seedQuery={item.name}
                        items={currentBinding ? [currentBinding] : []}
                        title="已绑定 DJ"
                        emptyLabel="当前艺人还没有绑定到库内 DJ。"
                        onAdd={(value) =>
                          updateKeyArtistDraft(item.id, {
                            djId: value.id,
                            dj: {
                              id: value.id,
                              name: value.name,
                              avatarUrl: value.imageUrl || null,
                              avatarMediumUrl: value.imageUrl || null,
                            },
                          })
                        }
                        onRemove={() =>
                          updateKeyArtistDraft(item.id, {
                            djId: null,
                            dj: null,
                          })
                        }
                      />
                    </div>
                  </div>
                );
              })}

              {!keyArtistDrafts.length ? (
                <div className="rounded-[16px] border border-dashed border-[#d7ded9] px-4 py-6 text-sm text-black/48">
                  暂无代表艺人。如确有需要，再为当前风格补充代表艺人行。
                </div>
              ) : null}
            </div>
          </section>
        </section>
      )}

      <MultilingualEditorOverlay
        open={activeLocalizedField === 'description'}
        title="风格描述"
        kind="textarea"
        value={draft.descriptionValue}
        maxLength={INPUT_LIMITS.genre.description}
        onChange={(locale, value) => updateLocalizedValue('description', locale, value)}
        onClose={() => setActiveLocalizedField(null)}
      />

      <MultilingualEditorOverlay
        open={activeLocalizedField === 'example'}
        title="风格示例"
        kind="textarea"
        value={draft.exampleValue}
        maxLength={INPUT_LIMITS.genre.example}
        onChange={(locale, value) => updateLocalizedValue('example', locale, value)}
        onClose={() => setActiveLocalizedField(null)}
      />
    </AdminContentLayout>
  );
}
