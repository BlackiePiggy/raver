'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import {
  eventOrganizerBindingApi,
  EventOrganizerBindingCatalogItem,
} from '@/features/admin-content/event-organizer-binding/api';
import { EventStudioOrganizer } from '@/features/admin-content/event-studio/types';

const PAGE_SIZE = 24;

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

const formatDateRange = (startDate: string, endDate: string): string => {
  const formatter = new Intl.DateTimeFormat('zh-CN', {
    month: 'short',
    day: 'numeric',
  });
  return `${formatter.format(new Date(startDate))} - ${formatter.format(new Date(endDate))}`;
};

const buildUnboundClusterKey = (item: EventOrganizerBindingCatalogItem): string => {
  const organizerName = String(item.organizerName || '').trim();
  if (organizerName) return organizerName;

  const name = String(item.name || '').trim();
  if (!name) return '未命名活动';
  const normalized = name
    .replace(/\d{4}.*/g, '')
    .replace(/\([^)]*\)/g, '')
    .replace(/[^\p{L}\p{N}\u4e00-\u9fa5]+/gu, ' ')
    .trim();

  if (!normalized) return name;
  const tokens = normalized.split(/\s+/).filter(Boolean);
  return tokens.slice(0, 3).join(' ');
};

export default function EventOrganizerBindingPageClient() {
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('all');
  const [page, setPage] = useState(1);
  const [items, setItems] = useState<EventOrganizerBindingCatalogItem[]>([]);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [selectedEventId, setSelectedEventId] = useState<string | null>(null);
  const [selectedOrganizer, setSelectedOrganizer] = useState<EventStudioOrganizer | null>(null);
  const [selectedEventIds, setSelectedEventIds] = useState<string[]>([]);
  const [organizerQuery, setOrganizerQuery] = useState('');
  const [organizerResults, setOrganizerResults] = useState<EventStudioOrganizer[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSearchingOrganizers, setIsSearchingOrganizers] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [cacheMessage, setCacheMessage] = useState('目录摘要由服务端缓存层承接，适合低频绑定管理。');

  const selectedEvent = useMemo(
    () => items.find((item) => item.id === selectedEventId) ?? null,
    [items, selectedEventId]
  );
  const selectedEvents = useMemo(
    () => items.filter((item) => selectedEventIds.includes(item.id)),
    [items, selectedEventIds]
  );
  const allVisibleSelected = items.length > 0 && items.every((item) => selectedEventIds.includes(item.id));
  const unboundClusters = useMemo(() => {
    const map = new Map<string, EventOrganizerBindingCatalogItem[]>();
    items
      .filter((item) => !item.wikiFestivalId)
      .forEach((item) => {
        const key = buildUnboundClusterKey(item);
        const bucket = map.get(key) ?? [];
        bucket.push(item);
        map.set(key, bucket);
      });

    return Array.from(map.entries())
      .map(([label, rows]) => ({
        label,
        rows,
      }))
      .sort((left, right) => right.rows.length - left.rows.length)
      .slice(0, 8);
  }, [items]);

  const loadEvents = useCallback(async () => {
    try {
      setIsLoading(true);
      const response = await eventOrganizerBindingApi.fetchEvents({
        page,
        limit: PAGE_SIZE,
        search: search || undefined,
        status,
      });
      setItems(response.items);
      setTotalPages(response.pagination.totalPages);
      setTotal(response.pagination.total);
      setCacheMessage(
        response.cache?.hit
          ? '当前页已命中服务端目录缓存，适合持续低频管理。'
          : '当前页已从摘要层刷新，避免直接命中全量重查询。'
      );
      if (!selectedEventId && response.items[0]) {
        setSelectedEventId(response.items[0].id);
      }
      if (selectedEventId && !response.items.some((item) => item.id === selectedEventId)) {
        setSelectedEventId(response.items[0]?.id ?? null);
      }
      setSelectedEventIds((current) => current.filter((eventId) => response.items.some((item) => item.id === eventId)));
      setError('');
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '活动绑定目录加载失败');
    } finally {
      setIsLoading(false);
    }
  }, [page, search, selectedEventId, status]);

  useEffect(() => {
    void loadEvents();
  }, [loadEvents]);

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

  const handleSearchSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setPage(1);
    setSearch(searchInput.trim());
  };

  const handleBind = async () => {
    if (!selectedEvent || !selectedOrganizer) return;
    try {
      setIsSubmitting(true);
      setError('');
      setSuccessMessage('');
      await eventOrganizerBindingApi.bindOrganizer({
        eventId: selectedEvent.id,
        organizerId: selectedOrganizer.id,
        organizerName: selectedOrganizer.name,
      });
      setSuccessMessage(`已将「${selectedEvent.name}」绑定到主办方「${selectedOrganizer.name}」`);
      await loadEvents();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '活动绑定失败');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleClear = async () => {
    if (!selectedEvent) return;
    try {
      setIsSubmitting(true);
      setError('');
      setSuccessMessage('');
      await eventOrganizerBindingApi.clearOrganizer({
        eventId: selectedEvent.id,
      });
      setSelectedOrganizer(null);
      setOrganizerQuery('');
      setSuccessMessage(`已清空「${selectedEvent.name}」当前绑定的主办方关系`);
      await loadEvents();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '清空主办方绑定失败');
    } finally {
      setIsSubmitting(false);
    }
  };

  const toggleEventSelection = (eventId: string) => {
    setSelectedEventIds((current) =>
      current.includes(eventId)
        ? current.filter((item) => item !== eventId)
        : [...current, eventId]
    );
  };

  const toggleSelectAllVisible = () => {
    if (allVisibleSelected) {
      setSelectedEventIds([]);
      return;
    }
    setSelectedEventIds(items.map((item) => item.id));
  };

  const selectCluster = (clusterEventIds: string[]) => {
    setSelectedEventIds((current) => Array.from(new Set([...current, ...clusterEventIds])));
  };

  const handleBatchBind = async () => {
    if (!selectedOrganizer || selectedEventIds.length === 0) return;
    try {
      setIsSubmitting(true);
      setError('');
      setSuccessMessage('');
      const result = await eventOrganizerBindingApi.bindOrganizerBatch({
        eventIds: selectedEventIds,
        organizerId: selectedOrganizer.id,
        organizerName: selectedOrganizer.name,
      });
      setSuccessMessage(
        result.failureCount > 0
          ? `批量绑定完成：成功 ${result.successCount} 条，失败 ${result.failureCount} 条。`
          : `批量绑定完成：成功 ${result.successCount} 条。`
      );
      await loadEvents();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '批量绑定失败');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleBatchClear = async () => {
    if (selectedEventIds.length === 0) return;
    try {
      setIsSubmitting(true);
      setError('');
      setSuccessMessage('');
      const result = await eventOrganizerBindingApi.clearOrganizerBatch({
        eventIds: selectedEventIds,
      });
      setSelectedOrganizer(null);
      setOrganizerQuery('');
      setSuccessMessage(
        result.failureCount > 0
          ? `批量清空完成：成功 ${result.successCount} 条，失败 ${result.failureCount} 条。`
          : `批量清空完成：成功 ${result.successCount} 条。`
      );
      await loadEvents();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '批量清空失败');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <AdminContentLayout
      title="活动 ↔ 主办方绑定中心"
      eyebrow="Admin / Content Workspace / Organizer Binding"
      description="这一页把 Festival Viewer 里最常用的 Event ↔ Brand 关系维护迁回统一后台。左侧用低频目录摘要选活动，右侧集中完成主办方搜索、绑定、清空与编辑跳转。"
      actions={
        <>
          <Link href="/admin/content/organizers" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回主办方工作区
          </Link>
          <Link href="/admin/content/events/catalog" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            活动目录中心
          </Link>
          <Link href="/admin/content/organizers/new" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
            新建主办方
          </Link>
        </>
      }
    >
      <section className="grid gap-5 xl:grid-cols-[1.2fr_0.8fr]">
        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Binding Strategy</div>
          <h2 className="mt-2 text-2xl font-semibold">低频目录 + 关系面板</h2>
          <div className="mt-5 grid gap-3 md:grid-cols-3">
            {[
              '左侧活动目录只看摘要卡片，不直接加载完整活动详情',
              '右侧只在真正绑定时拉取完整活动并提交标准化 update payload',
              '先把高频关系维护回迁，当前已经补到批量绑定第一版',
            ].map((item) => (
              <div key={item} className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm leading-6">
                {item}
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-border-secondary bg-[linear-gradient(180deg,rgba(255,255,255,0.05),rgba(255,255,255,0.02)),radial-gradient(circle_at_top_left,rgba(209,171,84,0.16),transparent_35%),radial-gradient(circle_at_bottom_right,rgba(64,147,255,0.14),transparent_45%)] p-6">
          <div className="text-sm text-text-secondary">Cache Status</div>
          <h2 className="mt-2 text-2xl font-semibold">摘要层说明</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>{cacheMessage}</p>
            <p>当前页：{page} / {totalPages}</p>
            <p>可管理活动：{total.toLocaleString()} 条</p>
          </div>
        </div>
      </section>

      <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <div className="text-sm text-text-secondary">Unbound Clusters</div>
            <h2 className="mt-2 text-2xl font-semibold">未匹配聚类视图</h2>
            <p className="mt-3 text-sm leading-6 text-text-secondary">
              把当前页还没绑定正式主办方的活动按主办方文案或活动名关键词聚类，方便运营集中勾选后再做批量绑定。
            </p>
          </div>
          <div className="rounded-2xl border border-border-secondary bg-bg-tertiary/40 px-4 py-3 text-sm text-text-secondary">
            当前页未绑定活动：{items.filter((item) => !item.wikiFestivalId).length} 条
          </div>
        </div>

        <div className="mt-5 grid gap-4 lg:grid-cols-2 xl:grid-cols-3">
          {unboundClusters.length === 0 ? (
            <div className="rounded-2xl border border-border-secondary bg-bg-tertiary/35 px-4 py-6 text-sm text-text-secondary">
              当前页没有待治理的未匹配活动。
            </div>
          ) : (
            unboundClusters.map((cluster) => (
              <div key={cluster.label} className="rounded-2xl border border-border-secondary bg-bg-tertiary/35 p-4">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="text-sm font-semibold text-text-primary">{cluster.label}</div>
                    <div className="mt-1 text-xs text-text-secondary">{cluster.rows.length} 条待绑定活动</div>
                  </div>
                  <button
                    type="button"
                    onClick={() => selectCluster(cluster.rows.map((item) => item.id))}
                    className="rounded-xl border border-border-secondary px-3 py-2 text-xs hover:border-primary-blue hover:text-primary-blue"
                  >
                    选中这一组
                  </button>
                </div>

                <div className="mt-4 space-y-2">
                  {cluster.rows.slice(0, 4).map((row) => (
                    <button
                      key={row.id}
                      type="button"
                      onClick={() => setSelectedEventId(row.id)}
                      className="block w-full rounded-xl border border-border-secondary bg-bg-secondary/60 px-3 py-3 text-left hover:border-primary-blue/40"
                    >
                      <div className="text-sm font-medium text-text-primary">{row.name}</div>
                      <div className="mt-1 text-xs leading-5 text-text-secondary">
                        {row.city || '未知城市'} / {row.country || '未知国家'} · {formatDateRange(row.startDate, row.endDate)}
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            ))
          )}
        </div>
      </section>

      <section className="grid gap-5 xl:grid-cols-[1.15fr_0.85fr]">
        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
            <form onSubmit={handleSearchSubmit} className="grid flex-1 gap-3 md:grid-cols-[minmax(0,1.7fr)_220px_auto]">
              <label className="space-y-2">
                <span className="text-xs uppercase tracking-[0.2em] text-text-secondary">搜索活动</span>
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
                检索活动
              </button>
            </form>
            <div className="flex flex-wrap gap-3">
              <button
                type="button"
                onClick={toggleSelectAllVisible}
                className="rounded-xl border border-border-secondary px-4 py-3 text-sm hover:border-primary-blue hover:text-primary-blue"
              >
                {allVisibleSelected ? '取消全选当前页' : '全选当前页'}
              </button>
              <div className="rounded-xl border border-border-secondary bg-bg-tertiary/40 px-4 py-3 text-sm text-text-secondary">
                已选 {selectedEventIds.length} 条
              </div>
            </div>
          </div>

          <div className="mt-5">
            {isLoading ? (
              <div className="py-20 text-center text-sm text-text-secondary">活动摘要加载中…</div>
            ) : items.length === 0 ? (
              <div className="py-20 text-center text-sm text-text-secondary">当前筛选下没有活动可供绑定。</div>
            ) : (
              <div className="space-y-4">
                {items.map((item) => {
                  const selected = item.id === selectedEventId;
                  return (
                    <div
                      key={item.id}
                      className={`grid gap-4 rounded-3xl border p-4 transition-colors lg:grid-cols-[32px_120px_minmax(0,1fr)] ${
                        selected
                          ? 'border-primary-blue bg-primary-blue/8'
                          : 'border-border-secondary bg-bg-tertiary/35 hover:border-primary-blue/40'
                      }`}
                    >
                      <label className="flex items-start pt-1">
                        <input
                          type="checkbox"
                          checked={selectedEventIds.includes(item.id)}
                          onChange={() => toggleEventSelection(item.id)}
                          className="mt-1 h-4 w-4 rounded border-border-secondary bg-bg-secondary"
                        />
                      </label>
                      <div className="relative overflow-hidden rounded-2xl border border-border-secondary bg-bg-secondary">
                        {item.coverImageUrl ? (
                          <Image
                            src={item.coverImageUrl}
                            alt={item.name}
                            width={240}
                            height={180}
                            className="h-full min-h-[100px] w-full object-cover"
                          />
                        ) : (
                          <div className="flex h-full min-h-[100px] items-center justify-center bg-[linear-gradient(135deg,rgba(209,171,84,0.18),rgba(64,147,255,0.18))] text-sm text-text-secondary">
                            暂无封面
                          </div>
                        )}
                      </div>

                      <button
                        type="button"
                        onClick={() => {
                          setSelectedEventId(item.id);
                          setSelectedOrganizer(null);
                          setOrganizerQuery('');
                          setSuccessMessage('');
                        }}
                        className="min-w-0 text-left"
                      >
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="rounded-full border border-border-secondary px-3 py-1 text-xs text-text-secondary">
                            {item.eventType || '未标记类型'}
                          </span>
                          <span className="rounded-full border border-border-secondary px-3 py-1 text-xs text-text-secondary">
                            {item.status || 'unknown'}
                          </span>
                          {item.wikiFestivalId ? (
                            <span className="rounded-full border border-primary-blue/30 bg-primary-blue/10 px-3 py-1 text-xs text-text-primary">
                              已绑定主办方
                            </span>
                          ) : (
                            <span className="rounded-full border border-amber-300/30 bg-amber-300/10 px-3 py-1 text-xs text-amber-100">
                              待绑定
                            </span>
                          )}
                        </div>

                        <h3 className="mt-3 truncate text-xl font-semibold text-text-primary">{item.name}</h3>
                        <p className="mt-2 text-sm leading-6 text-text-secondary">
                          {item.city || '未知城市'} / {item.country || '未知国家'} · {formatDateRange(item.startDate, item.endDate)}
                        </p>
                        <p className="mt-2 text-sm leading-6 text-text-secondary">
                          当前主办方：{item.wikiFestival?.name || item.organizerName || '尚未绑定正式主办方'}
                        </p>
                        <p className="mt-2 text-xs text-text-secondary">最近更新：{formatDateTime(item.updatedAt)}</p>
                      </button>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          <div className="mt-6 flex items-center justify-between border-t border-white/5 pt-6">
            <div className="text-sm text-text-secondary">
              共 {total.toLocaleString()} 条活动摘要
            </div>
            <div className="flex gap-3">
              <button
                type="button"
                disabled={page <= 1}
                onClick={() => setPage((current) => Math.max(1, current - 1))}
                className="rounded-xl border border-border-secondary px-4 py-2 text-sm disabled:cursor-not-allowed disabled:opacity-40"
              >
                上一页
              </button>
              <button
                type="button"
                disabled={page >= totalPages}
                onClick={() => setPage((current) => Math.min(totalPages, current + 1))}
                className="rounded-xl border border-border-secondary px-4 py-2 text-sm disabled:cursor-not-allowed disabled:opacity-40"
              >
                下一页
              </button>
            </div>
          </div>
        </div>

        <div className="space-y-5">
          <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
            <div className="text-sm text-text-secondary">Binding Panel</div>
            <h2 className="mt-2 text-2xl font-semibold">当前活动关系面板</h2>

            {selectedEvent ? (
              <div className="mt-5 space-y-4">
                <div className="rounded-2xl border border-border-secondary bg-bg-tertiary/50 p-4">
                  <div className="text-sm text-text-secondary">当前活动</div>
                  <div className="mt-1 text-xl font-semibold text-text-primary">{selectedEvent.name}</div>
                  <div className="mt-2 text-sm leading-6 text-text-secondary">
                    当前绑定：
                    {selectedEvent.wikiFestival?.name || selectedEvent.organizerName || '尚未绑定正式主办方'}
                  </div>
                </div>

                <label className="space-y-2">
                  <span className="text-xs uppercase tracking-[0.2em] text-text-secondary">搜索主办方</span>
                  <input
                    value={organizerQuery}
                    onChange={(event) => {
                      setOrganizerQuery(event.target.value);
                      setSelectedOrganizer(null);
                      setSuccessMessage('');
                    }}
                    placeholder="输入主办方名 / alias / 城市"
                    className="w-full rounded-xl border border-border-secondary bg-bg-tertiary/70 px-4 py-3 text-sm text-text-primary outline-none transition-colors focus:border-primary-blue"
                  />
                </label>

                <div className="rounded-2xl border border-border-secondary bg-bg-tertiary/35 p-3">
                  {isSearchingOrganizers ? (
                    <div className="text-sm text-text-secondary">正在搜索主办方…</div>
                  ) : organizerResults.length === 0 ? (
                    <div className="text-sm text-text-secondary">输入关键词后会在正式主办方库中检索候选。</div>
                  ) : (
                    <div className="space-y-2">
                      {organizerResults.map((organizer) => {
                        const active = organizer.id === selectedOrganizer?.id;
                        return (
                          <button
                            key={organizer.id}
                            type="button"
                            onClick={() => setSelectedOrganizer(organizer)}
                            className={`w-full rounded-2xl border px-4 py-3 text-left transition-colors ${
                              active
                                ? 'border-primary-blue bg-primary-blue/10'
                                : 'border-border-secondary bg-bg-secondary/70 hover:border-primary-blue/40'
                            }`}
                          >
                            <div className="text-sm font-semibold text-text-primary">{organizer.name}</div>
                            <div className="mt-1 text-xs leading-5 text-text-secondary">
                              {organizer.city || '未知城市'} / {organizer.country || '未知国家'}
                            </div>
                          </button>
                        );
                      })}
                    </div>
                  )}
                </div>

                {selectedOrganizer ? (
                  <div className="rounded-2xl border border-primary-blue/20 bg-primary-blue/8 p-4 text-sm leading-6 text-text-primary">
                    即将绑定到：{selectedOrganizer.name}
                  </div>
                ) : null}

                <div className="grid gap-3">
                  <button
                    type="button"
                    disabled={!selectedOrganizer || isSubmitting}
                    onClick={handleBind}
                    className="rounded-xl bg-primary-blue px-5 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    绑定到所选主办方
                  </button>
                  <button
                    type="button"
                    disabled={isSubmitting || !selectedEvent?.wikiFestivalId}
                    onClick={handleClear}
                    className="rounded-xl border border-border-secondary px-5 py-3 text-sm hover:border-primary-blue hover:text-primary-blue disabled:cursor-not-allowed disabled:opacity-40"
                  >
                    清空当前绑定
                  </button>
                </div>

                <div className="rounded-2xl border border-border-secondary bg-bg-tertiary/35 p-4">
                  <div className="text-sm font-semibold text-text-primary">批量操作</div>
                  <div className="mt-2 text-sm leading-6 text-text-secondary">
                    当前已选 {selectedEventIds.length} 条活动
                    {selectedEvents.length > 0 ? `，其中本页可见 ${selectedEvents.length} 条` : ''}
                  </div>
                  <div className="mt-4 grid gap-3">
                    <button
                      type="button"
                      disabled={!selectedOrganizer || selectedEventIds.length === 0 || isSubmitting}
                      onClick={handleBatchBind}
                      className="rounded-xl bg-primary-blue px-5 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
                    >
                      批量绑定到所选主办方
                    </button>
                    <button
                      type="button"
                      disabled={selectedEventIds.length === 0 || isSubmitting}
                      onClick={handleBatchClear}
                      className="rounded-xl border border-border-secondary px-5 py-3 text-sm hover:border-primary-blue hover:text-primary-blue disabled:cursor-not-allowed disabled:opacity-40"
                    >
                      批量清空绑定
                    </button>
                  </div>
                </div>
              </div>
            ) : (
              <div className="mt-5 text-sm text-text-secondary">先从左侧选择一个活动。</div>
            )}
          </section>

          {error ? (
            <section className="rounded-3xl border border-red-500/30 bg-red-500/10 p-4 text-sm text-red-200">
              {error}
            </section>
          ) : null}

          {successMessage ? (
            <section className="rounded-3xl border border-emerald-400/30 bg-emerald-400/10 p-4 text-sm text-emerald-100">
              {successMessage}
            </section>
          ) : null}

          <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
            <div className="text-sm text-text-secondary">Migration Note</div>
            <h2 className="mt-2 text-2xl font-semibold">迁移边界</h2>
            <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
              <p>这一步已经补到批量绑定和未匹配聚类第一版，先解决日常“找活动、绑主办方、清关系、批量改关系”的后台高频动作。</p>
              <p>下一批继续补更深的 Archive / DJ 辅助管理能力和 DJ edit，让 Festival Viewer 的运营型工作继续往这里收口。</p>
            </div>
            <div className="mt-4 grid gap-3">
              <Link href="/admin/content/events/catalog" className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm hover:border-primary-blue hover:text-primary-blue">
                返回活动目录中心
              </Link>
              <Link href="/admin/content/legacy-tools/brands" className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm hover:border-primary-blue hover:text-primary-blue">
                查看旧 Brand 工具桥接页
              </Link>
            </div>
          </section>
        </div>
      </section>
    </AdminContentLayout>
  );
}
