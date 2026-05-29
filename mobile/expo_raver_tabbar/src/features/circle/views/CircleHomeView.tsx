import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  Animated,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  useWindowDimensions,
  View,
} from 'react-native';

type CircleHomeViewProps = {
  bottomInset: number;
};

type CircleSectionKey = 'feed' | 'squads' | 'ids' | 'ratings';
type FeedModeKey = 'recommended' | 'following' | 'latest';
type SquadModeKey = 'plaza' | 'mine';

type MeasuredLayout = {
  x: number;
  width: number;
};

type FeedPost = {
  id: string;
  author: string;
  handle: string;
  time: string;
  title: string;
  body: string;
  tag: string;
  reason: string;
  location: string;
  liked: string;
  replies: string;
  saves: string;
  palette: [string, string, string];
};

type SquadCard = {
  id: string;
  name: string;
  leader: string;
  region: string;
  members: string;
  palette: [string, string, string];
};

type IDEntry = {
  id: string;
  songName: string;
  event: string;
  artists: string;
  contributor: string;
  createdAt: string;
  likes: string;
  comments: string;
  palette: [string, string, string];
};

type RatingEvent = {
  id: string;
  title: string;
  description: string;
  publisher: string;
  units: string;
  average: number;
  palette: [string, string];
};

const CIRCLE_THEME = {
  background: '#08080A',
  card: '#141419',
  cardBorder: 'rgba(255,255,255,0.08)',
  primaryText: '#F5F5F7',
  secondaryText: '#A3A3AD',
  tertiaryText: 'rgba(255,255,255,0.68)',
  accent: '#8C5CFF',
};

const CIRCLE_SECTIONS: Array<{
  key: CircleSectionKey;
  label: string;
  color: string;
}> = [
  { key: 'feed', label: '动态', color: '#F24F62' },
  { key: 'squads', label: '小队', color: '#4BAEFF' },
  { key: 'ids', label: 'ID', color: '#8C5CFF' },
  { key: 'ratings', label: '打分', color: '#F3B94A' },
];

const FEED_MODES: Array<{
  key: FeedModeKey;
  label: string;
  icon: keyof typeof Ionicons.glyphMap;
}> = [
  { key: 'recommended', label: '推荐', icon: 'sparkles' },
  { key: 'following', label: '关注', icon: 'people' },
  { key: 'latest', label: '最新', icon: 'time' },
];

const FEED_POSTS: Record<FeedModeKey, FeedPost[]> = {
  recommended: [
    {
      id: 'feed-1',
      author: 'Blackie',
      handle: '@blackie',
      time: '18 分钟前',
      title: '昨晚主舞台 01:30 之后的连续推进非常顺，灯光切面和低频控制几乎踩在同一拍点上。',
      body: '最舒服的是它没有急着堆高潮，而是把凌晨段的情绪一点点抬起来，后半程才真正打开。',
      tag: 'Warehouse 现场记录',
      reason: '因为你最近常看凌晨段路线和 warehouse 现场记录',
      location: '上海 Main Stage',
      liked: '233',
      replies: '84',
      saves: '19',
      palette: ['#443055', '#1E2431', '#0B0D12'],
    },
    {
      id: 'feed-2',
      author: 'YURI',
      handle: '@yurimoves',
      time: '46 分钟前',
      title: 'Vision Wave 的 Garden 场在 02:40 切过去刚好，能躲开两次主通道回卷的人流。',
      body: '如果你是凌晨段路线党，这一段的移动成本会比在 Main 和 Side 之间来回折返低很多。',
      tag: '路线笔记',
      reason: '因为你收藏过 Vision Wave 的路线笔记',
      location: 'Vision Wave 2026 · Garden 场',
      liked: '162',
      replies: '41',
      saves: '37',
      palette: ['#22445E', '#16222C', '#0B0D12'],
    },
  ],
  following: [
    {
      id: 'feed-3',
      author: 'NORA',
      handle: '@nora',
      time: '1 小时前',
      title: 'Riverfront 的 sunrise 段已经放出新的排布图，左侧通道会提前半小时开放。',
      body: '如果你想抢前排但又不想被回流挤出来，建议 04:20 之后再往前压。',
      tag: '关注 DJ 动态',
      reason: '因为你关注了 NORA',
      location: 'Riverfront Hall',
      liked: '98',
      replies: '22',
      saves: '15',
      palette: ['#3D2B4C', '#15202A', '#0B0D12'],
    },
  ],
  latest: [
    {
      id: 'feed-4',
      author: 'Soma Room',
      handle: '@somaroom',
      time: '刚刚',
      title: '今晚 open air 因天气原因提前改到仓库空间，入场动线和存包点同步更新。',
      body: '新的路线图已经挂在活动详情里，建议先看一遍再出发。',
      tag: '活动更新',
      reason: '因为你最近浏览过这场活动详情',
      location: 'Unit 09 Warehouse',
      liked: '41',
      replies: '17',
      saves: '6',
      palette: ['#4C3131', '#20262E', '#0B0D12'],
    },
  ],
};

const SQUADS: Record<SquadModeKey, SquadCard[]> = {
  plaza: [
    {
      id: 'squad-1',
      name: 'Warehouse Signal',
      leader: 'Blackie',
      region: 'IP地区：上海',
      members: '34 人',
      palette: ['#FB9A42', '#C95839', '#392114'],
    },
    {
      id: 'squad-2',
      name: 'Sunrise Route Lab',
      leader: 'Nina',
      region: 'IP地区：杭州',
      members: '27 人',
      palette: ['#F58A44', '#AC3147', '#34161C'],
    },
    {
      id: 'squad-3',
      name: 'Berlin Groove Club',
      leader: 'Karin',
      region: 'IP地区：北京',
      members: '19 人',
      palette: ['#F5A74F', '#E15B48', '#341813'],
    },
    {
      id: 'squad-4',
      name: '凌晨段路线党',
      leader: 'YURI',
      region: 'IP地区：成都',
      members: '46 人',
      palette: ['#FFB454', '#C7493A', '#3A1B15'],
    },
  ],
  mine: [
    {
      id: 'squad-5',
      name: 'Main Stage Patrol',
      leader: 'Blackie',
      region: 'IP地区：上海',
      members: '12 人',
      palette: ['#F6A54B', '#D24C40', '#341C16'],
    },
    {
      id: 'squad-6',
      name: 'Open Air Checklist',
      leader: 'Momo',
      region: 'IP地区：苏州',
      members: '8 人',
      palette: ['#F8A04E', '#B64846', '#371A18'],
    },
  ],
};

const ID_ENTRIES: IDEntry[] = [
  {
    id: 'id-1',
    songName: 'Aurora Line (Warehouse Edit)',
    event: 'Vision Wave 2026 Shanghai Opening',
    artists: 'NORA, KARIN',
    contributor: 'Blackie',
    createdAt: '今天 02:18',
    likes: '128',
    comments: '24',
    palette: ['#7A56F7', '#2A2241', '#13101B'],
  },
  {
    id: 'id-2',
    songName: 'Night Engine',
    event: 'Storm Festival Main Season',
    artists: 'KASIA',
    contributor: 'YURI',
    createdAt: '昨天 23:46',
    likes: '76',
    comments: '11',
    palette: ['#865DFF', '#33244F', '#16111E'],
  },
];

const RATING_EVENTS: RatingEvent[] = [
  {
    id: 'rating-1',
    title: 'Vision Wave 2026 Shanghai Opening',
    description: '主舞台、Garden、动线和灯光系统已建立评分单元，适合活动结束后统一复盘。',
    publisher: 'Blackie',
    units: '12 个单位',
    average: 8.7,
    palette: ['#2C4B5F', '#10151B'],
  },
  {
    id: 'rating-2',
    title: 'Riverfront Sunrise Session',
    description: '加入了开场、sunrise、返场三个关键时段的评分，适合对比不同阶段的体验变化。',
    publisher: 'Nina',
    units: '9 个单位',
    average: 9.1,
    palette: ['#523144', '#161117'],
  },
];

export function CircleHomeView({ bottomInset }: CircleHomeViewProps) {
  const { width } = useWindowDimensions();
  const [section, setSection] = useState<CircleSectionKey>('feed');
  const [feedMode, setFeedMode] = useState<FeedModeKey>('recommended');
  const [squadMode, setSquadMode] = useState<SquadModeKey>('plaza');
  const indicatorX = useRef(new Animated.Value(0)).current;
  const indicatorWidth = useRef(new Animated.Value(0)).current;
  const layoutsRef = useRef<Partial<Record<CircleSectionKey, MeasuredLayout>>>(
    {},
  );
  const scrollRef = useRef<ScrollView>(null);
  const [layoutVersion, setLayoutVersion] = useState(0);
  const hasIndicatorReadyRef = useRef(false);

  const cardColumnWidth = useMemo(
    () => Math.max(148, (width - 32 - 12) / 2),
    [width],
  );

  useEffect(() => {
    const activeLayout = layoutsRef.current[section];
    if (!activeLayout) {
      return;
    }

    scrollRef.current?.scrollTo({
      x: Math.max(activeLayout.x - width * 0.36, 0),
      animated: hasIndicatorReadyRef.current,
    });

    if (!hasIndicatorReadyRef.current) {
      indicatorX.setValue(activeLayout.x);
      indicatorWidth.setValue(activeLayout.width);
      hasIndicatorReadyRef.current = true;
      return;
    }

    Animated.parallel([
      Animated.timing(indicatorX, {
        toValue: activeLayout.x,
        duration: 180,
        useNativeDriver: false,
      }),
      Animated.timing(indicatorWidth, {
        toValue: activeLayout.width,
        duration: 180,
        useNativeDriver: false,
      }),
    ]).start();
  }, [indicatorWidth, indicatorX, layoutVersion, section, width]);

  function renderTopTabs() {
    const activeColor =
      CIRCLE_SECTIONS.find(item => item.key === section)?.color ??
      CIRCLE_THEME.accent;

    return (
      <View style={styles.topTabsWrap}>
        <ScrollView
          ref={scrollRef}
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.topTabsContent}
        >
          <View style={styles.topTabsRow}>
            {CIRCLE_SECTIONS.map(item => {
              const selected = item.key === section;
              return (
                <Pressable
                  key={item.key}
                  onLayout={event => {
                    layoutsRef.current[item.key] = {
                      x: event.nativeEvent.layout.x,
                      width: event.nativeEvent.layout.width,
                    };
                    setLayoutVersion(value => value + 1);
                  }}
                  onPress={() => setSection(item.key)}
                  style={styles.topTabButton}
                >
                  <Text
                    style={[
                      styles.topTabText,
                      selected && styles.topTabTextSelected,
                    ]}
                  >
                    {item.label}
                  </Text>
                </Pressable>
              );
            })}
            <Animated.View
              pointerEvents="none"
              style={[
                styles.topTabIndicator,
                {
                  backgroundColor: activeColor,
                  transform: [{ translateX: indicatorX }],
                  width: indicatorWidth,
                },
              ]}
            />
          </View>
        </ScrollView>
      </View>
    );
  }

  function renderFeedSection() {
    const posts = FEED_POSTS[feedMode];

    return (
      <View style={styles.sectionFill}>
        <View style={styles.segmentedShell}>
          {FEED_MODES.map((mode, index) => {
            const selected = mode.key === feedMode;
            return (
              <Pressable
                key={mode.key}
                onPress={() => setFeedMode(mode.key)}
                style={[
                  styles.segmentedButton,
                  index > 0 && styles.segmentedButtonGap,
                ]}
              >
                {selected ? (
                  <LinearGradient
                    colors={['#A26DFF', '#7C54FF', '#5E3DE9']}
                    start={{ x: 0, y: 0 }}
                    end={{ x: 1, y: 1 }}
                    style={styles.segmentedActiveFill}
                  >
                    <Ionicons
                      name={mode.icon}
                      size={14}
                      color={CIRCLE_THEME.primaryText}
                    />
                    <Text
                      style={[
                        styles.segmentedLabel,
                        styles.segmentedLabelSelected,
                      ]}
                    >
                      {mode.label}
                    </Text>
                  </LinearGradient>
                ) : (
                  <>
                    <Ionicons
                      name={mode.icon}
                      size={14}
                      color={CIRCLE_THEME.secondaryText}
                    />
                    <Text style={styles.segmentedLabel}>{mode.label}</Text>
                  </>
                )}
              </Pressable>
            );
          })}
        </View>

        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={{
            paddingHorizontal: 16,
            paddingTop: 10,
            paddingBottom: bottomInset + 112,
          }}
        >
          {posts.map(post => (
            <View key={post.id} style={styles.feedCard}>
              <LinearGradient
                pointerEvents="none"
                colors={[
                  'rgba(255,255,255,0.04)',
                  'rgba(255,255,255,0)',
                  'rgba(255,255,255,0)',
                ]}
                locations={[0, 0.18, 1]}
                style={styles.feedCardSheen}
              />
              <View style={styles.feedHeaderRow}>
                <View style={styles.feedAvatar}>
                  <LinearGradient
                    colors={['#A368FF', '#5D41F2']}
                    start={{ x: 0, y: 0 }}
                    end={{ x: 1, y: 1 }}
                    style={styles.feedAvatarFill}
                  >
                    <Text style={styles.feedAvatarText}>
                      {post.author.slice(0, 2).toUpperCase()}
                    </Text>
                  </LinearGradient>
                </View>

                <View style={styles.feedHeaderMeta}>
                  <Text style={styles.feedAuthorName}>{post.author}</Text>
                  <Text style={styles.feedHandleText}>
                    {post.handle} · {post.time}
                  </Text>
                </View>

                <Pressable style={styles.feedMoreButton}>
                  <Ionicons
                    name="ellipsis-horizontal"
                    size={16}
                    color={CIRCLE_THEME.secondaryText}
                  />
                </Pressable>
              </View>

              <Text style={styles.feedTitle}>{post.title}</Text>
              <Text style={styles.feedBody}>{post.body}</Text>

              <View style={styles.feedReasonRow}>
                <Ionicons
                  name="sparkles"
                  size={12}
                  color={CIRCLE_THEME.secondaryText}
                />
                <Text style={styles.feedReasonText}>{post.reason}</Text>
              </View>

              <LinearGradient
                colors={post.palette}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.feedMedia}
              >
                <LinearGradient
                  colors={[
                    'rgba(255,255,255,0.04)',
                    'rgba(255,255,255,0)',
                    'rgba(0,0,0,0.52)',
                  ]}
                  locations={[0, 0.38, 1]}
                  style={StyleSheet.absoluteFillObject}
                />
                <View style={styles.feedMediaChip}>
                  <Text style={styles.feedMediaChipText}>{post.tag}</Text>
                </View>
              </LinearGradient>

              <Pressable style={styles.locationPill}>
                <Ionicons
                  name="location-outline"
                  size={12}
                  color={CIRCLE_THEME.secondaryText}
                />
                <Text style={styles.locationPillText}>{post.location}</Text>
              </Pressable>

              <View style={styles.feedMetricsDivider} />
              <View style={styles.feedMetricsRow}>
                <Pressable style={styles.feedMetricItem}>
                  <Ionicons
                    name="chatbubble-ellipses-outline"
                    size={14}
                    color={CIRCLE_THEME.secondaryText}
                  />
                  <Text style={styles.feedMetricText}>{post.replies}</Text>
                </Pressable>
                <Pressable style={styles.feedMetricItem}>
                  <Ionicons
                    name="heart-outline"
                    size={14}
                    color={CIRCLE_THEME.secondaryText}
                  />
                  <Text style={styles.feedMetricText}>{post.liked}</Text>
                </Pressable>
                <Pressable style={styles.feedMetricItem}>
                  <Ionicons
                    name="bookmark-outline"
                    size={14}
                    color={CIRCLE_THEME.secondaryText}
                  />
                  <Text style={styles.feedMetricText}>{post.saves}</Text>
                </Pressable>
                <View style={styles.feedMetricSpacer} />
                <Pressable style={styles.feedMetricMoreButton}>
                  <Ionicons
                    name="ellipsis-horizontal"
                    size={16}
                    color={CIRCLE_THEME.secondaryText}
                  />
                </Pressable>
              </View>
            </View>
          ))}
        </ScrollView>

        <Pressable
          style={[styles.composeButton, { bottom: bottomInset + 24 }]}
        >
          <Ionicons name="add" size={24} color="#FFFFFF" />
        </Pressable>
      </View>
    );
  }

  function renderSquadsSection() {
    const items = SQUADS[squadMode];

    return (
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{
          paddingHorizontal: 16,
          paddingTop: 8,
          paddingBottom: bottomInset + 36,
        }}
      >
        <View style={styles.sectionHeaderRow}>
          <Text style={styles.sectionTitle}>小队广场</Text>
          <Pressable style={styles.headerCapsuleButton}>
            <Ionicons name="add-circle" size={16} color="#F5F5F7" />
            <Text style={styles.headerCapsuleButtonText}>创建小队</Text>
          </Pressable>
        </View>

        <View style={styles.segmentedShell}>
          {[
            { key: 'plaza' as const, label: '小队广场' },
            { key: 'mine' as const, label: '我的小队' },
          ].map((mode, index) => {
            const selected = squadMode === mode.key;
            return (
              <Pressable
                key={mode.key}
                onPress={() => setSquadMode(mode.key)}
                style={[
                  styles.segmentedButton,
                  selected && styles.segmentedButtonSelected,
                  index > 0 && styles.segmentedButtonGap,
                ]}
              >
                <Text
                  style={[
                    styles.segmentedLabel,
                    selected && styles.segmentedLabelSelected,
                  ]}
                >
                  {mode.label}
                </Text>
              </Pressable>
            );
          })}
        </View>

        <View style={styles.squadGrid}>
          {items.map((item, index) => (
            <Pressable
              key={item.id}
              style={[
                styles.squadCard,
                {
                  width: cardColumnWidth,
                  marginRight: index % 2 === 0 ? 12 : 0,
                },
              ]}
            >
              <LinearGradient
                colors={item.palette}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.squadCardFill}
              >
                <LinearGradient
                  colors={[
                    'rgba(0,0,0,0.18)',
                    'rgba(0,0,0,0.50)',
                    'rgba(0,0,0,0.78)',
                  ]}
                  locations={[0, 0.58, 1]}
                  style={StyleSheet.absoluteFillObject}
                />
                <View style={styles.squadCardBody}>
                  <Text style={styles.squadCardTitle}>{item.name}</Text>
                  <View style={styles.squadLeaderRow}>
                    <View style={styles.squadLeaderAvatar}>
                      <Text style={styles.squadLeaderAvatarText}>
                        {item.leader.slice(0, 1).toUpperCase()}
                      </Text>
                    </View>
                    <Text style={styles.squadLeaderText}>
                      队长 {item.leader}
                    </Text>
                  </View>
                  <View style={styles.squadMetaRow}>
                    <Text style={styles.squadMetaText}>{item.region}</Text>
                    <Text style={styles.squadMetaDivider}>·</Text>
                    <Text style={styles.squadMetaText}>{item.members}</Text>
                  </View>
                </View>
              </LinearGradient>
            </Pressable>
          ))}
        </View>
      </ScrollView>
    );
  }

  function renderIDsSection() {
    return (
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{
          paddingHorizontal: 16,
          paddingTop: 8,
          paddingBottom: bottomInset + 36,
        }}
      >
        <View style={styles.sectionHeaderRow}>
          <Text style={styles.sectionTitle}>ID（未发行）</Text>
          <Pressable style={styles.headerCapsuleButton}>
            <Ionicons name="add-circle" size={16} color="#F5F5F7" />
            <Text style={styles.headerCapsuleButtonText}>发布 ID</Text>
          </Pressable>
        </View>

        {ID_ENTRIES.map(item => (
          <View key={item.id} style={styles.idCard}>
            <LinearGradient
              colors={item.palette}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.idArtwork}
            >
              <View style={styles.idArtworkBadge}>
                <Ionicons name="musical-notes" size={12} color="#FFFFFF" />
                <Text style={styles.idArtworkBadgeText}>未发行</Text>
              </View>
            </LinearGradient>

            <View style={styles.idContent}>
              <View style={styles.idTitleRow}>
                <Text style={styles.idTitle}>{item.songName}</Text>
                <Ionicons
                  name="chevron-forward"
                  size={14}
                  color={CIRCLE_THEME.secondaryText}
                />
              </View>
              <Text style={styles.idSubline}>{item.artists}</Text>
              <Text style={styles.idSubline}>{item.event}</Text>

              <View style={styles.idMetaRow}>
                <Text style={styles.idMetaText}>贡献者：{item.contributor}</Text>
                <Text style={styles.idMetaDivider}>·</Text>
                <Text style={styles.idMetaText}>{item.createdAt}</Text>
              </View>

              <View style={styles.idMetricsRow}>
                <View style={styles.idMetricItem}>
                  <Ionicons
                    name="heart"
                    size={13}
                    color={CIRCLE_THEME.secondaryText}
                  />
                  <Text style={styles.idMetricText}>{item.likes}</Text>
                </View>
                <View style={styles.idMetricItem}>
                  <Ionicons
                    name="chatbubble-outline"
                    size={13}
                    color={CIRCLE_THEME.secondaryText}
                  />
                  <Text style={styles.idMetricText}>{item.comments}</Text>
                </View>
              </View>
            </View>
          </View>
        ))}
      </ScrollView>
    );
  }

  function renderRatingStars(score: number) {
    return (
      <View style={styles.ratingStarsRow}>
        {[0, 1, 2, 3, 4].map(index => {
          const starValue = (index + 1) * 2;
          let icon: keyof typeof Ionicons.glyphMap = 'star-outline';
          if (score >= starValue) {
            icon = 'star';
          } else if (score >= starValue - 1) {
            icon = 'star-half';
          }

          return (
            <Ionicons
              key={`${score}-${index}`}
              name={icon}
              size={12}
              color="#F3B94A"
            />
          );
        })}
      </View>
    );
  }

  function renderRatingsSection() {
    return (
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{
          paddingHorizontal: 16,
          paddingTop: 8,
          paddingBottom: bottomInset + 36,
        }}
      >
        <View style={styles.sectionHeaderRow}>
          <Text style={styles.sectionTitle}>事件驱动打分</Text>
          <View style={styles.ratingActionsRow}>
            <Pressable style={styles.smallHeaderButton}>
              <Ionicons name="download-outline" size={13} color="#F5F5F7" />
              <Text style={styles.smallHeaderButtonText}>从活动导入</Text>
            </Pressable>
            <Pressable style={styles.smallHeaderButton}>
              <Ionicons name="add" size={13} color="#F5F5F7" />
              <Text style={styles.smallHeaderButtonText}>发布事件</Text>
            </Pressable>
          </View>
        </View>

        {RATING_EVENTS.map(item => (
          <View key={item.id} style={styles.ratingCard}>
            <LinearGradient
              colors={item.palette}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.ratingArtwork}
            >
              <Ionicons name="sparkles" size={20} color="#FFFFFF" />
            </LinearGradient>

            <View style={styles.ratingContent}>
              <View style={styles.ratingTitleRow}>
                <Text style={styles.ratingTitle}>{item.title}</Text>
                <Ionicons
                  name="chevron-forward"
                  size={14}
                  color={CIRCLE_THEME.secondaryText}
                />
              </View>
              <Text style={styles.ratingBody}>{item.description}</Text>
              <Text style={styles.ratingPublisher}>
                发布者：{item.publisher}
              </Text>

              <View style={styles.ratingFooterRow}>
                <Text style={styles.ratingMetaText}>{item.units}</Text>
                <Text style={styles.ratingMetaDivider}>·</Text>
                <Text style={styles.ratingMetaText}>
                  均分 {item.average.toFixed(1)}/10
                </Text>
                <View style={styles.ratingFooterSpacer} />
                {renderRatingStars(item.average)}
              </View>
            </View>
          </View>
        ))}
      </ScrollView>
    );
  }

  function renderSectionContent() {
    switch (section) {
      case 'feed':
        return renderFeedSection();
      case 'squads':
        return renderSquadsSection();
      case 'ids':
        return renderIDsSection();
      case 'ratings':
        return renderRatingsSection();
      default:
        return null;
    }
  }

  return (
    <View style={styles.screen}>
      {renderTopTabs()}
      <View style={styles.contentFill}>{renderSectionContent()}</View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: CIRCLE_THEME.background,
  },
  contentFill: {
    flex: 1,
  },
  sectionFill: {
    flex: 1,
  },
  topTabsWrap: {
    paddingTop: 8,
  },
  topTabsContent: {
    paddingHorizontal: 16,
  },
  topTabsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    position: 'relative',
    paddingBottom: 10,
  },
  topTabButton: {
    paddingRight: 24,
    paddingBottom: 6,
  },
  topTabText: {
    fontSize: 18,
    fontWeight: '400',
    color: CIRCLE_THEME.secondaryText,
  },
  topTabTextSelected: {
    color: CIRCLE_THEME.primaryText,
  },
  topTabIndicator: {
    position: 'absolute',
    left: 0,
    bottom: 0,
    height: 3,
    borderRadius: 999,
  },
  segmentedShell: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: 16,
    marginTop: 2,
    padding: 4,
    borderRadius: 14,
    backgroundColor: '#111116',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: CIRCLE_THEME.cardBorder,
  },
  segmentedButton: {
    flex: 1,
    minHeight: 38,
    borderRadius: 11,
    alignItems: 'center',
    justifyContent: 'center',
    flexDirection: 'row',
  },
  segmentedButtonGap: {
    marginLeft: 6,
  },
  segmentedButtonSelected: {
    backgroundColor: CIRCLE_THEME.accent,
  },
  segmentedActiveFill: {
    flex: 1,
    minHeight: 38,
    borderRadius: 11,
    alignItems: 'center',
    justifyContent: 'center',
    flexDirection: 'row',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.14)',
  },
  segmentedLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: CIRCLE_THEME.secondaryText,
  },
  segmentedLabelSelected: {
    color: CIRCLE_THEME.primaryText,
  },
  feedCard: {
    position: 'relative',
    marginBottom: 12,
    padding: 14,
    borderRadius: 20,
    backgroundColor: CIRCLE_THEME.card,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: CIRCLE_THEME.cardBorder,
    overflow: 'hidden',
    shadowColor: '#000000',
    shadowOpacity: 0.16,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 8 },
    elevation: 6,
  },
  feedCardSheen: {
    ...StyleSheet.absoluteFillObject,
  },
  feedHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  feedAvatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    overflow: 'hidden',
  },
  feedAvatarFill: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  feedAvatarText: {
    fontSize: 13,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  feedHeaderMeta: {
    flex: 1,
    marginLeft: 10,
  },
  feedAuthorName: {
    fontSize: 15,
    fontWeight: '600',
    color: CIRCLE_THEME.primaryText,
  },
  feedHandleText: {
    marginTop: 2,
    fontSize: 12,
    color: CIRCLE_THEME.secondaryText,
  },
  feedMoreButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  feedTitle: {
    marginTop: 12,
    fontSize: 16,
    lineHeight: 23,
    fontWeight: '600',
    color: CIRCLE_THEME.primaryText,
  },
  feedBody: {
    marginTop: 8,
    fontSize: 14,
    lineHeight: 21,
    color: CIRCLE_THEME.tertiaryText,
  },
  feedReasonRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 10,
  },
  feedReasonText: {
    marginLeft: 6,
    flex: 1,
    fontSize: 12,
    fontWeight: '600',
    color: CIRCLE_THEME.secondaryText,
  },
  feedMedia: {
    marginTop: 14,
    height: 188,
    borderRadius: 18,
    overflow: 'hidden',
    justifyContent: 'space-between',
    paddingTop: 12,
  },
  feedMediaChip: {
    alignSelf: 'flex-start',
    marginLeft: 12,
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 999,
    backgroundColor: 'rgba(0,0,0,0.36)',
  },
  feedMediaChipText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  locationPill: {
    alignSelf: 'flex-start',
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 12,
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 999,
    backgroundColor: '#1A1A20',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.08)',
  },
  locationPillText: {
    marginLeft: 5,
    fontSize: 11,
    fontWeight: '600',
    color: CIRCLE_THEME.secondaryText,
  },
  feedMetricsDivider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: 'rgba(255,255,255,0.08)',
    marginTop: 12,
  },
  feedMetricsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 12,
  },
  feedMetricItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 16,
    minHeight: 24,
  },
  feedMetricText: {
    marginLeft: 5,
    fontSize: 12,
    color: CIRCLE_THEME.secondaryText,
  },
  feedMetricSpacer: {
    flex: 1,
  },
  feedMetricMoreButton: {
    width: 28,
    height: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
  composeButton: {
    position: 'absolute',
    right: 18,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: CIRCLE_THEME.accent,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000000',
    shadowOpacity: 0.28,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 7 },
    elevation: 10,
  },
  sectionHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: CIRCLE_THEME.primaryText,
  },
  headerCapsuleButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderRadius: 999,
    backgroundColor: CIRCLE_THEME.card,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: CIRCLE_THEME.cardBorder,
  },
  headerCapsuleButtonText: {
    marginLeft: 6,
    fontSize: 13,
    fontWeight: '600',
    color: CIRCLE_THEME.primaryText,
  },
  squadGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  squadCard: {
    marginBottom: 12,
    aspectRatio: 1.5,
    backgroundColor: CIRCLE_THEME.card,
  },
  squadCardFill: {
    flex: 1,
  },
  squadCardBody: {
    flex: 1,
    justifyContent: 'flex-end',
    paddingHorizontal: 10,
    paddingVertical: 10,
  },
  squadCardTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  squadLeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 7,
  },
  squadLeaderAvatar: {
    width: 16,
    height: 16,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(255,255,255,0.18)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.38)',
  },
  squadLeaderAvatarText: {
    fontSize: 9,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  squadLeaderText: {
    marginLeft: 6,
    fontSize: 10,
    fontWeight: '600',
    color: 'rgba(255,255,255,0.94)',
  },
  squadMetaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
  },
  squadMetaText: {
    fontSize: 10,
    fontWeight: '600',
    color: 'rgba(255,255,255,0.92)',
  },
  squadMetaDivider: {
    marginHorizontal: 6,
    fontSize: 10,
    color: 'rgba(255,255,255,0.70)',
  },
  idCard: {
    flexDirection: 'row',
    marginBottom: 12,
    padding: 12,
    borderRadius: 18,
    backgroundColor: CIRCLE_THEME.card,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: CIRCLE_THEME.cardBorder,
  },
  idArtwork: {
    width: 74,
    height: 74,
    borderRadius: 16,
    padding: 10,
    justifyContent: 'flex-start',
  },
  idArtworkBadge: {
    alignSelf: 'flex-start',
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 999,
    backgroundColor: 'rgba(255,255,255,0.14)',
  },
  idArtworkBadgeText: {
    marginLeft: 5,
    fontSize: 10,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  idContent: {
    flex: 1,
    marginLeft: 12,
  },
  idTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  idTitle: {
    flex: 1,
    fontSize: 15,
    fontWeight: '700',
    color: CIRCLE_THEME.primaryText,
  },
  idSubline: {
    marginTop: 4,
    fontSize: 12,
    lineHeight: 18,
    color: CIRCLE_THEME.secondaryText,
  },
  idMetaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    flexWrap: 'wrap',
    marginTop: 8,
  },
  idMetaText: {
    fontSize: 11,
    color: CIRCLE_THEME.secondaryText,
  },
  idMetaDivider: {
    marginHorizontal: 6,
    fontSize: 11,
    color: CIRCLE_THEME.secondaryText,
  },
  idMetricsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 9,
  },
  idMetricItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 14,
  },
  idMetricText: {
    marginLeft: 4,
    fontSize: 11,
    color: CIRCLE_THEME.secondaryText,
  },
  ratingActionsRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  smallHeaderButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderRadius: 999,
    backgroundColor: CIRCLE_THEME.card,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: CIRCLE_THEME.cardBorder,
  },
  smallHeaderButtonText: {
    marginLeft: 5,
    fontSize: 12,
    fontWeight: '600',
    color: CIRCLE_THEME.primaryText,
  },
  ratingCard: {
    flexDirection: 'row',
    marginBottom: 12,
    padding: 12,
    borderRadius: 18,
    backgroundColor: CIRCLE_THEME.card,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: CIRCLE_THEME.cardBorder,
  },
  ratingArtwork: {
    width: 72,
    height: 72,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ratingContent: {
    flex: 1,
    marginLeft: 12,
  },
  ratingTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  ratingTitle: {
    flex: 1,
    fontSize: 15,
    fontWeight: '700',
    color: CIRCLE_THEME.primaryText,
  },
  ratingBody: {
    marginTop: 5,
    fontSize: 12,
    lineHeight: 18,
    color: CIRCLE_THEME.secondaryText,
  },
  ratingPublisher: {
    marginTop: 6,
    fontSize: 11,
    color: CIRCLE_THEME.secondaryText,
  },
  ratingFooterRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 10,
  },
  ratingMetaText: {
    fontSize: 11,
    fontWeight: '600',
    color: CIRCLE_THEME.secondaryText,
  },
  ratingMetaDivider: {
    marginHorizontal: 6,
    fontSize: 11,
    color: CIRCLE_THEME.secondaryText,
  },
  ratingFooterSpacer: {
    flex: 1,
  },
  ratingStarsRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
});
