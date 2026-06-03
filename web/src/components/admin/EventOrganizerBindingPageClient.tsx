'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { useCallback, useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import EntityBindingField from '@/components/admin/EntityBindingField';
import type { EntityBindingValue } from '@/components/admin/EntityBindingSearch';
import {
  eventOrganizerBindingApi,
  type EventOrganizerBindingCatalogItem,
} from '@/features/admin-content/event-organizer-binding/api';
import type { EventStudioOrganizer } from '@/features/admin-content/event-studio/types';

const PAGE_SIZE = 24;

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

const formatDateRange = (startDate: string, endDate: string): string => {
  const formatter = new Intl.DateTimeFormat('zh-CN', {
    month: 'short',
    day: 'numeric',
  });
  return `${formatter.format(new Date(startDate))} - ${formatter.format(new Date(endDate))}`;
};

const buildUnboundClusterKey = (item: EventOrganizerBindingCatalogItem): string => {
  const organizerName = String(item.organizerName || '').trim();
  if (organizerName) return organizerName;

  const name = String(item.name || '').trim();
  if (!name) return 'Unnamed event';
  const normalized = name
    .replace(/\d{4}.*/g, '')
    .replace(/\([^)]*\)/g, '')
    .replace(/[^\p{L}\p{N}\u4e00-\u9fa5]+/gu, ' ')
    .trim();

  if (!normalized) return name;
  const tokens = normalized.split(/\s+/).filter(Boolean);
  return tokens.slice(0, 3).join(' ');
};

const organizerToBindingValue = (organizer: EventStudioOrganizer): EntityBindingValue => ({
  id: organizer.id,
  name: organizer.name,
  subtitle: [organizer.city, organizer.country].filter(Boolean).join(', ') || organizer.tagline || null,
  imageUrl: organizer.avatarUrl || organizer.backgroundUrl || null,
});

export default function EventOrganizerBindingPageClient() {
  const searchParams = useSearchParams();
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('all');
  const [page, setPage] = useState(1);
  const [items, setItems] = useState<EventOrganizerBindingCatalogItem[]>([]);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [selectedEventId, setSelectedEventId] = useState<string | null>(null);
  const [selectedOrganizer, setSelectedOrganizer] = useState<EventStudioOrganizer | null>(null);
  const [selectedEventIds, setSelectedEventIds] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [cacheMessage, setCacheMessage] = useState(
    'Catalog summary is served from the server cache layer and is suitable for low-frequency binding work.'
  );

  const preselectedOrganizerId = searchParams.get('organizerId')?.trim() || '';
  const preselectedOrganizerName = searchParams.get('organizerName')?.trim() || '';

  const selectedEvent = useMemo(
    () => items.find((item) => item.id === selectedEventId) ?? null,
    [items, selectedEventId]
  );
  const selectedEvents = useMemo(
    () => items.filter((item) => selectedEventIds.includes(item.id)),
    [items, selectedEventIds]
  );
  const selectedOrganizerBinding = useMemo<EntityBindingValue[]>(
    () => (selectedOrganizer ? [organizerToBindingValue(selectedOrganizer)] : []),
    [selectedOrganizer]
  );
  const organizerSeedQuery = selectedOrganizer?.name || preselectedOrganizerName;
  const allVisibleSelected = items.length > 0 && items.every((item) => selectedEventIds.includes(item.id));

  const unboundClusters = useMemo(() => {
    const map = new Map<string, EventOrganizerBindingCatalogItem[]>();
    items
      .filter((item) => !item.wikiFestivalId)
      .forEach((item) => {
        const key = buildUnboundClusterKey(item);
        const bucket = map.get(key) ?? [];
        bucket.push(item);
        map.set(key, bucket);
      });

    return Array.from(map.entries())
      .map(([label, rows]) => ({ label, rows }))
      .sort((left, right) => right.rows.length - left.rows.length)
      .slice(0, 8);
  }, [items]);

  const loadEvents = useCallback(async () => {
    try {
      setIsLoading(true);
      const response = await eventOrganizerBindingApi.fetchEvents({
        page,
        limit: PAGE_SIZE,
        search: search || undefined,
        status,
      });
      setItems(response.items);
      setTotalPages(response.pagination.totalPages);
      setTotal(response.pagination.total);
      setCacheMessage(
        response.cache?.hit
          ? 'This page hit the catalog cache and is ready for continuous low-frequency binding work.'
          : 'This page was refreshed from the summary layer instead of running a heavy full scan.'
      );

      if (!selectedEventId && response.items[0]) {
        setSelectedEventId(response.items[0].id);
      }
      if (selectedEventId && !response.items.some((item) => item.id === selectedEventId)) {
        setSelectedEventId(response.items[0]?.id ?? null);
      }
      setSelectedEventIds((current) =>
        current.filter((eventId) => response.items.some((item) => item.id === eventId))
      );
      setError('');
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to load event binding catalog.');
    } finally {
      setIsLoading(false);
    }
  }, [page, search, selectedEventId, status]);

  useEffect(() => {
    void loadEvents();
  }, [loadEvents]);

  useEffect(() => {
    if (!preselectedOrganizerId || !preselectedOrganizerName) return;
    setSelectedOrganizer((current) => {
      if (current?.id === preselectedOrganizerId) return current;
      return {
        id: preselectedOrganizerId,
        name: preselectedOrganizerName,
        aliases: [],
        country: '',
        city: '',
        tagline: '',
      };
    });
  }, [preselectedOrganizerId, preselectedOrganizerName]);

  const handleSearchSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setPage(1);
    setSearch(searchInput.trim());
  };

  const handleBind = async () => {
    if (!selectedEvent || !selectedOrganizer) return;
    try {
      setIsSubmitting(true);
      setError('');
      setSuccessMessage('');
      await eventOrganizerBindingApi.bindOrganizer({
        eventId: selectedEvent.id,
        organizerId: selectedOrganizer.id,
        organizerName: selectedOrganizer.name,
      });
      setSuccessMessage(`Bound "${selectedEvent.name}" to organizer "${selectedOrganizer.name}".`);
      await loadEvents();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to bind organizer.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleClear = async () => {
    if (!selectedEvent) return;
    try {
      setIsSubmitting(true);
      setError('');
      setSuccessMessage('');
      await eventOrganizerBindingApi.clearOrganizer({
        eventId: selectedEvent.id,
      });
      setSuccessMessage(`Cleared current organizer binding for "${selectedEvent.name}".`);
      await loadEvents();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to clear organizer binding.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const toggleEventSelection = (eventId: string) => {
    setSelectedEventIds((current) =>
      current.includes(eventId) ? current.filter((item) => item !== eventId) : [...current, eventId]
    );
  };

  const toggleSelectAllVisible = () => {
    if (allVisibleSelected) {
      setSelectedEventIds([]);
      return;
    }
    setSelectedEventIds(items.map((item) => item.id));
  };

  const selectCluster = (clusterEventIds: string[]) => {
    setSelectedEventIds((current) => Array.from(new Set([...current, ...clusterEventIds])));
  };

  const handleBatchBind = async () => {
    if (!selectedOrganizer || selectedEventIds.length === 0) return;
    try {
      setIsSubmitting(true);
      setError('');
      setSuccessMessage('');
      const result = await eventOrganizerBindingApi.bindOrganizerBatch({
        eventIds: selectedEventIds,
        organizerId: selectedOrganizer.id,
        organizerName: selectedOrganizer.name,
      });
      setSuccessMessage(
        result.failureCount > 0
          ? `Batch binding finished: ${result.successCount} succeeded, ${result.failureCount} failed.`
          : `Batch binding finished: ${result.successCount} succeeded.`
      );
      await loadEvents();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to batch bind organizer.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleBatchClear = async () => {
    if (selectedEventIds.length === 0) return;
    try {
      setIsSubmitting(true);
      setError('');
      setSuccessMessage('');
      const result = await eventOrganizerBindingApi.clearOrganizerBatch({
        eventIds: selectedEventIds,
      });
      setSuccessMessage(
        result.failureCount > 0
          ? `Batch clear finished: ${result.successCount} succeeded, ${result.failureCount} failed.`
          : `Batch clear finished: ${result.successCount} succeeded.`
      );
      await loadEvents();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to batch clear organizer binding.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <AdminContentLayout
      title="Event Organizer Binding Center"
      eyebrow="Admin / Content Workspace / Organizer Binding"
      description="Use one shared binding workflow to link events to canonical organizer records, both one by one and in batches."
      actions={
        <>
          <Link href="/admin/content/organizers" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            Back to Organizers
          </Link>
          <Link href="/admin/content/organizers/catalog" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            Organizer Catalog
          </Link>
          <Link href="/admin/content/events/catalog" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            Event Catalog
          </Link>
          <Link href="/admin/content/organizers/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            New Organizer
          </Link>
        </>
      }
    >
      <section className="grid gap-5 xl:grid-cols-[1.2fr_0.8fr]">
        <div className="admin-reference-card p-6">
          <div className="text-[11px] uppercase tracking-[0.18em] text-black/35">Binding Strategy</div>
          <h2 className="mt-2 text-2xl font-semibold text-[#071110]">Summary catalog + shared binding field</h2>
          <div className="mt-5 grid gap-3 md:grid-cols-3">
            {[
              'The left side stays lightweight and only loads event summaries.',
              'The right side handles canonical organizer selection and mutation.',
              'Single-event and batch-event flows now share the same organizer picker.',
            ].map((item) => (
              <div key={item} className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] px-4 py-3 text-sm leading-6 text-[#24312d]">
                {item}
              </div>
            ))}
          </div>
        </div>

        <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7efda_0%,#ffffff_100%)] p-6">
          <div className="text-[11px] uppercase tracking-[0.18em] text-black/35">Cache Status</div>
          <h2 className="mt-2 text-2xl font-semibold text-[#071110]">Summary layer status</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-black/52">
            <p>{cacheMessage}</p>
            <p>Page: {page} / {totalPages}</p>
            <p>Manageable events: {total.toLocaleString()}</p>
          </div>
        </div>
      </section>

      <section className="admin-reference-card p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <div className="text-sm text-black/42">Unbound Clusters</div>
            <h2 className="mt-2 text-2xl font-semibold text-[#071110]">Unbound event clusters</h2>
            <p className="mt-3 text-sm leading-6 text-black/48">
              Group unbound records by organizer text or event name keywords so operations can select and bind them in batches.
            </p>
          </div>
          <div className="admin-reference-soft-card px-4 py-3 text-sm text-black/48">
            Unbound events on this page: {items.filter((item) => !item.wikiFestivalId).length}
          </div>
        </div>

        <div className="mt-5 grid gap-4 lg:grid-cols-2 xl:grid-cols-3">
          {unboundClusters.length === 0 ? (
            <div className="admin-reference-soft-card px-4 py-6 text-sm text-black/48">
              No unbound events in the current page scope.
            </div>
          ) : (
            unboundClusters.map((cluster) => (
              <div key={cluster.label} className="admin-reference-soft-card p-4">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="text-sm font-semibold text-[#071110]">{cluster.label}</div>
                    <div className="mt-1 text-xs text-black/42">{cluster.rows.length} candidate events</div>
                  </div>
                  <button
                    type="button"
                    onClick={() => selectCluster(cluster.rows.map((item) => item.id))}
                    className="rounded-full border border-[#e8eceb] bg-white px-3 py-2 text-xs font-semibold text-[#071110]"
                  >
                    Select Cluster
                  </button>
                </div>

                <div className="mt-4 space-y-2">
                  {cluster.rows.slice(0, 4).map((row) => (
                    <button
                      key={row.id}
                      type="button"
                      onClick={() => setSelectedEventId(row.id)}
                      className="block w-full rounded-[20px] border border-[#e8eceb] bg-white px-3 py-3 text-left"
                    >
                      <div className="text-sm font-medium text-[#071110]">{row.name}</div>
                      <div className="mt-1 text-xs leading-5 text-black/48">
                        {row.city || 'Unknown city'} / {row.country || 'Unknown country'} · {formatDateRange(row.startDate, row.endDate)}
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            ))
          )}
        </div>
      </section>

      <section className="grid gap-5 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="admin-reference-card p-6">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
            <form onSubmit={handleSearchSubmit} className="grid flex-1 gap-3 md:grid-cols-[minmax(0,1.7fr)_220px_auto]">
              <label className="space-y-2">
                <span className="text-xs uppercase tracking-[0.2em] text-black/35">Search Events</span>
                <input
                  value={searchInput}
                  onChange={(event) => setSearchInput(event.target.value)}
                  placeholder="Event / city / organizer"
                  className="w-full rounded-full px-4 py-3 text-sm"
                />
              </label>
              <label className="space-y-2">
                <span className="text-xs uppercase tracking-[0.2em] text-black/35">Status</span>
                <select
                  value={status}
                  onChange={(event) => {
                    setStatus(event.target.value);
                    setPage(1);
                  }}
                  className="w-full rounded-full px-4 py-3 text-sm"
                >
                  <option value="all">All</option>
                  <option value="upcoming">Upcoming</option>
                  <option value="ongoing">Ongoing</option>
                  <option value="ended">Ended</option>
                  <option value="cancelled">Cancelled</option>
                </select>
              </label>
              <button type="submit" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
                Search
              </button>
            </form>
            <div className="flex flex-wrap gap-3">
              <button
                type="button"
                onClick={toggleSelectAllVisible}
                className="rounded-full border border-[#e8eceb] bg-white px-4 py-3 text-sm font-semibold text-[#071110]"
              >
                {allVisibleSelected ? 'Clear Page Selection' : 'Select Current Page'}
              </button>
              <div className="admin-reference-soft-card px-4 py-3 text-sm text-black/48">
                Selected: {selectedEventIds.length}
              </div>
            </div>
          </div>

          <div className="mt-5">
            {isLoading ? (
              <div className="py-20 text-center text-sm text-black/48">Loading event summaries...</div>
            ) : items.length === 0 ? (
              <div className="py-20 text-center text-sm text-black/48">No events match the current filter.</div>
            ) : (
              <div className="space-y-4">
                {items.map((item) => {
                  const selected = item.id === selectedEventId;
                  return (
                    <div
                      key={item.id}
                      className={`grid gap-4 rounded-[24px] border p-4 transition-colors lg:grid-cols-[32px_120px_minmax(0,1fr)] ${
                        selected ? 'border-[#dceabf] bg-[#edf7f2]' : 'border-[#e8eceb] bg-[#f8f9f8]'
                      }`}
                    >
                      <label className="flex items-start pt-1">
                        <input
                          type="checkbox"
                          checked={selectedEventIds.includes(item.id)}
                          onChange={() => toggleEventSelection(item.id)}
                          className="mt-1 h-4 w-4 rounded border-border-secondary bg-white"
                        />
                      </label>
                      <div className="relative overflow-hidden rounded-[20px] border border-[#e8eceb] bg-[#f5f5f7]">
                        {item.coverImageUrl ? (
                          <Image
                            src={item.coverImageUrl}
                            alt={item.name}
                            width={240}
                            height={180}
                            className="h-full min-h-[100px] w-full object-cover"
                          />
                        ) : (
                          <div className="flex h-full min-h-[100px] items-center justify-center bg-[linear-gradient(135deg,#f7efda,#edf7f2)] text-sm text-black/42">
                            No cover
                          </div>
                        )}
                      </div>

                      <button
                        type="button"
                        onClick={() => {
                          setSelectedEventId(item.id);
                          setSuccessMessage('');
                        }}
                        className="min-w-0 text-left"
                      >
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="admin-reference-chip">{item.eventType || 'Unlabeled type'}</span>
                          <span className="admin-reference-chip bg-[#f5f5f7] text-black/55">{item.status || 'unknown'}</span>
                          {item.wikiFestivalId ? (
                            <span className="rounded-full border border-[#dceabf] bg-[#eef8d8] px-3 py-1 text-xs font-semibold text-[#2f4027]">
                              Bound
                            </span>
                          ) : (
                            <span className="rounded-full border border-[#eadfbe] bg-[#f6edd7] px-3 py-1 text-xs font-semibold text-[#604a1b]">
                              Unbound
                            </span>
                          )}
                        </div>

                        <h3 className="mt-3 truncate text-xl font-semibold text-[#071110]">{item.name}</h3>
                        <p className="mt-2 text-sm leading-6 text-black/48">
                          {item.city || 'Unknown city'} / {item.country || 'Unknown country'} · {formatDateRange(item.startDate, item.endDate)}
                        </p>
                        <p className="mt-2 text-sm leading-6 text-black/48">
                          Current organizer: {item.wikiFestival?.name || item.organizerName || 'Not bound yet'}
                        </p>
                        <p className="mt-2 text-xs text-black/38">Updated: {formatDateTime(item.updatedAt)}</p>
                      </button>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          <div className="mt-6 flex items-center justify-between border-t border-white/5 pt-6">
            <div className="text-sm text-black/48">Total summaries: {total.toLocaleString()}</div>
            <div className="flex gap-3">
              <button
                type="button"
                disabled={page <= 1}
                onClick={() => setPage((current) => Math.max(1, current - 1))}
                className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
              >
                Previous
              </button>
              <button
                type="button"
                disabled={page >= totalPages}
                onClick={() => setPage((current) => Math.min(totalPages, current + 1))}
                className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
              >
                Next
              </button>
            </div>
          </div>
        </div>

        <div className="space-y-5">
          <section className="admin-reference-dark-card p-6">
            <div className="text-sm text-white/45">Binding Panel</div>
            <h2 className="mt-2 text-2xl font-semibold text-white">Current binding panel</h2>

            {selectedEvent ? (
              <div className="mt-5 space-y-4">
                <div className="rounded-[22px] border border-white/10 bg-white/8 p-4">
                  <div className="text-sm text-white/45">Current event</div>
                  <div className="mt-1 text-xl font-semibold text-white">{selectedEvent.name}</div>
                  <div className="mt-2 text-sm leading-6 text-white/62">
                    Current organizer: {selectedEvent.wikiFestival?.name || selectedEvent.organizerName || 'Not bound yet'}
                  </div>
                </div>

                <div className="[&_.admin-reference-soft-card]:border-white/10 [&_.admin-reference-soft-card]:bg-white/8 [&_.admin-reference-soft-card]:text-white [&_.text-black\\/38]:text-white/45 [&_.text-black\\/45]:text-white/60 [&_.text-black\\/48]:text-white/55 [&_.text-\\[\\#111827\\]]:text-white [&_.border-\\[\\#e8eceb\\]]:border-white/10 [&_.bg-white]:bg-white [&_.text-\\[\\#8b3a3a\\]]:text-\\[\\#8b3a3a\\]">
                  <EntityBindingField
                    kind="festival"
                    mode="single"
                    seedQuery={organizerSeedQuery}
                    items={selectedOrganizerBinding}
                    disabled={isSubmitting}
                    title="Target organizer"
                    emptyLabel="Search and choose one canonical organizer record."
                    onAdd={(value) => {
                      setSelectedOrganizer({
                        id: value.id,
                        name: value.name,
                        aliases: [],
                        country: '',
                        city: '',
                        tagline: value.subtitle || '',
                        avatarUrl: value.imageUrl || null,
                        backgroundUrl: value.imageUrl || null,
                      });
                      setSuccessMessage('');
                    }}
                    onRemove={() => {
                      setSelectedOrganizer(null);
                      setSuccessMessage('');
                    }}
                  />
                </div>

                <div className="grid gap-3 sm:grid-cols-2">
                  <button
                    type="button"
                    disabled={!selectedOrganizer || isSubmitting}
                    onClick={handleBind}
                    className="rounded-full bg-white px-5 py-3 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    Bind Selected Organizer
                  </button>
                  <button
                    type="button"
                    disabled={isSubmitting || !selectedEvent?.wikiFestivalId}
                    onClick={handleClear}
                    className="rounded-full border border-white/10 bg-white/8 px-5 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-40"
                  >
                    Clear Current Binding
                  </button>
                </div>

                <div className="rounded-[22px] border border-white/10 bg-white/8 p-4">
                  <div className="text-sm font-semibold text-white">Batch Actions</div>
                  <div className="mt-2 text-sm leading-6 text-white/58">
                    Selected events: {selectedEventIds.length}
                    {selectedEvents.length > 0 ? `, visible on this page: ${selectedEvents.length}` : ''}
                  </div>
                  <div className="mt-4 grid gap-3 sm:grid-cols-2">
                    <button
                      type="button"
                      disabled={!selectedOrganizer || selectedEventIds.length === 0 || isSubmitting}
                      onClick={handleBatchBind}
                      className="rounded-full bg-white px-5 py-3 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-50"
                    >
                      Batch Bind
                    </button>
                    <button
                      type="button"
                      disabled={selectedEventIds.length === 0 || isSubmitting}
                      onClick={handleBatchClear}
                      className="rounded-full border border-white/10 bg-white/8 px-5 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-40"
                    >
                      Batch Clear
                    </button>
                  </div>
                </div>
              </div>
            ) : (
              <div className="mt-5 text-sm text-white/55">Select an event from the left first.</div>
            )}
          </section>

          {error ? (
            <section className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] p-4 text-sm text-[#6a3530]">
              {error}
            </section>
          ) : null}

          {successMessage ? (
            <section className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-4 text-sm text-[#2f4027]">
              {successMessage}
            </section>
          ) : null}

          <section className="admin-reference-soft-card p-6">
            <div className="text-sm text-black/42">Migration Note</div>
            <h2 className="mt-2 text-2xl font-semibold text-[#071110]">Current scope</h2>
            <div className="mt-4 space-y-3 text-sm leading-6 text-black/48">
              <p>
                This page now uses the same shared binding field abstraction as rankings, genres, and ratings.
              </p>
              <p>
                The single-event and batch-event organizer flows remain intact; only the organizer selection layer was unified.
              </p>
            </div>
          </section>
        </div>
      </section>
    </AdminContentLayout>
  );
}
