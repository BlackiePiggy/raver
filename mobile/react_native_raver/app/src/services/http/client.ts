import { appEnv } from '../../app/config/env';
import { createAppError } from './errors';

type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

type RequestOptions = {
  method?: HttpMethod;
  body?: unknown;
  headers?: Record<string, string>;
  signal?: AbortSignal;
  token?: string | null;
};

export async function requestJson<T>(
  path: string,
  options: RequestOptions = {},
): Promise<T> {
  const response = await request(path, options);
  return parseJsonResponse<T>(response);
}

export async function request(
  path: string,
  options: RequestOptions = {},
): Promise<Response> {
  const url = buildURL(path);
  const headers = buildHeaders(options);

  try {
    const response = await fetch(url, {
      body: options.body === undefined ? undefined : JSON.stringify(options.body),
      headers,
      method: options.method ?? 'GET',
      signal: options.signal,
    });

    if (!response.ok) {
      throw createAppError({
        code: 'http_error',
        message: `Request failed with status ${response.status}.`,
        retryable: response.status >= 500,
        status: response.status,
      });
    }

    return response;
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw error;
    }

    if (typeof error === 'object' && error !== null && 'code' in error) {
      throw error;
    }

    throw createAppError({
      code: 'network_error',
      message: error instanceof Error ? error.message : 'Network request failed.',
      retryable: true,
    });
  }
}

async function parseJsonResponse<T>(response: Response): Promise<T> {
  try {
    const text = await response.text();
    if (text.length === 0) {
      return undefined as T;
    }
    return JSON.parse(text) as T;
  } catch (error) {
    throw createAppError({
      code: 'parse_error',
      message: error instanceof Error ? error.message : 'Unable to parse response.',
      retryable: false,
      status: response.status,
    });
  }
}

function buildURL(path: string): string {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }

  const baseURL = appEnv.bffBaseURL.replace(/\/$/, '');
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  return `${baseURL}${normalizedPath}`;
}

function buildHeaders(options: RequestOptions): Record<string, string> {
  const headers: Record<string, string> = {
    Accept: 'application/json',
    ...options.headers,
  };

  if (options.body !== undefined) {
    headers['Content-Type'] = 'application/json';
  }

  if (options.token) {
    headers.Authorization = `Bearer ${options.token}`;
  }

  return headers;
}
