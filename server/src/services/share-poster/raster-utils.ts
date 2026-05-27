import fs from 'fs';
import path from 'path';
import jpeg from 'jpeg-js';
import { PNG } from 'pngjs';

type RGB = [number, number, number];

const APP_ICON_PATH = path.resolve(
  __dirname,
  '../../../../mobile/ios/RaverMVP/RaverMVP/Assets.xcassets/AppIcon.appiconset/icon-60@3x.png'
);
const isLikelyAliyunOssHost = (hostname: string): boolean => {
  const normalized = String(hostname || '').trim().toLowerCase();
  return normalized.includes('aliyuncs.com') || normalized.includes('ravehub.top');
};

const buildPosterFetchUrl = (rawUrl: string): string => {
  try {
    const parsed = new URL(rawUrl);
    const pathname = parsed.pathname.toLowerCase();
    const isWebpLike = pathname.endsWith('.webp') || parsed.searchParams.get('x-oss-process')?.includes('format,webp');
    if (isLikelyAliyunOssHost(parsed.hostname) && isWebpLike) {
      parsed.searchParams.set('x-oss-process', 'image/format,png');
      return parsed.toString();
    }
    return rawUrl;
  } catch {
    return rawUrl;
  }
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

export const asciiText = (value: string | null | undefined, fallback: string): string => {
  const normalized = String(value || '')
    .replace(/[^\x20-\x7E]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  return normalized || fallback;
};

export const clampText = (value: string, maxLength: number): string => {
  const normalized = value.trim();
  if (normalized.length <= maxLength) return normalized;
  return `${normalized.slice(0, Math.max(0, maxLength - 1))}…`;
};

export const wrapAsciiText = (value: string, maxChars: number, maxLines: number): string[] => {
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

export const setPixel = (png: PNG, x: number, y: number, color: RGB, alpha = 255): void => {
  if (x < 0 || y < 0 || x >= png.width || y >= png.height) return;
  const index = (png.width * y + x) << 2;
  png.data[index] = color[0];
  png.data[index + 1] = color[1];
  png.data[index + 2] = color[2];
  png.data[index + 3] = alpha;
};

export const fillRect = (png: PNG, x: number, y: number, width: number, height: number, color: RGB, alpha = 255): void => {
  for (let row = y; row < y + height; row += 1) {
    for (let col = x; col < x + width; col += 1) {
      setPixel(png, col, row, color, alpha);
    }
  }
};

export const drawHorizontalLine = (png: PNG, x: number, y: number, width: number, thickness: number, color: RGB, alpha = 255): void => {
  fillRect(png, x, y, width, Math.max(1, thickness), color, alpha);
};

export const drawVerticalLine = (png: PNG, x: number, y: number, thickness: number, height: number, color: RGB, alpha = 255): void => {
  fillRect(png, x, y, Math.max(1, thickness), height, color, alpha);
};

export const insetRect = (
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

export const fillVerticalGradient = (
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

export const drawText = (png: PNG, text: string, x: number, y: number, scale: number, color: RGB): void => {
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

export const loadAppIconPng = (() => {
  let cached: PNG | null | undefined;
  return (): PNG | null => {
    if (cached !== undefined) return cached;
    try {
      const bytes = fs.readFileSync(APP_ICON_PATH);
      cached = PNG.sync.read(bytes);
      return cached;
    } catch {
      cached = null;
      return cached;
    }
  };
})();

export const blendPixel = (
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

export const overlayPngScaled = (
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

export const decodeImageToPng = (buffer: Buffer, contentType?: string | null): PNG | null => {
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
      const png = new PNG({ width: decoded.width, height: decoded.height });
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
      const png = new PNG({ width: decoded.width, height: decoded.height });
      png.data = Buffer.from(decoded.data);
      return png;
    } catch {
      return null;
    }
  }
};

export const loadRemoteImagePng = async (urlString: string | null | undefined): Promise<PNG | null> => {
  const normalized = String(urlString || '').trim();
  if (!/^https?:\/\//i.test(normalized)) return null;
  try {
    const response = await fetch(buildPosterFetchUrl(normalized));
    if (!response.ok) return null;
    const arrayBuffer = await response.arrayBuffer();
    return decodeImageToPng(Buffer.from(arrayBuffer), response.headers.get('content-type'));
  } catch {
    return null;
  }
};

export const overlayPngCover = (
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
      const srcX = Math.min(source.width - 1, Math.max(0, Math.floor(cropX + (col / width) * cropWidth)));
      const srcY = Math.min(source.height - 1, Math.max(0, Math.floor(cropY + (row / height) * cropHeight)));
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
