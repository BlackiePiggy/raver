'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

export default function AdminContentLegacyFestivalViewerPage() {
  return (
    <AdminContentLayout
      title="Festival Viewer"
      eyebrow="Admin / Content Workspace / Legacy Tools"
      description="完整 Festival Viewer 仍然承担一部分历史内容管理和迁移期兜底能力。这里把它作为统一后台中的一块受控能力，而不是分散在别处的孤立入口。"
      actions={
        <>
          <Link href="/admin/content/legacy-tools" className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm font-semibold text-[#071110]">
            返回旧工具总览
          </Link>
          <Link href="/admin/festival-viewer.html" className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white">
            打开完整 Festival Viewer
          </Link>
        </>
      }
    >
      <section className="admin-reference-card p-6">
        <div className="text-sm text-black/42">Legacy Role</div>
        <h2 className="mt-2 text-2xl font-semibold text-[#071110]">当前仍保留的原因</h2>
        <div className="mt-5 grid gap-3 md:grid-cols-3">
          {[
            '承接尚未原生化的长尾管理能力',
            '为审核和历史编辑器提供迁移期兜底',
            '避免在新后台未完工前中断运营工作流',
          ].map((item) => (
            <div key={item} className="admin-reference-soft-card px-4 py-3 text-sm text-[#24312d]">
              {item}
            </div>
          ))}
        </div>
      </section>
    </AdminContentLayout>
  );
}
