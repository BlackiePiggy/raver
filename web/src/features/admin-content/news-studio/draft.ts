import { NewsStudioBindingItem, NewsStudioDraft, NewsStudioLoadedArticle } from './types';

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

const fromIds = (items?: string[] | null): NewsStudioBindingItem[] =>
  (items || [])
    .filter(Boolean)
    .map((id) => ({
      id,
      name: id,
    }));

const toIdText = (items?: string[] | null): string => (items || []).filter(Boolean).join(', ');

export const extractMarkdownImageUrls = (body: string): string[] => {
  const source = String(body || '');
  const regex = /!\[[^\]]*\]\((https?:\/\/[^\s)]+)\)/g;
  const urls: string[] = [];
  let match: RegExpExecArray | null = regex.exec(source);
  while (match) {
    const url = String(match[1] || '').trim();
    if (url) urls.push(url);
    match = regex.exec(source);
  }
  return Array.from(new Set(urls));
};

export const createNewsUploadDraftKey = (): string =>
  `news-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;

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
  bodyImageUrls: [],
  uploadNewsKey: createNewsUploadDraftKey(),
  sessionUploadedResources: [],
  boundDjs: [],
  boundBrands: [],
  boundEvents: [],
});

export const hydrateNewsStudioDraftFromArticle = (
  article: NewsStudioLoadedArticle
): NewsStudioDraft => {
  const bodyImageUrls = extractMarkdownImageUrls(article.body || '').filter(
    (url) => url !== String(article.coverImageURL || '').trim()
  );

  return {
    id: article.id,
    title: article.title || '',
    summary: article.summary || '',
    body: article.body || '',
    source: article.source || 'Raver',
    category: article.category || 'community',
    link: article.link || '',
    coverImageUrl: article.coverImageURL || '',
    publishedAt: toDateTimeLocal(article.publishedAt),
    boundDjIdsText: toIdText(article.boundDjIDs),
    boundBrandIdsText: toIdText(article.boundBrandIDs),
    boundEventIdsText: toIdText(article.boundEventIDs),
    bodyImageUrls,
    uploadNewsKey: createNewsUploadDraftKey(),
    sessionUploadedResources: [],
    boundDjs: fromIds(article.boundDjIDs),
    boundBrands: fromIds(article.boundBrandIDs),
    boundEvents: fromIds(article.boundEventIDs),
  };
};
