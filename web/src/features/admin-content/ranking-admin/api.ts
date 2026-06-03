import { authenticatedFetch, authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';

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
  dj: Record<string, unknown> | null;
  festival: Record<string, unknown> | null;
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

  async uploadImage(file: File, boardId: string): Promise<{ url: string; originalUrl?: string | null; fileName?: string | null }> {
    const formData = new FormData();
    formData.append('image', file);
    formData.append('boardId', boardId);

    const response = await authenticatedFetch(getApiUrl('/v1/learn/rankings/upload-image'), {
      method: 'POST',
      body: formData,
      headers: {},
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error((error as { error?: string }).error || '榜单图片上传失败');
    }

    return response.json();
  },

  async deleteBoard(boardId: string): Promise<void> {
    await authenticatedJsonFetch<Envelope<{ success: true }>>(getApiUrl(`/v1/learn/rankings/${encodeURIComponent(boardId)}`), {
      method: 'DELETE',
    });
  },
};
