'use client';

import clsx from 'clsx';
import { Search, X } from 'lucide-react';

type AdminSearchFieldSize = 'sm' | 'md' | 'lg';

type AdminSearchFieldProps = {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  size?: AdminSearchFieldSize;
  className?: string;
  inputClassName?: string;
  submitLabel?: string;
  onSubmit?: () => void;
  submitButtonType?: 'button' | 'submit';
  onClear?: () => void;
  disabled?: boolean;
  ariaLabel?: string;
};

const SIZE_STYLES: Record<
  AdminSearchFieldSize,
  {
    shell: string;
    icon: string;
    input: string;
    button: string;
    clear: string;
  }
> = {
  sm: {
    shell: 'h-[44px] gap-3 px-4',
    icon: 'h-4 w-4',
    input: 'text-[14px]',
    button: 'h-[32px] px-4 text-sm',
    clear: 'h-8 w-8',
  },
  md: {
    shell: 'h-[48px] gap-3 px-4.5',
    icon: 'h-4.5 w-4.5',
    input: 'text-[14px]',
    button: 'h-[34px] px-4 text-sm',
    clear: 'h-8 w-8',
  },
  lg: {
    shell: 'h-[54px] gap-3 px-5',
    icon: 'h-5 w-5',
    input: 'text-[15px]',
    button: 'h-[38px] px-4.5 text-sm',
    clear: 'h-9 w-9',
  },
};

export default function AdminSearchField({
  value,
  onChange,
  placeholder = 'Search',
  size = 'md',
  className,
  inputClassName,
  submitLabel,
  onSubmit,
  submitButtonType = 'button',
  onClear,
  disabled = false,
  ariaLabel,
}: AdminSearchFieldProps) {
  const styles = SIZE_STYLES[size];
  const canClear = Boolean(value.trim()) && Boolean(onClear);
  const canSubmit = Boolean(onSubmit && submitLabel);

  return (
    <div
      className={clsx(
        'admin-search-field-shell flex min-w-0 items-center rounded-full border border-[#e8eceb] bg-white text-[#111827] shadow-[0_1px_0_rgba(255,255,255,0.7)_inset]',
        styles.shell,
        disabled && 'opacity-60',
        className
      )}
    >
      <Search className={clsx('shrink-0 text-[#9aa1ad]', styles.icon)} />
      <input
        type="text"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        disabled={disabled}
        aria-label={ariaLabel || placeholder}
        className={clsx(
          'admin-search-field-input min-w-0 flex-1 appearance-none border-0 bg-transparent px-0 py-0 font-medium text-[#111827] outline-none ring-0 shadow-none placeholder:text-[#9aa1ad]',
          styles.input,
          inputClassName
        )}
      />
      {canClear ? (
        <button
          type="button"
          onClick={onClear}
          disabled={disabled}
          className={clsx(
            'inline-flex shrink-0 items-center justify-center rounded-full border border-[#edf0f2] bg-[#f7f8fa] text-[#7d8592] transition hover:bg-[#eef1f4]',
            styles.clear
          )}
          aria-label="Clear search"
        >
          <X className="h-4 w-4" />
        </button>
      ) : null}
      {canSubmit ? (
        <button
          type={submitButtonType}
          onClick={submitButtonType === 'button' ? onSubmit : undefined}
          disabled={disabled}
          className={clsx(
            'inline-flex shrink-0 items-center justify-center rounded-full bg-[#071110] font-semibold text-white transition hover:bg-[#14211f]',
            styles.button
          )}
        >
          {submitLabel}
        </button>
      ) : null}
    </div>
  );
}
