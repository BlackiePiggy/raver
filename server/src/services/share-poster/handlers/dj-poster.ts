import { buildPosterQrText, formatPosterDate, renderStructuredPosterSvg } from '../svg-utils';
import { excerpt, pickLocalizedText, posterText } from '../localization';
import { SharePosterHandler } from '../types';

export const djPosterHandler: SharePosterHandler = {
  id: 'dj-profile',
  supports(context) {
    return context.shareLink.targetType === 'dj';
  },
  async render(context) {
    const dj = await context.prisma.dJ.findUnique({
      where: { id: context.shareLink.targetId },
      select: {
        name: true,
        nameI18n: true,
        bio: true,
        bioI18n: true,
        avatarUrl: true,
        bannerUrl: true,
        country: true,
        countryI18n: true,
        genres: true,
        updatedAt: true,
      },
    });
    if (!dj) return null;
    const title = posterText(pickLocalizedText(dj.nameI18n, context.locale, dj.name), context.shareLink.title);
    const country = posterText(pickLocalizedText(dj.countryI18n, context.locale, dj.country), context.locale === 'zh' ? '未知' : 'Unknown');
    const bio = posterText(pickLocalizedText(dj.bioI18n, context.locale, dj.bio), context.locale === 'zh' ? '等待补充简介' : 'Bio coming soon');
    const genres = dj.genres.slice(0, 3).join(' · ') || (context.locale === 'zh' ? '风格待补充' : 'Genres TBA');
    const updated = formatPosterDate(dj.updatedAt, 'UTC', context.locale);
    const png = await renderStructuredPosterSvg({
      locale: context.locale,
      title,
      imageUrl: dj.bannerUrl || dj.avatarUrl || context.shareLink.imageUrl,
      rows: [
        {
          kind: 'pair',
          left: { label: context.locale === 'zh' ? '国家/地区' : 'COUNTRY', value: country },
          right: { label: context.locale === 'zh' ? '最近更新' : 'UPDATED', value: updated },
        },
        {
          kind: 'full',
          cell: { label: context.locale === 'zh' ? '风格' : 'GENRES', value: genres },
        },
        {
          kind: 'full',
          cell: { label: context.locale === 'zh' ? '简介' : 'BIO', value: excerpt(bio, 180) },
        },
      ],
      footerLine1: context.locale === 'zh' ? '扫码打开 RaveHub 查看 DJ 详情与相关活动' : 'SCAN TO OPEN RAVEHUB FOR DJ PROFILE & EVENTS',
      footerLine2: 'RaveHub App',
      qrText: buildPosterQrText(context.shareLink.code),
      mode: 'dj_svg',
    });
    console.info(`[share-poster] code=${context.shareLink.code} targetType=dj svg-render success bytes=${png.length}`);
    return {
      png,
      mode: 'dj_svg',
      handlerId: this.id,
      variant: context.variant,
    };
  },
};
