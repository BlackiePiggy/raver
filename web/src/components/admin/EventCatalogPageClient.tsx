'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  CalendarRange,
  CheckCheck,
  ChevronLeft,
  ChevronRight,
  Clock3,
  Copy,
  Ellipsis,
  Link2,
  MapPin,
  RefreshCw,
  Search,
  SlidersHorizontal,
  UserRoundPlus,
  XCircle,
} from 'lucide-react';
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
import {
  eventOrganizerBindingApi,
} from '@/features/admin-content/event-organizer-binding/api';
import type { EventStudioOrganizer } from '@/features/admin-content/event-studio';

const PAGE_SIZE = 10;
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
      return 'border-[#dceabf] bg-[#eef8d8] text-[#2f4027]';
    case 'ended':
      return 'border-[#e8eceb] bg-[#f5f5f7] text-[#5f6a67]';
    case 'cancelled':
    case 'canceled':
      return 'border-[#efdad8] bg-[#f7e3e0] text-[#6a3530]';
    default:
      return 'border-[#eadfbe] bg-[#f6edd7] text-[#604a1b]';
  }
};

const resolveEventStatusLabel = (status?: string | null): string => {
  switch (status) {
    case 'ongoing':
      return 'Live';
    case 'ended':
      return 'Ended';
    case 'cancelled':
    case 'canceled':
      return 'Cancelled';
    default:
      return 'Upcoming';
  }
};

const resolveEventStatusSummary = (status?: string | null): string => {
  switch (status) {
    case 'ongoing':
      return '进行中';
    case 'ended':
      return '已结束';
    case 'cancelled':
    case 'canceled':
      return '已取消';
    default:
      return '即将开始';
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
  const [cityInput, setCityInput] = useState('');
  const [city, setCity] = useState('');
  const [countryInput, setCountryInput] = useState('');
  const [country, setCountry] = useState('');
  const [eventType, setEventType] = useState('all');
  const [page, setPage] = useState(1);
  const [items, setItems] = useState<EventCatalogItem[]>([]);
  const [pagination, setPagination] = useState<AdminCatalogPagination>(EMPTY_PAGINATION);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState('');
  const [cacheMeta, setCacheMeta] = useState<CacheMeta | null>(null);
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [bulkNotice, setBulkNotice] = useState('');
  const [organizerQuery, setOrganizerQuery] = useState('');
  const [organizerResults, setOrganizerResults] = useState<EventStudioOrganizer[]>([]);
  const [selectedOrganizer, setSelectedOrganizer] = useState<EventStudioOrganizer | null>(null);
  const [isSearchingOrganizers, setIsSearchingOrganizers] = useState(false);
  const [isApplyingBulkBinding, setIsApplyingBulkBinding] = useState(false);

  const filters = useMemo<EventCatalogFilters>(
    () => ({
      page,
      limit: PAGE_SIZE,
      search: search || undefined,
      status,
      city: city || undefined,
      country: country || undefined,
      eventType: eventType === 'all' ? undefined : eventType,
    }),
    [page, search, status, city, country, eventType]
  );

  const cacheKey = useMemo(
    () =>
      buildAdminCatalogCacheKey('events-catalog', {
        page,
        limit: PAGE_SIZE,
        search: search || undefined,
        status,
        city: city || undefined,
        country: country || undefined,
        eventType: eventType === 'all' ? undefined : eventType,
      }),
    [page, search, status, city, country, eventType]
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
    setCity(cityInput.trim());
    setCountry(countryInput.trim());
    setSelectedIds([]);
    setBulkNotice('');
  };

  const handleRefresh = () => {
    clearAdminCatalogCache(cacheKey);
    void loadCatalog({ force: true });
  };

  const handleReset = () => {
    setSearchInput('');
    setSearch('');
    setStatus('all');
    setCityInput('');
    setCity('');
    setCountryInput('');
    setCountry('');
    setEventType('all');
    setPage(1);
    setSelectedIds([]);
    setBulkNotice('');
  };

  const selectedItems = useMemo(
    () => items.filter((item) => selectedIds.includes(item.id)),
    [items, selectedIds]
  );

  const selectedIdSet = useMemo(() => new Set(selectedIds), [selectedIds]);

  const allCurrentPageSelected = items.length > 0 && items.every((item) => selectedIdSet.has(item.id));

  const toggleItemSelection = (id: string) => {
    setSelectedIds((current) =>
      current.includes(id) ? current.filter((item) => item !== id) : [...current, id]
    );
    setBulkNotice('');
  };

  const toggleSelectAllCurrentPage = () => {
    setSelectedIds((current) =>
      allCurrentPageSelected
        ? current.filter((id) => !items.some((item) => item.id === id))
        : Array.from(new Set([...current, ...items.map((item) => item.id)]))
    );
    setBulkNotice('');
  };

  const handleBulkCopy = async (mode: 'ids' | 'names' | 'links') => {
    if (!selectedItems.length || typeof window === 'undefined' || !navigator.clipboard?.writeText) return;

    const text =
      mode === 'ids'
        ? selectedItems.map((item) => item.id).join('\n')
        : mode === 'names'
          ? selectedItems.map((item) => item.name).join('\n')
          : selectedItems.map((item) => `${window.location.origin}/events/${item.id}`).join('\n');

    await navigator.clipboard.writeText(text);
    setBulkNotice(
      mode === 'ids'
        ? `已复制 ${selectedItems.length} 条活动 ID`
        : mode === 'names'
          ? `已复制 ${selectedItems.length} 条活动名称`
          : `已复制 ${selectedItems.length} 条活动详情链接`
    );
  };

  const bulkEditHref =
    selectedItems.length === 1 ? `/admin/content/events/${selectedItems[0].id}/edit` : null;

  useEffect(() => {
    const query = organizerQuery.trim();
    if (!query) {
      setOrganizerResults([]);
      return;
    }

    const timer = window.setTimeout(async () => {
      try {
        setIsSearchingOrganizers(true);
        const results = await eventOrganizerBindingApi.searchOrganizers(query);
        setOrganizerResults(results);
      } catch {
        setOrganizerResults([]);
      } finally {
        setIsSearchingOrganizers(false);
      }
    }, 280);

    return () => window.clearTimeout(timer);
  }, [organizerQuery]);

  const statusCounts = useMemo(() => {
    const counts = {
      upcoming: 0,
      ongoing: 0,
      ended: 0,
      cancelled: 0,
      verified: 0,
      draft: 0,
    };

    items.forEach((item) => {
      if (item.status === 'ongoing') counts.ongoing += 1;
      else if (item.status === 'ended') counts.ended += 1;
      else if (item.status === 'cancelled' || item.status === 'canceled') counts.cancelled += 1;
      else counts.upcoming += 1;

      if (item.isVerified) counts.verified += 1;
      else counts.draft += 1;
    });

    return counts;
  }, [items]);

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

  const handleBulkBindOrganizer = async () => {
    if (!selectedOrganizer || selectedIds.length === 0) return;

    try {
      setIsApplyingBulkBinding(true);
      setError('');
      const result = await eventOrganizerBindingApi.bindOrganizerBatch({
        eventIds: selectedIds,
        organizerId: selectedOrganizer.id,
        organizerName: selectedOrganizer.name,
      });
      setBulkNotice(
        result.failureCount > 0
          ? `批量绑定完成：成功 ${result.successCount} 条，失败 ${result.failureCount} 条。`
          : `批量绑定完成：成功 ${result.successCount} 条。`
      );
      setSelectedIds([]);
      await loadCatalog({ force: true });
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '批量绑定主办方失败');
    } finally {
      setIsApplyingBulkBinding(false);
    }
  };

  const handleBulkClearOrganizer = async () => {
    if (selectedIds.length === 0) return;

    try {
      setIsApplyingBulkBinding(true);
      setError('');
      const result = await eventOrganizerBindingApi.clearOrganizerBatch({
        eventIds: selectedIds,
      });
      setBulkNotice(
        result.failureCount > 0
          ? `批量清空完成：成功 ${result.successCount} 条，失败 ${result.failureCount} 条。`
          : `批量清空完成：成功 ${result.successCount} 条。`
      );
      setSelectedIds([]);
      setSelectedOrganizer(null);
      setOrganizerQuery('');
      await loadCatalog({ force: true });
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '批量清空主办方失败');
    } finally {
      setIsApplyingBulkBinding(false);
    }
  };

  const handleCopySingleId = async (id: string) => {
    if (typeof window === 'undefined' || !navigator.clipboard?.writeText) return;
    await navigator.clipboard.writeText(id);
    setBulkNotice(`已复制活动 ID：${id}`);
  };

  return (
    <AdminContentLayout
      title="活动目录"
      eyebrow="Admin / Content / Events / Catalog"
      description="集中查看、筛选和编辑活动。把主要操作收束到目录页主线里，减少无关说明的干扰。"
      actions={
        <>
          <button
            type="button"
            onClick={handleRefresh}
            className="inline-flex items-center gap-2 rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            <RefreshCw className="h-4 w-4" />
            <span>刷新目录</span>
          </button>
          <Link href="/admin/content/events" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            活动工作区
          </Link>
        </>
      }
    >
      <section className="admin-reference-card overflow-hidden p-5 lg:p-6">
        <div className="flex flex-col gap-5">
          <div className="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
            <div className="space-y-3">
              <div className="flex flex-wrap items-center gap-3">
                <span className="rounded-full bg-[#eff4f2] px-4 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-black/45">
                  Event Catalog
                </span>
                <span className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm text-black/48">
                  {cacheSummary}
                </span>
                {cacheMeta?.fetchedAt ? (
                  <span className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm text-black/48">
                    更新于 {formatDateTime(cacheMeta.fetchedAt)}
                  </span>
                ) : null}
              </div>
              <p className="max-w-[44rem] text-[14px] leading-7 text-black/48">
                搜索、筛选、状态判断和编辑入口都集中在这一页，尽量让主要操作一步直达。
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-3">
              <button
                type="button"
                onClick={toggleSelectAllCurrentPage}
                disabled={!items.length}
                className="rounded-full border border-[#e8eceb] bg-white px-4 py-2.5 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
              >
                {allCurrentPageSelected ? '取消全选' : '全选当前页'}
              </button>
              <Link
                href="/admin/content/events/new"
                className="rounded-full border border-[#e8eceb] bg-[#f8f9f8] px-5 py-2.5 text-sm font-semibold text-[#071110]"
              >
                导入活动
              </Link>
              <Link href="/admin/content/events/new" className="rounded-full bg-[#071110] px-5 py-2.5 text-sm font-semibold text-white">
                新建活动
              </Link>
            </div>
          </div>

          <form
            onSubmit={handleSearchSubmit}
            className="admin-reference-soft-card grid gap-3 p-4 md:grid-cols-2 xl:grid-cols-[minmax(200px,1.35fr)_116px_116px_116px_140px_86px_86px]"
          >
            <label className="flex items-center gap-3 rounded-full bg-white px-4 py-3">
              <Search className="h-4 w-4 text-black/35" />
              <input
                value={searchInput}
                onChange={(event) => setSearchInput(event.target.value)}
                placeholder="搜索活动名、主办方、城市"
                className="w-full border-0 bg-transparent px-0 py-0 text-sm shadow-none focus:shadow-none"
              />
            </label>

            <label className="flex items-center gap-3 rounded-full bg-white px-4 py-3">
              <span className="text-xs font-semibold uppercase tracking-[0.14em] text-black/35">状态</span>
              <select
                value={status}
                onChange={(event) => {
                  setStatus(event.target.value);
                  setPage(1);
                }}
                className="w-full border-0 bg-transparent px-0 py-0 text-sm shadow-none focus:shadow-none"
              >
                <option value="all">全部状态</option>
                <option value="upcoming">即将开始</option>
                <option value="ongoing">进行中</option>
                <option value="ended">已结束</option>
                <option value="cancelled">已取消</option>
              </select>
            </label>

            <label className="flex items-center gap-3 rounded-full bg-white px-4 py-3">
              <span className="text-xs font-semibold uppercase tracking-[0.14em] text-black/35">类型</span>
              <select
                value={eventType}
                onChange={(event) => {
                  setEventType(event.target.value);
                  setPage(1);
                }}
                className="w-full border-0 bg-transparent px-0 py-0 text-sm shadow-none focus:shadow-none"
              >
                <option value="all">全部类型</option>
                <option value="电音节">电音节</option>
                <option value="酒吧活动">酒吧活动</option>
                <option value="露天活动">露天活动</option>
                <option value="俱乐部派对">俱乐部派对</option>
                <option value="仓库派对">仓库派对</option>
                <option value="巡演专场">巡演专场</option>
                <option value="其他">其他</option>
              </select>
            </label>

            <label className="flex items-center gap-3 rounded-full bg-white px-4 py-3">
              <MapPin className="h-4 w-4 text-black/35" />
              <input
                value={cityInput}
                onChange={(event) => setCityInput(event.target.value)}
                placeholder="城市"
                className="w-full border-0 bg-transparent px-0 py-0 text-sm shadow-none focus:shadow-none"
              />
            </label>

            <label className="flex items-center gap-3 rounded-full bg-white px-4 py-3">
              <SlidersHorizontal className="h-4 w-4 text-black/35" />
              <input
                value={countryInput}
                onChange={(event) => setCountryInput(event.target.value)}
                placeholder="国家 / 地区"
                className="w-full border-0 bg-transparent px-0 py-0 text-sm shadow-none focus:shadow-none"
              />
            </label>

            <button type="submit" className="rounded-full bg-[#071110] px-4 py-3 text-sm font-semibold text-white">
              搜索
            </button>

            <button
              type="button"
              onClick={handleReset}
              className="rounded-full border border-[#e8eceb] bg-white px-4 py-3 text-sm font-semibold text-[#071110]"
            >
              重置
            </button>
          </form>

          <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-5">
            {[
              {
                label: '全部活动',
                value: pagination.total,
                note: `第 ${pagination.page} / ${pagination.totalPages} 页`,
                tone: 'admin-studio-pastel-mint',
              },
              {
                label: 'Live',
                value: statusCounts.ongoing,
                note: '当前进行中的活动',
                tone: 'admin-reference-soft-card',
              },
              {
                label: '/v1',
                value: statusCounts.upcoming,
                note: '即将开始的活动',
                tone: 'admin-reference-soft-card',
              },
              {
                label: 'Ready',
                value: statusCounts.verified,
                note: '已验证活动',
                tone: 'admin-reference-soft-card',
              },
              {
                label: 'Draft',
                value: statusCounts.draft,
                note: '待完善或待验证',
                tone: 'admin-reference-soft-card',
              },
            ].map((item) => (
              <div key={item.label} className={`${item.tone} px-5 py-4`}>
                <div className="text-xs font-semibold uppercase tracking-[0.14em] text-black/35">{item.label}</div>
                <div className="mt-3 text-[28px] font-semibold tracking-[-0.04em] text-[#071110]">
                  {item.value.toLocaleString()}
                </div>
                <div className="mt-1 text-sm text-black/46">{item.note}</div>
              </div>
            ))}
          </div>

          {selectedIds.length ? (
            <section className="admin-reference-soft-card space-y-4 p-4">
              <div className="flex flex-col gap-3 xl:flex-row xl:items-center xl:justify-between">
                <div className="flex flex-wrap items-center gap-3 text-sm text-black/56">
                  <span className="rounded-full bg-white px-4 py-2 font-semibold text-[#071110]">
                    已选中 {selectedIds.length} 条活动
                  </span>
                  {bulkNotice ? <span className="text-[#2f4027]">{bulkNotice}</span> : null}
                </div>

                <div className="flex flex-wrap gap-3">
                  <button
                    type="button"
                    onClick={() => void handleBulkCopy('ids')}
                    className="inline-flex items-center gap-2 rounded-full border border-[#e8eceb] bg-white px-4 py-2.5 text-sm font-semibold text-[#071110]"
                  >
                    <Copy className="h-4 w-4" />
                    <span>复制 ID</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => void handleBulkCopy('links')}
                    className="inline-flex items-center gap-2 rounded-full border border-[#e8eceb] bg-white px-4 py-2.5 text-sm font-semibold text-[#071110]"
                  >
                    <Link2 className="h-4 w-4" />
                    <span>复制链接</span>
                  </button>
                  {bulkEditHref ? (
                    <Link
                      href={bulkEditHref}
                      className="inline-flex items-center gap-2 rounded-full bg-[#071110] px-4 py-2.5 text-sm font-semibold text-white"
                    >
                      <CheckCheck className="h-4 w-4" />
                      <span>编辑活动</span>
                    </Link>
                  ) : null}
                </div>
              </div>

              <details className="rounded-[22px] border border-[#e8eceb] bg-white px-4 py-4">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-3 text-sm font-semibold text-[#071110]">
                  <span>更多批量操作</span>
                  <Ellipsis className="h-4 w-4 text-black/38" />
                </summary>

                <div className="mt-4 grid gap-4 xl:grid-cols-[minmax(0,1fr)_auto_auto]">
                  <div>
                    <label className="flex items-center gap-3 rounded-full border border-[#e8eceb] bg-[#f8f9f8] px-4 py-3">
                      <UserRoundPlus className="h-4 w-4 text-black/35" />
                      <input
                        value={organizerQuery}
                        onChange={(event) => setOrganizerQuery(event.target.value)}
                        placeholder="搜索并批量指定主办方"
                        className="w-full border-0 bg-transparent px-0 py-0 text-sm shadow-none focus:shadow-none"
                      />
                    </label>

                    {selectedOrganizer ? (
                      <div className="mt-3 rounded-full border border-[#dceabf] bg-[#edf7f2] px-4 py-2.5 text-sm text-[#2f4027]">
                        当前主办方：{selectedOrganizer.name}
                      </div>
                    ) : null}

                    {organizerQuery.trim() ? (
                      <div className="mt-3 space-y-2 rounded-[20px] border border-[#e8eceb] bg-[#f8f9f8] p-3">
                        {isSearchingOrganizers ? (
                          <div className="text-sm text-black/48">主办方搜索中…</div>
                        ) : organizerResults.length ? (
                          organizerResults.slice(0, 5).map((item) => (
                            <button
                              key={item.id}
                              type="button"
                              onClick={() => {
                                setSelectedOrganizer(item);
                                setOrganizerQuery(item.name);
                                setOrganizerResults([]);
                              }}
                              className="block w-full rounded-[18px] border border-[#e8eceb] bg-white px-4 py-3 text-left"
                            >
                              <div className="text-sm font-semibold text-[#071110]">{item.name}</div>
                              <div className="mt-1 text-xs text-black/42">
                                {[item.country, item.city, item.tagline].filter(Boolean).join(' · ') || item.id}
                              </div>
                            </button>
                          ))
                        ) : (
                          <div className="text-sm text-black/48">没有匹配的主办方结果。</div>
                        )}
                      </div>
                    ) : null}
                  </div>

                  <button
                    type="button"
                    onClick={() => void handleBulkBindOrganizer()}
                    disabled={!selectedItems.length || !selectedOrganizer || isApplyingBulkBinding}
                    className="inline-flex items-center justify-center gap-2 rounded-full bg-[#071110] px-4 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-40"
                  >
                    <UserRoundPlus className="h-4 w-4" />
                    <span>{isApplyingBulkBinding ? '执行中...' : '批量指定主办方'}</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => void handleBulkClearOrganizer()}
                    disabled={!selectedItems.length || isApplyingBulkBinding}
                    className="inline-flex items-center justify-center gap-2 rounded-full border border-[#e8eceb] bg-white px-4 py-3 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
                  >
                    <XCircle className="h-4 w-4" />
                    <span>{isApplyingBulkBinding ? '执行中...' : '清空主办方'}</span>
                  </button>
                </div>
              </details>
            </section>
          ) : null}

          {error ? (
            <div className="rounded-[20px] border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-[#7a2d29]">
              {error}
            </div>
          ) : null}

          <section className="space-y-3">
            {isLoading ? (
              <div className="admin-reference-soft-card py-20 text-center text-sm text-black/48">活动目录加载中…</div>
            ) : items.length === 0 ? (
              <div className="admin-reference-soft-card py-20 text-center text-sm text-black/48">
                当前筛选条件下还没有活动。
              </div>
            ) : (
              items.map((item) => (
                <article
                  key={item.id}
                  className="admin-reference-soft-card grid gap-4 overflow-hidden p-4 lg:grid-cols-[180px_minmax(0,1fr)_236px]"
                >
                  <div className="relative overflow-hidden rounded-[22px] border border-[#e8eceb] bg-white">
                    {item.coverImageUrl ? (
                      <Image
                        src={item.coverImageUrl}
                        alt={item.name}
                        width={320}
                        height={220}
                        className="h-full min-h-[136px] w-full object-cover"
                      />
                    ) : (
                      <div className="flex h-full min-h-[136px] items-center justify-center bg-[linear-gradient(135deg,#f7efda,#edf7f2)] text-sm text-black/42">
                        暂无封面
                      </div>
                    )}

                    <button
                      type="button"
                      onClick={() => toggleItemSelection(item.id)}
                      className={`absolute left-3 top-3 rounded-full px-3 py-1.5 text-xs font-semibold ${
                        selectedIdSet.has(item.id)
                          ? 'bg-[#071110] text-white'
                          : 'border border-[#e8eceb] bg-white/92 text-[#071110]'
                      }`}
                    >
                      {selectedIdSet.has(item.id) ? '已选中' : '选择'}
                    </button>
                  </div>

                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className={`rounded-full border px-3 py-1 text-xs font-semibold ${resolveEventTone(item.status)}`}>
                        {resolveEventStatusLabel(item.status)}
                      </span>
                      {item.eventType ? <span className="admin-reference-chip">{item.eventType}</span> : null}
                      {item.timeZone ? (
                        <span className="rounded-full border border-[#e8eceb] bg-white px-3 py-1 text-xs font-semibold text-black/55">
                          {item.timeZone}
                        </span>
                      ) : null}
                      {item.isVerified ? (
                        <span className="rounded-full border border-[#dceabf] bg-[#eef8d8] px-3 py-1 text-xs font-semibold text-[#2f4027]">
                          Ready
                        </span>
                      ) : null}
                    </div>

                    <h3 className="mt-4 truncate text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">
                      {item.name}
                    </h3>

                    <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-2 text-sm text-black/48">
                      <span>
                        {item.wikiFestival?.name || item.organizerName || '未绑定正式主办方'}
                      </span>
                      <span>
                        {[item.city, item.country].filter(Boolean).join(', ') || '地点待补充'}
                      </span>
                    </div>

                    <div className="mt-4 grid gap-3 md:grid-cols-3">
                      <div className="rounded-[20px] border border-[#e8eceb] bg-white px-4 py-3">
                        <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.14em] text-black/35">
                          <CalendarRange className="h-4 w-4" />
                          <span>活动日期</span>
                        </div>
                        <div className="mt-2 text-sm font-semibold text-[#071110]">{formatDateRange(item)}</div>
                      </div>

                      <div className="rounded-[20px] border border-[#e8eceb] bg-white px-4 py-3">
                        <div className="text-xs font-semibold uppercase tracking-[0.14em] text-black/35">
                          活动状态
                        </div>
                        <div className="mt-2 text-sm font-semibold text-[#071110]">
                          {resolveEventStatusSummary(item.status)}
                        </div>
                      </div>

                      <div className="rounded-[20px] border border-[#e8eceb] bg-white px-4 py-3">
                        <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.14em] text-black/35">
                          <Clock3 className="h-4 w-4" />
                          <span>最近更新</span>
                        </div>
                        <div className="mt-2 text-sm font-semibold text-[#071110]">{formatDateTime(item.updatedAt)}</div>
                      </div>
                    </div>
                  </div>

                  <div className="flex flex-col justify-between gap-4 rounded-[22px] border border-[#e8eceb] bg-white p-4">
                    <div className="space-y-3 text-sm text-black/48">
                      <div>
                        <div className="text-xs font-semibold uppercase tracking-[0.14em] text-black/35">Event Days</div>
                        <div className="mt-1 text-[18px] font-semibold text-[#071110]">
                          {item.eventDays?.length ?? 0} 天
                        </div>
                      </div>
                      <div>
                        <div className="text-xs font-semibold uppercase tracking-[0.14em] text-black/35">时区</div>
                        <div className="mt-1 text-sm font-semibold text-[#071110]">{item.timeZone || '未记录'}</div>
                      </div>
                    </div>

                    <div className="grid gap-3">
                      <Link
                        href={`/events/${item.id}`}
                        className="rounded-full border border-[#e8eceb] bg-[#f8f9f8] px-4 py-3 text-center text-sm font-semibold text-[#071110]"
                      >
                        查看详情
                      </Link>
                      <Link
                        href={`/admin/content/events/${item.id}/edit`}
                        className="rounded-full bg-[#071110] px-4 py-3 text-center text-sm font-semibold text-white"
                      >
                        编辑活动
                      </Link>

                      <details className="relative">
                        <summary className="flex cursor-pointer list-none items-center justify-center rounded-full border border-[#e8eceb] bg-white px-4 py-3 text-sm font-semibold text-[#071110]">
                          <Ellipsis className="h-4 w-4" />
                        </summary>
                        <div className="absolute right-0 top-[calc(100%+10px)] z-20 grid min-w-[180px] gap-2 rounded-[20px] border border-[#e8eceb] bg-white p-3 shadow-[0_18px_42px_rgba(33,52,47,0.12)]">
                          <button
                            type="button"
                            onClick={() => toggleItemSelection(item.id)}
                            className="rounded-full bg-[#f8f9f8] px-4 py-2 text-left text-sm font-semibold text-[#071110]"
                          >
                            {selectedIdSet.has(item.id) ? '取消选中' : '选中活动'}
                          </button>
                          <button
                            type="button"
                            onClick={() => void handleCopySingleId(item.id)}
                            className="rounded-full bg-[#f8f9f8] px-4 py-2 text-left text-sm font-semibold text-[#071110]"
                          >
                            复制活动 ID
                          </button>
                        </div>
                      </details>
                    </div>
                  </div>
                </article>
              ))
            )}
          </section>

          <div className="flex flex-col gap-4 border-t border-[#ecefed] pt-5 xl:flex-row xl:items-center xl:justify-between">
            <div className="text-sm text-black/48">
              共 {pagination.total.toLocaleString()} 条活动，当前显示第{' '}
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
                  className="inline-flex h-10 w-10 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
                >
                  <ChevronLeft className="h-4 w-4" />
                </button>

                {visiblePages.map((pageNumber) => (
                  <button
                    key={pageNumber}
                    type="button"
                    onClick={() => setPage(pageNumber)}
                    className={`h-10 min-w-10 rounded-full px-3 text-sm font-semibold ${
                      pageNumber === pagination.page
                        ? 'bg-[#071110] text-white'
                        : 'border border-[#e8eceb] bg-white text-[#071110]'
                    }`}
                  >
                    {pageNumber}
                  </button>
                ))}

                <button
                  type="button"
                  disabled={pagination.page >= pagination.totalPages}
                  onClick={() => setPage((current) => Math.min(pagination.totalPages, current + 1))}
                  className="inline-flex h-10 w-10 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
                >
                  <ChevronRight className="h-4 w-4" />
                </button>
              </div>

              <div className="rounded-full border border-[#e8eceb] bg-white px-4 py-2.5 text-sm text-black/48">
                每页 {pagination.limit} 条
              </div>
            </div>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
