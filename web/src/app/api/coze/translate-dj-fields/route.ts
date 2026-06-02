import { NextResponse } from 'next/server';
import { runCozeDjFieldTranslate } from '@/lib/server/coze-translate';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return NextResponse.json({ ok: false, error: 'Invalid JSON body' }, { status: 400 });
  }

  const fields =
    payload && typeof payload === 'object' && !Array.isArray(payload)
      ? (payload as Record<string, unknown>).fields
      : null;

  try {
    const result = await runCozeDjFieldTranslate(fields);
    return NextResponse.json(
      {
        ok: true,
        translated: result.translated,
        raw_response: result.raw,
      },
      { headers: { 'Cache-Control': 'no-store' } }
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    const status =
      message === 'fields.country or fields.bio is required'
        ? 400
        : message.includes('not configured')
          ? 503
          : 502;
    return NextResponse.json({ ok: false, error: message }, { status });
  }
}
