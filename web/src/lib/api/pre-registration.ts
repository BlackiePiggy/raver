import { getApiUrl } from '@/lib/config';
import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';

export interface PreRegistrationPayload {
  email: string;
  salutationName: string;
  phoneCountryCode?: string;
  phoneNumber?: string;
  wechatId?: string;
  salutation: 'Miss.' | 'Mr.' | '先生' | '女士';
  expectationMessage?: string;
  source?: string;
}

export interface PreRegistrationResponse {
  message: string;
  alreadyRegistered: boolean;
  registration: {
    id: string;
    email: string;
    salutationName?: string | null;
    salutation?: string;
    fullSalutation?: string;
    status: string;
    createdAt?: string;
    updatedAt?: string;
  };
}

export interface AdminPreRegistrationItem {
  id: string;
  email: string;
  phoneCountryCode: string | null;
  phoneNumber: string | null;
  wechatId: string | null;
  salutationName: string | null;
  salutation: string;
  fullSalutation?: string;
  expectationMessage: string | null;
  status: string;
  source: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface AdminPreRegistrationListResponse {
  items: AdminPreRegistrationItem[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface PreRegistrationBatch {
  id: string;
  batchName: string;
  plannedSlots: number | null;
  note: string | null;
  status: string;
  createdBy: string | null;
  createdAt: string;
  updatedAt: string;
  stats: {
    total: number;
    selected: number;
    notSelected: number;
    waitlist: number;
  };
}

const parseError = async (response: Response): Promise<string> => {
  try {
    const data = await response.json();
    return data.error || data.message || 'Request failed';
  } catch {
    return 'Request failed';
  }
};

class PreRegistrationAPI {
  private getHeaders(token?: string): HeadersInit {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };
    if (token) {
      headers.Authorization = `Bearer ${token}`;
    }
    return headers;
  }

  async submit(data: PreRegistrationPayload): Promise<PreRegistrationResponse> {
    const response = await fetch(getApiUrl('/pre-registrations'), {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      throw new Error(await parseError(response));
    }
    return response.json();
  }

  async listAdminRegistrations(
    _token: string,
    params?: Record<string, string | number | boolean | undefined>
  ): Promise<AdminPreRegistrationListResponse> {
    const search = new URLSearchParams();
    if (params) {
      for (const [key, value] of Object.entries(params)) {
        if (value === undefined || value === null || value === '') continue;
        search.set(key, String(value));
      }
    }

    const suffix = search.toString() ? `?${search.toString()}` : '';
    return authenticatedJsonFetch<AdminPreRegistrationListResponse>(getApiUrl(`/admin/v1/pre-registrations${suffix}`));
  }

  async listAdminBatches(_token: string): Promise<{ items: PreRegistrationBatch[] }> {
    return authenticatedJsonFetch<{ items: PreRegistrationBatch[] }>(getApiUrl('/admin/v1/pre-registration-batches'));
  }

  async createAdminBatch(
    _token: string,
    data: { batchName: string; plannedSlots?: number; note?: string }
  ): Promise<PreRegistrationBatch> {
    return authenticatedJsonFetch<PreRegistrationBatch>(getApiUrl('/admin/v1/pre-registration-batches'), {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async applyAdminBatchDecision(
    _token: string,
    batchId: string,
    data: { decision: 'SELECTED' | 'NOT_SELECTED' | 'WAITLIST'; registrationIds: string[]; decisionReason?: string }
  ): Promise<{ message: string; affectedCount: number; decision: string }> {
    return authenticatedJsonFetch<{ message: string; affectedCount: number; decision: string }>(
      getApiUrl(`/admin/v1/pre-registration-batches/${batchId}/decisions`),
      {
        method: 'POST',
        body: JSON.stringify(data),
      }
    );
  }

  async enqueueNotifications(
    _token: string,
    data: {
      channel: 'EMAIL' | 'SMS' | 'WECHAT' | 'IN_APP';
      templateKey: string;
      registrationIds: string[];
      batchId?: string;
    }
  ): Promise<{ message: string; createdCount: number }> {
    return authenticatedJsonFetch<{ message: string; createdCount: number }>(
      getApiUrl('/admin/v1/pre-registration-notifications'),
      {
        method: 'POST',
        body: JSON.stringify(data),
      }
    );
  }
}

export const preRegistrationAPI = new PreRegistrationAPI();
