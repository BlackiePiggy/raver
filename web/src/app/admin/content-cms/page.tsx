'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import AdminAppShell from '@/components/admin/AdminAppShell';
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
      router.replace('/admin/content');
    }
  }, [isLoading, policy.canAccessContentCms, router, token, user]);

  if (isLoading) {
    return (
      <AdminAppShell title="正在进入内容后台" description="同步当前登录态并准备跳转到统一内容控制台。">
        <div className="admin-shell-panel p-8 text-sm text-black/55">加载中...</div>
      </AdminAppShell>
    );
  }

  if (!user) {
    return (
      <AdminAppShell title="内容后台需要登录" description="请先登录后访问统一内容控制台。">
        <div className="admin-shell-panel p-8">
          <p className="text-lg font-semibold text-[#071110]">请先登录后访问内容后台。</p>
          <Link href="/login?next=%2Fadmin" className="mt-5 inline-flex rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            去登录
          </Link>
        </div>
      </AdminAppShell>
    );
  }

  if (!policy.canAccessContentCms) {
    return (
      <AdminAppShell title="当前账号无权访问" description="你的角色暂时不能进入内容后台。">
        <div className="admin-shell-panel p-8 text-lg font-semibold text-[#071110]">当前账号无权访问内容后台。</div>
      </AdminAppShell>
    );
  }

  return (
    <AdminAppShell
      title="正在进入统一内容后台"
      eyebrow="Raver Admin / Content CMS"
      description="正在同步当前登录态，并跳转到新的 Web 内容控制台。Festival Viewer 会作为迁移期旧工具继续保留在 legacy tools 中。"
    >
      <section className="mx-auto max-w-4xl space-y-5">
        <div>
          <div className="text-sm text-black/45">Admin / Content CMS</div>
          <h1 className="mt-2 text-3xl font-semibold text-[#071110]">正在进入统一内容后台</h1>
          <p className="mt-2 text-sm leading-6 text-black/50">当前页面会自动同步身份并完成跳转。</p>
        </div>

        <div className="admin-shell-panel p-5">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="text-lg font-semibold text-[#071110]">后台身份</h2>
              <p className="mt-1 text-sm text-black/50">{policy.description}</p>
            </div>
            <div className="admin-shell-soft-panel px-4 py-3 text-sm">
              <div className="text-black/45">当前身份</div>
              <div className="mt-1 font-semibold text-[#071110]">{policy.label}</div>
            </div>
          </div>
          {policy.capabilities.length > 0 && (
            <div className="mt-4 space-y-2">
              {policy.capabilities.map((capability) => (
                <div key={capability} className="admin-shell-soft-panel px-3 py-2 text-sm text-[#18211f]">
                  {capability}
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="admin-shell-panel p-5">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="text-lg font-semibold text-[#071110]">{redirecting ? '跳转中...' : '准备跳转'}</h2>
              <p className="mt-1 text-sm text-black/50">如果没有自动跳转，可以手动打开 legacy tools。</p>
            </div>
            <div className="flex flex-wrap gap-3">
              <Link href="/admin/content/legacy-tools" className="rounded-full border border-white/50 bg-white/50 px-4 py-2 text-sm text-[#071110]">
                打开旧工具桥接
              </Link>
            </div>
          </div>
        </div>

        <div className="rounded-[24px] border border-yellow-500/30 bg-yellow-500/10 p-5 text-sm leading-6 text-[#7a5b0f]">
          第一批不新增 RBAC 数据表。正式的入驻组织、艺人认领和细粒度内容授权会在后续数据库备份后单独迁移。
        </div>
      </section>
    </AdminAppShell>
  );
}
