'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

function LegacyCard({
  href,
  title,
  description,
  eyebrow,
}: {
  href: string;
  title: string;
  description: string;
  eyebrow: string;
}) {
  return (
    <Link href={href} className="rounded-3xl border border-border-secondary bg-bg-secondary p-5 transition-colors hover:border-primary-blue">
      <div className="text-sm text-text-secondary">{eyebrow}</div>
      <h2 className="text-xl font-semibold">{title}</h2>
      <p className="mt-3 text-sm leading-6 text-text-secondary">{description}</p>
    </Link>
  );
}

export default function AdminContentLegacyToolsPage() {
  return (
    <AdminContentLayout
      title="迁移期旧工具"
      description="统一内容后台已经建立，但部分审核、Brand/DJ 历史工具、长尾编辑能力仍需通过 Festival Viewer 过渡访问。这里集中保留这些入口，避免后台再次分散。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回内容总览
          </Link>
          <Link href="/admin/festival-viewer.html" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
            打开 Festival Viewer
          </Link>
        </>
      }
    >
      <section className="grid gap-5 lg:grid-cols-2 xl:grid-cols-3">
        <LegacyCard
          href="/admin/content/legacy-tools/festival-viewer"
          eyebrow="Legacy Hub"
          title="完整 Festival Viewer"
          description="保留完整内容工具页，用于历史能力兜底和迁移期回查。"
        />
        <LegacyCard
          href="/admin/content/reviews/submissions"
          eyebrow="Review Bridge"
          title="结构化审核台"
          description="当前 content submissions 的结构化审核仍主要通过这里过渡到旧工具。"
        />
        <LegacyCard
          href="/admin/content/legacy-tools/brands"
          eyebrow="Brand Bridge"
          title="旧 Brand 工具"
          description="Brand 网格、编辑器与 Event ↔ Brand 绑定仍在这里，后续逐步回迁。"
        />
        <LegacyCard
          href="/admin/content/legacy-tools/djs"
          eyebrow="DJ Bridge"
          title="旧 DJ 工具"
          description="旧 DJ 管理工具保留作为迁移期兜底入口，直到新 DJ Studio 完成。"
        />
        <LegacyCard
          href="/admin/content/legacy-tools/archive"
          eyebrow="Archive Bridge"
          title="旧 Archive 工具"
          description="旧活动资料整理、导入和长尾工具仍然通过 Archive 页承接。"
        />
        <LegacyCard
          href="/admin/content/legacy-tools/archive-center"
          eyebrow="Archive Center"
          title="Archive 年份中心"
          description="先把最常用的按年份查看历史活动摘要迁回统一后台。"
        />
        <LegacyCard
          href="/admin/content/reviews/dj-bindings"
          eyebrow="Review Bridge"
          title="DJ Binding Review"
          description="DJ 自动绑定候选继续通过独立的审核台处理，不与 content review 混用。"
        />
      </section>
    </AdminContentLayout>
  );
}
