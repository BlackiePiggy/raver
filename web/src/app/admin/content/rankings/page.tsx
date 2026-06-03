'use client';

import Link from 'next/link';
import { Pencil, Plus, Trash2 } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import EntityBindingField from '@/components/admin/EntityBindingField';
import type { EntityBindingValue } from '@/components/admin/EntityBindingSearch';
import {
  rankingAdminApi,
  type RankingBoardDetail,
  type RankingBoardDetailEntry,
  type RankingBoardSummary,
  type RankingEntityType,
} from '@/features/admin-content/ranking-admin';

type RankingEntryDraft = {
  key: string;
  rank: number;
  name: string;
  entityId: string | null;
  binding: EntityBindingValue | null;
  delta: number | null;
};

const renderDelta = (value: number | null): string => {
  if (value === null || value === 0) return '排名无变化';
  if (value > 0) return `较去年上升 ${value} 位`;
  return `较去年下降 ${Math.abs(value)} 位`;
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

  const selectedBoard = useMemo(
    () => boards.find((item) => item.id === selectedBoardId) ?? null,
    [boards, selectedBoardId]
  );

  const sortedDraftEntries = useMemo(
    () => [...draftEntries].sort((a, b) => a.rank - b.rank || a.name.localeCompare(b.name, 'zh-CN')),
    [draftEntries]
  );

  const loadBoards = async (preferredBoardId?: string) => {
    setLoadingBoards(true);
    setError('');
    try {
      const items = await rankingAdminApi.listBoards();
      setBoards(items);
      const nextSelected = (preferredBoardId ?? selectedBoardId) || items[0]?.id || '';
      setSelectedBoardId(nextSelected);
      if (!nextSelected) {
        setDetail(null);
        setDraftEntries([]);
        setEditingKeys(new Set());
      }
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载榜单列表失败。');
    } finally {
      setLoadingBoards(false);
    }
  };

  const loadBoardDetail = async (boardId: string, year?: number | null) => {
    setLoadingDetail(true);
    setError('');
    try {
      const nextDetail = await rankingAdminApi.fetchBoard(boardId, year);
      setDetail(nextDetail);
      setDraftEntries(buildEntryDrafts(nextDetail));
      setEditingKeys(new Set());
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载榜单详情失败。');
    } finally {
      setLoadingDetail(false);
    }
  };

  useEffect(() => {
    void loadBoards();
  }, []);

  useEffect(() => {
    if (!selectedBoardId) return;
    void loadBoardDetail(selectedBoardId);
  }, [selectedBoardId]);

  const handleDeleteBoard = async () => {
    if (!selectedBoardId) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await rankingAdminApi.deleteBoard(selectedBoardId);
      setNotice('榜单已删除。');
      setDetail(null);
      setDraftEntries([]);
      setEditingKeys(new Set());
      await loadBoards();
    } catch (deleteError) {
      setError(deleteError instanceof Error ? deleteError.message : '删除榜单失败。');
    } finally {
      setSaving(false);
    }
  };

  const handleSelectYear = async (year: number) => {
    if (!detail?.boardId) return;
    await loadBoardDetail(detail.boardId, year);
  };

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
      setError('榜单条目名称不能为空。');
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
    const nextRank = draftEntries.length
      ? Math.max(...draftEntries.map((item) => item.rank)) + 1
      : 1;
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

  const handleSaveYear = async () => {
    if (!detail?.boardId || !detail.year) return;
    const normalizedEntries = sortedDraftEntries
      .map((entry) => ({
        rank: Number(entry.rank),
        name: entry.name.trim(),
        entityId: entry.entityId,
      }))
      .filter((entry) => entry.name);

    if (!normalizedEntries.length) {
      setError('当前年份至少需要保留一条榜单对象。');
      return;
    }

    setSaving(true);
    setError('');
    setNotice('');
    try {
      await rankingAdminApi.upsertYear(detail.boardId, detail.year, {
        entries: normalizedEntries,
      });
      await loadBoardDetail(detail.boardId, detail.year);
      setNotice(`${detail.title} 的 ${detail.year} 年榜单已保存。`);
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '保存榜单年份内容失败。');
    } finally {
      setSaving(false);
    }
  };

  return (
    <AdminContentLayout
      title="榜单管理"
      description="按年份维护榜单对象，并为每一条榜单对象绑定库内 DJ 或主办方品牌。"
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
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="truncate text-[15px] font-semibold text-[#111827]">{board.title}</div>
                      <div className="mt-1 text-xs text-black/45">{board.subtitle || board.id}</div>
                    </div>
                    <span className="admin-reference-chip">{board.entityType === 'dj' ? 'DJ' : '主办方 / 品牌'}</span>
                  </div>
                </button>
              ))}

              {!boards.length && !loadingBoards ? (
                <div className="admin-reference-soft-card p-4 text-sm text-black/48">暂时还没有榜单。</div>
              ) : null}
            </div>
          </section>

          <section className="admin-reference-card p-5">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <div className="text-xs uppercase tracking-[0.14em] text-black/38">Details</div>
                <h2 className="mt-2 text-[20px] font-semibold text-[#111827]">{selectedBoard?.title || '选择一个榜单'}</h2>
                <div className="mt-1 text-sm text-black/48">
                  {detail
                    ? `${detail.entityType === 'festival' ? '主办方 / 品牌榜单' : 'DJ 榜单'}，年份只在右侧切换。`
                    : '请先从左侧选择一个榜单。'}
                </div>
              </div>
              <button
                type="button"
                className="rounded-full border border-[#e8d9d9] bg-white px-4 py-2 text-sm text-[#8b3a3a]"
                disabled={!selectedBoardId || saving}
                onClick={() => void handleDeleteBoard()}
              >
                删除榜单
              </button>
            </div>

            {detail ? (
              <div className="mt-5 space-y-5">
                <div className="admin-reference-soft-card p-4 text-sm text-black/65">
                  <div>标题：{detail.title}</div>
                  <div className="mt-1">副标题：{detail.subtitle || '未设置'}</div>
                  <div className="mt-1">绑定策略：{detail.strictEntityBinding ? '仅允许严格 entityId 绑定' : '允许名称回退匹配'}</div>
                </div>

                <div className="flex flex-wrap items-center gap-2">
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
                </div>

                <div className="flex flex-wrap items-center justify-between gap-3 rounded-[20px] border border-[#e8eceb] bg-[#fafaf8] px-4 py-4">
                  <div>
                    <div className="text-sm font-semibold text-[#111827]">
                      {detail.year ? `${detail.year} 年榜单对象` : '年份内容'}
                    </div>
                    <div className="mt-1 text-xs text-black/48">每条对象默认以确认态展示，点击编辑后展开为可编辑状态。</div>
                  </div>
                  <div className="flex flex-wrap gap-2">
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
                      disabled={saving || !detail.year}
                    >
                      {saving ? '保存中...' : '保存本年度'}
                    </button>
                  </div>
                </div>

                <div className="space-y-3">
                  {sortedDraftEntries.map((entry) => {
                    const isEditing = editingKeys.has(entry.key);
                    const isBound = Boolean(entry.entityId && entry.binding);
                    return (
                      <div key={entry.key} className="admin-reference-card p-4">
                        {!isEditing ? (
                          <div className="flex flex-wrap items-center justify-between gap-4">
                            <div className="min-w-0">
                              <div className="flex flex-wrap items-center gap-2">
                                <span className="admin-reference-chip">#{entry.rank}</span>
                                <span className="text-base font-semibold text-[#111827]">{entry.name || '未命名对象'}</span>
                                <span className={`rounded-full px-2.5 py-1 text-xs ${isBound ? 'bg-[#edf7f2] text-[#31513d]' : 'bg-[#f7efda] text-[#7a5a25]'}`}>
                                  {isBound ? '已绑定' : '未绑定'}
                                </span>
                              </div>
                              <div className="mt-2 text-xs text-black/45">{renderDelta(entry.delta)}</div>
                              <div className="mt-2 text-sm text-black/55">
                                {entry.binding
                                  ? `绑定对象：${entry.binding.name}${entry.binding.subtitle ? ` · ${entry.binding.subtitle}` : ''}`
                                  : '当前还没有绑定到库内对象。'}
                              </div>
                            </div>
                            <div className="flex items-center gap-2">
                              <button
                                type="button"
                                onClick={() => startEditing(entry.key)}
                                className="inline-flex items-center gap-2 rounded-full border border-[#d7ded9] bg-white px-4 py-2 text-sm text-[#18211f]"
                              >
                                <Pencil className="h-4 w-4" />
                                编辑
                              </button>
                              <button
                                type="button"
                                onClick={() => removeEntry(entry.key)}
                                className="inline-flex items-center gap-2 rounded-full border border-[#ead6d6] bg-white px-4 py-2 text-sm text-[#8b3a3a]"
                              >
                                <Trash2 className="h-4 w-4" />
                                删除
                              </button>
                            </div>
                          </div>
                        ) : (
                          <div className="space-y-4">
                            <div className="flex flex-wrap items-center justify-between gap-3">
                              <div className="text-sm font-semibold text-[#111827]">编辑榜单对象</div>
                              <span className="admin-reference-chip">#{entry.rank}</span>
                            </div>

                            <div className="grid gap-3 md:grid-cols-[120px_minmax(0,1fr)]">
                              <input
                                className="rounded-[16px] border border-[#e8eceb] bg-white px-3 py-3 text-sm"
                                value={String(entry.rank)}
                                onChange={(event) =>
                                  updateEntryDraft(entry.key, {
                                    rank: Number(event.target.value) || entry.rank,
                                  })
                                }
                              />
                              <input
                                className="rounded-[16px] border border-[#e8eceb] bg-white px-3 py-3 text-sm"
                                placeholder="榜单对象名称"
                                value={entry.name}
                                onChange={(event) =>
                                  updateEntryDraft(entry.key, {
                                    name: event.target.value,
                                  })
                                }
                              />
                            </div>

                            <EntityBindingField
                              kind={detail.entityType === 'festival' ? 'festival' : 'dj'}
                              mode="single"
                              seedQuery={entry.name}
                              items={entry.binding ? [entry.binding] : []}
                              title="绑定库内对象"
                              emptyLabel="当前还没有绑定到库内对象。"
                              onAdd={(value) =>
                                updateEntryDraft(entry.key, {
                                  entityId: value.id,
                                  binding: value,
                                })
                              }
                              onRemove={() =>
                                updateEntryDraft(entry.key, {
                                  entityId: null,
                                  binding: null,
                                })
                              }
                            />

                            <div className="flex flex-wrap justify-end gap-2">
                              <button
                                type="button"
                                onClick={() => cancelEditing(entry.key)}
                                className="rounded-full border border-[#e7ebef] bg-white px-4 py-2 text-sm font-semibold text-[#111827]"
                              >
                                收起
                              </button>
                              <button
                                type="button"
                                onClick={() => confirmEditing(entry.key)}
                                className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white"
                              >
                                确认
                              </button>
                            </div>
                          </div>
                        )}
                      </div>
                    );
                  })}

                  {!sortedDraftEntries.length ? (
                    <div className="admin-reference-soft-card p-4 text-sm text-black/48">当前年份还没有榜单对象。</div>
                  ) : null}
                </div>
              </div>
            ) : (
              <div className="admin-reference-soft-card mt-4 p-4 text-sm text-black/48">
                {loadingDetail || loadingBoards ? '正在加载...' : '请从左侧选择一个榜单继续。'}
              </div>
            )}
          </section>
        </div>
      </section>
    </AdminContentLayout>
  );
}
