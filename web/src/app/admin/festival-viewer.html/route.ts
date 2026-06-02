import { serveScrapRaveRootAsset } from '@/lib/server/legacy-festival-viewer';

export const runtime = 'nodejs';

export async function GET() {
  return serveScrapRaveRootAsset('festival-viewer.html');
}
