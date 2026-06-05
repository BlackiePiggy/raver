import type { EntityChangeDb, EntitySnapshot } from '../entity-change.types';
import { dateToIso, sortedStrings, textHash, textPreview } from './snapshot-utils';

export const buildNewsChangeSnapshot = async (input: {
  entityId: string;
  db: EntityChangeDb;
}): Promise<EntitySnapshot | null> => {
  const article = await input.db.newsArticle.findUnique({
    where: { id: input.entityId },
    include: {
      djBindings: { select: { djId: true } },
      festivalBrandBindings: { select: { festivalBrandId: true } },
      eventBindings: { select: { eventId: true } },
    },
  });

  if (!article) return null;

  return {
    entityType: 'news',
    entityId: article.id,
    displayName: article.title,
    revision: null,
    schemaVersion: 1,
    capturedAt: new Date().toISOString(),
    data: {
      profile: {
        title: article.title,
        summary: article.summary,
        bodyPreview: textPreview(article.body),
        bodyHash: textHash(article.body),
        category: article.category,
        source: article.source,
        visibility: article.visibility,
      },
      media: {
        coverImageUrl: article.coverImageUrl,
        link: article.link,
      },
      publish: {
        authorId: article.authorId,
        publishedAt: dateToIso(article.publishedAt),
      },
      bindings: {
        djIds: sortedStrings(article.djBindings.map((binding) => binding.djId)),
        brandIds: sortedStrings(article.festivalBrandBindings.map((binding) => binding.festivalBrandId)),
        eventIds: sortedStrings(article.eventBindings.map((binding) => binding.eventId)),
      },
    },
  };
};
