'use client';

import Link from 'next/link';
import { ReactNode, useEffect, useMemo, useState } from 'react';
import { usePathname } from 'next/navigation';
import Navigation from '@/components/Navigation';
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
  groups: NavGroup[];
};

const NAV_SECTIONS: NavSection[] = [
  {
    id: 'overview',
    label: '总览台',
    description: '统一查看内容体系现状、迁移重点和工作区入口。',
    groups: [
      {
        id: 'overview-root',
        label: '后台总览',
        description: '统一内容后台首页与迁移视图。',
        items: [
          {
            href: '/admin/content',
            label: '内容总览',
            description: '统一查看活动、主办方、DJ、审核与迁移进度。',
          },
        ],
      },
    ],
  },
  {
    id: 'production',
    label: '内容生产',
    description: '承接活动、主办方、DJ 的统一创建、编辑与资料治理。',
    groups: [
      {
        id: 'events',
        label: '活动管理',
        description: '统一收口 Event Studio 的 create、edit、排期和媒体。',
        items: [
          {
            href: '/admin/content/events',
            label: '活动工作区',
            description: '查看 Event Studio 当前能力与迁移进度。',
          },
          {
            href: '/admin/content/events/catalog',
            label: '活动目录中心',
            description: '以低频快照和分页摘要管理活动全量目录。',
          },
          {
            href: '/admin/content/events/cache-governance',
            label: '目录缓存治理',
            description: '查看活动、DJ 与 Archive 摘要缓存策略与手动预热入口。',
          },
          {
            href: '/admin/content/events/new',
            label: '新建活动',
            description: '进入统一后台活动创建流程。',
          },
        ],
      },
      {
        id: 'organizers',
        label: '主办方管理',
        description: '统一承接 Brand / WikiFestival 的资料、媒体与 proof。',
        items: [
          {
            href: '/admin/content/organizers',
            label: '主办方工作区',
            description: '查看 Organizer Studio 能力与后续迁移计划。',
          },
          {
            href: '/admin/content/organizers/bindings',
            label: '活动绑定中心',
            description: '在统一后台维护活动与主办方的正式绑定关系。',
          },
          {
            href: '/admin/content/organizers/new',
            label: '新建主办方',
            description: '进入统一后台主办方创建流程。',
          },
        ],
      },
      {
        id: 'djs',
        label: 'DJ 管理',
        description: '统一承接 DJ 档案、平台链接和审核前资料治理。',
        items: [
          {
            href: '/admin/content/djs',
            label: 'DJ 工作区',
            description: '查看 DJ Studio 的迁移计划与统一入口。',
          },
          {
            href: '/admin/content/djs/catalog',
            label: 'DJ 目录中心',
            description: '以低频快照和分页摘要管理 DJ 全量目录。',
          },
          {
            href: '/admin/content/djs/new',
            label: '新建 DJ',
            description: '进入统一后台 DJ 创建流程。',
          },
        ],
      },
    ],
  },
  {
    id: 'governance',
    label: '审核与治理',
    description: '集中管理结构化审核、版本变更与内容质量治理。',
    groups: [
      {
        id: 'reviews',
        label: '审核工作台',
        description: '统一收口 review center 与 submission 管理。',
        items: [
          {
            href: '/admin/content/reviews',
            label: '审核中心',
            description: '统一管理 content submissions 与结构化审核。',
          },
          {
            href: '/admin/content/reviews/submissions',
            label: '内容贡献审核',
            description: '查看内容提交流转、结构化审核与处理路径。',
          },
          {
            href: '/admin/content/reviews/dj-bindings',
            label: 'DJ 绑定审核',
            description: '处理 DJ 自动绑定候选与阵容映射审核。',
          },
          {
            href: '/admin/content/reviews/reports',
            label: '举报审核',
            description: '管理内容举报、升级处理和模板动作。',
          },
        ],
      },
    ],
  },
  {
    id: 'migration',
    label: '迁移与支持',
    description: '保留迁移期桥接入口，逐步减少对旧工具的依赖。',
    groups: [
      {
        id: 'legacy',
        label: '迁移辅助',
        description: '保留 Festival Viewer 与专项旧工具桥接。',
        items: [
          {
            href: '/admin/content/legacy-tools',
            label: '旧工具',
            description: '迁移期保留 Festival Viewer 与专项工具入口。',
          },
          {
            href: '/admin/content/legacy-tools/festival-viewer',
            label: 'Festival Viewer',
            description: '完整旧后台入口与历史能力兜底页。',
          },
          {
            href: '/admin/content/legacy-tools/brands',
            label: '旧 Brand 工具',
            description: '历史 Brand 网格、绑定与编辑器入口。',
          },
          {
            href: '/admin/content/legacy-tools/djs',
            label: '旧 DJ 工具',
            description: '迁移期 DJ 历史资料维护与兜底入口。',
          },
          {
            href: '/admin/content/legacy-tools/archive',
            label: '旧 Archive 工具',
            description: '旧活动导入、资料整理与长尾工具入口。',
          },
          {
            href: '/admin/content/legacy-tools/archive-center',
            label: 'Archive 年份中心',
            description: '在统一后台按年份浏览历史活动摘要。',
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

export default function AdminContentLayout({
  title,
  eyebrow = 'Admin / Content Workspace',
  description,
  actions,
  children,
}: AdminContentLayoutProps) {
  const pathname = usePathname();
  const { user, isLoading } = useAuth();
  const rolePolicy = useMemo(() => getAdminCmsRolePolicy(user), [user]);
  const [expandedSections, setExpandedSections] = useState<string[]>([]);

  useEffect(() => {
    setExpandedSections((current) => {
      const autoExpanded = NAV_SECTIONS
        .filter((section) => sectionContainsPath(pathname, section))
        .map((section) => section.id);
      if (!autoExpanded.length) return current.length ? current : [NAV_SECTIONS[0]?.id].filter(Boolean);
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
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <div className="mx-auto max-w-7xl px-6 pt-28">加载中...</div>
      </main>
    );
  }

  if (!user) {
    return (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <section className="mx-auto max-w-5xl px-6 pt-28">
          <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-6">
            <div className="text-sm text-text-secondary">Admin / Content Workspace</div>
            <h1 className="mt-2 text-3xl font-semibold">请先登录后访问内容后台</h1>
            <p className="mt-3 text-sm leading-6 text-text-secondary">
              统一内容后台用于管理活动、主办方、DJ 与审核流程，需要登录后进入。
            </p>
            <div className="mt-5">
              <Link href="/login" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
                去登录
              </Link>
            </div>
          </div>
        </section>
      </main>
    );
  }

  if (!rolePolicy.canAccessContentCms) {
    return (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <section className="mx-auto max-w-5xl px-6 pt-28">
          <div className="rounded-2xl border border-border-secondary bg-bg-secondary p-6">
            <div className="text-sm text-text-secondary">Admin / Content Workspace</div>
            <h1 className="mt-2 text-3xl font-semibold">当前账号无权限访问内容后台</h1>
            <p className="mt-3 text-sm leading-6 text-text-secondary">
              当前后台能力仍然由账号角色、owner 字段与 contributor 关系共同决定。
            </p>
            <div className="mt-5">
              <Link href="/admin" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
                返回后台
              </Link>
            </div>
          </div>
        </section>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-bg-primary text-text-primary">
      <Navigation />
      <section className="mx-auto max-w-7xl px-6 pb-12 pt-24">
        <div className="grid gap-6 xl:grid-cols-[280px_minmax(0,1fr)]">
          <aside className="space-y-4">
            <div className="rounded-[28px] border border-white/10 bg-[linear-gradient(180deg,rgba(255,255,255,0.06),rgba(255,255,255,0.02)),radial-gradient(circle_at_top_left,rgba(209,171,84,0.22),transparent_38%),radial-gradient(circle_at_bottom_right,rgba(64,147,255,0.16),transparent_45%)] p-5 shadow-[0_24px_80px_rgba(0,0,0,0.24)]">
              <div className="text-[11px] uppercase tracking-[0.28em] text-text-secondary">Raver Admin</div>
              <h2 className="mt-3 text-2xl font-semibold">内容后台</h2>
              <p className="mt-3 text-sm leading-6 text-text-secondary">
                用一套简洁、分区清晰的工作台管理活动、主办方、DJ 和审核链路，逐步替代分散入口。
              </p>
              <div className="mt-5 grid gap-3">
                <div className="rounded-2xl border border-white/10 bg-black/10 px-4 py-3 text-sm">
                  <div className="text-text-secondary">当前身份</div>
                  <div className="mt-1 font-semibold">{rolePolicy.label}</div>
                </div>
                <div className="rounded-2xl border border-white/10 bg-black/10 px-4 py-3 text-sm text-text-secondary">
                  多级侧栏已作为后台主导航，方便在同一工作台里切换模块与子页面。
                </div>
              </div>
            </div>

            <nav className="rounded-[28px] border border-border-secondary bg-bg-secondary/95 p-3 shadow-[0_14px_44px_rgba(0,0,0,0.16)] backdrop-blur">
              <div className="px-3 pb-2 text-xs uppercase tracking-[0.24em] text-text-secondary">Workspace Map</div>
              <div className="space-y-3">
                {NAV_SECTIONS.map((section) => {
                  const isExpanded = expandedSections.includes(section.id);
                  const sectionActive = sectionContainsPath(pathname, section);
                  return (
                    <div
                      key={section.id}
                      className={`rounded-3xl border transition-colors ${
                        sectionActive
                          ? 'border-primary-blue/40 bg-primary-blue/5'
                          : 'border-border-secondary bg-bg-tertiary/35'
                      }`}
                    >
                      <button
                        type="button"
                        onClick={() => toggleSection(section.id)}
                        className="flex w-full items-start justify-between gap-3 px-4 py-4 text-left"
                      >
                        <div>
                          <div className="text-sm font-semibold text-text-primary">{section.label}</div>
                          <div className="mt-1 text-xs leading-5 text-text-secondary">{section.description}</div>
                        </div>
                        <div
                          className={`mt-1 rounded-full border border-border-secondary px-2 py-1 text-[11px] uppercase tracking-[0.18em] text-text-secondary transition-transform ${
                            isExpanded ? 'rotate-0' : '-rotate-90'
                          }`}
                        >
                          V
                        </div>
                      </button>

                      {isExpanded ? (
                        <div className="space-y-3 border-t border-white/5 px-3 pb-3 pt-2">
                          {section.groups.map((group) => (
                            <div key={group.id} className="rounded-2xl bg-black/10 px-3 py-3">
                              <div className="text-xs uppercase tracking-[0.18em] text-text-secondary">
                                {group.label}
                              </div>
                              <div className="mt-1 text-xs leading-5 text-text-secondary">
                                {group.description}
                              </div>
                              <div className="mt-3 space-y-2">
                                {group.items.map((item) => {
                                  const active = isActivePath(pathname, item.href);
                                  return (
                                    <Link
                                      key={item.href}
                                      href={item.href}
                                      className={`block rounded-2xl border px-4 py-3 transition-colors ${
                                        active
                                          ? 'border-primary-blue bg-primary-blue/12 text-text-primary shadow-[inset_0_0_0_1px_rgba(64,147,255,0.08)]'
                                          : 'border-border-secondary bg-bg-secondary/70 text-text-secondary hover:border-primary-blue/50 hover:text-text-primary'
                                      }`}
                                    >
                                      <div className="text-sm font-semibold">{item.label}</div>
                                      <div className="mt-1 text-xs leading-5">{item.description}</div>
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
              </div>
            </nav>

            <div className="rounded-[28px] border border-border-secondary bg-bg-secondary p-4 text-sm leading-6 text-text-secondary">
              当前阶段优先收口 Event / Organizer / DJ 三条主线，审核中心与旧工具按模块逐步回迁到这个多级后台里。
            </div>
          </aside>

          <div className="space-y-5">
            <header className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
              <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
                <div>
                  <div className="text-sm text-text-secondary">{eyebrow}</div>
                  <h1 className="mt-2 text-3xl font-semibold">{title}</h1>
                  <p className="mt-3 max-w-3xl text-sm leading-6 text-text-secondary">{description}</p>
                </div>
                {actions ? <div className="flex flex-wrap gap-3">{actions}</div> : null}
              </div>
            </header>

            {children}
          </div>
        </div>
      </section>
    </main>
  );
}
