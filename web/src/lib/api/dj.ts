const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api';

export interface DJ {
  id: string;
  name: string;
  slug: string;
  bio: string | null;
  avatarUrl: string | null;
  bannerUrl: string | null;
  country: string | null;
  spotifyId: string | null;
  appleMusicId: string | null;
  soundcloudUrl: string | null;
  instagramUrl: string | null;
  twitterUrl: string | null;
  isVerified: boolean;
  followerCount: number;
  lastSyncedAt?: string | null;
  spotify?: {
    id: string;
    name: string;
    uri: string;
    url: string | null;
    popularity: number;
    followers: number;
    genres: string[];
    imageUrl: string | null;
  } | null;
  createdAt: string;
  updatedAt: string;
}

export interface DJsResponse {
  djs: DJ[];
  live?: boolean;
  refresh?: boolean;
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface DJFilters {
  page?: number;
  limit?: number;
  search?: string;
  country?: string;
  sortBy?: 'followerCount' | 'name' | 'createdAt';
  live?: boolean;
  refresh?: boolean;
}

class DJAPI {
  private getHeaders(token?: string) {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    return headers;
  }

  async getDJs(filters?: DJFilters): Promise<DJsResponse> {
    const params = new URLSearchParams();
    if (filters) {
      Object.entries(filters).forEach(([key, value]) => {
        if (value !== undefined) {
          params.append(key, value.toString());
        }
      });
    }

    const response = await fetch(`${API_URL}/djs?${params.toString()}`);

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to fetch DJs');
    }

    return response.json();
  }

  async getDJ(id: string): Promise<DJ> {
    const response = await fetch(`${API_URL}/djs/${id}`);

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to fetch DJ');
    }

    return response.json();
  }

  async createDJ(data: Partial<DJ>, token: string): Promise<DJ> {
    const response = await fetch(`${API_URL}/djs`, {
      method: 'POST',
      headers: this.getHeaders(token),
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to create DJ');
    }

    return response.json();
  }
}

export const djAPI = new DJAPI();
