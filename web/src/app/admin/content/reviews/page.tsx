'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

const REVIEW_MODULES = [
  {
    href: '/admin/content/reviews/submissions',
    title: '内容贡献审核',
    description: '处理 Event / Organizer / DJ 等内容提交的结构化审核。',
    tone: 'bg-[#dff4a8]',
  },
  {
    href: '/admin/content/reviews/dj-bindings',
    title: 'DJ 绑定审核',
    description: '处理阵容候选 DJ 的 apply / dismiss 审核链路。',
    tone: 'bg-[#f3e5a8]',
  },
  {
    href: '/admin/content/reviews/reports',
    title: '举报审核',
    description: '处理内容举报、升级审核和模板化动作。',
    tone: 'bg-[#f7c4c0]',
  },
];

export default function AdminContentReviewsPage() {
  return (
    <AdminContentLayout
      title="审核中心"
      description="审核中心现在以统一后台原生页面为主，不再把具体功能完全桥接到 festival-viewer。内容贡献审核、DJ 绑定审核、举报审核都沿着当前接口体系直接在 Next Admin 内持续演进。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
            返回内容总览
          </Link>
          <Link href="/admin/content/reviews/submissions" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            进入内容贡献审核
          </Link>
        </>
      }
    >
      <section className="space-y-5">
        <section className="admin-reference-card p-6">
          <div className="flex items-center justify-between">
            <div>
              <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">Review Matrix</div>
              <h2 className="mt-2 text-[28px] font-semibold tracking-[-0.03em] text-[#1a1a1a]">审核工作台矩阵</h2>
            </div>
            <span className="admin-reference-chip">Review</span>
          </div>
          <div className="mt-5 grid gap-4 md:grid-cols-3">
            {REVIEW_MODULES.map((item) => (
              <Link key={item.href} href={item.href} className={`admin-reference-pastel-card ${item.tone} block p-5`}>
                <div className="text-[22px] font-semibold tracking-[-0.02em] text-[#1a1a1a]">{item.title}</div>
                <div className="mt-3 text-[14px] leading-7 text-black/55">{item.description}</div>
              </Link>
            ))}
          </div>
        </section>

        <div className="grid gap-5 xl:grid-cols-[1.15fr_0.85fr]">
          <section className="admin-reference-card p-6">
            <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">Migration Track</div>
            <h2 className="mt-2 text-[28px] font-semibold tracking-[-0.03em] text-[#1a1a1a]">当前演进方向</h2>
            <div className="mt-5 space-y-3">
              {[
                '审核主线优先直接对齐当前 Web / Server 接口，不再依赖旧 festival-viewer 页面',
                '内容贡献审核持续补业务 diff、自动审查提示和结构化 review notes',
                'DJ 绑定审核与举报审核已经回到统一后台原生页面中继续演进',
                '长尾实体与深层工具只在缺少当前接口时才保留迁移期兜底',
              ].map((item, index) => (
                <div key={item} className="admin-reference-soft-card px-4 py-4 text-[15px] leading-7 text-[#1f2937]">
                  {index + 1}. {item}
                </div>
              ))}
            </div>
          </section>

          <section className="admin-reference-soft-card p-6">
            <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">Current Split</div>
            <h2 className="mt-2 text-[28px] font-semibold tracking-[-0.03em] text-[#1a1a1a]">当前分工</h2>
            <div className="mt-5 space-y-4 text-[15px] leading-8 text-black/55">
              <p>内容贡献审核负责 Event / Organizer / DJ 等内容稿件的创建、编辑、版本比对和审批。</p>
              <p>DJ 自动命中的 Event 阵容候选通过统一后台内的 DJ 绑定审核工作台处理。</p>
              <p>举报审核与内容审核仍是不同工作流，但现在都在统一后台原生承接，不再依赖旧工具说明页跳转。</p>
            </div>
          </section>
        </div>
      </section>
    </AdminContentLayout>
  );
}
