const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api';

export interface Event {
  id: string;
  name: string;
  slug: string;
  organizerId: string | null;
  organizerName: string | null;
  description: string | null;
  coverImageUrl: string | null;
  lineupImageUrl: string | null;
  eventType: string | null;
  venueName: string | null;
  venueAddress: string | null;
  city: string | null;
  country: string | null;
  latitude: number | null;
  longitude: number | null;
  startDate: string;
  endDate: string;
  ticketUrl: string | null;
  ticketPriceMin: number | null;
  ticketPriceMax: number | null;
  ticketCurrency: string | null;
  ticketNotes: string | null;
  ticketTiers?: Array<{
    id?: string;
    name: string;
    price: number;
    currency?: string | null;
    sortOrder?: number;
  }>;
  officialWebsite: string | null;
  status: string;
  isVerified: boolean;
  createdAt: string;
  updatedAt: string;
  lineupSlots?: EventLineupSlot[];
  organizer?: {
    id: string;
    username: string;
    displayName: string | null;
    avatarUrl: string | null;
  } | null;
}

export interface EventLineupSlot {
  id?: string;
  eventId?: string;
  djId?: string | null;
  djName: string;
  stageName?: string | null;
  sortOrder?: number;
  startTime: string;
  endTime: string;
  dj?: {
    id: string;
    name: string;
    avatarUrl?: string | null;
    bannerUrl?: string | null;
    country?: string | null;
  } | null;
}

export interface EventsResponse {
  events: Event[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface EventFilters {
  page?: number;
  limit?: number;
  search?: string;
  city?: string;
  country?: string;
  eventType?: string;
  status?: string;
}

class EventAPI {
  private getHeaders(token?: string) {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    return headers;
  }

  async getEvents(filters?: EventFilters): Promise<EventsResponse> {
    const params = new URLSearchParams();
    if (filters) {
      Object.entries(filters).forEach(([key, value]) => {
        if (value !== undefined) {
          params.append(key, value.toString());
        }
      });
    }

    const response = await fetch(`${API_URL}/events?${params.toString()}`);

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to fetch events');
    }

    return response.json();
  }

  async getEvent(id: string): Promise<Event> {
    const response = await fetch(`${API_URL}/events/${id}`);

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to fetch event');
    }

    return response.json();
  }

  async createEvent(data: Partial<Event>, token: string): Promise<Event> {
    const response = await fetch(`${API_URL}/events`, {
      method: 'POST',
      headers: this.getHeaders(token),
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to create event');
    }

    return response.json();
  }

  async getMyEvents(token: string): Promise<{ events: Event[] }> {
    const response = await fetch(`${API_URL}/events/mine`, {
      headers: this.getHeaders(token),
    });
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.error || 'Failed to fetch my events');
    }
    return response.json();
  }

  async updateEvent(id: string, data: Partial<Event>, token: string): Promise<Event> {
    const response = await fetch(`${API_URL}/events/${id}`, {
      method: 'PUT',
      headers: this.getHeaders(token),
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to update event');
    }

    return response.json();
  }

  async uploadImage(file: File, token: string): Promise<{ url: string }> {
    const formData = new FormData();
    formData.append('image', file);

    const headers: HeadersInit = {};
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const response = await fetch(`${API_URL}/events/upload-image`, {
      method: 'POST',
      headers,
      body: formData,
    });
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.error || 'Failed to upload image');
    }
    return response.json();
  }
}

export const eventAPI = new EventAPI();
