import { authenticatedJsonFetch, authenticatedFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import { uploadMediaWithFetcher } from '@/lib/api/upload-media';
import {
  compressQuizImageForUpload,
  type QuizImageCompressionProfile,
  type QuizImageCompressionResult,
} from '@/lib/api/quiz-image-compression';

export type QuizAttemptMode = 'default' | 'custom_limit' | 'unlimited';
export type QuizQuestionStatus = 'draft' | 'active' | 'archived';
export type QuizQuestionType = 'single_choice';

export type AdminQuizConfig = {
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
  createdAt: string;
  updatedAt: string;
};

export type AdminQuizQuestionOption = {
  id: string;
  text: string | null;
  imageUrl: string | null;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
};

export type AdminQuizQuestion = {
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
  createdAt: string;
  updatedAt: string;
  options: AdminQuizQuestionOption[];
};

export type AdminQuizPagination = {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

export type AdminQuizUserOverride = {
  id: string;
  userId: string;
  attemptMode: QuizAttemptMode;
  dailyAttemptLimitOverride: number | null;
  note: string | null;
  updatedBy: string | null;
  createdAt: string;
  updatedAt: string;
  user: {
    id: string;
    username: string;
    displayName: string | null;
    email: string;
  };
};

export type AdminQuizQuestionInput = {
  status: QuizQuestionStatus;
  type: QuizQuestionType;
  stemText: string;
  stemImageUrl?: string | null;
  correctOptionId: string;
  timeLimitSec?: number | null;
  sortOrder?: number | null;
  tags?: string[];
  difficulty?: string | null;
  explanation?: string | null;
  options: Array<{
    id: string;
    text?: string | null;
    imageUrl?: string | null;
    sortOrder?: number | null;
  }>;
};

export type AdminQuizQuestionImportInput = {
  status?: QuizQuestionStatus;
  stemText: string;
  stemImageUrl?: string | null;
  correctOptionId?: string;
  correctOptionIndex?: number;
  timeLimitSec?: number | null;
  sortOrder?: number | null;
  tags?: string[];
  difficulty?: string | null;
  explanation?: string | null;
  options: Array<
    | string
    | {
        id?: string;
        text?: string | null;
        imageUrl?: string | null;
        sortOrder?: number | null;
        isCorrect?: boolean;
      }
  >;
};

export type AdminQuizUploadedImage = {
  url: string;
  originalUrl: string | null;
  fileName: string | null;
  mimeType: string | null;
  compression: Pick<QuizImageCompressionResult, 'originalBytes' | 'uploadedBytes' | 'compressed'>;
};

export type AdminQuizDebugSet = {
  questionIds: string[];
  items: AdminQuizQuestion[];
};

const buildQuery = (params?: Record<string, string | number | boolean | undefined>): string => {
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(params || {})) {
    if (value === undefined || value === '') continue;
    query.set(key, String(value));
  }
  const value = query.toString();
  return value ? `?${value}` : '';
};

export const adminQuizApi = {
  async getConfig(): Promise<{ success: true; config: AdminQuizConfig }> {
    return authenticatedJsonFetch<{ success: true; config: AdminQuizConfig }>('/api/admin/v1/quiz/config');
  },

  async updateConfig(input: Partial<AdminQuizConfig>): Promise<{ success: true; config: AdminQuizConfig }> {
    return authenticatedJsonFetch<{ success: true; config: AdminQuizConfig }>('/api/admin/v1/quiz/config', {
      method: 'PATCH',
      body: JSON.stringify(input),
    });
  },

  async listQuestions(params?: {
    q?: string;
    status?: QuizQuestionStatus | '';
    page?: number;
    limit?: number;
  }): Promise<{ success: true; items: AdminQuizQuestion[]; pagination: AdminQuizPagination }> {
    return authenticatedJsonFetch<{ success: true; items: AdminQuizQuestion[]; pagination: AdminQuizPagination }>(
      `/api/admin/v1/quiz/questions${buildQuery(params)}`
    );
  },

  async getDebugSet(): Promise<{ success: true; questionIds: string[]; items: AdminQuizQuestion[] }> {
    return authenticatedJsonFetch<{ success: true; questionIds: string[]; items: AdminQuizQuestion[] }>(
      '/api/admin/v1/quiz/debug-set'
    );
  },

  async updateDebugSet(questionIds: string[]): Promise<{ success: true; questionIds: string[]; items: AdminQuizQuestion[] }> {
    return authenticatedJsonFetch<{ success: true; questionIds: string[]; items: AdminQuizQuestion[] }>(
      '/api/admin/v1/quiz/debug-set',
      {
        method: 'PATCH',
        body: JSON.stringify({ questionIds }),
      }
    );
  },

  async getQuestion(id: string): Promise<{ success: true; item: AdminQuizQuestion }> {
    return authenticatedJsonFetch<{ success: true; item: AdminQuizQuestion }>(
      `/api/admin/v1/quiz/questions/${encodeURIComponent(id)}`
    );
  },

  async createQuestion(input: AdminQuizQuestionInput): Promise<{ success: true; item: AdminQuizQuestion }> {
    return authenticatedJsonFetch<{ success: true; item: AdminQuizQuestion }>('/api/admin/v1/quiz/questions', {
      method: 'POST',
      body: JSON.stringify(input),
    });
  },

  async importQuestions(input: {
    questions: AdminQuizQuestionImportInput[];
  }): Promise<{ success: true; count: number; items: AdminQuizQuestion[] }> {
    return authenticatedJsonFetch<{ success: true; count: number; items: AdminQuizQuestion[] }>(
      '/api/admin/v1/quiz/questions/import',
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
  },

  async updateQuestion(id: string, input: AdminQuizQuestionInput): Promise<{ success: true; item: AdminQuizQuestion }> {
    return authenticatedJsonFetch<{ success: true; item: AdminQuizQuestion }>(
      `/api/admin/v1/quiz/questions/${encodeURIComponent(id)}`,
      {
        method: 'PATCH',
        body: JSON.stringify(input),
      }
    );
  },

  async archiveQuestion(id: string): Promise<{ success: true; item: AdminQuizQuestion }> {
    return authenticatedJsonFetch<{ success: true; item: AdminQuizQuestion }>(
      `/api/admin/v1/quiz/questions/${encodeURIComponent(id)}/archive`,
      {
        method: 'POST',
      }
    );
  },

  async bulkDeleteQuestions(ids: string[]): Promise<{ success: true; count: number; ids: string[] }> {
    return authenticatedJsonFetch<{ success: true; count: number; ids: string[] }>(
      '/api/admin/v1/quiz/questions/bulk-delete',
      {
        method: 'POST',
        body: JSON.stringify({ ids }),
      }
    );
  },

  async listUserOverrides(params?: {
    q?: string;
    page?: number;
    limit?: number;
  }): Promise<{ success: true; items: AdminQuizUserOverride[]; pagination: AdminQuizPagination }> {
    return authenticatedJsonFetch<{ success: true; items: AdminQuizUserOverride[]; pagination: AdminQuizPagination }>(
      `/api/admin/v1/quiz/user-overrides${buildQuery(params)}`
    );
  },

  async updateUserOverride(input: {
    userId: string;
    attemptMode: QuizAttemptMode;
    dailyAttemptLimitOverride?: number | null;
    note?: string | null;
  }): Promise<{ success: true; item: AdminQuizUserOverride }> {
    return authenticatedJsonFetch<{ success: true; item: AdminQuizUserOverride }>(
      `/api/admin/v1/quiz/users/${encodeURIComponent(input.userId)}/override`,
      {
        method: 'PATCH',
        body: JSON.stringify({
          attemptMode: input.attemptMode,
          dailyAttemptLimitOverride: input.dailyAttemptLimitOverride ?? null,
          note: input.note ?? null,
        }),
      }
    );
  },

  async uploadImage(
    file: File,
    options?: {
      profile?: QuizImageCompressionProfile;
    }
  ): Promise<AdminQuizUploadedImage> {
    const prepared = await compressQuizImageForUpload(file, options?.profile ?? 'option');
    const uploaded = await uploadMediaWithFetcher({
      url: getApiUrl('/api/admin/v1/quiz/upload-image'),
      file: prepared.file,
      fetcher: authenticatedFetch,
      fallbackError: 'Quiz 图片上传失败',
      invalidResponseError: '上传成功但未返回有效图片地址',
    });
    return {
      ...uploaded,
      compression: {
        originalBytes: prepared.originalBytes,
        uploadedBytes: prepared.uploadedBytes,
        compressed: prepared.compressed,
      },
    };
  },
};
