'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

export default function AdminContentLegacyBrandsPage() {
  return (
    <AdminContentLayout
      title="旧 Brand 工具"
      eyebrow="Admin / Content Workspace / Legacy Tools"
      description="旧 Brand 工具仍承担历史 Brand 网格、活动绑定和部分深水区编辑能力。这里先把入口统一收口，等待 Organizer Studio 继续补齐。"
      actions={
        <>
          <Link href="/admin/content/legacy-tools" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回旧工具总览
          </Link>
          <Link href="/admin/festival-viewer.html#brand" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
            打开旧 Brand 工具
          </Link>
        </>
      }
    >
      <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-6 text-sm leading-6 text-text-secondary">
        Organizer Studio 已经完成 create / edit 第一版，但 Event ↔ Brand 关系维护和部分历史编辑能力仍在旧工具中。下一步会继续把这部分向统一后台迁移。
      </section>
    </AdminContentLayout>
  );
}
