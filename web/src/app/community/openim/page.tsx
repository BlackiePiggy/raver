'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import {
  openIMAdminApi,
  OpenIMAdminOverview,
  OpenIMAuditLog,
  OpenIMImageModerationJob,
  OpenIMMessageReport,
  OpenIMSyncJob,
  OpenIMWebhookEvent,
} from '@/lib/api/openim-admin';

const formatTime = (value?: string | null): string => {
  if (!value) {
    return '-';
  }
  return new Date(value).toLocaleString('zh-CN', { hour12: false });
};

const shortText = (value: string | null | undefined, max = 80): string => {
  if (!value) {
    return '-';
  }
  return value.length > max ? `${value.slice(0, max)}...` : value;
};

const statusClassName = (status: string): string => {
  const normalized = status.toLowerCase();
  if (['resolved', 'approved', 'succeeded'].includes(normalized)) {
    return 'text-green-400';
  }
  if (['rejected', 'failed'].includes(normalized)) {
    return 'text-red-400';
  }
  if (['pending', 'processing', 'retrying'].includes(normalized)) {
    return 'text-yellow-400';
  }
  return 'text-text-secondary';
};

export default function OpenIMAdminPage() {
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [actionId, setActionId] = useState<string | null>(null);

  const [overview, setOverview] = useState<OpenIMAdminOverview | null>(null);
  const [reports, setReports] = useState<OpenIMMessageReport[]>([]);
  const [imageJobs, setImageJobs] = useState<OpenIMImageModerationJob[]>([]);
  const [webhooks, setWebhooks] = useState<OpenIMWebhookEvent[]>([]);
  const [syncJobs, setSyncJobs] = useState<OpenIMSyncJob[]>([]);
  const [auditLogs, setAuditLogs] = useState<OpenIMAuditLog[]>([]);

  const loadData = useCallback(async () => {
    if (!isAdmin) {
      setLoading(false);
      return;
    }
    try {
      setLoading(true);
      setError('');
      const [overviewData, reportData, imageData, webhookData, syncData, auditData] = await Promise.all([
        openIMAdminApi.getOverview(),
        openIMAdminApi.getReports('pending', 10),
        openIMAdminApi.getImageModerationJobs('pending', 10),
        openIMAdminApi.getWebhooks(8),
        openIMAdminApi.getSyncJobs(8),
        openIMAdminApi.getAuditLogs(8),
      ]);

      setOverview(overviewData);
      setReports(reportData.items);
      setImageJobs(imageData.items);
      setWebhooks(webhookData.items);
      setSyncJobs(syncData.items);
      setAuditLogs(auditData.items);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : '加载 OpenIM 管理数据失败');
    } finally {
      setLoading(false);
    }
  }, [isAdmin]);

  useEffect(() => {
    void loadData();
  }, [loadData]);

  const handleResolveReport = async (reportId: string, status: 'resolved' | 'rejected') => {
    try {
      setActionId(reportId);
      await openIMAdminApi.resolveReport(reportId, status, `web-openim-admin:${status}`);
      await loadData();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : '处理举报失败');
    } finally {
      setActionId(null);
    }
  };

  const handleReviewImage = async (jobId: string, status: 'approved' | 'rejected') => {
    try {
      setActionId(jobId);
      await openIMAdminApi.reviewImageModerationJob(jobId, status, `web-openim-admin:${status}`);
      await loadData();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : '处理图片审核失败');
    } finally {
      setActionId(null);
    }
  };

  const metricCards = useMemo(() => {
    if (!overview) {
      return [];
    }
    return [
      { label: '待处理举报', value: overview.pendingReports },
      { label: '待审图片', value: overview.pendingImageModerationJobs },
      { label: '待执行同步任务', value: overview.pendingSyncJobs },
      { label: '24h 无效签名', value: overview.invalidWebhooks24h },
      { label: '24h 被拒图片', value: overview.rejectedImageModeration24h },
      { label: '24h webhook', value: overview.webhooks24h },
    ];
  }, [overview]);

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px]">
        <div className="max-w-[1200px] mx-auto px-6 py-8 space-y-6">
          <div className="flex items-center justify-between gap-4">
            <div>
              <h1 className="text-3xl font-bold text-text-primary">OpenIM 管理台</h1>
              <p className="text-sm text-text-secondary mt-2">举报、图片审核、Webhook 与同步任务总览</p>
            </div>
            <button
              onClick={() => void loadData()}
              className="px-4 py-2 text-sm rounded-lg border border-bg-tertiary bg-bg-secondary text-text-primary hover:border-primary-purple transition-colors"
            >
              刷新
            </button>
          </div>

          {!user && (
            <div className="rounded-lg border border-red-500/30 bg-red-500/10 p-4 text-sm text-red-300">
              请先登录管理员账号后访问。
            </div>
          )}

          {user && !isAdmin && (
            <div className="rounded-lg border border-red-500/30 bg-red-500/10 p-4 text-sm text-red-300">
              当前账号不是管理员，无法访问 OpenIM 管理模块。
            </div>
          )}

          {error && (
            <div className="rounded-lg border border-red-500/30 bg-red-500/10 p-4 text-sm text-red-300">
              {error}
            </div>
          )}

          {isAdmin && (
            <>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                {metricCards.map((card) => (
                  <div key={card.label} className="rounded-lg border border-bg-tertiary bg-bg-secondary p-4">
                    <div className="text-xs text-text-secondary">{card.label}</div>
                    <div className="mt-2 text-2xl font-semibold text-text-primary">{card.value}</div>
                  </div>
                ))}
              </div>

              <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
                <section className="rounded-lg border border-bg-tertiary bg-bg-secondary p-4">
                  <h2 className="text-lg font-semibold text-text-primary mb-3">待处理举报</h2>
                  <div className="space-y-3">
                    {reports.length === 0 && !loading && <div className="text-sm text-text-secondary">暂无待处理举报</div>}
                    {reports.map((report) => (
                      <div key={report.id} className="rounded-lg border border-bg-tertiary p-3">
                        <div className="text-xs text-text-secondary">messageID: {report.messageID}</div>
                        <div className="text-sm text-text-primary mt-1">{report.reason}</div>
                        <div className="text-xs text-text-secondary mt-1">{shortText(report.detail, 120)}</div>
                        <div className="mt-3 flex items-center gap-2">
                          <button
                            disabled={actionId === report.id}
                            onClick={() => void handleResolveReport(report.id, 'resolved')}
                            className="px-2.5 py-1.5 text-xs rounded-md bg-green-600/20 text-green-300 border border-green-500/30 hover:bg-green-600/30 disabled:opacity-50"
                          >
                            通过
                          </button>
                          <button
                            disabled={actionId === report.id}
                            onClick={() => void handleResolveReport(report.id, 'rejected')}
                            className="px-2.5 py-1.5 text-xs rounded-md bg-red-600/20 text-red-300 border border-red-500/30 hover:bg-red-600/30 disabled:opacity-50"
                          >
                            驳回
                          </button>
                          <span className="text-[11px] text-text-secondary ml-auto">{formatTime(report.createdAt)}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </section>

                <section className="rounded-lg border border-bg-tertiary bg-bg-secondary p-4">
                  <h2 className="text-lg font-semibold text-text-primary mb-3">待审图片任务</h2>
                  <div className="space-y-3">
                    {imageJobs.length === 0 && !loading && <div className="text-sm text-text-secondary">暂无待审图片任务</div>}
                    {imageJobs.map((job) => (
                      <div key={job.id} className="rounded-lg border border-bg-tertiary p-3">
                        <div className="text-xs text-text-secondary">messageID: {job.messageID || '-'}</div>
                        <div className="text-xs text-text-secondary mt-1 break-all">{job.imageURL}</div>
                        <div className={`text-xs mt-2 ${statusClassName(job.status)}`}>{job.status}</div>
                        <div className="mt-3 flex items-center gap-2">
                          <button
                            disabled={actionId === job.id}
                            onClick={() => void handleReviewImage(job.id, 'approved')}
                            className="px-2.5 py-1.5 text-xs rounded-md bg-green-600/20 text-green-300 border border-green-500/30 hover:bg-green-600/30 disabled:opacity-50"
                          >
                            通过
                          </button>
                          <button
                            disabled={actionId === job.id}
                            onClick={() => void handleReviewImage(job.id, 'rejected')}
                            className="px-2.5 py-1.5 text-xs rounded-md bg-red-600/20 text-red-300 border border-red-500/30 hover:bg-red-600/30 disabled:opacity-50"
                          >
                            拒绝
                          </button>
                          <span className="text-[11px] text-text-secondary ml-auto">{formatTime(job.createdAt)}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </section>
              </div>

              <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
                <section className="rounded-lg border border-bg-tertiary bg-bg-secondary p-4">
                  <h3 className="text-base font-semibold text-text-primary mb-3">最近 Webhook</h3>
                  <div className="space-y-2">
                    {webhooks.length === 0 && !loading && <div className="text-sm text-text-secondary">暂无数据</div>}
                    {webhooks.map((event) => (
                      <div key={event.id} className="text-xs border border-bg-tertiary rounded-md p-2">
                        <div className="text-text-primary">{event.callbackCommand || '-'}</div>
                        <div className={event.signatureValid ? 'text-green-400' : 'text-red-400'}>
                          signature: {event.signatureValid ? 'valid' : 'invalid'}
                        </div>
                        <div className="text-text-secondary">{shortText(event.verifyReason, 90)}</div>
                      </div>
                    ))}
                  </div>
                </section>

                <section className="rounded-lg border border-bg-tertiary bg-bg-secondary p-4">
                  <h3 className="text-base font-semibold text-text-primary mb-3">最近同步任务</h3>
                  <div className="space-y-2">
                    {syncJobs.length === 0 && !loading && <div className="text-sm text-text-secondary">暂无数据</div>}
                    {syncJobs.map((job) => (
                      <div key={job.id} className="text-xs border border-bg-tertiary rounded-md p-2">
                        <div className="text-text-primary">{job.jobType} / {job.entityType}</div>
                        <div className={statusClassName(job.status)}>{job.status}</div>
                        <div className="text-text-secondary">attempts: {job.attempts}/{job.maxAttempts}</div>
                      </div>
                    ))}
                  </div>
                </section>

                <section className="rounded-lg border border-bg-tertiary bg-bg-secondary p-4">
                  <h3 className="text-base font-semibold text-text-primary mb-3">最近审计日志</h3>
                  <div className="space-y-2">
                    {auditLogs.length === 0 && !loading && <div className="text-sm text-text-secondary">暂无数据</div>}
                    {auditLogs.map((log) => (
                      <div key={log.id} className="text-xs border border-bg-tertiary rounded-md p-2">
                        <div className="text-text-primary">{log.action}</div>
                        <div className="text-text-secondary">actor: {log.actorID}</div>
                        <div className="text-text-secondary">{formatTime(log.createdAt)}</div>
                      </div>
                    ))}
                  </div>
                </section>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
