'use client';

import { countries, getCountryCode, getEmojiFlag } from 'countries-list';
import Image from 'next/image';
import Link from 'next/link';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ChevronDown, ChevronLeft, ChevronRight, Ellipsis } from 'lucide-react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import AdminSearchField from '@/components/admin/AdminSearchField';
import OverlayImageViewer, { type OverlayImageViewerAsset } from '@/components/admin/OverlayImageViewer';
import {
  organizerCatalogApi,
  OrganizerCatalogItem,
  OrganizerCatalogPagination,
  type OrganizerCatalogSortBy,
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
const ORGANIZER_SORT_OPTIONS: Array<{ value: OrganizerCatalogSortBy; label: string }> = [
  { value: 'updatedAtDesc', label: '最新更新' },
  { value: 'updatedAtAsc', label: '最早更新' },
  { value: 'createdAtDesc', label: '最新创建' },
  { value: 'createdAtAsc', label: '最早创建' },
  { value: 'nameAsc', label: '名称 A-Z' },
  { value: 'nameDesc', label: '名称 Z-A' },
];

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
  { key: 'posts', label: 'Posts', helper: '资讯' },
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

const normalizeAssetType = (value?: string | null): string => String(value || '').trim().toLowerCase();

const resolvePrimaryVisual = (item: OrganizerCatalogItem): string | null => item.avatarUrl || item.backgroundUrl || null;

const resolveCountryLabel = (country?: string | null): string => {
  if (!country || country === 'all') return '全部国家';
  const code = getCountryCode(country);
  const flag = code ? getEmojiFlag(code) : '';
  return flag ? `${flag} ${country}` : country;
};

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

const buildVisiblePages = (page: number, totalPages: number): number[] => {
  const safeTotalPages = Math.max(1, totalPages);
  const start = Math.max(1, Math.min(safeTotalPages - 4, page - 2));
  const end = Math.min(safeTotalPages, start + 4);
  return Array.from({ length: end - start + 1 }, (_, index) => start + index);
};

const mergeById = <T extends { id: string }>(items: T[]): T[] => {
  const seen = new Set<string>();
  return items.filter((item) => {
    if (seen.has(item.id)) return false;
    seen.add(item.id);
    return true;
  });
};

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
      {loading ? '鍔犺浇涓?..' : '鍔犺浇鏇村'}
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
  const [previewAssetIndex, setPreviewAssetIndex] = useState<number | null>(null);

  useEffect(() => {
    setActiveTab('info');
    setEventsState(createOrganizerEventsState());
    setPostsState(createOrganizerPostsState());
    setPreviewAssetIndex(null);
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
          next[key] = {
            ...next[key],
            items: [...page.items].sort((left, right) =>
              key === 'upcoming'
                ? new Date(left.startDate || 0).getTime() - new Date(right.startDate || 0).getTime()
                : new Date(right.startDate || 0).getTime() - new Date(left.startDate || 0).getTime()
            ),
            pagination: page.pagination,
            loading: false,
            loaded: true,
          };
        });
        return next;
      });
    } catch (nextError) {
      const message = nextError instanceof Error ? nextError.message : '娲诲姩鍔犺浇澶辫触';
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
        error: nextError instanceof Error ? nextError.message : '资讯加载失败',
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
  const backgroundImage = resolved?.backgroundUrl || item.backgroundUrl || '';
  const avatarImage = resolved?.avatarUrl || item.avatarUrl || '';
  const backgroundAsset = imageAssets.find((asset) => normalizeAssetType(asset.type) === 'background' && asset.url);
  const avatarAsset = imageAssets.find((asset) => normalizeAssetType(asset.type) === 'avatar' && asset.url);
  const heroImage =
    backgroundImage ||
    backgroundAsset?.url ||
    imageAssets.find((asset) => asset.url && normalizeAssetType(asset.type) !== 'avatar')?.url ||
    avatarImage ||
    avatarAsset?.url ||
    imageAssets[0]?.url ||
    '';
  const links = resolved?.links || [];
  const aliases = compactList(resolved?.aliases);
  const contributors = compactList(resolved?.aliases);
  const previewSeen = new Set<string>();
  const previewAssets: OverlayImageViewerAsset[] = [];
  const pushPreviewAsset = (asset: OverlayImageViewerAsset | null) => {
    if (!asset?.url || previewSeen.has(asset.url)) return;
    previewSeen.add(asset.url);
    previewAssets.push(asset);
  };

  pushPreviewAsset(
    backgroundImage
      ? {
          url: backgroundImage,
          alt: `${primaryName} banner`,
          title: 'Banner',
          subtitle: 'Organizer background',
        }
      : null
  );
  pushPreviewAsset(
    avatarImage
      ? {
          url: avatarImage,
          alt: `${primaryName} avatar`,
          title: 'Avatar',
          subtitle: 'Organizer avatar',
        }
      : null
  );
  imageAssets.forEach((asset) => {
    pushPreviewAsset({
      url: asset.url,
      alt: asset.label || asset.fileName || asset.type || primaryName,
      title: asset.label || asset.fileName || asset.type || 'Asset',
      subtitle: asset.type || 'Organizer asset',
    });
  });

  return (
    <div className="fixed inset-0 z-[80] flex items-center justify-center bg-black/45 p-4" onClick={onClose}>
      <div
        className="relative max-h-[92vh] w-full max-w-[1360px] overflow-hidden rounded-[28px] border border-white/70 bg-[#f7f5ef] shadow-[0_30px_120px_rgba(7,17,16,0.24)]"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="absolute right-6 top-6 z-10 flex items-center gap-2">
          <Link
            href={`/admin/content/organizers/${item.id}/edit`}
            className="inline-flex h-10 items-center rounded-full bg-[#071110] px-4 text-sm font-semibold text-white shadow-[0_8px_20px_rgba(7,17,16,0.16)]"
          >
            编辑主办方
          </Link>
          <button
            type="button"
            onClick={onClose}
            className="inline-flex h-10 w-10 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#6b7280]"
            aria-label="关闭主办方详情"
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
              <div className="relative aspect-[1.42/1]">
                {heroImage ? (
                  <Image src={heroImage} alt={primaryName} fill className="object-cover" sizes="900px" />
                ) : (
                  <div className="flex h-full items-center justify-center text-sm text-[#7b8794]">暂无主视觉</div>
                )}
              </div>
            </button>

            <div className="-mt-10 px-4">
              <div className="rounded-[24px] border border-[#e8eceb] bg-white/96 p-5 shadow-[0_12px_32px_rgba(33,52,47,0.08)]">
                <div className="text-[28px] font-semibold tracking-[-0.04em] text-[#111827]">{primaryName}</div>
                <div className="mt-2 text-sm font-medium text-[#6b7280]">
                  {resolved?.city || item.city || '城市待补充'} 路 {resolved?.country || item.country || '国家待补充'}
                </div>
                {resolved?.tagline || item.tagline ? (
                  <div className="mt-3 text-sm leading-6 text-[#4b5563]">{resolved?.tagline || item.tagline}</div>
                ) : null}
              </div>
            </div>

            <div className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-1">
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

            <div className="mt-5 rounded-[22px] border border-[#e8eceb] bg-white p-5">
              <div className="text-sm font-semibold text-[#111827]">Basic Info</div>
              <div className="mt-4 space-y-3 text-sm text-[#4b5563]">
                <div><span className="font-medium text-[#111827]">ID: </span>{resolved?.id || item.id}</div>
                <div><span className="font-medium text-[#111827]">City: </span>{resolved?.city || item.city || 'Not set'}</div>
                <div><span className="font-medium text-[#111827]">Country: </span>{resolved?.country || item.country || 'Not set'}</div>
                <div><span className="font-medium text-[#111827]">Updated At: </span>{formatDateTime(item.updatedAt)}</div>
                <div><span className="font-medium text-[#111827]">Created At: </span>{formatDateTime(item.createdAt)}</div>
              </div>
            </div>
          </div>

          <div className="p-6">
            <div className="flex items-center justify-between gap-3 pr-[184px]">
              <div>
                <div className="text-xs font-semibold uppercase tracking-[0.14em] text-[#9aa1ad]">Organizer Profile</div>
                <div className="mt-2 text-[26px] font-semibold tracking-[-0.04em] text-[#111827]">主办方详情</div>
              </div>
            </div>

            <div className="mt-6 flex flex-wrap gap-2 rounded-[24px] border border-[#e8eceb] bg-white/70 p-2">
              {ORGANIZER_TABS.map((tab) => (
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
                      const sectionVisiblePages = buildVisiblePages(sectionState.pagination.page, sectionState.pagination.totalPages);
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
                            <div className="mt-4 text-sm text-[#6b7280]">姝ｅ湪鍔犺浇娲诲姩...</div>
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
                                    <div className="mt-1 text-xs text-[#6b7280]">{formatDateOnly(eventItem.startDate)} 路 {[eventItem.city, eventItem.country].filter(Boolean).join(', ') || '地点未设置'}</div>
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
                              <EmptyTabState title="暂无活动" description="这个分组下还没有与该主办方关联的活动。" />
                            </div>
                          )}
                          <div className="mt-4 flex flex-col gap-3 border-t border-[#edf0f2] pt-4 sm:flex-row sm:items-center sm:justify-between">
                            <div className="text-xs text-[#8b93a1]">
                              第 {sectionState.pagination.page} / {Math.max(1, sectionState.pagination.totalPages)} 页 · 共 {sectionState.pagination.total} 场活动
                            </div>
                            <div className="flex flex-wrap items-center gap-2">
                              <button
                                type="button"
                                disabled={sectionState.loading || sectionState.pagination.page <= 1}
                                onClick={() => void loadEvents(sectionState.pagination.page - 1, section)}
                                className="inline-flex h-9 min-w-9 items-center justify-center rounded-full border border-[#e8eceb] bg-white px-3 text-xs font-semibold text-[#111827] disabled:cursor-not-allowed disabled:opacity-40"
                              >
                                Prev
                              </button>
                              {sectionVisiblePages.map((pageNumber) => (
                                <button
                                  key={`${section}-${pageNumber}`}
                                  type="button"
                                  disabled={sectionState.loading}
                                  onClick={() => void loadEvents(pageNumber, section)}
                                  className={`inline-flex h-9 min-w-9 items-center justify-center rounded-full px-3 text-xs font-semibold ${
                                    pageNumber === sectionState.pagination.page
                                      ? 'bg-[#071110] text-white'
                                      : 'border border-[#e8eceb] bg-white text-[#111827]'
                                  }`}
                                >
                                  {pageNumber}
                                </button>
                              ))}
                              <button
                                type="button"
                                disabled={sectionState.loading || sectionState.pagination.page >= Math.max(1, sectionState.pagination.totalPages)}
                                onClick={() => void loadEvents(sectionState.pagination.page + 1, section)}
                                className="inline-flex h-9 min-w-9 items-center justify-center rounded-full border border-[#e8eceb] bg-white px-3 text-xs font-semibold text-[#111827] disabled:cursor-not-allowed disabled:opacity-40"
                              >
                                Next
                              </button>
                            </div>
                          </div>
                        </section>
                      );
                    })}
                  </div>
                ) : null}

                {activeTab === 'posts' ? (
                  <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                    <div className="flex items-center justify-between gap-3">
                      <div>
                        <div className="text-sm font-semibold text-[#111827]">相关资讯</div>
                        <div className="mt-1 text-xs text-[#9aa1ad]">对应 iOS Posts 页</div>
                      </div>
                    </div>
                    {postsState.error ? <div className="mt-4 rounded-[16px] bg-red-50 px-4 py-3 text-sm text-[#7a2d29]">{postsState.error}</div> : null}
                    {postsState.loading && !postsState.items.length ? (
                      <div className="mt-4 text-sm text-[#6b7280]">正在加载资讯...</div>
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
                                <div className="mt-1 text-xs text-[#6b7280]">{article.source || 'Raver'} 路 {formatDateOnly(article.publishedAt)}</div>
                                {article.summary ? <div className="mt-2 line-clamp-2 text-xs leading-5 text-[#6b7280]">{article.summary}</div> : null}
                              </div>
                            </Link>
                          );
                        })}
                      </div>
                    ) : (
                      <div className="mt-4">
                        <EmptyTabState title="暂无相关资讯" description="还没有与该主办方绑定的资讯内容。" />
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

export default function OrganizerCatalogPageClient() {
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [country, setCountry] = useState('all');
  const [sortBy, setSortBy] = useState<OrganizerCatalogSortBy>('updatedAtDesc');
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
  const [menuOpenOrganizerId, setMenuOpenOrganizerId] = useState<string | null>(null);
  const [pendingDeleteOrganizer, setPendingDeleteOrganizer] = useState<OrganizerCatalogItem | null>(null);
  const [deletingOrganizerId, setDeletingOrganizerId] = useState<string | null>(null);
  const actionMenuRef = useRef<HTMLDivElement | null>(null);
  const countryOptions = useMemo(
    () =>
      Object.values(countries)
        .map((item) => item.name)
        .sort((left, right) => left.localeCompare(right, 'en')),
    []
  );
  const selectedSortLabel =
    ORGANIZER_SORT_OPTIONS.find((item) => item.value === sortBy)?.label || '最新更新';

  const loadCatalog = useCallback(async () => {
    try {
      setIsLoading(true);
      setError('');
      const response = await organizerCatalogApi.fetchOrganizers({
        page,
        limit: PAGE_SIZE,
        search: search || undefined,
        country: country === 'all' ? undefined : country,
        sortBy,
      });
      setItems(response.items);
      setPagination(response.pagination);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '主办方目录加载失败，请稍后重试。');
    } finally {
      setIsLoading(false);
    }
  }, [country, page, search, sortBy]);

  useEffect(() => {
    void loadCatalog();
  }, [loadCatalog]);

  useEffect(() => {
    if (!menuOpenOrganizerId) return;

    const handlePointerDown = (event: MouseEvent) => {
      if (!actionMenuRef.current) return;
      if (event.target instanceof Node && actionMenuRef.current.contains(event.target)) return;
      setMenuOpenOrganizerId(null);
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setMenuOpenOrganizerId(null);
      }
    };

    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [menuOpenOrganizerId]);

  const handleSearchSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setPage(1);
    setSearch(searchInput.trim());
  };

  const handleReset = () => {
    setSearchInput('');
    setSearch('');
    setCountry('all');
    setSortBy('updatedAtDesc');
    setPage(1);
  };

  const openDetailOverlay = useCallback(async (item: OrganizerCatalogItem) => {
    setMenuOpenOrganizerId(null);
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
      setSelectedOrganizerError(detailError instanceof Error ? detailError.message : '主办方详情加载失败，请稍后重试。');
    } finally {
      setSelectedOrganizerLoading(false);
    }
  }, [detailCache]);

  const closeDetailOverlay = useCallback(() => {
    setMenuOpenOrganizerId(null);
    setSelectedOrganizer(null);
    setSelectedOrganizerDetail(null);
    setSelectedOrganizerError('');
    setSelectedOrganizerLoading(false);
  }, []);

  const requestDeleteOrganizer = useCallback((item: OrganizerCatalogItem) => {
    setMenuOpenOrganizerId(null);
    setPendingDeleteOrganizer(item);
  }, []);

  const confirmDeleteOrganizer = useCallback(async () => {
    if (!pendingDeleteOrganizer) return;
    const organizerId = pendingDeleteOrganizer.id;
    try {
      setDeletingOrganizerId(organizerId);
      await organizerStudioApi.deleteOrganizer(organizerId);
      setItems((current) => current.filter((item) => item.id !== organizerId));
      setPagination((current) => ({
        ...current,
        total: Math.max(0, current.total - 1),
      }));
      if (selectedOrganizer?.id === organizerId) {
        closeDetailOverlay();
      }
      setPendingDeleteOrganizer(null);
      setDetailCache((current) => {
        const next = { ...current };
        delete next[organizerId];
        return next;
      });
    } catch (deleteError) {
      setError(deleteError instanceof Error ? deleteError.message : '删除主办方失败，请稍后重试。');
    } finally {
      setDeletingOrganizerId(null);
    }
  }, [closeDetailOverlay, pendingDeleteOrganizer, selectedOrganizer]);

  const totalPages = Math.max(1, pagination.totalPages);
  const visiblePages = useMemo(() => {
    const start = Math.max(1, Math.min(totalPages - 4, pagination.page - 2));
    const end = Math.min(totalPages, start + 4);
    return Array.from({ length: end - start + 1 }, (_, index) => start + index);
  }, [pagination.page, totalPages]);

  return (
    <AdminContentLayout
      title="主办方目录中心"
      eyebrow="Admin / Content Workspace / Organizer Catalog"
      actions={
        <>
          <Link
            href="/admin/content/organizers/bindings"
            className="rounded-full border border-[#e9dcff] bg-[#f6f0ff] px-5 py-3 text-sm font-semibold text-[#6d28d9]"
          >
            活动绑定中心
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
      <section className="overflow-hidden rounded-[28px] border border-[#edf0f2] bg-white p-5 shadow-[0_4px_20px_rgba(17,24,39,0.04)]">
        <div className="flex flex-col gap-4">
          <form onSubmit={handleSearchSubmit} className="flex flex-col gap-3 xl:flex-row xl:items-center">
            <AdminSearchField
              value={searchInput}
              onChange={setSearchInput}
              placeholder="主办方名称 / 别名 / 城市 / 国家 / 官方链接"
              size="md"
              className="min-w-0 flex-1"
              submitLabel="搜索目录"
              submitButtonType="submit"
              onClear={handleReset}
            />

            <label className="relative flex h-[48px] min-w-[154px] items-center justify-between rounded-[18px] border border-[#eceff1] bg-white px-5 text-[15px] font-semibold text-[#111827] xl:w-[190px]">
              <span>{resolveCountryLabel(country)}</span>
              <select
                value={country}
                onChange={(event) => {
                  setCountry(event.target.value);
                  setPage(1);
                }}
                className="absolute inset-0 opacity-0"
              >
                <option value="all">全部国家</option>
                {countryOptions.map((item) => (
                  <option key={item} value={item}>
                    {item}
                  </option>
                ))}
              </select>
              <ChevronDown className="h-4.5 w-4.5 text-[#9ca3af]" />
            </label>

            <label className="relative flex h-[48px] min-w-[154px] items-center justify-between rounded-[18px] border border-[#eceff1] bg-white px-5 text-[15px] font-semibold text-[#111827] xl:w-[190px]">
              <span>{selectedSortLabel}</span>
              <select
                value={sortBy}
                onChange={(event) => {
                  setSortBy(event.target.value as OrganizerCatalogSortBy);
                  setPage(1);
                }}
                className="absolute inset-0 opacity-0"
              >
                {ORGANIZER_SORT_OPTIONS.map((item) => (
                  <option key={item.value} value={item.value}>
                    {item.label}
                  </option>
                ))}
              </select>
              <ChevronDown className="h-4.5 w-4.5 text-[#9ca3af]" />
            </label>

            <button
              type="button"
              onClick={handleReset}
              className="inline-flex h-[48px] items-center justify-center rounded-full border border-[#e8eceb] bg-white px-5 text-sm font-semibold text-[#071110] xl:min-w-[112px]"
            >
              清空筛选
            </button>
          </form>

          <div className="flex flex-wrap items-center gap-0 divide-x divide-[#edf0f2]">
            <div className="pr-7 text-sm text-[#6b7280]">
              共 <span className="font-semibold text-[#111827]">{pagination.total.toLocaleString()}</span> 个主办方
            </div>
            <div className="px-7 text-sm text-[#6b7280]">
              当前页 <span className="font-semibold text-[#111827]">{pagination.page}</span> / {Math.max(1, pagination.totalPages)}
            </div>
            <div className="px-7 text-sm text-[#6b7280]">
              国家筛选 <span className="font-semibold text-[#111827]">{resolveCountryLabel(country)}</span>
            </div>
            <div className="pl-7 text-sm text-[#6b7280]">
              排序 <span className="font-semibold text-[#111827]">{selectedSortLabel}</span>
            </div>
          </div>
        </div>
      </section>

      <section className="overflow-hidden rounded-[28px] border border-[#edf0f2] bg-white shadow-[0_4px_20px_rgba(17,24,39,0.04)]">
        {error ? (
          <div className="border-b border-red-200 bg-red-50 px-6 py-4 text-sm text-[#7a2d29]">
            {error}
          </div>
        ) : null}

        {isLoading ? (
          <div className="px-6 py-20 text-center text-sm text-text-secondary">主办方目录加载中...</div>
        ) : items.length === 0 ? (
          <div className="px-6 py-20 text-center text-sm text-text-secondary">当前筛选条件下没有主办方。</div>
        ) : (
          <div className="divide-y divide-[#edf0f2]">
            {items.map((item) => {
              const visualUrl = resolvePrimaryVisual(item);
              return (
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
                  className="flex cursor-pointer flex-col gap-3 px-6 py-4 transition-colors hover:bg-[#fbfcfb] focus:outline-none focus:ring-2 focus:ring-[#d9e7dd] lg:flex-row lg:items-center lg:gap-4"
                >
                  <div className="flex min-w-0 flex-1 gap-4">
                    <div className="relative h-[92px] w-[92px] shrink-0 overflow-hidden rounded-[16px] bg-[#f3f5f7]">
                      {visualUrl ? (
                        <Image
                          src={visualUrl}
                          alt={item.name}
                          width={104}
                          height={104}
                          className="h-full w-full object-cover"
                        />
                      ) : (
                        <div className="flex h-full items-center justify-center bg-[linear-gradient(135deg,#f7efda,#edf7f2)] text-sm text-black/45">
                          暂无主视觉
                        </div>
                      )}
                    </div>

                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="admin-reference-chip">{item.country || '未知国家'}</span>
                        {item.city ? <span className="admin-reference-chip">{item.city}</span> : null}
                      </div>
                      <h3 className="mt-1.5 truncate text-[18px] font-semibold tracking-[-0.025em] text-[#071110]">{item.name}</h3>
                      <p className="mt-1 truncate text-[12px] font-medium text-[#6b7280]">
                        {item.city || '未知城市'} / {item.country || '未知国家'}
                        {item.abbreviation ? ` 路 ${item.abbreviation}` : ''}
                        {typeof item.revision === 'number' ? ` 路 rev ${item.revision}` : ''}
                      </p>
                      {item.tagline ? <p className="mt-1.5 line-clamp-1 text-[12px] leading-5 text-black/55">{item.tagline}</p> : null}
                      {item.aliases?.length ? (
                        <p className="mt-1 line-clamp-1 text-[13px] leading-6 text-black/48">别名：{item.aliases.slice(0, 4).join('、')}</p>
                      ) : null}
                      <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-[12px] font-medium text-[#7d8592]">
                        <span>更新于 {formatDateTime(item.updatedAt)}</span>
                        <span>创建于 {formatDateTime(item.createdAt)}</span>
                      </div>
                    </div>
                  </div>

                  <div className="flex shrink-0 items-center gap-2 overflow-x-auto lg:w-auto lg:max-w-[560px] lg:justify-end">
                    <div className="shrink-0 rounded-[12px] bg-[#f4f5f7] px-3 py-2 text-[11px] leading-4 text-[#6b7280]">
                      目录中心承接查找和跳转，深入资料处理继续进入编辑与绑定工作流。
                    </div>
                    <Link
                      href={`/admin/content/organizers/${item.id}/edit`}
                      onClick={(event) => event.stopPropagation()}
                      className="inline-flex h-[36px] shrink-0 items-center justify-center rounded-full bg-[#071110] px-4 text-center text-sm font-semibold text-white"
                    >
                      编辑主办方
                    </Link>
                    <Link
                      href={`/admin/content/organizers/bindings?organizerId=${encodeURIComponent(item.id)}&organizerName=${encodeURIComponent(item.name)}`}
                      onClick={(event) => event.stopPropagation()}
                      className="inline-flex h-[36px] shrink-0 items-center justify-center rounded-full border border-[#e7ebef] bg-white px-4 text-center text-sm font-semibold text-[#111827]"
                    >
                      打开绑定中心
                    </Link>
                    {item.officialWebsite ? (
                      <a
                        href={item.officialWebsite}
                        target="_blank"
                        rel="noreferrer"
                        onClick={(event) => event.stopPropagation()}
                        className="inline-flex h-[36px] shrink-0 items-center justify-center rounded-full border border-[#e7ebef] bg-white px-4 text-center text-sm font-semibold text-[#111827]"
                      >
                        官方链接
                      </a>
                    ) : (
                      <div className="shrink-0 rounded-full border border-[#e7ebef] bg-white px-4 py-2 text-center text-sm text-black/42">
                        暂无官方链接
                      </div>
                    )}
                    <div className="relative" ref={menuOpenOrganizerId === item.id ? actionMenuRef : null}>
                      <button
                        type="button"
                        onClick={(event) => {
                          event.stopPropagation();
                          setMenuOpenOrganizerId((current) => (current === item.id ? null : item.id));
                        }}
                        className="inline-flex h-[36px] w-[36px] shrink-0 items-center justify-center rounded-full border border-[#e7ebef] bg-white text-[#111827]"
                        aria-label="更多操作"
                      >
                        <Ellipsis className="h-4 w-4" />
                      </button>
                      {menuOpenOrganizerId === item.id ? (
                        <div
                          className="absolute right-0 top-[48px] z-20 min-w-[148px] rounded-[18px] border border-[#e7ebef] bg-white p-2 shadow-[0_16px_36px_rgba(17,24,39,0.14)]"
                          onClick={(event) => event.stopPropagation()}
                        >
                          <button
                            type="button"
                            onClick={() => requestDeleteOrganizer(item)}
                            className="flex w-full items-center justify-start rounded-[12px] px-3 py-2 text-sm font-semibold text-[#b42318] transition hover:bg-[#fff5f4]"
                          >
                            删除主办方
                          </button>
                        </div>
                      ) : null}
                    </div>
                  </div>
                </article>
              );
            })}
          </div>
        )}

        <div className="flex flex-col gap-4 border-t border-[#edf0f2] px-6 py-5 xl:flex-row xl:items-center xl:justify-between">
          <div className="text-[14px] font-medium text-[#6b7280]">
            共 {pagination.total.toLocaleString()} 条
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              disabled={pagination.page <= 1}
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
                  pageNumber === pagination.page ? 'bg-[#071110] text-white' : 'text-[#111827]'
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
              disabled={pagination.page >= totalPages}
              onClick={() => setPage((current) => Math.min(totalPages, current + 1))}
              className="inline-flex h-10 w-10 items-center justify-center rounded-full text-[#111827] disabled:cursor-not-allowed disabled:opacity-40"
            >
              <ChevronRight className="h-5 w-5" />
            </button>
          </div>

          <div className="flex items-center gap-2 rounded-[14px] border border-[#e8ecef] bg-white px-5 py-2.5 text-[14px] font-semibold text-[#111827]">
            <span>{pagination.limit} 条 / 页</span>
          </div>
        </div>
      </section>

      <OrganizerDetailOverlay
        item={selectedOrganizer}
        detail={selectedOrganizerDetail}
        loading={selectedOrganizerLoading}
        error={selectedOrganizerError}
        onClose={closeDetailOverlay}
      />
      {pendingDeleteOrganizer ? (
        <div className="fixed inset-0 z-[90] flex items-center justify-center bg-black/45 p-4" onClick={() => setPendingDeleteOrganizer(null)}>
          <div
            className="w-full max-w-md rounded-[28px] border border-[#e8eceb] bg-white p-6 shadow-[0_24px_72px_rgba(17,24,39,0.18)]"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[#b42318]">删除主办方</div>
            <div className="mt-3 text-[24px] font-semibold tracking-[-0.04em] text-[#111827]">确认删除这个主办方吗？</div>
            <p className="mt-3 text-sm leading-6 text-[#6b7280]">
              {pendingDeleteOrganizer.name}
              <br />
              删除后将无法恢复，请再次确认这是你要执行的操作。
            </p>
            <div className="mt-6 flex justify-end gap-3">
              <button
                type="button"
                onClick={() => setPendingDeleteOrganizer(null)}
                className="inline-flex h-[44px] items-center justify-center rounded-full border border-[#e7ebef] bg-white px-5 text-sm font-semibold text-[#111827]"
              >
                取消
              </button>
              <button
                type="button"
                onClick={() => void confirmDeleteOrganizer()}
                disabled={deletingOrganizerId === pendingDeleteOrganizer.id}
                className="inline-flex h-[44px] items-center justify-center rounded-full bg-[#b42318] px-5 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
              >
                {deletingOrganizerId === pendingDeleteOrganizer.id ? '删除中...' : '确认删除'}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </AdminContentLayout>
  );
}
