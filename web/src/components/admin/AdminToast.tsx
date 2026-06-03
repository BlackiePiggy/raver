'use client';

import { useEffect } from 'react';
import { CheckCircle2, AlertCircle, AlertTriangle, Info, X } from 'lucide-react';

export type AdminToastTone = 'success' | 'error' | 'warning' | 'neutral';

type AdminToastProps = {
  message: string | null;
  tone?: AdminToastTone;
  visible: boolean;
  onClose?: () => void;
  durationMs?: number;
  className?: string;
};

const TONE_STYLES: Record<
  AdminToastTone,
  {
    panel: string;
    icon: typeof CheckCircle2;
    iconClassName: string;
  }
> = {
  success: {
    panel: 'border-[#d8e5dc] bg-[#f5fbf6] text-[#2f5d43] shadow-[0_18px_36px_rgba(47,93,67,0.12)]',
    icon: CheckCircle2,
    iconClassName: 'text-[#2f5d43]',
  },
  error: {
    panel: 'border-[#f0d7d5] bg-[#fff7f6] text-[#8b3a3a] shadow-[0_18px_36px_rgba(139,58,58,0.12)]',
    icon: AlertCircle,
    iconClassName: 'text-[#8b3a3a]',
  },
  warning: {
    panel: 'border-[#eadfbe] bg-[#fffaf0] text-[#7a5a16] shadow-[0_18px_36px_rgba(122,90,22,0.12)]',
    icon: AlertTriangle,
    iconClassName: 'text-[#7a5a16]',
  },
  neutral: {
    panel: 'border-[#dbe3e0] bg-white text-[#31413d] shadow-[0_18px_36px_rgba(7,17,16,0.12)]',
    icon: Info,
    iconClassName: 'text-[#31413d]',
  },
};

export default function AdminToast({
  message,
  tone = 'neutral',
  visible,
  onClose,
  durationMs = 2200,
  className,
}: AdminToastProps) {
  useEffect(() => {
    if (!visible || !message || !onClose || durationMs <= 0) return undefined;
    const timer = window.setTimeout(() => {
      onClose();
    }, durationMs);
    return () => window.clearTimeout(timer);
  }, [durationMs, message, onClose, visible]);

  const toneStyle = TONE_STYLES[tone];
  const Icon = toneStyle.icon;

  return (
    <div className="pointer-events-none fixed inset-x-0 top-5 z-[140] flex justify-center px-4">
      <div
        className={`pointer-events-auto flex min-h-[52px] w-full max-w-[440px] items-start gap-3 rounded-[20px] border px-4 py-3 transition-all duration-200 ${
          toneStyle.panel
        } ${visible && message ? 'translate-y-0 opacity-100' : '-translate-y-2 opacity-0'} ${className || ''}`}
        role="status"
        aria-live="polite"
      >
        <Icon className={`mt-0.5 h-4 w-4 shrink-0 ${toneStyle.iconClassName}`} />
        <div className="min-w-0 flex-1 text-sm leading-6">{message || ''}</div>
        {onClose ? (
          <button
            type="button"
            onClick={onClose}
            className="inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-full border border-current/10 bg-white/50 text-current transition hover:bg-white/75"
            aria-label="Close toast"
          >
            <X className="h-3.5 w-3.5" />
          </button>
        ) : null}
      </div>
    </div>
  );
}
