import { registerEntityChangeDefinition } from '../entity-change.registry';
import type { ChangePathConfig } from '../entity-change.types';
import { buildPostChangeSnapshot } from '../snapshots/post.snapshot';

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

export const postChangePaths: Record<string, ChangePathConfig> = {
  'content.preview': publicScalar('内容摘要', 'Content preview', 'content', 100),
  'content.hash': privateScalar('内容指纹', 'Content hash', 'content'),
  'content.titleI18n': operatorScalar('多语言标题', 'Localized title', 'content'),
  'content.summaryI18n': operatorScalar('多语言摘要', 'Localized summary', 'content'),
  'content.bodyI18n': operatorScalar('多语言正文', 'Localized body', 'content'),
  'media.images': {
    ...publicScalar('图片', 'Images', 'media', 90),
    arrayStrategy: { type: 'set' },
  },
  'context.location': publicScalar('地点', 'Location', 'context'),
  'context.type': publicScalar('帖子类型', 'Post type', 'context'),
  'context.visibility': operatorScalar('可见性', 'Visibility', 'context'),
  'context.squadId': privateScalar('小队 ID', 'Squad ID', 'context'),
  'context.eventId': publicScalar('关联活动', 'Related event', 'context'),
  'context.setId': publicScalar('关联 Set', 'Related set', 'context'),
  'context.displayPublishedAt': publicScalar('展示发布时间', 'Display published time', 'context'),
  'stats.likeCount': privateScalar('点赞数', 'Like count', 'stats'),
  'stats.repostCount': privateScalar('转发数', 'Repost count', 'stats'),
  'stats.saveCount': privateScalar('收藏数', 'Save count', 'stats'),
  'stats.shareCount': privateScalar('分享数', 'Share count', 'stats'),
  'stats.hideCount': privateScalar('隐藏数', 'Hide count', 'stats'),
  'stats.commentCount': privateScalar('评论数', 'Comment count', 'stats'),
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
  entityType: 'post',
  snapshotSchemaVersion: 1,
  buildSnapshot: buildPostChangeSnapshot,
  paths: postChangePaths,
});
