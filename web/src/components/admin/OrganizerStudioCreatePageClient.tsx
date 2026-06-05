'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import OrganizerStudioForm from '@/components/admin/OrganizerStudioForm';
import {
  createOrganizerStudioDraft,
  type OrganizerStudioCreateResult,
  type OrganizerStudioDraft,
} from '@/features/admin-content/organizer-studio';
import { buildAdminContentSubmitResultHref } from '@/features/admin-content/submit-result';

export default function OrganizerStudioCreatePageClient({
  initialName,
}: {
  initialName: string;
}) {
  const router = useRouter();
  const [draft, setDraft] = useState<OrganizerStudioDraft>(() =>
    createOrganizerStudioDraft(initialName)
  );

  const handleSubmitResult = (result: OrganizerStudioCreateResult) => {
    if (result.kind === 'created') {
      router.replace(
        buildAdminContentSubmitResultHref({
          entityType: 'festival',
          flow: 'create',
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
        flow: 'create',
        outcome: 'submitted',
        submissionId: result.payload.submission.id,
        message: result.payload.message,
      })
    );
  };

  return (
    <AdminContentLayout
      title="新建主办方"
      description="这里已经接上 Organizer Studio 第一版可提交流程。当前版本先覆盖头像、背景、证明、品牌资料和官方链接，并走统一 `/v1/learn/festivals` 创建链路。"
      actions={
        <>
          <Link
            href="/admin/content/organizers/catalog"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            返回主办方目录
          </Link>
          <Link
            href="/admin/content/events/new"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            去新建活动
          </Link>
        </>
      }
    >
      <OrganizerStudioForm
        mode="create"
        draft={draft}
        setDraft={setDraft}
        onSubmit={handleSubmitResult}
      />
    </AdminContentLayout>
  );
}
