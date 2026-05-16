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

type SessionListBody = {
  items?: Array<{
    id: string;
    clientType?: string | null;
    isCurrent?: boolean;
    revokedAt?: string | null;
    expiresAt?: string;
    idleExpiresAt?: string | null;
    absoluteExpiresAt?: string | null;
  }>;
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
  cookieHeader: string,
  accessToken?: string
): Promise<ApiResponse<T>> => {
  const response = await axios.request<T>({
    method,
    url: buildPath(path),
    data: body,
    headers: {
      'Content-Type': 'application/json',
      ...(cookieHeader ? { Cookie: cookieHeader } : {}),
      ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
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

const parseDateMs = (value: string | null | undefined, label: string): number => {
  assert(Boolean(value), `${label} missing`);
  const ms = Date.parse(value || '');
  assert(Number.isFinite(ms), `${label} is not a valid date: ${String(value)}`);
  return ms;
};

const newIdentity = (prefix: string): { username: string; email: string; password: string } => {
  const suffix = `${Date.now()}`.slice(-6) + crypto.randomInt(1000, 9999).toString();
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
    { ...account, displayName: account.username, birthYear: 1998, regionCode: 'JP' },
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
  const activeAccessToken = refresh.data.accessToken || refresh.data.token || '';
  assert(Boolean(activeAccessToken), 'refresh response missing access token');

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

  const sessionList = await request<SessionListBody>('GET', '/auth/sessions', undefined, cookieHeader, activeAccessToken);
  assert(sessionList.status === 200, `session-list expected 200 but got ${sessionList.status}`);
  const currentSession = sessionList.data.items?.find((item) => item.isCurrent);
  assert(Boolean(currentSession?.id), 'session-list expected current session');

  const revokeCurrent = await request<{ success?: boolean; revokedCurrent?: boolean }>(
    'DELETE',
    `/auth/sessions/${currentSession?.id || ''}`,
    undefined,
    cookieHeader,
    activeAccessToken
  );
  cookieHeader = mergeCookies(cookieHeader, revokeCurrent.setCookies);
  assert(revokeCurrent.status === 200, `revoke-current-session expected 200 but got ${revokeCurrent.status}`);
  assert(revokeCurrent.data.success === true, 'revoke-current-session missing success=true');
  assert(revokeCurrent.data.revokedCurrent === true, 'revoke-current-session expected revokedCurrent=true');

  const refreshAfterCurrentRevoke = await request<{ error?: string; code?: string }>('POST', '/auth/refresh', {}, cookieHeader);
  assert(
    refreshAfterCurrentRevoke.status === 401,
    `refresh-after-current-revoke expected 401 but got ${refreshAfterCurrentRevoke.status}`
  );

  const reloginAfterCurrentRevoke = await request<AuthSuccessBody>(
    'POST',
    '/auth/login',
    { identifier: account.username, password: account.password },
    ''
  );
  cookieHeader = mergeCookies('', reloginAfterCurrentRevoke.setCookies);
  assert(reloginAfterCurrentRevoke.status === 200, `relogin-after-current-revoke expected 200 but got ${reloginAfterCurrentRevoke.status}`);

  const webAdminCookieHeader = '';
  const webAdminLogin = await axios.request<AuthSuccessBody>({
    method: 'POST',
    url: buildPath('/auth/login'),
    data: {
      identifier: account.username,
      password: account.password,
      clientType: 'web_admin',
      deviceName: 'Auth Integration Admin Browser',
      platform: 'web',
      appVersion: 'itest',
    },
    headers: {
      'Content-Type': 'application/json',
      'x-raver-client-type': 'web_admin',
      'x-raver-device-name': 'Auth Integration Admin Browser',
      'x-raver-platform': 'web',
      'x-raver-app-version': 'itest',
    },
    validateStatus: () => true,
  });
  assert(webAdminLogin.status === 200, `web-admin-login expected 200 but got ${webAdminLogin.status}`);
  const webAdminCookie = mergeCookies(
    webAdminCookieHeader,
    Array.isArray(webAdminLogin.headers['set-cookie']) ? webAdminLogin.headers['set-cookie'] : []
  );
  const webAdminAccessToken = webAdminLogin.data.accessToken || webAdminLogin.data.token || '';
  assert(Boolean(webAdminAccessToken), 'web-admin-login missing access token');
  const webAdminSessions = await request<SessionListBody>(
    'GET',
    '/auth/sessions',
    undefined,
    webAdminCookie,
    webAdminAccessToken
  );
  assert(webAdminSessions.status === 200, `web-admin-session-list expected 200 but got ${webAdminSessions.status}`);
  const webAdminCurrent = webAdminSessions.data.items?.find((item) => item.isCurrent);
  assert(webAdminCurrent?.clientType === 'web_admin', `web-admin current session expected clientType=web_admin but got ${String(webAdminCurrent?.clientType)}`);
  const webAdminExpiresInMs = parseDateMs(webAdminCurrent?.expiresAt, 'web-admin expiresAt') - Date.now();
  assert(webAdminExpiresInMs > 11 * 60 * 60 * 1000, `web-admin expiresAt expected >11h but got ${webAdminExpiresInMs}ms`);
  assert(webAdminExpiresInMs < 13 * 60 * 60 * 1000, `web-admin expiresAt expected <13h but got ${webAdminExpiresInMs}ms`);
  assert(Boolean(webAdminCurrent?.idleExpiresAt), 'web-admin current session expected idleExpiresAt');
  assert(Boolean(webAdminCurrent?.absoluteExpiresAt), 'web-admin current session expected absoluteExpiresAt');

  const iosLogin = await axios.request<AuthSuccessBody>({
    method: 'POST',
    url: buildPath('/auth/login'),
    data: {
      identifier: account.username,
      password: account.password,
      clientType: 'ios',
      deviceName: 'Auth Integration iPhone',
      platform: 'ios',
      appVersion: 'itest',
    },
    headers: {
      'Content-Type': 'application/json',
      'x-raver-client-type': 'ios',
      'x-raver-device-name': 'Auth Integration iPhone',
      'x-raver-platform': 'ios',
      'x-raver-app-version': 'itest',
    },
    validateStatus: () => true,
  });
  assert(iosLogin.status === 200, `ios-login expected 200 but got ${iosLogin.status}`);
  const iosCookie = mergeCookies('', Array.isArray(iosLogin.headers['set-cookie']) ? iosLogin.headers['set-cookie'] : []);
  const iosAccessToken = iosLogin.data.accessToken || iosLogin.data.token || '';
  assert(Boolean(iosAccessToken), 'ios-login missing access token');
  const iosSessions = await request<SessionListBody>('GET', '/auth/sessions', undefined, iosCookie, iosAccessToken);
  assert(iosSessions.status === 200, `ios-session-list expected 200 but got ${iosSessions.status}`);
  const iosCurrent = iosSessions.data.items?.find((item) => item.isCurrent);
  assert(iosCurrent?.clientType === 'ios', `ios current session expected clientType=ios but got ${String(iosCurrent?.clientType)}`);
  const iosExpiresInMs = parseDateMs(iosCurrent?.expiresAt, 'ios expiresAt') - Date.now();
  assert(iosExpiresInMs > 29 * 24 * 60 * 60 * 1000, `ios expiresAt expected >29d but got ${iosExpiresInMs}ms`);
  assert(!iosCurrent?.idleExpiresAt, 'ios current session expected no idleExpiresAt');
  assert(!iosCurrent?.absoluteExpiresAt, 'ios current session expected no absoluteExpiresAt');

  const logoutAllLoginA = await request<AuthSuccessBody>(
    'POST',
    '/auth/login',
    { identifier: account.username, password: account.password, clientType: 'ios', deviceName: 'logout-all-a', platform: 'ios' },
    ''
  );
  const logoutAllCookieA = mergeCookies('', logoutAllLoginA.setCookies);
  const logoutAllAccessA = logoutAllLoginA.data.accessToken || logoutAllLoginA.data.token || '';
  const logoutAllRefreshA = logoutAllLoginA.data.refreshToken || '';
  assert(logoutAllLoginA.status === 200, `logout-all login A expected 200 but got ${logoutAllLoginA.status}`);
  assert(Boolean(logoutAllAccessA), 'logout-all login A missing access token');
  assert(Boolean(logoutAllRefreshA), 'logout-all login A missing refresh token');

  const logoutAllLoginB = await request<AuthSuccessBody>(
    'POST',
    '/auth/login',
    { identifier: account.username, password: account.password, clientType: 'ios', deviceName: 'logout-all-b', platform: 'ios' },
    ''
  );
  const logoutAllCookieB = mergeCookies('', logoutAllLoginB.setCookies);
  const logoutAllRefreshB = logoutAllLoginB.data.refreshToken || '';
  assert(logoutAllLoginB.status === 200, `logout-all login B expected 200 but got ${logoutAllLoginB.status}`);
  assert(Boolean(logoutAllRefreshB), 'logout-all login B missing refresh token');

  const beforeLogoutAllSessions = await request<SessionListBody>('GET', '/auth/sessions', undefined, logoutAllCookieA, logoutAllAccessA);
  assert(beforeLogoutAllSessions.status === 200, `before-logout-all sessions expected 200 but got ${beforeLogoutAllSessions.status}`);
  const activeBeforeLogoutAll = beforeLogoutAllSessions.data.items?.filter((item) => !item.revokedAt).length || 0;
  assert(activeBeforeLogoutAll >= 2, `logout-all expected at least two active sessions before revoke but got ${activeBeforeLogoutAll}`);

  const logoutAll = await request<{ success?: boolean }>('POST', '/auth/logout-all', {}, logoutAllCookieA, logoutAllAccessA);
  assert(logoutAll.status === 200, `logout-all expected 200 but got ${logoutAll.status}`);
  assert(logoutAll.data.success === true, 'logout-all missing success=true');

  const refreshAfterLogoutAllA = await request<{ error?: string; code?: string }>(
    'POST',
    '/auth/refresh',
    { refreshToken: logoutAllRefreshA },
    ''
  );
  assert(refreshAfterLogoutAllA.status === 401, `refresh-after-logout-all A expected 401 but got ${refreshAfterLogoutAllA.status}`);
  assert(
    refreshAfterLogoutAllA.data.code === 'AUTH_SESSION_REVOKED',
    `refresh-after-logout-all A expected AUTH_SESSION_REVOKED but got ${String(refreshAfterLogoutAllA.data.code)}`
  );

  const refreshAfterLogoutAllB = await request<{ error?: string; code?: string }>(
    'POST',
    '/auth/refresh',
    { refreshToken: logoutAllRefreshB },
    logoutAllCookieB
  );
  assert(refreshAfterLogoutAllB.status === 401, `refresh-after-logout-all B expected 401 but got ${refreshAfterLogoutAllB.status}`);
  assert(
    refreshAfterLogoutAllB.data.code === 'AUTH_SESSION_REVOKED',
    `refresh-after-logout-all B expected AUTH_SESSION_REVOKED but got ${String(refreshAfterLogoutAllB.data.code)}`
  );

  const passwordAccount = newIdentity('auth_it_pw');
  const passwordRegister = await request<AuthSuccessBody>(
    'POST',
    '/auth/register',
    { ...passwordAccount, displayName: passwordAccount.username, birthYear: 1998, regionCode: 'JP' },
    ''
  );
  assert(passwordRegister.status === 201, `password-register expected 201 but got ${passwordRegister.status}`);

  const passwordLoginA = await request<AuthSuccessBody>(
    'POST',
    '/auth/login',
    { identifier: passwordAccount.username, password: passwordAccount.password, clientType: 'ios', deviceName: 'password-session-a', platform: 'ios' },
    ''
  );
  const passwordCookieA = mergeCookies('', passwordLoginA.setCookies);
  const passwordAccessA = passwordLoginA.data.accessToken || passwordLoginA.data.token || '';
  const passwordRefreshA = passwordLoginA.data.refreshToken || '';
  assert(passwordLoginA.status === 200, `password-login A expected 200 but got ${passwordLoginA.status}`);
  assert(Boolean(passwordAccessA), 'password-login A missing access token');
  assert(Boolean(passwordRefreshA), 'password-login A missing refresh token');

  const passwordLoginB = await request<AuthSuccessBody>(
    'POST',
    '/auth/login',
    { identifier: passwordAccount.username, password: passwordAccount.password, clientType: 'ios', deviceName: 'password-session-b', platform: 'ios' },
    ''
  );
  const passwordCookieB = mergeCookies('', passwordLoginB.setCookies);
  const passwordRefreshB = passwordLoginB.data.refreshToken || '';
  assert(passwordLoginB.status === 200, `password-login B expected 200 but got ${passwordLoginB.status}`);
  assert(Boolean(passwordRefreshB), 'password-login B missing refresh token');

  const changePassword = await request<{ success?: boolean; revokedOtherSessions?: number }>(
    'POST',
    '/auth/password',
    { currentPassword: passwordAccount.password, newPassword: 'Passw0rd!2' },
    passwordCookieA,
    passwordAccessA
  );
  assert(changePassword.status === 200, `change-password expected 200 but got ${changePassword.status}`);
  assert(changePassword.data.success === true, 'change-password missing success=true');
  assert(
    Number(changePassword.data.revokedOtherSessions || 0) >= 1,
    `change-password expected at least one revoked other session but got ${String(changePassword.data.revokedOtherSessions)}`
  );

  const refreshCurrentAfterPasswordChange = await request<AuthSuccessBody>(
    'POST',
    '/auth/refresh',
    { refreshToken: passwordRefreshA },
    passwordCookieA
  );
  assert(
    refreshCurrentAfterPasswordChange.status === 200,
    `refresh-current-after-password-change expected 200 but got ${refreshCurrentAfterPasswordChange.status}`
  );
  const refreshOtherAfterPasswordChange = await request<{ error?: string; code?: string }>(
    'POST',
    '/auth/refresh',
    { refreshToken: passwordRefreshB },
    passwordCookieB
  );
  assert(
    refreshOtherAfterPasswordChange.status === 401,
    `refresh-other-after-password-change expected 401 but got ${refreshOtherAfterPasswordChange.status}`
  );
  assert(
    refreshOtherAfterPasswordChange.data.code === 'AUTH_SESSION_REVOKED',
    `refresh-other-after-password-change expected AUTH_SESSION_REVOKED but got ${String(refreshOtherAfterPasswordChange.data.code)}`
  );

  const deletedAccount = newIdentity('auth_it_del');
  const deletedRegister = await request<AuthSuccessBody>(
    'POST',
    '/auth/register',
    { ...deletedAccount, displayName: deletedAccount.username, birthYear: 1998, regionCode: 'JP' },
    ''
  );
  assert(deletedRegister.status === 201, `delete-register expected 201 but got ${deletedRegister.status}`);

  const deleteLoginA = await request<AuthSuccessBody>(
    'POST',
    '/auth/login',
    { identifier: deletedAccount.username, password: deletedAccount.password, clientType: 'ios', deviceName: 'delete-session-a', platform: 'ios' },
    ''
  );
  const deleteCookieA = mergeCookies('', deleteLoginA.setCookies);
  const deleteAccessA = deleteLoginA.data.accessToken || deleteLoginA.data.token || '';
  const deleteRefreshA = deleteLoginA.data.refreshToken || '';
  assert(deleteLoginA.status === 200, `delete-login A expected 200 but got ${deleteLoginA.status}`);
  assert(Boolean(deleteAccessA), 'delete-login A missing access token');
  assert(Boolean(deleteRefreshA), 'delete-login A missing refresh token');

  const deleteLoginB = await request<AuthSuccessBody>(
    'POST',
    '/auth/login',
    { identifier: deletedAccount.username, password: deletedAccount.password, clientType: 'ios', deviceName: 'delete-session-b', platform: 'ios' },
    ''
  );
  const deleteCookieB = mergeCookies('', deleteLoginB.setCookies);
  const deleteRefreshB = deleteLoginB.data.refreshToken || '';
  assert(deleteLoginB.status === 200, `delete-login B expected 200 but got ${deleteLoginB.status}`);
  assert(Boolean(deleteRefreshB), 'delete-login B missing refresh token');

  const deleteAccount = await request<{ success?: boolean; status?: string }>(
    'DELETE',
    '/auth/account',
    {},
    deleteCookieA,
    deleteAccessA
  );
  assert(deleteAccount.status === 200, `delete-account expected 200 but got ${deleteAccount.status}`);
  assert(deleteAccount.data.success === true, 'delete-account missing success=true');
  assert(deleteAccount.data.status === 'deleted', `delete-account expected status=deleted but got ${String(deleteAccount.data.status)}`);

  const refreshCurrentAfterDelete = await request<{ error?: string; code?: string }>(
    'POST',
    '/auth/refresh',
    { refreshToken: deleteRefreshA },
    deleteCookieA
  );
  assert(refreshCurrentAfterDelete.status === 401, `refresh-current-after-delete expected 401 but got ${refreshCurrentAfterDelete.status}`);
  assert(
    refreshCurrentAfterDelete.data.code === 'AUTH_SESSION_REVOKED',
    `refresh-current-after-delete expected AUTH_SESSION_REVOKED but got ${String(refreshCurrentAfterDelete.data.code)}`
  );
  const refreshOtherAfterDelete = await request<{ error?: string; code?: string }>(
    'POST',
    '/auth/refresh',
    { refreshToken: deleteRefreshB },
    deleteCookieB
  );
  assert(refreshOtherAfterDelete.status === 401, `refresh-other-after-delete expected 401 but got ${refreshOtherAfterDelete.status}`);
  assert(
    refreshOtherAfterDelete.data.code === 'AUTH_SESSION_REVOKED',
    `refresh-other-after-delete expected AUTH_SESSION_REVOKED but got ${String(refreshOtherAfterDelete.data.code)}`
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
    { ...loginRateUser, displayName: loginRateUser.username, birthYear: 1998, regionCode: 'JP' },
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
      { ...registerRateUser, displayName: registerRateUser.username, birthYear: 1998, regionCode: 'JP' },
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

  if (['1', 'true', 'yes', 'on'].includes(String(process.env.AUTH_FIREBASE_PHONE_MOCK || '').trim().toLowerCase())) {
    const firebasePhone = randomPhone();
    const firebasePhoneLogin = await request<AuthSuccessBody>(
      'POST',
      '/auth/firebase-phone/login',
      {
        idToken: `mock-firebase-phone:${firebasePhone}:auth-it-firebase`,
        birthYear: 1998,
        regionCode: 'JP',
      },
      ''
    );
    assert(
      firebasePhoneLogin.status === 200,
      `firebase-phone-login expected 200 but got ${firebasePhoneLogin.status}`
    );
    assert(
      Boolean(firebasePhoneLogin.data.accessToken || firebasePhoneLogin.data.token),
      'firebase-phone-login missing access token'
    );
    assert(Boolean(firebasePhoneLogin.data.refreshToken), 'firebase-phone-login missing refresh token');

    const firebasePhoneInvalid = await request<{ code?: string }>(
      'POST',
      '/auth/firebase-phone/login',
      { idToken: 'invalid-firebase-phone-token' },
      ''
    );
    assert(
      firebasePhoneInvalid.status === 401,
      `firebase-phone-invalid expected 401 but got ${firebasePhoneInvalid.status}`
    );
    assert(
      firebasePhoneInvalid.data.code === 'AUTH_FIREBASE_PHONE_TOKEN_INVALID',
      `firebase-phone-invalid expected AUTH_FIREBASE_PHONE_TOKEN_INVALID but got ${String(firebasePhoneInvalid.data.code)}`
    );
    console.log('[auth-integration] scenario firebase-phone-flow passed');
  } else {
    console.log('[auth-integration] scenario firebase-phone-flow skipped (AUTH_FIREBASE_PHONE_MOCK=true to enable)');
  }

  console.log('[auth-integration] all scenarios passed');
};

main().catch((error) => {
  console.error('[auth-integration] failed', error);
  process.exitCode = 1;
});
