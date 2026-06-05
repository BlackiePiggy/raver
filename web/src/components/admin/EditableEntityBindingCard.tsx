'use client';

import { Pencil, Trash2 } from 'lucide-react';
import { useMemo, useState, type ReactNode } from 'react';
import AdminCountedControl from '@/components/admin/AdminCountedControl';
import EntityBindingField from '@/components/admin/EntityBindingField';
import type { EntityBindingKind, EntityBindingValue } from '@/components/admin/EntityBindingSearch';
import { countText } from '@/lib/input-rules';

type EditableEntityBindingCardProps = {
  header: ReactNode;
  badge?: ReactNode;
  name: string;
  nameValue: string;
  namePlaceholder: string;
  nameMaxLength?: number;
  bindingKind: EntityBindingKind;
  binding: EntityBindingValue | null;
  seedQuery?: string;
  bindingTitle?: string;
  bindingEmptyLabel?: string;
  confirmedMeta?: ReactNode;
  boundLabel?: string;
  unboundLabel?: string;
  isEditing?: boolean;
  defaultEditing?: boolean;
  onNameChange: (value: string) => void;
  onAddBinding: (value: EntityBindingValue) => void;
  onRemoveBinding: () => void;
  onConfirm?: () => void;
  onEditStart?: () => void;
  onEditCancel?: () => void;
  onDelete?: () => void;
};

const BOUND_BADGE_CLASS = 'bg-[#edf7f2] text-[#31513d]';
const UNBOUND_BADGE_CLASS = 'bg-[#f7efda] text-[#7a5a25]';

export default function EditableEntityBindingCard({
  header,
  badge,
  name,
  nameValue,
  namePlaceholder,
  nameMaxLength,
  bindingKind,
  binding,
  seedQuery = '',
  bindingTitle = '绑定库内对象',
  bindingEmptyLabel = '当前还没有绑定到库内对象。',
  confirmedMeta = null,
  boundLabel = '已绑定',
  unboundLabel = '未绑定',
  isEditing,
  defaultEditing = false,
  onNameChange,
  onAddBinding,
  onRemoveBinding,
  onConfirm,
  onEditStart,
  onEditCancel,
  onDelete,
}: EditableEntityBindingCardProps) {
  const [localEditing, setLocalEditing] = useState(defaultEditing);
  const editing = isEditing ?? localEditing;
  const bindingItems = useMemo(() => (binding ? [binding] : []), [binding]);
  const isBound = Boolean(binding);

  const openEditor = () => {
    onEditStart?.();
    if (isEditing === undefined) setLocalEditing(true);
  };

  const cancelEditor = () => {
    onEditCancel?.();
    if (isEditing === undefined) setLocalEditing(false);
  };

  const confirmEditor = () => {
    onConfirm?.();
    if (isEditing === undefined) setLocalEditing(false);
  };

  return (
    <div className="rounded-[18px] border border-[#e8eceb] bg-white p-4">
      {!editing ? (
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              {badge}
              <span className="text-base font-semibold text-[#111827]">{name || '未命名对象'}</span>
              <span className={`rounded-full px-2.5 py-1 text-xs ${isBound ? BOUND_BADGE_CLASS : UNBOUND_BADGE_CLASS}`}>
                {isBound ? boundLabel : unboundLabel}
              </span>
            </div>
            <div className="mt-2 text-sm font-medium text-[#111827]">{header}</div>
            {confirmedMeta ? <div className="mt-2 text-sm text-black/55">{confirmedMeta}</div> : null}
            <div className="mt-2 text-sm text-black/55">
              {binding
                ? `绑定对象：${binding.name}${binding.subtitle ? ` · ${binding.subtitle}` : ''}`
                : bindingEmptyLabel}
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={openEditor}
              className="inline-flex items-center gap-2 rounded-full border border-[#d7ded9] bg-white px-4 py-2 text-sm text-[#18211f]"
            >
              <Pencil className="h-4 w-4" />
              编辑
            </button>
            {onDelete ? (
              <button
                type="button"
                onClick={onDelete}
                className="inline-flex items-center gap-2 rounded-full border border-[#ead6d6] bg-white px-4 py-2 text-sm text-[#8b3a3a]"
              >
                <Trash2 className="h-4 w-4" />
                删除
              </button>
            ) : null}
          </div>
        </div>
      ) : (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="text-sm font-semibold text-[#111827]">{header}</div>
            {badge}
          </div>

          {typeof nameMaxLength === 'number' ? (
            <AdminCountedControl count={countText(nameValue)} maxLength={nameMaxLength}>
              <input
                className="w-full rounded-[16px] border border-[#e8eceb] bg-white px-3 py-3 text-sm"
                placeholder={namePlaceholder}
                value={nameValue}
                onChange={(event) => onNameChange(event.target.value)}
                maxLength={nameMaxLength}
              />
            </AdminCountedControl>
          ) : (
            <input
              className="w-full rounded-[16px] border border-[#e8eceb] bg-white px-3 py-3 text-sm"
              placeholder={namePlaceholder}
              value={nameValue}
              onChange={(event) => onNameChange(event.target.value)}
            />
          )}

          <EntityBindingField
            kind={bindingKind}
            mode="single"
            seedQuery={seedQuery}
            items={bindingItems}
            title={bindingTitle}
            emptyLabel={bindingEmptyLabel}
            onAdd={onAddBinding}
            onRemove={onRemoveBinding}
          />

          <div className="flex flex-wrap justify-end gap-2">
            <button
              type="button"
              onClick={cancelEditor}
              className="rounded-full border border-[#e7ebef] bg-white px-4 py-2 text-sm font-semibold text-[#111827]"
            >
              收起
            </button>
            <button
              type="button"
              onClick={confirmEditor}
              className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white"
            >
              确认
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
