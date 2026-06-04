'use client';

import Link from 'next/link';
import { useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import AdminPublishTaskActions from '@/components/admin/AdminPublishTaskActions';
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
  const [savedLabelId, setSavedLabelId] = useState<string | null>(null);

  const handleSubmitResult = (result: LabelStudioCreateResult) => {
    setSubmitNotice(`厂牌创建成功：${result.label.name}`);
    setSubmitResultLink(`/admin/content/labels/${result.label.id}/edit`);
    setSavedLabelId(result.label.id);
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
          <Link
            href="/admin/content"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
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

      {savedLabelId ? (
        <AdminPublishTaskActions
          taskType="brand_release"
          entityType="label"
          entityId={savedLabelId}
          mode="create"
        />
      ) : null}

      <LabelStudioForm mode="create" draft={draft} setDraft={setDraft} onSubmit={handleSubmitResult} />
    </AdminContentLayout>
  );
}
