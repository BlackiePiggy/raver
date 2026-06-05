'use client';

import Link from 'next/link';
import { ChevronDown, ChevronRight, Languages, Plus, Trash2 } from 'lucide-react';
import { useCallback, useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import AdminCountedControl from '@/components/admin/AdminCountedControl';
import EditableEntityBindingCard from '@/components/admin/EditableEntityBindingCard';
import {
  MultilingualEditorOverlay,
  type LocalizedLocaleKey,
  type LocalizedTextValue,
  localizedTextFilledLocaleLabels,
} from '@/components/admin/LocalizedTextEditor';
import { genreAdminApi, type GenreAdminNode, type GenreKeyArtistBinding } from '@/features/admin-content/genre-admin';
import { INPUT_LIMITS, countText } from '@/lib/input-rules';

const flattenTree = (items: GenreAdminNode[]): GenreAdminNode[] =>
  items.flatMap((item) => [item, ...flattenTree(item.children ?? [])]);

const normalizeLocalizedValue = (value?: Record<string, string> | null, fallback = ''): LocalizedTextValue => ({
  zh: value?.zh || fallback || '',
  en: value?.en || '',
  ja: value?.ja || '',
  enFull: value?.enFull || '',
});

type LocalizedFieldKey = 'description' | 'example';

type KeyArtistDraft = {
  id: string;
  name: string;
  djId: string | null;
  dj: GenreKeyArtistBinding['dj'];
};

function GenreTreeNode({
  item,
  selectedId,
  expandedIds,
  onSelect,
  onToggle,
  level = 0,
}: {
  item: GenreAdminNode;
  selectedId: string;
  expandedIds: Set<string>;
  onSelect: (id: string) => void;
  onToggle: (id: string) => void;
  level?: number;
}) {
  const hasChildren = Boolean(item.children?.length);
  const isExpanded = expandedIds.has(item.id);
  const isSelected = selectedId === item.id;

  return (
    <div className="space-y-2">
      <div
        className={`admin-reference-soft-card rounded-[18px] px-4 py-3 ${
          isSelected ? 'border border-[#d7e8dc] bg-[#f6fbf7]' : ''
        }`}
        style={{ marginLeft: `${level * 18}px` }}
      >
        <div className="flex items-start gap-3">
          <button
            type="button"
            className="mt-0.5 rounded-full p-1 text-black/45 transition hover:bg-black/5 disabled:opacity-30"
            onClick={() => hasChildren && onToggle(item.id)}
            disabled={!hasChildren}
            aria-label={hasChildren ? 'Expand or collapse child genres' : 'No child genres'}
          >
            {hasChildren ? (
              isExpanded ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />
            ) : (
              <div className="h-4 w-4" />
            )}
          </button>
          <button type="button" className="min-w-0 flex-1 text-left" onClick={() => onSelect(item.id)}>
            <div className="text-sm font-semibold text-[#111827]">{item.name}</div>
            <div className="mt-1 break-words text-xs leading-5 text-black/45">{item.path}</div>
          </button>
          <span className="admin-reference-chip shrink-0">{item.children?.length ?? 0}</span>
        </div>
      </div>

      {hasChildren && isExpanded ? (
        <div className="space-y-2">
          {item.children!.map((child) => (
            <GenreTreeNode
              key={child.id}
              item={child}
              selectedId={selectedId}
              expandedIds={expandedIds}
              onSelect={onSelect}
              onToggle={onToggle}
              level={level + 1}
            />
          ))}
        </div>
      ) : null}
    </div>
  );
}

export default function AdminGenresPage() {
  const [tree, setTree] = useState<GenreAdminNode[]>([]);
  const [expandedIds, setExpandedIds] = useState<Set<string>>(new Set());
  const [selectedId, setSelectedId] = useState('');
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [descriptionValue, setDescriptionValue] = useState<LocalizedTextValue>(() => normalizeLocalizedValue(null));
  const [exampleValue, setExampleValue] = useState<LocalizedTextValue>(() => normalizeLocalizedValue(null));
  const [spotifyTrackURL, setSpotifyTrackURL] = useState('');
  const [wikipediaURL, setWikipediaURL] = useState('');
  const [activeLocalizedField, setActiveLocalizedField] = useState<LocalizedFieldKey | null>(null);
  const [keyArtistDrafts, setKeyArtistDrafts] = useState<KeyArtistDraft[]>([]);

  const flatNodes = useMemo(() => flattenTree(tree), [tree]);
  const selectedNode = flatNodes.find((item) => item.id === selectedId) ?? null;

  const openLocalizedField = (field: LocalizedFieldKey) => {
    setActiveLocalizedField(field);
  };

  const loadTree = useCallback(async (preferredId?: string) => {
    setLoading(true);
    setError('');
    try {
      const payload = await genreAdminApi.fetchTree();
      setTree(payload.items);
      const nextFlat = flattenTree(payload.items);
      const nextId = preferredId || nextFlat[0]?.id || '';
      setSelectedId(nextId);
      setExpandedIds((current) => {
        const next = new Set(current);
        nextFlat.forEach((item) => {
          const segments = item.path.split(' / ');
          if (segments.length > 1 && item.parentId) next.add(item.parentId);
        });
        return next;
      });
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '加载风格树失败。');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadTree();
  }, [loadTree]);

  useEffect(() => {
    if (!selectedNode) return;
    setDescriptionValue(normalizeLocalizedValue(selectedNode.descriptionI18n, selectedNode.description || ''));
    setExampleValue(normalizeLocalizedValue(selectedNode.exampleI18n, selectedNode.example || ''));
    setSpotifyTrackURL(selectedNode.spotifyTrackURL || '');
    setWikipediaURL(selectedNode.wikipediaURL || '');
    setKeyArtistDrafts(
      (selectedNode.keyArtistBindings.length
        ? selectedNode.keyArtistBindings
        : selectedNode.keyArtists.map((name) => ({ name, djId: null, dj: null }))).map((item, index) => ({
        id: `${selectedNode.id}-artist-${index}-${item.name}`,
        name: item.name,
        djId: item.djId,
        dj: item.dj,
      }))
    );
  }, [selectedNode]);

  const toggleExpanded = (id: string) => {
    setExpandedIds((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const handleSaveContent = async () => {
    if (!selectedNode) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await genreAdminApi.updateContent(selectedNode.id, {
        description: descriptionValue.zh,
        descriptionI18n: descriptionValue,
        example: exampleValue.zh,
        exampleI18n: exampleValue,
        spotifyTrackURL: spotifyTrackURL.trim() || null,
        wikipediaURL: wikipediaURL.trim() || null,
      });
      await genreAdminApi.updateKeyArtists(selectedNode.id, {
        keyArtists: keyArtistDrafts.map((item) => item.name.trim()).filter(Boolean),
        bindings: keyArtistDrafts
          .map((item) => ({
            name: item.name.trim(),
            djId: item.djId,
          }))
          .filter((item) => item.name),
      });
      setNotice('风格内容已更新。');
      await loadTree(selectedNode.id);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '更新风格内容失败。');
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteNode = async () => {
    if (!selectedNode) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await genreAdminApi.deleteNode(selectedNode.id);
      setNotice('风格节点已删除。');
      await loadTree();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '删除风格节点失败。');
    } finally {
      setSaving(false);
    }
  };

  const handleAutoMatch = async () => {
    setSaving(true);
    setError('');
    setNotice('');
    try {
      const result = await genreAdminApi.autoMatchKeyArtists();
      setNotice(`自动匹配完成：共匹配 ${result.matched}/${result.totalArtists} 位艺人，更新了 ${result.updatedGenres} 条风格。`);
      await loadTree(selectedId);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '自动匹配代表艺人失败。');
    } finally {
      setSaving(false);
    }
  };

  const updateLocalizedValue = (field: LocalizedFieldKey, locale: LocalizedLocaleKey, value: string) => {
    if (field === 'description') {
      setDescriptionValue((current) => ({ ...current, [locale]: value }));
      return;
    }
    setExampleValue((current) => ({ ...current, [locale]: value }));
  };

  const addKeyArtistDraft = () => {
    setKeyArtistDrafts((current) => [
      ...current,
      {
        id: `draft-${Date.now()}-${current.length}`,
        name: '',
        djId: null,
        dj: null,
      },
    ]);
  };

  const updateKeyArtistDraft = (id: string, patch: Partial<KeyArtistDraft>) => {
    setKeyArtistDrafts((current) =>
      current.map((item) => (item.id === id ? { ...item, ...patch } : item))
    );
  };

  const removeKeyArtistDraft = (id: string) => {
    setKeyArtistDrafts((current) => current.filter((item) => item.id !== id));
  };

  return (
    <AdminContentLayout
      title="风格管理"
      description="维护风格层级树、多语言描述，以及可复用的代表艺人 DJ 绑定。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
            返回内容后台
          </Link>
          <Link href="/admin/content/genres/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            新建风格
          </Link>
        </>
      }
    >
      <section className="space-y-5">
        {error ? <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] p-4 text-sm text-[#6a3530]">{error}</div> : null}
        {notice ? <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-4 text-sm text-[#2f4027]">{notice}</div> : null}

        <div className="grid gap-5 xl:grid-cols-[560px_minmax(0,1fr)]">
          <section className="admin-reference-card p-5">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h2 className="text-[20px] font-semibold text-[#111827]">风格树</h2>
                <div className="mt-1 text-sm text-black/48">支持展开多级节点并查看完整路径。</div>
              </div>
              <button type="button" className="rounded-full border border-[#d7ded9] px-4 py-2 text-sm" onClick={handleAutoMatch} disabled={saving}>
                自动匹配代表艺人
              </button>
            </div>

            <div className="mt-4 max-h-[780px] overflow-auto pr-2">
              {tree.length ? (
                <div className="space-y-2">
                  {tree.map((item) => (
                    <GenreTreeNode
                      key={item.id}
                      item={item}
                      selectedId={selectedId}
                      expandedIds={expandedIds}
                      onSelect={setSelectedId}
                      onToggle={toggleExpanded}
                    />
                  ))}
                </div>
              ) : (
                <div className="admin-reference-soft-card p-4 text-sm text-black/48">{loading ? '加载中...' : '暂无风格数据。'}</div>
              )}
            </div>
          </section>

          <section className="admin-reference-card p-5">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h2 className="text-[20px] font-semibold text-[#111827]">节点编辑</h2>
                <div className="mt-1 text-sm text-black/48">{selectedNode ? selectedNode.path : '请先从左侧风格树中选择一个节点。'}</div>
              </div>
              <button type="button" className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm" disabled={!selectedNode || saving} onClick={handleDeleteNode}>
                删除节点
              </button>
            </div>

            {selectedNode ? (
              <div className="mt-4 space-y-5">
                <div className="admin-reference-soft-card p-4 text-sm text-black/65">
                  <div>名称：{selectedNode.name}</div>
                  <div className="mt-1">路径：{selectedNode.path}</div>
                </div>

                <div className="grid gap-4 xl:grid-cols-2">
                  <div className="admin-reference-soft-card p-4">
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <div className="text-sm font-semibold text-[#111827]">风格描述</div>
                        <div className="mt-1 text-xs text-black/48">
                          已填写语言：{localizedTextFilledLocaleLabels(descriptionValue).join(' / ') || '暂无'}
                        </div>
                      </div>
                      <button
                        type="button"
                        className="rounded-full border border-[#d7ded9] bg-white px-3 py-2 text-sm text-[#18211f]"
                        onClick={() => openLocalizedField('description')}
                      >
                        <span className="inline-flex items-center gap-2">
                          <Languages className="h-4 w-4" />
                          多语言
                        </span>
                      </button>
                    </div>
                    <div className="mt-3 rounded-[16px] border border-[#e8eceb] bg-white px-4 py-3 text-sm leading-7 text-[#111827]">
                      {descriptionValue.zh || '还没有中文描述。'}
                    </div>
                  </div>

                  <div className="admin-reference-soft-card p-4">
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <div className="text-sm font-semibold text-[#111827]">风格示例</div>
                        <div className="mt-1 text-xs text-black/48">
                          已填写语言：{localizedTextFilledLocaleLabels(exampleValue).join(' / ') || '暂无'}
                        </div>
                      </div>
                      <button
                        type="button"
                        className="rounded-full border border-[#d7ded9] bg-white px-3 py-2 text-sm text-[#18211f]"
                        onClick={() => openLocalizedField('example')}
                      >
                        <span className="inline-flex items-center gap-2">
                          <Languages className="h-4 w-4" />
                          多语言
                        </span>
                      </button>
                    </div>
                    <div className="mt-3 rounded-[16px] border border-[#e8eceb] bg-white px-4 py-3 text-sm leading-7 text-[#111827]">
                      {exampleValue.zh || '还没有示例内容。'}
                    </div>
                  </div>
                </div>

                <div className="grid gap-4 xl:grid-cols-2">
                  <label className="block">
                    <div className="mb-2 text-sm font-semibold text-[#111827]">Spotify 曲目链接</div>
                    <AdminCountedControl count={countText(spotifyTrackURL)} maxLength={INPUT_LIMITS.common.url}>
                      <input
                        className="admin-studio-input"
                        placeholder="Spotify 曲目链接"
                        value={spotifyTrackURL}
                        maxLength={INPUT_LIMITS.common.url}
                        onChange={(event) => setSpotifyTrackURL(event.target.value)}
                      />
                    </AdminCountedControl>
                  </label>
                  <label className="block">
                    <div className="mb-2 text-sm font-semibold text-[#111827]">Wikipedia 链接</div>
                    <AdminCountedControl count={countText(wikipediaURL)} maxLength={INPUT_LIMITS.common.url}>
                      <input
                        className="admin-studio-input"
                        placeholder="Wikipedia 链接"
                        value={wikipediaURL}
                        maxLength={INPUT_LIMITS.common.url}
                        onChange={(event) => setWikipediaURL(event.target.value)}
                      />
                    </AdminCountedControl>
                  </label>
                </div>

                <div className="admin-reference-soft-card p-4">
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <div className="text-sm font-semibold text-[#111827]">代表艺人</div>
                      <div className="mt-1 text-xs text-black/48">每一行保留一个艺人名称，并绑定一个 DJ。</div>
                    </div>
                    <button type="button" className="rounded-full border border-[#d7ded9] bg-white px-3 py-2 text-sm text-[#18211f]" onClick={addKeyArtistDraft}>
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
                        <EditableEntityBindingCard
                          key={item.id}
                          header={`代表艺人 #${index + 1}`}
                          name={item.name}
                          nameValue={item.name}
                          namePlaceholder="艺人名称"
                          nameMaxLength={INPUT_LIMITS.genre.keyArtistName}
                          bindingKind="dj"
                          binding={currentBinding}
                          seedQuery={item.name}
                          bindingTitle="已绑定 DJ"
                          bindingEmptyLabel="当前代表艺人还没有关联到库内 DJ。"
                          confirmedMeta={null}
                          boundLabel="已绑定"
                          unboundLabel="未绑定"
                          onNameChange={(value) => updateKeyArtistDraft(item.id, { name: value })}
                          onAddBinding={(value) =>
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
                          onRemoveBinding={() =>
                            updateKeyArtistDraft(item.id, {
                              djId: null,
                              dj: null,
                            })
                          }
                          onDelete={() => removeKeyArtistDraft(item.id)}
                        />
                      );
                    })}

                    {!keyArtistDrafts.length ? (
                      <div className="rounded-[16px] border border-dashed border-[#d7ded9] px-4 py-6 text-sm text-black/48">
                        暂无代表艺人，可通过上方按钮按需添加。
                      </div>
                    ) : null}
                  </div>
                </div>

                <button type="button" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white" disabled={saving} onClick={handleSaveContent}>
                  {saving ? '保存中...' : '保存节点内容'}
                </button>
              </div>
            ) : (
              <div className="admin-reference-soft-card mt-4 p-4 text-sm text-black/48">{loading ? '加载中...' : '请先选择一个风格节点查看详情。'}</div>
            )}
          </section>
        </div>
      </section>

      <MultilingualEditorOverlay
        open={activeLocalizedField === 'description'}
        title="风格描述"
        kind="textarea"
        value={descriptionValue}
        maxLength={INPUT_LIMITS.genre.description}
        onChange={(locale, value) => updateLocalizedValue('description', locale, value)}
        onClose={() => setActiveLocalizedField(null)}
      />

      <MultilingualEditorOverlay
        open={activeLocalizedField === 'example'}
        title="风格示例"
        kind="textarea"
        value={exampleValue}
        maxLength={INPUT_LIMITS.genre.example}
        onChange={(locale, value) => updateLocalizedValue('example', locale, value)}
        onClose={() => setActiveLocalizedField(null)}
      />
    </AdminContentLayout>
  );
}
