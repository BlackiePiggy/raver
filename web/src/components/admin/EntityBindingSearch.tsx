'use client';

import { useEffect, useMemo, useState } from 'react';
import { eventStudioApi } from '@/features/admin-content/event-studio/api';

export type EntityBindingKind = 'dj' | 'festival';

export type EntityBindingValue = {
  id: string;
  name: string;
  subtitle?: string | null;
  imageUrl?: string | null;
};

type EntityBindingSearchProps = {
  kind: EntityBindingKind;
  seedQuery?: string;
  current?: EntityBindingValue | null;
  disabled?: boolean;
  showCurrentCard?: boolean;
  onBind: (value: EntityBindingValue) => Promise<void> | void;
  onClear?: () => Promise<void> | void;
};

type SearchResultItem = EntityBindingValue & {
  note?: string | null;
};

const normalizeText = (value: string): string => value.trim().toLowerCase();

export default function EntityBindingSearch({
  kind,
  seedQuery = '',
  current = null,
  disabled = false,
  showCurrentCard = true,
  onBind,
  onClear,
}: EntityBindingSearchProps) {
  const [query, setQuery] = useState(seedQuery);
  const [results, setResults] = useState<SearchResultItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    setQuery(seedQuery);
  }, [seedQuery]);

  const effectiveQuery = useMemo(() => query.trim() || seedQuery.trim(), [query, seedQuery]);

  const mapResults = async (keyword: string): Promise<SearchResultItem[]> => {
    if (kind === 'festival') {
      const items = await eventStudioApi.searchOrganizers(keyword);
      return items.map((item) => ({
        id: item.id,
        name: item.name,
        subtitle: [item.city, item.country].filter(Boolean).join(', ') || null,
        imageUrl: item.avatarUrl || item.backgroundUrl || null,
        note: item.tagline || null,
      }));
    }

    const exactMatches = await eventStudioApi.matchExactDJs([keyword]);
    const exact = exactMatches
      .filter(
        (item) =>
          normalizeText(item.query) === normalizeText(keyword) ||
          normalizeText(item.name) === normalizeText(keyword)
      )
      .map((item) => ({
        id: item.djId,
        name: item.name,
        subtitle: item.aliases?.length ? item.aliases.join(' / ') : null,
        imageUrl: item.avatarUrl || item.avatarMediumUrl || item.avatarSmallUrl || null,
        note: 'Exact match',
      }));

    const loose = await eventStudioApi.searchDJs(keyword);
    const merged = new Map<string, SearchResultItem>();

    for (const item of exact) {
      merged.set(item.id, item);
    }
    for (const item of loose) {
      if (!item.id) continue;
      if (!merged.has(item.id)) {
        merged.set(item.id, {
          id: item.id,
          name: item.name,
          subtitle: item.country || item.slug || null,
          imageUrl: item.avatarUrl || item.avatarMediumUrl || item.avatarSmallUrl || null,
          note: item.slug || null,
        });
      }
    }

    return Array.from(merged.values());
  };

  const runSearch = async (keyword: string) => {
    const trimmed = keyword.trim();
    if (!trimmed) {
      setResults([]);
      setError('');
      return;
    }

    setLoading(true);
    setError('');
    try {
      const items = await mapResults(trimmed);
      setResults(items);
      if (!items.length) {
        setError('No matching library entities were found.');
      }
    } catch (searchError) {
      setResults([]);
      setError(searchError instanceof Error ? searchError.message : 'Search failed.');
    } finally {
      setLoading(false);
    }
  };

  const handleBind = async (item: EntityBindingValue) => {
    setSubmitting(true);
    setError('');
    try {
      await onBind(item);
      setResults([]);
    } catch (bindError) {
      setError(bindError instanceof Error ? bindError.message : 'Binding failed.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleClear = async () => {
    if (!onClear) return;
    setSubmitting(true);
    setError('');
    try {
      await onClear();
    } catch (clearError) {
      setError(clearError instanceof Error ? clearError.message : 'Clearing binding failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-3">
      <div className="admin-reference-soft-card space-y-3 p-3">
        {showCurrentCard ? (
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <div className="text-xs uppercase tracking-[0.14em] text-black/38">Binding</div>
              <div className="mt-1 text-sm font-medium text-[#111827]">
                {current ? current.name : 'No library entity bound'}
              </div>
              {current?.subtitle ? <div className="mt-1 text-xs text-black/45">{current.subtitle}</div> : null}
            </div>
            {current && onClear ? (
              <button
                type="button"
                className="rounded-full border border-[#e4d8d8] bg-white px-3 py-1.5 text-xs text-[#8b3a3a]"
                disabled={disabled || submitting}
                onClick={() => void handleClear()}
              >
                Clear binding
              </button>
            ) : null}
          </div>
        ) : null}

        <div className="flex flex-wrap gap-2">
          <input
            className="min-w-[180px] flex-1 rounded-[14px] border border-[#e8eceb] bg-white px-3 py-2 text-sm"
            placeholder={kind === 'festival' ? 'Search organizer / festival brand' : 'Search DJ'}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            disabled={disabled || submitting}
          />
          <button
            type="button"
            className="rounded-full border border-[#d7ded9] bg-white px-4 py-2 text-sm text-[#18211f]"
            disabled={disabled || submitting || loading}
            onClick={() => void runSearch(effectiveQuery)}
          >
            {loading ? 'Searching...' : 'Search'}
          </button>
          {seedQuery.trim() ? (
            <button
              type="button"
              className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white"
              disabled={disabled || submitting || loading}
              onClick={() => void runSearch(seedQuery)}
            >
              Quick match
            </button>
          ) : null}
        </div>
      </div>

      {error ? (
        <div className="rounded-[16px] border border-[#f0d7d5] bg-[#fff7f6] px-3 py-2 text-xs text-[#8b3a3a]">
          {error}
        </div>
      ) : null}

      {results.length ? (
        <div className="space-y-2">
          {results.map((item) => (
            <div
              key={item.id}
              className="admin-reference-soft-card flex items-center justify-between gap-3 px-3 py-3"
            >
              <div className="min-w-0">
                <div className="truncate text-sm font-medium text-[#111827]">{item.name}</div>
                {item.subtitle ? <div className="mt-1 truncate text-xs text-black/45">{item.subtitle}</div> : null}
                {item.note ? <div className="mt-1 truncate text-xs text-black/35">{item.note}</div> : null}
              </div>
              <button
                type="button"
                className="rounded-full bg-[#071110] px-3 py-1.5 text-xs font-semibold text-white"
                disabled={disabled || submitting}
                onClick={() => void handleBind(item)}
              >
                Bind
              </button>
            </div>
          ))}
        </div>
      ) : null}
    </div>
  );
}
