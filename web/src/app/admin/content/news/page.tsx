'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import { newsStudioApi, type NewsStudioLoadedArticle } from '@/features/admin-content/news-studio';

const formatDateTime = (value?: string | null): string => {
  if (!value) return '未记录';
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
};

function NewsDetailOverlay({
  item,
  detail,
  loading,
  error,
  onClose,
}: {
  item: NewsStudioLoadedArticle | null;
  detail: NewsStudioLoadedArticle | null;
  loading: boolean;
  error: string;
  onClose: () => void;
}) {
  if (!item) return null;

  const resolved = detail ?? item;
  const coverImage = resolved.coverImageURL || item.coverImageURL || '';

  return (
    <div className="fixed inset-0 z-[80] flex items-center justify-center bg-black/45 p-4" onClick={onClose}>
      <div
        className="relative max-h-[90vh] w-full max-w-[980px] overflow-hidden rounded-[28px] border border-white/70 bg-[#f7f5ef] shadow-[0_30px_120px_rgba(7,17,16,0.24)]"
        onClick={(event) => event.stopPropagation()}
      >
        <button
          type="button"
          onClick={onClose}
          className="absolute right-6 top-6 z-10 inline-flex h-10 w-10 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#6b7280]"
          aria-label="关闭资讯详情"
        >
          ×
        </button>

        <div className="grid max-h-[90vh] overflow-y-auto lg:grid-cols-[0.95fr_1.45fr]">
          <div className="border-b border-[#e8eceb] bg-[linear-gradient(180deg,#eef4f0_0%,#f7f5ef_100%)] p-6 lg:border-b-0 lg:border-r">
            <div className="overflow-hidden rounded-[24px] border border-[#dfe7e2] bg-[#e7ece9]">
              {coverImage ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={coverImage} alt={resolved.title} className="aspect-[1.25/1] w-full object-cover" />
              ) : (
                <div className="flex aspect-[1.25/1] items-center justify-center text-sm text-[#7b8794]">暂无封面</div>
              )}
            </div>

            <div className="-mt-10 px-4">
              <div className="rounded-[24px] border border-[#e8eceb] bg-white/96 p-5 shadow-[0_12px_32px_rgba(33,52,47,0.08)]">
                <div className="flex flex-wrap gap-2">
                  <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">{resolved.category}</span>
                  <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">{resolved.source}</span>
                </div>
                <div className="mt-3 text-[28px] font-semibold tracking-[-0.04em] text-[#111827]">{resolved.title}</div>
                <div className="mt-2 text-sm font-medium text-[#6b7280]">发布于 {formatDateTime(resolved.publishedAt)}</div>
              </div>
            </div>
          </div>

          <div className="p-6">
            <div className="flex items-center justify-between gap-3">
              <div>
                <div className="text-xs font-semibold uppercase tracking-[0.14em] text-[#9aa1ad]">News Profile</div>
                <div className="mt-2 text-[26px] font-semibold tracking-[-0.04em] text-[#111827]">详细信息</div>
              </div>
              <Link
                href={`/admin/content/news/${item.id}/edit`}
                className="inline-flex h-[42px] items-center rounded-full bg-[#071110] px-5 text-sm font-semibold text-white"
              >
                编辑资讯
              </Link>
            </div>

            {loading ? (
              <div className="mt-6 rounded-[22px] border border-[#e8eceb] bg-white px-5 py-10 text-sm text-[#6b7280]">
                正在加载资讯完整信息...
              </div>
            ) : error ? (
              <div className="mt-6 rounded-[22px] border border-red-200 bg-red-50 px-5 py-4 text-sm text-[#7a2d29]">
                {error}
              </div>
            ) : (
              <div className="mt-6 space-y-5">
                <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                  <div className="text-sm font-semibold text-[#111827]">摘要</div>
                  <div className="mt-3 text-sm leading-7 text-[#4b5563]">{resolved.summary || '暂无摘要。'}</div>
                </section>

                <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                  <div className="text-sm font-semibold text-[#111827]">正文</div>
                  <div className="mt-3 whitespace-pre-wrap text-sm leading-7 text-[#4b5563]">{resolved.body || '暂无正文。'}</div>
                </section>

                <section className="grid gap-5 lg:grid-cols-2">
                  <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                    <div className="text-sm font-semibold text-[#111827]">基础资料</div>
                    <div className="mt-4 space-y-3 text-sm text-[#4b5563]">
                      <div><span className="font-medium text-[#111827]">ID: </span>{resolved.id}</div>
                      <div><span className="font-medium text-[#111827]">Category: </span>{resolved.category}</div>
                      <div><span className="font-medium text-[#111827]">Source: </span>{resolved.source}</div>
                      <div><span className="font-medium text-[#111827]">Link: </span>{resolved.link || '未设置'}</div>
                    </div>
                  </div>

                  <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                    <div className="text-sm font-semibold text-[#111827]">绑定实体</div>
                    <div className="mt-4 space-y-3 text-sm text-[#4b5563]">
                      <div><span className="font-medium text-[#111827]">DJs: </span>{resolved.boundDjIDs.length ? resolved.boundDjIDs.join(', ') : '暂无'}</div>
                      <div><span className="font-medium text-[#111827]">Brands: </span>{resolved.boundBrandIDs.length ? resolved.boundBrandIDs.join(', ') : '暂无'}</div>
                      <div><span className="font-medium text-[#111827]">Events: </span>{resolved.boundEventIDs.length ? resolved.boundEventIDs.join(', ') : '暂无'}</div>
                    </div>
                  </div>
                </section>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default function AdminContentNewsPage() {
  const [items, setItems] = useState<NewsStudioLoadedArticle[]>([]);
  const [cursor, setCursor] = useState<string | null>(null);
  const [cursorStack, setCursorStack] = useState<Array<string | null>>([]);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedNews, setSelectedNews] = useState<NewsStudioLoadedArticle | null>(null);
  const [selectedNewsDetail, setSelectedNewsDetail] = useState<NewsStudioLoadedArticle | null>(null);
  const [selectedNewsLoading, setSelectedNewsLoading] = useState(false);
  const [selectedNewsError, setSelectedNewsError] = useState('');
  const [detailCache, setDetailCache] = useState<Record<string, NewsStudioLoadedArticle>>({});

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

  const openDetailOverlay = async (item: NewsStudioLoadedArticle) => {
    setSelectedNews(item);
    setSelectedNewsError('');
    const cached = detailCache[item.id];
    if (cached) {
      setSelectedNewsDetail(cached);
      setSelectedNewsLoading(false);
      return;
    }

    setSelectedNewsDetail(null);
    setSelectedNewsLoading(true);
    try {
      const detail = await newsStudioApi.fetchNews(item.id);
      setDetailCache((current) => ({ ...current, [item.id]: detail }));
      setSelectedNewsDetail(detail);
    } catch (detailError) {
      setSelectedNewsError(detailError instanceof Error ? detailError.message : '资讯详情加载失败');
    } finally {
      setSelectedNewsLoading(false);
    }
  };

  const closeDetailOverlay = () => {
    setSelectedNews(null);
    setSelectedNewsDetail(null);
    setSelectedNewsLoading(false);
    setSelectedNewsError('');
  };

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
                <div
                  key={item.id}
                  role="button"
                  tabIndex={0}
                  onClick={() => void openDetailOverlay(item)}
                  onKeyDown={(event) => {
                    if (event.key === 'Enter' || event.key === ' ') {
                      event.preventDefault();
                      void openDetailOverlay(item);
                    }
                  }}
                  className="admin-reference-soft-card cursor-pointer p-5 transition-colors hover:bg-[#fafaf8] focus:outline-none focus:ring-2 focus:ring-[#d9e7dd]"
                >
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
                      <div className="mt-3 text-xs text-black/38">发布于 {formatDateTime(item.publishedAt)}</div>
                    </div>
                    <Link
                      href={`/admin/content/news/${item.id}/edit`}
                      onClick={(event) => event.stopPropagation()}
                      className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
                    >
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

      <NewsDetailOverlay
        item={selectedNews}
        detail={selectedNewsDetail}
        loading={selectedNewsLoading}
        error={selectedNewsError}
        onClose={closeDetailOverlay}
      />
    </AdminContentLayout>
  );
}
