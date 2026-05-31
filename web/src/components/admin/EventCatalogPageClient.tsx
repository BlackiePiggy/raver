'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  CalendarDays,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Ellipsis,
  List,
  Search,
  SlidersHorizontal,
  Upload,
  Users2,
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
  readAdminCatalogCache,
  writeAdminCatalogCache,
} from '@/features/admin-content/catalog/cache';

const PAGE_SIZE = 10;
const CACHE_TTL_MS = 10 * 60 * 1000;

const EMPTY_PAGINATION: AdminCatalogPagination = {
  page: 1,
  limit: PAGE_SIZE,
  total: 0,
  totalPages: 1,
};

const formatDateRange = (item: EventCatalogItem): string => {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
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

const resolveEventStatus = (
  item: EventCatalogItem
): { label: string; dot: string; badgeTone: string; metricLabel: string } => {
  if (item.isVerified) {
    return {
      label: 'Ready',
      dot: 'bg-[#ff4f7a]',
      badgeTone: 'bg-[#f7f0f4] text-[#4b505b]',
      metricLabel: 'Ready',
    };
  }
  if (item.status === 'ongoing') {
    return {
      label: 'Live',
      dot: 'bg-[#22c55e]',
      badgeTone: 'bg-[#f5f6f8] text-[#4b505b]',
      metricLabel: 'Live',
    };
  }
  if (item.status === 'upcoming') {
    return {
      label: '/v1',
      dot: 'bg-[#ffbe2e]',
      badgeTone: 'bg-[#f5f6f8] text-[#4b505b]',
      metricLabel: '/v1',
    };
  }
  return {
    label: 'Draft',
    dot: 'bg-[#4a86f7]',
    badgeTone: 'bg-[#f5f6f8] text-[#4b505b]',
    metricLabel: 'Draft',
  };
};

const formatLocation = (item: EventCatalogItem): string =>
  [item.city, item.country].filter(Boolean).join(', ') || '地点待补充';

function StatCard({
  label,
  value,
  icon,
  dotClassName,
}: {
  label: string;
  value: number;
  icon?: JSX.Element;
  dotClassName?: string;
}) {
  return (
    <div className="rounded-[24px] border border-[#ebeef2] bg-white px-6 py-5 shadow-[0_2px_10px_rgba(15,23,42,0.03)]">
      <div className="flex items-center gap-3">
        {icon ? (
          <div className="flex h-12 w-12 items-center justify-center rounded-[16px] bg-[#eefaf1] text-[#22c55e]">
            {icon}
          </div>
        ) : (
          <span className={`h-3.5 w-3.5 rounded-full ${dotClassName || 'bg-[#22c55e]'}`} />
        )}
        <div className="text-[15px] font-semibold leading-none text-[#111827]">{label}</div>
      </div>
      <div className="mt-5 flex items-end gap-1.5 text-[#111827]">
        <span className="text-[30px] font-semibold leading-none tracking-[-0.04em]">
          {value.toLocaleString()}
        </span>
        <span className="pb-0.5 text-[18px] leading-none text-[#b1b7c3]">个</span>
      </div>
    </div>
  );
}

export default function EventCatalogPageClient() {
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('all');
  const [eventType, setEventType] = useState('all');
  const [timezone, setTimezone] = useState('all');
  const [page, setPage] = useState(1);
  const [items, setItems] = useState<EventCatalogItem[]>([]);
  const [pagination, setPagination] = useState<AdminCatalogPagination>(EMPTY_PAGINATION);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  const filters = useMemo<EventCatalogFilters>(
    () => ({
      page,
      limit: PAGE_SIZE,
      search: search || undefined,
      status,
      city: undefined,
      country: timezone === 'all' ? undefined : timezone,
      eventType: eventType === 'all' ? undefined : eventType,
    }),
    [page, search, status, timezone, eventType]
  );

  const cacheKey = useMemo(
    () =>
      buildAdminCatalogCacheKey('events-catalog', {
        page,
        limit: PAGE_SIZE,
        search: search || undefined,
        status,
        city: undefined,
        country: timezone === 'all' ? undefined : timezone,
        eventType: eventType === 'all' ? undefined : eventType,
      }),
    [page, search, status, timezone, eventType]
  );

  const loadCatalog = useCallback(
    async (options?: { force?: boolean }) => {
      const cached = !options?.force ? readAdminCatalogCache<EventCatalogResponse>(cacheKey) : null;

      if (cached) {
        setItems(cached.data.items);
        setPagination(cached.data.pagination);
        setError('');
        setIsLoading(false);
        if (!cached.isStale) return;
      } else {
        setIsLoading(true);
      }

      try {
        const response = await adminCatalogApi.fetchEvents(filters);
        const written = writeAdminCatalogCache(cacheKey, response, CACHE_TTL_MS);
        setItems(response.items);
        setPagination(response.pagination);
        void written;
        setError('');
      } catch (nextError) {
        setError(nextError instanceof Error ? nextError.message : '活动目录加载失败');
      } finally {
        setIsLoading(false);
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

  const statusCounts = useMemo(() => {
    const counts = {
      live: 0,
      v1: 0,
      ready: 0,
      draft: 0,
    };

    items.forEach((item) => {
      const state = resolveEventStatus(item).metricLabel;
      if (state === 'Live') counts.live += 1;
      else if (state === '/v1') counts.v1 += 1;
      else if (state === 'Ready') counts.ready += 1;
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

  return (
    <AdminContentLayout
      title="活动目录"
      eyebrow=""
      description="统一查看与管理所有活动。快速筛选、搜索与操作。"
      actions={
        <>
          <Link
            href="/admin/content/events/new"
            className="inline-flex items-center gap-3 rounded-full border border-[#e8eceb] bg-white px-8 py-4 text-[15px] font-semibold text-[#111827] shadow-[0_4px_18px_rgba(17,24,39,0.04)]"
          >
            <Upload className="h-5 w-5" />
            <span>导入活动</span>
          </Link>
          <Link
            href="/admin/content/events/new"
            className="inline-flex items-center gap-3 rounded-full bg-[#071110] px-8 py-4 text-[15px] font-semibold text-white shadow-[0_12px_28px_rgba(7,17,16,0.18)]"
          >
            <span className="text-[24px] leading-none">+</span>
            <span>新建活动</span>
          </Link>
        </>
      }
    >
      <section className="space-y-6">
        <section className="rounded-[34px] border border-[#edf0f2] bg-white px-6 py-6 shadow-[0_8px_32px_rgba(17,24,39,0.04)]">
          <form
            onSubmit={handleSearchSubmit}
            className="flex flex-wrap gap-4"
          >
            <label className="flex h-[68px] min-w-[240px] flex-[1.45_1_320px] items-center gap-4 rounded-[22px] border border-[#eceff1] bg-white px-5 text-[#111827] shadow-[inset_0_1px_0_rgba(255,255,255,0.6)]">
              <input
                value={searchInput}
                onChange={(event) => setSearchInput(event.target.value)}
                placeholder="搜索活动名称、主办方、城市..."
                className="w-full border-0 bg-transparent px-0 py-0 text-[16px] font-medium text-[#111827] outline-none placeholder:text-[#9ca3af]"
              />
              <Search className="h-6 w-6 text-[#4b5563]" />
            </label>

            <label className="relative flex h-[68px] min-w-[170px] flex-1 items-center justify-between rounded-[22px] border border-[#eceff1] bg-white px-7 text-[15px] font-semibold text-[#111827]">
              <span>{status === 'all' ? '全部状态' : status}</span>
              <select
                value={status}
                onChange={(event) => {
                  setStatus(event.target.value);
                  setPage(1);
                }}
                className="absolute opacity-0"
              >
                <option value="all">全部状态</option>
                <option value="upcoming">Upcoming</option>
                <option value="ongoing">Live</option>
                <option value="ended">Ended</option>
                <option value="cancelled">Cancelled</option>
              </select>
              <ChevronDown className="h-5 w-5 text-[#6b7280]" />
            </label>

            <label className="relative flex h-[68px] min-w-[170px] flex-1 items-center justify-between rounded-[22px] border border-[#eceff1] bg-white px-7 text-[15px] font-semibold text-[#111827]">
              <span>{eventType === 'all' ? '全部类型' : eventType}</span>
              <select
                value={eventType}
                onChange={(event) => {
                  setEventType(event.target.value);
                  setPage(1);
                }}
                className="absolute opacity-0"
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
              <ChevronDown className="h-5 w-5 text-[#6b7280]" />
            </label>

            <label className="relative flex h-[68px] min-w-[170px] flex-1 items-center justify-between rounded-[22px] border border-[#eceff1] bg-white px-7 text-[15px] font-semibold text-[#111827]">
              <span>{timezone === 'all' ? '全部时区' : timezone}</span>
              <select
                value={timezone}
                onChange={(event) => {
                  setTimezone(event.target.value);
                  setPage(1);
                }}
                className="absolute opacity-0"
              >
                <option value="all">全部时区</option>
                <option value="Asia/Shanghai">Asia/Shanghai</option>
                <option value="Asia/Hong_Kong">Asia/Hong_Kong</option>
                <option value="America/Los_Angeles">America/Los_Angeles</option>
                <option value="Europe/Brussels">Europe/Brussels</option>
              </select>
              <ChevronDown className="h-5 w-5 text-[#6b7280]" />
            </label>

            <button
              type="button"
              className="flex h-[68px] min-w-[148px] items-center justify-center gap-3 rounded-[22px] border border-[#eceff1] bg-white px-6 text-[15px] font-semibold text-[#111827]"
            >
              <SlidersHorizontal className="h-5 w-5" />
              <span>更多筛选</span>
            </button>

            <label className="ml-auto flex h-[68px] min-w-[124px] items-center justify-between rounded-[22px] border border-[#eceff1] bg-white px-6 text-[15px] font-semibold text-[#111827]">
              <span>最新更新</span>
              <ChevronDown className="h-5 w-5 text-[#9ca3af]" />
            </label>
          </form>

          <div className="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-5">
            <StatCard
              label="全部活动"
              value={pagination.total}
              icon={<List className="h-8 w-8" strokeWidth={2.4} />}
            />
            <StatCard label="Live" value={statusCounts.live} dotClassName="bg-[#22c55e]" />
            <StatCard label="/v1" value={statusCounts.v1} dotClassName="bg-[#ffbe2e]" />
            <StatCard label="Ready" value={statusCounts.ready} dotClassName="bg-[#ff4f7a]" />
            <StatCard label="Draft" value={statusCounts.draft} dotClassName="bg-[#4a86f7]" />
          </div>
        </section>

        <section className="overflow-hidden rounded-[34px] border border-[#edf0f2] bg-white shadow-[0_8px_32px_rgba(17,24,39,0.04)]">
          {error ? (
            <div className="border-b border-red-200 bg-red-50 px-6 py-4 text-sm text-[#7a2d29]">{error}</div>
          ) : null}

          {isLoading ? (
            <div className="px-6 py-20 text-center text-sm text-[#6b7280]">活动目录加载中…</div>
          ) : items.length === 0 ? (
            <div className="px-6 py-20 text-center text-sm text-[#6b7280]">当前筛选条件下还没有活动。</div>
          ) : (
            <div>
              <div className="hidden border-b border-[#edf0f2] px-6 py-4 text-[12px] font-semibold uppercase tracking-[0.18em] text-[#9aa1ad] lg:grid lg:grid-cols-[minmax(0,1.8fr)_180px_220px]">
                <span>活动信息</span>
                <span>状态与更新时间</span>
                <span className="text-right">操作</span>
              </div>

              <div className="divide-y divide-[#edf0f2]">
              {items.map((item) => {
                const state = resolveEventStatus(item);
                return (
                  <article
                    key={item.id}
                    className="gap-5 px-6 py-6 lg:grid lg:grid-cols-[minmax(0,1.8fr)_180px_220px] lg:items-center"
                  >
                    <div className="flex min-w-0 gap-4">
                      <div className="h-[104px] w-[140px] shrink-0 overflow-hidden rounded-[20px] bg-[#f3f5f7]">
                        {item.coverImageUrl ? (
                          <Image
                            src={item.coverImageUrl}
                            alt={item.name}
                            width={140}
                            height={104}
                            className="h-full w-full object-cover"
                          />
                        ) : (
                          <div className="flex h-full items-center justify-center text-sm text-[#9ca3af]">暂无封面</div>
                        )}
                      </div>

                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2.5">
                          <span
                            className={`inline-flex items-center gap-2 rounded-full px-3.5 py-1.5 text-[13px] font-semibold ${state.badgeTone}`}
                          >
                            <span className={`h-3 w-3 rounded-full ${state.dot}`} />
                            <span>{state.label}</span>
                          </span>
                          <span className="text-[13px] font-medium text-[#a0a7b3]">
                            {item.timeZone || '未设置时区'}
                          </span>
                        </div>

                        <h2 className="mt-3 truncate text-[22px] font-semibold tracking-[-0.03em] text-[#111827]">
                          {item.name}
                        </h2>

                        <div className="mt-1 truncate text-[14px] font-medium text-[#6b7280]">
                          {item.wikiFestival?.name || item.organizerName || '未绑定主办方'} · {formatLocation(item)}
                        </div>

                        <div className="mt-3 flex flex-wrap items-center gap-x-6 gap-y-2 text-[14px] font-medium text-[#7d8592]">
                          <div className="flex items-center gap-2.5">
                            <CalendarDays className="h-4.5 w-4.5 text-[#a0a7b3]" />
                            <span>{formatDateRange(item)}</span>
                          </div>
                          <div className="flex items-center gap-2.5">
                            <Users2 className="h-4.5 w-4.5 text-[#a0a7b3]" />
                            <span>{item.eventDays?.length ?? 0} 天</span>
                          </div>
                        </div>
                      </div>
                    </div>

                    <div className="mt-4 space-y-2 lg:mt-0">
                      <div className="text-[13px] font-semibold uppercase tracking-[0.16em] text-[#a0a7b3]">
                        更新时间
                      </div>
                      <div className="text-[15px] font-medium text-[#111827]">
                        {formatDateTime(item.updatedAt)}
                      </div>
                    </div>

                    <div className="mt-4 flex flex-wrap items-center gap-3 lg:mt-0 lg:justify-end">
                      <Link
                        href={`/events/${item.id}`}
                        className="inline-flex h-[46px] items-center justify-center rounded-[16px] border border-[#e7ebef] bg-white px-5 text-[14px] font-semibold text-[#111827] transition hover:bg-[#f7f8fa]"
                      >
                        查看详情
                      </Link>
                      <Link
                        href={`/admin/content/events/${item.id}/edit`}
                        className="inline-flex h-[46px] items-center justify-center rounded-[16px] bg-[#071110] px-5 text-[14px] font-semibold text-white shadow-[0_8px_20px_rgba(7,17,16,0.15)]"
                      >
                        编辑活动
                      </Link>
                      <button
                        type="button"
                        className="inline-flex h-[46px] w-[46px] items-center justify-center rounded-[16px] border border-[#e7ebef] bg-white text-[#111827]"
                      >
                        <Ellipsis className="h-5 w-5" />
                      </button>
                    </div>
                  </article>
                );
              })}
              </div>
            </div>
          )}

          <div className="flex flex-col gap-4 border-t border-[#edf0f2] px-6 py-5 xl:flex-row xl:items-center xl:justify-between">
            <div className="text-[14px] font-medium text-[#6b7280]">
              共 {pagination.total.toLocaleString()} 条
            </div>

            <div className="flex items-center gap-3">
              <button
                type="button"
                disabled={pagination.page <= 1}
                onClick={() => setPage((current) => Math.max(1, current - 1))}
                className="inline-flex h-11 w-11 items-center justify-center rounded-full text-[#9ca3af] disabled:cursor-not-allowed disabled:opacity-40"
              >
                <ChevronLeft className="h-5 w-5" />
              </button>

              {visiblePages.map((pageNumber) => (
                <button
                  key={pageNumber}
                  type="button"
                  onClick={() => setPage(pageNumber)}
                  className={`inline-flex h-11 min-w-11 items-center justify-center rounded-[16px] px-4 text-[16px] font-semibold ${
                    pageNumber === pagination.page
                      ? 'bg-[#071110] text-white'
                      : 'text-[#111827]'
                  }`}
                >
                  {pageNumber}
                </button>
              ))}

              {pagination.totalPages > visiblePages[visiblePages.length - 1] ? (
                <>
                  <span className="px-1 text-[20px] text-[#9ca3af]">...</span>
                  <button
                    type="button"
                    onClick={() => setPage(pagination.totalPages)}
                    className="inline-flex h-11 min-w-11 items-center justify-center rounded-[16px] px-4 text-[16px] font-semibold text-[#111827]"
                  >
                    {pagination.totalPages}
                  </button>
                </>
              ) : null}

              <button
                type="button"
                disabled={pagination.page >= pagination.totalPages}
                onClick={() => setPage((current) => Math.min(pagination.totalPages, current + 1))}
                className="inline-flex h-11 w-11 items-center justify-center rounded-full text-[#111827] disabled:cursor-not-allowed disabled:opacity-40"
              >
                <ChevronRight className="h-5 w-5" />
              </button>
            </div>

            <div className="flex items-center gap-3 rounded-[16px] border border-[#e8ecef] bg-white px-5 py-3 text-[14px] font-semibold text-[#111827]">
              <span>{pagination.limit} 条/页</span>
              <ChevronDown className="h-5 w-5 text-[#6b7280]" />
            </div>
          </div>
        </section>
      </section>
    </AdminContentLayout>
  );
}
