'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import {
  NotificationCenterGlobalConfig,
  notificationCenterAdminApi,
  NotificationCenterDeliveryItem,
  NotificationCenterStatusResponse,
  NotificationCenterTemplateItem,
} from '@/lib/api/notification-center-admin';

const formatTime = (value?: string | null): string => {
  if (!value) return '-';
  return new Date(value).toLocaleString('zh-CN', { hour12: false });
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
  { value: 'event_daily_digest', label: '活动日更' },
  { value: 'route_dj_reminder', label: '路线 DJ 提醒' },
  { value: 'followed_dj_update', label: '关注 DJ 动态' },
  { value: 'followed_brand_update', label: '关注品牌动态' },
  { value: 'major_news', label: '重大资讯' },
] as const;

const CHANNEL_OPTIONS = [
  { value: 'in_app', label: '站内' },
  { value: 'apns', label: 'APNs' },
  { value: 'openim', label: 'OpenIM' },
] as const;

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
    timezone: 'UTC',
    muteChannels: ['apns'],
    exemptCategories: ['chat_message', 'route_dj_reminder'],
  },
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

export default function NotificationCenterAdminPage() {
  const { user, isLoading } = useAuth();
  const isAdmin = user?.role === 'admin';

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [statusData, setStatusData] = useState<NotificationCenterStatusResponse | null>(null);
  const [deliveries, setDeliveries] = useState<NotificationCenterDeliveryItem[]>([]);
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
  const [filterLimit, setFilterLimit] = useState('50');

  const loadData = useCallback(async () => {
    if (!isAdmin) {
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError('');
      const windowHoursNumeric = Number(windowHours) > 0 ? Number(windowHours) : 24;
      const deliveriesLimit = Number(filterLimit) > 0 ? Number(filterLimit) : 50;
      const [statusResult, deliveriesResult, templatesResult] = await Promise.all([
        notificationCenterAdminApi.getStatus(windowHoursNumeric),
        notificationCenterAdminApi.getDeliveries({
          limit: deliveriesLimit,
          channel: filterChannel ? (filterChannel as 'in_app' | 'apns' | 'openim') : undefined,
          status: trimValue(filterStatus) || undefined,
          userId: trimValue(filterUserId) || undefined,
          eventId: trimValue(filterEventId) || undefined,
        }),
        notificationCenterAdminApi.getTemplates({ limit: 200 }),
      ]);
      setStatusData(statusResult);
      setDeliveries(deliveriesResult);
      setTemplates(templatesResult);
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
  }, [filterChannel, filterEventId, filterLimit, filterStatus, filterUserId, isAdmin, windowHours]);

  useEffect(() => {
    void loadData();
  }, [loadData]);

  const channelStats = useMemo(() => {
    if (!statusData?.delivery.byChannel) return [];
    return Object.entries(statusData.delivery.byChannel).map(([channel, value]) => ({ channel, ...value }));
  }, [statusData]);

  const alertItems = useMemo(() => statusData?.delivery.alerts.items ?? [], [statusData]);

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
            timezone: trimValue(normalizedDraft.governance.quietHours.timezone) || 'UTC',
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

  if (isLoading) {
    return (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <div className="mx-auto max-w-6xl px-6 pt-28">加载中...</div>
      </main>
    );
  }

  if (!user) {
    return (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <div className="mx-auto max-w-6xl px-6 pt-28">
          <p className="text-lg">请先登录管理员账号后访问通知中心后台。</p>
          <Link href="/login" className="mt-4 inline-block rounded-lg bg-primary-blue px-4 py-2 text-white">
            去登录
          </Link>
        </div>
      </main>
    );
  }

  if (!isAdmin) {
    return (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <div className="mx-auto max-w-6xl px-6 pt-28">
          <p className="text-lg">当前账号无权限访问通知中心后台。</p>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-bg-primary text-text-primary">
      <Navigation />
      <section className="mx-auto max-w-7xl px-6 pb-12 pt-24 space-y-5">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h1 className="text-3xl font-semibold">通知中心后台</h1>
            <p className="mt-2 text-text-secondary">APNs 配置诊断与通知投递明细</p>
          </div>
          <button
            type="button"
            onClick={() => void loadData()}
            className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue"
          >
            刷新
          </button>
        </div>

        {error && <div className="rounded-lg border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300">{error}</div>}

        <div className="grid gap-4 rounded-lg border border-border-secondary bg-bg-secondary p-4 md:grid-cols-4">
          <label className="text-sm text-text-secondary">
            统计窗口（小时）
            <input
              value={windowHours}
              onChange={(event) => setWindowHours(event.target.value)}
              className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
              placeholder="24"
            />
          </label>

          <label className="text-sm text-text-secondary">
            渠道筛选
            <select
              value={filterChannel}
              onChange={(event) => setFilterChannel(event.target.value)}
              className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
            >
              <option value="">全部</option>
              <option value="apns">apns</option>
              <option value="in_app">in_app</option>
              <option value="openim">openim</option>
            </select>
          </label>

          <label className="text-sm text-text-secondary">
            状态筛选
            <input
              value={filterStatus}
              onChange={(event) => setFilterStatus(event.target.value)}
              className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
              placeholder="sent / failed / queued"
            />
          </label>

          <label className="text-sm text-text-secondary">
            明细条数
            <input
              value={filterLimit}
              onChange={(event) => setFilterLimit(event.target.value)}
              className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
              placeholder="50"
            />
          </label>

          <label className="text-sm text-text-secondary md:col-span-2">
            用户 ID
            <input
              value={filterUserId}
              onChange={(event) => setFilterUserId(event.target.value)}
              className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
              placeholder="u_xxx"
            />
          </label>

          <label className="text-sm text-text-secondary md:col-span-2">
            事件 ID
            <input
              value={filterEventId}
              onChange={(event) => setFilterEventId(event.target.value)}
              className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
              placeholder="event id"
            />
          </label>
        </div>

        <section className="rounded-lg border border-border-secondary bg-bg-secondary p-4 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold">全局开关与灰度</h2>
            <button
              type="button"
              onClick={() => void handleSaveConfig()}
              disabled={!configDraft || savingConfig}
              className="rounded-md bg-primary-blue px-4 py-2 text-sm text-white disabled:opacity-60"
            >
              {savingConfig ? '保存中...' : '保存配置'}
            </button>
          </div>

          {configDraft && (
            <>
              <div className="grid gap-4 md:grid-cols-2">
                <div>
                  <div className="text-sm text-text-secondary mb-2">分类开关</div>
                  <div className="space-y-2">
                    {CATEGORY_OPTIONS.map((item) => (
                      <label key={item.value} className="flex items-center justify-between rounded-md border border-border-secondary px-3 py-2">
                        <span className="text-sm">{item.label}</span>
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

                <div>
                  <div className="text-sm text-text-secondary mb-2">渠道开关</div>
                  <div className="space-y-2">
                    {CHANNEL_OPTIONS.map((item) => (
                      <label key={item.value} className="flex items-center justify-between rounded-md border border-border-secondary px-3 py-2">
                        <span className="text-sm">{item.label}</span>
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

              <div className="grid gap-4 md:grid-cols-3">
                <label className="text-sm text-text-secondary">
                  灰度启用
                  <div className="mt-2">
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
                  </div>
                </label>
                <label className="text-sm text-text-secondary">
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
                    className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                  />
                </label>
                <label className="text-sm text-text-secondary md:col-span-3">
                  灰度白名单用户（每行一个 userId）
                  <textarea
                    value={grayAllowUserIDsText}
                    onChange={(event) => setGrayAllowUserIDsText(event.target.value)}
                    className="mt-2 h-24 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                    placeholder="u_xxx"
                  />
                </label>
              </div>

              <div className="grid gap-4 md:grid-cols-2">
                <div className="rounded-md border border-border-secondary p-3 space-y-3">
                  <div className="text-sm text-text-secondary">限频策略</div>
                  <label className="flex items-center justify-between text-sm">
                    <span>启用</span>
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
                  <label className="text-sm text-text-secondary">
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
                      className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                    />
                  </label>
                  <label className="text-sm text-text-secondary">
                    单用户窗口内最大通知数
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
                      className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                    />
                  </label>
                  <label className="text-sm text-text-secondary">
                    限频豁免分类（逗号分隔）
                    <input
                      value={rateLimitExemptCategoriesText}
                      onChange={(event) => setRateLimitExemptCategoriesText(event.target.value)}
                      className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                      placeholder="chat_message"
                    />
                  </label>
                </div>

                <div className="rounded-md border border-border-secondary p-3 space-y-3">
                  <div className="text-sm text-text-secondary">免打扰与静默渠道</div>
                  <label className="flex items-center justify-between text-sm">
                    <span>启用</span>
                    <input
                      type="checkbox"
                      checked={configDraft.governance.quietHours.enabled}
                      onChange={(event) =>
                        setConfigDraft((prev) =>
                          prev
                            ? {
                                ...prev,
                                governance: {
                                  ...prev.governance,
                                  quietHours: {
                                    ...prev.governance.quietHours,
                                    enabled: event.target.checked,
                                  },
                                },
                              }
                            : prev
                        )
                      }
                    />
                  </label>
                  <div className="grid gap-3 grid-cols-2">
                    <label className="text-sm text-text-secondary">
                      开始小时（0-23）
                      <input
                        type="number"
                        min={0}
                        max={23}
                        value={configDraft.governance.quietHours.startHour}
                        onChange={(event) =>
                          setConfigDraft((prev) =>
                            prev
                              ? {
                                  ...prev,
                                  governance: {
                                    ...prev.governance,
                                    quietHours: {
                                      ...prev.governance.quietHours,
                                      startHour: clampInt(Number(event.target.value), 23, 0, 23),
                                    },
                                  },
                                }
                              : prev
                          )
                        }
                        className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                      />
                    </label>
                    <label className="text-sm text-text-secondary">
                      结束小时（0-23）
                      <input
                        type="number"
                        min={0}
                        max={23}
                        value={configDraft.governance.quietHours.endHour}
                        onChange={(event) =>
                          setConfigDraft((prev) =>
                            prev
                              ? {
                                  ...prev,
                                  governance: {
                                    ...prev.governance,
                                    quietHours: {
                                      ...prev.governance.quietHours,
                                      endHour: clampInt(Number(event.target.value), 8, 0, 23),
                                    },
                                  },
                                }
                              : prev
                          )
                        }
                        className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                      />
                    </label>
                  </div>
                  <label className="text-sm text-text-secondary">
                    时区
                    <input
                      value={configDraft.governance.quietHours.timezone}
                      onChange={(event) =>
                        setConfigDraft((prev) =>
                          prev
                            ? {
                                ...prev,
                                governance: {
                                  ...prev.governance,
                                  quietHours: {
                                    ...prev.governance.quietHours,
                                    timezone: event.target.value,
                                  },
                                },
                              }
                            : prev
                        )
                      }
                      className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                      placeholder="UTC"
                    />
                  </label>
                  <label className="text-sm text-text-secondary">
                    静默渠道（逗号分隔）
                    <input
                      value={quietHoursMuteChannelsText}
                      onChange={(event) => setQuietHoursMuteChannelsText(event.target.value)}
                      className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                      placeholder="apns"
                    />
                  </label>
                  <label className="text-sm text-text-secondary">
                    免打扰豁免分类（逗号分隔）
                    <input
                      value={quietHoursExemptCategoriesText}
                      onChange={(event) => setQuietHoursExemptCategoriesText(event.target.value)}
                      className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                      placeholder="chat_message,route_dj_reminder"
                    />
                  </label>
                </div>
              </div>
            </>
          )}
        </section>

        <div className="grid gap-4 md:grid-cols-3 xl:grid-cols-6">
          <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
            <div className="text-xs text-text-secondary">APNs</div>
            <div className="mt-2 text-sm">enabled: {statusData?.apns.enabled ? 'true' : 'false'}</div>
            <div className="text-sm">configured: {statusData?.apns.configured ? 'true' : 'false'}</div>
            <div className="text-sm">sandbox: {statusData?.apns.useSandbox ? 'true' : 'false'}</div>
            <div className="mt-2 text-xs text-text-secondary break-all">bundle: {statusData?.apns.bundleId || '-'}</div>
          </div>
          <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
            <div className="text-xs text-text-secondary">总投递</div>
            <div className="mt-2 text-2xl font-semibold">{statusData?.delivery.totals.total ?? 0}</div>
            <div className="text-sm text-green-400">sent: {statusData?.delivery.totals.sent ?? 0}</div>
            <div className="text-sm text-red-400">failed: {statusData?.delivery.totals.failed ?? 0}</div>
            <div className="text-sm text-yellow-400">queued: {statusData?.delivery.totals.queued ?? 0}</div>
          </div>
          <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
            <div className="text-xs text-text-secondary">时间窗口</div>
            <div className="mt-2 text-sm">{statusData?.delivery.windowHours ?? 0} 小时</div>
            <div className="text-xs text-text-secondary mt-2">since: {formatTime(statusData?.delivery.since)}</div>
            <div className="text-xs text-text-secondary mt-2">token cache: {statusData?.apns.tokenCache.active ? 'active' : 'inactive'}</div>
            <div className="text-xs text-text-secondary mt-2">
              alerts: {statusData?.delivery.alerts.triggeredCount ?? 0}
            </div>
          </div>
          <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
            <div className="text-xs text-text-secondary">投递成功率</div>
            <div className="mt-2 text-2xl font-semibold text-green-400">
              {formatPercent(statusData?.delivery.rates.deliverySuccessRate)}
            </div>
            <div className="text-xs text-text-secondary mt-2">
              failure: {formatPercent(statusData?.delivery.rates.deliveryFailureRate)}
            </div>
          </div>
          <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
            <div className="text-xs text-text-secondary">打开率（Inbox）</div>
            <div className="mt-2 text-2xl font-semibold text-primary-blue">
              {formatPercent(statusData?.delivery.engagement.openRate)}
            </div>
            <div className="text-xs text-text-secondary mt-2">
              read: {statusData?.delivery.engagement.inboxRead ?? 0} / created: {statusData?.delivery.engagement.inboxCreated ?? 0}
            </div>
          </div>
          <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
            <div className="text-xs text-text-secondary">退订率（订阅快照）</div>
            <div className="mt-2 text-2xl font-semibold text-orange-300">
              {formatPercent(statusData?.delivery.subscriptions.unsubscribeRate)}
            </div>
            <div className="text-xs text-text-secondary mt-2">
              disabled: {statusData?.delivery.subscriptions.disabled ?? 0} / total: {statusData?.delivery.subscriptions.total ?? 0}
            </div>
            <div className="text-xs text-text-secondary">
              window changed: {statusData?.delivery.subscriptions.disabledUpdatedInWindow ?? 0}
            </div>
          </div>
        </div>

        <section className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
          <h2 className="text-lg font-semibold">告警摘要</h2>
          {alertItems.length === 0 ? (
            <div className="mt-3 text-sm text-text-secondary">暂无告警规则</div>
          ) : (
            <div className="mt-3 overflow-x-auto">
              <table className="min-w-full text-left text-sm">
                <thead>
                  <tr className="border-b border-border-secondary text-text-secondary">
                    <th className="px-2 py-2">code</th>
                    <th className="px-2 py-2">severity</th>
                    <th className="px-2 py-2">triggered</th>
                    <th className="px-2 py-2">value</th>
                    <th className="px-2 py-2">threshold</th>
                    <th className="px-2 py-2">message</th>
                  </tr>
                </thead>
                <tbody>
                  {alertItems.map((item) => (
                    <tr key={item.code} className="border-b border-border-secondary/50">
                      <td className="px-2 py-2">{item.code}</td>
                      <td
                        className={`px-2 py-2 ${
                          item.severity === 'high'
                            ? 'text-red-400'
                            : item.severity === 'medium'
                              ? 'text-yellow-400'
                              : 'text-text-secondary'
                        }`}
                      >
                        {item.severity}
                      </td>
                      <td className={`px-2 py-2 ${item.triggered ? 'text-red-300' : 'text-green-400'}`}>
                        {item.triggered ? 'yes' : 'no'}
                      </td>
                      <td className="px-2 py-2">{item.value}</td>
                      <td className="px-2 py-2">{item.threshold}</td>
                      <td className="px-2 py-2">{item.message}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>

        <section className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
          <h2 className="text-lg font-semibold">渠道统计</h2>
          {channelStats.length === 0 ? (
            <div className="mt-3 text-sm text-text-secondary">{loading ? '加载中...' : '暂无统计数据'}</div>
          ) : (
            <div className="mt-3 overflow-x-auto">
              <table className="min-w-full text-left text-sm">
                <thead>
                  <tr className="border-b border-border-secondary text-text-secondary">
                    <th className="px-2 py-2">channel</th>
                    <th className="px-2 py-2">total</th>
                    <th className="px-2 py-2">sent</th>
                    <th className="px-2 py-2">failed</th>
                    <th className="px-2 py-2">queued</th>
                  </tr>
                </thead>
                <tbody>
                  {channelStats.map((item) => (
                    <tr key={item.channel} className="border-b border-border-secondary/50">
                      <td className="px-2 py-2">{item.channel}</td>
                      <td className="px-2 py-2">{item.total}</td>
                      <td className="px-2 py-2 text-green-400">{item.sent}</td>
                      <td className="px-2 py-2 text-red-400">{item.failed}</td>
                      <td className="px-2 py-2 text-yellow-400">{item.queued}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>

        <section className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
          <h2 className="text-lg font-semibold">投递明细</h2>
          <div className="mt-3 overflow-x-auto">
            <table className="min-w-full text-left text-xs">
              <thead>
                <tr className="border-b border-border-secondary text-text-secondary">
                  <th className="px-2 py-2">time</th>
                  <th className="px-2 py-2">channel</th>
                  <th className="px-2 py-2">status</th>
                  <th className="px-2 py-2">user</th>
                  <th className="px-2 py-2">event</th>
                  <th className="px-2 py-2">attempts</th>
                  <th className="px-2 py-2">error</th>
                </tr>
              </thead>
              <tbody>
                {deliveries.map((item) => (
                  <tr key={item.id} className="border-b border-border-secondary/50">
                    <td className="px-2 py-2">{formatTime(item.createdAt)}</td>
                    <td className="px-2 py-2">{item.channel}</td>
                    <td className="px-2 py-2">
                      <span
                        className={
                          item.status === 'sent'
                            ? 'text-green-400'
                            : item.status === 'failed'
                              ? 'text-red-400'
                              : 'text-yellow-400'
                        }
                      >
                        {item.status}
                      </span>
                    </td>
                    <td className="px-2 py-2">
                      {item.user.displayName || item.user.username}
                      <div className="text-text-secondary">{item.userId}</div>
                    </td>
                    <td className="px-2 py-2">
                      {item.event.category}
                      <div className="text-text-secondary break-all">{item.eventId}</div>
                    </td>
                    <td className="px-2 py-2">{item.attempts}</td>
                    <td className="px-2 py-2 break-all text-text-secondary">{item.error || '-'}</td>
                  </tr>
                ))}
                {deliveries.length === 0 && !loading && (
                  <tr>
                    <td colSpan={7} className="px-2 py-6 text-center text-text-secondary">
                      暂无明细
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>

        <section className="rounded-lg border border-border-secondary bg-bg-secondary p-4 space-y-4">
          <h2 className="text-lg font-semibold">通知模板</h2>
          <div className="grid gap-3 md:grid-cols-3">
            <label className="text-sm text-text-secondary">
              分类
              <select
                value={templateForm.category}
                onChange={(event) =>
                  setTemplateForm((prev) => ({ ...prev, category: event.target.value as typeof prev.category }))
                }
                className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
              >
                {CATEGORY_OPTIONS.map((item) => (
                  <option key={item.value} value={item.value}>
                    {item.label}
                  </option>
                ))}
              </select>
            </label>
            <label className="text-sm text-text-secondary">
              语言
              <input
                value={templateForm.locale}
                onChange={(event) => setTemplateForm((prev) => ({ ...prev, locale: event.target.value }))}
                className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                placeholder="zh-CN"
              />
            </label>
            <label className="text-sm text-text-secondary">
              渠道
              <select
                value={templateForm.channel}
                onChange={(event) =>
                  setTemplateForm((prev) => ({ ...prev, channel: event.target.value as typeof prev.channel }))
                }
                className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
              >
                {CHANNEL_OPTIONS.map((item) => (
                  <option key={item.value} value={item.value}>
                    {item.label}
                  </option>
                ))}
              </select>
            </label>
            <label className="text-sm text-text-secondary md:col-span-3">
              标题模板
              <input
                value={templateForm.titleTemplate}
                onChange={(event) => setTemplateForm((prev) => ({ ...prev, titleTemplate: event.target.value }))}
                className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                placeholder="你有一条新消息"
              />
            </label>
            <label className="text-sm text-text-secondary md:col-span-3">
              内容模板
              <textarea
                value={templateForm.bodyTemplate}
                onChange={(event) => setTemplateForm((prev) => ({ ...prev, bodyTemplate: event.target.value }))}
                className="mt-2 h-20 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                placeholder="{{senderName}}: {{messagePreview}}"
              />
            </label>
            <label className="text-sm text-text-secondary md:col-span-3">
              Deep Link 模板
              <input
                value={templateForm.deeplinkTemplate}
                onChange={(event) => setTemplateForm((prev) => ({ ...prev, deeplinkTemplate: event.target.value }))}
                className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                placeholder="raver://messages/conversation/{{conversationId}}"
              />
            </label>
            <label className="text-sm text-text-secondary md:col-span-2">
              变量列表（逗号分隔）
              <input
                value={templateForm.variablesText}
                onChange={(event) => setTemplateForm((prev) => ({ ...prev, variablesText: event.target.value }))}
                className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                placeholder="senderName,messagePreview,conversationId"
              />
            </label>
            <label className="text-sm text-text-secondary">
              启用
              <div className="mt-2">
                <input
                  type="checkbox"
                  checked={templateForm.isActive}
                  onChange={(event) => setTemplateForm((prev) => ({ ...prev, isActive: event.target.checked }))}
                />
              </div>
            </label>
          </div>

          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => void handleSaveTemplate()}
              disabled={savingTemplate}
              className="rounded-md bg-primary-blue px-4 py-2 text-sm text-white disabled:opacity-60"
            >
              {savingTemplate ? '保存中...' : '保存模板'}
            </button>
            <button
              type="button"
              onClick={() => setTemplateForm(DEFAULT_TEMPLATE_FORM)}
              className="rounded-md border border-border-secondary px-4 py-2 text-sm"
            >
              清空
            </button>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-xs">
              <thead>
                <tr className="border-b border-border-secondary text-text-secondary">
                  <th className="px-2 py-2">分类</th>
                  <th className="px-2 py-2">语言</th>
                  <th className="px-2 py-2">渠道</th>
                  <th className="px-2 py-2">标题</th>
                  <th className="px-2 py-2">启用</th>
                  <th className="px-2 py-2">更新时间</th>
                  <th className="px-2 py-2">操作</th>
                </tr>
              </thead>
              <tbody>
                {templates.map((item) => (
                  <tr key={item.id} className="border-b border-border-secondary/50">
                    <td className="px-2 py-2">{item.category}</td>
                    <td className="px-2 py-2">{item.locale}</td>
                    <td className="px-2 py-2">{item.channel}</td>
                    <td className="px-2 py-2 max-w-[260px] truncate">{item.titleTemplate}</td>
                    <td className="px-2 py-2">{item.isActive ? 'true' : 'false'}</td>
                    <td className="px-2 py-2">{formatTime(item.updatedAt)}</td>
                    <td className="px-2 py-2">
                      <button
                        type="button"
                        onClick={() => loadTemplateToForm(item)}
                        className="rounded border border-border-secondary px-2 py-1 hover:border-primary-blue hover:text-primary-blue"
                      >
                        编辑
                      </button>
                    </td>
                  </tr>
                ))}
                {templates.length === 0 && !loading && (
                  <tr>
                    <td colSpan={7} className="px-2 py-6 text-center text-text-secondary">
                      暂无模板
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
      </section>
    </main>
  );
}
