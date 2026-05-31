'use client';

import { getCountryCode, getEmojiFlag } from 'countries-list';
import Image from 'next/image';
import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ChevronLeft,
  ChevronRight,
  Copy,
  Download,
  Ellipsis,
  Filter,
  Plus,
  RefreshCw,
  Search,
  Upload,
} from 'lucide-react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import {
  adminCatalogApi,
  AdminCatalogPagination,
  DJCatalogFilters,
  DJCatalogItem,
  DJCatalogResponse,
  DJCatalogSummary,
} from '@/features/admin-content/catalog/api';
import {
  buildAdminCatalogCacheKey,
  clearAdminCatalogCache,
  readAdminCatalogCache,
  writeAdminCatalogCache,
} from '@/features/admin-content/catalog/cache';

const PAGE_SIZE = 20;
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

const formatPercentage = (value: number, total: number): string => {
  if (!total) return '0%';
  return `${((value / total) * 100).toFixed(1)}%`;
};

const isDJIncomplete = (item: DJCatalogItem): boolean =>
  !item.avatarUrl || !item.bio || !item.country || !Array.isArray(item.genres) || item.genres.length === 0;

const resolveDJState = (item: DJCatalogItem): {
  label: string;
  tone: string;
} => {
  if (isDJIncomplete(item)) {
    return {
      label: '资料待完善',
      tone: 'border-[#dbe7ff] bg-[#eef4ff] text-[#4267c7]',
    };
  }
  if (item.isVerified) {
    return {
      label: '已验证',
      tone: 'border-[#dceabf] bg-[#eef8d8] text-[#2f8b4f]',
    };
  }
  return {
    label: '未验证',
    tone: 'border-[#f0dfaf] bg-[#fff4d8] text-[#b57a12]',
  };
};

const resolveCountryFlag = (country?: string | null): string | null => {
  if (!country) return null;
  const code = getCountryCode(country);
  if (!code) return null;
  return getEmojiFlag(code);
};

const resolveTagPills = (item: DJCatalogItem): string[] => {
  const tags = [
    ...(Array.isArray(item.genres) ? item.genres : []),
    ...(Array.isArray(item.aliases) ? item.aliases : []),
  ]
    .map((entry) => entry.trim())
    .filter(Boolean);

  return Array.from(new Set(tags)).slice(0, 2);
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
  const [country, setCountry] = useState('all');
  const [verificationStatus, setVerificationStatus] = useState<
    'all' | 'verified' | 'unverified' | 'incomplete'
  >('all');
  const [sortBy, setSortBy] = useState<'followerCount' | 'name' | 'createdAt'>('followerCount');
  const [page, setPage] = useState(1);
  const [items, setItems] = useState<DJCatalogItem[]>([]);
  const [pagination, setPagination] = useState<AdminCatalogPagination>(EMPTY_PAGINATION);
  const [summary, setSummary] = useState<DJCatalogSummary | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState('');
  const [cacheMeta, setCacheMeta] = useState<CacheMeta | null>(null);
  const [copyNotice, setCopyNotice] = useState('');

  const filters = useMemo<DJCatalogFilters>(
    () => ({
      page,
      limit: PAGE_SIZE,
      search: search || undefined,
      country: country === 'all' ? undefined : country,
      verificationStatus,
      sortBy,
    }),
    [country, page, search, sortBy, verificationStatus]
  );

  const cacheKey = useMemo(
    () =>
      buildAdminCatalogCacheKey('djs-catalog', {
        page,
        limit: PAGE_SIZE,
        search: search || undefined,
        country: country === 'all' ? undefined : country,
        verificationStatus,
        sortBy,
      }),
    [country, page, search, sortBy, verificationStatus]
  );

  const loadCatalog = useCallback(
    async (options?: { force?: boolean }) => {
      const cached = !options?.force ? readAdminCatalogCache<DJCatalogResponse>(cacheKey) : null;

      if (cached) {
        setItems(cached.data.items);
        setPagination(cached.data.pagination);
        setSummary(cached.data.summary ?? null);
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
        setSummary(response.summary ?? null);
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
    setCountry('all');
    setVerificationStatus('all');
    setSortBy('followerCount');
    setPage(1);
  };

  const handleExport = () => {
    if (typeof window === 'undefined' || !items.length) return;

    const header = [
      'DJ 名称',
      '国家/地区',
      '状态',
      '平台粉丝',
      '最近同步',
      '最近更新',
      '详情链接',
      '编辑链接',
    ];

    const rows = items.map((item) => {
      const state = resolveDJState(item).label;
      return [
        item.name,
        item.country || '',
        state,
        String(item.followerCount ?? ''),
        formatDateTime(item.lastSyncedAt),
        formatDateTime(item.updatedAt),
        `${window.location.origin}/djs/${item.id}`,
        `${window.location.origin}/admin/content/djs/${item.id}/edit`,
      ];
    });

    const csv = [header, ...rows]
      .map((row) => row.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(','))
      .join('\n');

    const blob = new Blob([`\ufeff${csv}`], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `dj-catalog-page-${pagination.page}.csv`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
  };

  const handleCopyId = async (id: string) => {
    if (typeof window === 'undefined' || !navigator.clipboard?.writeText) return;
    await navigator.clipboard.writeText(id);
    setCopyNotice(`已复制 DJ ID：${id}`);
    window.setTimeout(() => {
      setCopyNotice((current) => (current === `已复制 DJ ID：${id}` ? '' : current));
    }, 2400);
  };

  const computedSummary = useMemo<DJCatalogSummary>(() => {
    if (summary) return summary;
    const nextSummary = {
      total: items.length,
      verified: 0,
      unverified: 0,
      incomplete: 0,
    };

    items.forEach((item) => {
      if (isDJIncomplete(item)) {
        nextSummary.incomplete += 1;
      } else if (item.isVerified) {
        nextSummary.verified += 1;
      } else {
        nextSummary.unverified += 1;
      }
    });

    nextSummary.total = nextSummary.verified + nextSummary.unverified + nextSummary.incomplete;
    return nextSummary;
  }, [items, summary]);

  const countryOptions = useMemo(() => {
    const options = Array.from(new Set(items.map((item) => item.country).filter(Boolean))) as string[];
    if (country !== 'all' && country && !options.includes(country)) {
      options.push(country);
    }
    return options.sort((left, right) => left.localeCompare(right, 'en'));
  }, [country, items]);

  const visiblePages = useMemo(() => {
    const totalPages = Math.max(1, pagination.totalPages);
    const start = Math.max(1, Math.min(totalPages - 4, pagination.page - 2));
    const end = Math.min(totalPages, start + 4);
    return Array.from({ length: end - start + 1 }, (_, index) => start + index);
  }, [pagination.page, pagination.totalPages]);

  const cacheSummary = useMemo(() => {
    if (!cacheMeta) return '首次加载';
    if (cacheMeta.isStale) return '缓存更新中';
    return cacheMeta.source === 'cache' ? '缓存命中' : '实时刷新';
  }, [cacheMeta]);

  return (
    <AdminContentLayout
      title="DJ 管理"
      eyebrow="内容控制台 / DJ 工作区"
      description="管理平台 DJ 资料、认证状态与内容。可筛选、编辑资料或查看 DJ 详情。"
      actions={
        <>
          <Link
            href="/admin/content/djs/new"
            className="inline-flex items-center gap-2 rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            <Upload className="h-4 w-4" />
            <span>导入 DJ</span>
          </Link>
          <Link
            href="/admin/content/djs/new"
            className="inline-flex items-center gap-2 rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
          >
            <Plus className="h-4 w-4" />
            <span>新增 DJ</span>
          </Link>
        </>
      }
    >
      <section className="space-y-5">
        <section className="admin-reference-card p-5 lg:p-6">
          <div className="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
            <form
              onSubmit={handleSearchSubmit}
              className="grid flex-1 gap-3 md:grid-cols-2 xl:grid-cols-[minmax(240px,1.45fr)_190px_190px_auto_auto]"
            >
              <label className="flex items-center gap-3 rounded-full border border-[#e8eceb] bg-white px-5 py-3">
                <Search className="h-5 w-5 text-black/35" />
                <input
                  value={searchInput}
                  onChange={(event) => setSearchInput(event.target.value)}
                  placeholder="搜索 DJ 名称、国家、标签..."
                  className="w-full border-0 bg-transparent px-0 py-0 text-sm shadow-none outline-none"
                />
              </label>

              <label className="flex items-center rounded-full border border-[#e8eceb] bg-white px-4 py-3">
                <select
                  value={verificationStatus}
                  onChange={(event) => {
                    setVerificationStatus(
                      event.target.value as 'all' | 'verified' | 'unverified' | 'incomplete'
                    );
                    setPage(1);
                  }}
                  className="w-full border-0 bg-transparent px-0 py-0 text-sm font-semibold text-[#071110] shadow-none outline-none"
                >
                  <option value="all">全部认证状态</option>
                  <option value="verified">已验证</option>
                  <option value="unverified">未验证</option>
                  <option value="incomplete">资料待完善</option>
                </select>
              </label>

              <label className="flex items-center rounded-full border border-[#e8eceb] bg-white px-4 py-3">
                <select
                  value={country}
                  onChange={(event) => {
                    setCountry(event.target.value);
                    setPage(1);
                  }}
                  className="w-full border-0 bg-transparent px-0 py-0 text-sm font-semibold text-[#071110] shadow-none outline-none"
                >
                  <option value="all">全部国家/地区</option>
                  {countryOptions.map((item) => (
                    <option key={item} value={item}>
                      {item}
                    </option>
                  ))}
                </select>
              </label>

              <details className="relative">
                <summary className="flex cursor-pointer list-none items-center justify-center gap-2 rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
                  <Filter className="h-4 w-4" />
                  <span>更多筛选</span>
                </summary>

                <div className="absolute right-0 top-[calc(100%+12px)] z-20 min-w-[240px] rounded-[24px] border border-[#e8eceb] bg-white p-4 shadow-[0_18px_42px_rgba(33,52,47,0.1)]">
                  <label className="block">
                    <div className="mb-2 text-xs font-semibold uppercase tracking-[0.14em] text-black/35">
                      排序方式
                    </div>
                    <select
                      value={sortBy}
                      onChange={(event) => {
                        setSortBy(event.target.value as 'followerCount' | 'name' | 'createdAt');
                        setPage(1);
                      }}
                      className="w-full rounded-full border border-[#e8eceb] bg-[#f8f9f8] px-4 py-3 text-sm font-semibold text-[#071110] outline-none"
                    >
                      <option value="followerCount">按平台粉丝</option>
                      <option value="name">按名称</option>
                      <option value="createdAt">按创建时间</option>
                    </select>
                  </label>
                </div>
              </details>

              <button type="submit" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
                搜索
              </button>
            </form>

            <div className="flex flex-wrap items-center gap-3">
              <button
                type="button"
                onClick={handleRefresh}
                className="inline-flex items-center justify-center rounded-full border border-[#e8eceb] bg-white px-4 py-3 text-[#071110]"
                aria-label="刷新目录"
              >
                <RefreshCw className="h-5 w-5" />
              </button>
              <button
                type="button"
                onClick={handleExport}
                className="inline-flex items-center gap-2 rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
              >
                <Download className="h-4 w-4" />
                <span>导出</span>
              </button>
              <button
                type="button"
                onClick={handleReset}
                className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
              >
                重置
              </button>
            </div>
          </div>

          <div className="mt-4 flex flex-wrap items-center gap-3 text-sm text-black/46">
            <span className="rounded-full bg-[#eff4f2] px-4 py-2 font-semibold uppercase tracking-[0.14em] text-black/42">
              DJ Catalog
            </span>
            <span className="rounded-full border border-[#e8eceb] bg-white px-4 py-2">
              {cacheSummary}
            </span>
            {cacheMeta?.fetchedAt ? (
              <span className="rounded-full border border-[#e8eceb] bg-white px-4 py-2">
                更新于 {formatDateTime(cacheMeta.fetchedAt)}
              </span>
            ) : null}
            {isRefreshing ? <span>目录刷新中…</span> : null}
            {copyNotice ? <span className="text-[#2f8b4f]">{copyNotice}</span> : null}
          </div>

          <div className="mt-5 grid gap-4 lg:grid-cols-4">
            <div className="admin-studio-pastel-mint px-5 py-5">
              <div className="text-[15px] font-semibold text-[#071110]">全部 DJ</div>
              <div className="mt-3 text-[42px] font-semibold leading-none tracking-[-0.05em] text-[#071110]">
                {computedSummary.total.toLocaleString()}
              </div>
              <div className="mt-4 text-sm text-black/46">第 {pagination.page} / {pagination.totalPages} 页</div>
            </div>

            <div className="admin-reference-soft-card px-5 py-5">
              <div className="text-[15px] font-semibold text-[#071110]">已验证</div>
              <div className="mt-3 flex items-end justify-between gap-3">
                <div className="text-[42px] font-semibold leading-none tracking-[-0.05em] text-[#071110]">
                  {computedSummary.verified.toLocaleString()}
                </div>
                <div className="pb-1 text-[28px] font-medium text-black/42">
                  {formatPercentage(computedSummary.verified, computedSummary.total)}
                </div>
              </div>
            </div>

            <div className="admin-reference-soft-card px-5 py-5">
              <div className="text-[15px] font-semibold text-[#071110]">未验证</div>
              <div className="mt-3 flex items-end justify-between gap-3">
                <div className="text-[42px] font-semibold leading-none tracking-[-0.05em] text-[#071110]">
                  {computedSummary.unverified.toLocaleString()}
                </div>
                <div className="pb-1 text-[28px] font-medium text-black/42">
                  {formatPercentage(computedSummary.unverified, computedSummary.total)}
                </div>
              </div>
            </div>

            <div className="admin-reference-soft-card px-5 py-5">
              <div className="text-[15px] font-semibold text-[#071110]">资料待完善</div>
              <div className="mt-3 flex items-end justify-between gap-3">
                <div className="text-[42px] font-semibold leading-none tracking-[-0.05em] text-[#071110]">
                  {computedSummary.incomplete.toLocaleString()}
                </div>
                <div className="pb-1 text-[28px] font-medium text-black/42">
                  {formatPercentage(computedSummary.incomplete, computedSummary.total)}
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="admin-reference-card overflow-hidden">
          {error ? (
            <div className="border-b border-red-500/15 bg-red-500/10 px-6 py-4 text-sm text-[#7a2d29]">
              {error}
            </div>
          ) : null}

          <div className="hidden lg:grid lg:grid-cols-[minmax(0,2.1fr)_1.2fr_1fr_1fr_1.15fr_1.15fr_170px] lg:gap-6 lg:px-6 lg:py-5">
            {['DJ 信息', '国家/地区', '认证状态', '平台粉丝', '最近同步', '最近更新', '操作'].map((label) => (
              <div key={label} className="text-[15px] font-semibold text-black/52">
                {label}
              </div>
            ))}
          </div>

          {isLoading ? (
            <div className="border-t border-[#edf0ee] px-6 py-20 text-center text-sm text-black/48">
              DJ 目录加载中…
            </div>
          ) : items.length === 0 ? (
            <div className="border-t border-[#edf0ee] px-6 py-20 text-center text-sm text-black/48">
              当前筛选条件下还没有 DJ。
            </div>
          ) : (
            <div className="border-t border-[#edf0ee]">
              {items.map((item) => {
                const state = resolveDJState(item);
                const tags = resolveTagPills(item);
                const countryFlag = resolveCountryFlag(item.country);
                return (
                  <article
                    key={item.id}
                    className="border-b border-[#edf0ee] px-5 py-5 last:border-b-0 lg:grid lg:grid-cols-[minmax(0,2.1fr)_1.2fr_1fr_1fr_1.15fr_1.15fr_170px] lg:gap-6 lg:px-6"
                  >
                    <div className="min-w-0">
                      <div className="flex items-start gap-4">
                        <div className="flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-[18px] border border-[#e8eceb] bg-[#f3f5f4]">
                          {item.avatarUrl ? (
                            <Image
                              src={item.avatarUrl}
                              alt={item.name}
                              width={64}
                              height={64}
                              className="h-full w-full object-cover"
                            />
                          ) : (
                            <span className="text-xs text-black/42">暂无头像</span>
                          )}
                        </div>

                        <div className="min-w-0 flex-1">
                          <div className="truncate text-[18px] font-semibold tracking-[-0.02em] text-[#071110]">
                            {item.name}
                          </div>
                          <div className="mt-3 flex flex-wrap gap-2">
                            {tags.length ? (
                              tags.map((tag) => (
                                <span
                                  key={tag}
                                  className="rounded-full bg-[#f2f4f3] px-3 py-1 text-xs font-semibold text-black/55"
                                >
                                  {tag}
                                </span>
                              ))
                            ) : (
                              <span className="rounded-full bg-[#f2f4f3] px-3 py-1 text-xs font-semibold text-black/42">
                                资料标签待补充
                              </span>
                            )}
                            {(Array.isArray(item.genres) ? item.genres.length : 0) > 2 ||
                            (Array.isArray(item.aliases) ? item.aliases.length : 0) > 2 ? (
                              <span className="rounded-full bg-[#f2f4f3] px-3 py-1 text-xs font-semibold text-black/42">
                                ...
                              </span>
                            ) : null}
                          </div>
                        </div>
                      </div>
                    </div>

                    <div className="mt-4 flex items-center gap-3 text-[17px] font-medium text-[#071110] lg:mt-0">
                      {countryFlag ? (
                        <span className="text-[28px] leading-none" aria-hidden="true">
                          {countryFlag}
                        </span>
                      ) : null}
                      <span>{item.country || '待补充'}</span>
                    </div>

                    <div className="mt-4 lg:mt-0">
                      <span className={`inline-flex rounded-full border px-4 py-2 text-sm font-semibold ${state.tone}`}>
                        {state.label}
                      </span>
                    </div>

                    <div className="mt-4 text-[17px] font-medium text-[#071110] lg:mt-0">
                      {formatFollowers(item.followerCount ?? item.soundCloudFollowers)}
                    </div>

                    <div className="mt-4 text-[17px] font-medium text-[#071110] lg:mt-0">
                      {formatDateTime(item.lastSyncedAt)}
                    </div>

                    <div className="mt-4 text-[17px] font-medium text-[#071110] lg:mt-0">
                      {formatDateTime(item.updatedAt)}
                    </div>

                    <div className="mt-4 flex items-center gap-3 lg:mt-0 lg:justify-end">
                      <Link
                        href={`/admin/content/djs/${item.id}/edit`}
                        className="inline-flex rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
                      >
                        编辑
                      </Link>

                      <details className="relative">
                        <summary className="flex h-12 w-12 cursor-pointer list-none items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#071110]">
                          <Ellipsis className="h-5 w-5" />
                        </summary>

                        <div className="absolute right-0 top-[calc(100%+10px)] z-20 grid min-w-[180px] gap-2 rounded-[20px] border border-[#e8eceb] bg-white p-3 shadow-[0_18px_42px_rgba(33,52,47,0.12)]">
                          <Link
                            href={`/djs/${item.id}`}
                            className="rounded-full bg-[#f8f9f8] px-4 py-2 text-left text-sm font-semibold text-[#071110]"
                          >
                            查看详情
                          </Link>
                          <button
                            type="button"
                            onClick={() => void handleCopyId(item.id)}
                            className="inline-flex items-center gap-2 rounded-full bg-[#f8f9f8] px-4 py-2 text-left text-sm font-semibold text-[#071110]"
                          >
                            <Copy className="h-4 w-4" />
                            <span>复制 ID</span>
                          </button>
                        </div>
                      </details>
                    </div>
                  </article>
                );
              })}
            </div>
          )}

          <div className="flex flex-col gap-4 border-t border-[#edf0ee] px-5 py-5 lg:flex-row lg:items-center lg:justify-between lg:px-6">
            <div className="text-sm text-black/48">
              共 {pagination.total.toLocaleString()} 条，当前显示第{' '}
              {pagination.total === 0 ? 0 : (pagination.page - 1) * pagination.limit + 1}
              {' - '}
              {Math.min(pagination.page * pagination.limit, pagination.total)} 条
            </div>

            <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  disabled={pagination.page <= 1}
                  onClick={() => setPage((current) => Math.max(1, current - 1))}
                  className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
                >
                  <ChevronLeft className="h-4 w-4" />
                </button>

                {visiblePages.map((pageNumber) => (
                  <button
                    key={pageNumber}
                    type="button"
                    onClick={() => setPage(pageNumber)}
                    className={`h-11 min-w-11 rounded-full px-3 text-sm font-semibold ${
                      pageNumber === pagination.page
                        ? 'bg-[#071110] text-white'
                        : 'border border-[#e8eceb] bg-white text-[#071110]'
                    }`}
                  >
                    {pageNumber}
                  </button>
                ))}

                {pagination.totalPages > visiblePages[visiblePages.length - 1] ? (
                  <span className="px-2 text-black/36">...</span>
                ) : null}

                {pagination.totalPages > visiblePages[visiblePages.length - 1] ? (
                  <button
                    type="button"
                    onClick={() => setPage(pagination.totalPages)}
                    className="h-11 min-w-11 rounded-full border border-[#e8eceb] bg-white px-3 text-sm font-semibold text-[#071110]"
                  >
                    {pagination.totalPages}
                  </button>
                ) : null}

                <button
                  type="button"
                  disabled={pagination.page >= pagination.totalPages}
                  onClick={() => setPage((current) => Math.min(pagination.totalPages, current + 1))}
                  className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
                >
                  <ChevronRight className="h-4 w-4" />
                </button>
              </div>

              <div className="rounded-full border border-[#e8eceb] bg-white px-4 py-2.5 text-sm text-black/48">
                {pagination.limit} 条/页
              </div>
            </div>
          </div>
        </section>
      </section>
    </AdminContentLayout>
  );
}
