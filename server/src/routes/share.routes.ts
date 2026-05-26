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
import { normalizePosterLocale, normalizePosterVariant, renderSharePoster } from '../services/share-poster';

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
    const variant = normalizePosterVariant(req.query.variant);
    console.info(
      `[share-poster] code=${code} route-hit targetType=${shareLink.targetType} status=${shareLink.status} locale=${locale} variant=${variant || 'default'} host=${req.get('host') || 'unknown'} ua=${req.get('user-agent') || 'unknown'}`
    );

    if (!state.ok) {
      console.warn(
        `[share-poster] code=${code} route-blocked reason=${state.reason} statusCode=${state.statusCode}`
      );
      res.status(state.statusCode).type('html').send(renderLandingPage(req, shareLink, state));
      return;
    }

    const { png, mode, handlerId } = await renderSharePoster({
      prisma,
      shareLink,
      locale,
      variant,
    });
    console.info(
      `[share-poster] code=${code} route-success mode=${mode} handler=${handlerId} bytes=${png.length}`
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
