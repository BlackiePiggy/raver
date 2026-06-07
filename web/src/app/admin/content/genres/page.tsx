'use client';

import Link from 'next/link';
import { ChevronDown, ChevronRight, Plus, Trash2, Pencil, Search, RefreshCw, ExternalLink } from 'lucide-react';
import { useCallback, useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import AdminCountedControl from '@/components/admin/AdminCountedControl';
import EntityBindingField from '@/components/admin/EntityBindingField';
import {
  LocalizedTextField,
  MultilingualEditorOverlay,
  type LocalizedLocaleKey,
  type LocalizedTextValue,
} from '@/components/admin/LocalizedTextEditor';
import { genreAdminApi, type GenreAdminNode, type GenreKeyArtistBinding } from '@/features/admin-content/genre-admin';
import { INPUT_LIMITS, countText } from '@/lib/input-rules';

// ─── Helpers ──────────────────────────────────────────────────────────────────

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

type StructureDraft = {
  name: string;
  slug: string;
  sortOrder: string;
  parentId: string;
};

const emptyLocalizedValue = (): LocalizedTextValue => ({
  zh: '',
  en: '',
  ja: '',
  enFull: '',
});

const collectDescendantIds = (node: GenreAdminNode | null): Set<string> => {
  const ids = new Set<string>();
  if (!node) return ids;
  const walk = (items: GenreAdminNode[]) => {
    for (const item of items) {
      ids.add(item.id);
      if (item.children?.length) {
        walk(item.children);
      }
    }
  };
  walk(node.children ?? []);
  return ids;
};

// ─── Right-side tree node ─────────────────────────────────────────────────────

function TreeNode({
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
    <div>
      <div
        className={`group flex items-center gap-1 rounded-lg px-2 py-1.5 transition-colors cursor-pointer ${
          isSelected
            ? 'bg-emerald-50 text-emerald-800'
            : 'hover:bg-gray-100 text-gray-700'
        }`}
        style={{ paddingLeft: `${8 + level * 16}px` }}
        onClick={() => onSelect(item.id)}
      >
        {/* Drag handle */}
        <span className="flex-shrink-0 text-gray-300 opacity-0 group-hover:opacity-100 transition-opacity cursor-grab">
          <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="currentColor">
            <circle cx={9} cy={6} r={1.5} /><circle cx={15} cy={6} r={1.5} />
            <circle cx={9} cy={12} r={1.5} /><circle cx={15} cy={12} r={1.5} />
            <circle cx={9} cy={18} r={1.5} /><circle cx={15} cy={18} r={1.5} />
          </svg>
        </span>

        {/* Expand toggle */}
        <button
          type="button"
          onClick={(e) => { e.stopPropagation(); if (hasChildren) onToggle(item.id); }}
          className={`flex-shrink-0 rounded p-0.5 transition-colors ${hasChildren ? 'hover:bg-gray-200' : 'opacity-0 pointer-events-none'}`}
        >
          {hasChildren ? (
            isExpanded
              ? <ChevronDown className={`h-3.5 w-3.5 ${isSelected ? 'text-emerald-700' : 'text-gray-500'}`} />
              : <ChevronRight className={`h-3.5 w-3.5 ${isSelected ? 'text-emerald-700' : 'text-gray-500'}`} />
          ) : (
            <span className="h-3.5 w-3.5 block" />
          )}
        </button>

        {/* Label + count */}
        <span className={`flex-1 min-w-0 truncate text-sm font-medium ${isSelected ? 'text-emerald-800 font-semibold' : ''}`}>
          {item.name}
        </span>
        <span className={`flex-shrink-0 text-xs ${isSelected ? 'text-emerald-600' : 'text-gray-400'}`}>
          ({item.children?.length ?? 0})
        </span>
      </div>

      {hasChildren && isExpanded && (
        <div>
          {item.children!.map((child) => (
            <TreeNode
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
      )}
    </div>
  );
}

// ─── Section card wrapper ─────────────────────────────────────────────────────

function SectionCard({ title, action, children }: { title: string; action?: React.ReactNode; children: React.ReactNode }) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
      <div className="flex items-center justify-between border-b border-gray-100 px-6 py-4">
        <h2 className="text-base font-bold text-gray-900">{title}</h2>
        {action}
      </div>
      <div className="px-6 py-5">{children}</div>
    </div>
  );
}

// ─── Inline field display + edit button ──────────────────────────────────────

function FieldCell({
  label,
  value,
  onEdit,
  monospace = false,
  badge,
  externalHref,
  suffix,
}: {
  label: string;
  value: string;
  onEdit?: () => void;
  monospace?: boolean;
  badge?: React.ReactNode;
  externalHref?: string;
  suffix?: string;
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="flex items-center gap-2 rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 min-h-[38px]">
        {badge}
        <span className={`flex-1 min-w-0 truncate text-sm ${monospace ? 'font-mono' : ''} ${value ? 'text-gray-800' : 'text-gray-400'}`}>
          {value || '—'}
        </span>
        {externalHref && value && (
          <a href={externalHref} target="_blank" rel="noopener noreferrer" className="flex-shrink-0 text-gray-400 hover:text-gray-600 transition-colors">
            <ExternalLink className="h-3.5 w-3.5" />
          </a>
        )}
        {suffix && <span className="flex-shrink-0 text-xs text-gray-400">{suffix}</span>}
        {onEdit && (
          <button
            type="button"
            onClick={onEdit}
            className="flex-shrink-0 rounded p-0.5 text-gray-400 hover:text-gray-700 hover:bg-gray-200 transition-colors"
          >
            <Pencil className="h-3.5 w-3.5" />
          </button>
        )}
      </div>
    </div>
  );
}

function ReadOnlyTextBlock({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div>
      <div className="mb-2 text-xs text-gray-500">{label}</div>
      <div className="rounded-lg border border-gray-200 bg-gray-50 px-4 py-3 text-sm leading-relaxed text-gray-800">
        {value || '—'}
      </div>
    </div>
  );
}

function ReadOnlyUrlField({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="flex min-h-[44px] items-center gap-2 rounded-lg border border-gray-200 bg-gray-50 px-3 py-2">
        <span className={`min-w-0 flex-1 break-all font-mono text-sm ${value ? 'text-gray-800' : 'text-gray-400'}`}>
          {value || '—'}
        </span>
        {value ? (
          <a
            href={value}
            target="_blank"
            rel="noopener noreferrer"
            className="flex-shrink-0 text-gray-400 transition-colors hover:text-gray-600"
          >
            <ExternalLink className="h-3.5 w-3.5" />
          </a>
        ) : null}
      </div>
    </div>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────

export default function AdminGenresPage() {
  const [tree, setTree] = useState<GenreAdminNode[]>([]);
  const [expandedIds, setExpandedIds] = useState<Set<string>>(new Set());
  const [selectedId, setSelectedId] = useState('');
  const [treeSearch, setTreeSearch] = useState('');
  const [isEditing, setIsEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const [structureDraft, setStructureDraft] = useState<StructureDraft>({
    name: '',
    slug: '',
    sortOrder: '',
    parentId: '',
  });
  const [descriptionValue, setDescriptionValue] = useState<LocalizedTextValue>(emptyLocalizedValue);
  const [exampleValue, setExampleValue] = useState<LocalizedTextValue>(emptyLocalizedValue);
  const [activeLocalizedField, setActiveLocalizedField] = useState<LocalizedFieldKey | null>(null);

  const [spotifyTrackURL, setSpotifyTrackURL] = useState('');
  const [wikipediaURL, setWikipediaURL] = useState('');
  const [keyArtistDrafts, setKeyArtistDrafts] = useState<KeyArtistDraft[]>([]);

  const flatNodes = useMemo(() => flattenTree(tree), [tree]);
  const selectedNode = flatNodes.find((item) => item.id === selectedId) ?? null;
  const selectedParentNode = useMemo(
    () => (selectedNode?.parentId ? flatNodes.find((item) => item.id === selectedNode.parentId) ?? null : null),
    [flatNodes, selectedNode]
  );
  const selectedNodeDescendantIds = useMemo(() => collectDescendantIds(selectedNode), [selectedNode]);
  const parentOptions = useMemo(
    () => flatNodes.filter((item) => item.id !== selectedId && !selectedNodeDescendantIds.has(item.id)),
    [flatNodes, selectedId, selectedNodeDescendantIds]
  );
  const readonlyKeyArtistBindings = useMemo(
    () =>
      selectedNode
        ? (selectedNode.keyArtistBindings.length
            ? selectedNode.keyArtistBindings
            : selectedNode.keyArtists.map((name) => ({ name, djId: null, dj: null })))
        : [],
    [selectedNode]
  );

  // Filtered tree search (flat match, highlighted in tree by id set)
  const searchMatchIds = useMemo(() => {
    if (!treeSearch.trim()) return null;
    const q = treeSearch.toLowerCase();
    return new Set(flatNodes.filter((n) => n.name.toLowerCase().includes(q)).map((n) => n.id));
  }, [treeSearch, flatNodes]);

  // Breadcrumb from selected node path
  const breadcrumbParts = useMemo(() => {
    if (!selectedNode) return [];
    return selectedNode.path.split(' / ').filter(Boolean);
  }, [selectedNode]);

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
          if (item.parentId) next.add(item.parentId);
        });
        return next;
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : '加载风格树失败。');
    } finally {
      setLoading(false);
    }
  }, []);

  const hydrateDraftFromNode = useCallback((node: GenreAdminNode | null) => {
    if (!node) return;
    setStructureDraft({
      name: node.name || '',
      slug: node.slug || '',
      sortOrder: node.sortOrder != null ? String(node.sortOrder) : '',
      parentId: node.parentId || '',
    });
    setDescriptionValue(normalizeLocalizedValue(node.descriptionI18n, node.description || ''));
    setExampleValue(normalizeLocalizedValue(node.exampleI18n, node.example || ''));
    setSpotifyTrackURL(node.spotifyTrackURL || '');
    setWikipediaURL(node.wikipediaURL || '');
    setKeyArtistDrafts(
      (node.keyArtistBindings.length
        ? node.keyArtistBindings
        : node.keyArtists.map((name) => ({ name, djId: null, dj: null }))
      ).map((item, index) => ({
        id: `${node.id}-artist-${index}-${item.name}`,
        name: item.name,
        djId: item.djId,
        dj: item.dj,
      }))
    );
  }, []);

  useEffect(() => { void loadTree(); }, [loadTree]);

  useEffect(() => {
    if (!selectedNode) return;
    hydrateDraftFromNode(selectedNode);
    setIsEditing(false);
    setActiveLocalizedField(null);
  }, [hydrateDraftFromNode, selectedNode]);

  const toggleExpanded = (id: string) =>
    setExpandedIds((cur) => { const next = new Set(cur); next.has(id) ? next.delete(id) : next.add(id); return next; });

  const handleSaveContent = async () => {
    if (!selectedNode) return;
    if (!structureDraft.name.trim()) {
      setError('请先填写风格名称。');
      return;
    }
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await genreAdminApi.updateNode(selectedNode.id, {
        name: structureDraft.name.trim(),
        parentId: structureDraft.parentId || null,
        slug: structureDraft.slug.trim() || null,
        sortOrder: structureDraft.sortOrder.trim() ? Number(structureDraft.sortOrder) : null,
      });
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
        bindings: keyArtistDrafts.map((item) => ({ name: item.name.trim(), djId: item.djId })).filter((item) => item.name),
      });
      setNotice('风格内容已更新。');
      await loadTree(selectedNode.id);
      setIsEditing(false);
    } catch (e) {
      setError(e instanceof Error ? e.message : '更新风格内容失败。');
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
    } catch (e) {
      setError(e instanceof Error ? e.message : '删除风格节点失败。');
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
    } catch (e) {
      setError(e instanceof Error ? e.message : '自动匹配代表艺人失败。');
    } finally {
      setSaving(false);
    }
  };

  const updateLocalizedValue = (field: LocalizedFieldKey, locale: LocalizedLocaleKey, value: string) => {
    if (field === 'description') { setDescriptionValue((cur) => ({ ...cur, [locale]: value })); return; }
    setExampleValue((cur) => ({ ...cur, [locale]: value }));
  };

  const addKeyArtistDraft = () =>
    setKeyArtistDrafts((cur) => [...cur, { id: `draft-${Date.now()}-${cur.length}`, name: '', djId: null, dj: null }]);

  const updateKeyArtistDraft = (id: string, patch: Partial<KeyArtistDraft>) =>
    setKeyArtistDrafts((cur) => cur.map((item) => (item.id === id ? { ...item, ...patch } : item)));

  const removeKeyArtistDraft = (id: string) =>
    setKeyArtistDrafts((cur) => cur.filter((item) => item.id !== id));

  return (
    <AdminContentLayout
      title="风格管理"
      description="维护风格层级树、多语言描述，以及可复用的代表艺人 DJ 绑定。"
      actions={
        <div className="flex items-center gap-2">
          <Link href="/admin/content" className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors">
            返回上级
          </Link>
          <button
            type="button"
            onClick={() => void loadTree(selectedId)}
            disabled={loading || saving}
            className="flex items-center gap-1.5 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors disabled:opacity-50"
          >
            <RefreshCw className="h-3.5 w-3.5" />
            刷新
          </button>
          {selectedNode ? (
            isEditing ? (
              <>
                <button
                  type="button"
                  onClick={() => {
                    setError('');
                    setNotice('');
                    hydrateDraftFromNode(selectedNode);
                    setIsEditing(false);
                  }}
                  disabled={saving}
                  className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors disabled:opacity-50"
                >
                  取消编辑
                </button>
                <button
                  type="button"
                  onClick={handleSaveContent}
                  disabled={saving}
                  className="rounded-lg bg-gray-900 px-4 py-2 text-sm font-semibold text-white hover:bg-gray-800 transition-colors disabled:opacity-50"
                >
                  {saving ? '保存中…' : '保存当前节点'}
                </button>
              </>
            ) : (
              <button
                type="button"
                onClick={() => {
                  setError('');
                  setNotice('');
                  setIsEditing(true);
                }}
                disabled={!selectedNode}
                className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors disabled:opacity-50"
              >
                编辑当前节点
              </button>
            )
          ) : null}
          <Link href="/admin/content/genres/new" className="rounded-lg bg-gray-900 px-4 py-2 text-sm font-semibold text-white hover:bg-gray-800 transition-colors">
            新建子风格
          </Link>
        </div>
      }
    >
      {/* Breadcrumb */}
      {selectedNode && (
        <nav className="flex items-center gap-1.5 text-sm text-gray-500">
          <span className="text-gray-400">流派管理</span>
          {breadcrumbParts.map((part, i) => (
            <span key={i} className="flex items-center gap-1.5">
              <span className="text-gray-300">/</span>
              <span className={i === breadcrumbParts.length - 1 ? 'font-semibold text-gray-900' : 'text-gray-500'}>
                {part}
              </span>
            </span>
          ))}
        </nav>
      )}

      {/* Alerts */}
      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>
      )}
      {notice && (
        <div className="rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{notice}</div>
      )}

      {/* Main 2-column layout: wide left + narrow right tree */}
      <div className="grid gap-4 xl:grid-cols-[1fr_320px] xl:items-start">

        {/* ── Left: edit panels ── */}
        <div className="space-y-4">
          {!selectedNode ? (
            <SectionCard title="风格详情">
              <div className="py-8 text-center text-sm text-gray-400">
                {loading ? '加载中…' : '请先从右侧风格树中选择一个节点。'}
              </div>
            </SectionCard>
          ) : isEditing ? (
            <>
              <section className="admin-reference-card p-6">
                <div className="text-xs uppercase tracking-[0.14em] text-black/38">结构</div>
                <h2 className="mt-2 text-[22px] font-semibold text-[#111827]">当前节点结构</h2>
                <div className="mt-1 text-sm text-black/48">
                  调整当前风格的名称、slug、排序以及挂载父节点。
                </div>

                <div className="mt-5 grid gap-4 lg:grid-cols-3">
                  <AdminCountedControl count={countText(structureDraft.name)} maxLength={INPUT_LIMITS.genre.name}>
                    <input
                      className="admin-studio-input"
                      placeholder="风格名称"
                      value={structureDraft.name}
                      maxLength={INPUT_LIMITS.genre.name}
                      onChange={(event) => setStructureDraft((current) => ({ ...current, name: event.target.value }))}
                    />
                  </AdminCountedControl>
                  <AdminCountedControl count={countText(structureDraft.slug)} maxLength={INPUT_LIMITS.genre.slug}>
                    <input
                      className="admin-studio-input"
                      placeholder="Slug（可选）"
                      value={structureDraft.slug}
                      maxLength={INPUT_LIMITS.genre.slug}
                      onChange={(event) => setStructureDraft((current) => ({ ...current, slug: event.target.value }))}
                    />
                  </AdminCountedControl>
                  <AdminCountedControl count={countText(structureDraft.sortOrder)} maxLength={INPUT_LIMITS.genre.sortOrder}>
                    <input
                      className="admin-studio-input"
                      placeholder="排序值（可选）"
                      value={structureDraft.sortOrder}
                      maxLength={INPUT_LIMITS.genre.sortOrder}
                      onChange={(event) => setStructureDraft((current) => ({ ...current, sortOrder: event.target.value }))}
                    />
                  </AdminCountedControl>
                </div>

                <div className="mt-4 grid gap-4 xl:grid-cols-[minmax(0,1fr)_320px]">
                  <label className="block">
                    <div className="mb-2 admin-studio-label">父风格</div>
                    <div className="admin-studio-select-shell">
                      <select
                        value={structureDraft.parentId}
                        onChange={(event) => setStructureDraft((current) => ({ ...current, parentId: event.target.value }))}
                        className="admin-studio-select"
                      >
                        <option value="">设为顶层根节点</option>
                        {parentOptions.map((item) => (
                          <option key={item.id} value={item.id}>
                            {`${'— '.repeat(item.path.split(' / ').filter(Boolean).length - 1)}${item.name}`}
                          </option>
                        ))}
                      </select>
                    </div>
                  </label>
                  <div className="admin-reference-soft-card p-4 text-sm text-black/55">
                    <div className="text-xs uppercase tracking-[0.14em] text-black/38">当前挂载位置</div>
                    <div className="mt-2 font-medium text-[#111827]">
                      {parentOptions.find((item) => item.id === structureDraft.parentId)?.name || '顶层根节点'}
                    </div>
                    <div className="mt-1 break-words leading-6">
                      {parentOptions.find((item) => item.id === structureDraft.parentId)?.path || '当前节点将直接位于顶层。'}
                    </div>
                  </div>
                </div>
              </section>

              <section className="admin-reference-card p-6">
                <div className="text-xs uppercase tracking-[0.14em] text-black/38">详情</div>
                <h2 className="mt-2 text-[22px] font-semibold text-[#111827]">风格资料</h2>
                <div className="mt-1 text-sm text-black/48">
                  补齐外部链接、多语言描述与示例内容。
                </div>

                <div className="mt-4 grid gap-4 lg:grid-cols-2">
                  <AdminCountedControl count={countText(spotifyTrackURL)} maxLength={INPUT_LIMITS.common.url}>
                    <input
                      className="admin-studio-input"
                      placeholder="Spotify 曲目链接（可选）"
                      value={spotifyTrackURL}
                      maxLength={INPUT_LIMITS.common.url}
                      onChange={(event) => setSpotifyTrackURL(event.target.value)}
                    />
                  </AdminCountedControl>
                  <AdminCountedControl count={countText(wikipediaURL)} maxLength={INPUT_LIMITS.common.url}>
                    <input
                      className="admin-studio-input"
                      placeholder="Wikipedia 链接（可选）"
                      value={wikipediaURL}
                      maxLength={INPUT_LIMITS.common.url}
                      onChange={(event) => setWikipediaURL(event.target.value)}
                    />
                  </AdminCountedControl>
                </div>

                <div className="mt-4 grid gap-4 xl:grid-cols-2">
                  <LocalizedTextField
                    label="风格描述"
                    kind="textarea"
                    value={descriptionValue}
                    placeholder="先填写中文描述"
                    hint="右侧按钮可继续补充英文、日文和英文全称版本。"
                    maxLength={INPUT_LIMITS.genre.description}
                    onPrimaryChange={(value) => setDescriptionValue((current) => ({ ...current, zh: value }))}
                    onOpenOverlay={() => setActiveLocalizedField('description')}
                  />
                  <LocalizedTextField
                    label="风格示例"
                    kind="textarea"
                    value={exampleValue}
                    placeholder="填写中文示例或代表性语境"
                    hint="用于补充典型表达、代表作品或场景。"
                    maxLength={INPUT_LIMITS.genre.example}
                    onPrimaryChange={(value) => setExampleValue((current) => ({ ...current, zh: value }))}
                    onOpenOverlay={() => setActiveLocalizedField('example')}
                  />
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

                <div className="mt-4 space-y-2.5">
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
                      <div key={item.id} className="rounded-[18px] border border-[#e8eceb] bg-white p-3">
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

                        <div className="mt-2.5">
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

                        <div className="mt-2.5">
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

              <div className="flex items-center justify-between gap-3">
                <button
                  type="button"
                  disabled={saving}
                  onClick={handleDeleteNode}
                  className="flex items-center gap-1.5 rounded-lg border border-red-200 bg-white px-4 py-2 text-sm font-medium text-red-600 hover:bg-red-50 transition-colors disabled:opacity-40"
                >
                  <Trash2 className="h-3.5 w-3.5" />
                  删除节点
                </button>
                <button
                  type="button"
                  disabled={saving}
                  onClick={handleAutoMatch}
                  className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors disabled:opacity-50"
                >
                  自动匹配代表艺人
                </button>
              </div>
            </>
          ) : (
            <>
              <SectionCard title="基本信息">
                <div className="space-y-4">
                  <div className="grid grid-cols-3 gap-4">
                    <FieldCell label="名称（中文）" value={selectedNode.name} />
                    <FieldCell label="名称（英文）" value="" />
                    <FieldCell label="名称（日文）" value="" />
                  </div>
                  <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                    <FieldCell label="Slug" value={selectedNode.slug || ''} monospace />
                    <FieldCell label="排序值" value={selectedNode.sortOrder != null ? String(selectedNode.sortOrder) : ''} />
                    <FieldCell label="父节点" value={selectedParentNode?.name || '顶层根节点'} />
                    <FieldCell label="层级路径" value={selectedNode.path} monospace />
                  </div>
                  <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                    <FieldCell
                      label="节点类型"
                      value={(selectedNode.children?.length ?? 0) === 0 ? '叶子节点' : '父节点'}
                      badge={
                        <span className={`mr-1 inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-semibold ${
                          (selectedNode.children?.length ?? 0) === 0
                            ? 'bg-emerald-100 text-emerald-700'
                            : 'bg-blue-100 text-blue-700'
                        }`}>
                          {(selectedNode.children?.length ?? 0) === 0 ? '叶子节点' : '父节点'}
                        </span>
                      }
                    />
                    <FieldCell
                      label="状态"
                      value="启用"
                      badge={<span className="mr-1 h-2 w-2 flex-shrink-0 rounded-full bg-emerald-500" />}
                    />
                    <FieldCell label="子节点数" value={String(selectedNode.children?.length ?? 0)} />
                    <FieldCell label="代表艺人数" value={String(readonlyKeyArtistBindings.length)} />
                  </div>
                </div>
              </SectionCard>

              <SectionCard title="外部链接">
                <div className="grid grid-cols-2 gap-4">
                  <ReadOnlyUrlField label="Spotify 曲目链接" value={selectedNode.spotifyTrackURL || ''} />
                  <ReadOnlyUrlField label="Wikipedia 链接" value={selectedNode.wikipediaURL || ''} />
                </div>
              </SectionCard>

              <SectionCard title="风格描述">
                <div className="grid gap-4 xl:grid-cols-2">
                  <ReadOnlyTextBlock label="中文描述" value={selectedNode.descriptionI18n?.zh || selectedNode.description || ''} />
                  <ReadOnlyTextBlock label="英文描述" value={selectedNode.descriptionI18n?.en || ''} />
                  <ReadOnlyTextBlock label="日文描述" value={selectedNode.descriptionI18n?.ja || ''} />
                  <ReadOnlyTextBlock label="风格示例" value={selectedNode.exampleI18n?.zh || selectedNode.example || ''} />
                </div>
              </SectionCard>

              <SectionCard title="代表艺人">
                {readonlyKeyArtistBindings.length ? (
                  <div className="space-y-1.5">
                    {readonlyKeyArtistBindings.map((item, index) => (
                      <div key={`${item.name}-${index}`} className="rounded-lg border border-gray-200 bg-gray-50 px-4 py-2.5">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="text-sm font-semibold text-gray-900">{item.name}</span>
                          <span className={`rounded-full px-2 py-0.5 text-[10px] font-semibold ${
                            item.djId ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-200 text-gray-600'
                          }`}>
                            {item.djId ? '已绑定' : '未绑定'}
                          </span>
                          {item.dj ? <span className="text-xs text-gray-500">{item.dj.name}</span> : null}
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="rounded-lg border border-dashed border-gray-200 py-6 text-center text-sm text-gray-400">
                    暂无代表艺人。
                  </div>
                )}
              </SectionCard>
            </>
          )}
        </div>

        {/* ── Right: genre tree panel ── */}
        <div className="rounded-xl border border-gray-200 bg-white shadow-sm xl:sticky xl:top-4">
          <div className="border-b border-gray-100 px-4 py-3">
            <h2 className="text-sm font-semibold text-gray-900">风格树</h2>
          </div>

          {/* Search */}
          <div className="border-b border-gray-100 px-3 py-2.5">
            <div className="flex items-center gap-2 rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 focus-within:border-gray-400 focus-within:bg-white transition-colors">
              <Search className="h-3.5 w-3.5 flex-shrink-0 text-gray-400" />
              <input
                value={treeSearch}
                onChange={(e) => setTreeSearch(e.target.value)}
                placeholder="搜索风格名称"
                className="flex-1 appearance-none border-0 bg-transparent text-sm text-gray-700 shadow-none outline-none placeholder:text-gray-400 focus:outline-none focus:ring-0"
              />
            </div>
          </div>

          {/* Tree */}
          <div className="max-h-[calc(100vh-280px)] overflow-y-auto px-1 py-2">
            {loading ? (
              <div className="py-12 text-center text-xs text-gray-400">加载中…</div>
            ) : tree.length === 0 ? (
              <div className="py-12 text-center text-xs text-gray-400">暂无风格数据。</div>
            ) : (
              tree
                .filter((item) =>
                  !searchMatchIds || searchMatchIds.has(item.id) ||
                  flattenTree([item]).some((n) => searchMatchIds.has(n.id))
                )
                .map((item) => (
                  <TreeNode
                    key={item.id}
                    item={item}
                    selectedId={selectedId}
                    expandedIds={treeSearch ? new Set(flatNodes.map((n) => n.id)) : expandedIds}
                    onSelect={setSelectedId}
                    onToggle={toggleExpanded}
                  />
                ))
            )}
          </div>

          {/* Legend */}
          <div className="flex items-center gap-3 border-t border-gray-100 px-4 py-2.5">
            {[
              { color: 'bg-emerald-500', label: '叶子节点' },
              { color: 'bg-blue-500', label: '父节点' },
              { color: 'bg-gray-300', label: '禁用节点' },
            ].map(({ color, label }) => (
              <div key={label} className="flex items-center gap-1">
                <span className={`h-2 w-2 rounded-full ${color}`} />
                <span className="text-[10px] text-gray-500">{label}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Multilingual overlays */}
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
