import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { Request, Response, Router } from 'express';
import { PrismaClient } from '@prisma/client';
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

const asciiText = (value: string | null | undefined, fallback: string): string => {
  const normalized = String(value || '')
    .replace(/[^\x20-\x7E]/g, '')
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

const drawPoster = async (shareLink: Awaited<ReturnType<typeof getRawShareLinkByCode>>): Promise<Buffer> => {
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

    if (!state.ok) {
      res.status(state.statusCode).type('html').send(renderLandingPage(req, shareLink, state));
      return;
    }

    const png = await drawPoster(shareLink);
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
