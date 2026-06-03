'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import {
  rankingAdminApi,
  type RankingBoardDetail,
  type RankingBoardEntry,
  type RankingBoardSummary,
} from '@/features/admin-content/ranking-admin';

const emptyEntry = (rank = 1): RankingBoardEntry => ({ rank, name: '', entityId: '' });

export default function AdminRankingPage() {
  const [boards, setBoards] = useState<RankingBoardSummary[]>([]);
  const [selectedBoardId, setSelectedBoardId] = useState<string>('');
  const [detail, setDetail] = useState<RankingBoardDetail | null>(null);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [createDraft, setCreateDraft] = useState({
    id: '',
    title: '',
    subtitle: '',
    description: '',
    entityType: 'dj' as 'dj' | 'festival',
    year: String(new Date().getFullYear()),
    coverImageUrl: '',
  });
  const [entriesDraft, setEntriesDraft] = useState<RankingBoardEntry[]>([emptyEntry(1), emptyEntry(2), emptyEntry(3)]);
  const [importText, setImportText] = useState('');

  const selectedBoard = useMemo(
    () => boards.find((item) => item.id === selectedBoardId) ?? null,
    [boards, selectedBoardId]
  );

  const loadBoards = async (preferredBoardId?: string) => {
    setLoading(true);
    setError('');
    try {
      const items = await rankingAdminApi.listBoards();
      setBoards(items);
      const nextId = preferredBoardId ?? selectedBoardId ?? items[0]?.id ?? '';
      setSelectedBoardId(nextId);
      if (nextId) {
        const nextDetail = await rankingAdminApi.fetchBoard(nextId);
        setDetail(nextDetail);
      } else {
        setDetail(null);
      }
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '加载榜单失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadBoards();
  }, []);

  useEffect(() => {
    if (!selectedBoardId) return;
    setLoading(true);
    setError('');
    void rankingAdminApi
      .fetchBoard(selectedBoardId)
      .then((payload) => setDetail(payload))
      .catch((nextError) => setError(nextError instanceof Error ? nextError.message : '加载榜单详情失败'))
      .finally(() => setLoading(false));
  }, [selectedBoardId]);

  const handleCreateBoard = async () => {
    setSaving(true);
    setError('');
    setNotice('');
    try {
      const created = await rankingAdminApi.createBoard({
        id: createDraft.id || undefined,
        title: createDraft.title,
        subtitle: createDraft.subtitle,
        description: createDraft.description,
        entityType: createDraft.entityType,
        year: Number(createDraft.year),
        coverImageUrl: createDraft.coverImageUrl || null,
        entries: entriesDraft.filter((item) => item.name.trim()),
        importText: importText.trim(),
      });
      setNotice(`已创建榜单：${created.title}`);
      await loadBoards(created.id);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '创建榜单失败');
    } finally {
      setSaving(false);
    }
  };

  const handleUpsertYear = async () => {
    if (!detail?.boardId || !detail.year) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await rankingAdminApi.upsertYear(detail.boardId, detail.year, {
        entries: entriesDraft.filter((item) => item.name.trim()),
        importText: importText.trim(),
      });
      const nextDetail = await rankingAdminApi.fetchBoard(detail.boardId, detail.year);
      setDetail(nextDetail);
      setNotice(`已更新 ${detail.year} 年榜单条目`);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '更新年份条目失败');
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteBoard = async () => {
    if (!selectedBoardId) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await rankingAdminApi.deleteBoard(selectedBoardId);
      setNotice('榜单已删除');
      await loadBoards();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '删除榜单失败');
    } finally {
      setSaving(false);
    }
  };

  return (
    <AdminContentLayout
      title="榜单管理"
      description="管理 DJ / Festival 榜单、年份条目、封面图与实体绑定，支持手动维护与导入文本双模式。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
            返回内容控制台
          </Link>
        </>
      }
    >
      <section className="space-y-5">
        {error ? <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] p-4 text-sm text-[#6a3530]">{error}</div> : null}
        {notice ? <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-4 text-sm text-[#2f4027]">{notice}</div> : null}

        <div className="grid gap-5 xl:grid-cols-[360px_minmax(0,1fr)]">
          <section className="admin-reference-card p-5">
            <div className="flex items-center justify-between">
              <h2 className="text-[20px] font-semibold text-[#111827]">榜单目录</h2>
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
                  <div className="flex items-center justify-between gap-3">
                    <div className="min-w-0">
                      <div className="truncate text-[16px] font-semibold text-[#111827]">{board.title}</div>
                      <div className="mt-1 text-xs text-black/48">{board.id}</div>
                    </div>
                    <span className="admin-reference-chip">{board.entityType}</span>
                  </div>
                  <div className="mt-3 text-sm text-black/52">{board.years.length ? board.years.join(' / ') : '暂无年份'}</div>
                </button>
              ))}
              {!boards.length && !loading ? <div className="admin-reference-soft-card p-4 text-sm text-black/48">暂无榜单。</div> : null}
            </div>
          </section>

          <div className="space-y-5">
            <section className="admin-reference-card p-5">
              <h2 className="text-[20px] font-semibold text-[#111827]">新建榜单</h2>
              <div className="mt-4 grid gap-4 md:grid-cols-2">
                <input className="admin-reference-soft-card px-4 py-3 text-sm" placeholder="榜单 ID（可选）" value={createDraft.id} onChange={(event) => setCreateDraft((prev) => ({ ...prev, id: event.target.value }))} />
                <input className="admin-reference-soft-card px-4 py-3 text-sm" placeholder="榜单标题" value={createDraft.title} onChange={(event) => setCreateDraft((prev) => ({ ...prev, title: event.target.value }))} />
                <input className="admin-reference-soft-card px-4 py-3 text-sm" placeholder="副标题" value={createDraft.subtitle} onChange={(event) => setCreateDraft((prev) => ({ ...prev, subtitle: event.target.value }))} />
                <input className="admin-reference-soft-card px-4 py-3 text-sm" placeholder="年份" value={createDraft.year} onChange={(event) => setCreateDraft((prev) => ({ ...prev, year: event.target.value }))} />
                <select className="admin-reference-soft-card px-4 py-3 text-sm" value={createDraft.entityType} onChange={(event) => setCreateDraft((prev) => ({ ...prev, entityType: event.target.value as 'dj' | 'festival' }))}>
                  <option value="dj">DJ 榜单</option>
                  <option value="festival">Festival 榜单</option>
                </select>
                <input className="admin-reference-soft-card px-4 py-3 text-sm" placeholder="封面图片 URL（可选）" value={createDraft.coverImageUrl} onChange={(event) => setCreateDraft((prev) => ({ ...prev, coverImageUrl: event.target.value }))} />
              </div>
              <textarea className="admin-reference-soft-card mt-4 min-h-[110px] w-full px-4 py-3 text-sm" placeholder="榜单描述" value={createDraft.description} onChange={(event) => setCreateDraft((prev) => ({ ...prev, description: event.target.value }))} />
              <div className="mt-4 grid gap-4 xl:grid-cols-2">
                <div className="admin-reference-soft-card p-4">
                  <div className="text-sm font-semibold text-[#111827]">手动条目</div>
                  <div className="mt-3 space-y-3">
                    {entriesDraft.map((entry, index) => (
                      <div key={`create-entry-${index}`} className="grid gap-2 md:grid-cols-[88px_minmax(0,1fr)]">
                        <input
                          className="rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm"
                          value={String(entry.rank)}
                          onChange={(event) =>
                            setEntriesDraft((prev) =>
                              prev.map((item, itemIndex) => itemIndex === index ? { ...item, rank: Number(event.target.value) || item.rank } : item)
                            )
                          }
                        />
                        <input
                          className="rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm"
                          placeholder="艺人 / 活动名称"
                          value={entry.name}
                          onChange={(event) =>
                            setEntriesDraft((prev) =>
                              prev.map((item, itemIndex) => itemIndex === index ? { ...item, name: event.target.value } : item)
                            )
                          }
                        />
                      </div>
                    ))}
                    <button type="button" className="rounded-full border border-[#d7ded9] px-4 py-2 text-sm" onClick={() => setEntriesDraft((prev) => [...prev, emptyEntry(prev.length + 1)])}>
                      添加一行
                    </button>
                  </div>
                </div>
                <div className="admin-reference-soft-card p-4">
                  <div className="text-sm font-semibold text-[#111827]">导入文本</div>
                  <textarea className="mt-3 min-h-[180px] w-full rounded-[16px] border border-[#e8eceb] bg-white px-3 py-3 text-sm" placeholder={`1. Artist A\n2. Artist B`} value={importText} onChange={(event) => setImportText(event.target.value)} />
                </div>
              </div>
              <div className="mt-4 flex flex-wrap gap-3">
                <button type="button" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white" disabled={saving} onClick={handleCreateBoard}>
                  {saving ? '提交中...' : '创建榜单'}
                </button>
              </div>
            </section>

            <section className="admin-reference-card p-5">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h2 className="text-[20px] font-semibold text-[#111827]">当前榜单</h2>
                  <div className="mt-1 text-sm text-black/48">{selectedBoard ? selectedBoard.title : '请选择左侧榜单'}</div>
                </div>
                <div className="flex flex-wrap gap-3">
                  <button type="button" className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm" disabled={!selectedBoardId || saving} onClick={handleDeleteBoard}>
                    删除榜单
                  </button>
                </div>
              </div>
              {detail ? (
                <div className="mt-4 space-y-4">
                  <div className="admin-reference-soft-card p-4 text-sm text-black/65">
                    <div>标题：{detail.title}</div>
                    <div className="mt-1">年份：{detail.years.join(' / ') || '暂无'}</div>
                    <div className="mt-1">绑定模式：{detail.strictEntityBinding ? '严格 entityId 绑定' : '允许名称回退匹配'}</div>
                  </div>
                  <div className="admin-reference-soft-card p-4">
                    <div className="text-sm font-semibold text-[#111827]">更新当前年份</div>
                    <div className="mt-3 space-y-3">
                      {(detail.entries.length ? detail.entries : entriesDraft).map((entry, index) => (
                        <div key={`detail-entry-${index}`} className="grid gap-2 md:grid-cols-[88px_minmax(0,1fr)]">
                          <div className="rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm">{entry.rank}</div>
                          <div className="rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm">{entry.name}</div>
                        </div>
                      ))}
                    </div>
                    <button type="button" className="mt-4 rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white" disabled={saving || !detail.year} onClick={handleUpsertYear}>
                      {saving ? '保存中...' : `更新 ${detail.year ?? ''} 年条目`}
                    </button>
                  </div>
                </div>
              ) : (
                <div className="admin-reference-soft-card mt-4 p-4 text-sm text-black/48">{loading ? '加载中...' : '请选择一个榜单查看详情。'}</div>
              )}
            </section>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
