'use client';

import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import EventStudioForm from '@/components/admin/EventStudioForm';
import {
  createEventStudioDraft,
  eventStudioApi,
  hydrateEventStudioDraftFromEvent,
  type EventStudioCreateResult,
  type EventStudioDraft,
} from '@/features/admin-content/event-studio';

export default function AdminContentEventEditPage() {
  const params = useParams<{ id: string }>();
  const eventId = typeof params?.id === 'string' ? params.id : '';
  const [draft, setDraft] = useState<EventStudioDraft>(() => createEventStudioDraft());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [resultLink, setResultLink] = useState<string | null>(null);

  useEffect(() => {
    if (!eventId) {
      setError('缺少活动 ID');
      setLoading(false);
      return;
    }

    let cancelled = false;
    const load = async () => {
      try {
        setLoading(true);
        setError(null);
        const event = await eventStudioApi.fetchEvent(eventId);
        if (cancelled) return;
        setDraft(hydrateEventStudioDraftFromEvent(event));
      } catch (loadError) {
        if (cancelled) return;
        setError(loadError instanceof Error ? loadError.message : '加载活动失败');
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, [eventId]);

  const pageTitle = useMemo(() => (draft.name.zh || draft.name.en || '编辑活动'), [draft.name.en, draft.name.zh]);

  const handleSubmitResult = (result: EventStudioCreateResult) => {
    if (result.kind === 'created') {
      setNotice(`活动编辑已提交成功：${result.event.name}`);
      setResultLink(`/admin/content/events/${result.event.id}/edit`);
      return;
    }
    setNotice(result.payload.message || '编辑提交已进入审核队列');
    setResultLink('/admin/content/reviews/submissions');
  };

  return (
    <AdminContentLayout
      title={pageTitle}
      description="统一后台中的活动编辑页会直接加载正式活动资料，支持结构化活动日、时间表、图片替换与主办方绑定更新。"
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
      {notice ? (
        <section className="admin-studio-pastel-mint p-4 text-sm text-[#2f4027]">
          <div>{notice}</div>
          {resultLink ? (
            <div className="mt-3">
              <Link href={resultLink} className="font-semibold text-[#071110] hover:underline">
                继续进入结果页面
              </Link>
            </div>
          ) : null}
        </section>
      ) : null}

      {loading ? (
        <section className="admin-studio-section p-6 text-sm text-black/48">
          正在加载活动详情并回填编辑表单...
        </section>
      ) : error ? (
        <section className="admin-studio-pastel-rose p-6 text-sm text-[#6a3530]">
          {error}
        </section>
      ) : (
        <EventStudioForm mode="edit" eventId={eventId} draft={draft} setDraft={setDraft} onSubmit={handleSubmitResult} submitButtonText="提交活动编辑" />
      )}
    </AdminContentLayout>
  );
}
