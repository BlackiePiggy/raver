import 'dotenv/config';
import {
  getEntityChangeDefinition,
  type EntitySnapshot,
} from '../modules/entity-change';
import { diffEntitySnapshots } from '../modules/entity-change/entity-change-diff-engine';

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const snapshot = (data: Record<string, unknown>): EntitySnapshot => ({
  entityType: 'label',
  entityId: 'label-regression',
  displayName: 'Regression Label',
  revision: null,
  schemaVersion: 1,
  capturedAt: new Date('2026-06-05T00:00:00.000Z').toISOString(),
  data,
});

const labelData = (genres: string[] = ['techno', 'house']): Record<string, unknown> => ({
  profile: {
    name: 'Regression Label',
    nameI18n: null,
    slug: 'regression-label',
    profileUrl: 'community://regression-label',
    profileSlug: 'regression-label',
    introductionPreview: 'A label for regression checks',
    introduction: 'A longer label introduction',
    descriptionI18n: null,
  },
  source: {
    sourcePage: 1,
    sourceListingUrl: 'https://source.example.com/list',
    cardId: 'source-card',
  },
  media: {
    logoUrl: 'https://cdn.example.com/logo.png',
    avatarSourceUrl: 'https://source.example.com/avatar.png',
    backgroundSourceUrl: 'https://source.example.com/background.png',
    avatarUrl: 'https://cdn.example.com/avatar.png',
    backgroundUrl: 'https://cdn.example.com/background.png',
  },
  region: {
    nation: 'NL',
    locationPeriod: 'Amsterdam / 2010s',
  },
  music: {
    genresPreview: 'Techno, House',
    latestReleaseListing: 'Latest Release',
    genres,
  },
  contact: {
    contacts: { email: 'private@example.com' },
    generalContactEmail: 'private@example.com',
    demoSubmissionUrl: 'https://demo.example.com',
    demoSubmissionDisplay: 'Send demos',
  },
  links: {
    linksInWeb: { homepage: 'https://label.example.com' },
    facebookUrl: 'https://facebook.com/label',
    soundcloudUrl: 'https://soundcloud.com/label',
    musicPurchaseUrl: 'https://buy.example.com',
    officialWebsiteUrl: 'https://label.example.com',
  },
  founder: {
    founderName: 'Founder Name',
    foundedAt: '2012',
    founderDjId: 'dj-founder',
  },
  stats: {
    soundcloudFollowers: 1000,
    likes: 200,
  },
});

const run = (): void => {
  const definition = getEntityChangeDefinition('label');
  const createDiff = diffEntitySnapshots({
    definition,
    before: null,
    after: snapshot(labelData()),
  });

  assert(createDiff.changes.length > 0, 'label create should be changed');
  assert(createDiff.publicChanges.some((change) => change.path === 'profile.name'), 'label name should be public');
  assert(createDiff.publicChanges.some((change) => change.path === 'profile.introduction'), 'label introduction should be public');
  assert(createDiff.publicChanges.some((change) => change.path === 'media.avatarUrl'), 'label avatar should be public');
  assert(createDiff.publicChanges.some((change) => change.path === 'music.genres'), 'label genres should be public');
  assert(createDiff.publicChanges.some((change) => change.path === 'founder.founderName'), 'label founder should be public');
  assert(!createDiff.publicChanges.some((change) => change.path.startsWith('source.')), 'label source fields must not be public');
  assert(!createDiff.publicChanges.some((change) => change.path.startsWith('contact.contacts')), 'label contacts must stay private');

  const genreOrderDiff = diffEntitySnapshots({
    definition,
    before: snapshot(labelData(['techno', 'house'])),
    after: snapshot(labelData(['house', 'techno'])),
  });
  assert(genreOrderDiff.changes.length === 0, 'label genre order should not create diff');

  console.log('[entity-change-label-regression] ok');
};

try {
  run();
} catch (error) {
  console.error('[entity-change-label-regression] failed:', error);
  process.exit(1);
}
