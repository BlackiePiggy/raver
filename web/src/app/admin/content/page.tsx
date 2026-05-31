'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

const HUB_CARDS = [
  {
    eyebrow: 'Event Studio',
    title: '活动工作区',
    description: '活动目录、创建、编辑、排期与媒体主线集中在同一入口。',
    bullets: ['活动目录中心已接入', '创建与编辑基于当前 /v1 流程', '可直接进入缓存治理与关系维护'],
    href: '/admin/content/events',
    tone: 'bg-[#dff4a8]',
  },
  {
    eyebrow: 'Organizer Studio',
    title: '主办方工作区',
    description: '主办方目录、资料编辑与活动绑定统一进入原生管理链路。',
    bullets: ['目录中心可直接检索与编辑', '活动绑定支持一跳进入', '新建与编辑流程已经收口'],
    href: '/admin/content/organizers',
    tone: 'bg-[#f3e5a8]',
  },
  {
    eyebrow: 'DJ Studio',
    title: 'DJ 工作区',
    description: 'DJ 档案、媒体、proof 与链接资料统一在后台内处理。',
    bullets: ['目录中心支持快速定位', '新建与编辑在同一流程语义下完成', '与审核链路保持连续'],
    href: '/admin/content/djs',
    tone: 'bg-[#f7c4c0]',
  },
  {
    eyebrow: 'News Studio',
    title: '资讯工作区',
    description: '资讯正文、封面、发布时间与关联绑定统一收口到网页后台。',
    bullets: ['资讯创建与编辑已接入', '正文区域优先级更高', '支持 DJ / 主办方 / 活动绑定'],
    href: '/admin/content/news',
    tone: 'bg-[#dbeefe]',
  },
  {
    eyebrow: 'Label Studio',
    title: '厂牌工作区',
    description: '厂牌资料、视觉 URL 与官方链接可以直接在统一后台维护。',
    bullets: ['厂牌创建与编辑已接入', '目录支持分页检索', '资料区与视觉区已拆分'],
    href: '/admin/content/labels',
    tone: 'bg-[#e7f7d7]',
  },
  {
    eyebrow: 'Review Center',
    title: '审核中心',
    description: '内容贡献审核、DJ 绑定审核与举报审核在统一后台中分区处理。',
    bullets: ['内容审核直连当前接口体系', '审核队列入口清晰', '页面内继续原生演进'],
    href: '/admin/content/reviews',
    tone: 'bg-[#dbeefe]',
  },
];

function WorkspaceCard({
  href,
  title,
  eyebrow,
  description,
  bullets,
  tone,
}: {
  href: string;
  title: string;
  eyebrow: string;
  description: string;
  bullets: string[];
  tone: string;
}) {
  return (
    <Link href={href} className={`admin-reference-pastel-card block ${tone} p-5`}>
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">{eyebrow}</div>
          <h2 className="mt-2 text-[26px] font-semibold tracking-[-0.03em] text-[#1a1a1a]">{title}</h2>
        </div>
        <span className="admin-reference-chip">Open</span>
      </div>
      <p className="mt-4 text-[14px] leading-7 text-black/55">{description}</p>
      <div className="mt-5 space-y-2">
        {bullets.map((bullet) => (
          <div key={bullet} className="admin-reference-soft-card px-4 py-3 text-[14px] leading-6 text-[#1f2937]">
            {bullet}
          </div>
        ))}
      </div>
    </Link>
  );
}

export default function AdminContentWorkspacePage() {
  return (
    <AdminContentLayout
      title="内容控制台"
      description="在同一套后台内管理活动、主办方、DJ、审核与缓存治理。核心目录、创建和编辑链路集中收口，支持通过左侧多级导航快速进入不同板块。"
      actions={
        <>
          <Link href="/admin" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
            返回后台
          </Link>
          <Link href="/admin/content/reviews/submissions" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            进入审核队列
          </Link>
        </>
      }
    >
      <section className="space-y-5">
        <div className="grid gap-4 lg:grid-cols-4">
          {[
            { label: 'Active Modules', value: '14', note: '核心工作台' },
            { label: 'Catalog Surfaces', value: '05', note: '活动 / 主办方 / DJ / 资讯 / 厂牌' },
            { label: 'Review Queues', value: '03', note: '内容 / 绑定 / 举报' },
            { label: 'Admin Focus', value: 'Live', note: '统一后台主链路' },
          ].map((item, index) => (
            <div
              key={item.label}
              className={`admin-reference-pastel-card p-5 ${
                index === 0
                  ? 'bg-[#dff4a8]'
                  : index === 1
                    ? 'bg-[#f3e5a8]'
                    : index === 2
                      ? 'bg-[#f7c4c0]'
                      : 'bg-[#dbeefe]'
              }`}
            >
              <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">{item.label}</div>
              <div className="mt-4 text-[34px] font-semibold tracking-[-0.04em] text-[#1a1a1a]">{item.value}</div>
              <div className="mt-2 text-[13px] text-black/55">{item.note}</div>
            </div>
          ))}
        </div>

        <div className="grid gap-5 xl:grid-cols-[1.35fr_0.65fr]">
          <section className="admin-reference-card p-6">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">Primary Areas</div>
                <h2 className="mt-2 text-[30px] font-semibold tracking-[-0.03em] text-[#1a1a1a]">核心内容区</h2>
              </div>
              <span className="admin-reference-chip">Unified</span>
            </div>
            <div className="mt-5 grid gap-5 xl:grid-cols-2">
              {HUB_CARDS.map((card) => (
                <WorkspaceCard key={card.href} {...card} />
              ))}
            </div>
          </section>

          <div className="space-y-5">
            <section className="admin-reference-pastel-card bg-[linear-gradient(180deg,#ebfff5_0%,#f9fffc_100%)] p-6">
              <div className="text-[12px] uppercase tracking-[0.18em] text-[#8cae73]">Control Mode</div>
              <h2 className="mt-3 text-[34px] font-semibold tracking-[-0.04em] text-[#1a1a1a]">目录、编辑、审核</h2>
              <p className="mt-4 text-[15px] leading-8 text-[#8ea27f]">
                统一后台已经具备核心实体的目录中心、新建与编辑主入口，适合直接作为日常管理控制台使用。
              </p>
              <div className="mt-5 flex flex-wrap gap-3">
                <Link href="/admin/content/events/catalog" className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white">
                  打开活动目录
                </Link>
                <Link href="/admin/content/organizers/catalog" className="rounded-full border border-[#ececec] bg-white px-4 py-2 text-sm text-[#18211f]">
                  打开主办方目录
                </Link>
                <Link href="/admin/content/news" className="rounded-full border border-[#ececec] bg-white px-4 py-2 text-sm text-[#18211f]">
                  打开资讯工作区
                </Link>
              </div>
            </section>

            <section className="admin-reference-dark-card p-6">
              <div className="text-[12px] uppercase tracking-[0.18em] text-white/30">Quick Access</div>
              <div className="mt-4 space-y-3">
                {[
                  { href: '/admin/content/events/catalog', label: '活动目录中心' },
                  { href: '/admin/content/organizers/catalog', label: '主办方目录中心' },
                  { href: '/admin/content/djs/catalog', label: 'DJ 目录中心' },
                  { href: '/admin/content/news', label: '资讯工作区' },
                  { href: '/admin/content/labels', label: '厂牌工作区' },
                  { href: '/admin/content/events/cache-governance', label: '目录缓存治理' },
                ].map((item) => (
                  <Link key={item.href} href={item.href} className="block rounded-[20px] border border-white/10 px-4 py-4 text-[15px] text-white/88">
                    {item.label}
                  </Link>
                ))}
              </div>
            </section>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
