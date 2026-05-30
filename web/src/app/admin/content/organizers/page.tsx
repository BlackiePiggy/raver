'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

export default function AdminContentOrganizersPage() {
  return (
    <AdminContentLayout
      title="主办方工作区"
      description="这里统一承接 Brand / WikiFestival 的目录、新建、编辑、proof、官方链接和活动绑定能力，并与 iOS OrganizerUploadFlow 对齐。当前主办方目录中心、create、edit 和绑定中心都已经落地，可作为统一后台里的原生主链路使用。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回内容总览
          </Link>
          <Link href="/admin/content/organizers/catalog" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            主办方目录中心
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
              '目录检索、官方链接与 create/edit submission',
              '编辑基线：baseBrandRevision 与 patch submission',
            ].map((item) => (
              <div key={item} className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm">
                {item}
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Native Closure</div>
          <h2 className="mt-2 text-2xl font-semibold">当前已可原生闭环</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>统一后台现在已经提供主办方目录中心、主办方新建、主办方编辑和活动绑定中心，日常资料治理可以直接在这一套链路里完成。</p>
            <p>下一步继续补 Event 中的 inline organizer create/bind、revision diff，以及更细的关系治理体验，但不再把目录和主编辑流放回旧工具。</p>
            <Link href="/admin/content/organizers/catalog" className="inline-block text-sm font-semibold text-primary-blue hover:underline">
              打开主办方目录中心
            </Link>
          </div>
        </div>

        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Binding Center</div>
          <h2 className="mt-2 text-2xl font-semibold">活动绑定中心已回迁第一版</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>统一后台现在已经有原生的活动 ↔ 主办方绑定中心，先承接最常用的单活动绑定、清空关系和关系定位操作。</p>
            <p>这里已经补到批量绑定、聚类视图和关系定位，后续继续增强 revision diff 与更多批量治理能力。</p>
            <Link href="/admin/content/organizers/bindings" className="inline-block text-sm font-semibold text-primary-blue hover:underline">
              打开活动绑定中心
            </Link>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
