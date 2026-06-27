'use client';

import Link from 'next/link';
import {
  BadgeCheck,
  ChevronDown,
  LogOut,
  PanelLeftClose,
  Settings,
  Triangle,
  UserCircle2,
  X,
} from 'lucide-react';
import { clsx } from 'clsx';
import { ReactNode, useEffect, useMemo, useRef, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import useOverlayBodyLock from '@/hooks/useOverlayBodyLock';
import { getAdminCmsRolePolicy } from '@/lib/admin/role-policy';
import { getVisibleAdminNavGroups, isAdminHrefActive } from '@/lib/admin/navigation';
import { createLoginHref } from '@/lib/auth/login-redirect';
import AdminSearchField from '@/components/admin/AdminSearchField';

type AdminAppShellProps = {
  title: string;
  description?: string;
  eyebrow?: string;
  actions?: ReactNode;
  hidePageHeader?: boolean;
  children: ReactNode;
};

const SIDEBAR_STATE_KEY = 'raver-admin-shell-collapsed';
const SIDEBAR_SCROLL_KEY = 'raver-admin-shell-scroll-top';
const SIDEBAR_GROUP_STATE_KEY = 'raver-admin-shell-group-open';

const initialsFromName = (value?: string | null): string =>
  value
    ?.split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((item) => item.slice(0, 1).toUpperCase())
    .join('') || 'RA';

type SidebarSettingsTabKey = 'profile' | 'permissions' | 'session';

const SIDEBAR_SETTINGS_TABS: Array<{
  key: SidebarSettingsTabKey;
  label: string;
  description: string;
  icon: typeof UserCircle2;
}> = [
  {
    key: 'profile',
    label: '基本信息',
    description: '头像、名称与账号标识',
    icon: UserCircle2,
  },
  {
    key: 'permissions',
    label: '身份权限',
    description: '当前角色与后台能力',
    icon: BadgeCheck,
  },
  {
    key: 'session',
    label: '会话操作',
    description: '退出登录与会话入口',
    icon: LogOut,
  },
];

function SidebarUserSettingsOverlay({
  open,
  onClose,
  onAuthAction,
  activeTab,
  setActiveTab,
  userName,
  userEmail,
  userAvatarUrl,
  userRoleLabel,
  userRoleDescription,
  userCapabilities,
  userId,
  username,
  userBio,
  userLocation,
  isAuthenticated,
}: {
  open: boolean;
  onClose: () => void;
  onAuthAction: () => void;
  activeTab: SidebarSettingsTabKey;
  setActiveTab: (next: SidebarSettingsTabKey) => void;
  userName: string;
  userEmail: string;
  userAvatarUrl: string | null;
  userRoleLabel: string;
  userRoleDescription: string;
  userCapabilities: string[];
  userId: string;
  username: string;
  userBio: string | null;
  userLocation: string | null;
  isAuthenticated: boolean;
}) {
  useOverlayBodyLock(open);

  useEffect(() => {
    if (!open) return undefined;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose();
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [onClose, open]);

  if (!open) return null;

  const renderRightPane = () => {
    if (activeTab === 'permissions') {
      return (
        <div className="space-y-4">
          <section className="rounded-[22px] border border-[#d8e1dd] bg-white p-5">
            <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-black/38">当前身份</div>
            <div className="mt-3 text-[26px] font-semibold tracking-[-0.04em] text-[#071110]">{userRoleLabel}</div>
            <p className="mt-2 text-sm leading-7 text-black/55">{userRoleDescription}</p>
          </section>

          <section className="rounded-[22px] border border-[#d8e1dd] bg-white p-5">
            <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-black/38">可用能力</div>
            <div className="mt-4 grid gap-3">
              {userCapabilities.length ? (
                userCapabilities.map((capability) => (
                  <div key={capability} className="rounded-[18px] border border-[#eef1ef] bg-[#f6f8f7] px-4 py-3 text-sm leading-6 text-[#18211f]">
                    {capability}
                  </div>
                ))
              ) : (
                <div className="rounded-[18px] border border-dashed border-[#d7ded9] px-4 py-5 text-sm text-black/45">
                  当前账号没有额外的后台能力说明。
                </div>
              )}
            </div>
          </section>
        </div>
      );
    }

    if (activeTab === 'session') {
      return (
        <div className="space-y-4">
          <section className="rounded-[22px] border border-[#d8e1dd] bg-white p-5">
            <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-black/38">会话状态</div>
            <div className="mt-3 text-[24px] font-semibold tracking-[-0.04em] text-[#071110]">
              {isAuthenticated ? '当前已登录' : '当前未登录'}
            </div>
            <p className="mt-2 text-sm leading-7 text-black/55">
              {isAuthenticated
                ? '当前后台会话基于你的账号身份生效。退出后将返回登录页，需要重新认证才能继续进入管理后台。'
                : '当前没有有效的后台会话。你可以前往登录页重新认证后再进入管理后台。'}
            </p>
            <div className="mt-5 flex flex-wrap gap-3">
              {isAuthenticated ? (
                <Link
                  href="/admin/auth-sessions"
                  className="rounded-full border border-[#d7ded9] bg-white px-4 py-2.5 text-sm font-semibold text-[#18211f]"
                  onClick={onClose}
                >
                  查看登录设备
                </Link>
              ) : null}
              <button
                type="button"
                onClick={onAuthAction}
                className={clsx(
                  'rounded-full px-4 py-2.5 text-sm font-semibold text-white',
                  isAuthenticated ? 'bg-[#7d2020]' : 'bg-[#1f9d61]'
                )}
              >
                {isAuthenticated ? '退出登录' : '前往登录'}
              </button>
            </div>
          </section>
        </div>
      );
    }

    return (
      <div className="space-y-4">
        <section className="rounded-[22px] border border-[#d8e1dd] bg-white p-5">
          <div className="flex flex-wrap items-start gap-4">
            <span className="relative grid size-[84px] shrink-0 place-items-center overflow-hidden rounded-[28px] bg-[#071110] text-[22px] font-extrabold text-white">
              {userAvatarUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={userAvatarUrl} alt={userName} className="h-full w-full object-cover" />
              ) : (
                initialsFromName(userName || userEmail || username)
              )}
            </span>
            <div className="min-w-0 flex-1">
              <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-black/38">账户资料</div>
              <div className="mt-2 break-words text-[28px] font-semibold tracking-[-0.04em] text-[#071110]">
                {userName}
              </div>
              <div className="mt-2 text-sm text-black/56">{userEmail}</div>
              <div className="mt-1 text-sm text-black/46">@{username}</div>
            </div>
          </div>
        </section>

        <section className="grid gap-3 md:grid-cols-2">
          <div className="rounded-[22px] border border-[#d8e1dd] bg-white p-5">
            <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-black/38">用户 ID</div>
            <div className="mt-3 break-all text-sm leading-6 text-[#18211f]">{userId || '未提供'}</div>
          </div>
          <div className="rounded-[22px] border border-[#d8e1dd] bg-white p-5">
            <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-black/38">当前角色</div>
            <div className="mt-3 text-sm font-semibold text-[#18211f]">{userRoleLabel}</div>
          </div>
        </section>

        <section className="rounded-[22px] border border-[#d8e1dd] bg-white p-5">
          <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-black/38">补充信息</div>
          <div className="mt-4 grid gap-3">
            <div className="rounded-[18px] border border-[#eef1ef] bg-[#f6f8f7] px-4 py-3">
              <div className="text-[11px] font-semibold uppercase tracking-[0.14em] text-black/34">Bio</div>
              <div className="mt-2 text-sm leading-6 text-[#18211f]">{userBio?.trim() || '未填写'}</div>
            </div>
            <div className="rounded-[18px] border border-[#eef1ef] bg-[#f6f8f7] px-4 py-3">
              <div className="text-[11px] font-semibold uppercase tracking-[0.14em] text-black/34">Location</div>
              <div className="mt-2 text-sm leading-6 text-[#18211f]">{userLocation?.trim() || '未填写'}</div>
            </div>
          </div>
        </section>
      </div>
    );
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-[rgba(7,17,16,0.36)] p-4" onClick={onClose}>
      <div
        className="flex h-[min(720px,calc(100vh-32px))] w-full max-w-5xl overflow-hidden rounded-[32px] border border-[#d7ded9] bg-[#f4f6f5] shadow-[0_24px_80px_rgba(7,17,16,0.18)]"
        onClick={(event) => event.stopPropagation()}
      >
        <aside className="flex w-[280px] shrink-0 flex-col border-r border-[#dce3df] bg-[linear-gradient(180deg,#eef4f1_0%,#f7faf8_100%)] p-5">
          <div className="flex items-center justify-between">
            <div>
              <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-black/36">设置</div>
              <div className="mt-1 text-[24px] font-semibold tracking-[-0.04em] text-[#071110]">后台账户</div>
            </div>
            <button
              type="button"
              onClick={onClose}
              className="grid size-10 place-items-center rounded-full border border-[#d7ded9] bg-white text-[#18211f]"
            >
              <X className="size-4" />
            </button>
          </div>

          <div className="mt-5 flex items-center gap-3 rounded-[22px] border border-[#dde5e1] bg-white px-3 py-3">
            <span className="relative grid size-12 shrink-0 place-items-center overflow-hidden rounded-full bg-[#071110] text-sm font-extrabold text-white">
              {userAvatarUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={userAvatarUrl} alt={userName} className="h-full w-full object-cover" />
              ) : (
                initialsFromName(userName || userEmail || username)
              )}
            </span>
            <div className="min-w-0">
              <div className="line-clamp-2 break-words text-sm font-semibold leading-5 text-[#071110]">{userName}</div>
              <div className="mt-1 text-xs text-black/48">{userRoleLabel}</div>
            </div>
          </div>

          <div className="mt-5 space-y-2">
            {SIDEBAR_SETTINGS_TABS.map((tab) => {
              const Icon = tab.icon;
              const active = activeTab === tab.key;
              return (
                <button
                  key={tab.key}
                  type="button"
                  onClick={() => setActiveTab(tab.key)}
                  className={clsx(
                    'flex w-full items-start gap-3 rounded-[20px] px-4 py-3 text-left transition',
                    active ? 'bg-[#071110] text-white' : 'border border-transparent bg-white text-[#18211f] hover:border-[#d7ded9]'
                  )}
                >
                  <span className={clsx('mt-0.5 grid size-8 shrink-0 place-items-center rounded-full', active ? 'bg-white/14' : 'bg-[#f1f4f2]')}>
                    <Icon className="size-4" />
                  </span>
                  <span className="min-w-0">
                    <div className="text-sm font-semibold">{tab.label}</div>
                    <div className={clsx('mt-1 text-xs leading-5', active ? 'text-white/74' : 'text-black/48')}>
                      {tab.description}
                    </div>
                  </span>
                </button>
              );
            })}
          </div>
        </aside>

        <section className="min-w-0 flex-1 overflow-y-auto p-6 admin-shell-scrollbar">{renderRightPane()}</section>
      </div>
    </div>
  );
}

function Sidebar({
  collapsed,
  setCollapsed,
  mobileOpen,
  setMobileOpen,
  showProfileFooter,
}: {
  collapsed: boolean;
  setCollapsed: (next: boolean) => void;
  mobileOpen: boolean;
  setMobileOpen: (next: boolean) => void;
  showProfileFooter?: boolean;
}) {
  const pathname = usePathname();
  const { user } = useAuth();
  const policy = useMemo(() => getAdminCmsRolePolicy(user), [user]);
  const groups = useMemo(() => getVisibleAdminNavGroups(policy), [policy]);
  const scrollAreaRef = useRef<HTMLDivElement | null>(null);
  const [groupOpenState, setGroupOpenState] = useState<Record<string, boolean>>({});

  const groupActiveState = useMemo(
    () =>
      Object.fromEntries(
        groups.map((group) => [
          group.id,
          group.items.some((item) => isAdminHrefActive(pathname, item.href, item.matchMode)),
        ])
      ) as Record<string, boolean>,
    [groups, pathname]
  );

  useEffect(() => {
    if (typeof window === 'undefined') return;
    const nextScrollTop = Number(window.sessionStorage.getItem(SIDEBAR_SCROLL_KEY) || '0');
    if (!Number.isFinite(nextScrollTop)) return;

    const restore = () => {
      if (scrollAreaRef.current) {
        scrollAreaRef.current.scrollTop = nextScrollTop;
      }
    };

    restore();
    window.requestAnimationFrame(restore);
  }, [pathname]);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    try {
      const raw = window.localStorage.getItem(SIDEBAR_GROUP_STATE_KEY);
      const parsed = raw ? (JSON.parse(raw) as Record<string, boolean>) : {};
      const nextState: Record<string, boolean> = {};

      for (const group of groups) {
        const savedValue = parsed[group.id];
        nextState[group.id] = typeof savedValue === 'boolean' ? savedValue : true;
        if (groupActiveState[group.id]) {
          nextState[group.id] = true;
        }
      }

      setGroupOpenState(nextState);
    } catch {
      setGroupOpenState(
        Object.fromEntries(groups.map((group) => [group.id, true])) as Record<string, boolean>
      );
    }
  }, [groups, groupActiveState]);

  useEffect(() => {
    setGroupOpenState((current) => {
      let changed = false;
      const next = { ...current };
      for (const group of groups) {
        if (!(group.id in next)) {
          next[group.id] = true;
          changed = true;
        }
        if (groupActiveState[group.id] && next[group.id] === false) {
          next[group.id] = true;
          changed = true;
        }
      }

      return changed ? next : current;
    });
  }, [groups, groupActiveState]);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    window.localStorage.setItem(SIDEBAR_GROUP_STATE_KEY, JSON.stringify(groupOpenState));
  }, [groupOpenState]);

  const persistSidebarScroll = () => {
    if (typeof window === 'undefined' || !scrollAreaRef.current) return;
    window.sessionStorage.setItem(SIDEBAR_SCROLL_KEY, String(scrollAreaRef.current.scrollTop));
  };

  const toggleGroup = (groupId: string) => {
    setGroupOpenState((current) => {
      if (groupActiveState[groupId]) {
        return { ...current, [groupId]: true };
      }
      return {
        ...current,
        [groupId]: !current[groupId],
      };
    });
  };
  return (
    <>
      <aside
        className={clsx(
          'admin-shell-sidebar fixed inset-y-0 left-0 z-30 flex h-screen shrink-0 flex-col transition-all duration-500 ease-[cubic-bezier(.22,1,.36,1)] md:relative',
          collapsed ? 'w-[92px] px-[14px]' : 'w-[246px] px-[18px]',
          mobileOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0'
        )}
      >
        <div className={clsx('mb-[28px] flex items-center', collapsed ? 'justify-center' : 'gap-3')}>
          <Triangle className="size-[24px] fill-[#071110] text-[#071110]" />
          {!collapsed && <b className="text-[18px] tracking-[-0.03em] text-[#071110]">RaveHub Admin</b>}
        </div>

        <div className={clsx('mb-[18px] flex shrink-0 items-center', collapsed ? 'justify-center' : 'justify-between px-1')}>
          <span className={clsx('text-[18px] font-bold tracking-[-0.03em] text-[#071110]', collapsed && 'hidden')}>Menu</span>
          <button
            type="button"
            onClick={() => setCollapsed(!collapsed)}
            className="grid size-8 place-items-center rounded-full transition hover:bg-white/60 active:scale-95"
          >
            <PanelLeftClose className={clsx('size-4 transition-transform duration-500', collapsed && 'rotate-180')} />
          </button>
        </div>

        <div className="relative min-h-0 flex-1">
          <div
            ref={scrollAreaRef}
            onScroll={persistSidebarScroll}
            className="absolute inset-0 overflow-y-auto px-1 py-2 admin-shell-scrollbar"
          >
            {groups.map((group) => {
              const isOpen = groupOpenState[group.id] ?? true;
              return (
                <div key={group.id} className="mb-4">
                  {!collapsed ? (
                    <button
                      type="button"
                      onClick={() => toggleGroup(group.id)}
                      className="mb-2 flex w-full items-center justify-between rounded-full px-2 py-2 text-left text-[13px] font-bold text-[#071110] transition hover:bg-white/50"
                    >
                      <span>{group.label}</span>
                      <ChevronDown
                        className={clsx(
                          'size-4 transition-transform duration-300 ease-[cubic-bezier(.22,1,.36,1)]',
                          isOpen ? 'rotate-0' : '-rotate-90'
                        )}
                      />
                    </button>
                  ) : null}

                  <div
                    className={clsx(
                      collapsed
                        ? 'grid grid-rows-[1fr] opacity-100'
                        : isOpen
                          ? 'grid grid-rows-[1fr] opacity-100'
                          : 'grid grid-rows-[0fr] opacity-70',
                      'transition-all duration-300 ease-[cubic-bezier(.22,1,.36,1)]'
                    )}
                  >
                    <div className="overflow-hidden">
                      <nav className="space-y-[7px]">
                        {group.items.map((item) => {
                          const active = isAdminHrefActive(pathname, item.href, item.matchMode);
                          const Icon = item.icon;
                          return (
                            <Link
                              key={item.href}
                              href={item.href}
                              onClick={() => {
                                persistSidebarScroll();
                                setMobileOpen(false);
                              }}
                              className={clsx(
                                'group flex h-[44px] w-full items-center rounded-full text-[13px] font-semibold transition-all duration-300 hover:-translate-y-0.5',
                                collapsed ? 'justify-center px-0' : 'gap-4 px-[15px]',
                                active
                                  ? 'bg-[#071110] text-white shadow-[0_0_28px_rgba(91,245,255,.24)]'
                                  : 'text-[#18211f] hover:bg-white/60'
                              )}
                            >
                              <span
                                className={clsx(
                                  'grid place-items-center',
                                  active ? 'text-white' : 'rounded-full bg-white/45 text-[#121b19] group-hover:bg-white/80',
                                  collapsed ? 'size-9' : 'size-7'
                                )}
                              >
                                <Icon className="size-[15px]" />
                              </span>
                              {!collapsed && <span>{item.label}</span>}
                            </Link>
                          );
                        })}
                      </nav>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {showProfileFooter ? <div className="admin-shell-profile mt-4 shrink-0 rounded-[24px] p-3" /> : null}
      </aside>
      {mobileOpen && <div onClick={() => setMobileOpen(false)} className="fixed inset-0 z-20 bg-black/20 md:hidden" />}
    </>
  );
}

function Topbar({
  title,
  eyebrow,
  description,
  actions,
  hidePageHeader,
  setMobileOpen,
  onOpenSettings,
  onAuthAction,
  authActionLabel,
  authActionTone,
  userName,
  userAvatarUrl,
}: Pick<AdminAppShellProps, 'title' | 'eyebrow' | 'description' | 'actions'> & {
  hidePageHeader?: boolean;
  setMobileOpen: (next: boolean) => void;
  onOpenSettings: () => void;
  onAuthAction: () => void;
  authActionLabel: string;
  authActionTone: 'danger' | 'success';
  userName: string;
  userAvatarUrl: string | null;
}) {
  const [query, setQuery] = useState('');

  return (
    <>
      <div className="flex h-[72px] shrink-0 items-center gap-3 pr-3 pt-[18px] md:gap-6 md:pr-[26px]">
        <button
          type="button"
          onClick={() => setMobileOpen(true)}
          className="ml-3 grid size-10 place-items-center rounded-full bg-white/60 transition hover:bg-white/80 active:scale-95 md:hidden"
        >
          <PanelLeftClose className="size-4 rotate-180" />
        </button>
        <AdminSearchField
          value={query}
          onChange={setQuery}
          placeholder="Search modules, queues, records"
          size="sm"
          className="mx-auto h-[42px] w-full max-w-[470px] bg-[#f5f5f7]"
          inputClassName="text-[12px] font-medium placeholder:text-black/40"
          onClear={query ? () => setQuery('') : undefined}
        />
        <div className="hidden items-center gap-3 md:flex">
          <div className="flex items-center gap-3">
            <span className="relative grid size-10 shrink-0 place-items-center overflow-hidden rounded-full bg-[#071110] text-[11px] font-bold text-white shadow-[0_8px_24px_rgba(7,17,16,0.12)]">
              {userAvatarUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={userAvatarUrl} alt={userName} className="h-full w-full object-cover" />
              ) : (
                initialsFromName(userName)
              )}
            </span>
            <div className="flex h-10 min-w-0 max-w-[220px] flex-col justify-between">
              <div className="truncate text-[13px] font-extrabold leading-4 text-[#071110]">{userName}</div>
              <button
                type="button"
                onClick={onAuthAction}
                className={clsx(
                  'inline-flex h-5 items-center self-start rounded-full px-2.5 text-[10px] font-bold uppercase tracking-[0.12em] text-white',
                  authActionTone === 'danger' ? 'bg-[#a92b2b]' : 'bg-[#1f9d61]'
                )}
              >
                {authActionLabel}
              </button>
            </div>
            <button
              type="button"
              onClick={onOpenSettings}
              className="grid size-10 shrink-0 place-items-center rounded-full border border-[#d7ded9] bg-[#f4f6f5] text-[#15221f] transition hover:bg-white"
              aria-label="Open admin account settings"
            >
              <Settings className="size-[15px]" />
            </button>
          </div>
        </div>
      </div>

      {!hidePageHeader ? (
        <div className="mb-5 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p className="text-[11px] font-bold uppercase tracking-[0.22em] text-black/35">{eyebrow || 'Raver Admin'}</p>
            <h1 className="mt-2 text-[32px] font-extrabold tracking-[-0.04em] text-[#071110]">{title}</h1>
            {description ? <p className="mt-3 max-w-3xl text-[14px] leading-7 text-black/48">{description}</p> : null}
          </div>
          {actions ? <div className="flex flex-wrap gap-3">{actions}</div> : null}
        </div>
      ) : null}
    </>
  );
}

export default function AdminAppShell({
  title,
  description,
  eyebrow = 'Raver Admin',
  actions,
  hidePageHeader = false,
  children,
}: AdminAppShellProps) {
  const { user, logout } = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const policy = useMemo(() => getAdminCmsRolePolicy(user), [user]);
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [settingsTab, setSettingsTab] = useState<SidebarSettingsTabKey>('profile');

  const resolvedUserName = user?.displayName?.trim() || user?.username || 'Admin User';
  const resolvedUserEmail = user?.email?.trim() || '未登录邮箱';
  const resolvedAvatarUrl = user?.avatarUrl?.trim() || user?.avatarURL?.trim() || null;
  const authActionLabel = user ? 'Sign out' : 'Sign in';
  const authActionTone = user ? 'danger' : 'success';
  const loginHref = createLoginHref(pathname);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    const nextCollapsed = window.localStorage.getItem(SIDEBAR_STATE_KEY) === '1';
    setCollapsed(nextCollapsed);
  }, []);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    window.localStorage.setItem(SIDEBAR_STATE_KEY, collapsed ? '1' : '0');
  }, [collapsed]);

  return (
    <main className="admin-ravehub-shell h-screen">
      <div className="admin-ravehub-bg" />
      <div className="relative flex h-screen overflow-hidden">
        <Sidebar
          collapsed={collapsed}
          setCollapsed={setCollapsed}
          mobileOpen={mobileOpen}
          setMobileOpen={setMobileOpen}
          showProfileFooter={false}
        />
        <div className="flex min-w-0 flex-1 overflow-hidden px-3 pb-4 md:px-4 md:pb-5">
          <section className="min-w-0 flex-1 overflow-y-auto admin-shell-scrollbar">
            <Topbar
              title={title}
              eyebrow={eyebrow}
              description={description}
              actions={actions}
              hidePageHeader={hidePageHeader}
              setMobileOpen={setMobileOpen}
              onOpenSettings={() => {
                setSettingsTab('profile');
                setSettingsOpen(true);
              }}
              onAuthAction={() => {
                if (user) {
                  logout();
                  return;
                }
                router.push(loginHref);
              }}
              authActionLabel={authActionLabel}
              authActionTone={authActionTone}
              userName={resolvedUserName}
              userAvatarUrl={resolvedAvatarUrl}
            />
            <div className="admin-shell-page pb-8">
              {children}
            </div>
          </section>
        </div>
      </div>
      <SidebarUserSettingsOverlay
        open={settingsOpen}
        onClose={() => setSettingsOpen(false)}
        onAuthAction={() => {
          if (user) {
            logout();
            return;
          }
          router.push(loginHref);
        }}
        activeTab={settingsTab}
        setActiveTab={setSettingsTab}
        userName={resolvedUserName}
        userEmail={resolvedUserEmail}
        userAvatarUrl={resolvedAvatarUrl}
        userRoleLabel={policy.label}
        userRoleDescription={policy.description}
        userCapabilities={policy.capabilities}
        userId={user?.id || ''}
        username={user?.username || ''}
        userBio={user?.bio || null}
        userLocation={user?.location || null}
        isAuthenticated={Boolean(user)}
      />
    </main>
  );
}
