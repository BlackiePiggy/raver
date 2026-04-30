import { PrismaClient } from '@prisma/client';
import { Router, Response } from 'express';
import { authenticate, AuthRequest } from '../middleware/auth';
import { tencentIMGroupService } from '../services/tencent-im/tencent-im-group.service';
import { tencentIMTokenService } from '../services/tencent-im/tencent-im-token.service';
import { tencentIMUserService } from '../services/tencent-im/tencent-im-user.service';

const router: Router = Router();
const prisma = new PrismaClient();

router.get('/bootstrap', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const bootstrap = await tencentIMTokenService.bootstrapForUser(userId);
    res.json(bootstrap);
  } catch (error) {
    console.error('Tencent IM bootstrap error:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Tencent IM bootstrap failed',
    });
  }
});

router.post('/users/me/sync', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
        isActive: true,
      },
    });

    if (!user || !user.isActive) {
      res.status(404).json({ error: 'User not found or inactive' });
      return;
    }

    const profile = await tencentIMUserService.ensureUser(user);
    res.json({
      success: true,
      profile,
    });
  } catch (error) {
    console.error('Tencent IM user sync error:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Tencent IM user sync failed',
    });
  }
});

router.post('/squads/:squadId/sync', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    const squadId = String(req.params.squadId || '').trim();

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    if (!squadId) {
      res.status(400).json({ error: 'Squad ID is required' });
      return;
    }

    const membership = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId,
          userId,
        },
      },
      select: {
        id: true,
      },
    });

    if (!membership) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const profile = await tencentIMGroupService.ensureSquadGroupById(squadId);
    res.json({
      success: true,
      profile,
    });
  } catch (error) {
    console.error('Tencent IM squad sync error:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Tencent IM squad sync failed',
    });
  }
});

router.get('/squads/mine', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const memberships = await prisma.squadMember.findMany({
      where: {
        userId,
      },
      select: {
        squadId: true,
        role: true,
        joinedAt: true,
        squad: {
          select: {
            name: true,
            isPublic: true,
            updatedAt: true,
          },
        },
      },
      orderBy: {
        joinedAt: 'desc',
      },
    });

    const squads = memberships.map((item) => ({
      squadId: item.squadId,
      role: item.role,
      joinedAt: item.joinedAt,
      name: item.squad.name,
      isPublic: item.squad.isPublic,
      updatedAt: item.squad.updatedAt,
    }));

    res.json({
      success: true,
      total: squads.length,
      squads,
    });
  } catch (error) {
    console.error('Tencent IM list my squads error:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Tencent IM list my squads failed',
    });
  }
});

router.post('/squads/sync-all', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const memberships = await prisma.squadMember.findMany({
      where: {
        userId,
      },
      select: {
        squadId: true,
      },
    });

    const squadIds = Array.from(new Set(memberships.map((item) => item.squadId)));
    const results: Array<{ squadId: string; success: boolean; error?: string }> = [];

    for (const squadId of squadIds) {
      try {
        await tencentIMGroupService.ensureSquadGroupById(squadId);
        results.push({ squadId, success: true });
      } catch (error) {
        results.push({
          squadId,
          success: false,
          error: error instanceof Error ? error.message : 'unknown sync error',
        });
      }
    }

    const successCount = results.filter((item) => item.success).length;
    const failedCount = results.length - successCount;
    res.json({
      success: failedCount === 0,
      total: results.length,
      successCount,
      failedCount,
      results,
    });
  } catch (error) {
    console.error('Tencent IM sync all squads error:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Tencent IM sync all squads failed',
    });
  }
});

router.post('/squads/:squadId/messages/test', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    const squadId = String(req.params.squadId || '').trim();
    const text = String((req.body as { text?: string } | undefined)?.text || 'TIM test message').trim();

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    if (!squadId) {
      res.status(400).json({ error: 'Squad ID is required' });
      return;
    }

    const membership = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId,
          userId,
        },
      },
      select: {
        id: true,
      },
    });

    if (!membership) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    await tencentIMGroupService.ensureSquadGroupById(squadId);
    await tencentIMGroupService.sendSquadTextMessage(squadId, userId, text);

    res.json({
      success: true,
      squadId,
      text,
    });
  } catch (error) {
    console.error('Tencent IM squad test message error:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Tencent IM squad test message failed',
    });
  }
});

export default router;
