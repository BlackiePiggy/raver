import 'dotenv/config';
import '../modules/entity-change';
import { diffEntitySnapshots } from '../modules/entity-change/entity-change-diff-engine';
import { getEntityChangeDefinition } from '../modules/entity-change';
import type { EntitySnapshot } from '../modules/entity-change';

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const snapshot = (data: Record<string, unknown>): EntitySnapshot => ({
  entityType: 'djSet',
  entityId: 'dj-set-regression',
  displayName: 'Regression Set',
  revision: null,
  schemaVersion: 1,
  capturedAt: new Date().toISOString(),
  data,
});

const baseData = (): Record<string, unknown> => ({
  profile: {
    title: 'Before Set',
    description: 'Before description',
    isVerified: false,
  },
  video: {
    videoUrl: 'https://youtu.be/aaaaaaaaaaa',
    videoAuthorName: 'Uploader A',
    platform: 'youtube',
    videoId: 'aaaaaaaaaaa',
    duration: 3600,
  },
  media: {
    thumbnailUrl: 'https://img.example.com/before.jpg',
  },
  recording: {
    recordedAt: '2026-06-01T00:00:00.000Z',
    venue: 'Room A',
    eventName: 'Night A',
  },
  lineup: {
    customDjNames: ['Alpha', 'Beta'],
    artists: [
      { identityKey: 'custom:alpha', name: 'Alpha', role: 'custom' },
      { identityKey: 'custom:beta', name: 'Beta', role: 'custom' },
    ],
  },
  tracks: [
    {
      identityKey: 'position:1',
      position: 1,
      startTime: 0,
      endTime: 180,
      title: 'Track One',
      artist: 'Artist One',
      status: 'released',
      spotifyUrl: null,
    },
    {
      identityKey: 'position:2',
      position: 2,
      startTime: 180,
      endTime: 360,
      title: 'Track Two',
      artist: 'Artist Two',
      status: 'id',
      spotifyUrl: null,
    },
  ],
});

const run = (): void => {
  const definition = getEntityChangeDefinition('djSet');

  const titleDiff = diffEntitySnapshots({
    definition,
    before: snapshot(baseData()),
    after: snapshot({
      ...baseData(),
      profile: {
        ...(baseData().profile as Record<string, unknown>),
        title: 'After Set',
      },
    }),
  });
  assert(titleDiff.publicChanges.some((change) => change.label === 'Set 标题' && change.before === 'Before Set' && change.after === 'After Set'), 'title update should expose public old/new values');

  const lineupOrderDiff = diffEntitySnapshots({
    definition,
    before: snapshot(baseData()),
    after: snapshot({
      ...baseData(),
      lineup: {
        customDjNames: ['Beta', 'Alpha'],
        artists: [
          { identityKey: 'custom:beta', name: 'Beta', role: 'custom' },
          { identityKey: 'custom:alpha', name: 'Alpha', role: 'custom' },
        ],
      },
    }),
  });
  assert(lineupOrderDiff.changes.length === 0, 'lineup order-only changes should not create diff');

  const trackEditDiff = diffEntitySnapshots({
    definition,
    before: snapshot(baseData()),
    after: snapshot({
      ...baseData(),
      tracks: [
        {
          identityKey: 'position:1',
          position: 1,
          startTime: 30,
          endTime: 210,
          title: 'Track One VIP',
          artist: 'Artist One',
          status: 'released',
          spotifyUrl: 'https://open.spotify.com/track/1',
        },
        {
          identityKey: 'position:2',
          position: 2,
          startTime: 180,
          endTime: 360,
          title: 'Track Two',
          artist: 'Artist Two',
          status: 'id',
          spotifyUrl: null,
        },
      ],
    }),
  });
  assert(trackEditDiff.publicChanges.some((change) => change.label === '曲名' && change.after === 'Track One VIP'), 'track title update should be specific');
  assert(trackEditDiff.publicChanges.some((change) => change.label === '曲目开始时间' && change.before === '0:00' && change.after === '0:30'), 'track start time should use mm:ss old/new values');
  assert(trackEditDiff.publicChanges.some((change) => change.label === 'Spotify 链接' && change.after === 'https://open.spotify.com/track/1'), 'track public link update should be exposed');

  const trackAddRemoveDiff = diffEntitySnapshots({
    definition,
    before: snapshot(baseData()),
    after: snapshot({
      ...baseData(),
      tracks: [
        {
          identityKey: 'position:1',
          position: 1,
          startTime: 0,
          endTime: 180,
          title: 'Track One',
          artist: 'Artist One',
          status: 'released',
          spotifyUrl: null,
        },
        {
          identityKey: 'position:3',
          position: 3,
          startTime: 360,
          endTime: 540,
          title: 'Track Three',
          artist: 'Artist Three',
          status: 'released',
          spotifyUrl: null,
        },
      ],
    }),
  });
  assert(trackAddRemoveDiff.changes.some((change) => change.kind === 'removed' && change.path === 'tracks'), 'track removal should be detected');
  assert(trackAddRemoveDiff.changes.some((change) => change.kind === 'added' && change.path === 'tracks'), 'track addition should be detected');

  console.log('[entity-change-dj-set-regression] ok');
};

try {
  run();
} catch (error) {
  console.error('[entity-change-dj-set-regression] failed:', error);
  process.exit(1);
}
