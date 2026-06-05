import { registerEntityChangeDefinition } from '../entity-change.registry';
import type { ChangePathConfig } from '../entity-change.types';
import { buildBrandChangeSnapshot } from '../snapshots/brand.snapshot';

const publicScalar = (labelZh: string, labelEn: string, category: string): ChangePathConfig => ({
  labelZh,
  labelEn,
  category,
  audience: 'public',
  publicSafe: true,
});

const privateScalar = (labelZh: string, labelEn: string, category: string): ChangePathConfig => ({
  labelZh,
  labelEn,
  category,
  audience: 'private',
  publicSafe: false,
  sensitive: true,
});

export const brandChangePaths: Record<string, ChangePathConfig> = {
  'profile.name': publicScalar('主办方名称', 'Brand name', 'profile'),
  'profile.abbreviation': publicScalar('缩写', 'Abbreviation', 'profile'),
  'profile.aliases': {
    ...publicScalar('别名', 'Aliases', 'profile'),
    arrayStrategy: { type: 'set' },
  },
  'profile.tagline': publicScalar('标语', 'Tagline', 'profile'),
  'profile.introduction': publicScalar('介绍', 'Introduction', 'profile'),
  'profile.isActive': publicScalar('启用状态', 'Active status', 'profile'),
  'region.country': publicScalar('国家/地区', 'Country or region', 'region'),
  'region.city': publicScalar('城市', 'City', 'region'),
  'basics.foundedYear': publicScalar('创立年份', 'Founded year', 'basics'),
  'basics.frequency': publicScalar('举办频率', 'Frequency', 'basics'),
  'media.avatarUrl': publicScalar('头像', 'Avatar', 'media'),
  'media.backgroundUrl': publicScalar('背景图', 'Background image', 'media'),
  'links.officialWebsite': publicScalar('官网', 'Official website', 'links'),
  'links.facebookUrl': publicScalar('Facebook', 'Facebook', 'links'),
  'links.instagramUrl': publicScalar('Instagram', 'Instagram', 'links'),
  'links.twitterUrl': publicScalar('X / Twitter', 'X / Twitter', 'links'),
  'links.youtubeUrl': publicScalar('YouTube', 'YouTube', 'links'),
  'links.tiktokUrl': publicScalar('TikTok', 'TikTok', 'links'),
  'links.links': {
    ...publicScalar('外部链接', 'External links', 'links'),
    arrayStrategy: { type: 'keyed-list', keyPath: 'url', orderMatters: true },
  },
  'bindings.eventIds': {
    labelZh: '关联活动',
    labelEn: 'Related events',
    category: 'bindings',
    audience: 'operator',
    publicSafe: false,
    arrayStrategy: { type: 'set' },
  },
  'bindings.postIds': {
    ...privateScalar('关联帖子', 'Related posts', 'bindings'),
    arrayStrategy: { type: 'set' },
  },
  'bindings.newsIds': {
    ...privateScalar('关联资讯', 'Related news', 'bindings'),
    arrayStrategy: { type: 'set' },
  },
};

registerEntityChangeDefinition({
  entityType: 'brand',
  snapshotSchemaVersion: 1,
  buildSnapshot: buildBrandChangeSnapshot,
  paths: brandChangePaths,
});
