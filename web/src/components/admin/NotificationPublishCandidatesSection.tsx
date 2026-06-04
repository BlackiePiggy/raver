'use client';

import type { NotificationAdminPublishTaskPage } from '@/lib/api/notification-center-admin';

type NotificationPublishCandidatesSectionProps = {
  page: NotificationAdminPublishTaskPage | null;
  loading: boolean;
};

const TASK_TYPE_LABELS: Record<string, string> = {
  news_release: '资讯发布候选',
  event_release: '活动发布候选',
  dj_release: 'DJ 资料发布候选',
  brand_release: '品牌资料发布候选',
};

export default function NotificationPublishCandidatesSection({
  page,
  loading,
}: NotificationPublishCandidatesSectionProps) {
  const items = page?.items ?? [];

  return (
    <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <div className="admin-studio-label">Pending Candidates</div>
          <h2 className="mt-2 text-xl font-semibold text-[#071110]">待处理发布候选项</h2>
          <div className="mt-2 text-sm text-[#5b6763]">
            这里承接那些没有在内容成功页当场决定是否发送 APNS 的内容。你可以稍后回到这里，再进入下方任务队列统一处理。
          </div>
        </div>
        <div className="rounded-full bg-[#f3f5f4] px-4 py-2 text-xs font-semibold text-[#42514c]">
          {page ? `${page.pagination.total.toLocaleString()} 条候选` : '同步中'}
        </div>
      </div>

      <div className="mt-5 space-y-3">
        {loading ? (
          <div className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] px-4 py-4 text-sm text-[#5b6763]">
            正在加载待处理候选项...
          </div>
        ) : items.length ? (
          items.slice(0, 6).map((task) => (
            <div
              key={task.id}
              className="flex flex-wrap items-start justify-between gap-3 rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] px-4 py-4"
            >
              <div className="min-w-0">
                <div className="text-sm font-semibold text-[#071110]">{task.title}</div>
                <div className="mt-1 text-xs text-[#5b6763]">
                  {TASK_TYPE_LABELS[task.taskType] || task.taskType} / {task.entityType}
                </div>
                {task.summary ? <div className="mt-2 text-sm text-[#5b6763]">{task.summary}</div> : null}
              </div>
              <div className="flex items-center gap-2">
                <span className="rounded-full bg-[#eef2ef] px-3 py-1 text-[11px] font-semibold text-[#42514c]">
                  {task.status}
                </span>
                <a
                  href="#notification-publish-task-queue"
                  className="rounded-full border border-[#d9e1de] bg-white px-4 py-2 text-sm font-semibold text-[#071110]"
                >
                  去处理
                </a>
              </div>
            </div>
          ))
        ) : (
          <div className="rounded-[20px] border border-[#edf1ef] bg-[#fbfcfb] px-4 py-4 text-sm text-[#5b6763]">
            当前没有待处理发布候选项。
          </div>
        )}
      </div>
    </section>
  );
}
