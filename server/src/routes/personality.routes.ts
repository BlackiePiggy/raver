import { Router, Response } from 'express';
import { authenticate, type AuthRequest } from '../middleware/auth';
import {
  PersonalityServiceError,
  abandonPersonalitySession,
  createPersonalitySession,
  getPersonalityResult,
  getPersonalityStatus,
  savePersonalitySessionAnswer,
  submitPersonalitySession,
  type PersonalitySessionAnswer,
  type PersonalitySessionMode,
} from '../services/personality.service';

const router: Router = Router();

const normalizeRouteId = (value: string | string[] | undefined): string => {
  if (Array.isArray(value)) {
    return value[0] ?? '';
  }
  return typeof value === 'string' ? value : '';
};

const handlePersonalityError = (res: Response, error: unknown): void => {
  if (error instanceof PersonalityServiceError) {
    res.status(error.status).json({
      error: error.message,
      code: error.code,
    });
    return;
  }
  console.error('[personality] unexpected error', error);
  res.status(500).json({
    error: 'Internal server error',
    code: 'PERSONALITY_INTERNAL_ERROR',
  });
};

router.get('/status', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  const userId = req.user?.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized', code: 'AUTH_REQUIRED' });
    return;
  }
  try {
    const summary = await getPersonalityStatus(userId, {
      userRole: req.user?.role ?? null,
    });
    res.json(summary);
  } catch (error) {
    handlePersonalityError(res, error);
  }
});

router.get('/result', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  const userId = req.user?.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized', code: 'AUTH_REQUIRED' });
    return;
  }
  try {
    const result = await getPersonalityResult(userId);
    res.json({ result });
  } catch (error) {
    handlePersonalityError(res, error);
  }
});

router.post('/sessions', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  const userId = req.user?.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized', code: 'AUTH_REQUIRED' });
    return;
  }
  try {
    const modeInput = typeof req.body?.mode === 'string' ? req.body.mode.trim() : '';
    const mode: PersonalitySessionMode = modeInput === 'debug_set' ? 'debug_set' : 'standard';
    const session = await createPersonalitySession(userId, {
      mode,
      userRole: req.user?.role ?? null,
    });
    res.status(201).json(session);
  } catch (error) {
    handlePersonalityError(res, error);
  }
});

router.post('/sessions/:id/answer', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  const userId = req.user?.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized', code: 'AUTH_REQUIRED' });
    return;
  }

  const answersInput = Array.isArray(req.body?.answers) ? req.body.answers : null;
  if (!answersInput) {
    res.status(400).json({
      error: 'answers is required',
      code: 'PERSONALITY_ANSWER_REQUIRED',
    });
    return;
  }

  const answers: PersonalitySessionAnswer[] = answersInput.map((item: any) => ({
    questionId: typeof item?.questionId === 'string' ? item.questionId.trim() : '',
    optionId: typeof item?.optionId === 'string' && item.optionId.trim() ? item.optionId.trim() : null,
  }));

  if (answers.some((item) => !item.questionId)) {
    res.status(400).json({
      error: 'Each answer must include questionId',
      code: 'PERSONALITY_ANSWER_QUESTION_ID_REQUIRED',
    });
    return;
  }

  try {
    const result = await savePersonalitySessionAnswer(userId, normalizeRouteId(req.params.id), {
      answers,
      currentQuestionIndex:
        typeof req.body?.currentQuestionIndex === 'number' && Number.isFinite(req.body.currentQuestionIndex)
          ? Math.floor(req.body.currentQuestionIndex)
          : undefined,
    });
    res.json(result);
  } catch (error) {
    handlePersonalityError(res, error);
  }
});

router.post('/sessions/:id/submit', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  const userId = req.user?.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized', code: 'AUTH_REQUIRED' });
    return;
  }

  const answersInput = Array.isArray(req.body?.answers) ? req.body.answers : null;
  if (!answersInput) {
    res.status(400).json({
      error: 'answers is required',
      code: 'PERSONALITY_SUBMIT_ANSWERS_REQUIRED',
    });
    return;
  }

  const answers: PersonalitySessionAnswer[] = answersInput.map((item: any) => ({
    questionId: typeof item?.questionId === 'string' ? item.questionId.trim() : '',
    optionId: typeof item?.optionId === 'string' && item.optionId.trim() ? item.optionId.trim() : null,
  }));

  if (answers.some((item) => !item.questionId)) {
    res.status(400).json({
      error: 'Each answer must include questionId',
      code: 'PERSONALITY_SUBMIT_QUESTION_ID_REQUIRED',
    });
    return;
  }

  try {
    const result = await submitPersonalitySession(userId, normalizeRouteId(req.params.id), answers);
    res.json(result);
  } catch (error) {
    handlePersonalityError(res, error);
  }
});

router.post('/sessions/:id/abandon', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  const userId = req.user?.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized', code: 'AUTH_REQUIRED' });
    return;
  }
  try {
    const result = await abandonPersonalitySession(userId, normalizeRouteId(req.params.id));
    res.json(result);
  } catch (error) {
    handlePersonalityError(res, error);
  }
});

export default router;
