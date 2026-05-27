import fs from 'fs';
import path from 'path';
import { Resvg } from '@resvg/resvg-js';
import QRCode from 'qrcode';
import { buildShareShortUrl } from '../share-link.service';
import { excerpt, singleLine } from './localization';
import { SharePosterLocale, SharePosterSectionRow, SharePosterStructuredCardInput } from './types';

const APP_ICON_PATH = path.resolve(
  __dirname,
  '../../../../mobile/ios/RaverMVP/RaverMVP/Assets.xcassets/AppIcon.appiconset/icon-60@3x.png'
);
const POSTER_QR_SIZE = 72;
const POSTER_QR_X = 280;
const POSTER_QR_ICON_BOX_SIZE = 20;
const POSTER_QR_ICON_SIZE = 16;

const isLikelyAliyunOssHost = (hostname: string): boolean => {
  const normalized = String(hostname || '').trim().toLowerCase();
  return normalized.includes('aliyuncs.com') || normalized.includes('ravehub.top');
};

const buildPosterFetchUrl = (rawUrl: string): { url: string; transformed: boolean; reason: string | null } => {
  try {
    const parsed = new URL(rawUrl);
    const pathname = parsed.pathname.toLowerCase();
    const isWebpLike = pathname.endsWith('.webp') || parsed.searchParams.get('x-oss-process')?.includes('format,webp');
    if (isLikelyAliyunOssHost(parsed.hostname) && isWebpLike) {
      parsed.searchParams.set('x-oss-process', 'image/format,png');
      return {
        url: parsed.toString(),
        transformed: true,
        reason: 'oss_webp_to_png',
      };
    }
    return { url: rawUrl, transformed: false, reason: null };
  } catch {
    return { url: rawUrl, transformed: false, reason: 'invalid_url_parse' };
  }
};

export const htmlEscape = (value: string | null | undefined): string =>
  String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

export const svgEscape = (value: string | null | undefined): string => htmlEscape(value);

export const toImageDataUri = async (
  urlString: string | null | undefined,
  options?: {
    debugLabel?: string;
  }
): Promise<string | null> => {
  const normalized = String(urlString || '').trim();
  const debugLabel = options?.debugLabel || 'share-poster-image';
  if (!/^https?:\/\//i.test(normalized)) {
    console.warn(
      `[share-poster] ${debugLabel} image-fetch skipped reason=invalid_url url=${normalized || 'empty'}`
    );
    return null;
  }
  const fetchTarget = buildPosterFetchUrl(normalized);
  if (fetchTarget.transformed) {
    console.info(
      `[share-poster] ${debugLabel} image-fetch rewrite reason=${fetchTarget.reason} originalUrl=${normalized} fetchUrl=${fetchTarget.url}`
    );
  }
  try {
    const response = await fetch(fetchTarget.url);
    const contentType = response.headers.get('content-type') || 'unknown';
    if (!response.ok) {
      console.warn(
        `[share-poster] ${debugLabel} image-fetch failed status=${response.status} contentType=${contentType} url=${fetchTarget.url} originalUrl=${normalized}`
      );
      return null;
    }
    const arrayBuffer = await response.arrayBuffer();
    const byteLength = arrayBuffer.byteLength;
    if (byteLength <= 0) {
      console.warn(
        `[share-poster] ${debugLabel} image-fetch failed reason=empty_body contentType=${contentType} url=${fetchTarget.url} originalUrl=${normalized}`
      );
      return null;
    }
    console.info(
      `[share-poster] ${debugLabel} image-fetch success bytes=${byteLength} contentType=${contentType} url=${fetchTarget.url} originalUrl=${normalized}`
    );
    return `data:${contentType === 'unknown' ? 'image/jpeg' : contentType};base64,${Buffer.from(arrayBuffer).toString('base64')}`;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(
      `[share-poster] ${debugLabel} image-fetch exception url=${fetchTarget.url} originalUrl=${normalized} message=${message}`
    );
    return null;
  }
};

const loadLocalImageDataUri = (() => {
  const cache = new Map<string, string | null>();
  return (filePath: string): string | null => {
    if (cache.has(filePath)) return cache.get(filePath) ?? null;
    try {
      const bytes = fs.readFileSync(filePath);
      const ext = path.extname(filePath).toLowerCase();
      const mimeType = ext === '.jpg' || ext === '.jpeg' ? 'image/jpeg' : 'image/png';
      const dataUri = `data:${mimeType};base64,${bytes.toString('base64')}`;
      cache.set(filePath, dataUri);
      return dataUri;
    } catch {
      cache.set(filePath, null);
      return null;
    }
  };
})();

export const getSharePosterAppIconDataUri = (): string | null => loadLocalImageDataUri(APP_ICON_PATH);

export const formatPosterDate = (date: Date | null, timeZone: string, locale: SharePosterLocale = 'en'): string => {
  if (!date) return locale === 'zh' ? '待定' : 'TBA';
  try {
    if (locale === 'zh') {
      return new Intl.DateTimeFormat('zh-CN', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        timeZone,
      }).format(date);
    }
    return new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      timeZone,
    }).format(date);
  } catch {
    return locale === 'zh' ? '待定' : date.toISOString().slice(0, 10);
  }
};

export const formatPosterDateParts = (
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

export const formatPosterDuration = (startDate: Date | null, endDate: Date | null, timeZone: string): string => {
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

export const formatPosterDurationLabel = (
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

export const formatPosterTime = (date: Date | null, timeZone: string, locale: SharePosterLocale): string => {
  if (!date) return locale === 'zh' ? '待定' : 'TBA';
  try {
    return new Intl.DateTimeFormat(locale === 'zh' ? 'zh-CN' : 'en-US', {
      hour: '2-digit',
      minute: '2-digit',
      hour12: locale !== 'zh',
      timeZone,
    }).format(date);
  } catch {
    return locale === 'zh' ? '待定' : 'TBA';
  }
};

export const estimatePosterLineWidth = (value: string, fontSize: number): number => {
  let width = 0;
  for (const char of value) {
    if (char === ' ') {
      width += fontSize * 0.26;
    } else if (/[A-Z0-9]/.test(char)) {
      width += fontSize * 0.58;
    } else if (/[a-z]/.test(char)) {
      width += fontSize * 0.52;
    } else if (/[.,:;!?'’"()\-·/&]/.test(char)) {
      width += fontSize * 0.24;
    } else {
      width += fontSize * 0.9;
    }
  }
  return width;
};

export const wrapPosterMixedText = (value: string, maxWidth: number, fontSize: number, maxLines: number): string[] => {
  const normalized = singleLine(value);
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
  if (current && lines.length < maxLines) lines.push(current);
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

export const renderPosterTextBlock = (
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

export const renderZhDateText = (
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

export const renderZhNumberUnitText = (
  numberText: string,
  unitText: string,
  x: number,
  y: number,
  bodyFont: string
): string => {
  return `<text x="${x}" y="${y}" font-family="${bodyFont}" font-weight="900" font-size="18" fill="#e4e4e7" letter-spacing="0">${svgEscape(`${numberText}${unitText ? ` ${unitText}` : ''}`.trim())}</text>`;
};

const posterFonts = {
  title: "'站酷高端黑', 'ZCOOL_GDH', 'zcool-gdh', 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans SC', sans-serif",
  body: "'站酷高端黑', 'ZCOOL_GDH', 'zcool-gdh', 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans SC', sans-serif",
};

const renderRowPair = (row: Extract<SharePosterSectionRow, { kind: 'pair' }>, y: number, locale: SharePosterLocale): string => {
  const letterSpacing = locale === 'zh' ? '1.2' : '3';
  const leftValue = wrapPosterMixedText(row.left.value, 132, 18, 2);
  const rightValue = wrapPosterMixedText(row.right.value, 132, 18, 2);
  return `
    <text x="25" y="${y}" font-family="${posterFonts.body}" font-size="12" fill="#71717a" letter-spacing="${letterSpacing}">${svgEscape(row.left.label)}</text>
    ${renderPosterTextBlock(leftValue, 25, y + 20, posterFonts.body, 18, 22, '#e4e4e7', 0)}
    <text x="200" y="${y}" font-family="${posterFonts.body}" font-size="12" fill="#71717a" letter-spacing="${letterSpacing}">${svgEscape(row.right.label)}</text>
    ${renderPosterTextBlock(rightValue, 200, y + 20, posterFonts.body, 18, 22, '#e4e4e7', 0)}
  `;
};

const renderRowFull = (row: Extract<SharePosterSectionRow, { kind: 'full' }>, y: number, locale: SharePosterLocale): { svg: string; bottomY: number } => {
  const letterSpacing = locale === 'zh' ? '1.2' : '3';
  const valueLines = wrapPosterMixedText(row.cell.value, 316, 17, 3);
  return {
    svg: `
      <text x="25" y="${y}" font-family="${posterFonts.body}" font-size="12" fill="#71717a" letter-spacing="${letterSpacing}">${svgEscape(row.cell.label)}</text>
      ${renderPosterTextBlock(valueLines, 25, y + 20, posterFonts.body, 17, 22, '#e4e4e7', 0)}
    `,
    bottomY: y + 20 + (valueLines.length - 1) * 22,
  };
};

const renderStructuredPosterHeroThemeOverlay = (
  theme: SharePosterStructuredCardInput['heroTheme'],
  hasHeroImage: boolean
): string => {
  if (!theme || !hasHeroImage) return '';
  if (theme === 'event_timetable') {
    return `
  <rect x="0" y="60" width="390" height="300" fill="url(#eventTimetableTint)"/>
  <path d="M0 112 C48 84, 102 88, 154 118 S262 172, 390 116 L390 188 C338 216, 280 220, 220 194 S94 148, 0 186 Z" fill="#f43f5e" fill-opacity="0.18"/>
  <path d="M0 248 C72 214, 152 220, 232 250 S330 286, 390 262 L390 360 L0 360 Z" fill="#38bdf8" fill-opacity="0.16"/>
  <g stroke="#ffffff" stroke-opacity="0.12" stroke-width="1" stroke-linecap="round">
    <line x1="28" y1="108" x2="362" y2="108"/>
    <line x1="28" y1="156" x2="362" y2="156"/>
    <line x1="28" y1="204" x2="362" y2="204"/>
    <line x1="28" y1="252" x2="362" y2="252"/>
    <line x1="28" y1="300" x2="362" y2="300"/>
    <line x1="82" y1="96" x2="82" y2="324"/>
    <line x1="172" y1="96" x2="172" y2="324"/>
    <line x1="262" y1="96" x2="262" y2="324"/>
    <line x1="332" y1="96" x2="332" y2="324"/>
  </g>`;
  }
  return '';
};

export const renderStructuredPosterSvg = async (input: SharePosterStructuredCardInput): Promise<Buffer> => {
  const qrDataUrl = await QRCode.toDataURL(input.qrText, {
    errorCorrectionLevel: 'H',
    margin: 0,
    width: 240,
    color: {
      dark: '#050505',
      light: '#FFFFFFFF',
    },
  });
  const heroImageDataUrl = await toImageDataUri(input.imageUrl, {
    debugLabel: `structured mode=${input.mode}`,
  });
  const heroThemeOverlay = renderStructuredPosterHeroThemeOverlay(input.heroTheme, Boolean(heroImageDataUrl));
  const appIconDataUrl = getSharePosterAppIconDataUri();
  const titleFontSize = 28;
  const titleLines = wrapPosterMixedText(
    input.locale === 'zh' ? input.title : input.title.toUpperCase(),
    278,
    titleFontSize,
    3
  );
  const titleLineHeight = 30;
  const titleBottomY = 350;
  const titleStartY = titleBottomY - (Math.max(titleLines.length, 1) - 1) * titleLineHeight;
  const titleBlock = titleLines
    .map((line, index) => {
      const y = titleStartY + index * titleLineHeight;
      return `<text x="25" y="${y}" font-family="${posterFonts.title}" font-weight="900" font-size="${titleFontSize}" letter-spacing="${input.locale === 'zh' ? '1.2' : '0.8'}" fill="#fff">${svgEscape(line)}</text>`;
    })
    .join('');

  let rowsSvg = '';
  let cursorY = 372;
  for (const row of input.rows) {
    if (row.kind === 'pair') {
      rowsSvg += renderRowPair(row, cursorY, input.locale);
      cursorY += 50;
      continue;
    }
    const rendered = renderRowFull(row, cursorY, input.locale);
    rowsSvg += rendered.svg;
    cursorY = rendered.bottomY + 30;
  }
  const dividerY = cursorY + 8;
  const footerLine1Y = dividerY + 27;
  const footerLine2Y = footerLine1Y + 19;
  const qrY = footerLine2Y - 14;
  const qrIconBoxX = POSTER_QR_X + (POSTER_QR_SIZE - POSTER_QR_ICON_BOX_SIZE) / 2;
  const qrIconBoxY = qrY + (POSTER_QR_SIZE - POSTER_QR_ICON_BOX_SIZE) / 2;
  const qrIconX = POSTER_QR_X + (POSTER_QR_SIZE - POSTER_QR_ICON_SIZE) / 2;
  const qrIconY = qrY + (POSTER_QR_SIZE - POSTER_QR_ICON_SIZE) / 2;

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
    <linearGradient id="eventTimetableTint" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#0f172a" stop-opacity="0.22"/>
      <stop offset="50%" stop-color="#d946ef" stop-opacity="0.12"/>
      <stop offset="100%" stop-color="#0ea5e9" stop-opacity="0.2"/>
    </linearGradient>
  </defs>
  <rect width="390" height="700" rx="30" fill="#0f0f11" stroke="#27272a" stroke-width="1"/>
  <rect x="0" y="0" width="390" height="60" fill="rgba(255,255,255,0.03)"/>
  <line x1="0" y1="60" x2="390" y2="60" stroke="rgba(255,255,255,0.05)" stroke-width="1"/>
  <text x="25" y="38" font-family="${posterFonts.title}" font-size="16" fill="#d4d4d8" letter-spacing="4.3">RAVEHUB ACCESS</text>

  <rect x="0" y="60" width="390" height="300" fill="#18181b"/>
  ${heroImageDataUrl ? `<image href="${heroImageDataUrl}" x="0" y="60" width="390" height="300" preserveAspectRatio="xMidYMid slice" clip-path="url(#heroClip)" />` : ''}
  ${heroThemeOverlay}
  <rect x="0" y="60" width="390" height="300" fill="url(#titleMask)"/>
  <g>${titleBlock}</g>

  <g font-family="${posterFonts.body}">
    ${rowsSvg}
  </g>

  <line x1="25" y1="${dividerY}" x2="365" y2="${dividerY}" stroke="rgba(255,255,255,0.1)" stroke-width="1"/>
  <g font-family="${posterFonts.body}">
    <text x="25" y="${footerLine1Y}" font-weight="${input.locale === 'zh' ? '700' : '400'}" font-size="13" fill="#a1a1aa" letter-spacing="${input.locale === 'zh' ? '0.2' : '1.04'}">${svgEscape(excerpt(input.footerLine1, 42))}</text>
    <text x="25" y="${footerLine2Y}" font-family="${posterFonts.title}" font-size="14" fill="#a1a1aa" letter-spacing="0.72">${svgEscape(input.footerLine2)}</text>
  </g>
  <rect x="${POSTER_QR_X}" y="${qrY}" width="${POSTER_QR_SIZE}" height="${POSTER_QR_SIZE}" fill="#ffffff"/>
  <image href="${qrDataUrl}" x="${POSTER_QR_X}" y="${qrY}" width="${POSTER_QR_SIZE}" height="${POSTER_QR_SIZE}" preserveAspectRatio="none" />
  ${
    appIconDataUrl
      ? `
  <rect x="${qrIconBoxX}" y="${qrIconBoxY}" width="${POSTER_QR_ICON_BOX_SIZE}" height="${POSTER_QR_ICON_BOX_SIZE}" rx="4" fill="#ffffff"/>
  <image href="${appIconDataUrl}" x="${qrIconX}" y="${qrIconY}" width="${POSTER_QR_ICON_SIZE}" height="${POSTER_QR_ICON_SIZE}" preserveAspectRatio="xMidYMid meet" />`
      : ''
  }
</svg>`;

  const resvg = new Resvg(svg, {
    fitTo: {
      mode: 'width',
      value: 780,
    },
  });
  return Buffer.from(resvg.render().asPng());
};

export const buildPosterQrText = (code: string): string => buildShareShortUrl(code);
