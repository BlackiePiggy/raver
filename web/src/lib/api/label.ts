import { getApiUrl } from '@/lib/config';

export interface LabelRecord {
  id: string;
  name: string;
  slug: string;
  profileUrl: string;
  profileSlug: string | null;
  avatarUrl: string | null;
  backgroundUrl: string | null;
  nation: string | null;
  soundcloudFollowers: number | null;
  likes: number | null;
  genres: string[];
  genresPreview: string | null;
  latestReleaseListing: string | null;
  locationPeriod: string | null;
  introduction: string | null;
  facebookUrl: string | null;
  soundcloudUrl: string | null;
  musicPurchaseUrl: string | null;
  officialWebsiteUrl: string | null;
}

export interface LabelListResponse {
  labels: LabelRecord[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface LabelListFilters {
  page?: number;
  limit?: number;
  sortBy?: 'soundcloudFollowers' | 'likes' | 'name' | 'nation' | 'latestRelease' | 'createdAt';
  order?: 'asc' | 'desc';
  search?: string;
  nation?: string;
  genre?: string;
}

export const labelAPI = {
  async getLabels(filters: LabelListFilters = {}): Promise<LabelListResponse> {
    const params = new URLSearchParams();
    Object.entries(filters).forEach(([key, value]) => {
      if (value === undefined || value === null || value === '') return;
      params.set(key, String(value));
    });

    const suffix = params.toString() ? `?${params.toString()}` : '';
    const response = await fetch(getApiUrl(`/labels${suffix}`));

    if (!response.ok) {
      const payload = await response.json().catch(() => ({}));
      throw new Error(payload.error || '加载厂牌失败');
    }

    return response.json();
  },
};
