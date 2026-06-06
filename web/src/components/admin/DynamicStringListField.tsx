'use client';

import { Plus, Trash2 } from 'lucide-react';
import AdminCountedControl from '@/components/admin/AdminCountedControl';
import { countText } from '@/lib/input-rules';

const countFilledItems = (items: string[]) => items.map((item) => String(item || '').trim()).filter(Boolean).length;

type DynamicStringListFieldProps = {
  label: string;
  items: string[];
  placeholder: string;
  onChange: (index: number, value: string) => void;
  onAdd: () => void;
  onRemove: (index: number) => void;
  hint?: string;
  itemMax: number;
  maxItems: number;
  error?: string;
  addLabel?: string;
};

export default function DynamicStringListField({
  label,
  items,
  placeholder,
  onChange,
  onAdd,
  onRemove,
  hint,
  itemMax,
  maxItems,
  error,
  addLabel = '添加一行',
}: DynamicStringListFieldProps) {
  const combinedHint = [hint, `已填写 ${countFilledItems(items)}/${maxItems} 项`]
    .filter(Boolean)
    .join(' ');

  return (
    <label className="block">
      <div className="mb-2 admin-studio-label">{label}</div>
      <div className="space-y-3">
        {items.map((item, index) => (
          <div key={`${label}-${index}`} className="flex items-start gap-2">
            <div className="min-w-0 flex-1">
              <AdminCountedControl count={countText(item)} maxLength={itemMax}>
                <input
                  value={item}
                  onChange={(event) => onChange(index, event.target.value)}
                  className="admin-studio-input"
                  placeholder={placeholder}
                  maxLength={itemMax}
                />
              </AdminCountedControl>
            </div>
            <button
              type="button"
              onClick={() => onRemove(index)}
              className="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-black/48 hover:text-[#071110]"
              aria-label={`删除${label}${index + 1}`}
            >
              <Trash2 className="h-4 w-4" />
            </button>
          </div>
        ))}
        <button
          type="button"
          onClick={onAdd}
          disabled={items.length >= maxItems}
          className="inline-flex items-center gap-2 rounded-full border border-[#d9e7dd] bg-[#f6fbf7] px-4 py-2 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-60"
        >
          <Plus className="h-4 w-4" />
          {addLabel}
        </button>
      </div>
      {combinedHint ? <div className="mt-2 text-xs text-black/40">{combinedHint}</div> : null}
      {error ? <div className="mt-2 text-xs text-[#6a3530]">{error}</div> : null}
    </label>
  );
}
