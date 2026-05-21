'use client';

import { useState } from 'react';
import { eventAPI, EventTimezoneLookupItem } from '@/lib/api/event';
import { getTimeZoneLabel } from '@/lib/timezone';

interface EventTimezonePickerProps {
  token?: string | null;
  query: string;
  onQueryChange: (value: string) => void;
  selection: EventTimezoneLookupItem | null;
  onSelectionChange: (value: EventTimezoneLookupItem | null) => void;
  onAutoFillLocation?: (item: EventTimezoneLookupItem) => void;
}

export default function EventTimezonePicker({
  token,
  query,
  onQueryChange,
  selection,
  onSelectionChange,
  onAutoFillLocation,
}: EventTimezonePickerProps) {
  const [items, setItems] = useState<EventTimezoneLookupItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSearch = async () => {
    const trimmed = query.trim();
    if (!trimmed) {
      setError('请先输入城市或城市+州/国家');
      setItems([]);
      return;
    }
    setLoading(true);
    setError('');
    try {
      const results = await eventAPI.searchEventTimezones(trimmed, token || undefined);
      setItems(results);
      if (!results.length) {
        setError('没有匹配结果，请尝试城市英文名、州缩写或国家名');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : '搜索城市时区失败');
      setItems([]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="md:col-span-2 rounded-xl border border-bg-primary bg-bg-tertiary/40 p-4">
      <label className="block text-sm text-text-secondary mb-2">活动时区</label>
      <div className="flex flex-col md:flex-row gap-2">
        <input
          value={query}
          onChange={(e) => {
            onQueryChange(e.target.value);
            if (selection && e.target.value.trim() !== (selection.cityAscii || selection.city)) {
              onSelectionChange(null);
            }
          }}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault();
              void handleSearch();
            }
          }}
          className="flex-1 bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary"
          placeholder="输入城市或城市+州/国家，如 Chicago / Springfield MO / Amsterdam NL"
        />
        <div className="flex gap-2">
          <button
            type="button"
            onClick={() => void handleSearch()}
            className="px-3 py-2 rounded-lg border border-bg-primary text-text-primary hover:border-primary-blue"
            disabled={loading}
          >
            {loading ? '搜索中...' : '搜索城市时区'}
          </button>
          <button
            type="button"
            onClick={() => {
              onSelectionChange(null);
              onQueryChange('');
              setItems([]);
              setError('');
            }}
            className="px-3 py-2 rounded-lg border border-bg-primary text-text-secondary hover:text-text-primary"
          >
            清空
          </button>
        </div>
      </div>

      <div className={`mt-3 rounded-lg border px-3 py-2 text-sm ${selection ? 'border-primary-blue/40 bg-primary-blue/10 text-primary-blue' : 'border-bg-primary bg-bg-primary/30 text-text-tertiary'}`}>
        {selection
          ? `${selection.label} (${getTimeZoneLabel(selection.timezone)})`
          : '未确认活动城市时区。保存前必须从候选列表中明确选择。'}
      </div>

      {error ? <p className="mt-2 text-xs text-accent-red">{error}</p> : null}

      {items.length ? (
        <div className="mt-3 flex flex-col gap-2">
          {items.map((item) => (
            <button
              key={`${item.city}-${item.exactProvince}-${item.country}-${item.timezone}`}
              type="button"
              onClick={() => {
                onSelectionChange(item);
                onQueryChange(item.cityAscii || item.city);
                onAutoFillLocation?.(item);
                setItems([]);
                setError('');
              }}
              className="rounded-lg border border-bg-primary bg-bg-primary/30 px-3 py-2 text-left text-sm text-text-primary hover:border-primary-blue"
            >
              {item.label}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}
