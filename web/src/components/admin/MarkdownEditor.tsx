'use client';

import { useMemo, type Ref } from 'react';

type MarkdownEditorProps = {
  label?: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  minHeightClassName?: string;
  error?: string;
  textareaRef?: Ref<HTMLTextAreaElement>;
};

const normalizeHttpUrl = (raw: string): string => {
  const text = raw.trim();
  return /^https?:\/\//i.test(text) ? text : '';
};

const escapeHtml = (value: string): string =>
  value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const renderInline = (rawText: string): string => {
  let text = escapeHtml(rawText);
  text = text.replace(/!\[([^\]]*)\]\((https?:\/\/[^\s)]+)\)/g, (_match, alt, url) => {
    const safe = normalizeHttpUrl(url);
    if (!safe) return '';
    return `<img src="${escapeHtml(safe)}" alt="${escapeHtml(alt || '')}" loading="lazy" />`;
  });
  text = text.replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, (_match, label, url) => {
    const safe = normalizeHttpUrl(url);
    if (!safe) return escapeHtml(label || '');
    return `<a href="${escapeHtml(safe)}" target="_blank" rel="noopener noreferrer">${escapeHtml(label || safe)}</a>`;
  });
  text = text.replace(/`([^`]+)`/g, '<code>$1</code>');
  text = text.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  text = text.replace(/\*([^*]+)\*/g, '<em>$1</em>');
  return text;
};

export const renderMarkdownHtml = (markdownText: string): string => {
  const src = String(markdownText || '').replace(/\r\n/g, '\n');
  if (!src.trim()) return '<p style="color:#6b7280;">暂无正文预览</p>';

  const lines = src.split('\n');
  const out: string[] = [];
  let inCode = false;
  let codeLines: string[] = [];
  let listType = '';
  let paragraph: string[] = [];

  const flushParagraph = () => {
    if (!paragraph.length) return;
    out.push(`<p>${renderInline(paragraph.join(' '))}</p>`);
    paragraph = [];
  };

  const flushList = () => {
    if (!listType) return;
    out.push(`</${listType}>`);
    listType = '';
  };

  for (const rawLine of lines) {
    const line = String(rawLine || '');
    const trimmed = line.trim();

    if (trimmed.startsWith('```')) {
      flushParagraph();
      flushList();
      if (!inCode) {
        inCode = true;
        codeLines = [];
      } else {
        out.push(`<pre><code>${escapeHtml(codeLines.join('\n'))}</code></pre>`);
        inCode = false;
        codeLines = [];
      }
      continue;
    }

    if (inCode) {
      codeLines.push(line);
      continue;
    }

    if (!trimmed) {
      flushParagraph();
      flushList();
      continue;
    }

    const heading = trimmed.match(/^(#{1,6})\s+(.+)$/);
    if (heading) {
      flushParagraph();
      flushList();
      const level = Math.min(6, Math.max(1, heading[1].length));
      out.push(`<h${level}>${renderInline(heading[2])}</h${level}>`);
      continue;
    }

    if (/^---+$/.test(trimmed)) {
      flushParagraph();
      flushList();
      out.push('<hr />');
      continue;
    }

    const quote = trimmed.match(/^>\s?(.*)$/);
    if (quote) {
      flushParagraph();
      flushList();
      out.push(`<blockquote>${renderInline(quote[1] || '')}</blockquote>`);
      continue;
    }

    const ul = trimmed.match(/^[-*]\s+(.+)$/);
    if (ul) {
      flushParagraph();
      if (!listType) {
        listType = 'ul';
        out.push('<ul>');
      } else if (listType !== 'ul') {
        flushList();
        listType = 'ul';
        out.push('<ul>');
      }
      out.push(`<li>${renderInline(ul[1])}</li>`);
      continue;
    }

    const ol = trimmed.match(/^\d+\.\s+(.+)$/);
    if (ol) {
      flushParagraph();
      if (!listType) {
        listType = 'ol';
        out.push('<ol>');
      } else if (listType !== 'ol') {
        flushList();
        listType = 'ol';
        out.push('<ol>');
      }
      out.push(`<li>${renderInline(ol[1])}</li>`);
      continue;
    }

    flushList();
    paragraph.push(trimmed);
  }

  if (inCode) {
    out.push(`<pre><code>${escapeHtml(codeLines.join('\n'))}</code></pre>`);
  }

  flushParagraph();
  flushList();
  return out.join('');
};

export default function MarkdownEditor({
  label = 'Markdown',
  value,
  onChange,
  placeholder,
  minHeightClassName = 'min-h-[360px]',
  error,
  textareaRef,
}: MarkdownEditorProps) {
  const previewHtml = useMemo(() => renderMarkdownHtml(value), [value]);

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between gap-3">
        <div className="admin-studio-label">{label}</div>
        <div className="text-xs text-black/45">支持标题、列表、引用、链接、图片与代码块</div>
      </div>

      <div className="grid gap-4 xl:grid-cols-2">
        <textarea
          ref={textareaRef}
          value={value}
          onChange={(event) => onChange(event.target.value)}
          className={`admin-studio-textarea ${minHeightClassName}`}
          placeholder={placeholder}
        />

        <div className={`overflow-hidden rounded-[24px] border border-[#e8eceb] bg-white ${minHeightClassName}`}>
          <div className="border-b border-[#edf0f2] px-4 py-3 text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">
            Preview
          </div>
          <div
            className="prose prose-sm max-w-none px-5 py-4 text-[#111827] prose-headings:text-[#111827] prose-p:text-[#374151] prose-a:text-[#0f766e] prose-strong:text-[#111827] prose-code:text-[#7c2d12] prose-pre:bg-[#0f172a] prose-pre:text-white prose-blockquote:text-[#4b5563] prose-img:rounded-[16px]"
            dangerouslySetInnerHTML={{ __html: previewHtml }}
          />
        </div>
      </div>

      {error ? <div className="text-xs text-[#6a3530]">{error}</div> : null}
    </div>
  );
}
