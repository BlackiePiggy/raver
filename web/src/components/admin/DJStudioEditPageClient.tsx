'use client';

import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import DJStudioForm from '@/components/admin/DJStudioForm';
import {
  createDJStudioDraft,
  djStudioApi,
  hydrateDJStudioDraftFromDJ,
  type DJStudioCreateResult,
  type DJStudioDraft,
} from '@/features/admin-content/dj-studio';

export default function DJStudioEditPageClient() {
  const params = useParams<{ id: string }>();
  const djId = typeof params?.id === 'string' ? params.id : '';
  const [draft, setDraft] = useState<DJStudioDraft>(() => createDJStudioDraft());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [resultLink, setResultLink] = useState<string | null>(null);

  useEffect(() => {
    if (!djId) {
      setError('缺少 DJ ID');
      setLoading(false);
      return;
    }

    let cancelled = false;
    const load = async () => {
      try {
        setLoading(true);
        setError(null);
        const dj = await djStudioApi.fetchDJ(djId);
        if (cancelled) return;
        setDraft(hydrateDJStudioDraftFromDJ(dj));
      } catch (loadError) {
        if (cancelled) return;
        setError(loadError instanceof Error ? loadError.message : '加载 DJ 失败');
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, [djId]);

  const pageTitle = useMemo(
    () => draft.name.zh || draft.name.en || '编辑 DJ',
    [draft.name.en, draft.name.zh]
  );

  const handleSubmitResult = (result: DJStudioCreateResult) => {
    if (result.kind === 'created') {
      setNotice(`DJ 更新已提交成功：${result.dj.name}`);
      setResultLink(`/admin/content/djs/${result.dj.id}/edit`);
      return;
    }
    setNotice(result.payload.message || 'DJ 编辑已进入审核队列');
    setResultLink('/admin/content/reviews');
  };

  return (
    <AdminContentLayout
      title={pageTitle}
      description="编辑态第一版已经接上 DJ 详情加载、draft 回填和真实 PATCH 提交链路。下一轮会继续补 proof 生命周期、平台源对齐提示和从活动阵容一跳编辑 DJ 的联动。"
      actions={
        <>
          <Link
            href="/admin/content/djs"
            className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue"
          >
            返回 DJ 工作区
          </Link>
          <Link
            href="/admin/content/djs/catalog"
            className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue"
          >
            打开 DJ 目录中心
          </Link>
        </>
      }
    >
      {notice ? (
        <section className="rounded-3xl border border-primary-blue/30 bg-primary-blue/10 p-4 text-sm text-text-primary">
          <div>{notice}</div>
          {resultLink ? (
            <div className="mt-3">
              <Link href={resultLink} className="text-primary-blue hover:underline">
                打开结果页面
              </Link>
            </div>
          ) : null}
        </section>
      ) : null}

      {loading ? (
        <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-6 text-sm text-text-secondary">
          正在加载 DJ 详情并回填编辑表单...
        </section>
      ) : error ? (
        <section className="rounded-3xl border border-red-500/30 bg-red-500/10 p-6 text-sm text-red-200">
          {error}
        </section>
      ) : (
        <DJStudioForm
          mode="edit"
          djId={djId}
          draft={draft}
          setDraft={setDraft}
          onSubmit={handleSubmitResult}
          submitButtonText="提交 DJ 编辑"
        />
      )}
    </AdminContentLayout>
  );
}
