import { Request, Response, Router } from 'express';
import { PrismaClient } from '@prisma/client';
import QRCode from 'qrcode';
import {
  buildShareShortUrl,
  getRawShareLinkByCode,
  recordShareLinkEvent,
  ShareLinkError,
} from '../services/share-link.service';

const router: Router = Router();
const prisma = new PrismaClient();

const renderStatePage = (title: string, description: string, primaryURL?: string | null): string => {
  const button = primaryURL
    ? `<a href="${primaryURL}" style="display:inline-block;padding:12px 18px;background:#111827;color:#fff;text-decoration:none;border-radius:999px;">打开 Raver</a>`
    : '';

  return `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${title}</title>
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
        <h1>${title}</h1>
        <p>${description}</p>
        ${button}
      </section>
    </main>
  </body>
</html>`;
};

router.get('/s/:code', async (req: Request, res: Response): Promise<void> => {
  try {
    const code = req.params.code as string;
    const shareLink = await getRawShareLinkByCode(prisma, code);

    if (shareLink.status !== 'active') {
      res.status(410).type('html').send(
        renderStatePage('链接已失效', '这个分享链接已经不可用。请返回 Raver 获取新的分享链接。')
      );
      return;
    }

    if (shareLink.expiresAt && shareLink.expiresAt.getTime() <= Date.now()) {
      res.status(410).type('html').send(
        renderStatePage('邀请已过期', '这个邀请链接已经过期。请联系分享者重新生成邀请。')
      );
      return;
    }

    if (shareLink.maxUses !== null && shareLink.maxUses !== undefined && shareLink.usedCount >= shareLink.maxUses) {
      res.status(410).type('html').send(
        renderStatePage('邀请已用完', '这个邀请链接的可用次数已经耗尽。请联系分享者重新生成邀请。')
      );
      return;
    }

    await recordShareLinkEvent({
      prisma,
      code,
      eventType: 'open',
      channel: 'external_open',
      platform: 'WebLanding',
      userAgent: typeof req.headers['user-agent'] === 'string' ? req.headers['user-agent'] : null,
      referrer: typeof req.headers.referer === 'string' ? req.headers.referer : null,
    });

    res.redirect(302, shareLink.canonicalUrl);
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

    const png = await QRCode.toBuffer(buildShareShortUrl(shareLink.code), {
      errorCorrectionLevel: 'M',
      margin: 2,
      type: 'png',
      width: 512,
      color: {
        dark: '#111827',
        light: '#FFFFFFFF',
      },
    });

    res.setHeader('Content-Type', 'image/png');
    res.setHeader('Cache-Control', 'public, max-age=300');
    res.send(png);
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

export default router;
