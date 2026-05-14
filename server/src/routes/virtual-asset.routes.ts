import { Prisma } from '@prisma/client';
import { Router, Response } from 'express';
import { authenticate, AuthRequest } from '../middleware/auth';
import { adminAuditService } from '../modules/admin/admin-audit.service';
import { requireAdminOrOperator } from '../modules/admin/admin-auth.policy';
import { virtualAssetService, VirtualAssetError } from '../services/virtual-asset.service';

const router: Router = Router();

const sendError = (res: Response, error: unknown, fallback: string): void => {
  if (error instanceof VirtualAssetError) {
    res.status(error.statusCode).json({ error: error.message });
    return;
  }
  console.error(fallback, error);
  res.status(500).json({ error: fallback });
};

const parseAssetIdsBody = (body: unknown): string[] => {
  const value = body as { assetIds?: unknown; assetId?: unknown };
  if (Array.isArray(value.assetIds)) {
    return value.assetIds.map((item) => String(item));
  }
  if (typeof value.assetId === 'string' && value.assetId.trim()) {
    return [value.assetId];
  }
  return [];
};

const firstParam = (value: string | string[] | undefined): string => {
  return Array.isArray(value) ? value[0] || '' : value || '';
};

router.get('/virtual-assets/catalog', async (req, res): Promise<void> => {
  try {
    const type = typeof req.query.type === 'string' ? req.query.type : undefined;
    const includeHidden = req.query.includeHidden === 'true';
    const result = await virtualAssetService.listCatalog({ type, includeHidden });
    res.json(result);
  } catch (error) {
    sendError(res, error, '获取虚拟资产目录失败');
  }
});

router.get('/me/virtual-assets', authenticate, async (req: AuthRequest, res): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: '未登录' });
      return;
    }
    const result = await virtualAssetService.getMyAssets(userId);
    res.json(result);
  } catch (error) {
    sendError(res, error, '获取我的虚拟资产失败');
  }
});

router.put('/me/virtual-assets/equips/:assetType', authenticate, async (req: AuthRequest, res): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: '未登录' });
      return;
    }
    const result = await virtualAssetService.updateEquip(userId, firstParam(req.params.assetType), parseAssetIdsBody(req.body));
    res.json(result);
  } catch (error) {
    sendError(res, error, '更新虚拟资产装备失败');
  }
});

router.get('/users/:id/appearance', async (req, res): Promise<void> => {
  try {
    const result = await virtualAssetService.getAppearance(firstParam(req.params.id));
    res.json(result);
  } catch (error) {
    sendError(res, error, '获取用户虚拟资产展示失败');
  }
});

router.post(
  '/admin/virtual-assets/grants',
  authenticate,
  requireAdminOrOperator,
  async (req: AuthRequest, res): Promise<void> => {
    try {
      const actorUserId = req.user?.userId;
      if (!actorUserId) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }

      const body = req.body as {
        userId?: string;
        assetId?: string;
        assetCode?: string;
        acquisitionSource?: string;
        expiresAt?: string | null;
        metadata?: Prisma.InputJsonObject;
      };
      const result = await virtualAssetService.grantAsset({
        userId: body.userId || '',
        assetId: body.assetId,
        assetCode: body.assetCode,
        acquisitionSource: body.acquisitionSource,
        expiresAt: body.expiresAt,
        metadata: body.metadata,
      });
      await adminAuditService.createAction({
        actorId: actorUserId,
        action: 'virtual_asset.grant',
        targetType: 'user_virtual_asset',
        targetId: result.id,
        detail: {
          userId: result.userId,
          assetId: result.assetId,
          assetCode: result.asset.code,
          acquisitionSource: result.acquisitionSource,
          expiresAt: result.expiresAt,
        },
      });
      res.status(201).json(result);
    } catch (error) {
      sendError(res, error, '发放虚拟资产失败');
    }
  }
);

export default router;
