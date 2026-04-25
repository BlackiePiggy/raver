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
  refreshToken?: string;
};

type SmsSendBody = {
  success?: boolean;
  expiresInSeconds?: number;
  debugCode?: string;
  debugProvider?: string;
};

const baseUrl = (process.env.AUTH_INTEGRATION_BASE_URL || 'http://127.0.0.1:3901/v1').replace(/\/+$/, '');
const expectedAccessExpiresIn = Number(process.env.AUTH_INTEGRATION_EXPECT_ACCESS_EXPIRES_IN || '900');
const loginRateLimitMaxAttempts = Number(process.env.AUTH_INTEGRATION_LOGIN_RATE_MAX_ATTEMPTS || '10');
const registerRateLimitMaxAttempts = Number(process.env.AUTH_INTEGRATION_REGISTER_RATE_MAX_ATTEMPTS || '10');
const enableSmsFlow = !['0', 'false', 'no', 'off'].includes(
  String(process.env.AUTH_INTEGRATION_ENABLE_SMS || 'true').trim().toLowerCase()
);
const requireSmsDebugCode = !['0', 'false', 'no', 'off'].includes(
  String(process.env.AUTH_INTEGRATION_REQUIRE_SMS_DEBUG_CODE || 'true').trim().toLowerCase()
);

const buildPath = (path: string): string => `${baseUrl}${path.startsWith('/') ? path : `/${path}`}`;

const mergeCookies = (prevCookieHeader: string, setCookies: string[]): string => {
  const cookieMap = new Map<string, string>();
  prevCookieHeader
    .split(';')
    .map((item) => item.trim())
    .filter(Boolean)
    .forEach((pair) => {
      const index = pair.indexOf('=');
      if (index <= 0) return;
      cookieMap.set(pair.slice(0, index), pair.slice(index + 1));
    });

  setCookies.forEach((cookie) => {
    const first = cookie.split(';')[0]?.trim();
    if (!first) return;
    const index = first.indexOf('=');
    if (index <= 0) return;
    cookieMap.set(first.slice(0, index), first.slice(index + 1));
  });

  return Array.from(cookieMap.entries())
    .map(([key, value]) => `${key}=${value}`)
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
  return {
    status: response.status,
    data: response.data,
    setCookies: Array.isArray(setCookieHeader) ? setCookieHeader : [],
  };
};

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const newIdentity = (prefix: string): { username: string; email: string; password: string } => {
  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  const username = `${prefix}_${suffix}`;
  return {
    username,
    email: `${username}@example.com`,
    password: 'Passw0rd!',
  };
};

const randomPhone = (): string => {
  const trailing = `${Date.now()}`.slice(-7);
  return `+1555${trailing}`;
};

const main = async (): Promise<void> => {
  assert(Number.isFinite(expectedAccessExpiresIn) && expectedAccessExpiresIn > 0, 'Invalid AUTH_INTEGRATION_EXPECT_ACCESS_EXPIRES_IN');
  assert(Number.isFinite(loginRateLimitMaxAttempts) && loginRateLimitMaxAttempts >= 1, 'Invalid AUTH_INTEGRATION_LOGIN_RATE_MAX_ATTEMPTS');
  assert(
    Number.isFinite(registerRateLimitMaxAttempts) && registerRateLimitMaxAttempts >= 1,
    'Invalid AUTH_INTEGRATION_REGISTER_RATE_MAX_ATTEMPTS'
  );

  console.log('[auth-integration] start', {
    baseUrl,
    expectedAccessExpiresIn,
    loginRateLimitMaxAttempts,
    registerRateLimitMaxAttempts,
    enableSmsFlow,
    requireSmsDebugCode,
  });

  // Scenario A: account register/login + refresh rotation + logout revoke
  const account = newIdentity('auth_it');
  let cookieHeader = '';

  const register = await request<AuthSuccessBody>(
    'POST',
    '/auth/register',
    { ...account, displayName: account.username },
    cookieHeader
  );
  cookieHeader = mergeCookies(cookieHeader, register.setCookies);
  assert(register.status === 201, `register expected 201 but got ${register.status}`);
  assert(
    register.data.accessTokenExpiresIn === expectedAccessExpiresIn,
    `register accessTokenExpiresIn expected ${expectedAccessExpiresIn} but got ${String(register.data.accessTokenExpiresIn)}`
  );

  const logoutAfterRegister = await request<{ success?: boolean }>('POST', '/auth/logout', {}, cookieHeader);
  cookieHeader = mergeCookies(cookieHeader, logoutAfterRegister.setCookies);
  assert(logoutAfterRegister.status === 200, `logout-after-register expected 200 but got ${logoutAfterRegister.status}`);

  const login = await request<AuthSuccessBody>(
    'POST',
    '/auth/login',
    { identifier: account.username, password: account.password },
    cookieHeader
  );
  cookieHeader = mergeCookies(cookieHeader, login.setCookies);
  assert(login.status === 200, `login expected 200 but got ${login.status}`);
  const loginRefreshToken = login.data.refreshToken || '';
  assert(Boolean(loginRefreshToken), 'login response missing refreshToken');

  const refresh = await request<AuthSuccessBody>('POST', '/auth/refresh', {}, cookieHeader);
  cookieHeader = mergeCookies(cookieHeader, refresh.setCookies);
  assert(refresh.status === 200, `refresh expected 200 but got ${refresh.status}`);
  const refreshedRefreshToken = refresh.data.refreshToken || '';
  assert(Boolean(refreshedRefreshToken), 'refresh response missing refreshToken');
  assert(
    refresh.data.accessTokenExpiresIn === expectedAccessExpiresIn,
    `refresh accessTokenExpiresIn expected ${expectedAccessExpiresIn} but got ${String(refresh.data.accessTokenExpiresIn)}`
  );
  assert(
    refreshedRefreshToken !== loginRefreshToken,
    'refresh rotation expected new refresh token but received same token'
  );

  const refreshWithOldToken = await request<{ error?: string }>(
    'POST',
    '/auth/refresh',
    { refreshToken: loginRefreshToken },
    cookieHeader
  );
  assert(
    refreshWithOldToken.status === 401,
    `refresh-with-old-token expected 401 but got ${refreshWithOldToken.status}`
  );

  const logout = await request<{ success?: boolean }>('POST', '/auth/logout', {}, cookieHeader);
  cookieHeader = mergeCookies(cookieHeader, logout.setCookies);
  assert(logout.status === 200, `logout expected 200 but got ${logout.status}`);
  assert(logout.data?.success === true, 'logout missing success=true');

  const refreshAfterLogout = await request<{ error?: string }>('POST', '/auth/refresh', {}, cookieHeader);
  assert(
    refreshAfterLogout.status === 401,
    `refresh-after-logout expected 401 but got ${refreshAfterLogout.status}`
  );
  console.log('[auth-integration] scenario account-session passed');

  // Scenario B: login rate limit
  const loginRateUser = newIdentity('auth_it_rl');
  const seededLoginRateUser = await request<AuthSuccessBody>(
    'POST',
    '/auth/register',
    { ...loginRateUser, displayName: loginRateUser.username },
    ''
  );
  assert(seededLoginRateUser.status === 201, `seed login-rate user expected 201 but got ${seededLoginRateUser.status}`);

  let loginRateLastStatus = 0;
  for (let attempt = 1; attempt <= loginRateLimitMaxAttempts + 1; attempt += 1) {
    const invalidLogin = await request<{ error?: string }>(
      'POST',
      '/auth/login',
      { identifier: loginRateUser.username, password: 'WrongPass!' },
      ''
    );
    loginRateLastStatus = invalidLogin.status;
    if (attempt <= loginRateLimitMaxAttempts) {
      assert(
        invalidLogin.status === 401,
        `login-rate attempt ${attempt} expected 401 but got ${invalidLogin.status}`
      );
    }
  }
  assert(loginRateLastStatus === 429, `login-rate final attempt expected 429 but got ${loginRateLastStatus}`);
  console.log('[auth-integration] scenario login-rate-limit passed');

  // Scenario C: register rate limit
  const registerRateUser = newIdentity('auth_it_rr');
  let registerRateLastStatus = 0;
  for (let attempt = 1; attempt <= registerRateLimitMaxAttempts + 1; attempt += 1) {
    const registerAttempt = await request<{ error?: string }>(
      'POST',
      '/auth/register',
      { ...registerRateUser, displayName: registerRateUser.username },
      ''
    );
    registerRateLastStatus = registerAttempt.status;
    if (attempt === 1) {
      assert(registerAttempt.status === 201, `register-rate attempt 1 expected 201 but got ${registerAttempt.status}`);
    } else if (attempt <= registerRateLimitMaxAttempts) {
      assert(
        registerAttempt.status === 409,
        `register-rate attempt ${attempt} expected 409 but got ${registerAttempt.status}`
      );
    }
  }
  assert(registerRateLastStatus === 429, `register-rate final attempt expected 429 but got ${registerRateLastStatus}`);
  console.log('[auth-integration] scenario register-rate-limit passed');

  // Scenario D: sms send/login flow (with mock debug code in non-prod)
  if (enableSmsFlow) {
    const phoneNumber = (process.env.AUTH_INTEGRATION_SMS_PHONE || '').trim() || randomPhone();
    const smsSend = await request<SmsSendBody>('POST', '/auth/sms/send', { phone: phoneNumber, scene: 'login' }, '');
    assert(smsSend.status === 201, `sms-send expected 201 but got ${smsSend.status}`);
    assert(Boolean(smsSend.data.success), 'sms-send missing success=true');

    const debugCode = smsSend.data.debugCode || '';
    if (requireSmsDebugCode) {
      assert(Boolean(debugCode), 'sms-send expected debugCode in current integration mode');
    }

    const smsWrongLogin = await request<{ error?: string }>(
      'POST',
      '/auth/sms/login',
      { phone: phoneNumber, code: '000000' },
      ''
    );
    assert(smsWrongLogin.status === 401, `sms-login wrong-code expected 401 but got ${smsWrongLogin.status}`);

    if (debugCode) {
      const smsLogin = await request<AuthSuccessBody>(
        'POST',
        '/auth/sms/login',
        { phone: phoneNumber, code: debugCode },
        ''
      );
      assert(smsLogin.status === 200, `sms-login expected 200 but got ${smsLogin.status}`);
      assert(Boolean(smsLogin.data.accessToken || smsLogin.data.token), 'sms-login missing access token');
      assert(Boolean(smsLogin.data.refreshToken), 'sms-login missing refresh token');
    }
    console.log('[auth-integration] scenario sms-flow passed');
  } else {
    console.log('[auth-integration] scenario sms-flow skipped (AUTH_INTEGRATION_ENABLE_SMS=false)');
  }

  console.log('[auth-integration] all scenarios passed');
};

main().catch((error) => {
  console.error('[auth-integration] failed', error);
  process.exitCode = 1;
});
