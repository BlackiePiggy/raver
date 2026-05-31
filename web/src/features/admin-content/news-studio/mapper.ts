import { NewsStudioCreateInput, NewsStudioDraft } from './types';

const parseIdText = (value: string): string[] =>
  value
    .split(/[\n,]/)
    .map((item) => item.trim())
    .filter(Boolean);

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
  boundDjIDs: parseIdText(draft.boundDjIdsText),
  boundBrandIDs: parseIdText(draft.boundBrandIdsText),
  boundEventIDs: parseIdText(draft.boundEventIdsText),
});
