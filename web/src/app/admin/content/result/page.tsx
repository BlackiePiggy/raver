'use client';

import Link from 'next/link';
import { Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import AdminPublishTaskActions from '@/components/admin/AdminPublishTaskActions';
import NotificationContentHistoryPrompt from '@/components/admin/NotificationContentHistoryPrompt';
import {
  isAdminContentSubmitEntityType,
  resolveAdminContentSubmitResultContent,
  type AdminContentSubmitEntityType,
  type AdminContentSubmitFlow,
  type AdminContentSubmitOutcome,
} from '@/features/admin-content/submit-result';

const isFlow = (value: string | null): value is AdminContentSubmitFlow => value === 'create' || value === 'edit';
const isOutcome = (value: string | null): value is AdminContentSubmitOutcome =>
  value === 'created' || value === 'submitted';

function AdminContentSubmitResultPageContent() {
  const searchParams = useSearchParams();
  const entityTypeParam = searchParams.get('entityType');
  const flowParam = searchParams.get('flow');
  const outcomeParam = searchParams.get('outcome');
  const entityId = searchParams.get('entityId');
  const entityName = searchParams.get('entityName');
  const submissionId = searchParams.get('submissionId');
  const message = searchParams.get('message');

  const entityType: AdminContentSubmitEntityType = isAdminContentSubmitEntityType(entityTypeParam)
    ? entityTypeParam
    : 'label';
  const flow: AdminContentSubmitFlow = isFlow(flowParam) ? flowParam : 'create';
  const outcome: AdminContentSubmitOutcome = isOutcome(outcomeParam) ? outcomeParam : 'created';

  const content = resolveAdminContentSubmitResultContent({
    entityType,
    flow,
    outcome,
    entityId,
    entityName,
    submissionId,
    message,
  });

  return (
    <AdminContentLayout
      title={content.title}
      description="独立结果页会明确展示当前这次操作是已直接入库，还是已进入审核与提交流程，避免停留在原页时无法确认状态。"
      actions={
        <Link
          href={content.catalogHref}
          className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
        >
          {content.catalogLabel}
        </Link>
      }
    >
      <section className="admin-studio-section px-6 py-10">
        <div className="mx-auto flex max-w-3xl flex-col items-center text-center">
          <div className="flex h-24 w-24 items-center justify-center rounded-full bg-[#edf7f2]">
            <div className="flex h-14 w-14 items-center justify-center rounded-full bg-[#071110] text-3xl font-bold text-white">OK</div>
          </div>

          <h2 className="mt-8 text-3xl font-black tracking-[-0.05em] text-[#071110]">{content.title}</h2>
          <p className="mt-4 max-w-2xl text-sm leading-7 text-black/56">{content.message}</p>

          {entityName ? (
            <div className="mt-6 rounded-full bg-[#f3f5f4] px-4 py-2 text-sm font-medium text-[#071110]">
              {entityName}
            </div>
          ) : null}

          {submissionId ? (
            <div className="mt-3 text-xs text-black/42">提交单号：{submissionId}</div>
          ) : null}

          <div className="mt-10 flex w-full max-w-xl flex-col gap-3 sm:flex-row sm:justify-center">
            <Link
              href={content.primaryHref}
              className="inline-flex min-h-12 items-center justify-center rounded-full bg-[#071110] px-6 py-3 text-sm font-semibold text-white"
            >
              {content.primaryLabel}
            </Link>
            <Link
              href={content.secondaryHref}
              className="inline-flex min-h-12 items-center justify-center rounded-full border border-[#d7ddda] bg-white px-6 py-3 text-sm font-semibold text-[#071110]"
            >
              {content.secondaryLabel}
            </Link>
          </div>

          {content.historyPrompt ? (
            <div className="mt-8 w-full max-w-3xl">
              <NotificationContentHistoryPrompt
                entityType={content.historyPrompt.entityType}
                entityId={content.historyPrompt.entityId}
                secondaryHref={content.historyPrompt.secondaryHref}
                secondaryLabel={content.historyPrompt.secondaryLabel}
                description={content.historyPrompt.description}
              />
            </div>
          ) : null}
        </div>
      </section>

      {content.publishTask ? (
        <AdminPublishTaskActions
          taskType={content.publishTask.taskType}
          entityType={content.publishTask.entityType}
          entityId={content.publishTask.entityId}
          mode={content.publishTask.mode}
        />
      ) : null}
    </AdminContentLayout>
  );
}

export default function AdminContentSubmitResultPage() {
  return (
    <Suspense
      fallback={
        <AdminContentLayout title="提交结果" description="正在整理提交结果...">
          <section className="admin-studio-section p-6 text-sm text-black/48">正在整理提交结果...</section>
        </AdminContentLayout>
      }
    >
      <AdminContentSubmitResultPageContent />
    </Suspense>
  );
}
