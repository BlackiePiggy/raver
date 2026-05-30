'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import {
  adminCatalogApi,
  AdminCatalogPagination,
  DJCatalogFilters,
  DJCatalogItem,
  DJCatalogResponse,
} from '@/features/admin-content/catalog/api';
import {
  buildAdminCatalogCacheKey,
  clearAdminCatalogCache,
  readAdminCatalogCache,
  writeAdminCatalogCache,
} from '@/features/admin-content/catalog/cache';

const PAGE_SIZE = 50;
const CACHE_TTL_MS = 15 * 60 * 1000;

const EMPTY_PAGINATION: AdminCatalogPagination = {
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

const formatFollowers = (value?: number | null): string => {
  if (typeof value !== 'number' || !Number.isFinite(value)) return '未同步';
  return new Intl.NumberFormat('zh-CN').format(value);
};

type CacheMeta = {
  source: 'cache' | 'network';
  fetchedAt: string;
  expiresAt: string;
  isStale: boolean;
};

export default function DJCatalogPageClient() {
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [sortBy, setSortBy] = useState<'followerCount' | 'name' | 'createdAt'>('followerCount');
  const [page, setPage] = useState(1);
  const [items, setItems] = useState<DJCatalogItem[]>([]);
  const [pagination, setPagination] = useState<AdminCatalogPagination>(EMPTY_PAGINATION);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState('');
  const [cacheMeta, setCacheMeta] = useState<CacheMeta | null>(null);

  const filters = useMemo<DJCatalogFilters>(
    () => ({
      page,
      limit: PAGE_SIZE,
      search: search || undefined,
      sortBy,
    }),
    [page, search, sortBy]
  );

  const cacheKey = useMemo(
    () =>
      buildAdminCatalogCacheKey('djs-catalog', {
        page,
        limit: PAGE_SIZE,
        search: search || undefined,
        sortBy,
      }),
    [page, search, sortBy]
  );

  const loadCatalog = useCallback(
    async (options?: { force?: boolean }) => {
      const cached = !options?.force ? readAdminCatalogCache<DJCatalogResponse>(cacheKey) : null;

      if (cached) {
        setItems(cached.data.items);
        setPagination(cached.data.pagination);
        setCacheMeta({
          source: 'cache',
          fetchedAt: cached.fetchedAt,
          expiresAt: cached.expiresAt,
          isStale: cached.isStale,
        });
        setError('');
        setIsLoading(false);
        if (!cached.isStale) {
          return;
        }
        setIsRefreshing(true);
      } else {
        setIsLoading(true);
      }

      try {
        const response = await adminCatalogApi.fetchDJs(filters);
        const written = writeAdminCatalogCache(cacheKey, response, CACHE_TTL_MS);
        setItems(response.items);
        setPagination(response.pagination);
        setCacheMeta({
          source: response.cache?.hit ? 'cache' : 'network',
          fetchedAt: response.cache?.generatedAt || written.fetchedAt,
          expiresAt: written.expiresAt,
          isStale: Boolean(response.cache?.stale),
        });
        setError('');
      } catch (nextError) {
        setError(nextError instanceof Error ? nextError.message : 'DJ 目录加载失败');
      } finally {
        setIsLoading(false);
        setIsRefreshing(false);
      }
    },
    [cacheKey, filters]
  );

  useEffect(() => {
    void loadCatalog();
  }, [loadCatalog]);

  const handleSearchSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setPage(1);
    setSearch(searchInput.trim());
  };

  const handleRefresh = () => {
    clearAdminCatalogCache(cacheKey);
    void loadCatalog({ force: true });
  };

  const handleReset = () => {
    setSearchInput('');
    setSearch('');
    setSortBy('followerCount');
    setPage(1);
  };

  return (
    <AdminContentLayout
      title="DJ 目录中心"
      eyebrow="Admin / Content Workspace / DJ Catalog"
      description="统一查看 DJ 目录、资料摘要、编辑入口与详情入口。目录层默认读取分页摘要和本地快照，更深的资料处理按需进入编辑页。"
      actions={
        <>
          <Link href="/admin/content/djs" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            返回 DJ 工作区
          </Link>
          <button
            type="button"
            onClick={handleRefresh}
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            手动刷新目录
          </button>
          <Link href="/admin/content/djs/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            新建 DJ
          </Link>
        </>
      }
    >
      <section className="grid gap-5 xl:grid-cols-[1.4fr_0.9fr]">
        <div className="admin-reference-card p-6">
          <div className="text-[11px] uppercase tracking-[0.18em] text-black/35">Catalog Strategy</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">目录层优先轻量管理</h2>
          <div className="mt-5 grid gap-3 md:grid-cols-3">
            {[
              { title: '固定分页', body: `单页固定 ${PAGE_SIZE} 条 DJ 摘要，先解决管理视图而不是一次全拉。`, tone: 'bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)]' },
              { title: '本地快照', body: '本地快照 TTL 15 分钟，目录重开时优先命中缓存。', tone: 'bg-[linear-gradient(180deg,#f7efda_0%,#ffffff_100%)]' },
              { title: '分层处理', body: '排序、搜索和进入编辑分层处理，避免高频数据库压力。', tone: 'bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)]' },
            ].map((item) => (
              <div key={item.title} className={`admin-reference-pastel-card p-4 ${item.tone}`}>
                <div className="text-xs font-bold uppercase tracking-[0.18em] text-black/35">{item.title}</div>
                <div className="mt-5 text-sm leading-6 text-[#24312d]">{item.body}</div>
              </div>
            ))}
          </div>
        </div>

        <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-6">
          <div className="text-[11px] uppercase tracking-[0.18em] text-black/35">Snapshot Meta</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">目录快照状态</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-black/55">
            <p>当前页：{pagination.page} / {pagination.totalPages}</p>
            <p>摘要总量：{pagination.total.toLocaleString()} 位 DJ</p>
            <p>最新快照：{cacheMeta ? formatDateTime(cacheMeta.fetchedAt) : '尚未生成'}</p>
            <p>刷新方式：{cacheMeta?.source === 'cache' ? '缓存命中' : '后台摘要刷新'}</p>
            <p>快照状态：{cacheMeta?.isStale ? '已陈旧，后台会自动补刷新' : '新鲜可用'}</p>
          </div>
        </div>
      </section>

      <section className="admin-reference-card p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <form onSubmit={handleSearchSubmit} className="grid flex-1 gap-3 md:grid-cols-[minmax(0,1.6fr)_220px_auto_auto]">
            <label className="space-y-2">
              <span className="text-xs uppercase tracking-[0.2em] text-black/35">搜索关键词</span>
              <input
                value={searchInput}
                onChange={(event) => setSearchInput(event.target.value)}
                placeholder="DJ 名称 / 别名 / 国家"
                className="w-full rounded-full px-4 py-3 text-sm"
              />
            </label>
            <label className="space-y-2">
              <span className="text-xs uppercase tracking-[0.2em] text-black/35">排序方式</span>
              <select
                value={sortBy}
                onChange={(event) => {
                  setSortBy(event.target.value as 'followerCount' | 'name' | 'createdAt');
                  setPage(1);
                }}
                className="w-full rounded-full px-4 py-3 text-sm"
              >
                <option value="followerCount">按粉丝量</option>
                <option value="name">按名称</option>
                <option value="createdAt">按创建时间</option>
              </select>
            </label>
            <button type="submit" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
              搜索目录
            </button>
            <button
              type="button"
              onClick={handleReset}
              className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
            >
              清空筛选
            </button>
          </form>

          <div className="admin-reference-soft-card px-4 py-3 text-sm text-black/50">
            {isRefreshing ? '检测到缓存陈旧，正在后台更新当前页 DJ 摘要…' : '目录层采用低频快照 + 手动刷新，更适合全量管理场景。'}
          </div>
        </div>
      </section>

      <section className="admin-reference-card p-6">
        {error ? (
          <div className="rounded-[18px] border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-[#7a2d29]">
            {error}
          </div>
        ) : null}

        {isLoading ? (
          <div className="py-20 text-center text-sm text-text-secondary">DJ 目录加载中…</div>
        ) : items.length === 0 ? (
          <div className="py-20 text-center text-sm text-text-secondary">当前筛选条件下还没有 DJ 摘要。</div>
        ) : (
          <div className="space-y-4">
            {items.map((item) => (
              <div
                key={item.id}
                className="grid gap-4 rounded-[28px] border border-[#e8eceb] bg-[#fcfcfb] p-5 lg:grid-cols-[minmax(0,1fr)_240px]"
              >
                <div className="flex flex-col gap-4 md:flex-row">
                  <div className="flex h-24 w-24 shrink-0 items-center justify-center overflow-hidden rounded-[22px] border border-[#e8eceb] bg-[linear-gradient(135deg,#edf7f2,#f7efda)]">
                    {item.avatarUrl ? (
                      <Image
                        src={item.avatarUrl}
                        alt={item.name}
                        width={96}
                        height={96}
                        className="h-full w-full object-cover"
                      />
                    ) : (
                      <span className="text-sm text-black/45">暂无头像</span>
                    )}
                  </div>

                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      {item.isVerified ? (
                        <span className="rounded-full border border-[#dceabf] bg-[#eef8d8] px-3 py-1 text-xs font-semibold text-[#2f4027]">
                          已验证
                        </span>
                      ) : (
                        <span className="admin-reference-chip">
                          未验证
                        </span>
                      )}
                      <span className="admin-reference-chip">
                        {item.country || '未知国家'}
                      </span>
                    </div>

                    <h3 className="mt-3 truncate text-2xl font-semibold text-[#071110]">{item.name}</h3>
                    <p className="mt-2 line-clamp-2 text-sm leading-6 text-black/52">
                      {item.bio || '当前目录层只展示轻量资料摘要，更重的 proof、外部平台抓取和资料对齐会在后续详情层处理。'}
                    </p>

                    <div className="mt-4 grid gap-3 md:grid-cols-3">
                      <div className="admin-reference-soft-card px-4 py-3 text-sm">
                        <div className="text-black/42">平台粉丝</div>
                        <div className="mt-1 font-semibold text-[#071110]">{formatFollowers(item.followerCount)}</div>
                      </div>
                      <div className="admin-reference-soft-card px-4 py-3 text-sm">
                        <div className="text-black/42">最近同步</div>
                        <div className="mt-1 font-semibold text-[#071110]">{formatDateTime(item.lastSyncedAt)}</div>
                      </div>
                      <div className="admin-reference-soft-card px-4 py-3 text-sm">
                        <div className="text-black/42">最近更新</div>
                        <div className="mt-1 font-semibold text-[#071110]">{formatDateTime(item.updatedAt)}</div>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="admin-reference-dark-card flex flex-col justify-between gap-3 p-4">
                  <div className="text-sm leading-6 text-white/65">
                    目录中心先承担“看全量、做筛选、快速定位”的角色，深入资料处理再进入编辑页继续完成。
                  </div>
                  <div className="grid gap-3">
                    <Link href={`/admin/content/djs/${item.id}/edit`} className="rounded-full bg-white px-4 py-3 text-center text-sm font-semibold text-[#071110]">
                      编辑 DJ
                    </Link>
                    <Link href={`/djs/${item.id}`} className="rounded-full border border-white/10 bg-white/8 px-4 py-3 text-center text-sm text-white">
                      打开 DJ 详情
                    </Link>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        <div className="mt-6 flex flex-col gap-3 border-t border-white/5 pt-6 sm:flex-row sm:items-center sm:justify-between">
          <div className="text-sm text-black/48">
            共 {pagination.total.toLocaleString()} 位 DJ，当前显示第 {(pagination.page - 1) * pagination.limit + 1} - {Math.min(pagination.page * pagination.limit, pagination.total)} 位
          </div>
          <div className="flex gap-3">
            <button
              type="button"
              disabled={pagination.page <= 1}
              onClick={() => setPage((current) => Math.max(1, current - 1))}
              className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
            >
              上一页
            </button>
            <button
              type="button"
              disabled={pagination.page >= pagination.totalPages}
              onClick={() => setPage((current) => Math.min(pagination.totalPages, current + 1))}
              className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
            >
              下一页
            </button>
          </div>
        </div>
      </section>

      <section className="admin-reference-card p-6">
        <div className="grid gap-3 lg:grid-cols-3">
          {[
            { title: '全量查看', body: 'DJ 目录优先承担全量查看、筛选和快速进入编辑的工作。', tone: 'bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)]' },
            { title: '资料处理', body: '更重的外部源对齐、proof 生命周期和精细资料处理继续在编辑流里推进。', tone: 'bg-[linear-gradient(180deg,#f7efda_0%,#ffffff_100%)]' },
            { title: '治理入口', body: '绑定审核和其他治理能力继续通过统一后台分区进入。', tone: 'bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)]' },
          ].map((item) => (
            <div key={item.title} className={`admin-reference-pastel-card p-4 ${item.tone}`}>
              <div className="text-xs font-bold uppercase tracking-[0.18em] text-black/35">{item.title}</div>
              <div className="mt-4 text-sm leading-6 text-[#24312d]">{item.body}</div>
            </div>
          ))}
        </div>
      </section>
    </AdminContentLayout>
  );
}
