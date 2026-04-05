interface SpotifyImage {
  url: string;
  height: number;
  width: number;
}

interface SpotifyArtist {
  id: string;
  name: string;
  uri: string;
  popularity?: number;
  genres?: string[];
  followers?: {
    total?: number;
  };
  images?: SpotifyImage[];
  external_urls?: {
    spotify?: string;
  };
}

export interface SpotifyArtistProfile {
  id: string;
  name: string;
  uri: string;
  url: string | null;
  popularity: number;
  followers: number;
  genres: string[];
  imageUrl: string | null;
}

export class SpotifyUpstreamError extends Error {
  readonly code: string;
  readonly status?: number;

  constructor(code: string, message: string, status?: number) {
    super(message);
    this.name = 'SpotifyUpstreamError';
    this.code = code;
    this.status = status;
  }
}

class SpotifyArtistService {
  private token: string | null = null;
  private tokenExpiresAt = 0;
  private readonly cache = new Map<string, { data: SpotifyArtistProfile | null; expiresAt: number }>();
  private readonly cacheTtlMs = 5 * 60 * 1000;
  private readonly requestTimeoutMs = (() => {
    const parsed = Number(process.env.SPOTIFY_REQUEST_TIMEOUT_MS);
    if (!Number.isFinite(parsed)) return 5000;
    return Math.max(1000, Math.floor(parsed));
  })();
  private readonly maxRetryCount = (() => {
    const parsed = Number(process.env.SPOTIFY_RETRY_COUNT);
    if (!Number.isFinite(parsed)) return 1;
    return Math.max(0, Math.min(3, Math.floor(parsed)));
  })();

  private shouldLog(): boolean {
    return process.env.SPOTIFY_DEBUG_LOG !== '0';
  }

  private log(level: 'info' | 'warn' | 'error', event: string, payload?: Record<string, unknown>): void {
    if (!this.shouldLog()) return;
    const prefix = `[spotify-debug] ${event}`;
    if (payload) {
      console[level](prefix, payload);
      return;
    }
    console[level](prefix);
  }

  private async fetchWithTimeout(url: string, options?: RequestInit): Promise<Response> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.requestTimeoutMs);
    try {
      return await fetch(url, { ...options, signal: controller.signal });
    } finally {
      clearTimeout(timer);
    }
  }

  isConfigured(): boolean {
    return Boolean(process.env.SPOTIFY_CLIENT_ID && process.env.SPOTIFY_CLIENT_SECRET);
  }

  private async wait(ms: number): Promise<void> {
    await new Promise((resolve) => setTimeout(resolve, ms));
  }

  private parseRetryAfterMs(response: Response): number | null {
    const retryAfterRaw = response.headers.get('retry-after');
    if (!retryAfterRaw) return null;
    const seconds = Number(retryAfterRaw);
    if (Number.isFinite(seconds) && seconds > 0) {
      return Math.min(10_000, Math.floor(seconds * 1000));
    }
    return null;
  }

  private resetToken() {
    this.token = null;
    this.tokenExpiresAt = 0;
  }

  private async getAccessToken(): Promise<string | null> {
    if (!this.isConfigured()) {
      return null;
    }

    const now = Date.now();
    if (this.token && now < this.tokenExpiresAt - 30_000) {
      return this.token;
    }

    const clientId = process.env.SPOTIFY_CLIENT_ID as string;
    const clientSecret = process.env.SPOTIFY_CLIENT_SECRET as string;
    const basicAuth = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');

    this.log('info', 'token.request.start');

    for (let attempt = 0; attempt <= this.maxRetryCount; attempt += 1) {
      try {
        const response = await this.fetchWithTimeout('https://accounts.spotify.com/api/token', {
          method: 'POST',
          headers: {
            Authorization: `Basic ${basicAuth}`,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: new URLSearchParams({ grant_type: 'client_credentials' }).toString(),
        });

        if (response.ok) {
          const payload = (await response.json()) as { access_token: string; expires_in: number };
          this.token = payload.access_token;
          this.tokenExpiresAt = Date.now() + payload.expires_in * 1000;
          this.log('info', 'token.request.success', {
            attempt,
            expiresInSec: payload.expires_in,
          });
          return this.token;
        }

        this.log('warn', 'token.request.non_ok', {
          attempt,
          status: response.status,
        });

        if (response.status === 429 && attempt < this.maxRetryCount) {
          const delay = this.parseRetryAfterMs(response) ?? 600 * (attempt + 1);
          this.log('warn', 'token.request.retry_429', { attempt, delayMs: delay });
          await this.wait(delay);
          continue;
        }

        if (response.status >= 500 && attempt < this.maxRetryCount) {
          this.log('warn', 'token.request.retry_5xx', { attempt });
          await this.wait(400 * (attempt + 1));
          continue;
        }

        this.log('error', 'token.request.failed', {
          attempt,
          status: response.status,
        });
        return null;
      } catch (error) {
        this.log('warn', 'token.request.exception', {
          attempt,
          name: (error as Error).name,
          message: (error as Error).message,
        });
        if (attempt >= this.maxRetryCount) {
          this.log('error', 'token.request.give_up');
          return null;
        }
        await this.wait(400 * (attempt + 1));
      }
    }

    return null;
  }

  private async fetchSpotifyAuthorized(
    url: string,
    allowTokenRefresh = true,
    attempt = 0
  ): Promise<Response> {
    const token = await this.getAccessToken();
    if (!token) {
      throw new SpotifyUpstreamError('token_unavailable', 'Spotify token is unavailable');
    }

    const parsedUrl = new URL(url);
    const q = parsedUrl.searchParams.get('q');
    this.log('info', 'api.request.start', {
      attempt,
      path: parsedUrl.pathname,
      query: q ?? undefined,
      allowTokenRefresh,
    });

    try {
      const response = await this.fetchWithTimeout(url, {
        headers: { Authorization: `Bearer ${token}` },
      });

      this.log('info', 'api.request.response', {
        attempt,
        path: parsedUrl.pathname,
        status: response.status,
      });

      if (!response.ok) {
        let bodyPreview = '';
        try {
          bodyPreview = (await response.clone().text()).slice(0, 300);
        } catch (_error) {
          bodyPreview = '';
        }
        this.log('warn', 'api.request.non_ok_detail', {
          attempt,
          path: parsedUrl.pathname,
          status: response.status,
          statusText: response.statusText,
          contentType: response.headers.get('content-type') || '',
          bodyPreview,
        });
      }

      if (response.status === 401 && allowTokenRefresh) {
        this.log('warn', 'api.request.retry_401_refresh_token', {
          attempt,
          path: parsedUrl.pathname,
        });
        this.resetToken();
        return this.fetchSpotifyAuthorized(url, false, attempt + 1);
      }

      if (response.status === 429 && attempt < this.maxRetryCount) {
        const delay = this.parseRetryAfterMs(response) ?? 700 * (attempt + 1);
        this.log('warn', 'api.request.retry_429', {
          attempt,
          path: parsedUrl.pathname,
          delayMs: delay,
        });
        await this.wait(delay);
        return this.fetchSpotifyAuthorized(url, allowTokenRefresh, attempt + 1);
      }

      if (response.status >= 500 && attempt < this.maxRetryCount) {
        this.log('warn', 'api.request.retry_5xx', {
          attempt,
          path: parsedUrl.pathname,
        });
        await this.wait(500 * (attempt + 1));
        return this.fetchSpotifyAuthorized(url, allowTokenRefresh, attempt + 1);
      }

      return response;
    } catch (error) {
      this.log('warn', 'api.request.exception', {
        attempt,
        path: parsedUrl.pathname,
        name: (error as Error).name,
        message: (error as Error).message,
      });
      if (attempt >= this.maxRetryCount) {
        this.log('error', 'api.request.give_up', {
          path: parsedUrl.pathname,
        });
        throw new SpotifyUpstreamError(
          'request_timeout',
          `Spotify request timeout for ${parsedUrl.pathname}`
        );
      }
      await this.wait(500 * (attempt + 1));
      return this.fetchSpotifyAuthorized(url, allowTokenRefresh, attempt + 1);
    }
  }

  private normalizeArtist(artist: SpotifyArtist): SpotifyArtistProfile {
    const sortedImages = [...(artist.images ?? [])].sort((a, b) => b.width - a.width);
    const preferredImage = sortedImages[0]?.url ?? null;
    return {
      id: artist.id,
      name: artist.name,
      uri: artist.uri,
      url: artist.external_urls?.spotify ?? null,
      popularity: artist.popularity ?? 0,
      followers: artist.followers?.total ?? 0,
      genres: artist.genres ?? [],
      imageUrl: preferredImage,
    };
  }

  private hasRichArtistFields(artist: SpotifyArtist): boolean {
    return (
      typeof artist.popularity === 'number' &&
      Array.isArray(artist.genres) &&
      typeof artist.followers?.total === 'number'
    );
  }

  private async hydrateArtistsByIds(artistIds: string[]): Promise<Map<string, SpotifyArtistProfile>> {
    const uniqueIds = Array.from(
      new Set(
        artistIds
          .map((item) => item.trim())
          .filter(Boolean)
      )
    );
    const hydrated = new Map<string, SpotifyArtistProfile>();
    if (uniqueIds.length === 0) {
      return hydrated;
    }

    for (const artistId of uniqueIds) {
      try {
        const response = await this.fetchSpotifyAuthorized(
          `https://api.spotify.com/v1/artists/${encodeURIComponent(artistId)}`
        );
        if (!response.ok) {
          this.log('warn', 'search.hydrate.non_ok', {
            status: response.status,
            artistId,
          });
          continue;
        }

        const artist = (await response.json()) as SpotifyArtist;
        if (!artist?.id) continue;
        const profile = this.normalizeArtist(artist);
        hydrated.set(artist.id, profile);
        this.setCache(`id:${artist.id}`, profile);
      } catch (error) {
        this.log('warn', 'search.hydrate.exception_id', {
          artistId,
          name: (error as Error).name,
          message: (error as Error).message,
        });
      }
    }

    return hydrated;
  }

  private getCache(cacheKey: string): SpotifyArtistProfile | null | undefined {
    const entry = this.cache.get(cacheKey);
    if (!entry) {
      return undefined;
    }
    if (Date.now() >= entry.expiresAt) {
      this.cache.delete(cacheKey);
      return undefined;
    }
    return entry.data;
  }

  private setCache(cacheKey: string, data: SpotifyArtistProfile | null) {
    this.cache.set(cacheKey, { data, expiresAt: Date.now() + this.cacheTtlMs });
  }

  async getArtistById(artistId: string): Promise<SpotifyArtistProfile | null> {
    if (!artistId || !this.isConfigured()) {
      return null;
    }

    const cacheKey = `id:${artistId}`;
    const cached = this.getCache(cacheKey);
    if (cached !== undefined) {
      return cached;
    }

    try {
      const response = await this.fetchSpotifyAuthorized(
        `https://api.spotify.com/v1/artists/${encodeURIComponent(artistId)}`
      );

      if (!response.ok) {
        this.setCache(cacheKey, null);
        return null;
      }

      const artist = (await response.json()) as SpotifyArtist;
      const normalized = this.normalizeArtist(artist);
      this.setCache(cacheKey, normalized);
      this.setCache(`name:${artist.name.trim().toLowerCase()}`, normalized);
      return normalized;
    } catch (error) {
      if (error instanceof SpotifyUpstreamError) {
        throw error;
      }
      this.setCache(cacheKey, null);
      return null;
    }
  }

  async searchArtistsByName(name: string, limit = 10): Promise<SpotifyArtistProfile[]> {
    const trimmed = name.trim();
    if (!trimmed || !this.isConfigured()) {
      return [];
    }

    this.log('info', 'search.start', {
      query: trimmed,
      limit,
    });

    const safeLimit = Math.max(1, Math.min(20, Math.floor(limit)));
    const buildSearchURL = (targetLimit: number): string =>
      `https://api.spotify.com/v1/search?${new URLSearchParams({
        q: trimmed,
        type: 'artist',
        limit: String(targetLimit),
      }).toString()}`;

    try {
      let response = await this.fetchSpotifyAuthorized(buildSearchURL(safeLimit));

      if (response && !response.ok && response.status === 400 && safeLimit !== 10) {
        let bodyPreview = '';
        try {
          bodyPreview = (await response.clone().text()).toLowerCase();
        } catch (_error) {
          bodyPreview = '';
        }
        if (bodyPreview.includes('invalid limit')) {
          this.log('warn', 'search.limit_fallback_to_10', {
            query: trimmed,
            requestedLimit: safeLimit,
          });
          response = await this.fetchSpotifyAuthorized(buildSearchURL(10));
        }
      }

      if (!response.ok) {
        this.log('warn', 'search.non_ok', {
          query: trimmed,
          status: response.status,
        });
        throw new SpotifyUpstreamError(
          'search_non_ok',
          `Spotify search failed with status ${response.status}`,
          response.status
        );
      }

      const payload = (await response.json()) as { artists?: { items?: SpotifyArtist[] } };
      const items = payload.artists?.items ?? [];
      if (items.length === 0) {
        this.log('info', 'search.empty', {
          query: trimmed,
        });
        return [];
      }

      const normalizedName = trimmed.toLowerCase();
      const dedupMap = new Map<string, SpotifyArtist>();
      for (const item of items) {
        if (!item?.id || dedupMap.has(item.id)) continue;
        dedupMap.set(item.id, item);
      }

      const sorted = Array.from(dedupMap.values()).sort((a, b) => {
        const aExact = a.name.trim().toLowerCase() === normalizedName ? 1 : 0;
        const bExact = b.name.trim().toLowerCase() === normalizedName ? 1 : 0;
        if (aExact !== bExact) {
          return bExact - aExact;
        }
        const followersDiff = (b.followers?.total ?? 0) - (a.followers?.total ?? 0);
        if (followersDiff !== 0) {
          return followersDiff;
        }
        return (b.popularity ?? 0) - (a.popularity ?? 0);
      });

      const needsHydrationIds = sorted
        .filter((item) => !this.hasRichArtistFields(item))
        .map((item) => item.id);

      let hydratedById = new Map<string, SpotifyArtistProfile>();
      if (needsHydrationIds.length > 0) {
        this.log('info', 'search.hydrate.start', {
          query: trimmed,
          count: needsHydrationIds.length,
        });
        try {
          hydratedById = await this.hydrateArtistsByIds(needsHydrationIds);
          this.log('info', 'search.hydrate.done', {
            query: trimmed,
            hydratedCount: hydratedById.size,
          });
        } catch (error) {
          this.log('warn', 'search.hydrate.exception', {
            query: trimmed,
            name: (error as Error).name,
            message: (error as Error).message,
          });
        }
      }

      const profiles = sorted.map((item) => hydratedById.get(item.id) ?? this.normalizeArtist(item));
      for (const profile of profiles) {
        this.setCache(`id:${profile.id}`, profile);
      }
      if (profiles.length > 0) {
        this.setCache(`name:${normalizedName}`, profiles[0]);
      }
      this.log('info', 'search.success', {
        query: trimmed,
        resultCount: profiles.length,
      });
      return profiles;
    } catch (error) {
      if (error instanceof SpotifyUpstreamError) {
        throw error;
      }
      this.log('error', 'search.exception', {
        query: trimmed,
        name: (error as Error).name,
        message: (error as Error).message,
      });
      throw error;
    }
  }

  async searchArtistByName(name: string): Promise<SpotifyArtistProfile | null> {
    const trimmed = name.trim();
    if (!trimmed || !this.isConfigured()) {
      return null;
    }

    const cacheKey = `name:${trimmed.toLowerCase()}`;
    const cached = this.getCache(cacheKey);
    if (cached !== undefined) {
      return cached;
    }

    try {
      const candidates = await this.searchArtistsByName(trimmed, 10);
      const best = candidates[0] ?? null;
      this.setCache(cacheKey, best);
      return best;
    } catch {
      this.setCache(cacheKey, null);
      return null;
    }
  }
}

export default new SpotifyArtistService();
