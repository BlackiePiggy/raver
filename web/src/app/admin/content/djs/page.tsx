'use client';

import Link from 'next/link';
import {
  ChevronRight,
  CircleAlert,
  Ellipsis,
  FileText,
  FolderOpen,
  Headphones,
  Image as ImageIcon,
  Plus,
} from 'lucide-react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

const PRIMARY_ACTIONS = [
  {
    title: '查看 DJ 目录',
    description: '浏览和管理所有 DJ 条目、头像、国家、平台链接和基础统计。',
    href: '/admin/content/djs/catalog',
    buttonLabel: '进入 DJ 目录',
    icon: FolderOpen,
    tone: 'from-[#edf5ff] to-[#f8fbff]',
    iconTone: 'bg-[#3b82f6] text-white shadow-[0_10px_28px_rgba(59,130,246,0.28)]',
  },
  {
    title: '新建 DJ',
    description: '创建新的 DJ 档案，补充基础资料、proof、平台链接与统计信息。',
    href: '/admin/content/djs/new',
    buttonLabel: '新建 DJ',
    icon: Plus,
    tone: 'from-[#edfff3] to-[#fbfffc]',
    iconTone: 'bg-[#22c55e] text-white shadow-[0_10px_28px_rgba(34,197,94,0.28)]',
  },
  {
    title: '处理绑定审核',
    description: '集中处理 DJ 绑定审核、资料修订和与活动阵容相关的核心问题。',
    href: '/admin/content/reviews/dj-bindings',
    buttonLabel: '进入绑定审核',
    icon: Headphones,
    tone: 'from-[#f5f0ff] to-[#fcfbff]',
    iconTone: 'bg-[#8b5cf6] text-white shadow-[0_10px_28px_rgba(139,92,246,0.28)]',
  },
];

const KEY_ENTRIES = [
  {
    status: 'Ready',
    statusTone: 'bg-[#ebf9ef] text-[#28a258]',
    dotTone: 'bg-[#22c55e]',
    title: 'DJ 目录中心',
    meta: '快速检索 · 排序筛选 · 编辑跳转',
    date: 'Catalog',
    href: '/admin/content/djs/catalog',
  },
  {
    status: 'Import',
    statusTone: 'bg-[#f9f2dc] text-[#a8841b]',
    dotTone: 'bg-[#fbbf24]',
    title: 'DJ 创建流程',
    meta: '基础资料 · proof 提交 · 平台链接',
    date: 'Create',
    href: '/admin/content/djs/new',
  },
  {
    status: 'OSS',
    statusTone: 'bg-[#edf4ff] text-[#3b82f6]',
    dotTone: 'bg-[#60a5fa]',
    title: '媒体与头像处理',
    meta: '头像上传 · banner 资料 · 素材替换',
    date: 'Media',
    href: '/admin/content/djs/new',
  },
  {
    status: 'Review',
    statusTone: 'bg-[#faebec] text-[#b05664]',
    dotTone: 'bg-[#fb7185]',
    title: 'DJ 绑定审核',
    meta: '阵容匹配 · 绑定修正 · 审核处理',
    date: 'Review',
    href: '/admin/content/reviews/dj-bindings',
  },
];

const PENDING_ITEMS = [
  {
    title: '待审核 DJ 绑定',
    count: '6',
    href: '/admin/content/reviews/dj-bindings',
    icon: Headphones,
    tone: 'bg-[#f3ecff] text-[#8b5cf6]',
  },
  {
    title: '待审核的 DJ 变更',
    count: '3',
    href: '/admin/content/reviews/submissions',
    icon: FileText,
    tone: 'bg-[#eaf8ee] text-[#22c55e]',
  },
  {
    title: '图片与素材待补',
    count: '4',
    href: '/admin/content/djs/catalog',
    icon: ImageIcon,
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
    title: '1. 查看 DJ 目录',
    description: '统一管理 DJ 基础资料、国家、头像和平台链接，支持快速检索。',
    icon: FolderOpen,
    tone: 'bg-[#eef5ff] text-[#3b82f6]',
  },
  {
    title: '2. 新建 DJ',
    description: '创建 DJ 并补全基础资料、proof 和平台外链。',
    icon: Plus,
    tone: 'bg-[#effcf2] text-[#22c55e]',
  },
  {
    title: '3. 处理绑定审核',
    description: '进入绑定审核流，处理阵容匹配与资料修订问题。',
    icon: Headphones,
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

export default function AdminContentDjsPage() {
  return (
    <AdminContentLayout
      title="DJ 管理中心"
      description="专注于 DJ 核心管理。快速查看目录、创建新 DJ 并处理绑定审核与资料修订。"
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
                href="/admin/content/djs/catalog"
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
