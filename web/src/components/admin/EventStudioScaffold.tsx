'use client';

import Link from 'next/link';

type EventStudioScaffoldProps = {
  mode: 'create' | 'edit';
  eventId?: string;
};

const STEP_ITEMS = [
  '媒体与图片分区',
  '基础信息',
  '时间与时区',
  '地点与地图',
  '时间表',
  '仅阵容',
  '票务与提交',
];

export default function EventStudioScaffold({ mode, eventId }: EventStudioScaffoldProps) {
  return (
    <div className="grid gap-5 xl:grid-cols-[1.35fr_1fr]">
      <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <div className="text-sm text-text-secondary">Event Studio / {mode === 'create' ? 'Create' : 'Edit'}</div>
            <h2 className="mt-2 text-2xl font-semibold">{mode === 'create' ? '新建活动' : '编辑活动'}脚手架</h2>
            <p className="mt-3 max-w-3xl text-sm leading-6 text-text-secondary">
              这里是接入新 Event Studio 的正式路由。下一阶段会把 iOS `EventUploadFlow` 对应的 draft、validation、mapper、media upload 和 `/v1/events` 提交链路接进来。
            </p>
          </div>
          {eventId ? (
            <div className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm">
              Event ID: <span className="font-semibold">{eventId}</span>
            </div>
          ) : null}
        </div>

        <div className="mt-6 grid gap-3 md:grid-cols-2">
          {STEP_ITEMS.map((step, index) => (
            <div key={step} className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm leading-6">
              <div className="text-xs uppercase tracking-[0.18em] text-text-secondary">Step {index + 1}</div>
              <div className="mt-1 font-semibold text-text-primary">{step}</div>
            </div>
          ))}
        </div>
      </section>

      <div className="space-y-5">
        <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Next Build Items</div>
          <h2 className="mt-2 text-2xl font-semibold">下一步接入</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>1. 抽 Event Studio draft、validation、mapper、media orchestration。</p>
            <p>2. 对齐 iOS 的 `schedule`、`weeks`、`eventDays`、`lineupSlots` 与时区语义。</p>
            <p>3. 接入 `/v1/events`、`/v1/event-timezones/search`、`/v1/events/upload-image`。</p>
          </div>
        </section>

        <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Legacy Links</div>
          <h2 className="mt-2 text-2xl font-semibold">迁移期参考入口</h2>
          <div className="mt-4 flex flex-col gap-3">
            <Link href="/events/publish" className="rounded-2xl border border-border-secondary px-4 py-3 text-sm hover:border-primary-blue hover:text-primary-blue">
              查看旧活动发布页
            </Link>
            <Link href="/admin/festival-viewer.html#archive" className="rounded-2xl border border-border-secondary px-4 py-3 text-sm hover:border-primary-blue hover:text-primary-blue">
              打开旧 Archive / Event Tooling
            </Link>
          </div>
        </section>
      </div>
    </div>
  );
}
