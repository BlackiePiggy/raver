'use client';

import { Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import NotificationCenterWorkspaceLayout from '@/components/admin/NotificationCenterWorkspaceLayout';
import NotificationContentHistoryWorkspace from '@/components/admin/NotificationContentHistoryWorkspace';

function NotificationCenterContentHistoryPageContent() {
  const searchParams = useSearchParams();
  const entityType = searchParams.get('entityType') || 'all';
  const query = searchParams.get('query') || '';

  return (
    <NotificationCenterWorkspaceLayout
      title="内容历史"
      description="统一查看后台内容创建、编辑的成功和失败结果，并决定成功项是否继续进入用户通知推送。"
    >
      <NotificationContentHistoryWorkspace initialEntityType={entityType} initialQuery={query} />
    </NotificationCenterWorkspaceLayout>
  );
}

export default function NotificationCenterContentHistoryPage() {
  return (
    <Suspense
      fallback={
        <NotificationCenterWorkspaceLayout
          title="内容历史"
          description="统一查看后台内容创建、编辑的成功和失败结果，并决定成功项是否继续进入用户通知推送。"
        >
          <section className="rounded-[28px] border border-[#e7ece8] bg-white p-6 text-sm text-[#5b6763]">
            正在加载内容历史...
          </section>
        </NotificationCenterWorkspaceLayout>
      }
    >
      <NotificationCenterContentHistoryPageContent />
    </Suspense>
  );
}
