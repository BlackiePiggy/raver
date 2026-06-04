'use client';

import { useEffect, useMemo, useState } from 'react';
import AdminToast, { type AdminToastTone } from '@/components/admin/AdminToast';
import {
  notificationCenterAdminApi,
  type AdminNewsPublishContext,
  type AdminNewsPublishResult,
} from '@/lib/api/notification-center-admin';

type AdminNewsPublishActionsProps = {
  newsId: string;
  mode: 'create' | 'edit';
};

type ToastState = {
  message: string;
  tone: AdminToastTone;
} | null;

const AUDIENCE_LABELS: Record<string, string> = {
  event_news: '活动关注用户',
  followed_dj_news: 'DJ 关注用户',
  followed_brand_news: '厂牌关注用户',
};

export default function AdminNewsPublishActions({ newsId, mode }: AdminNewsPublishActionsProps) {
  const [context, setContext] = useState<AdminNewsPublishContext | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedAudienceKeys, setSelectedAudienceKeys] = useState<string[]>([]);
  const [sendApns, setSendApns] = useState(true);
  const [sendInApp, setSendInApp] = useState(true);
  const [publishing, setPublishing] = useState(false);
  const [result, setResult] = useState<AdminNewsPublishResult | null>(null);
  const [toast, setToast] = useState<ToastState>(null);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      try {
        setLoading(true);
        setError(null);
        setResult(null);
        const nextContext = await notificationCenterAdminApi.getNewsPublishContext(newsId);
        if (cancelled) return;
        setContext(nextContext);
        setSelectedAudienceKeys(
          nextContext.audiences.filter((item) => item.targetUserCount > 0).map((item) => item.key)
        );
      } catch (loadError) {
        if (cancelled) return;
        setError(loadError instanceof Error ? loadError.message : '加载通知受众失败');
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, [newsId]);

  const totalTargetUsers = useMemo(() => {
    if (!context) return 0;
    return context.audiences
      .filter((item) => selectedAudienceKeys.includes(item.key))
      .reduce((sum, item) => sum + item.targetUserCount, 0);
  }, [context, selectedAudienceKeys]);

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
    if (!selectedAudienceKeys.length) {
      setToast({ message: '请至少选择一类通知受众。', tone: 'warning' });
      return;
    }
    if (!availableChannels.length) {
      setToast({ message: '请至少选择一种发送渠道。', tone: 'warning' });
      return;
    }

    try {
      setPublishing(true);
      setError(null);
      const publishResult = await notificationCenterAdminApi.publishNewsNotification({
        newsId,
        audienceKeys: selectedAudienceKeys as Array<'event_news' | 'followed_dj_news' | 'followed_brand_news'>,
        channels: availableChannels,
      });
      setResult(publishResult);
      setToast({ message: '通知发送请求已完成。', tone: 'success' });
    } catch (publishError) {
      setError(publishError instanceof Error ? publishError.message : '通知发送失败');
      setToast({ message: '通知发送失败。', tone: 'error' });
    } finally {
      setPublishing(false);
    }
  };

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
            {mode === 'create' ? '资讯已保存，决定是否通知用户。' : '资讯已保存，仅在需要时发送通知。'}
          </h3>
          <p className="mt-3 max-w-3xl text-sm leading-6 text-black/52">
            这一步专门用于避免补录旧资讯时误发 APNS，同时保留在发布重要新资讯时手动推送给目标用户的能力。
          </p>
        </div>
      </div>

      {loading ? <div className="mt-5 text-sm text-black/48">正在加载通知受众...</div> : null}
      {error ? (
        <div className="mt-5 rounded-[24px] border border-[#f0d7d5] bg-[#fff7f6] px-4 py-3 text-sm text-[#8b3a3a]">
          {error}
        </div>
      ) : null}

      {context ? (
        <div className="mt-5 space-y-5">
          <div className="grid gap-4 md:grid-cols-[1.4fr_0.6fr]">
            <div className="rounded-[28px] border border-[#e7ece8] bg-[#f9fbfa] p-5">
              <div className="text-xs uppercase tracking-[0.24em] text-black/38">Article</div>
              <div className="mt-3 text-lg font-semibold text-[#071110]">{context.article.title}</div>
              <div className="mt-2 text-sm leading-6 text-black/58">{context.article.summary || '暂无摘要'}</div>
              <div className="mt-4 text-xs text-black/42">发布时间 {context.article.publishedAt}</div>
            </div>

            <div className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
              <div className="text-xs uppercase tracking-[0.24em] text-black/38">Target Snapshot</div>
              <div className="mt-3 text-3xl font-semibold text-[#071110]">{totalTargetUsers}</div>
              <div className="mt-2 text-sm text-black/56">当前选中受众的用户数</div>
            </div>
          </div>

          <div className="grid gap-4 lg:grid-cols-[1.3fr_0.7fr]">
            <div className="space-y-3">
              {context.audiences.map((audience) => {
                const checked = selectedAudienceKeys.includes(audience.key);
                const disabled = audience.targetUserCount <= 0;

                return (
                  <label
                    key={audience.key}
                    className={`flex cursor-pointer items-start gap-4 rounded-[24px] border px-5 py-4 transition ${
                      checked ? 'border-[#071110] bg-[#f5f7f6]' : 'border-[#e7ece8] bg-white'
                    } ${disabled ? 'cursor-not-allowed opacity-55' : ''}`}
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
                        {audience.entities.length ? (
                          audience.entities.map((entity) => (
                            <span
                              key={entity.id}
                              className="rounded-full border border-[#dde5e1] px-3 py-1 text-xs text-[#42514c]"
                            >
                              {entity.name} / {entity.targetUserCount}
                            </span>
                          ))
                        ) : (
                          <span className="text-xs text-black/42">当前没有可通知的绑定对象。</span>
                        )}
                      </div>
                    </div>
                  </label>
                );
              })}
            </div>

            <div className="space-y-4 rounded-[28px] border border-[#e7ece8] bg-[#fcfcfb] p-5">
              <div>
                <div className="text-xs uppercase tracking-[0.24em] text-black/38">Channels</div>
                <div className="mt-3 space-y-3">
                  <label className="flex items-center justify-between rounded-[18px] border border-[#e7ece8] bg-white px-4 py-3 text-sm text-[#071110]">
                    <span>站内通知</span>
                    <input type="checkbox" checked={sendInApp} onChange={(event) => setSendInApp(event.target.checked)} />
                  </label>
                  <label className="flex items-center justify-between rounded-[18px] border border-[#e7ece8] bg-white px-4 py-3 text-sm text-[#071110]">
                    <span>APNS 推送</span>
                    <input type="checkbox" checked={sendApns} onChange={(event) => setSendApns(event.target.checked)} />
                  </label>
                </div>
              </div>

              <button
                type="button"
                onClick={() => void handlePublish()}
                disabled={publishing || !selectedAudienceKeys.length || !availableChannels.length}
                className="inline-flex w-full items-center justify-center rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white disabled:opacity-45"
              >
                {publishing ? '发送中...' : '发送所选通知'}
              </button>

              <div className="text-xs leading-6 text-black/42">
                如果这里不执行发送，资讯会保持已保存状态，但不会新增任何用户通知。
              </div>
            </div>
          </div>

          {result ? (
            <div className="rounded-[28px] border border-[#dbe6dd] bg-[#f6fbf7] p-5">
              <div className="text-xs uppercase tracking-[0.24em] text-[#44614f]">Publish Result</div>
              <div className="mt-4 grid gap-3 md:grid-cols-3">
                {result.audiences.map((audience) => (
                  <div key={audience.key} className="rounded-[20px] border border-[#d8e5dc] bg-white px-4 py-4">
                    <div className="text-sm font-semibold text-[#071110]">
                      {AUDIENCE_LABELS[audience.key] || audience.label}
                    </div>
                    <div className="mt-2 text-xs leading-6 text-[#45604f]">
                      {audience.entityCount} 个绑定对象 / {audience.targetUserCount} 位用户
                    </div>
                    <div className="mt-3 text-xs leading-6 text-[#45604f]">
                      {audience.results.length} 个发送批次
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ) : null}
        </div>
      ) : null}
    </section>
  );
}
