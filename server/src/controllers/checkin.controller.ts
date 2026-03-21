import { Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';

const prisma = new PrismaClient();

export const createCheckin = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { eventId, djId, type, note, photoUrl, rating, attendedAt } = req.body;

    if (!type || (type !== 'event' && type !== 'dj')) {
      res.status(400).json({ error: 'Invalid type. Must be "event" or "dj"' });
      return;
    }

    if (type === 'event' && !eventId) {
      res.status(400).json({ error: 'Event ID is required for event checkin' });
      return;
    }

    if (type === 'dj' && !djId) {
      res.status(400).json({ error: 'DJ ID is required for DJ checkin' });
      return;
    }

    const parsedAttendedAt =
      typeof attendedAt === 'string' && attendedAt.trim().length > 0 ? new Date(attendedAt) : null;

    if (parsedAttendedAt && Number.isNaN(parsedAttendedAt.getTime())) {
      res.status(400).json({ error: 'attendedAt must be a valid ISO datetime' });
      return;
    }

    const checkin = await prisma.checkin.create({
      data: {
        userId,
        eventId: eventId ?? null,
        djId: type === 'dj' ? djId : null,
        type,
        note,
        photoUrl,
        rating,
        attendedAt: parsedAttendedAt ?? new Date(),
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        event: true,
        dj: true,
      },
    });

    res.status(201).json(checkin);
  } catch (error) {
    console.error('Create checkin error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getCheckins = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const {
      page = '1',
      limit = '20',
      userId,
      eventId,
      djId,
      type,
    } = req.query;

    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    const where: any = {};

    if (userId) {
      where.userId = userId as string;
    }

    if (eventId) {
      where.eventId = eventId as string;
    }

    if (djId) {
      where.djId = djId as string;
    }

    if (type) {
      where.type = type as string;
    }

    const [checkins, total] = await Promise.all([
      prisma.checkin.findMany({
        where,
        skip,
        take: limitNum,
        orderBy: [{ attendedAt: 'desc' }, { createdAt: 'desc' }],
        include: {
          user: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
          event: true,
          dj: true,
        },
      }),
      prisma.checkin.count({ where }),
    ]);

    res.json({
      checkins,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        totalPages: Math.ceil(total / limitNum),
      },
    });
  } catch (error) {
    console.error('Get checkins error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getMyCheckins = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const {
      page = '1',
      limit = '20',
      type,
    } = req.query;

    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    const where: any = { userId };

    if (type) {
      where.type = type as string;
    }

    const [checkins, total] = await Promise.all([
      prisma.checkin.findMany({
        where,
        skip,
        take: limitNum,
        orderBy: [{ attendedAt: 'desc' }, { createdAt: 'desc' }],
        include: {
          event: true,
          dj: true,
        },
      }),
      prisma.checkin.count({ where }),
    ]);

    res.json({
      checkins,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        totalPages: Math.ceil(total / limitNum),
      },
    });
  } catch (error) {
    console.error('Get my checkins error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const deleteCheckin = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { id } = req.params;

    const checkin = await prisma.checkin.findUnique({
      where: { id: id as string },
    });

    if (!checkin) {
      res.status(404).json({ error: 'Checkin not found' });
      return;
    }

    if (checkin.userId !== userId && req.user?.role !== 'admin') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    await prisma.checkin.delete({
      where: { id: id as string },
    });

    res.status(204).send();
  } catch (error) {
    console.error('Delete checkin error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
