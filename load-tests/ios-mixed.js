import { check, group, sleep } from 'k6';
import exec from 'k6/execution';
import { defaultThresholds, profileOptions } from './lib/config.js';
import { expectOk, maybeJson, request } from './lib/http.js';
import { handleSummary } from './lib/summary.js';

export const options = {
  ...profileOptions('baseline'),
  thresholds: {
    ...defaultThresholds,
    'http_req_duration{surface:health}': ['p(95)<150'],
    'http_req_duration{surface:auth}': ['p(95)<800'],
    'http_req_duration{surface:feed}': ['p(95)<700'],
  },
};

const authUser = __ENV.LOAD_AUTH_USER || '';
const authPassword = __ENV.LOAD_AUTH_PASSWORD || '';
const allowRegister = ['1', 'true', 'yes', 'on'].includes(String(__ENV.LOAD_REGISTER_USERS || '').toLowerCase());

function newIdentity() {
  const suffix = `${Date.now()}_${Math.floor(Math.random() * 100000)}_${exec.vu.idInTest}`;
  return {
    username: `k6_${suffix}`,
    email: `k6_${suffix}@example.com`,
    password: 'Passw0rd!',
    displayName: `k6_${suffix}`,
    birthYear: 1998,
    regionCode: 'JP',
  };
}

function extractToken(body) {
  return body?.accessToken || body?.token || '';
}

export function setup() {
  if (authUser && authPassword) {
    const login = request(
      'POST',
      '/v1/auth/login',
      { identifier: authUser, password: authPassword },
      { tags: { surface: 'auth', action: 'setup_login' } }
    );
    const body = maybeJson(login, {});
    check(login, {
      'setup login status ok': (r) => r.status === 200,
      'setup login returned token': () => Boolean(extractToken(body)),
    });
    return { token: extractToken(body), authenticated: Boolean(extractToken(body)) };
  }

  if (allowRegister) {
    const identity = newIdentity();
    const register = request('POST', '/v1/auth/register', identity, {
      tags: { surface: 'auth', action: 'setup_register' },
    });
    const body = maybeJson(register, {});
    check(register, {
      'setup register status ok': (r) => r.status === 201 || r.status === 200,
      'setup register returned token': () => Boolean(extractToken(body)),
    });
    return { token: extractToken(body), authenticated: Boolean(extractToken(body)) };
  }

  return { token: '', authenticated: false };
}

function publicBrowse() {
  group('public browse', () => {
    expectOk(request('GET', '/health', undefined, { tags: { surface: 'health' } }), 'health');
    expectOk(request('GET', '/api/events?limit=20', undefined, { tags: { surface: 'events' } }), 'events list');
    expectOk(request('GET', '/api/djs?limit=20', undefined, { tags: { surface: 'djs' } }), 'djs list');
    expectOk(request('GET', '/v1/feed?limit=20', undefined, { tags: { surface: 'feed' } }), 'feed');
    expectOk(request('GET', '/v1/feed/search?q=music', undefined, { tags: { surface: 'search' } }), 'feed search');
  });
}

function authenticatedBrowse(token) {
  group('authenticated iOS flow', () => {
    expectOk(request('GET', '/v1/profile/me', undefined, { token, tags: { surface: 'profile' } }), 'profile me');
    expectOk(request('GET', '/v1/notifications/unread-count', undefined, { token, tags: { surface: 'notifications' } }), 'unread count');
    expectOk(
      request('GET', '/v1/notification-center/inbox?limit=20', undefined, { token, tags: { surface: 'notifications' } }),
      'notification inbox'
    );
    expectOk(request('GET', '/v1/squads/recommended?limit=10', undefined, { token, tags: { surface: 'squads' } }), 'recommended squads');
    expectOk(request('GET', '/v1/me/virtual-assets', undefined, { token, tags: { surface: 'virtual_assets' } }), 'my virtual assets');
  });
}

function lightWrites(token) {
  group('light writes', () => {
    const profilePatch = request(
      'PATCH',
      '/v1/profile/me',
      { bio: `k6 capacity probe ${Date.now()}` },
      { token, tags: { surface: 'profile', write: 'true' } }
    );
    expectOk(profilePatch, 'profile patch');

    const markRead = request(
      'POST',
      '/v1/notifications/read',
      { ids: [] },
      { token, tags: { surface: 'notifications', write: 'true' } }
    );
    expectOk(markRead, 'notifications read');
  });
}

export default function (state) {
  publicBrowse();

  if (state.authenticated && state.token) {
    authenticatedBrowse(state.token);

    if (exec.scenario.iterationInTest % 10 === 0) {
      lightWrites(state.token);
    }
  }

  sleep(Math.random() * 2 + 0.5);
}

export { handleSummary };
