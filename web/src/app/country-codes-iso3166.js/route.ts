import { serveScrapRaveRootAsset } from '@/lib/server/legacy-festival-viewer';

export const runtime = 'nodejs';

export async function GET() {
  return serveScrapRaveRootAsset('country-codes-iso3166.js');
}
