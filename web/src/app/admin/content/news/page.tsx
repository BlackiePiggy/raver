'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useEffect, useMemo, useRef, useState } from 'react';
import { ChevronLeft, ChevronRight, Ellipsis } from 'lucide-react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import AdminSearchField from '@/components/admin/AdminSearchField';
import OverlayImageViewer, { type OverlayImageViewerAsset } from '@/components/admin/OverlayImageViewer';
import { djStudioApi } from '@/features/admin-content/dj-studio/api';
import { eventStudioApi } from '@/features/admin-content/event-studio/api';
import { newsStudioApi, type NewsStudioLoadedArticle } from '@/features/admin-content/news-studio';
import { organizerStudioApi } from '@/features/admin-content/organizer-studio/api';

const NEWS_CATEGORY_OPTIONS = [
  { value: '', label: '全部分类' },
  { value: 'community', label: 'community' },
  { value: 'festival', label: 'festival' },
  { value: 'scene', label: 'scene' },
  { value: 'gear', label: 'gear' },
  { value: 'industry', label: 'industry' },
] as const;

const NEWS_SORT_OPTIONS = [
  { value: 'newest', label: '发布时间从晚到早' },
  { value: 'oldest', label: '发布时间从早到晚' },
] as const;

const PAGE_SIZE = 12;

const buildVisiblePages = (page: number, totalPages: number): number[] => {
  const safeTotalPages = Math.max(1, totalPages);
  const start = Math.max(1, Math.min(safeTotalPages - 4, page - 2));
  const end = Math.min(safeTotalPages, start + 4);
  return Array.from({ length: end - start + 1 }, (_, index) => start + index);
};

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

const formatEventStatusLabel = (value?: string | null): string | null => {
  const normalized = String(value || '').trim().toLowerCase();
  if (!normalized) return null;
  if (normalized === 'cancelled') return '已取消';
  if (normalized === 'ongoing') return '进行中';
  if (normalized === 'ended') return '已结束';
  if (normalized === 'upcoming') return '即将开始';
  return value ?? null;
};

type NewsDetailTabKey = 'overview' | 'content' | 'bindings';
type BindingGroupKey = 'dj' | 'brand' | 'event';

type BindingDisplayItem = {
  id: string;
  name: string;
  subtitle?: string | null;
  meta?: string | null;
  imageUrl?: string | null;
};

const NEWS_DETAIL_TABS: Array<{ key: NewsDetailTabKey; label: string }> = [
  { key: 'overview', label: '概览' },
  { key: 'content', label: '正文' },
  { key: 'bindings', label: '绑定' },
];

const renderDetailText = (label: string, value?: string | null) => (
  <div>
    <span className="font-medium text-[#111827]">{label}: </span>
    {value && value.trim() ? value : '未设置'}
  </div>
);

const buildBindingCacheKey = (kind: BindingGroupKey, id: string): string => `${kind}:${id}`;

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
  const [bindingDetails, setBindingDetails] = useState<Record<string, BindingDisplayItem>>({});
  const [bindingErrors, setBindingErrors] = useState<Record<string, string>>({});

  const resolved = detail ?? item;

  const bindingGroups = useMemo(
    () =>
      resolved
        ? [
            { kind: 'dj' as const, label: 'DJs', items: resolved.boundDjIDs },
            { kind: 'brand' as const, label: 'Brands', items: resolved.boundBrandIDs },
            { kind: 'event' as const, label: 'Events', items: resolved.boundEventIDs },
          ]
        : [],
    [resolved]
  );

  useEffect(() => {
    setActiveTab('overview');
    setPreviewAssetIndex(null);
    setBindingDetails({});
    setBindingErrors({});
  }, [item?.id]);

  useEffect(() => {
    if (activeTab !== 'bindings' || !resolved) return;

    let cancelled = false;
    const missingEntries = bindingGroups.flatMap((group) =>
      group.items
        .map((id) => ({ kind: group.kind, id }))
        .filter(({ kind, id }) => {
          const cacheKey = buildBindingCacheKey(kind, id);
          return !bindingDetails[cacheKey] && !bindingErrors[cacheKey];
        })
    );

    if (!missingEntries.length) return;

    const loadBindings = async () => {
      await Promise.all(
        missingEntries.map(async ({ kind, id }) => {
          const cacheKey = buildBindingCacheKey(kind, id);
          try {
            let payload: BindingDisplayItem;
            if (kind === 'dj') {
              const dj = await djStudioApi.fetchDJ(id);
              payload = {
                id,
                name: dj.name || id,
                subtitle: [dj.country, dj.slug].filter(Boolean).join(' / ') || null,
                meta: dj.genres?.length ? dj.genres.slice(0, 3).join(' / ') : null,
                imageUrl: dj.avatarUrl || dj.bannerUrl || null,
              };
            } else if (kind === 'brand') {
              const brand = await organizerStudioApi.fetchOrganizer(id);
              payload = {
                id,
                name: brand.name || id,
                subtitle: [brand.city, brand.country].filter(Boolean).join(', ') || null,
                meta: brand.tagline || brand.abbreviation || null,
                imageUrl: brand.avatarUrl || brand.backgroundUrl || null,
              };
            } else {
              const event = await eventStudioApi.fetchEventOverview(id);
              payload = {
                id,
                name: event.name || id,
                subtitle: [event.city, event.country].filter(Boolean).join(', ') || null,
                meta: [event.eventType, formatEventStatusLabel(event.status), formatDateTime(event.startDate)].filter(Boolean).join(' · ') || null,
                imageUrl: event.coverImageUrl || event.cardImageUrl || null,
              };
            }

            if (cancelled) return;
            setBindingDetails((current) => ({ ...current, [cacheKey]: payload }));
          } catch (loadError) {
            if (cancelled) return;
            setBindingErrors((current) => ({
              ...current,
              [cacheKey]: loadError instanceof Error ? loadError.message : '加载绑定对象失败',
            }));
          }
        })
      );
    };

    void loadBindings();
    return () => {
      cancelled = true;
    };
  }, [activeTab, bindingDetails, bindingErrors, bindingGroups, resolved]);

  if (!item || !resolved) return null;

  const coverImage = resolved.coverImageURL || item.coverImageURL || '';
  const previewAssets: OverlayImageViewerAsset[] = coverImage
    ? [
        {
          url: coverImage,
          alt: resolved.title,
          title: '封面图',
          subtitle: resolved.category || resolved.source || '资讯资源',
        },
      ]
    : [];

  let tabContent: React.ReactNode = null;
  if (loading) {
    tabContent = (
      <div className="rounded-[22px] border border-[#e8eceb] bg-white px-5 py-10 text-sm text-[#6b7280]">
        正在加载完整资讯详情...
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
          <div className="text-sm font-semibold text-[#111827]">摘要</div>
          <div className="mt-3 text-sm leading-7 text-[#4b5563]">{resolved.summary || '暂无摘要。'}</div>
        </section>

        <section className="grid gap-5 lg:grid-cols-2">
          <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
            <div className="text-sm font-semibold text-[#111827]">文章信息</div>
            <div className="mt-4 space-y-3 text-sm text-[#4b5563]">
              {renderDetailText('ID', resolved.id)}
              {renderDetailText('Category', resolved.category)}
              {renderDetailText('Source', resolved.source)}
              {renderDetailText('Published', formatDateTime(resolved.publishedAt))}
            </div>
          </div>

          <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
            <div className="text-sm font-semibold text-[#111827]">原始链接</div>
            <div className="mt-4 text-sm leading-7 text-[#4b5563]">
              {resolved.link ? (
                <a href={resolved.link} target="_blank" rel="noreferrer" className="break-all text-[#1d4ed8] underline">
                  {resolved.link}
                </a>
              ) : (
                '没有附带原始链接。'
              )}
            </div>
          </div>
        </section>
      </div>
    );
  } else if (activeTab === 'content') {
    tabContent = (
      <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
        <div className="text-sm font-semibold text-[#111827]">正文</div>
        <div className="mt-3 whitespace-pre-wrap text-sm leading-7 text-[#4b5563]">{resolved.body || '暂无正文内容。'}</div>
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
            <div className="mt-4 space-y-3">
              {group.items.length ? (
                group.items.map((entry) => {
                  const cacheKey = buildBindingCacheKey(group.kind, entry);
                  const bound = bindingDetails[cacheKey];
                  const boundError = bindingErrors[cacheKey];
                  return (
                    <div key={entry} className="rounded-[18px] border border-[#edf0f2] bg-[#fafaf9] p-3">
                      <div className="flex gap-3">
                        <div className="h-12 w-12 overflow-hidden rounded-[14px] border border-[#edf0f2] bg-white">
                          {bound?.imageUrl ? (
                            // eslint-disable-next-line @next/next/no-img-element
                            <img src={bound.imageUrl} alt={bound.name} className="h-full w-full object-cover" />
                          ) : (
                            <div className="flex h-full w-full items-center justify-center text-[10px] font-semibold text-black/25">
                              {group.label.slice(0, 1)}
                            </div>
                          )}
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="truncate text-sm font-semibold text-[#111827]">{bound?.name || entry}</div>
                          {bound?.subtitle ? <div className="mt-1 truncate text-xs text-black/48">{bound.subtitle}</div> : null}
                          {bound?.meta ? <div className="mt-1 truncate text-xs text-black/35">{bound.meta}</div> : null}
                          <div className="mt-2 break-all text-[11px] text-black/32">ID: {entry}</div>
                          {boundError ? <div className="mt-2 text-[11px] text-[#8b3a3a]">{boundError}</div> : null}
                        </div>
                      </div>
                    </div>
                  );
                })
              ) : (
                <div className="text-sm text-[#6b7280]">暂无绑定。</div>
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
        <div className="absolute right-6 top-6 z-10 flex items-center gap-2">
          <Link
            href={`/admin/content/news/${item.id}/edit`}
            className="inline-flex h-10 items-center rounded-full bg-[#071110] px-4 text-sm font-semibold text-white shadow-[0_8px_20px_rgba(7,17,16,0.16)]"
          >
            编辑资讯
          </Link>
          <button
            type="button"
            onClick={onClose}
            className="inline-flex h-10 w-10 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#6b7280]"
            aria-label="Close news detail"
          >
            ×
          </button>
        </div>

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
                <div className="mt-2 text-sm font-medium text-[#6b7280]">发布时间 {formatDateTime(resolved.publishedAt)}</div>
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
              <div className="text-sm font-semibold text-[#111827]">基础信息</div>
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
            <div className="flex items-center justify-between gap-3 pr-[162px]">
              <div>
                <div className="text-xs font-semibold uppercase tracking-[0.14em] text-[#9aa1ad]">News Profile</div>
                <div className="mt-2 text-[26px] font-semibold tracking-[-0.04em] text-[#111827]">资讯详情</div>
              </div>
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
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [query, setQuery] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');
  const [sourceFilter, setSourceFilter] = useState('');
  const [sortOrder, setSortOrder] = useState<'newest' | 'oldest'>('newest');
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
        const response = await newsStudioApi.listNews({
          page,
          limit: PAGE_SIZE,
          category: categoryFilter || undefined,
          source: sourceFilter || undefined,
          sort: sortOrder,
          query: query || undefined,
        });
        if (cancelled) return;
        setItems(response.items);
        setTotal(response.pagination?.total ?? response.items.length);
        setTotalPages(response.pagination?.totalPages ?? 1);
      } catch (loadError) {
        if (cancelled) return;
        setError(loadError instanceof Error ? loadError.message : '资讯列表加载失败。');
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void load();
    return () => {
      cancelled = true;
    };
  }, [categoryFilter, page, query, sortOrder, sourceFilter]);

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

  const resetPaging = () => {
    setPage(1);
  };

  const visiblePages = useMemo(() => buildVisiblePages(page, totalPages), [page, totalPages]);

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
      setSelectedNewsError(detailError instanceof Error ? detailError.message : '资讯详情加载失败。');
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
      setTotal((current) => Math.max(0, current - 1));
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
      description=""
      actions={
        <>
          <Link href="/admin/content/news/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            新建资讯
          </Link>
        </>
      }
    >
      <section className="space-y-5">
        <section className="rounded-[28px] border border-[#edf0f2] bg-white p-6 shadow-[0_4px_20px_rgba(17,24,39,0.04)]">
          <div className="grid w-full gap-3 lg:min-w-[920px] lg:grid-cols-[minmax(260px,1.35fr)_minmax(220px,0.78fr)_minmax(220px,0.78fr)_minmax(240px,0.85fr)]">
              <label className="block">
                <div className="mb-2 text-xs font-semibold uppercase tracking-[0.12em] text-black/38">Search</div>
                <AdminSearchField
                  value={query}
                  onChange={(value) => {
                    setQuery(value);
                    resetPaging();
                  }}
                  placeholder="搜索标题、来源或摘要"
                  size="md"
                  className="w-full"
                  onClear={() => {
                    setQuery('');
                    resetPaging();
                  }}
                />
              </label>
              <label className="block">
                <div className="mb-2 text-xs font-semibold uppercase tracking-[0.12em] text-black/38">Source</div>
                <input
                  value={sourceFilter}
                  onChange={(event) => {
                    setSourceFilter(event.target.value);
                    resetPaging();
                  }}
                  className="admin-studio-input w-full"
                  placeholder="按来源筛选"
                />
              </label>
              <label className="block">
                <div className="mb-2 text-xs font-semibold uppercase tracking-[0.12em] text-black/38">Category</div>
                <select
                  value={categoryFilter}
                  onChange={(event) => {
                    setCategoryFilter(event.target.value);
                    resetPaging();
                  }}
                  className="admin-studio-input w-full"
                >
                  {NEWS_CATEGORY_OPTIONS.map((option) => (
                    <option key={option.value || 'all'} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </label>
              <label className="block">
                <div className="mb-2 text-xs font-semibold uppercase tracking-[0.12em] text-black/38">Sort</div>
                <select
                  value={sortOrder}
                  onChange={(event) => {
                    setSortOrder(event.target.value as 'newest' | 'oldest');
                    resetPaging();
                  }}
                  className="admin-studio-input w-full"
                >
                  {NEWS_SORT_OPTIONS.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </label>
          </div>

          {loading ? (
            <div className="mt-6 text-sm text-black/48">正在加载资讯列表...</div>
          ) : error ? (
            <div className="admin-studio-pastel-rose mt-6 p-4 text-sm text-[#6a3530]">{error}</div>
          ) : (
            <div className="mt-6 overflow-hidden rounded-[28px] border border-[#edf0f2] bg-white">
              {items.map((item) => (
                <article
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
                  className="flex cursor-pointer flex-col gap-4 px-6 py-5 transition-colors hover:bg-[#fbfcfb] focus:outline-none focus:ring-2 focus:ring-[#d9e7dd] lg:flex-row lg:items-center lg:gap-6"
                >
                  <div className="flex min-w-0 flex-1 gap-4">
                    <div className="relative h-[110px] w-[180px] shrink-0 overflow-hidden rounded-[16px] bg-[#f3f5f7]">
                      {item.coverImageURL ? (
                        <Image src={item.coverImageURL} alt={item.title} fill className="object-cover" sizes="180px" />
                      ) : (
                        <div className="flex h-full w-full items-center justify-center text-sm text-[#9ca3af]">
                          NEWS
                        </div>
                      )}
                    </div>

                    <div className="min-w-0 flex-1">
                      <div className="flex items-center justify-between gap-3">
                        <div className="flex min-w-0 flex-wrap gap-2">
                          <span className="admin-reference-chip">{item.category}</span>
                          <span className="admin-reference-chip">{item.source}</span>
                        </div>
                        <div className="hidden text-[11px] text-black/36 md:block">{formatDateTime(item.publishedAt)}</div>
                      </div>

                      <h3 className="mt-2 truncate text-[20px] font-semibold tracking-[-0.025em] text-[#111827]">
                        {item.title}
                      </h3>
                      <p className="mt-2.5 line-clamp-2 text-[13px] leading-6 text-[#7d8592]">
                        {item.summary || item.body || '暂无摘要。'}
                      </p>
                    </div>

                    <div className="flex shrink-0 items-center gap-2.5 self-start lg:self-center">
                      <Link
                        href={`/admin/content/news/${item.id}/edit`}
                        onClick={(event) => event.stopPropagation()}
                        className="inline-flex h-[44px] items-center justify-center rounded-full bg-[#071110] px-6 text-[14px] font-semibold text-white shadow-[0_6px_16px_rgba(7,17,16,0.15)]"
                      >
                        编辑
                      </Link>
                      <div className="relative" ref={menuOpenNewsId === item.id ? actionMenuRef : null}>
                        <button
                          type="button"
                          onClick={(event) => {
                            event.stopPropagation();
                            setMenuOpenNewsId((current) => (current === item.id ? null : item.id));
                          }}
                          className="inline-flex h-[44px] w-[44px] items-center justify-center rounded-full border border-[#e7ebef] bg-white text-[#111827]"
                          aria-label="More actions"
                        >
                          <Ellipsis className="h-5 w-5" />
                        </button>
                        {menuOpenNewsId === item.id ? (
                          <div
                            className="absolute right-0 top-[52px] z-20 min-w-[148px] rounded-[18px] border border-[#e7ebef] bg-white p-2 shadow-[0_16px_36px_rgba(17,24,39,0.14)]"
                            onClick={(event) => event.stopPropagation()}
                          >
                            <button
                              type="button"
                              onClick={() => requestDeleteNews(item)}
                              className="flex w-full items-center justify-start rounded-[12px] px-3 py-2 text-sm font-semibold text-[#b42318] transition hover:bg-[#fff5f4]"
                            >
                              删除资讯
                            </button>
                          </div>
                        ) : null}
                      </div>
                    </div>
                  </div>
                </article>
              ))}

              {!items.length ? (
                <div className="px-6 py-20 text-center text-sm text-black/48">当前筛选条件下没有匹配的资讯。</div>
              ) : null}
            </div>
          )}

          <div className="mt-6 flex flex-col gap-4 border-t border-[#edf0f2] pt-5 xl:flex-row xl:items-center xl:justify-between">
            <div className="text-[14px] font-medium text-[#6b7280]">
              共 {total.toLocaleString()} 条，当前第 {page} / {Math.max(1, totalPages)} 页
            </div>

            <div className="flex items-center gap-2">
              <button
                type="button"
                disabled={page <= 1}
                onClick={() => setPage((current) => Math.max(1, current - 1))}
                className="inline-flex h-10 w-10 items-center justify-center rounded-full text-[#9ca3af] disabled:cursor-not-allowed disabled:opacity-40"
              >
                <ChevronLeft className="h-5 w-5" />
              </button>

              {visiblePages.map((pageNumber) => (
                <button
                  key={pageNumber}
                  type="button"
                  onClick={() => setPage(pageNumber)}
                  className={`inline-flex h-10 min-w-10 items-center justify-center rounded-full px-3.5 text-[15px] font-semibold ${
                    pageNumber === page ? 'bg-[#071110] text-white' : 'text-[#111827]'
                  }`}
                >
                  {pageNumber}
                </button>
              ))}

              {totalPages > visiblePages[visiblePages.length - 1] ? (
                <>
                  <span className="px-1 text-[18px] text-[#9ca3af]">...</span>
                  <button
                    type="button"
                    onClick={() => setPage(totalPages)}
                    className="inline-flex h-10 min-w-10 items-center justify-center rounded-full px-3.5 text-[15px] font-semibold text-[#111827]"
                  >
                    {totalPages}
                  </button>
                </>
              ) : null}

              <button
                type="button"
                disabled={page >= totalPages}
                onClick={() => setPage((current) => Math.min(totalPages, current + 1))}
                className="inline-flex h-10 w-10 items-center justify-center rounded-full text-[#111827] disabled:cursor-not-allowed disabled:opacity-40"
              >
                <ChevronRight className="h-5 w-5" />
              </button>
            </div>

            <div className="rounded-[14px] border border-[#e8ecef] bg-white px-5 py-2.5 text-[14px] font-semibold text-[#111827]">
              <span>{PAGE_SIZE} 条 / 页</span>
            </div>
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
