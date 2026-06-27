'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import AdminAppShell from '@/components/admin/AdminAppShell';
import { useAuth } from '@/contexts/AuthContext';
import { getAdminCmsRolePolicy } from '@/lib/admin/role-policy';
import { adminAnalyticsApi, WebsiteVisitRecord, WebsiteVisitsSummary } from '@/lib/api/admin-analytics';
import { formatDateTimeWithSystemTimeZoneLabel } from '@/lib/timezone';

const maskHash = (value?: string | null): string => {
  if (!value) return '-';
  return `${value.slice(0, 10)}...${value.slice(-6)}`;
};

const formatTime = (value?: string | null): string => {
  if (!value) return '-';
  return formatDateTimeWithSystemTimeZoneLabel(value);
};

const formatScreen = (visit: WebsiteVisitRecord): string => {
  const screen = visit.screen;
  if (!screen) return '-';
  const viewport = screen.viewportWidth && screen.viewportHeight ? `${screen.viewportWidth}x${screen.viewportHeight}` : '-';
  const physical = screen.width && screen.height ? `${screen.width}x${screen.height}` : '-';
  const ratio = screen.devicePixelRatio ? ` @${screen.devicePixelRatio}x` : '';
  return `${viewport} / ${physical}${ratio}`;
};

function Metric({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
      <div className="text-sm text-text-secondary">{label}</div>
      <div className="mt-2 text-2xl font-semibold">{value}</div>
    </div>
  );
}

function TopList({ title, items }: { title: string; items: Array<{ value: string; count: number }> }) {
  return (
    <section className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
      <h2 className="text-lg font-semibold">{title}</h2>
      <div className="mt-4 space-y-2">
        {items.length ? (
          items.map((item) => (
            <div key={item.value} className="flex items-center justify-between gap-4 rounded-lg border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm">
              <span className="min-w-0 truncate text-text-secondary">{item.value}</span>
              <span className="shrink-0 font-semibold">{item.count}</span>
            </div>
          ))
        ) : (
          <div className="rounded-lg border border-dashed border-border-secondary p-4 text-sm text-text-secondary">暂无数据</div>
        )}
      </div>
    </section>
  );
}

export default function AdminWebsiteVisitsPage() {
  const { user, isLoading } = useAuth();
  const rolePolicy = useMemo(() => getAdminCmsRolePolicy(user), [user]);
  const [limit, setLimit] = useState('100');
  const [summary, setSummary] = useState<WebsiteVisitsSummary | null>(null);
  const [visits, setVisits] = useState<WebsiteVisitRecord[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadVisits = useCallback(async () => {
    if (!rolePolicy.canAccessOperations) return;

    try {
      setLoading(true);
      setError(null);
      const numericLimit = Number(limit) > 0 ? Number(limit) : 100;
      const data = await adminAnalyticsApi.getWebsiteVisits(numericLimit);
      setSummary(data.summary);
      setVisits(data.visits);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载访客记录失败');
    } finally {
      setLoading(false);
    }
  }, [limit, rolePolicy.canAccessOperations]);

  useEffect(() => {
    void loadVisits();
  }, [loadVisits]);

  if (isLoading) {
    return (
      <AdminAppShell title="访客记录" description="加载访客记录中。">
        <div className="admin-shell-panel p-8 text-sm text-black/55">加载中...</div>
      </AdminAppShell>
    );
  }

  if (!user) {
    return (
      <AdminAppShell title="访客记录" description="登录后可查看官网访客记录。">
        <div className="admin-shell-panel p-8">
          <p className="text-lg">请先登录后访问运营后台。</p>
          <Link href="/login" className="mt-4 inline-flex rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            去登录
          </Link>
        </div>
      </AdminAppShell>
    );
  }

  if (!rolePolicy.canAccessOperations) {
    return (
      <AdminAppShell title="访客记录" description="当前账号暂时没有访客记录查看权限。">
        <div className="admin-shell-panel p-8">
          <p className="text-lg">当前账号无权限访问访客记录。</p>
        </div>
      </AdminAppShell>
    );
  }

  return (
    <AdminAppShell
      title="访客记录"
      eyebrow="Raver Admin / Analytics"
      description="查看 ravehub.top 官网最近访问记录。当前为轻量 JSONL 记录，不包含明文 IP。"
      actions={
        <>
          <label className="admin-shell-soft-panel flex items-center gap-3 rounded-full px-4 py-3 text-sm text-[#071110]">
            <span className="text-black/45">条数</span>
            <input
              value={limit}
              onChange={(event) => setLimit(event.target.value)}
              className="w-20 rounded-full px-3 py-2 text-center text-sm"
            />
          </label>
          <button
            type="button"
            onClick={() => void loadVisits()}
            disabled={loading}
            className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white disabled:opacity-60"
          >
            {loading ? '刷新中...' : '刷新'}
          </button>
        </>
      }
    >
      <section className="space-y-5">
        {error && <div className="rounded-lg border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300">{error}</div>}

        <div className="grid gap-4 md:grid-cols-3">
          <Metric label="最近日志访问数" value={summary?.totalVisits ?? 0} />
          <Metric label="最近独立访客" value={summary?.uniqueVisitors ?? 0} />
          <Metric label="当前展示记录" value={visits.length} />
        </div>

        <div className="grid gap-4 lg:grid-cols-2">
          <TopList title="热门路径" items={summary?.topPaths ?? []} />
          <TopList title="访问来源" items={summary?.topReferrers ?? []} />
        </div>

        <section className="rounded-lg border border-border-secondary bg-bg-secondary">
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border-secondary px-5 py-4">
            <div>
              <h2 className="text-lg font-semibold">最近访问</h2>
              <p className="mt-1 text-sm text-text-secondary">visitor 和 IP 均为 hash 后展示。</p>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-border-secondary text-sm">
              <thead className="bg-bg-tertiary text-left text-xs uppercase tracking-[0.12em] text-text-secondary">
                <tr>
                  <th className="px-4 py-3 font-semibold">时间</th>
                  <th className="px-4 py-3 font-semibold">路径</th>
                  <th className="px-4 py-3 font-semibold">来源</th>
                  <th className="px-4 py-3 font-semibold">访客</th>
                  <th className="px-4 py-3 font-semibold">IP Hash</th>
                  <th className="px-4 py-3 font-semibold">语言/时区</th>
                  <th className="px-4 py-3 font-semibold">屏幕</th>
                  <th className="px-4 py-3 font-semibold">User-Agent</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border-secondary">
                {visits.length ? (
                  visits.map((visit) => (
                    <tr key={visit.id || `${visit.createdAt}-${visit.visitorIdHash}`} className="align-top">
                      <td className="whitespace-nowrap px-4 py-3 text-text-secondary">{formatTime(visit.createdAt)}</td>
                      <td className="max-w-[16rem] px-4 py-3">
                        <div className="truncate font-medium">{visit.path || '-'}</div>
                      </td>
                      <td className="max-w-[18rem] px-4 py-3 text-text-secondary">
                        <div className="truncate">{visit.referrer || 'direct'}</div>
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 font-mono text-xs text-text-secondary">{maskHash(visit.visitorIdHash)}</td>
                      <td className="whitespace-nowrap px-4 py-3 font-mono text-xs text-text-secondary">{maskHash(visit.ipHash)}</td>
                      <td className="whitespace-nowrap px-4 py-3 text-text-secondary">
                        {visit.language || '-'} / {visit.timezone || '-'}
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 text-text-secondary">{formatScreen(visit)}</td>
                      <td className="max-w-[24rem] px-4 py-3 text-text-secondary">
                        <div className="truncate">{visit.userAgent || '-'}</div>
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={8} className="px-5 py-10 text-center text-text-secondary">
                      暂无访客记录。真实用户访问官网后会自动写入。
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
      </section>
    </AdminAppShell>
  );
}
