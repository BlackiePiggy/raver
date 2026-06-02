import { NextResponse } from 'next/server';
import { runCozeFestivalTranslate } from '@/lib/server/coze-translate';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return NextResponse.json({ ok: false, error: 'Invalid JSON body' }, { status: 400 });
  }

  const festival =
    payload && typeof payload === 'object' && !Array.isArray(payload)
      ? (payload as Record<string, unknown>).festival
      : null;

  try {
    const result = await runCozeFestivalTranslate(festival);
    const rawRecord =
      result.raw && typeof result.raw === 'object' && !Array.isArray(result.raw)
        ? (result.raw as Record<string, unknown>)
        : null;
    return NextResponse.json(
      {
        ok: true,
        translated: result.translated,
        formatted_output: rawRecord?.formatted_output ?? null,
        raw_response: result.raw,
      },
      { headers: { 'Cache-Control': 'no-store' } }
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    const status =
      message === 'festival object is required' ? 400 : message.includes('not configured') ? 503 : 502;
    return NextResponse.json({ ok: false, error: message }, { status });
  }
}
