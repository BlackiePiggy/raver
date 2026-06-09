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
  const TEMP_EMAIL = 'quiz-smoke-user@local.test';
  const TEMP_USERNAME = 'quiz_smoke_user';

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

  const ensureQuizPool = async (): Promise<void> => {
    const config = await prisma.quizConfig.upsert({
      where: { id: 'default' },
      update: {
        isEnabled: true,
        questionCount: 20,
        passCorrectCount: 16,
        dailyAttemptLimit: 20,
        defaultTimeLimitSec: 20,
        allowRetakeAfterPass: true,
        allowRestartDuringSession: true,
      },
      create: {
        id: 'default',
        isEnabled: true,
        questionCount: 20,
        passCorrectCount: 16,
        dailyAttemptLimit: 20,
        defaultTimeLimitSec: 20,
        dailyLimitTimeZone: 'Asia/Shanghai',
        allowRetakeAfterPass: true,
        allowRestartDuringSession: true,
      },
    });

    const existingCount = await prisma.quizQuestion.count({
      where: {
        status: QuizQuestionStatus.active,
        type: QuizQuestionType.single_choice,
      },
    });

    const needed = Math.max(0, config.questionCount - existingCount);
    for (let index = 0; index < needed; index += 1) {
      const question = await prisma.quizQuestion.create({
        data: {
          status: QuizQuestionStatus.active,
          type: QuizQuestionType.single_choice,
          stemText: `Smoke question ${index + 1}`,
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
    }
  };

  const cleanupUserQuizState = async (userId: string): Promise<void> => {
    await prisma.quizAttemptLedger.deleteMany({ where: { userId } });
    await prisma.quizSession.deleteMany({ where: { userId } });
    await prisma.quizUserPolicyOverride.deleteMany({ where: { userId } });
  };

  try {
    logStage('boot', { usingDirectUrl: Boolean(directDatabaseUrl) });

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
    assert(session.questions.length === 20, 'session should contain 20 questions');
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

    const answers = submitSession.questions.map((question, index) => ({
      questionId: question.questionId,
      optionId: index < 16 ? question.options[0]?.optionId ?? null : null,
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
    await prisma.$disconnect();
  }
};

void main();
