'use client';

import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import NotificationContentHistoryPrompt from '@/components/admin/NotificationContentHistoryPrompt';
import OrganizerStudioForm from '@/components/admin/OrganizerStudioForm';
import {
  createOrganizerStudioDraft,
  hydrateOrganizerStudioDraftFromOrganizer,
  organizerStudioApi,
  type OrganizerStudioCreateResult,
  type OrganizerStudioDraft,
} from '@/features/admin-content/organizer-studio';

export default function AdminContentOrganizerEditPage() {
  const params = useParams<{ id: string }>();
  const organizerId = typeof params?.id === 'string' ? params.id : '';
  const [draft, setDraft] = useState<OrganizerStudioDraft>(() => createOrganizerStudioDraft());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [resultLink, setResultLink] = useState<string | null>(null);
  const [savedOrganizerId, setSavedOrganizerId] = useState<string | null>(null);

  useEffect(() => {
    if (!organizerId) {
      setError('缺少主办方 ID');
      setLoading(false);
      return;
    }

    let cancelled = false;
    const load = async () => {
      try {
        setLoading(true);
        setError(null);
        const organizer = await organizerStudioApi.fetchOrganizer(organizerId);
        if (cancelled) return;
        setDraft(hydrateOrganizerStudioDraftFromOrganizer(organizer));
        setSavedOrganizerId(organizerId);
      } catch (loadError) {
        if (cancelled) return;
        setError(loadError instanceof Error ? loadError.message : '加载主办方失败');
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
  }, [organizerId]);

  const pageTitle = useMemo(() => draft.name.zh || draft.name.en || '编辑主办方', [draft.name.en, draft.name.zh]);

  const handleSubmitResult = (result: OrganizerStudioCreateResult) => {
    if (result.kind === 'created') {
      setNotice(`主办方更新已提交成功：${result.organizer.name}`);
      setResultLink(`/admin/content/organizers/${result.organizer.id}/edit`);
      setSavedOrganizerId(result.organizer.id);
      return;
    }
    setNotice(result.payload.message || '主办方编辑已进入审核队列');
    setResultLink('/admin/content/reviews');
    setSavedOrganizerId(null);
  };

  return (
    <AdminContentLayout
      title={pageTitle}
      description="编辑态第一版已经接上主办方详情加载、draft 回填和真实 PATCH 提交链路。下一轮会继续补 event binding、revision diff 和更细的媒体生命周期。"
      actions={
        <>
          <Link
            href="/admin/content/organizers/catalog"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            返回主办方目录
          </Link>
          <Link
            href="/admin/content/events/catalog"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            打开活动目录
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
                打开结果页面
              </Link>
            </div>
          ) : null}
        </section>
      ) : null}

      {notice && savedOrganizerId ? (
        <NotificationContentHistoryPrompt
          entityType="festival"
          entityId={savedOrganizerId}
          secondaryHref="/admin/content/organizers/catalog"
          secondaryLabel="稍后处理，先回到主办方目录"
          description="这次主办方资料更新已经直接保存成功。你可以现在去统一内容历史页继续决定是否推送，也可以稍后再处理。"
        />
      ) : null}

      {loading ? (
        <section className="admin-studio-section p-6 text-sm text-black/48">正在加载主办方详情并回填编辑表单...</section>
      ) : error ? (
        <section className="admin-studio-pastel-rose p-6 text-sm text-[#6a3530]">{error}</section>
      ) : (
        <OrganizerStudioForm
          mode="edit"
          organizerId={organizerId}
          draft={draft}
          setDraft={setDraft}
          onSubmit={handleSubmitResult}
          submitButtonText="提交主办方编辑"
        />
      )}
    </AdminContentLayout>
  );
}
