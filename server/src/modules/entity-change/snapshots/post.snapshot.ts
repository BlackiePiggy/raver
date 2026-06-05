import type { EntityChangeDb, EntitySnapshot } from '../entity-change.types';
import { dateToIso, normalizeJson, sortedStrings, textHash, textPreview } from './snapshot-utils';

export const buildPostChangeSnapshot = async (input: {
  entityId: string;
  db: EntityChangeDb;
}): Promise<EntitySnapshot | null> => {
  const post = await input.db.post.findUnique({
    where: { id: input.entityId },
    include: {
      djBindings: { select: { djId: true } },
      festivalBrandBindings: { select: { festivalBrandId: true } },
      eventBindings: { select: { eventId: true } },
    },
  });

  if (!post) return null;

  return {
    entityType: 'post',
    entityId: post.id,
    displayName: textPreview(post.content, 48) || post.id,
    revision: null,
    schemaVersion: 1,
    capturedAt: new Date().toISOString(),
    data: {
      content: {
        preview: textPreview(post.content),
        hash: textHash(post.content),
        titleI18n: normalizeJson(post.titleI18n),
        summaryI18n: normalizeJson(post.summaryI18n),
        bodyI18n: normalizeJson(post.bodyI18n),
      },
      media: {
        images: sortedStrings(post.images),
      },
      context: {
        location: post.location,
        type: post.type,
        visibility: post.visibility,
        squadId: post.squadId,
        eventId: post.eventId,
        setId: post.setId,
        displayPublishedAt: dateToIso(post.displayPublishedAt),
      },
      stats: {
        likeCount: post.likeCount,
        repostCount: post.repostCount,
        saveCount: post.saveCount,
        shareCount: post.shareCount,
        hideCount: post.hideCount,
        commentCount: post.commentCount,
      },
      bindings: {
        djIds: sortedStrings(post.djBindings.map((binding) => binding.djId)),
        brandIds: sortedStrings(post.festivalBrandBindings.map((binding) => binding.festivalBrandId)),
        eventIds: sortedStrings(post.eventBindings.map((binding) => binding.eventId)),
      },
    },
  };
};
