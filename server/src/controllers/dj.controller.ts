import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';

const prisma = new PrismaClient();

export const getDJs = async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      page = '1',
      limit = '20',
      search,
      country,
      sortBy = 'followerCount'
    } = req.query;

    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

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

    const [djs, total] = await Promise.all([
      prisma.dJ.findMany({
        where,
        skip,
        take: limitNum,
        orderBy,
      }),
      prisma.dJ.count({ where }),
    ]);

    res.json({
      djs,
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

    const dj = await prisma.dJ.findUnique({
      where: { id: id as string },
    });

    if (!dj) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    res.json(dj);
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
