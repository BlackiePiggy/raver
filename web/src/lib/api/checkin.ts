const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3901/api';

export interface Checkin {
  id: string;
  userId: string;
  eventId: string | null;
  djId: string | null;
  type: 'event' | 'dj';
  note: string | null;
  photoUrl: string | null;
  rating: number | null;
  attendedAt: string;
  createdAt: string;
  user?: {
    id: string;
    username: string;
    displayName: string | null;
    avatarUrl: string | null;
  };
  event?: any;
  dj?: any;
}

export interface CheckinsResponse {
  checkins: Checkin[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface CreateCheckinData {
  eventId?: string;
  djId?: string;
  type: 'event' | 'dj';
  note?: string;
  photoUrl?: string;
  rating?: number;
  attendedAt?: string;
}

class CheckinAPI {
  private getHeaders(token?: string) {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    return headers;
  }

  async createCheckin(data: CreateCheckinData, token: string): Promise<Checkin> {
    const response = await fetch(`${API_URL}/checkins`, {
      method: 'POST',
      headers: this.getHeaders(token),
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to create checkin');
    }

    return response.json();
  }

  async getMyCheckins(token: string, page = 1, type?: 'event' | 'dj'): Promise<CheckinsResponse> {
    const params = new URLSearchParams({ page: page.toString() });
    if (type) {
      params.append('type', type);
    }

    const response = await fetch(`${API_URL}/checkins/my?${params.toString()}`, {
      headers: this.getHeaders(token),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to fetch checkins');
    }

    return response.json();
  }

  async deleteCheckin(id: string, token: string): Promise<void> {
    const response = await fetch(`${API_URL}/checkins/${id}`, {
      method: 'DELETE',
      headers: this.getHeaders(token),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to delete checkin');
    }
  }
}

export const checkinAPI = new CheckinAPI();
