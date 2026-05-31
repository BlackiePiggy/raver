'use client';

import Link from 'next/link';
import {
  ChevronRight,
  CircleAlert,
  Ellipsis,
  FileText,
  FolderOpen,
  Link2,
  Plus,
  Users,
} from 'lucide-react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

const PRIMARY_ACTIONS = [
  {
    title: '查看主办方目录',
    description: '浏览和管理所有主办方资料、城市、国家、视觉素材和链接。',
    href: '/admin/content/organizers/catalog',
    buttonLabel: '进入主办方目录',
    icon: FolderOpen,
    tone: 'from-[#edf5ff] to-[#f8fbff]',
    iconTone: 'bg-[#3b82f6] text-white shadow-[0_10px_28px_rgba(59,130,246,0.28)]',
  },
  {
    title: '新建主办方',
    description: '创建新的主办方条目，设置名称、简介、链接和视觉素材。',
    href: '/admin/content/organizers/new',
    buttonLabel: '新建主办方',
    icon: Plus,
    tone: 'from-[#edfff3] to-[#fbfffc]',
    iconTone: 'bg-[#22c55e] text-white shadow-[0_10px_28px_rgba(34,197,94,0.28)]',
  },
  {
    title: '绑定活动关系',
    description: '为活动分配主办方，建立归属关系并统一进入绑定工作流。',
    href: '/admin/content/organizers/bindings',
    buttonLabel: '进入绑定中心',
    icon: Users,
    tone: 'from-[#f5f0ff] to-[#fcfbff]',
    iconTone: 'bg-[#8b5cf6] text-white shadow-[0_10px_28px_rgba(139,92,246,0.28)]',
  },
];

const KEY_ENTRIES = [
  {
    status: 'Ready',
    statusTone: 'bg-[#ebf9ef] text-[#28a258]',
    dotTone: 'bg-[#22c55e]',
    title: '主办方目录中心',
    meta: '快速检索 · 一键编辑 · 资料浏览',
    date: 'Catalog',
    href: '/admin/content/organizers/catalog',
  },
  {
    status: 'On',
    statusTone: 'bg-[#f9f2dc] text-[#a8841b]',
    dotTone: 'bg-[#fbbf24]',
    title: '主办方创建流程',
    meta: '基础资料 · 官方链接 · 图片素材',
    date: 'Create',
    href: '/admin/content/organizers/new',
  },
  {
    status: 'Patch',
    statusTone: 'bg-[#faebec] text-[#b05664]',
    dotTone: 'bg-[#fb7185]',
    title: '活动绑定工作流',
    meta: '关系定位 · 清空绑定 · 批量治理',
    date: 'Bind',
    href: '/admin/content/organizers/bindings',
  },
  {
    status: 'Edit',
    statusTone: 'bg-[#edf4ff] text-[#3b82f6]',
    dotTone: 'bg-[#60a5fa]',
    title: '主办方编辑工作区',
    meta: '资料回填 · 链接修订 · 素材更新',
    date: 'Edit',
    href: '/admin/content/organizers/catalog',
  },
];

const PENDING_ITEMS = [
  {
    title: '待处理活动绑定',
    count: '3',
    href: '/admin/content/organizers/bindings',
    icon: Users,
    tone: 'bg-[#f3ecff] text-[#8b5cf6]',
  },
  {
    title: '待审核的主办方变更',
    count: '4',
    href: '/admin/content/reviews/submissions',
    icon: FileText,
    tone: 'bg-[#eaf8ee] text-[#22c55e]',
  },
  {
    title: '资料缺链接待补',
    count: '2',
    href: '/admin/content/organizers/catalog',
    icon: Link2,
    tone: 'bg-[#eef5ff] text-[#3b82f6]',
  },
  {
    title: '举报待处理',
    count: '1',
    href: '/admin/content/reviews/reports',
    icon: CircleAlert,
    tone: 'bg-[#fff6df] text-[#f59e0b]',
  },
];

const GUIDE_ITEMS = [
  {
    title: '1. 查看主办方目录',
    description: '统一管理主办方资料、城市、国家与视觉素材，支持搜索与跳转。',
    icon: FolderOpen,
    tone: 'bg-[#eef5ff] text-[#3b82f6]',
  },
  {
    title: '2. 新建主办方',
    description: '创建主办方并设置基础资料、简介与外部链接。',
    icon: Plus,
    tone: 'bg-[#effcf2] text-[#22c55e]',
  },
  {
    title: '3. 绑定活动关系',
    description: '把主办方分配给活动，建立归属关系并继续管理。',
    icon: Users,
    tone: 'bg-[#f4efff] text-[#8b5cf6]',
  },
];

function ActionCard({
  title,
  description,
  href,
  buttonLabel,
  icon: Icon,
  tone,
  iconTone,
}: (typeof PRIMARY_ACTIONS)[number]) {
  return (
    <section className={`admin-reference-pastel-card bg-gradient-to-br ${tone} p-6`}>
      <div className="flex items-start gap-5">
        <div className={`flex h-20 w-20 shrink-0 items-center justify-center rounded-full ${iconTone}`}>
          <Icon className="h-10 w-10" strokeWidth={2.4} />
        </div>
        <div className="min-w-0 flex-1">
          <h2 className="text-[20px] font-semibold tracking-[-0.03em] text-[#111827]">{title}</h2>
          <p className="mt-3 max-w-[24rem] text-[15px] leading-8 text-black/50">{description}</p>
          <Link
            href={href}
            className="mt-8 inline-flex items-center gap-3 rounded-full bg-[#071110] px-7 py-3 text-sm font-semibold text-white"
          >
            <span>{buttonLabel}</span>
            <ChevronRight className="h-4 w-4" />
          </Link>
        </div>
      </div>
    </section>
  );
}

export default function AdminContentOrganizersPage() {
  return (
    <AdminContentLayout
      title="主办方管理中心"
      description="专注于主办方核心管理。快速查看目录、创建主办方并处理活动绑定关系。"
      actions={null}
    >
      <section className="space-y-5">
        <section className="admin-reference-card p-5">
          <div className="grid gap-4 xl:grid-cols-3">
            {PRIMARY_ACTIONS.map((item) => (
              <ActionCard key={item.title} {...item} />
            ))}
          </div>
        </section>

        <div className="grid gap-5 xl:grid-cols-[1.38fr_0.62fr]">
          <section className="admin-reference-card p-6">
            <div className="flex items-center justify-between gap-3">
              <h2 className="text-[18px] font-semibold tracking-[-0.02em] text-[#111827]">核心入口</h2>
              <Link
                href="/admin/content/organizers/catalog"
                className="inline-flex items-center gap-2 rounded-full border border-[#e8eceb] bg-[#f8f9f8] px-4 py-2 text-sm font-semibold text-[#111827]"
              >
                <span>查看全部</span>
                <ChevronRight className="h-4 w-4" />
              </Link>
            </div>

            <div className="mt-5 space-y-3">
              {KEY_ENTRIES.map((item) => (
                <Link
                  key={item.title}
                  href={item.href}
                  className="admin-reference-soft-card flex items-center gap-4 px-5 py-4"
                >
                  <div className="flex w-[130px] items-center gap-3">
                    <span className={`h-3 w-3 rounded-full ${item.dotTone}`} />
                    <span className="text-[16px] font-medium text-[#374151]">{item.status}</span>
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[18px] font-semibold tracking-[-0.02em] text-[#111827]">
                      {item.title}
                    </div>
                    <div className="mt-1 text-[14px] text-black/45">{item.meta}</div>
                  </div>
                  <div className={`rounded-full px-5 py-2 text-sm font-semibold ${item.statusTone}`}>
                    {item.status}
                  </div>
                  <div className="w-[86px] text-right text-[15px] font-medium text-black/42">{item.date}</div>
                  <div className="flex w-8 justify-end text-black/46">
                    <Ellipsis className="h-5 w-5" />
                  </div>
                </Link>
              ))}
            </div>
          </section>

          <section className="admin-reference-card p-6">
            <h2 className="text-[18px] font-semibold tracking-[-0.02em] text-[#111827]">待处理事项</h2>

            <div className="mt-5 space-y-4">
              {PENDING_ITEMS.map((item) => {
                const Icon = item.icon;
                return (
                  <Link
                    key={item.title}
                    href={item.href}
                    className="admin-reference-soft-card flex items-center gap-4 px-4 py-4"
                  >
                    <div className={`flex h-12 w-12 items-center justify-center rounded-2xl ${item.tone}`}>
                      <Icon className="h-6 w-6" />
                    </div>
                    <div className="min-w-0 flex-1 text-[16px] font-semibold text-[#374151]">{item.title}</div>
                    <div className="text-[16px] font-semibold text-[#111827]">{item.count}</div>
                    <ChevronRight className="h-5 w-5 text-black/38" />
                  </Link>
                );
              })}

              <Link
                href="/admin/content/reviews"
                className="admin-reference-soft-card flex items-center justify-center gap-3 px-4 py-5 text-[16px] font-semibold text-[#111827]"
              >
                <span>进入审核中心</span>
                <ChevronRight className="h-5 w-5 text-black/38" />
              </Link>
            </div>
          </section>
        </div>

        <section className="admin-reference-card p-6">
          <h2 className="text-[18px] font-semibold tracking-[-0.02em] text-[#111827]">管理指引</h2>
          <div className="mt-6 grid gap-5 xl:grid-cols-3">
            {GUIDE_ITEMS.map((item, index) => {
              const Icon = item.icon;
              return (
                <div
                  key={item.title}
                  className={`flex gap-5 ${index < GUIDE_ITEMS.length - 1 ? 'xl:border-r xl:border-[#eef0ef] xl:pr-6' : ''}`}
                >
                  <div className={`flex h-16 w-16 shrink-0 items-center justify-center rounded-full ${item.tone}`}>
                    <Icon className="h-8 w-8" />
                  </div>
                  <div>
                    <div className="text-[18px] font-semibold tracking-[-0.02em] text-[#111827]">{item.title}</div>
                    <div className="mt-3 text-[15px] leading-8 text-black/48">{item.description}</div>
                  </div>
                </div>
              );
            })}
          </div>
        </section>
      </section>
    </AdminContentLayout>
  );
}
