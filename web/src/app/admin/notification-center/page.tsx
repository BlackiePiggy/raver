'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import NotificationCenterWorkspaceLayout from '@/components/admin/NotificationCenterWorkspaceLayout';
import NotificationPublishCandidatesSection from '@/components/admin/NotificationPublishCandidatesSection';
import {
  notificationCenterAdminApi,
  type NotificationAdminPublishTaskPage,
  type NotificationCenterDeliverySectionSummary,
  type NotificationCenterStatusResponse,
} from '@/lib/api/notification-center-admin';
import { formatPercent, formatTime } from '@/components/admin/notification-center/shared';

const ENTRY_CARDS = [
  {
    href: '/admin/notification-center/publish-tasks',
    label: '发布任务',
    title: '处理待发布候选项',
    description: '查看成功页暂未决定的发布候选，统一完成发布或拒绝。',
  },
  {
    href: '/admin/notification-center/manual',
    label: '手动发布',
    title: '发一条运营通知',
    description: '面向自定义对象手动触发 APNS / 站内通知，并先预览触达范围。',
  },
  {
    href: '/admin/notification-center/deliveries',
    label: '投递记录',
    title: '看清通知都发到了哪里',
    description: '按通知分区查看投递结果、失败情况、用户与绑定对象。',
  },
  {
    href: '/admin/notification-center/templates',
    label: '通知模板',
    title: '维护消息文案模板',
    description: '统一管理分类、语言、渠道维度的通知模板与变量。',
  },
  {
    href: '/admin/notification-center/governance',
    label: '治理配置',
    title: '控制灰度与限频策略',
    description: '集中管理分类开关、渠道开关、灰度发布、静默时段与限频。',
  },
] as const;

export default function NotificationCenterOverviewPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [statusData, setStatusData] = useState<NotificationCenterStatusResponse | null>(null);
  const [publishTaskPage, setPublishTaskPage] = useState<NotificationAdminPublishTaskPage | null>(null);
  const [publishTaskLoading, setPublishTaskLoading] = useState(false);
  const [sectionSummaries, setSectionSummaries] = useState<NotificationCenterDeliverySectionSummary[]>([]);

  const loadOverview = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const [status, publishTasks, sections] = await Promise.all([
        notificationCenterAdminApi.getStatus(24),
        notificationCenterAdminApi.getPublishTasks({ page: 1, limit: 8, status: 'pending' }),
        notificationCenterAdminApi.getDeliverySections(),
      ]);
      setStatusData(status);
      setPublishTaskPage(publishTasks);
      setSectionSummaries(sections);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载通知中心总览失败');
    } finally {
      setLoading(false);
      setPublishTaskLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadOverview();
  }, [loadOverview]);

  const alertItems = useMemo(() => statusData?.delivery.alerts.items ?? [], [statusData]);
  const triggeredAlerts = useMemo(() => alertItems.filter((item) => item.triggered), [alertItems]);
  const topSections = useMemo(() => sectionSummaries.slice().sort((a, b) => b.total - a.total).slice(0, 4), [sectionSummaries]);

  return (
    <NotificationCenterWorkspaceLayout
      title="通知中心"
      description="把通知相关工作拆成清晰的几个子功能页：发布任务、手动发布、投递记录、模板和治理配置。"
      actions={
        <button
          type="button"
          onClick={() => {
            setPublishTaskLoading(true);
            void loadOverview();
          }}
          className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
        >
          刷新总览
        </button>
      }
    >
      {error ? (
        <section className="rounded-[24px] border border-[#f0d7d5] bg-[#fff7f6] px-4 py-3 text-sm text-[#8b3a3a]">
          {error}
        </section>
      ) : null}

      <section className="grid gap-4 xl:grid-cols-5">
        <article className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
          <div className="text-xs uppercase tracking-[0.24em] text-black/38">APNS</div>
          <div className="mt-3 text-2xl font-semibold text-[#071110]">
            {statusData?.apns.configured ? 'Ready' : 'Missing'}
          </div>
          <div className="mt-2 text-sm text-[#5b6763]">enabled: {statusData?.apns.enabled ? 'true' : 'false'}</div>
          <div className="text-sm text-[#5b6763]">sandbox: {statusData?.apns.useSandbox ? 'true' : 'false'}</div>
        </article>
        <article className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
          <div className="text-xs uppercase tracking-[0.24em] text-black/38">待处理任务</div>
          <div className="mt-3 text-2xl font-semibold text-[#071110]">{publishTaskPage?.pagination.total ?? 0}</div>
          <div className="mt-2 text-sm text-[#5b6763]">统一在发布任务页继续处理</div>
        </article>
        <article className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
          <div className="text-xs uppercase tracking-[0.24em] text-black/38">24h 总投递</div>
          <div className="mt-3 text-2xl font-semibold text-[#071110]">{statusData?.delivery.totals.total ?? 0}</div>
          <div className="mt-2 text-sm text-[#5b6763]">sent: {statusData?.delivery.totals.sent ?? 0}</div>
          <div className="text-sm text-[#5b6763]">failed: {statusData?.delivery.totals.failed ?? 0}</div>
        </article>
        <article className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
          <div className="text-xs uppercase tracking-[0.24em] text-black/38">成功率</div>
          <div className="mt-3 text-2xl font-semibold text-[#071110]">
            {formatPercent(statusData?.delivery.rates.deliverySuccessRate)}
          </div>
          <div className="mt-2 text-sm text-[#5b6763]">
            failure: {formatPercent(statusData?.delivery.rates.deliveryFailureRate)}
          </div>
        </article>
        <article className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
          <div className="text-xs uppercase tracking-[0.24em] text-black/38">当前告警</div>
          <div className="mt-3 text-2xl font-semibold text-[#071110]">{triggeredAlerts.length}</div>
          <div className="mt-2 text-sm text-[#5b6763]">统计窗口：24h</div>
        </article>
      </section>

      <section className="grid gap-4 xl:grid-cols-2">
        {ENTRY_CARDS.map((card) => (
          <Link
            key={card.href}
            href={card.href}
            className="rounded-[28px] border border-[#e7ece8] bg-white p-6 transition hover:-translate-y-0.5 hover:border-[#cfd8d4]"
          >
            <div className="text-xs uppercase tracking-[0.24em] text-black/38">{card.label}</div>
            <div className="mt-3 text-xl font-semibold text-[#071110]">{card.title}</div>
            <div className="mt-3 text-sm leading-6 text-[#5b6763]">{card.description}</div>
          </Link>
        ))}
      </section>

      <section className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
        <div className="space-y-6">
          <NotificationPublishCandidatesSection page={publishTaskPage} loading={loading || publishTaskLoading} />

          <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
            <div className="admin-studio-label">Alerts</div>
            <h2 className="mt-2 text-xl font-semibold text-[#071110]">告警摘要</h2>
            <div className="mt-5 space-y-3">
              {triggeredAlerts.length ? (
                triggeredAlerts.map((item) => (
                  <div key={item.code} className="rounded-[20px] border border-[#f0d7d5] bg-[#fff7f6] px-4 py-4">
                    <div className="flex flex-wrap items-center justify-between gap-3">
                      <div className="text-sm font-semibold text-[#071110]">{item.code}</div>
                      <span className="rounded-full bg-[#fff1f0] px-3 py-1 text-[11px] font-semibold text-[#8b3a3a]">
                        已触发
                      </span>
                    </div>
                    <div className="mt-2 text-sm leading-6 text-[#8b3a3a]">{item.message}</div>
                  </div>
                ))
              ) : (
                <div className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] px-4 py-4 text-sm text-[#5b6763]">
                  当前没有已触发告警。
                </div>
              )}
            </div>
          </section>
        </div>

        <div className="space-y-6">
          <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
            <div className="admin-studio-label">Delivery Sections</div>
            <h2 className="mt-2 text-xl font-semibold text-[#071110]">主要投递分区</h2>
            <div className="mt-5 space-y-3">
              {topSections.map((section) => (
                <div
                  key={section.section}
                  className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] px-4 py-4"
                >
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <div className="text-sm font-semibold text-[#071110]">{section.section}</div>
                      <div className="mt-1 text-xs text-[#5b6763]">最后投递：{formatTime(section.lastDeliveryAt)}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-lg font-semibold text-[#071110]">{section.total}</div>
                      <div className="text-xs text-[#5b6763]">记录</div>
                    </div>
                  </div>
                  <div className="mt-3 flex flex-wrap gap-2 text-xs text-[#5b6763]">
                    <span className="rounded-full bg-[#f2f5f3] px-3 py-1">APNS {section.apnsCount}</span>
                    <span className="rounded-full bg-[#f2f5f3] px-3 py-1">站内 {section.inAppCount}</span>
                    <span className="rounded-full bg-[#f2f5f3] px-3 py-1">失败 {section.failedCount}</span>
                  </div>
                </div>
              ))}
            </div>
          </section>

          <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
            <div className="admin-studio-label">Snapshot</div>
            <h2 className="mt-2 text-xl font-semibold text-[#071110]">当前状态快照</h2>
            <div className="mt-5 grid gap-4 md:grid-cols-2">
              <div className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
                <div className="text-sm text-[#5b6763]">窗口起点</div>
                <div className="mt-2 text-base font-semibold text-[#071110]">
                  {formatTime(statusData?.delivery.since)}
                </div>
              </div>
              <div className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
                <div className="text-sm text-[#5b6763]">Inbox 打开率</div>
                <div className="mt-2 text-base font-semibold text-[#071110]">
                  {formatPercent(statusData?.delivery.engagement.openRate)}
                </div>
              </div>
              <div className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
                <div className="text-sm text-[#5b6763]">禁用订阅数</div>
                <div className="mt-2 text-base font-semibold text-[#071110]">
                  {statusData?.delivery.subscriptions.disabled ?? 0}
                </div>
              </div>
              <div className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
                <div className="text-sm text-[#5b6763]">最近窗口小时数</div>
                <div className="mt-2 text-base font-semibold text-[#071110]">
                  {statusData?.delivery.windowHours ?? 24}h
                </div>
              </div>
            </div>
          </section>
        </div>
      </section>
    </NotificationCenterWorkspaceLayout>
  );
}
