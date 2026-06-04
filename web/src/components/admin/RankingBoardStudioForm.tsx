'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import {
  rankingAdminApi,
  type RankingBoardDetail,
  type RankingEntityType,
} from '@/features/admin-content/ranking-admin/api';

type RankingBoardStudioFormProps = {
  mode: 'create' | 'edit';
  boardId?: string;
};

type DraftState = {
  id: string;
  title: string;
  subtitle: string;
  description: string;
  entityType: RankingEntityType;
  coverImageUrl: string;
};

const createInitialDraft = (): DraftState => ({
  id: '',
  title: '',
  subtitle: '',
  description: '',
  entityType: 'dj',
  coverImageUrl: '',
});

const buildDraftFromDetail = (detail: RankingBoardDetail): DraftState => ({
  id: detail.boardId,
  title: detail.title,
  subtitle: detail.subtitle || '',
  description: detail.description || '',
  entityType: detail.entityType,
  coverImageUrl: detail.coverImageUrl || '',
});

export default function RankingBoardStudioForm({ mode, boardId }: RankingBoardStudioFormProps) {
  const router = useRouter();
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const [draft, setDraft] = useState<DraftState>(createInitialDraft);
  const [loading, setLoading] = useState(mode === 'edit');
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  useEffect(() => {
    if (mode !== 'edit' || !boardId) return;
    let cancelled = false;
    const load = async () => {
      setLoading(true);
      setError('');
      try {
        const detail = await rankingAdminApi.fetchBoard(boardId);
        if (cancelled) return;
        setDraft(buildDraftFromDetail(detail));
      } catch (loadError) {
        if (cancelled) return;
        setError(loadError instanceof Error ? loadError.message : '加载榜单失败');
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void load();
    return () => {
      cancelled = true;
    };
  }, [boardId, mode]);

  const handleUploadCover = async (file: File | null) => {
    if (!file) return;
    setUploading(true);
    setError('');
    try {
      const uploaded = await rankingAdminApi.uploadImage(file, draft.id || draft.title || 'ranking-temp');
      setDraft((current) => ({ ...current, coverImageUrl: uploaded.url || uploaded.originalUrl || '' }));
    } catch (uploadError) {
      setError(uploadError instanceof Error ? uploadError.message : '上传榜单封面失败');
    } finally {
      setUploading(false);
    }
  };

  const handleSubmit = async () => {
    const title = draft.title.trim();
    if (!title) {
      setError('榜单名称不能为空');
      return;
    }

    setSaving(true);
    setError('');
    setNotice('');
    try {
      if (mode === 'create') {
        const created = await rankingAdminApi.createBoard({
          id: draft.id.trim() || undefined,
          title,
          subtitle: draft.subtitle.trim(),
          description: draft.description.trim(),
          entityType: draft.entityType,
          coverImageUrl: draft.coverImageUrl.trim() || null,
        });
        setNotice(`已创建榜单：${created.title}`);
        setTimeout(() => {
          router.push('/admin/content/rankings');
        }, 500);
        return;
      }

      if (!boardId) {
        setError('缺少榜单 ID');
        return;
      }

      await rankingAdminApi.updateBoard(boardId, {
        title,
        subtitle: draft.subtitle.trim(),
        description: draft.description.trim(),
        entityType: draft.entityType,
        coverImageUrl: draft.coverImageUrl.trim() || null,
      });
      setNotice('榜单信息已保存');
      setTimeout(() => {
        router.push('/admin/content/rankings');
      }, 500);
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : mode === 'create' ? '创建榜单失败' : '更新榜单失败');
    } finally {
      setSaving(false);
    }
  };

  return (
    <AdminContentLayout
      title={mode === 'create' ? '新建榜单' : '编辑榜单'}
      description={mode === 'create' ? '这里只创建榜单本体信息，不录入任何年度对象。' : '修改榜单名称、封面、简介和绑定对象类型。'}
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
              <div className="text-xs uppercase tracking-[0.14em] text-black/38">Board Metadata</div>
              <h2 className="mt-2 text-[20px] font-semibold text-[#111827]">
                {mode === 'create' ? '榜单本体信息' : '编辑榜单本体'}
              </h2>
            </div>
            <button
              type="button"
              onClick={() => void handleSubmit()}
              disabled={saving || uploading || loading}
              className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
            >
              {saving ? '保存中...' : mode === 'create' ? '创建榜单' : '保存修改'}
            </button>
          </div>

          {loading ? (
            <div className="mt-5 admin-reference-soft-card p-4 text-sm text-black/50">正在加载榜单信息...</div>
          ) : (
            <div className="mt-5 grid gap-5 xl:grid-cols-[minmax(0,1.2fr)_320px]">
              <div className="space-y-4">
                <div className="grid gap-4 md:grid-cols-2">
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    placeholder="榜单 ID（可选）"
                    value={draft.id}
                    disabled={mode === 'edit'}
                    onChange={(event) => setDraft((current) => ({ ...current, id: event.target.value }))}
                  />
                  <select
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    value={draft.entityType}
                    onChange={(event) =>
                      setDraft((current) => ({
                        ...current,
                        entityType: event.target.value === 'festival' ? 'festival' : 'dj',
                      }))
                    }
                  >
                    <option value="dj">绑定 DJ</option>
                    <option value="festival">绑定主办方 / 品牌</option>
                  </select>
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm md:col-span-2"
                    placeholder="榜单名称"
                    value={draft.title}
                    onChange={(event) => setDraft((current) => ({ ...current, title: event.target.value }))}
                  />
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm md:col-span-2"
                    placeholder="榜单副标题"
                    value={draft.subtitle}
                    onChange={(event) => setDraft((current) => ({ ...current, subtitle: event.target.value }))}
                  />
                </div>

                <textarea
                  className="admin-reference-soft-card min-h-[180px] w-full px-4 py-3 text-sm"
                  placeholder="榜单简介"
                  value={draft.description}
                  onChange={(event) => setDraft((current) => ({ ...current, description: event.target.value }))}
                />
              </div>

              <div className="space-y-4">
                <div className="admin-reference-soft-card p-4">
                  <div className="text-xs uppercase tracking-[0.14em] text-black/38">Cover</div>
                  <div className="mt-3 overflow-hidden rounded-[20px] border border-[#e8eceb] bg-[#f5f6f7]">
                    <div className="relative aspect-[1/1]">
                      {draft.coverImageUrl.trim() ? (
                        <Image src={draft.coverImageUrl} alt={draft.title || 'ranking cover'} fill className="object-cover" sizes="480px" />
                      ) : (
                        <div className="flex h-full items-center justify-center text-sm text-black/45">暂无封面</div>
                      )}
                    </div>
                  </div>
                  <div className="mt-3 flex flex-wrap gap-2">
                    <button
                      type="button"
                      onClick={() => fileInputRef.current?.click()}
                      disabled={uploading}
                      className="rounded-full border border-[#d7ded9] bg-white px-4 py-2 text-sm text-[#18211f] disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      {uploading ? '上传中...' : '上传封面'}
                    </button>
                    <button
                      type="button"
                      onClick={() => setDraft((current) => ({ ...current, coverImageUrl: '' }))}
                      className="rounded-full border border-[#ead6d6] bg-white px-4 py-2 text-sm text-[#8b3a3a]"
                    >
                      清空封面
                    </button>
                  </div>
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={(event) => {
                      const file = event.target.files?.[0] ?? null;
                      event.currentTarget.value = '';
                      void handleUploadCover(file);
                    }}
                  />
                </div>

                <input
                  className="admin-reference-soft-card w-full px-4 py-3 text-sm"
                  placeholder="或直接粘贴封面图片 URL"
                  value={draft.coverImageUrl}
                  onChange={(event) => setDraft((current) => ({ ...current, coverImageUrl: event.target.value }))}
                />
              </div>
            </div>
          )}
        </section>
      </section>
    </AdminContentLayout>
  );
}
