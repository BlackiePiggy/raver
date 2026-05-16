import axios from 'axios';
import crypto from 'crypto';

type SendLoginCodeInput = {
  phoneNumber: string;
  code: string;
};

interface SmsProvider {
  sendLoginCode(input: SendLoginCodeInput): Promise<void>;
}

export const getSmsProviderType = (): string => smsProviderType;

export const getSmsProviderStatus = () => {
  const missingAliyunConfig: string[] = [];
  if (!aliyunAccessKeyId) missingAliyunConfig.push('ALIYUN_SMS_ACCESS_KEY_ID');
  if (!aliyunAccessKeySecret) missingAliyunConfig.push('ALIYUN_SMS_ACCESS_KEY_SECRET');
  if (!aliyunSignName) missingAliyunConfig.push('ALIYUN_SMS_SIGN_NAME');
  if (!aliyunTemplateCodeLogin) missingAliyunConfig.push('ALIYUN_SMS_TEMPLATE_CODE_LOGIN');
  const debugReturnCodeEnabled =
    process.env.NODE_ENV !== 'production'
    && smsProviderType === 'mock'
    && ['1', 'true', 'yes', 'on'].includes(String(process.env.AUTH_SMS_DEBUG_RETURN_CODE || '').trim().toLowerCase());

  return {
    provider: smsProviderType,
    productionSafe: process.env.NODE_ENV !== 'production' || smsProviderType === 'aliyun',
    aliyunConfigured: missingAliyunConfig.length === 0,
    missingAliyunConfig,
    debugReturnCodeEnabled,
  };
};

const cleanEnv = (value: string | undefined): string | null => {
  if (!value) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const smsProviderType = (cleanEnv(process.env.AUTH_SMS_PROVIDER) || 'mock').toLowerCase();
const aliyunAccessKeyId = cleanEnv(process.env.ALIYUN_SMS_ACCESS_KEY_ID);
const aliyunAccessKeySecret = cleanEnv(process.env.ALIYUN_SMS_ACCESS_KEY_SECRET);
const aliyunSignName = cleanEnv(process.env.ALIYUN_SMS_SIGN_NAME);
const aliyunTemplateCodeLogin = cleanEnv(process.env.ALIYUN_SMS_TEMPLATE_CODE_LOGIN);
const aliyunRegionId = cleanEnv(process.env.ALIYUN_SMS_REGION_ID) || 'cn-hangzhou';

const percentEncode = (value: string): string =>
  encodeURIComponent(value)
    .replace(/\+/g, '%20')
    .replace(/\*/g, '%2A')
    .replace(/%7E/g, '~');

const timestampISO8601 = (): string =>
  new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');

const maskPhone = (phoneNumber: string): string => {
  const trimmed = phoneNumber.trim();
  if (trimmed.length <= 4) return '****';
  const prefix = trimmed.slice(0, Math.min(4, Math.max(1, trimmed.length - 4)));
  const suffix = trimmed.slice(-4);
  return `${prefix}****${suffix}`;
};

const ensureAliyunConfig = (): void => {
  const missing: string[] = [];
  if (!aliyunAccessKeyId) missing.push('ALIYUN_SMS_ACCESS_KEY_ID');
  if (!aliyunAccessKeySecret) missing.push('ALIYUN_SMS_ACCESS_KEY_SECRET');
  if (!aliyunSignName) missing.push('ALIYUN_SMS_SIGN_NAME');
  if (!aliyunTemplateCodeLogin) missing.push('ALIYUN_SMS_TEMPLATE_CODE_LOGIN');

  if (missing.length > 0) {
    throw new Error(`Aliyun SMS config missing: ${missing.join(', ')}`);
  }
};

const signAliyunRpcParams = (
  params: Record<string, string>,
  accessKeySecret: string
): Record<string, string> => {
  const sortedKeys = Object.keys(params).sort((a, b) => a.localeCompare(b));
  const canonicalized = sortedKeys
    .map((key) => `${percentEncode(key)}=${percentEncode(params[key])}`)
    .join('&');

  const stringToSign = `POST&%2F&${percentEncode(canonicalized)}`;
  const signature = crypto
    .createHmac('sha1', `${accessKeySecret}&`)
    .update(stringToSign)
    .digest('base64');

  return {
    ...params,
    Signature: signature,
  };
};

class AliyunSmsProvider implements SmsProvider {
  async sendLoginCode(input: SendLoginCodeInput): Promise<void> {
    ensureAliyunConfig();

    const baseParams: Record<string, string> = {
      AccessKeyId: aliyunAccessKeyId!,
      Action: 'SendSms',
      Format: 'JSON',
      RegionId: aliyunRegionId,
      SignatureMethod: 'HMAC-SHA1',
      SignatureNonce: crypto.randomUUID(),
      SignatureVersion: '1.0',
      Timestamp: timestampISO8601(),
      Version: '2017-05-25',
      PhoneNumbers: input.phoneNumber,
      SignName: aliyunSignName!,
      TemplateCode: aliyunTemplateCodeLogin!,
      TemplateParam: JSON.stringify({ code: input.code }),
    };

    const signedParams = signAliyunRpcParams(baseParams, aliyunAccessKeySecret!);

    const response = await axios.post('https://dysmsapi.aliyuncs.com/', null, {
      params: signedParams,
      timeout: 10_000,
    });

    const data = response.data as { Code?: string; Message?: string; BizId?: string };
    if (data?.Code !== 'OK') {
      const code = data?.Code || 'UNKNOWN';
      const message = data?.Message || 'Aliyun SMS request failed';
      throw new Error(`Aliyun SMS error: ${code} ${message}`);
    }

    console.info('[sms] aliyun send success', {
      phone: maskPhone(input.phoneNumber),
      bizId: data.BizId || null,
    });
  }
}

class MockSmsProvider implements SmsProvider {
  async sendLoginCode(input: SendLoginCodeInput): Promise<void> {
    console.info('[sms] mock send code', {
      phone: maskPhone(input.phoneNumber),
      code: input.code,
    });
  }
}

const buildProvider = (): SmsProvider => {
  if (smsProviderType === 'aliyun') {
    try {
      ensureAliyunConfig();
      return new AliyunSmsProvider();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (process.env.NODE_ENV === 'production') {
        throw new Error(`[sms] aliyun provider unavailable in production: ${message}`);
      }
      console.error(`[sms] aliyun provider unavailable, fallback to mock: ${message}`);
      return new MockSmsProvider();
    }
  }
  if (process.env.NODE_ENV === 'production') {
    throw new Error('AUTH_SMS_PROVIDER=aliyun is required in production');
  }
  return new MockSmsProvider();
};

export const smsProvider: SmsProvider = buildProvider();

export const smsService = {
  async sendLoginCode(phoneNumber: string, code: string): Promise<void> {
    await smsProvider.sendLoginCode({ phoneNumber, code });
  },
};
