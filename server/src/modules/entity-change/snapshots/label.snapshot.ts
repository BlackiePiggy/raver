import type { EntityChangeDb, EntitySnapshot } from '../entity-change.types';
import { normalizeJson, sortedStrings } from './snapshot-utils';
import { normalizeLabelFounders, type LabelFounderRecord } from '../../../utils/label-founders';

export const buildLabelChangeSnapshot = async (input: {
  entityId: string;
  db: EntityChangeDb;
}): Promise<EntitySnapshot | null> => {
  const label = await input.db.label.findUnique({
    where: { id: input.entityId },
  });

  if (!label) return null;

  const founders = normalizeLabelFounders(label.founders).map((item: LabelFounderRecord, index: number) => ({
    identityKey: item.djId ? `dj:${item.djId}` : `manual:${(item.name ?? '').toLowerCase()}:${index}`,
    name: item.name,
    djId: item.djId,
  }));

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
        foundedAt: label.foundedAt,
        founders,
      },
      stats: {
        soundcloudFollowers: label.soundcloudFollowers,
        likes: label.likes,
      },
    },
  };
};
