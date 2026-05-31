'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import { newsStudioApi, type NewsStudioLoadedArticle } from '@/features/admin-content/news-studio';

export default function AdminContentNewsPage() {
  const [items, setItems] = useState<NewsStudioLoadedArticle[]>([]);
  const [cursor, setCursor] = useState<string | null>(null);
  const [cursorStack, setCursorStack] = useState<Array<string | null>>([]);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      try {
        setLoading(true);
        setError(null);
        const response = await newsStudioApi.listNews(cursor, 12);
        if (cancelled) return;
        setItems(response.items);
        setNextCursor(response.nextCursor);
      } catch (loadError) {
        if (cancelled) return;
        setError(loadError instanceof Error ? loadError.message : '加载资讯失败');
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void load();
    return () => {
      cancelled = true;
    };
  }, [cursor]);

  const filteredItems = useMemo(() => {
    const keyword = query.trim().toLowerCase();
    if (!keyword) return items;
    return items.filter((item) =>
      [item.title, item.source, item.summary]
        .join(' ')
        .toLowerCase()
        .includes(keyword)
    );
  }, [items, query]);

  return (
    <AdminContentLayout
      title="资讯工作区"
      description="在统一后台中完成资讯的创建、编辑和关联维护。这里优先突出正文与发布动作，把状态信息弱化到辅助层。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            返回内容控制台
          </Link>
          <Link href="/admin/content/news/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            新建资讯
          </Link>
        </>
      }
    >
      <section className="space-y-5">
        <div className="grid gap-4 lg:grid-cols-4">
          {[
            { label: 'News Studio', value: 'Live', note: '创建 / 编辑已接入', tone: 'bg-[#dff4a8]' },
            { label: 'Body First', value: 'On', note: '正文区强化', tone: 'bg-[#f3e5a8]' },
            { label: 'Bindings', value: 'IDs', note: 'DJ / 主办方 / 活动', tone: 'bg-[#f7c4c0]' },
            { label: 'Page Size', value: '12', note: '游标分页', tone: 'bg-[#dbeefe]' },
          ].map((item) => (
            <div key={item.label} className={`admin-reference-pastel-card p-5 ${item.tone}`}>
              <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">{item.label}</div>
              <div className="mt-4 text-[34px] font-semibold tracking-[-0.04em] text-[#1a1a1a]">{item.value}</div>
              <div className="mt-2 text-[13px] text-black/55">{item.note}</div>
            </div>
          ))}
        </div>

        <section className="admin-reference-card p-6">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">Latest News</div>
              <h2 className="mt-2 text-[30px] font-semibold tracking-[-0.03em] text-[#1a1a1a]">最近资讯</h2>
            </div>
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              className="admin-studio-input max-w-[320px]"
              placeholder="搜索标题 / 来源 / 摘要"
            />
          </div>

          {loading ? (
            <div className="mt-6 text-sm text-black/48">正在加载资讯列表...</div>
          ) : error ? (
            <div className="admin-studio-pastel-rose mt-6 p-4 text-sm text-[#6a3530]">{error}</div>
          ) : (
            <div className="mt-6 space-y-4">
              {filteredItems.map((item) => (
                <div key={item.id} className="admin-reference-soft-card p-5">
                  <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap gap-2">
                        <span className="admin-reference-chip">{item.category}</span>
                        <span className="admin-reference-chip">{item.source}</span>
                      </div>
                      <h3 className="mt-4 text-xl font-semibold tracking-[-0.02em] text-[#071110]">{item.title}</h3>
                      <p className="mt-2 line-clamp-2 text-sm leading-7 text-black/48">
                        {item.summary || item.body || '暂无摘要'}
                      </p>
                      <div className="mt-3 text-xs text-black/38">
                        发布于 {new Date(item.publishedAt).toLocaleString('zh-CN')}
                      </div>
                    </div>
                    <Link href={`/admin/content/news/${item.id}/edit`} className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
                      编辑资讯
                    </Link>
                  </div>
                </div>
              ))}

              {!filteredItems.length ? (
                <div className="admin-reference-soft-card p-6 text-sm text-black/48">当前页没有匹配的资讯。</div>
              ) : null}
            </div>
          )}

          <div className="mt-6 flex flex-wrap gap-3">
            <button
              type="button"
              onClick={() => {
                if (!cursorStack.length) return;
                const nextStack = [...cursorStack];
                const previousCursor = nextStack.pop() ?? null;
                setCursorStack(nextStack);
                setCursor(previousCursor);
              }}
              disabled={!cursorStack.length}
              className="admin-studio-button-secondary px-5 py-3 text-sm disabled:opacity-50"
            >
              上一页
            </button>
            <button
              type="button"
              onClick={() => {
                if (!nextCursor) return;
                setCursorStack((current) => [...current, cursor]);
                setCursor(nextCursor);
              }}
              disabled={!nextCursor}
              className="admin-studio-button-secondary px-5 py-3 text-sm disabled:opacity-50"
            >
              下一页
            </button>
          </div>
        </section>
      </section>
    </AdminContentLayout>
  );
}
