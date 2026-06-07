'use client';

import Link from 'next/link';
import { ChevronDown, ChevronRight, Languages, Plus, Trash2, Pencil, Search, RefreshCw, ExternalLink } from 'lucide-react';
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

// ─── URL input field with char count ─────────────────────────────────────────

function UrlField({
  label,
  value,
  placeholder,
  maxLength,
  onChange,
}: {
  label: string;
  value: string;
  placeholder: string;
  maxLength: number;
  onChange: (v: string) => void;
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="flex items-center gap-2 rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 focus-within:border-gray-400 focus-within:bg-white transition-colors">
        <input
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          maxLength={maxLength}
          className="flex-1 min-w-0 appearance-none border-0 bg-transparent text-sm text-gray-800 shadow-none outline-none placeholder:text-gray-400 focus:outline-none focus:ring-0 font-mono"
          spellCheck={false}
          autoCapitalize="off"
          autoCorrect="off"
        />
        {value && (
          <a href={value} target="_blank" rel="noopener noreferrer" className="flex-shrink-0 text-gray-400 hover:text-gray-600 transition-colors">
            <ExternalLink className="h-3.5 w-3.5" />
          </a>
        )}
      </div>
      <div className="text-right text-[10px] text-gray-400">{countText(value)}/{maxLength}</div>
    </div>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────

export default function AdminGenresPage() {
  const [tree, setTree] = useState<GenreAdminNode[]>([]);
  const [expandedIds, setExpandedIds] = useState<Set<string>>(new Set());
  const [selectedId, setSelectedId] = useState('');
  const [treeSearch, setTreeSearch] = useState('');
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  // Localized text
  const [descriptionValue, setDescriptionValue] = useState<LocalizedTextValue>(() => normalizeLocalizedValue(null));
  const [exampleValue, setExampleValue] = useState<LocalizedTextValue>(() => normalizeLocalizedValue(null));
  const [activeLocalizedField, setActiveLocalizedField] = useState<LocalizedFieldKey | null>(null);
  const [descriptionTab, setDescriptionTab] = useState<'zh' | 'en' | 'ja'>('zh');

  // External links
  const [spotifyTrackURL, setSpotifyTrackURL] = useState('');
  const [wikipediaURL, setWikipediaURL] = useState('');

  // Key artists
  const [keyArtistDrafts, setKeyArtistDrafts] = useState<KeyArtistDraft[]>([]);

  const flatNodes = useMemo(() => flattenTree(tree), [tree]);
  const selectedNode = flatNodes.find((item) => item.id === selectedId) ?? null;

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

  useEffect(() => { void loadTree(); }, [loadTree]);

  useEffect(() => {
    if (!selectedNode) return;
    setDescriptionValue(normalizeLocalizedValue(selectedNode.descriptionI18n, selectedNode.description || ''));
    setExampleValue(normalizeLocalizedValue(selectedNode.exampleI18n, selectedNode.example || ''));
    setSpotifyTrackURL(selectedNode.spotifyTrackURL || '');
    setWikipediaURL(selectedNode.wikipediaURL || '');
    setDescriptionTab('zh');
    setKeyArtistDrafts(
      (selectedNode.keyArtistBindings.length
        ? selectedNode.keyArtistBindings
        : selectedNode.keyArtists.map((name) => ({ name, djId: null, dj: null }))
      ).map((item, index) => ({
        id: `${selectedNode.id}-artist-${index}-${item.name}`,
        name: item.name,
        djId: item.djId,
        dj: item.dj,
      }))
    );
  }, [selectedNode]);

  const toggleExpanded = (id: string) =>
    setExpandedIds((cur) => { const next = new Set(cur); next.has(id) ? next.delete(id) : next.add(id); return next; });

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
        bindings: keyArtistDrafts.map((item) => ({ name: item.name.trim(), djId: item.djId })).filter((item) => item.name),
      });
      setNotice('风格内容已更新。');
      await loadTree(selectedNode.id);
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

  // Description tab active text
  const descriptionTabText = descriptionTab === 'zh' ? descriptionValue.zh : descriptionTab === 'en' ? descriptionValue.en : descriptionValue.ja;

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

          {/* Section 1: Basic info */}
          <SectionCard
            title="基本信息"
            action={
              <button
                type="button"
                className="flex h-8 w-8 items-center justify-center rounded-lg border border-gray-200 text-gray-400 hover:text-gray-700 hover:bg-gray-50 transition-colors"
              >
                <Pencil className="h-3.5 w-3.5" />
              </button>
            }
          >
            {selectedNode ? (
              <div className="space-y-4">
                {/* Row 1: names */}
                <div className="grid grid-cols-3 gap-4">
                  <FieldCell
                    label="名称（中文）"
                    value={selectedNode.name}
                  />
                  <FieldCell
                    label="名称（英文）"
                    value=""
                  />
                  <FieldCell
                    label="名称（日文）"
                    value=""
                  />
                </div>
                {/* Row 2: path, type, status, sort */}
                <div className="grid grid-cols-4 gap-4">
                  <FieldCell
                    label="层级路径"
                    value={selectedNode.path}
                  />
                  <FieldCell
                    label="节点类型"
                    value={(selectedNode.children?.length ?? 0) === 0 ? '叶子节点' : '父节点'}
                    badge={
                      <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-semibold mr-1 ${
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
                    badge={<span className="mr-1 h-2 w-2 rounded-full bg-emerald-500 flex-shrink-0" />}
                  />
                  <FieldCell
                    label="子节点数"
                    value={String(selectedNode.children?.length ?? 0)}
                  />
                </div>
              </div>
            ) : (
              <div className="py-8 text-center text-sm text-gray-400">
                {loading ? '加载中…' : '请先从右侧风格树中选择一个节点。'}
              </div>
            )}
          </SectionCard>

          {/* Section 2: External links */}
          {selectedNode && (
            <SectionCard
              title="外部链接"
              action={
                <button
                  type="button"
                  className="flex h-8 w-8 items-center justify-center rounded-lg border border-gray-200 text-gray-400 hover:text-gray-700 hover:bg-gray-50 transition-colors"
                >
                  <Pencil className="h-3.5 w-3.5" />
                </button>
              }
            >
              <div className="grid grid-cols-2 gap-4">
                <UrlField
                  label="Spotify 曲目链接"
                  value={spotifyTrackURL}
                  placeholder="https://open.spotify.com/..."
                  maxLength={INPUT_LIMITS.common.url}
                  onChange={setSpotifyTrackURL}
                />
                <UrlField
                  label="Wikipedia 链接"
                  value={wikipediaURL}
                  placeholder="https://en.wikipedia.org/..."
                  maxLength={INPUT_LIMITS.common.url}
                  onChange={setWikipediaURL}
                />
              </div>
            </SectionCard>
          )}

          {/* Section 3: Description */}
          {selectedNode && (
            <SectionCard
              title="风格描述"
              action={
                <button
                  type="button"
                  onClick={() => setActiveLocalizedField('description')}
                  className="flex items-center gap-1.5 rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-medium text-gray-600 hover:bg-gray-50 transition-colors"
                >
                  <Plus className="h-3.5 w-3.5" />
                  添加语言
                </button>
              }
            >
              {/* Language tabs */}
              <div className="flex items-center gap-1 mb-4">
                {(
                  [
                    { key: 'zh' as const, label: '中文', filled: Boolean(descriptionValue.zh) },
                    { key: 'en' as const, label: '英文', filled: Boolean(descriptionValue.en) },
                    { key: 'ja' as const, label: '日文', filled: Boolean(descriptionValue.ja) },
                  ]
                ).map(({ key, label, filled }) => (
                  <button
                    key={key}
                    type="button"
                    onClick={() => setDescriptionTab(key)}
                    className={`rounded-lg px-3 py-1.5 text-sm font-medium transition-colors ${
                      descriptionTab === key
                        ? 'bg-emerald-100 text-emerald-800'
                        : filled
                        ? 'text-gray-700 hover:bg-gray-100'
                        : 'text-gray-400 hover:bg-gray-100'
                    }`}
                  >
                    {label}
                  </button>
                ))}
              </div>

              {/* Text area */}
              <div className="relative">
                <textarea
                  value={descriptionTabText}
                  onChange={(e) => {
                    const v = e.target.value;
                    if (descriptionTab === 'zh') setDescriptionValue((cur) => ({ ...cur, zh: v }));
                    else if (descriptionTab === 'en') setDescriptionValue((cur) => ({ ...cur, en: v }));
                    else setDescriptionValue((cur) => ({ ...cur, ja: v }));
                  }}
                  rows={5}
                  maxLength={INPUT_LIMITS.genre.description}
                  placeholder={`请输入${descriptionTab === 'zh' ? '中文' : descriptionTab === 'en' ? '英文' : '日文'}描述…`}
                  className="w-full rounded-lg border border-gray-200 bg-gray-50 px-4 py-3 text-sm leading-relaxed text-gray-800 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-900/10 resize-none"
                />
                <div className="mt-1 text-right text-[10px] text-gray-400">
                  {countText(descriptionTabText)}/{INPUT_LIMITS.genre.description}
                </div>
              </div>

              {/* Full multilingual editor */}
              <button
                type="button"
                onClick={() => setActiveLocalizedField('description')}
                className="mt-2 flex items-center gap-1.5 text-xs font-medium text-gray-500 hover:text-gray-800 transition-colors"
              >
                <Languages className="h-3.5 w-3.5" />
                打开多语言编辑器
              </button>
            </SectionCard>
          )}

          {/* Section 4: Key artists */}
          {selectedNode && (
            <SectionCard
              title="代表艺人"
              action={
                <button
                  type="button"
                  onClick={addKeyArtistDraft}
                  className="flex items-center gap-1.5 rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-medium text-gray-600 hover:bg-gray-50 transition-colors"
                >
                  <Plus className="h-3.5 w-3.5" />
                  添加艺人
                </button>
              }
            >
              {keyArtistDrafts.length > 0 ? (
                <div className="overflow-x-auto">
                  <table className="min-w-full text-sm">
                    <thead>
                      <tr className="border-b border-gray-100 bg-gray-50/80">
                        {['DJ 名称', '绑定状态', '操作'].map((col) => (
                          <th key={col} className="px-4 py-2 text-left text-[11px] font-semibold uppercase tracking-wide text-gray-400">
                            {col}
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {keyArtistDrafts.map((item) => (
                        <tr key={item.id} className="border-b border-gray-50 hover:bg-gray-50/60 transition-colors">
                          {/* Name */}
                          <td className="px-4 py-2">
                            <input
                              value={item.name}
                              onChange={(e) => updateKeyArtistDraft(item.id, { name: e.target.value })}
                              placeholder="艺人名称"
                              maxLength={INPUT_LIMITS.genre.keyArtistName}
                              className="w-full rounded-md border border-gray-200 bg-white px-2.5 py-1 text-sm text-gray-800 focus:outline-none focus:ring-2 focus:ring-gray-900/10"
                            />
                          </td>

                          {/* Binding status */}
                          <td className="px-4 py-2">
                            {item.djId ? (
                              <div className="flex items-center gap-1.5">
                                <span className="h-2 w-2 rounded-full bg-emerald-500 flex-shrink-0" />
                                <span className="text-xs font-semibold text-emerald-700">已绑定</span>
                                {item.dj && (
                                  <span className="text-xs text-gray-500 truncate max-w-[120px]">{item.dj.name}</span>
                                )}
                              </div>
                            ) : (
                              <div className="flex items-center gap-1.5">
                                <span className="h-2 w-2 rounded-full bg-gray-300 flex-shrink-0" />
                                <span className="text-xs text-gray-500">未绑定</span>
                              </div>
                            )}
                          </td>

                          {/* Actions */}
                          <td className="px-4 py-2">
                            <div className="flex items-center gap-2">
                              <EditableEntityBindingCard
                                key={item.id}
                                header={`代表艺人`}
                                name={item.name}
                                nameValue={item.name}
                                namePlaceholder="艺人名称"
                                nameMaxLength={INPUT_LIMITS.genre.keyArtistName}
                                bindingKind="dj"
                                binding={
                                  item.dj
                                    ? { id: item.dj.id, name: item.dj.name, subtitle: null, imageUrl: item.dj.avatarMediumUrl || item.dj.avatarUrl || null }
                                    : null
                                }
                                seedQuery={item.name}
                                bindingTitle="已绑定 DJ"
                                bindingEmptyLabel="当前代表艺人还没有关联到库内 DJ。"
                                confirmedMeta={null}
                                boundLabel="已绑定"
                                unboundLabel="未绑定"
                                onNameChange={(v) => updateKeyArtistDraft(item.id, { name: v })}
                                onAddBinding={(v) =>
                                  updateKeyArtistDraft(item.id, {
                                    djId: v.id,
                                    dj: { id: v.id, name: v.name, avatarUrl: v.imageUrl || null, avatarMediumUrl: v.imageUrl || null },
                                  })
                                }
                                onRemoveBinding={() => updateKeyArtistDraft(item.id, { djId: null, dj: null })}
                                onDelete={() => removeKeyArtistDraft(item.id)}
                                renderTrigger={({ onClick }: { onClick: () => void }) => (
                                  <button
                                    type="button"
                                    onClick={onClick}
                                    className="flex h-7 w-7 items-center justify-center rounded-lg border border-gray-200 bg-white text-gray-400 hover:text-gray-700 hover:bg-gray-50 transition-colors"
                                    title="编辑绑定"
                                  >
                                    <Pencil className="h-3.5 w-3.5" />
                                  </button>
                                )}
                              />
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <div className="rounded-lg border border-dashed border-gray-200 py-8 text-center text-sm text-gray-400">
                  暂无代表艺人，可通过上方按钮按需添加。
                </div>
              )}
            </SectionCard>
          )}

          {/* Save / delete actions */}
          {selectedNode && (
            <div className="flex items-center justify-between gap-3">
              <button
                type="button"
                disabled={!selectedNode || saving}
                onClick={handleDeleteNode}
                className="flex items-center gap-1.5 rounded-lg border border-red-200 bg-white px-4 py-2 text-sm font-medium text-red-600 hover:bg-red-50 transition-colors disabled:opacity-40"
              >
                <Trash2 className="h-3.5 w-3.5" />
                删除节点
              </button>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  disabled={saving}
                  onClick={handleAutoMatch}
                  className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors disabled:opacity-50"
                >
                  自动匹配代表艺人
                </button>
                <button
                  type="button"
                  disabled={saving || !selectedNode}
                  onClick={handleSaveContent}
                  className="rounded-lg bg-gray-900 px-5 py-2 text-sm font-semibold text-white hover:bg-gray-800 transition-colors disabled:opacity-50"
                >
                  {saving ? '保存中…' : '保存节点内容'}
                </button>
              </div>
            </div>
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
