interface SpotifyImage {
  url: string;
  height: number;
  width: number;
}

interface SpotifyArtist {
  id: string;
  name: string;
  uri: string;
  popularity: number;
  genres: string[];
  followers?: {
    total: number;
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

class SpotifyArtistService {
  private token: string | null = null;
  private tokenExpiresAt = 0;
  private readonly cache = new Map<string, { data: SpotifyArtistProfile | null; expiresAt: number }>();
  private readonly cacheTtlMs = 5 * 60 * 1000;
  private readonly requestTimeoutMs = 3500;

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

    try {
      const response = await this.fetchWithTimeout('https://accounts.spotify.com/api/token', {
        method: 'POST',
        headers: {
          Authorization: `Basic ${basicAuth}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({ grant_type: 'client_credentials' }).toString(),
      });

      if (!response.ok) {
        return null;
      }

      const payload = (await response.json()) as { access_token: string; expires_in: number };
      this.token = payload.access_token;
      this.tokenExpiresAt = Date.now() + payload.expires_in * 1000;
      return this.token;
    } catch {
      return null;
    }
  }

  private normalizeArtist(artist: SpotifyArtist): SpotifyArtistProfile {
    const sortedImages = [...(artist.images ?? [])].sort((a, b) => a.width - b.width);
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

  private pickBestMatch(name: string, items: SpotifyArtist[]): SpotifyArtist | null {
    if (items.length === 0) {
      return null;
    }

    const normalized = name.trim().toLowerCase();
    const exact = items.find((item) => item.name.trim().toLowerCase() === normalized);
    if (exact) {
      return exact;
    }

    return items
      .slice()
      .sort((a, b) => {
        const followersDiff = (b.followers?.total ?? 0) - (a.followers?.total ?? 0);
        if (followersDiff !== 0) {
          return followersDiff;
        }
        return (b.popularity ?? 0) - (a.popularity ?? 0);
      })[0];
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

    const token = await this.getAccessToken();
    if (!token) {
      this.setCache(cacheKey, null);
      return null;
    }

    try {
      const response = await this.fetchWithTimeout(`https://api.spotify.com/v1/artists/${encodeURIComponent(artistId)}`, {
        headers: { Authorization: `Bearer ${token}` },
      });

      if (!response.ok) {
        this.setCache(cacheKey, null);
        return null;
      }

      const artist = (await response.json()) as SpotifyArtist;
      const normalized = this.normalizeArtist(artist);
      this.setCache(cacheKey, normalized);
      this.setCache(`name:${artist.name.trim().toLowerCase()}`, normalized);
      return normalized;
    } catch {
      this.setCache(cacheKey, null);
      return null;
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

    const token = await this.getAccessToken();
    if (!token) {
      this.setCache(cacheKey, null);
      return null;
    }

    const params = new URLSearchParams({
      q: trimmed,
      type: 'artist',
      limit: '10',
    });

    try {
      const response = await this.fetchWithTimeout(`https://api.spotify.com/v1/search?${params.toString()}`, {
        headers: { Authorization: `Bearer ${token}` },
      });

      if (!response.ok) {
        this.setCache(cacheKey, null);
        return null;
      }

      const payload = (await response.json()) as { artists?: { items?: SpotifyArtist[] } };
      const items = payload.artists?.items ?? [];
      const best = this.pickBestMatch(trimmed, items);
      const normalized = best ? this.normalizeArtist(best) : null;
      this.setCache(cacheKey, normalized);

      if (normalized) {
        this.setCache(`id:${normalized.id}`, normalized);
      }

      return normalized;
    } catch {
      this.setCache(cacheKey, null);
      return null;
    }
  }
}

export default new SpotifyArtistService();
