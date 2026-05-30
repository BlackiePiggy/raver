'use client';

import Link from 'next/link';
import { useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import EventStudioForm from '@/components/admin/EventStudioForm';
import {
  createEventStudioDraft,
  type EventStudioCreateResult,
  type EventStudioDraft,
} from '@/features/admin-content/event-studio';

export default function AdminContentEventCreatePage() {
  const [draft, setDraft] = useState<EventStudioDraft>(() => createEventStudioDraft());
  const [submitNotice, setSubmitNotice] = useState<string | null>(null);
  const [submitResultLink, setSubmitResultLink] = useState<string | null>(null);

  const handleSubmitResult = (result: EventStudioCreateResult) => {
    if (result.kind === 'created') {
      setSubmitNotice(`活动已创建成功：${result.event.name}`);
      setSubmitResultLink(`/events/${result.event.id}`);
      return;
    }
    setSubmitNotice(result.payload.message || '活动已进入审核队列');
    setSubmitResultLink('/my-publishes?type=event');
  };

  return (
    <AdminContentLayout
      title="新建活动"
      description="这里已经接上了 Event Studio 第一版可提交流程。当前版本先覆盖基础资料、时区、媒体与简单票务，并走统一 `/v1/events` 创建链路。"
      actions={
        <>
          <Link href="/admin/content/events" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回活动工作区
          </Link>
          <Link href="/admin/content/organizers/new" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            新建主办方
          </Link>
        </>
      }
    >
      {submitNotice ? (
        <section className="rounded-3xl border border-primary-blue/30 bg-primary-blue/10 p-4 text-sm text-text-primary">
          <div>{submitNotice}</div>
          {submitResultLink ? (
            <div className="mt-3">
              <Link href={submitResultLink} className="text-primary-blue hover:underline">
                打开结果页面
              </Link>
            </div>
          ) : null}
        </section>
      ) : null}

      <EventStudioForm mode="create" draft={draft} setDraft={setDraft} onSubmit={handleSubmitResult} />
    </AdminContentLayout>
  );
}
