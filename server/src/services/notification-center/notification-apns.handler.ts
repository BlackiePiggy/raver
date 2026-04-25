import fs from 'fs';
import http2 from 'http2';
import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';
import { notificationCenterService } from './notification-center.service';
import type { NotificationChannelHandler, NotificationEvent } from './notification-center.types';

const prisma = new PrismaClient();

const readEnv = (key: string): string => {
  return String(process.env[key] || '').trim();
};

const readBoolEnv = (key: string, fallback = false): boolean => {
  const value = readEnv(key).toLowerCase();
  if (!value) return fallback;
  if (value === '1' || value === 'true' || value === 'yes') return true;
  if (value === '0' || value === 'false' || value === 'no') return false;
  return fallback;
};

const APNS_CONFIG = {
  enabled: readBoolEnv('NOTIFICATION_APNS_ENABLED', false),
  keyId: readEnv('NOTIFICATION_APNS_KEY_ID'),
  teamId: readEnv('NOTIFICATION_APNS_TEAM_ID'),
  bundleId: readEnv('NOTIFICATION_APNS_BUNDLE_ID'),
  privateKeyPath: readEnv('NOTIFICATION_APNS_PRIVATE_KEY_PATH'),
  privateKeyInline: readEnv('NOTIFICATION_APNS_PRIVATE_KEY'),
  privateKeyBase64: readEnv('NOTIFICATION_APNS_PRIVATE_KEY_BASE64'),
  useSandbox: readBoolEnv('NOTIFICATION_APNS_USE_SANDBOX', true),
};

type APNSSendResult = {
  success: boolean;
  statusCode: number;
  reason?: string;
};

let cachedJWTToken: { token: string; expiresAt: number } | null = null;

const getPrivateKeySource = (): 'inline' | 'base64' | 'path' | 'none' => {
  if (APNS_CONFIG.privateKeyInline) return 'inline';
  if (APNS_CONFIG.privateKeyBase64) return 'base64';
  if (APNS_CONFIG.privateKeyPath) return 'path';
  return 'none';
};

const maskText = (value: string): string => {
  const trimmed = value.trim();
  if (!trimmed) return '';
  if (trimmed.length <= 6) return '*'.repeat(trimmed.length);
  return `${trimmed.slice(0, 2)}***${trimmed.slice(-2)}`;
};

const loadPrivateKey = (): string => {
  if (APNS_CONFIG.privateKeyInline) {
    return APNS_CONFIG.privateKeyInline.replace(/\\n/g, '\n');
  }
  if (APNS_CONFIG.privateKeyBase64) {
    return Buffer.from(APNS_CONFIG.privateKeyBase64, 'base64').toString('utf8');
  }
  if (APNS_CONFIG.privateKeyPath) {
    return fs.readFileSync(APNS_CONFIG.privateKeyPath, 'utf8');
  }
  return '';
};

const isConfigured = (): boolean => {
  if (!APNS_CONFIG.enabled) {
    return false;
  }
  return Boolean(
    APNS_CONFIG.keyId &&
      APNS_CONFIG.teamId &&
      APNS_CONFIG.bundleId &&
      (APNS_CONFIG.privateKeyInline || APNS_CONFIG.privateKeyBase64 || APNS_CONFIG.privateKeyPath)
  );
};

const getMissingConfigFields = (): string[] => {
  const missing: string[] = [];
  if (!APNS_CONFIG.keyId) missing.push('NOTIFICATION_APNS_KEY_ID');
  if (!APNS_CONFIG.teamId) missing.push('NOTIFICATION_APNS_TEAM_ID');
  if (!APNS_CONFIG.bundleId) missing.push('NOTIFICATION_APNS_BUNDLE_ID');
  if (getPrivateKeySource() === 'none') {
    missing.push('NOTIFICATION_APNS_PRIVATE_KEY_*');
  }
  return missing;
};

const getProviderHost = (): string => {
  return APNS_CONFIG.useSandbox ? 'https://api.sandbox.push.apple.com' : 'https://api.push.apple.com';
};

const getProviderToken = (): string => {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJWTToken && cachedJWTToken.expiresAt - 60 > now) {
    return cachedJWTToken.token;
  }

  const privateKey = loadPrivateKey();
  if (!privateKey) {
    throw new Error('missing-apns-private-key');
  }
  if (!APNS_CONFIG.keyId || !APNS_CONFIG.teamId) {
    throw new Error('missing-apns-key-id-or-team-id');
  }

  const token = jwt.sign(
    {
      iss: APNS_CONFIG.teamId,
      iat: now,
    },
    privateKey,
    {
      algorithm: 'ES256',
      keyid: APNS_CONFIG.keyId,
    }
  );

  cachedJWTToken = {
    token,
    expiresAt: now + 50 * 60,
  };
  return token;
};

const buildAPNSPayload = (event: NotificationEvent): Record<string, unknown> => {
  return {
    aps: {
      alert: {
        title: event.payload.title,
        body: event.payload.body,
      },
      sound: 'default',
      ...(typeof event.payload.badgeDelta === 'number' ? { badge: Math.max(0, event.payload.badgeDelta) } : {}),
    },
    deeplink: event.payload.deeplink || null,
    category: event.category,
    metadata: event.payload.metadata || {},
  };
};

const sendOneAPNSNotification = async (
  client: http2.ClientHttp2Session,
  deviceToken: string,
  event: NotificationEvent
): Promise<APNSSendResult> => {
  const providerToken = getProviderToken();
  const payload = JSON.stringify(buildAPNSPayload(event));
  const request = client.request({
    ':method': 'POST',
    ':path': `/3/device/${deviceToken}`,
    authorization: `bearer ${providerToken}`,
    'apns-topic': APNS_CONFIG.bundleId,
    'apns-push-type': 'alert',
    'apns-priority': '10',
    'content-type': 'application/json',
  });

  return new Promise<APNSSendResult>((resolve, reject) => {
    let responseBody = '';
    let statusCode = 0;

    request.setEncoding('utf8');
    request.on('response', (headers) => {
      statusCode = Number(headers[':status'] || 0);
    });
    request.on('data', (chunk: string) => {
      responseBody += chunk;
    });
    request.on('error', (error) => {
      reject(error);
    });
    request.on('end', () => {
      if (statusCode >= 200 && statusCode < 300) {
        resolve({ success: true, statusCode });
        return;
      }

      let reason = 'apns-send-failed';
      if (responseBody) {
        try {
          const parsed = JSON.parse(responseBody) as { reason?: unknown };
          if (typeof parsed.reason === 'string' && parsed.reason.trim()) {
            reason = parsed.reason;
          }
        } catch {
          reason = responseBody.slice(0, 300);
        }
      }

      resolve({
        success: false,
        statusCode,
        reason,
      });
    });

    request.write(payload);
    request.end();
  });
};

const deactivateInvalidTokens = async (tokens: string[]): Promise<void> => {
  if (tokens.length === 0) return;
  await prisma.devicePushToken.updateMany({
    where: {
      pushToken: { in: tokens },
    },
    data: {
      isActive: false,
    },
  });
};

const createAPNSHandler = (): NotificationChannelHandler => {
  return {
    async deliver(event: NotificationEvent) {
      const targetUserIds = Array.from(new Set(event.targets.map((item) => item.userId.trim()).filter(Boolean)));

      if (!APNS_CONFIG.enabled) {
        return {
          channel: 'apns',
          success: false,
          detail: 'apns-disabled',
          targetResults: targetUserIds.map((userId) => ({
            userId,
            success: false,
            detail: 'apns-disabled',
            attempts: 0,
          })),
        };
      }

      if (!isConfigured()) {
        return {
          channel: 'apns',
          success: false,
          detail: `apns-config-missing:${getMissingConfigFields().join(',') || 'unknown'}`,
          targetResults: targetUserIds.map((userId) => ({
            userId,
            success: false,
            detail: 'apns-config-missing',
            attempts: 0,
          })),
        };
      }

      if (targetUserIds.length === 0) {
        return { channel: 'apns', success: true, detail: 'no-target-users' };
      }

      const deviceTokens = await prisma.devicePushToken.findMany({
        where: {
          userId: { in: targetUserIds },
          isActive: true,
          platform: { in: ['ios', 'apns', 'ios_apns'] },
        },
        select: {
          userId: true,
          pushToken: true,
        },
      });

      const tokens = Array.from(new Set(deviceTokens.map((item) => item.pushToken.trim()).filter(Boolean)));
      if (tokens.length === 0) {
        return {
          channel: 'apns',
          success: false,
          detail: 'no-active-device-token',
          targetResults: targetUserIds.map((userId) => ({
            userId,
            success: false,
            detail: 'no-active-device-token',
            attempts: 0,
          })),
        };
      }

      const userTokenMap = new Map<string, string[]>();
      for (const item of deviceTokens) {
        const userId = item.userId.trim();
        const token = item.pushToken.trim();
        if (!userId || !token) continue;
        const current = userTokenMap.get(userId) ?? [];
        if (!current.includes(token)) {
          current.push(token);
        }
        userTokenMap.set(userId, current);
      }

      const client = http2.connect(getProviderHost());
      try {
        const tokenResults = await Promise.all(
          tokens.map(async (token) => {
            try {
              return {
                token,
                result: await sendOneAPNSNotification(client, token, event),
              };
            } catch (error) {
              return {
                token,
                result: {
                  success: false,
                  statusCode: 0,
                  reason: error instanceof Error ? error.message : 'apns-transport-error',
                } as APNSSendResult,
              };
            }
          })
        );

        const invalidTokens: string[] = [];
        let tokenSuccessCount = 0;
        let tokenFailCount = 0;
        const tokenResultMap = new Map(tokenResults.map((item) => [item.token, item.result]));

        for (const { token, result } of tokenResults) {
          if (result.success) {
            tokenSuccessCount += 1;
            continue;
          }

          tokenFailCount += 1;
          if (
            result.statusCode === 410 ||
            result.reason === 'BadDeviceToken' ||
            result.reason === 'Unregistered' ||
            result.reason === 'DeviceTokenNotForTopic'
          ) {
            invalidTokens.push(token);
          }
        }

        if (invalidTokens.length > 0) {
          await deactivateInvalidTokens(invalidTokens);
        }

        const targetResults = targetUserIds.map((userId) => {
          const userTokens = userTokenMap.get(userId) ?? [];
          if (userTokens.length === 0) {
            return {
              userId,
              success: false,
              detail: 'no-active-device-token',
              attempts: 0,
            };
          }

          let userTokenSuccessCount = 0;
          let userTokenFailCount = 0;
          const failReasons: string[] = [];
          for (const token of userTokens) {
            const result = tokenResultMap.get(token);
            if (!result) {
              userTokenFailCount += 1;
              failReasons.push('missing-send-result');
              continue;
            }
            if (result.success) {
              userTokenSuccessCount += 1;
              continue;
            }
            userTokenFailCount += 1;
            if (result.reason) {
              failReasons.push(result.reason);
            }
          }

          const success = userTokenSuccessCount > 0;
          return {
            userId,
            success,
            detail: success
              ? `sent=${userTokenSuccessCount}, failed=${userTokenFailCount}`
              : failReasons[0] || `failed=${userTokenFailCount}`,
            attempts: userTokens.length,
            deliveredAt: success ? new Date() : undefined,
          };
        });

        const deliveredUserCount = targetResults.filter((item) => item.success).length;
        const success = deliveredUserCount > 0;
        return {
          channel: 'apns',
          success,
          detail: `user_sent=${deliveredUserCount}/${targetResults.length}, token_sent=${tokenSuccessCount}, token_failed=${tokenFailCount}, invalidated=${invalidTokens.length}`,
          targetResults,
        };
      } finally {
        client.close();
      }
    },
  };
};

export const getNotificationCenterAPNSStatus = (): {
  enabled: boolean;
  configured: boolean;
  providerHost: string;
  useSandbox: boolean;
  bundleId: string | null;
  keyIdMasked: string | null;
  teamIdMasked: string | null;
  privateKeySource: 'inline' | 'base64' | 'path' | 'none';
  privateKeyPath: string | null;
  missingConfig: string[];
  tokenCache: { active: boolean; expiresAt: string | null };
} => {
  const privateKeySource = getPrivateKeySource();
  const tokenCacheExpiry = cachedJWTToken?.expiresAt ? new Date(cachedJWTToken.expiresAt * 1000).toISOString() : null;
  return {
    enabled: APNS_CONFIG.enabled,
    configured: isConfigured(),
    providerHost: getProviderHost(),
    useSandbox: APNS_CONFIG.useSandbox,
    bundleId: APNS_CONFIG.bundleId || null,
    keyIdMasked: APNS_CONFIG.keyId ? maskText(APNS_CONFIG.keyId) : null,
    teamIdMasked: APNS_CONFIG.teamId ? maskText(APNS_CONFIG.teamId) : null,
    privateKeySource,
    privateKeyPath: privateKeySource === 'path' ? APNS_CONFIG.privateKeyPath || null : null,
    missingConfig: APNS_CONFIG.enabled ? getMissingConfigFields() : [],
    tokenCache: {
      active: Boolean(tokenCacheExpiry),
      expiresAt: tokenCacheExpiry,
    },
  };
};

export const registerNotificationCenterAPNSHandler = (): void => {
  notificationCenterService.registerHandler('apns', createAPNSHandler());
};
