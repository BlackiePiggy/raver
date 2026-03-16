'use client';

import { useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { Button } from '@/components/ui/Button';
import { getApiUrl } from '@/lib/config';
import Navigation from '@/components/Navigation';

interface DJSet {
  id: string;
  title: string;
  djId: string;
  thumbnailUrl?: string;
  venue?: string;
  eventName?: string;
  viewCount: number;
  createdAt: string;
  dj: {
    id: string;
    name: string;
    avatarUrl?: string;
  };
  tracks: any[];
}

export default function DJSetsPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [sets, setSets] = useState<DJSet[]>([]);
  const [loading, setLoading] = useState(true);
  const [sortBy, setSortBy] = useState(searchParams.get('sort') || 'latest');
  const [filterDJ, setFilterDJ] = useState(searchParams.get('dj') || '');
  const [allDJs, setAllDJs] = useState<any[]>([]);

  useEffect(() => {
    loadData();
  }, [sortBy, filterDJ]);

  const loadData = async () => {
    try {
      setLoading(true);

      // 获取所有DJ Sets
      const response = await fetch(getApiUrl('/dj-sets'));
      let data = await response.json();

      // 如果返回的是对象而不是数组，尝试获取数组
      if (!Array.isArray(data)) {
        data = [];
      }

      // 筛选DJ
      if (filterDJ) {
        data = data.filter((set: DJSet) => set.djId === filterDJ);
      }

      // 排序
      switch (sortBy) {
        case 'latest':
          data.sort((a: DJSet, b: DJSet) =>
            new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
          );
          break;
        case 'popular':
          data.sort((a: DJSet, b: DJSet) => b.viewCount - a.viewCount);
          break;
        case 'tracks':
          data.sort((a: DJSet, b: DJSet) => b.tracks.length - a.tracks.length);
          break;
      }

      setSets(data);

      // 获取所有DJ列表用于筛选
      const djsResponse = await fetch(getApiUrl('/djs'));
      const djsData = await djsResponse.json();
      setAllDJs(djsData.djs || []);
    } catch (error) {
      console.error('Failed to load DJ sets:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSortChange = (newSort: string) => {
    setSortBy(newSort);
    const params = new URLSearchParams(searchParams.toString());
    params.set('sort', newSort);
    router.push(`/sets?${params.toString()}`);
  };

  const handleDJFilter = (djId: string) => {
    setFilterDJ(djId);
    const params = new URLSearchParams(searchParams.toString());
    if (djId) {
      params.set('dj', djId);
    } else {
      params.delete('dj');
    }
    router.push(`/sets?${params.toString()}`);
  };

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />

      {/* Header */}
      <div className="pt-[44px] bg-bg-secondary border-b border-bg-tertiary">
        <div className="max-w-7xl mx-auto px-4 py-8">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h1 className="text-4xl font-bold text-text-primary mb-2">DJ Sets</h1>
              <p className="text-text-secondary">
                探索精彩的现场表演视频和完整歌单
              </p>
            </div>
            <Button
              variant="primary"
              onClick={() => router.push('/upload')}
            >
              + 上传Set
            </Button>
          </div>

          {/* Filters */}
          <div className="flex flex-wrap gap-4">
            {/* Sort */}
            <div className="flex items-center gap-2">
              <span className="text-text-secondary text-sm">排序:</span>
              <select
                value={sortBy}
                onChange={(e) => handleSortChange(e.target.value)}
                className="bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 text-sm border border-bg-primary focus:border-primary-purple focus:outline-none"
              >
                <option value="latest">最新上传</option>
                <option value="popular">最受欢迎</option>
                <option value="tracks">歌曲最多</option>
              </select>
            </div>

            {/* DJ Filter */}
            <div className="flex items-center gap-2">
              <span className="text-text-secondary text-sm">DJ:</span>
              <select
                value={filterDJ}
                onChange={(e) => handleDJFilter(e.target.value)}
                className="bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 text-sm border border-bg-primary focus:border-primary-purple focus:outline-none"
              >
                <option value="">全部DJ</option>
                {allDJs.map((dj) => (
                  <option key={dj.id} value={dj.id}>
                    {dj.name}
                  </option>
                ))}
              </select>
            </div>

            {/* Clear Filters */}
            {(filterDJ || sortBy !== 'latest') && (
              <button
                onClick={() => {
                  setSortBy('latest');
                  setFilterDJ('');
                  router.push('/sets');
                }}
                className="text-primary-blue hover:text-primary-purple text-sm"
              >
                清除筛选
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Sets Grid */}
      <div className="max-w-7xl mx-auto px-4 py-8">
        {loading ? (
          <div className="text-center py-20">
            <div className="text-text-secondary text-xl">加载中...</div>
          </div>
        ) : sets.length === 0 ? (
          <div className="text-center py-20">
            <div className="text-6xl mb-4">🎵</div>
            <p className="text-text-secondary text-lg mb-6">
              {filterDJ ? '该DJ还没有上传任何Sets' : '还没有任何DJ Sets'}
            </p>
            <Button
              variant="primary"
              onClick={() => router.push('/upload')}
            >
              上传第一个Set
            </Button>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {sets.map((set) => (
              <Link
                key={set.id}
                href={`/dj-sets/${set.id}`}
                className="bg-bg-secondary rounded-xl overflow-hidden hover:scale-105 hover:shadow-2xl transition-all duration-300 border border-bg-tertiary"
              >
                {set.thumbnailUrl ? (
                  <img
                    src={set.thumbnailUrl}
                    alt={set.title}
                    className="w-full h-48 object-cover"
                  />
                ) : (
                  <div className="w-full h-48 bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center">
                    <span className="text-6xl">🎧</span>
                  </div>
                )}
                <div className="p-5">
                  <h2 className="text-xl font-semibold text-text-primary mb-2 line-clamp-2">
                    {set.title}
                  </h2>

                  {/* DJ Info */}
                  <div className="flex items-center gap-2 mb-3">
                    {set.dj.avatarUrl ? (
                      <img
                        src={set.dj.avatarUrl}
                        alt={set.dj.name}
                        className="w-6 h-6 rounded-full"
                      />
                    ) : (
                      <div className="w-6 h-6 rounded-full bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-xs">
                        🎧
                      </div>
                    )}
                    <span className="text-text-secondary text-sm">{set.dj.name}</span>
                  </div>

                  {set.venue && (
                    <div className="flex items-center text-text-secondary text-sm mb-2">
                      <span className="mr-2">📍</span>
                      <span>{set.venue}</span>
                    </div>
                  )}

                  {set.eventName && (
                    <div className="flex items-center text-text-secondary text-sm mb-3">
                      <span className="mr-2">🎪</span>
                      <span>{set.eventName}</span>
                    </div>
                  )}

                  <div className="flex items-center gap-4 text-sm text-text-secondary pt-3 border-t border-bg-tertiary">
                    <span className="flex items-center gap-1">
                      <span>🎵</span>
                      <span>{set.tracks.length} 首歌</span>
                    </span>
                    {set.viewCount > 0 && (
                      <span className="flex items-center gap-1">
                        <span>👁️</span>
                        <span>{set.viewCount}</span>
                      </span>
                    )}
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}