'use client';

import Link from 'next/link';
import { Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import AdminPublishTaskActions from '@/components/admin/AdminPublishTaskActions';
import {
  resolveEventStudioSubmitResultContent,
  type EventStudioSubmitFlow,
  type EventStudioSubmitOutcome,
} from '@/features/admin-content/event-studio';

const isFlow = (value: string | null): value is EventStudioSubmitFlow => value === 'create' || value === 'edit';
const isOutcome = (value: string | null): value is EventStudioSubmitOutcome => value === 'created' || value === 'submitted';

function EventResultContent() {
  const searchParams = useSearchParams();
  const flowParam = searchParams.get('flow');
  const outcomeParam = searchParams.get('outcome');
  const eventId = searchParams.get('eventId');
  const eventName = searchParams.get('eventName');
  const submissionId = searchParams.get('submissionId');
  const message = searchParams.get('message');

  const flow: EventStudioSubmitFlow = isFlow(flowParam) ? flowParam : 'create';
  const outcome: EventStudioSubmitOutcome = isOutcome(outcomeParam) ? outcomeParam : 'submitted';
  const content = resolveEventStudioSubmitResultContent({
    flow,
    outcome,
    eventId,
    eventName,
    submissionId,
    message,
  });

  return (
    <AdminContentLayout
      title={content.title}
      description="提交结果页和 iOS 一样使用独立结果页，明确区分已直接入库成功与仍在处理中、等待审核的提交任务。"
      actions={
        <Link href="/admin/content/events/catalog" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
          返回活动目录
        </Link>
      }
    >
      <section className="admin-studio-section px-6 py-10">
        <div className="mx-auto flex max-w-3xl flex-col items-center text-center">
          <div className="flex h-24 w-24 items-center justify-center rounded-full bg-[#edf7f2]">
            <div className="flex h-14 w-14 items-center justify-center rounded-full bg-[#071110] text-3xl font-bold text-white">OK</div>
          </div>

          <h2 className="mt-8 text-3xl font-black tracking-[-0.05em] text-[#071110]">{content.title}</h2>
          <p className="mt-4 max-w-2xl text-sm leading-7 text-black/56">{content.message}</p>

          {eventName ? <div className="mt-6 rounded-full bg-[#f3f5f4] px-4 py-2 text-sm font-medium text-[#071110]">{eventName}</div> : null}
          {submissionId ? <div className="mt-3 text-xs text-black/42">Submission: {submissionId}</div> : null}

          <div className="mt-10 flex w-full max-w-xl flex-col gap-3 sm:flex-row sm:justify-center">
            <Link
              href={content.primaryHref}
              className="inline-flex min-h-12 items-center justify-center rounded-full bg-[#071110] px-6 py-3 text-sm font-semibold text-white"
            >
              {content.primaryLabel}
            </Link>
            <Link
              href={content.secondaryHref}
              className="inline-flex min-h-12 items-center justify-center rounded-full border border-[#d7ddda] bg-white px-6 py-3 text-sm font-semibold text-[#071110]"
            >
              {content.secondaryLabel}
            </Link>
          </div>
        </div>
      </section>

      {eventId && outcome === 'created' ? (
        <AdminPublishTaskActions
          taskType="event_release"
          entityType="event"
          entityId={eventId}
          mode={flow === 'create' ? 'create' : 'edit'}
        />
      ) : null}
    </AdminContentLayout>
  );
}

export default function AdminContentEventResultPage() {
  return (
    <Suspense
      fallback={
        <AdminContentLayout title="提交结果" description="正在整理提交结果...">
          <section className="admin-studio-section p-6 text-sm text-black/48">正在整理提交结果...</section>
        </AdminContentLayout>
      }
    >
      <EventResultContent />
    </Suspense>
  );
}
