'use client';

import { Link2, Plus, Trash2 } from 'lucide-react';
import AdminCountedControl from '@/components/admin/AdminCountedControl';
import EntityBindingSearch, {
  type EntityBindingKind,
  type EntityBindingValue,
} from '@/components/admin/EntityBindingSearch';
import { countText } from '@/lib/input-rules';

export type DynamicEntityNameListItem = {
  id: string;
  name: string;
  binding: EntityBindingValue | null;
};

type DynamicEntityNameListFieldProps = {
  label: string;
  items: DynamicEntityNameListItem[];
  placeholder: string;
  kind: EntityBindingKind;
  itemMax: number;
  maxItems: number;
  onChangeName: (index: number, value: string) => void;
  onAddManual: () => void;
  onAddBinding: (value: EntityBindingValue) => void;
  onRemove: (index: number) => void;
  hint?: string;
  error?: string;
  addManualLabel?: string;
  bindingTitle?: string;
  emptyLabel?: string;
  searchSeedQuery?: string;
};

const countEffectiveItems = (items: DynamicEntityNameListItem[]) =>
  items.filter((item) => item.name.trim() || item.binding).length;

export default function DynamicEntityNameListField({
  label,
  items,
  placeholder,
  kind,
  itemMax,
  maxItems,
  onChangeName,
  onAddManual,
  onAddBinding,
  onRemove,
  hint,
  error,
  addManualLabel = '添加未绑定项',
  bindingTitle = '搜索并添加绑定项',
  emptyLabel = '当前还没有添加任何条目。',
  searchSeedQuery = '',
}: DynamicEntityNameListFieldProps) {
  const combinedHint = [hint, `已填写 ${countEffectiveItems(items)}/${maxItems} 项`]
    .filter(Boolean)
    .join(' ');
  const reachedLimit = items.length >= maxItems;

  return (
    <label className="block">
      <div className="mb-2 admin-studio-label">{label}</div>
      <div className="space-y-3">
        {items.length ? (
          items.map((item, index) => (
            <div key={item.id} className="admin-reference-soft-card space-y-3 p-3">
              <div className="flex items-start gap-2">
                <div className="min-w-0 flex-1">
                  <AdminCountedControl count={countText(item.name)} maxLength={itemMax}>
                    <input
                      value={item.name}
                      onChange={(event) => onChangeName(index, event.target.value)}
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
              <div className="rounded-[16px] border border-[#e8eceb] bg-white px-3 py-3 text-sm text-[#111827]">
                {item.binding ? (
                  <div className="space-y-1">
                    <div className="inline-flex items-center gap-2 rounded-full bg-[#f2f8f4] px-3 py-1 text-xs font-semibold text-[#234536]">
                      <Link2 className="h-3.5 w-3.5" />
                      已绑定：{item.binding.name}
                    </div>
                    {item.binding.subtitle ? (
                      <div className="text-xs text-black/45">{item.binding.subtitle}</div>
                    ) : null}
                  </div>
                ) : (
                  <div className="text-xs text-black/45">未绑定，仅展示此名称，iOS 端不可点击。</div>
                )}
              </div>
            </div>
          ))
        ) : (
          <div className="rounded-[16px] border border-dashed border-[#d7ded9] px-4 py-4 text-sm text-black/48">
            {emptyLabel}
          </div>
        )}

        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={onAddManual}
            disabled={reachedLimit}
            className="inline-flex items-center gap-2 rounded-full border border-[#d9e7dd] bg-[#f6fbf7] px-4 py-2 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-60"
          >
            <Plus className="h-4 w-4" />
            {addManualLabel}
          </button>
        </div>

        <div className="admin-reference-soft-card p-3">
          <div className="mb-3 text-xs uppercase tracking-[0.14em] text-black/38">{bindingTitle}</div>
          <EntityBindingSearch
            kind={kind}
            seedQuery={searchSeedQuery}
            disabled={reachedLimit}
            showCurrentCard={false}
            onBind={onAddBinding}
          />
        </div>
      </div>
      {combinedHint ? <div className="mt-2 text-xs text-black/40">{combinedHint}</div> : null}
      {error ? <div className="mt-2 text-xs text-[#6a3530]">{error}</div> : null}
    </label>
  );
}
