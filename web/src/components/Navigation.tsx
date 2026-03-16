'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';

export default function Navigation() {
  const pathname = usePathname();
  const router = useRouter();
  const { user, logout, isLoading } = useAuth();

  const showBackButton = pathname !== '/';

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 backdrop-blur-apple bg-bg-glass border-b border-border-secondary">
      <div className="max-w-[980px] mx-auto px-6 h-[44px] flex items-center justify-between">
        <div className="flex items-center gap-4">
          {showBackButton && (
            <button
              onClick={() => router.back()}
              className="text-sm text-text-secondary hover:text-text-primary transition-colors"
            >
              ← 返回
            </button>
          )}
          <Link href="/" className="text-xl font-semibold text-text-primary hover:text-text-secondary transition-colors">
            Raver
          </Link>
        </div>

        {!isLoading && (
          <div className="flex items-center gap-6">
            {user ? (
              <>
                <Link href="/events" className="text-sm text-text-secondary hover:text-text-primary transition-colors">
                  活动
                </Link>
                <Link href="/djs" className="text-sm text-text-secondary hover:text-text-primary transition-colors">
                  DJ
                </Link>
                <Link href="/sets" className="text-sm text-text-secondary hover:text-text-primary transition-colors">
                  DJ Sets
                </Link>
                <Link href="/checkins" className="text-sm text-text-secondary hover:text-text-primary transition-colors">
                  打卡
                </Link>
                <button
                  onClick={logout}
                  className="text-sm text-text-secondary hover:text-text-primary transition-colors"
                >
                  登出
                </button>
              </>
            ) : (
              <>
                <Link href="/events" className="text-sm text-text-secondary hover:text-text-primary transition-colors">
                  活动
                </Link>
                <Link href="/djs" className="text-sm text-text-secondary hover:text-text-primary transition-colors">
                  DJ
                </Link>
                <Link href="/sets" className="text-sm text-text-secondary hover:text-text-primary transition-colors">
                  DJ Sets
                </Link>
                <Link href="/login" className="text-sm text-primary-blue hover:text-primary-purple transition-colors">
                  登录
                </Link>
              </>
            )}
          </div>
        )}
      </div>
    </nav>
  );
}