import { Router, Response } from 'express';
import { authenticate, AuthRequest } from '../middleware/auth';
import { globalSearchService, isGlobalSearchTab, normalizeSearchLocale } from '../services/global-search.service';

const router: Router = Router();

const normalizeLimit = (value: unknown, fallback = 30, max = 80): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.min(max, Math.floor(parsed)));
};

router.get('/', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const query = String(req.query.q || '').trim();
    if (!query) {
      res.status(400).json({ error: 'Search query is required' });
      return;
    }

    const rawTab = String(req.query.tab || 'all').trim();
    const tab = isGlobalSearchTab(rawTab) ? rawTab : 'all';
    const limit = normalizeLimit(req.query.limit);
    const locale = normalizeSearchLocale(req.query.locale, req.headers['accept-language']);

    const result = await globalSearchService.search({
      query,
      tab,
      limit,
      userId,
      locale,
    });

    res.json({ data: result });
  } catch (error) {
    console.error('Global search error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
