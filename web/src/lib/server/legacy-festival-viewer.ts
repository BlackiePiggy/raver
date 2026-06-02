import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { NextResponse } from 'next/server';

const SCRAP_RAVE_ROOT = path.resolve(process.cwd(), '..', 'scrapRave');
const FESTIVAL_VIEWER_ROOT = path.join(SCRAP_RAVE_ROOT, 'festival-viewer');

const MIME_TYPES: Record<string, string> = {
  '.css': 'text/css; charset=utf-8',
  '.gif': 'image/gif',
  '.html': 'text/html; charset=utf-8',
  '.jpeg': 'image/jpeg',
  '.jpg': 'image/jpeg',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.webp': 'image/webp',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

function notFoundResponse() {
  return NextResponse.json({ ok: false, error: 'Not found' }, { status: 404 });
}

function resolveSafePath(root: string, relativePath: string) {
  const normalized = relativePath.replace(/\\/g, '/').replace(/^\/+/, '');
  const segments = normalized.split('/').filter(Boolean);
  if (!segments.length) return null;
  if (segments.some((segment) => segment === '.' || segment === '..')) return null;

  const resolved = path.resolve(root, ...segments);
  const relative = path.relative(root, resolved);
  if (relative.startsWith('..') || path.isAbsolute(relative)) return null;
  return resolved;
}

async function serveFile(filePath: string) {
  try {
    const fileStat = await stat(filePath);
    if (!fileStat.isFile()) {
      return notFoundResponse();
    }
    const buffer = await readFile(filePath);
    const extension = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[extension] || 'application/octet-stream';
    return new NextResponse(buffer, {
      status: 200,
      headers: {
        'Cache-Control': 'no-store',
        'Content-Length': String(buffer.byteLength),
        'Content-Type': contentType,
      },
    });
  } catch {
    return notFoundResponse();
  }
}

export async function serveFestivalViewerAsset(pathSegments: string[]) {
  const filePath = resolveSafePath(FESTIVAL_VIEWER_ROOT, pathSegments.join('/'));
  if (!filePath) return notFoundResponse();
  return serveFile(filePath);
}

export async function serveScrapRaveRootAsset(relativePath: string) {
  const filePath = resolveSafePath(SCRAP_RAVE_ROOT, relativePath);
  if (!filePath) return notFoundResponse();
  return serveFile(filePath);
}
