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
    <Link href={href} className="admin-reference-card block p-5">
      <div className="text-[11px] uppercase tracking-[0.18em] text-black/35">{eyebrow}</div>
      <h2 className="mt-2 text-xl font-semibold text-[#071110]">{title}</h2>
      <p className="mt-3 text-sm leading-6 text-black/52">{description}</p>
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
          <Link href="/admin/content" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            返回内容总览
          </Link>
          <Link href="/admin/festival-viewer.html" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            打开 Festival Viewer
          </Link>
        </>
      }
    >
      <section className="admin-reference-card mb-5 p-6">
        <div className="grid gap-3 md:grid-cols-3">
          {[
            { title: '迁移兜底', body: '先把还没完全回迁的新旧工具集中在一个入口，避免再次分散。', tone: 'bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)]' },
            { title: '审核桥接', body: '保留审核与历史工具的过渡入口，但视觉上仍保持统一后台语言。', tone: 'bg-[linear-gradient(180deg,#f7efda_0%,#ffffff_100%)]' },
            { title: '逐步收口', body: '等新工作台稳定后，再逐页把这里的能力完全替换掉。', tone: 'bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)]' },
          ].map((item) => (
            <div key={item.title} className={`admin-reference-pastel-card p-4 ${item.tone}`}>
              <div className="text-xs font-bold uppercase tracking-[0.18em] text-black/35">{item.title}</div>
              <div className="mt-4 text-sm leading-6 text-[#24312d]">{item.body}</div>
            </div>
          ))}
        </div>
      </section>
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
