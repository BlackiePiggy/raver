'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import AdminAppShell from '@/components/admin/AdminAppShell';
import NotificationManualPublishConsole from '@/components/admin/NotificationManualPublishConsole';
import NotificationPublishTaskQueue from '@/components/admin/NotificationPublishTaskQueue';
import { useAuth } from '@/contexts/AuthContext';
import {
  NotificationCenterGlobalConfig,
  notificationCenterAdminApi,
  type NotificationAdminPublishTaskPage,
  type NotificationCenterDeliverySection,
  type NotificationCenterDeliverySectionPage,
  type NotificationCenterDeliverySectionSummary,
  type NotificationCenterStatusResponse,
  type NotificationCenterTemplateItem,
} from '@/lib/api/notification-center-admin';
import { formatDateTimeWithSystemTimeZoneLabel } from '@/lib/timezone';

const formatTime = (value?: string | null): string => {
  if (!value) return '-';
  return formatDateTimeWithSystemTimeZoneLabel(value);
};

const formatPercent = (value?: number): string => `${((value ?? 0) * 100).toFixed(1)}%`;

const trimValue = (value: string): string => value.trim();

const clampPercentage = (value: number): number => {
  if (!Number.isFinite(value)) return 100;
  const numeric = Math.floor(value);
  if (numeric < 0) return 0;
  if (numeric > 100) return 100;
  return numeric;
};

const clampInt = (value: number, fallback: number, min: number, max: number): number => {
  if (!Number.isFinite(value)) return fallback;
  const numeric = Math.floor(value);
  if (numeric < min) return min;
  if (numeric > max) return max;
  return numeric;
};

const CATEGORY_OPTIONS = [
  { value: 'chat_message', label: '聊天消息' },
  { value: 'community_interaction', label: '社区互动' },
  { value: 'event_countdown', label: '活动倒计时' },
  { value: 'event_daily_digest', label: '活动日报' },
  { value: 'route_dj_reminder', label: '路线 DJ 提醒' },
  { value: 'followed_dj_update', label: '关注 DJ 更新' },
  { value: 'followed_brand_update', label: '关注厂牌更新' },
  { value: 'account_enforcement', label: '账号处罚 / 申诉' },
  { value: 'content_review', label: '内容审核结果' },
  { value: 'report_decision', label: '举报处理结果' },
  { value: 'major_news', label: '重大资讯' },
] as const;

const CHANNEL_OPTIONS = [
  { value: 'in_app', label: '站内' },
  { value: 'apns', label: 'APNS' },
  { value: 'email', label: 'Email' },
  { value: 'sms', label: 'SMS' },
] as const;

const SECTION_OPTIONS: Array<{ key: NotificationCenterDeliverySection; label: string; helper: string }> = [
  { key: 'event_news', label: '活动资讯通知', helper: '活动关注用户收到的资讯更新通知' },
  { key: 'followed_dj_news', label: 'DJ 资讯通知', helper: '关注 DJ 用户收到的资讯更新通知' },
  { key: 'followed_brand_news', label: '厂牌资讯通知', helper: '关注厂牌用户收到的资讯更新通知' },
  { key: 'major_news_broadcast', label: '重大资讯广播', helper: '面向更广泛受众的资讯广播' },
  { key: 'event_schedule', label: '活动日程提醒', helper: '倒计时、日报、路线 DJ 提醒等时程类通知' },
  { key: 'chat_and_community', label: '聊天与社区', helper: '聊天消息、社区互动类通知' },
  { key: 'moderation_and_system', label: '审核与系统', helper: '内容审核、举报处理、账号处罚类通知' },
  { key: 'other', label: '其他通知', helper: '未归入以上分类的通知记录' },
];

const CATEGORY_VALUES = new Set(CATEGORY_OPTIONS.map((item) => item.value));
const CHANNEL_VALUES = new Set(CHANNEL_OPTIONS.map((item) => item.value));

const DEFAULT_GOVERNANCE: NotificationCenterGlobalConfig['governance'] = {
  rateLimit: {
    enabled: false,
    windowSeconds: 3600,
    maxPerUser: 60,
    exemptCategories: ['chat_message'],
  },
  quietHours: {
    enabled: false,
    startHour: 23,
    endHour: 8,
    timezone: 'Asia/Shanghai',
    muteChannels: ['apns'],
    exemptCategories: ['chat_message', 'route_dj_reminder'],
  },
};

const DEFAULT_TEMPLATE_FORM = {
  category: 'chat_message' as (typeof CATEGORY_OPTIONS)[number]['value'],
  locale: 'zh-CN',
  channel: 'apns' as (typeof CHANNEL_OPTIONS)[number]['value'],
  titleTemplate: '',
  bodyTemplate: '',
  deeplinkTemplate: '',
  variablesText: '',
  isActive: true,
};

const parseCommaValues = (value: string): string[] =>
  Array.from(
    new Set(
      value
        .split(',')
        .map((item) => item.trim())
        .filter(Boolean)
    )
  );

const normalizeConfigDraft = (config: NotificationCenterGlobalConfig): NotificationCenterGlobalConfig => ({
  ...config,
  governance: {
    rateLimit: {
      ...DEFAULT_GOVERNANCE.rateLimit,
      ...(config.governance?.rateLimit || {}),
    },
    quietHours: {
      ...DEFAULT_GOVERNANCE.quietHours,
      ...(config.governance?.quietHours || {}),
    },
  },
});

const toVariablesArray = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is string => typeof item === 'string')
    .map((item) => item.trim())
    .filter(Boolean);
};

const buildVisiblePages = (page: number, totalPages: number): number[] => {
  const safeTotalPages = Math.max(1, totalPages);
  const start = Math.max(1, Math.min(safeTotalPages - 4, page - 2));
  const end = Math.min(safeTotalPages, start + 4);
  return Array.from({ length: end - start + 1 }, (_, index) => start + index);
};

const sectionSummaryMap = (items: NotificationCenterDeliverySectionSummary[]) =>
  new Map(items.map((item) => [item.section, item]));

export default function NotificationCenterAdminPage() {
  const { user, isLoading } = useAuth();
  const isAdmin = user?.role === 'admin';

  const [loading, setLoading] = useState(true);
  const [sectionLoading, setSectionLoading] = useState(false);
  const [error, setError] = useState('');
  const [statusData, setStatusData] = useState<NotificationCenterStatusResponse | null>(null);
  const [templates, setTemplates] = useState<NotificationCenterTemplateItem[]>([]);
  const [configDraft, setConfigDraft] = useState<NotificationCenterGlobalConfig | null>(null);
  const [grayAllowUserIDsText, setGrayAllowUserIDsText] = useState('');
  const [rateLimitExemptCategoriesText, setRateLimitExemptCategoriesText] = useState('');
  const [quietHoursMuteChannelsText, setQuietHoursMuteChannelsText] = useState('');
  const [quietHoursExemptCategoriesText, setQuietHoursExemptCategoriesText] = useState('');
  const [savingConfig, setSavingConfig] = useState(false);
  const [savingTemplate, setSavingTemplate] = useState(false);
  const [templateForm, setTemplateForm] = useState(DEFAULT_TEMPLATE_FORM);
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
  const [publishTaskPage, setPublishTaskPage] = useState<NotificationAdminPublishTaskPage | null>(null);
  const [publishTaskListPage, setPublishTaskListPage] = useState(1);
  const [publishTaskLoading, setPublishTaskLoading] = useState(false);

  const loadSectionPage = useCallback(
    async (section: NotificationCenterDeliverySection, page: number) => {
      if (!isAdmin) return;
      try {
        setSectionLoading(true);
        const result = await notificationCenterAdminApi.getDeliveriesBySection({
          section,
          page,
          limit: 20,
          channel: filterChannel ? (filterChannel as (typeof CHANNEL_OPTIONS)[number]['value']) : undefined,
          status: trimValue(filterStatus) || undefined,
          userId: trimValue(filterUserId) || undefined,
          eventId: trimValue(filterEventId) || undefined,
          query: trimValue(filterQuery) || undefined,
        });
        setSectionPage(result);
      } catch (err: unknown) {
        setError(err instanceof Error ? err.message : '加载通知记录失败');
      } finally {
        setSectionLoading(false);
      }
    },
    [filterChannel, filterEventId, filterQuery, filterStatus, filterUserId, isAdmin]
  );

  const loadPublishTasks = useCallback(
    async (page: number) => {
      if (!isAdmin) return;
      try {
        setPublishTaskLoading(true);
        const result = await notificationCenterAdminApi.getPublishTasks({
          page,
          limit: 12,
          status: 'pending',
        });
        setPublishTaskPage(result);
      } catch (err: unknown) {
        setError(err instanceof Error ? err.message : '加载待决策通知任务失败');
      } finally {
        setPublishTaskLoading(false);
      }
    },
    [isAdmin]
  );

  const loadDashboard = useCallback(async () => {
    if (!isAdmin) {
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError('');
      const windowHoursNumeric = Number(windowHours) > 0 ? Number(windowHours) : 24;
      const [statusResult, templatesResult, summariesResult] = await Promise.all([
        notificationCenterAdminApi.getStatus(windowHoursNumeric),
        notificationCenterAdminApi.getTemplates({ limit: 200 }),
        notificationCenterAdminApi.getDeliverySections({
          channel: filterChannel ? (filterChannel as (typeof CHANNEL_OPTIONS)[number]['value']) : undefined,
          status: trimValue(filterStatus) || undefined,
          userId: trimValue(filterUserId) || undefined,
          eventId: trimValue(filterEventId) || undefined,
          query: trimValue(filterQuery) || undefined,
        }),
      ]);

      setStatusData(statusResult);
      setTemplates(templatesResult);
      setSectionSummaries(summariesResult);

      const normalizedConfig = normalizeConfigDraft(statusResult.config);
      setConfigDraft(normalizedConfig);
      setGrayAllowUserIDsText(normalizedConfig.grayRelease.allowUserIDs.join('\n'));
      setRateLimitExemptCategoriesText(normalizedConfig.governance.rateLimit.exemptCategories.join(','));
      setQuietHoursMuteChannelsText(normalizedConfig.governance.quietHours.muteChannels.join(','));
      setQuietHoursExemptCategoriesText(normalizedConfig.governance.quietHours.exemptCategories.join(','));
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : '加载通知中心数据失败');
    } finally {
      setLoading(false);
    }
  }, [filterChannel, filterEventId, filterQuery, filterStatus, filterUserId, isAdmin, windowHours]);

  useEffect(() => {
    void loadDashboard();
  }, [loadDashboard]);

  useEffect(() => {
    void loadSectionPage(activeSection, sectionListPage);
  }, [activeSection, loadSectionPage, sectionListPage]);

  useEffect(() => {
    void loadPublishTasks(publishTaskListPage);
  }, [loadPublishTasks, publishTaskListPage]);

  const channelStats = useMemo(() => {
    if (!statusData?.delivery.byChannel) return [];
    return Object.entries(statusData.delivery.byChannel).map(([channel, value]) => ({ channel, ...value }));
  }, [statusData]);

  const alertItems = useMemo(() => statusData?.delivery.alerts.items ?? [], [statusData]);

  const summaryLookup = useMemo(() => sectionSummaryMap(sectionSummaries), [sectionSummaries]);
  const visiblePages = useMemo(
    () => buildVisiblePages(sectionPage?.pagination.page ?? 1, sectionPage?.pagination.totalPages ?? 1),
    [sectionPage?.pagination.page, sectionPage?.pagination.totalPages]
  );

  const handleSaveConfig = async () => {
    if (!configDraft) return;
    try {
      setSavingConfig(true);
      setError('');
      const normalizedDraft = normalizeConfigDraft(configDraft);
      const allowUserIDs = Array.from(
        new Set(
          grayAllowUserIDsText
            .split('\n')
            .map((item) => item.trim())
            .filter(Boolean)
        )
      );
      const rateLimitExemptCategories = parseCommaValues(rateLimitExemptCategoriesText).filter((item) =>
        CATEGORY_VALUES.has(item as (typeof CATEGORY_OPTIONS)[number]['value'])
      ) as NotificationCenterGlobalConfig['governance']['rateLimit']['exemptCategories'];
      const quietHoursMuteChannels = parseCommaValues(quietHoursMuteChannelsText).filter((item) =>
        CHANNEL_VALUES.has(item as (typeof CHANNEL_OPTIONS)[number]['value'])
      ) as NotificationCenterGlobalConfig['governance']['quietHours']['muteChannels'];
      const quietHoursExemptCategories = parseCommaValues(quietHoursExemptCategoriesText).filter((item) =>
        CATEGORY_VALUES.has(item as (typeof CATEGORY_OPTIONS)[number]['value'])
      ) as NotificationCenterGlobalConfig['governance']['quietHours']['exemptCategories'];

      const payload: NotificationCenterGlobalConfig = {
        ...normalizedDraft,
        grayRelease: {
          ...normalizedDraft.grayRelease,
          percentage: clampPercentage(Number(normalizedDraft.grayRelease.percentage)),
          allowUserIDs,
        },
        governance: {
          rateLimit: {
            ...normalizedDraft.governance.rateLimit,
            windowSeconds: clampInt(Number(normalizedDraft.governance.rateLimit.windowSeconds), 3600, 30, 24 * 60 * 60),
            maxPerUser: clampInt(Number(normalizedDraft.governance.rateLimit.maxPerUser), 60, 1, 10000),
            exemptCategories: rateLimitExemptCategories.length > 0 ? rateLimitExemptCategories : ['chat_message'],
          },
          quietHours: {
            ...normalizedDraft.governance.quietHours,
            startHour: clampInt(Number(normalizedDraft.governance.quietHours.startHour), 23, 0, 23),
            endHour: clampInt(Number(normalizedDraft.governance.quietHours.endHour), 8, 0, 23),
            timezone: trimValue(normalizedDraft.governance.quietHours.timezone) || 'Asia/Shanghai',
            muteChannels: quietHoursMuteChannels.length > 0 ? quietHoursMuteChannels : ['apns'],
            exemptCategories:
              quietHoursExemptCategories.length > 0 ? quietHoursExemptCategories : ['chat_message', 'route_dj_reminder'],
          },
        },
      };

      const saved = await notificationCenterAdminApi.updateConfig(payload);
      const normalizedSaved = normalizeConfigDraft(saved);
      setConfigDraft(normalizedSaved);
      setGrayAllowUserIDsText(normalizedSaved.grayRelease.allowUserIDs.join('\n'));
      setRateLimitExemptCategoriesText(normalizedSaved.governance.rateLimit.exemptCategories.join(','));
      setQuietHoursMuteChannelsText(normalizedSaved.governance.quietHours.muteChannels.join(','));
      setQuietHoursExemptCategoriesText(normalizedSaved.governance.quietHours.exemptCategories.join(','));
      setStatusData((prev) => (prev ? { ...prev, config: normalizedSaved } : prev));
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : '保存配置失败');
    } finally {
      setSavingConfig(false);
    }
  };

  const handleSaveTemplate = async () => {
    try {
      setSavingTemplate(true);
      setError('');
      const variables = Array.from(
        new Set(
          templateForm.variablesText
            .split(',')
            .map((item) => item.trim())
            .filter(Boolean)
        )
      );
      await notificationCenterAdminApi.upsertTemplate({
        category: templateForm.category,
        locale: trimValue(templateForm.locale) || 'zh-CN',
        channel: templateForm.channel,
        titleTemplate: trimValue(templateForm.titleTemplate),
        bodyTemplate: trimValue(templateForm.bodyTemplate),
        deeplinkTemplate: trimValue(templateForm.deeplinkTemplate) || null,
        variables,
        isActive: templateForm.isActive,
      });
      const nextTemplates = await notificationCenterAdminApi.getTemplates({ limit: 200 });
      setTemplates(nextTemplates);
      setTemplateForm(DEFAULT_TEMPLATE_FORM);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : '保存模板失败');
    } finally {
      setSavingTemplate(false);
    }
  };

  const loadTemplateToForm = (template: NotificationCenterTemplateItem) => {
    setTemplateForm({
      category: template.category,
      locale: template.locale,
      channel: template.channel,
      titleTemplate: template.titleTemplate,
      bodyTemplate: template.bodyTemplate,
      deeplinkTemplate: template.deeplinkTemplate || '',
      variablesText: toVariablesArray(template.variables).join(','),
      isActive: template.isActive,
    });
  };

  const handleApplyFilters = async () => {
    setSectionListPage(1);
    await loadDashboard();
    await loadSectionPage(activeSection, 1);
  };

  if (isLoading) {
    return (
      <AdminAppShell title="通知中心后台" description="正在加载通知中心后台...">
        <div className="admin-shell-panel p-8 text-sm text-black/55">加载中...</div>
      </AdminAppShell>
    );
  }

  if (!user) {
    return (
      <AdminAppShell title="通知中心后台" description="请先登录管理员账号后访问通知中心后台。">
        <div className="admin-shell-panel mx-auto max-w-6xl p-8">
          <p className="text-lg">请先登录管理员账号后访问通知中心后台。</p>
          <Link href="/login" className="mt-4 inline-flex rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            去登录
          </Link>
        </div>
      </AdminAppShell>
    );
  }

  if (!isAdmin) {
    return (
      <AdminAppShell title="通知中心后台" description="当前账号无权限访问通知中心后台。">
        <div className="admin-shell-panel mx-auto max-w-6xl p-8">
          <p className="text-lg">当前账号无权限访问通知中心后台。</p>
        </div>
      </AdminAppShell>
    );
  }

  return (
    <AdminAppShell
      title="通知中心后台"
      eyebrow="Raver Admin / Notification Center"
      description="统一管理 APNS、资讯推送、时程提醒、社区通知与审核系统通知。"
    >
      <section className="space-y-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h1 className="text-3xl font-semibold text-[#071110]">通知中心后台</h1>
            <p className="mt-2 text-sm text-[#5b6763]">APNS 健康状态、通知全局治理、模板维护与通知记录分区管理。</p>
          </div>
          <div className="flex items-center gap-3">
            <Link
              href="/admin"
              className="rounded-full border border-[#d9e1de] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
            >
              返回运营总览
            </Link>
            <button
              type="button"
              onClick={() => void handleApplyFilters()}
              className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
            >
              刷新通知中心
            </button>
          </div>
        </div>

        {error ? (
          <div className="rounded-[24px] border border-[#f0d7d5] bg-[#fff7f6] px-4 py-3 text-sm text-[#8b3a3a]">
            {error}
          </div>
        ) : null}

        <section className="grid gap-4 xl:grid-cols-6">
          <article className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
            <div className="text-xs uppercase tracking-[0.24em] text-black/38">APNS</div>
            <div className="mt-3 text-2xl font-semibold text-[#071110]">{statusData?.apns.configured ? 'Ready' : 'Missing'}</div>
            <div className="mt-2 text-sm text-[#5b6763]">enabled: {statusData?.apns.enabled ? 'true' : 'false'}</div>
            <div className="text-sm text-[#5b6763]">sandbox: {statusData?.apns.useSandbox ? 'true' : 'false'}</div>
          </article>
          <article className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
            <div className="text-xs uppercase tracking-[0.24em] text-black/38">总投递</div>
            <div className="mt-3 text-2xl font-semibold text-[#071110]">{statusData?.delivery.totals.total ?? 0}</div>
            <div className="mt-2 text-sm text-[#5b6763]">sent: {statusData?.delivery.totals.sent ?? 0}</div>
            <div className="text-sm text-[#5b6763]">failed: {statusData?.delivery.totals.failed ?? 0}</div>
          </article>
          <article className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
            <div className="text-xs uppercase tracking-[0.24em] text-black/38">成功率</div>
            <div className="mt-3 text-2xl font-semibold text-[#071110]">
              {formatPercent(statusData?.delivery.rates.deliverySuccessRate)}
            </div>
            <div className="mt-2 text-sm text-[#5b6763]">failure: {formatPercent(statusData?.delivery.rates.deliveryFailureRate)}</div>
          </article>
          <article className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
            <div className="text-xs uppercase tracking-[0.24em] text-black/38">Inbox 打开率</div>
            <div className="mt-3 text-2xl font-semibold text-[#071110]">{formatPercent(statusData?.delivery.engagement.openRate)}</div>
            <div className="mt-2 text-sm text-[#5b6763]">
              {statusData?.delivery.engagement.inboxRead ?? 0} / {statusData?.delivery.engagement.inboxCreated ?? 0}
            </div>
          </article>
          <article className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
            <div className="text-xs uppercase tracking-[0.24em] text-black/38">退订率</div>
            <div className="mt-3 text-2xl font-semibold text-[#071110]">
              {formatPercent(statusData?.delivery.subscriptions.unsubscribeRate)}
            </div>
            <div className="mt-2 text-sm text-[#5b6763]">disabled: {statusData?.delivery.subscriptions.disabled ?? 0}</div>
          </article>
          <article className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
            <div className="text-xs uppercase tracking-[0.24em] text-black/38">统计窗口</div>
            <div className="mt-3 text-2xl font-semibold text-[#071110]">{statusData?.delivery.windowHours ?? 0}h</div>
            <div className="mt-2 text-sm text-[#5b6763]">since: {formatTime(statusData?.delivery.since)}</div>
          </article>
        </section>

        <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <div className="admin-studio-label">Record Filters</div>
              <h2 className="mt-2 text-xl font-semibold text-[#071110]">通知记录筛选</h2>
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
                placeholder="资讯标题 / 用户 / 绑定对象"
              />
            </label>
          </div>
        </section>

        <section className="grid gap-6 xl:grid-cols-[0.92fr_1.08fr]">
          <div className="space-y-6">
            <NotificationManualPublishConsole />

            <NotificationPublishTaskQueue
              page={publishTaskPage}
              loading={publishTaskLoading}
              pageValue={publishTaskListPage}
              onPageChange={setPublishTaskListPage}
              onReload={() => loadPublishTasks(publishTaskListPage)}
            />

            <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
              <div className="admin-studio-label">Delivery Sections</div>
              <h2 className="mt-2 text-xl font-semibold text-[#071110]">按通知类型查看记录</h2>
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
              <div className="admin-studio-label">Alerts</div>
              <h2 className="mt-2 text-xl font-semibold text-[#071110]">告警摘要</h2>
              <div className="mt-5 space-y-3">
                {alertItems.length ? (
                  alertItems.map((item) => (
                    <div key={item.code} className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] px-4 py-4">
                      <div className="flex flex-wrap items-center justify-between gap-3">
                        <div className="text-sm font-semibold text-[#071110]">{item.code}</div>
                        <span
                          className={`rounded-full px-3 py-1 text-[11px] font-semibold ${
                            item.triggered ? 'bg-[#fff1f0] text-[#8b3a3a]' : 'bg-[#eef6f0] text-[#315742]'
                          }`}
                        >
                          {item.triggered ? '已触发' : '正常'}
                        </span>
                      </div>
                      <div className="mt-2 text-sm leading-6 text-[#5b6763]">{item.message}</div>
                    </div>
                  ))
                ) : (
                  <div className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] px-4 py-4 text-sm text-[#5b6763]">
                    当前没有告警项。
                  </div>
                )}
              </div>
            </section>
          </div>

          <div className="space-y-6">
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
                      : '正在加载通知记录...'}
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

            <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
              <div className="admin-studio-label">Global Policy</div>
              <div className="mt-2 flex flex-wrap items-center justify-between gap-4">
                <h2 className="text-xl font-semibold text-[#071110]">全局开关与治理</h2>
                <button
                  type="button"
                  onClick={() => void handleSaveConfig()}
                  disabled={!configDraft || savingConfig}
                  className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white disabled:opacity-45"
                >
                  {savingConfig ? '保存中...' : '保存配置'}
                </button>
              </div>

              {configDraft ? (
                <div className="mt-5 space-y-5">
                  <div className="grid gap-4 md:grid-cols-2">
                    <div className="rounded-[24px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
                      <div className="text-sm font-semibold text-[#071110]">分类开关</div>
                      <div className="mt-3 space-y-2">
                        {CATEGORY_OPTIONS.map((item) => (
                          <label key={item.value} className="flex items-center justify-between rounded-[18px] border border-[#e7ece8] bg-white px-4 py-3 text-sm">
                            <span>{item.label}</span>
                            <input
                              type="checkbox"
                              checked={Boolean(configDraft.categorySwitches[item.value])}
                              onChange={(event) =>
                                setConfigDraft((prev) =>
                                  prev
                                    ? {
                                        ...prev,
                                        categorySwitches: {
                                          ...prev.categorySwitches,
                                          [item.value]: event.target.checked,
                                        },
                                      }
                                    : prev
                                )
                              }
                            />
                          </label>
                        ))}
                      </div>
                    </div>

                    <div className="rounded-[24px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
                      <div className="text-sm font-semibold text-[#071110]">渠道开关</div>
                      <div className="mt-3 space-y-2">
                        {CHANNEL_OPTIONS.map((item) => (
                          <label key={item.value} className="flex items-center justify-between rounded-[18px] border border-[#e7ece8] bg-white px-4 py-3 text-sm">
                            <span>{item.label}</span>
                            <input
                              type="checkbox"
                              checked={Boolean(configDraft.channelSwitches[item.value])}
                              onChange={(event) =>
                                setConfigDraft((prev) =>
                                  prev
                                    ? {
                                        ...prev,
                                        channelSwitches: {
                                          ...prev.channelSwitches,
                                          [item.value]: event.target.checked,
                                        },
                                      }
                                    : prev
                                )
                              }
                            />
                          </label>
                        ))}
                      </div>
                    </div>
                  </div>

                  <div className="grid gap-4 md:grid-cols-2">
                    <div className="rounded-[24px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
                      <div className="text-sm font-semibold text-[#071110]">灰度发布</div>
                      <div className="mt-3 grid gap-3">
                        <label className="text-sm text-[#5b6763]">
                          <div className="mb-2">是否启用</div>
                          <input
                            type="checkbox"
                            checked={configDraft.grayRelease.enabled}
                            onChange={(event) =>
                              setConfigDraft((prev) =>
                                prev
                                  ? {
                                      ...prev,
                                      grayRelease: {
                                        ...prev.grayRelease,
                                        enabled: event.target.checked,
                                      },
                                    }
                                  : prev
                              )
                            }
                          />
                        </label>
                        <label className="text-sm text-[#5b6763]">
                          灰度比例（0-100）
                          <input
                            type="number"
                            min={0}
                            max={100}
                            value={configDraft.grayRelease.percentage}
                            onChange={(event) =>
                              setConfigDraft((prev) =>
                                prev
                                  ? {
                                      ...prev,
                                      grayRelease: {
                                        ...prev.grayRelease,
                                        percentage: clampPercentage(Number(event.target.value)),
                                      },
                                    }
                                  : prev
                              )
                            }
                            className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-white px-4 py-3 text-sm text-[#071110]"
                          />
                        </label>
                        <label className="text-sm text-[#5b6763]">
                          灰度白名单用户（每行一个）
                          <textarea
                            value={grayAllowUserIDsText}
                            onChange={(event) => setGrayAllowUserIDsText(event.target.value)}
                            className="mt-2 h-24 w-full rounded-[18px] border border-[#d9e1de] bg-white px-4 py-3 text-sm text-[#071110]"
                            placeholder="u_xxx"
                          />
                        </label>
                      </div>
                    </div>

                    <div className="rounded-[24px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
                      <div className="text-sm font-semibold text-[#071110]">限频与静默时段</div>
                      <div className="mt-3 grid gap-3">
                        <label className="flex items-center justify-between rounded-[18px] border border-[#e7ece8] bg-white px-4 py-3 text-sm">
                          <span>启用限频</span>
                          <input
                            type="checkbox"
                            checked={configDraft.governance.rateLimit.enabled}
                            onChange={(event) =>
                              setConfigDraft((prev) =>
                                prev
                                  ? {
                                      ...prev,
                                      governance: {
                                        ...prev.governance,
                                        rateLimit: {
                                          ...prev.governance.rateLimit,
                                          enabled: event.target.checked,
                                        },
                                      },
                                    }
                                  : prev
                              )
                            }
                          />
                        </label>
                        <label className="text-sm text-[#5b6763]">
                          窗口秒数
                          <input
                            type="number"
                            min={30}
                            max={86400}
                            value={configDraft.governance.rateLimit.windowSeconds}
                            onChange={(event) =>
                              setConfigDraft((prev) =>
                                prev
                                  ? {
                                      ...prev,
                                      governance: {
                                        ...prev.governance,
                                        rateLimit: {
                                          ...prev.governance.rateLimit,
                                          windowSeconds: clampInt(Number(event.target.value), 3600, 30, 24 * 60 * 60),
                                        },
                                      },
                                    }
                                  : prev
                              )
                            }
                            className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-white px-4 py-3 text-sm text-[#071110]"
                          />
                        </label>
                        <label className="text-sm text-[#5b6763]">
                          单用户窗口最大通知数
                          <input
                            type="number"
                            min={1}
                            max={10000}
                            value={configDraft.governance.rateLimit.maxPerUser}
                            onChange={(event) =>
                              setConfigDraft((prev) =>
                                prev
                                  ? {
                                      ...prev,
                                      governance: {
                                        ...prev.governance,
                                        rateLimit: {
                                          ...prev.governance.rateLimit,
                                          maxPerUser: clampInt(Number(event.target.value), 60, 1, 10000),
                                        },
                                      },
                                    }
                                  : prev
                              )
                            }
                            className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-white px-4 py-3 text-sm text-[#071110]"
                          />
                        </label>
                        <label className="text-sm text-[#5b6763]">
                          限频豁免分类
                          <input
                            value={rateLimitExemptCategoriesText}
                            onChange={(event) => setRateLimitExemptCategoriesText(event.target.value)}
                            className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-white px-4 py-3 text-sm text-[#071110]"
                          />
                        </label>
                        <label className="text-sm text-[#5b6763]">
                          静默渠道
                          <input
                            value={quietHoursMuteChannelsText}
                            onChange={(event) => setQuietHoursMuteChannelsText(event.target.value)}
                            className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-white px-4 py-3 text-sm text-[#071110]"
                          />
                        </label>
                        <label className="text-sm text-[#5b6763]">
                          静默豁免分类
                          <input
                            value={quietHoursExemptCategoriesText}
                            onChange={(event) => setQuietHoursExemptCategoriesText(event.target.value)}
                            className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-white px-4 py-3 text-sm text-[#071110]"
                          />
                        </label>
                      </div>
                    </div>
                  </div>
                </div>
              ) : null}
            </section>

            <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
              <div className="admin-studio-label">Templates</div>
              <div className="mt-2 flex flex-wrap items-center justify-between gap-4">
                <h2 className="text-xl font-semibold text-[#071110]">通知模板</h2>
                <button
                  type="button"
                  onClick={() => void handleSaveTemplate()}
                  disabled={savingTemplate}
                  className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white disabled:opacity-45"
                >
                  {savingTemplate ? '保存中...' : '保存模板'}
                </button>
              </div>

              <div className="mt-5 grid gap-4 md:grid-cols-3">
                <label className="text-sm text-[#5b6763]">
                  分类
                  <select
                    value={templateForm.category}
                    onChange={(event) =>
                      setTemplateForm((prev) => ({ ...prev, category: event.target.value as typeof prev.category }))
                    }
                    className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                  >
                    {CATEGORY_OPTIONS.map((item) => (
                      <option key={item.value} value={item.value}>
                        {item.label}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="text-sm text-[#5b6763]">
                  语言
                  <input
                    value={templateForm.locale}
                    onChange={(event) => setTemplateForm((prev) => ({ ...prev, locale: event.target.value }))}
                    className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                  />
                </label>
                <label className="text-sm text-[#5b6763]">
                  渠道
                  <select
                    value={templateForm.channel}
                    onChange={(event) =>
                      setTemplateForm((prev) => ({ ...prev, channel: event.target.value as typeof prev.channel }))
                    }
                    className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                  >
                    {CHANNEL_OPTIONS.map((item) => (
                      <option key={item.value} value={item.value}>
                        {item.label}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="text-sm text-[#5b6763] md:col-span-3">
                  标题模板
                  <input
                    value={templateForm.titleTemplate}
                    onChange={(event) => setTemplateForm((prev) => ({ ...prev, titleTemplate: event.target.value }))}
                    className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                  />
                </label>
                <label className="text-sm text-[#5b6763] md:col-span-3">
                  内容模板
                  <textarea
                    value={templateForm.bodyTemplate}
                    onChange={(event) => setTemplateForm((prev) => ({ ...prev, bodyTemplate: event.target.value }))}
                    className="mt-2 h-24 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                  />
                </label>
                <label className="text-sm text-[#5b6763] md:col-span-3">
                  Deeplink 模板
                  <input
                    value={templateForm.deeplinkTemplate}
                    onChange={(event) => setTemplateForm((prev) => ({ ...prev, deeplinkTemplate: event.target.value }))}
                    className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                  />
                </label>
                <label className="text-sm text-[#5b6763] md:col-span-2">
                  变量列表（逗号分隔）
                  <input
                    value={templateForm.variablesText}
                    onChange={(event) => setTemplateForm((prev) => ({ ...prev, variablesText: event.target.value }))}
                    className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                  />
                </label>
                <label className="text-sm text-[#5b6763]">
                  启用
                  <div className="mt-4">
                    <input
                      type="checkbox"
                      checked={templateForm.isActive}
                      onChange={(event) => setTemplateForm((prev) => ({ ...prev, isActive: event.target.checked }))}
                    />
                  </div>
                </label>
              </div>

              <div className="mt-5 overflow-x-auto">
                <table className="min-w-full text-left text-sm">
                  <thead>
                    <tr className="border-b border-[#edf1ef] text-[#5b6763]">
                      <th className="px-3 py-3">分类</th>
                      <th className="px-3 py-3">语言</th>
                      <th className="px-3 py-3">渠道</th>
                      <th className="px-3 py-3">标题</th>
                      <th className="px-3 py-3">启用</th>
                      <th className="px-3 py-3">更新时间</th>
                      <th className="px-3 py-3">操作</th>
                    </tr>
                  </thead>
                  <tbody>
                    {templates.map((item) => (
                      <tr key={item.id} className="border-b border-[#f1f4f2]">
                        <td className="px-3 py-4">{item.category}</td>
                        <td className="px-3 py-4">{item.locale}</td>
                        <td className="px-3 py-4">{item.channel}</td>
                        <td className="px-3 py-4">{item.titleTemplate}</td>
                        <td className="px-3 py-4">{item.isActive ? 'true' : 'false'}</td>
                        <td className="px-3 py-4">{formatTime(item.updatedAt)}</td>
                        <td className="px-3 py-4">
                          <button
                            type="button"
                            onClick={() => loadTemplateToForm(item)}
                            className="rounded-full border border-[#d9e1de] px-4 py-2 text-xs font-semibold text-[#071110]"
                          >
                            编辑
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          </div>
        </section>

        <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
          <div className="admin-studio-label">Channel Stats</div>
          <h2 className="mt-2 text-xl font-semibold text-[#071110]">渠道统计</h2>
          <div className="mt-5 overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead>
                <tr className="border-b border-[#edf1ef] text-[#5b6763]">
                  <th className="px-3 py-3">channel</th>
                  <th className="px-3 py-3">total</th>
                  <th className="px-3 py-3">sent</th>
                  <th className="px-3 py-3">failed</th>
                  <th className="px-3 py-3">queued</th>
                </tr>
              </thead>
              <tbody>
                {channelStats.map((item) => (
                  <tr key={item.channel} className="border-b border-[#f1f4f2]">
                    <td className="px-3 py-4">{item.channel}</td>
                    <td className="px-3 py-4">{item.total}</td>
                    <td className="px-3 py-4">{item.sent}</td>
                    <td className="px-3 py-4">{item.failed}</td>
                    <td className="px-3 py-4">{item.queued}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </section>
    </AdminAppShell>
  );
}
