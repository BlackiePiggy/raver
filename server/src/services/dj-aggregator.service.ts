import axios from 'axios';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

interface SpotifyArtist {
  id: string;
  name: string;
  images: { url: string }[];
  genres: string[];
  followers: { total: number };
  external_urls: { spotify: string };
}

interface DiscogsArtist {
  id: number;
  name: string;
  profile: string;
  images?: { uri: string }[];
  urls?: string[];
}

export class DJAggregatorService {
  private spotifyToken: string | null = null;
  private spotifyTokenExpiry: number = 0;

  /**
   * Get Spotify access token
   */
  private async getSpotifyToken(): Promise<string> {
    if (this.spotifyToken && Date.now() < this.spotifyTokenExpiry) {
      return this.spotifyToken;
    }

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

    this.spotifyToken = response.data.access_token;
    this.spotifyTokenExpiry = Date.now() + response.data.expires_in * 1000;

    return this.spotifyToken as string;
  }

  /**
   * Search for DJ on Spotify
   */
  async searchSpotifyArtist(name: string): Promise<SpotifyArtist | null> {
    try {
      const token = await this.getSpotifyToken();
      const response = await axios.get('https://api.spotify.com/v1/search', {
        headers: { Authorization: `Bearer ${token}` },
        params: {
          q: name,
          type: 'artist',
          limit: 1,
        },
      });

      const artist = response.data.artists?.items[0];
      return artist || null;
    } catch (error) {
      console.error('Spotify search error:', error);
      return null;
    }
  }

  /**
   * Search for DJ on Discogs
   */
  async searchDiscogsArtist(name: string): Promise<DiscogsArtist | null> {
    try {
      const token = process.env.DISCOGS_TOKEN;
      if (!token) {
        console.warn('Discogs token not configured');
        return null;
      }

      const response = await axios.get('https://api.discogs.com/database/search', {
        headers: { Authorization: `Discogs token=${token}` },
        params: {
          q: name,
          type: 'artist',
          per_page: 1,
        },
      });

      const artistId = response.data.results?.[0]?.id;
      if (!artistId) return null;

      const artistResponse = await axios.get(`https://api.discogs.com/artists/${artistId}`, {
        headers: { Authorization: `Discogs token=${token}` },
      });

      return artistResponse.data;
    } catch (error) {
      console.error('Discogs search error:', error);
      return null;
    }
  }

  /**
   * Aggregate DJ data from multiple sources
   */
  async aggregateDJData(name: string) {
    const [spotifyData, discogsData] = await Promise.all([
      this.searchSpotifyArtist(name),
      this.searchDiscogsArtist(name),
    ]);

    return {
      name,
      bio: discogsData?.profile || null,
      avatarUrl: spotifyData?.images[0]?.url || discogsData?.images?.[0]?.uri || null,
      spotifyId: spotifyData?.id || null,
      discogsId: discogsData?.id?.toString() || null,
      followerCount: spotifyData?.followers?.total || 0,
    };
  }

  /**
   * Sync DJ data from external sources
   */
  async syncDJ(djId: string) {
    const dj = await prisma.dJ.findUnique({ where: { id: djId } });
    if (!dj) throw new Error('DJ not found');

    const aggregatedData = await this.aggregateDJData(dj.name);

    return await prisma.dJ.update({
      where: { id: djId },
      data: {
        ...aggregatedData,
        lastSyncedAt: new Date(),
      },
    });
  }

  /**
   * Batch sync multiple DJs
   */
  async batchSyncDJs(djIds: string[]) {
    const results = [];
    for (const djId of djIds) {
      try {
        const updated = await this.syncDJ(djId);
        results.push({ success: true, dj: updated });
        // Rate limiting
        await new Promise(resolve => setTimeout(resolve, 1000));
      } catch (error) {
        results.push({ success: false, djId, error: (error as Error).message });
      }
    }
    return results;
  }
}

export default new DJAggregatorService();
