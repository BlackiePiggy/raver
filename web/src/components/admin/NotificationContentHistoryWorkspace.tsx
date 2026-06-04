'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import AdminToast, { type AdminToastTone } from '@/components/admin/AdminToast';
import {
  notificationCenterAdminApi,
  type NotificationAdminContentHistoryDetailResponse,
  type NotificationAdminContentHistoryItem,
  type NotificationAdminContentHistoryPage,
  type NotificationAdminPublishTaskContext,
} from '@/lib/api/notification-center-admin';

type NotificationContentHistoryWorkspaceProps = {
  initialEntityType?: string;
  initialQuery?: string;
};

type ToastState = {
  message: string;
  tone: AdminToastTone;
} | null;

const ENTITY_TABS = [
  { key: 'all', label: '全部' },
  { key: 'event', label: '活动' },
  { key: 'dj', label: 'DJ' },
  { key: 'news_article', label: '资讯' },
  { key: 'label', label: '厂牌' },
  { key: 'festival', label: '主办方' },
] as const;

const PUSH_STATUS_LABELS: Record<string, string> = {
  pending: '待推送',
  published: '已推送',
  skipped: '无需推送',
  superseded: '已被后续更新覆盖',
  not_applicable: '不适用',
};

const RESULT_STATUS_LABELS: Record<string, string> = {
  success: '成功',
  failed: '失败',
};

const TASK_TYPE_LABELS: Record<string, string> = {
  news_release: '资讯通知',
  event_release: '活动通知',
  dj_release: 'DJ 通知',
  brand_release: '品牌通知',
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

export default function NotificationContentHistoryWorkspace({
  initialEntityType,
  initialQuery,
}: NotificationContentHistoryWorkspaceProps) {
  const [entityType, setEntityType] = useState(initialEntityType || 'all');
  const [search, setSearch] = useState(initialQuery || '');
  const [searchDraft, setSearchDraft] = useState(initialQuery || '');
  const [pageValue, setPageValue] = useState(1);
  const [page, setPage] = useState<NotificationAdminContentHistoryPage | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detail, setDetail] = useState<NotificationAdminContentHistoryDetailResponse | null>(null);
  const [selectedAudienceKeys, setSelectedAudienceKeys] = useState<string[]>([]);
  const [sendInApp, setSendInApp] = useState(true);
  const [sendApns, setSendApns] = useState(true);
  const [acting, setActing] = useState<'publish' | 'skip' | null>(null);
  const [toast, setToast] = useState<ToastState>(null);

  const loadPage = useCallback(async (nextPage: number, nextEntityType: string, nextQuery: string) => {
    try {
      setLoading(true);
      setError(null);
      const result = await notificationCenterAdminApi.getContentHistory({
        page: nextPage,
        limit: 12,
        entityType: nextEntityType === 'all' ? undefined : nextEntityType,
        query: nextQuery || undefined,
      });
      setPage(result);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载内容历史失败');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadPage(pageValue, entityType, search);
  }, [entityType, loadPage, pageValue, search]);

  useEffect(() => {
    if (!selectedId) {
      setDetail(null);
      setSelectedAudienceKeys([]);
      return;
    }

    let cancelled = false;
    const loadDetail = async () => {
      try {
        setDetailLoading(true);
        const result = await notificationCenterAdminApi.getContentHistoryDetail(selectedId);
        if (cancelled) return;
        setDetail(result);
        setSelectedAudienceKeys(
          (result.context?.audiences ?? [])
            .filter((item) => item.targetUserCount > 0)
            .map((item) => item.key)
        );
      } catch (loadError) {
        if (cancelled) return;
        setToast({ message: loadError instanceof Error ? loadError.message : '加载详情失败', tone: 'error' });
      } finally {
        if (!cancelled) setDetailLoading(false);
      }
    };

    void loadDetail();
    return () => {
      cancelled = true;
    };
  }, [selectedId]);

  const selectedItem = useMemo<NotificationAdminContentHistoryItem | null>(
    () => page?.items.find((item) => item.id === selectedId) ?? null,
    [page?.items, selectedId]
  );

  const totalTargetUsers = useMemo(() => {
    const audiences = detail?.context?.audiences ?? [];
    return audiences
      .filter((item) => selectedAudienceKeys.includes(item.key))
      .reduce((sum, item) => sum + item.targetUserCount, 0);
  }, [detail?.context?.audiences, selectedAudienceKeys]);

  const channels = useMemo(() => {
    const next: Array<'in_app' | 'apns'> = [];
    if (sendInApp) next.push('in_app');
    if (sendApns) next.push('apns');
    return next;
  }, [sendApns, sendInApp]);

  const handlePublish = async () => {
    if (!detail?.task) return;
    if (!selectedAudienceKeys.length) {
      setToast({ message: '请至少选择一类受众', tone: 'warning' });
      return;
    }
    if (!channels.length) {
      setToast({ message: '请至少选择一种发送渠道', tone: 'warning' });
      return;
    }
    try {
      setActing('publish');
      await notificationCenterAdminApi.publishTask({
        taskId: detail.task.id,
        audienceKeys: selectedAudienceKeys,
        channels,
      });
      setToast({ message: '推送已发布', tone: 'success' });
      await loadPage(pageValue, entityType, search);
      if (selectedId) {
        const nextDetail = await notificationCenterAdminApi.getContentHistoryDetail(selectedId);
        setDetail(nextDetail);
      }
    } catch (actionError) {
      setToast({ message: actionError instanceof Error ? actionError.message : '推送失败', tone: 'error' });
    } finally {
      setActing(null);
    }
  };

  const handleSkip = async () => {
    if (!selectedItem) return;
    try {
      setActing('skip');
      await notificationCenterAdminApi.skipContentHistory({ historyId: selectedItem.id });
      setToast({ message: '已标记为无需推送', tone: 'success' });
      await loadPage(pageValue, entityType, search);
      if (selectedId) {
        const nextDetail = await notificationCenterAdminApi.getContentHistoryDetail(selectedId);
        setDetail(nextDetail);
      }
    } catch (actionError) {
      setToast({ message: actionError instanceof Error ? actionError.message : '处理失败', tone: 'error' });
    } finally {
      setActing(null);
    }
  };

  const detailContext: NotificationAdminPublishTaskContext | null = detail?.context ?? null;
  const canPublish =
    selectedItem?.resultStatus === 'success' &&
    selectedItem.pushStatus === 'pending' &&
    Boolean(detail?.task && detailContext);

  return (
    <section className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
      <AdminToast
        message={toast?.message || null}
        tone={toast?.tone || 'neutral'}
        visible={Boolean(toast?.message)}
        onClose={() => setToast(null)}
      />

      <div className="space-y-6">
        <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
          <div className="admin-studio-label">Content History</div>
          <h2 className="mt-2 text-xl font-semibold text-[#071110]">统一内容历史</h2>
          <p className="mt-2 text-sm leading-6 text-[#5b6763]">
            所有后台成功入库或失败的内容操作，都会在这里留档。成功项可以继续决定是否推送；已推送的投递结果会继续沉淀到通知中心投递历史。
          </p>

          <div className="mt-5 flex flex-wrap gap-2">
            {ENTITY_TABS.map((tab) => {
              const active = tab.key === entityType;
              return (
                <button
                  key={tab.key}
                  type="button"
                  onClick={() => {
                    setEntityType(tab.key);
                    setPageValue(1);
                    setSelectedId(null);
                  }}
                  className={`rounded-full px-4 py-2 text-sm font-semibold ${
                    active ? 'bg-[#071110] text-white' : 'border border-[#d9e1de] bg-white text-[#071110]'
                  }`}
                >
                  {tab.label}
                </button>
              );
            })}
          </div>

          <form
            className="mt-4 flex gap-3"
            onSubmit={(event) => {
              event.preventDefault();
              setSearch(searchDraft.trim());
              setPageValue(1);
              setSelectedId(null);
            }}
          >
            <input
              value={searchDraft}
              onChange={(event) => setSearchDraft(event.target.value)}
              placeholder="按标题或对象 ID 搜索"
              className="min-w-0 flex-1 rounded-full border border-[#d9e1de] px-4 py-3 text-sm text-[#071110]"
            />
            <button
              type="submit"
              className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
            >
              搜索
            </button>
          </form>
        </section>

        <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
          <div className="flex items-center justify-between gap-4">
            <div>
              <div className="admin-studio-label">Records</div>
              <h3 className="mt-2 text-lg font-semibold text-[#071110]">历史记录列表</h3>
            </div>
            <div className="text-sm text-[#5b6763]">
              {page ? `共 ${page.pagination.total.toLocaleString()} 条` : '加载中'}
            </div>
          </div>

          <div className="mt-5 space-y-3">
            {loading ? (
              <div className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] px-4 py-4 text-sm text-[#5b6763]">
                正在加载内容历史...
              </div>
            ) : error ? (
              <div className="rounded-[20px] border border-[#f0d7d5] bg-[#fff7f6] px-4 py-4 text-sm text-[#8b3a3a]">
                {error}
              </div>
            ) : page?.items.length ? (
              page.items.map((item) => {
                const active = item.id === selectedId;
                return (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() => setSelectedId(item.id)}
                    className={`block w-full rounded-[20px] border px-4 py-4 text-left ${
                      active ? 'border-[#071110] bg-[#f7f8f7]' : 'border-[#edf1ef] bg-[#fbfcfb]'
                    }`}
                  >
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div className="min-w-0">
                        <div className="text-sm font-semibold text-[#071110]">{item.title}</div>
                        <div className="mt-1 text-xs text-[#5b6763]">
                          {item.entityType} / {item.operationType} / {RESULT_STATUS_LABELS[item.resultStatus] || item.resultStatus}
                        </div>
                        {item.summary ? <div className="mt-2 text-sm text-[#5b6763]">{item.summary}</div> : null}
                        {item.errorMessage ? (
                          <div className="mt-2 text-sm text-[#8b3a3a]">{item.errorMessage}</div>
                        ) : null}
                      </div>
                      <div className="flex flex-wrap gap-2">
                        <span className="rounded-full bg-[#eef2ef] px-3 py-1 text-[11px] font-semibold text-[#42514c]">
                          {PUSH_STATUS_LABELS[item.pushStatus] || item.pushStatus}
                        </span>
                        {item.taskType ? (
                          <span className="rounded-full bg-[#f3f5f4] px-3 py-1 text-[11px] font-semibold text-[#42514c]">
                            {TASK_TYPE_LABELS[item.taskType] || item.taskType}
                          </span>
                        ) : null}
                      </div>
                    </div>
                  </button>
                );
              })
            ) : (
              <div className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] px-4 py-4 text-sm text-[#5b6763]">
                当前筛选下还没有内容历史。
              </div>
            )}
          </div>

          {page && page.pagination.totalPages > 1 ? (
            <div className="mt-5 flex items-center gap-2">
              <button
                type="button"
                disabled={page.pagination.page <= 1}
                onClick={() => setPageValue((current) => Math.max(1, current - 1))}
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
                onClick={() => setPageValue((current) => Math.min(page.pagination.totalPages, current + 1))}
                className="rounded-full border border-[#d9e1de] bg-white px-4 py-2 text-sm font-semibold text-[#071110] disabled:opacity-45"
              >
                下一页
              </button>
            </div>
          ) : null}
        </section>
      </div>

      <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
        <div className="admin-studio-label">Detail</div>
        <h2 className="mt-2 text-xl font-semibold text-[#071110]">记录详情</h2>

        {!selectedItem ? (
          <div className="mt-5 rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] px-4 py-4 text-sm text-[#5b6763]">
            选择左侧一条记录后，可以查看详情并决定是否推送。
          </div>
        ) : detailLoading ? (
          <div className="mt-5 rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] px-4 py-4 text-sm text-[#5b6763]">
            正在加载详情...
          </div>
        ) : (
          <div className="mt-5 space-y-4">
            <div className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <div className="text-base font-semibold text-[#071110]">{selectedItem.title}</div>
                  <div className="mt-1 text-sm text-[#5b6763]">
                    {selectedItem.entityType}
                    {selectedItem.entityId ? ` / ${selectedItem.entityId}` : ''}
                    {selectedItem.sourceRoute ? ` / ${selectedItem.sourceRoute}` : ''}
                  </div>
                </div>
                <span className="rounded-full bg-[#eef2ef] px-3 py-1 text-[11px] font-semibold text-[#42514c]">
                  {PUSH_STATUS_LABELS[selectedItem.pushStatus] || selectedItem.pushStatus}
                </span>
              </div>
              {selectedItem.summary ? <div className="mt-3 text-sm leading-6 text-[#5b6763]">{selectedItem.summary}</div> : null}
              {selectedItem.errorMessage ? (
                <div className="mt-3 rounded-[16px] border border-[#f0d7d5] bg-[#fff7f6] px-3 py-3 text-sm text-[#8b3a3a]">
                  {selectedItem.errorMessage}
                </div>
              ) : null}
            </div>

            {detailContext ? (
              <>
                <div className="grid gap-4 md:grid-cols-[1.25fr_0.75fr]">
                  <div className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
                    <div className="text-xs uppercase tracking-[0.14em] text-black/38">Preview</div>
                    <div className="mt-2 text-base font-semibold text-[#071110]">{detailContext.entity.title}</div>
                    <div className="mt-2 text-sm leading-6 text-[#5b6763]">
                      {detailContext.entity.summary || '暂无摘要'}
                    </div>
                  </div>
                  <div className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
                    <div className="text-xs uppercase tracking-[0.14em] text-black/38">Audience</div>
                    <div className="mt-2 text-3xl font-semibold text-[#071110]">{totalTargetUsers}</div>
                    <div className="mt-1 text-sm text-[#5b6763]">当前选中用户数</div>
                  </div>
                </div>

                <div className="space-y-3">
                  {detailContext.audiences.map((audience) => {
                    const checked = selectedAudienceKeys.includes(audience.key);
                    const disabled = audience.targetUserCount <= 0 || !canPublish;
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
                          onChange={() =>
                            setSelectedAudienceKeys((current) =>
                              current.includes(audience.key)
                                ? current.filter((item) => item !== audience.key)
                                : [...current, audience.key]
                            )
                          }
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
                        </div>
                      </label>
                    );
                  })}
                </div>

                <div className="grid gap-3 md:grid-cols-2">
                  <label className="flex items-center justify-between rounded-[18px] border border-[#e7ece8] bg-white px-4 py-3 text-sm text-[#071110]">
                    <span>站内通知</span>
                    <input
                      type="checkbox"
                      checked={sendInApp}
                      disabled={!canPublish}
                      onChange={(event) => setSendInApp(event.target.checked)}
                    />
                  </label>
                  <label className="flex items-center justify-between rounded-[18px] border border-[#e7ece8] bg-white px-4 py-3 text-sm text-[#071110]">
                    <span>APNS 推送</span>
                    <input
                      type="checkbox"
                      checked={sendApns}
                      disabled={!canPublish}
                      onChange={(event) => setSendApns(event.target.checked)}
                    />
                  </label>
                </div>
              </>
            ) : null}

            <div className="flex flex-wrap gap-3">
              <button
                type="button"
                onClick={() => void handlePublish()}
                disabled={!canPublish || acting !== null}
                className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white disabled:opacity-45"
              >
                {acting === 'publish' ? '推送中...' : '一键推送'}
              </button>
              <button
                type="button"
                onClick={() => void handleSkip()}
                disabled={selectedItem.pushStatus !== 'pending' || acting !== null}
                className="rounded-full border border-[#d9e1de] bg-white px-5 py-3 text-sm font-semibold text-[#071110] disabled:opacity-45"
              >
                {acting === 'skip' ? '处理中...' : '标记无需推送'}
              </button>
              {selectedItem.pushStatus === 'published' ? (
                <Link
                  href="/admin/notification-center/deliveries"
                  className="rounded-full border border-[#d9e1de] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
                >
                  查看通知中心投递历史
                </Link>
              ) : null}
            </div>
          </div>
        )}
      </section>
    </section>
  );
}
