import { authenticatedFetch, authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import {
  OrganizerStudioCreateInput,
  OrganizerStudioCreateResult,
  OrganizerStudioImageUsage,
  OrganizerStudioLoadedOrganizer,
  OrganizerStudioSubmissionAcceptedPayload,
  OrganizerStudioUpdateInput,
} from './types';

type OrganizerImageUploadResponse = {
  url: string;
  originalUrl?: string | null;
  fileName?: string | null;
};

type OrganizerDeleteImagesInput =
  | {
      draftId: string;
      urls: string[];
    }
  | {
      brandId: string;
      urls: string[];
    };

const isSubmissionPayload = (
  value: unknown
): value is OrganizerStudioSubmissionAcceptedPayload => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const row = value as Record<string, unknown>;
  return typeof row.message === 'string' && !!row.submission && typeof row.submission === 'object';
};

export const organizerStudioApi = {
  async uploadImage(
    file: File,
    options: {
      usage: OrganizerStudioImageUsage;
      draftId: string;
      sort?: number;
    }
  ): Promise<OrganizerImageUploadResponse> {
    const formData = new FormData();
    formData.append('image', file);
    formData.append('usage', options.usage);
    formData.append('draftId', options.draftId);
    if (typeof options.sort === 'number') {
      formData.append('sort', String(options.sort));
    }

    const response = await authenticatedFetch(getApiUrl('/v1/wiki/brands/upload-image'), {
      method: 'POST',
      body: formData,
      headers: {},
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error?.error || '主办方图片上传失败');
    }

    return response.json();
  },

  async createOrganizer(input: OrganizerStudioCreateInput): Promise<OrganizerStudioCreateResult> {
    const payload = await authenticatedJsonFetch<unknown>(getApiUrl('/v1/learn/festivals'), {
      method: 'POST',
      body: JSON.stringify(input),
    });

    if (isSubmissionPayload(payload)) {
      return { kind: 'submitted', payload };
    }

    const organizer = payload as {
      id: string;
      name: string;
      city?: string | null;
      country?: string | null;
      revision?: number | null;
    };
    return { kind: 'created', organizer };
  },

  async updateOrganizer(
    id: string,
    input: OrganizerStudioUpdateInput
  ): Promise<OrganizerStudioCreateResult> {
    const payload = await authenticatedJsonFetch<unknown>(
      getApiUrl(`/v1/learn/festivals/${id}`),
      {
        method: 'PATCH',
        body: JSON.stringify(input),
      }
    );

    if (isSubmissionPayload(payload)) {
      return { kind: 'submitted', payload };
    }

    const organizer = payload as {
      id: string;
      name: string;
      city?: string | null;
      country?: string | null;
      revision?: number | null;
    };
    return { kind: 'created', organizer };
  },

  async fetchOrganizer(id: string): Promise<OrganizerStudioLoadedOrganizer> {
    return authenticatedJsonFetch<OrganizerStudioLoadedOrganizer>(
      getApiUrl(`/v1/learn/festivals/${id}`)
    );
  },

  async deleteImages(input: OrganizerDeleteImagesInput): Promise<void> {
    await authenticatedJsonFetch<{ success: true }>(
      getApiUrl('/v1/wiki/brands/delete-images'),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
  },
};
