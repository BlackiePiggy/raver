import type { LucideIcon } from 'lucide-react';
import {
  Activity,
  Bell,
  BookCheck,
  CircleUserRound,
  Disc3,
  FileWarning,
  Fingerprint,
  FolderKanban,
  Gavel,
  Headphones,
  LayoutGrid,
  ListTree,
  Newspaper,
  RadioTower,
  ShieldCheck,
  Sparkles,
  TicketCheck,
  Users,
} from 'lucide-react';
import type { AdminCmsRolePolicy } from '@/lib/admin/role-policy';

export type AdminNavItem = {
  href: string;
  label: string;
  description: string;
  icon: LucideIcon;
  visible: (policy: AdminCmsRolePolicy) => boolean;
  matchMode?: 'exact' | 'prefix';
};

export type AdminNavGroup = {
  id: string;
  label: string;
  items: AdminNavItem[];
};

const alwaysVisible = () => true;
const opsVisible = (policy: AdminCmsRolePolicy) => policy.canAccessOperations;
const notificationVisible = (policy: AdminCmsRolePolicy) => policy.canAccessNotificationOps;
const preregVisible = (policy: AdminCmsRolePolicy) => policy.canAccessPreRegistrationOps;
const contentVisible = (policy: AdminCmsRolePolicy) => policy.canAccessContentCms;

export const ADMIN_NAV_GROUPS: AdminNavGroup[] = [
  {
    id: 'menu',
    label: 'Menu',
    items: [
      {
        href: '/admin',
        label: '后台工作台',
        description: '总览与状态',
        icon: LayoutGrid,
        visible: alwaysVisible,
        matchMode: 'exact',
      },
    ],
  },
  {
    id: 'overview',
    label: 'Overview',
    items: [
      {
        href: '/admin/content',
        label: '内容控制台',
        description: '内容总览入口',
        icon: FolderKanban,
        visible: contentVisible,
        matchMode: 'exact',
      },
    ],
  },
  {
    id: 'content',
    label: 'Content',
    items: [
      {
        href: '/admin/content/events',
        label: '活动工作区',
        description: '活动目录与编辑',
        icon: RadioTower,
        visible: contentVisible,
        matchMode: 'prefix',
      },
      {
        href: '/admin/content/organizers',
        label: '主办方工作区',
        description: '主办方目录与绑定',
        icon: TicketCheck,
        visible: contentVisible,
        matchMode: 'prefix',
      },
      {
        href: '/admin/content/djs',
        label: 'DJ 工作区',
        description: 'DJ 目录与编辑',
        icon: Headphones,
        visible: contentVisible,
        matchMode: 'prefix',
      },
      {
        href: '/admin/content/news',
        label: '资讯工作区',
        description: '资讯创建与编辑',
        icon: Newspaper,
        visible: contentVisible,
        matchMode: 'prefix',
      },
      {
        href: '/admin/content/labels',
        label: '厂牌工作区',
        description: '厂牌资料与编辑',
        icon: Disc3,
        visible: contentVisible,
        matchMode: 'prefix',
      },
      {
        href: '/admin/content/rankings',
        label: '榜单管理',
        description: '榜单与年份条目维护',
        icon: Sparkles,
        visible: contentVisible,
        matchMode: 'prefix',
      },
      {
        href: '/admin/content/genres',
        label: '流派管理',
        description: '流派树与内容维护',
        icon: ListTree,
        visible: contentVisible,
        matchMode: 'prefix',
      },
      {
        href: '/admin/content/identifiers',
        label: 'ID 管理',
        description: '关键标识字段维护',
        icon: Fingerprint,
        visible: contentVisible,
        matchMode: 'prefix',
      },
      {
        href: '/admin/content/ratings',
        label: '打分管理',
        description: '评分活动与评分项维护',
        icon: Activity,
        visible: contentVisible,
        matchMode: 'prefix',
      },
    ],
  },
  {
    id: 'governance',
    label: 'Governance',
    items: [
      {
        href: '/admin/content/reviews',
        label: '审核中心',
        description: '内容审核与举报',
        icon: BookCheck,
        visible: contentVisible,
        matchMode: 'prefix',
      },
      {
        href: '/admin/dj-binding-reviews',
        label: 'DJ 绑定审核',
        description: '阵容命中处理',
        icon: FileWarning,
        visible: opsVisible,
        matchMode: 'prefix',
      },
      {
        href: '/admin/content-reports',
        label: '举报审核队列',
        description: 'UGC 举报处理',
        icon: Gavel,
        visible: opsVisible,
        matchMode: 'prefix',
      },
      {
        href: '/admin/account-enforcements',
        label: '账号处罚',
        description: '封禁与申诉',
        icon: ShieldCheck,
        visible: opsVisible,
        matchMode: 'prefix',
      },
    ],
  },
  {
    id: 'operations',
    label: 'Operations',
    items: [
      {
        href: '/admin/users',
        label: '用户管理',
        description: '用户检索与删除',
        icon: Users,
        visible: opsVisible,
        matchMode: 'prefix',
      },
      {
        href: '/admin/pre-registrations',
        label: '预登记管理',
        description: '批次与通知',
        icon: Activity,
        visible: preregVisible,
        matchMode: 'prefix',
      },
      {
        href: '/admin/notification-center',
        label: '通知中心',
        description: '模板与投递状态',
        icon: Bell,
        visible: notificationVisible,
        matchMode: 'prefix',
      },
      {
        href: '/admin/account-deletions',
        label: '账号删除请求',
        description: '删除与重试',
        icon: CircleUserRound,
        visible: opsVisible,
        matchMode: 'prefix',
      },
      {
        href: '/admin/auth-sessions',
        label: '登录设备与会话',
        description: '会话与撤销',
        icon: ShieldCheck,
        visible: alwaysVisible,
        matchMode: 'prefix',
      },
    ],
  },
];

export const getVisibleAdminNavGroups = (policy: AdminCmsRolePolicy): AdminNavGroup[] =>
  ADMIN_NAV_GROUPS.map((group) => ({
    ...group,
    items: group.items.filter((item) => item.visible(policy)),
  })).filter((group) => group.items.length > 0);

export const isAdminHrefActive = (
  pathname: string,
  href: string,
  matchMode: 'exact' | 'prefix' = 'prefix'
): boolean => {
  if (matchMode === 'exact') {
    return pathname === href;
  }

  return pathname === href || pathname.startsWith(`${href}/`);
};
