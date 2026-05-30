'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

function WorkspaceCard({
  href,
  title,
  eyebrow,
  description,
  bullets,
}: {
  href: string;
  title: string;
  eyebrow: string;
  description: string;
  bullets: string[];
}) {
  return (
    <Link href={href} className="rounded-3xl border border-border-secondary bg-bg-secondary p-5 transition-colors hover:border-primary-blue">
      <div className="text-sm text-text-secondary">{eyebrow}</div>
      <h2 className="mt-2 text-2xl font-semibold">{title}</h2>
      <p className="mt-3 text-sm leading-6 text-text-secondary">{description}</p>
      <div className="mt-4 space-y-2">
        {bullets.map((bullet) => (
          <div key={bullet} className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-3 py-2 text-sm">
            {bullet}
          </div>
        ))}
      </div>
    </Link>
  );
}

export default function AdminContentWorkspacePage() {
  return (
    <AdminContentLayout
      title="统一内容后台"
      description="第一版内容工作区已经从旧的桥接页独立出来。当前后台开始采用多级展开侧栏来管理活动、主办方、DJ、审核与迁移入口，让不同板块在同一工作台里更清晰地分区协作。"
      actions={
        <>
          <Link href="/admin" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            返回后台首页
          </Link>
          <Link href="/admin/content/legacy-tools" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
            打开旧工具桥接
          </Link>
        </>
      }
    >
      <section className="grid gap-5 lg:grid-cols-2">
        <WorkspaceCard
          href="/admin/content/events"
          eyebrow="Event Studio"
          title="活动工作区"
          description="活动创建、编辑、排期、时区和媒体主线已经开始从这里统一承接，后续继续补 schedule、eventDays 和 timetable 深水区。"
          bullets={[
            'create/edit 已对齐统一 /v1 提交链路',
            '继续补 iOS EventUploadFlow 的 schedule、weeks、eventDays',
            '旧发布与旧编辑入口已收口到统一后台',
          ]}
        />
        <WorkspaceCard
          href="/admin/content/organizers"
          eyebrow="Organizer Studio"
          title="主办方工作区"
          description="统一承接 Brand / WikiFestival 的资料维护、证明材料上传、官方链接和活动绑定，第一版 create/edit 已经就位。"
          bullets={[
            '对齐 iOS OrganizerUploadFlow create/edit 语义',
            '主视觉、proof、identity/rights 校验保持一致',
            '后续接 Event 中 inline organizer create/bind',
          ]}
        />
        <WorkspaceCard
          href="/admin/content/organizers/bindings"
          eyebrow="Organizer Binding"
          title="活动绑定中心"
          description="把 Event ↔ Brand 的高频关系维护迁回统一后台，用双栏绑定面板取代分散旧工具中的主要操作。"
          bullets={[
            '左侧活动摘要目录，右侧正式主办方绑定面板',
            '绑定时复用标准 Event Studio 更新链路',
            '后续继续补批量绑定和未匹配聚类视图',
          ]}
        />
        <WorkspaceCard
          href="/admin/content/djs"
          eyebrow="DJ Studio"
          title="DJ 工作区"
          description="统一承接 DJ 手动创建、编辑、平台链接、proof 与媒体资产，后续与审核链路一体化。"
          bullets={[
            '对齐 iOS DJUploadFlow',
            'avatar 必填，平台链接或 proof 二选一',
            '后续接 /v1/djs/manual/import 与 PATCH /v1/djs/:id',
          ]}
        />
        <WorkspaceCard
          href="/admin/content/reviews"
          eyebrow="Review Center"
          title="审核中心"
          description="迁移期间先桥接现有结构化审核台，后续逐步把 Event / Organizer / DJ 审核详情原生化到 Next Admin。"
          bullets={[
            '当前保留 Festival Viewer 结构化审核入口',
            '后续原生化 content_submissions 详情与版本 diff',
            '与 DJ 阵容绑定审核、举报审核形成清晰分工',
          ]}
        />
      </section>

      <section className="grid gap-5 lg:grid-cols-2">
        <WorkspaceCard
          href="/admin/content/events/catalog"
          eyebrow="Catalog Center"
          title="活动目录中心"
          description="以分页摘要、本地 TTL 快照和手动刷新来管理活动全量目录，减少后台每次打开时的数据库压力。"
          bullets={[
            '单页摘要 + stale-while-revalidate 式本地快照',
            '目录层轻量，编辑层再拉完整活动数据',
            '逐步承接旧 Archive / Event 列表型工作',
          ]}
        />
        <WorkspaceCard
          href="/admin/content/events/cache-governance"
          eyebrow="Cache Governance"
          title="目录缓存治理"
          description="把活动、DJ、Archive 的摘要缓存做成可观察、可手动预热的治理台，避免每次都直打全量数据源。"
          bullets={[
            '统一查看内存热缓存、磁盘快照与摘要刷新状态',
            '为活动高峰前手动预热重点目录提供入口',
            '为后续 Redis / DB snapshot 升级预留治理承接层',
          ]}
        />
        <WorkspaceCard
          href="/admin/content/djs/catalog"
          eyebrow="Catalog Center"
          title="DJ 目录中心"
          description="把 DJ 全量浏览、筛选和定位收回统一后台，先解决管理入口分散和高频重查问题。"
          bullets={[
            '优先命中本地快照，陈旧后自动补刷新',
            '适合迁移旧 DJ/Facebook 辅助管理能力',
            '后续继续承接 proof、平台源和历史编辑面板',
          ]}
        />
      </section>

      <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <div className="text-sm text-text-secondary">Migration Focus</div>
            <h2 className="mt-2 text-2xl font-semibold">当前迁移重点</h2>
            <p className="mt-3 max-w-3xl text-sm leading-6 text-text-secondary">
              这轮改造不再继续扩展旧 `festival-viewer` 主线编辑器，也不继续加厚旧 Web publish/edit 页面，而是把主工作流迁入这个内容后台。
            </p>
          </div>
          <Link href="/admin/content/legacy-tools" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            查看迁移期旧工具
          </Link>
        </div>
        <div className="mt-5 grid gap-3 md:grid-cols-3">
          {[
            '先完成工作区骨架与入口收口',
            '再升级多级侧栏与统一信息架构',
            '随后持续补 shared draft / media / mapper 与各 Studio 深水区',
          ].map((item) => (
            <div key={item} className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm">
              {item}
            </div>
          ))}
        </div>
      </section>
    </AdminContentLayout>
  );
}
