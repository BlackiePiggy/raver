import { Response, Router } from 'express';
import { authenticate, type AuthRequest } from '../../middleware/auth';
import { adminAuditService } from './admin-audit.service';
import { requireAdmin, requireAdminOrOperator } from './admin-auth.policy';
import { AdminPersonalityError, adminPersonalityService } from './admin-personality.service';

const router: Router = Router();

const normalizeRouteId = (value: string | string[] | undefined): string => {
  if (Array.isArray(value)) {
    return value[0] ?? '';
  }
  return typeof value === 'string' ? value : '';
};

const handleError = (res: Response, error: unknown, fallbackMessage: string): void => {
  if (error instanceof AdminPersonalityError) {
    res.status(error.status).json({
      error: error.message,
      code: error.code,
    });
    return;
  }
  console.error(fallbackMessage, error);
  res.status(500).json({ error: fallbackMessage });
};

router.get('/config', authenticate, requireAdminOrOperator, async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const config = await adminPersonalityService.getConfig();
    res.json({ success: true, config });
  } catch (error) {
    handleError(res, error, 'Failed to fetch personality config');
  }
});

router.patch('/config', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const config = await adminPersonalityService.updateConfig({
      isEnabled: typeof req.body?.isEnabled === 'boolean' ? req.body.isEnabled : undefined,
      questionCount: typeof req.body?.questionCount === 'number' ? req.body.questionCount : undefined,
      axisThreshold: typeof req.body?.axisThreshold === 'number' ? req.body.axisThreshold : undefined,
      resultTypeCapacity: typeof req.body?.resultTypeCapacity === 'number' ? req.body.resultTypeCapacity : undefined,
      standardQuestionIds: Array.isArray(req.body?.standardQuestionIds) ? (req.body.standardQuestionIds as string[]) : undefined,
      debugQuestionIds: Array.isArray(req.body?.debugQuestionIds) ? (req.body.debugQuestionIds as string[]) : undefined,
      easterEggQuestionId:
        req.body?.easterEggQuestionId === null
          ? null
          : typeof req.body?.easterEggQuestionId === 'string'
          ? req.body.easterEggQuestionId
          : undefined,
      hiddenResultPriority: Array.isArray(req.body?.hiddenResultPriority) ? (req.body.hiddenResultPriority as string[]) : undefined,
    });
    await adminAuditService.createAction({
      actorId: req.user?.userId || 'unknown',
      action: 'personality.config.update',
      targetType: 'personality_config',
      targetId: config.id,
      detail: config,
    });
    res.json({ success: true, config });
  } catch (error) {
    handleError(res, error, 'Failed to update personality config');
  }
});

router.get('/questions', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const result = await adminPersonalityService.listQuestions({
      page: Number(req.query.page),
      limit: Number(req.query.limit),
      status: typeof req.query.status === 'string' ? req.query.status : undefined,
    });
    res.json({ success: true, items: result.items, pagination: result.pagination });
  } catch (error) {
    handleError(res, error, 'Failed to fetch personality questions');
  }
});

router.get('/questions/:id', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const item = await adminPersonalityService.getQuestion(normalizeRouteId(req.params.id));
    res.json({ success: true, item });
  } catch (error) {
    handleError(res, error, 'Failed to fetch personality question');
  }
});

router.post('/questions', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const item = await adminPersonalityService.createQuestion(req.body || {});
    await adminAuditService.createAction({
      actorId: req.user?.userId || 'unknown',
      action: 'personality.question.create',
      targetType: 'personality_question',
      targetId: item.id,
      detail: item,
    });
    res.status(201).json({ success: true, item });
  } catch (error) {
    handleError(res, error, 'Failed to create personality question');
  }
});

router.patch('/questions/:id', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const item = await adminPersonalityService.updateQuestion(normalizeRouteId(req.params.id), req.body || {});
    await adminAuditService.createAction({
      actorId: req.user?.userId || 'unknown',
      action: 'personality.question.update',
      targetType: 'personality_question',
      targetId: item.id,
      detail: item,
    });
    res.json({ success: true, item });
  } catch (error) {
    handleError(res, error, 'Failed to update personality question');
  }
});

router.post('/questions/:id/archive', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const item = await adminPersonalityService.archiveQuestion(normalizeRouteId(req.params.id));
    await adminAuditService.createAction({
      actorId: req.user?.userId || 'unknown',
      action: 'personality.question.archive',
      targetType: 'personality_question',
      targetId: item.id,
      detail: item,
    });
    res.json({ success: true, item });
  } catch (error) {
    handleError(res, error, 'Failed to archive personality question');
  }
});

router.get('/result-types', authenticate, requireAdminOrOperator, async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const items = await adminPersonalityService.listResultTypes();
    res.json({ success: true, items });
  } catch (error) {
    handleError(res, error, 'Failed to fetch personality result types');
  }
});

router.get('/result-types/:id', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const item = await adminPersonalityService.getResultType(normalizeRouteId(req.params.id));
    res.json({ success: true, item });
  } catch (error) {
    handleError(res, error, 'Failed to fetch personality result type');
  }
});

router.post('/result-types', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const item = await adminPersonalityService.createResultType(req.body || {});
    await adminAuditService.createAction({
      actorId: req.user?.userId || 'unknown',
      action: 'personality.result_type.create',
      targetType: 'personality_result_type',
      targetId: item.id,
      detail: item,
    });
    res.status(201).json({ success: true, item });
  } catch (error) {
    handleError(res, error, 'Failed to create personality result type');
  }
});

router.patch('/result-types/:id', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const item = await adminPersonalityService.updateResultType(normalizeRouteId(req.params.id), req.body || {});
    await adminAuditService.createAction({
      actorId: req.user?.userId || 'unknown',
      action: 'personality.result_type.update',
      targetType: 'personality_result_type',
      targetId: item.id,
      detail: item,
    });
    res.json({ success: true, item });
  } catch (error) {
    handleError(res, error, 'Failed to update personality result type');
  }
});

router.get('/debug-set', authenticate, requireAdminOrOperator, async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const result = await adminPersonalityService.getDebugSet();
    res.json({ success: true, ...result });
  } catch (error) {
    handleError(res, error, 'Failed to fetch personality debug set');
  }
});

router.patch('/debug-set', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const result = await adminPersonalityService.updateDebugSet(
      Array.isArray(req.body?.questionIds) ? (req.body.questionIds as string[]) : []
    );
    await adminAuditService.createAction({
      actorId: req.user?.userId || 'unknown',
      action: 'personality.debug_set.update',
      targetType: 'personality_debug_set',
      targetId: 'default',
      detail: result,
    });
    res.json({ success: true, ...result });
  } catch (error) {
    handleError(res, error, 'Failed to update personality debug set');
  }
});

export default router;
