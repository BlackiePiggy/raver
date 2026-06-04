'use client';

import { useCallback, useEffect, useState } from 'react';
import NotificationCenterWorkspaceLayout from '@/components/admin/NotificationCenterWorkspaceLayout';
import {
  CATEGORY_OPTIONS,
  CATEGORY_VALUES,
  CHANNEL_OPTIONS,
  CHANNEL_VALUES,
  clampInt,
  clampPercentage,
  normalizeConfigDraft,
  parseCommaValues,
} from '@/components/admin/notification-center/shared';
import {
  notificationCenterAdminApi,
  type NotificationCenterGlobalConfig,
} from '@/lib/api/notification-center-admin';

export default function NotificationCenterGovernancePage() {
  const [configDraft, setConfigDraft] = useState<NotificationCenterGlobalConfig | null>(null);
  const [grayAllowUserIDsText, setGrayAllowUserIDsText] = useState('');
  const [rateLimitExemptCategoriesText, setRateLimitExemptCategoriesText] = useState('');
  const [quietHoursMuteChannelsText, setQuietHoursMuteChannelsText] = useState('');
  const [quietHoursExemptCategoriesText, setQuietHoursExemptCategoriesText] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadConfig = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const config = await notificationCenterAdminApi.getConfig();
      const normalized = normalizeConfigDraft(config);
      setConfigDraft(normalized);
      setGrayAllowUserIDsText(normalized.grayRelease.allowUserIDs.join('\n'));
      setRateLimitExemptCategoriesText(normalized.governance.rateLimit.exemptCategories.join(','));
      setQuietHoursMuteChannelsText(normalized.governance.quietHours.muteChannels.join(','));
      setQuietHoursExemptCategoriesText(normalized.governance.quietHours.exemptCategories.join(','));
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载治理配置失败');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadConfig();
  }, [loadConfig]);

  const handleSaveConfig = async () => {
    if (!configDraft) return;
    try {
      setSaving(true);
      setError(null);
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
            timezone: normalizedDraft.governance.quietHours.timezone.trim() || 'Asia/Shanghai',
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
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '保存治理配置失败');
    } finally {
      setSaving(false);
    }
  };

  return (
    <NotificationCenterWorkspaceLayout
      title="治理配置"
      description="控制通知系统的全局开关、灰度比例、限频和静默时段，避免通知失控。"
      actions={
        <button
          type="button"
          onClick={() => void handleSaveConfig()}
          disabled={!configDraft || saving}
          className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white disabled:opacity-45"
        >
          {saving ? '保存中...' : '保存配置'}
        </button>
      }
    >
      {error ? (
        <section className="rounded-[24px] border border-[#f0d7d5] bg-[#fff7f6] px-4 py-3 text-sm text-[#8b3a3a]">
          {error}
        </section>
      ) : null}

      {configDraft ? (
        <section className="space-y-6">
          <section className="grid gap-6 xl:grid-cols-2">
            <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
              <div className="admin-studio-label">Category Switches</div>
              <h2 className="mt-2 text-xl font-semibold text-[#071110]">分类开关</h2>
              <div className="mt-5 space-y-2">
                {CATEGORY_OPTIONS.map((item) => (
                  <label
                    key={item.value}
                    className="flex items-center justify-between rounded-[18px] border border-[#e7ece8] bg-[#fbfcfb] px-4 py-3 text-sm"
                  >
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
            </section>

            <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
              <div className="admin-studio-label">Channel Switches</div>
              <h2 className="mt-2 text-xl font-semibold text-[#071110]">渠道开关</h2>
              <div className="mt-5 space-y-2">
                {CHANNEL_OPTIONS.map((item) => (
                  <label
                    key={item.value}
                    className="flex items-center justify-between rounded-[18px] border border-[#e7ece8] bg-[#fbfcfb] px-4 py-3 text-sm"
                  >
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
            </section>
          </section>

          <section className="grid gap-6 xl:grid-cols-2">
            <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
              <div className="admin-studio-label">Gray Release</div>
              <h2 className="mt-2 text-xl font-semibold text-[#071110]">灰度发布</h2>
              <div className="mt-5 grid gap-4">
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
                    className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                  />
                </label>
                <label className="text-sm text-[#5b6763]">
                  灰度白名单用户（每行一个）
                  <textarea
                    value={grayAllowUserIDsText}
                    onChange={(event) => setGrayAllowUserIDsText(event.target.value)}
                    className="mt-2 h-24 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                    placeholder="u_xxx"
                  />
                </label>
              </div>
            </section>

            <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
              <div className="admin-studio-label">Governance</div>
              <h2 className="mt-2 text-xl font-semibold text-[#071110]">限频与静默</h2>
              <div className="mt-5 grid gap-4">
                <label className="flex items-center justify-between rounded-[18px] border border-[#e7ece8] bg-[#fbfcfb] px-4 py-3 text-sm">
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
                    className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
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
                    className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                  />
                </label>
                <label className="text-sm text-[#5b6763]">
                  限频豁免分类
                  <input
                    value={rateLimitExemptCategoriesText}
                    onChange={(event) => setRateLimitExemptCategoriesText(event.target.value)}
                    className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                  />
                </label>
                <label className="flex items-center justify-between rounded-[18px] border border-[#e7ece8] bg-[#fbfcfb] px-4 py-3 text-sm">
                  <span>启用静默时段</span>
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
                <div className="grid gap-4 md:grid-cols-2">
                  <label className="text-sm text-[#5b6763]">
                    开始小时
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
                      className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                    />
                  </label>
                  <label className="text-sm text-[#5b6763]">
                    结束小时
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
                      className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                    />
                  </label>
                </div>
                <label className="text-sm text-[#5b6763]">
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
                    className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                  />
                </label>
                <label className="text-sm text-[#5b6763]">
                  静默渠道
                  <input
                    value={quietHoursMuteChannelsText}
                    onChange={(event) => setQuietHoursMuteChannelsText(event.target.value)}
                    className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                  />
                </label>
                <label className="text-sm text-[#5b6763]">
                  静默豁免分类
                  <input
                    value={quietHoursExemptCategoriesText}
                    onChange={(event) => setQuietHoursExemptCategoriesText(event.target.value)}
                    className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
                  />
                </label>
              </div>
            </section>
          </section>
        </section>
      ) : !loading ? (
        <section className="rounded-[28px] border border-[#e7ece8] bg-white p-6 text-sm text-[#5b6763]">
          暂无可用治理配置。
        </section>
      ) : (
        <section className="rounded-[28px] border border-[#e7ece8] bg-white p-6 text-sm text-[#5b6763]">
          正在加载治理配置...
        </section>
      )}
    </NotificationCenterWorkspaceLayout>
  );
}
