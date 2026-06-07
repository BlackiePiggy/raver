'use client';

import Link from 'next/link';
import { ChevronDown, ChevronRight, Languages, Plus, Trash2, Pencil, Search, RefreshCw, ExternalLink } from 'lucide-react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import AdminCountedControl from '@/components/admin/AdminCountedControl';
import EditableEntityBindingCard from '@/components/admin/EditableEntityBindingCard';
import {
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

type TreeSearchCandidate = {
  id: string;
  name: string;
  path: string;
  depth: number;
};

type PendingCreateTarget = {
  id: string;
  name: string;
  parentId: string | null | undefined;
};

type PendingCreateMode = 'sibling' | 'child';

type SectionTitleProps = {
  title: string;
  dirty?: boolean;
};

const getNodeDepth = (path: string): number => path.split(' / ').filter(Boolean).length;

const getAncestorIds = (targetId: string, items: GenreAdminNode[]): string[] => {
  const byId = new Map(items.map((item) => [item.id, item]));
  const ancestorIds: string[] = [];
  let current = byId.get(targetId) ?? null;
  while (current?.parentId) {
    ancestorIds.unshift(current.parentId);
    current = byId.get(current.parentId) ?? null;
  }
  return ancestorIds;
};

const sameLocalizedValue = (left: LocalizedTextValue, right: LocalizedTextValue): boolean =>
  left.zh === right.zh &&
  left.en === right.en &&
  left.ja === right.ja &&
  left.enFull === right.enFull;

const normalizeKeyArtistDraftsForCompare = (items: KeyArtistDraft[]) =>
  items
    .map((item) => ({
      name: item.name.trim(),
      djId: item.djId || null,
    }))
    .filter((item) => item.name);

const normalizeGenreKeyArtistsForCompare = (node: GenreAdminNode | null) =>
  node
    ? (node.keyArtistBindings.length
        ? node.keyArtistBindings
        : node.keyArtists.map((name) => ({ name, djId: null, dj: null }))
      )
        .map((item) => ({
          name: item.name.trim(),
          djId: item.djId || null,
        }))
        .filter((item) => item.name)
    : [];

// ─── Right-side tree node ─────────────────────────────────────────────────────

function TreeNode({
  item,
  selectedId,
  expandedIds,
  onSelect,
  onToggle,
  registerNodeRef,
  onRequestCreate,
  level = 0,
}: {
  item: GenreAdminNode;
  selectedId: string;
  expandedIds: Set<string>;
  onSelect: (id: string) => void;
  onToggle: (id: string) => void;
  registerNodeRef: (id: string, node: HTMLDivElement | null) => void;
  onRequestCreate: (target: PendingCreateTarget) => void;
  level?: number;
}) {
  const hasChildren = Boolean(item.children?.length);
  const isExpanded = expandedIds.has(item.id);
  const isSelected = selectedId === item.id;
  const insertButtonLeft = Math.max(0, 8 + level * 16 - 4);
  const insertLineLeft = insertButtonLeft + 24;

  return (
    <div className="relative">
      <div
        ref={(node) => registerNodeRef(item.id, node)}
        className={`group flex items-center gap-1 rounded-lg px-2 py-1.5 transition-colors cursor-pointer ${
          isSelected
            ? 'bg-emerald-50 text-emerald-800'
            : 'hover:bg-gray-100 text-gray-700'
        }`}
        style={{ paddingLeft: `${8 + level * 16}px` }}
        onClick={() => onSelect(item.id)}
      >
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

      <button
        type="button"
        onClick={(event) => {
          event.stopPropagation();
          onRequestCreate({
            id: item.id,
            name: item.name,
            parentId: item.parentId,
          });
        }}
        className="absolute inset-x-0 -bottom-[9px] z-20 h-[18px] opacity-0 transition-opacity hover:opacity-100 focus:opacity-100"
        aria-label={`在 ${item.name} 后新增节点`}
      >
        <span
          className="pointer-events-none absolute top-1/2 h-px -translate-y-1/2 rounded-full bg-gradient-to-r from-[#5ee9a5] via-[#26d07c] to-[#9ef3c9] shadow-[0_0_14px_rgba(38,208,124,0.55)]"
          style={{ left: `${insertLineLeft}px`, right: '6px' }}
        />
        <span
          className="pointer-events-none absolute top-1/2 inline-flex h-5 w-5 -translate-y-1/2 items-center justify-center rounded-full border border-[#78e4ab] bg-white text-[#18a957] shadow-[0_0_0_3px_rgba(255,255,255,0.92),0_0_18px_rgba(38,208,124,0.35)]"
          style={{ left: `${insertButtonLeft}px` }}
        >
          <Plus className="h-3.5 w-3.5" />
        </span>
      </button>

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
              registerNodeRef={registerNodeRef}
              onRequestCreate={onRequestCreate}
              level={level + 1}
            />
          ))}
        </div>
      )}
    </div>
  );
}

// ─── Section card wrapper ─────────────────────────────────────────────────────

function SectionCard({ title, action, children }: { title: React.ReactNode; action?: React.ReactNode; children: React.ReactNode }) {
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

function SectionTitle({ title, dirty = false }: SectionTitleProps) {
  return (
    <span className="inline-flex items-center gap-2">
      <span>{title}</span>
      {dirty ? <span className="text-xs font-semibold text-red-500">未保存</span> : null}
    </span>
  );
}

function FieldLabel({
  label,
  dirty = false,
}: {
  label: string;
  dirty?: boolean;
}) {
  return (
    <div className="flex items-center gap-2 text-xs text-gray-500">
      <span>{label}</span>
      {dirty ? <span className="font-semibold text-red-500">未保存</span> : null}
    </div>
  );
}

function BasicInfoField({
  label,
  value,
  placeholder,
  maxLength,
  onChange,
  dirty = false,
  monospace = false,
}: {
  label: string;
  value: string;
  placeholder: string;
  maxLength: number;
  onChange: (value: string) => void;
  dirty?: boolean;
  monospace?: boolean;
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <FieldLabel label={label} dirty={dirty} />
      <AdminCountedControl count={countText(value)} maxLength={maxLength}>
        <input
          type="text"
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder={placeholder}
          maxLength={maxLength}
          className={`admin-studio-input ${monospace ? 'font-mono' : ''}`}
          spellCheck={false}
          autoCapitalize="off"
          autoCorrect="off"
        />
      </AdminCountedControl>
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
  dirty = false,
}: {
  label: string;
  value: string;
  placeholder: string;
  maxLength: number;
  onChange: (v: string) => void;
  dirty?: boolean;
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <FieldLabel label={label} dirty={dirty} />
      <div className="admin-search-field-shell flex items-center gap-2 rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 transition-colors">
        <input
          type="text"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          maxLength={maxLength}
          className="admin-search-field-input flex-1 min-w-0 bg-transparent text-sm text-gray-800 placeholder:text-gray-400 font-mono"
          spellCheck={false}
          autoCapitalize="off"
          autoCorrect="off"
          inputMode="url"
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
  const [treeSearchFocused, setTreeSearchFocused] = useState(false);
  const [pendingScrollTargetId, setPendingScrollTargetId] = useState<string | null>(null);
  const [pendingCreateTarget, setPendingCreateTarget] = useState<PendingCreateTarget | null>(null);
  const [pendingCreateName, setPendingCreateName] = useState('');
  const [creatingNode, setCreatingNode] = useState(false);
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const treeContainerRef = useRef<HTMLDivElement | null>(null);
  const treeNodeRefs = useRef(new Map<string, HTMLDivElement>());
  const [basicName, setBasicName] = useState('');
  const [basicSlug, setBasicSlug] = useState('');

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

  const treeSearchCandidates = useMemo<TreeSearchCandidate[]>(() => {
    const query = treeSearch.trim().toLowerCase();
    if (!query) return [];
    return flatNodes
      .filter((node) => node.name.toLowerCase().includes(query))
      .map((node) => ({
        id: node.id,
        name: node.name,
        path: node.path,
        depth: getNodeDepth(node.path),
      }))
      .sort((left, right) => {
        const leftStarts = left.name.toLowerCase().startsWith(query);
        const rightStarts = right.name.toLowerCase().startsWith(query);
        if (leftStarts !== rightStarts) return leftStarts ? -1 : 1;
        if (left.depth !== right.depth) return left.depth - right.depth;
        return left.path.localeCompare(right.path, 'zh-CN');
      })
      .slice(0, 10);
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
      const nextExpanded = preferredId ? new Set(getAncestorIds(preferredId, nextFlat)) : new Set<string>();
      setExpandedIds(nextExpanded);
      if (preferredId) {
        setPendingScrollTargetId(preferredId);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : '加载风格树失败。');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void loadTree(); }, [loadTree]);

  useEffect(() => {
    if (!selectedNode) return;
    setBasicName(selectedNode.name || '');
    setBasicSlug(selectedNode.slug || '');
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

  useEffect(() => {
    if (!pendingScrollTargetId) return;
    const node = treeNodeRefs.current.get(pendingScrollTargetId);
    if (!node) return;
    node.scrollIntoView({ block: 'start', behavior: 'smooth' });
    setPendingScrollTargetId(null);
  }, [pendingScrollTargetId, expandedIds, tree]);

  const registerTreeNodeRef = useCallback((id: string, node: HTMLDivElement | null) => {
    if (node) {
      treeNodeRefs.current.set(id, node);
      return;
    }
    treeNodeRefs.current.delete(id);
  }, []);

  const selectTreeNode = useCallback((id: string, options?: { expandAncestors?: boolean; alignTop?: boolean }) => {
    setSelectedId(id);
    if (options?.expandAncestors) {
      setExpandedIds(new Set(getAncestorIds(id, flatNodes)));
    }
    if (options?.alignTop) {
      setPendingScrollTargetId(id);
    }
  }, [flatNodes]);

  const handleTreeSearchSelect = useCallback((candidate: TreeSearchCandidate) => {
    setTreeSearch(candidate.name);
    setTreeSearchFocused(false);
    selectTreeNode(candidate.id, { expandAncestors: true, alignTop: true });
  }, [selectTreeNode]);

  const handleCreateNode = useCallback(async (mode: PendingCreateMode) => {
    if (!pendingCreateTarget) return;
    const trimmedName = pendingCreateName.trim();
    if (!trimmedName) {
      setError('请先填写新节点名称。');
      return;
    }
    const parentId = mode === 'child' ? pendingCreateTarget.id : pendingCreateTarget.parentId ?? null;

    setCreatingNode(true);
    setError('');
    setNotice('');
    try {
      const created = await genreAdminApi.createNode({
        name: trimmedName,
        parentId,
      });
      setPendingCreateTarget(null);
      setPendingCreateName('');
      setNotice(`已创建节点「${created.name}」，你可以继续在左侧补充内容。`);
      await loadTree(created.id);
    } catch (createError) {
      setError(createError instanceof Error ? createError.message : '创建风格节点失败。');
    } finally {
      setCreatingNode(false);
    }
  }, [loadTree, pendingCreateName, pendingCreateTarget]);

  const toggleExpanded = (id: string) =>
    setExpandedIds((cur) => { const next = new Set(cur); next.has(id) ? next.delete(id) : next.add(id); return next; });

  const initialDescriptionValue = selectedNode
    ? normalizeLocalizedValue(selectedNode.descriptionI18n, selectedNode.description || '')
    : normalizeLocalizedValue(null);
  const basicNameDirty = selectedNode ? basicName !== (selectedNode.name || '') : false;
  const basicSlugDirty = selectedNode ? basicSlug !== (selectedNode.slug || '') : false;
  const descriptionDirty = selectedNode ? !sameLocalizedValue(descriptionValue, initialDescriptionValue) : false;
  const keyArtistsDirty = selectedNode
    ? JSON.stringify(normalizeKeyArtistDraftsForCompare(keyArtistDrafts)) !== JSON.stringify(normalizeGenreKeyArtistsForCompare(selectedNode))
    : false;
  const spotifyDirty = selectedNode ? spotifyTrackURL !== (selectedNode.spotifyTrackURL || '') : false;
  const wikipediaDirty = selectedNode ? wikipediaURL !== (selectedNode.wikipediaURL || '') : false;
  const basicInfoDirty = basicNameDirty || basicSlugDirty;
  const externalLinksDirty = spotifyDirty || wikipediaDirty;

  const handleSaveContent = async () => {
    if (!selectedNode) return;
    if (!basicName.trim()) {
      setError('请先填写流派名称。');
      return;
    }
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await genreAdminApi.updateNode(selectedNode.id, {
        name: basicName.trim(),
        slug: basicSlug.trim() || null,
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
            title={<SectionTitle title="基本信息" dirty={basicInfoDirty} />}
          >
            {selectedNode ? (
              <div className="space-y-4">
                <div className="grid gap-4 xl:grid-cols-2">
                  <BasicInfoField
                    label="名称"
                    value={basicName}
                    placeholder="输入流派名称"
                    maxLength={INPUT_LIMITS.genre.name}
                    onChange={setBasicName}
                    dirty={basicNameDirty}
                  />
                  <BasicInfoField
                    label="Slug"
                    value={basicSlug}
                    placeholder="可选，自定义 slug"
                    maxLength={INPUT_LIMITS.genre.slug}
                    onChange={setBasicSlug}
                    dirty={basicSlugDirty}
                    monospace
                  />
                </div>
                <div className="grid grid-cols-1 gap-4">
                  <FieldCell
                    label="层级路径"
                    value={selectedNode.path}
                  />
                </div>
              </div>
            ) : (
              <div className="py-8 text-center text-sm text-gray-400">
                {loading ? '加载中…' : '请先从右侧风格树中选择一个节点。'}
              </div>
            )}
          </SectionCard>

          {/* Section 2: Description */}
          {selectedNode && (
            <SectionCard
              title={<SectionTitle title="风格描述" dirty={descriptionDirty} />}
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
              <div>
                <FieldLabel label="描述内容" dirty={descriptionDirty} />
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

          {/* Section 3: Key artists */}
          {selectedNode && (
            <SectionCard
              title={<SectionTitle title="代表艺人" dirty={keyArtistsDirty} />}
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

          {/* Section 4: External links */}
          {selectedNode && (
            <SectionCard title={<SectionTitle title="外部链接" dirty={externalLinksDirty} />}>
              <div className="grid grid-cols-2 gap-4">
                <UrlField
                  label="Spotify 曲目链接"
                  value={spotifyTrackURL}
                  placeholder="https://open.spotify.com/..."
                  maxLength={INPUT_LIMITS.common.url}
                  onChange={setSpotifyTrackURL}
                  dirty={spotifyDirty}
                />
                <UrlField
                  label="Wikipedia 链接"
                  value={wikipediaURL}
                  placeholder="https://en.wikipedia.org/..."
                  maxLength={INPUT_LIMITS.common.url}
                  onChange={setWikipediaURL}
                  dirty={wikipediaDirty}
                />
              </div>
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
          <div className="relative border-b border-gray-100 px-3 py-2.5">
            <div className="admin-search-field-shell flex items-center gap-2 rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 transition-colors">
              <Search className="h-3.5 w-3.5 flex-shrink-0 text-gray-400" />
              <input
                type="text"
                value={treeSearch}
                onChange={(e) => setTreeSearch(e.target.value)}
                onFocus={() => setTreeSearchFocused(true)}
                onBlur={() => {
                  window.setTimeout(() => setTreeSearchFocused(false), 120);
                }}
                placeholder="搜索风格名称"
                className="admin-search-field-input flex-1 bg-transparent text-sm text-gray-700 placeholder:text-gray-400"
              />
            </div>
            {treeSearchFocused && treeSearch.trim() ? (
              <div className="absolute inset-x-3 top-full z-20 mt-2 overflow-hidden rounded-xl border border-gray-200 bg-white shadow-[0_12px_32px_rgba(15,23,42,0.12)]">
                {treeSearchCandidates.length ? (
                  <div className="max-h-72 overflow-y-auto py-2">
                    {treeSearchCandidates.map((candidate) => (
                      <button
                        key={candidate.id}
                        type="button"
                        onMouseDown={(event) => event.preventDefault()}
                        onClick={() => handleTreeSearchSelect(candidate)}
                        className="flex w-full flex-col items-start gap-1 px-4 py-2.5 text-left transition-colors hover:bg-gray-50"
                      >
                        <span className="text-sm font-medium text-gray-900">{candidate.name}</span>
                        <span className="text-xs text-gray-500">{candidate.path}</span>
                      </button>
                    ))}
                  </div>
                ) : (
                  <div className="px-4 py-3 text-sm text-gray-400">没有匹配到风格节点。</div>
                )}
              </div>
            ) : null}
          </div>

          {/* Tree */}
          <div ref={treeContainerRef} className="max-h-[calc(100vh-280px)] overflow-y-auto px-1 py-2">
            {loading ? (
              <div className="py-12 text-center text-xs text-gray-400">加载中…</div>
            ) : tree.length === 0 ? (
              <div className="py-12 text-center text-xs text-gray-400">暂无风格数据。</div>
            ) : (
              tree
                .map((item) => (
                  <TreeNode
                    key={item.id}
                    item={item}
                    selectedId={selectedId}
                    expandedIds={expandedIds}
                    onSelect={selectTreeNode}
                    onToggle={toggleExpanded}
                    registerNodeRef={registerTreeNodeRef}
                    onRequestCreate={(target) => {
                      setPendingCreateTarget(target);
                      setPendingCreateName('');
                      setError('');
                    }}
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

      {pendingCreateTarget ? (
        <div className="fixed inset-0 z-[120] flex items-center justify-center bg-black/35 px-4">
          <div className="w-full max-w-md rounded-[24px] border border-[#e5e7eb] bg-white p-6 shadow-[0_24px_80px_rgba(15,23,42,0.22)]">
            <div className="text-xs font-semibold uppercase tracking-[0.18em] text-black/35">新增节点</div>
            <h3 className="mt-2 text-xl font-semibold text-[#111827]">为“{pendingCreateTarget.name}”创建新节点</h3>
            <p className="mt-2 text-sm leading-6 text-black/50">
              请选择把新节点加在当前节点的同级，还是作为它的子节点。创建后会自动切换到新节点详情页。
            </p>

            <div className="mt-5">
              <div className="mb-2 text-xs font-semibold uppercase tracking-[0.14em] text-black/38">节点名称</div>
              <AdminCountedControl count={countText(pendingCreateName)} maxLength={INPUT_LIMITS.genre.name}>
                <input
                  className="admin-studio-input"
                  value={pendingCreateName}
                  maxLength={INPUT_LIMITS.genre.name}
                  onChange={(event) => setPendingCreateName(event.target.value)}
                  placeholder="先填写新节点名称"
                  autoFocus
                />
              </AdminCountedControl>
            </div>

            <div className="mt-5 grid gap-3">
              <button
                type="button"
                disabled={creatingNode}
                onClick={() => void handleCreateNode('sibling')}
                className="rounded-[18px] border border-[#d9e3df] bg-white px-4 py-3 text-left transition hover:border-[#bfcfc8] disabled:opacity-60"
              >
                <div className="text-sm font-semibold text-[#111827]">添加同级节点</div>
                <div className="mt-1 text-sm text-black/48">新节点会和“{pendingCreateTarget.name}”处于同一层级。</div>
              </button>
              <button
                type="button"
                disabled={creatingNode}
                onClick={() => void handleCreateNode('child')}
                className="rounded-[18px] border border-[#d9e3df] bg-white px-4 py-3 text-left transition hover:border-[#bfcfc8] disabled:opacity-60"
              >
                <div className="text-sm font-semibold text-[#111827]">添加子节点</div>
                <div className="mt-1 text-sm text-black/48">新节点会挂在“{pendingCreateTarget.name}”下面。</div>
              </button>
            </div>

            <div className="mt-5 flex justify-end">
              <button
                type="button"
                disabled={creatingNode}
                onClick={() => {
                  setPendingCreateTarget(null);
                  setPendingCreateName('');
                }}
                className="rounded-full border border-[#e5e7eb] bg-white px-4 py-2 text-sm font-medium text-[#374151] transition hover:bg-[#f8faf9] disabled:opacity-60"
              >
                取消
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </AdminContentLayout>
  );
}
