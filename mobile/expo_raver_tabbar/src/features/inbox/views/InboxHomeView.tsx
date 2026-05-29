import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import React, { useMemo, useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import { SafeBlurView } from '../../../shared/ui/SafeBlurView';

type InboxHomeViewProps = {
  bottomInset: number;
};

type AlertEntry = {
  id: string;
  title: string;
  icon: keyof typeof Ionicons.glyphMap;
  unread: number;
  palette: [string, string];
};

type SummaryEntry = {
  id: string;
  title: string;
  preview: string;
  time: string;
  unread: number;
  icon: keyof typeof Ionicons.glyphMap;
  palette: [string, string];
  iconColor: string;
};

type ConversationEntry = {
  id: string;
  title: string;
  preview: string;
  time: string;
  unread: number;
  isPinned: boolean;
  isGroup: boolean;
  hasUnreadMention: boolean;
  avatarText: string;
  palette: [string, string];
};

const INBOX_THEME = {
  background: '#08080A',
  card: '#141419',
  border: 'rgba(255,255,255,0.08)',
  primaryText: '#F5F5F7',
  secondaryText: '#A3A3AD',
  tertiaryText: 'rgba(255,255,255,0.72)',
  accent: '#8C5CFF',
  destructive: '#FF4D67',
};

const ALERTS: AlertEntry[] = [
  {
    id: 'like',
    title: '点赞消息',
    icon: 'heart',
    unread: 3,
    palette: ['rgba(232,101,145,0.18)', 'rgba(232,101,145,0.06)'],
  },
  {
    id: 'comment',
    title: '评论消息',
    icon: 'chatbubble',
    unread: 5,
    palette: ['rgba(255,255,255,0.10)', 'rgba(255,255,255,0.04)'],
  },
  {
    id: 'follow',
    title: '关注消息',
    icon: 'person-add',
    unread: 1,
    palette: ['rgba(90,169,255,0.18)', 'rgba(90,169,255,0.06)'],
  },
  {
    id: 'squad',
    title: '小队邀请',
    icon: 'people',
    unread: 2,
    palette: ['rgba(140,92,255,0.18)', 'rgba(140,92,255,0.06)'],
  },
];

const SUMMARY_ENTRIES: SummaryEntry[] = [
  {
    id: 'reviews',
    title: '审核通知',
    preview: '你提交的活动和 DJ 审核结果会显示在这里',
    time: '12:10',
    unread: 2,
    icon: 'checkmark-circle',
    palette: ['rgba(86,201,139,0.22)', 'rgba(47,157,92,0.08)'],
    iconColor: '#41C56B',
  },
  {
    id: 'events',
    title: '关注的活动',
    preview: 'Vision Wave 刚刚更新了 Garden 场的入场动线',
    time: '09:42',
    unread: 4,
    icon: 'sparkles',
    palette: ['rgba(140,92,255,0.24)', 'rgba(255,166,84,0.10)'],
    iconColor: '#8C5CFF',
  },
  {
    id: 'djs',
    title: '关注的DJ',
    preview: 'NORA 发布了新的 route note，适合凌晨段前切场',
    time: '昨天',
    unread: 1,
    icon: 'mic',
    palette: ['rgba(76,147,255,0.24)', 'rgba(75,220,255,0.08)'],
    iconColor: '#5AA9FF',
  },
  {
    id: 'brands',
    title: '关注的音乐节',
    preview: 'Storm Festival 开放了第二轮阵容和存包预约',
    time: '周二',
    unread: 0,
    icon: 'sparkles',
    palette: ['rgba(140,92,255,0.24)', 'rgba(255,185,74,0.08)'],
    iconColor: '#8C5CFF',
  },
];

const INITIAL_CONVERSATIONS: ConversationEntry[] = [
  {
    id: 'conv-1',
    title: 'Warehouse Signal',
    preview: '@你 今晚 01:20 之后统一往 Garden 集合',
    time: '12:32',
    unread: 7,
    isPinned: true,
    isGroup: true,
    hasUnreadMention: true,
    avatarText: 'WS',
    palette: ['#A46AFF', '#5D42F2'],
  },
  {
    id: 'conv-2',
    title: 'NORA',
    preview: '新的 set time 我发你了，你看下是不是这版',
    time: '11:06',
    unread: 2,
    isPinned: false,
    isGroup: false,
    hasUnreadMention: false,
    avatarText: 'NO',
    palette: ['#5EA7FF', '#315CFF'],
  },
  {
    id: 'conv-3',
    title: '凌晨段路线党',
    preview: '已经把 open air 改仓库后的路线图同步到群相册了',
    time: '昨天',
    unread: 0,
    isPinned: false,
    isGroup: true,
    hasUnreadMention: false,
    avatarText: 'LD',
    palette: ['#FFAB55', '#DD5B47'],
  },
  {
    id: 'conv-4',
    title: 'Momo',
    preview: '下周那场我准备直接冲前排，你呢',
    time: '周二',
    unread: 0,
    isPinned: false,
    isGroup: false,
    hasUnreadMention: false,
    avatarText: 'MO',
    palette: ['#E66B94', '#8D4AF7'],
  },
];

export function InboxHomeView({ bottomInset }: InboxHomeViewProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [selectedIDs, setSelectedIDs] = useState<string[]>([]);
  const [conversations, setConversations] = useState(INITIAL_CONVERSATIONS);

  const sortedConversations = useMemo(
    () =>
      [...conversations].sort((left, right) => {
        if (left.isPinned !== right.isPinned) {
          return left.isPinned ? -1 : 1;
        }
        return 0;
      }),
    [conversations],
  );

  function unreadBadgeText(count: number) {
    return count > 99 ? '99+' : `${count}`;
  }

  function toggleEditing() {
    setIsEditing(value => {
      const next = !value;
      if (!next) {
        setSelectedIDs([]);
      }
      return next;
    });
  }

  function toggleSelection(id: string) {
    setSelectedIDs(current =>
      current.includes(id)
        ? current.filter(item => item !== id)
        : [...current, id],
    );
  }

  function selectAllOrClear() {
    if (selectedIDs.length === conversations.length) {
      setSelectedIDs([]);
      return;
    }
    setSelectedIDs(conversations.map(item => item.id));
  }

  function markSelectedRead() {
    setConversations(current =>
      current.map(item =>
        selectedIDs.includes(item.id) ? { ...item, unread: 0 } : item,
      ),
    );
    setSelectedIDs([]);
  }

  function hideSelected() {
    setConversations(current =>
      current.filter(item => !selectedIDs.includes(item.id)),
    );
    setSelectedIDs([]);
  }

  function renderTopAlerts() {
    return (
      <View style={styles.topRow}>
        <View style={styles.alertsRow}>
          {ALERTS.map(item => (
            <Pressable key={item.id} style={styles.alertButton}>
              <LinearGradient
                colors={item.palette}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.alertCircle}
              >
                <Ionicons
                  name={item.icon}
                  size={19}
                  color={INBOX_THEME.primaryText}
                />
              </LinearGradient>
              {item.unread > 0 ? (
                <View style={styles.alertBadge}>
                  <Text style={styles.alertBadgeText}>
                    {unreadBadgeText(item.unread)}
                  </Text>
                </View>
              ) : null}
            </Pressable>
          ))}
        </View>

        <Pressable
          onPress={toggleEditing}
          accessibilityLabel={isEditing ? '完成编辑' : '编辑会话'}
          style={[
            styles.editButton,
            isEditing && styles.editButtonSelected,
          ]}
        >
          <Ionicons
            name={isEditing ? 'checkmark' : 'create-outline'}
            size={18}
            color={
              isEditing
                ? INBOX_THEME.primaryText
                : INBOX_THEME.secondaryText
            }
          />
        </Pressable>
      </View>
    );
  }

  function renderSummaryRow(item: SummaryEntry, isLast: boolean) {
    return (
      <Pressable
        key={item.id}
        style={[styles.listRow, isLast && styles.listRowLast]}
      >
        <LinearGradient
          colors={item.palette}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.summaryAvatar}
        >
          <Ionicons name={item.icon} size={18} color={item.iconColor} />
        </LinearGradient>

        <View style={styles.rowContent}>
          <View style={styles.rowTitleLine}>
            <Text style={styles.rowTitle}>{item.title}</Text>
            <Text style={styles.rowTime}>{item.time}</Text>
          </View>

          <View style={styles.rowPreviewLine}>
            <Text style={styles.rowPreview} numberOfLines={1}>
              {item.preview}
            </Text>

            {item.unread > 0 ? (
              <View style={styles.unreadBadge}>
                <Text style={styles.unreadBadgeText}>
                  {unreadBadgeText(item.unread)}
                </Text>
              </View>
            ) : null}
          </View>
        </View>
      </Pressable>
    );
  }

  function renderConversationRow(
    item: ConversationEntry,
    isLast: boolean,
  ) {
    const selected = selectedIDs.includes(item.id);

    return (
      <Pressable
        key={item.id}
        onPress={() => {
          if (isEditing) {
            toggleSelection(item.id);
            return;
          }
          if (item.unread > 0) {
            setConversations(current =>
              current.map(conversation =>
                conversation.id === item.id
                  ? { ...conversation, unread: 0 }
                  : conversation,
              ),
            );
          }
        }}
        style={[
          styles.listRow,
          styles.conversationRow,
          isLast && styles.listRowLast,
          selected && styles.conversationRowSelected,
        ]}
      >
        {isEditing ? (
          <View
            style={[
              styles.selectionCircle,
              selected && styles.selectionCircleSelected,
            ]}
          >
            {selected ? (
              <Ionicons name="checkmark" size={12} color="#FFFFFF" />
            ) : null}
          </View>
        ) : null}

        <LinearGradient
          colors={item.palette}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.conversationAvatar}
        >
          <Text style={styles.conversationAvatarText}>{item.avatarText}</Text>
        </LinearGradient>

        <View style={styles.rowContent}>
          <View style={styles.rowTitleLine}>
            <View style={styles.conversationTitleGroup}>
              <Text style={styles.rowTitle}>{item.title}</Text>
              {item.isPinned ? (
                <Ionicons
                  name="pin"
                  size={11}
                  color={INBOX_THEME.accent}
                  style={styles.pinnedIcon}
                />
              ) : null}
              {item.isGroup ? (
                <View style={styles.groupBadge}>
                  <Text style={styles.groupBadgeText}>小队</Text>
                </View>
              ) : null}
            </View>
            <Text style={styles.rowTime}>{item.time}</Text>
          </View>

          <View style={styles.rowPreviewLine}>
            <Text
              style={[
                styles.rowPreview,
                item.hasUnreadMention && styles.rowPreviewMention,
              ]}
              numberOfLines={1}
            >
              {item.preview}
            </Text>

            {item.unread > 0 ? (
              <View style={styles.unreadBadge}>
                <Text style={styles.unreadBadgeText}>
                  {unreadBadgeText(item.unread)}
                </Text>
              </View>
            ) : null}
          </View>
        </View>
      </Pressable>
    );
  }

  return (
    <View style={styles.screen}>
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{
          paddingHorizontal: 16,
          paddingTop: 8,
          paddingBottom: bottomInset + (isEditing ? 102 : 28),
        }}
      >
        {renderTopAlerts()}

        <View style={styles.listCard}>
          {SUMMARY_ENTRIES.map((item, index) =>
            renderSummaryRow(item, index === SUMMARY_ENTRIES.length - 1),
          )}
        </View>

        <View style={styles.listCard}>
          {sortedConversations.map((item, index) =>
            renderConversationRow(
              item,
              index === sortedConversations.length - 1,
            ),
          )}
        </View>
      </ScrollView>

      {isEditing ? (
        <View style={[styles.batchBarWrap, { bottom: bottomInset }]}>
          <SafeBlurView intensity={28} tint="dark" style={styles.batchBarBlur}>
            <View style={styles.batchDivider} />
            <View style={styles.batchBar}>
              <Pressable onPress={selectAllOrClear}>
                <Text style={styles.batchPrimaryActionText}>
                  {selectedIDs.length === conversations.length
                    ? '取消全选'
                    : '全选'}
                </Text>
              </Pressable>

              <Text style={styles.batchMetaText}>
                已选 {selectedIDs.length} 项
              </Text>

              <View style={styles.batchActionsRight}>
                <Pressable
                  onPress={markSelectedRead}
                  disabled={selectedIDs.length === 0}
                >
                  <Text
                    style={[
                      styles.batchSecondaryActionText,
                      selectedIDs.length === 0 && styles.batchDisabledText,
                    ]}
                  >
                    标为已读
                  </Text>
                </Pressable>
                <Pressable
                  onPress={hideSelected}
                  disabled={selectedIDs.length === 0}
                >
                  <Text
                    style={[
                      styles.batchDestructiveText,
                      selectedIDs.length === 0 && styles.batchDisabledText,
                    ]}
                  >
                    隐藏
                  </Text>
                </Pressable>
              </View>
            </View>
          </SafeBlurView>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: INBOX_THEME.background,
  },
  topRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  alertsRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  alertButton: {
    marginRight: 16,
  },
  alertCircle: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: INBOX_THEME.border,
  },
  alertBadge: {
    position: 'absolute',
    top: -6,
    right: -8,
    minWidth: 22,
    height: 18,
    borderRadius: 9,
    paddingHorizontal: 6,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: INBOX_THEME.destructive,
  },
  alertBadgeText: {
    fontSize: 10,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  editButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: INBOX_THEME.card,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: INBOX_THEME.border,
  },
  editButtonSelected: {
    backgroundColor: INBOX_THEME.accent,
    borderColor: 'rgba(255,255,255,0.16)',
  },
  listCard: {
    marginBottom: 12,
    borderRadius: 18,
    overflow: 'hidden',
    backgroundColor: INBOX_THEME.card,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: INBOX_THEME.border,
  },
  listRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: 'rgba(255,255,255,0.06)',
  },
  listRowLast: {
    borderBottomWidth: 0,
  },
  summaryAvatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  conversationRow: {
    minHeight: 76,
  },
  conversationRowSelected: {
    backgroundColor: 'rgba(140,92,255,0.10)',
  },
  selectionCircle: {
    width: 22,
    height: 22,
    borderRadius: 11,
    borderWidth: 1.2,
    borderColor: INBOX_THEME.secondaryText,
    marginRight: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  selectionCircleSelected: {
    backgroundColor: INBOX_THEME.accent,
    borderColor: INBOX_THEME.accent,
  },
  selectionIcon: {
    marginRight: 10,
  },
  conversationAvatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  conversationAvatarText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  rowContent: {
    flex: 1,
    marginLeft: 10,
  },
  rowTitleLine: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  rowTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: INBOX_THEME.primaryText,
  },
  rowTime: {
    marginLeft: 8,
    fontSize: 12,
    color: INBOX_THEME.secondaryText,
  },
  rowPreviewLine: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 4,
  },
  rowPreview: {
    flex: 1,
    fontSize: 13,
    lineHeight: 18,
    color: INBOX_THEME.secondaryText,
  },
  rowPreviewMention: {
    color: INBOX_THEME.destructive,
  },
  unreadBadge: {
    marginLeft: 10,
    minWidth: 23,
    height: 18,
    borderRadius: 9,
    paddingHorizontal: 7,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: INBOX_THEME.destructive,
  },
  unreadBadgeText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  conversationTitleGroup: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    paddingRight: 10,
  },
  pinnedIcon: {
    marginLeft: 6,
  },
  groupBadge: {
    marginLeft: 8,
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 999,
    backgroundColor: 'rgba(140,92,255,0.22)',
  },
  groupBadgeText: {
    fontSize: 10,
    fontWeight: '700',
    color: INBOX_THEME.primaryText,
  },
  batchBarWrap: {
    position: 'absolute',
    left: 0,
    right: 0,
  },
  batchBarBlur: {
    overflow: 'hidden',
  },
  batchDivider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: 'rgba(255,255,255,0.10)',
  },
  batchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: 'rgba(8,8,10,0.42)',
  },
  batchMetaText: {
    fontSize: 12,
    color: INBOX_THEME.secondaryText,
  },
  batchActionsRight: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  batchPrimaryActionText: {
    fontSize: 14,
    fontWeight: '600',
    color: INBOX_THEME.primaryText,
  },
  batchSecondaryActionText: {
    fontSize: 14,
    fontWeight: '600',
    color: INBOX_THEME.primaryText,
    marginLeft: 18,
  },
  batchDestructiveText: {
    fontSize: 14,
    fontWeight: '600',
    color: INBOX_THEME.destructive,
    marginLeft: 18,
  },
  batchDisabledText: {
    opacity: 0.36,
  },
});
