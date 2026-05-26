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

const formatPosterVenueText = (value: string): string =>
  String(value || '')
    .replace(/\s*,\s*/g, ', ')
    .replace(/\s+/g, ' ')
    .trim();

const localizedValueFromRecord = (record: Record<string, unknown>, locale: SharePosterLocale): string | null => {
  const keysByLocale: Record<SharePosterLocale, string[]> = {
    zh: ['zh', 'zh-CN', 'zh-Hans', 'zh_CN', 'zh_Hans'],
    en: ['enFull', 'en', 'en-US', 'en_US'],
  };
  const fallbackKeys = ['zh', 'enFull', 'en', 'ja'];
  for (const key of [...keysByLocale[locale], ...fallbackKeys]) {
    const text = normalizeEventText(record[key]);
    if (text) return text;
  }
  return null;
};

const readLocalizedAddressText = (
  value: unknown,
  field: 'formattedAddressI18n' | 'detailAddressI18n',
  locale: SharePosterLocale
): string | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const source = (value as Record<string, unknown>)[field];
  if (!source || typeof source !== 'object' || Array.isArray(source)) return null;
  const record = source as Record<string, unknown>;
  return localizedValueFromRecord(record, locale);
};

const resolvePosterVenueText = (event: {
  venueName?: string | null;
  venueAddress?: string | null;
  city?: string | null;
  country?: string | null;
  cityI18n?: unknown;
  countryI18n?: unknown;
  manualLocation?: unknown;
  locationPoint?: unknown;
}, locale: SharePosterLocale): string | null => {
  const cityText =
    event.cityI18n && typeof event.cityI18n === 'object' && !Array.isArray(event.cityI18n)
      ? localizedValueFromRecord(event.cityI18n as Record<string, unknown>, locale) ?? normalizeEventText(event.city)
      : normalizeEventText(event.city);
  const countryText =
    event.countryI18n && typeof event.countryI18n === 'object' && !Array.isArray(event.countryI18n)
      ? localizedValueFromRecord(event.countryI18n as Record<string, unknown>, locale) ?? normalizeEventText(event.country)
      : normalizeEventText(event.country);
  const unified = readLocalizedAddressText(event.manualLocation, 'formattedAddressI18n', locale)
    ?? readLocalizedAddressText(event.locationPoint, 'formattedAddressI18n', locale)
    ?? readLocalizedAddressText(event.manualLocation, 'detailAddressI18n', locale)
    ?? cityText
    ?? countryText;
  return unified ? formatPosterVenueText(unified) : null;
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

const normalizePosterLocale = (
  localeInput: unknown,
  acceptLanguage: string | string[] | undefined
): SharePosterLocale => {
  const localeRaw = String(localeInput || '').trim().toLowerCase();
  if (localeRaw.startsWith('zh')) return 'zh';
  if (localeRaw.startsWith('en')) return 'en';
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
  organizer: string | null;
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
        titleFont: "'站酷高端黑', 'Alibaba PuHuiTi', 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans SC', sans-serif",
        bodyFont: "'站酷高端黑', 'Alibaba PuHuiTi', 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans SC', sans-serif",
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
        titleFont: "'站酷高端黑', 'Alibaba PuHuiTi', 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans SC', sans-serif",
        bodyFont: "'站酷高端黑', 'Alibaba PuHuiTi', 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans SC', sans-serif",
      };

const renderZhDateText = (
  date: Date | null,
  timeZone: string,
  x: number,
  y: number,
  bodyFont: string
): string => {
  const parts = formatPosterDateParts(date, timeZone);
  if (!parts) {
    return `<text x="${x}" y="${y}" font-family="${bodyFont}" font-weight="900" font-size="18" fill="#e4e4e7">待定</text>`;
  }
  return `<text x="${x}" y="${y}" font-family="${bodyFont}" font-weight="900" font-size="18" fill="#e4e4e7" letter-spacing="0">${svgEscape(`${parts.year}年 ${parts.month}月${parts.day}日`)}</text>`;
};

const renderZhNumberUnitText = (
  numberText: string,
  unitText: string,
  x: number,
  y: number,
  bodyFont: string
): string => {
  return `<text x="${x}" y="${y}" font-family="${bodyFont}" font-weight="900" font-size="18" fill="#e4e4e7" letter-spacing="0">${svgEscape(`${numberText}${unitText ? ` ${unitText}` : ''}`.trim())}</text>`;
};

const estimatePosterLineWidth = (value: string, fontSize: number): number => {
  let width = 0;
  for (const char of value) {
    if (char === ' ') {
      width += fontSize * 0.34;
    } else if (/[A-Z0-9]/.test(char)) {
      width += fontSize * 0.66;
    } else if (/[a-z]/.test(char)) {
      width += fontSize * 0.56;
    } else if (/[.,:;!?'’"()\-·/&]/.test(char)) {
      width += fontSize * 0.3;
    } else {
      width += fontSize * 0.94;
    }
  }
  return width;
};

const wrapPosterMixedText = (value: string, maxWidth: number, fontSize: number, maxLines: number): string[] => {
  const normalized = String(value || '').replace(/\s+/g, ' ').trim();
  if (!normalized) return [''];

  const tokens = normalized.match(/([A-Za-z0-9]+|[\u3400-\u9FFF]|[^\s])/g) || [normalized];
  const lines: string[] = [];
  let current = '';

  for (const token of tokens) {
    const glue = current && /^[A-Za-z0-9]+$/.test(token) && /[A-Za-z0-9]$/.test(current) ? ' ' : '';
    const candidate = `${current}${glue}${token}`;
    if (!current || estimatePosterLineWidth(candidate, fontSize) <= maxWidth) {
      current = candidate;
      continue;
    }
    lines.push(current);
    if (lines.length >= maxLines) break;
    current = token;
  }

  if (current && lines.length < maxLines) {
    lines.push(current);
  }

  const fitted = lines.slice(0, maxLines);
  const consumed = fitted.join('').replace(/\s+/g, '');
  const original = tokens.join('').replace(/\s+/g, '');
  const truncated = original.length > consumed.length || lines.length > maxLines;

  if (truncated && fitted.length > 0) {
    let lastLine = fitted[fitted.length - 1];
    while (lastLine && estimatePosterLineWidth(`${lastLine}…`, fontSize) > maxWidth) {
      lastLine = lastLine.slice(0, -1).trimEnd();
    }
    fitted[fitted.length - 1] = lastLine ? `${lastLine}…` : '…';
  }
  return fitted;
};

const renderPosterTextBlock = (
  lines: string[],
  x: number,
  y: number,
  fontFamily: string,
  fontSize: number,
  lineHeight: number,
  fill: string,
  letterSpacing: number,
  fontWeight = '900'
): string =>
  lines
    .map(
      (line, index) =>
        `<text x="${x}" y="${y + index * lineHeight}" font-family="${fontFamily}" font-weight="${fontWeight}" font-size="${fontSize}" fill="${fill}" letter-spacing="${letterSpacing}">${svgEscape(line)}</text>`
    )
    .join('');

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
  shareLink: Awaited<ReturnType<typeof getRawShareLinkByCode>>,
  locale: SharePosterLocale
): Promise<SharePosterEventSnapshot | null> => {
  if (shareLink.targetType !== 'event') return null;

  const event = await prisma.event.findUnique({
    where: { id: shareLink.targetId },
    select: {
      name: true,
      nameI18n: true,
      venueName: true,
      venueAddress: true,
      city: true,
      cityI18n: true,
      country: true,
      countryI18n: true,
      manualLocation: true,
      locationPoint: true,
      startDate: true,
      endDate: true,
      timeZone: true,
      coverImageUrl: true,
      lineupImageUrl: true,
      imageAssets: true,
      wikiFestival: {
        select: {
          name: true,
          nameI18n: true,
        },
      },
      _count: {
        select: {
          canonicalArtists: true,
        },
      },
    },
  });

  if (!event) return null;

  const localizedTitle =
    event.nameI18n && typeof event.nameI18n === 'object' && !Array.isArray(event.nameI18n)
      ? localizedValueFromRecord(event.nameI18n as Record<string, unknown>, locale) ?? normalizeEventText(event.name)
      : normalizeEventText(event.name);
  const localizedOrganizer =
    event.wikiFestival?.nameI18n &&
    typeof event.wikiFestival.nameI18n === 'object' &&
    !Array.isArray(event.wikiFestival.nameI18n)
      ? localizedValueFromRecord(event.wikiFestival.nameI18n as Record<string, unknown>, locale) ?? normalizeEventText(event.wikiFestival.name)
      : normalizeEventText(event.wikiFestival?.name);
  const venue = posterText(resolvePosterVenueText(event, locale), locale === 'zh' ? '待定' : 'Venue TBA');

  return {
    title: posterText(localizedTitle || shareLink.title, posterText(shareLink.title, `Event ${shareLink.code}`)),
    venue,
    organizer: localizedOrganizer,
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
  const titleSource = locale === 'zh' ? (event.title || shareLink.title || '') : (event.title || shareLink.title || '').toUpperCase();
  const titleFontSize = 28;
  const titleMaxWidth = 278;
  const titleLines = wrapPosterMixedText(titleSource, titleMaxWidth, titleFontSize, 3);
  const titleLineHeight = 30;
  const titleBottomY = 350;
  const titleStartY = titleBottomY - (Math.max(titleLines.length, 1) - 1) * titleLineHeight;
  const titleBlock = titleLines
    .map((line, index) => {
      const y = titleStartY + index * titleLineHeight;
      const letterSpacing = locale === 'zh' ? '1.2' : '0.8';
      return `<text x="25" y="${y}" font-family="${copy.titleFont}" font-weight="900" font-size="${titleFontSize}" letter-spacing="${letterSpacing}" fill="#fff">${svgEscape(line)}</text>`;
    })
    .join('');
  const durationMatch = safeDuration.match(/^(\d+)\s*(.*)$/);
  const durationNumber = durationMatch?.[1] || safeDuration;
  const durationUnit = durationMatch?.[2] || '';
  const lineupMatch = safeLineup.match(/^(\d+)\s*(.*)$/);
  const lineupNumber = lineupMatch?.[1] || safeLineup;
  const lineupUnit = lineupMatch?.[2] || '';
  const venueLines = wrapPosterMixedText(formatPosterVenueText(safeVenueRaw), 302, 16, 3);
  const venueValueY = 492;
  const venueLineHeight = 22;
  const venueBottomY = venueValueY + (venueLines.length - 1) * venueLineHeight;
  const organizerRaw = normalizeEventText(event.organizer);
  const organizerLines = organizerRaw ? wrapPosterMixedText(organizerRaw, 338, 18, 3) : [];
  const organizerLabelY = venueBottomY + 34;
  const organizerValueY = organizerLabelY + 20;
  const organizerLineHeight = 24;
  const organizerBottomY = organizerLines.length > 0
    ? organizerValueY + (organizerLines.length - 1) * organizerLineHeight
    : venueBottomY;
  const dividerY = (organizerLines.length > 0 ? organizerBottomY : venueBottomY) + 28;
  const footerLine1Y = dividerY + 27;
  const footerLine2Y = footerLine1Y + 19;
  const qrY = dividerY + 13;
  const moreInfoLine1 = locale === 'zh' ? '更多活动与艺人信息请扫码查看' : 'SCAN FOR MORE EVENTS &';
  const moreInfoLine2 = locale === 'zh' ? 'RaveHub App' : 'LINEUP INFO ON RAVEHUB APP';

  const svg = `
<svg xmlns="http://www.w3.org/2000/svg" width="390" height="700" viewBox="0 0 390 700">
  <defs>
    <clipPath id="heroClip">
      <rect x="0" y="60" width="390" height="300" />
    </clipPath>
    <linearGradient id="titleMask" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#000" stop-opacity="0"/>
      <stop offset="52%" stop-color="#000" stop-opacity="0"/>
      <stop offset="100%" stop-color="#000" stop-opacity="0.82"/>
    </linearGradient>
  </defs>
  <rect width="390" height="700" rx="30" fill="#0f0f11" stroke="#27272a" stroke-width="1"/>

  <rect x="0" y="0" width="390" height="60" fill="rgba(255,255,255,0.03)"/>
  <line x1="0" y1="60" x2="390" y2="60" stroke="rgba(255,255,255,0.05)" stroke-width="1"/>
  <text x="25" y="38" font-family="${copy.titleFont}" font-size="16" fill="#d4d4d8" letter-spacing="4.3">RAVEHUB ACCESS</text>

  <rect x="0" y="60" width="390" height="300" fill="#18181b"/>
  ${
    heroImageDataUrl
      ? `<image href="${heroImageDataUrl}" x="0" y="60" width="390" height="300" preserveAspectRatio="xMidYMid slice" clip-path="url(#heroClip)" />`
      : ''
  }
  <rect x="0" y="60" width="390" height="300" fill="url(#titleMask)"/>

  <g>${titleBlock}</g>

  <g font-family="${copy.bodyFont}">
    <text x="25" y="372" font-size="12" fill="#71717a" letter-spacing="${locale === 'zh' ? '1.2' : '3'}">${svgEscape(copy.start)}</text>
    ${locale === 'zh'
      ? renderZhDateText(event.startDate, event.timeZone, 25, 392, copy.bodyFont)
      : `<text x="25" y="392" font-size="18" fill="#e4e4e7" letter-spacing="1.08">${safeStart}</text>`}

    <text x="200" y="372" font-size="12" fill="#71717a" letter-spacing="${locale === 'zh' ? '1.2' : '3'}">${svgEscape(copy.end)}</text>
    ${locale === 'zh'
      ? renderZhDateText(event.endDate, event.timeZone, 200, 392, copy.bodyFont)
      : `<text x="200" y="392" font-size="18" fill="#e4e4e7" letter-spacing="1.08">${safeEnd}</text>`}

    <text x="25" y="422" font-size="12" fill="#71717a" letter-spacing="${locale === 'zh' ? '1.2' : '3'}">${svgEscape(copy.duration)}</text>
    ${
      locale === 'zh'
        ? renderZhNumberUnitText(durationNumber, durationUnit, 25, 442, copy.bodyFont)
        : `<text x="25" y="442" font-size="18" fill="#e4e4e7" letter-spacing="1.08">${safeDuration}</text>`
    }

    <text x="200" y="422" font-size="12" fill="#71717a" letter-spacing="${locale === 'zh' ? '1.2' : '3'}">${svgEscape(copy.lineup)}</text>
    ${
      locale === 'zh'
        ? renderZhNumberUnitText(lineupNumber, lineupUnit, 200, 442, copy.bodyFont)
        : `<text x="200" y="442" font-size="18" fill="#e4e4e7" letter-spacing="1.08">${safeLineup}</text>`
    }

    <text x="25" y="472" font-size="12" fill="#71717a" letter-spacing="${locale === 'zh' ? '1.2' : '3'}">${svgEscape(copy.venue)}</text>
    ${renderPosterTextBlock(venueLines, 25, venueValueY, copy.bodyFont, 16, venueLineHeight, '#e4e4e7', 0)}

    ${organizerLines.length > 0
      ? `
    <text x="25" y="${organizerLabelY}" font-size="12" fill="#71717a" letter-spacing="${locale === 'zh' ? '1.2' : '3'}">${svgEscape(copy.presentedBy)}</text>
    ${renderPosterTextBlock(organizerLines, 25, organizerValueY, copy.bodyFont, 18, organizerLineHeight, '#e4e4e7', 0)}`
      : ''}
  </g>

  <line x1="25" y1="${dividerY}" x2="365" y2="${dividerY}" stroke="rgba(255,255,255,0.1)" stroke-width="1"/>

  <g font-family="${copy.bodyFont}">
    <text x="25" y="${footerLine1Y}" font-weight="${locale === 'zh' ? '700' : '400'}" font-size="13" fill="#a1a1aa" letter-spacing="${locale === 'zh' ? '0.2' : '1.04'}">${svgEscape(moreInfoLine1)}</text>
    <text x="25" y="${footerLine2Y}" font-family="${copy.titleFont}" font-size="14" fill="#a1a1aa" letter-spacing="0.72">${svgEscape(moreInfoLine2)}</text>
  </g>

  <rect x="292" y="${qrY}" width="60" height="60" fill="#ffffff"/>
  <image href="${qrImageDataUrl}" x="292" y="${qrY}" width="60" height="60" preserveAspectRatio="none" />
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
  const eventSnapshot = await loadEventPosterSnapshot(shareLink, locale);
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
    const locale = normalizePosterLocale(req.query.locale, req.headers['accept-language']);
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
