import { NewsStudioCreateInput, NewsStudioDraft } from './types';
import { INPUT_LIMITS, normalizeMultiline, normalizeSingleLine } from '@/lib/input-rules';

const parseIdText = (value: string): string[] =>
  value
    .split(/[\n,]/)
    .map((item) => item.trim())
    .filter(Boolean);

const mapBindingIds = (items: NewsStudioDraft['boundDjs']): string[] =>
  items
    .map((item) => String(item.id || '').trim())
    .filter(Boolean);

const resolveBindingIds = (
  items: NewsStudioDraft['boundDjs'],
  legacyText: string
): string[] => {
  const next = mapBindingIds(items);
  return next.length ? next : parseIdText(legacyText);
};

const toIsoStringOrNull = (value: string): string | null => {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const date = new Date(trimmed);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
};

export const mapNewsStudioDraftToCreateInput = (
  draft: NewsStudioDraft
): NewsStudioCreateInput => ({
  title: normalizeSingleLine(draft.title).slice(0, INPUT_LIMITS.news.title),
  summary: normalizeMultiline(draft.summary).slice(0, INPUT_LIMITS.news.summary),
  body: normalizeMultiline(draft.body).slice(0, INPUT_LIMITS.news.body),
  source: normalizeSingleLine(draft.source).slice(0, INPUT_LIMITS.news.source) || 'Raver',
  category: draft.category,
  link: draft.link.trim() || null,
  coverImageURL: draft.coverImageUrl.trim() || null,
  publishedAt: toIsoStringOrNull(draft.publishedAt),
  boundDjIDs: resolveBindingIds(draft.boundDjs, draft.boundDjIdsText),
  boundBrandIDs: resolveBindingIds(draft.boundBrands, draft.boundBrandIdsText),
  boundEventIDs: resolveBindingIds(draft.boundEvents, draft.boundEventIdsText),
});
