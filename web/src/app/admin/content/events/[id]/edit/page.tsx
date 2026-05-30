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
      setResultLink(`/events/${result.event.id}`);
      return;
    }
    setNotice(result.payload.message || '编辑提交已进入审核队列');
    setResultLink('/my-publishes?type=event');
  };

  return (
    <AdminContentLayout
      title={pageTitle}
      description="编辑态第一版已经接上活动详情加载、draft 回填和真实 PATCH 提交链路。下一轮会继续补 revision、冲突提示和更完整的 schedule/timetable 更新语义。"
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
      {notice ? (
        <section className="rounded-3xl border border-primary-blue/30 bg-primary-blue/10 p-4 text-sm text-text-primary">
          <div>{notice}</div>
          {resultLink ? (
            <div className="mt-3">
              <Link href={resultLink} className="text-primary-blue hover:underline">
                打开结果页面
              </Link>
            </div>
          ) : null}
        </section>
      ) : null}

      {loading ? (
        <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-6 text-sm text-text-secondary">
          正在加载活动详情并回填编辑表单...
        </section>
      ) : error ? (
        <section className="rounded-3xl border border-red-500/30 bg-red-500/10 p-6 text-sm text-red-200">
          {error}
        </section>
      ) : (
        <EventStudioForm mode="edit" eventId={eventId} draft={draft} setDraft={setDraft} onSubmit={handleSubmitResult} submitButtonText="提交活动编辑" />
      )}
    </AdminContentLayout>
  );
}
