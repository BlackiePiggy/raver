'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import { genreAdminApi } from '@/features/admin-content/genre-admin';

type CreateGenreDraft = {
  name: string;
  parentId: string;
  slug: string;
  sortOrder: string;
};

const initialDraft = (): CreateGenreDraft => ({
  name: '',
  parentId: '',
  slug: '',
  sortOrder: '',
});

export default function AdminGenreCreatePage() {
  const [draft, setDraft] = useState<CreateGenreDraft>(initialDraft);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [created, setCreated] = useState<{ id: string; name: string; path: string } | null>(null);

  const canSubmit = useMemo(() => draft.name.trim().length > 0, [draft.name]);

  const handleSubmit = async () => {
    if (!canSubmit) {
      setError('请先填写流派名称。');
      return;
    }

    setSaving(true);
    setError('');
    try {
      const node = await genreAdminApi.createNode({
        name: draft.name.trim(),
        parentId: draft.parentId.trim() || null,
        slug: draft.slug.trim() || null,
        sortOrder: draft.sortOrder.trim() ? Number(draft.sortOrder) : null,
      });
      setCreated({
        id: node.id,
        name: node.name,
        path: node.path,
      });
      setDraft(initialDraft());
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '创建流派失败。');
    } finally {
      setSaving(false);
    }
  };

  return (
    <AdminContentLayout
      title="新建流派"
      description="通过独立流程创建新的流派节点，创建成功后会停留在成功结果页，方便继续回到流派管理。"
      actions={
        <>
          <Link
            href="/admin/content/genres"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            返回流派管理
          </Link>
          <Link
            href="/admin/content"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            返回内容控制台
          </Link>
        </>
      }
    >
      {created ? (
        <section className="space-y-5">
          <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-6 text-[#2f4027]">
            <div className="text-xs uppercase tracking-[0.14em] text-[#52705c]">Success</div>
            <div className="mt-3 text-[30px] font-semibold tracking-[-0.04em] text-[#111827]">流派创建成功</div>
            <div className="mt-3 space-y-2 text-sm leading-7 text-[#4a5b52]">
              <div>名称：{created.name}</div>
              <div>路径：{created.path}</div>
              <div>ID：{created.id}</div>
            </div>
          </div>

          <div className="flex flex-wrap gap-3">
            <Link
              href="/admin/content/genres"
              className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
            >
              返回流派管理
            </Link>
            <button
              type="button"
              onClick={() => {
                setCreated(null);
                setError('');
              }}
              className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
            >
              继续新建
            </button>
          </div>
        </section>
      ) : (
        <section className="space-y-5">
          {error ? (
            <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] p-4 text-sm text-[#6a3530]">
              {error}
            </div>
          ) : null}

          <section className="admin-reference-card p-6">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <div className="text-xs uppercase tracking-[0.14em] text-black/38">Create</div>
                <h2 className="mt-2 text-[22px] font-semibold text-[#111827]">流派节点信息</h2>
                <div className="mt-1 text-sm text-black/48">根节点和子节点都通过这个独立页面创建。</div>
              </div>
              <button
                type="button"
                onClick={() => void handleSubmit()}
                disabled={saving || !canSubmit}
                className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
              >
                {saving ? '创建中...' : '创建流派'}
              </button>
            </div>

            <div className="mt-5 grid gap-4 md:grid-cols-2">
              <input
                className="rounded-[16px] border border-[#e8eceb] bg-white px-4 py-3 text-sm"
                placeholder="流派名称"
                value={draft.name}
                onChange={(event) => setDraft((current) => ({ ...current, name: event.target.value }))}
              />
              <input
                className="rounded-[16px] border border-[#e8eceb] bg-white px-4 py-3 text-sm"
                placeholder="父节点 ID（可选）"
                value={draft.parentId}
                onChange={(event) => setDraft((current) => ({ ...current, parentId: event.target.value }))}
              />
              <input
                className="rounded-[16px] border border-[#e8eceb] bg-white px-4 py-3 text-sm"
                placeholder="Slug（可选）"
                value={draft.slug}
                onChange={(event) => setDraft((current) => ({ ...current, slug: event.target.value }))}
              />
              <input
                className="rounded-[16px] border border-[#e8eceb] bg-white px-4 py-3 text-sm"
                placeholder="排序值（可选）"
                value={draft.sortOrder}
                onChange={(event) => setDraft((current) => ({ ...current, sortOrder: event.target.value }))}
              />
            </div>
          </section>
        </section>
      )}
    </AdminContentLayout>
  );
}
