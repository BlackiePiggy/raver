import type { EntityChangeDb, EntitySnapshot } from '../entity-change.types';
import { normalizeJson, sortedStrings } from './snapshot-utils';

export const buildDJChangeSnapshot = async (input: {
  entityId: string;
  db: EntityChangeDb;
}): Promise<EntitySnapshot | null> => {
  const [dj, genreBindings] = await Promise.all([
    input.db.dJ.findUnique({
      where: { id: input.entityId },
    }),
    input.db.dJGenreBinding.findMany({
      where: { djId: input.entityId },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
      select: {
        genreId: true,
        genre: {
          select: {
            name: true,
            path: true,
          },
        },
      },
    }),
  ]);

  if (!dj) return null;

  return {
    entityType: 'dj',
    entityId: dj.id,
    displayName: dj.name,
    revision: null,
    schemaVersion: 2,
    capturedAt: new Date().toISOString(),
    data: {
      profile: {
        name: dj.name,
        nameI18n: normalizeJson(dj.nameI18n),
        aliases: sortedStrings(dj.aliases),
        genres: sortedStrings(dj.genres),
        genreBindings: genreBindings.map((binding) => ({
          genreId: binding.genreId,
          label: binding.genre.name,
          path: binding.genre.path,
        })),
        bio: dj.bio,
        bioI18n: normalizeJson(dj.bioI18n),
        country: dj.country,
        countryI18n: normalizeJson(dj.countryI18n),
        isVerified: dj.isVerified,
        honors: normalizeJson(dj.honors),
      },
      media: {
        avatarUrl: dj.avatarUrl,
        avatarSourceUrl: dj.avatarSourceUrl,
        bannerUrl: dj.bannerUrl,
      },
      links: {
        spotifyUrl: dj.spotifyUrl,
        appleMusicId: dj.appleMusicId,
        soundcloudUrl: dj.soundcloudUrl,
        instagramUrl: dj.instagramUrl,
        facebookUrl: dj.facebookUrl,
        twitterUrl: dj.twitterUrl,
        youtubeUrl: dj.youtubeUrl,
        neteaseUrl: dj.neteaseUrl,
        qqMusicUrl: dj.qqMusicUrl,
        website: dj.website,
      },
      platform: {
        spotifyId: dj.spotifyId,
        spotifyFollowers: dj.spotifyFollowers,
        soundcloudId: dj.soundcloudId,
        trackCount: dj.trackCount,
        playlistCount: dj.playlistCount,
        soundCloudFollowers: dj.soundCloudFollowers,
        soundCloudFavorites: dj.soundCloudFavorites,
        followerCount: dj.followerCount,
      },
      source: {
        sourceId: dj.sourceId,
        sourceDataSource: dj.sourceDataSource,
        sourceGenres: sortedStrings(dj.sourceGenres),
        sourceLabels: sortedStrings(dj.sourceLabels),
        raId: dj.raId,
        discogsId: dj.discogsId,
        beatportId: dj.beatportId,
      },
    },
  };
};
