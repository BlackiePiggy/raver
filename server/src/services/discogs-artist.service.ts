interface DiscogsSearchResult {
  id: number;
  type?: string;
  title?: string;
  thumb?: string;
  cover_image?: string;
  resource_url?: string;
  uri?: string;
}

interface DiscogsSearchResponse {
  results?: DiscogsSearchResult[];
}

interface DiscogsImage {
  type?: string;
  uri?: string;
  uri150?: string;
  width?: number;
  height?: number;
}

interface DiscogsNamedEntity {
  id?: number;
  name?: string;
  resource_url?: string;
  active?: boolean;
}

interface DiscogsArtistDetailResponse {
  id: number;
  name: string;
  realname?: string;
  profile?: string;
  urls?: string[];
  namevariations?: string[];
  aliases?: DiscogsNamedEntity[];
  groups?: DiscogsNamedEntity[];
  images?: DiscogsImage[];
  uri?: string;
  resource_url?: string;
}

export interface DiscogsArtistSearchProfile {
  artistId: number;
  name: string;
  thumbUrl: string | null;
  coverImageUrl: string | null;
  resourceUrl: string | null;
  uri: string | null;
}

export interface DiscogsArtistDetailProfile {
  artistId: number;
  name: string;
  realName: string | null;
  profile: string | null;
  urls: string[];
  nameVariations: string[];
  aliases: string[];
  groups: string[];
  primaryImageUrl: string | null;
  thumbnailImageUrl: string | null;
  resourceUrl: string | null;
  uri: string | null;
}

export class DiscogsUpstreamError extends Error {
  readonly code: string;
  readonly status?: number;

  constructor(code: string, message: string, status?: number) {
    super(message);
    this.name = 'DiscogsUpstreamError';
    this.code = code;
    this.status = status;
  }
}

class DiscogsArtistService {
  private readonly cache = new Map<string, { data: unknown; expiresAt: number }>();
  private readonly cacheTtlMs = 5 * 60 * 1000;
  private readonly requestTimeoutMs = (() => {
    const parsed = Number(process.env.DISCOGS_REQUEST_TIMEOUT_MS);
    if (!Number.isFinite(parsed)) return 7000;
    return Math.max(1000, Math.floor(parsed));
  })();
  private readonly maxRetryCount = (() => {
    const parsed = Number(process.env.DISCOGS_RETRY_COUNT);
    if (!Number.isFinite(parsed)) return 1;
    return Math.max(0, Math.min(3, Math.floor(parsed)));
  })();
  private readonly userAgent = process.env.DISCOGS_USER_AGENT?.trim() || 'RaverHub/1.0 +https://raver.app';

  private shouldLog(): boolean {
    return process.env.DISCOGS_DEBUG_LOG === '1';
  }

  private log(level: 'info' | 'warn' | 'error', event: string, payload?: Record<string, unknown>): void {
    if (!this.shouldLog()) return;
    const prefix = `[discogs-debug] ${event}`;
    if (payload) {
      console[level](prefix, payload);
      return;
    }
    console[level](prefix);
  }

  private async wait(ms: number): Promise<void> {
    await new Promise((resolve) => setTimeout(resolve, ms));
  }

  private getToken(): string | null {
    const token = process.env.DISCOGS_TOKEN?.trim();
    return token && token.length > 0 ? token : null;
  }

  isConfigured(): boolean {
    return Boolean(this.getToken());
  }

  private sanitizeDiscogsImageUrl(raw: string | null | undefined): string | null {
    if (!raw) return null;
    const trimmed = raw.trim();
    if (!trimmed) return null;
    if (trimmed.includes('/images/spacer.gif')) return null;
    return trimmed;
  }

  private getCache<T>(cacheKey: string): T | undefined {
    const entry = this.cache.get(cacheKey);
    if (!entry) return undefined;
    if (Date.now() >= entry.expiresAt) {
      this.cache.delete(cacheKey);
      return undefined;
    }
    return entry.data as T;
  }

  private setCache<T>(cacheKey: string, data: T): void {
    this.cache.set(cacheKey, { data, expiresAt: Date.now() + this.cacheTtlMs });
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

  private async fetchWithTimeout(url: string, options?: RequestInit): Promise<Response> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.requestTimeoutMs);
    try {
      return await fetch(url, { ...options, signal: controller.signal });
    } finally {
      clearTimeout(timer);
    }
  }

  private async fetchDiscogsAuthorized(url: string, attempt = 0): Promise<Response> {
    const token = this.getToken();
    if (!token) {
      throw new DiscogsUpstreamError('token_unavailable', 'Discogs token is unavailable');
    }

    const parsedUrl = new URL(url);
    this.log('info', 'api.request.start', {
      attempt,
      path: parsedUrl.pathname,
      query: parsedUrl.search || undefined,
    });

    try {
      const response = await this.fetchWithTimeout(url, {
        method: 'GET',
        headers: {
          Authorization: `Discogs token=${token}`,
          'Content-Type': 'application/json',
          Accept: 'application/json',
          'User-Agent': this.userAgent,
        },
      });

      this.log('info', 'api.request.response', {
        attempt,
        path: parsedUrl.pathname,
        status: response.status,
      });

      if (response.status === 429 && attempt < this.maxRetryCount) {
        const delay = this.parseRetryAfterMs(response) ?? 900 * (attempt + 1);
        this.log('warn', 'api.request.retry_429', {
          attempt,
          path: parsedUrl.pathname,
          delayMs: delay,
        });
        await this.wait(delay);
        return this.fetchDiscogsAuthorized(url, attempt + 1);
      }

      if (response.status >= 500 && attempt < this.maxRetryCount) {
        this.log('warn', 'api.request.retry_5xx', {
          attempt,
          path: parsedUrl.pathname,
        });
        await this.wait(600 * (attempt + 1));
        return this.fetchDiscogsAuthorized(url, attempt + 1);
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
        throw new DiscogsUpstreamError(
          'request_timeout',
          `Discogs request timeout for ${parsedUrl.pathname}`
        );
      }
      await this.wait(600 * (attempt + 1));
      return this.fetchDiscogsAuthorized(url, attempt + 1);
    }
  }

  private normalizeSearchResult(item: DiscogsSearchResult): DiscogsArtistSearchProfile | null {
    const artistId = Number(item.id);
    if (!Number.isFinite(artistId) || artistId <= 0) return null;

    const name = (item.title ?? '').trim();
    if (!name) return null;

    return {
      artistId,
      name,
      thumbUrl: this.sanitizeDiscogsImageUrl(item.thumb),
      coverImageUrl: this.sanitizeDiscogsImageUrl(item.cover_image),
      resourceUrl: item.resource_url?.trim() || null,
      uri: item.uri?.trim() || null,
    };
  }

  private normalizeDetail(raw: DiscogsArtistDetailResponse): DiscogsArtistDetailProfile {
    const images = Array.isArray(raw.images) ? raw.images : [];
    const primaryImage =
      images.find((item) => (item.type ?? '').toLowerCase() === 'primary') ?? images[0] ?? null;
    const primaryImageUrl = this.sanitizeDiscogsImageUrl(primaryImage?.uri ?? null);
    const thumbnailImageUrl = this.sanitizeDiscogsImageUrl(primaryImage?.uri150 ?? null);

    const aliasNames = (raw.aliases ?? [])
      .map((item) => (item.name ?? '').trim())
      .filter(Boolean);
    const groupNames = (raw.groups ?? [])
      .map((item) => (item.name ?? '').trim())
      .filter(Boolean);
    const nameVariations = (raw.namevariations ?? [])
      .map((item) => item.trim())
      .filter(Boolean);
    const urls = (raw.urls ?? [])
      .map((item) => item.trim())
      .filter(Boolean);

    return {
      artistId: raw.id,
      name: (raw.name ?? '').trim(),
      realName: raw.realname?.trim() || null,
      profile: raw.profile?.trim() || null,
      urls,
      nameVariations,
      aliases: aliasNames,
      groups: groupNames,
      primaryImageUrl,
      thumbnailImageUrl,
      resourceUrl: raw.resource_url?.trim() || null,
      uri: raw.uri?.trim() || null,
    };
  }

  async searchArtistsByName(name: string, limit = 10): Promise<DiscogsArtistSearchProfile[]> {
    const trimmed = name.trim();
    if (!trimmed || !this.isConfigured()) {
      return [];
    }

    const safeLimit = Math.max(1, Math.min(50, Math.floor(limit)));
    const cacheKey = `search:${trimmed.toLowerCase()}:${safeLimit}`;
    const cached = this.getCache<DiscogsArtistSearchProfile[]>(cacheKey);
    if (cached !== undefined) {
      return cached;
    }

    const searchUrl = `https://api.discogs.com/database/search?${new URLSearchParams({
      q: trimmed,
      type: 'artist',
      per_page: String(safeLimit),
    }).toString()}`;

    const response = await this.fetchDiscogsAuthorized(searchUrl);
    if (!response.ok) {
      throw new DiscogsUpstreamError(
        'search_non_ok',
        `Discogs search failed with status ${response.status}`,
        response.status
      );
    }

    const payload = (await response.json()) as DiscogsSearchResponse;
    const items = (payload.results ?? [])
      .filter((item) => !item.type || item.type === 'artist')
      .map((item) => this.normalizeSearchResult(item))
      .filter((item): item is DiscogsArtistSearchProfile => item !== null);

    const normalizedName = trimmed.toLowerCase();
    const dedup = new Map<number, DiscogsArtistSearchProfile>();
    for (const item of items) {
      if (!dedup.has(item.artistId)) {
        dedup.set(item.artistId, item);
      }
    }

    const sorted = Array.from(dedup.values()).sort((a, b) => {
      const aExact = a.name.trim().toLowerCase() === normalizedName ? 1 : 0;
      const bExact = b.name.trim().toLowerCase() === normalizedName ? 1 : 0;
      if (aExact !== bExact) {
        return bExact - aExact;
      }
      const aHasImage = a.thumbUrl || a.coverImageUrl ? 1 : 0;
      const bHasImage = b.thumbUrl || b.coverImageUrl ? 1 : 0;
      if (aHasImage !== bHasImage) {
        return bHasImage - aHasImage;
      }
      return a.name.localeCompare(b.name);
    });

    this.setCache(cacheKey, sorted);
    return sorted;
  }

  async getArtistById(artistId: number): Promise<DiscogsArtistDetailProfile | null> {
    if (!Number.isFinite(artistId) || artistId <= 0 || !this.isConfigured()) {
      return null;
    }

    const cacheKey = `artist:${artistId}`;
    const cached = this.getCache<DiscogsArtistDetailProfile | null>(cacheKey);
    if (cached !== undefined) {
      return cached;
    }

    const detailUrl = `https://api.discogs.com/artists/${artistId}`;
    const response = await this.fetchDiscogsAuthorized(detailUrl);
    if (response.status === 404) {
      this.setCache(cacheKey, null);
      return null;
    }
    if (!response.ok) {
      throw new DiscogsUpstreamError(
        'detail_non_ok',
        `Discogs artist detail failed with status ${response.status}`,
        response.status
      );
    }

    const payload = (await response.json()) as DiscogsArtistDetailResponse;
    const normalized = this.normalizeDetail(payload);
    this.setCache(cacheKey, normalized);
    return normalized;
  }
}

export default new DiscogsArtistService();
