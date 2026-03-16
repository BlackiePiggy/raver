import { PrismaClient } from '@prisma/client';
import axios from 'axios';

const prisma = new PrismaClient();

interface CreateDJSetInput {
  djId: string;
  title: string;
  videoUrl: string;
  description?: string;
  recordedAt?: Date;
  venue?: string;
  eventName?: string;
}

interface CreateTrackInput {
  setId: string;
  position: number;
  startTime: number;
  endTime?: number;
  title: string;
  artist: string;
  status?: 'released' | 'id' | 'remix' | 'edit';
}

export class DJSetService {
  /**
   * Parse video URL to extract platform and video ID
   */
  parseVideoUrl(url: string): { platform: string; videoId: string } | null {
    // YouTube patterns
    const youtubePatterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/,
      /youtube\.com\/embed\/([a-zA-Z0-9_-]{11})/,
    ];

    for (const pattern of youtubePatterns) {
      const match = url.match(pattern);
      if (match) {
        return { platform: 'youtube', videoId: match[1] };
      }
    }

    // Bilibili patterns
    const bilibiliPattern = /bilibili\.com\/video\/(BV[a-zA-Z0-9]+)/;
    const bilibiliMatch = url.match(bilibiliPattern);
    if (bilibiliMatch) {
      return { platform: 'bilibili', videoId: bilibiliMatch[1] };
    }

    return null;
  }

  /**
   * Generate slug from title
   */
  generateSlug(title: string): string {
    return title
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '');
  }

  /**
   * Create a new DJ set
   */
  async createDJSet(input: CreateDJSetInput) {
    const videoInfo = this.parseVideoUrl(input.videoUrl);
    if (!videoInfo) {
      throw new Error('Invalid video URL');
    }

    const slug = this.generateSlug(input.title);

    return await prisma.dJSet.create({
      data: {
        djId: input.djId,
        title: input.title,
        slug,
        description: input.description,
        videoUrl: input.videoUrl,
        platform: videoInfo.platform,
        videoId: videoInfo.videoId,
        recordedAt: input.recordedAt,
        venue: input.venue,
        eventName: input.eventName,
      },
      include: {
        dj: true,
      },
    });
  }

  /**
   * Add track to a DJ set
   */
  async addTrack(input: CreateTrackInput) {
    return await prisma.track.create({
      data: {
        setId: input.setId,
        position: input.position,
        startTime: input.startTime,
        endTime: input.endTime,
        title: input.title,
        artist: input.artist,
        status: input.status || 'released',
      },
    });
  }

  /**
   * Batch add tracks to a DJ set
   */
  async batchAddTracks(setId: string, tracks: Omit<CreateTrackInput, 'setId'>[]) {
    const trackData = tracks.map(track => ({
      setId,
      ...track,
      status: track.status || 'released',
    }));

    return await prisma.track.createMany({
      data: trackData,
    });
  }

  /**
   * Search for track on streaming platforms
   */
  async searchTrackOnPlatforms(title: string, artist: string) {
    const query = `${artist} ${title}`;
    const results: any = {
      spotify: null,
      appleMusic: null,
      youtubeMusic: null,
    };

    // Search Spotify
    try {
      const spotifyToken = process.env.SPOTIFY_ACCESS_TOKEN;
      if (spotifyToken) {
        const response = await axios.get('https://api.spotify.com/v1/search', {
          headers: { Authorization: `Bearer ${spotifyToken}` },
          params: { q: query, type: 'track', limit: 1 },
        });
        const track = response.data.tracks?.items[0];
        if (track) {
          results.spotify = track.external_urls.spotify;
        }
      }
    } catch (error) {
      console.error('Spotify search error:', error);
    }

    return results;
  }

  /**
   * Auto-link tracks to streaming platforms
   */
  async autoLinkTracks(setId: string) {
    const tracks = await prisma.track.findMany({
      where: { setId, status: 'released' },
    });

    for (const track of tracks) {
      if (!track.spotifyUrl) {
        const links = await this.searchTrackOnPlatforms(track.title, track.artist);
        await prisma.track.update({
          where: { id: track.id },
          data: {
            spotifyUrl: links.spotify,
            appleMusicUrl: links.appleMusic,
            youtubeMusicUrl: links.youtubeMusic,
          },
        });
        // Rate limiting
        await new Promise(resolve => setTimeout(resolve, 500));
      }
    }
  }

  /**
   * Get all DJ sets
   */
  async getAllDJSets() {
    return await prisma.dJSet.findMany({
      include: {
        dj: true,
        tracks: {
          orderBy: { position: 'asc' },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Get DJ set with tracks
   */
  async getDJSet(setId: string) {
    return await prisma.dJSet.findUnique({
      where: { id: setId },
      include: {
        dj: true,
        tracks: {
          orderBy: { position: 'asc' },
        },
      },
    });
  }

  /**
   * Get DJ sets by DJ ID
   */
  async getDJSetsByDJ(djId: string) {
    return await prisma.dJSet.findMany({
      where: { djId },
      include: {
        dj: true,
        tracks: {
          orderBy: { position: 'asc' },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }
}

export default new DJSetService();