import { buildPosterQrText, renderStructuredPosterSvg } from '../svg-utils';
import { pickLocalizedText, posterText } from '../localization';
import { SharePosterHandler } from '../types';

export const festivalPosterHandler: SharePosterHandler = {
  id: 'festival-intro',
  supports(context) {
    return context.shareLink.targetType === 'festival';
  },
  async render(context) {
    const festival = await context.prisma.wikiFestival.findUnique({
      where: { id: context.shareLink.targetId },
      select: {
        name: true,
        nameI18n: true,
        country: true,
        countryI18n: true,
        city: true,
        cityI18n: true,
        avatarUrl: true,
        backgroundUrl: true,
        _count: {
          select: {
            events: true,
          },
        },
      },
    });
    if (!festival) return null;
    const title = posterText(pickLocalizedText(festival.nameI18n, context.locale, festival.name), context.shareLink.title);
    const city = pickLocalizedText(festival.cityI18n, context.locale, festival.city) || festival.city;
    const country = pickLocalizedText(festival.countryI18n, context.locale, festival.country) || festival.country;
    const location = [city, country].filter(Boolean).join(' · ');
    const png = await renderStructuredPosterSvg({
      locale: context.locale,
      title,
      imageUrl: festival.backgroundUrl || festival.avatarUrl || context.shareLink.imageUrl,
      rows: [
        {
          kind: 'pair',
          left: { label: context.locale === 'zh' ? '地点' : 'LOCATION', value: posterText(location, context.locale === 'zh' ? '待补充' : 'TBA') },
          right: { label: context.locale === 'zh' ? '活动次数' : 'EVENTS', value: String(festival._count?.events || 0) },
        },
      ],
      footerLine1: context.locale === 'zh' ? '扫码打开 RaveHub 查看品牌介绍与相关活动' : 'SCAN TO OPEN RAVEHUB FOR FESTIVAL INFO & EVENTS',
      footerLine2: 'RaveHub App',
      qrText: buildPosterQrText(context.shareLink.code),
      mode: 'festival_svg',
    });
    console.info(`[share-poster] code=${context.shareLink.code} targetType=festival svg-render success bytes=${png.length}`);
    return {
      png,
      mode: 'festival_svg',
      handlerId: this.id,
      variant: context.variant,
    };
  },
};
