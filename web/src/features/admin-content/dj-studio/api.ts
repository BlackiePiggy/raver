import { authenticatedFetch, authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import {
  DJStudioCreateInput,
  DJStudioCreateResult,
  DJStudioImageUsage,
  DJStudioLoadedDJ,
  DJStudioSubmissionAcceptedPayload,
  DJStudioUpdateInput,
} from './types';

type DJStudioImageUploadResponse = {
  url: string;
  originalUrl?: string | null;
  fileName?: string | null;
};

const isSubmissionPayload = (
  value: unknown
): value is DJStudioSubmissionAcceptedPayload => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const row = value as Record<string, unknown>;
  return typeof row.message === 'string' && !!row.submission && typeof row.submission === 'object';
};

export const djStudioApi = {
  async uploadImage(
    file: File,
    options: {
      usage: DJStudioImageUsage;
      draftId: string;
    }
  ): Promise<DJStudioImageUploadResponse> {
    const formData = new FormData();
    formData.append('image', file);
    formData.append('usage', options.usage);
    formData.append('draftId', options.draftId);

    const response = await authenticatedFetch(getApiUrl('/v1/djs/upload-image'), {
      method: 'POST',
      body: formData,
      headers: {},
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error?.error || 'DJ 图片上传失败');
    }

    return response.json();
  },

  async deleteDraftImages(input: {
    draftId: string;
    urls: string[];
  }): Promise<void> {
    await authenticatedJsonFetch<{ success: true }>(
      getApiUrl('/v1/djs/delete-images'),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
  },

  async createDJ(input: DJStudioCreateInput): Promise<DJStudioCreateResult> {
    const payload = await authenticatedJsonFetch<unknown>(getApiUrl('/v1/djs/manual/import'), {
      method: 'POST',
      body: JSON.stringify(input),
    });

    if (isSubmissionPayload(payload)) {
      return { kind: 'submitted', payload };
    }

    const row = payload as {
      action: string;
      dj: {
        id: string;
        name: string;
        slug?: string | null;
        avatarUrl?: string | null;
        country?: string | null;
      };
    };
    return {
      kind: 'created',
      dj: row.dj,
    };
  },

  async updateDJ(id: string, input: DJStudioUpdateInput): Promise<DJStudioCreateResult> {
    const payload = await authenticatedJsonFetch<unknown>(getApiUrl(`/v1/djs/${id}`), {
      method: 'PATCH',
      body: JSON.stringify(input),
    });

    if (isSubmissionPayload(payload)) {
      return { kind: 'submitted', payload };
    }

    const row = payload as {
      id: string;
      name: string;
      slug?: string | null;
      avatarUrl?: string | null;
      country?: string | null;
    };
    return {
      kind: 'created',
      dj: row,
    };
  },

  async fetchDJ(id: string): Promise<DJStudioLoadedDJ> {
    return authenticatedJsonFetch<DJStudioLoadedDJ>(getApiUrl(`/v1/djs/${id}`));
  },
};
