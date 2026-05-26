import QRCode from 'qrcode';
import { Resvg } from '@resvg/resvg-js';
import { PNG } from 'pngjs';
import { buildShareShortUrl } from '../../share-link.service';
import {
  pickLocalizedText,
  posterText,
  formatPosterVenueText,
  normalizeText,
  resolvePosterVenueText,
} from '../localization';
import {
  asciiText,
  clampText,
  drawHorizontalLine,
  drawText,
  fillRect,
  fillVerticalGradient,
  insetRect,
  loadRemoteImagePng,
  overlayPngCover,
  wrapAsciiText,
} from '../raster-utils';
import {
  formatPosterDate,
  formatPosterDuration,
  formatPosterDurationLabel,
  renderPosterTextBlock,
  renderZhDateText,
  renderZhNumberUnitText,
  svgEscape,
  toImageDataUri,
  wrapPosterMixedText,
} from '../svg-utils';
import { SharePosterHandler, SharePosterLocale } from '../types';

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

type EventPosterSnapshot = {
  title: string;
  venue: string;
  organizer: string | null;
  startDate: Date | null;
  endDate: Date | null;
  timeZone: string;
  artistCount: number;
  imageUrl: string | null;
};

const parseEventImageAssets = (value: unknown): EventImageAssetPayload[] => {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is EventImageAssetPayload => Boolean(item && typeof item === 'object'));
};

const resolveEventImageAssetBucket = (asset: EventImageAssetPayload): 'poster' | 'cover' | 'lineup' | 'other' => {
  const raw = [asset.bucket, asset.zone, asset.type, asset.purpose, asset.kind]
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
    normalizeText(assets.find((asset) => resolveEventImageAssetBucket(asset) === bucket)?.url);
  return (
    normalizeText(row.coverImageUrl) ||
    firstAssetUrl('poster') ||
    normalizeText(row.lineupImageUrl) ||
    firstAssetUrl('lineup') ||
    firstAssetUrl('cover') ||
    null
  );
};

const posterCopy = (locale: SharePosterLocale) =>
  locale === 'zh'
    ? {
        start: '开始',
        end: '结束',
        duration: '时长',
        lineup: '阵容',
        venue: '地点',
        presentedBy: '主办方',
        titleFont: "'站酷高端黑', 'ZCOOL_GDH', 'zcool-gdh', 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans SC', sans-serif",
        bodyFont: "'站酷高端黑', 'ZCOOL_GDH', 'zcool-gdh', 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans SC', sans-serif",
      }
    : {
        start: 'START',
        end: 'END',
        duration: 'DURATION',
        lineup: 'LINEUP',
        venue: 'VENUE',
        presentedBy: 'PRESENTED BY',
        titleFont: "'站酷高端黑', 'ZCOOL_GDH', 'zcool-gdh', 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans SC', sans-serif",
        bodyFont: "'站酷高端黑', 'ZCOOL_GDH', 'zcool-gdh', 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans SC', sans-serif",
      };

const loadEventPosterSnapshot = async (
  prisma: any,
  shareLink: any,
  locale: SharePosterLocale
): Promise<EventPosterSnapshot | null> => {
  if (shareLink.targetType !== 'event') return null;
  const event = await prisma.event.findUnique({
    where: { id: shareLink.targetId },
    select: {
      name: true,
      nameI18n: true,
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
  const localizedTitle = pickLocalizedText(event.nameI18n, locale, event.name);
  const localizedOrganizer = pickLocalizedText(event.wikiFestival?.nameI18n, locale, event.wikiFestival?.name);
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
  };
};

const renderEventPosterSvg = async (
  shareLink: any,
  event: EventPosterSnapshot,
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
      return `<text x="25" y="${y}" font-family="${copy.titleFont}" font-weight="900" font-size="${titleFontSize}" letter-spacing="${locale === 'zh' ? '1.2' : '0.8'}" fill="#fff">${svgEscape(line)}</text>`;
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
  const organizerRaw = normalizeText(event.organizer);
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
  ${heroImageDataUrl ? `<image href="${heroImageDataUrl}" x="0" y="60" width="390" height="300" preserveAspectRatio="xMidYMid slice" clip-path="url(#heroClip)" />` : ''}
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
    ${locale === 'zh'
      ? renderZhNumberUnitText(durationNumber, durationUnit, 25, 442, copy.bodyFont)
      : `<text x="25" y="442" font-size="18" fill="#e4e4e7" letter-spacing="1.08">${safeDuration}</text>`}
    <text x="200" y="422" font-size="12" fill="#71717a" letter-spacing="${locale === 'zh' ? '1.2' : '3'}">${svgEscape(copy.lineup)}</text>
    ${locale === 'zh'
      ? renderZhNumberUnitText(lineupNumber, lineupUnit, 200, 442, copy.bodyFont)
      : `<text x="200" y="442" font-size="18" fill="#e4e4e7" letter-spacing="1.08">${safeLineup}</text>`}
    <text x="25" y="472" font-size="12" fill="#71717a" letter-spacing="${locale === 'zh' ? '1.2' : '3'}">${svgEscape(copy.venue)}</text>
    ${renderPosterTextBlock(venueLines, 25, venueValueY, copy.bodyFont, 16, venueLineHeight, '#e4e4e7', 0)}
    ${organizerLines.length > 0 ? `
    <text x="25" y="${organizerLabelY}" font-size="12" fill="#71717a" letter-spacing="${locale === 'zh' ? '1.2' : '3'}">${svgEscape(copy.presentedBy)}</text>
    ${renderPosterTextBlock(organizerLines, 25, organizerValueY, copy.bodyFont, 18, organizerLineHeight, '#e4e4e7', 0)}` : ''}
  </g>
  <line x1="25" y1="${dividerY}" x2="365" y2="${dividerY}" stroke="rgba(255,255,255,0.1)" stroke-width="1"/>
  <g font-family="${copy.bodyFont}">
    <text x="25" y="${footerLine1Y}" font-weight="${locale === 'zh' ? '700' : '400'}" font-size="13" fill="#a1a1aa" letter-spacing="${locale === 'zh' ? '0.2' : '1.04'}">${svgEscape(moreInfoLine1)}</text>
    <text x="25" y="${footerLine2Y}" font-family="${copy.titleFont}" font-size="14" fill="#a1a1aa" letter-spacing="0.72">${svgEscape(moreInfoLine2)}</text>
  </g>
  <rect x="292" y="${qrY}" width="60" height="60" fill="#ffffff"/>
  <image href="${qrDataUrl}" x="292" y="${qrY}" width="60" height="60" preserveAspectRatio="none" />
</svg>`;
  try {
    const resvg = new Resvg(svg, {
      fitTo: {
        mode: 'width',
        value: 780,
      },
    });
    return Buffer.from(resvg.render().asPng());
  } catch {
    return null;
  }
};

const drawEventAccessPassPoster = async (
  shareLink: any,
  event: EventPosterSnapshot
): Promise<Buffer> => {
  const width = 900;
  const height = 1400;
  const png = new PNG({ width, height });
  const black: [number, number, number] = [0, 0, 0];
  const zinc950: [number, number, number] = [9, 9, 11];
  const zinc800: [number, number, number] = [39, 39, 42];
  const zinc500: [number, number, number] = [113, 113, 122];
  const white: [number, number, number] = [255, 255, 255];
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
  drawText(png, 'RAVEHUB ACCESS', cardX + 36, cardY + 34, 4, [212, 212, 216]);

  fillVerticalGradient(png, cardX, cardY + 116, cardWidth, heroHeight, [34, 34, 36], [5, 5, 6]);
  const heroImage = await loadRemoteImagePng(event.imageUrl);
  if (heroImage) overlayPngCover(png, heroImage, cardX, cardY + 116, cardWidth, heroHeight);
  for (let row = 0; row < heroHeight; row += 1) {
    const alpha = Math.round((row / Math.max(1, heroHeight - 1)) * 165);
    fillRect(png, cardX, cardY + 116 + row, cardWidth, 1, black, alpha);
  }

  const titleLines = wrapAsciiText(clampText(asciiText(event.title, 'EVENT'), 34), 18, 3);
  titleLines.forEach((line, index) => {
    drawText(png, line, cardX + 34, cardY + 116 + heroHeight - 108 + index * 54, 6, white);
  });

  const contentTop = heroBottom + 56;
  const leftColX = cardX + 40;
  const rightColX = cardX + 420;
  const rowGap = 126;
  const drawLabelValue = (label: string, value: string, x: number, y: number, maxChars = 18, maxLines = 2): void => {
    drawText(png, label, x, y, 3, zinc500);
    wrapAsciiText(clampText(asciiText(value, 'TBA'), maxChars), maxChars, maxLines).forEach((line, index) => {
      drawText(png, line, x, y + 42 + index * 32, 4, white);
    });
  };

  drawLabelValue('START', formatPosterDate(event.startDate, event.timeZone, 'en'), leftColX, contentTop);
  drawLabelValue('END', formatPosterDate(event.endDate, event.timeZone, 'en'), rightColX, contentTop);
  drawLabelValue('DURATION', formatPosterDuration(event.startDate, event.endDate, event.timeZone), leftColX, contentTop + rowGap);
  drawLabelValue('LINEUP', `${Math.max(0, event.artistCount)} ARTISTS`, rightColX, contentTop + rowGap);
  drawLabelValue('VENUE', event.venue || 'VENUE TBA', leftColX, contentTop + rowGap * 2, 34, 3);
  drawLabelValue('PRESENTED BY', event.organizer || 'RAVER', leftColX, contentTop + rowGap * 3, 34, 2);

  drawHorizontalLine(png, cardX + 40, cardY + cardHeight - 190, cardWidth - 80, 1, white, 24);
  drawText(png, 'RAVEHUB ACCESS', cardX + 40, cardY + cardHeight - 144, 3, zinc500);
  drawText(png, 'SCAN', cardX + 500, cardY + cardHeight - 144, 4, white);
  drawText(png, 'RAVEHUB APP', cardX + 500, cardY + cardHeight - 100, 3, zinc500);

  const qr = await QRCode.create(buildShareShortUrl(shareLink.code), { errorCorrectionLevel: 'M' });
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

export const eventPosterHandler: SharePosterHandler = {
  id: 'event-access',
  supports(context) {
    if (context.shareLink.targetType !== 'event') return false;
    return !context.variant || !['timetable', 'event_timetable', 'schedule'].includes(context.variant);
  },
  async render(context) {
    const snapshot = await loadEventPosterSnapshot(context.prisma, context.shareLink, context.locale);
    if (!snapshot) return null;
    console.info(
      `[share-poster] code=${context.shareLink.code} targetType=${context.shareLink.targetType} eventSnapshot loaded title="${snapshot.title}" imageUrl=${snapshot.imageUrl || 'none'}`
    );
    const renderedPoster = await renderEventPosterSvg(context.shareLink, snapshot, context.locale);
    if (renderedPoster) {
      console.info(
        `[share-poster] code=${context.shareLink.code} targetType=${context.shareLink.targetType} svg-render success bytes=${renderedPoster.length} imageUrl=${snapshot.imageUrl || 'none'}`
      );
      return {
        png: renderedPoster,
        mode: 'event_svg',
        handlerId: this.id,
        variant: context.variant,
      };
    }
    console.warn(`[share-poster] code=${context.shareLink.code} targetType=${context.shareLink.targetType} fallback=event_fallback_png`);
    return {
      png: await drawEventAccessPassPoster(context.shareLink, snapshot),
      mode: 'event_fallback_png',
      handlerId: this.id,
      variant: context.variant,
    };
  },
};
