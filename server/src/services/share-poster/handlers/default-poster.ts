import QRCode from 'qrcode';
import { PNG } from 'pngjs';
import { SharePosterHandler } from '../types';
import { buildShareShortUrl } from '../../share-link.service';
import {
  asciiText,
  clampText,
  drawText,
  fillRect,
  loadAppIconPng,
  overlayPngScaled,
  wrapAsciiText,
} from '../raster-utils';

const drawDefaultPoster = async (shareLink: any): Promise<Buffer> => {
  const width = 900;
  const height = 1400;
  const png = new PNG({ width, height });
  const dark: [number, number, number] = [23, 23, 23];
  const muted: [number, number, number] = [82, 82, 82];
  const paper: [number, number, number] = [246, 242, 234];
  const accent: [number, number, number] = [221, 62, 44];
  const black: [number, number, number] = [0, 0, 0];
  const white: [number, number, number] = [255, 255, 255];

  fillRect(png, 0, 0, width, height, paper);
  fillRect(png, 0, 0, width, 260, dark);
  fillRect(png, 0, 260, width, 12, accent);
  drawText(png, 'RAVER', 70, 80, 12, white);
  drawText(png, String(shareLink.previewType || '').replace(/_/g, ' ').slice(0, 22), 72, 205, 4, [230, 230, 230]);

  const title = asciiText(shareLink.title, `${shareLink.targetType} ${shareLink.code}`);
  const subtitle = asciiText(shareLink.subtitle, 'OPEN RAVER TO VIEW THIS SHARE');
  wrapAsciiText(title, 18, 3).forEach((line, index) => drawText(png, line, 72, 340 + index * 78, 9, dark));
  wrapAsciiText(subtitle, 35, 4).forEach((line, index) => drawText(png, line, 76, 610 + index * 38, 5, muted));

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

  const appIcon = loadAppIconPng();
  if (appIcon) {
    const logoSize = Math.round(actualQrSize * 0.18);
    const logoX = Math.floor(qrX + (actualQrSize - logoSize) / 2);
    const logoY = Math.floor(qrY + (actualQrSize - logoSize) / 2);
    overlayPngScaled(png, appIcon, logoX, logoY, logoSize, logoSize);
  }

  drawText(png, 'SCAN TO OPEN', 245, 1255, 6, dark);
  drawText(png, `CODE ${clampText(shareLink.code, 8)}`, 250, 1315, 4, muted);
  return PNG.sync.write(png);
};

export const defaultPosterHandler: SharePosterHandler = {
  id: 'default',
  supports: () => true,
  async render(context) {
    const png = await drawDefaultPoster(context.shareLink);
    return {
      png,
      mode: 'default_png',
      handlerId: 'default',
      variant: context.variant,
    };
  },
};
