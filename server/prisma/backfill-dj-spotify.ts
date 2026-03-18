import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type SpotifyArtist = {
  id: string;
  name: string;
  followers?: { total: number };
  images?: Array<{ url: string; width: number; height: number }>;
  genres?: string[];
};

const timeoutMs = 20000;

async function fetchWithTimeout(url: string, options?: RequestInit): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

async function getToken() {
  const clientId = process.env.SPOTIFY_CLIENT_ID;
  const clientSecret = process.env.SPOTIFY_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    throw new Error('Missing SPOTIFY_CLIENT_ID or SPOTIFY_CLIENT_SECRET');
  }

  const basicAuth = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
  const response = await fetchWithTimeout('https://accounts.spotify.com/api/token', {
    method: 'POST',
    headers: {
      Authorization: `Basic ${basicAuth}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({ grant_type: 'client_credentials' }).toString(),
  });

  if (!response.ok) {
    throw new Error(`Spotify token failed: ${response.status}`);
  }
  const payload = (await response.json()) as { access_token: string };
  return payload.access_token;
}

async function searchArtist(token: string, name: string): Promise<SpotifyArtist | null> {
  const params = new URLSearchParams({
    q: name,
    type: 'artist',
    limit: '5',
  });
  const response = await fetchWithTimeout(`https://api.spotify.com/v1/search?${params.toString()}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!response.ok) {
    return null;
  }

  const payload = (await response.json()) as { artists?: { items?: SpotifyArtist[] } };
  const items = payload.artists?.items ?? [];
  if (items.length === 0) {
    return null;
  }

  const normalized = name.trim().toLowerCase();
  const exact = items.find((item) => item.name.trim().toLowerCase() === normalized);
  if (exact) {
    return exact;
  }

  return items.sort((a, b) => (b.followers?.total ?? 0) - (a.followers?.total ?? 0))[0];
}

async function main() {
  const token = await getToken();
  const targets = await prisma.dJ.findMany({
    where: {
      OR: [{ avatarUrl: null }, { spotifyId: null }],
    },
    orderBy: { followerCount: 'desc' },
    take: 120,
  });

  console.log(`Targets: ${targets.length}`);
  let success = 0;

  for (const dj of targets) {
    try {
      const artist = await searchArtist(token, dj.name);
      if (!artist) {
        continue;
      }
      const image = [...(artist.images ?? [])].sort((a, b) => a.width - b.width)[0]?.url ?? null;
      const bio =
        dj.bio || (artist.genres?.length ? `Spotify genres: ${artist.genres.slice(0, 3).join(', ')}` : null);

      await prisma.dJ.update({
        where: { id: dj.id },
        data: {
          spotifyId: dj.spotifyId || artist.id,
          avatarUrl: dj.avatarUrl || image,
          followerCount: artist.followers?.total ?? dj.followerCount,
          bio,
          lastSyncedAt: new Date(),
        },
      });
      success += 1;
      console.log(`Updated: ${dj.name}`);
    } catch {
      console.log(`Skip: ${dj.name}`);
    }
  }

  console.log(`Done. Updated ${success}/${targets.length}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
