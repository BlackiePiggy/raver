import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { Request, Response, Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { Resvg } from '@resvg/resvg-js';
import jpeg from 'jpeg-js';
import QRCode from 'qrcode';
import { PNG } from 'pngjs';
import {
  buildShareShortUrl,
  getRawShareLinkByCode,
  recordShareLinkEvent,
  ShareLinkError,
} from '../modules/share';

const router: Router = Router();
const prisma = new PrismaClient();
const APP_DOWNLOAD_URL = process.env.RAVER_IOS_DOWNLOAD_URL || 'https://ravehub.top/download';
const IP_HASH_SALT = process.env.SHARE_LINK_IP_HASH_SALT || process.env.AUTH_REFRESH_TOKEN_SECRET || 'raver-share-link';
const APP_ICON_PATH = path.resolve(
  __dirname,
  '../../../mobile/ios/RaverMVP/RaverMVP/Assets.xcassets/AppIcon.appiconset/icon-60@3x.png'
);

type RGB = [number, number, number];

type PosterRenderMode =
  | 'event_svg'
  | 'event_fallback_png'
  | 'default_png';

type SharePosterLocale = 'zh' | 'en';

const htmlEscape = (value: string | null | undefined): string =>
  String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const cssImageUrl = (value: string | null | undefined): string => {
  const normalized = String(value || '').trim();
  if (!normalized || !/^https?:\/\//i.test(normalized)) return '';
  return normalized.replace(/["\\\n\r]/g, '');
};

type EventImageAssetPayload = {
  bucket?: string | null;
  zone?: string | null;
  type?: string | null;
  purpose?: string | null;
  kind?: string | null;
  url?: string | null;
  sort?: number | null;
  order?: number | null;
};

const parseEventImageAssets = (value: unknown): EventImageAssetPayload[] => {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is EventImageAssetPayload => Boolean(item && typeof item === 'object'));
};

const normalizeEventText = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  return normalized ? normalized : null;
};

const resolveEventImageAssetBucket = (asset: EventImageAssetPayload): 'poster' | 'cover' | 'lineup' | 'other' => {
  const raw = [
    asset.bucket,
    asset.zone,
    asset.type,
    asset.purpose,
    asset.kind,
  ]
    .map((item) => String(item || '').trim().toLowerCase())
    .find(Boolean) || '';
  if (raw.includes('poster')) return 'poster';
  if (raw.includes('cover')) return 'cover';
  if (raw.includes('lineup')) return 'lineup';
  return 'other';
};

const sortEventImageAssetsForDisplay = (assets: EventImageAssetPayload[]): EventImageAssetPayload[] =>
  [...assets].sort((a, b) => {
    const aOrder = typeof a.sort === 'number' ? a.sort : typeof a.order === 'number' ? a.order : Number.MAX_SAFE_INTEGER;
    const bOrder = typeof b.sort === 'number' ? b.sort : typeof b.order === 'number' ? b.order : Number.MAX_SAFE_INTEGER;
    return aOrder - bOrder;
  });

const resolveEventPosterImageUrl = (row: {
  imageAssets?: unknown;
  coverImageUrl?: unknown;
  lineupImageUrl?: unknown;
}): string | null => {
  const assets = sortEventImageAssetsForDisplay(parseEventImageAssets(row.imageAssets ?? []));
  const firstAssetUrl = (bucket: ReturnType<typeof resolveEventImageAssetBucket>) =>
    normalizeEventText(assets.find((asset) => resolveEventImageAssetBucket(asset) === bucket)?.url);
  return (
    normalizeEventText(row.coverImageUrl) ||
    firstAssetUrl('poster') ||
    normalizeEventText(row.lineupImageUrl) ||
    firstAssetUrl('lineup') ||
    firstAssetUrl('cover') ||
    null
  );
};

const asciiText = (value: string | null | undefined, fallback: string): string => {
  const normalized = String(value || '')
    .replace(/[^\x20-\x7E]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  return normalized || fallback;
};

const posterText = (value: string | null | undefined, fallback: string): string => {
  const normalized = String(value || '')
    .replace(/\s+/g, ' ')
    .trim();
  return normalized || fallback;
};

const wrapText = (value: string, maxChars: number, maxLines: number): string[] => {
  const words = value.split(/\s+/).filter(Boolean);
  const lines: string[] = [];
  let current = '';
  for (const word of words) {
    const next = current ? `${current} ${word}` : word;
    if (next.length <= maxChars) {
      current = next;
      continue;
    }
    if (current) lines.push(current);
    current = word.slice(0, maxChars);
    if (lines.length >= maxLines) break;
  }
  if (current && lines.length < maxLines) lines.push(current);
  return lines.length > 0 ? lines : [value.slice(0, maxChars)];
};

const currentPublicUrl = (req: Request): string => `${req.protocol}://${req.get('host')}${req.originalUrl}`;

const getClientIp = (req: Request): string => {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.trim()) {
    const first = forwarded.split(',')[0].trim();
    if (first) return first;
  }
  if (Array.isArray(forwarded) && forwarded.length > 0 && forwarded[0].trim()) {
    return forwarded[0].trim();
  }
  return req.socket.remoteAddress || 'unknown';
};

const hashIp = (value: string): string | null => {
  const normalized = String(value || '').trim();
  if (!normalized || normalized === 'unknown') return null;
  return crypto.createHash('sha256').update(`${IP_HASH_SALT}:${normalized}`).digest('hex');
};

const classifyUserAgent = (userAgent: string | null): { suspicious: boolean; reason: string | null } => {
  const normalized = String(userAgent || '').trim();
  if (!normalized) {
    return { suspicious: true, reason: 'missing_user_agent' };
  }
  if (normalized.length > 512) {
    return { suspicious: true, reason: 'oversized_user_agent' };
  }
  if (/(curl|wget|python-requests|scrapy|bot|crawler|spider|headless)/i.test(normalized)) {
    return { suspicious: true, reason: 'automation_user_agent' };
  }
  return { suspicious: false, reason: null };
};

const requestContext = (req: Request) => {
  const userAgent = typeof req.headers['user-agent'] === 'string' ? req.headers['user-agent'] : null;
  const uaRisk = classifyUserAgent(userAgent);
  return {
    userAgent,
    referrer: typeof req.headers.referer === 'string' ? req.headers.referer : null,
    ipHash: hashIp(getClientIp(req)),
    uaRisk,
  };
};

const normalizePosterLocale = (acceptLanguage: string | string[] | undefined): SharePosterLocale => {
  const raw = Array.isArray(acceptLanguage) ? acceptLanguage.join(',') : String(acceptLanguage || '');
  return raw.trim().toLowerCase().startsWith('zh') ? 'zh' : 'en';
};

const appendShareCode = (value: string, code: string): string => {
  try {
    const url = new URL(value);
    if (!url.searchParams.has('shareCode')) {
      url.searchParams.set('shareCode', code);
    }
    return url.toString();
  } catch {
    const separator = value.includes('?') ? '&' : '?';
    return `${value}${separator}shareCode=${encodeURIComponent(code)}`;
  }
};

const describeShareState = (shareLink: Awaited<ReturnType<typeof getRawShareLinkByCode>>): {
  ok: boolean;
  statusCode: number;
  title: string;
  description: string;
  reason: string | null;
} => {
  if (shareLink.status !== 'active') {
    return {
      ok: false,
      statusCode: 410,
      title: '链接已失效',
      description: '这个分享链接已经不可用。请返回 Raver 获取新的分享链接。',
      reason: shareLink.status === 'revoked' ? 'revoked' : 'inactive',
    };
  }

  if (shareLink.expiresAt && shareLink.expiresAt.getTime() <= Date.now()) {
    return {
      ok: false,
      statusCode: 410,
      title: '邀请已过期',
      description: '这个邀请链接已经过期。请联系分享者重新生成邀请。',
      reason: 'expired',
    };
  }

  if (shareLink.maxUses !== null && shareLink.maxUses !== undefined && shareLink.usedCount >= shareLink.maxUses) {
    return {
      ok: false,
      statusCode: 410,
      title: '邀请已用完',
      description: '这个邀请链接的可用次数已经耗尽。请联系分享者重新生成邀请。',
      reason: 'exhausted',
    };
  }

  return {
    ok: true,
    statusCode: 200,
    title: shareLink.title,
    description: shareLink.subtitle || '打开 Raver 查看这个分享内容。',
    reason: null,
  };
};

const renderStatePage = (title: string, description: string, primaryURL?: string | null): string => {
  const escapedTitle = htmlEscape(title);
  const escapedDescription = htmlEscape(description);
  const escapedPrimaryURL = primaryURL ? htmlEscape(primaryURL) : null;
  const button = primaryURL
    ? `<a href="${escapedPrimaryURL}" style="display:inline-block;padding:12px 18px;background:#111827;color:#fff;text-decoration:none;border-radius:999px;">打开 Raver</a>`
    : '';

  return `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${escapedTitle}</title>
    <meta property="og:title" content="${escapedTitle}" />
    <meta property="og:description" content="${escapedDescription}" />
    <style>
      body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #f4f4f5; color: #111827; }
      main { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 24px; }
      section { width: 100%; max-width: 480px; background: #fff; border-radius: 24px; padding: 28px; box-shadow: 0 12px 40px rgba(17,24,39,.08); }
      h1 { margin: 0 0 12px; font-size: 28px; }
      p { margin: 0 0 20px; line-height: 1.6; color: #4b5563; }
    </style>
  </head>
  <body>
    <main>
      <section>
        <h1>${escapedTitle}</h1>
        <p>${escapedDescription}</p>
        ${button}
      </section>
    </main>
  </body>
</html>`;
};

const renderLandingPage = (
  req: Request,
  shareLink: Awaited<ReturnType<typeof getRawShareLinkByCode>>,
  state: ReturnType<typeof describeShareState>
): string => {
  const pageUrl = htmlEscape(currentPublicUrl(req));
  const title = htmlEscape(state.title);
  const description = htmlEscape(state.description);
  const imageUrl = cssImageUrl(shareLink.imageUrl);
  const imageMeta = imageUrl ? `<meta property="og:image" content="${htmlEscape(imageUrl)}" />` : '';
  const heroImage = imageUrl ? `<div class="art" style="background-image:url('${htmlEscape(imageUrl)}')"></div>` : '<div class="art fallback">R</div>';
  const openUrl = htmlEscape(`/s/${encodeURIComponent(shareLink.code)}/open`);
  const downloadUrl = htmlEscape(`/s/${encodeURIComponent(shareLink.code)}/download`);
  const details = shareLink.visibility === 'private_invite'
    ? '这是一个私密小队邀请，加入前只展示必要信息。'
    : '在 Raver 中打开，继续查看完整内容。';
  const statusNote = state.ok ? htmlEscape(details) : htmlEscape(state.description);
  const buttons = state.ok
    ? `<div class="actions">
        <a class="primary" href="${openUrl}">打开 Raver</a>
        <a class="secondary" href="${downloadUrl}">下载 App</a>
      </div>`
    : `<div class="actions"><a class="secondary" href="${htmlEscape(APP_DOWNLOAD_URL)}">下载 App</a></div>`;

  return `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${title}</title>
    <meta name="description" content="${description}" />
    <meta property="og:type" content="website" />
    <meta property="og:url" content="${pageUrl}" />
    <meta property="og:title" content="${title}" />
    <meta property="og:description" content="${description}" />
    ${imageMeta}
    <meta name="twitter:card" content="${imageUrl ? 'summary_large_image' : 'summary'}" />
    <style>
      * { box-sizing: border-box; }
      body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f6f2ea; color: #171717; }
      main { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 28px 18px; }
      section { width: 100%; max-width: 460px; }
      .art { width: 100%; aspect-ratio: 1 / .72; border-radius: 20px; background-size: cover; background-position: center; background-color: #1f2937; box-shadow: 0 18px 50px rgba(23,23,23,.16); margin-bottom: 24px; }
      .fallback { display: flex; align-items: center; justify-content: center; color: #fff; font-size: 72px; font-weight: 800; background: linear-gradient(135deg, #171717, #475569); }
      h1 { margin: 0 0 10px; font-size: 30px; line-height: 1.14; letter-spacing: 0; }
      p { margin: 0; color: #525252; line-height: 1.6; font-size: 16px; }
      .note { margin-top: 12px; font-size: 14px; color: #737373; }
      .actions { display: grid; gap: 10px; margin-top: 24px; }
      a { min-height: 48px; display: inline-flex; align-items: center; justify-content: center; border-radius: 999px; text-decoration: none; font-weight: 700; }
      .primary { background: #171717; color: #fff; }
      .secondary { background: #fff; color: #171717; border: 1px solid rgba(23,23,23,.12); }
      @media (min-width: 520px) {
        .actions { grid-template-columns: 1fr 1fr; }
      }
    </style>
  </head>
  <body>
    <main>
      <section>
        ${heroImage}
        <h1>${title}</h1>
        <p>${description}</p>
        <p class="note">${statusNote}</p>
        ${buttons}
      </section>
    </main>
  </body>
</html>`;
};

const font5x7: Record<string, string[]> = {
  ' ': ['00000', '00000', '00000', '00000', '00000', '00000', '00000'],
  '-': ['00000', '00000', '00000', '11110', '00000', '00000', '00000'],
  '.': ['00000', '00000', '00000', '00000', '00000', '01100', '01100'],
  '/': ['00001', '00010', '00100', '01000', '10000', '00000', '00000'],
  ':': ['00000', '01100', '01100', '00000', '01100', '01100', '00000'],
  '?': ['11110', '00001', '00001', '00110', '00100', '00000', '00100'],
  '&': ['01100', '10010', '10100', '01000', '10101', '10010', '01101'],
  '=': ['00000', '11111', '00000', '11111', '00000', '00000', '00000'],
  '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
  '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
  '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
  '3': ['11110', '00001', '00001', '01110', '00001', '00001', '11110'],
  '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
  '5': ['11111', '10000', '10000', '11110', '00001', '00001', '11110'],
  '6': ['01110', '10000', '10000', '11110', '10001', '10001', '01110'],
  '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
  '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
  '9': ['01110', '10001', '10001', '01111', '00001', '00001', '01110'],
  A: ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
  B: ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
  C: ['01111', '10000', '10000', '10000', '10000', '10000', '01111'],
  D: ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
  E: ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
  F: ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
  G: ['01111', '10000', '10000', '10011', '10001', '10001', '01111'],
  H: ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
  I: ['11111', '00100', '00100', '00100', '00100', '00100', '11111'],
  J: ['00111', '00010', '00010', '00010', '00010', '10010', '01100'],
  K: ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
  L: ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
  M: ['10001', '11011', '10101', '10101', '10001', '10001', '10001'],
  N: ['10001', '11001', '10101', '10011', '10001', '10001', '10001'],
  O: ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
  P: ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
  Q: ['01110', '10001', '10001', '10001', '10101', '10010', '01101'],
  R: ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
  S: ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
  T: ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
  U: ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
  V: ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
  W: ['10001', '10001', '10001', '10101', '10101', '10101', '01010'],
  X: ['10001', '10001', '01010', '00100', '01010', '10001', '10001'],
  Y: ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
  Z: ['11111', '00001', '00010', '00100', '01000', '10000', '11111'],
};

const setPixel = (png: PNG, x: number, y: number, color: RGB, alpha = 255): void => {
  if (x < 0 || y < 0 || x >= png.width || y >= png.height) return;
  const index = (png.width * y + x) << 2;
  png.data[index] = color[0];
  png.data[index + 1] = color[1];
  png.data[index + 2] = color[2];
  png.data[index + 3] = alpha;
};

const fillRect = (png: PNG, x: number, y: number, width: number, height: number, color: RGB, alpha = 255): void => {
  for (let row = y; row < y + height; row += 1) {
    for (let col = x; col < x + width; col += 1) {
      setPixel(png, col, row, color, alpha);
    }
  }
};

const drawHorizontalLine = (png: PNG, x: number, y: number, width: number, thickness: number, color: RGB, alpha = 255): void => {
  fillRect(png, x, y, width, Math.max(1, thickness), color, alpha);
};

const drawVerticalLine = (png: PNG, x: number, y: number, thickness: number, height: number, color: RGB, alpha = 255): void => {
  fillRect(png, x, y, Math.max(1, thickness), height, color, alpha);
};

const insetRect = (
  png: PNG,
  x: number,
  y: number,
  width: number,
  height: number,
  color: RGB,
  thickness = 1,
  alpha = 255
): void => {
  drawHorizontalLine(png, x, y, width, thickness, color, alpha);
  drawHorizontalLine(png, x, y + height - thickness, width, thickness, color, alpha);
  drawVerticalLine(png, x, y, thickness, height, color, alpha);
  drawVerticalLine(png, x + width - thickness, y, thickness, height, color, alpha);
};

const fillVerticalGradient = (
  png: PNG,
  x: number,
  y: number,
  width: number,
  height: number,
  top: RGB,
  bottom: RGB
): void => {
  for (let row = 0; row < height; row += 1) {
    const ratio = height <= 1 ? 0 : row / (height - 1);
    const color: RGB = [
      Math.round(top[0] + (bottom[0] - top[0]) * ratio),
      Math.round(top[1] + (bottom[1] - top[1]) * ratio),
      Math.round(top[2] + (bottom[2] - top[2]) * ratio),
    ];
    fillRect(png, x, y + row, width, 1, color);
  }
};

const clampText = (value: string, maxLength: number): string => {
  const normalized = value.trim();
  if (normalized.length <= maxLength) return normalized;
  return `${normalized.slice(0, Math.max(0, maxLength - 1))}…`;
};

const drawText = (png: PNG, text: string, x: number, y: number, scale: number, color: RGB): void => {
  let cursor = x;
  for (const rawChar of text.toUpperCase()) {
    const glyph = font5x7[rawChar] || font5x7['?'];
    for (let row = 0; row < glyph.length; row += 1) {
      for (let col = 0; col < glyph[row].length; col += 1) {
        if (glyph[row][col] === '1') {
          fillRect(png, cursor + col * scale, y + row * scale, scale, scale, color);
        }
      }
    }
    cursor += 6 * scale;
  }
};

const loadAppIconPng = (() => {
  let cached: PNG | null | undefined;
  return (): PNG | null => {
    if (cached !== undefined) {
      return cached;
    }
    try {
      const bytes = fs.readFileSync(APP_ICON_PATH);
      cached = PNG.sync.read(bytes);
      return cached;
    } catch (error) {
      console.error('Failed to load share QR logo:', error);
      cached = null;
      return cached;
    }
  };
})();

const blendPixel = (
  target: PNG,
  x: number,
  y: number,
  source: RGB,
  alpha: number
): void => {
  if (x < 0 || y < 0 || x >= target.width || y >= target.height) return;
  const dstIndex = (target.width * y + x) << 2;
  const srcAlpha = Math.max(0, Math.min(255, alpha)) / 255;
  const invAlpha = 1 - srcAlpha;
  target.data[dstIndex] = Math.round(source[0] * srcAlpha + target.data[dstIndex] * invAlpha);
  target.data[dstIndex + 1] = Math.round(source[1] * srcAlpha + target.data[dstIndex + 1] * invAlpha);
  target.data[dstIndex + 2] = Math.round(source[2] * srcAlpha + target.data[dstIndex + 2] * invAlpha);
  target.data[dstIndex + 3] = 255;
};

const overlayPngScaled = (
  target: PNG,
  source: PNG,
  x: number,
  y: number,
  width: number,
  height: number
): void => {
  if (width <= 0 || height <= 0) return;
  for (let row = 0; row < height; row += 1) {
    for (let col = 0; col < width; col += 1) {
      const srcX = Math.min(source.width - 1, Math.floor((col / width) * source.width));
      const srcY = Math.min(source.height - 1, Math.floor((row / height) * source.height));
      const srcIndex = (source.width * srcY + srcX) << 2;
      const alpha = source.data[srcIndex + 3];
      if (alpha === 0) continue;
      blendPixel(
        target,
        x + col,
        y + row,
        [source.data[srcIndex], source.data[srcIndex + 1], source.data[srcIndex + 2]],
        alpha
      );
    }
  }
};

const decodeImageToPng = (buffer: Buffer, contentType?: string | null): PNG | null => {
  const normalizedType = String(contentType || '').toLowerCase();

  if (normalizedType.includes('png')) {
    try {
      return PNG.sync.read(buffer);
    } catch {
      return null;
    }
  }

  if (normalizedType.includes('jpeg') || normalizedType.includes('jpg')) {
    try {
      const decoded = jpeg.decode(buffer, { useTArray: true });
      const png = new PNG({
        width: decoded.width,
        height: decoded.height,
      });
      png.data = Buffer.from(decoded.data);
      return png;
    } catch {
      return null;
    }
  }

  try {
    return PNG.sync.read(buffer);
  } catch {
    try {
      const decoded = jpeg.decode(buffer, { useTArray: true });
      const png = new PNG({
        width: decoded.width,
        height: decoded.height,
      });
      png.data = Buffer.from(decoded.data);
      return png;
    } catch {
      return null;
    }
  }
};

const loadRemoteImagePng = async (urlString: string | null | undefined): Promise<PNG | null> => {
  const normalized = String(urlString || '').trim();
  if (!/^https?:\/\//i.test(normalized)) return null;

  try {
    const response = await fetch(normalized);
    if (!response.ok) return null;
    const arrayBuffer = await response.arrayBuffer();
    return decodeImageToPng(Buffer.from(arrayBuffer), response.headers.get('content-type'));
  } catch (error) {
    console.error('Failed to load share poster remote image:', error);
    return null;
  }
};

const overlayPngCover = (
  target: PNG,
  source: PNG,
  x: number,
  y: number,
  width: number,
  height: number
): void => {
  if (width <= 0 || height <= 0 || source.width <= 0 || source.height <= 0) return;
  const scale = Math.max(width / source.width, height / source.height);
  const cropWidth = width / scale;
  const cropHeight = height / scale;
  const cropX = Math.max(0, (source.width - cropWidth) / 2);
  const cropY = Math.max(0, (source.height - cropHeight) / 2);

  for (let row = 0; row < height; row += 1) {
    for (let col = 0; col < width; col += 1) {
      const srcX = Math.min(
        source.width - 1,
        Math.max(0, Math.floor(cropX + (col / width) * cropWidth))
      );
      const srcY = Math.min(
        source.height - 1,
        Math.max(0, Math.floor(cropY + (row / height) * cropHeight))
      );
      const srcIndex = (source.width * srcY + srcX) << 2;
      const alpha = source.data[srcIndex + 3];
      if (alpha === 0) continue;
      blendPixel(
        target,
        x + col,
        y + row,
        [source.data[srcIndex], source.data[srcIndex + 1], source.data[srcIndex + 2]],
        alpha
      );
    }
  }
};

type SharePosterEventSnapshot = {
  title: string;
  venue: string;
  organizer: string;
  startDate: Date | null;
  endDate: Date | null;
  timeZone: string;
  artistCount: number;
  imageUrl: string | null;
  shareCode: string;
};

const formatPosterDate = (date: Date | null, timeZone: string, locale: SharePosterLocale = 'en'): string => {
  if (!date) return locale == 'zh' ? '待定' : 'TBA';
  try {
    if (locale === 'zh') {
      return new Intl.DateTimeFormat('zh-CN', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        timeZone,
      }).format(date);
    }
    const formatted = new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      timeZone,
    }).format(date);
    return asciiText(formatted.toUpperCase(), 'TBA');
  } catch {
    return locale === 'zh' ? '待定' : asciiText(date.toISOString().slice(0, 10), 'TBA');
  }
};

const formatPosterDateParts = (
  date: Date | null,
  timeZone: string
): { year: string; month: string; day: string } | null => {
  if (!date) return null;
  try {
    const parts = new Intl.DateTimeFormat('zh-CN-u-nu-latn', {
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      timeZone,
    }).formatToParts(date);
    const year = parts.find((part) => part.type === 'year')?.value || '';
    const month = parts.find((part) => part.type === 'month')?.value || '';
    const day = parts.find((part) => part.type === 'day')?.value || '';
    if (!year || !month || !day) return null;
    return { year, month, day };
  } catch {
    return null;
  }
};

const svgEscape = (value: string | null | undefined): string => htmlEscape(value);

const toImageDataUri = async (urlString: string | null | undefined): Promise<string | null> => {
  const normalized = String(urlString || '').trim();
  if (!/^https?:\/\//i.test(normalized)) return null;

  try {
    const response = await fetch(normalized);
    if (!response.ok) return null;
    const arrayBuffer = await response.arrayBuffer();
    const contentType = response.headers.get('content-type') || 'image/jpeg';
    return `data:${contentType};base64,${Buffer.from(arrayBuffer).toString('base64')}`;
  } catch (error) {
    console.error('Failed to load share poster remote image as data URL:', error);
    return null;
  }
};

const formatPosterDurationLabel = (
  startDate: Date | null,
  endDate: Date | null,
  timeZone: string,
  locale: SharePosterLocale
): string => {
  const duration = formatPosterDuration(startDate, endDate, timeZone);
  if (duration === 'TBA') {
    return locale === 'zh' ? '待定' : 'TBA';
  }
  if (locale === 'zh') {
    const days = duration.match(/\d+/)?.[0] || duration;
    return `${days} 天`;
  }
  return duration.replace(/\bDAY\b/g, 'Day').replace(/\bDAYS\b/g, 'Days');
};

const posterCopy = (locale: SharePosterLocale) =>
  locale === 'zh'
    ? {
        access: 'RAVEHUB 通行证',
        start: '开始',
        end: '结束',
        duration: '时长',
        lineup: '阵容',
        venue: '地点',
        presentedBy: '主办方',
        moreInfo: '更多活动、艺人信息请扫码查看 RaveHub App',
        titleFont: "'ZCOOL_KuHei', '站酷酷黑', 'Alibaba PuHuiTi', 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans SC', sans-serif",
        bodyFont: "'ZCOOL_KuHei', '站酷酷黑', 'Alibaba PuHuiTi', 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans SC', sans-serif",
      }
    : {
        access: 'RAVEHUB ACCESS',
        start: 'START',
        end: 'END',
        duration: 'DURATION',
        lineup: 'LINEUP',
        venue: 'VENUE',
        presentedBy: 'PRESENTED BY',
        moreInfo: 'SCAN RAVEHUB APP FOR MORE EVENTS & LINEUP INFO',
        titleFont: "'ZCOOL_KuHei', '站酷酷黑', 'Alibaba PuHuiTi', 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans SC', sans-serif",
        bodyFont: "'ZCOOL_KuHei', '站酷酷黑', 'Alibaba PuHuiTi', 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans SC', sans-serif",
      };

const hasCJKText = (value: string): boolean => /[\u3400-\u9FFF]/.test(value);
const hasLatinOrDigitText = (value: string): boolean => /[A-Za-z0-9]/.test(value);
const isLatinStyledChar = (char: string): boolean => /[A-Za-z0-9\s.,:&()\-/'"+]/.test(char);

const splitMixedRuns = (value: string): Array<{ text: string; kind: 'cjk' | 'latin' }> => {
  const runs: Array<{ text: string; kind: 'cjk' | 'latin' }> = [];
  let current = '';
  let currentKind: 'cjk' | 'latin' | null = null;

  for (const char of value) {
    const kind: 'cjk' | 'latin' = isLatinStyledChar(char) ? 'latin' : 'cjk';
    if (currentKind === kind || currentKind === null) {
      current += char;
      currentKind = kind;
      continue;
    }
    runs.push({ text: current, kind: currentKind });
    current = char;
    currentKind = kind;
  }

  if (current && currentKind) {
    runs.push({ text: current, kind: currentKind });
  }
  return runs;
};

const measurePosterTextWidth = (value: string, fontSize: number, kind: 'cjk' | 'latin'): number => {
  let width = 0;
  for (const char of value) {
    if (char === ' ') {
      width += fontSize * 0.16;
    } else if (/[.,:]/.test(char)) {
      width += fontSize * 0.14;
    } else if (kind === 'latin') {
      width += fontSize * 0.46;
    } else {
      width += fontSize * 0.98;
    }
  }
  return width;
};

const buildMixedFontText = (
  value: string,
  x: number,
  y: number,
  fontSize: number,
  color: string,
  zhFont: string,
  enFont: string,
  zhWeight: string,
  letterSpacing: number | { zh: number; latin: number }
): string => {
  const runs = splitMixedRuns(value);
  let cursorX = x;
  return runs.map((run) => {
    const family = run.kind === 'latin' ? enFont : zhFont;
    const weight = run.kind === 'latin' ? '400' : zhWeight;
    const runLetterSpacing = typeof letterSpacing === 'number'
      ? letterSpacing
      : run.kind === 'latin'
        ? letterSpacing.latin
        : letterSpacing.zh;
    const text = `<text x="${cursorX}" y="${y}" font-family="${family}" font-weight="${weight}" font-size="${fontSize}" fill="${color}" letter-spacing="${runLetterSpacing}">${svgEscape(run.text)}</text>`;
    cursorX += measurePosterTextWidth(run.text, fontSize, run.kind) + Math.max(0, run.text.length - 1) * runLetterSpacing;
    return text;
  }).join('');
};

const renderZhDateText = (
  date: Date | null,
  timeZone: string,
  x: number,
  y: number,
  bodyFont: string,
  titleFont: string
): string => {
  const parts = formatPosterDateParts(date, timeZone);
  if (!parts) {
    return `<text x="${x}" y="${y}" font-family="${bodyFont}" font-weight="900" font-size="18" fill="#e4e4e7">待定</text>`;
  }
  const yearWidth = measurePosterTextWidth(parts.year, 18, 'latin');
  const monthWidth = measurePosterTextWidth(parts.month, 18, 'latin');
  const dayWidth = measurePosterTextWidth(parts.day, 18, 'latin');
  const yearLabelX = x + yearWidth + 4;
  const monthX = yearLabelX + 12;
  const monthLabelX = monthX + monthWidth + 3;
  const dayX = monthLabelX + 12;
  const dayLabelX = dayX + dayWidth + 3;
  return `
    <text x="${x}" y="${y}" font-family="${titleFont}" font-size="18" fill="#e4e4e7" letter-spacing="0.5">${svgEscape(parts.year)}</text>
    <text x="${yearLabelX}" y="${y}" font-family="${bodyFont}" font-weight="900" font-size="17" fill="#e4e4e7">年</text>
    <text x="${monthX}" y="${y}" font-family="${titleFont}" font-size="18" fill="#e4e4e7" letter-spacing="0.38">${svgEscape(parts.month)}</text>
    <text x="${monthLabelX}" y="${y}" font-family="${bodyFont}" font-weight="900" font-size="17" fill="#e4e4e7">月</text>
    <text x="${dayX}" y="${y}" font-family="${titleFont}" font-size="18" fill="#e4e4e7" letter-spacing="0.38">${svgEscape(parts.day)}</text>
    <text x="${dayLabelX}" y="${y}" font-family="${bodyFont}" font-weight="900" font-size="17" fill="#e4e4e7">日</text>
  `;
};

const renderZhNumberUnitText = (
  numberText: string,
  unitText: string,
  x: number,
  y: number,
  bodyFont: string,
  titleFont: string
): string => {
  const numberWidth = measurePosterTextWidth(numberText, 18, 'latin');
  const unitX = x + numberWidth + 6;
  return `
    <text x="${x}" y="${y}" font-family="${titleFont}" font-size="18" fill="#e4e4e7" letter-spacing="0.5">${svgEscape(numberText)}</text>
    <text x="${unitX}" y="${y}" font-family="${bodyFont}" font-weight="900" font-size="18" fill="#e4e4e7" letter-spacing="0.18">${svgEscape(unitText)}</text>
  `;
};

const formatPosterDuration = (startDate: Date | null, endDate: Date | null, timeZone: string): string => {
  if (!startDate || !endDate) return 'TBA';
  try {
    const startText = new Intl.DateTimeFormat('en-CA', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      timeZone,
    }).format(startDate);
    const endText = new Intl.DateTimeFormat('en-CA', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      timeZone,
    }).format(endDate);
    const start = new Date(`${startText}T00:00:00Z`);
    const end = new Date(`${endText}T00:00:00Z`);
    const diffDays = Math.max(1, Math.round((end.getTime() - start.getTime()) / 86400000) + 1);
    return `${diffDays} ${diffDays > 1 ? 'DAYS' : 'DAY'}`;
  } catch {
    return 'TBA';
  }
};

const loadEventPosterSnapshot = async (
  shareLink: Awaited<ReturnType<typeof getRawShareLinkByCode>>
): Promise<SharePosterEventSnapshot | null> => {
  if (shareLink.targetType !== 'event') return null;

  const event = await prisma.event.findUnique({
    where: { id: shareLink.targetId },
    select: {
      name: true,
      organizerName: true,
      venueName: true,
      venueAddress: true,
      city: true,
      country: true,
      startDate: true,
      endDate: true,
      timeZone: true,
      coverImageUrl: true,
      lineupImageUrl: true,
      imageAssets: true,
      _count: {
        select: {
          canonicalArtists: true,
        },
      },
    },
  });

  if (!event) return null;

  const venue = posterText(
    [event.venueAddress, event.venueName, event.city, event.country].filter(Boolean).join(' · '),
    'Venue TBA'
  );

  return {
    title: posterText(event.name || shareLink.title, posterText(shareLink.title, `Event ${shareLink.code}`)),
    venue,
    organizer: posterText(event.organizerName || shareLink.subtitle || 'RAVER', 'RAVER'),
    startDate: event.startDate ?? null,
    endDate: event.endDate ?? null,
    timeZone: event.timeZone || 'UTC',
    artistCount: Math.max(0, Number(event._count?.canonicalArtists ?? 0)),
    imageUrl: resolveEventPosterImageUrl(event) || shareLink.imageUrl || null,
    shareCode: shareLink.code,
  };
};

const renderEventPosterSvg = async (
  shareLink: Awaited<ReturnType<typeof getRawShareLinkByCode>>,
  event: SharePosterEventSnapshot,
  locale: SharePosterLocale
): Promise<Buffer | null> => {
  const copy = posterCopy(locale);
  const qrDataUrl = await QRCode.toDataURL(buildShareShortUrl(shareLink.code), {
    errorCorrectionLevel: 'H',
    margin: 0,
    width: 240,
    color: {
      dark: '#050505',
      light: '#FFFFFFFF',
    },
  });
  const qrImageDataUrl = qrDataUrl;
  const heroImageDataUrl = await toImageDataUri(event.imageUrl);

  const safeStart = svgEscape(formatPosterDate(event.startDate, event.timeZone, locale));
  const safeEnd = svgEscape(formatPosterDate(event.endDate, event.timeZone, locale));
  const safeDuration = svgEscape(formatPosterDurationLabel(event.startDate, event.endDate, event.timeZone, locale));
  const safeLineup = svgEscape(locale === 'zh' ? `${Math.max(0, event.artistCount)} 组艺人` : `${Math.max(0, event.artistCount)} Artists`);
  const safeVenueRaw = event.venue || (locale === 'zh' ? '待定' : 'Venue TBA');
  const safeVenue = svgEscape(safeVenueRaw);
  const titleSource = locale === 'zh' ? (event.title || shareLink.title || '') : (event.title || shareLink.title || '').toUpperCase();
  const titleLines = wrapText(titleSource, locale === 'zh' ? 12 : 16, 3);
  const titleBlock = titleLines
    .map((line, index) => {
      const y = 280 + index * 30;
      if (locale === 'zh' && hasLatinOrDigitText(line) && hasCJKText(line)) {
        return buildMixedFontText(line, 25, y, 28, '#fff', copy.bodyFont, copy.titleFont, '900', 2.6);
      }
      const fontFamily = hasCJKText(line) ? copy.bodyFont : copy.titleFont;
      const fontWeight = hasCJKText(line) ? '900' : '400';
      const letterSpacing = hasCJKText(line) ? '2.6' : '5.04';
      return `<text x="25" y="${y}" font-family="${fontFamily}" font-weight="${fontWeight}" font-size="28" letter-spacing="${letterSpacing}" fill="#fff">${svgEscape(line)}</text>`;
    })
    .join('');
  const durationMatch = safeDuration.match(/^(\d+)\s*(.*)$/);
  const durationNumber = durationMatch?.[1] || safeDuration;
  const durationUnit = durationMatch?.[2] || '';
  const lineupMatch = safeLineup.match(/^(\d+)\s*(.*)$/);
  const lineupNumber = lineupMatch?.[1] || safeLineup;
  const lineupUnit = lineupMatch?.[2] || '';
  const organizerRaw = event.organizer || 'Raver';
  const organizerParts = locale === 'zh'
    ? organizerRaw.split(/×/).map((item) => item.trim()).filter(Boolean)
    : [organizerRaw];
  const organizerSecondary = organizerParts[1] ? svgEscape(organizerParts[1]) : '';
  const moreInfoLine1 = locale === 'zh' ? '更多活动与艺人信息请扫码查看' : 'SCAN FOR MORE EVENTS &';
  const moreInfoLine2 = locale === 'zh' ? 'RaveHub App' : 'LINEUP INFO ON RAVEHUB APP';

  const svg = `
<svg xmlns="http://www.w3.org/2000/svg" width="390" height="700" viewBox="0 0 390 700">
  <defs>
    <linearGradient id="maskGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#000" stop-opacity="0.15"/>
      <stop offset="55%" stop-color="#000" stop-opacity="0.5"/>
      <stop offset="100%" stop-color="#000" stop-opacity="0.92"/>
    </linearGradient>
    <linearGradient id="topGlow" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#ef4444" stop-opacity="0.1"/>
      <stop offset="100%" stop-color="transparent"/>
    </linearGradient>
    <clipPath id="heroClip">
      <rect x="0" y="60" width="390" height="260" />
    </clipPath>
  </defs>
  <rect width="390" height="700" rx="30" fill="#0f0f11" stroke="#27272a" stroke-width="1"/>

  <rect x="0" y="0" width="390" height="60" fill="rgba(255,255,255,0.03)"/>
  <line x1="0" y1="60" x2="390" y2="60" stroke="rgba(255,255,255,0.05)" stroke-width="1"/>
  <text x="25" y="38" font-family="${copy.titleFont}" font-size="16" fill="#d4d4d8" letter-spacing="4.3">RAVEHUB ACCESS</text>

  <rect x="0" y="60" width="390" height="260" fill="#18181b"/>
  ${
    heroImageDataUrl
      ? `<image href="${heroImageDataUrl}" x="0" y="60" width="390" height="260" preserveAspectRatio="xMidYMid slice" clip-path="url(#heroClip)" />`
      : ''
  }
  <rect x="0" y="60" width="390" height="260" fill="url(#maskGrad)"/>
  <rect x="0" y="60" width="390" height="260" fill="url(#topGlow)"/>

  <line x1="0" y1="91" x2="390" y2="91" stroke="rgba(239,68,68,0.2)" stroke-width="2"/>
  <line x1="0" y1="130" x2="390" y2="130" stroke="rgba(239,68,68,0.2)" stroke-width="1"/>
  <line x1="0" y1="158" x2="390" y2="158" stroke="rgba(239,68,68,0.2)" stroke-width="3"/>
  <line x1="0" y1="193" x2="390" y2="193" stroke="rgba(239,68,68,0.2)" stroke-width="2"/>
  <line x1="0" y1="226" x2="390" y2="226" stroke="rgba(239,68,68,0.2)" stroke-width="1"/>
  <line x1="0" y1="255" x2="390" y2="255" stroke="rgba(239,68,68,0.2)" stroke-width="2"/>

  <g>${titleBlock}</g>

  <rect x="0" y="320" width="390" height="20" fill="#000"/>
  <path d="M0,0 L7,-10 L14,0 L21,-10 L28,0 L35,-10 L42,0 L49,-10 L56,0 L63,-10 L70,0 L77,-10 L84,0 L91,-10 L98,0 L105,-10 L112,0 L119,-10 L126,0 L133,-10 L140,0 L147,-10 L154,0 L161,-10 L168,0 L175,-10 L182,0 L189,-10 L196,0 L203,-10 L210,0 L217,-10 L224,0 L231,-10 L238,0 L245,-10 L252,0 L259,-10 L266,0 L273,-10 L280,0 L287,-10 L294,0 L301,-10 L308,0 L315,-10 L322,0 L329,-10 L336,0 L343,-10 L350,0 L357,-10 L364,0 L371,-10 L378,0 L385,-10 L392,0" transform="translate(0,320)" fill="#0f0f11"/>

  <g font-family="${copy.bodyFont}">
    <text x="25" y="372" font-size="12" fill="#71717a" letter-spacing="${locale === 'zh' ? '1.2' : '3'}">${svgEscape(copy.start)}</text>
    ${locale === 'zh'
      ? renderZhDateText(event.startDate, event.timeZone, 25, 392, copy.bodyFont, copy.titleFont)
      : `<text x="25" y="392" font-size="18" fill="#e4e4e7" letter-spacing="1.08">${safeStart}</text>`}

    <text x="200" y="372" font-size="12" fill="#71717a" letter-spacing="${locale === 'zh' ? '1.2' : '3'}">${svgEscape(copy.end)}</text>
    ${locale === 'zh'
      ? renderZhDateText(event.endDate, event.timeZone, 200, 392, copy.bodyFont, copy.titleFont)
      : `<text x="200" y="392" font-size="18" fill="#e4e4e7" letter-spacing="1.08">${safeEnd}</text>`}

    <text x="25" y="422" font-size="12" fill="#71717a" letter-spacing="${locale === 'zh' ? '1.2' : '3'}">${svgEscape(copy.duration)}</text>
    ${
      locale === 'zh'
        ? renderZhNumberUnitText(durationNumber, durationUnit, 25, 442, copy.bodyFont, copy.titleFont)
        : `<text x="25" y="442" font-size="18" fill="#e4e4e7" letter-spacing="1.08">${safeDuration}</text>`
    }

    <text x="200" y="422" font-size="12" fill="#71717a" letter-spacing="${locale === 'zh' ? '1.2' : '3'}">${svgEscape(copy.lineup)}</text>
    ${
      locale === 'zh'
        ? renderZhNumberUnitText(lineupNumber, lineupUnit, 200, 442, copy.bodyFont, copy.titleFont)
        : `<text x="200" y="442" font-size="18" fill="#e4e4e7" letter-spacing="1.08">${safeLineup}</text>`
    }

    <text x="25" y="472" font-size="12" fill="#71717a" letter-spacing="${locale === 'zh' ? '1.2' : '3'}">${svgEscape(copy.venue)}</text>
    ${locale === 'zh' && hasLatinOrDigitText(safeVenueRaw)
      ? buildMixedFontText(safeVenueRaw, 25, 492, 17, '#e4e4e7', copy.bodyFont, copy.titleFont, '900', { zh: 0.18, latin: 0 })
      : `<text x="25" y="492" font-size="17" fill="#e4e4e7" letter-spacing="${locale === 'zh' ? '0.3' : '1.02'}">${safeVenue}</text>`}

    <text x="25" y="522" font-size="12" fill="#71717a" letter-spacing="${locale === 'zh' ? '1.2' : '3'}">${svgEscape(copy.presentedBy)}</text>
    ${
      locale === 'zh' && organizerSecondary
        ? `${buildMixedFontText(`${organizerParts[0] || ''} × `, 25, 542, 18, '#e4e4e7', copy.bodyFont, copy.titleFont, '900', 0.8)}
    <text x="102" y="542" font-family="${copy.titleFont}" font-size="18" fill="#e4e4e7" letter-spacing="1.08">${organizerSecondary}</text>`
        : locale === 'zh' && hasLatinOrDigitText(organizerRaw)
          ? buildMixedFontText(organizerRaw, 25, 542, 18, '#e4e4e7', copy.bodyFont, copy.titleFont, '900', 0.8)
          : `<text x="25" y="542" font-size="18" fill="#e4e4e7" letter-spacing="1.08">${svgEscape(organizerRaw)}</text>`
    }
  </g>

  <line x1="25" y1="560" x2="365" y2="560" stroke="rgba(255,255,255,0.1)" stroke-width="1"/>

  <g font-family="${copy.bodyFont}">
    <text x="25" y="587" font-weight="${locale === 'zh' ? '700' : '400'}" font-size="13" fill="#a1a1aa" letter-spacing="${locale === 'zh' ? '0.2' : '1.04'}">${svgEscape(moreInfoLine1)}</text>
    <text x="25" y="606" font-family="${copy.titleFont}" font-size="14" fill="#a1a1aa" letter-spacing="0.72">${svgEscape(moreInfoLine2)}</text>
  </g>

  <rect x="292" y="573" width="60" height="60" fill="#ffffff"/>
  <image href="${qrImageDataUrl}" x="292" y="573" width="60" height="60" preserveAspectRatio="none" />
</svg>`;

  try {
    const resvg = new Resvg(svg, {
      fitTo: {
        mode: 'width',
        value: 780,
      },
    });
    const poster = resvg.render().asPng();
    console.info(
      `[share-poster] code=${shareLink.code} targetType=${shareLink.targetType} svg-render success bytes=${poster.length} imageUrl=${event.imageUrl || 'none'}`
    );
    return Buffer.from(poster);
  } catch (error) {
    console.error(
      `[share-poster] code=${shareLink.code} targetType=${shareLink.targetType} svg-render failed imageUrl=${event.imageUrl || 'none'}`,
      error
    );
    return null;
  }
};

const drawDefaultPoster = async (shareLink: Awaited<ReturnType<typeof getRawShareLinkByCode>>): Promise<Buffer> => {
  const width = 900;
  const height = 1400;
  const png = new PNG({ width, height });
  const dark: RGB = [23, 23, 23];
  const muted: RGB = [82, 82, 82];
  const paper: RGB = [246, 242, 234];
  const accent: RGB = [221, 62, 44];
  const black: RGB = [0, 0, 0];
  const white: RGB = [255, 255, 255];

  fillRect(png, 0, 0, width, height, paper);
  fillRect(png, 0, 0, width, 260, dark);
  fillRect(png, 0, 260, width, 12, accent);
  drawText(png, 'RAVER', 70, 80, 12, white);
  drawText(png, shareLink.previewType.replace(/_/g, ' ').slice(0, 22), 72, 205, 4, [230, 230, 230]);

  const title = asciiText(shareLink.title, `${shareLink.targetType} ${shareLink.code}`);
  const subtitle = asciiText(shareLink.subtitle, 'OPEN RAVER TO VIEW THIS SHARE');
  wrapText(title, 18, 3).forEach((line, index) => drawText(png, line, 72, 340 + index * 78, 9, dark));
  wrapText(subtitle, 35, 4).forEach((line, index) => drawText(png, line, 76, 610 + index * 38, 5, muted));

  const qrText = buildShareShortUrl(shareLink.code);
  const qr = await QRCode.create(qrText, { errorCorrectionLevel: 'M' });
  const modules = qr.modules.size;
  const qrSize = 360;
  const cell = Math.floor(qrSize / modules);
  const actualQrSize = modules * cell;
  const qrX = Math.floor((width - actualQrSize) / 2);
  const qrY = 840;
  fillRect(png, qrX - 28, qrY - 28, actualQrSize + 56, actualQrSize + 56, white);
  for (let row = 0; row < modules; row += 1) {
    for (let col = 0; col < modules; col += 1) {
      if (qr.modules.get(row, col)) {
        fillRect(png, qrX + col * cell, qrY + row * cell, cell, cell, black);
      }
    }
  }

  drawText(png, 'SCAN TO OPEN', 245, 1255, 6, dark);
  drawText(png, `CODE ${shareLink.code}`, 250, 1315, 4, muted);

  return PNG.sync.write(png);
};

const drawEventAccessPassPoster = async (
  shareLink: Awaited<ReturnType<typeof getRawShareLinkByCode>>,
  event: SharePosterEventSnapshot
): Promise<Buffer> => {
  const width = 900;
  const height = 1400;
  const png = new PNG({ width, height });
  const black: RGB = [0, 0, 0];
  const zinc950: RGB = [9, 9, 11];
  const zinc800: RGB = [39, 39, 42];
  const zinc500: RGB = [113, 113, 122];
  const zinc300: RGB = [212, 212, 216];
  const red: RGB = [239, 68, 68];
  const white: RGB = [255, 255, 255];
  const cardX = 72;
  const cardY = 60;
  const cardWidth = width - cardX * 2;
  const cardHeight = height - 120;
  const heroHeight = 455;
  const heroBottom = cardY + 116 + heroHeight;

  fillRect(png, 0, 0, width, height, black);
  fillRect(png, cardX, cardY, cardWidth, cardHeight, zinc950);
  insetRect(png, cardX, cardY, cardWidth, cardHeight, zinc800, 2);
  fillRect(png, cardX, cardY, cardWidth, 116, [17, 17, 20]);
  drawHorizontalLine(png, cardX, cardY + 115, cardWidth, 1, white, 18);
  drawText(png, 'RAVEHUB ACCESS', cardX + 36, cardY + 34, 4, zinc300);

  fillVerticalGradient(png, cardX, cardY + 116, cardWidth, heroHeight, [34, 34, 36], [5, 5, 6]);
  const heroImage = await loadRemoteImagePng(event.imageUrl);
  if (heroImage) {
    overlayPngCover(png, heroImage, cardX, cardY + 116, cardWidth, heroHeight);
  }
  fillRect(png, cardX, cardY + 116, cardWidth, heroHeight, black, 92);
  fillRect(png, cardX, cardY + 116, cardWidth, heroHeight, red, 20);
  for (let row = 0; row < heroHeight; row += 1) {
    const alpha = Math.round((row / Math.max(1, heroHeight - 1)) * 165);
    fillRect(png, cardX, cardY + 116 + row, cardWidth, 1, black, alpha);
  }

  const glitchOffsets = [54, 122, 164, 218, 280, 346, 402];
  glitchOffsets.forEach((offset, index) => {
    drawHorizontalLine(
      png,
      cardX,
      cardY + 116 + offset,
      cardWidth,
      index % 3 === 0 ? 3 : (index % 2 === 0 ? 2 : 1),
      red,
      index % 2 === 0 ? 56 : 34
    );
  });

  const titleLines = wrapText(clampText(event.title, 34), 18, 3);
  titleLines.forEach((line, index) => {
    drawText(png, line, cardX + 34, cardY + 116 + heroHeight - 108 + index * 54, 6, white);
  });

  const notchTop = heroBottom;
  fillRect(png, cardX, notchTop, cardWidth, 22, black);
  const notchWidth = 24;
  for (let start = 0; start < cardWidth; start += notchWidth) {
    const centerX = cardX + start + Math.floor(notchWidth / 2);
    for (let row = 0; row < 12; row += 1) {
      const span = Math.max(1, 12 - row);
      fillRect(png, centerX - span, notchTop + row, span * 2, 1, zinc950);
    }
  }

  const contentTop = notchTop + 34;
  const leftColX = cardX + 40;
  const rightColX = cardX + 420;
  const rowGap = 126;

  const drawLabelValue = (label: string, value: string, x: number, y: number, maxChars = 18, maxLines = 2): void => {
    drawText(png, label, x, y, 3, zinc500);
    wrapText(clampText(value, maxChars), maxChars, maxLines).forEach((line, index) => {
      drawText(png, line, x, y + 42 + index * 32, 4, white);
    });
  };

  drawLabelValue('START', formatPosterDate(event.startDate, event.timeZone), leftColX, contentTop);
  drawLabelValue('END', formatPosterDate(event.endDate, event.timeZone), rightColX, contentTop);
  drawLabelValue('DURATION', formatPosterDuration(event.startDate, event.endDate, event.timeZone), leftColX, contentTop + rowGap);
  drawLabelValue('LINEUP', `${Math.max(0, event.artistCount)} ARTISTS`, rightColX, contentTop + rowGap);
  drawLabelValue('VENUE', event.venue || 'VENUE TBA', leftColX, contentTop + rowGap * 2, 34, 3);
  drawLabelValue('PRESENTED BY', event.organizer || 'RAVER', leftColX, contentTop + rowGap * 3, 34, 2);

  drawHorizontalLine(png, cardX + 40, cardY + cardHeight - 190, cardWidth - 80, 1, white, 24);
  drawText(png, 'RAVEHUB ACCESS', cardX + 40, cardY + cardHeight - 144, 3, zinc500);
  drawText(png, 'SCAN', cardX + 500, cardY + cardHeight - 144, 4, white);
  drawText(png, 'RAVEHUB APP', cardX + 500, cardY + cardHeight - 100, 3, zinc500);

  const qrText = buildShareShortUrl(shareLink.code);
  const qr = await QRCode.create(qrText, { errorCorrectionLevel: 'M' });
  const modules = qr.modules.size;
  const qrSize = 132;
  const cell = Math.max(2, Math.floor(qrSize / modules));
  const actualQrSize = modules * cell;
  const qrX = cardX + cardWidth - 40 - actualQrSize;
  const qrY = cardY + cardHeight - 156;
  fillRect(png, qrX - 12, qrY - 12, actualQrSize + 24, actualQrSize + 24, white);
  for (let row = 0; row < modules; row += 1) {
    for (let col = 0; col < modules; col += 1) {
      if (qr.modules.get(row, col)) {
        fillRect(png, qrX + col * cell, qrY + row * cell, cell, cell, black);
      }
    }
  }

  return PNG.sync.write(png);
};

const drawPoster = async (
  shareLink: Awaited<ReturnType<typeof getRawShareLinkByCode>>,
  locale: SharePosterLocale
): Promise<{ png: Buffer; mode: PosterRenderMode }> => {
  const eventSnapshot = await loadEventPosterSnapshot(shareLink);
  if (eventSnapshot) {
    console.info(
      `[share-poster] code=${shareLink.code} targetType=${shareLink.targetType} eventSnapshot loaded title="${eventSnapshot.title}" imageUrl=${eventSnapshot.imageUrl || 'none'}`
    );
    const renderedPoster = await renderEventPosterSvg(shareLink, eventSnapshot, locale);
    if (renderedPoster) {
      return { png: renderedPoster, mode: 'event_svg' };
    }
    console.warn(
      `[share-poster] code=${shareLink.code} targetType=${shareLink.targetType} fallback=event_fallback_png`
    );
    return {
      png: await drawEventAccessPassPoster(shareLink, eventSnapshot),
      mode: 'event_fallback_png',
    };
  }
  console.warn(
    `[share-poster] code=${shareLink.code} targetType=${shareLink.targetType} fallback=default_png reason=no_event_snapshot`
  );
  return { png: await drawDefaultPoster(shareLink), mode: 'default_png' };
};

router.get('/s/:code', async (req: Request, res: Response): Promise<void> => {
  try {
    const code = req.params.code as string;
    const shareLink = await getRawShareLinkByCode(prisma, code);
    const state = describeShareState(shareLink);
    const context = requestContext(req);

    await recordShareLinkEvent({
      prisma,
      code,
      eventType: 'open',
      channel: state.ok ? 'landing_open' : 'landing_error',
      platform: 'WebLanding',
      userAgent: context.userAgent,
      ipHash: context.ipHash,
      referrer: context.referrer,
      metadata: {
        targetType: shareLink.targetType,
        visibility: shareLink.visibility,
        status: shareLink.status,
        state: state.reason,
        suspiciousUserAgent: context.uaRisk.suspicious,
        suspiciousUserAgentReason: context.uaRisk.reason,
      },
    });

    res.status(state.statusCode).type('html').send(renderLandingPage(req, shareLink, state));
  } catch (error) {
    if (error instanceof ShareLinkError) {
      res.status(error.status).type('html').send(
        renderStatePage('链接不存在', '你访问的分享链接不存在，或已经被移除。')
      );
      return;
    }
    console.error('Public share landing error:', error);
    res.status(500).type('html').send(
      renderStatePage('打开失败', '链接暂时无法打开，请稍后再试。')
    );
  }
});

router.get('/s/:code/open', async (req: Request, res: Response): Promise<void> => {
  try {
    const code = req.params.code as string;
    const shareLink = await getRawShareLinkByCode(prisma, code);
    const state = describeShareState(shareLink);

    if (!state.ok) {
      res.status(state.statusCode).type('html').send(renderLandingPage(req, shareLink, state));
      return;
    }

    const context = requestContext(req);
    await recordShareLinkEvent({
      prisma,
      code,
      eventType: 'redirect',
      channel: 'open_app_button',
      platform: 'WebLanding',
      userAgent: context.userAgent,
      ipHash: context.ipHash,
      referrer: context.referrer,
      metadata: {
        targetType: shareLink.targetType,
        visibility: shareLink.visibility,
        destination: 'deep_link',
        suspiciousUserAgent: context.uaRisk.suspicious,
        suspiciousUserAgentReason: context.uaRisk.reason,
      },
    });

    res.redirect(302, appendShareCode(shareLink.deepLink || shareLink.canonicalUrl, shareLink.code));
  } catch (error) {
    if (error instanceof ShareLinkError) {
      res.status(error.status).type('html').send(
        renderStatePage('链接不存在', '你访问的分享链接不存在，或已经被移除。')
      );
      return;
    }
    console.error('Public share redirect error:', error);
    res.status(500).type('html').send(
      renderStatePage('打开失败', '链接暂时无法打开，请稍后再试。')
    );
  }
});

router.get('/s/:code/download', async (req: Request, res: Response): Promise<void> => {
  try {
    const code = req.params.code as string;
    const shareLink = await getRawShareLinkByCode(prisma, code);
    const context = requestContext(req);

    await recordShareLinkEvent({
      prisma,
      code,
      eventType: 'install_click',
      channel: 'download_app_button',
      platform: 'WebLanding',
      userAgent: context.userAgent,
      ipHash: context.ipHash,
      referrer: context.referrer,
      metadata: {
        targetType: shareLink.targetType,
        visibility: shareLink.visibility,
        suspiciousUserAgent: context.uaRisk.suspicious,
        suspiciousUserAgentReason: context.uaRisk.reason,
      },
    });

    res.redirect(302, APP_DOWNLOAD_URL);
  } catch (error) {
    if (error instanceof ShareLinkError) {
      res.redirect(302, APP_DOWNLOAD_URL);
      return;
    }
    console.error('Public share download redirect error:', error);
    res.redirect(302, APP_DOWNLOAD_URL);
  }
});

router.get('/qr/:code.png', async (req: Request, res: Response): Promise<void> => {
  try {
    const code = req.params.code as string;
    const shareLink = await getRawShareLinkByCode(prisma, code);

    if (shareLink.status !== 'active') {
      res.status(410).type('html').send(
        renderStatePage('二维码已失效', '这个二维码对应的分享链接已经不可用。')
      );
      return;
    }

    const qrBuffer = await QRCode.toBuffer(buildShareShortUrl(shareLink.code), {
      errorCorrectionLevel: 'H',
      margin: 2,
      type: 'png',
      width: 512,
      color: {
        dark: '#111827',
        light: '#FFFFFFFF',
      },
    });

    const png = PNG.sync.read(qrBuffer);
    const appIcon = loadAppIconPng();
    if (appIcon) {
      const logoSize = Math.round(png.width * 0.18);
      const logoX = Math.floor((png.width - logoSize) / 2);
      const logoY = Math.floor((png.height - logoSize) / 2);
      overlayPngScaled(png, appIcon, logoX, logoY, logoSize, logoSize);
    }

    res.setHeader('Content-Type', 'image/png');
    res.setHeader('Cache-Control', 'public, max-age=300');
    res.send(PNG.sync.write(png));
  } catch (error) {
    if (error instanceof ShareLinkError) {
      res.status(error.status).type('html').send(
        renderStatePage('二维码不存在', '你访问的二维码不存在，或已经被移除。')
      );
      return;
    }
    console.error('Public share QR error:', error);
    res.status(500).type('html').send(
      renderStatePage('二维码生成失败', '二维码暂时无法生成，请稍后再试。')
    );
  }
});

router.get('/poster/:code.png', async (req: Request, res: Response): Promise<void> => {
  try {
    const code = req.params.code as string;
    const shareLink = await getRawShareLinkByCode(prisma, code);
    const state = describeShareState(shareLink);
    const locale = normalizePosterLocale(req.headers['accept-language']);
    console.info(
      `[share-poster] code=${code} route-hit targetType=${shareLink.targetType} status=${shareLink.status} locale=${locale} host=${req.get('host') || 'unknown'} ua=${req.get('user-agent') || 'unknown'}`
    );

    if (!state.ok) {
      console.warn(
        `[share-poster] code=${code} route-blocked reason=${state.reason} statusCode=${state.statusCode}`
      );
      res.status(state.statusCode).type('html').send(renderLandingPage(req, shareLink, state));
      return;
    }

    const { png, mode } = await drawPoster(shareLink, locale);
    console.info(
      `[share-poster] code=${code} route-success mode=${mode} bytes=${png.length}`
    );
    res.setHeader('Content-Type', 'image/png');
    res.setHeader('Cache-Control', 'public, max-age=300');
    res.send(png);
  } catch (error) {
    if (error instanceof ShareLinkError) {
      res.status(error.status).type('html').send(
        renderStatePage('海报不存在', '你访问的分享海报不存在，或已经被移除。')
      );
      return;
    }
    console.error('Public share poster error:', error);
    res.status(500).type('html').send(
      renderStatePage('海报生成失败', '分享海报暂时无法生成，请稍后再试。')
    );
  }
});

export default router;
