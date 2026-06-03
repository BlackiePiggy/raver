'use client';

import { countries, getCountryCode, getEmojiFlag } from 'countries-list';
import Image from 'next/image';
import Link from 'next/link';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  CalendarDays,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Ellipsis,
  List,
  Search,
  SlidersHorizontal,
  Upload,
  Users2,
} from 'lucide-react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import {
  adminCatalogApi,
  AdminCatalogPagination,
  EventCatalogFilters,
  EventCatalogItem,
  EventCatalogResponse,
} from '@/features/admin-content/catalog/api';
import {
  buildAdminCatalogCacheKey,
  readAdminCatalogCache,
  writeAdminCatalogCache,
} from '@/features/admin-content/catalog/cache';
import { eventStudioApi } from '@/features/admin-content/event-studio/api';
import type { EventStudioLoadedEvent } from '@/features/admin-content/event-studio/types';

const PAGE_SIZE = 10;
const CACHE_TTL_MS = 10 * 60 * 1000;
const EVENT_SORT_OPTIONS = [
  { value: 'startDateDesc', label: '活动时间从晚到早' },
  { value: 'startDateAsc', label: '活动时间从早到晚' },
  { value: 'updatedAtDesc', label: '最近更新优先' },
  { value: 'updatedAtAsc', label: '最早更新优先' },
] as const;

const EMPTY_PAGINATION: AdminCatalogPagination = {
  page: 1,
  limit: PAGE_SIZE,
  total: 0,
  totalPages: 1,
};

const formatDateRange = (item: EventCatalogItem): string => {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return `${formatter.format(new Date(item.startDate))} - ${formatter.format(new Date(item.endDate))}`;
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

const resolveEventStatus = (
  item: EventCatalogItem
): { label: string; dot: string; badgeTone: string; metricLabel: string } => {
  if (item.status === 'ongoing') {
    return {
      label: '正在进行',
      dot: 'bg-[#22c55e]',
      badgeTone: 'bg-[#f0fdf4] text-[#16a34a]',
      metricLabel: 'ongoing',
    };
  }
  if (item.status === 'upcoming') {
    return {
      label: '即将开始',
      dot: 'bg-[#ffbe2e]',
      badgeTone: 'bg-[#fffbeb] text-[#d97706]',
      metricLabel: 'upcoming',
    };
  }
  if (item.status === 'cancelled') {
    return {
      label: '已取消',
      dot: 'bg-[#ef4444]',
      badgeTone: 'bg-[#fef2f2] text-[#dc2626]',
      metricLabel: 'cancelled',
    };
  }
  return {
    label: '已结束',
    dot: 'bg-[#64748b]',
    badgeTone: 'bg-[#f1f5f9] text-[#475569]',
    metricLabel: 'ended',
  };
};

const formatLocation = (item: EventCatalogItem): string =>
  [item.city, item.country].filter(Boolean).join(', ') || '地点待补充';

const resolveCountryLabel = (country?: string | null): string => {
  if (!country) return '国家待补充';
  const code = getCountryCode(country);
  const flag = code ? getEmojiFlag(code) : '';
  return flag ? `${flag} ${country}` : country;
};

const resolveStatusFilterLabel = (status?: string | null): string => {
  switch (status) {
    case 'upcoming':
      return '即将开始';
    case 'ongoing':
      return '正在进行';
    case 'ended':
      return '已结束';
    case 'cancelled':
      return '已取消';
    default:
      return '全部状态';
  }
};

// ① StatCard 改为扁平横排样式
const firstFilledText = (...values: Array<string | null | undefined>): string => {
  for (const value of values) {
    const trimmed = String(value || '').trim();
    if (trimmed) return trimmed;
  }
  return '';
};

const compactStringList = (value?: Array<string | null> | null): string[] =>
  Array.isArray(value) ? value.map((item) => String(item || '').trim()).filter(Boolean) : [];

const sortedByOrder = <T extends { sortOrder?: number | null; sort?: number | null; order?: number | null }>(
  items?: T[] | null
): T[] =>
  Array.isArray(items)
    ? [...items].sort((left, right) => {
        const leftOrder = left.sortOrder ?? left.sort ?? left.order ?? 0;
        const rightOrder = right.sortOrder ?? right.sort ?? right.order ?? 0;
        return leftOrder - rightOrder;
      })
    : [];

const formatMaybeDate = (value?: string | null): string => {
  if (!value) return '未设置';
  return new Intl.DateTimeFormat('en-CA', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date(value));
};

const detailText = (label: string, value?: string | number | null) => (
  <div>
    <span className="font-medium text-[#111827]">{label}: </span>
    {value === undefined || value === null || value === '' ? '未设置' : value}
  </div>
);

type EventDetailTabKey = 'overview' | 'schedule' | 'lineup' | 'tickets' | 'media';

const EVENT_DETAIL_TABS: Array<{ key: EventDetailTabKey; label: string }> = [
  { key: 'overview', label: 'Overview' },
  { key: 'schedule', label: 'Schedule' },
  { key: 'lineup', label: 'Lineup' },
  { key: 'tickets', label: 'Tickets' },
  { key: 'media', label: 'Media' },
];

function EventDetailOverlay({
  item,
  detail,
  loading,
  error,
  onClose,
  onRequestLoadDetail,
}: {
  item: EventCatalogItem | null;
  detail: EventStudioLoadedEvent | null;
  loading: boolean;
  error: string;
  onClose: () => void;
  onRequestLoadDetail: () => void | Promise<void>;
}) {
  const [activeTab, setActiveTab] = useState<EventDetailTabKey>('overview');
  const [previewAssetIndex, setPreviewAssetIndex] = useState<number | null>(null);

  useEffect(() => {
    if (!item) return;
    setActiveTab('overview');
    setPreviewAssetIndex(null);
  }, [item]);

  useEffect(() => {
    if (!item) return;
    if (activeTab === 'overview') return;
    if (detail || loading || error) return;
    void onRequestLoadDetail();
  }, [activeTab, detail, error, item, loading, onRequestLoadDetail]);

  if (!item) return null;

  const resolved = detail ?? null;
  const state = resolveEventStatus(item);
  const primaryName =
    firstFilledText(resolved?.nameI18n?.zh, resolved?.nameI18n?.en, resolved?.name, item.name) || item.name;
  const description = firstFilledText(resolved?.description);
  const imageAssets = sortedByOrder(resolved?.imageAssets);
  const posterAsset = imageAssets.find((asset) => ['poster', 'cover'].includes(String(asset.type || '').toLowerCase()));
  const heroImage = resolved?.coverImageUrl || posterAsset?.url || item.coverImageUrl || resolved?.lineupImageUrl || '';
  const weeks = sortedByOrder(resolved?.weeks);
  const eventDays = sortedByOrder(resolved?.eventDays);
  const lineupArtists = sortedByOrder(resolved?.lineupArtists);
  const timetableSlots = sortedByOrder(resolved?.timetableSlots ?? resolved?.lineupSlots);
  const ticketTiers = sortedByOrder(resolved?.ticketTiers);
  const stageOrder = compactStringList(resolved?.stageOrder);
  const cityCountry = [resolved?.city ?? item.city, resolved?.country ?? item.country].filter(Boolean).join(', ');
  const timeZone = resolved?.schedule?.timeZone || resolved?.timeZone || item.timeZone || '未设置';
  const eventTypeLabel = resolved?.eventType || item.eventType || '未设置';
  const organizerLabel = resolved?.organizerName || item.wikiFestival?.name || item.organizerName || '未绑定主办方';
  const activePreviewAsset = previewAssetIndex !== null ? imageAssets[previewAssetIndex] : null;

  let tabContent: React.ReactNode = null;
  if (activeTab === 'overview') {
    tabContent = (
      <div className="space-y-5">
        <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
          <div className="text-sm font-semibold text-[#111827]">活动简介</div>
          <div className="mt-3 text-sm leading-7 text-[#4b5563]">
            {description || '点击右侧的 Schedule / Lineup / Tickets / Media tab 后，系统会按需加载更完整的活动详情。'}
          </div>
        </section>
        <section className="grid gap-5 lg:grid-cols-2">
          <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
            <div className="text-sm font-semibold text-[#111827]">目录摘要</div>
            <div className="mt-4 space-y-3 text-sm text-[#4b5563]">
              {detailText('ID', item.id)}
              {detailText('Slug', item.slug)}
              {detailText('Status', item.status)}
              {detailText('Type', eventTypeLabel)}
              {detailText('Time Zone', timeZone)}
              {detailText('Organizer', organizerLabel)}
            </div>
          </div>
          <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
            <div className="text-sm font-semibold text-[#111827]">快速概览</div>
            <div className="mt-4 grid gap-3 sm:grid-cols-2">
              <div className="rounded-[18px] border border-[#edf0f2] bg-[#fafbfb] px-4 py-3">
                <div className="text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">Date Range</div>
                <div className="mt-2 text-sm font-semibold text-[#111827]">{formatDateRange(item)}</div>
              </div>
              <div className="rounded-[18px] border border-[#edf0f2] bg-[#fafbfb] px-4 py-3">
                <div className="text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">Event Days</div>
                <div className="mt-2 text-sm font-semibold text-[#111827]">{(item.eventDays?.length ?? 0).toLocaleString()}</div>
              </div>
              <div className="rounded-[18px] border border-[#edf0f2] bg-[#fafbfb] px-4 py-3 sm:col-span-2">
                <div className="text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">Location</div>
                <div className="mt-2 text-sm font-semibold text-[#111827]">{formatLocation(item)}</div>
              </div>
            </div>
          </div>
        </section>
      </div>
    );
  } else if (loading && !resolved) {
    tabContent = (
      <div className="rounded-[24px] border border-[#e8eceb] bg-white px-5 py-10 text-sm text-[#6b7280]">
        正在加载 {EVENT_DETAIL_TABS.find((tab) => tab.key === activeTab)?.label}...
      </div>
    );
  } else if (error && !resolved) {
    tabContent = (
      <div className="rounded-[24px] border border-red-200 bg-red-50 px-5 py-4 text-sm text-[#7a2d29]">
        <div>{error}</div>
        <button
          type="button"
          onClick={() => void onRequestLoadDetail()}
          className="mt-3 inline-flex h-[38px] items-center rounded-full border border-red-200 bg-white px-4 text-sm font-semibold text-[#7a2d29]"
        >
          重试加载
        </button>
      </div>
    );
  } else if (activeTab === 'schedule') {
    tabContent = (
      <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
        <div className="flex items-center justify-between gap-3">
          <div className="text-sm font-semibold text-[#111827]">Weeks / Event Days</div>
          <div className="text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">
            {weeks.length} weeks · {eventDays.length} days
          </div>
        </div>
        <div className="mt-4 grid gap-3 lg:grid-cols-2">
          {weeks.map((week) => (
            <div key={`${week.weekIndex}-${week.startDate}`} className="rounded-[18px] border border-[#edf0f2] bg-[#fafbfb] px-4 py-3 text-sm text-[#4b5563]">
              <div className="font-semibold text-[#111827]">{week.label || `Week ${week.weekIndex}`}</div>
              <div className="mt-1">{formatMaybeDate(week.startDate)} - {formatMaybeDate(week.endDate)}</div>
            </div>
          ))}
          {eventDays.map((day) => (
            <div key={day.eventDayId} className="rounded-[18px] border border-[#edf0f2] bg-[#fafbfb] px-4 py-3 text-sm text-[#4b5563]">
              <div className="font-semibold text-[#111827]">{day.label || `Day ${day.overallDayIndex}`}</div>
              <div className="mt-1">{formatMaybeDate(day.date)} {day.weekday ? `· ${day.weekday}` : ''}</div>
            </div>
          ))}
          {!weeks.length && !eventDays.length ? <div className="text-sm text-[#6b7280]">暂无 weeks / eventDays。</div> : null}
        </div>
      </section>
    );
  } else if (activeTab === 'lineup') {
    tabContent = (
      <div className="space-y-5">
        <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
          <div className="text-sm font-semibold text-[#111827]">Lineup Artists</div>
          <div className="mt-4 flex flex-wrap gap-2">
            {lineupArtists.map((artist, index) => (
              <span key={artist.id || `${artist.djName}-${index}`} className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">
                {artist.djName || compactStringList(artist.memberNames).join(' / ') || 'Unnamed'}
              </span>
            ))}
            {!lineupArtists.length ? <span className="text-sm text-[#6b7280]">暂无 lineup。</span> : null}
          </div>
        </section>
        <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
          <div className="text-sm font-semibold text-[#111827]">Stage Order</div>
          <div className="mt-4 flex flex-wrap gap-2">
            {stageOrder.map((stage) => (
              <span key={stage} className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">
                {stage}
              </span>
            ))}
            {!stageOrder.length ? <span className="text-sm text-[#6b7280]">暂无 stage。</span> : null}
          </div>
        </section>
        <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
          <div className="text-sm font-semibold text-[#111827]">Timetable Slots</div>
          <div className="mt-4 space-y-2">
            {timetableSlots.map((slot, index) => (
              <div key={slot.id || `${slot.djName}-${index}`} className="rounded-[18px] border border-[#edf0f2] bg-[#fafbfb] px-4 py-3 text-sm text-[#4b5563]">
                <span className="font-semibold text-[#111827]">{slot.djName || compactStringList(slot.memberNames).join(' / ') || 'Unnamed'}</span>
                <span> · {slot.stageName || 'Stage TBD'} · {slot.localDate || 'Date TBD'} {slot.startTime || slot.endTime ? `· ${slot.startTime || '?'} - ${slot.endTime || '?'}` : ''}</span>
              </div>
            ))}
            {!timetableSlots.length ? <div className="text-sm text-[#6b7280]">暂无 timetable slot。</div> : null}
          </div>
        </section>
      </div>
    );
  } else if (activeTab === 'tickets') {
    tabContent = (
      <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
        <div className="text-sm font-semibold text-[#111827]">票务与外链</div>
        <div className="mt-4 grid gap-3 lg:grid-cols-2">
          {[
            ['Ticket URL', resolved?.ticketUrl],
            ['Currency', resolved?.ticketCurrency],
            ['Official Website', resolved?.officialWebsite],
            ['Source URL', resolved?.sourceEventUrl],
          ].map(([label, value]) => (
            <div key={label} className="rounded-[18px] border border-[#edf0f2] bg-[#fafbfb] px-4 py-3 text-sm text-[#4b5563]">
              <div className="font-semibold text-[#111827]">{label}</div>
              <div className="mt-1 break-all">{value || '未设置'}</div>
            </div>
          ))}
        </div>
        {ticketTiers.length ? (
          <div className="mt-4 flex flex-wrap gap-2">
            {ticketTiers.map((tier, index) => (
              <span key={tier.id || `${tier.name}-${index}`} className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">
                {tier.name}: {tier.price} {tier.currency || resolved?.ticketCurrency || ''}
              </span>
            ))}
          </div>
        ) : null}
        {resolved?.ticketNotes ? <div className="mt-4 text-sm leading-6 text-[#4b5563]">{resolved.ticketNotes}</div> : null}
      </section>
    );
  } else if (activeTab === 'media') {
    tabContent = (
      <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
        <div className="flex items-center justify-between gap-3">
          <div className="text-sm font-semibold text-[#111827]">Media Assets</div>
          <div className="text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">
            {imageAssets.length} assets
          </div>
        </div>
        <div className="mt-4 grid grid-cols-[repeat(auto-fill,minmax(148px,1fr))] gap-3">
          {imageAssets.map((asset, index) => (
            <button
              key={`${asset.url}-${index}`}
              type="button"
              onClick={() => setPreviewAssetIndex(index)}
              className="overflow-hidden rounded-[18px] border border-[#edf0f2] bg-[#fafbfb] text-left transition hover:bg-white"
            >
              <div className="relative h-[112px] w-full bg-[#eef1f3]">
                <Image src={asset.url} alt={asset.label || asset.type || 'event asset'} fill className="object-cover" sizes="220px" />
              </div>
              <div className="space-y-1 px-3 py-2">
                <div className="truncate text-xs font-semibold text-[#111827]">{asset.label || asset.fileName || 'Asset'}</div>
                <div className="truncate text-[11px] text-[#6b7280]">{asset.type || 'unknown type'}</div>
              </div>
            </button>
          ))}
          {!imageAssets.length ? <div className="text-sm text-[#6b7280]">暂无 media assets。</div> : null}
        </div>
      </section>
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
          aria-label="关闭活动详情"
        >
          ×
        </button>

        <div className="grid max-h-[92vh] overflow-y-auto lg:grid-cols-[380px_minmax(0,1fr)]">
          <div className="border-b border-[#e8eceb] bg-[linear-gradient(180deg,#eef4f0_0%,#f7f5ef_100%)] p-6 lg:border-b-0 lg:border-r">
            <div className="overflow-hidden rounded-[24px] border border-[#dfe7e2] bg-[#e7ece9]">
              <div className="relative aspect-[1.42/1]">
                {heroImage ? (
                  <Image src={heroImage} alt={primaryName} fill className="object-cover" sizes="900px" />
                ) : (
                  <div className="flex h-full items-center justify-center text-sm text-[#7b8794]">暂无活动封面</div>
                )}
              </div>
            </div>

            <div className="-mt-10 px-4">
              <div className="rounded-[24px] border border-[#e8eceb] bg-white/96 p-5 shadow-[0_12px_32px_rgba(33,52,47,0.08)]">
                <div className="flex flex-wrap items-center gap-2">
                  <span className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-[12px] font-semibold ${state.badgeTone}`}>
                    <span className={`h-2 w-2 rounded-full ${state.dot}`} />
                    {state.label}
                  </span>
                  <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-[12px] font-semibold text-[#6b7280]">
                    {eventTypeLabel}
                  </span>
                </div>
                <div className="mt-3 text-[28px] font-semibold tracking-[-0.04em] text-[#111827]">{primaryName}</div>
                <div className="mt-2 text-sm font-medium text-[#6b7280]">
                  {organizerLabel} · {cityCountry || '地点待补充'}
                </div>
              </div>
            </div>

            <div className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-1">
              {[
                ['Status', state.label],
                ['Type', eventTypeLabel],
                ['Days', (eventDays.length || item.eventDays?.length || 0).toLocaleString()],
                ['Time Zone', timeZone],
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
                {detailText('ID', item.id)}
                {detailText('开始日期', formatMaybeDate(item.startDate))}
                {detailText('结束日期', formatMaybeDate(item.endDate))}
                {detailText('Organizer', organizerLabel)}
                {detailText('Location', cityCountry || formatLocation(item))}
                {detailText('Updated At', formatDateTime(item.updatedAt))}
              </div>
            </div>
          </div>

          <div className="p-6">
            <div className="flex items-center justify-between gap-3">
              <div>
                <div className="text-xs font-semibold uppercase tracking-[0.14em] text-[#9aa1ad]">Event Profile</div>
                <div className="mt-2 text-[26px] font-semibold tracking-[-0.04em] text-[#111827]">详细信息</div>
              </div>
              <div className="flex items-center gap-2">
                <Link
                  href={`/events/${item.id}`}
                  className="inline-flex h-[42px] items-center rounded-full border border-[#e8eceb] bg-white px-5 text-sm font-semibold text-[#111827]"
                >
                  前台页
                </Link>
                <Link
                  href={`/admin/content/events/${item.id}/edit`}
                  className="inline-flex h-[42px] items-center rounded-full bg-[#071110] px-5 text-sm font-semibold text-white"
                >
                  编辑活动
                </Link>
              </div>
            </div>

            <div className="mt-6 flex flex-wrap gap-2 rounded-[24px] border border-[#e8eceb] bg-white/70 p-2">
              {EVENT_DETAIL_TABS.map((tab) => (
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

        {activePreviewAsset ? (
          <div className="absolute inset-0 z-20 flex items-center justify-center bg-black/70 p-6" onClick={() => setPreviewAssetIndex(null)}>
            <div
              className="relative w-full max-w-[980px] overflow-hidden rounded-[28px] border border-white/10 bg-[#101414] shadow-[0_30px_120px_rgba(0,0,0,0.45)]"
              onClick={(event) => event.stopPropagation()}
            >
              <button
                type="button"
                onClick={() => setPreviewAssetIndex(null)}
                className="absolute right-4 top-4 z-10 inline-flex h-10 w-10 items-center justify-center rounded-full bg-white/10 text-white"
                aria-label="关闭图片预览"
              >
                ×
              </button>
              <div className="grid gap-0 lg:grid-cols-[minmax(0,1fr)_260px]">
                <div className="relative min-h-[480px] bg-black">
                  <Image
                    src={activePreviewAsset.url}
                    alt={activePreviewAsset.label || activePreviewAsset.type || 'event asset preview'}
                    fill
                    className="object-contain"
                    sizes="1200px"
                  />
                </div>
                <div className="space-y-3 bg-[#111827] p-5 text-white">
                  <div className="text-xs font-semibold uppercase tracking-[0.14em] text-white/45">Media Detail</div>
                  <div className="text-lg font-semibold">{activePreviewAsset.label || activePreviewAsset.fileName || 'Asset'}</div>
                  <div className="text-sm text-white/70">{activePreviewAsset.type || 'unknown type'}</div>
                  {activePreviewAsset.fileName ? <div className="break-all text-sm text-white/70">{activePreviewAsset.fileName}</div> : null}
                  <div className="pt-2 text-xs text-white/45">单击图片外部区域可关闭预览。</div>
                </div>
              </div>
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );
}

function StatCard({
  label,
  value,
  icon,
  dotClassName,
}: {
  label: string;
  value: number;
  icon?: JSX.Element;
  dotClassName?: string;
}) {
  return (
    <div className="flex items-center gap-2.5">
      {icon ? (
        <div className="flex h-9 w-9 items-center justify-center rounded-[12px] bg-[#eefaf1] text-[#22c55e]">
          {icon}
        </div>
      ) : (
        <span className={`h-2.5 w-2.5 shrink-0 rounded-full ${dotClassName || 'bg-[#22c55e]'}`} />
      )}
      <div className="text-[14px] font-semibold text-[#6b7280]">{label}</div>
      <div className="flex items-baseline gap-1">
        <span className="text-[22px] font-semibold leading-none tracking-[-0.03em] text-[#111827]">
          {value.toLocaleString()}
        </span>
        <span className="text-[13px] leading-none text-[#b1b7c3]">个</span>
      </div>
    </div>
  );
}

export default function EventCatalogPageClient() {
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('all');
  const [eventType, setEventType] = useState('all');
  const [country, setCountry] = useState('all');
  const [sortBy, setSortBy] = useState<(typeof EVENT_SORT_OPTIONS)[number]['value']>('startDateDesc');
  const [page, setPage] = useState(1);
  const [items, setItems] = useState<EventCatalogItem[]>([]);
  const [pagination, setPagination] = useState<AdminCatalogPagination>(EMPTY_PAGINATION);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedEvent, setSelectedEvent] = useState<EventCatalogItem | null>(null);
  const [selectedEventDetail, setSelectedEventDetail] = useState<EventStudioLoadedEvent | null>(null);
  const [selectedEventError, setSelectedEventError] = useState('');
  const [selectedEventLoading, setSelectedEventLoading] = useState(false);
  const [detailCache, setDetailCache] = useState<Record<string, EventStudioLoadedEvent>>({});
  const [menuOpenEventId, setMenuOpenEventId] = useState<string | null>(null);
  const [pendingDeleteEvent, setPendingDeleteEvent] = useState<EventCatalogItem | null>(null);
  const [deletingEventId, setDeletingEventId] = useState<string | null>(null);
  const actionMenuRef = useRef<HTMLDivElement | null>(null);
  const detailRequestRef = useRef(0);

  const filters = useMemo<EventCatalogFilters>(
    () => ({
      page,
      limit: PAGE_SIZE,
      search: search || undefined,
      status,
      city: undefined,
      country: country === 'all' ? undefined : country,
      eventType: eventType === 'all' ? undefined : eventType,
      sortBy,
    }),
    [page, search, status, country, eventType, sortBy]
  );

  const cacheKey = useMemo(
    () =>
      buildAdminCatalogCacheKey('events-catalog', {
        page,
        limit: PAGE_SIZE,
        search: search || undefined,
        status,
        city: undefined,
        country: country === 'all' ? undefined : country,
        eventType: eventType === 'all' ? undefined : eventType,
        sortBy,
      }),
    [page, search, status, country, eventType, sortBy]
  );

  const loadCatalog = useCallback(
    async (options?: { force?: boolean }) => {
      const cached = !options?.force ? readAdminCatalogCache<EventCatalogResponse>(cacheKey) : null;

      if (cached) {
        setItems(cached.data.items);
        setPagination(cached.data.pagination);
        setError('');
        setIsLoading(false);
        if (!cached.isStale) return;
      } else {
        setIsLoading(true);
      }

      try {
        const response = await adminCatalogApi.fetchEvents(filters);
        const written = writeAdminCatalogCache(cacheKey, response, CACHE_TTL_MS);
        setItems(response.items);
        setPagination(response.pagination);
        void written;
        setError('');
      } catch (nextError) {
        setError(nextError instanceof Error ? nextError.message : '活动目录加载失败');
      } finally {
        setIsLoading(false);
      }
    },
    [cacheKey, filters]
  );

  useEffect(() => {
    void loadCatalog();
  }, [loadCatalog]);

  useEffect(() => {
    if (!menuOpenEventId) return;

    const handlePointerDown = (event: MouseEvent) => {
      if (!actionMenuRef.current) return;
      if (event.target instanceof Node && actionMenuRef.current.contains(event.target)) return;
      setMenuOpenEventId(null);
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setMenuOpenEventId(null);
      }
    };

    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [menuOpenEventId]);

  const handleSearchSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setPage(1);
    setSearch(searchInput.trim());
  };

  const statusCounts = useMemo(() => {
    const counts = { upcoming: 0, ongoing: 0, ended: 0, cancelled: 0 };
    items.forEach((item) => {
      const state = resolveEventStatus(item).metricLabel;
      if (state === 'ongoing') counts.ongoing += 1;
      else if (state === 'upcoming') counts.upcoming += 1;
      else if (state === 'cancelled') counts.cancelled += 1;
      else counts.ended += 1;
    });
    return counts;
  }, [items]);

  const visiblePages = useMemo(() => {
    const totalPages = Math.max(1, pagination.totalPages);
    const start = Math.max(1, Math.min(totalPages - 4, pagination.page - 2));
    const end = Math.min(totalPages, start + 4);
    return Array.from({ length: end - start + 1 }, (_, index) => start + index);
  }, [pagination.page, pagination.totalPages]);

  const countryOptions = useMemo(() => {
    const names = Object.values(countries)
      .map((item) => item.name?.trim())
      .filter((value): value is string => Boolean(value));
    return Array.from(new Set(names)).sort((left, right) => left.localeCompare(right, 'en'));
  }, []);

  const selectedSortLabel = EVENT_SORT_OPTIONS.find((item) => item.value === sortBy)?.label || '活动时间从晚到早';

  const openDetailOverlay = useCallback((item: EventCatalogItem) => {
    setMenuOpenEventId(null);
    detailRequestRef.current += 1;
    setSelectedEvent(item);
    setSelectedEventError('');
    const cached = detailCache[item.id];
    if (cached) {
      setSelectedEventDetail(cached);
      setSelectedEventLoading(false);
      return;
    }

    setSelectedEventDetail(null);
    setSelectedEventLoading(false);
  }, [detailCache]);

  const loadSelectedEventDetail = useCallback(async () => {
    if (!selectedEvent) return;

    const cached = detailCache[selectedEvent.id];
    if (cached) {
      setSelectedEventDetail(cached);
      setSelectedEventError('');
      setSelectedEventLoading(false);
      return;
    }

    const requestId = detailRequestRef.current + 1;
    detailRequestRef.current = requestId;
    const selectedEventId = selectedEvent.id;
    setSelectedEventLoading(true);
    setSelectedEventError('');

    try {
      const detail = await eventStudioApi.fetchEvent(selectedEventId);
      if (detailRequestRef.current !== requestId) return;
      setDetailCache((current) => ({ ...current, [selectedEventId]: detail }));
      setSelectedEventDetail(detail);
    } catch (detailError) {
      if (detailRequestRef.current !== requestId) return;
      setSelectedEventError(detailError instanceof Error ? detailError.message : '活动详情加载失败');
    } finally {
      if (detailRequestRef.current !== requestId) return;
      setSelectedEventLoading(false);
    }
  }, [detailCache, selectedEvent]);

  const closeDetailOverlay = useCallback(() => {
    setMenuOpenEventId(null);
    detailRequestRef.current += 1;
    setSelectedEvent(null);
    setSelectedEventDetail(null);
    setSelectedEventError('');
    setSelectedEventLoading(false);
  }, []);

  const requestDeleteEvent = useCallback((item: EventCatalogItem) => {
    setMenuOpenEventId(null);
    setPendingDeleteEvent(item);
  }, []);

  const confirmDeleteEvent = useCallback(async () => {
    if (!pendingDeleteEvent) return;
    const eventId = pendingDeleteEvent.id;
    try {
      setDeletingEventId(eventId);
      await eventStudioApi.deleteEvent(eventId);
      setItems((current) => current.filter((item) => item.id !== eventId));
      setPagination((current) => ({
        ...current,
        total: Math.max(0, current.total - 1),
      }));
      if (selectedEvent?.id === eventId) {
        closeDetailOverlay();
      }
      setPendingDeleteEvent(null);
      setDetailCache((current) => {
        const next = { ...current };
        delete next[eventId];
        return next;
      });
    } catch (deleteError) {
      setError(deleteError instanceof Error ? deleteError.message : '删除活动失败');
    } finally {
      setDeletingEventId(null);
    }
  }, [closeDetailOverlay, pendingDeleteEvent, selectedEvent]);

  return (
    <AdminContentLayout
      title="活动目录"
      eyebrow=""
      description="统一查看与管理所有活动。默认按活动时间从晚到早排列，可按国家、状态与更新时间筛选。"
      actions={
        <>
          <Link
            href="/admin/content/events/new"
            className="inline-flex items-center gap-2.5 rounded-full border border-[#e8eceb] bg-white px-7 py-3.5 text-[15px] font-semibold text-[#111827] shadow-[0_2px_10px_rgba(15,23,42,0.04)]"
          >
            <Upload className="h-5 w-5" />
            <span>导入活动</span>
          </Link>
          <Link
            href="/admin/content/events/new"
            className="inline-flex items-center gap-2.5 rounded-full bg-[#071110] px-7 py-3.5 text-[15px] font-semibold text-white shadow-[0_10px_24px_rgba(7,17,16,0.18)]"
          >
            <span className="text-[22px] leading-none">+</span>
            <span>新建活动</span>
          </Link>
        </>
      }
    >
      <section className="space-y-5">
        {/* ② 筛选区 + 统计块 — 同一白卡 */}
        <section className="rounded-[28px] border border-[#edf0f2] bg-white px-6 py-5 shadow-[0_4px_20px_rgba(17,24,39,0.04)]">
          <form onSubmit={handleSearchSubmit} className="flex flex-wrap gap-3">
            {/* 搜索框 — ① h-[54px] */}
            <label className="flex h-[54px] min-w-[240px] flex-[1.45_1_280px] items-center gap-3 rounded-[18px] border border-[#eceff1] bg-white px-5 text-[#111827]">
              <Search className="h-5 w-5 shrink-0 text-[#9ca3af]" />
              <input
                value={searchInput}
                onChange={(event) => setSearchInput(event.target.value)}
                placeholder="搜索活动名称、主办方、城市..."
                className="w-full border-0 bg-transparent px-0 py-0 text-[15px] font-medium text-[#111827] outline-none placeholder:text-[#9ca3af]"
              />
            </label>

            {/* 全部状态 */}
            <label className="relative flex h-[54px] min-w-[148px] flex-1 items-center justify-between rounded-[18px] border border-[#eceff1] bg-white px-5 text-[15px] font-semibold text-[#111827]">
              <span>{resolveStatusFilterLabel(status)}</span>
              <select
                value={status}
                onChange={(event) => { setStatus(event.target.value); setPage(1); }}
                className="absolute inset-0 opacity-0"
              >
                <option value="all">全部状态</option>
                <option value="upcoming">即将开始</option>
                <option value="ongoing">正在进行</option>
                <option value="ended">已结束</option>
                <option value="cancelled">已取消</option>
              </select>
              <ChevronDown className="h-4.5 w-4.5 text-[#9ca3af]" />
            </label>

            {/* 全部类型 */}
            <label className="relative flex h-[54px] min-w-[148px] flex-1 items-center justify-between rounded-[18px] border border-[#eceff1] bg-white px-5 text-[15px] font-semibold text-[#111827]">
              <span>{eventType === 'all' ? '全部类型' : eventType}</span>
              <select
                value={eventType}
                onChange={(event) => { setEventType(event.target.value); setPage(1); }}
                className="absolute inset-0 opacity-0"
              >
                <option value="all">全部类型</option>
                <option value="电音节">电音节</option>
                <option value="酒吧活动">酒吧活动</option>
                <option value="露天活动">露天活动</option>
                <option value="俱乐部派对">俱乐部派对</option>
                <option value="仓库派对">仓库派对</option>
                <option value="巡演专场">巡演专场</option>
                <option value="其他">其他</option>
              </select>
              <ChevronDown className="h-4.5 w-4.5 text-[#9ca3af]" />
            </label>

            {/* 全部国家 */}
            <label className="relative flex h-[54px] min-w-[148px] flex-1 items-center justify-between rounded-[18px] border border-[#eceff1] bg-white px-5 text-[15px] font-semibold text-[#111827]">
              <span>{country === 'all' ? '全部国家' : resolveCountryLabel(country)}</span>
              <select
                value={country}
                onChange={(event) => { setCountry(event.target.value); setPage(1); }}
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

            {/* 更多筛选 */}
            <button
              type="button"
              className="flex h-[54px] min-w-[130px] items-center justify-center gap-2.5 rounded-[18px] border border-[#eceff1] bg-white px-5 text-[15px] font-semibold text-[#111827]"
            >
              <SlidersHorizontal className="h-4.5 w-4.5" />
              <span>更多筛选</span>
            </button>

            {/* 排序方式 */}
            <label className="ml-auto relative flex h-[54px] min-w-[180px] cursor-pointer items-center justify-between gap-2 rounded-[18px] border border-[#eceff1] bg-white px-5 text-[15px] font-semibold text-[#111827]">
              <span>{selectedSortLabel}</span>
              <select
                value={sortBy}
                onChange={(event) => { setSortBy(event.target.value as (typeof EVENT_SORT_OPTIONS)[number]['value']); setPage(1); }}
                className="absolute inset-0 opacity-0"
              >
                {EVENT_SORT_OPTIONS.map((item) => (
                  <option key={item.value} value={item.value}>
                    {item.label}
                  </option>
                ))}
              </select>
              <ChevronDown className="h-4.5 w-4.5 text-[#9ca3af]" />
            </label>
          </form>

          {/* ③ 统计块 — 扁平横排，用竖线分隔 */}
          <div className="mt-5 flex flex-wrap items-center gap-0 divide-x divide-[#edf0f2]">
            <div className="pr-7">
              <StatCard
                label="全部活动"
                value={pagination.total}
                icon={<List className="h-5 w-5" strokeWidth={2.4} />}
              />
            </div>
            <div className="px-7">
              <StatCard label="正在进行" value={statusCounts.ongoing} dotClassName="bg-[#22c55e]" />
            </div>
            <div className="px-7">
              <StatCard label="即将开始" value={statusCounts.upcoming} dotClassName="bg-[#ffbe2e]" />
            </div>
            <div className="px-7">
              <StatCard label="已结束" value={statusCounts.ended} dotClassName="bg-[#64748b]" />
            </div>
            <div className="pl-7">
              <StatCard label="已取消" value={statusCounts.cancelled} dotClassName="bg-[#ef4444]" />
            </div>
          </div>
          <div className="mt-4 grid gap-2 rounded-[22px] border border-[#edf0f2] bg-[#fafbfb] px-4 py-3 text-sm text-[#4b5563] md:grid-cols-2 xl:grid-cols-4">
            <div><span className="font-semibold text-[#111827]">即将开始</span>：后端状态为 `upcoming` 的活动。</div>
            <div><span className="font-semibold text-[#111827]">正在进行</span>：后端状态为 `ongoing` 的活动。</div>
            <div><span className="font-semibold text-[#111827]">已结束</span>：后端状态为 `ended`，以及未命中其他三态时按已结束显示的活动。</div>
            <div><span className="font-semibold text-[#111827]">已取消</span>：后端状态为 `cancelled` 的活动。</div>
          </div>
        </section>

        {/* 列表区 */}
        <section className="overflow-hidden rounded-[28px] border border-[#edf0f2] bg-white shadow-[0_4px_20px_rgba(17,24,39,0.04)]">
          {error ? (
            <div className="border-b border-red-200 bg-red-50 px-6 py-4 text-sm text-[#7a2d29]">{error}</div>
          ) : null}

          {isLoading ? (
            <div className="px-6 py-20 text-center text-sm text-[#6b7280]">活动目录加载中…</div>
          ) : items.length === 0 ? (
            <div className="px-6 py-20 text-center text-sm text-[#6b7280]">当前筛选条件下还没有活动。</div>
          ) : (
            // ④ 无表头，直接列表
            <div className="divide-y divide-[#edf0f2]">
              {items.map((item) => {
                const state = resolveEventStatus(item);
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
                    className="flex cursor-pointer flex-col gap-4 px-6 py-5 transition-colors hover:bg-[#fbfcfb] focus:outline-none focus:ring-2 focus:ring-[#d9e7dd] lg:flex-row lg:items-center lg:gap-6"
                  >
                    {/* 左：封面 + 信息 */}
                    <div className="flex min-w-0 flex-1 gap-4">
                      {/* ⑦ 封面图 180×110 */}
                      <div className="h-[110px] w-[180px] shrink-0 overflow-hidden rounded-[16px] bg-[#f3f5f7]">
                        {item.coverImageUrl ? (
                          <Image
                            src={item.coverImageUrl}
                            alt={item.name}
                            width={180}
                            height={110}
                            className="h-full w-full object-cover"
                          />
                        ) : (
                          <div className="flex h-full items-center justify-center text-sm text-[#9ca3af]">暂无封面</div>
                        )}
                      </div>

                      <div className="min-w-0 flex-1">
                        {/* 状态 badge */}
                        <div className="flex flex-wrap items-center gap-2">
                          <span
                            className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-[13px] font-semibold ${state.badgeTone}`}
                          >
                            <span className={`h-2 w-2 rounded-full ${state.dot}`} />
                            {state.label}
                          </span>
                        </div>

                        <h2 className="mt-2 truncate text-[20px] font-semibold tracking-[-0.025em] text-[#111827]">
                          {item.name}
                        </h2>

                        <div className="mt-0.5 truncate text-[13px] font-medium text-[#6b7280]">
                          {item.wikiFestival?.name || item.organizerName || '未绑定主办方'} · {formatLocation(item)}
                        </div>

                        <div className="mt-2.5 flex flex-wrap items-center gap-x-5 gap-y-1.5 text-[13px] font-medium text-[#7d8592]">
                          <div className="flex items-center gap-2">
                            <CalendarDays className="h-4 w-4 text-[#b1b7c3]" />
                            <span>{formatDateRange(item)}</span>
                          </div>
                          <div className="flex items-center gap-2">
                            <Users2 className="h-4 w-4 text-[#b1b7c3]" />
                            <span>{item.eventDays?.length ?? 0} 天</span>
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* ⑤ 右侧：时区 tag + 更新时间 合并列 */}
                    <div className="flex shrink-0 flex-col items-start gap-2 lg:w-[200px]">
                      {item.timeZone ? (
                        <span className="inline-flex rounded-[8px] bg-[#f4f5f7] px-3 py-1.5 text-[12px] font-semibold text-[#6b7280]">
                          {item.timeZone}
                        </span>
                      ) : null}
                      <div className="text-[14px] font-medium text-[#6b7280]">
                        更新于 {formatDateTime(item.updatedAt)}
                      </div>
                    </div>

                    {/* ⑥ 操作按钮 — rounded-full 风格 */}
                    <div className="flex shrink-0 items-center gap-2.5">
                      <button
                        type="button"
                        onClick={(event) => {
                          event.stopPropagation();
                          void openDetailOverlay(item);
                        }}
                        className="inline-flex h-[44px] items-center justify-center rounded-full border border-[#e7ebef] bg-white px-6 text-[14px] font-semibold text-[#111827] transition hover:bg-[#f7f8fa]"
                      >
                        查看详情
                      </button>
                      <Link
                        href={`/admin/content/events/${item.id}/edit`}
                        onClick={(event) => event.stopPropagation()}
                        className="inline-flex h-[44px] items-center justify-center rounded-full bg-[#071110] px-6 text-[14px] font-semibold text-white shadow-[0_6px_16px_rgba(7,17,16,0.15)]"
                      >
                        编辑活动
                      </Link>
                      <div
                        className="relative"
                        ref={menuOpenEventId === item.id ? actionMenuRef : null}
                      >
                        <button
                          type="button"
                          onClick={(event) => {
                            event.stopPropagation();
                            setMenuOpenEventId((current) => (current === item.id ? null : item.id));
                          }}
                          className="inline-flex h-[44px] w-[44px] items-center justify-center rounded-full border border-[#e7ebef] bg-white text-[#111827]"
                          aria-label="更多操作"
                        >
                          <Ellipsis className="h-5 w-5" />
                        </button>
                        {menuOpenEventId === item.id ? (
                          <div
                            className="absolute right-0 top-[52px] z-20 min-w-[148px] rounded-[18px] border border-[#e7ebef] bg-white p-2 shadow-[0_16px_36px_rgba(17,24,39,0.14)]"
                            onClick={(event) => event.stopPropagation()}
                          >
                            <button
                              type="button"
                              onClick={() => requestDeleteEvent(item)}
                              className="flex w-full items-center justify-start rounded-[12px] px-3 py-2 text-sm font-semibold text-[#b42318] transition hover:bg-[#fff5f4]"
                            >
                              删除活动
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

          {/* 分页 */}
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
                    pageNumber === pagination.page
                      ? 'bg-[#071110] text-white'
                      : 'text-[#111827]'
                  }`}
                >
                  {pageNumber}
                </button>
              ))}

              {pagination.totalPages > visiblePages[visiblePages.length - 1] ? (
                <>
                  <span className="px-1 text-[18px] text-[#9ca3af]">...</span>
                  <button
                    type="button"
                    onClick={() => setPage(pagination.totalPages)}
                    className="inline-flex h-10 min-w-10 items-center justify-center rounded-full px-3.5 text-[15px] font-semibold text-[#111827]"
                  >
                    {pagination.totalPages}
                  </button>
                </>
              ) : null}

              <button
                type="button"
                disabled={pagination.page >= pagination.totalPages}
                onClick={() => setPage((current) => Math.min(pagination.totalPages, current + 1))}
                className="inline-flex h-10 w-10 items-center justify-center rounded-full text-[#111827] disabled:cursor-not-allowed disabled:opacity-40"
              >
                <ChevronRight className="h-5 w-5" />
              </button>
            </div>

            <div className="flex cursor-pointer items-center gap-2 rounded-[14px] border border-[#e8ecef] bg-white px-5 py-2.5 text-[14px] font-semibold text-[#111827]">
              <span>{pagination.limit} 条/页</span>
              <ChevronDown className="h-4 w-4 text-[#9ca3af]" />
            </div>
          </div>
        </section>
      <EventDetailOverlay
        item={selectedEvent}
        detail={selectedEventDetail}
        loading={selectedEventLoading}
        error={selectedEventError}
        onClose={closeDetailOverlay}
        onRequestLoadDetail={loadSelectedEventDetail}
      />
      {pendingDeleteEvent ? (
        <div className="fixed inset-0 z-[90] flex items-center justify-center bg-black/45 p-4" onClick={() => setPendingDeleteEvent(null)}>
          <div
            className="w-full max-w-md rounded-[28px] border border-[#e8eceb] bg-white p-6 shadow-[0_24px_72px_rgba(17,24,39,0.18)]"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[#b42318]">Delete Event</div>
            <div className="mt-3 text-[24px] font-semibold tracking-[-0.04em] text-[#111827]">确认删除这个活动？</div>
            <p className="mt-3 text-sm leading-6 text-[#6b7280]">
              {pendingDeleteEvent.name}
              <br />
              删除后将无法恢复，请再次确认这是你要执行的操作。
            </p>
            <div className="mt-6 flex justify-end gap-3">
              <button
                type="button"
                onClick={() => setPendingDeleteEvent(null)}
                className="inline-flex h-[44px] items-center justify-center rounded-full border border-[#e7ebef] bg-white px-5 text-sm font-semibold text-[#111827]"
              >
                取消
              </button>
              <button
                type="button"
                onClick={() => void confirmDeleteEvent()}
                disabled={deletingEventId === pendingDeleteEvent.id}
                className="inline-flex h-[44px] items-center justify-center rounded-full bg-[#b42318] px-5 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
              >
                {deletingEventId === pendingDeleteEvent.id ? '删除中...' : '确认删除'}
              </button>
            </div>
          </div>
        </div>
      ) : null}
      </section>
    </AdminContentLayout>
  );
}
