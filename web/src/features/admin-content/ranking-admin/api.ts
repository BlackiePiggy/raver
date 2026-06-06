import { authenticatedFetch, authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import { uploadMediaWithFetcher } from '@/lib/api/upload-media';

export type RankingEntityType = 'dj' | 'festival';

export type RankingBoardSummary = {
  id: string;
  title: string;
  subtitle: string;
  description: string;
  coverImageUrl: string | null;
  years: number[];
  entityType: RankingEntityType;
  createdAt: string;
  updatedAt: string;
};

export type RankingBoardEntry = {
  rank: number;
  name: string;
  entityId?: string | null;
};

export type RankingBoardDetailEntry = {
  rank: number;
  name: string;
  entityId: string | null;
  delta: number | null;
  dj: RankingBoundDJ | null;
  festival: RankingBoundFestival | null;
};

export type RankingBoundDJ = {
  id: string;
  name: string;
  slug?: string | null;
  avatarUrl?: string | null;
  bannerUrl?: string | null;
  followerCount?: number | null;
  country?: string | null;
};

export type RankingBoundFestival = {
  id: string;
  name: string;
  avatarUrl?: string | null;
  backgroundUrl?: string | null;
  country?: string | null;
  city?: string | null;
  tagline?: string | null;
};

export type RankingBoardDetail = {
  boardId: string;
  title: string;
  subtitle: string;
  description: string;
  coverImageUrl: string | null;
  entityType: RankingEntityType;
  years: number[];
  year: number | null;
  strictEntityBinding?: boolean;
  entries: RankingBoardDetailEntry[];
};

export type RankingAutoMatchCandidate = {
  id: string;
  name: string;
  subtitle?: string | null;
  imageUrl?: string | null;
};

export type RankingAutoMatchStatus = 'already_bound' | 'matched' | 'ambiguous' | 'unmatched';

export type RankingAutoMatchPreviewItem = {
  rank: number;
  name: string;
  currentEntityId: string | null;
  status: RankingAutoMatchStatus;
  current?: RankingAutoMatchCandidate | null;
  suggested?: RankingAutoMatchCandidate | null;
  candidates: RankingAutoMatchCandidate[];
};

export type RankingAutoMatchPreview = {
  boardId: string;
  year: number;
  entityType: RankingEntityType;
  total: number;
  alreadyBoundCount: number;
  matchedCount: number;
  ambiguousCount: number;
  unmatchedCount: number;
  items: RankingAutoMatchPreviewItem[];
};

export type RankingBoardInput = {
  id?: string;
  title: string;
  subtitle?: string;
  description?: string;
  coverImageUrl?: string | null;
  entityType: RankingEntityType;
  years?: number[];
  year?: number | null;
  importText?: string;
  entries?: RankingBoardEntry[];
};

export type RankingYearUpsertInput = {
  importText?: string;
  entries?: RankingBoardEntry[];
};

export type RankingBindingUpdateInput = {
  entityId: string | null;
};

type Envelope<T> = {
  data: T;
};

export const rankingAdminApi = {
  async listBoards(): Promise<RankingBoardSummary[]> {
    const payload = await authenticatedJsonFetch<Envelope<RankingBoardSummary[]>>(getApiUrl('/v1/learn/rankings'));
    return payload.data;
  },

  async fetchBoard(boardId: string, year?: number | null): Promise<RankingBoardDetail> {
    const query = year ? `?year=${encodeURIComponent(String(year))}` : '';
    const payload = await authenticatedJsonFetch<Envelope<RankingBoardDetail>>(
      getApiUrl(`/v1/learn/rankings/${encodeURIComponent(boardId)}${query}`)
    );
    return payload.data;
  },

  async createBoard(input: RankingBoardInput): Promise<RankingBoardSummary> {
    const payload = await authenticatedJsonFetch<Envelope<RankingBoardSummary>>(getApiUrl('/v1/learn/rankings'), {
      method: 'POST',
      body: JSON.stringify(input),
    });
    return payload.data;
  },

  async updateBoard(boardId: string, input: Partial<RankingBoardInput>): Promise<RankingBoardSummary> {
    const payload = await authenticatedJsonFetch<Envelope<RankingBoardSummary>>(
      getApiUrl(`/v1/learn/rankings/${encodeURIComponent(boardId)}`),
      {
        method: 'PATCH',
        body: JSON.stringify(input),
      }
    );
    return payload.data;
  },

  async upsertYear(boardId: string, year: number, input: RankingYearUpsertInput): Promise<{
    boardId: string;
    year: number;
    count: number;
    years: number[];
  }> {
    const payload = await authenticatedJsonFetch<
      Envelope<{ boardId: string; year: number; count: number; years: number[] }>
    >(
      getApiUrl(`/v1/learn/rankings/${encodeURIComponent(boardId)}/years/${encodeURIComponent(String(year))}/upsert`),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
    return payload.data;
  },

  async previewAutoMatch(boardId: string, year: number): Promise<RankingAutoMatchPreview> {
    const payload = await authenticatedJsonFetch<Envelope<RankingAutoMatchPreview>>(
      getApiUrl(`/v1/learn/rankings/${encodeURIComponent(boardId)}/years/${encodeURIComponent(String(year))}/auto-match-preview`)
    );
    return payload.data;
  },

  async applyAutoMatch(boardId: string, year: number): Promise<RankingAutoMatchPreview> {
    const payload = await authenticatedJsonFetch<Envelope<RankingAutoMatchPreview>>(
      getApiUrl(`/v1/learn/rankings/${encodeURIComponent(boardId)}/years/${encodeURIComponent(String(year))}/auto-match-apply`),
      {
        method: 'POST',
      }
    );
    return payload.data;
  },

  async updateEntryBinding(
    boardId: string,
    year: number,
    rank: number,
    input: RankingBindingUpdateInput
  ): Promise<RankingBoardDetailEntry> {
    const payload = await authenticatedJsonFetch<Envelope<RankingBoardDetailEntry>>(
      getApiUrl(
        `/v1/learn/rankings/${encodeURIComponent(boardId)}/years/${encodeURIComponent(String(year))}/entries/${encodeURIComponent(String(rank))}/binding`
      ),
      {
        method: 'PATCH',
        body: JSON.stringify(input),
      }
    );
    return payload.data;
  },

  async uploadImage(file: File, boardId: string): Promise<{ url: string; originalUrl?: string | null; fileName?: string | null }> {
    return uploadMediaWithFetcher({
      url: getApiUrl('/v1/learn/rankings/upload-image'),
      file,
      fields: { boardId },
      fallbackError: '榜单图片上传失败',
      invalidResponseError: '榜单图片上传成功，但未返回有效图片地址',
    });
  },

  async deleteBoard(boardId: string): Promise<void> {
    await authenticatedJsonFetch<Envelope<{ success: true }>>(getApiUrl(`/v1/learn/rankings/${encodeURIComponent(boardId)}`), {
      method: 'DELETE',
    });
  },
};
