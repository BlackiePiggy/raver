'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import { AccountDeletionRequest, accountDeletionsApi } from '@/lib/api/account-deletions';
import { formatDateTimeWithSystemTimeZoneLabel } from '@/lib/timezone';

const formatTime = (value?: string | null): string => {
  if (!value) return '-';
  return formatDateTimeWithSystemTimeZoneLabel(value);
};

const statusClassName = (status: string): string => {
  if (status === 'completed' || status === 'skipped') return 'border-accent-green/40 bg-accent-green/10 text-accent-green';
  if (status === 'partial_failed' || status === 'failed') return 'border-red-500/40 bg-red-500/10 text-red-300';
  if (status === 'pending' || status === 'queued') return 'border-yellow-500/40 bg-yellow-500/10 text-yellow-300';
  return 'border-border-secondary bg-bg-tertiary text-text-secondary';
};

function StatusBadge({ status }: { status: string }) {
  return <span className={`rounded-md border px-2 py-1 text-xs font-semibold ${statusClassName(status)}`}>{status}</span>;
}

function ErrorText({ value }: { value?: string | null }) {
  if (!value) return <span className="text-text-secondary">-</span>;
  return <span className="break-words text-red-300">{value}</span>;
}

export default function AccountDeletionsAdminPage() {
  const { user, token, isLoading } = useAuth();
  const canOperate = user?.role === 'admin' || user?.role === 'operator';
  const canRetry = user?.role === 'admin';

  const [items, setItems] = useState<AccountDeletionRequest[]>([]);
  const [filterUserId, setFilterUserId] = useState('');
  const [filterStatus, setFilterStatus] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const summary = useMemo(() => {
    const failed = items.filter((item) => item.status === 'partial_failed' || item.imStatus === 'failed' || item.mediaStatus === 'failed').length;
    const pending = items.filter((item) => item.status === 'queued' || item.imStatus === 'pending' || item.mediaStatus === 'pending').length;
    return { total: items.length, failed, pending };
  }, [items]);

  const loadAll = useCallback(async () => {
    if (!token || !canOperate) return;
    try {
      setLoading(true);
      setError(null);
      const result = await accountDeletionsApi.list(token, {
        userId: filterUserId.trim() || undefined,
        status: filterStatus || undefined,
        limit: 100,
      });
      setItems(result.items);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载账号删除请求失败');
    } finally {
      setLoading(false);
    }
  }, [canOperate, filterStatus, filterUserId, token]);

  useEffect(() => {
    void loadAll();
  }, [loadAll]);

  const retryRequest = async (item: AccountDeletionRequest) => {
    if (!token || !canRetry) return;
    try {
      setError(null);
      setNotice(null);
      await accountDeletionsApi.retry(token, item.id);
      setNotice('已触发重试');
      await loadAll();
    } catch (retryError) {
      setError(retryError instanceof Error ? retryError.message : '重试失败');
    }
  };

  const processDue = async () => {
    if (!token || !canRetry) return;
    try {
      setError(null);
      setNotice(null);
      const result = await accountDeletionsApi.processDue(token, 50);
      setNotice(`已处理 ${result.results.length} 条到期删除任务`);
      await loadAll();
    } catch (processError) {
      setError(processError instanceof Error ? processError.message : '处理到期任务失败');
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

  if (!user || !canOperate) {
    return (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <section className="mx-auto max-w-4xl px-6 pt-28">
          <div className="rounded-lg border border-border-secondary bg-bg-secondary p-6">
            <h1 className="text-2xl font-semibold">账号删除请求</h1>
            <p className="mt-3 text-sm text-text-secondary">当前账号无权限访问该页面。</p>
            <Link href={user ? '/admin' : '/login'} className="mt-5 inline-block rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
              {user ? '返回后台' : '去登录'}
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
            <p className="text-sm text-text-secondary">Privacy Ops</p>
            <h1 className="mt-1 text-3xl font-semibold">账号删除请求</h1>
          </div>
          <div className="flex flex-wrap gap-3">
            {canRetry && (
              <button
                type="button"
                onClick={() => void processDue()}
                className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue"
              >
                处理到期任务
              </button>
            )}
            <button
              type="button"
              onClick={() => void loadAll()}
              disabled={loading}
              className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
            >
              {loading ? '刷新中...' : '刷新'}
            </button>
          </div>
        </div>

        {error && <div className="rounded-lg border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300">{error}</div>}
        {notice && <div className="rounded-lg border border-accent-green/40 bg-accent-green/10 px-4 py-3 text-sm text-accent-green">{notice}</div>}

        <div className="grid gap-4 md:grid-cols-3">
          <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
            <div className="text-sm text-text-secondary">当前列表</div>
            <div className="mt-2 text-2xl font-semibold">{summary.total}</div>
          </div>
          <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
            <div className="text-sm text-text-secondary">待处理</div>
            <div className="mt-2 text-2xl font-semibold">{summary.pending}</div>
          </div>
          <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
            <div className="text-sm text-text-secondary">需重试</div>
            <div className="mt-2 text-2xl font-semibold">{summary.failed}</div>
          </div>
        </div>

        <section className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
          <div className="grid gap-3 md:grid-cols-[1fr_180px_auto]">
            <input
              value={filterUserId}
              onChange={(event) => setFilterUserId(event.target.value)}
              placeholder="按用户 ID 筛选"
              className="rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
            />
            <select
              value={filterStatus}
              onChange={(event) => setFilterStatus(event.target.value)}
              className="rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
            >
              <option value="">全部状态</option>
              <option value="queued">queued</option>
              <option value="completed">completed</option>
              <option value="partial_failed">partial_failed</option>
            </select>
            <button
              type="button"
              onClick={() => void loadAll()}
              className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue"
            >
              应用筛选
            </button>
          </div>
        </section>

        <section className="overflow-hidden rounded-lg border border-border-secondary bg-bg-secondary">
          <div className="grid grid-cols-[1.1fr_0.8fr_0.8fr_1.2fr_120px] gap-3 border-b border-border-secondary px-4 py-3 text-xs font-semibold uppercase tracking-wide text-text-secondary">
            <div>请求</div>
            <div>IM 删除</div>
            <div>OSS 媒体</div>
            <div>失败原因 / 目标</div>
            <div>操作</div>
          </div>
          <div className="divide-y divide-border-secondary">
            {items.map((item) => {
              const objectKeys = item.mediaTargets?.objectKeys || [];
              return (
                <div key={item.id} className="grid grid-cols-[1.1fr_0.8fr_0.8fr_1.2fr_120px] gap-3 px-4 py-4 text-sm">
                  <div className="min-w-0 space-y-2">
                    <StatusBadge status={item.status} />
                    <div className="break-all font-mono text-xs text-text-secondary">{item.id}</div>
                    <div className="break-all text-text-secondary">user: {item.userId}</div>
                    <div className="text-text-secondary">{formatTime(item.createdAt)}</div>
                  </div>
                  <div className="space-y-2">
                    <StatusBadge status={item.imStatus} />
                    <div className="text-text-secondary">尝试 {item.imAttempts}</div>
                    <div className="break-all text-xs text-text-secondary">{item.imUserId || '-'}</div>
                    <ErrorText value={item.imLastError} />
                  </div>
                  <div className="space-y-2">
                    <StatusBadge status={item.mediaStatus} />
                    <div className="text-text-secondary">尝试 {item.mediaAttempts}</div>
                    <div className="text-text-secondary">{objectKeys.length} 个对象</div>
                    <ErrorText value={item.mediaLastError} />
                  </div>
                  <div className="min-w-0 space-y-2">
                    <div className="text-text-secondary">完成：{formatTime(item.completedAt)}</div>
                    <div className="max-h-28 overflow-auto rounded-md border border-border-secondary bg-bg-tertiary p-2 font-mono text-xs text-text-secondary">
                      {objectKeys.length > 0 ? objectKeys.join('\n') : '-'}
                    </div>
                  </div>
                  <div>
                    {canRetry ? (
                      <button
                        type="button"
                        onClick={() => void retryRequest(item)}
                        className="rounded-lg border border-border-secondary px-3 py-2 text-xs hover:border-primary-blue hover:text-primary-blue"
                      >
                        重试
                      </button>
                    ) : (
                      <span className="text-xs text-text-secondary">只读</span>
                    )}
                  </div>
                </div>
              );
            })}
            {items.length === 0 && <div className="px-4 py-8 text-sm text-text-secondary">暂无账号删除请求。</div>}
          </div>
        </section>
      </section>
    </main>
  );
}
