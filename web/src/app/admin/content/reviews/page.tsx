'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

export default function AdminContentReviewsPage() {
  return (
    <AdminContentLayout
      title="审核中心"
      description="迁移期先把审核中心收口到统一内容后台内，再逐步把 Festival Viewer 里的结构化审核台原生化进 Next Admin。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回内容总览
          </Link>
          <Link href="/admin/festival-viewer.html#review" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
            打开结构化审核台
          </Link>
        </>
      }
    >
      <section className="grid gap-5 xl:grid-cols-[1.15fr_1fr]">
        <div className="space-y-5">
          <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
            <div className="text-sm text-text-secondary">Review Matrix</div>
            <h2 className="mt-2 text-2xl font-semibold">审核工作台矩阵</h2>
            <div className="mt-5 grid gap-3 md:grid-cols-3">
              {[
                {
                  href: '/admin/content/reviews/submissions',
                  title: '内容贡献审核',
                  description: '处理 Event / Organizer / DJ 等内容提交的结构化审核。',
                },
                {
                  href: '/admin/content/reviews/dj-bindings',
                  title: 'DJ 绑定审核',
                  description: '处理阵容候选 DJ 的 apply / dismiss 审核链路。',
                },
                {
                  href: '/admin/content/reviews/reports',
                  title: '举报审核',
                  description: '处理内容举报、升级审核和模板化动作。',
                },
              ].map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-4 transition-colors hover:border-primary-blue"
                >
                  <div className="text-base font-semibold">{item.title}</div>
                  <div className="mt-2 text-sm leading-6 text-text-secondary">{item.description}</div>
                </Link>
              ))}
            </div>
          </div>

          <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
            <div className="text-sm text-text-secondary">Migration Track</div>
            <h2 className="mt-2 text-2xl font-semibold">审核中心迁移步骤</h2>
            <div className="mt-5 space-y-3">
              {[
                '短期继续桥接 Festival Viewer 结构化审核台',
                '中期原生化 Event / Organizer / DJ submission detail',
                '补版本 diff、inline review notes、approve / reject',
                '长尾实体继续通过 legacy tools 过渡',
              ].map((item, index) => (
                <div key={item} className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm">
                  {index + 1}. {item}
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Current Split</div>
          <h2 className="mt-2 text-2xl font-semibold">当前分工</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>内容贡献审核先通过结构化审核台处理。</p>
            <p>DJ 自动命中的 Event 阵容候选继续通过独立的 DJ Binding Review 页面处理。</p>
            <p>举报审核与内容审核仍然是两条不同工作流，但现在已经纳入同一个后台分区下统一导航。</p>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
