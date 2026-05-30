'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

export default function AdminContentLegacyDjsPage() {
  return (
    <AdminContentLayout
      title="旧 DJ 工具"
      eyebrow="Admin / Content Workspace / Legacy Tools"
      description="在 DJ Studio 尚未完整原生化之前，旧 DJ 工具仍作为迁移期兜底入口保留。现在它已经被统一纳入后台的迁移与支持分区。"
      actions={
        <>
          <Link href="/admin/content/legacy-tools" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回旧工具总览
          </Link>
          <Link href="/admin/festival-viewer.html#dj" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
            打开旧 DJ 工具
          </Link>
        </>
      }
    >
      <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-6 text-sm leading-6 text-text-secondary">
        当前 DJ 的统一后台主入口已经建立，但真正的 shared draft / validation / mapper 和 create/edit 页面仍在推进中，所以旧工具还要继续承担兜底角色。
      </section>
    </AdminContentLayout>
  );
}
