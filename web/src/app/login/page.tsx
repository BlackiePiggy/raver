'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import Navigation from '@/components/Navigation';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Card } from '@/components/ui/Card';

export default function LoginPage() {
  const router = useRouter();
  const { login } = useAuth();
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    const searchParams = new URLSearchParams(window.location.search);
    const reason = searchParams.get('reason');
    if (reason === 'session-expired') {
      setNotice('登录状态已过期，请重新登录。');
    } else if (reason === 'idle-timeout') {
      setNotice('你已 30 分钟没有操作，后台会话已自动退出。');
    }
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setIsLoading(true);

    try {
      await login(identifier, password);
      const searchParams = new URLSearchParams(window.location.search);
      const next = searchParams.get('next');
      router.push(next && next.startsWith('/') ? next : '/');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px] min-h-[calc(100vh-44px)] flex items-center justify-center px-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold bg-gradient-to-r from-primary-purple to-primary-blue bg-clip-text text-transparent mb-2">
            RaveHub
          </h1>
          <p className="text-text-secondary">Welcome back to the community</p>
        </div>

        <Card>
          <h2 className="text-2xl font-bold text-text-primary mb-6">Login</h2>

          {notice && (
            <div className="mb-4 bg-yellow-500/10 border border-yellow-500/40 text-yellow-200 px-4 py-3 rounded-lg text-sm">
              {notice}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <Input
              type="text"
              label="邮箱 / 用户名 / 昵称"
              placeholder="your@email.com / username / nickname"
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
              required
            />

            <Input
              type="password"
              label="Password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />

            {error && (
              <div className="bg-red-500/10 border border-red-500 text-red-500 px-4 py-3 rounded-lg text-sm">
                {error}
              </div>
            )}

            <Button
              type="submit"
              variant="primary"
              size="lg"
              className="w-full"
              isLoading={isLoading}
            >
              Login
            </Button>
          </form>

          <div className="mt-6 text-center">
            <p className="text-text-secondary text-sm">
              Don&apos;t have an account?{' '}
              <Link href="/register" className="text-primary-purple hover:text-primary-blue transition-colors">
                Register
              </Link>
            </p>
            <div className="mt-4 flex flex-wrap items-center justify-center gap-3 text-xs text-text-tertiary">
              <Link href="/legal/terms" className="hover:text-text-secondary transition-colors">Terms</Link>
              <Link href="/legal/privacy" className="hover:text-text-secondary transition-colors">Privacy</Link>
              <Link href="/legal/contact" className="hover:text-text-secondary transition-colors">Contact</Link>
            </div>
          </div>
        </Card>
      </div>
      </div>
    </div>
  );
}
