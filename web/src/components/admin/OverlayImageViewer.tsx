'use client';

import Image from 'next/image';
import { useEffect } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import useOverlayBodyLock from '@/hooks/useOverlayBodyLock';

export type OverlayImageViewerAsset = {
  url: string;
  alt?: string;
  title?: string;
  subtitle?: string;
  fileName?: string;
};

type OverlayImageViewerProps = {
  assets: OverlayImageViewerAsset[];
  activeIndex: number | null;
  onClose: () => void;
  onChange: (index: number) => void;
};

export default function OverlayImageViewer({
  assets,
  activeIndex,
  onClose,
  onChange,
}: OverlayImageViewerProps) {
  const activeAsset = activeIndex !== null ? assets[activeIndex] : null;
  const resolvedActiveIndex = activeIndex ?? 0;
  const hasCarousel = assets.length > 1;

  useOverlayBodyLock(activeIndex !== null);

  useEffect(() => {
    if (activeIndex === null) return;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose();
        return;
      }
      if (!hasCarousel) return;
      if (event.key === 'ArrowLeft') {
        onChange(activeIndex === 0 ? assets.length - 1 : activeIndex - 1);
      }
      if (event.key === 'ArrowRight') {
        onChange(activeIndex === assets.length - 1 ? 0 : activeIndex + 1);
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [activeIndex, assets.length, hasCarousel, onChange, onClose]);

  if (!activeAsset) return null;

  return (
    <div
      className="fixed inset-0 z-[95] flex items-center justify-center overflow-hidden overscroll-contain bg-black/80 p-6"
      onClick={(event) => {
        event.stopPropagation();
        onClose();
      }}
    >
      <div
        className="relative flex h-full min-h-0 w-full max-w-[1440px] overflow-hidden rounded-[28px] border border-white/10 bg-[#101414] shadow-[0_30px_120px_rgba(0,0,0,0.45)]"
        onClick={(event) => event.stopPropagation()}
      >
        {hasCarousel ? (
          <>
            <button
              type="button"
              onClick={() => onChange(resolvedActiveIndex === 0 ? assets.length - 1 : resolvedActiveIndex - 1)}
              className="absolute left-4 top-1/2 z-10 inline-flex h-12 w-12 -translate-y-1/2 items-center justify-center rounded-full bg-black/45 text-white transition hover:bg-black/60"
              aria-label="Previous image"
            >
              <ChevronLeft className="h-5 w-5" />
            </button>
            <button
              type="button"
              onClick={() => onChange(resolvedActiveIndex === assets.length - 1 ? 0 : resolvedActiveIndex + 1)}
              className="absolute right-[316px] top-1/2 z-10 inline-flex h-12 w-12 -translate-y-1/2 items-center justify-center rounded-full bg-black/45 text-white transition hover:bg-black/60"
              aria-label="Next image"
            >
              <ChevronRight className="h-5 w-5" />
            </button>
          </>
        ) : null}
        <button
          type="button"
          onClick={onClose}
          className="absolute right-4 top-4 z-10 inline-flex h-10 w-10 items-center justify-center rounded-full bg-white/10 text-white"
          aria-label="Close image preview"
        >
          ×
        </button>
        <div className="grid h-full w-full gap-0 lg:grid-cols-[minmax(0,1fr)_300px]">
          <div className="relative min-h-[480px] bg-black">
            <Image
              src={activeAsset.url}
              alt={activeAsset.alt || activeAsset.title || activeAsset.fileName || 'image preview'}
              fill
              className="object-contain"
              sizes="1600px"
            />
          </div>
          <div className="space-y-3 overflow-y-auto overscroll-contain bg-[#111827] p-6 text-white">
            <div className="text-xs font-semibold uppercase tracking-[0.14em] text-white/45">Media Detail</div>
            <div className="text-lg font-semibold">{activeAsset.title || activeAsset.fileName || 'Asset'}</div>
            {activeAsset.subtitle ? <div className="text-sm text-white/70">{activeAsset.subtitle}</div> : null}
            {activeAsset.fileName ? <div className="break-all text-sm text-white/70">{activeAsset.fileName}</div> : null}
            {hasCarousel ? (
              <div className="rounded-[18px] border border-white/10 bg-white/5 px-4 py-3 text-sm text-white/70">
                {resolvedActiveIndex + 1} / {assets.length}
              </div>
            ) : null}
            <div className="pt-2 text-xs text-white/45">Use left/right arrow keys to switch images and press Esc to close.</div>
          </div>
        </div>
      </div>
    </div>
  );
}
