import {
  Prisma,
  QuizAttemptMode,
  QuizQuestionStatus,
  QuizQuestionType,
  QuizSessionStatus,
} from '@prisma/client';
import { prisma } from '../lib/prisma';

const QUIZ_CONFIG_ID = 'default';
const QUIZ_SESSION_TTL_MS = 2 * 60 * 60 * 1000;
const MIN_OPTION_COUNT = 2;
const MAX_OPTION_COUNT = 6;

type QuizConfigRecord = Awaited<ReturnType<typeof prisma.quizConfig.upsert>>;

type QuizQuestionOptionPayload = {
  optionId: string;
  text: string | null;
  imageUrl: string | null;
  sortOrder: number;
};

type QuizQuestionClientPayload = {
  questionId: string;
  stemText: string;
  stemImageUrl: string | null;
  options: QuizQuestionOptionPayload[];
  timeLimitSec: number;
};

type QuizQuestionServerSnapshot = QuizQuestionClientPayload & {
  correctOptionId: string;
};

type QuizConfigSnapshot = {
  questionCount: number;
  passCorrectCount: number;
  dailyAttemptLimit: number;
  defaultTimeLimitSec: number;
  dailyLimitTimeZone: string;
  allowRetakeAfterPass: boolean;
  allowRestartDuringSession: boolean;
};

type QuizQuestionSnapshotEnvelope = {
  questions: QuizQuestionServerSnapshot[];
};

type QuizPermanentPassRecord = {
  passed: boolean;
  passedAt: Date | null;
};

type QuizUserPolicyOverrideRecord = {
  attemptMode: QuizAttemptMode;
  dailyAttemptLimitOverride: number | null;
};

type EffectiveAttemptPolicy = {
  attemptMode: QuizAttemptMode;
  dailyAttemptLimit: number | null;
  isUnlimited: boolean;
};

export type QuizStatusSummary = {
  isEnabled: boolean;
  questionCount: number;
  passCorrectCount: number;
  dailyAttemptLimit: number;
  effectiveDailyAttemptLimit: number | null;
  isUnlimitedAttempts: boolean;
  attemptMode: QuizAttemptMode;
  defaultTimeLimitSec: number;
  dailyLimitTimeZone: string;
  allowRetakeAfterPass: boolean;
  allowRestartDuringSession: boolean;
  todayAttemptCount: number;
  todayRemainingAttempts: number;
  hasPermanentPass: boolean;
  passedAt: string | null;
  canStart: boolean;
  activeSessionId: string | null;
  disabledReason: string | null;
};

export type QuizSessionCreateResult = {
  sessionId: string;
  questionCount: number;
  passCorrectCount: number;
  dailyAttemptLimit: number;
  dailyRemainingAttemptsAfterStart: number;
  timeZone: string;
  questions: QuizQuestionClientPayload[];
  startedAt: string;
  expiresAt: string;
};

export type QuizSessionSubmitAnswer = {
  questionId: string;
  optionId: string | null;
};

export type QuizSessionSubmitResult = {
  sessionId: string;
  totalCount: number;
  correctCount: number;
  passCorrectCount: number;
  passed: boolean;
  passedAt: string | null;
};

export class QuizServiceError extends Error {
  status: number;
  code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

const formatDateKeyInTimeZone = (date: Date, timeZone: string): string => {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const parts = formatter.formatToParts(date);
  const readPart = (type: Intl.DateTimeFormatPartTypes): string => {
    return parts.find((item) => item.type === type)?.value ?? '';
  };
  return `${readPart('year')}-${readPart('month')}-${readPart('day')}@${timeZone}`;
};

const shuffle = <T>(items: T[]): T[] => {
  const next = items.slice();
  for (let index = next.length - 1; index > 0; index -= 1) {
    const randomIndex = Math.floor(Math.random() * (index + 1));
    [next[index], next[randomIndex]] = [next[randomIndex], next[index]];
  }
  return next;
};

const normalizePositiveInt = (value: number | null | undefined, fallback: number): number => {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  const normalized = Math.floor(value);
  return normalized > 0 ? normalized : fallback;
};

const ensureQuizConfig = async (
  tx: Prisma.TransactionClient | typeof prisma = prisma
): Promise<QuizConfigRecord> => {
  return tx.quizConfig.upsert({
    where: { id: QUIZ_CONFIG_ID },
    update: {},
    create: {
      id: QUIZ_CONFIG_ID,
      isEnabled: false,
      questionCount: 20,
      passCorrectCount: 16,
      dailyAttemptLimit: 3,
      defaultTimeLimitSec: 20,
      dailyLimitTimeZone: 'Asia/Shanghai',
      allowRetakeAfterPass: true,
      allowRestartDuringSession: true,
    },
  });
};

const readPermanentPassRecord = async (
  tx: Prisma.TransactionClient | typeof prisma,
  userId: string
): Promise<QuizPermanentPassRecord> => {
  const row = await tx.quizAttemptLedger.findFirst({
    where: { userId, passed: true },
    orderBy: [{ passedAt: 'asc' }, { updatedAt: 'asc' }],
    select: { passed: true, passedAt: true },
  });
  return {
    passed: Boolean(row?.passed),
    passedAt: row?.passedAt ?? null,
  };
};

const readQuizUserPolicyOverride = async (
  tx: Prisma.TransactionClient | typeof prisma,
  userId: string
): Promise<QuizUserPolicyOverrideRecord | null> => {
  return tx.quizUserPolicyOverride.findUnique({
    where: { userId },
    select: {
      attemptMode: true,
      dailyAttemptLimitOverride: true,
    },
  });
};

const resolveEffectiveAttemptPolicy = (
  config: QuizConfigRecord,
  override: QuizUserPolicyOverrideRecord | null
): EffectiveAttemptPolicy => {
  if (!override || override.attemptMode === QuizAttemptMode.default) {
    return {
      attemptMode: QuizAttemptMode.default,
      dailyAttemptLimit: config.dailyAttemptLimit,
      isUnlimited: false,
    };
  }

  if (override.attemptMode === QuizAttemptMode.unlimited) {
    return {
      attemptMode: QuizAttemptMode.unlimited,
      dailyAttemptLimit: null,
      isUnlimited: true,
    };
  }

  return {
    attemptMode: QuizAttemptMode.custom_limit,
    dailyAttemptLimit: normalizePositiveInt(override.dailyAttemptLimitOverride, config.dailyAttemptLimit),
    isUnlimited: false,
  };
};

const readQuizSnapshotEnvelope = (value: Prisma.JsonValue): QuizQuestionSnapshotEnvelope => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new QuizServiceError(500, 'QUIZ_SNAPSHOT_INVALID', 'Quiz session snapshot is invalid');
  }
  const questions = Array.isArray((value as { questions?: unknown }).questions)
    ? ((value as { questions: unknown[] }).questions as QuizQuestionServerSnapshot[])
    : null;
  if (!questions) {
    throw new QuizServiceError(500, 'QUIZ_SNAPSHOT_INVALID', 'Quiz session snapshot is invalid');
  }
  return { questions };
};

const createDisabledReason = (input: {
  config: QuizConfigRecord;
  hasPermanentPass: boolean;
  remainingAttempts: number;
  activeSessionId: string | null;
  isUnlimitedAttempts: boolean;
}): string | null => {
  if (!input.config.isEnabled) return 'quiz_disabled';
  if (input.hasPermanentPass && !input.config.allowRetakeAfterPass) return 'already_passed';
  if (!input.isUnlimitedAttempts && input.remainingAttempts <= 0) return 'daily_limit_reached';
  if (input.activeSessionId && !input.config.allowRestartDuringSession) return 'session_in_progress';
  return null;
};

export const getQuizStatus = async (userId: string): Promise<QuizStatusSummary> => {
  const config = await ensureQuizConfig();
  const todayDateKey = formatDateKeyInTimeZone(new Date(), config.dailyLimitTimeZone);
  const [todayLedger, permanentPass, activeSession, policyOverride] = await Promise.all([
    prisma.quizAttemptLedger.findUnique({
      where: {
        userId_attemptDateKey: {
          userId,
          attemptDateKey: todayDateKey,
        },
      },
      select: { attemptCount: true },
    }),
    readPermanentPassRecord(prisma, userId),
    prisma.quizSession.findFirst({
      where: { userId, status: QuizSessionStatus.in_progress },
      orderBy: { startedAt: 'desc' },
      select: { id: true },
    }),
    readQuizUserPolicyOverride(prisma, userId),
  ]);

  const effectivePolicy = resolveEffectiveAttemptPolicy(config, policyOverride);
  const todayAttemptCount = todayLedger?.attemptCount ?? 0;
  const todayRemainingAttempts = effectivePolicy.isUnlimited
    ? Number.MAX_SAFE_INTEGER
    : Math.max(0, (effectivePolicy.dailyAttemptLimit ?? config.dailyAttemptLimit) - todayAttemptCount);
  const disabledReason = createDisabledReason({
    config,
    hasPermanentPass: permanentPass.passed,
    remainingAttempts: todayRemainingAttempts,
    activeSessionId: activeSession?.id ?? null,
    isUnlimitedAttempts: effectivePolicy.isUnlimited,
  });

  return {
    isEnabled: config.isEnabled,
    questionCount: config.questionCount,
    passCorrectCount: config.passCorrectCount,
    dailyAttemptLimit: config.dailyAttemptLimit,
    effectiveDailyAttemptLimit: effectivePolicy.dailyAttemptLimit,
    isUnlimitedAttempts: effectivePolicy.isUnlimited,
    attemptMode: effectivePolicy.attemptMode,
    defaultTimeLimitSec: config.defaultTimeLimitSec,
    dailyLimitTimeZone: config.dailyLimitTimeZone,
    allowRetakeAfterPass: config.allowRetakeAfterPass,
    allowRestartDuringSession: config.allowRestartDuringSession,
    todayAttemptCount,
    todayRemainingAttempts: effectivePolicy.isUnlimited ? -1 : todayRemainingAttempts,
    hasPermanentPass: permanentPass.passed,
    passedAt: permanentPass.passedAt ? permanentPass.passedAt.toISOString() : null,
    canStart: disabledReason === null,
    activeSessionId: activeSession?.id ?? null,
    disabledReason,
  };
};

export const getQuizConfigSummary = async (userId: string): Promise<QuizStatusSummary> => {
  return getQuizStatus(userId);
};

export const createQuizSession = async (userId: string): Promise<QuizSessionCreateResult> => {
  return prisma.$transaction(async (tx) => {
    const config = await ensureQuizConfig(tx);
    const now = new Date();
    const todayDateKey = formatDateKeyInTimeZone(now, config.dailyLimitTimeZone);

    const [permanentPass, todayLedger, activeSessions, policyOverride, questionRows] = await Promise.all([
      readPermanentPassRecord(tx, userId),
      tx.quizAttemptLedger.findUnique({
        where: {
          userId_attemptDateKey: {
            userId,
            attemptDateKey: todayDateKey,
          },
        },
      }),
      tx.quizSession.findMany({
        where: { userId, status: QuizSessionStatus.in_progress },
        select: { id: true },
      }),
      readQuizUserPolicyOverride(tx, userId),
      tx.quizQuestion.findMany({
        where: {
          status: QuizQuestionStatus.active,
          type: QuizQuestionType.single_choice,
          correctOptionId: { not: null },
        },
        include: {
          options: {
            orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
          },
        },
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
      }),
    ]);

    if (!config.isEnabled) {
      throw new QuizServiceError(403, 'QUIZ_DISABLED', 'Quiz system is currently disabled');
    }
    if (permanentPass.passed && !config.allowRetakeAfterPass) {
      throw new QuizServiceError(409, 'QUIZ_ALREADY_PASSED', 'You have already passed this quiz');
    }
    const effectivePolicy = resolveEffectiveAttemptPolicy(config, policyOverride);
    const effectiveDailyAttemptLimit = effectivePolicy.dailyAttemptLimit ?? config.dailyAttemptLimit;

    if (!effectivePolicy.isUnlimited && (todayLedger?.attemptCount ?? 0) >= effectiveDailyAttemptLimit) {
      throw new QuizServiceError(409, 'QUIZ_DAILY_LIMIT_REACHED', 'Daily quiz attempt limit reached');
    }
    if (activeSessions.length > 0 && !config.allowRestartDuringSession) {
      throw new QuizServiceError(409, 'QUIZ_SESSION_IN_PROGRESS', 'A quiz session is already in progress');
    }

    const eligibleQuestions = questionRows.filter((question) => {
      const optionCount = question.options.length;
      if (optionCount < MIN_OPTION_COUNT || optionCount > MAX_OPTION_COUNT) return false;
      return question.options.some((option) => option.id === question.correctOptionId);
    });

    if (eligibleQuestions.length < config.questionCount) {
      throw new QuizServiceError(409, 'QUIZ_QUESTION_POOL_INSUFFICIENT', 'Not enough active quiz questions');
    }

    const selectedQuestions = shuffle(eligibleQuestions).slice(0, config.questionCount);
    const questionSnapshots: QuizQuestionServerSnapshot[] = selectedQuestions.map((question) => {
      const options = question.options.map((option) => ({
        optionId: option.id,
        text: option.text ?? null,
        imageUrl: option.imageUrl ?? null,
        sortOrder: option.sortOrder,
      }));
      return {
        questionId: question.id,
        stemText: question.stemText,
        stemImageUrl: question.stemImageUrl ?? null,
        options,
        timeLimitSec: normalizePositiveInt(question.timeLimitSec, config.defaultTimeLimitSec),
        correctOptionId: question.correctOptionId as string,
      };
    });

    if (activeSessions.length > 0) {
      await tx.quizSession.updateMany({
        where: {
          id: { in: activeSessions.map((item) => item.id) },
          status: QuizSessionStatus.in_progress,
        },
        data: {
          status: QuizSessionStatus.abandoned,
        },
      });
    }

    const configSnapshot: QuizConfigSnapshot = {
      questionCount: config.questionCount,
      passCorrectCount: config.passCorrectCount,
      dailyAttemptLimit: effectiveDailyAttemptLimit,
      defaultTimeLimitSec: config.defaultTimeLimitSec,
      dailyLimitTimeZone: config.dailyLimitTimeZone,
      allowRetakeAfterPass: config.allowRetakeAfterPass,
      allowRestartDuringSession: config.allowRestartDuringSession,
    };

    const expiresAt = new Date(now.getTime() + QUIZ_SESSION_TTL_MS);
    const session = await tx.quizSession.create({
      data: {
        userId,
        status: QuizSessionStatus.in_progress,
        configSnapshot: configSnapshot as unknown as Prisma.InputJsonValue,
        questionSnapshot: {
          questions: questionSnapshots,
        } as unknown as Prisma.InputJsonValue,
        currentQuestionIndex: 0,
        startedAt: now,
        expiresAt,
      },
      select: {
        id: true,
        startedAt: true,
        expiresAt: true,
      },
    });

    await tx.quizAttemptLedger.upsert({
      where: {
        userId_attemptDateKey: {
          userId,
          attemptDateKey: todayDateKey,
        },
      },
      update: {
        attemptCount: {
          increment: 1,
        },
        lastSessionId: session.id,
      },
      create: {
        userId,
        attemptDateKey: todayDateKey,
        attemptCount: 1,
        passed: permanentPass.passed,
        passedAt: permanentPass.passedAt,
        lastSessionId: session.id,
      },
    });

    return {
      sessionId: session.id,
      questionCount: config.questionCount,
      passCorrectCount: config.passCorrectCount,
      dailyAttemptLimit: effectiveDailyAttemptLimit,
      dailyRemainingAttemptsAfterStart: effectivePolicy.isUnlimited
        ? -1
        : Math.max(0, effectiveDailyAttemptLimit - ((todayLedger?.attemptCount ?? 0) + 1)),
      timeZone: config.dailyLimitTimeZone,
      questions: questionSnapshots.map(({ correctOptionId: _correctOptionId, ...question }) => question),
      startedAt: session.startedAt.toISOString(),
      expiresAt: (session.expiresAt ?? expiresAt).toISOString(),
    };
  });
};

export const submitQuizSession = async (
  userId: string,
  sessionId: string,
  answers: QuizSessionSubmitAnswer[]
): Promise<QuizSessionSubmitResult> => {
  return prisma.$transaction(async (tx) => {
    const session = await tx.quizSession.findFirst({
      where: { id: sessionId, userId },
      select: {
        id: true,
        status: true,
        questionSnapshot: true,
        configSnapshot: true,
        startedAt: true,
        expiresAt: true,
      },
    });

    if (!session) {
      throw new QuizServiceError(404, 'QUIZ_SESSION_NOT_FOUND', 'Quiz session not found');
    }
    if (session.status !== QuizSessionStatus.in_progress) {
      throw new QuizServiceError(409, 'QUIZ_SESSION_NOT_ACTIVE', 'Quiz session is not active');
    }
    if (session.expiresAt && session.expiresAt.getTime() < Date.now()) {
      await tx.quizSession.update({
        where: { id: session.id },
        data: { status: QuizSessionStatus.expired },
      });
      throw new QuizServiceError(409, 'QUIZ_SESSION_EXPIRED', 'Quiz session has expired');
    }

    const snapshotEnvelope = readQuizSnapshotEnvelope(session.questionSnapshot);
    const configSnapshot = session.configSnapshot as unknown as QuizConfigSnapshot;
    const answerMap = new Map<string, string | null>();
    answers.forEach((item) => {
      if (!item.questionId) return;
      answerMap.set(item.questionId, item.optionId ?? null);
    });

    const correctCount = snapshotEnvelope.questions.reduce((count, question) => {
      return answerMap.get(question.questionId) === question.correctOptionId ? count + 1 : count;
    }, 0);
    const passed = correctCount >= normalizePositiveInt(configSnapshot.passCorrectCount, 1);
    const submittedAt = new Date();

    await tx.quizSession.update({
      where: { id: session.id },
      data: {
        status: QuizSessionStatus.submitted,
        submittedAt,
        correctCount,
        passed,
      },
    });

    const attemptDateKey = formatDateKeyInTimeZone(
      session.startedAt,
      configSnapshot.dailyLimitTimeZone || 'Asia/Shanghai'
    );
    const existingLedger = await tx.quizAttemptLedger.findUnique({
      where: {
        userId_attemptDateKey: {
          userId,
          attemptDateKey,
        },
      },
    });

    if (existingLedger) {
      await tx.quizAttemptLedger.update({
        where: { id: existingLedger.id },
        data: {
          passed: existingLedger.passed || passed,
          passedAt: existingLedger.passedAt ?? (passed ? submittedAt : null),
          lastSessionId: session.id,
        },
      });
    } else {
      await tx.quizAttemptLedger.create({
        data: {
          userId,
          attemptDateKey,
          attemptCount: 1,
          passed,
          passedAt: passed ? submittedAt : null,
          lastSessionId: session.id,
        },
      });
    }

    const permanentPass = await readPermanentPassRecord(tx, userId);
    return {
      sessionId: session.id,
      totalCount: snapshotEnvelope.questions.length,
      correctCount,
      passCorrectCount: normalizePositiveInt(configSnapshot.passCorrectCount, 1),
      passed,
      passedAt: permanentPass.passedAt ? permanentPass.passedAt.toISOString() : null,
    };
  });
};

export const abandonQuizSession = async (userId: string, sessionId: string): Promise<{ sessionId: string; status: 'abandoned' }> => {
  const session = await prisma.quizSession.findFirst({
    where: { id: sessionId, userId },
    select: { id: true, status: true },
  });
  if (!session) {
    throw new QuizServiceError(404, 'QUIZ_SESSION_NOT_FOUND', 'Quiz session not found');
  }
  if (session.status === QuizSessionStatus.in_progress) {
    await prisma.quizSession.update({
      where: { id: session.id },
      data: { status: QuizSessionStatus.abandoned },
    });
  }
  return { sessionId: session.id, status: 'abandoned' };
};
