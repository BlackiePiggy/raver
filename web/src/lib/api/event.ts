import { uploadMediaWithFetcher } from '@/lib/api/upload-media';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3901/api';

export type EventDerivedStatus = 'upcoming' | 'ongoing' | 'ended' | 'cancelled';
export type EventVisibility = 'visible' | 'hidden';
export type EventStatusFilter = EventDerivedStatus;

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
  timeZone?: string | null;
  dayRolloverHour?: number | null;
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
  status: EventDerivedStatus;
  isCancelled?: boolean | null;
  visibility?: EventVisibility | null;
  isVerified: boolean;
  createdAt: string;
  updatedAt: string;
  schedule?: {
    mode?: string | null;
    timeZone?: string | null;
    dayRolloverHour?: number | null;
  } | null;
  eventDays?: Array<{
    id?: string;
    eventDayId: string;
    weekIndex: number;
    dayIndexInWeek: number;
    overallDayIndex: number;
    label?: string | null;
    weekday?: string | null;
    date: string;
    sortOrder?: number;
  }>;
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
  eventDayId?: string | null;
  weekIndex?: number | null;
  dayIndexInWeek?: number | null;
  overallDayIndex?: number | null;
  localDate?: string | null;
  djId?: string | null;
  festivalDayIndex?: number | null;
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
  status?: EventStatusFilter;
}

export interface EventTimezoneLookupItem {
  city: string;
  cityAscii: string;
  province: string;
  exactProvince: string;
  stateAnsi: string;
  country: string;
  iso2: string;
  iso3: string;
  timezone: string;
  lat: number | null;
  lng: number | null;
  population: number | null;
  label: string;
  matchSource?: string;
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

  /**
   * @deprecated Legacy event mutation path. Use `eventStudioApi.createEvent` with generated Event contract input.
   */
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

  async searchEventTimezones(query: string, token?: string): Promise<EventTimezoneLookupItem[]> {
    const params = new URLSearchParams({
      q: query.trim(),
      limit: '8',
    });
    const response = await fetch(`${API_URL}/events/timezones/search?${params.toString()}`, {
      headers: this.getHeaders(token),
    });
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.error || 'Failed to search event timezones');
    }
    const data = await response.json();
    return Array.isArray(data?.items) ? data.items : [];
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

  /**
   * @deprecated Legacy event mutation path. Use `eventStudioApi.updateEvent` with generated Event contract input.
   */
  async updateEvent(id: string, data: Partial<Event>, token: string): Promise<Event> {
    const response = await fetch(`${API_URL}/events/${id}`, {
      method: 'PATCH',
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
    return uploadMediaWithFetcher({
      url: `${API_URL}/events/upload-image`,
      file,
      fetcher: (input, init) => fetch(input, {
        ...init,
        headers: {
          ...(init?.headers || {}),
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      }),
      fallbackError: 'Failed to upload image',
      invalidResponseError: 'Upload succeeded but no valid image URL was returned',
    });
  }
}

export const eventAPI = new EventAPI();
