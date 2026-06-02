'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import EventStudioForm from '@/components/admin/EventStudioForm';
import {
  buildEventStudioSubmitResultHref,
  createEventStudioDraft,
  type EventStudioCreateResult,
  type EventStudioDraft,
} from '@/features/admin-content/event-studio';

export default function AdminContentEventCreatePage() {
  const router = useRouter();
  const [draft, setDraft] = useState<EventStudioDraft>(() => createEventStudioDraft());

  const handleSubmitResult = (result: EventStudioCreateResult) => {
    if (result.kind === 'created') {
      router.replace(
        buildEventStudioSubmitResultHref({
          flow: 'create',
          outcome: 'created',
          eventId: result.event.id,
          eventName: result.event.name,
        })
      );
      return;
    }

    router.replace(
      buildEventStudioSubmitResultHref({
        flow: 'create',
        outcome: 'submitted',
        submissionId: result.payload.submission.id,
        message: result.payload.message,
      })
    );
  };

  return (
    <AdminContentLayout
      title="新建活动"
      description="在统一后台内完成活动资料创建、主办方绑定、时区确认、时间表录入和素材上传。"
      actions={
        <>
          <Link href="/admin/content/events" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            返回活动工作区
          </Link>
          <Link href="/admin/content/events/catalog" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            活动目录中心
          </Link>
          <Link href="/admin/content/organizers/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            新建主办方
          </Link>
        </>
      }
    >
      <EventStudioForm mode="create" draft={draft} setDraft={setDraft} onSubmit={handleSubmitResult} />
    </AdminContentLayout>
  );
}
