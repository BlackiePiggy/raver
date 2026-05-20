import { Prisma, PrismaClient } from '@prisma/client';
import axios, { AxiosRequestConfig } from 'axios';
import path from 'path';
import {
  USER_ENTITY_RELATION_FAVORITE,
  USER_ENTITY_TARGET_DJ,
} from './user-entity-follow.service';
import { resolveUserGenrePreferences } from './user-genre-preference.service';

const prisma = new PrismaClient();

const youtubeProxyUrl = (process.env.YOUTUBE_PROXY_URL || process.env.YOUTUBE_HTTPS_PROXY || 'http://127.0.0.1:7897').trim();

const youtubeAxiosProxyConfig = (): Pick<AxiosRequestConfig, 'proxy'> => {
  if (!youtubeProxyUrl) return {};
  try {
    const parsed = new URL(youtubeProxyUrl);
    return {
      proxy: {
        protocol: parsed.protocol.replace(':', ''),
        host: parsed.hostname,
        port: Number(parsed.port || 80),
      },
    };
  } catch (_error) {
    return {};
  }
};

type DJSetSortBy = 'latest' | 'popular' | 'tracks';

interface DJSetListOptions {
  page?: number;
  limit?: number;
  sortBy?: DJSetSortBy;
  djId?: string;
  eventId?: string;
  eventName?: string;
}

interface CreateDJSetInput {
  djId?: string | null;
  djIds?: string[];
  customDjNames?: string[];
  uploadedById?: string;
  title: string;
  videoUrl: string;
  videoAuthorName?: string;
  thumbnailUrl?: string;
  description?: string;
  recordedAt?: Date;
  venue?: string;
  eventId?: string | null;
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
  spotifyUrl?: string;
  spotifyId?: string;
  spotifyUri?: string;
  neteaseUrl?: string;
  neteaseId?: string;
}

interface UpdateDJSetInput {
  djId?: string;
  djIds?: string[];
  customDjNames?: string[];
  title?: string;
  description?: string;
  videoUrl?: string;
  videoAuthorName?: string;
  thumbnailUrl?: string;
  venue?: string;
  eventId?: string | null;
  eventName?: string;
  recordedAt?: Date | null;
}

export class DJSetService {
  private readonly youtubeOEmbedTimeoutMs = Number(process.env.YOUTUBE_OEMBED_TIMEOUT_MS || 1000);

  private readonly contributorUserSelect = {
    id: true,
    username: true,
    displayName: true,
    avatarUrl: true,
    bio: true,
    location: true,
  } as const;

  private async filterActiveCopyrightTakedowns<T extends { id: string }>(sets: T[]): Promise<T[]> {
    if (sets.length === 0) return sets;
    const takedowns = await prisma.contentReport.findMany({
      where: {
        targetType: 'dj_set',
        targetId: { in: sets.map((set) => set.id) },
        reason: 'copyright',
        metadata: {
          path: ['copyright', 'takedownStatus'],
          equals: 'active',
        },
      },
      select: { targetId: true },
    });
    if (takedowns.length === 0) return sets;
    const hiddenIds = new Set(takedowns.map((row) => row.targetId));
    return sets.filter((set) => !hiddenIds.has(set.id));
  }

  private normalizeNullableId(value?: string | null): string | null | undefined {
    if (value === undefined) return undefined;
    if (value === null) return null;
    const normalized = String(value || '').trim();
    return normalized || null;
  }

  private async mapContributorProfile(
    user:
      | {
          id: string;
          username: string;
          displayName: string | null;
          avatarUrl: string | null;
          bio: string | null;
          location: string | null;
        }
      | null
      | undefined
  ) {
    if (!user) {
      return null;
    }

    const favoriteDjRelationRows = await prisma.userEntityFollow.findMany({
      where: {
        userId: user.id,
        relationType: USER_ENTITY_RELATION_FAVORITE,
        targetType: USER_ENTITY_TARGET_DJ,
      },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      select: {
        targetId: true,
      },
    });

    const favoriteDjIds =
      favoriteDjRelationRows.length > 0
        ? favoriteDjRelationRows.map((row) => row.targetId).filter((id): id is string => Boolean(id))
        : [];

    let favoriteDJs: string[] = [];
    if (favoriteDjIds.length > 0) {
      const djs = await prisma.dJ.findMany({
        where: {
          id: {
            in: favoriteDjIds,
          },
        },
        select: {
          id: true,
          name: true,
        },
      });

      const djNameById = new Map(djs.map((dj) => [dj.id, dj.name]));
      favoriteDJs = favoriteDjIds.map((djId) => djNameById.get(djId)).filter((name): name is string => Boolean(name));
    }
    const favoriteGenres = await resolveUserGenrePreferences(prisma, user.id);

    return {
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      bio: user.bio,
      location: user.location,
      favoriteGenres,
      favoriteDJs,
    };
  }

  /**
   * Parse video URL to extract platform and video ID
   */
  parseVideoUrl(url: string): { platform: string; videoId: string } | null {
    const trimmed = url.trim();
    if (!trimmed) {
      return null;
    }

    const resolvePathname = (value: string): string => {
      try {
        if (value.startsWith('http://') || value.startsWith('https://')) {
          return new URL(value).pathname;
        }
      } catch (_error) {
        // Ignore invalid URL parsing and fallback to raw string.
      }
      return value;
    };

    const pathname = resolvePathname(trimmed);
    const lowerPath = pathname.toLowerCase();
    const isVideoFile = /\.(mp4|mov|m4v|webm|m3u8)$/i.test(lowerPath);

    if ((lowerPath.startsWith('/uploads/') || lowerPath.includes('/uploads/')) && isVideoFile) {
      const videoId = path.basename(pathname).replace(/\.[^.]+$/, '') || `local-${Date.now()}`;
      return { platform: 'native', videoId };
    }

    if ((trimmed.startsWith('http://') || trimmed.startsWith('https://')) && isVideoFile) {
      const videoId = path.basename(pathname).replace(/\.[^.]+$/, '') || `native-${Date.now()}`;
      return { platform: 'native', videoId };
    }

    // YouTube patterns
    const youtubePatterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/,
      /youtube\.com\/embed\/([a-zA-Z0-9_-]{11})/,
      /youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})/,
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

  private async generateUniqueSlug(title: string): Promise<string> {
    const baseSlug = this.generateSlug(title) || 'dj-set';
    let candidate = baseSlug;
    let counter = 1;

    while (true) {
      const exists = await prisma.dJSet.findUnique({
        where: { slug: candidate },
        select: { id: true },
      });

      if (!exists) {
        return candidate;
      }

      counter += 1;
      candidate = `${baseSlug}-${counter}`;
    }
  }

  private decodeHtml(text: string): string {
    return text
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'");
  }

  private extractMeta(html: string, key: string): string {
    const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const patterns = [
      new RegExp(`<meta[^>]*property=["']${escaped}["'][^>]*content=["']([^"']+)["'][^>]*>`, 'i'),
      new RegExp(`<meta[^>]*content=["']([^"']+)["'][^>]*property=["']${escaped}["'][^>]*>`, 'i'),
      new RegExp(`<meta[^>]*name=["']${escaped}["'][^>]*content=["']([^"']+)["'][^>]*>`, 'i'),
      new RegExp(`<meta[^>]*content=["']([^"']+)["'][^>]*name=["']${escaped}["'][^>]*>`, 'i'),
    ];

    for (const pattern of patterns) {
      const match = html.match(pattern);
      if (match?.[1]) {
        return this.decodeHtml(match[1].trim());
      }
    }

    return '';
  }

  async getVideoPreview(videoUrl: string) {
    const parsed = this.parseVideoUrl(videoUrl);
    if (!parsed) {
      throw new Error('Invalid video URL');
    }

    if (parsed.platform === 'native') {
      const pathname = (() => {
        try {
          if (videoUrl.startsWith('http://') || videoUrl.startsWith('https://')) {
            return new URL(videoUrl).pathname;
          }
        } catch (_error) {
          // Ignore URL parse errors and fallback to raw value.
        }
        return videoUrl;
      })();
      const fileName = path.basename(pathname).replace(/\.[^.]+$/, '');
      return {
        platform: parsed.platform,
        videoId: parsed.videoId,
        title: fileName ? fileName.replace(/[-_]+/g, ' ') : '',
        description: '',
        thumbnailUrl: '',
      };
    }

    let title = '';
    let description = '';
    let thumbnailUrl = '';
    let authorName = '';

    // Prefer oEmbed for YouTube metadata, but always keep a fast thumbnail fallback.
    if (parsed.platform === 'youtube') {
      const canonicalYouTubeUrl = `https://www.youtube.com/watch?v=${parsed.videoId}`;
      thumbnailUrl = `https://img.youtube.com/vi/${parsed.videoId}/hqdefault.jpg`;

      try {
        const oembed = await axios.get('https://www.youtube.com/oembed', {
          params: { url: canonicalYouTubeUrl, format: 'json' },
          timeout: this.youtubeOEmbedTimeoutMs,
          ...youtubeAxiosProxyConfig(),
        });
        title = oembed.data?.title || '';
        authorName = oembed.data?.author_name || '';
        thumbnailUrl = oembed.data?.thumbnail_url || thumbnailUrl;
      } catch (error) {
        if (!axios.isAxiosError(error) || error.code !== 'ECONNABORTED') {
          const message = error instanceof Error ? error.message : String(error);
          console.warn(`YouTube oEmbed preview unavailable for ${parsed.videoId}: ${message}`);
        }
      }
    }

    // Fallback to Open Graph parsing (skip YouTube to avoid long timeout in restricted regions)
    if (parsed.platform !== 'youtube' && (!title || !description || !thumbnailUrl)) {
      try {
        const pageResponse = await axios.get(videoUrl, {
          timeout: 3500,
          headers: {
            'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            Accept: 'text/html,application/xhtml+xml',
          },
        });
        const html = String(pageResponse.data || '');
        title = title || this.extractMeta(html, 'og:title') || this.extractMeta(html, 'twitter:title');
        description =
          description ||
          this.extractMeta(html, 'og:description') ||
          this.extractMeta(html, 'description');
        thumbnailUrl =
          thumbnailUrl || this.extractMeta(html, 'og:image') || this.extractMeta(html, 'twitter:image');
      } catch (error) {
        console.warn('Open Graph preview fetch failed:', error);
      }
    }

    return {
      platform: parsed.platform,
      videoId: parsed.videoId,
      title,
      description,
      thumbnailUrl,
      authorName,
    };
  }

  /**
   * Create a new DJ set
   */
  async createDJSet(input: CreateDJSetInput) {
    const videoInfo = this.parseVideoUrl(input.videoUrl);
    if (!videoInfo) {
      throw new Error('Invalid video URL');
    }
    const normalizedPrimaryDjId = String(input.djId || '').trim() || undefined;
    const thumbnailUrl = input.thumbnailUrl?.trim() || undefined;

    const normalizedDjIds = this.normalizeDjIds(normalizedPrimaryDjId, input.djIds);
    const customDjNames = this.normalizeCustomDjNames(input.customDjNames);
    const eventId = this.normalizeNullableId(input.eventId);

    const slug = await this.generateUniqueSlug(input.title);

    const created = await prisma.$transaction(async (tx) => {
      const set = await tx.dJSet.create({
        data: {
          djId: normalizedPrimaryDjId,
          customDjNames,
          uploadedById: input.uploadedById,
          title: input.title,
          slug,
          description: input.description,
          thumbnailUrl,
          videoUrl: input.videoUrl,
          videoAuthorName: input.videoAuthorName?.trim() || undefined,
          platform: videoInfo.platform,
          videoId: videoInfo.videoId,
          recordedAt: input.recordedAt,
          venue: input.venue,
          eventId,
          eventName: input.eventName,
        },
        include: {
          dj: true,
          uploader: {
            select: this.contributorUserSelect,
          },
        },
      });
      await this.syncDJSetArtists(tx, set.id, {
        primaryDjId: normalizedPrimaryDjId ?? null,
        djIds: normalizedDjIds,
        customDjNames,
      });
      return set;
    });

    return this.attachLineupInfo(created as any);
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
        spotifyUrl: input.spotifyUrl,
        spotifyId: input.spotifyId,
        spotifyUri: input.spotifyUri,
        neteaseUrl: input.neteaseUrl,
        neteaseId: input.neteaseId,
      },
    });
  }

  /**
   * Batch add tracks to a DJ set
   */
  async batchAddTracks(setId: string, tracks: Omit<CreateTrackInput, 'setId'>[]) {
    const trackData = tracks.map(track => ({
      setId,
      position: track.position,
      startTime: track.startTime,
      endTime: track.endTime,
      title: track.title,
      artist: track.artist,
      status: track.status || 'released',
      spotifyUrl: track.spotifyUrl,
      spotifyId: track.spotifyId,
      spotifyUri: track.spotifyUri,
      neteaseUrl: track.neteaseUrl,
      neteaseId: track.neteaseId,
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
    const sets = await prisma.dJSet.findMany({
      include: {
        dj: true,
        artists: {
          orderBy: [{ artistOrder: 'asc' }, { createdAt: 'asc' }],
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true },
            },
          },
        },
        uploader: {
          select: this.contributorUserSelect,
        },
        tracks: {
          orderBy: { position: 'asc' },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const visibleSets = await this.filterActiveCopyrightTakedowns(sets);
    return await Promise.all(
      visibleSets.map(async (set) => {
        const contributor = await this.mapContributorProfile(set.uploader);
        const withLineup = await this.attachLineupInfo(set as any);
        return {
          ...withLineup,
          videoContributor: contributor,
          tracklistContributor: contributor,
        };
      })
    );
  }

  async listDJSets(options: DJSetListOptions = {}) {
    const page = Math.max(1, Math.floor(options.page || 1));
    const limit = Math.min(Math.max(1, Math.floor(options.limit || 20)), 100);
    const sortBy = options.sortBy || 'latest';
    const djId = String(options.djId || '').trim();
    const eventId = String(options.eventId || '').trim();
    const eventName = String(options.eventName || '').trim();
    const where = {
      ...(djId ? { djId } : {}),
      ...(eventId
        ? {
            OR: [
              { eventId },
              ...(eventName ? [{ eventName: { equals: eventName, mode: 'insensitive' as const } }] : []),
            ],
          }
        : eventName
          ? { eventName: { equals: eventName, mode: 'insensitive' as const } }
          : {}),
    };
    const orderBy =
      sortBy === 'popular'
        ? [{ viewCount: 'desc' as const }, { createdAt: 'desc' as const }]
        : sortBy === 'tracks'
          ? [{ tracks: { _count: 'desc' as const } }, { createdAt: 'desc' as const }]
          : [{ createdAt: 'desc' as const }];
    const skip = (page - 1) * limit;

    const [total, sets] = await Promise.all([
      prisma.dJSet.count({ where }),
      prisma.dJSet.findMany({
        where,
        include: {
          dj: true,
          artists: {
            orderBy: [{ artistOrder: 'asc' }, { createdAt: 'asc' }],
            include: {
              dj: {
                select: { id: true, name: true, avatarUrl: true },
              },
            },
          },
          uploader: {
            select: this.contributorUserSelect,
          },
          tracks: {
            orderBy: { position: 'asc' },
          },
        },
        orderBy,
        skip,
        take: limit,
      }),
    ]);

    const visibleSets = await this.filterActiveCopyrightTakedowns(sets);
    const items = await Promise.all(
      visibleSets.map(async (set) => {
        const contributor = await this.mapContributorProfile(set.uploader);
        const withLineup = await this.attachLineupInfo(set as any);
        return {
          ...withLineup,
          videoContributor: contributor,
          tracklistContributor: contributor,
        };
      })
    );

    return { items, total };
  }

  async getDJSetsByUploader(userId: string) {
    const sets = await prisma.dJSet.findMany({
      where: { uploadedById: userId },
      include: {
        dj: true,
        artists: {
          orderBy: [{ artistOrder: 'asc' }, { createdAt: 'asc' }],
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true },
            },
          },
        },
        uploader: {
          select: this.contributorUserSelect,
        },
        tracks: {
          orderBy: { position: 'asc' },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const visibleSets = await this.filterActiveCopyrightTakedowns(sets);
    return await Promise.all(
      visibleSets.map(async (set) => {
        const contributor = await this.mapContributorProfile(set.uploader);
        const withLineup = await this.attachLineupInfo(set as any);
        return {
          ...withLineup,
          videoContributor: contributor,
          tracklistContributor: contributor,
        };
      })
    );
  }

  /**
   * Get DJ set with tracks
   */
  async getDJSet(setId: string) {
    const djSet = await prisma.dJSet.findUnique({
      where: { id: setId },
      include: {
        dj: true,
        artists: {
          orderBy: [{ artistOrder: 'asc' }, { createdAt: 'asc' }],
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true },
            },
          },
        },
        uploader: {
          select: this.contributorUserSelect,
        },
        tracks: {
          orderBy: { position: 'asc' },
        },
      },
    });

    if (!djSet) {
      return null;
    }
    const visibleSets = await this.filterActiveCopyrightTakedowns([djSet]);
    if (visibleSets.length === 0) {
      return null;
    }

    const contributor = await this.mapContributorProfile(djSet.uploader);
    const withLineup = await this.attachLineupInfo(djSet as any);
    return {
      ...withLineup,
      videoContributor: contributor,
      tracklistContributor: contributor,
    };
  }

  /**
   * Get DJ sets by DJ ID
   */
  async getDJSetsByDJ(djId: string) {
    const sets = await prisma.dJSet.findMany({
      where: {
        artists: {
          some: { djId },
        },
      },
      include: {
        dj: true,
        artists: {
          orderBy: [{ artistOrder: 'asc' }, { createdAt: 'asc' }],
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true },
            },
          },
        },
        uploader: {
          select: this.contributorUserSelect,
        },
        tracks: {
          orderBy: { position: 'asc' },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const visibleSets = await this.filterActiveCopyrightTakedowns(sets);
    return await Promise.all(
      visibleSets.map(async (set) => {
        const contributor = await this.mapContributorProfile(set.uploader);
        const withLineup = await this.attachLineupInfo(set as any);
        return {
          ...withLineup,
          videoContributor: contributor,
          tracklistContributor: contributor,
        };
      })
    );
  }

  async updateDJSetByUploader(setId: string, userId: string, input: UpdateDJSetInput) {
    const current = await prisma.dJSet.findUnique({
      where: { id: setId },
      select: {
        id: true,
        djId: true,
        customDjNames: true,
        uploadedById: true,
        videoUrl: true,
        platform: true,
        videoId: true,
      },
    });

    if (!current) {
      throw new Error('DJ set not found');
    }
    if (!current.uploadedById || current.uploadedById !== userId) {
      throw new Error('Forbidden');
    }

    let platform = current.platform;
    let videoId = current.videoId;
    const thumbnailUrl = input.thumbnailUrl?.trim() || undefined;

    if (input.videoUrl && input.videoUrl !== current.videoUrl) {
      const parsed = this.parseVideoUrl(input.videoUrl);
      if (!parsed) {
        throw new Error('Invalid video URL');
      }
      platform = parsed.platform;
      videoId = parsed.videoId;
    }

    const nextDjId = input.djId !== undefined ? (String(input.djId || '').trim() || null) : current.djId;
    const nextEventId = this.normalizeNullableId(input.eventId);
    const currentArtists = await prisma.dJSetArtist.findMany({
      where: { setId },
      orderBy: [{ artistOrder: 'asc' }, { createdAt: 'asc' }],
      select: { djId: true },
    });
    const currentDjIds = currentArtists
      .map((artist) => String(artist.djId || '').trim())
      .filter((id): id is string => Boolean(id));
    const normalizedDjIds = this.normalizeDjIds(
      nextDjId,
      input.djIds && input.djIds.length > 0 ? input.djIds : currentDjIds
    );
    const customDjNames =
      input.customDjNames !== undefined
        ? this.normalizeCustomDjNames(input.customDjNames)
        : current.customDjNames;

    const updated = await prisma.$transaction(async (tx) => {
      const set = await tx.dJSet.update({
        where: { id: setId },
        data: {
          djId: nextDjId,
          customDjNames,
          title: input.title ?? undefined,
          description: input.description ?? undefined,
          videoUrl: input.videoUrl ?? undefined,
          videoAuthorName: input.videoAuthorName?.trim() || undefined,
          thumbnailUrl,
          venue: input.venue ?? undefined,
          eventId: nextEventId,
          eventName: input.eventName ?? undefined,
          recordedAt: input.recordedAt ?? undefined,
          platform,
          videoId,
        },
        include: {
          dj: true,
          artists: {
            orderBy: [{ artistOrder: 'asc' }, { createdAt: 'asc' }],
            include: {
              dj: {
                select: { id: true, name: true, avatarUrl: true },
              },
            },
          },
          uploader: {
            select: this.contributorUserSelect,
          },
          tracks: {
            orderBy: { position: 'asc' },
          },
        },
      });
      await this.syncDJSetArtists(tx, setId, {
        primaryDjId: nextDjId,
        djIds: normalizedDjIds,
        customDjNames,
      });
      return set;
    });
    return this.attachLineupInfo(updated as any);
  }

  async replaceTracksByUploader(
    setId: string,
    userId: string,
    tracks: Omit<CreateTrackInput, 'setId'>[]
  ) {
    const current = await prisma.dJSet.findUnique({
      where: { id: setId },
      select: { id: true, uploadedById: true, thumbnailUrl: true },
    });
    if (!current) {
      throw new Error('DJ set not found');
    }
    if (!current.uploadedById || current.uploadedById !== userId) {
      throw new Error('Forbidden');
    }

    const normalized = tracks.map((track, index) => ({
      setId,
      position: Number(track.position) || index + 1,
      startTime: track.startTime,
      endTime: track.endTime,
      title: track.title,
      artist: track.artist,
      status: track.status || 'released',
      spotifyUrl: track.spotifyUrl,
      spotifyId: track.spotifyId,
      spotifyUri: track.spotifyUri,
      neteaseUrl: track.neteaseUrl,
      neteaseId: track.neteaseId,
    }));

    await prisma.$transaction([
      prisma.track.deleteMany({ where: { setId } }),
      ...(normalized.length > 0 ? [prisma.track.createMany({ data: normalized })] : []),
    ]);

    return await this.getDJSet(setId);
  }

  private normalizeDjIds(primaryDjId?: string | null, candidateIds?: string[]): string[] {
    const ids = [primaryDjId, ...(candidateIds || [])]
      .map((id) => String(id || '').trim())
      .filter(Boolean);
    return [...new Set(ids)];
  }

  private normalizeCustomDjNames(names?: string[]): string[] {
    if (!Array.isArray(names)) {
      return [];
    }
    const cleaned = names.map((name) => String(name || '').trim()).filter(Boolean);
    return [...new Set(cleaned)];
  }

  private async syncDJSetArtists(
    tx: Prisma.TransactionClient,
    setId: string,
    input: {
      primaryDjId?: string | null;
      djIds: string[];
      customDjNames: string[];
    }
  ): Promise<void> {
    await tx.dJSetArtist.deleteMany({
      where: { setId },
    });

    const normalizedDjIds = this.normalizeDjIds(input.primaryDjId, input.djIds);
    const djRows =
      normalizedDjIds.length > 0
        ? await tx.dJ.findMany({
            where: {
              id: { in: normalizedDjIds },
            },
            select: {
              id: true,
              name: true,
            },
          })
        : [];
    const djNameById = new Map(djRows.map((row) => [row.id, row.name]));

    const artistRows: Prisma.DJSetArtistCreateManyInput[] = [];
    normalizedDjIds.forEach((djId, index) => {
      artistRows.push({
        setId,
        djId,
        artistNameSnapshot: djNameById.get(djId) ?? djId,
        artistOrder: index,
        role: input.primaryDjId && djId === input.primaryDjId ? 'primary' : 'co',
      });
    });
    input.customDjNames.forEach((name, index) => {
      artistRows.push({
        setId,
        djId: null,
        artistNameSnapshot: name,
        artistOrder: normalizedDjIds.length + index,
        role: 'custom',
      });
    });

    if (artistRows.length > 0) {
      await tx.dJSetArtist.createMany({
        data: artistRows,
      });
    }
  }

  private async attachLineupInfo<T extends { id: string; djId?: string | null; customDjNames: string[]; artists?: any[] }>(
    set: T
  ) {
    const artistRows = Array.isArray(set.artists)
      ? set.artists
      : await prisma.dJSetArtist.findMany({
          where: { setId: set.id },
          orderBy: [{ artistOrder: 'asc' }, { createdAt: 'asc' }],
          include: {
            dj: {
              select: { id: true, name: true, avatarUrl: true },
            },
          },
        });

    const lineupIds = artistRows
      .map((artist: any) => artist.djId)
      .filter((id: unknown): id is string => typeof id === 'string' && id.trim().length > 0);
    const lineupDjs = artistRows.map((artist: any) => artist.dj).filter((dj: any) => Boolean(dj));
    const djById = new Map(lineupDjs.map((dj: any) => [dj.id, dj]));
    const customDjNames = artistRows
      .filter((artist: any) => !artist.djId)
      .map((artist: any) => String(artist.artistNameSnapshot || '').trim())
      .filter(Boolean);

    return {
      ...set,
      lineupDjs: lineupIds.map((id) => djById.get(id)).filter((dj): dj is NonNullable<typeof dj> => Boolean(dj)),
      customDjNames,
    };
  }

  async deleteDJSetByUploader(setId: string, userId: string, role?: string) {
    const current = await prisma.dJSet.findUnique({
      where: { id: setId },
      select: { id: true, uploadedById: true, thumbnailUrl: true },
    });

    if (!current) {
      throw new Error('DJ set not found');
    }
    if (role !== 'admin' && (!current.uploadedById || current.uploadedById !== userId)) {
      throw new Error('Forbidden');
    }

    await prisma.dJSet.delete({
      where: { id: setId },
    });
    return current;
  }

  /**
   * Get all tracklists for a DJ set
   */
  async getTracklists(setId: string) {
    const tracklists = await prisma.tracklist.findMany({
      where: { setId },
      include: {
        uploader: {
          select: this.contributorUserSelect,
        },
        tracks: {
          orderBy: { position: 'asc' },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return await Promise.all(
      tracklists.map(async (tracklist) => {
        const contributor = await this.mapContributorProfile(tracklist.uploader);
        return {
          id: tracklist.id,
          setId: tracklist.setId,
          title: tracklist.title,
          isDefault: tracklist.isDefault,
          createdAt: tracklist.createdAt,
          updatedAt: tracklist.updatedAt,
          contributor,
          trackCount: tracklist.tracks.length,
        };
      })
    );
  }

  /**
   * Get a specific tracklist with tracks
   */
  async getTracklistById(tracklistId: string) {
    const tracklist = await prisma.tracklist.findUnique({
      where: { id: tracklistId },
      include: {
        uploader: {
          select: this.contributorUserSelect,
        },
        tracks: {
          orderBy: { position: 'asc' },
        },
      },
    });

    if (!tracklist) {
      return null;
    }

    const contributor = await this.mapContributorProfile(tracklist.uploader);
    return {
      id: tracklist.id,
      setId: tracklist.setId,
      title: tracklist.title,
      isDefault: tracklist.isDefault,
      createdAt: tracklist.createdAt,
      updatedAt: tracklist.updatedAt,
      contributor,
      tracks: tracklist.tracks,
    };
  }

  /**
   * Create a new tracklist for a DJ set
   */
  async createTracklist(
    setId: string,
    uploadedById: string,
    title: string | undefined,
    tracks: Omit<CreateTrackInput, 'setId'>[]
  ) {
    // Check if DJ set exists
    const djSet = await prisma.dJSet.findUnique({
      where: { id: setId },
      select: { id: true },
    });

    if (!djSet) {
      throw new Error('DJ set not found');
    }

    // Create tracklist with tracks
    const tracklist = await prisma.tracklist.create({
      data: {
        setId,
        uploadedById,
        title: title || null,
        isDefault: false,
      },
      include: {
        uploader: {
          select: this.contributorUserSelect,
        },
      },
    });

    // Add tracks to the tracklist
    const trackData = tracks.map((track, index) => ({
      tracklistId: tracklist.id,
      position: Number(track.position) || index + 1,
      startTime: track.startTime,
      endTime: track.endTime,
      title: track.title,
      artist: track.artist,
      status: track.status || 'released',
      spotifyUrl: track.spotifyUrl,
      spotifyId: track.spotifyId,
      spotifyUri: track.spotifyUri,
      neteaseUrl: track.neteaseUrl,
      neteaseId: track.neteaseId,
    }));

    await prisma.tracklistTrack.createMany({
      data: trackData,
    });

    // Return the complete tracklist
    return await this.getTracklistById(tracklist.id);
  }
}

export default new DJSetService();
