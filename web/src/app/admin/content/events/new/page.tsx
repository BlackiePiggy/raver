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
      setSubmitNotice(`活动已直接创建成功：${result.event.name}`);
      setSubmitResultLink(`/admin/content/events/${result.event.id}/edit`);
      return;
    }
    setSubmitNotice(result.payload.message || '活动任务已提交，当前正在处理中，尚未等同于已直接入库。');
    setSubmitResultLink('/admin/content/reviews/submissions');
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
      {submitNotice ? (
        <section className="admin-studio-pastel-mint p-4 text-sm text-[#2f4027]">
          <div>{submitNotice}</div>
          {submitResultLink ? (
            <div className="mt-3">
              <Link href={submitResultLink} className="font-semibold text-[#071110] hover:underline">
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
