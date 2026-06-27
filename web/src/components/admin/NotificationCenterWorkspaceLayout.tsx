'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import type { ReactNode } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import { useAuth } from '@/contexts/AuthContext';
import { getAdminCmsRolePolicy } from '@/lib/admin/role-policy';
import { createLoginHref } from '@/lib/auth/login-redirect';

type NotificationCenterWorkspaceLayoutProps = {
  title: string;
  description: string;
  actions?: ReactNode;
  children: ReactNode;
};

const NAV_ITEMS = [
  { href: '/admin/notification-center', label: '总览', exact: true },
  { href: '/admin/notification-center/content-history', label: '内容历史', exact: false },
  { href: '/admin/notification-center/publish-tasks', label: '发布任务', exact: false },
  { href: '/admin/notification-center/manual', label: '手动发布', exact: false },
  { href: '/admin/notification-center/deliveries', label: '投递记录', exact: false },
  { href: '/admin/notification-center/templates', label: '通知模板', exact: false },
  { href: '/admin/notification-center/governance', label: '治理配置', exact: false },
] as const;

const isItemActive = (pathname: string, href: string, exact = false): boolean =>
  exact ? pathname === href : pathname === href || pathname.startsWith(`${href}/`);

export default function NotificationCenterWorkspaceLayout({
  title,
  description,
  actions,
  children,
}: NotificationCenterWorkspaceLayoutProps) {
  const pathname = usePathname();
  const { user, isLoading } = useAuth();
  const policy = getAdminCmsRolePolicy(user);
  const loginHref = createLoginHref(pathname);

  if (isLoading) {
    return (
      <AdminContentLayout
        title="通知中心"
        eyebrow="Raver Admin / Notification Center"
        description="正在加载通知中心..."
      >
        <section className="admin-shell-panel p-8 text-sm text-black/55">正在加载...</section>
      </AdminContentLayout>
    );
  }

  if (!user) {
    return (
      <AdminContentLayout
        title="通知中心"
        eyebrow="Raver Admin / Notification Center"
        description="请先登录管理员账号后访问通知中心。"
      >
        <section className="admin-shell-panel p-8">
          <p className="text-lg">请先登录管理员账号后访问通知中心。</p>
          <Link
            href={loginHref}
            className="mt-4 inline-flex rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
          >
            去登录
          </Link>
        </section>
      </AdminContentLayout>
    );
  }

  if (!policy.canAccessNotificationOps) {
    return (
      <AdminContentLayout
        title="通知中心"
        eyebrow="Raver Admin / Notification Center"
        description="当前账号无权限访问通知中心。"
      >
        <section className="admin-shell-panel p-8">
          <p className="text-lg">当前账号无权限访问通知中心。</p>
        </section>
      </AdminContentLayout>
    );
  }

  return (
    <AdminContentLayout
      title={title}
      eyebrow="Raver Admin / Notification Center"
      description={description}
      actions={actions}
    >
      <section className="space-y-6">
        {/* 优化Tab栏样式：对齐UI，间距、圆角、排版统一 */}
        <nav className="rounded-[28px] border border-[#e7ece8] bg-white p-4">
          <div className="flex flex-wrap gap-3">
            {NAV_ITEMS.map((item) => {
              const active = isItemActive(pathname, item.href, item.exact);
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`rounded-full px-5 py-2.5 text-sm font-medium transition-all ${
                    active
                      ? 'bg-[#071110] text-white shadow-sm'
                      : 'border border-[#d9e1de] bg-[#fbfcfb] text-[#071110] hover:bg-white hover:border-[#071110]/20'
                  }`}
                >
                  {item.label}
                </Link>
              );
            })}
          </div>
        </nav>
        {children}
      </section>
    </AdminContentLayout>
  );
}
