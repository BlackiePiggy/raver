import 'dotenv/config';
import axios, { type Method } from 'axios';
import crypto from 'crypto';

type ApiResponse<T> = {
  status: number;
  data: T;
  setCookies: string[];
};

type AuthSuccessBody = {
  accessToken?: string;
  token?: string;
  accessTokenExpiresIn?: number;
};

const baseUrl = (process.env.AUTH_SMOKE_BASE_URL || 'http://127.0.0.1:3901/v1').replace(/\/+$/, '');
const expectedAccessExpiresIn = Number(process.env.AUTH_SMOKE_EXPECT_ACCESS_EXPIRES_IN || '900');
const enableSmsCheck = ['1', 'true', 'yes', 'on'].includes(
  (process.env.AUTH_SMOKE_ENABLE_SMS || '').trim().toLowerCase()
);
const smokePhone = (process.env.AUTH_SMOKE_PHONE || '').trim();

const buildPath = (path: string): string => `${baseUrl}${path.startsWith('/') ? path : `/${path}`}`;

const mergeCookies = (prevCookieHeader: string, setCookies: string[]): string => {
  const bucket = new Map<string, string>();
  prevCookieHeader
    .split(';')
    .map((item) => item.trim())
    .filter(Boolean)
    .forEach((pair) => {
      const index = pair.indexOf('=');
      if (index <= 0) return;
      const name = pair.slice(0, index);
      const value = pair.slice(index + 1);
      bucket.set(name, value);
    });

  for (const cookie of setCookies) {
    const firstPair = cookie.split(';')[0]?.trim();
    if (!firstPair) continue;
    const index = firstPair.indexOf('=');
    if (index <= 0) continue;
    const name = firstPair.slice(0, index);
    const value = firstPair.slice(index + 1);
    bucket.set(name, value);
  }

  return Array.from(bucket.entries())
    .map(([name, value]) => `${name}=${value}`)
    .join('; ');
};

const request = async <T>(
  method: Method,
  path: string,
  body: unknown,
  cookieHeader: string
): Promise<ApiResponse<T>> => {
  const response = await axios.request<T>({
    method,
    url: buildPath(path),
    data: body,
    headers: {
      'Content-Type': 'application/json',
      ...(cookieHeader ? { Cookie: cookieHeader } : {}),
    },
    validateStatus: () => true,
  });

  const setCookieHeader = response.headers['set-cookie'];
  const setCookies = Array.isArray(setCookieHeader) ? setCookieHeader : [];
  return {
    status: response.status,
    data: response.data,
    setCookies,
  };
};

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const main = async (): Promise<void> => {
  assert(Number.isFinite(expectedAccessExpiresIn) && expectedAccessExpiresIn > 0, 'Invalid AUTH_SMOKE_EXPECT_ACCESS_EXPIRES_IN');

  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  const username = `auth_smoke_${suffix}`;
  const email = `${username}@example.com`;
  const password = 'Passw0rd!';
  let cookieHeader = '';

  console.log('[auth-smoke] start', { baseUrl, expectedAccessExpiresIn, enableSmsCheck });

  const register = await request<AuthSuccessBody>(
    'POST',
    '/auth/register',
    { username, email, password, displayName: username },
    cookieHeader
  );
  cookieHeader = mergeCookies(cookieHeader, register.setCookies);
  assert(register.status === 201, `register expected 201 but got ${register.status}`);
  const registerToken = register.data.accessToken || register.data.token || '';
  assert(Boolean(registerToken), 'register response missing access token');
  assert(
    register.data.accessTokenExpiresIn === expectedAccessExpiresIn,
    `register accessTokenExpiresIn expected ${expectedAccessExpiresIn} but got ${String(register.data.accessTokenExpiresIn)}`
  );
  console.log('[auth-smoke] register ok', {
    status: register.status,
    accessTokenExpiresIn: register.data.accessTokenExpiresIn,
  });

  const refresh = await request<AuthSuccessBody>('POST', '/auth/refresh', {}, cookieHeader);
  cookieHeader = mergeCookies(cookieHeader, refresh.setCookies);
  assert(refresh.status === 200, `refresh expected 200 but got ${refresh.status}`);
  const refreshToken = refresh.data.accessToken || refresh.data.token || '';
  assert(Boolean(refreshToken), 'refresh response missing access token');
  assert(
    refresh.data.accessTokenExpiresIn === expectedAccessExpiresIn,
    `refresh accessTokenExpiresIn expected ${expectedAccessExpiresIn} but got ${String(refresh.data.accessTokenExpiresIn)}`
  );
  console.log('[auth-smoke] refresh ok', { status: refresh.status });

  const logout = await request<{ success?: boolean }>('POST', '/auth/logout', {}, cookieHeader);
  cookieHeader = mergeCookies(cookieHeader, logout.setCookies);
  assert(logout.status === 200, `logout expected 200 but got ${logout.status}`);
  assert(logout.data?.success === true, 'logout response missing success=true');
  console.log('[auth-smoke] logout ok', { status: logout.status });

  const refreshAfterLogout = await request<{ error?: string }>('POST', '/auth/refresh', {}, cookieHeader);
  assert(refreshAfterLogout.status === 401, `refresh-after-logout expected 401 but got ${refreshAfterLogout.status}`);
  console.log('[auth-smoke] refresh-after-logout ok', { status: refreshAfterLogout.status });

  if (enableSmsCheck) {
    assert(Boolean(smokePhone), 'AUTH_SMOKE_ENABLE_SMS=true requires AUTH_SMOKE_PHONE');
    const smsSend = await request<{ success?: boolean }>(
      'POST',
      '/auth/sms/send',
      { phone: smokePhone, scene: 'login' },
      cookieHeader
    );
    assert(smsSend.status === 201, `sms-send expected 201 but got ${smsSend.status}`);
    console.log('[auth-smoke] sms-send ok', { status: smsSend.status });
  } else {
    console.log('[auth-smoke] sms check skipped (set AUTH_SMOKE_ENABLE_SMS=true and AUTH_SMOKE_PHONE to enable)');
  }

  console.log('[auth-smoke] all checks passed');
};

main().catch((error) => {
  console.error('[auth-smoke] failed', error);
  process.exitCode = 1;
});
