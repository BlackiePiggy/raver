import { Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';
import {
  USER_ENTITY_RELATION_FOLLOW,
  USER_ENTITY_TARGET_DJ,
  deleteUserEntityRelation,
  upsertUserEntityRelation,
  userEntityFollowWhere,
} from '../services/user-entity-follow.service';

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

    const existingFollow = await prisma.userEntityFollow.findUnique({
      where: userEntityFollowWhere(userId, USER_ENTITY_RELATION_FOLLOW, USER_ENTITY_TARGET_DJ, djId),
    });

    if (existingFollow) {
      res.status(409).json({ error: 'Already following this DJ' });
      return;
    }

    const follow = await prisma.$transaction(async (tx) => {
      const relation = await upsertUserEntityRelation(tx, {
        userId,
        relationType: USER_ENTITY_RELATION_FOLLOW,
        targetType: USER_ENTITY_TARGET_DJ,
        targetId: djId,
      });
      const djRow = await tx.dJ.findUniqueOrThrow({
        where: { id: djId },
      });

      await tx.dJ.update({
        where: { id: djId },
        data: {
          followerCount: {
            increment: 1,
          },
        },
      });

      return {
        id: relation.id,
        followerId: userId,
        followingId: null,
        djId,
        type: 'dj',
        createdAt: relation.createdAt,
        updatedAt: relation.updatedAt,
        dj: djRow,
      };
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

    const follow = await prisma.userEntityFollow.findUnique({
      where: userEntityFollowWhere(userId, USER_ENTITY_RELATION_FOLLOW, USER_ENTITY_TARGET_DJ, djId as string),
    });

    if (!follow) {
      res.status(404).json({ error: 'Not following this DJ' });
      return;
    }

    await prisma.$transaction(async (tx) => {
      await deleteUserEntityRelation(tx, {
        userId,
        relationType: USER_ENTITY_RELATION_FOLLOW,
        targetType: USER_ENTITY_TARGET_DJ,
        targetId: djId as string,
      });

      await tx.dJ.update({
        where: { id: djId as string },
        data: {
          followerCount: {
            decrement: 1,
          },
        },
      });
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

    const [followRows, total] = await Promise.all([
      prisma.userEntityFollow.findMany({
        where: {
          userId,
          relationType: USER_ENTITY_RELATION_FOLLOW,
          targetType: USER_ENTITY_TARGET_DJ,
        },
        skip,
        take: limitNum,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          userId: true,
          targetId: true,
          createdAt: true,
          updatedAt: true,
        },
      }),
      prisma.userEntityFollow.count({
        where: {
          userId,
          relationType: USER_ENTITY_RELATION_FOLLOW,
          targetType: USER_ENTITY_TARGET_DJ,
        },
      }),
    ]);

    const orderedDjIds = followRows.map((row) => row.targetId).filter((id): id is string => Boolean(id));
    const djRows = orderedDjIds.length
      ? await prisma.dJ.findMany({
          where: {
            id: {
              in: orderedDjIds,
            },
          },
        })
      : [];
    const djById = new Map(djRows.map((row) => [row.id, row]));
    const follows = followRows
      .map((row) => {
        const dj = djById.get(row.targetId);
        if (!dj) return null;
        return {
          id: row.id,
          followerId: row.userId,
          followingId: null,
          djId: row.targetId,
          type: 'dj',
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          dj,
        };
      })
      .filter(Boolean);

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

    const follow = await prisma.userEntityFollow.findUnique({
      where: userEntityFollowWhere(userId, USER_ENTITY_RELATION_FOLLOW, USER_ENTITY_TARGET_DJ, djId as string),
    });

    res.json({
      isFollowing: !!follow,
    });
  } catch (error) {
    console.error('Check follow status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
