import crypto from 'crypto';
import {
  canonicalizeValue,
  hashCanonicalValue,
  stableSerialize,
} from './entity-change-canonicalizer';
import type {
  ChangePathConfig,
  EntityChange,
  EntityChangeDefinition,
  EntityChangeEntityType,
  EntitySnapshot,
  PublicEntityChange,
} from './entity-change.types';

const DIFF_SCHEMA_VERSION = 1;

const isRecord = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === 'object' && !Array.isArray(value);

const getPathValue = (value: unknown, path: string): unknown => {
  if (!path) return value;
  return path.split('.').reduce<unknown>((acc, key) => {
    if (!isRecord(acc)) return undefined;
    return acc[key];
  }, value);
};

const defaultConfig = (path: string): ChangePathConfig => ({
  labelZh: path || '内容',
  labelEn: path || 'Content',
  category: 'profile',
  audience: 'private',
  publicSafe: false,
  sensitive: true,
});

const labelJaByEn: Record<string, string> = {
  'Event name': 'イベント名',
  'Event description': 'イベント説明',
  'Event type': 'イベント種別',
  'Cancellation status': 'キャンセル状態',
  'Official website': '公式サイト',
  'Cover image': 'カバー画像',
  'Lineup image': 'ラインナップ画像',
  'Organizer name': '主催者名',
  'Related brand': '関連ブランド',
  'Venue name': '会場名',
  'Venue address': '会場住所',
  City: '都市',
  'Country or region': '国・地域',
  'Location details': '場所の詳細',
  'Map coordinate': '地図座標',
  Latitude: '緯度',
  Longitude: '経度',
  'Start date': '開始日',
  'End date': '終了日',
  'Schedule mode': 'スケジュール形式',
  'Time zone': 'タイムゾーン',
  'Start time': '開始時刻',
  'End time': '終了時刻',
  'Day rollover hour': '日付切替時刻',
  'Week structure': '週構成',
  'Event days': 'イベント日程',
  'Ticket URL': 'チケットURL',
  'Minimum ticket price': '最低チケット価格',
  'Maximum ticket price': '最高チケット価格',
  'Ticket currency': 'チケット通貨',
  'Ticket notes': 'チケット説明',
  'Ticket tier': 'チケット区分',
  Stage: 'ステージ',
  'Lineup artist': 'ラインナップアーティスト',
  'Timetable performance': 'タイムテーブル出演',
  'Reference links': '参考リンク',
  'Social links': 'SNSリンク',
  'Source provider': '情報元',
  'Source event URL': '情報元イベントURL',
  'DJ name': 'DJ名',
  Aliases: '別名',
  Genres: 'ジャンル',
  Bio: 'プロフィール',
  'Verification status': '認証状態',
  Honors: '受賞・実績',
  Avatar: 'アバター',
  Banner: 'バナー',
  'Spotify URL': 'Spotifyリンク',
  'SoundCloud URL': 'SoundCloudリンク',
  'Instagram URL': 'Instagramリンク',
  'Facebook URL': 'Facebookリンク',
  'X / Twitter URL': 'X / Twitterリンク',
  'YouTube URL': 'YouTubeリンク',
  Website: '公式サイト',
  'Spotify followers': 'Spotifyフォロワー数',
  'Track count': '曲数',
  'Playlist count': 'プレイリスト数',
  'In-app follower count': 'アプリ内フォロワー数',
  'External source ID': '外部ソースID',
  'External data source': '外部データソース',
  'External source genres': '外部ソースジャンル',
  'External source labels': '外部ソースレーベル',
  'Brand name': 'ブランド名',
  Abbreviation: '略称',
  Tagline: 'タグライン',
  Introduction: '紹介',
  'Active status': '有効状態',
  'Founded year': '設立年',
  Frequency: '開催頻度',
  'Background image': '背景画像',
  'External links': '外部リンク',
  'Related events': '関連イベント',
  'Related posts': '関連投稿',
  'Related news': '関連ニュース',
  'Set title': 'Setタイトル',
  'Set localized title': 'Set多言語タイトル',
  'Set slug': 'Set slug',
  'Set description': 'Set説明',
  'Set localized description': 'Set多言語説明',
  'Video URL': '動画URL',
  'Video author': '動画投稿者',
  'Video platform': '動画プラットフォーム',
  'Platform video ID': 'プラットフォーム動画ID',
  'Video duration': '動画時間',
  Thumbnail: 'サムネイル',
  'Recorded date': '録音日',
  Venue: '会場',
  'Related event ID': '関連イベントID',
  'Related event': '関連イベント',
  'View count': '再生数',
  'Like count': 'いいね数',
  'Primary DJ ID': 'メインDJ ID',
  'Primary DJ': 'メインDJ',
  'Custom artists': 'カスタムアーティスト',
  'Set lineup': 'Setラインナップ',
  'Track list': 'トラックリスト',
  'Track position': 'トラック番号',
  'Track title': '曲名',
  'Track artist': 'トラックアーティスト',
  'Track status': 'トラック状態',
  'Track label': 'トラックレーベル',
  'Release year': 'リリース年',
  'Track start time': 'トラック開始時刻',
  'Track end time': 'トラック終了時刻',
  'Spotify track ID': 'SpotifyトラックID',
  'Spotify URI': 'Spotify URI',
  'Apple Music URL': 'Apple Musicリンク',
  'YouTube Music URL': 'YouTube Musicリンク',
  'Beatport URL': 'Beatportリンク',
  'Netease URL': 'NetEaseリンク',
  'Netease track ID': 'NetEaseトラックID',
  'News title': 'ニュースタイトル',
  'News summary': 'ニュース要約',
  'Body preview': '本文プレビュー',
  'Body hash': '本文フィンガープリント',
  'News category': 'ニュースカテゴリ',
  'News source': 'ニュースソース',
  Visibility: '公開範囲',
  'Source link': '元記事リンク',
  'Author ID': '作者ID',
  'Published time': '公開日時',
  'Related DJs': '関連DJ',
  'Related brands': '関連ブランド',
  'Content preview': '内容プレビュー',
  'Content hash': '内容フィンガープリント',
  'Localized title': '多言語タイトル',
  'Localized summary': '多言語要約',
  'Localized body': '多言語本文',
  Images: '画像',
  Location: '場所',
  'Post type': '投稿タイプ',
  'Squad ID': '小隊ID',
  'Related set': '関連Set',
  'Display published time': '表示公開日時',
  'Repost count': 'リポスト数',
  'Save count': '保存数',
  'Share count': 'シェア数',
  'Hide count': '非表示数',
  'Comment count': 'コメント数',
  'Label name': 'レーベル名',
  'Localized name': '多言語名',
  'Label slug': 'レーベルslug',
  'Profile URL': 'プロフィールURL',
  'Profile slug': 'プロフィールslug',
  'Introduction preview': '紹介プレビュー',
  'Localized description': '多言語紹介',
  'Source page': 'ソースページ',
  'Source listing URL': 'ソース一覧URL',
  'Source card ID': 'ソースカードID',
  Logo: 'ロゴ',
  'Avatar source URL': 'アバター元URL',
  'Background source URL': '背景画像元URL',
  'Location period': '地域・期間',
  'Genres preview': 'ジャンルプレビュー',
  'Latest release listing': '最新リリース',
  Contacts: '連絡先',
  'Contact email': '連絡メール',
  'Demo submission URL': 'Demo送信URL',
  'Demo submission display': 'Demo送信表示文言',
  'Web links': 'Webリンク',
  'Music purchase URL': '購入リンク',
  Founder: '創設者',
  'Founded at': '設立時期',
  'Founder DJ': '創設者DJ',
  'SoundCloud followers': 'SoundCloudフォロワー数',
  Likes: 'いいね数',
  Facebook: 'Facebook',
  Instagram: 'Instagram',
  'X / Twitter': 'X / Twitter',
  YouTube: 'YouTube',
  TikTok: 'TikTok',
};

const labelJaFor = (config: ChangePathConfig): string =>
  config.labelJa ?? labelJaByEn[config.labelEn] ?? config.labelZh;

const resolveConfig = (
  path: string,
  configs: Record<string, ChangePathConfig>
): ChangePathConfig => {
  if (configs[path]) return configs[path];
  const segments = path.split('.');
  for (let index = segments.length - 2; index >= 1; index -= 1) {
    const candidate = [...segments.slice(0, index), ...segments.slice(index + 1)].join('.');
    if (configs[candidate]) return configs[candidate];
  }
  while (segments.length > 0) {
    segments.pop();
    const candidate = segments.join('.');
    if (candidate && configs[candidate]) return configs[candidate];
  }
  return defaultConfig(path);
};

const defaultFormat = (value: unknown): string | null => {
  if (value === null || value === undefined) return null;
  if (typeof value === 'string') {
    if (!value) return null;
    return value.length > 80 ? `${value.slice(0, 77)}...` : value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (Array.isArray(value)) return value.map(defaultFormat).filter(Boolean).join(', ');
  if (isRecord(value)) {
    const label = value.name ?? value.title ?? value.displayName ?? value.id;
    if (typeof label === 'string' && label.trim()) return label.trim();
    return stableSerialize(value).slice(0, 80);
  }
  return String(value);
};

const makeChange = (input: {
  kind: EntityChange['kind'];
  path: string;
  before: unknown;
  after: unknown;
  config: ChangePathConfig;
  entityType: EntityChangeEntityType;
  beforeSnapshot?: EntitySnapshot | null;
  afterSnapshot?: EntitySnapshot | null;
  itemKey?: string | null;
  itemLabel?: string | null;
}): EntityChange => {
  const beforeFormatted = input.config.formatter?.(input.before, {
    path: input.path,
    entityType: input.entityType,
    snapshot: input.beforeSnapshot ?? null,
  });
  const afterFormatted = input.config.formatter?.(input.after, {
    path: input.path,
    entityType: input.entityType,
    snapshot: input.afterSnapshot ?? null,
  });

  return {
    id: crypto.randomUUID(),
    kind: input.kind,
    path: input.path,
    pathLabelZh: input.config.labelZh,
    pathLabelEn: input.config.labelEn,
    pathLabelJa: labelJaFor(input.config),
    category: input.config.category,
    audience: input.config.audience,
    publicSafe: input.config.publicSafe,
    sensitive: Boolean(input.config.sensitive),
    before: input.before,
    after: input.after,
    beforeDisplayZh: beforeFormatted?.zh ?? defaultFormat(input.before),
    afterDisplayZh: afterFormatted?.zh ?? defaultFormat(input.after),
    beforeDisplayEn: beforeFormatted?.en ?? defaultFormat(input.before),
    afterDisplayEn: afterFormatted?.en ?? defaultFormat(input.after),
    beforeDisplayJa: beforeFormatted?.ja ?? beforeFormatted?.zh ?? defaultFormat(input.before),
    afterDisplayJa: afterFormatted?.ja ?? afterFormatted?.zh ?? defaultFormat(input.after),
    itemKey: input.itemKey ?? null,
    itemLabelZh: input.itemLabel ?? null,
    itemLabelEn: input.itemLabel ?? null,
  };
};

const diffSetArray = (input: {
  path: string;
  before: unknown[];
  after: unknown[];
  config: ChangePathConfig;
  entityType: EntityChangeEntityType;
  beforeSnapshot?: EntitySnapshot | null;
  afterSnapshot?: EntitySnapshot | null;
}): EntityChange[] => {
  const beforeMap = new Map(input.before.map((item) => [hashCanonicalValue(item), item]));
  const afterMap = new Map(input.after.map((item) => [hashCanonicalValue(item), item]));
  const changes: EntityChange[] = [];

  for (const [key, item] of beforeMap) {
    if (!afterMap.has(key)) {
      changes.push(makeChange({
        kind: 'removed',
        path: input.path,
        before: item,
        after: null,
        config: input.config,
        entityType: input.entityType,
        beforeSnapshot: input.beforeSnapshot,
        afterSnapshot: input.afterSnapshot,
        itemKey: key,
      }));
    }
  }

  for (const [key, item] of afterMap) {
    if (!beforeMap.has(key)) {
      changes.push(makeChange({
        kind: 'added',
        path: input.path,
        before: null,
        after: item,
        config: input.config,
        entityType: input.entityType,
        beforeSnapshot: input.beforeSnapshot,
        afterSnapshot: input.afterSnapshot,
        itemKey: key,
      }));
    }
  }

  return changes;
};

const diffKeyedArray = (input: {
  path: string;
  before: unknown[];
  after: unknown[];
  config: ChangePathConfig;
  definition: EntityChangeDefinition;
  keyPath: string;
  orderMatters: boolean;
  beforeSnapshot?: EntitySnapshot | null;
  afterSnapshot?: EntitySnapshot | null;
}): EntityChange[] => {
  const keyFor = (item: unknown, index: number): string => {
    const key = getPathValue(item, input.keyPath);
    return typeof key === 'string' || typeof key === 'number' ? String(key) : `index:${index}`;
  };
  const beforeMap = new Map(input.before.map((item, index) => [keyFor(item, index), item]));
  const afterMap = new Map(input.after.map((item, index) => [keyFor(item, index), item]));
  const changes: EntityChange[] = [];

  for (const [key, item] of beforeMap) {
    if (!afterMap.has(key)) {
      changes.push(makeChange({
        kind: 'removed',
        path: input.path,
        before: item,
        after: null,
        config: input.config,
        entityType: input.definition.entityType,
        beforeSnapshot: input.beforeSnapshot,
        afterSnapshot: input.afterSnapshot,
        itemKey: key,
      }));
    }
  }

  for (const [key, item] of afterMap) {
    if (!beforeMap.has(key)) {
      changes.push(makeChange({
        kind: 'added',
        path: input.path,
        before: null,
        after: item,
        config: input.config,
        entityType: input.definition.entityType,
        beforeSnapshot: input.beforeSnapshot,
        afterSnapshot: input.afterSnapshot,
        itemKey: key,
      }));
    }
  }

  for (const [key, beforeItem] of beforeMap) {
    const afterItem = afterMap.get(key);
    if (afterItem === undefined) continue;
    changes.push(...diffValue({
      path: `${input.path}.${key}`,
      before: beforeItem,
      after: afterItem,
      definition: input.definition,
      beforeSnapshot: input.beforeSnapshot,
      afterSnapshot: input.afterSnapshot,
    }));
  }

  if (input.orderMatters) {
    const beforeOrder = input.before.map(keyFor).join('|');
    const afterOrder = input.after.map(keyFor).join('|');
    if (beforeOrder !== afterOrder && beforeMap.size === afterMap.size) {
      changes.push(makeChange({
        kind: 'reordered',
        path: input.path,
        before: beforeOrder,
        after: afterOrder,
        config: input.config,
        entityType: input.definition.entityType,
        beforeSnapshot: input.beforeSnapshot,
        afterSnapshot: input.afterSnapshot,
      }));
    }
  }

  return changes;
};

const diffOrderedArray = (input: {
  path: string;
  before: unknown[];
  after: unknown[];
  config: ChangePathConfig;
  definition: EntityChangeDefinition;
  beforeSnapshot?: EntitySnapshot | null;
  afterSnapshot?: EntitySnapshot | null;
}): EntityChange[] => {
  const changes: EntityChange[] = [];
  const maxLength = Math.max(input.before.length, input.after.length);
  for (let index = 0; index < maxLength; index += 1) {
    const beforeItem = input.before[index];
    const afterItem = input.after[index];
    if (beforeItem === undefined && afterItem !== undefined) {
      changes.push(makeChange({
        kind: 'added',
        path: `${input.path}.${index}`,
        before: null,
        after: afterItem,
        config: input.config,
        entityType: input.definition.entityType,
        beforeSnapshot: input.beforeSnapshot,
        afterSnapshot: input.afterSnapshot,
        itemKey: String(index),
      }));
      continue;
    }
    if (beforeItem !== undefined && afterItem === undefined) {
      changes.push(makeChange({
        kind: 'removed',
        path: `${input.path}.${index}`,
        before: beforeItem,
        after: null,
        config: input.config,
        entityType: input.definition.entityType,
        beforeSnapshot: input.beforeSnapshot,
        afterSnapshot: input.afterSnapshot,
        itemKey: String(index),
      }));
      continue;
    }
    changes.push(...diffValue({
      path: `${input.path}.${index}`,
      before: beforeItem,
      after: afterItem,
      definition: input.definition,
      beforeSnapshot: input.beforeSnapshot,
      afterSnapshot: input.afterSnapshot,
    }));
  }

  const beforeItemHashes = input.before.map(hashCanonicalValue).sort().join('|');
  const afterItemHashes = input.after.map(hashCanonicalValue).sort().join('|');
  const beforeOrderHashes = input.before.map(hashCanonicalValue).join('|');
  const afterOrderHashes = input.after.map(hashCanonicalValue).join('|');
  if (
    input.before.length === input.after.length &&
    beforeItemHashes === afterItemHashes &&
    beforeOrderHashes !== afterOrderHashes
  ) {
    changes.push(makeChange({
      kind: 'reordered',
      path: input.path,
      before: beforeOrderHashes,
      after: afterOrderHashes,
      config: input.config,
      entityType: input.definition.entityType,
      beforeSnapshot: input.beforeSnapshot,
      afterSnapshot: input.afterSnapshot,
    }));
  }

  return changes;
};

const diffValue = (input: {
  path: string;
  before: unknown;
  after: unknown;
  definition: EntityChangeDefinition;
  beforeSnapshot?: EntitySnapshot | null;
  afterSnapshot?: EntitySnapshot | null;
}): EntityChange[] => {
  const config = resolveConfig(input.path, input.definition.paths);
  const before = canonicalizeValue(input.before, input.path, input.definition.paths);
  const after = canonicalizeValue(input.after, input.path, input.definition.paths);

  if (hashCanonicalValue(before) === hashCanonicalValue(after)) return [];

  if (Array.isArray(before) || Array.isArray(after)) {
    const beforeArray = Array.isArray(before) ? before : [];
    const afterArray = Array.isArray(after) ? after : [];
    const strategy = config.arrayStrategy;
    if (strategy?.type === 'set') {
      return diffSetArray({
        path: input.path,
        before: beforeArray,
        after: afterArray,
        config,
        entityType: input.definition.entityType,
        beforeSnapshot: input.beforeSnapshot,
        afterSnapshot: input.afterSnapshot,
      });
    }
    if (strategy?.type === 'keyed-list') {
      return diffKeyedArray({
        path: input.path,
        before: beforeArray,
        after: afterArray,
        config,
        definition: input.definition,
        keyPath: strategy.keyPath,
        orderMatters: strategy.orderMatters,
        beforeSnapshot: input.beforeSnapshot,
        afterSnapshot: input.afterSnapshot,
      });
    }
    if (strategy?.type === 'ordered-list') {
      if (strategy.itemIdentity === 'key' && strategy.keyPath) {
        return diffKeyedArray({
          path: input.path,
          before: beforeArray,
          after: afterArray,
          config,
          definition: input.definition,
          keyPath: strategy.keyPath,
          orderMatters: true,
          beforeSnapshot: input.beforeSnapshot,
          afterSnapshot: input.afterSnapshot,
        });
      }
      return diffOrderedArray({
        path: input.path,
        before: beforeArray,
        after: afterArray,
        config,
        definition: input.definition,
        beforeSnapshot: input.beforeSnapshot,
        afterSnapshot: input.afterSnapshot,
      });
    }
  }

  if (isRecord(before) || isRecord(after)) {
    const beforeRecord = isRecord(before) ? before : {};
    const afterRecord = isRecord(after) ? after : {};
    const keys = Array.from(new Set([...Object.keys(beforeRecord), ...Object.keys(afterRecord)])).sort();
    return keys.flatMap((key) => diffValue({
      path: input.path ? `${input.path}.${key}` : key,
      before: beforeRecord[key],
      after: afterRecord[key],
      definition: input.definition,
      beforeSnapshot: input.beforeSnapshot,
      afterSnapshot: input.afterSnapshot,
    }));
  }

  const kind: EntityChange['kind'] =
    before === null || before === undefined ? 'added' : after === null || after === undefined ? 'removed' : 'updated';
  return [makeChange({
    kind,
    path: input.path,
    before,
    after,
    config,
    entityType: input.definition.entityType,
    beforeSnapshot: input.beforeSnapshot,
    afterSnapshot: input.afterSnapshot,
  })];
};

export const diffEntitySnapshots = (input: {
  definition: EntityChangeDefinition;
  before: EntitySnapshot | null;
  after: EntitySnapshot | null;
}): {
  diffSchemaVersion: number;
  beforeHash: string | null;
  afterHash: string | null;
  changes: EntityChange[];
  publicChanges: PublicEntityChange[];
} => {
  const beforeData = input.before
    ? canonicalizeValue(input.before.data, '', input.definition.paths)
    : null;
  const afterData = input.after
    ? canonicalizeValue(input.after.data, '', input.definition.paths)
    : null;
  const beforeHash = input.before ? hashCanonicalValue(beforeData) : null;
  const afterHash = input.after ? hashCanonicalValue(afterData) : null;

  if (beforeHash && afterHash && beforeHash === afterHash) {
    return {
      diffSchemaVersion: DIFF_SCHEMA_VERSION,
      beforeHash,
      afterHash,
      changes: [],
      publicChanges: [],
    };
  }

  const changes = diffValue({
    path: '',
    before: beforeData,
    after: afterData,
    definition: input.definition,
    beforeSnapshot: input.before,
    afterSnapshot: input.after,
  });
  const publicChanges = changes
    .filter((change) => change.publicSafe && change.audience === 'public')
    .map((change) => ({
      path: change.path,
      label: change.pathLabelZh,
      labelZh: change.pathLabelZh,
      labelEn: change.pathLabelEn,
      labelJa: change.pathLabelJa,
      kind: change.kind,
      before: change.beforeDisplayZh,
      after: change.afterDisplayZh,
      beforeEn: change.beforeDisplayEn,
      afterEn: change.afterDisplayEn,
      beforeJa: change.beforeDisplayJa,
      afterJa: change.afterDisplayJa,
    }));

  return {
    diffSchemaVersion: DIFF_SCHEMA_VERSION,
    beforeHash,
    afterHash,
    changes,
    publicChanges,
  };
};
