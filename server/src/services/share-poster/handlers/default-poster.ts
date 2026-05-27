import { buildPosterQrText, renderStructuredPosterSvg } from '../svg-utils';
import { posterText } from '../localization';
import { SharePosterHandler, SharePosterSectionRow } from '../types';

const localizedTypeLabel = (targetType: string, locale: 'zh' | 'en'): string => {
  const normalized = String(targetType || '').trim().toLowerCase();
  const zhMap: Record<string, string> = {
    post: '动态',
    news: '资讯',
    set: 'Set',
    dj_set: 'Set',
    label: '厂牌',
    festival: '主办方',
    squad_card: '小队',
    squad_invite: '小队邀请',
    rating_event: '打分事件',
    rating_unit: '打分单位',
    circle_id: '识曲',
    user_card: '个人名片',
  };
  const enMap: Record<string, string> = {
    post: 'POST',
    news: 'NEWS',
    set: 'SET',
    dj_set: 'SET',
    label: 'LABEL',
    festival: 'ORGANIZER',
    squad_card: 'SQUAD',
    squad_invite: 'SQUAD INVITE',
    rating_event: 'RATING EVENT',
    rating_unit: 'RATING UNIT',
    circle_id: 'TRACK ID',
    user_card: 'PROFILE',
  };
  if (locale === 'zh') return zhMap[normalized] || '分享内容';
  return enMap[normalized] || normalized.replace(/[_-]+/g, ' ').toUpperCase() || 'SHARE';
};

const localizedPreviewType = (previewType: string | null | undefined, locale: 'zh' | 'en'): string => {
  const normalized = String(previewType || '').trim().toLowerCase();
  if (!normalized) return locale === 'zh' ? '默认模版' : 'DEFAULT TEMPLATE';
  if (locale === 'zh') {
    if (normalized === 'content_card') return '内容卡片';
    if (normalized === 'invite_card') return '邀请卡片';
    return normalized.replace(/[_-]+/g, ' ');
  }
  return normalized.replace(/[_-]+/g, ' ').toUpperCase();
};

const buildDefaultRows = (
  shareLink: {
    targetType: string;
    previewType: string | null;
    subtitle: string | null;
    code: string;
  },
  locale: 'zh' | 'en'
): SharePosterSectionRow[] => {
  const typeValue = localizedTypeLabel(shareLink.targetType, locale);
  const previewValue = localizedPreviewType(shareLink.previewType, locale);
  const summaryValue = posterText(
    shareLink.subtitle,
    locale === 'zh' ? '打开 RaveHub 查看完整内容' : 'OPEN RAVEHUB TO VIEW FULL DETAILS'
  );

  return [
    {
      kind: 'pair',
      left: {
        label: locale === 'zh' ? '内容类型' : 'TYPE',
        value: typeValue,
      },
      right: {
        label: locale === 'zh' ? '分享卡片' : 'CARD',
        value: previewValue,
      },
    },
    {
      kind: 'full',
      cell: {
        label: locale === 'zh' ? '内容摘要' : 'SUMMARY',
        value: summaryValue,
      },
    },
    {
      kind: 'full',
      cell: {
        label: locale === 'zh' ? '分享代码' : 'SHARE CODE',
        value: shareLink.code.toUpperCase(),
      },
    },
  ];
};

export const defaultPosterHandler: SharePosterHandler = {
  id: 'default',
  supports: () => true,
  async render(context) {
    const png = await renderStructuredPosterSvg({
      locale: context.locale,
      title: posterText(
        context.shareLink.title,
        context.locale === 'zh' ? 'RaveHub 分享内容' : 'RaveHub Share'
      ),
      imageUrl: context.shareLink.imageUrl || null,
      rows: buildDefaultRows(context.shareLink, context.locale),
      footerLine1:
        context.locale === 'zh'
          ? '扫码打开 RaveHub 查看完整内容与更多相关信息'
          : 'SCAN TO OPEN RAVEHUB FOR FULL DETAILS & MORE',
      footerLine2: 'RaveHub App',
      qrText: buildPosterQrText(context.shareLink.code),
      mode: 'default_svg',
    });
    console.info(
      `[share-poster] code=${context.shareLink.code} targetType=${context.shareLink.targetType} svg-render success bytes=${png.length} handler=default`
    );
    return {
      png,
      mode: 'default_svg',
      handlerId: 'default',
      variant: context.variant,
    };
  },
};
