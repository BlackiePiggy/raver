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
    };

    items.forEach((item) => {
      if (item.status === 'ongoing') counts.ongoing += 1;
      else if (item.status === 'ended') counts.ended += 1;
      else if (item.status === 'cancelled' || item.status === 'canceled') counts.cancelled += 1;
      else counts.upcoming += 1;

      if (item.isVerified) counts.verified += 1;
    });

    return counts;
  }, [items]);

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

  return (
    <AdminContentLayout
      title="活动目录中心"
      eyebrow="Admin / Content Workspace / Event Catalog"
      description="统一查看活动目录、活动摘要、编辑入口与详情入口。目录层默认读取分页摘要与本地快照，进入编辑或详情时再加载更深的数据。"
      actions={
        <>
          <Link href="/admin/content/events" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            返回活动工作区
          </Link>
          <button
            type="button"
            onClick={handleRefresh}
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            手动刷新目录
          </button>
          <Link href="/admin/content/events/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            新建活动
          </Link>
        </>
      }
    >
      <section className="grid gap-5 xl:grid-cols-[1.4fr_0.9fr]">
        <div className="admin-reference-card p-6">
          <div className="text-[11px] uppercase tracking-[0.18em] text-black/35">Catalog Strategy</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">目录层优先轻量定位</h2>
          <div className="mt-5 grid gap-3 md:grid-cols-3">
            {[
              {
                title: '分页摘要',
                body: `单页固定 ${PAGE_SIZE} 条摘要，避免一次拉全量活动。`,
                tone: 'bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)]',
              },
              {
                title: '本地快照',
                body: '优先读取 10 分钟本地快照，陈旧时再后台静默刷新。',
                tone: 'bg-[linear-gradient(180deg,#f7efda_0%,#ffffff_100%)]',
              },
              {
                title: '深层数据',
                body: '只在进入详情或编辑时请求重数据，目录层保持轻量。',
                tone: 'bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)]',
              },
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
            <p>摘要总量：{pagination.total.toLocaleString()} 条</p>
            <p>最新快照：{cacheMeta ? formatDateTime(cacheMeta.fetchedAt) : '尚未生成'}</p>
            <p>刷新方式：{cacheMeta?.source === 'cache' ? '缓存命中' : '后台摘要刷新'}</p>
            <p>快照状态：{cacheMeta?.isStale ? '已陈旧，后台会自动补刷新' : '新鲜可用'}</p>
          </div>
        </div>
      </section>

      <section className="admin-reference-card p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <form onSubmit={handleSearchSubmit} className="grid flex-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
            <label className="space-y-2 xl:col-span-2">
              <span className="text-xs uppercase tracking-[0.2em] text-black/35">搜索关键词</span>
              <input
                value={searchInput}
                onChange={(event) => setSearchInput(event.target.value)}
                placeholder="活动名 / 城市 / 主办方"
                className="w-full rounded-full px-4 py-3 text-sm"
              />
            </label>
            <label className="space-y-2">
              <span className="text-xs uppercase tracking-[0.2em] text-black/35">活动状态</span>
              <select
                value={status}
                onChange={(event) => {
                  setStatus(event.target.value);
                  setPage(1);
                }}
                className="w-full rounded-full px-4 py-3 text-sm"
              >
                <option value="all">全部状态</option>
                <option value="upcoming">即将开始</option>
                <option value="ongoing">进行中</option>
                <option value="ended">已结束</option>
                <option value="cancelled">已取消</option>
              </select>
            </label>
            <label className="space-y-2">
              <span className="text-xs uppercase tracking-[0.2em] text-black/35">城市</span>
              <input
                value={cityInput}
                onChange={(event) => setCityInput(event.target.value)}
                placeholder="Shanghai"
                className="w-full rounded-full px-4 py-3 text-sm"
              />
            </label>
            <label className="space-y-2 xl:col-span-2">
              <span className="text-xs uppercase tracking-[0.2em] text-black/35">国家 / 类型</span>
              <div className="grid gap-3 md:grid-cols-2">
                <input
                  value={countryInput}
                  onChange={(event) => setCountryInput(event.target.value)}
                  placeholder="China"
                  className="w-full rounded-full px-4 py-3 text-sm"
                />
                <select
                  value={eventType}
                  onChange={(event) => {
                    setEventType(event.target.value);
                    setPage(1);
                  }}
                  className="w-full rounded-full px-4 py-3 text-sm"
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
              </div>
            </label>
            <button type="submit" className="min-w-[140px] rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
              搜索目录
            </button>
            <button
              type="button"
              onClick={handleReset}
              className="min-w-[140px] rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
            >
              清空筛选
            </button>
          </form>

          <div className="admin-reference-soft-card px-4 py-3 text-sm text-black/50">
            {isRefreshing ? '检测到缓存陈旧，正在后台更新当前页目录…' : '目录层默认采用 stale-while-revalidate 方式减轻请求压力。'}
          </div>
        </div>
      </section>

      <section className="admin-reference-card p-6">
        <div>
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <div className="text-[11px] uppercase tracking-[0.18em] text-black/35">Page Summary</div>
              <h2 className="mt-2 text-[20px] font-semibold tracking-[-0.03em] text-[#071110]">当前页管理概览</h2>
            </div>
            <button
              type="button"
              onClick={toggleSelectAllCurrentPage}
              disabled={!items.length}
              className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
            >
              {allCurrentPageSelected ? '取消全选当前页' : '全选当前页'}
            </button>
          </div>

          <div className="mt-5 grid gap-3 md:grid-cols-5">
            {[
              { label: '即将开始', value: statusCounts.upcoming, tone: 'bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)]' },
              { label: '进行中', value: statusCounts.ongoing, tone: 'bg-[linear-gradient(180deg,#f7efda_0%,#ffffff_100%)]' },
              { label: '已结束', value: statusCounts.ended, tone: 'bg-[linear-gradient(180deg,#f5f5f7_0%,#ffffff_100%)]' },
              { label: '已取消', value: statusCounts.cancelled, tone: 'bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)]' },
              { label: '已验证', value: statusCounts.verified, tone: 'bg-[linear-gradient(180deg,#eef3fb_0%,#ffffff_100%)]' },
            ].map((item) => (
              <div key={item.label} className={`admin-reference-pastel-card p-4 text-sm ${item.tone}`}>
                <div className="text-black/42">{item.label}</div>
                <div className="mt-2 font-mono text-[24px] font-semibold text-[#071110]">{item.value}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="admin-reference-dark-card p-6">
        <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
          <div>
            <div className="text-[11px] uppercase tracking-[0.18em] text-white/45">Bulk Actions</div>
            <h2 className="mt-2 text-[20px] font-semibold tracking-[-0.03em] text-white">批量管理</h2>
            <div className="mt-4 space-y-3 text-sm leading-6 text-white/65">
              <p>已选中 {selectedItems.length} 条活动，可复制活动 ID、活动名称或详情链接。</p>
              <p>当前也支持直接批量指定主办方或批量清空主办方绑定，沿用统一后台已验证的绑定链路。</p>
            </div>
            <div className="mt-5 space-y-3">
              <label className="space-y-2">
                <span className="text-xs uppercase tracking-[0.18em] text-white/45">批量指定主办方</span>
                <input
                  value={organizerQuery}
                  onChange={(event) => setOrganizerQuery(event.target.value)}
                  placeholder="搜索主办方名称"
                  className="w-full rounded-full border border-white/10 bg-white/8 px-4 py-3 text-sm text-white placeholder:text-white/45"
                />
              </label>

              {selectedOrganizer ? (
                <div className="rounded-[18px] border border-white/10 bg-white/8 px-4 py-3 text-sm text-white/78">
                  当前选中主办方：{selectedOrganizer.name}
                </div>
              ) : null}

              {organizerQuery.trim() ? (
                <div className="rounded-[18px] border border-white/10 bg-white/8 p-3">
                  {isSearchingOrganizers ? (
                    <div className="text-sm text-white/55">主办方搜索中…</div>
                  ) : organizerResults.length ? (
                    <div className="space-y-2">
                      {organizerResults.slice(0, 5).map((item) => (
                        <button
                          key={item.id}
                          type="button"
                          onClick={() => {
                            setSelectedOrganizer(item);
                            setOrganizerQuery(item.name);
                            setOrganizerResults([]);
                          }}
                          className="block w-full rounded-[18px] border border-white/10 bg-white/6 px-4 py-3 text-left"
                        >
                          <div className="text-sm font-semibold text-white">{item.name}</div>
                          <div className="mt-1 text-xs text-white/45">
                            {[item.country, item.city, item.tagline].filter(Boolean).join(' · ') || item.id}
                          </div>
                        </button>
                      ))}
                    </div>
                  ) : (
                    <div className="text-sm text-white/55">没有匹配的主办方结果。</div>
                  )}
                </div>
              ) : null}
            </div>
          </div>

          <div className="grid gap-3 md:grid-cols-2">
            <button
              type="button"
              onClick={() => void handleBulkCopy('ids')}
              disabled={!selectedItems.length}
              className="rounded-full border border-white/10 bg-white/8 px-4 py-3 text-left text-sm text-white disabled:cursor-not-allowed disabled:opacity-40"
            >
              复制选中活动 ID
            </button>
            <button
              type="button"
              onClick={() => void handleBulkCopy('names')}
              disabled={!selectedItems.length}
              className="rounded-full border border-white/10 bg-white/8 px-4 py-3 text-left text-sm text-white disabled:cursor-not-allowed disabled:opacity-40"
            >
              复制选中活动名称
            </button>
            <button
              type="button"
              onClick={() => void handleBulkCopy('links')}
              disabled={!selectedItems.length}
              className="rounded-full border border-white/10 bg-white/8 px-4 py-3 text-left text-sm text-white disabled:cursor-not-allowed disabled:opacity-40"
            >
              复制选中活动详情链接
            </button>
            <button
              type="button"
              onClick={() => void handleBulkBindOrganizer()}
              disabled={!selectedItems.length || !selectedOrganizer || isApplyingBulkBinding}
              className="rounded-full bg-white px-4 py-3 text-left text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
            >
              {isApplyingBulkBinding ? '执行中...' : '批量指定主办方'}
            </button>
            <button
              type="button"
              onClick={() => void handleBulkClearOrganizer()}
              disabled={!selectedItems.length || isApplyingBulkBinding}
              className="rounded-full border border-white/10 bg-white/8 px-4 py-3 text-left text-sm text-white disabled:cursor-not-allowed disabled:opacity-40"
            >
              {isApplyingBulkBinding ? '执行中...' : '批量清空主办方'}
            </button>
            {bulkEditHref ? (
              <Link href={bulkEditHref} className="rounded-full bg-white px-4 py-3 text-center text-sm font-semibold text-[#071110]">
                进入选中活动编辑
              </Link>
            ) : (
              <div className="rounded-[18px] border border-white/10 bg-white/8 px-4 py-3 text-sm text-white/45">
                选中单条活动后可一跳进入编辑
              </div>
            )}
            {bulkNotice ? <div className="md:col-span-2 text-sm text-white/78">{bulkNotice}</div> : null}
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
          <div className="py-20 text-center text-sm text-text-secondary">活动目录加载中…</div>
        ) : items.length === 0 ? (
          <div className="py-20 text-center text-sm text-text-secondary">当前筛选条件下还没有活动摘要。</div>
        ) : (
          <div className="space-y-4">
            {items.map((item) => (
              <div
                key={item.id}
                className="grid gap-4 rounded-[28px] border border-[#e8eceb] bg-[#fcfcfb] p-5 lg:grid-cols-[172px_minmax(0,1fr)_230px]"
              >
                <div className="relative overflow-hidden rounded-[22px] border border-[#e8eceb] bg-[#f5f5f7]">
                  <button
                    type="button"
                    onClick={() => toggleItemSelection(item.id)}
                    className={`absolute left-3 top-3 z-10 rounded-full border px-3 py-1 text-xs font-semibold ${
                      selectedIdSet.has(item.id)
                        ? 'border-[#071110] bg-[#071110] text-white'
                        : 'border-[#e8eceb] bg-white/92 text-[#071110]'
                    }`}
                  >
                    {selectedIdSet.has(item.id) ? '已选' : '选择'}
                  </button>
                  {item.coverImageUrl ? (
                    <Image
                      src={item.coverImageUrl}
                      alt={item.name}
                      width={320}
                      height={200}
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <div className="flex h-full min-h-[120px] items-center justify-center bg-[linear-gradient(135deg,#f7efda,#edf7f2)] text-sm text-black/45">
                      暂无封面
                    </div>
                  )}
                </div>

                <div>
                  <div className="flex flex-wrap items-center gap-2">
                    <span className={`rounded-full border px-3 py-1 text-xs ${resolveEventTone(item.status)}`}>
                      {item.status || 'upcoming'}
                    </span>
                    <span className="admin-reference-chip">
                      {item.eventType || '未标记类型'}
                    </span>
                    {item.isVerified ? (
                      <span className="rounded-full border border-[#dceabf] bg-[#eef8d8] px-3 py-1 text-xs font-semibold text-[#2f4027]">
                        已验证
                      </span>
                    ) : null}
                  </div>

                  <h3 className="mt-3 text-2xl font-semibold text-[#071110]">{item.name}</h3>
                  <p className="mt-2 text-sm leading-6 text-black/52">
                    {item.wikiFestival?.name || item.organizerName || '未绑定正式主办方'} · {item.city || '未知城市'} / {item.country || '未知国家'}
                  </p>

                  <div className="mt-4 grid gap-3 md:grid-cols-4">
                    <div className="admin-reference-soft-card px-4 py-3 text-sm">
                      <div className="text-black/42">活动日期</div>
                      <div className="mt-1 font-semibold text-[#071110]">{formatDateRange(item)}</div>
                    </div>
                    <div className="admin-reference-soft-card px-4 py-3 text-sm">
                      <div className="text-black/42">演出天数</div>
                      <div className="mt-1 font-semibold text-[#071110]">{item.eventDays?.length ?? 0} 天</div>
                    </div>
                    <div className="admin-reference-soft-card px-4 py-3 text-sm">
                      <div className="text-black/42">最近更新</div>
                      <div className="mt-1 font-semibold text-[#071110]">{formatDateTime(item.updatedAt)}</div>
                    </div>
                    <div className="admin-reference-soft-card px-4 py-3 text-sm">
                      <div className="text-black/42">时区</div>
                      <div className="mt-1 font-semibold text-[#071110]">{item.timeZone || '未记录'}</div>
                    </div>
                  </div>
                </div>

                <div className="admin-reference-dark-card flex flex-col justify-between gap-3 p-4">
                  <div className="text-sm leading-6 text-white/65">
                    目录层只看摘要，编辑时再进入详情页拉取完整资料，避免列表态反复命中重查询。
                  </div>
                  <div className="grid gap-3">
                    <Link href={`/admin/content/events/${item.id}/edit`} className="rounded-full bg-white px-4 py-3 text-center text-sm font-semibold text-[#071110]">
                      编辑活动
                    </Link>
                    <Link href={`/events/${item.id}`} className="rounded-full border border-white/10 bg-white/8 px-4 py-3 text-center text-sm text-white">
                      打开活动详情
                    </Link>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        <div className="mt-6 flex flex-col gap-3 border-t border-white/5 pt-6 sm:flex-row sm:items-center sm:justify-between">
          <div className="text-sm text-black/48">
            共 {pagination.total.toLocaleString()} 条摘要，当前显示第 {(pagination.page - 1) * pagination.limit + 1} - {Math.min(pagination.page * pagination.limit, pagination.total)} 条
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
            { title: '摘要加载', body: '活动目录保持低频摘要加载，适合集中查看与快速进入编辑。', tone: 'bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)]' },
            { title: '深层资料', body: '活动详情和深层资料只在真正进入详情或编辑时再拉取完整数据。', tone: 'bg-[linear-gradient(180deg,#f7efda_0%,#ffffff_100%)]' },
            { title: '外围能力', body: '活动绑定、Archive 与其他补充能力继续通过统一后台分区进入。', tone: 'bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)]' },
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
