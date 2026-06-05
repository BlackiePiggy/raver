'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import DJStudioForm from '@/components/admin/DJStudioForm';
import {
  createDJStudioDraft,
  type DJStudioCreateResult,
  type DJStudioDraft,
} from '@/features/admin-content/dj-studio';
import { buildAdminContentSubmitResultHref } from '@/features/admin-content/submit-result';

export default function DJStudioCreatePageClient({
  initialName,
}: {
  initialName: string;
}) {
  const router = useRouter();
  const [draft, setDraft] = useState<DJStudioDraft>(() => createDJStudioDraft(initialName));

  const handleSubmitResult = (result: DJStudioCreateResult) => {
    if (result.kind === 'created') {
      router.replace(
        buildAdminContentSubmitResultHref({
          entityType: 'dj',
          flow: 'create',
          outcome: 'created',
          entityId: result.dj.id,
          entityName: result.dj.name,
        })
      );
      return;
    }

    router.replace(
      buildAdminContentSubmitResultHref({
        entityType: 'dj',
        flow: 'create',
        outcome: 'submitted',
        submissionId: result.payload.submission.id,
        message: result.payload.message,
      })
    );
  };

  return (
    <AdminContentLayout
      title="新建 DJ"
      description="这里已经接上 DJ Studio 第一版提交流程。当前版本先覆盖头像、banner、proof、平台链接和基础平台统计，并走统一 `/v1/djs/manual/import` 创建链路。"
      actions={
        <>
          <Link
            href="/admin/content/djs/catalog"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            返回 DJ 目录
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
      <DJStudioForm
        mode="create"
        draft={draft}
        setDraft={setDraft}
        onSubmit={handleSubmitResult}
      />
    </AdminContentLayout>
  );
}
