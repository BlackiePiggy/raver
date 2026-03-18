import { getApiUrl } from './config';

// Spotify搜索
export class SpotifyAPI {
  static async getAuthStatus() {
    const response = await fetch(getApiUrl('/music/spotify/auth-status'));
    if (!response.ok) {
      throw new Error('Failed to fetch Spotify auth status');
    }
    return response.json();
  }

  static async searchTrack(keyword: string) {
    const response = await fetch(getApiUrl(`/music/spotify/search?keyword=${encodeURIComponent(keyword)}`));
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.error || 'Failed to search on Spotify');
    }
    return response.json();
  }
}
