'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

export default function AdminContentReviewReportsPage() {
  return (
    <AdminContentLayout
      title="举报审核"
      eyebrow="Admin / Content Workspace / Reviews"
      description="举报审核和内容贡献审核是两条不同工作流。这里先把说明、入口和职责边界收口到统一后台，避免审核模块再次分散。"
      actions={
        <>
          <Link href="/admin/content/reviews" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回审核中心
          </Link>
          <Link href="/admin/content-reports" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
            打开举报审核台
          </Link>
        </>
      }
    >
      <section className="grid gap-5 xl:grid-cols-[1.25fr_1fr]">
        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Moderation Actions</div>
          <h2 className="mt-2 text-2xl font-semibold">当前支持的处理动作</h2>
          <div className="mt-5 grid gap-3 md:grid-cols-2">
            {[
              '标记已处理 / 驳回举报',
              '下架内容 / 恢复内容',
              '警告用户 / 限制用户 / 临时封禁 / 永久封禁',
              '升级审核与模板化通知',
            ].map((item) => (
              <div key={item} className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm">
                {item}
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Positioning</div>
          <h2 className="mt-2 text-2xl font-semibold">在统一后台中的位置</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>举报审核已经是 Next Admin 原生页面，但之前导航关系较弱。现在它作为审核分区的一部分被纳入统一后台信息架构。</p>
            <p>后续可以继续补待处理数量、优先级摘要和跨模块联动提示。</p>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
