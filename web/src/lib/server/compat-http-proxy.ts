const apiBase = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3901/api';
export const backendOrigin = apiBase.replace(/\/api\/?$/, '');
export const upstreamProxyTimeoutMs = (() => {
  const parsed = Number(process.env.NEXT_UPSTREAM_PROXY_TIMEOUT_MS || 15_000);
  if (Number.isFinite(parsed) && parsed > 0) {
    return Math.floor(parsed);
  }
  return 15_000;
})();

const hopByHopHeaders = new Set([
  'connection',
  'content-length',
  'host',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
]);

export const copyRequestHeaders = (request: Request): Headers => {
  const headers = new Headers();
  for (const [key, value] of request.headers.entries()) {
    if (hopByHopHeaders.has(key.toLowerCase())) continue;
    headers.set(key, value);
  }
  return headers;
};

export const forwardUpstreamResponse = async (response: Response): Promise<Response> => {
  const body = await response.arrayBuffer();
  const headers = new Headers();
  for (const [key, value] of response.headers.entries()) {
    if (hopByHopHeaders.has(key.toLowerCase())) continue;
    headers.set(key, value);
  }
  headers.set('Cache-Control', 'no-store');
  return new Response(body, {
    status: response.status,
    headers,
  });
};

export const proxyRequestToUpstream = async (
  request: Request,
  upstreamUrl: string,
  methodOverride?: string
): Promise<Response> => {
  const method = (methodOverride || request.method || 'GET').toUpperCase();
  const headers = copyRequestHeaders(request);
  const init: RequestInit = {
    method,
    headers,
    redirect: 'manual',
  };

  if (method !== 'GET' && method !== 'HEAD') {
    const body = await request.arrayBuffer();
    init.body = body;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), upstreamProxyTimeoutMs);
  init.signal = controller.signal;

  let upstream: Response;
  try {
    upstream = await fetch(upstreamUrl, init);
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
    return Response.json(
      {
        ok: false,
        error: `Upstream request failed: ${message}`,
      },
      { status: 502 }
    );
  }
  clearTimeout(timeout);

  return forwardUpstreamResponse(upstream);
};
