'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

const ORGANIZER_ITEMS = [
  '目录中心支持快速检索、编辑跳转与绑定跳转',
  '主办方新建与编辑已在统一后台原生可用',
  '活动绑定中心支持关系定位、清空与批量治理',
  '后续继续补 revision diff 与更深的关系治理体验',
];

const SUMMARY_CARDS = [
  { label: 'Catalog', title: 'Ready', note: '全量目录已接入', className: 'bg-[#dff4a8]' },
  { label: 'Create', title: 'On', note: '主办方创建已可直接使用', className: 'bg-[#f3e5a8]' },
  { label: 'Edit', title: 'Patch', note: '资料回填与提交已打通', className: 'bg-[#f7c4c0]' },
];

export default function AdminContentOrganizersPage() {
  return (
    <AdminContentLayout
      title="主办方工作区"
      description="统一管理主办方目录、新建、编辑、官方链接、素材资料与活动绑定。主办方主链路已经可以在这一套后台中连续完成。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
            返回内容总览
          </Link>
          <Link href="/admin/content/organizers/catalog" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
            主办方目录中心
          </Link>
          <Link href="/admin/content/organizers/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            新建主办方
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
                <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">Organizer Studio</div>
                <h2 className="mt-2 text-[28px] font-semibold tracking-[-0.03em] text-[#1a1a1a]">核心能力</h2>
              </div>
              <span className="admin-reference-chip">Main Flow</span>
            </div>

            <div className="mt-5 space-y-3">
              {ORGANIZER_ITEMS.map((item, index) => (
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
              <h2 className="mt-2 text-[30px] font-semibold tracking-[-0.03em] text-[#1a1a1a]">目录与关系已统一收口</h2>
              <div className="mt-5 space-y-3 text-[15px] leading-8 text-[#8ea27f]">
                <p>统一后台已经提供主办方目录、新建、编辑和绑定中心，日常资料治理可以在同一套工作台中完成。</p>
                <p>目录层负责定位和跳转，深入修改再进入编辑页或绑定面板处理。</p>
              </div>
            </section>

            <section className="admin-reference-dark-card p-6">
              <div className="text-[12px] uppercase tracking-[0.18em] text-white/30">Quick Access</div>
              <div className="mt-4 space-y-3">
                <Link href="/admin/content/organizers/catalog" className="block rounded-[20px] border border-white/10 px-4 py-4 text-[15px] text-white/88">
                  打开主办方目录中心
                </Link>
                <Link href="/admin/content/organizers/bindings" className="block rounded-[20px] border border-white/10 px-4 py-4 text-[15px] text-white/88">
                  进入活动绑定中心
                </Link>
                <Link href="/admin/content/organizers/new" className="block rounded-[20px] border border-white/10 px-4 py-4 text-[15px] text-white/88">
                  创建新的主办方条目
                </Link>
              </div>
            </section>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
