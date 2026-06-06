import { NextResponse } from 'next/server';

export const runtime = 'nodejs';

type TestCheck = {
  label: string;
  ok: boolean;
  detail: string;
};

const ensureAdmin = async (request: Request): Promise<NextResponse | null> => {
  const authorization = request.headers.get('authorization') || '';
  const token = authorization.match(/^Bearer\s+(.+)$/i)?.[1]?.trim() || '';
  if (!token) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const profileResponse = await fetch('http://127.0.0.1:3901/v1/profile/me', {
    headers: {
      Authorization: `Bearer ${token}`,
    },
    cache: 'no-store',
  }).catch(() => null);

  if (!profileResponse || !profileResponse.ok) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const profile = (await profileResponse.json().catch(() => null)) as { role?: string } | null;
  if (profile?.role !== 'admin') {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  return null;
};

const testCozeEndpoint = async (label: string, runUrl: string, token: string): Promise<TestCheck[]> => {
  const checks: TestCheck[] = [];
  const trimmedRunUrl = String(runUrl || '').trim();
  const trimmedToken = String(token || '').trim();

  if (!trimmedRunUrl) {
    checks.push({ label: `${label} URL`, ok: false, detail: '未配置' });
  } else {
    try {
      new URL(trimmedRunUrl);
      checks.push({ label: `${label} URL`, ok: true, detail: trimmedRunUrl });
    } catch {
      checks.push({ label: `${label} URL`, ok: false, detail: 'URL 格式无效' });
    }
  }

  if (!trimmedToken) {
    checks.push({ label: `${label} Token`, ok: false, detail: '未配置' });
  } else {
    checks.push({
      label: `${label} Token`,
      ok: true,
      detail: `已填写，长度 ${trimmedToken.length}`,
    });
  }

  if (!trimmedRunUrl || !trimmedToken) {
    return checks;
  }

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    const response = await fetch(trimmedRunUrl, {
      method: 'OPTIONS',
      headers: {
        Authorization: `Bearer ${trimmedToken}`,
      },
      signal: controller.signal,
    }).catch(async () => {
      return fetch(trimmedRunUrl, {
        method: 'HEAD',
        headers: {
          Authorization: `Bearer ${trimmedToken}`,
        },
        signal: controller.signal,
      });
    });
    clearTimeout(timeout);
    checks.push({
      label: `${label} 连通性`,
      ok: response.status < 500,
      detail: `HTTP ${response.status}`,
    });
  } catch (error) {
    const detail =
      error instanceof Error && error.name === 'AbortError'
        ? '请求超时'
        : error instanceof Error
          ? error.message
          : '未知错误';
    checks.push({
      label: `${label} 连通性`,
      ok: false,
      detail,
    });
  }

  return checks;
};

export async function POST(request: Request) {
  const guard = await ensureAdmin(request);
  if (guard) return guard;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  const payload = body && typeof body === 'object' && !Array.isArray(body) ? body as {
    sectionId?: unknown;
    values?: Record<string, unknown>;
  } : null;

  const sectionId = typeof payload?.sectionId === 'string' ? payload.sectionId.trim() : '';
  const values = payload?.values && typeof payload.values === 'object' && !Array.isArray(payload.values)
    ? payload.values
    : {};

  if (!sectionId) {
    return NextResponse.json({ error: 'sectionId is required' }, { status: 400 });
  }

  const readValue = (key: string) => String(values[key] ?? '').trim();
  let checks: TestCheck[] = [];

  if (sectionId === 'coze-workflows') {
    checks = [
      ...(await testCozeEndpoint('Timetable', readValue('COZE_TIMETABLE_WORKFLOW_RUN_URL'), readValue('COZE_TIMETABLE_WORKFLOW_TOKEN'))),
      ...(await testCozeEndpoint('Lineup', readValue('COZE_LINEUP_WORKFLOW_RUN_URL'), readValue('COZE_LINEUP_WORKFLOW_TOKEN'))),
      ...(await testCozeEndpoint('Poster', readValue('COZE_POSTER_WORKFLOW_RUN_URL'), readValue('COZE_POSTER_WORKFLOW_TOKEN'))),
    ];
  } else if (sectionId === 'coze-web-tools') {
    checks = [
      ...(await testCozeEndpoint('Festival Translate', readValue('COZE_TRANSLATE_RUN_URL'), readValue('COZE_TOKEN_TRANSLATE'))),
      ...(await testCozeEndpoint('DJ Translate', readValue('COZE_DJ_TRANS_RUN_URL'), readValue('COZE_DJ_TRANS_TOKEN'))),
      ...(await testCozeEndpoint('Location Normalize', readValue('COZE_LOCATION_NORMALIZE_RUN_URL'), readValue('COZE_LOCATION_NORMALIZE_TOKEN'))),
    ];
  } else if (sectionId === 'coze-shared') {
    checks = [
      ...(await testCozeEndpoint('DJ Enrich', readValue('COZE_DJ_ENRICH_RUN_URL'), readValue('COZE_DJ_ENRICH_TOKEN'))),
      {
        label: 'Public Base URL',
        ok: Boolean(readValue('COZE_PUBLIC_BASE_URL')),
        detail: readValue('COZE_PUBLIC_BASE_URL') || '未配置',
      },
      {
        label: 'OSS Accelerate Base URL',
        ok: Boolean(readValue('COZE_OSS_ACCELERATE_BASE_URL')),
        detail: readValue('COZE_OSS_ACCELERATE_BASE_URL') || '未配置',
      },
    ];
  } else {
    return NextResponse.json({ error: 'Unknown sectionId' }, { status: 400 });
  }

  const ok = checks.every((item) => item.ok);
  return NextResponse.json({
    sectionId,
    ok,
    checkedAt: new Date().toISOString(),
    message: ok ? '测试通过' : '存在需要处理的配置项',
    checks,
  }, {
    headers: { 'Cache-Control': 'no-store' },
  });
}

