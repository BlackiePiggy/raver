import 'dotenv/config';

const directDatabaseUrl = process.env.DIRECT_URL || process.env.DATABASE_URL;
if (directDatabaseUrl) {
  process.env.DATABASE_URL = directDatabaseUrl;
}

const logStage = (stage: string, details?: Record<string, unknown>): void => {
  if (details) {
    console.log(`[quiz-admin-smoke] ${stage}`, details);
    return;
  }
  console.log(`[quiz-admin-smoke] ${stage}`);
};

const TEMP_EMAIL = 'quiz-admin-smoke-user@local.test';
const TEMP_USERNAME = 'quiz_admin_smoke_user';

const assert = (condition: boolean, message: string): void => {
  if (!condition) {
    throw new Error(message);
  }
};

const main = async (): Promise<void> => {
  const { PrismaClient, QuizAttemptMode, QuizQuestionStatus, QuizQuestionType } = await import('@prisma/client');
  const { adminQuizService } = await import('../modules/admin/admin-quiz.service');

  const prisma = new PrismaClient();

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
        passwordHash: 'quiz-admin-smoke-password-hash',
        displayName: 'Quiz Admin Smoke User',
      },
      select: { id: true },
    });

    return created.id;
  };

  let createdQuestionId: string | null = null;
  let originalConfig: Awaited<ReturnType<typeof adminQuizService.getConfig>> | null = null;

  try {
    logStage('boot', { usingDirectUrl: Boolean(directDatabaseUrl) });

    logStage('ensureTestUser:start');
    const userId = await ensureTestUser();
    logStage('ensureTestUser:done', { userId });

    logStage('config:get:start');
    originalConfig = await adminQuizService.getConfig();
    logStage('config:get:done', {
      questionCount: originalConfig.questionCount,
      passCorrectCount: originalConfig.passCorrectCount,
      dailyAttemptLimit: originalConfig.dailyAttemptLimit,
    });

    logStage('config:update:start');
    const updatedConfig = await adminQuizService.updateConfig({
      isEnabled: true,
      questionCount: 20,
      passCorrectCount: 15,
      dailyAttemptLimit: 5,
      defaultTimeLimitSec: 25,
      dailyLimitTimeZone: 'Asia/Shanghai',
      allowRetakeAfterPass: true,
      allowRestartDuringSession: true,
    });
    logStage('config:update:done', {
      questionCount: updatedConfig.questionCount,
      passCorrectCount: updatedConfig.passCorrectCount,
      dailyAttemptLimit: updatedConfig.dailyAttemptLimit,
    });
    assert(updatedConfig.passCorrectCount === 15, 'config passCorrectCount should be updated');
    assert(updatedConfig.dailyAttemptLimit === 5, 'config dailyAttemptLimit should be updated');

    const draftOptionAId = `draft-opt-a-${Date.now()}`;
    const draftOptionBId = `draft-opt-b-${Date.now()}`;
    const draftOptionCId = `draft-opt-c-${Date.now()}`;

    logStage('question:create:start');
    const createdQuestion = await adminQuizService.createQuestion({
      status: QuizQuestionStatus.draft,
      type: QuizQuestionType.single_choice,
      stemText: 'Smoke admin question',
      stemImageUrl: null,
      correctOptionId: draftOptionBId,
      timeLimitSec: 18,
      sortOrder: 900001,
      tags: ['smoke', 'admin'],
      difficulty: 'medium',
      explanation: 'admin smoke explanation',
      options: [
        { id: draftOptionAId, text: 'Option A', sortOrder: 0 },
        { id: draftOptionBId, text: 'Option B', sortOrder: 1 },
        { id: draftOptionCId, text: 'Option C', sortOrder: 2 },
      ],
    });
    createdQuestionId = createdQuestion.id;
    logStage('question:create:done', {
      questionId: createdQuestion.id,
      optionCount: createdQuestion.options.length,
      correctOptionId: createdQuestion.correctOptionId,
    });
    assert(createdQuestion.options.length === 3, 'created question should contain 3 options');
    assert(createdQuestion.correctOptionId != null, 'created question should have persisted correctOptionId');

    logStage('question:get:start');
    const fetchedQuestion = await adminQuizService.getQuestion(createdQuestion.id);
    logStage('question:get:done', { status: fetchedQuestion.status, stemText: fetchedQuestion.stemText });
    assert(fetchedQuestion.stemText === 'Smoke admin question', 'fetched question should match created question');

    logStage('question:list:start');
    const listResult = await adminQuizService.listQuestions({
      q: 'Smoke admin question',
      status: QuizQuestionStatus.draft,
      page: 1,
      limit: 20,
    });
    logStage('question:list:done', { total: listResult.pagination.total });
    assert(listResult.items.some((item) => item.id === createdQuestion.id), 'listQuestions should include created question');

    const updateOptionAId = `update-opt-a-${Date.now()}`;
    const updateOptionBId = `update-opt-b-${Date.now()}`;

    logStage('question:update:start');
    const updatedQuestion = await adminQuizService.updateQuestion(createdQuestion.id, {
      status: QuizQuestionStatus.active,
      type: QuizQuestionType.single_choice,
      stemText: 'Smoke admin question updated',
      stemImageUrl: 'https://example.com/quiz-smoke-image.jpg',
      correctOptionId: updateOptionAId,
      timeLimitSec: 22,
      sortOrder: 900002,
      tags: ['smoke', 'updated'],
      difficulty: 'hard',
      explanation: 'updated explanation',
      options: [
        { id: updateOptionAId, text: 'Updated Option A', sortOrder: 0 },
        { id: updateOptionBId, text: 'Updated Option B', sortOrder: 1 },
      ],
    });
    logStage('question:update:done', {
      status: updatedQuestion.status,
      optionCount: updatedQuestion.options.length,
      stemImageUrl: updatedQuestion.stemImageUrl,
    });
    assert(updatedQuestion.status === QuizQuestionStatus.active, 'updated question should be active');
    assert(updatedQuestion.options.length === 2, 'updated question should contain 2 options');

    logStage('question:archive:start');
    const archivedQuestion = await adminQuizService.archiveQuestion(createdQuestion.id);
    logStage('question:archive:done', { status: archivedQuestion.status });
    assert(archivedQuestion.status === QuizQuestionStatus.archived, 'question should be archived');

    logStage('override:update:start');
    const override = await adminQuizService.updateUserOverride({
      userId,
      attemptMode: QuizAttemptMode.unlimited,
      note: 'quiz admin smoke override',
      updatedBy: userId,
    });
    logStage('override:update:done', {
      attemptMode: override.attemptMode,
      dailyAttemptLimitOverride: override.dailyAttemptLimitOverride,
    });
    assert(override.attemptMode === QuizAttemptMode.unlimited, 'override should be unlimited');

    logStage('override:list:start');
    const overrideList = await adminQuizService.listUserOverrides({
      q: TEMP_EMAIL,
      page: 1,
      limit: 20,
    });
    logStage('override:list:done', { total: overrideList.pagination.total });
    assert(overrideList.items.some((item) => item.userId === userId), 'override list should include target user');

    console.log('[quiz-admin-smoke] passed', {
      userId,
      questionId: createdQuestionId,
    });
  } catch (error) {
    console.error('[quiz-admin-smoke] failed', error);
    process.exitCode = 1;
  } finally {
    if (originalConfig) {
      try {
        await adminQuizService.updateConfig({
          isEnabled: originalConfig.isEnabled,
          questionCount: originalConfig.questionCount,
          passCorrectCount: originalConfig.passCorrectCount,
          dailyAttemptLimit: originalConfig.dailyAttemptLimit,
          defaultTimeLimitSec: originalConfig.defaultTimeLimitSec,
          dailyLimitTimeZone: originalConfig.dailyLimitTimeZone,
          allowRetakeAfterPass: originalConfig.allowRetakeAfterPass,
          allowRestartDuringSession: originalConfig.allowRestartDuringSession,
        });
      } catch (restoreError) {
        console.error('[quiz-admin-smoke] failed to restore config', restoreError);
        process.exitCode = 1;
      }
    }

    if (createdQuestionId) {
      try {
        await prisma.quizQuestionOption.deleteMany({ where: { questionId: createdQuestionId } });
        await prisma.quizQuestion.deleteMany({ where: { id: createdQuestionId } });
      } catch (cleanupError) {
        console.error('[quiz-admin-smoke] failed to cleanup question', cleanupError);
        process.exitCode = 1;
      }
    }

    try {
      await prisma.quizUserPolicyOverride.deleteMany({
        where: {
          user: {
            email: TEMP_EMAIL,
          },
        },
      });
    } catch (cleanupError) {
      console.error('[quiz-admin-smoke] failed to cleanup override', cleanupError);
      process.exitCode = 1;
    }

    await prisma.$disconnect();
  }
};

void main();
