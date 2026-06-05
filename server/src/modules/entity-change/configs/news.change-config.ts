import { registerEntityChangeDefinition } from '../entity-change.registry';
import type { ChangePathConfig } from '../entity-change.types';
import { buildNewsChangeSnapshot } from '../snapshots/news.snapshot';

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

export const newsChangePaths: Record<string, ChangePathConfig> = {
  'profile.title': publicScalar('资讯标题', 'News title', 'profile', 100),
  'profile.summary': publicScalar('资讯摘要', 'News summary', 'profile', 95),
  'profile.bodyPreview': publicScalar('正文摘要', 'Body preview', 'profile', 90),
  'profile.bodyHash': privateScalar('正文指纹', 'Body hash', 'profile'),
  'profile.category': publicScalar('资讯分类', 'News category', 'profile'),
  'profile.source': operatorScalar('资讯来源', 'News source', 'profile'),
  'profile.visibility': operatorScalar('可见性', 'Visibility', 'profile'),
  'media.coverImageUrl': publicScalar('封面图', 'Cover image', 'media'),
  'media.link': publicScalar('原文链接', 'Source link', 'media'),
  'publish.authorId': privateScalar('作者 ID', 'Author ID', 'publish'),
  'publish.publishedAt': publicScalar('发布时间', 'Published time', 'publish'),
  'bindings.djIds': {
    ...publicScalar('关联 DJ', 'Related DJs', 'bindings'),
    arrayStrategy: { type: 'set' },
  },
  'bindings.brandIds': {
    ...publicScalar('关联品牌', 'Related brands', 'bindings'),
    arrayStrategy: { type: 'set' },
  },
  'bindings.eventIds': {
    ...publicScalar('关联活动', 'Related events', 'bindings'),
    arrayStrategy: { type: 'set' },
  },
};

registerEntityChangeDefinition({
  entityType: 'news',
  snapshotSchemaVersion: 1,
  buildSnapshot: buildNewsChangeSnapshot,
  paths: newsChangePaths,
});
