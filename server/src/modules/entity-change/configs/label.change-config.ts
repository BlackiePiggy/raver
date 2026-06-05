import { registerEntityChangeDefinition } from '../entity-change.registry';
import type { ChangePathConfig } from '../entity-change.types';
import { buildLabelChangeSnapshot } from '../snapshots/label.snapshot';

const publicScalar = (labelZh: string, labelEn: string, category: string, priority = 50): ChangePathConfig => ({
  labelZh,
  labelEn,
  category,
  audience: 'public',
  publicSafe: true,
  priority,
});

const operatorScalar = (labelZh: string, labelEn: string, category: string): ChangePathConfig => ({
  labelZh,
  labelEn,
  category,
  audience: 'operator',
  publicSafe: false,
});

const privateScalar = (labelZh: string, labelEn: string, category: string): ChangePathConfig => ({
  labelZh,
  labelEn,
  category,
  audience: 'private',
  publicSafe: false,
  sensitive: true,
});

export const labelChangePaths: Record<string, ChangePathConfig> = {
  'profile.name': publicScalar('厂牌名称', 'Label name', 'profile', 100),
  'profile.nameI18n': operatorScalar('多语言名称', 'Localized name', 'profile'),
  'profile.slug': operatorScalar('厂牌 slug', 'Label slug', 'profile'),
  'profile.profileUrl': operatorScalar('资料链接', 'Profile URL', 'profile'),
  'profile.profileSlug': operatorScalar('资料 slug', 'Profile slug', 'profile'),
  'profile.introductionPreview': publicScalar('简介预览', 'Introduction preview', 'profile', 90),
  'profile.introduction': publicScalar('介绍', 'Introduction', 'profile', 90),
  'profile.descriptionI18n': operatorScalar('多语言介绍', 'Localized description', 'profile'),
  'source.sourcePage': privateScalar('来源页码', 'Source page', 'source'),
  'source.sourceListingUrl': privateScalar('来源列表链接', 'Source listing URL', 'source'),
  'source.cardId': privateScalar('来源卡片 ID', 'Source card ID', 'source'),
  'media.logoUrl': publicScalar('Logo', 'Logo', 'media'),
  'media.avatarUrl': publicScalar('头像', 'Avatar', 'media'),
  'media.backgroundUrl': publicScalar('背景图', 'Background image', 'media'),
  'media.avatarSourceUrl': operatorScalar('头像源链接', 'Avatar source URL', 'media'),
  'media.backgroundSourceUrl': operatorScalar('背景图源链接', 'Background source URL', 'media'),
  'region.nation': publicScalar('国家/地区', 'Country or region', 'region'),
  'region.locationPeriod': publicScalar('地区/时期', 'Location period', 'region'),
  'music.genresPreview': publicScalar('风格预览', 'Genres preview', 'music'),
  'music.latestReleaseListing': publicScalar('最新发行', 'Latest release listing', 'music'),
  'music.genres': {
    ...publicScalar('风格标签', 'Genres', 'music'),
    arrayStrategy: { type: 'set' },
  },
  'contact.contacts': privateScalar('联系方式', 'Contacts', 'contact'),
  'contact.generalContactEmail': privateScalar('联系邮箱', 'Contact email', 'contact'),
  'contact.demoSubmissionUrl': operatorScalar('Demo 提交链接', 'Demo submission URL', 'contact'),
  'contact.demoSubmissionDisplay': operatorScalar('Demo 提交展示文案', 'Demo submission display', 'contact'),
  'links.linksInWeb': operatorScalar('网页链接集合', 'Web links', 'links'),
  'links.facebookUrl': publicScalar('Facebook', 'Facebook', 'links'),
  'links.soundcloudUrl': publicScalar('SoundCloud', 'SoundCloud', 'links'),
  'links.musicPurchaseUrl': publicScalar('购买链接', 'Music purchase URL', 'links'),
  'links.officialWebsiteUrl': publicScalar('官网', 'Official website', 'links'),
  'founder.founderName': publicScalar('创始人', 'Founder', 'founder'),
  'founder.foundedAt': publicScalar('创立时间', 'Founded at', 'founder'),
  'founder.founderDjIds': {
    ...publicScalar('创始人 DJ 列表', 'Founder DJs', 'founder'),
    arrayStrategy: { type: 'set' },
  },
  'stats.soundcloudFollowers': operatorScalar('SoundCloud 粉丝数', 'SoundCloud followers', 'stats'),
  'stats.likes': operatorScalar('点赞数', 'Likes', 'stats'),
};

registerEntityChangeDefinition({
  entityType: 'label',
  snapshotSchemaVersion: 2,
  buildSnapshot: buildLabelChangeSnapshot,
  paths: labelChangePaths,
});
