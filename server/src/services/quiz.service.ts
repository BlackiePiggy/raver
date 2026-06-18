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
const QUIZ_DEBUG_ADMIN_ROLE = 'admin';
const QUIZ_STANDARD_RESERVE_QUESTION_COUNT = 10;
const QUIZ_STANDARD_TEXT_QUESTION_COUNT = 15;
const QUIZ_STANDARD_IMAGE_QUESTION_COUNT = 5;
const QUIZ_STANDARD_QUESTION_COUNT =
  QUIZ_STANDARD_TEXT_QUESTION_COUNT + QUIZ_STANDARD_IMAGE_QUESTION_COUNT;

export type QuizSessionMode = 'standard' | 'debug_set';

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
  sessionMode: QuizSessionMode;
  questionCount: number;
  passCorrectCount: number;
  dailyAttemptLimit: number;
  defaultTimeLimitSec: number;
  dailyLimitTimeZone: string;
  allowRetakeAfterPass: boolean;
  allowRestartDuringSession: boolean;
  consumesAttempt: boolean;
  writesQualification: boolean;
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
  canUseDebugQuestionSet: boolean;
  debugQuestionSetCount: number;
  canStartDebugQuestionSet: boolean;
};

export type QuizSessionCreateResult = {
  mode: QuizSessionMode;
  sessionId: string;
  questionCount: number;
  passCorrectCount: number;
  dailyAttemptLimit: number;
  dailyRemainingAttemptsAfterStart: number;
  timeZone: string;
  questions: QuizQuestionClientPayload[];
  reserveQuestions: QuizQuestionClientPayload[];
  startedAt: string;
  expiresAt: string;
};

export type QuizSessionSubmitAnswer = {
  questionId: string;
  optionId: string | null;
};

export type QuizSessionSubmitOptions = {
  presentedQuestionIds?: string[] | null;
};

export type QuizSessionAbandonReason = 'user_abandon' | 'preflight_failed';

export type QuizSessionSubmitResult = {
  mode: QuizSessionMode;
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

const uniqueQuestionIds = (ids: readonly string[]): string[] => {
  const seen = new Set<string>();
  const result: string[] = [];
  ids.forEach((id) => {
    if (!seen.has(id)) {
      seen.add(id);
      result.push(id);
    }
  });
  return result;
};

const normalizePositiveInt = (value: number | null | undefined, fallback: number): number => {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  const normalized = Math.floor(value);
  return normalized > 0 ? normalized : fallback;
};

const isQuizDebugAdmin = (role: string | null | undefined): boolean => {
  return String(role || '').trim().toLowerCase() == QUIZ_DEBUG_ADMIN_ROLE;
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

const toClientQuestionPayload = (
  question: QuizQuestionServerSnapshot
): QuizQuestionClientPayload => {
  const { correctOptionId: _correctOptionId, ...clientPayload } = question;
  return clientPayload;
};

const isEligibleQuizQuestionRow = (question: {
  correctOptionId: string | null;
  options: Array<{ id: string }>;
}): boolean => {
  const optionCount = question.options.length;
  if (optionCount < MIN_OPTION_COUNT || optionCount > MAX_OPTION_COUNT) return false;
  return question.options.some((option) => option.id === question.correctOptionId);
};

const isImageQuizQuestionRow = (question: {
  stemImageUrl: string | null;
  options: Array<{ imageUrl: string | null }>;
}): boolean => {
  return Boolean(question.stemImageUrl) || question.options.some((option) => Boolean(option.imageUrl));
};

const selectStandardQuizQuestions = <
  T extends {
    stemImageUrl: string | null;
    options: Array<{ imageUrl: string | null }>;
  },
>(
  questions: T[]
): T[] => {
  const imageQuestions = questions.filter(isImageQuizQuestionRow);
  const textQuestions = questions.filter((question) => !isImageQuizQuestionRow(question));
  const selectedTextQuestions = shuffle(textQuestions).slice(0, QUIZ_STANDARD_TEXT_QUESTION_COUNT);
  const selectedImageQuestions = shuffle(imageQuestions).slice(0, QUIZ_STANDARD_IMAGE_QUESTION_COUNT);

  if (
    selectedTextQuestions.length < QUIZ_STANDARD_TEXT_QUESTION_COUNT ||
    selectedImageQuestions.length < QUIZ_STANDARD_IMAGE_QUESTION_COUNT
  ) {
    return [];
  }

  return shuffle([...selectedTextQuestions, ...selectedImageQuestions]);
};

const buildQuestionSnapshot = (
  question: {
    id: string;
    stemText: string;
    stemImageUrl: string | null;
    timeLimitSec: number | null;
    correctOptionId: string | null;
    options: Array<{
      id: string;
      text: string | null;
      imageUrl: string | null;
      sortOrder: number;
    }>;
  },
  defaultTimeLimitSec: number
): QuizQuestionServerSnapshot => {
  return {
    questionId: question.id,
    stemText: question.stemText,
    stemImageUrl: question.stemImageUrl ?? null,
    options: question.options.map((option) => ({
      optionId: option.id,
      text: option.text ?? null,
      imageUrl: option.imageUrl ?? null,
      sortOrder: option.sortOrder,
    })),
    timeLimitSec: normalizePositiveInt(question.timeLimitSec, defaultTimeLimitSec),
    correctOptionId: question.correctOptionId as string,
  };
};

export const getQuizStatus = async (
  userId: string,
  options?: {
    userRole?: string | null;
  }
): Promise<QuizStatusSummary> => {
  const config = await ensureQuizConfig();
  const todayDateKey = formatDateKeyInTimeZone(new Date(), config.dailyLimitTimeZone);
  const [todayLedger, permanentPass, activeSession, policyOverride, debugQuestionCount] = await Promise.all([
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
    config.debugQuestionIds.length > 0
      ? prisma.quizQuestion.count({
          where: {
            id: { in: config.debugQuestionIds },
            correctOptionId: { not: null },
          },
        })
      : Promise.resolve(0),
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
  const canUseDebugQuestionSet = isQuizDebugAdmin(options?.userRole);
  const canStartDebugQuestionSet = canUseDebugQuestionSet && debugQuestionCount > 0;

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
    canUseDebugQuestionSet,
    debugQuestionSetCount: debugQuestionCount,
    canStartDebugQuestionSet,
  };
};

export const getQuizConfigSummary = async (
  userId: string,
  options?: {
    userRole?: string | null;
  }
): Promise<QuizStatusSummary> => {
  return getQuizStatus(userId, options);
};

export const createQuizSession = async (
  userId: string,
  options?: {
    mode?: QuizSessionMode;
    userRole?: string | null;
  }
): Promise<QuizSessionCreateResult> => {
  return prisma.$transaction(async (tx) => {
    const config = await ensureQuizConfig(tx);
    const now = new Date();
    const todayDateKey = formatDateKeyInTimeZone(now, config.dailyLimitTimeZone);
    const sessionMode: QuizSessionMode = options?.mode === 'debug_set' ? 'debug_set' : 'standard';
    const isDebugSession = sessionMode === 'debug_set';

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
          ...(isDebugSession
            ? {
                id: { in: config.debugQuestionIds },
                correctOptionId: { not: null },
              }
            : {
                status: QuizQuestionStatus.active,
                type: QuizQuestionType.single_choice,
                correctOptionId: { not: null },
              }),
        },
        include: {
          options: {
            orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
          },
        },
        orderBy: isDebugSession ? undefined : [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
      }),
    ]);

    if (!isDebugSession && !config.isEnabled) {
      throw new QuizServiceError(403, 'QUIZ_DISABLED', 'Quiz system is currently disabled');
    }
    if (!isDebugSession && permanentPass.passed && !config.allowRetakeAfterPass) {
      throw new QuizServiceError(409, 'QUIZ_ALREADY_PASSED', 'You have already passed this quiz');
    }
    if (isDebugSession && !isQuizDebugAdmin(options?.userRole)) {
      throw new QuizServiceError(403, 'QUIZ_DEBUG_FORBIDDEN', 'Only admin can start debug quiz sessions');
    }
    const effectivePolicy = resolveEffectiveAttemptPolicy(config, policyOverride);
    const effectiveDailyAttemptLimit = effectivePolicy.dailyAttemptLimit ?? config.dailyAttemptLimit;

    if (
      !isDebugSession &&
      !effectivePolicy.isUnlimited &&
      (todayLedger?.attemptCount ?? 0) >= effectiveDailyAttemptLimit
    ) {
      throw new QuizServiceError(409, 'QUIZ_DAILY_LIMIT_REACHED', 'Daily quiz attempt limit reached');
    }
    if (activeSessions.length > 0 && !config.allowRestartDuringSession) {
      throw new QuizServiceError(409, 'QUIZ_SESSION_IN_PROGRESS', 'A quiz session is already in progress');
    }

    const eligibleQuestionRows = questionRows.filter(isEligibleQuizQuestionRow);
    const selectedQuestions = isDebugSession
      ? config.debugQuestionIds
          .map((id) => eligibleQuestionRows.find((question) => question.id === id) ?? null)
          .filter((question): question is (typeof eligibleQuestionRows)[number] => Boolean(question))
      : selectStandardQuizQuestions(eligibleQuestionRows);
    const reserveQuestions = !isDebugSession
      ? shuffle(eligibleQuestionRows)
          .filter((question) => !selectedQuestions.some((selected) => selected.id === question.id))
          .slice(0, QUIZ_STANDARD_RESERVE_QUESTION_COUNT)
      : [];

    if (isDebugSession) {
      if (selectedQuestions.length === 0) {
        throw new QuizServiceError(409, 'QUIZ_DEBUG_SET_EMPTY', 'Debug quiz question set is empty');
      }
    } else if (selectedQuestions.length < QUIZ_STANDARD_QUESTION_COUNT) {
      throw new QuizServiceError(409, 'QUIZ_QUESTION_POOL_INSUFFICIENT', 'Not enough active quiz questions');
    }

    const resolvedQuestionCount = isDebugSession ? selectedQuestions.length : QUIZ_STANDARD_QUESTION_COUNT;
    const resolvedPassCorrectCount = Math.max(1, Math.min(config.passCorrectCount, resolvedQuestionCount));
    const questionSnapshots: QuizQuestionServerSnapshot[] = [...selectedQuestions, ...reserveQuestions].map((question) =>
      buildQuestionSnapshot(question, config.defaultTimeLimitSec)
    );

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
      sessionMode,
      questionCount: resolvedQuestionCount,
      passCorrectCount: resolvedPassCorrectCount,
      dailyAttemptLimit: effectiveDailyAttemptLimit,
      defaultTimeLimitSec: config.defaultTimeLimitSec,
      dailyLimitTimeZone: config.dailyLimitTimeZone,
      allowRetakeAfterPass: config.allowRetakeAfterPass,
      allowRestartDuringSession: config.allowRestartDuringSession,
      consumesAttempt: !isDebugSession,
      writesQualification: !isDebugSession,
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

    if (!isDebugSession) {
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
    }

    return {
      mode: sessionMode,
      sessionId: session.id,
      questionCount: resolvedQuestionCount,
      passCorrectCount: resolvedPassCorrectCount,
      dailyAttemptLimit: effectiveDailyAttemptLimit,
      dailyRemainingAttemptsAfterStart: isDebugSession
        ? (effectivePolicy.isUnlimited ? -1 : Math.max(0, effectiveDailyAttemptLimit - (todayLedger?.attemptCount ?? 0)))
        : effectivePolicy.isUnlimited
        ? -1
        : Math.max(0, effectiveDailyAttemptLimit - ((todayLedger?.attemptCount ?? 0) + 1)),
      timeZone: config.dailyLimitTimeZone,
      questions: selectedQuestions.map((question) =>
        toClientQuestionPayload(buildQuestionSnapshot(question, config.defaultTimeLimitSec))
      ),
      reserveQuestions: reserveQuestions.map((question) =>
        toClientQuestionPayload(buildQuestionSnapshot(question, config.defaultTimeLimitSec))
      ),
      startedAt: session.startedAt.toISOString(),
      expiresAt: (session.expiresAt ?? expiresAt).toISOString(),
    };
  });
};

export const submitQuizSession = async (
  userId: string,
  sessionId: string,
  answers: QuizSessionSubmitAnswer[],
  options?: QuizSessionSubmitOptions
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
    const expectedQuestionCount = normalizePositiveInt(configSnapshot.questionCount, 1);
    const snapshotById = new Map(snapshotEnvelope.questions.map((question) => [question.questionId, question]));
    const presentedQuestionIds = Array.isArray(options?.presentedQuestionIds) && options?.presentedQuestionIds.length
      ? uniqueQuestionIds(options.presentedQuestionIds)
      : snapshotEnvelope.questions.slice(0, expectedQuestionCount).map((question) => question.questionId);

    if (presentedQuestionIds.length !== expectedQuestionCount) {
      throw new QuizServiceError(
        400,
        'QUIZ_SUBMIT_PRESENTED_QUESTION_COUNT_INVALID',
        'Presented question count does not match this session'
      );
    }

    const presentedQuestions = presentedQuestionIds.map((id) => snapshotById.get(id) ?? null);
    if (presentedQuestions.some((question) => !question)) {
      throw new QuizServiceError(
        400,
        'QUIZ_SUBMIT_PRESENTED_QUESTION_INVALID',
        'Presented question list contains unknown question ids'
      );
    }

    const answerMap = new Map<string, string | null>();
    answers.forEach((item) => {
      if (!item.questionId) return;
      answerMap.set(item.questionId, item.optionId ?? null);
    });

    const correctCount = presentedQuestions.reduce((count, question) => {
      if (!question) return count;
      return answerMap.get(question.questionId) === question.correctOptionId ? count + 1 : count;
    }, 0);
    const resolvedPassCorrectCount = Math.max(
      1,
      Math.min(normalizePositiveInt(configSnapshot.passCorrectCount, 1), presentedQuestions.length)
    );
    const passed = correctCount >= resolvedPassCorrectCount;
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

    if (configSnapshot.writesQualification !== false) {
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
    }

    const permanentPass = await readPermanentPassRecord(tx, userId);
    return {
      mode: configSnapshot.sessionMode || 'standard',
      sessionId: session.id,
      totalCount: presentedQuestions.length,
      correctCount,
      passCorrectCount: resolvedPassCorrectCount,
      passed,
      passedAt: permanentPass.passedAt ? permanentPass.passedAt.toISOString() : null,
    };
  });
};

export const abandonQuizSession = async (
  userId: string,
  sessionId: string,
  options?: { reason?: QuizSessionAbandonReason | null }
): Promise<{ sessionId: string; status: 'abandoned' }> => {
  const session = await prisma.quizSession.findFirst({
    where: { id: sessionId, userId },
    select: { id: true, status: true, startedAt: true, configSnapshot: true },
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
  if (options?.reason === 'preflight_failed') {
    const configSnapshot = session.configSnapshot as unknown as QuizConfigSnapshot;
    if (configSnapshot.consumesAttempt !== false) {
      const attemptDateKey = formatDateKeyInTimeZone(
        session.startedAt,
        configSnapshot.dailyLimitTimeZone || 'Asia/Shanghai'
      );
      const ledger = await prisma.quizAttemptLedger.findUnique({
        where: {
          userId_attemptDateKey: {
            userId,
            attemptDateKey,
          },
        },
      });
      if (ledger && ledger.lastSessionId === session.id && ledger.attemptCount > 0) {
        const nextAttemptCount = Math.max(0, ledger.attemptCount - 1);
        if (nextAttemptCount === 0 && !ledger.passed && !ledger.passedAt) {
          await prisma.quizAttemptLedger.delete({
            where: { id: ledger.id },
          });
        } else {
          await prisma.quizAttemptLedger.update({
            where: { id: ledger.id },
            data: {
              attemptCount: nextAttemptCount,
              lastSessionId: null,
            },
          });
        }
      }
    }
  }
  return { sessionId: session.id, status: 'abandoned' };
};
