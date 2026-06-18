import 'dotenv/config';

const directDatabaseUrl = process.env.DIRECT_URL || process.env.DATABASE_URL;
if (directDatabaseUrl) {
  process.env.DATABASE_URL = directDatabaseUrl;
}

const logStage = (stage: string, details?: Record<string, unknown>): void => {
  if (details) {
    console.log(`[quiz-qualification-smoke] ${stage}`, details);
    return;
  }
  console.log(`[quiz-qualification-smoke] ${stage}`);
};

const main = async (): Promise<void> => {
  const { PrismaClient, QuizQuestionStatus, QuizQuestionType } = await import('@prisma/client');
  const { createQuizSession, getQuizStatus, submitQuizSession, abandonQuizSession } = await import(
    '../services/quiz.service'
  );
  const { accountQualificationService } = await import('../services/account-qualification.service');

  const prisma = new PrismaClient();
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
  const TEMP_EMAIL = 'quiz-smoke-user@local.test';
  const TEMP_USERNAME = 'quiz_smoke_user';
  const STANDARD_TEXT_QUESTION_COUNT = 15;
  const STANDARD_IMAGE_QUESTION_COUNT = 5;
  const STANDARD_QUESTION_COUNT = STANDARD_TEXT_QUESTION_COUNT + STANDARD_IMAGE_QUESTION_COUNT;
  const SMOKE_IMAGE_DATA_URL =
    'data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%221%22 height=%221%22%3E%3C/svg%3E';

  type SnapshotQuestion = {
    questionId: string;
    correctOptionId: string;
  };

  const assert = (condition: boolean, message: string): void => {
    if (!condition) {
      throw new Error(message);
    }
  };

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
        passwordHash: 'quiz-smoke-password-hash',
        displayName: 'Quiz Smoke User',
      },
      select: { id: true },
    });

    return created.id;
  };

  const createSmokeQuestion = async (index: number, isImageQuestion: boolean): Promise<void> => {
    const question = await prisma.quizQuestion.create({
      data: {
        status: QuizQuestionStatus.active,
        type: QuizQuestionType.single_choice,
        stemText: `Smoke question ${index + 1}`,
        stemImageUrl: isImageQuestion ? SMOKE_IMAGE_DATA_URL : null,
        timeLimitSec: 20,
        sortOrder: 10_000 + index,
      },
      select: { id: true },
    });

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
      data: { correctOptionId: optionA.id },
    });
  };

  const ensureQuizPool = async (): Promise<void> => {
    await prisma.quizConfig.upsert({
      where: { id: 'default' },
      update: {
        isEnabled: true,
        questionCount: STANDARD_QUESTION_COUNT,
        passCorrectCount: 16,
        dailyAttemptLimit: 20,
        defaultTimeLimitSec: 20,
        allowRetakeAfterPass: true,
        allowRestartDuringSession: true,
      },
      create: {
        id: 'default',
        isEnabled: true,
        questionCount: STANDARD_QUESTION_COUNT,
        passCorrectCount: 16,
        dailyAttemptLimit: 20,
        defaultTimeLimitSec: 20,
        dailyLimitTimeZone: 'Asia/Shanghai',
        allowRetakeAfterPass: true,
        allowRestartDuringSession: true,
      },
    });

    const existingQuestions = await prisma.quizQuestion.findMany({
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
    const eligibleQuestions = existingQuestions.filter((question) => {
      return question.options.some((option) => option.id === question.correctOptionId);
    });
    const imageQuestionCount = eligibleQuestions.filter((question) => {
      return Boolean(question.stemImageUrl) || question.options.some((option) => Boolean(option.imageUrl));
    }).length;
    const textQuestionCount = eligibleQuestions.length - imageQuestionCount;

    const textNeeded = Math.max(0, STANDARD_TEXT_QUESTION_COUNT - textQuestionCount);
    const imageNeeded = Math.max(0, STANDARD_IMAGE_QUESTION_COUNT - imageQuestionCount);
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

  const cleanupUserQuizState = async (userId: string): Promise<void> => {
    await prisma.quizAttemptLedger.deleteMany({ where: { userId } });
    await prisma.quizSession.deleteMany({ where: { userId } });
    await prisma.quizUserPolicyOverride.deleteMany({ where: { userId } });
  };

  const readSnapshotQuestions = async (sessionId: string): Promise<SnapshotQuestion[]> => {
    const session = await prisma.quizSession.findUnique({
      where: { id: sessionId },
      select: { questionSnapshot: true },
    });
    const raw = session?.questionSnapshot as unknown as { questions?: SnapshotQuestion[] } | null;
    assert(Array.isArray(raw?.questions), 'session snapshot questions should be an array');
    return raw?.questions ?? [];
  };

  try {
    logStage('boot', { usingDirectUrl: Boolean(directDatabaseUrl) });

    originalConfig = await prisma.quizConfig.upsert({
      where: { id: 'default' },
      update: {},
      create: {
        id: 'default',
        isEnabled: true,
        questionCount: STANDARD_QUESTION_COUNT,
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

    logStage('ensureQuizPool:start');
    await ensureQuizPool();
    logStage('ensureQuizPool:done');

    logStage('cleanupUserQuizState:start');
    await cleanupUserQuizState(userId);
    logStage('cleanupUserQuizState:done');

    logStage('getQuizStatus:initial:start');
    const initialStatus = await getQuizStatus(userId);
    logStage('getQuizStatus:initial:done', {
      canStart: initialStatus.canStart,
      todayAttemptCount: initialStatus.todayAttemptCount,
    });
    assert(initialStatus.hasPermanentPass === false, 'initial hasPermanentPass should be false');

    logStage('qualification:initial:start');
    const initialQualifications = await accountQualificationService.getSummary(userId);
    logStage('qualification:initial:done', {
      status: initialQualifications.items[0]?.status ?? null,
    });
    assert(initialQualifications.items.length === 1, 'qualification items should include quiz entry');
    assert(initialQualifications.items[0]?.key === 'quiz_pass', 'qualification key should be quiz_pass');
    assert(initialQualifications.items[0]?.status === 'unqualified', 'initial qualification should be unqualified');

    logStage('createQuizSession:abandon:start');
    const session = await createQuizSession(userId);
    logStage('createQuizSession:abandon:done', {
      sessionId: session.sessionId,
      questionCount: session.questions.length,
    });
    assert(session.questions.length === STANDARD_QUESTION_COUNT, 'session should contain 20 questions');
    assert(countImageQuestions(session.questions) === STANDARD_IMAGE_QUESTION_COUNT, 'session should contain 5 image questions');
    assert(
      session.questions.every((question) => !('correctOptionId' in (question as Record<string, unknown>))),
      'client session payload must not expose correctOptionId'
    );

    logStage('getQuizStatus:afterFirstStart:start');
    const statusAfterFirstStart = await getQuizStatus(userId);
    logStage('getQuizStatus:afterFirstStart:done', {
      todayAttemptCount: statusAfterFirstStart.todayAttemptCount,
      activeSessionId: statusAfterFirstStart.activeSessionId,
    });
    assert(statusAfterFirstStart.todayAttemptCount === 1, 'attempt count should increment immediately after first start');
    assert(statusAfterFirstStart.activeSessionId === session.sessionId, 'active session id should match first session');

    logStage('abandonQuizSession:start');
    const abandonResult = await abandonQuizSession(userId, session.sessionId);
    logStage('abandonQuizSession:done', { status: abandonResult.status });
    assert(abandonResult.status === 'abandoned', 'session should be abandoned');

    logStage('getQuizStatus:afterAbandon:start');
    const statusAfterAbandon = await getQuizStatus(userId);
    logStage('getQuizStatus:afterAbandon:done', {
      todayAttemptCount: statusAfterAbandon.todayAttemptCount,
      activeSessionId: statusAfterAbandon.activeSessionId,
    });
    assert(statusAfterAbandon.todayAttemptCount === 1, 'abandon must not refund attempt count');
    assert(statusAfterAbandon.activeSessionId === null, 'abandoned session should no longer be active');

    logStage('createQuizSession:submit:start');
    const submitSession = await createQuizSession(userId);
    logStage('createQuizSession:submit:done', {
      sessionId: submitSession.sessionId,
      questionCount: submitSession.questions.length,
    });
    assert(
      submitSession.questions.every((question) => !('correctOptionId' in (question as Record<string, unknown>))),
      'submit session payload must not expose correctOptionId'
    );
    assert(
      countImageQuestions(submitSession.questions) === STANDARD_IMAGE_QUESTION_COUNT,
      'submit session should contain 5 image questions'
    );

    logStage('getQuizStatus:afterSecondStart:start');
    const statusAfterSecondStart = await getQuizStatus(userId);
    logStage('getQuizStatus:afterSecondStart:done', {
      todayAttemptCount: statusAfterSecondStart.todayAttemptCount,
      activeSessionId: statusAfterSecondStart.activeSessionId,
    });
    assert(statusAfterSecondStart.todayAttemptCount === 2, 'second start should consume another attempt');
    assert(
      statusAfterSecondStart.activeSessionId === submitSession.sessionId,
      'active session id should match second session'
    );

    const snapshotQuestions = await readSnapshotQuestions(submitSession.sessionId);
    const snapshotById = new Map(snapshotQuestions.map((question) => [question.questionId, question]));
    const answers = submitSession.questions.map((question, index) => ({
      questionId: question.questionId,
      optionId: index < 16 ? snapshotById.get(question.questionId)?.correctOptionId ?? null : null,
    }));

    logStage('submitQuizSession:start');
    const submitResult = await submitQuizSession(userId, submitSession.sessionId, answers);
    logStage('submitQuizSession:done', {
      passed: submitResult.passed,
      correctCount: submitResult.correctCount,
    });
    assert(submitResult.passed === true, 'submit result should be passed');
    assert(submitResult.correctCount >= 16, 'correctCount should reach pass threshold');

    logStage('getQuizStatus:final:start');
    const finalStatus = await getQuizStatus(userId);
    logStage('getQuizStatus:final:done', {
      hasPermanentPass: finalStatus.hasPermanentPass,
      todayAttemptCount: finalStatus.todayAttemptCount,
      activeSessionId: finalStatus.activeSessionId,
    });
    assert(finalStatus.hasPermanentPass === true, 'final status should mark permanent pass');
    assert(finalStatus.todayAttemptCount === 2, 'final attempt count should preserve consumed starts');
    assert(finalStatus.activeSessionId === null, 'submitted session should no longer be active');

    logStage('qualification:final:start');
    const finalQualifications = await accountQualificationService.getSummary(userId);
    logStage('qualification:final:done', {
      status: finalQualifications.items[0]?.status ?? null,
    });
    assert(finalQualifications.items[0]?.status === 'qualified', 'final qualification should be qualified');

    console.log('[quiz-qualification-smoke] passed', {
      userId,
      firstSessionId: session.sessionId,
      secondSessionId: submitSession.sessionId,
      correctCount: submitResult.correctCount,
      passedAt: submitResult.passedAt,
    });
  } catch (error) {
    if (
      error instanceof Error &&
      'code' in error &&
      (error as { code?: string }).code === 'P2021'
    ) {
      console.error(
        '[quiz-qualification-smoke] failed: quiz tables are missing in the current database. ' +
          'Apply the quiz migrations first, then rerun this smoke.'
      );
    } else {
      console.error('[quiz-qualification-smoke] failed', error);
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
        console.error('[quiz-qualification-smoke] failed to restore config', restoreError);
        process.exitCode = 1;
      }
    }

    await prisma.$disconnect();
  }
};

void main();
