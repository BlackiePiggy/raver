'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

const EVENT_CAPABILITIES = [
  '活动目录、创建与编辑已经进入统一后台主入口',
  '时区搜索、主办方绑定、封面和阵容图上传可直接处理',
  '编辑流已对齐当前 /v1 提交链路',
  '后续继续细化 schedule、weeks、eventDays 与 timetable 语义',
];

const SUMMARY_CARDS = [
  {
    label: 'Catalog',
    title: 'Live',
    note: '目录与编辑入口已经统一',
    className: 'bg-[#dff4a8]',
  },
  {
    label: 'Studio',
    title: '/v1',
    note: '创建与编辑对齐当前接口',
    className: 'bg-[#f3e5a8]',
  },
  {
    label: 'Media',
    title: 'Ready',
    note: '封面与阵容图上传可用',
    className: 'bg-[#f7c4c0]',
  },
];

export default function AdminContentEventsPage() {
  return (
    <AdminContentLayout
      title="活动工作区"
      description="统一管理活动目录、创建、编辑、时区、主办方绑定与媒体资料。活动主链路已经集中到这一套工作区中，可直接作为日常活动管理入口。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
            返回内容总览
          </Link>
          <Link href="/admin/content/events/catalog" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
            活动目录中心
          </Link>
          <Link href="/admin/content/events/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            新建活动
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
                    <div className="mt-6 text-[40px] font-semibold leading-none text-[#1a1a1a]">{card.title}</div>
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
                <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">Event Studio</div>
                <h2 className="mt-2 text-[28px] font-semibold tracking-[-0.03em] text-[#1a1a1a]">核心能力</h2>
              </div>
              <span className="admin-reference-chip">Main Flow</span>
            </div>

            <div className="mt-5 space-y-3">
              {EVENT_CAPABILITIES.map((item, index) => (
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
              <h2 className="mt-2 text-[30px] font-semibold tracking-[-0.03em] text-[#f3f1ff] mix-blend-multiply">
                当前已可直接使用
              </h2>
              <div className="mt-5 space-y-3 text-[15px] leading-8 text-[#8ea27f]">
                <p>活动目录中心、活动新建和活动编辑已经在统一后台内收口，主要资料、时区、主办方绑定和媒体上传都可直接处理。</p>
                <p>剩余差距集中在更深的 schedule、eventDays 和 revision conflict 语义，会继续在这条主链路内补齐。</p>
              </div>
            </section>

            <section className="admin-reference-dark-card p-6">
              <div className="text-[12px] uppercase tracking-[0.18em] text-white/30">Quick Access</div>
              <div className="mt-5 space-y-3">
                <Link href="/admin/content/events/catalog" className="block rounded-[20px] border border-white/10 px-4 py-4 text-[15px] text-white/88">
                  打开活动目录中心
                </Link>
                <Link href="/admin/content/events/new" className="block rounded-[20px] border border-white/10 px-4 py-4 text-[15px] text-white/88">
                  创建新的活动条目
                </Link>
                <Link href="/admin/content/organizers/new" className="block rounded-[20px] border border-white/10 px-4 py-4 text-[15px] text-white/88">
                  新建主办方并继续绑定
                </Link>
              </div>
            </section>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
