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
      <section className="admin-studio-section p-6">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <div className="admin-studio-label">Event Studio / {mode === 'create' ? 'Create' : 'Edit'}</div>
            <h2 className="mt-2 text-2xl font-semibold text-[#071110]">{mode === 'create' ? '新建活动' : '编辑活动'}脚手架</h2>
            <p className="mt-3 max-w-3xl text-sm leading-6 text-black/52">
              这里是接入新 Event Studio 的正式路由。下一阶段会把 iOS `EventUploadFlow` 对应的 draft、validation、mapper、media upload 和 `/v1/events` 提交链路接进来。
            </p>
          </div>
          {eventId ? (
            <div className="admin-studio-soft px-4 py-3 text-sm">
              Event ID: <span className="font-semibold">{eventId}</span>
            </div>
          ) : null}
        </div>

        <div className="mt-6 grid gap-3 md:grid-cols-2">
          {STEP_ITEMS.map((step, index) => (
            <div key={step} className="admin-studio-soft px-4 py-3 text-sm leading-6">
              <div className="admin-studio-label">Step {index + 1}</div>
              <div className="mt-1 font-semibold text-[#071110]">{step}</div>
            </div>
          ))}
        </div>
      </section>

      <div className="space-y-5">
        <section className="admin-studio-pastel-sand p-6">
          <div className="admin-studio-label">Next Build Items</div>
          <h2 className="mt-2 text-2xl font-semibold text-[#071110]">下一步接入</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-black/52">
            <p>1. 抽 Event Studio draft、validation、mapper、media orchestration。</p>
            <p>2. 对齐 iOS 的 `schedule`、`weeks`、`eventDays`、`lineupSlots` 与时区语义。</p>
            <p>3. 接入 `/v1/events`、`/v1/event-timezones/search`、`/v1/events/upload-image`。</p>
          </div>
        </section>

        <section className="admin-studio-section p-6">
          <div className="admin-studio-label">Legacy Links</div>
          <h2 className="mt-2 text-2xl font-semibold text-[#071110]">迁移期参考入口</h2>
          <div className="mt-4 flex flex-col gap-3">
            <Link href="/events/publish" className="admin-studio-button-secondary px-4 py-3 text-sm">
              查看旧活动发布页
            </Link>
            <Link href="/admin/festival-viewer.html#archive" className="admin-studio-button-secondary px-4 py-3 text-sm">
              打开旧 Archive / Event Tooling
            </Link>
          </div>
        </section>
      </div>
    </div>
  );
}
