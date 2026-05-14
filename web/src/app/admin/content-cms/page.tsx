'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import { getAdminCmsRolePolicy } from '@/lib/admin/role-policy';

export default function AdminContentCmsPage() {
  const router = useRouter();
  const { user, token, isLoading } = useAuth();
  const policy = useMemo(() => getAdminCmsRolePolicy(user), [user]);
  const [redirecting, setRedirecting] = useState(false);

  useEffect(() => {
    if (isLoading || !user || !policy.canAccessContentCms) return;

    try {
      if (token) {
        const bearerToken = token.toLowerCase().startsWith('bearer ') ? token : `Bearer ${token}`;
        localStorage.setItem('raver_viewer_auth_token', bearerToken);
        localStorage.setItem('raver_viewer_auth_user', JSON.stringify(user));
      }
    } finally {
      setRedirecting(true);
      router.replace('/admin/festival-viewer.html');
    }
  }, [isLoading, policy.canAccessContentCms, router, token, user]);

  if (isLoading) {
    return (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <div className="mx-auto max-w-6xl px-6 pt-28">加载中...</div>
      </main>
    );
  }

  if (!user) {
    return (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <div className="mx-auto max-w-6xl px-6 pt-28">
          <p className="text-lg">请先登录后访问内容后台。</p>
          <Link href="/login" className="mt-4 inline-block rounded-lg bg-primary-blue px-4 py-2 text-white">
            去登录
          </Link>
        </div>
      </main>
    );
  }

  if (!policy.canAccessContentCms) {
    return (
      <main className="min-h-screen bg-bg-primary text-text-primary">
        <Navigation />
        <div className="mx-auto max-w-6xl px-6 pt-28">
          <p className="text-lg">当前账号无权限访问内容后台。</p>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-bg-primary text-text-primary">
      <Navigation />
      <section className="mx-auto max-w-3xl space-y-5 px-6 pb-10 pt-28">
        <div>
          <div className="text-sm text-text-secondary">Admin / Content CMS</div>
          <h1 className="mt-2 text-3xl font-semibold">正在进入内容管理中心</h1>
          <p className="mt-2 text-sm leading-6 text-text-secondary">
            正在同步当前登录态，并跳转到完整的 festival-viewer 管理页面。
          </p>
        </div>

        <div className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="text-lg font-semibold">后台身份</h2>
              <p className="mt-1 text-sm text-text-secondary">{policy.description}</p>
            </div>
            <div className="rounded-lg border border-border-secondary bg-bg-tertiary px-4 py-3 text-sm">
              <div className="text-text-secondary">当前身份</div>
              <div className="mt-1 font-semibold">{policy.label}</div>
            </div>
          </div>
          {policy.capabilities.length > 0 && (
            <div className="mt-4 space-y-2">
              {policy.capabilities.map((capability) => (
                <div key={capability} className="rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm">
                  {capability}
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="text-lg font-semibold">{redirecting ? '跳转中...' : '准备跳转'}</h2>
              <p className="mt-1 text-sm text-text-secondary">
                如果没有自动跳转，可以手动打开完整页面。
              </p>
            </div>
            <Link href="/admin/festival-viewer.html" className="rounded-md border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
              打开内容管理
            </Link>
          </div>
        </div>

        <div className="rounded-lg border border-yellow-500/40 bg-yellow-500/10 p-4 text-sm leading-6 text-yellow-100">
          第一批不新增 RBAC 数据表。正式的入驻组织、艺人认领和细粒度内容授权会在后续数据库备份后单独迁移。
        </div>
      </section>
    </main>
  );
}
