import type { EntityChangeDb, EntitySnapshot } from '../entity-change.types';
import { normalizeJson, sortedStrings } from './snapshot-utils';

export const buildLabelChangeSnapshot = async (input: {
  entityId: string;
  db: EntityChangeDb;
}): Promise<EntitySnapshot | null> => {
  const label = await input.db.label.findUnique({
    where: { id: input.entityId },
  });

  if (!label) return null;

  return {
    entityType: 'label',
    entityId: label.id,
    displayName: label.name,
    revision: null,
    schemaVersion: 2,
    capturedAt: new Date().toISOString(),
    data: {
      profile: {
        name: label.name,
        nameI18n: normalizeJson(label.nameI18n),
        slug: label.slug,
        profileUrl: label.profileUrl,
        profileSlug: label.profileSlug,
        introductionPreview: label.introductionPreview,
        introduction: label.introduction,
        descriptionI18n: normalizeJson(label.descriptionI18n),
      },
      source: {
        sourcePage: label.sourcePage,
        sourceListingUrl: label.sourceListingUrl,
        cardId: label.cardId,
      },
      media: {
        logoUrl: label.logoUrl,
        avatarSourceUrl: label.avatarSourceUrl,
        backgroundSourceUrl: label.backgroundSourceUrl,
        avatarUrl: label.avatarUrl,
        backgroundUrl: label.backgroundUrl,
      },
      region: {
        nation: label.nation,
        locationPeriod: label.locationPeriod,
      },
      music: {
        genresPreview: label.genresPreview,
        latestReleaseListing: label.latestReleaseListing,
        genres: sortedStrings(label.genres),
      },
      contact: {
        contacts: normalizeJson(label.contacts),
        generalContactEmail: label.generalContactEmail,
        demoSubmissionUrl: label.demoSubmissionUrl,
        demoSubmissionDisplay: label.demoSubmissionDisplay,
      },
      links: {
        linksInWeb: normalizeJson(label.linksInWeb),
        facebookUrl: label.facebookUrl,
        soundcloudUrl: label.soundcloudUrl,
        musicPurchaseUrl: label.musicPurchaseUrl,
        officialWebsiteUrl: label.officialWebsiteUrl,
      },
      founder: {
        founderName: label.founderName,
        foundedAt: label.foundedAt,
        founderDjIds: sortedStrings(label.founderDjIds),
      },
      stats: {
        soundcloudFollowers: label.soundcloudFollowers,
        likes: label.likes,
      },
    },
  };
};
