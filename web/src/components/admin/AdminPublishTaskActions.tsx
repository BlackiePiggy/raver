'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import AdminToast, { type AdminToastTone } from '@/components/admin/AdminToast';
import {
  notificationCenterAdminApi,
  type NotificationAdminPublishExecutionResult,
  type NotificationAdminPublishTaskContext,
  type NotificationAdminPublishTaskDetailResponse,
  type NotificationAdminPublishTaskItem,
  type NotificationAdminPublishTaskType,
} from '@/lib/api/notification-center-admin';

type AdminPublishTaskActionsProps = {
  taskType: NotificationAdminPublishTaskType;
  entityType: string;
  entityId: string;
  mode: 'create' | 'edit';
};

type ToastState = {
  message: string;
  tone: AdminToastTone;
} | null;

const TASK_TITLES: Record<NotificationAdminPublishTaskType, string> = {
  news_release: '资讯发布通知',
  event_release: '活动发布通知',
  dj_release: 'DJ 资料发布通知',
  brand_release: '品牌资料发布通知',
};

const AUDIENCE_LABELS: Record<string, string> = {
  event_news: '关注活动资讯的用户',
  followed_dj_news: '关注 DJ 资讯的用户',
  followed_brand_news: '关注品牌资讯的用户',
  followed_dj_event: '关注 DJ 活动的用户',
  followed_brand_event: '关注品牌活动的用户',
  followed_dj_info: '关注 DJ 的用户',
  followed_brand_info: '关注品牌的用户',
};

export default function AdminPublishTaskActions({
  taskType,
  entityType,
  entityId,
  mode,
}: AdminPublishTaskActionsProps) {
  const [loading, setLoading] = useState(true);
  const [publishing, setPublishing] = useState(false);
  const [rejecting, setRejecting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<ToastState>(null);
  const [task, setTask] = useState<NotificationAdminPublishTaskItem | null>(null);
  const [context, setContext] = useState<NotificationAdminPublishTaskContext | null>(null);
  const [result, setResult] = useState<NotificationAdminPublishExecutionResult | null>(null);
  const [selectedAudienceKeys, setSelectedAudienceKeys] = useState<string[]>([]);
  const [sendApns, setSendApns] = useState(true);
  const [sendInApp, setSendInApp] = useState(true);

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      try {
        setLoading(true);
        setError(null);
        const response: NotificationAdminPublishTaskDetailResponse =
          await notificationCenterAdminApi.getPublishTaskByEntity({
            taskType,
            entityType,
            entityId,
          });
        if (cancelled) return;
        setTask(response.task);
        setContext(response.context);
        setSelectedAudienceKeys(
          (response.context?.audiences ?? [])
            .filter((item) => item.targetUserCount > 0)
            .map((item) => item.key)
        );
      } catch (loadError) {
        if (cancelled) return;
        setError(loadError instanceof Error ? loadError.message : '加载通知任务失败');
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    void load();

    return () => {
      cancelled = true;
    };
  }, [entityId, entityType, taskType]);

  const availableChannels = useMemo(() => {
    const channels: Array<'in_app' | 'apns'> = [];
    if (sendInApp) channels.push('in_app');
    if (sendApns) channels.push('apns');
    return channels;
  }, [sendApns, sendInApp]);

  const totalTargetUsers = useMemo(() => {
    return (context?.audiences ?? [])
      .filter((item) => selectedAudienceKeys.includes(item.key))
      .reduce((sum, item) => sum + item.targetUserCount, 0);
  }, [context?.audiences, selectedAudienceKeys]);

  const toggleAudience = (key: string) => {
    setSelectedAudienceKeys((current) =>
      current.includes(key) ? current.filter((item) => item !== key) : [...current, key]
    );
  };

  const handlePublish = async () => {
    if (!task) {
      setToast({ message: '当前没有可发布任务', tone: 'warning' });
      return;
    }
    if (!selectedAudienceKeys.length) {
      setToast({ message: '请至少选择一类受众', tone: 'warning' });
      return;
    }
    if (!availableChannels.length) {
      setToast({ message: '请至少选择一种发送渠道', tone: 'warning' });
      return;
    }

    try {
      setPublishing(true);
      setError(null);
      const response = await notificationCenterAdminApi.publishTask({
        taskId: task.id,
        audienceKeys: selectedAudienceKeys,
        channels: availableChannels,
      });
      setTask(response.task);
      setResult(response.result);
      setToast({ message: '通知发布完成', tone: 'success' });
    } catch (publishError) {
      setError(publishError instanceof Error ? publishError.message : '通知发布失败');
      setToast({ message: '通知发布失败', tone: 'error' });
    } finally {
      setPublishing(false);
    }
  };

  const handleReject = async () => {
    if (!task) return;
    try {
      setRejecting(true);
      setError(null);
      const response = await notificationCenterAdminApi.rejectTask({
        taskId: task.id,
      });
      setTask(response.task);
      setToast({ message: '已标记为暂不发布', tone: 'success' });
    } catch (rejectError) {
      setError(rejectError instanceof Error ? rejectError.message : '拒绝发布失败');
      setToast({ message: '拒绝发布失败', tone: 'error' });
    } finally {
      setRejecting(false);
    }
  };

  if (loading) {
    return <section className="admin-studio-section p-6 text-sm text-black/48">正在加载通知任务...</section>;
  }

  if (error && !context) {
    return (
      <section className="admin-studio-section p-6">
        <div className="rounded-[24px] border border-[#f0d7d5] bg-[#fff7f6] px-4 py-3 text-sm text-[#8b3a3a]">
          {error}
        </div>
      </section>
    );
  }

  if (!task && !context) {
    return null;
  }

  const isFinished = task?.status === 'published' || task?.status === 'rejected';

  return (
    <section className="admin-studio-section p-6">
      <AdminToast
        message={toast?.message || null}
        tone={toast?.tone || 'neutral'}
        visible={Boolean(toast?.message)}
        onClose={() => setToast(null)}
      />

      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <div className="admin-studio-label">发布后通知</div>
          <h3 className="mt-2 text-[22px] font-semibold tracking-[-0.03em] text-[#071110]">
            {mode === 'create' ? '内容已保存，决定是否立即通知用户' : '内容已更新，决定是否向用户推送这次变更'}
          </h3>
          <p className="mt-3 max-w-3xl text-sm leading-6 text-black/52">
            这里使用统一的后台发布任务链路。你现在可以直接发布，也可以跳到统一内容历史页稍后继续处理。
          </p>
        </div>
        <div className="rounded-full bg-[#f3f5f4] px-4 py-2 text-xs font-semibold text-[#42514c]">
          {TASK_TITLES[taskType]}
          {task?.status ? ` / ${task.status}` : ''}
        </div>
      </div>

      {error ? (
        <div className="mt-5 rounded-[24px] border border-[#f0d7d5] bg-[#fff7f6] px-4 py-3 text-sm text-[#8b3a3a]">
          {error}
        </div>
      ) : null}

      {context ? (
        <div className="mt-5 space-y-5">
          <div className="grid gap-4 md:grid-cols-[1.4fr_0.6fr]">
            <div className="rounded-[28px] border border-[#e7ece8] bg-[#f9fbfa] p-5">
              <div className="text-xs uppercase tracking-[0.24em] text-black/38">Entity</div>
              <div className="mt-3 text-lg font-semibold text-[#071110]">{context.entity.title}</div>
              <div className="mt-2 text-sm leading-6 text-black/58">{context.entity.summary || '暂无摘要'}</div>
              <div className="mt-4 text-xs text-black/42">发生时间 {context.entity.occurredAt}</div>
            </div>
            <div className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
              <div className="text-xs uppercase tracking-[0.24em] text-black/38">Target Snapshot</div>
              <div className="mt-3 text-3xl font-semibold text-[#071110]">{totalTargetUsers}</div>
              <div className="mt-2 text-sm text-black/56">当前选中受众用户数</div>
            </div>
          </div>

          <div className="grid gap-4 lg:grid-cols-[1.3fr_0.7fr]">
            <div className="space-y-3">
              {context.audiences.map((audience) => {
                const checked = selectedAudienceKeys.includes(audience.key);
                const disabled = audience.targetUserCount <= 0 || isFinished;
                return (
                  <label
                    key={audience.key}
                    className={`flex items-start gap-4 rounded-[24px] border px-5 py-4 transition ${
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
                      <div className="flex flex-wrap items-center gap-3">
                        <div className="text-sm font-semibold text-[#071110]">
                          {AUDIENCE_LABELS[audience.key] || audience.label}
                        </div>
                        <span className="rounded-full bg-[#eef2ef] px-3 py-1 text-[11px] font-semibold text-[#42514c]">
                          {audience.entityCount} 个绑定对象
                        </span>
                        <span className="rounded-full bg-[#eef2ef] px-3 py-1 text-[11px] font-semibold text-[#42514c]">
                          {audience.targetUserCount} 位用户
                        </span>
                      </div>
                      <div className="mt-3 flex flex-wrap gap-2">
                        {audience.entities.map((entity) => (
                          <span
                            key={entity.id}
                            className="rounded-full border border-[#dde5e1] px-3 py-1 text-xs text-[#42514c]"
                          >
                            {entity.name} / {entity.targetUserCount}
                          </span>
                        ))}
                      </div>
                    </div>
                  </label>
                );
              })}
            </div>

            <div className="space-y-4 rounded-[28px] border border-[#e7ece8] bg-[#fcfcfb] p-5">
              <Link
                href={`/admin/notification-center/content-history?entityType=${encodeURIComponent(entityType)}&query=${encodeURIComponent(entityId)}`}
                className="inline-flex w-full items-center justify-center rounded-full border border-[#d7ddda] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
              >
                去统一内容历史继续处理
              </Link>

              <div>
                <div className="text-xs uppercase tracking-[0.24em] text-black/38">Channels</div>
                <div className="mt-3 space-y-3">
                  <label className="flex items-center justify-between rounded-[18px] border border-[#e7ece8] bg-white px-4 py-3 text-sm text-[#071110]">
                    <span>站内通知</span>
                    <input
                      type="checkbox"
                      checked={sendInApp}
                      disabled={isFinished}
                      onChange={(event) => setSendInApp(event.target.checked)}
                    />
                  </label>
                  <label className="flex items-center justify-between rounded-[18px] border border-[#e7ece8] bg-white px-4 py-3 text-sm text-[#071110]">
                    <span>APNS 推送</span>
                    <input
                      type="checkbox"
                      checked={sendApns}
                      disabled={isFinished}
                      onChange={(event) => setSendApns(event.target.checked)}
                    />
                  </label>
                </div>
              </div>

              <button
                type="button"
                onClick={() => void handlePublish()}
                disabled={publishing || isFinished || !selectedAudienceKeys.length || !availableChannels.length}
                className="inline-flex w-full items-center justify-center rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white disabled:opacity-45"
              >
                {publishing ? '发布中...' : '立即发布通知'}
              </button>

              <button
                type="button"
                onClick={() => void handleReject()}
                disabled={rejecting || isFinished}
                className="inline-flex w-full items-center justify-center rounded-full border border-[#d7ddda] bg-white px-5 py-3 text-sm font-semibold text-[#071110] disabled:opacity-45"
              >
                {rejecting ? '处理中...' : '标记无需推送'}
              </button>

              <div className="text-xs leading-6 text-black/42">
                如果暂时不在这里处理，也可以稍后到统一内容历史页继续推送、查看预览，或者标记为无需推送。
              </div>
            </div>
          </div>

          {result ? (
            <div className="rounded-[28px] border border-[#d8e5dc] bg-[#f7fbf8] p-5">
              <div className="admin-studio-label">Latest Result</div>
              <div className="mt-3 text-sm text-[#2f5d43]">
                已完成发布，本次共处理 {result.audiences.length} 组受众。
              </div>
            </div>
          ) : null}
        </div>
      ) : null}
    </section>
  );
}
