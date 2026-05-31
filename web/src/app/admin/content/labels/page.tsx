'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import { labelStudioApi, type LabelStudioLoadedLabel } from '@/features/admin-content/label-studio';

export default function AdminContentLabelsPage() {
  const [items, setItems] = useState<LabelStudioLoadedLabel[]>([]);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [search, setSearch] = useState('');
  const [inputValue, setInputValue] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      try {
        setLoading(true);
        setError(null);
        const response = await labelStudioApi.listLabels(page, 12, search);
        if (cancelled) return;
        setItems(response.items);
        setTotalPages(response.pagination.totalPages || 1);
      } catch (loadError) {
        if (cancelled) return;
        setError(loadError instanceof Error ? loadError.message : '加载厂牌失败');
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void load();
    return () => {
      cancelled = true;
    };
  }, [page, search]);

  return (
    <AdminContentLayout
      title="厂牌工作区"
      description="厂牌资料、视觉链接和官方渠道现在已经可以直接在网页后台中创建与编辑，并采用更接近参考后台的内容优先排版。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            返回内容控制台
          </Link>
          <Link href="/admin/content/labels/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            新建厂牌
          </Link>
        </>
      }
    >
      <section className="space-y-5">
        <div className="grid gap-4 lg:grid-cols-4">
          {[
            { label: 'Label Studio', value: 'Live', note: '创建 / 编辑已接入', tone: 'bg-[#dff4a8]' },
            { label: 'Visual Mode', value: 'URL', note: '视觉先走 URL 模式', tone: 'bg-[#f3e5a8]' },
            { label: 'Paging', value: `${page}/${totalPages}`, note: '标准页码', tone: 'bg-[#f7c4c0]' },
            { label: 'Results', value: String(items.length), note: '当前页数据', tone: 'bg-[#dbeefe]' },
          ].map((item) => (
            <div key={item.label} className={`admin-reference-pastel-card p-5 ${item.tone}`}>
              <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">{item.label}</div>
              <div className="mt-4 text-[34px] font-semibold tracking-[-0.04em] text-[#1a1a1a]">{item.value}</div>
              <div className="mt-2 text-[13px] text-black/55">{item.note}</div>
            </div>
          ))}
        </div>

        <section className="admin-reference-card p-6">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">Label Directory</div>
              <h2 className="mt-2 text-[30px] font-semibold tracking-[-0.03em] text-[#1a1a1a]">厂牌目录</h2>
            </div>
            <div className="flex flex-wrap gap-3">
              <input
                value={inputValue}
                onChange={(event) => setInputValue(event.target.value)}
                className="admin-studio-input w-[260px]"
                placeholder="搜索厂牌名称"
              />
              <button
                type="button"
                onClick={() => {
                  setPage(1);
                  setSearch(inputValue.trim());
                }}
                className="admin-studio-button-secondary px-5 py-3 text-sm"
              >
                搜索
              </button>
            </div>
          </div>

          {loading ? (
            <div className="mt-6 text-sm text-black/48">正在加载厂牌目录...</div>
          ) : error ? (
            <div className="admin-studio-pastel-rose mt-6 p-4 text-sm text-[#6a3530]">{error}</div>
          ) : (
            <div className="mt-6 grid gap-4 xl:grid-cols-2">
              {items.map((item) => (
                <div key={item.id} className="admin-reference-soft-card p-5">
                  <div className="flex items-start justify-between gap-4">
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap gap-2">
                        {item.nation ? <span className="admin-reference-chip">{item.nation}</span> : null}
                        {item.genresPreview ? <span className="admin-reference-chip">{item.genresPreview}</span> : null}
                      </div>
                      <h3 className="mt-4 text-xl font-semibold tracking-[-0.02em] text-[#071110]">{item.name}</h3>
                      <p className="mt-2 line-clamp-3 text-sm leading-7 text-black/48">
                        {item.introductionPreview || item.introduction || '暂无厂牌简介'}
                      </p>
                    </div>
                    <Link href={`/admin/content/labels/${item.id}/edit`} className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
                      编辑厂牌
                    </Link>
                  </div>
                </div>
              ))}
            </div>
          )}

          <div className="mt-6 flex flex-wrap gap-3">
            <button
              type="button"
              onClick={() => setPage((current) => Math.max(1, current - 1))}
              disabled={page <= 1}
              className="admin-studio-button-secondary px-5 py-3 text-sm disabled:opacity-50"
            >
              上一页
            </button>
            <button
              type="button"
              onClick={() => setPage((current) => Math.min(totalPages, current + 1))}
              disabled={page >= totalPages}
              className="admin-studio-button-secondary px-5 py-3 text-sm disabled:opacity-50"
            >
              下一页
            </button>
          </div>
        </section>
      </section>
    </AdminContentLayout>
  );
}
