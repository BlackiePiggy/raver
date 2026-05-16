'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import { getAdminCmsRolePolicy } from '@/lib/admin/role-policy';
import { AdminAuthSessionListParams, AuthSessionItem, adminAuthSessionsApi, authSessionsApi } from '@/lib/api/auth-sessions';
import { formatDateTimeWithSystemTimeZoneLabel } from '@/lib/timezone';

const formatTime = (value?: string | null): string => {
  if (!value) return '-';
  return formatDateTimeWithSystemTimeZoneLabel(value);
};

const getStatus = (item: AuthSessionItem): 'current' | 'active' | 'revoked' => {
  if (item.revokedAt) return 'revoked';
  if (item.isCurrent) return 'current';
  return 'active';
};

const statusLabel = (status: ReturnType<typeof getStatus>): string => {
  if (status === 'current') return '当前会话';
  if (status === 'active') return '有效';
  return '已撤销';
};

const statusClassName = (status: ReturnType<typeof getStatus>): string => {
  if (status === 'current') return 'border-accent-green/40 bg-accent-green/10 text-accent-green';
  if (status === 'active') return 'border-primary-blue/40 bg-primary-blue/10 text-primary-blue';
  return 'border-border-secondary bg-bg-tertiary text-text-secondary';
};

function StatusBadge({ status }: { status: ReturnType<typeof getStatus> }) {
  return <span className={`rounded-md border px-2 py-1 text-xs font-semibold ${statusClassName(status)}`}>{statusLabel(status)}</span>;
}

const describeDevice = (item: AuthSessionItem): string => {
  if (item.deviceName) return item.deviceName;
  if (item.platform) return item.platform;
  if (item.userAgent) return item.userAgent.slice(0, 80);
  return '未知设备';
};

export default function AuthSessionsAdminPage() {
  const { user, logout, isLoading } = useAuth();
  const rolePolicy = useMemo(() => getAdminCmsRolePolicy(user), [user]);
  const canManageUserSessions = user?.role === 'admin';

  const [items, setItems] = useState<AuthSessionItem[]>([]);
  const [managedItems, setManagedItems] = useState<AuthSessionItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [managedLoading, setManagedLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [managedError, setManagedError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [revokingId, setRevokingId] = useState<string | null>(null);
  const [managedRevokingId, setManagedRevokingId] = useState<string | null>(null);
  const [searchUserId, setSearchUserId] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [includeRevoked, setIncludeRevoked] = useState(false);

  const loadSessions = useCallback(async () => {
    if (!user || !rolePolicy.canAccessAdminShell) return;
    try {
      setLoading(true);
      setError(null);
      const result = await authSessionsApi.list();
      setItems(result.items);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载会话失败');
    } finally {
      setLoading(false);
    }
  }, [rolePolicy.canAccessAdminShell, user]);

  useEffect(() => {
    void loadSessions();
  }, [loadSessions]);

  const summary = useMemo(() => {
    const active = items.filter((item) => !item.revokedAt).length;
    const webAdmin = items.filter((item) => item.clientType === 'web_admin' && !item.revokedAt).length;
    return { total: items.length, active, webAdmin };
  }, [items]);

  const revokeSession = async (item: AuthSessionItem) => {
    const confirmed = window.confirm(item.isCurrent ? '撤销当前会话后需要重新登录，确认继续？' : '确认撤销该登录会话？');
    if (!confirmed) return;

    try {
      setError(null);
      setNotice(null);
      setRevokingId(item.id);
      const result = await authSessionsApi.revoke(item.id);
      if (result.revokedCurrent) {
        logout();
        return;
      }
      setNotice('会话已撤销');
      await loadSessions();
    } catch (revokeError) {
      setError(revokeError instanceof Error ? revokeError.message : '撤销会话失败');
    } finally {
      setRevokingId(null);
    }
  };

  const loadManagedSessions = useCallback(async () => {
    if (!canManageUserSessions) return;
    const params: AdminAuthSessionListParams = {
      userId: searchUserId.trim() || undefined,
      q: searchUserId.trim() ? undefined : searchQuery.trim() || undefined,
      includeRevoked,
      limit: 100,
    };

    try {
      setManagedLoading(true);
      setManagedError(null);
      const result = await adminAuthSessionsApi.list(params);
      setManagedItems(result.items);
    } catch (loadError) {
      setManagedError(loadError instanceof Error ? loadError.message : '加载用户会话失败');
    } finally {
      setManagedLoading(false);
    }
  }, [canManageUserSessions, includeRevoked, searchQuery, searchUserId]);

  const revokeManagedSession = async (item: AuthSessionItem) => {
    const targetLabel = item.user?.email || item.user?.username || item.userId || item.id;
    const confirmed = window.confirm(`确认撤销 ${targetLabel} 的该登录会话？`);
    if (!confirmed) return;

    try {
      setManagedError(null);
      setNotice(null);
      setManagedRevokingId(item.id);
      await adminAuthSessionsApi.revoke(item.id);
      setNotice('用户会话已撤销');
      await loadManagedSessions();
    } catch (revokeError) {
      setManagedError(revokeError instanceof Error ? revokeError.message : '撤销用户会话失败');
    } finally {
      setManagedRevokingId(null);
    }
  };

  if (isLoading) {
    return (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <div className="mx-auto max-w-6xl px-6 pt-28">加载中...</div>
      </main>
    );
  }

  if (!user || !rolePolicy.canAccessAdminShell) {
    return (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <section className="mx-auto max-w-4xl px-6 pt-28">
          <div className="rounded-lg border border-border-secondary bg-bg-secondary p-6">
            <h1 className="text-2xl font-semibold">登录设备与会话</h1>
            <p className="mt-3 text-sm text-text-secondary">请先登录后查看会话。</p>
            <Link href="/login" className="mt-5 inline-block rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
              去登录
            </Link>
          </div>
        </section>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-bg-primary text-text-primary">
      <Navigation />
      <section className="mx-auto max-w-7xl space-y-5 px-6 pb-12 pt-24">
        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <p className="text-sm text-text-secondary">Auth Sessions</p>
            <h1 className="mt-1 text-3xl font-semibold">登录设备与会话</h1>
            <p className="mt-2 text-sm text-text-secondary">查看当前账号的 Web Admin / iOS 登录会话，并撤销不再使用的设备。</p>
          </div>
          <button
            type="button"
            onClick={() => void loadSessions()}
            disabled={loading}
            className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
          >
            {loading ? '刷新中...' : '刷新'}
          </button>
        </div>

        {error && <div className="rounded-lg border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300">{error}</div>}
        {notice && <div className="rounded-lg border border-accent-green/40 bg-accent-green/10 px-4 py-3 text-sm text-accent-green">{notice}</div>}

        <div className="grid gap-4 md:grid-cols-3">
          <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
            <div className="text-sm text-text-secondary">全部记录</div>
            <div className="mt-2 text-2xl font-semibold">{summary.total}</div>
          </div>
          <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
            <div className="text-sm text-text-secondary">有效会话</div>
            <div className="mt-2 text-2xl font-semibold">{summary.active}</div>
          </div>
          <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
            <div className="text-sm text-text-secondary">Web Admin</div>
            <div className="mt-2 text-2xl font-semibold">{summary.webAdmin}</div>
          </div>
        </div>

        <section className="overflow-hidden rounded-lg border border-border-secondary bg-bg-secondary">
          <div className="grid grid-cols-[1.2fr_0.7fr_1fr_1fr_120px] gap-3 border-b border-border-secondary px-4 py-3 text-xs font-semibold uppercase tracking-wide text-text-secondary">
            <div>设备</div>
            <div>类型</div>
            <div>活跃时间</div>
            <div>过期时间</div>
            <div>操作</div>
          </div>
          <div className="divide-y divide-border-secondary">
            {items.map((item) => {
              const status = getStatus(item);
              const canRevoke = !item.revokedAt;
              return (
                <div key={item.id} className="grid grid-cols-[1.2fr_0.7fr_1fr_1fr_120px] gap-3 px-4 py-4 text-sm">
                  <div className="min-w-0 space-y-2">
                    <div className="flex flex-wrap items-center gap-2">
                      <StatusBadge status={status} />
                      {item.ipAddressMasked && <span className="text-xs text-text-secondary">{item.ipAddressMasked}</span>}
                    </div>
                    <div className="break-words font-semibold">{describeDevice(item)}</div>
                    <div className="break-all font-mono text-xs text-text-tertiary">{item.id}</div>
                    {item.userAgent && <div className="line-clamp-2 break-words text-xs text-text-secondary">{item.userAgent}</div>}
                  </div>
                  <div className="space-y-2">
                    <div className="font-semibold">{item.clientType}</div>
                    <div className="text-text-secondary">{item.platform || '-'}</div>
                    <div className="text-text-secondary">{item.appVersion || '-'}</div>
                  </div>
                  <div className="space-y-2 text-text-secondary">
                    <div>创建：{formatTime(item.createdAt)}</div>
                    <div>最近：{formatTime(item.lastUsedAt)}</div>
                  </div>
                  <div className="space-y-2 text-text-secondary">
                    <div>Refresh：{formatTime(item.expiresAt)}</div>
                    <div>Idle：{formatTime(item.idleExpiresAt)}</div>
                    <div>Absolute：{formatTime(item.absoluteExpiresAt)}</div>
                    {item.revokedAt && <div className="text-red-300">撤销：{formatTime(item.revokedAt)}</div>}
                  </div>
                  <div>
                    {canRevoke ? (
                      <button
                        type="button"
                        onClick={() => void revokeSession(item)}
                        disabled={revokingId === item.id}
                        className="rounded-lg border border-border-secondary px-3 py-2 text-sm hover:border-red-500 hover:text-red-300 disabled:opacity-60"
                      >
                        {revokingId === item.id ? '撤销中...' : '撤销'}
                      </button>
                    ) : (
                      <span className="text-sm text-text-tertiary">-</span>
                    )}
                  </div>
                </div>
              );
            })}
            {items.length === 0 && (
              <div className="px-4 py-8 text-center text-sm text-text-secondary">
                暂无会话记录
              </div>
            )}
          </div>
        </section>

        {canManageUserSessions && (
          <section className="space-y-4 rounded-lg border border-border-secondary bg-bg-secondary p-5">
            <div className="flex flex-col gap-2 md:flex-row md:items-end md:justify-between">
              <div>
                <p className="text-sm text-text-secondary">Admin Session Management</p>
                <h2 className="mt-1 text-xl font-semibold">用户会话检索与踢下线</h2>
              </div>
              <button
                type="button"
                onClick={() => void loadManagedSessions()}
                disabled={managedLoading}
                className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
              >
                {managedLoading ? '查询中...' : '查询'}
              </button>
            </div>

            <div className="grid gap-3 md:grid-cols-[1fr_1fr_auto]">
              <input
                value={searchUserId}
                onChange={(event) => setSearchUserId(event.target.value)}
                placeholder="精确用户 ID"
                className="rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
              />
              <input
                value={searchQuery}
                onChange={(event) => setSearchQuery(event.target.value)}
                placeholder="邮箱 / 用户名 / 昵称"
                disabled={Boolean(searchUserId.trim())}
                className="rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm disabled:opacity-50"
              />
              <label className="flex items-center gap-2 rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm text-text-secondary">
                <input
                  type="checkbox"
                  checked={includeRevoked}
                  onChange={(event) => setIncludeRevoked(event.target.checked)}
                  className="h-4 w-4"
                />
                包含已撤销
              </label>
            </div>

            {managedError && <div className="rounded-lg border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300">{managedError}</div>}

            <div className="overflow-hidden rounded-lg border border-border-secondary bg-bg-primary">
              <div className="grid grid-cols-[1.1fr_1.2fr_0.7fr_1fr_1fr_120px] gap-3 border-b border-border-secondary px-4 py-3 text-xs font-semibold uppercase tracking-wide text-text-secondary">
                <div>用户</div>
                <div>设备</div>
                <div>类型</div>
                <div>活跃时间</div>
                <div>过期时间</div>
                <div>操作</div>
              </div>
              <div className="divide-y divide-border-secondary">
                {managedItems.map((item) => {
                  const status = getStatus(item);
                  const canRevoke = !item.revokedAt;
                  return (
                    <div key={item.id} className="grid grid-cols-[1.1fr_1.2fr_0.7fr_1fr_1fr_120px] gap-3 px-4 py-4 text-sm">
                      <div className="min-w-0 space-y-2">
                        <div className="font-semibold">{item.user?.displayName || item.user?.username || item.userId || '-'}</div>
                        <div className="break-all text-xs text-text-secondary">{item.user?.email || '-'}</div>
                        <div className="break-all font-mono text-xs text-text-tertiary">{item.user?.id || item.userId || '-'}</div>
                        {item.user?.role && <div className="text-xs text-text-secondary">{item.user.role}</div>}
                      </div>
                      <div className="min-w-0 space-y-2">
                        <div className="flex flex-wrap items-center gap-2">
                          <StatusBadge status={status} />
                          {item.ipAddressMasked && <span className="text-xs text-text-secondary">{item.ipAddressMasked}</span>}
                        </div>
                        <div className="break-words font-semibold">{describeDevice(item)}</div>
                        <div className="break-all font-mono text-xs text-text-tertiary">{item.id}</div>
                      </div>
                      <div className="space-y-2">
                        <div className="font-semibold">{item.clientType}</div>
                        <div className="text-text-secondary">{item.platform || '-'}</div>
                      </div>
                      <div className="space-y-2 text-text-secondary">
                        <div>创建：{formatTime(item.createdAt)}</div>
                        <div>最近：{formatTime(item.lastUsedAt)}</div>
                      </div>
                      <div className="space-y-2 text-text-secondary">
                        <div>Refresh：{formatTime(item.expiresAt)}</div>
                        <div>Idle：{formatTime(item.idleExpiresAt)}</div>
                        <div>Absolute：{formatTime(item.absoluteExpiresAt)}</div>
                        {item.revokedAt && <div className="text-red-300">撤销：{formatTime(item.revokedAt)}</div>}
                      </div>
                      <div>
                        {canRevoke ? (
                          <button
                            type="button"
                            onClick={() => void revokeManagedSession(item)}
                            disabled={managedRevokingId === item.id}
                            className="rounded-lg border border-border-secondary px-3 py-2 text-sm hover:border-red-500 hover:text-red-300 disabled:opacity-60"
                          >
                            {managedRevokingId === item.id ? '撤销中...' : '踢下线'}
                          </button>
                        ) : (
                          <span className="text-sm text-text-tertiary">-</span>
                        )}
                      </div>
                    </div>
                  );
                })}
                {managedItems.length === 0 && (
                  <div className="px-4 py-8 text-center text-sm text-text-secondary">
                    输入用户 ID、邮箱、用户名或昵称后查询会话
                  </div>
                )}
              </div>
            </div>
          </section>
        )}
      </section>
    </main>
  );
}
