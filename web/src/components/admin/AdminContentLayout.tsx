'use client';

import Image from 'next/image';
import Link from 'next/link';
import { ReactNode, useEffect, useMemo, useState } from 'react';
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
  description: string;
  items: NavLeaf[];
};

type NavSection = {
  id: string;
  label: string;
  description: string;
  accent: string;
  groups: NavGroup[];
};

const NAV_SECTIONS: NavSection[] = [
  {
    id: 'overview',
    label: 'Overview',
    description: '总览、状态与入口',
    accent: 'from-[#d9ff72] to-[#8edb2f]',
    groups: [
      {
        id: 'overview-root',
        label: 'Workspace',
        description: '内容运营总览',
        items: [
          {
            href: '/admin/content',
            label: '内容总览',
            description: '查看全局状态、重点任务和模块入口',
          },
        ],
      },
    ],
  },
  {
    id: 'production',
    label: 'Production',
    description: '内容目录与编辑流',
    accent: 'from-[#7dd3fc] to-[#38bdf8]',
    groups: [
      {
        id: 'events',
        label: 'Events',
        description: '活动目录、创建、编辑与缓存',
        items: [
          {
            href: '/admin/content/events',
            label: '活动工作区',
            description: '活动编辑主入口',
          },
          {
            href: '/admin/content/events/catalog',
            label: '活动目录中心',
            description: '分页摘要与快速检索',
          },
          {
            href: '/admin/content/events/cache-governance',
            label: '目录缓存治理',
            description: '缓存状态与手动预热',
          },
          {
            href: '/admin/content/events/new',
            label: '新建活动',
            description: '创建新的活动条目',
          },
        ],
      },
      {
        id: 'organizers',
        label: 'Organizers',
        description: '主办方目录、资料与绑定',
        items: [
          {
            href: '/admin/content/organizers',
            label: '主办方工作区',
            description: '主办方资料主入口',
          },
          {
            href: '/admin/content/organizers/catalog',
            label: '主办方目录中心',
            description: '目录检索与编辑跳转',
          },
          {
            href: '/admin/content/organizers/bindings',
            label: '活动绑定中心',
            description: '活动与主办方关系维护',
          },
          {
            href: '/admin/content/organizers/new',
            label: '新建主办方',
            description: '创建新的主办方条目',
          },
        ],
      },
      {
        id: 'djs',
        label: 'DJs',
        description: 'DJ 目录、档案与编辑',
        items: [
          {
            href: '/admin/content/djs',
            label: 'DJ 工作区',
            description: 'DJ 资料主入口',
          },
          {
            href: '/admin/content/djs/catalog',
            label: 'DJ 目录中心',
            description: '目录检索与快速定位',
          },
          {
            href: '/admin/content/djs/new',
            label: '新建 DJ',
            description: '创建新的 DJ 条目',
          },
        ],
      },
    ],
  },
  {
    id: 'governance',
    label: 'Governance',
    description: '审核、举报与治理',
    accent: 'from-[#fbbf24] to-[#f59e0b]',
    groups: [
      {
        id: 'reviews',
        label: 'Reviews',
        description: '审核面板与处理队列',
        items: [
          {
            href: '/admin/content/reviews',
            label: '审核中心',
            description: '统一审核总入口',
          },
          {
            href: '/admin/content/reviews/submissions',
            label: '内容贡献审核',
            description: '内容提交审批与差异查看',
          },
          {
            href: '/admin/content/reviews/dj-bindings',
            label: 'DJ 绑定审核',
            description: '阵容匹配与自动绑定候选',
          },
          {
            href: '/admin/content/reviews/reports',
            label: '举报审核',
            description: '内容举报与升级处理',
          },
        ],
      },
    ],
  },
  {
    id: 'support',
    label: 'Support',
    description: '补充工具与历史入口',
    accent: 'from-[#fb7185] to-[#f43f5e]',
    groups: [
      {
        id: 'legacy',
        label: 'Utilities',
        description: '补充工具与迁移期兜底',
        items: [
          {
            href: '/admin/content/legacy-tools',
            label: '补充工具',
            description: '查看补充能力与历史入口',
          },
          {
            href: '/admin/content/legacy-tools/festival-viewer',
            label: 'Festival Viewer',
            description: '历史工具总入口',
          },
          {
            href: '/admin/content/legacy-tools/brands',
            label: 'Brand 工具',
            description: '历史 Brand 资料工具',
          },
          {
            href: '/admin/content/legacy-tools/djs',
            label: 'DJ 工具',
            description: '历史 DJ 管理入口',
          },
          {
            href: '/admin/content/legacy-tools/archive',
            label: 'Archive 工具',
            description: '历史资料与导入处理',
          },
          {
            href: '/admin/content/legacy-tools/archive-center',
            label: 'Archive 年份中心',
            description: '按年份浏览历史活动摘要',
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
              className="inline-flex rounded-xl bg-[#d9ff72] px-5 py-3 text-sm font-semibold text-black"
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

  return (
    <main className="min-h-screen bg-[#0e0e0e] text-[#f0f0f0]">
      <div className="grid min-h-screen grid-cols-1 xl:grid-cols-[224px_minmax(0,1fr)_248px]">
        <aside className="border-b border-white/6 bg-[#141414] px-4 py-5 xl:border-b-0 xl:border-r">
          <div className="flex items-center gap-3 px-2 pb-5">
            <div className="relative flex h-10 w-10 items-center justify-center overflow-hidden rounded-full bg-[linear-gradient(135deg,#d9ff72,#7ecb2b)] text-xs font-bold text-black">
              {user.avatarUrl ? (
                <Image
                  src={user.avatarUrl}
                  alt={displayName}
                  fill
                  className="object-cover"
                  sizes="40px"
                />
              ) : (
                avatarInitials
              )}
            </div>
            <div className="min-w-0">
              <div className="truncate text-sm font-semibold text-[#f5f5f5]">{displayName}</div>
              <div className="truncate text-[11px] uppercase tracking-[0.18em] text-[#5f5f5f]">
                {rolePolicy.label}
              </div>
            </div>
          </div>

          <div className="mb-5 rounded-xl border border-white/6 bg-[#1a1a1a] px-3 py-2.5">
            <div className="flex items-center gap-2">
              <svg width="14" height="14" viewBox="0 0 16 16" fill="none" aria-hidden="true">
                <circle cx="6.5" cy="6.5" r="5" stroke="#666" strokeWidth="1.5" />
                <path d="M10.5 10.5L14 14" stroke="#666" strokeWidth="1.5" strokeLinecap="round" />
              </svg>
              <div className="flex-1 text-[12px] text-[#6c6c6c]">Search modules</div>
              <span className="rounded bg-[#101010] px-1.5 py-0.5 font-mono text-[10px] text-[#595959]">
                ⌘K
              </span>
            </div>
          </div>

          <nav className="space-y-5">
            {NAV_SECTIONS.map((section) => {
              const isExpanded = expandedSections.includes(section.id);
              const sectionActive = sectionContainsPath(pathname, section);
              return (
                <div key={section.id}>
                  <div className="mb-2 px-2 text-[10px] font-bold uppercase tracking-[0.14em] text-[#525252]">
                    {section.label}
                  </div>
                  <button
                    type="button"
                    onClick={() => toggleSection(section.id)}
                    className={`flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left transition-colors ${
                      sectionActive
                        ? 'bg-[#d9ff72] text-black'
                        : 'text-[#8a8a8a] hover:bg-[#1a1a1a] hover:text-[#f0f0f0]'
                    }`}
                  >
                    <span
                      className={`h-2.5 w-2.5 rounded-full bg-gradient-to-br ${section.accent} ${
                        sectionActive ? 'opacity-100' : 'opacity-75'
                      }`}
                    />
                    <span className="flex-1 text-[13px] font-semibold">{section.description}</span>
                    <span
                      className={`text-[10px] transition-transform ${
                        isExpanded ? 'rotate-90' : ''
                      }`}
                    >
                      ›
                    </span>
                  </button>

                  {isExpanded ? (
                    <div className="mt-2 space-y-3 pl-2">
                      {section.groups.map((group) => (
                        <div key={group.id} className="rounded-2xl bg-[#181818] px-3 py-3">
                          <div className="text-[10px] uppercase tracking-[0.18em] text-[#5e5e5e]">
                            {group.label}
                          </div>
                          <div className="mt-1 text-[11px] leading-5 text-[#6f6f6f]">
                            {group.description}
                          </div>
                          <div className="mt-3 space-y-1.5">
                            {group.items.map((item) => {
                              const active = isActivePath(pathname, item.href);
                              return (
                                <Link
                                  key={item.href}
                                  href={item.href}
                                  className={`block rounded-xl px-3 py-2.5 transition-colors ${
                                    active
                                      ? 'bg-[#222222] text-[#f5f5f5] ring-1 ring-white/10'
                                      : 'text-[#8f8f8f] hover:bg-[#202020] hover:text-[#f5f5f5]'
                                  }`}
                                >
                                  <div className="text-[12.5px] font-semibold">{item.label}</div>
                                  <div className="mt-0.5 text-[11px] leading-5 text-inherit opacity-75">
                                    {item.description}
                                  </div>
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

          <div className="mt-8 rounded-2xl border border-white/6 bg-[#181818] px-4 py-4">
            <div className="text-[10px] uppercase tracking-[0.18em] text-[#5d5d5d]">Workspace</div>
            <div className="mt-2 text-sm font-semibold text-[#f0f0f0]">Raver Content Console</div>
            <div className="mt-2 text-[12px] leading-5 text-[#7e7e7e]">
              活动、主办方、DJ 与审核在同一后台内完成管理。
            </div>
          </div>
        </aside>

        <section className="min-w-0 bg-[#111111]">
          <div className="flex items-center gap-3 border-b border-white/6 px-5 py-4">
            <div className="flex items-center gap-2 text-[#5f5f5f]">
              <span className="cursor-default text-sm">◧</span>
              <span className="cursor-default text-sm">☆</span>
            </div>
            <div className="flex items-center gap-2 text-[12px] text-[#666]">
              <span>{activeSection.label}</span>
              <span>/</span>
              <span className="text-[#9a9a9a]">{title}</span>
            </div>
            <div className="ml-auto flex items-center gap-3 text-[#666]">
              <span className="text-sm">◐</span>
              <span className="text-sm">↺</span>
              <span className="text-sm">⌁</span>
              <span className="text-sm">◎</span>
            </div>
          </div>

          <div className="flex flex-col gap-5 px-5 py-5">
            <header className="rounded-[20px] border border-white/6 bg-[#191919] px-5 py-5">
              <div className="flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between">
                <div>
                  <div className="text-[11px] uppercase tracking-[0.18em] text-[#5f5f5f]">{eyebrow}</div>
                  <h1 className="mt-2 text-[28px] font-semibold tracking-[-0.03em] text-[#f0f0f0]">
                    {title}
                  </h1>
                  <p className="mt-3 max-w-3xl text-sm leading-6 text-[#8c8c8c]">{description}</p>
                </div>
                <div className="flex flex-wrap items-center gap-3">
                  <div className="rounded-xl border border-white/6 bg-[#131313] px-3 py-2 text-[12px] text-[#8c8c8c]">
                    {CURRENT_DATE_LABEL}
                  </div>
                  {actions ? <div className="flex flex-wrap gap-3">{actions}</div> : null}
                </div>
              </div>
            </header>

            <div className="min-w-0">{children}</div>
          </div>
        </section>

        <aside className="hidden border-l border-white/6 bg-[#141414] px-4 py-5 xl:flex xl:flex-col xl:gap-6">
          <div>
            <div className="text-[13px] font-semibold text-[#f0f0f0]">Workspace Status</div>
            <div className="mt-3 space-y-3">
              <div className="rounded-2xl border border-white/6 bg-[#1a1a1a] px-4 py-3">
                <div className="text-[11px] text-[#616161]">当前模块</div>
                <div className="mt-1 text-sm font-semibold text-[#f0f0f0]">{activeSection.label}</div>
                <div className="mt-1 text-[11px] leading-5 text-[#7a7a7a]">
                  {activeSection.description}
                </div>
              </div>
              <div className="rounded-2xl border border-white/6 bg-[#1a1a1a] px-4 py-3">
                <div className="text-[11px] text-[#616161]">账号角色</div>
                <div className="mt-1 text-sm font-semibold text-[#d9ff72]">{rolePolicy.label}</div>
                <div className="mt-1 text-[11px] leading-5 text-[#7a7a7a]">{rolePolicy.description}</div>
              </div>
            </div>
          </div>

          <div>
            <div className="text-[13px] font-semibold text-[#f0f0f0]">重点能力</div>
            <div className="mt-3 space-y-2">
              {capabilityHighlights.length > 0 ? (
                capabilityHighlights.map((item) => (
                  <div
                    key={item}
                    className="rounded-xl border border-white/6 bg-[#1a1a1a] px-3 py-3 text-[12px] leading-5 text-[#8a8a8a]"
                  >
                    {item}
                  </div>
                ))
              ) : (
                <div className="rounded-xl border border-white/6 bg-[#1a1a1a] px-3 py-3 text-[12px] leading-5 text-[#8a8a8a]">
                  当前账号暂无额外重点能力说明。
                </div>
              )}
            </div>
          </div>

          <div>
            <div className="text-[13px] font-semibold text-[#f0f0f0]">Quick Links</div>
            <div className="mt-3 space-y-2">
              {[
                { href: '/admin/content/events/new', label: '创建活动' },
                { href: '/admin/content/organizers/new', label: '创建主办方' },
                { href: '/admin/content/djs/new', label: '创建 DJ' },
                { href: '/admin/content/reviews/submissions', label: '处理审核队列' },
              ].map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  className="flex items-center justify-between rounded-xl border border-white/6 bg-[#1a1a1a] px-3 py-3 text-[12px] text-[#d3d3d3] transition-colors hover:bg-[#202020]"
                >
                  <span>{item.label}</span>
                  <span className="text-[#666]">›</span>
                </Link>
              ))}
            </div>
          </div>
        </aside>
      </div>
    </main>
  );
}
