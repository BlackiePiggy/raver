'use client';

import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import OrganizerStudioForm from '@/components/admin/OrganizerStudioForm';
import {
  createOrganizerStudioDraft,
  hydrateOrganizerStudioDraftFromOrganizer,
  organizerStudioApi,
  type OrganizerStudioCreateResult,
  type OrganizerStudioDraft,
} from '@/features/admin-content/organizer-studio';
import { buildAdminContentSubmitResultHref } from '@/features/admin-content/submit-result';

export default function AdminContentOrganizerEditPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const organizerId = typeof params?.id === 'string' ? params.id : '';
  const [draft, setDraft] = useState<OrganizerStudioDraft>(() => createOrganizerStudioDraft());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

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
      router.replace(
        buildAdminContentSubmitResultHref({
          entityType: 'festival',
          flow: 'edit',
          outcome: 'created',
          entityId: result.organizer.id,
          entityName: result.organizer.name,
        })
      );
      return;
    }

    router.replace(
      buildAdminContentSubmitResultHref({
        entityType: 'festival',
        flow: 'edit',
        outcome: 'submitted',
        entityId: organizerId,
        submissionId: result.payload.submission.id,
        message: result.payload.message,
      })
    );
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
