import 'dotenv/config';

const directDatabaseUrl = process.env.DIRECT_URL || process.env.DATABASE_URL;
if (directDatabaseUrl) {
  process.env.DATABASE_URL = directDatabaseUrl;
}

const logStage = (stage: string, details?: Record<string, unknown>): void => {
  if (details) {
    console.log(`[quiz-preflight-smoke] ${stage}`, details);
    return;
  }
  console.log(`[quiz-preflight-smoke] ${stage}`);
};

const TEMP_EMAIL = 'quiz-preflight-smoke-user@local.test';
const TEMP_USERNAME = 'quiz_preflight_smoke_user';
const STANDARD_TEXT_QUESTION_COUNT = 15;
const STANDARD_IMAGE_QUESTION_COUNT = 5;
const STANDARD_QUESTION_COUNT = STANDARD_TEXT_QUESTION_COUNT + STANDARD_IMAGE_QUESTION_COUNT;
const MIN_IMAGE_POOL_COUNT_WITH_RESERVE = STANDARD_IMAGE_QUESTION_COUNT + 1;
const SMOKE_IMAGE_DATA_URL =
  'data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%221%22 height=%221%22%3E%3C/svg%3E';

const assert = (condition: boolean, message: string): void => {
  if (!condition) {
    throw new Error(message);
  }
};

type SnapshotQuestion = {
  questionId: string;
  correctOptionId: string;
  options: Array<{
    optionId: string;
  }>;
};

type SnapshotEnvelope = {
  questions: SnapshotQuestion[];
};

const main = async (): Promise<void> => {
  const { PrismaClient, QuizQuestionStatus, QuizQuestionType } = await import('@prisma/client');
  const { createQuizSession, submitQuizSession, abandonQuizSession, getQuizStatus } = await import('../services/quiz.service');

  const prisma = new PrismaClient();
  const createdQuestionIds: string[] = [];
  let originalConfig:
    | {
        id: string;
        isEnabled: boolean;
        questionCount: number;
        passCorrectCount: number;
        dailyAttemptLimit: number;
        defaultTimeLimitSec: number;
        dailyLimitTimeZone: string;
        allowRetakeAfterPass: boolean;
        allowRestartDuringSession: boolean;
        debugQuestionIds: string[];
      }
    | null = null;

  const ensureTestUser = async (): Promise<string> => {
    const existing = await prisma.user.findUnique({
      where: { email: TEMP_EMAIL },
      select: { id: true },
    });
    if (existing) {
      return existing.id;
    }

    const created = await prisma.user.create({
      data: {
        email: TEMP_EMAIL,
        username: TEMP_USERNAME,
        passwordHash: 'quiz-preflight-smoke-password-hash',
        displayName: 'Quiz Preflight Smoke User',
      },
      select: { id: true },
    });
    return created.id;
  };

  const cleanupUserQuizState = async (userId: string): Promise<void> => {
    await prisma.quizAttemptLedger.deleteMany({ where: { userId } });
    await prisma.quizSession.deleteMany({ where: { userId } });
    await prisma.quizUserPolicyOverride.deleteMany({ where: { userId } });
  };

  const createSmokeQuestion = async (index: number, isImageQuestion: boolean): Promise<void> => {
    const question = await prisma.quizQuestion.create({
      data: {
        status: QuizQuestionStatus.active,
        type: QuizQuestionType.single_choice,
        stemText: `Quiz preflight smoke question ${Date.now()}-${index}`,
        stemImageUrl: isImageQuestion ? SMOKE_IMAGE_DATA_URL : null,
        timeLimitSec: 15,
        sortOrder: 950_000 + index,
      },
      select: { id: true },
    });
    createdQuestionIds.push(question.id);

    const optionA = await prisma.quizQuestionOption.create({
      data: {
        questionId: question.id,
        text: 'Option A',
        sortOrder: 0,
      },
      select: { id: true },
    });

    await prisma.quizQuestionOption.createMany({
      data: [
        {
          questionId: question.id,
          text: 'Option B',
          sortOrder: 1,
        },
        {
          questionId: question.id,
          text: 'Option C',
          sortOrder: 2,
        },
      ],
    });

    await prisma.quizQuestion.update({
      where: { id: question.id },
      data: {
        correctOptionId: optionA.id,
      },
    });
  };

  const ensureReservePool = async (): Promise<void> => {
    const existingActiveQuestions = await prisma.quizQuestion.findMany({
      where: {
        status: QuizQuestionStatus.active,
        type: QuizQuestionType.single_choice,
        correctOptionId: { not: null },
      },
      select: {
        correctOptionId: true,
        stemImageUrl: true,
        options: {
          select: {
            id: true,
            imageUrl: true,
          },
        },
      },
    });
    const eligibleActiveQuestions = existingActiveQuestions.filter((question) => {
      return question.options.some((option) => option.id === question.correctOptionId);
    });
    const imageQuestionCount = eligibleActiveQuestions.filter((question) => {
      return Boolean(question.stemImageUrl) || question.options.some((option) => Boolean(option.imageUrl));
    }).length;
    const textQuestionCount = eligibleActiveQuestions.length - imageQuestionCount;

    const textNeeded = Math.max(0, STANDARD_TEXT_QUESTION_COUNT - textQuestionCount);
    const imageNeeded = Math.max(0, MIN_IMAGE_POOL_COUNT_WITH_RESERVE - imageQuestionCount);
    for (let index = 0; index < textNeeded; index += 1) {
      await createSmokeQuestion(index, false);
    }
    for (let index = 0; index < imageNeeded; index += 1) {
      await createSmokeQuestion(textNeeded + index, true);
    }
  };

  const countImageQuestions = (questions: Array<{ stemImageUrl: string | null; options: Array<{ imageUrl: string | null }> }>): number => {
    return questions.filter((question) => {
      return Boolean(question.stemImageUrl) || question.options.some((option) => Boolean(option.imageUrl));
    }).length;
  };

  const readSnapshotEnvelope = async (sessionId: string): Promise<SnapshotEnvelope> => {
    const session = await prisma.quizSession.findUnique({
      where: { id: sessionId },
      select: { questionSnapshot: true },
    });
    assert(Boolean(session?.questionSnapshot), 'session snapshot should exist');
    const raw = session?.questionSnapshot as unknown as { questions?: SnapshotQuestion[] };
    assert(Array.isArray(raw.questions), 'session snapshot questions should be an array');
    return { questions: raw.questions ?? [] };
  };

  try {
    logStage('boot', { usingDirectUrl: Boolean(directDatabaseUrl) });

    originalConfig = await prisma.quizConfig.upsert({
      where: { id: 'default' },
      update: {},
      create: {
        id: 'default',
        isEnabled: true,
        questionCount: 20,
        passCorrectCount: 16,
        dailyAttemptLimit: 3,
        defaultTimeLimitSec: 20,
        dailyLimitTimeZone: 'Asia/Shanghai',
        allowRetakeAfterPass: true,
        allowRestartDuringSession: true,
        debugQuestionIds: [],
      },
      select: {
        id: true,
        isEnabled: true,
        questionCount: true,
        passCorrectCount: true,
        dailyAttemptLimit: true,
        defaultTimeLimitSec: true,
        dailyLimitTimeZone: true,
        allowRetakeAfterPass: true,
        allowRestartDuringSession: true,
        debugQuestionIds: true,
      },
    });

    logStage('ensureTestUser:start');
    const userId = await ensureTestUser();
    logStage('ensureTestUser:done', { userId });

    logStage('cleanupUserQuizState:start');
    await cleanupUserQuizState(userId);
    logStage('cleanupUserQuizState:done');

    logStage('ensureReservePool:start');
    await ensureReservePool();
    logStage('ensureReservePool:done', { createdQuestionCount: createdQuestionIds.length });

    logStage('config:standardQuestionCount:start');
    await prisma.quizConfig.update({
      where: { id: 'default' },
      data: {
        isEnabled: true,
        questionCount: STANDARD_QUESTION_COUNT,
        passCorrectCount: 16,
        dailyAttemptLimit: 10,
        defaultTimeLimitSec: 20,
        dailyLimitTimeZone: 'Asia/Shanghai',
        allowRetakeAfterPass: true,
        allowRestartDuringSession: true,
      },
    });
    logStage('config:standardQuestionCount:done');

    logStage('status:initial:start');
    const initialStatus = await getQuizStatus(userId);
    logStage('status:initial:done', {
      todayAttemptCount: initialStatus.todayAttemptCount,
      todayRemainingAttempts: initialStatus.todayRemainingAttempts,
    });

    logStage('session:create:preflight:start');
    const preflightSession = await createQuizSession(userId);
    logStage('session:create:preflight:done', {
      sessionId: preflightSession.sessionId,
      primaryCount: preflightSession.questions.length,
      reserveCount: preflightSession.reserveQuestions.length,
    });
    assert(preflightSession.questions.length === STANDARD_QUESTION_COUNT, 'primary question count should use standard 20');
    assert(countImageQuestions(preflightSession.questions) === STANDARD_IMAGE_QUESTION_COUNT, 'standard session should include 5 image questions');
    assert(preflightSession.reserveQuestions.length > 0, 'standard session should include reserve questions');

    const afterPreflightCreate = await getQuizStatus(userId);
    logStage('status:afterPreflightCreate:done', {
      todayAttemptCount: afterPreflightCreate.todayAttemptCount,
      activeSessionId: afterPreflightCreate.activeSessionId,
    });
    assert(afterPreflightCreate.todayAttemptCount === initialStatus.todayAttemptCount + 1, 'start should consume attempt');

    logStage('session:abandon:preflightFailed:start');
    const preflightAbandon = await abandonQuizSession(userId, preflightSession.sessionId, {
      reason: 'preflight_failed',
    });
    logStage('session:abandon:preflightFailed:done', { status: preflightAbandon.status });

    const afterRollbackStatus = await getQuizStatus(userId);
    logStage('status:afterRollback:done', {
      todayAttemptCount: afterRollbackStatus.todayAttemptCount,
      activeSessionId: afterRollbackStatus.activeSessionId,
    });
    assert(
      afterRollbackStatus.todayAttemptCount === initialStatus.todayAttemptCount,
      'preflight_failed should refund consumed attempt'
    );
    assert(afterRollbackStatus.activeSessionId === null, 'preflight_failed should close active session');

    logStage('session:create:replacement:start');
    const replacementSession = await createQuizSession(userId);
    logStage('session:create:replacement:done', {
      sessionId: replacementSession.sessionId,
      primaryCount: replacementSession.questions.length,
      reserveCount: replacementSession.reserveQuestions.length,
    });
    assert(replacementSession.questions.length === STANDARD_QUESTION_COUNT, 'replacement session should still use standard 20');
    assert(countImageQuestions(replacementSession.questions) === STANDARD_IMAGE_QUESTION_COUNT, 'replacement session should include 5 image questions');
    assert(replacementSession.reserveQuestions.length > 0, 'replacement session should include reserve questions');

    const snapshotEnvelope = await readSnapshotEnvelope(replacementSession.sessionId);
    const snapshotById = new Map(snapshotEnvelope.questions.map((question) => [question.questionId, question]));

    const replacementQuestion = replacementSession.reserveQuestions[0];
    const presentedQuestionIds = [
      replacementQuestion.questionId,
      ...replacementSession.questions.slice(1).map((question) => question.questionId),
    ];
    assert(
      new Set(presentedQuestionIds).size === replacementSession.questions.length,
      'presented question ids should remain deduplicated after replacement'
    );
    assert(
      !presentedQuestionIds.includes(replacementSession.questions[0]?.questionId ?? ''),
      'presented question ids should exclude the replaced primary question'
    );

    const answers = presentedQuestionIds.map((questionId) => {
      const snapshot = snapshotById.get(questionId);
      assert(Boolean(snapshot), `snapshot missing for presented question ${questionId}`);
      return {
        questionId,
        optionId: snapshot?.correctOptionId ?? null,
      };
    });

    logStage('session:submit:replacement:start');
    const submitResult = await submitQuizSession(userId, replacementSession.sessionId, answers, {
      presentedQuestionIds,
    });
    logStage('session:submit:replacement:done', {
      totalCount: submitResult.totalCount,
      correctCount: submitResult.correctCount,
      passed: submitResult.passed,
    });
    assert(submitResult.totalCount === STANDARD_QUESTION_COUNT, 'submit should score only the final presented question count');
    assert(submitResult.correctCount === STANDARD_QUESTION_COUNT, 'submit should score replacement reserve question correctly');
    assert(submitResult.passed === true, 'fully correct replacement session should pass');

    const finalStatus = await getQuizStatus(userId);
    logStage('status:final:done', {
      todayAttemptCount: finalStatus.todayAttemptCount,
      hasPermanentPass: finalStatus.hasPermanentPass,
    });
    assert(
      finalStatus.todayAttemptCount === initialStatus.todayAttemptCount + 1,
      'only the successfully started replacement session should remain consumed'
    );

    console.log('[quiz-preflight-smoke] passed', {
      userId,
      preflightSessionId: preflightSession.sessionId,
      replacementSessionId: replacementSession.sessionId,
      presentedQuestionIds,
    });
  } catch (error) {
    if (error instanceof Error && 'code' in error) {
      const prismaCode = (error as { code?: string }).code;
      if (prismaCode === 'P2021') {
        console.error(
          '[quiz-preflight-smoke] failed: quiz tables are missing in the current database. ' +
            'Apply the quiz migrations first, then rerun this smoke.'
        );
      } else if (prismaCode === 'P2022') {
        console.error(
          '[quiz-preflight-smoke] failed: the current database schema is behind the latest quiz migration ' +
            '(for example missing quiz_config.debug_question_ids). Apply the latest quiz migrations first, then rerun this smoke.'
        );
      } else {
        console.error('[quiz-preflight-smoke] failed', error);
      }
    } else {
      console.error('[quiz-preflight-smoke] failed', error);
    }
    process.exitCode = 1;
  } finally {
    if (originalConfig) {
      try {
        await prisma.quizConfig.upsert({
          where: { id: originalConfig.id },
          update: {
            isEnabled: originalConfig.isEnabled,
            questionCount: originalConfig.questionCount,
            passCorrectCount: originalConfig.passCorrectCount,
            dailyAttemptLimit: originalConfig.dailyAttemptLimit,
            defaultTimeLimitSec: originalConfig.defaultTimeLimitSec,
            dailyLimitTimeZone: originalConfig.dailyLimitTimeZone,
            allowRetakeAfterPass: originalConfig.allowRetakeAfterPass,
            allowRestartDuringSession: originalConfig.allowRestartDuringSession,
            debugQuestionIds: originalConfig.debugQuestionIds,
          },
          create: originalConfig,
        });
      } catch (restoreError) {
        console.error('[quiz-preflight-smoke] failed to restore config', restoreError);
        process.exitCode = 1;
      }
    }

    if (createdQuestionIds.length > 0) {
      try {
        await prisma.quizQuestionOption.deleteMany({
          where: {
            questionId: {
              in: createdQuestionIds,
            },
          },
        });
        await prisma.quizQuestion.deleteMany({
          where: {
            id: {
              in: createdQuestionIds,
            },
          },
        });
      } catch (cleanupError) {
        console.error('[quiz-preflight-smoke] failed to cleanup created questions', cleanupError);
        process.exitCode = 1;
      }
    }

    await prisma.$disconnect();
  }
};

void main();
