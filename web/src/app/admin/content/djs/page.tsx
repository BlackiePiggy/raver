'use client';

import Link from 'next/link';
import AdminContentLayout from '@/components/admin/AdminContentLayout';

const DJ_RULES = [
  '目录中心支持快速检索、排序与编辑跳转',
  'DJ 新建与编辑已经在统一后台中打通',
  '头像、proof、平台链接和基础统计可以直接提交',
  '后续继续补 proof 生命周期与平台源对齐提示',
];

export default function AdminContentDjsPage() {
  return (
    <AdminContentLayout
      title="DJ 工作区"
      description="统一管理 DJ 目录、新建、编辑、proof、平台链接与媒体资料。DJ 主链路已经集中到统一后台中，适合直接作为日常资料管理入口。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-4 py-2 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
            返回内容总览
          </Link>
          <Link href="/admin/content/djs/catalog" className="rounded-xl border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] px-4 py-2 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
            DJ 目录中心
          </Link>
          <Link href="/admin/content/djs/new" className="rounded-xl bg-[#a8ff3e] px-4 py-2 text-sm font-semibold text-black">
            新建 DJ
          </Link>
        </>
      }
    >
      <section className="grid gap-4 lg:grid-cols-4">
        {[
          { label: 'Catalog', value: 'Ready', note: '全量目录已接入' },
          { label: 'Create', value: 'Import', note: '手动创建已对齐当前接口' },
          { label: 'Edit', value: 'Patch', note: '编辑资料已可提交' },
          { label: 'Media', value: 'OSS', note: '头像与素材上传已可用' },
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
          <div className="text-[11px] uppercase tracking-[0.18em] text-[#5f5f5f]">DJ Studio</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#f0f0f0]">核心规则</h2>
          <div className="mt-5 space-y-3">
            {DJ_RULES.map((item, index) => (
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
              <p>DJ 目录中心、DJ 新建和 DJ 编辑已经在统一后台内打通，头像、banner、proof 与平台链接都可直接提交。</p>
              <p>接下来会继续细化 proof 生命周期和平台源对齐体验，但主线已经不再依赖旧列表页。</p>
            </div>
          </div>

          <div className="rounded-[18px] border border-[rgba(255,255,255,0.07)] bg-[#1a1a1a] p-6">
            <div className="text-[11px] uppercase tracking-[0.18em] text-[#5f5f5f]">Quick Access</div>
            <div className="mt-4 grid gap-3">
              <Link href="/admin/content/djs/catalog" className="rounded-[14px] border border-[rgba(255,255,255,0.07)] bg-[#151515] px-4 py-3 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
                打开 DJ 目录中心
              </Link>
              <Link href="/admin/content/djs/new" className="rounded-[14px] border border-[rgba(255,255,255,0.07)] bg-[#151515] px-4 py-3 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
                创建新的 DJ 条目
              </Link>
              <Link href="/admin/content/reviews/dj-bindings" className="rounded-[14px] border border-[rgba(255,255,255,0.07)] bg-[#151515] px-4 py-3 text-sm text-[#d0d0d0] hover:bg-[#202020] hover:text-white">
                进入 DJ 绑定审核
              </Link>
            </div>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
