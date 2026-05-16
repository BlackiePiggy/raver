import { Router, Response } from 'express';
import { Prisma } from '@prisma/client';
import { authenticate, AuthRequest } from '../middleware/auth';
import { requireAdminOrOperator } from '../modules/admin/admin-auth.policy';
import {
  createDjEnrichmentJob,
  getDjEnrichmentJobDetail,
  getDjEnrichmentResultDetail,
  listDjEnrichmentJobs,
  listDjEnrichmentResults,
  reviewDjEnrichmentResult,
  reviewDjEnrichmentResultsBulk,
} from '../services/dj-enrichment.service';

const router: Router = Router();

const cleanText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const parseLimit = (value: unknown, fallback = 200, max = 500): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(Math.floor(parsed), max);
};

const parseOffset = (value: unknown): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return 0;
  return Math.floor(parsed);
};

const toOptionalJsonObject = (value: unknown): Prisma.InputJsonObject | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as Prisma.InputJsonObject;
};

router.post('/jobs', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorId = req.user?.userId;
    if (!actorId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const djIds = Array.isArray(req.body?.djIds)
      ? req.body.djIds.map((item: unknown) => cleanText(item)).filter(Boolean)
      : [];
    if (djIds.length === 0) {
      res.status(400).json({ error: 'djIds cannot be empty' });
      return;
    }
    const created = await createDjEnrichmentJob(actorId, djIds, {
      maxConcurrency: Number(req.body?.maxConcurrency),
    });
    res.status(202).json({
      success: true,
      jobId: created.jobId,
      acceptedCount: created.acceptedCount,
      maxConcurrency: created.maxConcurrency,
      status: 'queued',
    });
  } catch (error) {
    console.error('Create DJ enrichment job error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to create DJ enrichment job' });
  }
});

router.get('/jobs', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const items = await listDjEnrichmentJobs({
      status: cleanText(req.query.status) || undefined,
      requestedById: cleanText(req.query.requestedById) || undefined,
      limit: parseLimit(req.query.limit, 20, 100),
    });
    res.json({ success: true, items, total: items.length });
  } catch (error) {
    console.error('List DJ enrichment jobs error:', error);
    res.status(500).json({ error: 'Failed to fetch DJ enrichment jobs' });
  }
});

router.get('/jobs/:id', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const id = cleanText(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'job id is required' });
      return;
    }
    const job = await getDjEnrichmentJobDetail(id);
    if (!job) {
      res.status(404).json({ error: 'DJ enrichment job not found' });
      return;
    }
    res.json({ success: true, job });
  } catch (error) {
    console.error('Get DJ enrichment job detail error:', error);
    res.status(500).json({ error: 'Failed to fetch DJ enrichment job detail' });
  }
});

router.get('/results', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const result = await listDjEnrichmentResults({
      applyStatus: cleanText(req.query.applyStatus) || undefined,
      reviewStatus: cleanText(req.query.reviewStatus) || undefined,
      limit: parseLimit(req.query.limit),
      offset: parseOffset(req.query.offset),
    });
    res.json({ success: true, ...result });
  } catch (error) {
    console.error('List DJ enrichment results error:', error);
    res.status(500).json({ error: 'Failed to fetch DJ enrichment results' });
  }
});

router.get('/results/:id', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const id = cleanText(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'result id is required' });
      return;
    }
    const result = await getDjEnrichmentResultDetail(id);
    if (!result) {
      res.status(404).json({ error: 'DJ enrichment result not found' });
      return;
    }
    res.json({ success: true, result });
  } catch (error) {
    console.error('Get DJ enrichment result detail error:', error);
    res.status(500).json({ error: 'Failed to fetch DJ enrichment result detail' });
  }
});

router.post('/results/:id/review', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorId = req.user?.userId;
    if (!actorId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const resultId = cleanText(req.params.id);
    const decision = cleanText(req.body?.decision).toLowerCase();
    if (decision !== 'approved' && decision !== 'rejected') {
      res.status(400).json({ error: 'decision must be approved or rejected' });
      return;
    }
    const updated = await reviewDjEnrichmentResult({
      resultId,
      actorId,
      decision,
      reason: cleanText(req.body?.reason) || null,
      reviewNotes: toOptionalJsonObject(req.body?.reviewNotes),
    });
    res.json({
      success: true,
      result: updated,
      message: decision === 'approved' ? 'DJ enrichment 已审核通过并入库' : 'DJ enrichment 已拒绝',
    });
  } catch (error) {
    console.error('Review DJ enrichment result error:', error);
    const message = error instanceof Error ? error.message : 'Failed to review DJ enrichment result';
    const status = /not found/i.test(message) ? 404 : /already been reviewed|not ready/i.test(message) ? 409 : 500;
    res.status(status).json({ error: message });
  }
});

router.post('/results/review-bulk', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorId = req.user?.userId;
    if (!actorId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const decision = cleanText(req.body?.decision).toLowerCase();
    if (decision !== 'approved' && decision !== 'rejected') {
      res.status(400).json({ error: 'decision must be approved or rejected' });
      return;
    }
    const resultIds = Array.isArray(req.body?.resultIds)
      ? req.body.resultIds.map((item: unknown) => cleanText(item)).filter(Boolean)
      : [];
    if (resultIds.length === 0) {
      res.status(400).json({ error: 'resultIds cannot be empty' });
      return;
    }
    const summary = await reviewDjEnrichmentResultsBulk({
      resultIds,
      actorId,
      decision,
      reason: cleanText(req.body?.reason) || null,
      reviewNotes: toOptionalJsonObject(req.body?.reviewNotes),
      batchSize: parseLimit(req.body?.batchSize, 100, 200),
    });
    res.json({
      success: true,
      ...summary,
      message: decision === 'approved'
        ? `DJ enrichment 批量审核通过完成：${summary.succeeded}/${summary.requested}`
        : `DJ enrichment 批量拒绝完成：${summary.succeeded}/${summary.requested}`,
    });
  } catch (error) {
    console.error('Bulk review DJ enrichment results error:', error);
    const message = error instanceof Error ? error.message : 'Failed to bulk review DJ enrichment results';
    res.status(500).json({ error: message });
  }
});

export default router;
