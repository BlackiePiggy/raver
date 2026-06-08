import {
  Prisma,
  QuizAttemptMode,
  QuizQuestionStatus,
  QuizQuestionType,
  type QuizConfig,
} from '@prisma/client';
import { prisma } from '../../lib/prisma';

const QUIZ_CONFIG_ID = 'default';
const MAX_OPTION_COUNT = 6;
const MIN_OPTION_COUNT = 2;

export type AdminQuizQuestionOptionInput = {
  id?: string;
  text?: string | null;
  imageUrl?: string | null;
  sortOrder?: number | null;
};

export type AdminQuizQuestionUpsertInput = {
  status?: QuizQuestionStatus | null;
  type?: QuizQuestionType | null;
  stemText?: string | null;
  stemImageUrl?: string | null;
  correctOptionId?: string | null;
  timeLimitSec?: number | null;
  sortOrder?: number | null;
  tags?: string[];
  difficulty?: string | null;
  explanation?: string | null;
  options?: AdminQuizQuestionOptionInput[];
};

export class AdminQuizError extends Error {
  status: number;
  code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

const normalizeText = (value: unknown, maxLength: number): string | null => {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  if (!normalized) return null;
  return normalized.slice(0, maxLength);
};

const normalizeOptionalUrl = (value: unknown): string | null => {
  const normalized = normalizeText(value, 2000);
  return normalized || null;
};

const normalizeOptionalPositiveInt = (value: unknown): number | null => {
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  const normalized = Math.floor(value);
  return normalized > 0 ? normalized : null;
};

const normalizeStringList = (value: unknown, maxItems: number): string[] => {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  for (const item of value) {
    const normalized = normalizeText(item, 64);
    if (!normalized || seen.has(normalized)) continue;
    seen.add(normalized);
    if (seen.size >= maxItems) break;
  }
  return Array.from(seen);
};

const ensureQuizConfig = async (): Promise<QuizConfig> => {
  return prisma.quizConfig.upsert({
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

const mapQuestion = (question: {
  id: string;
  status: QuizQuestionStatus;
  type: QuizQuestionType;
  stemText: string;
  stemImageUrl: string | null;
  correctOptionId: string | null;
  timeLimitSec: number | null;
  sortOrder: number;
  tags: string[];
  difficulty: string | null;
  explanation: string | null;
  createdAt: Date;
  updatedAt: Date;
  options: Array<{
    id: string;
    text: string | null;
    imageUrl: string | null;
    sortOrder: number;
    createdAt: Date;
    updatedAt: Date;
  }>;
}) => ({
  id: question.id,
  status: question.status,
  type: question.type,
  stemText: question.stemText,
  stemImageUrl: question.stemImageUrl,
  correctOptionId: question.correctOptionId,
  timeLimitSec: question.timeLimitSec,
  sortOrder: question.sortOrder,
  tags: question.tags,
  difficulty: question.difficulty,
  explanation: question.explanation,
  createdAt: question.createdAt.toISOString(),
  updatedAt: question.updatedAt.toISOString(),
  options: question.options.map((option) => ({
    id: option.id,
    text: option.text,
    imageUrl: option.imageUrl,
    sortOrder: option.sortOrder,
    createdAt: option.createdAt.toISOString(),
    updatedAt: option.updatedAt.toISOString(),
  })),
});

const validateQuestionPayload = (input: AdminQuizQuestionUpsertInput): {
  status: QuizQuestionStatus;
  type: QuizQuestionType;
  stemText: string;
  stemImageUrl: string | null;
  correctOptionId: string;
  timeLimitSec: number | null;
  sortOrder: number;
  tags: string[];
  difficulty: string | null;
  explanation: string | null;
  options: Array<{
    id?: string;
    text: string | null;
    imageUrl: string | null;
    sortOrder: number;
  }>;
} => {
  const status = input.status ?? QuizQuestionStatus.draft;
  const type = input.type ?? QuizQuestionType.single_choice;
  const stemText = normalizeText(input.stemText, 5000);
  const stemImageUrl = normalizeOptionalUrl(input.stemImageUrl);
  const correctOptionId = normalizeText(input.correctOptionId, 128);
  const timeLimitSec = normalizeOptionalPositiveInt(input.timeLimitSec);
  const sortOrder =
    typeof input.sortOrder === 'number' && Number.isFinite(input.sortOrder) ? Math.floor(input.sortOrder) : 0;
  const tags = normalizeStringList(input.tags, 20);
  const difficulty = normalizeText(input.difficulty, 64);
  const explanation = normalizeText(input.explanation, 5000);

  if (!stemText) {
    throw new AdminQuizError(400, 'QUIZ_STEM_REQUIRED', 'stemText is required');
  }
  if (type !== QuizQuestionType.single_choice) {
    throw new AdminQuizError(400, 'QUIZ_TYPE_UNSUPPORTED', 'Only single_choice is supported');
  }
  if (!Array.isArray(input.options) || input.options.length < MIN_OPTION_COUNT || input.options.length > MAX_OPTION_COUNT) {
    throw new AdminQuizError(400, 'QUIZ_OPTION_COUNT_INVALID', `options must contain ${MIN_OPTION_COUNT}-${MAX_OPTION_COUNT} items`);
  }

  const options = input.options.map((option, index) => ({
    id: normalizeText(option.id, 128) ?? undefined,
    text: normalizeText(option.text, 2000),
    imageUrl: normalizeOptionalUrl(option.imageUrl),
    sortOrder:
      typeof option.sortOrder === 'number' && Number.isFinite(option.sortOrder)
        ? Math.floor(option.sortOrder)
        : index,
  }));

  if (options.some((option) => !option.text && !option.imageUrl)) {
    throw new AdminQuizError(400, 'QUIZ_OPTION_EMPTY', 'Each option must include text, image, or both');
  }
  if (!correctOptionId) {
    throw new AdminQuizError(400, 'QUIZ_CORRECT_OPTION_REQUIRED', 'correctOptionId is required');
  }

  const optionIds = options.map((option) => option.id).filter((value): value is string => Boolean(value));
  if (!optionIds.includes(correctOptionId)) {
    throw new AdminQuizError(400, 'QUIZ_CORRECT_OPTION_INVALID', 'correctOptionId must match one option id');
  }

  return {
    status,
    type,
    stemText,
    stemImageUrl,
    correctOptionId,
    timeLimitSec,
    sortOrder,
    tags,
    difficulty,
    explanation,
    options,
  };
};

export const adminQuizService = {
  async getConfig() {
    const config = await ensureQuizConfig();
    return {
      id: config.id,
      isEnabled: config.isEnabled,
      questionCount: config.questionCount,
      passCorrectCount: config.passCorrectCount,
      dailyAttemptLimit: config.dailyAttemptLimit,
      defaultTimeLimitSec: config.defaultTimeLimitSec,
      dailyLimitTimeZone: config.dailyLimitTimeZone,
      allowRetakeAfterPass: config.allowRetakeAfterPass,
      allowRestartDuringSession: config.allowRestartDuringSession,
      createdAt: config.createdAt.toISOString(),
      updatedAt: config.updatedAt.toISOString(),
    };
  },

  async updateConfig(input: Partial<{
    isEnabled: boolean;
    questionCount: number;
    passCorrectCount: number;
    dailyAttemptLimit: number;
    defaultTimeLimitSec: number;
    dailyLimitTimeZone: string;
    allowRetakeAfterPass: boolean;
    allowRestartDuringSession: boolean;
  }>) {
    const current = await ensureQuizConfig();
    const questionCount =
      typeof input.questionCount === 'number' && Number.isFinite(input.questionCount)
        ? Math.max(1, Math.min(100, Math.floor(input.questionCount)))
        : current.questionCount;
    const passCorrectCount =
      typeof input.passCorrectCount === 'number' && Number.isFinite(input.passCorrectCount)
        ? Math.max(1, Math.min(questionCount, Math.floor(input.passCorrectCount)))
        : current.passCorrectCount;
    const dailyAttemptLimit =
      typeof input.dailyAttemptLimit === 'number' && Number.isFinite(input.dailyAttemptLimit)
        ? Math.max(1, Math.min(9999, Math.floor(input.dailyAttemptLimit)))
        : current.dailyAttemptLimit;
    const defaultTimeLimitSec =
      typeof input.defaultTimeLimitSec === 'number' && Number.isFinite(input.defaultTimeLimitSec)
        ? Math.max(1, Math.min(3600, Math.floor(input.defaultTimeLimitSec)))
        : current.defaultTimeLimitSec;
    const dailyLimitTimeZone = normalizeText(input.dailyLimitTimeZone, 100) ?? current.dailyLimitTimeZone;

    const updated = await prisma.quizConfig.update({
      where: { id: QUIZ_CONFIG_ID },
      data: {
        isEnabled: typeof input.isEnabled === 'boolean' ? input.isEnabled : current.isEnabled,
        questionCount,
        passCorrectCount,
        dailyAttemptLimit,
        defaultTimeLimitSec,
        dailyLimitTimeZone,
        allowRetakeAfterPass:
          typeof input.allowRetakeAfterPass === 'boolean' ? input.allowRetakeAfterPass : current.allowRetakeAfterPass,
        allowRestartDuringSession:
          typeof input.allowRestartDuringSession === 'boolean'
            ? input.allowRestartDuringSession
            : current.allowRestartDuringSession,
      },
    });

    return this.getConfig().then(() => ({
      id: updated.id,
      isEnabled: updated.isEnabled,
      questionCount: updated.questionCount,
      passCorrectCount: updated.passCorrectCount,
      dailyAttemptLimit: updated.dailyAttemptLimit,
      defaultTimeLimitSec: updated.defaultTimeLimitSec,
      dailyLimitTimeZone: updated.dailyLimitTimeZone,
      allowRetakeAfterPass: updated.allowRetakeAfterPass,
      allowRestartDuringSession: updated.allowRestartDuringSession,
      createdAt: updated.createdAt.toISOString(),
      updatedAt: updated.updatedAt.toISOString(),
    }));
  },

  async listQuestions(params: {
    q?: string;
    status?: string;
    page?: number;
    limit?: number;
  }) {
    const page = typeof params.page === 'number' && Number.isFinite(params.page) && params.page > 0 ? Math.floor(params.page) : 1;
    const limit =
      typeof params.limit === 'number' && Number.isFinite(params.limit) && params.limit > 0
        ? Math.min(100, Math.floor(params.limit))
        : 20;
    const skip = (page - 1) * limit;
    const q = normalizeText(params.q, 200);
    const status =
      params.status && Object.values(QuizQuestionStatus).includes(params.status as QuizQuestionStatus)
        ? (params.status as QuizQuestionStatus)
        : undefined;

    const where: Prisma.QuizQuestionWhereInput = {};
    if (q) {
      where.OR = [
        { id: q },
        { stemText: { contains: q, mode: 'insensitive' } },
        { difficulty: { contains: q, mode: 'insensitive' } },
      ];
    }
    if (status) {
      where.status = status;
    }

    const [items, total] = await prisma.$transaction([
      prisma.quizQuestion.findMany({
        where,
        include: {
          options: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
        },
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
        skip,
        take: limit,
      }),
      prisma.quizQuestion.count({ where }),
    ]);

    return {
      items: items.map(mapQuestion),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      },
    };
  },

  async getQuestion(id: string) {
    const item = await prisma.quizQuestion.findUnique({
      where: { id },
      include: {
        options: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
      },
    });
    if (!item) {
      throw new AdminQuizError(404, 'QUIZ_QUESTION_NOT_FOUND', 'Quiz question not found');
    }
    return mapQuestion(item);
  },

  async createQuestion(input: AdminQuizQuestionUpsertInput) {
    const normalized = validateQuestionPayload(input);
    const created = await prisma.$transaction(async (tx) => {
      const question = await tx.quizQuestion.create({
        data: {
          status: normalized.status,
          type: normalized.type,
          stemText: normalized.stemText,
          stemImageUrl: normalized.stemImageUrl,
          timeLimitSec: normalized.timeLimitSec,
          sortOrder: normalized.sortOrder,
          tags: normalized.tags,
          difficulty: normalized.difficulty,
          explanation: normalized.explanation,
        },
      });

      const optionIdMap = new Map<string, string>();
      for (const option of normalized.options) {
        const createdOption = await tx.quizQuestionOption.create({
          data: {
            questionId: question.id,
            text: option.text,
            imageUrl: option.imageUrl,
            sortOrder: option.sortOrder,
          },
        });
        if (option.id) optionIdMap.set(option.id, createdOption.id);
      }

      const mappedCorrectOptionId = optionIdMap.get(normalized.correctOptionId);
      if (!mappedCorrectOptionId) {
        throw new AdminQuizError(400, 'QUIZ_CORRECT_OPTION_INVALID', 'correctOptionId must match one option id');
      }

      await tx.quizQuestion.update({
        where: { id: question.id },
        data: { correctOptionId: mappedCorrectOptionId },
      });

      return tx.quizQuestion.findUniqueOrThrow({
        where: { id: question.id },
        include: {
          options: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
        },
      });
    });

    return mapQuestion(created);
  },

  async updateQuestion(id: string, input: AdminQuizQuestionUpsertInput) {
    const existing = await prisma.quizQuestion.findUnique({
      where: { id },
      include: { options: true },
    });
    if (!existing) {
      throw new AdminQuizError(404, 'QUIZ_QUESTION_NOT_FOUND', 'Quiz question not found');
    }

    const normalized = validateQuestionPayload(input);
    const updated = await prisma.$transaction(async (tx) => {
      await tx.quizQuestion.update({
        where: { id },
        data: {
          status: normalized.status,
          type: normalized.type,
          stemText: normalized.stemText,
          stemImageUrl: normalized.stemImageUrl,
          timeLimitSec: normalized.timeLimitSec,
          sortOrder: normalized.sortOrder,
          tags: normalized.tags,
          difficulty: normalized.difficulty,
          explanation: normalized.explanation,
          correctOptionId: null,
        },
      });

      await tx.quizQuestionOption.deleteMany({ where: { questionId: id } });

      const optionIdMap = new Map<string, string>();
      for (const option of normalized.options) {
        const createdOption = await tx.quizQuestionOption.create({
          data: {
            questionId: id,
            text: option.text,
            imageUrl: option.imageUrl,
            sortOrder: option.sortOrder,
          },
        });
        if (option.id) optionIdMap.set(option.id, createdOption.id);
      }

      const mappedCorrectOptionId = optionIdMap.get(normalized.correctOptionId);
      if (!mappedCorrectOptionId) {
        throw new AdminQuizError(400, 'QUIZ_CORRECT_OPTION_INVALID', 'correctOptionId must match one option id');
      }

      await tx.quizQuestion.update({
        where: { id },
        data: { correctOptionId: mappedCorrectOptionId },
      });

      return tx.quizQuestion.findUniqueOrThrow({
        where: { id },
        include: {
          options: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
        },
      });
    });

    return mapQuestion(updated);
  },

  async archiveQuestion(id: string) {
    const existing = await prisma.quizQuestion.findUnique({ where: { id } });
    if (!existing) {
      throw new AdminQuizError(404, 'QUIZ_QUESTION_NOT_FOUND', 'Quiz question not found');
    }
    const updated = await prisma.quizQuestion.update({
      where: { id },
      data: {
        status: QuizQuestionStatus.archived,
      },
      include: {
        options: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
      },
    });
    return mapQuestion(updated);
  },

  async listUserOverrides(params: { q?: string; page?: number; limit?: number }) {
    const page = typeof params.page === 'number' && Number.isFinite(params.page) && params.page > 0 ? Math.floor(params.page) : 1;
    const limit =
      typeof params.limit === 'number' && Number.isFinite(params.limit) && params.limit > 0
        ? Math.min(100, Math.floor(params.limit))
        : 20;
    const skip = (page - 1) * limit;
    const q = normalizeText(params.q, 200);

    if (q) {
      const userWhere: Prisma.UserWhereInput = {
        OR: [
          { id: q },
          { username: { contains: q, mode: 'insensitive' } },
          { displayName: { contains: q, mode: 'insensitive' } },
          { email: { contains: q, mode: 'insensitive' } },
        ],
      };

      const [users, total] = await prisma.$transaction([
        prisma.user.findMany({
          where: userWhere,
          select: {
            id: true,
            username: true,
            displayName: true,
            email: true,
          },
          orderBy: [{ createdAt: 'desc' }],
          skip,
          take: limit,
        }),
        prisma.user.count({ where: userWhere }),
      ]);

      const overrides = await prisma.quizUserPolicyOverride.findMany({
        where: { userId: { in: users.map((user) => user.id) } },
      });
      const overrideByUserId = new Map(overrides.map((item) => [item.userId, item]));

      return {
        items: users.map((user) => {
          const item = overrideByUserId.get(user.id);
          return {
            id: item?.id || `quiz_override_virtual_${user.id}`,
            userId: user.id,
            attemptMode: item?.attemptMode || QuizAttemptMode.default,
            dailyAttemptLimitOverride: item?.dailyAttemptLimitOverride || null,
            note: item?.note || null,
            updatedBy: item?.updatedBy || null,
            createdAt: (item?.createdAt || new Date(0)).toISOString(),
            updatedAt: (item?.updatedAt || new Date(0)).toISOString(),
            user: {
              id: user.id,
              username: user.username,
              displayName: user.displayName,
              email: user.email,
            },
          };
        }),
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit) || 1,
        },
      };
    }

    const [items, total] = await prisma.$transaction([
      prisma.quizUserPolicyOverride.findMany({
        include: {
          user: {
            select: {
              id: true,
              username: true,
              displayName: true,
              email: true,
            },
          },
        },
        orderBy: [{ updatedAt: 'desc' }, { createdAt: 'desc' }],
        skip,
        take: limit,
      }),
      prisma.quizUserPolicyOverride.count(),
    ]);

    return {
      items: items.map((item) => ({
        id: item.id,
        userId: item.userId,
        attemptMode: item.attemptMode,
        dailyAttemptLimitOverride: item.dailyAttemptLimitOverride,
        note: item.note,
        updatedBy: item.updatedBy,
        createdAt: item.createdAt.toISOString(),
        updatedAt: item.updatedAt.toISOString(),
        user: {
          id: item.user.id,
          username: item.user.username,
          displayName: item.user.displayName,
          email: item.user.email,
        },
      })),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      },
    };
  },

  async updateUserOverride(input: {
    userId: string;
    attemptMode: QuizAttemptMode;
    dailyAttemptLimitOverride?: number | null;
    note?: string | null;
    updatedBy?: string | null;
  }) {
    const user = await prisma.user.findUnique({
      where: { id: input.userId },
      select: { id: true, username: true, displayName: true, email: true },
    });
    if (!user) {
      throw new AdminQuizError(404, 'QUIZ_OVERRIDE_USER_NOT_FOUND', 'User not found');
    }

    let dailyAttemptLimitOverride: number | null = null;
    if (input.attemptMode === QuizAttemptMode.custom_limit) {
      dailyAttemptLimitOverride = normalizeOptionalPositiveInt(input.dailyAttemptLimitOverride);
      if (!dailyAttemptLimitOverride) {
        throw new AdminQuizError(
          400,
          'QUIZ_OVERRIDE_LIMIT_REQUIRED',
          'dailyAttemptLimitOverride is required when attemptMode is custom_limit'
        );
      }
    }

    const note = normalizeText(input.note, 2000);
    const item = await prisma.quizUserPolicyOverride.upsert({
      where: { userId: input.userId },
      update: {
        attemptMode: input.attemptMode,
        dailyAttemptLimitOverride,
        note,
        updatedBy: input.updatedBy ?? null,
      },
      create: {
        userId: input.userId,
        attemptMode: input.attemptMode,
        dailyAttemptLimitOverride,
        note,
        updatedBy: input.updatedBy ?? null,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            email: true,
          },
        },
      },
    });

    return {
      id: item.id,
      userId: item.userId,
      attemptMode: item.attemptMode,
      dailyAttemptLimitOverride: item.dailyAttemptLimitOverride,
      note: item.note,
      updatedBy: item.updatedBy,
      createdAt: item.createdAt.toISOString(),
      updatedAt: item.updatedAt.toISOString(),
      user: {
        id: item.user.id,
        username: item.user.username,
        displayName: item.user.displayName,
        email: item.user.email,
      },
    };
  },
};
