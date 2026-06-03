'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useEffect, useMemo, useRef, useState } from 'react';
import { Ellipsis } from 'lucide-react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import OverlayImageViewer, { type OverlayImageViewerAsset } from '@/components/admin/OverlayImageViewer';
import { newsStudioApi, type NewsStudioLoadedArticle } from '@/features/admin-content/news-studio';

const formatDateTime = (value?: string | null): string => {
  if (!value) return 'Not recorded';
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
};

type NewsDetailTabKey = 'overview' | 'content' | 'bindings';

const NEWS_DETAIL_TABS: Array<{ key: NewsDetailTabKey; label: string }> = [
  { key: 'overview', label: 'Overview' },
  { key: 'content', label: 'Content' },
  { key: 'bindings', label: 'Bindings' },
];

const renderDetailText = (label: string, value?: string | null) => (
  <div>
    <span className="font-medium text-[#111827]">{label}: </span>
    {value && value.trim() ? value : 'Not set'}
  </div>
);

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
  const [activeTab, setActiveTab] = useState<NewsDetailTabKey>('overview');
  const [previewAssetIndex, setPreviewAssetIndex] = useState<number | null>(null);

  useEffect(() => {
    setActiveTab('overview');
    setPreviewAssetIndex(null);
  }, [item?.id]);

  if (!item) return null;

  const resolved = detail ?? item;
  const coverImage = resolved.coverImageURL || item.coverImageURL || '';
  const previewAssets: OverlayImageViewerAsset[] = coverImage
    ? [
        {
          url: coverImage,
          alt: resolved.title,
          title: 'Cover Image',
          subtitle: resolved.category || resolved.source || 'News asset',
        },
      ]
    : [];
  const bindingGroups = [
    { label: 'DJs', items: resolved.boundDjIDs },
    { label: 'Brands', items: resolved.boundBrandIDs },
    { label: 'Events', items: resolved.boundEventIDs },
  ];

  let tabContent: React.ReactNode = null;
  if (loading) {
    tabContent = (
      <div className="rounded-[22px] border border-[#e8eceb] bg-white px-5 py-10 text-sm text-[#6b7280]">
        Loading full article details...
      </div>
    );
  } else if (error) {
    tabContent = (
      <div className="rounded-[22px] border border-red-200 bg-red-50 px-5 py-4 text-sm text-[#7a2d29]">
        {error}
      </div>
    );
  } else if (activeTab === 'overview') {
    tabContent = (
      <div className="space-y-5">
        <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
          <div className="text-sm font-semibold text-[#111827]">Summary</div>
          <div className="mt-3 text-sm leading-7 text-[#4b5563]">{resolved.summary || 'No summary available.'}</div>
        </section>

        <section className="grid gap-5 lg:grid-cols-2">
          <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
            <div className="text-sm font-semibold text-[#111827]">Article Metadata</div>
            <div className="mt-4 space-y-3 text-sm text-[#4b5563]">
              {renderDetailText('ID', resolved.id)}
              {renderDetailText('Category', resolved.category)}
              {renderDetailText('Source', resolved.source)}
              {renderDetailText('Published', formatDateTime(resolved.publishedAt))}
            </div>
          </div>

          <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
            <div className="text-sm font-semibold text-[#111827]">Source Link</div>
            <div className="mt-4 text-sm leading-7 text-[#4b5563]">
              {resolved.link ? (
                <a href={resolved.link} target="_blank" rel="noreferrer" className="break-all text-[#1d4ed8] underline">
                  {resolved.link}
                </a>
              ) : (
                'No source link attached.'
              )}
            </div>
          </div>
        </section>
      </div>
    );
  } else if (activeTab === 'content') {
    tabContent = (
      <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
        <div className="text-sm font-semibold text-[#111827]">Body</div>
        <div className="mt-3 whitespace-pre-wrap text-sm leading-7 text-[#4b5563]">{resolved.body || 'No body content.'}</div>
      </section>
    );
  } else {
    tabContent = (
      <div className="grid gap-5 xl:grid-cols-3">
        {bindingGroups.map((group) => (
          <section key={group.label} className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
            <div className="flex items-center justify-between gap-3">
              <div className="text-sm font-semibold text-[#111827]">{group.label}</div>
              <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#6b7280]">
                {group.items.length}
              </span>
            </div>
            <div className="mt-4 flex flex-wrap gap-2">
              {group.items.length ? (
                group.items.map((entry) => (
                  <span key={entry} className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">
                    {entry}
                  </span>
                ))
              ) : (
                <div className="text-sm text-[#6b7280]">No bindings.</div>
              )}
            </div>
          </section>
        ))}
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-[80] flex items-center justify-center bg-black/45 p-4" onClick={onClose}>
      <div
        className="relative max-h-[92vh] w-full max-w-[1360px] overflow-hidden rounded-[28px] border border-white/70 bg-[#f7f5ef] shadow-[0_30px_120px_rgba(7,17,16,0.24)]"
        onClick={(event) => event.stopPropagation()}
      >
        <button
          type="button"
          onClick={onClose}
          className="absolute right-6 top-6 z-10 inline-flex h-10 w-10 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#6b7280]"
          aria-label="Close news detail"
        >
          脳
        </button>

        <div className="grid max-h-[92vh] overflow-y-auto lg:grid-cols-[380px_minmax(0,1fr)]">
          <div className="border-b border-[#e8eceb] bg-[linear-gradient(180deg,#eef4f0_0%,#f7f5ef_100%)] p-6 lg:border-b-0 lg:border-r">
            <button
              type="button"
              onClick={() => {
                if (previewAssets.length) setPreviewAssetIndex(0);
              }}
              className="block w-full overflow-hidden rounded-[24px] border border-[#dfe7e2] bg-[#e7ece9] text-left"
            >
              {coverImage ? (
                <div className="relative aspect-[1.25/1] w-full">
                  <Image src={coverImage} alt={resolved.title} fill className="object-cover" sizes="900px" />
                </div>
              ) : (
                <div className="flex aspect-[1.25/1] items-center justify-center text-sm text-[#7b8794]">No cover image</div>
              )}
            </button>

            <div className="-mt-10 px-4">
              <div className="rounded-[24px] border border-[#e8eceb] bg-white/96 p-5 shadow-[0_12px_32px_rgba(33,52,47,0.08)]">
                <div className="flex flex-wrap gap-2">
                  <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">{resolved.category}</span>
                  <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">{resolved.source}</span>
                </div>
                <div className="mt-3 text-[28px] font-semibold tracking-[-0.04em] text-[#111827]">{resolved.title}</div>
                <div className="mt-2 text-sm font-medium text-[#6b7280]">Published {formatDateTime(resolved.publishedAt)}</div>
              </div>
            </div>

            <div className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-1">
              {[
                ['Category', resolved.category],
                ['Source', resolved.source],
                ['DJs', String(resolved.boundDjIDs.length)],
                ['Events', String(resolved.boundEventIDs.length)],
              ].map(([label, value]) => (
                <div key={label} className="rounded-[20px] border border-[#e8eceb] bg-white px-4 py-3">
                  <div className="text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">{label}</div>
                  <div className="mt-2 text-base font-semibold text-[#111827]">{value}</div>
                </div>
              ))}
            </div>

            <div className="mt-5 rounded-[22px] border border-[#e8eceb] bg-white p-5">
              <div className="text-sm font-semibold text-[#111827]">Basic Info</div>
              <div className="mt-4 space-y-3 text-sm text-[#4b5563]">
                {renderDetailText('ID', resolved.id)}
                {renderDetailText('Published', formatDateTime(resolved.publishedAt))}
                {renderDetailText('Category', resolved.category)}
                {renderDetailText('Source', resolved.source)}
                {renderDetailText('Link', resolved.link)}
              </div>
            </div>
          </div>

          <div className="p-6">
            <div className="flex items-center justify-between gap-3">
              <div>
                <div className="text-xs font-semibold uppercase tracking-[0.14em] text-[#9aa1ad]">News Profile</div>
                <div className="mt-2 text-[26px] font-semibold tracking-[-0.04em] text-[#111827]">Article Detail</div>
              </div>
              <Link
                href={`/admin/content/news/${item.id}/edit`}
                className="inline-flex h-[42px] items-center rounded-full bg-[#071110] px-5 text-sm font-semibold text-white"
              >
                Edit News
              </Link>
            </div>

            <div className="mt-6 flex flex-wrap gap-2 rounded-[24px] border border-[#e8eceb] bg-white/70 p-2">
              {NEWS_DETAIL_TABS.map((tab) => (
                <button
                  key={tab.key}
                  type="button"
                  onClick={() => setActiveTab(tab.key)}
                  className={`inline-flex h-[42px] items-center rounded-full px-4 text-sm font-semibold transition ${
                    activeTab === tab.key
                      ? 'bg-[#071110] text-white shadow-[0_8px_20px_rgba(7,17,16,0.16)]'
                      : 'text-[#6b7280] hover:bg-white'
                  }`}
                >
                  {tab.label}
                </button>
              ))}
            </div>

            <div className="mt-6">{tabContent}</div>
          </div>
        </div>
        <OverlayImageViewer
          assets={previewAssets}
          activeIndex={previewAssetIndex}
          onClose={() => setPreviewAssetIndex(null)}
          onChange={setPreviewAssetIndex}
        />
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
  const [menuOpenNewsId, setMenuOpenNewsId] = useState<string | null>(null);
  const [pendingDeleteNews, setPendingDeleteNews] = useState<NewsStudioLoadedArticle | null>(null);
  const [deletingNewsId, setDeletingNewsId] = useState<string | null>(null);
  const actionMenuRef = useRef<HTMLDivElement | null>(null);

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
        setError(loadError instanceof Error ? loadError.message : 'Failed to load news.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void load();
    return () => {
      cancelled = true;
    };
  }, [cursor]);

  useEffect(() => {
    if (!menuOpenNewsId) return;

    const handlePointerDown = (event: MouseEvent) => {
      if (!actionMenuRef.current) return;
      if (event.target instanceof Node && actionMenuRef.current.contains(event.target)) return;
      setMenuOpenNewsId(null);
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setMenuOpenNewsId(null);
      }
    };

    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [menuOpenNewsId]);

  const filteredItems = useMemo(() => {
    const keyword = query.trim().toLowerCase();
    if (!keyword) return items;
    return items.filter((item) => [item.title, item.source, item.summary].join(' ').toLowerCase().includes(keyword));
  }, [items, query]);

  const openDetailOverlay = async (item: NewsStudioLoadedArticle) => {
    setMenuOpenNewsId(null);
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
      setSelectedNewsError(detailError instanceof Error ? detailError.message : 'Failed to load article detail.');
    } finally {
      setSelectedNewsLoading(false);
    }
  };

  const closeDetailOverlay = () => {
    setMenuOpenNewsId(null);
    setSelectedNews(null);
    setSelectedNewsDetail(null);
    setSelectedNewsLoading(false);
    setSelectedNewsError('');
  };

  const requestDeleteNews = (item: NewsStudioLoadedArticle) => {
    setMenuOpenNewsId(null);
    setPendingDeleteNews(item);
  };

  const confirmDeleteNews = async () => {
    if (!pendingDeleteNews) return;
    const articleId = pendingDeleteNews.id;
    try {
      setDeletingNewsId(articleId);
      await newsStudioApi.deleteNews(articleId);
      setItems((current) => current.filter((item) => item.id !== articleId));
      if (selectedNews?.id === articleId) {
        closeDetailOverlay();
      }
      setPendingDeleteNews(null);
      setDetailCache((current) => {
        const next = { ...current };
        delete next[articleId];
        return next;
      });
    } catch (deleteError) {
      setError(deleteError instanceof Error ? deleteError.message : '删除资讯失败，请稍后重试。');
    } finally {
      setDeletingNewsId(null);
    }
  };

  return (
    <AdminContentLayout
      title="News Workspace"
      description="Create, edit, and maintain article records with the same premium detail overlay structure used by events."
      actions={
        <>
          <Link href="/admin/content" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            Back to Content
          </Link>
          <Link href="/admin/content/news/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            New Article
          </Link>
        </>
      }
    >
      <section className="space-y-5">
        <div className="grid gap-4 lg:grid-cols-4">
          {[
            { label: 'News Studio', value: 'Live', note: 'create and edit enabled', tone: 'bg-[#dff4a8]' },
            { label: 'Body First', value: 'On', note: 'long-form content workflow', tone: 'bg-[#f3e5a8]' },
            { label: 'Bindings', value: 'IDs', note: 'dj, brand, and event relations', tone: 'bg-[#f7c4c0]' },
            { label: 'Page Size', value: '12', note: 'cursor-based pagination', tone: 'bg-[#dbeefe]' },
          ].map((card) => (
            <div key={card.label} className={`admin-reference-pastel-card p-5 ${card.tone}`}>
              <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">{card.label}</div>
              <div className="mt-4 text-[34px] font-semibold tracking-[-0.04em] text-[#1a1a1a]">{card.value}</div>
              <div className="mt-2 text-[13px] text-black/55">{card.note}</div>
            </div>
          ))}
        </div>

        <section className="admin-reference-card p-6">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">Latest News</div>
              <h2 className="mt-2 text-[30px] font-semibold tracking-[-0.03em] text-[#1a1a1a]">Recent Articles</h2>
            </div>
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              className="admin-studio-input max-w-[320px]"
              placeholder="Search title, source, or summary"
            />
          </div>

          {loading ? (
            <div className="mt-6 text-sm text-black/48">Loading article list...</div>
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
                      <p className="mt-2 line-clamp-2 text-sm leading-7 text-black/48">{item.summary || item.body || 'No summary available.'}</p>
                      <div className="mt-3 text-xs text-black/38">Published {formatDateTime(item.publishedAt)}</div>
                    </div>
                    <div className="flex items-center gap-2">
                      <Link
                        href={`/admin/content/news/${item.id}/edit`}
                        onClick={(event) => event.stopPropagation()}
                        className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
                      >
                        Edit
                      </Link>
                      <div className="relative" ref={menuOpenNewsId === item.id ? actionMenuRef : null}>
                        <button
                          type="button"
                          onClick={(event) => {
                            event.stopPropagation();
                            setMenuOpenNewsId((current) => (current === item.id ? null : item.id));
                          }}
                          className="inline-flex h-[44px] w-[44px] items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#6b7280]"
                          aria-label="More actions"
                        >
                          <Ellipsis className="h-4 w-4" />
                        </button>
                        {menuOpenNewsId === item.id ? (
                          <div
                            className="absolute right-0 top-[52px] z-20 min-w-[140px] rounded-[16px] border border-[#e7ebef] bg-white p-2 shadow-[0_16px_36px_rgba(17,24,39,0.14)]"
                            onClick={(event) => event.stopPropagation()}
                          >
                            <button
                              type="button"
                              onClick={() => requestDeleteNews(item)}
                              className="flex w-full items-center justify-start rounded-[12px] px-3 py-2 text-sm font-semibold text-[#b42318] transition hover:bg-[#fff5f4]"
                            >
                              Delete Article
                            </button>
                          </div>
                        ) : null}
                      </div>
                    </div>
                  </div>
                </div>
              ))}

              {!filteredItems.length ? <div className="admin-reference-soft-card p-6 text-sm text-black/48">No matching articles on this page.</div> : null}
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
              Previous
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
              Next
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
      {pendingDeleteNews ? (
        <div className="fixed inset-0 z-[90] flex items-center justify-center bg-black/45 p-4" onClick={() => setPendingDeleteNews(null)}>
          <div
            className="w-full max-w-md rounded-[28px] border border-[#e8eceb] bg-white p-6 shadow-[0_24px_72px_rgba(17,24,39,0.18)]"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[#b42318]">删除资讯</div>
            <div className="mt-3 text-[24px] font-semibold tracking-[-0.04em] text-[#111827]">确认删除这篇资讯吗？</div>
            <p className="mt-3 text-sm leading-6 text-[#6b7280]">
              {pendingDeleteNews.title}
              <br />
              删除后将无法恢复，请再次确认这是你要执行的操作。
            </p>
            <div className="mt-6 flex justify-end gap-3">
              <button
                type="button"
                onClick={() => setPendingDeleteNews(null)}
                className="inline-flex h-[44px] items-center justify-center rounded-full border border-[#e7ebef] bg-white px-5 text-sm font-semibold text-[#111827]"
              >
                取消
              </button>
              <button
                type="button"
                onClick={() => void confirmDeleteNews()}
                disabled={deletingNewsId === pendingDeleteNews.id}
                className="inline-flex h-[44px] items-center justify-center rounded-full bg-[#b42318] px-5 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
              >
                {deletingNewsId === pendingDeleteNews.id ? '删除中...' : '确认删除'}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </AdminContentLayout>
  );
}
