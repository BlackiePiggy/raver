import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import React, { useMemo, useState } from 'react';
import {
  Modal,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  useWindowDimensions,
  View,
} from 'react-native';

type ProfileHomeViewProps = {
  bottomInset: number;
};

type ProfileSectionKey = 'published' | 'saves' | 'likes';
type ProfilePageKey = 'settings' | 'publishes' | 'savesHub' | 'routes' | 'tools';
type SaveSegmentKey = 'events' | 'djs';

type ProfileStat = {
  label: string;
  value: string;
};

type ProfileQuickAction = {
  key: string;
  label: string;
  icon: keyof typeof Ionicons.glyphMap;
  accent: string;
};

type ProfileCheckinPreview = {
  id: string;
  title: string;
  subtitle: string;
};

type ProfileFeedCard = {
  id: string;
  category: string;
  title: string;
  summary: string;
  publishedAt: string;
  metrics: [string, string, string];
  palette: [string, string];
};

type ProfileSubpageItem = {
  id: string;
  title: string;
  subtitle: string;
  meta?: string;
  icon?: keyof typeof Ionicons.glyphMap;
  palette?: [string, string];
};

const PROFILE_THEME = {
  background: '#08080A',
  card: '#141419',
  surface: '#101015',
  border: 'rgba(255,255,255,0.08)',
  primaryText: '#F5F5F7',
  secondaryText: '#A3A3AD',
  tertiaryText: 'rgba(255,255,255,0.68)',
  accent: '#8C5CFF',
  accentEnd: '#5735E6',
  teal: '#45D9D1',
  orange: '#F39B43',
  rose: '#E86591',
};

const PROFILE_HEADER = {
  displayName: 'Blackie',
  location: '上海',
  joinedDays: '加入 1280 天',
  bio: 'Warehouse、Techno、Open Air、凌晨段控场。会写活动记录，也会做路线和收藏。',
  tags: ['Techno', 'Warehouse', 'Open Air', 'Berlin Groove', 'Night Drive'],
  stats: [
    { label: '动态', value: '148' },
    { label: '粉丝', value: '3.4k' },
    { label: '关注', value: '421' },
    { label: '好友', value: '89' },
  ] satisfies ProfileStat[],
};

const PROFILE_QUICK_ACTIONS: ProfileQuickAction[] = [
  { key: 'publishes', label: '我的发布', icon: 'layers-outline', accent: PROFILE_THEME.accent },
  { key: 'saves', label: '我的收藏', icon: 'star', accent: '#F6B24B' },
  { key: 'routes', label: '我的路线', icon: 'navigate-outline', accent: '#55B7F3' },
  { key: 'tools', label: '小工具', icon: 'sparkles-outline', accent: '#E86591' },
];

const PROFILE_CHECKINS: ProfileCheckinPreview[] = [
  {
    id: 'checkin-1',
    title: 'Vision Wave 2026 Shanghai Opening',
    subtitle: '2026.06.21 · 上海 · Main Stage Warehouse',
  },
  {
    id: 'checkin-2',
    title: 'NORA @ Riverfront Hall',
    subtitle: '2026.05.28 · 成都 · 现场打卡',
  },
  {
    id: 'checkin-3',
    title: 'Storm Festival Main Season',
    subtitle: '2026.05.11 · 上海 · 仓库路线已保存',
  },
];

const PROFILE_SECTIONS: Array<{
  key: ProfileSectionKey;
  label: string;
  icon: keyof typeof Ionicons.glyphMap;
}> = [
  { key: 'published', label: '动态', icon: 'grid-outline' },
  { key: 'saves', label: '收藏', icon: 'star-outline' },
  { key: 'likes', label: 'Like', icon: 'heart-outline' },
];

const PROFILE_FEEDS: Record<ProfileSectionKey, ProfileFeedCard[]> = {
  published: [
    {
      id: 'post-1',
      category: '现场记录',
      title: '昨晚主舞台 01:30 之后的连续推进非常顺，灯光切面和低频都做到了同一拍点上。',
      summary: '这场最舒服的是它没有急着堆高潮，而是把凌晨后的情绪层层叠起来，留给后半段更多空间。',
      publishedAt: '2026.06.03 20:18',
      metrics: ['84 回复', '233 喜欢', '19 收藏'],
      palette: ['#32283C', '#16131A'],
    },
    {
      id: 'post-2',
      category: '路线笔记',
      title: '给 Vision Wave 做了一条更适合凌晨段的听感路线，避开两次大规模人流回卷。',
      summary: '如果 00:30 先留在 Main，02:40 再切 Garden，整体体感会比来回折返舒服得多。',
      publishedAt: '2026.06.02 12:07',
      metrics: ['41 回复', '162 喜欢', '37 收藏'],
      palette: ['#203544', '#10141A'],
    },
  ],
  saves: [
    {
      id: 'save-1',
      category: '收藏帖子',
      title: '今年 open air 的舞台系统为什么都在回到更克制的灯光密度',
      summary: '一篇关于日落场与海边场地光污染控制的长文，里面提到的节奏密度非常有参考价值。',
      publishedAt: '保存于 2026.06.01',
      metrics: ['读完 8 分钟', '已收藏', '分享 12'],
      palette: ['#243A2E', '#101513'],
    },
  ],
  likes: [
    {
      id: 'like-1',
      category: 'Like 过的帖子',
      title: '成都 Riverfront 那晚开场的 warm-up 为什么会比 headliner 还让人上头',
      summary: '评论区关于 support 排布和城市夜场情绪的讨论很完整，值得回看。',
      publishedAt: 'Like 于 2026.05.31',
      metrics: ['96 回复', '已 Like', '8 转发'],
      palette: ['#35251F', '#151210'],
    },
  ],
};

const PROFILE_PAGE_TITLES: Record<ProfilePageKey, string> = {
  settings: '设置',
  publishes: '我的发布',
  savesHub: '我的收藏',
  routes: '我的路线',
  tools: '小工具',
};

const PROFILE_PUBLISHES: ProfileSubpageItem[] = [
  {
    id: 'publish-1',
    title: 'Vision Wave 2026 Shanghai Opening',
    subtitle: '活动发布 · 上海 · Main Stage Warehouse',
    meta: '2026.06.21 23:00',
    palette: ['#244B57', '#0E121A'],
  },
  {
    id: 'publish-2',
    title: 'Warehouse Sunrise Notes',
    subtitle: '帖子发布 · 凌晨段路线和听感记录',
    meta: '2026.06.02 12:07',
    palette: ['#3D2940', '#17131A'],
  },
  {
    id: 'publish-3',
    title: 'NORA Sunrise Mix for Riverfront Session',
    subtitle: 'Sets 发布 · 关联 DJ NORA',
    meta: '2026.05.26 18:42',
    palette: ['#223D57', '#10151B'],
  },
];

const PROFILE_SAVED_EVENTS: ProfileSubpageItem[] = [
  {
    id: 'saved-event-1',
    title: 'Sunset Frequency Open Air',
    subtitle: '深圳 · Coastline Park',
    meta: '2026.07.05 周日',
    palette: ['#17506A', '#101822'],
  },
  {
    id: 'saved-event-2',
    title: 'Warehouse Motion All Night Long',
    subtitle: '北京 · Unit 09 Warehouse',
    meta: '2026.07.12 周六',
    palette: ['#5B263B', '#18131A'],
  },
];

const PROFILE_FOLLOWED_DJS: ProfileSubpageItem[] = [
  {
    id: 'followed-dj-1',
    title: 'NORA',
    subtitle: 'Berlin · Melodic Techno / Progressive House',
    meta: '3.2k 关注者',
    palette: ['#28415C', '#12161D'],
  },
  {
    id: 'followed-dj-2',
    title: 'KARIN',
    subtitle: '上海 · Techno / Warehouse',
    meta: '1.4k 关注者',
    palette: ['#4A274A', '#151118'],
  },
];

const PROFILE_ROUTES: ProfileSubpageItem[] = [
  {
    id: 'route-1',
    title: 'Vision Wave 主舞台凌晨路线',
    subtitle: '已选 4 个演出 · 避开两次大规模回流',
    meta: '更新于 2026.06.03 01:12',
    palette: ['#244B57', '#0E121A'],
  },
  {
    id: 'route-2',
    title: 'Storm Festival 仓库听感路线',
    subtitle: '已选 3 个演出 · 更适合 sunrise 段',
    meta: '更新于 2026.05.11 02:08',
    palette: ['#3A2A3C', '#131116'],
  },
];

const PROFILE_TOOLS: ProfileSubpageItem[] = [
  {
    id: 'tool-1',
    title: '桌面倒计时管理',
    subtitle: '集中管理已加入桌面小组件的活动',
    icon: 'apps-outline',
  },
  {
    id: 'tool-2',
    title: 'Movie Banner 弹幕',
    subtitle: '超大字体全屏弹幕，支持静态与跑马灯',
    icon: 'text-outline',
  },
];

const PROFILE_SETTING_GROUPS: Array<{
  title: string;
  items: Array<{ id: string; label: string; icon: keyof typeof Ionicons.glyphMap }>;
}> = [
  {
    title: '账号设置',
    items: [
      { id: 'edit-profile', label: '编辑资料', icon: 'person-circle-outline' },
      { id: 'privacy', label: '隐私设置', icon: 'shield-half-outline' },
      { id: 'account-status', label: '账号状态', icon: 'alert-circle-outline' },
    ],
  },
  {
    title: '通知设置',
    items: [
      { id: 'push', label: '消息通知', icon: 'notifications-outline' },
      { id: 'appearance', label: '主题设置', icon: 'color-palette-outline' },
      { id: 'language', label: '语言设置', icon: 'globe-outline' },
    ],
  },
];

export function ProfileHomeView({ bottomInset }: ProfileHomeViewProps) {
  const { width, height } = useWindowDimensions();
  const [selectedSection, setSelectedSection] =
    useState<ProfileSectionKey>('published');
  const [selectedSaveSegment, setSelectedSaveSegment] =
    useState<SaveSegmentKey>('events');
  const [activePage, setActivePage] = useState<ProfilePageKey | null>(null);

  const heroHeight = Math.max(252, Math.min(height * 0.33, 292));
  const quickActionColumns = width < 360 ? 4 : 4;
  const quickActionWidth = useMemo(
    () => (width - 32 - (quickActionColumns - 1) * 8) / quickActionColumns,
    [quickActionColumns, width],
  );

  return (
    <ScrollView
      style={styles.screen}
      showsVerticalScrollIndicator={false}
      contentContainerStyle={{ paddingBottom: bottomInset + 22 }}
    >
      <View style={[styles.heroCard, { height: heroHeight }]}>
        <LinearGradient
          colors={['#34244A', '#16202C', '#0B0C11']}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.heroFill}
        />
        <View style={styles.heroGlowLarge} />
        <View style={styles.heroGlowSmall} />
        <LinearGradient
          colors={[
            'rgba(0,0,0,0.04)',
            'rgba(0,0,0,0.26)',
            'rgba(0,0,0,0.72)',
            PROFILE_THEME.background,
          ]}
          locations={[0, 0.34, 0.76, 1]}
          style={styles.heroShade}
        />

        <View style={styles.heroTopActions}>
          <Pressable
            style={styles.heroIconButton}
            onPress={() => setActivePage('settings')}
          >
            <Ionicons
              name="ellipsis-horizontal"
              size={18}
              color={PROFILE_THEME.primaryText}
            />
          </Pressable>
        </View>

        <View style={styles.heroContent}>
          <View style={styles.heroIdentityRow}>
            <LinearGradient
              colors={['#A56AFF', '#6F4EFF']}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.avatarRing}
            >
              <View style={styles.avatarCore}>
                <Text style={styles.avatarText}>BL</Text>
              </View>
            </LinearGradient>

            <View style={styles.heroMeta}>
              <View style={styles.heroTitleRow}>
                <Text style={styles.heroName}>{PROFILE_HEADER.displayName}</Text>
                <Pressable style={styles.qrButton}>
                  <Ionicons
                    name="qr-code-outline"
                    size={16}
                    color={PROFILE_THEME.primaryText}
                  />
                </Pressable>
              </View>

              <View style={styles.heroPillRow}>
                <View style={styles.metaPill}>
                  <Text style={styles.metaPillText}>{PROFILE_HEADER.location}</Text>
                </View>
                <View style={styles.metaPill}>
                  <Text style={styles.metaPillText}>{PROFILE_HEADER.joinedDays}</Text>
                </View>
              </View>
              <View style={styles.heroStatsRowCompact}>
                {PROFILE_HEADER.stats.map(item => (
                  <View key={item.label} style={styles.heroStatCompactItem}>
                    <Text style={styles.heroStatCompactValue}>{item.value}</Text>
                    <Text style={styles.heroStatCompactLabel}>{item.label}</Text>
                  </View>
                ))}
              </View>
            </View>
          </View>
        </View>
      </View>

      <View style={styles.sectionWrap}>
        <Text style={styles.bioText}>{PROFILE_HEADER.bio}</Text>

        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.tagsRow}
        >
          {PROFILE_HEADER.tags.map(tag => (
            <View key={tag} style={styles.tagChip}>
              <Text style={styles.tagText}>{tag}</Text>
            </View>
          ))}
        </ScrollView>
      </View>

      <View style={styles.sectionWrap}>
        <View style={styles.sectionCard}>
          <View style={styles.sectionHeadingRow}>
            <View style={styles.sectionHeadingInline}>
              <Ionicons
                name="checkmark-circle"
                size={16}
                color={PROFILE_THEME.accent}
              />
              <Text style={styles.sectionHeadingTitle}>我的近期打卡</Text>
            </View>
            <Pressable>
              <Text style={styles.sectionLinkText}>查看全部</Text>
            </Pressable>
          </View>

          <View style={styles.checkinList}>
            {PROFILE_CHECKINS.map((item, index) => (
              <View key={item.id} style={styles.checkinRow}>
                <View style={styles.checkinTimeline}>
                  <View style={styles.checkinDot} />
                  {index < PROFILE_CHECKINS.length - 1 ? (
                    <View style={styles.checkinConnector} />
                  ) : null}
                </View>
                <View style={styles.checkinMeta}>
                  <Text style={styles.checkinTitle}>{item.title}</Text>
                  <Text style={styles.checkinSubtitle}>{item.subtitle}</Text>
                </View>
              </View>
            ))}
          </View>
        </View>
      </View>

      <View style={styles.sectionWrap}>
        <View style={styles.sectionCard}>
          <Text style={styles.sectionHeadingTitle}>快捷入口</Text>
          <View style={styles.quickActionsGrid}>
            {PROFILE_QUICK_ACTIONS.map(action => (
              <Pressable
                key={action.key}
                style={[styles.quickActionItem, { width: quickActionWidth }]}
                onPress={() => {
                  if (action.key === 'publishes') {
                    setActivePage('publishes');
                  }
                  if (action.key === 'saves') {
                    setActivePage('savesHub');
                  }
                  if (action.key === 'routes') {
                    setActivePage('routes');
                  }
                  if (action.key === 'tools') {
                    setActivePage('tools');
                  }
                }}
              >
                <View
                  style={[
                    styles.quickActionIconWrap,
                    { backgroundColor: `${action.accent}22` },
                  ]}
                >
                  <Ionicons
                    name={action.icon}
                    size={20}
                    color={action.accent}
                  />
                </View>
                <Text style={styles.quickActionLabel}>{action.label}</Text>
              </Pressable>
            ))}
          </View>
        </View>
      </View>

      <View style={styles.sectionWrap}>
        <View style={styles.segmentedShell}>
          {PROFILE_SECTIONS.map(section => {
            const isSelected = section.key === selectedSection;
            return (
              <Pressable
                key={section.key}
                onPress={() => setSelectedSection(section.key)}
                style={[
                  styles.segmentButton,
                  isSelected && styles.segmentButtonActive,
                ]}
              >
                {isSelected ? (
                  <LinearGradient
                    colors={[PROFILE_THEME.accent, PROFILE_THEME.accentEnd]}
                    start={{ x: 0, y: 0 }}
                    end={{ x: 1, y: 1 }}
                    style={styles.segmentActiveFill}
                  />
                ) : null}
                <View style={styles.segmentInner}>
                  <Ionicons
                    name={section.icon}
                    size={12}
                    color={
                      isSelected
                        ? PROFILE_THEME.primaryText
                        : PROFILE_THEME.secondaryText
                    }
                  />
                  <Text
                    style={[
                      styles.segmentText,
                      isSelected && styles.segmentTextActive,
                    ]}
                  >
                    {section.label}
                  </Text>
                </View>
              </Pressable>
            );
          })}
        </View>

        <View style={styles.feedList}>
          {PROFILE_FEEDS[selectedSection].map(item => (
            <Pressable key={item.id} style={styles.feedCard}>
              <View style={styles.feedHeaderRow}>
                <View style={styles.feedCategoryBadge}>
                  <Text style={styles.feedCategoryText}>{item.category}</Text>
                </View>
                <Text style={styles.feedTime}>{item.publishedAt}</Text>
              </View>

              <Text style={styles.feedTitle}>{item.title}</Text>
              <Text style={styles.feedSummary}>{item.summary}</Text>

              <View style={styles.feedFooterRow}>
                <View style={styles.feedMetrics}>
                  {item.metrics.map(metric => (
                    <Text key={metric} style={styles.feedMetricText}>
                      {metric}
                    </Text>
                  ))}
                </View>
                <LinearGradient
                  colors={item.palette}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={styles.feedThumb}
                >
                  <Ionicons
                    name="radio-outline"
                    size={18}
                    color="rgba(255,255,255,0.86)"
                  />
                </LinearGradient>
              </View>
            </Pressable>
          ))}
        </View>
      </View>
      {renderPageOverlay()}
    </ScrollView>
  );

  function renderSubpageHeader(title: string) {
    return (
      <View style={styles.pageHeader}>
        <Pressable
          style={styles.pageHeaderButton}
          onPress={() => setActivePage(null)}
        >
          <Ionicons
            name="chevron-back"
            size={18}
            color={PROFILE_THEME.primaryText}
          />
        </Pressable>
        <Text style={styles.pageHeaderTitle}>{title}</Text>
        <View style={styles.pageHeaderSpacer} />
      </View>
    );
  }

  function renderEntityCard(item: ProfileSubpageItem) {
    return (
      <Pressable key={item.id} style={styles.subpageCard}>
        <LinearGradient
          colors={item.palette ?? ['#2D2438', '#15131A']}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.subpageThumb}
        >
          <Ionicons
            name="radio-outline"
            size={18}
            color="rgba(255,255,255,0.86)"
          />
        </LinearGradient>
        <View style={styles.subpageMeta}>
          <Text style={styles.subpageTitle}>{item.title}</Text>
          <Text style={styles.subpageSubtitle}>{item.subtitle}</Text>
          {item.meta ? <Text style={styles.subpageMetaText}>{item.meta}</Text> : null}
        </View>
        <Ionicons
          name="chevron-forward"
          size={16}
          color="rgba(255,255,255,0.42)"
        />
      </Pressable>
    );
  }

  function renderSettingsPage() {
    return (
      <ScrollView
        style={styles.pageScroll}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.pageScrollContent}
      >
        {PROFILE_SETTING_GROUPS.map(group => (
          <View key={group.title} style={styles.pageSectionCard}>
            <Text style={styles.pageSectionTitle}>{group.title}</Text>
            <View style={styles.settingsList}>
              {group.items.map((item, index) => (
                <View key={item.id}>
                  <Pressable style={styles.settingsRow}>
                    <View style={styles.settingsRowLead}>
                      <Ionicons
                        name={item.icon}
                        size={18}
                        color={PROFILE_THEME.primaryText}
                      />
                      <Text style={styles.settingsRowLabel}>{item.label}</Text>
                    </View>
                    <Ionicons
                      name="chevron-forward"
                      size={16}
                      color={PROFILE_THEME.secondaryText}
                    />
                  </Pressable>
                  {index < group.items.length - 1 ? (
                    <View style={styles.settingsDivider} />
                  ) : null}
                </View>
              ))}
            </View>
          </View>
        ))}
      </ScrollView>
    );
  }

  function renderPublishesPage() {
    return (
      <ScrollView
        style={styles.pageScroll}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.pageScrollContent}
      >
        <View style={styles.pageSectionCard}>
          <Text style={styles.pageSectionTitle}>我发布的内容</Text>
          <View style={styles.subpageCardList}>
            {PROFILE_PUBLISHES.map(item => renderEntityCard(item))}
          </View>
        </View>
      </ScrollView>
    );
  }

  function renderSavesPage() {
    const saveTabs: Array<{ key: SaveSegmentKey; label: string; icon: keyof typeof Ionicons.glyphMap }> = [
      { key: 'events', label: '收藏活动', icon: 'star-outline' },
      { key: 'djs', label: '关注的DJ', icon: 'headset-outline' },
    ];

    const activeItems =
      selectedSaveSegment === 'events' ? PROFILE_SAVED_EVENTS : PROFILE_FOLLOWED_DJS;

    return (
      <ScrollView
        style={styles.pageScroll}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.pageScrollContent}
      >
        <View style={styles.pageSectionCard}>
          <View style={styles.segmentedShell}>
            {saveTabs.map(tab => {
              const isSelected = selectedSaveSegment === tab.key;
              return (
                <Pressable
                  key={tab.key}
                  style={[
                    styles.segmentButton,
                    isSelected && styles.segmentButtonActive,
                  ]}
                  onPress={() => setSelectedSaveSegment(tab.key)}
                >
                  {isSelected ? (
                    <LinearGradient
                      colors={[PROFILE_THEME.accent, PROFILE_THEME.accentEnd]}
                      start={{ x: 0, y: 0 }}
                      end={{ x: 1, y: 1 }}
                      style={styles.segmentActiveFill}
                    />
                  ) : null}
                  <View style={styles.segmentInner}>
                    <Ionicons
                      name={tab.icon}
                      size={12}
                      color={
                        isSelected
                          ? PROFILE_THEME.primaryText
                          : PROFILE_THEME.secondaryText
                      }
                    />
                    <Text
                      style={[
                        styles.segmentText,
                        isSelected && styles.segmentTextActive,
                      ]}
                    >
                      {tab.label}
                    </Text>
                  </View>
                </Pressable>
              );
            })}
          </View>
          <View style={styles.subpageCardList}>
            {activeItems.map(item => renderEntityCard(item))}
          </View>
        </View>
      </ScrollView>
    );
  }

  function renderRoutesPage() {
    return (
      <ScrollView
        style={styles.pageScroll}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.pageScrollContent}
      >
        <View style={styles.pageSectionCard}>
          <Text style={styles.pageSectionTitle}>我的路线</Text>
          <Text style={styles.pageSectionCaption}>
            按你在时间表中的选择生成，也会显示离线缓存过的活动。
          </Text>
          <View style={styles.subpageCardList}>
            {PROFILE_ROUTES.map(item => renderEntityCard(item))}
          </View>
        </View>
      </ScrollView>
    );
  }

  function renderToolsPage() {
    return (
      <ScrollView
        style={styles.pageScroll}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.pageScrollContent}
      >
        <View style={styles.pageSectionCard}>
          <Text style={styles.pageSectionTitle}>小工具</Text>
          <View style={styles.toolsList}>
            {PROFILE_TOOLS.map(item => (
              <Pressable key={item.id} style={styles.toolCard}>
                <View style={styles.toolIconWrap}>
                  <Ionicons
                    name={item.icon ?? 'sparkles-outline'}
                    size={24}
                    color={PROFILE_THEME.primaryText}
                  />
                </View>
                <View style={styles.toolMeta}>
                  <Text style={styles.toolTitle}>{item.title}</Text>
                  <Text style={styles.toolSubtitle}>{item.subtitle}</Text>
                </View>
                <Ionicons
                  name="chevron-forward"
                  size={16}
                  color={PROFILE_THEME.secondaryText}
                />
              </Pressable>
            ))}
          </View>
        </View>
      </ScrollView>
    );
  }

  function renderActivePageContent(page: ProfilePageKey) {
    switch (page) {
      case 'settings':
        return renderSettingsPage();
      case 'publishes':
        return renderPublishesPage();
      case 'savesHub':
        return renderSavesPage();
      case 'routes':
        return renderRoutesPage();
      case 'tools':
        return renderToolsPage();
    }
  }

  function renderPageOverlay() {
    if (!activePage) {
      return null;
    }

    return (
      <Modal
        transparent={false}
        visible
        animationType="slide"
        presentationStyle="fullScreen"
        onRequestClose={() => setActivePage(null)}
      >
        <SafeAreaView style={styles.pageModalRoot}>
          {renderSubpageHeader(PROFILE_PAGE_TITLES[activePage])}
          {renderActivePageContent(activePage)}
        </SafeAreaView>
      </Modal>
    );
  }
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: PROFILE_THEME.background,
  },
  heroCard: {
    overflow: 'hidden',
    justifyContent: 'flex-end',
  },
  heroFill: {
    ...StyleSheet.absoluteFillObject,
  },
  heroGlowLarge: {
    position: 'absolute',
    width: 214,
    height: 214,
    borderRadius: 999,
    top: 22,
    right: -24,
    backgroundColor: 'rgba(255,255,255,0.14)',
  },
  heroGlowSmall: {
    position: 'absolute',
    width: 148,
    height: 148,
    borderRadius: 999,
    top: 86,
    left: -18,
    backgroundColor: 'rgba(69,217,209,0.13)',
  },
  heroShade: {
    ...StyleSheet.absoluteFillObject,
  },
  heroTopActions: {
    position: 'absolute',
    top: 10,
    right: 16,
    zIndex: 2,
  },
  heroIconButton: {
    width: 36,
    height: 36,
    borderRadius: 999,
    backgroundColor: 'rgba(10,10,14,0.34)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.14)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  heroContent: {
    paddingHorizontal: 16,
    paddingBottom: 14,
    gap: 14,
  },
  heroIdentityRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 14,
  },
  avatarRing: {
    width: 88,
    height: 88,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarCore: {
    width: 82,
    height: 82,
    borderRadius: 999,
    backgroundColor: '#1B1526',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.18)',
  },
  avatarText: {
    color: '#FFFFFF',
    fontSize: 28,
    fontWeight: '800',
    letterSpacing: 0,
  },
  heroMeta: {
    flex: 1,
    gap: 8,
    justifyContent: 'flex-end',
  },
  heroTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  heroName: {
    flexShrink: 1,
    color: '#FFFFFF',
    fontSize: 28,
    lineHeight: 32,
    fontWeight: '800',
    letterSpacing: 0,
  },
  qrButton: {
    width: 28,
    height: 28,
    borderRadius: 999,
    backgroundColor: 'rgba(255,255,255,0.1)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  heroPillRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  metaPill: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
    backgroundColor: 'rgba(255,255,255,0.12)',
  },
  metaPillText: {
    color: 'rgba(255,255,255,0.9)',
    fontSize: 11,
    fontWeight: '600',
    letterSpacing: 0,
  },
  heroStatsRowCompact: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 12,
    paddingTop: 2,
  },
  heroStatCompactItem: {
    flex: 1,
    alignItems: 'flex-start',
  },
  heroStatCompactValue: {
    color: '#FFFFFF',
    fontSize: 17,
    lineHeight: 20,
    fontWeight: '700',
    letterSpacing: 0,
  },
  heroStatCompactLabel: {
    marginTop: 3,
    color: 'rgba(255,255,255,0.72)',
    fontSize: 11,
    fontWeight: '500',
    letterSpacing: 0,
  },
  sectionWrap: {
    paddingHorizontal: 16,
    paddingTop: 14,
  },
  bioText: {
    color: PROFILE_THEME.secondaryText,
    fontSize: 14,
    lineHeight: 21,
    fontWeight: '400',
    letterSpacing: 0,
  },
  tagsRow: {
    paddingTop: 10,
    gap: 8,
  },
  tagChip: {
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 8,
    backgroundColor: PROFILE_THEME.card,
    borderWidth: 1,
    borderColor: PROFILE_THEME.border,
  },
  tagText: {
    color: PROFILE_THEME.primaryText,
    fontSize: 12,
    fontWeight: '500',
    letterSpacing: 0,
  },
  sectionCard: {
    borderRadius: 16,
    backgroundColor: PROFILE_THEME.card,
    borderWidth: 1,
    borderColor: PROFILE_THEME.border,
    padding: 16,
  },
  sectionHeadingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 10,
  },
  sectionHeadingInline: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  sectionHeadingTitle: {
    color: PROFILE_THEME.primaryText,
    fontSize: 18,
    lineHeight: 22,
    fontWeight: '700',
    letterSpacing: 0,
  },
  sectionLinkText: {
    color: PROFILE_THEME.accent,
    fontSize: 13,
    fontWeight: '600',
    letterSpacing: 0,
  },
  checkinList: {
    paddingTop: 10,
    gap: 10,
  },
  checkinRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 10,
  },
  checkinTimeline: {
    width: 14,
    alignItems: 'center',
  },
  checkinDot: {
    width: 8,
    height: 8,
    borderRadius: 999,
    backgroundColor: PROFILE_THEME.accent,
    marginTop: 4,
  },
  checkinConnector: {
    width: 2,
    height: 28,
    marginTop: 5,
    backgroundColor: 'rgba(140,92,255,0.28)',
  },
  checkinMeta: {
    flex: 1,
    paddingBottom: 2,
  },
  checkinTitle: {
    color: PROFILE_THEME.primaryText,
    fontSize: 14,
    lineHeight: 19,
    fontWeight: '600',
    letterSpacing: 0,
  },
  checkinSubtitle: {
    marginTop: 4,
    color: PROFILE_THEME.secondaryText,
    fontSize: 12,
    lineHeight: 17,
    fontWeight: '400',
    letterSpacing: 0,
  },
  quickActionsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    paddingTop: 14,
  },
  quickActionItem: {
    minHeight: 82,
    alignItems: 'center',
    justifyContent: 'flex-start',
  },
  quickActionIconWrap: {
    width: 44,
    height: 44,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  quickActionLabel: {
    marginTop: 8,
    color: PROFILE_THEME.primaryText,
    fontSize: 11,
    lineHeight: 15,
    fontWeight: '600',
    textAlign: 'center',
    letterSpacing: 0,
  },
  segmentedShell: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    padding: 4,
    borderRadius: 14,
    backgroundColor: 'rgba(20,20,25,0.94)',
    borderWidth: 1,
    borderColor: PROFILE_THEME.border,
  },
  segmentButton: {
    flex: 1,
    minHeight: 36,
    borderRadius: 10,
    overflow: 'hidden',
  },
  segmentButtonActive: {
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.12)',
  },
  segmentActiveFill: {
    ...StyleSheet.absoluteFillObject,
  },
  segmentInner: {
    minHeight: 36,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingHorizontal: 8,
  },
  segmentText: {
    color: PROFILE_THEME.secondaryText,
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0,
  },
  segmentTextActive: {
    color: '#FFFFFF',
  },
  feedList: {
    paddingTop: 12,
    gap: 12,
  },
  feedCard: {
    borderRadius: 16,
    backgroundColor: PROFILE_THEME.card,
    borderWidth: 1,
    borderColor: PROFILE_THEME.border,
    padding: 14,
  },
  feedHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 8,
  },
  feedCategoryBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 999,
    backgroundColor: 'rgba(140,92,255,0.16)',
  },
  feedCategoryText: {
    color: '#C7B5FF',
    fontSize: 10,
    fontWeight: '700',
    letterSpacing: 0,
  },
  feedTime: {
    color: PROFILE_THEME.secondaryText,
    fontSize: 11,
    fontWeight: '500',
    letterSpacing: 0,
  },
  feedTitle: {
    marginTop: 10,
    color: PROFILE_THEME.primaryText,
    fontSize: 15,
    lineHeight: 21,
    fontWeight: '700',
    letterSpacing: 0,
  },
  feedSummary: {
    marginTop: 8,
    color: PROFILE_THEME.secondaryText,
    fontSize: 13,
    lineHeight: 19,
    fontWeight: '400',
    letterSpacing: 0,
  },
  feedFooterRow: {
    marginTop: 14,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  feedMetrics: {
    flex: 1,
    gap: 4,
  },
  feedMetricText: {
    color: PROFILE_THEME.tertiaryText,
    fontSize: 11,
    fontWeight: '500',
    letterSpacing: 0,
  },
  feedThumb: {
    width: 72,
    height: 72,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  pageModalRoot: {
    flex: 1,
    backgroundColor: PROFILE_THEME.background,
  },
  pageHeader: {
    height: 52,
    paddingHorizontal: 16,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderBottomWidth: 1,
    borderBottomColor: PROFILE_THEME.border,
  },
  pageHeaderButton: {
    width: 36,
    height: 36,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(255,255,255,0.06)',
  },
  pageHeaderTitle: {
    color: PROFILE_THEME.primaryText,
    fontSize: 17,
    fontWeight: '700',
    letterSpacing: 0,
  },
  pageHeaderSpacer: {
    width: 36,
    height: 36,
  },
  pageScroll: {
    flex: 1,
    backgroundColor: PROFILE_THEME.background,
  },
  pageScrollContent: {
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 28,
    gap: 14,
  },
  pageSectionCard: {
    borderRadius: 16,
    backgroundColor: PROFILE_THEME.card,
    borderWidth: 1,
    borderColor: PROFILE_THEME.border,
    padding: 16,
  },
  pageSectionTitle: {
    color: PROFILE_THEME.primaryText,
    fontSize: 18,
    lineHeight: 22,
    fontWeight: '700',
    letterSpacing: 0,
  },
  pageSectionCaption: {
    marginTop: 6,
    color: PROFILE_THEME.secondaryText,
    fontSize: 12,
    lineHeight: 17,
    fontWeight: '400',
    letterSpacing: 0,
  },
  settingsList: {
    marginTop: 12,
  },
  settingsRow: {
    minHeight: 54,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  settingsRowLead: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  settingsRowLabel: {
    color: PROFILE_THEME.primaryText,
    fontSize: 14,
    fontWeight: '500',
    letterSpacing: 0,
  },
  settingsDivider: {
    height: 1,
    marginLeft: 28,
    backgroundColor: 'rgba(255,255,255,0.06)',
  },
  subpageCardList: {
    marginTop: 14,
    gap: 12,
  },
  subpageCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    borderRadius: 16,
    backgroundColor: PROFILE_THEME.surface,
    borderWidth: 1,
    borderColor: PROFILE_THEME.border,
    padding: 12,
  },
  subpageThumb: {
    width: 66,
    height: 74,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  subpageMeta: {
    flex: 1,
    gap: 4,
  },
  subpageTitle: {
    color: PROFILE_THEME.primaryText,
    fontSize: 15,
    lineHeight: 20,
    fontWeight: '700',
    letterSpacing: 0,
  },
  subpageSubtitle: {
    color: PROFILE_THEME.secondaryText,
    fontSize: 12,
    lineHeight: 17,
    fontWeight: '500',
    letterSpacing: 0,
  },
  subpageMetaText: {
    color: PROFILE_THEME.tertiaryText,
    fontSize: 11,
    lineHeight: 16,
    fontWeight: '500',
    letterSpacing: 0,
  },
  toolsList: {
    marginTop: 14,
    gap: 12,
  },
  toolCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    borderRadius: 16,
    backgroundColor: PROFILE_THEME.surface,
    borderWidth: 1,
    borderColor: PROFILE_THEME.border,
    padding: 14,
  },
  toolIconWrap: {
    width: 52,
    height: 52,
    borderRadius: 16,
    backgroundColor: 'rgba(140,92,255,0.22)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  toolMeta: {
    flex: 1,
    gap: 4,
  },
  toolTitle: {
    color: PROFILE_THEME.primaryText,
    fontSize: 15,
    lineHeight: 20,
    fontWeight: '700',
    letterSpacing: 0,
  },
  toolSubtitle: {
    color: PROFILE_THEME.secondaryText,
    fontSize: 12,
    lineHeight: 17,
    fontWeight: '400',
    letterSpacing: 0,
  },
});
