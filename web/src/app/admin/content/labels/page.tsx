'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useEffect, useMemo, useRef, useState } from 'react';
import { Ellipsis } from 'lucide-react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import AdminSearchField from '@/components/admin/AdminSearchField';
import OverlayImageViewer, { type OverlayImageViewerAsset } from '@/components/admin/OverlayImageViewer';
import { labelStudioApi, type LabelStudioLoadedLabel } from '@/features/admin-content/label-studio';

const formatNumber = (value?: number | null): string =>
  typeof value === 'number' && Number.isFinite(value) ? new Intl.NumberFormat('zh-CN').format(value) : 'Not synced';

type LabelDetailTabKey = 'overview' | 'links' | 'genres';
type LabelDirectorySortKey =
  | 'followersDesc'
  | 'likesDesc'
  | 'nameAsc'
  | 'nameDesc'
  | 'nationAsc'
  | 'nationDesc'
  | 'latestReleaseDesc'
  | 'latestReleaseAsc'
  | 'createdAtDesc'
  | 'createdAtAsc';

const LABEL_DIRECTORY_SORT_OPTIONS: Array<{
  value: LabelDirectorySortKey;
  label: string;
  sortBy: 'soundcloudFollowers' | 'likes' | 'name' | 'nation' | 'latestRelease' | 'createdAt';
  order: 'asc' | 'desc';
}> = [
  { value: 'followersDesc', label: 'Followers High to Low', sortBy: 'soundcloudFollowers', order: 'desc' },
  { value: 'likesDesc', label: 'Likes High to Low', sortBy: 'likes', order: 'desc' },
  { value: 'createdAtDesc', label: 'Newest Added', sortBy: 'createdAt', order: 'desc' },
  { value: 'createdAtAsc', label: 'Oldest Added', sortBy: 'createdAt', order: 'asc' },
  { value: 'latestReleaseDesc', label: 'Latest Release Z to A', sortBy: 'latestRelease', order: 'desc' },
  { value: 'latestReleaseAsc', label: 'Latest Release A to Z', sortBy: 'latestRelease', order: 'asc' },
  { value: 'nameAsc', label: 'Name A-Z', sortBy: 'name', order: 'asc' },
  { value: 'nameDesc', label: 'Name Z-A', sortBy: 'name', order: 'desc' },
  { value: 'nationAsc', label: 'Country A-Z', sortBy: 'nation', order: 'asc' },
  { value: 'nationDesc', label: 'Country Z-A', sortBy: 'nation', order: 'desc' },
];

const LABEL_DETAIL_TABS: Array<{ key: LabelDetailTabKey; label: string }> = [
  { key: 'overview', label: 'Overview' },
  { key: 'links', label: 'Links' },
  { key: 'genres', label: 'Genres' },
];

const renderDetailText = (label: string, value?: string | null) => (
  <div>
    <span className="font-medium text-[#111827]">{label}: </span>
    {value && value.trim() ? value : 'Not set'}
  </div>
);

const renderFounderDjNames = (item: LabelStudioLoadedLabel): string =>
  item.founderDjs?.length
    ? item.founderDjs.map((dj) => dj.name).filter(Boolean).join(' / ')
    : 'Not set';

function LabelDetailOverlay({
  item,
  detail,
  loading,
  error,
  onClose,
}: {
  item: LabelStudioLoadedLabel | null;
  detail: LabelStudioLoadedLabel | null;
  loading: boolean;
  error: string;
  onClose: () => void;
}) {
  const [activeTab, setActiveTab] = useState<LabelDetailTabKey>('overview');
  const [previewAssetIndex, setPreviewAssetIndex] = useState<number | null>(null);

  useEffect(() => {
    setActiveTab('overview');
    setPreviewAssetIndex(null);
  }, [item?.id]);

  if (!item) return null;

  const resolved = detail ?? item;
  const bannerImage = resolved.backgroundUrl || '';
  const avatarImage = resolved.avatarUrl || resolved.logoUrl || '';
  const heroImage = bannerImage || avatarImage || '';
  const previewAssets: OverlayImageViewerAsset[] = [
    ...(bannerImage
      ? [
          {
            url: bannerImage,
            alt: `${resolved.name} banner`,
            title: 'Banner',
            subtitle: 'Label banner',
          },
        ]
      : []),
    ...(avatarImage
      ? [
          {
            url: avatarImage,
            alt: `${resolved.name} avatar`,
            title: 'Avatar',
            subtitle: 'Label avatar',
          },
        ]
      : []),
  ];
  const linkItems = [
    { label: 'Official', value: resolved.officialWebsiteUrl },
    { label: 'Facebook', value: resolved.facebookUrl },
    { label: 'SoundCloud', value: resolved.soundcloudUrl },
    { label: 'Purchase', value: resolved.musicPurchaseUrl },
    { label: 'Contact', value: resolved.generalContactEmail },
    { label: 'Demo', value: resolved.demoSubmissionDisplay || resolved.demoSubmissionUrl },
  ];

  let tabContent: React.ReactNode = null;
  if (loading) {
    tabContent = (
      <div className="rounded-[22px] border border-[#e8eceb] bg-white px-5 py-10 text-sm text-[#6b7280]">
        Loading full label details...
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
          <div className="text-sm font-semibold text-[#111827]">Introduction</div>
          <div className="mt-3 text-sm leading-7 text-[#4b5563]">
            {resolved.introduction || resolved.introductionPreview || 'No introduction available.'}
          </div>
        </section>

        <section className="grid gap-5 lg:grid-cols-2">
          <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
            <div className="text-sm font-semibold text-[#111827]">Identity</div>
            <div className="mt-4 space-y-3 text-sm text-[#4b5563]">
              {renderDetailText('ID', resolved.id)}
              {renderDetailText('Slug', resolved.slug)}
              {renderDetailText('Nation', resolved.nation)}
              {renderDetailText('Founded', resolved.foundedAt)}
              {renderDetailText('Founder', resolved.founderName)}
            </div>
          </div>

          <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
            <div className="text-sm font-semibold text-[#111827]">Release Context</div>
            <div className="mt-4 space-y-3 text-sm text-[#4b5563]">
              {renderDetailText('Location Period', resolved.locationPeriod)}
              {renderDetailText('Latest Release', resolved.latestReleaseListing)}
              {renderDetailText('Profile URL', resolved.profileUrl)}
              {renderDetailText('Profile Slug', resolved.profileSlug)}
              {renderDetailText('Founder DJs', renderFounderDjNames(resolved))}
            </div>
          </div>
        </section>
      </div>
    );
  } else if (activeTab === 'links') {
    tabContent = (
      <div className="grid gap-5 lg:grid-cols-2">
        {linkItems.map((entry) => (
          <section key={entry.label} className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
            <div className="text-sm font-semibold text-[#111827]">{entry.label}</div>
            <div className="mt-3 break-all text-sm leading-7 text-[#4b5563]">{entry.value || 'Not set'}</div>
          </section>
        ))}
      </div>
    );
  } else {
    tabContent = (
      <div className="space-y-5">
        <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
          <div className="text-sm font-semibold text-[#111827]">Genres</div>
          <div className="mt-4 flex flex-wrap gap-2">
            {resolved.genres.length ? (
              resolved.genres.map((genre) => (
                <span key={genre} className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">
                  {genre}
                </span>
              ))
            ) : (
              <div className="text-sm text-[#6b7280]">No genres attached.</div>
            )}
          </div>
        </section>

        <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
          <div className="text-sm font-semibold text-[#111827]">Genre Preview</div>
          <div className="mt-3 text-sm leading-7 text-[#4b5563]">{resolved.genresPreview || 'No preview text.'}</div>
        </section>
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
            href={`/admin/content/labels/${item.id}/edit`}
            className="inline-flex h-10 items-center rounded-full bg-[#071110] px-4 text-sm font-semibold text-white shadow-[0_8px_20px_rgba(7,17,16,0.16)]"
          >
            Edit Label
          </Link>
          <button
            type="button"
            onClick={onClose}
            className="inline-flex h-10 w-10 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#6b7280]"
            aria-label="Close label detail"
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
              {heroImage ? (
                <div className="relative aspect-[1.25/1] w-full">
                  <Image src={heroImage} alt={resolved.name} fill className="object-cover" sizes="900px" />
                </div>
              ) : (
                <div className="flex aspect-[1.25/1] items-center justify-center text-sm text-[#7b8794]">No visual available</div>
              )}
            </button>

            <div className="-mt-10 px-4">
              <div className="flex items-end gap-4 rounded-[24px] border border-[#e8eceb] bg-white/96 p-5 shadow-[0_12px_32px_rgba(33,52,47,0.08)]">
                <button
                  type="button"
                  onClick={() => {
                    const avatarIndex = previewAssets.findIndex((asset) => asset.url === avatarImage);
                    if (avatarIndex >= 0) setPreviewAssetIndex(avatarIndex);
                  }}
                  className="flex h-[92px] w-[92px] shrink-0 items-center justify-center overflow-hidden rounded-[22px] bg-[#f1f4f6]"
                >
                  {avatarImage ? (
                    <Image
                      src={avatarImage}
                      alt={resolved.name}
                      width={92}
                      height={92}
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <span className="text-xs text-[#9aa1ad]">No avatar</span>
                  )}
                </button>
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap gap-2">
                  {resolved.nation ? <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">{resolved.nation}</span> : null}
                  {resolved.genresPreview ? <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">{resolved.genresPreview}</span> : null}
                  </div>
                  <div className="mt-3 text-[28px] font-semibold tracking-[-0.04em] text-[#111827]">{resolved.name}</div>
                  <div className="mt-2 text-sm font-medium text-[#6b7280]">{resolved.locationPeriod || resolved.slug}</div>
                </div>
              </div>
            </div>

            <div className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-1">
              {[
                ['Followers', formatNumber(resolved.soundcloudFollowers)],
                ['Likes', formatNumber(resolved.likes)],
                ['Genres', resolved.genres.length.toLocaleString()],
                ['Founder', resolved.founderName || 'Not set'],
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
                {renderDetailText('Slug', resolved.slug)}
                {renderDetailText('Nation', resolved.nation)}
                {renderDetailText('Profile URL', resolved.profileUrl)}
                {renderDetailText('Founded', resolved.foundedAt)}
              </div>
            </div>
          </div>

          <div className="p-6">
            <div className="flex items-center justify-between gap-3 pr-[162px]">
              <div>
                <div className="text-xs font-semibold uppercase tracking-[0.14em] text-[#9aa1ad]">Label Profile</div>
                <div className="mt-2 text-[26px] font-semibold tracking-[-0.04em] text-[#111827]">Label Detail</div>
              </div>
            </div>

            <div className="mt-6 flex flex-wrap gap-2 rounded-[24px] border border-[#e8eceb] bg-white/70 p-2">
              {LABEL_DETAIL_TABS.map((tab) => (
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
      </div>
      <OverlayImageViewer
        assets={previewAssets}
        activeIndex={previewAssetIndex}
        onClose={() => setPreviewAssetIndex(null)}
        onChange={setPreviewAssetIndex}
      />
    </div>
  );
}

export default function AdminContentLabelsPage() {
  const [items, setItems] = useState<LabelStudioLoadedLabel[]>([]);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [search, setSearch] = useState('');
  const [inputValue, setInputValue] = useState('');
  const [sortBy, setSortBy] = useState<LabelDirectorySortKey>('followersDesc');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedLabel, setSelectedLabel] = useState<LabelStudioLoadedLabel | null>(null);
  const [selectedLabelDetail, setSelectedLabelDetail] = useState<LabelStudioLoadedLabel | null>(null);
  const [selectedLabelLoading, setSelectedLabelLoading] = useState(false);
  const [selectedLabelError, setSelectedLabelError] = useState('');
  const [detailCache, setDetailCache] = useState<Record<string, LabelStudioLoadedLabel>>({});
  const [menuOpenLabelId, setMenuOpenLabelId] = useState<string | null>(null);
  const [pendingDeleteLabel, setPendingDeleteLabel] = useState<LabelStudioLoadedLabel | null>(null);
  const [deletingLabelId, setDeletingLabelId] = useState<string | null>(null);
  const actionMenuRef = useRef<HTMLDivElement | null>(null);

  const activeSortOption = useMemo(
    () => LABEL_DIRECTORY_SORT_OPTIONS.find((item) => item.value === sortBy) ?? LABEL_DIRECTORY_SORT_OPTIONS[0],
    [sortBy]
  );

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      try {
        setLoading(true);
        setError(null);
        const response = await labelStudioApi.listLabels(
          page,
          12,
          search,
          activeSortOption.sortBy,
          activeSortOption.order
        );
        if (cancelled) return;
        setItems(response.items);
        setTotalPages(response.pagination.totalPages || 1);
      } catch (loadError) {
        if (cancelled) return;
        setError(loadError instanceof Error ? loadError.message : 'Failed to load labels.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void load();
    return () => {
      cancelled = true;
    };
  }, [activeSortOption.order, activeSortOption.sortBy, page, search]);

  useEffect(() => {
    if (!menuOpenLabelId) return;

    const handlePointerDown = (event: MouseEvent) => {
      if (!actionMenuRef.current) return;
      if (event.target instanceof Node && actionMenuRef.current.contains(event.target)) return;
      setMenuOpenLabelId(null);
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setMenuOpenLabelId(null);
      }
    };

    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [menuOpenLabelId]);

  const openDetailOverlay = async (item: LabelStudioLoadedLabel) => {
    setMenuOpenLabelId(null);
    setSelectedLabel(item);
    setSelectedLabelError('');
    const cached = detailCache[item.id];
    if (cached) {
      setSelectedLabelDetail(cached);
      setSelectedLabelLoading(false);
      return;
    }

    setSelectedLabelDetail(null);
    setSelectedLabelLoading(true);
    try {
      const detail = await labelStudioApi.fetchLabel(item.id);
      setDetailCache((current) => ({ ...current, [item.id]: detail }));
      setSelectedLabelDetail(detail);
    } catch (detailError) {
      setSelectedLabelError(detailError instanceof Error ? detailError.message : 'Failed to load label detail.');
    } finally {
      setSelectedLabelLoading(false);
    }
  };

  const closeDetailOverlay = () => {
    setMenuOpenLabelId(null);
    setSelectedLabel(null);
    setSelectedLabelDetail(null);
    setSelectedLabelLoading(false);
    setSelectedLabelError('');
  };

  const requestDeleteLabel = (item: LabelStudioLoadedLabel) => {
    setMenuOpenLabelId(null);
    setPendingDeleteLabel(item);
  };

  const confirmDeleteLabel = async () => {
    if (!pendingDeleteLabel) return;
    const labelId = pendingDeleteLabel.id;
    try {
      setDeletingLabelId(labelId);
      await labelStudioApi.deleteLabel(labelId);
      setItems((current) => current.filter((item) => item.id !== labelId));
      if (selectedLabel?.id === labelId) {
        closeDetailOverlay();
      }
      setPendingDeleteLabel(null);
      setDetailCache((current) => {
        const next = { ...current };
        delete next[labelId];
        return next;
      });
    } catch (deleteError) {
      setError(deleteError instanceof Error ? deleteError.message : '删除厂牌失败，请稍后重试。');
    } finally {
      setDeletingLabelId(null);
    }
  };

  const visiblePages = useMemo(() => {
    const cappedTotal = Math.max(1, totalPages);
    const start = Math.max(1, Math.min(cappedTotal - 4, page - 2));
    const end = Math.min(cappedTotal, start + 4);
    return Array.from({ length: end - start + 1 }, (_, index) => start + index);
  }, [page, totalPages]);

  return (
    <AdminContentLayout
      title="Label Workspace"
      description="Manage label metadata, channel links, and profile assets with the same detail overlay structure used by events."
      actions={
        <>
          <Link href="/admin/content" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            Back to Content
          </Link>
          <Link href="/admin/content/labels/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            New Label
          </Link>
        </>
      }
    >
      <section className="space-y-5">
        <section className="admin-reference-card p-6">
          <div className="flex flex-col gap-4">
            <div>
              <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">Label Directory</div>
              <h2 className="mt-2 text-[30px] font-semibold tracking-[-0.03em] text-[#1a1a1a]">Label Directory</h2>
            </div>
            <div className="flex flex-col gap-3 xl:flex-row xl:items-end xl:justify-between">
              <div className="min-w-0 flex-1">
                <AdminSearchField
                  value={inputValue}
                  onChange={setInputValue}
                  placeholder="Search label name"
                  size="md"
                  submitLabel="Search"
                  onSubmit={() => {
                    setPage(1);
                    setSearch(inputValue.trim());
                  }}
                  onClear={() => {
                    setInputValue('');
                    setPage(1);
                    setSearch('');
                  }}
                />
              </div>
              <div className="flex flex-wrap items-end gap-3">
                <div>
                  <div className="mb-2 text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">Sort</div>
                  <select
                    value={sortBy}
                    onChange={(event) => {
                      setPage(1);
                      setSortBy(event.target.value as typeof sortBy);
                    }}
                    className="admin-studio-input min-w-[220px]"
                  >
                    {LABEL_DIRECTORY_SORT_OPTIONS.map((option) => (
                      <option key={option.value} value={option.value}>
                        {option.label}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
            </div>
          </div>

          <div className="mt-6 flex flex-wrap items-center justify-between gap-3 border-b border-[#edf0f2] pb-4 text-sm text-black/48">
            <div>
              Current page: {page} / {totalPages}
            </div>
            <div>{items.length} records on this page</div>
          </div>

          {loading ? (
            <div className="mt-6 text-sm text-black/48">Loading label directory...</div>
          ) : error ? (
            <div className="admin-studio-pastel-rose mt-6 p-4 text-sm text-[#6a3530]">{error}</div>
          ) : (
            <div className="mt-5 grid gap-3 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
              {items.map((item) => {
                const avatarImage = item.avatarUrl || item.logoUrl || item.backgroundUrl || null;
                const topGenres = item.genres.slice(0, 3);
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
                    className="admin-reference-soft-card cursor-pointer p-3.5 transition-colors hover:bg-[#fafaf8] focus:outline-none focus:ring-2 focus:ring-[#d9e7dd]"
                  >
                    <div className="flex items-start gap-3">
                      <div className="relative h-[72px] w-[72px] shrink-0 overflow-hidden rounded-[16px] border border-[#e8eceb] bg-[#eef1ef]">
                        {avatarImage ? (
                          <Image src={avatarImage} alt={item.name} fill className="object-cover" sizes="72px" />
                        ) : (
                          <div className="flex h-full w-full items-center justify-center text-xs font-semibold text-black/35">
                            {item.name.slice(0, 1).toUpperCase()}
                          </div>
                        )}
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="min-w-0">
                          <h3 className="truncate text-[16px] font-semibold tracking-[-0.02em] text-[#071110]">{item.name}</h3>
                          {item.nation ? <div className="mt-1 text-xs font-medium text-black/42">{item.nation}</div> : null}
                          <div className="mt-2 flex flex-wrap gap-2">
                            {topGenres.length ? (
                              topGenres.map((genre) => (
                                <span key={`${item.id}-${genre}`} className="admin-reference-chip">
                                  {genre}
                                </span>
                              ))
                            ) : item.genresPreview ? (
                              <span className="admin-reference-chip">{item.genresPreview}</span>
                            ) : (
                              <span className="text-xs text-black/38">No style tags yet</span>
                            )}
                          </div>
                        </div>
                      </div>
                      <div className="ml-auto flex shrink-0 items-start gap-2">
                        <Link
                          href={`/admin/content/labels/${item.id}/edit`}
                          onClick={(event) => event.stopPropagation()}
                          className="inline-flex h-9 items-center rounded-full border border-[#e8eceb] bg-white px-3.5 text-sm font-semibold text-[#111827]"
                        >
                          编辑
                        </Link>
                        <div className="relative" ref={menuOpenLabelId === item.id ? actionMenuRef : null}>
                          <button
                          type="button"
                          onClick={(event) => {
                            event.stopPropagation();
                            setMenuOpenLabelId((current) => (current === item.id ? null : item.id));
                          }}
                          className="inline-flex h-9 w-9 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#6b7280]"
                          aria-label="More actions"
                        >
                          <Ellipsis className="h-4 w-4" />
                        </button>
                        {menuOpenLabelId === item.id ? (
                          <div
                            className="absolute right-0 top-[44px] z-20 min-w-[140px] rounded-[16px] border border-[#e7ebef] bg-white p-2 shadow-[0_16px_36px_rgba(17,24,39,0.14)]"
                            onClick={(event) => event.stopPropagation()}
                          >
                            <button
                              type="button"
                              onClick={() => requestDeleteLabel(item)}
                              className="flex w-full items-center justify-start rounded-[12px] px-3 py-2 text-sm font-semibold text-[#b42318] transition hover:bg-[#fff5f4]"
                            >
                              删除厂牌
                            </button>
                          </div>
                        ) : null}
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          <div className="mt-6 flex flex-wrap items-center gap-2">
            <button
              type="button"
              onClick={() => setPage((current) => Math.max(1, current - 1))}
              disabled={page <= 1}
              className="admin-studio-button-secondary px-4 py-2 text-sm disabled:opacity-50"
            >
              Previous
            </button>
            {visiblePages.map((pageNumber) => (
              <button
                key={pageNumber}
                type="button"
                onClick={() => setPage(pageNumber)}
                className={`inline-flex h-10 min-w-10 items-center justify-center rounded-full px-3 text-sm font-semibold ${
                  pageNumber === page ? 'bg-[#071110] text-white' : 'border border-[#e8eceb] bg-white text-[#111827]'
                }`}
              >
                {pageNumber}
              </button>
            ))}
            {totalPages > visiblePages[visiblePages.length - 1] ? (
              <>
                <span className="px-1 text-sm text-black/35">...</span>
                <button
                  type="button"
                  onClick={() => setPage(totalPages)}
                  className="inline-flex h-10 min-w-10 items-center justify-center rounded-full border border-[#e8eceb] bg-white px-3 text-sm font-semibold text-[#111827]"
                >
                  {totalPages}
                </button>
              </>
            ) : null}
            <button
              type="button"
              onClick={() => setPage((current) => Math.min(totalPages, current + 1))}
              disabled={page >= totalPages}
              className="admin-studio-button-secondary px-4 py-2 text-sm disabled:opacity-50"
            >
              Next
            </button>
          </div>
        </section>
      </section>

      <LabelDetailOverlay
        item={selectedLabel}
        detail={selectedLabelDetail}
        loading={selectedLabelLoading}
        error={selectedLabelError}
        onClose={closeDetailOverlay}
      />
      {pendingDeleteLabel ? (
        <div className="fixed inset-0 z-[90] flex items-center justify-center bg-black/45 p-4" onClick={() => setPendingDeleteLabel(null)}>
          <div
            className="w-full max-w-md rounded-[28px] border border-[#e8eceb] bg-white p-6 shadow-[0_24px_72px_rgba(17,24,39,0.18)]"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[#b42318]">删除厂牌</div>
            <div className="mt-3 text-[24px] font-semibold tracking-[-0.04em] text-[#111827]">确认删除这个厂牌吗？</div>
            <p className="mt-3 text-sm leading-6 text-[#6b7280]">
              {pendingDeleteLabel.name}
              <br />
              删除后将无法恢复，请再次确认这是你要执行的操作。
            </p>
            <div className="mt-6 flex justify-end gap-3">
              <button
                type="button"
                onClick={() => setPendingDeleteLabel(null)}
                className="inline-flex h-[44px] items-center justify-center rounded-full border border-[#e7ebef] bg-white px-5 text-sm font-semibold text-[#111827]"
              >
                取消
              </button>
              <button
                type="button"
                onClick={() => void confirmDeleteLabel()}
                disabled={deletingLabelId === pendingDeleteLabel.id}
                className="inline-flex h-[44px] items-center justify-center rounded-full bg-[#b42318] px-5 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
              >
                {deletingLabelId === pendingDeleteLabel.id ? '删除中...' : '确认删除'}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </AdminContentLayout>
  );
}
