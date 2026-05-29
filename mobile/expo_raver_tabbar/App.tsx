import { Ionicons } from '@expo/vector-icons';
import { StatusBar } from 'expo-status-bar';
import { useMemo, useState } from 'react';
import {
  Pressable,
  SafeAreaView,
  StyleSheet,
  Text,
  View,
} from 'react-native';

type TabKey = 'discover' | 'circle' | 'search' | 'inbox' | 'profile';

type TabItem = {
  key: TabKey;
  label: string;
  activeIcon: keyof typeof Ionicons.glyphMap;
  inactiveIcon: keyof typeof Ionicons.glyphMap;
  accent?: boolean;
  description: string;
};

const TAB_ITEMS: TabItem[] = [
  {
    key: 'discover',
    label: '发现',
    activeIcon: 'compass',
    inactiveIcon: 'compass-outline',
    description: '这里后面可以接 Discover 首页内容。',
  },
  {
    key: 'circle',
    label: '圈子',
    activeIcon: 'people',
    inactiveIcon: 'people-outline',
    description: '这里后面可以接 Circle 动态流或社区首页。',
  },
  {
    key: 'search',
    label: '搜索',
    activeIcon: 'search',
    inactiveIcon: 'search',
    accent: true,
    description: '这里后面可以接全局搜索浮层或搜索结果页。',
  },
  {
    key: 'inbox',
    label: '收件箱',
    activeIcon: 'mail',
    inactiveIcon: 'mail-outline',
    description: '这里后面可以接通知、私信或消息入口。',
  },
  {
    key: 'profile',
    label: '我的',
    activeIcon: 'person',
    inactiveIcon: 'person-outline',
    description: '这里后面可以接个人主页和设置。',
  },
];

export default function App() {
  const [activeTab, setActiveTab] = useState<TabKey>('discover');

  const currentTab = useMemo(
    () => TAB_ITEMS.find(item => item.key === activeTab) ?? TAB_ITEMS[0],
    [activeTab],
  );

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar style="light" />
      <View style={styles.screen}>
        <View style={styles.heroBlock}>
          <Text style={styles.kicker}>Raver Expo MVP</Text>
          <Text style={styles.title}>{currentTab.label}</Text>
          <Text style={styles.description}>{currentTab.description}</Text>
        </View>

        <View style={styles.previewCard}>
          <Text style={styles.previewLabel}>当前选中</Text>
          <Text style={styles.previewValue}>{currentTab.label}</Text>
          <Text style={styles.previewHint}>
            先把主页的底部 Tab 壳子复现出来，后面再逐个把真实页面塞进去。
          </Text>
        </View>

        <View style={styles.spacer} />

        <View style={styles.tabBarShell}>
          <View style={styles.tabBar}>
            {TAB_ITEMS.map(item => {
              const isActive = item.key === activeTab;
              const iconName = isActive ? item.activeIcon : item.inactiveIcon;

              if (item.accent) {
                return (
                  <Pressable
                    key={item.key}
                    accessibilityRole="button"
                    onPress={() => setActiveTab(item.key)}
                    style={styles.searchTabWrap}
                  >
                    <View style={styles.searchButton}>
                      <Ionicons name={iconName} size={22} color="#FFFFFF" />
                    </View>
                    <Text style={styles.searchLabel}>{item.label}</Text>
                  </Pressable>
                );
              }

              return (
                <Pressable
                  key={item.key}
                  accessibilityRole="button"
                  onPress={() => setActiveTab(item.key)}
                  style={styles.tabButton}
                >
                  <View style={isActive ? styles.activePill : styles.inactivePill}>
                    <Ionicons
                      name={iconName}
                      size={20}
                      color={isActive ? '#FFFFFF' : '#8F98A8'}
                    />
                    <Text style={isActive ? styles.activeLabel : styles.inactiveLabel}>
                      {item.label}
                    </Text>
                  </View>
                </Pressable>
              );
            })}
          </View>
        </View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#0A0F18',
  },
  screen: {
    flex: 1,
    backgroundColor: '#0A0F18',
    paddingHorizontal: 20,
    paddingTop: 20,
  },
  heroBlock: {
    gap: 8,
  },
  kicker: {
    color: '#F15B7C',
    fontSize: 13,
    fontWeight: '700',
    letterSpacing: 0,
    textTransform: 'uppercase',
  },
  title: {
    color: '#FFFFFF',
    fontSize: 40,
    fontWeight: '800',
    letterSpacing: 0,
  },
  description: {
    color: '#A3ADBF',
    fontSize: 16,
    lineHeight: 24,
    letterSpacing: 0,
  },
  previewCard: {
    marginTop: 28,
    borderRadius: 8,
    backgroundColor: '#121926',
    borderWidth: 1,
    borderColor: '#222C3D',
    padding: 20,
    gap: 6,
  },
  previewLabel: {
    color: '#8F98A8',
    fontSize: 13,
    fontWeight: '600',
    letterSpacing: 0,
  },
  previewValue: {
    color: '#FFFFFF',
    fontSize: 28,
    fontWeight: '800',
    letterSpacing: 0,
  },
  previewHint: {
    color: '#A3ADBF',
    fontSize: 15,
    lineHeight: 22,
    letterSpacing: 0,
  },
  spacer: {
    flex: 1,
  },
  tabBarShell: {
    paddingBottom: 12,
  },
  tabBar: {
    minHeight: 84,
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-between',
    borderRadius: 24,
    borderWidth: 1,
    borderColor: '#242F43',
    backgroundColor: '#101723',
    paddingHorizontal: 10,
    paddingTop: 10,
    paddingBottom: 10,
    shadowColor: '#000000',
    shadowOpacity: 0.28,
    shadowRadius: 18,
    shadowOffset: {
      width: 0,
      height: 10,
    },
    elevation: 16,
  },
  tabButton: {
    flex: 1,
  },
  activePill: {
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
    borderRadius: 20,
    backgroundColor: '#F15B7C',
  },
  inactivePill: {
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
    borderRadius: 20,
    backgroundColor: 'transparent',
  },
  activeLabel: {
    color: '#FFFFFF',
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0,
  },
  inactiveLabel: {
    color: '#8F98A8',
    fontSize: 11,
    fontWeight: '600',
    letterSpacing: 0,
  },
  searchTabWrap: {
    width: 74,
    alignItems: 'center',
    justifyContent: 'flex-end',
    gap: 6,
    marginTop: -22,
  },
  searchButton: {
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#F15B7C',
    borderWidth: 4,
    borderColor: '#101723',
    shadowColor: '#F15B7C',
    shadowOpacity: 0.3,
    shadowRadius: 14,
    shadowOffset: {
      width: 0,
      height: 6,
    },
    elevation: 12,
  },
  searchLabel: {
    color: '#FFFFFF',
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0,
  },
});
