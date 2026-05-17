import http from 'k6/http';
import { check } from 'k6';
import { Counter, Rate } from 'k6/metrics';
import { BASE_URL } from './config.js';

export const apiErrors = new Counter('raver_api_errors');
export const apiOkRate = new Rate('raver_api_ok_rate');

export function jsonHeaders(token) {
  return {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
}

export function apiUrl(path) {
  return `${BASE_URL}${path.startsWith('/') ? path : `/${path}`}`;
}

export function request(method, path, body, params = {}) {
  const response = http.request(method, apiUrl(path), body === undefined ? null : JSON.stringify(body), {
    timeout: params.timeout || '15s',
    tags: {
      endpoint: path.replace(/[0-9a-fA-F-]{24,}/g, ':id'),
      ...(params.tags || {}),
    },
    headers: {
      ...jsonHeaders(params.token),
      ...(params.headers || {}),
    },
  });

  const ok = response.status >= 200 && response.status < 400;
  apiOkRate.add(ok);
  if (!ok) apiErrors.add(1);
  return response;
}

export function expectOk(response, label, extra = {}) {
  return check(response, {
    [`${label}: status 2xx/3xx`]: (r) => r.status >= 200 && r.status < 400,
    ...extra,
  });
}

export function maybeJson(response, fallback = null) {
  try {
    return response.json();
  } catch (_error) {
    return fallback;
  }
}
