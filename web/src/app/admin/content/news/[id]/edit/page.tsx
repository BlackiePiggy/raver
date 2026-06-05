'use client';

import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import NewsStudioForm from '@/components/admin/NewsStudioForm';
import {
  createNewsStudioDraft,
  hydrateNewsStudioDraftFromArticle,
  newsStudioApi,
  type NewsStudioCreateResult,
  type NewsStudioDraft,
} from '@/features/admin-content/news-studio';
import { buildAdminContentSubmitResultHref } from '@/features/admin-content/submit-result';

export default function AdminContentNewsEditPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const newsId = typeof params?.id === 'string' ? params.id : '';
  const [draft, setDraft] = useState<NewsStudioDraft>(() => createNewsStudioDraft());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!newsId) {
      setError('缺少资讯 ID');
      setLoading(false);
      return;
    }

    let cancelled = false;
    const load = async () => {
      try {
        setLoading(true);
        setError(null);
        const article = await newsStudioApi.fetchNews(newsId);
        if (cancelled) return;
        setDraft(hydrateNewsStudioDraftFromArticle(article));
      } catch (loadError) {
        if (cancelled) return;
        setError(loadError instanceof Error ? loadError.message : '加载资讯失败。');
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, [newsId]);

  const handleSubmitResult = (result: NewsStudioCreateResult) => {
    router.replace(
      buildAdminContentSubmitResultHref({
        entityType: 'news_article',
        flow: 'edit',
        outcome: 'created',
        entityId: result.article.id,
        entityName: result.article.title,
      })
    );
  };

  return (
    <AdminContentLayout
      title={draft.title || '编辑资讯'}
      description="回填当前资讯的正文、摘要、媒体资源和绑定关系，保存后可按需要决定是否发送用户通知。"
      actions={
        <>
          <Link
            href="/admin/content/news"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            返回资讯目录
          </Link>
          <Link
            href="/admin/content/news/new"
            className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
          >
            新建资讯
          </Link>
        </>
      }
    >
      {loading ? (
        <section className="admin-studio-section p-6 text-sm text-black/48">正在加载资讯详情...</section>
      ) : error ? (
        <section className="admin-studio-pastel-rose p-6 text-sm text-[#6a3530]">{error}</section>
      ) : (
        <NewsStudioForm
          mode="edit"
          newsId={newsId}
          draft={draft}
          setDraft={setDraft}
          onSubmit={handleSubmitResult}
          submitButtonText="保存资讯"
        />
      )}
    </AdminContentLayout>
  );
}
