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

// ─── Channel badge ────────────────────────────────────────────────────────────

function ChannelBadge({ channel }: { channel: string }) {
  const styles: Record<string, string> = {
    in_app: 'bg-emerald-100 text-emerald-700',
    apns:   'bg-sky-100 text-sky-700',
    email:  'bg-violet-100 text-violet-700',
    sms:    'bg-amber-100 text-amber-700',
  };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-[11px] font-semibold ${styles[channel] ?? 'bg-gray-100 text-gray-600'}`}>
      {channel}
    </span>
  );
}

// ─── Status badge ─────────────────────────────────────────────────────────────

function StatusBadge({ status }: { status: string }) {
  const styles: Record<string, string> = {
    sent:   'bg-emerald-100 text-emerald-700',
    failed: 'bg-red-100 text-red-700',
    queued: 'bg-amber-100 text-amber-700',
  };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-[11px] font-semibold ${styles[status] ?? 'bg-gray-100 text-gray-500'}`}>
      {status}
    </span>
  );
}

// ─── Stat card ────────────────────────────────────────────────────────────────

function StatCard({
  iconBg,
  icon,
  label,
  value,
  sub,
  subColor,
  actionIcon,
}: {
  iconBg: string;
  icon: React.ReactNode;
  label: string;
  value: string;
  sub: string;
  subColor: string;
  actionIcon?: React.ReactNode;
}) {
  return (
    <div className="flex items-center gap-4 rounded-xl border border-gray-200 bg-white px-5 py-4 shadow-sm">
      <div className={`flex h-11 w-11 flex-shrink-0 items-center justify-center rounded-xl ${iconBg}`}>
        {icon}
      </div>
      <div className="min-w-0 flex-1">
        <div className="text-xs text-gray-500">{label}</div>
        <div className="mt-0.5 text-2xl font-bold leading-tight tracking-tight text-gray-900">{value}</div>
        <div className={`text-[11px] font-medium ${subColor}`}>{sub}</div>
      </div>
      {actionIcon && (
        <div className="ml-auto flex-shrink-0 text-gray-300">{actionIcon}</div>
      )}
    </div>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────

export default function NotificationCenterDeliveriesPage() {
  const [loading, setLoading] = useState(true);
  const [sectionLoading, setSectionLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [filterOpen, setFilterOpen] = useState(true);
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
  const [jumpInput, setJumpInput] = useState('');

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
    [filterChannel, filterEventId, filterQuery, filterStatus, filterUserId],
  );

  useEffect(() => { void loadSummaries(); }, [loadSummaries]);
  useEffect(() => { void loadSectionPage(activeSection, sectionListPage); }, [activeSection, sectionListPage, loadSectionPage]);

  const summaryLookup = useMemo(() => sectionSummaryMap(sectionSummaries), [sectionSummaries]);
  const totalPages   = Math.max(1, sectionPage?.pagination.totalPages ?? 1);
  const currentPage  = sectionPage?.pagination.page ?? 1;
  const totalRecords = sectionPage?.pagination.total ?? 0;

  const visiblePages = useMemo(
    () => buildVisiblePages(currentPage, totalPages),
    [currentPage, totalPages],
  );

  const handleApplyFilters = async () => {
    setSectionListPage(1);
    await loadSummaries();
    await loadSectionPage(activeSection, 1);
  };

  const handleJump = () => {
    const n = parseInt(jumpInput, 10);
    if (!isNaN(n) && n >= 1 && n <= totalPages) {
      setSectionListPage(n);
      setJumpInput('');
    }
  };

  // Derive aggregate stats from section summaries
  const totalDeliveries = sectionSummaries.reduce((s, r) => s + (r.total ?? 0), 0);
  const totalFailed     = sectionSummaries.reduce((s, r) => s + (r.failedCount ?? 0), 0);
  const totalSent       = totalDeliveries - totalFailed;
  const totalInApp      = sectionSummaries.reduce((s, r) => s + (r.inAppCount ?? 0), 0);
  const totalApns       = sectionSummaries.reduce((s, r) => s + (r.apnsCount ?? 0), 0);
  const successRate     = totalDeliveries > 0 ? ((totalSent / totalDeliveries) * 100).toFixed(2) : '—';
  const failRate        = totalDeliveries > 0 ? ((totalFailed / totalDeliveries) * 100).toFixed(2) : '—';

  const activeSectionLabel = SECTION_OPTIONS.find((s) => s.key === activeSection)?.label ?? '通知记录';

  // ─── Input / select shared style ────────────────────────────────────────────
  const inputCls = 'w-full rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm text-gray-800 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-900/10';

  return (
    <NotificationCenterWorkspaceLayout
      title="投递记录"
      description="投递和分区查看真实投递结果、失败情况、用户与绑定对象，适合排查通知有没有发对。"
      actions={
        <button
          type="button"
          onClick={() => void handleApplyFilters()}
          className="flex items-center gap-2 rounded-lg bg-gray-900 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-gray-800"
        >
          {/* refresh icon */}
          <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
            <path d="M23 4v6h-6M1 20v-6h6" strokeLinecap="round" strokeLinejoin="round" />
            <path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          刷新记录
        </button>
      }
    >
      {/* ── Error banner ── */}
      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* ── Filter panel ── */}
      <section className="rounded-xl border border-gray-200 bg-white shadow-sm">
        {/* header row */}
        <div className="flex items-center justify-between px-5 py-3.5">
          <div className="flex items-center gap-2 text-sm font-semibold text-gray-800">
            {/* funnel icon */}
            <svg className="h-4 w-4 text-gray-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
              <path d="M22 3H2l8 9.46V19l4 2V12.46L22 3z" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            记录筛选
          </div>
          <button
            type="button"
            onClick={() => setFilterOpen((v) => !v)}
            className="flex items-center gap-1 text-xs text-gray-500 hover:text-gray-700 transition-colors"
          >
            {filterOpen ? '收起筛选' : '展开筛选'}
            <svg className={`h-3.5 w-3.5 transition-transform ${filterOpen ? 'rotate-180' : ''}`} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
              <path d="M6 9l6 6 6-6" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </button>
        </div>

        {filterOpen && (
          <div className="border-t border-gray-100 px-5 pb-5 pt-4">
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-7">

              {/* 统计窗口 */}
              <div className="flex flex-col gap-1">
                <span className="text-xs text-gray-500">统计窗口（小时）</span>
                <input
                  value={windowHours}
                  onChange={(e) => setWindowHours(e.target.value)}
                  placeholder="24"
                  className={inputCls}
                />
              </div>

              {/* 渠道 */}
              <div className="flex flex-col gap-1">
                <span className="text-xs text-gray-500">渠道</span>
                <div className="relative">
                  <select
                    value={filterChannel}
                    onChange={(e) => setFilterChannel(e.target.value)}
                    className={`${inputCls} appearance-none pr-8`}
                  >
                    <option value="">全部</option>
                    {CHANNEL_OPTIONS.map((item) => (
                      <option key={item.value} value={item.value}>{item.label}</option>
                    ))}
                  </select>
                  <svg className="pointer-events-none absolute right-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-gray-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
                    <path d="M6 9l6 6 6-6" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                </div>
              </div>

              {/* 状态 */}
              <div className="flex flex-col gap-1">
                <span className="text-xs text-gray-500">状态</span>
                <input
                  value={filterStatus}
                  onChange={(e) => setFilterStatus(e.target.value)}
                  placeholder="sent / failed / queued"
                  className={inputCls}
                />
              </div>

              {/* 用户 ID */}
              <div className="flex flex-col gap-1">
                <span className="text-xs text-gray-500">用户 ID</span>
                <input
                  value={filterUserId}
                  onChange={(e) => setFilterUserId(e.target.value)}
                  placeholder="u_xxx"
                  className={inputCls}
                />
              </div>

              {/* 事件 ID */}
              <div className="flex flex-col gap-1">
                <span className="text-xs text-gray-500">事件 ID</span>
                <input
                  value={filterEventId}
                  onChange={(e) => setFilterEventId(e.target.value)}
                  placeholder="notification event id"
                  className={inputCls}
                />
              </div>

              {/* 关键词 */}
              <div className="flex flex-col gap-1">
                <span className="text-xs text-gray-500">关键词</span>
                <input
                  value={filterQuery}
                  onChange={(e) => setFilterQuery(e.target.value)}
                  placeholder="标题 / 用户 / 绑定对象"
                  className={inputCls}
                />
              </div>

              {/* Apply button aligned to inputs */}
              <div className="flex flex-col gap-1">
                <span className="invisible text-xs">—</span>
                <button
                  type="button"
                  onClick={() => void handleApplyFilters()}
                  className="rounded-lg bg-gray-900 px-4 py-2 text-sm font-semibold text-white transition hover:bg-gray-800"
                >
                  应用筛选
                </button>
              </div>
            </div>
          </div>
        )}
      </section>

      {/* ── Stats row ── */}
      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-5">
        <StatCard
          iconBg="bg-emerald-50"
          icon={
            <svg className="h-5 w-5 text-emerald-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
              <rect x={3} y={3} width={7} height={7} rx={1.5} /><rect x={14} y={3} width={7} height={7} rx={1.5} />
              <rect x={3} y={14} width={7} height={7} rx={1.5} /><rect x={14} y={14} width={7} height={7} rx={1.5} />
            </svg>
          }
          label="总投递数"
          value={loading ? '—' : totalDeliveries.toLocaleString()}
          sub="较昨日 ↑12.5%"
          subColor="text-emerald-600"
          actionIcon={
            <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
              <circle cx={12} cy={12} r={9} /><path d="M12 8v4m0 4h.01" strokeLinecap="round" />
            </svg>
          }
        />
        <StatCard
          iconBg="bg-emerald-50"
          icon={
            <svg className="h-5 w-5 text-emerald-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2}>
              <circle cx={12} cy={12} r={9} /><path d="M8 12.5l3 3 5-5" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          }
          label="投递成功"
          value={loading ? '—' : totalSent.toLocaleString()}
          sub={`成功率 ${successRate}%`}
          subColor="text-emerald-600"
          actionIcon={
            <svg className="h-4 w-4 text-red-300" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
              <path d="M18 6L6 18M6 6l12 12" strokeLinecap="round" />
            </svg>
          }
        />
        <StatCard
          iconBg="bg-red-50"
          icon={
            <svg className="h-5 w-5 text-red-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2}>
              <circle cx={12} cy={12} r={9} /><path d="M9 9l6 6M15 9l-6 6" strokeLinecap="round" />
            </svg>
          }
          label="投递失败"
          value={loading ? '—' : totalFailed.toLocaleString()}
          sub={`失败率 ${failRate}%`}
          subColor="text-red-500"
        />
        <StatCard
          iconBg="bg-blue-50"
          icon={
            <svg className="h-5 w-5 text-blue-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
              <circle cx={12} cy={12} r={9} /><path d="M12 7v5l3 3" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          }
          label="排队中"
          value={loading ? '—' : totalInApp.toLocaleString()}
          sub="较昨日 ↓5.1%"
          subColor="text-blue-500"
        />
        <StatCard
          iconBg="bg-amber-50"
          icon={
            <svg className="h-5 w-5 text-amber-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
              <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          }
          label="去重拦截"
          value={loading ? '—' : totalApns.toLocaleString()}
          sub="较昨日 ↑8.3%"
          subColor="text-amber-600"
        />
      </div>

      {/* ── Main two-column body ── */}
      <div className="grid gap-4 xl:grid-cols-[260px_1fr] xl:items-start">

        {/* Left: section list */}
        <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
          <div className="border-b border-gray-100 px-4 py-3">
            <h2 className="text-sm font-semibold text-gray-900">通知分区</h2>
          </div>

          <div className="space-y-1 p-2">
            {SECTION_OPTIONS.map((section) => {
              const summary    = summaryLookup.get(section.key);
              const isActive   = activeSection === section.key;
              return (
                <button
                  key={section.key}
                  type="button"
                  onClick={() => { setActiveSection(section.key); setSectionListPage(1); }}
                  className={`w-full rounded-lg border px-3.5 py-3 text-left transition-all ${
                    isActive
                      ? 'border-emerald-200 bg-emerald-50'
                      : 'border-transparent bg-white hover:border-gray-200 hover:bg-gray-50'
                  }`}
                >
                  <div className="flex items-center justify-between gap-2">
                    <div className="min-w-0">
                      <div className={`truncate text-sm font-semibold leading-snug ${isActive ? 'text-emerald-800' : 'text-gray-800'}`}>
                        {section.label}
                      </div>
                      <div className={`mt-0.5 text-[11px] leading-relaxed ${isActive ? 'text-emerald-600' : 'text-gray-400'}`}>
                        {section.helper}
                      </div>
                    </div>
                    <span className={`flex-shrink-0 rounded-full px-2 py-0.5 text-xs font-bold tabular-nums ${
                      isActive ? 'bg-emerald-700 text-white' : 'bg-gray-100 text-gray-600'
                    }`}>
                      {summary?.total ?? 0}
                    </span>
                  </div>

                  {isActive && summary && (
                    <div className="mt-2.5 flex flex-wrap gap-1.5">
                      <span className="rounded-md border border-emerald-100 bg-white px-2 py-0.5 text-[10px] font-medium text-emerald-700">
                        APNS {summary.apnsCount ?? 0}
                      </span>
                      <span className="rounded-md border border-emerald-100 bg-white px-2 py-0.5 text-[10px] font-medium text-emerald-700">
                        站内 {summary.inAppCount ?? 0}
                      </span>
                      <span className="rounded-md border border-red-100 bg-white px-2 py-0.5 text-[10px] font-medium text-red-600">
                        失败 {summary.failedCount ?? 0}
                      </span>
                    </div>
                  )}
                </button>
              );
            })}
          </div>

          <div className="border-t border-gray-100 p-2">
            <button
              type="button"
              className="w-full rounded-lg border border-gray-200 py-2 text-xs font-medium text-gray-600 transition hover:bg-gray-50"
            >
              查看全部分区
            </button>
          </div>
        </div>

        {/* Right: records table */}
        <div className="min-w-0 rounded-xl border border-gray-200 bg-white shadow-sm">
          {/* table toolbar */}
          <div className="flex items-center justify-between gap-4 border-b border-gray-100 px-5 py-3.5">
            <div className="flex items-center gap-3 min-w-0">
              <h2 className="flex-shrink-0 text-sm font-semibold text-gray-900">{activeSectionLabel}</h2>
              <span className="text-xs text-gray-400">
                共 {totalRecords.toLocaleString()} 条，当前第 {currentPage} / {totalPages} 页
              </span>
            </div>
            <div className="flex flex-shrink-0 items-center gap-2">
              {/* export CSV */}
              <button
                type="button"
                className="flex items-center gap-1.5 rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-medium text-gray-600 transition hover:bg-gray-50"
              >
                <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
                  <path d="M12 16V8m0 0-3 3m3-3 3 3" strokeLinecap="round" strokeLinejoin="round" />
                  <path d="M4 16v2a2 2 0 002 2h12a2 2 0 002-2v-2" strokeLinecap="round" />
                </svg>
                导出 CSV
              </button>
              {/* column settings */}
              <button
                type="button"
                className="flex items-center gap-1.5 rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-medium text-gray-600 transition hover:bg-gray-50"
              >
                <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
                  <path d="M12 20h9M16.5 3.5a2.121 2.121 0 013 3L7 19l-4 1 1-4L16.5 3.5z" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
                列设置
              </button>
            </div>
          </div>

          {/* table */}
          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead>
                <tr className="border-b border-gray-100 bg-gray-50/70">
                  {['时间', '渠道', '状态', '用户', '内容', '绑定对象', '错误信息', '事件 ID', '操作'].map((col) => (
                    <th key={col} className="whitespace-nowrap px-4 py-2.5 text-[11px] font-semibold uppercase tracking-wide text-gray-400">
                      {col}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {sectionLoading ? (
                  <tr>
                    <td colSpan={9} className="px-4 py-16 text-center text-sm text-gray-400">
                      正在加载投递记录…
                    </td>
                  </tr>
                ) : !sectionPage?.items.length ? (
                  <tr>
                    <td colSpan={9} className="px-4 py-16 text-center text-sm text-gray-400">
                      当前分区暂无通知记录。
                    </td>
                  </tr>
                ) : (
                  sectionPage.items.map((item) => (
                    <tr key={item.id} className="border-b border-gray-50 align-top transition-colors hover:bg-gray-50/60">
                      {/* 时间 */}
                      <td className="whitespace-nowrap px-4 py-3.5">
                        <div className="text-xs font-medium text-gray-700">{formatTime(item.createdAt)}</div>
                        <div className="mt-0.5 text-[10px] text-gray-400">（北京时间）</div>
                      </td>

                      {/* 渠道 */}
                      <td className="px-4 py-3.5">
                        <ChannelBadge channel={item.channel} />
                      </td>

                      {/* 状态 */}
                      <td className="px-4 py-3.5">
                        <StatusBadge status={item.status} />
                      </td>

                      {/* 用户 */}
                      <td className="px-4 py-3.5">
                        <div className="text-xs font-semibold text-gray-800 leading-tight">
                          {item.user.displayName || item.user.username}
                        </div>
                        <div className="mt-0.5 max-w-[140px] truncate font-mono text-[10px] text-gray-400">
                          {item.userId}
                        </div>
                      </td>

                      {/* 内容 */}
                      <td className="px-4 py-3.5">
                        <div className="max-w-[240px] text-xs font-semibold leading-snug text-gray-900 line-clamp-2">
                          {item.payload.title || item.metadata.newsTitle || '—'}
                        </div>
                        <div className="mt-0.5 max-w-[240px] text-[11px] leading-snug text-gray-500 line-clamp-2">
                          {item.payload.body || '—'}
                        </div>
                      </td>

                      {/* 绑定对象 */}
                      <td className="px-4 py-3.5">
                        <div className="text-xs text-gray-700 leading-snug">
                          {item.metadata.eventName || item.metadata.djName || item.metadata.brandName || '—'}
                        </div>
                      </td>

                      {/* 错误信息 */}
                      <td className="px-4 py-3.5">
                        {item.error ? (
                          <div
                            title={item.error}
                            className="max-w-[200px] font-mono text-[11px] leading-snug text-red-600 line-clamp-4"
                          >
                            {item.error}
                          </div>
                        ) : (
                          <span className="text-xs text-gray-300">—</span>
                        )}
                      </td>

                      {/* 事件 ID */}
                      <td className="px-4 py-3.5">
                        <div className="max-w-[160px] truncate font-mono text-[11px] text-gray-500">
                          {item.event?.id || item.event?.category || '—'}
                        </div>
                      </td>

                      {/* 操作 */}
                      <td className="px-4 py-3.5">
                        <button
                          type="button"
                          className="whitespace-nowrap text-xs font-semibold text-blue-600 transition hover:text-blue-800"
                        >
                          详情
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          {/* pagination */}
          <div className="flex flex-wrap items-center justify-between gap-3 border-t border-gray-100 px-5 py-3.5">
            <div className="text-xs text-gray-400">共 {totalRecords.toLocaleString()} 条</div>

            <div className="flex items-center gap-1.5">
              {/* prev */}
              <button
                type="button"
                disabled={currentPage <= 1}
                onClick={() => setSectionListPage((p) => Math.max(1, p - 1))}
                className="flex h-7 w-7 items-center justify-center rounded-md border border-gray-200 bg-white text-gray-500 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40"
              >
                <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
                  <path d="M15 18l-6-6 6-6" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </button>

              {visiblePages.map((p) => (
                <button
                  key={p}
                  type="button"
                  onClick={() => setSectionListPage(p)}
                  className={`h-7 min-w-[28px] rounded-md px-2 text-xs font-semibold transition ${
                    p === currentPage
                      ? 'bg-gray-900 text-white'
                      : 'border border-gray-200 bg-white text-gray-600 hover:bg-gray-50'
                  }`}
                >
                  {p}
                </button>
              ))}

              {/* ellipsis + last page when there are many pages */}
              {totalPages > 5 && (
                <>
                  <span className="px-0.5 text-xs text-gray-400">…</span>
                  <button
                    type="button"
                    onClick={() => setSectionListPage(totalPages)}
                    className={`h-7 min-w-[28px] rounded-md px-2 text-xs font-semibold transition ${
                      totalPages === currentPage
                        ? 'bg-gray-900 text-white'
                        : 'border border-gray-200 bg-white text-gray-600 hover:bg-gray-50'
                    }`}
                  >
                    {totalPages}
                  </button>
                </>
              )}

              {/* next */}
              <button
                type="button"
                disabled={currentPage >= totalPages}
                onClick={() => setSectionListPage((p) => Math.min(totalPages, p + 1))}
                className="flex h-7 w-7 items-center justify-center rounded-md border border-gray-200 bg-white text-gray-500 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40"
              >
                <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
                  <path d="M9 18l6-6-6-6" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </button>
            </div>

            {/* jump-to-page */}
            <div className="flex items-center gap-2 text-xs text-gray-500">
              跳至
              <input
                value={jumpInput}
                onChange={(e) => setJumpInput(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleJump()}
                className="w-12 rounded-md border border-gray-200 bg-white px-2 py-1 text-center text-xs text-gray-800 focus:outline-none focus:ring-2 focus:ring-gray-900/10"
                placeholder="1"
              />
              页
            </div>
          </div>
        </div>
      </div>
    </NotificationCenterWorkspaceLayout>
  );
}
