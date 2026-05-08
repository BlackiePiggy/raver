import 'dotenv/config';
import axios, { type Method } from 'axios';

type ShareLinkBody = {
  code?: string;
  shortUrl?: string;
  canonicalUrl?: string;
  deepLink?: string;
  qrCodeUrl?: string;
  title?: string;
  status?: string;
};

type ErrorBody = {
  error?: string;
  message?: string;
};

const apiBaseUrl = (process.env.SHARE_LINK_SMOKE_API_BASE_URL || 'http://127.0.0.1:3901/v1').replace(/\/+$/, '');
const publicBaseUrl = (process.env.SHARE_LINK_SMOKE_PUBLIC_BASE_URL || 'http://127.0.0.1:3901').replace(/\/+$/, '');
const targetType = (process.env.SHARE_LINK_SMOKE_TARGET_TYPE || '').trim();
const targetId = (process.env.SHARE_LINK_SMOKE_TARGET_ID || '').trim();
const existingCode = (process.env.SHARE_LINK_SMOKE_CODE || '').trim();
const authToken = (process.env.SHARE_LINK_SMOKE_AUTH_TOKEN || '').trim();

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const describeFailure = (label: string, status: number, data: unknown): string => {
  const body = data as ErrorBody;
  const error = body?.error ? ` error=${body.error}` : '';
  const message = body?.message ? ` message=${body.message}` : '';
  const migrationHint = status === 500
    ? ' Hint: if this is a fresh local database, run `npx prisma migrate dev --schema prisma/schema.prisma` and restart the server.'
    : '';
  return `${label} expected 200 but got ${status}.${error}${message}${migrationHint}`;
};

const apiUrl = (path: string): string => `${apiBaseUrl}${path.startsWith('/') ? path : `/${path}`}`;
const publicUrl = (path: string): string => `${publicBaseUrl}${path.startsWith('/') ? path : `/${path}`}`;

const request = async <T>(
  method: Method,
  url: string,
  body?: unknown,
  options?: { redirects?: number; responseType?: 'arraybuffer' | 'json' | 'text' }
): Promise<{ status: number; data: T; headers: Record<string, unknown> }> => {
  const response = await axios.request<T>({
    method,
    url,
    data: body,
    maxRedirects: options?.redirects ?? 0,
    responseType: options?.responseType,
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': 'RaverShareLinkSmoke/1.0',
      ...(authToken ? { Authorization: `Bearer ${authToken}` } : {}),
    },
    validateStatus: () => true,
  });
  return {
    status: response.status,
    data: response.data,
    headers: response.headers as Record<string, unknown>,
  };
};

const resolveOrUseExistingCode = async (): Promise<string> => {
  if (existingCode) return existingCode;

  assert(Boolean(targetType), 'Set SHARE_LINK_SMOKE_TARGET_TYPE or SHARE_LINK_SMOKE_CODE');
  assert(Boolean(targetId), 'Set SHARE_LINK_SMOKE_TARGET_ID or SHARE_LINK_SMOKE_CODE');

  const response = await request<ShareLinkBody>('POST', apiUrl('/share-links/resolve'), {
    targetType,
    targetId,
    channel: 'smoke',
    campaign: 'share_link_smoke',
    preferPermanent: true,
  }, { redirects: 0, responseType: 'json' });

  assert(response.status === 200, describeFailure('resolve', response.status, response.data));
  assert(Boolean(response.data.code), 'resolve response missing code');
  assert(Boolean(response.data.shortUrl?.includes('/s/')), 'resolve response missing shortUrl');
  console.log('[share-link-smoke] resolve ok', {
    code: response.data.code,
    shortUrl: response.data.shortUrl,
    title: response.data.title,
  });

  return String(response.data.code);
};

const main = async (): Promise<void> => {
  console.log('[share-link-smoke] start', {
    apiBaseUrl,
    publicBaseUrl,
    targetType: targetType || null,
    targetId: targetId || null,
    existingCode: existingCode || null,
  });

  const code = await resolveOrUseExistingCode();

  const detail = await request<ShareLinkBody>('GET', apiUrl(`/share-links/${encodeURIComponent(code)}`), undefined, {
    redirects: 0,
    responseType: 'json',
  });
  assert(detail.status === 200, describeFailure('detail', detail.status, detail.data));
  assert(detail.data.code === code, `detail code expected ${code} but got ${String(detail.data.code)}`);
  assert(Boolean(detail.data.deepLink), 'detail response missing deepLink');
  console.log('[share-link-smoke] detail ok', {
    code: detail.data.code,
    deepLink: detail.data.deepLink,
    status: detail.data.status,
  });

  const landing = await request<string>('GET', publicUrl(`/s/${encodeURIComponent(code)}`), undefined, {
    redirects: 0,
    responseType: 'text',
  });
  assert(landing.status === 200, `landing expected 200 but got ${landing.status}`);
  assert(String(landing.data).includes('og:title'), 'landing missing og:title');
  assert(String(landing.data).includes(`/s/${code}/open`), 'landing missing open app link');
  console.log('[share-link-smoke] landing ok', { status: landing.status });

  const open = await request<string>('GET', publicUrl(`/s/${encodeURIComponent(code)}/open`), undefined, {
    redirects: 0,
    responseType: 'text',
  });
  assert(open.status >= 300 && open.status < 400, `open expected redirect but got ${open.status}`);
  const openLocation = String(open.headers.location || '');
  assert(openLocation.startsWith('raver://') || openLocation.startsWith('https://'), 'open redirect location is invalid');
  assert(openLocation.includes('shareCode='), 'open redirect missing shareCode');
  console.log('[share-link-smoke] open redirect ok', {
    status: open.status,
    location: openLocation,
  });

  const qr = await request<Buffer>('GET', publicUrl(`/qr/${encodeURIComponent(code)}.png`), undefined, {
    redirects: 0,
    responseType: 'arraybuffer',
  });
  assert(qr.status === 200, `qr expected 200 but got ${qr.status}`);
  assert(String(qr.headers['content-type'] || '').includes('image/png'), 'qr response is not PNG');
  console.log('[share-link-smoke] qr ok', {
    status: qr.status,
    contentType: qr.headers['content-type'],
  });

  const poster = await request<Buffer>('GET', publicUrl(`/poster/${encodeURIComponent(code)}.png`), undefined, {
    redirects: 0,
    responseType: 'arraybuffer',
  });
  assert(poster.status === 200, `poster expected 200 but got ${poster.status}`);
  assert(String(poster.headers['content-type'] || '').includes('image/png'), 'poster response is not PNG');
  assert(Buffer.from(poster.data).length > 1024, 'poster PNG is unexpectedly small');
  console.log('[share-link-smoke] poster ok', {
    status: poster.status,
    contentType: poster.headers['content-type'],
  });

  console.log('[share-link-smoke] all checks passed');
};

main().catch((error) => {
  console.error('[share-link-smoke] failed', error);
  process.exitCode = 1;
});
