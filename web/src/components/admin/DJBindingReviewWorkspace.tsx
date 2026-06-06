'use client';

import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { useCallback, useEffect, useMemo, useState } from 'react';
import AdminAppShell from '@/components/admin/AdminAppShell';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import { useAuth } from '@/contexts/AuthContext';
import {
  DJEventBindingReviewCandidate,
  DJEventBindingReviewJob,
  djEventBindingReviewApi,
} from '@/lib/api/dj-event-binding-review';
import { formatDateTimeWithSystemTimeZoneLabel } from '@/lib/timezone';

// ─── Helpers ──────────────────────────────────────────────────────────────────

const formatTime = (value?: string | null): string => {
  if (!value) return '—';
  return formatDateTimeWithSystemTimeZoneLabel(value);
};

// ─── Badge helpers ────────────────────────────────────────────────────────────

function JobStatusBadge({ status }: { status: string }) {
  const map: Record<string, string> = {
    applied:           'bg-emerald-100 text-emerald-700 border border-emerald-200',
    partially_applied: 'bg-blue-100 text-blue-700 border border-blue-200',
    dismissed:         'bg-gray-100 text-gray-500 border border-gray-200',
    pending:           'bg-amber-100 text-amber-700 border border-amber-200',
  };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold ${map[status] ?? 'bg-gray-100 text-gray-500'}`}>
      {status}
    </span>
  );
}

function TierBadge({ tier }: { tier: string }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-semibold ${
      tier === 'exact'
        ? 'bg-emerald-100 text-emerald-700'
        : 'bg-blue-100 text-blue-700'
    }`}>
      {tier}
    </span>
  );
}

function CandidateStatusBadge({ status }: { status: string }) {
  const map: Record<string, string> = {
    applied:              'bg-emerald-100 text-emerald-700',
    skipped_already_bound:'bg-gray-100 text-gray-500',
    dismissed:            'bg-red-100 text-red-600',
    pending:              'bg-amber-100 text-amber-700',
  };
  return (
    <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-semibold ${map[status] ?? 'bg-gray-100 text-gray-500'}`}>
      {status}
    </span>
  );
}

// ─── Stat card ────────────────────────────────────────────────────────────────

function StatCard({ icon, label, value }: { icon: React.ReactNode; label: string; value: number }) {
  return (
    <div className="flex items-center gap-4 rounded-xl border border-gray-200 bg-white px-5 py-4 shadow-sm">
      <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-xl bg-gray-100 text-gray-500">
        {icon}
      </div>
      <div>
        <div className="text-xs text-gray-500">{label}</div>
        <div className="mt-0.5 text-2xl font-bold leading-tight text-gray-900">{value}</div>
      </div>
    </div>
  );
}

// ─── Pagination ───────────────────────────────────────────────────────────────

function Pagination({
  page, totalPages, total, pageSize,
  onPageChange, onPageSizeChange,
}: {
  page: number;
  totalPages: number;
  total: number;
  pageSize: number;
  onPageChange: (p: number) => void;
  onPageSizeChange: (s: number) => void;
}) {
  const pages = useMemo(() => {
    const safe = Math.max(1, totalPages);
    const start = Math.max(1, Math.min(safe - 4, page - 2));
    const end = Math.min(safe, start + 4);
    return Array.from({ length: end - start + 1 }, (_, i) => start + i);
  }, [page, totalPages]);

  return (
    <div className="flex items-center justify-between border-t border-gray-100 px-5 py-3">
      <span className="text-xs text-gray-400">共 {total} 条</span>
      <div className="flex items-center gap-1.5">
        <button
          type="button"
          disabled={page <= 1}
          onClick={() => onPageChange(page - 1)}
          className="flex h-7 w-7 items-center justify-center rounded-md border border-gray-200 bg-white text-gray-500 transition hover:bg-gray-50 disabled:opacity-40"
        >
          <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
            <path d="M15 18l-6-6 6-6" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </button>
        {pages.map((p) => (
          <button
            key={p}
            type="button"
            onClick={() => onPageChange(p)}
            className={`h-7 min-w-[28px] rounded-md px-2 text-xs font-semibold transition ${
              p === page ? 'bg-gray-900 text-white' : 'border border-gray-200 bg-white text-gray-600 hover:bg-gray-50'
            }`}
          >
            {p}
          </button>
        ))}
        <button
          type="button"
          disabled={page >= totalPages}
          onClick={() => onPageChange(page + 1)}
          className="flex h-7 w-7 items-center justify-center rounded-md border border-gray-200 bg-white text-gray-500 transition hover:bg-gray-50 disabled:opacity-40"
        >
          <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
            <path d="M9 18l6-6-6-6" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </button>
      </div>
      <div className="flex items-center gap-1.5">
        <div className="relative">
          <select
            value={pageSize}
            onChange={(e) => onPageSizeChange(Number(e.target.value))}
            className="appearance-none rounded-lg border border-gray-200 bg-white py-1 pl-3 pr-7 text-xs font-medium text-gray-700 focus:outline-none"
          >
            {[10, 20, 50].map((s) => (
              <option key={s} value={s}>{s} 条/页</option>
            ))}
          </select>
          <svg className="pointer-events-none absolute right-2 top-1/2 h-3 w-3 -translate-y-1/2 text-gray-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
            <path d="M6 9l6 6 6-6" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </div>
      </div>
    </div>
  );
}

// ─── Types ────────────────────────────────────────────────────────────────────

type DetailTab = 'exact' | 'fuzzy' | 'applied';

type DJBindingReviewWorkspaceProps = {
  embedded?: boolean;
};

// ─── Main component ───────────────────────────────────────────────────────────

export default function DJBindingReviewWorkspace({ embedded = false }: DJBindingReviewWorkspaceProps) {
  const searchParams = useSearchParams();
  const { user, token, isLoading } = useAuth();
  const canOperate = user?.role === 'admin' || user?.role === 'operator';
  const focusDjId = useMemo(() => searchParams.get('djId')?.trim() || '', [searchParams]);

  // List state
  const [jobs, setJobs] = useState<DJEventBindingReviewJob[]>([]);
  const [selectedJobId, setSelectedJobId] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [listPage, setListPage] = useState(1);
  const [listPageSize, setListPageSize] = useState(10);
  const [listLoading, setListLoading] = useState(false);
  const [listTotal, setListTotal] = useState(0);

  // Detail state
  const [selectedJob, setSelectedJob] = useState<DJEventBindingReviewJob | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailTab, setDetailTab] = useState<DetailTab>('exact');
  const [selectedCandidateIds, setSelectedCandidateIds] = useState<string[]>([]);

  // Candidate pagination
  const [candidatePage, setCandidatePage] = useState(1);
  const [candidatePageSize, setCandidatePageSize] = useState(10);

  // Action state
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  // ── Load jobs list ──────────────────────────────────────────────────────────

  const loadJobs = useCallback(async () => {
    if (!token || !canOperate) return;
    try {
      setListLoading(true);
      setError(null);
      const result = await djEventBindingReviewApi.list(token, {
        status: statusFilter || undefined,
        page: listPage,
        limit: listPageSize,
      });
      setJobs(result.items);
      setListTotal(result.pagination?.total ?? result.items.length);
      setSelectedJobId((cur) => {
        if (cur && result.items.some((j) => j.id === cur)) return cur;
        if (focusDjId) {
          const focused = result.items.find((j) => j.djId === focusDjId);
          if (focused) return focused.id;
        }
        return result.items[0]?.id ?? '';
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : '加载 DJ 绑定审核任务失败');
    } finally {
      setListLoading(false);
    }
  }, [canOperate, focusDjId, listPage, listPageSize, statusFilter, token]);

  // ── Load job detail ─────────────────────────────────────────────────────────

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
      setCandidatePage(1);
      setDetailTab('exact');
    } catch (e) {
      setError(e instanceof Error ? e.message : '加载任务详情失败');
    } finally {
      setDetailLoading(false);
    }
  }, [canOperate, selectedJobId, token]);

  useEffect(() => { void loadJobs(); }, [loadJobs]);
  useEffect(() => { void loadJobDetail(); }, [loadJobDetail]);

  useEffect(() => {
    if (!focusDjId || !jobs.length) return;
    const focused = jobs.find((j) => j.djId === focusDjId);
    if (!focused) {
      setNotice('已打开绑定审核台，但当前列表里还没有这个 DJ 的候选任务。');
      return;
    }
    setSelectedJobId((cur) => (cur === focused.id ? cur : focused.id));
    setNotice(`已定位到 ${focused.dj.name} 的绑定候选。系统只会列出候选，不会自动绑定。`);
  }, [focusDjId, jobs]);

  // ── Actions ─────────────────────────────────────────────────────────────────

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
      } catch (e) {
        setError(e instanceof Error ? e.message : '操作失败');
      } finally {
        setActionLoading(false);
      }
    },
    [loadJobs],
  );

  const refreshAll = useCallback(async () => { await loadJobs(); }, [loadJobs]);

  // ── Candidate grouping ──────────────────────────────────────────────────────

  const allCandidates    = selectedJob?.candidates ?? [];
  const exactCandidates  = allCandidates.filter((c) => c.matchTier === 'exact');
  const fuzzyCandidates  = allCandidates.filter((c) => c.matchTier !== 'exact');
  const appliedCandidates = allCandidates.filter((c) => c.status === 'applied');
  const pendingCandidates = allCandidates.filter((c) => c.status === 'pending');
  const exactPendingCandidates = pendingCandidates.filter((c) => c.matchTier === 'exact');

  const tabCandidates: Record<DetailTab, DJEventBindingReviewCandidate[]> = {
    exact:   exactCandidates,
    fuzzy:   fuzzyCandidates,
    applied: appliedCandidates,
  };

  const currentTabCandidates = tabCandidates[detailTab];
  const currentTabSelectableCandidates = currentTabCandidates.filter((candidate) => candidate.status === 'pending');
  const candidateTotal = currentTabCandidates.length;
  const candidateTotalPages = Math.max(1, Math.ceil(candidateTotal / candidatePageSize));
  const pagedCandidates = currentTabCandidates.slice(
    (candidatePage - 1) * candidatePageSize,
    candidatePage * candidatePageSize,
  );

  // ── Summary ─────────────────────────────────────────────────────────────────

  const summary = useMemo(() => ({
    total:   listTotal,
    pending: jobs.filter((j) => j.status === 'pending').length,
    partial: jobs.filter((j) => j.status === 'partially_applied').length,
    exact:   jobs.reduce((s, j) => s + j.exactCount, 0),
  }), [jobs, listTotal]);

  const listTotalPages = Math.max(1, Math.ceil(listTotal / listPageSize));

  // ── Toggle helpers ───────────────────────────────────────────────────────────

  const toggleCandidate = (id: string, checked: boolean) =>
    setSelectedCandidateIds((cur) => checked ? [...new Set([...cur, id])] : cur.filter((x) => x !== id));

  const toggleAllPending = (checked: boolean) =>
    setSelectedCandidateIds(checked ? currentTabSelectableCandidates.map((c) => c.id) : []);

  // ─── Content ─────────────────────────────────────────────────────────────────

  const content = (
    <div className="space-y-4">
      {/* Alerts */}
      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>
      )}
      {notice && (
        <div className="rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{notice}</div>
      )}

      {/* Stats row */}
      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <StatCard
          icon={
            <svg className="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
              <circle cx={12} cy={12} r={9} /><path d="M12 7v5l3 2" strokeLinecap="round" />
            </svg>
          }
          label="当前任务"
          value={summary.total}
        />
        <StatCard
          icon={
            <svg className="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
              <rect x={3} y={3} width={7} height={7} rx={1} /><rect x={14} y={3} width={7} height={7} rx={1} />
              <rect x={3} y={14} width={7} height={7} rx={1} /><rect x={14} y={14} width={7} height={7} rx={1} />
            </svg>
          }
          label="待处理"
          value={summary.pending}
        />
        <StatCard
          icon={
            <svg className="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
              <circle cx={8} cy={8} r={5} /><circle cx={16} cy={16} r={5} />
            </svg>
          }
          label="部分已应用"
          value={summary.partial}
        />
        <StatCard
          icon={
            <svg className="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
              <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          }
          label="Exact 候选总数"
          value={summary.exact}
        />
      </div>

      {/* Two-column body */}
      <div className="grid gap-4 xl:grid-cols-[300px_minmax(0,1fr)] xl:items-start">

        {/* ── Left: job list ── */}
        <div className="min-w-0 rounded-xl border border-gray-200 bg-white shadow-sm">
          {/* List header */}
          <div className="flex items-center justify-between border-b border-gray-100 px-4 py-3">
            <h2 className="text-sm font-semibold text-gray-900">任务列表</h2>
            <div className="relative">
              <select
                value={statusFilter}
                onChange={(e) => { setStatusFilter(e.target.value); setListPage(1); }}
                className="appearance-none rounded-lg border border-gray-200 bg-white py-1.5 pl-3 pr-7 text-xs font-medium text-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-900/10"
              >
                <option value="">全部状态</option>
                <option value="pending">pending</option>
                <option value="partially_applied">partially_applied</option>
                <option value="applied">applied</option>
                <option value="dismissed">dismissed</option>
              </select>
              <svg className="pointer-events-none absolute right-2 top-1/2 h-3 w-3 -translate-y-1/2 text-gray-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
                <path d="M6 9l6 6 6-6" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </div>
          </div>

          {/* Job cards */}
          <div className="space-y-1.5 p-3">
            {listLoading ? (
              <div className="py-12 text-center text-xs text-gray-400">加载中…</div>
            ) : jobs.length === 0 ? (
              <div className="rounded-lg border border-dashed border-gray-200 py-10 text-center text-xs text-gray-400">
                暂无 DJ 绑定审核任务
              </div>
            ) : (
              jobs.map((job) => {
                const isSelected = job.id === selectedJobId;
                return (
                  <button
                    key={job.id}
                    type="button"
                    onClick={() => setSelectedJobId(job.id)}
                    className={`w-full rounded-lg border p-3.5 text-left transition-all ${
                      isSelected
                        ? 'border-gray-300 bg-gray-50 shadow-sm'
                        : 'border-gray-100 bg-white hover:border-gray-200 hover:bg-gray-50'
                    }`}
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <div className="truncate text-[11px] text-gray-400">{job.djNameSnapshot}</div>
                        <div className="mt-0.5 truncate text-sm font-semibold text-gray-900">{job.dj.name}</div>
                      </div>
                      <JobStatusBadge status={job.status} />
                    </div>
                    <div className="mt-2.5 grid grid-cols-3 gap-1 text-[11px] text-gray-500">
                      <span>Exact {job.exactCount}</span>
                      <span>Fuzzy {job.fuzzyCount}</span>
                      <span>Applied {job.appliedCount}</span>
                    </div>
                    <div className="mt-2 text-[10px] text-gray-400">
                      来源 {job.triggerSource} · {formatTime(job.createdAt)}
                    </div>
                  </button>
                );
              })
            )}
          </div>

          {/* List pagination */}
          {listTotal > 0 && (
            <Pagination
              page={listPage}
              totalPages={listTotalPages}
              total={listTotal}
              pageSize={listPageSize}
              onPageChange={setListPage}
              onPageSizeChange={(s) => { setListPageSize(s); setListPage(1); }}
            />
          )}
        </div>

        {/* ── Right: detail ── */}
        <div className="min-w-0 overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
          {!selectedJob ? (
            <div className="py-24 text-center text-sm text-gray-400">
              请选择左侧一个 DJ 绑定审核任务
            </div>
          ) : detailLoading ? (
            <div className="py-24 text-center text-sm text-gray-400">正在加载任务详情…</div>
          ) : (
            <>
              {/* Detail header */}
              <div className="flex flex-wrap items-center justify-between gap-3 border-b border-gray-100 px-5 py-3.5">
                <div className="flex flex-wrap items-center gap-2 min-w-0">
                  <h2 className="text-base font-bold text-gray-900">{selectedJob.dj.name}</h2>
                  <span className="text-xs text-gray-400">·</span>
                  <span className="text-xs text-gray-500">{selectedJob.triggerSource}</span>
                  <span className="text-xs text-gray-400">·</span>
                  <span className="text-xs text-gray-500">{formatTime(selectedJob.createdAt)}</span>
                </div>
                <div className="flex flex-shrink-0 flex-wrap items-center gap-2">
                  {/* Select exact */}
                  <button
                    type="button"
                    disabled={!exactPendingCandidates.length || actionLoading}
                    onClick={() => {
                      setSelectedCandidateIds(exactPendingCandidates.map((c) => c.id));
                      setNotice('已勾选全部 exact 候选，请确认后再导入。');
                    }}
                    className="rounded-lg border border-emerald-300 bg-emerald-50 px-3 py-1.5 text-xs font-semibold text-emerald-700 transition hover:bg-emerald-100 disabled:opacity-40"
                  >
                    勾选 Exact 候选
                  </button>
                  {/* Apply selected */}
                  <button
                    type="button"
                    disabled={!selectedCandidateIds.length || actionLoading}
                    onClick={() =>
                      void handleAction(
                        () => djEventBindingReviewApi.applyCandidates(token ?? '', selectedJob.id, selectedCandidateIds),
                        '已导入所选绑定',
                      )
                    }
                    className="rounded-lg bg-gray-900 px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-gray-800 disabled:opacity-40"
                  >
                    导入所选绑定
                  </button>
                  {/* More actions */}
                  <div className="relative">
                    <button
                      type="button"
                      className="flex items-center gap-1.5 rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-semibold text-gray-700 transition hover:bg-gray-50"
                    >
                      更多操作
                      <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
                        <path d="M6 9l6 6 6-6" strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                    </button>
                  </div>
                </div>
              </div>

              {/* Tabs */}
              <div className="border-b border-gray-100 px-5">
                <div className="flex gap-0">
                  {(
                    [
                      { key: 'exact' as DetailTab,   label: `Exact 候选 (${exactCandidates.length})` },
                      { key: 'fuzzy' as DetailTab,   label: `Fuzzy 候选 (${fuzzyCandidates.length})` },
                      { key: 'applied' as DetailTab, label: `已应用 (${appliedCandidates.length})` },
                    ] as { key: DetailTab; label: string }[]
                  ).map(({ key, label }) => (
                    <button
                      key={key}
                      type="button"
                      onClick={() => { setDetailTab(key); setCandidatePage(1); setSelectedCandidateIds([]); }}
                      className={`relative px-4 py-3 text-sm font-semibold transition-colors ${
                        detailTab === key
                          ? 'text-gray-900'
                          : 'text-gray-400 hover:text-gray-700'
                      }`}
                    >
                      {label}
                      {detailTab === key && (
                        <span className="absolute bottom-0 left-0 right-0 h-0.5 rounded-full bg-emerald-500" />
                      )}
                    </button>
                  ))}
                </div>
              </div>

              {/* Candidate table */}
              <div className="min-w-0 overflow-x-hidden">
                <table className="w-full table-fixed text-left text-sm">
                  <thead>
                    <tr className="border-b border-gray-100 bg-gray-50/70">
                      {detailTab !== 'applied' && (
                        <th className="w-10 px-4 py-2.5">
                          <input
                            type="checkbox"
                            checked={
                              currentTabSelectableCandidates.length > 0 &&
                              currentTabSelectableCandidates.every((candidate) => selectedCandidateIds.includes(candidate.id))
                            }
                            onChange={(e) => toggleAllPending(e.target.checked)}
                            className="h-3.5 w-3.5 rounded border-gray-300"
                          />
                        </th>
                      )}
                      <th className="px-4 py-2.5 text-[11px] font-semibold uppercase tracking-wide text-gray-400">
                        {detailTab === 'applied' ? '已绑定名称' : '候选名称'}
                      </th>
                      <th className="px-4 py-2.5 text-[11px] font-semibold uppercase tracking-wide text-gray-400">事件信息</th>
                      <th className="px-4 py-2.5 text-[11px] font-semibold uppercase tracking-wide text-gray-400">
                        {detailTab === 'applied' ? '绑定信息' : '匹配信息'}
                      </th>
                      {detailTab !== 'applied' && (
                        <th className="px-4 py-2.5 text-[11px] font-semibold uppercase tracking-wide text-gray-400">分数</th>
                      )}
                      <th className="px-4 py-2.5 text-[11px] font-semibold uppercase tracking-wide text-gray-400">来源</th>
                      <th className="px-4 py-2.5 text-[11px] font-semibold uppercase tracking-wide text-gray-400">操作</th>
                    </tr>
                  </thead>
                  <tbody>
                    {pagedCandidates.length === 0 ? (
                      <tr>
                        <td
                          colSpan={detailTab === 'applied' ? 5 : 7}
                          className="px-4 py-16 text-center text-sm text-gray-400"
                        >
                          {detailTab === 'exact'   && '暂无 Exact 候选'}
                          {detailTab === 'fuzzy'   && '暂无 Fuzzy 候选'}
                          {detailTab === 'applied' && '暂无已应用绑定'}
                        </td>
                      </tr>
                    ) : (
                      pagedCandidates.map((candidate) => {
                        const isSelected = selectedCandidateIds.includes(candidate.id);
                        const canSelect  = candidate.status === 'pending';
                        return (
                          <tr
                            key={candidate.id}
                            className={`border-b border-gray-50 align-top transition-colors hover:bg-gray-50/60 ${isSelected ? 'bg-emerald-50/40' : ''}`}
                          >
                            {/* Checkbox */}
                            {detailTab !== 'applied' && (
                              <td className="px-4 py-3.5">
                                <input
                                  type="checkbox"
                                  checked={isSelected}
                                  disabled={!canSelect}
                                  onChange={(e) => toggleCandidate(candidate.id, e.target.checked)}
                                  className="h-3.5 w-3.5 rounded border-gray-300 disabled:opacity-40"
                                />
                              </td>
                            )}

                            {/* 候选名称 / 已绑定名称 */}
                            <td className="px-4 py-3.5">
                              <div className="break-words text-xs font-semibold text-gray-800">{candidate.rawName}</div>
                              {detailTab !== 'applied' && (
                                <div className="mt-1.5 flex flex-wrap gap-1">
                                  <TierBadge tier={candidate.matchTier} />
                                  <CandidateStatusBadge status={candidate.status} />
                                </div>
                              )}
                            </td>

                            {/* 事件信息 */}
                            <td className="px-4 py-3.5">
                              <div className="break-words text-xs font-semibold leading-snug text-gray-900">
                                {candidate.eventNameSnapshot}
                              </div>
                              <div className="mt-1 space-y-0.5 text-[11px] text-gray-400">
                                <div>时间 {formatTime(candidate.startAtSnapshot)}</div>
                                <div>来源 {candidate.sourceType}</div>
                                {candidate.stageNameSnapshot && (
                                  <div>舞台 {candidate.stageNameSnapshot}</div>
                                )}
                              </div>
                            </td>

                            {/* 匹配信息 / 绑定信息 */}
                            <td className="px-4 py-3.5">
                              {detailTab === 'applied' ? (
                                <div className="space-y-0.5 break-all font-mono text-[11px] text-gray-500">
                                  <div>DJ {candidate.rawName}</div>
                                  {candidate.eventArtistMemberId && (
                                    <div>memberId {candidate.eventArtistMemberId}</div>
                                  )}
                                  {candidate.eventArtistId && (
                                    <div>artistId {candidate.eventArtistId}</div>
                                  )}
                                </div>
                              ) : (
                                <div className="space-y-0.5 break-all font-mono text-[11px] text-gray-500">
                                  <div className="text-gray-700 font-sans font-medium">{candidate.matchReason}</div>
                                  <div>eventId {candidate.eventId}</div>
                                  {candidate.eventArtistId && <div>artist {candidate.eventArtistId}</div>}
                                  {candidate.eventArtistMemberId && <div>member {candidate.eventArtistMemberId}</div>}
                                  {candidate.eventPerformanceId && <div>slot {candidate.eventPerformanceId}</div>}
                                </div>
                              )}
                            </td>

                            {/* 分数 */}
                            {detailTab !== 'applied' && (
                              <td className="px-4 py-3.5">
                                <span className="text-xs font-bold text-gray-800">{candidate.matchScore}</span>
                              </td>
                            )}

                            {/* 来源 */}
                            <td className="px-4 py-3.5">
                              <div className="text-xs text-gray-700">{candidate.sourceType}</div>
                              <div className="mt-0.5 text-[10px] text-gray-400">
                                {formatTime(candidate.startAtSnapshot)?.slice(0, 16)}
                              </div>
                            </td>

                            {/* 操作 */}
                            <td className="px-4 py-3.5">
                              <div className="flex flex-wrap items-center gap-2">
                                {/* View icon */}
                                <button
                                  type="button"
                                  className="text-gray-400 transition hover:text-gray-700"
                                  title="查看详情"
                                >
                                  <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
                                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                                    <circle cx={12} cy={12} r={3} />
                                  </svg>
                                </button>
                                {/* Open external icon */}
                                {detailTab !== 'applied' && (
                                  <button
                                    type="button"
                                    className="text-gray-400 transition hover:text-gray-700"
                                    title="在新页面打开"
                                  >
                                    <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
                                      <path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6" />
                                      <polyline points="15 3 21 3 21 9" /><line x1={10} y1={14} x2={21} y2={3} />
                                    </svg>
                                  </button>
                                )}
                                {/* Single apply / dismiss – only for pending */}
                                {canSelect && detailTab !== 'applied' && (
                                  <>
                                    <button
                                      type="button"
                                      disabled={actionLoading}
                                      onClick={() =>
                                        void handleAction(
                                          () => djEventBindingReviewApi.applyCandidates(token ?? '', selectedJob.id, [candidate.id]),
                                          '已导入该候选绑定',
                                        )
                                      }
                                      className="rounded-md bg-gray-900 px-2.5 py-1 text-[11px] font-semibold text-white transition hover:bg-gray-800 disabled:opacity-40"
                                    >
                                      导入
                                    </button>
                                    <button
                                      type="button"
                                      disabled={actionLoading}
                                      onClick={() =>
                                        void handleAction(
                                          () => djEventBindingReviewApi.dismissCandidates(token ?? '', selectedJob.id, { candidateIds: [candidate.id] }),
                                          '已忽略该候选',
                                        )
                                      }
                                      className="rounded-md border border-red-200 bg-red-50 px-2.5 py-1 text-[11px] font-semibold text-red-600 transition hover:bg-red-100 disabled:opacity-40"
                                    >
                                      忽略
                                    </button>
                                  </>
                                )}
                              </div>
                            </td>
                          </tr>
                        );
                      })
                    )}
                  </tbody>
                </table>
              </div>

              {/* Candidate pagination */}
              {candidateTotal > 0 && (
                <Pagination
                  page={candidatePage}
                  totalPages={candidateTotalPages}
                  total={candidateTotal}
                  pageSize={candidatePageSize}
                  onPageChange={setCandidatePage}
                  onPageSizeChange={(s) => { setCandidatePageSize(s); setCandidatePage(1); }}
                />
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );

  // ─── Auth / permission guards ─────────────────────────────────────────────

  if (isLoading) {
    const msg = <div className="py-12 text-center text-sm text-gray-400">加载中…</div>;
    return embedded ? (
      <AdminContentLayout title="DJ 绑定审核" eyebrow="Admin / Content Workspace / Reviews" description="加载中...">{msg}</AdminContentLayout>
    ) : (
      <AdminAppShell title="DJ 绑定审核" description="加载中...">{msg}</AdminAppShell>
    );
  }

  if (!user || !canOperate) {
    const msg = (
      <div className="rounded-xl border border-gray-200 bg-white p-6 text-sm text-gray-500">
        当前账号无权限访问该页面。
      </div>
    );
    return embedded ? (
      <AdminContentLayout
        title="DJ 绑定审核"
        eyebrow="Admin / Content Workspace / Reviews"
        description="当前账号无权限访问该页面。"
        actions={
          <Link href={user ? '/admin/content' : '/login'} className="rounded-lg bg-gray-900 px-4 py-2 text-sm font-semibold text-white">
            {user ? '返回内容后台' : '去登录'}
          </Link>
        }
      >
        {msg}
      </AdminContentLayout>
    ) : (
      <AdminAppShell title="DJ 绑定审核" description="当前账号暂时没有 DJ 绑定审核权限。">
        <section className="mx-auto max-w-4xl space-y-4">
          {msg}
          <Link href={user ? '/admin' : '/login'} className="inline-flex rounded-lg bg-gray-900 px-4 py-2 text-sm font-semibold text-white">
            {user ? '返回后台' : '去登录'}
          </Link>
        </section>
      </AdminAppShell>
    );
  }

  // ─── Embedded mode ─────────────────────────────────────────────────────────

  if (embedded) {
    return (
      <AdminContentLayout
        title="DJ 绑定审核"
        eyebrow="Admin / Content Workspace / Reviews"
        description="原生承接 DJ 与 Event 阵容 / member / timetable slot 的自动命中审核，不再通过旧工具说明页做跳转。"
        actions={
          <>
            <Link href="/admin/content/reviews" className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-50 transition-colors">
              返回审核中心
            </Link>
            <button
              type="button"
              onClick={() => void refreshAll()}
              disabled={listLoading || detailLoading || actionLoading}
              className="rounded-lg bg-gray-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-60 transition-colors hover:bg-gray-800"
            >
              {listLoading || detailLoading ? '刷新中…' : '刷新'}
            </button>
          </>
        }
      >
        {content}
      </AdminContentLayout>
    );
  }

  // ─── Standalone mode ────────────────────────────────────────────────────────

  return (
    <AdminAppShell
      title="DJ 绑定审核"
      eyebrow="Raver Admin / Content Ops"
      description="管理 DJ 与 Event 阵容、member 和 timetable slot 的自动命中结果，优先处理 exact 命中与批量 apply。"
      hidePageHeader
    >
      <section className="space-y-4">
        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <p className="text-sm text-gray-500">Content Ops</p>
            <h1 className="mt-1 text-3xl font-bold text-gray-900">DJ 绑定审核</h1>
            <p className="mt-1.5 text-sm leading-relaxed text-gray-500">
              管理 DJ 与 Event 阵容 / member / timetable slot 的自动命中结果。可先看 exact 命中，再一键 apply。
            </p>
          </div>
          <div className="flex flex-shrink-0 flex-wrap gap-2">
            <button
              type="button"
              onClick={() => void refreshAll()}
              disabled={listLoading || detailLoading || actionLoading}
              className="flex items-center gap-2 rounded-lg bg-gray-900 px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-60 transition hover:bg-gray-800"
            >
              <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
                <path d="M23 4v6h-6M1 20v-6h6" strokeLinecap="round" strokeLinejoin="round" />
                <path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              {listLoading || detailLoading ? '刷新中…' : '刷新'}
            </button>
            <Link
              href="/admin"
              className="rounded-lg border border-gray-200 bg-white px-4 py-2.5 text-sm font-semibold text-gray-700 transition hover:bg-gray-50"
            >
              返回后台
            </Link>
          </div>
        </div>
        {content}
      </section>
    </AdminAppShell>
  );
}
