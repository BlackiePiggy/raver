import { expect, test } from '@playwright/test';

const adminUser = {
  id: 'admin-user-1',
  username: 'admin',
  email: 'admin@example.com',
  displayName: 'Admin User',
  avatarUrl: null,
  role: 'admin',
};

const adminStatus = {
  success: true,
  status: {
    checkedAt: new Date('2026-05-16T09:30:00.000Z').toISOString(),
    overallStatus: 'healthy',
    alertReasons: [],
    notification: {
      status: 'healthy',
      apns: { enabled: true, configured: true, environment: 'sandbox', bundleId: 'com.raver.app' },
      delivery: {
        totals: { total: 10, queued: 1, sent: 8, failed: 1 },
        rates: { deliveryFailureRate: 0.1 },
        alerts: { items: [] },
      },
      config: { quietHoursEnabled: false, defaultChannels: ['in_app'] },
      outboxWorker: {
        asyncModeEnabled: true,
        workerEnabled: true,
        intervalMs: 5000,
        eventLimit: 50,
        running: true,
        inFlight: false,
      },
    },
    checkinProjection: {
      projectionVersion: 2,
      status: 'healthy',
      dirtyCheckins: 0,
      pendingOutbox: 0,
      pendingReadyOutbox: 0,
      deadOutbox: 0,
      projectedUsers: 3,
      oldestPendingAvailableAt: null,
      oldestPendingCreatedAt: null,
      oldestPendingAgeSeconds: 0,
      thresholds: { criticalPendingAgeSeconds: 900 },
      alertReasons: [],
      checkedAt: new Date('2026-05-16T09:30:00.000Z').toISOString(),
    },
  },
};

const mockProfile = async (page: import('@playwright/test').Page) => {
  await page.route('**/v1/profile/me', async (route) => {
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(adminUser) });
  });
};

const mockBootstrapRefresh = async (page: import('@playwright/test').Page, token = 'bootstrap-token') => {
  await page.route('**/v1/auth/refresh', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ user: adminUser, token, accessToken: token }),
    });
  });
};

test('Web Admin refreshes after a 401 and retries the admin request', async ({ page }) => {
  let refreshCalls = 0;
  let statusCalls = 0;

  await mockProfile(page);
  await page.route('**/v1/auth/refresh', async (route) => {
    refreshCalls += 1;
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ user: adminUser, token: `access-token-${refreshCalls}`, accessToken: `access-token-${refreshCalls}` }),
    });
  });
  await page.route('**/api/admin/v1/status**', async (route) => {
    statusCalls += 1;
    if (statusCalls === 1) {
      await route.fulfill({ status: 401, contentType: 'application/json', body: JSON.stringify({ error: 'ACCESS_TOKEN_EXPIRED' }) });
      return;
    }
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(adminStatus) });
  });

  await page.goto('/admin');

  await expect(page.getByRole('heading', { name: '整体状态' })).toBeVisible();
  await expect(page.getByText('通知投递总量')).toBeVisible();
  expect(refreshCalls).toBe(2);
  expect(statusCalls).toBe(2);
});

test('Web Admin redirects to login when refresh fails after a 401', async ({ page }) => {
  let refreshCalls = 0;

  await mockProfile(page);
  await page.route('**/v1/auth/refresh', async (route) => {
    refreshCalls += 1;
    if (refreshCalls === 1) {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ user: adminUser, token: 'bootstrap-token', accessToken: 'bootstrap-token' }),
      });
      return;
    }
    await route.fulfill({ status: 401, contentType: 'application/json', body: JSON.stringify({ error: 'AUTH_REFRESH_EXPIRED' }) });
  });
  await page.route('**/api/admin/v1/status**', async (route) => {
    await route.fulfill({ status: 401, contentType: 'application/json', body: JSON.stringify({ error: 'ACCESS_TOKEN_EXPIRED' }) });
  });

  await page.goto('/admin');

  await expect(page).toHaveURL(/\/login\?reason=session-expired/);
  await expect(page.getByText('登录状态已过期，请重新登录。')).toBeVisible();
  expect(refreshCalls).toBe(2);
});

test('Web Admin clears legacy localStorage token during bootstrap', async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem('token', 'legacy-local-storage-token');
  });
  await mockProfile(page);
  await mockBootstrapRefresh(page, 'memory-bootstrap-token');
  await page.route('**/api/admin/v1/status**', async (route) => {
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(adminStatus) });
  });

  await page.goto('/admin');

  await expect(page.getByRole('heading', { name: '整体状态' })).toBeVisible();
  await expect.poll(() => page.evaluate(() => localStorage.getItem('token'))).toBeNull();
});

test('Web Admin keeps access token out of localStorage after login', async ({ page }) => {
  let loginAuthorizationHeader: string | undefined;

  await page.route('**/v1/auth/refresh', async (route) => {
    await route.fulfill({ status: 401, contentType: 'application/json', body: JSON.stringify({ error: 'AUTH_REFRESH_TOKEN_MISSING' }) });
  });
  await page.route('**/v1/auth/login', async (route) => {
    loginAuthorizationHeader = route.request().headers().authorization;
    const body = route.request().postDataJSON() as { identifier?: string; password?: string; clientType?: string };
    expect(body).toEqual({ identifier: 'admin@example.com', password: 'admin-password', clientType: 'web_admin' });
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ user: adminUser, token: 'login-access-token', accessToken: 'login-access-token' }),
    });
  });

  await page.goto('/login');
  await page.getByPlaceholder('your@email.com / username / nickname').fill('admin@example.com');
  await page.getByPlaceholder('••••••••').fill('admin-password');
  await page.getByRole('button', { name: 'Login' }).click();

  await expect(page).toHaveURL(/\/$/);
  expect(loginAuthorizationHeader).toBeUndefined();
  await expect.poll(() => page.evaluate(() => localStorage.getItem('token'))).toBeNull();
  await expect.poll(() => page.evaluate(() => Object.keys(localStorage))).not.toContain('token');
});

test('Web Admin lists auth sessions and revokes another session', async ({ page }) => {
  let listCalls = 0;
  let revokedSessionId: string | null = null;

  await mockProfile(page);
  await mockBootstrapRefresh(page);
  await page.route('**/v1/auth/sessions', async (route) => {
    listCalls += 1;
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        items: [
          {
            id: 'current-session',
            clientType: 'web_admin',
            deviceId: 'browser-1',
            deviceName: 'Chrome on Mac',
            platform: 'web',
            appVersion: null,
            userAgent: 'Playwright Chrome',
            ipAddressMasked: '127***0.1',
            createdAt: '2026-05-16T08:00:00.000Z',
            lastUsedAt: '2026-05-16T09:00:00.000Z',
            expiresAt: '2026-05-16T20:00:00.000Z',
            idleExpiresAt: '2026-05-16T09:30:00.000Z',
            absoluteExpiresAt: '2026-05-16T20:00:00.000Z',
            revokedAt: null,
            isCurrent: true,
          },
          {
            id: 'ios-session',
            clientType: 'ios',
            deviceId: 'ios-1',
            deviceName: 'Blackie iPhone',
            platform: 'ios',
            appVersion: '1.0.0',
            userAgent: 'Raver iOS',
            ipAddressMasked: '10***0.2',
            createdAt: '2026-05-15T08:00:00.000Z',
            lastUsedAt: '2026-05-16T08:50:00.000Z',
            expiresAt: '2026-06-15T08:00:00.000Z',
            idleExpiresAt: null,
            absoluteExpiresAt: null,
            revokedAt: listCalls > 1 ? '2026-05-16T09:05:00.000Z' : null,
            isCurrent: false,
          },
        ],
      }),
    });
  });
  await page.route('**/v1/auth/sessions/ios-session', async (route) => {
    revokedSessionId = 'ios-session';
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ success: true, revokedCurrent: false }),
    });
  });

  page.on('dialog', (dialog) => dialog.accept());
  await page.goto('/admin/auth-sessions');

  await expect(page.getByRole('heading', { name: '登录设备与会话' })).toBeVisible();
  await expect(page.getByText('Chrome on Mac')).toBeVisible();
  await expect(page.getByText('Blackie iPhone')).toBeVisible();
  await page.getByRole('button', { name: '撤销' }).last().click();

  await expect(page.getByText('会话已撤销')).toBeVisible();
  await expect(page.getByText('已撤销', { exact: true })).toBeVisible();
  expect(revokedSessionId).toBe('ios-session');
});

test('Web Admin revokes the current session and returns to logged-out state', async ({ page }) => {
  await mockProfile(page);
  await mockBootstrapRefresh(page);
  await page.route('**/v1/auth/sessions', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        items: [
          {
            id: 'current-session',
            clientType: 'web_admin',
            deviceId: 'browser-1',
            deviceName: 'Chrome on Mac',
            platform: 'web',
            appVersion: null,
            userAgent: 'Playwright Chrome',
            ipAddressMasked: '127***0.1',
            createdAt: '2026-05-16T08:00:00.000Z',
            lastUsedAt: '2026-05-16T09:00:00.000Z',
            expiresAt: '2026-05-16T20:00:00.000Z',
            idleExpiresAt: '2026-05-16T09:30:00.000Z',
            absoluteExpiresAt: '2026-05-16T20:00:00.000Z',
            revokedAt: null,
            isCurrent: true,
          },
        ],
      }),
    });
  });
  await page.route('**/v1/auth/sessions/current-session', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ success: true, revokedCurrent: true }),
    });
  });
  await page.route('**/v1/auth/logout', async (route) => {
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ success: true }) });
  });

  page.on('dialog', (dialog) => dialog.accept());
  await page.goto('/admin/auth-sessions');
  await page.getByRole('button', { name: '撤销' }).click();

  await expect(page.getByText('请先登录后查看会话。')).toBeVisible();
});

test('Web Admin searches and revokes another user session as admin', async ({ page }) => {
  let managedListCalls = 0;
  let revokedSessionId: string | null = null;

  await mockProfile(page);
  await mockBootstrapRefresh(page);
  await page.route('**/v1/auth/sessions', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ items: [] }),
    });
  });
  await page.route('**/api/admin/v1/auth-sessions**', async (route) => {
    if (route.request().method() !== 'GET') return route.fallback();
    managedListCalls += 1;
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        items: [
          {
            id: 'target-web-session',
            userId: 'target-user-1',
            clientType: 'web_admin',
            deviceId: 'target-browser',
            deviceName: 'Target Chrome',
            platform: 'web',
            appVersion: null,
            userAgent: 'Target Browser',
            ipAddressMasked: '172***0.5',
            createdAt: '2026-05-16T07:00:00.000Z',
            lastUsedAt: '2026-05-16T09:10:00.000Z',
            expiresAt: '2026-05-16T19:00:00.000Z',
            idleExpiresAt: '2026-05-16T09:40:00.000Z',
            absoluteExpiresAt: '2026-05-16T19:00:00.000Z',
            revokedAt: managedListCalls > 1 ? '2026-05-16T09:20:00.000Z' : null,
            isCurrent: false,
            user: {
              id: 'target-user-1',
              username: 'target',
              displayName: 'Target User',
              email: 'target@example.com',
              role: 'user',
            },
          },
        ],
      }),
    });
  });
  await page.route('**/api/admin/v1/auth-sessions/target-web-session/revoke', async (route) => {
    revokedSessionId = 'target-web-session';
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ success: true, sessionId: 'target-web-session', targetUserId: 'target-user-1' }),
    });
  });

  page.on('dialog', (dialog) => dialog.accept());
  await page.goto('/admin/auth-sessions');

  await expect(page.getByRole('heading', { name: '用户会话检索与踢下线' })).toBeVisible();
  await page.getByPlaceholder('邮箱 / 用户名 / 昵称').fill('target@example.com');
  await page.getByRole('button', { name: '查询' }).click();
  await expect(page.getByText('target@example.com')).toBeVisible();
  await expect(page.getByText('Target Chrome')).toBeVisible();
  await page.getByRole('button', { name: '踢下线' }).click();

  await expect(page.getByText('用户会话已撤销')).toBeVisible();
  await expect(page.getByText('已撤销', { exact: true })).toBeVisible();
  expect(revokedSessionId).toBe('target-web-session');
});

test('Web Admin requires password reauth before creating account enforcement', async ({ page }) => {
  let createRequestProof: string | null = null;

  await mockProfile(page);
  await mockBootstrapRefresh(page);
  await page.route('**/api/admin/v1/account-enforcements**', async (route) => {
    if (route.request().method() === 'GET') {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ success: true, items: [] }),
      });
      return;
    }
    return route.fallback();
  });
  await page.route('**/api/admin/v1/enforcement-appeals**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ success: true, items: [] }),
    });
  });
  await page.route('**/v1/auth/reauth', async (route) => {
    const body = route.request().postDataJSON() as { password?: string; scope?: string };
    expect(body).toEqual({ password: 'admin-password', scope: 'account_enforcement.write' });
    expect(route.request().headers().authorization).toBe('Bearer bootstrap-token');
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        reauthProof: 'reauth-proof-token',
        expiresInSeconds: 600,
        scope: 'account_enforcement.write',
      }),
    });
  });
  await page.route('**/api/admin/v1/users/target-user-1/enforcements', async (route) => {
    createRequestProof = route.request().headers()['x-raver-reauth-proof'] || null;
    await route.fulfill({
      status: 201,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        enforcement: {
          id: 'enforcement-1',
          userId: 'target-user-1',
          status: 'active',
          type: 'suspension',
          scopes: ['message_send', 'comment_create'],
          reasonCode: 'harassment',
          internalNote: null,
          startsAt: '2026-05-16T09:00:00.000Z',
          endsAt: '2026-05-23T09:00:00.000Z',
          createdBy: 'admin-user-1',
          createdFromReportId: null,
          createdFromCaseId: null,
          revokedAt: null,
          revokedBy: null,
          revocationReason: null,
          createdAt: '2026-05-16T09:00:00.000Z',
          updatedAt: '2026-05-16T09:00:00.000Z',
        },
      }),
    });
  });

  await page.goto('/admin/account-enforcements');
  await page.getByLabel('用户 ID').fill('target-user-1');
  await page.getByRole('button', { name: '创建临时封禁' }).click();

  await expect(page.getByRole('heading', { name: '安全复验' })).toBeVisible();
  await page.getByLabel('密码').fill('admin-password');
  await page.getByRole('button', { name: '确认继续' }).click();

  await expect(page.getByText('处罚已创建')).toBeVisible();
  expect(createRequestProof).toBe('reauth-proof-token');
});

test('Web Admin requires password reauth before retrying account deletion', async ({ page }) => {
  let retryRequestProof: string | null = null;

  await mockProfile(page);
  await mockBootstrapRefresh(page);
  await page.route('**/api/admin/v1/account-deletions**', async (route) => {
    if (route.request().method() !== 'GET') return route.fallback();
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        items: [
          {
            id: 'request-1',
            userId: 'target-user-1',
            status: 'partial_failed',
            requestedBy: 'user',
            requestSource: 'settings',
            originalEmailHash: null,
            originalPhoneHash: null,
            previousAvatarUrl: null,
            previousProfileQrUrl: null,
            imUserId: 'im-target-user-1',
            imStatus: 'failed',
            imAttempts: 1,
            imNextRunAt: '2026-05-16T10:00:00.000Z',
            imLastError: 'IM deletion failed',
            mediaStatus: 'completed',
            mediaAttempts: 1,
            mediaNextRunAt: '2026-05-16T10:00:00.000Z',
            mediaLastError: null,
            mediaTargets: { objectKeys: ['avatars/target-user-1.png'], sourceUrls: [] },
            completedAt: null,
            createdAt: '2026-05-16T09:00:00.000Z',
            updatedAt: '2026-05-16T09:05:00.000Z',
          },
        ],
      }),
    });
  });
  await page.route('**/v1/auth/reauth', async (route) => {
    const body = route.request().postDataJSON() as { password?: string; scope?: string };
    expect(body).toEqual({ password: 'admin-password', scope: 'account_deletion.write' });
    expect(route.request().headers().authorization).toBe('Bearer bootstrap-token');
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        reauthProof: 'account-deletion-reauth-proof',
        expiresInSeconds: 600,
        scope: 'account_deletion.write',
      }),
    });
  });
  await page.route('**/api/admin/v1/account-deletions/request-1/retry', async (route) => {
    retryRequestProof = route.request().headers()['x-raver-reauth-proof'] || null;
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        request: {
          id: 'request-1',
          userId: 'target-user-1',
          status: 'completed',
          requestedBy: 'user',
          requestSource: 'settings',
          originalEmailHash: null,
          originalPhoneHash: null,
          previousAvatarUrl: null,
          previousProfileQrUrl: null,
          imUserId: 'im-target-user-1',
          imStatus: 'completed',
          imAttempts: 2,
          imNextRunAt: '2026-05-16T10:00:00.000Z',
          imLastError: null,
          mediaStatus: 'completed',
          mediaAttempts: 1,
          mediaNextRunAt: '2026-05-16T10:00:00.000Z',
          mediaLastError: null,
          mediaTargets: { objectKeys: ['avatars/target-user-1.png'], sourceUrls: [] },
          completedAt: '2026-05-16T09:10:00.000Z',
          createdAt: '2026-05-16T09:00:00.000Z',
          updatedAt: '2026-05-16T09:10:00.000Z',
        },
      }),
    });
  });

  await page.goto('/admin/account-deletions');
  await expect(page.getByRole('heading', { name: '账号删除请求' })).toBeVisible();
  await page.getByRole('button', { name: '重试' }).click();

  await expect(page.getByRole('heading', { name: '安全复验' })).toBeVisible();
  await page.getByLabel('密码').fill('admin-password');
  await page.getByRole('button', { name: '确认继续' }).click();

  await expect(page.getByText('已触发重试')).toBeVisible();
  expect(retryRequestProof).toBe('account-deletion-reauth-proof');
});
