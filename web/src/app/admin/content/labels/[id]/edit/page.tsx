'use client';

import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import LabelStudioForm from '@/components/admin/LabelStudioForm';
import {
  createLabelStudioDraft,
  hydrateLabelStudioDraftFromLabel,
  labelStudioApi,
  type LabelStudioCreateResult,
  type LabelStudioDraft,
} from '@/features/admin-content/label-studio';
import { buildAdminContentSubmitResultHref } from '@/features/admin-content/submit-result';

export default function AdminContentLabelEditPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const labelId = typeof params?.id === 'string' ? params.id : '';
  const [draft, setDraft] = useState<LabelStudioDraft>(() => createLabelStudioDraft());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!labelId) {
      setError('缺少厂牌 ID');
      setLoading(false);
      return;
    }

    let cancelled = false;

    const load = async () => {
      try {
        setLoading(true);
        setError(null);
        const label = await labelStudioApi.fetchLabel(labelId);
        if (cancelled) return;
        setDraft(hydrateLabelStudioDraftFromLabel(label));
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
  }, [labelId]);

  const handleSubmitResult = (result: LabelStudioCreateResult) => {
    router.replace(
      buildAdminContentSubmitResultHref({
        entityType: 'label',
        flow: 'edit',
        outcome: 'created',
        entityId: result.label.id,
        entityName: result.label.name,
      })
    );
  };

  return (
    <AdminContentLayout
      title={draft.name || '编辑厂牌'}
      description="编辑厂牌资料后，可以直接决定这次变更是否进入统一通知发布链路。未当场处理的内容，也会进入通知中心待处理候选项。"
      actions={
        <>
          <Link
            href="/admin/content/labels"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            返回厂牌目录
          </Link>
          <Link
            href="/admin/content/labels/new"
            className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
          >
            新建厂牌
          </Link>
        </>
      }
    >
      {loading ? (
        <section className="admin-studio-section p-6 text-sm text-black/48">正在加载厂牌详情...</section>
      ) : error ? (
        <section className="admin-studio-pastel-rose p-6 text-sm text-[#6a3530]">{error}</section>
      ) : (
        <LabelStudioForm
          mode="edit"
          labelId={labelId}
          draft={draft}
          setDraft={setDraft}
          onSubmit={handleSubmitResult}
          submitButtonText="保存厂牌"
        />
      )}
    </AdminContentLayout>
  );
}
