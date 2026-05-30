'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

const EVENT_CAPABILITIES = [
  '活动目录、创建、编辑已经进入统一后台主入口',
  '活动时区搜索、主办方绑定、封面和阵容图上传已可直接处理',
  '编辑流已对齐当前 /v1 提交链路',
  '后续继续细化 schedule、weeks、eventDays 与 timetable 语义',
];

function MetricCard({
  label,
  value,
  note,
}: {
  label: string;
  value: string;
  note: string;
}) {
  return (
    <div className="rounded-[18px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] p-5">
      <div className="text-[11px] uppercase tracking-[0.18em] text-[#5d5d5d]">{label}</div>
      <div className="mt-3 font-mono text-[28px] font-semibold tracking-[-0.04em] text-[#f4f4f4]">
        {value}
      </div>
      <div className="mt-2 text-[12px] text-[#7c7c7c]">{note}</div>
    </div>
  );
}

export default function AdminContentEventsPage() {
  return (
    <AdminContentLayout
      title="活动工作区"
      description="统一管理活动目录、创建、编辑、时区、主办方绑定与媒体资料。活动主链路已经集中到这一套工作区中，可直接作为日常活动管理入口。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-4 py-2 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
            返回内容总览
          </Link>
          <Link href="/admin/content/events/catalog" className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-4 py-2 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
            活动目录中心
          </Link>
          <Link href="/admin/content/events/new" className="rounded-xl bg-[#a8ff3e] px-4 py-2 text-sm font-semibold text-black">
            新建活动
          </Link>
        </>
      }
    >
      <section className="grid gap-4 lg:grid-cols-4">
        <MetricCard label="Catalog" value="Live" note="目录与编辑入口已统一" />
        <MetricCard label="Studio" value="/v1" note="创建与编辑对齐当前接口" />
        <MetricCard label="Media" value="Ready" note="封面与阵容图上传可用" />
        <MetricCard label="Binding" value="On" note="主办方绑定已进入主流程" />
      </section>

      <section className="grid gap-5 xl:grid-cols-[1.3fr_0.7fr]">
        <div className="rounded-[18px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] p-6">
          <div className="text-[11px] uppercase tracking-[0.18em] text-[#5f5f5f]">Event Studio</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#f0f0f0]">核心能力</h2>
          <div className="mt-5 space-y-3">
            {EVENT_CAPABILITIES.map((item, index) => (
              <div key={item} className="flex items-center gap-3 rounded-[14px] border border-[rgba(255,255,255,0.07)] bg-[#151515] px-4 py-3 text-sm leading-6 text-[#d3d3d3]">
                <div className="flex h-7 w-7 items-center justify-center rounded-full bg-[#a8ff3e] text-[11px] font-bold text-black">
                  {index + 1}
                </div>
                <div>{item}</div>
              </div>
            ))}
          </div>
        </div>

        <div className="space-y-5">
          <div className="rounded-[18px] border border-[rgba(168,255,62,0.18)] bg-[linear-gradient(180deg,rgba(168,255,62,0.12),rgba(168,255,62,0.03))] p-6">
            <div className="text-[11px] uppercase tracking-[0.18em] text-[#86b852]">Status</div>
            <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#f0f0f0]">当前已可直接使用</h2>
            <div className="mt-4 space-y-3 text-sm leading-6 text-[#9ab27f]">
              <p>活动目录中心、活动新建和活动编辑已经在统一后台内收口，主要资料、时区、主办方绑定和媒体上传都可直接处理。</p>
              <p>剩余差距集中在更深的 schedule / eventDays / revision conflict 语义，会继续在这条主链路内补齐。</p>
            </div>
          </div>

          <div className="rounded-[18px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] p-6">
            <div className="text-[11px] uppercase tracking-[0.18em] text-[#5f5f5f]">Quick Access</div>
            <div className="mt-4 grid gap-3">
              <Link href="/admin/content/events/catalog" className="rounded-[14px] border border-[rgba(255,255,255,0.07)] bg-[#151515] px-4 py-3 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
                打开活动目录中心
              </Link>
              <Link href="/admin/content/events/new" className="rounded-[14px] border border-[rgba(255,255,255,0.07)] bg-[#151515] px-4 py-3 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
                创建新的活动条目
              </Link>
              <Link href="/admin/content/organizers/new" className="rounded-[14px] border border-[rgba(255,255,255,0.07)] bg-[#151515] px-4 py-3 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
                新建主办方并继续绑定
              </Link>
            </div>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
