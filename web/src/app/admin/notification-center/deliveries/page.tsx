'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import NotificationCenterWorkspaceLayout from '@/components/admin/NotificationCenterWorkspaceLayout';
import {
  CHANNEL_OPTIONS,
  SECTION_OPTIONS,
  buildVisiblePages,
  formatTime,
  sectionSummaryMap,
  trimValue,
} from '@/components/admin/notification-center/shared';
import {
  notificationCenterAdminApi,
  type NotificationCenterDeliverySection,
  type NotificationCenterDeliverySectionPage,
  type NotificationCenterDeliverySectionSummary,
} from '@/lib/api/notification-center-admin';

export default function NotificationCenterDeliveriesPage() {
  const [loading, setLoading] = useState(true);
  const [sectionLoading, setSectionLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [windowHours, setWindowHours] = useState('24');
  const [filterChannel, setFilterChannel] = useState('');
  const [filterStatus, setFilterStatus] = useState('');
  const [filterUserId, setFilterUserId] = useState('');
  const [filterEventId, setFilterEventId] = useState('');
  const [filterQuery, setFilterQuery] = useState('');
  const [activeSection, setActiveSection] = useState<NotificationCenterDeliverySection>('event_news');
  const [sectionSummaries, setSectionSummaries] = useState<NotificationCenterDeliverySectionSummary[]>([]);
  const [sectionPage, setSectionPage] = useState<NotificationCenterDeliverySectionPage | null>(null);
  const [sectionListPage, setSectionListPage] = useState(1);

  const loadSummaries = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const result = await notificationCenterAdminApi.getDeliverySections({
        channel: filterChannel ? (filterChannel as 'in_app' | 'apns' | 'email' | 'sms') : undefined,
        status: trimValue(filterStatus) || undefined,
        userId: trimValue(filterUserId) || undefined,
        eventId: trimValue(filterEventId) || undefined,
        query: trimValue(filterQuery) || undefined,
      });
      setSectionSummaries(result);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载投递分区失败');
    } finally {
      setLoading(false);
    }
  }, [filterChannel, filterEventId, filterQuery, filterStatus, filterUserId]);

  const loadSectionPage = useCallback(
    async (section: NotificationCenterDeliverySection, page: number) => {
      try {
        setSectionLoading(true);
        setError(null);
        const result = await notificationCenterAdminApi.getDeliveriesBySection({
          section,
          page,
          limit: 20,
          channel: filterChannel ? (filterChannel as 'in_app' | 'apns' | 'email' | 'sms') : undefined,
          status: trimValue(filterStatus) || undefined,
          userId: trimValue(filterUserId) || undefined,
          eventId: trimValue(filterEventId) || undefined,
          query: trimValue(filterQuery) || undefined,
        });
        setSectionPage(result);
      } catch (loadError) {
        setError(loadError instanceof Error ? loadError.message : '加载投递记录失败');
      } finally {
        setSectionLoading(false);
      }
    },
    [filterChannel, filterEventId, filterQuery, filterStatus, filterUserId]
  );

  useEffect(() => {
    void loadSummaries();
  }, [loadSummaries]);

  useEffect(() => {
    void loadSectionPage(activeSection, sectionListPage);
  }, [activeSection, sectionListPage, loadSectionPage]);

  const summaryLookup = useMemo(() => sectionSummaryMap(sectionSummaries), [sectionSummaries]);
  const visiblePages = useMemo(
    () => buildVisiblePages(sectionPage?.pagination.page ?? 1, sectionPage?.pagination.totalPages ?? 1),
    [sectionPage?.pagination.page, sectionPage?.pagination.totalPages]
  );

  const handleApplyFilters = async () => {
    setSectionListPage(1);
    await loadSummaries();
    await loadSectionPage(activeSection, 1);
  };

  return (
    <NotificationCenterWorkspaceLayout
      title="投递记录"
      description="按通知分区查看真实投递结果、失败情况、用户与绑定对象，适合排查通知有没有发对。"
      actions={
        <button
          type="button"
          onClick={() => void handleApplyFilters()}
          className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
        >
          刷新记录
        </button>
      }
    >
      {error ? (
        <section className="rounded-[24px] border border-[#f0d7d5] bg-[#fff7f6] px-4 py-3 text-sm text-[#8b3a3a]">
          {error}
        </section>
      ) : null}

      <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div>
            <div className="admin-studio-label">Record Filters</div>
            <h2 className="mt-2 text-xl font-semibold text-[#071110]">记录筛选</h2>
          </div>
          <button
            type="button"
            onClick={() => void handleApplyFilters()}
            className="rounded-full border border-[#d9e1de] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            应用筛选
          </button>
        </div>
        <div className="mt-5 grid gap-4 md:grid-cols-3 xl:grid-cols-6">
          <label className="text-sm text-[#5b6763]">
            统计窗口（小时）
            <input
              value={windowHours}
              onChange={(event) => setWindowHours(event.target.value)}
              className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
              placeholder="24"
            />
          </label>
          <label className="text-sm text-[#5b6763]">
            渠道
            <select
              value={filterChannel}
              onChange={(event) => setFilterChannel(event.target.value)}
              className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
            >
              <option value="">全部</option>
              {CHANNEL_OPTIONS.map((item) => (
                <option key={item.value} value={item.value}>
                  {item.label}
                </option>
              ))}
            </select>
          </label>
          <label className="text-sm text-[#5b6763]">
            状态
            <input
              value={filterStatus}
              onChange={(event) => setFilterStatus(event.target.value)}
              className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
              placeholder="sent / failed / queued"
            />
          </label>
          <label className="text-sm text-[#5b6763]">
            用户 ID
            <input
              value={filterUserId}
              onChange={(event) => setFilterUserId(event.target.value)}
              className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
              placeholder="u_xxx"
            />
          </label>
          <label className="text-sm text-[#5b6763]">
            事件 ID
            <input
              value={filterEventId}
              onChange={(event) => setFilterEventId(event.target.value)}
              className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
              placeholder="notification event id"
            />
          </label>
          <label className="text-sm text-[#5b6763]">
            关键词
            <input
              value={filterQuery}
              onChange={(event) => setFilterQuery(event.target.value)}
              className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
              placeholder="标题 / 用户 / 绑定对象"
            />
          </label>
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
        <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
          <div className="admin-studio-label">Delivery Sections</div>
          <h2 className="mt-2 text-xl font-semibold text-[#071110]">通知分区</h2>
          <div className="mt-5 space-y-3">
            {SECTION_OPTIONS.map((section) => {
              const summary = summaryLookup.get(section.key);
              const isActiveSection = activeSection === section.key;
              return (
                <button
                  key={section.key}
                  type="button"
                  onClick={() => {
                    setActiveSection(section.key);
                    setSectionListPage(1);
                  }}
                  className={`w-full rounded-[24px] border px-4 py-4 text-left transition ${
                    isActiveSection ? 'border-[#071110] bg-[#f5f7f6]' : 'border-[#e7ece8] bg-white'
                  }`}
                >
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <div className="text-sm font-semibold text-[#071110]">{section.label}</div>
                      <div className="mt-1 text-xs leading-5 text-[#5b6763]">{section.helper}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-lg font-semibold text-[#071110]">{summary?.total ?? 0}</div>
                      <div className="text-xs text-[#5b6763]">记录</div>
                    </div>
                  </div>
                  <div className="mt-3 flex flex-wrap gap-2 text-xs text-[#5b6763]">
                    <span className="rounded-full bg-[#f2f5f3] px-3 py-1">APNS {summary?.apnsCount ?? 0}</span>
                    <span className="rounded-full bg-[#f2f5f3] px-3 py-1">站内 {summary?.inAppCount ?? 0}</span>
                    <span className="rounded-full bg-[#f2f5f3] px-3 py-1">失败 {summary?.failedCount ?? 0}</span>
                  </div>
                </button>
              );
            })}
          </div>
        </section>

        <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <div className="admin-studio-label">Section Records</div>
              <h2 className="mt-2 text-xl font-semibold text-[#071110]">
                {SECTION_OPTIONS.find((item) => item.key === activeSection)?.label || '通知记录'}
              </h2>
              <div className="mt-2 text-sm text-[#5b6763]">
                {sectionPage
                  ? `共 ${sectionPage.pagination.total.toLocaleString()} 条，当前第 ${sectionPage.pagination.page} / ${Math.max(1, sectionPage.pagination.totalPages)} 页`
                  : loading || sectionLoading
                    ? '正在加载通知记录...'
                    : '暂无数据'}
              </div>
            </div>
          </div>

          <div className="mt-5 overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead>
                <tr className="border-b border-[#edf1ef] text-[#5b6763]">
                  <th className="px-3 py-3">时间</th>
                  <th className="px-3 py-3">渠道</th>
                  <th className="px-3 py-3">状态</th>
                  <th className="px-3 py-3">用户</th>
                  <th className="px-3 py-3">内容</th>
                  <th className="px-3 py-3">绑定对象</th>
                  <th className="px-3 py-3">错误</th>
                </tr>
              </thead>
              <tbody>
                {sectionPage?.items.map((item) => (
                  <tr key={item.id} className="border-b border-[#f1f4f2] align-top">
                    <td className="px-3 py-4 text-xs text-[#5b6763]">
                      <div>{formatTime(item.createdAt)}</div>
                      <div className="mt-1 text-[11px]">{item.event.category}</div>
                    </td>
                    <td className="px-3 py-4">
                      <span className="rounded-full bg-[#f2f5f3] px-3 py-1 text-xs font-semibold text-[#42514c]">
                        {item.channel}
                      </span>
                    </td>
                    <td className="px-3 py-4">
                      <span
                        className={`rounded-full px-3 py-1 text-xs font-semibold ${
                          item.status === 'sent'
                            ? 'bg-[#edf7ef] text-[#315742]'
                            : item.status === 'failed'
                              ? 'bg-[#fff1f0] text-[#8b3a3a]'
                              : 'bg-[#fff8eb] text-[#8a6114]'
                        }`}
                      >
                        {item.status}
                      </span>
                    </td>
                    <td className="px-3 py-4 text-sm text-[#071110]">
                      <div>{item.user.displayName || item.user.username}</div>
                      <div className="mt-1 text-xs text-[#5b6763]">{item.userId}</div>
                    </td>
                    <td className="px-3 py-4">
                      <div className="max-w-[260px] text-sm font-semibold text-[#071110]">
                        {item.payload.title || item.metadata.newsTitle || '-'}
                      </div>
                      <div className="mt-1 max-w-[260px] text-xs leading-5 text-[#5b6763]">
                        {item.payload.body || '-'}
                      </div>
                    </td>
                    <td className="px-3 py-4 text-xs leading-5 text-[#5b6763]">
                      {item.metadata.eventName || item.metadata.djName || item.metadata.brandName || '-'}
                    </td>
                    <td className="px-3 py-4 text-xs leading-5 text-[#8b3a3a]">{item.error || '-'}</td>
                  </tr>
                ))}
                {!sectionLoading && !sectionPage?.items.length ? (
                  <tr>
                    <td colSpan={7} className="px-3 py-10 text-center text-sm text-[#5b6763]">
                      当前分区暂无通知记录。
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>

          <div className="mt-5 flex flex-wrap items-center justify-between gap-3">
            <div className="text-xs text-[#5b6763]">每页 20 条</div>
            <div className="flex flex-wrap items-center gap-2">
              <button
                type="button"
                disabled={(sectionPage?.pagination.page ?? 1) <= 1}
                onClick={() => setSectionListPage((current) => Math.max(1, current - 1))}
                className="rounded-full border border-[#d9e1de] bg-white px-4 py-2 text-xs font-semibold text-[#071110] disabled:opacity-40"
              >
                上一页
              </button>
              {visiblePages.map((pageNumber) => (
                <button
                  key={pageNumber}
                  type="button"
                  onClick={() => setSectionListPage(pageNumber)}
                  className={`min-w-9 rounded-full px-3 py-2 text-xs font-semibold ${
                    pageNumber === (sectionPage?.pagination.page ?? 1)
                      ? 'bg-[#071110] text-white'
                      : 'border border-[#d9e1de] bg-white text-[#071110]'
                  }`}
                >
                  {pageNumber}
                </button>
              ))}
              <button
                type="button"
                disabled={(sectionPage?.pagination.page ?? 1) >= Math.max(1, sectionPage?.pagination.totalPages ?? 1)}
                onClick={() =>
                  setSectionListPage((current) =>
                    Math.min(Math.max(1, sectionPage?.pagination.totalPages ?? 1), current + 1)
                  )
                }
                className="rounded-full border border-[#d9e1de] bg-white px-4 py-2 text-xs font-semibold text-[#071110] disabled:opacity-40"
              >
                下一页
              </button>
            </div>
          </div>
        </section>
      </section>
    </NotificationCenterWorkspaceLayout>
  );
}
