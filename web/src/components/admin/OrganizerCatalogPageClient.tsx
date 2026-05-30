'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useCallback, useEffect, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import {
  organizerCatalogApi,
  OrganizerCatalogItem,
  OrganizerCatalogPagination,
} from '@/features/admin-content/organizer-catalog/api';

const PAGE_SIZE = 24;

const EMPTY_PAGINATION: OrganizerCatalogPagination = {
  page: 1,
  limit: PAGE_SIZE,
  total: 0,
  totalPages: 1,
};

const formatDateTime = (value?: string | null): string => {
  if (!value) return '未记录';
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
};

const resolvePrimaryVisual = (item: OrganizerCatalogItem): string | null =>
  item.avatarUrl || item.backgroundUrl || null;

export default function OrganizerCatalogPageClient() {
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [items, setItems] = useState<OrganizerCatalogItem[]>([]);
  const [pagination, setPagination] = useState<OrganizerCatalogPagination>(EMPTY_PAGINATION);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  const loadCatalog = useCallback(async () => {
    try {
      setIsLoading(true);
      setError('');
      const response = await organizerCatalogApi.fetchOrganizers({
        page,
        limit: PAGE_SIZE,
        search: search || undefined,
      });
      setItems(response.items);
      setPagination(response.pagination);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '主办方目录加载失败');
    } finally {
      setIsLoading(false);
    }
  }, [page, search]);

  useEffect(() => {
    void loadCatalog();
  }, [loadCatalog]);

  const handleSearchSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setPage(1);
    setSearch(searchInput.trim());
  };

  const handleReset = () => {
    setSearchInput('');
    setSearch('');
    setPage(1);
  };

  return (
    <AdminContentLayout
      title="主办方目录中心"
      eyebrow="Admin / Content Workspace / Organizer Catalog"
      description="统一查看主办方目录、资料摘要、绑定入口与编辑入口。目录层保持轻量检索，进入编辑或绑定时再进入更深的操作流。"
      actions={
        <>
          <Link href="/admin/content/organizers" className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-4 py-2 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
            返回主办方工作区
          </Link>
          <button
            type="button"
            onClick={() => void loadCatalog()}
            className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-4 py-2 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white"
          >
            刷新目录
          </button>
          <Link href="/admin/content/organizers/new" className="rounded-xl bg-[#a8ff3e] px-4 py-2 text-sm font-semibold text-black">
            新建主办方
          </Link>
        </>
      }
    >
      <section className="grid gap-5 xl:grid-cols-[1.35fr_0.95fr]">
        <div className="rounded-[18px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] p-6">
          <div className="text-[11px] uppercase tracking-[0.18em] text-[#5f5f5f]">Catalog Scope</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#f0f0f0]">目录、编辑、绑定统一收口</h2>
          <div className="mt-5 grid gap-3 md:grid-cols-3">
            {[
              '目录层先原生承接名称、地区、视觉和链接的全量定位能力',
              '进入编辑页后继续沿用已经落地的 Organizer Studio create / edit 主链路',
              '活动绑定关系继续通过统一后台活动绑定中心处理，不再把目录能力散落到旧工具',
            ].map((item) => (
              <div key={item} className="rounded-[14px] border border-[rgba(255,255,255,0.07)] bg-[#151515] px-4 py-3 text-sm leading-6 text-[#d2d2d2]">
                {item}
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-[18px] border border-[rgba(168,255,62,0.18)] bg-[linear-gradient(180deg,rgba(168,255,62,0.12),rgba(168,255,62,0.03))] p-6">
          <div className="text-[11px] uppercase tracking-[0.18em] text-[#86b852]">Catalog Snapshot</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#f0f0f0]">目录概览</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-[#9ab27f]">
            <p>当前页：{pagination.page} / {pagination.totalPages}</p>
            <p>目录总量：{pagination.total.toLocaleString()} 个主办方</p>
            <p>当前策略：目录先轻量定位，深入修改再进入编辑页</p>
            <p>当前目标：让 Organizer Catalog / New / Edit 成为统一后台内可直接使用的主链路</p>
          </div>
        </div>
      </section>

      <section className="rounded-[18px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <form onSubmit={handleSearchSubmit} className="grid flex-1 gap-3 md:grid-cols-[minmax(0,1.7fr)_auto_auto]">
            <label className="space-y-2">
              <span className="text-xs uppercase tracking-[0.2em] text-[#5f5f5f]">搜索关键词</span>
              <input
                value={searchInput}
                onChange={(event) => setSearchInput(event.target.value)}
                placeholder="主办方名称 / 别名 / 城市 / 国家 / 官方链接"
                className="w-full rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#151515] px-4 py-3 text-sm text-[#f0f0f0] outline-none transition-colors focus:border-[#a8ff3e]"
              />
            </label>
            <button type="submit" className="rounded-xl bg-[#a8ff3e] px-5 py-3 text-sm font-semibold text-black">
              搜索目录
            </button>
            <button
              type="button"
              onClick={handleReset}
              className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#151515] px-5 py-3 text-sm text-[#cfcfcf] hover:bg-[#202020] hover:text-white"
            >
              清空筛选
            </button>
          </form>

          <div className="rounded-[14px] border border-[rgba(255,255,255,0.07)] bg-[#151515] px-4 py-3 text-sm text-[#8a8a8a]">
            当前目录中心直接对齐 `/v1/learn/festivals`，不再依赖旧 Brand 页面做查找入口。
          </div>
        </div>
      </section>

      <section className="rounded-[18px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] p-6">
        {error ? (
          <div className="rounded-2xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-200">
            {error}
          </div>
        ) : null}

        {isLoading ? (
          <div className="py-20 text-center text-sm text-text-secondary">主办方目录加载中…</div>
        ) : items.length === 0 ? (
          <div className="py-20 text-center text-sm text-text-secondary">当前筛选条件下没有主办方。</div>
        ) : (
          <div className="space-y-4">
            {items.map((item) => {
              const visualUrl = resolvePrimaryVisual(item);
              return (
                <div key={item.id} className="grid gap-4 rounded-[18px] border border-[rgba(255,255,255,0.07)] bg-[#151515] p-4 lg:grid-cols-[140px_minmax(0,1fr)_220px]">
                  <div className="relative overflow-hidden rounded-[16px] border border-[rgba(255,255,255,0.07)] bg-[#101010]">
                    {visualUrl ? (
                      <Image
                        src={visualUrl}
                        alt={item.name}
                        width={280}
                        height={180}
                        className="h-full min-h-[110px] w-full object-cover"
                      />
                    ) : (
                      <div className="flex h-full min-h-[110px] items-center justify-center bg-[linear-gradient(135deg,rgba(209,171,84,0.18),rgba(64,147,255,0.18))] text-sm text-text-secondary">
                        暂无主视觉
                      </div>
                    )}
                  </div>

                  <div className="min-w-0">
                    <h3 className="text-xl font-semibold text-[#f0f0f0]">{item.name}</h3>
                    <p className="mt-2 text-sm leading-6 text-[#8a8a8a]">
                      {item.city || '未知城市'} / {item.country || '未知国家'}
                      {item.abbreviation ? ` · ${item.abbreviation}` : ''}
                      {typeof item.revision === 'number' ? ` · rev ${item.revision}` : ''}
                    </p>
                    {item.tagline ? (
                      <p className="mt-2 text-sm leading-6 text-[#8a8a8a]">{item.tagline}</p>
                    ) : null}
                    {item.aliases?.length ? (
                      <p className="mt-2 text-sm leading-6 text-[#8a8a8a]">
                        别名：{item.aliases.slice(0, 4).join('、')}
                      </p>
                    ) : null}
                    <p className="mt-2 text-xs text-[#666]">
                      更新时间：{formatDateTime(item.updatedAt)} · 创建时间：{formatDateTime(item.createdAt)}
                    </p>
                  </div>

                  <div className="grid gap-3">
                    <Link href={`/admin/content/organizers/${item.id}/edit`} className="rounded-xl bg-[#a8ff3e] px-4 py-3 text-center text-sm font-semibold text-black">
                      编辑主办方
                    </Link>
                    <Link href={`/admin/content/organizers/bindings?organizerId=${encodeURIComponent(item.id)}&organizerName=${encodeURIComponent(item.name)}`} className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#101010] px-4 py-3 text-center text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
                      打开绑定中心
                    </Link>
                    {item.officialWebsite ? (
                      <a
                        href={item.officialWebsite}
                        target="_blank"
                        rel="noreferrer"
                        className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#101010] px-4 py-3 text-center text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white"
                      >
                        官方链接
                      </a>
                    ) : (
                      <div className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#101010] px-4 py-3 text-center text-sm text-[#777]">
                        暂无官方链接
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}

        <div className="mt-6 flex justify-end gap-3 border-t border-white/5 pt-6">
          <button
            type="button"
            disabled={pagination.page <= 1}
            onClick={() => setPage((current) => Math.max(1, current - 1))}
            className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#151515] px-4 py-2 text-sm text-[#d0d0d0] disabled:cursor-not-allowed disabled:opacity-40"
          >
            上一页
          </button>
          <button
            type="button"
            disabled={pagination.page >= pagination.totalPages}
            onClick={() => setPage((current) => current + 1)}
            className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#151515] px-4 py-2 text-sm text-[#d0d0d0] disabled:cursor-not-allowed disabled:opacity-40"
          >
            下一页
          </button>
        </div>
      </section>
    </AdminContentLayout>
  );
}
