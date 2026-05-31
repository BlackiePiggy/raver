'use client';

import { getCountryCode, getEmojiFlag } from 'countries-list';
import Image from 'next/image';
import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ChevronDown,
  ChevronLeft,
  ChevronRight,
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

const formatDateCell = (value?: string | null): { date: string; time: string } => {
  if (!value) return { date: '未记录', time: '' };
  const formatted = formatDateTime(value);
  const [date, time] = formatted.split(' ');
  return {
    date: date || '未记录',
    time: time || '',
  };
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

const resolveDJState = (
  item: DJCatalogItem
): {
  label: string;
  tone: string;
} => {
  if (item.isVerified) {
    return {
      label: '已验证',
      tone: 'border-[#dceabf] bg-[#eef8d8] text-[#2f8b4f]',
    };
  }
  if (isDJIncomplete(item)) {
    return {
      label: '资料待完善',
      tone: 'border-[#dbe7ff] bg-[#eef4ff] text-[#4267c7]',
    };
  }
  return {
    label: '未验证',
    tone: 'border-[#f0dfaf] bg-[#fff4d8] text-[#b57a12]',
  };
};

const resolveCountryDisplay = (
  country?: string | null
): {
  flag: string | null;
  label: string;
} => {
  if (!country) return { flag: null, label: '待补充' };
  const code = getCountryCode(country);
  return {
    flag: code ? getEmojiFlag(code) : null,
    label: country,
  };
};

const resolveTagPills = (item: DJCatalogItem): string[] => {
  const genres = Array.isArray(item.genres) ? item.genres : [];
  const aliases = Array.isArray(item.aliases) ? item.aliases : [];
  const tags = [...genres, ...aliases]
    .map((entry) => entry.trim())
    .filter(Boolean);

  if (!tags.length) return ['资料标签待补充'];
  return Array.from(new Set(tags)).slice(0, 2);
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
        setError('');
        setIsLoading(false);
        if (!cached.isStale) return;
        setIsRefreshing(true);
      } else {
        setIsLoading(true);
      }

      try {
        const response = await adminCatalogApi.fetchDJs(filters);
        writeAdminCatalogCache(cacheKey, response, CACHE_TTL_MS);
        setItems(response.items);
        setPagination(response.pagination);
        setSummary(response.summary ?? null);
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

    const header = ['DJ 名称', '国家/地区', '认证状态', '平台粉丝', '最近同步', '最近更新'];
    const rows = items.map((item) => [
      item.name,
      item.country || '',
      resolveDJState(item).label,
      String(item.followerCount ?? item.soundCloudFollowers ?? ''),
      formatDateTime(item.lastSyncedAt),
      formatDateTime(item.updatedAt),
    ]);

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

  const computedSummary = useMemo<DJCatalogSummary>(() => {
    if (summary) return summary;
    const nextSummary = {
      total: items.length,
      verified: 0,
      unverified: 0,
      incomplete: 0,
    };

    items.forEach((item) => {
      if (item.isVerified) {
        nextSummary.verified += 1;
      } else if (isDJIncomplete(item)) {
        nextSummary.incomplete += 1;
      } else {
        nextSummary.unverified += 1;
      }
    });

    nextSummary.total = nextSummary.verified + nextSummary.unverified + nextSummary.incomplete;
    return nextSummary;
  }, [items, summary]);

  const newThisMonth = useMemo(() => {
    const now = new Date();
    return items.reduce((count, item) => {
      if (!item.createdAt) return count;
      const createdAt = new Date(item.createdAt);
      if (
        createdAt.getFullYear() === now.getFullYear() &&
        createdAt.getMonth() === now.getMonth()
      ) {
        return count + 1;
      }
      return count;
    }, 0);
  }, [items]);

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

  return (
    <AdminContentLayout
      title="DJ 管理"
      eyebrow="内容控制台 / DJ 工作区"
      description="管理平台 DJ 资料、认证状态与内容。可筛选、编辑资料或查看 DJ 详情。"
      actions={
        <>
          <Link
            href="/admin/content/djs/new"
            className="inline-flex h-[52px] items-center gap-2.5 rounded-full border border-[#e8eceb] bg-white px-8 text-[15px] font-semibold text-[#071110] shadow-[0_2px_10px_rgba(15,23,42,0.03)]"
          >
            <Upload className="h-5 w-5" />
            <span>导入 DJ</span>
          </Link>
          <Link
            href="/admin/content/djs/new"
            className="inline-flex h-[52px] items-center gap-2.5 rounded-full bg-[#071110] px-8 text-[15px] font-semibold text-white shadow-[0_10px_24px_rgba(7,17,16,0.15)]"
          >
            <Plus className="h-5 w-5" />
            <span>新增 DJ</span>
          </Link>
        </>
      }
    >
      <section className="space-y-7">
        <section className="rounded-[34px] border border-[#edf0f2] bg-white px-8 py-8 shadow-[0_10px_34px_rgba(17,24,39,0.05)]">
          <div className="flex flex-col gap-6">
            <div className="grid gap-4 xl:grid-cols-[minmax(240px,1.25fr)_165px_175px_150px_56px_110px]">
              <form
                onSubmit={handleSearchSubmit}
                className="contents"
              >
                <label className="flex h-[54px] min-w-0 items-center gap-3 rounded-[22px] border border-[#e8eceb] bg-white px-5 text-[#111827] shadow-[0_2px_10px_rgba(15,23,42,0.02)]">
                  <Search className="h-5 w-5 text-[#7d8592]" />
                  <input
                    value={searchInput}
                    onChange={(event) => setSearchInput(event.target.value)}
                    placeholder="搜索 DJ 名称、国家、标签..."
                    className="w-full border-0 bg-transparent px-0 py-0 text-[15px] font-medium outline-none placeholder:text-[#9aa1ad]"
                  />
                </label>

                <label className="relative flex h-[54px] min-w-0 items-center justify-between rounded-[22px] border border-[#e8eceb] bg-white px-5 text-[15px] font-semibold text-[#111827]">
                  <span>
                    {verificationStatus === 'all'
                      ? '全部认证状态'
                      : verificationStatus === 'verified'
                        ? '已验证'
                        : verificationStatus === 'unverified'
                          ? '未验证'
                          : '资料待完善'}
                  </span>
                  <select
                    value={verificationStatus}
                    onChange={(event) => {
                      setVerificationStatus(
                        event.target.value as 'all' | 'verified' | 'unverified' | 'incomplete'
                      );
                      setPage(1);
                    }}
                    className="absolute inset-0 opacity-0"
                  >
                    <option value="all">全部认证状态</option>
                    <option value="verified">已验证</option>
                    <option value="unverified">未验证</option>
                    <option value="incomplete">资料待完善</option>
                  </select>
                  <ChevronDown className="h-5 w-5 text-[#7d8592]" />
                </label>

                <label className="relative flex h-[54px] min-w-0 items-center justify-between rounded-[22px] border border-[#e8eceb] bg-white px-5 text-[15px] font-semibold text-[#111827]">
                  <span>{country === 'all' ? '全部国家/地区' : country}</span>
                  <select
                    value={country}
                    onChange={(event) => {
                      setCountry(event.target.value);
                      setPage(1);
                    }}
                    className="absolute inset-0 opacity-0"
                  >
                    <option value="all">全部国家/地区</option>
                    {countryOptions.map((item) => (
                      <option key={item} value={item}>
                        {item}
                      </option>
                    ))}
                  </select>
                  <ChevronDown className="h-5 w-5 text-[#7d8592]" />
                </label>

                <details className="relative">
                  <summary className="flex h-[54px] cursor-pointer list-none items-center gap-3 rounded-[22px] border border-[#e8eceb] bg-white px-5 text-[15px] font-semibold text-[#111827]">
                    <Filter className="h-5 w-5" />
                    <span>更多筛选</span>
                  </summary>
                  <div className="absolute left-0 top-[calc(100%+10px)] z-20 min-w-[220px] rounded-[24px] border border-[#e8eceb] bg-white p-4 shadow-[0_18px_42px_rgba(33,52,47,0.12)]">
                    <div className="mb-2 text-xs font-semibold uppercase tracking-[0.14em] text-[#9aa1ad]">
                      排序方式
                    </div>
                    <select
                      value={sortBy}
                      onChange={(event) => {
                        setSortBy(event.target.value as 'followerCount' | 'name' | 'createdAt');
                        setPage(1);
                      }}
                      className="w-full rounded-[18px] border border-[#e8eceb] bg-white px-4 py-3 text-sm font-semibold text-[#111827] outline-none"
                    >
                      <option value="followerCount">按平台粉丝</option>
                      <option value="name">按名称</option>
                      <option value="createdAt">按创建时间</option>
                    </select>
                  </div>
                </details>
              </form>

              <button
                type="button"
                onClick={handleRefresh}
                className="inline-flex h-[54px] w-[54px] items-center justify-center rounded-[22px] border border-[#e8eceb] bg-white text-[#071110]"
                aria-label="刷新目录"
              >
                <RefreshCw className={`h-5 w-5 ${isRefreshing ? 'animate-spin' : ''}`} />
              </button>

              <button
                type="button"
                onClick={handleExport}
                className="inline-flex h-[54px] items-center justify-center gap-3 rounded-[22px] border border-[#e8eceb] bg-white px-5 text-[15px] font-semibold text-[#111827]"
              >
                <Download className="h-5 w-5" />
                <span>导出</span>
              </button>
            </div>

            <div className="overflow-hidden rounded-[28px] border border-[#edf0f2] bg-white shadow-[0_2px_10px_rgba(15,23,42,0.03)]">
              <div className="grid xl:grid-cols-4">
                <div className="flex min-h-[112px] flex-col justify-between px-10 py-6">
                  <div className="text-[15px] font-semibold text-[#111827]">全部 DJ</div>
                  <div className="flex items-end justify-between gap-4">
                    <div className="text-[38px] font-semibold leading-none tracking-[-0.04em] text-[#111827]">
                      {computedSummary.total.toLocaleString()}
                    </div>
                    <div className="pb-1 text-[13px] font-semibold text-[#55b776]">
                      ↑ {newThisMonth} 本月新增
                    </div>
                  </div>
                </div>

                <div className="flex min-h-[112px] flex-col justify-between border-t border-[#edf0f2] px-10 py-6 xl:border-l xl:border-t-0">
                  <div className="text-[15px] font-semibold text-[#111827]">已验证</div>
                  <div className="flex items-end justify-between gap-4">
                    <div className="text-[38px] font-semibold leading-none tracking-[-0.04em] text-[#111827]">
                      {computedSummary.verified.toLocaleString()}
                    </div>
                    <div className="pb-1 text-[15px] font-semibold text-[#7a818d]">
                      {formatPercentage(computedSummary.verified, computedSummary.total)}
                    </div>
                  </div>
                </div>

                <div className="flex min-h-[112px] flex-col justify-between border-t border-[#edf0f2] px-10 py-6 xl:border-l xl:border-t-0">
                  <div className="text-[15px] font-semibold text-[#111827]">未验证</div>
                  <div className="flex items-end justify-between gap-4">
                    <div className="text-[38px] font-semibold leading-none tracking-[-0.04em] text-[#111827]">
                      {computedSummary.unverified.toLocaleString()}
                    </div>
                    <div className="pb-1 text-[15px] font-semibold text-[#7a818d]">
                      {formatPercentage(computedSummary.unverified, computedSummary.total)}
                    </div>
                  </div>
                </div>

                <div className="flex min-h-[112px] flex-col justify-between border-t border-[#edf0f2] px-10 py-6 xl:border-l xl:border-t-0">
                  <div className="text-[15px] font-semibold text-[#111827]">资料待完善</div>
                  <div className="flex items-end justify-between gap-4">
                    <div className="text-[38px] font-semibold leading-none tracking-[-0.04em] text-[#111827]">
                      {computedSummary.incomplete.toLocaleString()}
                    </div>
                    <div className="pb-1 text-[15px] font-semibold text-[#7a818d]">
                      {formatPercentage(computedSummary.incomplete, computedSummary.total)}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="overflow-hidden rounded-[34px] border border-[#edf0f2] bg-white shadow-[0_10px_34px_rgba(17,24,39,0.05)]">
          {error ? (
            <div className="border-b border-red-200 bg-red-50 px-8 py-4 text-sm text-[#7a2d29]">
              {error}
            </div>
          ) : null}

          <div className="hidden border-b border-[#edf0f2] px-7 py-6 lg:grid lg:grid-cols-[minmax(0,2.9fr)_1.15fr_0.95fr_1fr_1.15fr_1.15fr_156px] lg:gap-6">
            {['DJ 信息', '国家/地区', '认证状态', '平台粉丝', '最近同步', '最近更新', '操作'].map((label) => (
              <div key={label} className="text-[15px] font-semibold text-[#4b5563]">
                {label}
              </div>
            ))}
          </div>

          {isLoading ? (
            <div className="px-8 py-20 text-center text-sm text-[#6b7280]">DJ 目录加载中…</div>
          ) : items.length === 0 ? (
            <div className="px-8 py-20 text-center text-sm text-[#6b7280]">当前筛选条件下还没有 DJ。</div>
          ) : (
            <div className="divide-y divide-[#edf0f2]">
              {items.map((item) => {
                const state = resolveDJState(item);
                const tags = resolveTagPills(item);
                const countryDisplay = resolveCountryDisplay(item.country);
                const lastSynced = formatDateCell(item.lastSyncedAt);
                const updatedAt = formatDateCell(item.updatedAt);
                return (
                  <article
                    key={item.id}
                    className="px-7 py-5 lg:grid lg:grid-cols-[minmax(0,2.9fr)_1.15fr_0.95fr_1fr_1.15fr_1.15fr_156px] lg:items-center lg:gap-6"
                  >
                    <div className="min-w-0">
                      <div className="flex min-w-0 items-center gap-4">
                        <div className="flex h-[72px] w-[72px] shrink-0 items-center justify-center overflow-hidden rounded-[18px] bg-[#f1f4f6]">
                          {item.avatarUrl ? (
                            <Image
                              src={item.avatarUrl}
                              alt={item.name}
                              width={72}
                              height={72}
                              className="h-full w-full object-cover"
                            />
                          ) : (
                            <span className="text-xs text-[#9aa1ad]">暂无头像</span>
                          )}
                        </div>

                        <div className="min-w-0 flex-1">
                          <div className="truncate text-[18px] font-semibold tracking-[-0.02em] text-[#111827]">
                            {item.name}
                          </div>
                          <div className="mt-2.5 flex flex-wrap items-center gap-2">
                            {tags.map((tag) => (
                              <span
                                key={`${item.id}-${tag}`}
                                className="rounded-full bg-[#f4f5f7] px-3 py-1 text-[12px] font-semibold text-[#6b7280]"
                              >
                                {tag}
                              </span>
                            ))}
                            <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-[12px] font-semibold text-[#8f96a3]">
                              ...
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>

                    <div className="mt-4 flex items-center gap-3 text-[17px] font-medium text-[#111827] lg:mt-0">
                      {countryDisplay.flag ? (
                        <span className="text-[28px] leading-none" aria-hidden="true">
                          {countryDisplay.flag}
                        </span>
                      ) : null}
                      <span className="truncate">{countryDisplay.label}</span>
                    </div>

                    <div className="mt-4 lg:mt-0">
                      <span
                        className={`inline-flex rounded-full border px-4 py-2 text-[14px] font-semibold ${state.tone}`}
                      >
                        {state.label}
                      </span>
                    </div>

                    <div className="mt-4 text-[17px] font-medium text-[#111827] lg:mt-0">
                      {formatFollowers(item.followerCount ?? item.soundCloudFollowers)}
                    </div>

                    <div className="mt-4 text-[16px] font-medium text-[#111827] lg:mt-0">
                      <div>{lastSynced.date}{lastSynced.time ? ` ${lastSynced.time}` : ''}</div>
                    </div>

                    <div className="mt-4 text-[16px] font-medium text-[#111827] lg:mt-0">
                      <div>{updatedAt.date}{updatedAt.time ? ` ${updatedAt.time}` : ''}</div>
                    </div>

                    <div className="mt-4 flex items-center gap-3 lg:mt-0 lg:justify-end">
                      <Link
                        href={`/admin/content/djs/${item.id}/edit`}
                        className="inline-flex h-[50px] items-center rounded-full border border-[#e8eceb] bg-white px-6 text-[15px] font-semibold text-[#111827]"
                      >
                        编辑
                      </Link>
                      <button
                        type="button"
                        className="inline-flex h-[50px] w-[50px] items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#111827]"
                        aria-label="更多操作"
                      >
                        <Ellipsis className="h-5 w-5" />
                      </button>
                    </div>
                  </article>
                );
              })}
            </div>
          )}

          <div className="flex flex-col gap-4 border-t border-[#edf0f2] px-7 py-5 lg:flex-row lg:items-center lg:justify-between">
            <div className="text-[15px] font-medium text-[#6b7280]">共 {pagination.total.toLocaleString()} 条</div>

            <div className="flex items-center gap-2">
              <button
                type="button"
                disabled={pagination.page <= 1}
                onClick={() => setPage((current) => Math.max(1, current - 1))}
                className="inline-flex h-10 w-10 items-center justify-center rounded-full text-[#8f96a3] disabled:cursor-not-allowed disabled:opacity-40"
              >
                <ChevronLeft className="h-5 w-5" />
              </button>

              {visiblePages.map((pageNumber) => (
                <button
                  key={pageNumber}
                  type="button"
                  onClick={() => setPage(pageNumber)}
                  className={`inline-flex h-10 min-w-10 items-center justify-center rounded-[14px] px-3 text-[15px] font-semibold ${
                    pageNumber === pagination.page ? 'bg-[#071110] text-white' : 'text-[#111827]'
                  }`}
                >
                  {pageNumber}
                </button>
              ))}

              {pagination.totalPages > visiblePages[visiblePages.length - 1] ? (
                <>
                  <span className="px-2 text-[#9aa1ad]">...</span>
                  <button
                    type="button"
                    onClick={() => setPage(pagination.totalPages)}
                    className="inline-flex h-10 min-w-10 items-center justify-center rounded-[14px] px-3 text-[15px] font-semibold text-[#111827]"
                  >
                    {pagination.totalPages}
                  </button>
                </>
              ) : null}

              <button
                type="button"
                disabled={pagination.page >= pagination.totalPages}
                onClick={() => setPage((current) => Math.min(pagination.totalPages, current + 1))}
                className="inline-flex h-10 w-10 items-center justify-center rounded-full text-[#111827] disabled:cursor-not-allowed disabled:opacity-40"
              >
                <ChevronRight className="h-5 w-5" />
              </button>
            </div>

            <div className="flex items-center gap-2 rounded-[16px] border border-[#e8eceb] bg-white px-5 py-3 text-[15px] font-semibold text-[#111827]">
              <span>{pagination.limit} 条/页</span>
              <ChevronDown className="h-4 w-4 text-[#7d8592]" />
            </div>
          </div>
        </section>
      </section>
    </AdminContentLayout>
  );
}
