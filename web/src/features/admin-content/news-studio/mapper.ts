import { NewsStudioCreateInput, NewsStudioDraft } from './types';

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
  title: draft.title.trim(),
  summary: draft.summary.trim(),
  body: draft.body.trim(),
  source: draft.source.trim() || 'Raver',
  category: draft.category,
  link: draft.link.trim() || null,
  coverImageURL: draft.coverImageUrl.trim() || null,
  publishedAt: toIsoStringOrNull(draft.publishedAt),
  boundDjIDs: resolveBindingIds(draft.boundDjs, draft.boundDjIdsText),
  boundBrandIDs: resolveBindingIds(draft.boundBrands, draft.boundBrandIdsText),
  boundEventIDs: resolveBindingIds(draft.boundEvents, draft.boundEventIdsText),
});
