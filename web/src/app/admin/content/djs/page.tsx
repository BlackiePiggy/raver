'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

const DJ_RULES = [
  '目录中心支持快速检索、排序与编辑跳转',
  'DJ 新建与编辑已经在统一后台中打通',
  '头像、proof、平台链接和基础统计可以直接提交',
  '后续继续补 proof 生命周期与平台源对齐提示',
];

const SUMMARY_CARDS = [
  { label: 'Catalog', title: 'Ready', note: '全量目录已接入', className: 'bg-[#dff4a8]' },
  { label: 'Create', title: 'Import', note: '手动创建已对齐当前接口', className: 'bg-[#f3e5a8]' },
  { label: 'Media', title: 'OSS', note: '头像与素材上传已可用', className: 'bg-[#dbeefe]' },
];

export default function AdminContentDjsPage() {
  return (
    <AdminContentLayout
      title="DJ 工作区"
      description="统一管理 DJ 目录、新建、编辑、proof、平台链接与媒体资料。DJ 主链路已经集中到统一后台中，适合直接作为日常资料管理入口。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
            返回内容总览
          </Link>
          <Link href="/admin/content/djs/catalog" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
            DJ 目录中心
          </Link>
          <Link href="/admin/content/djs/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            新建 DJ
          </Link>
        </>
      }
    >
      <section className="space-y-5">
        <div className="admin-reference-card p-5">
          <div className="grid gap-3 md:grid-cols-3">
            {SUMMARY_CARDS.map((card) => (
              <div key={card.label} className={`admin-reference-pastel-card ${card.className} p-4`}>
                <div className="flex items-start justify-between">
                  <div>
                    <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">{card.label}</div>
                    <div className="mt-6 text-[38px] font-semibold leading-none text-[#1a1a1a]">{card.title}</div>
                  </div>
                  <span className="admin-reference-chip">Status</span>
                </div>
                <div className="mt-8 text-[13px] leading-6 text-black/55">{card.note}</div>
              </div>
            ))}
          </div>
        </div>

        <div className="grid gap-5 xl:grid-cols-[1.35fr_0.65fr]">
          <section className="admin-reference-card p-6">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">DJ Studio</div>
                <h2 className="mt-2 text-[28px] font-semibold tracking-[-0.03em] text-[#1a1a1a]">核心规则</h2>
              </div>
              <span className="admin-reference-chip">Main Flow</span>
            </div>

            <div className="mt-5 space-y-3">
              {DJ_RULES.map((item, index) => (
                <div key={item} className="admin-reference-soft-card flex items-center gap-4 px-4 py-4">
                  <div className="flex h-10 w-10 items-center justify-center rounded-full bg-[#b8ff2b] text-[14px] font-bold text-black">
                    {index + 1}
                  </div>
                  <div className="text-[15px] leading-7 text-[#1f2937]">{item}</div>
                </div>
              ))}
            </div>
          </section>

          <div className="space-y-5">
            <section className="admin-reference-pastel-card bg-[linear-gradient(180deg,#ebfff5_0%,#f9fffc_100%)] p-6">
              <div className="text-[12px] uppercase tracking-[0.18em] text-[#8cae73]">Status</div>
              <h2 className="mt-2 text-[30px] font-semibold tracking-[-0.03em] text-[#1a1a1a]">当前已可直接使用</h2>
              <div className="mt-5 space-y-3 text-[15px] leading-8 text-[#8ea27f]">
                <p>DJ 目录中心、DJ 新建和 DJ 编辑已经在统一后台内打通，头像、banner、proof 与平台链接都可直接提交。</p>
                <p>接下来会继续细化 proof 生命周期和平台源对齐体验，但主线已经不再依赖旧列表页。</p>
              </div>
            </section>

            <section className="admin-reference-dark-card p-6">
              <div className="text-[12px] uppercase tracking-[0.18em] text-white/30">Quick Access</div>
              <div className="mt-4 space-y-3">
                <Link href="/admin/content/djs/catalog" className="block rounded-[20px] border border-white/10 px-4 py-4 text-[15px] text-white/88">
                  打开 DJ 目录中心
                </Link>
                <Link href="/admin/content/djs/new" className="block rounded-[20px] border border-white/10 px-4 py-4 text-[15px] text-white/88">
                  创建新的 DJ 条目
                </Link>
                <Link href="/admin/content/reviews/dj-bindings" className="block rounded-[20px] border border-white/10 px-4 py-4 text-[15px] text-white/88">
                  进入 DJ 绑定审核
                </Link>
              </div>
            </section>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
