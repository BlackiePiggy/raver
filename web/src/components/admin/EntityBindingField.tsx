'use client';

import { Trash2 } from 'lucide-react';
import EntityBindingSearch, {
  type EntityBindingKind,
  type EntityBindingValue,
} from '@/components/admin/EntityBindingSearch';

type EntityBindingFieldProps = {
  kind: EntityBindingKind;
  mode: 'single' | 'multiple';
  items: EntityBindingValue[];
  seedQuery?: string;
  disabled?: boolean;
  title?: string;
  emptyLabel?: string;
  onAdd: (value: EntityBindingValue) => Promise<void> | void;
  onRemove: (value: EntityBindingValue) => Promise<void> | void;
};

export default function EntityBindingField({
  kind,
  mode,
  items,
  seedQuery = '',
  disabled = false,
  title = 'Bound objects',
  emptyLabel = 'No bound objects yet.',
  onAdd,
  onRemove,
}: EntityBindingFieldProps) {
  return (
    <div className="space-y-3">
      <div className="admin-reference-soft-card p-3">
        <div className="text-xs uppercase tracking-[0.14em] text-black/38">{title}</div>
        {items.length ? (
          <div className="mt-3 space-y-2">
            {items.map((item) => (
              <div
                key={item.id}
                className="flex items-center justify-between gap-3 rounded-[16px] border border-[#e8eceb] bg-white px-3 py-3"
              >
                <div className="min-w-0">
                  <div className="truncate text-sm font-medium text-[#111827]">{item.name}</div>
                  {item.subtitle ? <div className="mt-1 truncate text-xs text-black/45">{item.subtitle}</div> : null}
                </div>
                <button
                  type="button"
                  className="rounded-full border border-[#ead6d6] bg-white p-2 text-[#8b3a3a]"
                  disabled={disabled}
                  onClick={() => void onRemove(item)}
                  aria-label={`Remove ${item.name}`}
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            ))}
          </div>
        ) : (
          <div className="mt-3 rounded-[16px] border border-dashed border-[#d7ded9] px-4 py-4 text-sm text-black/48">
            {emptyLabel}
          </div>
        )}
      </div>

      <EntityBindingSearch
        kind={kind}
        seedQuery={seedQuery}
        disabled={disabled}
        showCurrentCard={false}
        onBind={(value) => onAdd(value)}
      />

      {mode === 'single' && items.length > 0 ? (
        <div className="text-xs text-black/45">Selecting a new result will replace the current binding.</div>
      ) : null}
    </div>
  );
}
