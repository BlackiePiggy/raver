'use client';

import { useEffect, useMemo, useState } from 'react';
import AdminToast, { type AdminToastTone } from '@/components/admin/AdminToast';
import {
  notificationCenterAdminApi,
  type NotificationAdminPublishTaskContext,
  type NotificationAdminPublishTaskItem,
  type NotificationAdminPublishTaskPage,
} from '@/lib/api/notification-center-admin';

type NotificationPublishTaskQueueProps = {
  page: NotificationAdminPublishTaskPage | null;
  loading: boolean;
  pageValue: number;
  onPageChange: (page: number) => void;
  onReload: () => Promise<void> | void;
};

type ToastState = {
  message: string;
  tone: AdminToastTone;
} | null;

const AUDIENCE_LABELS: Record<string, string> = {
  event_news: '活动关注用户',
  followed_dj_news: 'DJ 关注用户',
  followed_brand_news: '品牌关注用户',
  followed_dj_event: 'DJ 关注用户',
  followed_brand_event: '品牌关注用户',
};

export default function NotificationPublishTaskQueue({
  page,
  loading,
  pageValue,
  onPageChange,
  onReload,
}: NotificationPublishTaskQueueProps) {
  const [expandedTaskId, setExpandedTaskId] = useState<string | null>(null);
  const [detailTaskId, setDetailTaskId] = useState<string | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailError, setDetailError] = useState<string | null>(null);
  const [detailContext, setDetailContext] = useState<NotificationAdminPublishTaskContext | null>(null);
  const [selectedAudienceKeys, setSelectedAudienceKeys] = useState<string[]>([]);
  const [sendInApp, setSendInApp] = useState(true);
  const [sendApns, setSendApns] = useState(true);
  const [actingTaskId, setActingTaskId] = useState<string | null>(null);
  const [toast, setToast] = useState<ToastState>(null);

  useEffect(() => {
    if (!expandedTaskId) {
      setDetailTaskId(null);
      setDetailContext(null);
      setSelectedAudienceKeys([]);
      setDetailError(null);
      return;
    }

    let cancelled = false;
    const run = async () => {
      try {
        setDetailLoading(true);
        setDetailError(null);
        setDetailTaskId(expandedTaskId);
        const detail = await notificationCenterAdminApi.getPublishTask(expandedTaskId);
        if (cancelled) return;
        setDetailContext(detail.context);
        setSelectedAudienceKeys(
          (detail.context?.audiences ?? [])
            .filter((item) => item.targetUserCount > 0)
            .map((item) => item.key)
        );
      } catch (error) {
        if (cancelled) return;
        setDetailError(error instanceof Error ? error.message : '加载任务详情失败');
      } finally {
        if (!cancelled) {
          setDetailLoading(false);
        }
      }
    };

    void run();
    return () => {
      cancelled = true;
    };
  }, [expandedTaskId]);

  const selectedTask = useMemo(
    () => page?.items.find((item) => item.id === expandedTaskId) ?? null,
    [expandedTaskId, page?.items]
  );

  const totalTargetUsers = useMemo(
    () =>
      (detailContext?.audiences ?? [])
        .filter((item) => selectedAudienceKeys.includes(item.key))
        .reduce((sum, item) => sum + item.targetUserCount, 0),
    [detailContext?.audiences, selectedAudienceKeys]
  );

  const availableChannels = useMemo(() => {
    const channels: Array<'in_app' | 'apns'> = [];
    if (sendInApp) channels.push('in_app');
    if (sendApns) channels.push('apns');
    return channels;
  }, [sendApns, sendInApp]);

  const toggleAudience = (key: string) => {
    setSelectedAudienceKeys((current) =>
      current.includes(key) ? current.filter((item) => item !== key) : [...current, key]
    );
  };

  const handlePublish = async () => {
    if (!selectedTask) return;
    if (selectedAudienceKeys.length === 0) {
      setToast({ message: '请至少选择一类受众', tone: 'warning' });
      return;
    }
    if (availableChannels.length === 0) {
      setToast({ message: '请至少选择一种发送渠道', tone: 'warning' });
      return;
    }

    try {
      setActingTaskId(selectedTask.id);
      await notificationCenterAdminApi.publishTask({
        taskId: selectedTask.id,
        audienceKeys: selectedAudienceKeys,
        channels: availableChannels,
      });
      setToast({ message: '通知已发布', tone: 'success' });
      setExpandedTaskId(null);
      await onReload();
    } catch (error) {
      setToast({ message: error instanceof Error ? error.message : '发布失败', tone: 'error' });
    } finally {
      setActingTaskId(null);
    }
  };

  const handleReject = async () => {
    if (!selectedTask) return;
    try {
      setActingTaskId(selectedTask.id);
      await notificationCenterAdminApi.rejectTask({ taskId: selectedTask.id });
      setToast({ message: '已标记为不发布', tone: 'success' });
      setExpandedTaskId(null);
      await onReload();
    } catch (error) {
      setToast({ message: error instanceof Error ? error.message : '处理失败', tone: 'error' });
    } finally {
      setActingTaskId(null);
    }
  };

  return (
    <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
      <AdminToast
        message={toast?.message || null}
        tone={toast?.tone || 'neutral'}
        visible={Boolean(toast?.message)}
        onClose={() => setToast(null)}
      />

      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <div className="admin-studio-label">Pending Decisions</div>
          <h2 className="mt-2 text-xl font-semibold text-[#071110]">待决策发布任务</h2>
          <div className="mt-2 text-sm text-[#5b6763]">
            {page
              ? `共 ${page.pagination.total.toLocaleString()} 条，当前第 ${page.pagination.page} / ${Math.max(1, page.pagination.totalPages)} 页`
              : '正在加载待决策任务...'}
          </div>
        </div>
      </div>

      <div className="mt-5 space-y-3">
        {loading ? (
          <div className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] px-4 py-4 text-sm text-[#5b6763]">
            正在加载待决策发布任务...
          </div>
        ) : page?.items.length ? (
          page.items.map((task) => {
            const isExpanded = task.id === expandedTaskId;
            return (
              <div key={task.id} className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] px-4 py-4">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="text-sm font-semibold text-[#071110]">{task.title}</div>
                    <div className="mt-1 text-xs text-[#5b6763]">
                      {task.taskType} / {task.entityType} / {task.entityId}
                    </div>
                    {task.summary ? <div className="mt-2 text-sm text-[#5b6763]">{task.summary}</div> : null}
                    <div className="mt-2 text-xs text-[#5b6763]">最近更新时间 {task.updatedAt}</div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="rounded-full bg-[#eef2ef] px-3 py-1 text-[11px] font-semibold text-[#42514c]">
                      {task.status}
                    </span>
                    <button
                      type="button"
                      onClick={() => setExpandedTaskId((current) => (current === task.id ? null : task.id))}
                      className="rounded-full border border-[#d9e1de] bg-white px-4 py-2 text-sm font-semibold text-[#071110]"
                    >
                      {isExpanded ? '收起' : '处理'}
                    </button>
                  </div>
                </div>

                {isExpanded ? (
                  <div className="mt-4 rounded-[18px] border border-[#e7ece8] bg-white p-4">
                    {detailLoading && detailTaskId === task.id ? (
                      <div className="text-sm text-[#5b6763]">正在加载任务详情...</div>
                    ) : detailError ? (
                      <div className="rounded-[16px] border border-[#f0d7d5] bg-[#fff7f6] px-3 py-3 text-sm text-[#8b3a3a]">
                        {detailError}
                      </div>
                    ) : detailContext ? (
                      <div className="space-y-4">
                        <div className="grid gap-4 md:grid-cols-[1.3fr_0.7fr]">
                          <div className="rounded-[18px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
                            <div className="text-xs uppercase tracking-[0.14em] text-black/38">Entity</div>
                            <div className="mt-2 text-base font-semibold text-[#071110]">{detailContext.entity.title}</div>
                            <div className="mt-2 text-sm leading-6 text-black/56">{detailContext.entity.summary}</div>
                          </div>
                          <div className="rounded-[18px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
                            <div className="text-xs uppercase tracking-[0.14em] text-black/38">Snapshot</div>
                            <div className="mt-2 text-3xl font-semibold text-[#071110]">{totalTargetUsers}</div>
                            <div className="mt-1 text-sm text-black/56">当前选中用户数</div>
                          </div>
                        </div>

                        <div className="space-y-3">
                          {detailContext.audiences.map((audience) => {
                            const checked = selectedAudienceKeys.includes(audience.key);
                            const disabled = audience.targetUserCount <= 0;
                            return (
                              <label
                                key={audience.key}
                                className={`flex items-start gap-4 rounded-[18px] border px-4 py-4 ${
                                  checked ? 'border-[#071110] bg-[#f5f7f6]' : 'border-[#e7ece8] bg-white'
                                } ${disabled ? 'opacity-55' : 'cursor-pointer'}`}
                              >
                                <input
                                  type="checkbox"
                                  checked={checked}
                                  disabled={disabled}
                                  onChange={() => toggleAudience(audience.key)}
                                  className="mt-1 h-4 w-4"
                                />
                                <div className="min-w-0 flex-1">
                                  <div className="flex flex-wrap items-center gap-2">
                                    <div className="text-sm font-semibold text-[#071110]">
                                      {AUDIENCE_LABELS[audience.key] || audience.label}
                                    </div>
                                    <span className="rounded-full bg-[#eef2ef] px-3 py-1 text-[11px] font-semibold text-[#42514c]">
                                      {audience.entityCount} 个对象
                                    </span>
                                    <span className="rounded-full bg-[#eef2ef] px-3 py-1 text-[11px] font-semibold text-[#42514c]">
                                      {audience.targetUserCount} 位用户
                                    </span>
                                  </div>
                                </div>
                              </label>
                            );
                          })}
                        </div>

                        <div className="grid gap-4 md:grid-cols-[0.8fr_1.2fr]">
                          <div className="space-y-3 rounded-[18px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
                            <label className="flex items-center justify-between rounded-[16px] border border-[#e7ece8] bg-white px-4 py-3 text-sm text-[#071110]">
                              <span>站内通知</span>
                              <input
                                type="checkbox"
                                checked={sendInApp}
                                onChange={(event) => setSendInApp(event.target.checked)}
                              />
                            </label>
                            <label className="flex items-center justify-between rounded-[16px] border border-[#e7ece8] bg-white px-4 py-3 text-sm text-[#071110]">
                              <span>APNS 推送</span>
                              <input
                                type="checkbox"
                                checked={sendApns}
                                onChange={(event) => setSendApns(event.target.checked)}
                              />
                            </label>
                          </div>

                          <div className="flex flex-wrap items-end justify-end gap-2">
                            <button
                              type="button"
                              onClick={() => void handleReject()}
                              disabled={actingTaskId === task.id}
                              className="rounded-full border border-[#d9e1de] bg-white px-5 py-3 text-sm font-semibold text-[#071110] disabled:opacity-45"
                            >
                              {actingTaskId === task.id ? '处理中...' : '不发布'}
                            </button>
                            <button
                              type="button"
                              onClick={() => void handlePublish()}
                              disabled={actingTaskId === task.id}
                              className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white disabled:opacity-45"
                            >
                              {actingTaskId === task.id ? '发布中...' : '立即发布'}
                            </button>
                          </div>
                        </div>
                      </div>
                    ) : (
                      <div className="text-sm text-[#5b6763]">暂无可用详情</div>
                    )}
                  </div>
                ) : null}
              </div>
            );
          })
        ) : (
          <div className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] px-4 py-4 text-sm text-[#5b6763]">
            当前没有待决策发布任务。
          </div>
        )}
      </div>

      {page && page.pagination.totalPages > 1 ? (
        <div className="mt-5 flex flex-wrap items-center gap-2">
          <button
            type="button"
            disabled={page.pagination.page <= 1}
            onClick={() => onPageChange(Math.max(1, pageValue - 1))}
            className="rounded-full border border-[#d9e1de] bg-white px-4 py-2 text-sm font-semibold text-[#071110] disabled:opacity-45"
          >
            上一页
          </button>
          <span className="text-sm text-[#5b6763]">
            第 {page.pagination.page} / {page.pagination.totalPages} 页
          </span>
          <button
            type="button"
            disabled={page.pagination.page >= page.pagination.totalPages}
            onClick={() => onPageChange(Math.min(page.pagination.totalPages, pageValue + 1))}
            className="rounded-full border border-[#d9e1de] bg-white px-4 py-2 text-sm font-semibold text-[#071110] disabled:opacity-45"
          >
            下一页
          </button>
        </div>
      ) : null}
    </section>
  );
}
