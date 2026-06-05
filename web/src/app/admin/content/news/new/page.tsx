'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import NewsStudioForm from '@/components/admin/NewsStudioForm';
import {
  createNewsStudioDraft,
  type NewsStudioCreateResult,
  type NewsStudioDraft,
} from '@/features/admin-content/news-studio';
import { buildAdminContentSubmitResultHref } from '@/features/admin-content/submit-result';

export default function AdminContentNewsCreatePage() {
  const router = useRouter();
  const [draft, setDraft] = useState<NewsStudioDraft>(() => createNewsStudioDraft());

  const handleSubmitResult = (result: NewsStudioCreateResult) => {
    router.replace(
      buildAdminContentSubmitResultHref({
        entityType: 'news_article',
        flow: 'create',
        outcome: 'created',
        entityId: result.article.id,
        entityName: result.article.title,
      })
    );
  };

  return (
    <AdminContentLayout
      title="新建资讯"
      description="使用新的后台 Studio 流程创建资讯内容，正文编辑、资源管理和对象绑定都集中在同一条工作流中。"
      actions={
        <>
          <Link
            href="/admin/content/news"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            返回资讯目录
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
      <NewsStudioForm mode="create" draft={draft} setDraft={setDraft} onSubmit={handleSubmitResult} />
    </AdminContentLayout>
  );
}
