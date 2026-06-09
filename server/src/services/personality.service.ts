import { Prisma, QuizQuestionStatus, QuizSessionStatus } from '@prisma/client';
import { prisma } from '../lib/prisma';

const PERSONALITY_CONFIG_ID = 'default';
const PERSONALITY_DEBUG_ADMIN_ROLE = 'admin';
const PERSONALITY_STANDARD_MODE = 'standard';
const PERSONALITY_DEBUG_MODE = 'debug_set';
const AXIS_CODES = ['E', 'I', 'S', 'N', 'T', 'F', 'J', 'P'] as const;
const AXIS_PAIRS = [
  ['E', 'I'],
  ['S', 'N'],
  ['T', 'F'],
  ['J', 'P'],
] as const;

export type PersonalitySessionMode = 'standard' | 'debug_set';

export type PersonalityResultPayload = {
  code: string;
  title: string;
  subtitle: string | null;
  slangTagline: string | null;
  genreMapping: string | null;
  description: string;
  imageUrl: string | null;
  isHidden: boolean;
  mbtiCode: string | null;
};

export type PersonalityStatusSummary = {
  isEnabled: boolean;
  questionCount: number;
  axisThreshold: number;
  resultTypeCapacity: number;
  hasCompleted: boolean;
  completedAt: string | null;
  result: PersonalityResultPayload | null;
  canStart: boolean;
  activeSessionId: string | null;
  disabledReason: string | null;
  canUseDebugQuestionSet: boolean;
  debugQuestionSetCount: number;
  canStartDebugQuestionSet: boolean;
};

export type PersonalityQuestionOptionPayload = {
  optionId: string;
  text: string | null;
  imageUrl: string | null;
  sortOrder: number;
};

export type PersonalityQuestionPayload = {
  questionId: string;
  stemText: string;
  stemImageUrl: string | null;
  options: PersonalityQuestionOptionPayload[];
  isEasterEgg: boolean;
};

type PersonalityQuestionOptionServerSnapshot = PersonalityQuestionOptionPayload & {
  scorePayload: Record<string, number>;
  directResultCode: string | null;
};

type PersonalityQuestionServerSnapshot = {
  questionId: string;
  stemText: string;
  stemImageUrl: string | null;
  options: PersonalityQuestionOptionServerSnapshot[];
  isEasterEgg: boolean;
};

type PersonalityConfigSnapshot = {
  sessionMode: PersonalitySessionMode;
  questionCount: number;
  axisThreshold: number;
  hiddenResultPriority: string[];
  writesRecord: boolean;
};

type PersonalityQuestionSnapshotEnvelope = {
  questions: PersonalityQuestionServerSnapshot[];
};

export type PersonalitySessionCreateResult = {
  mode: PersonalitySessionMode;
  sessionId: string;
  questionCount: number;
  axisThreshold: number;
  questions: PersonalityQuestionPayload[];
  startedAt: string;
};

export type PersonalitySessionAnswer = {
  questionId: string;
  optionId: string | null;
};

export type PersonalitySessionSubmitResult = {
  mode: PersonalitySessionMode;
  sessionId: string;
  questionCount: number;
  answeredCount: number;
  axisScores: Record<string, number>;
  result: PersonalityResultPayload;
};

export class PersonalityServiceError extends Error {
  status: number;
  code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

const isDebugAdmin = (role: string | null | undefined): boolean =>
  String(role || '').trim().toLowerCase() === PERSONALITY_DEBUG_ADMIN_ROLE;

const normalizePositiveInt = (value: number | null | undefined, fallback: number): number => {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  const normalized = Math.floor(value);
  return normalized > 0 ? normalized : fallback;
};

const uniqueIds = (values: readonly string[]): string[] => {
  const seen = new Set<string>();
  const items: string[] = [];
  for (const value of values) {
    const normalized = String(value || '').trim();
    if (!normalized || seen.has(normalized)) continue;
    seen.add(normalized);
    items.push(normalized);
  }
  return items;
};

const shuffle = <T>(items: T[]): T[] => {
  const next = items.slice();
  for (let index = next.length - 1; index > 0; index -= 1) {
    const randomIndex = Math.floor(Math.random() * (index + 1));
    [next[index], next[randomIndex]] = [next[randomIndex], next[index]];
  }
  return next;
};

const ensurePersonalityConfig = async (
  tx: Prisma.TransactionClient | typeof prisma = prisma
) => {
  return tx.personalityConfig.upsert({
    where: { id: PERSONALITY_CONFIG_ID },
    update: {},
    create: {
      id: PERSONALITY_CONFIG_ID,
      isEnabled: false,
      questionCount: 16,
      axisThreshold: 9,
      resultTypeCapacity: 32,
      hiddenResultPriority: ['PHOENIX', 'CPDD', 'DRUNK', 'HHHH'],
    },
  });
};

const mapResultPayload = (result: {
  code: string;
  title: string;
  subtitle: string | null;
  slangTagline: string | null;
  genreMapping: string | null;
  description: string;
  imageUrl: string | null;
  isHidden: boolean;
  mbtiCode: string | null;
}): PersonalityResultPayload => ({
  code: result.code,
  title: result.title,
  subtitle: result.subtitle,
  slangTagline: result.slangTagline,
  genreMapping: result.genreMapping,
  description: result.description,
  imageUrl: result.imageUrl,
  isHidden: result.isHidden,
  mbtiCode: result.mbtiCode,
});

const toClientQuestionPayload = (
  question: PersonalityQuestionServerSnapshot
): PersonalityQuestionPayload => ({
  questionId: question.questionId,
  stemText: question.stemText,
  stemImageUrl: question.stemImageUrl,
  isEasterEgg: question.isEasterEgg,
  options: question.options.map((option) => ({
    optionId: option.optionId,
    text: option.text,
    imageUrl: option.imageUrl,
    sortOrder: option.sortOrder,
  })),
});

const readQuestionSnapshotEnvelope = (value: Prisma.JsonValue): PersonalityQuestionSnapshotEnvelope => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new PersonalityServiceError(500, 'PERSONALITY_SNAPSHOT_INVALID', 'Personality session snapshot is invalid');
  }
  const questions = Array.isArray((value as { questions?: unknown }).questions)
    ? ((value as { questions: unknown[] }).questions as PersonalityQuestionServerSnapshot[])
    : null;
  if (!questions) {
    throw new PersonalityServiceError(500, 'PERSONALITY_SNAPSHOT_INVALID', 'Personality session snapshot is invalid');
  }
  return { questions };
};

const buildQuestionSnapshot = (
  question: {
    id: string;
    stemText: string;
    stemImageUrl: string | null;
    isEasterEgg: boolean;
    options: Array<{
      id: string;
      text: string | null;
      imageUrl: string | null;
      sortOrder: number;
      scorePayload: Prisma.JsonValue | null;
      directResultCode: string | null;
    }>;
  }
): PersonalityQuestionServerSnapshot => ({
  questionId: question.id,
  stemText: question.stemText,
  stemImageUrl: question.stemImageUrl ?? null,
  isEasterEgg: Boolean(question.isEasterEgg),
  options: question.options.map((option) => ({
    optionId: option.id,
    text: option.text ?? null,
    imageUrl: option.imageUrl ?? null,
    sortOrder: option.sortOrder,
    scorePayload:
      option.scorePayload && typeof option.scorePayload === 'object' && !Array.isArray(option.scorePayload)
        ? Object.fromEntries(
            Object.entries(option.scorePayload as Record<string, unknown>)
              .filter(([key, raw]) => AXIS_CODES.includes(key as (typeof AXIS_CODES)[number]) && typeof raw === 'number')
              .map(([key, raw]) => [key, Math.max(0, Math.floor(raw as number))])
          )
        : {},
    directResultCode: option.directResultCode ?? null,
  })),
});

const isEligibleQuestion = (question: {
  options: Array<{ id: string; text: string | null; imageUrl: string | null }>;
}): boolean => question.options.length >= 2 && question.options.every((option) => Boolean(option.text || option.imageUrl));

const buildDisabledReason = (input: {
  isEnabled: boolean;
  hasCompleted: boolean;
  activeSessionId: string | null;
}): string | null => {
  if (!input.isEnabled) return 'personality_disabled';
  if (input.hasCompleted) return 'already_completed';
  if (input.activeSessionId) return 'session_in_progress';
  return null;
};

const resolveAxisScores = (answers: PersonalitySessionAnswer[], questions: PersonalityQuestionServerSnapshot[]): {
  axisScores: Record<string, number>;
  directResultCodes: string[];
  answeredCount: number;
} => {
  const answerMap = new Map<string, string | null>();
  for (const answer of answers) {
    if (!answer.questionId) continue;
    answerMap.set(answer.questionId, answer.optionId ?? null);
  }

  const axisScores: Record<string, number> = Object.fromEntries(AXIS_CODES.map((axis) => [axis, 0]));
  const directResultCodes: string[] = [];
  let answeredCount = 0;

  for (const question of questions) {
    const optionId = answerMap.get(question.questionId);
    if (!optionId) continue;
    const option = question.options.find((item) => item.optionId === optionId);
    if (!option) continue;
    answeredCount += 1;
    if (option.directResultCode) {
      directResultCodes.push(option.directResultCode);
    }
    for (const [axis, value] of Object.entries(option.scorePayload || {})) {
      axisScores[axis] = (axisScores[axis] ?? 0) + normalizePositiveInt(value, 0);
    }
  }

  return { axisScores, directResultCodes, answeredCount };
};

const axisRangeTriggerMatches = (axisScores: Record<string, number>): boolean => {
  return AXIS_PAIRS.every(([left, right]) => {
    const dominant = Math.max(axisScores[left] ?? 0, axisScores[right] ?? 0);
    return dominant >= 7 && dominant <= 9;
  });
};

const resolveRegularResultCode = (axisScores: Record<string, number>, axisThreshold: number): string => {
  const letters = AXIS_PAIRS.map(([left, right]) => ((axisScores[left] ?? 0) >= axisThreshold ? left : right));
  return letters.join('');
};

const resolveResultCode = (input: {
  axisScores: Record<string, number>;
  directResultCodes: string[];
  hiddenResultPriority: string[];
  axisThreshold: number;
}): string => {
  const directSet = new Set(input.directResultCodes.map((code) => String(code || '').trim()).filter(Boolean));
  for (const code of input.hiddenResultPriority) {
    if (directSet.has(code)) return code;
  }
  if (axisRangeTriggerMatches(input.axisScores)) {
    return 'HHHH';
  }
  return resolveRegularResultCode(input.axisScores, input.axisThreshold);
};

const getResultByCode = async (
  tx: Prisma.TransactionClient | typeof prisma,
  code: string
): Promise<PersonalityResultPayload> => {
  const row = await tx.personalityResultType.findUnique({
    where: { code },
    select: {
      code: true,
      title: true,
      subtitle: true,
      slangTagline: true,
      genreMapping: true,
      description: true,
      imageUrl: true,
      isHidden: true,
      mbtiCode: true,
      isActive: true,
    },
  });
  if (!row || !row.isActive) {
    throw new PersonalityServiceError(409, 'PERSONALITY_RESULT_TYPE_NOT_FOUND', `Personality result type ${code} is not configured`);
  }
  return mapResultPayload(row);
};

export const getPersonalityStatus = async (
  userId: string,
  options?: {
    userRole?: string | null;
  }
): Promise<PersonalityStatusSummary> => {
  const config = await ensurePersonalityConfig();
  const [record, activeSession, debugQuestionCount] = await Promise.all([
    prisma.personalityUserRecord.findUnique({
      where: { userId },
      select: { hasCompleted: true, completedAt: true, resultSnapshot: true },
    }),
    prisma.personalitySession.findFirst({
      where: { userId, status: QuizSessionStatus.in_progress },
      orderBy: { startedAt: 'desc' },
      select: { id: true },
    }),
    config.debugQuestionIds.length > 0
      ? prisma.personalityQuestion.count({
          where: {
            id: { in: config.debugQuestionIds },
            status: QuizQuestionStatus.active,
          },
        })
      : Promise.resolve(0),
  ]);

  const canUseDebugQuestionSet = isDebugAdmin(options?.userRole);
  const disabledReason = buildDisabledReason({
    isEnabled: config.isEnabled,
    hasCompleted: Boolean(record?.hasCompleted),
    activeSessionId: activeSession?.id ?? null,
  });
  return {
    isEnabled: config.isEnabled,
    questionCount: config.questionCount,
    axisThreshold: config.axisThreshold,
    resultTypeCapacity: config.resultTypeCapacity,
    hasCompleted: Boolean(record?.hasCompleted),
    completedAt: record?.completedAt ? record.completedAt.toISOString() : null,
    result:
      record?.resultSnapshot && typeof record.resultSnapshot === 'object' && !Array.isArray(record.resultSnapshot)
        ? mapResultPayload(record.resultSnapshot as PersonalityResultPayload)
        : null,
    canStart: disabledReason === null,
    activeSessionId: activeSession?.id ?? null,
    disabledReason,
    canUseDebugQuestionSet,
    debugQuestionSetCount: debugQuestionCount,
    canStartDebugQuestionSet: canUseDebugQuestionSet && debugQuestionCount > 0,
  };
};

export const getPersonalityResult = async (userId: string): Promise<PersonalityResultPayload | null> => {
  const record = await prisma.personalityUserRecord.findUnique({
    where: { userId },
    select: {
      hasCompleted: true,
      resultSnapshot: true,
    },
  });
  if (!record?.hasCompleted || !record.resultSnapshot || typeof record.resultSnapshot !== 'object' || Array.isArray(record.resultSnapshot)) {
    return null;
  }
  return mapResultPayload(record.resultSnapshot as PersonalityResultPayload);
};

export const createPersonalitySession = async (
  userId: string,
  options?: {
    mode?: PersonalitySessionMode;
    userRole?: string | null;
  }
): Promise<PersonalitySessionCreateResult> => {
  return prisma.$transaction(async (tx) => {
    const config = await ensurePersonalityConfig(tx);
    const now = new Date();
    const sessionMode: PersonalitySessionMode = options?.mode === PERSONALITY_DEBUG_MODE ? PERSONALITY_DEBUG_MODE : PERSONALITY_STANDARD_MODE;
    const isDebugSession = sessionMode === PERSONALITY_DEBUG_MODE;

    const [record, activeSessions, allQuestions, easterEggQuestion] = await Promise.all([
      tx.personalityUserRecord.findUnique({
        where: { userId },
        select: { hasCompleted: true },
      }),
      tx.personalitySession.findMany({
        where: { userId, status: QuizSessionStatus.in_progress },
        select: { id: true },
      }),
      tx.personalityQuestion.findMany({
        where: {
          status: QuizQuestionStatus.active,
          isEasterEgg: false,
          ...(isDebugSession
            ? { id: { in: config.debugQuestionIds } }
            : config.standardQuestionIds.length > 0
            ? { id: { in: config.standardQuestionIds } }
            : {}),
        },
        include: {
          options: {
            orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
          },
        },
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
      }),
      config.easterEggQuestionId
        ? tx.personalityQuestion.findFirst({
            where: {
              id: config.easterEggQuestionId,
              status: QuizQuestionStatus.active,
            },
            include: {
              options: {
                orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
              },
            },
          })
        : Promise.resolve(null),
    ]);

    if (!isDebugSession && !config.isEnabled) {
      throw new PersonalityServiceError(403, 'PERSONALITY_DISABLED', 'Personality test is currently disabled');
    }
    if (!isDebugSession && record?.hasCompleted) {
      throw new PersonalityServiceError(409, 'PERSONALITY_ALREADY_COMPLETED', 'You have already completed this personality test');
    }
    if (isDebugSession && !isDebugAdmin(options?.userRole)) {
      throw new PersonalityServiceError(403, 'PERSONALITY_DEBUG_FORBIDDEN', 'Only admin can start debug personality sessions');
    }
    if (activeSessions.length > 0) {
      throw new PersonalityServiceError(409, 'PERSONALITY_SESSION_IN_PROGRESS', 'A personality session is already in progress');
    }

    const eligibleQuestions = allQuestions.filter(isEligibleQuestion);
    const standardPool = isDebugSession ? eligibleQuestions : shuffle(eligibleQuestions);
    const selectedStandardQuestions = standardPool.slice(0, normalizePositiveInt(config.questionCount, 16));
    if (selectedStandardQuestions.length < normalizePositiveInt(config.questionCount, 16)) {
      throw new PersonalityServiceError(409, 'PERSONALITY_QUESTION_POOL_INSUFFICIENT', 'Not enough active personality questions');
    }

    const questions = [...selectedStandardQuestions];
    if (easterEggQuestion && isEligibleQuestion(easterEggQuestion) && !questions.some((item) => item.id === easterEggQuestion.id)) {
      questions.push(easterEggQuestion);
    }

    const snapshots = questions.map((question) => buildQuestionSnapshot(question));
    const configSnapshot: PersonalityConfigSnapshot = {
      sessionMode,
      questionCount: selectedStandardQuestions.length,
      axisThreshold: normalizePositiveInt(config.axisThreshold, 9),
      hiddenResultPriority: uniqueIds(config.hiddenResultPriority),
      writesRecord: !isDebugSession,
    };

    const session = await tx.personalitySession.create({
      data: {
        userId,
        mode: sessionMode,
        status: QuizSessionStatus.in_progress,
        configSnapshot: configSnapshot as unknown as Prisma.InputJsonValue,
        questionSnapshot: {
          questions: snapshots,
        } as unknown as Prisma.InputJsonValue,
        currentQuestionIndex: 0,
        startedAt: now,
      },
      select: {
        id: true,
        startedAt: true,
      },
    });

    return {
      mode: sessionMode,
      sessionId: session.id,
      questionCount: questions.length,
      axisThreshold: configSnapshot.axisThreshold,
      questions: snapshots.map(toClientQuestionPayload),
      startedAt: session.startedAt.toISOString(),
    };
  });
};

export const savePersonalitySessionAnswer = async (
  userId: string,
  sessionId: string,
  input: {
    answers: PersonalitySessionAnswer[];
    currentQuestionIndex?: number | null;
  }
): Promise<{ sessionId: string; status: 'saved' }> => {
  const session = await prisma.personalitySession.findFirst({
    where: { id: sessionId, userId },
    select: { id: true, status: true },
  });
  if (!session) {
    throw new PersonalityServiceError(404, 'PERSONALITY_SESSION_NOT_FOUND', 'Personality session not found');
  }
  if (session.status !== QuizSessionStatus.in_progress) {
    throw new PersonalityServiceError(409, 'PERSONALITY_SESSION_NOT_ACTIVE', 'Personality session is not active');
  }

  await prisma.personalitySession.update({
    where: { id: session.id },
    data: {
      answersSnapshot: input.answers as unknown as Prisma.InputJsonValue,
      currentQuestionIndex:
        typeof input.currentQuestionIndex === 'number' && Number.isFinite(input.currentQuestionIndex)
          ? Math.max(0, Math.floor(input.currentQuestionIndex))
          : undefined,
    },
  });

  return { sessionId: session.id, status: 'saved' };
};

export const submitPersonalitySession = async (
  userId: string,
  sessionId: string,
  answers: PersonalitySessionAnswer[]
): Promise<PersonalitySessionSubmitResult> => {
  return prisma.$transaction(async (tx) => {
    const session = await tx.personalitySession.findFirst({
      where: { id: sessionId, userId },
      select: {
        id: true,
        mode: true,
        status: true,
        questionSnapshot: true,
        configSnapshot: true,
      },
    });
    if (!session) {
      throw new PersonalityServiceError(404, 'PERSONALITY_SESSION_NOT_FOUND', 'Personality session not found');
    }
    if (session.status !== QuizSessionStatus.in_progress) {
      throw new PersonalityServiceError(409, 'PERSONALITY_SESSION_NOT_ACTIVE', 'Personality session is not active');
    }

    const snapshotEnvelope = readQuestionSnapshotEnvelope(session.questionSnapshot);
    const configSnapshot = session.configSnapshot as unknown as PersonalityConfigSnapshot;
    const scoringQuestions = snapshotEnvelope.questions.filter((question) => !question.isEasterEgg);
    const { axisScores, directResultCodes, answeredCount } = resolveAxisScores(answers, snapshotEnvelope.questions);
    const resultCode = resolveResultCode({
      axisScores,
      directResultCodes,
      hiddenResultPriority: uniqueIds(configSnapshot.hiddenResultPriority || ['PHOENIX', 'CPDD', 'DRUNK', 'HHHH']),
      axisThreshold: normalizePositiveInt(configSnapshot.axisThreshold, 9),
    });
    const result = await getResultByCode(tx, resultCode);
    const submittedAt = new Date();

    await tx.personalitySession.update({
      where: { id: session.id },
      data: {
        status: QuizSessionStatus.submitted,
        submittedAt,
        answersSnapshot: answers as unknown as Prisma.InputJsonValue,
        resultCode: result.code,
        resultSnapshot: result as unknown as Prisma.InputJsonValue,
      },
    });

    if (configSnapshot.writesRecord !== false) {
      await tx.personalityUserRecord.upsert({
        where: { userId },
        update: {
          hasCompleted: true,
          completedAt: submittedAt,
          resultCode: result.code,
          resultSnapshot: result as unknown as Prisma.InputJsonValue,
          lastSessionId: session.id,
        },
        create: {
          userId,
          hasCompleted: true,
          completedAt: submittedAt,
          resultCode: result.code,
          resultSnapshot: result as unknown as Prisma.InputJsonValue,
          lastSessionId: session.id,
        },
      });
    }

    return {
      mode: session.mode === PERSONALITY_DEBUG_MODE ? PERSONALITY_DEBUG_MODE : PERSONALITY_STANDARD_MODE,
      sessionId: session.id,
      questionCount: scoringQuestions.length,
      answeredCount,
      axisScores,
      result,
    };
  });
};

export const abandonPersonalitySession = async (
  userId: string,
  sessionId: string
): Promise<{ sessionId: string; status: 'abandoned' }> => {
  const session = await prisma.personalitySession.findFirst({
    where: { id: sessionId, userId },
    select: { id: true, status: true },
  });
  if (!session) {
    throw new PersonalityServiceError(404, 'PERSONALITY_SESSION_NOT_FOUND', 'Personality session not found');
  }
  if (session.status === QuizSessionStatus.in_progress) {
    await prisma.personalitySession.update({
      where: { id: session.id },
      data: { status: QuizSessionStatus.abandoned },
    });
  }
  return { sessionId: session.id, status: 'abandoned' };
};
