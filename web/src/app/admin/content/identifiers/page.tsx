'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import {
  identifierAdminApi,
  type IdentifierLabelItem,
  type IdentifierOrganizerItem,
  type IdentifierRankingEntryItem,
} from '@/features/admin-content/identifier-admin';

type IdentifierTab = 'organizers' | 'labels' | 'rankings';

export default function AdminIdentifiersPage() {
  const [tab, setTab] = useState<IdentifierTab>('organizers');
  const [search, setSearch] = useState('');
  const [organizers, setOrganizers] = useState<IdentifierOrganizerItem[]>([]);
  const [labels, setLabels] = useState<IdentifierLabelItem[]>([]);
  const [rankingEntries, setRankingEntries] = useState<IdentifierRankingEntryItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [savingKey, setSavingKey] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      if (tab === 'organizers') {
        const payload = await identifierAdminApi.listOrganizers(search);
        setOrganizers(payload.items);
      } else if (tab === 'labels') {
        const payload = await identifierAdminApi.listLabels(search);
        setLabels(payload.items);
      } else {
        const payload = await identifierAdminApi.listRankingEntries(search);
        setRankingEntries(payload.items);
      }
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '加载 ID 管理数据失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, [tab]);

  const saveOrganizer = async (item: IdentifierOrganizerItem, nextValue: string) => {
    const key = `organizer-${item.id}`;
    setSavingKey(key);
    setError('');
    setNotice('');
    try {
      await identifierAdminApi.updateOrganizer(item.id, {
        sourceRowId: nextValue.trim() ? Number(nextValue) : null,
      });
      setNotice(`已更新主办方 ${item.name} 的 sourceRowId`);
      await load();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '更新主办方标识失败');
    } finally {
      setSavingKey('');
    }
  };

  const saveLabel = async (item: IdentifierLabelItem, next: { slug: string; profileSlug: string; profileUrl: string }) => {
    const key = `label-${item.id}`;
    setSavingKey(key);
    setError('');
    setNotice('');
    try {
      await identifierAdminApi.updateLabel(item.id, next);
      setNotice(`已更新厂牌 ${item.name} 的标识字段`);
      await load();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '更新厂牌标识失败');
    } finally {
      setSavingKey('');
    }
  };

  const saveRankingEntry = async (item: IdentifierRankingEntryItem, entityId: string) => {
    const key = `ranking-${item.boardId}-${item.year}-${item.rank}`;
    setSavingKey(key);
    setError('');
    setNotice('');
    try {
      await identifierAdminApi.updateRankingEntry(item.boardId, item.year, item.rank, {
        entityId: entityId.trim() || null,
      });
      setNotice(`已更新 ${item.boardTitle} ${item.year} #${item.rank} 的 entityId`);
      await load();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '更新榜单条目标识失败');
    } finally {
      setSavingKey('');
    }
  };

  return (
    <AdminContentLayout
      title="ID 管理"
      description="统一维护主办方、厂牌与榜单条目的关键标识字段，优先解决 sourceRowId、slug、profile 与 entityId 的对齐问题。"
      actions={
        <Link href="/admin/content" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
          返回内容控制台
        </Link>
      }
    >
      <section className="space-y-5">
        {error ? <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] p-4 text-sm text-[#6a3530]">{error}</div> : null}
        {notice ? <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-4 text-sm text-[#2f4027]">{notice}</div> : null}
        <section className="admin-reference-card p-5">
          <div className="flex flex-wrap items-center gap-3">
            {[
              ['organizers', '主办方 sourceRowId'],
              ['labels', '厂牌 slug / profile'],
              ['rankings', '榜单 entityId'],
            ].map(([value, label]) => (
              <button
                key={value}
                type="button"
                onClick={() => setTab(value as IdentifierTab)}
                className={`rounded-full px-4 py-2 text-sm ${tab === value ? 'bg-[#071110] text-white' : 'border border-[#e8eceb] bg-white text-[#18211f]'}`}
              >
                {label}
              </button>
            ))}
            <div className="ml-auto flex items-center gap-3">
              <input className="admin-reference-soft-card px-4 py-2 text-sm" placeholder="搜索名称 / ID" value={search} onChange={(event) => setSearch(event.target.value)} />
              <button type="button" className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white" onClick={() => void load()} disabled={loading}>
                {loading ? '加载中...' : '搜索'}
              </button>
            </div>
          </div>
        </section>

        {tab === 'organizers' ? (
          <section className="admin-reference-card overflow-hidden">
            <div className="grid grid-cols-[minmax(0,1.2fr)_200px_240px] gap-0 border-b border-[#eef1ee] bg-[#fafbf9] px-5 py-3 text-xs font-semibold uppercase tracking-[0.12em] text-black/42">
              <div>主办方</div>
              <div>sourceRowId</div>
              <div>操作</div>
            </div>
            {organizers.map((item) => {
              let nextValue = String(item.sourceRowId ?? '');
              return (
                <div key={item.id} className="grid grid-cols-[minmax(0,1.2fr)_200px_240px] items-center gap-0 border-b border-[#f1f3f2] px-5 py-4">
                  <div>
                    <div className="text-sm font-semibold text-[#111827]">{item.name}</div>
                    <div className="mt-1 text-xs text-black/45">{item.id}</div>
                  </div>
                  <input className="rounded-[14px] border border-[#e8eceb] bg-white px-3 py-2 text-sm" defaultValue={nextValue} onChange={(event) => { nextValue = event.target.value; }} />
                  <div>
                    <button type="button" className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white" disabled={savingKey === `organizer-${item.id}`} onClick={() => void saveOrganizer(item, nextValue)}>
                      {savingKey === `organizer-${item.id}` ? '保存中...' : '保存'}
                    </button>
                  </div>
                </div>
              );
            })}
            {!organizers.length ? <div className="p-5 text-sm text-black/48">{loading ? '加载中...' : '暂无主办方数据。'}</div> : null}
          </section>
        ) : null}

        {tab === 'labels' ? (
          <section className="space-y-4">
            {labels.map((item) => {
              let nextSlug = item.slug;
              let nextProfileSlug = item.profileSlug ?? '';
              let nextProfileUrl = item.profileUrl;
              return (
                <div key={item.id} className="admin-reference-card p-5">
                  <div className="text-[16px] font-semibold text-[#111827]">{item.name}</div>
                  <div className="mt-1 text-xs text-black/45">{item.id}</div>
                  <div className="mt-4 grid gap-3 xl:grid-cols-3">
                    <input className="admin-reference-soft-card px-4 py-3 text-sm" defaultValue={item.slug} placeholder="slug" onChange={(event) => { nextSlug = event.target.value; }} />
                    <input className="admin-reference-soft-card px-4 py-3 text-sm" defaultValue={item.profileSlug ?? ''} placeholder="profileSlug" onChange={(event) => { nextProfileSlug = event.target.value; }} />
                    <input className="admin-reference-soft-card px-4 py-3 text-sm" defaultValue={item.profileUrl} placeholder="profileUrl" onChange={(event) => { nextProfileUrl = event.target.value; }} />
                  </div>
                  <button type="button" className="mt-4 rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white" disabled={savingKey === `label-${item.id}`} onClick={() => void saveLabel(item, { slug: nextSlug, profileSlug: nextProfileSlug, profileUrl: nextProfileUrl })}>
                    {savingKey === `label-${item.id}` ? '保存中...' : '保存厂牌标识'}
                  </button>
                </div>
              );
            })}
            {!labels.length ? <div className="admin-reference-soft-card p-5 text-sm text-black/48">{loading ? '加载中...' : '暂无厂牌数据。'}</div> : null}
          </section>
        ) : null}

        {tab === 'rankings' ? (
          <section className="space-y-4">
            {rankingEntries.map((item) => {
              let nextEntityId = item.entityId ?? '';
              return (
                <div key={`${item.boardId}-${item.year}-${item.rank}`} className="admin-reference-card p-5">
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <div className="text-[16px] font-semibold text-[#111827]">{item.boardTitle} · {item.year} · #{item.rank}</div>
                      <div className="mt-1 text-sm text-black/52">{item.name}</div>
                    </div>
                    <span className="admin-reference-chip">{item.entityType}</span>
                  </div>
                  <div className="mt-4 flex flex-wrap gap-3">
                    <input className="admin-reference-soft-card min-w-[320px] flex-1 px-4 py-3 text-sm" defaultValue={item.entityId ?? ''} placeholder="entityId" onChange={(event) => { nextEntityId = event.target.value; }} />
                    <button type="button" className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white" disabled={savingKey === `ranking-${item.boardId}-${item.year}-${item.rank}`} onClick={() => void saveRankingEntry(item, nextEntityId)}>
                      {savingKey === `ranking-${item.boardId}-${item.year}-${item.rank}` ? '保存中...' : '保存 entityId'}
                    </button>
                  </div>
                </div>
              );
            })}
            {!rankingEntries.length ? <div className="admin-reference-soft-card p-5 text-sm text-black/48">{loading ? '加载中...' : '暂无榜单条目数据。'}</div> : null}
          </section>
        ) : null}
      </section>
    </AdminContentLayout>
  );
}
