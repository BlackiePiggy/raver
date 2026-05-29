import { Ionicons } from '@expo/vector-icons';
import { BlurView } from 'expo-blur';
import { LinearGradient } from 'expo-linear-gradient';
import { StatusBar } from 'expo-status-bar';
import React, { useEffect, useRef, useState } from 'react';
import {
  Animated,
  Modal,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  useWindowDimensions,
  View,
} from 'react-native';

type MainTabKey = 'discover' | 'circle' | 'inbox' | 'profile';
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
  palette: [string, string, string];
};

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

export default function App() {
  const { width, height } = useWindowDimensions();
  const [mainTab, setMainTab] = useState<MainTabKey>('discover');
  const [discoverSection, setDiscoverSection] =
    useState<DiscoverSectionKey>('recommend');
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [isSearchMounted, setIsSearchMounted] = useState(false);
  const [recommendStageHeight, setRecommendStageHeight] = useState(0);
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

  const activeSection =
    DISCOVER_SECTIONS.find(item => item.key === discoverSection) ??
    DISCOVER_SECTIONS[0];
  const bottomBarVisualHeight = 84;
  const bottomBarLift = 18;
  const recommendBottomReserve = bottomBarVisualHeight + bottomBarLift + 10;
  const cardWidth = Math.max(width - 32, 1);
  const cardSpacing = 10;
  const cardSnap = cardWidth + cardSpacing;
  const fallbackRecommendedCardHeight = Math.max(height - 150, 420);
  const recommendedCardHeight =
    recommendStageHeight > 0
      ? Math.max(recommendStageHeight - 6, 320)
      : fallbackRecommendedCardHeight;
  const indicatorWidth = 22;
  const indicatorDotWidth = 6;
  const indicatorDotHeight = 4;
  const indicatorStep = 12;
  const indicatorTravel = indicatorStep * Math.max(RECOMMENDATIONS.length - 1, 0);
  const indicatorTrackWidth = indicatorWidth + indicatorTravel;
  const indicatorTranslateX = recommendationScrollX.interpolate({
    inputRange: [0, cardSnap * Math.max(RECOMMENDATIONS.length - 1, 1)],
    outputRange: [0, indicatorTravel],
    extrapolate: 'clamp',
  });

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

  useEffect(() => {
    animateBottomSelection(mainTab);
  }, [mainTab]);

  useEffect(() => {
    const layout = sectionLayouts[discoverSection];
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
      currentScreen = renderPlaceholder(
        '圈子',
        '动态、小队、ID 和打分入口会挂在这一层。',
        '#E46593',
      );
      break;
    case 'inbox':
      currentScreen = renderPlaceholder(
        '收件箱',
        '通知、会话和消息列表会从这里展开。',
        '#6D92F4',
      );
      break;
    case 'profile':
      currentScreen = renderPlaceholder(
        '我的',
        '个人主页、设置和收藏会落在这里。',
        '#76C955',
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

        {discoverSection === 'recommend' ? (
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
                scrollEventThrottle={16}
              >
                {RECOMMENDATIONS.map((item, index) => {
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
                            index === RECOMMENDATIONS.length - 1
                              ? 0
                              : cardSpacing,
                          transform: [{ scale }],
                        },
                      ]}
                    >
                      <Pressable style={styles.cardButton}>
                        <View style={styles.cardBase}>
                          <LinearGradient
                            colors={item.palette}
                            start={{ x: 0, y: 0 }}
                            end={{ x: 1, y: 1 }}
                            style={styles.cardFill}
                          />

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
                                <Text style={styles.typePillText}>
                                  {item.type}
                                </Text>
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
                              <Text style={styles.cardLineText}>
                                {item.location}
                              </Text>
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

              <View pointerEvents="none" style={styles.recommendIndicatorWrap}>
                <View
                  style={[
                    styles.recommendIndicatorTrack,
                    { width: indicatorTrackWidth },
                  ]}
                >
                  {RECOMMENDATIONS.map((item, index) => (
                    <View
                      key={item.id}
                      style={[
                        styles.recommendIndicatorDot,
                        {
                          width: indicatorDotWidth,
                          height: indicatorDotHeight,
                          left:
                            index * indicatorStep +
                            (indicatorWidth - indicatorDotWidth) / 2,
                        },
                      ]}
                    />
                  ))}
                  <Animated.View
                    style={[
                      styles.recommendIndicatorActive,
                      {
                        width: indicatorWidth,
                        transform: [{ translateX: indicatorTranslateX }],
                      },
                    ]}
                  />
                </View>
              </View>
            </View>
          </View>
        ) : (
          renderSectionPlaceholder(activeSection)
        )}
      </View>
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

        <View style={styles.bottomBarOuter}>
          <BlurView intensity={22} tint="dark" style={styles.bottomBarBlur}>
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
                          onPress={() => setMainTab(tab.key)}
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
                      onPress={() => setMainTab(tab.key)}
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
          </BlurView>
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
    paddingBottom: 54,
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
    bottom: 44,
  },
  recommendIndicatorTrack: {
    height: 8,
    justifyContent: 'center',
    position: 'relative',
  },
  recommendIndicatorDot: {
    position: 'absolute',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 999,
    backgroundColor: 'rgba(255,255,255,0.26)',
  },
  recommendIndicatorActive: {
    position: 'absolute',
    left: 0,
    height: 4,
    borderRadius: 999,
    backgroundColor: THEME.pageIndicator,
    shadowColor: THEME.pageIndicator,
    shadowOpacity: 0.72,
    shadowRadius: 5,
    shadowOffset: {
      width: 0,
      height: 0,
    },
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
