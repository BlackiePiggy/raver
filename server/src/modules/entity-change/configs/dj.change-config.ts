import { registerEntityChangeDefinition } from '../entity-change.registry';
import type { ChangePathConfig } from '../entity-change.types';
import { buildDJChangeSnapshot } from '../snapshots/dj.snapshot';

const publicScalar = (labelZh: string, labelEn: string, category: string): ChangePathConfig => ({
  labelZh,
  labelEn,
  category,
  audience: 'public',
  publicSafe: true,
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

export const djChangePaths: Record<string, ChangePathConfig> = {
  'profile.name': publicScalar('DJ 名称', 'DJ name', 'profile'),
  'profile.aliases': {
    ...publicScalar('别名', 'Aliases', 'profile'),
    arrayStrategy: { type: 'set' },
  },
  'profile.genres': {
    ...publicScalar('风格标签', 'Genres', 'profile'),
    arrayStrategy: { type: 'set' },
  },
  'profile.bio': publicScalar('简介', 'Bio', 'profile'),
  'profile.country': publicScalar('国家/地区', 'Country or region', 'profile'),
  'profile.isVerified': publicScalar('认证状态', 'Verification status', 'profile'),
  'profile.honors': publicScalar('荣誉', 'Honors', 'profile'),
  'media.avatarUrl': publicScalar('头像', 'Avatar', 'media'),
  'media.bannerUrl': publicScalar('背景图', 'Banner', 'media'),
  'links.spotifyUrl': publicScalar('Spotify 链接', 'Spotify URL', 'links'),
  'links.soundcloudUrl': publicScalar('SoundCloud 链接', 'SoundCloud URL', 'links'),
  'links.instagramUrl': publicScalar('Instagram 链接', 'Instagram URL', 'links'),
  'links.facebookUrl': publicScalar('Facebook 链接', 'Facebook URL', 'links'),
  'links.twitterUrl': publicScalar('X / Twitter 链接', 'X / Twitter URL', 'links'),
  'links.youtubeUrl': publicScalar('YouTube 链接', 'YouTube URL', 'links'),
  'links.website': publicScalar('官网', 'Website', 'links'),
  'platform.spotifyFollowers': operatorScalar('Spotify 粉丝数', 'Spotify followers', 'platform'),
  'platform.trackCount': operatorScalar('曲目数', 'Track count', 'platform'),
  'platform.playlistCount': operatorScalar('歌单数', 'Playlist count', 'platform'),
  'platform.followerCount': privateScalar('站内关注数', 'In-app follower count', 'platform'),
  'source.sourceId': privateScalar('外部源 ID', 'External source ID', 'source'),
  'source.sourceDataSource': privateScalar('外部数据源', 'External data source', 'source'),
  'source.sourceGenres': {
    ...privateScalar('外部源风格', 'External source genres', 'source'),
    arrayStrategy: { type: 'set' },
  },
  'source.sourceLabels': {
    ...privateScalar('外部源厂牌', 'External source labels', 'source'),
    arrayStrategy: { type: 'set' },
  },
};

registerEntityChangeDefinition({
  entityType: 'dj',
  snapshotSchemaVersion: 1,
  buildSnapshot: buildDJChangeSnapshot,
  paths: djChangePaths,
});
