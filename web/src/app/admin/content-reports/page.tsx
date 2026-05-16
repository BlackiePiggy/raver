'use client';

import Link from 'next/link';
import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import { AdminContentReport, ContentReportSummary, ModerationDecisionTemplate, contentReportsApi } from '@/lib/api/content-reports';
import { formatDateTimeWithSystemTimeZoneLabel } from '@/lib/timezone';

const STATUS_OPTIONS = ['', 'pending', 'reviewing', 'resolved', 'rejected', 'closed'];
const PRIORITY_OPTIONS = ['', 'high', 'medium', 'normal'];
const ACTIONS = [
  { value: 'resolve', label: '标记已处理' },
  { value: 'dismiss', label: '驳回举报' },
  { value: 'hide_content', label: '下架内容' },
  { value: 'restore_content', label: '恢复内容' },
  { value: 'warn_user', label: '警告用户' },
  { value: 'restrict_user', label: '限制用户 14 天' },
  { value: 'suspend_user', label: '临时封禁 7 天' },
  { value: 'ban_user', label: '永久封禁' },
  { value: 'escalate', label: '升级审核' },
];

const formatTime = (value?: string | null): string => {
  if (!value) return '-';
  return formatDateTimeWithSystemTimeZoneLabel(value);
};

const priorityClass = (priority?: string): string => {
  if (priority === 'high') return 'border-red-500/40 bg-red-500/10 text-red-300';
  if (priority === 'medium') return 'border-yellow-500/40 bg-yellow-500/10 text-yellow-300';
  return 'border-border-secondary bg-bg-tertiary text-text-secondary';
};

const statusClass = (status: string): string => {
  if (status === 'pending') return 'border-red-500/40 bg-red-500/10 text-red-300';
  if (status === 'reviewing') return 'border-yellow-500/40 bg-yellow-500/10 text-yellow-300';
  if (status === 'resolved') return 'border-accent-green/40 bg-accent-green/10 text-accent-green';
  if (status === 'rejected') return 'border-blue-400/40 bg-blue-400/10 text-blue-300';
  return 'border-border-secondary bg-bg-tertiary text-text-secondary';
};

const shortJson = (value: unknown): string => {
  if (!value) return '暂无预览';
  try {
    return JSON.stringify(value, null, 2).slice(0, 1800);
  } catch {
    return String(value).slice(0, 1800);
  }
};

const recordValue = (value: unknown): Record<string, unknown> => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
};

const copyrightWorkflow = (report: AdminContentReport | null): Record<string, unknown> => {
  return recordValue(recordValue(report?.metadata).copyright);
};

function UserLine({ user, fallback }: { user?: AdminContentReport['reporter']; fallback: string }) {
  if (!user) return <span className="font-mono text-xs text-text-secondary">{fallback}</span>;
  return (
    <span>
      {user.displayName || user.username}
      <span className="ml-2 font-mono text-xs text-text-secondary">{user.id}</span>
    </span>
  );
}

export default function ContentReportsAdminPage() {
  const { user, token, isLoading } = useAuth();
  const canOperate = user?.role === 'admin' || user?.role === 'operator';
  const [items, setItems] = useState<AdminContentReport[]>([]);
  const [selected, setSelected] = useState<AdminContentReport | null>(null);
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [summary, setSummary] = useState<ContentReportSummary | null>(null);
  const [templates, setTemplates] = useState<ModerationDecisionTemplate[]>([]);
  const [templateKey, setTemplateKey] = useState('report_resolved');
  const [templateLocale, setTemplateLocale] = useState('ja-JP');
  const [templateTitle, setTemplateTitle] = useState('');
  const [templateBody, setTemplateBody] = useState('');
  const [templatePreview, setTemplatePreview] = useState<{ title: string; body: string } | null>(null);
  const [status, setStatus] = useState('pending');
  const [targetType, setTargetType] = useState('');
  const [reason, setReason] = useState('');
  const [priority, setPriority] = useState('');
  const [action, setAction] = useState('resolve');
  const [batchAction, setBatchAction] = useState<'resolve' | 'dismiss'>('resolve');
  const [note, setNote] = useState('');
  const [batchNote, setBatchNote] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const targetTypes = useMemo(
    () => Array.from(new Set(items.map((item) => item.targetType))).sort(),
    [items]
  );
  const reasons = useMemo(
    () => Array.from(new Set(items.map((item) => item.reason))).sort(),
    [items]
  );
  const selectedCopyrightWorkflow = copyrightWorkflow(selected);

  const loadReports = useCallback(async () => {
    if (!token || !canOperate) return;
    try {
      setLoading(true);
      setError(null);
      const [result, summaryResult] = await Promise.all([
        contentReportsApi.list(token, {
        status: status || undefined,
        targetType: targetType || undefined,
        reason: reason || undefined,
        priority: priority || undefined,
        limit: 100,
        }),
        contentReportsApi.summary(token),
      ]);
      setItems(result.items);
      setSummary(summaryResult.summary);
      setSelectedIds((ids) => ids.filter((id) => result.items.some((item) => item.id === id)));
      if (result.items.length > 0) {
        setSelected((currentSelected) => {
          const current = currentSelected ? result.items.find((item) => item.id === currentSelected.id) : null;
          return current || result.items[0];
        });
      } else {
        setSelected(null);
      }
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载举报队列失败');
    } finally {
      setLoading(false);
    }
  }, [canOperate, priority, reason, status, targetType, token]);

  const loadTemplates = useCallback(async () => {
    if (!token || !canOperate) return;
    const result = await contentReportsApi.listTemplates(token, { templateKey, locale: templateLocale });
    setTemplates(result.items);
    const current = result.items[0];
    setTemplateTitle(current?.title || '');
    setTemplateBody(current?.body || '');
    setTemplatePreview(null);
  }, [canOperate, templateKey, templateLocale, token]);

  useEffect(() => {
    void loadReports();
  }, [loadReports]);

  useEffect(() => {
    void loadTemplates();
  }, [loadTemplates]);

  const loadDetail = async (report: AdminContentReport) => {
    if (!token) return;
    try {
      setError(null);
      const result = await contentReportsApi.get(token, report.id);
      setSelected(result.report);
    } catch (detailError) {
      setError(detailError instanceof Error ? detailError.message : '加载举报详情失败');
    }
  };

  const submitDecision = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!token || !selected) return;
    try {
      setError(null);
      setNotice(null);
      const durationDays = action === 'restrict_user' ? 14 : action === 'suspend_user' ? 7 : undefined;
      await contentReportsApi.decide(token, selected.id, {
        action,
        note: note.trim() || undefined,
        durationDays,
      });
      setNotice('处理动作已提交');
      setNote('');
      await loadReports();
    } catch (decisionError) {
      setError(decisionError instanceof Error ? decisionError.message : '处理举报失败');
    }
  };

  const toggleSelectedId = (reportId: string) => {
    setSelectedIds((ids) => (ids.includes(reportId) ? ids.filter((id) => id !== reportId) : [...ids, reportId]));
  };

  const submitBatchDecision = async () => {
    if (!token || selectedIds.length === 0) return;
    try {
      setError(null);
      setNotice(null);
      const result = await contentReportsApi.batchDecide(token, {
        reportIds: selectedIds,
        action: batchAction,
        note: batchNote.trim() || undefined,
      });
      setNotice(`已批量处理 ${result.updatedCount} 条举报`);
      setSelectedIds([]);
      setBatchNote('');
      await loadReports();
    } catch (batchError) {
      setError(batchError instanceof Error ? batchError.message : '批量处理失败');
    }
  };

  const previewTemplate = async () => {
    if (!token) return;
    const result = await contentReportsApi.previewTemplate(token, {
      title: templateTitle,
      body: templateBody,
      variables: { reportId: selected?.id || 'report-id', targetType: selected?.targetType || 'post', reason: selected?.reason || 'spam' },
    });
    setTemplatePreview(result.preview);
  };

  const saveTemplateDraft = async () => {
    if (!token) return;
    const result = await contentReportsApi.createTemplate(token, {
      templateKey,
      locale: templateLocale,
      title: templateTitle,
      body: templateBody,
    });
    setNotice(`模板草稿已保存 v${result.item.version}`);
    await loadTemplates();
  };

  const publishTemplate = async (templateId: string) => {
    if (!token) return;
    const result = await contentReportsApi.publishTemplate(token, templateId);
    setNotice(`模板已发布 v${result.item.version}`);
    await loadTemplates();
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
            <h1 className="text-2xl font-semibold">举报审核后台</h1>
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
            <p className="text-sm text-text-secondary">Trust & Safety</p>
            <h1 className="mt-1 text-3xl font-semibold">举报审核队列</h1>
          </div>
          <button
            type="button"
            onClick={() => void loadReports()}
            disabled={loading}
            className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
          >
            {loading ? '刷新中...' : '刷新'}
          </button>
        </div>

        {error && <div className="rounded-lg border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300">{error}</div>}
        {notice && <div className="rounded-lg border border-accent-green/40 bg-accent-green/10 px-4 py-3 text-sm text-accent-green">{notice}</div>}

        {summary && (
          <section className="grid gap-3 md:grid-cols-4">
            <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
              <div className="text-sm text-text-secondary">待处理</div>
              <div className="mt-2 text-2xl font-semibold">{summary.pendingCount}</div>
            </div>
            <div className="rounded-lg border border-red-500/30 bg-red-500/10 p-4">
              <div className="text-sm text-red-200">SLA 超时</div>
              <div className="mt-2 text-2xl font-semibold text-red-200">{summary.overdueCount}</div>
            </div>
            <div className="rounded-lg border border-yellow-500/30 bg-yellow-500/10 p-4">
              <div className="text-sm text-yellow-200">高优先级待处理</div>
              <div className="mt-2 text-2xl font-semibold text-yellow-200">{summary.highPriorityPendingCount}</div>
            </div>
            <div className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
              <div className="text-sm text-text-secondary">最早待处理</div>
              <div className="mt-2 text-sm font-semibold">{formatTime(summary.oldestPendingAt)}</div>
            </div>
          </section>
        )}

        <section className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
          <div className="grid gap-3 md:grid-cols-5">
            <label className="text-sm">
              <span className="text-text-secondary">状态</span>
              <select value={status} onChange={(event) => setStatus(event.target.value)} className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2">
                {STATUS_OPTIONS.map((item) => <option key={item || 'all'} value={item}>{item || '全部'}</option>)}
              </select>
            </label>
            <label className="text-sm">
              <span className="text-text-secondary">优先级</span>
              <select value={priority} onChange={(event) => setPriority(event.target.value)} className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2">
                {PRIORITY_OPTIONS.map((item) => <option key={item || 'all'} value={item}>{item || '全部'}</option>)}
              </select>
            </label>
            <label className="text-sm">
              <span className="text-text-secondary">对象类型</span>
              <input value={targetType} onChange={(event) => setTargetType(event.target.value)} list="report-target-types" className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2" />
              <datalist id="report-target-types">{targetTypes.map((item) => <option key={item} value={item} />)}</datalist>
            </label>
            <label className="text-sm">
              <span className="text-text-secondary">原因</span>
              <input value={reason} onChange={(event) => setReason(event.target.value)} list="report-reasons" className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2" />
              <datalist id="report-reasons">{reasons.map((item) => <option key={item} value={item} />)}</datalist>
            </label>
            <div className="flex items-end">
              <button type="button" onClick={() => void loadReports()} className="w-full rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
                应用筛选
              </button>
            </div>
          </div>
        </section>

        <section className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
          <div className="grid gap-4 lg:grid-cols-[260px_1fr_1fr]">
            <div className="space-y-3">
              <div>
                <div className="font-semibold">三语处理模板</div>
                <p className="mt-1 text-xs text-text-secondary">支持草稿、预览、发布和回滚到历史版本。</p>
              </div>
              <select value={templateKey} onChange={(event) => setTemplateKey(event.target.value)} className="w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm">
                {['report_resolved', 'report_dismissed', 'content_hidden', 'content_restored', 'user_warned', 'user_restricted', 'user_suspended', 'user_banned', 'report_escalated'].map((item) => <option key={item} value={item}>{item}</option>)}
              </select>
              <select value={templateLocale} onChange={(event) => setTemplateLocale(event.target.value)} className="w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm">
                {['ja-JP', 'zh-CN', 'en'].map((item) => <option key={item} value={item}>{item}</option>)}
              </select>
            </div>
            <div className="space-y-3">
              <input value={templateTitle} onChange={(event) => setTemplateTitle(event.target.value)} placeholder="模板标题" className="w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm" />
              <textarea value={templateBody} onChange={(event) => setTemplateBody(event.target.value)} rows={4} placeholder="模板正文，可使用 {{reportId}} {{targetType}} {{reason}}" className="w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm" />
              <div className="flex flex-wrap gap-2">
                <button type="button" onClick={() => void previewTemplate()} className="rounded-lg border border-border-secondary px-3 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">预览</button>
                <button type="button" onClick={() => void saveTemplateDraft()} className="rounded-lg bg-primary-blue px-3 py-2 text-sm font-semibold text-white">保存草稿</button>
              </div>
            </div>
            <div className="space-y-3 text-sm">
              {templatePreview && (
                <div className="rounded-md border border-border-secondary bg-bg-tertiary p-3">
                  <div className="font-semibold">{templatePreview.title}</div>
                  <p className="mt-2 whitespace-pre-wrap text-text-secondary">{templatePreview.body}</p>
                </div>
              )}
              <div className="max-h-44 space-y-2 overflow-auto">
                {templates.map((item) => (
                  <div key={item.id} className="flex items-center justify-between gap-3 rounded-md border border-border-secondary bg-bg-tertiary p-2">
                    <span>v{item.version} · {item.status}</span>
                    <div className="flex gap-2">
                      {item.status !== 'published' && !item.id.startsWith('default:') && (
                        <button type="button" onClick={() => void publishTemplate(item.id)} className="text-primary-blue">发布</button>
                      )}
                      {item.status === 'archived' && (
                        <button type="button" onClick={() => void contentReportsApi.rollbackTemplate(token!, item.id).then(loadTemplates)} className="text-primary-blue">回滚</button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </section>

        <section className="grid gap-5 lg:grid-cols-[430px_1fr]">
          <div className="space-y-3">
            {items.length > 0 && (
              <section className="rounded-lg border border-border-secondary bg-bg-secondary p-4">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <div className="font-semibold">批量低风险处理</div>
                    <div className="mt-1 text-xs text-text-secondary">仅后端允许同对象类型、同原因、未结案 normal 优先级举报。</div>
                  </div>
                  <span className="text-sm text-text-secondary">已选 {selectedIds.length}</span>
                </div>
                <div className="mt-3 grid gap-2 sm:grid-cols-[1fr_auto]">
                  <select value={batchAction} onChange={(event) => setBatchAction(event.target.value as 'resolve' | 'dismiss')} className="rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm">
                    <option value="resolve">标记已处理</option>
                    <option value="dismiss">驳回举报</option>
                  </select>
                  <button
                    type="button"
                    onClick={() => void submitBatchDecision()}
                    disabled={selectedIds.length === 0}
                    className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue disabled:opacity-50"
                  >
                    批量提交
                  </button>
                </div>
                <textarea
                  value={batchNote}
                  onChange={(event) => setBatchNote(event.target.value)}
                  rows={2}
                  placeholder="批量处理备注"
                  className="mt-3 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
                />
              </section>
            )}
            {items.length === 0 && !loading && (
              <div className="rounded-lg border border-border-secondary bg-bg-secondary p-5 text-sm text-text-secondary">暂无符合条件的举报。</div>
            )}
            {items.map((item) => (
              <div
                key={item.id}
                className={`w-full rounded-lg border p-4 text-left hover:border-primary-blue ${selected?.id === item.id ? 'border-primary-blue bg-bg-tertiary' : 'border-border-secondary bg-bg-secondary'}`}
              >
                <div className="flex items-start gap-3">
                  <input
                    type="checkbox"
                    checked={selectedIds.includes(item.id)}
                    onChange={() => toggleSelectedId(item.id)}
                    className="mt-1 h-4 w-4 accent-primary-blue"
                    aria-label={`选择举报 ${item.id}`}
                  />
                  <button type="button" onClick={() => void loadDetail(item)} className="min-w-0 flex-1 text-left">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className={`rounded-md border px-2 py-1 text-xs font-semibold ${priorityClass(item.priority)}`}>{item.priority || 'normal'}</span>
                      <span className={`rounded-md border px-2 py-1 text-xs font-semibold ${statusClass(item.status)}`}>{item.status}</span>
                      {item.isOverdue && <span className="rounded-md border border-red-500/40 px-2 py-1 text-xs text-red-300">SLA 超时</span>}
                    </div>
                    <div className="mt-3 font-semibold">{item.reason}</div>
                    <div className="mt-1 break-all text-sm text-text-secondary">{item.targetType} · {item.targetId}</div>
                    <div className="mt-2 text-xs text-text-secondary">举报量 {item.reportCountForTarget || 1} · {formatTime(item.createdAt)}</div>
                  </button>
                </div>
              </div>
            ))}
          </div>

          {selected ? (
            <div className="space-y-5">
              <section className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <h2 className="text-xl font-semibold">举报详情</h2>
                    <p className="mt-1 font-mono text-xs text-text-secondary">{selected.id}</p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <span className={`rounded-md border px-2 py-1 text-xs font-semibold ${priorityClass(selected.priority)}`}>{selected.priority || 'normal'}</span>
                    <span className={`rounded-md border px-2 py-1 text-xs font-semibold ${statusClass(selected.status)}`}>{selected.status}</span>
                  </div>
                </div>
                <dl className="mt-5 grid gap-4 text-sm md:grid-cols-2">
                  <div><dt className="text-text-secondary">举报人</dt><dd className="mt-1"><UserLine user={selected.reporter} fallback={selected.reporterUserId} /></dd></div>
                  <div><dt className="text-text-secondary">目标用户</dt><dd className="mt-1"><UserLine user={selected.targetUser} fallback={selected.targetUserId || '-'} /></dd></div>
                  <div><dt className="text-text-secondary">对象</dt><dd className="mt-1 font-mono text-xs">{selected.targetType}:{selected.targetId}</dd></div>
                  <div><dt className="text-text-secondary">SLA</dt><dd className="mt-1">{formatTime(selected.slaDueAt)} {selected.isOverdue ? '· 已超时' : ''}</dd></div>
                </dl>
                <div className="mt-5">
                  <div className="text-sm text-text-secondary">补充说明</div>
                  <p className="mt-2 whitespace-pre-wrap rounded-md border border-border-secondary bg-bg-tertiary p-3 text-sm leading-6">{selected.detail || '无'}</p>
                </div>
                <div className="mt-5">
                  <div className="text-sm text-text-secondary">截图/附件</div>
                  <div className="mt-2 space-y-2 rounded-md border border-border-secondary bg-bg-tertiary p-3 text-sm">
                    {(selected.attachments || []).map((attachment, index) => (
                      <a key={`${attachment.url}-${index}`} href={attachment.url || '#'} target="_blank" rel="noreferrer" className="block break-all text-primary-blue">
                        {attachment.type || 'link'} · {attachment.label || attachment.url}
                      </a>
                    ))}
                    {(!selected.attachments || selected.attachments.length === 0) && <div className="text-text-secondary">无附件。</div>}
                  </div>
                </div>
              </section>

              <section className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
                <h2 className="text-xl font-semibold">对象预览</h2>
                <pre className="mt-4 max-h-[360px] overflow-auto rounded-md border border-border-secondary bg-bg-tertiary p-4 text-xs leading-5 text-text-secondary">
                  {shortJson(selected.targetPreview)}
                </pre>
              </section>

              <section className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
                <h2 className="text-xl font-semibold">上下文</h2>
                <pre className="mt-4 max-h-[260px] overflow-auto rounded-md border border-border-secondary bg-bg-tertiary p-4 text-xs leading-5 text-text-secondary">
                  {shortJson(selected.context)}
                </pre>
              </section>

              <section className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
                <h2 className="text-xl font-semibold">处理动作</h2>
                {selected.reason === 'copyright' && (
                  <div className="mt-4 rounded-md border border-yellow-500/30 bg-yellow-500/10 p-3 text-sm text-yellow-100">
                    <div className="font-semibold">版权投诉处理</div>
                    <div className="mt-2 leading-6 text-yellow-100/80">
                      投诉成立时先下架内容；反通知或复核通过后可恢复。目标用户累计已成立版权投诉 {selected.copyrightStats?.resolvedCopyrightCount ?? 0}/{selected.copyrightStats?.repeatInfringerThreshold ?? 3} 次。
                      {selected.copyrightStats?.repeatInfringer ? ' 已达到重复侵权复核阈值，可限制、临时封禁或永久封禁。' : ' 未达到重复侵权阈值。'}
                    </div>
                    {Object.keys(selectedCopyrightWorkflow).length > 0 && (
                      <dl className="mt-3 grid gap-2 text-xs sm:grid-cols-2">
                        <div><dt className="text-yellow-100/60">下架状态</dt><dd>{String(selectedCopyrightWorkflow.takedownStatus ?? '-')}</dd></div>
                        <div><dt className="text-yellow-100/60">已应用到内容</dt><dd>{selectedCopyrightWorkflow.takedownApplied ? '是' : '否'}</dd></div>
                        <div><dt className="text-yellow-100/60">临时下架</dt><dd>{formatTime(typeof selectedCopyrightWorkflow.temporaryTakedownAt === 'string' ? selectedCopyrightWorkflow.temporaryTakedownAt : null)}</dd></div>
                        <div><dt className="text-yellow-100/60">恢复时间</dt><dd>{formatTime(typeof selectedCopyrightWorkflow.restoredAt === 'string' ? selectedCopyrightWorkflow.restoredAt : null)}</dd></div>
                      </dl>
                    )}
                  </div>
                )}
                <form onSubmit={(event) => void submitDecision(event)} className="mt-4 space-y-4">
                  <label className="block text-sm">
                    <span className="text-text-secondary">动作</span>
                    <select value={action} onChange={(event) => setAction(event.target.value)} className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2">
                      {ACTIONS.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
                    </select>
                  </label>
                  <label className="block text-sm">
                    <span className="text-text-secondary">处理备注</span>
                    <textarea value={note} onChange={(event) => setNote(event.target.value)} rows={4} className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2" />
                  </label>
                  <button type="submit" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">提交处理</button>
                </form>
              </section>

              <section className="grid gap-5 md:grid-cols-2">
                <div className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
                  <h2 className="text-lg font-semibold">相同对象举报</h2>
                  <div className="mt-3 space-y-2 text-sm text-text-secondary">
                    {(selected.similarReports || []).slice(0, 8).map((item) => (
                      <div key={item.id} className="rounded-md border border-border-secondary bg-bg-tertiary p-3">{item.reason} · {formatTime(item.createdAt)}</div>
                    ))}
                    {(selected.similarReports || []).length === 0 && <div>暂无相似举报。</div>}
                  </div>
                </div>
                <div className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
                  <h2 className="text-lg font-semibold">目标用户历史</h2>
                  <div className="mt-3 space-y-2 text-sm text-text-secondary">
                    {(selected.targetHistory || []).slice(0, 8).map((item) => (
                      <div key={item.id} className="rounded-md border border-border-secondary bg-bg-tertiary p-3">{item.targetType} · {item.reason} · {formatTime(item.createdAt)}</div>
                    ))}
                    {(selected.targetHistory || []).length === 0 && <div>暂无目标用户历史举报。</div>}
                  </div>
                </div>
              </section>

              <section className="grid gap-5 md:grid-cols-2">
                <div className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
                  <h2 className="text-lg font-semibold">历史处罚</h2>
                  <pre className="mt-3 max-h-[260px] overflow-auto rounded-md border border-border-secondary bg-bg-tertiary p-3 text-xs text-text-secondary">{shortJson(selected.enforcementHistory)}</pre>
                </div>
                <div className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
                  <h2 className="text-lg font-semibold">历史申诉</h2>
                  <pre className="mt-3 max-h-[260px] overflow-auto rounded-md border border-border-secondary bg-bg-tertiary p-3 text-xs text-text-secondary">{shortJson(selected.appealHistory)}</pre>
                </div>
              </section>
            </div>
          ) : (
            <div className="rounded-lg border border-border-secondary bg-bg-secondary p-5 text-sm text-text-secondary">请选择一条举报查看详情。</div>
          )}
        </section>
      </section>
    </main>
  );
}
