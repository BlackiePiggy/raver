import { buildPosterQrText, renderStructuredPosterSvg } from '../svg-utils';
import { excerpt, pickLocalizedText, posterText } from '../localization';
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
        foundedYear: true,
        tagline: true,
        introduction: true,
        descriptionI18n: true,
        avatarUrl: true,
        backgroundUrl: true,
      },
    });
    if (!festival) return null;
    const title = posterText(pickLocalizedText(festival.nameI18n, context.locale, festival.name), context.shareLink.title);
    const city = pickLocalizedText(festival.cityI18n, context.locale, festival.city) || festival.city;
    const country = pickLocalizedText(festival.countryI18n, context.locale, festival.country) || festival.country;
    const intro = pickLocalizedText(festival.descriptionI18n, context.locale, festival.introduction) || festival.introduction;
    const location = [city, country].filter(Boolean).join(' · ');
    const png = await renderStructuredPosterSvg({
      locale: context.locale,
      title,
      imageUrl: festival.backgroundUrl || festival.avatarUrl || context.shareLink.imageUrl,
      rows: [
        {
          kind: 'pair',
          left: { label: context.locale === 'zh' ? '城市' : 'CITY', value: posterText(location, context.locale === 'zh' ? '待补充' : 'TBA') },
          right: { label: context.locale === 'zh' ? '创立年份' : 'FOUNDED', value: posterText(festival.foundedYear, context.locale === 'zh' ? '待补充' : 'TBA') },
        },
        {
          kind: 'full',
          cell: { label: context.locale === 'zh' ? '标语' : 'TAGLINE', value: posterText(festival.tagline, context.locale === 'zh' ? '等待补充' : 'Coming soon') },
        },
        {
          kind: 'full',
          cell: { label: context.locale === 'zh' ? '介绍' : 'INTRO', value: excerpt(intro, 180) || (context.locale === 'zh' ? '暂无介绍' : 'No introduction yet') },
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
