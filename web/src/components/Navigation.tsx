'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { usePathname, useRouter } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { notificationApi, NotificationCount } from '@/lib/api/notification';

export default function Navigation() {
  const pathname = usePathname();
  const router = useRouter();
  const { user, logout, isLoading } = useAuth();
  const [menuOpen, setMenuOpen] = useState(false);
  const [notificationCount, setNotificationCount] = useState<NotificationCount | null>(null);
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const showBackButton = pathname !== '/';

  // 加载通知数量
  useEffect(() => {
    if (user) {
      loadNotificationCount();
      // 每30秒刷新一次通知数量
      const interval = setInterval(loadNotificationCount, 30000);
      return () => clearInterval(interval);
    }
  }, [user]);

  const loadNotificationCount = async () => {
    try {
      const count = await notificationApi.getUnreadCount();
      setNotificationCount(count);
    } catch (error) {
      console.error('加载通知数量失败:', error);
    }
  };

  useEffect(() => {
    return () => {
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current);
      }
    };
  }, []);

  const openMenu = () => {
    if (closeTimerRef.current) {
      clearTimeout(closeTimerRef.current);
      closeTimerRef.current = null;
    }
    setMenuOpen(true);
  };

  const scheduleCloseMenu = () => {
    if (closeTimerRef.current) {
      clearTimeout(closeTimerRef.current);
    }
    closeTimerRef.current = setTimeout(() => setMenuOpen(false), 140);
  };

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
            RaveHub
          </Link>
        </div>

        {!isLoading && (
          <div className="flex items-center gap-5">
            <Link href="/events" className="text-sm text-text-secondary hover:text-text-primary transition-colors">
              活动
            </Link>
            <Link href="/djs" className="text-sm text-text-secondary hover:text-text-primary transition-colors">
              DJ
            </Link>
            <Link href="/sets" className="text-sm text-text-secondary hover:text-text-primary transition-colors">
              Sets
            </Link>
            <Link href="/community" className="text-sm text-text-secondary hover:text-text-primary transition-colors">
              圈子
            </Link>
            <Link href="/learn" className="text-sm text-text-secondary hover:text-text-primary transition-colors">
              学习
            </Link>

            {user ? (
              <div
                className="relative"
                onMouseEnter={openMenu}
                onMouseLeave={scheduleCloseMenu}
                onFocusCapture={openMenu}
                onBlurCapture={scheduleCloseMenu}
              >
                <button
                  type="button"
                  onClick={() => setMenuOpen((prev) => !prev)}
                  className="h-8 w-8 rounded-full overflow-hidden border border-border-secondary bg-bg-tertiary/60 flex items-center justify-center relative"
                  aria-label="user menu"
                  aria-expanded={menuOpen}
                >
                  {user.avatarUrl ? (
                    <Image src={user.avatarUrl} alt={user.displayName || user.username} width={32} height={32} className="h-full w-full object-cover" />
                  ) : (
                    <span className="text-xs text-text-primary font-semibold">
                      {(user.displayName || user.username || 'U').slice(0, 1).toUpperCase()}
                    </span>
                  )}
                  {notificationCount && notificationCount.total > 0 && (
                    <span className="absolute -top-1 -right-1 h-4 min-w-[16px] px-1 bg-red-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center">
                      {notificationCount.total > 99 ? '99+' : notificationCount.total}
                    </span>
                  )}
                </button>
                <div
                  className={`absolute right-0 top-full z-50 min-w-[200px] rounded-lg border border-bg-primary bg-bg-secondary p-2 shadow-2xl transition-all duration-200 ease-out ${
                    menuOpen
                      ? 'pointer-events-auto mt-1 opacity-100 translate-y-0'
                      : 'pointer-events-none mt-1 opacity-0 -translate-y-1'
                  }`}
                >
                  <Link href="/profile" className="block px-3 py-2 text-sm rounded-md text-text-secondary hover:text-text-primary hover:bg-bg-tertiary">
                    我的主页
                  </Link>
                  <Link
                    href="/notifications"
                    className="flex items-center justify-between px-3 py-2 text-sm rounded-md text-text-secondary hover:text-text-primary hover:bg-bg-tertiary"
                  >
                    <span>我的消息</span>
                    {notificationCount && notificationCount.total > 0 && (
                      <span className="h-5 min-w-[20px] px-1.5 bg-red-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center">
                        {notificationCount.total > 99 ? '99+' : notificationCount.total}
                      </span>
                    )}
                  </Link>
                  <Link
                    href="/community/squads?my=true"
                    className="block px-3 py-2 text-sm rounded-md text-text-secondary hover:text-text-primary hover:bg-bg-tertiary"
                  >
                    我的小队
                  </Link>
                  <div className="my-1 border-t border-bg-tertiary"></div>
                  <Link href="/publish/new" className="block px-3 py-2 text-sm rounded-md text-text-secondary hover:text-text-primary hover:bg-bg-tertiary">
                    新建发布
                  </Link>
                  <Link href="/my-publishes" className="block px-3 py-2 text-sm rounded-md text-text-secondary hover:text-text-primary hover:bg-bg-tertiary">
                    我的发布
                  </Link>
                  <Link href="/checkins" className="block px-3 py-2 text-sm rounded-md text-text-secondary hover:text-text-primary hover:bg-bg-tertiary">
                    我的打卡
                  </Link>
                  <div className="my-1 border-t border-bg-tertiary"></div>
                  <button
                    onClick={logout}
                    className="w-full text-left px-3 py-2 text-sm rounded-md text-text-secondary hover:text-text-primary hover:bg-bg-tertiary"
                  >
                    退出登录
                  </button>
                </div>
              </div>
            ) : (
              <Link href="/login" className="text-sm text-primary-blue hover:text-primary-purple transition-colors">
                登录
              </Link>
            )}
          </div>
        )}
      </div>
    </nav>
  );
}
