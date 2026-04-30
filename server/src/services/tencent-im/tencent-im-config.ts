import type { TencentIMConfig } from './tencent-im-types';

const cleanEnv = (value: string | undefined): string => (value || '').trim();

const parseBoolean = (value: string | undefined): boolean => {
  return ['1', 'true', 'yes', 'on'].includes(cleanEnv(value).toLowerCase());
};

const parseNumber = (value: string | undefined, fallback: number): number => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const sdkAppId = parseNumber(process.env.TENCENT_IM_SDK_APP_ID, 0);
const secretKey = cleanEnv(process.env.TENCENT_IM_SECRET_KEY);
const adminIdentifier = cleanEnv(process.env.TENCENT_IM_ADMIN_IDENTIFIER) || 'administrator';

export const tencentIMConfig: TencentIMConfig = {
  enabled: parseBoolean(process.env.TENCENT_IM_ENABLED),
  isConfigured: sdkAppId > 0 && secretKey.length > 0,
  sdkAppId,
  secretKey,
  adminIdentifier,
  apiBaseUrl: cleanEnv(process.env.TENCENT_IM_API_BASE_URL) || 'https://console.tim.qq.com',
  region: cleanEnv(process.env.TENCENT_IM_REGION) || 'shanghai',
  requestTimeoutMs: parseNumber(process.env.TENCENT_IM_REQUEST_TIMEOUT_MS, 10000),
  userSigExpireSeconds: parseNumber(process.env.TENCENT_IM_USERSIG_EXPIRE_SECONDS, 7 * 24 * 60 * 60),
  callbackSecret: cleanEnv(process.env.TENCENT_IM_CALLBACK_SECRET),
};
