'use client';

import Image from 'next/image';
import type { ReactNode } from 'react';
import { ChevronLeft, ChevronRight, Link2, Trash2 } from 'lucide-react';

export type AdminImageUploadPanelItem = {
  id: string;
  previewUrl: string;
  remoteUrl?: string | null;
  fileName?: string | null;
  statusText?: string | null;
  state?: 'idle' | 'uploading' | 'failed';
  linkUrl?: string | null;
  linkLabel?: string;
  removeLabel?: string;
  onRemove?: () => void;
  onMoveLeft?: () => void;
  onMoveRight?: () => void;
  moveLeftDisabled?: boolean;
  moveRightDisabled?: boolean;
};

type AdminImageUploadPanelProps = {
  title: string;
  description: string;
  hint: string;
  items: AdminImageUploadPanelItem[];
  onUpload: (files: File[]) => void;
  uploading?: boolean;
  multiple?: boolean;
  tone?: 'primary' | 'secondary';
  previewMode?: 'square' | 'landscape';
  className?: string;
  statsHint?: string;
  emptyActionLabel?: string;
  populatedActionLabel?: string;
  uploadingLabel?: string;
  children?: ReactNode;
};

const panelToneClassName = {
  primary: 'admin-reference-card',
  secondary: 'admin-reference-soft-card border border-[#e8eceb] bg-[#fafbf9]',
};

const previewHeightClassName = {
  square: 'h-[168px]',
  landscape: 'h-[128px]',
};

export default function AdminImageUploadPanel({
  title,
  description,
  hint,
  items,
  onUpload,
  uploading = false,
  multiple = false,
  tone = 'secondary',
  previewMode = 'square',
  className = '',
  statsHint,
  emptyActionLabel,
  populatedActionLabel,
  uploadingLabel = '上传中...',
  children,
}: AdminImageUploadPanelProps) {
  const uploadingCount = items.filter((item) => item.state === 'uploading').length;
  const actionLabel = uploading
    ? uploadingLabel
    : items.length
      ? (populatedActionLabel || (multiple ? '继续添加' : '更换图片'))
      : (emptyActionLabel || (multiple ? '选择图片' : '上传图片'));

  const summaryHint = uploadingCount
    ? `${uploadingCount} 张上传中`
    : statsHint || (multiple ? '单次最多选择 12 张' : '支持上传 1 张图片');

  return (
    <div className={`min-h-[332px] ${panelToneClassName[tone]} p-4 ${className}`.trim()}>
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[#071110]">{title}</div>
          <div className="mt-1 line-clamp-2 text-[11px] leading-5 text-black/48">{description}</div>
        </div>
        <label className="admin-studio-button-secondary shrink-0 cursor-pointer px-3 py-2 text-[11px]">
          {actionLabel}
          <input
            type="file"
            multiple={multiple}
            accept="image/*"
            className="hidden"
            onChange={(event) => {
              const files = Array.from(event.target.files || []);
              event.currentTarget.value = '';
              if (files.length) onUpload(files);
            }}
          />
        </label>
      </div>

      <div className="mt-4">
        <div className="mb-3 flex items-center justify-between gap-3 text-[11px] text-black/45">
          <span>{items.length} 张图片</span>
          <span>{summaryHint}</span>
        </div>
        {children ? (
          children
        ) : items.length ? (
          <div className="admin-shell-scrollbar -mx-1 flex gap-3 overflow-x-auto px-1 pb-2">
            {items.map((item) => {
              const previewUrl = item.previewUrl.trim();
              const remoteUrl = String(item.remoteUrl || '').trim();
              return (
                <div key={item.id} className="w-[168px] shrink-0 overflow-hidden rounded-[20px] border border-[#e8eceb] bg-white">
                  <div className={`relative overflow-hidden bg-[#f2f3ef] ${previewHeightClassName[previewMode]}`}>
                    {previewUrl ? (
                      remoteUrl ? (
                        <Image src={remoteUrl} alt={item.fileName || title} fill className="object-cover" sizes="240px" />
                      ) : (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={previewUrl} alt={item.fileName || title} className="h-full w-full object-cover" />
                      )
                    ) : (
                      <div className="flex h-full items-center justify-center text-[11px] text-black/35">暂无预览</div>
                    )}

                    {item.state === 'uploading' ? (
                      <div className="absolute inset-0 flex items-center justify-center bg-black/35 text-[11px] font-medium text-white">
                        上传中...
                      </div>
                    ) : null}

                    {item.state === 'failed' ? (
                      <div className="absolute right-2 top-2 rounded-full bg-[#fff4e6] px-2 py-1 text-[10px] font-semibold text-[#b25b00]">
                        上传失败
                      </div>
                    ) : null}
                  </div>

                  <div className="space-y-2 px-3 py-3">
                    <div className="min-w-0">
                      <div className="truncate text-[11px] font-medium text-[#071110]">{item.fileName || title}</div>
                      <div className="mt-1 truncate text-[10px] text-black/40">{item.statusText || '已上传'}</div>
                    </div>

                    {item.linkUrl ? (
                      <a
                        href={item.linkUrl}
                        target="_blank"
                        rel="noreferrer"
                        className="flex items-center gap-1 truncate text-[10px] text-[#415d56] hover:text-[#071110]"
                        title={item.linkUrl}
                      >
                        <Link2 className="h-3 w-3 shrink-0" />
                        <span className="truncate">{item.linkLabel || item.linkUrl}</span>
                      </a>
                    ) : null}

                    <div className="flex items-center justify-between gap-2">
                      <div className="flex items-center gap-1.5">
                        {item.onMoveLeft ? (
                          <button
                            type="button"
                            onClick={item.onMoveLeft}
                            disabled={item.moveLeftDisabled}
                            aria-label="向前移动"
                            className="inline-flex h-7 w-7 items-center justify-center rounded-full border border-[#d6ddd7] text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
                          >
                            <ChevronLeft className="h-3.5 w-3.5" />
                          </button>
                        ) : null}
                        {item.onMoveRight ? (
                          <button
                            type="button"
                            onClick={item.onMoveRight}
                            disabled={item.moveRightDisabled}
                            aria-label="向后移动"
                            className="inline-flex h-7 w-7 items-center justify-center rounded-full border border-[#d6ddd7] text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
                          >
                            <ChevronRight className="h-3.5 w-3.5" />
                          </button>
                        ) : null}
                      </div>

                      {item.onRemove ? (
                        <button
                          type="button"
                          onClick={item.onRemove}
                          className="inline-flex items-center gap-1 rounded-full border border-[#ead6d6] px-2.5 py-2 text-[10px] font-medium text-[#8b3a3a]"
                        >
                          <Trash2 className="h-3 w-3" />
                          <span>{item.removeLabel || '移除'}</span>
                        </button>
                      ) : null}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <div className="flex min-h-[224px] items-center justify-center rounded-[22px] border border-dashed border-[#d6ddd7] bg-white px-4 text-center text-[11px] leading-5 text-black/42">
            {hint}
          </div>
        )}
      </div>
    </div>
  );
}
