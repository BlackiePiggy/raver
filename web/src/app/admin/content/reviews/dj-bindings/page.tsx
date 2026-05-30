'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

export default function AdminContentReviewDjBindingsPage() {
  return (
    <AdminContentLayout
      title="DJ 绑定审核"
      eyebrow="Admin / Content Workspace / Reviews"
      description="这里集中说明 DJ 自动绑定候选与活动阵容审核的处理边界。它和普通内容提交流程不同，但现在已经纳入统一后台导航体系。"
      actions={
        <>
          <Link href="/admin/content/reviews" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回审核中心
          </Link>
          <Link href="/admin/dj-binding-reviews" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
            打开 DJ 绑定审核台
          </Link>
        </>
      }
    >
      <section className="grid gap-5 lg:grid-cols-2">
        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Workflow Boundary</div>
          <h2 className="mt-2 text-2xl font-semibold">这条审核链路负责什么</h2>
          <div className="mt-5 space-y-3">
            {[
              '审核 DJ 自动命中的候选实体是否正确',
              '决定 apply / dismiss，不直接等同于内容创建审核',
              '帮助活动阵容、canonical artist 与 DJ 资料建立正确关系',
            ].map((item) => (
              <div key={item} className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm">
                {item}
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Unification Goal</div>
          <h2 className="mt-2 text-2xl font-semibold">收口目标</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>虽然当前审核台还是独立页面，但已经被纳入统一内容后台的审核分区，不再作为后台首页上的孤立工具。</p>
            <p>后续会继续补摘要卡片、待处理计数与从 Event Studio 跳转进审核任务的能力。</p>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
