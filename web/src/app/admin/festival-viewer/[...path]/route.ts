import { serveFestivalViewerAsset } from '@/lib/server/legacy-festival-viewer';

export const runtime = 'nodejs';

type RouteContext = {
  params: Promise<{
    path: string[];
  }>;
};

export async function GET(_request: Request, context: RouteContext) {
  const { path } = await context.params;
  return serveFestivalViewerAsset(path);
}
