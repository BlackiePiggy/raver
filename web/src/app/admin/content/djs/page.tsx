'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

export default function AdminContentDjsPage() {
  return (
    <AdminContentLayout
      title="DJ 工作区"
      description="这里将统一承接 DJ 的手动创建、编辑、proof、平台链接和媒体资产管理，并逐步替换旧列表页或工具页中的分散入口。当前 DJ Studio 的 create / edit 第一版已经接入统一后台。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回内容总览
          </Link>
          <Link href="/admin/content/djs/catalog" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            DJ 目录中心
          </Link>
          <Link href="/admin/content/djs/new" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
            新建 DJ
          </Link>
          <Link href="/admin/festival-viewer.html#dj" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            打开旧 DJ 工具
          </Link>
        </>
      }
    >
      <section className="grid gap-5 lg:grid-cols-2">
        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Flow Standard</div>
          <h2 className="mt-2 text-2xl font-semibold">DJ UploadFlow 对齐点</h2>
          <div className="mt-5 space-y-3">
            {[
              '仅手动创建，普通用户创建进入审核',
              'avatar 必填，平台链接或 proof 图至少满足一项',
              '媒体先上传 OSS，再提交 create/edit payload',
              '创建走 /v1/djs/manual/import，编辑走 PATCH /v1/djs/:id',
            ].map((item) => (
              <div key={item} className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm">
                {item}
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Current Plan</div>
          <h2 className="mt-2 text-2xl font-semibold">当前计划</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>DJ Studio 的 create / edit 第一版已经接入统一后台，当前可提交头像、banner、proof、平台链接和基础平台统计。</p>
            <p>下一步继续补 proof 生命周期、平台源对齐提示和从 Event Studio 跳转新建 / 编辑 DJ 的联动入口。</p>
          </div>
        </div>

        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Catalog Center</div>
          <h2 className="mt-2 text-2xl font-semibold">全量 DJ 目录已收口</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>统一后台现在已经提供 DJ 目录中心，默认通过分页摘要、本地 TTL 快照和手动刷新来查看全量 DJ。</p>
            <p>这样可以先把全量管理入口收回到统一后台，再逐步迁移旧工具中的 proof、平台源和历史编辑能力。</p>
            <Link href="/admin/content/djs/catalog" className="inline-block text-sm font-semibold text-primary-blue hover:underline">
              打开 DJ 目录中心
            </Link>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
