'use client';

import Image from 'next/image';
import Link from 'next/link';
import { ChangeEvent, FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import AdminAppShell from '@/components/admin/AdminAppShell';
import OverlayImageViewer, { type OverlayImageViewerAsset } from '@/components/admin/OverlayImageViewer';
import useOverlayBodyLock from '@/hooks/useOverlayBodyLock';
import { useAuth } from '@/contexts/AuthContext';
import { getAdminCmsRolePolicy } from '@/lib/admin/role-policy';
import {
  adminQuizApi,
  type AdminQuizConfig,
  type AdminQuizQuestion,
  type AdminQuizQuestionImportInput,
  type AdminQuizQuestionInput,
  type AdminQuizUserOverride,
  type QuizAttemptMode,
  type QuizQuestionStatus,
} from '@/lib/api/admin-quiz';

type TabKey = 'config' | 'debug_set' | 'questions' | 'overrides';
type EditorMode = 'create' | 'edit';

const QUESTION_PAGE_SIZE_OPTIONS = [10, 20, 50, 100] as const;

const QUIZ_IMPORT_EXAMPLE = `[
  {
    "status": "draft",
    "stemText": "以下哪一项最符合 House 的典型特征？",
    "timeLimitSec": 20,
    "tags": ["house", "genre"],
    "difficulty": "easy",
    "options": [
      { "id": "opt_a", "text": "稳定四拍地板鼓", "isCorrect": true },
      { "id": "opt_b", "text": "极端 breakcore 节奏" },
      { "id": "opt_c", "text": "完全无鼓点环境音" }
    ]
  },
  {
    "status": "active",
    "stemText": "图中这个术语对应哪种设备？",
    "stemImageUrl": "https://example.com/question-image.jpg",
    "correctOptionIndex": 1,
    "options": [
      { "text": "调音台" },
      { "text": "CDJ / 播放器" },
      { "text": "监听耳机" }
    ]
  }
]`;

const QUIZ_IMPORT_RULE_SECTIONS: Array<{
  title: string;
  items: string[];
}> = [
  {
    title: '整体结构',
    items: [
      '导入内容必须是一个 JSON 数组，数组里的每一项代表一道题。',
      '每一项都必须是对象，不能直接传字符串、数字或其他非对象结构。',
      '当前只支持 single_choice 单选题，题型不需要单独填写，系统会自动按单选题导入。',
    ],
  },
  {
    title: '题目字段',
    items: [
      '`stemText` 必填，系统会先 trim，去掉首尾空格后不能为空，最大长度 5000。',
      '`status` 可选，允许 `draft`、`active`、`archived`；如果不填或填了无效值，会自动按 `draft` 导入。',
      '`stemImageUrl` 可选；如果填写，必须是字符串，系统会 trim，最大长度 2000。',
      '`timeLimitSec` 可选；只有正整数才会生效，非正数、小数会被归一化，不合法时等同于不填。',
      '`sortOrder` 可选；会被取整，不填时系统会自动接在当前题库末尾。',
      '`tags` 可选；必须是字符串数组，系统会 trim、去重，最多保留 20 个标签，每个标签最大 64 字符。',
      '`difficulty` 可选；字符串，trim 后最大长度 64。',
      '`explanation` 可选；字符串，trim 后最大长度 5000。',
    ],
  },
  {
    title: '选项字段',
    items: [
      '`options` 必填，数量必须在 2 到 6 个之间。',
      '每个选项可以直接写成字符串，也可以写成对象。',
      '字符串写法会被自动转换为一个选项对象，文本就是这个字符串，图片为空，排序按数组顺序，id 自动生成为 `import_option_1` 这类临时值。',
      '对象写法支持 `id`、`text`、`imageUrl`、`sortOrder`、`isCorrect`。',
      '对象里的 `id` 如果不填，会自动按 `import_option_n` 补齐；同一道题里的 option id 不能重复。',
      '每个选项最终必须至少有 `text` 或 `imageUrl` 其中之一，两个都没有会直接报错。',
      '`sortOrder` 不填时默认就是当前选项在数组中的位置。',
    ],
  },
  {
    title: '正确答案判定规则',
    items: [
      '你必须至少提供一种正确答案指定方式，否则整道题会导入失败。',
      '系统按这个优先级确定正确答案：`correctOptionId` > `correctOptionIndex` > 唯一一个 `options[].isCorrect === true`。',
      '如果提供了 `correctOptionId`，它必须能匹配到导入后这道题的某个 option id。',
      '`correctOptionIndex` 是从 0 开始计数的数组下标，超出范围会直接报错。',
      '如果使用 `isCorrect` 方式，必须恰好只有一个选项标记为 `true`；如果多个选项都为 `true`，会直接报错。',
      '这里填写的 option id 只用于导入时在这道题内部建立正确答案映射，最终入库后数据库会生成新的真实 option id，不会保留你写入的临时 id。',
    ],
  },
  {
    title: '失败与校验说明',
    items: [
      '批量导入是逐条校验、统一创建的流程；只要其中一题不合法，这次导入就会失败。',
      '常见失败原因包括：`stemText` 为空、`options` 数量不在 2-6、option id 重复、没有正确答案、正确答案指向不存在的选项、某个选项既没有文本也没有图片。',
      'JSON 本身如果格式错误，例如逗号、引号、括号不合法，也会在提交前直接报解析错误。',
    ],
  },
];

type QuestionDraftOption = {
  id: string;
  text: string;
  imageUrl: string;
  sortOrder: number;
};

type QuestionDraft = {
  status: QuizQuestionStatus;
  stemText: string;
  stemImageUrl: string;
  correctOptionId: string;
  timeLimitSec: string;
  tags: string;
  difficulty: string;
  explanation: string;
  options: QuestionDraftOption[];
};

type UploadCompressionSummary = {
  originalBytes: number;
  uploadedBytes: number;
  compressed: boolean;
};

const resolveDraftTimeLimit = (defaultTimeLimitSec?: number | null): string => {
  if (typeof defaultTimeLimitSec !== 'number' || !Number.isFinite(defaultTimeLimitSec) || defaultTimeLimitSec <= 0) {
    return '';
  }
  return String(Math.floor(defaultTimeLimitSec));
};

const buildDraftOption = (sortOrder: number, seed?: Partial<QuestionDraftOption>): QuestionDraftOption => ({
  id: seed?.id || `opt_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
  text: seed?.text || '',
  imageUrl: seed?.imageUrl || '',
  sortOrder,
});

const createDefaultQuestionDraft = (defaultTimeLimitSec?: number | null): QuestionDraft => {
  const options = [buildDraftOption(0), buildDraftOption(1)];
  return {
    status: 'draft',
    stemText: '',
    stemImageUrl: '',
    correctOptionId: options[0]?.id || '',
    timeLimitSec: resolveDraftTimeLimit(defaultTimeLimitSec),
    tags: '',
    difficulty: '',
    explanation: '',
    options,
  };
};

const createDraftFromQuestion = (item: AdminQuizQuestion): QuestionDraft => ({
  status: item.status,
  stemText: item.stemText || '',
  stemImageUrl: item.stemImageUrl || '',
  correctOptionId: item.correctOptionId || item.options[0]?.id || '',
  timeLimitSec: item.timeLimitSec ? String(item.timeLimitSec) : '',
  tags: item.tags.join(', '),
  difficulty: item.difficulty || '',
  explanation: item.explanation || '',
  options: item.options
    .slice()
    .sort((a, b) => a.sortOrder - b.sortOrder)
    .map((option, index) =>
      buildDraftOption(index, {
        id: option.id,
        text: option.text || '',
        imageUrl: option.imageUrl || '',
        sortOrder: option.sortOrder,
      })
    ),
});

const formatTime = (value?: string | null): string => {
  if (!value) return '-';
  return new Date(value).toLocaleString();
};

const OPTION_LETTERS = ['A', 'B', 'C', 'D', 'E', 'F'];

const statusBadgeClass = (status: QuizQuestionStatus): string => {
  if (status === 'active') return 'bg-emerald-50 text-emerald-700 border border-emerald-200';
  if (status === 'archived') return 'bg-red-50 text-red-600 border border-red-200';
  return 'bg-amber-50 text-amber-700 border border-amber-200';
};

const previewOptionLabel = (text: string, imageUrl: string): string => {
  const normalized = text.trim();
  if (normalized) return normalized;
  return imageUrl.trim() ? '图片选项' : '未填写内容';
};

const normalizedPreviewOptionText = (text: string): string | null => {
  const normalized = text.trim();
  return normalized ? normalized : null;
};

const hasPreviewOptionImage = (imageUrl: string): boolean => imageUrl.trim().length > 0;

const usesImageGridPreview = (options: QuestionDraftOption[]): boolean =>
  options.length === 4 && options.every((option) => !normalizedPreviewOptionText(option.text) && hasPreviewOptionImage(option.imageUrl));

const formatBytes = (bytes: number): string => {
  if (!Number.isFinite(bytes) || bytes <= 0) return '0 B';
  if (bytes < 1024) return `${Math.round(bytes)} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(bytes < 10 * 1024 ? 1 : 0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(bytes < 10 * 1024 * 1024 ? 2 : 1)} MB`;
};

const buildCompressionSummaryText = (summary: UploadCompressionSummary): string => {
  const savedBytes = Math.max(0, summary.originalBytes - summary.uploadedBytes);
  const savedPercent =
    summary.originalBytes > 0 ? Math.max(0, Math.round((savedBytes / summary.originalBytes) * 100)) : 0;

  if (!summary.compressed || savedBytes <= 0) {
    return `${formatBytes(summary.originalBytes)} → ${formatBytes(summary.uploadedBytes)}`;
  }

  return `${formatBytes(summary.originalBytes)} → ${formatBytes(summary.uploadedBytes)} · 压缩 ${savedPercent}%`;
};

/* ─── shared input style ─── */
const inputCls = (multiline = false) =>
  `w-full rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm text-gray-900 placeholder-gray-400 outline-none transition focus:border-gray-900 focus:ring-0 ${
    multiline ? 'min-h-[80px] resize-y' : ''
  }`;

const selectCls = () =>
  `w-full rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm text-gray-900 outline-none transition focus:border-gray-900`;

const readOnlyInputCls = () =>
  `w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm text-gray-500 outline-none`;

/* ─── Field label wrapper ─── */
function Field({ label, hint, children }: { label: string; hint?: string; children: React.ReactNode }) {
  return (
    <label className="flex flex-col gap-1">
      <span className="text-[11px] font-medium text-gray-400 tracking-wide uppercase">
        {label}
        {hint ? <span className="ml-1.5 font-normal normal-case text-gray-400">{hint}</span> : null}
      </span>
      {children}
    </label>
  );
}

/* ─── Inline notice / error banner ─── */
function Banner({ type, message }: { type: 'error' | 'notice'; message: string }) {
  return (
    <div
      className={`rounded-xl px-4 py-3 text-sm font-medium ${
        type === 'error'
          ? 'bg-red-50 text-red-700 border border-red-200'
          : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
      }`}
    >
      {message}
    </div>
  );
}

/* ─── ID tooltip badge ─── */
function IdTooltip({ id }: { id: string }) {
  return (
    <div className="group relative inline-flex items-center">
      <span className="flex h-4 w-4 cursor-default items-center justify-center rounded-full border border-gray-300 text-[9px] font-bold text-gray-400 transition group-hover:border-gray-500 group-hover:text-gray-600 select-none">
        i
      </span>
      <div className="pointer-events-none absolute left-5 top-1/2 z-20 -translate-y-1/2 whitespace-nowrap rounded-lg border border-gray-200 bg-white px-2.5 py-1.5 font-mono text-[10px] text-gray-600 opacity-0 shadow-lg transition-opacity duration-150 group-hover:opacity-100">
        {id}
      </div>
    </div>
  );
}

function QuizImportOverlay({
  open,
  value,
  importing,
  feedback,
  onOpenRules,
  onChange,
  onClose,
  onFillExample,
  onSubmit,
}: {
  open: boolean;
  value: string;
  importing: boolean;
  feedback: { type: 'error' | 'notice'; message: string } | null;
  onOpenRules: () => void;
  onChange: (value: string) => void;
  onClose: () => void;
  onFillExample: () => void;
  onSubmit: (e: FormEvent<HTMLFormElement>) => void;
}) {
  useOverlayBodyLock(open);

  useEffect(() => {
    if (!open) return undefined;
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [onClose, open]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[140] bg-black/45 p-4 md:p-8" onClick={onClose}>
      <div
        className="mx-auto flex h-full max-w-4xl flex-col overflow-hidden rounded-[28px] border border-white/65 bg-[#f6f7f8] shadow-[0_30px_80px_rgba(15,23,42,0.22)]"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-black/8 bg-white px-6 py-4">
          <div>
            <div className="text-lg font-semibold tracking-[-0.03em] text-gray-900">批量导入题库</div>
            <p className="mt-1 text-sm text-gray-500">
              粘贴 JSON 数组，支持 `correctOptionId`、`correctOptionIndex`、`options[].isCorrect` 指定正确答案。
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded-full border border-gray-200 bg-white px-3 py-1.5 text-xs font-semibold text-gray-600 transition hover:bg-gray-50"
          >
            关闭
          </button>
        </div>

        <form onSubmit={onSubmit} className="flex min-h-0 flex-1 flex-col gap-4 p-6">
          {feedback ? <Banner type={feedback.type} message={feedback.message} /> : null}
          <textarea
            value={value}
            onChange={(e) => onChange(e.target.value)}
            className="min-h-0 flex-1 resize-none rounded-[24px] border border-gray-200 bg-white px-4 py-4 font-mono text-[12px] leading-6 text-gray-800 outline-none transition focus:border-gray-900"
            spellCheck={false}
          />
          <div className="flex items-center justify-between gap-3 rounded-[20px] border border-black/6 bg-white/80 px-4 py-3">
            <div className="min-w-0">
              <div className="text-xs font-semibold uppercase tracking-[0.14em] text-black/35">Import Rules</div>
              <p className="mt-1 text-xs leading-5 text-gray-500">
                查看完整字段要求、正确答案判定优先级、失败条件和推荐 JSON 组织方式。
              </p>
            </div>
            <button
              type="button"
              onClick={onOpenRules}
              className="shrink-0 rounded-full border border-gray-200 bg-white px-4 py-2 text-xs font-semibold text-gray-700 transition hover:bg-gray-50"
            >
              点击查看规则
            </button>
          </div>
          <div className="flex items-center justify-between gap-3">
            <button
              type="button"
              onClick={onFillExample}
              className="rounded-full border border-gray-200 bg-white px-4 py-2 text-xs font-semibold text-gray-600 transition hover:bg-gray-50"
            >
              填入示例
            </button>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={onClose}
                className="rounded-full border border-gray-200 bg-white px-4 py-2 text-xs font-semibold text-gray-600 transition hover:bg-gray-50"
              >
                取消
              </button>
              <button
                type="submit"
                disabled={importing}
                className="rounded-full bg-gray-900 px-4 py-2 text-xs font-semibold text-white transition hover:bg-gray-800 disabled:opacity-50"
              >
                {importing ? '导入中...' : '确认导入'}
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
}

function QuizImportRulesOverlay({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  useOverlayBodyLock(open);

  useEffect(() => {
    if (!open) return undefined;
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [onClose, open]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[155] bg-black/56 p-4 md:p-8" onClick={onClose}>
      <div
        className="mx-auto flex h-full max-w-5xl flex-col overflow-hidden rounded-[30px] border border-white/65 bg-[#f6f7f8] shadow-[0_34px_90px_rgba(15,23,42,0.28)]"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-black/8 bg-white px-6 py-5">
          <div>
            <div className="text-xl font-semibold tracking-[-0.03em] text-gray-900">批量导入规则说明</div>
            <p className="mt-1 text-sm text-gray-500">
              这份说明直接对齐当前后端真实校验逻辑，用来规范你整理题库文本时的字段写法。
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded-full border border-gray-200 bg-white px-3 py-1.5 text-xs font-semibold text-gray-600 transition hover:bg-gray-50"
          >
            关闭
          </button>
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto px-6 py-6">
          <div className="rounded-[24px] border border-[#d7e4dc] bg-white px-5 py-4">
            <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-black/35">Recommended Example</div>
            <pre className="mt-3 overflow-x-auto whitespace-pre-wrap break-words font-mono text-[12px] leading-6 text-[#1f2937]">
              {QUIZ_IMPORT_EXAMPLE}
            </pre>
          </div>

          <div className="mt-5 grid gap-4">
            {QUIZ_IMPORT_RULE_SECTIONS.map((section) => (
              <section key={section.title} className="rounded-[24px] border border-black/6 bg-white px-5 py-5">
                <div className="text-[15px] font-semibold tracking-[-0.02em] text-gray-900">{section.title}</div>
                <div className="mt-3 space-y-2">
                  {section.items.map((item) => (
                    <p key={item} className="text-sm leading-7 text-gray-600">
                      {item}
                    </p>
                  ))}
                </div>
              </section>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function QuizDeleteConfirmOverlay({
  open,
  count,
  deleting,
  onClose,
  onConfirm,
}: {
  open: boolean;
  count: number;
  deleting: boolean;
  onClose: () => void;
  onConfirm: () => void;
}) {
  useOverlayBodyLock(open);

  useEffect(() => {
    if (!open) return undefined;
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !deleting) onClose();
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [deleting, onClose, open]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[145] bg-black/48 p-4 md:p-8" onClick={() => (!deleting ? onClose() : undefined)}>
      <div
        className="mx-auto mt-[10vh] w-full max-w-[520px] overflow-hidden rounded-[28px] border border-white/65 bg-[#f6f7f8] shadow-[0_30px_80px_rgba(15,23,42,0.24)]"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="border-b border-black/8 bg-white px-6 py-5">
          <div className="text-lg font-semibold tracking-[-0.03em] text-gray-900">确认批量删除</div>
          <p className="mt-1 text-sm leading-6 text-gray-500">
            你当前选中了 <span className="font-semibold text-gray-900">{count}</span> 道题目。删除后将无法恢复，请确认这次操作。
          </p>
        </div>

        <div className="px-6 py-5">
          <div className="rounded-[22px] border border-red-100 bg-red-50/80 px-4 py-4">
            <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-red-500">Danger Zone</div>
            <p className="mt-2 text-sm leading-6 text-red-700">
              这会直接删除已选题目及其选项数据，不会进入归档，也不会保留恢复入口。
            </p>
          </div>

          <div className="mt-5 flex items-center justify-end gap-2">
            <button
              type="button"
              onClick={onClose}
              disabled={deleting}
              className="rounded-full border border-gray-200 bg-white px-4 py-2 text-xs font-semibold text-gray-600 transition hover:bg-gray-50 disabled:opacity-50"
            >
              取消
            </button>
            <button
              type="button"
              onClick={onConfirm}
              disabled={deleting}
              className="rounded-full bg-[#b42318] px-4 py-2 text-xs font-semibold text-white transition hover:bg-[#9f1f15] disabled:opacity-50"
            >
              {deleting ? '删除中...' : `确认删除 ${count} 道`}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ─── Image field: compact, no overflow ─── */
function QuizImageField({
  imageUrl,
  alt,
  uploadLabel,
  uploading,
  uploadSummary,
  onUpload,
  onRemove,
  onPreview,
  emptyMessage = '未上传图片',
}: {
  imageUrl: string;
  alt: string;
  uploadLabel: string;
  uploading: boolean;
  uploadSummary?: UploadCompressionSummary | null;
  onUpload: (event: ChangeEvent<HTMLInputElement>) => void;
  onRemove: () => void;
  onPreview: () => void;
  emptyMessage?: string;
}) {
  const normalizedImageUrl = imageUrl.trim();

  return (
    <div className="space-y-2">
      {/* action buttons row */}
      <div className="flex flex-wrap items-center gap-1.5">
        <label className="inline-flex cursor-pointer items-center gap-1.5 rounded-lg border border-gray-200 bg-gray-50 px-2.5 py-1.5 text-xs font-medium text-gray-600 transition hover:bg-gray-100">
          <input type="file" accept="image/*" className="hidden" onChange={onUpload} />
          {uploading ? '上传中...' : uploadLabel}
        </label>
        {normalizedImageUrl ? (
          <>
            <button
              type="button"
              onClick={onPreview}
              className="rounded-lg border border-gray-200 bg-white px-2.5 py-1.5 text-xs font-medium text-gray-600 transition hover:bg-gray-50"
            >
              全屏查看
            </button>
            <button
              type="button"
              onClick={onRemove}
              className="rounded-lg border border-red-100 bg-red-50 px-2.5 py-1.5 text-xs font-medium text-red-600 transition hover:bg-red-100"
            >
              移除
            </button>
          </>
        ) : null}
      </div>

      {/* image preview box */}
      {normalizedImageUrl ? (
        <div className="flex items-start gap-2.5 overflow-hidden rounded-xl border border-gray-200 bg-[#f4f5f6] p-2.5">
          {/* thumbnail */}
          <button
            type="button"
            onClick={onPreview}
            className="shrink-0 overflow-hidden rounded-lg border border-gray-200 bg-white transition hover:opacity-90"
            aria-label="打开大图预览"
            title="点击查看大图"
          >
            <div className="relative h-14 w-14">
              <Image
                src={normalizedImageUrl}
                alt={alt}
                fill
                className="object-contain"
                sizes="56px"
              />
            </div>
          </button>
          {/* info */}
          <div className="min-w-0 flex-1 overflow-hidden py-0.5">
            <div
              className="truncate text-[11px] text-gray-500 leading-snug"
              title={normalizedImageUrl}
            >
              {normalizedImageUrl.split('/').pop()?.split('?')[0] || normalizedImageUrl}
            </div>
            {uploadSummary ? (
              <div className="mt-1 text-[10px] text-gray-400">
                {buildCompressionSummaryText(uploadSummary)}
              </div>
            ) : null}
          </div>
        </div>
      ) : (
        <div className="rounded-xl border border-dashed border-gray-200 bg-[#f4f5f6] px-3 py-2.5 text-xs text-gray-400">
          {emptyMessage}
        </div>
      )}
    </div>
  );
}

/* ─── Main page ─── */
export default function AdminQuizPage() {
  const { user, isLoading } = useAuth();
  const rolePolicy = useMemo(() => getAdminCmsRolePolicy(user), [user]);
  const canOperate = rolePolicy.canAccessOperations;
  const canWrite = user?.role === 'admin';

  const [tab, setTab] = useState<TabKey>('config');
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  /* config */
  const [config, setConfig] = useState<AdminQuizConfig | null>(null);
  const [configDraft, setConfigDraft] = useState<Partial<AdminQuizConfig>>({});
  const [configLoading, setConfigLoading] = useState(false);
  const [configSaving, setConfigSaving] = useState(false);

  /* questions */
  const [questionQueryInput, setQuestionQueryInput] = useState('');
  const [questionQuery, setQuestionQuery] = useState('');
  const [questionStatus, setQuestionStatus] = useState<QuizQuestionStatus | ''>('');
  const [questionPage, setQuestionPage] = useState(1);
  const [questionPageSize, setQuestionPageSize] = useState<number>(10);
  const [questions, setQuestions] = useState<AdminQuizQuestion[]>([]);
  const [questionTotal, setQuestionTotal] = useState(0);
  const [questionLoading, setQuestionLoading] = useState(false);
  const [selectedQuestionId, setSelectedQuestionId] = useState<string | null>(null);
  const [editorMode, setEditorMode] = useState<EditorMode>('create');
  const [questionDraft, setQuestionDraft] = useState<QuestionDraft>(createDefaultQuestionDraft());
  const [questionSaving, setQuestionSaving] = useState(false);
  const [uploadingTarget, setUploadingTarget] = useState<string | null>(null);
  const [showImportOverlay, setShowImportOverlay] = useState(false);
  const [showImportRulesOverlay, setShowImportRulesOverlay] = useState(false);
  const [importText, setImportText] = useState(QUIZ_IMPORT_EXAMPLE);
  const [importingQuestions, setImportingQuestions] = useState(false);
  const [importFeedback, setImportFeedback] = useState<{ type: 'error' | 'notice'; message: string } | null>(null);
  const [multiSelectMode, setMultiSelectMode] = useState(false);
  const [selectedQuestionIds, setSelectedQuestionIds] = useState<string[]>([]);
  const [bulkDeletingQuestions, setBulkDeletingQuestions] = useState(false);
  const [showBulkDeleteConfirm, setShowBulkDeleteConfirm] = useState(false);
  const [imagePreviewAssets, setImagePreviewAssets] = useState<OverlayImageViewerAsset[]>([]);
  const [imagePreviewIndex, setImagePreviewIndex] = useState<number | null>(null);
  const [uploadCompressionByTarget, setUploadCompressionByTarget] = useState<Record<string, UploadCompressionSummary>>({});
  const [debugSetQuestionIds, setDebugSetQuestionIds] = useState<string[]>([]);
  const [debugSetItems, setDebugSetItems] = useState<AdminQuizQuestion[]>([]);
  const [debugSetLoading, setDebugSetLoading] = useState(false);
  const [debugSetSaving, setDebugSetSaving] = useState(false);

  /* overrides */
  const [overrideQueryInput, setOverrideQueryInput] = useState('');
  const [overrideQuery, setOverrideQuery] = useState('');
  const [overridePage, setOverridePage] = useState(1);
  const [overrides, setOverrides] = useState<AdminQuizUserOverride[]>([]);
  const [overrideTotal, setOverrideTotal] = useState(0);
  const [overrideLoading, setOverrideLoading] = useState(false);
  const [overrideSavingUserId, setOverrideSavingUserId] = useState<string | null>(null);
  const [overrideDrafts, setOverrideDrafts] = useState<
    Record<string, { attemptMode: QuizAttemptMode; dailyAttemptLimitOverride: string; note: string }>
  >({});

  const selectedQuestion = useMemo(
    () => questions.find((item) => item.id === selectedQuestionId) || null,
    [questions, selectedQuestionId]
  );

  const createFreshQuestionDraft = useCallback(
    () => createDefaultQuestionDraft(configDraft.defaultTimeLimitSec),
    [configDraft.defaultTimeLimitSec]
  );

  /* ── loaders ── */
  const loadConfig = useCallback(async () => {
    if (!canOperate) return;
    try {
      setConfigLoading(true);
      const result = await adminQuizApi.getConfig();
      setConfig(result.config);
      setConfigDraft(result.config);
    } catch (e) {
      setError(e instanceof Error ? e.message : '加载答题配置失败');
    } finally {
      setConfigLoading(false);
    }
  }, [canOperate]);

  const loadQuestions = useCallback(async () => {
    if (!canOperate) return;
    try {
      setQuestionLoading(true);
      const result = await adminQuizApi.listQuestions({
        q: questionQuery.trim() || undefined,
        status: questionStatus,
        page: questionPage,
        limit: questionPageSize,
      });
      setQuestions(result.items);
      setQuestionTotal(result.pagination.total);
      setSelectedQuestionIds((current) => current.filter((id) => result.items.some((item) => item.id === id)));
      setSelectedQuestionId((cur) =>
        cur && result.items.some((i) => i.id === cur) ? cur : result.items[0]?.id || null
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : '加载题库失败');
    } finally {
      setQuestionLoading(false);
    }
  }, [canOperate, questionPage, questionPageSize, questionQuery, questionStatus]);

  const loadOverrides = useCallback(async () => {
    if (!canOperate) return;
    try {
      setOverrideLoading(true);
      const result = await adminQuizApi.listUserOverrides({
        q: overrideQuery.trim() || undefined,
        page: overridePage,
        limit: 20,
      });
      setOverrides(result.items);
      setOverrideTotal(result.pagination.total);
      setOverrideDrafts((cur) => {
        const next = { ...cur };
        for (const item of result.items) {
          next[item.userId] = next[item.userId] || {
            attemptMode: item.attemptMode,
            dailyAttemptLimitOverride: item.dailyAttemptLimitOverride ? String(item.dailyAttemptLimitOverride) : '',
            note: item.note || '',
          };
        }
        return next;
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : '加载用户覆盖失败');
    } finally {
      setOverrideLoading(false);
    }
  }, [canOperate, overridePage, overrideQuery]);

  const loadDebugSet = useCallback(async () => {
    if (!canOperate) return;
    try {
      setDebugSetLoading(true);
      const result = await adminQuizApi.getDebugSet();
      setDebugSetQuestionIds(result.questionIds);
      setDebugSetItems(result.items);
    } catch (e) {
      setError(e instanceof Error ? e.message : '加载调试套题失败');
    } finally {
      setDebugSetLoading(false);
    }
  }, [canOperate]);

  useEffect(() => { void loadConfig(); }, [loadConfig]);
  useEffect(() => { void loadQuestions(); }, [loadQuestions]);
  useEffect(() => { void loadOverrides(); }, [loadOverrides]);
  useEffect(() => { void loadDebugSet(); }, [loadDebugSet]);

  useEffect(() => {
    if (selectedQuestion && editorMode === 'edit') {
      setQuestionDraft(createDraftFromQuestion(selectedQuestion));
      setUploadCompressionByTarget({});
    }
  }, [editorMode, selectedQuestion]);

  const totalQuestionPages = Math.max(1, Math.ceil(questionTotal / questionPageSize));
  const totalOverridePages = Math.max(1, Math.ceil(overrideTotal / 20));

  /* ── submit handlers ── */
  const submitConfig = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!canWrite || !configDraft) return;
    try {
      setConfigSaving(true);
      setError(null);
      setNotice(null);
      const result = await adminQuizApi.updateConfig({
        isEnabled: Boolean(configDraft.isEnabled),
        questionCount: Number(configDraft.questionCount),
        passCorrectCount: Number(configDraft.passCorrectCount),
        dailyAttemptLimit: Number(configDraft.dailyAttemptLimit),
        defaultTimeLimitSec: Number(configDraft.defaultTimeLimitSec),
        dailyLimitTimeZone: String(configDraft.dailyLimitTimeZone || 'Asia/Shanghai'),
        allowRetakeAfterPass: Boolean(configDraft.allowRetakeAfterPass),
        allowRestartDuringSession: Boolean(configDraft.allowRestartDuringSession),
      });
      setConfig(result.config);
      setConfigDraft(result.config);
      setNotice('答题系统配置已保存');
    } catch (e) {
      setError(e instanceof Error ? e.message : '保存答题配置失败');
    } finally {
      setConfigSaving(false);
    }
  };

  const buildQuestionInput = (): AdminQuizQuestionInput => ({
    status: questionDraft.status,
    type: 'single_choice',
    stemText: questionDraft.stemText.trim(),
    stemImageUrl: questionDraft.stemImageUrl.trim() || null,
    correctOptionId: questionDraft.correctOptionId,
    timeLimitSec: questionDraft.timeLimitSec.trim() ? Number(questionDraft.timeLimitSec) : null,
    tags: questionDraft.tags.split(',').map((t) => t.trim()).filter(Boolean),
    difficulty: questionDraft.difficulty.trim() || null,
    explanation: questionDraft.explanation.trim() || null,
    options: questionDraft.options.map((opt, i) => ({
      id: opt.id,
      text: opt.text.trim() || null,
      imageUrl: opt.imageUrl.trim() || null,
      sortOrder: Number.isFinite(opt.sortOrder) ? opt.sortOrder : i,
    })),
  });

  const submitQuestion = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!canWrite) return;
    try {
      setQuestionSaving(true);
      setError(null);
      setNotice(null);
      const payload = buildQuestionInput();
      const result =
        editorMode === 'edit' && selectedQuestionId
          ? await adminQuizApi.updateQuestion(selectedQuestionId, payload)
          : await adminQuizApi.createQuestion(payload);
      setNotice(editorMode === 'edit' ? '题目已更新' : '题目已创建');
      setEditorMode('edit');
      setSelectedQuestionId(result.item.id);
      await loadQuestions();
      setQuestionDraft(createDraftFromQuestion(result.item));
    } catch (e) {
      setError(e instanceof Error ? e.message : '保存题目失败');
    } finally {
      setQuestionSaving(false);
    }
  };

  const archiveQuestion = async () => {
    if (!canWrite || !selectedQuestionId) return;
    if (!window.confirm('确认归档这道题吗？归档后不会参与抽题。')) return;
    try {
      setQuestionSaving(true);
      setError(null);
      setNotice(null);
      await adminQuizApi.archiveQuestion(selectedQuestionId);
      setNotice('题目已归档');
      await loadQuestions();
    } catch (e) {
      setError(e instanceof Error ? e.message : '归档题目失败');
    } finally {
      setQuestionSaving(false);
    }
  };

  const uploadImage = async (e: ChangeEvent<HTMLInputElement>, target: 'stem' | string) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    try {
      setUploadingTarget(target);
      setError(null);
      const uploaded = await adminQuizApi.uploadImage(file, {
        profile: target === 'stem' ? 'stem' : 'option',
      });
      const compressionSummary: UploadCompressionSummary = uploaded.compression;
      if (target === 'stem') {
        setQuestionDraft((cur) => ({ ...cur, stemImageUrl: uploaded.url }));
      } else {
        setQuestionDraft((cur) => ({
          ...cur,
          options: cur.options.map((opt) => (opt.id === target ? { ...opt, imageUrl: uploaded.url } : opt)),
        }));
      }
      setUploadCompressionByTarget((current) => ({
        ...current,
        [target]: compressionSummary,
      }));
      setNotice(`图片上传成功 · ${buildCompressionSummaryText(compressionSummary)}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : '图片上传失败');
    } finally {
      setUploadingTarget(null);
    }
  };

  const clearImage = useCallback((target: 'stem' | string) => {
    if (target === 'stem') {
      setQuestionDraft((current) => ({ ...current, stemImageUrl: '' }));
      setUploadCompressionByTarget((current) => {
        const next = { ...current };
        delete next.stem;
        return next;
      });
      return;
    }

    setQuestionDraft((current) => ({
      ...current,
      options: current.options.map((option) => (option.id === target ? { ...option, imageUrl: '' } : option)),
    }));
    setUploadCompressionByTarget((current) => {
      const next = { ...current };
      delete next[target];
      return next;
    });
  }, []);

  const openImagePreview = useCallback((url: string, title: string, subtitle?: string) => {
    const normalizedUrl = url.trim();
    if (!normalizedUrl) return;

    const fileNameCandidate = normalizedUrl.split('/').pop()?.split('?')[0]?.trim() || title;
    setImagePreviewAssets([
      {
        url: normalizedUrl,
        title,
        subtitle,
        fileName: fileNameCandidate,
      },
    ]);
    setImagePreviewIndex(0);
  }, []);

  const saveOverride = async (userId: string) => {
    if (!canWrite) return;
    const draft = overrideDrafts[userId];
    if (!draft) return;
    try {
      setOverrideSavingUserId(userId);
      setError(null);
      setNotice(null);
      await adminQuizApi.updateUserOverride({
        userId,
        attemptMode: draft.attemptMode,
        dailyAttemptLimitOverride:
          draft.attemptMode === 'custom_limit' ? Number(draft.dailyAttemptLimitOverride || 0) : null,
        note: draft.note.trim() || null,
      });
      setNotice('用户次数覆盖已保存');
      await loadOverrides();
    } catch (e) {
      setError(e instanceof Error ? e.message : '保存用户覆盖失败');
    } finally {
      setOverrideSavingUserId(null);
    }
  };

  const submitImportQuestions = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!canWrite) return;
    try {
      setImportingQuestions(true);
      setImportFeedback(null);
      const parsed = JSON.parse(importText) as unknown;
      if (!Array.isArray(parsed)) throw new Error('导入内容必须是 JSON 数组');
      const result = await adminQuizApi.importQuestions({ questions: parsed as AdminQuizQuestionImportInput[] });
      setImportFeedback({ type: 'notice', message: `成功导入 ${result.count} 道题目` });
      setQuestionPage(1);
      await loadQuestions();
    } catch (e) {
      if (e instanceof SyntaxError) setImportFeedback({ type: 'error', message: `JSON 格式错误：${e.message}` });
      else setImportFeedback({ type: 'error', message: e instanceof Error ? e.message : '批量导入题目失败' });
    } finally {
      setImportingQuestions(false);
    }
  };

  const toggleQuestionMultiSelect = (id: string) => {
    setSelectedQuestionIds((current) =>
      current.includes(id) ? current.filter((itemId) => itemId !== id) : [...current, id]
    );
  };

  const handleToggleQuestionSelectAll = () => {
    const pageIds = questions.map((item) => item.id);
    const allSelected = pageIds.length > 0 && pageIds.every((id) => selectedQuestionIds.includes(id));
    setSelectedQuestionIds((current) => {
      if (allSelected) {
        return current.filter((id) => !pageIds.includes(id));
      }
      return Array.from(new Set([...current, ...pageIds]));
    });
  };

  const exitMultiSelectMode = () => {
    setMultiSelectMode(false);
    setSelectedQuestionIds([]);
  };

  const deleteSelectedQuestions = async () => {
    if (!canWrite || selectedQuestionIds.length === 0) return;
    try {
      setBulkDeletingQuestions(true);
      setError(null);
      setNotice(null);
      await adminQuizApi.bulkDeleteQuestions(selectedQuestionIds);
      setNotice(`已删除 ${selectedQuestionIds.length} 道题目`);
      setSelectedQuestionId((current) => (current && selectedQuestionIds.includes(current) ? null : current));
      setShowBulkDeleteConfirm(false);
      exitMultiSelectMode();
      await loadQuestions();
    } catch (e) {
      setError(e instanceof Error ? e.message : '批量删除题目失败');
    } finally {
      setBulkDeletingQuestions(false);
    }
  };

  const addQuestionToDebugSet = (question: AdminQuizQuestion) => {
    setDebugSetQuestionIds((current) => (current.includes(question.id) ? current : [...current, question.id]));
    setDebugSetItems((current) => (current.some((item) => item.id === question.id) ? current : [...current, question]));
  };

  const removeQuestionFromDebugSet = (questionId: string) => {
    setDebugSetQuestionIds((current) => current.filter((id) => id !== questionId));
    setDebugSetItems((current) => current.filter((item) => item.id !== questionId));
  };

  const moveDebugSetQuestion = (questionId: string, direction: 'up' | 'down') => {
    setDebugSetQuestionIds((current) => {
      const index = current.indexOf(questionId);
      if (index < 0) return current;
      const nextIndex = direction === 'up' ? index - 1 : index + 1;
      if (nextIndex < 0 || nextIndex >= current.length) return current;
      const next = current.slice();
      [next[index], next[nextIndex]] = [next[nextIndex], next[index]];
      return next;
    });
    setDebugSetItems((current) => {
      const index = current.findIndex((item) => item.id === questionId);
      if (index < 0) return current;
      const nextIndex = direction === 'up' ? index - 1 : index + 1;
      if (nextIndex < 0 || nextIndex >= current.length) return current;
      const next = current.slice();
      [next[index], next[nextIndex]] = [next[nextIndex], next[index]];
      return next;
    });
  };

  const saveDebugSet = async () => {
    if (!canWrite) return;
    try {
      setDebugSetSaving(true);
      setError(null);
      setNotice(null);
      const result = await adminQuizApi.updateDebugSet(debugSetQuestionIds);
      setDebugSetQuestionIds(result.questionIds);
      setDebugSetItems(result.items);
      await loadConfig();
      setNotice(`调试套题已保存，共 ${result.questionIds.length} 题`);
    } catch (e) {
      setError(e instanceof Error ? e.message : '保存调试套题失败');
    } finally {
      setDebugSetSaving(false);
    }
  };

  /* ── gate states ── */
  if (isLoading) {
    return (
      <AdminAppShell title="答题系统" description="加载答题系统配置中。">
        <div className="p-8 text-sm text-gray-400">加载中...</div>
      </AdminAppShell>
    );
  }
  if (!user || !canOperate) {
    return (
      <AdminAppShell title="答题系统" description="当前账号暂时不能访问答题系统后台。">
        <section className="mx-auto max-w-4xl">
          <div className="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
            <h1 className="text-2xl font-semibold text-gray-900">答题系统</h1>
            <p className="mt-3 text-sm text-gray-500">当前账号无权限访问该页面。</p>
            <Link
              href={user ? '/admin' : '/login'}
              className="mt-5 inline-flex rounded-full bg-gray-900 px-5 py-2.5 text-sm font-semibold text-white"
            >
              {user ? '返回后台' : '去登录'}
            </Link>
          </div>
        </section>
      </AdminAppShell>
    );
  }

  /* ════════════════════════════════════════════
     RENDER
  ════════════════════════════════════════════ */
  return (
    <AdminAppShell title="答题系统" description="围绕主线维护题库、全局配置与用户级答题次数覆盖。" hidePageHeader>
      <div className="flex min-h-full flex-col bg-gray-50">

        {/* ── top header bar ── */}
        <div className="flex items-center justify-between border-b border-gray-200 bg-white px-6 py-4">
          <div>
            <h1 className="text-xl font-bold text-gray-900">答题系统</h1>
            <p className="mt-0.5 text-sm text-gray-500">围绕主线维护题库、全局配置与用户级答题次数覆盖。</p>
          </div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => { void loadConfig(); void loadQuestions(); void loadOverrides(); void loadDebugSet(); }}
              className="flex items-center gap-1.5 rounded-full border border-gray-200 bg-white px-3.5 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50 transition"
            >
              <svg className="h-3.5 w-3.5" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M1 8a7 7 0 1 1 .6 2.8M1 8V3m0 5H6" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
              刷新
            </button>
            {tab === 'questions' ? (
              <button
                type="button"
                onClick={() => {
                  const form = document.getElementById('question-form') as HTMLFormElement | null;
                  form?.requestSubmit();
                }}
                disabled={!canWrite || questionSaving}
                className="rounded-full bg-gray-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50 hover:bg-gray-800 transition"
              >
                {questionSaving ? '保存中...' : editorMode === 'edit' ? '保存题目' : '创建题目'}
              </button>
            ) : null}
            {tab === 'config' ? (
              <button
                type="button"
                onClick={() => {
                  const form = document.getElementById('config-form') as HTMLFormElement | null;
                  form?.requestSubmit();
                }}
                disabled={!canWrite || configSaving || configLoading}
                className="rounded-full bg-gray-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50 hover:bg-gray-800 transition"
              >
                {configSaving ? '保存中...' : '保存配置'}
              </button>
            ) : null}
            {tab === 'debug_set' ? (
              <button
                type="button"
                onClick={() => { void saveDebugSet(); }}
                disabled={!canWrite || debugSetSaving}
                className="rounded-full bg-gray-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50 hover:bg-gray-800 transition"
              >
                {debugSetSaving ? '保存中...' : '保存调试套题'}
              </button>
            ) : null}
          </div>
        </div>

        {/* ── tab bar ── */}
        <div className="flex items-center gap-0.5 border-b border-gray-200 bg-white px-6 pt-2">
          {([
            ['config', '配置'],
            ['debug_set', '调试套题'],
            ['questions', '题库'],
            ['overrides', '用户次数覆盖'],
          ] as Array<[TabKey, string]>).map(([key, label]) => (
            <button
              key={key}
              type="button"
              onClick={() => setTab(key)}
              className={`rounded-t-lg px-4 py-2 text-sm font-medium transition mb-[-1px] border-b-2 ${
                tab === key
                  ? 'border-gray-900 text-gray-900'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        {/* ── page body ── */}
        <div className="flex-1 overflow-auto p-5">
          {/* banners */}
          {error ? <div className="mb-4"><Banner type="error" message={error} /></div> : null}
          {notice ? <div className="mb-4"><Banner type="notice" message={notice} /></div> : null}

          {/* ══ CONFIG TAB ══ */}
          {tab === 'config' ? (
            <div className="mx-auto max-w-2xl">
              <div className="rounded-2xl border border-gray-200 bg-white shadow-sm">
                <div className="border-b border-gray-100 px-6 py-4">
                  <div className="text-[11px] font-semibold uppercase tracking-widest text-gray-400">Quiz Config</div>
                  <p className="mt-1 text-sm text-gray-500">控制答题系统的开关、抽题规模、通过标准和每日次数规则。</p>
                </div>
                <form id="config-form" onSubmit={submitConfig} className="p-6 space-y-6">
                  {/* toggles section */}
                  <div>
                    <div className="mb-3 text-[11px] font-semibold uppercase tracking-widest text-gray-300">开关</div>
                    <div className="grid gap-3 sm:grid-cols-3">
                      {([
                        ['isEnabled', '系统启用'] as const,
                        ['allowRetakeAfterPass', '通过后可重答'] as const,
                        ['allowRestartDuringSession', '答题中可重启'] as const,
                      ]).map(([key, label]) => (
                        <label key={key} className="flex cursor-pointer items-center justify-between gap-3 rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
                          <span className="text-sm text-gray-700">{label}</span>
                          <div
                            onClick={() => setConfigDraft((c) => ({ ...c, [key]: !c[key] }))}
                            className={`relative h-5 w-9 flex-shrink-0 rounded-full transition-colors ${
                              configDraft[key] ? 'bg-gray-900' : 'bg-gray-300'
                            }`}
                          >
                            <span
                              className={`absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition-transform ${
                                configDraft[key] ? 'translate-x-4' : 'translate-x-0.5'
                              }`}
                            />
                          </div>
                        </label>
                      ))}
                    </div>
                  </div>

                  {/* numbers section */}
                  <div>
                    <div className="mb-3 text-[11px] font-semibold uppercase tracking-widest text-gray-300">参数</div>
                    <div className="grid gap-3 sm:grid-cols-2">
                      <Field label="答题数量">
                        <input
                          type="number"
                          value={String(configDraft.questionCount ?? '')}
                          onChange={(e) => setConfigDraft((c) => ({ ...c, questionCount: Number(e.target.value || 0) }))}
                          className={inputCls()}
                        />
                      </Field>
                      <Field label="通过所需正确题数">
                        <input
                          type="number"
                          value={String(configDraft.passCorrectCount ?? '')}
                          onChange={(e) => setConfigDraft((c) => ({ ...c, passCorrectCount: Number(e.target.value || 0) }))}
                          className={inputCls()}
                        />
                      </Field>
                      <Field label="默认每日次数">
                        <input
                          type="number"
                          value={String(configDraft.dailyAttemptLimit ?? '')}
                          onChange={(e) => setConfigDraft((c) => ({ ...c, dailyAttemptLimit: Number(e.target.value || 0) }))}
                          className={inputCls()}
                        />
                      </Field>
                      <Field label="默认单题时长（秒）">
                        <input
                          type="number"
                          value={String(configDraft.defaultTimeLimitSec ?? '')}
                          onChange={(e) => setConfigDraft((c) => ({ ...c, defaultTimeLimitSec: Number(e.target.value || 0) }))}
                          className={inputCls()}
                        />
                      </Field>
                      <Field label="日限额时区" hint="sm:col-span-2">
                        <input
                          value={String(configDraft.dailyLimitTimeZone ?? '')}
                          onChange={(e) => setConfigDraft((c) => ({ ...c, dailyLimitTimeZone: e.target.value }))}
                          className={inputCls()}
                        />
                      </Field>
                    </div>
                  </div>

                  <div className="flex items-center justify-between rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
                    <span className="text-xs text-gray-400">
                      最后更新：{config ? formatTime(config.updatedAt) : configLoading ? '加载中...' : '-'}
                    </span>
                    <button
                      type="submit"
                      disabled={!canWrite || configSaving || configLoading}
                      className="rounded-full bg-gray-900 px-5 py-2 text-sm font-semibold text-white disabled:opacity-50 hover:bg-gray-800 transition"
                    >
                      {configSaving ? '保存中...' : '保存配置'}
                    </button>
                  </div>
                </form>
              </div>
            </div>
          ) : null}

          {/* ══ DEBUG SET TAB ══ */}
          {tab === 'debug_set' ? (
            <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_360px]">
              {/* left: question picker */}
              <div className="rounded-2xl border border-gray-200 bg-white shadow-sm">
                <div className="flex items-center justify-between border-b border-gray-100 px-5 py-4">
                  <div>
                    <div className="text-[11px] font-semibold uppercase tracking-widest text-gray-400">Debug Question Picker</div>
                    <p className="mt-0.5 text-sm text-gray-500">从现有题库中挑选题目组成 admin-only 调试套题。</p>
                  </div>
                  <span className="text-xs text-gray-400">已选 {debugSetQuestionIds.length} 题</span>
                </div>

                <div className="border-b border-gray-100 px-5 py-3">
                  <form
                    onSubmit={(e) => {
                      e.preventDefault();
                      setQuestionPage(1);
                      setQuestionQuery(questionQueryInput);
                    }}
                    className="flex flex-wrap gap-2"
                  >
                    <input
                      value={questionQueryInput}
                      onChange={(e) => setQuestionQueryInput(e.target.value)}
                      placeholder="搜索题干 / 难度 / 题目 ID"
                      className={inputCls() + ' min-w-[180px] flex-1'}
                    />
                    <select
                      value={questionStatus}
                      onChange={(e) => {
                        setQuestionPage(1);
                        setQuestionStatus(e.target.value as QuizQuestionStatus | '');
                      }}
                      className={selectCls() + ' max-w-[140px]'}
                    >
                      <option value="">全部状态</option>
                      <option value="draft">draft</option>
                      <option value="active">active</option>
                      <option value="archived">archived</option>
                    </select>
                    <button
                      type="submit"
                      className="rounded-lg border border-gray-200 bg-gray-50 px-4 py-2 text-sm font-semibold text-gray-700 transition hover:bg-gray-100"
                    >
                      搜索
                    </button>
                  </form>
                </div>

                <div className="divide-y divide-gray-100">
                  {questionLoading ? (
                    <div className="px-5 py-8 text-center text-sm text-gray-400">加载题库中...</div>
                  ) : questions.length === 0 ? (
                    <div className="px-5 py-8 text-center text-sm text-gray-400">当前筛选条件下没有题目</div>
                  ) : (
                    questions.map((item) => {
                      const inDebugSet = debugSetQuestionIds.includes(item.id);
                      return (
                        <div key={`debug-library-${item.id}`} className="flex items-center justify-between gap-4 px-5 py-3.5">
                          <div className="min-w-0 flex-1">
                            <div className="flex items-center gap-2 mb-1">
                              <span className={`rounded-full px-2 py-0.5 text-[10px] font-semibold ${statusBadgeClass(item.status)}`}>
                                {item.status}
                              </span>
                              <IdTooltip id={item.id} />
                            </div>
                            <div className="line-clamp-2 text-sm font-medium text-gray-900">
                              {item.stemText || '未填写题干'}
                            </div>
                            <div className="mt-1 flex flex-wrap gap-2 text-[11px] text-gray-400">
                              <span>{item.options.length} 个选项</span>
                              <span>·</span>
                              <span>{item.timeLimitSec ?? '-'} 秒</span>
                              {item.difficulty ? <><span>·</span><span>{item.difficulty}</span></> : null}
                            </div>
                          </div>
                          <button
                            type="button"
                            disabled={!canWrite || inDebugSet}
                            onClick={() => addQuestionToDebugSet(item)}
                            className={`shrink-0 rounded-full px-3 py-1.5 text-xs font-semibold transition ${
                              inDebugSet
                                ? 'cursor-not-allowed border border-emerald-200 bg-emerald-50 text-emerald-600'
                                : 'border border-gray-200 bg-white text-gray-700 hover:bg-gray-50'
                            }`}
                          >
                            {inDebugSet ? '✓ 已加入' : '加入'}
                          </button>
                        </div>
                      );
                    })
                  )}
                </div>

                <div className="flex items-center justify-between border-t border-gray-100 px-5 py-3 text-xs text-gray-500">
                  <span>第 {questionPage} / {totalQuestionPages} 页 · 共 {questionTotal} 题</span>
                  <div className="flex gap-1.5">
                    <button
                      type="button"
                      disabled={questionPage <= 1}
                      onClick={() => setQuestionPage((page) => Math.max(1, page - 1))}
                      className="rounded-full border border-gray-200 px-3 py-1.5 hover:bg-gray-50 disabled:opacity-40"
                    >
                      上一页
                    </button>
                    <button
                      type="button"
                      disabled={questionPage >= totalQuestionPages}
                      onClick={() => setQuestionPage((page) => Math.min(totalQuestionPages, page + 1))}
                      className="rounded-full border border-gray-200 px-3 py-1.5 hover:bg-gray-50 disabled:opacity-40"
                    >
                      下一页
                    </button>
                  </div>
                </div>
              </div>

              {/* right: current debug set */}
              <div className="rounded-2xl border border-gray-200 bg-white shadow-sm">
                <div className="border-b border-gray-100 px-5 py-4">
                  <div className="text-[11px] font-semibold uppercase tracking-widest text-gray-400">Current Debug Set</div>
                  <p className="mt-0.5 text-sm text-gray-500">iOS admin 开始页会按此顺序出题。</p>
                </div>

                <div className="divide-y divide-gray-100">
                  {debugSetLoading ? (
                    <div className="px-5 py-8 text-center text-sm text-gray-400">加载调试套题中...</div>
                  ) : debugSetItems.length === 0 ? (
                    <div className="px-5 py-8 text-center text-sm text-gray-400">还没有加入任何调试题目</div>
                  ) : (
                    debugSetItems.map((item, index) => (
                      <div key={`debug-selected-${item.id}`} className="flex items-start gap-3 px-4 py-3.5">
                        <div className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-gray-900 text-[11px] font-semibold text-white mt-0.5">
                          {index + 1}
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="line-clamp-2 text-sm font-medium text-gray-900">{item.stemText || '未填写题干'}</div>
                          <div className="mt-2 flex flex-wrap gap-1.5">
                            <button
                              type="button"
                              disabled={!canWrite || index === 0}
                              onClick={() => moveDebugSetQuestion(item.id, 'up')}
                              className="rounded-full border border-gray-200 px-2.5 py-1 text-xs font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-40"
                            >
                              ↑
                            </button>
                            <button
                              type="button"
                              disabled={!canWrite || index === debugSetItems.length - 1}
                              onClick={() => moveDebugSetQuestion(item.id, 'down')}
                              className="rounded-full border border-gray-200 px-2.5 py-1 text-xs font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-40"
                            >
                              ↓
                            </button>
                            <button
                              type="button"
                              disabled={!canWrite}
                              onClick={() => removeQuestionFromDebugSet(item.id)}
                              className="rounded-full border border-red-100 bg-red-50 px-2.5 py-1 text-xs font-medium text-red-600 hover:bg-red-100 disabled:opacity-50"
                            >
                              移除
                            </button>
                          </div>
                        </div>
                      </div>
                    ))
                  )}
                </div>

                <div className="flex items-center justify-between border-t border-gray-100 px-5 py-3 text-xs text-gray-500">
                  <span>共 {debugSetQuestionIds.length} 题</span>
                  <button
                    type="button"
                    disabled={!canWrite || debugSetSaving}
                    onClick={() => void saveDebugSet()}
                    className="rounded-full bg-gray-900 px-4 py-2 text-xs font-semibold text-white disabled:opacity-50 hover:bg-gray-800 transition"
                  >
                    {debugSetSaving ? '保存中...' : '保存'}
                  </button>
                </div>
              </div>
            </div>
          ) : null}

          {/* ══ QUESTIONS TAB ══ */}
          {tab === 'questions' ? (
            <div className="grid gap-4 xl:grid-cols-[300px_minmax(0,1fr)_320px]">

              {/* ── col 1: question list ── */}
              <div className="flex flex-col gap-0 rounded-2xl border border-gray-200 bg-white shadow-sm overflow-hidden">
                {/* header */}
                <div className="flex items-center justify-between border-b border-gray-100 px-4 py-3">
                  <div className="text-[11px] font-semibold uppercase tracking-widest text-gray-400">题库</div>
                  <button
                    type="button"
                    onClick={() => {
                      setEditorMode('create');
                      setSelectedQuestionId(null);
                      setQuestionDraft(createFreshQuestionDraft());
                      setUploadCompressionByTarget({});
                    }}
                    className="rounded-full bg-gray-900 px-3 py-1.5 text-xs font-semibold text-white hover:bg-gray-800 transition"
                  >
                    新建
                  </button>
                </div>

                {/* toolbar */}
                <div className="border-b border-gray-100 px-3 py-2.5 space-y-2">
                  <div className="flex items-center gap-1.5">
                    <button
                      type="button"
                      onClick={() => {
                        setImportFeedback(null);
                        setShowImportOverlay(true);
                      }}
                      className="rounded-full border border-dashed border-gray-300 px-2.5 py-1 text-xs font-medium text-gray-500 transition hover:border-gray-400 hover:text-gray-700"
                    >
                      ＋ 批量导入
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        if (multiSelectMode) { exitMultiSelectMode(); return; }
                        setMultiSelectMode(true);
                        setSelectedQuestionIds([]);
                      }}
                      className={`rounded-full border px-2.5 py-1 text-xs font-medium transition ${
                        multiSelectMode
                          ? 'border-gray-900 bg-gray-900 text-white'
                          : 'border-gray-200 bg-white text-gray-600 hover:bg-gray-50'
                      }`}
                    >
                      {multiSelectMode ? '退出多选' : '多选'}
                    </button>
                    {multiSelectMode ? (
                      <>
                        <button
                          type="button"
                          onClick={handleToggleQuestionSelectAll}
                          className="rounded-full border border-gray-200 bg-white px-2.5 py-1 text-xs font-medium text-gray-600 transition hover:bg-gray-50"
                        >
                          全选
                        </button>
                        <button
                          type="button"
                          onClick={() => setShowBulkDeleteConfirm(true)}
                          disabled={!canWrite || selectedQuestionIds.length === 0 || bulkDeletingQuestions}
                          className="rounded-full border border-red-200 bg-red-50 px-2.5 py-1 text-xs font-semibold text-red-600 transition hover:bg-red-100 disabled:opacity-50"
                        >
                          {bulkDeletingQuestions ? '删除中...' : `删 ${selectedQuestionIds.length}`}
                        </button>
                      </>
                    ) : null}
                  </div>

                  {/* search */}
                  <form
                    onSubmit={(e) => { e.preventDefault(); setQuestionPage(1); setQuestionQuery(questionQueryInput); }}
                    className="space-y-1.5"
                  >
                    <input
                      value={questionQueryInput}
                      onChange={(e) => setQuestionQueryInput(e.target.value)}
                      placeholder="搜索题干 / 难度 / id"
                      className={inputCls()}
                    />
                    <div className="flex gap-1.5">
                      <select
                        value={questionStatus}
                        onChange={(e) => { setQuestionStatus(e.target.value as QuizQuestionStatus | ''); setQuestionPage(1); }}
                        className={selectCls() + ' flex-1 text-xs'}
                      >
                        <option value="">全部状态</option>
                        <option value="draft">draft</option>
                        <option value="active">active</option>
                        <option value="archived">archived</option>
                      </select>
                      <button
                        type="submit"
                        className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-xs font-semibold text-gray-700 hover:bg-gray-50 transition"
                      >
                        搜索
                      </button>
                    </div>
                    <div className="flex items-center justify-between gap-2">
                      <span className="text-[11px] text-gray-400">每页</span>
                      <select
                        value={String(questionPageSize)}
                        onChange={(e) => {
                          setQuestionPageSize(Number(e.target.value || 10));
                          setQuestionPage(1);
                        }}
                        className="rounded-lg border border-gray-200 bg-white px-2 py-1.5 text-xs text-gray-700 outline-none focus:border-gray-900"
                      >
                        {QUESTION_PAGE_SIZE_OPTIONS.map((size) => (
                          <option key={size} value={size}>{size} 条</option>
                        ))}
                      </select>
                    </div>
                  </form>
                </div>

                {/* question cards */}
                <div className="flex-1 divide-y divide-gray-100 overflow-y-auto">
                  {questionLoading ? (
                    <div className="px-4 py-6 text-center text-xs text-gray-400">加载中...</div>
                  ) : questions.length === 0 ? (
                    <div className="px-4 py-6 text-center text-xs text-gray-400">暂无题目</div>
                  ) : (
                    questions.map((item) => {
                      const isSelected = selectedQuestionId === item.id;
                      const isChecked = selectedQuestionIds.includes(item.id);
                      return (
                        <button
                          key={item.id}
                          type="button"
                          onClick={() => {
                            if (multiSelectMode) { toggleQuestionMultiSelect(item.id); return; }
                            setSelectedQuestionId(item.id);
                            setEditorMode('edit');
                            setQuestionDraft(createDraftFromQuestion(item));
                          }}
                          className={`w-full px-4 py-3 text-left transition hover:bg-gray-50 ${
                            multiSelectMode ? (isChecked ? 'bg-red-50' : 'bg-white') : isSelected ? 'bg-emerald-50' : ''
                          }`}
                        >
                          <div className="flex items-start justify-between gap-2">
                            {multiSelectMode ? (
                              <div className="mt-0.5 flex h-4 w-4 flex-shrink-0 items-center justify-center rounded border border-gray-300 bg-white">
                                {isChecked ? (
                                  <svg className="h-3 w-3 text-red-600" viewBox="0 0 12 12" fill="none">
                                    <path d="M2 6l2.5 2.5L10 3" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
                                  </svg>
                                ) : null}
                              </div>
                            ) : null}
                            <div className="min-w-0 flex-1">
                              <div className="line-clamp-2 text-sm font-medium text-gray-900 leading-snug">{item.stemText}</div>
                              <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
                                <span className={`rounded-full px-1.5 py-0.5 text-[10px] font-medium ${statusBadgeClass(item.status)}`}>
                                  {item.status}
                                </span>
                                <span className="text-[10px] text-gray-400">{item.options.length}选 · {item.timeLimitSec ?? '-'}s</span>
                                <IdTooltip id={item.id} />
                              </div>
                            </div>
                            {!multiSelectMode ? (
                              <div className={`mt-0.5 flex h-4 w-4 flex-shrink-0 items-center justify-center rounded-full ${
                                isSelected ? 'bg-emerald-500' : 'border-2 border-gray-200'
                              }`}>
                                {isSelected ? (
                                  <svg className="h-2.5 w-2.5 text-white" viewBox="0 0 12 12" fill="none">
                                    <path d="M2 6l3 3 5-5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
                                  </svg>
                                ) : null}
                              </div>
                            ) : null}
                          </div>
                        </button>
                      );
                    })
                  )}
                </div>

                {/* pagination */}
                <div className="flex items-center justify-between border-t border-gray-100 px-4 py-2.5 text-[11px] text-gray-500">
                  <span>{questionPage}/{totalQuestionPages} · {questionTotal} 条</span>
                  <div className="flex gap-1">
                    <button
                      type="button"
                      disabled={questionPage <= 1}
                      onClick={() => setQuestionPage((p) => Math.max(1, p - 1))}
                      className="rounded border border-gray-200 px-2 py-1 disabled:opacity-40 hover:bg-gray-50"
                    >‹</button>
                    <button
                      type="button"
                      disabled={questionPage >= totalQuestionPages}
                      onClick={() => setQuestionPage((p) => Math.min(totalQuestionPages, p + 1))}
                      className="rounded border border-gray-200 px-2 py-1 disabled:opacity-40 hover:bg-gray-50"
                    >›</button>
                  </div>
                </div>
              </div>

              {/* ── col 2: question editor ── */}
              <div className="rounded-2xl border border-gray-200 bg-white shadow-sm overflow-hidden">
                <div className="flex items-center justify-between border-b border-gray-100 px-5 py-3.5">
                  <div>
                    <div className="text-[11px] font-semibold uppercase tracking-widest text-gray-400">
                      {editorMode === 'edit' ? 'Question Editor' : 'New Question'}
                    </div>
                    <p className="mt-0.5 text-xs text-gray-400">单选题 · 正确答案从右侧选项列表设置</p>
                  </div>
                  {editorMode === 'edit' && selectedQuestionId ? (
                    <button
                      type="button"
                      onClick={archiveQuestion}
                      disabled={!canWrite || questionSaving}
                      className="rounded-full border border-red-200 bg-red-50 px-3 py-1.5 text-xs font-semibold text-red-600 hover:bg-red-100 transition disabled:opacity-50"
                    >
                      归档
                    </button>
                  ) : null}
                </div>

                <form id="question-form" onSubmit={submitQuestion} className="p-5 space-y-4">
                  {/* row 1: status + time */}
                  <div className="grid grid-cols-2 gap-3">
                    <Field label="状态">
                      <select
                        value={questionDraft.status}
                        onChange={(e) => setQuestionDraft((c) => ({ ...c, status: e.target.value as QuizQuestionStatus }))}
                        className={selectCls()}
                      >
                        <option value="draft">draft</option>
                        <option value="active">active</option>
                        <option value="archived">archived</option>
                      </select>
                    </Field>
                    <Field label="时长（秒）">
                      <input
                        type="number"
                        value={questionDraft.timeLimitSec}
                        onChange={(e) => setQuestionDraft((c) => ({ ...c, timeLimitSec: e.target.value }))}
                        placeholder={configDraft.defaultTimeLimitSec ? `默认 ${configDraft.defaultTimeLimitSec}` : undefined}
                        className={inputCls()}
                      />
                    </Field>
                  </div>

                  {/* stem text */}
                  <Field label="题干">
                    <textarea
                      value={questionDraft.stemText}
                      onChange={(e) => setQuestionDraft((c) => ({ ...c, stemText: e.target.value }))}
                      className={inputCls(true)}
                    />
                  </Field>

                  {/* stem image */}
                  <Field label="题干图片">
                    <QuizImageField
                      imageUrl={questionDraft.stemImageUrl}
                      alt="题干图片"
                      uploadLabel="上传图片"
                      uploading={uploadingTarget === 'stem'}
                      uploadSummary={uploadCompressionByTarget.stem ?? null}
                      onUpload={(e) => void uploadImage(e, 'stem')}
                      onRemove={() => clearImage('stem')}
                      onPreview={() => openImagePreview(questionDraft.stemImageUrl, '题干图片', 'Quiz stem image')}
                      emptyMessage="未上传题干图片"
                    />
                  </Field>

                  {/* row: tags + difficulty */}
                  <div className="grid grid-cols-2 gap-3">
                    <Field label="标签" hint="逗号分隔">
                      <input
                        value={questionDraft.tags}
                        onChange={(e) => setQuestionDraft((c) => ({ ...c, tags: e.target.value }))}
                        className={inputCls()}
                      />
                    </Field>
                    <Field label="难度">
                      <select
                        value={questionDraft.difficulty}
                        onChange={(e) => setQuestionDraft((c) => ({ ...c, difficulty: e.target.value }))}
                        className={selectCls()}
                      >
                        <option value="">不设置</option>
                        <option value="easy">easy</option>
                        <option value="medium">medium</option>
                        <option value="hard">hard</option>
                      </select>
                    </Field>
                  </div>

                  {/* correct option id — read only, subtle */}
                  <div className="flex items-center gap-2 rounded-lg border border-gray-100 bg-gray-50 px-3 py-2">
                    <span className="text-[11px] font-medium text-gray-400 uppercase tracking-wide shrink-0">正确答案</span>
                    <span className="font-mono text-[11px] text-gray-500 truncate">{questionDraft.correctOptionId || '—'}</span>
                  </div>

                  {/* explanation */}
                  <Field label="解释" hint="后台维护，答题中不展示">
                    <textarea
                      value={questionDraft.explanation}
                      onChange={(e) => setQuestionDraft((c) => ({ ...c, explanation: e.target.value }))}
                      placeholder="请输入解释说明"
                      className={inputCls(true)}
                    />
                  </Field>

                  <div className="flex items-center justify-between rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
                    <span className="text-xs text-gray-400">
                      {editorMode === 'edit' && selectedQuestion
                        ? `更新于 ${formatTime(selectedQuestion.updatedAt)}`
                        : '创建后自动进入编辑状态'}
                    </span>
                    <button
                      type="submit"
                      disabled={!canWrite || questionSaving}
                      className="rounded-full bg-gray-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50 hover:bg-gray-800 transition"
                    >
                      {questionSaving ? '保存中...' : editorMode === 'edit' ? '保存' : '创建'}
                    </button>
                  </div>
                </form>
              </div>

              {/* ── col 3: options + preview ── */}
              <div className="flex flex-col gap-4">
                {/* options panel */}
                <div className="rounded-2xl border border-gray-200 bg-white shadow-sm overflow-hidden">
                  <div className="flex items-center justify-between border-b border-gray-100 px-4 py-3">
                    <div>
                      <div className="text-[11px] font-semibold uppercase tracking-widest text-gray-400">选项</div>
                      <div className="mt-0.5 text-xs text-gray-400">2–6 个 · 可文字、图片或图文</div>
                    </div>
                    <button
                      type="button"
                      disabled={questionDraft.options.length >= 6}
                      onClick={() =>
                        setQuestionDraft((c) => ({
                          ...c,
                          options: [...c.options, buildDraftOption(c.options.length)],
                        }))
                      }
                      className="rounded-full border border-gray-200 bg-gray-50 px-3 py-1.5 text-xs font-semibold text-gray-700 hover:bg-gray-100 transition disabled:opacity-50"
                    >
                      + 新增
                    </button>
                  </div>

                  <div className="divide-y divide-gray-100">
                    {questionDraft.options.map((option, index) => {
                      const isCorrect = questionDraft.correctOptionId === option.id;
                      const letter = OPTION_LETTERS[index] || String(index + 1);
                      return (
                        <div key={option.id} className="p-3.5 space-y-2.5">
                          {/* option header */}
                          <div className="flex items-center justify-between">
                            <div className="flex items-center gap-2">
                              <div
                                className={`flex h-6 w-6 items-center justify-center rounded-full text-xs font-bold ${
                                  isCorrect ? 'bg-emerald-500 text-white' : 'border-2 border-gray-300 text-gray-500'
                                }`}
                              >
                                {letter}
                              </div>
                              <IdTooltip id={option.id} />
                              {isCorrect ? (
                                <span className="rounded-full bg-emerald-50 px-2 py-0.5 text-[10px] font-semibold text-emerald-600 border border-emerald-200">
                                  正确答案
                                </span>
                              ) : null}
                            </div>
                            <button
                              type="button"
                              disabled={questionDraft.options.length <= 2}
                              onClick={() =>
                                setQuestionDraft((c) => {
                                  const nextOptions = c.options.filter((o) => o.id !== option.id);
                                  const nextCorrect =
                                    c.correctOptionId === option.id ? nextOptions[0]?.id || '' : c.correctOptionId;
                                  return {
                                    ...c,
                                    correctOptionId: nextCorrect,
                                    options: nextOptions.map((o, i) => ({ ...o, sortOrder: i })),
                                  };
                                })
                              }
                              className="text-xs text-gray-400 hover:text-red-500 transition disabled:opacity-30"
                            >
                              删除
                            </button>
                          </div>

                          {/* text */}
                          <input
                            value={option.text}
                            placeholder={`选项 ${letter} 文本`}
                            onChange={(e) =>
                              setQuestionDraft((c) => ({
                                ...c,
                                options: c.options.map((o) =>
                                  o.id === option.id ? { ...o, text: e.target.value } : o
                                ),
                              }))
                            }
                            className={inputCls()}
                          />

                          {/* image */}
                          <QuizImageField
                            imageUrl={option.imageUrl}
                            alt={option.text || `选项 ${letter}`}
                            uploadLabel="上传图片"
                            uploading={uploadingTarget === option.id}
                            uploadSummary={uploadCompressionByTarget[option.id] ?? null}
                            onUpload={(e) => void uploadImage(e, option.id)}
                            onRemove={() => clearImage(option.id)}
                            onPreview={() =>
                              openImagePreview(
                                option.imageUrl,
                                `选项 ${letter} 图片`,
                                option.text.trim() || `Option ${letter}`
                              )
                            }
                            emptyMessage="未上传图片"
                          />

                          {/* set correct */}
                          {!isCorrect ? (
                            <button
                              type="button"
                              onClick={() => setQuestionDraft((c) => ({ ...c, correctOptionId: option.id }))}
                              className="flex items-center gap-1.5 text-xs text-gray-400 hover:text-emerald-600 transition"
                            >
                              <div className="h-3.5 w-3.5 rounded-full border-2 border-gray-300" />
                              设为正确答案
                            </button>
                          ) : null}
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* preview panel */}
                <div className="rounded-2xl border border-gray-200 bg-white shadow-sm overflow-hidden">
                  <div className="flex items-center justify-between border-b border-gray-100 px-4 py-3">
                    <div>
                      <div className="text-[11px] font-semibold uppercase tracking-widest text-gray-400">预览</div>
                      <div className="mt-0.5 text-xs text-gray-400">实时预览答题展示效果</div>
                    </div>
                    <span className="rounded-full border border-gray-200 bg-gray-50 px-2 py-0.5 text-[10px] text-gray-500">
                      {questionDraft.options.length} 选项
                    </span>
                  </div>

                  <div className="p-4 space-y-3">
                    <div className="text-[15px] font-semibold leading-snug text-gray-900">
                      {questionDraft.stemText.trim() || <span className="text-gray-300">题干预览</span>}
                    </div>

                    {questionDraft.stemImageUrl.trim() ? (
                      <div className="flex">
                        <div className="relative h-48 w-[70%] overflow-hidden rounded-[12px] border border-gray-100 bg-gray-50">
                          <Image
                            src={questionDraft.stemImageUrl.trim()}
                            alt="题干预览"
                            fill
                            className="object-contain"
                            sizes="(max-width: 768px) 100vw, 560px"
                          />
                        </div>
                      </div>
                    ) : null}

                    {usesImageGridPreview(questionDraft.options) ? (
                      <div className="grid grid-cols-2 gap-2">
                        {questionDraft.options.map((option, index) => {
                          const letter = OPTION_LETTERS[index] || String(index + 1);
                          return (
                            <div
                              key={`preview-${option.id}`}
                              className="relative overflow-hidden rounded-[14px] border border-gray-200 bg-gray-50"
                            >
                              {option.imageUrl.trim() ? (
                                <div className="relative h-36 w-full">
                                  <Image
                                    src={option.imageUrl.trim()}
                                    alt={`选项 ${letter}`}
                                    fill
                                    className="object-cover"
                                    sizes="(max-width: 768px) 50vw, 180px"
                                  />
                                </div>
                              ) : (
                                <div className="flex h-36 items-center justify-center text-xs text-gray-400">图片缺失</div>
                              )}
                              <div className="absolute left-2.5 top-2.5 rounded-full bg-black/55 px-1.5 py-0.5 text-[10px] font-bold text-white">
                                {letter}
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    ) : (
                      <div className="space-y-1.5">
                        {questionDraft.options.map((option, index) => {
                          const letter = OPTION_LETTERS[index] || String(index + 1);
                          const isCorrect = questionDraft.correctOptionId === option.id;
                          return (
                            <div
                              key={`preview-${option.id}`}
                              className={`flex items-center gap-3 rounded-xl border px-3 py-2.5 ${
                                isCorrect ? 'border-emerald-200 bg-emerald-50' : 'border-gray-200 bg-gray-50'
                              }`}
                            >
                              <div className={`flex h-5 w-5 flex-shrink-0 items-center justify-center rounded-full border text-[10px] font-bold ${
                                isCorrect ? 'border-emerald-400 bg-emerald-500 text-white' : 'border-gray-300 bg-white text-gray-600'
                              }`}>
                                {letter}
                              </div>
                              <span className="text-[13px] text-gray-700 flex-1">
                                {previewOptionLabel(option.text, option.imageUrl)}
                              </span>
                              {option.imageUrl.trim() ? (
                                <div className="relative ml-auto h-9 w-9 overflow-hidden rounded-lg border border-gray-200 bg-white">
                                  <Image
                                    src={option.imageUrl.trim()}
                                    alt={previewOptionLabel(option.text, option.imageUrl)}
                                    fill
                                    className="object-contain"
                                    sizes="36px"
                                  />
                                </div>
                              ) : null}
                            </div>
                          );
                        })}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>
          ) : null}

          {/* ══ OVERRIDES TAB ══ */}
          {tab === 'overrides' ? (
            <div className="mx-auto max-w-5xl">
              <div className="rounded-2xl border border-gray-200 bg-white shadow-sm">
                <div className="border-b border-gray-100 px-6 py-4">
                  <div className="text-[11px] font-semibold uppercase tracking-widest text-gray-400">User Attempt Overrides</div>
                  <p className="mt-1 text-sm text-gray-500">
                    按用户设置 quiz 次数策略。
                    <code className="mx-1 rounded bg-gray-100 px-1 text-xs">default</code>继承全局；
                    <code className="mx-1 rounded bg-gray-100 px-1 text-xs">custom_limit</code>专属次数；
                    <code className="mx-1 rounded bg-gray-100 px-1 text-xs">unlimited</code>不限次数。
                  </p>
                </div>

                <div className="border-b border-gray-100 px-5 py-3">
                  <form
                    onSubmit={(e) => { e.preventDefault(); setOverridePage(1); setOverrideQuery(overrideQueryInput); }}
                    className="flex gap-2"
                  >
                    <input
                      value={overrideQueryInput}
                      onChange={(e) => setOverrideQueryInput(e.target.value)}
                      placeholder="搜索邮箱 / 用户名 / displayName / userId"
                      className={inputCls() + ' flex-1'}
                    />
                    <button
                      type="submit"
                      className="rounded-lg border border-gray-200 bg-gray-50 px-4 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-100 transition"
                    >
                      搜索
                    </button>
                  </form>
                </div>

                <div className="divide-y divide-gray-100">
                  {overrideLoading ? (
                    <div className="px-6 py-8 text-center text-sm text-gray-400">加载用户覆盖中...</div>
                  ) : overrides.length === 0 ? (
                    <div className="px-6 py-8 text-center text-sm text-gray-400">暂无用户覆盖数据</div>
                  ) : (
                    overrides.map((item) => {
                      const draft = overrideDrafts[item.userId] || {
                        attemptMode: item.attemptMode,
                        dailyAttemptLimitOverride: item.dailyAttemptLimitOverride ? String(item.dailyAttemptLimitOverride) : '',
                        note: item.note || '',
                      };
                      return (
                        <div key={item.id} className="px-5 py-4">
                          <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
                            {/* user info */}
                            <div className="min-w-[200px]">
                              <div className="text-sm font-semibold text-gray-900">
                                {item.user.displayName || item.user.username}
                              </div>
                              <div className="text-sm text-gray-500">{item.user.email}</div>
                              <div className="mt-0.5 flex items-center gap-1.5">
                                <IdTooltip id={item.userId} />
                                <span className="text-[11px] text-gray-400">更新 {formatTime(item.updatedAt)}</span>
                              </div>
                            </div>

                            {/* controls */}
                            <div className="flex flex-1 flex-wrap items-center gap-2">
                              <select
                                value={draft.attemptMode}
                                onChange={(e) =>
                                  setOverrideDrafts((c) => ({
                                    ...c,
                                    [item.userId]: { ...draft, attemptMode: e.target.value as QuizAttemptMode },
                                  }))
                                }
                                className={selectCls() + ' max-w-[150px]'}
                              >
                                <option value="default">default</option>
                                <option value="custom_limit">custom_limit</option>
                                <option value="unlimited">unlimited</option>
                              </select>

                              <input
                                value={draft.dailyAttemptLimitOverride}
                                disabled={draft.attemptMode !== 'custom_limit'}
                                onChange={(e) =>
                                  setOverrideDrafts((c) => ({
                                    ...c,
                                    [item.userId]: { ...draft, dailyAttemptLimitOverride: e.target.value },
                                  }))
                                }
                                placeholder="专属次数"
                                className={inputCls() + ' max-w-[100px]'}
                              />

                              <input
                                value={draft.note}
                                onChange={(e) =>
                                  setOverrideDrafts((c) => ({
                                    ...c,
                                    [item.userId]: { ...draft, note: e.target.value },
                                  }))
                                }
                                placeholder="备注"
                                className={inputCls() + ' flex-1 min-w-[140px]'}
                              />

                              <button
                                type="button"
                                onClick={() => void saveOverride(item.userId)}
                                disabled={!canWrite || overrideSavingUserId === item.userId}
                                className="rounded-lg bg-gray-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50 hover:bg-gray-800 transition"
                              >
                                {overrideSavingUserId === item.userId ? '保存中...' : '保存'}
                              </button>
                            </div>
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>

                {/* pagination */}
                <div className="flex items-center justify-between border-t border-gray-100 px-5 py-3 text-sm text-gray-500">
                  <span>第 {overridePage} / {totalOverridePages} 页 · {overrideTotal} 条</span>
                  <div className="flex gap-1.5">
                    <button
                      type="button"
                      disabled={overridePage <= 1}
                      onClick={() => setOverridePage((p) => Math.max(1, p - 1))}
                      className="rounded-full border border-gray-200 px-3 py-1.5 text-xs hover:bg-gray-50 disabled:opacity-40"
                    >
                      上一页
                    </button>
                    <button
                      type="button"
                      disabled={overridePage >= totalOverridePages}
                      onClick={() => setOverridePage((p) => Math.min(totalOverridePages, p + 1))}
                      className="rounded-full border border-gray-200 px-3 py-1.5 text-xs hover:bg-gray-50 disabled:opacity-40"
                    >
                      下一页
                    </button>
                  </div>
                </div>
              </div>
            </div>
          ) : null}
        </div>
      </div>

      <QuizImportOverlay
        open={showImportOverlay}
        value={importText}
        importing={importingQuestions}
        feedback={importFeedback}
        onOpenRules={() => setShowImportRulesOverlay(true)}
        onChange={setImportText}
        onClose={() => {
          setShowImportOverlay(false);
          setImportFeedback(null);
        }}
        onFillExample={() => setImportText(QUIZ_IMPORT_EXAMPLE)}
        onSubmit={submitImportQuestions}
      />
      <QuizImportRulesOverlay
        open={showImportRulesOverlay}
        onClose={() => setShowImportRulesOverlay(false)}
      />
      <QuizDeleteConfirmOverlay
        open={showBulkDeleteConfirm}
        count={selectedQuestionIds.length}
        deleting={bulkDeletingQuestions}
        onClose={() => setShowBulkDeleteConfirm(false)}
        onConfirm={() => void deleteSelectedQuestions()}
      />
      <OverlayImageViewer
        assets={imagePreviewAssets}
        activeIndex={imagePreviewIndex}
        onClose={() => {
          setImagePreviewIndex(null);
          setImagePreviewAssets([]);
        }}
        onChange={setImagePreviewIndex}
      />
    </AdminAppShell>
  );
}
