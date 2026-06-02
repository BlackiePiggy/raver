import { NextResponse } from 'next/server';

export const runtime = 'nodejs';

export async function GET() {
  return NextResponse.json(
    {
      ok: true,
      data: {
        amap: {
          jsApiKey: process.env.AMAP_JS_API_KEY || '',
          securityJsCode: process.env.AMAP_SECURITY_JS_CODE || '',
        },
        mapkit: {
          jsToken: process.env.MAPKIT_JS_TOKEN || '',
        },
        mapbox: {
          accessToken: process.env.MAPBOX_ACCESS_TOKEN || '',
        },
        geoapify: {
          apiKey: process.env.GEOAPIFY_API_KEY || '',
        },
      },
    },
    {
      headers: {
        'Cache-Control': 'no-store',
      },
    }
  );
}
