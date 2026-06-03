export type NewsStudioCategory = 'festival' | 'scene' | 'gear' | 'industry' | 'community';

export type NewsStudioBindingItem = {
  id: string;
  name: string;
  subtitle?: string | null;
  imageUrl?: string | null;
};

export type NewsStudioDraft = {
  id: string;
  title: string;
  summary: string;
  body: string;
  source: string;
  category: NewsStudioCategory;
  link: string;
  coverImageUrl: string;
  publishedAt: string;
  boundDjIdsText: string;
  boundBrandIdsText: string;
  boundEventIdsText: string;
  bodyImageUrls: string[];
  uploadNewsKey: string;
  sessionUploadedResources: string[];
  boundDjs: NewsStudioBindingItem[];
  boundBrands: NewsStudioBindingItem[];
  boundEvents: NewsStudioBindingItem[];
};

export type NewsStudioValidationErrors = Partial<Record<'title' | 'body', string>>;

export type NewsStudioLoadedArticle = {
  id: string;
  category: NewsStudioCategory;
  source: string;
  title: string;
  summary: string;
  body: string;
  link: string | null;
  coverImageURL: string | null;
  publishedAt: string;
  boundDjIDs: string[];
  boundBrandIDs: string[];
  boundEventIDs: string[];
};

export type NewsStudioCreateInput = {
  title: string;
  summary: string;
  body: string;
  source: string;
  category: NewsStudioCategory;
  link?: string | null;
  coverImageURL?: string | null;
  publishedAt?: string | null;
  boundDjIDs?: string[];
  boundBrandIDs?: string[];
  boundEventIDs?: string[];
};

export type NewsStudioCreatedArticle = {
  id: string;
  title: string;
  publishedAt: string;
};

export type NewsStudioCreateResult = {
  kind: 'created';
  article: NewsStudioCreatedArticle;
};
