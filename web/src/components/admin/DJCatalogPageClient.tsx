'use client';

import { getCountryCode, getEmojiFlag } from 'countries-list';
import Image from 'next/image';
import Link from 'next/link';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Download,
  Ellipsis,
  Filter,
  Headphones,
  Plus,
  RefreshCw,
  Search,
  Upload,
} from 'lucide-react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import OverlayImageViewer, { type OverlayImageViewerAsset } from '@/components/admin/OverlayImageViewer';
import {
  adminCatalogApi,
  AdminCatalogPagination,
  DJCatalogFilters,
  DJCatalogItem,
  DJCatalogResponse,
  DJCatalogSummary,
} from '@/features/admin-content/catalog/api';
import { djStudioApi } from '@/features/admin-content/dj-studio/api';
import type {
  DJStudioLoadedDJ,
  DJStudioPagination,
  DJStudioRatingUnit,
  DJStudioRelatedArticle,
  DJStudioRelatedEvent,
  DJStudioRelatedSet,
} from '@/features/admin-content/dj-studio/types';
import {
  buildAdminCatalogCacheKey,
  clearAdminCatalogCache,
  readAdminCatalogCache,
  writeAdminCatalogCache,
} from '@/features/admin-content/catalog/cache';

const PAGE_SIZE = 20;
const CACHE_TTL_MS = 15 * 60 * 1000;

const EMPTY_PAGINATION: AdminCatalogPagination = {
  page: 1,
  limit: PAGE_SIZE,
  total: 0,
  totalPages: 1,
};

const RELATED_PAGE_SIZE = {
  events: 8,
  ratings: 10,
  posts: 10,
  sets: 10,
};

type DJDetailTabKey = 'intro' | 'events' | 'ratings' | 'posts' | 'sets';

type DJRelatedSectionState<T> = {
  items: T[];
  pagination: DJStudioPagination;
  loading: boolean;
  error: string;
  loaded: boolean;
};

type DJEventSectionsState = {
  upcoming: DJRelatedSectionState<DJStudioRelatedEvent>;
  ended: DJRelatedSectionState<DJStudioRelatedEvent>;
};

type DJPostsState = {
  items: DJStudioRelatedArticle[];
  nextCursor: string | null;
  loading: boolean;
  error: string;
  loaded: boolean;
};

const createRelatedState = <T,>(limit: number): DJRelatedSectionState<T> => ({
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

const createEventSectionsState = (): DJEventSectionsState => ({
  upcoming: createRelatedState<DJStudioRelatedEvent>(RELATED_PAGE_SIZE.events),
  ended: createRelatedState<DJStudioRelatedEvent>(RELATED_PAGE_SIZE.events),
});

const createPostsState = (): DJPostsState => ({
  items: [],
  nextCursor: null,
  loading: false,
  error: '',
  loaded: false,
});

const DJ_DETAIL_TABS: Array<{ key: DJDetailTabKey; label: string; helper: string }> = [
  { key: 'intro', label: 'Intro', helper: '绠€浠? },
  { key: 'events', label: 'Events', helper: '娲诲姩' },
  { key: 'ratings', label: 'Ratings', helper: '璇勫垎' },
  { key: 'posts', label: 'Posts', helper: '鍔ㄦ€? },
  { key: 'sets', label: 'Sets', helper: '婕斿嚭' },
];

const formatDateTime = (value?: string | null): string => {
  if (!value) return '鏈褰?;
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
};

const formatDateCell = (value?: string | null): { date: string; time: string } => {
  if (!value) return { date: '鏈褰?, time: '' };
  const formatted = formatDateTime(value);
  const [date, time] = formatted.split(' ');
  return { date: date || '鏈褰?, time: time || '' };
};

const formatFollowers = (value?: number | null): string => {
  if (typeof value !== 'number' || !Number.isFinite(value)) return '鏈悓姝?;
  return new Intl.NumberFormat('zh-CN').format(value);
};

const formatCompactNumber = (value?: number | null): string => {
  if (typeof value !== 'number' || !Number.isFinite(value)) return '0';
  return new Intl.NumberFormat('zh-CN', { notation: 'compact', maximumFractionDigits: 1 }).format(value);
};

const formatDateOnly = (value?: string | null): string => {
  if (!value) return '鏃ユ湡鏈褰?;
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date(value));
};

const formatDuration = (value?: number | string | null): string => {
  const seconds = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(seconds) || seconds <= 0) return '';
  const total = Math.round(seconds);
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const rest = total % 60;
  return hours > 0
    ? `${hours}:${String(minutes).padStart(2, '0')}:${String(rest).padStart(2, '0')}`
    : `${minutes}:${String(rest).padStart(2, '0')}`;
};

const formatPercentage = (value: number, total: number): string => {
  if (!total) return '0%';
  return `${((value / total) * 100).toFixed(1)}%`;
};

const isDJIncomplete = (item: DJCatalogItem): boolean =>
  !item.avatarUrl || !item.bio || !item.country || !Array.isArray(item.genres) || item.genres.length === 0;

const resolveDJState = (item: DJCatalogItem): { label: string; tone: string } => {
  if (item.isVerified) {
    return { label: '宸查獙璇?, tone: 'border-[#c6e8c8] bg-[#eef8ee] text-[#2f8b4f]' };
  }
  if (isDJIncomplete(item)) {
    return { label: '璧勬枡寰呭畬鍠?, tone: 'border-[#c8d9fb] bg-[#eef2ff] text-[#4267c7]' };
  }
  return { label: '鏈獙璇?, tone: 'border-[#f0dfaf] bg-[#fff9ec] text-[#b57a12]' };
};

const resolveCountryDisplay = (country?: string | null): { flag: string | null; label: string } => {
  if (!country) return { flag: null, label: '寰呰ˉ鍏? };
  const code = getCountryCode(country);
  return {
    flag: code ? getEmojiFlag(code) : null,
    label: country, // 鈶?鏄剧ず瀹屾暣鍥藉鍚?
  };
};

const resolveTagPills = (item: DJCatalogItem): string[] => {
  const genres = Array.isArray(item.genres) ? item.genres : [];
  const aliases = Array.isArray(item.aliases) ? item.aliases : [];
  const tags = [...genres, ...aliases].map((entry) => entry.trim()).filter(Boolean);
  if (!tags.length) return ['璧勬枡鏍囩寰呰ˉ鍏?];
  return Array.from(new Set(tags)).slice(0, 2);
};

const firstFilledText = (...values: Array<string | null | undefined>): string => {
  for (const value of values) {
    const trimmed = String(value || '').trim();
    if (trimmed) return trimmed;
  }
  return '';
};

const compactTextList = (value?: string[] | null): string[] =>
  Array.isArray(value) ? value.map((item) => item.trim()).filter(Boolean) : [];

const detailLinks = (detail: DJStudioLoadedDJ) =>
  [
    { label: 'Spotify', value: detail.spotifyUrl, id: detail.spotifyId },
    { label: 'Instagram', value: detail.instagramUrl },
    { label: 'SoundCloud', value: detail.soundcloudUrl, id: detail.soundcloudId },
    { label: 'Apple Music', value: detail.appleMusicId ? `music.apple.com/artist/${detail.appleMusicId}` : null, id: detail.appleMusicId },
    { label: 'Facebook', value: detail.facebookUrl },
    { label: 'X / Twitter', value: detail.twitterUrl },
    { label: 'YouTube', value: detail.youtubeUrl },
    { label: 'Netease', value: detail.neteaseUrl },
    { label: 'QQ Music', value: detail.qqMusicUrl },
    { label: 'Website', value: detail.website },
    { label: 'Other', value: detail.otherPlatformUrl },
  ].filter((item) => item.value || item.id);

const hasNextPage = (pagination: DJStudioPagination): boolean =>
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

const detailText = (label: string, value?: string | number | null) => (
  <div>
    <span className="font-medium text-[#111827]">{label}: </span>
    {value === undefined || value === null || value === '' ? '鏈缃? : value}
  </div>
);

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

function DJDetailOverlay({
  item,
  detail,
  loading,
  error,
  onClose,
}: {
  item: DJCatalogItem | null;
  detail: DJStudioLoadedDJ | null;
  loading: boolean;
  error: string;
  onClose: () => void;
}) {
  const [activeTab, setActiveTab] = useState<DJDetailTabKey>('intro');
  const [previewAssetIndex, setPreviewAssetIndex] = useState<number | null>(null);
  const [setsState, setSetsState] = useState(() => createRelatedState<DJStudioRelatedSet>(RELATED_PAGE_SIZE.sets));
  const [eventsState, setEventsState] = useState<DJEventSectionsState>(() => createEventSectionsState());
  const [ratingsState, setRatingsState] = useState(() => createRelatedState<DJStudioRatingUnit>(RELATED_PAGE_SIZE.ratings));
  const [postsState, setPostsState] = useState<DJPostsState>(() => createPostsState());

  useEffect(() => {
    setActiveTab('intro');
    setPreviewAssetIndex(null);
    setSetsState(createRelatedState<DJStudioRelatedSet>(RELATED_PAGE_SIZE.sets));
    setEventsState(createEventSectionsState());
    setRatingsState(createRelatedState<DJStudioRatingUnit>(RELATED_PAGE_SIZE.ratings));
    setPostsState(createPostsState());
  }, [item?.id]);

  const loadSets = useCallback(async (pageToLoad = 1) => {
    if (!item?.id) return;
    setSetsState((current) => ({ ...current, loading: true, error: '' }));
    try {
      const page = await djStudioApi.fetchDJSets(item.id, pageToLoad, RELATED_PAGE_SIZE.sets);
      setSetsState((current) => ({
        ...current,
        items: pageToLoad === 1 ? page.items : mergeById([...current.items, ...page.items]),
        pagination: page.pagination,
        loading: false,
        loaded: true,
      }));
    } catch (nextError) {
      setSetsState((current) => ({
        ...current,
        loading: false,
        loaded: true,
        error: nextError instanceof Error ? nextError.message : 'Sets 鍔犺浇澶辫触',
      }));
    }
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
      const results = await Promise.all(
        sections.map(async (key) => ({
          key,
          page: await djStudioApi.fetchDJEvents(
            item.id,
            pageToLoad,
            RELATED_PAGE_SIZE.events,
            key === 'upcoming' ? ['ongoing', 'upcoming'] : ['ended', 'cancelled', 'canceled']
          ),
        }))
      );
      setEventsState((current) => {
        const next = { ...current };
        results.forEach(({ key, page }) => {
          const sortedItems = [...page.items].sort((left, right) =>
            key === 'upcoming'
              ? new Date(left.startDate || 0).getTime() - new Date(right.startDate || 0).getTime()
              : new Date(right.startDate || 0).getTime() - new Date(left.startDate || 0).getTime()
          );
          next[key] = {
            ...next[key],
            items: sortedItems,
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

  const loadRatings = useCallback(async (pageToLoad = 1) => {
    if (!item?.id) return;
    setRatingsState((current) => ({ ...current, loading: true, error: '' }));
    try {
      const page = await djStudioApi.fetchDJRatingUnits(item.id, pageToLoad, RELATED_PAGE_SIZE.ratings);
      setRatingsState((current) => ({
        ...current,
        items: pageToLoad === 1 ? page.items : mergeById([...current.items, ...page.items]),
        pagination: page.pagination,
        loading: false,
        loaded: true,
      }));
    } catch (nextError) {
      setRatingsState((current) => ({
        ...current,
        loading: false,
        loaded: true,
        error: nextError instanceof Error ? nextError.message : '璇勫垎鍗曞厓鍔犺浇澶辫触',
      }));
    }
  }, [item?.id]);

  const loadPosts = useCallback(async (cursor?: string | null) => {
    if (!item?.id) return;
    setPostsState((current) => ({ ...current, loading: true, error: '' }));
    try {
      const page = await djStudioApi.fetchDJRelatedArticles(item.id, cursor, RELATED_PAGE_SIZE.posts);
      setPostsState((current) => ({
        items: cursor ? mergeById([...current.items, ...page.items]) : page.items,
        nextCursor: page.nextCursor ?? null,
        loading: false,
        loaded: true,
        error: '',
      }));
    } catch (nextError) {
      setPostsState((current) => ({
        ...current,
        loading: false,
        loaded: true,
        error: nextError instanceof Error ? nextError.message : '鍔ㄦ€佸姞杞藉け璐?,
      }));
    }
  }, [item?.id]);

  useEffect(() => {
    if (!item?.id) return;
    if (activeTab === 'sets' && !setsState.loaded && !setsState.loading) {
      void loadSets(1);
    }
    if (activeTab === 'events' && !eventsState.upcoming.loaded && !eventsState.ended.loaded && !eventsState.upcoming.loading && !eventsState.ended.loading) {
      void loadEvents(1);
    }
    if (activeTab === 'ratings' && !ratingsState.loaded && !ratingsState.loading) {
      void loadRatings(1);
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
    loadRatings,
    loadSets,
    postsState.loaded,
    postsState.loading,
    ratingsState.loaded,
    ratingsState.loading,
    setsState.loaded,
    setsState.loading,
  ]);

  if (!item) return null;

  const resolved = detail ?? null;
  const state = resolveDJState(item);
  const aliases = compactTextList(resolved?.aliases ?? item.aliases);
  const genres = compactTextList(resolved?.genres ?? item.genres);
  const countryDisplay = resolveCountryDisplay(resolved?.country ?? item.country);
  const bioText = firstFilledText(
    resolved?.bioI18n?.zh,
    resolved?.bioI18n?.en,
    resolved?.bio,
    item.bio
  );
  const primaryName = firstFilledText(resolved?.nameI18n?.zh, resolved?.nameI18n?.en, resolved?.name, item.name) || item.name;
  const secondaryName = firstFilledText(
    resolved?.nameI18n?.en && resolved?.nameI18n?.en !== primaryName ? resolved.nameI18n.en : '',
    resolved?.slug
  );
  const linkItems = resolved ? detailLinks(resolved) : [];
  const previewAssets: OverlayImageViewerAsset[] = [
    ...(resolved?.bannerUrl || item.bannerUrl
      ? [
          {
            url: resolved?.bannerUrl || item.bannerUrl || '',
            alt: `${primaryName} banner`,
            title: 'Banner',
            subtitle: 'DJ banner',
          },
        ]
      : []),
    ...(resolved?.avatarUrl || item.avatarUrl
      ? [
          {
            url: resolved?.avatarUrl || item.avatarUrl || '',
            alt: `${primaryName} avatar`,
            title: 'Avatar',
            subtitle: 'DJ avatar',
          },
        ]
      : []),
  ];
  const contributors: Array<{
    id: string;
    username?: string | null;
    displayName?: string | null;
    avatarUrl?: string | null;
  }> = Array.isArray(resolved?.contributors)
    ? resolved.contributors
    : compactTextList(resolved?.contributorUsernames).map((username) => ({ id: username, username }));

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
          aria-label="鍏抽棴 DJ 璇︽儏"
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
              <div className="relative aspect-[1.2/1]">
                {resolved?.bannerUrl || item.bannerUrl ? (
                  <Image
                    src={resolved?.bannerUrl || item.bannerUrl || ''}
                    alt={primaryName}
                    fill
                    className="object-cover"
                    sizes="900px"
                  />
                ) : (
                  <div className="flex h-full items-center justify-center text-sm text-[#7b8794]">鏆傛棤 Banner</div>
                )}
              </div>
            </button>

            <div className="-mt-10 px-4">
              <div className="flex items-end gap-4 rounded-[24px] border border-[#e8eceb] bg-white/96 p-4 shadow-[0_12px_32px_rgba(33,52,47,0.08)]">
                <button
                  type="button"
                  onClick={() => {
                    const avatarIndex = previewAssets.findIndex((asset) => asset.url === (resolved?.avatarUrl || item.avatarUrl || ''));
                    if (avatarIndex >= 0) setPreviewAssetIndex(avatarIndex);
                  }}
                  className="flex h-[92px] w-[92px] shrink-0 items-center justify-center overflow-hidden rounded-[22px] bg-[#f1f4f6]"
                >
                  {resolved?.avatarUrl || item.avatarUrl ? (
                    <Image
                      src={resolved?.avatarUrl || item.avatarUrl || ''}
                      alt={primaryName}
                      width={92}
                      height={92}
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <span className="text-xs text-[#9aa1ad]">鏆傛棤澶村儚</span>
                  )}
                </button>
                <div className="min-w-0 flex-1">
                  <div className="text-[24px] font-semibold tracking-[-0.04em] text-[#111827]">{primaryName}</div>
                  {secondaryName ? <div className="mt-1 text-sm text-[#6b7280]">{secondaryName}</div> : null}
                  <div className="mt-3 flex flex-wrap items-center gap-2">
                    <span className={`inline-flex rounded-full border px-3 py-1 text-[12px] font-semibold ${state.tone}`}>
                      {state.label}
                    </span>
                    {countryDisplay.flag ? <span className="text-[18px] leading-none">{countryDisplay.flag}</span> : null}
                    <span className="text-sm font-medium text-[#374151]">{countryDisplay.label}</span>
                  </div>
                </div>
              </div>
            </div>

            <div className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-1">
              <div className="rounded-[20px] border border-[#e8eceb] bg-white px-4 py-3">
                <div className="text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">骞冲彴绮変笣</div>
                <div className="mt-2 text-xl font-semibold text-[#111827]">
                  {formatFollowers(item.followerCount ?? item.soundCloudFollowers)}
                </div>
              </div>
              <div className="rounded-[20px] border border-[#e8eceb] bg-white px-4 py-3">
                <div className="text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">Spotify 绮変笣</div>
                <div className="mt-2 text-xl font-semibold text-[#111827]">
                  {formatFollowers(resolved?.spotifyFollowers ?? null)}
                </div>
              </div>
              <div className="rounded-[20px] border border-[#e8eceb] bg-white px-4 py-3">
                <div className="text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">鏇茬洰鏁?/div>
                <div className="mt-2 text-xl font-semibold text-[#111827]">
                  {typeof resolved?.trackCount === 'number' ? resolved.trackCount.toLocaleString() : '鏈悓姝?}
                </div>
              </div>
              <div className="rounded-[20px] border border-[#e8eceb] bg-white px-4 py-3">
                <div className="text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">姝屽崟鏁?/div>
                <div className="mt-2 text-xl font-semibold text-[#111827]">
                  {typeof resolved?.playlistCount === 'number' ? resolved.playlistCount.toLocaleString() : '鏈悓姝?}
                </div>
              </div>
            </div>

            <div className="mt-5 rounded-[22px] border border-[#e8eceb] bg-white p-5">
              <div className="text-sm font-semibold text-[#111827]">Basic Info</div>
              <div className="mt-4 space-y-3 text-sm text-[#4b5563]">
                {detailText('ID', resolved?.id || item.id)}
                {detailText('Country', countryDisplay.label)}
                {detailText('Slug', resolved?.slug)}
                {detailText('Updated At', formatDateTime(item.updatedAt))}
                {detailText('Created At', formatDateTime(item.createdAt))}
              </div>
            </div>
          </div>

          <div className="p-6">
            <div className="flex items-center justify-between gap-3">
              <div>
                <div className="text-xs font-semibold uppercase tracking-[0.14em] text-[#9aa1ad]">DJ Profile</div>
                <div className="mt-2 text-[26px] font-semibold tracking-[-0.04em] text-[#111827]">DJ 璇︽儏</div>
              </div>
              <Link
                href={`/admin/content/djs/${item.id}/edit`}
                className="inline-flex h-[42px] items-center rounded-full bg-[#071110] px-5 text-sm font-semibold text-white"
              >
                缂栬緫 DJ
              </Link>
            </div>

            <div className="mt-6 flex flex-wrap gap-2 rounded-[24px] border border-[#e8eceb] bg-white/70 p-2">
              {DJ_DETAIL_TABS.map((tab) => (
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
                姝ｅ湪鍔犺浇 DJ 瀹屾暣淇℃伅...
              </div>
            ) : error ? (
              <div className="mt-6 rounded-[22px] border border-red-200 bg-red-50 px-5 py-4 text-sm text-[#7a2d29]">
                {error}
              </div>
            ) : (
              <div className="mt-6">
                {activeTab === 'intro' ? (
                  <div className="space-y-5">
                    <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                      <div className="flex items-center justify-between gap-4">
                        <div>
                          <div className="text-sm font-semibold text-[#111827]">绠€浠?/div>
                          <div className="mt-1 text-xs text-[#9aa1ad]">瀵瑰簲 iOS Intro 椤碉細鍩虹璧勬枡銆佺畝浠嬨€侀鏍笺€佸閾句笌璐＄尞鑰?/div>
                        </div>
                        {typeof resolved?.viewerWatchedCount === 'number' ? (
                          <span className="rounded-full bg-[#eef8ee] px-3 py-1 text-xs font-semibold text-[#2f8b4f]">
                            宸茬湅 {resolved.viewerWatchedCount}
                          </span>
                        ) : null}
                      </div>
                      <div className="mt-4 text-sm leading-7 text-[#4b5563]">
                        {bioText || '鏆傛棤绠€浠嬩俊鎭€?}
                      </div>
                    </section>

                    <section className="grid gap-5 lg:grid-cols-2">
                      <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                        <div className="text-sm font-semibold text-[#111827]">鍩虹璧勬枡</div>
                        <div className="mt-4 space-y-3 text-sm text-[#4b5563]">
                          {detailText('ID', resolved?.id || item.id)}
                          {detailText('Slug', resolved?.slug || '鏈缃?)}
                          {detailText('鍥藉/鍦板尯', countryDisplay.label)}
                          {detailText('鍙紪杈?, resolved?.canEdit === false ? '鍚? : '鏄?)}
                          {detailText('鏈€杩戝悓姝?, formatDateTime(item.lastSyncedAt))}
                          {detailText('鏈€杩戞洿鏂?, formatDateTime(item.updatedAt))}
                          {detailText('鍒涘缓鏃堕棿', formatDateTime(item.createdAt))}
                        </div>
                      </div>

                      <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                        <div className="text-sm font-semibold text-[#111827]">椋庢牸涓庡埆鍚?/div>
                        <div className="mt-4 space-y-4">
                          <div>
                            <div className="mb-2 text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">Genres</div>
                            <div className="flex flex-wrap gap-2">
                              {genres.length ? genres.map((genre) => (
                                <span key={genre} className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">
                                  {genre}
                                </span>
                              )) : <span className="text-sm text-[#6b7280]">鏆傛棤</span>}
                            </div>
                          </div>
                          <div>
                            <div className="mb-2 text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">Aliases</div>
                            <div className="flex flex-wrap gap-2">
                              {aliases.length ? aliases.map((alias) => (
                                <span key={alias} className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">
                                  {alias}
                                </span>
                              )) : <span className="text-sm text-[#6b7280]">鏆傛棤</span>}
                            </div>
                          </div>
                        </div>
                      </div>
                    </section>

                    <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                      <div className="text-sm font-semibold text-[#111827]">骞冲彴涓庡閾?/div>
                      <div className="mt-4 grid gap-3 lg:grid-cols-2">
                        {linkItems.length ? linkItems.map((linkItem) => (
                          <div key={linkItem.label} className="rounded-[18px] border border-[#edf0f2] bg-[#fafbfb] px-4 py-3 text-sm text-[#4b5563]">
                            <div className="font-semibold text-[#111827]">{linkItem.label}</div>
                            {linkItem.value ? <div className="mt-1 break-all">{linkItem.value}</div> : null}
                            {linkItem.id ? <div className="mt-1 text-xs text-[#8b93a1]">ID: {linkItem.id}</div> : null}
                          </div>
                        )) : (
                          <div className="text-sm text-[#6b7280]">鏆傛棤骞冲彴閾炬帴銆?/div>
                        )}
                      </div>
                    </section>

                    <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                      <div className="text-sm font-semibold text-[#111827]">骞冲彴缁熻</div>
                      <div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-4">
                        {[
                          ['Spotify Followers', formatFollowers(resolved?.spotifyFollowers ?? null)],
                          ['SoundCloud Followers', formatFollowers(resolved?.soundCloudFollowers ?? null)],
                          ['SoundCloud Favorites', typeof resolved?.soundCloudFavorites === 'number' ? resolved.soundCloudFavorites.toLocaleString() : '鏈悓姝?],
                          ['Follower Count', formatFollowers(item.followerCount ?? null)],
                        ].map(([label, value]) => (
                          <div key={label} className="rounded-[18px] border border-[#edf0f2] bg-[#fafbfb] px-4 py-3">
                            <div className="text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">{label}</div>
                            <div className="mt-2 text-lg font-semibold text-[#111827]">{value}</div>
                          </div>
                        ))}
                      </div>
                    </section>

                    <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                      <div className="text-sm font-semibold text-[#111827]">璐＄尞鑰?/div>
                      <div className="mt-4 flex flex-wrap gap-2">
                        {contributors.length ? contributors.map((contributor) => (
                          <span key={contributor.id} className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">
                            {contributor.displayName || contributor.username || contributor.id}
                          </span>
                        )) : <span className="text-sm text-[#6b7280]">鏆傛棤璐＄尞鑰呬俊鎭€?/span>}
                      </div>
                    </section>
                  </div>
                ) : null}

                {activeTab === 'events' ? (
                  <div className="space-y-5">
                    {(['upcoming', 'ended'] as const).map((section) => {
                      const sectionState = eventsState[section];
                      const title = section === 'upcoming' ? '鍗冲皢寮€濮?/ 杩涜涓? : '鍘嗗彶娲诲姩';
                      const sectionVisiblePages = buildVisiblePages(sectionState.pagination.page, sectionState.pagination.totalPages);
                      return (
                        <section key={section} className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                          <div className="flex items-center justify-between gap-3">
                            <div>
                              <div className="text-sm font-semibold text-[#111827]">{title}</div>
                              <div className="mt-1 text-xs text-[#9aa1ad]">瀵瑰簲 iOS Events 椤电殑鍒嗙粍涓庡垎椤?/div>
                            </div>
                            <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#6b7280]">
                              {sectionState.pagination.total} 鍦?                            </span>
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
                                    {eventItem.coverImageUrl || eventItem.imageUrl ? (
                                      <Image src={eventItem.coverImageUrl || eventItem.imageUrl || ''} alt={eventItem.name} fill className="object-cover" sizes="160px" />
                                    ) : null}
                                  </div>
                                  <div className="min-w-0 flex-1">
                                    <div className="truncate text-sm font-semibold text-[#111827]">{eventItem.name}</div>
                                    <div className="mt-1 text-xs text-[#6b7280]">{formatDateOnly(eventItem.startDate)} 路 {[eventItem.city, eventItem.country].filter(Boolean).join(', ') || '鍦扮偣鏈缃?}</div>
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
                              <EmptyTabState title="鏆傛棤娲诲姩" description="杩欎釜鍒嗙粍涓嬭繕娌℃湁缁戝畾鍒拌 DJ 鐨勬椿鍔ㄣ€? />
                            </div>
                          )}
                          <div className="mt-4 flex flex-col gap-3 border-t border-[#edf0f2] pt-4 sm:flex-row sm:items-center sm:justify-between">
                            <div className="text-xs text-[#8b93a1]">
                              Page {sectionState.pagination.page} / {Math.max(1, sectionState.pagination.totalPages)} 璺?Total {sectionState.pagination.total} events
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

                {activeTab === 'ratings' ? (
                  <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                    <div className="flex items-center justify-between gap-3">
                      <div>
                        <div className="text-sm font-semibold text-[#111827]">璇勫垎鍗曞厓</div>
                        <div className="mt-1 text-xs text-[#9aa1ad]">瀵瑰簲 iOS Ratings 椤?/div>
                      </div>
                      <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#6b7280]">
                        {ratingsState.pagination.total} 涓?                      </span>
                    </div>
                    {ratingsState.error ? <div className="mt-4 rounded-[16px] bg-red-50 px-4 py-3 text-sm text-[#7a2d29]">{ratingsState.error}</div> : null}
                    {ratingsState.loading && !ratingsState.items.length ? (
                      <div className="mt-4 text-sm text-[#6b7280]">姝ｅ湪鍔犺浇璇勫垎...</div>
                    ) : ratingsState.items.length ? (
                      <div className="mt-4 grid gap-3">
                        {ratingsState.items.map((unit) => (
                          <div key={unit.id} className="rounded-[18px] border border-[#edf0f2] bg-[#fafbfb] p-4">
                            <div className="flex items-start justify-between gap-3">
                              <div className="min-w-0">
                                <div className="truncate text-sm font-semibold text-[#111827]">{unit.name}</div>
                                <div className="mt-1 text-xs text-[#6b7280]">{unit.event?.name || '鏈粦瀹氭椿鍔?} 路 {formatDateOnly(unit.createdAt)}</div>
                              </div>
                              <div className="rounded-full bg-white px-3 py-1 text-xs font-semibold text-[#111827]">
                                {(unit.rating ?? 0).toFixed(1)} / {unit.ratingCount ?? 0}
                              </div>
                            </div>
                            {unit.description ? <div className="mt-3 text-sm leading-6 text-[#4b5563]">{unit.description}</div> : null}
                            {unit.createdBy ? <div className="mt-3 text-xs text-[#8b93a1]">鍒涘缓鑰咃細{unit.createdBy.displayName || unit.createdBy.username || unit.createdBy.id}</div> : null}
                          </div>
                        ))}
                      </div>
                    ) : (
                      <div className="mt-4">
                        <EmptyTabState title="鏆傛棤璇勫垎鍗曞厓" description="杩樻病鏈変笌杩欎釜 DJ 缁戝畾鐨勮瘎鍒嗗唴瀹广€? />
                      </div>
                    )}
                    <LoadMoreButton
                      disabled={!hasNextPage(ratingsState.pagination)}
                      loading={ratingsState.loading}
                      onClick={() => void loadRatings(ratingsState.pagination.page + 1)}
                    />
                  </section>
                ) : null}

                {activeTab === 'posts' ? (
                  <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                    <div className="flex items-center justify-between gap-3">
                      <div>
                        <div className="text-sm font-semibold text-[#111827]">鐩稿叧鍔ㄦ€?/div>
                        <div className="mt-1 text-xs text-[#9aa1ad]">瀵瑰簲 iOS Posts 椤碉紝鏉ヨ嚜缁戝畾 DJ 鐨?News feed</div>
                      </div>
                    </div>
                    {postsState.error ? <div className="mt-4 rounded-[16px] bg-red-50 px-4 py-3 text-sm text-[#7a2d29]">{postsState.error}</div> : null}
                    {postsState.loading && !postsState.items.length ? (
                      <div className="mt-4 text-sm text-[#6b7280]">姝ｅ湪鍔犺浇鍔ㄦ€?..</div>
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
                        <EmptyTabState title="鏆傛棤鐩稿叧鍔ㄦ€? description="杩樻病鏈変笌杩欎釜 DJ 缁戝畾鐨勬柊闂绘垨鍔ㄦ€佸唴瀹广€? />
                      </div>
                    )}
                    <LoadMoreButton
                      disabled={!postsState.nextCursor}
                      loading={postsState.loading}
                      onClick={() => void loadPosts(postsState.nextCursor)}
                    />
                  </section>
                ) : null}

                {activeTab === 'sets' ? (
                  <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                    <div className="flex items-center justify-between gap-3">
                      <div>
                        <div className="text-sm font-semibold text-[#111827]">DJ Sets</div>
                        <div className="mt-1 text-xs text-[#9aa1ad]">瀵瑰簲 iOS Sets 椤?/div>
                      </div>
                      <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#6b7280]">
                        {setsState.pagination.total} 涓?                      </span>
                    </div>
                    {setsState.error ? <div className="mt-4 rounded-[16px] bg-red-50 px-4 py-3 text-sm text-[#7a2d29]">{setsState.error}</div> : null}
                    {setsState.loading && !setsState.items.length ? (
                      <div className="mt-4 text-sm text-[#6b7280]">姝ｅ湪鍔犺浇 Sets...</div>
                    ) : setsState.items.length ? (
                      <div className="mt-4 grid gap-3">
                        {setsState.items.map((setItem) => (
                          <Link
                            key={setItem.id}
                            href={`/dj-sets/${setItem.id}`}
                            className="flex gap-3 rounded-[18px] border border-[#edf0f2] bg-[#fafbfb] p-3 transition hover:bg-white"
                          >
                            <div className="relative h-20 w-28 shrink-0 overflow-hidden rounded-[14px] bg-[#e7ece9]">
                              {setItem.thumbnailUrl ? <Image src={setItem.thumbnailUrl} alt={setItem.title} fill className="object-cover" sizes="220px" /> : null}
                            </div>
                            <div className="min-w-0 flex-1">
                              <div className="line-clamp-2 text-sm font-semibold text-[#111827]">{setItem.title}</div>
                              <div className="mt-1 text-xs text-[#6b7280]">
                                {[setItem.eventName, setItem.venue, formatDateOnly(setItem.recordedAt || setItem.createdAt)].filter(Boolean).join(' 路 ')}
                              </div>
                              <div className="mt-2 flex flex-wrap gap-2">
                                {setItem.platform ? <span className="rounded-full bg-white px-2.5 py-1 text-[11px] font-semibold text-[#6b7280]">{setItem.platform}</span> : null}
                                {formatDuration(setItem.duration) ? <span className="rounded-full bg-white px-2.5 py-1 text-[11px] font-semibold text-[#6b7280]">{formatDuration(setItem.duration)}</span> : null}
                                <span className="rounded-full bg-white px-2.5 py-1 text-[11px] font-semibold text-[#6b7280]">{setItem.trackCount ?? setItem.tracks?.length ?? 0} tracks</span>
                                <span className="rounded-full bg-white px-2.5 py-1 text-[11px] font-semibold text-[#6b7280]">{formatCompactNumber(setItem.viewCount)} views</span>
                                <span className="rounded-full bg-white px-2.5 py-1 text-[11px] font-semibold text-[#6b7280]">{formatCompactNumber(setItem.likeCount)} likes</span>
                              </div>
                            </div>
                          </Link>
                        ))}
                      </div>
                    ) : (
                      <div className="mt-4">
                        <EmptyTabState title="鏆傛棤 Sets" description="杩樻病鏈変笌杩欎釜 DJ 缁戝畾鐨?Set 鎴栬棰戝唴瀹广€? />
                      </div>
                    )}
                    <LoadMoreButton
                      disabled={!hasNextPage(setsState.pagination)}
                      loading={setsState.loading}
                      onClick={() => void loadSets(setsState.pagination.page + 1)}
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

// 鈶?缁熻鍧?鈥?鎵佸钩妯帓锛宭abel涓婃柟锛屾暟瀛?鐧惧垎姣斾笅鏂逛袱绔?
function StatBlock({
  label,
  value,
  rightText,
  helper,
}: {
  label: string;
  value: number;
  rightText?: string;
  helper?: string;
}) {
  return (
    <div className="flex flex-1 flex-col gap-2 px-6 py-5">
      <div className="text-[13px] font-medium text-[#6b7280]">{label}</div>
      <div className="flex items-end justify-between gap-2">
        <div className="text-[28px] font-semibold leading-none tracking-[-0.035em] text-[#111827]">
          {value.toLocaleString()}
        </div>
        {helper ? (
          <div className="flex items-center gap-1 pb-0.5 text-[12px] font-semibold text-[#22c55e]">
            {helper}
          </div>
        ) : null}
        {rightText ? (
          <div className="pb-0.5 text-[13px] font-medium text-[#9aa1ad]">{rightText}</div>
        ) : null}
      </div>
    </div>
  );
}

export default function DJCatalogPageClient() {
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [country, setCountry] = useState('all');
  const [verificationStatus, setVerificationStatus] = useState<
    'all' | 'verified' | 'unverified' | 'incomplete'
  >('all');
  const [sortBy, setSortBy] = useState<'followerCount' | 'name' | 'createdAt'>('followerCount');
  const [page, setPage] = useState(1);
  const [items, setItems] = useState<DJCatalogItem[]>([]);
  const [pagination, setPagination] = useState<AdminCatalogPagination>(EMPTY_PAGINATION);
  const [summary, setSummary] = useState<DJCatalogSummary | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState('');
  const [selectedDJ, setSelectedDJ] = useState<DJCatalogItem | null>(null);
  const [selectedDJDetail, setSelectedDJDetail] = useState<DJStudioLoadedDJ | null>(null);
  const [selectedDJError, setSelectedDJError] = useState('');
  const [selectedDJLoading, setSelectedDJLoading] = useState(false);
  const [detailCache, setDetailCache] = useState<Record<string, DJStudioLoadedDJ>>({});
  const [menuOpenDJId, setMenuOpenDJId] = useState<string | null>(null);
  const [pendingDeleteDJ, setPendingDeleteDJ] = useState<DJCatalogItem | null>(null);
  const [deletingDJId, setDeletingDJId] = useState<string | null>(null);
  const actionMenuRef = useRef<HTMLDivElement | null>(null);

  const filters = useMemo<DJCatalogFilters>(
    () => ({
      page,
      limit: PAGE_SIZE,
      search: search || undefined,
      country: country === 'all' ? undefined : country,
      verificationStatus,
      sortBy,
    }),
    [country, page, search, sortBy, verificationStatus]
  );

  const cacheKey = useMemo(
    () =>
      buildAdminCatalogCacheKey('djs-catalog', {
        page,
        limit: PAGE_SIZE,
        search: search || undefined,
        country: country === 'all' ? undefined : country,
        verificationStatus,
        sortBy,
      }),
    [country, page, search, sortBy, verificationStatus]
  );

  const loadCatalog = useCallback(
    async (options?: { force?: boolean }) => {
      const cached = !options?.force ? readAdminCatalogCache<DJCatalogResponse>(cacheKey) : null;
      if (cached) {
        setItems(cached.data.items);
        setPagination(cached.data.pagination);
        setSummary(cached.data.summary ?? null);
        setError('');
        setIsLoading(false);
        if (!cached.isStale) return;
        setIsRefreshing(true);
      } else {
        setIsLoading(true);
      }
      try {
        const response = await adminCatalogApi.fetchDJs(filters);
        writeAdminCatalogCache(cacheKey, response, CACHE_TTL_MS);
        setItems(response.items);
        setPagination(response.pagination);
        setSummary(response.summary ?? null);
        setError('');
      } catch (nextError) {
        setError(nextError instanceof Error ? nextError.message : 'DJ 鐩綍鍔犺浇澶辫触');
      } finally {
        setIsLoading(false);
        setIsRefreshing(false);
      }
    },
    [cacheKey, filters]
  );

  useEffect(() => {
    void loadCatalog();
  }, [loadCatalog]);

  useEffect(() => {
    if (!menuOpenDJId) return;

    const handlePointerDown = (event: MouseEvent) => {
      if (!actionMenuRef.current) return;
      if (event.target instanceof Node && actionMenuRef.current.contains(event.target)) return;
      setMenuOpenDJId(null);
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setMenuOpenDJId(null);
      }
    };

    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [menuOpenDJId]);

  const handleSearchSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setPage(1);
    setSearch(searchInput.trim());
  };

  const handleRefresh = () => {
    clearAdminCatalogCache(cacheKey);
    void loadCatalog({ force: true });
  };

  const handleReset = () => {
    setSearchInput('');
    setSearch('');
    setCountry('all');
    setVerificationStatus('all');
    setSortBy('followerCount');
    setPage(1);
  };

  const openDetailOverlay = useCallback(async (item: DJCatalogItem) => {
    setMenuOpenDJId(null);
    setSelectedDJ(item);
    setSelectedDJError('');
    const cached = detailCache[item.id];
    if (cached) {
      setSelectedDJDetail(cached);
      setSelectedDJLoading(false);
      return;
    }

    setSelectedDJDetail(null);
    setSelectedDJLoading(true);
    try {
      const detail = await djStudioApi.fetchDJ(item.id);
      setDetailCache((current) => ({ ...current, [item.id]: detail }));
      setSelectedDJDetail(detail);
    } catch (detailError) {
      setSelectedDJError(detailError instanceof Error ? detailError.message : 'DJ 璇︽儏鍔犺浇澶辫触');
    } finally {
      setSelectedDJLoading(false);
    }
  }, [detailCache]);

  const closeDetailOverlay = useCallback(() => {
    setMenuOpenDJId(null);
    setSelectedDJ(null);
    setSelectedDJDetail(null);
    setSelectedDJError('');
    setSelectedDJLoading(false);
  }, []);

  const requestDeleteDJ = useCallback((item: DJCatalogItem) => {
    setMenuOpenDJId(null);
    setPendingDeleteDJ(item);
  }, []);

  const confirmDeleteDJ = useCallback(async () => {
    if (!pendingDeleteDJ) return;
    const djId = pendingDeleteDJ.id;
    try {
      setDeletingDJId(djId);
      await djStudioApi.deleteDJ(djId);
      setItems((current) => current.filter((item) => item.id !== djId));
      setPagination((current) => ({
        ...current,
        total: Math.max(0, current.total - 1),
      }));
      if (selectedDJ?.id === djId) {
        closeDetailOverlay();
      }
      setPendingDeleteDJ(null);
      setDetailCache((current) => {
        const next = { ...current };
        delete next[djId];
        return next;
      });
    } catch (deleteError) {
      setError(deleteError instanceof Error ? deleteError.message : '鍒犻櫎 DJ 澶辫触');
    } finally {
      setDeletingDJId(null);
    }
  }, [closeDetailOverlay, pendingDeleteDJ, selectedDJ]);

  const handleExport = () => {
    if (typeof window === 'undefined' || !items.length) return;
    const header = ['DJ 鍚嶇О', '鍥藉/鍦板尯', '璁よ瘉鐘舵€?, '骞冲彴绮変笣', '鏈€杩戝悓姝?, '鏈€杩戞洿鏂?];
    const rows = items.map((item) => [
      item.name,
      item.country || '',
      resolveDJState(item).label,
      String(item.followerCount ?? item.soundCloudFollowers ?? ''),
      formatDateTime(item.lastSyncedAt),
      formatDateTime(item.updatedAt),
    ]);
    const csv = [header, ...rows]
      .map((row) => row.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(','))
      .join('\n');
    const blob = new Blob([`\ufeff${csv}`], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `dj-catalog-page-${pagination.page}.csv`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
  };

  const computedSummary = useMemo<DJCatalogSummary>(() => {
    if (summary) return summary;
    const nextSummary = { total: items.length, verified: 0, unverified: 0, incomplete: 0 };
    items.forEach((item) => {
      if (item.isVerified) nextSummary.verified += 1;
      else if (isDJIncomplete(item)) nextSummary.incomplete += 1;
      else nextSummary.unverified += 1;
    });
    nextSummary.total = nextSummary.verified + nextSummary.unverified + nextSummary.incomplete;
    return nextSummary;
  }, [items, summary]);

  const countryOptions = useMemo(() => {
    const options = Array.from(new Set(items.map((item) => item.country).filter(Boolean))) as string[];
    if (country !== 'all' && country && !options.includes(country)) options.push(country);
    return options.sort((left, right) => left.localeCompare(right, 'en'));
  }, [country, items]);

  const visiblePages = useMemo(() => {
    const totalPages = Math.max(1, pagination.totalPages);
    const start = Math.max(1, Math.min(totalPages - 4, pagination.page - 2));
    const end = Math.min(totalPages, start + 4);
    return Array.from({ length: end - start + 1 }, (_, index) => start + index);
  }, [pagination.page, pagination.totalPages]);

  return (
    <AdminContentLayout
      title="DJ 绠＄悊"
      eyebrow="????? / DJ ??"
      description="绠＄悊骞冲彴 DJ 璧勬枡銆佽璇佺姸鎬佷笌鍐呭銆傚彲绛涢€夈€佺紪杈戣祫鏂欐垨鏌ョ湅 DJ 璇︽儏銆?
      actions={
        <>
          {/* 鈶?瀵煎叆鎸夐挳锛氭棤杈规銆佺函鏂囧瓧+鍥炬爣 */}
          <Link
            href="/admin/content/reviews/dj-bindings"
            className="inline-flex h-[44px] items-center gap-2 rounded-full border border-[#e9dcff] bg-[#f6f0ff] px-5 text-[14px] font-semibold text-[#6d28d9]"
          >
            <Headphones className="h-4 w-4" />
            <span>DJ 缁戝畾瀹℃牳</span>
          </Link>
          <Link
            href="/admin/content/djs/new"
            className="inline-flex h-[44px] items-center gap-2 rounded-full border border-[#e8eceb] bg-white px-5 text-[14px] font-semibold text-[#111827]"
          >
            <Upload className="h-4 w-4" />
            <span>瀵煎叆 DJ</span>
          </Link>
          <Link
            href="/admin/content/djs/new"
            className="inline-flex h-[44px] items-center gap-2 rounded-full bg-[#071110] px-5 text-[14px] font-semibold text-white"
          >
            <Plus className="h-4 w-4" />
            <span>鏂板 DJ</span>
          </Link>
        </>
      }
    >
      <section className="space-y-4">

        {/* 鈶?绛涢€夋爮 鈥?鏃犲灞傚崱鐗囷紝鎵佸钩涓€琛?*/}
        <div className="flex flex-wrap items-center gap-3">
          <form onSubmit={handleSearchSubmit} className="flex min-w-0 flex-1 flex-wrap items-center gap-3">
            {/* 鎼滅储妗嗭細鍥炬爣鍦ㄥ彸渚?*/}
            <label className="flex h-[44px] min-w-[220px] flex-[1.5_1_280px] items-center gap-3 rounded-[14px] border border-[#e8eceb] bg-white px-4 text-[#111827]">
              <input
                value={searchInput}
                onChange={(event) => setSearchInput(event.target.value)}
                placeholder="鎼滅储 DJ 鍚嶇О銆佸浗瀹躲€佹爣绛?.."
                className="w-full border-0 bg-transparent px-0 py-0 text-[14px] font-medium outline-none placeholder:text-[#9aa1ad]"
              />
              <Search className="h-4 w-4 shrink-0 text-[#9aa1ad]" />
            </label>

            {/* 鍏ㄩ儴璁よ瘉鐘舵€?*/}
            <label className="relative flex h-[44px] min-w-[160px] flex-1 items-center justify-between rounded-[14px] border border-[#e8eceb] bg-white px-4 text-[14px] font-semibold text-[#111827]">
              <span>
                {verificationStatus === 'all'
                  ? '鍏ㄩ儴璁よ瘉鐘舵€?
                  : verificationStatus === 'verified'
                    ? '宸查獙璇?
                    : verificationStatus === 'unverified'
                      ? '鏈獙璇?
                      : '璧勬枡寰呭畬鍠?}
              </span>
              <select
                value={verificationStatus}
                onChange={(event) => {
                  setVerificationStatus(event.target.value as 'all' | 'verified' | 'unverified' | 'incomplete');
                  setPage(1);
                }}
                className="absolute inset-0 opacity-0"
              >
                <option value="all">鍏ㄩ儴璁よ瘉鐘舵€?/option>
                <option value="verified">宸查獙璇?/option>
                <option value="unverified">鏈獙璇?/option>
                <option value="incomplete">璧勬枡寰呭畬鍠?/option>
              </select>
              <ChevronDown className="h-4 w-4 text-[#9aa1ad]" />
            </label>

            {/* 鍏ㄩ儴鍥藉/鍦板尯 */}
            <label className="relative flex h-[44px] min-w-[150px] flex-1 items-center justify-between rounded-[14px] border border-[#e8eceb] bg-white px-4 text-[14px] font-semibold text-[#111827]">
              <span>{country === 'all' ? '鍏ㄩ儴鍥藉/鍦板尯' : country}</span>
              <select
                value={country}
                onChange={(event) => {
                  setCountry(event.target.value);
                  setPage(1);
                }}
                className="absolute inset-0 opacity-0"
              >
                <option value="all">鍏ㄩ儴鍥藉/鍦板尯</option>
                {countryOptions.map((item) => (
                  <option key={item} value={item}>{item}</option>
                ))}
              </select>
              <ChevronDown className="h-4 w-4 text-[#9aa1ad]" />
            </label>

            {/* 鏇村绛涢€?*/}
            <details className="relative">
              <summary className="flex h-[44px] cursor-pointer list-none items-center gap-2 rounded-[14px] border border-[#e8eceb] bg-white px-4 text-[14px] font-semibold text-[#111827]">
                <Filter className="h-4 w-4" />
                <span>鏇村绛涢€?/span>
              </summary>
              <div className="absolute left-0 top-[calc(100%+8px)] z-20 min-w-[200px] rounded-[18px] border border-[#e8eceb] bg-white p-4 shadow-[0_12px_32px_rgba(33,52,47,0.10)]">
                <div className="mb-2 text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">鎺掑簭鏂瑰紡</div>
                <select
                  value={sortBy}
                  onChange={(event) => {
                    setSortBy(event.target.value as 'followerCount' | 'name' | 'createdAt');
                    setPage(1);
                  }}
                  className="w-full rounded-[12px] border border-[#e8eceb] bg-white px-3 py-2.5 text-sm font-semibold text-[#111827] outline-none"
                >
                  <option value="followerCount">鎸夊钩鍙扮矇涓?/option>
                  <option value="name">鎸夊悕绉?/option>
                  <option value="createdAt">鎸夊垱寤烘椂闂?/option>
                </select>
              </div>
            </details>
          </form>

          {/* 鈶?鍒锋柊銆佸鍑?鈥?绉昏嚦鏈€鍙筹紝鍥炬爣+鏂囧瓧椋庢牸 */}
          <button
            type="button"
            onClick={handleRefresh}
            className="inline-flex h-[44px] w-[44px] items-center justify-center rounded-[14px] border border-[#e8eceb] bg-white text-[#6b7280]"
            aria-label="鍒锋柊鐩綍"
          >
            <RefreshCw className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`} />
          </button>

          <button
            type="button"
            onClick={handleExport}
            className="inline-flex h-[44px] items-center gap-2 rounded-[14px] border border-[#e8eceb] bg-white px-4 text-[14px] font-semibold text-[#111827]"
          >
            <Download className="h-4 w-4" />
            <span>瀵煎嚭</span>
          </button>
        </div>

        {/* 鈶?缁熻鍧?鈥?鎵佸钩鍥涙牸妯帓锛岃交杈规瀹瑰櫒锛岀珫绾垮垎闅?*/}
        <div className="flex overflow-hidden rounded-[18px] border border-[#edf0f2] bg-white divide-x divide-[#edf0f2]">
          <StatBlock
            label="鍏ㄩ儴 DJ"
            value={computedSummary.total}
            helper={computedSummary.total ? `鈫?${Math.max(0, Math.min(items.length, PAGE_SIZE))} 鏈湀鏂板` : undefined}
          />
          <StatBlock
            label="宸查獙璇?
            value={computedSummary.verified}
            rightText={formatPercentage(computedSummary.verified, computedSummary.total)}
          />
          <StatBlock
            label="鏈獙璇?
            value={computedSummary.unverified}
            rightText={formatPercentage(computedSummary.unverified, computedSummary.total)}
          />
          <StatBlock
            label="璧勬枡寰呭畬鍠?
            value={computedSummary.incomplete}
            rightText={formatPercentage(computedSummary.incomplete, computedSummary.total)}
          />
        </div>

        {/* 鍒楄〃鍖?*/}
        <section className="overflow-hidden rounded-[18px] border border-[#edf0f2] bg-white">
          {error ? (
            <div className="border-b border-red-200 bg-red-50 px-6 py-3 text-sm text-[#7a2d29]">{error}</div>
          ) : null}

          {/* 鈶?琛ㄥご 鈥?鏇村皬鏇磋交 */}
          <div className="hidden border-b border-[#edf0f2] px-5 py-3 lg:grid lg:grid-cols-[minmax(0,2.4fr)_1.2fr_0.9fr_1fr_1.2fr_1.2fr_140px] lg:gap-6">
            {['DJ 淇℃伅', '鍥藉/鍦板尯', '璁よ瘉鐘舵€?, '骞冲彴绮変笣', '鏈€杩戝悓姝?, '鏈€杩戞洿鏂?, '鎿嶄綔'].map((label) => (
              <div key={label} className="text-[13px] font-medium text-[#9aa1ad]">
                {label}
              </div>
            ))}
          </div>

          {isLoading ? (
            <div className="px-6 py-16 text-center text-sm text-[#6b7280]">DJ 鐩綍鍔犺浇涓€?/div>
          ) : items.length === 0 ? (
            <div className="px-6 py-16 text-center text-sm text-[#6b7280]">褰撳墠绛涢€夋潯浠朵笅杩樻病鏈?DJ銆?/div>
          ) : (
            <div className="divide-y divide-[#edf0f2]">
              {items.map((item) => {
                const state = resolveDJState(item);
                const tags = resolveTagPills(item);
                const countryDisplay = resolveCountryDisplay(item.country);
                const lastSynced = formatDateCell(item.lastSyncedAt);
                const updatedAt = formatDateCell(item.updatedAt);
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
                    className="cursor-pointer px-5 py-3.5 transition-colors hover:bg-[#fbfcfb] focus:outline-none focus:ring-2 focus:ring-[#d9e7dd] lg:grid lg:grid-cols-[minmax(0,2.4fr)_1.2fr_0.9fr_1fr_1.2fr_1.2fr_140px] lg:items-center lg:gap-6"
                  >
                    {/* 鈶?DJ淇℃伅鍒楋細澶村儚56脳56锛屾洿绱у噾 */}
                    <div className="min-w-0">
                      <div className="flex min-w-0 items-center gap-3">
                        <div className="flex h-[56px] w-[56px] shrink-0 items-center justify-center overflow-hidden rounded-[14px] bg-[#f1f4f6]">
                          {item.avatarUrl ? (
                            <Image
                              src={item.avatarUrl}
                              alt={item.name}
                              width={56}
                              height={56}
                              className="h-full w-full object-cover"
                            />
                          ) : (
                            <span className="text-xs text-[#9aa1ad]">鏆傛棤</span>
                          )}
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="truncate text-[15px] font-semibold tracking-[-0.01em] text-[#111827]">
                            {item.name}
                          </div>
                          <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
                            {tags.map((tag) => (
                              <span
                                key={`${item.id}-${tag}`}
                                className="rounded-full bg-[#f4f5f7] px-2.5 py-0.5 text-[11px] font-semibold text-[#6b7280]"
                              >
                                {tag}
                              </span>
                            ))}
                            <span className="rounded-full bg-[#f4f5f7] px-2.5 py-0.5 text-[11px] font-semibold text-[#8f96a3]">
                              ...
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* 鈶?鍥藉锛氬畬鏁村悕绉?*/}
                    <div className="mt-3 flex items-center gap-2 text-[14px] font-medium text-[#111827] lg:mt-0">
                      {countryDisplay.flag ? (
                        <span className="text-[20px] leading-none" aria-hidden="true">
                          {countryDisplay.flag}
                        </span>
                      ) : null}
                      <span>{countryDisplay.label}</span>
                    </div>

                    {/* 鈶?璁よ瘉鐘舵€?badge 鈥?鏇寸揣鍑?*/}
                    <div className="mt-3 lg:mt-0">
                      <span
                        className={`inline-flex rounded-full border px-3 py-1 text-[12px] font-semibold ${state.tone}`}
                      >
                        {state.label}
                      </span>
                    </div>

                    <div className="mt-3 text-[14px] font-medium text-[#111827] lg:mt-0">
                      {formatFollowers(item.followerCount ?? item.soundCloudFollowers)}
                    </div>

                    <div className="mt-3 text-[13px] font-medium text-[#111827] lg:mt-0">
                      <div>{lastSynced.date}</div>
                      {lastSynced.time ? <div className="text-[#6b7280]">{lastSynced.time}</div> : null}
                    </div>

                    <div className="mt-3 text-[13px] font-medium text-[#111827] lg:mt-0">
                      <div>{updatedAt.date}</div>
                      {updatedAt.time ? <div className="text-[#6b7280]">{updatedAt.time}</div> : null}
                    </div>

                    {/* 鈶?鎿嶄綔鎸夐挳 鈥?鏇村皬锛屾弿杈归鏍?*/}
                    <div
                      className="relative mt-3 flex items-center gap-2 lg:mt-0 lg:justify-end"
                      ref={menuOpenDJId === item.id ? actionMenuRef : null}
                    >
                      <Link
                        href={`/admin/content/djs/${item.id}/edit`}
                        onClick={(event) => {
                          event.stopPropagation();
                          setMenuOpenDJId(null);
                        }}
                        className="inline-flex h-[36px] items-center rounded-[10px] border border-[#e8eceb] bg-white px-4 text-[13px] font-semibold text-[#111827]"
                      >
                        缂栬緫
                      </Link>
                      <button
                        type="button"
                        onClick={(event) => {
                          event.stopPropagation();
                          setMenuOpenDJId((current) => (current === item.id ? null : item.id));
                        }}
                        className="inline-flex h-[36px] w-[36px] items-center justify-center rounded-[10px] border border-[#e8eceb] bg-white text-[#6b7280]"
                        aria-label="鏇村鎿嶄綔"
                      >
                        <Ellipsis className="h-4 w-4" />
                      </button>
                      {menuOpenDJId === item.id ? (
                        <div
                          className="absolute right-0 top-[44px] z-20 min-w-[140px] rounded-[16px] border border-[#e7ebef] bg-white p-2 shadow-[0_16px_36px_rgba(17,24,39,0.14)]"
                          onClick={(event) => event.stopPropagation()}
                        >
                          <button
                            type="button"
                            onClick={() => requestDeleteDJ(item)}
                            className="flex w-full items-center justify-start rounded-[12px] px-3 py-2 text-sm font-semibold text-[#b42318] transition hover:bg-[#fff5f4]"
                          >
                            鍒犻櫎 DJ
                          </button>
                        </div>
                      ) : null}
                    </div>
                  </article>
                );
              })}
            </div>
          )}

          {/* 鍒嗛〉 */}
          <div className="flex flex-col gap-3 border-t border-[#edf0f2] px-5 py-4 lg:flex-row lg:items-center lg:justify-between">
            <div className="text-[13px] font-medium text-[#6b7280]">
              鍏?{pagination.total.toLocaleString()} 鏉?
            </div>

            <div className="flex items-center gap-1.5">
              <button
                type="button"
                disabled={pagination.page <= 1}
                onClick={() => setPage((current) => Math.max(1, current - 1))}
                className="inline-flex h-9 w-9 items-center justify-center rounded-full text-[#8f96a3] disabled:cursor-not-allowed disabled:opacity-40"
              >
                <ChevronLeft className="h-4 w-4" />
              </button>

              {visiblePages.map((pageNumber) => (
                <button
                  key={pageNumber}
                  type="button"
                  onClick={() => setPage(pageNumber)}
                  className={`inline-flex h-9 min-w-9 items-center justify-center rounded-full px-3 text-[14px] font-semibold ${
                    pageNumber === pagination.page ? 'bg-[#071110] text-white' : 'text-[#111827]'
                  }`}
                >
                  {pageNumber}
                </button>
              ))}

              {pagination.totalPages > visiblePages[visiblePages.length - 1] ? (
                <>
                  <span className="px-1 text-[#9aa1ad]">...</span>
                  <button
                    type="button"
                    onClick={() => setPage(pagination.totalPages)}
                    className="inline-flex h-9 min-w-9 items-center justify-center rounded-full px-3 text-[14px] font-semibold text-[#111827]"
                  >
                    {pagination.totalPages}
                  </button>
                </>
              ) : null}

              <button
                type="button"
                disabled={pagination.page >= pagination.totalPages}
                onClick={() => setPage((current) => Math.min(pagination.totalPages, current + 1))}
                className="inline-flex h-9 w-9 items-center justify-center rounded-full text-[#111827] disabled:cursor-not-allowed disabled:opacity-40"
              >
                <ChevronRight className="h-4 w-4" />
              </button>
            </div>

            <div className="flex items-center gap-2 rounded-[12px] border border-[#e8eceb] bg-white px-4 py-2 text-[13px] font-semibold text-[#111827]">
              <span>{pagination.limit} 鏉?椤?/span>
              <ChevronDown className="h-3.5 w-3.5 text-[#9aa1ad]" />
            </div>
          </div>
        </section>
      </section>

      <DJDetailOverlay
        item={selectedDJ}
        detail={selectedDJDetail}
        loading={selectedDJLoading}
        error={selectedDJError}
        onClose={closeDetailOverlay}
      />
      {pendingDeleteDJ ? (
        <div className="fixed inset-0 z-[90] flex items-center justify-center bg-black/45 p-4" onClick={() => setPendingDeleteDJ(null)}>
          <div
            className="w-full max-w-md rounded-[28px] border border-[#e8eceb] bg-white p-6 shadow-[0_24px_72px_rgba(17,24,39,0.18)]"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[#b42318]">Delete DJ</div>
            <div className="mt-3 text-[24px] font-semibold tracking-[-0.04em] text-[#111827]">纭鍒犻櫎杩欎釜 DJ锛?/div>
            <p className="mt-3 text-sm leading-6 text-[#6b7280]">
              {pendingDeleteDJ.name}
              <br />
              鍒犻櫎鍚庡皢鏃犳硶鎭㈠锛岃鍐嶆纭杩欐槸浣犺鎵ц鐨勬搷浣溿€?            </p>
            <div className="mt-6 flex justify-end gap-3">
              <button
                type="button"
                onClick={() => setPendingDeleteDJ(null)}
                className="inline-flex h-[44px] items-center justify-center rounded-full border border-[#e7ebef] bg-white px-5 text-sm font-semibold text-[#111827]"
              >
                鍙栨秷
              </button>
              <button
                type="button"
                onClick={() => void confirmDeleteDJ()}
                disabled={deletingDJId === pendingDeleteDJ.id}
                className="inline-flex h-[44px] items-center justify-center rounded-full bg-[#b42318] px-5 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
              >
                {deletingDJId === pendingDeleteDJ.id ? '鍒犻櫎涓?..' : '纭鍒犻櫎'}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </AdminContentLayout>
  );
}

