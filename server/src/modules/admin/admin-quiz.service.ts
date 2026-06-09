import {
  Prisma,
  QuizAttemptMode,
  QuizQuestionStatus,
  QuizQuestionType,
  type QuizConfig,
} from '@prisma/client';
import crypto from 'crypto';
import { prisma } from '../../lib/prisma';
import { mediaAssetService } from '../../services/media-asset.service';

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

const normalizeQuizQuestionStatusValue = (value: unknown): QuizQuestionStatus | undefined => {
  if (value === QuizQuestionStatus.draft) return QuizQuestionStatus.draft;
  if (value === QuizQuestionStatus.active) return QuizQuestionStatus.active;
  if (value === QuizQuestionStatus.archived) return QuizQuestionStatus.archived;
  return undefined;
};

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
  sortOrder: number | null;
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
    typeof input.sortOrder === 'number' && Number.isFinite(input.sortOrder) ? Math.floor(input.sortOrder) : null;
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

type ValidatedQuizQuestionInput = ReturnType<typeof validateQuestionPayload>;

const collectQuizQuestionImageUrls = (question: {
  stemImageUrl?: string | null;
  options?: Array<{ imageUrl?: string | null }>;
}): string[] => {
  const urls = new Set<string>();
  const stemImageUrl = normalizeOptionalUrl(question.stemImageUrl);
  if (stemImageUrl) {
    urls.add(stemImageUrl);
  }
  for (const option of question.options || []) {
    const optionImageUrl = normalizeOptionalUrl(option.imageUrl);
    if (optionImageUrl) {
      urls.add(optionImageUrl);
    }
  }
  return Array.from(urls);
};

const markQuizImageUrlInactiveIfUnused = async (
  url: string,
  nextStatus: 'replaced' | 'deleted'
): Promise<void> => {
  const normalizedUrl = normalizeOptionalUrl(url);
  if (!normalizedUrl) return;

  const [stemRefCount, optionRefCount] = await prisma.$transaction([
    prisma.quizQuestion.count({
      where: { stemImageUrl: normalizedUrl },
    }),
    prisma.quizQuestionOption.count({
      where: { imageUrl: normalizedUrl },
    }),
  ]);

  if (stemRefCount > 0 || optionRefCount > 0) {
    return;
  }

  if (nextStatus === 'replaced') {
    await mediaAssetService.markReplacedByUrl(normalizedUrl);
    return;
  }
  await mediaAssetService.markDeletedByUrl(normalizedUrl);
};

const cleanupUnusedQuizImageUrls = async (
  urls: string[],
  nextStatus: 'replaced' | 'deleted'
): Promise<void> => {
  for (const url of Array.from(new Set(urls.map((item) => normalizeOptionalUrl(item)).filter((item): item is string => Boolean(item))))) {
    await markQuizImageUrlInactiveIfUnused(url, nextStatus);
  }
};

const createQuestionRecord = async (
  tx: Prisma.TransactionClient,
  normalized: ValidatedQuizQuestionInput
) => {
  const optionIdMap = new Map<string, string>();
  const optionRows = normalized.options.map((option) => {
    const id = crypto.randomUUID();
    if (option.id) optionIdMap.set(option.id, id);
    return {
      id,
      text: option.text,
      imageUrl: option.imageUrl,
      sortOrder: option.sortOrder,
    };
  });

  const mappedCorrectOptionId = optionIdMap.get(normalized.correctOptionId);
  if (!mappedCorrectOptionId) {
    throw new AdminQuizError(400, 'QUIZ_CORRECT_OPTION_INVALID', 'correctOptionId must match one option id');
  }

  const resolvedSortOrder =
    normalized.sortOrder ??
    (((await tx.quizQuestion.aggregate({
      _max: { sortOrder: true },
    }))._max.sortOrder ?? -1) + 1);

  return tx.quizQuestion.create({
    data: {
      status: normalized.status,
      type: normalized.type,
      stemText: normalized.stemText,
      stemImageUrl: normalized.stemImageUrl,
      correctOptionId: mappedCorrectOptionId,
      timeLimitSec: normalized.timeLimitSec,
      sortOrder: resolvedSortOrder,
      tags: normalized.tags,
      difficulty: normalized.difficulty,
      explanation: normalized.explanation,
      options: {
        create: optionRows,
      },
    },
    include: {
      options: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
    },
  });
};

const normalizeImportQuestionPayload = (value: unknown, itemIndex: number): AdminQuizQuestionUpsertInput => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new AdminQuizError(400, 'QUIZ_IMPORT_ITEM_INVALID', `Question #${itemIndex + 1} must be an object`);
  }

  const record = value as Record<string, unknown>;
  const rawOptions = Array.isArray(record.options) ? record.options : null;
  if (!rawOptions) {
    throw new AdminQuizError(400, 'QUIZ_IMPORT_OPTIONS_REQUIRED', `Question #${itemIndex + 1} must include options`);
  }

  const normalizedOptions = rawOptions.map((option, optionIndex) => {
    if (typeof option === 'string') {
      return {
        id: `import_option_${optionIndex + 1}`,
        text: option,
        imageUrl: null,
        sortOrder: optionIndex,
        isCorrect: false,
      };
    }

    if (!option || typeof option !== 'object' || Array.isArray(option)) {
      throw new AdminQuizError(
        400,
        'QUIZ_IMPORT_OPTION_INVALID',
        `Question #${itemIndex + 1} option #${optionIndex + 1} must be a string or object`
      );
    }

    const optionRecord = option as Record<string, unknown>;
    return {
      id: normalizeText(optionRecord.id, 128) ?? `import_option_${optionIndex + 1}`,
      text: typeof optionRecord.text === 'string' ? optionRecord.text : null,
      imageUrl: optionRecord.imageUrl,
      sortOrder:
        typeof optionRecord.sortOrder === 'number' && Number.isFinite(optionRecord.sortOrder)
          ? Math.floor(optionRecord.sortOrder)
          : optionIndex,
      isCorrect: optionRecord.isCorrect === true,
    };
  });

  const optionIds = new Set<string>();
  for (const option of normalizedOptions) {
    if (optionIds.has(option.id)) {
      throw new AdminQuizError(
        400,
        'QUIZ_IMPORT_OPTION_ID_DUPLICATED',
        `Question #${itemIndex + 1} contains duplicated option ids`
      );
    }
    optionIds.add(option.id);
  }

  const markedCorrect = normalizedOptions.filter((option) => option.isCorrect);
  if (markedCorrect.length > 1) {
    throw new AdminQuizError(
      400,
      'QUIZ_IMPORT_CORRECT_OPTION_AMBIGUOUS',
      `Question #${itemIndex + 1} has multiple options marked as correct`
    );
  }

  let correctOptionId = normalizeText(record.correctOptionId, 128);
  if (!correctOptionId && typeof record.correctOptionIndex === 'number' && Number.isFinite(record.correctOptionIndex)) {
    const correctOptionIndex = Math.floor(record.correctOptionIndex);
    if (correctOptionIndex < 0 || correctOptionIndex >= normalizedOptions.length) {
      throw new AdminQuizError(
        400,
        'QUIZ_IMPORT_CORRECT_OPTION_INDEX_INVALID',
        `Question #${itemIndex + 1} correctOptionIndex is out of range`
      );
    }
    correctOptionId = normalizedOptions[correctOptionIndex]?.id ?? null;
  }
  if (!correctOptionId && markedCorrect.length === 1) {
    correctOptionId = markedCorrect[0]?.id ?? null;
  }
  if (!correctOptionId) {
    throw new AdminQuizError(
      400,
      'QUIZ_IMPORT_CORRECT_OPTION_REQUIRED',
      `Question #${itemIndex + 1} must provide correctOptionId, correctOptionIndex, or one options[].isCorrect`
    );
  }

  return {
    status: normalizeQuizQuestionStatusValue(record.status) ?? QuizQuestionStatus.draft,
    type: QuizQuestionType.single_choice,
    stemText: typeof record.stemText === 'string' ? record.stemText : null,
    stemImageUrl: typeof record.stemImageUrl === 'string' ? record.stemImageUrl : null,
    correctOptionId,
    timeLimitSec: typeof record.timeLimitSec === 'number' ? record.timeLimitSec : null,
    sortOrder: typeof record.sortOrder === 'number' ? record.sortOrder : null,
    tags: Array.isArray(record.tags) ? (record.tags as string[]) : [],
    difficulty: typeof record.difficulty === 'string' ? record.difficulty : null,
    explanation: typeof record.explanation === 'string' ? record.explanation : null,
    options: normalizedOptions.map((option) => ({
      id: option.id,
      text: option.text,
      imageUrl: option.imageUrl as string | null,
      sortOrder: option.sortOrder,
    })),
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
      debugQuestionIds: config.debugQuestionIds,
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
      debugQuestionIds: string[];
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
        debugQuestionIds: Array.isArray(input.debugQuestionIds) ? input.debugQuestionIds : current.debugQuestionIds,
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
      debugQuestionIds: updated.debugQuestionIds,
      createdAt: updated.createdAt.toISOString(),
      updatedAt: updated.updatedAt.toISOString(),
    }));
  },

  async getDebugSet() {
    const config = await ensureQuizConfig();
    const ids = Array.from(new Set(config.debugQuestionIds.map((value) => normalizeText(value, 128)).filter((value): value is string => Boolean(value))));
    if (ids.length === 0) {
      return {
        questionIds: [] as string[],
        items: [] as ReturnType<typeof mapQuestion>[],
      };
    }

    const rows = await prisma.quizQuestion.findMany({
      where: {
        id: { in: ids },
      },
      include: {
        options: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
      },
    });
    const rowById = new Map(rows.map((row) => [row.id, row]));

    return {
      questionIds: ids,
      items: ids
        .map((id) => rowById.get(id))
        .filter((row): row is typeof rows[number] => Boolean(row))
        .map(mapQuestion),
    };
  },

  async updateDebugSet(questionIds: string[]) {
    const ids = Array.from(
      new Set(
        questionIds
          .map((value) => normalizeText(value, 128))
          .filter((value): value is string => Boolean(value))
      )
    );

    if (ids.length > 0) {
      const existingRows = await prisma.quizQuestion.findMany({
        where: { id: { in: ids } },
        select: { id: true },
      });
      if (existingRows.length !== ids.length) {
        throw new AdminQuizError(404, 'QUIZ_DEBUG_SET_QUESTION_NOT_FOUND', 'One or more debug-set questions were not found');
      }
    }

    await prisma.quizConfig.update({
      where: { id: QUIZ_CONFIG_ID },
      data: {
        debugQuestionIds: ids,
      },
    });

    return this.getDebugSet();
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
    const created = await prisma.$transaction(async (tx) => createQuestionRecord(tx, normalized), {
      maxWait: 10_000,
      timeout: 30_000,
    });

    return mapQuestion(created);
  },

  async importQuestions(values: unknown[]) {
    if (!Array.isArray(values) || values.length === 0) {
      throw new AdminQuizError(400, 'QUIZ_IMPORT_EMPTY', 'questions must contain at least one item');
    }

    const normalizedItems = values.map((value, index) => validateQuestionPayload(normalizeImportQuestionPayload(value, index)));
    const createdItems = await prisma.$transaction(async (tx) => {
      const items = [];
      for (const normalized of normalizedItems) {
        items.push(await createQuestionRecord(tx, normalized));
      }
      return items;
    }, {
      maxWait: 10_000,
      timeout: 60_000,
    });

    return {
      count: createdItems.length,
      items: createdItems.map(mapQuestion),
    };
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
    const previousImageUrls = collectQuizQuestionImageUrls(existing);
    const nextImageUrls = collectQuizQuestionImageUrls({
      stemImageUrl: normalized.stemImageUrl,
      options: normalized.options,
    });
    const updated = await prisma.$transaction(async (tx) => {
      await tx.quizQuestion.update({
        where: { id },
        data: {
          status: normalized.status,
          type: normalized.type,
          stemText: normalized.stemText,
          stemImageUrl: normalized.stemImageUrl,
          timeLimitSec: normalized.timeLimitSec,
          sortOrder: normalized.sortOrder ?? existing.sortOrder,
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

    const removedImageUrls = previousImageUrls.filter((url) => !nextImageUrls.includes(url));
    await cleanupUnusedQuizImageUrls(removedImageUrls, 'replaced');

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

  async deleteQuestions(ids: string[]) {
    const normalizedIds = Array.from(
      new Set(
        ids
          .map((value) => normalizeText(value, 128))
          .filter((value): value is string => Boolean(value))
      )
    );

    if (normalizedIds.length === 0) {
      throw new AdminQuizError(400, 'QUIZ_DELETE_IDS_REQUIRED', 'ids must contain at least one question id');
    }

    const existingItems = await prisma.quizQuestion.findMany({
      where: { id: { in: normalizedIds } },
      select: {
        id: true,
        stemImageUrl: true,
        options: {
          select: {
            imageUrl: true,
          },
        },
      },
    });

    if (existingItems.length !== normalizedIds.length) {
      throw new AdminQuizError(404, 'QUIZ_QUESTION_NOT_FOUND', 'One or more quiz questions were not found');
    }

    const removedImageUrls = existingItems.flatMap((item) => collectQuizQuestionImageUrls(item));

    await prisma.quizQuestion.deleteMany({
      where: { id: { in: normalizedIds } },
    });

    await cleanupUnusedQuizImageUrls(removedImageUrls, 'deleted');

    return {
      count: normalizedIds.length,
      ids: normalizedIds,
    };
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
