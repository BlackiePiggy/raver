import axios from 'axios';

export class MusicSearchService {
  /**
   * 搜索网易云音乐
   */
  async searchNetease(keyword: string) {
    try {
      // 使用网易云音乐API (需要部署网易云API服务或使用第��方API)
      // 这里使用一个开源的网易云API: https://github.com/Binaryify/NeteaseCloudMusicApi
      const apiUrl = process.env.NETEASE_API_URL || 'http://localhost:3300';

      const response = await axios.get(`${apiUrl}/search`, {
        params: {
          keywords: keyword,
          limit: 10,
          type: 1, // 1: 单曲
        },
      });

      const songs = response.data.result?.songs || [];

      return songs.map((song: any) => ({
        id: song.id,
        name: song.name,
        artist: song.artists?.map((a: any) => a.name).join(', ') || '',
        album: song.album?.name || '',
        url: `https://music.163.com/#/song?id=${song.id}`,
        platform: 'netease',
      }));
    } catch (error) {
      console.error('Netease search error:', error);
      return [];
    }
  }

  /**
   * 搜索Spotify
   */
  async searchSpotify(keyword: string) {
    try {
      const token = await this.getSpotifyToken();

      const response = await axios.get('https://api.spotify.com/v1/search', {
        headers: {
          Authorization: `Bearer ${token}`,
        },
        params: {
          q: keyword,
          type: 'track',
          limit: 10,
        },
      });

      const tracks = response.data.tracks?.items || [];

      return tracks.map((track: any) => ({
        id: track.id,
        name: track.name,
        artist: track.artists?.map((a: any) => a.name).join(', ') || '',
        album: track.album?.name || '',
        url: track.external_urls?.spotify || '',
        platform: 'spotify',
        previewUrl: track.preview_url,
      }));
    } catch (error) {
      console.error('Spotify search error:', error);
      return [];
    }
  }

  /**
   * 获取Spotify Token
   */
  private async getSpotifyToken(): Promise<string> {
    const clientId = process.env.SPOTIFY_CLIENT_ID;
    const clientSecret = process.env.SPOTIFY_CLIENT_SECRET;

    if (!clientId || !clientSecret) {
      throw new Error('Spotify credentials not configured');
    }

    const response = await axios.post(
      'https://accounts.spotify.com/api/token',
      'grant_type=client_credentials',
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          Authorization: `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString('base64')}`,
        },
      }
    );

    return response.data.access_token;
  }
}

export default new MusicSearchService();