'use client';

import Image from 'next/image';
import Link from 'next/link';
import { CSSProperties, ReactNode, useEffect, useMemo, useState } from 'react';
import { usePathname } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { getAdminCmsRolePolicy } from '@/lib/admin/role-policy';

type NavLeaf = {
  href: string;
  label: string;
  description: string;
};

type NavGroup = {
  id: string;
  label: string;
  items: NavLeaf[];
};

type NavSection = {
  id: string;
  label: string;
  description: string;
  icon: string;
  groups: NavGroup[];
};

const NAV_SECTIONS: NavSection[] = [
  {
    id: 'overview',
    label: 'Dashboards',
    description: 'Overview',
    icon: '⊞',
    groups: [
      {
        id: 'overview-root',
        label: 'Overview',
        items: [
          {
            href: '/admin/content',
            label: '内容总览',
            description: '全局入口与控制台',
          },
        ],
      },
    ],
  },
  {
    id: 'production',
    label: 'Content',
    description: 'Production',
    icon: '◫',
    groups: [
      {
        id: 'events',
        label: 'Events',
        items: [
          {
            href: '/admin/content/events',
            label: '活动工作区',
            description: '活动主入口',
          },
          {
            href: '/admin/content/events/catalog',
            label: '活动目录中心',
            description: '目录与检索',
          },
          {
            href: '/admin/content/events/cache-governance',
            label: '目录缓存治理',
            description: '缓存状态与预热',
          },
          {
            href: '/admin/content/events/new',
            label: '新建活动',
            description: '创建活动',
          },
        ],
      },
      {
        id: 'organizers',
        label: 'Organizers',
        items: [
          {
            href: '/admin/content/organizers',
            label: '主办方工作区',
            description: '主办方主入口',
          },
          {
            href: '/admin/content/organizers/catalog',
            label: '主办方目录中心',
            description: '目录与检索',
          },
          {
            href: '/admin/content/organizers/bindings',
            label: '活动绑定中心',
            description: '关系维护',
          },
          {
            href: '/admin/content/organizers/new',
            label: '新建主办方',
            description: '创建主办方',
          },
        ],
      },
      {
        id: 'djs',
        label: 'DJs',
        items: [
          {
            href: '/admin/content/djs',
            label: 'DJ 工作区',
            description: 'DJ 主入口',
          },
          {
            href: '/admin/content/djs/catalog',
            label: 'DJ 目录中心',
            description: '目录与检索',
          },
          {
            href: '/admin/content/djs/new',
            label: '新建 DJ',
            description: '创建 DJ',
          },
        ],
      },
    ],
  },
  {
    id: 'governance',
    label: 'Governance',
    description: 'Reviews',
    icon: '✓',
    groups: [
      {
        id: 'reviews',
        label: 'Review Center',
        items: [
          {
            href: '/admin/content/reviews',
            label: '审核中心',
            description: '审核总览',
          },
          {
            href: '/admin/content/reviews/submissions',
            label: '内容贡献审核',
            description: '内容审批',
          },
          {
            href: '/admin/content/reviews/dj-bindings',
            label: 'DJ 绑定审核',
            description: '绑定处理',
          },
          {
            href: '/admin/content/reviews/reports',
            label: '举报审核',
            description: '举报处理',
          },
        ],
      },
    ],
  },
  {
    id: 'support',
    label: 'Support',
    description: 'Utilities',
    icon: '⋯',
    groups: [
      {
        id: 'legacy',
        label: 'Utilities',
        items: [
          {
            href: '/admin/content/legacy-tools',
            label: '补充工具',
            description: '统一补充入口',
          },
          {
            href: '/admin/content/legacy-tools/festival-viewer',
            label: 'Festival Viewer',
            description: '历史工具入口',
          },
          {
            href: '/admin/content/legacy-tools/brands',
            label: 'Brand 工具',
            description: '历史 Brand 工具',
          },
          {
            href: '/admin/content/legacy-tools/djs',
            label: 'DJ 工具',
            description: '历史 DJ 工具',
          },
          {
            href: '/admin/content/legacy-tools/archive',
            label: 'Archive 工具',
            description: '历史资料工具',
          },
          {
            href: '/admin/content/legacy-tools/archive-center',
            label: 'Archive 年份中心',
            description: '历史摘要',
          },
        ],
      },
    ],
  },
];

type AdminContentLayoutProps = {
  title: string;
  eyebrow?: string;
  description: string;
  actions?: ReactNode;
  children: ReactNode;
};

const isActivePath = (pathname: string, href: string): boolean => {
  if (href === '/admin/content') {
    return pathname === href;
  }
  return pathname === href || pathname.startsWith(`${href}/`);
};

const sectionContainsPath = (pathname: string, section: NavSection): boolean =>
  section.groups.some((group) => group.items.some((item) => isActivePath(pathname, item.href)));

const initialsFromName = (value: string): string =>
  value
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((item) => item.slice(0, 1).toUpperCase())
    .join('') || 'RA';

const CURRENT_DATE_LABEL = new Intl.DateTimeFormat('en-US', {
  month: 'short',
  day: 'numeric',
  year: 'numeric',
}).format(new Date());

const LEFT_COLLAPSE_KEY = 'raver-admin-left-collapsed';
const RIGHT_COLLAPSE_KEY = 'raver-admin-right-collapsed';

export default function AdminContentLayout({
  title,
  eyebrow = 'Raver Admin / Content',
  description,
  actions,
  children,
}: AdminContentLayoutProps) {
  const pathname = usePathname();
  const { user, isLoading } = useAuth();
  const rolePolicy = useMemo(() => getAdminCmsRolePolicy(user), [user]);
  const [expandedSections, setExpandedSections] = useState<string[]>([]);
  const [leftCollapsed, setLeftCollapsed] = useState(false);
  const [rightCollapsed, setRightCollapsed] = useState(false);
  const activeSection = useMemo(
    () => NAV_SECTIONS.find((section) => sectionContainsPath(pathname, section)) ?? NAV_SECTIONS[0],
    [pathname]
  );

  useEffect(() => {
    setExpandedSections((current) => {
      const autoExpanded = NAV_SECTIONS
        .filter((section) => sectionContainsPath(pathname, section))
        .map((section) => section.id);
      if (!autoExpanded.length) {
        return current.length ? current : [NAV_SECTIONS[0]?.id].filter(Boolean);
      }
      const merged = new Set([...current, ...autoExpanded]);
      return Array.from(merged);
    });
  }, [pathname]);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    setLeftCollapsed(window.localStorage.getItem(LEFT_COLLAPSE_KEY) === '1');
    setRightCollapsed(window.localStorage.getItem(RIGHT_COLLAPSE_KEY) === '1');
  }, []);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    window.localStorage.setItem(LEFT_COLLAPSE_KEY, leftCollapsed ? '1' : '0');
  }, [leftCollapsed]);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    window.localStorage.setItem(RIGHT_COLLAPSE_KEY, rightCollapsed ? '1' : '0');
  }, [rightCollapsed]);

  const toggleSection = (sectionId: string) => {
    setExpandedSections((current) =>
      current.includes(sectionId)
        ? current.filter((item) => item !== sectionId)
        : [...current, sectionId]
    );
  };

  if (isLoading) {
    return (
      <main className="min-h-screen bg-[#0d0d0d] text-[#f1f1f1]">
        <div className="flex min-h-screen items-center justify-center text-sm text-[#8a8a8a]">
          正在加载后台...
        </div>
      </main>
    );
  }

  if (!user) {
    return (
      <main className="min-h-screen bg-[#0d0d0d] px-6 py-10 text-[#f1f1f1]">
        <section className="mx-auto max-w-3xl rounded-[28px] border border-white/10 bg-[#171717] p-8">
          <div className="text-[11px] uppercase tracking-[0.24em] text-[#666]">Raver Admin</div>
          <h1 className="mt-3 text-3xl font-semibold">请先登录</h1>
          <p className="mt-4 max-w-2xl text-sm leading-6 text-[#8a8a8a]">
            登录后可进入活动、主办方、DJ 与审核管理工作台。
          </p>
          <div className="mt-6">
            <Link
              href="/login"
              className="inline-flex rounded-xl bg-[#a8ff3e] px-5 py-3 text-sm font-semibold text-black"
            >
              去登录
            </Link>
          </div>
        </section>
      </main>
    );
  }

  if (!rolePolicy.canAccessContentCms) {
    return (
      <main className="min-h-screen bg-[#0d0d0d] px-6 py-10 text-[#f1f1f1]">
        <section className="mx-auto max-w-3xl rounded-[28px] border border-white/10 bg-[#171717] p-8">
          <div className="text-[11px] uppercase tracking-[0.24em] text-[#666]">Raver Admin</div>
          <h1 className="mt-3 text-3xl font-semibold">当前账号暂不可访问</h1>
          <p className="mt-4 max-w-2xl text-sm leading-6 text-[#8a8a8a]">
            当前权限未开放内容后台入口，请切换具备权限的账号后访问。
          </p>
          <div className="mt-6">
            <Link
              href="/admin"
              className="inline-flex rounded-xl border border-white/10 px-5 py-3 text-sm text-[#cfcfcf]"
            >
              返回后台
            </Link>
          </div>
        </section>
      </main>
    );
  }

  const displayName = user.displayName || user.username || 'Raver Admin';
  const avatarInitials = initialsFromName(displayName);
  const capabilityHighlights = rolePolicy.capabilities.slice(0, 3);
  const shellStyle = {
    '--admin-left': leftCollapsed ? '76px' : '208px',
    '--admin-right': rightCollapsed ? '52px' : '212px',
  } as CSSProperties;

  return (
    <main className="min-h-screen bg-[#0e0e0e] text-[#f0f0f0] xl:h-screen xl:overflow-hidden">
      <div
        style={shellStyle}
        className="grid min-h-screen grid-cols-1 xl:h-screen xl:grid-cols-[var(--admin-left)_minmax(0,1fr)_var(--admin-right)] xl:overflow-hidden"
      >
        <aside className="border-b border-[rgba(255,255,255,0.07)] bg-[#141414] xl:h-screen xl:overflow-hidden xl:border-b-0 xl:border-r">
          <div className="flex h-full flex-col px-3 py-4">
            <div className={`flex items-center ${leftCollapsed ? 'justify-center' : 'gap-3 px-2'} pb-4`}>
              <div className="relative flex h-9 w-9 items-center justify-center overflow-hidden rounded-full bg-[linear-gradient(135deg,#a8ff3e,#7fe11e)] text-[11px] font-bold text-black">
                {user.avatarUrl ? (
                  <Image
                    src={user.avatarUrl}
                    alt={displayName}
                    fill
                    className="object-cover"
                    sizes="36px"
                  />
                ) : (
                  avatarInitials
                )}
              </div>
              {!leftCollapsed ? (
                <>
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[13px] font-semibold text-[#f0f0f0]">{displayName}</div>
                    <div className="truncate text-[10px] uppercase tracking-[0.16em] text-[#666]">
                      {rolePolicy.label}
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => setLeftCollapsed(true)}
                    className="flex h-8 w-8 items-center justify-center rounded-lg border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] text-[#777] hover:text-[#f0f0f0]"
                    aria-label="收起左侧栏"
                  >
                    ‹
                  </button>
                </>
              ) : null}
            </div>

            {leftCollapsed ? (
              <div className="flex-1 overflow-y-auto overflow-x-hidden">
                <div className="flex flex-col items-center gap-3 pt-2">
                  <button
                    type="button"
                    onClick={() => setLeftCollapsed(false)}
                    className="flex h-10 w-10 items-center justify-center rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] text-[#a8ff3e]"
                    aria-label="展开左侧栏"
                  >
                    ›
                  </button>
                  {NAV_SECTIONS.map((section) => {
                    const active = sectionContainsPath(pathname, section);
                    return (
                      <button
                        key={section.id}
                        type="button"
                        onClick={() => {
                          setLeftCollapsed(false);
                          toggleSection(section.id);
                        }}
                        className={`flex h-10 w-10 items-center justify-center rounded-xl border text-sm transition-colors ${
                          active
                            ? 'border-[#a8ff3e] bg-[#a8ff3e] text-black'
                            : 'border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] text-[#8a8a8a] hover:text-[#f0f0f0]'
                        }`}
                        aria-label={section.label}
                      >
                        {section.icon}
                      </button>
                    );
                  })}
                </div>
              </div>
            ) : (
              <>
                <div className="mb-4 rounded-[10px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-3 py-2">
                  <div className="flex items-center gap-2">
                    <svg width="13" height="13" viewBox="0 0 16 16" fill="none" aria-hidden="true">
                      <circle cx="6.5" cy="6.5" r="5" stroke="#666" strokeWidth="1.5" />
                      <path d="M10.5 10.5L14 14" stroke="#666" strokeWidth="1.5" strokeLinecap="round" />
                    </svg>
                    <div className="flex-1 text-[12px] text-[#777]">Search...</div>
                    <span className="rounded bg-[#101010] px-1.5 py-0.5 font-mono text-[10px] text-[#5a5a5a]">
                      ⌘K
                    </span>
                  </div>
                </div>

                <div className="flex-1 overflow-y-auto overflow-x-hidden pr-1">
                  <nav className="space-y-5">
                    {NAV_SECTIONS.map((section) => {
                      const isExpanded = expandedSections.includes(section.id);
                      const sectionActive = sectionContainsPath(pathname, section);
                      return (
                        <div key={section.id}>
                          <div className="mb-2 px-2 text-[10px] font-bold uppercase tracking-[0.1em] text-[#555]">
                            {section.label}
                          </div>
                          <button
                            type="button"
                            onClick={() => toggleSection(section.id)}
                            className={`flex w-full items-center gap-3 rounded-[10px] px-3 py-2.5 text-left text-[12.5px] font-medium transition-colors ${
                              sectionActive
                                ? 'bg-[#a8ff3e] text-black'
                                : 'text-[#8b8b8b] hover:bg-[#1a1a1a] hover:text-[#f0f0f0]'
                            }`}
                          >
                            <span className="w-4 text-center text-[13px]">{section.icon}</span>
                            <span className="flex-1">{section.description}</span>
                            <span className={`text-[10px] opacity-60 transition-transform ${isExpanded ? 'rotate-90' : ''}`}>
                              ›
                            </span>
                          </button>

                          {isExpanded ? (
                            <div className="mt-2 border-l border-[rgba(255,255,255,0.06)] pl-3">
                              {section.groups.map((group) => (
                                <div key={group.id} className="mb-3 last:mb-0">
                                  <div className="px-2 pb-1 text-[10px] font-semibold uppercase tracking-[0.16em] text-[#5b5b5b]">
                                    {group.label}
                                  </div>
                                  <div className="space-y-1">
                                    {group.items.map((item) => {
                                      const active = isActivePath(pathname, item.href);
                                      return (
                                        <Link
                                          key={item.href}
                                          href={item.href}
                                          className={`flex items-center gap-3 rounded-[10px] px-3 py-2.5 transition-colors ${
                                            active
                                              ? 'bg-[#202020] text-[#f3f3f3]'
                                              : 'text-[#868686] hover:bg-[#1a1a1a] hover:text-[#f0f0f0]'
                                          }`}
                                        >
                                          <span className={`h-1.5 w-1.5 rounded-full ${active ? 'bg-[#a8ff3e]' : 'bg-[#4b4b4b]'}`} />
                                          <div className="min-w-0 flex-1">
                                            <div className="truncate text-[12.5px] font-medium">{item.label}</div>
                                            <div className="truncate text-[10px] text-inherit opacity-55">
                                              {item.description}
                                            </div>
                                          </div>
                                          <span className="text-[10px] opacity-35">›</span>
                                        </Link>
                                      );
                                    })}
                                  </div>
                                </div>
                              ))}
                            </div>
                          ) : null}
                        </div>
                      );
                    })}
                  </nav>
                </div>

                <div className="mt-4 rounded-[12px] border border-[rgba(255,255,255,0.07)] bg-[#181818] px-4 py-3">
                  <div className="text-[10px] uppercase tracking-[0.14em] text-[#555]">Workspace</div>
                  <div className="mt-2 text-[12px] font-semibold text-[#f0f0f0]">Content Console</div>
                  <div className="mt-1 text-[11px] leading-5 text-[#777]">
                    活动、主办方、DJ 与审核统一管理。
                  </div>
                </div>
              </>
            )}
          </div>
        </aside>

        <section className="min-w-0 bg-[#111111] xl:flex xl:h-screen xl:flex-col xl:overflow-hidden">
          <div className="flex items-center gap-3 border-b border-[rgba(255,255,255,0.07)] px-5 py-3.5">
            <button
              type="button"
              onClick={() => setLeftCollapsed((current) => !current)}
              className="flex h-8 w-8 items-center justify-center rounded-lg border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] text-[#777] hover:text-[#f0f0f0]"
              aria-label={leftCollapsed ? '展开左侧栏' : '收起左侧栏'}
            >
              {leftCollapsed ? '›' : '‹'}
            </button>
            <div className="flex items-center gap-2 text-[#666]">
              <span className="text-sm">◧</span>
              <span className="text-sm">☆</span>
            </div>
            <div className="flex items-center gap-2 text-[12px] text-[#5e5e5e]">
              <span>{activeSection.label}</span>
              <span>/</span>
              <span className="text-[#8f8f8f]">{title}</span>
            </div>
            <div className="ml-auto flex items-center gap-2">
              <div className="rounded-[10px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-3 py-1.5 text-[11px] text-[#8b8b8b]">
                {CURRENT_DATE_LABEL}
              </div>
              <button
                type="button"
                onClick={() => setRightCollapsed((current) => !current)}
                className="flex h-8 w-8 items-center justify-center rounded-lg border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] text-[#777] hover:text-[#f0f0f0]"
                aria-label={rightCollapsed ? '展开右侧栏' : '收起右侧栏'}
              >
                {rightCollapsed ? '‹' : '›'}
              </button>
            </div>
          </div>

          <div className="flex-1 overflow-y-auto overflow-x-hidden">
            <div className="flex flex-col gap-5 px-5 py-5">
              <header className="rounded-[18px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-5 py-5">
                <div className="flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between">
                  <div>
                    <div className="text-[11px] uppercase tracking-[0.18em] text-[#5f5f5f]">{eyebrow}</div>
                    <h1 className="mt-2 text-[28px] font-semibold tracking-[-0.03em] text-[#f0f0f0]">
                      {title}
                    </h1>
                    <p className="mt-3 max-w-3xl text-sm leading-6 text-[#8a8a8a]">{description}</p>
                  </div>
                  {actions ? <div className="flex flex-wrap gap-3">{actions}</div> : null}
                </div>
              </header>

              <div className="min-w-0">{children}</div>
            </div>
          </div>
        </section>

        <aside className="hidden border-l border-[rgba(255,255,255,0.07)] bg-[#141414] xl:block xl:h-screen xl:overflow-hidden">
          <div className="flex h-full flex-col">
            {rightCollapsed ? (
              <div className="flex h-full flex-col items-center gap-3 px-2 py-4">
                <button
                  type="button"
                  onClick={() => setRightCollapsed(false)}
                  className="flex h-10 w-10 items-center justify-center rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] text-[#a8ff3e]"
                  aria-label="展开右侧栏"
                >
                  ‹
                </button>
                <div className="mt-4 text-[10px] uppercase tracking-[0.24em] text-[#5b5b5b] [writing-mode:vertical-rl]">
                  STATUS
                </div>
              </div>
            ) : (
              <div className="flex h-full flex-col px-4 py-4">
                <div className="mb-4 flex items-center justify-between">
                  <div className="text-[13px] font-semibold text-[#f0f0f0]">Workspace</div>
                  <button
                    type="button"
                    onClick={() => setRightCollapsed(true)}
                    className="flex h-8 w-8 items-center justify-center rounded-lg border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] text-[#777] hover:text-[#f0f0f0]"
                    aria-label="收起右侧栏"
                  >
                    ›
                  </button>
                </div>

                <div className="flex-1 overflow-y-auto overflow-x-hidden pr-1">
                  <div className="space-y-5">
                    <div>
                      <div className="mb-3 text-[13px] font-semibold text-[#f0f0f0]">Status</div>
                      <div className="space-y-3">
                        <div className="rounded-[14px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-4 py-3">
                          <div className="text-[11px] text-[#616161]">Current module</div>
                          <div className="mt-1 text-sm font-semibold text-[#f0f0f0]">{activeSection.description}</div>
                          <div className="mt-1 text-[11px] text-[#7a7a7a]">{title}</div>
                        </div>
                        <div className="rounded-[14px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-4 py-3">
                          <div className="text-[11px] text-[#616161]">Role</div>
                          <div className="mt-1 text-sm font-semibold text-[#a8ff3e]">{rolePolicy.label}</div>
                          <div className="mt-1 text-[11px] leading-5 text-[#7a7a7a]">{rolePolicy.description}</div>
                        </div>
                      </div>
                    </div>

                    <div>
                      <div className="mb-3 text-[13px] font-semibold text-[#f0f0f0]">Highlights</div>
                      <div className="space-y-2">
                        {capabilityHighlights.length > 0 ? (
                          capabilityHighlights.map((item) => (
                            <div
                              key={item}
                              className="rounded-[12px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-3 py-3 text-[12px] leading-5 text-[#8a8a8a]"
                            >
                              {item}
                            </div>
                          ))
                        ) : (
                          <div className="rounded-[12px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-3 py-3 text-[12px] leading-5 text-[#8a8a8a]">
                            当前账号暂无额外能力说明。
                          </div>
                        )}
                      </div>
                    </div>

                    <div>
                      <div className="mb-3 text-[13px] font-semibold text-[#f0f0f0]">Quick links</div>
                      <div className="space-y-2">
                        {[
                          { href: '/admin/content/events/new', label: '创建活动' },
                          { href: '/admin/content/organizers/new', label: '创建主办方' },
                          { href: '/admin/content/djs/new', label: '创建 DJ' },
                          { href: '/admin/content/reviews/submissions', label: '处理审核队列' },
                        ].map((item) => (
                          <Link
                            key={item.href}
                            href={item.href}
                            className="flex items-center justify-between rounded-[12px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-3 py-3 text-[12px] text-[#d0d0d0] transition-colors hover:bg-[#202020]"
                          >
                            <span>{item.label}</span>
                            <span className="text-[#666]">›</span>
                          </Link>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </aside>
      </div>
    </main>
  );
}
