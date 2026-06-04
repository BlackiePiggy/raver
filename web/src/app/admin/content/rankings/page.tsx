'use client';

import Image from 'next/image';
import Link from 'next/link';
import { Pencil, Plus, Sparkles, Trash2, Upload } from 'lucide-react';
import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import EditableEntityBindingCard from '@/components/admin/EditableEntityBindingCard';
import type { EntityBindingValue } from '@/components/admin/EntityBindingSearch';
import {
  rankingAdminApi,
  type RankingAutoMatchPreview,
  type RankingBoardDetail,
  type RankingBoardDetailEntry,
  type RankingBoardSummary,
  type RankingEntityType,
} from '@/features/admin-content/ranking-admin/api';

type RankingEntryDraft = {
  key: string;
  rank: number;
  name: string;
  entityId: string | null;
  binding: EntityBindingValue | null;
  delta: number | null;
};

type JsonImportPreview = {
  year: number | null;
  entries: Array<{
    rank: number;
    name: string;
    entityId: string | null;
  }>;
};

const buildBindingLabel = (entry: RankingBoardDetailEntry, entityType: RankingEntityType): EntityBindingValue | null => {
  if (entityType === 'festival') {
    const bound = entry.festival;
    if (!bound) return null;
    return {
      id: bound.id,
      name: bound.name,
      subtitle: [bound.city, bound.country].filter(Boolean).join(', ') || bound.tagline || null,
      imageUrl: bound.avatarUrl || bound.backgroundUrl || null,
    };
  }

  const bound = entry.dj;
  if (!bound) return null;
  return {
    id: bound.id,
    name: bound.name,
    subtitle: bound.country || bound.slug || null,
    imageUrl: bound.avatarUrl || bound.bannerUrl || null,
  };
};

const buildEntryDrafts = (detail: RankingBoardDetail): RankingEntryDraft[] =>
  detail.entries
    .slice()
    .sort((a, b) => a.rank - b.rank)
    .map((entry) => ({
      key: `${detail.boardId}-${detail.year ?? 'draft'}-${entry.rank}-${entry.entityId ?? entry.name}`,
      rank: entry.rank,
      name: entry.name,
      entityId: entry.entityId,
      binding: buildBindingLabel(entry, detail.entityType),
      delta: entry.delta,
    }));

const renderDelta = (value: number | null): string => {
  if (value === null || value === 0) return '排名无变化';
  if (value > 0) return `较去年上升 ${value} 位`;
  return `较去年下降 ${Math.abs(value)} 位`;
};

const parseJsonImport = (raw: string): JsonImportPreview => {
  const payload = JSON.parse(raw) as unknown;
  const normalizeEntry = (item: unknown, index: number) => {
    if (typeof item === 'string') {
      const name = item.trim();
      if (!name) return null;
      return {
        rank: index + 1,
        name,
        entityId: null,
      };
    }
    if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
    const row = item as Record<string, unknown>;
    const name = String(row.name ?? row.title ?? row.label ?? '').trim();
    if (!name) return null;
    const rank = Number(row.rank ?? index + 1);
    const entityId = String(row.entityId ?? row.id ?? '').trim() || null;
    return {
      rank: Number.isFinite(rank) && rank > 0 ? Math.floor(rank) : index + 1,
      name,
      entityId,
    };
  };

  const extractEntries = (value: unknown): JsonImportPreview => {
    if (Array.isArray(value)) {
      return {
        year: null,
        entries: value
          .map((item, index) => normalizeEntry(item, index))
          .filter((item): item is NonNullable<typeof item> => Boolean(item))
          .sort((a, b) => a.rank - b.rank),
      };
    }

    if (!value || typeof value !== 'object') {
      throw new Error('JSON 结构不正确');
    }

    const row = value as Record<string, unknown>;
    const yearValue = Number(row.year ?? row.rankingYear ?? row.seasonYear);
    const nestedEntries =
      (Array.isArray(row.entries) ? row.entries : null) ||
      (Array.isArray(row.items) ? row.items : null) ||
      (Array.isArray(row.rankings) ? row.rankings : null) ||
      [];

    return {
      year: Number.isFinite(yearValue) ? Math.floor(yearValue) : null,
      entries: nestedEntries
        .map((item, index) => normalizeEntry(item, index))
        .filter((item): item is NonNullable<typeof item> => Boolean(item))
        .sort((a, b) => a.rank - b.rank),
    };
  };

  const parsed = extractEntries(payload);
  if (!parsed.entries.length) {
    throw new Error('JSON 中没有可导入的榜单对象');
  }
  return parsed;
};

function OverlayShell({
  title,
  description,
  onClose,
  children,
}: {
  title: string;
  description?: string;
  onClose: () => void;
  children: ReactNode;
}) {
  return (
    <div className="fixed inset-0 z-[90] flex items-center justify-center bg-black/45 p-4" onClick={onClose}>
      <div
        className="max-h-[88vh] w-full max-w-[920px] overflow-hidden rounded-[28px] border border-white/70 bg-[#f7f5ef] shadow-[0_30px_120px_rgba(7,17,16,0.24)]"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-[#e8eceb] px-6 py-5">
          <div>
            <div className="text-[20px] font-semibold text-[#111827]">{title}</div>
            {description ? <div className="mt-1 text-sm text-black/50">{description}</div> : null}
          </div>
          <button
            type="button"
            onClick={onClose}
            className="inline-flex h-10 w-10 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#6b7280]"
            aria-label="关闭"
          >
            ×
          </button>
        </div>
        <div className="max-h-[calc(88vh-88px)] overflow-y-auto p-6">{children}</div>
      </div>
    </div>
  );
}

export default function AdminRankingPage() {
  const [boards, setBoards] = useState<RankingBoardSummary[]>([]);
  const [selectedBoardId, setSelectedBoardId] = useState('');
  const [detail, setDetail] = useState<RankingBoardDetail | null>(null);
  const [draftEntries, setDraftEntries] = useState<RankingEntryDraft[]>([]);
  const [editingKeys, setEditingKeys] = useState<Set<string>>(new Set());
  const [loadingBoards, setLoadingBoards] = useState(false);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [yearInput, setYearInput] = useState(String(new Date().getFullYear()));
  const [jsonOverlayOpen, setJsonOverlayOpen] = useState(false);
  const [jsonText, setJsonText] = useState('');
  const [jsonPreview, setJsonPreview] = useState<JsonImportPreview | null>(null);
  const [jsonError, setJsonError] = useState('');
  const [matchOverlayOpen, setMatchOverlayOpen] = useState(false);
  const [matchPreview, setMatchPreview] = useState<RankingAutoMatchPreview | null>(null);
  const [matchLoading, setMatchLoading] = useState(false);
  const [matchApplying, setMatchApplying] = useState(false);
  const [matchError, setMatchError] = useState('');

  const selectedBoard = useMemo(
    () => boards.find((item) => item.id === selectedBoardId) ?? null,
    [boards, selectedBoardId]
  );

  const sortedDraftEntries = useMemo(
    () => [...draftEntries].sort((a, b) => a.rank - b.rank || a.name.localeCompare(b.name, 'zh-CN')),
    [draftEntries]
  );

  const loadBoards = useCallback(async (preferredBoardId?: string) => {
    setLoadingBoards(true);
    setError('');
    try {
      const items = await rankingAdminApi.listBoards();
      setBoards(items);
      const nextSelected = preferredBoardId ?? selectedBoardId ?? items[0]?.id ?? '';
      setSelectedBoardId(nextSelected);
      if (!nextSelected) {
        setDetail(null);
        setDraftEntries([]);
        setEditingKeys(new Set());
      }
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载榜单列表失败');
    } finally {
      setLoadingBoards(false);
    }
  }, [selectedBoardId]);

  const loadBoardDetail = useCallback(async (boardId: string, year?: number | null) => {
    setLoadingDetail(true);
    setError('');
    try {
      const nextDetail = await rankingAdminApi.fetchBoard(boardId, year);
      setDetail(nextDetail);
      setDraftEntries(buildEntryDrafts(nextDetail));
      setEditingKeys(new Set());
      if (nextDetail.year) {
        setYearInput(String(nextDetail.year));
      }
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载榜单详情失败');
    } finally {
      setLoadingDetail(false);
    }
  }, []);

  useEffect(() => {
    void loadBoards();
  }, [loadBoards]);

  useEffect(() => {
    if (!selectedBoardId) return;
    void loadBoardDetail(selectedBoardId);
  }, [loadBoardDetail, selectedBoardId]);

  const updateEntryDraft = (key: string, patch: Partial<RankingEntryDraft>) => {
    setDraftEntries((current) => current.map((item) => (item.key === key ? { ...item, ...patch } : item)));
  };

  const startEditing = (key: string) => {
    setEditingKeys((current) => new Set(current).add(key));
  };

  const cancelEditing = (key: string) => {
    setEditingKeys((current) => {
      const next = new Set(current);
      next.delete(key);
      return next;
    });
  };

  const confirmEditing = (key: string) => {
    const target = draftEntries.find((item) => item.key === key);
    if (!target) return;
    if (!target.name.trim()) {
      setError('榜单对象名称不能为空');
      return;
    }
    setError('');
    setEditingKeys((current) => {
      const next = new Set(current);
      next.delete(key);
      return next;
    });
  };

  const addEntry = () => {
    const nextRank = draftEntries.length ? Math.max(...draftEntries.map((item) => item.rank)) + 1 : 1;
    const key = `draft-${Date.now()}-${nextRank}`;
    setDraftEntries((current) => [
      ...current,
      {
        key,
        rank: nextRank,
        name: '',
        entityId: null,
        binding: null,
        delta: null,
      },
    ]);
    setEditingKeys((current) => new Set(current).add(key));
  };

  const removeEntry = (key: string) => {
    setDraftEntries((current) => current.filter((item) => item.key !== key));
    setEditingKeys((current) => {
      const next = new Set(current);
      next.delete(key);
      return next;
    });
  };

  const handleDeleteBoard = async () => {
    if (!selectedBoardId) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await rankingAdminApi.deleteBoard(selectedBoardId);
      setNotice('榜单已删除');
      setDetail(null);
      setDraftEntries([]);
      setEditingKeys(new Set());
      await loadBoards();
    } catch (deleteError) {
      setError(deleteError instanceof Error ? deleteError.message : '删除榜单失败');
    } finally {
      setSaving(false);
    }
  };

  const handleSelectYear = async (year: number) => {
    if (!detail?.boardId) return;
    await loadBoardDetail(detail.boardId, year);
  };

  const handleAddYear = async () => {
    if (!detail?.boardId) return;
    const year = Number(yearInput);
    if (!Number.isFinite(year) || year < 1900 || year > 2200) {
      setError('请输入有效年份');
      return;
    }
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await rankingAdminApi.upsertYear(detail.boardId, Math.floor(year), { entries: [] });
      await loadBoards(detail.boardId);
      await loadBoardDetail(detail.boardId, Math.floor(year));
      setNotice(`${detail.title} 已新增 ${Math.floor(year)} 年榜单`);
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '新增年份失败');
    } finally {
      setSaving(false);
    }
  };

  const handleSaveYear = async () => {
    if (!detail?.boardId || !detail.year) return;
    const normalizedEntries = sortedDraftEntries
      .map((entry) => ({
        rank: Number(entry.rank),
        name: entry.name.trim(),
        entityId: entry.entityId,
      }))
      .filter((entry) => entry.name);

    setSaving(true);
    setError('');
    setNotice('');
    try {
      await rankingAdminApi.upsertYear(detail.boardId, detail.year, {
        entries: normalizedEntries,
      });
      await loadBoardDetail(detail.boardId, detail.year);
      await loadBoards(detail.boardId);
      setNotice(`${detail.title} 的 ${detail.year} 年榜单已保存`);
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '保存榜单年份内容失败');
    } finally {
      setSaving(false);
    }
  };

  const handleOpenJsonOverlay = () => {
    setJsonOverlayOpen(true);
    setJsonText('');
    setJsonPreview(null);
    setJsonError('');
  };

  const handleFormatJson = () => {
    try {
      const parsed = parseJsonImport(jsonText);
      setJsonPreview(parsed);
      setJsonText(JSON.stringify(JSON.parse(jsonText), null, 2));
      setJsonError('');
    } catch (previewError) {
      setJsonPreview(null);
      setJsonError(previewError instanceof Error ? previewError.message : 'JSON 解析失败');
    }
  };

  const handleApplyJson = () => {
    if (!jsonPreview) {
      setJsonError('请先格式化并确认 JSON');
      return;
    }
    setDraftEntries(
      jsonPreview.entries.map((entry) => ({
        key: `json-${Date.now()}-${entry.rank}-${entry.name}`,
        rank: entry.rank,
        name: entry.name,
        entityId: entry.entityId,
        binding: null,
        delta: null,
      }))
    );
    setEditingKeys(new Set());
    setJsonOverlayOpen(false);
    setNotice(
      jsonPreview.year && detail?.year && jsonPreview.year !== detail.year
        ? `已回填 ${jsonPreview.entries.length} 条数据。导入 JSON 标注年份为 ${jsonPreview.year}，当前仍回填到 ${detail.year} 年。`
        : `已回填 ${jsonPreview.entries.length} 条榜单对象`
    );
  };

  const handleOpenAutoMatch = async () => {
    if (!detail?.boardId || !detail.year) return;
    setMatchOverlayOpen(true);
    setMatchPreview(null);
    setMatchError('');
    setMatchLoading(true);
    try {
      const preview = await rankingAdminApi.previewAutoMatch(detail.boardId, detail.year);
      setMatchPreview(preview);
    } catch (previewError) {
      setMatchError(previewError instanceof Error ? previewError.message : '加载自动匹配结果失败');
    } finally {
      setMatchLoading(false);
    }
  };

  const handleApplyAutoMatch = async () => {
    if (!detail?.boardId || !detail.year) return;
    setMatchApplying(true);
    setMatchError('');
    try {
      const nextPreview = await rankingAdminApi.applyAutoMatch(detail.boardId, detail.year);
      setMatchPreview(nextPreview);
      await loadBoardDetail(detail.boardId, detail.year);
      setNotice(`已自动匹配 ${nextPreview.matchedCount} 条唯一命中的对象`);
    } catch (applyError) {
      setMatchError(applyError instanceof Error ? applyError.message : '应用自动匹配失败');
    } finally {
      setMatchApplying(false);
    }
  };

  return (
    <AdminContentLayout
      title="榜单管理"
      description="榜单本体与年度内容分离管理。榜单名称、封面和简介单独编辑；具体某一年的榜单对象在这里维护。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
            返回内容控制台
          </Link>
          <Link href="/admin/content/rankings/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            新建榜单
          </Link>
        </>
      }
    >
      <section className="space-y-5">
        {error ? (
          <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] p-4 text-sm text-[#6a3530]">
            {error}
          </div>
        ) : null}
        {notice ? (
          <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-4 text-sm text-[#2f4027]">
            {notice}
          </div>
        ) : null}

        <div className="grid gap-5 xl:grid-cols-[320px_minmax(0,1fr)]">
          <section className="admin-reference-card p-5">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-xs uppercase tracking-[0.14em] text-black/38">Boards</div>
                <h2 className="mt-2 text-[20px] font-semibold text-[#111827]">榜单名称</h2>
              </div>
              <span className="admin-reference-chip">{boards.length}</span>
            </div>

            <div className="mt-4 space-y-3">
              {boards.map((board) => (
                <button
                  key={board.id}
                  type="button"
                  onClick={() => setSelectedBoardId(board.id)}
                  className={`admin-reference-soft-card w-full rounded-[20px] px-4 py-4 text-left ${
                    selectedBoardId === board.id ? 'border border-[#d7e8dc] bg-[#f6fbf7]' : ''
                  }`}
                >
                  <div className="flex items-start gap-3">
                    <div className="relative h-14 w-14 shrink-0 overflow-hidden rounded-[16px] border border-[#e8eceb] bg-[#f3f4f6]">
                      {board.coverImageUrl ? (
                        <Image src={board.coverImageUrl} alt={board.title} fill className="object-cover" sizes="120px" />
                      ) : null}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-[15px] font-semibold text-[#111827]">{board.title}</div>
                      <div className="mt-1 text-xs text-black/45">{board.subtitle || board.id}</div>
                      <div className="mt-2 flex flex-wrap items-center gap-2">
                        <span className="admin-reference-chip">{board.entityType === 'dj' ? 'DJ' : '主办方 / 品牌'}</span>
                        <span className="text-xs text-black/42">{board.years.length ? `${board.years.length} 个年份` : '暂无年份'}</span>
                      </div>
                    </div>
                  </div>
                </button>
              ))}

              {!boards.length && !loadingBoards ? (
                <div className="admin-reference-soft-card p-4 text-sm text-black/48">暂时还没有榜单。</div>
              ) : null}
            </div>
          </section>

          <section className="admin-reference-card p-5">
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div className="flex min-w-0 items-start gap-4">
                <div className="relative h-20 w-20 shrink-0 overflow-hidden rounded-[22px] border border-[#e8eceb] bg-[#f3f4f6]">
                  {selectedBoard?.coverImageUrl ? (
                    <Image src={selectedBoard.coverImageUrl} alt={selectedBoard.title} fill className="object-cover" sizes="200px" />
                  ) : null}
                </div>
                <div className="min-w-0">
                  <div className="text-xs uppercase tracking-[0.14em] text-black/38">Board Detail</div>
                  <h2 className="mt-2 text-[24px] font-semibold text-[#111827]">{selectedBoard?.title || '选择一个榜单'}</h2>
                  <div className="mt-2 text-sm text-black/50">
                    {detail
                      ? `${detail.entityType === 'festival' ? '主办方 / 品牌榜单' : 'DJ 榜单'}，榜单本体信息独立编辑，年份内容在这里维护。`
                      : '请先从左侧选择一个榜单。'}
                  </div>
                </div>
              </div>

              {selectedBoard ? (
                <div className="flex flex-wrap gap-2">
                  <Link
                    href={`/admin/content/rankings/${selectedBoard.id}/edit`}
                    className="inline-flex items-center gap-2 rounded-full border border-[#d7ded9] bg-white px-4 py-2 text-sm text-[#18211f]"
                  >
                    <Pencil className="h-4 w-4" />
                    编辑榜单
                  </Link>
                  <button
                    type="button"
                    className="inline-flex items-center gap-2 rounded-full border border-[#ead6d6] bg-white px-4 py-2 text-sm text-[#8b3a3a]"
                    disabled={!selectedBoardId || saving}
                    onClick={() => void handleDeleteBoard()}
                  >
                    <Trash2 className="h-4 w-4" />
                    删除榜单
                  </button>
                </div>
              ) : null}
            </div>

            {detail ? (
              <div className="mt-5 space-y-5">
                <div className="admin-reference-soft-card p-4 text-sm text-black/65">
                  <div>榜单名称：{detail.title}</div>
                  <div className="mt-1">榜单副标题：{detail.subtitle || '未设置'}</div>
                  <div className="mt-1">绑定对象类型：{detail.entityType === 'festival' ? '主办方 / 品牌' : 'DJ'}</div>
                  <div className="mt-1">简介：{detail.description || '未设置简介'}</div>
                </div>

                <div className="rounded-[20px] border border-[#e8eceb] bg-[#fafaf8] px-4 py-4">
                  <div className="flex flex-wrap items-end justify-between gap-3">
                    <div>
                      <div className="text-sm font-semibold text-[#111827]">年份管理</div>
                      <div className="mt-1 text-xs text-black/48">新建榜单时不录入任何单位。具体某一年，在这里新增并维护。</div>
                    </div>
                    <div className="flex flex-wrap items-center gap-2">
                      <input
                        className="rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm"
                        value={yearInput}
                        onChange={(event) => setYearInput(event.target.value)}
                        placeholder="年份"
                      />
                      <button
                        type="button"
                        onClick={() => void handleAddYear()}
                        className="inline-flex items-center gap-2 rounded-full border border-[#d7ded9] bg-white px-4 py-2 text-sm text-[#18211f]"
                      >
                        <Plus className="h-4 w-4" />
                        添加年份
                      </button>
                    </div>
                  </div>

                  <div className="mt-4 flex flex-wrap items-center gap-2">
                    {detail.years.map((year) => (
                      <button
                        key={year}
                        type="button"
                        className={`rounded-full px-4 py-2 text-sm ${
                          detail.year === year ? 'bg-[#071110] text-white' : 'border border-[#e8eceb] bg-white text-[#18211f]'
                        }`}
                        onClick={() => void handleSelectYear(year)}
                        disabled={loadingDetail}
                      >
                        {year}
                      </button>
                    ))}
                    {!detail.years.length ? <div className="text-sm text-black/48">当前榜单还没有任何年份。</div> : null}
                  </div>
                </div>

                {detail.year ? (
                  <>
                    <div className="flex flex-wrap items-center justify-between gap-3 rounded-[20px] border border-[#e8eceb] bg-[#fafaf8] px-4 py-4">
                      <div>
                        <div className="text-sm font-semibold text-[#111827]">{detail.year} 年榜单对象</div>
                        <div className="mt-1 text-xs text-black/48">默认按已确认状态展示。点击编辑后展开单条对象编辑框。</div>
                      </div>
                      <div className="flex flex-wrap gap-2">
                        <button
                          type="button"
                          onClick={() => void handleOpenAutoMatch()}
                          className="inline-flex items-center gap-2 rounded-full border border-[#d7ded9] bg-white px-4 py-2 text-sm text-[#18211f]"
                        >
                          <Sparkles className="h-4 w-4" />
                          自动匹配今年全部对象
                        </button>
                        <button
                          type="button"
                          onClick={handleOpenJsonOverlay}
                          className="inline-flex items-center gap-2 rounded-full border border-[#d7ded9] bg-white px-4 py-2 text-sm text-[#18211f]"
                        >
                          <Upload className="h-4 w-4" />
                          JSON 导入
                        </button>
                        <button
                          type="button"
                          onClick={addEntry}
                          className="inline-flex items-center gap-2 rounded-full border border-[#d7ded9] bg-white px-4 py-2 text-sm text-[#18211f]"
                        >
                          <Plus className="h-4 w-4" />
                          添加对象
                        </button>
                        <button
                          type="button"
                          onClick={() => void handleSaveYear()}
                          className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white"
                          disabled={saving}
                        >
                          {saving ? '保存中...' : '保存本年度'}
                        </button>
                      </div>
                    </div>

                    <div className="space-y-3">
                      {sortedDraftEntries.map((entry) => (
                        <EditableEntityBindingCard
                          key={entry.key}
                          header={
                            <div className="text-xs text-black/45">
                              {renderDelta(entry.delta)}
                            </div>
                          }
                          badge={<span className="admin-reference-chip">#{entry.rank}</span>}
                          name={entry.name}
                          nameValue={entry.name}
                          namePlaceholder="榜单对象名称"
                          bindingKind={detail.entityType === 'festival' ? 'festival' : 'dj'}
                          binding={entry.binding}
                          seedQuery={entry.name}
                          bindingTitle="绑定库内对象"
                          bindingEmptyLabel="当前还没有绑定到库内对象。"
                          isEditing={editingKeys.has(entry.key)}
                          onNameChange={(value) =>
                            updateEntryDraft(entry.key, {
                              name: value,
                            })
                          }
                          onAddBinding={(value) =>
                            updateEntryDraft(entry.key, {
                              entityId: value.id,
                              binding: value,
                            })
                          }
                          onRemoveBinding={() =>
                            updateEntryDraft(entry.key, {
                              entityId: null,
                              binding: null,
                            })
                          }
                          onEditStart={() => startEditing(entry.key)}
                          onEditCancel={() => cancelEditing(entry.key)}
                          onConfirm={() => confirmEditing(entry.key)}
                          onDelete={() => removeEntry(entry.key)}
                        />
                      ))}

                      {!sortedDraftEntries.length ? (
                        <div className="admin-reference-soft-card p-4 text-sm text-black/48">当前年份还没有榜单对象。</div>
                      ) : null}
                    </div>
                  </>
                ) : (
                  <div className="admin-reference-soft-card p-4 text-sm text-black/48">这个榜单还没有任何年份，请先新增年份。</div>
                )}
              </div>
            ) : (
              <div className="admin-reference-soft-card mt-4 p-4 text-sm text-black/48">
                {loadingDetail || loadingBoards ? '正在加载...' : '请从左侧选择一个榜单继续。'}
              </div>
            )}
          </section>
        </div>
      </section>

      {jsonOverlayOpen ? (
        <OverlayShell
          title="JSON 导入榜单对象"
          description="支持直接粘贴数组或包含 year / entries 的对象结构。格式化确认后，将回填到当前选中的年份。"
          onClose={() => setJsonOverlayOpen(false)}
        >
          <div className="space-y-4">
            <textarea
              className="min-h-[240px] w-full rounded-[20px] border border-[#e8eceb] bg-white px-4 py-3 text-sm"
              placeholder={`{\n  "year": 2026,\n  "entries": [\n    { "rank": 1, "name": "Artist A" },\n    { "rank": 2, "name": "Artist B" }\n  ]\n}`}
              value={jsonText}
              onChange={(event) => setJsonText(event.target.value)}
            />
            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                onClick={handleFormatJson}
                className="rounded-full border border-[#d7ded9] bg-white px-4 py-2 text-sm text-[#18211f]"
              >
                自动格式化
              </button>
              <button
                type="button"
                onClick={handleApplyJson}
                className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white"
                disabled={!jsonPreview}
              >
                确认回填
              </button>
            </div>
            {jsonError ? <div className="rounded-[16px] border border-[#f0d7d5] bg-[#fff7f6] px-4 py-3 text-sm text-[#8b3a3a]">{jsonError}</div> : null}
            {jsonPreview ? (
              <div className="rounded-[20px] border border-[#e8eceb] bg-white p-4">
                <div className="text-sm font-semibold text-[#111827]">导入预览</div>
                <div className="mt-2 text-xs text-black/48">
                  {jsonPreview.year ? `JSON 标注年份：${jsonPreview.year}` : 'JSON 未标注年份'} · 共 {jsonPreview.entries.length} 条对象
                </div>
                <div className="mt-3 max-h-[280px] space-y-2 overflow-y-auto">
                  {jsonPreview.entries.map((entry) => (
                    <div key={`preview-${entry.rank}-${entry.name}`} className="rounded-[14px] border border-[#edf0f2] px-3 py-3 text-sm text-[#111827]">
                      #{entry.rank} · {entry.name}
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
          </div>
        </OverlayShell>
      ) : null}

      {matchOverlayOpen ? (
        <OverlayShell
          title="自动匹配今年全部对象"
          description="先预览唯一命中、歧义和未命中的结果。确认后，只会应用唯一命中的匹配。"
          onClose={() => setMatchOverlayOpen(false)}
        >
          <div className="space-y-4">
            {matchError ? <div className="rounded-[16px] border border-[#f0d7d5] bg-[#fff7f6] px-4 py-3 text-sm text-[#8b3a3a]">{matchError}</div> : null}
            {matchLoading ? (
              <div className="admin-reference-soft-card p-4 text-sm text-black/50">正在加载自动匹配结果...</div>
            ) : null}
            {matchPreview ? (
              <>
                <div className="grid gap-3 sm:grid-cols-4">
                  {[
                    ['总条数', matchPreview.total],
                    ['已绑定', matchPreview.alreadyBoundCount],
                    ['唯一命中', matchPreview.matchedCount],
                    ['未命中 / 歧义', matchPreview.unmatchedCount + matchPreview.ambiguousCount],
                  ].map(([label, value]) => (
                    <div key={String(label)} className="rounded-[18px] border border-[#e8eceb] bg-white px-4 py-4">
                      <div className="text-xs uppercase tracking-[0.14em] text-black/38">{label}</div>
                      <div className="mt-2 text-[24px] font-semibold text-[#111827]">{value}</div>
                    </div>
                  ))}
                </div>

                <div className="flex flex-wrap gap-2">
                  <button
                    type="button"
                    onClick={() => void handleApplyAutoMatch()}
                    disabled={matchApplying || matchPreview.matchedCount === 0}
                    className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    {matchApplying ? '应用中...' : '确认应用唯一匹配'}
                  </button>
                </div>

                <div className="space-y-3">
                  {matchPreview.items.map((item) => (
                    <div key={`match-${item.rank}-${item.name}`} className="rounded-[18px] border border-[#e8eceb] bg-white px-4 py-4">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="admin-reference-chip">#{item.rank}</span>
                        <span className="text-sm font-semibold text-[#111827]">{item.name}</span>
                        <span
                          className={`rounded-full px-2.5 py-1 text-xs ${
                            item.status === 'already_bound'
                              ? 'bg-[#edf7f2] text-[#31513d]'
                              : item.status === 'matched'
                                ? 'bg-[#eef4ff] text-[#35558a]'
                                : item.status === 'ambiguous'
                                  ? 'bg-[#fff6dc] text-[#8a6a24]'
                                  : 'bg-[#fff2f0] text-[#8b3a3a]'
                          }`}
                        >
                          {item.status === 'already_bound'
                            ? '已绑定'
                            : item.status === 'matched'
                              ? '唯一命中'
                              : item.status === 'ambiguous'
                                ? '多候选'
                                : '未命中'}
                        </span>
                      </div>
                      <div className="mt-2 text-sm text-black/55">
                        {item.suggested
                          ? `建议绑定：${item.suggested.name}${item.suggested.subtitle ? ` · ${item.suggested.subtitle}` : ''}`
                          : item.current
                            ? `当前已绑定：${item.current.name}`
                            : '暂无可自动应用的绑定对象'}
                      </div>
                      {item.candidates.length > 1 ? (
                        <div className="mt-2 text-xs text-black/45">
                          候选对象：{item.candidates.map((candidate) => candidate.name).join(' / ')}
                        </div>
                      ) : null}
                    </div>
                  ))}
                </div>
              </>
            ) : null}
          </div>
        </OverlayShell>
      ) : null}
    </AdminContentLayout>
  );
}
