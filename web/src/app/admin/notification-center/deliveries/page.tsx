'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import NotificationCenterWorkspaceLayout from '@/components/admin/NotificationCenterWorkspaceLayout';
import {
  CHANNEL_OPTIONS,
  SECTION_OPTIONS,
  buildVisiblePages,
  formatPercent,
  formatTime,
  sectionSummaryMap,
  trimValue,
} from '@/components/admin/notification-center/shared';
import {
  notificationCenterAdminApi,
  type NotificationCenterDeliverySection,
  type NotificationCenterDeliverySectionPage,
  type NotificationCenterDeliverySectionSummary,
  type NotificationCenterStatusResponse,
} from '@/lib/api/notification-center-admin';

type ColumnKey =
  | 'time'
  | 'channel'
  | 'status'
  | 'user'
  | 'content'
  | 'binding'
  | 'error'
  | 'eventId'
  | 'actions';

const DEFAULT_VISIBLE_COLUMNS: Record<ColumnKey, boolean> = {
  time: true,
  channel: true,
  status: true,
  user: true,
  content: true,
  binding: true,
  error: true,
  eventId: true,
  actions: true,
};

const COLUMN_OPTIONS: Array<{ key: ColumnKey; label: string }> = [
  { key: 'time', label: '时间' },
  { key: 'channel', label: '渠道' },
  { key: 'status', label: '状态' },
  { key: 'user', label: '用户' },
  { key: 'content', label: '内容' },
  { key: 'binding', label: '绑定对象' },
  { key: 'error', label: '错误信息' },
  { key: 'eventId', label: '事件 ID' },
  { key: 'actions', label: '操作' },
];

export default function NotificationCenterDeliveriesPage() {
  const [loading, setLoading] = useState(true);
  const [sectionLoading, setSectionLoading] = useState(false);
  const [statusLoading, setStatusLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [windowHours, setWindowHours] = useState('24');
  const [filterChannel, setFilterChannel] = useState('');
  const [filterStatus, setFilterStatus] = useState('');
  const [filterUserId, setFilterUserId] = useState('');
  const [filterEventId, setFilterEventId] = useState('');
  const [filterQuery, setFilterQuery] = useState('');
  const [isFilterCollapse, setIsFilterCollapse] = useState(false);

  const [activeSection, setActiveSection] = useState<NotificationCenterDeliverySection>('event_news');
  const [sectionSummaries, setSectionSummaries] = useState<NotificationCenterDeliverySectionSummary[]>([]);
  const [sectionPage, setSectionPage] = useState<NotificationCenterDeliverySectionPage | null>(null);
  const [statusData, setStatusData] = useState<NotificationCenterStatusResponse | null>(null);
  const [sectionListPage, setSectionListPage] = useState(1);
  const [jumpPageNum, setJumpPageNum] = useState('1');
  const [selectedDeliveryId, setSelectedDeliveryId] = useState<string | null>(null);
  const [showColumnSettings, setShowColumnSettings] = useState(false);
  const [visibleColumns, setVisibleColumns] = useState<Record<ColumnKey, boolean>>(DEFAULT_VISIBLE_COLUMNS);

  const parsedWindowHours = useMemo(() => {
    const numeric = Number.parseInt(windowHours, 10);
    if (!Number.isFinite(numeric) || numeric <= 0) return 24;
    return Math.min(168, numeric);
  }, [windowHours]);

  const loadStatus = useCallback(async () => {
    try {
      setStatusLoading(true);
      const result = await notificationCenterAdminApi.getStatus(parsedWindowHours);
      setStatusData(result);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载投递概览失败');
    } finally {
      setStatusLoading(false);
    }
  }, [parsedWindowHours]);

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
    void loadStatus();
  }, [loadStatus]);

  useEffect(() => {
    void loadSectionPage(activeSection, sectionListPage);
    setJumpPageNum(String(sectionListPage));
  }, [activeSection, sectionListPage, loadSectionPage]);

  const summaryLookup = useMemo(() => sectionSummaryMap(sectionSummaries), [sectionSummaries]);
  const visiblePages = useMemo(
    () => buildVisiblePages(sectionPage?.pagination.page ?? 1, sectionPage?.pagination.totalPages ?? 1),
    [sectionPage?.pagination.page, sectionPage?.pagination.totalPages]
  );
  const selectedDelivery = useMemo(
    () => sectionPage?.items.find((item) => item.id === selectedDeliveryId) ?? null,
    [sectionPage?.items, selectedDeliveryId]
  );

  const handleApplyFilters = async () => {
    setSectionListPage(1);
    await Promise.all([loadSummaries(), loadSectionPage(activeSection, 1), loadStatus()]);
  };

  const handleJumpPage = () => {
    const num = Number.parseInt(jumpPageNum, 10) || 1;
    const maxPage = sectionPage?.pagination.totalPages ?? 1;
    const target = Math.min(Math.max(1, num), maxPage);
    setSectionListPage(target);
  };

  const handleToggleColumn = (key: ColumnKey) => {
    setVisibleColumns((current) => ({ ...current, [key]: !current[key] }));
  };

  const overviewCardList = useMemo(() => {
    const totals = statusData?.delivery.totals;
    const rates = statusData?.delivery.rates;
    const engagement = statusData?.delivery.engagement;
    const subscriptions = statusData?.delivery.subscriptions;
    return [
      {
        label: '总投递数',
        value: totals?.total ?? 0,
        helper: `${parsedWindowHours}h 窗口`,
        color: 'bg-emerald-100 text-emerald-600',
      },
      {
        label: '投递成功',
        value: totals?.sent ?? 0,
        helper: formatPercent(rates?.deliverySuccessRate),
        color: 'bg-green-100 text-green-600',
      },
      {
        label: '投递失败',
        value: totals?.failed ?? 0,
        helper: formatPercent(rates?.deliveryFailureRate),
        color: 'bg-red-100 text-red-600',
      },
      {
        label: '排队中',
        value: totals?.queued ?? 0,
        helper: `Inbox 未读 ${engagement?.inboxUnread ?? 0}`,
        color: 'bg-sky-100 text-sky-600',
      },
      {
        label: '静默/关闭订阅',
        value: subscriptions?.disabled ?? 0,
        helper: `退订率 ${formatPercent(subscriptions?.unsubscribeRate)}`,
        color: 'bg-amber-100 text-amber-600',
      },
    ];
  }, [parsedWindowHours, statusData]);

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
        <section className="rounded-[24px] border border-[#f0d7d5] bg-[#fff7f6] px-4 py-3 text-sm text-[#8b3a3a] mb-5">
          {error}
        </section>
      ) : null}

      {/* 筛选区域 */}
      <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5 mb-5">
        <div className="flex items-center justify-between mb-4">
          <div>
            <div className="admin-studio-label">Record Filters</div>
            <h2 className="text-xl font-semibold text-[#071110]">记录筛选</h2>
          </div>
          <div className="flex gap-3">
            <button
              onClick={() => setIsFilterCollapse(!isFilterCollapse)}
              className="rounded-full border border-[#d9e1de] bg-white px-4 py-2 text-sm font-semibold text-[#071110]"
            >
              {isFilterCollapse ? '展开筛选' : '收起筛选'}
            </button>
            <button
              type="button"
              onClick={() => void handleApplyFilters()}
              className="rounded-full bg-[#071110] px-5 py-2 text-sm font-semibold text-white"
            >
              应用筛选
            </button>
          </div>
        </div>
        {!isFilterCollapse && (
          <div className="grid gap-4 grid-cols-1 md:grid-cols-3 xl:grid-cols-6">
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
                  <option key={item.value} value={item.value}>{item.label}</option>
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
        )}
      </section>

      {/* 统计卡片 */}
      <section className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4 mb-5">
        {overviewCardList.map((card, idx) => (
          <div key={idx} className="rounded-[24px] border border-[#e7ece8] bg-white p-5">
            <div className="flex justify-between items-start">
              <span className={`w-8 h-8 rounded-full flex items-center justify-center ${card.color}`}></span>
              <span className="text-xs text-[#5b6763]">{statusLoading ? '加载中...' : card.helper}</span>
            </div>
            <div className="mt-3">
              <div className="text-[26px] font-bold text-[#071110]">{card.value.toLocaleString()}</div>
              <div className="text-sm text-[#5b6763] mt-1">{card.label}</div>
            </div>
          </div>
        ))}
      </section>

      {/* 主内容分栏 */}
      <section className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
        {/* 左侧分区 */}
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
                    isActiveSection ? 'border-[#82d19b] bg-[#f0f9f3]' : 'border-[#e7ece8] bg-white'
                  }`}
                >
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <div className="text-sm font-semibold text-[#071110]">{section.label}</div>
                      <div className="mt-1 text-xs leading-5 text-[#5b6763]">{section.helper}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-lg font-semibold text-[#071110]">{summary?.total ?? 0}</div>
                      <div className="mt-1 text-xs text-[#5b6763]">
                        失败 {summary?.failedCount ?? 0} · 最近 {formatTime(summary?.lastDeliveryAt)}
                      </div>
                    </div>
                  </div>
                </button>
              );
            })}
          </div>
        </section>

        {/* 右侧表格 */}
        <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
          <div className="flex flex-wrap items-center justify-between gap-4 mb-4">
            <div>
              <div className="admin-studio-label">Section Records</div>
              <h2 className="mt-2 text-xl font-semibold text-[#071110]">
                {SECTION_OPTIONS.find((item) => item.key === activeSection)?.label || '通知记录'}
              </h2>
              <div className="mt-2 text-sm text-[#5b6763]">
                {sectionPage ? `共 ${sectionPage.pagination.total.toLocaleString()} 条，当前第 ${sectionPage.pagination.page} / ${Math.max(1, sectionPage.pagination.totalPages)} 页`
                  : loading || sectionLoading ? '正在加载通知记录...' : '暂无数据'}
              </div>
            </div>
            <div className="relative flex gap-3">
              <button
                type="button"
                onClick={() => setShowColumnSettings((current) => !current)}
                className="rounded-full border border-[#d9e1de] bg-white px-3 py-2 text-xs font-medium"
              >
                列设置
              </button>
              {showColumnSettings ? (
                <div className="absolute right-0 top-full z-10 mt-2 w-44 rounded-[20px] border border-[#e7ece8] bg-white p-3 shadow-lg">
                  <div className="mb-2 text-xs font-semibold text-[#071110]">显示列</div>
                  <div className="space-y-2">
                    {COLUMN_OPTIONS.map((column) => (
                      <label key={column.key} className="flex items-center gap-2 text-xs text-[#5b6763]">
                        <input
                          type="checkbox"
                          checked={visibleColumns[column.key]}
                          onChange={() => handleToggleColumn(column.key)}
                        />
                        <span>{column.label}</span>
                      </label>
                    ))}
                  </div>
                </div>
              ) : null}
            </div>
          </div>

          <div className="mt-2 overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead>
                <tr className="border-b border-[#edf1ef] text-[#5b6763]">
                  {visibleColumns.time ? <th className="px-3 py-3">时间</th> : null}
                  {visibleColumns.channel ? <th className="px-3 py-3">渠道</th> : null}
                  {visibleColumns.status ? <th className="px-3 py-3">状态</th> : null}
                  {visibleColumns.user ? <th className="px-3 py-3">用户</th> : null}
                  {visibleColumns.content ? <th className="px-3 py-3">内容</th> : null}
                  {visibleColumns.binding ? <th className="px-3 py-3">绑定对象</th> : null}
                  {visibleColumns.error ? <th className="px-3 py-3">错误信息</th> : null}
                  {visibleColumns.eventId ? <th className="px-3 py-3">事件 ID</th> : null}
                  {visibleColumns.actions ? <th className="px-3 py-3">操作</th> : null}
                </tr>
              </thead>
              <tbody>
                {sectionPage?.items.map((item) => (
                  <tr key={item.id} className="border-b border-[#f1f4f2] align-top">
                    {visibleColumns.time ? (
                      <td className="px-3 py-4 text-xs text-[#5b6763]">
                        <div>{formatTime(item.createdAt)}</div>
                        <div className="mt-1 text-[11px]">(北京时间)</div>
                      </td>
                    ) : null}
                    {visibleColumns.channel ? (
                      <td className="px-3 py-4">
                        <span className={`rounded-full px-3 py-1 text-xs font-semibold ${
                          item.channel === 'in_app' ? 'bg-[#dcf7e3] text-[#2d8648]'
                          : item.channel === 'apns' ? 'bg-[#ffe8e8] text-[#b83c3c]'
                          : item.channel === 'email' ? 'bg-[#e1edff] text-[#2c5cad]'
                          : 'bg-[#f3e8ff] text-[#8149b9]'
                        }`}>
                          {item.channel}
                        </span>
                      </td>
                    ) : null}
                    {visibleColumns.status ? (
                      <td className="px-3 py-4">
                        <span className={`rounded-full px-3 py-1 text-xs font-semibold ${
                          item.status === 'sent' ? 'bg-[#edf7ef] text-[#315742]'
                          : item.status === 'failed' ? 'bg-[#fff1f0] text-[#8b3a3a]'
                          : 'bg-[#e6f2ff] text-[#275f99]'
                        }`}>
                          {item.status}
                        </span>
                      </td>
                    ) : null}
                    {visibleColumns.user ? (
                      <td className="px-3 py-4 text-sm text-[#071110]">
                        <div>{item.user.displayName || item.user.username}</div>
                        <div className="mt-1 text-xs text-[#5b6763]">{item.userId}</div>
                      </td>
                    ) : null}
                    {visibleColumns.content ? (
                      <td className="px-3 py-4">
                        <div className="max-w-[260px] text-sm font-semibold text-[#071110]">
                          {item.payload.title || item.metadata.newsTitle || '-'}
                        </div>
                        <div className="mt-1 max-w-[260px] text-xs leading-5 text-[#5b6763]">
                          {item.payload.body || '-'}
                        </div>
                      </td>
                    ) : null}
                    {visibleColumns.binding ? (
                      <td className="px-3 py-4 text-xs leading-5 text-[#5b6763]">
                        {item.metadata.eventName || item.metadata.djName || item.metadata.brandName || '-'}
                      </td>
                    ) : null}
                    {visibleColumns.error ? (
                      <td className="px-3 py-4 text-xs leading-5 text-[#8b3a3a] max-w-[220px] break-all">{item.error || '-'}</td>
                    ) : null}
                    {visibleColumns.eventId ? (
                      <td className="px-3 py-4 text-xs text-[#5b6763]">{item.event?.id || '-'}</td>
                    ) : null}
                    {visibleColumns.actions ? (
                      <td className="px-3 py-4">
                        <button
                          type="button"
                          onClick={() => setSelectedDeliveryId(item.id)}
                          className="text-sky-600 text-xs font-medium"
                        >
                          详情
                        </button>
                      </td>
                    ) : null}
                  </tr>
                ))}
                {!sectionLoading && !sectionPage?.items.length && (
                  <tr>
                    <td colSpan={COLUMN_OPTIONS.filter((column) => visibleColumns[column.key]).length} className="px-3 py-10 text-center text-sm text-[#5b6763]">
                      当前分区暂无通知记录。
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          {selectedDelivery ? (
            <div className="mt-5 rounded-[24px] border border-[#e7ece8] bg-[#fbfcfb] p-5">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <div className="text-xs uppercase tracking-[0.24em] text-black/38">Delivery Detail</div>
                  <div className="mt-2 text-lg font-semibold text-[#071110]">
                    {selectedDelivery.payload.title || selectedDelivery.metadata.newsTitle || selectedDelivery.id}
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => setSelectedDeliveryId(null)}
                  className="rounded-full border border-[#d9e1de] bg-white px-3 py-2 text-xs font-medium text-[#071110]"
                >
                  收起详情
                </button>
              </div>
              <div className="mt-4 grid gap-4 md:grid-cols-2">
                <div className="rounded-[18px] border border-[#e7ece8] bg-white p-4 text-sm text-[#5b6763]">
                  <div className="text-xs uppercase tracking-[0.2em] text-black/38">投递信息</div>
                  <div className="mt-2">记录 ID：{selectedDelivery.id}</div>
                  <div className="mt-1">创建时间：{formatTime(selectedDelivery.createdAt)}</div>
                  <div className="mt-1">送达时间：{formatTime(selectedDelivery.deliveredAt)}</div>
                  <div className="mt-1">尝试次数：{selectedDelivery.attempts}</div>
                  <div className="mt-1">渠道：{selectedDelivery.channel}</div>
                  <div className="mt-1">状态：{selectedDelivery.status}</div>
                </div>
                <div className="rounded-[18px] border border-[#e7ece8] bg-white p-4 text-sm text-[#5b6763]">
                  <div className="text-xs uppercase tracking-[0.2em] text-black/38">关联上下文</div>
                  <div className="mt-2">用户：{selectedDelivery.user.displayName || selectedDelivery.user.username}</div>
                  <div className="mt-1">用户 ID：{selectedDelivery.userId}</div>
                  <div className="mt-1">事件 ID：{selectedDelivery.eventId}</div>
                  <div className="mt-1">来源：{selectedDelivery.metadata.source || '-'}</div>
                  <div className="mt-1">路由：{selectedDelivery.metadata.route || '-'}</div>
                </div>
                <div className="rounded-[18px] border border-[#e7ece8] bg-white p-4 text-sm text-[#5b6763] md:col-span-2">
                  <div className="text-xs uppercase tracking-[0.2em] text-black/38">消息内容</div>
                  <div className="mt-2 text-base font-semibold text-[#071110]">{selectedDelivery.payload.title || '-'}</div>
                  <div className="mt-2 leading-6">{selectedDelivery.payload.body || '-'}</div>
                  <div className="mt-2 break-all text-xs text-[#5b6763]">
                    Deeplink：{selectedDelivery.payload.deeplink || '-'}
                  </div>
                  {selectedDelivery.error ? (
                    <div className="mt-3 rounded-[16px] bg-[#fff1f0] px-3 py-2 text-xs leading-5 text-[#8b3a3a]">
                      错误：{selectedDelivery.error}
                    </div>
                  ) : null}
                </div>
              </div>
            </div>
          ) : null}

          {/* 分页 */}
          <div className="mt-5 flex flex-wrap items-center justify-between gap-3">
            <div className="text-xs text-[#5b6763]">每页 20 条</div>
            <div className="flex items-center gap-3">
              <div className="flex flex-wrap items-center gap-2">
                <button
                  disabled={(sectionPage?.pagination.page ?? 1) <= 1}
                  onClick={() => setSectionListPage((current) => Math.max(1, current - 1))}
                  className="rounded-full border border-[#d9e1de] bg-white px-4 py-2 text-xs font-semibold text-[#071110] disabled:opacity-40"
                >
                  上一页
                </button>
                {visiblePages.map((pageNumber) => (
                  <button
                    key={pageNumber}
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
                  disabled={(sectionPage?.pagination.page ?? 1) >= Math.max(1, sectionPage?.pagination.totalPages ?? 1)}
                  onClick={() => setSectionListPage((current) => Math.min(Math.max(1, sectionPage?.pagination.totalPages ?? 1), current + 1))}
                  className="rounded-full border border-[#d9e1de] bg-white px-4 py-2 text-xs font-semibold text-[#071110] disabled:opacity-40"
                >
                  下一页
                </button>
              </div>
              <div className="flex items-center gap-2 text-xs">
                <span>跳至</span>
                <input
                  value={jumpPageNum}
                  onChange={(e) => setJumpPageNum(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleJumpPage()}
                  className="w-12 rounded-lg border border-[#d9e1de] px-2 py-1 text-center"
                />
                <span>页</span>
              </div>
            </div>
          </div>
        </section>
      </section>
    </NotificationCenterWorkspaceLayout>
  );
}
