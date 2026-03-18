import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';
import spotifyArtistService from '../services/spotify-artist.service';

const prisma = new PrismaClient();
const DJ_SYNC_TTL_MS = 1000 * 60 * 60 * 12;

const parseBoolean = (value: string | undefined, fallback: boolean): boolean => {
  if (value === undefined) {
    return fallback;
  }
  const normalized = value.toLowerCase().trim();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) {
    return true;
  }
  if (['0', 'false', 'no', 'off'].includes(normalized)) {
    return false;
  }
  return fallback;
};

const slugify = (name: string): string =>
  name
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-');

const uniqueSlugForName = async (name: string) => {
  const base = slugify(name) || `dj-${Date.now()}`;
  let candidate = base;
  let seq = 1;
  while (true) {
    const exists = await prisma.dJ.findUnique({ where: { slug: candidate } });
    if (!exists || exists.name.toLowerCase() === name.toLowerCase()) {
      return candidate;
    }
    seq += 1;
    candidate = `${base}-${seq}`;
  }
};

const ensureDJByName = async (name: string) => {
  const trimmed = name.trim();
  if (!trimmed) {
    return null;
  }

  const existing = await prisma.dJ.findFirst({
    where: { name: { equals: trimmed, mode: 'insensitive' } },
  });
  if (existing) {
    return existing;
  }

  const spotify = await spotifyArtistService.searchArtistByName(trimmed);
  if (spotify) {
    return upsertDJFromSpotifyProfile(trimmed, spotify);
  }

  const slug = await uniqueSlugForName(trimmed);
  return prisma.dJ.create({
    data: {
      name: trimmed,
      slug,
      isVerified: false,
    },
  });
};

const shouldSyncDJ = (dj: any, forceRefresh: boolean) => {
  if (forceRefresh) {
    return true;
  }

  const missingCoreFields = !dj.spotifyId || !dj.avatarUrl;
  if (missingCoreFields) {
    return true;
  }

  if (!dj.lastSyncedAt) {
    return true;
  }

  const lastSyncedTime = new Date(dj.lastSyncedAt).getTime();
  return Number.isNaN(lastSyncedTime) || Date.now() - lastSyncedTime > DJ_SYNC_TTL_MS;
};

const enrichDJWithSpotify = async (dj: any, forceRefresh = false) => {
  try {
    if (!shouldSyncDJ(dj, forceRefresh)) {
      return { ...dj, spotify: null };
    }

    let spotify = null;
    if (dj.spotifyId) {
      spotify = await spotifyArtistService.getArtistById(dj.spotifyId);
    }
    if (!spotify) {
      spotify = await spotifyArtistService.searchArtistByName(dj.name);
    }

    if (!spotify) {
      return { ...dj, spotify: null };
    }

    const inferredBio =
      dj.bio ||
      (spotify.genres.length > 0 ? `Spotify genres: ${spotify.genres.slice(0, 3).join(', ')}` : null);

    const updateData = {
      spotifyId: dj.spotifyId || spotify.id,
      followerCount: spotify.followers || dj.followerCount,
      avatarUrl: dj.avatarUrl || spotify.imageUrl,
      bio: inferredBio,
      lastSyncedAt: new Date(),
    };

    const updatedDJ = await prisma.dJ.update({
      where: { id: dj.id },
      data: updateData,
    });

    return {
      ...updatedDJ,
      spotify: spotify,
    };
  } catch {
    return { ...dj, spotify: null };
  }
};

const upsertDJFromSpotifyProfile = async (
  fallbackName: string,
  spotify: {
    id: string;
    name: string;
    followers: number;
    imageUrl: string | null;
    genres: string[];
  }
) => {
  const existingBySpotifyId = await prisma.dJ.findFirst({
    where: { spotifyId: spotify.id },
  });

  const target = existingBySpotifyId
    ? existingBySpotifyId
    : await prisma.dJ.findFirst({
        where: { name: { equals: fallbackName, mode: 'insensitive' } },
      });

  const bio = spotify.genres.length ? `Spotify genres: ${spotify.genres.slice(0, 3).join(', ')}` : null;
  const data = {
    name: target?.name || spotify.name || fallbackName,
    spotifyId: spotify.id,
    followerCount: spotify.followers || target?.followerCount || 0,
    avatarUrl: target?.avatarUrl || spotify.imageUrl,
    bio: target?.bio || bio,
    lastSyncedAt: new Date(),
  };

  if (target) {
    return prisma.dJ.update({
      where: { id: target.id },
      data,
    });
  }

  const slug = await uniqueSlugForName(data.name);
  return prisma.dJ.create({
    data: {
      ...data,
      slug,
      isVerified: true,
    },
  });
};

export const getDJs = async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      page = '1',
      limit = '20',
      search,
      country,
      sortBy = 'followerCount',
      live = 'true',
      refresh = 'false',
    } = req.query;

    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;
    const includeLive = parseBoolean(live as string | undefined, true);
    const forceRefresh = parseBoolean(refresh as string | undefined, false);

    const where: any = {};

    if (search) {
      where.OR = [
        { name: { contains: search as string, mode: 'insensitive' } },
        { bio: { contains: search as string, mode: 'insensitive' } },
      ];
    }

    if (country) {
      where.country = country as string;
    }

    const orderBy: any = {};
    if (sortBy === 'followerCount') {
      orderBy.followerCount = 'desc';
    } else if (sortBy === 'name') {
      orderBy.name = 'asc';
    } else {
      orderBy.createdAt = 'desc';
    }

    const [djsRaw, total] = await Promise.all([
      prisma.dJ.findMany({
        where,
        skip,
        take: limitNum,
        orderBy,
      }),
      prisma.dJ.count({ where }),
    ]);

    if (search && djsRaw.length === 0) {
      const ensured = await ensureDJByName(search as string);
      if (ensured) {
        res.json({
          djs: [ensured],
          live: includeLive && spotifyArtistService.isConfigured(),
          refresh: forceRefresh,
          pagination: {
            page: 1,
            limit: limitNum,
            total: 1,
            totalPages: 1,
          },
        });
        return;
      }
    }

    const djs =
      includeLive && spotifyArtistService.isConfigured()
        ? await Promise.all(djsRaw.map((dj) => enrichDJWithSpotify(dj, forceRefresh)))
        : djsRaw;
    const sortedDjs =
      includeLive && sortBy === 'followerCount'
        ? [...djs].sort((a, b) => (b.followerCount ?? 0) - (a.followerCount ?? 0))
        : djs;

    res.json({
      djs: sortedDjs,
      live: includeLive && spotifyArtistService.isConfigured(),
      refresh: forceRefresh,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        totalPages: Math.ceil(total / limitNum),
      },
    });
  } catch (error) {
    console.error('Get DJs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getDJ = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const includeLive = parseBoolean(req.query.live as string | undefined, true);
    const forceRefresh = parseBoolean(req.query.refresh as string | undefined, false);

    const djRaw = await prisma.dJ.findUnique({
      where: { id: id as string },
    });

    if (!djRaw) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    const dj =
      includeLive && spotifyArtistService.isConfigured()
        ? await enrichDJWithSpotify(djRaw, forceRefresh)
        : djRaw;

    res.json({
      ...dj,
      live: includeLive && spotifyArtistService.isConfigured(),
      refresh: forceRefresh,
    });
  } catch (error) {
    console.error('Get DJ error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const createDJ = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const {
      name,
      slug,
      bio,
      avatarUrl,
      bannerUrl,
      country,
      spotifyId,
      appleMusicId,
      soundcloudUrl,
      instagramUrl,
      twitterUrl,
    } = req.body;

    if (!name || !slug) {
      res.status(400).json({ error: 'Name and slug are required' });
      return;
    }

    const existingDJ = await prisma.dJ.findUnique({
      where: { slug },
    });

    if (existingDJ) {
      res.status(409).json({ error: 'DJ with this slug already exists' });
      return;
    }

    const dj = await prisma.dJ.create({
      data: {
        name,
        slug,
        bio,
        avatarUrl,
        bannerUrl,
        country,
        spotifyId,
        appleMusicId,
        soundcloudUrl,
        instagramUrl,
        twitterUrl,
      },
    });

    res.status(201).json(dj);
  } catch (error) {
    console.error('Create DJ error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const batchCreateDJs = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { names, country, isVerified = false } = req.body as {
      names?: string[];
      country?: string;
      isVerified?: boolean;
    };

    if (!Array.isArray(names) || names.length === 0) {
      res.status(400).json({ error: 'names must be a non-empty string array' });
      return;
    }

    const cleaned = names
      .map((name) => String(name).trim())
      .filter((name) => Boolean(name));

    if (cleaned.length === 0) {
      res.status(400).json({ error: 'No valid DJ names found' });
      return;
    }

    const createdOrUpdated: any[] = [];

    for (const name of cleaned) {
      const baseSlug = slugify(name) || `dj-${Date.now()}`;
      let candidate = baseSlug;
      let seq = 1;

      while (true) {
        const existingBySlug = await prisma.dJ.findUnique({ where: { slug: candidate } });
        if (!existingBySlug || existingBySlug.name.toLowerCase() === name.toLowerCase()) {
          break;
        }
        seq += 1;
        candidate = `${baseSlug}-${seq}`;
      }

      const existingByName = await prisma.dJ.findFirst({
        where: { name: { equals: name, mode: 'insensitive' } },
      });

      const dj = existingByName
        ? await prisma.dJ.update({
            where: { id: existingByName.id },
            data: {
              country: existingByName.country ?? country,
              isVerified: existingByName.isVerified || Boolean(isVerified),
            },
          })
        : await prisma.dJ.create({
            data: {
              name,
              slug: candidate,
              country,
              isVerified: Boolean(isVerified),
            },
          });

      createdOrUpdated.push(dj);
    }

    res.status(201).json({
      total: createdOrUpdated.length,
      djs: createdOrUpdated,
    });
  } catch (error) {
    console.error('Batch create DJs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const searchSpotifyArtist = async (req: Request, res: Response): Promise<void> => {
  try {
    const query = String(req.query.q || '').trim();
    if (!query) {
      res.status(400).json({ error: 'q is required' });
      return;
    }

    if (!spotifyArtistService.isConfigured()) {
      res.status(400).json({ error: 'Spotify credentials are not configured' });
      return;
    }

    const artist = await spotifyArtistService.searchArtistByName(query);
    if (!artist) {
      res.json({ artist: null });
      return;
    }

    const dj = await upsertDJFromSpotifyProfile(query, artist);
    res.json({ artist, dj });
  } catch (error) {
    console.error('Search Spotify artist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const ensureDJs = async (req: Request, res: Response): Promise<void> => {
  try {
    const bodyNames = Array.isArray((req.body as any)?.names)
      ? ((req.body as any).names as unknown[])
      : [];
    const queryNames =
      typeof req.query.names === 'string'
        ? req.query.names.split(',')
        : [];

    const names = [...bodyNames, ...queryNames]
      .map((item) => String(item).trim())
      .filter(Boolean);

    if (names.length === 0) {
      res.status(400).json({ error: 'names are required' });
      return;
    }

    const unique = [...new Set(names)];
    const ensured = (
      await Promise.all(
        unique.map(async (name) => {
          try {
            return await ensureDJByName(name);
          } catch {
            return null;
          }
        })
      )
    ).filter((item): item is NonNullable<typeof item> => item !== null);

    res.json({
      total: unique.length,
      ensured: ensured.length,
      djs: ensured,
    });
  } catch (error) {
    console.error('Ensure DJs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const updateDJ = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    const dj = await prisma.dJ.update({
      where: { id: id as string },
      data: updateData,
    });

    res.json(dj);
  } catch (error) {
    console.error('Update DJ error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const deleteDJ = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    await prisma.dJ.delete({
      where: { id: id as string },
    });

    res.status(204).send();
  } catch (error) {
    console.error('Delete DJ error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
