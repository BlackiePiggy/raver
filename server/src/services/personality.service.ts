import { Prisma, QuizQuestionStatus, QuizSessionStatus } from '@prisma/client';
import { prisma } from '../lib/prisma';

const PERSONALITY_CONFIG_ID = 'default';
const PERSONALITY_DEBUG_ADMIN_ROLE = 'admin';
const PERSONALITY_STANDARD_MODE = 'standard';
const PERSONALITY_DEBUG_MODE = 'debug_set';
const AXIS_CODES = ['E', 'I', 'S', 'N', 'T', 'F', 'J', 'P'] as const;
const PAIR_CODES = ['EI', 'SN', 'TF', 'JP'] as const;
const AXIS_TO_PAIR: Record<(typeof AXIS_CODES)[number], { pair: (typeof PAIR_CODES)[number]; deltaSign: 1 | -1 }> = {
  E: { pair: 'EI', deltaSign: 1 },
  I: { pair: 'EI', deltaSign: -1 },
  S: { pair: 'SN', deltaSign: 1 },
  N: { pair: 'SN', deltaSign: -1 },
  T: { pair: 'TF', deltaSign: 1 },
  F: { pair: 'TF', deltaSign: -1 },
  J: { pair: 'JP', deltaSign: 1 },
  P: { pair: 'JP', deltaSign: -1 },
};
const PAIR_META: Record<
  (typeof PAIR_CODES)[number],
  {
    left: (typeof AXIS_CODES)[number];
    right: (typeof AXIS_CODES)[number];
    fallback: (typeof AXIS_CODES)[number];
  }
> = {
  EI: { left: 'E', right: 'I', fallback: 'I' },
  SN: { left: 'S', right: 'N', fallback: 'N' },
  TF: { left: 'T', right: 'F', fallback: 'F' },
  JP: { left: 'J', right: 'P', fallback: 'P' },
};

type PairCode = (typeof PAIR_CODES)[number];
type AxisCode = (typeof AXIS_CODES)[number];

export type PersonalitySessionMode = 'standard' | 'debug_set';

export type PersonalityGenreBinding = {
  label: string;
  genreId: string | null;
  path: string | null;
};

export type PersonalityResultPayload = {
  code: string;
  title: string;
  subtitle: string | null;
  slangTagline: string | null;
  genreMapping: string | null;
  genreBindings: PersonalityGenreBinding[];
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
  balanceScores: Record<string, number>;
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

const normalizeSignedInt = (value: unknown): number | null => {
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  const normalized = Math.trunc(value);
  return normalized === 0 ? null : normalized;
};

const emptyPairBalances = (): Record<PairCode, number> =>
  Object.fromEntries(PAIR_CODES.map((pair) => [pair, 0])) as Record<PairCode, number>;

const emptyAxisScores = (): Record<AxisCode, number> =>
  Object.fromEntries(AXIS_CODES.map((axis) => [axis, 0])) as Record<AxisCode, number>;

const emptyPairEvidence = (): Record<
  PairCode,
  {
    leftPrimary: number;
    rightPrimary: number;
    leftSecondary: number;
    rightSecondary: number;
  }
> =>
  Object.fromEntries(
    PAIR_CODES.map((pair) => [
      pair,
      {
        leftPrimary: 0,
        rightPrimary: 0,
        leftSecondary: 0,
        rightSecondary: 0,
      },
    ])
  ) as Record<
    PairCode,
    {
      leftPrimary: number;
      rightPrimary: number;
      leftSecondary: number;
      rightSecondary: number;
    }
  >;

const clamp = (value: number, min: number, max: number): number => Math.min(max, Math.max(min, value));

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
  genreBindings?: Prisma.JsonValue | PersonalityGenreBinding[] | null;
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
  genreBindings: normalizeGenreBindings(result.genreBindings),
  description: result.description,
  imageUrl: result.imageUrl,
  isHidden: result.isHidden,
  mbtiCode: result.mbtiCode,
});

const normalizeGenreBindings = (value: unknown): PersonalityGenreBinding[] => {
  if (!Array.isArray(value)) return [];

  const result: PersonalityGenreBinding[] = [];
  const seen = new Set<string>();

  for (const raw of value) {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) continue;
    const row = raw as Record<string, unknown>;
    const label = String(row.label || '').trim();
    const genreIdRaw = typeof row.genreId === 'string' ? row.genreId.trim() : '';
    const pathRaw = typeof row.path === 'string' ? row.path.trim() : '';
    const normalizedLabel = label || (pathRaw ? pathRaw.split('/').map((item) => item.trim()).filter(Boolean).at(-1) || '' : '');
    const key = genreIdRaw ? `genre:${genreIdRaw}` : `label:${normalizedLabel.toLowerCase()}`;
    if (!normalizedLabel || seen.has(key)) continue;
    seen.add(key);
    result.push({
      label: normalizedLabel,
      genreId: genreIdRaw || null,
      path: pathRaw || null,
    });
  }

  return result;
};

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
              .map(([key, raw]) => [String(key || '').trim().toUpperCase(), normalizeSignedInt(raw)] as const)
              .filter(([key, raw]) => {
                if (raw === null) return false;
                return (
                  AXIS_CODES.includes(key as AxisCode) ||
                  PAIR_CODES.includes(key as PairCode)
                );
              })
              .map(([key, raw]) => [key, raw as number])
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
  return null;
};

const canAutoReplaceActiveSessions = (input: {
  requestedMode: PersonalitySessionMode;
  activeSessions: Array<{ mode: string | null }>;
}): boolean => {
  if (input.activeSessions.length === 0) return false;
  return input.requestedMode === PERSONALITY_STANDARD_MODE || input.requestedMode === PERSONALITY_DEBUG_MODE;
};

const resolveScoringState = (answers: PersonalitySessionAnswer[], questions: PersonalityQuestionServerSnapshot[]): {
  axisScores: Record<string, number>;
  balanceScores: Record<string, number>;
  directResultCodes: string[];
  answeredCount: number;
} => {
  const answerMap = new Map<string, string | null>();
  for (const answer of answers) {
    if (!answer.questionId) continue;
    answerMap.set(answer.questionId, answer.optionId ?? null);
  }

  const pairBalances = emptyPairBalances();
  const pairEvidence = emptyPairEvidence();
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
      const normalizedKey = String(axis || '').trim().toUpperCase();
      const normalizedValue = normalizeSignedInt(value);
      if (normalizedValue === null) continue;

      if (PAIR_CODES.includes(normalizedKey as PairCode)) {
        const pairCode = normalizedKey as PairCode;
        pairBalances[pairCode] += normalizedValue;
        if (Math.abs(normalizedValue) >= 2) {
          if (normalizedValue > 0) {
            pairEvidence[pairCode].leftPrimary += 1;
          } else {
            pairEvidence[pairCode].rightPrimary += 1;
          }
        } else {
          if (normalizedValue > 0) {
            pairEvidence[pairCode].leftSecondary += Math.abs(normalizedValue);
          } else {
            pairEvidence[pairCode].rightSecondary += Math.abs(normalizedValue);
          }
        }
        continue;
      }

      if (AXIS_CODES.includes(normalizedKey as AxisCode)) {
        const axisCode = normalizedKey as AxisCode;
        const { pair, deltaSign } = AXIS_TO_PAIR[axisCode];
        const pairDelta = normalizedValue * deltaSign;
        pairBalances[pair] += pairDelta;
        if (Math.abs(normalizedValue) >= 2) {
          if (pairDelta > 0) {
            pairEvidence[pair].leftPrimary += 1;
          } else {
            pairEvidence[pair].rightPrimary += 1;
          }
        } else {
          if (pairDelta > 0) {
            pairEvidence[pair].leftSecondary += Math.abs(pairDelta);
          } else {
            pairEvidence[pair].rightSecondary += Math.abs(pairDelta);
          }
        }
      }
    }
  }

  const axisScores = emptyAxisScores();
  for (const pair of PAIR_CODES) {
    const balance = pairBalances[pair];
    const meta = PAIR_META[pair];
    axisScores[meta.left] = clamp(8 + balance, 0, 16);
    axisScores[meta.right] = clamp(8 - balance, 0, 16);
  }

  return {
    axisScores,
    balanceScores: pairBalances,
    directResultCodes,
    answeredCount,
  };
};

const balanceRangeTriggerMatches = (balanceScores: Record<string, number>): boolean => {
  return PAIR_CODES.every((pair) => Math.abs(balanceScores[pair] ?? 0) <= 1);
};

const resolveRegularMbtiCode = (input: {
  balanceScores: Record<string, number>;
  answeredQuestions: PersonalityQuestionServerSnapshot[];
  answers: PersonalitySessionAnswer[];
}): string => {
  const answerMap = new Map<string, string | null>();
  for (const answer of input.answers) {
    if (!answer.questionId) continue;
    answerMap.set(answer.questionId, answer.optionId ?? null);
  }

  const pairEvidence = emptyPairEvidence();

  for (const question of input.answeredQuestions) {
    const optionId = answerMap.get(question.questionId);
    if (!optionId) continue;
    const option = question.options.find((item) => item.optionId === optionId);
    if (!option) continue;
    for (const [rawKey, rawValue] of Object.entries(option.scorePayload || {})) {
      const key = String(rawKey || '').trim().toUpperCase();
      const value = normalizeSignedInt(rawValue);
      if (value === null) continue;

      if (PAIR_CODES.includes(key as PairCode)) {
        const pairCode = key as PairCode;
        if (Math.abs(value) >= 2) {
          if (value > 0) pairEvidence[pairCode].leftPrimary += 1;
          else pairEvidence[pairCode].rightPrimary += 1;
        } else {
          if (value > 0) pairEvidence[pairCode].leftSecondary += Math.abs(value);
          else pairEvidence[pairCode].rightSecondary += Math.abs(value);
        }
        continue;
      }

      if (AXIS_CODES.includes(key as AxisCode)) {
        const axisCode = key as AxisCode;
        const { pair, deltaSign } = AXIS_TO_PAIR[axisCode];
        const pairDelta = value * deltaSign;
        if (Math.abs(value) >= 2) {
          if (pairDelta > 0) pairEvidence[pair].leftPrimary += 1;
          else pairEvidence[pair].rightPrimary += 1;
        } else {
          if (pairDelta > 0) pairEvidence[pair].leftSecondary += Math.abs(pairDelta);
          else pairEvidence[pair].rightSecondary += Math.abs(pairDelta);
        }
      }
    }
  }

  const letters = PAIR_CODES.map((pair) => {
    const balance = input.balanceScores[pair] ?? 0;
    const meta = PAIR_META[pair];
    if (balance > 0) return meta.left;
    if (balance < 0) return meta.right;

    const evidence = pairEvidence[pair];
    if (evidence.leftPrimary !== evidence.rightPrimary) {
      return evidence.leftPrimary > evidence.rightPrimary ? meta.left : meta.right;
    }
    if (evidence.leftSecondary !== evidence.rightSecondary) {
      return evidence.leftSecondary > evidence.rightSecondary ? meta.left : meta.right;
    }
    return meta.fallback;
  });

  return letters.join('');
};

const resolveResultCode = (input: {
  balanceScores: Record<string, number>;
  directResultCodes: string[];
  hiddenResultPriority: string[];
  answeredQuestions: PersonalityQuestionServerSnapshot[];
  answers: PersonalitySessionAnswer[];
}): string => {
  const directSet = new Set(input.directResultCodes.map((code) => String(code || '').trim()).filter(Boolean));
  for (const code of input.hiddenResultPriority) {
    if (directSet.has(code)) return code;
  }
  if (balanceRangeTriggerMatches(input.balanceScores)) {
    return 'HHHH';
  }
  return resolveRegularMbtiCode({
    balanceScores: input.balanceScores,
    answeredQuestions: input.answeredQuestions,
    answers: input.answers,
  });
};

const getResultByCode = async (
  tx: Prisma.TransactionClient | typeof prisma,
  code: string
): Promise<PersonalityResultPayload> => {
  const normalized = String(code || '').trim().toUpperCase();
  const row = await tx.personalityResultType.findFirst({
    where: {
      OR: [{ code: normalized }, { mbtiCode: normalized }],
      isActive: true,
    },
    select: {
      code: true,
      title: true,
      subtitle: true,
      slangTagline: true,
      genreMapping: true,
      genreBindings: true,
      description: true,
      imageUrl: true,
      isHidden: true,
      mbtiCode: true,
      isActive: true,
    },
  });
  if (!row || !row.isActive) {
    throw new PersonalityServiceError(409, 'PERSONALITY_RESULT_TYPE_NOT_FOUND', `Personality result type ${normalized} is not configured`);
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
        select: { id: true, mode: true },
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
      if (canAutoReplaceActiveSessions({ requestedMode: sessionMode, activeSessions })) {
        await tx.personalitySession.updateMany({
          where: {
            id: { in: activeSessions.map((session) => session.id) },
            status: QuizSessionStatus.in_progress,
          },
          data: {
            status: QuizSessionStatus.abandoned,
          },
        });
      } else {
        throw new PersonalityServiceError(409, 'PERSONALITY_SESSION_IN_PROGRESS', 'A personality session is already in progress');
      }
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
  }, {
    timeout: 60000,
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
    const { axisScores, balanceScores, directResultCodes, answeredCount } = resolveScoringState(
      answers,
      snapshotEnvelope.questions
    );
    if (answeredCount < snapshotEnvelope.questions.length) {
      throw new PersonalityServiceError(
        409,
        'PERSONALITY_SESSION_INCOMPLETE',
        'All personality questions must be answered before submit'
      );
    }
    const resultCode = resolveResultCode({
      balanceScores,
      directResultCodes,
      hiddenResultPriority: uniqueIds(configSnapshot.hiddenResultPriority || ['PHOENIX', 'CPDD', 'DRUNK', 'HHHH']),
      answeredQuestions: scoringQuestions,
      answers,
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
      balanceScores,
      result,
    };
  }, {
    timeout: 60000,
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
