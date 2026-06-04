'use client';

import NotificationCenterWorkspaceLayout from '@/components/admin/NotificationCenterWorkspaceLayout';
import NotificationManualPublishConsole from '@/components/admin/NotificationManualPublishConsole';

export default function NotificationCenterManualPage() {
  return (
    <NotificationCenterWorkspaceLayout
      title="手动发布"
      description="用于运营侧主动发起一条 APNS / 站内通知，可先绑定内容对象，再对触达范围做预览。"
    >
      <NotificationManualPublishConsole />
    </NotificationCenterWorkspaceLayout>
  );
}
