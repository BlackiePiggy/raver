'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import {
  adminCatalogApi,
  AdminCatalogPagination,
  EventCatalogFilters,
  EventCatalogItem,
  EventCatalogResponse,
} from '@/features/admin-content/catalog/api';
import {
  buildAdminCatalogCacheKey,
  clearAdminCatalogCache,
  readAdminCatalogCache,
  writeAdminCatalogCache,
} from '@/features/admin-content/catalog/cache';

const PAGE_SIZE = 50;
const CACHE_TTL_MS = 10 * 60 * 1000;

const EMPTY_PAGINATION: AdminCatalogPagination = {
  page: 1,
  limit: PAGE_SIZE,
  total: 0,
  totalPages: 1,
};

const formatDateRange = (item: EventCatalogItem): string => {
  const formatter = new Intl.DateTimeFormat('zh-CN', {
    month: 'short',
    day: 'numeric',
  });
  return `${formatter.format(new Date(item.startDate))} - ${formatter.format(new Date(item.endDate))}`;
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

const resolveEventTone = (status?: string | null): string => {
  switch (status) {
    case 'ongoing':
      return 'border-emerald-400/30 bg-emerald-400/10 text-emerald-100';
    case 'ended':
      return 'border-white/15 bg-black/25 text-text-secondary';
    case 'cancelled':
    case 'canceled':
      return 'border-rose-400/30 bg-rose-400/10 text-rose-100';
    default:
      return 'border-amber-300/30 bg-amber-300/10 text-amber-100';
  }
};

type CacheMeta = {
  source: 'cache' | 'network';
  fetchedAt: string;
  expiresAt: string;
  isStale: boolean;
};

export default function EventCatalogPageClient() {
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('all');
  const [page, setPage] = useState(1);
  const [items, setItems] = useState<EventCatalogItem[]>([]);
  const [pagination, setPagination] = useState<AdminCatalogPagination>(EMPTY_PAGINATION);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState('');
  const [cacheMeta, setCacheMeta] = useState<CacheMeta | null>(null);

  const filters = useMemo<EventCatalogFilters>(
    () => ({
      page,
      limit: PAGE_SIZE,
      search: search || undefined,
      status,
    }),
    [page, search, status]
  );

  const cacheKey = useMemo(
    () =>
      buildAdminCatalogCacheKey('events-catalog', {
        page,
        limit: PAGE_SIZE,
        search: search || undefined,
        status,
      }),
    [page, search, status]
  );

  const loadCatalog = useCallback(
    async (options?: { force?: boolean }) => {
      const cached = !options?.force ? readAdminCatalogCache<EventCatalogResponse>(cacheKey) : null;

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
        const response = await adminCatalogApi.fetchEvents(filters);
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
        setError(nextError instanceof Error ? nextError.message : '活动目录加载失败');
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
    setStatus('all');
    setPage(1);
  };

  return (
    <AdminContentLayout
      title="活动目录中心"
      eyebrow="Admin / Content Workspace / Event Catalog"
      description="这里展示统一后台里的活动全量目录，但默认通过分页摘要和本地 TTL 快照来查看，不会在每次打开时都重新全量扫库。你可以把它理解成一个面向管理操作的低频目录层。"
      actions={
        <>
          <Link href="/admin/content/events" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回活动工作区
          </Link>
          <button
            type="button"
            onClick={handleRefresh}
            className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue"
          >
            手动刷新目录
          </button>
          <Link href="/admin/content/events/new" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
            新建活动
          </Link>
        </>
      }
    >
      <section className="grid gap-5 xl:grid-cols-[1.4fr_0.9fr]">
        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Catalog Strategy</div>
          <h2 className="mt-2 text-2xl font-semibold">全量可管，但不是全量直打</h2>
          <div className="mt-5 grid gap-3 md:grid-cols-3">
            {[
              `单页固定 ${PAGE_SIZE} 条摘要，避免一次拉全量活动`,
              '优先读取 10 分钟本地快照，陈旧时再后台静默刷新',
              '只在进入详情或编辑时请求重数据，目录层保持轻量',
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
            <p>摘要总量：{pagination.total.toLocaleString()} 条</p>
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
                placeholder="活动名 / 城市 / 主办方"
                className="w-full rounded-xl border border-border-secondary bg-bg-tertiary/70 px-4 py-3 text-sm text-text-primary outline-none transition-colors focus:border-primary-blue"
              />
            </label>
            <label className="space-y-2">
              <span className="text-xs uppercase tracking-[0.2em] text-text-secondary">活动状态</span>
              <select
                value={status}
                onChange={(event) => {
                  setStatus(event.target.value);
                  setPage(1);
                }}
                className="w-full rounded-xl border border-border-secondary bg-bg-tertiary/70 px-4 py-3 text-sm text-text-primary outline-none transition-colors focus:border-primary-blue"
              >
                <option value="all">全部状态</option>
                <option value="upcoming">即将开始</option>
                <option value="ongoing">进行中</option>
                <option value="ended">已结束</option>
                <option value="cancelled">已取消</option>
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
            {isRefreshing ? '检测到缓存陈旧，正在后台更新当前页目录…' : '目录层默认采用 stale-while-revalidate 方式减轻请求压力。'}
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
          <div className="py-20 text-center text-sm text-text-secondary">活动目录加载中…</div>
        ) : items.length === 0 ? (
          <div className="py-20 text-center text-sm text-text-secondary">当前筛选条件下还没有活动摘要。</div>
        ) : (
          <div className="space-y-4">
            {items.map((item) => (
              <div
                key={item.id}
                className="grid gap-4 rounded-3xl border border-border-secondary bg-bg-tertiary/40 p-4 lg:grid-cols-[160px_minmax(0,1fr)_220px]"
              >
                <div className="relative overflow-hidden rounded-2xl border border-border-secondary bg-bg-secondary">
                  {item.coverImageUrl ? (
                    <Image
                      src={item.coverImageUrl}
                      alt={item.name}
                      width={320}
                      height={200}
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <div className="flex h-full min-h-[120px] items-center justify-center bg-[linear-gradient(135deg,rgba(209,171,84,0.18),rgba(64,147,255,0.18))] text-sm text-text-secondary">
                      暂无封面
                    </div>
                  )}
                </div>

                <div>
                  <div className="flex flex-wrap items-center gap-2">
                    <span className={`rounded-full border px-3 py-1 text-xs ${resolveEventTone(item.status)}`}>
                      {item.status || 'upcoming'}
                    </span>
                    <span className="rounded-full border border-border-secondary px-3 py-1 text-xs text-text-secondary">
                      {item.eventType || '未标记类型'}
                    </span>
                    {item.isVerified ? (
                      <span className="rounded-full border border-primary-blue/30 bg-primary-blue/10 px-3 py-1 text-xs text-text-primary">
                        已验证
                      </span>
                    ) : null}
                  </div>

                  <h3 className="mt-3 text-2xl font-semibold text-text-primary">{item.name}</h3>
                  <p className="mt-2 text-sm leading-6 text-text-secondary">
                    {item.wikiFestival?.name || item.organizerName || '未绑定正式主办方'} · {item.city || '未知城市'} / {item.country || '未知国家'}
                  </p>

                  <div className="mt-4 grid gap-3 md:grid-cols-3">
                    <div className="rounded-2xl border border-border-secondary bg-bg-secondary/70 px-4 py-3 text-sm">
                      <div className="text-text-secondary">活动日期</div>
                      <div className="mt-1 font-semibold">{formatDateRange(item)}</div>
                    </div>
                    <div className="rounded-2xl border border-border-secondary bg-bg-secondary/70 px-4 py-3 text-sm">
                      <div className="text-text-secondary">演出天数</div>
                      <div className="mt-1 font-semibold">{item.eventDays?.length ?? 0} 天</div>
                    </div>
                    <div className="rounded-2xl border border-border-secondary bg-bg-secondary/70 px-4 py-3 text-sm">
                      <div className="text-text-secondary">最近更新</div>
                      <div className="mt-1 font-semibold">{formatDateTime(item.updatedAt)}</div>
                    </div>
                  </div>
                </div>

                <div className="flex flex-col justify-between gap-3 rounded-2xl border border-border-secondary bg-bg-secondary/70 p-4">
                  <div className="text-sm leading-6 text-text-secondary">
                    目录层只看摘要，编辑时再进入详情页拉取完整资料，避免列表态反复命中重查询。
                  </div>
                  <div className="grid gap-3">
                    <Link href={`/admin/content/events/${item.id}/edit`} className="rounded-xl bg-primary-blue px-4 py-3 text-center text-sm font-semibold text-white">
                      编辑活动
                    </Link>
                    <Link href={`/events/${item.id}`} className="rounded-xl border border-border-secondary px-4 py-3 text-center text-sm hover:border-primary-blue hover:text-primary-blue">
                      打开活动详情
                    </Link>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        <div className="mt-6 flex flex-col gap-3 border-t border-white/5 pt-6 sm:flex-row sm:items-center sm:justify-between">
          <div className="text-sm text-text-secondary">
            共 {pagination.total.toLocaleString()} 条摘要，当前显示第 {(pagination.page - 1) * pagination.limit + 1} - {Math.min(pagination.page * pagination.limit, pagination.total)} 条
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
          <h2 className="mt-2 text-2xl font-semibold">Festival Viewer 功能迁移节奏</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>这一版先把“全量活动看板 + 编辑入口 + 低频目录层”搬进统一后台，先让日常活动管理不再依赖分散页面。</p>
            <p>下一批继续把 Event ↔ Brand 绑定、Archive 年份页和长尾补资料工具逐步拆回这个后台。</p>
          </div>
        </div>

        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Legacy Access</div>
          <h2 className="mt-2 text-2xl font-semibold">迁移期兜底</h2>
          <div className="mt-4 grid gap-3">
            <Link href="/admin/content/legacy-tools/brands" className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm hover:border-primary-blue hover:text-primary-blue">
              继续处理 Event ↔ Brand 绑定
            </Link>
            <Link href="/admin/content/legacy-tools/archive" className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm hover:border-primary-blue hover:text-primary-blue">
              查看旧 Archive 年份工具
            </Link>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
