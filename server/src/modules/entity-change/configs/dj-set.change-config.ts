import { registerEntityChangeDefinition } from '../entity-change.registry';
import type { ChangePathConfig, FormattedValue } from '../entity-change.types';
import { buildDJSetChangeSnapshot } from '../snapshots/dj-set.snapshot';

const publicScalar = (labelZh: string, labelEn: string, category: string, priority = 50): ChangePathConfig => ({
  labelZh,
  labelEn,
  category,
  audience: 'public',
  publicSafe: true,
  priority,
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

const formatSeconds = (value: unknown): FormattedValue => {
  if (value === null || value === undefined) return { zh: null, en: null, ja: null };
  const seconds = Number(value);
  if (!Number.isFinite(seconds)) return { zh: String(value), en: String(value), ja: String(value) };
  const minutes = Math.floor(seconds / 60);
  const rest = Math.max(0, Math.floor(seconds % 60));
  const text = `${minutes}:${String(rest).padStart(2, '0')}`;
  return { zh: text, en: text, ja: text };
};

const formatDate = (value: unknown): FormattedValue => {
  if (value === null || value === undefined) return { zh: null, en: null, ja: null };
  const date = new Date(String(value));
  if (Number.isNaN(date.getTime())) return { zh: String(value), en: String(value), ja: String(value) };
  const text = date.toISOString().slice(0, 10);
  return { zh: text, en: text, ja: text };
};

export const djSetChangePaths: Record<string, ChangePathConfig> = {
  'profile.title': publicScalar('Set 标题', 'Set title', 'profile', 100),
  'profile.titleI18n': operatorScalar('Set 多语言标题', 'Set localized title', 'profile'),
  'profile.slug': operatorScalar('Set slug', 'Set slug', 'profile'),
  'profile.description': publicScalar('Set 描述', 'Set description', 'profile'),
  'profile.descriptionI18n': operatorScalar('Set 多语言描述', 'Set localized description', 'profile'),
  'profile.isVerified': publicScalar('认证状态', 'Verification status', 'profile'),
  'video.videoUrl': publicScalar('视频链接', 'Video URL', 'video'),
  'video.videoAuthorName': publicScalar('视频作者', 'Video author', 'video'),
  'video.platform': publicScalar('视频平台', 'Video platform', 'video'),
  'video.videoId': operatorScalar('平台视频 ID', 'Platform video ID', 'video'),
  'video.duration': {
    ...publicScalar('视频时长', 'Video duration', 'video'),
    formatter: formatSeconds,
  },
  'media.thumbnailUrl': publicScalar('封面图', 'Thumbnail', 'media'),
  'recording.recordedAt': {
    ...publicScalar('录制日期', 'Recorded date', 'recording', 90),
    formatter: formatDate,
  },
  'recording.venue': publicScalar('场地', 'Venue', 'recording', 85),
  'recording.eventId': operatorScalar('关联活动 ID', 'Related event ID', 'recording'),
  'recording.eventName': publicScalar('关联活动', 'Related event', 'recording', 85),
  'stats.viewCount': privateScalar('播放数', 'View count', 'stats'),
  'stats.likeCount': privateScalar('点赞数', 'Like count', 'stats'),
  'lineup.primaryDjId': operatorScalar('主 DJ ID', 'Primary DJ ID', 'lineup'),
  'lineup.primaryDjName': publicScalar('主 DJ', 'Primary DJ', 'lineup', 88),
  'lineup.customDjNames': {
    ...publicScalar('自定义艺人', 'Custom artists', 'lineup', 88),
    arrayStrategy: { type: 'set' },
  },
  'lineup.artists': {
    ...publicScalar('Set 阵容', 'Set lineup', 'lineup', 88),
    arrayStrategy: { type: 'keyed-list', keyPath: 'identityKey', orderMatters: false },
  },
  tracks: {
    ...publicScalar('曲目列表', 'Track list', 'tracks', 92),
    arrayStrategy: { type: 'keyed-list', keyPath: 'identityKey', orderMatters: true },
  },
  'tracks.position': publicScalar('曲目序号', 'Track position', 'tracks', 90),
  'tracks.title': publicScalar('曲名', 'Track title', 'tracks', 92),
  'tracks.artist': publicScalar('曲目艺人', 'Track artist', 'tracks', 92),
  'tracks.status': publicScalar('曲目状态', 'Track status', 'tracks', 88),
  'tracks.label': operatorScalar('曲目厂牌', 'Track label', 'tracks'),
  'tracks.releaseYear': operatorScalar('发行年份', 'Release year', 'tracks'),
  'tracks.startTime': {
    ...publicScalar('曲目开始时间', 'Track start time', 'tracks', 92),
    formatter: formatSeconds,
  },
  'tracks.endTime': {
    ...publicScalar('曲目结束时间', 'Track end time', 'tracks', 92),
    formatter: formatSeconds,
  },
  'tracks.spotifyUrl': publicScalar('Spotify 链接', 'Spotify URL', 'tracks'),
  'tracks.spotifyId': operatorScalar('Spotify 曲目 ID', 'Spotify track ID', 'tracks'),
  'tracks.spotifyUri': operatorScalar('Spotify URI', 'Spotify URI', 'tracks'),
  'tracks.appleMusicUrl': publicScalar('Apple Music 链接', 'Apple Music URL', 'tracks'),
  'tracks.youtubeMusicUrl': publicScalar('YouTube Music 链接', 'YouTube Music URL', 'tracks'),
  'tracks.soundcloudUrl': publicScalar('SoundCloud 链接', 'SoundCloud URL', 'tracks'),
  'tracks.beatportUrl': publicScalar('Beatport 链接', 'Beatport URL', 'tracks'),
  'tracks.neteaseUrl': publicScalar('网易云音乐链接', 'Netease URL', 'tracks'),
  'tracks.neteaseId': operatorScalar('网易云曲目 ID', 'Netease track ID', 'tracks'),
};

registerEntityChangeDefinition({
  entityType: 'djSet',
  snapshotSchemaVersion: 1,
  buildSnapshot: buildDJSetChangeSnapshot,
  paths: djSetChangePaths,
});
