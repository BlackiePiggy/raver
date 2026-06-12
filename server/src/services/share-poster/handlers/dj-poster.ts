import { buildPosterQrText, renderStructuredPosterSvg } from '../svg-utils';
import { pickLocalizedText, posterText } from '../localization';
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
        avatarUrl: true,
        bannerUrl: true,
        country: true,
        countryI18n: true,
        genres: true,
        genreBindings: {
          orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
          select: {
            displayName: true,
            genre: {
              select: {
                name: true,
              },
            },
          },
          take: 6,
        },
      },
    });
    if (!dj) return null;
    const boundEventRows = await context.prisma.eventArtist.findMany({
      where: {
        OR: [
          { primaryDjId: context.shareLink.targetId },
          { members: { some: { djId: context.shareLink.targetId } } },
        ],
      },
      select: {
        eventId: true,
      },
      distinct: ['eventId'],
    });
    const title = posterText(pickLocalizedText(dj.nameI18n, context.locale, dj.name), context.shareLink.title);
    const country = posterText(pickLocalizedText(dj.countryI18n, context.locale, dj.country), context.locale === 'zh' ? '未知' : 'Unknown');
    const genreNames = dj.genreBindings
      .map((binding) => (binding.displayName || binding.genre.name).trim())
      .filter(Boolean);
    const genres = [...genreNames, ...dj.genres]
      .filter(Boolean)
      .filter((value, index, array) => array.findIndex((item) => item.toLowerCase() === value.toLowerCase()) === index)
      .slice(0, 6)
      .join(' · ') || (context.locale === 'zh' ? '风格待补充' : 'Genres TBA');
    const eventCountText = String(boundEventRows.length || 0);
    const png = await renderStructuredPosterSvg({
      locale: context.locale,
      title,
      imageUrl: dj.avatarUrl || null,
      rows: [
        {
          kind: 'pair',
          left: { label: context.locale === 'zh' ? '国家/地区' : 'COUNTRY', value: country },
          right: { label: context.locale === 'zh' ? '活动数量' : 'EVENTS', value: eventCountText },
        },
        {
          kind: 'full',
          cell: { label: context.locale === 'zh' ? '风格' : 'GENRES', value: genres },
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
