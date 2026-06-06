import { authenticatedFetch } from '@/lib/auth/authenticated-fetch';

export type UploadedMediaResult = {
  url: string;
  originalUrl: string | null;
  fileName: string | null;
  mimeType: string | null;
};

type UploadFetchLike = (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;
type UploadFieldValue = string | number | boolean | null | undefined;

const parseJsonSafe = async (response: Response): Promise<unknown> => {
  try {
    return await response.json();
  } catch {
    return null;
  }
};

const unwrapMaybeEnvelope = (payload: unknown): unknown => {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) return payload;
  const row = payload as { data?: unknown };
  return row.data !== undefined ? row.data : payload;
};

export const normalizeUploadedMediaPayload = (
  payload: unknown,
  invalidResponseError = '上传成功但未返回有效图片地址'
): UploadedMediaResult => {
  const unwrapped = unwrapMaybeEnvelope(payload);
  if (!unwrapped || typeof unwrapped !== 'object' || Array.isArray(unwrapped)) {
    throw new Error(invalidResponseError);
  }

  const row = unwrapped as Record<string, unknown>;
  const url = typeof row.url === 'string' ? row.url.trim() : '';
  if (!url) {
    throw new Error(invalidResponseError);
  }

  return {
    url,
    originalUrl: typeof row.originalUrl === 'string' ? row.originalUrl.trim() : null,
    fileName:
      typeof row.fileName === 'string'
        ? row.fileName.trim()
        : typeof row.filename === 'string'
          ? row.filename.trim()
          : null,
    mimeType: typeof row.mimeType === 'string' ? row.mimeType.trim() : null,
  };
};

export const parseUploadedMediaResponse = async (
  response: Response,
  fallbackError = '图片上传失败',
  invalidResponseError = '上传成功但未返回有效图片地址'
): Promise<UploadedMediaResult> => {
  const payload = await parseJsonSafe(response);
  if (!response.ok) {
    const error =
      payload && typeof payload === 'object' && !Array.isArray(payload)
        ? (payload as { error?: string; message?: string })
        : null;
    throw new Error(error?.error || error?.message || fallbackError);
  }
  return normalizeUploadedMediaPayload(payload, invalidResponseError);
};

export const uploadMediaWithFetcher = async ({
  url,
  file,
  fields,
  fileField = 'image',
  fetcher = authenticatedFetch,
  fallbackError = '图片上传失败',
  invalidResponseError = '上传成功但未返回有效图片地址',
  init,
}: {
  url: string;
  file: File;
  fields?: Record<string, UploadFieldValue>;
  fileField?: string;
  fetcher?: UploadFetchLike;
  fallbackError?: string;
  invalidResponseError?: string;
  init?: Omit<RequestInit, 'method' | 'body'>;
}): Promise<UploadedMediaResult> => {
  const formData = new FormData();
  formData.append(fileField, file);
  Object.entries(fields || {}).forEach(([key, value]) => {
    if (value === undefined || value === null) return;
    formData.append(key, String(value));
  });

  const response = await fetcher(url, {
    ...init,
    method: 'POST',
    body: formData,
    headers: {},
  });

  return parseUploadedMediaResponse(response, fallbackError, invalidResponseError);
};
