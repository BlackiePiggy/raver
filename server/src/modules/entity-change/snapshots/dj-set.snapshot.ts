import type { EntityChangeDb, EntitySnapshot } from '../entity-change.types';
import { dateToIso, normalizeJson, sortedStrings } from './snapshot-utils';

const normalizeTrackIdentityKey = (track: {
  position: number;
  startTime: number;
  title: string;
  artist: string;
}): string => {
  const position = Number.isFinite(track.position) ? track.position : 0;
  return `position:${position}`;
};

export const buildDJSetChangeSnapshot = async (input: {
  entityId: string;
  db: EntityChangeDb;
}): Promise<EntitySnapshot | null> => {
  const set = await input.db.dJSet.findUnique({
    where: { id: input.entityId },
    include: {
      dj: {
        select: { id: true, name: true },
      },
      event: {
        select: { id: true, name: true },
      },
      artists: {
        orderBy: [{ artistOrder: 'asc' }, { createdAt: 'asc' }],
        include: {
          dj: {
            select: { id: true, name: true },
          },
        },
      },
      tracks: {
        orderBy: [{ position: 'asc' }, { startTime: 'asc' }, { id: 'asc' }],
      },
    },
  });

  if (!set) return null;

  const lineupArtists = set.artists
    .map((artist) => {
      const identityKey = artist.djId ? `dj:${artist.djId}` : `custom:${artist.artistNameSnapshot.trim().toLowerCase()}`;
      return {
        identityKey,
        name: artist.dj?.name ?? artist.artistNameSnapshot,
        djId: artist.djId,
        role: artist.role,
      };
    })
    .sort((a, b) => a.identityKey.localeCompare(b.identityKey, 'en', { sensitivity: 'base' }));

  return {
    entityType: 'djSet',
    entityId: set.id,
    displayName: set.title,
    revision: null,
    schemaVersion: 1,
    capturedAt: new Date().toISOString(),
    data: {
      profile: {
        title: set.title,
        titleI18n: normalizeJson(set.titleI18n),
        slug: set.slug,
        description: set.description,
        descriptionI18n: normalizeJson(set.descriptionI18n),
        isVerified: set.isVerified,
      },
      video: {
        videoUrl: set.videoUrl,
        videoAuthorName: set.videoAuthorName,
        platform: set.platform,
        videoId: set.videoId,
        duration: set.duration,
      },
      media: {
        thumbnailUrl: set.thumbnailUrl,
      },
      recording: {
        recordedAt: dateToIso(set.recordedAt),
        venue: set.venue,
        eventId: set.eventId,
        eventName: set.eventName ?? set.event?.name ?? null,
      },
      stats: {
        viewCount: set.viewCount,
        likeCount: set.likeCount,
      },
      lineup: {
        primaryDjId: set.djId,
        primaryDjName: set.dj?.name ?? null,
        customDjNames: sortedStrings(set.customDjNames),
        artists: lineupArtists,
      },
      tracks: set.tracks.map((track) => ({
        identityKey: normalizeTrackIdentityKey(track),
        position: track.position,
        startTime: track.startTime,
        endTime: track.endTime,
        title: track.title,
        artist: track.artist,
        status: track.status,
        label: track.label,
        releaseYear: track.releaseYear,
        spotifyUrl: track.spotifyUrl,
        spotifyId: track.spotifyId,
        spotifyUri: track.spotifyUri,
        appleMusicUrl: track.appleMusicUrl,
        youtubeMusicUrl: track.youtubeMusicUrl,
        soundcloudUrl: track.soundcloudUrl,
        beatportUrl: track.beatportUrl,
        neteaseUrl: track.neteaseUrl,
        neteaseId: track.neteaseId,
      })),
    },
  };
};
