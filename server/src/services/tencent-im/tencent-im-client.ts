import axios, { AxiosInstance } from 'axios';
import { tencentIMConfig } from './tencent-im-config';
import { tencentIMUserSigService } from './tencent-im-usersig.service';

interface TencentIMApiResponse<T> {
  ActionStatus?: 'OK' | 'FAIL';
  ErrorCode?: number;
  ErrorInfo?: string;
  ErrorDisplay?: string;
  GroupId?: string;
  MemberList?: T;
}

class TencentIMClientError extends Error {
  constructor(
    message: string,
    public readonly status?: number,
    public readonly errorCode?: number
  ) {
    super(message);
    this.name = 'TencentIMClientError';
  }
}

class TencentIMClient {
  private readonly http: AxiosInstance;
  private adminUserSig: string | null = null;
  private adminUserSigExpiresAt = 0;

  constructor() {
    this.http = axios.create({
      baseURL: tencentIMConfig.apiBaseUrl,
      timeout: tencentIMConfig.requestTimeoutMs,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  async post<T>(path: string, body: Record<string, unknown>): Promise<TencentIMApiResponse<T>> {
    if (!tencentIMConfig.enabled) {
      throw new TencentIMClientError('Tencent IM is disabled');
    }

    if (!tencentIMConfig.isConfigured) {
      throw new TencentIMClientError('Tencent IM is enabled but missing SDKAppID or SecretKey');
    }

    const random = this.createRandom();
    const userSig = this.getAdminUserSig();

    try {
      const response = await this.http.post<TencentIMApiResponse<T>>(path, body, {
        params: {
          sdkappid: tencentIMConfig.sdkAppId,
          identifier: tencentIMConfig.adminIdentifier,
          usersig: userSig,
          random,
          contenttype: 'json',
        },
      });

      const payload = response.data ?? {};
      if (payload.ActionStatus === 'FAIL' || (typeof payload.ErrorCode === 'number' && payload.ErrorCode !== 0)) {
        throw new TencentIMClientError(
          payload.ErrorInfo || payload.ErrorDisplay || 'Tencent IM request failed',
          response.status,
          payload.ErrorCode
        );
      }

      return payload;
    } catch (error) {
      if (error instanceof TencentIMClientError) {
        throw error;
      }

      if (axios.isAxiosError(error)) {
        const message = typeof error.response?.data === 'object'
          ? JSON.stringify(error.response.data)
          : error.message;
        throw new TencentIMClientError(message, error.response?.status);
      }

      throw error;
    }
  }

  private getAdminUserSig(): string {
    const now = Date.now();
    if (this.adminUserSig && now < this.adminUserSigExpiresAt - 60_000) {
      return this.adminUserSig;
    }

    const expireSeconds = Math.max(3600, Math.min(tencentIMConfig.userSigExpireSeconds, 7 * 24 * 60 * 60));
    const userSig = tencentIMUserSigService.generate(tencentIMConfig.adminIdentifier, expireSeconds);
    this.adminUserSig = userSig;
    this.adminUserSigExpiresAt = now + expireSeconds * 1000;
    return userSig;
  }

  private createRandom(): number {
    return Math.floor(Math.random() * 0xffffffff);
  }
}

export const tencentIMClient = new TencentIMClient();
export { TencentIMClientError };
