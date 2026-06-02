import {
  backendOrigin,
  copyRequestHeaders,
  forwardUpstreamResponse,
  proxyRequestToUpstream,
  upstreamProxyTimeoutMs,
} from '@/lib/server/compat-http-proxy';

export const runtime = 'nodejs';

type RouteContext = {
  params: Promise<{
    path: string[];
  }>;
};

const toSearch = (request: Request): string => {
  const url = new URL(request.url);
  return url.search || '';
};

const buildEventYearsFallback = async (request: Request): Promise<Response> => {
  const headers = copyRequestHeaders(request);
  const counts = new Map<number, number>();
  let page = 1;
  let totalPages = 1;
  while (page <= totalPages && page <= 500) {
    const query = new URLSearchParams({
      page: String(page),
      limit: '100',
      status: 'all',
    });
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), upstreamProxyTimeoutMs);
    let response: Response;
    try {
      response = await fetch(`${backendOrigin}/v1/events?${query.toString()}`, {
        method: 'GET',
        headers,
        redirect: 'manual',
        signal: controller.signal,
      });
    } catch (error) {
      clearTimeout(timeout);
      if (error instanceof Error && error.name === 'AbortError') {
        return Response.json(
          {
            ok: false,
            error: `Upstream request timed out after ${upstreamProxyTimeoutMs}ms`,
          },
          { status: 504 }
        );
      }
      const message = error instanceof Error ? error.message : 'Unknown upstream error';
      return Response.json({ ok: false, error: `Upstream request failed: ${message}` }, { status: 502 });
    }
    clearTimeout(timeout);
    if (!response.ok) {
      return forwardUpstreamResponse(response);
    }
    const payload = (await response.json()) as Record<string, unknown>;
    const data = payload.data && typeof payload.data === 'object' ? (payload.data as Record<string, unknown>) : {};
    const items = Array.isArray(data.items)
      ? (data.items as Array<Record<string, unknown>>)
      : Array.isArray(payload.events)
        ? (payload.events as Array<Record<string, unknown>>)
        : [];
    for (const item of items) {
      const startDate = String(item.startDate || '').trim();
      const match = startDate.match(/^(\d{4})/);
      if (!match) continue;
      const year = Number(match[1]);
      counts.set(year, (counts.get(year) || 0) + 1);
    }
    const pagination =
      payload.pagination && typeof payload.pagination === 'object'
        ? (payload.pagination as Record<string, unknown>)
        : {};
    totalPages = Number(pagination.totalPages || totalPages || 1);
    page += 1;
  }
  return Response.json({
    years: [...counts.entries()]
      .sort((a, b) => b[0] - a[0])
      .map(([year, count]) => ({ year, count })),
  });
};

const resolveLegacyCompat = (request: Request, rawPath: string) => {
  let method = request.method.toUpperCase();
  let normalizedPath = rawPath.replace(/^\/+/, '');

  if (method === 'POST' && normalizedPath.endsWith('/delete')) {
    method = 'DELETE';
    normalizedPath = normalizedPath.slice(0, -'/delete'.length);
  } else if (method === 'POST' && normalizedPath.endsWith('/update')) {
    method = 'PATCH';
    normalizedPath = normalizedPath.slice(0, -'/update'.length);
  }

  return {
    method,
    upstreamPath: `/v1/${normalizedPath}${toSearch(request)}`,
    normalizedPath,
  };
};

async function handleRequest(request: Request, context: RouteContext) {
  const { path } = await context.params;
  const rawPath = path.join('/');
  const { method, upstreamPath, normalizedPath } = resolveLegacyCompat(request, rawPath);
  const upstreamUrl = `${backendOrigin}${upstreamPath}`;

  if (method === 'GET' && normalizedPath === 'events/years') {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), upstreamProxyTimeoutMs);
    try {
      const response = await fetch(upstreamUrl, {
        method: 'GET',
        headers: copyRequestHeaders(request),
        redirect: 'manual',
        signal: controller.signal,
      });
      clearTimeout(timeout);
      if (response.status === 404) {
        return buildEventYearsFallback(request);
      }
      return forwardUpstreamResponse(response);
    } catch (error) {
      clearTimeout(timeout);
      if (error instanceof Error && error.name === 'AbortError') {
        return Response.json(
          {
            ok: false,
            error: `Upstream request timed out after ${upstreamProxyTimeoutMs}ms`,
          },
          { status: 504 }
        );
      }
      const message = error instanceof Error ? error.message : 'Unknown upstream error';
      return Response.json({ ok: false, error: `Upstream request failed: ${message}` }, { status: 502 });
    }
  }

  return proxyRequestToUpstream(request, upstreamUrl, method);
}

export async function GET(request: Request, context: RouteContext) {
  return handleRequest(request, context);
}

export async function POST(request: Request, context: RouteContext) {
  return handleRequest(request, context);
}

export async function PATCH(request: Request, context: RouteContext) {
  return handleRequest(request, context);
}

export async function DELETE(request: Request, context: RouteContext) {
  return handleRequest(request, context);
}
