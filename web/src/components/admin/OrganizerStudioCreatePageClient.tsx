'use client';

import Link from 'next/link';
import { useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import NotificationContentHistoryPrompt from '@/components/admin/NotificationContentHistoryPrompt';
import OrganizerStudioForm from '@/components/admin/OrganizerStudioForm';
import {
  createOrganizerStudioDraft,
  type OrganizerStudioCreateResult,
  type OrganizerStudioDraft,
} from '@/features/admin-content/organizer-studio';

export default function OrganizerStudioCreatePageClient({
  initialName,
}: {
  initialName: string;
}) {
  const [draft, setDraft] = useState<OrganizerStudioDraft>(() =>
    createOrganizerStudioDraft(initialName)
  );
  const [submitNotice, setSubmitNotice] = useState<string | null>(null);
  const [submitResultLink, setSubmitResultLink] = useState<string | null>(null);
  const [savedOrganizerId, setSavedOrganizerId] = useState<string | null>(null);

  const handleSubmitResult = (result: OrganizerStudioCreateResult) => {
    if (result.kind === 'created') {
      setSubmitNotice(`主办方已创建成功：${result.organizer.name}`);
      setSubmitResultLink(`/admin/content/organizers/${result.organizer.id}/edit`);
      setSavedOrganizerId(result.organizer.id);
      return;
    }
    setSubmitNotice(result.payload.message || '主办方已进入审核队列');
    setSubmitResultLink('/admin/content/reviews');
    setSavedOrganizerId(null);
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

      {savedOrganizerId ? (
        <NotificationContentHistoryPrompt
          entityType="festival"
          entityId={savedOrganizerId}
          secondaryHref="/admin/content/organizers/catalog"
          secondaryLabel="稍后处理，先回到主办方目录"
          description="这条主办方资料已经直接保存成功。你可以现在去统一内容历史页继续决定是否推送，也可以先回目录稍后处理。"
        />
      ) : null}

      <OrganizerStudioForm
        mode="create"
        draft={draft}
        setDraft={setDraft}
        onSubmit={handleSubmitResult}
      />
    </AdminContentLayout>
  );
}
