const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3901/api';

export interface Follow {
  id: string;
  followerId: string;
  followingId: string | null;
  djId: string | null;
  type: 'user' | 'dj';
  createdAt: string;
  dj?: any;
}

export interface FollowsResponse {
  follows: Follow[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

class FollowAPI {
  private getHeaders(token?: string) {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    return headers;
  }

  async followDJ(djId: string, token: string): Promise<Follow> {
    const response = await fetch(`${API_URL}/follows/dj`, {
      method: 'POST',
      headers: this.getHeaders(token),
      body: JSON.stringify({ djId }),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to follow DJ');
    }

    return response.json();
  }

  async unfollowDJ(djId: string, token: string): Promise<void> {
    const response = await fetch(`${API_URL}/follows/dj/${djId}`, {
      method: 'DELETE',
      headers: this.getHeaders(token),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to unfollow DJ');
    }
  }

  async getMyFollowedDJs(token: string, page = 1): Promise<FollowsResponse> {
    const response = await fetch(`${API_URL}/follows/my/djs?page=${page}`, {
      headers: this.getHeaders(token),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to fetch followed DJs');
    }

    return response.json();
  }

  async checkFollowStatus(djId: string, token: string): Promise<{ isFollowing: boolean }> {
    const response = await fetch(`${API_URL}/follows/dj/${djId}/status`, {
      headers: this.getHeaders(token),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to check follow status');
    }

    return response.json();
  }
}

export const followAPI = new FollowAPI();
