'use client';

import Link from 'next/link';
import { useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import LabelStudioForm from '@/components/admin/LabelStudioForm';
import {
  createLabelStudioDraft,
  type LabelStudioCreateResult,
  type LabelStudioDraft,
} from '@/features/admin-content/label-studio';

export default function AdminContentLabelCreatePage() {
  const [draft, setDraft] = useState<LabelStudioDraft>(() => createLabelStudioDraft());
  const [submitNotice, setSubmitNotice] = useState<string | null>(null);
  const [submitResultLink, setSubmitResultLink] = useState<string | null>(null);

  const handleSubmitResult = (result: LabelStudioCreateResult) => {
    setSubmitNotice(`厂牌已创建成功：${result.label.name}`);
    setSubmitResultLink(`/admin/content/labels/${result.label.id}/edit`);
  };

  return (
    <AdminContentLayout
      title="新建厂牌"
      description="新厂牌创建页已经接上当前后台接口，主区域突出身份、简介和官方渠道，统计与附加信息放到次级区。"
      actions={
        <>
          <Link href="/admin/content/labels" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            返回厂牌工作区
          </Link>
          <Link href="/admin/content" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            返回内容控制台
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
                打开结果页面
              </Link>
            </div>
          ) : null}
        </section>
      ) : null}

      <LabelStudioForm mode="create" draft={draft} setDraft={setDraft} onSubmit={handleSubmitResult} />
    </AdminContentLayout>
  );
}
