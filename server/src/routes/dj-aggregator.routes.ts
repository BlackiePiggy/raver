import { Router, Request, Response } from 'express';
import type { IRouter } from 'express';
import djAggregatorService from '../services/dj-aggregator.service';

const router: IRouter = Router();

/**
 * POST /api/dj-aggregator/sync/:djId
 * Sync DJ data from external sources
 */
router.post('/sync/:djId', async (req: Request, res: Response): Promise<void> => {
  try {
    const updatedDJ = await djAggregatorService.syncDJ(req.params.djId as string);
    res.json(updatedDJ);
  } catch (error) {
    console.error('Sync DJ error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * POST /api/dj-aggregator/batch-sync
 * Batch sync multiple DJs
 */
router.post('/batch-sync', async (req: Request, res: Response): Promise<void> => {
  try {
    const { djIds } = req.body;

    if (!Array.isArray(djIds) || djIds.length === 0) {
      res.status(400).json({ error: 'Invalid djIds' });
      return;
    }

    const results = await djAggregatorService.batchSyncDJs(djIds);
    res.json(results);
  } catch (error) {
    console.error('Batch sync error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * GET /api/dj-aggregator/search/:name
 * Search for DJ data from external sources
 */
router.get('/search/:name', async (req: Request, res: Response): Promise<void> => {
  try {
    const data = await djAggregatorService.aggregateDJData(req.params.name as string);
    res.json(data);
  } catch (error) {
    console.error('Search DJ error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

export default router;