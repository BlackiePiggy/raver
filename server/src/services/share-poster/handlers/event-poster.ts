import QRCode from 'qrcode';
import { PNG } from 'pngjs';
import { buildPosterQrText, renderStructuredPosterSvg } from '../svg-utils';
import { resolveEventPosterBackgroundImageUrl } from '../event-images';
import { DEFAULT_EVENT_TIME_ZONE, normalizeEventTimeZone, storageDateToEventDate } from '../../../utils/event-timezone';
import {
  pickLocalizedText,
  posterText,
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
import { SharePosterHandler, SharePosterLocale, SharePosterSectionRow } from '../types';

type EventPosterWeek = {
  weekIndex: number;
  label: string | null;
  startDate: Date;
  endDate: Date;
};

type EventPosterDay = {
  weekIndex: number;
  label: string | null;
  date: Date;
};

type EventPosterDateRange = {
  weekIndex: number;
  label: string | null;
  startDate: Date;
  endDate: Date;
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
  weeks: EventPosterWeek[];
  eventDays: EventPosterDay[];
};

const formatPosterEventDate = (date: Date, locale: SharePosterLocale, timeZone: string): string => {
  try {
    if (locale === 'zh') {
      return new Intl.DateTimeFormat('zh-CN', {
        year: 'numeric',
        month: 'numeric',
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
    return date.toISOString().slice(0, 10);
  }
};

const formatPosterEventDateRange = (
  startDate: Date,
  endDate: Date,
  locale: SharePosterLocale,
  timeZone: string
): string => {
  const startText = formatPosterEventDate(startDate, locale, timeZone);
  const endText = formatPosterEventDate(endDate, locale, timeZone);
  return startText === endText ? startText : `${startText} - ${endText}`;
};

const localizedWeekTitle = (locale: SharePosterLocale, weekIndex: number): string =>
  locale === 'zh' ? `第 ${weekIndex} 周` : `Week ${weekIndex}`;

const buildPosterDateRanges = (snapshot: EventPosterSnapshot): EventPosterDateRange[] => {
  const weeks = snapshot.weeks
    .slice()
    .sort((lhs, rhs) => lhs.weekIndex - rhs.weekIndex || lhs.startDate.getTime() - rhs.startDate.getTime());
  if (weeks.length > 0) {
    return weeks.map((week) => ({
      weekIndex: week.weekIndex,
      label: week.label,
      startDate: week.startDate,
      endDate: week.endDate,
    }));
  }

  const groupedEventDays = new Map<number, EventPosterDay[]>();
  for (const eventDay of snapshot.eventDays) {
    const current = groupedEventDays.get(eventDay.weekIndex) ?? [];
    current.push(eventDay);
    groupedEventDays.set(eventDay.weekIndex, current);
  }
  if (groupedEventDays.size > 0) {
    return Array.from(groupedEventDays.entries())
      .sort((lhs, rhs) => lhs[0] - rhs[0])
      .map(([weekIndex, days]) => {
        const sortedDays = days.slice().sort((lhs, rhs) => lhs.date.getTime() - rhs.date.getTime());
        return {
          weekIndex,
          label: sortedDays.find((item) => String(item.label || '').trim())?.label ?? null,
          startDate: sortedDays[0].date,
          endDate: sortedDays[sortedDays.length - 1].date,
        };
      });
  }

  if (snapshot.startDate && snapshot.endDate) {
    return [{
      weekIndex: 1,
      label: null,
      startDate: snapshot.startDate,
      endDate: snapshot.endDate,
    }];
  }

  return [];
};

const buildPosterDateSummary = (snapshot: EventPosterSnapshot, locale: SharePosterLocale): string => {
  const ranges = buildPosterDateRanges(snapshot);
  if (ranges.length === 0) {
    return locale === 'zh' ? '待定' : 'TBA';
  }
  return ranges
    .map((range) => {
      const prefix = ranges.length > 1
        ? (String(range.label || '').trim() || localizedWeekTitle(locale, range.weekIndex))
        : null;
      const body = formatPosterEventDateRange(range.startDate, range.endDate, locale, snapshot.timeZone);
      return prefix ? `${prefix} ${body}` : body;
    })
    .join(' · ');
};

const buildPosterRows = (snapshot: EventPosterSnapshot, locale: SharePosterLocale): SharePosterSectionRow[] => {
  const rows: SharePosterSectionRow[] = [
    {
      kind: 'full',
      cell: {
        label: locale === 'zh' ? '时间' : 'DATES',
        value: buildPosterDateSummary(snapshot, locale),
      },
    },
    {
      kind: 'pair',
      left: {
        label: locale === 'zh' ? '阵容' : 'LINEUP',
        value: locale === 'zh' ? `${Math.max(0, snapshot.artistCount)} 组艺人` : `${Math.max(0, snapshot.artistCount)} Artists`,
      },
      right: {
        label: locale === 'zh' ? '时区' : 'TIME ZONE',
        value: snapshot.timeZone || 'UTC',
      },
    },
    {
      kind: 'full',
      cell: {
        label: locale === 'zh' ? '地点' : 'VENUE',
        value: snapshot.venue,
      },
    },
  ];

  if (snapshot.organizer?.trim()) {
    rows.push({
      kind: 'full',
      cell: {
        label: locale === 'zh' ? '主办方' : 'PRESENTED BY',
        value: snapshot.organizer.trim(),
      },
    });
  }

  return rows;
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
      weeks: {
        orderBy: [{ sortOrder: 'asc' }, { weekIndex: 'asc' }],
        select: {
          weekIndex: true,
          label: true,
          startDate: true,
          endDate: true,
        },
      },
      eventDays: {
        orderBy: [{ sortOrder: 'asc' }, { overallDayIndex: 'asc' }],
        select: {
          weekIndex: true,
          label: true,
          date: true,
        },
      },
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
  const eventTimeZone = normalizeEventTimeZone(event.timeZone || DEFAULT_EVENT_TIME_ZONE);
  return {
    title: posterText(localizedTitle || shareLink.title, posterText(shareLink.title, `Event ${shareLink.code}`)),
    venue,
    organizer: localizedOrganizer,
    startDate: event.startDate ?? null,
    endDate: event.endDate ?? null,
    timeZone: eventTimeZone,
    artistCount: Math.max(0, Number(event._count?.canonicalArtists ?? 0)),
    imageUrl: resolveEventPosterBackgroundImageUrl(event) || shareLink.imageUrl || null,
    weeks: Array.isArray(event.weeks)
      ? event.weeks.map((week: EventPosterWeek) => ({
        ...week,
        startDate: storageDateToEventDate(week.startDate, eventTimeZone),
        endDate: storageDateToEventDate(week.endDate, eventTimeZone),
      }))
      : [],
    eventDays: Array.isArray(event.eventDays)
      ? event.eventDays.map((day: EventPosterDay) => ({
        ...day,
        date: storageDateToEventDate(day.date, eventTimeZone),
      }))
      : [],
  };
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
  const drawLabelValue = (label: string, value: string, x: number, y: number, maxChars = 18, maxLines = 2): void => {
    drawText(png, label, x, y, 3, zinc500);
    wrapAsciiText(clampText(asciiText(value, 'TBA'), maxChars), maxChars, maxLines).forEach((line, index) => {
      drawText(png, line, x, y + 42 + index * 32, 4, white);
    });
  };

  const drawFullRow = (label: string, value: string, y: number, maxChars = 38, maxLines = 3): number => {
    drawText(png, label, leftColX, y, 3, zinc500);
    const lines = wrapAsciiText(clampText(asciiText(value, 'TBA'), maxChars), maxChars, maxLines);
    lines.forEach((line, index) => {
      drawText(png, line, leftColX, y + 42 + index * 32, 4, white);
    });
    return y + 42 + Math.max(0, lines.length - 1) * 32;
  };

  let cursorY = contentTop;
  cursorY = drawFullRow('DATES', buildPosterDateSummary(event, 'en'), cursorY, 44, 3) + 54;
  drawLabelValue('LINEUP', `${Math.max(0, event.artistCount)} ARTISTS`, leftColX, cursorY);
  drawLabelValue('TIME ZONE', event.timeZone || 'UTC', rightColX, cursorY);
  cursorY += 126;
  cursorY = drawFullRow('VENUE', event.venue || 'VENUE TBA', cursorY, 34, 3) + 54;
  cursorY = drawFullRow('PRESENTED BY', event.organizer || 'RAVER', cursorY, 34, 2) + 54;

  drawHorizontalLine(png, cardX + 40, cardY + cardHeight - 190, cardWidth - 80, 1, white, 24);
  drawText(png, 'RAVEHUB ACCESS', cardX + 40, cardY + cardHeight - 144, 3, zinc500);
  drawText(png, 'SCAN', cardX + 500, cardY + cardHeight - 144, 4, white);
  drawText(png, 'RAVEHUB APP', cardX + 500, cardY + cardHeight - 100, 3, zinc500);

  const qr = await QRCode.create(buildPosterQrText(shareLink.code), { errorCorrectionLevel: 'M' });
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
    return context.shareLink.targetType === 'event';
  },
  async render(context) {
    const snapshot = await loadEventPosterSnapshot(context.prisma, context.shareLink, context.locale);
    if (!snapshot) return null;
    console.info(
      `[share-poster] code=${context.shareLink.code} targetType=${context.shareLink.targetType} eventSnapshot loaded title="${snapshot.title}" imageUrl=${snapshot.imageUrl || 'none'}`
    );
    const renderedPoster = await renderStructuredPosterSvg({
      locale: context.locale,
      title: snapshot.title,
      imageUrl: snapshot.imageUrl,
      debugLabel: `event-access code=${context.shareLink.code}`,
      rows: buildPosterRows(snapshot, context.locale),
      footerLine1:
        context.locale === 'zh'
          ? '扫码打开 RaveHub 查看活动时间、阵容与更多现场信息'
          : 'SCAN TO OPEN RAVEHUB FOR EVENT DATES, LINEUP & MORE',
      footerLine2: 'RaveHub App',
      qrText: buildPosterQrText(context.shareLink.code),
      mode: 'event_svg',
    });
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
