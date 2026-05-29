import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { StatusBar } from 'expo-status-bar';
import React, { useEffect, useRef, useState } from 'react';
import {
  Animated,
  Image,
  Modal,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  useWindowDimensions,
  View,
} from 'react-native';

import type { MainTabKey } from '../../../application/navigation/routes';
import { useAppContainer } from '../../../application/di/AppContainer';
import { CircleHomeView } from '../../circle/views/CircleHomeView';
import {
  fetchRemoteDJDetail,
  fetchRemoteDJEvents,
  fetchRemoteDJs,
  fetchRemoteEventDetail,
  fetchRemoteFestivalDetail,
  fetchRemoteFestivals,
  fetchRemoteGenreDetail,
  fetchRemoteGenreTreeSummary,
  fetchRemoteLabelDetail,
  fetchRemoteLabelList,
  fetchRemoteRankingBoardDetail,
  fetchRemoteRankingBoards,
  type RemoteDJ,
  type RemoteEvent,
  type RemoteFestival,
  type RemoteGenreDetail,
  type RemoteGenreSummaryNode,
  type RemoteLabel,
  type RemoteRankingBoard,
  type RemoteRankingBoardDetail,
} from '../data/discoverRemoteSource';
import { useRecommendEventsViewModel } from '../recommend/viewModels/useRecommendEventsViewModel';
import { InboxHomeView } from '../../inbox/views/InboxHomeView';
import { ProfileHomeView } from '../../profile/views/ProfileHomeView';
import { SafeBlurView } from '../../../shared/ui/SafeBlurView';

type DiscoverSectionKey =
  | 'recommend'
  | 'events'
  | 'news'
  | 'organizers'
  | 'djs'
  | 'labels'
  | 'rankings'
  | 'sets'
  | 'genres';

type MainTabItem = {
  key: MainTabKey;
  label: string;
  icon: keyof typeof Ionicons.glyphMap;
  activeIcon: keyof typeof Ionicons.glyphMap;
};

type DiscoverSection = {
  key: DiscoverSectionKey;
  label: string;
  color: string;
};

type RecommendationCard = {
  id: string;
  type: string;
  status: string;
  location: string;
  date: string;
  title: string;
  imageUrl?: string;
  palette: [string, string, string];
};

type EventTypeFilter = {
  key: string;
  label: string;
  color: string;
};

type EventListItem = {
  id: string;
  name: string;
  eventTypeKey: string;
  eventTypeLabel: string;
  status: string;
  statusColor: string;
  month: string;
  day: string;
  dateRange: string;
  address: string;
  palette: [string, string];
};

type NewsCategoryKey =
  | 'all'
  | 'festival'
  | 'scene'
  | 'gear'
  | 'industry'
  | 'community';

type NewsCategoryItem = {
  key: NewsCategoryKey;
  label: string;
  color: string;
};

type NewsArticle = {
  id: string;
  category: NewsCategoryKey;
  source: string;
  title: string;
  summary: string;
  publishedAt: string;
  replyCount: number;
  palette: [string, string];
};

type OrganizerItem = {
  id: string;
  name: string;
  country: string;
  city: string;
  foundedYear: string;
  frequency: string;
  palette: [string, string];
  monogram: string;
};

type LabelItem = {
  id: string;
  name: string;
  country: string;
  city: string;
  foundedYear: string;
  focus: string;
  releases: string;
  followers: string;
  palette: [string, string];
  monogram: string;
};

type DJSummary = {
  id: string;
  name: string;
  country: string;
  city: string;
  genres: string[];
  palette: [string, string];
  monogram: string;
};

type RankingBoardKey = 'events' | 'djs' | 'organizers';

type RankingEntry = {
  id: string;
  title: string;
  subtitle: string;
  score: string;
  delta: string;
  palette: [string, string];
  kind: 'event' | 'dj' | 'organizer';
  targetId: string;
};

type SetListItem = {
  id: string;
  title: string;
  djId: string;
  djName: string;
  eventId: string;
  eventTitle: string;
  duration: string;
  bpm: string;
  style: string;
  palette: [string, string];
};

type GenreSpotlight = {
  id: string;
  name: string;
  description: string;
  energy: string;
  scene: string;
  relatedDJId: string;
  relatedDJName: string;
  relatedEventId: string;
  relatedEventTitle: string;
  palette: [string, string];
};

type EventScheduleSlot = {
  time: string;
  stage: string;
  artistId: string;
  artistName: string;
};

type EventDetailData = {
  id: string;
  title: string;
  subtitle: string;
  location: string;
  schedule: string;
  organizerName: string;
  organizerId: string;
  description: string;
  heroPalette: [string, string, string];
  lineup: DJSummary[];
  scheduleSlots: EventScheduleSlot[];
  news: NewsArticle[];
  posts: string[];
  ratings: string[];
  sets: string[];
};

type DJDetailData = {
  id: string;
  name: string;
  subtitle: string;
  country: string;
  city: string;
  genres: string[];
  bio: string;
  heroPalette: [string, string, string];
  honors: string[];
  upcomingEvents: string[];
  ratings: string[];
  posts: string[];
  sets: string[];
};

type OrganizerDetailData = {
  id: string;
  name: string;
  subtitle: string;
  country: string;
  city: string;
  foundedYear: string;
  frequency: string;
  intro: string;
  heroPalette: [string, string, string];
  events: string[];
  posts: string[];
};

type NewsDetailData = {
  id: string;
  category: NewsCategoryKey;
  source: string;
  title: string;
  summary: string;
  publishedAt: string;
  heroPalette: [string, string, string];
  body: string[];
  relatedEvents: string[];
  discussion: string[];
};

type LabelDetailData = {
  id: string;
  name: string;
  subtitle: string;
  country: string;
  city: string;
  foundedYear: string;
  focus: string;
  intro: string;
  heroPalette: [string, string, string];
  featuredDJs: string[];
  releases: string[];
  posts: string[];
};

type SetDetailData = {
  id: string;
  title: string;
  subtitle: string;
  djId: string;
  djName: string;
  eventId: string;
  eventTitle: string;
  duration: string;
  bpm: string;
  style: string;
  description: string;
  heroPalette: [string, string, string];
  trackHighlights: string[];
  notes: string[];
};

type GenreDetailData = {
  id: string;
  name: string;
  subtitle: string;
  description: string;
  energy: string;
  scene: string;
  heroPalette: [string, string, string];
  relatedDJs: string[];
  relatedEvents: string[];
  listeningNotes: string[];
};

type RankingBoardDetailEntry = {
  rank: number;
  title: string;
  subtitle: string;
  score: string;
  delta: string;
  note: string;
  palette: [string, string];
  kind: 'event' | 'dj' | 'organizer';
  targetId: string;
};

type RankingBoardDimension = {
  label: string;
  weight: string;
  note: string;
};

type RankingBoardDetailData = {
  key: RankingBoardKey;
  title: string;
  subtitle: string;
  summary: string;
  updatedAt: string;
  scope: string;
  heroPalette: [string, string, string];
  snapshot: string[];
  trends: string[];
  dimensions: RankingBoardDimension[];
  methodology: string[];
  entries: RankingBoardDetailEntry[];
};

type EventDetailAddon = {
  doorTime: string;
  travelWindow: string;
  audienceProfile: string;
  vibeTags: string[];
  labelSpotlights: string[];
  venueTips: string[];
  ticketTips: string[];
};

type DJDetailAddon = {
  slotFocus: string;
  route: string;
  pace: string;
  labels: string[];
  relatedNewsIDs: string[];
  styleNotes: string[];
  listeningMoments: string[];
};

type OrganizerDetailAddon = {
  signatureStyle: string;
  audienceProfile: string;
  coverageCities: string[];
  relatedNewsIDs: string[];
  focusLabels: string[];
  productionNotes: string[];
};

type NewsDetailAddon = {
  keyTakeaways: string[];
  involvedScenes: string[];
  editorNotes: string[];
};

type LabelDetailAddon = {
  signatureKeywords: string[];
  keyCities: string[];
  relatedNewsIDs: string[];
  relatedSets: string[];
  curationNotes: string[];
};

type SetDetailAddon = {
  recordingSource: string;
  structureSummary: string;
  relatedNewsIDs: string[];
  relatedLabels: string[];
  idealScenes: string[];
  chapterNotes: string[];
};

type GenreDetailAddon = {
  tempoRange: string;
  commonSlots: string[];
  moodKeywords: string[];
  entrySets: string[];
  relatedLabels: string[];
};

type DetailDestination =
  | { kind: 'event'; item: EventDetailData }
  | { kind: 'dj'; item: DJDetailData }
  | { kind: 'organizer'; item: OrganizerDetailData }
  | { kind: 'news'; item: NewsDetailData }
  | { kind: 'label'; item: LabelDetailData }
  | { kind: 'set'; item: SetDetailData }
  | { kind: 'genre'; item: GenreDetailData }
  | { kind: 'rankingBoard'; item: RankingBoardDetailData };

type EventDetailTabKey =
  | 'info'
  | 'lineup'
  | 'schedule'
  | 'news'
  | 'posts'
  | 'ratings'
  | 'sets';

type DJDetailTabKey = 'intro' | 'events' | 'ratings' | 'posts' | 'sets';
type OrganizerDetailTabKey = 'basic' | 'events' | 'posts';
type NewsDetailTabKey = 'article' | 'events' | 'discussion';
type LabelDetailTabKey = 'basic' | 'djs' | 'releases' | 'posts';
type SetDetailTabKey = 'basic' | 'tracks' | 'event';
type GenreDetailTabKey = 'overview' | 'djs' | 'events' | 'notes';
type RankingBoardDetailTabKey = 'overview' | 'top' | 'dimensions' | 'method';

type MeasuredLayout = {
  x: number;
  width: number;
};

const THEME = {
  background: '#08080A',
  card: '#1C1C1F',
  cardBorder: 'rgba(255,255,255,0.1)',
  primaryText: '#F5F5F7',
  secondaryText: '#A3A3AD',
  accent: '#8C5CFF',
  tabBarChromeStart: 'rgba(25,20,38,0.92)',
  tabBarChromeEnd: 'rgba(32,23,53,0.92)',
  tabBarSelectionStart: 'rgba(133,102,255,0.92)',
  tabBarSelectionEnd: 'rgba(106,74,231,0.88)',
  tabBarStrokeLeading: 'rgba(255,255,255,0.22)',
  tabBarStrokeTrailing: 'rgba(182,160,255,0.26)',
  tabBarSelectionStroke: 'rgba(255,255,255,0.18)',
  pageIndicator: '#29F3EA',
};

const DISCOVER_REMOTE_PALETTES: Array<[string, string, string]> = [
  ['#214E57', '#111722', '#08090C'],
  ['#402657', '#13121B', '#09090C'],
  ['#15506A', '#101B24', '#07090C'],
  ['#4C263B', '#17121A', '#08080B'],
  ['#2F3850', '#12151C', '#08090C'],
  ['#24394C', '#10141B', '#08090C'],
];

const EVENT_TYPE_LABELS: Record<string, string> = {
  festival: '电音节',
  club_party: '俱乐部',
  club: '俱乐部',
  warehouse_party: '仓库派对',
  warehouse: '仓库派对',
  outdoor_event: '户外',
  outdoor: '户外',
  bar_event: '酒吧',
};

const EVENT_STATUS_LABELS: Record<string, string> = {
  upcoming: '即将开始',
  ongoing: '正在进行',
  completed: '已结束',
  ended: '已结束',
  cancelled: '已取消',
  draft: '待发布',
};

const EVENT_STATUS_COLORS: Record<string, string> = {
  upcoming: '#F58433',
  ongoing: '#46C96D',
  completed: '#6D92F4',
  ended: '#6D92F4',
  cancelled: '#DF4F7B',
  draft: '#8C5CFF',
};

function remotePalette(index: number): [string, string, string] {
  return DISCOVER_REMOTE_PALETTES[index % DISCOVER_REMOTE_PALETTES.length]!;
}

function remoteCardPalette(index: number): [string, string] {
  const palette = remotePalette(index);
  return [palette[0], palette[1]];
}

function deriveMonogram(name: string) {
  const trimmed = name.trim();
  if (!trimmed) {
    return 'RV';
  }
  const compact = trimmed.replace(/[^A-Za-z0-9\u4e00-\u9fa5]/g, '');
  return compact.slice(0, 2).toUpperCase();
}

function normalizeLookupKey(input?: string | null) {
  return (input ?? '')
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .replace(/\s+/g, ' ');
}

function formatMonthDay(iso: string) {
  const date = new Date(iso);
  const month = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'][date.getMonth()] ?? 'JAN';
  const day = String(date.getDate()).padStart(2, '0');
  return { month, day };
}

function formatDateLine(startISO: string, endISO: string) {
  const start = new Date(startISO);
  const end = new Date(endISO);
  const startDate = `${start.getFullYear()}.${String(start.getMonth() + 1).padStart(2, '0')}.${String(start.getDate()).padStart(2, '0')}`;
  const endDate = `${end.getFullYear()}.${String(end.getMonth() + 1).padStart(2, '0')}.${String(end.getDate()).padStart(2, '0')}`;
  return `${startDate} - ${endDate}`;
}

function formatCountryName(input?: string | null) {
  if (!input) {
    return '未知';
  }

  const map: Record<string, string> = {
    CHN: '中国',
    DEU: '德国',
    FRA: '法国',
    NLD: '荷兰',
    USA: '美国',
    GBR: '英国',
    JPN: '日本',
    THA: '泰国',
    IND: '印度',
    US: '美国',
    IN: '印度',
  };

  return map[input] ?? input;
}

function formatFollowerCount(value?: number | null) {
  if (!value || value <= 0) {
    return '0 Followers';
  }
  if (value >= 1000000) {
    return `${(value / 1000000).toFixed(1)}M Followers`;
  }
  if (value >= 1000) {
    return `${Math.round(value / 1000)}k Followers`;
  }
  return `${value} Followers`;
}

function flattenGenreNodes(nodes: RemoteGenreSummaryNode[]): RemoteGenreSummaryNode[] {
  const output: RemoteGenreSummaryNode[] = [];

  for (const node of nodes) {
    output.push(node);
    if (Array.isArray(node.children) && node.children.length > 0) {
      output.push(...flattenGenreNodes(node.children));
    }
  }

  return output;
}

function formatRankingYearRange(years?: number[] | null) {
  const validYears = (years ?? []).filter(year => Number.isFinite(year));
  return String(validYears.length > 0 ? Math.max(...validYears) : 2025);
}

function formatRankingDelta(delta?: number | null) {
  if (typeof delta !== 'number') {
    return '—';
  }
  if (delta === 0) {
    return '0';
  }
  return delta > 0 ? `+${delta}` : `${delta}`;
}

const MAIN_TABS: MainTabItem[] = [
  {
    key: 'discover',
    label: '发现',
    icon: 'compass-outline',
    activeIcon: 'compass',
  },
  {
    key: 'circle',
    label: '圈子',
    icon: 'people-outline',
    activeIcon: 'people',
  },
  {
    key: 'inbox',
    label: '收件箱',
    icon: 'chatbubbles-outline',
    activeIcon: 'chatbubbles',
  },
  {
    key: 'profile',
    label: '我的',
    icon: 'person-circle-outline',
    activeIcon: 'person-circle',
  },
];

const DISCOVER_SECTIONS: DiscoverSection[] = [
  { key: 'recommend', label: '推荐', color: '#45D9D1' },
  { key: 'events', label: '活动', color: '#F78A35' },
  { key: 'news', label: '资讯', color: '#F9A640' },
  { key: 'organizers', label: '主办方', color: '#E46593' },
  { key: 'djs', label: 'DJ', color: '#76C955' },
  { key: 'labels', label: '厂牌', color: '#6D92F4' },
  { key: 'rankings', label: '榜单', color: '#BB79F3' },
  { key: 'sets', label: 'Sets', color: '#4CA9F7' },
  { key: 'genres', label: '流派', color: '#38C8A7' },
];

const RECOMMENDATIONS: RecommendationCard[] = [
  {
    id: '1',
    type: 'Festival',
    status: '即将开始',
    location: '上海 · Main Stage Warehouse',
    date: '2026.06.21 周六 23:00',
    title: 'HYPERWAVE\nSUMMER OPENING',
    palette: ['#175C57', '#0A1B22', '#020304'],
  },
  {
    id: '2',
    type: 'Club Night',
    status: '正在进行',
    location: '成都 · Riverfront Hall',
    date: '2026.06.28 周六 22:30',
    title: 'AFTERGLOW\nCITY SESSION',
    palette: ['#4A215D', '#12101F', '#040406'],
  },
  {
    id: '3',
    type: 'Open Air',
    status: '已结束',
    location: '深圳 · Coastline Park',
    date: '2026.07.05 周日 18:30',
    title: 'SUNSET\nFREQUENCY',
    palette: ['#144B6A', '#0A131E', '#020304'],
  },
];

const EVENT_TYPE_FILTERS: EventTypeFilter[] = [
  { key: 'all', label: '全部', color: '#8C5CFF' },
  { key: 'festival', label: '电音节', color: '#F58433' },
  { key: 'club_party', label: '俱乐部', color: '#C95CF0' },
  { key: 'warehouse_party', label: '仓库派对', color: '#DF4F7B' },
  { key: 'outdoor_event', label: '户外', color: '#46C96D' },
  { key: 'bar_event', label: '酒吧', color: '#55ABF5' },
];

const EVENTS_FEED: EventListItem[] = [
  {
    id: 'event-1',
    name: 'Vision Wave 2026 Shanghai Opening',
    eventTypeKey: 'festival',
    eventTypeLabel: '电音节',
    status: '即将开始',
    statusColor: '#F58433',
    month: 'JUN',
    day: '21',
    dateRange: '2026.06.21 周六 23:00 - 06.22 周日 06:00',
    address: '上海 · Main Stage Warehouse',
    palette: ['#244B57', '#0E121A'],
  },
  {
    id: 'event-2',
    name: 'Afterglow City Session with NORA',
    eventTypeKey: 'club_party',
    eventTypeLabel: '俱乐部',
    status: '售票中',
    statusColor: '#8C5CFF',
    month: 'JUN',
    day: '28',
    dateRange: '2026.06.28 周六 22:30 - 06.29 周日 05:00',
    address: '成都 · Riverfront Hall',
    palette: ['#4B245A', '#15131D'],
  },
  {
    id: 'event-3',
    name: 'Sunset Frequency Open Air',
    eventTypeKey: 'outdoor_event',
    eventTypeLabel: '户外',
    status: '限量余票',
    statusColor: '#46C96D',
    month: 'JUL',
    day: '05',
    dateRange: '2026.07.05 周日 18:30 - 23:30',
    address: '深圳 · Coastline Park',
    palette: ['#17506A', '#101822'],
  },
  {
    id: 'event-4',
    name: 'Warehouse Motion All Night Long',
    eventTypeKey: 'warehouse_party',
    eventTypeLabel: '仓库派对',
    status: '即将售罄',
    statusColor: '#DF4F7B',
    month: 'JUL',
    day: '12',
    dateRange: '2026.07.12 周六 23:59 - 07.13 周日 08:00',
    address: '北京 · Unit 09 Warehouse',
    palette: ['#5B263B', '#18131A'],
  },
];

const NEWS_CATEGORIES: NewsCategoryItem[] = [
  { key: 'all', label: '全部', color: '#A3A3AD' },
  { key: 'festival', label: '电音节', color: '#F58433' },
  { key: 'scene', label: '现场观察', color: '#55ABF5' },
  { key: 'gear', label: '设备玩法', color: '#66C95F' },
  { key: 'industry', label: '行业动态', color: '#DE874A' },
  { key: 'community', label: '社区话题', color: '#B38CEE' },
];

const NEWS_FEED: NewsArticle[] = [
  {
    id: 'news-1',
    category: 'festival',
    source: 'Raver 编辑部',
    title: '2026 夏季电音节排期更新，长三角仓库场地热度持续升高',
    summary: '从上海到苏州的新场地释放速度明显加快，主办方正在把更多预算投入夜间沉浸式视觉与音响升级。',
    publishedAt: '2026.06.03 20:14',
    replyCount: 18,
    palette: ['#30261F', '#171412'],
  },
  {
    id: 'news-2',
    category: 'scene',
    source: '现场观察',
    title: '我们在成都看了一晚上的开场编排，舞台转场终于不再拖沓',
    summary: '几位本地 promoter 开始用更轻的结构去连接 headliner 和 support，观众留存时间比去年更长。',
    publishedAt: '2026.06.02 18:40',
    replyCount: 26,
    palette: ['#1F2A36', '#12161C'],
  },
  {
    id: 'news-3',
    category: 'gear',
    source: '设备研究所',
    title: '中型 club 正在回流模拟机架，VJ 与灯控的联动方式也跟着变了',
    summary: '本轮升级更强调“低延迟”和“少切换”，后台工作流明显向巡演级配置靠拢。',
    publishedAt: '2026.06.01 16:08',
    replyCount: 9,
    palette: ['#1D3124', '#121815'],
  },
  {
    id: 'news-4',
    category: 'community',
    source: '社区热议',
    title: '你最在意活动页里的什么信息？票务、lineup、还是场地图例',
    summary: '最近很多用户开始把“交通离场体验”和“二次入场规则”放到决策前列，讨论度意外地高。',
    publishedAt: '2026.05.31 22:21',
    replyCount: 41,
    palette: ['#2B2336', '#15131A'],
  },
];

const ORGANIZER_FEED: OrganizerItem[] = [
  {
    id: 'organizer-1',
    name: 'Tomorrowland',
    country: '比利时',
    city: 'Boom',
    foundedYear: '2005',
    frequency: '年度',
    palette: ['#273244', '#0E1118'],
    monogram: 'TO',
  },
  {
    id: 'organizer-2',
    name: 'Ultra Music Festival',
    country: '美国',
    city: 'Miami',
    foundedYear: '1999',
    frequency: '年度',
    palette: ['#2B364A', '#10131A'],
    monogram: 'UL',
  },
  {
    id: 'organizer-3',
    name: 'Storm Festival',
    country: '中国',
    city: '上海',
    foundedYear: '2013',
    frequency: '年度',
    palette: ['#3A2A3C', '#131116'],
    monogram: 'ST',
  },
  {
    id: 'organizer-4',
    name: 'EDC Las Vegas',
    country: '美国',
    city: 'Las Vegas',
    foundedYear: '1997',
    frequency: '年度',
    palette: ['#25384A', '#10141B'],
    monogram: 'ED',
  },
];

const LABEL_FEED: LabelItem[] = [
  {
    id: 'label-1',
    name: 'Afterlife',
    country: '意大利',
    city: 'Milan',
    foundedYear: '2016',
    focus: 'Melodic Techno / Immersive',
    releases: '184 Releases',
    followers: '92k Followers',
    palette: ['#2F3850', '#12151C'],
    monogram: 'AL',
  },
  {
    id: 'label-2',
    name: 'Drumcode',
    country: '瑞典',
    city: 'Stockholm',
    foundedYear: '1996',
    focus: 'Techno / Warehouse',
    releases: '302 Releases',
    followers: '118k Followers',
    palette: ['#3F2B3A', '#161117'],
    monogram: 'DC',
  },
  {
    id: 'label-3',
    name: 'Anjunadeep',
    country: '英国',
    city: 'London',
    foundedYear: '2005',
    focus: 'Deep House / Progressive',
    releases: '267 Releases',
    followers: '86k Followers',
    palette: ['#21485A', '#10161C'],
    monogram: 'AD',
  },
  {
    id: 'label-4',
    name: 'Ninja Tune',
    country: '英国',
    city: 'London',
    foundedYear: '1990',
    focus: 'Electronic / Leftfield',
    releases: '410 Releases',
    followers: '133k Followers',
    palette: ['#4C3424', '#17130F'],
    monogram: 'NT',
  },
];

const DJ_LIBRARY: DJSummary[] = [
  {
    id: 'dj-1',
    name: 'NORA',
    country: '德国',
    city: 'Berlin',
    genres: ['Melodic Techno', 'Progressive House'],
    palette: ['#28415C', '#12161D'],
    monogram: 'NO',
  },
  {
    id: 'dj-2',
    name: 'KARIN',
    country: '中国',
    city: '上海',
    genres: ['Techno', 'Warehouse'],
    palette: ['#4A274A', '#151118'],
    monogram: 'KA',
  },
  {
    id: 'dj-3',
    name: 'MATSU',
    country: '日本',
    city: 'Tokyo',
    genres: ['House', 'Disco'],
    palette: ['#24505B', '#12181C'],
    monogram: 'MA',
  },
];

const RANKING_BOARDS: Record<RankingBoardKey, RankingEntry[]> = {
  events: [
    {
      id: 'rank-event-1',
      title: 'Vision Wave 2026 Shanghai Opening',
      subtitle: '上海 · Main Stage Warehouse',
      score: '9.4',
      delta: '+2',
      palette: ['#244B57', '#0E121A'],
      kind: 'event',
      targetId: 'event-1',
    },
    {
      id: 'rank-event-2',
      title: 'Sunset Frequency Open Air',
      subtitle: '深圳 · Coastline Park',
      score: '9.1',
      delta: '+1',
      palette: ['#17506A', '#101822'],
      kind: 'event',
      targetId: 'event-3',
    },
    {
      id: 'rank-event-3',
      title: 'Warehouse Motion All Night Long',
      subtitle: '北京 · Unit 09 Warehouse',
      score: '8.9',
      delta: 'NEW',
      palette: ['#5B263B', '#18131A'],
      kind: 'event',
      targetId: 'event-4',
    },
  ],
  djs: [
    {
      id: 'rank-dj-1',
      title: 'NORA',
      subtitle: 'Berlin · Melodic Techno / Progressive House',
      score: '9.5',
      delta: '+1',
      palette: ['#28415C', '#12161D'],
      kind: 'dj',
      targetId: 'dj-1',
    },
    {
      id: 'rank-dj-2',
      title: 'KARIN',
      subtitle: '上海 · Techno / Warehouse',
      score: '8.9',
      delta: '+3',
      palette: ['#4A274A', '#151118'],
      kind: 'dj',
      targetId: 'dj-2',
    },
    {
      id: 'rank-dj-3',
      title: 'MATSU',
      subtitle: 'Tokyo · House / Disco',
      score: '8.7',
      delta: 'NEW',
      palette: ['#24505B', '#12181C'],
      kind: 'dj',
      targetId: 'dj-3',
    },
  ],
  organizers: [
    {
      id: 'rank-org-1',
      title: 'Storm Festival',
      subtitle: '上海 · 中国 · 年度',
      score: '9.2',
      delta: '+2',
      palette: ['#3A2A3C', '#131116'],
      kind: 'organizer',
      targetId: 'organizer-3',
    },
    {
      id: 'rank-org-2',
      title: 'Tomorrowland',
      subtitle: 'Boom · 比利时 · 年度',
      score: '9.1',
      delta: '-1',
      palette: ['#273244', '#0E1118'],
      kind: 'organizer',
      targetId: 'organizer-1',
    },
    {
      id: 'rank-org-3',
      title: 'Ultra Music Festival',
      subtitle: 'Miami · 美国 · 年度',
      score: '8.8',
      delta: '+1',
      palette: ['#2B364A', '#10131A'],
      kind: 'organizer',
      targetId: 'organizer-2',
    },
  ],
};

const SETS_FEED: SetListItem[] = [
  {
    id: 'set-1',
    title: 'Live at Berlin Warehouse 2025',
    djId: 'dj-1',
    djName: 'NORA',
    eventId: 'event-2',
    eventTitle: 'Afterglow City Session with NORA',
    duration: '01:24:18',
    bpm: '126 BPM',
    style: 'Melodic Techno',
    palette: ['#28415C', '#12161D'],
  },
  {
    id: 'set-2',
    title: 'Warehouse Motion Opening Set',
    djId: 'dj-2',
    djName: 'KARIN',
    eventId: 'event-4',
    eventTitle: 'Warehouse Motion All Night Long',
    duration: '00:58:42',
    bpm: '132 BPM',
    style: 'Warehouse Techno',
    palette: ['#4A274A', '#151118'],
  },
  {
    id: 'set-3',
    title: 'Sunrise House in Tokyo Bay',
    djId: 'dj-3',
    djName: 'MATSU',
    eventId: 'event-3',
    eventTitle: 'Sunset Frequency Open Air',
    duration: '01:11:05',
    bpm: '122 BPM',
    style: 'House / Disco',
    palette: ['#24505B', '#12181C'],
  },
];

const GENRE_SPOTLIGHTS: GenreSpotlight[] = [
  {
    id: 'genre-1',
    name: 'Melodic Techno',
    description: '更强调长线 build-up、情绪推进和大场景沉浸感，近两年在大型 warehouse 和 festival 里都很强势。',
    energy: '高峰时段',
    scene: 'Warehouse / Main Stage',
    relatedDJId: 'dj-1',
    relatedDJName: 'NORA',
    relatedEventId: 'event-1',
    relatedEventTitle: 'Vision Wave 2026 Shanghai Opening',
    palette: ['#2B3E58', '#12161D'],
  },
  {
    id: 'genre-2',
    name: 'Warehouse Techno',
    description: '更强调低频、工业感和长时间推进，适合大体量夜场和凌晨时段的连续听感。',
    energy: '凌晨段',
    scene: 'Warehouse',
    relatedDJId: 'dj-2',
    relatedDJName: 'KARIN',
    relatedEventId: 'event-4',
    relatedEventTitle: 'Warehouse Motion All Night Long',
    palette: ['#4A274A', '#151118'],
  },
  {
    id: 'genre-3',
    name: 'House / Disco',
    description: '节奏更轻，groove 更友好，适合 open air 的 golden hour 和 sunrise 时段。',
    energy: '日落 / Sunrise',
    scene: 'Open Air / Beach',
    relatedDJId: 'dj-3',
    relatedDJName: 'MATSU',
    relatedEventId: 'event-3',
    relatedEventTitle: 'Sunset Frequency Open Air',
    palette: ['#24505B', '#12181C'],
  },
];

const EVENT_DETAILS: EventDetailData[] = [
  {
    id: 'event-1',
    title: 'Vision Wave 2026 Shanghai Opening',
    subtitle: 'Main Stage Warehouse',
    location: '上海 · Main Stage Warehouse · 虹口',
    schedule: '2026.06.21 周六 23:00 - 06.22 周日 06:00',
    organizerName: 'Storm Festival',
    organizerId: 'organizer-3',
    description:
      'Vision Wave 以长时间段 warehouse 场景为核心，聚焦更完整的灯光节奏、舞台氛围与凌晨时段的情绪推进。',
    heroPalette: ['#214E57', '#111722', '#08090C'],
    lineup: [DJ_LIBRARY[0], DJ_LIBRARY[1], DJ_LIBRARY[2]],
    scheduleSlots: [
      { time: '23:00', stage: 'Main', artistId: 'dj-2', artistName: 'KARIN' },
      { time: '01:00', stage: 'Main', artistId: 'dj-1', artistName: 'NORA' },
      { time: '03:00', stage: 'Garden', artistId: 'dj-3', artistName: 'MATSU' },
    ],
    news: NEWS_FEED.slice(0, 2),
    posts: ['现场灯光排练已经完成，主舞台 01:00 后进入整段连续视觉。', '今天 22:30 开始检票，入场后请从东侧通道分流。'],
    ratings: ['音响期待值 9.2', '场地体验预测 8.8', '阵容新鲜度 8.6'],
    sets: ['Warehouse Motion Opening Set', 'Live at Berlin Warehouse 2025', 'Sunrise House in Tokyo Bay'],
  },
  {
    id: 'event-2',
    title: 'Afterglow City Session with NORA',
    subtitle: 'Riverfront Hall',
    location: '成都 · Riverfront Hall',
    schedule: '2026.06.28 周六 22:30 - 06.29 周日 05:00',
    organizerName: 'Ultra Music Festival',
    organizerId: 'organizer-2',
    description:
      'Afterglow 偏向更紧凑的城市夜场节奏，舞台切换更快，重心落在主嘉宾与 support 之间的衔接。',
    heroPalette: ['#402657', '#13121B', '#09090C'],
    lineup: [DJ_LIBRARY[0], DJ_LIBRARY[2]],
    scheduleSlots: [
      { time: '22:30', stage: 'Room A', artistId: 'dj-3', artistName: 'MATSU' },
      { time: '00:30', stage: 'Room A', artistId: 'dj-1', artistName: 'NORA' },
    ],
    news: NEWS_FEED.slice(1, 3),
    posts: ['今晚开场前会先放出完整时间表。'],
    ratings: ['票价友好度 8.4', '主理人口碑 8.7'],
    sets: ['Sunrise House in Tokyo Bay', 'Live at Berlin Warehouse 2025'],
  },
  {
    id: 'event-3',
    title: 'Sunset Frequency Open Air',
    subtitle: 'Coastline Park',
    location: '深圳 · Coastline Park · 南山',
    schedule: '2026.07.05 周日 18:30 - 23:30',
    organizerName: 'Tomorrowland',
    organizerId: 'organizer-1',
    description:
      'Sunset Frequency 把 open air 的日落时段拉得更长，整体视觉和编排更轻，但会在黄金时段把情绪推到最高。',
    heroPalette: ['#15506A', '#101B24', '#07090C'],
    lineup: [DJ_LIBRARY[2], DJ_LIBRARY[0]],
    scheduleSlots: [
      { time: '18:30', stage: 'Beach', artistId: 'dj-3', artistName: 'MATSU' },
      { time: '20:15', stage: 'Beach', artistId: 'dj-1', artistName: 'NORA' },
    ],
    news: NEWS_FEED.slice(0, 1),
    posts: ['日落前半段会先以更松弛的 house/disco 氛围起场。'],
    ratings: ['景观氛围 9.1', '松弛感 8.8', '日落时段期待值 9.0'],
    sets: ['Sunrise House in Tokyo Bay', 'Live at Berlin Warehouse 2025'],
  },
  {
    id: 'event-4',
    title: 'Warehouse Motion All Night Long',
    subtitle: 'Unit 09 Warehouse',
    location: '北京 · Unit 09 Warehouse · 朝阳',
    schedule: '2026.07.12 周六 23:59 - 07.13 周日 08:00',
    organizerName: 'EDC Las Vegas',
    organizerId: 'organizer-4',
    description:
      'Warehouse Motion 用更密的时段编排和工业风视觉做整夜推进，适合长时间沉浸式听感与连段节奏。',
    heroPalette: ['#4C263B', '#17121A', '#08080B'],
    lineup: [DJ_LIBRARY[1], DJ_LIBRARY[0]],
    scheduleSlots: [
      { time: '23:59', stage: 'Room 01', artistId: 'dj-2', artistName: 'KARIN' },
      { time: '02:00', stage: 'Room 01', artistId: 'dj-1', artistName: 'NORA' },
    ],
    news: NEWS_FEED.slice(2, 4),
    posts: ['仓库区域已经完成第二轮声场测试。', '清晨段的视觉将切换到更克制的冷色系。'],
    ratings: ['工业氛围 9.0', '夜场密度 8.9', '凌晨推进 8.8'],
    sets: ['Warehouse Motion Opening Set', 'Live at Berlin Warehouse 2025'],
  },
];

const DJ_DETAILS: DJDetailData[] = [
  {
    id: 'dj-1',
    name: 'NORA',
    subtitle: 'Berlin · Melodic Techno / Progressive House',
    country: '德国',
    city: 'Berlin',
    genres: ['Melodic Techno', 'Progressive House'],
    bio: 'NORA 以大段渐进式 build-up 和凌晨时段的情绪控制见长，近年在欧洲与亚洲的 warehouse 场景都很活跃。',
    heroPalette: ['#243F58', '#10151E', '#08090C'],
    honors: ['2025 RA Top Picks', '2024 Warehouse Circuit Highlight'],
    upcomingEvents: ['Vision Wave 2026 Shanghai Opening', 'Afterglow City Session with NORA'],
    ratings: ['控场能力 9.3', '选曲完成度 9.0', '过渡流畅度 9.1'],
    posts: ['NORA 刚公布了亚洲夏季巡演第二阶段时间。'],
    sets: ['Live at Berlin Warehouse 2025'],
  },
  {
    id: 'dj-2',
    name: 'KARIN',
    subtitle: '上海 · Techno / Warehouse',
    country: '中国',
    city: '上海',
    genres: ['Techno', 'Warehouse'],
    bio: 'KARIN 的 set 更强调低频推进和工业感结构，擅长为大体量 warehouse 夜场做开场与过渡。',
    heroPalette: ['#4B264A', '#141118', '#08080B'],
    honors: ['2025 East Asia Rising Selector'],
    upcomingEvents: ['Vision Wave 2026 Shanghai Opening'],
    ratings: ['开场节奏 8.8', '低频掌控 8.9'],
    posts: ['KARIN 在社区分享了自己的最新巡演硬件配置。'],
    sets: ['Warehouse Motion Opening Set'],
  },
  {
    id: 'dj-3',
    name: 'MATSU',
    subtitle: 'Tokyo · House / Disco',
    country: '日本',
    city: 'Tokyo',
    genres: ['House', 'Disco'],
    bio: 'MATSU 的清晨时段 set 以轻盈 groove 和复古 house/disco 片段见长，是很强的 sunrise 角色。',
    heroPalette: ['#22505B', '#10161C', '#08090C'],
    honors: ['2024 Tokyo Sunrise Favorite'],
    upcomingEvents: ['Sunset Frequency Open Air', 'Afterglow City Session with NORA'],
    ratings: ['清晨情绪控制 9.0', '旋律友好度 8.7'],
    posts: ['MATSU 更新了本周东京 club residency 的嘉宾名单。'],
    sets: ['Sunrise House in Tokyo Bay'],
  },
];

const ORGANIZER_DETAILS: OrganizerDetailData[] = [
  {
    id: 'organizer-1',
    name: 'Tomorrowland',
    subtitle: 'Boom · 比利时 · 2005 · 年度',
    country: '比利时',
    city: 'Boom',
    foundedYear: '2005',
    frequency: '年度',
    intro: 'Tomorrowland 是全球最成熟的大型电子音乐节品牌之一，擅长大体量叙事和超高密度视觉系统。',
    heroPalette: ['#2A3344', '#11141C', '#08090C'],
    events: ['Tomorrowland Belgium 2026', 'Tomorrowland Winter 2026'],
    posts: ['Tomorrowland 公布了新一轮舞台概念草图。'],
  },
  {
    id: 'organizer-2',
    name: 'Ultra Music Festival',
    subtitle: 'Miami · 美国 · 1999 · 年度',
    country: '美国',
    city: 'Miami',
    foundedYear: '1999',
    frequency: '年度',
    intro: 'Ultra 在城市中心大场景的组织经验非常成熟，活动调性更偏“巨量人群 + 强 headliner 聚焦”。',
    heroPalette: ['#28374B', '#10141B', '#08090C'],
    events: ['Ultra Miami 2026', 'Road to Ultra Asia 2026'],
    posts: ['Ultra 刚更新了 2026 年度城市合作计划。'],
  },
  {
    id: 'organizer-3',
    name: 'Storm Festival',
    subtitle: '上海 · 中国 · 2013 · 年度',
    country: '中国',
    city: '上海',
    foundedYear: '2013',
    frequency: '年度',
    intro: 'Storm Festival 是国内电子音乐场景里最重要的品牌之一，近几年在仓库与沉浸式空间的结合上更激进。',
    heroPalette: ['#3A2A3C', '#131116', '#08080C'],
    events: ['Vision Wave 2026 Shanghai Opening', 'Storm Festival Main Season 2026'],
    posts: ['Storm 团队最近在社区公开了新场地测试片段。'],
  },
  {
    id: 'organizer-4',
    name: 'EDC Las Vegas',
    subtitle: 'Las Vegas · 美国 · 1997 · 年度',
    country: '美国',
    city: 'Las Vegas',
    foundedYear: '1997',
    frequency: '年度',
    intro: 'EDC 的核心优势在于超大规模场景叙事、夜间灯光系统和极强的节庆氛围管理。',
    heroPalette: ['#24394C', '#10141B', '#08090C'],
    events: ['Warehouse Motion All Night Long', 'EDC Las Vegas 2026'],
    posts: ['EDC 公开了本季夜间主舞台灯光升级预告。'],
  },
];

const NEWS_DETAILS: NewsDetailData[] = [
  {
    id: 'news-1',
    category: 'festival',
    source: 'Raver 编辑部',
    title: '2026 夏季电音节排期更新，长三角仓库场地热度持续升高',
    summary: '从上海到苏州的新场地释放速度明显加快，主办方正在把更多预算投入夜间沉浸式视觉与音响升级。',
    publishedAt: '2026.06.03 20:14',
    heroPalette: ['#30261F', '#171412', '#08080B'],
    body: [
      '今年夏季的排期更新里，一个最明显的趋势是长三角仓库类场地的密度继续上升，尤其是上海、苏州和杭州之间形成了更稳定的夜场联动。',
      '和去年相比，主办方在预算分配上更愿意把资源投向视觉系统、声场优化和凌晨段动线，而不是单纯堆高 headline 阵容。',
      '用户讨论里最常提到的关键词也在变化，从“阵容够不够大”逐渐转向“场地体验是否完整”“离场是否顺畅”“凌晨段的情绪推进是否成立”。',
    ],
    relatedEvents: [
      'Vision Wave 2026 Shanghai Opening',
      'Warehouse Motion All Night Long',
    ],
    discussion: [
      '仓库场地热度上涨会不会带来票价继续抬升？',
      '视觉与音响升级，是否真的比更多 headline 更有吸引力？',
      '凌晨段的体验会不会成为今年活动页里的核心卖点？',
    ],
  },
  {
    id: 'news-2',
    category: 'scene',
    source: '现场观察',
    title: '我们在成都看了一晚上的开场编排，舞台转场终于不再拖沓',
    summary: '几位本地 promoter 开始用更轻的结构去连接 headliner 和 support，观众留存时间比去年更长。',
    publishedAt: '2026.06.02 18:40',
    heroPalette: ['#1F2A36', '#12161C', '#08090C'],
    body: [
      '成都最近几场活动的一个积极变化，是开场与主嘉宾之间的衔接更顺了，不再为了“赶紧进高潮”而牺牲前半段的层次感。',
      '这种调整最直接的结果，是观众对 support 的停留时间明显变长，也让后面几次转场不再那么突兀。',
      '如果这套排布继续成熟，未来本地 club night 的整体完成度会比过去好很多。',
    ],
    relatedEvents: ['Afterglow City Session with NORA'],
    discussion: [
      'support 和 headliner 的关系应该更偏“衔接”还是“对比”？',
      '开场太快进入高潮，是否反而会损伤后半夜体验？',
    ],
  },
  {
    id: 'news-3',
    category: 'gear',
    source: '设备研究所',
    title: '中型 club 正在回流模拟机架，VJ 与灯控的联动方式也跟着变了',
    summary: '本轮升级更强调“低延迟”和“少切换”，后台工作流明显向巡演级配置靠拢。',
    publishedAt: '2026.06.01 16:08',
    heroPalette: ['#1D3124', '#121815', '#08090B'],
    body: [
      '一些中型 club 开始重新评估模拟链路和低延迟机架的价值，尤其是在灯控与 VJ 联动较复杂的夜场里，这种变化很明显。',
      '相比过去依赖大量切换和补丁式配置，现在的目标更像是“稳定、少跳变、可长时间运行”。',
      '这会直接影响现场观感，尤其是凌晨段连续听感和视觉推进的完整性。',
    ],
    relatedEvents: ['Warehouse Motion All Night Long'],
    discussion: [
      '低延迟和稳定性，是否比更多炫技效果更重要？',
      'club 级工作流和巡演级工作流之间的差距正在缩小吗？',
    ],
  },
  {
    id: 'news-4',
    category: 'community',
    source: '社区热议',
    title: '你最在意活动页里的什么信息？票务、lineup、还是场地图例',
    summary: '最近很多用户开始把“交通离场体验”和“二次入场规则”放到决策前列，讨论度意外地高。',
    publishedAt: '2026.05.31 22:21',
    heroPalette: ['#2B2336', '#15131A', '#08080C'],
    body: [
      '在最近的社区讨论里，用户最关心的活动页信息并不只是阵容和票价，反而是更具体的体验信息，比如离场路线、检票分流和二次入场规则。',
      '这说明活动页正在从“只负责卖票”的页面，慢慢变成“帮助用户做完整决策”的页面。',
      '如果这些信息能被结构化地放进页面里，活动详情本身的完成度也会更高。',
    ],
    relatedEvents: [
      'Vision Wave 2026 Shanghai Opening',
      'Sunset Frequency Open Air',
    ],
    discussion: [
      '活动详情里是不是该把离场和交通信息提前到更靠前的位置？',
      '你更愿意看到长文介绍，还是清晰的规则卡片？',
    ],
  },
];

const LABEL_DETAILS: LabelDetailData[] = [
  {
    id: 'label-1',
    name: 'Afterlife',
    subtitle: 'Milan · 意大利 · 2016',
    country: '意大利',
    city: 'Milan',
    foundedYear: '2016',
    focus: 'Melodic Techno / Immersive',
    intro: 'Afterlife 以沉浸式视觉、大场景叙事和 melodic techno 的长线 build-up 著称，是近年最有辨识度的厂牌之一。',
    heroPalette: ['#2F3850', '#12151C', '#08090C'],
    featuredDJs: ['NORA'],
    releases: ['Realm Shift EP', 'Warehouse Echoes VA', 'Afterlight Session 02'],
    posts: ['Afterlife 刚更新了夏季沉浸式舞台概念预告。'],
  },
  {
    id: 'label-2',
    name: 'Drumcode',
    subtitle: 'Stockholm · 瑞典 · 1996',
    country: '瑞典',
    city: 'Stockholm',
    foundedYear: '1996',
    focus: 'Techno / Warehouse',
    intro: 'Drumcode 是现代 techno 与 warehouse 场景中最稳定的厂牌标识之一，强调低频推进和工业感质地。',
    heroPalette: ['#3F2B3A', '#161117', '#08080B'],
    featuredDJs: ['KARIN'],
    releases: ['Pressure Curve LP', 'Night Conveyor EP', 'Drumcode Tools Vol. 8'],
    posts: ['Drumcode 发布了新一轮夏季巡演精选曲包。'],
  },
  {
    id: 'label-3',
    name: 'Anjunadeep',
    subtitle: 'London · 英国 · 2005',
    country: '英国',
    city: 'London',
    foundedYear: '2005',
    focus: 'Deep House / Progressive',
    intro: 'Anjunadeep 更强调空间感、旋律性和长线 progressive 叙事，适合 open air、sunset 和长时段旅行场景。',
    heroPalette: ['#21485A', '#10161C', '#08090C'],
    featuredDJs: ['MATSU'],
    releases: ['Golden Hours EP', 'Open Sky Sessions', 'Deep Route Notes'],
    posts: ['Anjunadeep 更新了年度 open air 系列计划。'],
  },
  {
    id: 'label-4',
    name: 'Ninja Tune',
    subtitle: 'London · 英国 · 1990',
    country: '英国',
    city: 'London',
    foundedYear: '1990',
    focus: 'Electronic / Leftfield',
    intro: 'Ninja Tune 的横向覆盖更广，从电子到 leftfield 实验都能容纳，是极有文化标识的老牌独立厂牌。',
    heroPalette: ['#4C3424', '#17130F', '#08090C'],
    featuredDJs: ['MATSU'],
    releases: ['Night Transit Cuts', 'Leftfield Warehouse Notes', 'Coastal Motion'],
    posts: ['Ninja Tune 释出了一期关于 live workflow 的幕后短片。'],
  },
];

const SET_DETAILS: SetDetailData[] = [
  {
    id: 'set-1',
    title: 'Live at Berlin Warehouse 2025',
    subtitle: 'NORA · Melodic Techno',
    djId: 'dj-1',
    djName: 'NORA',
    eventId: 'event-2',
    eventTitle: 'Afterglow City Session with NORA',
    duration: '01:24:18',
    bpm: '126 BPM',
    style: 'Melodic Techno',
    description: '这套 set 的前半段留了更长的 build-up，后半程则把情绪推向更完整的 warehouse peak hour 结构。',
    heroPalette: ['#28415C', '#12161D', '#08090C'],
    trackHighlights: ['00:18 进入第一次抬升', '00:42 切入主旋律层', '01:07 完成 peak hour 收束'],
    notes: ['适合凌晨后半程', '适合 warehouse 主舞台', '偏长线 build-up'],
  },
  {
    id: 'set-2',
    title: 'Warehouse Motion Opening Set',
    subtitle: 'KARIN · Warehouse Techno',
    djId: 'dj-2',
    djName: 'KARIN',
    eventId: 'event-4',
    eventTitle: 'Warehouse Motion All Night Long',
    duration: '00:58:42',
    bpm: '132 BPM',
    style: 'Warehouse Techno',
    description: '更强调低频和工业质感，是很典型的 warehouse 开场 set，重点在建立夜场温度而不是立刻堆高潮。',
    heroPalette: ['#4A274A', '#151118', '#08080B'],
    trackHighlights: ['00:08 建立低频基底', '00:29 连续鼓组推进', '00:51 留白后重新提速'],
    notes: ['适合开场', '低频偏重', '工业感明显'],
  },
  {
    id: 'set-3',
    title: 'Sunrise House in Tokyo Bay',
    subtitle: 'MATSU · House / Disco',
    djId: 'dj-3',
    djName: 'MATSU',
    eventId: 'event-3',
    eventTitle: 'Sunset Frequency Open Air',
    duration: '01:11:05',
    bpm: '122 BPM',
    style: 'House / Disco',
    description: '更适合 sunrise 和 open air 的轻盈 groove，前段轻松，后段则慢慢把旋律和热度抬上来。',
    heroPalette: ['#24505B', '#12181C', '#08090C'],
    trackHighlights: ['00:12 引入 disco break', '00:36 增加 vocal layer', '00:58 日出段完成情绪抬升'],
    notes: ['适合 sunrise', 'groove 轻盈', 'open air 友好'],
  },
];

const GENRE_DETAILS: GenreDetailData[] = [
  {
    id: 'genre-1',
    name: 'Melodic Techno',
    subtitle: 'Warehouse / Main Stage',
    description: 'Melodic Techno 更强调旋律性、层层推进的 build-up 和大场景沉浸感，适合大型仓库和主舞台的高潮时段。',
    energy: '高峰时段',
    scene: 'Warehouse / Main Stage',
    heroPalette: ['#2B3E58', '#12161D', '#08090C'],
    relatedDJs: ['NORA'],
    relatedEvents: ['Vision Wave 2026 Shanghai Opening'],
    listeningNotes: ['更适合长线 build-up', '旋律与空间感优先', '适合大体量舞台'],
  },
  {
    id: 'genre-2',
    name: 'Warehouse Techno',
    subtitle: 'Warehouse',
    description: 'Warehouse Techno 的核心是低频、工业感和长时间推进，更适合封闭空间和凌晨段的连续听感。',
    energy: '凌晨段',
    scene: 'Warehouse',
    heroPalette: ['#4A274A', '#151118', '#08080B'],
    relatedDJs: ['KARIN'],
    relatedEvents: ['Warehouse Motion All Night Long'],
    listeningNotes: ['更适合封闭仓库', '低频占比更高', '工业氛围更浓'],
  },
  {
    id: 'genre-3',
    name: 'House / Disco',
    subtitle: 'Open Air / Beach',
    description: 'House / Disco 更重视 groove 和轻盈感，适合日落、sunrise 和 open air 的长时段陪伴。',
    energy: '日落 / Sunrise',
    scene: 'Open Air / Beach',
    heroPalette: ['#24505B', '#12181C', '#08090C'],
    relatedDJs: ['MATSU'],
    relatedEvents: ['Sunset Frequency Open Air'],
    listeningNotes: ['更松弛', 'groove 更友好', '适合户外与海边场景'],
  },
];

const EVENT_DETAIL_ADDONS: Record<string, EventDetailAddon> = {
  'event-1': {
    doorTime: '22:30 开始检票',
    travelWindow: '建议 22:10 - 22:40 到场',
    audienceProfile: '偏 warehouse 核心乐迷与凌晨段长线停留人群',
    vibeTags: ['长线 build-up', '主舞台沉浸', '凌晨 peak hour'],
    labelSpotlights: ['Afterlife', 'Drumcode'],
    venueTips: [
      '东侧通道为主检票口，西侧通道只开放出场分流。',
      '主舞台 01:00 后进入连续视觉段，中途不建议频繁走动。',
      '仓库内温差明显，凌晨后半段体感会下降。',
    ],
    ticketTips: [
      '电子票需提前绑定实名信息。',
      '二次入场仅限凌晨 03:00 前，离场后需走专门通道。',
      '寄存区与周边吧台分开排队，建议入场后先完成寄存。',
    ],
  },
  'event-2': {
    doorTime: '22:00 开始检票',
    travelWindow: '建议 21:45 - 22:20 到场',
    audienceProfile: '偏城市夜场用户，首进场与复购人群占比高',
    vibeTags: ['城市夜场', '转场顺滑', 'headliner 聚焦'],
    labelSpotlights: ['Afterlife', 'Anjunadeep'],
    venueTips: [
      'Room A 与酒水区之间动线短，开场时段会更拥挤。',
      '主嘉宾前一小时 support 会做更长衔接，不建议太晚到。',
      '离场网约车上车点在北侧路口，步行约 4 分钟。',
    ],
    ticketTips: [
      '预售票与现场票分通道检票。',
      '支持电子票转赠，但需在开场前 2 小时完成。',
      'VIP 区需二次核验手环。',
    ],
  },
  'event-3': {
    doorTime: '17:45 开始检票',
    travelWindow: '建议 17:30 - 18:10 到场',
    audienceProfile: 'open air 与 sunset 场景偏好用户，轻社交氛围更强',
    vibeTags: ['日落氛围', '海边 open air', '轻盈 groove'],
    labelSpotlights: ['Anjunadeep', 'Ninja Tune'],
    venueTips: [
      'Beach 区域无遮挡，建议提前准备轻薄外套。',
      '日落前后是拍摄高峰，主通道会短时拥堵。',
      '户外草地段不建议穿高跟鞋或较硬鞋底。',
    ],
    ticketTips: [
      '户外活动遇天气变化会同步在活动页推送。',
      '17:45 - 19:00 为快速检票时段。',
      '离场接驳车末班在 23:50。',
    ],
  },
  'event-4': {
    doorTime: '23:20 开始检票',
    travelWindow: '建议 23:10 - 23:45 到场',
    audienceProfile: '偏 techno 深度用户，长时段停留比例高',
    vibeTags: ['工业低频', 'all night long', '凌晨推进'],
    labelSpotlights: ['Drumcode'],
    venueTips: [
      '仓库内部信号较弱，建议提前保存票码与集合点。',
      'Room 01 声压更高，耳塞在入口处可领取。',
      '清晨离场将开放南门分流，减少主通道回堵。',
    ],
    ticketTips: [
      '23:59 后场内将停止现场售票。',
      '凌晨 04:00 前可二次入场一次。',
      '寄存区高峰集中在 00:00 - 00:40，建议错峰。',
    ],
  },
};

const DJ_DETAIL_ADDONS: Record<string, DJDetailAddon> = {
  'dj-1': {
    slotFocus: '凌晨 01:00 - 03:30 高峰段',
    route: 'Berlin / Amsterdam / Shanghai 夏季巡演线',
    pace: '前段拉开空间，后段持续抬升情绪',
    labels: ['Afterlife', 'Anjunadeep'],
    relatedNewsIDs: ['news-1', 'news-2'],
    styleNotes: ['旋律层铺陈细', '过渡长而稳', '高潮段更注重空间感'],
    listeningMoments: ['适合 warehouse 主舞台', '适合凌晨后半夜', '适合长线 build-up 场景'],
  },
  'dj-2': {
    slotFocus: '开场与 00:00 前后过渡段',
    route: 'Shanghai / Hangzhou / Beijing 仓库夜场线',
    pace: '低频先行，逐段堆叠工业张力',
    labels: ['Drumcode'],
    relatedNewsIDs: ['news-3'],
    styleNotes: ['kick 更重', '鼓组推进密度高', '情绪提速更克制'],
    listeningMoments: ['适合仓库开场', '适合长时段热身', '适合封闭空间'],
  },
  'dj-3': {
    slotFocus: '日落与 sunrise 时段',
    route: 'Tokyo / Osaka / Shenzhen 海边场景线',
    pace: '先给 groove，再慢慢抬旋律亮度',
    labels: ['Anjunadeep', 'Ninja Tune'],
    relatedNewsIDs: ['news-2', 'news-4'],
    styleNotes: ['轻盈 disco break', 'vocal layer 点到即止', '更偏松弛感'],
    listeningMoments: ['适合 open air', '适合海边日落', '适合清晨收尾'],
  },
};

const ORGANIZER_DETAIL_ADDONS: Record<string, OrganizerDetailAddon> = {
  'organizer-1': {
    signatureStyle: '超大场景叙事、密集视觉装置、节庆氛围编排完整',
    audienceProfile: '节庆型大场景用户，跨城市旅行用户比例高',
    coverageCities: ['Boom', 'Alpe d’Huez', 'Barcelona'],
    relatedNewsIDs: ['news-1'],
    focusLabels: ['Afterlife'],
    productionNotes: ['更强调世界观包装', '主舞台层次感极强', '现场服务链成熟'],
  },
  'organizer-2': {
    signatureStyle: '城市中心大场景、headline 集中、节奏直接',
    audienceProfile: '重 headliner 决策用户，短期出行观演用户占比高',
    coverageCities: ['Miami', 'Tokyo', 'Seoul'],
    relatedNewsIDs: ['news-2'],
    focusLabels: ['Afterlife', 'Anjunadeep'],
    productionNotes: ['主舞台转换效率高', '城市交通联动更重要', '票务与安检承压更大'],
  },
  'organizer-3': {
    signatureStyle: '国内仓库与沉浸式空间结合，视觉和声场都更激进',
    audienceProfile: '国内核心电子乐用户，本地复购与跨城用户兼有',
    coverageCities: ['上海', '苏州', '杭州'],
    relatedNewsIDs: ['news-1', 'news-4'],
    focusLabels: ['Drumcode'],
    productionNotes: ['更重凌晨段设计', '会优先优化场地体验', '本土场景联动更紧密'],
  },
  'organizer-4': {
    signatureStyle: '超大夜场氛围、灯光系统密度高、体验线条清晰',
    audienceProfile: '重节庆体验与大型舞台用户，观光型用户占比也高',
    coverageCities: ['Las Vegas', 'Orlando', 'Mexico City'],
    relatedNewsIDs: ['news-3'],
    focusLabels: ['Drumcode'],
    productionNotes: ['场内分区极细', '主舞台压迫感强', '后勤与引导体系成熟'],
  },
};

const NEWS_DETAIL_ADDONS: Record<string, NewsDetailAddon> = {
  'news-1': {
    keyTakeaways: ['仓库场地供给持续增加', '预算向视觉与音响体验倾斜', '用户更关注整体动线与凌晨体验'],
    involvedScenes: ['上海仓库场景', '苏州新场地', '杭州周边夜场'],
    editorNotes: ['这是活动详情结构应该继续前移的信息层。', '“体验信息”已经开始和 lineup 一样影响转化。'],
  },
  'news-2': {
    keyTakeaways: ['开场与主嘉宾衔接变顺', 'support 停留时间拉长', '整体完成度比单纯堆高潮更重要'],
    involvedScenes: ['成都 club night', '本地主办方编排'],
    editorNotes: ['这类内容很适合在活动详情里做“编排亮点”模块。', '观众对节奏结构的感知越来越成熟。'],
  },
  'news-3': {
    keyTakeaways: ['中型 club 开始重视低延迟', '机架与灯控联动回归稳定优先', '凌晨连续体验会更完整'],
    involvedScenes: ['中型 club 升级', 'VJ / 灯控联动'],
    editorNotes: ['设备升级对用户最直接的感受，其实是“没那么断裂”。', '技术工作流正在更像巡演级系统。'],
  },
  'news-4': {
    keyTakeaways: ['离场与交通成为高频决策项', '规则卡片比长文更适合快速扫读', '活动页承担更多决策辅助功能'],
    involvedScenes: ['活动详情设计', '社区决策讨论'],
    editorNotes: ['这一类讨论会直接反推产品信息架构。', '规则、动线、时间点应该更结构化地提前展示。'],
  },
};

const LABEL_DETAIL_ADDONS: Record<string, LabelDetailAddon> = {
  'label-1': {
    signatureKeywords: ['沉浸式视觉', '长线 build-up', '大场景 melodic'],
    keyCities: ['Milan', 'Ibiza', 'Tulum'],
    relatedNewsIDs: ['news-1'],
    relatedSets: ['Live at Berlin Warehouse 2025'],
    curationNotes: ['发行之间的视觉语言统一度高', '适合主舞台长时段叙事', '更强调沉浸感而不是密度轰炸'],
  },
  'label-2': {
    signatureKeywords: ['工业低频', 'warehouse techno', '大鼓组推进'],
    keyCities: ['Stockholm', 'Amsterdam', 'Berlin'],
    relatedNewsIDs: ['news-3'],
    relatedSets: ['Warehouse Motion Opening Set'],
    curationNotes: ['更强调可用性和场景效率', '开场与 peak hour 之间衔接明确', '仓库听感辨识度强'],
  },
  'label-3': {
    signatureKeywords: ['progressive', '深空间感', 'sunset 场景'],
    keyCities: ['London', 'Lisbon', 'Bali'],
    relatedNewsIDs: ['news-2'],
    relatedSets: ['Sunrise House in Tokyo Bay', 'Live at Berlin Warehouse 2025'],
    curationNotes: ['适合 open air 与旅途感场景', '更重旋律耐听度', '曲线更平滑'],
  },
  'label-4': {
    signatureKeywords: ['leftfield', '文化标识', '实验电子'],
    keyCities: ['London', 'Bristol', 'Tokyo'],
    relatedNewsIDs: ['news-4'],
    relatedSets: ['Sunrise House in Tokyo Bay'],
    curationNotes: ['风格覆盖面广但调性始终鲜明', '适合深挖厂牌文化路径', 'live workflow 内容丰富'],
  },
};

const SET_DETAIL_ADDONS: Record<string, SetDetailAddon> = {
  'set-1': {
    recordingSource: 'Berlin Warehouse 现场回录',
    structureSummary: '前 20 分钟蓄力，中段拉满旋律层，尾段完成高峰收束。',
    relatedNewsIDs: ['news-1', 'news-2'],
    relatedLabels: ['Afterlife', 'Anjunadeep'],
    idealScenes: ['warehouse 主舞台', '凌晨后半段', '长线 build-up 需求'],
    chapterNotes: ['开头留白较多，适合热身后承接。', '中段旋律层会明显推高现场亮度。'],
  },
  'set-2': {
    recordingSource: 'Warehouse Motion 彩排后现场版本',
    structureSummary: '先稳住低频地基，再通过连续鼓组与留白切换建立张力。',
    relatedNewsIDs: ['news-3'],
    relatedLabels: ['Drumcode'],
    idealScenes: ['仓库开场', '工业风夜场', '长时段热身'],
    chapterNotes: ['不急着堆高潮，但很会立住空间温度。', '适合给后续 headliner 留更宽的接力面。'],
  },
  'set-3': {
    recordingSource: 'Tokyo Bay sunrise 户外录音',
    structureSummary: 'groove 更轻，vocal 与 disco break 会在后段逐步拉亮气氛。',
    relatedNewsIDs: ['news-2', 'news-4'],
    relatedLabels: ['Anjunadeep', 'Ninja Tune'],
    idealScenes: ['海边日落', 'sunrise 收尾', 'open air 松弛段'],
    chapterNotes: ['适合一边走动一边听。', '后段情绪抬升不突兀，很适合户外空间。'],
  },
};

const GENRE_DETAIL_ADDONS: Record<string, GenreDetailAddon> = {
  'genre-1': {
    tempoRange: '124 - 128 BPM',
    commonSlots: ['主舞台高峰段', '凌晨 01:00 后'],
    moodKeywords: ['沉浸', '拉升', '空间感'],
    entrySets: ['Live at Berlin Warehouse 2025'],
    relatedLabels: ['Afterlife', 'Anjunadeep'],
  },
  'genre-2': {
    tempoRange: '130 - 136 BPM',
    commonSlots: ['仓库开场后半段', '凌晨 02:00 - 05:00'],
    moodKeywords: ['工业', '低频', '压迫感'],
    entrySets: ['Warehouse Motion Opening Set'],
    relatedLabels: ['Drumcode'],
  },
  'genre-3': {
    tempoRange: '118 - 124 BPM',
    commonSlots: ['日落段', 'sunrise 段'],
    moodKeywords: ['groove', '松弛', '亮度'],
    entrySets: ['Sunrise House in Tokyo Bay'],
    relatedLabels: ['Anjunadeep', 'Ninja Tune'],
  },
};

const RANKING_BOARD_DETAILS: Record<RankingBoardKey, RankingBoardDetailData> = {
  events: {
    key: 'events',
    title: '活动热度榜',
    subtitle: '按近 14 天站内浏览、收藏、想去、讨论热度综合排序',
    summary: '这个榜单更像“最近哪一场活动真正抓住了大家的注意力”，它不是只看票卖得快，而是把浏览、收藏、评论和跨页联动一起算进去。',
    updatedAt: '2026.05.29 19:30',
    scope: '中国大陆重点城市 + 已建档海外头部活动',
    heroPalette: ['#244B57', '#11161E', '#08090C'],
    snapshot: ['近 14 天活跃活动 126 场', '新增入榜 4 场', '上海与北京仓库场景持续升温'],
    trends: ['用户更愿意收藏“凌晨体验完整”的活动。', '离场与交通规则写得清晰的活动页转化更高。'],
    dimensions: [
      { label: '浏览热度', weight: '30%', note: '活动页 UV 与停留时长' },
      { label: '收藏与想去', weight: '28%', note: '收藏、想去、提醒设置等主动信号' },
      { label: '讨论密度', weight: '22%', note: '评论、问答、社区转发' },
      { label: '详情完成度', weight: '20%', note: 'lineup、动线、规则等结构化信息是否齐全' },
    ],
    methodology: [
      '只纳入近 45 天内仍可报名、仍有讨论或仍可回看内容的活动。',
      '同一活动的站内不同入口会合并去重，避免重复计算热度。',
      '如果活动详情页存在关键信息缺失，会被拉低完成度权重。',
      '榜单每 30 分钟刷新一次，夜间高峰时段会提高评论信号权重。',
    ],
    entries: [
      { rank: 1, title: 'Vision Wave 2026 Shanghai Opening', subtitle: '上海 · Main Stage Warehouse', score: '9.4', delta: '+2', note: '详情页信息完整，凌晨段讨论密度最高。', palette: ['#244B57', '#0E121A'], kind: 'event', targetId: 'event-1' },
      { rank: 2, title: 'Sunset Frequency Open Air', subtitle: '深圳 · Coastline Park', score: '9.1', delta: '+1', note: '日落 open air 讨论增长明显，收藏率高。', palette: ['#17506A', '#101822'], kind: 'event', targetId: 'event-3' },
      { rank: 3, title: 'Warehouse Motion All Night Long', subtitle: '北京 · Unit 09 Warehouse', score: '8.9', delta: 'NEW', note: '工业风与 all night long 标签带来高转评比。', palette: ['#5B263B', '#18131A'], kind: 'event', targetId: 'event-4' },
      { rank: 4, title: 'Afterglow City Session with NORA', subtitle: '成都 · Riverfront Hall', score: '8.6', delta: '+1', note: '城市夜场转场话题推动了点击增长。', palette: ['#4B245A', '#15131D'], kind: 'event', targetId: 'event-2' },
    ],
  },
  djs: {
    key: 'djs',
    title: 'DJ 热度榜',
    subtitle: '按近 14 天主页访问、活动关联点击与 sets 播放热度综合排序',
    summary: '这个榜单更偏“谁现在真的被反复点开和听到”，尤其会放大活动详情页与 sets 页之间的联动效应。',
    updatedAt: '2026.05.29 19:30',
    scope: '站内已建档 DJ + 近 60 天有活动或 sets 更新的账号',
    heroPalette: ['#28415C', '#10151D', '#08090C'],
    snapshot: ['近 14 天被访问 DJ 214 位', '新入榜 7 位', 'sets 回看对排名影响继续提升'],
    trends: ['“活动详情 -> DJ 主页 -> Sets”成为最稳定的浏览链路。', '凌晨段控场型 DJ 的收藏增速高于快闪流量型 DJ。'],
    dimensions: [
      { label: '主页访问', weight: '32%', note: '站内 DJ 主页 UV 与停留时长' },
      { label: '活动关联点击', weight: '26%', note: '从活动详情点击 DJ 的转化' },
      { label: 'Sets 播放', weight: '24%', note: '相关 sets 的播放、收藏与回听' },
      { label: '社区提及', weight: '18%', note: '动态、评论与榜单讨论中的点名频次' },
    ],
    methodology: [
      '仅统计近 60 天有活动关联、sets 更新或社区讨论的 DJ。',
      '同一用户短时间连续访问会被折算，避免刷量。',
      '如果 DJ 缺少代表 sets 或活动资料，榜单会体现为后劲不足。',
      '跨页点击链路越完整，说明用户意图越强，权重也越高。',
    ],
    entries: [
      { rank: 1, title: 'NORA', subtitle: 'Berlin · Melodic Techno / Progressive House', score: '9.5', delta: '+1', note: '活动关联点击与 set 回听都很强，热度极稳。', palette: ['#28415C', '#12161D'], kind: 'dj', targetId: 'dj-1' },
      { rank: 2, title: 'KARIN', subtitle: '上海 · Techno / Warehouse', score: '8.9', delta: '+3', note: '仓库开场型内容带来了明显新增关注。', palette: ['#4A274A', '#151118'], kind: 'dj', targetId: 'dj-2' },
      { rank: 3, title: 'MATSU', subtitle: 'Tokyo · House / Disco', score: '8.7', delta: 'NEW', note: 'sunrise 场景和轻盈 groove 的标签很吃收藏。', palette: ['#24505B', '#12181C'], kind: 'dj', targetId: 'dj-3' },
    ],
  },
  organizers: {
    key: 'organizers',
    title: '主办方榜',
    subtitle: '按活动完成度、用户复购讨论与品牌热度综合排序',
    summary: '主办方榜更看“做出来的完整感”，不仅看名气，还看活动详情是否靠谱、用户会不会愿意再来第二次。',
    updatedAt: '2026.05.29 19:30',
    scope: '站内已建档主办方 + 近一年内至少有两场活动记录',
    heroPalette: ['#3A2A3C', '#131116', '#08080C'],
    snapshot: ['近一年活跃主办方 58 家', '复购讨论明显提升', '视觉与动线完成度成为新分水岭'],
    trends: ['活动页规则写得清楚的品牌，用户口碑更稳定。', '仓库类场景的主办方更容易因为体验细节拉开差距。'],
    dimensions: [
      { label: '活动完成度', weight: '34%', note: '活动页信息层是否齐、现场体验口碑是否稳定' },
      { label: '品牌热度', weight: '24%', note: '主办方主页访问、品牌名提及与收藏' },
      { label: '复购讨论', weight: '22%', note: '“下一场还想去吗”类讨论和正向反馈' },
      { label: '内容联动', weight: '20%', note: '资讯、DJ、Sets 等关联页是否形成闭环' },
    ],
    methodology: [
      '至少要求近一年有两场以上已建档活动，才能进入主办方榜。',
      '品牌热度不会完全覆盖活动完成度，避免只靠名气压榜。',
      '如果品牌的活动页长期缺乏交通、规则、时间表等信息，会影响分数。',
      '榜单每周会额外做一次人工校正，避免短时异常流量干扰。',
    ],
    entries: [
      { rank: 1, title: 'Storm Festival', subtitle: '上海 · 中国 · 年度', score: '9.2', delta: '+2', note: '国内仓库与沉浸式场景结合度高，讨论与复购意愿都强。', palette: ['#3A2A3C', '#131116'], kind: 'organizer', targetId: 'organizer-3' },
      { rank: 2, title: 'Tomorrowland', subtitle: 'Boom · 比利时 · 年度', score: '9.1', delta: '-1', note: '世界观与节庆完成度顶级，但近期站内更新频率稍低。', palette: ['#273244', '#0E1118'], kind: 'organizer', targetId: 'organizer-1' },
      { rank: 3, title: 'Ultra Music Festival', subtitle: 'Miami · 美国 · 年度', score: '8.8', delta: '+1', note: '城市大场景与 headline 聚焦仍然稳。', palette: ['#2B364A', '#10131A'], kind: 'organizer', targetId: 'organizer-2' },
      { rank: 4, title: 'EDC Las Vegas', subtitle: 'Las Vegas · 美国 · 年度', score: '8.5', delta: 'NEW', note: '夜间灯光系统和节庆氛围评价持续上升。', palette: ['#24394C', '#10141B'], kind: 'organizer', targetId: 'organizer-4' },
    ],
  },
};

const EVENT_DETAIL_TABS: Array<{ key: EventDetailTabKey; label: string; color: string }> = [
  { key: 'info', label: '信息', color: '#45D9D1' },
  { key: 'lineup', label: '阵容', color: '#4CA9F7' },
  { key: 'schedule', label: '时间表', color: '#8EC84D' },
  { key: 'news', label: 'News', color: '#F58433' },
  { key: 'posts', label: '动态', color: '#F14D61' },
  { key: 'ratings', label: '打分', color: '#F9B53B' },
  { key: 'sets', label: 'Sets', color: '#8E6DF2' },
];

const DJ_DETAIL_TABS: Array<{ key: DJDetailTabKey; label: string; color: string }> = [
  { key: 'intro', label: '简介', color: '#45D9D1' },
  { key: 'events', label: '活动', color: '#F9B53B' },
  { key: 'ratings', label: '打分', color: '#8E6DF2' },
  { key: 'posts', label: '动态', color: '#F14D61' },
  { key: 'sets', label: 'Sets', color: '#4CA9F7' },
];

const ORGANIZER_DETAIL_TABS: Array<{ key: OrganizerDetailTabKey; label: string; color: string }> = [
  { key: 'basic', label: '信息', color: '#45D9D1' },
  { key: 'events', label: '活动', color: '#F9B53B' },
  { key: 'posts', label: '动态', color: '#F14D61' },
];

const NEWS_DETAIL_TABS: Array<{ key: NewsDetailTabKey; label: string; color: string }> = [
  { key: 'article', label: '正文', color: '#45D9D1' },
  { key: 'events', label: '关联活动', color: '#F9B53B' },
  { key: 'discussion', label: '讨论点', color: '#B38CEE' },
];

const LABEL_DETAIL_TABS: Array<{ key: LabelDetailTabKey; label: string; color: string }> = [
  { key: 'basic', label: '信息', color: '#45D9D1' },
  { key: 'djs', label: 'DJ', color: '#76C955' },
  { key: 'releases', label: '发行', color: '#6D92F4' },
  { key: 'posts', label: '动态', color: '#F14D61' },
];

const SET_DETAIL_TABS: Array<{ key: SetDetailTabKey; label: string; color: string }> = [
  { key: 'basic', label: '信息', color: '#45D9D1' },
  { key: 'tracks', label: '亮点', color: '#F9B53B' },
  { key: 'event', label: '关联活动', color: '#4CA9F7' },
];

const GENRE_DETAIL_TABS: Array<{ key: GenreDetailTabKey; label: string; color: string }> = [
  { key: 'overview', label: '概览', color: '#45D9D1' },
  { key: 'djs', label: 'DJ', color: '#76C955' },
  { key: 'events', label: '活动', color: '#F9B53B' },
  { key: 'notes', label: '听感', color: '#38C8A7' },
];

const RANKING_BOARD_DETAIL_TABS: Array<{
  key: RankingBoardDetailTabKey;
  label: string;
  color: string;
}> = [
  { key: 'overview', label: '概览', color: '#45D9D1' },
  { key: 'top', label: 'Top', color: '#F9B53B' },
  { key: 'dimensions', label: '维度', color: '#BB79F3' },
  { key: 'method', label: '方法', color: '#4CA9F7' },
];

function mapRemoteEventToRecommendation(
  event: RemoteEvent,
  index: number,
): RecommendationCard {
  return {
    id: event.id,
    type: EVENT_TYPE_LABELS[event.eventType ?? ''] ?? 'Festival',
    status: EVENT_STATUS_LABELS[event.status ?? ''] ?? '即将开始',
    location:
      event.manualLocation?.formattedAddressI18n?.zh ??
      `${event.city ?? '未知城市'} · ${event.venueName ?? '待定场地'}`,
    date: formatDateLine(event.startDate, event.endDate),
    title: event.name.toUpperCase(),
    imageUrl:
      event.cardImageUrl ??
      event.coverImageUrl ??
      event.lineupImageUrl ??
      undefined,
    palette: remotePalette(index),
  };
}

function mapRemoteEventToListItem(event: RemoteEvent, index: number): EventListItem {
  const parts = formatMonthDay(event.startDate);

  return {
    id: event.id,
    name: event.name,
    eventTypeKey: event.eventType ?? 'festival',
    eventTypeLabel:
      EVENT_TYPE_LABELS[event.eventType ?? ''] ?? '电音节',
    status: EVENT_STATUS_LABELS[event.status ?? ''] ?? '即将开始',
    statusColor: EVENT_STATUS_COLORS[event.status ?? ''] ?? '#F58433',
    month: parts.month,
    day: parts.day,
    dateRange: formatDateLine(event.startDate, event.endDate),
    address:
      event.manualLocation?.formattedAddressI18n?.zh ??
      `${event.city ?? '未知城市'} · ${event.venueName ?? '待定场地'}`,
    palette: remoteCardPalette(index),
  };
}

function mapRemoteDJToSummary(dj: RemoteDJ, index: number): DJSummary {
  return {
    id: dj.id,
    name: dj.name,
    country: dj.countryI18n?.zh ?? formatCountryName(dj.country),
    city: dj.countryI18n?.enFull ?? dj.country ?? 'Unknown',
    genres: dj.genres?.slice(0, 3) ?? ['Electronic'],
    palette: remoteCardPalette(index),
    monogram: deriveMonogram(dj.name),
  };
}

function mapRemoteEventToDetail(
  event: RemoteEvent,
  index: number,
  lineup: DJSummary[],
  organizers: OrganizerItem[],
): EventDetailData {
  const normalizedOrganizerName = normalizeLookupKey(event.organizerName);
  const linkedOrganizer =
    organizers.find(item => {
      const organizerKey = normalizeLookupKey(item.name);
      return (
        organizerKey.length > 0 &&
        normalizedOrganizerName.length > 0 &&
        (organizerKey === normalizedOrganizerName ||
          organizerKey.includes(normalizedOrganizerName) ||
          normalizedOrganizerName.includes(organizerKey))
      );
    }) ?? organizers[0] ?? null;
  const slots =
    event.lineupSlots?.slice(0, 4).map(slot => ({
      time: slot.startTime.slice(11, 16),
      stage: slot.stageName ?? 'Main',
      artistId: slot.dj?.id ?? `${event.id}-${slot.djName}`,
      artistName: slot.dj?.name ?? slot.djName,
    })) ?? [];

  return {
    id: event.id,
    title: event.name,
    subtitle: event.venueName ?? event.city ?? 'Festival',
    location:
      event.manualLocation?.formattedAddressI18n?.zh ??
      `${event.city ?? '未知城市'} · ${event.venueName ?? '待定场地'}`,
    schedule: formatDateLine(event.startDate, event.endDate),
    organizerName:
      event.organizerName ?? linkedOrganizer?.name ?? 'RaverHub Official',
    organizerId: linkedOrganizer?.id ?? ORGANIZER_DETAILS[0]!.id,
    description:
      event.description ??
      `这场 ${EVENT_TYPE_LABELS[event.eventType ?? ''] ?? '电子音乐活动'} 已接入现有后端数据，当前先展示真实基础资料，后续继续补完整关联内容。`,
    heroPalette: remotePalette(index),
    lineup,
    scheduleSlots: slots,
    news: NEWS_FEED.slice(0, 2),
    posts: [`当前已接入真实活动数据：${event.name}`],
    ratings: [
      `阵容热度 ${Math.max(8.1, 9.4 - index * 0.2).toFixed(1)}`,
      `城市关注 ${Math.max(8.0, 9.1 - index * 0.2).toFixed(1)}`,
    ],
    sets: SET_DETAILS.slice(0, 2).map(item => item.title),
  };
}

function mapRecommendEventsToState(events: RemoteEvent[]) {
  const nextRecommendations = events
    .slice(0, 3)
    .map((item, index) => mapRemoteEventToRecommendation(item, index));
  const nextEventsFeed = events
    .slice(0, 4)
    .map((item, index) => mapRemoteEventToListItem(item, index));
  const nextEventDetails = events
    .slice(0, 4)
    .map((item, index) =>
      mapRemoteEventToDetail(item, index, DJ_LIBRARY.slice(0, 3), ORGANIZER_FEED),
    );

  return {
    nextRecommendations,
    nextEventsFeed,
    nextEventDetails,
  };
}

function mapRemoteDJToDetail(
  dj: RemoteDJ,
  index: number,
  upcomingEvents: string[],
): DJDetailData {
  return {
    id: dj.id,
    name: dj.name,
    subtitle: `${dj.countryI18n?.enFull ?? dj.country ?? 'Unknown'} · ${(dj.genres ?? ['Electronic']).slice(0, 2).join(' / ')}`,
    country: dj.countryI18n?.zh ?? formatCountryName(dj.country),
    city: dj.countryI18n?.enFull ?? dj.country ?? 'Unknown',
    genres: dj.genres?.slice(0, 4) ?? ['Electronic'],
    bio:
      dj.bio ??
      `${dj.name} 的真实资料已经接入后端，当前先展示已同步到资料库的艺人简介与排行信息。`,
    heroPalette: remotePalette(index),
    honors:
      dj.honors?.slice(0, 3).map(item =>
        `${item.year ?? ''} ${item.title ?? 'Ranking'} #${item.rank ?? '-'}`.trim(),
      ) ?? ['Raver Discover Synced'],
    upcomingEvents,
    ratings: [
      `关注度 ${Math.max(8.2, 9.5 - index * 0.2).toFixed(1)}`,
      `巡演热度 ${Math.max(8.0, 9.1 - index * 0.2).toFixed(1)}`,
    ],
    posts: [`已接入 ${dj.name} 的真实资料卡与荣誉数据。`],
    sets: SET_DETAILS.slice(0, Math.max(1, Math.min(2, dj.setCount ?? 1))).map(
      item => item.title,
    ),
  };
}

function mapRemoteFestivalToOrganizerItem(
  festival: RemoteFestival,
  index: number,
): OrganizerItem {
  return {
    id: festival.id,
    name: festival.name,
    country: festival.country ?? '未知',
    city: festival.city ?? '未知',
    foundedYear: festival.foundedYear ?? 'Unknown',
    frequency: festival.frequency ?? '年度',
    palette: remoteCardPalette(index),
    monogram: deriveMonogram(festival.name),
  };
}

function mapRemoteFestivalToOrganizerDetail(
  festival: RemoteFestival,
  index: number,
  eventNames: string[],
): OrganizerDetailData {
  return {
    id: festival.id,
    name: festival.name,
    subtitle: `${festival.city ?? 'Unknown'} · ${festival.country ?? 'Unknown'} · ${festival.foundedYear ?? 'Unknown'}`,
    country: festival.country ?? '未知',
    city: festival.city ?? '未知',
    foundedYear: festival.foundedYear ?? 'Unknown',
    frequency: festival.frequency ?? '年度',
    intro:
      festival.introduction ??
      `${festival.name} 的主办方资料已从现有知识库接入，后续会继续补品牌事件关系与更完整的历史信息。`,
    heroPalette: remotePalette(index),
    events: eventNames.length > 0 ? eventNames : EVENT_DETAILS.slice(0, 2).map(item => item.title),
    posts: [`已接入 ${festival.name} 的主办方介绍与外链资料。`],
  };
}

function mapRemoteLabelToItem(label: RemoteLabel, index: number): LabelItem {
  return {
    id: label.id,
    name: label.name,
    country: formatCountryName(label.nation),
    city: label.locationPeriod?.split('.')[0]?.trim() ?? 'Unknown',
    foundedYear: label.latestReleaseListing ?? 'Unknown',
    focus: label.genresPreview ?? label.genres?.slice(0, 2).join(' / ') ?? 'Electronic',
    releases: label.latestReleaseListing ?? 'Recent Releases',
    followers: formatFollowerCount(label.soundcloudFollowers),
    palette: remoteCardPalette(index),
    monogram: deriveMonogram(label.name),
  };
}

function mapRemoteLabelToDetail(
  label: RemoteLabel,
  index: number,
  featuredDJs: string[],
): LabelDetailData {
  return {
    id: label.id,
    name: label.name,
    subtitle: `${label.locationPeriod ?? formatCountryName(label.nation)}`,
    country: formatCountryName(label.nation),
    city: label.locationPeriod?.split('.')[0]?.trim() ?? 'Unknown',
    foundedYear: label.latestReleaseListing ?? 'Unknown',
    focus:
      label.genresPreview ??
      label.genres?.slice(0, 2).join(' / ') ??
      'Electronic',
    intro:
      label.introduction ??
      `${label.name} 的基础资料已接入现有标签数据库，后续再继续补更强的厂牌关系内容。`,
    heroPalette: remotePalette(index),
    featuredDJs:
      featuredDJs.length > 0
        ? featuredDJs
        : DJ_DETAILS.slice(0, 2).map(item => item.name),
    releases: [label.latestReleaseListing ?? 'Recent Release'],
    posts: [`已接入 ${label.name} 的真实厂牌资料。`],
  };
}

function mapRemoteGenreToSpotlight(
  node: RemoteGenreSummaryNode,
  index: number,
  djs: DJSummary[],
  events: EventDetailData[],
): GenreSpotlight {
  const relatedDJ = djs[index % djs.length] ?? DJ_LIBRARY[index % DJ_LIBRARY.length]!;
  const relatedEvent =
    events[index % events.length] ?? EVENT_DETAILS[index % EVENT_DETAILS.length]!;
  return {
    id: node.id,
    name: node.name,
    description: node.path,
    energy: '适合探索',
    scene: node.children && node.children.length > 0 ? `${node.children.length} 个子风格` : '独立节点',
    relatedDJId: relatedDJ.id,
    relatedDJName: relatedDJ.name,
    relatedEventId: relatedEvent.id,
    relatedEventTitle: relatedEvent.title,
    palette: remoteCardPalette(index),
  };
}

function mapRemoteGenreToDetail(
  node: RemoteGenreSummaryNode,
  index: number,
  djs: DJSummary[],
  events: EventDetailData[],
  remoteDetail?: RemoteGenreDetail | null,
): GenreDetailData {
  return {
    id: node.id,
    name: node.name,
    subtitle: node.path.split(' > ').slice(0, 2).join(' / '),
    description:
      remoteDetail?.descriptionI18n?.zh ??
      remoteDetail?.description ??
      node.path,
    energy: '探索中',
    scene: node.children && node.children.length > 0 ? `${node.children.length} 个分支` : '终端风格',
    heroPalette: remotePalette(index),
    relatedDJs:
      djs.length > 0 ? djs.slice(0, 2).map(item => item.name) : DJ_DETAILS.slice(0, 2).map(item => item.name),
    relatedEvents:
      events.length > 0
        ? events.slice(0, 2).map(item => item.title)
        : EVENT_DETAILS.slice(0, 2).map(item => item.title),
    listeningNotes: [
      `当前接入的是 ${node.name} 在风格树里的真实路径。`,
      remoteDetail?.path ?? node.path,
    ],
  };
}

function mapRemoteRankingEntries(
  entries: RemoteRankingBoardDetail['entries'],
  entityType: string | null | undefined,
): RankingBoardDetailEntry[] {
  return entries.slice(0, 10).map((entry, index) => {
    const isFestivalBoard = entityType === 'festival';
    const linkedDJ = entry.dj ?? null;
    const linkedFestival = entry.festival ?? null;
    const title = linkedFestival?.name ?? linkedDJ?.name ?? entry.name;
    const subtitle = isFestivalBoard
      ? `${linkedFestival?.city ?? '未知城市'} · ${linkedFestival?.country ?? '未知地区'}`
      : `${formatCountryName(linkedDJ?.country)}`;

    return {
      rank: entry.rank,
      title,
      subtitle,
      score: Math.max(8, 9.8 - index * 0.18).toFixed(1),
      delta: formatRankingDelta(entry.delta),
      note: isFestivalBoard
        ? linkedFestival?.tagline ?? `${title} 的真实榜单条目已同步。`
        : `${title} 的真实榜单位次已同步。`,
      palette: remoteCardPalette(index),
      kind: isFestivalBoard ? 'organizer' : 'dj',
      targetId:
        linkedFestival?.id ??
        linkedDJ?.id ??
        entry.entityId ??
        `${entityType ?? 'ranking'}-${entry.rank}`,
    };
  });
}

function mapRemoteRankingBoardDetail(
  boardKey: RankingBoardKey,
  detail: RemoteRankingBoardDetail,
  fallback: RankingBoardDetailData,
): RankingBoardDetailData {
  return {
    ...fallback,
    title: detail.title,
    subtitle: detail.subtitle ?? fallback.subtitle,
    summary: detail.description || fallback.summary,
    updatedAt: String(detail.year ?? formatRankingYearRange(detail.years)),
    scope: '已接入真实榜单详情',
    snapshot: [
      `已同步 ${detail.entries.length} 条真实榜单名次`,
      `榜单年份 ${detail.year ?? formatRankingYearRange(detail.years)}`,
      boardKey === 'organizers' ? '当前映射为主办方/节庆榜单' : '当前映射为 DJ 榜单',
    ],
    entries:
      detail.entries.length > 0
        ? mapRemoteRankingEntries(detail.entries, detail.entityType)
        : fallback.entries,
  };
}

function mapRemoteRankingBoardRows(
  boardKey: RankingBoardKey,
  detail: RemoteRankingBoardDetail,
): RankingEntry[] {
  return mapRemoteRankingEntries(detail.entries, detail.entityType)
    .slice(0, 4)
    .map(item => ({
      id: `${boardKey}-${item.targetId}`,
      title: item.title,
      subtitle: item.subtitle,
      score: item.score,
      delta: item.delta,
      palette: item.palette,
      kind: item.kind,
      targetId: item.targetId,
    }));
}

function mapRankingBoardsFromRemote(
  events: EventListItem[],
  djs: DJSummary[],
  organizers: OrganizerItem[],
): Record<RankingBoardKey, RankingEntry[]> {
  return {
    events: events.slice(0, 3).map((item, index) => ({
      id: `remote-rank-event-${item.id}`,
      title: item.name,
      subtitle: item.address,
      score: (9.4 - index * 0.2).toFixed(1),
      delta: index === 0 ? '+2' : index === 1 ? '+1' : 'NEW',
      palette: item.palette,
      kind: 'event',
      targetId: item.id,
    })),
    djs: djs.slice(0, 3).map((item, index) => ({
      id: `remote-rank-dj-${item.id}`,
      title: item.name,
      subtitle: `${item.country} · ${item.genres.join(' / ')}`,
      score: (9.5 - index * 0.3).toFixed(1),
      delta: index === 0 ? '+1' : index === 1 ? '+3' : 'NEW',
      palette: item.palette,
      kind: 'dj',
      targetId: item.id,
    })),
    organizers: organizers.slice(0, 3).map((item, index) => ({
      id: `remote-rank-organizer-${item.id}`,
      title: item.name,
      subtitle: `${item.city} · ${item.country} · ${item.frequency}`,
      score: (9.2 - index * 0.2).toFixed(1),
      delta: index === 0 ? '+2' : index === 1 ? '-1' : '+1',
      palette: item.palette,
      kind: 'organizer',
      targetId: item.id,
    })),
  };
}

type DiscoverHomeViewProps = {
  mainTab?: MainTabKey;
  onMainTabChange?: (tab: MainTabKey) => void;
};

export function DiscoverHomeView({
  mainTab: controlledMainTab,
  onMainTabChange,
}: DiscoverHomeViewProps = {}) {
  const { eventRecommendationRepository } = useAppContainer();
  const { width, height } = useWindowDimensions();
  const [uncontrolledMainTab, setUncontrolledMainTab] =
    useState<MainTabKey>('discover');
  const [discoverSection, setDiscoverSection] =
    useState<DiscoverSectionKey>('recommend');
  const [selectedEventType, setSelectedEventType] = useState('all');
  const [selectedNewsCategory, setSelectedNewsCategory] =
    useState<NewsCategoryKey>('all');
  const [selectedRankingBoard, setSelectedRankingBoard] =
    useState<RankingBoardKey>('events');
  const [recommendationCards, setRecommendationCards] =
    useState<RecommendationCard[]>(RECOMMENDATIONS);
  const [eventsFeed, setEventsFeed] = useState<EventListItem[]>(EVENTS_FEED);
  const [eventDetails, setEventDetails] = useState<EventDetailData[]>(EVENT_DETAILS);
  const [organizerFeed, setOrganizerFeed] =
    useState<OrganizerItem[]>(ORGANIZER_FEED);
  const [organizerDetails, setOrganizerDetails] =
    useState<OrganizerDetailData[]>(ORGANIZER_DETAILS);
  const [djLibrary, setDJLibrary] = useState<DJSummary[]>(DJ_LIBRARY);
  const [djDetails, setDJDetails] = useState<DJDetailData[]>(DJ_DETAILS);
  const [labelFeed, setLabelFeed] = useState<LabelItem[]>(LABEL_FEED);
  const [labelDetails, setLabelDetails] =
    useState<LabelDetailData[]>(LABEL_DETAILS);
  const [rankingBoards, setRankingBoards] =
    useState<Record<RankingBoardKey, RankingEntry[]>>(RANKING_BOARDS);
  const [rankingBoardDetails, setRankingBoardDetails] =
    useState<Record<RankingBoardKey, RankingBoardDetailData>>(RANKING_BOARD_DETAILS);
  const [genreSpotlights, setGenreSpotlights] =
    useState<GenreSpotlight[]>(GENRE_SPOTLIGHTS);
  const [genreDetails, setGenreDetails] =
    useState<GenreDetailData[]>(GENRE_DETAILS);
  const [detailStack, setDetailStack] = useState<DetailDestination[]>([]);
  const [eventDetailTab, setEventDetailTab] = useState<EventDetailTabKey>('info');
  const [djDetailTab, setDjDetailTab] = useState<DJDetailTabKey>('intro');
  const [organizerDetailTab, setOrganizerDetailTab] =
    useState<OrganizerDetailTabKey>('basic');
  const [newsDetailTab, setNewsDetailTab] =
    useState<NewsDetailTabKey>('article');
  const [labelDetailTab, setLabelDetailTab] =
    useState<LabelDetailTabKey>('basic');
  const [setDetailTab, setSetDetailTab] = useState<SetDetailTabKey>('basic');
  const [genreDetailTab, setGenreDetailTab] =
    useState<GenreDetailTabKey>('overview');
  const [rankingBoardDetailTab, setRankingBoardDetailTab] =
    useState<RankingBoardDetailTabKey>('overview');
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [isSearchMounted, setIsSearchMounted] = useState(false);
  const [recommendStageHeight, setRecommendStageHeight] = useState(0);
  const [activeRecommendationIndex, setActiveRecommendationIndex] = useState(0);
  const recommendViewModel = useRecommendEventsViewModel({
    recommendationRepository: eventRecommendationRepository,
    sessionUserID: null,
  });
  const recommendationScrollRef = useRef<ScrollView | null>(null);
  const topTabsScrollRef = useRef<ScrollView | null>(null);
  const bottomLayouts = useRef<Record<MainTabKey, MeasuredLayout>>({
    discover: { x: 0, width: 0 },
    circle: { x: 0, width: 0 },
    inbox: { x: 0, width: 0 },
    profile: { x: 0, width: 0 },
  }).current;
  const sectionLayouts = useRef<Record<string, MeasuredLayout>>({}).current;
  const bottomPillX = useRef(new Animated.Value(0)).current;
  const bottomPillWidth = useRef(new Animated.Value(0)).current;
  const topIndicatorX = useRef(new Animated.Value(0)).current;
  const topIndicatorWidth = useRef(new Animated.Value(0)).current;
  const overlayOpacity = useRef(new Animated.Value(0)).current;
  const overlayScale = useRef(new Animated.Value(0.96)).current;
  const recommendationScrollX = useRef(new Animated.Value(0)).current;
  const recommendationIndicatorIndex = useRef(new Animated.Value(0)).current;
  const activeDetail = detailStack[detailStack.length - 1] ?? null;
  const mainTab = controlledMainTab ?? uncontrolledMainTab;

  const activeSection =
    DISCOVER_SECTIONS.find(item => item.key === discoverSection) ??
    DISCOVER_SECTIONS[0];
  const visibleEvents =
    selectedEventType === 'all'
      ? eventsFeed
      : eventsFeed.filter(item => item.eventTypeKey === selectedEventType);
  const visibleNews =
    selectedNewsCategory === 'all'
      ? NEWS_FEED
      : NEWS_FEED.filter(item => item.category === selectedNewsCategory);
  const visibleRankingBoard = rankingBoards[selectedRankingBoard];
  const screenAspectRatio = height / Math.max(width, 1);
  const bottomBarVisualHeight = 84;
  const bottomBarInset = Math.max(
    8,
    Math.min(16, 10 + (screenAspectRatio - 1.7) * 8),
  );
  const cardToTabGap = 1;
  const recommendBottomReserve =
    bottomBarVisualHeight + bottomBarInset + cardToTabGap;
  const estimatedRecommendStageHeight = Math.max(height - 54, 0);
  const cardWidth = Math.max(width - 32, 1);
  const cardSpacing = 10;
  const cardSnap = cardWidth + cardSpacing;
  const indicatorBottomInset = recommendBottomReserve + 8;
  const fallbackRecommendedCardHeight = Math.max(
    estimatedRecommendStageHeight - recommendBottomReserve,
    320,
  );
  const recommendedCardHeight =
    recommendStageHeight > 0
      ? Math.max(recommendStageHeight - recommendBottomReserve, 320)
      : fallbackRecommendedCardHeight;
  const indicatorWidth = 28;
  const indicatorDotWidth = 5;
  const indicatorDotHeight = 3;
  const indicatorGap = 4;
  const indicatorTrackWidth =
    indicatorWidth +
    (indicatorDotWidth + indicatorGap) *
      Math.max(recommendationCards.length - 1, 0);
  const detailHeroHeight = Math.max(320, Math.min(height * 0.42, 380));
  const detailTopInset = Math.max(18, Math.min(42, height * 0.042));
  const detailHorizontalPadding = 16;
  const detailBottomPadding = Math.max(108, height * 0.14);

  function animateBottomSelection(tabKey: MainTabKey) {
    const layout = bottomLayouts[tabKey];
    if (!layout || layout.width === 0) {
      return;
    }
    const targetWidth = Math.max(layout.width - 8, 0);
    const targetX = layout.x + 4;

    Animated.parallel([
      Animated.spring(bottomPillX, {
        toValue: targetX,
        stiffness: 240,
        damping: 24,
        mass: 0.9,
        useNativeDriver: false,
      }),
      Animated.spring(bottomPillWidth, {
        toValue: targetWidth,
        stiffness: 240,
        damping: 24,
        mass: 0.9,
        useNativeDriver: false,
      }),
    ]).start();
  }

  function animateTopSectionSelection(sectionKey: DiscoverSectionKey) {
    const layout = sectionLayouts[sectionKey];
    if (!layout || layout.width === 0) {
      return;
    }

    Animated.parallel([
      Animated.spring(topIndicatorX, {
        toValue: layout.x,
        stiffness: 260,
        damping: 28,
        mass: 0.9,
        useNativeDriver: false,
      }),
      Animated.spring(topIndicatorWidth, {
        toValue: layout.width,
        stiffness: 260,
        damping: 28,
        mass: 0.9,
        useNativeDriver: false,
      }),
    ]).start();
  }

  function getEventTypeColor(eventTypeKey: string) {
    return (
      EVENT_TYPE_FILTERS.find(item => item.key === eventTypeKey)?.color ??
      THEME.accent
    );
  }

  function pushDetail(nextDetail: DetailDestination) {
    setDetailStack(currentStack =>
      currentStack.length > 0 ? [...currentStack, nextDetail] : [nextDetail],
    );
  }

  function openEventDetail(eventID: string) {
    const detail = eventDetails.find(item => item.id === eventID);
    if (!detail) {
      return;
    }
    setEventDetailTab('info');
    pushDetail({ kind: 'event', item: detail });
  }

  function openDJDetail(djID: string) {
    const detail = djDetails.find(item => item.id === djID);
    if (!detail) {
      return;
    }
    setDjDetailTab('intro');
    pushDetail({ kind: 'dj', item: detail });
  }

  function openOrganizerDetail(organizerID: string) {
    const detail = organizerDetails.find(item => item.id === organizerID);
    if (!detail) {
      return;
    }
    setOrganizerDetailTab('basic');
    pushDetail({ kind: 'organizer', item: detail });
  }

  function openNewsDetail(newsID: string) {
    const detail = NEWS_DETAILS.find(item => item.id === newsID);
    if (!detail) {
      return;
    }
    setNewsDetailTab('article');
    pushDetail({ kind: 'news', item: detail });
  }

  function openLabelDetail(labelID: string) {
    const detail = labelDetails.find(item => item.id === labelID);
    if (!detail) {
      return;
    }
    setLabelDetailTab('basic');
    pushDetail({ kind: 'label', item: detail });
  }

  function openSetDetail(setID: string) {
    const detail = SET_DETAILS.find(item => item.id === setID);
    if (!detail) {
      return;
    }
    setSetDetailTab('basic');
    pushDetail({ kind: 'set', item: detail });
  }

  function openGenreDetail(genreID: string) {
    const detail = genreDetails.find(item => item.id === genreID);
    if (!detail) {
      return;
    }
    setGenreDetailTab('overview');
    pushDetail({ kind: 'genre', item: detail });
  }

  function openRankingBoardDetail(boardKey: RankingBoardKey) {
    const detail = rankingBoardDetails[boardKey];
    if (!detail) {
      return;
    }
    setRankingBoardDetailTab('overview');
    pushDetail({ kind: 'rankingBoard', item: detail });
  }

  function closeDetail() {
    setDetailStack([]);
  }

  function goBackDetail() {
    setDetailStack(currentStack =>
      currentStack.length > 1 ? currentStack.slice(0, -1) : [],
    );
  }

  function findEventDetailByTitle(title: string) {
    return eventDetails.find(item => item.title === title) ?? null;
  }

  function findDJDetailByName(name: string) {
    return djDetails.find(item => item.name === name) ?? null;
  }

  function findLabelDetailByName(name: string) {
    return labelDetails.find(item => item.name === name) ?? null;
  }

  function findNewsArticleByID(newsID: string) {
    return NEWS_FEED.find(item => item.id === newsID) ?? null;
  }

  function findRelatedNewsIDs(newsID: string, category: NewsCategoryKey) {
    const sameCategory = NEWS_FEED.filter(
      item => item.category === category && item.id !== newsID,
    )
      .map(item => item.id)
      .slice(0, 2);

    if (sameCategory.length > 0) {
      return sameCategory;
    }

    return NEWS_FEED.filter(item => item.id !== newsID)
      .map(item => item.id)
      .slice(0, 2);
  }

  function handleMainTabChange(nextTab: MainTabKey) {
    if (controlledMainTab === undefined) {
      setUncontrolledMainTab(nextTab);
    }
    onMainTabChange?.(nextTab);
  }

  useEffect(() => {
    void recommendViewModel.loadIfNeeded();
  }, [recommendViewModel]);

  useEffect(() => {
    if (recommendViewModel.events.length === 0) {
      return;
    }

    const {
      nextRecommendations,
      nextEventsFeed,
      nextEventDetails,
    } = mapRecommendEventsToState(recommendViewModel.events);

    if (__DEV__) {
      console.log(
        'recommend vm commit',
        nextRecommendations.map(item => ({
          id: item.id,
          title: item.title,
          imageUrl: item.imageUrl ?? null,
        })),
      );
    }

    setRecommendationCards(nextRecommendations);
    setEventsFeed(nextEventsFeed);
    setEventDetails(nextEventDetails);
  }, [recommendViewModel.events]);

  useEffect(() => {
    let cancelled = false;

    async function hydrateDiscoverSupplementalData() {
      const djsPromise = fetchRemoteDJs(6);
      const festivalsPromise = fetchRemoteFestivals(4);
      const labelsPromise = fetchRemoteLabelList(4);
      const genresPromise = fetchRemoteGenreTreeSummary();
      const rankingsPromise = fetchRemoteRankingBoards();

      const [djsResult, festivalsResult, labelsResult, genresResult, rankingsResult] =
        await Promise.allSettled([
          djsPromise,
          festivalsPromise,
          labelsPromise,
          genresPromise,
          rankingsPromise,
        ]);

      let nextEventsFeed = eventsFeed;
      let nextEventDetails = eventDetails;
      let nextDJLibrary = DJ_LIBRARY;
      let nextDJDetails = DJ_DETAILS;
      let nextOrganizerFeed = ORGANIZER_FEED;
      let nextOrganizerDetails = ORGANIZER_DETAILS;
      let nextLabelFeed = LABEL_FEED;
      let nextLabelDetails = LABEL_DETAILS;
      let nextGenreSpotlights = GENRE_SPOTLIGHTS;
      let nextGenreDetails = GENRE_DETAILS;
      let nextRankingBoards = RANKING_BOARDS;
      let nextRankingBoardDetails = RANKING_BOARD_DETAILS;

      const remoteDJs =
        djsResult.status === 'fulfilled' ? djsResult.value.slice(0, 4) : [];
      const remoteFestivals =
        festivalsResult.status === 'fulfilled'
          ? festivalsResult.value.slice(0, 4)
          : [];
      const remoteLabels =
        labelsResult.status === 'fulfilled' ? labelsResult.value.slice(0, 4) : [];

      const djBoardMeta =
        rankingsResult.status === 'fulfilled'
          ? rankingsResult.value.find(item => item.entityType === 'dj') ?? null
          : null;
      const festivalBoardMeta =
        rankingsResult.status === 'fulfilled'
          ? rankingsResult.value.find(item => item.entityType === 'festival') ??
            rankingsResult.value[0] ??
            null
          : null;

      if (remoteFestivals.length > 0) {
        nextOrganizerFeed = remoteFestivals.map((item, index) =>
          mapRemoteFestivalToOrganizerItem(item, index),
        );
      }

      if (remoteDJs.length > 0) {
        nextDJLibrary = remoteDJs.map((item, index) =>
          mapRemoteDJToSummary(item, index),
        );
      }

      if (remoteFestivals.length > 0) {
        const organizerEventNames =
          nextEventsFeed.length > 0
            ? nextEventsFeed.slice(0, 2).map(item => item.name)
            : EVENT_DETAILS.slice(0, 2).map(item => item.title);
        nextOrganizerDetails = remoteFestivals.map((item, index) =>
          mapRemoteFestivalToOrganizerDetail(item, index, organizerEventNames),
        );
      }

      if (remoteDJs.length > 0) {
        const fallbackUpcomingEvents =
          nextEventsFeed.length > 0
            ? nextEventsFeed.slice(0, 2).map(item => item.name)
            : EVENTS_FEED.slice(0, 2).map(item => item.name);
        nextDJDetails = remoteDJs.map((item, index) =>
          mapRemoteDJToDetail(item, index, fallbackUpcomingEvents),
        );
      }

      if (remoteLabels.length > 0) {
        nextLabelFeed = remoteLabels.map((item, index) =>
          mapRemoteLabelToItem(item, index),
        );
        const featuredDJNames =
          nextDJLibrary.length > 0
            ? nextDJLibrary.slice(0, 2).map(item => item.name)
            : DJ_DETAILS.slice(0, 2).map(item => item.name);
        nextLabelDetails = remoteLabels.map((item, index) =>
          mapRemoteLabelToDetail(item, index, featuredDJNames),
        );
      }

      let immediatePickedGenres: RemoteGenreSummaryNode[] = [];
      if (genresResult.status === 'fulfilled') {
        const flattened = flattenGenreNodes(genresResult.value);
        const preferredGenres = flattened.filter(item =>
          ['Techno', 'House', 'Trance', 'Drum & Bass', 'Experimental'].includes(
            item.name,
          ),
        );
        immediatePickedGenres =
          (preferredGenres.length > 0 ? preferredGenres : flattened).slice(0, 4);

        nextGenreSpotlights = immediatePickedGenres.map((item, index) =>
          mapRemoteGenreToSpotlight(item, index, nextDJLibrary, nextEventDetails),
        );
        nextGenreDetails = immediatePickedGenres.map((item, index) =>
          mapRemoteGenreToDetail(item, index, nextDJLibrary, nextEventDetails),
        );
      }

      if (rankingsResult.status === 'fulfilled') {
        nextRankingBoardDetails = {
          ...nextRankingBoardDetails,
          djs: djBoardMeta
            ? {
                ...nextRankingBoardDetails.djs,
                title: djBoardMeta.title,
                subtitle: djBoardMeta.subtitle ?? nextRankingBoardDetails.djs.subtitle,
                summary: djBoardMeta.description || nextRankingBoardDetails.djs.summary,
                updatedAt: formatRankingYearRange(djBoardMeta.years),
                scope: '已接入真实榜单元数据',
              }
            : nextRankingBoardDetails.djs,
          organizers: festivalBoardMeta
            ? {
                ...nextRankingBoardDetails.organizers,
                title: festivalBoardMeta.title,
                subtitle:
                  festivalBoardMeta.subtitle ??
                  nextRankingBoardDetails.organizers.subtitle,
                summary:
                  festivalBoardMeta.description ||
                  nextRankingBoardDetails.organizers.summary,
                updatedAt: formatRankingYearRange(festivalBoardMeta.years),
                scope: '已接入真实榜单元数据',
              }
            : nextRankingBoardDetails.organizers,
        };
      }

      nextRankingBoards = mapRankingBoardsFromRemote(
        nextEventsFeed,
        nextDJLibrary,
        nextOrganizerFeed,
      );

      if (!cancelled) {
        setDJLibrary(nextDJLibrary);
        setDJDetails(nextDJDetails);
        setOrganizerFeed(nextOrganizerFeed);
        setOrganizerDetails(nextOrganizerDetails);
        setLabelFeed(nextLabelFeed);
        setLabelDetails(nextLabelDetails);
        setGenreSpotlights(nextGenreSpotlights);
        setGenreDetails(nextGenreDetails);
        setRankingBoards(nextRankingBoards);
        setRankingBoardDetails(nextRankingBoardDetails);
      }

      const [
        djDetailPayloads,
        djEventsPayloads,
        festivalDetailPayloads,
        labelDetailPayloads,
        genreDetailPayloads,
        djBoardDetailResult,
        festivalBoardDetailResult,
      ] = await Promise.all([
        Promise.allSettled(remoteDJs.map(item => fetchRemoteDJDetail(item.id))),
        Promise.allSettled(remoteDJs.map(item => fetchRemoteDJEvents(item.id, 4))),
        Promise.allSettled(
          remoteFestivals.map(item => fetchRemoteFestivalDetail(item.id)),
        ),
        Promise.allSettled(
          remoteLabels.map(item => fetchRemoteLabelDetail(item.id)),
        ),
        Promise.allSettled(
          immediatePickedGenres.map(item => fetchRemoteGenreDetail(item.id)),
        ),
        djBoardMeta
          ? Promise.allSettled([
              fetchRemoteRankingBoardDetail(
                djBoardMeta.id,
                Math.max(...(djBoardMeta.years ?? [2025])),
              ),
            ])
          : Promise.resolve([]),
        festivalBoardMeta
          ? Promise.allSettled([
              fetchRemoteRankingBoardDetail(
                festivalBoardMeta.id,
                Math.max(...(festivalBoardMeta.years ?? [2025])),
              ),
            ])
          : Promise.resolve([]),
      ]);

      if (remoteFestivals.length > 0) {
        const organizerEventNames =
          nextEventsFeed.length > 0
            ? nextEventsFeed.slice(0, 2).map(item => item.name)
            : EVENT_DETAILS.slice(0, 2).map(item => item.title);
        nextOrganizerDetails = remoteFestivals.map((item, index) =>
          mapRemoteFestivalToOrganizerDetail(
            festivalDetailPayloads[index]?.status === 'fulfilled'
              ? festivalDetailPayloads[index].value
              : item,
            index,
            organizerEventNames,
          ),
        );
      }

      if (remoteDJs.length > 0) {
        const fallbackUpcomingEvents =
          nextEventsFeed.length > 0
            ? nextEventsFeed.slice(0, 2).map(item => item.name)
            : EVENTS_FEED.slice(0, 2).map(item => item.name);
        nextDJDetails = remoteDJs.map((item, index) => {
          const remoteDJ =
            djDetailPayloads[index]?.status === 'fulfilled'
              ? djDetailPayloads[index].value
              : item;
          const upcomingEvents =
            djEventsPayloads[index]?.status === 'fulfilled'
              ? djEventsPayloads[index].value
                  .slice(0, 3)
                  .map(event => event.name)
                  .filter(Boolean)
              : [];

          return mapRemoteDJToDetail(
            remoteDJ,
            index,
            upcomingEvents.length > 0 ? upcomingEvents : fallbackUpcomingEvents,
          );
        });
      }

      if (remoteLabels.length > 0) {
        const featuredDJNames =
          nextDJLibrary.length > 0
            ? nextDJLibrary.slice(0, 2).map(item => item.name)
            : DJ_DETAILS.slice(0, 2).map(item => item.name);
        nextLabelDetails = labelDetailPayloads.map((result, index) =>
          mapRemoteLabelToDetail(
            result.status === 'fulfilled' ? result.value : remoteLabels[index]!,
            index,
            featuredDJNames,
          ),
        );
      }

      if (immediatePickedGenres.length > 0) {
        nextGenreSpotlights = immediatePickedGenres.map((item, index) =>
          mapRemoteGenreToSpotlight(item, index, nextDJLibrary, nextEventDetails),
        );
        nextGenreDetails = immediatePickedGenres.map((item, index) =>
          mapRemoteGenreToDetail(
            item,
            index,
            nextDJLibrary,
            nextEventDetails,
            genreDetailPayloads[index]?.status === 'fulfilled'
              ? genreDetailPayloads[index].value
              : null,
          ),
        );
      }

      if (rankingsResult.status === 'fulfilled') {
        const resolvedDJBoardDetail =
          djBoardDetailResult[0]?.status === 'fulfilled'
            ? djBoardDetailResult[0].value
            : null;
        const resolvedFestivalBoardDetail =
          festivalBoardDetailResult[0]?.status === 'fulfilled'
            ? festivalBoardDetailResult[0].value
            : null;

        nextRankingBoardDetails = {
          ...nextRankingBoardDetails,
          djs:
            djBoardMeta && resolvedDJBoardDetail
              ? mapRemoteRankingBoardDetail(
                  'djs',
                  resolvedDJBoardDetail,
                  nextRankingBoardDetails.djs,
                )
              : nextRankingBoardDetails.djs,
          organizers:
            festivalBoardMeta && resolvedFestivalBoardDetail
              ? mapRemoteRankingBoardDetail(
                  'organizers',
                  resolvedFestivalBoardDetail,
                  nextRankingBoardDetails.organizers,
                )
              : nextRankingBoardDetails.organizers,
        };
      }

      nextRankingBoards = mapRankingBoardsFromRemote(
        nextEventsFeed,
        nextDJLibrary,
        nextOrganizerFeed,
      );
      const resolvedDJBoardRows =
        djBoardDetailResult[0]?.status === 'fulfilled'
          ? djBoardDetailResult[0].value
          : null;
      const resolvedFestivalBoardRows =
        festivalBoardDetailResult[0]?.status === 'fulfilled'
          ? festivalBoardDetailResult[0].value
          : null;

      if (djBoardMeta && resolvedDJBoardRows) {
        nextRankingBoards = {
          ...nextRankingBoards,
          djs: mapRemoteRankingBoardRows('djs', resolvedDJBoardRows),
        };
      }
      if (festivalBoardMeta && resolvedFestivalBoardRows) {
        nextRankingBoards = {
          ...nextRankingBoards,
          organizers: mapRemoteRankingBoardRows(
            'organizers',
            resolvedFestivalBoardRows,
          ),
        };
      }

      if (!cancelled) {
        setDJDetails(nextDJDetails);
        setOrganizerDetails(nextOrganizerDetails);
        setLabelDetails(nextLabelDetails);
        setGenreSpotlights(nextGenreSpotlights);
        setGenreDetails(nextGenreDetails);
        setRankingBoards(nextRankingBoards);
        setRankingBoardDetails(nextRankingBoardDetails);
      }
    }

    hydrateDiscoverSupplementalData().catch(error => {
      console.error('hydrateDiscoverSupplementalData failed', error);
    });

    return () => {
      cancelled = true;
    };
  }, [eventDetails, eventsFeed, recommendViewModel.events.length]);

  useEffect(() => {
    animateBottomSelection(mainTab);
  }, [mainTab]);

  useEffect(() => {
    Animated.spring(recommendationIndicatorIndex, {
      toValue: activeRecommendationIndex,
      stiffness: 320,
      damping: 26,
      mass: 0.72,
      useNativeDriver: false,
    }).start();
  }, [activeRecommendationIndex, recommendationIndicatorIndex]);

  useEffect(() => {
    const listenerId = recommendationScrollX.addListener(({ value }) => {
      const nextIndex = Math.round(value / cardSnap);
      setActiveRecommendationIndex(prevIndex => {
        const clampedIndex = Math.max(
          0,
          Math.min(recommendationCards.length - 1, nextIndex),
        );
        return prevIndex === clampedIndex ? prevIndex : clampedIndex;
      });
    });

    return () => {
      recommendationScrollX.removeListener(listenerId);
    };
  }, [cardSnap, recommendationCards.length, recommendationScrollX]);

  useEffect(() => {
    animateTopSectionSelection(discoverSection);

    const layout = sectionLayouts[discoverSection];
    if (!layout || layout.width === 0) {
      return;
    }
    topTabsScrollRef.current?.scrollTo({
      x: Math.max(layout.x - width / 2 + layout.width / 2, 0),
      animated: true,
    });
  }, [
    discoverSection,
    sectionLayouts,
    topIndicatorWidth,
    topIndicatorX,
    width,
  ]);

  useEffect(() => {
    if (isSearchOpen) {
      setIsSearchMounted(true);
      Animated.parallel([
        Animated.timing(overlayOpacity, {
          toValue: 1,
          duration: 180,
          useNativeDriver: true,
        }),
        Animated.spring(overlayScale, {
          toValue: 1,
          stiffness: 260,
          damping: 24,
          mass: 0.95,
          useNativeDriver: true,
        }),
      ]).start();
      return;
    }

    Animated.parallel([
      Animated.timing(overlayOpacity, {
        toValue: 0,
        duration: 160,
        useNativeDriver: true,
      }),
      Animated.timing(overlayScale, {
        toValue: 0.96,
        duration: 160,
        useNativeDriver: true,
      }),
    ]).start(({ finished }) => {
      if (finished) {
        setIsSearchMounted(false);
      }
    });
  }, [isSearchOpen, overlayOpacity, overlayScale]);

  let currentScreen: React.ReactNode;
  switch (mainTab) {
    case 'discover':
      currentScreen = renderDiscoverScreen();
      break;
    case 'circle':
      currentScreen = (
        <CircleHomeView
          bottomInset={bottomBarVisualHeight + bottomBarInset + 24}
        />
      );
      break;
    case 'inbox':
      currentScreen = (
        <InboxHomeView
          bottomInset={bottomBarVisualHeight + bottomBarInset + 24}
        />
      );
      break;
    case 'profile':
      currentScreen = (
        <ProfileHomeView
          bottomInset={bottomBarVisualHeight + bottomBarInset + 24}
        />
      );
      break;
  }

  function handleSectionPress(sectionKey: DiscoverSectionKey) {
    setDiscoverSection(sectionKey);
  }

  function openSearch() {
    setIsSearchOpen(true);
  }

  function closeSearch() {
    setIsSearchOpen(false);
  }

  function renderDiscoverScreen() {
    return (
      <View style={styles.discoverScreen}>
        <View style={styles.discoverTabBarWrap}>
          <ScrollView
            ref={topTabsScrollRef}
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.discoverTabScrollContent}
          >
            <View style={styles.discoverTabsRow}>
              {DISCOVER_SECTIONS.map(section => {
                const isSelected = section.key === discoverSection;
                return (
                  <Pressable
                    key={section.key}
                    onLayout={event => {
                      sectionLayouts[section.key] = {
                        x: event.nativeEvent.layout.x,
                        width: event.nativeEvent.layout.width,
                      };
                      if (section.key === discoverSection) {
                        animateTopSectionSelection(section.key);
                      }
                    }}
                    onPress={() => handleSectionPress(section.key)}
                    style={styles.discoverTabButton}
                  >
                    <Text
                      style={[
                        styles.discoverTabText,
                        isSelected && {
                          color: section.color,
                          fontWeight: '600',
                        },
                      ]}
                    >
                      {section.label}
                    </Text>
                  </Pressable>
                );
              })}
              <Animated.View
                pointerEvents="none"
                style={[
                  styles.discoverIndicator,
                  {
                    backgroundColor: activeSection.color,
                    transform: [{ translateX: topIndicatorX }],
                    width: topIndicatorWidth,
                  },
                ]}
              />
            </View>
          </ScrollView>
        </View>

        {renderDiscoverSectionContent()}
      </View>
    );
  }

  function renderDiscoverSectionContent() {
    switch (discoverSection) {
      case 'recommend':
        return renderRecommendSection();
      case 'events':
        return renderEventsSection();
      case 'news':
        return renderNewsSection();
      case 'organizers':
        return renderOrganizersSection();
      case 'djs':
        return renderDJsSection();
      case 'labels':
        return renderLabelsSection();
      case 'rankings':
        return renderRankingsSection();
      case 'sets':
        return renderSetsSection();
      case 'genres':
        return renderGenresSection();
      default:
        return renderSectionPlaceholder(activeSection);
    }
  }

  function renderRecommendSection() {
    return (
      <View style={styles.recommendPagerWrap}>
        <View
          style={styles.recommendStage}
          onLayout={event => {
            const nextHeight = event.nativeEvent.layout.height;
            if (Math.abs(nextHeight - recommendStageHeight) > 1) {
              setRecommendStageHeight(nextHeight);
            }
          }}
        >
          <Animated.ScrollView
            ref={recommendationScrollRef}
            horizontal
            decelerationRate="fast"
            snapToInterval={cardSnap}
            disableIntervalMomentum
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={[
              styles.recommendScrollContent,
              { paddingBottom: recommendBottomReserve },
            ]}
            onScroll={Animated.event(
              [{ nativeEvent: { contentOffset: { x: recommendationScrollX } } }],
              { useNativeDriver: false },
            )}
            onMomentumScrollEnd={event => {
              const nextIndex = Math.round(
                event.nativeEvent.contentOffset.x / cardSnap,
              );
              setActiveRecommendationIndex(
                Math.max(0, Math.min(recommendationCards.length - 1, nextIndex)),
              );
            }}
            scrollEventThrottle={16}
          >
            {recommendationCards.map((item, index) => {
              const inputRange = [
                (index - 1) * cardSnap,
                index * cardSnap,
                (index + 1) * cardSnap,
              ];
              const parallaxTranslate = recommendationScrollX.interpolate({
                inputRange,
                outputRange: [34, 0, -34],
                extrapolate: 'clamp',
              });
              const scale = recommendationScrollX.interpolate({
                inputRange,
                outputRange: [0.95, 1, 0.95],
                extrapolate: 'clamp',
              });

              return (
                <Animated.View
                  key={item.id}
                  style={[
                    styles.cardFrame,
                    {
                      width: cardWidth,
                      height: recommendedCardHeight,
                      marginRight:
                        index === recommendationCards.length - 1 ? 0 : cardSpacing,
                      transform: [{ scale }],
                    },
                  ]}
                >
                  <Pressable
                    style={styles.cardButton}
                    onPress={() => openEventDetail(item.id)}
                  >
                    <View style={styles.cardBase}>
                      <LinearGradient
                        colors={item.palette}
                        start={{ x: 0, y: 0 }}
                        end={{ x: 1, y: 1 }}
                        style={styles.cardFill}
                      />
                      {item.imageUrl ? (
                        <Image
                          source={{ uri: item.imageUrl }}
                          style={styles.cardImage}
                          resizeMode="cover"
                        />
                      ) : null}
                      <View style={styles.cardImageTint} />

                      <Animated.View
                        style={[
                          styles.cardAtmosphereBand,
                          styles.cardAtmosphereBandPrimary,
                          { transform: [{ translateX: parallaxTranslate }] },
                        ]}
                      />
                      <Animated.View
                        style={[
                          styles.cardAtmosphereBand,
                          styles.cardAtmosphereBandSecondary,
                          {
                            transform: [
                              {
                                translateX: Animated.multiply(
                                  parallaxTranslate,
                                  0.7,
                                ),
                              },
                            ],
                          },
                        ]}
                      />

                      <LinearGradient
                        colors={[
                          'rgba(0,0,0,0)',
                          'rgba(0,0,0,0)',
                          'rgba(0,0,0,0.68)',
                          'rgba(0,0,0,0.92)',
                        ]}
                        locations={[0, 0.58, 0.8, 1]}
                        style={styles.cardShade}
                      />

                      <View style={styles.cardMeta}>
                        <View style={styles.cardPillRow}>
                          <View style={styles.typePill}>
                            <Text style={styles.typePillText}>{item.type}</Text>
                          </View>
                          <View style={styles.statusPill}>
                            <Text style={styles.statusPillText}>
                              {item.status}
                            </Text>
                          </View>
                        </View>

                        <View style={styles.cardLine}>
                          <Ionicons
                            name="location-outline"
                            size={14}
                            color="rgba(255,255,255,0.88)"
                          />
                          <Text style={styles.cardLineText}>{item.location}</Text>
                        </View>

                        <View style={styles.cardLine}>
                          <Ionicons
                            name="calendar-outline"
                            size={13}
                            color="rgba(255,255,255,0.86)"
                          />
                          <Text style={styles.cardLineTextSecondary}>
                            {item.date}
                          </Text>
                        </View>

                        <Text style={styles.cardHeadline}>{item.title}</Text>
                      </View>
                    </View>
                  </Pressable>
                </Animated.View>
              );
            })}
          </Animated.ScrollView>

          <View
            pointerEvents="none"
            style={[
              styles.recommendIndicatorWrap,
              { bottom: indicatorBottomInset },
            ]}
          >
            <View
              style={[
                styles.recommendIndicatorTrack,
                {
                  width: indicatorTrackWidth,
                  gap: indicatorGap,
                },
              ]}
            >
              {recommendationCards.map((item, index) => {
                const animatedWidth = recommendationIndicatorIndex.interpolate({
                  inputRange: [index - 1, index, index + 1],
                  outputRange: [indicatorDotWidth, indicatorWidth, indicatorDotWidth],
                  extrapolate: 'clamp',
                });
                const animatedColor = recommendationIndicatorIndex.interpolate({
                  inputRange: [index - 1, index, index + 1],
                  outputRange: [
                    'rgba(255,255,255,0.30)',
                    THEME.pageIndicator,
                    'rgba(255,255,255,0.30)',
                  ],
                  extrapolate: 'clamp',
                });
                const animatedShadowOpacity =
                  recommendationIndicatorIndex.interpolate({
                    inputRange: [index - 1, index, index + 1],
                    outputRange: [0, 0.9, 0],
                    extrapolate: 'clamp',
                  });
                const animatedShadowRadius =
                  recommendationIndicatorIndex.interpolate({
                    inputRange: [index - 1, index, index + 1],
                    outputRange: [0, 6, 0],
                    extrapolate: 'clamp',
                  });
                const animatedGlowRadius =
                  recommendationIndicatorIndex.interpolate({
                    inputRange: [index - 1, index, index + 1],
                    outputRange: [0, 12, 0],
                    extrapolate: 'clamp',
                  });

                return (
                  <Animated.View
                    key={item.id}
                    style={[
                      styles.recommendIndicatorDot,
                      {
                        width: animatedWidth,
                        height: indicatorDotHeight,
                        backgroundColor: animatedColor,
                        shadowOpacity: animatedShadowOpacity,
                        shadowRadius: animatedShadowRadius,
                        elevation: index === activeRecommendationIndex ? 8 : 0,
                      },
                    ]}
                  >
                    <Animated.View
                      pointerEvents="none"
                      style={[
                        styles.recommendIndicatorGlow,
                        {
                          shadowRadius: animatedGlowRadius,
                          shadowOpacity: animatedShadowOpacity,
                        },
                      ]}
                    />
                  </Animated.View>
                );
              })}
            </View>
          </View>
        </View>
      </View>
    );
  }

  function renderEventsSection() {
    return (
      <View style={styles.sectionScreen}>
        <View style={styles.eventsHeader}>
          <View style={styles.eventsUtilityRow}>
            <Pressable style={styles.locationFilterButton}>
              <Ionicons name="location" size={12} color={THEME.primaryText} />
              <Text style={styles.locationFilterText}>上海</Text>
            </Pressable>
            <Pressable style={styles.utilityIconButton}>
              <Ionicons
                name="calendar-outline"
                size={16}
                color={THEME.primaryText}
              />
            </Pressable>
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.eventsChipScrollContent}
            >
              {EVENT_TYPE_FILTERS.map(filter => {
                const isActive = filter.key === selectedEventType;
                return (
                  <Pressable
                    key={filter.key}
                    onPress={() => setSelectedEventType(filter.key)}
                    style={[
                      styles.eventsTypeChip,
                      isActive && { backgroundColor: filter.color },
                    ]}
                  >
                    <Text
                      style={[
                        styles.eventsTypeChipText,
                        isActive && styles.eventsTypeChipTextActive,
                      ]}
                    >
                      {filter.label}
                    </Text>
                  </Pressable>
                );
              })}
            </ScrollView>
          </View>
        </View>

        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={styles.eventsScrollContent}
        >
          {visibleEvents.map(event => {
            const eventTypeColor = getEventTypeColor(event.eventTypeKey);

            return (
            <Pressable
              key={event.id}
              style={styles.eventRowCard}
              onPress={() => openEventDetail(event.id)}
            >
              <View style={styles.eventRowCover}>
                <LinearGradient
                  colors={event.palette}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={styles.eventRowCoverFill}
                />
                <View style={styles.eventDateBadge}>
                  <Text style={styles.eventDateBadgeMonth}>{event.month}</Text>
                  <Text style={styles.eventDateBadgeDay}>{event.day}</Text>
                </View>
                <View
                  style={[
                    styles.eventStatusBadge,
                    { backgroundColor: event.statusColor },
                  ]}
                >
                  <Text style={styles.eventStatusBadgeText}>{event.status}</Text>
                </View>
              </View>

              <View style={styles.eventRowMeta}>
                <Text style={styles.eventRowTitle}>{event.name}</Text>
                <View
                  style={[
                    styles.eventTypeBadge,
                    { backgroundColor: `${eventTypeColor}26` },
                  ]}
                >
                  <Text
                    style={[
                      styles.eventTypeBadgeText,
                      { color: eventTypeColor },
                    ]}
                  >
                    {event.eventTypeLabel}
                  </Text>
                </View>
                <View style={styles.eventInfoLine}>
                  <Ionicons
                    name="calendar-outline"
                    size={13}
                    color={THEME.secondaryText}
                  />
                  <Text style={styles.eventInfoText}>{event.dateRange}</Text>
                </View>
                <View style={styles.eventInfoLine}>
                  <Ionicons
                    name="location-outline"
                    size={13}
                    color={THEME.secondaryText}
                  />
                  <Text style={styles.eventInfoText}>{event.address}</Text>
                </View>
              </View>
            </Pressable>
            );
          })}
        </ScrollView>

        <View style={styles.eventsFloatingWrap}>
          <View style={styles.eventsPromptBubble}>
            <Text style={styles.eventsPromptText}>没有找？快来添加</Text>
            <Pressable style={styles.eventsPromptClose}>
              <Ionicons name="close" size={12} color={THEME.secondaryText} />
            </Pressable>
          </View>
          <LinearGradient
            colors={[THEME.accent, '#5238E5']}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.eventsFloatingButton}
          >
            <Ionicons name="add" size={24} color="#FFFFFF" />
          </LinearGradient>
        </View>
      </View>
    );
  }

  function renderNewsSection() {
    return (
      <View style={styles.sectionScreen}>
        <View style={styles.newsHeader}>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.newsChipScrollContent}
          >
            {NEWS_CATEGORIES.map(category => {
              const isActive = category.key === selectedNewsCategory;
              return (
                <Pressable
                  key={category.key}
                  onPress={() => setSelectedNewsCategory(category.key)}
                  style={[
                    styles.newsCategoryChip,
                    isActive && { backgroundColor: category.color },
                  ]}
                >
                  <Text
                    style={[
                      styles.newsCategoryChipText,
                      isActive && styles.newsCategoryChipTextActive,
                    ]}
                  >
                    {category.label}
                  </Text>
                </Pressable>
              );
            })}
          </ScrollView>
          <Pressable style={styles.newsComposeButton}>
            <Ionicons name="create-outline" size={16} color="#FFFFFF" />
          </Pressable>
        </View>

        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={styles.newsScrollContent}
        >
          {visibleNews.map((article, index) => {
            const category =
              NEWS_CATEGORIES.find(item => item.key === article.category) ??
              NEWS_CATEGORIES[0];

            return (
              <View key={article.id}>
                <Pressable
                  style={styles.newsRow}
                  onPress={() => openNewsDetail(article.id)}
                >
                  <View style={styles.newsMeta}>
                    <View style={styles.newsBadgeRow}>
                      <View
                        style={[
                          styles.newsCategoryBadge,
                          { backgroundColor: `${category.color}20` },
                        ]}
                      >
                        <Text
                          style={[
                            styles.newsCategoryBadgeText,
                            { color: category.color },
                          ]}
                        >
                          {category.label}
                        </Text>
                      </View>
                      <Text style={styles.newsSourceText}>{article.source}</Text>
                    </View>
                    <Text style={styles.newsTitle}>{article.title}</Text>
                    <Text style={styles.newsSummary}>{article.summary}</Text>
                    <View style={styles.newsFooterRow}>
                      <Text style={styles.newsFooterText}>{article.publishedAt}</Text>
                      <View style={styles.newsFooterReply}>
                        <Ionicons
                          name="chatbubble-outline"
                          size={12}
                          color={THEME.secondaryText}
                        />
                        <Text style={styles.newsFooterText}>
                          {article.replyCount}
                        </Text>
                      </View>
                    </View>
                  </View>
                  <View style={styles.newsCover}>
                    <LinearGradient
                      colors={article.palette}
                      start={{ x: 0, y: 0 }}
                      end={{ x: 1, y: 1 }}
                      style={styles.newsCoverFill}
                    />
                    <Ionicons
                      name="newspaper"
                      size={24}
                      color="rgba(255,255,255,0.82)"
                    />
                  </View>
                </Pressable>
                {index < visibleNews.length - 1 ? (
                  <View style={styles.newsDivider} />
                ) : null}
              </View>
            );
          })}
        </ScrollView>
      </View>
    );
  }

  function renderOrganizersSection() {
    return (
      <View style={styles.sectionScreen}>
        <View style={styles.organizersToolbar}>
          <Text style={styles.organizersToolbarText}>
            已加载 {organizerFeed.length} / 共 128 个主办方
          </Text>
          <Pressable style={styles.organizersAddButton}>
            <Ionicons name="add-circle" size={14} color="#FFFFFF" />
            <Text style={styles.organizersAddButtonText}>新增主办方</Text>
          </Pressable>
        </View>

        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={styles.organizersScrollContent}
        >
          {organizerFeed.map(item => (
            <Pressable
              key={item.id}
              style={styles.organizerCard}
              onPress={() => openOrganizerDetail(item.id)}
            >
              <View style={styles.organizerBanner}>
                <LinearGradient
                  colors={item.palette}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={styles.organizerBannerFill}
                />
                <LinearGradient
                  colors={[
                    'rgba(0,0,0,0)',
                    'rgba(0,0,0,0.45)',
                    'rgba(0,0,0,0.8)',
                  ]}
                  locations={[0, 0.55, 1]}
                  style={styles.organizerBannerShade}
                />
                <View style={styles.organizerIdentityRow}>
                  <View style={styles.organizerAvatar}>
                    <LinearGradient
                      colors={item.palette}
                      start={{ x: 0, y: 0 }}
                      end={{ x: 1, y: 1 }}
                      style={styles.organizerAvatarFill}
                    />
                    <Text style={styles.organizerAvatarText}>
                      {item.monogram}
                    </Text>
                  </View>
                  <View style={styles.organizerTextWrap}>
                    <Text style={styles.organizerName}>{item.name}</Text>
                    <Text style={styles.organizerInfoLine}>
                      {item.country} · {item.city} · {item.foundedYear} ·{' '}
                      {item.frequency}
                    </Text>
                  </View>
                </View>
              </View>
            </Pressable>
          ))}
        </ScrollView>
      </View>
    );
  }

  function renderDJsSection() {
    return (
      <View style={styles.sectionScreen}>
        <View style={styles.djsToolbar}>
          <Text style={styles.djsToolbarText}>
            已收录 {djLibrary.length} / 共 342 位 DJ
          </Text>
          <Pressable style={styles.djsAddButton}>
            <Ionicons name="add-circle" size={14} color="#FFFFFF" />
            <Text style={styles.djsAddButtonText}>新增 DJ</Text>
          </Pressable>
        </View>

        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={styles.djsScrollContent}
        >
          {djLibrary.map(item => (
            <Pressable
              key={item.id}
              style={styles.djCard}
              onPress={() => openDJDetail(item.id)}
            >
              <LinearGradient
                colors={item.palette}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.djAvatar}
              >
                <Text style={styles.djAvatarText}>{item.monogram}</Text>
              </LinearGradient>
              <View style={styles.djMeta}>
                <Text style={styles.djName}>{item.name}</Text>
                <Text style={styles.djSubline}>
                  {item.country} · {item.city}
                </Text>
                <View style={styles.djGenreRow}>
                  {item.genres.map(genre => (
                    <View key={genre} style={styles.djGenrePill}>
                      <Text style={styles.djGenrePillText}>{genre}</Text>
                    </View>
                  ))}
                </View>
              </View>
              <Ionicons
                name="chevron-forward"
                size={16}
                color="rgba(255,255,255,0.46)"
              />
            </Pressable>
          ))}
        </ScrollView>
      </View>
    );
  }

  function renderLabelsSection() {
    return (
      <View style={styles.sectionScreen}>
        <View style={styles.labelsToolbar}>
          <Text style={styles.labelsToolbarText}>
            精选电子音乐厂牌与发行目录
          </Text>
          <Pressable style={styles.labelsAddButton}>
            <Ionicons name="add-circle" size={14} color="#FFFFFF" />
            <Text style={styles.labelsAddButtonText}>新增厂牌</Text>
          </Pressable>
        </View>

        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={styles.labelsScrollContent}
        >
          {labelFeed.map(item => (
            <Pressable
              key={item.id}
              style={styles.labelCard}
              onPress={() => openLabelDetail(item.id)}
            >
              <LinearGradient
                colors={item.palette}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.labelCardHero}
              >
                <View style={styles.labelMonogramWrap}>
                  <Text style={styles.labelMonogramText}>{item.monogram}</Text>
                </View>
                <View style={styles.labelHeroMeta}>
                  <Text style={styles.labelName}>{item.name}</Text>
                  <Text style={styles.labelLocationLine}>
                    {item.country} · {item.city} · {item.foundedYear}
                  </Text>
                </View>
              </LinearGradient>

              <View style={styles.labelCardBody}>
                <Text style={styles.labelFocusText}>{item.focus}</Text>
                <View style={styles.labelStatsRow}>
                  <Text style={styles.labelStatText}>{item.releases}</Text>
                  <Text style={styles.labelStatsDivider}>·</Text>
                  <Text style={styles.labelStatText}>{item.followers}</Text>
                </View>
              </View>
            </Pressable>
          ))}
        </ScrollView>
      </View>
    );
  }

  function openRankingTarget(entry: RankingEntry) {
    switch (entry.kind) {
      case 'event':
        openEventDetail(entry.targetId);
        break;
      case 'dj':
        openDJDetail(entry.targetId);
        break;
      case 'organizer':
        openOrganizerDetail(entry.targetId);
        break;
    }
  }

  function renderRankingsSection() {
    const boardDetail = rankingBoardDetails[selectedRankingBoard];

    return (
      <View style={styles.sectionScreen}>
        <View style={styles.rankingsHeader}>
          <View style={styles.rankingsBoardSwitch}>
            {([
              { key: 'events', label: '活动热度' },
              { key: 'djs', label: 'DJ 热度' },
              { key: 'organizers', label: '主办方' },
            ] as const).map(item => {
              const selected = selectedRankingBoard === item.key;
              return (
                <Pressable
                  key={item.key}
                  onPress={() => setSelectedRankingBoard(item.key)}
                  style={[
                    styles.rankingsBoardChip,
                    selected && styles.rankingsBoardChipActive,
                  ]}
                >
                  <Text
                    style={[
                      styles.rankingsBoardChipText,
                      selected && styles.rankingsBoardChipTextActive,
                    ]}
                  >
                    {item.label}
                  </Text>
                </Pressable>
              );
            })}
          </View>
        </View>

        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={styles.rankingsScrollContent}
        >
          <Pressable
            onPress={() => openRankingBoardDetail(selectedRankingBoard)}
            style={styles.rankingHeroCard}
          >
            <LinearGradient
              colors={boardDetail.heroPalette}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.rankingHeroGradient}
            >
              <View style={styles.rankingHeroTopRow}>
                <View style={styles.rankingHeroBadge}>
                  <Text style={styles.rankingHeroBadgeText}>完整榜单</Text>
                </View>
                <Ionicons
                  name="chevron-forward"
                  size={16}
                  color="rgba(255,255,255,0.84)"
                />
              </View>
              <Text style={styles.rankingHeroTitle}>{boardDetail.title}</Text>
              <Text style={styles.rankingHeroSubtitle}>
                {boardDetail.subtitle}
              </Text>
              <Text style={styles.rankingHeroSummary}>{boardDetail.summary}</Text>
              <View style={styles.rankingHeroFooter}>
                <Text style={styles.rankingHeroMetaText}>{boardDetail.updatedAt}</Text>
                <Text style={styles.rankingHeroMetaText}>{boardDetail.scope}</Text>
              </View>
            </LinearGradient>
          </Pressable>

          <View style={styles.rankingInsightList}>
            {boardDetail.snapshot.map(item => (
              <View key={item} style={styles.rankingInsightCard}>
                <Ionicons
                  name="sparkles-outline"
                  size={15}
                  color={THEME.pageIndicator}
                />
                <Text style={styles.rankingInsightText}>{item}</Text>
              </View>
            ))}
          </View>

          {visibleRankingBoard.map((item, index) => (
            <Pressable
              key={item.id}
              style={styles.rankingRow}
              onPress={() => openRankingTarget(item)}
            >
              <View style={styles.rankingIndexWrap}>
                <Text style={styles.rankingIndexText}>{index + 1}</Text>
              </View>
              <LinearGradient
                colors={item.palette}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.rankingThumb}
              />
              <View style={styles.rankingMeta}>
                <Text style={styles.rankingTitle}>{item.title}</Text>
                <Text style={styles.rankingSubtitle}>{item.subtitle}</Text>
              </View>
              <View style={styles.rankingScoreWrap}>
                <Text style={styles.rankingScore}>{item.score}</Text>
                <Text style={styles.rankingDelta}>{item.delta}</Text>
              </View>
            </Pressable>
          ))}
        </ScrollView>
      </View>
    );
  }

  function renderSetsSection() {
    return (
      <View style={styles.sectionScreen}>
        <View style={styles.setsToolbar}>
          <Text style={styles.setsToolbarText}>
            现场录音、巡演回放与精选 sets
          </Text>
          <Pressable style={styles.setsFilterButton}>
            <Ionicons name="options-outline" size={15} color="#FFFFFF" />
          </Pressable>
        </View>

        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={styles.setsScrollContent}
        >
          {SETS_FEED.map(item => (
            <View key={item.id} style={styles.setCard}>
              <Pressable
                style={styles.setCardTop}
                onPress={() => openSetDetail(item.id)}
              >
                <LinearGradient
                  colors={item.palette}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={styles.setThumb}
                >
                  <Ionicons name="play" size={20} color="#FFFFFF" />
                </LinearGradient>
                <View style={styles.setMeta}>
                  <Text style={styles.setTitle}>{item.title}</Text>
                  <Text style={styles.setSubtitle}>
                    {item.djName} · {item.style}
                  </Text>
                  <Text style={styles.setMetaLine}>
                    {item.duration} · {item.bpm}
                  </Text>
                </View>
                <Ionicons
                  name="chevron-forward"
                  size={16}
                  color="rgba(255,255,255,0.46)"
                />
              </Pressable>

              <Pressable
                style={styles.setLinkedEventRow}
                onPress={() => openDJDetail(item.djId)}
              >
                <Ionicons
                  name="person-outline"
                  size={14}
                  color={THEME.secondaryText}
                />
                <Text style={styles.setLinkedEventText}>{item.djName}</Text>
              </Pressable>

              <Pressable
                style={styles.setLinkedEventRow}
                onPress={() => openEventDetail(item.eventId)}
              >
                <Ionicons
                  name="radio-outline"
                  size={14}
                  color={THEME.secondaryText}
                />
                <Text style={styles.setLinkedEventText}>{item.eventTitle}</Text>
              </Pressable>
            </View>
          ))}
        </ScrollView>
      </View>
    );
  }

  function renderGenresSection() {
    return (
      <View style={styles.sectionScreen}>
        <View style={styles.genresToolbar}>
          <Text style={styles.genresToolbarText}>
            从风格切入，看场景、DJ 和活动的关联
          </Text>
        </View>

        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={styles.genresScrollContent}
        >
          {genreSpotlights.map(item => (
            <Pressable
              key={item.id}
              style={styles.genreCard}
              onPress={() => openGenreDetail(item.id)}
            >
              <LinearGradient
                colors={item.palette}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.genreHero}
              >
                <Text style={styles.genreName}>{item.name}</Text>
                <Text style={styles.genreScene}>{item.scene}</Text>
              </LinearGradient>

              <View style={styles.genreBody}>
                <Text style={styles.genreDescription}>{item.description}</Text>
                <View style={styles.genreTagsRow}>
                  <View style={styles.genreTag}>
                    <Text style={styles.genreTagText}>{item.energy}</Text>
                  </View>
                  <View style={styles.genreTag}>
                    <Text style={styles.genreTagText}>{item.scene}</Text>
                  </View>
                </View>

                <Pressable
                  style={styles.genreLinkedRow}
                  onPress={() => openDJDetail(item.relatedDJId)}
                >
                  <Ionicons
                    name="person-outline"
                    size={14}
                    color={THEME.secondaryText}
                  />
                  <Text style={styles.genreLinkedText}>
                    推荐 DJ · {item.relatedDJName}
                  </Text>
                </Pressable>
                <Pressable
                  style={styles.genreLinkedRow}
                  onPress={() => openEventDetail(item.relatedEventId)}
                >
                  <Ionicons
                    name="radio-outline"
                    size={14}
                    color={THEME.secondaryText}
                  />
                  <Text style={styles.genreLinkedText}>
                    关联活动 · {item.relatedEventTitle}
                  </Text>
                </Pressable>
              </View>
            </Pressable>
          ))}
        </ScrollView>
      </View>
    );
  }

  function renderDetailTabs<T extends string>(
    tabs: Array<{ key: T; label: string; color: string }>,
    activeKey: T,
    onPress: (nextKey: T) => void,
  ) {
    return (
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.detailTabsScrollContent}
      >
        <View style={styles.detailTabsRow}>
          {tabs.map(tab => {
            const isActive = tab.key === activeKey;
            return (
              <Pressable
                key={tab.key}
                onPress={() => onPress(tab.key)}
                style={styles.detailTabButton}
              >
                <Text
                  style={[
                    styles.detailTabText,
                    isActive && { color: tab.color, fontWeight: '600' },
                  ]}
                >
                  {tab.label}
                </Text>
                <View
                  style={[
                    styles.detailTabUnderline,
                    isActive && { backgroundColor: tab.color, opacity: 1 },
                  ]}
                />
              </Pressable>
            );
          })}
        </View>
      </ScrollView>
    );
  }

  function renderDetailSectionLabel(label: string) {
    return <Text style={styles.detailSectionLabel}>{label}</Text>;
  }

  function renderTextCard(items: string[], icon: keyof typeof Ionicons.glyphMap) {
    return (
      <View style={styles.detailListBlock}>
        {items.map((item, index) => (
          <View key={`${item}-${index}`} style={styles.detailListCard}>
            <View style={styles.detailListIconWrap}>
              <Ionicons name={icon} size={16} color={THEME.primaryText} />
            </View>
            <Text style={styles.detailListText}>{item}</Text>
          </View>
        ))}
      </View>
    );
  }

  function renderNewsCard(article: NewsArticle) {
    const category =
      NEWS_CATEGORIES.find(item => item.key === article.category) ??
      NEWS_CATEGORIES[0];

    return (
      <Pressable
        key={article.id}
        style={styles.detailNewsCard}
        onPress={() => openNewsDetail(article.id)}
      >
        <View style={styles.detailNewsBody}>
          <View style={styles.detailNewsBadgeRow}>
            <View
              style={[
                styles.detailNewsBadge,
                { backgroundColor: `${category.color}24` },
              ]}
            >
              <Text style={[styles.detailNewsBadgeText, { color: category.color }]}>
                {category.label}
              </Text>
            </View>
            <Text style={styles.detailNewsMetaText}>{article.source}</Text>
          </View>
          <Text style={styles.detailNewsTitle}>{article.title}</Text>
          <Text style={styles.detailNewsSummary}>{article.summary}</Text>
          <Text style={styles.detailNewsMetaText}>{article.publishedAt}</Text>
        </View>
        <View style={styles.detailNewsCover}>
          <LinearGradient
            colors={article.palette}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.detailNewsCoverFill}
          />
          <Ionicons
            name="newspaper-outline"
            size={20}
            color="rgba(255,255,255,0.78)"
          />
        </View>
      </Pressable>
    );
  }

  function renderLinkedEventCard(title: string, index: number) {
    const linkedEvent = findEventDetailByTitle(title);

    return (
      <Pressable
        key={`${title}-${index}`}
        style={styles.detailLinkedEventCard}
        disabled={!linkedEvent}
        onPress={() => {
          if (linkedEvent) {
            openEventDetail(linkedEvent.id);
          }
        }}
      >
        <LinearGradient
          colors={
            linkedEvent
              ? [linkedEvent.heroPalette[0], linkedEvent.heroPalette[1]]
              : ['#252833', '#14151A']
          }
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.detailLinkedEventThumb}
        >
          <Ionicons name="radio" size={18} color="rgba(255,255,255,0.86)" />
        </LinearGradient>
        <View style={styles.detailLinkedEventMeta}>
          <Text style={styles.detailLinkedEventTitle}>{title}</Text>
          <Text style={styles.detailLinkedEventSubtitle}>
            {linkedEvent?.location ?? '活动信息待补充'}
          </Text>
          <Text style={styles.detailLinkedEventSubtitle}>
            {linkedEvent?.schedule ?? '时间待补充'}
          </Text>
        </View>
        <Ionicons
          name="chevron-forward"
          size={16}
          color="rgba(255,255,255,0.46)"
        />
      </Pressable>
    );
  }

  function renderLinkedDJCard(name: string, index: number) {
    const linkedDJ = findDJDetailByName(name);

    return (
      <Pressable
        key={`${name}-${index}`}
        style={styles.detailLinkedEventCard}
        disabled={!linkedDJ}
        onPress={() => {
          if (linkedDJ) {
            openDJDetail(linkedDJ.id);
          }
        }}
      >
        <LinearGradient
          colors={
            linkedDJ
              ? [linkedDJ.heroPalette[0], linkedDJ.heroPalette[1]]
              : ['#252833', '#14151A']
          }
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.detailLinkedEventThumb}
        >
          <Ionicons name="person" size={18} color="rgba(255,255,255,0.86)" />
        </LinearGradient>
        <View style={styles.detailLinkedEventMeta}>
          <Text style={styles.detailLinkedEventTitle}>{name}</Text>
          <Text style={styles.detailLinkedEventSubtitle}>
            {linkedDJ?.subtitle ?? 'DJ 信息待补充'}
          </Text>
          <Text style={styles.detailLinkedEventSubtitle}>
            {linkedDJ?.genres.join(' / ') ?? '风格待补充'}
          </Text>
        </View>
        <Ionicons
          name="chevron-forward"
          size={16}
          color="rgba(255,255,255,0.46)"
        />
      </Pressable>
    );
  }

  function renderLinkedSetCard(title: string, index: number) {
    const linkedSet = SET_DETAILS.find(item => item.title === title);

    return (
      <Pressable
        key={`${title}-${index}`}
        style={styles.detailLinkedEventCard}
        disabled={!linkedSet}
        onPress={() => {
          if (linkedSet) {
            openSetDetail(linkedSet.id);
          }
        }}
      >
        <LinearGradient
          colors={
            linkedSet
              ? [linkedSet.heroPalette[0], linkedSet.heroPalette[1]]
              : ['#252833', '#14151A']
          }
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.detailLinkedEventThumb}
        >
          <Ionicons
            name="play-circle"
            size={18}
            color="rgba(255,255,255,0.86)"
          />
        </LinearGradient>
        <View style={styles.detailLinkedEventMeta}>
          <Text style={styles.detailLinkedEventTitle}>{title}</Text>
          <Text style={styles.detailLinkedEventSubtitle}>
            {linkedSet?.subtitle ?? 'Sets 信息待补充'}
          </Text>
          <Text style={styles.detailLinkedEventSubtitle}>
            {linkedSet
              ? `${linkedSet.duration} · ${linkedSet.bpm}`
              : '时长待补充'}
          </Text>
        </View>
        <Ionicons
          name="chevron-forward"
          size={16}
          color="rgba(255,255,255,0.46)"
        />
      </Pressable>
    );
  }

  function renderLinkedLabelCard(name: string, index: number) {
    const linkedLabel = findLabelDetailByName(name);

    return (
      <Pressable
        key={`${name}-${index}`}
        style={styles.detailLinkedEventCard}
        disabled={!linkedLabel}
        onPress={() => {
          if (linkedLabel) {
            openLabelDetail(linkedLabel.id);
          }
        }}
      >
        <LinearGradient
          colors={
            linkedLabel
              ? [linkedLabel.heroPalette[0], linkedLabel.heroPalette[1]]
              : ['#252833', '#14151A']
          }
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.detailLinkedEventThumb}
        >
          <Ionicons name="albums" size={18} color="rgba(255,255,255,0.86)" />
        </LinearGradient>
        <View style={styles.detailLinkedEventMeta}>
          <Text style={styles.detailLinkedEventTitle}>{name}</Text>
          <Text style={styles.detailLinkedEventSubtitle}>
            {linkedLabel?.subtitle ?? '厂牌信息待补充'}
          </Text>
          <Text style={styles.detailLinkedEventSubtitle}>
            {linkedLabel?.focus ?? '风格方向待补充'}
          </Text>
        </View>
        <Ionicons
          name="chevron-forward"
          size={16}
          color="rgba(255,255,255,0.46)"
        />
      </Pressable>
    );
  }

  function renderLinkedNewsCards(newsIDs: string[]) {
    return (
      <View style={styles.detailNewsList}>
        {newsIDs.map(newsID => {
          const article = findNewsArticleByID(newsID);

          if (!article) {
            return null;
          }

          return renderNewsCard(article);
        })}
      </View>
    );
  }

  function openRankingDetailTarget(entry: RankingBoardDetailEntry) {
    switch (entry.kind) {
      case 'event':
        openEventDetail(entry.targetId);
        break;
      case 'dj':
        openDJDetail(entry.targetId);
        break;
      case 'organizer':
        openOrganizerDetail(entry.targetId);
        break;
    }
  }

  function renderRankingBoardEntryCard(entry: RankingBoardDetailEntry) {
    return (
      <Pressable
        key={`${entry.title}-${entry.rank}`}
        style={styles.rankingDetailEntryCard}
        onPress={() => openRankingDetailTarget(entry)}
      >
        <View style={styles.rankingDetailEntryTopRow}>
          <View style={styles.rankingDetailRankPill}>
            <Text style={styles.rankingDetailRankText}>#{entry.rank}</Text>
          </View>
          <Text style={styles.rankingDetailDeltaText}>{entry.delta}</Text>
        </View>
        <View style={styles.rankingDetailEntryMainRow}>
          <LinearGradient
            colors={entry.palette}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.rankingDetailEntryThumb}
          />
          <View style={styles.rankingDetailEntryMeta}>
            <Text style={styles.rankingDetailEntryTitle}>{entry.title}</Text>
            <Text style={styles.rankingDetailEntrySubtitle}>{entry.subtitle}</Text>
            <Text style={styles.rankingDetailEntryNote}>{entry.note}</Text>
          </View>
          <View style={styles.rankingDetailScoreWrap}>
            <Text style={styles.rankingDetailScoreText}>{entry.score}</Text>
          </View>
        </View>
      </Pressable>
    );
  }

  function renderRankingBoardDetailContent(detail: RankingBoardDetailData) {
    switch (rankingBoardDetailTab) {
      case 'overview':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('榜单概览')}
            <View style={styles.detailDescriptionCard}>
              <Text style={styles.detailDescriptionText}>{detail.summary}</Text>
            </View>
            <View style={styles.detailMetricsRow}>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>更新时间</Text>
                <Text style={styles.detailMetricValueSmall}>{detail.updatedAt}</Text>
              </View>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>采样范围</Text>
                <Text style={styles.detailMetricValueSmall}>{detail.scope}</Text>
              </View>
            </View>
            {renderDetailSectionLabel('当前快照')}
            {renderTextCard(detail.snapshot, 'bar-chart-outline')}
            {renderDetailSectionLabel('趋势观察')}
            {renderTextCard(detail.trends, 'trending-up-outline')}
          </View>
        );
      case 'top':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('榜单 Top')}
            <View style={styles.rankingDetailEntryList}>
              {detail.entries.map(entry => renderRankingBoardEntryCard(entry))}
            </View>
          </View>
        );
      case 'dimensions':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('评分维度')}
            <View style={styles.rankingDimensionList}>
              {detail.dimensions.map(item => (
                <View key={item.label} style={styles.rankingDimensionCard}>
                  <View style={styles.rankingDimensionTopRow}>
                    <Text style={styles.rankingDimensionLabel}>{item.label}</Text>
                    <Text style={styles.rankingDimensionWeight}>{item.weight}</Text>
                  </View>
                  <Text style={styles.rankingDimensionNote}>{item.note}</Text>
                </View>
              ))}
            </View>
          </View>
        );
      case 'method':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('计算方法')}
            {renderTextCard(detail.methodology, 'analytics-outline')}
          </View>
        );
    }
  }

  function renderDetailHero(
    palette: [string, string, string],
    eyebrow: string,
    title: string,
    subtitle: string,
    lines: string[],
    chips: string[],
  ) {
    return (
      <View style={[styles.detailHero, { height: detailHeroHeight }]}>
        <LinearGradient
          colors={palette}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.detailHeroFill}
        />
        <View style={styles.detailHeroGlowPrimary} />
        <View style={styles.detailHeroGlowSecondary} />
        <LinearGradient
          colors={[
            'rgba(0,0,0,0.02)',
            'rgba(0,0,0,0.22)',
            'rgba(0,0,0,0.74)',
            '#08080A',
          ]}
          locations={[0, 0.38, 0.78, 1]}
          style={styles.detailHeroShade}
        />
        <View
          style={[
            styles.detailHeroMeta,
            {
              paddingTop: detailTopInset + 46,
              paddingHorizontal: detailHorizontalPadding,
            },
          ]}
        >
          <View style={styles.detailHeroEyebrow}>
            <Text style={styles.detailHeroEyebrowText}>{eyebrow}</Text>
          </View>
          <Text style={styles.detailHeroTitle}>{title}</Text>
          <Text style={styles.detailHeroSubtitle}>{subtitle}</Text>
          <View style={styles.detailHeroLineGroup}>
            {lines.map(line => (
              <Text key={line} style={styles.detailHeroLineText}>
                {line}
              </Text>
            ))}
          </View>
          <View style={styles.detailHeroChipRow}>
            {chips.map(chip => (
              <View key={chip} style={styles.detailHeroChip}>
                <Text style={styles.detailHeroChipText}>{chip}</Text>
              </View>
            ))}
          </View>
        </View>
      </View>
    );
  }

  function renderEventDetailContent(detail: EventDetailData) {
    const addon = EVENT_DETAIL_ADDONS[detail.id];

    switch (eventDetailTab) {
      case 'info':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('活动信息')}
            <View style={styles.detailMetricsRow}>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>开始时间</Text>
                <Text style={styles.detailMetricValue}>23:00</Text>
              </View>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>阵容人数</Text>
                <Text style={styles.detailMetricValue}>{detail.lineup.length} 位</Text>
              </View>
            </View>

            <View style={styles.detailInfoCard}>
              <View style={styles.detailInfoRow}>
                <Text style={styles.detailInfoLabel}>活动地点</Text>
                <Text style={styles.detailInfoValue}>{detail.location}</Text>
              </View>
              <View style={styles.detailInfoDivider} />
              <View style={styles.detailInfoRow}>
                <Text style={styles.detailInfoLabel}>活动时间</Text>
                <Text style={styles.detailInfoValue}>{detail.schedule}</Text>
              </View>
              <View style={styles.detailInfoDivider} />
              <Pressable
                style={styles.detailInfoRow}
                onPress={() => openOrganizerDetail(detail.organizerId)}
              >
                <Text style={styles.detailInfoLabel}>主办方</Text>
                <View style={styles.detailInfoActionWrap}>
                  <Text style={styles.detailInfoValue}>{detail.organizerName}</Text>
                  <Ionicons
                    name="chevron-forward"
                    size={15}
                    color="rgba(255,255,255,0.44)"
                  />
                </View>
              </Pressable>
            </View>

            {renderDetailSectionLabel('活动简介')}
            <View style={styles.detailDescriptionCard}>
              <Text style={styles.detailDescriptionText}>{detail.description}</Text>
            </View>
            <View style={styles.detailMetricsRow}>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>检票时间</Text>
                <Text style={styles.detailMetricValueSmall}>{addon.doorTime}</Text>
              </View>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>建议到场</Text>
                <Text style={styles.detailMetricValueSmall}>
                  {addon.travelWindow}
                </Text>
              </View>
            </View>
            <View style={styles.detailInfoCard}>
              <View style={styles.detailInfoRow}>
                <Text style={styles.detailInfoLabel}>人群画像</Text>
                <Text style={styles.detailInfoValue}>{addon.audienceProfile}</Text>
              </View>
            </View>
            {renderDetailSectionLabel('氛围标签')}
            <View style={styles.detailChipCloud}>
              {addon.vibeTags.map(tag => (
                <View key={tag} style={styles.detailCloudChip}>
                  <Text style={styles.detailCloudChipText}>{tag}</Text>
                </View>
              ))}
            </View>
            {renderDetailSectionLabel('相关厂牌')}
            <View style={styles.detailLinkedEventList}>
              {addon.labelSpotlights.map((name, index) =>
                renderLinkedLabelCard(name, index),
              )}
            </View>
            {renderDetailSectionLabel('到场提示')}
            {renderTextCard(addon.venueTips, 'navigate-outline')}
            {renderDetailSectionLabel('票务与规则')}
            {renderTextCard(addon.ticketTips, 'ticket-outline')}
          </View>
        );
      case 'lineup':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('阵容')}
            <View style={styles.detailLineupList}>
              {detail.lineup.map(dj => (
                <Pressable
                  key={dj.id}
                  style={styles.detailLineupCard}
                  onPress={() => openDJDetail(dj.id)}
                >
                  <LinearGradient
                    colors={dj.palette}
                    start={{ x: 0, y: 0 }}
                    end={{ x: 1, y: 1 }}
                    style={styles.detailLineupAvatar}
                  >
                    <Text style={styles.detailLineupAvatarText}>{dj.monogram}</Text>
                  </LinearGradient>
                  <View style={styles.detailLineupMeta}>
                    <Text style={styles.detailLineupName}>{dj.name}</Text>
                    <Text style={styles.detailLineupSubtext}>
                      {dj.country} · {dj.city}
                    </Text>
                    <Text style={styles.detailLineupSubtext}>
                      {dj.genres.join(' / ')}
                    </Text>
                  </View>
                  <Ionicons
                    name="chevron-forward"
                    size={16}
                    color="rgba(255,255,255,0.46)"
                  />
                </Pressable>
              ))}
            </View>
          </View>
        );
      case 'schedule':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('时间表')}
            <View style={styles.detailScheduleList}>
              {detail.scheduleSlots.map((slot, index) => (
                <Pressable
                  key={`${slot.time}-${slot.artistId}-${index}`}
                  style={styles.detailScheduleCard}
                  onPress={() => openDJDetail(slot.artistId)}
                >
                  <View style={styles.detailScheduleTimeBlock}>
                    <Text style={styles.detailScheduleTime}>{slot.time}</Text>
                    <Text style={styles.detailScheduleStage}>{slot.stage}</Text>
                  </View>
                  <View style={styles.detailScheduleMeta}>
                    <Text style={styles.detailScheduleArtist}>{slot.artistName}</Text>
                    <Text style={styles.detailScheduleHint}>点击查看 DJ 详情</Text>
                  </View>
                  <Ionicons
                    name="chevron-forward"
                    size={16}
                    color="rgba(255,255,255,0.46)"
                  />
                </Pressable>
              ))}
            </View>
          </View>
        );
      case 'news':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('相关新闻')}
            <View style={styles.detailNewsList}>
              {detail.news.map(article => renderNewsCard(article))}
            </View>
          </View>
        );
      case 'posts':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('活动动态')}
            {renderTextCard(detail.posts, 'chatbubble-ellipses-outline')}
          </View>
        );
      case 'ratings':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('活动打分')}
            <View style={styles.detailRatingsGrid}>
              {detail.ratings.map((item, index) => (
                <View key={`${item}-${index}`} style={styles.detailRatingCard}>
                  <Text style={styles.detailRatingText}>{item}</Text>
                </View>
              ))}
            </View>
          </View>
        );
      case 'sets':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('关联 Sets')}
            <View style={styles.detailLinkedEventList}>
              {detail.sets.map((title, index) => renderLinkedSetCard(title, index))}
            </View>
          </View>
        );
    }
  }

  function renderDJDetailContent(detail: DJDetailData) {
    const addon = DJ_DETAIL_ADDONS[detail.id];

    switch (djDetailTab) {
      case 'intro':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('DJ 简介')}
            <View style={styles.detailMetricsRow}>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>国家</Text>
                <Text style={styles.detailMetricValue}>{detail.country}</Text>
              </View>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>城市</Text>
                <Text style={styles.detailMetricValue}>{detail.city}</Text>
              </View>
            </View>
            <View style={styles.detailDescriptionCard}>
              <Text style={styles.detailDescriptionText}>{detail.bio}</Text>
            </View>
            <View style={styles.detailInfoCard}>
              <View style={styles.detailInfoRow}>
                <Text style={styles.detailInfoLabel}>擅长时段</Text>
                <Text style={styles.detailInfoValue}>{addon.slotFocus}</Text>
              </View>
              <View style={styles.detailInfoDivider} />
              <View style={styles.detailInfoRow}>
                <Text style={styles.detailInfoLabel}>巡演路线</Text>
                <Text style={styles.detailInfoValue}>{addon.route}</Text>
              </View>
              <View style={styles.detailInfoDivider} />
              <View style={styles.detailInfoRow}>
                <Text style={styles.detailInfoLabel}>推进节奏</Text>
                <Text style={styles.detailInfoValue}>{addon.pace}</Text>
              </View>
            </View>
            {renderDetailSectionLabel('风格')}
            <View style={styles.detailChipCloud}>
              {detail.genres.map(genre => (
                <View key={genre} style={styles.detailCloudChip}>
                  <Text style={styles.detailCloudChipText}>{genre}</Text>
                </View>
              ))}
            </View>
            {renderDetailSectionLabel('风格细节')}
            {renderTextCard(addon.styleNotes, 'pulse-outline')}
            {renderDetailSectionLabel('关联厂牌')}
            <View style={styles.detailLinkedEventList}>
              {addon.labels.map((label, index) => renderLinkedLabelCard(label, index))}
            </View>
            {renderDetailSectionLabel('荣誉')}
            {renderTextCard(detail.honors, 'trophy-outline')}
          </View>
        );
      case 'events':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('关联活动')}
            <View style={styles.detailLinkedEventList}>
              {detail.upcomingEvents.map((title, index) =>
                renderLinkedEventCard(title, index),
              )}
            </View>
          </View>
        );
      case 'ratings':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('关联打分')}
            <View style={styles.detailRatingsGrid}>
              {detail.ratings.map((item, index) => (
                <View key={`${item}-${index}`} style={styles.detailRatingCard}>
                  <Text style={styles.detailRatingText}>{item}</Text>
                </View>
              ))}
            </View>
          </View>
        );
      case 'posts':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('DJ 动态')}
            {renderTextCard(detail.posts, 'sparkles-outline')}
            {renderDetailSectionLabel('相关资讯')}
            {renderLinkedNewsCards(addon.relatedNewsIDs)}
          </View>
        );
      case 'sets':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('DJ Sets')}
            <View style={styles.detailLinkedEventList}>
              {detail.sets.map((title, index) => renderLinkedSetCard(title, index))}
            </View>
            {renderDetailSectionLabel('适合场景')}
            {renderTextCard(addon.listeningMoments, 'headset-outline')}
          </View>
        );
    }
  }

  function renderOrganizerDetailContent(detail: OrganizerDetailData) {
    const addon = ORGANIZER_DETAIL_ADDONS[detail.id];

    switch (organizerDetailTab) {
      case 'basic':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('主办方信息')}
            <View style={styles.detailMetricsRow}>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>成立年份</Text>
                <Text style={styles.detailMetricValue}>{detail.foundedYear}</Text>
              </View>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>活动频率</Text>
                <Text style={styles.detailMetricValue}>{detail.frequency}</Text>
              </View>
            </View>
            <View style={styles.detailInfoCard}>
              <View style={styles.detailInfoRow}>
                <Text style={styles.detailInfoLabel}>国家</Text>
                <Text style={styles.detailInfoValue}>{detail.country}</Text>
              </View>
              <View style={styles.detailInfoDivider} />
              <View style={styles.detailInfoRow}>
                <Text style={styles.detailInfoLabel}>城市</Text>
                <Text style={styles.detailInfoValue}>{detail.city}</Text>
              </View>
            </View>
            <View style={styles.detailDescriptionCard}>
              <Text style={styles.detailDescriptionText}>{detail.intro}</Text>
            </View>
            {renderDetailSectionLabel('品牌风格')}
            <View style={styles.detailDescriptionCard}>
              <Text style={styles.detailDescriptionText}>
                {addon.signatureStyle}
              </Text>
            </View>
            <View style={styles.detailInfoCard}>
              <View style={styles.detailInfoRow}>
                <Text style={styles.detailInfoLabel}>受众画像</Text>
                <Text style={styles.detailInfoValue}>{addon.audienceProfile}</Text>
              </View>
            </View>
            {renderDetailSectionLabel('覆盖城市')}
            <View style={styles.detailChipCloud}>
              {addon.coverageCities.map(city => (
                <View key={city} style={styles.detailCloudChip}>
                  <Text style={styles.detailCloudChipText}>{city}</Text>
                </View>
              ))}
            </View>
            {renderDetailSectionLabel('关注厂牌')}
            <View style={styles.detailLinkedEventList}>
              {addon.focusLabels.map((name, index) =>
                renderLinkedLabelCard(name, index),
              )}
            </View>
          </View>
        );
      case 'events':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('主办活动')}
            <View style={styles.detailLinkedEventList}>
              {detail.events.map((title, index) => renderLinkedEventCard(title, index))}
            </View>
          </View>
        );
      case 'posts':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('品牌动态')}
            {renderTextCard(detail.posts, 'megaphone-outline')}
            {renderDetailSectionLabel('制作观察')}
            {renderTextCard(addon.productionNotes, 'construct-outline')}
            {renderDetailSectionLabel('相关资讯')}
            {renderLinkedNewsCards(addon.relatedNewsIDs)}
          </View>
        );
    }
  }

  function renderNewsDetailContent(detail: NewsDetailData) {
    const addon = NEWS_DETAIL_ADDONS[detail.id];

    switch (newsDetailTab) {
      case 'article':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('文章正文')}
            <View style={styles.detailDescriptionCard}>
              {detail.body.map((paragraph, index) => (
                <Text
                  key={`${detail.id}-paragraph-${index}`}
                  style={[
                    styles.detailDescriptionText,
                    index > 0 && styles.detailParagraphSpacing,
                  ]}
                >
                  {paragraph}
                </Text>
              ))}
            </View>
            {renderDetailSectionLabel('关键信息')}
            {renderTextCard(addon.keyTakeaways, 'sparkles-outline')}
            {renderDetailSectionLabel('涉及场景')}
            <View style={styles.detailChipCloud}>
              {addon.involvedScenes.map(scene => (
                <View key={scene} style={styles.detailCloudChip}>
                  <Text style={styles.detailCloudChipText}>{scene}</Text>
                </View>
              ))}
            </View>
          </View>
        );
      case 'events':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('关联活动')}
            <View style={styles.detailLinkedEventList}>
              {detail.relatedEvents.map((title, index) =>
                renderLinkedEventCard(title, index),
              )}
            </View>
            {renderDetailSectionLabel('延伸阅读')}
            {renderLinkedNewsCards(findRelatedNewsIDs(detail.id, detail.category))}
          </View>
        );
      case 'discussion':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('讨论点')}
            {renderTextCard(detail.discussion, 'chatbubbles-outline')}
            {renderDetailSectionLabel('编辑注记')}
            {renderTextCard(addon.editorNotes, 'create-outline')}
          </View>
        );
    }
  }

  function renderLabelDetailContent(detail: LabelDetailData) {
    const addon = LABEL_DETAIL_ADDONS[detail.id];

    switch (labelDetailTab) {
      case 'basic':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('厂牌信息')}
            <View style={styles.detailMetricsRow}>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>成立年份</Text>
                <Text style={styles.detailMetricValue}>{detail.foundedYear}</Text>
              </View>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>核心方向</Text>
                <Text style={styles.detailMetricValueSmall}>{detail.focus}</Text>
              </View>
            </View>
            <View style={styles.detailInfoCard}>
              <View style={styles.detailInfoRow}>
                <Text style={styles.detailInfoLabel}>国家</Text>
                <Text style={styles.detailInfoValue}>{detail.country}</Text>
              </View>
              <View style={styles.detailInfoDivider} />
              <View style={styles.detailInfoRow}>
                <Text style={styles.detailInfoLabel}>城市</Text>
                <Text style={styles.detailInfoValue}>{detail.city}</Text>
              </View>
            </View>
            <View style={styles.detailDescriptionCard}>
              <Text style={styles.detailDescriptionText}>{detail.intro}</Text>
            </View>
            {renderDetailSectionLabel('声音关键词')}
            <View style={styles.detailChipCloud}>
              {addon.signatureKeywords.map(item => (
                <View key={item} style={styles.detailCloudChip}>
                  <Text style={styles.detailCloudChipText}>{item}</Text>
                </View>
              ))}
            </View>
            {renderDetailSectionLabel('核心城市')}
            <View style={styles.detailChipCloud}>
              {addon.keyCities.map(city => (
                <View key={city} style={styles.detailCloudChip}>
                  <Text style={styles.detailCloudChipText}>{city}</Text>
                </View>
              ))}
            </View>
          </View>
        );
      case 'djs':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('关联 DJ')}
            <View style={styles.detailLinkedEventList}>
              {detail.featuredDJs.map((name, index) =>
                renderLinkedDJCard(name, index),
              )}
            </View>
          </View>
        );
      case 'releases':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('代表发行')}
            {renderTextCard(detail.releases, 'disc-outline')}
            {renderDetailSectionLabel('相关 Sets')}
            <View style={styles.detailLinkedEventList}>
              {addon.relatedSets.map((title, index) => renderLinkedSetCard(title, index))}
            </View>
          </View>
        );
      case 'posts':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('厂牌动态')}
            {renderTextCard(detail.posts, 'megaphone-outline')}
            {renderDetailSectionLabel('策展方向')}
            {renderTextCard(addon.curationNotes, 'albums-outline')}
            {renderDetailSectionLabel('相关新闻')}
            {renderLinkedNewsCards(addon.relatedNewsIDs)}
          </View>
        );
    }
  }

  function renderSetDetailContent(detail: SetDetailData) {
    const addon = SET_DETAIL_ADDONS[detail.id];

    switch (setDetailTab) {
      case 'basic':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('Sets 信息')}
            <View style={styles.detailMetricsRow}>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>时长</Text>
                <Text style={styles.detailMetricValue}>{detail.duration}</Text>
              </View>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>速度</Text>
                <Text style={styles.detailMetricValue}>{detail.bpm}</Text>
              </View>
            </View>
            <View style={styles.detailInfoCard}>
              <Pressable
                style={styles.detailInfoRow}
                onPress={() => openDJDetail(detail.djId)}
              >
                <Text style={styles.detailInfoLabel}>DJ</Text>
                <View style={styles.detailInfoActionWrap}>
                  <Text style={styles.detailInfoValue}>{detail.djName}</Text>
                  <Ionicons
                    name="chevron-forward"
                    size={15}
                    color="rgba(255,255,255,0.44)"
                  />
                </View>
              </Pressable>
              <View style={styles.detailInfoDivider} />
              <View style={styles.detailInfoRow}>
                <Text style={styles.detailInfoLabel}>风格</Text>
                <Text style={styles.detailInfoValue}>{detail.style}</Text>
              </View>
            </View>
            <View style={styles.detailDescriptionCard}>
              <Text style={styles.detailDescriptionText}>{detail.description}</Text>
            </View>
            <View style={styles.detailInfoCard}>
              <View style={styles.detailInfoRow}>
                <Text style={styles.detailInfoLabel}>录音来源</Text>
                <Text style={styles.detailInfoValue}>{addon.recordingSource}</Text>
              </View>
              <View style={styles.detailInfoDivider} />
              <View style={styles.detailInfoRow}>
                <Text style={styles.detailInfoLabel}>结构概览</Text>
                <Text style={styles.detailInfoValue}>
                  {addon.structureSummary}
                </Text>
              </View>
            </View>
          </View>
        );
      case 'tracks':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('结构亮点')}
            {renderTextCard(detail.trackHighlights, 'pulse-outline')}
            {renderDetailSectionLabel('听感笔记')}
            {renderTextCard(detail.notes, 'ear-outline')}
            {renderDetailSectionLabel('章节观察')}
            {renderTextCard(addon.chapterNotes, 'musical-notes-outline')}
            {renderDetailSectionLabel('关联资讯')}
            {renderLinkedNewsCards(addon.relatedNewsIDs)}
          </View>
        );
      case 'event':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('关联活动')}
            <View style={styles.detailLinkedEventList}>
              {renderLinkedEventCard(detail.eventTitle, 0)}
            </View>
            {renderDetailSectionLabel('适合场景')}
            {renderTextCard(addon.idealScenes, 'radio-outline')}
            {renderDetailSectionLabel('关联厂牌')}
            <View style={styles.detailLinkedEventList}>
              {addon.relatedLabels.map((name, index) =>
                renderLinkedLabelCard(name, index),
              )}
            </View>
          </View>
        );
    }
  }

  function renderGenreDetailContent(detail: GenreDetailData) {
    const addon = GENRE_DETAIL_ADDONS[detail.id];

    switch (genreDetailTab) {
      case 'overview':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('流派概览')}
            <View style={styles.detailMetricsRow}>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>适合时段</Text>
                <Text style={styles.detailMetricValueSmall}>{detail.energy}</Text>
              </View>
              <View style={styles.detailMetricCard}>
                <Text style={styles.detailMetricLabel}>场景</Text>
                <Text style={styles.detailMetricValueSmall}>{detail.scene}</Text>
              </View>
            </View>
            <View style={styles.detailDescriptionCard}>
              <Text style={styles.detailDescriptionText}>
                {detail.description}
              </Text>
            </View>
            <View style={styles.detailInfoCard}>
              <View style={styles.detailInfoRow}>
                <Text style={styles.detailInfoLabel}>常见速度</Text>
                <Text style={styles.detailInfoValue}>{addon.tempoRange}</Text>
              </View>
            </View>
            {renderDetailSectionLabel('情绪关键词')}
            <View style={styles.detailChipCloud}>
              {addon.moodKeywords.map(keyword => (
                <View key={keyword} style={styles.detailCloudChip}>
                  <Text style={styles.detailCloudChipText}>{keyword}</Text>
                </View>
              ))}
            </View>
            {renderDetailSectionLabel('代表厂牌')}
            <View style={styles.detailLinkedEventList}>
              {addon.relatedLabels.map((name, index) =>
                renderLinkedLabelCard(name, index),
              )}
            </View>
          </View>
        );
      case 'djs':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('推荐 DJ')}
            <View style={styles.detailLinkedEventList}>
              {detail.relatedDJs.map((name, index) =>
                renderLinkedDJCard(name, index),
              )}
            </View>
          </View>
        );
      case 'events':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('关联活动')}
            <View style={styles.detailLinkedEventList}>
              {detail.relatedEvents.map((title, index) =>
                renderLinkedEventCard(title, index),
              )}
            </View>
          </View>
        );
      case 'notes':
        return (
          <View style={styles.detailSectionGroup}>
            {renderDetailSectionLabel('听感与场景')}
            {renderTextCard(detail.listeningNotes, 'headset-outline')}
            {renderDetailSectionLabel('常见时段')}
            {renderTextCard(addon.commonSlots, 'time-outline')}
            {renderDetailSectionLabel('入门 Sets')}
            <View style={styles.detailLinkedEventList}>
              {addon.entrySets.map((title, index) => renderLinkedSetCard(title, index))}
            </View>
          </View>
        );
    }
  }

  function renderDetailOverlay() {
    if (!activeDetail) {
      return null;
    }

    let heroNode: React.ReactNode = null;
    let tabNode: React.ReactNode = null;
    let contentNode: React.ReactNode = null;

    switch (activeDetail.kind) {
      case 'event': {
        const detail = activeDetail.item;
        heroNode = renderDetailHero(
          detail.heroPalette,
          'EVENT',
          detail.title,
          detail.subtitle,
          [detail.location, detail.schedule],
          [detail.organizerName, `${detail.lineup.length} 位 DJ`],
        );
        tabNode = renderDetailTabs(
          EVENT_DETAIL_TABS,
          eventDetailTab,
          setEventDetailTab,
        );
        contentNode = renderEventDetailContent(detail);
        break;
      }
      case 'dj': {
        const detail = activeDetail.item;
        heroNode = renderDetailHero(
          detail.heroPalette,
          'DJ PROFILE',
          detail.name,
          detail.subtitle,
          [`${detail.country} · ${detail.city}`, detail.genres.join(' / ')],
          ['Raver DJ', `${detail.upcomingEvents.length} 场关联活动`],
        );
        tabNode = renderDetailTabs(DJ_DETAIL_TABS, djDetailTab, setDjDetailTab);
        contentNode = renderDJDetailContent(detail);
        break;
      }
      case 'organizer': {
        const detail = activeDetail.item;
        heroNode = renderDetailHero(
          detail.heroPalette,
          'ORGANIZER',
          detail.name,
          detail.subtitle,
          [`${detail.country} · ${detail.city}`, `成立于 ${detail.foundedYear}`],
          [detail.frequency, `${detail.events.length} 场关联活动`],
        );
        tabNode = renderDetailTabs(
          ORGANIZER_DETAIL_TABS,
          organizerDetailTab,
          setOrganizerDetailTab,
        );
        contentNode = renderOrganizerDetailContent(detail);
        break;
      }
      case 'news': {
        const detail = activeDetail.item;
        const category =
          NEWS_CATEGORIES.find(item => item.key === detail.category) ??
          NEWS_CATEGORIES[0];
        heroNode = renderDetailHero(
          detail.heroPalette,
          'NEWS',
          detail.title,
          detail.source,
          [detail.summary, detail.publishedAt],
          [category.label, `${detail.relatedEvents.length} 场关联活动`],
        );
        tabNode = renderDetailTabs(
          NEWS_DETAIL_TABS,
          newsDetailTab,
          setNewsDetailTab,
        );
        contentNode = renderNewsDetailContent(detail);
        break;
      }
      case 'label': {
        const detail = activeDetail.item;
        heroNode = renderDetailHero(
          detail.heroPalette,
          'LABEL',
          detail.name,
          detail.subtitle,
          [`${detail.country} · ${detail.city}`, `成立于 ${detail.foundedYear}`],
          [detail.focus, `${detail.featuredDJs.length} 位关联 DJ`],
        );
        tabNode = renderDetailTabs(
          LABEL_DETAIL_TABS,
          labelDetailTab,
          setLabelDetailTab,
        );
        contentNode = renderLabelDetailContent(detail);
        break;
      }
      case 'set': {
        const detail = activeDetail.item;
        heroNode = renderDetailHero(
          detail.heroPalette,
          'SETS',
          detail.title,
          detail.subtitle,
          [`${detail.duration} · ${detail.bpm}`, `${detail.djName} · ${detail.style}`],
          [detail.eventTitle, '现场录音 / 回放'],
        );
        tabNode = renderDetailTabs(
          SET_DETAIL_TABS,
          setDetailTab,
          setSetDetailTab,
        );
        contentNode = renderSetDetailContent(detail);
        break;
      }
      case 'genre': {
        const detail = activeDetail.item;
        heroNode = renderDetailHero(
          detail.heroPalette,
          'GENRE',
          detail.name,
          detail.subtitle,
          [detail.energy, detail.scene],
          [`${detail.relatedDJs.length} 位关联 DJ`, `${detail.relatedEvents.length} 场关联活动`],
        );
        tabNode = renderDetailTabs(
          GENRE_DETAIL_TABS,
          genreDetailTab,
          setGenreDetailTab,
        );
        contentNode = renderGenreDetailContent(detail);
        break;
      }
      case 'rankingBoard': {
        const detail = activeDetail.item;
        heroNode = renderDetailHero(
          detail.heroPalette,
          'RANKING',
          detail.title,
          detail.subtitle,
          [detail.scope, detail.updatedAt],
          [`${detail.entries.length} 条核心席位`, '近 14 天热度综合'],
        );
        tabNode = renderDetailTabs(
          RANKING_BOARD_DETAIL_TABS,
          rankingBoardDetailTab,
          setRankingBoardDetailTab,
        );
        contentNode = renderRankingBoardDetailContent(detail);
        break;
      }
    }

    return (
      <Modal
        transparent={false}
        presentationStyle="fullScreen"
        visible={!!activeDetail}
        animationType="slide"
        onRequestClose={goBackDetail}
      >
        <View style={styles.detailModalRoot}>
          <StatusBar style="light" />
          <ScrollView
            stickyHeaderIndices={[1]}
            showsVerticalScrollIndicator={false}
            contentContainerStyle={{ paddingBottom: detailBottomPadding }}
          >
            {heroNode}
            <View style={styles.detailStickyTabsShell}>{tabNode}</View>
            <View
              style={[
                styles.detailContentWrap,
                { paddingHorizontal: detailHorizontalPadding },
              ]}
            >
              {contentNode}
            </View>
          </ScrollView>

          <View
            pointerEvents="box-none"
            style={[
              styles.detailTopChrome,
              {
                top: detailTopInset,
                left: detailHorizontalPadding,
                right: detailHorizontalPadding,
              },
            ]}
          >
            <Pressable style={styles.detailChromeButton} onPress={goBackDetail}>
              <Ionicons name="chevron-back" size={18} color="#FFFFFF" />
            </Pressable>
            <Pressable style={styles.detailChromeButton} onPress={closeDetail}>
              <Ionicons
                name="ellipsis-horizontal"
                size={18}
                color="#FFFFFF"
              />
            </Pressable>
          </View>
        </View>
      </Modal>
    );
  }

  function renderSectionPlaceholder(section: DiscoverSection) {
    return (
      <View style={styles.sectionPlaceholder}>
        <View
          style={[
            styles.sectionPlaceholderAccent,
            { backgroundColor: section.color },
          ]}
        />
        <Text style={styles.sectionPlaceholderTitle}>{section.label}</Text>
        <Text style={styles.sectionPlaceholderBody}>
          这一栏先把分页结构、字重、间距和指示线对齐到 iOS 版，接下来再逐块补真实内容。
        </Text>
      </View>
    );
  }

  function renderPlaceholder(title: string, description: string, accent: string) {
    return (
      <View style={styles.placeholderScreen}>
        <View style={[styles.placeholderAccent, { backgroundColor: accent }]} />
        <Text style={styles.placeholderTitle}>{title}</Text>
        <Text style={styles.placeholderDescription}>{description}</Text>
      </View>
    );
  }

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar style="light" />
      <View style={styles.screen}>
        {currentScreen}
        {renderDetailOverlay()}

        <View style={[styles.bottomBarOuter, { bottom: bottomBarInset }]}>
          <SafeBlurView intensity={22} tint="dark" style={styles.bottomBarBlur}>
            <LinearGradient
              colors={[THEME.tabBarChromeStart, THEME.tabBarChromeEnd]}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.bottomBarGradient}
            >
              <View style={styles.bottomBarStroke} />
              <Animated.View
                pointerEvents="none"
                style={[
                  styles.bottomActivePill,
                  {
                    transform: [{ translateX: bottomPillX }],
                    width: bottomPillWidth,
                  },
                ]}
              >
                <LinearGradient
                  colors={[
                    THEME.tabBarSelectionStart,
                    THEME.tabBarSelectionEnd,
                  ]}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={styles.bottomActivePillFill}
                />
              </Animated.View>

              <View style={styles.bottomBarContent}>
                {MAIN_TABS.map(tab => {
                  const isActive = mainTab === tab.key;
                  const iconName = isActive ? tab.activeIcon : tab.icon;

                  if (tab.key === 'inbox') {
                    return (
                      <React.Fragment key={tab.key}>
                        <View style={styles.searchSlot}>
                          <LinearGradient
                            colors={[THEME.accent, '#5238E5']}
                            start={{ x: 0, y: 0 }}
                            end={{ x: 1, y: 1 }}
                            style={styles.searchButtonRing}
                          >
                            <Pressable
                              onPress={openSearch}
                              style={styles.searchButton}
                            >
                              <Ionicons
                                name="search"
                                size={22}
                                color={THEME.primaryText}
                              />
                            </Pressable>
                          </LinearGradient>
                        </View>

                        <Pressable
                          onLayout={event => {
                            bottomLayouts[tab.key] = {
                              x: event.nativeEvent.layout.x,
                              width: event.nativeEvent.layout.width,
                            };
                            if (tab.key === mainTab) {
                              animateBottomSelection(tab.key);
                            }
                          }}
                          onPress={() => handleMainTabChange(tab.key)}
                          style={styles.bottomTabButton}
                        >
                          <View style={styles.bottomTabInner}>
                            <View style={styles.bottomIconWrap}>
                              <Ionicons
                                name={iconName}
                                size={18}
                                color={
                                  isActive
                                    ? THEME.primaryText
                                    : THEME.secondaryText
                                }
                              />
                              <View style={styles.unreadBadge}>
                                <Text style={styles.unreadBadgeText}>3</Text>
                              </View>
                            </View>
                            <Text
                              style={[
                                styles.bottomTabLabel,
                                isActive && styles.bottomTabLabelActive,
                              ]}
                            >
                              {tab.label}
                            </Text>
                          </View>
                        </Pressable>
                      </React.Fragment>
                    );
                  }

                  return (
                    <Pressable
                      key={tab.key}
                      onLayout={event => {
                        bottomLayouts[tab.key] = {
                          x: event.nativeEvent.layout.x,
                          width: event.nativeEvent.layout.width,
                        };
                        if (tab.key === mainTab) {
                          animateBottomSelection(tab.key);
                        }
                      }}
                      onPress={() => handleMainTabChange(tab.key)}
                      style={styles.bottomTabButton}
                    >
                      <View style={styles.bottomTabInner}>
                        <View style={styles.bottomIconWrap}>
                          <Ionicons
                            name={iconName}
                            size={18}
                            color={
                              isActive ? THEME.primaryText : THEME.secondaryText
                            }
                          />
                        </View>
                        <Text
                          style={[
                            styles.bottomTabLabel,
                            isActive && styles.bottomTabLabelActive,
                          ]}
                        >
                          {tab.label}
                        </Text>
                      </View>
                    </Pressable>
                  );
                })}
              </View>
            </LinearGradient>
          </SafeBlurView>
        </View>

        <Modal
          transparent
          visible={isSearchMounted}
          animationType="none"
          onRequestClose={closeSearch}
        >
          <Animated.View style={[styles.searchOverlay, { opacity: overlayOpacity }]}>
            <Pressable style={styles.searchBackdrop} onPress={closeSearch} />
            <Animated.View
              style={[
                styles.searchSheet,
                {
                  transform: [{ scale: overlayScale }],
                  opacity: overlayOpacity,
                },
              ]}
            >
              <Text style={styles.searchSheetTitle}>全站搜索入口</Text>
              <Text style={styles.searchSheetBody}>
                点击这里可以搜索历史活动，以及活动相关的 DJ、资讯、Sets、榜单、打分、动态、品牌和厂牌信息。
              </Text>
              <View style={styles.searchFieldMock}>
                <Ionicons
                  name="search"
                  size={16}
                  color={THEME.secondaryText}
                />
                <Text style={styles.searchFieldText}>
                  搜索活动、DJ、资讯、Sets...
                </Text>
              </View>
              <Pressable onPress={closeSearch} style={styles.searchPrimaryButton}>
                <Text style={styles.searchPrimaryButtonText}>开始搜索</Text>
              </Pressable>
            </Animated.View>
          </Animated.View>
        </Modal>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: THEME.background,
  },
  screen: {
    flex: 1,
    backgroundColor: THEME.background,
  },
  discoverScreen: {
    flex: 1,
    paddingTop: 6,
  },
  discoverTabBarWrap: {
    paddingBottom: 4,
  },
  discoverTabScrollContent: {
    paddingHorizontal: 16,
  },
  discoverTabsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 24,
    position: 'relative',
  },
  discoverTabButton: {
    paddingVertical: 12,
  },
  discoverTabText: {
    fontSize: 18,
    fontWeight: '400',
    color: THEME.secondaryText,
    letterSpacing: 0,
  },
  discoverIndicator: {
    position: 'absolute',
    left: 0,
    bottom: 0,
    height: 2.6,
    borderRadius: 999,
  },
  recommendPagerWrap: {
    flex: 1,
    paddingTop: 4,
    paddingBottom: 0,
  },
  recommendStage: {
    flex: 1,
  },
  recommendScrollContent: {
    paddingHorizontal: 16,
  },
  cardFrame: {
    borderRadius: 28,
    overflow: 'hidden',
  },
  cardButton: {
    flex: 1,
  },
  cardBase: {
    flex: 1,
    borderRadius: 28,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
    shadowColor: '#000000',
    shadowOpacity: 0.22,
    shadowRadius: 13,
    shadowOffset: {
      width: 0,
      height: 6,
    },
    elevation: 12,
  },
  cardFill: {
    ...StyleSheet.absoluteFillObject,
  },
  cardImage: {
    ...StyleSheet.absoluteFillObject,
  },
  cardImageTint: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(7,12,18,0.22)',
  },
  cardAtmosphereBand: {
    position: 'absolute',
    borderRadius: 999,
    opacity: 0.55,
  },
  cardAtmosphereBandPrimary: {
    width: 260,
    height: 260,
    right: -20,
    top: 70,
    backgroundColor: 'rgba(255,255,255,0.12)',
    transform: [{ rotate: '-24deg' }],
  },
  cardAtmosphereBandSecondary: {
    width: 180,
    height: 180,
    left: -30,
    top: 150,
    backgroundColor: 'rgba(43,243,236,0.1)',
    transform: [{ rotate: '18deg' }],
  },
  cardShade: {
    ...StyleSheet.absoluteFillObject,
  },
  cardMeta: {
    flex: 1,
    justifyContent: 'flex-end',
    paddingHorizontal: 20,
    paddingBottom: 18,
  },
  cardPillRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 8,
  },
  typePill: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 999,
    backgroundColor: 'rgba(255,255,255,0.15)',
  },
  typePillText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0,
  },
  statusPill: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 999,
    backgroundColor: 'rgba(41,243,234,0.18)',
  },
  statusPillText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0,
  },
  cardLine: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: 2,
  },
  cardLineText: {
    color: 'rgba(255,255,255,0.88)',
    fontSize: 15,
    fontWeight: '600',
    flexShrink: 1,
    letterSpacing: 0,
  },
  cardLineTextSecondary: {
    color: 'rgba(255,255,255,0.86)',
    fontSize: 14,
    fontWeight: '600',
    flexShrink: 1,
    letterSpacing: 0,
  },
  cardHeadline: {
    marginTop: 6,
    color: '#FFFFFF',
    fontSize: 34,
    lineHeight: 31,
    fontWeight: '800',
    letterSpacing: 0,
  },
  recommendIndicatorWrap: {
    position: 'absolute',
    alignSelf: 'center',
  },
  recommendIndicatorTrack: {
    height: 6,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    position: 'relative',
  },
  recommendIndicatorDot: {
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 999,
    backgroundColor: 'rgba(255,255,255,0.26)',
    shadowColor: THEME.pageIndicator,
    shadowOffset: {
      width: 0,
      height: 0,
    },
  },
  recommendIndicatorGlow: {
    position: 'absolute',
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    height: 3,
    borderRadius: 999,
    shadowColor: THEME.pageIndicator,
  },
  sectionScreen: {
    flex: 1,
  },
  eventsHeader: {
    paddingTop: 8,
    paddingBottom: 8,
    backgroundColor: THEME.background,
  },
  eventsUtilityRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  locationFilterButton: {
    marginLeft: 16,
    width: 58,
    height: 34,
    borderRadius: 12,
    backgroundColor: THEME.card,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
  },
  locationFilterText: {
    color: THEME.primaryText,
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0,
  },
  utilityIconButton: {
    width: 32,
    height: 32,
    borderRadius: 10,
    backgroundColor: THEME.card,
    alignItems: 'center',
    justifyContent: 'center',
  },
  eventsChipScrollContent: {
    paddingRight: 16,
    gap: 8,
  },
  eventsTypeChip: {
    height: 34,
    paddingHorizontal: 10,
    borderRadius: 12,
    backgroundColor: THEME.card,
    alignItems: 'center',
    justifyContent: 'center',
  },
  eventsTypeChipText: {
    color: THEME.primaryText,
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0,
  },
  eventsTypeChipTextActive: {
    color: '#FFFFFF',
  },
  eventsScrollContent: {
    paddingHorizontal: 14,
    paddingTop: 8,
    paddingBottom: 142,
    gap: 14,
  },
  eventRowCard: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 12,
    minHeight: 176,
    padding: 12,
    borderRadius: 16,
    backgroundColor: THEME.card,
  },
  eventRowCover: {
    width: 144,
    height: 172,
    borderRadius: 14,
    overflow: 'hidden',
  },
  eventRowCoverFill: {
    ...StyleSheet.absoluteFillObject,
  },
  eventDateBadge: {
    position: 'absolute',
    top: 8,
    left: 8,
    minWidth: 46,
    paddingHorizontal: 8,
    paddingVertical: 6,
    borderRadius: 9,
    backgroundColor: 'rgba(20,20,24,0.5)',
    alignItems: 'center',
  },
  eventDateBadgeMonth: {
    color: '#F5F5F7',
    fontSize: 10,
    fontWeight: '600',
    letterSpacing: 0,
  },
  eventDateBadgeDay: {
    color: '#F5F5F7',
    fontSize: 20,
    fontWeight: '700',
    lineHeight: 22,
    letterSpacing: 0,
  },
  eventStatusBadge: {
    position: 'absolute',
    left: 8,
    bottom: 8,
    paddingHorizontal: 9,
    paddingVertical: 5,
    borderRadius: 999,
  },
  eventStatusBadgeText: {
    color: '#FFFFFF',
    fontSize: 11,
    fontWeight: '600',
    letterSpacing: 0,
  },
  eventRowMeta: {
    flex: 1,
    paddingTop: 2,
    paddingRight: 4,
  },
  eventRowTitle: {
    color: THEME.primaryText,
    fontSize: 17,
    fontWeight: '700',
    lineHeight: 22,
    letterSpacing: 0,
    marginBottom: 10,
  },
  eventTypeBadge: {
    alignSelf: 'flex-start',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 999,
    marginBottom: 10,
  },
  eventTypeBadgeText: {
    fontSize: 12,
    fontWeight: '500',
    letterSpacing: 0,
  },
  eventInfoLine: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 7,
    marginBottom: 7,
  },
  eventInfoText: {
    flex: 1,
    color: THEME.secondaryText,
    fontSize: 12,
    lineHeight: 18,
    fontWeight: '500',
    letterSpacing: 0,
  },
  eventsFloatingWrap: {
    position: 'absolute',
    right: 20,
    bottom: 108,
    alignItems: 'flex-end',
    gap: 10,
  },
  eventsPromptBubble: {
    maxWidth: 226,
    paddingLeft: 14,
    paddingRight: 8,
    paddingVertical: 10,
    borderRadius: 18,
    backgroundColor: 'rgba(28,28,31,0.9)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.14)',
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 10,
  },
  eventsPromptText: {
    flex: 1,
    color: THEME.primaryText,
    fontSize: 12,
    lineHeight: 16,
    fontWeight: '700',
    letterSpacing: 0,
  },
  eventsPromptClose: {
    width: 22,
    height: 22,
    borderRadius: 999,
    backgroundColor: 'rgba(255,255,255,0.16)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  eventsFloatingButton: {
    width: 58,
    height: 58,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: THEME.accent,
    shadowOpacity: 0.32,
    shadowRadius: 16,
    shadowOffset: {
      width: 0,
      height: 8,
    },
    elevation: 12,
  },
  newsHeader: {
    paddingTop: 8,
    paddingBottom: 4,
    paddingLeft: 16,
    paddingRight: 16,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: THEME.background,
  },
  newsChipScrollContent: {
    gap: 8,
    paddingRight: 6,
  },
  newsCategoryChip: {
    height: 34,
    paddingHorizontal: 10,
    borderRadius: 12,
    backgroundColor: THEME.card,
    alignItems: 'center',
    justifyContent: 'center',
  },
  newsCategoryChipText: {
    color: THEME.primaryText,
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0,
  },
  newsCategoryChipTextActive: {
    color: '#FFFFFF',
  },
  newsComposeButton: {
    width: 32,
    height: 32,
    borderRadius: 12,
    backgroundColor: '#F58433',
    alignItems: 'center',
    justifyContent: 'center',
  },
  newsScrollContent: {
    paddingBottom: 118,
  },
  newsRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  newsMeta: {
    flex: 1,
  },
  newsBadgeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: 7,
  },
  newsCategoryBadge: {
    paddingHorizontal: 6,
    paddingVertical: 3,
    borderRadius: 6,
  },
  newsCategoryBadgeText: {
    fontSize: 10,
    fontWeight: '600',
    letterSpacing: 0,
  },
  newsSourceText: {
    color: THEME.secondaryText,
    fontSize: 11,
    fontWeight: '400',
    letterSpacing: 0,
  },
  newsTitle: {
    color: THEME.primaryText,
    fontSize: 15,
    lineHeight: 21,
    fontWeight: '600',
    letterSpacing: 0,
    marginBottom: 6,
  },
  newsSummary: {
    color: THEME.secondaryText,
    fontSize: 12,
    lineHeight: 18,
    fontWeight: '400',
    letterSpacing: 0,
    marginBottom: 8,
  },
  newsFooterRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  newsFooterReply: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  newsFooterText: {
    color: THEME.secondaryText,
    fontSize: 11,
    fontWeight: '400',
    letterSpacing: 0,
  },
  newsCover: {
    width: 122,
    height: 82,
    borderRadius: 6,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
  },
  newsCoverFill: {
    ...StyleSheet.absoluteFillObject,
  },
  newsDivider: {
    marginLeft: 16,
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.08)',
  },
  organizersToolbar: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 8,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  organizersToolbarText: {
    flex: 1,
    color: THEME.secondaryText,
    fontSize: 12,
    fontWeight: '400',
    letterSpacing: 0,
  },
  organizersAddButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderRadius: 9,
    backgroundColor: THEME.accent,
  },
  organizersAddButtonText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0,
  },
  organizersScrollContent: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 118,
    gap: 14,
  },
  organizerCard: {
    borderRadius: 14,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: THEME.cardBorder,
  },
  organizerBanner: {
    width: '100%',
    aspectRatio: 16 / 9,
    minHeight: 250,
    justifyContent: 'flex-end',
  },
  organizerBannerFill: {
    ...StyleSheet.absoluteFillObject,
  },
  organizerBannerShade: {
    ...StyleSheet.absoluteFillObject,
  },
  organizerIdentityRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 14,
    paddingBottom: 20,
  },
  organizerAvatar: {
    width: 62,
    height: 62,
    borderRadius: 12,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  organizerAvatarFill: {
    ...StyleSheet.absoluteFillObject,
  },
  organizerAvatarText: {
    color: 'rgba(255,255,255,0.88)',
    fontSize: 22,
    fontWeight: '900',
    letterSpacing: 0,
  },
  organizerTextWrap: {
    flex: 1,
  },
  organizerName: {
    color: '#FFFFFF',
    fontSize: 18,
    lineHeight: 23,
    fontWeight: '800',
    letterSpacing: 0,
    marginBottom: 6,
  },
  organizerInfoLine: {
    color: 'rgba(255,255,255,0.86)',
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0,
  },
  djsToolbar: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 8,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  djsToolbarText: {
    flex: 1,
    color: THEME.secondaryText,
    fontSize: 12,
    fontWeight: '400',
    letterSpacing: 0,
  },
  djsAddButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderRadius: 9,
    backgroundColor: '#76C955',
  },
  djsAddButtonText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0,
  },
  djsScrollContent: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 118,
    gap: 12,
  },
  djCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    padding: 14,
    borderRadius: 18,
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
  },
  djAvatar: {
    width: 64,
    height: 64,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  djAvatarText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '800',
    letterSpacing: 0,
  },
  djMeta: {
    flex: 1,
  },
  djName: {
    color: THEME.primaryText,
    fontSize: 16,
    lineHeight: 21,
    fontWeight: '700',
    letterSpacing: 0,
    marginBottom: 4,
  },
  djSubline: {
    color: THEME.secondaryText,
    fontSize: 12,
    lineHeight: 17,
    fontWeight: '500',
    letterSpacing: 0,
    marginBottom: 8,
  },
  djGenreRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
  },
  djGenrePill: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 999,
    backgroundColor: '#17171E',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
  },
  djGenrePillText: {
    color: THEME.primaryText,
    fontSize: 10,
    fontWeight: '600',
    letterSpacing: 0,
  },
  labelsToolbar: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 8,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  labelsToolbarText: {
    flex: 1,
    color: THEME.secondaryText,
    fontSize: 12,
    fontWeight: '400',
    letterSpacing: 0,
  },
  labelsAddButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderRadius: 9,
    backgroundColor: '#6D92F4',
  },
  labelsAddButtonText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0,
  },
  labelsScrollContent: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 118,
    gap: 14,
  },
  labelCard: {
    borderRadius: 18,
    overflow: 'hidden',
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
  },
  labelCardHero: {
    minHeight: 132,
    paddingHorizontal: 16,
    paddingVertical: 16,
    justifyContent: 'space-between',
  },
  labelMonogramWrap: {
    width: 52,
    height: 52,
    borderRadius: 14,
    backgroundColor: 'rgba(255,255,255,0.12)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.18)',
  },
  labelMonogramText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '800',
    letterSpacing: 0,
  },
  labelHeroMeta: {
    gap: 4,
  },
  labelName: {
    color: '#FFFFFF',
    fontSize: 20,
    lineHeight: 24,
    fontWeight: '800',
    letterSpacing: 0,
  },
  labelLocationLine: {
    color: 'rgba(255,255,255,0.84)',
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0,
  },
  labelCardBody: {
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  labelFocusText: {
    color: THEME.primaryText,
    fontSize: 14,
    lineHeight: 20,
    fontWeight: '600',
    letterSpacing: 0,
    marginBottom: 8,
  },
  labelStatsRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  labelStatText: {
    color: THEME.secondaryText,
    fontSize: 12,
    fontWeight: '500',
    letterSpacing: 0,
  },
  labelStatsDivider: {
    marginHorizontal: 6,
    color: THEME.secondaryText,
    fontSize: 12,
    fontWeight: '500',
  },
  rankingsHeader: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 8,
  },
  rankingsBoardSwitch: {
    flexDirection: 'row',
    gap: 8,
  },
  rankingsBoardChip: {
    paddingHorizontal: 11,
    paddingVertical: 8,
    borderRadius: 12,
    backgroundColor: THEME.card,
  },
  rankingsBoardChipActive: {
    backgroundColor: THEME.accent,
  },
  rankingsBoardChipText: {
    color: THEME.primaryText,
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0,
  },
  rankingsBoardChipTextActive: {
    color: '#FFFFFF',
  },
  rankingsScrollContent: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 118,
    gap: 12,
  },
  rankingHeroCard: {
    borderRadius: 20,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
  },
  rankingHeroGradient: {
    minHeight: 188,
    paddingHorizontal: 16,
    paddingTop: 14,
    paddingBottom: 16,
    justifyContent: 'space-between',
  },
  rankingHeroTopRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  rankingHeroBadge: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 999,
    backgroundColor: 'rgba(255,255,255,0.14)',
  },
  rankingHeroBadgeText: {
    color: '#FFFFFF',
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0,
  },
  rankingHeroTitle: {
    color: '#FFFFFF',
    fontSize: 24,
    lineHeight: 30,
    fontWeight: '800',
    letterSpacing: 0,
    marginTop: 16,
  },
  rankingHeroSubtitle: {
    color: 'rgba(255,255,255,0.88)',
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '600',
    letterSpacing: 0,
    marginTop: 6,
  },
  rankingHeroSummary: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 13,
    lineHeight: 19,
    fontWeight: '500',
    letterSpacing: 0,
    marginTop: 10,
  },
  rankingHeroFooter: {
    gap: 4,
    marginTop: 14,
  },
  rankingHeroMetaText: {
    color: 'rgba(255,255,255,0.68)',
    fontSize: 11,
    lineHeight: 16,
    fontWeight: '500',
    letterSpacing: 0,
  },
  rankingInsightList: {
    gap: 10,
  },
  rankingInsightCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    borderRadius: 16,
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  rankingInsightText: {
    flex: 1,
    color: THEME.primaryText,
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '500',
    letterSpacing: 0,
  },
  rankingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    padding: 12,
    borderRadius: 18,
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
  },
  rankingIndexWrap: {
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: 'rgba(255,255,255,0.08)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  rankingIndexText: {
    color: THEME.primaryText,
    fontSize: 15,
    fontWeight: '700',
    letterSpacing: 0,
  },
  rankingThumb: {
    width: 54,
    height: 54,
    borderRadius: 14,
  },
  rankingMeta: {
    flex: 1,
    gap: 4,
  },
  rankingTitle: {
    color: THEME.primaryText,
    fontSize: 15,
    lineHeight: 20,
    fontWeight: '700',
    letterSpacing: 0,
  },
  rankingSubtitle: {
    color: THEME.secondaryText,
    fontSize: 12,
    lineHeight: 17,
    fontWeight: '500',
    letterSpacing: 0,
  },
  rankingScoreWrap: {
    alignItems: 'flex-end',
    gap: 4,
  },
  rankingScore: {
    color: '#FFFFFF',
    fontSize: 20,
    lineHeight: 24,
    fontWeight: '800',
    letterSpacing: 0,
  },
  rankingDelta: {
    color: '#45D9D1',
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0,
  },
  rankingDetailEntryList: {
    gap: 12,
  },
  rankingDetailEntryCard: {
    borderRadius: 18,
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
    padding: 12,
    gap: 10,
  },
  rankingDetailEntryTopRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  rankingDetailRankPill: {
    paddingHorizontal: 9,
    paddingVertical: 5,
    borderRadius: 999,
    backgroundColor: 'rgba(255,255,255,0.08)',
  },
  rankingDetailRankText: {
    color: THEME.primaryText,
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0,
  },
  rankingDetailDeltaText: {
    color: '#45D9D1',
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0,
  },
  rankingDetailEntryMainRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  rankingDetailEntryThumb: {
    width: 64,
    height: 64,
    borderRadius: 16,
  },
  rankingDetailEntryMeta: {
    flex: 1,
    gap: 4,
  },
  rankingDetailEntryTitle: {
    color: THEME.primaryText,
    fontSize: 15,
    lineHeight: 20,
    fontWeight: '700',
    letterSpacing: 0,
  },
  rankingDetailEntrySubtitle: {
    color: THEME.secondaryText,
    fontSize: 12,
    lineHeight: 17,
    fontWeight: '500',
    letterSpacing: 0,
  },
  rankingDetailEntryNote: {
    color: 'rgba(255,255,255,0.74)',
    fontSize: 12,
    lineHeight: 17,
    fontWeight: '500',
    letterSpacing: 0,
  },
  rankingDetailScoreWrap: {
    minWidth: 52,
    alignItems: 'flex-end',
  },
  rankingDetailScoreText: {
    color: '#FFFFFF',
    fontSize: 22,
    lineHeight: 26,
    fontWeight: '800',
    letterSpacing: 0,
  },
  rankingDimensionList: {
    gap: 12,
  },
  rankingDimensionCard: {
    borderRadius: 18,
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
    padding: 14,
    gap: 8,
  },
  rankingDimensionTopRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  rankingDimensionLabel: {
    flex: 1,
    color: THEME.primaryText,
    fontSize: 15,
    lineHeight: 20,
    fontWeight: '700',
    letterSpacing: 0,
  },
  rankingDimensionWeight: {
    color: '#BB79F3',
    fontSize: 14,
    fontWeight: '800',
    letterSpacing: 0,
  },
  rankingDimensionNote: {
    color: THEME.secondaryText,
    fontSize: 12,
    lineHeight: 18,
    fontWeight: '500',
    letterSpacing: 0,
  },
  setsToolbar: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 8,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  setsToolbarText: {
    flex: 1,
    color: THEME.secondaryText,
    fontSize: 12,
    fontWeight: '400',
    letterSpacing: 0,
  },
  setsFilterButton: {
    width: 34,
    height: 34,
    borderRadius: 12,
    backgroundColor: THEME.card,
    alignItems: 'center',
    justifyContent: 'center',
  },
  setsScrollContent: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 118,
    gap: 12,
  },
  setCard: {
    borderRadius: 18,
    overflow: 'hidden',
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
  },
  setCardTop: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    padding: 12,
  },
  setThumb: {
    width: 76,
    height: 76,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  setMeta: {
    flex: 1,
    gap: 4,
  },
  setTitle: {
    color: THEME.primaryText,
    fontSize: 15,
    lineHeight: 20,
    fontWeight: '700',
    letterSpacing: 0,
  },
  setSubtitle: {
    color: THEME.secondaryText,
    fontSize: 12,
    lineHeight: 17,
    fontWeight: '500',
    letterSpacing: 0,
  },
  setMetaLine: {
    color: 'rgba(255,255,255,0.72)',
    fontSize: 11,
    fontWeight: '600',
    letterSpacing: 0,
  },
  setLinkedEventRow: {
    minHeight: 42,
    paddingHorizontal: 14,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255,255,255,0.06)',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  setLinkedEventText: {
    flex: 1,
    color: THEME.secondaryText,
    fontSize: 12,
    fontWeight: '500',
    letterSpacing: 0,
  },
  genresToolbar: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 8,
  },
  genresToolbarText: {
    color: THEME.secondaryText,
    fontSize: 12,
    fontWeight: '400',
    letterSpacing: 0,
  },
  genresScrollContent: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 118,
    gap: 14,
  },
  genreCard: {
    borderRadius: 18,
    overflow: 'hidden',
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
  },
  genreHero: {
    minHeight: 110,
    paddingHorizontal: 16,
    paddingVertical: 14,
    justifyContent: 'flex-end',
  },
  genreName: {
    color: '#FFFFFF',
    fontSize: 22,
    lineHeight: 26,
    fontWeight: '800',
    letterSpacing: 0,
    marginBottom: 6,
  },
  genreScene: {
    color: 'rgba(255,255,255,0.84)',
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0,
  },
  genreBody: {
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  genreDescription: {
    color: THEME.primaryText,
    fontSize: 14,
    lineHeight: 21,
    fontWeight: '500',
    letterSpacing: 0,
    marginBottom: 10,
  },
  genreTagsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: 10,
  },
  genreTag: {
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 999,
    backgroundColor: '#17171E',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
  },
  genreTagText: {
    color: THEME.primaryText,
    fontSize: 11,
    fontWeight: '600',
    letterSpacing: 0,
  },
  genreLinkedRow: {
    minHeight: 36,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  genreLinkedText: {
    flex: 1,
    color: THEME.secondaryText,
    fontSize: 12,
    fontWeight: '500',
    letterSpacing: 0,
  },
  detailModalRoot: {
    flex: 1,
    backgroundColor: THEME.background,
  },
  detailHero: {
    justifyContent: 'flex-end',
    overflow: 'hidden',
  },
  detailHeroFill: {
    ...StyleSheet.absoluteFillObject,
  },
  detailHeroGlowPrimary: {
    position: 'absolute',
    width: 240,
    height: 240,
    borderRadius: 999,
    top: 46,
    right: -36,
    backgroundColor: 'rgba(255,255,255,0.14)',
  },
  detailHeroGlowSecondary: {
    position: 'absolute',
    width: 186,
    height: 186,
    borderRadius: 999,
    left: -28,
    top: 132,
    backgroundColor: 'rgba(41,243,234,0.1)',
  },
  detailHeroShade: {
    ...StyleSheet.absoluteFillObject,
  },
  detailHeroMeta: {
    justifyContent: 'flex-end',
    paddingBottom: 24,
    gap: 8,
  },
  detailHeroEyebrow: {
    alignSelf: 'flex-start',
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 999,
    backgroundColor: 'rgba(255,255,255,0.14)',
  },
  detailHeroEyebrowText: {
    color: '#FFFFFF',
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0,
  },
  detailHeroTitle: {
    color: '#FFFFFF',
    fontSize: 31,
    lineHeight: 35,
    fontWeight: '800',
    letterSpacing: 0,
  },
  detailHeroSubtitle: {
    color: 'rgba(255,255,255,0.9)',
    fontSize: 16,
    lineHeight: 20,
    fontWeight: '600',
    letterSpacing: 0,
  },
  detailHeroLineGroup: {
    gap: 4,
    marginTop: 2,
  },
  detailHeroLineText: {
    color: 'rgba(255,255,255,0.82)',
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '500',
    letterSpacing: 0,
  },
  detailHeroChipRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 6,
  },
  detailHeroChip: {
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 999,
    backgroundColor: 'rgba(12,12,16,0.42)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.12)',
  },
  detailHeroChipText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0,
  },
  detailStickyTabsShell: {
    backgroundColor: THEME.background,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.06)',
  },
  detailTabsScrollContent: {
    paddingHorizontal: 16,
  },
  detailTabsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 20,
  },
  detailTabButton: {
    paddingTop: 14,
    paddingBottom: 10,
  },
  detailTabText: {
    color: THEME.secondaryText,
    fontSize: 16,
    fontWeight: '500',
    letterSpacing: 0,
  },
  detailTabUnderline: {
    marginTop: 8,
    width: '100%',
    height: 2.5,
    borderRadius: 999,
    backgroundColor: 'transparent',
    opacity: 0,
  },
  detailTopChrome: {
    position: 'absolute',
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  detailChromeButton: {
    width: 36,
    height: 36,
    borderRadius: 999,
    backgroundColor: 'rgba(0,0,0,0.32)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.16)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  detailContentWrap: {
    paddingTop: 18,
  },
  detailSectionGroup: {
    gap: 12,
  },
  detailSectionLabel: {
    color: THEME.primaryText,
    fontSize: 20,
    lineHeight: 24,
    fontWeight: '700',
    letterSpacing: 0,
  },
  detailMetricsRow: {
    flexDirection: 'row',
    gap: 10,
  },
  detailMetricCard: {
    flex: 1,
    minHeight: 82,
    borderRadius: 16,
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
    paddingHorizontal: 14,
    paddingVertical: 14,
    justifyContent: 'space-between',
  },
  detailMetricLabel: {
    color: THEME.secondaryText,
    fontSize: 12,
    fontWeight: '500',
    letterSpacing: 0,
  },
  detailMetricValue: {
    color: THEME.primaryText,
    fontSize: 20,
    lineHeight: 24,
    fontWeight: '700',
    letterSpacing: 0,
  },
  detailMetricValueSmall: {
    color: THEME.primaryText,
    fontSize: 15,
    lineHeight: 20,
    fontWeight: '700',
    letterSpacing: 0,
  },
  detailInfoCard: {
    borderRadius: 18,
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
    overflow: 'hidden',
  },
  detailInfoRow: {
    minHeight: 54,
    paddingHorizontal: 16,
    paddingVertical: 14,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 14,
  },
  detailInfoLabel: {
    color: THEME.secondaryText,
    fontSize: 13,
    fontWeight: '600',
    letterSpacing: 0,
  },
  detailInfoValue: {
    flex: 1,
    color: THEME.primaryText,
    fontSize: 13,
    lineHeight: 18,
    textAlign: 'right',
    fontWeight: '600',
    letterSpacing: 0,
  },
  detailInfoDivider: {
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.06)',
    marginLeft: 16,
  },
  detailInfoActionWrap: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
    gap: 6,
  },
  detailDescriptionCard: {
    borderRadius: 18,
    backgroundColor: '#101015',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
    padding: 16,
  },
  detailDescriptionText: {
    color: THEME.primaryText,
    fontSize: 14,
    lineHeight: 22,
    fontWeight: '400',
    letterSpacing: 0,
  },
  detailParagraphSpacing: {
    marginTop: 14,
  },
  detailLineupList: {
    gap: 12,
  },
  detailLineupCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    borderRadius: 18,
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
    padding: 12,
  },
  detailLineupAvatar: {
    width: 58,
    height: 58,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  detailLineupAvatarText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '800',
    letterSpacing: 0,
  },
  detailLineupMeta: {
    flex: 1,
    gap: 3,
  },
  detailLineupName: {
    color: THEME.primaryText,
    fontSize: 17,
    lineHeight: 21,
    fontWeight: '700',
    letterSpacing: 0,
  },
  detailLineupSubtext: {
    color: THEME.secondaryText,
    fontSize: 12,
    lineHeight: 17,
    fontWeight: '500',
    letterSpacing: 0,
  },
  detailScheduleList: {
    gap: 10,
  },
  detailScheduleCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    borderRadius: 18,
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
    padding: 14,
  },
  detailScheduleTimeBlock: {
    width: 76,
    gap: 4,
  },
  detailScheduleTime: {
    color: THEME.primaryText,
    fontSize: 22,
    lineHeight: 25,
    fontWeight: '800',
    letterSpacing: 0,
  },
  detailScheduleStage: {
    color: '#45D9D1',
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0,
  },
  detailScheduleMeta: {
    flex: 1,
    gap: 4,
  },
  detailScheduleArtist: {
    color: THEME.primaryText,
    fontSize: 16,
    lineHeight: 20,
    fontWeight: '700',
    letterSpacing: 0,
  },
  detailScheduleHint: {
    color: THEME.secondaryText,
    fontSize: 12,
    lineHeight: 16,
    fontWeight: '500',
    letterSpacing: 0,
  },
  detailNewsList: {
    gap: 12,
  },
  detailNewsCard: {
    flexDirection: 'row',
    alignItems: 'stretch',
    gap: 12,
    borderRadius: 18,
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
    padding: 12,
  },
  detailNewsBody: {
    flex: 1,
    gap: 6,
  },
  detailNewsBadgeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  detailNewsBadge: {
    paddingHorizontal: 7,
    paddingVertical: 4,
    borderRadius: 999,
  },
  detailNewsBadgeText: {
    fontSize: 10,
    fontWeight: '700',
    letterSpacing: 0,
  },
  detailNewsMetaText: {
    color: THEME.secondaryText,
    fontSize: 11,
    fontWeight: '500',
    letterSpacing: 0,
  },
  detailNewsTitle: {
    color: THEME.primaryText,
    fontSize: 15,
    lineHeight: 20,
    fontWeight: '700',
    letterSpacing: 0,
  },
  detailNewsSummary: {
    color: THEME.secondaryText,
    fontSize: 12,
    lineHeight: 18,
    fontWeight: '400',
    letterSpacing: 0,
  },
  detailNewsCover: {
    width: 88,
    borderRadius: 12,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
  },
  detailNewsCoverFill: {
    ...StyleSheet.absoluteFillObject,
  },
  detailListBlock: {
    gap: 10,
  },
  detailListCard: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 12,
    borderRadius: 18,
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
    padding: 14,
  },
  detailListIconWrap: {
    width: 28,
    height: 28,
    borderRadius: 999,
    backgroundColor: 'rgba(255,255,255,0.08)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  detailListText: {
    flex: 1,
    color: THEME.primaryText,
    fontSize: 14,
    lineHeight: 20,
    fontWeight: '500',
    letterSpacing: 0,
  },
  detailRatingsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  detailRatingCard: {
    width: '47%',
    minHeight: 74,
    borderRadius: 16,
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
    paddingHorizontal: 12,
    paddingVertical: 14,
    justifyContent: 'center',
  },
  detailRatingText: {
    color: THEME.primaryText,
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '600',
    letterSpacing: 0,
  },
  detailChipCloud: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  detailCloudChip: {
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderRadius: 999,
    backgroundColor: '#14141B',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
  },
  detailCloudChipText: {
    color: THEME.primaryText,
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0,
  },
  detailLinkedEventList: {
    gap: 12,
  },
  detailLinkedEventCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    borderRadius: 18,
    backgroundColor: '#111118',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
    padding: 12,
  },
  detailLinkedEventThumb: {
    width: 74,
    height: 84,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  detailLinkedEventMeta: {
    flex: 1,
    gap: 4,
  },
  detailLinkedEventTitle: {
    color: THEME.primaryText,
    fontSize: 15,
    lineHeight: 20,
    fontWeight: '700',
    letterSpacing: 0,
  },
  detailLinkedEventSubtitle: {
    color: THEME.secondaryText,
    fontSize: 11,
    lineHeight: 16,
    fontWeight: '500',
    letterSpacing: 0,
  },
  sectionPlaceholder: {
    flex: 1,
    marginHorizontal: 16,
    marginTop: 18,
    marginBottom: 116,
    borderRadius: 28,
    borderWidth: 1,
    borderColor: THEME.cardBorder,
    backgroundColor: THEME.card,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 28,
  },
  sectionPlaceholderAccent: {
    width: 52,
    height: 6,
    borderRadius: 999,
    marginBottom: 18,
  },
  sectionPlaceholderTitle: {
    color: THEME.primaryText,
    fontSize: 28,
    fontWeight: '800',
    marginBottom: 10,
    letterSpacing: 0,
  },
  sectionPlaceholderBody: {
    color: THEME.secondaryText,
    fontSize: 15,
    lineHeight: 22,
    textAlign: 'center',
    letterSpacing: 0,
  },
  placeholderScreen: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 28,
    paddingBottom: 116,
  },
  placeholderAccent: {
    width: 52,
    height: 6,
    borderRadius: 999,
    marginBottom: 18,
  },
  placeholderTitle: {
    color: THEME.primaryText,
    fontSize: 30,
    fontWeight: '800',
    marginBottom: 10,
    letterSpacing: 0,
  },
  placeholderDescription: {
    color: THEME.secondaryText,
    fontSize: 15,
    lineHeight: 22,
    textAlign: 'center',
    letterSpacing: 0,
  },
  bottomBarOuter: {
    position: 'absolute',
    left: 16,
    right: 16,
    bottom: 18,
  },
  bottomBarBlur: {
    borderRadius: 999,
    overflow: 'hidden',
  },
  bottomBarGradient: {
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 7,
    minHeight: 66,
    justifyContent: 'center',
  },
  bottomBarStroke: {
    ...StyleSheet.absoluteFillObject,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.12)',
  },
  bottomBarContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  bottomTabButton: {
    flex: 1,
    height: 52,
    justifyContent: 'center',
    alignItems: 'center',
  },
  bottomTabInner: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 3,
  },
  bottomIconWrap: {
    width: 48,
    height: 22,
    alignItems: 'center',
    justifyContent: 'center',
  },
  unreadBadge: {
    position: 'absolute',
    top: -6,
    right: 6,
    minWidth: 16,
    height: 16,
    paddingHorizontal: 4,
    borderRadius: 999,
    backgroundColor: '#FF3B30',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.88)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  unreadBadgeText: {
    color: '#FFFFFF',
    fontSize: 9,
    fontWeight: '700',
    letterSpacing: 0,
  },
  bottomTabLabel: {
    color: THEME.secondaryText,
    fontSize: 11,
    lineHeight: 14,
    fontWeight: '500',
    letterSpacing: 0,
    textAlign: 'center',
  },
  bottomTabLabelActive: {
    color: THEME.primaryText,
    fontWeight: '600',
  },
  searchSlot: {
    width: 52,
    alignItems: 'center',
    justifyContent: 'center',
  },
  searchButtonRing: {
    width: 56,
    height: 56,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: THEME.accent,
    shadowOpacity: 0.36,
    shadowRadius: 14,
    shadowOffset: {
      width: 0,
      height: 8,
    },
    elevation: 10,
  },
  searchButton: {
    width: 54,
    height: 54,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.32)',
    backgroundColor: 'transparent',
  },
  bottomActivePill: {
    position: 'absolute',
    top: 9,
    left: 0,
    height: 52,
    borderRadius: 999,
    overflow: 'hidden',
  },
  bottomActivePillFill: {
    flex: 1,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: THEME.tabBarSelectionStroke,
  },
  searchOverlay: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 20,
    backgroundColor: 'rgba(0,0,0,0.32)',
  },
  searchBackdrop: {
    ...StyleSheet.absoluteFillObject,
  },
  searchSheet: {
    width: '100%',
    maxWidth: 420,
    borderRadius: 24,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.12)',
    backgroundColor: '#111118',
    padding: 22,
    gap: 14,
  },
  searchSheetTitle: {
    color: THEME.primaryText,
    fontSize: 24,
    fontWeight: '800',
    letterSpacing: 0,
  },
  searchSheetBody: {
    color: THEME.secondaryText,
    fontSize: 15,
    lineHeight: 22,
    letterSpacing: 0,
  },
  searchFieldMock: {
    height: 48,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
    backgroundColor: '#171720',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 14,
  },
  searchFieldText: {
    color: THEME.secondaryText,
    fontSize: 14,
    letterSpacing: 0,
  },
  searchPrimaryButton: {
    height: 48,
    borderRadius: 14,
    backgroundColor: THEME.accent,
    alignItems: 'center',
    justifyContent: 'center',
  },
  searchPrimaryButtonText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '700',
    letterSpacing: 0,
  },
});
