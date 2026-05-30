import type { LucideIcon } from 'lucide-react';
import {
  Activity,
  Bell,
  BookCheck,
  CircleUserRound,
  FileWarning,
  FolderKanban,
  Gavel,
  Headphones,
  LayoutGrid,
  RadioTower,
  ShieldCheck,
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
      },
      {
        href: '/admin/content',
        label: '内容控制台',
        description: '内容总入口',
        icon: FolderKanban,
        visible: contentVisible,
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
      },
      {
        href: '/admin/content/organizers',
        label: '主办方工作区',
        description: '主办方目录与绑定',
        icon: TicketCheck,
        visible: contentVisible,
      },
      {
        href: '/admin/content/djs',
        label: 'DJ 工作区',
        description: 'DJ 目录与编辑',
        icon: Headphones,
        visible: contentVisible,
      },
      {
        href: '/admin/content/reviews',
        label: '审核中心',
        description: '审核与举报',
        icon: BookCheck,
        visible: contentVisible,
      },
    ],
  },
  {
    id: 'governance',
    label: 'Governance',
    items: [
      {
        href: '/admin/dj-binding-reviews',
        label: 'DJ 绑定审核',
        description: '阵容命中处理',
        icon: FileWarning,
        visible: opsVisible,
      },
      {
        href: '/admin/content-reports',
        label: '举报审核队列',
        description: 'UGC 举报处理',
        icon: Gavel,
        visible: opsVisible,
      },
      {
        href: '/admin/account-enforcements',
        label: '账号处罚',
        description: '封禁与申诉',
        icon: ShieldCheck,
        visible: opsVisible,
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
      },
      {
        href: '/admin/pre-registrations',
        label: '预登记管理',
        description: '批次与通知',
        icon: Activity,
        visible: preregVisible,
      },
      {
        href: '/admin/notification-center',
        label: '通知中心',
        description: '模板与投递状态',
        icon: Bell,
        visible: notificationVisible,
      },
      {
        href: '/admin/account-deletions',
        label: '账号删除请求',
        description: '删除与重试',
        icon: CircleUserRound,
        visible: opsVisible,
      },
      {
        href: '/admin/auth-sessions',
        label: '登录设备与会话',
        description: '会话与撤销',
        icon: ShieldCheck,
        visible: alwaysVisible,
      },
    ],
  },
];

export const getVisibleAdminNavGroups = (policy: AdminCmsRolePolicy): AdminNavGroup[] =>
  ADMIN_NAV_GROUPS.map((group) => ({
    ...group,
    items: group.items.filter((item) => item.visible(policy)),
  })).filter((group) => group.items.length > 0);

export const isAdminHrefActive = (pathname: string, href: string): boolean => {
  if (href === '/admin') {
    return pathname === href;
  }

  return pathname === href || pathname.startsWith(`${href}/`);
};
