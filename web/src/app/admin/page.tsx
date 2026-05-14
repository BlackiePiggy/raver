'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import { getAdminCmsRolePolicy } from '@/lib/admin/role-policy';
import { AdminHealthStatus, AdminStatus, adminStatusApi } from '@/lib/api/admin-status';

const STATUS_LABELS: Record<AdminHealthStatus, string> = {
  healthy: '健康',
  degraded: '需关注',
  critical: '严重',
};

const STATUS_CLASS_NAMES: Record<AdminHealthStatus, string> = {
  healthy: 'border-accent-green/40 bg-accent-green/10 text-accent-green',
  degraded: 'border-yellow-500/40 bg-yellow-500/10 text-yellow-300',
  critical: 'border-red-500/40 bg-red-500/10 text-red-300',
};

const formatTime = (value?: string | null): string => {
  if (!value) return '-';
  return new Date(value).toLocaleString('zh-CN', { hour12: false });
};

const formatPercent = (value?: number): string => `${((value ?? 0) * 100).toFixed(1)}%`;

const formatBoolean = (value: boolean): string => (value ? '是' : '否');

function StatusBadge({ status }: { status: AdminHealthStatus }) {
  return (
    <span className={`inline-flex rounded-md border px-2.5 py-1 text-xs font-semibold ${STATUS_CLASS_NAMES[status]}`}>
      {STATUS_LABELS[status]}
    </span>
  );
}

function Metric({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
      <div className="text-sm text-text-secondary">{label}</div>
      <div className="mt-2 text-2xl font-semibold">{value}</div>
    </div>
  );
}

export default function AdminOverviewPage() {
  const { user, isLoading } = useAuth();
  const rolePolicy = useMemo(() => getAdminCmsRolePolicy(user), [user]);

  const [status, setStatus] = useState<AdminStatus | null>(null);
  const [windowHours, setWindowHours] = useState('24');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadStatus = useCallback(async () => {
    if (!rolePolicy.canAccessOperations) return;

    try {
      setLoading(true);
      setError(null);
      const numericWindowHours = Number(windowHours) > 0 ? Number(windowHours) : 24;
      const nextStatus = await adminStatusApi.getStatus(numericWindowHours);
      setStatus(nextStatus);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载运营状态失败');
    } finally {
      setLoading(false);
    }
  }, [rolePolicy.canAccessOperations, windowHours]);

  useEffect(() => {
    void loadStatus();
  }, [loadStatus]);

  const notificationAlerts = useMemo(
    () => status?.notification.delivery.alerts.items.filter((item) => item.triggered) ?? [],
    [status]
  );

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
          <p className="text-lg">请先登录后访问运营后台。</p>
          <Link href="/login" className="mt-4 inline-block rounded-lg bg-primary-blue px-4 py-2 text-white">
            去登录
          </Link>
        </div>
      </main>
    );
  }

  if (!rolePolicy.canAccessAdminShell) {
    return (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <div className="mx-auto max-w-6xl px-6 pt-28">
          <p className="text-lg">当前账号无权限访问后台。</p>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-bg-primary text-text-primary">
      <Navigation />
      <section className="mx-auto max-w-7xl space-y-5 px-6 pb-12 pt-24">
        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <h1 className="text-3xl font-semibold">后台工作台</h1>
            <p className="mt-2 text-text-secondary">Admin / Content CMS / Operations</p>
          </div>
          {rolePolicy.canAccessOperations ? (
            <div className="flex flex-wrap items-center gap-3">
              <label className="text-sm text-text-secondary">
                统计窗口
                <input
                  value={windowHours}
                  onChange={(event) => setWindowHours(event.target.value)}
                  className="ml-2 w-20 rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-primary"
                />
              </label>
              <button
                type="button"
                onClick={() => void loadStatus()}
                disabled={loading}
                className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue disabled:opacity-60"
              >
                {loading ? '刷新中...' : '刷新'}
              </button>
            </div>
          ) : (
            <div className="rounded-lg border border-border-secondary bg-bg-secondary px-4 py-3 text-sm">
              <div className="text-text-secondary">当前身份</div>
              <div className="mt-1 font-semibold">{rolePolicy.label}</div>
            </div>
          )}
        </div>

        {error && <div className="rounded-lg border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300">{error}</div>}

        <div className="grid gap-4 md:grid-cols-3">
          <Link href="/admin/content-cms" className="rounded-lg border border-border-secondary bg-bg-secondary p-4 hover:border-primary-blue">
            <div className="text-sm text-text-secondary">Content CMS</div>
            <div className="mt-2 text-lg font-semibold">内容管理中心</div>
            <div className="mt-2 text-sm leading-6 text-text-secondary">活动、DJ、Set、资讯、百科、榜单统一入口</div>
          </Link>
          {rolePolicy.canAccessPreRegistrationOps && (
            <Link href="/admin/pre-registrations" className="rounded-lg border border-border-secondary bg-bg-secondary p-4 hover:border-primary-blue">
              <div className="text-sm text-text-secondary">Pre-registration Ops</div>
              <div className="mt-2 text-lg font-semibold">预登记管理</div>
              <div className="mt-2 text-sm leading-6 text-text-secondary">审核、批次与通知处理</div>
            </Link>
          )}
          {rolePolicy.canAccessNotificationOps && (
            <Link href="/admin/notification-center" className="rounded-lg border border-border-secondary bg-bg-secondary p-4 hover:border-primary-blue">
              <div className="text-sm text-text-secondary">Notification Ops</div>
              <div className="mt-2 text-lg font-semibold">通知中心后台</div>
              <div className="mt-2 text-sm leading-6 text-text-secondary">通知模板、投递状态与配置</div>
            </Link>
          )}
          {rolePolicy.canAccessOperations ? (
            <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
              <div className="text-sm text-text-secondary">最后检查</div>
              <div className="mt-2 text-lg font-semibold">{formatTime(status?.checkedAt)}</div>
            </div>
          ) : (
            <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
              <div className="text-sm text-text-secondary">权限边界</div>
              <div className="mt-2 text-lg font-semibold">{rolePolicy.label}</div>
              <div className="mt-2 text-sm leading-6 text-text-secondary">只能管理自己或已授权主体名下的内容。</div>
            </div>
          )}
        </div>

        {!rolePolicy.canAccessOperations && rolePolicy.capabilities.length > 0 && (
          <section className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
            <h2 className="text-xl font-semibold">可用能力</h2>
            <div className="mt-4 grid gap-3 md:grid-cols-2">
              {rolePolicy.capabilities.map((capability) => (
                <div key={capability} className="rounded-lg border border-border-secondary bg-bg-tertiary p-3 text-sm leading-6">
                  {capability}
                </div>
              ))}
            </div>
          </section>
        )}

        {rolePolicy.canAccessOperations && status && (
          <>
            <section className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h2 className="text-xl font-semibold">整体状态</h2>
                  <p className="mt-1 text-sm text-text-secondary">跨 notification、worker 与 check-in projection 的只读聚合</p>
                </div>
                <StatusBadge status={status.overallStatus} />
              </div>
              {status.alertReasons.length > 0 && (
                <div className="mt-4 flex flex-wrap gap-2">
                  {status.alertReasons.map((reason) => (
                    <span key={reason} className="rounded-md border border-border-secondary bg-bg-tertiary px-2.5 py-1 text-xs text-text-secondary">
                      {reason}
                    </span>
                  ))}
                </div>
              )}
            </section>

            <section className="grid gap-4 md:grid-cols-4">
              <Metric label="通知投递总量" value={status.notification.delivery.totals.total} />
              <Metric label="通知失败率" value={formatPercent(status.notification.delivery.rates.deliveryFailureRate)} />
              <Metric label="待处理投递" value={status.notification.delivery.totals.queued} />
              <Metric label="Check-in 待投影" value={status.checkinProjection.pendingOutbox} />
            </section>

            <section className="grid gap-5 lg:grid-cols-2">
              <div className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
                <div className="mb-4 flex items-center justify-between gap-3">
                  <h2 className="text-xl font-semibold">Notification</h2>
                  <StatusBadge status={status.notification.status} />
                </div>
                <div className="grid gap-3 text-sm md:grid-cols-2">
                  <div className="rounded-lg border border-border-secondary bg-bg-tertiary p-3">
                    <div className="text-text-secondary">APNs enabled</div>
                    <div className="mt-1 font-semibold">{formatBoolean(status.notification.apns.enabled)}</div>
                  </div>
                  <div className="rounded-lg border border-border-secondary bg-bg-tertiary p-3">
                    <div className="text-text-secondary">APNs configured</div>
                    <div className="mt-1 font-semibold">{formatBoolean(status.notification.apns.configured)}</div>
                  </div>
                  <div className="rounded-lg border border-border-secondary bg-bg-tertiary p-3">
                    <div className="text-text-secondary">Outbox worker</div>
                    <div className="mt-1 font-semibold">{status.notification.outboxWorker.running ? '运行中' : '未运行'}</div>
                  </div>
                  <div className="rounded-lg border border-border-secondary bg-bg-tertiary p-3">
                    <div className="text-text-secondary">Async mode</div>
                    <div className="mt-1 font-semibold">{formatBoolean(status.notification.outboxWorker.asyncModeEnabled)}</div>
                  </div>
                </div>
                {notificationAlerts.length > 0 && (
                  <div className="mt-4 space-y-2">
                    {notificationAlerts.map((alert) => (
                      <div key={alert.code} className="rounded-lg border border-yellow-500/40 bg-yellow-500/10 px-3 py-2 text-sm text-yellow-200">
                        {alert.message}
                      </div>
                    ))}
                  </div>
                )}
              </div>

              <div className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
                <div className="mb-4 flex items-center justify-between gap-3">
                  <h2 className="text-xl font-semibold">Check-in Projection</h2>
                  <StatusBadge status={status.checkinProjection.status} />
                </div>
                <div className="grid gap-3 text-sm md:grid-cols-2">
                  <div className="rounded-lg border border-border-secondary bg-bg-tertiary p-3">
                    <div className="text-text-secondary">Dirty checkins</div>
                    <div className="mt-1 font-semibold">{status.checkinProjection.dirtyCheckins}</div>
                  </div>
                  <div className="rounded-lg border border-border-secondary bg-bg-tertiary p-3">
                    <div className="text-text-secondary">Ready outbox</div>
                    <div className="mt-1 font-semibold">{status.checkinProjection.pendingReadyOutbox}</div>
                  </div>
                  <div className="rounded-lg border border-border-secondary bg-bg-tertiary p-3">
                    <div className="text-text-secondary">Dead outbox</div>
                    <div className="mt-1 font-semibold">{status.checkinProjection.deadOutbox}</div>
                  </div>
                  <div className="rounded-lg border border-border-secondary bg-bg-tertiary p-3">
                    <div className="text-text-secondary">Oldest pending age</div>
                    <div className="mt-1 font-semibold">{status.checkinProjection.oldestPendingAgeSeconds}s</div>
                  </div>
                </div>
              </div>
            </section>
          </>
        )}
      </section>
    </main>
  );
}
