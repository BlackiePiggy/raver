import { getApiUrl } from './config';

export class DJSetAPI {
  static async createDJSet(data: {
    djId: string;
    title: string;
    videoUrl: string;
    description?: string;
    recordedAt?: string;
    venue?: string;
    eventName?: string;
  }) {
    const response = await fetch(getApiUrl('/dj-sets'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    if (!response.ok) throw new Error('Failed to create DJ set');
    return response.json();
  }

  static async getDJSet(id: string) {
    const response = await fetch(getApiUrl(`/dj-sets/${id}`));
    if (!response.ok) throw new Error('Failed to fetch DJ set');
    return response.json();
  }

  static async getDJSetsByDJ(djId: string) {
    const response = await fetch(getApiUrl(`/dj-sets/dj/${djId}`));
    if (!response.ok) throw new Error('Failed to fetch DJ sets');
    return response.json();
  }

  static async addTrack(setId: string, track: any) {
    const response = await fetch(getApiUrl(`/dj-sets/${setId}/tracks`), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(track),
    });
    if (!response.ok) throw new Error('Failed to add track');
    return response.json();
  }

  static async batchAddTracks(setId: string, tracks: any[]) {
    const response = await fetch(getApiUrl(`/dj-sets/${setId}/tracks/batch`), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ tracks }),
    });
    if (!response.ok) throw new Error('Failed to add tracks');
    return response.json();
  }

  static async autoLinkTracks(setId: string) {
    const response = await fetch(getApiUrl(`/dj-sets/${setId}/auto-link`), {
      method: 'POST',
    });
    if (!response.ok) throw new Error('Failed to auto-link tracks');
    return response.json();
  }
}

export class DJAggregatorAPI {
  static async syncDJ(djId: string) {
    const response = await fetch(getApiUrl(`/dj-aggregator/sync/${djId}`), {
      method: 'POST',
    });
    if (!response.ok) throw new Error('Failed to sync DJ');
    return response.json();
  }

  static async batchSyncDJs(djIds: string[]) {
    const response = await fetch(getApiUrl('/dj-aggregator/batch-sync'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ djIds }),
    });
    if (!response.ok) throw new Error('Failed to batch sync DJs');
    return response.json();
  }

  static async searchDJ(name: string) {
    const response = await fetch(getApiUrl(`/dj-aggregator/search/${encodeURIComponent(name)}`));
    if (!response.ok) throw new Error('Failed to search DJ');
    return response.json();
  }
}