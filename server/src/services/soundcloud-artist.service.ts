interface SoundCloudUserRaw {
  id?: string | number;
  username?: string;
  full_name?: string;
  avatar_url?: string;
  permalink?: string;
  permalink_url?: string;
  city?: string | null;
  country?: string | null;
  description?: string | null;
  website?: string | null;
  track_count?: number;
  playlist_count?: number;
  followers_count?: number;
  public_favorites_count?: number;
}

interface SoundCloudWebProfileRaw {
  service?: string | null;
  url?: string | null;
}

interface SoundCloudSearchPayload {
  collection?: SoundCloudUserRaw[];
}

interface SoundCloudOAuthPayload {
  access_token?: string;
  expires_in?: number;
}

type SoundCloudWebProfileLinks = {
  website: string | null;
  spotifyUrl: string | null;
  instagramUrl: string | null;
  facebookUrl: string | null;
  twitterUrl: string | null;
  youtubeUrl: string | null;
};

type SoundCloudSearchOptions = {
  enrichWebProfiles?: boolean;
};

export interface SoundCloudArtistProfile {
  soundcloudId: string;
  name: string;
  username: string;
  avatarUrl: string | null;
  permalink: string | null;
  permalinkUrl: string | null;
  city: string | null;
  country: string | null;
  description: string | null;
  website: string | null;
  spotifyUrl: string | null;
  instagramUrl: string | null;
  facebookUrl: string | null;
  twitterUrl: string | null;
  youtubeUrl: string | null;
  trackCount: number;
  playlistCount: number;
  followersCount: number;
  publicFavoritesCount: number;
}

export class SoundCloudUpstreamError extends Error {
  readonly code: string;
  readonly status?: number;

  constructor(code: string, message: string, status?: number) {
    super(message);
    this.name = 'SoundCloudUpstreamError';
    this.code = code;
    this.status = status;
  }
}

class SoundCloudArtistService {
  private token: string | null = null;
  private tokenExpiresAt = 0;
  private readonly cache = new Map<string, { data: SoundCloudArtistProfile[]; expiresAt: number }>();
  private readonly cacheTtlMs = 5 * 60 * 1000;
  private readonly minRequestIntervalMs = (() => {
    const parsed = Number(process.env.SOUNDCLOUD_MIN_REQUEST_INTERVAL_MS);
    if (!Number.isFinite(parsed) || parsed <= 0) return 0;
    return Math.floor(parsed);
  })();
  private readonly requestTimeoutMs = (() => {
    const parsed = Number(process.env.SOUNDCLOUD_REQUEST_TIMEOUT_MS);
    if (!Number.isFinite(parsed)) return 12000;
    return Math.max(1000, Math.floor(parsed));
  })();
  private readonly maxRetryCount = (() => {
    const parsed = Number(process.env.SOUNDCLOUD_RETRY_COUNT);
    if (!Number.isFinite(parsed)) return 1;
    return Math.max(0, Math.min(3, Math.floor(parsed)));
  })();
  private requestGate: Promise<void> = Promise.resolve();
  private lastRequestAtMs = 0;

  private getClientID(): string | null {
    const value =
      process.env.SOUNDCLOUD_CLIENT_ID ??
      process.env.SoundCloud_CLIENT_ID ??
      null;
    const trimmed = typeof value === 'string' ? value.trim() : '';
    return trimmed || null;
  }

  private getClientSecret(): string | null {
    const value =
      process.env.SOUNDCLOUD_CLIENT_SECRET ??
      process.env.SoundCloud_CLIENT_SECRET ??
      null;
    const trimmed = typeof value === 'string' ? value.trim() : '';
    return trimmed || null;
  }

  isConfigured(): boolean {
    return Boolean(this.getClientID() && this.getClientSecret());
  }

  private shouldLog(): boolean {
    return process.env.SOUNDCLOUD_DEBUG_LOG === '1';
  }

  private log(level: 'info' | 'warn' | 'error', event: string, payload?: Record<string, unknown>): void {
    if (!this.shouldLog()) return;
    const prefix = `[soundcloud-debug] ${event}`;
    if (payload) {
      console[level](prefix, payload);
      return;
    }
    console[level](prefix);
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

  private getCache(cacheKey: string): SoundCloudArtistProfile[] | undefined {
    const entry = this.cache.get(cacheKey);
    if (!entry) return undefined;
    if (Date.now() >= entry.expiresAt) {
      this.cache.delete(cacheKey);
      return undefined;
    }
    return entry.data;
  }

  private setCache(cacheKey: string, data: SoundCloudArtistProfile[]): void {
    this.cache.set(cacheKey, { data, expiresAt: Date.now() + this.cacheTtlMs });
  }

  private async fetchWithTimeout(url: string, options?: RequestInit): Promise<Response> {
    await this.waitForRequestSlot();
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.requestTimeoutMs);
    try {
      return await fetch(url, { ...options, signal: controller.signal });
    } finally {
      clearTimeout(timer);
    }
  }

  private async waitForRequestSlot(): Promise<void> {
    if (this.minRequestIntervalMs <= 0) return;

    this.requestGate = this.requestGate
      .then(async () => {
      const now = Date.now();
      const nextAllowedAt = this.lastRequestAtMs + this.minRequestIntervalMs;
      const waitMs = Math.max(0, nextAllowedAt - now);
      if (waitMs > 0) {
        this.log('info', 'api.request.throttle_wait', { waitMs });
        await this.wait(waitMs);
      }
      this.lastRequestAtMs = Date.now();
      })
      .catch(() => undefined);

    await this.requestGate;
  }

  private resetToken(): void {
    this.token = null;
    this.tokenExpiresAt = 0;
  }

  private async getAccessToken(): Promise<string> {
    const now = Date.now();
    if (this.token && now < this.tokenExpiresAt - 30_000) {
      return this.token;
    }

    const clientID = this.getClientID();
    const clientSecret = this.getClientSecret();
    if (!clientID || !clientSecret) {
      throw new SoundCloudUpstreamError('credentials_missing', 'SoundCloud client credentials are missing');
    }

    const basicAuth = Buffer.from(`${clientID}:${clientSecret}`).toString('base64');

    let response: Response;
    try {
      response = await this.fetchWithTimeout('https://secure.soundcloud.com/oauth/token', {
        method: 'POST',
        headers: {
          Accept: 'application/json; charset=utf-8',
          'Content-Type': 'application/x-www-form-urlencoded',
          Authorization: `Basic ${basicAuth}`,
        },
        body: new URLSearchParams({ grant_type: 'client_credentials' }).toString(),
      });
    } catch (error) {
      this.resetToken();
      throw new SoundCloudUpstreamError('oauth_timeout', (error as Error).message);
    }

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      this.resetToken();
      throw new SoundCloudUpstreamError(
        'oauth_non_ok',
        `SoundCloud oauth failed with status ${response.status}${body ? `: ${body}` : ''}`,
        response.status
      );
    }

    const payload = (await response.json()) as SoundCloudOAuthPayload;
    const accessToken = typeof payload.access_token === 'string' ? payload.access_token.trim() : '';
    if (!accessToken) {
      this.resetToken();
      throw new SoundCloudUpstreamError('oauth_no_token', 'SoundCloud oauth response has no access_token');
    }

    const expiresIn = Number(payload.expires_in);
    const ttlMs = Number.isFinite(expiresIn) && expiresIn > 0
      ? Math.max(60_000, Math.floor(expiresIn * 1000))
      : 55 * 60 * 1000;
    this.token = accessToken;
    this.tokenExpiresAt = Date.now() + ttlMs;
    return accessToken;
  }

  private toNonNegativeInt(value: unknown): number {
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed < 0) return 0;
    return Math.floor(parsed);
  }

  private normalizeUser(raw: SoundCloudUserRaw): SoundCloudArtistProfile | null {
    const idCandidate = raw.id;
    const soundcloudId = String(idCandidate ?? '').trim();
    if (!soundcloudId) return null;

    const username = String(raw.username ?? '').trim();
    const fullName = String(raw.full_name ?? '').trim();
    const name = username || fullName;
    if (!name) return null;

    const avatarUrl = typeof raw.avatar_url === 'string' ? raw.avatar_url.trim() : '';
    const permalink = typeof raw.permalink === 'string' ? raw.permalink.trim() : '';
    const permalinkUrl = typeof raw.permalink_url === 'string' ? raw.permalink_url.trim() : '';
    const city = typeof raw.city === 'string' ? raw.city.trim() : '';
    const country = typeof raw.country === 'string' ? raw.country.trim() : '';
    const description = typeof raw.description === 'string' ? raw.description.trim() : '';
    const website = typeof raw.website === 'string' ? raw.website.trim() : '';

    return {
      soundcloudId,
      name,
      username: username || name,
      avatarUrl: avatarUrl || null,
      permalink: permalink || null,
      permalinkUrl: permalinkUrl || null,
      city: city || null,
      country: country || null,
      description: description || null,
      website: website || null,
      spotifyUrl: null,
      instagramUrl: null,
      facebookUrl: null,
      twitterUrl: null,
      youtubeUrl: null,
      trackCount: this.toNonNegativeInt(raw.track_count),
      playlistCount: this.toNonNegativeInt(raw.playlist_count),
      followersCount: this.toNonNegativeInt(raw.followers_count),
      publicFavoritesCount: this.toNonNegativeInt(raw.public_favorites_count),
    };
  }

  private extractWebProfileLinks(profiles: SoundCloudWebProfileRaw[]): SoundCloudWebProfileLinks {
    const links: SoundCloudWebProfileLinks = {
      website: null as string | null,
      spotifyUrl: null as string | null,
      instagramUrl: null as string | null,
      facebookUrl: null as string | null,
      twitterUrl: null as string | null,
      youtubeUrl: null as string | null,
    };

    const unmatchedWebsiteCandidates: string[] = [];
    for (const profile of profiles) {
      const url = typeof profile?.url === 'string' ? profile.url.trim() : '';
      if (!url) continue;

      const service = typeof profile?.service === 'string' ? profile.service.trim().toLowerCase() : '';
      if (service.includes('spotify')) {
        if (!links.spotifyUrl) links.spotifyUrl = url;
        continue;
      }
      if (service.includes('instagram')) {
        if (!links.instagramUrl) links.instagramUrl = url;
        continue;
      }
      if (service.includes('facebook')) {
        if (!links.facebookUrl) links.facebookUrl = url;
        continue;
      }
      if (service === 'x' || service.includes('twitter')) {
        if (!links.twitterUrl) links.twitterUrl = url;
        continue;
      }
      if (service.includes('youtube')) {
        if (!links.youtubeUrl) links.youtubeUrl = url;
        continue;
      }
      if (service.includes('website') || service.includes('official') || service.includes('homepage')) {
        if (!links.website) links.website = url;
        continue;
      }
      unmatchedWebsiteCandidates.push(url);
    }

    if (!links.website && unmatchedWebsiteCandidates.length > 0) {
      links.website = unmatchedWebsiteCandidates[0];
    }
    return links;
  }

  private async fetchUserWebProfiles(soundcloudId: string): Promise<SoundCloudWebProfileRaw[]> {
    const id = soundcloudId.trim();
    if (!id) return [];

    const url = `https://api.soundcloud.com/users/${encodeURIComponent(id)}/web-profiles`;
    let response: Response;
    try {
      response = await this.fetchSoundCloudAuthorized(url, true, 0);
    } catch (_error) {
      response = await this.fetchSoundCloudWithClientID(url, 0);
    }

    if (!response.ok) return [];
    const payload = await response.json().catch(() => null);
    if (!Array.isArray(payload)) return [];
    return payload as SoundCloudWebProfileRaw[];
  }

  private async enrichUserWithWebProfiles(item: SoundCloudArtistProfile): Promise<SoundCloudArtistProfile> {
    const links = await this.getWebProfileLinksByUserId(item.soundcloudId);
    return {
      ...item,
      website: links.website || item.website || null,
      spotifyUrl: links.spotifyUrl,
      instagramUrl: links.instagramUrl,
      facebookUrl: links.facebookUrl,
      twitterUrl: links.twitterUrl,
      youtubeUrl: links.youtubeUrl,
    };
  }

  async getWebProfileLinksByUserId(soundcloudId: string): Promise<SoundCloudWebProfileLinks> {
    const profiles = await this.fetchUserWebProfiles(soundcloudId).catch(() => []);
    if (!profiles.length) {
      return {
        website: null,
        spotifyUrl: null,
        instagramUrl: null,
        facebookUrl: null,
        twitterUrl: null,
        youtubeUrl: null,
      };
    }
    return this.extractWebProfileLinks(profiles);
  }

  private async fetchSoundCloudAuthorized(url: string, allowRefresh = true, attempt = 0): Promise<Response> {
    const token = await this.getAccessToken();
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
          Authorization: `OAuth ${token}`,
          Accept: 'application/json; charset=utf-8',
        },
      });

      this.log('info', 'api.request.response', {
        attempt,
        path: parsedUrl.pathname,
        status: response.status,
      });

      if (response.status === 401 && allowRefresh) {
        this.log('warn', 'api.request.retry_401', {
          path: parsedUrl.pathname,
        });
        this.resetToken();
        return this.fetchSoundCloudAuthorized(url, false, attempt + 1);
      }

      if (response.status === 429 && attempt < this.maxRetryCount) {
        const delay = this.parseRetryAfterMs(response) ?? 1000 * (attempt + 1);
        this.log('warn', 'api.request.retry_429', {
          attempt,
          path: parsedUrl.pathname,
          delayMs: delay,
        });
        await this.wait(delay);
        return this.fetchSoundCloudAuthorized(url, allowRefresh, attempt + 1);
      }

      if (response.status >= 500 && attempt < this.maxRetryCount) {
        this.log('warn', 'api.request.retry_5xx', {
          attempt,
          path: parsedUrl.pathname,
        });
        await this.wait(700 * (attempt + 1));
        return this.fetchSoundCloudAuthorized(url, allowRefresh, attempt + 1);
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
        throw new SoundCloudUpstreamError(
          'request_timeout',
          `SoundCloud request timeout for ${parsedUrl.pathname}`
        );
      }
      await this.wait(700 * (attempt + 1));
      return this.fetchSoundCloudAuthorized(url, allowRefresh, attempt + 1);
    }
  }

  private buildClientIDURL(url: string): string {
    const clientID = this.getClientID();
    if (!clientID) {
      throw new SoundCloudUpstreamError('credentials_missing', 'SoundCloud client id is missing');
    }
    const parsed = new URL(url);
    if (!parsed.searchParams.get('client_id')) {
      parsed.searchParams.set('client_id', clientID);
    }
    return parsed.toString();
  }

  private async fetchSoundCloudWithClientID(url: string, attempt = 0): Promise<Response> {
    const directURL = this.buildClientIDURL(url);
    const parsedUrl = new URL(directURL);
    this.log('info', 'api.client_id.request.start', {
      attempt,
      path: parsedUrl.pathname,
      query: parsedUrl.search || undefined,
    });

    try {
      const response = await this.fetchWithTimeout(directURL, {
        method: 'GET',
        headers: {
          Accept: 'application/json; charset=utf-8',
        },
      });
      this.log('info', 'api.client_id.request.response', {
        attempt,
        path: parsedUrl.pathname,
        status: response.status,
      });

      if (response.status === 429 && attempt < this.maxRetryCount) {
        const delay = this.parseRetryAfterMs(response) ?? 1000 * (attempt + 1);
        await this.wait(delay);
        return this.fetchSoundCloudWithClientID(url, attempt + 1);
      }
      if (response.status >= 500 && attempt < this.maxRetryCount) {
        await this.wait(700 * (attempt + 1));
        return this.fetchSoundCloudWithClientID(url, attempt + 1);
      }

      return response;
    } catch (error) {
      if (attempt >= this.maxRetryCount) {
        throw new SoundCloudUpstreamError('client_id_timeout', (error as Error).message);
      }
      await this.wait(700 * (attempt + 1));
      return this.fetchSoundCloudWithClientID(url, attempt + 1);
    }
  }

  async searchUsersByName(name: string, limit = 10, options?: SoundCloudSearchOptions): Promise<SoundCloudArtistProfile[]> {
    const trimmed = name.trim();
    if (!trimmed || !this.isConfigured()) return [];
    const enrichWebProfiles = options?.enrichWebProfiles !== false;

    const safeLimit = Math.max(1, Math.min(50, Math.floor(limit)));
    const cacheKey = `search:${trimmed.toLowerCase()}:${safeLimit}:enrich=${enrichWebProfiles ? '1' : '0'}`;
    const cached = this.getCache(cacheKey);
    if (cached) return cached;

    const url = `https://api.soundcloud.com/users?${new URLSearchParams({
      q: trimmed,
      limit: String(safeLimit),
    }).toString()}`;

    let response: Response;
    try {
      response = await this.fetchSoundCloudAuthorized(url, true, 0);
    } catch (error) {
      this.log('warn', 'search.oauth_fallback_to_client_id', {
        query: trimmed,
        message: (error as Error).message,
      });
      response = await this.fetchSoundCloudWithClientID(url, 0);
    }
    if (!response.ok) {
      throw new SoundCloudUpstreamError(
        'search_non_ok',
        `SoundCloud search failed with status ${response.status}`,
        response.status
      );
    }

    const payload = (await response.json()) as SoundCloudSearchPayload | SoundCloudUserRaw[];
    const rawItems = Array.isArray(payload)
      ? payload
      : Array.isArray(payload?.collection)
        ? payload.collection
        : [];

    const dedup = new Map<string, SoundCloudArtistProfile>();
    for (const raw of rawItems) {
      const normalized = this.normalizeUser(raw);
      if (!normalized) continue;
      if (!dedup.has(normalized.soundcloudId)) {
        dedup.set(normalized.soundcloudId, normalized);
      }
    }

    const baseItems = Array.from(dedup.values());
    const resolvedItems = enrichWebProfiles
      ? await Promise.all(baseItems.map(async (item) => this.enrichUserWithWebProfiles(item)))
      : baseItems;

    const items = resolvedItems.sort((lhs, rhs) => {
      if (rhs.followersCount !== lhs.followersCount) {
        return rhs.followersCount - lhs.followersCount;
      }
      if (rhs.trackCount !== lhs.trackCount) {
        return rhs.trackCount - lhs.trackCount;
      }
      return lhs.name.localeCompare(rhs.name, 'en', { sensitivity: 'base' });
    });

    this.setCache(cacheKey, items);
    return items;
  }
}

const soundcloudArtistService = new SoundCloudArtistService();
export default soundcloudArtistService;
