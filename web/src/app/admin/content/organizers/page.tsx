'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

const ORGANIZER_ITEMS = [
  '目录中心支持快速检索、编辑跳转与绑定跳转',
  '主办方新建与编辑已在统一后台原生可用',
  '活动绑定中心支持关系定位、清空与批量治理',
  '后续继续补 revision diff 与更深的关系治理体验',
];

export default function AdminContentOrganizersPage() {
  return (
    <AdminContentLayout
      title="主办方工作区"
      description="统一管理主办方目录、新建、编辑、官方链接、素材资料与活动绑定。主办方主链路已经可以在这一套后台中连续完成。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-4 py-2 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
            返回内容总览
          </Link>
          <Link href="/admin/content/organizers/catalog" className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-4 py-2 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
            主办方目录中心
          </Link>
          <Link href="/admin/content/organizers/new" className="rounded-xl bg-[#a8ff3e] px-4 py-2 text-sm font-semibold text-black">
            新建主办方
          </Link>
        </>
      }
    >
      <section className="grid gap-4 lg:grid-cols-4">
        {[
          { label: 'Catalog', value: 'Ready', note: '全量目录已接入' },
          { label: 'Create', value: 'On', note: '主办方创建已可直接使用' },
          { label: 'Edit', value: 'Patch', note: '资料回填与提交已打通' },
          { label: 'Binding', value: 'Live', note: '活动关系维护已在主后台' },
        ].map((item) => (
          <div key={item.label} className="rounded-[18px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] p-5">
            <div className="text-[11px] uppercase tracking-[0.18em] text-[#5d5d5d]">{item.label}</div>
            <div className="mt-3 font-mono text-[28px] font-semibold tracking-[-0.04em] text-[#f4f4f4]">
              {item.value}
            </div>
            <div className="mt-2 text-[12px] text-[#7c7c7c]">{item.note}</div>
          </div>
        ))}
      </section>

      <section className="grid gap-5 xl:grid-cols-[1.25fr_0.75fr]">
        <div className="rounded-[18px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] p-6">
          <div className="text-[11px] uppercase tracking-[0.18em] text-[#5f5f5f]">Organizer Studio</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#f0f0f0]">核心能力</h2>
          <div className="mt-5 space-y-3">
            {ORGANIZER_ITEMS.map((item, index) => (
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
            <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#f0f0f0]">目录与关系已统一收口</h2>
            <div className="mt-4 space-y-3 text-sm leading-6 text-[#9ab27f]">
              <p>统一后台已经提供主办方目录、新建、编辑和绑定中心，日常资料治理可以在同一套工作台中完成。</p>
              <p>目录层负责定位和跳转，深入修改再进入编辑页或绑定面板处理。</p>
            </div>
          </div>

          <div className="rounded-[18px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] p-6">
            <div className="text-[11px] uppercase tracking-[0.18em] text-[#5f5f5f]">Quick Access</div>
            <div className="mt-4 grid gap-3">
              <Link href="/admin/content/organizers/catalog" className="rounded-[14px] border border-[rgba(255,255,255,0.07)] bg-[#151515] px-4 py-3 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
                打开主办方目录中心
              </Link>
              <Link href="/admin/content/organizers/bindings" className="rounded-[14px] border border-[rgba(255,255,255,0.07)] bg-[#151515] px-4 py-3 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
                进入活动绑定中心
              </Link>
              <Link href="/admin/content/organizers/new" className="rounded-[14px] border border-[rgba(255,255,255,0.07)] bg-[#151515] px-4 py-3 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
                创建新的主办方条目
              </Link>
            </div>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
