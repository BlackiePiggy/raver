import { buildPosterQrText, renderStructuredPosterSvg } from '../svg-utils';
import { excerpt, posterText } from '../localization';
import { SharePosterHandler } from '../types';

export const userProfilePosterHandler: SharePosterHandler = {
  id: 'user-profile',
  supports(context) {
    return context.shareLink.targetType === 'user_card';
  },
  async render(context) {
    const user = await context.prisma.user.findUnique({
      where: { id: context.shareLink.targetId },
      select: {
        username: true,
        displayName: true,
        avatarUrl: true,
        backgroundUrl: true,
        bio: true,
        location: true,
        createdAt: true,
      },
    });
    if (!user) return null;
    const title = posterText(user.displayName || user.username, context.shareLink.title);
    const joinDate = new Intl.DateTimeFormat(context.locale === 'zh' ? 'zh-CN' : 'en-US', {
      year: 'numeric',
      month: 'short',
    }).format(user.createdAt);
    const png = await renderStructuredPosterSvg({
      locale: context.locale,
      title,
      imageUrl: user.backgroundUrl || user.avatarUrl || context.shareLink.imageUrl,
      rows: [
        {
          kind: 'pair',
          left: { label: context.locale === 'zh' ? '用户名' : 'USERNAME', value: `@${user.username}` },
          right: { label: context.locale === 'zh' ? '加入时间' : 'JOINED', value: joinDate },
        },
        {
          kind: 'full',
          cell: { label: context.locale === 'zh' ? '位置' : 'LOCATION', value: posterText(user.location, context.locale === 'zh' ? '未填写' : 'Not set') },
        },
        {
          kind: 'full',
          cell: { label: context.locale === 'zh' ? '简介' : 'BIO', value: excerpt(user.bio, 180) || (context.locale === 'zh' ? '这个人还没有写简介' : 'This user has not added a bio yet') },
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
