import axios, { AxiosInstance } from 'axios';
import { openIMConfig } from './openim-config';
import type { OpenIMAdminTokenData, OpenIMApiResponse } from './openim-types';

class OpenIMClientError extends Error {
  constructor(
    message: string,
    public readonly status?: number,
    public readonly errCode?: number
  ) {
    super(message);
    this.name = 'OpenIMClientError';
  }
}

class OpenIMClient {
  private readonly http: AxiosInstance;
  private adminToken: string | null = null;
  private adminTokenExpiresAt = 0;

  constructor() {
    this.http = axios.create({
      baseURL: openIMConfig.apiBaseUrl,
      timeout: openIMConfig.requestTimeoutMs,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  isEnabled(): boolean {
    return openIMConfig.enabled;
  }

  async getAdminToken(): Promise<string> {
    if (!openIMConfig.enabled) {
      throw new OpenIMClientError('OpenIM is disabled');
    }

    const now = Date.now();
    if (this.adminToken && now < this.adminTokenExpiresAt - 60_000) {
      return this.adminToken;
    }

    const data = await this.rawPost<OpenIMAdminTokenData>(openIMConfig.paths.getAdminToken, {
      userID: openIMConfig.adminUserId,
      secret: openIMConfig.adminSecret,
      operationID: this.createOperationId('admin-token'),
    });

    if (!data.token) {
      throw new OpenIMClientError('OpenIM admin token response did not include token');
    }

    const expireSeconds = data.expireTimeSeconds || data.expireTime || 3600;
    this.adminToken = data.token;
    this.adminTokenExpiresAt = now + expireSeconds * 1000;
    return data.token;
  }

  async post<T>(path: string, body: Record<string, unknown>): Promise<T> {
    const token = await this.getAdminToken();
    return this.rawPost<T>(path, body, token);
  }

  createOperationId(prefix: string): string {
    return `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
  }

  private async rawPost<T>(path: string, body: Record<string, unknown>, token?: string): Promise<T> {
    try {
      const operationID = typeof body.operationID === 'string' && body.operationID.trim().length > 0
        ? body.operationID.trim()
        : this.createOperationId('openim');
      const requestBody = body.operationID ? body : { ...body, operationID };
      const response = await this.http.post<OpenIMApiResponse<T>>(path, requestBody, {
        headers: {
          operationID,
          ...(token ? { token } : {}),
        },
      });

      const payload = response.data;
      if (typeof payload.errCode === 'number' && payload.errCode !== 0) {
        throw new OpenIMClientError(payload.errMsg || 'OpenIM request failed', response.status, payload.errCode);
      }

      return (payload.data ?? (payload as T)) as T;
    } catch (error) {
      if (error instanceof OpenIMClientError) {
        throw error;
      }
      if (axios.isAxiosError(error)) {
        const message = typeof error.response?.data === 'object'
          ? JSON.stringify(error.response.data)
          : error.message;
        throw new OpenIMClientError(message, error.response?.status);
      }
      throw error;
    }
  }
}

export const openIMClient = new OpenIMClient();
export { OpenIMClientError };
