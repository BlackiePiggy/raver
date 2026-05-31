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
  return { date: date || '未记录', time: time || '' };
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

const resolveDJState = (item: DJCatalogItem): { label: string; tone: string } => {
  if (item.isVerified) {
    return { label: '已验证', tone: 'border-[#c6e8c8] bg-[#eef8ee] text-[#2f8b4f]' };
  }
  if (isDJIncomplete(item)) {
    return { label: '资料待完善', tone: 'border-[#c8d9fb] bg-[#eef2ff] text-[#4267c7]' };
  }
  return { label: '未验证', tone: 'border-[#f0dfaf] bg-[#fff9ec] text-[#b57a12]' };
};

const resolveCountryDisplay = (country?: string | null): { flag: string | null; label: string } => {
  if (!country) return { flag: null, label: '待补充' };
  const code = getCountryCode(country);
  return {
    flag: code ? getEmojiFlag(code) : null,
    label: country, // ⑤ 显示完整国家名
  };
};

const resolveTagPills = (item: DJCatalogItem): string[] => {
  const genres = Array.isArray(item.genres) ? item.genres : [];
  const aliases = Array.isArray(item.aliases) ? item.aliases : [];
  const tags = [...genres, ...aliases].map((entry) => entry.trim()).filter(Boolean);
  if (!tags.length) return ['资料标签待补充'];
  return Array.from(new Set(tags)).slice(0, 2);
};

// ② 统计块 — 扁平横排，label上方，数字+百分比下方两端
function StatBlock({
  label,
  value,
  rightText,
  helper,
}: {
  label: string;
  value: number;
  rightText?: string;
  helper?: string;
}) {
  return (
    <div className="flex flex-1 flex-col gap-2 px-6 py-5">
      <div className="text-[13px] font-medium text-[#6b7280]">{label}</div>
      <div className="flex items-end justify-between gap-2">
        <div className="text-[28px] font-semibold leading-none tracking-[-0.035em] text-[#111827]">
          {value.toLocaleString()}
        </div>
        {helper ? (
          <div className="flex items-center gap-1 pb-0.5 text-[12px] font-semibold text-[#22c55e]">
            {helper}
          </div>
        ) : null}
        {rightText ? (
          <div className="pb-0.5 text-[13px] font-medium text-[#9aa1ad]">{rightText}</div>
        ) : null}
      </div>
    </div>
  );
}

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
    const nextSummary = { total: items.length, verified: 0, unverified: 0, incomplete: 0 };
    items.forEach((item) => {
      if (item.isVerified) nextSummary.verified += 1;
      else if (isDJIncomplete(item)) nextSummary.incomplete += 1;
      else nextSummary.unverified += 1;
    });
    nextSummary.total = nextSummary.verified + nextSummary.unverified + nextSummary.incomplete;
    return nextSummary;
  }, [items, summary]);

  const countryOptions = useMemo(() => {
    const options = Array.from(new Set(items.map((item) => item.country).filter(Boolean))) as string[];
    if (country !== 'all' && country && !options.includes(country)) options.push(country);
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
          {/* ① 导入按钮：无边框、纯文字+图标 */}
          <Link
            href="/admin/content/djs/new"
            className="inline-flex h-[44px] items-center gap-2 rounded-full border border-[#e8eceb] bg-white px-5 text-[14px] font-semibold text-[#111827]"
          >
            <Upload className="h-4 w-4" />
            <span>导入 DJ</span>
          </Link>
          <Link
            href="/admin/content/djs/new"
            className="inline-flex h-[44px] items-center gap-2 rounded-full bg-[#071110] px-5 text-[14px] font-semibold text-white"
          >
            <Plus className="h-4 w-4" />
            <span>新增 DJ</span>
          </Link>
        </>
      }
    >
      <section className="space-y-4">

        {/* ① 筛选栏 — 无外层卡片，扁平一行 */}
        <div className="flex flex-wrap items-center gap-3">
          <form onSubmit={handleSearchSubmit} className="flex min-w-0 flex-1 flex-wrap items-center gap-3">
            {/* 搜索框：图标在右侧 */}
            <label className="flex h-[44px] min-w-[220px] flex-[1.5_1_280px] items-center gap-3 rounded-[14px] border border-[#e8eceb] bg-white px-4 text-[#111827]">
              <input
                value={searchInput}
                onChange={(event) => setSearchInput(event.target.value)}
                placeholder="搜索 DJ 名称、国家、标签..."
                className="w-full border-0 bg-transparent px-0 py-0 text-[14px] font-medium outline-none placeholder:text-[#9aa1ad]"
              />
              <Search className="h-4 w-4 shrink-0 text-[#9aa1ad]" />
            </label>

            {/* 全部认证状态 */}
            <label className="relative flex h-[44px] min-w-[160px] flex-1 items-center justify-between rounded-[14px] border border-[#e8eceb] bg-white px-4 text-[14px] font-semibold text-[#111827]">
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
                  setVerificationStatus(event.target.value as 'all' | 'verified' | 'unverified' | 'incomplete');
                  setPage(1);
                }}
                className="absolute inset-0 opacity-0"
              >
                <option value="all">全部认证状态</option>
                <option value="verified">已验证</option>
                <option value="unverified">未验证</option>
                <option value="incomplete">资料待完善</option>
              </select>
              <ChevronDown className="h-4 w-4 text-[#9aa1ad]" />
            </label>

            {/* 全部国家/地区 */}
            <label className="relative flex h-[44px] min-w-[150px] flex-1 items-center justify-between rounded-[14px] border border-[#e8eceb] bg-white px-4 text-[14px] font-semibold text-[#111827]">
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
                  <option key={item} value={item}>{item}</option>
                ))}
              </select>
              <ChevronDown className="h-4 w-4 text-[#9aa1ad]" />
            </label>

            {/* 更多筛选 */}
            <details className="relative">
              <summary className="flex h-[44px] cursor-pointer list-none items-center gap-2 rounded-[14px] border border-[#e8eceb] bg-white px-4 text-[14px] font-semibold text-[#111827]">
                <Filter className="h-4 w-4" />
                <span>更多筛选</span>
              </summary>
              <div className="absolute left-0 top-[calc(100%+8px)] z-20 min-w-[200px] rounded-[18px] border border-[#e8eceb] bg-white p-4 shadow-[0_12px_32px_rgba(33,52,47,0.10)]">
                <div className="mb-2 text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">排序方式</div>
                <select
                  value={sortBy}
                  onChange={(event) => {
                    setSortBy(event.target.value as 'followerCount' | 'name' | 'createdAt');
                    setPage(1);
                  }}
                  className="w-full rounded-[12px] border border-[#e8eceb] bg-white px-3 py-2.5 text-sm font-semibold text-[#111827] outline-none"
                >
                  <option value="followerCount">按平台粉丝</option>
                  <option value="name">按名称</option>
                  <option value="createdAt">按创建时间</option>
                </select>
              </div>
            </details>
          </form>

          {/* ① 刷新、导出 — 移至最右，图标+文字风格 */}
          <button
            type="button"
            onClick={handleRefresh}
            className="inline-flex h-[44px] w-[44px] items-center justify-center rounded-[14px] border border-[#e8eceb] bg-white text-[#6b7280]"
            aria-label="刷新目录"
          >
            <RefreshCw className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`} />
          </button>

          <button
            type="button"
            onClick={handleExport}
            className="inline-flex h-[44px] items-center gap-2 rounded-[14px] border border-[#e8eceb] bg-white px-4 text-[14px] font-semibold text-[#111827]"
          >
            <Download className="h-4 w-4" />
            <span>导出</span>
          </button>
        </div>

        {/* ② 统计块 — 扁平四格横排，轻边框容器，竖线分隔 */}
        <div className="flex overflow-hidden rounded-[18px] border border-[#edf0f2] bg-white divide-x divide-[#edf0f2]">
          <StatBlock
            label="全部 DJ"
            value={computedSummary.total}
            helper={computedSummary.total ? `↑ ${Math.max(0, Math.min(items.length, PAGE_SIZE))} 本月新增` : undefined}
          />
          <StatBlock
            label="已验证"
            value={computedSummary.verified}
            rightText={formatPercentage(computedSummary.verified, computedSummary.total)}
          />
          <StatBlock
            label="未验证"
            value={computedSummary.unverified}
            rightText={formatPercentage(computedSummary.unverified, computedSummary.total)}
          />
          <StatBlock
            label="资料待完善"
            value={computedSummary.incomplete}
            rightText={formatPercentage(computedSummary.incomplete, computedSummary.total)}
          />
        </div>

        {/* 列表区 */}
        <section className="overflow-hidden rounded-[18px] border border-[#edf0f2] bg-white">
          {error ? (
            <div className="border-b border-red-200 bg-red-50 px-6 py-3 text-sm text-[#7a2d29]">{error}</div>
          ) : null}

          {/* ③ 表头 — 更小更轻 */}
          <div className="hidden border-b border-[#edf0f2] px-5 py-3 lg:grid lg:grid-cols-[minmax(0,2.4fr)_1.2fr_0.9fr_1fr_1.2fr_1.2fr_140px] lg:gap-6">
            {['DJ 信息', '国家/地区', '认证状态', '平台粉丝', '最近同步', '最近更新', '操作'].map((label) => (
              <div key={label} className="text-[13px] font-medium text-[#9aa1ad]">
                {label}
              </div>
            ))}
          </div>

          {isLoading ? (
            <div className="px-6 py-16 text-center text-sm text-[#6b7280]">DJ 目录加载中…</div>
          ) : items.length === 0 ? (
            <div className="px-6 py-16 text-center text-sm text-[#6b7280]">当前筛选条件下还没有 DJ。</div>
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
                    className="px-5 py-3.5 lg:grid lg:grid-cols-[minmax(0,2.4fr)_1.2fr_0.9fr_1fr_1.2fr_1.2fr_140px] lg:items-center lg:gap-6"
                  >
                    {/* ④ DJ信息列：头像56×56，更紧凑 */}
                    <div className="min-w-0">
                      <div className="flex min-w-0 items-center gap-3">
                        <div className="flex h-[56px] w-[56px] shrink-0 items-center justify-center overflow-hidden rounded-[14px] bg-[#f1f4f6]">
                          {item.avatarUrl ? (
                            <Image
                              src={item.avatarUrl}
                              alt={item.name}
                              width={56}
                              height={56}
                              className="h-full w-full object-cover"
                            />
                          ) : (
                            <span className="text-xs text-[#9aa1ad]">暂无</span>
                          )}
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="truncate text-[15px] font-semibold tracking-[-0.01em] text-[#111827]">
                            {item.name}
                          </div>
                          <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
                            {tags.map((tag) => (
                              <span
                                key={`${item.id}-${tag}`}
                                className="rounded-full bg-[#f4f5f7] px-2.5 py-0.5 text-[11px] font-semibold text-[#6b7280]"
                              >
                                {tag}
                              </span>
                            ))}
                            <span className="rounded-full bg-[#f4f5f7] px-2.5 py-0.5 text-[11px] font-semibold text-[#8f96a3]">
                              ...
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* ⑤ 国家：完整名称 */}
                    <div className="mt-3 flex items-center gap-2 text-[14px] font-medium text-[#111827] lg:mt-0">
                      {countryDisplay.flag ? (
                        <span className="text-[20px] leading-none" aria-hidden="true">
                          {countryDisplay.flag}
                        </span>
                      ) : null}
                      <span>{countryDisplay.label}</span>
                    </div>

                    {/* ⑥ 认证状态 badge — 更紧凑 */}
                    <div className="mt-3 lg:mt-0">
                      <span
                        className={`inline-flex rounded-full border px-3 py-1 text-[12px] font-semibold ${state.tone}`}
                      >
                        {state.label}
                      </span>
                    </div>

                    <div className="mt-3 text-[14px] font-medium text-[#111827] lg:mt-0">
                      {formatFollowers(item.followerCount ?? item.soundCloudFollowers)}
                    </div>

                    <div className="mt-3 text-[13px] font-medium text-[#111827] lg:mt-0">
                      <div>{lastSynced.date}</div>
                      {lastSynced.time ? <div className="text-[#6b7280]">{lastSynced.time}</div> : null}
                    </div>

                    <div className="mt-3 text-[13px] font-medium text-[#111827] lg:mt-0">
                      <div>{updatedAt.date}</div>
                      {updatedAt.time ? <div className="text-[#6b7280]">{updatedAt.time}</div> : null}
                    </div>

                    {/* ⑦ 操作按钮 — 更小，描边风格 */}
                    <div className="mt-3 flex items-center gap-2 lg:mt-0 lg:justify-end">
                      <Link
                        href={`/admin/content/djs/${item.id}/edit`}
                        className="inline-flex h-[36px] items-center rounded-[10px] border border-[#e8eceb] bg-white px-4 text-[13px] font-semibold text-[#111827]"
                      >
                        编辑
                      </Link>
                      <button
                        type="button"
                        className="inline-flex h-[36px] w-[36px] items-center justify-center rounded-[10px] border border-[#e8eceb] bg-white text-[#6b7280]"
                        aria-label="更多操作"
                      >
                        <Ellipsis className="h-4 w-4" />
                      </button>
                    </div>
                  </article>
                );
              })}
            </div>
          )}

          {/* 分页 */}
          <div className="flex flex-col gap-3 border-t border-[#edf0f2] px-5 py-4 lg:flex-row lg:items-center lg:justify-between">
            <div className="text-[13px] font-medium text-[#6b7280]">
              共 {pagination.total.toLocaleString()} 条
            </div>

            <div className="flex items-center gap-1.5">
              <button
                type="button"
                disabled={pagination.page <= 1}
                onClick={() => setPage((current) => Math.max(1, current - 1))}
                className="inline-flex h-9 w-9 items-center justify-center rounded-full text-[#8f96a3] disabled:cursor-not-allowed disabled:opacity-40"
              >
                <ChevronLeft className="h-4 w-4" />
              </button>

              {visiblePages.map((pageNumber) => (
                <button
                  key={pageNumber}
                  type="button"
                  onClick={() => setPage(pageNumber)}
                  className={`inline-flex h-9 min-w-9 items-center justify-center rounded-full px-3 text-[14px] font-semibold ${
                    pageNumber === pagination.page ? 'bg-[#071110] text-white' : 'text-[#111827]'
                  }`}
                >
                  {pageNumber}
                </button>
              ))}

              {pagination.totalPages > visiblePages[visiblePages.length - 1] ? (
                <>
                  <span className="px-1 text-[#9aa1ad]">...</span>
                  <button
                    type="button"
                    onClick={() => setPage(pagination.totalPages)}
                    className="inline-flex h-9 min-w-9 items-center justify-center rounded-full px-3 text-[14px] font-semibold text-[#111827]"
                  >
                    {pagination.totalPages}
                  </button>
                </>
              ) : null}

              <button
                type="button"
                disabled={pagination.page >= pagination.totalPages}
                onClick={() => setPage((current) => Math.min(pagination.totalPages, current + 1))}
                className="inline-flex h-9 w-9 items-center justify-center rounded-full text-[#111827] disabled:cursor-not-allowed disabled:opacity-40"
              >
                <ChevronRight className="h-4 w-4" />
              </button>
            </div>

            <div className="flex items-center gap-2 rounded-[12px] border border-[#e8eceb] bg-white px-4 py-2 text-[13px] font-semibold text-[#111827]">
              <span>{pagination.limit} 条/页</span>
              <ChevronDown className="h-3.5 w-3.5 text-[#9aa1ad]" />
            </div>
          </div>
        </section>
      </section>
    </AdminContentLayout>
  );
}
