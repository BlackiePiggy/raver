import { Router, Response } from 'express';
import { authenticate, type AuthRequest } from '../middleware/auth';
import {
  QuizServiceError,
  abandonQuizSession,
  createQuizSession,
  getQuizConfigSummary,
  getQuizStatus,
  submitQuizSession,
  type QuizSessionSubmitAnswer,
} from '../services/quiz.service';

const router: Router = Router();

const normalizeRouteId = (value: string | string[] | undefined): string => {
  if (Array.isArray(value)) {
    return value[0] ?? '';
  }
  return typeof value === 'string' ? value : '';
};

const handleQuizError = (res: Response, error: unknown): void => {
  if (error instanceof QuizServiceError) {
    res.status(error.status).json({
      error: error.message,
      code: error.code,
    });
    return;
  }
  console.error('[quiz] unexpected error', error);
  res.status(500).json({
    error: 'Internal server error',
    code: 'QUIZ_INTERNAL_ERROR',
  });
};

router.get('/config', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  const userId = req.user?.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized', code: 'AUTH_REQUIRED' });
    return;
  }
  try {
    const summary = await getQuizConfigSummary(userId);
    res.json(summary);
  } catch (error) {
    handleQuizError(res, error);
  }
});

router.get('/status', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  const userId = req.user?.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized', code: 'AUTH_REQUIRED' });
    return;
  }
  try {
    const summary = await getQuizStatus(userId);
    res.json(summary);
  } catch (error) {
    handleQuizError(res, error);
  }
});

router.post('/sessions', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  const userId = req.user?.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized', code: 'AUTH_REQUIRED' });
    return;
  }
  try {
    const session = await createQuizSession(userId);
    res.status(201).json(session);
  } catch (error) {
    handleQuizError(res, error);
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
      code: 'QUIZ_SUBMIT_ANSWERS_REQUIRED',
    });
    return;
  }

  const answers: QuizSessionSubmitAnswer[] = answersInput.map((item: any) => ({
    questionId: typeof item?.questionId === 'string' ? item.questionId.trim() : '',
    optionId: typeof item?.optionId === 'string' && item.optionId.trim() ? item.optionId.trim() : null,
  }));

  if (answers.some((item) => !item.questionId)) {
    res.status(400).json({
      error: 'Each answer must include questionId',
      code: 'QUIZ_SUBMIT_QUESTION_ID_REQUIRED',
    });
    return;
  }

  try {
    const result = await submitQuizSession(userId, normalizeRouteId(req.params.id), answers);
    res.json(result);
  } catch (error) {
    handleQuizError(res, error);
  }
});

router.post('/sessions/:id/abandon', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  const userId = req.user?.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized', code: 'AUTH_REQUIRED' });
    return;
  }
  try {
    const result = await abandonQuizSession(userId, normalizeRouteId(req.params.id));
    res.json(result);
  } catch (error) {
    handleQuizError(res, error);
  }
});

export default router;
