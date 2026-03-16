import { Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';

const prisma = new PrismaClient();

export const followDJ = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { djId } = req.body;

    if (!djId) {
      res.status(400).json({ error: 'DJ ID is required' });
      return;
    }

    const dj = await prisma.dJ.findUnique({
      where: { id: djId },
    });

    if (!dj) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    const existingFollow = await prisma.follow.findUnique({
      where: {
        followerId_djId: {
          followerId: userId,
          djId,
        },
      },
    });

    if (existingFollow) {
      res.status(409).json({ error: 'Already following this DJ' });
      return;
    }

    const follow = await prisma.follow.create({
      data: {
        followerId: userId,
        djId,
        type: 'dj',
      },
      include: {
        dj: true,
      },
    });

    await prisma.dJ.update({
      where: { id: djId },
      data: {
        followerCount: {
          increment: 1,
        },
      },
    });

    res.status(201).json(follow);
  } catch (error) {
    console.error('Follow DJ error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const unfollowDJ = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { djId } = req.params;

    const follow = await prisma.follow.findUnique({
      where: {
        followerId_djId: {
          followerId: userId,
          djId: djId as string,
        },
      },
    });

    if (!follow) {
      res.status(404).json({ error: 'Not following this DJ' });
      return;
    }

    await prisma.follow.delete({
      where: {
        followerId_djId: {
          followerId: userId,
          djId: djId as string,
        },
      },
    });

    await prisma.dJ.update({
      where: { id: djId as string },
      data: {
        followerCount: {
          decrement: 1,
        },
      },
    });

    res.status(204).send();
  } catch (error) {
    console.error('Unfollow DJ error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getMyFollowedDJs = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const {
      page = '1',
      limit = '20',
    } = req.query;

    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    const [follows, total] = await Promise.all([
      prisma.follow.findMany({
        where: {
          followerId: userId,
          type: 'dj',
        },
        skip,
        take: limitNum,
        orderBy: { createdAt: 'desc' },
        include: {
          dj: true,
        },
      }),
      prisma.follow.count({
        where: {
          followerId: userId,
          type: 'dj',
        },
      }),
    ]);

    res.json({
      follows,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        totalPages: Math.ceil(total / limitNum),
      },
    });
  } catch (error) {
    console.error('Get my followed DJs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const checkFollowStatus = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { djId } = req.params;

    const follow = await prisma.follow.findUnique({
      where: {
        followerId_djId: {
          followerId: userId,
          djId: djId as string,
        },
      },
    });

    res.json({
      isFollowing: !!follow,
    });
  } catch (error) {
    console.error('Check follow status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
