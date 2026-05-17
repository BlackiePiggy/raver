'use client';

import React, { createContext, useCallback, useContext, useState, useEffect, useRef } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { User, authAPI } from '@/lib/api/auth';
import { authSessionToken } from '@/lib/auth/session-token';
import { AUTH_EXPIRED_EVENT } from '@/lib/auth/authenticated-fetch';

interface AuthContextType {
  user: User | null;
  token: string | null;
  login: (identifier: string, password: string) => Promise<void>;
  register: (username: string, email: string, password: string, displayName?: string) => Promise<void>;
  logout: () => void;
  refreshProfile: () => Promise<void>;
  setAuthUser: (nextUser: User) => void;
  isLoading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

const ADMIN_IDLE_TIMEOUT_MS = 30 * 60 * 1000;
const ADMIN_IDLE_WARNING_MS = 28 * 60 * 1000;
const ACTIVITY_EVENTS = ['click', 'keydown', 'pointermove', 'scroll', 'touchstart'] as const;

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const pathname = usePathname();
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [showIdleWarning, setShowIdleWarning] = useState(false);
  const [sessionNotice, setSessionNotice] = useState<string | null>(null);
  const pathnameRef = useRef(pathname);
  const lastActivityAtRef = useRef(Date.now());
  const lastSessionRefreshAtRef = useRef(Date.now());
  const isRefreshingRef = useRef(false);

  useEffect(() => {
    pathnameRef.current = pathname;
  }, [pathname]);

  const clearSession = useCallback((notice?: string, reason?: 'session-expired' | 'idle-timeout') => {
    const currentPathname = pathnameRef.current;
    const shouldRedirectToLogin = Boolean(reason && currentPathname?.startsWith('/admin'));

    authSessionToken.set(null);
    authSessionToken.clearLegacyStorage();
    setToken(null);
    setUser(null);
    setShowIdleWarning(false);
    setSessionNotice(shouldRedirectToLogin ? null : notice || null);

    if (shouldRedirectToLogin) {
      const next = `${currentPathname}${typeof window !== 'undefined' ? window.location.search : ''}`;
      router.replace(`/login?reason=${reason}&next=${encodeURIComponent(next)}`);
    }
  }, [router]);

  const applySession = useCallback(async (session: Awaited<ReturnType<typeof authAPI.refresh>>) => {
    const nextToken = session.accessToken || session.token;
    if (!nextToken) {
      throw new Error('Missing access token');
    }
    authSessionToken.set(nextToken);
    setToken(nextToken);
    const userData = await authAPI.getProfile(nextToken);
    setUser({
      ...session.user,
      ...userData,
      role: userData.role && userData.role !== 'user' ? userData.role : session.user.role,
      avatarUrl: userData.avatarUrl ?? session.user.avatarUrl ?? session.user.avatarURL ?? null,
    });
    lastActivityAtRef.current = Date.now();
    lastSessionRefreshAtRef.current = Date.now();
    setShowIdleWarning(false);
    setSessionNotice(null);
  }, []);

  const renewSession = useCallback(async () => {
    if (isRefreshingRef.current) return;
    isRefreshingRef.current = true;
    try {
      const session = await authAPI.refresh();
      await applySession(session);
    } catch {
      clearSession('登录状态已过期，请重新登录。', 'session-expired');
    } finally {
      isRefreshingRef.current = false;
    }
  }, [applySession, clearSession]);

  useEffect(() => {
    const handleExpired = () => {
      clearSession('登录状态已过期，请重新登录。', 'session-expired');
    };
    window.addEventListener(AUTH_EXPIRED_EVENT, handleExpired);

    authSessionToken.clearLegacyStorage();
    authAPI.refresh()
      .then(applySession)
      .catch(() => {
        clearSession();
      })
      .finally(() => {
        setIsLoading(false);
      });

    return () => {
      window.removeEventListener(AUTH_EXPIRED_EVENT, handleExpired);
    };
  }, [applySession, clearSession]);

  useEffect(() => {
    if (!user || !token) return;

    const markActivity = () => {
      lastActivityAtRef.current = Date.now();
      setShowIdleWarning(false);
    };

    ACTIVITY_EVENTS.forEach((eventName) => {
      window.addEventListener(eventName, markActivity, { passive: true });
    });

    const timer = window.setInterval(() => {
      const now = Date.now();
      const idleForMs = now - lastActivityAtRef.current;
      const refreshAgeMs = now - lastSessionRefreshAtRef.current;

      if (idleForMs >= ADMIN_IDLE_TIMEOUT_MS) {
        clearSession('你已 30 分钟没有操作，后台会话已自动退出。', 'idle-timeout');
        return;
      }

      if (idleForMs >= ADMIN_IDLE_WARNING_MS) {
        setShowIdleWarning(true);
        return;
      }

      if (refreshAgeMs >= ADMIN_IDLE_WARNING_MS) {
        void renewSession();
      }
    }, 30 * 1000);

    return () => {
      window.clearInterval(timer);
      ACTIVITY_EVENTS.forEach((eventName) => {
        window.removeEventListener(eventName, markActivity);
      });
    };
  }, [clearSession, renewSession, token, user]);

  const login = async (identifier: string, password: string) => {
    const response = await authAPI.login({ identifier, password });
    const nextToken = response.accessToken || response.token;
    authSessionToken.set(nextToken);
    setUser(response.user);
    setToken(nextToken);
    lastActivityAtRef.current = Date.now();
    lastSessionRefreshAtRef.current = Date.now();
    setShowIdleWarning(false);
    setSessionNotice(null);
  };

  const register = async (username: string, email: string, password: string, displayName?: string) => {
    const response = await authAPI.register({ username, email, password, displayName });
    const nextToken = response.accessToken || response.token;
    authSessionToken.set(nextToken);
    setUser(response.user);
    setToken(nextToken);
    lastActivityAtRef.current = Date.now();
    lastSessionRefreshAtRef.current = Date.now();
    setShowIdleWarning(false);
    setSessionNotice(null);
  };

  const logout = () => {
    void authAPI.logout();
    clearSession();
  };

  const refreshProfile = async () => {
    const currentToken = token || authSessionToken.get();
    if (!currentToken) return;
    const profile = await authAPI.getProfile(currentToken);
    setUser((current) => ({
      ...(current || profile),
      ...profile,
      role: profile.role && profile.role !== 'user' ? profile.role : current?.role || profile.role,
    }));
    if (!token) {
      setToken(currentToken);
    }
  };

  const setAuthUser = (nextUser: User) => {
    setUser(nextUser);
  };

  return (
    <AuthContext.Provider value={{ user, token, login, register, logout, refreshProfile, setAuthUser, isLoading }}>
      {children}
      {sessionNotice && !user && (
        <div className="fixed right-4 top-4 z-50 max-w-sm rounded-lg border border-red-500/30 bg-bg-secondary px-4 py-3 text-sm text-text-primary shadow-xl">
          {sessionNotice}
        </div>
      )}
      {showIdleWarning && user && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-4">
          <div className="w-full max-w-md rounded-lg border border-border-secondary bg-bg-secondary p-6 shadow-2xl">
            <h2 className="text-xl font-semibold text-text-primary">后台会话即将过期</h2>
            <p className="mt-3 text-sm leading-6 text-text-secondary">
              你已经接近 30 分钟没有操作。继续使用会刷新后台会话；不处理则会自动退出。
            </p>
            <div className="mt-6 flex justify-end gap-3">
              <button
                type="button"
                onClick={logout}
                className="rounded-lg border border-border-secondary px-4 py-2 text-sm font-medium text-text-secondary hover:border-red-500 hover:text-red-400"
              >
                退出
              </button>
              <button
                type="button"
                onClick={() => void renewSession()}
                className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white hover:bg-primary-purple"
              >
                继续使用
              </button>
            </div>
          </div>
        </div>
      )}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
