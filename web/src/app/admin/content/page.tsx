'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

function WorkspaceCard({
  href,
  title,
  eyebrow,
  description,
  bullets,
}: {
  href: string;
  title: string;
  eyebrow: string;
  description: string;
  bullets: string[];
}) {
  return (
    <Link href={href} className="rounded-[18px] border border-white/6 bg-[#1a1a1a] p-5 transition-colors hover:border-white/12 hover:bg-[#202020]">
      <div className="text-[11px] uppercase tracking-[0.18em] text-[#5e5e5e]">{eyebrow}</div>
      <h2 className="mt-2 text-[22px] font-semibold tracking-[-0.02em] text-[#f1f1f1]">{title}</h2>
      <p className="mt-3 text-sm leading-6 text-[#8c8c8c]">{description}</p>
      <div className="mt-4 space-y-2">
        {bullets.map((bullet) => (
          <div key={bullet} className="rounded-xl border border-white/6 bg-[#151515] px-3 py-2 text-sm text-[#cfcfcf]">
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
          <Link href="/admin" className="rounded-xl border border-white/6 px-4 py-2 text-sm text-[#d0d0d0] hover:border-white/12 hover:text-white">
            返回后台
          </Link>
          <Link href="/admin/content/reviews/submissions" className="rounded-xl bg-[#d9ff72] px-4 py-2 text-sm font-semibold text-black">
            进入审核队列
          </Link>
        </>
      }
    >
      <section className="grid gap-4 lg:grid-cols-4">
        {[
          { label: 'Active Modules', value: '12', note: '核心工作台' },
          { label: 'Catalog Surfaces', value: '03', note: '活动 / 主办方 / DJ' },
          { label: 'Review Queues', value: '03', note: '内容 / 绑定 / 举报' },
          { label: 'Admin Focus', value: 'Live', note: '统一后台主链路' },
        ].map((item) => (
          <div key={item.label} className="rounded-[18px] border border-white/6 bg-[#1a1a1a] p-5">
            <div className="text-[11px] uppercase tracking-[0.18em] text-[#5d5d5d]">{item.label}</div>
            <div className="mt-3 font-mono text-[30px] font-semibold tracking-[-0.04em] text-[#f5f5f5]">
              {item.value}
            </div>
            <div className="mt-2 text-[12px] text-[#7a7a7a]">{item.note}</div>
          </div>
        ))}
      </section>

      <section className="grid gap-5 lg:grid-cols-[1.35fr_0.65fr]">
        <div className="rounded-[20px] border border-white/6 bg-[#1a1a1a] p-6">
          <div className="flex items-start justify-between gap-4">
            <div>
              <div className="text-[11px] uppercase tracking-[0.18em] text-[#5e5e5e]">Primary Areas</div>
              <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#f1f1f1]">核心内容区</h2>
            </div>
            <div className="rounded-full border border-[#29351a] bg-[#151c0d] px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.16em] text-[#d9ff72]">
              unified
            </div>
          </div>

          <div className="mt-5 grid gap-5 lg:grid-cols-2">
            <WorkspaceCard
              href="/admin/content/events"
              eyebrow="Event Studio"
              title="活动工作区"
              description="活动目录、创建、编辑、排期与媒体主线集中在同一入口。"
              bullets={[
                '活动目录中心已接入',
                '创建与编辑基于当前 /v1 流程',
                '可直接进入缓存治理与关系维护',
              ]}
            />
            <WorkspaceCard
              href="/admin/content/organizers"
              eyebrow="Organizer Studio"
              title="主办方工作区"
              description="主办方目录、资料编辑与活动绑定统一进入一套原生管理链路。"
              bullets={[
                '目录中心可直接检索与编辑',
                '活动绑定支持一跳进入',
                '新建与编辑流程已经收口',
              ]}
            />
            <WorkspaceCard
              href="/admin/content/djs"
              eyebrow="DJ Studio"
              title="DJ 工作区"
              description="DJ 档案、媒体、proof 与链接资料统一在后台内处理。"
              bullets={[
                '目录中心支持快速定位',
                '新建与编辑在同一流程语义下完成',
                '与审核链路保持连续',
              ]}
            />
            <WorkspaceCard
              href="/admin/content/reviews"
              eyebrow="Review Center"
              title="审核中心"
              description="内容贡献审核、DJ 绑定审核与举报审核在统一后台中分区处理。"
              bullets={[
                '内容审核直连当前接口体系',
                '审核队列入口清晰',
                '页面内继续原生演进',
              ]}
            />
          </div>
        </div>

        <div className="space-y-5">
          <div className="rounded-[20px] border border-[#2c3a18] bg-[linear-gradient(135deg,#15200d_0%,#121212_55%,#101010_100%)] p-6">
            <div className="inline-flex rounded-full bg-[#d9ff72] px-3 py-1 text-[10px] font-bold uppercase tracking-[0.16em] text-black">
              control mode
            </div>
            <h2 className="mt-4 text-[28px] font-semibold tracking-[-0.04em] text-[#d9ff72]">
              目录、编辑、审核
            </h2>
            <p className="mt-3 text-sm leading-6 text-[#9cab8e]">
              统一后台已经具备核心实体的目录中心、新建与编辑主入口，适合直接作为日常管理控制台使用。
            </p>
            <div className="mt-5 flex gap-3">
              <Link href="/admin/content/events/catalog" className="rounded-xl bg-[#d9ff72] px-4 py-2 text-sm font-semibold text-black">
                打开活动目录
              </Link>
              <Link href="/admin/content/organizers/catalog" className="rounded-xl border border-[#31431a] px-4 py-2 text-sm text-[#d9ff72]">
                打开主办方目录
              </Link>
            </div>
          </div>

          <div className="rounded-[20px] border border-white/6 bg-[#1a1a1a] p-6">
            <div className="text-[11px] uppercase tracking-[0.18em] text-[#5d5d5d]">Quick Access</div>
            <div className="mt-4 space-y-3">
              {[
                { href: '/admin/content/events/catalog', label: '活动目录中心' },
                { href: '/admin/content/organizers/catalog', label: '主办方目录中心' },
                { href: '/admin/content/djs/catalog', label: 'DJ 目录中心' },
                { href: '/admin/content/events/cache-governance', label: '目录缓存治理' },
              ].map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  className="flex items-center justify-between rounded-xl border border-white/6 bg-[#151515] px-4 py-3 text-sm text-[#d4d4d4] transition-colors hover:bg-[#202020]"
                >
                  <span>{item.label}</span>
                  <span className="text-[#666]">›</span>
                </Link>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className="grid gap-5 lg:grid-cols-2">
        <WorkspaceCard
          href="/admin/content/events/catalog"
          eyebrow="Catalog Center"
          title="活动目录中心"
          description="以分页摘要和低频刷新方式浏览活动全量目录，进入后可继续跳转到活动编辑。"
          bullets={[
            '目录层优先轻量定位',
            '编辑层再拉取完整数据',
            '适合高频管理与巡检',
          ]}
        />
        <WorkspaceCard
          href="/admin/content/organizers/catalog"
          eyebrow="Catalog Center"
          title="主办方目录中心"
          description="统一查看主办方资料、地区、链接与视觉摘要，并直接进入编辑与绑定。"
          bullets={[
            '搜索、分页与详情跳转已具备',
            '支持一跳进入绑定中心',
            '可作为主办方日常管理主页',
          ]}
        />
        <WorkspaceCard
          href="/admin/content/djs/catalog"
          eyebrow="Catalog Center"
          title="DJ 目录中心"
          description="将 DJ 全量浏览、筛选和编辑定位收回统一后台，适合集中治理资料与入口。"
          bullets={[
            '优先命中摘要层',
            '适合快速进入编辑',
            '统一 DJ 管理入口',
          ]}
        />
      </section>

      <section className="grid gap-5 lg:grid-cols-[1.2fr_0.8fr]">
        <div className="rounded-[20px] border border-white/6 bg-[#1a1a1a] p-6">
          <div className="text-[11px] uppercase tracking-[0.18em] text-[#5d5d5d]">Operations Flow</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#f1f1f1]">重点工作流</h2>
          <div className="mt-5 grid gap-3">
            {[
              '活动资料创建与编辑',
              '主办方资料维护与活动绑定',
              'DJ 资料录入与档案编辑',
              '内容贡献审核与举报处理',
              '目录缓存治理与目录巡检',
            ].map((item, index) => (
              <div key={item} className="flex items-center gap-3 rounded-xl border border-white/6 bg-[#151515] px-4 py-3">
                <div className="flex h-8 w-8 items-center justify-center rounded-full bg-[#d9ff72] text-xs font-bold text-black">
                  {index + 1}
                </div>
                <div className="text-sm text-[#d1d1d1]">{item}</div>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-[20px] border border-white/6 bg-[#1a1a1a] p-6">
          <div className="text-[11px] uppercase tracking-[0.18em] text-[#5d5d5d]">Additional Tools</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#f1f1f1]">补充入口</h2>
          <p className="mt-3 text-sm leading-6 text-[#8a8a8a]">
            审核、目录治理与历史工具保留在统一后台侧栏中统一访问，避免页面入口再次分散。
          </p>
          <div className="mt-5 grid gap-3">
            <Link href="/admin/content/reviews" className="rounded-xl border border-white/6 bg-[#151515] px-4 py-3 text-sm text-[#d4d4d4] hover:bg-[#202020]">
              审核中心
            </Link>
            <Link href="/admin/content/legacy-tools" className="rounded-xl border border-white/6 bg-[#151515] px-4 py-3 text-sm text-[#d4d4d4] hover:bg-[#202020]">
              补充工具
            </Link>
            <Link href="/admin/content/organizers/bindings" className="rounded-xl border border-white/6 bg-[#151515] px-4 py-3 text-sm text-[#d4d4d4] hover:bg-[#202020]">
              活动绑定中心
            </Link>
          </div>
        </div>
      </section>

      <section className="grid gap-5 lg:grid-cols-2">
        <WorkspaceCard
          href="/admin/content/events/cache-governance"
          eyebrow="Cache Governance"
          title="目录缓存治理"
          description="查看活动、DJ 与 Archive 摘要缓存状态，并在高峰前手动预热重点目录。"
          bullets={[
            '支持缓存状态观察',
            '提供手动刷新入口',
            '降低目录打开时的重查询压力',
          ]}
        />
        <WorkspaceCard
          href="/admin/content/legacy-tools"
          eyebrow="Support"
          title="补充工具"
          description="将历史工具与长尾能力统一收纳到同一后台内，作为补充入口集中管理。"
          bullets={[
            '集中保留补充工具入口',
            '避免后台再次分散',
            '适合作为长尾能力承接区',
          ]}
        />
      </section>
    </AdminContentLayout>
  );
}
