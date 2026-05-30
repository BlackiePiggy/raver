'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

const EVENT_PHASE_ITEMS = [
  'Event Studio create/edit 已接上统一 /v1 提交链路',
  '活动时区搜索、主办方绑定、封面和阵容图上传已可用',
  '旧 /events/publish 与 /events/my/[id]/edit 已迁移到统一后台入口',
  '下一批继续补 schedule、weeks、eventDays、revision conflict 和 richer timetable',
];

export default function AdminContentEventsPage() {
  return (
    <AdminContentLayout
      title="活动工作区"
      description="这里承接 Web 端活动创建与编辑的统一主线。当前 Event Studio 第一版已经可新建、可编辑，并与 `/v1/events`、`/v1/event-timezones/search`、`/v1/events/upload-image` 对齐。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回内容总览
          </Link>
          <Link href="/admin/content/events/catalog" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            活动目录中心
          </Link>
          <Link href="/admin/content/events/new" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
            新建活动
          </Link>
          <Link href="/admin/content/organizers/new" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            新建主办方
          </Link>
        </>
      }
    >
      <section className="grid gap-5 xl:grid-cols-[1.4fr_1fr]">
        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Implementation Track</div>
          <h2 className="mt-2 text-2xl font-semibold">Event Studio 第一阶段任务</h2>
          <div className="mt-5 space-y-3">
            {EVENT_PHASE_ITEMS.map((item, index) => (
              <div key={item} className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm leading-6">
                {index + 1}. {item}
              </div>
            ))}
          </div>
        </div>

        <div className="space-y-5">
        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Native Closure</div>
          <h2 className="mt-2 text-2xl font-semibold">当前已可原生闭环</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>活动目录中心、活动新建和活动编辑已经在统一后台内收口，当前可以直接完成主要资料、时区、主办方绑定和媒体上传的原生管理流程。</p>
            <p>与 iOS 相比，剩余差距集中在更深的 schedule/weeks/eventDays、revision conflict 和更完整的 lineup/timetable 语义，后续会继续在统一后台内部补齐。</p>
          </div>
        </div>

          <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
            <div className="text-sm text-text-secondary">Next Step</div>
            <h2 className="mt-2 text-2xl font-semibold">下一步</h2>
            <p className="mt-3 text-sm leading-6 text-text-secondary">
              下一批代码会优先补更完整的 schedule / weeks / eventDays，并把 Organizer Studio 的创建绑定能力进一步嵌入活动编辑流程。
            </p>
          </div>

          <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
            <div className="text-sm text-text-secondary">Catalog Center</div>
            <h2 className="mt-2 text-2xl font-semibold">全量活动目录已收口</h2>
            <p className="mt-3 text-sm leading-6 text-text-secondary">
              统一后台现在已经提供活动目录中心，默认通过分页摘要、本地 TTL 快照和手动刷新来查看全量活动，不再需要每次都去分散页面里重打全量数据。
            </p>
            <div className="mt-4">
              <Link href="/admin/content/events/catalog" className="text-sm font-semibold text-primary-blue hover:underline">
                打开活动目录中心
              </Link>
            </div>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
