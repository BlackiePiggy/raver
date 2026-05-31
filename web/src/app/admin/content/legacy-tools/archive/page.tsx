'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

export default function AdminContentLegacyArchivePage() {
  return (
    <AdminContentLayout
      title="旧 Archive 工具"
      eyebrow="Admin / Content Workspace / Legacy Tools"
      description="旧 Archive / Event Tooling 仍承担活动资料整理、导入和部分长尾工具能力。这里先把入口纳入统一后台，后续再决定哪些能力继续回迁。"
      actions={
        <>
          <Link href="/admin/content/legacy-tools" className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm font-semibold text-[#071110]">
            返回旧工具总览
          </Link>
          <Link href="/admin/content/legacy-tools/archive-center" className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm font-semibold text-[#071110]">
            Archive 年份中心
          </Link>
          <Link href="/admin/festival-viewer.html#archive" className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white">
            打开旧 Archive 工具
          </Link>
        </>
      }
    >
      <section className="grid gap-5 lg:grid-cols-2">
        <div className="admin-reference-soft-card p-6 text-sm leading-6 text-black/48">
          这部分能力偏历史和运营工具链，当前不会一次性把旧 Archive 全搬完，但已经开始把最常用的“按年份回看活动”能力迁进统一后台。
        </div>
        <div className="admin-reference-card p-6">
          <div className="text-sm text-black/42">Archive Center</div>
          <h2 className="mt-2 text-2xl font-semibold text-[#071110]">年份式浏览已回迁第一版</h2>
          <p className="mt-3 text-sm leading-6 text-black/48">
            统一后台现在已经有 Archive 年份中心，先支持按年份查看历史活动摘要，后续再继续补导入、图片缓存和更深的运营工具链。
          </p>
          <div className="mt-4">
            <Link href="/admin/content/legacy-tools/archive-center" className="text-sm font-semibold text-[#071110] hover:underline">
              打开 Archive 年份中心
            </Link>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
