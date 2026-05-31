import { NewsStudioDraft, NewsStudioLoadedArticle } from './types';

const toDateTimeLocal = (value?: string | null): string => {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hour = String(date.getHours()).padStart(2, '0');
  const minute = String(date.getMinutes()).padStart(2, '0');
  return `${year}-${month}-${day}T${hour}:${minute}`;
};

const fromIds = (items?: string[] | null): string => (items || []).filter(Boolean).join(', ');

export const createNewsStudioDraft = (): NewsStudioDraft => ({
  id: crypto.randomUUID(),
  title: '',
  summary: '',
  body: '',
  source: 'Raver',
  category: 'community',
  link: '',
  coverImageUrl: '',
  publishedAt: '',
  boundDjIdsText: '',
  boundBrandIdsText: '',
  boundEventIdsText: '',
});

export const hydrateNewsStudioDraftFromArticle = (
  article: NewsStudioLoadedArticle
): NewsStudioDraft => ({
  id: article.id,
  title: article.title || '',
  summary: article.summary || '',
  body: article.body || '',
  source: article.source || 'Raver',
  category: article.category || 'community',
  link: article.link || '',
  coverImageUrl: article.coverImageURL || '',
  publishedAt: toDateTimeLocal(article.publishedAt),
  boundDjIdsText: fromIds(article.boundDjIDs),
  boundBrandIdsText: fromIds(article.boundBrandIDs),
  boundEventIdsText: fromIds(article.boundEventIDs),
});
