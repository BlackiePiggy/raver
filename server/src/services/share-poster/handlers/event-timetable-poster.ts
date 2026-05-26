import { buildPosterQrText, formatPosterDate, formatPosterTime, renderStructuredPosterSvg } from '../svg-utils';
import { pickLocalizedText, posterText, resolvePosterVenueText } from '../localization';
import { SharePosterHandler } from '../types';

export const eventTimetablePosterHandler: SharePosterHandler = {
  id: 'event-timetable',
  supports(context) {
    return context.shareLink.targetType === 'event'
      && ['timetable', 'event_timetable', 'schedule'].includes(context.variant || '');
  },
  async render(context) {
    const event = await context.prisma.event.findUnique({
      where: { id: context.shareLink.targetId },
      select: {
        name: true,
        nameI18n: true,
        city: true,
        cityI18n: true,
        country: true,
        countryI18n: true,
        manualLocation: true,
        locationPoint: true,
        timeZone: true,
        startDate: true,
        endDate: true,
        coverImageUrl: true,
        lineupImageUrl: true,
        imageAssets: true,
        performances: {
          where: {
            startAt: {
              not: null,
            },
          },
          select: {
            displayNameSnapshot: true,
            festivalDayIndex: true,
            startAt: true,
            stage: {
              select: {
                name: true,
              },
            },
          },
          orderBy: [{ startAt: 'asc' }, { sortOrder: 'asc' }],
          take: 4,
        },
      },
    });
    if (!event) return null;
    const title = posterText(pickLocalizedText(event.nameI18n, context.locale, event.name), context.shareLink.title);
    const timeZone = event.timeZone || 'UTC';
    const venue = posterText(resolvePosterVenueText(event, context.locale), context.locale === 'zh' ? '地点待定' : 'Venue TBA');
    const slots = event.performances.map((slot, index) => {
      const timeText = `${formatPosterDate(slot.startAt, timeZone, context.locale)} ${formatPosterTime(slot.startAt, timeZone, context.locale)}`;
      const stageText = slot.stage?.name?.trim() ? `${slot.stage.name} · ${timeText}` : timeText;
      return {
        kind: 'full' as const,
        cell: {
          label: context.locale === 'zh' ? `演出 ${index + 1}` : `SLOT ${index + 1}`,
          value: `${slot.displayNameSnapshot} · ${stageText}`,
        },
      };
    });
    if (slots.length === 0) {
      slots.push({
        kind: 'full',
        cell: {
          label: context.locale === 'zh' ? '时间表' : 'TIMETABLE',
          value: context.locale === 'zh' ? '当前还没有可展示的时间表信息' : 'No timetable data available yet',
        },
      });
    }
    const png = await renderStructuredPosterSvg({
      locale: context.locale,
      title,
      imageUrl: event.coverImageUrl || event.lineupImageUrl || context.shareLink.imageUrl,
      rows: [
        {
          kind: 'pair',
          left: { label: context.locale === 'zh' ? '开始日期' : 'START', value: formatPosterDate(event.startDate, timeZone, context.locale) },
          right: { label: context.locale === 'zh' ? '结束日期' : 'END', value: formatPosterDate(event.endDate, timeZone, context.locale) },
        },
        {
          kind: 'full',
          cell: { label: context.locale === 'zh' ? '活动地点' : 'VENUE', value: venue },
        },
        ...slots,
      ],
      footerLine1: context.locale === 'zh' ? '扫码打开 RaveHub 查看完整时间表与活动详情' : 'SCAN TO OPEN RAVEHUB FOR FULL TIMETABLE & EVENT INFO',
      footerLine2: 'RaveHub App',
      qrText: buildPosterQrText(context.shareLink.code),
      mode: 'event_timetable_svg',
    });
    console.info(`[share-poster] code=${context.shareLink.code} targetType=event variant=${context.variant} svg-render success bytes=${png.length}`);
    return {
      png,
      mode: 'event_timetable_svg',
      handlerId: this.id,
      variant: context.variant,
    };
  },
};
