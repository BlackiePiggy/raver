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
      description="这里承接统一后台里的 DJ 全量管理视图，但列表层默认只读取分页摘要和本地快照，避免每次都去打全量数据。更重的资料编辑、外部源对齐和 proof 处理会按需进入详情或旧工具。"
      actions={
        <>
          <Link href="/admin/content/djs" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回 DJ 工作区
          </Link>
          <button
            type="button"
            onClick={handleRefresh}
            className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue"
          >
            手动刷新目录
          </button>
          <Link href="/admin/content/djs/new" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
            新建 DJ
          </Link>
        </>
      }
    >
      <section className="grid gap-5 xl:grid-cols-[1.4fr_0.9fr]">
        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Catalog Strategy</div>
          <h2 className="mt-2 text-2xl font-semibold">目录页优先看快照，不优先打源</h2>
          <div className="mt-5 grid gap-3 md:grid-cols-3">
            {[
              `单页固定 ${PAGE_SIZE} 条 DJ 摘要，先解决管理视图而不是一次全拉`,
              '本地快照 TTL 15 分钟，目录重开时优先命中缓存',
              '排序、搜索和进入编辑分层处理，避免高频数据库压力',
            ].map((item) => (
              <div key={item} className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm leading-6">
                {item}
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-border-secondary bg-[linear-gradient(180deg,rgba(255,255,255,0.05),rgba(255,255,255,0.02)),radial-gradient(circle_at_top_left,rgba(209,171,84,0.16),transparent_35%),radial-gradient(circle_at_bottom_right,rgba(64,147,255,0.14),transparent_45%)] p-6">
          <div className="text-sm text-text-secondary">Snapshot Meta</div>
          <h2 className="mt-2 text-2xl font-semibold">目录快照状态</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>当前页：{pagination.page} / {pagination.totalPages}</p>
            <p>摘要总量：{pagination.total.toLocaleString()} 位 DJ</p>
            <p>最新快照：{cacheMeta ? formatDateTime(cacheMeta.fetchedAt) : '尚未生成'}</p>
            <p>刷新方式：{cacheMeta?.source === 'cache' ? '缓存命中' : '后台摘要刷新'}</p>
            <p>快照状态：{cacheMeta?.isStale ? '已陈旧，后台会自动补刷新' : '新鲜可用'}</p>
          </div>
        </div>
      </section>

      <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <form onSubmit={handleSearchSubmit} className="grid flex-1 gap-3 md:grid-cols-[minmax(0,1.6fr)_220px_auto_auto]">
            <label className="space-y-2">
              <span className="text-xs uppercase tracking-[0.2em] text-text-secondary">搜索关键词</span>
              <input
                value={searchInput}
                onChange={(event) => setSearchInput(event.target.value)}
                placeholder="DJ 名称 / 别名 / 国家"
                className="w-full rounded-xl border border-border-secondary bg-bg-tertiary/70 px-4 py-3 text-sm text-text-primary outline-none transition-colors focus:border-primary-blue"
              />
            </label>
            <label className="space-y-2">
              <span className="text-xs uppercase tracking-[0.2em] text-text-secondary">排序方式</span>
              <select
                value={sortBy}
                onChange={(event) => {
                  setSortBy(event.target.value as 'followerCount' | 'name' | 'createdAt');
                  setPage(1);
                }}
                className="w-full rounded-xl border border-border-secondary bg-bg-tertiary/70 px-4 py-3 text-sm text-text-primary outline-none transition-colors focus:border-primary-blue"
              >
                <option value="followerCount">按粉丝量</option>
                <option value="name">按名称</option>
                <option value="createdAt">按创建时间</option>
              </select>
            </label>
            <button type="submit" className="rounded-xl bg-primary-blue px-5 py-3 text-sm font-semibold text-white">
              搜索目录
            </button>
            <button
              type="button"
              onClick={handleReset}
              className="rounded-xl border border-border-secondary px-5 py-3 text-sm hover:border-primary-blue hover:text-primary-blue"
            >
              清空筛选
            </button>
          </form>

          <div className="rounded-2xl border border-border-secondary bg-bg-tertiary/50 px-4 py-3 text-sm text-text-secondary">
            {isRefreshing ? '检测到缓存陈旧，正在后台更新当前页 DJ 摘要…' : '目录层采用低频快照 + 手动刷新，更适合全量管理场景。'}
          </div>
        </div>
      </section>

      <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
        {error ? (
          <div className="rounded-2xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-200">
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
                className="grid gap-4 rounded-3xl border border-border-secondary bg-bg-tertiary/40 p-4 lg:grid-cols-[minmax(0,1fr)_240px]"
              >
                <div className="flex flex-col gap-4 md:flex-row">
                  <div className="flex h-24 w-24 shrink-0 items-center justify-center overflow-hidden rounded-2xl border border-border-secondary bg-[linear-gradient(135deg,rgba(209,171,84,0.18),rgba(64,147,255,0.18))]">
                    {item.avatarUrl ? (
                      <Image
                        src={item.avatarUrl}
                        alt={item.name}
                        width={96}
                        height={96}
                        className="h-full w-full object-cover"
                      />
                    ) : (
                      <span className="text-sm text-text-secondary">暂无头像</span>
                    )}
                  </div>

                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      {item.isVerified ? (
                        <span className="rounded-full border border-primary-blue/30 bg-primary-blue/10 px-3 py-1 text-xs text-text-primary">
                          已验证
                        </span>
                      ) : (
                        <span className="rounded-full border border-border-secondary px-3 py-1 text-xs text-text-secondary">
                          未验证
                        </span>
                      )}
                      <span className="rounded-full border border-border-secondary px-3 py-1 text-xs text-text-secondary">
                        {item.country || '未知国家'}
                      </span>
                    </div>

                    <h3 className="mt-3 truncate text-2xl font-semibold text-text-primary">{item.name}</h3>
                    <p className="mt-2 line-clamp-2 text-sm leading-6 text-text-secondary">
                      {item.bio || '当前目录层只展示轻量资料摘要，更重的 proof、外部平台抓取和资料对齐会在后续详情层处理。'}
                    </p>

                    <div className="mt-4 grid gap-3 md:grid-cols-3">
                      <div className="rounded-2xl border border-border-secondary bg-bg-secondary/70 px-4 py-3 text-sm">
                        <div className="text-text-secondary">平台粉丝</div>
                        <div className="mt-1 font-semibold">{formatFollowers(item.followerCount)}</div>
                      </div>
                      <div className="rounded-2xl border border-border-secondary bg-bg-secondary/70 px-4 py-3 text-sm">
                        <div className="text-text-secondary">最近同步</div>
                        <div className="mt-1 font-semibold">{formatDateTime(item.lastSyncedAt)}</div>
                      </div>
                      <div className="rounded-2xl border border-border-secondary bg-bg-secondary/70 px-4 py-3 text-sm">
                        <div className="text-text-secondary">最近更新</div>
                        <div className="mt-1 font-semibold">{formatDateTime(item.updatedAt)}</div>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="flex flex-col justify-between gap-3 rounded-2xl border border-border-secondary bg-bg-secondary/70 p-4">
                  <div className="text-sm leading-6 text-text-secondary">
                    目录中心先承担“看全量、做筛选、快速定位”的角色。DJ 的精细编辑能力迁移完成前，仍可按需回退旧工具。
                  </div>
                  <div className="grid gap-3">
                    <Link href={`/admin/content/djs/${item.id}/edit`} className="rounded-xl bg-primary-blue px-4 py-3 text-center text-sm font-semibold text-white">
                      编辑 DJ
                    </Link>
                    <Link href="/admin/content/legacy-tools/djs" className="rounded-xl border border-border-secondary px-4 py-3 text-center text-sm hover:border-primary-blue hover:text-primary-blue">
                      进入 DJ 迁移工具
                    </Link>
                    <Link href={`/djs/${item.id}`} className="rounded-xl border border-border-secondary px-4 py-3 text-center text-sm hover:border-primary-blue hover:text-primary-blue">
                      打开 DJ 详情
                    </Link>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        <div className="mt-6 flex flex-col gap-3 border-t border-white/5 pt-6 sm:flex-row sm:items-center sm:justify-between">
          <div className="text-sm text-text-secondary">
            共 {pagination.total.toLocaleString()} 位 DJ，当前显示第 {(pagination.page - 1) * pagination.limit + 1} - {Math.min(pagination.page * pagination.limit, pagination.total)} 位
          </div>
          <div className="flex gap-3">
            <button
              type="button"
              disabled={pagination.page <= 1}
              onClick={() => setPage((current) => Math.max(1, current - 1))}
              className="rounded-xl border border-border-secondary px-4 py-2 text-sm disabled:cursor-not-allowed disabled:opacity-40"
            >
              上一页
            </button>
            <button
              type="button"
              disabled={pagination.page >= pagination.totalPages}
              onClick={() => setPage((current) => Math.min(pagination.totalPages, current + 1))}
              className="rounded-xl border border-border-secondary px-4 py-2 text-sm disabled:cursor-not-allowed disabled:opacity-40"
            >
              下一页
            </button>
          </div>
        </div>
      </section>

      <section className="grid gap-5 lg:grid-cols-2">
        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Migration Bridge</div>
          <h2 className="mt-2 text-2xl font-semibold">旧 DJ 工具的迁移边界</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>这一版先把 DJ 全量浏览、筛选与管理定位搬进统一后台，先解决“在同一处看到全量、低压力管理”的问题。</p>
            <p>后续继续把 proof 生命周期、平台源对齐、旧 Facebook/外部源辅助字段和精细编辑面板逐步拆回这里。</p>
          </div>
        </div>

        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Legacy Access</div>
          <h2 className="mt-2 text-2xl font-semibold">迁移期兜底</h2>
          <div className="mt-4 grid gap-3">
            <Link href="/admin/content/legacy-tools/djs" className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm hover:border-primary-blue hover:text-primary-blue">
              打开旧 DJ 工具桥接页
            </Link>
            <Link href="/admin/content/reviews/dj-bindings" className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm hover:border-primary-blue hover:text-primary-blue">
              进入 DJ 绑定审核台
            </Link>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
