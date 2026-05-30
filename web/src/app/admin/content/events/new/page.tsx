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
      setSubmitResultLink(`/admin/content/events/${result.event.id}/edit`);
      return;
    }
    setSubmitNotice(result.payload.message || '活动已进入审核队列');
    setSubmitResultLink('/admin/content/reviews/submissions');
  };

  return (
    <AdminContentLayout
      title="新建活动"
      description="在统一后台内完成活动资料创建、主办方绑定、时区确认、时间表录入和素材上传。当前页面已经作为正式的活动创建入口使用。"
      actions={
        <>
          <Link href="/admin/content/events" className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-4 py-2 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
            返回活动工作区
          </Link>
          <Link href="/admin/content/events/catalog" className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-4 py-2 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
            活动目录中心
          </Link>
          <Link href="/admin/content/organizers/new" className="rounded-xl bg-[#a8ff3e] px-4 py-2 text-sm font-semibold text-black">
            新建主办方
          </Link>
        </>
      }
    >
      {submitNotice ? (
        <section className="rounded-[18px] border border-[rgba(168,255,62,0.22)] bg-[linear-gradient(180deg,rgba(168,255,62,0.12),rgba(168,255,62,0.04))] p-4 text-sm text-[#d9ff9a]">
          <div>{submitNotice}</div>
          {submitResultLink ? (
            <div className="mt-3">
              <Link href={submitResultLink} className="text-[#f0f0f0] hover:text-white hover:underline">
                继续进入结果页面
              </Link>
            </div>
          ) : null}
        </section>
      ) : null}

      <EventStudioForm mode="create" draft={draft} setDraft={setDraft} onSubmit={handleSubmitResult} />
    </AdminContentLayout>
  );
}
