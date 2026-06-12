import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { adminQuizApi, type AdminQuizUploadedImage } from '@/lib/api/admin-quiz';

export type PersonalityQuestionStatus = 'draft' | 'active' | 'archived';

export type AdminPersonalityConfig = {
  id: string;
  isEnabled: boolean;
  questionCount: number;
  axisThreshold: number;
  resultTypeCapacity: number;
  standardQuestionIds: string[];
  debugQuestionIds: string[];
  easterEggQuestionId: string | null;
  hiddenResultPriority: string[];
  createdAt: string;
  updatedAt: string;
};

export type AdminPersonalityQuestionOption = {
  id: string;
  text: string | null;
  imageUrl: string | null;
  sortOrder: number;
  scorePayload: Record<string, number>;
  primaryScoreAxis?: string | null;
  primaryScoreValue?: number | null;
  secondaryScoreAxis?: string | null;
  secondaryScoreValue?: number | null;
  directResultCode: string | null;
  createdAt: string;
  updatedAt: string;
};

export type AdminPersonalityQuestion = {
  id: string;
  status: PersonalityQuestionStatus;
  stemText: string;
  stemImageUrl: string | null;
  sortOrder: number;
  isEasterEgg: boolean;
  createdAt: string;
  updatedAt: string;
  options: AdminPersonalityQuestionOption[];
};

export type AdminPersonalityResultType = {
  id: string;
  code: string;
  title: string;
  subtitle: string | null;
  slangTagline: string | null;
  genreMapping: string | null;
  genreBindings: PersonalityGenreBinding[];
  description: string;
  imageUrl: string | null;
  sortOrder: number;
  isActive: boolean;
  isHidden: boolean;
  mbtiCode: string | null;
  createdAt: string;
  updatedAt: string;
};

export type AdminPersonalityPagination = {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

export type AdminPersonalityQuestionInput = {
  status: PersonalityQuestionStatus;
  stemText: string;
  stemImageUrl?: string | null;
  sortOrder?: number | null;
  isEasterEgg?: boolean | null;
  options: Array<{
    id?: string;
    text?: string | null;
    imageUrl?: string | null;
    sortOrder?: number | null;
    primaryScoreAxis?: string | null;
    primaryScoreValue?: number | null;
    secondaryScoreAxis?: string | null;
    secondaryScoreValue?: number | null;
    directResultCode?: string | null;
  }>;
};

export type AdminPersonalityResultTypeInput = {
  code: string;
  title: string;
  subtitle?: string | null;
  slangTagline?: string | null;
  genreMapping?: string | null;
  genreBindings?: PersonalityGenreBinding[] | null;
  description: string;
  imageUrl?: string | null;
  sortOrder?: number | null;
  isActive?: boolean | null;
  isHidden?: boolean | null;
  mbtiCode?: string | null;
};

export type PersonalityGenreBinding = {
  label: string;
  displayName?: string | null;
  genreId: string | null;
  path: string | null;
};

export type AdminPersonalityDebugSet = {
  questionIds: string[];
  items: AdminPersonalityQuestion[];
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

export const adminPersonalityApi = {
  async getConfig(): Promise<{ success: true; config: AdminPersonalityConfig }> {
    return authenticatedJsonFetch<{ success: true; config: AdminPersonalityConfig }>('/api/admin/v1/personality/config');
  },

  async updateConfig(input: Partial<AdminPersonalityConfig>): Promise<{ success: true; config: AdminPersonalityConfig }> {
    return authenticatedJsonFetch<{ success: true; config: AdminPersonalityConfig }>('/api/admin/v1/personality/config', {
      method: 'PATCH',
      body: JSON.stringify(input),
    });
  },

  async listQuestions(params?: {
    status?: PersonalityQuestionStatus | '';
    page?: number;
    limit?: number;
  }): Promise<{ success: true; items: AdminPersonalityQuestion[]; pagination: AdminPersonalityPagination }> {
    return authenticatedJsonFetch<{ success: true; items: AdminPersonalityQuestion[]; pagination: AdminPersonalityPagination }>(
      `/api/admin/v1/personality/questions${buildQuery(params)}`
    );
  },

  async getQuestion(id: string): Promise<{ success: true; item: AdminPersonalityQuestion }> {
    return authenticatedJsonFetch<{ success: true; item: AdminPersonalityQuestion }>(
      `/api/admin/v1/personality/questions/${encodeURIComponent(id)}`
    );
  },

  async createQuestion(input: AdminPersonalityQuestionInput): Promise<{ success: true; item: AdminPersonalityQuestion }> {
    return authenticatedJsonFetch<{ success: true; item: AdminPersonalityQuestion }>('/api/admin/v1/personality/questions', {
      method: 'POST',
      body: JSON.stringify(input),
    });
  },

  async updateQuestion(id: string, input: AdminPersonalityQuestionInput): Promise<{ success: true; item: AdminPersonalityQuestion }> {
    return authenticatedJsonFetch<{ success: true; item: AdminPersonalityQuestion }>(
      `/api/admin/v1/personality/questions/${encodeURIComponent(id)}`,
      {
        method: 'PATCH',
        body: JSON.stringify(input),
      }
    );
  },

  async archiveQuestion(id: string): Promise<{ success: true; item: AdminPersonalityQuestion }> {
    return authenticatedJsonFetch<{ success: true; item: AdminPersonalityQuestion }>(
      `/api/admin/v1/personality/questions/${encodeURIComponent(id)}/archive`,
      {
        method: 'POST',
      }
    );
  },

  async listResultTypes(): Promise<{ success: true; items: AdminPersonalityResultType[] }> {
    return authenticatedJsonFetch<{ success: true; items: AdminPersonalityResultType[] }>('/api/admin/v1/personality/result-types');
  },

  async getResultType(id: string): Promise<{ success: true; item: AdminPersonalityResultType }> {
    return authenticatedJsonFetch<{ success: true; item: AdminPersonalityResultType }>(
      `/api/admin/v1/personality/result-types/${encodeURIComponent(id)}`
    );
  },

  async createResultType(input: AdminPersonalityResultTypeInput): Promise<{ success: true; item: AdminPersonalityResultType }> {
    return authenticatedJsonFetch<{ success: true; item: AdminPersonalityResultType }>(
      '/api/admin/v1/personality/result-types',
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
  },

  async updateResultType(id: string, input: Partial<AdminPersonalityResultTypeInput>): Promise<{ success: true; item: AdminPersonalityResultType }> {
    return authenticatedJsonFetch<{ success: true; item: AdminPersonalityResultType }>(
      `/api/admin/v1/personality/result-types/${encodeURIComponent(id)}`,
      {
        method: 'PATCH',
        body: JSON.stringify(input),
      }
    );
  },

  async getDebugSet(): Promise<{ success: true; questionIds: string[]; items: AdminPersonalityQuestion[] }> {
    return authenticatedJsonFetch<{ success: true; questionIds: string[]; items: AdminPersonalityQuestion[] }>(
      '/api/admin/v1/personality/debug-set'
    );
  },

  async updateDebugSet(questionIds: string[]): Promise<{ success: true; questionIds: string[]; items: AdminPersonalityQuestion[] }> {
    return authenticatedJsonFetch<{ success: true; questionIds: string[]; items: AdminPersonalityQuestion[] }>(
      '/api/admin/v1/personality/debug-set',
      {
        method: 'PATCH',
        body: JSON.stringify({ questionIds }),
      }
    );
  },

  async uploadImage(file: File): Promise<AdminQuizUploadedImage> {
    return adminQuizApi.uploadImage(file, { profile: 'option' });
  },
};
