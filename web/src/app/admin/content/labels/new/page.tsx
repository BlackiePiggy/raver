'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import LabelStudioForm from '@/components/admin/LabelStudioForm';
import {
  createLabelStudioDraft,
  type LabelStudioCreateResult,
  type LabelStudioDraft,
} from '@/features/admin-content/label-studio';
import { buildAdminContentSubmitResultHref } from '@/features/admin-content/submit-result';

export default function AdminContentLabelCreatePage() {
  const router = useRouter();
  const [draft, setDraft] = useState<LabelStudioDraft>(() => createLabelStudioDraft());

  const handleSubmitResult = (result: LabelStudioCreateResult) => {
    router.replace(
      buildAdminContentSubmitResultHref({
        entityType: 'label',
        flow: 'create',
        outcome: 'created',
        entityId: result.label.id,
        entityName: result.label.name,
      })
    );
  };

  return (
    <AdminContentLayout
      title="新建厂牌"
      description="使用当前后台 Studio 流程创建厂牌资料。保存成功后，可以立即决定是否通过统一发布任务链路发送 APNS / 站内通知。"
      actions={
        <>
          <Link
            href="/admin/content/labels"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            返回厂牌目录
          </Link>
        </>
      }
    >
      <LabelStudioForm mode="create" draft={draft} setDraft={setDraft} onSubmit={handleSubmitResult} />
    </AdminContentLayout>
  );
}
