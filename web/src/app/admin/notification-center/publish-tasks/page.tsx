'use client';

import { useCallback, useEffect, useState } from 'react';
import NotificationCenterWorkspaceLayout from '@/components/admin/NotificationCenterWorkspaceLayout';
import NotificationPublishCandidatesSection from '@/components/admin/NotificationPublishCandidatesSection';
import NotificationPublishTaskQueue from '@/components/admin/NotificationPublishTaskQueue';
import {
  notificationCenterAdminApi,
  type NotificationAdminPublishTaskPage,
} from '@/lib/api/notification-center-admin';

export default function NotificationCenterPublishTasksPage() {
  const [page, setPage] = useState<NotificationAdminPublishTaskPage | null>(null);
  const [loading, setLoading] = useState(true);
  const [listPage, setListPage] = useState(1);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async (nextPage: number) => {
    try {
      setLoading(true);
      setError(null);
      const result = await notificationCenterAdminApi.getPublishTasks({
        page: nextPage,
        limit: 12,
        status: 'pending',
      });
      setPage(result);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载发布任务失败');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load(listPage);
  }, [listPage, load]);

  return (
    <NotificationCenterWorkspaceLayout
      title="发布任务"
      description="所有成功页暂未当场决定的通知候选，都会留在这里统一处理。"
      actions={
        <button
          type="button"
          onClick={() => void load(listPage)}
          className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
        >
          刷新任务
        </button>
      }
    >
      {error ? (
        <section className="rounded-[24px] border border-[#f0d7d5] bg-[#fff7f6] px-4 py-3 text-sm text-[#8b3a3a]">
          {error}
        </section>
      ) : null}

      <section className="grid gap-6 xl:grid-cols-[0.88fr_1.12fr]">
        <div className="space-y-6">
          <NotificationPublishCandidatesSection page={page} loading={loading} />

          <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
            <div className="admin-studio-label">How It Works</div>
            <h2 className="mt-2 text-xl font-semibold text-[#071110]">处理逻辑</h2>
            <div className="mt-4 space-y-3 text-sm leading-6 text-[#5b6763]">
              <p>1. 内容创建或编辑成功后，如果没有当场决定是否发送 APNS，就会落到这里。</p>
              <p>2. 进入任务详情后，可以按受众、渠道决定是否发布。</p>
              <p>3. 拒绝发布后，任务会保留历史决策状态，但不会继续对用户触发通知。</p>
            </div>
          </section>
        </div>

        <NotificationPublishTaskQueue
          page={page}
          loading={loading}
          pageValue={listPage}
          onPageChange={setListPage}
          onReload={() => load(listPage)}
        />
      </section>
    </NotificationCenterWorkspaceLayout>
  );
}
