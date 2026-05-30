'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

export default function AdminContentReviewsPage() {
  return (
    <AdminContentLayout
      title="审核中心"
      description="审核中心现在以统一后台原生页面为主，不再把具体功能完全桥接到 festival-viewer。内容贡献审核、DJ 绑定审核、举报审核都沿着当前接口体系直接在 Next Admin 内持续演进。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回内容总览
          </Link>
          <Link href="/admin/content/reviews/submissions" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
            进入内容贡献审核
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
            <h2 className="mt-2 text-2xl font-semibold">当前演进方向</h2>
            <div className="mt-5 space-y-3">
              {[
                '审核主线优先直接对齐当前 Web / Server 接口，不再依赖旧 festival-viewer 页面',
                '内容贡献审核持续补业务 diff、自动审查提示和结构化 review notes',
                'DJ 绑定审核与举报审核已经回到统一后台原生页面中继续演进',
                '长尾实体与深层工具只在缺少当前接口时才保留迁移期兜底',
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
            <p>内容贡献审核负责 Event / Organizer / DJ 等内容稿件的创建、编辑、版本比对和审批。</p>
            <p>DJ 自动命中的 Event 阵容候选通过统一后台内的 DJ 绑定审核工作台处理。</p>
            <p>举报审核与内容审核仍是不同工作流，但现在都在统一后台原生承接，不再依赖旧工具说明页跳转。</p>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
