'use client';

import Link from 'next/link';
import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import {
  AccountEnforcement,
  EnforcementAppeal,
  accountEnforcementsApi,
} from '@/lib/api/account-enforcements';
import { formatDateTimeWithSystemTimeZoneLabel } from '@/lib/timezone';

const ENFORCEMENT_TYPES = [
  { value: 'warning', label: '警告' },
  { value: 'restriction', label: '功能限制' },
  { value: 'suspension', label: '临时封禁' },
  { value: 'ban', label: '永久封禁' },
  { value: 'risk_freeze', label: '风控冻结' },
];

const SCOPES = [
  { value: 'post_create', label: '发帖' },
  { value: 'comment_create', label: '评论' },
  { value: 'message_send', label: '私信/群聊' },
  { value: 'media_upload', label: '上传媒体' },
  { value: 'event_create', label: '创建活动' },
  { value: 'location_share', label: '位置共享' },
  { value: 'profile_update', label: '修改资料' },
  { value: 'squad_create', label: '创建小队' },
];

const REASONS = [
  'spam',
  'harassment',
  'hate_or_discrimination',
  'sexual_content',
  'violence_or_threat',
  'illegal_activity',
  'impersonation',
  'privacy_violation',
  'copyright',
  'scam_or_fraud',
  'minor_safety',
  'platform_abuse',
  'other',
];

const formatTime = (value?: string | null): string => {
  if (!value) return '-';
  return formatDateTimeWithSystemTimeZoneLabel(value);
};

const statusClassName = (status: string): string => {
  if (status === 'active') return 'border-red-500/40 bg-red-500/10 text-red-300';
  if (status === 'scheduled') return 'border-yellow-500/40 bg-yellow-500/10 text-yellow-300';
  if (status === 'revoked') return 'border-blue-400/40 bg-blue-400/10 text-blue-300';
  return 'border-border-secondary bg-bg-tertiary text-text-secondary';
};

const splitScopes = (value: string): string[] =>
  value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);

function StatusBadge({ status }: { status: string }) {
  return <span className={`rounded-md border px-2 py-1 text-xs font-semibold ${statusClassName(status)}`}>{status}</span>;
}

export default function AccountEnforcementsAdminPage() {
  const { user, token, isLoading } = useAuth();
  const canOperate = user?.role === 'admin' || user?.role === 'operator';

  const [items, setItems] = useState<AccountEnforcement[]>([]);
  const [appeals, setAppeals] = useState<EnforcementAppeal[]>([]);
  const [filterUserId, setFilterUserId] = useState('');
  const [filterStatus, setFilterStatus] = useState('active');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const [targetUserId, setTargetUserId] = useState('');
  const [type, setType] = useState('suspension');
  const [reasonCode, setReasonCode] = useState('harassment');
  const [durationDays, setDurationDays] = useState('7');
  const [customEndsAt, setCustomEndsAt] = useState('');
  const [scopes, setScopes] = useState('message_send,comment_create');
  const [internalNote, setInternalNote] = useState('');

  const selectedType = useMemo(() => ENFORCEMENT_TYPES.find((item) => item.value === type), [type]);

  const loadAll = useCallback(async () => {
    if (!token || !canOperate) return;
    try {
      setLoading(true);
      setError(null);
      const [enforcementResult, appealResult] = await Promise.all([
        accountEnforcementsApi.list(token, {
          userId: filterUserId.trim() || undefined,
          status: filterStatus || undefined,
          limit: 100,
        }),
        accountEnforcementsApi.listAppeals(token, { limit: 100 }),
      ]);
      setItems(enforcementResult.items);
      setAppeals(appealResult.items);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载处罚数据失败');
    } finally {
      setLoading(false);
    }
  }, [canOperate, filterStatus, filterUserId, token]);

  useEffect(() => {
    void loadAll();
  }, [loadAll]);

  const createEnforcement = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!token) return;
    try {
      setError(null);
      setNotice(null);
      const duration = Number(durationDays);
      await accountEnforcementsApi.create(token, targetUserId.trim(), {
        type,
        reasonCode,
        scopes: splitScopes(scopes),
        durationDays: Number.isFinite(duration) && duration > 0 ? Math.floor(duration) : undefined,
        endsAt: customEndsAt ? new Date(customEndsAt).toISOString() : undefined,
        internalNote: internalNote.trim() || undefined,
      });
      setNotice('处罚已创建');
      setTargetUserId('');
      setInternalNote('');
      await loadAll();
    } catch (createError) {
      setError(createError instanceof Error ? createError.message : '创建处罚失败');
    }
  };

  const revokeEnforcement = async (item: AccountEnforcement) => {
    if (!token) return;
    const reason = window.prompt('请输入撤销原因');
    if (!reason) return;
    try {
      setError(null);
      await accountEnforcementsApi.revoke(token, item.id, reason);
      setNotice('处罚已撤销');
      await loadAll();
    } catch (revokeError) {
      setError(revokeError instanceof Error ? revokeError.message : '撤销失败');
    }
  };

  const expireDue = async () => {
    if (!token) return;
    try {
      const result = await accountEnforcementsApi.expireDue(token);
      setNotice(`已激活 ${result.activatedCount} 条计划处罚，过期 ${result.expiredCount} 条临时处罚`);
      await loadAll();
    } catch (expireError) {
      setError(expireError instanceof Error ? expireError.message : '处理到期处罚失败');
    }
  };

  const decideAppeal = async (appeal: EnforcementAppeal, status: string, decision: string) => {
    if (!token) return;
    const decisionNote = window.prompt('处理备注') || '';
    try {
      setError(null);
      await accountEnforcementsApi.decideAppeal(token, appeal.id, { status, decision, decisionNote });
      setNotice('申诉已处理');
      await loadAll();
    } catch (decideError) {
      setError(decideError instanceof Error ? decideError.message : '处理申诉失败');
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
            <h1 className="text-2xl font-semibold">账号处罚后台</h1>
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
            <h1 className="mt-1 text-3xl font-semibold">账号处罚与申诉</h1>
          </div>
          <div className="flex flex-wrap gap-3">
            <button
              type="button"
              onClick={() => void expireDue()}
              className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue"
            >
              处理到期处罚
            </button>
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

        <section className="grid gap-5 lg:grid-cols-[380px_1fr]">
          <form onSubmit={(event) => void createEnforcement(event)} className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
            <h2 className="text-xl font-semibold">手动处罚</h2>
            <div className="mt-4 space-y-4">
              <label className="block text-sm">
                <span className="text-text-secondary">用户 ID</span>
                <input
                  value={targetUserId}
                  onChange={(event) => setTargetUserId(event.target.value)}
                  required
                  className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
                />
              </label>
              <label className="block text-sm">
                <span className="text-text-secondary">处罚类型</span>
                <select value={type} onChange={(event) => setType(event.target.value)} className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm">
                  {ENFORCEMENT_TYPES.map((item) => (
                    <option key={item.value} value={item.value}>{item.label}</option>
                  ))}
                </select>
              </label>
              <label className="block text-sm">
                <span className="text-text-secondary">原因码</span>
                <select value={reasonCode} onChange={(event) => setReasonCode(event.target.value)} className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm">
                  {REASONS.map((item) => (
                    <option key={item} value={item}>{item}</option>
                  ))}
                </select>
              </label>
              <label className="block text-sm">
                <span className="text-text-secondary">限制范围</span>
                <input
                  value={scopes}
                  onChange={(event) => setScopes(event.target.value)}
                  disabled={type === 'suspension' || type === 'ban' || type === 'warning'}
                  className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm disabled:opacity-50"
                />
              </label>
              <div className="grid gap-3 md:grid-cols-2">
                <label className="block text-sm">
                  <span className="text-text-secondary">封禁天数</span>
                  <input
                    value={durationDays}
                    onChange={(event) => setDurationDays(event.target.value)}
                    disabled={type === 'ban' || type === 'warning'}
                    className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm disabled:opacity-50"
                  />
                </label>
                <label className="block text-sm">
                  <span className="text-text-secondary">自定义到期</span>
                  <input
                    type="datetime-local"
                    value={customEndsAt}
                    onChange={(event) => setCustomEndsAt(event.target.value)}
                    disabled={type === 'ban' || type === 'warning'}
                    className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm disabled:opacity-50"
                  />
                </label>
              </div>
              <label className="block text-sm">
                <span className="text-text-secondary">内部备注</span>
                <textarea
                  value={internalNote}
                  onChange={(event) => setInternalNote(event.target.value)}
                  rows={4}
                  className="mt-2 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
                />
              </label>
              <button type="submit" className="w-full rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
                创建{selectedType ? selectedType.label : '处罚'}
              </button>
            </div>
            <div className="mt-4 rounded-md border border-border-secondary bg-bg-tertiary p-3 text-xs leading-6 text-text-secondary">
              可选 scope：{SCOPES.map((item) => item.value).join(', ')}
            </div>
          </form>

          <div className="space-y-5">
            <section className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
              <div className="flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
                <h2 className="text-xl font-semibold">处罚列表</h2>
                <div className="flex flex-wrap gap-3">
                  <input
                    value={filterUserId}
                    onChange={(event) => setFilterUserId(event.target.value)}
                    placeholder="按用户 ID"
                    className="rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
                  />
                  <select value={filterStatus} onChange={(event) => setFilterStatus(event.target.value)} className="rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm">
                    <option value="">全部状态</option>
                    <option value="active">active</option>
                    <option value="scheduled">scheduled</option>
                    <option value="expired">expired</option>
                    <option value="revoked">revoked</option>
                  </select>
                </div>
              </div>
              <div className="mt-4 overflow-x-auto">
                <table className="min-w-full text-left text-sm">
                  <thead className="text-text-secondary">
                    <tr className="border-b border-border-secondary">
                      <th className="py-3 pr-4">用户</th>
                      <th className="py-3 pr-4">类型</th>
                      <th className="py-3 pr-4">范围</th>
                      <th className="py-3 pr-4">原因</th>
                      <th className="py-3 pr-4">时间</th>
                      <th className="py-3 pr-4">操作</th>
                    </tr>
                  </thead>
                  <tbody>
                    {items.map((item) => (
                      <tr key={item.id} className="border-b border-border-secondary/70 align-top">
                        <td className="py-3 pr-4">
                          <div className="font-semibold">{item.user?.displayName || item.user?.username || item.userId}</div>
                          <div className="mt-1 text-xs text-text-secondary">{item.userId}</div>
                          <div className="mt-2"><StatusBadge status={item.status} /></div>
                        </td>
                        <td className="py-3 pr-4">{item.type}</td>
                        <td className="py-3 pr-4">{item.scopes.length > 0 ? item.scopes.join(', ') : '-'}</td>
                        <td className="py-3 pr-4">{item.reasonCode}</td>
                        <td className="py-3 pr-4 text-xs leading-6 text-text-secondary">
                          <div>开始：{formatTime(item.startsAt)}</div>
                          <div>到期：{formatTime(item.endsAt)}</div>
                          <div>撤销：{formatTime(item.revokedAt)}</div>
                        </td>
                        <td className="py-3 pr-4">
                          {item.status === 'active' || item.status === 'scheduled' ? (
                            <button
                              type="button"
                              onClick={() => void revokeEnforcement(item)}
                              className="rounded-md border border-border-secondary px-3 py-1.5 text-xs hover:border-red-400 hover:text-red-300"
                            >
                              撤销
                            </button>
                          ) : (
                            <span className="text-xs text-text-secondary">-</span>
                          )}
                        </td>
                      </tr>
                    ))}
                    {items.length === 0 && (
                      <tr>
                        <td colSpan={6} className="py-8 text-center text-text-secondary">暂无处罚记录</td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </section>

            <section className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
              <h2 className="text-xl font-semibold">申诉处理</h2>
              <div className="mt-4 grid gap-3">
                {appeals.map((appeal) => (
                  <div key={appeal.id} className="rounded-lg border border-border-secondary bg-bg-tertiary p-4">
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div>
                        <div className="text-sm font-semibold">{appeal.status}</div>
                        <div className="mt-1 text-xs text-text-secondary">用户：{appeal.userId} · 处罚：{appeal.enforcementId}</div>
                      </div>
                      <div className="flex gap-2">
                        <button type="button" onClick={() => void decideAppeal(appeal, 'accepted', 'accepted')} className="rounded-md border border-border-secondary px-3 py-1.5 text-xs hover:border-accent-green hover:text-accent-green">
                          通过
                        </button>
                        <button type="button" onClick={() => void decideAppeal(appeal, 'rejected', 'rejected')} className="rounded-md border border-border-secondary px-3 py-1.5 text-xs hover:border-red-400 hover:text-red-300">
                          驳回
                        </button>
                      </div>
                    </div>
                    <p className="mt-3 text-sm leading-6">{appeal.appealReason}</p>
                    {appeal.contactEmail && <p className="mt-2 text-xs text-text-secondary">联系邮箱：{appeal.contactEmail}</p>}
                  </div>
                ))}
                {appeals.length === 0 && <div className="rounded-lg border border-border-secondary bg-bg-tertiary p-6 text-center text-sm text-text-secondary">暂无申诉</div>}
              </div>
            </section>
          </div>
        </section>
      </section>
    </main>
  );
}
