import { getApiUrl } from './config';

// 网易云音乐搜索
export class NeteaseAPI {
  static async searchTrack(keyword: string) {
    try {
      const response = await fetch(getApiUrl(`/music/netease/search?keyword=${encodeURIComponent(keyword)}`));
      if (!response.ok) throw new Error('Failed to search on Netease');
      return response.json();
    } catch (error) {
      console.error('Netease search error:', error);
      return { songs: [] };
    }
  }
}

// Spotify搜索
export class SpotifyAPI {
  static async searchTrack(keyword: string) {
    try {
      const response = await fetch(getApiUrl(`/music/spotify/search?keyword=${encodeURIComponent(keyword)}`));
      if (!response.ok) throw new Error('Failed to search on Spotify');
      return response.json();
    } catch (error) {
      console.error('Spotify search error:', error);
      return { tracks: [] };
    }
  }
}