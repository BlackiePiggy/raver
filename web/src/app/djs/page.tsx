'use client';

import React, { useEffect, useState } from 'react';
import { djAPI, DJ } from '@/lib/api/dj';
import { DJCard } from '@/components/DJCard';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import Navigation from '@/components/Navigation';

export default function DJsPage() {
  const [djs, setDJs] = useState<DJ[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [sortBy, setSortBy] = useState<'followerCount' | 'name' | 'createdAt'>('followerCount');

  const loadDJs = async () => {
    try {
      setIsLoading(true);
      const response = await djAPI.getDJs({
        page,
        search: search || undefined,
        sortBy
      });
      setDJs(response.djs);
      setTotalPages(response.pagination.totalPages);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load DJs');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadDJs();
  }, [page, sortBy]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
    loadDJs();
  };

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px] max-w-7xl mx-auto px-4 py-8">
        <div className="mb-8">
          <h1 className="text-4xl font-bold bg-gradient-to-r from-primary-purple to-primary-blue bg-clip-text text-transparent mb-4">
            DJ 库
          </h1>
          <p className="text-text-secondary">发现你喜欢的电子音乐艺术家</p>
        </div>

        <div className="mb-8 space-y-4">
          <form onSubmit={handleSearch} className="flex gap-4">
            <div className="flex-1">
              <Input
                type="text"
                placeholder="搜索 DJ 名称..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            <Button type="submit" variant="primary">
              搜索
            </Button>
          </form>

          <div className="flex gap-2">
            <span className="text-text-secondary text-sm py-2">排序:</span>
            <Button
              variant={sortBy === 'followerCount' ? 'primary' : 'secondary'}
              size="sm"
              onClick={() => setSortBy('followerCount')}
            >
              热度
            </Button>
            <Button
              variant={sortBy === 'name' ? 'primary' : 'secondary'}
              size="sm"
              onClick={() => setSortBy('name')}
            >
              名称
            </Button>
            <Button
              variant={sortBy === 'createdAt' ? 'primary' : 'secondary'}
              size="sm"
              onClick={() => setSortBy('createdAt')}
            >
              最新
            </Button>
          </div>
        </div>

        {error && (
          <div className="bg-red-500/10 border border-red-500 text-red-500 px-4 py-3 rounded-lg mb-8">
            {error}
          </div>
        )}

        {isLoading ? (
          <div className="flex items-center justify-center py-20">
            <div className="text-text-secondary">加载中...</div>
          </div>
        ) : djs.length === 0 ? (
          <div className="text-center py-20">
            <div className="text-6xl mb-4">🎧</div>
            <p className="text-text-secondary">暂无 DJ</p>
          </div>
        ) : (
          <>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
              {djs.map((dj) => (
                <DJCard key={dj.id} dj={dj} />
              ))}
            </div>

            {totalPages > 1 && (
              <div className="flex justify-center gap-2">
                <Button
                  variant="secondary"
                  onClick={() => setPage(p => Math.max(1, p - 1))}
                  disabled={page === 1}
                >
                  上一页
                </Button>
                <span className="px-4 py-2 text-text-secondary">
                  第 {page} / {totalPages} 页
                </span>
                <Button
                  variant="secondary"
                  onClick={() => setPage(p => Math.min(totalPages, p + 1))}
                  disabled={page === totalPages}
                >
                  下一页
                </Button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
