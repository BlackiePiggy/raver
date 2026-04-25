import { getApiUrl } from '@/lib/config';

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
    token: string,
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
    const response = await fetch(getApiUrl(`/admin/pre-registrations${suffix}`), {
      headers: this.getHeaders(token),
    });

    if (!response.ok) {
      throw new Error(await parseError(response));
    }
    return response.json();
  }

  async listAdminBatches(token: string): Promise<{ items: PreRegistrationBatch[] }> {
    const response = await fetch(getApiUrl('/admin/pre-registration-batches'), {
      headers: this.getHeaders(token),
    });
    if (!response.ok) {
      throw new Error(await parseError(response));
    }
    return response.json();
  }

  async createAdminBatch(
    token: string,
    data: { batchName: string; plannedSlots?: number; note?: string }
  ): Promise<PreRegistrationBatch> {
    const response = await fetch(getApiUrl('/admin/pre-registration-batches'), {
      method: 'POST',
      headers: this.getHeaders(token),
      body: JSON.stringify(data),
    });
    if (!response.ok) {
      throw new Error(await parseError(response));
    }
    return response.json();
  }

  async applyAdminBatchDecision(
    token: string,
    batchId: string,
    data: { decision: 'SELECTED' | 'NOT_SELECTED' | 'WAITLIST'; registrationIds: string[]; decisionReason?: string }
  ): Promise<{ message: string; affectedCount: number; decision: string }> {
    const response = await fetch(getApiUrl(`/admin/pre-registration-batches/${batchId}/decisions`), {
      method: 'POST',
      headers: this.getHeaders(token),
      body: JSON.stringify(data),
    });
    if (!response.ok) {
      throw new Error(await parseError(response));
    }
    return response.json();
  }

  async enqueueNotifications(
    token: string,
    data: {
      channel: 'EMAIL' | 'SMS' | 'WECHAT' | 'IN_APP';
      templateKey: string;
      registrationIds: string[];
      batchId?: string;
    }
  ): Promise<{ message: string; createdCount: number }> {
    const response = await fetch(getApiUrl('/admin/pre-registration-notifications'), {
      method: 'POST',
      headers: this.getHeaders(token),
      body: JSON.stringify(data),
    });
    if (!response.ok) {
      throw new Error(await parseError(response));
    }
    return response.json();
  }
}

export const preRegistrationAPI = new PreRegistrationAPI();
