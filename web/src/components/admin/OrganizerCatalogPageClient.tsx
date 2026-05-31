'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import {
  organizerCatalogApi,
  OrganizerCatalogItem,
  OrganizerCatalogPagination,
} from '@/features/admin-content/organizer-catalog/api';
import { organizerStudioApi } from '@/features/admin-content/organizer-studio/api';
import type {
  OrganizerStudioLoadedOrganizer,
  OrganizerStudioPagination,
  OrganizerStudioRelatedArticle,
  OrganizerStudioRelatedEvent,
} from '@/features/admin-content/organizer-studio/types';

const PAGE_SIZE = 24;

const EMPTY_PAGINATION: OrganizerCatalogPagination = {
  page: 1,
  limit: PAGE_SIZE,
  total: 0,
  totalPages: 1,
};

const RELATED_EVENTS_LIMIT = 10;
const RELATED_POSTS_LIMIT = 10;

type OrganizerTabKey = 'info' | 'events' | 'posts';

type RelatedSectionState<T> = {
  items: T[];
  pagination: OrganizerStudioPagination;
  loading: boolean;
  error: string;
  loaded: boolean;
};

type OrganizerEventsState = {
  upcoming: RelatedSectionState<OrganizerStudioRelatedEvent>;
  ended: RelatedSectionState<OrganizerStudioRelatedEvent>;
};

type OrganizerPostsState = {
  items: OrganizerStudioRelatedArticle[];
  nextCursor: string | null;
  loading: boolean;
  error: string;
  loaded: boolean;
};

const createRelatedState = <T,>(limit: number): RelatedSectionState<T> => ({
  items: [],
  pagination: {
    page: 1,
    limit,
    total: 0,
    totalPages: 1,
  },
  loading: false,
  error: '',
  loaded: false,
});

const createOrganizerEventsState = (): OrganizerEventsState => ({
  upcoming: createRelatedState<OrganizerStudioRelatedEvent>(RELATED_EVENTS_LIMIT),
  ended: createRelatedState<OrganizerStudioRelatedEvent>(RELATED_EVENTS_LIMIT),
});

const createOrganizerPostsState = (): OrganizerPostsState => ({
  items: [],
  nextCursor: null,
  loading: false,
  error: '',
  loaded: false,
});

const ORGANIZER_TABS: Array<{ key: OrganizerTabKey; label: string; helper: string }> = [
  { key: 'info', label: 'Info', helper: '信息' },
  { key: 'events', label: 'Events', helper: '活动' },
  { key: 'posts', label: 'Posts', helper: '动态' },
];

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

const firstFilledText = (...values: Array<string | null | undefined>): string => {
  for (const value of values) {
    const trimmed = String(value || '').trim();
    if (trimmed) return trimmed;
  }
  return '';
};

const compactList = (value?: Array<string | null> | null): string[] =>
  Array.isArray(value) ? value.map((item) => String(item || '').trim()).filter(Boolean) : [];

const sortedAssets = <T extends { sort?: number | null; order?: number | null }>(items?: T[] | null): T[] =>
  Array.isArray(items)
    ? [...items].sort((left, right) => (left.sort ?? left.order ?? 0) - (right.sort ?? right.order ?? 0))
    : [];

const resolvePrimaryVisual = (item: OrganizerCatalogItem): string | null => item.avatarUrl || item.backgroundUrl || null;

const formatDateOnly = (value?: string | null): string => {
  if (!value) return '日期未记录';
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date(value));
};

const hasNextPage = (pagination: OrganizerStudioPagination): boolean =>
  pagination.page < Math.max(1, pagination.totalPages);

const mergeById = <T extends { id: string }>(items: T[]): T[] => {
  const seen = new Set<string>();
  return items.filter((item) => {
    if (seen.has(item.id)) return false;
    seen.add(item.id);
    return true;
  });
};

function TabButton({
  active,
  label,
  helper,
  onClick,
}: {
  active: boolean;
  label: string;
  helper: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`shrink-0 rounded-full px-4 py-2 text-left transition ${
        active ? 'bg-[#071110] text-white shadow-[0_8px_20px_rgba(7,17,16,0.16)]' : 'text-[#6b7280] hover:bg-white'
      }`}
    >
      <span className="block text-sm font-semibold leading-none">{label}</span>
      <span className={`mt-1 block text-[11px] leading-none ${active ? 'text-white/70' : 'text-[#9aa1ad]'}`}>{helper}</span>
    </button>
  );
}

function EmptyTabState({ title, description }: { title: string; description: string }) {
  return (
    <div className="rounded-[22px] border border-dashed border-[#d8dfdc] bg-white/70 px-5 py-8 text-center">
      <div className="text-sm font-semibold text-[#111827]">{title}</div>
      <div className="mt-2 text-sm leading-6 text-[#6b7280]">{description}</div>
    </div>
  );
}

function LoadMoreButton({
  disabled,
  loading,
  onClick,
}: {
  disabled: boolean;
  loading: boolean;
  onClick: () => void;
}) {
  if (disabled) return null;
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={loading}
      className="mt-4 inline-flex h-10 items-center rounded-full border border-[#d8dfdc] bg-white px-5 text-sm font-semibold text-[#111827] disabled:cursor-not-allowed disabled:opacity-50"
    >
      {loading ? '加载中...' : '加载更多'}
    </button>
  );
}

function OrganizerDetailOverlay({
  item,
  detail,
  loading,
  error,
  onClose,
}: {
  item: OrganizerCatalogItem | null;
  detail: OrganizerStudioLoadedOrganizer | null;
  loading: boolean;
  error: string;
  onClose: () => void;
}) {
  const [activeTab, setActiveTab] = useState<OrganizerTabKey>('info');
  const [eventsState, setEventsState] = useState<OrganizerEventsState>(() => createOrganizerEventsState());
  const [postsState, setPostsState] = useState<OrganizerPostsState>(() => createOrganizerPostsState());

  useEffect(() => {
    setActiveTab('info');
    setEventsState(createOrganizerEventsState());
    setPostsState(createOrganizerPostsState());
  }, [item?.id]);

  const loadEvents = useCallback(async (pageToLoad = 1, section?: 'upcoming' | 'ended') => {
    if (!item?.id) return;
    const sections: Array<'upcoming' | 'ended'> = section ? [section] : ['upcoming', 'ended'];
    setEventsState((current) => {
      const next = { ...current };
      sections.forEach((key) => {
        next[key] = { ...next[key], loading: true, error: '' };
      });
      return next;
    });
    try {
      const feed = await organizerStudioApi.fetchOrganizerEvents(item.id, {
        upcomingPage: pageToLoad,
        upcomingLimit: RELATED_EVENTS_LIMIT,
        endedPage: pageToLoad,
        endedLimit: RELATED_EVENTS_LIMIT,
      });
      setEventsState((current) => {
        const next = { ...current };
        sections.forEach((key) => {
          const page = feed[key];
          const merged = pageToLoad === 1 ? page.items : mergeById([...next[key].items, ...page.items]);
          next[key] = {
            ...next[key],
            items: key === 'upcoming'
              ? merged.sort((left, right) => new Date(left.startDate || 0).getTime() - new Date(right.startDate || 0).getTime())
              : merged.sort((left, right) => new Date(right.startDate || 0).getTime() - new Date(left.startDate || 0).getTime()),
            pagination: page.pagination,
            loading: false,
            loaded: true,
          };
        });
        return next;
      });
    } catch (nextError) {
      const message = nextError instanceof Error ? nextError.message : '活动加载失败';
      setEventsState((current) => {
        const next = { ...current };
        sections.forEach((key) => {
          next[key] = { ...next[key], loading: false, loaded: true, error: message };
        });
        return next;
      });
    }
  }, [item?.id]);

  const loadPosts = useCallback(async (cursor?: string | null) => {
    if (!item?.id) return;
    setPostsState((current) => ({ ...current, loading: true, error: '' }));
    try {
      const page = await organizerStudioApi.fetchOrganizerPosts(item.id, cursor, RELATED_POSTS_LIMIT);
      setPostsState((current) => ({
        items: cursor ? mergeById([...current.items, ...page.items]) : page.items,
        nextCursor: page.nextCursor,
        loading: false,
        loaded: true,
        error: '',
      }));
    } catch (nextError) {
      setPostsState((current) => ({
        ...current,
        loading: false,
        loaded: true,
        error: nextError instanceof Error ? nextError.message : '动态加载失败',
      }));
    }
  }, [item?.id]);

  useEffect(() => {
    if (!item?.id) return;
    if (activeTab === 'events' && !eventsState.upcoming.loaded && !eventsState.ended.loaded && !eventsState.upcoming.loading && !eventsState.ended.loading) {
      void loadEvents(1);
    }
    if (activeTab === 'posts' && !postsState.loaded && !postsState.loading) {
      void loadPosts(null);
    }
  }, [
    activeTab,
    eventsState.ended.loaded,
    eventsState.ended.loading,
    eventsState.upcoming.loaded,
    eventsState.upcoming.loading,
    item?.id,
    loadEvents,
    loadPosts,
    postsState.loaded,
    postsState.loading,
  ]);

  if (!item) return null;

  const resolved = detail ?? null;
  const primaryName =
    firstFilledText(resolved?.nameI18n?.zh, resolved?.nameI18n?.en, resolved?.name, item.name) || item.name;
  const introduction = firstFilledText(
    resolved?.descriptionI18n?.zh,
    resolved?.descriptionI18n?.en,
    resolved?.introduction,
    item.tagline
  );
  const imageAssets = sortedAssets(resolved?.imageAssets);
  const heroImage = resolved?.avatarUrl || item.avatarUrl || resolved?.backgroundUrl || item.backgroundUrl || imageAssets[0]?.url || '';
  const links = resolved?.links || [];
  const aliases = compactList(resolved?.aliases);
  const contributors = compactList(resolved?.aliases);

  return (
    <div className="fixed inset-0 z-[80] flex items-center justify-center bg-black/45 p-4" onClick={onClose}>
      <div
        className="relative max-h-[90vh] w-full max-w-[1040px] overflow-hidden rounded-[28px] border border-white/70 bg-[#f7f5ef] shadow-[0_30px_120px_rgba(7,17,16,0.24)]"
        onClick={(event) => event.stopPropagation()}
      >
        <button
          type="button"
          onClick={onClose}
          className="absolute right-6 top-6 z-10 inline-flex h-10 w-10 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#6b7280]"
          aria-label="关闭主办方详情"
        >
          ×
        </button>

        <div className="grid max-h-[90vh] overflow-y-auto lg:grid-cols-[1.05fr_1.45fr]">
          <div className="border-b border-[#e8eceb] bg-[linear-gradient(180deg,#eef4f0_0%,#f7f5ef_100%)] p-6 lg:border-b-0 lg:border-r">
            <div className="overflow-hidden rounded-[24px] border border-[#dfe7e2] bg-[#e7ece9]">
              <div className="relative aspect-[1.25/1]">
                {heroImage ? (
                  <Image src={heroImage} alt={primaryName} fill className="object-cover" sizes="900px" />
                ) : (
                  <div className="flex h-full items-center justify-center text-sm text-[#7b8794]">暂无主视觉</div>
                )}
              </div>
            </div>

            <div className="-mt-10 px-4">
              <div className="rounded-[24px] border border-[#e8eceb] bg-white/96 p-5 shadow-[0_12px_32px_rgba(33,52,47,0.08)]">
                <div className="text-[28px] font-semibold tracking-[-0.04em] text-[#111827]">{primaryName}</div>
                <div className="mt-2 text-sm font-medium text-[#6b7280]">
                  {resolved?.city || item.city || '城市待补充'} · {resolved?.country || item.country || '国家待补充'}
                </div>
                {resolved?.tagline || item.tagline ? (
                  <div className="mt-3 text-sm leading-6 text-[#4b5563]">{resolved?.tagline || item.tagline}</div>
                ) : null}
              </div>
            </div>

            <div className="mt-5 grid gap-3 sm:grid-cols-2">
              {[
                ['Aliases', aliases.length],
                ['Links', links.length],
                ['Images', imageAssets.length],
                ['Revision', resolved?.revision ?? item.revision ?? 0],
              ].map(([label, value]) => (
                <div key={label} className="rounded-[20px] border border-[#e8eceb] bg-white px-4 py-3">
                  <div className="text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">{label}</div>
                  <div className="mt-2 text-xl font-semibold text-[#111827]">{String(value)}</div>
                </div>
              ))}
            </div>
          </div>

          <div className="p-6">
            <div className="flex items-center justify-between gap-3">
              <div>
                <div className="text-xs font-semibold uppercase tracking-[0.14em] text-[#9aa1ad]">Organizer Profile</div>
                <div className="mt-2 text-[26px] font-semibold tracking-[-0.04em] text-[#111827]">主办方详情</div>
              </div>
              <Link
                href={`/admin/content/organizers/${item.id}/edit`}
                className="inline-flex h-[42px] items-center rounded-full bg-[#071110] px-5 text-sm font-semibold text-white"
              >
                编辑主办方
              </Link>
            </div>

            <div className="mt-5 flex gap-2 overflow-x-auto rounded-full border border-[#e8eceb] bg-white/70 p-1">
              {ORGANIZER_TABS.map((tab) => (
                <TabButton
                  key={tab.key}
                  active={activeTab === tab.key}
                  label={tab.label}
                  helper={tab.helper}
                  onClick={() => setActiveTab(tab.key)}
                />
              ))}
            </div>

            {loading ? (
              <div className="mt-6 rounded-[22px] border border-[#e8eceb] bg-white px-5 py-10 text-sm text-[#6b7280]">
                正在加载主办方完整信息...
              </div>
            ) : error ? (
              <div className="mt-6 rounded-[22px] border border-red-200 bg-red-50 px-5 py-4 text-sm text-[#7a2d29]">
                {error}
              </div>
            ) : (
              <div className="mt-6">
                {activeTab === 'info' ? (
                  <div className="space-y-5">
                    <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                      <div className="text-sm font-semibold text-[#111827]">简介</div>
                      <div className="mt-3 text-sm leading-7 text-[#4b5563]">{introduction || '暂无简介。'}</div>
                    </section>

                    <section className="grid gap-5 lg:grid-cols-2">
                      <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                        <div className="text-sm font-semibold text-[#111827]">基础资料</div>
                        <div className="mt-4 space-y-3 text-sm text-[#4b5563]">
                          <div><span className="font-medium text-[#111827]">ID: </span>{resolved?.id || item.id}</div>
                          <div><span className="font-medium text-[#111827]">Abbreviation: </span>{resolved?.abbreviation || item.abbreviation || '未设置'}</div>
                          <div><span className="font-medium text-[#111827]">Revision: </span>{resolved?.revision ?? item.revision ?? '未设置'}</div>
                          <div><span className="font-medium text-[#111827]">Founded: </span>{resolved?.foundedYear || '未设置'}</div>
                          <div><span className="font-medium text-[#111827]">Frequency: </span>{resolved?.frequency || '未设置'}</div>
                          <div><span className="font-medium text-[#111827]">最近更新: </span>{formatDateTime(item.updatedAt)}</div>
                          <div><span className="font-medium text-[#111827]">创建时间: </span>{formatDateTime(item.createdAt)}</div>
                        </div>
                      </div>

                      <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                        <div className="text-sm font-semibold text-[#111827]">链接</div>
                        <div className="mt-4 space-y-3 text-sm text-[#4b5563]">
                          <div><span className="font-medium text-[#111827]">Official: </span>{resolved?.officialWebsite || '未设置'}</div>
                          <div><span className="font-medium text-[#111827]">Instagram: </span>{resolved?.instagramUrl || '未设置'}</div>
                          <div><span className="font-medium text-[#111827]">Facebook: </span>{resolved?.facebookUrl || '未设置'}</div>
                          <div><span className="font-medium text-[#111827]">Twitter: </span>{resolved?.twitterUrl || '未设置'}</div>
                          <div><span className="font-medium text-[#111827]">YouTube: </span>{resolved?.youtubeUrl || '未设置'}</div>
                          <div><span className="font-medium text-[#111827]">TikTok: </span>{resolved?.tiktokUrl || '未设置'}</div>
                        </div>
                      </div>
                    </section>

                    <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                      <div className="text-sm font-semibold text-[#111827]">外链列表</div>
                      <div className="mt-4 flex flex-wrap gap-2">
                        {links.length ? links.map((link) => (
                          <span key={`${link.title}-${link.url}`} className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">
                            {link.title}: {link.url}
                          </span>
                        )) : <div className="text-sm text-[#6b7280]">暂无外链。</div>}
                      </div>
                    </section>

                    <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                      <div className="text-sm font-semibold text-[#111827]">贡献者</div>
                      <div className="mt-4 flex flex-wrap gap-2">
                        {resolved?.contributors?.length ? resolved.contributors.map((contributor) => (
                          <span key={contributor.id} className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">
                            {contributor.displayName || contributor.username || contributor.id}
                          </span>
                        )) : <div className="text-sm text-[#6b7280]">暂无贡献者。</div>}
                      </div>
                    </section>
                  </div>
                ) : null}

                {activeTab === 'events' ? (
                  <div className="space-y-5">
                    {(['upcoming', 'ended'] as const).map((section) => {
                      const sectionState = eventsState[section];
                      const title = section === 'upcoming' ? '即将开始 / 进行中' : '历史活动';
                      return (
                        <section key={section} className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                          <div className="flex items-center justify-between gap-3">
                            <div>
                              <div className="text-sm font-semibold text-[#111827]">{title}</div>
                              <div className="mt-1 text-xs text-[#9aa1ad]">对应 iOS Events 分组</div>
                            </div>
                            <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#6b7280]">
                              {sectionState.pagination.total} 场
                            </span>
                          </div>
                          {sectionState.error ? <div className="mt-4 rounded-[16px] bg-red-50 px-4 py-3 text-sm text-[#7a2d29]">{sectionState.error}</div> : null}
                          {sectionState.loading && !sectionState.items.length ? (
                            <div className="mt-4 text-sm text-[#6b7280]">正在加载活动...</div>
                          ) : sectionState.items.length ? (
                            <div className="mt-4 space-y-3">
                              {sectionState.items.map((eventItem) => (
                                <Link
                                  key={eventItem.id}
                                  href={`/admin/content/events/${eventItem.id}/edit`}
                                  className="flex gap-3 rounded-[18px] border border-[#edf0f2] bg-[#fafbfb] p-3 transition hover:bg-white"
                                >
                                  <div className="relative h-16 w-20 shrink-0 overflow-hidden rounded-[14px] bg-[#e7ece9]">
                                    {eventItem.coverImageUrl ? (
                                      <Image src={eventItem.coverImageUrl} alt={eventItem.name} fill className="object-cover" sizes="160px" />
                                    ) : null}
                                  </div>
                                  <div className="min-w-0 flex-1">
                                    <div className="truncate text-sm font-semibold text-[#111827]">{eventItem.name}</div>
                                    <div className="mt-1 text-xs text-[#6b7280]">{formatDateOnly(eventItem.startDate)} · {[eventItem.city, eventItem.country].filter(Boolean).join(', ') || '地点未设置'}</div>
                                    <div className="mt-2 flex flex-wrap gap-2">
                                      {eventItem.status ? <span className="rounded-full bg-white px-2.5 py-1 text-[11px] font-semibold text-[#6b7280]">{eventItem.status}</span> : null}
                                      {eventItem.eventType ? <span className="rounded-full bg-white px-2.5 py-1 text-[11px] font-semibold text-[#6b7280]">{eventItem.eventType}</span> : null}
                                    </div>
                                  </div>
                                </Link>
                              ))}
                            </div>
                          ) : (
                            <div className="mt-4">
                              <EmptyTabState title="暂无活动" description="这个分组下还没有主办方相关活动。" />
                            </div>
                          )}
                          <LoadMoreButton
                            disabled={!hasNextPage(sectionState.pagination)}
                            loading={sectionState.loading}
                            onClick={() => void loadEvents(sectionState.pagination.page + 1, section)}
                          />
                        </section>
                      );
                    })}
                  </div>
                ) : null}

                {activeTab === 'posts' ? (
                  <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                    <div className="flex items-center justify-between gap-3">
                      <div>
                        <div className="text-sm font-semibold text-[#111827]">相关动态</div>
                        <div className="mt-1 text-xs text-[#9aa1ad]">对应 iOS Posts 页</div>
                      </div>
                    </div>
                    {postsState.error ? <div className="mt-4 rounded-[16px] bg-red-50 px-4 py-3 text-sm text-[#7a2d29]">{postsState.error}</div> : null}
                    {postsState.loading && !postsState.items.length ? (
                      <div className="mt-4 text-sm text-[#6b7280]">正在加载动态...</div>
                    ) : postsState.items.length ? (
                      <div className="mt-4 space-y-3">
                        {postsState.items.map((article) => {
                          const cover = article.coverImageURL || article.coverImageUrl || '';
                          return (
                            <Link
                              key={article.id}
                              href={`/admin/content/news/${article.id}/edit`}
                              className="flex gap-3 rounded-[18px] border border-[#edf0f2] bg-[#fafbfb] p-3 transition hover:bg-white"
                            >
                              <div className="relative h-16 w-20 shrink-0 overflow-hidden rounded-[14px] bg-[#e7ece9]">
                                {cover ? <Image src={cover} alt={article.title} fill className="object-cover" sizes="160px" /> : null}
                              </div>
                              <div className="min-w-0 flex-1">
                                <div className="line-clamp-2 text-sm font-semibold text-[#111827]">{article.title}</div>
                                <div className="mt-1 text-xs text-[#6b7280]">{article.source || 'Raver'} · {formatDateOnly(article.publishedAt)}</div>
                                {article.summary ? <div className="mt-2 line-clamp-2 text-xs leading-5 text-[#6b7280]">{article.summary}</div> : null}
                              </div>
                            </Link>
                          );
                        })}
                      </div>
                    ) : (
                      <div className="mt-4">
                        <EmptyTabState title="暂无相关动态" description="还没有与该主办方绑定的新闻内容。" />
                      </div>
                    )}
                    <LoadMoreButton
                      disabled={!postsState.nextCursor}
                      loading={postsState.loading}
                      onClick={() => void loadPosts(postsState.nextCursor)}
                    />
                  </section>
                ) : null}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default function OrganizerCatalogPageClient() {
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [items, setItems] = useState<OrganizerCatalogItem[]>([]);
  const [pagination, setPagination] = useState<OrganizerCatalogPagination>(EMPTY_PAGINATION);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedOrganizer, setSelectedOrganizer] = useState<OrganizerCatalogItem | null>(null);
  const [selectedOrganizerDetail, setSelectedOrganizerDetail] = useState<OrganizerStudioLoadedOrganizer | null>(null);
  const [selectedOrganizerError, setSelectedOrganizerError] = useState('');
  const [selectedOrganizerLoading, setSelectedOrganizerLoading] = useState(false);
  const [detailCache, setDetailCache] = useState<Record<string, OrganizerStudioLoadedOrganizer>>({});

  const loadCatalog = useCallback(async () => {
    try {
      setIsLoading(true);
      setError('');
      const response = await organizerCatalogApi.fetchOrganizers({
        page,
        limit: PAGE_SIZE,
        search: search || undefined,
      });
      setItems(response.items);
      setPagination(response.pagination);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '主办方目录加载失败');
    } finally {
      setIsLoading(false);
    }
  }, [page, search]);

  useEffect(() => {
    void loadCatalog();
  }, [loadCatalog]);

  const handleSearchSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setPage(1);
    setSearch(searchInput.trim());
  };

  const handleReset = () => {
    setSearchInput('');
    setSearch('');
    setPage(1);
  };

  const openDetailOverlay = useCallback(async (item: OrganizerCatalogItem) => {
    setSelectedOrganizer(item);
    setSelectedOrganizerError('');
    const cached = detailCache[item.id];
    if (cached) {
      setSelectedOrganizerDetail(cached);
      setSelectedOrganizerLoading(false);
      return;
    }

    setSelectedOrganizerDetail(null);
    setSelectedOrganizerLoading(true);
    try {
      const detail = await organizerStudioApi.fetchOrganizer(item.id);
      setDetailCache((current) => ({ ...current, [item.id]: detail }));
      setSelectedOrganizerDetail(detail);
    } catch (detailError) {
      setSelectedOrganizerError(detailError instanceof Error ? detailError.message : '主办方详情加载失败');
    } finally {
      setSelectedOrganizerLoading(false);
    }
  }, [detailCache]);

  const closeDetailOverlay = useCallback(() => {
    setSelectedOrganizer(null);
    setSelectedOrganizerDetail(null);
    setSelectedOrganizerError('');
    setSelectedOrganizerLoading(false);
  }, []);

  return (
    <AdminContentLayout
      title="主办方目录中心"
      eyebrow="Admin / Content Workspace / Organizer Catalog"
      description="统一查看主办方目录、资料摘要、绑定入口与编辑入口。目录层保持轻量检索，进入编辑或绑定时再进入更深的操作流。"
      actions={
        <>
          <Link href="/admin/content/organizers" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            返回主办方工作区
          </Link>
          <button
            type="button"
            onClick={() => void loadCatalog()}
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            刷新目录
          </button>
          <Link href="/admin/content/organizers/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            新建主办方
          </Link>
        </>
      }
    >
      <section className="grid gap-5 xl:grid-cols-[1.35fr_0.95fr]">
        <div className="admin-reference-card p-6">
          <div className="text-[11px] uppercase tracking-[0.18em] text-black/35">Catalog Scope</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">目录、编辑、绑定统一入口</h2>
          <div className="mt-5 grid gap-3 md:grid-cols-3">
            {[
              { title: '目录定位', body: '目录层优先承接名称、地区、视觉和链接的全量定位能力。', tone: 'bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)]' },
              { title: '编辑主链路', body: '进入编辑页后继续沿用已落地的 Organizer Studio create / edit 主链路。', tone: 'bg-[linear-gradient(180deg,#f7efda_0%,#ffffff_100%)]' },
              { title: '绑定中心', body: '活动绑定关系继续通过统一后台活动绑定中心处理。', tone: 'bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)]' },
            ].map((item) => (
              <div key={item.title} className={`admin-reference-pastel-card p-4 ${item.tone}`}>
                <div className="text-xs font-bold uppercase tracking-[0.18em] text-black/35">{item.title}</div>
                <div className="mt-5 text-sm leading-6 text-[#24312d]">{item.body}</div>
              </div>
            ))}
          </div>
        </div>

        <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-6">
          <div className="text-[11px] uppercase tracking-[0.18em] text-black/35">Catalog Snapshot</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">目录概览</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-black/55">
            <p>当前页：{pagination.page} / {pagination.totalPages}</p>
            <p>目录总量：{pagination.total.toLocaleString()} 个主办方</p>
            <p>当前策略：目录先轻量定位，深入修改再进入编辑页。</p>
            <p>当前目标：让 Organizer Catalog / New / Edit 成为统一后台内可直接使用的主链路。</p>
          </div>
        </div>
      </section>

      <section className="admin-reference-card p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <form onSubmit={handleSearchSubmit} className="grid flex-1 gap-3 md:grid-cols-[minmax(0,1.7fr)_auto_auto]">
            <label className="space-y-2">
              <span className="text-xs uppercase tracking-[0.2em] text-black/35">搜索关键词</span>
              <input
                value={searchInput}
                onChange={(event) => setSearchInput(event.target.value)}
                placeholder="主办方名称 / 别名 / 城市 / 国家 / 官方链接"
                className="w-full rounded-full px-4 py-3 text-sm"
              />
            </label>
            <button type="submit" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
              搜索目录
            </button>
            <button
              type="button"
              onClick={handleReset}
              className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
            >
              清空筛选
            </button>
          </form>

          <div className="admin-reference-soft-card px-4 py-3 text-sm text-black/50">
            当前目录中心直接对齐 `/v1/learn/festivals`，不再依赖旧 Brand 页面做查找入口。
          </div>
        </div>
      </section>

      <section className="admin-reference-card p-6">
        {error ? (
          <div className="rounded-[18px] border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-[#7a2d29]">
            {error}
          </div>
        ) : null}

        {isLoading ? (
          <div className="py-20 text-center text-sm text-text-secondary">主办方目录加载中...</div>
        ) : items.length === 0 ? (
          <div className="py-20 text-center text-sm text-text-secondary">当前筛选条件下没有主办方。</div>
        ) : (
          <div className="space-y-4">
            {items.map((item) => {
              const visualUrl = resolvePrimaryVisual(item);
              return (
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
                  className="grid cursor-pointer gap-4 rounded-[28px] border border-[#e8eceb] bg-[#fcfcfb] p-5 transition-colors hover:bg-[#fafaf8] focus:outline-none focus:ring-2 focus:ring-[#d9e7dd] lg:grid-cols-[148px_minmax(0,1fr)_230px]"
                >
                  <div className="relative overflow-hidden rounded-[22px] border border-[#e8eceb] bg-[#f5f5f7]">
                    {visualUrl ? (
                      <Image
                        src={visualUrl}
                        alt={item.name}
                        width={280}
                        height={180}
                        className="h-full min-h-[110px] w-full object-cover"
                      />
                    ) : (
                      <div className="flex h-full min-h-[110px] items-center justify-center bg-[linear-gradient(135deg,#f7efda,#edf7f2)] text-sm text-black/45">
                        暂无主视觉
                      </div>
                    )}
                  </div>

                  <div className="min-w-0">
                    <div className="flex flex-wrap gap-2">
                      <span className="admin-reference-chip">{item.country || '未知国家'}</span>
                      {item.city ? <span className="admin-reference-chip">{item.city}</span> : null}
                    </div>
                    <h3 className="mt-3 text-xl font-semibold text-[#071110]">{item.name}</h3>
                    <p className="mt-2 text-sm leading-6 text-black/52">
                      {item.city || '未知城市'} / {item.country || '未知国家'}
                      {item.abbreviation ? ` · ${item.abbreviation}` : ''}
                      {typeof item.revision === 'number' ? ` · rev ${item.revision}` : ''}
                    </p>
                    {item.tagline ? <p className="mt-2 text-sm leading-6 text-black/52">{item.tagline}</p> : null}
                    {item.aliases?.length ? (
                      <p className="mt-2 text-sm leading-6 text-black/52">别名：{item.aliases.slice(0, 4).join('、')}</p>
                    ) : null}
                    <div className="mt-4 grid gap-3 md:grid-cols-2">
                      <div className="admin-reference-soft-card px-4 py-3 text-sm">
                        <div className="text-black/42">更新时间</div>
                        <div className="mt-1 font-semibold text-[#071110]">{formatDateTime(item.updatedAt)}</div>
                      </div>
                      <div className="admin-reference-soft-card px-4 py-3 text-sm">
                        <div className="text-black/42">创建时间</div>
                        <div className="mt-1 font-semibold text-[#071110]">{formatDateTime(item.createdAt)}</div>
                      </div>
                    </div>
                  </div>

                  <div className="admin-reference-soft-card grid gap-3 p-4">
                    <div className="text-sm leading-6 text-black/48">
                      目录中心承接查找和跳转，深入资料处理继续进入编辑与绑定工作流。
                    </div>
                    <Link
                      href={`/admin/content/organizers/${item.id}/edit`}
                      onClick={(event) => event.stopPropagation()}
                      className="rounded-full bg-[#071110] px-4 py-3 text-center text-sm font-semibold text-white"
                    >
                      编辑主办方
                    </Link>
                    <Link
                      href={`/admin/content/organizers/bindings?organizerId=${encodeURIComponent(item.id)}&organizerName=${encodeURIComponent(item.name)}`}
                      onClick={(event) => event.stopPropagation()}
                      className="rounded-full border border-[#e8eceb] bg-white px-4 py-3 text-center text-sm font-semibold text-[#071110]"
                    >
                      打开绑定中心
                    </Link>
                    {item.officialWebsite ? (
                      <a
                        href={item.officialWebsite}
                        target="_blank"
                        rel="noreferrer"
                        onClick={(event) => event.stopPropagation()}
                        className="rounded-full border border-[#e8eceb] bg-white px-4 py-3 text-center text-sm font-semibold text-[#071110]"
                      >
                        官方链接
                      </a>
                    ) : (
                      <div className="rounded-full border border-[#e8eceb] bg-white px-4 py-3 text-center text-sm text-black/42">
                        暂无官方链接
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}

        <div className="mt-6 flex justify-end gap-3 border-t border-white/5 pt-6">
          <button
            type="button"
            disabled={pagination.page <= 1}
            onClick={() => setPage((current) => Math.max(1, current - 1))}
            className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
          >
            上一页
          </button>
          <button
            type="button"
            disabled={pagination.page >= pagination.totalPages}
            onClick={() => setPage((current) => Math.min(pagination.totalPages, current + 1))}
            className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
          >
            下一页
          </button>
        </div>
      </section>

      <OrganizerDetailOverlay
        item={selectedOrganizer}
        detail={selectedOrganizerDetail}
        loading={selectedOrganizerLoading}
        error={selectedOrganizerError}
        onClose={closeDetailOverlay}
      />
    </AdminContentLayout>
  );
}
