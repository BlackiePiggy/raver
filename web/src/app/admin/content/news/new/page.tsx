'use client';

import Link from 'next/link';
import { useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import AdminPublishTaskActions from '@/components/admin/AdminPublishTaskActions';
import NewsStudioForm from '@/components/admin/NewsStudioForm';
import {
  createNewsStudioDraft,
  type NewsStudioCreateResult,
  type NewsStudioDraft,
} from '@/features/admin-content/news-studio';

export default function AdminContentNewsCreatePage() {
  const [draft, setDraft] = useState<NewsStudioDraft>(() => createNewsStudioDraft());
  const [submitNotice, setSubmitNotice] = useState<string | null>(null);
  const [submitResultLink, setSubmitResultLink] = useState<string | null>(null);
  const [savedNewsId, setSavedNewsId] = useState<string | null>(null);

  const handleSubmitResult = (result: NewsStudioCreateResult) => {
    setSubmitNotice(`资讯创建成功：${result.article.title}`);
    setSubmitResultLink(`/admin/content/news/${result.article.id}/edit`);
    setSavedNewsId(result.article.id);
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

      {savedNewsId ? (
        <AdminPublishTaskActions
          taskType="news_release"
          entityType="news_article"
          entityId={savedNewsId}
          mode="create"
        />
      ) : null}

      <NewsStudioForm mode="create" draft={draft} setDraft={setDraft} onSubmit={handleSubmitResult} />
    </AdminContentLayout>
  );
}
