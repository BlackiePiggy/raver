'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import { AdminPreRegistrationItem, preRegistrationAPI, PreRegistrationBatch } from '@/lib/api/pre-registration';

type DecisionType = 'SELECTED' | 'NOT_SELECTED' | 'WAITLIST';
type ChannelType = 'EMAIL' | 'SMS' | 'WECHAT' | 'IN_APP';

const DECISION_OPTIONS: Array<{ value: DecisionType; label: string }> = [
  { value: 'SELECTED', label: '已获得资格' },
  { value: 'NOT_SELECTED', label: '本轮未中签' },
  { value: 'WAITLIST', label: '候补' },
];

const CHANNEL_OPTIONS: Array<{ value: ChannelType; label: string }> = [
  { value: 'EMAIL', label: '邮件' },
  { value: 'SMS', label: '短信' },
  { value: 'WECHAT', label: '微信' },
  { value: 'IN_APP', label: '站内通知' },
];

export default function PreRegistrationAdminPage() {
  const { user, token, isLoading } = useAuth();
  const [items, setItems] = useState<AdminPreRegistrationItem[]>([]);
  const [batches, setBatches] = useState<PreRegistrationBatch[]>([]);
  const [selectedBatchId, setSelectedBatchId] = useState<string>('');
  const [selectedRegistrationIds, setSelectedRegistrationIds] = useState<Set<string>>(new Set());

  const [decision, setDecision] = useState<DecisionType>('SELECTED');
  const [decisionReason, setDecisionReason] = useState('');
  const [notificationChannel, setNotificationChannel] = useState<ChannelType>('EMAIL');
  const [templateKey, setTemplateKey] = useState('beta_result_notice');

  const [batchName, setBatchName] = useState('');
  const [plannedSlots, setPlannedSlots] = useState('');
  const [batchNote, setBatchNote] = useState('');

  const [statusFilter, setStatusFilter] = useState('');
  const [searchKeyword, setSearchKeyword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const isAuthorized = user?.role === 'admin' || user?.role === 'operator';
  const selectedCount = selectedRegistrationIds.size;
  const selectedIdsArray = useMemo(() => Array.from(selectedRegistrationIds), [selectedRegistrationIds]);

  const clearFeedback = () => {
    setError(null);
    setMessage(null);
  };

  const loadData = async () => {
    if (!token || !isAuthorized) return;
    setLoading(true);
    clearFeedback();
    try {
      const [registrationRes, batchRes] = await Promise.all([
        preRegistrationAPI.listAdminRegistrations(token, {
          limit: 100,
          status: statusFilter || undefined,
          search: searchKeyword || undefined,
        }),
        preRegistrationAPI.listAdminBatches(token),
      ]);
      setItems(registrationRes.items);
      setBatches(batchRes.items);
      if (!selectedBatchId && batchRes.items.length > 0) {
        setSelectedBatchId(batchRes.items[0].id);
      }
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载数据失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, isAuthorized]);

  const handleSearch = async () => {
    await loadData();
  };

  const toggleSelection = (registrationId: string) => {
    setSelectedRegistrationIds((prev) => {
      const next = new Set(prev);
      if (next.has(registrationId)) {
        next.delete(registrationId);
      } else {
        next.add(registrationId);
      }
      return next;
    });
  };

  const toggleSelectAll = () => {
    if (selectedRegistrationIds.size === items.length) {
      setSelectedRegistrationIds(new Set());
      return;
    }
    setSelectedRegistrationIds(new Set(items.map((item) => item.id)));
  };

  const handleCreateBatch = async () => {
    if (!token) return;
    clearFeedback();

    const trimmedBatchName = batchName.trim();
    if (!trimmedBatchName) {
      setError('请输入批次名称');
      return;
    }

    try {
      await preRegistrationAPI.createAdminBatch(token, {
        batchName: trimmedBatchName,
        plannedSlots: plannedSlots ? Number(plannedSlots) : undefined,
        note: batchNote.trim() || undefined,
      });
      setMessage('抽取批次已创建');
      setBatchName('');
      setPlannedSlots('');
      setBatchNote('');
      await loadData();
    } catch (createError) {
      setError(createError instanceof Error ? createError.message : '创建批次失败');
    }
  };

  const handleApplyDecision = async () => {
    if (!token) return;
    clearFeedback();

    if (!selectedBatchId) {
      setError('请先选择抽取批次');
      return;
    }
    if (selectedCount === 0) {
      setError('请至少勾选一条登记记录');
      return;
    }

    try {
      const result = await preRegistrationAPI.applyAdminBatchDecision(token, selectedBatchId, {
        decision,
        registrationIds: selectedIdsArray,
        decisionReason: decisionReason.trim() || undefined,
      });
      setMessage(`${result.message}（${result.affectedCount} 条）`);
      setSelectedRegistrationIds(new Set());
      await loadData();
    } catch (applyError) {
      setError(applyError instanceof Error ? applyError.message : '更新决策失败');
    }
  };

  const handleCreateNotificationTask = async () => {
    if (!token) return;
    clearFeedback();

    if (selectedCount === 0) {
      setError('请先勾选要发送通知的登记记录');
      return;
    }
    if (!templateKey.trim()) {
      setError('请输入通知模板键');
      return;
    }

    try {
      const result = await preRegistrationAPI.enqueueNotifications(token, {
        channel: notificationChannel,
        templateKey: templateKey.trim(),
        registrationIds: selectedIdsArray,
        batchId: selectedBatchId || undefined,
      });
      setMessage(`通知任务已创建（${result.createdCount} 条）`);
    } catch (notifyError) {
      setError(notifyError instanceof Error ? notifyError.message : '创建通知任务失败');
    }
  };

  if (isLoading) {
    return (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <div className="mx-auto max-w-5xl px-6 pt-28">加载中...</div>
      </main>
    );
  }

  if (!user) {
    return (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <div className="mx-auto max-w-5xl px-6 pt-28">
          <p className="text-lg">请先登录后访问预登记管理后台。</p>
          <Link href="/login" className="mt-4 inline-block rounded-full bg-primary-blue px-5 py-2 text-white">
            去登录
          </Link>
        </div>
      </main>
    );
  }

  if (!isAuthorized) {
    return (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <div className="mx-auto max-w-5xl px-6 pt-28">
          <p className="text-lg">当前账号无权限访问预登记管理后台。</p>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-bg-primary text-text-primary">
      <Navigation />
      <section className="mx-auto max-w-7xl px-6 pb-12 pt-24">
        <div className="mb-6">
          <h1 className="text-3xl font-semibold">预登记管理后台</h1>
          <p className="mt-2 text-text-secondary">查看登记、创建抽取批次、人工决定资格，并创建多端通知任务。</p>
        </div>

        {error && <div className="mb-4 rounded-lg border border-red-500/40 bg-red-500/10 px-4 py-3 text-red-300">{error}</div>}
        {message && (
          <div className="mb-4 rounded-lg border border-accent-green/40 bg-accent-green/10 px-4 py-3 text-accent-green">{message}</div>
        )}

        <div className="grid gap-4 rounded-2xl border border-border-secondary bg-bg-secondary p-5 md:grid-cols-4">
          <div className="md:col-span-2">
            <label className="mb-2 block text-sm text-text-secondary">搜索（邮箱/手机号/微信号）</label>
            <input
              value={searchKeyword}
              onChange={(event) => setSearchKeyword(event.target.value)}
              className="w-full rounded-xl border border-border-secondary bg-bg-tertiary px-4 py-2.5 text-sm"
              placeholder="keyword"
            />
          </div>
          <div>
            <label className="mb-2 block text-sm text-text-secondary">状态筛选</label>
            <select
              value={statusFilter}
              onChange={(event) => setStatusFilter(event.target.value)}
              className="w-full rounded-xl border border-border-secondary bg-bg-tertiary px-4 py-2.5 text-sm"
            >
              <option value="">全部</option>
              <option value="SUBMITTED">SUBMITTED</option>
              <option value="SELECTED">SELECTED</option>
              <option value="NOT_SELECTED">NOT_SELECTED</option>
              <option value="WAITLIST">WAITLIST</option>
            </select>
          </div>
          <div className="flex items-end">
            <button onClick={handleSearch} className="w-full rounded-xl bg-primary-blue px-4 py-2.5 text-sm font-semibold text-white">
              查询
            </button>
          </div>
        </div>

        <div className="mt-5 grid gap-5 lg:grid-cols-[2fr,1fr]">
          <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-5">
            <div className="mb-3 flex items-center justify-between">
              <h2 className="text-xl font-semibold">登记列表</h2>
              <button
                onClick={toggleSelectAll}
                disabled={items.length === 0}
                className="rounded-lg border border-border-primary px-3 py-1.5 text-xs hover:border-primary-blue hover:text-primary-blue disabled:opacity-50"
              >
                {selectedRegistrationIds.size === items.length && items.length > 0 ? '取消全选' : '全选'}
              </button>
            </div>

            <div className="overflow-x-auto">
              <table className="min-w-full text-left text-sm">
                <thead>
                  <tr className="border-b border-border-secondary text-text-secondary">
                    <th className="px-2 py-2"></th>
                    <th className="px-2 py-2">邮箱</th>
                    <th className="px-2 py-2">手机号</th>
                    <th className="px-2 py-2">微信号</th>
                    <th className="px-2 py-2">称呼</th>
                    <th className="px-2 py-2">完整称呼</th>
                    <th className="px-2 py-2">留言</th>
                    <th className="px-2 py-2">状态</th>
                  </tr>
                </thead>
                <tbody>
                  {items.map((item) => (
                    <tr key={item.id} className="border-b border-border-secondary/60">
                      <td className="px-2 py-2">
                        <input
                          type="checkbox"
                          checked={selectedRegistrationIds.has(item.id)}
                          onChange={() => toggleSelection(item.id)}
                        />
                      </td>
                      <td className="px-2 py-2">{item.email}</td>
                      <td className="px-2 py-2">{item.phoneCountryCode && item.phoneNumber ? `${item.phoneCountryCode} ${item.phoneNumber}` : '-'}</td>
                      <td className="px-2 py-2">{item.wechatId || '-'}</td>
                      <td className="px-2 py-2">{item.salutation}</td>
                      <td className="px-2 py-2">{item.fullSalutation || `${item.salutationName || ''}${item.salutation}`}</td>
                      <td className="px-2 py-2">
                        <p className="max-w-[260px] whitespace-pre-wrap break-words text-xs text-text-secondary" title={item.expectationMessage || ''}>
                          {item.expectationMessage || '-'}
                        </p>
                      </td>
                      <td className="px-2 py-2">{item.status}</td>
                    </tr>
                  ))}
                  {items.length === 0 && (
                    <tr>
                      <td colSpan={8} className="px-2 py-6 text-center text-text-tertiary">
                        {loading ? '加载中...' : '暂无数据'}
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          <div className="space-y-5">
            <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-5">
              <h2 className="mb-3 text-lg font-semibold">创建抽取批次</h2>
              <div className="space-y-3">
                <input
                  value={batchName}
                  onChange={(event) => setBatchName(event.target.value)}
                  placeholder="批次名称"
                  className="w-full rounded-xl border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
                />
                <input
                  value={plannedSlots}
                  onChange={(event) => setPlannedSlots(event.target.value)}
                  placeholder="计划名额（可选）"
                  className="w-full rounded-xl border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
                />
                <textarea
                  value={batchNote}
                  onChange={(event) => setBatchNote(event.target.value)}
                  rows={3}
                  placeholder="备注（可选）"
                  className="w-full rounded-xl border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
                />
                <button onClick={handleCreateBatch} className="w-full rounded-xl bg-primary-blue px-4 py-2.5 text-sm font-semibold text-white">
                  创建批次
                </button>
              </div>
            </div>

            <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-5">
              <h2 className="mb-3 text-lg font-semibold">人工抽取决策</h2>
              <div className="space-y-3">
                <select
                  value={selectedBatchId}
                  onChange={(event) => setSelectedBatchId(event.target.value)}
                  className="w-full rounded-xl border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
                >
                  <option value="">选择批次</option>
                  {batches.map((batch) => (
                    <option key={batch.id} value={batch.id}>
                      {batch.batchName}（已处理 {batch.stats.total}）
                    </option>
                  ))}
                </select>
                <select
                  value={decision}
                  onChange={(event) => setDecision(event.target.value as DecisionType)}
                  className="w-full rounded-xl border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
                >
                  {DECISION_OPTIONS.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
                <input
                  value={decisionReason}
                  onChange={(event) => setDecisionReason(event.target.value)}
                  placeholder="决策备注（可选）"
                  className="w-full rounded-xl border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
                />
                <button
                  onClick={handleApplyDecision}
                  className="w-full rounded-xl bg-accent-cyan px-4 py-2.5 text-sm font-semibold text-white"
                >
                  对已选记录应用决策（{selectedCount}）
                </button>
              </div>
            </div>

            <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-5">
              <h2 className="mb-3 text-lg font-semibold">创建通知任务</h2>
              <div className="space-y-3">
                <select
                  value={notificationChannel}
                  onChange={(event) => setNotificationChannel(event.target.value as ChannelType)}
                  className="w-full rounded-xl border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
                >
                  {CHANNEL_OPTIONS.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
                <input
                  value={templateKey}
                  onChange={(event) => setTemplateKey(event.target.value)}
                  className="w-full rounded-xl border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
                  placeholder="模板键"
                />
                <button
                  onClick={handleCreateNotificationTask}
                  className="w-full rounded-xl bg-accent-green px-4 py-2.5 text-sm font-semibold text-white"
                >
                  创建通知任务（{selectedCount}）
                </button>
              </div>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
