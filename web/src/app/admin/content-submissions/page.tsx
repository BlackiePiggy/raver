'use client';

import Link from 'next/link';
import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';

export default function ContentSubmissionsAdminPage() {
  const { user, isLoading } = useAuth();
  const router = useRouter();
  const isAuthorized = user?.role === 'admin' || user?.role === 'operator';

  useEffect(() => {
    if (!isLoading && isAuthorized) {
      router.replace('/admin/festival-viewer.html#review');
    }
  }, [isLoading, isAuthorized, router]);

  return (
    <main className="min-h-screen bg-bg-primary text-text-primary">
      <Navigation />
      <section className="mx-auto max-w-4xl px-6 pt-28">
        <div className="rounded-lg border border-border-secondary bg-bg-secondary p-6">
          <p className="text-sm text-text-secondary">Contribution Review</p>
          <h1 className="mt-2 text-2xl font-semibold">内容贡献审核已迁移到 Festival Viewer</h1>
          <p className="mt-3 text-sm leading-6 text-text-secondary">
            用户共建内容现在会按 Event / DJ / Set / Brand / Label / News / ID / Rating 的实际结构渲染，审核人可以逐字段写修改意见，再统一通过或拒绝。
          </p>
          <div className="mt-5 flex gap-3">
            {isAuthorized ? (
              <Link href="/admin/festival-viewer.html#review" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
                打开结构化审核台
              </Link>
            ) : (
              <Link href="/login" className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white">
                去登录
              </Link>
            )}
            <Link href="/admin" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
              返回后台
            </Link>
          </div>
        </div>
      </section>
    </main>
  );
}
