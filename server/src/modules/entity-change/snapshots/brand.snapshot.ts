import type { EntityChangeDb, EntitySnapshot } from '../entity-change.types';
import { normalizeJson, sortedStrings } from './snapshot-utils';

export const buildBrandChangeSnapshot = async (input: {
  entityId: string;
  db: EntityChangeDb;
}): Promise<EntitySnapshot | null> => {
  const brand = await input.db.wikiFestival.findUnique({
    where: { id: input.entityId },
    include: {
      events: { select: { id: true } },
      postBindings: { select: { postId: true } },
      newsBindings: { select: { articleId: true } },
    },
  });

  if (!brand) return null;

  return {
    entityType: 'brand',
    entityId: brand.id,
    displayName: brand.name,
    revision: brand.revision,
    schemaVersion: 1,
    capturedAt: new Date().toISOString(),
    data: {
      profile: {
        name: brand.name,
        nameI18n: normalizeJson(brand.nameI18n),
        abbreviation: brand.abbreviation,
        aliases: sortedStrings(brand.aliases),
        tagline: brand.tagline,
        introduction: brand.introduction,
        descriptionI18n: normalizeJson(brand.descriptionI18n),
        isActive: brand.isActive,
      },
      region: {
        country: brand.country,
        countryI18n: normalizeJson(brand.countryI18n),
        city: brand.city,
        cityI18n: normalizeJson(brand.cityI18n),
      },
      basics: {
        foundedYear: brand.foundedYear,
        frequency: brand.frequency,
        frequencyI18n: normalizeJson(brand.frequencyI18n),
      },
      media: {
        avatarUrl: brand.avatarUrl,
        backgroundUrl: brand.backgroundUrl,
      },
      links: {
        officialWebsite: brand.officialWebsite,
        facebookUrl: brand.facebookUrl,
        instagramUrl: brand.instagramUrl,
        twitterUrl: brand.twitterUrl,
        youtubeUrl: brand.youtubeUrl,
        tiktokUrl: brand.tiktokUrl,
        links: normalizeJson(brand.links),
      },
      bindings: {
        eventIds: sortedStrings(brand.events.map((event) => event.id)),
        postIds: sortedStrings(brand.postBindings.map((binding) => binding.postId)),
        newsIds: sortedStrings(brand.newsBindings.map((binding) => binding.articleId)),
      },
    },
  };
};
