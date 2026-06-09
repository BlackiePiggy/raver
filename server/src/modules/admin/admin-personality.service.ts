import { Prisma, QuizQuestionStatus } from '@prisma/client';
import { prisma } from '../../lib/prisma';

const PERSONALITY_CONFIG_ID = 'default';
const MIN_OPTION_COUNT = 2;
const MAX_OPTION_COUNT = 5;
const AXIS_CODES = ['E', 'I', 'S', 'N', 'T', 'F', 'J', 'P'] as const;

export class AdminPersonalityError extends Error {
  status: number;
  code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export type AdminPersonalityQuestionOptionInput = {
  id?: string;
  text?: string | null;
  imageUrl?: string | null;
  sortOrder?: number | null;
  scoreAxis?: string | null;
  scoreValue?: number | null;
  directResultCode?: string | null;
};

export type AdminPersonalityQuestionInput = {
  status?: QuizQuestionStatus | null;
  stemText?: string | null;
  stemImageUrl?: string | null;
  sortOrder?: number | null;
  isEasterEgg?: boolean | null;
  options?: AdminPersonalityQuestionOptionInput[];
};

export type AdminPersonalityResultTypeInput = {
  code?: string | null;
  title?: string | null;
  subtitle?: string | null;
  slangTagline?: string | null;
  genreMapping?: string | null;
  description?: string | null;
  imageUrl?: string | null;
  sortOrder?: number | null;
  isActive?: boolean | null;
  isHidden?: boolean | null;
  mbtiCode?: string | null;
};

const normalizeText = (value: unknown, maxLength: number): string | null => {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  if (!normalized) return null;
  return normalized.slice(0, maxLength);
};

const normalizeOptionalUrl = (value: unknown): string | null => normalizeText(value, 2000);

const normalizeOptionalPositiveInt = (value: unknown): number | null => {
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  const normalized = Math.floor(value);
  return normalized > 0 ? normalized : null;
};

const normalizeStatus = (value: unknown): QuizQuestionStatus => {
  if (value === QuizQuestionStatus.active) return QuizQuestionStatus.active;
  if (value === QuizQuestionStatus.archived) return QuizQuestionStatus.archived;
  return QuizQuestionStatus.draft;
};

const normalizeAxisCode = (value: unknown): string | null => {
  const normalized = normalizeText(value, 16)?.toUpperCase() ?? null;
  return normalized && AXIS_CODES.includes(normalized as (typeof AXIS_CODES)[number]) ? normalized : null;
};

const ensurePersonalityConfig = async () => {
  return prisma.personalityConfig.upsert({
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

const mapQuestion = (question: {
  id: string;
  status: QuizQuestionStatus;
  stemText: string;
  stemImageUrl: string | null;
  sortOrder: number;
  isEasterEgg: boolean;
  createdAt: Date;
  updatedAt: Date;
  options: Array<{
    id: string;
    text: string | null;
    imageUrl: string | null;
    sortOrder: number;
    scorePayload: Prisma.JsonValue | null;
    directResultCode: string | null;
    createdAt: Date;
    updatedAt: Date;
  }>;
}) => ({
  id: question.id,
  status: question.status,
  stemText: question.stemText,
  stemImageUrl: question.stemImageUrl,
  sortOrder: question.sortOrder,
  isEasterEgg: question.isEasterEgg,
  createdAt: question.createdAt.toISOString(),
  updatedAt: question.updatedAt.toISOString(),
  options: question.options.map((option) => ({
    id: option.id,
    text: option.text,
    imageUrl: option.imageUrl,
    sortOrder: option.sortOrder,
    scorePayload:
      option.scorePayload && typeof option.scorePayload === 'object' && !Array.isArray(option.scorePayload)
        ? option.scorePayload
        : {},
    directResultCode: option.directResultCode,
    createdAt: option.createdAt.toISOString(),
    updatedAt: option.updatedAt.toISOString(),
  })),
});

const mapResultType = (row: {
  id: string;
  code: string;
  title: string;
  subtitle: string | null;
  slangTagline: string | null;
  genreMapping: string | null;
  description: string;
  imageUrl: string | null;
  sortOrder: number;
  isActive: boolean;
  isHidden: boolean;
  mbtiCode: string | null;
  createdAt: Date;
  updatedAt: Date;
}) => ({
  id: row.id,
  code: row.code,
  title: row.title,
  subtitle: row.subtitle,
  slangTagline: row.slangTagline,
  genreMapping: row.genreMapping,
  description: row.description,
  imageUrl: row.imageUrl,
  sortOrder: row.sortOrder,
  isActive: row.isActive,
  isHidden: row.isHidden,
  mbtiCode: row.mbtiCode,
  createdAt: row.createdAt.toISOString(),
  updatedAt: row.updatedAt.toISOString(),
});

const validateQuestionPayload = (input: AdminPersonalityQuestionInput) => {
  const status = normalizeStatus(input.status);
  const stemText = normalizeText(input.stemText, 5000);
  const stemImageUrl = normalizeOptionalUrl(input.stemImageUrl);
  const isEasterEgg = Boolean(input.isEasterEgg);
  const sortOrder =
    typeof input.sortOrder === 'number' && Number.isFinite(input.sortOrder) ? Math.floor(input.sortOrder) : null;

  if (!stemText) {
    throw new AdminPersonalityError(400, 'PERSONALITY_STEM_REQUIRED', 'stemText is required');
  }
  if (!Array.isArray(input.options) || input.options.length < MIN_OPTION_COUNT || input.options.length > MAX_OPTION_COUNT) {
    throw new AdminPersonalityError(
      400,
      'PERSONALITY_OPTION_COUNT_INVALID',
      `options must contain ${MIN_OPTION_COUNT}-${MAX_OPTION_COUNT} items`
    );
  }

  const options = input.options.map((option, index) => {
    const axis = normalizeAxisCode(option.scoreAxis);
    const scoreValue = normalizeOptionalPositiveInt(option.scoreValue) ?? 1;
    const directResultCode = normalizeText(option.directResultCode, 64);
    if (!axis && !directResultCode) {
      throw new AdminPersonalityError(
        400,
        'PERSONALITY_OPTION_SCORE_REQUIRED',
        'Each option must define scoreAxis or directResultCode'
      );
    }
    return {
      id: normalizeText(option.id, 128) ?? undefined,
      text: normalizeText(option.text, 2000),
      imageUrl: normalizeOptionalUrl(option.imageUrl),
      sortOrder:
        typeof option.sortOrder === 'number' && Number.isFinite(option.sortOrder)
          ? Math.floor(option.sortOrder)
          : index,
      scorePayload: axis ? { [axis]: scoreValue } : {},
      directResultCode: directResultCode ?? null,
    };
  });

  if (options.some((option) => !option.text && !option.imageUrl)) {
    throw new AdminPersonalityError(400, 'PERSONALITY_OPTION_EMPTY', 'Each option must include text, image, or both');
  }

  return {
    status,
    stemText,
    stemImageUrl,
    sortOrder,
    isEasterEgg,
    options,
  };
};

const validateResultTypePayload = (input: AdminPersonalityResultTypeInput) => {
  const code = normalizeText(input.code, 64)?.toUpperCase();
  const title = normalizeText(input.title, 200);
  const description = normalizeText(input.description, 8000);
  if (!code) {
    throw new AdminPersonalityError(400, 'PERSONALITY_RESULT_CODE_REQUIRED', 'code is required');
  }
  if (!title) {
    throw new AdminPersonalityError(400, 'PERSONALITY_RESULT_TITLE_REQUIRED', 'title is required');
  }
  if (!description) {
    throw new AdminPersonalityError(400, 'PERSONALITY_RESULT_DESCRIPTION_REQUIRED', 'description is required');
  }
  return {
    code,
    title,
    subtitle: normalizeText(input.subtitle, 2000),
    slangTagline: normalizeText(input.slangTagline, 2000),
    genreMapping: normalizeText(input.genreMapping, 4000),
    description,
    imageUrl: normalizeOptionalUrl(input.imageUrl),
    sortOrder:
      typeof input.sortOrder === 'number' && Number.isFinite(input.sortOrder) ? Math.floor(input.sortOrder) : 0,
    isActive: input.isActive !== false,
    isHidden: Boolean(input.isHidden),
    mbtiCode: normalizeText(input.mbtiCode, 32)?.toUpperCase() ?? null,
  };
};

export const adminPersonalityService = {
  async getConfig() {
    const config = await ensurePersonalityConfig();
    return {
      id: config.id,
      isEnabled: config.isEnabled,
      questionCount: config.questionCount,
      axisThreshold: config.axisThreshold,
      resultTypeCapacity: config.resultTypeCapacity,
      standardQuestionIds: config.standardQuestionIds,
      debugQuestionIds: config.debugQuestionIds,
      easterEggQuestionId: config.easterEggQuestionId,
      hiddenResultPriority: config.hiddenResultPriority,
      createdAt: config.createdAt.toISOString(),
      updatedAt: config.updatedAt.toISOString(),
    };
  },

  async updateConfig(input: {
    isEnabled?: boolean;
    questionCount?: number;
    axisThreshold?: number;
    resultTypeCapacity?: number;
    standardQuestionIds?: string[];
    debugQuestionIds?: string[];
    easterEggQuestionId?: string | null;
    hiddenResultPriority?: string[];
  }) {
    await ensurePersonalityConfig();
    const updated = await prisma.personalityConfig.update({
      where: { id: PERSONALITY_CONFIG_ID },
      data: {
        isEnabled: typeof input.isEnabled === 'boolean' ? input.isEnabled : undefined,
        questionCount: normalizeOptionalPositiveInt(input.questionCount) ?? undefined,
        axisThreshold: normalizeOptionalPositiveInt(input.axisThreshold) ?? undefined,
        resultTypeCapacity: normalizeOptionalPositiveInt(input.resultTypeCapacity) ?? undefined,
        standardQuestionIds: Array.isArray(input.standardQuestionIds) ? input.standardQuestionIds.map(String) : undefined,
        debugQuestionIds: Array.isArray(input.debugQuestionIds) ? input.debugQuestionIds.map(String) : undefined,
        easterEggQuestionId:
          input.easterEggQuestionId === null
            ? null
            : typeof input.easterEggQuestionId === 'string'
            ? input.easterEggQuestionId.trim() || null
            : undefined,
        hiddenResultPriority: Array.isArray(input.hiddenResultPriority)
          ? input.hiddenResultPriority.map((value) => String(value || '').trim()).filter(Boolean)
          : undefined,
      },
    });
    return {
      id: updated.id,
      isEnabled: updated.isEnabled,
      questionCount: updated.questionCount,
      axisThreshold: updated.axisThreshold,
      resultTypeCapacity: updated.resultTypeCapacity,
      standardQuestionIds: updated.standardQuestionIds,
      debugQuestionIds: updated.debugQuestionIds,
      easterEggQuestionId: updated.easterEggQuestionId,
      hiddenResultPriority: updated.hiddenResultPriority,
      createdAt: updated.createdAt.toISOString(),
      updatedAt: updated.updatedAt.toISOString(),
    };
  },

  async listQuestions(params?: { page?: number; limit?: number; status?: QuizQuestionStatus | string }) {
    const page = Math.max(1, Math.floor(Number(params?.page) || 1));
    const limit = Math.min(200, Math.max(1, Math.floor(Number(params?.limit) || 50)));
    const status = normalizeText(params?.status, 32);
    const where: Prisma.PersonalityQuestionWhereInput = status ? { status: normalizeStatus(status) } : {};
    const [items, total] = await Promise.all([
      prisma.personalityQuestion.findMany({
        where,
        include: {
          options: {
            orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
          },
        },
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.personalityQuestion.count({ where }),
    ]);
    return {
      items: items.map(mapQuestion),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.max(1, Math.ceil(total / limit)),
      },
    };
  },

  async getQuestion(id: string) {
    const item = await prisma.personalityQuestion.findUnique({
      where: { id },
      include: {
        options: {
          orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
        },
      },
    });
    if (!item) {
      throw new AdminPersonalityError(404, 'PERSONALITY_QUESTION_NOT_FOUND', 'Personality question not found');
    }
    return mapQuestion(item);
  },

  async createQuestion(input: AdminPersonalityQuestionInput) {
    const normalized = validateQuestionPayload(input);
    const created = await prisma.$transaction(async (tx) => {
      const nextSortOrder =
        normalized.sortOrder ??
        (((await tx.personalityQuestion.aggregate({
          _max: { sortOrder: true },
        }))._max.sortOrder ?? -1) + 1);

      const question = await tx.personalityQuestion.create({
        data: {
          status: normalized.status,
          stemText: normalized.stemText,
          stemImageUrl: normalized.stemImageUrl,
          sortOrder: nextSortOrder,
          isEasterEgg: normalized.isEasterEgg,
        },
      });

      for (const option of normalized.options) {
        await tx.personalityQuestionOption.create({
          data: {
            questionId: question.id,
            text: option.text,
            imageUrl: option.imageUrl,
            sortOrder: option.sortOrder,
            scorePayload: option.scorePayload as Prisma.InputJsonValue,
            directResultCode: option.directResultCode,
          },
        });
      }

      return tx.personalityQuestion.findUniqueOrThrow({
        where: { id: question.id },
        include: {
          options: {
            orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
          },
        },
      });
    });
    return mapQuestion(created);
  },

  async updateQuestion(id: string, input: AdminPersonalityQuestionInput) {
    const existing = await prisma.personalityQuestion.findUnique({
      where: { id },
      include: { options: true },
    });
    if (!existing) {
      throw new AdminPersonalityError(404, 'PERSONALITY_QUESTION_NOT_FOUND', 'Personality question not found');
    }
    const normalized = validateQuestionPayload(input);
    const updated = await prisma.$transaction(async (tx) => {
      await tx.personalityQuestion.update({
        where: { id },
        data: {
          status: normalized.status,
          stemText: normalized.stemText,
          stemImageUrl: normalized.stemImageUrl,
          sortOrder: normalized.sortOrder ?? existing.sortOrder,
          isEasterEgg: normalized.isEasterEgg,
        },
      });
      await tx.personalityQuestionOption.deleteMany({ where: { questionId: id } });
      for (const option of normalized.options) {
        await tx.personalityQuestionOption.create({
          data: {
            questionId: id,
            text: option.text,
            imageUrl: option.imageUrl,
            sortOrder: option.sortOrder,
            scorePayload: option.scorePayload as Prisma.InputJsonValue,
            directResultCode: option.directResultCode,
          },
        });
      }
      return tx.personalityQuestion.findUniqueOrThrow({
        where: { id },
        include: {
          options: {
            orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
          },
        },
      });
    });
    return mapQuestion(updated);
  },

  async archiveQuestion(id: string) {
    const existing = await prisma.personalityQuestion.findUnique({ where: { id } });
    if (!existing) {
      throw new AdminPersonalityError(404, 'PERSONALITY_QUESTION_NOT_FOUND', 'Personality question not found');
    }
    const updated = await prisma.personalityQuestion.update({
      where: { id },
      data: { status: QuizQuestionStatus.archived },
      include: {
        options: {
          orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
        },
      },
    });
    return mapQuestion(updated);
  },

  async listResultTypes() {
    const items = await prisma.personalityResultType.findMany({
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
    });
    return items.map(mapResultType);
  },

  async getResultType(id: string) {
    const item = await prisma.personalityResultType.findUnique({ where: { id } });
    if (!item) {
      throw new AdminPersonalityError(404, 'PERSONALITY_RESULT_TYPE_NOT_FOUND', 'Personality result type not found');
    }
    return mapResultType(item);
  },

  async createResultType(input: AdminPersonalityResultTypeInput) {
    const normalized = validateResultTypePayload(input);
    const created = await prisma.personalityResultType.create({
      data: normalized,
    });
    return mapResultType(created);
  },

  async updateResultType(id: string, input: AdminPersonalityResultTypeInput) {
    const existing = await prisma.personalityResultType.findUnique({ where: { id } });
    if (!existing) {
      throw new AdminPersonalityError(404, 'PERSONALITY_RESULT_TYPE_NOT_FOUND', 'Personality result type not found');
    }
    const normalized = validateResultTypePayload({
      code: input.code ?? existing.code,
      title: input.title ?? existing.title,
      subtitle: input.subtitle ?? existing.subtitle,
      slangTagline: input.slangTagline ?? existing.slangTagline,
      genreMapping: input.genreMapping ?? existing.genreMapping,
      description: input.description ?? existing.description,
      imageUrl: input.imageUrl ?? existing.imageUrl,
      sortOrder: input.sortOrder ?? existing.sortOrder,
      isActive: input.isActive ?? existing.isActive,
      isHidden: input.isHidden ?? existing.isHidden,
      mbtiCode: input.mbtiCode ?? existing.mbtiCode,
    });
    const updated = await prisma.personalityResultType.update({
      where: { id },
      data: normalized,
    });
    return mapResultType(updated);
  },

  async getDebugSet() {
    const config = await ensurePersonalityConfig();
    const items = config.debugQuestionIds.length
      ? await prisma.personalityQuestion.findMany({
          where: { id: { in: config.debugQuestionIds } },
          include: {
            options: {
              orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
            },
          },
        })
      : [];
    const orderedItems = config.debugQuestionIds
      .map((id) => items.find((item) => item.id === id) ?? null)
      .filter((item): item is (typeof items)[number] => Boolean(item))
      .map(mapQuestion);
    return {
      questionIds: config.debugQuestionIds,
      items: orderedItems,
    };
  },

  async updateDebugSet(questionIds: string[]) {
    await ensurePersonalityConfig();
    const ids = Array.from(new Set(questionIds.map((value) => normalizeText(value, 128)).filter((value): value is string => Boolean(value))));
    if (ids.length > 0) {
      const existingRows = await prisma.personalityQuestion.findMany({
        where: {
          id: { in: ids },
        },
        select: { id: true },
      });
      if (existingRows.length !== ids.length) {
        throw new AdminPersonalityError(404, 'PERSONALITY_DEBUG_SET_QUESTION_NOT_FOUND', 'One or more debug-set questions were not found');
      }
    }
    await prisma.personalityConfig.update({
      where: { id: PERSONALITY_CONFIG_ID },
      data: {
        debugQuestionIds: ids,
      },
    });
    return this.getDebugSet();
  },
};
