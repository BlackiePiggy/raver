'use client';

import { Languages, X } from 'lucide-react';
import { countText } from '@/lib/input-rules';

export type LocalizedLocaleKey = 'zh' | 'en' | 'ja' | 'enFull';
export type LocalizedFieldKind = 'input' | 'textarea';

export type LocalizedTextValue = {
  zh: string;
  en: string;
  ja: string;
  enFull: string;
};

export const LOCALIZED_LOCALE_ITEMS: Array<{
  key: LocalizedLocaleKey;
  label: string;
  hint: string;
}> = [
  { key: 'zh', label: '中文', hint: '用于中文展示与检索回填。' },
  { key: 'en', label: '英文', hint: '用于英文展示与国际化回退。' },
  { key: 'ja', label: '日本語', hint: '用于日文展示。' },
  { key: 'enFull', label: '英文全称', hint: '可选，用于更完整的英文全称或地址。' },
];

export const localizedTextFilledLocaleLabels = (value: LocalizedTextValue): string[] =>
  LOCALIZED_LOCALE_ITEMS.filter((item) => value[item.key].trim()).map((item) => item.label);

export function LocalizedTextField({
  label,
  value,
  kind,
  placeholder,
  error,
  hint,
  maxLength,
  onPrimaryChange,
  onOpenOverlay,
}: {
  label: string;
  value: LocalizedTextValue;
  kind: LocalizedFieldKind;
  placeholder: string;
  error?: string;
  hint?: string;
  maxLength?: number;
  onPrimaryChange: (value: string) => void;
  onOpenOverlay: () => void;
}) {
  const filledLocales = localizedTextFilledLocaleLabels(value);
  const extraLocales = filledLocales.filter((item) => item !== '中文');
  const primaryCount = countText(value.zh, kind === 'textarea');
  const combinedHint = [
    hint,
    typeof maxLength === 'number' ? `${primaryCount}/${maxLength}` : null,
    extraLocales.length ? `已填写：${extraLocales.join(' / ')}` : '点击右侧按钮展开编辑英文、日文等多语言内容。',
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <label className="block">
      <div className="mb-2 admin-studio-label">{label}</div>
      <div className={`admin-localized-field-shell ${kind === 'textarea' ? 'is-textarea' : ''}`}>
        {kind === 'textarea' ? (
          <textarea
            value={value.zh}
            onChange={(event) => onPrimaryChange(event.target.value)}
            className="admin-studio-textarea min-h-28"
            placeholder={placeholder}
            maxLength={maxLength}
          />
        ) : (
          <input
            value={value.zh}
            onChange={(event) => onPrimaryChange(event.target.value)}
            className="admin-studio-input"
            placeholder={placeholder}
            maxLength={maxLength}
          />
        )}
        <button
          type="button"
          onClick={onOpenOverlay}
          className={`admin-localized-field-trigger ${kind === 'textarea' ? 'is-textarea' : ''}`}
          aria-label={`${label}多语言编辑`}
          title={`${label}多语言编辑`}
        >
          <Languages className="h-4 w-4" strokeWidth={2.2} />
          {extraLocales.length ? <span className="admin-localized-field-trigger-dot" /> : null}
        </button>
      </div>
      {combinedHint ? <div className="mt-2 text-xs text-black/40">{combinedHint}</div> : null}
      {error ? <div className="mt-2 text-xs text-[#6a3530]">{error}</div> : null}
    </label>
  );
}

export function MultilingualEditorOverlay({
  open,
  title,
  kind,
  value,
  onChange,
  onClose,
  onClear,
  maxLength,
  clearLabel = '清除该字段多语言',
  description = '主输入默认使用中文，这里统一补充英文、日文和其他语言版本。',
}: {
  open: boolean;
  title: string;
  kind: LocalizedFieldKind;
  value: LocalizedTextValue;
  onChange: (locale: LocalizedLocaleKey, value: string) => void;
  onClose: () => void;
  onClear?: () => void;
  maxLength?: number;
  clearLabel?: string;
  description?: string;
}) {
  if (!open) return null;

  return (
    <div className="admin-localized-overlay" onClick={onClose}>
      <div className="admin-localized-overlay-card" onClick={(event) => event.stopPropagation()}>
        <div className="flex items-start justify-between gap-4">
          <div>
            <div className="admin-studio-label">多语言编辑</div>
            <div className="mt-2 text-[24px] font-semibold tracking-[-0.04em] text-[#071110]">{title}</div>
            <div className="mt-2 text-sm leading-6 text-black/48">{description}</div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="admin-localized-overlay-close"
            aria-label="关闭多语言编辑器"
          >
            <X className="h-4 w-4" strokeWidth={2.2} />
          </button>
        </div>

        <div className="mt-5 grid gap-4">
          {LOCALIZED_LOCALE_ITEMS.map((item) => (
            <label key={`${title}-${item.key}`} className="block">
              <div className="mb-2 admin-studio-label">{item.label}</div>
              {kind === 'textarea' ? (
                <textarea
                  value={value[item.key]}
                  onChange={(event) => onChange(item.key, event.target.value)}
                  className="admin-studio-textarea min-h-28"
                  placeholder={`${title}${item.label}`}
                  maxLength={maxLength}
                />
              ) : (
                <input
                  value={value[item.key]}
                  onChange={(event) => onChange(item.key, event.target.value)}
                  className="admin-studio-input"
                  placeholder={`${title}${item.label}`}
                  maxLength={maxLength}
                />
              )}
              <div className="mt-2 text-xs text-black/40">
                {item.hint}
                {typeof maxLength === 'number' ? ` ${countText(value[item.key], kind === 'textarea')}/${maxLength}` : ''}
              </div>
            </label>
          ))}
        </div>

        <div className="mt-6 flex flex-wrap items-center justify-between gap-3">
          <div className="text-xs text-black/40">
            已填写语言：{localizedTextFilledLocaleLabels(value).join(' / ') || '暂无'}
          </div>
          <div className="flex flex-wrap gap-3">
            {onClear ? (
              <button type="button" onClick={onClear} className="admin-studio-button-secondary px-4 py-2 text-sm">
                {clearLabel}
              </button>
            ) : null}
            <button type="button" onClick={onClose} className="admin-studio-button-primary px-5 py-3 text-sm">
              完成
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
