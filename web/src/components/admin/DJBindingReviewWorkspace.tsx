'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import Navigation from '@/components/Navigation';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import { useAuth } from '@/contexts/AuthContext';
import {
  DJEventBindingReviewCandidate,
  DJEventBindingReviewJob,
  djEventBindingReviewApi,
} from '@/lib/api/dj-event-binding-review';
import { formatDateTimeWithSystemTimeZoneLabel } from '@/lib/timezone';

const formatTime = (value?: string | null): string => {
  if (!value) return '-';
  return formatDateTimeWithSystemTimeZoneLabel(value);
};

const jobStatusClassName = (status: string): string => {
  if (status === 'applied') return 'border-accent-green/40 bg-accent-green/10 text-accent-green';
  if (status === 'partially_applied') return 'border-primary-blue/40 bg-primary-blue/10 text-primary-blue';
  if (status === 'dismissed') return 'border-border-secondary bg-bg-tertiary text-text-secondary';
  return 'border-yellow-500/40 bg-yellow-500/10 text-yellow-300';
};

const candidateStatusClassName = (status: string): string => {
  if (status === 'applied') return 'border-accent-green/40 bg-accent-green/10 text-accent-green';
  if (status === 'skipped_already_bound') return 'border-border-secondary bg-bg-tertiary text-text-secondary';
  if (status === 'dismissed') return 'border-red-500/30 bg-red-500/10 text-red-300';
  return 'border-yellow-500/40 bg-yellow-500/10 text-yellow-300';
};

const tierClassName = (tier: string): string =>
  tier === 'exact'
    ? 'border-accent-green/40 bg-accent-green/10 text-accent-green'
    : 'border-primary-blue/40 bg-primary-blue/10 text-primary-blue';

function StatusBadge({ status, className }: { status: string; className: (status: string) => string }) {
  return <span className={`inline-flex rounded-md border px-2.5 py-1 text-xs font-semibold ${className(status)}`}>{status}</span>;
}

function SummaryMetric({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-4">
      <div className="text-sm text-text-secondary">{label}</div>
      <div className="mt-2 text-2xl font-semibold">{value}</div>
    </div>
  );
}

type DJBindingReviewWorkspaceProps = {
  embedded?: boolean;
};

export default function DJBindingReviewWorkspace({ embedded = false }: DJBindingReviewWorkspaceProps) {
  const { user, token, isLoading } = useAuth();
  const canOperate = user?.role === 'admin' || user?.role === 'operator';

  const [jobs, setJobs] = useState<DJEventBindingReviewJob[]>([]);
  const [selectedJobId, setSelectedJobId] = useState<string>('');
  const [selectedCandidateIds, setSelectedCandidateIds] = useState<string[]>([]);
  const [statusFilter, setStatusFilter] = useState('');
  const [listLoading, setListLoading] = useState(false);
  const [detailLoading, setDetailLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [selectedJob, setSelectedJob] = useState<DJEventBindingReviewJob | null>(null);

  const loadJobs = useCallback(async () => {
    if (!token || !canOperate) return;
    try {
      setListLoading(true);
      setError(null);
      const result = await djEventBindingReviewApi.list(token, {
        status: statusFilter || undefined,
        page: 1,
        limit: 50,
      });
      setJobs(result.items);
      setSelectedJobId((current) => {
        if (current && result.items.some((item) => item.id === current)) return current;
        return result.items[0]?.id ?? '';
      });
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载 DJ 绑定审核任务失败');
    } finally {
      setListLoading(false);
    }
  }, [canOperate, statusFilter, token]);

  const loadJobDetail = useCallback(async () => {
    if (!token || !selectedJobId || !canOperate) {
      setSelectedJob(null);
      setSelectedCandidateIds([]);
      return;
    }
    try {
      setDetailLoading(true);
      setError(null);
      const detail = await djEventBindingReviewApi.detail(token, selectedJobId);
      setSelectedJob(detail);
      setSelectedCandidateIds([]);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载任务详情失败');
    } finally {
      setDetailLoading(false);
    }
  }, [canOperate, selectedJobId, token]);

  useEffect(() => {
    void loadJobs();
  }, [loadJobs]);

  useEffect(() => {
    void loadJobDetail();
  }, [loadJobDetail]);

  const refreshAll = useCallback(async () => {
    await loadJobs();
  }, [loadJobs]);

  const handleAction = useCallback(
    async (action: () => Promise<DJEventBindingReviewJob>, successMessage: string) => {
      try {
        setActionLoading(true);
        setError(null);
        setNotice(null);
        const updated = await action();
        setNotice(successMessage);
        setSelectedJob(updated);
        setSelectedCandidateIds([]);
        await loadJobs();
      } catch (actionError) {
        setError(actionError instanceof Error ? actionError.message : '操作失败');
      } finally {
        setActionLoading(false);
      }
    },
    [loadJobs]
  );

  const pendingCandidates = useMemo(
    () => (selectedJob?.candidates ?? []).filter((candidate) => candidate.status === 'pending'),
    [selectedJob]
  );

  const exactPendingCandidates = useMemo(
    () => pendingCandidates.filter((candidate) => candidate.matchTier === 'exact'),
    [pendingCandidates]
  );

  const summary = useMemo(() => {
    const pending = jobs.filter((job) => job.status === 'pending').length;
    const partial = jobs.filter((job) => job.status === 'partially_applied').length;
    const exact = jobs.reduce((sum, job) => sum + job.exactCount, 0);
    return { total: jobs.length, pending, partial, exact };
  }, [jobs]);

  const toggleCandidate = (candidate: DJEventBindingReviewCandidate, checked: boolean) => {
    setSelectedCandidateIds((current) => {
      const next = new Set(current);
      if (checked) {
        next.add(candidate.id);
      } else {
        next.delete(candidate.id);
      }
      return Array.from(next);
    });
  };

  const toggleAllPending = (checked: boolean) => {
    setSelectedCandidateIds(checked ? pendingCandidates.map((candidate) => candidate.id) : []);
  };

  const content = (
    <>
      {error && <div className="rounded-2xl border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300">{error}</div>}
      {notice && <div className="rounded-2xl border border-accent-green/40 bg-accent-green/10 px-4 py-3 text-sm text-accent-green">{notice}</div>}

      <div className="grid gap-4 md:grid-cols-4">
        <SummaryMetric label="当前任务" value={summary.total} />
        <SummaryMetric label="待处理" value={summary.pending} />
        <SummaryMetric label="部分已应用" value={summary.partial} />
        <SummaryMetric label="Exact 候选总数" value={summary.exact} />
      </div>

      <div className="grid gap-5 xl:grid-cols-[360px_minmax(0,1fr)]">
        <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-5">
          <div className="flex items-center justify-between gap-3">
            <div>
              <div className="text-sm text-text-secondary">任务列表</div>
              <div className="mt-1 text-lg font-semibold">Binding Review Jobs</div>
            </div>
            <select
              value={statusFilter}
              onChange={(event) => setStatusFilter(event.target.value)}
              className="rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
            >
              <option value="">全部状态</option>
              <option value="pending">pending</option>
              <option value="partially_applied">partially_applied</option>
              <option value="applied">applied</option>
              <option value="dismissed">dismissed</option>
            </select>
          </div>

          <div className="mt-4 space-y-3">
            {jobs.map((job) => {
              const isSelected = job.id === selectedJobId;
              return (
                <button
                  key={job.id}
                  type="button"
                  onClick={() => setSelectedJobId(job.id)}
                  className={`w-full rounded-2xl border p-4 text-left transition ${
                    isSelected
                      ? 'border-primary-blue bg-primary-blue/10'
                      : 'border-border-secondary bg-bg-tertiary hover:border-primary-blue/60'
                  }`}
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="truncate text-sm text-text-secondary">{job.djNameSnapshot}</div>
                      <div className="truncate text-base font-semibold">{job.dj.name}</div>
                    </div>
                    <StatusBadge status={job.status} className={jobStatusClassName} />
                  </div>
                  <div className="mt-3 grid grid-cols-3 gap-2 text-xs text-text-secondary">
                    <div>Exact {job.exactCount}</div>
                    <div>Fuzzy {job.fuzzyCount}</div>
                    <div>Applied {job.appliedCount}</div>
                  </div>
                  <div className="mt-3 text-xs text-text-secondary">
                    来源 {job.triggerSource} · {formatTime(job.createdAt)}
                  </div>
                </button>
              );
            })}

            {!jobs.length && !listLoading && (
              <div className="rounded-2xl border border-dashed border-border-secondary px-4 py-8 text-center text-sm text-text-secondary">
                暂无 DJ 绑定审核任务
              </div>
            )}
          </div>
        </section>

        <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-5">
          {!selectedJob ? (
            <div className="rounded-2xl border border-dashed border-border-secondary px-4 py-12 text-center text-sm text-text-secondary">
              请选择左侧一个 DJ 绑定审核任务
            </div>
          ) : (
            <div className="space-y-5">
              <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                <div>
                  <div className="text-sm text-text-secondary">任务详情</div>
                  <h2 className="mt-1 text-2xl font-semibold">{selectedJob.dj.name}</h2>
                  <div className="mt-2 flex flex-wrap gap-2 text-sm text-text-secondary">
                    <span>状态 {selectedJob.status}</span>
                    <span>来源 {selectedJob.triggerSource}</span>
                    <span>创建于 {formatTime(selectedJob.createdAt)}</span>
                  </div>
                </div>
                <div className="flex flex-wrap gap-3">
                  <button
                    type="button"
                    disabled={!exactPendingCandidates.length || actionLoading}
                    onClick={() =>
                      void handleAction(
                        async () => djEventBindingReviewApi.applyExact(token || '', selectedJob.id),
                        '已应用全部 exact 候选'
                      )
                    }
                    className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
                  >
                    Apply Exact
                  </button>
                  <button
                    type="button"
                    disabled={!selectedCandidateIds.length || actionLoading}
                    onClick={() =>
                      void handleAction(
                        async () => djEventBindingReviewApi.applyCandidates(token || '', selectedJob.id, selectedCandidateIds),
                        '已应用所选候选'
                      )
                    }
                    className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue disabled:opacity-50"
                  >
                    Apply Selected
                  </button>
                  <button
                    type="button"
                    disabled={!selectedCandidateIds.length || actionLoading}
                    onClick={() =>
                      void handleAction(
                        async () =>
                          djEventBindingReviewApi.dismissCandidates(token || '', selectedJob.id, {
                            candidateIds: selectedCandidateIds,
                          }),
                        '已忽略所选候选'
                      )
                    }
                    className="rounded-lg border border-red-500/40 px-4 py-2 text-sm text-red-300 hover:bg-red-500/10 disabled:opacity-50"
                  >
                    Dismiss Selected
                  </button>
                </div>
              </div>

              <div className="grid gap-4 md:grid-cols-3">
                <SummaryMetric label="Exact" value={selectedJob.exactCount} />
                <SummaryMetric label="Fuzzy" value={selectedJob.fuzzyCount} />
                <SummaryMetric label="Applied" value={selectedJob.appliedCount} />
              </div>

              <div className="flex items-center justify-between gap-3 rounded-2xl border border-border-secondary bg-bg-tertiary px-4 py-3">
                <div>
                  <div className="text-sm font-semibold">候选列表</div>
                  <div className="mt-1 text-xs text-text-secondary">
                    pending 候选可批量勾选。Exact 命中通常可以直接点 `Apply Exact`。
                  </div>
                </div>
                <label className="flex items-center gap-2 text-sm text-text-secondary">
                  <input
                    type="checkbox"
                    checked={pendingCandidates.length > 0 && selectedCandidateIds.length === pendingCandidates.length}
                    onChange={(event) => toggleAllPending(event.target.checked)}
                  />
                  全选 pending
                </label>
              </div>

              <div className="space-y-3">
                {(selectedJob.candidates ?? []).map((candidate) => {
                  const isSelected = selectedCandidateIds.includes(candidate.id);
                  const canSelect = candidate.status === 'pending';
                  return (
                    <div key={candidate.id} className="rounded-2xl border border-border-secondary bg-bg-tertiary p-4">
                      <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
                        <div className="min-w-0">
                          <div className="flex flex-wrap items-center gap-2">
                            <label className="flex items-center gap-2 text-sm">
                              <input
                                type="checkbox"
                                checked={isSelected}
                                disabled={!canSelect}
                                onChange={(event) => toggleCandidate(candidate, event.target.checked)}
                              />
                              <span className="font-semibold">{candidate.rawName}</span>
                            </label>
                            <StatusBadge status={candidate.matchTier} className={tierClassName} />
                            <StatusBadge status={candidate.status} className={candidateStatusClassName} />
                          </div>
                          <div className="mt-2 flex flex-wrap gap-3 text-sm text-text-secondary">
                            <span>事件：{candidate.eventNameSnapshot}</span>
                            <span>来源：{candidate.sourceType}</span>
                            <span>分数：{candidate.matchScore}</span>
                            <span>原因：{candidate.matchReason}</span>
                          </div>
                          <div className="mt-2 flex flex-wrap gap-3 text-xs text-text-secondary">
                            <span>eventId {candidate.eventId}</span>
                            {candidate.eventArtistId && <span>artist {candidate.eventArtistId}</span>}
                            {candidate.eventArtistMemberId && <span>member {candidate.eventArtistMemberId}</span>}
                            {candidate.eventPerformanceId && <span>slot {candidate.eventPerformanceId}</span>}
                            {candidate.stageNameSnapshot && <span>stage {candidate.stageNameSnapshot}</span>}
                            <span>time {formatTime(candidate.startAtSnapshot)}</span>
                          </div>
                        </div>
                        <div className="flex shrink-0 flex-wrap gap-2">
                          {canSelect && (
                            <>
                              <button
                                type="button"
                                disabled={actionLoading}
                                onClick={() =>
                                  void handleAction(
                                    async () => djEventBindingReviewApi.applyCandidates(token || '', selectedJob.id, [candidate.id]),
                                    '已应用该候选'
                                  )
                                }
                                className="rounded-md bg-primary-blue px-3 py-2 text-xs font-semibold text-white disabled:opacity-50"
                              >
                                Apply
                              </button>
                              <button
                                type="button"
                                disabled={actionLoading}
                                onClick={() =>
                                  void handleAction(
                                    async () =>
                                      djEventBindingReviewApi.dismissCandidates(token || '', selectedJob.id, {
                                        candidateIds: [candidate.id],
                                      }),
                                    '已忽略该候选'
                                  )
                                }
                                className="rounded-md border border-red-500/40 px-3 py-2 text-xs text-red-300 hover:bg-red-500/10 disabled:opacity-50"
                              >
                                Dismiss
                              </button>
                            </>
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })}

                {!selectedJob.candidates?.length && !detailLoading && (
                  <div className="rounded-2xl border border-dashed border-border-secondary px-4 py-8 text-center text-sm text-text-secondary">
                    这个任务当前没有候选
                  </div>
                )}
              </div>
            </div>
          )}
        </section>
      </div>
    </>
  );

  if (isLoading) {
    return embedded ? (
      <AdminContentLayout title="DJ 绑定审核" eyebrow="Admin / Content Workspace / Reviews" description="加载中...">
        <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-6 text-sm text-text-secondary">加载中...</div>
      </AdminContentLayout>
    ) : (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <div className="mx-auto max-w-6xl px-6 pt-28">加载中...</div>
      </main>
    );
  }

  if (!user || !canOperate) {
    return embedded ? (
      <AdminContentLayout
        title="DJ 绑定审核"
        eyebrow="Admin / Content Workspace / Reviews"
        description="当前账号无权限访问该页面。"
        actions={
          <Link href={user ? '/admin/content' : '/login'} className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
            {user ? '返回内容后台' : '去登录'}
          </Link>
        }
      >
        <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-6 text-sm text-text-secondary">当前账号无权限访问该页面。</div>
      </AdminContentLayout>
    ) : (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <section className="mx-auto max-w-4xl px-6 pt-28">
          <div className="rounded-lg border border-border-secondary bg-bg-secondary p-6">
            <h1 className="text-2xl font-semibold">DJ 绑定审核</h1>
            <p className="mt-3 text-sm text-text-secondary">当前账号无权限访问该页面。</p>
            <Link href={user ? '/admin' : '/login'} className="mt-5 inline-block rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
              {user ? '返回后台' : '去登录'}
            </Link>
          </div>
        </section>
      </main>
    );
  }

  if (embedded) {
    return (
      <AdminContentLayout
        title="DJ 绑定审核"
        eyebrow="Admin / Content Workspace / Reviews"
        description="原生承接 DJ 与 Event 阵容 / member / timetable slot 的自动命中审核，不再通过旧工具说明页做跳转。这里直接处理 apply、dismiss 与 exact 批量应用。"
        actions={
          <>
            <Link href="/admin/content/reviews" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
              返回审核中心
            </Link>
            <button
              type="button"
              onClick={() => void refreshAll()}
              disabled={listLoading || detailLoading || actionLoading}
              className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
            >
              {listLoading || detailLoading ? '刷新中...' : '刷新'}
            </button>
          </>
        }
      >
        {content}
      </AdminContentLayout>
    );
  }

  return (
    <main className="min-h-screen bg-bg-primary text-text-primary">
      <Navigation />
      <section className="mx-auto max-w-7xl space-y-5 px-6 pb-12 pt-24">
        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <p className="text-sm text-text-secondary">Content Ops</p>
            <h1 className="mt-1 text-3xl font-semibold">DJ 绑定审核</h1>
            <p className="mt-2 text-sm leading-6 text-text-secondary">
              管理 DJ 与 Event 阵容 / member / timetable slot 的自动命中结果。可先看 exact 命中，再一键 apply。
            </p>
          </div>
          <div className="flex flex-wrap gap-3">
            <button
              type="button"
              onClick={() => void refreshAll()}
              disabled={listLoading || detailLoading || actionLoading}
              className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
            >
              {listLoading || detailLoading ? '刷新中...' : '刷新'}
            </button>
            <Link href="/admin" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
              返回后台
            </Link>
          </div>
        </div>
        {content}
      </section>
    </main>
  );
}
