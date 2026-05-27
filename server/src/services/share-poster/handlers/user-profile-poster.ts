import { buildPosterQrText, renderStructuredPosterSvg } from '../svg-utils';
import { posterText } from '../localization';
import { resolveUserGenrePreferences } from '../../user-genre-preference.service';
import { SharePosterHandler } from '../types';

export const userProfilePosterHandler: SharePosterHandler = {
  id: 'user-profile',
  supports(context) {
    return context.shareLink.targetType === 'user_card';
  },
  async render(context) {
    const [user, postCount, checkinStat, favoriteGenres] = await Promise.all([
      context.prisma.user.findUnique({
        where: { id: context.shareLink.targetId },
        select: {
          username: true,
          displayName: true,
          avatarUrl: true,
          backgroundUrl: true,
          location: true,
          createdAt: true,
        },
      }),
      context.prisma.post.count({
        where: { userId: context.shareLink.targetId },
      }),
      context.prisma.userCheckinStat.findUnique({
        where: {
          userId_scope: {
            userId: context.shareLink.targetId,
            scope: 'all',
          },
        },
        select: {
          eventCount: true,
          artistCount: true,
        },
      }),
      resolveUserGenrePreferences(context.prisma, context.shareLink.targetId),
    ]);
    if (!user) return null;
    const title = posterText(user.displayName || user.username, context.shareLink.title);
    const joinedDays = Math.max(
      1,
      Math.floor((Date.now() - user.createdAt.getTime()) / 86400000)
    );
    const genresText = favoriteGenres.slice(0, 6).join(' · ') || (context.locale === 'zh' ? '暂未选择' : 'Not set');
    const eventCountText = String(checkinStat?.eventCount || 0);
    const artistCountText = String(checkinStat?.artistCount || 0);
    const dynamicCountText = String(postCount || 0);
    const joinedDaysText = context.locale === 'zh' ? `${joinedDays} 天` : `${joinedDays} Days`;
    const png = await renderStructuredPosterSvg({
      locale: context.locale,
      title,
      imageUrl: user.avatarUrl || user.backgroundUrl || context.shareLink.imageUrl,
      rows: [
        {
          kind: 'pair',
          left: { label: context.locale === 'zh' ? '地理位置' : 'LOCATION', value: posterText(user.location, context.locale === 'zh' ? '未填写' : 'Not set') },
          right: { label: context.locale === 'zh' ? '加入天数' : 'JOINED', value: joinedDaysText },
        },
        {
          kind: 'pair',
          left: { label: context.locale === 'zh' ? '动态数量' : 'POSTS', value: dynamicCountText },
          right: { label: context.locale === 'zh' ? '打卡活动数' : 'CHECKIN EVENTS', value: eventCountText },
        },
        {
          kind: 'pair',
          left: { label: context.locale === 'zh' ? '打卡艺人数' : 'CHECKIN ARTISTS', value: artistCountText },
          right: { label: context.locale === 'zh' ? '用户名' : 'USERNAME', value: `@${user.username}` },
        },
        {
          kind: 'full',
          cell: { label: context.locale === 'zh' ? '喜欢听的风格' : 'FAVORITE GENRES', value: genresText },
        },
      ],
      footerLine1: context.locale === 'zh' ? '扫码打开 RaveHub 查看主页与更多近期动态' : 'SCAN TO OPEN RAVEHUB FOR PROFILE & RECENT ACTIVITY',
      footerLine2: 'RaveHub App',
      qrText: buildPosterQrText(context.shareLink.code),
      mode: 'user_card_svg',
    });
    console.info(`[share-poster] code=${context.shareLink.code} targetType=user_card svg-render success bytes=${png.length}`);
    return {
      png,
      mode: 'user_card_svg',
      handlerId: this.id,
      variant: context.variant,
    };
  },
};
