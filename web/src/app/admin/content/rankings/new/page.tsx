'use client';

import Link from 'next/link';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import { rankingAdminApi, type RankingBoardEntry, type RankingEntityType } from '@/features/admin-content/ranking-admin';

const makeEmptyEntry = (rank: number): RankingBoardEntry => ({
  rank,
  name: '',
  entityId: null,
});

type CreateDraft = {
  id: string;
  title: string;
  subtitle: string;
  description: string;
  entityType: RankingEntityType;
  year: string;
  coverImageUrl: string;
};

const initialCreateDraft = (): CreateDraft => ({
  id: '',
  title: '',
  subtitle: '',
  description: '',
  entityType: 'dj',
  year: String(new Date().getFullYear()),
  coverImageUrl: '',
});

export default function AdminRankingCreatePage() {
  const router = useRouter();
  const [draft, setDraft] = useState<CreateDraft>(initialCreateDraft);
  const [entries, setEntries] = useState<RankingBoardEntry[]>([
    makeEmptyEntry(1),
    makeEmptyEntry(2),
    makeEmptyEntry(3),
  ]);
  const [importText, setImportText] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const handleSubmit = async () => {
    setSaving(true);
    setError('');
    setNotice('');
    try {
      const created = await rankingAdminApi.createBoard({
        id: draft.id || undefined,
        title: draft.title.trim(),
        subtitle: draft.subtitle.trim(),
        description: draft.description.trim(),
        entityType: draft.entityType,
        year: Number(draft.year),
        coverImageUrl: draft.coverImageUrl.trim() || null,
        entries: entries.filter((item) => item.name.trim()),
        importText: importText.trim(),
      });
      setNotice(`已创建榜单：${created.title}`);
      setTimeout(() => {
        router.push('/admin/content/rankings');
      }, 600);
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '创建榜单失败。');
    } finally {
      setSaving(false);
    }
  };

  return (
    <AdminContentLayout
      title="新建榜单"
      description="在独立页面内创建榜单，录入榜单基础信息、首年内容与导入文本。"
      actions={
        <>
          <Link
            href="/admin/content/rankings"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            返回榜单管理
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
      <section className="space-y-5">
        {error ? (
          <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] p-4 text-sm text-[#6a3530]">
            {error}
          </div>
        ) : null}
        {notice ? (
          <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-4 text-sm text-[#2f4027]">
            {notice}
          </div>
        ) : null}

        <section className="admin-reference-card p-5">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <div className="text-xs uppercase tracking-[0.14em] text-black/38">Create</div>
              <h2 className="mt-2 text-[20px] font-semibold text-[#111827]">榜单基础信息</h2>
            </div>
            <button
              type="button"
              className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
              disabled={saving}
              onClick={() => void handleSubmit()}
            >
              {saving ? '提交中...' : '创建榜单'}
            </button>
          </div>

          <div className="mt-4 grid gap-4 md:grid-cols-2">
            <input
              className="admin-reference-soft-card px-4 py-3 text-sm"
              placeholder="榜单 ID（可选）"
              value={draft.id}
              onChange={(event) => setDraft((prev) => ({ ...prev, id: event.target.value }))}
            />
            <input
              className="admin-reference-soft-card px-4 py-3 text-sm"
              placeholder="榜单标题"
              value={draft.title}
              onChange={(event) => setDraft((prev) => ({ ...prev, title: event.target.value }))}
            />
            <input
              className="admin-reference-soft-card px-4 py-3 text-sm"
              placeholder="副标题"
              value={draft.subtitle}
              onChange={(event) => setDraft((prev) => ({ ...prev, subtitle: event.target.value }))}
            />
            <input
              className="admin-reference-soft-card px-4 py-3 text-sm"
              placeholder="年份"
              value={draft.year}
              onChange={(event) => setDraft((prev) => ({ ...prev, year: event.target.value }))}
            />
            <select
              className="admin-reference-soft-card px-4 py-3 text-sm"
              value={draft.entityType}
              onChange={(event) =>
                setDraft((prev) => ({ ...prev, entityType: event.target.value as RankingEntityType }))
              }
            >
              <option value="dj">DJ 榜单</option>
              <option value="festival">主办方 / 节庆品牌榜单</option>
            </select>
            <input
              className="admin-reference-soft-card px-4 py-3 text-sm"
              placeholder="封面图片 URL（可选）"
              value={draft.coverImageUrl}
              onChange={(event) => setDraft((prev) => ({ ...prev, coverImageUrl: event.target.value }))}
            />
          </div>

          <textarea
            className="admin-reference-soft-card mt-4 min-h-[96px] w-full px-4 py-3 text-sm"
            placeholder="榜单描述"
            value={draft.description}
            onChange={(event) => setDraft((prev) => ({ ...prev, description: event.target.value }))}
          />
        </section>

        <section className="grid gap-5 xl:grid-cols-[360px_minmax(0,1fr)]">
          <div className="admin-reference-card p-5">
            <div className="text-sm font-semibold text-[#111827]">手动录入前三位</div>
            <div className="mt-3 space-y-3">
              {entries.map((entry, index) => (
                <div key={`create-${index}`} className="grid gap-2 md:grid-cols-[80px_minmax(0,1fr)]">
                  <input
                    className="rounded-[14px] border border-[#e8eceb] bg-white px-3 py-2 text-sm"
                    value={String(entry.rank)}
                    onChange={(event) =>
                      setEntries((prev) =>
                        prev.map((item, itemIndex) =>
                          itemIndex === index
                            ? { ...item, rank: Number(event.target.value) || item.rank }
                            : item
                        )
                      )
                    }
                  />
                  <input
                    className="rounded-[14px] border border-[#e8eceb] bg-white px-3 py-2 text-sm"
                    placeholder="条目名称"
                    value={entry.name}
                    onChange={(event) =>
                      setEntries((prev) =>
                        prev.map((item, itemIndex) =>
                          itemIndex === index ? { ...item, name: event.target.value } : item
                        )
                      )
                    }
                  />
                </div>
              ))}
              <button
                type="button"
                className="rounded-full border border-[#d7ded9] px-4 py-2 text-sm text-[#18211f]"
                onClick={() => setEntries((prev) => [...prev, makeEmptyEntry(prev.length + 1)])}
              >
                添加一行
              </button>
            </div>
          </div>

          <div className="admin-reference-card p-5">
            <div className="text-sm font-semibold text-[#111827]">批量导入文本</div>
            <p className="mt-2 text-xs leading-6 text-black/48">支持 `1. Name` 或每行一个名称。</p>
            <textarea
              className="mt-3 min-h-[220px] w-full rounded-[16px] border border-[#e8eceb] bg-white px-3 py-3 text-sm"
              placeholder={`1. Artist A\n2. Artist B\n3. Artist C`}
              value={importText}
              onChange={(event) => setImportText(event.target.value)}
            />
          </div>
        </section>
      </section>
    </AdminContentLayout>
  );
}
