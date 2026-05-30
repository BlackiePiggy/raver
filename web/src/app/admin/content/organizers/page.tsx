'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

export default function AdminContentOrganizersPage() {
  return (
    <AdminContentLayout
      title="主办方工作区"
      description="这里统一承接 Brand / WikiFestival 的创建、编辑、proof、官方链接和活动绑定能力，并与 iOS OrganizerUploadFlow 对齐。当前第一版 create/edit 已经落地，后续继续补 event binding 和 revision diff。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回内容总览
          </Link>
          <Link href="/admin/content/organizers/bindings" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            活动绑定中心
          </Link>
          <Link href="/admin/content/organizers/new" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
            新建主办方
          </Link>
        </>
      }
    >
      <section className="grid gap-5 lg:grid-cols-2">
        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Alignment Scope</div>
          <h2 className="mt-2 text-2xl font-semibold">要对齐的主线能力</h2>
          <div className="mt-5 space-y-3">
            {[
              '基础资料：name / aliases / abbreviation / region',
              '介绍与多语言：introduction / descriptionI18n',
              '证明与媒体：avatar / background / proof / imageAssets',
              '官方链接与 create/edit submission',
              '编辑基线：baseBrandRevision 与 patch submission',
            ].map((item) => (
              <div key={item} className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm">
                {item}
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Migration Note</div>
          <h2 className="mt-2 text-2xl font-semibold">迁移策略</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>当前新后台已经接上 Organizer Studio 的 create/edit 第一版，但 Event ↔ Brand 的关系维护仍有一部分在 Festival Viewer。</p>
            <p>下一批会优先补 Event 中的 inline organizer create/bind，以及主办方编辑的 revision diff 和活动绑定细节。</p>
            <div className="pt-2">
              <Link href="/admin/festival-viewer.html#brand" className="text-primary-blue hover:underline">
                打开迁移期旧 Brand 工具
              </Link>
            </div>
          </div>
        </div>

        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Binding Center</div>
          <h2 className="mt-2 text-2xl font-semibold">活动绑定中心已回迁第一版</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>统一后台现在已经有原生的活动 ↔ 主办方绑定中心，先承接最常用的单活动绑定、清空关系和关系定位操作。</p>
            <p>后续会继续补批量绑定、聚类视图和 revision diff，逐步减少对旧 Brand 工具的依赖。</p>
            <Link href="/admin/content/organizers/bindings" className="inline-block text-sm font-semibold text-primary-blue hover:underline">
              打开活动绑定中心
            </Link>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
