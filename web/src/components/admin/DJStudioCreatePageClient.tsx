'use client';

import Link from 'next/link';
import { useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import DJStudioForm from '@/components/admin/DJStudioForm';
import {
  createDJStudioDraft,
  type DJStudioCreateResult,
  type DJStudioDraft,
} from '@/features/admin-content/dj-studio';

export default function DJStudioCreatePageClient({
  initialName,
}: {
  initialName: string;
}) {
  const [draft, setDraft] = useState<DJStudioDraft>(() => createDJStudioDraft(initialName));
  const [submitNotice, setSubmitNotice] = useState<string | null>(null);
  const [submitResultLink, setSubmitResultLink] = useState<string | null>(null);

  const handleSubmitResult = (result: DJStudioCreateResult) => {
    if (result.kind === 'created') {
      setSubmitNotice(`DJ 已创建成功：${result.dj.name}`);
      setSubmitResultLink(result.dj.id ? `/djs/${result.dj.id}` : '/admin/content/djs');
      return;
    }
    setSubmitNotice(result.payload.message || 'DJ 已进入审核队列');
    setSubmitResultLink('/admin/content/reviews');
  };

  return (
    <AdminContentLayout
      title="新建 DJ"
      description="这里已经接上 DJ Studio 第一版可提交流程。当前版本先覆盖头像、banner、proof、平台链接和基础平台统计，并走统一 `/v1/djs/manual/import` 创建链路。"
      actions={
        <>
          <Link href="/admin/content/djs" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回 DJ 工作区
          </Link>
          <Link href="/admin/content/events/new" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            去新建活动
          </Link>
        </>
      }
    >
      {submitNotice ? (
        <section className="rounded-3xl border border-primary-blue/30 bg-primary-blue/10 p-4 text-sm text-text-primary">
          <div>{submitNotice}</div>
          {submitResultLink ? (
            <div className="mt-3">
              <Link href={submitResultLink} className="text-primary-blue hover:underline">
                打开结果页面
              </Link>
            </div>
          ) : null}
        </section>
      ) : null}

      <DJStudioForm
        mode="create"
        draft={draft}
        setDraft={setDraft}
        onSubmit={handleSubmitResult}
      />
    </AdminContentLayout>
  );
}
