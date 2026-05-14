import { NextFunction, Request, RequestHandler, Response, Router } from 'express';
import { authenticate, AuthRequest } from '../../middleware/auth';
import checkinsV2Routes from '../../routes/checkins-v2.routes';
import notificationCenterRoutes from '../../routes/notification-center.routes';
import preRegistrationRoutes from '../../routes/pre-registration.routes';
import virtualAssetRoutes from '../../routes/virtual-asset.routes';
import { adminAuditService } from './admin-audit.service';
import { requireAdmin, requireAdminOrOperator } from './admin-auth.policy';
import { adminStatusService } from './admin-status.service';

const router: Router = Router();

const forwardToLegacyRouter = (legacyPrefix: string, legacyRouter: RequestHandler): RequestHandler => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const originalUrl = req.url;
    const suffix = originalUrl === '/' ? '' : originalUrl;
    req.url = `${legacyPrefix}${suffix}`;

    legacyRouter(req, res, (error?: unknown) => {
      req.url = originalUrl;
      if (error) {
        next(error);
        return;
      }
      next();
    });
  };
};

const parseLimit = (value: unknown, fallback = 50, max = 200): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(Math.floor(parsed), max);
};

const parseDateCursor = (value: unknown): Date | undefined => {
  if (typeof value !== 'string' || !value.trim()) return undefined;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? undefined : date;
};

const firstQueryValue = (value: unknown): string | undefined => {
  if (Array.isArray(value)) return typeof value[0] === 'string' ? value[0] : undefined;
  return typeof value === 'string' ? value : undefined;
};

router.get('/audit-logs', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const query = req.query as Request['query'];
    const result = await adminAuditService.listLogs({
      limit: parseLimit(query.limit),
      actorId: firstQueryValue(query.actorId),
      action: firstQueryValue(query.action),
      targetType: firstQueryValue(query.targetType),
      targetId: firstQueryValue(query.targetId),
      before: parseDateCursor(query.before || query.cursor),
    });
    res.json({ success: true, ...result });
  } catch (error) {
    console.error('Fetch admin audit logs error:', error);
    res.status(500).json({ error: 'Failed to fetch admin audit logs' });
  }
});

router.get('/status', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const query = req.query as Request['query'];
    const status = await adminStatusService.getStatus({
      windowHours: query.windowHours,
    });
    res.json({ success: true, status });
  } catch (error) {
    console.error('Fetch admin status error:', error);
    res.status(500).json({ error: 'Failed to fetch admin status' });
  }
});

router.use('/notifications', forwardToLegacyRouter('/admin', notificationCenterRoutes));
router.use('/pre-registrations', forwardToLegacyRouter('/admin/pre-registrations', preRegistrationRoutes));
router.use('/pre-registration-batches', forwardToLegacyRouter('/admin/pre-registration-batches', preRegistrationRoutes));
router.use('/pre-registration-notifications', forwardToLegacyRouter('/admin/pre-registration-notifications', preRegistrationRoutes));
router.use('/checkins', forwardToLegacyRouter('/admin/checkins', checkinsV2Routes));
router.use('/virtual-assets', forwardToLegacyRouter('/admin/virtual-assets', virtualAssetRoutes));

export default router;
